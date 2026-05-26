import Foundation
import Testing
@testable import CueSeekerApp

@MainActor
@Test
func quickSearchNavigationRowHiddenWhenNeitherDirectionAvailable() {
    withNavigationFocusUserDefaults { userDefaults in
        let store = PlaybackStore(userDefaults: userDefaults)
        store.configureQuickSearchNavigation(canMoveBack: false, canMoveForward: false)
        #expect(store.quickSearchNavigationState == .hidden)
    }
}

@MainActor
@Test
func quickSearchNavigationRowShowsOnlyBackWhenForwardUnavailable() {
    withNavigationFocusUserDefaults { userDefaults in
        let store = PlaybackStore(userDefaults: userDefaults)
        store.configureQuickSearchNavigation(canMoveBack: true, canMoveForward: false)
        #expect(store.quickSearchNavigationState == .visible(commands: [.back], selectedIndex: 0))
    }
}

@MainActor
@Test
func quickSearchNavigationRowShowsOnlyForwardWhenBackUnavailable() {
    withNavigationFocusUserDefaults { userDefaults in
        let store = PlaybackStore(userDefaults: userDefaults)
        store.configureQuickSearchNavigation(canMoveBack: false, canMoveForward: true)
        #expect(store.quickSearchNavigationState == .visible(commands: [.forward], selectedIndex: 0))
    }
}

@MainActor
@Test
func quickSearchNavigationRowShowsBothCommandsWhenBothAvailable() {
    withNavigationFocusUserDefaults { userDefaults in
        let store = PlaybackStore(userDefaults: userDefaults)
        store.configureQuickSearchNavigation(canMoveBack: true, canMoveForward: true)
        #expect(
            store.quickSearchNavigationState == .visible(
                commands: [.back, .forward],
                selectedIndex: 0
            )
        )
    }
}

@MainActor
@Test
func quickSearchNavigationFocusTraversalThroughChunksAndRefresh() {
    withNavigationFocusUserDefaults { userDefaults in
        let store = PlaybackStore(userDefaults: userDefaults)
        prepareNavigationFocusSentence(in: store)
        store.showQuickSearchAIEntryIfPossible(
            isEnabled: true,
            hasAPIKey: true,
            cachedChunks: ["a", "b"]
        )
        store.configureQuickSearchNavigation(canMoveBack: true, canMoveForward: true)
        store.focusQuickSearchInput()

        #expect(store.moveQuickSearchAIOptionFocus(by: 1))
        #expect(store.quickSearchFocusTarget == .aiOption)
        #expect(extractSelectedAIOption(store) == .chunks)

        #expect(store.moveQuickSearchAIOptionFocus(by: 1))
        #expect(store.quickSearchFocusTarget == .navigation)

        #expect(store.moveQuickSearchAIOptionFocus(by: 1))
        #expect(store.quickSearchFocusTarget == .aiOption)
        #expect(extractSelectedAIOption(store) == .refresh)

        #expect(store.moveQuickSearchAIOptionFocus(by: 1))
        #expect(store.quickSearchFocusTarget == .input)
    }
}

@MainActor
@Test
func quickSearchNavigationFocusTraversalUpwardThroughRefreshAndChunks() {
    withNavigationFocusUserDefaults { userDefaults in
        let store = PlaybackStore(userDefaults: userDefaults)
        prepareNavigationFocusSentence(in: store)
        store.showQuickSearchAIEntryIfPossible(
            isEnabled: true,
            hasAPIKey: true,
            cachedChunks: ["a", "b"]
        )
        store.configureQuickSearchNavigation(canMoveBack: true, canMoveForward: true)
        store.focusQuickSearchInput()

        #expect(store.moveQuickSearchAIOptionFocus(by: -1))
        #expect(store.quickSearchFocusTarget == .aiOption)
        #expect(extractSelectedAIOption(store) == .refresh)

        #expect(store.moveQuickSearchAIOptionFocus(by: -1))
        #expect(store.quickSearchFocusTarget == .navigation)

        #expect(store.moveQuickSearchAIOptionFocus(by: -1))
        #expect(store.quickSearchFocusTarget == .aiOption)
        #expect(extractSelectedAIOption(store) == .chunks)

        #expect(store.moveQuickSearchAIOptionFocus(by: -1))
        #expect(store.quickSearchFocusTarget == .input)
    }
}

@MainActor
@Test
func quickSearchNavigationAloneMovesBetweenInputAndNavigationOnly() {
    withNavigationFocusUserDefaults { userDefaults in
        let store = PlaybackStore(userDefaults: userDefaults)
        prepareNavigationFocusSentence(in: store)
        store.configureQuickSearchNavigation(canMoveBack: true, canMoveForward: false)

        #expect(store.moveQuickSearchAIOptionFocus(by: 1))
        #expect(store.quickSearchFocusTarget == .navigation)

        #expect(store.moveQuickSearchAIOptionFocus(by: 1))
        #expect(store.quickSearchFocusTarget == .input)

        #expect(store.moveQuickSearchAIOptionFocus(by: -1))
        #expect(store.quickSearchFocusTarget == .navigation)
    }
}

@MainActor
@Test
func quickSearchManualDraftEditHidesNavigationRow() {
    withNavigationFocusUserDefaults { userDefaults in
        let store = PlaybackStore(userDefaults: userDefaults)
        prepareNavigationFocusSentence(in: store)
        store.configureQuickSearchNavigation(canMoveBack: true, canMoveForward: true)
        #expect(store.quickSearchNavigationState != .hidden)

        store.quickSearchDraft = "manual"
        #expect(store.quickSearchNavigationState == .hidden)
    }
}

@MainActor
private func extractSelectedAIOption(_ store: PlaybackStore) -> PlaybackQuickSearchAIOption? {
    if case .options(_, _, let selectedOption) = store.quickSearchAIState {
        return selectedOption
    }
    return nil
}

@MainActor
private func prepareNavigationFocusSentence(in store: PlaybackStore) {
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

private func withNavigationFocusUserDefaults(_ body: (UserDefaults) -> Void) {
    let suiteName = "CueSeekerAppNavigationFocusTests-\(UUID().uuidString)"
    let userDefaults = UserDefaults(suiteName: suiteName)!
    defer {
        userDefaults.removePersistentDomain(forName: suiteName)
    }

    body(userDefaults)
}
