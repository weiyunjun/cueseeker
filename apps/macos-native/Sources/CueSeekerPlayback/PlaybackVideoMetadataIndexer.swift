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
    ) throws -> Int {
        var updatedVideoPaths = Set<String>()

        for videoFile in videoFiles {
            guard updatedVideoPaths.insert(videoFile.path).inserted else {
                continue
            }

            let metadata = try? SFXMediaMetadataInspector.metadata(
                atMediaPath: videoFile.path
            )
            try database.updateVideoMetadata(
                videoFile: videoFile,
                duration: metadata?.durationSeconds?.doubleValue,
                videoWidth: metadata?.videoWidth?.intValue,
                videoHeight: metadata?.videoHeight?.intValue,
                frameRate: metadata?.frameRate?.doubleValue,
                videoCodec: metadata?.videoCodec
            )
        }

        return updatedVideoPaths.count
    }
}
