import Foundation
import os

private final class PlaybackPerformanceProbeState: @unchecked Sendable {
    private let lock = NSLock()
    private var counters: [String: UInt64] = [:]

    func increment(_ name: String) -> UInt64 {
        lock.lock()
        defer { lock.unlock() }

        let nextCount = (counters[name] ?? 0) + 1
        counters[name] = nextCount
        return nextCount
    }
}

enum PlaybackPerformanceProbe {
    private static let logger = Logger(subsystem: "com.cueseeker.perf", category: "Playback")
    private static let isEnabled = diagnosticFlag("CUESEEKER_PERF_PLAYBACK")
    private static let isUIInvalidationEnabled = diagnosticFlag("CUESEEKER_PERF_UI")
    private static let state = PlaybackPerformanceProbeState()

    static func now() -> UInt64 {
        guard isEnabled else {
            return 0
        }

        return DispatchTime.now().uptimeNanoseconds
    }

    @discardableResult
    static func measure<T>(
        _ name: String,
        thresholdMilliseconds: Double = 16,
        _ block: () throws -> T
    ) rethrows -> T {
        guard isEnabled else {
            return try block()
        }

        let start = now()
        defer {
            logElapsed(name, since: start, thresholdMilliseconds: thresholdMilliseconds)
        }
        return try block()
    }

    static func logElapsed(
        _ name: String,
        since start: UInt64,
        thresholdMilliseconds: Double = 16
    ) {
        guard isEnabled else {
            return
        }

        let elapsedMilliseconds = Double(now() - start) / 1_000_000
        guard elapsedMilliseconds >= thresholdMilliseconds else {
            return
        }

        logger.warning("\(message(name: name, elapsedMilliseconds: elapsedMilliseconds), privacy: .public)")
    }

    @discardableResult
    static func countUI(_ name: String, details: String? = nil) -> UInt64 {
        guard isUIInvalidationEnabled else {
            return 0
        }

        let nextCount = state.increment(name)

        if let details, !details.isEmpty {
            logger.notice("COUNT \(name, privacy: .public) \(nextCount) \(details, privacy: .public)")
        } else {
            logger.notice("COUNT \(name, privacy: .public) \(nextCount)")
        }

        return nextCount
    }

    private static func message(name: String, elapsedMilliseconds: Double) -> String {
        String(format: "SLOW %@ %.2fms", name, elapsedMilliseconds)
    }

    private static func diagnosticFlag(_ name: String) -> Bool {
        let value = ProcessInfo.processInfo.environment[name]?.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).lowercased()

        switch value {
        case "1", "true", "yes", "on":
            return true
        default:
            return false
        }
    }
}
