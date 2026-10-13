import Foundation
import CNativePlayback
import CueSeekerCore

public struct PlaybackVideoMetadataIndexFailure:
    Equatable,
    Sendable
{
    public let videoPath: String
    public let reason: String
}

public struct PlaybackVideoMetadataIndexResult: Equatable, Sendable {
    public let updatedVideoPaths: [String]
    public let failures: [PlaybackVideoMetadataIndexFailure]
}

public struct PlaybackVideoMetadataIndexer {
    public init() {}

    @discardableResult
    public func indexDurations(
        under folder: URL,
        into database: any PlaybackVideoMetadataPersistence
    ) throws -> PlaybackVideoMetadataIndexResult {
        let videos = try database.libraryVideos(under: [folder])
        return try indexDurations(
            videoFiles: videos.map {
                URL.fromMediaPath($0.videoPath)
            },
            into: database
        )
    }

    @discardableResult
    public func indexDurations(
        videoFiles: [URL],
        into database: any PlaybackVideoMetadataPersistence,
        onProgress: (@Sendable (Int, Int) -> Void)? = nil
    ) throws -> PlaybackVideoMetadataIndexResult {
        var updatedVideoPaths = Set<String>()
        var failures: [PlaybackVideoMetadataIndexFailure] = []

        onProgress?(0, videoFiles.count)

        for (offset, videoFile) in videoFiles.enumerated() {
            try Task.checkCancellation()
            defer { onProgress?(offset + 1, videoFiles.count) }
            let videoPath = videoFile.mediaPath

            guard !updatedVideoPaths.contains(videoPath),
                  !failures.contains(where: {
                      $0.videoPath == videoPath
                  })
            else {
                continue
            }

            do {
                let playableInput = WebDAVClient.shared.resolvePlayableInput(
                    for: videoFile
                )
                let metadata =
                    try SFXMediaMetadataInspector.metadata(
                        atMediaPath: playableInput.inputPath,
                        httpHeaders: playableInput.httpHeaders
                    )
                guard let duration = metadata.durationSeconds?
                        .doubleValue,
                    duration.isFinite,
                    duration >= 0
                else {
                    throw PlaybackVideoMetadataIndexingError
                        .durationUnavailable
                }
                try database.updateVideoMetadata(
                    videoFile: videoFile,
                    duration: duration,
                    videoWidth: metadata.videoWidth?.intValue,
                    videoHeight: metadata.videoHeight?.intValue,
                    frameRate: metadata.frameRate?.doubleValue,
                    videoCodec: metadata.videoCodec,
                    audioTracks: metadata.audioTracks.map {
                        VideoAudioTrack(
                            language: $0.language,
                            title: $0.title,
                            codec: $0.codec,
                            channels: $0.channels?.intValue
                        )
                    }
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

private enum PlaybackVideoMetadataIndexingError: LocalizedError {
    case durationUnavailable

    var errorDescription: String? {
        "Video duration is unavailable."
    }
}
