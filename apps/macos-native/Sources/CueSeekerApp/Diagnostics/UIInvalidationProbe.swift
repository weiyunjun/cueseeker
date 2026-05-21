import Foundation
import os

private final class UIInvalidationProbeState: @unchecked Sendable {
    private let lock = NSLock()
    private var counters: [String: UInt64] = [:]
    private var didMarkStartup = false

    func increment(_ name: String) -> UInt64 {
        lock.lock()
        defer { lock.unlock() }

        let nextCount = (counters[name] ?? 0) + 1
        counters[name] = nextCount
        return nextCount
    }

    func shouldMarkStartup() -> Bool {
        lock.lock()
        defer { lock.unlock() }

        guard !didMarkStartup else {
            return false
        }

        didMarkStartup = true
        return true
    }
}

enum UIInvalidationProbe {
    static let isEnabled = diagnosticFlag("CUESEEKER_PERF_UI")

    private static let logger = Logger(subsystem: "com.cueseeker.perf", category: "UI")
    private static let state = UIInvalidationProbeState()

    static func markStartup() {
        guard isEnabled, state.shouldMarkStartup() else {
            return
        }

        logger.warning(
            "MARK UIInvalidationProbe.enabled pid=\(ProcessInfo.processInfo.processIdentifier)"
        )
    }

    static func mark(_ name: String, details: String? = nil) {
        guard isEnabled else {
            return
        }

        markStartup()

        if let details, !details.isEmpty {
            logger.warning("\(name, privacy: .public) \(details, privacy: .public)")
        } else {
            logger.warning("\(name, privacy: .public)")
        }
    }

    @discardableResult
    static func count(_ name: String, details: String? = nil) -> UInt64 {
        guard isEnabled else {
            return 0
        }

        markStartup()
        let nextCount = state.increment(name)

        if let details, !details.isEmpty {
            logger.warning("COUNT \(name, privacy: .public) \(nextCount) \(details, privacy: .public)")
        } else {
            logger.warning("COUNT \(name, privacy: .public) \(nextCount)")
        }

        return nextCount
    }

    private static func diagnosticFlag(_ name: String) -> Bool {
        let argumentName = "--" + name.lowercased().replacingOccurrences(of: "_", with: "-")
        if ProcessInfo.processInfo.arguments.contains(argumentName) {
            return true
        }

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
