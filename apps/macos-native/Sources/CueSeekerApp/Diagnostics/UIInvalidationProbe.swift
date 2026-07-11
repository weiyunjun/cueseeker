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

struct UIInvalidationProbeRecording: Equatable, Sendable {
    let markCounts: [String: UInt64]
    let counters: [String: UInt64]

    var marks: [String] {
        markCounts.keys.sorted().flatMap { name in
            Array(repeating: name, count: Int(markCounts[name] ?? 0))
        }
    }

    func markCount(_ name: String) -> UInt64 {
        markCounts[name] ?? 0
    }

    func count(_ name: String) -> UInt64 {
        counters[name] ?? 0
    }

    func delta(since earlier: UIInvalidationProbeRecording) -> UIInvalidationProbeRecording {
        UIInvalidationProbeRecording(
            markCounts: Self.delta(current: markCounts, earlier: earlier.markCounts),
            counters: Self.delta(current: counters, earlier: earlier.counters)
        )
    }

    private static func delta(
        current: [String: UInt64],
        earlier: [String: UInt64]
    ) -> [String: UInt64] {
        current.reduce(into: [:]) { result, item in
            let difference = item.value - min(item.value, earlier[item.key] ?? 0)
            if difference > 0 {
                result[item.key] = difference
            }
        }
    }
}

fileprivate final class UIInvalidationProbeTestRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var markCounts: [String: UInt64] = [:]
    private var counters: [String: UInt64] = [:]

    func mark(_ name: String) {
        lock.lock()
        markCounts[name, default: 0] += 1
        lock.unlock()
    }

    func increment(_ name: String) -> UInt64 {
        lock.lock()
        defer { lock.unlock() }

        let nextCount = (counters[name] ?? 0) + 1
        counters[name] = nextCount
        return nextCount
    }

    func recording() -> UIInvalidationProbeRecording {
        lock.lock()
        defer { lock.unlock() }
        return UIInvalidationProbeRecording(
            markCounts: markCounts,
            counters: counters
        )
    }
}

final class UIInvalidationProbeAsyncTestSession: @unchecked Sendable {
    fileprivate let id: UUID
    private let recorder: UIInvalidationProbeTestRecorder
    private let registry: UIInvalidationProbeAsyncTestRegistry
    private let lock = NSLock()
    private var isFinished = false

    fileprivate init(
        id: UUID,
        recorder: UIInvalidationProbeTestRecorder,
        registry: UIInvalidationProbeAsyncTestRegistry
    ) {
        self.id = id
        self.recorder = recorder
        self.registry = registry
    }

    func recording() -> UIInvalidationProbeRecording {
        recorder.recording()
    }

    func finish() {
        lock.lock()
        guard !isFinished else {
            lock.unlock()
            return
        }
        isFinished = true
        registry.finish(id: id)
        lock.unlock()
    }

    deinit {
        finish()
    }
}

fileprivate final class UIInvalidationProbeAsyncTestRegistry: @unchecked Sendable {
    private struct Entry {
        let scope: String?
        let recorder: UIInvalidationProbeTestRecorder
    }

    private let lock = NSLock()
    private var entries: [UUID: Entry] = [:]

    func begin(scope: String?) -> UIInvalidationProbeAsyncTestSession {
        lock.lock()
        let id = UUID()
        let recorder = UIInvalidationProbeTestRecorder()
        entries[id] = Entry(scope: scope, recorder: recorder)
        lock.unlock()
        return UIInvalidationProbeAsyncTestSession(
            id: id,
            recorder: recorder,
            registry: self
        )
    }

    func mark(_ name: String, scope: String?) {
        lock.lock()
        defer { lock.unlock() }
        for entry in entries.values where entry.scope == nil || entry.scope == scope {
            entry.recorder.mark(name)
        }
    }

    func increment(_ name: String, scope: String?) -> UInt64 {
        lock.lock()
        defer { lock.unlock() }
        var maximumCount: UInt64 = 0
        for entry in entries.values where entry.scope == nil || entry.scope == scope {
            maximumCount = max(maximumCount, entry.recorder.increment(name))
        }
        return maximumCount
    }

    func finish(id: UUID) {
        lock.lock()
        entries.removeValue(forKey: id)
        lock.unlock()
    }
}

enum UIInvalidationProbe {
    static let isEnabled = diagnosticFlag("CUESEEKER_PERF_UI")

    private static let logger = Logger(subsystem: "com.cueseeker.perf", category: "UI")
    private static let state = UIInvalidationProbeState()
    private static let asyncTestRegistry = UIInvalidationProbeAsyncTestRegistry()
    // Test runners may use a helper executable as argv[0], so inspect every
    // argument and the loaded bundles before enabling test-only recording.
    private static let supportsTestRecording = ProcessInfo.processInfo.arguments.contains {
        $0.contains(".xctest")
    } || Bundle.allBundles.contains {
        $0.bundlePath.contains(".xctest")
    } || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    @TaskLocal private static var testRecorder: UIInvalidationProbeTestRecorder?

    @MainActor
    static func recordForTesting<Value>(
        _ operation: () throws -> Value
    ) rethrows -> (value: Value, recording: UIInvalidationProbeRecording) {
        let recorder = UIInvalidationProbeTestRecorder()
        let value = try $testRecorder.withValue(recorder) {
            try operation()
        }
        return (value, recorder.recording())
    }

    static func beginAsyncRecordingForTesting(
        scope: String? = nil
    ) -> UIInvalidationProbeAsyncTestSession {
        asyncTestRegistry.begin(scope: scope)
    }

    static func markStartup() {
        guard isEnabled, state.shouldMarkStartup() else {
            return
        }

        logger.warning(
            "MARK UIInvalidationProbe.enabled pid=\(ProcessInfo.processInfo.processIdentifier)"
        )
    }

    static func mark(
        _ name: String,
        scope: String? = nil,
        details: @autoclosure () -> String? = nil
    ) {
        guard isEnabled || supportsTestRecording else {
            return
        }
        let testRecorder = testRecorder

        testRecorder?.mark(name)
        if supportsTestRecording {
            asyncTestRegistry.mark(name, scope: scope)
        }

        guard isEnabled else {
            return
        }

        markStartup()

        if let logDetails = logDetails(scope: scope, details: details()) {
            logger.warning("\(name, privacy: .public) \(logDetails, privacy: .public)")
        } else {
            logger.warning("\(name, privacy: .public)")
        }
    }

    @discardableResult
    static func count(
        _ name: String,
        scope: String? = nil,
        details: @autoclosure () -> String? = nil
    ) -> UInt64 {
        guard isEnabled || supportsTestRecording else {
            return 0
        }
        let testRecorder = testRecorder

        let testCount = testRecorder?.increment(name) ?? 0
        let asyncTestCount = supportsTestRecording
            ? asyncTestRegistry.increment(name, scope: scope)
            : 0

        guard isEnabled else {
            return max(testCount, asyncTestCount)
        }

        markStartup()
        let nextCount = state.increment(name)

        if let logDetails = logDetails(scope: scope, details: details()) {
            logger.warning(
                "COUNT \(name, privacy: .public) \(nextCount) \(logDetails, privacy: .public)"
            )
        } else {
            logger.warning("COUNT \(name, privacy: .public) \(nextCount)")
        }

        return nextCount
    }

    private static func logDetails(scope: String?, details: String?) -> String? {
        let components = [
            scope.map { "scope=\($0)" },
            details?.isEmpty == false ? details : nil,
        ].compactMap { $0 }
        return components.isEmpty ? nil : components.joined(separator: " ")
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
