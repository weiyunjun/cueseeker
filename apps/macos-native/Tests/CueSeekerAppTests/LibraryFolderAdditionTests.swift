import AppKit
import Foundation
import Testing
@testable import CueSeekerCore
@testable import CueSeekerApp

/// A folder joins the list once its Add Folder completes, with what it
/// indexed on the finished card.
@MainActor
@Test
func anAddedFolderJoinsTheListOnceItIsIndexed() async throws {
    let fixture = try LibraryFolderAdditionFixture()
    defer { fixture.cleanUp() }
    let app = fixture.makeApp()

    app.addFolder(fixture.show)
    #expect(!app.indexing.selectedFolders.contains(fixture.show))
    #expect(app.tasks.current.map(\.record.kind) == [.addFolder])

    await app.tasks.waitUntilIdle()

    #expect(app.indexing.selectedFolders == [fixture.show])
    #expect(app.tasks.completed.map(\.kind) == [.addFolder])
    #expect(app.tasks.completed.first?.itemCount == 2)
    #expect(app.tasks.completed.first?.oldPaths == [fixture.show.path])
}

/// A folder a root already holds has nothing new to index: it joins the list
/// and its task completes at once.
@MainActor
@Test
func addingAFolderARootHoldsIndexesNothing() async throws {
    let fixture = try LibraryFolderAdditionFixture()
    defer { fixture.cleanUp() }
    fixture.userDefaults.set([fixture.show.path], forKey: "selectedFolderPaths")
    let app = fixture.makeApp()

    app.addFolder(fixture.seasonOne)
    await app.tasks.waitUntilIdle()
    app.addFolder(fixture.show)
    await app.tasks.waitUntilIdle()

    #expect(app.indexing.selectedFolders == [fixture.show, fixture.seasonOne])
    #expect(app.tasks.completed.map(\.itemCount) == [0, 0])
    #expect(app.indexing.indexingStatus == .idle)
}

/// A removed Add Folder is as if the folder had never been added.
@MainActor
@Test
func aRemovedFolderAdditionLeavesNothingBehind() async throws {
    let fixture = try LibraryFolderAdditionFixture()
    defer { fixture.cleanUp() }
    let app = fixture.makeApp()

    app.addFolder(fixture.show)
    let addition = try #require(app.tasks.current.first)
    app.tasks.removeCurrentTask(id: addition.id)
    await app.tasks.waitUntilIdle()

    #expect(app.indexing.selectedFolders.isEmpty)
    #expect(app.indexing.removedFolderNotice == nil)
    #expect(app.indexing.folderRemovalStatus == .idle)
    #expect(app.tasks.incomplete.map(\.kind) == [.addFolder])
    #expect(app.tasks.incomplete.first?.errorMessage == L("task.error.cancelled"))
    #expect(try IndexingDatabase(path: fixture.databaseURL).subtitleFiles().isEmpty)
}

/// An Add Folder removed once its subtitles are published, in a later stage,
/// is taken back from the Filter Dialog too: its folders are no longer listed.
@MainActor
@Test
func aFolderAdditionRemovedAfterPublishingLeavesNoFolderInTheFilter() async throws {
    let fixture = try LibraryFolderAdditionFixture()
    defer { fixture.cleanUp() }
    let app = fixture.makeApp()
    let addFolder = app.tasks.runAddFolder
    app.tasks.runAddFolder = { folders, onProgress in
        try await addFolder(folders) { progress in
            if progress.stage == .readingVideoInfo {
                withUnsafeCurrentTask { $0?.cancel() }
            }
            onProgress(progress)
        }
    }

    app.addFolder(fixture.show)
    await app.tasks.waitUntilIdle()

    #expect(app.indexing.selectedFolders.isEmpty)
    #expect(try IndexingDatabase(path: fixture.databaseURL).subtitleFiles().isEmpty)
    #expect(filterFolderPaths(of: app).isEmpty)
}

/// An Add Folder cut short by quitting is taken back at the next launch, and
/// the roots already in the list keep what they indexed. The Filter Dialog
/// lists only what is kept.
@MainActor
@Test
func anUnfinishedFolderAdditionIsTakenBackAtLaunch() async throws {
    let fixture = try LibraryFolderAdditionFixture()
    defer { fixture.cleanUp() }
    try DatabaseBootstrap.prepare(at: fixture.databaseURL)
    let database = try IndexingDatabase(path: fixture.databaseURL)
    _ = try SubtitleIndexer().index(folder: fixture.seasonOne, into: database)
    _ = try SubtitleIndexer().index(folder: fixture.show, into: database)
    let taskRecords = try TaskRecordDatabase(path: fixture.databaseURL)
    let record = try taskRecords.insertQueuedTask(
        kind: .addFolder,
        fileName: "",
        folderPath: "",
        itemCount: 0,
        oldPaths: [fixture.show.path]
    )
    try taskRecords.updateState(id: record.id, to: .running)
    fixture.userDefaults.set([fixture.seasonOne.path], forKey: "selectedFolderPaths")

    let app = fixture.makeApp()

    #expect(app.tasks.incomplete.map(\.kind) == [.addFolder])
    #expect(app.tasks.incomplete.first?.errorMessage == L("task.error.interrupted"))
    #expect(try database.subtitleFiles().map {
        URL(fileURLWithPath: $0.subtitlePath).lastPathComponent
    } == ["Episode 1.srt"])
    #expect(try database.libraryPathRecords().map(\.rootURL.path) == [
        fixture.seasonOne.standardizedFileURL.path
    ])
    #expect(filterFolderPaths(of: app) == [fixture.seasonOne.path])
}

/// Index Now indexes the outermost root of every group once, in group order.
@MainActor
@Test
func indexNowIndexesEachGroupOnceInGroupOrder() async throws {
    let fixture = try LibraryFolderAdditionFixture()
    defer { fixture.cleanUp() }
    let other = fixture.container.appendingPathComponent("Other", isDirectory: true)
        .standardizedFileURL
    fixture.userDefaults.set(
        [fixture.seasonOne.path, other.path, fixture.show.path],
        forKey: "selectedFolderPaths"
    )
    let app = fixture.makeApp()
    app.tasks.runIndex = { _, _ in
        try await Task.sleep(nanoseconds: .max)
        return 0
    }

    app.indexAllFolders()

    #expect(app.tasks.current.first?.record.oldPaths == [fixture.show.path, other.path])
    let index = try #require(app.tasks.current.first)
    app.tasks.removeCurrentTask(id: index.id)
    await app.tasks.waitUntilIdle()
}

/// Index This Folder indexes only the selected root folder even when it is
/// nested inside another added parent root, keeping the parent LibraryID and
/// leaving sibling subfolders under the parent untouched.
@MainActor
@Test
func indexFolderIndexesOnlyTheSelectedFolderIncludingNestedRoot() async throws {
    let fixture = try LibraryFolderAdditionFixture()
    defer { fixture.cleanUp() }
    fixture.userDefaults.set(
        [fixture.show.path, fixture.seasonOne.path],
        forKey: "selectedFolderPaths"
    )
    let app = fixture.makeApp()
    app.indexAllFolders()
    await app.tasks.waitUntilIdle()

    // Modify Episode 1 in Season 1 and delete Episode 2 in Season 2 on disk.
    // Indexing only Season 1 should update Episode 1 without removing Episode 2
    // from the database or splitting search_paths.
    let ep1Subtitle = fixture.seasonOne.appendingPathComponent("Episode 1.srt")
    let ep2Subtitle = fixture.show
        .appendingPathComponent("Season 2", isDirectory: true)
        .appendingPathComponent("Episode 2.srt")
    try """
    1
    00:00:01,000 --> 00:00:03,000
    Episode 1 updated line

    """.write(to: ep1Subtitle, atomically: true, encoding: .utf8)
    try FileManager.default.removeItem(at: ep2Subtitle)

    app.indexFolder(fixture.seasonOne)
    await app.tasks.waitUntilIdle()

    guard case let .completed(completedFolder, result) = app.indexing.indexingStatus else {
        Issue.record("Expected single-folder index to complete, got \(app.indexing.indexingStatus)")
        return
    }
    #expect(completedFolder == fixture.seasonOne)
    #expect(result.indexedSubtitleFiles == 1)
    #expect(app.indexing.operationNotice == .indexed(folderName: "Season 1"))
    #expect(app.tasks.completed.first?.displayTitle == "Index: Season 1")

    let database = try IndexingDatabase(path: fixture.databaseURL)
    #expect(try database.libraryPathRecords().map(\.rootURL.path) == [fixture.show.path])
    let subtitleNames = try database.subtitleFiles().map {
        URL(fileURLWithPath: $0.subtitlePath).lastPathComponent
    }.sorted()
    #expect(subtitleNames == ["Episode 1.srt", "Episode 2.srt"])
}

/// A library task never stops what is playing. Removing a parent keeps a root
/// inside it, and with it the video playing there; a video that was only in
/// the removed part plays on as one the library no longer holds.
@MainActor
@Test
func removingAParentKeepsPlayingAndMarksOnlyTheVideosThatLeaveTheLibrary() async throws {
    let fixture = try LibraryFolderAdditionFixture()
    defer { fixture.cleanUp() }
    fixture.userDefaults.set(
        [fixture.seasonOne.path, fixture.show.path],
        forKey: "selectedFolderPaths"
    )
    let app = fixture.makeApp()
    app.indexAllFolders()
    await app.tasks.waitUntilIdle()
    let keptVideo = try fixture.indexedVideo(named: "Episode 1")
    let removedVideo = try fixture.indexedVideo(named: "Episode 2")

    app.library.selectedLibraryVideo = keptVideo
    app.search.selectResult(nil)
    app.removeFolder(fixture.show)
    await app.tasks.waitUntilIdle()

    #expect(app.indexing.selectedFolders == [fixture.seasonOne])
    #expect(app.library.selectedLibraryVideo == keptVideo)
    #expect(!app.currentPlaybackItemLeftLibrary)

    app.library.selectedLibraryVideo = removedVideo
    app.reconcilePlaybackAfterIndexedContentChange()

    #expect(app.library.selectedLibraryVideo == removedVideo)
    #expect(app.currentPlaybackItemLeftLibrary)
}

/// New subtitles for a video that stays in the library leave it playing as
/// before; an Index that takes the video out of the library leaves it playing
/// as one the library no longer holds.
@MainActor
@Test
func indexKeepsPlayingAVideoItTakesOutOfTheLibrary() async throws {
    let fixture = try LibraryFolderAdditionFixture()
    defer { fixture.cleanUp() }
    fixture.userDefaults.set([fixture.show.path], forKey: "selectedFolderPaths")
    let app = fixture.makeApp()
    app.indexAllFolders()
    await app.tasks.waitUntilIdle()
    let video = try fixture.indexedVideo(named: "Episode 2")
    let subtitle = URL(fileURLWithPath: video.subtitlePath)

    app.library.selectedLibraryVideo = video
    try """
    1
    00:00:01,000 --> 00:00:03,000
    Episode 2 line, rewritten

    """.write(to: subtitle, atomically: true, encoding: .utf8)
    app.indexAllFolders()
    await app.tasks.waitUntilIdle()

    guard case let .completedAll(_, result) = app.indexing.indexingStatus else {
        Issue.record("Expected Index Now to complete, got \(app.indexing.indexingStatus)")
        return
    }
    #expect(result.hasIndexedContentChanges)
    #expect(app.library.selectedLibraryVideo == video)
    #expect(!app.currentPlaybackItemLeftLibrary)

    try FileManager.default.removeItem(at: subtitle)
    app.indexAllFolders()
    await app.tasks.waitUntilIdle()

    #expect(app.library.selectedLibraryVideo == video)
    #expect(app.currentPlaybackItemLeftLibrary)
}

@MainActor
@Test
func tasksCompactDatabaseOnlyWhenSubtitleCuesMutate() async throws {
    let fixture = try LibraryFolderAdditionFixture()
    defer { fixture.cleanUp() }
    let app = fixture.makeApp()

    // 1. Add Folder with subtitle cues -> compacts freelist pages to 0.
    try fixture.injectFreelistPages()
    #expect(try fixture.freelistCount() > 0)
    app.addFolder(fixture.show)
    await app.tasks.waitUntilIdle()
    #expect(try fixture.freelistCount() == 0)

    // 2. Index All when nothing changed -> does NOT compact.
    try fixture.injectFreelistPages()
    let freelistBeforeUnchangedIndex = try fixture.freelistCount()
    #expect(freelistBeforeUnchangedIndex > 0)
    app.indexAllFolders()
    await app.tasks.waitUntilIdle()
    #expect(try fixture.freelistCount() == freelistBeforeUnchangedIndex)

    // 3. Index when only raw_cue_count is backfilled -> does NOT compact.
    try fixture.clearRawCueCounts()
    app.indexFolder(fixture.show)
    await app.tasks.waitUntilIdle()
    #expect(try fixture.freelistCount() > 0)

    // 4. Index when only video binding/metadata changes (subtitle unchanged) -> does NOT compact.
    let ep1Video = fixture.seasonOne.appendingPathComponent("Episode 1.mkv")
    try Data([0, 1, 2, 3]).write(to: ep1Video)
    app.indexFolder(fixture.show)
    await app.tasks.waitUntilIdle()
    #expect(try fixture.freelistCount() > 0)

    // 5. Add Folder for a subfolder already covered by an outer root -> does NOT compact.
    app.addFolder(fixture.seasonOne)
    await app.tasks.waitUntilIdle()
    #expect(try fixture.freelistCount() > 0)

    // 6. Remove Folder for a subfolder still covered by an outer root -> does NOT compact.
    app.removeFolder(fixture.seasonOne)
    await app.tasks.waitUntilIdle()
    #expect(try fixture.freelistCount() > 0)

    // 7. Add Folder and Remove Folder for an empty folder (no valid subtitles) -> does NOT compact.
    let emptyFolder = fixture.container.appendingPathComponent("Empty", isDirectory: true).standardizedFileURL
    try FileManager.default.createDirectory(at: emptyFolder, withIntermediateDirectories: true)
    app.addFolder(emptyFolder)
    await app.tasks.waitUntilIdle()
    #expect(try fixture.freelistCount() > 0)
    app.removeFolder(emptyFolder)
    await app.tasks.waitUntilIdle()
    #expect(try fixture.freelistCount() > 0)

    // 8. Index when a subtitle file is modified -> compacts freelist pages to 0.
    let ep1Subtitle = fixture.seasonOne.appendingPathComponent("Episode 1.srt")
    try """
    1
    00:00:01,000 --> 00:00:03,000
    Episode 1 updated line for compaction check

    """.write(to: ep1Subtitle, atomically: true, encoding: .utf8)
    app.indexFolder(fixture.show)
    await app.tasks.waitUntilIdle()
    #expect(try fixture.freelistCount() == 0)

    // 9. Index All when a subtitle file is deleted -> compacts freelist pages to 0.
    try fixture.injectFreelistPages()
    #expect(try fixture.freelistCount() > 0)
    try FileManager.default.removeItem(at: ep1Subtitle)
    app.indexAllFolders()
    await app.tasks.waitUntilIdle()
    #expect(try fixture.freelistCount() == 0)

    // 10. Remove Folder when remaining subtitle cues are deleted -> compacts freelist pages to 0.
    try fixture.injectFreelistPages()
    #expect(try fixture.freelistCount() > 0)
    app.removeFolder(fixture.show)
    await app.tasks.waitUntilIdle()
    #expect(try fixture.freelistCount() == 0)
}

/// The folders the Search and Excerpt Filter Dialogs list.
@MainActor
private func filterFolderPaths(of app: AppCoordinator) -> [String] {
    CueFacetFolderOption.listed(
        emptyDistribution: app.search.emptySearchFacetDistribution,
        snapshot: app.search.searchFacetSnapshot
    ).map(\.path)
}

private struct LibraryFolderAdditionFixture {
    let suiteName: String
    let userDefaults: UserDefaults
    let container: URL
    let databaseURL: URL
    let show: URL
    let seasonOne: URL

    @MainActor
    init() throws {
        suiteName = "CueSeekerLibraryFolderAdditionTests-\(UUID().uuidString)"
        userDefaults = try #require(UserDefaults.temporary(suiteName: suiteName))
        container = FileManager.default.temporaryDirectory
            .appendingPathComponent(suiteName, isDirectory: true)
        databaseURL = container.appendingPathComponent("CueSeeker.sqlite")
        show = container.appendingPathComponent("Show", isDirectory: true).standardizedFileURL
        seasonOne = show.appendingPathComponent("Season 1", isDirectory: true).standardizedFileURL
        try Self.writeEpisode(named: "Episode 1", in: seasonOne)
        try Self.writeEpisode(named: "Episode 2", in: show.appendingPathComponent("Season 2"))
    }

    /// The video the index wrote for an episode, as the Library selects it.
    func indexedVideo(named name: String) throws -> LibraryVideo {
        let metadata = try #require(
            try IndexingDatabase(path: databaseURL).subtitleFiles().first {
                URL(fileURLWithPath: $0.subtitlePath).lastPathComponent == "\(name).srt"
            }
        )
        return LibraryVideo(
            videoPath: try #require(metadata.videoPath),
            videoName: "\(name).mkv",
            duration: nil,
            subtitlePath: metadata.subtitlePath,
            subtitleFormat: .srt
        )
    }

    @MainActor
    func makeApp() -> AppCoordinator {
        _ = NSApplication.shared
        return AppCoordinator(userDefaults: userDefaults, databaseURL: databaseURL)
    }

    func cleanUp() {
        userDefaults.removePersistentDomainAndPlist(forName: suiteName)
        try? FileManager.default.removeItem(at: container)
    }

    func injectFreelistPages() throws {
        let database = try SQLiteDatabase(path: databaseURL)
        let largePath = "/" + String(repeating: "f", count: 16_384)
        try database.execute(
            """
            INSERT INTO library_root_folders (path, created_at, updated_at)
            VALUES ('\(largePath)', '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z');
            DELETE FROM library_root_folders WHERE path = '\(largePath)';
            PRAGMA wal_checkpoint(TRUNCATE);
            """
        )
    }

    func clearRawCueCounts() throws {
        let database = try SQLiteDatabase(path: databaseURL)
        try database.execute("UPDATE subtitle_files SET raw_cue_count = NULL;")
    }

    func freelistCount() throws -> Int {
        try DatabaseMaintenanceDatabase(
            path: databaseURL,
            access: .readOnly
        ).storageStats().freelistCount
    }

    private static func writeEpisode(named name: String, in folder: URL) throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try """
        1
        00:00:01,000 --> 00:00:02,000
        \(name) line

        """.write(
            to: folder.appendingPathComponent("\(name).srt"),
            atomically: true,
            encoding: .utf8
        )
        try Data([0]).write(to: folder.appendingPathComponent("\(name).mkv"))
    }
}
