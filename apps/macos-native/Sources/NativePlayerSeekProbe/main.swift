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
    var pauseBeforeSeek: Bool
    var timelineScrubBeforeSeek: Bool
    var waitForPlaybackEndBeforeSeek: Bool
    var frameToleranceSeconds: Double
    var seekTimeoutSeconds: Double
    var endTimeoutSeconds: Double
    var segmentEndSeconds: Double?
    var segmentTimeoutSeconds: Double

    static func parse(_ arguments: [String]) throws -> ProbeConfig {
        var videoPath: String?
        var seekTargets: [Double] = []
        var seekListLoops = 1
        var startSeconds = 0.0
        var pauseAfterFirstFrame = false
        var pauseBeforeSeek = false
        var timelineScrubBeforeSeek = false
        var waitForPlaybackEndBeforeSeek = false
        var frameToleranceSeconds = 0.75
        var seekTimeoutSeconds = 6.0
        var endTimeoutSeconds = 10.0
        var segmentEndSeconds: Double?
        var segmentTimeoutSeconds = 6.0

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
            case "--pause-before-seek":
                pauseBeforeSeek = true
                index += 1
            case "--timeline-scrub-before-seek":
                timelineScrubBeforeSeek = true
                index += 1
            case "--wait-for-playback-end-before-seek":
                waitForPlaybackEndBeforeSeek = true
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
            case "--end-timeout":
                endTimeoutSeconds = try parsePositiveDouble(
                    try parseString(valueAfter: argument, arguments: arguments, index: &index),
                    name: argument
                )
            case "--segment-end":
                segmentEndSeconds = try parseNonnegativeDouble(
                    try parseString(valueAfter: argument, arguments: arguments, index: &index),
                    name: argument
                )
            case "--segment-timeout":
                segmentTimeoutSeconds = try parsePositiveDouble(
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
        if let segmentEndSeconds, segmentEndSeconds < startSeconds {
            throw ProbeUsage.invalid("--segment-end must be greater than or equal to --start.")
        }
        guard !seekTargets.isEmpty || segmentEndSeconds != nil else {
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
            pauseBeforeSeek: pauseBeforeSeek,
            timelineScrubBeforeSeek: timelineScrubBeforeSeek,
            waitForPlaybackEndBeforeSeek: waitForPlaybackEndBeforeSeek,
            frameToleranceSeconds: frameToleranceSeconds,
            seekTimeoutSeconds: seekTimeoutSeconds,
            endTimeoutSeconds: endTimeoutSeconds,
            segmentEndSeconds: segmentEndSeconds,
            segmentTimeoutSeconds: segmentTimeoutSeconds
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
      --pause-before-seek           Pause playback immediately before each seek
      --timeline-scrub-before-seek  Enter timeline scrubbing before each seek
      --wait-for-playback-end-before-seek
                                    Let playback naturally end before first seek
      --frame-tolerance seconds     Allowed first-frame lag after target. Default: 0.75
      --seek-timeout seconds        Per-seek wait timeout. Default: 6
      --end-timeout seconds         Wait timeout for natural playback end. Default: 10
      --segment-end seconds         Verify bounded playback from --start to this timestamp
      --segment-timeout seconds     Wait timeout for segment completion. Default: 6
    """
}

private struct PlaybackSnapshot {
    var lastTime: Double?
    var duration: Double?
    var isPlaying: Bool?
    var failures: [String]
    var updateCount: Int
    var segmentFinishCount: Int
    var lastFinishedSegmentEndMilliseconds: Int?
}

private final class ProbeDelegate: NSObject, SFXNativePlaybackPlayerDelegate {
    private let lock = NSLock()
    private var lastTime: Double?
    private var duration: Double?
    private var isPlaying: Bool?
    private var failures: [String] = []
    private var updateCount = 0
    private var segmentFinishCount = 0
    private var lastFinishedSegmentEndMilliseconds: Int?

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

    func nativePlaybackPlayer(
        _ player: SFXNativePlaybackPlayer,
        didFinishSegmentAtMilliseconds endMilliseconds: Int
    ) {
        lock.lock()
        segmentFinishCount += 1
        lastFinishedSegmentEndMilliseconds = endMilliseconds
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
            updateCount: updateCount,
            segmentFinishCount: segmentFinishCount,
            lastFinishedSegmentEndMilliseconds: lastFinishedSegmentEndMilliseconds
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
    private var playbackEndWaitStart: Double = 0
    private var segmentWaitStart: Double = 0

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

        let startMilliseconds = Int((config.startSeconds * 1000).rounded())
        if let segmentEndSeconds = config.segmentEndSeconds {
            try player.openPath(
                config.videoURL.path,
                startMilliseconds: startMilliseconds,
                endMilliseconds: Int((segmentEndSeconds * 1000).rounded())
            )
        } else {
            try player.openPath(
                config.videoURL.path,
                startMilliseconds: startMilliseconds
            )
        }
        try player.setPaused(false)

        print("PLAYER_SEEK_PROBE_START targets=\(seekTargets.count) start=\(format(config.startSeconds))s segment_end=\(config.segmentEndSeconds.map(format) ?? "none")s pause_after_first_frame=\(config.pauseAfterFirstFrame ? "yes" : "no") pause_before_seek=\(config.pauseBeforeSeek ? "yes" : "no") timeline_scrub_before_seek=\(config.timelineScrubBeforeSeek ? "yes" : "no") wait_for_end_before_seek=\(config.waitForPlaybackEndBeforeSeek ? "yes" : "no")")
        printCounters(prefix: "PLAYER_SEEK_COUNTERS_INITIAL")

        if config.segmentEndSeconds != nil {
            segmentWaitStart = CACurrentMediaTime()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                Task { @MainActor in
                    self?.waitForSegmentEnd()
                }
            }
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            Task { @MainActor in
                self?.startSeekSequence()
            }
        }
    }

    private func waitForSegmentEnd() {
        guard let segmentEndSeconds = config.segmentEndSeconds else {
            finish()
            return
        }

        let elapsed = CACurrentMediaTime() - segmentWaitStart
        let endMilliseconds = Int((segmentEndSeconds * 1000).rounded())
        let snapshot = probeDelegate.snapshot()
        let segmentFinished = snapshot.segmentFinishCount == 1
        let lastVideoFrameMilliseconds = player.nativeLastSubmittedVideoFrameMilliseconds
        let lastAudioStartMilliseconds = player.nativeLastScheduledAudioStartMilliseconds
        let lastAudioEndMilliseconds = player.nativeLastScheduledAudioEndMilliseconds
        let nativeFinishCount = player.nativeSegmentFinishNotificationCount
        let nativeFinishedEndMilliseconds = player.nativeLastFinishedSegmentEndMilliseconds
        let videoEndGapMilliseconds = lastVideoFrameMilliseconds < 0
            ? 0
            : endMilliseconds - lastVideoFrameMilliseconds
        let videoEndToleranceMilliseconds = 100
        let videoOK = lastVideoFrameMilliseconds < 0
            || (
                lastVideoFrameMilliseconds < endMilliseconds
                    && videoEndGapMilliseconds <= videoEndToleranceMilliseconds
            )
        let audioOK = lastAudioEndMilliseconds < 0 || lastAudioEndMilliseconds <= endMilliseconds
        let endEventOK = nativeFinishCount == 1
            && nativeFinishedEndMilliseconds == endMilliseconds
            && snapshot.lastFinishedSegmentEndMilliseconds == endMilliseconds
        let passed = segmentFinished
            && videoOK
            && audioOK
            && endEventOK
            && snapshot.failures.isEmpty

        if passed || elapsed >= config.segmentTimeoutSeconds {
            let status = passed ? "pass" : "fail"
            print(
                "PLAYER_SEGMENT_RESULT status=\(status) start_ms=\(Int((config.startSeconds * 1000).rounded())) end_ms=\(endMilliseconds) elapsed_ms=\(format(elapsed * 1000)) current=\(format(player.currentTime))s last_video_ms=\(lastVideoFrameMilliseconds) last_video_gap_ms=\(videoEndGapMilliseconds) last_audio_start_ms=\(lastAudioStartMilliseconds) last_audio_end_ms=\(lastAudioEndMilliseconds) delegate_segment_count=\(snapshot.segmentFinishCount) native_segment_count=\(nativeFinishCount) playing=\(player.isPlaying ? "yes" : "no") failures=\(snapshot.failures.count)"
            )
            if !passed {
                if !segmentFinished {
                    failures.append("segment did not finish exactly once before timeout")
                }
                if !videoOK {
                    failures.append("last submitted video frame \(lastVideoFrameMilliseconds)ms is not within \(videoEndToleranceMilliseconds)ms before segment end \(endMilliseconds)ms")
                }
                if !audioOK {
                    failures.append("last scheduled audio end \(lastAudioEndMilliseconds)ms exceeds segment end \(endMilliseconds)ms")
                }
                if !endEventOK {
                    failures.append("segment finish event did not match end \(endMilliseconds)ms")
                }
            }
            finish()
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            Task { @MainActor in
                self?.waitForSegmentEnd()
            }
        }
    }

    private func startSeekSequence() {
        if config.waitForPlaybackEndBeforeSeek {
            playbackEndWaitStart = CACurrentMediaTime()
            waitForPlaybackEnd()
        } else {
            runNextSeek()
        }
    }

    private func waitForPlaybackEnd() {
        let elapsed = CACurrentMediaTime() - playbackEndWaitStart
        let snapshot = probeDelegate.snapshot()
        let frameCount = player.nativePresentedVideoFrameCount
        let duration = snapshot.duration ?? player.duration
        let currentTime = player.currentTime
        let ended = frameCount > 0
            && player.isPlaying == false
            && duration > 0
            && currentTime + 0.5 >= duration

        if ended {
            print("PLAYER_SEEK_END_WAIT status=pass elapsed_ms=\(format(elapsed * 1000)) current=\(format(currentTime))s duration=\(format(duration))s frame_count=\(frameCount) open_count=\(player.nativeSessionOpenCount)")
            runNextSeek()
            return
        }

        if elapsed >= config.endTimeoutSeconds {
            print("PLAYER_SEEK_END_WAIT status=fail elapsed_ms=\(format(elapsed * 1000)) current=\(format(currentTime))s duration=\(format(duration))s frame_count=\(frameCount) playing=\(player.isPlaying ? "yes" : "no")")
            failures.append("playback did not naturally end before timeout")
            finish()
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            Task { @MainActor in
                self?.waitForPlaybackEnd()
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
        let expectsReopenAfterEnd = config.waitForPlaybackEndBeforeSeek && seekIndex == 0
        if config.pauseBeforeSeek {
            do {
                try player.setPaused(true)
            } catch {
                failures.append("seek \(seekIndex + 1) failed to pause before seek: \(error)")
                finish()
                return
            }
        }
        let frameCountBeforeSeek = player.nativePresentedVideoFrameCount
        let openCountBeforeSeek = player.nativeSessionOpenCount
        let seekCountBeforeSeek = player.nativeInSessionSeekCount
        let expectedOpenCount = openCountBeforeSeek + (expectsReopenAfterEnd ? 1 : 0)
        let expectedSeekCount = seekCountBeforeSeek + (expectsReopenAfterEnd ? 0 : 1)
        let start = CACurrentMediaTime()

        do {
            if config.timelineScrubBeforeSeek {
                try player.setTimelineScrubbing(true)
            }
            try player.seek(
                toMilliseconds: targetMilliseconds,
                pauseAfterFirstFrame: config.pauseAfterFirstFrame
            )
            if !config.pauseAfterFirstFrame && !config.pauseBeforeSeek {
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
            expectedOpenCount: expectedOpenCount,
            expectsReopen: expectsReopenAfterEnd,
            frameCountBeforeSeek: frameCountBeforeSeek,
            openCountBeforeSeek: openCountBeforeSeek,
            start: start
        )
    }

    private func waitForSeekFrame(
        targetSeconds: Double,
        targetMilliseconds: Int,
        expectedSeekCount: UInt,
        expectedOpenCount: UInt,
        expectsReopen: Bool,
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
        let frameAdvanced = expectsReopen ? frameCount > 0 : frameCount > frameCountBeforeSeek
        let timeIsNearTarget = currentTime + config.frameToleranceSeconds >= targetSeconds
        let pauseStateOK = config.pauseAfterFirstFrame
            ? player.isPlaying == false
            : (!config.pauseBeforeSeek || player.isPlaying == true)
        let countersOK = openCount == expectedOpenCount && seekCount == expectedSeekCount
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
                    expectedOpenCount: expectedOpenCount,
                    expectsReopen: expectsReopen,
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

        if config.segmentEndSeconds == nil {
            let expectedReopenAfterEndCount = config.waitForPlaybackEndBeforeSeek ? 1 : 0
            let expectedOpenCount = 1 + expectedReopenAfterEndCount
            let expectedSeekCount = UInt(seekTargets.count - expectedReopenAfterEndCount)
            if player.nativeSessionOpenCount != expectedOpenCount {
                failures.append("expected \(expectedOpenCount) native session opens, got \(player.nativeSessionOpenCount)")
            }
            if player.nativeInSessionSeekCount != expectedSeekCount {
                failures.append("expected \(expectedSeekCount) in-session seeks, got \(player.nativeInSessionSeekCount)")
            }
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
        print("\(prefix) open_count=\(player.nativeSessionOpenCount) in_session_seek_count=\(player.nativeInSessionSeekCount) frame_count=\(player.nativePresentedVideoFrameCount) last_video_ms=\(player.nativeLastSubmittedVideoFrameMilliseconds) last_audio_start_ms=\(player.nativeLastScheduledAudioStartMilliseconds) last_audio_end_ms=\(player.nativeLastScheduledAudioEndMilliseconds) segment_count=\(player.nativeSegmentFinishNotificationCount) segment_end_ms=\(player.nativeLastFinishedSegmentEndMilliseconds)")
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
