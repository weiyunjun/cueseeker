import Foundation
import Testing
import CueSeekerCore
@testable import CueSeekerPlayback

@Test
func failedVideoMetadataInspectionDoesNotOverwriteStoredMetadata()
    throws
{
    let videoURL = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "CueSeekerInvalidVideo-\(UUID().uuidString)"
        )
        .appendingPathExtension("mkv")
    defer {
        try? FileManager.default.removeItem(at: videoURL)
    }
    try Data().write(to: videoURL)
    let persistence = VideoMetadataPersistenceStub()

    let result = try PlaybackVideoMetadataIndexer()
        .indexDurations(
            videoFiles: [videoURL],
            into: persistence
        )

    #expect(result.updatedVideoPaths.isEmpty)
    #expect(result.failures.count == 1)
    #expect(result.failures.first?.videoPath == videoURL.path)
    #expect(persistence.updateCallCount == 0)
}

private final class VideoMetadataPersistenceStub:
    PlaybackVideoMetadataPersistence,
    @unchecked Sendable
{
    private let lock = NSLock()
    private var storedUpdateCallCount = 0

    var updateCallCount: Int {
        lock.lock()
        defer {
            lock.unlock()
        }
        return storedUpdateCallCount
    }

    func libraryVideos(under folders: [URL]) throws -> [LibraryVideo] {
        []
    }

    func updateVideoMetadata(
        videoFile: URL,
        duration: Double?,
        videoWidth: Int?,
        videoHeight: Int?,
        frameRate: Double?,
        videoCodec: String?,
        audioTracks: [VideoAudioTrack]
    ) throws {
        lock.lock()
        storedUpdateCallCount += 1
        lock.unlock()
    }
}
