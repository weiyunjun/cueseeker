import AppKit
import Combine
import Foundation
import Testing
import CueSeekerCore
@testable import CueSeekerApp

@MainActor
@Test
func settingsStoreDefaultsShowCueGroupOff() {
    withTemporarySearchSettingsUserDefaults { userDefaults in
        let store = SettingsStore(userDefaults: userDefaults)

        #expect(!store.showCueGroup)
    }
}

@MainActor
@Test
func settingsStorePersistsShowCueGroupChanges() {
    withTemporarySearchSettingsUserDefaults { userDefaults in
        let store = SettingsStore(userDefaults: userDefaults)

        store.showCueGroup = true
        #expect(userDefaults.bool(forKey: "showCueGroup"))

        store.showCueGroup = false
        #expect(!userDefaults.bool(forKey: "showCueGroup"))
    }
}

@MainActor
@Test
func settingsStoreRecordsShowCueGroupUserAction() {
    withTemporarySearchSettingsUserDefaults { userDefaults in
        let store = SettingsStore(userDefaults: userDefaults)

        let recording = UIInvalidationProbe.recordForTesting {
            store.cueGroupPresentation.setFromUser(true)
        }.recording

        #expect(recording.marks == ["ACTION UI.ShowCueGroup.changed"])
        #expect(recording.counters.isEmpty)
    }
}

@MainActor
@Test
func settingsStoreLoadsPersistedShowCueGroupValue() {
    withTemporarySearchSettingsUserDefaults { userDefaults in
        userDefaults.set(true, forKey: "showCueGroup")

        let store = SettingsStore(userDefaults: userDefaults)

        #expect(store.showCueGroup)
    }
}

@MainActor
@Test
func settingsStoreDefaultsSearchFacetsToEveryOptionSelected() {
    withTemporarySearchSettingsUserDefaults { userDefaults in
        let store = SettingsStore(userDefaults: userDefaults)

        #expect(store.searchFacetFilter == CueFacetFilter())
    }
}

@MainActor
@Test
func settingsStoreRestoresSearchFacetSelections() {
    withTemporarySearchSettingsUserDefaults { userDefaults in
        let firstStore = SettingsStore(userDefaults: userDefaults)
        firstStore.searchFacetFilter = CueFacetFilter(
            durations: [.underOneSecond, .fiveSecondsOrMore],
            characters: [],
            languages: [.japanese, .unknown],
            watchStates: [.watching]
        )

        let restoredStore = SettingsStore(userDefaults: userDefaults)

        #expect(restoredStore.searchFacetFilter == firstStore.searchFacetFilter)
    }
}

@MainActor
@Test
func searchFacetPersistenceDoesNotInvalidateGlobalSettingsObservers() {
    withTemporarySearchSettingsUserDefaults { userDefaults in
        let store = SettingsStore(userDefaults: userDefaults)
        var changeCount = 0
        let cancellable = store.objectWillChange.sink {
            changeCount += 1
        }

        store.searchFacetFilter = CueFacetFilter(languages: [.japanese])

        #expect(changeCount == 0)
        withExtendedLifetime(cancellable) {}
    }
}

@Test
func facetCardGridUsesTwoThreeAndArbitraryColumnCounts() {
    let spacing = WorkbenchControlMetrics.redesignSpacing3
    let minimumWidth = WorkbenchControlMetrics.redesignFilterDataCardMinWidth

    #expect(CueFacetAdaptiveGridLayout.columnCount(
        availableWidth: minimumWidth * 2 + spacing,
        cardCount: 7
    ) == 2)
    #expect(CueFacetAdaptiveGridLayout.columnCount(
        availableWidth: minimumWidth * 3 + spacing * 2,
        cardCount: 7
    ) == 3)
    #expect(CueFacetAdaptiveGridLayout.columnCount(
        availableWidth: minimumWidth * 6 + spacing * 5,
        cardCount: 7
    ) == 6)
    #expect(CueFacetAdaptiveGridLayout.columnCount(
        availableWidth: 10_000,
        cardCount: 7
    ) == 7)
    #expect(CueFacetAdaptiveGridLayout.columnCount(
        availableWidth: 10_000,
        cardCount: 1
    ) == 1)
}

@MainActor
@Test
func settingsStoreTreatsUnrecognizedFacetValuesAsNewSelectedOptions() {
    withTemporarySearchSettingsUserDefaults { userDefaults in
        userDefaults.set([
            "language": ["en", "future-language"],
        ], forKey: "searchFacetExclusions")

        let store = SettingsStore(userDefaults: userDefaults)

        #expect(!store.searchFacetFilter.languages.contains(.english))
        #expect(store.searchFacetFilter.languages.contains(.japanese))
        #expect(store.searchFacetFilter.languages.contains(.unknown))
    }
}

@MainActor
private func withTemporarySearchSettingsUserDefaults(
    _ body: (UserDefaults) -> Void
) {
    _ = NSApplication.shared
    let suiteName = "CueSeekerSearchSettingsTests-\(UUID().uuidString)"
    let userDefaults = UserDefaults(suiteName: suiteName)!
    defer {
        userDefaults.removePersistentDomain(forName: suiteName)
    }

    body(userDefaults)
}
