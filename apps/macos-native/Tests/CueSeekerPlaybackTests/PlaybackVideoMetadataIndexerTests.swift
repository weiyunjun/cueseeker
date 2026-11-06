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

@Test
func primaryVideoStreamSelectionAndTailDurationProbingExcludeLeadingCoverAndRecoverMissingHeaderDuration() throws {
    let candidatePaths = [
        "/opt/homebrew/bin/ffmpeg",
        "/usr/local/bin/ffmpeg",
        "/usr/bin/ffmpeg"
    ]
    guard let ffmpegPath = candidatePaths.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
        return
    }
    let ffmpegURL = URL(fileURLWithPath: ffmpegPath)
    let tempDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerStreamAndDuration-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    defer {
        try? FileManager.default.removeItem(at: tempDir)
    }

    // 1. Create an MKV where stream 0 is a 64x96 static MJPEG cover and stream 1 is a 320x180 H.264 main video.
    let leadingCoverMKV = tempDir.appendingPathComponent("leading_cover.mkv")
    let coverProcess = Process()
    coverProcess.executableURL = ffmpegURL
    coverProcess.arguments = [
        "-y",
        "-f", "lavfi", "-i", "color=c=red:s=64x96:d=0.04",
        "-f", "lavfi", "-i", "testsrc=s=320x180:r=25:d=2.0",
        "-f", "lavfi", "-i", "sine=frequency=440:sample_rate=48000:d=2.0",
        "-map", "0:v:0", "-map", "1:v:0", "-map", "2:a:0",
        "-c:v:0", "mjpeg", "-pix_fmt:v:0", "yuvj420p", "-disposition:v:0", "0",
        "-c:v:1", "libx264", "-pix_fmt:v:1", "yuv420p", "-disposition:v:1", "default",
        "-c:a:0", "aac",
        leadingCoverMKV.path
    ]
    coverProcess.standardOutput = FileHandle.nullDevice
    coverProcess.standardError = FileHandle.nullDevice
    try coverProcess.run()
    coverProcess.waitUntilExit()
    #expect(coverProcess.terminationStatus == 0)

    let coverMetadata = try SFXMediaMetadataInspector.metadata(
        atMediaPath: leadingCoverMKV.path,
        httpHeaders: nil
    )
    #expect(coverMetadata.videoCodec == "h264")
    #expect(coverMetadata.videoWidth?.intValue == 320)
    #expect(coverMetadata.videoHeight?.intValue == 180)
    #expect(coverMetadata.audioTracks.count == 1)

    // 2. Create a streamed MKV via stdout pipe so the Matroska header has no duration (0 / N/A).
    let pipedMKV = tempDir.appendingPathComponent("piped_no_header_duration.mkv")
    FileManager.default.createFile(atPath: pipedMKV.path, contents: nil)
    let outHandle = try FileHandle(forWritingTo: pipedMKV)
    let pipeProcess = Process()
    pipeProcess.executableURL = ffmpegURL
    pipeProcess.arguments = [
        "-y",
        "-f", "lavfi", "-i", "testsrc=s=320x180:r=25:d=3.0",
        "-f", "lavfi", "-i", "sine=frequency=440:sample_rate=48000:d=3.0",
        "-c:v", "libx264", "-pix_fmt", "yuv420p", "-g", "25",
        "-c:a", "aac",
        "-f", "matroska",
        "pipe:1"
    ]
    pipeProcess.standardOutput = outHandle
    pipeProcess.standardError = FileHandle.nullDevice
    try pipeProcess.run()
    pipeProcess.waitUntilExit()
    try outHandle.close()
    #expect(pipeProcess.terminationStatus == 0)

    let pipedMetadata = try SFXMediaMetadataInspector.metadata(
        atMediaPath: pipedMKV.path,
        httpHeaders: nil
    )
    let probedDuration = pipedMetadata.durationSeconds?.doubleValue ?? 0
    #expect(probedDuration >= 2.8 && probedDuration <= 3.3)

    let sampledCovers = try SFXMediaMetadataInspector.sampleCoverFrames(
        atMediaPath: pipedMKV.path,
        httpHeaders: nil,
        timestampsMilliseconds: [500, 1500, 2500],
        scoringWidth: 160,
        scoringHeight: 90
    )
    #expect(sampledCovers.count == 3)
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
