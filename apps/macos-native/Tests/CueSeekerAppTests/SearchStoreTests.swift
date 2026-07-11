import Foundation
import AppKit
import Testing
import CueSeekerCore
@testable import CueSeekerApp

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

    #expect(resolvedCueContextTargetSourceIndex(in: page, targetEntryID: target.entryID) == 2717)
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

    #expect(resolvedCueContextTargetSourceIndex(in: page, targetEntryID: 1520171) == 2688)
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
    let page = try database.allCueGroupsVisiblePage(
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

    app.openSearchResult(first, recordsNavigationHistory: false)

    #expect(!app.canOpenPreviousSearchResult)
    #expect(app.canOpenNextSearchResult)
    #expect(app.search.searchNavigationSnapshot?.previous == nil)
    #expect(app.search.searchNavigationSnapshot?.current?.entryID == first.entryID)
    #expect(app.search.searchNavigationSnapshot?.next?.entryID == second.entryID)

    app.openSearchResult(second, recordsNavigationHistory: false)

    #expect(app.canOpenPreviousSearchResult)
    #expect(app.canOpenNextSearchResult)
    #expect(app.search.searchNavigationSnapshot?.previous?.entryID == first.entryID)
    #expect(app.search.searchNavigationSnapshot?.current?.entryID == second.entryID)
    #expect(app.search.searchNavigationSnapshot?.next?.entryID == third.entryID)
}

private func makeSearchResults() throws -> [SubtitleSearchResult] {
    let databaseURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerSearchStoreTests-\(UUID().uuidString).sqlite")
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()
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
