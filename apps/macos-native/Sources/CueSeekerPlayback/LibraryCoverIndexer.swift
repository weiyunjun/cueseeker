import CryptoKit
import Foundation
import CueSeekerCore

public struct LibraryCoverIndexingResult: Equatable, Sendable {
    public let eligibleVideoCount: Int
    public let skippedFreshCoverCount: Int
    public let generatedCoverCount: Int
    public let failedCoverCount: Int
    public let generatedDisplayCoverCount: Int
    public let failedDisplayCoverCount: Int
    public let elapsedSeconds: Double
}

public struct LibraryCoverIndexer: Sendable {
    public static let algorithmVersion = 1

    public struct Configuration: Sendable {
        public let candidatePercentages: [Double]
        public let scoringWidth: Int
        public let scoringHeight: Int
        public let maxConcurrentVideos: Int
        public let coverDirectory: URL
        public let ffmpegPath: String?
        public let displayRenditionCommitToken: LibraryCoverDisplayRenditionCommitToken?

        public init(
            candidatePercentages: [Double] = [0.20, 0.30, 0.40, 0.50, 0.60],
            scoringWidth: Int = 320,
            scoringHeight: Int = 180,
            maxConcurrentVideos: Int = 32,
            coverDirectory: URL,
            ffmpegPath: String? = nil,
            displayRenditionCommitToken: LibraryCoverDisplayRenditionCommitToken? = nil
        ) {
            self.candidatePercentages = candidatePercentages
                .filter { $0.isFinite && $0 > 0 && $0 < 1 }
                .sorted()
            self.scoringWidth = max(64, scoringWidth)
            self.scoringHeight = max(36, scoringHeight)
            self.maxConcurrentVideos = max(1, maxConcurrentVideos)
            self.coverDirectory = coverDirectory
            self.ffmpegPath = ffmpegPath
            self.displayRenditionCommitToken = displayRenditionCommitToken
        }
    }

    private enum FFmpegCommand: Sendable {
        case absolute(URL)
        case environment
    }

    private struct GenerationJob: Sendable {
        let order: Int
        let video: LibraryCoverEligibleVideo
        let coverURL: URL
        let displayURL: URL
        let existingCover: LibraryVideoCover?
    }

    private struct GenerationResult: Sendable {
        let order: Int
        let video: LibraryCoverEligibleVideo
        let coverURL: URL
        let displayURL: URL
        let existingCover: LibraryVideoCover?
        let masterData: Data?
        let displayRendition: LibraryCoverEncodedDisplayRendition?
        let sourceTimeMilliseconds: Int
        let score: Double?
        let status: LibraryCoverStatus
        let errorMessage: String?
    }

    private struct ScoredCandidate {
        let timestampMilliseconds: Int
        let qualityScore: Double
        let histogram: [Double]
        var totalScore: Double
    }

    private struct FrameMetrics {
        let qualityScore: Double
        let histogram: [Double]
    }

    private let configuration: Configuration
    private let ffmpegCommand: FFmpegCommand

    public init(configuration: Configuration) {
        self.configuration = configuration
        self.ffmpegCommand = Self.resolveFFmpegCommand(configuredPath: configuration.ffmpegPath)
    }

    @discardableResult
    public func indexCovers(
        under folder: URL,
        affectedVideoPaths: Set<String> = [],
        affectedFolderPaths: Set<String> = [],
        into database: any LibraryCoverPersistence
    ) async throws -> LibraryCoverIndexingResult {
        let videos = try database.libraryCoverEligibleVideos(under: [folder])
        return try await indexCovers(
            videos: videos,
            folderReferenceVideos: videos,
            affectedVideoPaths: affectedVideoPaths,
            affectedFolderPaths: affectedFolderPaths,
            into: database
        )
    }

    private func indexCovers(
        videos: [LibraryCoverEligibleVideo],
        folderReferenceVideos: [LibraryCoverEligibleVideo],
        affectedVideoPaths: Set<String>,
        affectedFolderPaths: Set<String>,
        into database: any LibraryCoverPersistence
    ) async throws -> LibraryCoverIndexingResult {
        let startedAt = Date()
        let videoCoverDirectory = configuration.coverDirectory
            .appendingPathComponent("Videos", isDirectory: true)
        let displayCoverDirectory = configuration.coverDirectory
            .appendingPathComponent("Display", isDirectory: true)
            .appendingPathComponent(
                "v\(LibraryCoverDisplayProfile.current.version)",
                isDirectory: true
            )
        try FileManager.default.createDirectory(
            at: videoCoverDirectory,
            withIntermediateDirectories: true
        )
        let commitToken = configuration.displayRenditionCommitToken
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
               isFreshCover(existingCover, for: video)
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

        let results = await generateCovers(for: jobs)
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
                        algorithmVersion: Self.algorithmVersion,
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
                        algorithmVersion: Self.algorithmVersion,
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
                coverDirectory: configuration.coverDirectory,
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

    private func generateCovers(for jobs: [GenerationJob]) async -> [GenerationResult] {
        guard !jobs.isEmpty else {
            return []
        }

        let limit = min(configuration.maxConcurrentVideos, jobs.count)
        var nextIndex = 0
        var results: [GenerationResult] = []
        results.reserveCapacity(jobs.count)

        await withTaskGroup(of: GenerationResult.self) { group in
            for _ in 0..<limit {
                let job = jobs[nextIndex]
                nextIndex += 1
                group.addTask(priority: .utility) {
                    self.generateCover(for: job)
                }
            }

            while let result = await group.next() {
                results.append(result)
                guard nextIndex < jobs.count else {
                    continue
                }

                let job = jobs[nextIndex]
                nextIndex += 1
                group.addTask(priority: .utility) {
                    self.generateCover(for: job)
                }
            }
        }

        return results
    }

    private func generateCover(for job: GenerationJob) -> GenerationResult {
        do {
            guard let duration = job.video.duration, duration.isFinite, duration > 0 else {
                throw LibraryCoverGenerationError.missingDuration
            }
            guard !configuration.candidatePercentages.isEmpty else {
                throw LibraryCoverGenerationError.emptyCandidatePercentages
            }

            let candidates = try configuration.candidatePercentages.map { percentage in
                let timestampMilliseconds = max(0, Int((duration * percentage * 1000).rounded()))
                let rawFrame = try captureScoringFrame(
                    videoPath: job.video.videoPath,
                    timestampMilliseconds: timestampMilliseconds
                )
                let metrics = try score(rawFrame: rawFrame)
                return ScoredCandidate(
                    timestampMilliseconds: timestampMilliseconds,
                    qualityScore: metrics.qualityScore,
                    histogram: metrics.histogram,
                    totalScore: metrics.qualityScore
                )
            }

            let best = bestCandidate(from: candidates)
            let encodedCover = try encodeFullResolutionCover(
                videoPath: job.video.videoPath,
                timestampMilliseconds: best.timestampMilliseconds,
                to: job.coverURL
            )

            return GenerationResult(
                order: job.order,
                video: job.video,
                coverURL: job.coverURL,
                displayURL: job.displayURL,
                existingCover: job.existingCover,
                masterData: encodedCover.masterData,
                displayRendition: encodedCover.displayRendition,
                sourceTimeMilliseconds: best.timestampMilliseconds,
                score: best.totalScore,
                status: .generated,
                errorMessage: nil
            )
        } catch {
            return GenerationResult(
                order: job.order,
                video: job.video,
                coverURL: job.coverURL,
                displayURL: job.displayURL,
                existingCover: job.existingCover,
                masterData: nil,
                displayRendition: nil,
                sourceTimeMilliseconds: 0,
                score: nil,
                status: .failed,
                errorMessage: String(describing: error)
            )
        }
    }

    private func captureScoringFrame(
        videoPath: String,
        timestampMilliseconds: Int
    ) throws -> Data {
        let timeString = Self.ffmpegTimeString(milliseconds: timestampMilliseconds)
        let size = "\(configuration.scoringWidth):\(configuration.scoringHeight)"
        let filter = "scale=\(size):force_original_aspect_ratio=decrease,pad=\(size):(ow-iw)/2:(oh-ih)/2:color=black"
        let arguments = [
            "-nostdin",
            "-hide_banner",
            "-loglevel", "error",
            "-ss", timeString,
            "-i", videoPath,
            "-frames:v", "1",
            "-an",
            "-sn",
            "-dn",
            "-vf", filter,
            "-pix_fmt", "rgb24",
            "-f", "rawvideo",
            "pipe:1"
        ]

        let output = try runFFmpeg(arguments: arguments, capturesStandardOutput: true)
        let expectedByteCount = configuration.scoringWidth * configuration.scoringHeight * 3
        guard output.count >= expectedByteCount else {
            throw LibraryCoverGenerationError.shortFrameData(output.count, expectedByteCount)
        }

        return output.count == expectedByteCount ? output : output.prefix(expectedByteCount)
    }

    private func encodeFullResolutionCover(
        videoPath: String,
        timestampMilliseconds: Int,
        to coverURL: URL
    ) throws -> (
        masterData: Data,
        displayRendition: LibraryCoverEncodedDisplayRendition
    ) {
        try FileManager.default.createDirectory(
            at: coverURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let temporaryURL = coverURL
            .deletingLastPathComponent()
            .appendingPathComponent("\(UUID().uuidString).jpg")
        try? FileManager.default.removeItem(at: temporaryURL)
        defer {
            try? FileManager.default.removeItem(at: temporaryURL)
        }

        let arguments = [
            "-nostdin",
            "-hide_banner",
            "-loglevel", "error",
            "-y",
            "-ss", Self.ffmpegTimeString(milliseconds: timestampMilliseconds),
            "-i", videoPath,
            "-frames:v", "1",
            "-an",
            "-sn",
            "-dn",
            "-q:v", "2",
            temporaryURL.path
        ]

        _ = try runFFmpeg(arguments: arguments, capturesStandardOutput: false)
        let displayRendition = try LibraryCoverDisplayRenditionGenerator().encode(
            masterURL: temporaryURL
        )
        return (
            masterData: try Data(contentsOf: temporaryURL),
            displayRendition: displayRendition
        )
    }

    private func score(rawFrame data: Data) throws -> FrameMetrics {
        let width = configuration.scoringWidth
        let height = configuration.scoringHeight
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

    private func edgeStrengthScore(lumas: [Double], width: Int, height: Int) -> Double {
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

    private func bestCandidate(from candidates: [ScoredCandidate]) -> ScoredCandidate {
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

    private func refreshFolderCoverReferences(
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

    private func isFreshCover(
        _ cover: LibraryVideoCover?,
        for video: LibraryCoverEligibleVideo
    ) -> Bool {
        guard let cover,
              isUsableGeneratedCover(cover),
              cover.algorithmVersion == Self.algorithmVersion,
              cover.generatedFileSize == video.fileSize,
              Self.durationsMatch(cover.generatedDuration, video.duration)
        else {
            return false
        }

        return true
    }

    private func isUsableGeneratedCover(_ cover: LibraryVideoCover) -> Bool {
        cover.status == .generated
            && FileManager.default.fileExists(atPath: cover.masterCoverPath)
    }

    private func coverURL(for video: LibraryCoverEligibleVideo, in directory: URL) -> URL {
        let digest = SHA256.hash(data: Data(video.videoPath.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
        return directory.appendingPathComponent("\(digest).jpg")
    }

    private func runFFmpeg(
        arguments: [String],
        capturesStandardOutput: Bool
    ) throws -> Data {
        let process = Process()
        switch ffmpegCommand {
        case .absolute(let url):
            process.executableURL = url
            process.arguments = arguments
        case .environment:
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = ["ffmpeg"] + arguments
        }
        process.standardInput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        process.qualityOfService = .utility

        let outputPipe = capturesStandardOutput ? Pipe() : nil
        if let outputPipe {
            process.standardOutput = outputPipe
        } else {
            process.standardOutput = FileHandle.nullDevice
        }

        try process.run()
        let output = outputPipe?.fileHandleForReading.readDataToEndOfFile() ?? Data()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw LibraryCoverGenerationError.ffmpegExit(process.terminationStatus)
        }

        return output
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

    private static func ffmpegTimeString(milliseconds: Int) -> String {
        String(format: "%.3f", Double(max(0, milliseconds)) / 1000.0)
    }

    private static func resolveFFmpegCommand(configuredPath: String?) -> FFmpegCommand {
        let candidates = [
            configuredPath.map(URL.init(fileURLWithPath:)),
            Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/ffmpeg"),
            URL(fileURLWithPath: "/opt/homebrew/bin/ffmpeg"),
            URL(fileURLWithPath: "/usr/local/bin/ffmpeg")
        ].compactMap { $0 }

        for url in candidates where FileManager.default.isExecutableFile(atPath: url.path) {
            return .absolute(url)
        }

        return .environment
    }
}

private enum LibraryCoverGenerationError: Error, CustomStringConvertible {
    case missingDuration
    case emptyCandidatePercentages
    case shortFrameData(Int, Int)
    case ffmpegExit(Int32)

    var description: String {
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
