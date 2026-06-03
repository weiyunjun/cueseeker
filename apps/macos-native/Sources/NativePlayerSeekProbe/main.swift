import AppKit
import CNativePlayback
import Darwin
import Foundation
import QuartzCore

private struct ProbeConfig {
    var videoURL: URL
    var seekTargetsSeconds: [Double]
    var seekListLoops: Int
    var startSeconds: Double
    var pauseAfterFirstFrame: Bool
    var timelineScrubBeforeSeek: Bool
    var frameToleranceSeconds: Double
    var seekTimeoutSeconds: Double

    static func parse(_ arguments: [String]) throws -> ProbeConfig {
        var videoPath: String?
        var seekTargets: [Double] = []
        var seekListLoops = 1
        var startSeconds = 0.0
        var pauseAfterFirstFrame = false
        var timelineScrubBeforeSeek = false
        var frameToleranceSeconds = 0.75
        var seekTimeoutSeconds = 6.0

        var index = 1
        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "--video":
                videoPath = try parseString(valueAfter: argument, arguments: arguments, index: &index)
            case "--seek-list":
                seekTargets = try parseSeekList(try parseString(valueAfter: argument, arguments: arguments, index: &index))
            case "--seek-list-loops":
                seekListLoops = try parsePositiveInt(
                    try parseString(valueAfter: argument, arguments: arguments, index: &index),
                    name: argument
                )
            case "--start":
                startSeconds = try parseNonnegativeDouble(
                    try parseString(valueAfter: argument, arguments: arguments, index: &index),
                    name: argument
                )
            case "--pause-after-first-frame":
                pauseAfterFirstFrame = true
                index += 1
            case "--timeline-scrub-before-seek":
                timelineScrubBeforeSeek = true
                index += 1
            case "--frame-tolerance":
                frameToleranceSeconds = try parsePositiveDouble(
                    try parseString(valueAfter: argument, arguments: arguments, index: &index),
                    name: argument
                )
            case "--seek-timeout":
                seekTimeoutSeconds = try parsePositiveDouble(
                    try parseString(valueAfter: argument, arguments: arguments, index: &index),
                    name: argument
                )
            case "--help", "-h":
                throw ProbeUsage.requested
            default:
                throw ProbeUsage.invalid("Unknown argument: \(argument)")
            }
        }

        guard let videoPath else {
            throw ProbeUsage.invalid("Missing --video path.")
        }
        guard !seekTargets.isEmpty else {
            throw ProbeUsage.invalid("Missing --seek-list targets.")
        }

        let videoURL = URL(fileURLWithPath: videoPath)
        guard FileManager.default.fileExists(atPath: videoURL.path) else {
            throw ProbeUsage.invalid("Video file does not exist: \(videoURL.path)")
        }

        return ProbeConfig(
            videoURL: videoURL,
            seekTargetsSeconds: seekTargets,
            seekListLoops: seekListLoops,
            startSeconds: startSeconds,
            pauseAfterFirstFrame: pauseAfterFirstFrame,
            timelineScrubBeforeSeek: timelineScrubBeforeSeek,
            frameToleranceSeconds: frameToleranceSeconds,
            seekTimeoutSeconds: seekTimeoutSeconds
        )
    }

    var expandedSeekTargetsSeconds: [Double] {
        Array(repeating: seekTargetsSeconds, count: seekListLoops).flatMap { $0 }
    }

    private static func parseString(
        valueAfter name: String,
        arguments: [String],
        index: inout Int
    ) throws -> String {
        guard index + 1 < arguments.count else {
            throw ProbeUsage.invalid("Missing value after \(name).")
        }
        index += 2
        return arguments[index - 1]
    }

    private static func parseSeekList(_ value: String) throws -> [Double] {
        let parts = value.split(separator: ",")
        let parsed = try parts.map { part -> Double in
            try parseNonnegativeDouble(String(part), name: "--seek-list")
        }
        guard !parsed.isEmpty else {
            throw ProbeUsage.invalid("Invalid empty --seek-list.")
        }
        return parsed
    }

    private static func parsePositiveInt(_ value: String, name: String) throws -> Int {
        guard let parsed = Int(value), parsed > 0 else {
            throw ProbeUsage.invalid("Invalid positive integer for \(name): \(value)")
        }
        return parsed
    }

    private static func parsePositiveDouble(_ value: String, name: String) throws -> Double {
        guard let parsed = Double(value), parsed.isFinite, parsed > 0 else {
            throw ProbeUsage.invalid("Invalid positive number for \(name): \(value)")
        }
        return parsed
    }

    private static func parseNonnegativeDouble(_ value: String, name: String) throws -> Double {
        guard let parsed = Double(value), parsed.isFinite, parsed >= 0 else {
            throw ProbeUsage.invalid("Invalid nonnegative number for \(name): \(value)")
        }
        return parsed
    }
}

private enum ProbeUsage: Error, CustomStringConvertible {
    case requested
    case invalid(String)

    var description: String {
        switch self {
        case .requested:
            return Self.usage
        case .invalid(let message):
            return "\(message)\n\n\(Self.usage)"
        }
    }

    static let usage = """
    Usage:
      NativePlayerSeekProbe --video path --seek-list seconds[,seconds...] [options]

    Options:
      --seek-list-loops count       Repeat the seek list. Default: 1
      --start seconds               Initial open timestamp. Default: 0
      --pause-after-first-frame     Seek should pause after the first new frame
      --timeline-scrub-before-seek  Enter timeline scrubbing before each seek
      --frame-tolerance seconds     Allowed first-frame lag after target. Default: 0.75
      --seek-timeout seconds        Per-seek wait timeout. Default: 6
    """
}

private struct PlaybackSnapshot {
    var lastTime: Double?
    var duration: Double?
    var isPlaying: Bool?
    var failures: [String]
    var updateCount: Int
}

private final class ProbeDelegate: NSObject, SFXNativePlaybackPlayerDelegate {
    private let lock = NSLock()
    private var lastTime: Double?
    private var duration: Double?
    private var isPlaying: Bool?
    private var failures: [String] = []
    private var updateCount = 0

    func nativePlaybackPlayer(
        _ player: SFXNativePlaybackPlayer,
        didUpdateTime time: Double,
        duration: Double,
        playing: Bool
    ) {
        lock.lock()
        lastTime = time
        self.duration = duration
        isPlaying = playing
        updateCount += 1
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

    func snapshot() -> PlaybackSnapshot {
        lock.lock()
        defer { lock.unlock() }
        return PlaybackSnapshot(
            lastTime: lastTime,
            duration: duration,
            isPlaying: isPlaying,
            failures: failures,
            updateCount: updateCount
        )
    }
}

@MainActor
private final class NativePlayerSeekProbeRunner {
    private let config: ProbeConfig
    private let player = SFXNativePlaybackPlayer()
    private let probeDelegate = ProbeDelegate()
    private var window: NSWindow?
    private var seekTargets: [Double]
    private var seekIndex = 0
    private var failures: [String] = []
    private(set) var exitCode: Int32 = 1

    init(config: ProbeConfig) {
        self.config = config
        seekTargets = config.expandedSeekTargetsSeconds
    }

    func start() throws {
        NSApplication.shared.setActivationPolicy(.regular)
        player.delegate = probeDelegate

        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 960, height: 540),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "CueSeeker Native Player Seek Probe"
        window.contentView = player.view
        window.center()
        window.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
        self.window = window

        try player.openPath(
            config.videoURL.path,
            startMilliseconds: Int((config.startSeconds * 1000).rounded())
        )
        try player.setPaused(false)

        print("PLAYER_SEEK_PROBE_START targets=\(seekTargets.count) start=\(format(config.startSeconds))s pause_after_first_frame=\(config.pauseAfterFirstFrame ? "yes" : "no") timeline_scrub_before_seek=\(config.timelineScrubBeforeSeek ? "yes" : "no")")
        printCounters(prefix: "PLAYER_SEEK_COUNTERS_INITIAL")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            Task { @MainActor in
                self?.runNextSeek()
            }
        }
    }

    private func runNextSeek() {
        guard seekIndex < seekTargets.count else {
            finish()
            return
        }

        let targetSeconds = seekTargets[seekIndex]
        let targetMilliseconds = Int((targetSeconds * 1000).rounded())
        let expectedSeekCount = seekIndex + 1
        let frameCountBeforeSeek = player.nativePresentedVideoFrameCount
        let openCountBeforeSeek = player.nativeSessionOpenCount
        let start = CACurrentMediaTime()

        do {
            if config.timelineScrubBeforeSeek {
                try player.setTimelineScrubbing(true)
            }
            try player.seek(
                toMilliseconds: targetMilliseconds,
                pauseAfterFirstFrame: config.pauseAfterFirstFrame
            )
            if !config.pauseAfterFirstFrame {
                try player.setPaused(false)
            }
        } catch {
            failures.append("seek \(seekIndex + 1) failed: \(error)")
            finish()
            return
        }

        waitForSeekFrame(
            targetSeconds: targetSeconds,
            targetMilliseconds: targetMilliseconds,
            expectedSeekCount: expectedSeekCount,
            frameCountBeforeSeek: frameCountBeforeSeek,
            openCountBeforeSeek: openCountBeforeSeek,
            start: start
        )
    }

    private func waitForSeekFrame(
        targetSeconds: Double,
        targetMilliseconds: Int,
        expectedSeekCount: Int,
        frameCountBeforeSeek: UInt,
        openCountBeforeSeek: UInt,
        start: Double
    ) {
        let elapsed = CACurrentMediaTime() - start
        let snapshot = probeDelegate.snapshot()
        let frameCount = player.nativePresentedVideoFrameCount
        let openCount = player.nativeSessionOpenCount
        let seekCount = player.nativeInSessionSeekCount
        let currentTime = player.currentTime
        let frameAdvanced = frameCount > frameCountBeforeSeek
        let timeIsNearTarget = currentTime + config.frameToleranceSeconds >= targetSeconds
        let pauseStateOK = !config.pauseAfterFirstFrame || player.isPlaying == false
        let countersOK = openCount == openCountBeforeSeek && openCount == 1 && seekCount == expectedSeekCount
        let passed = frameAdvanced && timeIsNearTarget && pauseStateOK && countersOK && snapshot.failures.isEmpty

        if passed || elapsed >= config.seekTimeoutSeconds {
            let status = passed ? "pass" : "fail"
            print(
                "PLAYER_SEEK_RESULT index=\(seekIndex + 1) status=\(status) target_ms=\(targetMilliseconds) elapsed_ms=\(format(elapsed * 1000)) current=\(format(currentTime))s frames_before=\(frameCountBeforeSeek) frames_after=\(frameCount) open_before=\(openCountBeforeSeek) open_after=\(openCount) seek_count=\(seekCount) playing=\(player.isPlaying ? "yes" : "no") failures=\(snapshot.failures.count)"
            )
            if !passed {
                failures.append("seek \(seekIndex + 1) did not satisfy frame/time/counter checks")
            }
            seekIndex += 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                Task { @MainActor in
                    self?.runNextSeek()
                }
            }
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            Task { @MainActor in
                self?.waitForSeekFrame(
                    targetSeconds: targetSeconds,
                    targetMilliseconds: targetMilliseconds,
                    expectedSeekCount: expectedSeekCount,
                    frameCountBeforeSeek: frameCountBeforeSeek,
                    openCountBeforeSeek: openCountBeforeSeek,
                    start: start
                )
            }
        }
    }

    private func finish() {
        let delegateSnapshot = probeDelegate.snapshot()
        failures.append(contentsOf: delegateSnapshot.failures.map { "delegate failure: \($0)" })

        let expectedSeekCount = seekTargets.count
        if player.nativeSessionOpenCount != 1 {
            failures.append("expected one native session open, got \(player.nativeSessionOpenCount)")
        }
        if player.nativeInSessionSeekCount != expectedSeekCount {
            failures.append("expected \(expectedSeekCount) in-session seeks, got \(player.nativeInSessionSeekCount)")
        }

        printCounters(prefix: "PLAYER_SEEK_COUNTERS_FINAL")
        print("PLAYER_SEEK_PROBE_RESULT status=\(failures.isEmpty ? "pass" : "fail") failures=\(failures.count)")
        for failure in failures {
            print("PLAYER_SEEK_FAILURE \(failure)")
        }

        exitCode = failures.isEmpty ? 0 : 1
        player.stop()
        window?.close()
        exit(exitCode)
    }

    private func printCounters(prefix: String) {
        print("\(prefix) open_count=\(player.nativeSessionOpenCount) in_session_seek_count=\(player.nativeInSessionSeekCount) frame_count=\(player.nativePresentedVideoFrameCount)")
    }

    private func format(_ value: Double) -> String {
        String(format: "%.3f", value)
    }
}

@main
private enum NativePlayerSeekProbeMain {
    @MainActor
    static func main() {
        setbuf(stdout, nil)
        setbuf(stderr, nil)
        do {
            let config = try ProbeConfig.parse(CommandLine.arguments)
            let runner = NativePlayerSeekProbeRunner(config: config)
            try runner.start()
            NSApp.run()
            exit(runner.exitCode)
        } catch let usage as ProbeUsage {
            fputs("\(usage.description)\n", stderr)
            exit(usage.exitCode)
        } catch {
            fputs("NativePlayerSeekProbe failed: \(error)\n", stderr)
            exit(1)
        }
    }
}

private extension ProbeUsage {
    var exitCode: Int32 {
        switch self {
        case .requested:
            return 0
        case .invalid:
            return 2
        }
    }
}
