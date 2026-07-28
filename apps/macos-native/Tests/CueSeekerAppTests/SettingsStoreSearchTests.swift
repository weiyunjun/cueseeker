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
func settingsStoreDefaultsSearchFacetsToNoOptionsSelected() {
    withTemporarySearchSettingsUserDefaults { userDefaults in
        let store = SettingsStore(userDefaults: userDefaults)

        #expect(store.searchFacetFilter.durations.isEmpty)
        #expect(store.searchFacetFilter.characters.isEmpty)
        #expect(store.searchFacetFilter.languages.isEmpty)
        #expect(store.searchFacetFilter.watchStates.isEmpty)
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
func settingsStoreKeepsEmptyAndCompleteFacetSelectionsDistinct() {
    withTemporarySearchSettingsUserDefaults { userDefaults in
        let firstStore = SettingsStore(userDefaults: userDefaults)
        firstStore.searchFacetFilter = CueFacetFilter()

        let emptyRestoredStore = SettingsStore(userDefaults: userDefaults)
        #expect(emptyRestoredStore.searchFacetFilter == CueFacetFilter())

        let completeFilter = CueFacetFilter(
            durations: Set(CueDurationFacet.allCases),
            characters: Set(CueCharacterFacet.allCases),
            languages: Set(SubtitleLanguageCode.allCases),
            watchStates: [.finished, .watching, .unwatched]
        )
        emptyRestoredStore.searchFacetFilter = completeFilter

        let completeRestoredStore = SettingsStore(userDefaults: userDefaults)
        #expect(completeRestoredStore.searchFacetFilter == completeFilter)
        #expect(completeRestoredStore.searchFacetFilter != CueFacetFilter())
    }
}

@MainActor
@Test
func settingsStoreKeepsSearchAndShioriFacetSelectionsIndependent() {
    withTemporarySearchSettingsUserDefaults { userDefaults in
        let firstStore = SettingsStore(userDefaults: userDefaults)
        let searchFilter = CueFacetFilter(languages: [.japanese])
        let firstListFilter = CueFacetFilter(
            durations: [.underOneSecond],
            watchStates: [.watching]
        )
        let secondListFilter = CueFacetFilter(
            characters: [.thirtyOneOrMore],
            languages: [.unknown]
        )

        firstStore.searchFacetFilter = searchFilter
        firstStore.setShioriFacetFilter(firstListFilter, forListID: 1)
        firstStore.setShioriFacetFilter(secondListFilter, forListID: 2)

        let restoredStore = SettingsStore(userDefaults: userDefaults)
        #expect(restoredStore.searchFacetFilter == searchFilter)
        #expect(restoredStore.shioriFacetFilter(forListID: 1) == firstListFilter)
        #expect(restoredStore.shioriFacetFilter(forListID: 2) == secondListFilter)
        #expect(restoredStore.shioriFacetFilter(forListID: 3) == CueFacetFilter())
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
        store.setShioriFacetFilter(
            CueFacetFilter(watchStates: [.finished]),
            forListID: 1
        )

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
func settingsStorePreservesKnownSelectionsBesideUnrecognizedExclusions() {
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
@Test
func settingsStoreIgnoresUnrecognizedShioriFacetExclusions() {
    withTemporarySearchSettingsUserDefaults { userDefaults in
        userDefaults.set([
            "7": [
                "language": ["en", "future-language"],
            ],
        ], forKey: "shioriFacetExclusionsByListID")

        let store = SettingsStore(userDefaults: userDefaults)
        let filter = store.shioriFacetFilter(forListID: 7)

        #expect(!filter.languages.contains(.english))
        #expect(filter.languages.contains(.japanese))
        #expect(filter.languages.contains(.unknown))
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
