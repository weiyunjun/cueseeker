import CryptoKit
import Foundation

public struct LibraryCoverIndexingResult: Equatable, Sendable {
    public let eligibleVideoCount: Int
    public let skippedFreshCoverCount: Int
    public let generatedCoverCount: Int
    public let failedCoverCount: Int
    public let generatedDisplayCoverCount: Int
    public let failedDisplayCoverCount: Int
    public let elapsedSeconds: Double

    public init(
        eligibleVideoCount: Int,
        skippedFreshCoverCount: Int,
        generatedCoverCount: Int,
        failedCoverCount: Int,
        generatedDisplayCoverCount: Int,
        failedDisplayCoverCount: Int,
        elapsedSeconds: Double
    ) {
        self.eligibleVideoCount = eligibleVideoCount
        self.skippedFreshCoverCount = skippedFreshCoverCount
        self.generatedCoverCount = generatedCoverCount
        self.failedCoverCount = failedCoverCount
        self.generatedDisplayCoverCount = generatedDisplayCoverCount
        self.failedDisplayCoverCount = failedDisplayCoverCount
        self.elapsedSeconds = elapsedSeconds
    }
}

public enum LibraryCoverGenerationError: Error, CustomStringConvertible, Sendable {
    case missingDuration
    case emptyCandidatePercentages
    case shortFrameData(Int, Int)
    case ffmpegExit(Int32)

    public var description: String {
        switch self {
        case .missingDuration:
            "missing video duration"
        case .emptyCandidatePercentages:
            "empty candidate percentages"
        case .shortFrameData(let actual, let expected):
            "short frame data: \(actual)/\(expected) bytes"
        case .ffmpegExit(let status):
            "ffmpeg exited with status \(status)"
        }
    }
}

public struct LibraryCoverCandidateScorer: Sendable {
    public static let algorithmVersion = 1

    public struct ScoredCandidate: Equatable, Sendable {
        public let timestampMilliseconds: Int
        public let qualityScore: Double
        public let histogram: [Double]
        public var totalScore: Double

        public init(
            timestampMilliseconds: Int,
            qualityScore: Double,
            histogram: [Double],
            totalScore: Double
        ) {
            self.timestampMilliseconds = timestampMilliseconds
            self.qualityScore = qualityScore
            self.histogram = histogram
            self.totalScore = totalScore
        }
    }

    public struct FrameMetrics: Equatable, Sendable {
        public let qualityScore: Double
        public let histogram: [Double]

        public init(qualityScore: Double, histogram: [Double]) {
            self.qualityScore = qualityScore
            self.histogram = histogram
        }
    }

    public struct GenerationJob: Sendable {
        public let order: Int
        public let video: LibraryCoverEligibleVideo
        public let coverURL: URL
        public let displayURL: URL
        public let existingCover: LibraryVideoCover?

        public init(
            order: Int,
            video: LibraryCoverEligibleVideo,
            coverURL: URL,
            displayURL: URL,
            existingCover: LibraryVideoCover?
        ) {
            self.order = order
            self.video = video
            self.coverURL = coverURL
            self.displayURL = displayURL
            self.existingCover = existingCover
        }
    }

    public struct GenerationResult: Sendable {
        public let order: Int
        public let video: LibraryCoverEligibleVideo
        public let coverURL: URL
        public let displayURL: URL
        public let existingCover: LibraryVideoCover?
        public let masterData: Data?
        public let displayRendition: LibraryCoverEncodedDisplayRendition?
        public let sourceTimeMilliseconds: Int
        public let score: Double?
        public let status: LibraryCoverStatus
        public let errorMessage: String?

        public init(
            order: Int,
            video: LibraryCoverEligibleVideo,
            coverURL: URL,
            displayURL: URL,
            existingCover: LibraryVideoCover?,
            masterData: Data?,
            displayRendition: LibraryCoverEncodedDisplayRendition?,
            sourceTimeMilliseconds: Int,
            score: Double?,
            status: LibraryCoverStatus,
            errorMessage: String?
        ) {
            self.order = order
            self.video = video
            self.coverURL = coverURL
            self.displayURL = displayURL
            self.existingCover = existingCover
            self.masterData = masterData
            self.displayRendition = displayRendition
            self.sourceTimeMilliseconds = sourceTimeMilliseconds
            self.score = score
            self.status = status
            self.errorMessage = errorMessage
        }
    }

    public static func indexCovers(
        videos: [LibraryCoverEligibleVideo],
        folderReferenceVideos: [LibraryCoverEligibleVideo],
        affectedVideoPaths: Set<String>,
        affectedFolderPaths: Set<String>,
        coverDirectory: URL,
        displayRenditionCommitToken: LibraryCoverDisplayRenditionCommitToken?,
        algorithmVersion: Int = LibraryCoverCandidateScorer.algorithmVersion,
        into database: any LibraryCoverPersistence,
        generateCovers: ([GenerationJob]) async -> [GenerationResult]
    ) async throws -> LibraryCoverIndexingResult {
        let startedAt = Date()
        let videoCoverDirectory = coverDirectory
            .appendingPathComponent("Videos", isDirectory: true)
        let displayCoverDirectory = coverDirectory
            .appendingPathComponent("Display", isDirectory: true)
            .appendingPathComponent(
                "v\(LibraryCoverDisplayProfile.current.version)",
                isDirectory: true
            )
        try FileManager.default.createDirectory(
            at: videoCoverDirectory,
            withIntermediateDirectories: true
        )
        let commitToken = displayRenditionCommitToken
            ?? LibraryCoverDisplayRenditionCommitGate().beginGeneration()

        var jobs: [GenerationJob] = []
        var skippedFreshCoverCount = 0
        for (index, video) in videos.enumerated() {
            guard !video.hasUserCover else {
                continue
            }
            let coverURL = coverURL(for: video, in: videoCoverDirectory)
            let existingCover = try database.libraryVideoCover(forVideoFileID: video.videoFileID)
            if !affectedVideoPaths.contains(video.videoPath),
               isFreshCover(existingCover, for: video, algorithmVersion: algorithmVersion)
            {
                skippedFreshCoverCount += 1
            } else {
                jobs.append(
                    GenerationJob(
                        order: index,
                        video: video,
                        coverURL: coverURL,
                        displayURL: LibraryCoverDisplayRenditionIndexer.displayURL(
                            forVideoPath: video.videoPath,
                            in: displayCoverDirectory
                        ),
                        existingCover: existingCover
                    )
                )
            }
        }

        let results = await generateCovers(jobs)
        for result in results.sorted(by: { $0.order < $1.order }) {
            switch result.status {
            case .generated:
                guard let masterData = result.masterData,
                      let displayRendition = result.displayRendition
                else {
                    continue
                }
                guard try commitToken.commit({
                    try LibraryCoverDisplayRenditionGenerator.publish(
                        masterData,
                        to: result.coverURL
                    )
                    try LibraryCoverDisplayRenditionGenerator.publish(
                        displayRendition.data,
                        to: result.displayURL
                    )
                    try database.upsertLibraryVideoCover(
                        videoFileID: result.video.videoFileID,
                        masterCoverPath: result.coverURL.path,
                        displayCoverPath: result.displayURL.path,
                        displayProfileVersion:
                            LibraryCoverDisplayProfile.current.version,
                        sourceTimeMilliseconds: result.sourceTimeMilliseconds,
                        score: result.score,
                        algorithmVersion: algorithmVersion,
                        generatedFileSize: result.video.fileSize,
                        generatedDuration: result.video.duration,
                        status: .generated,
                        errorMessage: nil
                    )
                    return true
                }) == true else {
                    throw CancellationError()
                }
            case .failed:
                guard result.existingCover?.status != .generated else {
                    continue
                }
                guard try commitToken.commit({
                    try database.upsertLibraryVideoCover(
                        videoFileID: result.video.videoFileID,
                        masterCoverPath: result.coverURL.path,
                        sourceTimeMilliseconds: result.sourceTimeMilliseconds,
                        score: result.score,
                        algorithmVersion: algorithmVersion,
                        generatedFileSize: result.video.fileSize,
                        generatedDuration: result.video.duration,
                        status: .failed,
                        errorMessage: result.errorMessage
                    )
                    return true
                }) == true else {
                    throw CancellationError()
                }
            }
        }

        let displayIndexer = LibraryCoverDisplayRenditionIndexer(
            configuration: .init(
                coverDirectory: coverDirectory,
                commitToken: commitToken
            )
        )
        let displayBackfillResult = try await displayIndexer
            .backfillDisplayRenditions(
                videoPaths: Set(
                    videos.lazy.filter { !$0.hasUserCover }.map(\.videoPath)
                ),
                into: database
            )
        let generatedFolderPaths = Set(
            results.lazy
                .filter { $0.status == .generated }
                .map(\.video.folderPath)
        )
        try refreshFolderCoverReferences(
            for: folderReferenceVideos,
            affectedFolderPaths: affectedFolderPaths.union(
                generatedFolderPaths
            ),
            in: database
        )

        let generatedCoverCount = results.filter { $0.status == .generated }.count
        let failedCoverCount = results.filter { $0.status == .failed }.count
        return LibraryCoverIndexingResult(
            eligibleVideoCount: videos.count,
            skippedFreshCoverCount: skippedFreshCoverCount,
            generatedCoverCount: generatedCoverCount,
            failedCoverCount: failedCoverCount,
            generatedDisplayCoverCount: generatedCoverCount
                + displayBackfillResult.generatedDisplayCoverCount,
            failedDisplayCoverCount: displayBackfillResult.failedDisplayCoverCount,
            elapsedSeconds: Date().timeIntervalSince(startedAt)
        )
    }

    public static func score(
        rawFrame data: Data,
        width: Int,
        height: Int
    ) throws -> FrameMetrics {
        let pixelCount = width * height
        guard data.count >= pixelCount * 3 else {
            throw LibraryCoverGenerationError.shortFrameData(data.count, pixelCount * 3)
        }

        var lumas = [Double](repeating: 0, count: pixelCount)
        var colorHistogram = [Double](repeating: 0, count: 64)
        var lumaHistogram = [Int](repeating: 0, count: 16)
        var lumaSum = 0.0
        var lumaSquaredSum = 0.0
        var saturationSum = 0.0
        var darkCount = 0
        var brightCount = 0

        data.withUnsafeBytes { (rawBuffer: UnsafeRawBufferPointer) in
            guard let base = rawBuffer.bindMemory(to: UInt8.self).baseAddress else {
                return
            }

            for pixelIndex in 0..<pixelCount {
                let offset = pixelIndex * 3
                let r = Double(base[offset])
                let g = Double(base[offset + 1])
                let b = Double(base[offset + 2])
                let maxChannel = max(r, g, b)
                let minChannel = min(r, g, b)
                let saturation = maxChannel > 0 ? (maxChannel - minChannel) / maxChannel : 0
                let luma = ((0.299 * r) + (0.587 * g) + (0.114 * b)) / 255.0

                lumas[pixelIndex] = luma
                lumaSum += luma
                lumaSquaredSum += luma * luma
                saturationSum += saturation
                if luma < 0.08 {
                    darkCount += 1
                }
                if luma > 0.94 {
                    brightCount += 1
                }

                let rBin = min(3, Int(r / 64))
                let gBin = min(3, Int(g / 64))
                let bBin = min(3, Int(b / 64))
                colorHistogram[(rBin * 16) + (gBin * 4) + bBin] += 1
                lumaHistogram[min(15, Int(luma * 16))] += 1
            }
        }

        let sampleCount = Double(pixelCount)
        let meanLuma = lumaSum / sampleCount
        let variance = max(0, (lumaSquaredSum / sampleCount) - (meanLuma * meanLuma))
        let standardDeviation = sqrt(variance)
        let averageSaturation = saturationSum / sampleCount
        let darkRatio = Double(darkCount) / sampleCount
        let brightRatio = Double(brightCount) / sampleCount
        let dominantLumaShare = Double(lumaHistogram.max() ?? 0) / sampleCount
        let edgeScore = edgeStrengthScore(lumas: lumas, width: width, height: height)

        let exposureScore = max(0, 1 - (abs(meanLuma - 0.56) / 0.46))
        let contrastScore = min(1, standardDeviation / 0.22)
        let saturationScore = min(1, averageSaturation / 0.35)
        let rangeScore = min(1, (1 - dominantLumaShare) / 0.55)
        let blankPenalty: Double
        if darkRatio > 0.78 || brightRatio > 0.86 || standardDeviation < 0.025 || dominantLumaShare > 0.94 {
            blankPenalty = 0.08
        } else if darkRatio > 0.55 || brightRatio > 0.68 || standardDeviation < 0.05 || dominantLumaShare > 0.82 {
            blankPenalty = 0.45
        } else {
            blankPenalty = 1.0
        }

        let qualityScore = 100 * blankPenalty * (
            (0.32 * exposureScore)
            + (0.18 * contrastScore)
            + (0.18 * edgeScore)
            + (0.14 * saturationScore)
            + (0.18 * rangeScore)
        )
        let normalizedHistogram = colorHistogram.map { $0 / sampleCount }

        return FrameMetrics(
            qualityScore: max(0, min(100, qualityScore)),
            histogram: normalizedHistogram
        )
    }

    public static func edgeStrengthScore(lumas: [Double], width: Int, height: Int) -> Double {
        guard width > 1, height > 1 else {
            return 0
        }

        var edgeSum = 0.0
        var edgeCount = 0
        for y in 0..<(height - 1) {
            let rowOffset = y * width
            let nextRowOffset = (y + 1) * width
            for x in 0..<(width - 1) {
                let current = lumas[rowOffset + x]
                edgeSum += abs(current - lumas[rowOffset + x + 1])
                edgeSum += abs(current - lumas[nextRowOffset + x])
                edgeCount += 2
            }
        }

        guard edgeCount > 0 else {
            return 0
        }

        return min(1, (edgeSum / Double(edgeCount)) / 0.075)
    }

    public static func bestCandidate(from candidates: [ScoredCandidate]) -> ScoredCandidate {
        guard !candidates.isEmpty else {
            return ScoredCandidate(
                timestampMilliseconds: 0,
                qualityScore: 0,
                histogram: [],
                totalScore: 0
            )
        }

        let histogramCount = candidates[0].histogram.count
        var averageHistogram = [Double](repeating: 0, count: histogramCount)
        for candidate in candidates {
            for index in 0..<histogramCount {
                averageHistogram[index] += candidate.histogram[index]
            }
        }
        for index in 0..<histogramCount {
            averageHistogram[index] /= Double(candidates.count)
        }

        return candidates
            .map { candidate in
                let distance = zip(candidate.histogram, averageHistogram)
                    .reduce(0.0) { partial, pair in
                        partial + abs(pair.0 - pair.1)
                    }
                let relevanceScore = max(0, 1 - min(1, distance / 1.4))
                var scored = candidate
                scored.totalScore = (0.70 * candidate.qualityScore) + (30 * relevanceScore)
                return scored
            }
            .max { lhs, rhs in
                if lhs.totalScore != rhs.totalScore {
                    return lhs.totalScore < rhs.totalScore
                }

                return lhs.timestampMilliseconds < rhs.timestampMilliseconds
            } ?? candidates[0]
    }

    public static func refreshFolderCoverReferences(
        for videos: [LibraryCoverEligibleVideo],
        affectedFolderPaths: Set<String>,
        in database: any LibraryCoverPersistence
    ) throws {
        var firstGeneratedCoverByFolder: [String: (video: LibraryCoverEligibleVideo, cover: LibraryVideoCover)] = [:]

        for video in videos {
            guard firstGeneratedCoverByFolder[video.folderPath] == nil,
                  let cover = try database.libraryVideoCover(forVideoFileID: video.videoFileID),
                  isUsableGeneratedCover(cover)
            else {
                continue
            }

            firstGeneratedCoverByFolder[video.folderPath] = (video, cover)
        }

        for folderPath in affectedFolderPaths {
            if let selected = firstGeneratedCoverByFolder[folderPath] {
                try database.upsertLibraryFolderCover(
                    folderPath: folderPath,
                    masterCoverPath: selected.cover.masterCoverPath,
                    sourceVideoFileID: selected.video.videoFileID
                )
            } else {
                try database.deleteLibraryFolderCover(folderPath: folderPath)
            }
        }
    }

    public static func isFreshCover(
        _ cover: LibraryVideoCover?,
        for video: LibraryCoverEligibleVideo,
        algorithmVersion: Int = LibraryCoverCandidateScorer.algorithmVersion
    ) -> Bool {
        guard let cover,
              isUsableGeneratedCover(cover),
              cover.algorithmVersion == algorithmVersion,
              cover.generatedFileSize == video.fileSize,
              durationsMatch(cover.generatedDuration, video.duration)
        else {
            return false
        }

        return true
    }

    public static func isUsableGeneratedCover(_ cover: LibraryVideoCover) -> Bool {
        cover.status == .generated
            && FileManager.default.fileExists(atPath: cover.masterCoverPath)
    }

    public static func coverURL(for video: LibraryCoverEligibleVideo, in directory: URL) -> URL {
        let digest = SHA256.hash(data: Data(video.videoPath.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
        return directory.appendingPathComponent("\(digest).jpg")
    }

    private static func durationsMatch(_ lhs: Double?, _ rhs: Double?) -> Bool {
        switch (lhs, rhs) {
        case (nil, nil):
            return true
        case (.some(let lhs), .some(let rhs)):
            return lhs.isFinite && rhs.isFinite && abs(lhs - rhs) <= 0.25
        default:
            return false
        }
    }
}
