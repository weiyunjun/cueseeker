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
