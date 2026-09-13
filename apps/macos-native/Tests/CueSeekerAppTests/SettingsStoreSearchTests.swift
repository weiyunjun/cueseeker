import AppKit
import Combine
import Foundation
import SwiftUI
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
func settingsStoreDefaultsCommandPanelFocusedCuePrefillOff() {
    withTemporarySearchSettingsUserDefaults { userDefaults in
        let store = SettingsStore(userDefaults: userDefaults)

        #expect(!store.prefillCommandPanelWithFocusedCue)
    }
}

@MainActor
@Test
func settingsStorePersistsCommandPanelFocusedCuePrefillChanges() {
    withTemporarySearchSettingsUserDefaults { userDefaults in
        let store = SettingsStore(userDefaults: userDefaults)

        store.prefillCommandPanelWithFocusedCue = true

        #expect(userDefaults.bool(
            forKey: "prefillCommandPanelWithFocusedCue"
        ))
        #expect(
            SettingsStore(userDefaults: userDefaults)
                .prefillCommandPanelWithFocusedCue
        )
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
func settingsStoreKeepsSearchAndExcerptFacetSelectionsIndependent() {
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
        firstStore.setExcerptFacetFilter(firstListFilter, forListID: 1)
        firstStore.setExcerptFacetFilter(secondListFilter, forListID: 2)

        let restoredStore = SettingsStore(userDefaults: userDefaults)
        #expect(restoredStore.searchFacetFilter == searchFilter)
        #expect(restoredStore.excerptFacetFilter(forListID: 1) == firstListFilter)
        #expect(restoredStore.excerptFacetFilter(forListID: 2) == secondListFilter)
        #expect(restoredStore.excerptFacetFilter(forListID: 3) == CueFacetFilter())
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
        store.setExcerptFacetFilter(
            CueFacetFilter(watchStates: [.finished]),
            forListID: 1
        )

        #expect(changeCount == 0)
        withExtendedLifetime(cancellable) {}
    }
}

@MainActor
@Test
func filterMenuFlattensTitleSectionsAndOptionsInOrder() {
    var filter = CueFacetFilter()
    let model = CueFacetFilterMenuModel(
        distribution: nil,
        availableLanguages: [.english, .japanese],
        isCalculating: false,
        filter: Binding(get: { filter }, set: { filter = $0 })
    )

    // The title, then four sections of divider + header + options
    // (4 durations, 4 character ranges, 2 languages, 3 watch states).
    #expect(model.elements.count == 22)
    guard case .title = model.elements[0] else {
        Issue.record("the menu must lead with its title")
        return
    }

    // Only option rows can take the highlight; the first selectable position
    // is Duration's <1s, which the menu highlights on open.
    #expect(model.selectablePositions.count == 13)
    #expect(model.selectablePositions.first == 3)
    #expect(
        model.option(at: 3)?.id == CueDurationFacet.underOneSecond.rawValue
    )

    // Checking through the model applies straight to the filter.
    model.option(at: 3)?.toggle()
    #expect(filter.durations.contains(.underOneSecond))
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
func settingsStoreIgnoresUnrecognizedExcerptFacetExclusions() {
    withTemporarySearchSettingsUserDefaults { userDefaults in
        userDefaults.set([
            "7": [
                "language": ["en", "future-language"],
            ],
        ], forKey: "excerptFacetExclusionsByListID")

        let store = SettingsStore(userDefaults: userDefaults)
        let filter = store.excerptFacetFilter(forListID: 7)

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
