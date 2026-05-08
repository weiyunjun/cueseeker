import Foundation
import os

private final class UIInvalidationProbeState: @unchecked Sendable {
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

enum UIInvalidationProbe {
    static let isEnabled = diagnosticFlag("CUESEEKER_PERF_UI")

    private static let logger = Logger(subsystem: "com.cueseeker.perf", category: "UI")
    private static let state = UIInvalidationProbeState()

    @discardableResult
    static func count(_ name: String, details: String? = nil) -> UInt64 {
        guard isEnabled else {
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
