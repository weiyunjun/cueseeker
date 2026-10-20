import AppKit
@testable import CueSeekerCore
import Foundation
import Testing
@testable import CueSeekerApp

@MainActor
@Test
func selectedTextSearchUsesPersistedFilterAndReusesAnOpenCommandPanel() throws {
    _ = NSApplication.shared
    let suiteName = "PlaybackSelectedTextSearch-\(UUID().uuidString)"
    let userDefaults = try #require(UserDefaults.temporary(suiteName: suiteName))
    let databaseURL = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "playback-selected-text-search-\(UUID().uuidString).sqlite"
        )
    defer {
        userDefaults.removePersistentDomainAndPlist(forName: suiteName)
        removeTemporaryDatabase(at: databaseURL)
    }
    let persistedFilter = CueFacetFilter(languages: [.japanese])
    SettingsStore(userDefaults: userDefaults).searchFacetFilter = persistedFilter
    let app = AppCoordinator(
        userDefaults: userDefaults,
        databaseURL: databaseURL
    )
    app.search.selectResult(
        playbackSharedSearchResult(id: 9_001, rank: 0)
    )
    app.activePlaybackSource = .search
    app.playback.isPlaybackSurfaceExpanded = true

    #expect(app.presentPlaybackCommandPanel())
    app.searchPlaybackSelectedText("first\r\nsecond")
    #expect(app.search.searchFacetFilter == persistedFilter)
    #expect(app.playback.commandPanelPresentation?.page == .searchResults)
    #expect(app.playback.commandPanelPresentation?.query == "first second")
    #expect(app.search.searchQuery == "first second")

    app.searchPlaybackSelectedText("replacement")
    #expect(app.playback.commandPanelPresentation?.page == .searchResults)
    #expect(app.playback.commandPanelPresentation?.query == "replacement")
    #expect(app.search.searchQuery == "replacement")
}

@MainActor
@Test
func playbackSearchUsesWorkbenchResultsWithoutRetainingAnotherDataset() async throws {
    let searchStore = SearchStore()
    let initialResults = (0..<40).map {
        playbackSharedSearchResult(
            id: Int64(1_000 + $0),
            rank: $0
        )
    }
    searchStore.replaceResidentResults(initialResults)
    let session = PlaybackSubtitleFocusSessionStore(
        openSnapshot: playbackSharedSearchOpenSnapshot(),
        sessionGeneration: 1,
        searchStore: searchStore
    )
    let window = try #require(session.searchWindow)

    #expect(session.searchStore === searchStore)
    #expect(window.snapshot.totalCount == 40)
    #expect(window.snapshot.loadedOrdinalRange == 0..<40)
    #expect(window.snapshot.isComplete)
    #expect(window.item(at: 39)?.identity == .search(1_039))

    searchStore.replaceResidentResults(
        searchStore.searchResults
            + [playbackSharedSearchResult(id: 1_040, rank: 40)]
    )
    await Task.yield()

    #expect(window.snapshot.totalCount == 41)
    #expect(window.item(at: 40)?.identity == .search(1_040))

    _ = session.dismissByUser()
    #expect(searchStore.searchResults.count == 41)
}

@MainActor
@Test
func playbackCommandPanelSearchPersistsWorkbenchFacetResultsAfterDismissal()
    throws
{
    _ = NSApplication.shared
    let databaseURL = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "playback-formal-search-filter-\(UUID().uuidString).sqlite"
        )
    defer { removeTemporaryDatabase(at: databaseURL) }
    let app = AppCoordinator(databaseURL: databaseURL)
    let facetFilter = CueFacetFilter(
        durations: [.underOneSecond]
    )
    let included = playbackSharedSearchResult(id: 8_001, rank: 0)
    let excluded = playbackSharedSearchResult(id: 8_002, rank: 1)
    app.search.updateSearchFacetFilter(facetFilter)
    app.search.selectResult(included)
    app.playback.isPlaybackSurfaceExpanded = true
    #expect(app.presentPlaybackCommandPanelSearch(
        query: "shared",
        startsSearch: false
    ))

    let generation = app.search.prepareSearch(
        appending: false,
        filterSet: SubtitleSearchFilterSet()
    )
    let snapshot = CueFacetSnapshot(
        cueIDs: [included.entryID, excluded.entryID],
        durationFacets: [.underOneSecond, .fiveSecondsOrMore],
        characterFacets: [.oneToTen, .oneToTen],
        languageFacets: [[], []],
        watchStateFacets: [.unwatched, .unwatched],
        folderFacets: Array(repeating: "/Media", count: ([included.entryID, excluded.entryID]).count)
    )
    // The scan matched both cues; the filter kept only the first as a result.
    #expect(app.search.commitExactSearchPage(
        SubtitleSearchPage(
            results: [included],
            cueIDs: [included.entryID],
            totalCount: 1,
            fileSummaries: [],
            facetSnapshot: snapshot
        ),
        generation: generation
    ))
    app.synchronizePlaybackCommandPanelSearchResults()

    #expect(app.search.searchQuery == "shared")
    #expect(app.search.searchFacetFilter == facetFilter)
    #expect(app.search.searchResults.map(\.entryID) == [8_001])
    #expect(app.playback.commandPanelSearchWindow?.snapshot.totalCount == 1)

    #expect(app.dismissPlaybackCommandPanelFromUser())
    #expect(app.search.searchQuery == "shared")
    #expect(app.search.searchFacetFilter == facetFilter)
    #expect(app.search.searchResults.map(\.entryID) == [8_001])
}

private func playbackSharedSearchOpenSnapshot()
    -> PlaybackSubtitleFocusOpenSnapshot {
    PlaybackSubtitleFocusOpenSnapshot(
        source: SubtitleFocusSourceIdentity(
            videoPath: "/Media/Shared.mkv",
            subtitlePath: "/Media/Shared.srt",
            subtitleFormat: .srt
        ),
        timestampMilliseconds: 0,
        wasPlaying: false
    )
}

private func playbackSharedSearchResult(
    id: Int64,
    rank: Int
) -> SubtitleSearchResult {
    SubtitleSearchResult(
        entryID: id,
        cueGroupID: id + 10_000,
        cueEventIndex: Int(id),
        cueDisplayOrder: 0,
        primaryGroupIndex: 0,
        subtitlePath: "/Media/Shared.srt",
        subtitleFormat: .srt,
        videoPath: "/Media/Shared.mkv",
        videoName: "Shared.mkv",
        startMilliseconds: rank * 1_000,
        endMilliseconds: rank * 1_000 + 900,
        content: "shared result \(rank)",
        cueLines: ["shared result \(rank)"],
        cueGroupLines: ["shared result \(rank)"],
        searchRank: rank
    )
}

@MainActor
@Test
func commandPanelPointerSelectionMovesTheRootHighlightWithinBounds() throws {
    _ = NSApplication.shared
    let suiteName = "PlaybackCommandPanelPointerSelection-\(UUID().uuidString)"
    let userDefaults = try #require(UserDefaults.temporary(suiteName: suiteName))
    let databaseURL = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "playback-command-panel-pointer-\(UUID().uuidString).sqlite"
        )
    defer {
        userDefaults.removePersistentDomainAndPlist(forName: suiteName)
        removeTemporaryDatabase(at: databaseURL)
    }
    let app = AppCoordinator(
        userDefaults: userDefaults,
        databaseURL: databaseURL
    )
    app.search.selectResult(playbackSharedSearchResult(id: 9_101, rank: 0))
    app.activePlaybackSource = .search
    app.playback.isPlaybackSurfaceExpanded = true

    #expect(app.presentPlaybackCommandPanel())
    #expect(app.playback.commandPanelPresentation?.selectedOrdinal == 0)

    // An empty query leaves two rows: Recent Videos and Recent Excerpts.
    app.selectPlaybackCommandPanelItem(at: 1)
    #expect(app.playback.commandPanelPresentation?.selectedOrdinal == 1)

    // Out-of-range ordinals are ignored rather than clearing the highlight.
    app.selectPlaybackCommandPanelItem(at: 2)
    #expect(app.playback.commandPanelPresentation?.selectedOrdinal == 1)
    app.selectPlaybackCommandPanelItem(at: -1)
    #expect(app.playback.commandPanelPresentation?.selectedOrdinal == 1)

    // A query adds the search row, so the third position becomes reachable.
    app.updatePlaybackCommandPanelQuery("query")
    #expect(app.playback.commandPanelPresentation?.selectedOrdinal == 0)
    app.selectPlaybackCommandPanelItem(at: 2)
    #expect(app.playback.commandPanelPresentation?.selectedOrdinal == 2)
}

@Test
func commandPanelSecondaryHeaderCentersShiftsAndTruncatesTitleAroundControls() {
    let bounds = CGRect(x: 0, y: 0, width: 1_000, height: 58)
    let leadingSize = CGSize(width: 32, height: 32)
    let trailingSize = CGSize(width: 220, height: 32)
    let spacing: CGFloat = 12

    // Short title stays strictly centered in the full header width.
    let centered = PlaybackCommandPanelHeaderLayoutGeometry.resolve(
        bounds: bounds,
        leadingSize: leadingSize,
        naturalTitleSize: CGSize(width: 120, height: 20),
        trailingSize: trailingSize,
        spacing: spacing
    )
    #expect(centered.leadingFrame.minX == 0)
    #expect(centered.trailingFrame.maxX == 1_000)
    #expect(centered.titleFrame.midX == bounds.midX)
    #expect(centered.titleFrame.width == 120)

    // Medium-long title shifts leftward into available space before truncating,
    // keeping a 12pt gap from the trailing Filter + Sort controls.
    let shifted = PlaybackCommandPanelHeaderLayoutGeometry.resolve(
        bounds: bounds,
        leadingSize: leadingSize,
        naturalTitleSize: CGSize(width: 600, height: 20),
        trailingSize: trailingSize,
        spacing: spacing
    )
    #expect(shifted.titleFrame.width == 600)
    #expect(shifted.titleFrame.maxX == shifted.trailingFrame.minX - spacing)
    #expect(shifted.titleFrame.minX > shifted.leadingFrame.maxX + spacing)

    // Very long title clamps to the available span with 12pt gaps on both sides.
    let truncated = PlaybackCommandPanelHeaderLayoutGeometry.resolve(
        bounds: bounds,
        leadingSize: leadingSize,
        naturalTitleSize: CGSize(width: 900, height: 20),
        trailingSize: trailingSize,
        spacing: spacing
    )
    #expect(truncated.titleFrame.minX == truncated.leadingFrame.maxX + spacing)
    #expect(truncated.titleFrame.maxX == truncated.trailingFrame.minX - spacing)
    #expect(truncated.titleFrame.width == 724)

    // Secondary pages without trailing controls (Recent Videos / Excerpts) keep
    // their title centered.
    let withoutTrailing = PlaybackCommandPanelHeaderLayoutGeometry.resolve(
        bounds: bounds,
        leadingSize: leadingSize,
        naturalTitleSize: CGSize(width: 140, height: 20),
        trailingSize: .zero,
        spacing: spacing
    )
    #expect(withoutTrailing.trailingFrame.width == 0)
    #expect(withoutTrailing.titleFrame.midX == bounds.midX)
}

@MainActor
@Test
func commandPanelSearchSynchronizesFilterAndSortWithWorkbenchAndResetsSelection()
    throws
{
    _ = NSApplication.shared
    let suiteName = "PlaybackCommandPanelFilterSort-\(UUID().uuidString)"
    let userDefaults = try #require(UserDefaults.temporary(suiteName: suiteName))
    let databaseURL = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "playback-command-panel-filter-sort-\(UUID().uuidString).sqlite"
        )
    defer {
        userDefaults.removePersistentDomainAndPlist(forName: suiteName)
        removeTemporaryDatabase(at: databaseURL)
    }

    let app = AppCoordinator(
        userDefaults: userDefaults,
        databaseURL: databaseURL
    )
    let first = SubtitleSearchResult(
        entryID: 7_001,
        cueGroupID: 17_001,
        cueEventIndex: 1,
        cueDisplayOrder: 0,
        primaryGroupIndex: 0,
        subtitlePath: "/Media/Episode02.srt",
        subtitleFormat: .srt,
        videoPath: "/Media/Episode02.mkv",
        videoName: "Episode02.mkv",
        displayTitle: "Episode 02",
        startMilliseconds: 1_000,
        endMilliseconds: 1_800,
        content: "short line",
        cueLines: ["short line"],
        cueGroupLines: ["short line"],
        searchRank: 0
    )
    let second = SubtitleSearchResult(
        entryID: 7_002,
        cueGroupID: 17_002,
        cueEventIndex: 2,
        cueDisplayOrder: 0,
        primaryGroupIndex: 0,
        subtitlePath: "/Media/Episode01.srt",
        subtitleFormat: .srt,
        videoPath: "/Media/Episode01.mkv",
        videoName: "Episode01.mkv",
        displayTitle: "Episode 01",
        startMilliseconds: 2_000,
        endMilliseconds: 8_000,
        content: "a much longer subtitle line for testing",
        cueLines: ["a much longer subtitle line for testing"],
        cueGroupLines: ["a much longer subtitle line for testing"],
        searchRank: 1
    )

    app.search.selectResult(first)
    app.activePlaybackSource = .search
    app.playback.isPlaybackSurfaceExpanded = true
    #expect(app.presentPlaybackCommandPanelSearch(
        query: "line",
        startsSearch: false
    ))

    let generation = app.search.prepareSearch(
        appending: false,
        filterSet: SubtitleSearchFilterSet()
    )
    let snapshot = CueFacetSnapshot(
        cueIDs: [first.entryID, second.entryID],
        durationFacets: [.underOneSecond, .fiveSecondsOrMore],
        characterFacets: [.oneToTen, .thirtyOneOrMore],
        characterWidths: [10, 39],
        languageFacets: [[.english], [.japanese]],
        watchStateFacets: [.unwatched, .watching],
        folderFacets: ["/Media", "/Media"]
    )
    #expect(app.search.commitExactSearchPage(
        SubtitleSearchPage(
            results: [first, second],
            cueIDs: [first.entryID, second.entryID],
            totalCount: 2,
            fileSummaries: [],
            facetSnapshot: snapshot
        ),
        generation: generation
    ))
    app.synchronizePlaybackCommandPanelSearchResults()

    // Move selection to the second result and hold a stale page snapshot.
    #expect(app.movePlaybackCommandPanelSelection(1))
    #expect(app.playback.commandPanelSearchWindow?.selectedOrdinal == 1)
    app.playback.holdCommandPanelPage(
        .searchResults(totalCount: 99, hasMoreResults: true)
    )

    // Changing Sort from Command Panel Search Results updates both SearchStore
    // and SettingsStore, clears the held page, reorders the preview, and resets
    // the selection to the first item.
    app.updateSearchSortOrder(.mostCharacters)
    #expect(app.search.searchSortOrder == .mostCharacters)
    #expect(app.settings.searchSortOrder == .mostCharacters)
    #expect(app.playback.commandPanelHeldPage == nil)
    #expect(app.search.searchResults.map(\.entryID) == [second.entryID, first.entryID])
    #expect(app.playback.commandPanelSearchWindow?.snapshot.totalCount == 2)
    #expect(app.playback.commandPanelSearchWindow?.item(at: 0)?.identity == .search(second.entryID))
    #expect(app.playback.commandPanelSearchWindow?.selectedOrdinal == 0)

    // Move selection to ordinal 1 again, then apply a Facet Filter.
    #expect(app.movePlaybackCommandPanelSelection(1))
    #expect(app.playback.commandPanelSearchWindow?.selectedOrdinal == 1)

    let japaneseFilter = CueFacetFilter(languages: [.japanese])
    app.applySearchFacetFilter(japaneseFilter)
    #expect(app.search.searchFacetFilter == japaneseFilter)
    #expect(app.settings.searchFacetFilter == japaneseFilter)
    #expect(app.search.searchResults.map(\.entryID) == [second.entryID])
    #expect(app.playback.commandPanelSearchWindow?.snapshot.totalCount == 1)
    #expect(app.playback.commandPanelSearchWindow?.selectedOrdinal == 0)
}
