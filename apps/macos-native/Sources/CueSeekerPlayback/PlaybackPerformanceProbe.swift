import Foundation
import os

enum PlaybackPerformanceProbe {
    private static let logger = Logger(subsystem: "com.cueseeker.perf", category: "Playback")

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

    private static func message(name: String, elapsedMilliseconds: Double) -> String {
        String(format: "SLOW %@ %.2fms", name, elapsedMilliseconds)
    }
}
