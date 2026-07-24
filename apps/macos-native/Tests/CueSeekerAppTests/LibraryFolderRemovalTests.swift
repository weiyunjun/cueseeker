import AppKit
import Foundation
import Testing
@testable import CueSeekerCore
@testable import CueSeekerApp

private enum LibraryFolderRemovalTestError: Error {
    case expected
}

private actor ControlledLibraryFolderRemovalExecutor: LibraryFolderRemovalExecuting {
    enum Outcome {
        case success
        case failure
    }

    private let outcome: Outcome
    private var started = false
    private var continuation: CheckedContinuation<Void, Never>?

    init(outcome: Outcome = .success) {
        self.outcome = outcome
    }

    func removeFolder(_ folder: URL, databaseURL: URL) async throws {
        started = true
        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }

        if outcome == .failure {
            throw LibraryFolderRemovalTestError.expected
        }
    }

    func hasStarted() -> Bool {
        started
    }

    func finish() {
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
    let removalTask = try #require(app.folderRemovalTask)

    #expect(app.indexing.folderRemovalStatus == .removing(fixture.folder))
    #expect(app.indexing.removedFolderNotice == nil)
    #expect(app.indexing.selectedFolders == [fixture.folder])
    #expect(app.indexing.isLibraryFolderOperationActive)
    #expect(!app.canCompactDatabase)
    try await waitUntilLibraryFolderRemovalStarts(executor)

    let mainActorProbe = Task { @MainActor in true }
    #expect(await mainActorProbe.value)

    await executor.finish()
    await removalTask.value

    #expect(app.indexing.folderRemovalStatus == .idle)
    #expect(app.indexing.removedFolderNotice == fixture.folder)
    #expect(app.indexing.selectedFolders.isEmpty)
    #expect(app.folderRemovalTask == nil)
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
    let removalTask = try #require(app.folderRemovalTask)
    await removalTask.value
    await app.databaseStorageStatsTask?.value

    #expect(app.indexing.folderRemovalStatus == .idle)
    #expect(app.indexing.removedFolderNotice == fixture.folder)
    #expect(app.indexing.selectedFolders.isEmpty)
    #expect(try app.searchDatabase?.search("Actual").isEmpty == true)
}

@MainActor
@Test
func libraryFolderRemovalKeepsUnavailableShioriAndClearsCanonicalCueContent() async throws {
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
                text: "Resident Shiori must remain unavailable"
            ),
        ]
    )
    let selection = try #require(try PlaybackSubtitleDatabase(path: database.path).cueTextSelection(
        forSubtitleFile: subtitleFile,
        atMilliseconds: 1_500
    ))
    let cueID = try #require(selection.cueLineID)
    _ = try ShioriDatabase(path: database.path).upsertShiori(
        selection: selection
    )

    _ = NSApplication.shared
    let app = AppCoordinator(
        userDefaults: fixture.userDefaults,
        databaseURL: fixture.databaseURL
    )
    app.reloadShioriTableRows()
    await app.shioriTableRowsTask?.value
    #expect(app.shiori.residentRelations.map(\.cueID) == [cueID])
    #expect(app.shiori.tableRowStore.snapshot.totalRowCount == 1)
    #expect(app.cueContent.content(for: cueID) != nil)

    app.removeFolder(fixture.folder)
    await app.folderRemovalTask?.value
    await app.shioriTableRowsTask?.value

    #expect(app.shiori.residentRelations.map(\.cueID) == [cueID])
    #expect(app.shiori.tableRowStore.snapshot.totalRowCount == 1)
    #expect(
        app.shiori.tableRowStore.snapshot.row(at: 0)?.cueState
            == .unavailable(.libraryUnavailable)
    )
    #expect(app.cueContent.content(for: cueID) == nil)
}

@MainActor
@Test
func libraryFolderRemovalAndIndexingRejectEachOther() async throws {
    let fixture = try LibraryFolderRemovalTestFixture()
    defer { fixture.cleanUp() }

    let executor = ControlledLibraryFolderRemovalExecutor()
    let app = fixture.makeApp(executor: executor)

    app.indexing.indexingStatus = .indexing(fixture.folder)
    app.removeFolder(fixture.folder)
    #expect(app.folderRemovalTask == nil)
    #expect(app.indexing.folderRemovalStatus == .idle)
    #expect(app.indexing.selectedFolders == [fixture.folder])
    #expect(app.startupError == "Indexing is running")

    app.indexing.indexingStatus = .idle
    app.removeFolder(fixture.folder)
    let removalTask = try #require(app.folderRemovalTask)
    try await waitUntilLibraryFolderRemovalStarts(executor)

    app.indexAllFolders()
    #expect(app.indexing.indexingStatus == .idle)
    #expect(app.startupError == "Folder removal is running")

    let otherFolder = URL(fileURLWithPath: "/Media/Other Folder")
    app.addFolder(otherFolder)
    #expect(app.indexing.selectedFolders == [fixture.folder])

    await executor.finish()
    await removalTask.value
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
    let removalTask = try #require(app.folderRemovalTask)
    try await waitUntilLibraryFolderRemovalStarts(executor)

    #expect(app.indexing.selectedFolders == [fixture.folder])
    #expect(app.library.libraryVideos == [existingVideo])
    #expect(app.library.selectedLibraryVideo == existingVideo)
    await executor.finish()
    await removalTask.value

    #expect(app.indexing.folderRemovalStatus == .idle)
    #expect(app.indexing.removedFolderNotice == nil)
    #expect(app.indexing.selectedFolders == [fixture.folder])
    #expect(app.library.libraryVideos == [existingVideo])
    #expect(app.library.selectedLibraryVideo == existingVideo)
    #expect(app.startupError?.contains("Failed to remove folder index") == true)
    #expect(app.folderRemovalTask == nil)
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
    await app.searchTask?.value
    app.search.activateResidentSearchTableProjection()
    let originalCueIDs = app.search.searchResultCueIDs
    try #require(originalCueIDs.count == 1)

    app.clearSearchAndPlaybackState(under: fixture.folder)
    #expect(app.search.searchResultCueIDs.isEmpty)
    #expect(app.search.tableRowStore.snapshot.totalRowCount == 0)

    app.restoreCurrentSearchAfterIndexedCueMutationFailure()
    await app.searchTask?.value

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

    app.indexFolder(fixture.folder)

    #expect(app.indexing.removedFolderNotice == nil)
    app.indexingTask?.cancel()
    await app.indexingTask?.value
}

@MainActor
@Test
func unchangedFolderIndexPreservesLoadedSearchState() async throws {
    _ = NSApplication.shared
    let suiteName = "CueSeekerIncrementalIndexTests-\(UUID().uuidString)"
    let userDefaults = try #require(UserDefaults(suiteName: suiteName))
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
        userDefaults.removePersistentDomain(forName: suiteName)
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
    await app.searchTask?.value
    let cueIDsBefore = app.search.searchResultCueIDs
    let revisionBefore = app.search.indexedCueDataRevision
    try #require(!cueIDsBefore.isEmpty)

    app.indexFolder(root)
    await app.indexingTask?.value

    guard case let .completed(_, result) = app.indexing.indexingStatus else {
        Issue.record(
            "Expected completed unchanged Index, got \(app.indexing.indexingStatus)"
        )
        return
    }
    #expect(!result.hasIndexedContentChanges)
    #expect(app.search.indexedCueDataRevision == revisionBefore)
    #expect(app.search.searchResultCueIDs == cueIDsBefore)
}

private struct LibraryFolderRemovalTestFixture {
    let suiteName: String
    let userDefaults: UserDefaults
    let databaseURL: URL
    let folder: URL

    @MainActor
    init() throws {
        suiteName = "CueSeekerLibraryFolderRemovalTests-\(UUID().uuidString)"
        userDefaults = try #require(UserDefaults(suiteName: suiteName))
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
        userDefaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: databaseURL)
        try? FileManager.default.removeItem(atPath: databaseURL.path + "-wal")
        try? FileManager.default.removeItem(atPath: databaseURL.path + "-shm")
    }
}

private func waitUntilLibraryFolderRemovalStarts(
    _ executor: ControlledLibraryFolderRemovalExecutor
) async throws {
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: .seconds(3))
    while !(await executor.hasStarted()) {
        guard clock.now < deadline else {
            Issue.record("Timed out waiting for Library folder removal")
            return
        }
        try await Task.sleep(for: .milliseconds(5))
    }
}
