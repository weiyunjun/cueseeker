import Foundation
import Testing
@testable import CueSeekerApp

@MainActor
@Test
func quickSearchAIEntryShowsCachedChunksWhenAvailable() {
    withTemporaryUserDefaults { userDefaults in
        let store = PlaybackStore(userDefaults: userDefaults)
        prepareQuickSearchCurrentSentence(in: store)

        store.showQuickSearchAIEntryIfPossible(
            isEnabled: true,
            hasAPIKey: true,
            cachedChunks: ["運", "実力", "うち"]
        )

        #expect(store.quickSearchDraft == "")
        #expect(store.quickSearchCurrentSentence == "運も実力のうちだ")
        #expect(store.selectedQuickSearchAIChunk() == "運")
        #expect(store.quickSearchFocusTarget == .aiOption)
        #expect(!store.isQuickSearchFocused)
        #expect(store.quickSearchAIState == .options(
            chunks: ["運", "実力", "うち"],
            selectedChunkIndex: 0,
            selectedOption: .chunks
        ))
    }
}

@MainActor
@Test
func quickSearchAIEntryFallsBackToCurrentSentenceChunkOptionWhenCacheMisses() {
    withTemporaryUserDefaults { userDefaults in
        let store = PlaybackStore(userDefaults: userDefaults)
        prepareQuickSearchCurrentSentence(in: store)

        store.showQuickSearchAIEntryIfPossible(
            isEnabled: true,
            hasAPIKey: true,
            cachedChunks: nil
        )

        #expect(store.quickSearchAIState == .options(
            chunks: [],
            selectedChunkIndex: nil,
            selectedOption: .refresh
        ))
        #expect(store.quickSearchFocusTarget == .aiOption)
        #expect(!store.isQuickSearchFocused)
        #expect(store.isQuickSearchAIRefreshOptionActive)
        #expect(store.canStartQuickSearchAIChunkingRequest)
    }
}

@MainActor
@Test
func quickSearchManualInputHidesCachedChunks() {
    withTemporaryUserDefaults { userDefaults in
        let store = PlaybackStore(userDefaults: userDefaults)
        prepareQuickSearchCurrentSentence(in: store)
        store.showQuickSearchAIEntryIfPossible(
            isEnabled: true,
            hasAPIKey: true,
            cachedChunks: ["運", "実力", "うち"]
        )

        store.requestQuickSearchFocus()
        store.quickSearchDraft = "manual input"

        #expect(store.quickSearchAIState == .hidden)
        #expect(store.quickSearchFocusTarget == .input)
        #expect(store.isQuickSearchFocused)
    }
}

@MainActor
@Test
func quickSearchInputFocusClearsAIOptionSelectionAndRestoresTextFocus() {
    withTemporaryUserDefaults { userDefaults in
        let store = PlaybackStore(userDefaults: userDefaults)
        prepareQuickSearchCurrentSentence(in: store)
        store.showQuickSearchAIEntryIfPossible(
            isEnabled: true,
            hasAPIKey: true,
            cachedChunks: ["運", "実力", "うち"]
        )

        store.requestQuickSearchFocus()

        #expect(store.quickSearchFocusTarget == .input)
        #expect(store.isQuickSearchFocused)
        #expect(store.quickSearchAIState == .options(
            chunks: ["運", "実力", "うち"],
            selectedChunkIndex: 0,
            selectedOption: nil
        ))
    }
}

@MainActor
@Test
func quickSearchAIOptionFocusCanMoveBackToInputAtBoundaries() {
    withTemporaryUserDefaults { userDefaults in
        let store = PlaybackStore(userDefaults: userDefaults)
        prepareQuickSearchCurrentSentence(in: store)
        store.showQuickSearchAIEntryIfPossible(
            isEnabled: true,
            hasAPIKey: true,
            cachedChunks: ["運", "実力", "うち"]
        )

        #expect(!store.isQuickSearchFocused)
        #expect(store.moveQuickSearchAIOptionFocus(by: -1))
        #expect(store.quickSearchFocusTarget == .input)
        #expect(store.isQuickSearchFocused)
        #expect(store.quickSearchAIState == .options(
            chunks: ["運", "実力", "うち"],
            selectedChunkIndex: 0,
            selectedOption: nil
        ))

        #expect(store.moveQuickSearchAIOptionFocus(by: 1))
        #expect(!store.isQuickSearchFocused)
        #expect(store.quickSearchAIState == .options(
            chunks: ["運", "実力", "うち"],
            selectedChunkIndex: 0,
            selectedOption: .chunks
        ))
        #expect(store.moveQuickSearchAIOptionFocus(by: 1))
        #expect(!store.isQuickSearchFocused)
        #expect(store.quickSearchAIState == .options(
            chunks: ["運", "実力", "うち"],
            selectedChunkIndex: 0,
            selectedOption: .refresh
        ))
        #expect(store.moveQuickSearchAIOptionFocus(by: 1))
        #expect(store.quickSearchFocusTarget == .input)
        #expect(store.isQuickSearchFocused)
    }
}

@MainActor
@Test
func quickSearchChunkSearchCanRestorePreviousChunkOptions() {
    withTemporaryUserDefaults { userDefaults in
        let store = PlaybackStore(userDefaults: userDefaults)
        prepareQuickSearchCurrentSentence(in: store)
        store.showQuickSearchAIEntryIfPossible(
            isEnabled: true,
            hasAPIKey: true,
            cachedChunks: ["運", "実力", "うち"]
        )

        #expect(store.moveQuickSearchAIChunkSelection(by: 1))
        #expect(store.selectedQuickSearchAIChunk() == "実力")
        #expect(!store.isQuickSearchFocused)
        store.applyQuickSearchAIChunkQuery("実力")
        #expect(!store.isQuickSearchFocused)
        store.markQuickSearchSubmitted(query: "実力", source: .chunk)
        store.selectDefaultQuickSearchResultIfNeeded(resultCount: 2)
        #expect(!store.isQuickSearchFocused)

        #expect(store.restoreQuickSearchAIOptionsAfterChunkSearch())
        #expect(store.quickSearchDraft == "")
        #expect(store.quickSearchSubmittedQuery == nil)
        #expect(store.quickSearchFocusTarget == .aiOption)
        #expect(!store.isQuickSearchFocused)
        #expect(store.quickSearchAIState == .options(
            chunks: ["運", "実力", "うち"],
            selectedChunkIndex: 1,
            selectedOption: .chunks
        ))
    }
}

@MainActor
@Test
func quickSearchDirectResultSelectionReturnsToInputAtBoundaries() {
    withTemporaryUserDefaults { userDefaults in
        let store = PlaybackStore(userDefaults: userDefaults)
        store.isQuickSearchOverlayVisible = true
        store.markQuickSearchSubmitted(query: "manual", source: .direct)
        store.selectDefaultQuickSearchResultIfNeeded(resultCount: 2)

        #expect(store.quickSearchFocusTarget == .result)
        #expect(!store.isQuickSearchFocused)
        #expect(store.moveQuickSearchResultSelection(by: -1, resultCount: 2))
        #expect(store.quickSearchFocusTarget == .input)
        #expect(store.isQuickSearchFocused)
        #expect(store.quickSearchSelectedResultIndex == nil)
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

@MainActor
private func prepareQuickSearchCurrentSentence(in store: PlaybackStore) {
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
}

private func withTemporaryUserDefaults(_ body: (UserDefaults) -> Void) {
    let suiteName = "CueSeekerAppTests-\(UUID().uuidString)"
    let userDefaults = UserDefaults(suiteName: suiteName)!
    defer {
        userDefaults.removePersistentDomain(forName: suiteName)
    }

    body(userDefaults)
}
