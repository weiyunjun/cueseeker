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
func filterDialogListsTheFourCardsAndTogglesTheDialogSelection() {
    var filter = CueFacetFilter()
    let sections = CueFacetSection.sections(
        counts: CueFacetFilterCounts(
            distribution: nil,
            isCalculating: false,
            totalCount: nil
        ),
        availableLanguages: [.english, .japanese],
        availableFolders: [],
        selection: filter,
        update: { change in change(&filter) }
    )

    // Duration, Character, Language, Watch Status and Folder, with 4
    // durations, 4 character ranges, the 2 languages, 3 watch states and no
    // folder listed.
    #expect(sections.map(\.id) == [.duration, .characters, .languages, .watchState, .folder])
    #expect(sections.map(\.options.count) == [4, 4, 2, 3, 0])
    #expect(sections[0].options[0].id == CueDurationFacet.underOneSecond.rawValue)
    #expect(sections.allSatisfy { $0.options.allSatisfy { $0.count == 0 } })

    // A toggle reads the selection as it is now, so a second one undoes the
    // first even without a new render in between.
    sections[0].options[0].toggle()
    #expect(filter.durations == [.underOneSecond])
    sections[0].options[0].toggle()
    #expect(filter.durations.isEmpty)
}

@MainActor
@Test
func filterDialogListsFoldersLastInLibraryOrderAndTogglesThemInTheSelection() {
    var filter = CueFacetFilter()
    let distribution = CueFacetDistribution(
        totalCount: 3,
        durationCounts: [:],
        characterCounts: [:],
        languageCounts: [:],
        watchStateCounts: [:],
        folderCounts: [
            "/Media/Season 10": 0,
            "/Media/Season 2": 0,
            "/Media/beta": 2,
            "/Media/Alpha": 1,
            "/Other/Alpha": 0
        ]
    )
    // The library's folders by natural name order, then path.
    let folders = CueFacetFolderOption.listed(emptyDistribution: distribution, snapshot: nil)
    #expect(folders.map(\.path) == [
        "/Media/Alpha",
        "/Other/Alpha",
        "/Media/beta",
        "/Media/Season 2",
        "/Media/Season 10"
    ])
    #expect(folders.map(\.title) == ["Alpha", "Alpha", "beta", "Season 2", "Season 10"])

    let sections = CueFacetSection.sections(
        counts: CueFacetFilterCounts(
            distribution: distribution,
            isCalculating: false,
            totalCount: 3
        ),
        availableLanguages: [],
        availableFolders: folders,
        selection: filter,
        update: { change in change(&filter) }
    )
    let folderSection = try! #require(sections.last)
    #expect(folderSection.id == .folder)
    #expect(folderSection.options.map(\.title) == ["Alpha", "Alpha", "beta", "Season 2", "Season 10"])
    #expect(folderSection.options.map(\.count) == [1, 0, 2, 0, 0])
    #expect(folderSection.options.allSatisfy { !$0.isSelected })

    // Selecting one folder leaves the other listed folders out.
    folderSection.options[2].toggle()
    #expect(filter.excludedFolders == ["/Media/Alpha", "/Other/Alpha", "/Media/Season 2", "/Media/Season 10"])
    #expect(filter.isFolderSelected("/Media/beta"))
    #expect(!filter.isFolderSelected("/Media/Alpha"))
}

@MainActor
@Test
func filterTriggerCountsTheOptionsTheSelectionHoldsAmongTheListedOnes() {
    let distribution = CueFacetDistribution(
        totalCount: 3,
        durationCounts: [:],
        characterCounts: [:],
        languageCounts: [.japanese: 3],
        watchStateCounts: [:],
        folderCounts: ["/Media/A": 1, "/Media/B": 1, "/Media/C": 1]
    )
    #expect(CueFacetFilter().selectedOptionCount(emptyDistribution: distribution, snapshot: nil) == 0)

    // Two durations, one language, one watch state and the two listed folders
    // the selection keeps.
    let filter = CueFacetFilter(
        durations: [.underOneSecond, .fiveSecondsOrMore],
        languages: [.japanese],
        watchStates: [.finished],
        excludedFolders: ["/Media/B"]
    )
    #expect(filter.selectedOptionCount(emptyDistribution: distribution, snapshot: nil) == 6)
}

@MainActor
@Test
func settingsStoreRestoresFolderSelectionsAndKeepsNoSelectionApart() {
    withTemporarySearchSettingsUserDefaults { userDefaults in
        let store = SettingsStore(userDefaults: userDefaults)
        store.searchFacetFilter = CueFacetFilter(excludedFolders: ["/Media/B", "/Media/C"])
        #expect(SettingsStore(userDefaults: userDefaults).searchFacetFilter.excludedFolders == ["/Media/B", "/Media/C"])

        // Every listed folder selected is still a selection; none is none.
        store.searchFacetFilter = CueFacetFilter(excludedFolders: [])
        #expect(SettingsStore(userDefaults: userDefaults).searchFacetFilter.excludedFolders == [])
        store.searchFacetFilter = CueFacetFilter()
        #expect(SettingsStore(userDefaults: userDefaults).searchFacetFilter.excludedFolders == nil)
    }
}

@MainActor
@Test
func filterDialogLeavesEveryCountBlankUntilTheCountsAreKnown() {
    var filter = CueFacetFilter()
    filter.languages = [.english]
    let distribution = CueFacetDistribution(
        totalCount: 2,
        durationCounts: [.underOneSecond: 2],
        characterCounts: [:],
        languageCounts: [.english: 2],
        watchStateCounts: [:],
        folderCounts: [:]
    )
    func sections(isCalculating: Bool) -> [CueFacetSection] {
        CueFacetSection.sections(
            counts: CueFacetFilterCounts(
                distribution: isCalculating ? nil : distribution,
                isCalculating: isCalculating,
                totalCount: isCalculating ? nil : 2
            ),
            availableLanguages: [.english, .japanese],
            availableFolders: [],
            selection: filter,
            update: { _ in }
        )
    }

    // While the search runs every count is unknown; once it completes every
    // option has its number, zero included.
    #expect(sections(isCalculating: true).allSatisfy { $0.options.allSatisfy { $0.count == nil } })
    #expect(sections(isCalculating: false)[0].options[0].count == 2)
    #expect(sections(isCalculating: false)[2].options.map(\.count) == [2, 0])
}

@MainActor
@Test
func filterDialogCountsNeverSearchAndWaitForTheCompleteRows() {
    let searchFilter = CueFacetFilter()
    let other = CueFacetFilter(durations: [.underOneSecond])
    let running = CueFacetFilterCounts(
        distribution: nil,
        isCalculating: true,
        totalCount: nil
    )
    let complete = CueFacetDistribution(
        totalCount: 3,
        durationCounts: [.underOneSecond: 3],
        characterCounts: [:],
        languageCounts: [:],
        watchStateCounts: [:],
        folderCounts: [:]
    )

    // The selection the search runs with keeps the search's own counts.
    let own = CueFacetFilterCounts.search(
        selection: searchFilter,
        searchFilter: searchFilter,
        isQueryEmpty: false,
        searchCounts: running,
        completeDistribution: { _ in complete }
    )
    #expect(own.isCalculating && own.totalCount == nil)

    // Another selection before the rows are complete knows nothing yet.
    let waiting = CueFacetFilterCounts.search(
        selection: other,
        searchFilter: searchFilter,
        isQueryEmpty: false,
        searchCounts: running,
        completeDistribution: { _ in nil }
    )
    #expect(waiting.isCalculating && waiting.totalCount == nil)

    // Once they are, it is answered from them.
    let answered = CueFacetFilterCounts.search(
        selection: other,
        searchFilter: searchFilter,
        isQueryEmpty: false,
        searchCounts: running,
        completeDistribution: { $0 == other ? complete : nil }
    )
    #expect(!answered.isCalculating)
    #expect(answered.distribution == complete)
    #expect(answered.totalCount == 3)

    // With no query there is nothing to count or wait for.
    let empty = CueFacetFilterCounts.search(
        selection: other,
        searchFilter: searchFilter,
        isQueryEmpty: true,
        searchCounts: running,
        completeDistribution: { _ in nil }
    )
    #expect(!empty.isCalculating && empty.totalCount == 0)
}

@MainActor
@Test
func filterDialogShowHandsOverOnlyAChangedSelection() {
    var applied: [CueFacetFilter] = []
    let session = CueFacetFilterDialogSession(
        source: .search,
        filter: CueFacetFilter(),
        apply: { applied.append($0) }
    )

    session.show()
    #expect(applied.isEmpty)

    session.filter.durations = [.underOneSecond]
    session.show()
    #expect(applied == [CueFacetFilter(durations: [.underOneSecond])])
}

@MainActor
@Test
func filterDialogPrimaryActionTitleCoversEmptySearchTrilingualCountsAndPreservesNonEmptyAndExcerpt() {
    defer { AppLocalization.apply(.english) }

    let expectedEmptySearchByLanguage: [(AppLanguage, [Int: String])] = [
        (.english, [
            0: "Apply 0 filters",
            1: "Apply 1 filter",
            2: "Apply 2 filters",
            1234: "Apply 1234 filters",
        ]),
        (.simplifiedChinese, [
            0: "应用 0 个筛选条件",
            1: "应用 1 个筛选条件",
            2: "应用 2 个筛选条件",
            1234: "应用 1234 个筛选条件",
        ]),
        (.traditionalChinese, [
            0: "套用 0 個篩選條件",
            1: "套用 1 個篩選條件",
            2: "套用 2 個篩選條件",
            1234: "套用 1234 個篩選條件",
        ]),
    ]

    for (language, expectedByCount) in expectedEmptySearchByLanguage {
        AppLocalization.apply(language)
        for (count, expectedTitle) in expectedByCount {
            #expect(
                CueFacetFilterDialogSession.Source.search.primaryActionTitle(
                    totalCount: nil,
                    selectedFilterCount: count,
                    isQueryEmpty: true
                ) == expectedTitle
            )
            #expect(
                CueFacetFilterDialogSession.Source.search.primaryActionTitle(
                    totalCount: 0,
                    selectedFilterCount: count,
                    isQueryEmpty: true
                ) == expectedTitle
            )
        }
    }

    AppLocalization.apply(.english)
    #expect(
        CueFacetFilterDialogSession.Source.search.primaryActionTitle(
            totalCount: nil,
            selectedFilterCount: 3,
            isQueryEmpty: false
        ) == "Calculating"
    )
    #expect(
        CueFacetFilterDialogSession.Source.search.primaryActionTitle(
            totalCount: 1,
            selectedFilterCount: 3,
            isQueryEmpty: false
        ) == "Show 1 result"
    )
    #expect(
        CueFacetFilterDialogSession.Source.search.primaryActionTitle(
            totalCount: 1234,
            selectedFilterCount: 3,
            isQueryEmpty: false
        ) == "Show 1234 results"
    )

    for isQueryEmpty in [false, true] {
        #expect(
            CueFacetFilterDialogSession.Source.excerpt.primaryActionTitle(
                totalCount: nil,
                selectedFilterCount: 2,
                isQueryEmpty: isQueryEmpty
            ) == "Calculating"
        )
        #expect(
            CueFacetFilterDialogSession.Source.excerpt.primaryActionTitle(
                totalCount: 1,
                selectedFilterCount: 2,
                isQueryEmpty: isQueryEmpty
            ) == "Show 1 excerpt"
        )
        #expect(
            CueFacetFilterDialogSession.Source.excerpt.primaryActionTitle(
                totalCount: 2,
                selectedFilterCount: 2,
                isQueryEmpty: isQueryEmpty
            ) == "Show 2 excerpts"
        )
    }
}

@MainActor
@Test
func filterDialogEmptyAndWhitespaceSearchQueriesStayApplyReadyWithMatchingSelectedCount() {
    let search = SearchStore()

    for query in ["", "   \t "] {
        search.updateQuery(query)
        let state = SearchFacetDialogSearchState(search)
        let counts = state.counts(for: CueFacetFilter(durations: [.underOneSecond]))
        #expect(state.isQueryEmpty)
        #expect(!counts.isCalculating)
        #expect(counts.totalCount == 0)
    }

    search.updateQuery("cue")
    #expect(!SearchFacetDialogSearchState(search).isQueryEmpty)

    let distribution = CueFacetDistribution(
        totalCount: 3,
        durationCounts: [:],
        characterCounts: [:],
        languageCounts: [.japanese: 3],
        watchStateCounts: [:],
        folderCounts: ["/Media/A": 1, "/Media/B": 1, "/Media/C": 1]
    )
    let availableLanguages = SubtitleLanguageCode.listed(
        emptyDistribution: distribution,
        snapshot: nil
    )
    let availableFolders = CueFacetFolderOption.listed(
        emptyDistribution: distribution,
        snapshot: nil
    )
    func sectionSelectedSum(_ selection: CueFacetFilter) -> Int {
        CueFacetSection.sections(
            counts: CueFacetFilterCounts(
                distribution: .zero,
                isCalculating: false,
                totalCount: 0
            ),
            availableLanguages: availableLanguages,
            availableFolders: availableFolders,
            selection: selection,
            update: { _ in }
        )
        .reduce(0) { $0 + $1.selectedCount }
    }

    var filter = CueFacetFilter()
    #expect(sectionSelectedSum(filter) == 0)

    filter.durations = [.underOneSecond]
    #expect(sectionSelectedSum(filter) == 1)
    #expect(filter.selectedOptionCount(emptyDistribution: distribution, snapshot: nil) == 1)

    filter = CueFacetFilter(
        durations: [.underOneSecond, .fiveSecondsOrMore],
        languages: [.japanese],
        watchStates: [.finished],
        excludedFolders: ["/Media/B"]
    )
    #expect(sectionSelectedSum(filter) == 6)
    #expect(filter.selectedOptionCount(emptyDistribution: distribution, snapshot: nil) == 6)

    filter = CueFacetFilter()
    #expect(sectionSelectedSum(filter) == 0)
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
@Test
func settingsStorePersistsSearchAndExcerptSortOrdersIndependentlyAndCleansUpDeletedLists() {
    withTemporarySearchSettingsUserDefaults { userDefaults in
        let firstStore = SettingsStore(userDefaults: userDefaults)
        #expect(firstStore.searchSortOrder == .default)
        #expect(firstStore.excerptSortOrder(forListID: 1) == .earliestDateAdded)
        #expect(firstStore.excerptSortOrder(forListID: 2) == .earliestDateAdded)

        firstStore.searchSortOrder = .mostCharacters
        firstStore.setExcerptSortOrder(.latestDateAdded, forListID: 1)
        firstStore.setExcerptSortOrder(.fewestCharacters, forListID: 2)
        firstStore.setExcerptFacetFilter(CueFacetFilter(languages: [.japanese]), forListID: 2)

        let restoredStore = SettingsStore(userDefaults: userDefaults)
        #expect(restoredStore.searchSortOrder == .mostCharacters)
        #expect(restoredStore.excerptSortOrder(forListID: 1) == .latestDateAdded)
        #expect(restoredStore.excerptSortOrder(forListID: 2) == .fewestCharacters)
        #expect(restoredStore.excerptSortOrder(forListID: 3) == .earliestDateAdded)

        restoredStore.removeExcerptListSettings(forListID: 2)
        #expect(restoredStore.excerptSortOrder(forListID: 2) == .earliestDateAdded)
        #expect(restoredStore.excerptFacetFilter(forListID: 2) == CueFacetFilter())

        let postDeleteStore = SettingsStore(userDefaults: userDefaults)
        #expect(postDeleteStore.excerptSortOrder(forListID: 1) == .latestDateAdded)
        #expect(postDeleteStore.excerptSortOrder(forListID: 2) == .earliestDateAdded)
        #expect(postDeleteStore.excerptFacetFilter(forListID: 2) == CueFacetFilter())
    }
}

@MainActor
private func withTemporarySearchSettingsUserDefaults(
    _ body: (UserDefaults) -> Void
) {
    _ = NSApplication.shared
    let suiteName = "CueSeekerSearchSettingsTests-\(UUID().uuidString)"
    let userDefaults = UserDefaults.temporary(suiteName: suiteName)!
    defer {
        userDefaults.removePersistentDomainAndPlist(forName: suiteName)
    }

    body(userDefaults)
}
