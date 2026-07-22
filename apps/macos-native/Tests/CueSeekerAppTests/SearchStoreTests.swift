import Foundation
import AppKit
import Testing
@testable import CueSeekerCore
@testable import CueSeekerApp

@MainActor
@Test
func searchInputDebounceIsOneHundredMilliseconds() {
    #expect(AppCoordinator.searchInputDebounceNanoseconds == 100_000_000)
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
        app.searchTask?.cancel()
        app.searchExactCompletionTask?.cancel()
        userDefaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: fixtureRoot)
    }

    let database = try #require(app.subtitleDatabase)
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
    let alphaTask = try #require(app.searchTask)
    let staleExactTask = Task<Void, Never> {
        try? await Task.sleep(nanoseconds: 10_000_000_000)
    }
    app.searchExactCompletionTask = staleExactTask

    app.updateSearchQuery("beta")
    let betaTask = try #require(app.searchTask)

    #expect(alphaTask.isCancelled)
    #expect(staleExactTask.isCancelled)
    #expect(app.search.searchQuery == "beta")
    #expect(app.activeSearchPerformanceRun?.query == "beta")
    #expect(app.activeSearchPerformanceRun?.debounce == true)

    await betaTask.value

    #expect(!app.search.searchResults.isEmpty)
    #expect(app.search.searchResults.allSatisfy { $0.content.contains("beta") })
    #expect(app.search.searchResults.allSatisfy { !$0.content.contains("alpha") })

    app.updateSearchQuery("alpha")
    let pendingAlphaTask = try #require(app.searchTask)
    app.search.searchResults = [
        makeTableSandboxSearchResult(
            id: 999,
            content: "stale pending row",
            speakers: [],
            searchRank: 0
        )
    ]
    app.search.searchResultCueIDs = [999]
    app.search.searchResultTotalCount = 1
    app.search.hasMoreSearchResults = true

    app.updateSearchQuery("")

    #expect(pendingAlphaTask.isCancelled)
    #expect(app.search.searchQuery.isEmpty)
    #expect(app.search.searchStatus == .idle)
    #expect(app.search.searchResults.isEmpty)
    #expect(app.search.searchResultCueIDs.isEmpty)
    #expect(app.search.searchResultTotalCount == 0)
    #expect(app.search.searchResultGroups.isEmpty)
    #expect(app.search.searchNavigationSnapshot == nil)
    #expect(!app.search.hasMoreSearchResults)
}

@MainActor
@Test
func watchStateScopedSearchRefreshesAfterLibraryHistoryPublication() async throws {
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
        app.searchTask?.cancel()
        app.searchExactCompletionTask?.cancel()
        userDefaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: fixtureRoot)
    }

    let database = try #require(app.subtitleDatabase)
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
    try database.rebuildLibraryPresentationSnapshot()
    let presentation = try #require(
        try database.libraryPresentation(under: [fixtureRoot])
            .first?.videos.first
    )
    let video = presentation.libraryVideo
    app.indexing.selectedFolders = [fixtureRoot]
    app.settings.searchScope = .watchingAndFinished

    app.updateSearchQuery("shared watch state")
    await app.searchTask?.value
    #expect(app.search.searchResults.isEmpty)

    app.recordRecentLibraryWatching(for: video, refreshPresentation: false)
    app.flushPendingLibraryPlaybackHistoryPresentations()
    await app.searchTask?.value

    #expect(app.search.searchResults.count == 1)
    #expect(app.search.searchResults.first?.videoPath == videoURL.path)
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
        speakers: [],
        searchRank: 0
    )
    let staleResult = makeTableSandboxSearchResult(
        id: 7,
        content: "stale first foo result",
        speakers: [],
        searchRank: 0
    )
    app.indexing.selectedFolders = [fixtureRoot]
    app.searchResultListGeneration = 3
    app.search.searchQuery = "foo"
    app.search.searchStatus = .searching
    app.search.searchResults = [currentResult]
    app.search.searchResultCueIDs = [currentResult.entryID]
    app.search.searchResultTotalCount = 1
    app.search.searchCountState = .exactProgress
    app.search.searchKnownResultCount = 1
    app.search.searchKnownFileCount = 1

    app.applySearchCountProgress(
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
        folderPaths: [fixtureRoot.path],
        languageFilter: app.settings.primarySearchLanguage.searchLanguageFilter,
        watchStateFilter: app.settings.searchScope.searchWatchStateFilter,
        filterSignature: app.search.activeFilterSetSignature,
        resultListGeneration: 1,
        run: nil
    )

    #expect(app.search.searchResults == [currentResult])
    #expect(app.search.searchResultCueIDs == [currentResult.entryID])
    #expect(app.search.searchResultTotalCount == 1)
    #expect(app.search.searchKnownResultCount == 1)
}

@MainActor
@Test
func tableSandboxAllCueContextFeedsAllCueSearchContext() throws {
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
        content: "Speaker filtered cue",
        speakers: ["高松灯"],
        searchRank: 10
    )
    let page = TableSandboxSearchHydrationPage(
        range: 10..<11,
        results: [result],
        totalRowCount: 42
    )

    app.applyTableSandboxAllCueSearchContext(page)

    #expect(app.search.searchStatus == .completed)
    #expect(app.search.searchResults == [result])
    #expect(app.search.searchResultTotalCount == 42)
    #expect(app.search.searchKnownResultCount == 42)
    #expect(app.search.hasMoreSearchResults)
    #expect(app.nextGlobalSearchCursor?.offset == 11)
}

@MainActor
@Test
func contextEntryPointsPreserveExactCueIdentity() throws {
    let suiteName = "CueSeekerCueContextEntryPointTests-\(UUID().uuidString)"
    let userDefaults = try #require(UserDefaults(suiteName: suiteName))
    let fixtureRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerCueContextEntryPointTests-\(UUID().uuidString)", isDirectory: true)
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
    let database = try #require(app.subtitleDatabase)
    let seedSubtitleFile = fixtureRoot.appendingPathComponent("Seed.ass")
    let seedVideoFile = fixtureRoot.appendingPathComponent("Seed.mkv")
    let seedGroup = SubtitleCueGroup(
        sequenceNumber: nil,
        startTimecode: "0:00:01.00",
        endTimecode: "0:00:02.00",
        startMilliseconds: 1_000,
        endMilliseconds: 2_000,
        searchContent: "seed upper\nseed lower",
        cueLines: [
            SubtitleCueLine(
                eventIndex: 0,
                sourceFormat: .ass,
                sourceStyle: "Top",
                sourceLayer: 0,
                startTimecode: "0:00:01.00",
                endTimecode: "0:00:02.00",
                startMilliseconds: 1_000,
                endMilliseconds: 2_000,
                content: "seed upper",
                displayX: nil,
                displayY: 100,
                displayOrder: 0
            ),
            SubtitleCueLine(
                eventIndex: 1,
                sourceFormat: .ass,
                sourceStyle: "Bottom",
                sourceLayer: 0,
                startTimecode: "0:00:01.00",
                endTimecode: "0:00:02.00",
                startMilliseconds: 1_000,
                endMilliseconds: 2_000,
                content: "seed lower",
                displayX: nil,
                displayY: 900,
                displayOrder: 1
            ),
        ]
    )
    try database.replaceCueGroups(
        subtitleFile: seedSubtitleFile,
        videoFile: seedVideoFile,
        format: .ass,
        cueGroups: [seedGroup]
    )
    let subtitleFile = fixtureRoot.appendingPathComponent("Episode.ass")
    let videoFile = fixtureRoot.appendingPathComponent("Episode.mkv")
    let cueGroup = SubtitleCueGroup(
        sequenceNumber: nil,
        startTimecode: "0:00:01.00",
        endTimecode: "0:00:03.00",
        startMilliseconds: 1_000,
        endMilliseconds: 3_000,
        searchContent: "upper cue\nlower cue",
        cueLines: [
            SubtitleCueLine(
                eventIndex: 10,
                sourceFormat: .ass,
                sourceStyle: "Top",
                sourceLayer: 0,
                startTimecode: "0:00:01.00",
                endTimecode: "0:00:03.00",
                startMilliseconds: 1_000,
                endMilliseconds: 3_000,
                content: "upper cue",
                displayX: nil,
                displayY: 100,
                displayOrder: 0
            ),
            SubtitleCueLine(
                eventIndex: 11,
                sourceFormat: .ass,
                sourceStyle: "Bottom",
                sourceLayer: 0,
                startTimecode: "0:00:01.00",
                endTimecode: "0:00:03.00",
                startMilliseconds: 1_000,
                endMilliseconds: 3_000,
                content: "lower cue",
                displayX: nil,
                displayY: 900,
                displayOrder: 1
            ),
        ]
    )
    try database.replaceCueGroups(
        subtitleFile: subtitleFile,
        videoFile: videoFile,
        format: .ass,
        cueGroups: [cueGroup]
    )
    app.indexing.selectedFolders = [fixtureRoot]

    let cues = try database.cueLineRecords(forSubtitleFile: subtitleFile)
    let upperCue = try #require(cues.first { $0.line.eventIndex == 10 })
    let lowerCue = try #require(cues.first { $0.line.eventIndex == 11 })
    #expect(upperCue.cueGroupID == lowerCue.cueGroupID)
    #expect(upperCue.id != upperCue.cueGroupID)
    #expect(lowerCue.id != lowerCue.cueGroupID)
    #expect(try database.firstCueID(forSubtitleFile: subtitleFile) == upperCue.id)
    #expect(try database.firstCueGroupID(forSubtitleFile: subtitleFile) == upperCue.cueGroupID)

    let allCuePage = try database.allCuesVisiblePage(
        limit: 10,
        cursor: .start,
        under: [fixtureRoot]
    )
    let lowerResult = try #require(allCuePage.results.first { $0.entryID == lowerCue.id })
    app.openSearchResultContext(lowerResult)
    #expect(app.search.cueContextSearchRequest?.targetCueID == lowerCue.id)

    let selection = try #require(try PlaybackSubtitleDatabase(path: database.path).cueTextSelection(
        forSubtitleFile: subtitleFile,
        atMilliseconds: 1_500
    ))
    let shiori = try ShioriDatabase(path: database.path).upsertShiori(
        selection: selection
    )
    app.openShioriContext(shiori, displayTitle: "Episode")
    #expect(app.search.cueContextSearchRequest?.targetCueID == lowerCue.id)

    let libraryDatabase = try #require(app.libraryDatabase)
    let libraryVideo = try #require(try libraryDatabase.libraryVideos(under: [fixtureRoot]).first {
        $0.subtitlePath == subtitleFile.path
    })
    app.openLibraryVideoContext(libraryVideo, displayTitle: "Episode")
    #expect(app.search.cueContextSearchRequest?.targetCueID == upperCue.id)
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
        speakers: [],
        searchRank: 0
    )
    let progressResults = (0..<3).map { index in
        makeTableSandboxSearchResult(
            id: Int64(100 + index),
            content: "Renderable progress result \(index)",
            speakers: [],
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
    app.search.searchQuery = "shared"
    app.search.searchStatus = .searching
    app.search.searchResults = [existingResult]
    app.search.searchResultCueIDs = [existingResult.entryID]
    app.search.searchResultTotalCount = 100
    app.search.searchCountState = .exactProgress
    app.search.searchKnownResultCount = 1
    app.search.hasMoreSearchResults = true
    app.loadedGlobalSearchResultCount = 1
    app.nextGlobalSearchCursor = SubtitleSearchCursor(offset: 1)

    app.applySearchCountProgress(
        SubtitleSearchProgressSnapshot(
            countSnapshot: .exactProgress(
                knownResultCount: progressResults.count,
                knownFileCount: 1
            ),
            fileSummaries: [progressSummary],
            results: progressResults,
            cueIDs: progressResults.map(\.entryID)
        ),
        query: "shared",
        folderPaths: [fixtureRoot.path],
        languageFilter: app.settings.primarySearchLanguage.searchLanguageFilter,
        watchStateFilter: app.settings.searchScope.searchWatchStateFilter,
        filterSignature: app.search.activeFilterSetSignature,
        run: nil
    )

    #expect(app.search.searchResults == progressResults)
    #expect(app.search.searchResultCueIDs == progressResults.map(\.entryID))
    #expect(app.search.searchResultTotalCount == progressResults.count)
    #expect(app.search.searchKnownResultCount == progressResults.count)
    #expect(app.loadedGlobalSearchResultCount == progressResults.count)
    #expect(!app.search.hasMoreSearchResults)
    #expect(app.nextGlobalSearchCursor == nil)
}

@Test
func workbenchSearchTextCopyBoundaryRequiresExactCountAndCompleteCueIDs() {
    let completeCueIDs: [Int64] = [11, 12, 13]

    #expect(workbenchSearchHasCompleteTextCopyBoundary(
        countState: .exact,
        cueIDs: completeCueIDs,
        resultRowCount: completeCueIDs.count
    ))
    #expect(workbenchSearchHasCompleteTextCopyBoundary(
        countState: .exact,
        cueIDs: [],
        resultRowCount: 0
    ))
    #expect(!workbenchSearchHasCompleteTextCopyBoundary(
        countState: .exactProgress,
        cueIDs: completeCueIDs,
        resultRowCount: completeCueIDs.count
    ))
    #expect(!workbenchSearchHasCompleteTextCopyBoundary(
        countState: .exact,
        cueIDs: Array(completeCueIDs.dropLast()),
        resultRowCount: completeCueIDs.count
    ))
    #expect(!workbenchSearchHasCompleteTextCopyBoundary(
        countState: .exact,
        cueIDs: completeCueIDs,
        resultRowCount: completeCueIDs.count - 1
    ))
    #expect(!workbenchSearchHasCompleteTextCopyBoundary(
        countState: .exact,
        cueIDs: [],
        resultRowCount: -1
    ))
}

@MainActor
@Test
func searchResultGroupsKeepSummaryOnlyRowsUntilGroupExpansion() {
    let path = "/Media/Episode.srt"
    let results = (0..<3).map { index in
        makeTableSandboxSearchResult(
            id: Int64(index + 1),
            content: "Grouped result \(index)",
            speakers: [],
            searchRank: index
        )
    }
    let summary = SubtitleSearchFileSummary(
        subtitlePath: path,
        subtitleFileName: "Episode.srt",
        subtitleDisplayTitle: "Episode",
        matchCount: results.count
    )

    let summaryOnlyGroups = AppCoordinator.makeSearchResultGroups(
        results: results,
        fileSummaries: [summary],
        expandedRowsByPath: [:],
        collapsedGroupPaths: [],
        includesSummaryOnlyGroups: false
    )

    #expect(summaryOnlyGroups.count == 1)
    #expect(summaryOnlyGroups[0].totalCount == 3)
    #expect(summaryOnlyGroups[0].results.isEmpty)

    let expandedGroups = AppCoordinator.makeSearchResultGroups(
        results: results,
        fileSummaries: [summary],
        expandedRowsByPath: [path: [results[1]]],
        collapsedGroupPaths: [],
        includesSummaryOnlyGroups: false
    )

    #expect(expandedGroups.count == 1)
    #expect(expandedGroups[0].results.map(\.entryID) == [2])
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
    let database = try #require(app.subtitleDatabase)
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
    app.search.searchQuery = "shared"
    app.search.searchResultTotalCount = 120

    let missingIDPage = await app.loadTableSandboxSearchRows(range: 110..<112)
    #expect(missingIDPage == nil)

    let exactPage = try database.searchPage(
        "shared",
        limit: 0,
        under: [fixtureRoot]
    )
    app.search.searchResultCueIDs = exactPage.cueIDs
    app.search.searchResultTotalCount = exactPage.totalCount
    app.search.searchFileSummaries = exactPage.fileSummaries
    app.search.searchCountState = exactPage.countState

    let page = try #require(await app.loadTableSandboxSearchRows(range: 110..<112))

    #expect(page.range == 110..<112)
    #expect(page.totalRowCount == 120)
    #expect(page.results.map(\.content) == [
        "Shared distant row 110",
        "Shared distant row 111"
    ])
    #expect(page.results.map(\.searchRank) == [110, 111])
}

@Test
func cueContextTargetSourceIndexUsesStableSearchRankNearTail() {
    let target = makeTableSandboxSearchResult(
        id: 1520171,
        content: "target cue",
        speakers: [],
        searchRank: 2717
    )
    let page = TableSandboxSearchHydrationPage(
        range: 2688..<2738,
        results: [
            makeTableSandboxSearchResult(
                id: 1520169,
                content: "preceding cue",
                speakers: [],
                searchRank: 2715
            ),
            target
        ],
        totalRowCount: 2738
    )

    #expect(resolvedCueContextTargetSourceIndex(in: page, targetCueID: target.entryID) == 2717)
}

@Test
func cueContextTargetSourceIndexFallsBackToLoadedRangeStartWhenTargetIsMissing() {
    let page = TableSandboxSearchHydrationPage(
        range: 2688..<2738,
        results: [
            makeTableSandboxSearchResult(
                id: 1520169,
                content: "preceding cue",
                speakers: [],
                searchRank: 2715
            )
        ],
        totalRowCount: 2738
    )

    #expect(resolvedCueContextTargetSourceIndex(in: page, targetCueID: 1520171) == 2688)
}

@Test
func cueContextDisplayRowTracksPrependedSourceRows() {
    let targetSourceIndex = 117

    #expect(
        cueContextDisplayRow(
            forSourceIndex: targetSourceIndex,
            loadedSourceRange: 117..<167,
            loadedRowCount: 50
        ) == 0
    )
    #expect(
        cueContextDisplayRow(
            forSourceIndex: targetSourceIndex,
            loadedSourceRange: 67..<167,
            loadedRowCount: 100
        ) == 50
    )
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
    let database = try #require(app.subtitleDatabase)
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
    let page = try database.allCuesVisiblePage(
        limit: 3,
        cursor: .start,
        under: [fixtureRoot]
    )
    let selected = try #require(page.results.first { $0.content == "selected result" })
    app.applyTableSandboxAllCueSearchContext(
        TableSandboxSearchHydrationPage(
            range: 0..<page.results.count,
            results: page.results,
            totalRowCount: page.totalCount
        )
    )
    app.search.selectedSearchResult = selected

    app.refreshSearchNavigationSnapshot()
    await app.searchNavigationTask?.value

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
        speakers: [],
        searchRank: 0
    )
    let second = makeTableSandboxSearchResult(
        id: 2,
        content: "second result",
        speakers: [],
        searchRank: 1
    )
    let third = makeTableSandboxSearchResult(
        id: 3,
        content: "third result",
        speakers: [],
        searchRank: 2
    )
    app.search.searchResults = [first, second, third]
    app.search.searchResultTotalCount = 3

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
            speakers: [],
            searchRank: value - 1
        )
    }
    search.replaceLoadedSearchResults(results)
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
func filterOnlyProjectionReusesCompleteSourceAndRejectsDuplicatePageLoads() throws {
    let search = SearchStore()
    let key = SearchFilterOnlyProjectionKey(
        filterSignature: "display:contains:episode",
        folderPaths: ["/Media"]
    )

    #expect(search.prepareFilterOnlyTableProjection(key: key))
    let firstToken = try #require(search.beginFilterOnlyPageLoad(
        key: key,
        loadedRowCount: 0
    ))
    #expect(search.beginFilterOnlyPageLoad(key: key, loadedRowCount: 0) == nil)
    #expect(!search.completeFilterOnlyPageLoad(
        firstToken,
        totalRowCount: 200,
        loadedRowCount: 200
    ))

    #expect(!search.prepareFilterOnlyTableProjection(key: key))
    #expect(search.beginFilterOnlyPageLoad(key: key, loadedRowCount: 200) == nil)
    #expect(search.tableProjectionSource == .filterOnly(key))
}

@MainActor
@Test
func filterOnlyProjectionResumesPartialSourceAndRejectsStaleResponse() throws {
    let search = SearchStore()
    let key = SearchFilterOnlyProjectionKey(
        filterSignature: "cues:contains:review",
        folderPaths: ["/Media"]
    )
    _ = search.prepareFilterOnlyTableProjection(key: key)
    let firstToken = try #require(search.beginFilterOnlyPageLoad(
        key: key,
        loadedRowCount: 0
    ))
    #expect(search.completeFilterOnlyPageLoad(
        firstToken,
        totalRowCount: 2_000,
        loadedRowCount: 200
    ))
    let pendingToken = try #require(search.beginFilterOnlyPageLoad(
        key: key,
        loadedRowCount: 200
    ))

    search.suspendFilterOnlyPageLoad()

    #expect(!search.acceptsFilterOnlyPageLoad(pendingToken))
    #expect(!search.prepareFilterOnlyTableProjection(key: key))
    let resumedToken = try #require(search.beginFilterOnlyPageLoad(
        key: key,
        loadedRowCount: 200
    ))
    #expect(resumedToken.startIndex == 200)
    #expect(resumedToken.generation != pendingToken.generation)
}

@MainActor
@Test
func indexedCueMutationInvalidatesFilterProjectionAndAdvancesItsIdentity() throws {
    let search = SearchStore()
    let originalKey = SearchFilterOnlyProjectionKey(
        filterSignature: "cues:contains:review",
        folderPaths: ["/Media"],
        indexedCueDataRevision: search.indexedCueDataRevision
    )
    _ = search.prepareFilterOnlyTableProjection(key: originalKey)
    let stalePageToken = try #require(search.beginFilterOnlyPageLoad(
        key: originalKey,
        loadedRowCount: 0
    ))
    search.tableRowStore.updateResidentSearchResults(
        [makeTableSandboxSearchResult(
            id: 42,
            content: "Stale indexed Cue",
            speakers: [],
            searchRank: 0
        )],
        cueContentProvider: { _ in nil },
        tableName: "test-search"
    )
    search.cueContextSearchRequest = CueContextSearchRequest(
        displayTitle: "Episode",
        subtitlePath: "/Media/Episode.srt",
        targetCueID: 42
    )

    let mutation = search.beginIndexedCueDataMutation()

    #expect(search.tableProjectionSource == nil)
    #expect(search.tableRowStore.snapshot.totalRowCount == 0)
    #expect(search.cueContextSearchRequest == nil)
    #expect(!search.acceptsFilterOnlyPageLoad(stalePageToken))
    #expect(search.indexedCueDataRevision == 0)
    #expect(search.completeIndexedCueDataMutation(mutation))
    #expect(!search.completeIndexedCueDataMutation(mutation))
    #expect(search.indexedCueDataRevision == 1)

    let refreshedKey = SearchFilterOnlyProjectionKey(
        filterSignature: originalKey.filterSignature,
        folderPaths: originalKey.folderPaths,
        indexedCueDataRevision: search.indexedCueDataRevision
    )
    #expect(refreshedKey != originalKey)
    #expect(search.prepareFilterOnlyTableProjection(key: refreshedKey))

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
        speakers: [],
        searchRank: 0
    )
    search.replaceLoadedSearchResults([result])
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
        speakers: [],
        searchRank: 0
    )
    search.replaceLoadedSearchResults([original])
    search.activateResidentSearchTableProjection()
    let originalSnapshotVersion = search.tableRowStore.snapshot.version

    search.replaceLoadedSearchResults([
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
    let database = try SubtitleDatabase(path: databaseURL)
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
    return try database.searchPage("今日", limit: 10).results
}

private func makeTableSandboxSearchResult(
    id: Int64,
    content: String,
    speakers: Set<String>,
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
        speakers: speakers,
        searchRank: searchRank
    )
}
