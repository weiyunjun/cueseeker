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
    private var storedHDRMetadata: VideoHDRMetadata?

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

    var lastHDRMetadata: VideoHDRMetadata? {
        lock.lock()
        defer {
            lock.unlock()
        }
        return storedHDRMetadata
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
        hdrMetadata: VideoHDRMetadata?,
        audioTracks: [VideoAudioTrack]
    ) throws {
        lock.lock()
        storedUpdateCallCount += 1
        storedContainerFormat = containerFormat
        storedHDRMetadata = hdrMetadata
        lock.unlock()
    }
}

@Test
func hdrMetadataProbingHandlesSDRHDR10StaticAndMidStreamBroadcastHLG() throws {
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
        .appendingPathComponent("CueSeekerHDRProbe-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDir) }

    func runFFmpeg(_ arguments: [String]) throws {
        let process = Process()
        process.executableURL = ffmpegURL
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        #expect(process.terminationStatus == 0)
    }

    // 1. Plain SDR 8-bit MP4 -> hdrMetadata must remain nil
    let sdrMP4 = tempDir.appendingPathComponent("sdr.mp4")
    try runFFmpeg([
        "-y", "-f", "lavfi", "-i", "color=c=black:s=160x90:r=24:d=0.5",
        "-c:v", "libx264", "-pix_fmt", "yuv420p",
        "-color_primaries", "bt709", "-color_trc", "bt709", "-colorspace", "bt709",
        sdrMP4.path
    ])
    let sdrProbed = try SFXMediaMetadataInspector.metadata(atMediaPath: sdrMP4.path, httpHeaders: nil)
    #expect(sdrProbed.hdrMetadata == nil)

    // 2. HDR10 PQ BT.2020 without Mastering Display / MaxCLL -> HDR10 still detected
    let hdr10NoStaticMKV = tempDir.appendingPathComponent("hdr10_no_static.mkv")
    try runFFmpeg([
        "-y", "-f", "lavfi", "-i", "color=c=black:s=160x90:r=24:d=0.5",
        "-c:v", "libx265", "-pix_fmt", "yuv420p10le",
        "-color_primaries", "bt2020", "-color_trc", "smpte2084", "-colorspace", "bt2020nc",
        "-x265-params", "log-level=error:colorprim=bt2020:transfer=smpte2084:colormatrix=bt2020nc",
        hdr10NoStaticMKV.path
    ])
    let hdr10NoStaticPersistence = VideoMetadataPersistenceStub()
    _ = try PlaybackVideoMetadataIndexer().indexDurations(
        videoFiles: [hdr10NoStaticMKV],
        into: hdr10NoStaticPersistence
    )
    let hdr10NoStatic = try #require(hdr10NoStaticPersistence.lastHDRMetadata)
    #expect(hdr10NoStatic.standards == [.hdr10])
    #expect(hdr10NoStatic.colorPrimaries == "bt2020")
    #expect(hdr10NoStatic.transferFunction == "smpte2084")
    #expect(hdr10NoStatic.masteringDisplayPrimaries == nil)
    #expect(hdr10NoStatic.maxCLL == nil)

    // 3. HDR10 with Display P3 mastering display + MaxCLL/MaxFALL SEI
    let hdr10FullMKV = tempDir.appendingPathComponent("hdr10_full.mkv")
    try runFFmpeg([
        "-y", "-f", "lavfi", "-i", "color=c=black:s=160x90:r=24:d=0.5",
        "-c:v", "libx265", "-pix_fmt", "yuv420p10le",
        "-color_primaries", "bt2020", "-color_trc", "smpte2084", "-colorspace", "bt2020nc",
        "-x265-params", "log-level=error:hdr10=1:colorprim=bt2020:transfer=smpte2084:colormatrix=bt2020nc:master-display=G(13250,34500)B(7500,3000)R(34000,16000)WP(15635,16450)L(10000000,50):max-cll=852,185",
        hdr10FullMKV.path
    ])
    let hdr10FullPersistence = VideoMetadataPersistenceStub()
    _ = try PlaybackVideoMetadataIndexer().indexDurations(
        videoFiles: [hdr10FullMKV],
        into: hdr10FullPersistence
    )
    let hdr10Full = try #require(hdr10FullPersistence.lastHDRMetadata)
    #expect(hdr10Full.standards == [.hdr10])
    #expect(hdr10Full.masteringDisplayPrimaries == "display_p3")
    #expect(hdr10Full.masteringDisplayMinLuminance == 0.005)
    #expect(hdr10Full.masteringDisplayMaxLuminance == 1000.0)
    #expect(hdr10Full.maxCLL == 852)
    #expect(hdr10Full.maxFALL == 185)

    // 4. Spliced MPEG-TS broadcast stream: 1s BT.709 SDR intro + 2s BT.2020 HLG main feature
    let sdrIntroTS = tempDir.appendingPathComponent("intro_sdr.ts")
    let hlgMainTS = tempDir.appendingPathComponent("main_hlg.ts")
    let combinedTS = tempDir.appendingPathComponent("broadcast_intro_sdr_to_hlg.ts")
    try runFFmpeg([
        "-y", "-f", "lavfi", "-i", "color=c=black:s=160x90:r=25:d=1.0",
        "-c:v", "libx265", "-pix_fmt", "yuv420p", "-g", "15",
        "-color_primaries", "bt709", "-color_trc", "bt709", "-colorspace", "bt709",
        "-x265-params", "log-level=error:colorprim=bt709:transfer=bt709:colormatrix=bt709",
        "-f", "mpegts",
        sdrIntroTS.path
    ])
    try runFFmpeg([
        "-y", "-f", "lavfi", "-i", "color=c=blue:s=160x90:r=25:d=2.0",
        "-c:v", "libx265", "-pix_fmt", "yuv420p10le", "-g", "15",
        "-color_primaries", "bt2020", "-color_trc", "arib-std-b67", "-colorspace", "bt2020nc",
        "-x265-params", "log-level=error:colorprim=bt2020:transfer=arib-std-b67:colormatrix=bt2020nc",
        "-f", "mpegts",
        hlgMainTS.path
    ])
    var splicedData = try Data(contentsOf: sdrIntroTS)
    splicedData.append(try Data(contentsOf: hlgMainTS))
    try splicedData.write(to: combinedTS)

    let hlgPersistence = VideoMetadataPersistenceStub()
    _ = try PlaybackVideoMetadataIndexer().indexDurations(
        videoFiles: [combinedTS],
        into: hlgPersistence
    )
    let hlgProbed = try #require(hlgPersistence.lastHDRMetadata)
    #expect(hlgProbed.standards == [.hlg])
    #expect(hlgProbed.colorPrimaries == "bt2020")
    #expect(hlgProbed.transferFunction == "arib-std-b67")

    // 5. Ordinary 8-bit H.264 SDR MPEG-TS & FLV -> must return nil HDR metadata without extra seeks/decodes
    let sdrH264TS = tempDir.appendingPathComponent("sdr_h264.ts")
    try runFFmpeg([
        "-y", "-f", "lavfi", "-i", "color=c=black:s=160x90:r=25:d=0.5",
        "-c:v", "libx264", "-pix_fmt", "yuv420p",
        "-color_primaries", "bt709", "-color_trc", "bt709", "-colorspace", "bt709",
        "-f", "mpegts",
        sdrH264TS.path
    ])
    let sdrTSProbed = try SFXMediaMetadataInspector.metadata(atMediaPath: sdrH264TS.path, httpHeaders: nil)
    #expect(sdrTSProbed.videoCodec == "h264")
    #expect(sdrTSProbed.hdrMetadata == nil)

    let sdrFLV = tempDir.appendingPathComponent("sdr_h264.flv")
    try runFFmpeg([
        "-y", "-f", "lavfi", "-i", "color=c=black:s=160x90:r=25:d=0.5",
        "-c:v", "libx264", "-pix_fmt", "yuv420p",
        "-color_primaries", "bt709", "-color_trc", "bt709", "-colorspace", "bt709",
        "-f", "flv",
        sdrFLV.path
    ])
    let sdrFLVProbed = try SFXMediaMetadataInspector.metadata(atMediaPath: sdrFLV.path, httpHeaders: nil)
    #expect(sdrFLVProbed.videoCodec == "h264")
    #expect(sdrFLVProbed.hdrMetadata == nil)
}
