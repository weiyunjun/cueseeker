import Foundation
import AppKit
import Combine
import Testing
@testable import CueSeekerCore
@testable import CueSeekerApp

@Test
func searchInputNormalizerReplacesEveryLineBreakWithSpaces() {
    #expect(
        SearchInputNormalizer.singleLine(
            "first\r\nsecond\nthird\rfourth\u{2028}fifth\u{2029}sixth"
        ) == "first second third fourth fifth sixth"
    )
    #expect(SearchInputNormalizer.singleLine("  keep  spaces  ") == "  keep  spaces  ")
}

@MainActor
@Test
func searchStoresPersistOnlyNormalizedSingleLineQueries() {
    let search = SearchStore()
    search.updateQuery("one\r\ntwo\nthree")
    #expect(search.searchQuery == "one two three")

    let excerpt = ExcerptStore()
    #expect(excerpt.updateTableSearchDraft("one\r\ntwo\nthree"))
    #expect(excerpt.tableSearchDraft == "one two three")
}

@MainActor
@Test
func searchFilterMenuDefaultsToClosed() {
    #expect(!WorkbenchTestSearchView.defaultFilterMenuOpen)
}

@MainActor
@Test
func emptySearchDisplaysZeroFacetCounts() {
    let search = SearchStore()

    #expect(search.displayedSearchFacetDistribution == .zero)
}

@MainActor
@Test
func excerptFilterMenuDefaultsToClosed() {
    #expect(!WorkbenchExcerptTableView.defaultFilterMenuOpen)
}

@MainActor
extension SearchStore {
    func replaceResidentResults(_ results: [SubtitleSearchResult]) {
        replaceResultState(
            results: results,
            status: .completed,
            totalCount: results.count,
            fileSummaries: [],
            countState: .exact,
            knownResultCount: results.count,
            knownFileCount: 0,
            hasMore: false
        )
    }
}

@MainActor
@Test
func searchInputDebounceIsOneHundredMilliseconds() {
    #expect(SearchStore.searchInputDebounceNanoseconds == 100_000_000)
}

@MainActor
@Test
func folderScopeChangeRejectsStaleNavigationAcrossABA() async {
    let search = SearchStore()
    let folderA = URL(fileURLWithPath: "/tmp/CueSeeker-Scope-A")
    let folderB = URL(fileURLWithPath: "/tmp/CueSeeker-Scope-B")
    let stalePage = TableSandboxSearchHydrationPage(
        range: 0..<1,
        results: [
            makeTableSandboxSearchResult(
                id: 42,
                content: "stale folder A result",
                searchRank: 0
            )
        ],
        totalRowCount: 1
    )

    _ = search.updateFolderScope([folderA])
    let staleGeneration = search.folderScopeGeneration
    let staleTask = Task { @MainActor in
        await Task.yield()
        guard !Task.isCancelled,
              search.acceptsFolderScope(
                [folderA],
                generation: staleGeneration
              )
        else {
            return
        }
        search.applyAllCueSearchPage(stalePage)
    }
    search.replaceNavigationTask(staleTask)

    _ = search.updateFolderScope([folderB])
    _ = search.updateFolderScope([folderA])
    await staleTask.value

    #expect(staleTask.isCancelled)
    #expect(search.folderScopeGeneration != staleGeneration)
    #expect(!search.acceptsFolderScope(
        [folderA],
        generation: staleGeneration
    ))
    #expect(search.searchResults.isEmpty)
}

@MainActor
@Test
func addingEmptyFolderRestartsInvalidatedActiveSearch() async throws {
    let suiteName = "CueSeekerEmptyFolderSearchLifecycleTests-\(UUID().uuidString)"
    let userDefaults = try #require(UserDefaults(suiteName: suiteName))
    let testRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent(suiteName, isDirectory: true)
    defer {
        userDefaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: testRoot)
    }

    let app = try await makeFolderScopeLifecycleApp(
        userDefaults: userDefaults,
        testRoot: testRoot
    )
    app.updateSearchQuery("scope lifecycle")
    let staleTask = try #require(app.search.searchTask)
    let emptyFolder = testRoot.appendingPathComponent(
        "Empty",
        isDirectory: true
    )
    try FileManager.default.createDirectory(
        at: emptyFolder,
        withIntermediateDirectories: true
    )

    app.addFolder(emptyFolder)
    let replacementTask = try #require(app.search.searchTask)
    await app.indexingTask?.value
    await app.libraryTask?.value
    await app.recentWatchingTask?.value
    await app.completeLibraryTask?.value
    await app.databaseStorageStatsTask?.value
    await replacementTask.value
    await app.search.exactCompletionTask?.value

    #expect(staleTask.isCancelled)
    guard case let .completed(_, result) = app.indexing.indexingStatus else {
        Issue.record("Expected empty folder indexing to complete")
        return
    }
    #expect(!result.hasIndexedContentChanges)
    #expect(!app.search.isSearching)
    #expect(app.search.searchStatus == .completed)
    #expect(app.search.searchResults.map(\.content) == [
        "scope lifecycle result"
    ])
}

@MainActor
@Test
func failedFolderIndexRestartsInvalidatedActiveSearch() async throws {
    let suiteName = "CueSeekerFailedFolderSearchLifecycleTests-\(UUID().uuidString)"
    let userDefaults = try #require(UserDefaults(suiteName: suiteName))
    let testRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent(suiteName, isDirectory: true)
    defer {
        userDefaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: testRoot)
    }

    let app = try await makeFolderScopeLifecycleApp(
        userDefaults: userDefaults,
        testRoot: testRoot
    )
    app.updateSearchQuery("scope lifecycle")
    let staleTask = try #require(app.search.searchTask)
    let invalidFolder = testRoot.appendingPathComponent("Not a folder")
    try Data("file root".utf8).write(to: invalidFolder)

    app.addFolder(invalidFolder)
    let replacementTask = try #require(app.search.searchTask)
    await app.indexingTask?.value
    await replacementTask.value
    await app.search.exactCompletionTask?.value

    #expect(staleTask.isCancelled)
    guard case let .failed(folder, _) = app.indexing.indexingStatus else {
        Issue.record("Expected file root indexing to fail")
        return
    }
    #expect(folder == invalidFolder)
    #expect(!app.search.isSearching)
    #expect(app.search.searchStatus == .completed)
    #expect(app.search.searchResults.map(\.content) == [
        "scope lifecycle result"
    ])
}

@MainActor
private func makeFolderScopeLifecycleApp(
    userDefaults: UserDefaults,
    testRoot: URL
) async throws -> AppCoordinator {
    let libraryRoot = testRoot.appendingPathComponent(
        "Library",
        isDirectory: true
    )
    try FileManager.default.createDirectory(
        at: libraryRoot,
        withIntermediateDirectories: true
    )
    try """
    1
    00:00:01,000 --> 00:00:02,000
    scope lifecycle result

    """.write(
        to: libraryRoot.appendingPathComponent("Episode.srt"),
        atomically: true,
        encoding: .utf8
    )
    try Data([0]).write(
        to: libraryRoot.appendingPathComponent("Episode.mkv")
    )

    _ = NSApplication.shared
    let app = AppCoordinator(
        userDefaults: userDefaults,
        databaseURL: testRoot.appendingPathComponent("CueSeeker.sqlite")
    )
    app.addFolder(libraryRoot)
    await app.indexingTask?.value
    await app.libraryTask?.value
    await app.recentWatchingTask?.value
    await app.completeLibraryTask?.value
    await app.databaseStorageStatsTask?.value
    guard case .completed = app.indexing.indexingStatus else {
        Issue.record("Expected lifecycle fixture indexing to complete")
        return app
    }
    return app
}

@MainActor
@Test
func resultStateCommitPublishesOneCoherentRevision() {
    let search = SearchStore()
    let result = makeTableSandboxSearchResult(
        id: 42,
        content: "atomic result",
        searchRank: 0
    )
    var observedStates: [(Int, Int, SearchStatus)] = []
    let cancellable = search.$resultRevision.dropFirst().sink { _ in
        observedStates.append((
            search.searchResults.count,
            search.searchResultTotalCount,
            search.searchStatus
        ))
    }
    defer { cancellable.cancel() }

    search.replaceResultState(
        results: [result],
        status: .completed,
        totalCount: 1,
        fileSummaries: [],
        countState: .exact,
        knownResultCount: 1,
        knownFileCount: 0,
        hasMore: false
    )

    #expect(observedStates.count == 1)
    #expect(observedStates.first?.0 == 1)
    #expect(observedStates.first?.1 == 1)
    #expect(observedStates.first?.2 == .completed)
}

@MainActor
@Test
func liveSearchUsesLatestInputAndClearsWithoutSubmit() async throws {
    let suiteName = "CueSeekerLiveSearchInputTests-\(UUID().uuidString)"
    let userDefaults = try #require(UserDefaults(suiteName: suiteName))
    let fixtureRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerLiveSearchInputTests-\(UUID().uuidString)", isDirectory: true)
    let databaseURL = fixtureRoot.appendingPathComponent("CueSeeker.sqlite")
    try FileManager.default.createDirectory(
        at: fixtureRoot,
        withIntermediateDirectories: true
    )

    _ = NSApplication.shared
    let app = AppCoordinator(userDefaults: userDefaults, databaseURL: databaseURL)
    defer {
        app.search.searchTask?.cancel()
        app.search.exactCompletionTask?.cancel()
        userDefaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: fixtureRoot)
    }

    let database = try #require(app.indexingDatabase)
    try database.replaceEntries(
        subtitleFile: fixtureRoot.appendingPathComponent("Episode.srt"),
        videoFile: fixtureRoot.appendingPathComponent("Episode.mkv"),
        entries: [
            SubtitleEntry(
                sequenceNumber: 1,
                startTimecode: "00:00:01,000",
                endTimecode: "00:00:02,000",
                startMilliseconds: 1_000,
                endMilliseconds: 2_000,
                text: "alpha live query"
            ),
            SubtitleEntry(
                sequenceNumber: 2,
                startTimecode: "00:00:03,000",
                endTimecode: "00:00:04,000",
                startMilliseconds: 3_000,
                endMilliseconds: 4_000,
                text: "beta live query"
            ),
        ]
    )
    app.indexing.selectedFolders = [fixtureRoot]

    app.updateSearchQuery("alpha")
    let alphaTask = try #require(app.search.searchTask)
    let staleExactTask = Task<Void, Never> {
        try? await Task.sleep(nanoseconds: 10_000_000_000)
    }
    app.search.replaceExactCompletionTask(staleExactTask)

    app.updateSearchQuery("beta")
    let betaTask = try #require(app.search.searchTask)

    #expect(alphaTask.isCancelled)
    #expect(staleExactTask.isCancelled)
    #expect(app.search.searchQuery == "beta")
    #expect(app.search.activePerformanceRun?.query == "beta")
    #expect(app.search.activePerformanceRun?.debounce == true)

    await betaTask.value

    #expect(!app.search.searchResults.isEmpty)
    #expect(app.search.searchResults.allSatisfy { $0.content.contains("beta") })
    #expect(app.search.searchResults.allSatisfy { !$0.content.contains("alpha") })

    app.updateSearchQuery("alpha")
    let pendingAlphaTask = try #require(app.search.searchTask)
    let staleResults = [
        makeTableSandboxSearchResult(
            id: 999,
            content: "stale pending row",
            searchRank: 0
        )
    ]
    app.search.replaceResultState(
        results: staleResults,
        orderedCueIDs: [999],
        status: .searching,
        totalCount: 1,
        fileSummaries: [],
        countState: .exact,
        knownResultCount: 1,
        knownFileCount: 0,
        hasMore: true
    )

    app.updateSearchQuery("")

    #expect(pendingAlphaTask.isCancelled)
    #expect(app.search.searchQuery.isEmpty)
    #expect(app.search.searchStatus == .idle)
    #expect(app.search.searchResults.isEmpty)
    #expect(app.search.searchResultCueIDs.isEmpty)
    #expect(app.search.searchResultTotalCount == 0)
    #expect(app.search.searchNavigationSnapshot == nil)
    #expect(!app.search.hasMoreSearchResults)
}

@MainActor
@Test
func exactFacetSnapshotRejectsStaleResultGeneration() throws {
    let search = SearchStore()
    search.updateQuery("first")
    let firstGeneration = search.prepareSearch(
        appending: false,
        filterSet: SubtitleSearchFilterSet()
    )
    let firstResult = makeTableSandboxSearchResult(
        id: 1,
        content: "first",
        searchRank: 0
    )
    let firstSnapshot = CueFacetSnapshot(
        cueIDs: [firstResult.entryID],
        durationFacets: [.oneToUnderThreeSeconds],
        characterFacets: [.oneToTen],
        languageFacets: [[.english]],
        watchStateFacets: [.unwatched]
    )
    let firstPage = SubtitleSearchPage(
        results: [firstResult],
        cueIDs: firstSnapshot.cueIDs,
        totalCount: 1,
        fileSummaries: [],
        facetSnapshot: firstSnapshot
    )
    #expect(search.commitExactSearchPage(
        firstPage,
        generation: firstGeneration
    ))
    #expect(search.searchFacetSnapshot == firstSnapshot)

    search.updateQuery("second")
    #expect(search.searchFacetSnapshot == nil)
    #expect(search.isFacetSnapshotCalculating)
    let secondGeneration = search.prepareSearch(
        appending: false,
        filterSet: SubtitleSearchFilterSet()
    )
    search.markSearchInProgress()

    #expect(!search.commitExactSearchPage(
        firstPage,
        generation: firstGeneration
    ))
    #expect(search.searchFacetSnapshot == nil)

    let secondResult = makeTableSandboxSearchResult(
        id: 2,
        content: "second",
        searchRank: 0
    )
    let secondSnapshot = CueFacetSnapshot(
        cueIDs: [secondResult.entryID],
        durationFacets: [.underOneSecond],
        characterFacets: [.oneToTen],
        languageFacets: [[.japanese]],
        watchStateFacets: [.watching]
    )
    let secondPage = SubtitleSearchPage(
        results: [secondResult],
        cueIDs: secondSnapshot.cueIDs,
        totalCount: 1,
        fileSummaries: [],
        facetSnapshot: secondSnapshot
    )
    #expect(search.commitExactSearchPage(
        secondPage,
        generation: secondGeneration
    ))
    #expect(search.searchFacetSnapshot == secondSnapshot)
    #expect(search.searchResultCueIDs == secondSnapshot.cueIDs)
    #expect(!search.isFacetSnapshotCalculating)
}

@MainActor
@Test
func facetFilterProjectsTableIDsWithoutChangingExactSearchBoundary() async {
    let search = SearchStore()
    search.updateQuery("query")
    let generation = search.prepareSearch(
        appending: false,
        filterSet: SubtitleSearchFilterSet()
    )
    let results = (0..<120).map { index in
        makeTableSandboxSearchResult(
            id: Int64(index + 1),
            content: "result \(index)",
            searchRank: index
        )
    }
    let snapshot = CueFacetSnapshot(
        cueIDs: results.map(\.entryID),
        durationFacets: (0..<120).map {
            $0.isMultiple(of: 2) ? .underOneSecond : .fiveSecondsOrMore
        },
        characterFacets: Array(repeating: .oneToTen, count: 120),
        languageFacets: Array(repeating: [.english], count: 120),
        watchStateFacets: Array(repeating: .unwatched, count: 120)
    )
    let page = SubtitleSearchPage(
        results: results,
        cueIDs: snapshot.cueIDs,
        totalCount: results.count,
        fileSummaries: [],
        facetSnapshot: snapshot
    )
    #expect(search.commitExactSearchPage(page, generation: generation))

    search.updateSearchFacetFilter(CueFacetFilter(
        durations: [.underOneSecond],
        characters: Set(CueCharacterFacet.allCases),
        languages: Set(SubtitleLanguageCode.allCases),
        watchStates: [.unwatched, .watching, .finished]
    ))
    #expect(search.filteredSearchResultCueIDs.count == 50)
    #expect(search.filteredSearchResultTotalCount == nil)

    for _ in 0..<20 where search.filteredSearchResultTotalCount == nil {
        await Task.yield()
    }

    #expect(search.filteredSearchResultCueIDs == results.enumerated().compactMap {
        $0.offset.isMultiple(of: 2) ? $0.element.entryID : nil
    })
    #expect(search.filteredSearchResultTotalCount == 60)
    #expect(search.filteredSearchFacetDistribution?.durationCounts == [
        .underOneSecond: 60,
        .fiveSecondsOrMore: 60,
    ])
    #expect(search.filteredSearchFacetDistribution?.characterCounts == [
        .oneToTen: 60,
    ])
    #expect(search.filteredSearchFacetDistribution?.languageCounts == [
        .english: 60,
    ])
    #expect(search.filteredSearchFacetDistribution?.watchStateCounts == [
        .unwatched: 60,
    ])
    #expect(search.searchResultCueIDs == results.map(\.entryID))
    #expect(search.searchResultTotalCount == 120)
    #expect(search.tableRowStore.snapshot.totalRowCount == 60)
}

@MainActor
@Test
func clearingLastFacetSelectionRestoresAllRows() {
    let search = SearchStore()
    search.updateQuery("query")
    let generation = search.prepareSearch(
        appending: false,
        filterSet: SubtitleSearchFilterSet()
    )
    let result = makeTableSandboxSearchResult(
        id: 1,
        content: "result",
        searchRank: 0
    )
    let snapshot = CueFacetSnapshot(
        cueIDs: [result.entryID],
        durationFacets: [.underOneSecond],
        characterFacets: [.oneToTen],
        languageFacets: [[.english]],
        watchStateFacets: [.unwatched]
    )
    let page = SubtitleSearchPage(
        results: [result],
        cueIDs: snapshot.cueIDs,
        totalCount: 1,
        fileSummaries: [],
        facetSnapshot: snapshot
    )
    #expect(search.commitExactSearchPage(page, generation: generation))

    search.updateSearchFacetFilter(CueFacetFilter(languages: [.japanese]))

    #expect(search.filteredSearchResultCueIDs.isEmpty)
    #expect(search.filteredSearchResultTotalCount == 0)
    #expect(search.tableRowStore.snapshot.totalRowCount == 0)

    search.updateSearchFacetFilter(CueFacetFilter(languages: []))

    #expect(search.filteredSearchResultCueIDs == [result.entryID])
    #expect(search.filteredSearchResultTotalCount == 1)
    #expect(search.searchResultCueIDs == [result.entryID])
    #expect(search.tableRowStore.snapshot.totalRowCount == 1)
}

@MainActor
@Test
func searchFacetWatchDistributionRefreshesAfterLibraryHistoryPublication() async throws {
    let suiteName = "CueSeekerWatchStateSearchRefreshTests-\(UUID().uuidString)"
    let userDefaults = try #require(UserDefaults(suiteName: suiteName))
    let fixtureRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "CueSeekerWatchStateSearchRefreshTests-\(UUID().uuidString)",
            isDirectory: true
        )
    let databaseURL = fixtureRoot.appendingPathComponent("CueSeeker.sqlite")
    try FileManager.default.createDirectory(
        at: fixtureRoot,
        withIntermediateDirectories: true
    )

    _ = NSApplication.shared
    let app = AppCoordinator(userDefaults: userDefaults, databaseURL: databaseURL)
    defer {
        app.search.searchTask?.cancel()
        app.search.exactCompletionTask?.cancel()
        userDefaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: fixtureRoot)
    }

    let database = try #require(app.indexingDatabase)
    let videoURL = fixtureRoot.appendingPathComponent("Episode.mkv")
    try database.replaceEntries(
        subtitleFile: fixtureRoot.appendingPathComponent("Episode.srt"),
        videoFile: videoURL,
        entries: [
            SubtitleEntry(
                sequenceNumber: 1,
                startTimecode: "00:00:01,000",
                endTimecode: "00:00:02,000",
                startMilliseconds: 1_000,
                endMilliseconds: 2_000,
                text: "shared watch state query"
            )
        ]
    )
    let libraryDatabase = try #require(app.libraryDatabase)
    try libraryDatabase.refreshPresentationAfterIndexedContentChange()
    let presentation = try #require(
        try libraryDatabase.libraryPresentation(under: [fixtureRoot])
            .first?.videos.first
    )
    let video = presentation.libraryVideo
    app.indexing.selectedFolders = [fixtureRoot]

    app.updateSearchQuery("shared watch state")
    await app.search.searchTask?.value
    await app.search.exactCompletionTask?.value
    #expect(app.search.searchResults.count == 1)
    #expect(app.search.searchFacetSnapshot?.distribution.watchStateCounts[.unwatched] == 1)

    app.recordRecentLibraryWatching(for: video, refreshPresentation: false)
    app.flushPendingLibraryPlaybackHistoryPresentations()
    await app.search.searchTask?.value
    await app.search.exactCompletionTask?.value

    #expect(app.search.searchResults.count == 1)
    #expect(app.search.searchResults.first?.videoPath == videoURL.path)
    #expect(app.search.searchFacetSnapshot?.distribution.watchStateCounts[.watching] == 1)
}

@MainActor
@Test
func staleExactProgressCannotPublishIntoRepeatedQueryText() throws {
    let suiteName = "CueSeekerRepeatedLiveSearchGenerationTests-\(UUID().uuidString)"
    let userDefaults = try #require(UserDefaults(suiteName: suiteName))
    let fixtureRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerRepeatedLiveSearchGenerationTests-\(UUID().uuidString)", isDirectory: true)
    let databaseURL = fixtureRoot.appendingPathComponent("CueSeeker.sqlite")
    defer {
        userDefaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: fixtureRoot)
    }
    try FileManager.default.createDirectory(
        at: fixtureRoot,
        withIntermediateDirectories: true
    )

    _ = NSApplication.shared
    let app = AppCoordinator(userDefaults: userDefaults, databaseURL: databaseURL)
    let currentResult = makeTableSandboxSearchResult(
        id: 42,
        content: "current foo result",
        searchRank: 0
    )
    let staleResult = makeTableSandboxSearchResult(
        id: 7,
        content: "stale first foo result",
        searchRank: 0
    )
    app.indexing.selectedFolders = [fixtureRoot]
    for _ in 0..<3 {
        app.search.advanceResultListGeneration()
    }
    app.search.updateQuery("foo")
    app.search.replaceResultState(
        results: [currentResult],
        orderedCueIDs: [currentResult.entryID],
        status: .searching,
        totalCount: 1,
        fileSummaries: [],
        countState: .exactProgress,
        knownResultCount: 1,
        knownFileCount: 1,
        hasMore: false
    )

    app.search.applyCountProgress(
        SubtitleSearchProgressSnapshot(
            countSnapshot: .exactProgress(
                knownResultCount: 2,
                knownFileCount: 1
            ),
            fileSummaries: [],
            results: [staleResult],
            cueIDs: [staleResult.entryID]
        ),
        query: "foo",
        filterSignature: app.search.activeFilterSetSignature,
        generation: 1,
        folders: app.indexing.selectedFolders,
        folderScopeGeneration: app.search.folderScopeGeneration,
        run: nil,
        isContextCurrent: { true },
        onResultsChanged: { _ in }
    )

    #expect(app.search.searchResults == [currentResult])
    #expect(app.search.searchResultCueIDs == [currentResult.entryID])
    #expect(app.search.searchResultTotalCount == 1)
    #expect(app.search.searchKnownResultCount == 1)
}

@MainActor
@Test
func allCuePageUpdatesSearchNavigationState() throws {
    let suiteName = "CueSeekerTableSandboxSearchContextTests-\(UUID().uuidString)"
    let userDefaults = try #require(UserDefaults(suiteName: suiteName))
    let databaseURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerTableSandboxSearchContextTests-\(UUID().uuidString).sqlite")
    defer {
        userDefaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: databaseURL)
        try? FileManager.default.removeItem(atPath: databaseURL.path + "-wal")
        try? FileManager.default.removeItem(atPath: databaseURL.path + "-shm")
    }

    _ = NSApplication.shared
    let app = AppCoordinator(userDefaults: userDefaults, databaseURL: databaseURL)
    let result = makeTableSandboxSearchResult(
        id: 42,
        content: "hydrated cue",
        searchRank: 10
    )
    let page = TableSandboxSearchHydrationPage(
        range: 10..<11,
        results: [result],
        totalRowCount: 42
    )

    app.search.applyAllCueSearchPage(page)

    #expect(app.search.searchStatus == .completed)
    #expect(app.search.searchResults == [result])
    #expect(app.search.searchResultTotalCount == 42)
    #expect(app.search.searchKnownResultCount == 42)
    #expect(app.search.hasMoreSearchResults)
    #expect(app.search.nextGlobalCursor?.offset == 11)
}

@MainActor
@Test
func searchCountProgressPublishesRenderableRowsAsCurrentResultRange() throws {
    let suiteName = "CueSeekerSearchCountProgressRowsTests-\(UUID().uuidString)"
    let userDefaults = try #require(UserDefaults(suiteName: suiteName))
    let fixtureRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerSearchCountProgressRowsTests-\(UUID().uuidString)", isDirectory: true)
    let databaseURL = fixtureRoot
        .appendingPathComponent("CueSeekerSearchCountProgressRowsTests.sqlite")
    defer {
        userDefaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: fixtureRoot)
    }

    try FileManager.default.createDirectory(
        at: fixtureRoot,
        withIntermediateDirectories: true
    )

    _ = NSApplication.shared
    let app = AppCoordinator(userDefaults: userDefaults, databaseURL: databaseURL)
    let existingResult = makeTableSandboxSearchResult(
        id: 41,
        content: "Existing visible result",
        searchRank: 0
    )
    let progressResults = (0..<3).map { index in
        makeTableSandboxSearchResult(
            id: Int64(100 + index),
            content: "Renderable progress result \(index)",
            searchRank: index
        )
    }
    let progressSummary = SubtitleSearchFileSummary(
        subtitlePath: "/Media/Episode.srt",
        subtitleFileName: "Episode.srt",
        subtitleDisplayTitle: "Episode",
        matchCount: progressResults.count
    )

    app.indexing.selectedFolders = [fixtureRoot]
    app.search.updateQuery("shared")
    app.search.replaceResultState(
        results: [existingResult],
        orderedCueIDs: [existingResult.entryID],
        status: .searching,
        totalCount: 100,
        fileSummaries: [],
        countState: .exactProgress,
        knownResultCount: 1,
        knownFileCount: 0,
        hasMore: true,
        loadedResultCount: 1,
        nextCursor: SubtitleSearchCursor(offset: 1)
    )

    app.search.commitSearchCountProgress(
        SubtitleSearchProgressSnapshot(
            countSnapshot: .exactProgress(
                knownResultCount: progressResults.count,
                knownFileCount: 1
            ),
            fileSummaries: [progressSummary],
            results: progressResults,
            cueIDs: progressResults.map(\.entryID)
        )
    )

    #expect(app.search.searchResults == progressResults)
    #expect(app.search.searchResultCueIDs == progressResults.map(\.entryID))
    #expect(app.search.searchResultTotalCount == progressResults.count)
    #expect(app.search.searchKnownResultCount == progressResults.count)
    #expect(app.search.loadedGlobalResultCount == progressResults.count)
    #expect(!app.search.hasMoreSearchResults)
    #expect(app.search.nextGlobalCursor == nil)
}

@Test
func workbenchSearchTextCopyBoundaryRequiresExactCountAndCompleteCueIDs() {
    let completeCueIDs: [Int64] = [11, 12, 13]

    #expect(workbenchSearchHasCompleteTextCopyBoundary(
        searchStatus: .completed,
        countState: .exact,
        cueIDs: completeCueIDs,
        resultRowCount: completeCueIDs.count
    ))
    #expect(workbenchSearchHasCompleteTextCopyBoundary(
        searchStatus: .completed,
        countState: .exact,
        cueIDs: [],
        resultRowCount: 0
    ))
    #expect(!workbenchSearchHasCompleteTextCopyBoundary(
        searchStatus: .searching,
        countState: .exact,
        cueIDs: [],
        resultRowCount: 0
    ))
    #expect(!workbenchSearchHasCompleteTextCopyBoundary(
        searchStatus: .completed,
        countState: .exactProgress,
        cueIDs: completeCueIDs,
        resultRowCount: completeCueIDs.count
    ))
    #expect(!workbenchSearchHasCompleteTextCopyBoundary(
        searchStatus: .completed,
        countState: .exact,
        cueIDs: Array(completeCueIDs.dropLast()),
        resultRowCount: completeCueIDs.count
    ))
    #expect(!workbenchSearchHasCompleteTextCopyBoundary(
        searchStatus: .completed,
        countState: .exact,
        cueIDs: completeCueIDs,
        resultRowCount: completeCueIDs.count - 1
    ))
    #expect(!workbenchSearchHasCompleteTextCopyBoundary(
        searchStatus: .completed,
        countState: .exact,
        cueIDs: [],
        resultRowCount: -1
    ))
}

@MainActor
@Test
func tableSandboxSearchRowsUseCurrentCueIDsForDistantRanges() async throws {
    let suiteName = "CueSeekerTableSandboxSearchIDTests-\(UUID().uuidString)"
    let userDefaults = try #require(UserDefaults(suiteName: suiteName))
    let fixtureRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerTableSandboxSearchIDTests-\(UUID().uuidString)", isDirectory: true)
    let databaseURL = fixtureRoot
        .appendingPathComponent("CueSeekerTableSandboxSearchIDTests.sqlite")
    defer {
        userDefaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: fixtureRoot)
    }

    try FileManager.default.createDirectory(
        at: fixtureRoot,
        withIntermediateDirectories: true
    )

    _ = NSApplication.shared
    let app = AppCoordinator(userDefaults: userDefaults, databaseURL: databaseURL)
    let database = try #require(app.indexingDatabase)
    let subtitleFile = fixtureRoot.appendingPathComponent("Episode.srt")
    let videoFile = fixtureRoot.appendingPathComponent("Episode.mkv")
    try database.replaceEntries(
        subtitleFile: subtitleFile,
        videoFile: videoFile,
        entries: (0..<120).map { index in
            SubtitleEntry(
                sequenceNumber: index + 1,
                startTimecode: String(format: "00:%02d:%02d,000", index / 60, index % 60),
                endTimecode: String(format: "00:%02d:%02d,500", index / 60, index % 60),
                startMilliseconds: index * 1_000,
                endMilliseconds: index * 1_000 + 500,
                text: "Shared distant row \(index)"
            )
        }
    )

    app.indexing.selectedFolders = [fixtureRoot]
    app.search.updateQuery("shared")
    app.search.replaceResultState(
        results: [],
        status: .completed,
        totalCount: 120,
        fileSummaries: [],
        countState: .exact,
        knownResultCount: 120,
        knownFileCount: 0,
        hasMore: true
    )

    let missingIDPage = await app.search.loadSearchRows(
        range: 110..<112,
        folders: app.indexing.selectedFolders,
        languageFilter: .all,
        watchStateFilter: .all
    )
    #expect(missingIDPage == nil)

    let exactPage = try #require(app.search.database).searchPage(
        "shared",
        limit: 0,
        under: [fixtureRoot]
    )
    app.search.replaceResultState(
        results: [],
        orderedCueIDs: exactPage.cueIDs,
        status: .completed,
        totalCount: exactPage.totalCount,
        fileSummaries: exactPage.fileSummaries,
        countState: exactPage.countState,
        knownResultCount: exactPage.totalCount,
        knownFileCount: exactPage.fileSummaries.count,
        hasMore: false
    )

    let page = try #require(await app.search.loadSearchRows(
        range: 110..<112,
        folders: app.indexing.selectedFolders,
        languageFilter: .all,
        watchStateFilter: .all
    ))

    #expect(page.range == 110..<112)
    #expect(page.totalRowCount == 120)
    #expect(page.results.map(\.content) == [
        "Shared distant row 110",
        "Shared distant row 111"
    ])
    #expect(page.results.map(\.searchRank) == [110, 111])
}

@MainActor
@Test
func emptyQuerySearchNavigationSnapshotLoadsAllCueWindowForPlayback() async throws {
    let suiteName = "CueSeekerAllCueSearchNavigationTests-\(UUID().uuidString)"
    let userDefaults = try #require(UserDefaults(suiteName: suiteName))
    let fixtureRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerAllCueSearchNavigationTests-\(UUID().uuidString)", isDirectory: true)
    let databaseURL = fixtureRoot
        .appendingPathComponent("CueSeekerAllCueSearchNavigationTests.sqlite")
    defer {
        userDefaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: fixtureRoot)
    }

    try FileManager.default.createDirectory(
        at: fixtureRoot,
        withIntermediateDirectories: true
    )

    _ = NSApplication.shared
    let app = AppCoordinator(userDefaults: userDefaults, databaseURL: databaseURL)
    let database = try #require(app.indexingDatabase)
    let subtitleFile = fixtureRoot.appendingPathComponent("Episode.srt")
    let videoFile = fixtureRoot.appendingPathComponent("Episode.mkv")
    try database.replaceEntries(
        subtitleFile: subtitleFile,
        videoFile: videoFile,
        entries: [
            SubtitleEntry(
                sequenceNumber: 1,
                startTimecode: "00:00:01,000",
                endTimecode: "00:00:02,000",
                startMilliseconds: 1_000,
                endMilliseconds: 2_000,
                text: "before selected"
            ),
            SubtitleEntry(
                sequenceNumber: 2,
                startTimecode: "00:00:03,000",
                endTimecode: "00:00:04,000",
                startMilliseconds: 3_000,
                endMilliseconds: 4_000,
                text: "selected result"
            ),
            SubtitleEntry(
                sequenceNumber: 3,
                startTimecode: "00:00:05,000",
                endTimecode: "00:00:06,000",
                startMilliseconds: 5_000,
                endMilliseconds: 6_000,
                text: "after selected"
            )
        ]
    )
    app.indexing.selectedFolders = [fixtureRoot]
    let page = try #require(app.search.database).allCuesVisiblePage(
        limit: 3,
        cursor: .start,
        under: [fixtureRoot]
    )
    let selected = try #require(page.results.first { $0.content == "selected result" })
    app.search.applyAllCueSearchPage(
        TableSandboxSearchHydrationPage(
            range: 0..<page.results.count,
            results: page.results,
            totalRowCount: page.totalCount
        )
    )
    app.search.selectResult(selected)

    app.refreshSearchNavigationSnapshot()
    await app.search.navigationTask?.value

    let snapshot = try #require(app.search.searchNavigationSnapshot)
    #expect(snapshot.totalCount == 3)
    #expect(snapshot.current?.entryID == selected.entryID)
    #expect(snapshot.previous?.content == "before selected")
    #expect(snapshot.next?.content == "after selected")
}

@MainActor
@Test
func openingSearchResultUpdatesNavigationStateImmediately() throws {
    let suiteName = "CueSeekerSearchPlaybackNavigationStateTests-\(UUID().uuidString)"
    let userDefaults = try #require(UserDefaults(suiteName: suiteName))
    let databaseURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerSearchPlaybackNavigationStateTests-\(UUID().uuidString).sqlite")
    defer {
        userDefaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: databaseURL)
        try? FileManager.default.removeItem(atPath: databaseURL.path + "-wal")
        try? FileManager.default.removeItem(atPath: databaseURL.path + "-shm")
    }

    _ = NSApplication.shared
    let app = AppCoordinator(userDefaults: userDefaults, databaseURL: databaseURL)
    let first = makeTableSandboxSearchResult(
        id: 1,
        content: "first result",
        searchRank: 0
    )
    let second = makeTableSandboxSearchResult(
        id: 2,
        content: "second result",
        searchRank: 1
    )
    let third = makeTableSandboxSearchResult(
        id: 3,
        content: "third result",
        searchRank: 2
    )
    app.search.replaceResultState(
        results: [first, second, third],
        status: .completed,
        totalCount: 3,
        fileSummaries: [],
        countState: .exact,
        knownResultCount: 3,
        knownFileCount: 0,
        hasMore: false
    )

    app.openSearchResult(first)

    #expect(!app.canOpenPreviousSearchResult)
    #expect(app.canOpenNextSearchResult)
    #expect(app.search.searchNavigationSnapshot?.previous == nil)
    #expect(app.search.searchNavigationSnapshot?.current?.entryID == first.entryID)
    #expect(app.search.searchNavigationSnapshot?.next?.entryID == second.entryID)

    app.openSearchResult(second)

    #expect(app.canOpenPreviousSearchResult)
    #expect(app.canOpenNextSearchResult)
    #expect(app.search.searchNavigationSnapshot?.previous?.entryID == first.entryID)
    #expect(app.search.searchNavigationSnapshot?.current?.entryID == second.entryID)
    #expect(app.search.searchNavigationSnapshot?.next?.entryID == third.entryID)
}

@MainActor
@Test
func searchTableProjectionSurvivesViewRemountWithoutMaterializingResults() {
    let cueStore = CueContentStore()
    let search = SearchStore(cueContentStore: cueStore)
    let results = (1...10_000).map { value in
        makeTableSandboxSearchResult(
            id: Int64(value),
            content: "Search Cue \(value)",
            searchRank: value - 1
        )
    }
    search.replaceResidentResults(results)
    let rowStore = search.tableRowStore

    search.activateResidentSearchTableProjection()
    let mountedVersion = rowStore.snapshot.version

    search.activateResidentSearchTableProjection()

    #expect(search.tableRowStore === rowStore)
    #expect(rowStore.snapshot.version == mountedVersion)
    #expect(rowStore.snapshot.totalRowCount == 10_000)
    #expect(rowStore.snapshot.loadedReferenceCount == 10_000)
    #expect(rowStore.snapshot.materializedRowCount == 0)
    #expect(rowStore.snapshot.row(at: 9_999)?.primaryCueText == "Search Cue 10000")
}

@MainActor
@Test
func indexedCueMutationInvalidatesUnownedProjectionAndAdvancesRevision() {
    let search = SearchStore()
    search.tableRowStore.updateResidentSearchResults(
        [makeTableSandboxSearchResult(
            id: 42,
            content: "Stale indexed Cue",
            searchRank: 0
        )],
        cueContentProvider: { _ in nil },
        tableName: "test-search"
    )
    let mutation = search.beginIndexedCueDataMutation()

    #expect(search.tableProjectionSource == nil)
    #expect(search.tableRowStore.snapshot.totalRowCount == 0)
    #expect(search.indexedCueDataRevision == 0)
    #expect(search.completeIndexedCueDataMutation(mutation))
    #expect(!search.completeIndexedCueDataMutation(mutation))
    #expect(search.indexedCueDataRevision == 1)

    let supersededMutation = search.beginIndexedCueDataMutation()
    let currentMutation = search.beginIndexedCueDataMutation()
    #expect(!search.completeIndexedCueDataMutation(supersededMutation))
    #expect(search.completeIndexedCueDataMutation(currentMutation))
    #expect(search.indexedCueDataRevision == 2)
}

@MainActor
@Test
func indexedCueMutationPreservesResidentSearchProjection() {
    let search = SearchStore()
    let result = makeTableSandboxSearchResult(
        id: 42,
        content: "Resident Search Cue",
        searchRank: 0
    )
    search.replaceResidentResults([result])
    search.activateResidentSearchTableProjection()
    let originalSource = search.tableProjectionSource
    let originalVersion = search.tableRowStore.snapshot.version

    let mutation = search.beginIndexedCueDataMutation()

    #expect(search.tableProjectionSource == originalSource)
    #expect(search.tableRowStore.snapshot.version == originalVersion)
    #expect(search.tableRowStore.snapshot.orderedEntryIDs == [42])
    #expect(search.tableRowStore.snapshot.row(at: 0)?.primaryCueText == "Resident Search Cue")
    #expect(search.completeIndexedCueDataMutation(mutation))
    #expect(search.tableProjectionSource == originalSource)
    #expect(search.tableRowStore.snapshot.version == originalVersion)
}

@MainActor
@Test
func residentSearchProjectionRevisionDirectlyUpdatesOwnedRowStore() {
    let search = SearchStore()
    let original = makeTableSandboxSearchResult(
        id: 42,
        content: "Stable Cue",
        searchRank: 0
    )
    search.replaceResidentResults([original])
    search.activateResidentSearchTableProjection()
    let originalSnapshotVersion = search.tableRowStore.snapshot.version

    search.replaceResidentResults([
        SubtitleSearchResult(cueContent: original.cueContent, searchRank: 7),
    ])

    #expect(search.tableRowStore.snapshot.version == originalSnapshotVersion + 1)
    #expect(search.tableRowStore.snapshot.searchResult(entryID: 42)?.searchRank == 7)
}

private func makeSearchResults() throws -> [SubtitleSearchResult] {
    let databaseURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerSearchStoreTests-\(UUID().uuidString).sqlite")
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    try DatabaseBootstrap.prepare(at: databaseURL)
    let database = try IndexingDatabase(path: databaseURL)
    try database.replaceEntries(
        subtitleFile: URL(fileURLWithPath: "/Media/Episode.srt"),
        videoFile: URL(fileURLWithPath: "/Media/Episode.mkv"),
        entries: [
            SubtitleEntry(
                sequenceNumber: 1,
                startTimecode: "00:00:01,000",
                endTimecode: "00:00:01,500",
                startMilliseconds: 1_000,
                endMilliseconds: 1_500,
                text: "今日 first"
            ),
            SubtitleEntry(
                sequenceNumber: 2,
                startTimecode: "00:00:03,000",
                endTimecode: "00:00:03,500",
                startMilliseconds: 3_000,
                endMilliseconds: 3_500,
                text: "今日 second"
            )
        ]
    )
    try database.replaceEntries(
        subtitleFile: URL(fileURLWithPath: "/Media/Other.srt"),
        videoFile: URL(fileURLWithPath: "/Media/Other.mkv"),
        entries: [
            SubtitleEntry(
                sequenceNumber: 1,
                startTimecode: "00:00:02,000",
                endTimecode: "00:00:02,500",
                startMilliseconds: 2_000,
                endMilliseconds: 2_500,
                text: "今日 other"
            )
        ]
    )
    return try SearchDatabase(path: databaseURL).searchPage("今日", limit: 10).results
}

private func makeTableSandboxSearchResult(
    id: Int64,
    content: String,
    searchRank: Int
) -> SubtitleSearchResult {
    SubtitleSearchResult(
        entryID: id,
        subtitlePath: "/Media/Episode.srt",
        subtitleFormat: .srt,
        videoPath: "/Media/Episode.mkv",
        videoName: "Episode.mkv",
        startMilliseconds: 1_000,
        endMilliseconds: 2_000,
        content: content,
        cueLines: [content],
        searchRank: searchRank
    )
}
