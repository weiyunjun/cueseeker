import AppKit
import Foundation
import Testing
@testable import CueSeekerCore
@testable import CueSeekerApp

private enum LibraryFolderRemovalTestError: Error {
    case expected
}

/// A removal the test releases by hand.
///
/// Starting is an event rather than a flag a test polls against a clock, and a
/// `finish()` that arrives before the removal does is remembered instead of
/// lost — otherwise the removal would wait for it forever.
private actor ControlledLibraryFolderRemovalExecutor: LibraryFolderRemovalExecuting {
    enum Outcome {
        case success
        case emptySuccess
        case failure
    }

    private let outcome: Outcome
    private var started = false
    private var finished = false
    private var startWaiters: [CheckedContinuation<Void, Never>] = []
    private var continuation: CheckedContinuation<Void, Never>?
    private(set) var removals: [(folder: URL, nestedRoots: [URL])] = []

    init(outcome: Outcome = .success) {
        self.outcome = outcome
    }

    @discardableResult
    func removeFolder(_ folder: URL, keepingNestedRoots nestedRoots: [URL], databaseURL: URL) async throws -> Bool {
        started = true
        removals.append((folder, nestedRoots))
        startWaiters.forEach { $0.resume() }
        startWaiters = []
        if !finished {
            await withCheckedContinuation { continuation in
                self.continuation = continuation
            }
        }

        if outcome == .failure {
            throw LibraryFolderRemovalTestError.expected
        }
        return outcome == .success
    }

    func hasStarted() -> Bool {
        started
    }

    func waitUntilStarted() async {
        guard !started else {
            return
        }
        await withCheckedContinuation { startWaiters.append($0) }
    }

    func finish() {
        finished = true
        continuation?.resume()
        continuation = nil
    }
}

@MainActor
@Test
func libraryFolderRemovalPublishesProgressWithoutBlockingMainActor() async throws {
    let fixture = try LibraryFolderRemovalTestFixture()
    defer { fixture.cleanUp() }

    let executor = ControlledLibraryFolderRemovalExecutor()
    let app = fixture.makeApp(executor: executor)

    app.removeFolder(fixture.folder)
    try await waitUntilLibraryFolderRemovalStarts(executor)

    #expect(app.indexing.folderRemovalStatus == .removing(fixture.folder))
    #expect(app.indexing.removedFolderNotice == nil)
    #expect(app.indexing.selectedFolders == [fixture.folder])
    #expect(app.tasks.hasLibraryTask)
    #expect(!app.canCompactDatabase)

    let mainActorProbe = Task { @MainActor in true }
    #expect(await mainActorProbe.value)

    await executor.finish()
    await app.tasks.waitUntilIdle()

    #expect(app.indexing.folderRemovalStatus == .idle)
    #expect(app.indexing.removedFolderNotice == fixture.folder)
    #expect(app.indexing.selectedFolders.isEmpty)
    #expect(app.tasks.current.isEmpty)
    #expect(app.tasks.completed.map(\.kind) == [.removeFolder])
}

@MainActor
@Test
func libraryFolderRemovalExecutorCommitsTargetedDatabaseDeletion() async throws {
    let fixture = try LibraryFolderRemovalTestFixture()
    defer { fixture.cleanUp() }

    try DatabaseBootstrap.prepare(at: fixture.databaseURL)
    let database = try IndexingDatabase(path: fixture.databaseURL)
    _ = try database.addSearchPath(fixture.folder)
    try database.replaceEntries(
        subtitleFile: fixture.folder.appendingPathComponent("Episode.srt"),
        videoFile: fixture.folder.appendingPathComponent("Episode.mkv"),
        entries: [
            SubtitleEntry(
                sequenceNumber: 1,
                startTimecode: "00:00:01,000",
                endTimecode: "00:00:02,000",
                startMilliseconds: 1_000,
                endMilliseconds: 2_000,
                text: "Actual folder removal executor"
            )
        ]
    )

    _ = NSApplication.shared
    let app = AppCoordinator(
        userDefaults: fixture.userDefaults,
        databaseURL: fixture.databaseURL
    )
    app.removeFolder(fixture.folder)
    await app.tasks.waitUntilIdle()
    await app.databaseStorageStatsTask?.value

    #expect(app.indexing.folderRemovalStatus == .idle)
    #expect(app.indexing.removedFolderNotice == fixture.folder)
    #expect(app.indexing.selectedFolders.isEmpty)
    #expect(try app.search.database?.search("Actual").isEmpty == true)
}

@MainActor
@Test
func libraryFolderRemovalKeepsUnavailableExcerptAndClearsCanonicalCueContent() async throws {
    let fixture = try LibraryFolderRemovalTestFixture()
    defer { fixture.cleanUp() }

    try DatabaseBootstrap.prepare(at: fixture.databaseURL)
    let database = try IndexingDatabase(path: fixture.databaseURL)
    _ = try database.addSearchPath(fixture.folder)
    let subtitleFile = fixture.folder.appendingPathComponent("Saved Episode.srt")
    let videoFile = fixture.folder.appendingPathComponent("Saved Episode.mkv")
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
                text: "Resident Excerpt must remain unavailable"
            ),
        ]
    )
    let selection = try #require(try PlaybackSubtitleDatabase(path: database.path).cueTextSelection(
        forSubtitleFile: subtitleFile,
        atMilliseconds: 1_500
    ))
    let cueID = try #require(selection.cueLineID)
    _ = try ExcerptDatabase(path: database.path).upsertExcerpt(
        selection: selection
    )

    _ = NSApplication.shared
    let app = AppCoordinator(
        userDefaults: fixture.userDefaults,
        databaseURL: fixture.databaseURL
    )
    app.reloadExcerptTableRows()
    await app.excerptTableRowsTask?.value
    #expect(app.excerpt.residentRelations.map(\.cueID) == [cueID])
    #expect(app.excerpt.tableRowStore.snapshot.totalRowCount == 1)
    #expect(app.cueContent.content(for: cueID) != nil)

    app.removeFolder(fixture.folder)
    await app.tasks.waitUntilIdle()
    #expect(app.excerptNeedsReloadAfterIndexedContentMutation == true)
    app.refreshExcerptOnReappearanceIfNeeded()
    await app.excerptTableRowsTask?.value

    #expect(app.excerpt.residentRelations.map(\.cueID) == [cueID])
    #expect(app.excerpt.tableRowStore.snapshot.totalRowCount == 1)
    #expect(
        app.excerpt.tableRowStore.snapshot.row(at: 0)?.cueState
            == .unavailable(.libraryUnavailable)
    )
    #expect(app.cueContent.content(for: cueID) == nil)
}

/// Only one library task exists at a time: while a removal runs, Index Now,
/// Add Folder and another removal are not taken, and none of them queues.
@MainActor
@Test
func aRunningFolderRemovalRefusesOtherLibraryTasks() async throws {
    let fixture = try LibraryFolderRemovalTestFixture()
    defer { fixture.cleanUp() }

    let executor = ControlledLibraryFolderRemovalExecutor()
    let app = fixture.makeApp(executor: executor)

    app.removeFolder(fixture.folder)
    try await waitUntilLibraryFolderRemovalStarts(executor)

    app.indexAllFolders()
    app.addFolder(URL(fileURLWithPath: "/Media/Other Folder"))
    app.removeFolder(fixture.folder)
    #expect(app.tasks.current.map(\.record.kind) == [.removeFolder])
    #expect(app.indexing.indexingStatus == .idle)

    // One transaction: it cannot be stopped once it has begun.
    let running = try #require(app.tasks.current.first)
    app.tasks.removeCurrentTask(id: running.id)
    #expect(app.tasks.current.map(\.id) == [running.id])

    await executor.finish()
    await app.tasks.waitUntilIdle()
    #expect(app.tasks.completed.map(\.kind) == [.removeFolder])
    #expect(app.indexing.selectedFolders.isEmpty)
}

/// A root that another root still holds leaves the list and nothing else: the
/// root holding it keeps indexing what it holds.
@MainActor
@Test
func removingARootAnotherRootHoldsChangesNothingIndexed() async throws {
    let fixture = try LibraryFolderRemovalTestFixture()
    defer { fixture.cleanUp() }

    let child = fixture.folder.appendingPathComponent("Season 1")
    fixture.userDefaults.set([child.path, fixture.folder.path], forKey: "selectedFolderPaths")
    let executor = ControlledLibraryFolderRemovalExecutor()
    let app = fixture.makeApp(executor: executor)

    app.removeFolder(child)
    await app.tasks.waitUntilIdle()

    #expect(await !executor.hasStarted())
    #expect(app.indexing.selectedFolders == [fixture.folder])
    #expect(app.indexing.removedFolderNotice == child)
    #expect(app.tasks.completed.map(\.kind) == [.removeFolder])
}

/// Removing a root that holds other roots keeps what lies inside them.
@MainActor
@Test
func removingARootKeepsTheRootsItHolds() async throws {
    let fixture = try LibraryFolderRemovalTestFixture()
    defer { fixture.cleanUp() }

    let child = fixture.folder.appendingPathComponent("Season 1").standardizedFileURL
    let grandchild = child.appendingPathComponent("Extras").standardizedFileURL
    fixture.userDefaults.set(
        [grandchild.path, fixture.folder.path, child.path],
        forKey: "selectedFolderPaths"
    )
    let executor = ControlledLibraryFolderRemovalExecutor()
    let app = fixture.makeApp(executor: executor)

    app.removeFolder(fixture.folder)
    await executor.finish()
    await app.tasks.waitUntilIdle()

    let removals = await executor.removals
    #expect(removals.map(\.folder) == [fixture.folder])
    #expect(removals.first?.nestedRoots == [child])
    #expect(app.indexing.selectedFolders == [grandchild, child])
}

@MainActor
@Test
func failedLibraryFolderRemovalPreservesFolderAndPresentationState() async throws {
    let fixture = try LibraryFolderRemovalTestFixture()
    defer { fixture.cleanUp() }

    let executor = ControlledLibraryFolderRemovalExecutor(outcome: .failure)
    let app = fixture.makeApp(executor: executor)
    let existingVideo = LibraryVideo(
        videoPath: fixture.folder.appendingPathComponent("Episode.mkv").path,
        videoName: "Episode.mkv",
        duration: 1_200,
        subtitlePath: fixture.folder.appendingPathComponent("Episode.srt").path,
        subtitleFormat: .srt
    )
    app.library.libraryVideos = [existingVideo]
    app.library.selectedLibraryVideo = existingVideo

    app.removeFolder(fixture.folder)
    try await waitUntilLibraryFolderRemovalStarts(executor)

    #expect(app.indexing.selectedFolders == [fixture.folder])
    #expect(app.library.libraryVideos == [existingVideo])
    #expect(app.library.selectedLibraryVideo == existingVideo)
    await executor.finish()
    await app.tasks.waitUntilIdle()

    #expect(app.indexing.folderRemovalStatus == .idle)
    #expect(app.indexing.removedFolderNotice == nil)
    #expect(app.indexing.selectedFolders == [fixture.folder])
    #expect(app.library.libraryVideos == [existingVideo])
    #expect(app.library.selectedLibraryVideo == existingVideo)
    #expect(app.startupError?.contains("Failed to remove folder index") == true)
    #expect(app.tasks.current.isEmpty)
    #expect(app.tasks.incomplete.map(\.kind) == [.removeFolder])
    #expect(
        app.tasks.incomplete.first?.errorMessage?
            .contains("Failed to remove folder index") == true
    )
}

@MainActor
@Test
func indexedCueMutationFailureRecoveryReloadsPrunedResidentSearch() async throws {
    let fixture = try LibraryFolderRemovalTestFixture()
    defer { fixture.cleanUp() }

    try DatabaseBootstrap.prepare(at: fixture.databaseURL)
    let database = try IndexingDatabase(path: fixture.databaseURL)
    _ = try database.addSearchPath(fixture.folder)
    try database.replaceEntries(
        subtitleFile: fixture.folder.appendingPathComponent("Episode.srt"),
        videoFile: fixture.folder.appendingPathComponent("Episode.mkv"),
        entries: [
            SubtitleEntry(
                sequenceNumber: 1,
                startTimecode: "00:00:01,000",
                endTimecode: "00:00:02,000",
                startMilliseconds: 1_000,
                endMilliseconds: 2_000,
                text: "Reload pruned resident Search result"
            ),
        ]
    )

    let app = fixture.makeApp(executor: ControlledLibraryFolderRemovalExecutor())
    app.submitSearch("Reload pruned")
    await app.search.searchTask?.value
    app.search.activateResidentSearchTableProjection()
    let originalCueIDs = app.search.searchResultCueIDs
    try #require(originalCueIDs.count == 1)

    app.clearSearchAndPlaybackState(under: fixture.folder)
    #expect(app.search.searchResultCueIDs == originalCueIDs)
    #expect(app.search.tableRowStore.snapshot.totalRowCount == 1)

    app.restoreCurrentSearchAfterIndexedCueMutationFailure(reloadFromDatabase: false)

    #expect(app.search.searchResultCueIDs == originalCueIDs)
    #expect(app.search.tableRowStore.snapshot.orderedEntryIDs
        == originalCueIDs.map(Int.init))
    #expect(app.search.tableRowStore.snapshot.row(at: 0)?.primaryCueText
        == "Reload pruned resident Search result")
}

@MainActor
@Test
func libraryFolderRemovalNoticeClearsWhenIndexingStarts() async throws {
    let fixture = try LibraryFolderRemovalTestFixture()
    defer { fixture.cleanUp() }

    let app = fixture.makeApp(executor: ControlledLibraryFolderRemovalExecutor())
    app.indexing.removedFolderNotice = fixture.folder

    app.indexAllFolders()

    #expect(app.indexing.removedFolderNotice == nil)
    await app.tasks.waitUntilIdle()
}

@MainActor
@Test
func unchangedFolderIndexPreservesLoadedSearchState() async throws {
    _ = NSApplication.shared
    let suiteName = "CueSeekerIncrementalIndexTests-\(UUID().uuidString)"
    let userDefaults = try #require(UserDefaults.temporary(suiteName: suiteName))
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "CueSeekerIncrementalIndexTests-\(UUID().uuidString)",
            isDirectory: true
        )
    let databaseURL = root.appendingPathComponent("CueSeeker.sqlite")
    let subtitleURL = root.appendingPathComponent("Episode.srt")
    let videoURL = root.appendingPathComponent("Episode.mkv")
    try FileManager.default.createDirectory(
        at: root,
        withIntermediateDirectories: true
    )
    try """
    1
    00:00:01,000 --> 00:00:03,000
    Stable incremental search text.

    """.write(to: subtitleURL, atomically: true, encoding: .utf8)
    try Data([0]).write(to: videoURL)
    defer {
        userDefaults.removePersistentDomainAndPlist(forName: suiteName)
        try? FileManager.default.removeItem(at: root)
    }

    try DatabaseBootstrap.prepare(at: databaseURL)
    let indexingDatabase = try IndexingDatabase(path: databaseURL)
    _ = try SubtitleIndexer().index(
        folder: root,
        into: indexingDatabase
    )
    userDefaults.set([root.path], forKey: "selectedFolderPaths")
    let app = AppCoordinator(
        userDefaults: userDefaults,
        databaseURL: databaseURL
    )
    app.submitSearch("incremental")
    await app.search.searchTask?.value
    let cueIDsBefore = app.search.searchResultCueIDs
    let revisionBefore = app.search.indexedCueDataRevision
    try #require(!cueIDsBefore.isEmpty)

    app.indexAllFolders()
    await app.tasks.waitUntilIdle()

    guard case let .completedAll(_, result) = app.indexing.indexingStatus else {
        Issue.record(
            "Expected completed unchanged Index, got \(app.indexing.indexingStatus)"
        )
        return
    }
    #expect(!result.hasIndexedContentChanges)
    #expect(app.search.indexedCueDataRevision == revisionBefore)
    #expect(app.search.searchResultCueIDs == cueIDsBefore)
}

@MainActor
@Test
func libraryFolderRemovalPreservesSearchStoreResultsAndCueContent() async throws {
    let fixture = try LibraryFolderRemovalTestFixture()
    defer { fixture.cleanUp() }

    try DatabaseBootstrap.prepare(at: fixture.databaseURL)
    let database = try IndexingDatabase(path: fixture.databaseURL)
    _ = try database.addSearchPath(fixture.folder)
    let subtitleFile = fixture.folder.appendingPathComponent("Search Preserved Episode.srt")
    let videoFile = fixture.folder.appendingPathComponent("Search Preserved Episode.mkv")
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
                text: "Retained search result across folder removal"
            ),
        ]
    )

    _ = NSApplication.shared
    let app = AppCoordinator(
        userDefaults: fixture.userDefaults,
        databaseURL: fixture.databaseURL
    )
    app.submitSearch("Retained")
    await app.search.searchTask?.value
    app.search.activateResidentSearchTableProjection()

    #expect(!app.search.searchResults.isEmpty)
    let cueID = try #require(app.search.searchResults.first?.entryID)
    #expect(app.search.cachedCueContent(for: cueID) != nil)
    #expect(app.search.tableRowStore.snapshot.totalRowCount == 1)
    #expect(app.search.tableRowStore.snapshot.row(at: 0)?.primaryCueText == "Retained search result across folder removal")

    app.removeFolder(fixture.folder)
    await app.tasks.waitUntilIdle()

    // Excerpt cue content store was purged of the removed folder's content
    #expect(app.cueContent.content(for: cueID) == nil)
    // Search store's isolated cue content cache and table rows remain fully populated
    #expect(!app.search.searchResults.isEmpty)
    #expect(app.search.cachedCueContent(for: cueID) != nil)
    #expect(app.search.tableRowStore.snapshot.totalRowCount == 1)
    #expect(app.search.tableRowStore.snapshot.row(at: 0)?.primaryCueText == "Retained search result across folder removal")
}

@MainActor
@Test
func addingOrRemovingEmptyFolderDoesNotMarkDeferredPageRefreshes() async throws {
    _ = NSApplication.shared
    let suiteName = "CueSeekerEmptyFolderOutcomeTests-\(UUID().uuidString)"
    let userDefaults = try #require(UserDefaults.temporary(suiteName: suiteName))
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "CueSeekerEmptyFolderOutcomeTests-\(UUID().uuidString)",
            isDirectory: true
        )
    let mediaFolder = root.appendingPathComponent("Media", isDirectory: true).standardizedFileURL
    let emptyFolder = root.appendingPathComponent("EmptyFolder", isDirectory: true).standardizedFileURL
    let databaseURL = root.appendingPathComponent("CueSeeker.sqlite")
    try FileManager.default.createDirectory(at: mediaFolder, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: emptyFolder, withIntermediateDirectories: true)
    defer {
        userDefaults.removePersistentDomainAndPlist(forName: suiteName)
        try? FileManager.default.removeItem(at: root)
    }

    let subtitleURL = mediaFolder.appendingPathComponent("Episode 01.srt")
    let videoURL = mediaFolder.appendingPathComponent("Episode 01.mkv")
    try """
    1
    00:00:01,000 --> 00:00:03,000
    Outcome based refresh line.

    """.write(to: subtitleURL, atomically: true, encoding: .utf8)
    try Data([0]).write(to: videoURL)

    try DatabaseBootstrap.prepare(at: databaseURL)
    let indexingDatabase = try IndexingDatabase(path: databaseURL)
    _ = try SubtitleIndexer().index(folder: mediaFolder, into: indexingDatabase)
    userDefaults.set([mediaFolder.path], forKey: "selectedFolderPaths")

    let app = AppCoordinator(userDefaults: userDefaults, databaseURL: databaseURL)
    app.submitSearch("Outcome")
    await app.search.searchTask?.value
    #expect(app.search.searchResultTotalCount == 1)

    // Add an empty folder while staying on File Level 2 of mediaFolder
    app.navigateWorkbench(to: .fileFolder(rootPath: mediaFolder.mediaPath))
    app.addFolder(emptyFolder)
    await app.tasks.waitUntilIdle()

    #expect(app.indexing.selectedFolders.contains(emptyFolder))
    #expect(app.search.pendingReappearanceRefreshMode == .none)
    #expect(app.recentNeedsReloadAfterIndexedMutation == false)
    #expect(app.libraryNeedsReloadAfterIndexedMutation == false)
    #expect(app.excerptNeedsReloadAfterIndexedContentMutation == false)
    #expect(app.fileNeedsReloadAfterIndexedMutation == false)

    // Remove the empty folder while staying on mediaFolder's File Level 2
    app.removeFolder(emptyFolder)
    await app.tasks.waitUntilIdle()

    #expect(!app.indexing.selectedFolders.contains(emptyFolder))
    #expect(app.search.pendingReappearanceRefreshMode == .none)
    #expect(app.recentNeedsReloadAfterIndexedMutation == false)
    #expect(app.libraryNeedsReloadAfterIndexedMutation == false)
    #expect(app.excerptNeedsReloadAfterIndexedContentMutation == false)
    #expect(app.fileNeedsReloadAfterIndexedMutation == false)
    #expect(app.heldWorkbenchRoute == nil)

    // Add the empty folder again, navigate into emptyFolder's File Level 2, and remove it
    app.addFolder(emptyFolder)
    await app.tasks.waitUntilIdle()
    let emptyFolderRoute = WorkbenchRoute.fileFolder(rootPath: emptyFolder.mediaPath)
    app.navigateWorkbench(to: emptyFolderRoute)
    app.removeFolder(emptyFolder)
    await app.tasks.waitUntilIdle()

    // While staying on emptyFolder's File Level 2, the route stays held (not unknown)
    #expect(app.heldWorkbenchRoute == emptyFolderRoute)
    #expect(app.isWorkbenchRouteUnknown(emptyFolderRoute) == false)

    // Once the user navigates away, emptyFolder's File Level 2 becomes unknown on reappearance
    app.navigateWorkbench(to: .file)
    #expect(app.heldWorkbenchRoute == nil)
    #expect(app.isWorkbenchRouteUnknown(emptyFolderRoute) == true)
}

@MainActor
@Test
func renameUpdatesFileSearchLibraryRecentAndExcerptInPlaceWithoutRerunningSearch() async throws {
    _ = NSApplication.shared
    let suiteName = "CueSeekerInPlaceRenameTests-\(UUID().uuidString)"
    let userDefaults = try #require(UserDefaults.temporary(suiteName: suiteName))
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "CueSeekerInPlaceRenameTests-\(UUID().uuidString)",
            isDirectory: true
        )
    let oldFolder = root.appendingPathComponent("Ave Mujica", isDirectory: true).standardizedFileURL
    let otherFolder = root.appendingPathComponent("MyGO!!!!!", isDirectory: true).standardizedFileURL
    let newFolder = root.appendingPathComponent("BanG Dream! Ave Mujica", isDirectory: true).standardizedFileURL
    let databaseURL = root.appendingPathComponent("CueSeeker.sqlite")
    try FileManager.default.createDirectory(at: oldFolder, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: otherFolder, withIntermediateDirectories: true)
    defer {
        userDefaults.removePersistentDomainAndPlist(forName: suiteName)
        try? FileManager.default.removeItem(at: root)
    }

    let subtitleURL = oldFolder.appendingPathComponent("Ave Mujica - 01.srt")
    let videoURL = oldFolder.appendingPathComponent("Ave Mujica - 01.mkv")
    try """
    1
    00:00:01,000 --> 00:00:03,000
    Welcome to the masquerade.

    """.write(to: subtitleURL, atomically: true, encoding: .utf8)
    try Data([0]).write(to: videoURL)

    let otherSubtitleURL = otherFolder.appendingPathComponent("MyGO - 01.srt")
    let otherVideoURL = otherFolder.appendingPathComponent("MyGO - 01.mkv")
    try """
    1
    00:00:01,000 --> 00:00:03,000
    Haruhikage.

    """.write(to: otherSubtitleURL, atomically: true, encoding: .utf8)
    try Data([0]).write(to: otherVideoURL)

    try DatabaseBootstrap.prepare(at: databaseURL)
    let indexingDatabase = try IndexingDatabase(path: databaseURL)
    _ = try SubtitleIndexer().index(folder: oldFolder, into: indexingDatabase)
    _ = try SubtitleIndexer().index(folder: otherFolder, into: indexingDatabase)
    let selection = try #require(
        try PlaybackSubtitleDatabase(path: databaseURL).cueTextSelection(
            forSubtitleFile: subtitleURL,
            atMilliseconds: 1_500
        )
    )
    _ = try ExcerptDatabase(path: databaseURL).upsertExcerpt(selection: selection)
    userDefaults.set([oldFolder.path, otherFolder.path], forKey: "selectedFolderPaths")

    let app = AppCoordinator(userDefaults: userDefaults, databaseURL: databaseURL)
    await app.startupDatabaseTask?.value
    app.reloadExcerptTableRows()
    await app.excerptTableRowsTask?.value
    app.submitSearch("masquerade")
    await app.search.searchTask?.value
    app.search.activateResidentSearchTableProjection()
    let searchGenerationBefore = app.search.resultListGeneration

    // Exclude oldFolder in Search and Excerpt facet filters so rewriting folder paths is exercised
    let initialFilter = CueFacetFilter(
        excludedFolders: [oldFolder.mediaPath]
    )
    app.settings.searchFacetFilter = initialFilter
    _ = app.search.updateSearchFacetFilter(initialFilter)
    app.settings.setExcerptFacetFilter(
        initialFilter,
        forListID: ExcerptListIdentity.defaultListID
    )
    _ = app.excerpt.updateTableFacetFilter(initialFilter)

    // Navigate to File Level 3 of oldFolder before renaming
    app.navigateWorkbench(
        to: .fileFiles(rootPath: oldFolder.mediaPath, folderPath: oldFolder.mediaPath)
    )

    // Rename folder "Ave Mujica" -> "BanG Dream! Ave Mujica"
    app.requestRootFolderRename(oldFolder)
    let session = try #require(app.library.renameSession)
    session.newName = "BanG Dream! Ave Mujica"
    app.confirmRename(session)
    await app.tasks.waitUntilIdle()

    // 1. File Level 3 route and loaded objects updated in place
    #expect(
        app.workbenchLayout.currentRoute == .fileFiles(
            rootPath: newFolder.mediaPath,
            folderPath: newFolder.mediaPath
        )
    )
    #expect(app.indexing.selectedFolders == [newFolder, otherFolder])
    #expect(
        app.library.fileObjects(for: newFolder.mediaPath).first?.displayTitle
            == "BanG Dream! Ave Mujica - 01"
    )

    // 2. Search updated in place without marking .rerunSearch or re-running search
    #expect(app.search.pendingReappearanceRefreshMode == .none)
    #expect(app.search.resultListGeneration == searchGenerationBefore)
    #expect(app.search.searchResults.first?.displayTitle == "BanG Dream! Ave Mujica - 01")
    #expect(
        app.search.searchResults.first?.videoPath
            == newFolder.appendingPathComponent("Ave Mujica - 01.mkv").mediaPath
    )
    #expect(
        app.search.emptySearchFacetDistribution?.folderCounts[newFolder.mediaPath] == 1
    )
    #expect(
        app.search.searchFacetFilter.excludedFolders == [newFolder.mediaPath]
    )
    #expect(
        app.settings.searchFacetFilter.excludedFolders == [newFolder.mediaPath]
    )

    // 3. Excerpt resident items and folder filter updated in place
    #expect(
        app.excerpt.tableFacetFilter.excludedFolders == [newFolder.mediaPath]
    )
    #expect(
        app.settings.excerptFacetFilter(forListID: ExcerptListIdentity.defaultListID)
            .excludedFolders == [newFolder.mediaPath]
    )
    #expect(
        app.excerpt.residentExcerptsByID.values.first?.displayTitle
            == "BanG Dream! Ave Mujica - 01"
    )
    #expect(
        app.excerpt.tableRowStore.snapshot.row(at: 0)?.displayTitle
            == "BanG Dream! Ave Mujica - 01"
    )

    // 4. Library updated with new folder path and display title
    #expect(
        app.library.completeLibraryFolderSummaries.contains {
            $0.folderPath == newFolder.mediaPath
        }
    )
}

private struct LibraryFolderRemovalTestFixture {
    let suiteName: String
    let userDefaults: UserDefaults
    let databaseURL: URL
    let folder: URL

    @MainActor
    init() throws {
        suiteName = "CueSeekerLibraryFolderRemovalTests-\(UUID().uuidString)"
        userDefaults = try #require(UserDefaults.temporary(suiteName: suiteName))
        databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("CueSeekerLibraryFolderRemovalTests-\(UUID().uuidString)")
            .appendingPathExtension("sqlite")
        folder = URL(fileURLWithPath: "/Media/Removal Fixture").standardizedFileURL
        userDefaults.set([folder.path], forKey: "selectedFolderPaths")
    }

    @MainActor
    func makeApp(
        executor: any LibraryFolderRemovalExecuting
    ) -> AppCoordinator {
        _ = NSApplication.shared
        return AppCoordinator(
            userDefaults: userDefaults,
            databaseURL: databaseURL,
            libraryFolderRemovalExecutor: executor
        )
    }

    func cleanUp() {
        userDefaults.removePersistentDomainAndPlist(forName: suiteName)
        removeTemporaryDatabase(at: databaseURL)
        try? FileManager.default.removeItem(atPath: databaseURL.path + "-wal")
        try? FileManager.default.removeItem(atPath: databaseURL.path + "-shm")
    }
}

private func waitUntilLibraryFolderRemovalStarts(
    _ executor: ControlledLibraryFolderRemovalExecutor
) async throws {
    await executor.waitUntilStarted()
}
