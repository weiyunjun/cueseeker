import Foundation

public struct ProbedVideoMediaMetadata: Equatable, Sendable {
    public let durationSeconds: Double?
    public let videoWidth: Int?
    public let videoHeight: Int?
    public let frameRate: Double?
    public let videoCodec: String?
    public let videoBitDepth: Int?
    public let videoPixelFormat: String?
    public let audioTracks: [VideoAudioTrack]

    public init(
        durationSeconds: Double?,
        videoWidth: Int?,
        videoHeight: Int?,
        frameRate: Double?,
        videoCodec: String?,
        videoBitDepth: Int? = nil,
        videoPixelFormat: String? = nil,
        audioTracks: [VideoAudioTrack]
    ) {
        self.durationSeconds = durationSeconds
        self.videoWidth = videoWidth
        self.videoHeight = videoHeight
        self.frameRate = frameRate
        self.videoCodec = videoCodec
        self.videoBitDepth = videoBitDepth
        self.videoPixelFormat = videoPixelFormat
        self.audioTracks = audioTracks
    }
}

public struct PlaybackVideoMetadataIndexFailure: Equatable, Sendable {
    public let videoPath: String
    public let reason: String

    public init(videoPath: String, reason: String) {
        self.videoPath = videoPath
        self.reason = reason
    }
}

public struct PlaybackVideoMetadataIndexResult: Equatable, Sendable {
    public let updatedVideoPaths: [String]
    public let failures: [PlaybackVideoMetadataIndexFailure]

    public init(
        updatedVideoPaths: [String],
        failures: [PlaybackVideoMetadataIndexFailure]
    ) {
        self.updatedVideoPaths = updatedVideoPaths
        self.failures = failures
    }
}

public enum PlaybackVideoMetadataIndexingError: LocalizedError, Sendable {
    case durationUnavailable

    public var errorDescription: String? {
        "Video duration is unavailable."
    }
}

public protocol PlaybackVideoMetadataPersistence: Sendable {
    func libraryVideos(under folders: [URL]) throws -> [LibraryVideo]

    func updateVideoMetadata(
        videoFile: URL,
        duration: Double?,
        videoWidth: Int?,
        videoHeight: Int?,
        frameRate: Double?,
        videoCodec: String?,
        videoBitDepth: Int?,
        videoPixelFormat: String?,
        audioTracks: [VideoAudioTrack]
    ) throws
}

public extension PlaybackVideoMetadataPersistence {
    func updateVideoMetadata(
        videoFile: URL,
        duration: Double?,
        videoWidth: Int?,
        videoHeight: Int?,
        frameRate: Double?,
        videoCodec: String?,
        audioTracks: [VideoAudioTrack]
    ) throws {
        try updateVideoMetadata(
            videoFile: videoFile,
            duration: duration,
            videoWidth: videoWidth,
            videoHeight: videoHeight,
            frameRate: frameRate,
            videoCodec: videoCodec,
            videoBitDepth: nil,
            videoPixelFormat: nil,
            audioTracks: audioTracks
        )
    }

    @discardableResult
    func indexVideoMetadata(
        under folder: URL,
        probe: (URL) throws -> ProbedVideoMediaMetadata
    ) throws -> PlaybackVideoMetadataIndexResult {
        let videos = try libraryVideos(under: [folder])
        return try indexVideoMetadata(
            videoFiles: videos.map { URL.fromMediaPath($0.videoPath) },
            probe: probe
        )
    }

    @discardableResult
    func indexVideoMetadata(
        videoFiles: [URL],
        onProgress: (@Sendable (Int, Int) -> Void)? = nil,
        probe: (URL) throws -> ProbedVideoMediaMetadata
    ) throws -> PlaybackVideoMetadataIndexResult {
        var updatedVideoPaths = Set<String>()
        var failures: [PlaybackVideoMetadataIndexFailure] = []

        onProgress?(0, videoFiles.count)

        for (offset, videoFile) in videoFiles.enumerated() {
            try Task.checkCancellation()
            defer { onProgress?(offset + 1, videoFiles.count) }
            let videoPath = videoFile.mediaPath

            guard !updatedVideoPaths.contains(videoPath),
                  !failures.contains(where: { $0.videoPath == videoPath })
            else {
                continue
            }

            do {
                let metadata = try probe(videoFile)
                guard let duration = metadata.durationSeconds,
                      duration.isFinite,
                      duration >= 0
                else {
                    throw PlaybackVideoMetadataIndexingError.durationUnavailable
                }
                try updateVideoMetadata(
                    videoFile: videoFile,
                    duration: duration,
                    videoWidth: metadata.videoWidth,
                    videoHeight: metadata.videoHeight,
                    frameRate: metadata.frameRate,
                    videoCodec: metadata.videoCodec,
                    videoBitDepth: metadata.videoBitDepth,
                    videoPixelFormat: metadata.videoPixelFormat,
                    audioTracks: metadata.audioTracks
                )
                updatedVideoPaths.insert(videoPath)
            } catch {
                failures.append(
                    PlaybackVideoMetadataIndexFailure(
                        videoPath: videoPath,
                        reason: error.localizedDescription
                    )
                )
            }
        }

        return PlaybackVideoMetadataIndexResult(
            updatedVideoPaths: updatedVideoPaths.sorted(),
            failures: failures
        )
    }
}

public protocol LibraryCoverPersistence: Sendable {
    func libraryCoverEligibleVideos(under folders: [URL]) throws -> [LibraryCoverEligibleVideo]
    func libraryCoverEligibleVideos(
        videoPaths: Set<String>
    ) throws -> [LibraryCoverEligibleVideo]
    func libraryCoverEligibleVideos(
        inFolderPaths folderPaths: Set<String>
    ) throws -> [LibraryCoverEligibleVideo]
    func libraryCoverDisplayCandidates(under folders: [URL]) throws -> [LibraryCoverDisplayCandidate]
    func libraryCoverDisplayCandidates(
        videoPaths: Set<String>
    ) throws -> [LibraryCoverDisplayCandidate]
    func libraryVideoCover(forVideoFileID videoFileID: Int64) throws -> LibraryVideoCover?

    func upsertLibraryVideoCover(
        videoFileID: Int64,
        masterCoverPath: String,
        displayCoverPath: String?,
        displayProfileVersion: Int?,
        sourceTimeMilliseconds: Int,
        score: Double?,
        algorithmVersion: Int,
        generatedFileSize: Int64?,
        generatedDuration: Double?,
        status: LibraryCoverStatus,
        errorMessage: String?
    ) throws

    func updateLibraryVideoDisplayCover(
        videoFileID: Int64,
        displayCoverPath: String?,
        displayProfileVersion: Int?
    ) throws

    func upsertLibraryFolderCover(
        folderPath: String,
        masterCoverPath: String,
        sourceVideoFileID: Int64
    ) throws

    func deleteLibraryFolderCover(folderPath: String) throws
}

public extension LibraryCoverPersistence {
    func libraryCoverEligibleVideos(
        videoPaths: Set<String>
    ) throws -> [LibraryCoverEligibleVideo] {
        let folders = Set(
            videoPaths.map {
                URL.fromMediaPath($0).deletingLastPathComponent()
            }
        )
        return try libraryCoverEligibleVideos(under: Array(folders))
            .filter { videoPaths.contains($0.videoPath) }
    }

    func libraryCoverEligibleVideos(
        inFolderPaths folderPaths: Set<String>
    ) throws -> [LibraryCoverEligibleVideo] {
        let resolvedFolderPaths = Set(folderPaths.map { path -> String in
            let url = URL.fromMediaPath(path)
            return url.isRemoteMediaURL ? url.mediaPath : url.resolvingSymlinksInPath().path
        })
        return try libraryCoverEligibleVideos(
            under: folderPaths.map(URL.fromMediaPath)
        ).filter {
            let url = URL.fromMediaPath($0.folderPath)
            let candidatePath = url.isRemoteMediaURL ? url.mediaPath : url.resolvingSymlinksInPath().path
            return resolvedFolderPaths.contains(candidatePath)
        }
    }

    func libraryCoverDisplayCandidates(
        videoPaths: Set<String>
    ) throws -> [LibraryCoverDisplayCandidate] {
        let folders = Set(
            videoPaths.map {
                URL.fromMediaPath($0).deletingLastPathComponent()
            }
        )
        return try libraryCoverDisplayCandidates(under: Array(folders))
            .filter { videoPaths.contains($0.videoPath) }
    }

    func upsertLibraryVideoCover(
        videoFileID: Int64,
        masterCoverPath: String,
        sourceTimeMilliseconds: Int,
        score: Double?,
        algorithmVersion: Int,
        generatedFileSize: Int64?,
        generatedDuration: Double?,
        status: LibraryCoverStatus,
        errorMessage: String?
    ) throws {
        try upsertLibraryVideoCover(
            videoFileID: videoFileID,
            masterCoverPath: masterCoverPath,
            displayCoverPath: nil,
            displayProfileVersion: nil,
            sourceTimeMilliseconds: sourceTimeMilliseconds,
            score: score,
            algorithmVersion: algorithmVersion,
            generatedFileSize: generatedFileSize,
            generatedDuration: generatedDuration,
            status: status,
            errorMessage: errorMessage
        )
    }
}

extension LibraryCoverDatabase: LibraryCoverPersistence {}
extension LibraryDatabase: PlaybackVideoMetadataPersistence {}
