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

@MainActor
@Test
func quickSearchCachedChunksCanReturnToRefreshHintAndBack() {
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

        #expect(store.moveQuickSearchAIChunkSelection(by: -1))
        #expect(store.quickSearchAIState == .chunks(["運", "実力", "うち"], selectedIndex: nil))
        #expect(store.showQuickSearchAIRefreshHintFromSearchField())
        #expect(store.quickSearchAIState == .refreshHint(["運", "実力", "うち"]))
        #expect(store.quickSearchAIState.ghostSuffix == " /chunks")
        #expect(store.isQuickSearchAIRefreshHintActive)
        #expect(store.canStartQuickSearchAIChunkingRequest)
        #expect(store.restoreQuickSearchAIChunkSelectionFromRefreshHint())
        #expect(store.quickSearchAIState == .chunks(["運", "実力", "うち"], selectedIndex: 0))
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
