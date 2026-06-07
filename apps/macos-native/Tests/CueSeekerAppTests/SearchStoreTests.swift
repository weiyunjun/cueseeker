import Combine
import Foundation
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
