import CNativePlayback
import Foundation
import Testing

@Test
@MainActor
func nativeSeekPastVideoTrackEndCompletesCurrentPresentationWithoutAFrame() async throws {
    guard let ffmpegURL = noFramePresentationFFmpegURL() else {
        print("Skipping native no-frame presentation test because ffmpeg is unavailable.")
        return
    }

    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "CueSeekerNoFramePresentationTests-\(UUID().uuidString)",
            isDirectory: true
        )
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer {
        try? FileManager.default.removeItem(at: directory)
    }

    let mediaURL = directory.appendingPathComponent("short-video-long-audio.mkv")
    try makeNoFramePresentationMedia(at: mediaURL, ffmpegURL: ffmpegURL)

    let player = SFXNativePlaybackPlayer()
    let delegate = NativeNoFramePresentationDelegate()
    player.delegate = delegate
    player.decodeMode = SFXNativePlaybackDecodeMode(rawValue: 1)!
    #expect(delegate.responds(
        to: NSSelectorFromString(
            "nativePlaybackPlayer:didReachEndWithoutVideoFrameForPresentationGeneration:"
        )
    ))
    defer {
        player.stop()
    }

    try player.openPath(mediaURL.path, startMilliseconds: 0)
    try player.setPaused(false)
    let initialGeneration = player.nativePresentationGeneration
    #expect(await waitForNativeNoFramePresentationCondition {
        delegate.frameCommit(for: initialGeneration) != nil
    })

    try player.seek(toMilliseconds: 1_500, pauseAfterFirstFrame: true)
    let noFrameGeneration = player.nativePresentationGeneration
    let frameCountAfterSeekRequest = player.nativePresentedVideoFrameCount
    let removalCountAfterSeekRequest = player.nativeDisplayImageRemovalCount

    #expect(noFrameGeneration > initialGeneration)
    #expect(await waitForNativeNoFramePresentationCondition {
        delegate.noFrameCount(for: noFrameGeneration) == 1 || delegate.hasFailure
    })
    #expect(!delegate.hasFailure)
    #expect(delegate.noFrameCount(for: noFrameGeneration) == 1)
    #expect(delegate.frameCommit(for: noFrameGeneration) == nil)
    #expect(player.nativePresentedVideoFrameCount == frameCountAfterSeekRequest)
    #expect(player.nativeDisplayImageRemovalCount == removalCountAfterSeekRequest)
}

@Test
@MainActor
func nativePresentationGateRetainsFirstPixelUntilCurrentGenerationResumes() async throws {
    guard let ffmpegURL = noFramePresentationFFmpegURL() else {
        print("Skipping native presentation gate test because ffmpeg is unavailable.")
        return
    }

    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "CueSeekerNativePresentationGateTests-\(UUID().uuidString)",
            isDirectory: true
        )
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer {
        try? FileManager.default.removeItem(at: directory)
    }

    let mediaURL = directory.appendingPathComponent("presentation-gate.mkv")
    try makeNoFramePresentationMedia(at: mediaURL, ffmpegURL: ffmpegURL)

    let player = SFXNativePlaybackPlayer()
    let delegate = NativeNoFramePresentationDelegate()
    player.delegate = delegate
    player.decodeMode = SFXNativePlaybackDecodeMode(rawValue: 1)!
    defer {
        player.stop()
    }

    try player.openPath(mediaURL.path, startMilliseconds: 0)
    try player.setPaused(false)
    let initialGeneration = player.nativePresentationGeneration
    #expect(await waitForNativeNoFramePresentationCondition {
        delegate.frameCommit(for: initialGeneration) != nil
            && player.nativeSessionOpenCount >= 2
    })

    delegate.setPresentationAllowed(false)
    try player.seek(toMilliseconds: 200, pauseAfterFirstFrame: true)
    let gatedGeneration = player.nativePresentationGeneration
    let removalCountAfterSeekRequest = player.nativeDisplayImageRemovalCount

    #expect(gatedGeneration > initialGeneration)
    #expect(await waitForNativeNoFramePresentationCondition {
        delegate.gateMilliseconds(for: gatedGeneration).count == 1
    })
    let gatedMilliseconds = try #require(
        delegate.gateMilliseconds(for: gatedGeneration).first
    )
    try await Task.sleep(nanoseconds: 200_000_000)

    #expect(delegate.gateMilliseconds(for: gatedGeneration) == [gatedMilliseconds])
    #expect(delegate.frameCommit(for: gatedGeneration) == nil)
    #expect(delegate.noFrameCount(for: gatedGeneration) == 0)
    #expect(player.nativeDisplayImageRemovalCount == removalCountAfterSeekRequest)

    delegate.setPresentationAllowed(true)
    player.resumeVideoPresentation(forGeneration: gatedGeneration)
    #expect(await waitForNativeNoFramePresentationCondition {
        delegate.frameCommit(for: gatedGeneration) != nil || delegate.hasFailure
    })
    try await Task.sleep(nanoseconds: 100_000_000)

    #expect(!delegate.hasFailure)
    #expect(delegate.frameCommit(for: gatedGeneration) == gatedMilliseconds)
    #expect(delegate.frameCommitCount(for: gatedGeneration) == 1)
    #expect(delegate.noFrameCount(for: gatedGeneration) == 0)
    #expect(player.nativeDisplayImageRemovalCount == removalCountAfterSeekRequest)
}

private final class NativeNoFramePresentationDelegate: NSObject, SFXNativePlaybackPlayerDelegate {
    private let lock = NSLock()
    private var frameCommits: [UInt: Int] = [:]
    private var frameCommitCounts: [UInt: Int] = [:]
    private var gateRequests: [UInt: [Int]] = [:]
    private var noFrameCounts: [UInt: Int] = [:]
    private var failures: [String] = []
    private var presentationAllowed = true

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
        frameCommits[presentationGeneration] = milliseconds
        frameCommitCounts[presentationGeneration, default: 0] += 1
        lock.unlock()
    }

    func nativePlaybackPlayer(
        _ player: SFXNativePlaybackPlayer,
        shouldPresentVideoFrameAtMilliseconds milliseconds: Int,
        presentationGeneration: UInt
    ) -> Bool {
        lock.lock()
        gateRequests[presentationGeneration, default: []].append(milliseconds)
        let allowed = presentationAllowed
        lock.unlock()
        return allowed
    }

    func nativePlaybackPlayer(
        _ player: SFXNativePlaybackPlayer,
        didReachEndWithoutVideoFrameForPresentationGeneration presentationGeneration: UInt
    ) {
        lock.lock()
        noFrameCounts[presentationGeneration, default: 0] += 1
        lock.unlock()
    }

    func frameCommit(for generation: UInt) -> Int? {
        lock.lock()
        defer { lock.unlock() }
        return frameCommits[generation]
    }

    func frameCommitCount(for generation: UInt) -> Int {
        lock.lock()
        defer { lock.unlock() }
        return frameCommitCounts[generation, default: 0]
    }

    func gateMilliseconds(for generation: UInt) -> [Int] {
        lock.lock()
        defer { lock.unlock() }
        return gateRequests[generation, default: []]
    }

    func setPresentationAllowed(_ allowed: Bool) {
        lock.lock()
        presentationAllowed = allowed
        lock.unlock()
    }

    func noFrameCount(for generation: UInt) -> Int {
        lock.lock()
        defer { lock.unlock() }
        return noFrameCounts[generation, default: 0]
    }

    var hasFailure: Bool {
        lock.lock()
        defer { lock.unlock() }
        return !failures.isEmpty
    }
}

@MainActor
private func waitForNativeNoFramePresentationCondition(
    timeoutSeconds: TimeInterval = 5,
    condition: @escaping () -> Bool
) async -> Bool {
    let deadline = Date().addingTimeInterval(timeoutSeconds)
    while Date() < deadline {
        if condition() {
            return true
        }
        try? await Task.sleep(nanoseconds: 25_000_000)
    }
    return condition()
}

private func makeNoFramePresentationMedia(at mediaURL: URL, ffmpegURL: URL) throws {
    try runNoFramePresentationProcess(
        ffmpegURL,
        arguments: [
            "-hide_banner",
            "-loglevel",
            "error",
            "-f",
            "lavfi",
            "-i",
            "testsrc2=duration=0.5:size=160x90:rate=24",
            "-f",
            "lavfi",
            "-i",
            "sine=frequency=440:duration=2",
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
            "-y",
            mediaURL.path
        ]
    )
}

private func noFramePresentationFFmpegURL() -> URL? {
    let searchPaths = [
        "/opt/homebrew/bin/ffmpeg",
        "/usr/local/bin/ffmpeg",
        "/usr/bin/ffmpeg"
    ] + ProcessInfo.processInfo.environment["PATH", default: ""]
        .split(separator: ":")
        .map { "\($0)/ffmpeg" }

    return searchPaths
        .map(URL.init(fileURLWithPath:))
        .first { FileManager.default.isExecutableFile(atPath: $0.path) }
}

private func runNoFramePresentationProcess(
    _ executableURL: URL,
    arguments: [String]
) throws {
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
            domain: "CueSeekerPlaybackTests.NoFramePresentationFixture",
            code: Int(process.terminationStatus),
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }
}
