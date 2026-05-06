import AppKit
import CueSeekerCore
import CueSeekerPlayback
import Darwin
import Foundation
import QuartzCore

private struct ProbeConfig {
    var videoURL: URL
    var subtitleURL: URL
    var durationSeconds: Double = 300
    var startSeconds: Double = 0
    var sampleIntervalSeconds: Double = 1
    var driftThresholdSeconds: Double = 0.75
    var stallThresholdSeconds: Double = 2
    var windowSize: CGSize = CGSize(width: 1280, height: 720)
    var verbose: Bool = false

    static func parse(_ arguments: [String]) throws -> ProbeConfig {
        var videoPath: String?
        var subtitlePath: String?
        var durationSeconds = 300.0
        var startSeconds = 0.0
        var sampleIntervalSeconds = 1.0
        var driftThresholdSeconds = 0.75
        var stallThresholdSeconds = 2.0
        var width = 1280.0
        var height = 720.0
        var verbose = false

        var index = 1
        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "--mode":
                try parseRendererCompatibility(valueAfter: argument, arguments: arguments, index: &index)
            case "--video":
                videoPath = try parseString(valueAfter: argument, arguments: arguments, index: &index)
            case "--subtitle":
                subtitlePath = try parseString(valueAfter: argument, arguments: arguments, index: &index)
            case "--duration":
                durationSeconds = try parsePositiveDouble(valueAfter: argument, arguments: arguments, index: &index)
            case "--start":
                startSeconds = try parseNonnegativeDouble(valueAfter: argument, arguments: arguments, index: &index)
            case "--sample-interval":
                sampleIntervalSeconds = try parsePositiveDouble(valueAfter: argument, arguments: arguments, index: &index)
            case "--drift-threshold":
                driftThresholdSeconds = try parsePositiveDouble(valueAfter: argument, arguments: arguments, index: &index)
            case "--stall-threshold":
                stallThresholdSeconds = try parsePositiveDouble(valueAfter: argument, arguments: arguments, index: &index)
            case "--width":
                width = try parsePositiveDouble(valueAfter: argument, arguments: arguments, index: &index)
            case "--height":
                height = try parsePositiveDouble(valueAfter: argument, arguments: arguments, index: &index)
            case "--verbose":
                verbose = true
                index += 1
            case "--help", "-h":
                throw ProbeUsage.requested
            default:
                throw ProbeUsage.invalid("Unknown argument: \(argument)")
            }
        }

        guard let videoPath else {
            throw ProbeUsage.invalid("Missing --video path.")
        }
        guard let subtitlePath else {
            throw ProbeUsage.invalid("Missing --subtitle path.")
        }

        let videoURL = URL(fileURLWithPath: videoPath)
        let subtitleURL = URL(fileURLWithPath: subtitlePath)
        guard FileManager.default.fileExists(atPath: videoURL.path) else {
            throw ProbeUsage.invalid("Video file does not exist: \(videoURL.path)")
        }
        guard FileManager.default.fileExists(atPath: subtitleURL.path) else {
            throw ProbeUsage.invalid("Subtitle file does not exist: \(subtitleURL.path)")
        }

        return ProbeConfig(
            videoURL: videoURL,
            subtitleURL: subtitleURL,
            durationSeconds: durationSeconds,
            startSeconds: startSeconds,
            sampleIntervalSeconds: sampleIntervalSeconds,
            driftThresholdSeconds: driftThresholdSeconds,
            stallThresholdSeconds: stallThresholdSeconds,
            windowSize: CGSize(width: width, height: height),
            verbose: verbose
        )
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

    private static func parseRendererCompatibility(
        valueAfter name: String,
        arguments: [String],
        index: inout Int
    ) throws {
        let value = try parseString(valueAfter: name, arguments: arguments, index: &index)
        guard value == "libass" || value == "legacy" else {
            throw ProbeUsage.invalid("Invalid mode: \(value). CueSeeker now uses libass only.")
        }
    }

    private static func parsePositiveDouble(
        valueAfter name: String,
        arguments: [String],
        index: inout Int
    ) throws -> Double {
        let value = try parseString(valueAfter: name, arguments: arguments, index: &index)
        guard let parsed = Double(value), parsed.isFinite, parsed > 0 else {
            throw ProbeUsage.invalid("Invalid positive number after \(name): \(value).")
        }
        return parsed
    }

    private static func parseNonnegativeDouble(
        valueAfter name: String,
        arguments: [String],
        index: inout Int
    ) throws -> Double {
        let value = try parseString(valueAfter: name, arguments: arguments, index: &index)
        guard let parsed = Double(value), parsed.isFinite, parsed >= 0 else {
            throw ProbeUsage.invalid("Invalid nonnegative number after \(name): \(value).")
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
      PlaybackSyncProbe --video path --subtitle path [options]

    Options:
      --mode libass|legacy        Optional compatibility flag. CueSeeker uses libass only.
      --duration seconds          Playback duration to observe. Default: 300
      --start seconds             Start timestamp. Default: 0
      --sample-interval seconds   Probe sample interval. Default: 1
      --drift-threshold seconds   Fail when media clock drift exceeds this value. Default: 0.75
      --stall-threshold seconds   Report a stall when media time is flat for this long. Default: 2
      --width pixels              Probe window width. Default: 1280
      --height pixels             Probe window height. Default: 720
      --verbose                   Print every sample
    """
}

private struct PlaybackSnapshot {
    var lastTime: Double?
    var duration: Double?
    var isPlaying: Bool?
    var failures: [String]
    var updateCount: Int
}

private final class ProbePlaybackDelegate: PlaybackPlayerDelegate {
    private let lock = NSLock()
    private var lastTime: Double?
    private var duration: Double?
    private var isPlaying: Bool?
    private var failures: [String] = []
    private var updateCount = 0

    func player(_ player: PlaybackPlayer, didChangeProperty name: String, value: PlaybackPropertyValue?) {
        lock.lock()
        defer { lock.unlock() }

        updateCount += 1
        switch (name, value) {
        case ("time-pos", .double(let time)?):
            lastTime = time
        case ("duration", .double(let duration)?):
            self.duration = duration
        case ("pause", .bool(let paused)?):
            isPlaying = !paused
        default:
            return
        }
    }

    func player(_ player: PlaybackPlayer, didFailWithMessage message: String) {
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

private struct ProbeSample {
    var wallSeconds: Double
    var mediaSeconds: Double
    var expectedSeconds: Double
}

@MainActor
private final class PlaybackSyncProbeRunner {
    private let config: ProbeConfig
    private let player = PlaybackPlayer()
    private let playbackDelegate = ProbePlaybackDelegate()
    private let cueGroups: [SubtitleCueGroup]
    private var window: NSWindow?
    private var timer: Timer?
    private var startHostSeconds: Double = 0
    private var samples: [ProbeSample] = []
    private var baselineSample: ProbeSample?
    private var consecutiveFlatMediaSeconds = 0.0
    private var maxFlatMediaSeconds = 0.0
    private var stallCount = 0
    private var maxAbsoluteProgressDrift = 0.0
    private var maxIntervalLag = 0.0
    private(set) var exitCode: Int32 = 1

    init(config: ProbeConfig) throws {
        self.config = config
        let contents = try String(contentsOf: config.subtitleURL)
        cueGroups = ASSParser.parseCueGroups(contents)
    }

    func start() throws {
        NSApplication.shared.setActivationPolicy(.regular)

        player.delegate = playbackDelegate

        let window = NSWindow(
            contentRect: CGRect(origin: .zero, size: config.windowSize),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "CueSeeker Playback Sync Probe - libass"
        window.contentView = player.renderView
        window.center()
        window.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
        self.window = window

        let request = try PlaybackRequest(
            videoURL: config.videoURL,
            startMilliseconds: Int((config.startSeconds * 1000).rounded()),
            subtitleSource: PlaybackSubtitleSource(url: config.subtitleURL, format: .ass)
        )
        try player.open(request)
        player.setSubtitlesVisible(true)

        startHostSeconds = CACurrentMediaTime()
        print("SYNC_PROBE_START mode=libass duration=\(format(config.durationSeconds))s start=\(format(config.startSeconds))s sample_interval=\(format(config.sampleIntervalSeconds))s cues=\(cueGroups.count)")

        timer = Timer.scheduledTimer(
            withTimeInterval: config.sampleIntervalSeconds,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                self?.recordSample()
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + config.durationSeconds) { [weak self] in
            Task { @MainActor in
                self?.finish()
            }
        }
    }

    private func recordSample() {
        let wallSeconds = CACurrentMediaTime() - startHostSeconds
        let snapshot = playbackDelegate.snapshot()
        let mediaSeconds = (try? player.getDoubleProperty("time-pos"))
            ?? snapshot.lastTime
            ?? config.startSeconds
        let expectedSeconds = config.startSeconds + wallSeconds
        let sample = ProbeSample(
            wallSeconds: wallSeconds,
            mediaSeconds: mediaSeconds,
            expectedSeconds: expectedSeconds
        )

        if let previous = samples.last {
            let wallDelta = sample.wallSeconds - previous.wallSeconds
            let mediaDelta = sample.mediaSeconds - previous.mediaSeconds
            let intervalLag = max(0, wallDelta - mediaDelta)
            maxIntervalLag = max(maxIntervalLag, intervalLag)

            if wallDelta > 0, mediaDelta < 0.050 {
                consecutiveFlatMediaSeconds += wallDelta
                maxFlatMediaSeconds = max(maxFlatMediaSeconds, consecutiveFlatMediaSeconds)
                if consecutiveFlatMediaSeconds >= config.stallThresholdSeconds {
                    stallCount += 1
                    consecutiveFlatMediaSeconds = 0
                }
            } else {
                consecutiveFlatMediaSeconds = 0
            }
        }

        if baselineSample == nil, samples.count >= 1 {
            baselineSample = sample
        }
        if let baselineSample {
            let wallProgress = sample.wallSeconds - baselineSample.wallSeconds
            let mediaProgress = sample.mediaSeconds - baselineSample.mediaSeconds
            maxAbsoluteProgressDrift = max(
                maxAbsoluteProgressDrift,
                abs(mediaProgress - wallProgress)
            )
        }

        samples.append(sample)

        if config.verbose {
            print(
                "SYNC_SAMPLE mode=libass wall=\(format(sample.wallSeconds)) media=\(format(sample.mediaSeconds)) expected=\(format(sample.expectedSeconds)) drift_vs_wall=\(format(sample.mediaSeconds - sample.expectedSeconds))"
            )
        }
    }

    private func finish() {
        timer?.invalidate()
        timer = nil
        recordSample()

        let finalSample = samples.last ?? ProbeSample(
            wallSeconds: 0,
            mediaSeconds: config.startSeconds,
            expectedSeconds: config.startSeconds
        )
        let baseline = baselineSample ?? finalSample
        let wallProgress = finalSample.wallSeconds - baseline.wallSeconds
        let mediaProgress = finalSample.mediaSeconds - baseline.mediaSeconds
        let progressDrift = mediaProgress - wallProgress
        let absoluteProgressDrift = abs(progressDrift)
        let finalExpectedDrift = finalSample.mediaSeconds - finalSample.expectedSeconds
        let snapshot = playbackDelegate.snapshot()
        let finalMediaMilliseconds = Int((finalSample.mediaSeconds * 1000).rounded())
        let expectedMilliseconds = Int((finalSample.expectedSeconds * 1000).rounded())
        let observedCue = cueSummary(atMilliseconds: finalMediaMilliseconds)
        let expectedCue = cueSummary(atMilliseconds: expectedMilliseconds)
        let cueMatchesExpected = observedCue == expectedCue
        let passed = snapshot.failures.isEmpty
            && absoluteProgressDrift <= config.driftThresholdSeconds
            && maxAbsoluteProgressDrift <= config.driftThresholdSeconds

        print("SYNC_PROBE_RESULT mode=libass status=\(passed ? "pass" : "fail")")
        print("SYNC_CLOCK mode=libass wall_progress=\(format(wallProgress))s media_progress=\(format(mediaProgress))s progress_drift=\(format(progressDrift))s max_abs_progress_drift=\(format(maxAbsoluteProgressDrift))s final_expected_drift=\(format(finalExpectedDrift))s max_interval_lag=\(format(maxIntervalLag))s")
        print("SYNC_STALL mode=libass stall_count=\(stallCount) max_flat_media=\(format(maxFlatMediaSeconds))s stall_threshold=\(format(config.stallThresholdSeconds))s")
        print("SYNC_PLAYBACK mode=libass delegate_updates=\(snapshot.updateCount) is_playing=\(snapshot.isPlaying.map(String.init) ?? "unknown") duration=\(snapshot.duration.map(format) ?? "unknown")s failures=\(snapshot.failures.count)")
        print("SYNC_SUBTITLE mode=libass observed_media_ms=\(finalMediaMilliseconds) expected_wall_ms=\(expectedMilliseconds) cue_matches_expected=\(cueMatchesExpected ? "yes" : "no")")
        print("SYNC_SUBTITLE_OBSERVED mode=libass \(observedCue)")
        print("SYNC_SUBTITLE_EXPECTED mode=libass \(expectedCue)")

        for failure in snapshot.failures {
            print("SYNC_FAILURE mode=libass message=\(failure)")
        }

        exitCode = passed ? 0 : 1
        try? player.stop()
        window?.close()
        NSApp.stop(nil)
    }

    private func cueSummary(atMilliseconds milliseconds: Int) -> String {
        let activeGroups = cueGroups.filter {
            milliseconds >= $0.startMilliseconds && milliseconds < $0.endMilliseconds
        }
        guard !activeGroups.isEmpty else {
            return "active_count=0 text=\"\""
        }

        let text = activeGroups
            .prefix(3)
            .map { group in
                group.searchContent
                    .replacingOccurrences(of: "\n", with: " ")
                    .replacingOccurrences(of: "\"", with: "'")
            }
            .joined(separator: " | ")
        return "active_count=\(activeGroups.count) text=\"\(text)\""
    }

    private func format(_ value: Double) -> String {
        String(format: "%.3f", value)
    }
}

@main
private enum PlaybackSyncProbeMain {
    @MainActor
    static func main() {
        do {
            let config = try ProbeConfig.parse(CommandLine.arguments)
            let runner = try PlaybackSyncProbeRunner(config: config)
            try runner.start()
            NSApp.run()
            exit(runner.exitCode)
        } catch let usage as ProbeUsage {
            fputs("\(usage.description)\n", stderr)
            exit(usage.exitCode)
        } catch {
            fputs("PlaybackSyncProbe failed: \(error)\n", stderr)
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
