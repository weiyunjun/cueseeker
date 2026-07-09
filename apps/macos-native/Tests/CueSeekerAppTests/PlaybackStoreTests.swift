import Combine
import Foundation
import Testing
@testable import CueSeekerApp

@MainActor
@Test
func timelineInteractionStateDoesNotInvalidatePlaybackStore() {
    withTemporaryUserDefaults { userDefaults in
        let store = PlaybackStore(userDefaults: userDefaults)
        var playbackStoreInvalidations = 0
        var timelineInvalidations = 0
        var scrubTimeInvalidations = 0

        let playbackStoreCancellable = store.objectWillChange.sink {
            playbackStoreInvalidations += 1
        }
        let timelineCancellable = store.timeline.objectWillChange.sink {
            timelineInvalidations += 1
        }
        let scrubTimeCancellable = store.timeline.scrubTimeStore.objectWillChange.sink {
            scrubTimeInvalidations += 1
        }

        store.isTimelineScrubbing = true
        store.timelineScrubTime = 12.5

        #expect(playbackStoreInvalidations == 0)
        #expect(timelineInvalidations == 1)
        #expect(scrubTimeInvalidations == 1)
        #expect(store.isTimelineScrubbing)
        #expect(store.timelineScrubTime == 12.5)

        withExtendedLifetime(playbackStoreCancellable) {}
        withExtendedLifetime(timelineCancellable) {}
        withExtendedLifetime(scrubTimeCancellable) {}
    }
}

@Test
func aiChunkingUsageEstimatesCNYCost() {
    let usage = AIChunkingUsage(
        promptTokens: 1_000,
        completionTokens: 2_000,
        totalTokens: 3_000
    )

    #expect(usage.estimatedCostCNY == 0.005)
}

private func withTemporaryUserDefaults(_ body: (UserDefaults) -> Void) {
    let suiteName = "CueSeekerAppTests-\(UUID().uuidString)"
    let userDefaults = UserDefaults(suiteName: suiteName)!
    defer {
        userDefaults.removePersistentDomain(forName: suiteName)
    }

    body(userDefaults)
}
