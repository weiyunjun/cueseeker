import Darwin

enum AppMemoryPressureRelief {
    static let largeResultReleaseThreshold = 5_000

    static func relieveAfterLargeResultRelease(estimatedReleasedRows: Int) {
        guard estimatedReleasedRows >= largeResultReleaseThreshold else {
            return
        }
        _ = malloc_zone_pressure_relief(nil, 0)
    }
}
