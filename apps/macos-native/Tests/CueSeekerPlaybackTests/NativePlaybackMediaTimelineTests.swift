import CNativePlayback
import CueSeekerPlayback
import Foundation
import Testing

@Test
@MainActor
func nativePlaybackUsesCommonTimelineWhenVideoTrackStartsAfterAudio() async throws {
    guard let ffmpegURL = executableURL(named: "ffmpeg") else {
        print("Skipping media timeline regression test because ffmpeg is unavailable.")
        return
    }

    let directory = temporaryMediaTimelineTestDirectory()
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer {
        try? FileManager.default.removeItem(at: directory)
    }

    let mediaURL = directory.appendingPathComponent("late-video-start.mkv")
    try runProcess(
        ffmpegURL,
        arguments: [
            "-hide_banner",
            "-loglevel",
            "error",
            "-f",
            "lavfi",
            "-i",
            "testsrc2=duration=2.5:size=160x90:rate=24",
            "-f",
            "lavfi",
            "-i",
            "sine=frequency=440:duration=5",
            "-filter_complex",
            "[0:v]setpts=PTS+2/TB[v]",
            "-map",
            "[v]",
            "-map",
            "1:a",
            "-c:v",
            "libx264",
            "-preset",
            "ultrafast",
            "-g",
            "12",
            "-pix_fmt",
            "yuv420p",
            "-c:a",
            "aac",
            "-y",
            mediaURL.path
        ]
    )

    let player = SFXNativePlaybackPlayer()
    player.decodeMode = SFXNativePlaybackDecodeMode(rawValue: 1)!
    defer {
        player.stop()
    }

    try player.openPath(mediaURL.path, startMilliseconds: 3_000)
    try player.setPaused(false)

    let producedFrame = await waitUntil(timeoutSeconds: 4) {
        player.nativePresentedVideoFrameCount > 0
            && player.nativeLastSubmittedVideoFrameMilliseconds >= 0
    }

    #expect(producedFrame)
    #expect(player.nativeLastSubmittedVideoFrameMilliseconds >= 3_000)
    #expect(player.nativeLastSubmittedVideoFrameMilliseconds < 4_500)
}

@Test
@MainActor
func nativePlaybackRebuildsAudioOutputAndContinuesInCurrentSession() async throws {
    guard let ffmpegURL = executableURL(named: "ffmpeg") else {
        print("Skipping audio output recovery regression test because ffmpeg is unavailable.")
        return
    }

    let directory = temporaryMediaTimelineTestDirectory()
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer {
        try? FileManager.default.removeItem(at: directory)
    }

    let mediaURL = directory.appendingPathComponent("audio-output-recovery.mkv")
    try runProcess(
        ffmpegURL,
        arguments: [
            "-hide_banner",
            "-loglevel",
            "error",
            "-f",
            "lavfi",
            "-i",
            "testsrc2=duration=15:size=160x90:rate=24",
            "-f",
            "lavfi",
            "-i",
            "sine=frequency=440:duration=15",
            "-c:v",
            "libx264",
            "-preset",
            "ultrafast",
            "-g",
            "12",
            "-pix_fmt",
            "yuv420p",
            "-c:a",
            "aac",
            "-shortest",
            "-y",
            mediaURL.path
        ]
    )

    let player = SFXNativePlaybackPlayer()
    let delegate = NativePlaybackCompletionDelegate()
    player.delegate = delegate
    player.decodeMode = SFXNativePlaybackDecodeMode(rawValue: 1)!
    defer {
        player.stop()
    }

    try player.openPath(mediaURL.path, startMilliseconds: 0)
    try player.setPaused(false)

    let started = await waitUntil(timeoutSeconds: 5) {
        player.nativePresentedVideoFrameCount > 0
            && player.nativeAudioPlayedBackBufferCount > 0
    }
    #expect(started)

    let openCountBeforeRecovery = player.nativeSessionOpenCount
    let seekCountBeforeRecovery = player.nativeInSessionSeekCount
    let audioCountBeforeRecovery = player.nativeAudioPlayedBackBufferCount
    let unexpectedDrainCountBeforeRecovery = player.nativeUnexpectedAudioDrainCount

    player.requestAudioOutputRecoveryForTesting()

    let recovered = await waitUntil(timeoutSeconds: 10) {
        player.nativeAudioOutputRecoveryCount == 1
    }
    #expect(recovered)
    #expect(player.nativeSessionOpenCount == openCountBeforeRecovery)
    #expect(player.nativeInSessionSeekCount == seekCountBeforeRecovery)
    #expect(player.nativeUnexpectedAudioDrainCount == unexpectedDrainCountBeforeRecovery)
    #expect(!delegate.hasFailures)

    let audioContinued = await waitUntil(timeoutSeconds: 10) {
        player.nativeAudioPlayedBackBufferCount > audioCountBeforeRecovery
    }
    #expect(audioContinued)
    #expect(player.isPlaying)
}

@Test
@MainActor
func nativePlaybackNotifiesNaturalCompletionAfterAudioDrain() async throws {
    guard let ffmpegURL = executableURL(named: "ffmpeg") else {
        print("Skipping native completion regression test because ffmpeg is unavailable.")
        return
    }

    let directory = temporaryMediaTimelineTestDirectory()
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer {
        try? FileManager.default.removeItem(at: directory)
    }

    let mediaURL = directory.appendingPathComponent("natural-completion.mkv")
    try runProcess(
        ffmpegURL,
        arguments: [
            "-hide_banner",
            "-loglevel",
            "error",
            "-f",
            "lavfi",
            "-i",
            "testsrc2=duration=1:size=160x90:rate=24",
            "-f",
            "lavfi",
            "-i",
            "sine=frequency=440:duration=1",
            "-c:v",
            "libx264",
            "-preset",
            "ultrafast",
            "-pix_fmt",
            "yuv420p",
            "-c:a",
            "aac",
            "-shortest",
            "-y",
            mediaURL.path
        ]
    )

    let player = SFXNativePlaybackPlayer()
    let delegate = NativePlaybackCompletionDelegate()
    player.delegate = delegate
    player.decodeMode = SFXNativePlaybackDecodeMode(rawValue: 1)!
    defer {
        player.stop()
    }

    try player.openPath(mediaURL.path, startMilliseconds: 0)
    try player.setPaused(false)

    let completed = await waitUntil(timeoutSeconds: 5) {
        delegate.completionCount == 1
    }

    #expect(completed)
    #expect(delegate.audioOutputWasDrained)
    #expect(!delegate.hasFailures)

    player.stop()

    let playbackPlayer = PlaybackPlayer()
    let playbackDelegate = PlaybackNaturalCompletionDelegate()
    playbackPlayer.delegate = playbackDelegate
    defer {
        try? playbackPlayer.stop()
    }
    _ = try playbackPlayer.open(
        PlaybackRequest(
            videoURL: mediaURL,
            startMilliseconds: 0
        )
    )
    try playbackPlayer.setPaused(false)

    let wrapperCompleted = await waitUntil(timeoutSeconds: 5) {
        playbackDelegate.completionCount == 1
    }

    #expect(wrapperCompleted)
    #expect(playbackPlayer.currentVideoURL == nil)
    #expect(!playbackDelegate.hasFailures)
}

@Test
@MainActor
func nativeAutoStopKeepsSessionAliveAndResumesFromBoundary() async throws {
    guard let ffmpegURL = executableURL(named: "ffmpeg") else {
        print("Skipping native auto-stop regression test because ffmpeg is unavailable.")
        return
    }

    let directory = temporaryMediaTimelineTestDirectory()
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer {
        try? FileManager.default.removeItem(at: directory)
    }

    let mediaURL = directory.appendingPathComponent("auto-stop-resume.mkv")
    try runProcess(
        ffmpegURL,
        arguments: [
            "-hide_banner",
            "-loglevel",
            "error",
            "-f",
            "lavfi",
            "-i",
            "testsrc2=duration=4:size=160x90:rate=24",
            "-f",
            "lavfi",
            "-i",
            "sine=frequency=440:duration=4",
            "-c:v",
            "libx264",
            "-preset",
            "ultrafast",
            "-g",
            "12",
            "-pix_fmt",
            "yuv420p",
            "-c:a",
            "aac",
            "-shortest",
            "-y",
            mediaURL.path
        ]
    )

    let boundaryMilliseconds = 1_500
    let player = SFXNativePlaybackPlayer()
    let delegate = NativeAutoStopDelegate()
    player.delegate = delegate
    player.decodeMode = SFXNativePlaybackDecodeMode(rawValue: 1)!
    defer {
        player.stop()
    }

    try player.openPath(
        mediaURL.path,
        startMilliseconds: 0,
        autoStopAtMilliseconds: boundaryMilliseconds
    )
    try player.setPaused(false)

    let reachedBoundary = await waitUntil(timeoutSeconds: 5) {
        delegate.reachedBoundaryMilliseconds == boundaryMilliseconds
    }
    #expect(reachedBoundary)
    #expect(!player.isPlaying)
    #expect(delegate.naturalCompletionCount == 0)
    #expect(player.nativeLastSubmittedVideoFrameMilliseconds < boundaryMilliseconds)
    let openCountAtBoundary = player.nativeSessionOpenCount
    let seekCountAtBoundary = player.nativeInSessionSeekCount

    try player.seek(toMilliseconds: boundaryMilliseconds)
    try player.setPaused(false)

    let resumedPastBoundary = await waitUntil(timeoutSeconds: 5) {
        player.nativeLastSubmittedVideoFrameMilliseconds >= boundaryMilliseconds
    }
    #expect(resumedPastBoundary)
    #expect(player.nativeSessionOpenCount == openCountAtBoundary)
    #expect(player.nativeInSessionSeekCount == seekCountAtBoundary + 1)
}

@Test
@MainActor
func playbackPlayerKeepsAutoPauseBoundaryAcrossUserSeeks() async throws {
    guard let ffmpegURL = executableURL(named: "ffmpeg") else {
        print("Skipping Auto Pause seek regression test because ffmpeg is unavailable.")
        return
    }

    let directory = temporaryMediaTimelineTestDirectory()
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer {
        try? FileManager.default.removeItem(at: directory)
    }

    let mediaURL = directory.appendingPathComponent("auto-pause-seek.mkv")
    try runProcess(
        ffmpegURL,
        arguments: [
            "-hide_banner",
            "-loglevel",
            "error",
            "-f",
            "lavfi",
            "-i",
            "testsrc2=duration=4:size=160x90:rate=24",
            "-f",
            "lavfi",
            "-i",
            "sine=frequency=440:duration=4",
            "-c:v",
            "libx264",
            "-preset",
            "ultrafast",
            "-g",
            "12",
            "-pix_fmt",
            "yuv420p",
            "-c:a",
            "aac",
            "-shortest",
            "-y",
            mediaURL.path
        ]
    )

    let staleBoundaryMilliseconds = 1_000
    let boundaryMilliseconds = 1_500
    let player = PlaybackPlayer()
    let delegate = PlaybackPlayerAutoPauseDelegate()
    player.delegate = delegate
    defer {
        try? player.stop()
    }

    _ = try player.open(PlaybackRequest(
        videoURL: mediaURL,
        startMilliseconds: 0,
        autoStopAtMilliseconds: staleBoundaryMilliseconds
    ))
    player.setAutoPauseBoundary(PlaybackAutoStopBoundary(
        startMilliseconds: 500,
        endMilliseconds: boundaryMilliseconds
    ))
    _ = try player.seek(toMilliseconds: 500)
    try player.setPaused(false)

    let reachedFirstPass = await waitUntil(timeoutSeconds: 5) {
        delegate.boundaryEventCount == 1
    }
    #expect(reachedFirstPass)
    #expect(delegate.lastBoundaryMilliseconds == boundaryMilliseconds)

    _ = try player.seek(toMilliseconds: 2_500, pauseAfterFirstFrame: true)
    try player.setPaused(false)
    try? await Task.sleep(nanoseconds: 250_000_000)
    #expect(delegate.boundaryEventCount == 1)

    _ = try player.seek(toMilliseconds: 500, pauseAfterFirstFrame: true)
    try? await Task.sleep(nanoseconds: 250_000_000)
    #expect(delegate.boundaryEventCount == 1)
    try player.setPaused(false)

    let reachedSecondPass = await waitUntil(timeoutSeconds: 5) {
        delegate.boundaryEventCount == 2
    }
    #expect(reachedSecondPass)

    let rejectedBoundary = PlaybackAutoStopBoundary(
        startMilliseconds: 500,
        endMilliseconds: 2_500
    )
    player.setAutoPauseBoundary(rejectedBoundary)
    _ = try player.seek(to: rejectedBoundary)
    player.setAutoPauseBoundary(nil)
    try player.setPaused(false)

    let continuedPastRejectedBoundary = await waitUntil(timeoutSeconds: 5) {
        delegate.lastPlaybackMilliseconds >= 3_000
    }
    #expect(continuedPastRejectedBoundary)
    #expect(delegate.boundaryEventCount == 2)
    #expect(!delegate.isPaused)
}

private final class NativeAutoStopDelegate: NSObject, SFXNativePlaybackPlayerDelegate {
    private let lock = NSLock()
    private var boundaryMilliseconds: Int?
    private var naturalCompletions = 0

    func nativePlaybackPlayer(
        _ player: SFXNativePlaybackPlayer,
        didUpdateTime time: Double,
        duration: Double,
        playing: Bool
    ) {}

    func nativePlaybackPlayer(
        _ player: SFXNativePlaybackPlayer,
        didFailWithMessage message: String
    ) {}

    func nativePlaybackPlayer(
        _ player: SFXNativePlaybackPlayer,
        didReachAutoStopBoundaryAtMilliseconds endMilliseconds: Int
    ) {
        lock.lock()
        boundaryMilliseconds = endMilliseconds
        lock.unlock()
    }

    func nativePlaybackPlayerDidFinishPlayback(
        _ player: SFXNativePlaybackPlayer
    ) {
        lock.lock()
        naturalCompletions += 1
        lock.unlock()
    }

    var reachedBoundaryMilliseconds: Int? {
        lock.lock()
        defer { lock.unlock() }
        return boundaryMilliseconds
    }

    var naturalCompletionCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return naturalCompletions
    }
}

private final class NativePlaybackCompletionDelegate: NSObject, SFXNativePlaybackPlayerDelegate {
    private let lock = NSLock()
    private var completions = 0
    private var audioWasDrained = false
    private var failures: [String] = []

    func nativePlaybackPlayer(
        _ player: SFXNativePlaybackPlayer,
        didUpdateTime time: Double,
        duration: Double,
        playing: Bool
    ) {}

    func nativePlaybackPlayer(
        _ player: SFXNativePlaybackPlayer,
        didFailWithMessage message: String
    ) {
        lock.lock()
        failures.append(message)
        lock.unlock()
    }

    func nativePlaybackPlayerDidFinishPlayback(
        _ player: SFXNativePlaybackPlayer
    ) {
        lock.lock()
        completions += 1
        audioWasDrained = player.nativeAudioOutputDrained
        lock.unlock()
    }

    var completionCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return completions
    }

    var audioOutputWasDrained: Bool {
        lock.lock()
        defer { lock.unlock() }
        return audioWasDrained
    }

    var hasFailures: Bool {
        lock.lock()
        defer { lock.unlock() }
        return !failures.isEmpty
    }
}

private final class PlaybackPlayerAutoPauseDelegate: PlaybackPlayerDelegate {
    private let lock = NSLock()
    private var boundaryEvents = 0
    private var lastBoundary: Int?
    private var playbackMilliseconds = 0
    private var paused = true

    func player(
        _ player: PlaybackPlayer,
        didChangeProperty name: String,
        value: PlaybackPropertyValue?
    ) {
        lock.lock()
        if name == "time-pos", case .double(let seconds) = value {
            playbackMilliseconds = max(0, Int((seconds * 1_000).rounded(.down)))
        } else if name == "pause", case .bool(let isPaused) = value {
            paused = isPaused
        }
        lock.unlock()
    }

    func player(_ player: PlaybackPlayer, didFailWithMessage message: String) {}

    func player(
        _ player: PlaybackPlayer,
        didReachAutoStopBoundaryAtMilliseconds endMilliseconds: Int
    ) {
        lock.lock()
        boundaryEvents += 1
        lastBoundary = endMilliseconds
        lock.unlock()
    }

    var boundaryEventCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return boundaryEvents
    }

    var lastBoundaryMilliseconds: Int? {
        lock.lock()
        defer { lock.unlock() }
        return lastBoundary
    }

    var lastPlaybackMilliseconds: Int {
        lock.lock()
        defer { lock.unlock() }
        return playbackMilliseconds
    }

    var isPaused: Bool {
        lock.lock()
        defer { lock.unlock() }
        return paused
    }
}

private final class PlaybackNaturalCompletionDelegate: PlaybackPlayerDelegate {
    private let lock = NSLock()
    private var completions = 0
    private var failures: [String] = []

    func player(
        _ player: PlaybackPlayer,
        didChangeProperty name: String,
        value: PlaybackPropertyValue?
    ) {}

    func player(_ player: PlaybackPlayer, didFailWithMessage message: String) {
        lock.lock()
        failures.append(message)
        lock.unlock()
    }

    func playerDidFinishPlayback(_ player: PlaybackPlayer) {
        lock.lock()
        completions += 1
        lock.unlock()
    }

    var completionCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return completions
    }

    var hasFailures: Bool {
        lock.lock()
        defer { lock.unlock() }
        return !failures.isEmpty
    }
}

private func executableURL(named name: String) -> URL? {
    let searchPaths = [
        "/opt/homebrew/bin/\(name)",
        "/usr/local/bin/\(name)",
        "/usr/bin/\(name)"
    ] + ProcessInfo.processInfo.environment["PATH", default: ""]
        .split(separator: ":")
        .map { "\($0)/\(name)" }

    return searchPaths
        .map(URL.init(fileURLWithPath:))
        .first { FileManager.default.isExecutableFile(atPath: $0.path) }
}

private func runProcess(_ executableURL: URL, arguments: [String]) throws {
    let process = Process()
    process.executableURL = executableURL
    process.arguments = arguments
    let errorPipe = Pipe()
    process.standardError = errorPipe

    try process.run()
    process.waitUntilExit()

    guard process.terminationStatus == 0 else {
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let message = String(data: errorData, encoding: .utf8) ?? "unknown error"
        throw NSError(
            domain: "CueSeekerPlaybackTests.Process",
            code: Int(process.terminationStatus),
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }
}

private func temporaryMediaTimelineTestDirectory() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerMediaTimelineTests-\(UUID().uuidString)", isDirectory: true)
}

@MainActor
private func waitUntil(timeoutSeconds: TimeInterval, condition: @escaping () -> Bool) async -> Bool {
    let deadline = Date().addingTimeInterval(timeoutSeconds)
    while Date() < deadline {
        if condition() {
            return true
        }
        try? await Task.sleep(nanoseconds: 50_000_000)
    }
    return condition()
}

@Test
@MainActor
func nativePlaybackOpensAndSwitchesAudioTracksCountedAmongAudioStreams() async throws {
    guard let ffmpegURL = executableURL(named: "ffmpeg") else {
        print("Skipping audio track test because ffmpeg is unavailable.")
        return
    }

    let directory = temporaryMediaTimelineTestDirectory()
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer {
        try? FileManager.default.removeItem(at: directory)
    }

    let mediaURL = directory.appendingPathComponent("audio-tracks.mkv")
    try runProcess(
        ffmpegURL,
        arguments: [
            "-hide_banner", "-loglevel", "error",
            "-f", "lavfi", "-i", "testsrc2=duration=6:size=160x90:rate=24",
            "-f", "lavfi", "-i", "sine=frequency=440:duration=6",
            "-f", "lavfi", "-i", "sine=frequency=880:duration=6",
            "-map", "0:v", "-map", "1:a", "-map", "2:a",
            "-c:v", "libx264", "-preset", "ultrafast", "-g", "12", "-pix_fmt", "yuv420p",
            "-c:a", "aac", "-ac:a:1", "2",
            "-metadata:s:a:0", "language=jpn",
            "-metadata:s:a:1", "language=eng",
            "-metadata:s:a:1", "title=Commentary",
            "-shortest", "-y", mediaURL.path
        ]
    )

    let metadata = try SFXMediaMetadataInspector.metadata(atMediaPath: mediaURL.path)
    #expect(metadata.audioTracks.map(\.language) == ["jpn", "eng"])
    #expect(metadata.audioTracks.map(\.title) == [nil, "Commentary"])
    #expect(metadata.audioTracks.map(\.codec) == ["aac", "aac"])
    #expect(metadata.audioTracks.map { $0.channels?.intValue } == [1, 2])

    // Hardware decode: a software session reopens itself once after its first
    // frame, which would drop the pause this test checks.
    let player = SFXNativePlaybackPlayer()
    player.decodeMode = SFXNativePlaybackDecodeMode(rawValue: 0)!
    defer {
        player.stop()
    }

    player.audioTrackIndex = 1
    try player.openPath(mediaURL.path, startMilliseconds: 0)
    #expect(player.currentAudioTrackIndex == 1)

    // A track the file does not have plays the first one.
    player.audioTrackIndex = 5
    try player.openPath(mediaURL.path, startMilliseconds: 0)
    #expect(player.currentAudioTrackIndex == 0)

    // Switching keeps the position and the pause.
    try player.seek(toMilliseconds: 2_000, pauseAfterFirstFrame: true)
    let pausedAtTarget = await waitUntil(timeoutSeconds: 5) {
        player.nativePresentedVideoFrameCount > 0
            && !player.isPlaying
            && abs(player.currentTime - 2) < 0.5
    }
    #expect(pausedAtTarget)

    try player.selectAudioTrackIndex(1)
    #expect(player.currentAudioTrackIndex == 1)
    #expect(player.audioTrackIndex == 1)
    try await Task.sleep(nanoseconds: 500_000_000)
    #expect(!player.isPlaying)
    #expect(abs(player.currentTime - 2) < 0.5)
}

@Test
@MainActor
func nativePlaybackOpensAndSeeksMatroskaWithAttachmentsChaptersAndTags() async throws {
    guard let ffmpegURL = executableURL(named: "ffmpeg") else {
        print("Skipping Matroska SeekHead/Cues regression test because ffmpeg is unavailable.")
        return
    }

    let directory = temporaryMediaTimelineTestDirectory()
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer {
        try? FileManager.default.removeItem(at: directory)
    }

    let dummyFontURL = directory.appendingPathComponent("DummyFont.ttf")
    try Data(repeating: 0x42, count: 64 * 1024).write(to: dummyFontURL)

    let ffmetadataURL = directory.appendingPathComponent("chapters.txt")
    let ffmetadata = """
    ;FFMETADATA1
    title=Matroska SeekHead Test
    [CHAPTER]
    TIMEBASE=1/1000
    START=0
    END=3000
    title=Part A
    [CHAPTER]
    TIMEBASE=1/1000
    START=3000
    END=6000
    title=Part B
    """
    try ffmetadata.write(to: ffmetadataURL, atomically: true, encoding: .utf8)

    let mediaURL = directory.appendingPathComponent("seekhead-attachments-tags.mkv")
    try runProcess(
        ffmpegURL,
        arguments: [
            "-hide_banner", "-loglevel", "error",
            "-f", "lavfi", "-i", "testsrc2=duration=6:size=160x90:rate=24",
            "-f", "lavfi", "-i", "sine=frequency=440:duration=6",
            "-i", ffmetadataURL.path,
            "-map_metadata", "2",
            "-map_chapters", "2",
            "-map", "0:v", "-map", "1:a",
            "-attach", dummyFontURL.path,
            "-metadata:s:t:0", "mimetype=application/x-truetype-font",
            "-c:v", "libx264", "-preset", "ultrafast", "-g", "12", "-pix_fmt", "yuv420p",
            "-c:a", "aac",
            "-shortest", "-y", mediaURL.path
        ]
    )

    let metadata = try SFXMediaMetadataInspector.metadata(atMediaPath: mediaURL.path)
    #expect(abs((metadata.durationSeconds?.doubleValue ?? 0) - 6.0) < 0.5)
    #expect(metadata.videoWidth?.intValue == 160)
    #expect(metadata.videoHeight?.intValue == 90)
    #expect(metadata.audioTracks.count == 1)

    let player = SFXNativePlaybackPlayer()
    player.decodeMode = SFXNativePlaybackDecodeMode(rawValue: 0)!
    defer {
        player.stop()
    }

    try player.openPath(mediaURL.path, startMilliseconds: 2_500)
    try player.setPaused(false)

    let initialFramePresented = await waitUntil(timeoutSeconds: 4) {
        player.nativePresentedVideoFrameCount > 0
            && player.nativeLastSubmittedVideoFrameMilliseconds >= 2_400
    }
    #expect(initialFramePresented)

    try player.seek(toMilliseconds: 4_200, pauseAfterFirstFrame: true)
    let soughtFramePresented = await waitUntil(timeoutSeconds: 4) {
        !player.isPlaying
            && abs(player.currentTime - 4.2) < 0.5
    }
    #expect(soughtFramePresented)
}

@Test
func nativePlaybackHardwareDecodeFormatCheckMatrix() {
    for supportedHEVCFormat in [
        "yuv420p", "yuvj420p", "yuv420p10le",
        "yuv422p", "yuv422p10le",
        "yuv444p", "yuv444p10le"
    ] {
        #expect(
            PlaybackHardwareCapabilities.isHardwareDecodeSupported(
                forCodec: "hevc",
                pixelFormat: supportedHEVCFormat
            ),
            "Expected HEVC \(supportedHEVCFormat) to be hardware decode supported"
        )
    }

    for unsupportedHEVCFormat in [
        "yuv420p12le", "yuv422p12le", "yuv444p12le",
        "gbrp", "gbrp10le", "gbrp12le",
        "gray", "gray10le"
    ] {
        #expect(
            !PlaybackHardwareCapabilities.isHardwareDecodeSupported(
                forCodec: "hevc",
                pixelFormat: unsupportedHEVCFormat
            ),
            "Expected HEVC \(unsupportedHEVCFormat) to fall back to software decode"
        )
    }

    for supportedVP9Format in ["yuv420p", "yuv420p10le"] {
        #expect(
            PlaybackHardwareCapabilities.isHardwareDecodeSupported(
                forCodec: "vp9",
                pixelFormat: supportedVP9Format
            ),
            "Expected VP9 \(supportedVP9Format) to be hardware decode supported"
        )
    }

    for unsupportedVP9Format in [
        "yuv420p12le",
        "yuv422p", "yuv422p10le", "yuv422p12le",
        "yuv444p", "yuv444p10le", "yuv444p12le",
        "gbrp"
    ] {
        #expect(
            !PlaybackHardwareCapabilities.isHardwareDecodeSupported(
                forCodec: "vp9",
                pixelFormat: unsupportedVP9Format
            ),
            "Expected VP9 \(unsupportedVP9Format) to fall back to software decode"
        )
    }

    let deviceSupportsAV1 = PlaybackHardwareCapabilities.isHardwareDecodeSupported(forCodec: "av1")
    for supportedAV1Format in ["yuv420p", "yuv420p10le"] {
        #expect(
            PlaybackHardwareCapabilities.isHardwareDecodeSupported(
                forCodec: "av1",
                pixelFormat: supportedAV1Format
            ) == deviceSupportsAV1
        )
    }
    for unsupportedAV1Format in [
        "yuv420p12le",
        "yuv422p", "yuv422p10le", "yuv422p12le",
        "yuv444p", "yuv444p10le", "yuv444p12le",
        "gbrp", "gray", "gray10le"
    ] {
        #expect(
            !PlaybackHardwareCapabilities.isHardwareDecodeSupported(
                forCodec: "av1",
                pixelFormat: unsupportedAV1Format
            ),
            "Expected AV1 \(unsupportedAV1Format) to fall back to software decode even on M3/M4+"
        )
    }

    for supportedH264Format in ["yuv420p", "yuvj420p"] {
        #expect(
            PlaybackHardwareCapabilities.isHardwareDecodeSupported(
                forCodec: "h264",
                pixelFormat: supportedH264Format
            )
        )
    }
    for unsupportedH264Format in [
        "yuv420p10le", "yuv420p12le",
        "yuv422p", "yuv422p10le",
        "yuv444p", "yuv444p10le",
        "gbrp"
    ] {
        #expect(
            !PlaybackHardwareCapabilities.isHardwareDecodeSupported(
                forCodec: "h264",
                pixelFormat: unsupportedH264Format
            ),
            "Expected H.264 \(unsupportedH264Format) to fall back to software decode"
        )
    }
}

@Test
@MainActor
func nativePlaybackFallsBackToSoftwareAndPresentsFramesForHEVC12BitAndVP9HighChroma() async throws {
    guard let ffmpegURL = executableURL(named: "ffmpeg") else {
        print("Skipping 12-bit/high-chroma hardware fallback test because ffmpeg is unavailable.")
        return
    }

    let directory = temporaryMediaTimelineTestDirectory()
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer {
        try? FileManager.default.removeItem(at: directory)
    }

    let cases: [(name: String, videoArgs: [String])] = [
        (
            name: "hevc-12bit.mkv",
            videoArgs: ["-c:v", "libx265", "-x265-params", "log-level=none:keyint=12", "-pix_fmt", "yuv420p12le"]
        ),
        (
            name: "vp9-12bit.mkv",
            videoArgs: ["-c:v", "libvpx-vp9", "-g", "12", "-pix_fmt", "yuv420p12le"]
        ),
        (
            name: "vp9-444.mkv",
            videoArgs: ["-c:v", "libvpx-vp9", "-g", "12", "-pix_fmt", "yuv444p"]
        ),
        (
            name: "h264-10bit.mkv",
            videoArgs: ["-c:v", "libx264", "-preset", "ultrafast", "-g", "12", "-pix_fmt", "yuv420p10le"]
        )
    ]

    for testCase in cases {
        let mediaURL = directory.appendingPathComponent(testCase.name)
        var arguments = [
            "-hide_banner", "-loglevel", "error",
            "-f", "lavfi", "-i", "testsrc2=duration=3:size=160x90:rate=24",
            "-f", "lavfi", "-i", "sine=frequency=440:duration=3"
        ]
        arguments.append(contentsOf: testCase.videoArgs)
        arguments.append(contentsOf: ["-c:a", "aac", "-shortest", "-y", mediaURL.path])
        try runProcess(ffmpegURL, arguments: arguments)

        let player = SFXNativePlaybackPlayer()
        player.decodeMode = SFXNativePlaybackDecodeMode(rawValue: 0)! // Hardware
        defer {
            player.stop()
        }

        try player.openPath(mediaURL.path, startMilliseconds: 0)
        #expect(!player.usingHardwareDecode, "Expected \(testCase.name) to fall back to software decode")
        try player.setPaused(false)

        let initialPresented = await waitUntil(timeoutSeconds: 4) {
            player.nativePresentedVideoFrameCount > 0
                && player.nativeLastSubmittedVideoFrameMilliseconds >= 0
        }
        #expect(initialPresented, "Expected \(testCase.name) to present video frames after software fallback")

        try player.seek(toMilliseconds: 1_500, pauseAfterFirstFrame: true)
        let soughtPresented = await waitUntil(timeoutSeconds: 4) {
            !player.isPlaying
                && abs(player.currentTime - 1.5) < 0.5
        }
        #expect(soughtPresented, "Expected \(testCase.name) to seek and scrub normally after software fallback")
    }
}

