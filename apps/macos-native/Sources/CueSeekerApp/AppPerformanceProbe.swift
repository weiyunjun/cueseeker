import Foundation
import os

private final class AppPerformanceProbeState: @unchecked Sendable {
    private let lock = NSLock()
    private var watchdogTimer: DispatchSourceTimer?
    private var lastActionName = "none"
    private var lastActionStartedAt: UInt64?

    func installWatchdogTimer(_ timer: DispatchSourceTimer) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        guard watchdogTimer == nil else {
            return false
        }

        watchdogTimer = timer
        return true
    }

    func hasWatchdogTimer() -> Bool {
        lock.lock()
        defer { lock.unlock() }

        return watchdogTimer != nil
    }

    func recordLastAction(_ name: String, startedAt: UInt64) {
        lock.lock()
        lastActionName = name
        lastActionStartedAt = startedAt
        lock.unlock()
    }

    func snapshotLastAction(now: UInt64) -> String {
        lock.lock()
        let name = lastActionName
        let startedAt = lastActionStartedAt
        lock.unlock()

        guard let startedAt else {
            return name
        }

        let ageMilliseconds = Double(now - startedAt) / 1_000_000
        return String(format: "%@ age=%.0fms", name, ageMilliseconds)
    }
}

enum AppPerformanceProbe {
    private static let logger = Logger(subsystem: "com.cueseeker.perf", category: "App")
    private static let state = AppPerformanceProbeState()
    private static let watchdogQueue = DispatchQueue(
        label: "app.cueseeker.performance-watchdog",
        qos: .utility
    )

    static func now() -> UInt64 {
        DispatchTime.now().uptimeNanoseconds
    }

    @discardableResult
    static func measure<T>(
        _ name: String,
        thresholdMilliseconds: Double = 16,
        _ block: () throws -> T
    ) rethrows -> T {
        let start = now()
        defer {
            logElapsed(name, since: start, thresholdMilliseconds: thresholdMilliseconds)
        }
        return try block()
    }

    @discardableResult
    static func action<T>(
        _ name: String,
        thresholdMilliseconds: Double = 16,
        _ block: () throws -> T
    ) rethrows -> T {
        recordLastAction(name)
        mark("MARK \(name).begin")
        let start = now()
        defer {
            logElapsed(name, since: start, thresholdMilliseconds: thresholdMilliseconds)
            mark("MARK \(name).end")
        }
        return try block()
    }

    static func startMainThreadWatchdog(
        thresholdMilliseconds: Double = 250,
        intervalMilliseconds: Int = 250
    ) {
        guard !state.hasWatchdogTimer() else {
            return
        }

        let timer = DispatchSource.makeTimerSource(queue: watchdogQueue)
        timer.schedule(
            deadline: .now() + .milliseconds(intervalMilliseconds),
            repeating: .milliseconds(intervalMilliseconds),
            leeway: .milliseconds(25)
        )
        timer.setEventHandler {
            let scheduledAt = now()
            DispatchQueue.main.async {
                logElapsed(
                    "MainThread.stall lastAction=\(state.snapshotLastAction(now: now()))",
                    since: scheduledAt,
                    thresholdMilliseconds: thresholdMilliseconds
                )
            }
        }

        if state.installWatchdogTimer(timer) {
            timer.resume()
            mark("MARK AppPerformanceProbe.watchdogStarted threshold=\(Int(thresholdMilliseconds))ms")
        } else {
            timer.cancel()
        }
    }

    static func logElapsed(
        _ name: String,
        since start: UInt64,
        thresholdMilliseconds: Double = 16
    ) {
        let elapsedMilliseconds = Double(now() - start) / 1_000_000
        guard elapsedMilliseconds >= thresholdMilliseconds else {
            return
        }

        logger.warning("\(message(name: name, elapsedMilliseconds: elapsedMilliseconds), privacy: .public)")
    }

    static func mark(_ name: String) {
        logger.warning("\(name, privacy: .public)")
    }

    private static func message(name: String, elapsedMilliseconds: Double) -> String {
        String(format: "SLOW %@ %.2fms", name, elapsedMilliseconds)
    }

    private static func recordLastAction(_ name: String) {
        state.recordLastAction(name, startedAt: now())
    }
}
