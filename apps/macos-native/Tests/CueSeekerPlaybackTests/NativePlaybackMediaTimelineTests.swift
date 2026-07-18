import CNativePlayback
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

private final class NativeAutoStopDelegate: NSObject, SFXNativePlaybackPlayerDelegate {
    private let lock = NSLock()
    private var boundaryMilliseconds: Int?

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

    var reachedBoundaryMilliseconds: Int? {
        lock.lock()
        defer { lock.unlock() }
        return boundaryMilliseconds
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
