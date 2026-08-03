import CNativePlayback
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

private struct NativePresentationCommit: Equatable {
    let generation: UInt
    let milliseconds: Int
}

private final class NativePresentationTransitionDelegate: NSObject, SFXNativePlaybackPlayerDelegate {
    private let lock = NSLock()
    private var commits: [NativePresentationCommit] = []
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
            "testsrc2=duration=5:size=\(videoSize):rate=24",
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
