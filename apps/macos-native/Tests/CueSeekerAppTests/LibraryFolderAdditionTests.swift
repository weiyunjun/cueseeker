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

/// An Add Folder cut short by quitting is taken back at the next launch, and
/// the roots already in the list keep what they indexed.
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
        userDefaults = try #require(UserDefaults(suiteName: suiteName))
        container = FileManager.default.temporaryDirectory
            .appendingPathComponent(suiteName, isDirectory: true)
        databaseURL = container.appendingPathComponent("CueSeeker.sqlite")
        show = container.appendingPathComponent("Show", isDirectory: true).standardizedFileURL
        seasonOne = show.appendingPathComponent("Season 1", isDirectory: true).standardizedFileURL
        try Self.writeEpisode(named: "Episode 1", in: seasonOne)
        try Self.writeEpisode(named: "Episode 2", in: show.appendingPathComponent("Season 2"))
    }

    @MainActor
    func makeApp() -> AppCoordinator {
        _ = NSApplication.shared
        return AppCoordinator(userDefaults: userDefaults, databaseURL: databaseURL)
    }

    func cleanUp() {
        userDefaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: container)
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
