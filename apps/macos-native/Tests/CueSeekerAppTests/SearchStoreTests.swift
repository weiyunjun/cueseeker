import Combine
import Foundation
import AppKit
import Testing
import CueSeekerCore
@testable import CueSeekerApp

@MainActor
@Test
func activeSearchNavigationResultFollowsPlaybackTimeWithinLoadedWindow() throws {
    let store = SearchStore()
    let results = try makeSearchResults()
    let first = try #require(results.first { $0.content == "今日 first" })
    let second = try #require(results.first { $0.content == "今日 second" })
    let otherVideo = try #require(results.first { $0.content == "今日 other" })

    store.selectedSearchResult = first
    store.searchNavigationSnapshot = SearchNavigationSnapshot(
        totalCount: 3,
        currentIndex: first.searchRank,
        neighborhood: [first, second, otherVideo],
        previous: nil,
        current: first,
        next: second
    )
    store.applySearchNavigationVisibleWindow(
        [first, second, otherVideo],
        startIndex: 0,
        totalCount: 3
    )

    store.updateActiveSearchNavigationResult(
        videoPath: first.videoPath,
        subtitlePath: first.subtitlePath,
        currentMilliseconds: 3_250
    )

    #expect(store.activeSearchNavigationEntryID == second.entryID)
    #expect(store.activeSearchNavigationRank == second.searchRank)
}

@MainActor
@Test
func activeSearchNavigationResultDoesNotPublishWhenResultIsUnchanged() throws {
    let store = SearchStore()
    let result = try #require(try makeSearchResults().first { $0.content == "今日 first" })
    store.selectedSearchResult = result
    store.searchNavigationSnapshot = SearchNavigationSnapshot(
        totalCount: 1,
        currentIndex: result.searchRank,
        neighborhood: [result],
        previous: nil,
        current: result,
        next: nil
    )
    store.applyActiveSearchNavigationResult(result)

    var publishedChangeCount = 0
    let cancellable = store.objectWillChange.sink {
        publishedChangeCount += 1
    }

    store.updateActiveSearchNavigationResult(
        videoPath: result.videoPath,
        subtitlePath: result.subtitlePath,
        currentMilliseconds: 1_250
    )

    #expect(publishedChangeCount == 0)
    _ = cancellable
}

@MainActor
@Test
func tableSandboxAllCueContextFeedsPlaybackSearchNavigationWindow() throws {
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
    #expect(app.search.searchNavigationVisibleWindowStartIndex == 10)
    #expect(app.search.searchNavigationVisibleTotalCount == 42)
    #expect(app.search.searchNavigationVisibleResult(at: 10) == result)
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
    #expect(app.search.searchNavigationVisibleResult(at: selected.searchRank)?.entryID == selected.entryID)
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
