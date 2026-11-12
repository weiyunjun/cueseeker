import CNativePlayback
import CueSeekerPlayback
import Foundation
import Testing

@Test
@MainActor
func nativeSeekAndOpenRetainPresentedImageUntilCurrentGenerationCommits() async throws {
    guard let ffmpegURL = presentationTransitionFFmpegURL() else {
        print("Skipping native presentation transition test because ffmpeg is unavailable.")
        return
    }

    let directory = temporaryPresentationTransitionDirectory()
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer {
        try? FileManager.default.removeItem(at: directory)
    }

    let firstMediaURL = directory.appendingPathComponent("first-large-16x9.mkv")
    let secondMediaURL = directory.appendingPathComponent("second-small-16x9.mkv")
    let thirdMediaURL = directory.appendingPathComponent("third-nonstandard-aspect.mkv")
    try makePresentationTransitionMedia(
        at: firstMediaURL,
        audioFrequency: 440,
        videoSize: "320x180",
        ffmpegURL: ffmpegURL
    )
    try makePresentationTransitionMedia(
        at: secondMediaURL,
        audioFrequency: 880,
        videoSize: "160x90",
        ffmpegURL: ffmpegURL
    )
    try makePresentationTransitionMedia(
        at: thirdMediaURL,
        audioFrequency: 1_320,
        videoSize: "144x108",
        ffmpegURL: ffmpegURL
    )

    let player = SFXNativePlaybackPlayer()
    player.volume = 0
    let delegate = NativePresentationTransitionDelegate()
    player.delegate = delegate
    #expect(delegate.responds(
        to: NSSelectorFromString(
            "nativePlaybackPlayer:didPresentVideoFrameAtMilliseconds:presentationGeneration:"
        )
    ))
    player.decodeMode = SFXNativePlaybackDecodeMode(rawValue: 1)!
    var stopped = false
    defer {
        if !stopped {
            player.stop()
        }
    }

    try player.openPath(firstMediaURL.path, startMilliseconds: 0)
    try player.setPaused(false)
    let initialGeneration = player.nativePresentationGeneration
    #expect(initialGeneration > 0)
    let presentedInitialGeneration = await waitForPresentationGeneration(
        initialGeneration,
        delegate: delegate
    )
    #expect(presentedInitialGeneration)
    #expect(player.nativePresentedVideoFrameCount > 0)
    let initialSnapshot = try #require(player.latestSubmittedVideoFrameSnapshot)
    #expect(initialSnapshot.width == 320)
    #expect(initialSnapshot.height == 180)
    #expect(CVPixelBufferGetWidth(initialSnapshot.pixelBuffer) == 320)
    #expect(CVPixelBufferGetHeight(initialSnapshot.pixelBuffer) == 180)

    let removalCountAfterInitialFrame = player.nativeDisplayImageRemovalCount

    try player.seek(toMilliseconds: 1_100, pauseAfterFirstFrame: true)
    let seekGeneration = player.nativePresentationGeneration
    #expect(seekGeneration > initialGeneration)
    #expect(player.nativeDisplayImageRemovalCount == removalCountAfterInitialFrame)
    let presentedSeekGeneration = await waitForPresentationGeneration(
        seekGeneration,
        delegate: delegate
    )
    #expect(presentedSeekGeneration)
    #expect(player.nativeDisplayImageRemovalCount == removalCountAfterInitialFrame)
    let seekCommit = try #require(delegate.commit(for: seekGeneration))
    #expect(seekCommit.milliseconds >= 1_100)
    let seekSnapshot = try #require(player.latestSubmittedVideoFrameSnapshot)
    #expect(seekSnapshot !== initialSnapshot)

    try player.openPath(secondMediaURL.path, startMilliseconds: 1_100)
    try player.setPaused(false)
    let openGeneration = player.nativePresentationGeneration
    #expect(openGeneration > seekGeneration)
    #expect(player.nativeDisplayImageRemovalCount == removalCountAfterInitialFrame)
    let presentedOpenGeneration = await waitForPresentationGeneration(
        openGeneration,
        delegate: delegate
    )
    #expect(presentedOpenGeneration)
    #expect(player.nativeDisplayImageRemovalCount == removalCountAfterInitialFrame)
    let openCommit = try #require(delegate.commit(for: openGeneration))
    #expect(openCommit.milliseconds >= 1_100)
    let openSnapshot = try #require(player.latestSubmittedVideoFrameSnapshot)
    #expect(openSnapshot !== seekSnapshot)
    #expect(openSnapshot.width == 160)
    #expect(openSnapshot.height == 90)

    try player.openPath(thirdMediaURL.path, startMilliseconds: 1_100)
    try player.setPaused(false)
    let thirdGeneration = player.nativePresentationGeneration
    #expect(thirdGeneration > openGeneration)
    #expect(player.nativeDisplayImageRemovalCount == removalCountAfterInitialFrame)
    let presentedThirdGeneration = await waitForPresentationGeneration(
        thirdGeneration,
        delegate: delegate
    )
    #expect(presentedThirdGeneration)
    #expect(player.nativeDisplayImageRemovalCount == removalCountAfterInitialFrame)
    let thirdSnapshot = try #require(player.latestSubmittedVideoFrameSnapshot)
    #expect(thirdSnapshot !== openSnapshot)
    #expect(thirdSnapshot.width == 144)
    #expect(thirdSnapshot.height == 108)

    player.stop()
    stopped = true
    #expect(player.nativeDisplayImageRemovalCount == removalCountAfterInitialFrame + 1)
    #expect(player.latestSubmittedVideoFrameSnapshot == nil)
    #expect(initialSnapshot.width == 320)
    #expect(initialSnapshot.height == 180)
}

@Test
@MainActor
func nativeRapidSeeksCommitOnlyLatestPresentationGeneration() async throws {
    guard let ffmpegURL = presentationTransitionFFmpegURL() else {
        print("Skipping native rapid-seek presentation test because ffmpeg is unavailable.")
        return
    }

    let directory = temporaryPresentationTransitionDirectory()
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer {
        try? FileManager.default.removeItem(at: directory)
    }

    let mediaURL = directory.appendingPathComponent("rapid-seek.mkv")
    try makePresentationTransitionMedia(
        at: mediaURL,
        audioFrequency: 660,
        ffmpegURL: ffmpegURL
    )

    let player = SFXNativePlaybackPlayer()
    player.volume = 0
    let delegate = NativePresentationTransitionDelegate()
    player.delegate = delegate
    #expect(delegate.responds(
        to: NSSelectorFromString(
            "nativePlaybackPlayer:didPresentVideoFrameAtMilliseconds:presentationGeneration:"
        )
    ))
    player.decodeMode = SFXNativePlaybackDecodeMode(rawValue: 1)!
    defer {
        player.stop()
    }

    try player.openPath(mediaURL.path, startMilliseconds: 0)
    try player.setPaused(false)
    let initialGeneration = player.nativePresentationGeneration
    let presentedInitialGeneration = await waitForPresentationGeneration(
        initialGeneration,
        delegate: delegate
    )
    #expect(presentedInitialGeneration)
    #expect(player.nativePresentedVideoFrameCount > 0)
    let removalCountBeforeSeeks = player.nativeDisplayImageRemovalCount

    try player.seek(toMilliseconds: 1_100, pauseAfterFirstFrame: false)
    let supersededGeneration = player.nativePresentationGeneration
    try player.seek(toMilliseconds: 3_100, pauseAfterFirstFrame: true)
    let currentGeneration = player.nativePresentationGeneration

    #expect(currentGeneration > supersededGeneration)
    #expect(player.nativeDisplayImageRemovalCount == removalCountBeforeSeeks)
    let presentedCurrentGeneration = await waitForPresentationGeneration(
        currentGeneration,
        delegate: delegate
    )
    #expect(presentedCurrentGeneration)
    #expect(delegate.commit(for: supersededGeneration) == nil)
    let currentCommit = try #require(delegate.commit(for: currentGeneration))
    #expect(currentCommit.milliseconds >= 3_100)
    #expect(player.nativeDisplayImageRemovalCount == removalCountBeforeSeeks)
}

@Test
func playbackSeekTimestampAlignmentAlignsPreTargetFramesWithin2msAndPreservesIEEE754Roundtrips() {
    // Pre-target frame within 2ms tolerance aligns to target.
    #expect(PlaybackSeekTimestampAlignment.alignedPlaybackMilliseconds(
        presentedMilliseconds: 1_099_348,
        targetMilliseconds: 1_099_350
    ) == 1_099_350)
    #expect(PlaybackSeekTimestampAlignment.alignedPlaybackMilliseconds(
        presentedMilliseconds: 1_099_349,
        targetMilliseconds: 1_099_350
    ) == 1_099_350)
    #expect(PlaybackSeekTimestampAlignment.alignedPlaybackMilliseconds(
        presentedMilliseconds: 1_099_350,
        targetMilliseconds: 1_099_350
    ) == 1_099_350)

    // Pre-target frame earlier by > 2ms (e.g. seeking past EOF) keeps actual frame timestamp.
    #expect(PlaybackSeekTimestampAlignment.alignedPlaybackMilliseconds(
        presentedMilliseconds: 1_099_347,
        targetMilliseconds: 1_099_350
    ) == 1_099_347)
    #expect(PlaybackSeekTimestampAlignment.alignedPlaybackMilliseconds(
        presentedMilliseconds: 5_950,
        targetMilliseconds: 6_000
    ) == 5_950)

    // Post-target frame keeps actual frame timestamp.
    #expect(PlaybackSeekTimestampAlignment.alignedPlaybackMilliseconds(
        presentedMilliseconds: 1_126,
        targetMilliseconds: 1_100
    ) == 1_126)
    #expect(PlaybackSeekTimestampAlignment.alignedPlaybackMilliseconds(
        presentedMilliseconds: 0,
        targetMilliseconds: 0
    ) == 0)

    // IEEE-754 decimal roundtrip values do not lose 1ms on floor conversion.
    for exactMs in [0, 1_000, 2_010, 4_020, 16_080, 1_096_080, 1_099_350] {
        let seconds = Double(exactMs) / 1_000
        #expect(PlaybackSeekTimestampAlignment.playbackMilliseconds(atSeconds: seconds) == exactMs)
    }
    #expect(PlaybackSeekTimestampAlignment.playbackMilliseconds(atSeconds: 1_099.3499) == 1_099_349)
}

@Test
@MainActor
func nativeOpenAndSeekAlignPreTarget2msFrameProgressWhilePreservingPostTargetFrameTimestamp() async throws {
    guard let ffmpegURL = presentationTransitionFFmpegURL() else {
        print("Skipping native 23.976fps pre-target seek alignment test because ffmpeg is unavailable.")
        return
    }

    let directory = temporaryPresentationTransitionDirectory()
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer {
        try? FileManager.default.removeItem(at: directory)
    }

    // At 24000/1001 fps in Matroska (1ms timebase):
    // - Frame 26 is at 1_084ms (2ms before 1_086ms)
    // - Frame 27 is at 1_126ms (post-target for 1_100ms)
    // - Frame 50 is at 2_085ms (1ms before 2_086ms)
    let mediaURL = directory.appendingPathComponent("ntsc-23976-seek-alignment.mkv")
    try makePresentationTransitionMedia(
        at: mediaURL,
        audioFrequency: 520,
        frameRate: "24000/1001",
        ffmpegURL: ffmpegURL
    )

    let player = SFXNativePlaybackPlayer()
    player.volume = 0
    let delegate = NativePresentationTransitionDelegate()
    player.delegate = delegate
    player.decodeMode = SFXNativePlaybackDecodeMode(rawValue: 1)!
    defer {
        player.stop()
    }

    // 1. Open at 1_086ms -> Frame 26 (1_084ms) is 2ms before target; progress aligns to 1_086ms.
    try player.openPath(mediaURL.path, startMilliseconds: 1_086)
    let openGen = player.nativePresentationGeneration
    let presentedOpen = await waitForPresentationGeneration(openGen, delegate: delegate)
    #expect(presentedOpen)
    let openCommit = try #require(delegate.commit(for: openGen))
    #expect(openCommit.milliseconds == 1_086)
    #expect(player.nativeLastSubmittedVideoFrameMilliseconds >= 1_086)
    #expect(PlaybackSeekTimestampAlignment.playbackMilliseconds(atSeconds: player.currentTime) >= 1_086)
    for reportedTime in delegate.reportedTimes(for: openGen) {
        #expect(PlaybackSeekTimestampAlignment.playbackMilliseconds(atSeconds: reportedTime) >= 1_086)
    }

    // 2. In-session seek to 2_086ms (paused after first frame) -> Frame 50 (2_085ms, 1ms early) aligns to 2_086ms.
    try player.seek(toMilliseconds: 2_086, pauseAfterFirstFrame: true)
    let seek2086Gen = player.nativePresentationGeneration
    #expect(await waitForPresentationGeneration(seek2086Gen, delegate: delegate))
    #expect(delegate.commit(for: seek2086Gen)?.milliseconds == 2_086)
    #expect(player.nativeLastSubmittedVideoFrameMilliseconds == 2_086)
    #expect(PlaybackSeekTimestampAlignment.playbackMilliseconds(atSeconds: player.currentTime) == 2_086)
    for reportedTime in delegate.reportedTimes(for: seek2086Gen) {
        #expect(PlaybackSeekTimestampAlignment.playbackMilliseconds(atSeconds: reportedTime) == 2_086)
    }

    // 3. Repeated in-session seeks back to 1_086ms never roll back to 1_084ms.
    for _ in 0..<3 {
        try player.seek(toMilliseconds: 1_086, pauseAfterFirstFrame: true)
        let seekGen = player.nativePresentationGeneration
        #expect(await waitForPresentationGeneration(seekGen, delegate: delegate))
        #expect(delegate.commit(for: seekGen)?.milliseconds == 1_086)
        #expect(player.nativeLastSubmittedVideoFrameMilliseconds == 1_086)
        #expect(PlaybackSeekTimestampAlignment.playbackMilliseconds(atSeconds: player.currentTime) == 1_086)
        for reportedTime in delegate.reportedTimes(for: seekGen) {
            #expect(PlaybackSeekTimestampAlignment.playbackMilliseconds(atSeconds: reportedTime) == 1_086)
        }
    }

    // 4. Normal post-target seek to 1_100ms -> Frame 26 (~1084ms) is skipped and Frame 27 (~1126ms) reports actual frame timestamp.
    try player.seek(toMilliseconds: 1_100, pauseAfterFirstFrame: true)
    let postTargetGen = player.nativePresentationGeneration
    #expect(await waitForPresentationGeneration(postTargetGen, delegate: delegate))
    let postTargetCommit = try #require(delegate.commit(for: postTargetGen))
    #expect(postTargetCommit.milliseconds >= 1_125)
    #expect(player.nativeLastSubmittedVideoFrameMilliseconds >= 1_125)
    #expect(PlaybackSeekTimestampAlignment.playbackMilliseconds(atSeconds: player.currentTime) >= 1_125)
}

private struct NativePresentationCommit: Equatable {
    let generation: UInt
    let milliseconds: Int
}

private final class NativePresentationTransitionDelegate: NSObject, SFXNativePlaybackPlayerDelegate {
    private let lock = NSLock()
    private var commits: [NativePresentationCommit] = []
    private var reportedTimesByGen: [UInt: [Double]] = [:]
    private var failures: [String] = []

    func nativePlaybackPlayer(
        _ player: SFXNativePlaybackPlayer,
        didUpdateTime time: Double,
        duration: Double,
        playing: Bool
    ) {}

    func nativePlaybackPlayer(
        _ player: SFXNativePlaybackPlayer,
        didUpdateTime time: Double,
        duration: Double,
        playing: Bool,
        presentationGeneration: UInt
    ) {
        lock.lock()
        reportedTimesByGen[presentationGeneration, default: []].append(time)
        lock.unlock()
    }

    func nativePlaybackPlayer(
        _ player: SFXNativePlaybackPlayer,
        didFailWithMessage message: String
    ) {
        lock.lock()
        failures.append(message)
        lock.unlock()
    }

    func nativePlaybackPlayer(
        _ player: SFXNativePlaybackPlayer,
        didPresentVideoFrameAtMilliseconds milliseconds: Int,
        presentationGeneration: UInt
    ) {
        lock.lock()
        commits.append(
            NativePresentationCommit(
                generation: presentationGeneration,
                milliseconds: milliseconds
            )
        )
        lock.unlock()
    }

    func commit(for generation: UInt) -> NativePresentationCommit? {
        lock.lock()
        defer { lock.unlock() }
        return commits.first { $0.generation == generation }
    }

    func reportedTimes(for generation: UInt) -> [Double] {
        lock.lock()
        defer { lock.unlock() }
        return reportedTimesByGen[generation] ?? []
    }

    var hasFailures: Bool {
        lock.lock()
        defer { lock.unlock() }
        return !failures.isEmpty
    }
}

@MainActor
private func waitForPresentationGeneration(
    _ generation: UInt,
    delegate: NativePresentationTransitionDelegate,
    timeoutSeconds: TimeInterval = 5
) async -> Bool {
    let deadline = Date().addingTimeInterval(timeoutSeconds)
    while Date() < deadline {
        if delegate.hasFailures {
            return false
        }
        if delegate.commit(for: generation) != nil {
            return true
        }
        try? await Task.sleep(nanoseconds: 25_000_000)
    }
    return delegate.commit(for: generation) != nil
}

private func makePresentationTransitionMedia(
    at mediaURL: URL,
    audioFrequency: Int,
    videoSize: String = "160x90",
    frameRate: String = "24",
    ffmpegURL: URL
) throws {
    try runPresentationTransitionProcess(
        ffmpegURL,
        arguments: [
            "-hide_banner",
            "-loglevel",
            "error",
            "-f",
            "lavfi",
            "-i",
            "testsrc2=duration=5:size=\(videoSize):rate=\(frameRate)",
            "-f",
            "lavfi",
            "-i",
            "sine=frequency=\(audioFrequency):duration=5",
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
            "-b:a",
            "96k",
            "-shortest",
            "-y",
            mediaURL.path
        ]
    )
}

private func presentationTransitionFFmpegURL() -> URL? {
    let packageDirectory = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let repositoryDirectory = packageDirectory
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    var searchPaths: [String] = []
    searchPaths.append(contentsOf: [
        "/opt/homebrew/bin/ffmpeg",
        "/usr/local/bin/ffmpeg",
        "/usr/bin/ffmpeg"
    ])
    searchPaths.append(
        contentsOf: ProcessInfo.processInfo.environment["PATH", default: ""]
            .split(separator: ":")
            .map { "\($0)/ffmpeg" }
    )
    if let runtimeRoot = ProcessInfo.processInfo.environment["CUESEEKER_MEDIA_RUNTIME_ROOT"] {
        searchPaths.append("\(runtimeRoot)/bin/ffmpeg")
    }
    searchPaths.append(
        repositoryDirectory
            .appendingPathComponent(".build/media-runtime/arm64-macos13/bin/ffmpeg")
            .path
    )

    return searchPaths
        .map(URL.init(fileURLWithPath:))
        .first { FileManager.default.isExecutableFile(atPath: $0.path) }
}

private func runPresentationTransitionProcess(_ executableURL: URL, arguments: [String]) throws {
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
            domain: "CueSeekerPlaybackTests.PresentationTransitionFixture",
            code: Int(process.terminationStatus),
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }
}

private func temporaryPresentationTransitionDirectory() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "CueSeekerPresentationTransitionTests-\(UUID().uuidString)",
            isDirectory: true
        )
}
