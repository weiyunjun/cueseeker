import Foundation
import AppKit
import Testing
@testable import CueSeekerCore
@testable import CueSeekerApp

@MainActor
struct ExcerptLifecycleAndInvalidItemsTests {
    @Test
    func excerptRemainsIntactDuringTaskAndDefersReloadUntilReappearance() async throws {
        try await withExcerptTestApp { app, database in
            // Set up a video and an excerpt
            try indexExcerptVideo("Episode1", in: database)
            let excerptDB = try #require(app.excerptDatabase)
            let list = try excerptDB.createExcerptList(name: "Favorites", description: "")
            let cue = try #require(try SearchDatabase(path: database.path).search("placeholder").first)
            _ = try excerptDB.upsertExcerpt(cueID: cue.entryID, listID: list.id)
            app.excerpt.setActiveListID(list.id)
            app.reloadExcerptTableRows()
            await app.excerptTableRowsTask?.value
            app.reloadExcerptListOverview()
            await app.excerptListOverviewTask?.value

            let initialListCount = app.excerpt.listOverview.lists.count
            #expect(initialListCount >= 1)
            #expect(app.excerpt.tableRowStore.snapshot.totalRowCount == 1)

            // Simulate task start (prepareExcerptForIndexedContentMutation)
            app.prepareExcerptForIndexedContentMutation(under: [URL(fileURLWithPath: "/Media")])
            // During task: must not be cleared
            #expect(app.excerpt.listOverview.lists.count == initialListCount)
            #expect(app.excerpt.tableRowStore.snapshot.totalRowCount == 1)
            #expect(app.excerptNeedsReloadAfterIndexedContentMutation == true)

            // Task finishes (reloadExcerptAfterIndexedContentMutation)
            app.reloadExcerptAfterIndexedContentMutation()
            // Right after task completes: must NOT immediately reload
            #expect(app.excerptNeedsReloadAfterIndexedContentMutation == true)

            // Now interface reappears (e.g. user navigates to excerpt list)
            app.refreshExcerptOnReappearanceIfNeeded()
            #expect(app.excerptNeedsReloadAfterIndexedContentMutation == false)
        }
    }

    @Test
    func openingInvalidExcerptShowsNotInLibraryErrorAndStopsPlayer() async throws {
        try await withExcerptTestApp { app, database in
            app.ensurePlayerInitialized()
            try indexExcerptVideo("Episode1", in: database)
            let excerptDB = try #require(app.excerptDatabase)
            let list = try excerptDB.createExcerptList(name: "Favorites", description: "")
            let cue = try #require(try SearchDatabase(path: database.path).search("placeholder").first)
            let saved = try excerptDB.upsertExcerpt(cueID: cue.entryID, listID: list.id)

            // Now remove the video from library so cue becomes invalid
            try database.replaceEntries(
                subtitleFile: URL(fileURLWithPath: "/Media/Episode1.srt"),
                videoFile: URL(fileURLWithPath: "/Media/Episode1.mkv"),
                entries: []
            )

            // Attempt to play the excerpt
            app.openExcerpt(saved)

            #expect(app.currentPlaybackItemLeftLibrary == true)
            #expect(app.playback.playbackStatus == .loadFailed)
            #expect(app.playback.errorMessages[.notInLibrary] != nil)
            #expect(app.playback.isPlaybackSurfaceExpanded == true)
            #expect(app.playback.playlistPosition == nil)
        }
    }

    @Test
    func openingInvalidExcerptWithTableScopeAndNonZeroOrdinalDoesNotCrash() async throws {
        try await withExcerptTestApp { app, database in
            app.ensurePlayerInitialized()
            try indexExcerptVideo("Episode1", in: database)
            let excerptDB = try #require(app.excerptDatabase)
            let list = try excerptDB.createExcerptList(name: "Favorites", description: "")
            let cue = try #require(try SearchDatabase(path: database.path).search("placeholder").first)
            let saved = try excerptDB.upsertExcerpt(cueID: cue.entryID, listID: list.id)

            // Remove video from library
            try database.replaceEntries(
                subtitleFile: URL(fileURLWithPath: "/Media/Episode1.srt"),
                videoFile: URL(fileURLWithPath: "/Media/Episode1.mkv"),
                entries: []
            )

            let scope = PlaybackPlaylistExcerptScope.table(
                PlaybackPlaylistExcerptTableContext(
                    runID: UUID(),
                    searchText: "",
                    totalCount: 1
                )
            )

            // Pass non-zero ordinal like a table click on an item that has left library
            app.openExcerpt(
                saved,
                navigationScopeIDs: [saved.id],
                playlistScope: scope,
                playlistSelectedOrdinal: 1,
                displayTitle: "Episode1"
            )

            #expect(app.currentPlaybackItemLeftLibrary == true)
            #expect(app.playback.playbackStatus == .loadFailed)
            #expect(app.playback.errorMessages[.notInLibrary] == "This item is no longer in the library")
            #expect(app.playback.isPlaybackSurfaceExpanded == true)
            #expect(app.playback.playlistPosition == nil)
            #expect(app.excerptPlaybackNavigationSnapshot == nil)
        }
    }
}

// MARK: - Test Fixture

private func indexExcerptVideo(
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

@MainActor
private func withExcerptTestApp(
    _ body: @MainActor (AppCoordinator, IndexingDatabase) async throws -> Void
) async throws {
    let suiteName = "CueSeekerExcerptTestApp-\(UUID().uuidString)"
    let userDefaults = try #require(UserDefaults(suiteName: suiteName))
    let databaseURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerExcerptTestApp-\(UUID().uuidString)")
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
