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

    @Test
    func batchSaveMoveDuplicateAndRemoveExcerptsHandlePartialDuplicatesStrictSkipAndSelectionRemap() async throws {
        try await withExcerptTestApp { app, database in
            try indexExcerptVideo("Episode1", in: database)
            try indexExcerptVideo("Episode2", in: database)
            try indexExcerptVideo("Episode3", in: database)
            let excerptDB = try #require(app.excerptDatabase)
            let listA = try excerptDB.createExcerptList(name: "ListA", description: "")
            let listB = try excerptDB.createExcerptList(name: "ListB", description: "")
            let listC = try excerptDB.createExcerptList(name: "ListC", description: "")

            let searchDB = try SearchDatabase(path: database.path)
            let cue1 = try #require(try searchDB.search("Episode1").first)
            let cue2 = try #require(try searchDB.search("Episode2").first)
            let cue3 = try #require(try searchDB.search("Episode3").first)

            app.reloadExcerptListOverview()
            await app.excerptListOverviewTask?.value

            // 1. Batch save cue1, cue2, cue3 to ListA
            #expect(app.saveExcerpts(
                cueIDs: [cue1.entryID, cue2.entryID, cue3.entryID],
                toListID: listA.id,
                listName: listA.name
            ))
            await app.excerptMutationTask?.value
            #expect(app.toast.visibleItems.last?.request == ExcerptToastRequest.saveSucceeded(listName: listA.name))
            #expect(try excerptDB.excerptRelations(listID: listA.id).map(\.cueID) == [cue1.entryID, cue2.entryID, cue3.entryID])

            // Saving the exact same 3 cues again to ListA shows already-exists warning
            #expect(!app.saveExcerpts(
                cueIDs: [cue1.entryID, cue2.entryID, cue3.entryID],
                toListID: listA.id,
                listName: listA.name
            ))
            #expect(app.toast.visibleItems.last?.request == ExcerptToastRequest.destinationAlreadyContainsCue(listName: listA.name))

            // Pre-populate cue2 into ListB so moving [cue1, cue2, cue3] from ListA -> ListB has a partial duplicate
            _ = try excerptDB.upsertExcerpt(cueID: cue2.entryID, listID: listB.id)
            app.reloadExcerptListOverview()
            await app.excerptListOverviewTask?.value

            app.excerpt.setActiveListID(listA.id)
            app.reloadExcerptTableRows()
            await app.excerptTableRowsTask?.value

            let itemsInA = try excerptDB.excerpts(listID: listA.id)
            #expect(itemsInA.count == 3)

            // Select all 3 rows in ListA
            var selection = TableSandboxRowSelectionState()
            selection.toggleAll(rowCount: 3)
            app.excerpt.tableSelectionState = selection
            app.excerpt.tableSelectionEntryIDs = app.excerpt.tableRowStore.snapshot.orderedEntryIDs

            // 2. Batch duplicate [item1, item2] to ListB -> partial duplicate succeeds and skips item2
            #expect(app.duplicateExcerpts(
                [itemsInA[0], itemsInA[1]],
                toListID: listC.id,
                listName: listC.name
            ))
            await app.excerptMutationTask?.value
            #expect(app.toast.visibleItems.last?.request == ExcerptToastRequest.duplicateSucceeded(listName: listC.name))
            #expect(try excerptDB.excerptRelations(listID: listC.id).map(\.cueID) == [cue1.entryID, cue2.entryID])

            // 3. Batch move all 3 items from ListA to ListB -> strict skip keeps cue2 in ListA and checked at row 0!
            #expect(app.moveExcerpts(
                itemsInA,
                toListID: listB.id,
                listName: listB.name
            ))
            await app.excerptMutationTask?.value
            #expect(app.toast.visibleItems.last?.request == ExcerptToastRequest.moveSucceeded(listName: listB.name))
            #expect(try excerptDB.excerptRelations(listID: listA.id).map(\.cueID) == [cue2.entryID])
            #expect(try excerptDB.excerptRelations(listID: listB.id).map(\.cueID) == [cue2.entryID, cue1.entryID, cue3.entryID])

            // Remaining row in ListA (cue2) stays checked at its new row index 0
            #expect(app.excerpt.tableRowStore.snapshot.totalRowCount == 1)
            #expect(app.excerpt.tableSelectionState.selectedRows(rowCount: 1) == [0])

            // Attempting to move the remaining duplicate item to ListB again shows already-exists warning and leaves it in ListA
            let survivingItem = try #require(try excerptDB.excerpts(listID: listA.id).first)
            #expect(!app.moveExcerpts(
                [survivingItem],
                toListID: listB.id,
                listName: listB.name
            ))
            #expect(app.toast.visibleItems.last?.request == ExcerptToastRequest.destinationAlreadyContainsCue(listName: listB.name))
            #expect(try excerptDB.excerptRelations(listID: listA.id).count == 1)

            // 4. Batch remove from ListB removes all items and clears selection
            app.excerpt.setActiveListID(listB.id)
            app.reloadExcerptTableRows()
            await app.excerptTableRowsTask?.value
            let itemsInB = try excerptDB.excerpts(listID: listB.id)
            #expect(itemsInB.count == 3)

            var selectionB = TableSandboxRowSelectionState()
            selectionB.toggleAll(rowCount: 3)
            app.excerpt.tableSelectionState = selectionB
            app.excerpt.tableSelectionEntryIDs = app.excerpt.tableRowStore.snapshot.orderedEntryIDs

            #expect(app.removeExcerpts(itemsInB, reloadPresentation: false))
            await app.excerptMutationTask?.value
            #expect(try excerptDB.excerptRelations(listID: listB.id).isEmpty)
            #expect(app.excerpt.tableRowStore.snapshot.totalRowCount == 0)
            #expect(app.excerpt.tableSelectionState.selectedCount(rowCount: 0) == 0)
        }
    }

    @Test
    func batchNewListPendingTransferSavesOrMovesSelectedItemsToNewlyCreatedList() async throws {
        try await withExcerptTestApp { app, database in
            try indexExcerptVideo("Episode1", in: database)
            try indexExcerptVideo("Episode2", in: database)
            let excerptDB = try #require(app.excerptDatabase)
            let searchDB = try SearchDatabase(path: database.path)
            let cue1 = try #require(try searchDB.search("Episode1").first)
            let cue2 = try #require(try searchDB.search("Episode2").first)

            app.reloadExcerptListOverview()
            await app.excerptListOverviewTask?.value

            // Create new list from batch Save to Excerpt List (.cues)
            app.beginCreatingExcerptList(
                pendingTransfer: ExcerptListEditorPendingTransfer(
                    action: .saveToExcerpt,
                    target: .cues([cue1.entryID, cue2.entryID])
                )
            )
            let session = try #require(app.excerpt.listEditorSession)
            session.name = "BatchSavedList"
            app.saveExcerptListEditor(session)
            await app.excerptListSaveTask?.value
            await app.excerptMutationTask?.value

            let savedList = try #require(try excerptDB.excerptLists().first(where: { $0.name == "BatchSavedList" }))
            #expect(try excerptDB.excerptRelations(listID: savedList.id).map(\.cueID) == [cue1.entryID, cue2.entryID])

            // Create new list from batch Move to ... (.excerpts)
            let savedItems = try excerptDB.excerpts(listID: savedList.id)
            app.excerpt.setActiveListID(savedList.id)
            app.reloadExcerptTableRows()
            await app.excerptTableRowsTask?.value

            app.beginCreatingExcerptList(
                pendingTransfer: ExcerptListEditorPendingTransfer(
                    action: .moveToList,
                    target: .excerpts(savedItems)
                )
            )
            let moveSession = try #require(app.excerpt.listEditorSession)
            moveSession.name = "BatchMovedList"
            app.saveExcerptListEditor(moveSession)
            await app.excerptListSaveTask?.value
            await app.excerptMutationTask?.value

            let movedList = try #require(try excerptDB.excerptLists().first(where: { $0.name == "BatchMovedList" }))
            #expect(try excerptDB.excerptRelations(listID: savedList.id).isEmpty)
            #expect(try excerptDB.excerptRelations(listID: movedList.id).map(\.cueID) == [cue1.entryID, cue2.entryID])
        }
    }

    @Test
    func selectionToolbarActionsAndWrappingHeightFollowSpec() {
        let searchActions = SchemaWorkbenchSelectionAction.searchActions(
            exportToAnki: {},
            copyDeepLinks: {},
            copyTable: {},
            saveDestinations: [],
            saveToExcerptList: { _ in },
            createListForSave: {}
        )
        #expect(searchActions.map(\.id) == ["anki", "copy-deep-links", "copy-table", "save-to-excerpt"])
        #expect(searchActions.map(\.keyLabel) == ["A", "D", "T", "S"])
        #expect(searchActions.last?.destinationMenu != nil)

        let excerptActions = SchemaWorkbenchSelectionAction.excerptActions(
            exportToAnki: {},
            copyDeepLinks: {},
            copyTable: {},
            destinations: [],
            moveToExcerptList: { _ in },
            createListForMove: {},
            duplicateToExcerptList: { _ in },
            createListForDuplicate: {},
            removeExcerpts: {}
        )
        #expect(excerptActions.map(\.id) == ["anki", "copy-deep-links", "copy-table", "move-to", "duplicate-to", "remove-excerpt"])
        #expect(excerptActions.map(\.keyLabel) == ["A", "D", "T", "M", "C", "R"])
        #expect(excerptActions.last?.style == .destructive)

        let wideHeight = SchemaWorkbenchStyle.pinnedToolbarHeight(
            forWidth: 1_400,
            isSelectionMode: true,
            selectionActions: excerptActions
        )
        let narrowHeight = SchemaWorkbenchStyle.pinnedToolbarHeight(
            forWidth: 420,
            isSelectionMode: true,
            selectionActions: excerptActions
        )
        #expect(wideHeight == SchemaWorkbenchStyle.pinnedToolbarHeight)
        #expect(narrowHeight > wideHeight)
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
