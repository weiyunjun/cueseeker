import Foundation
import Testing
@testable import CueSeekerApp

@MainActor
@Test
func quickSearchAIEntryShowsCachedChunksWhenAvailable() {
    withTemporaryUserDefaults { userDefaults in
        let store = PlaybackStore(userDefaults: userDefaults)
        store.isQuickSearchOverlayVisible = true
        store.setQuickSearchSubtitleLineCandidates(
            [
                PlaybackQuickSearchLineCandidate(
                    entryID: 1,
                    entryIndex: 0,
                    lineIndex: 0,
                    text: "運も実力のうちだ"
                )
            ],
            selectedIndex: 0
        )

        store.showQuickSearchAIEntryIfPossible(
            isEnabled: true,
            hasAPIKey: true,
            cachedChunks: ["運", "実力", "うち"]
        )

        #expect(store.selectedQuickSearchAIChunk() == "運")
        #expect(store.quickSearchAIState == .chunks(["運", "実力", "うち"], selectedIndex: 0))
    }
}

@MainActor
@Test
func quickSearchAIEntryFallsBackToHintWhenCacheMisses() {
    withTemporaryUserDefaults { userDefaults in
        let store = PlaybackStore(userDefaults: userDefaults)
        store.isQuickSearchOverlayVisible = true
        store.setQuickSearchSubtitleLineCandidates(
            [
                PlaybackQuickSearchLineCandidate(
                    entryID: 1,
                    entryIndex: 0,
                    lineIndex: 0,
                    text: "運も実力のうちだ"
                )
            ],
            selectedIndex: 0
        )

        store.showQuickSearchAIEntryIfPossible(
            isEnabled: true,
            hasAPIKey: true,
            cachedChunks: nil
        )

        #expect(store.quickSearchAIState == .hint)
    }
}

@MainActor
@Test
func quickSearchManualInputHidesCachedChunks() {
    withTemporaryUserDefaults { userDefaults in
        let store = PlaybackStore(userDefaults: userDefaults)
        store.isQuickSearchOverlayVisible = true
        store.setQuickSearchSubtitleLineCandidates(
            [
                PlaybackQuickSearchLineCandidate(
                    entryID: 1,
                    entryIndex: 0,
                    lineIndex: 0,
                    text: "運も実力のうちだ"
                )
            ],
            selectedIndex: 0
        )
        store.showQuickSearchAIEntryIfPossible(
            isEnabled: true,
            hasAPIKey: true,
            cachedChunks: ["運", "実力", "うち"]
        )

        store.quickSearchDraft = "manual input"

        #expect(store.quickSearchAIState == .hidden)
    }
}

private func withTemporaryUserDefaults(_ body: (UserDefaults) -> Void) {
    let suiteName = "CueSeekerAppTests-\(UUID().uuidString)"
    let userDefaults = UserDefaults(suiteName: suiteName)!
    defer {
        userDefaults.removePersistentDomain(forName: suiteName)
    }

    body(userDefaults)
}
