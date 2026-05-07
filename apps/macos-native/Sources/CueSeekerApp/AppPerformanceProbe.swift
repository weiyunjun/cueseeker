import Foundation
import os

private final class AppPerformanceProbeState: @unchecked Sendable {
    private let lock = NSLock()
    private var watchdogTimer: DispatchSourceTimer?
    private var runLoopObserver: CFRunLoopObserver?
    private var lastActionName = "none"
    private var lastActionStartedAt: UInt64?
    private var lastRunLoopActivity = "none"
    private var lastRunLoopActivityAt: UInt64?

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

    func installRunLoopObserver(_ observer: CFRunLoopObserver) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        guard runLoopObserver == nil else {
            return false
        }

        runLoopObserver = observer
        return true
    }

    func hasRunLoopObserver() -> Bool {
        lock.lock()
        defer { lock.unlock() }

        return runLoopObserver != nil
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

    func updateRunLoopActivity(_ activity: String, at timestamp: UInt64) -> (previous: String, start: UInt64)? {
        lock.lock()
        let previous = lastRunLoopActivity
        let previousAt = lastRunLoopActivityAt
        lastRunLoopActivity = activity
        lastRunLoopActivityAt = timestamp
        lock.unlock()

        guard let previousAt else {
            return nil
        }

        return (previous, previousAt)
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

    static func startMainRunLoopObserver(thresholdMilliseconds: Double = 250) {
        guard !state.hasRunLoopObserver() else {
            return
        }

        let activities: CFRunLoopActivity = [
            .entry,
            .beforeTimers,
            .beforeSources,
            .beforeWaiting,
            .afterWaiting,
            .exit
        ]
        let observer = CFRunLoopObserverCreateWithHandler(
            kCFAllocatorDefault,
            activities.rawValue,
            true,
            0
        ) { _, activity in
            let timestamp = now()
            let activityName = runLoopActivityName(activity)
            guard let previous = state.updateRunLoopActivity(activityName, at: timestamp) else {
                return
            }

            let elapsedMilliseconds = Double(timestamp - previous.start) / 1_000_000
            guard elapsedMilliseconds >= thresholdMilliseconds else {
                return
            }

            let message = runLoopMessage(
                from: previous.previous,
                to: activityName,
                elapsedMilliseconds: elapsedMilliseconds,
                lastAction: state.snapshotLastAction(now: timestamp)
            )
            logger.warning("\(message, privacy: .public)")
        }

        guard let observer else {
            mark("MARK AppPerformanceProbe.runLoopObserverCreateFailed")
            return
        }

        if state.installRunLoopObserver(observer) {
            CFRunLoopAddObserver(CFRunLoopGetMain(), observer, .commonModes)
            mark("MARK AppPerformanceProbe.runLoopObserverStarted threshold=\(Int(thresholdMilliseconds))ms")
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

    private static func runLoopActivityName(_ activity: CFRunLoopActivity) -> String {
        switch activity {
        case .entry:
            return "entry"
        case .beforeTimers:
            return "beforeTimers"
        case .beforeSources:
            return "beforeSources"
        case .beforeWaiting:
            return "beforeWaiting"
        case .afterWaiting:
            return "afterWaiting"
        case .exit:
            return "exit"
        default:
            return "activity=\(activity.rawValue)"
        }
    }

    private static func runLoopMessage(
        from previous: String,
        to current: String,
        elapsedMilliseconds: Double,
        lastAction: String
    ) -> String {
        String(
            format: "SLOW MainRunLoop.phaseGap %@->%@ lastAction=%@ %.2fms",
            previous,
            current,
            lastAction,
            elapsedMilliseconds
        )
    }
}
