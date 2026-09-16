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
                URL(fileURLWithPath: $0.videoPath)
            },
            into: database
        )
    }

    @discardableResult
    public func indexDurations(
        videoFiles: [URL],
        into database: any PlaybackVideoMetadataPersistence
    ) throws -> PlaybackVideoMetadataIndexResult {
        var updatedVideoPaths = Set<String>()
        var failures: [PlaybackVideoMetadataIndexFailure] = []

        for videoFile in videoFiles {
            guard !updatedVideoPaths.contains(videoFile.path),
                  !failures.contains(where: {
                      $0.videoPath == videoFile.path
                  })
            else {
                continue
            }

            do {
                let metadata =
                    try SFXMediaMetadataInspector.metadata(
                        atMediaPath: videoFile.path
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
                updatedVideoPaths.insert(videoFile.path)
            } catch {
                failures.append(
                    PlaybackVideoMetadataIndexFailure(
                        videoPath: videoFile.path,
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
