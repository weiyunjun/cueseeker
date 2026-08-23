import AppKit

/// Indexing reads the database, then scans and parses for a long time outside any
/// transaction, then writes back. Two instances doing that against the same
/// database can publish stale results over newer ones, so only one may run.
enum SingleInstanceGuard {
    static func runningInstance() -> NSRunningApplication? {
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
            return nil
        }
        let current = NSRunningApplication.current
        return NSRunningApplication
            .runningApplications(withBundleIdentifier: bundleIdentifier)
            .first { $0.processIdentifier != current.processIdentifier }
    }
}
