import Foundation
import CNativePlayback
import CueSeekerCore

public struct LibraryCoverIndexer: Sendable {
    public static let algorithmVersion = LibraryCoverCandidateScorer.algorithmVersion

    public static func recommendedMaxConcurrentVideos(for folder: URL) -> Int {
        folder.isRemoteMediaURL ? 2 : ProcessInfo.processInfo.activeProcessorCount
    }

    public struct Configuration: Sendable {
        public let candidatePercentages: [Double]
        public let scoringWidth: Int
        public let scoringHeight: Int
        public let maxConcurrentVideos: Int
        public let coverDirectory: URL
        public let ffmpegPath: String?
        public let displayRenditionCommitToken: LibraryCoverDisplayRenditionCommitToken?

        /// `maxConcurrentVideos` defaults to the core count, about as many
        /// covers as ever ran at once: the 32 it used to be were held to that
        /// by the threads the covers then shared with the rest of the App.
        public init(
            candidatePercentages: [Double] = [0.20, 0.30, 0.40, 0.50, 0.60],
            scoringWidth: Int = 320,
            scoringHeight: Int = 180,
            maxConcurrentVideos: Int = ProcessInfo.processInfo.activeProcessorCount,
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

    private typealias GenerationJob = LibraryCoverCandidateScorer.GenerationJob
    private typealias GenerationResult = LibraryCoverCandidateScorer.GenerationResult
    private typealias ScoredCandidate = LibraryCoverCandidateScorer.ScoredCandidate

    /// A cover waits on ffmpeg for most of its time. It waits here, never on
    /// the threads Search, the pages and the cover images run on, which would
    /// otherwise stay taken until the last cover is done.
    private static let generationQueue = DispatchQueue(
        label: "app.cueseeker.library-cover-generation",
        qos: .utility,
        attributes: .concurrent
    )

    private let configuration: Configuration
    private let ffmpegCommand: FFmpegCommand

    public init(configuration: Configuration) {
        self.configuration = configuration
        self.ffmpegCommand = Self.resolveFFmpegCommand(configuredPath: configuration.ffmpegPath)
    }

    /// `onProgress` reports how many covers have been generated and how many
    /// were found to need generating.
    @discardableResult
    public func indexCovers(
        under folder: URL,
        affectedVideoPaths: Set<String> = [],
        affectedFolderPaths: Set<String> = [],
        into database: any LibraryCoverPersistence,
        onProgress: (@Sendable (Int, Int) -> Void)? = nil
    ) async throws -> LibraryCoverIndexingResult {
        let videos = try database.libraryCoverEligibleVideos(under: [folder])
        return try await LibraryCoverCandidateScorer.indexCovers(
            videos: videos,
            folderReferenceVideos: videos,
            affectedVideoPaths: affectedVideoPaths,
            affectedFolderPaths: affectedFolderPaths,
            coverDirectory: configuration.coverDirectory,
            displayRenditionCommitToken: configuration.displayRenditionCommitToken,
            algorithmVersion: Self.algorithmVersion,
            into: database
        ) { jobs in
            await self.generateCovers(for: jobs, onProgress: onProgress)
        }
    }

    /// A cancelled task starts no further cover once the ones already being
    /// generated finish. What they produced is kept like any other result.
    private func generateCovers(
        for jobs: [GenerationJob],
        onProgress: (@Sendable (Int, Int) -> Void)? = nil
    ) async -> [GenerationResult] {
        onProgress?(0, jobs.count)
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
                    await self.generateCoverOnGenerationQueue(for: job)
                }
            }

            while let result = await group.next() {
                results.append(result)
                onProgress?(results.count, jobs.count)
                guard nextIndex < jobs.count, !Task.isCancelled else {
                    continue
                }

                let job = jobs[nextIndex]
                nextIndex += 1
                group.addTask(priority: .utility) {
                    await self.generateCoverOnGenerationQueue(for: job)
                }
            }
        }

        return results
    }

    private func generateCoverOnGenerationQueue(
        for job: GenerationJob
    ) async -> GenerationResult {
        await withCheckedContinuation { continuation in
            Self.generationQueue.async {
                continuation.resume(returning: self.generateCover(for: job))
            }
        }
    }

    private func generateCover(for job: GenerationJob) -> GenerationResult {
        do {
            guard let duration = job.video.duration, duration.isFinite, duration > 0 else {
                throw LibraryCoverGenerationError.missingDuration
            }
            guard !configuration.candidatePercentages.isEmpty else {
                throw LibraryCoverGenerationError.emptyCandidatePercentages
            }

            if configuration.ffmpegPath == nil {
                let sampled = try sampleAndEncodeCoverInProcess(
                    videoPath: job.video.videoPath,
                    duration: duration
                )
                return GenerationResult(
                    order: job.order,
                    video: job.video,
                    coverURL: job.coverURL,
                    displayURL: job.displayURL,
                    existingCover: job.existingCover,
                    masterData: sampled.masterData,
                    displayRendition: sampled.displayRendition,
                    sourceTimeMilliseconds: sampled.best.timestampMilliseconds,
                    score: sampled.best.totalScore,
                    status: .generated,
                    errorMessage: nil
                )
            }

            let candidates = try configuration.candidatePercentages.map { percentage in
                let timestampMilliseconds = max(0, Int((duration * percentage * 1000).rounded()))
                let rawFrame = try captureScoringFrame(
                    videoPath: job.video.videoPath,
                    timestampMilliseconds: timestampMilliseconds
                )
                let metrics = try LibraryCoverCandidateScorer.score(
                    rawFrame: rawFrame,
                    width: configuration.scoringWidth,
                    height: configuration.scoringHeight
                )
                return ScoredCandidate(
                    timestampMilliseconds: timestampMilliseconds,
                    qualityScore: metrics.qualityScore,
                    histogram: metrics.histogram,
                    totalScore: metrics.qualityScore
                )
            }

            let best = LibraryCoverCandidateScorer.bestCandidate(from: candidates)
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

    private func sampleAndEncodeCoverInProcess(
        videoPath: String,
        duration: Double
    ) throws -> (
        best: ScoredCandidate,
        masterData: Data,
        displayRendition: LibraryCoverEncodedDisplayRendition
    ) {
        let timestamps = configuration.candidatePercentages.map { percentage in
            NSNumber(value: max(0, Int((duration * percentage * 1000).rounded())))
        }
        let playableInput = WebDAVClient.shared.resolvePlayableInput(
            for: URL.fromMediaPath(videoPath)
        )
        let sampledFrames = try SFXMediaMetadataInspector.sampleCoverFrames(
            atMediaPath: playableInput.inputPath,
            httpHeaders: playableInput.httpHeaders,
            timestampsMilliseconds: timestamps,
            scoringWidth: configuration.scoringWidth,
            scoringHeight: configuration.scoringHeight
        )
        var candidates: [ScoredCandidate] = []
        var frameByTimestamp: [Int: SFXMediaCoverCandidateFrame] = [:]
        candidates.reserveCapacity(sampledFrames.count)
        for sampledFrame in sampledFrames {
            let metrics = try LibraryCoverCandidateScorer.score(
                rawFrame: sampledFrame.scoringRGB24Data,
                width: configuration.scoringWidth,
                height: configuration.scoringHeight
            )
            candidates.append(
                ScoredCandidate(
                    timestampMilliseconds: sampledFrame.timestampMilliseconds,
                    qualityScore: metrics.qualityScore,
                    histogram: metrics.histogram,
                    totalScore: metrics.qualityScore
                )
            )
            frameByTimestamp[sampledFrame.timestampMilliseconds] = sampledFrame
        }
        let best = LibraryCoverCandidateScorer.bestCandidate(from: candidates)
        guard let winningFrame = frameByTimestamp[best.timestampMilliseconds] ?? sampledFrames.first else {
            throw LibraryCoverGenerationError.emptyCandidatePercentages
        }
        let masterData = try LibraryCoverDisplayRenditionGenerator.masterJPEGData(
            from: winningFrame.cgImage
        )
        let displayRendition = try LibraryCoverDisplayRenditionGenerator().encode(
            masterImage: winningFrame.cgImage
        )
        return (
            best: best,
            masterData: masterData,
            displayRendition: displayRendition
        )
    }

    private func captureScoringFrame(
        videoPath: String,
        timestampMilliseconds: Int
    ) throws -> Data {
        let timeString = Self.ffmpegTimeString(milliseconds: timestampMilliseconds)
        let size = "\(configuration.scoringWidth):\(configuration.scoringHeight)"
        let filter = "scale='max(1,round(iw*sar))':ih,scale=\(size):force_original_aspect_ratio=decrease,pad=\(size):(ow-iw)/2:(oh-ih)/2:color=black"
        let resolvedInput = WebDAVClient.shared.resolvePlayableInput(for: URL.fromMediaPath(videoPath))
        var arguments = [
            "-nostdin",
            "-hide_banner",
            "-loglevel", "error"
        ]
        if let headers = resolvedInput.httpHeaders {
            arguments += ["-headers", headers]
        }
        arguments += [
            "-ss", timeString,
            "-i", resolvedInput.inputPath,
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

        let resolvedInput = WebDAVClient.shared.resolvePlayableInput(for: URL.fromMediaPath(videoPath))
        var arguments = [
            "-nostdin",
            "-hide_banner",
            "-loglevel", "error",
            "-y"
        ]
        if let headers = resolvedInput.httpHeaders {
            arguments += ["-headers", headers]
        }
        arguments += [
            "-ss", Self.ffmpegTimeString(milliseconds: timestampMilliseconds),
            "-i", resolvedInput.inputPath,
            "-frames:v", "1",
            "-an",
            "-sn",
            "-dn",
            "-vf", "scale='max(1,round(iw*sar))':ih",
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
