import Foundation
import CNativePlayback
import CueSeekerCore

public struct PlaybackVideoMetadataIndexer {
    public init() {}

    @discardableResult
    public func indexDurations(
        under folder: URL,
        into database: SubtitleDatabase
    ) throws -> Int {
        let videos = try database.libraryVideos(under: [folder])
        var updatedVideoPaths = Set<String>()

        for video in videos {
            guard !updatedVideoPaths.contains(video.videoPath) else {
                continue
            }

            let durationNumber = try? SFXMediaMetadataInspector.durationSeconds(atMediaPath: video.videoPath)
            let duration = durationNumber?.doubleValue
            try database.updateVideoDuration(
                videoFile: URL(fileURLWithPath: video.videoPath),
                duration: duration
            )
            updatedVideoPaths.insert(video.videoPath)
        }

        return updatedVideoPaths.count
    }
}
