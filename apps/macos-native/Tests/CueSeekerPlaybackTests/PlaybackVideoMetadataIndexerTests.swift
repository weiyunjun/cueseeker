import Foundation
import Testing
import CNativePlayback
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

@Test
func containerProbingDetectsRealContainerAndDistinguishesWebMFromMatroska() throws {
    let tempDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerContainerProbe-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    defer {
        try? FileManager.default.removeItem(at: tempDir)
    }

    let flvDisguisedAsF4V = tempDir.appendingPathComponent("sample.f4v")
    var flvHeader = Data([
        0x46, 0x4C, 0x56, 0x01, 0x05, 0x00, 0x00, 0x00, 0x09,
        0x00, 0x00, 0x00, 0x00
    ])
    flvHeader.append(Data(repeating: 0, count: 128))
    try flvHeader.write(to: flvDisguisedAsF4V)

    let flvProbe = try SFXMediaMetadataInspector.containerProbe(
        atMediaPath: flvDisguisedAsF4V.path,
        httpHeaders: nil
    )
    #expect(
        MediaDetailFormatter.resolvedVideoContainerExtension(
            formatName: flvProbe.formatName,
            fallbackExtension: "f4v"
        ) == "flv"
    )
    let flvCollageProbe = SubtitleScreenshotExporter.probeVideoContainer(
        resolvedInputPath: flvDisguisedAsF4V.path
    )
    #expect(flvCollageProbe == .init(isMatroska: false, canSkipFindStreamInfo: false))

    // Minimal Matroska/WebM EBML header with Segment + Cluster
    let mkvDisguisedAsMP4 = tempDir.appendingPathComponent("disguised_mkv.mp4")
    let mkvBytes = Data([
        0x1A, 0x45, 0xDF, 0xA3, // EBML Header ID
        0xA3,                   // Size = 35 bytes (0x80 | 35)
        0x42, 0x86, 0x81, 0x01, // EBMLVersion = 1 (4)
        0x42, 0xF7, 0x81, 0x01, // EBMLReadVersion = 1 (4)
        0x42, 0xF2, 0x81, 0x04, // EBMLMaxIDLength = 4 (4)
        0x42, 0xF3, 0x81, 0x08, // EBMLMaxSizeLength = 8 (4)
        0x42, 0x82, 0x88, 0x6D, 0x61, 0x74, 0x72, 0x6F, 0x73, 0x6B, 0x61, // DocType = "matroska" (11)
        0x42, 0x87, 0x81, 0x04, // DocTypeVersion = 4 (4)
        0x42, 0x85, 0x81, 0x02, // DocTypeReadVersion = 2 (4)
        0x18, 0x53, 0x80, 0x67, // Segment ID
        0x01, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, // Unknown segment size
        0x1F, 0x43, 0xB6, 0x75, // Cluster ID (terminates header parsing)
        0x01, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF
    ])
    try mkvBytes.write(to: mkvDisguisedAsMP4)

    let mkvProbe = try SFXMediaMetadataInspector.containerProbe(
        atMediaPath: mkvDisguisedAsMP4.path,
        httpHeaders: nil
    )
    #expect(mkvProbe.formatName == "matroska,webm")
    #expect(
        MediaDetailFormatter.resolvedVideoContainerExtension(
            formatName: mkvProbe.formatName,
            videoCodec: "hevc",
            fallbackExtension: "mp4"
        ) == "mkv"
    )
    #expect(
        MediaDetailFormatter.resolvedVideoContainerExtension(
            formatName: mkvProbe.formatName,
            videoCodec: "vp9",
            fallbackExtension: "mp4"
        ) == "webm"
    )
    #expect(
        MediaDetailFormatter.resolvedVideoContainerExtension(
            formatName: mkvProbe.formatName,
            videoCodec: "av1",
            fallbackExtension: "mp4"
        ) == "webm"
    )

    if let ffmpegURL = SubtitleScreenshotExporter.ffmpegExecutable()?.url {
        let rawRGB = tempDir.appendingPathComponent("raw.rgb")
        try Data(repeating: 0, count: 16 * 16 * 3).write(to: rawRGB)
        let mp4DisguisedAsMKV = tempDir.appendingPathComponent("sample.mkv")
        let process = Process()
        process.executableURL = ffmpegURL
        process.arguments = [
            "-y", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", "16x16",
            "-i", rawRGB.path, "-frames:v", "1", "-c:v", "mjpeg", "-f", "mp4",
            mp4DisguisedAsMKV.path
        ]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        #expect(process.terminationStatus == 0)

        let persistence = VideoMetadataPersistenceStub()
        let result = try PlaybackVideoMetadataIndexer().indexDurations(
            videoFiles: [mp4DisguisedAsMKV],
            into: persistence
        )
        #expect(result.updatedVideoPaths == [mp4DisguisedAsMKV.path])
        #expect(persistence.lastContainerFormat == "mp4")

        let mp4CollageProbe = SubtitleScreenshotExporter.probeVideoContainer(
            resolvedInputPath: mp4DisguisedAsMKV.path
        )
        #expect(mp4CollageProbe == .init(isMatroska: false, canSkipFindStreamInfo: true))
    }
}

private final class VideoMetadataPersistenceStub:
    PlaybackVideoMetadataPersistence,
    @unchecked Sendable
{
    private let lock = NSLock()
    private var storedUpdateCallCount = 0
    private var storedContainerFormat: String?

    var updateCallCount: Int {
        lock.lock()
        defer {
            lock.unlock()
        }
        return storedUpdateCallCount
    }

    var lastContainerFormat: String? {
        lock.lock()
        defer {
            lock.unlock()
        }
        return storedContainerFormat
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
        videoBitDepth: Int?,
        videoPixelFormat: String?,
        containerFormat: String?,
        audioTracks: [VideoAudioTrack]
    ) throws {
        lock.lock()
        storedUpdateCallCount += 1
        storedContainerFormat = containerFormat
        lock.unlock()
    }
}
