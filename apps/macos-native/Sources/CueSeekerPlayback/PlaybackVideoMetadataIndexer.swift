import Foundation
import CNativePlayback
import CueSeekerCore

public struct PlaybackVideoMetadataIndexer {
    public init() {}

    @discardableResult
    public func indexDurations(
        under folder: URL,
        into database: any PlaybackVideoMetadataPersistence
    ) throws -> Int {
        let videos = try database.libraryVideos(under: [folder])
        var updatedVideoPaths = Set<String>()

        for video in videos {
            guard !updatedVideoPaths.contains(video.videoPath) else {
                continue
            }

            let metadata = try? SFXMediaMetadataInspector.metadata(atMediaPath: video.videoPath)
            try database.updateVideoMetadata(
                videoFile: URL(fileURLWithPath: video.videoPath),
                duration: metadata?.durationSeconds?.doubleValue,
                videoWidth: metadata?.videoWidth?.intValue,
                videoHeight: metadata?.videoHeight?.intValue,
                frameRate: metadata?.frameRate?.doubleValue,
                videoCodec: metadata?.videoCodec
            )
            updatedVideoPaths.insert(video.videoPath)
        }

        return updatedVideoPaths.count
    }
}
