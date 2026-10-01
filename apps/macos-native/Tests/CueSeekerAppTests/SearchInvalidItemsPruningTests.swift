import Foundation
import AppKit
import Testing
@testable import CueSeekerCore
@testable import CueSeekerApp

@MainActor
struct SearchInvalidItemsPruningTests {
    @Test
    func searchPrunesInvalidItemsUponEnteringPlayback() async throws {
        try await withPruningTestApp { app, database in
            app.ensurePlayerInitialized()
            for name in ["A", "B", "C"] {
                try indexPruningVideo(name, in: database)
            }
            let results = try SearchDatabase(path: database.path)
                .search("placeholder")
                .sorted { $0.videoPath < $1.videoPath }
            #expect(results.count == 3)

            app.search.replaceResultState(
                results: results,
                status: .completed,
                totalCount: 3,
                fileSummaries: [],
                countState: .exact,
                knownResultCount: 3,
                knownFileCount: 3,
                hasMore: false
            )
            app.search.updateSearchSnapshotMutationRevision()
            #expect(app.search.searchResults.count == 3)
            #expect(app.search.searchResultTotalCount == 3)

            // Remove B's cue from database
            try emptyPruningSubtitle("B", in: database)
            // Mark a mutation occurred
            let mutationToken = app.search.beginIndexedCueDataMutation()
            _ = app.search.completeIndexedCueDataMutation(mutationToken)

            // User has not entered playback yet: results must stay unchanged
            #expect(app.search.searchResults.count == 3)
            #expect(app.search.searchResultTotalCount == 3)

            // Now click A to enter playback
            app.openSearchResult(results[0])

            // Search results and totalCount must have pruned B
            #expect(app.search.searchResults.map(\.videoName) == ["A.mkv", "C.mkv"])
            #expect(app.search.searchResultTotalCount == 2)
            #expect(app.playback.playlistSource?.boundary.totalCount == 2)
        }
    }

    @Test
    func searchPrunesSynchronouslyWhenTaskFinishesDuringPlayback() async throws {
        try await withPruningTestApp { app, database in
            app.ensurePlayerInitialized()
            for name in ["A", "B", "C"] {
                try indexPruningVideo(name, in: database)
            }
            let results = try SearchDatabase(path: database.path)
                .search("placeholder")
                .sorted { $0.videoPath < $1.videoPath }

            app.search.replaceResultState(
                results: results,
                status: .completed,
                totalCount: 3,
                fileSummaries: [],
                countState: .exact,
                knownResultCount: 3,
                knownFileCount: 3,
                hasMore: false
            )

            // Enter playback on A while all are valid
            app.openSearchResult(results[0])
            #expect(app.search.searchResults.count == 3)

            // During playback, library changes: B is emptied
            app.holdPlaybackBeforeIndexedContentChange()
            try emptyPruningSubtitle("B", in: database)
            app.reconcilePlaybackAfterIndexedContentChange()

            // Both playlist and search must have pruned B
            #expect(app.search.searchResults.map(\.videoName) == ["A.mkv", "C.mkv"])
            #expect(app.search.searchResultTotalCount == 2)
            #expect(app.playback.playlistSource?.currentItems().compactMap { item -> String? in
                guard case .search(let r) = item.target else { return nil }
                return r.videoName
            } == ["A.mkv", "C.mkv"])
        }
    }

    @Test
    func searchDoesNotPruneWhenPlaybackNeverEntered() async throws {
        try await withPruningTestApp { app, database in
            for name in ["A", "B"] {
                try indexPruningVideo(name, in: database)
            }
            let results = try SearchDatabase(path: database.path)
                .search("placeholder")
                .sorted { $0.videoPath < $1.videoPath }

            app.search.replaceResultState(
                results: results,
                status: .completed,
                totalCount: 2,
                fileSummaries: [],
                countState: .exact,
                knownResultCount: 2,
                knownFileCount: 2,
                hasMore: false
            )

            // Database mutates
            try emptyPruningSubtitle("B", in: database)

            // User navigates back and forward, or switches tabs
            app.navigateWorkbench(to: .recent)
            app.navigateWorkbench(to: .search)

            // Results and totalCount must stay intact because playback was never entered
            #expect(app.search.searchResults.count == 2)
            #expect(app.search.searchResultTotalCount == 2)
        }
    }

    @Test
    func invalidSearchResultShowsErrorBannerAndNavigatesToSurvivingResultClearingError() async throws {
        try await withPruningTestApp { app, database in
            app.ensurePlayerInitialized()
            for name in ["A", "B", "C"] {
                try indexPruningVideo(name, in: database)
            }
            let results = try SearchDatabase(path: database.path)
                .search("placeholder")
                .sorted { $0.videoPath < $1.videoPath }

            app.search.replaceResultState(
                results: results,
                status: .completed,
                totalCount: 3,
                fileSummaries: [],
                countState: .exact,
                knownResultCount: 3,
                knownFileCount: 3,
                hasMore: false
            )

            // Remove B's cue
            try emptyPruningSubtitle("B", in: database)

            // Open invalid result B
            app.openSearchResult(results[1])

            #expect(app.currentPlaybackItemLeftLibrary == true)
            #expect(app.playback.playbackStatus == .loadFailed)
            #expect(app.playback.errorMessages[.notInLibrary] == "This item is no longer in the library")
            #expect(app.playback.isPlaybackSurfaceExpanded == true)
            #expect(app.playback.playlistPosition == nil)
            #expect(app.playback.playlistSource?.boundary.totalCount == 2)

            // Navigate to surviving item
            app.goNext()

            #expect(app.currentPlaybackItemLeftLibrary == false)
            #expect(app.search.selectedSearchResult?.entryID != results[1].entryID)
            #expect(app.playback.errorMessages[.notInLibrary] == nil)
        }
    }

    @Test
    func openingInvalidSearchResultWithEmptyPlaylistShowsErrorBannerAndNoAvailableResultsFeedback() async throws {
        try await withPruningTestApp { app, database in
            app.ensurePlayerInitialized()
            try indexPruningVideo("A", in: database)
            let results = try SearchDatabase(path: database.path).search("placeholder")

            app.search.replaceResultState(
                results: results,
                status: .completed,
                totalCount: 1,
                fileSummaries: [],
                countState: .exact,
                knownResultCount: 1,
                knownFileCount: 1,
                hasMore: false
            )

            // Remove A's cue
            try emptyPruningSubtitle("A", in: database)

            // Open invalid result A
            app.openSearchResult(results[0])

            #expect(app.currentPlaybackItemLeftLibrary == true)
            #expect(app.playback.playbackStatus == .loadFailed)
            #expect(app.playback.errorMessages[.notInLibrary] == "This item is no longer in the library")
            #expect(app.playback.playlistSource?.boundary.totalCount == 0)
            #expect(app.playback.playbackViewModel?.feedback?.text == "No Available Results")
            #expect(app.playback.playbackViewModel?.feedback?.icon == .warning)

            // Stop playback dismisses error banner
            app.stopPlayback()
            #expect(app.playback.errorMessages[.notInLibrary] == nil)
        }
    }

    @Test
    func commandPanelPlaybackDismissesErrorBanner() async throws {
        try await withPruningTestApp { app, database in
            app.ensurePlayerInitialized()
            for name in ["A", "B"] {
                try indexPruningVideo(name, in: database)
            }
            let results = try SearchDatabase(path: database.path)
                .search("placeholder")
                .sorted { $0.videoPath < $1.videoPath }

            app.search.replaceResultState(
                results: results,
                status: .completed,
                totalCount: 2,
                fileSummaries: [],
                countState: .exact,
                knownResultCount: 2,
                knownFileCount: 2,
                hasMore: false
            )

            // Remove A's cue
            try emptyPruningSubtitle("A", in: database)

            // Open invalid result A
            app.openSearchResult(results[0])
            #expect(app.playback.errorMessages[.notInLibrary] == "This item is no longer in the library")

            // Open Command Panel search with valid item B
            app.playback.presentCommandPanel(
                PlaybackCommandPanelPresentation(
                    page: .searchResults,
                    query: "placeholder",
                    selectedOrdinal: 0,
                    resumesPlaybackOnDismiss: false
                )
            )
            app.synchronizePlaybackCommandPanelSearchResults()

            // Trigger playFromThisCue on B via Command Panel
            #expect(app.requestPlaybackCommandPanelSearchAction(.playFromThisCue, ordinal: 0))

            #expect(app.currentPlaybackItemLeftLibrary == false)
            #expect(app.playback.errorMessages[.notInLibrary] == nil)
        }
    }
}

// MARK: - Test Fixture

private func indexPruningVideo(
    _ basename: String,
    in database: IndexingDatabase
) throws {
    try database.replaceEntries(
        subtitleFile: URL(fileURLWithPath: "/Media/\(basename).srt"),
        videoFile: URL(fileURLWithPath: "/Media/\(basename).mkv"),
        entries: [
            SubtitleEntry(
                sequenceNumber: 1,
                startTimecode: "00:00:01,000",
                endTimecode: "00:00:02,000",
                startMilliseconds: 1_000,
                endMilliseconds: 2_000,
                text: "placeholder \(basename)"
            )
        ]
    )
}

private func emptyPruningSubtitle(
    _ basename: String,
    in database: IndexingDatabase
) throws {
    try database.replaceEntries(
        subtitleFile: URL(fileURLWithPath: "/Media/\(basename).srt"),
        videoFile: URL(fileURLWithPath: "/Media/\(basename).mkv"),
        entries: []
    )
}

@MainActor
private func withPruningTestApp(
    _ body: @MainActor (AppCoordinator, IndexingDatabase) async throws -> Void
) async throws {
    let suiteName = "CueSeekerSearchPruningTests-\(UUID().uuidString)"
    let userDefaults = try #require(UserDefaults(suiteName: suiteName))
    let databaseURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerSearchPruningTests-\(UUID().uuidString)")
        .appendingPathExtension("sqlite")
    defer {
        userDefaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: databaseURL)
        try? FileManager.default.removeItem(atPath: databaseURL.path + "-wal")
        try? FileManager.default.removeItem(atPath: databaseURL.path + "-shm")
    }

    _ = NSApplication.shared
    let app = AppCoordinator(userDefaults: userDefaults, databaseURL: databaseURL)
    await app.startupDatabaseTask?.value
    let database = try #require(app.indexingDatabase)
    try await body(app, database)
}
