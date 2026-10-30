import Darwin
import CueSeekerCore

enum AppMemoryPressureRelief {
    static let largeResultReleaseThreshold = 5_000

    static func relieveAfterLargeResultRelease(estimatedReleasedRows: Int) {
        guard estimatedReleasedRows >= largeResultReleaseThreshold else {
            return
        }
        AppLogger.shared.debug(
            .system,
            "Memory pressure relief triggered",
            details: "released_rows=\(estimatedReleasedRows)"
        )
        _ = malloc_zone_pressure_relief(nil, 0)
    }
}
