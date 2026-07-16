import AppKit
import CueSeekerCore
import Foundation
import Testing
@testable import CueSeekerApp

@MainActor
@Test
func playbackSearchUsesWorkbenchResultsWithoutRetainingAnotherDataset() async throws {
    let searchStore = SearchStore()
    searchStore.searchResults = (0..<40).map {
        playbackSharedSearchResult(
            id: Int64(1_000 + $0),
            rank: $0
        )
    }
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
    #expect(window.retainedItemCount == 0)
    #expect(window.requestWindow(containing: 39))
    #expect(window.item(at: 39)?.identity == .search(1_039))

    searchStore.searchResults.append(
        playbackSharedSearchResult(id: 1_040, rank: 40)
    )
    await Task.yield()

    #expect(window.snapshot.totalCount == 41)
    #expect(window.item(at: 40)?.identity == .search(1_040))
    #expect(window.retainedItemCount == 0)

    _ = session.dismissByUser()
    #expect(searchStore.searchResults.count == 41)
}

@MainActor
@Test
func playbackSearchTemporaryFilterDoesNotChangeFormalFilterUntilPlay() throws {
    _ = NSApplication.shared
    let databaseURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("playback-shared-search-filter-\(UUID().uuidString).sqlite")
    defer { try? FileManager.default.removeItem(at: databaseURL) }
    let app = AppCoordinator(databaseURL: databaseURL)
    let formalFilter = SubtitleSearchFilterSet(rules: [
        SubtitleSearchFilterRule(
            field: .display,
            operatorID: .contains,
            value: "Episode"
        ),
    ])
    app.search.activeFilterSet = formalFilter
    app.search.resultFilterSet = formalFilter

    app.activatePlaybackSearchHost()

    #expect(app.search.isPlaybackTemporaryFilterActive)
    #expect(app.search.activeFilterSet == formalFilter)
    #expect(app.search.resultFilterSet.isEffectivelyEmpty)

    app.finishPlaybackSearchHost(committingEmptyFilter: false)

    #expect(!app.search.isPlaybackTemporaryFilterActive)
    #expect(app.search.activeFilterSet == formalFilter)
    #expect(app.search.resultFilterSet == formalFilter)

    app.activatePlaybackSearchHost()
    app.finishPlaybackSearchHost(committingEmptyFilter: true)

    #expect(!app.search.isPlaybackTemporaryFilterActive)
    #expect(app.search.activeFilterSet.isEffectivelyEmpty)
    #expect(app.search.resultFilterSet.isEffectivelyEmpty)
}

@MainActor
@Test
func playbackSearchInputUpdatesTheWorkbenchQuery() {
    _ = NSApplication.shared
    let databaseURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("playback-shared-search-query-\(UUID().uuidString).sqlite")
    defer { try? FileManager.default.removeItem(at: databaseURL) }
    let app = AppCoordinator(databaseURL: databaseURL)

    app.updatePlaybackSearchQuery("shared query")

    #expect(app.search.searchQuery == "shared query")
    #expect(app.search.isPlaybackTemporaryFilterActive)
    #expect(app.search.resultFilterSet.isEffectivelyEmpty)
}

@MainActor
@Test
func playbackSearchFailedPlayDoesNotCommitTheTemporaryFilter() async throws {
    _ = NSApplication.shared
    let databaseURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("playback-shared-search-failed-play-\(UUID().uuidString).sqlite")
    defer { try? FileManager.default.removeItem(at: databaseURL) }
    let app = AppCoordinator(databaseURL: databaseURL)
    let formalFilter = SubtitleSearchFilterSet(rules: [
        SubtitleSearchFilterRule(
            field: .display,
            operatorID: .contains,
            value: "Episode"
        ),
    ])
    let result = playbackSharedSearchResult(id: 8_001, rank: 0)
    app.search.activeFilterSet = formalFilter
    app.search.resultFilterSet = SubtitleSearchFilterSet()
    app.search.isPlaybackTemporaryFilterActive = true
    app.search.searchQuery = "shared"
    app.search.searchResults = [result]

    app.openSearchResult(
        result,
        playbackSearchPromotion: PlaybackSearchPromotion(
            query: "shared",
            scopePaths: [],
            selectedOrdinal: 0
        )
    )
    for _ in 0..<100 where app.search.isPlaybackTemporaryFilterActive {
        try await Task.sleep(for: .milliseconds(10))
    }

    #expect(!app.search.isPlaybackTemporaryFilterActive)
    #expect(app.search.activeFilterSet == formalFilter)
    #expect(app.search.resultFilterSet == formalFilter)
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
