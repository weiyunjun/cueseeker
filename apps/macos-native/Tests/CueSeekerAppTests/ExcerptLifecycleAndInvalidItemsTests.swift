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
            #expect(app.playback.errorMessages[.notInLibrary] == "This item is no longer in the library")
            #expect(app.playback.isPlaybackSurfaceExpanded == true)
            #expect(app.playback.playlistPosition == nil)
            #expect(app.playback.playbackViewModel?.feedback?.text == "No Available Results")
            #expect(app.playback.playbackViewModel?.feedback?.icon == .warning)

            // Exiting playback dismisses error banner
            app.stopPlayback()
            #expect(app.playback.errorMessages[.notInLibrary] == nil)
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
            #expect(app.player != nil)
            #expect(app.playback.playbackViewModel != nil)
            #expect(app.playback.playlistPosition == nil)
            #expect(app.playback.playlistSource != nil)
            #expect(app.openPlaybackSubtitleFocusFromUser() == true)
            #expect(app.playback.subtitleFocusSession != nil)
            #expect(app.playback.errorMessages[.notInLibrary] == nil)
        }
    }

    @Test
    func invalidExcerptKeepsPlaylistSourceAndAllowsNavigatingToSurvivingExcerpt() async throws {
        try await withExcerptTestApp { app, database in
            app.ensurePlayerInitialized()
            try indexExcerptVideo("Episode1", in: database)
            try indexExcerptVideo("Episode2", in: database)
            let excerptDB = try #require(app.excerptDatabase)
            let list = try excerptDB.createExcerptList(name: "Favorites", description: "")
            let cue1 = try #require(try SearchDatabase(path: database.path).search("Episode1").first)
            let cue2 = try #require(try SearchDatabase(path: database.path).search("Episode2").first)
            let saved1 = try excerptDB.upsertExcerpt(cueID: cue1.entryID, listID: list.id)
            let saved2 = try excerptDB.upsertExcerpt(cueID: cue2.entryID, listID: list.id)

            app.excerpt.setActiveListID(list.id)
            app.reloadExcerptTableRows()
            await app.excerptTableRowsTask?.value

            // Remove only Episode1 from library
            try database.replaceEntries(
                subtitleFile: URL(fileURLWithPath: "/Media/Episode1.srt"),
                videoFile: URL(fileURLWithPath: "/Media/Episode1.mkv"),
                entries: []
            )

            let scope = PlaybackPlaylistExcerptScope.table(
                PlaybackPlaylistExcerptTableContext(
                    runID: app.excerpt.tableResultSnapshotID,
                    searchText: "",
                    totalCount: 2
                )
            )

            // Open invalid excerpt 1
            app.openExcerpt(
                saved1,
                navigationScopeIDs: [saved1.id, saved2.id],
                playlistScope: scope,
                playlistSelectedOrdinal: 0,
                displayTitle: "Episode1"
            )

            #expect(app.currentPlaybackItemLeftLibrary == true)
            #expect(app.playback.playbackStatus == .loadFailed)
            #expect(app.playback.playlistSource != nil)
            #expect(app.playback.playlistSource?.boundary.totalCount == 1)
            #expect(app.playback.playlistSource?.item(at: 0)?.identity == .excerpt(saved2.id))
            #expect(app.playback.errorMessages[.notInLibrary] == "This item is no longer in the library")

            // Navigate to next available excerpt (Episode2)
            app.goNext()

            #expect(app.currentPlaybackItemLeftLibrary == false)
            #expect(app.excerpt.selectedExcerpt?.id == saved2.id)
            #expect(app.canGoPrevious == false)
            #expect(app.canGoNext == false)
            #expect(app.playback.errorMessages[.notInLibrary] == nil)
        }
    }

    @Test
    func invalidExcerptMoveAndDuplicateAreIntercepted() async throws {
        try await withExcerptTestApp { app, database in
            try indexExcerptVideo("Episode1", in: database)
            let excerptDB = try #require(app.excerptDatabase)
            let list1 = try excerptDB.createExcerptList(name: "List1", description: "")
            let list2 = try excerptDB.createExcerptList(name: "List2", description: "")
            let cue = try #require(try SearchDatabase(path: database.path).search("placeholder").first)
            let saved = try excerptDB.upsertExcerpt(cueID: cue.entryID, listID: list1.id)

            // Remove video from library so cue becomes invalid
            try database.replaceEntries(
                subtitleFile: URL(fileURLWithPath: "/Media/Episode1.srt"),
                videoFile: URL(fileURLWithPath: "/Media/Episode1.mkv"),
                entries: []
            )

            // Attempt to move
            let moveSuccess = app.moveExcerpt(saved, toListID: list2.id, listName: list2.name)
            #expect(moveSuccess == false)
            #expect(app.toast.visibleItems.last?.request == TableToastRequest.cueNotInLibrary)

            // Attempt to duplicate
            let dupSuccess = app.duplicateExcerpt(saved, toListID: list2.id, listName: list2.name)
            #expect(dupSuccess == false)
            #expect(app.toast.visibleItems.last?.request == TableToastRequest.cueNotInLibrary)

            // Attempt beginCreatingExcerptList with pending transfer
            app.beginCreatingExcerptList(
                pendingTransfer: ExcerptListEditorPendingTransfer(
                    action: .moveToList,
                    target: .excerpt(saved)
                )
            )
            #expect(app.excerpt.listEditorSession == nil)
            #expect(app.toast.visibleItems.last?.request == TableToastRequest.cueNotInLibrary)
        }
    }

    @Test
    func residentExcerptTableProjectionCountsOnlyValidCuesInFilterDistributionWhileKeepingUnavailableRows() async throws {
        try await withExcerptTestApp { app, database in
            try indexExcerptVideo("Episode1", in: database)
            try indexExcerptVideo("Episode2", in: database)
            let excerptDB = try #require(app.excerptDatabase)
            let list = try excerptDB.createExcerptList(name: "MixedList", description: "")
            let cue1 = try #require(try SearchDatabase(path: database.path).search("Episode1").first)
            let cue2 = try #require(try SearchDatabase(path: database.path).search("Episode2").first)
            _ = try excerptDB.upsertExcerpt(cueID: cue1.entryID, listID: list.id)
            _ = try excerptDB.upsertExcerpt(cueID: cue2.entryID, listID: list.id)

            // Make Episode1 unavailable
            try database.replaceEntries(
                subtitleFile: URL(fileURLWithPath: "/Media/Episode1.srt"),
                videoFile: URL(fileURLWithPath: "/Media/Episode1.mkv"),
                entries: []
            )

            app.excerpt.setActiveListID(list.id)
            app.reloadExcerptTableRows()
            await app.excerptTableRowsTask?.value
            app.reloadExcerptListOverview()
            await app.excerptListOverviewTask?.value

            let listSummary = try #require(app.excerpt.listOverview.lists.first(where: { $0.id == list.id }))
            #expect(listSummary.cueCount == 1)

            let projection = app.residentExcerptTableProjection(
                searchText: "",
                facetFilter: CueFacetFilter()
            )
            #expect(projection.relations.count == 2)
            #expect(projection.distribution.totalCount == 1)
            #expect(app.excerpt.tableRowStore.snapshot.displayIndex(forRow: 0) == nil)
            #expect(app.excerpt.tableRowStore.snapshot.displayIndex(forRow: 1) == 1)
        }
    }

    @Test
    func activeSearchOrFilterActionUnfreezesExcerptTableAfterIndexedContentMutation() async throws {
        try await withExcerptTestApp { app, database in
            try indexExcerptVideo("Episode1", in: database)
            try indexExcerptVideo("Episode2", in: database)
            let excerptDB = try #require(app.excerptDatabase)
            let list = try excerptDB.createExcerptList(name: "FreezeList", description: "")
            let cue1 = try #require(try SearchDatabase(path: database.path).search("Episode1").first)
            let cue2 = try #require(try SearchDatabase(path: database.path).search("Episode2").first)
            _ = try excerptDB.upsertExcerpt(cueID: cue1.entryID, listID: list.id)
            _ = try excerptDB.upsertExcerpt(cueID: cue2.entryID, listID: list.id)

            app.excerpt.setActiveListID(list.id)
            app.reloadExcerptTableRows()
            await app.excerptTableRowsTask?.value
            #expect(app.excerpt.tableRowStore.snapshot.unavailableRows.isEmpty)

            // Background mutation makes Episode1 unavailable while page is frozen
            app.prepareExcerptForIndexedContentMutation(under: [URL(fileURLWithPath: "/Media")])
            try database.replaceEntries(
                subtitleFile: URL(fileURLWithPath: "/Media/Episode1.srt"),
                videoFile: URL(fileURLWithPath: "/Media/Episode1.mkv"),
                entries: []
            )
            app.reloadExcerptAfterIndexedContentMutation()
            #expect(app.excerptNeedsReloadAfterIndexedContentMutation == true)
            #expect(app.excerpt.tableRowStore.snapshot.unavailableRows.isEmpty)

            // Active search input unfreezes and pulls latest DB state
            app.updateExcerptSearchQuery("placeholder")
            await app.excerptTableRowsTask?.value
            await app.excerptListOverviewTask?.value

            #expect(app.excerptNeedsReloadAfterIndexedContentMutation == false)
            #expect(app.excerpt.tableRowStore.snapshot.unavailableRows == [0])
        }
    }

    @Test
    func removingExcerptWhileFrozenAdjustsCountByDisplayedValidityAndPreservesFrozenState() async throws {
        try await withExcerptTestApp { app, database in
            try indexExcerptVideo("Episode1", in: database)
            try indexExcerptVideo("Episode2", in: database)
            let excerptDB = try #require(app.excerptDatabase)
            let list = try excerptDB.createExcerptList(name: "FrozenRemoveList", description: "")
            let cue1 = try #require(try SearchDatabase(path: database.path).search("Episode1").first)
            let cue2 = try #require(try SearchDatabase(path: database.path).search("Episode2").first)
            let saved1 = try excerptDB.upsertExcerpt(cueID: cue1.entryID, listID: list.id)
            let saved2 = try excerptDB.upsertExcerpt(cueID: cue2.entryID, listID: list.id)

            // Make saved1 already unavailable before opening the page
            try database.replaceEntries(
                subtitleFile: URL(fileURLWithPath: "/Media/Episode1.srt"),
                videoFile: URL(fileURLWithPath: "/Media/Episode1.mkv"),
                entries: []
            )

            app.excerpt.setActiveListID(list.id)
            app.reloadExcerptTableRows()
            await app.excerptTableRowsTask?.value
            app.reloadExcerptListOverview()
            await app.excerptListOverviewTask?.value

            #expect(app.excerpt.listOverview.lists.first(where: { $0.id == list.id })?.cueCount == 1)

            // Freeze page and make saved2 unavailable in background
            app.prepareExcerptForIndexedContentMutation(under: [URL(fileURLWithPath: "/Media")])
            try database.replaceEntries(
                subtitleFile: URL(fileURLWithPath: "/Media/Episode2.srt"),
                videoFile: URL(fileURLWithPath: "/Media/Episode2.mkv"),
                entries: []
            )
            app.reloadExcerptAfterIndexedContentMutation()

            // Removing saved1 (already displayed as unavailable) does not decrement valid count
            let displayedUnavailable = try #require(app.excerpt.tableRowStore.snapshot.excerpt(entryID: Int(saved1.id)))
            #expect(!displayedUnavailable.isValid)
            #expect(app.removeExcerpt(displayedUnavailable, reloadPresentation: false))
            await app.excerptMutationTask?.value
            #expect(app.excerpt.listOverview.lists.first(where: { $0.id == list.id })?.cueCount == 1)
            #expect(app.excerptNeedsReloadAfterIndexedContentMutation == true)

            // Removing saved2 (displayed as valid on frozen screen) decrements valid count by 1
            let displayedValid = try #require(app.excerpt.tableRowStore.snapshot.excerpt(entryID: Int(saved2.id)))
            #expect(displayedValid.isValid)
            #expect(app.removeExcerpt(displayedValid, reloadPresentation: false))
            await app.excerptMutationTask?.value
            #expect(app.excerpt.listOverview.lists.first(where: { $0.id == list.id })?.cueCount == 0)
            #expect(app.excerptNeedsReloadAfterIndexedContentMutation == true)
        }
    }

    @Test
    func openingExcerptListPlaybackWhenAllCuesAreUnavailableShowsNotInLibraryError() async throws {
        try await withExcerptTestApp { app, database in
            app.ensurePlayerInitialized()
            try indexExcerptVideo("Episode1", in: database)
            let excerptDB = try #require(app.excerptDatabase)
            let list = try excerptDB.createExcerptList(name: "AllUnavailablePlayback", description: "")
            let cue = try #require(try SearchDatabase(path: database.path).search("Episode1").first)
            _ = try excerptDB.upsertExcerpt(cueID: cue.entryID, listID: list.id)

            app.reloadExcerptListOverview()
            await app.excerptListOverviewTask?.value
            let frozenSummary = try #require(app.excerpt.listOverview.lists.first(where: { $0.id == list.id }))

            // Background mutation removes Episode1 while summary is still displayed on frozen page
            try database.replaceEntries(
                subtitleFile: URL(fileURLWithPath: "/Media/Episode1.srt"),
                videoFile: URL(fileURLWithPath: "/Media/Episode1.mkv"),
                entries: []
            )

            app.openExcerptListPlayback(frozenSummary)

            #expect(app.currentPlaybackItemLeftLibrary == true)
            #expect(app.playback.playbackStatus == .loadFailed)
            #expect(app.playback.errorMessages[.notInLibrary] == "This item is no longer in the library")
            #expect(app.playback.isPlaybackSurfaceExpanded == true)
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
    let userDefaults = try #require(UserDefaults.temporary(suiteName: suiteName))
    let databaseURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerExcerptTestApp-\(UUID().uuidString)")
        .appendingPathExtension("sqlite")
    defer {
        userDefaults.removePersistentDomainAndPlist(forName: suiteName)
        removeTemporaryDatabase(at: databaseURL)
        try? FileManager.default.removeItem(atPath: databaseURL.path + "-wal")
        try? FileManager.default.removeItem(atPath: databaseURL.path + "-shm")
    }

    _ = NSApplication.shared
    let app = AppCoordinator(userDefaults: userDefaults, databaseURL: databaseURL)
    await app.startupDatabaseTask?.value
    let database = try #require(app.indexingDatabase)
    try await body(app, database)
}
