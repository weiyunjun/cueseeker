#if DEBUG
import AppKit
import Foundation
import Testing
@testable import CueSeekerApp

@Suite
struct DebugTaskDelayTests {
    @Test
    func waitForDebugTaskDelayWithNonPositiveOrInvalidValuesReturnsImmediately() async {
        let testCases: [[String: String]] = [
            [:],
            ["CUESEEKER_DEBUG_TASK_DELAY_SECONDS": ""],
            ["CUESEEKER_DEBUG_TASK_DELAY_SECONDS": "-5"],
            ["CUESEEKER_DEBUG_TASK_DELAY_SECONDS": "0"],
            ["CUESEEKER_DEBUG_TASK_DELAY_SECONDS": "abc"],
            ["CUESEEKER_DEBUG_TASK_DELAY_SECONDS": "NaN"],
            ["CUESEEKER_DEBUG_TASK_DELAY_SECONDS": "Infinity"]
        ]

        for env in testCases {
            let start = ContinuousClock.now
            await AppCoordinator.waitForDebugTaskDelay(environment: env)
            let elapsed = ContinuousClock.now - start
            #expect(elapsed < .milliseconds(100))
        }
    }

    @Test
    func waitForDebugTaskDelayWithPositiveSecondsWaits() async {
        let env = ["CUESEEKER_DEBUG_TASK_DELAY_SECONDS": "0.05"]
        let start = ContinuousClock.now
        await AppCoordinator.waitForDebugTaskDelay(environment: env)
        let elapsed = ContinuousClock.now - start
        #expect(elapsed >= .milliseconds(40))
    }

    @Test
    @MainActor
    func appCoordinatorInitializesWithConfiguredRunners() throws {
        _ = NSApplication.shared
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("CueSeeker-Delay-Test-\(UUID().uuidString).sqlite")
        defer {
            try? FileManager.default.removeItem(at: databaseURL)
            try? FileManager.default.removeItem(atPath: databaseURL.path + "-wal")
            try? FileManager.default.removeItem(atPath: databaseURL.path + "-shm")
        }

        let suiteName = "CueSeeker-Delay-Test-\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        defer { userDefaults.removePersistentDomain(forName: suiteName) }

        let app = AppCoordinator(userDefaults: userDefaults, databaseURL: databaseURL)

        #expect(app.tasks.hasLibraryTask == false)
    }
}
#endif
