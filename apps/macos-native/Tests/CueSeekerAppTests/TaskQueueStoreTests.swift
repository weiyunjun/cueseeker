import AppKit
import Foundation
import Testing
@testable import CueSeekerApp
@testable import CueSeekerCore

private func taskQueueTestDatabaseURL() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerTaskQueueTests-\(UUID().uuidString)")
        .appendingPathExtension("sqlite")
}

/// An export that never finishes on its own, so a test can look at a queue
/// while a task is genuinely running.
private let neverFinishingExport: TaskExportRunner = { _, _, _, _ in
    try await Task.sleep(nanoseconds: .max)
}

private let neverFinishingRename: TaskRenameRunner = { _, _ in
    try await Task.sleep(nanoseconds: .max)
}

private let neverFinishingIndex: TaskIndexRunner = { _, _ in
    try await Task.sleep(nanoseconds: .max)
    return 0
}

private let neverFinishingRemoveFolder: TaskRemoveFolderRunner = { _ in
    try await Task.sleep(nanoseconds: .max)
}

@MainActor
private func makeTaskQueueStore(
    runExport: @escaping TaskExportRunner = neverFinishingExport,
    runRename: @escaping TaskRenameRunner = neverFinishingRename,
    runIndex: @escaping TaskIndexRunner = neverFinishingIndex,
    runAddFolder: @escaping TaskIndexRunner = neverFinishingIndex,
    runRemoveFolder: @escaping TaskRemoveFolderRunner = neverFinishingRemoveFolder
) throws -> (TaskQueueStore, URL) {
    let databaseURL = taskQueueTestDatabaseURL()
    try DatabaseBootstrap.prepare(at: databaseURL)
    let database = try TaskRecordDatabase(path: databaseURL)
    return (
        TaskQueueStore(
            database: database,
            runExport: runExport,
            runRename: runRename,
            runIndex: runIndex,
            runAddFolder: runAddFolder,
            runRemoveFolder: runRemoveFolder
        ),
        databaseURL
    )
}

private let showRootFolder = URL(fileURLWithPath: "/Videos/Show")

private let showFolderRename = LibraryRenameRequest.folder(
    path: "/Videos/Show",
    newName: "Show Renamed"
)

/// Runs the main actor until `condition` holds, so a test can wait on the
/// queue's own completion instead of guessing at a delay.
@MainActor
private func waitUntil(
    _ condition: () -> Bool,
    iterations: Int = 1_000
) async {
    for _ in 0..<iterations where !condition() {
        await Task.yield()
    }
}

/// An export of a file the folder rename above would move.
private func showEpisodeExportItems() -> [AnkiExportItem] {
    [
        AnkiExportItem(
            deckDisplayTitle: "Show",
            videoPath: "/Videos/Show/EP01.mkv",
            startMilliseconds: 0,
            endMilliseconds: 500,
            text: "line",
            displayTitle: "Show",
            timeRange: "",
            cueGroupOtherTexts: [],
            cueID: nil,
            subtitlePath: ""
        )
    ]
}

private func exportItems(_ count: Int) -> [AnkiExportItem] {
    (0..<count).map { index in
        AnkiExportItem(
            deckDisplayTitle: "Deck",
            videoPath: "/Videos/episode.mkv",
            startMilliseconds: index * 1_000,
            endMilliseconds: index * 1_000 + 500,
            text: "line \(index)",
            displayTitle: "Deck",
            timeRange: "",
            cueGroupOtherTexts: [],
            cueID: nil,
            subtitlePath: ""
        )
    }
}

/// The queue's whole point: a second export waits rather than starting a
/// competing ffmpeg pipeline.
@MainActor
@Test
func secondExportWaitsWhileTheFirstRuns() throws {
    let (store, databaseURL) = try makeTaskQueueStore()
    defer { removeTemporaryDatabase(at: databaseURL) }

    store.enqueueAnkiExport(
        items: exportItems(2),
        options: AnkiExportOptions(),
        destinationURL: URL(fileURLWithPath: "/Exports/First.apkg")
    )
    store.enqueueAnkiExport(
        items: exportItems(3),
        options: AnkiExportOptions(),
        destinationURL: URL(fileURLWithPath: "/Exports/Second.apkg")
    )

    #expect(store.current.map(\.record.state) == [.running, .queued])
    #expect(store.remainingTaskCount == 2)
}

@MainActor
@Test
func currentKeepsTheOrderTasksWereStartedIn() throws {
    let (store, databaseURL) = try makeTaskQueueStore()
    defer { removeTemporaryDatabase(at: databaseURL) }

    for index in 1...3 {
        store.enqueueAnkiExport(
            items: exportItems(index),
            options: AnkiExportOptions(),
            destinationURL: URL(fileURLWithPath: "/Exports/Deck\(index).apkg")
        )
    }

    #expect(store.current.map(\.record.fileName) == [
        "Deck1.apkg", "Deck2.apkg", "Deck3.apkg"
    ])
}

@MainActor
@Test
func aQueuedTaskCarriesWhatItWillWrite() throws {
    let (store, databaseURL) = try makeTaskQueueStore()
    defer { removeTemporaryDatabase(at: databaseURL) }

    store.enqueueAnkiExport(
        items: exportItems(80),
        options: AnkiExportOptions(),
        destinationURL: URL(fileURLWithPath: "/Users/reader/Exports/Deck.apkg")
    )

    let record = try #require(store.current.first?.record)
    #expect(record.fileName == "Deck.apkg")
    #expect(record.folderPath == "/Users/reader/Exports")
    #expect(record.itemCount == 80)
}

/// Removing a queued task never has to wait for anything, so it lands in
/// Incomplete immediately with the reason the reader gave it.
@MainActor
@Test
func removingAQueuedTaskRecordsItAsCancelled() throws {
    let (store, databaseURL) = try makeTaskQueueStore()
    defer { removeTemporaryDatabase(at: databaseURL) }

    store.enqueueAnkiExport(
        items: exportItems(1),
        options: AnkiExportOptions(),
        destinationURL: URL(fileURLWithPath: "/Exports/First.apkg")
    )
    store.enqueueAnkiExport(
        items: exportItems(1),
        options: AnkiExportOptions(),
        destinationURL: URL(fileURLWithPath: "/Exports/Second.apkg")
    )
    let queued = try #require(store.current.last)

    store.removeCurrentTask(id: queued.id)

    #expect(store.current.map(\.record.fileName) == ["First.apkg"])
    #expect(store.incomplete.map(\.fileName) == ["Second.apkg"])
    #expect(store.incomplete.first?.errorMessage == L("task.error.cancelled"))
    #expect(store.remainingTaskCount == 1)
}

@MainActor
@Test
func deletingARecordRemovesItFromTheHistoryAndTheDatabase() throws {
    let (store, databaseURL) = try makeTaskQueueStore()
    defer { removeTemporaryDatabase(at: databaseURL) }

    store.enqueueAnkiExport(
        items: exportItems(1),
        options: AnkiExportOptions(),
        destinationURL: URL(fileURLWithPath: "/Exports/First.apkg")
    )
    store.enqueueAnkiExport(
        items: exportItems(1),
        options: AnkiExportOptions(),
        destinationURL: URL(fileURLWithPath: "/Exports/Second.apkg")
    )
    let queued = try #require(store.current.last)
    store.removeCurrentTask(id: queued.id)

    store.deleteRecord(id: queued.id)

    #expect(store.incomplete.isEmpty)
    let database = try TaskRecordDatabase(path: databaseURL)
    #expect(try database.records().map(\.id) == [store.current.first?.id])
}

/// What a launch after a crash or a quit has to show.
@MainActor
@Test
func aLaunchClosesOutWhateverThePreviousOneLeftRunning() throws {
    let databaseURL = taskQueueTestDatabaseURL()
    defer { removeTemporaryDatabase(at: databaseURL) }
    try DatabaseBootstrap.prepare(at: databaseURL)

    let firstLaunch = TaskQueueStore(
        database: try TaskRecordDatabase(path: databaseURL),
        runExport: neverFinishingExport
    )
    firstLaunch.enqueueAnkiExport(
        items: exportItems(1),
        options: AnkiExportOptions(),
        destinationURL: URL(fileURLWithPath: "/Exports/Running.apkg")
    )
    firstLaunch.enqueueAnkiExport(
        items: exportItems(1),
        options: AnkiExportOptions(),
        destinationURL: URL(fileURLWithPath: "/Exports/Queued.apkg")
    )

    let secondLaunch = TaskQueueStore(
        database: try TaskRecordDatabase(path: databaseURL),
        runExport: neverFinishingExport
    )
    secondLaunch.loadPersistedRecords()

    #expect(secondLaunch.current.isEmpty)
    #expect(secondLaunch.completed.isEmpty)
    #expect(secondLaunch.incomplete.map(\.fileName) == [
        "Queued.apkg", "Running.apkg"
    ])
    #expect(
        secondLaunch.incomplete.allSatisfy {
            $0.errorMessage == L("task.error.interrupted")
        }
    )
}

@MainActor
@Test
func openingThePanelAlwaysStartsOnCurrent() throws {
    let (store, databaseURL) = try makeTaskQueueStore()
    defer { removeTemporaryDatabase(at: databaseURL) }

    store.openPanel()
    store.selectedTab = .completed
    store.closePanel()
    store.openPanel()

    #expect(store.isPanelOpen)
    #expect(store.selectedTab == .current)
}

/// The badge counts what is left to do, and disappears once nothing is.
@MainActor
@Test
func theRemainingCountIsRunningPlusQueued() throws {
    let (store, databaseURL) = try makeTaskQueueStore()
    defer { removeTemporaryDatabase(at: databaseURL) }

    #expect(store.remainingTaskCount == 0)

    store.enqueueAnkiExport(
        items: exportItems(1),
        options: AnkiExportOptions(),
        destinationURL: URL(fileURLWithPath: "/Exports/First.apkg")
    )
    store.enqueueAnkiExport(
        items: exportItems(1),
        options: AnkiExportOptions(),
        destinationURL: URL(fileURLWithPath: "/Exports/Second.apkg")
    )
    #expect(store.remainingTaskCount == 2)

    store.removeCurrentTask(id: try #require(store.current.last).id)
    #expect(store.remainingTaskCount == 1)
}

@MainActor
@Test
func aFinishedExportMovesToCompletedAndLetsTheNextOneStart() async throws {
    let (store, databaseURL) = try makeTaskQueueStore(runExport: { _, _, _, _ in })
    defer { removeTemporaryDatabase(at: databaseURL) }

    store.enqueueAnkiExport(
        items: exportItems(1),
        options: AnkiExportOptions(),
        destinationURL: URL(fileURLWithPath: "/Exports/First.apkg")
    )
    store.enqueueAnkiExport(
        items: exportItems(1),
        options: AnkiExportOptions(),
        destinationURL: URL(fileURLWithPath: "/Exports/Second.apkg")
    )

    await store.waitUntilIdle()

    #expect(store.completed.map(\.fileName) == ["Second.apkg", "First.apkg"])
    #expect(store.incomplete.isEmpty)
    #expect(store.remainingTaskCount == 0)

    let relaunched = TaskQueueStore(database: try TaskRecordDatabase(path: databaseURL))
    relaunched.loadPersistedRecords()
    #expect(relaunched.completed.map(\.fileName) == ["Second.apkg", "First.apkg"])
}

@MainActor
@Test
func aFailedExportMovesToIncompleteCarryingItsError() async throws {
    let (store, databaseURL) = try makeTaskQueueStore(runExport: { _, _, _, _ in
        throw AnkiPackageExportError.ffmpegNotFound
    })
    defer { removeTemporaryDatabase(at: databaseURL) }

    store.enqueueAnkiExport(
        items: exportItems(1),
        options: AnkiExportOptions(),
        destinationURL: URL(fileURLWithPath: "/Exports/First.apkg")
    )

    await waitUntil { store.current.isEmpty }

    #expect(store.completed.isEmpty)
    #expect(store.incomplete.map(\.fileName) == ["First.apkg"])
    #expect(
        store.incomplete.first?.errorMessage
            == AnkiPackageExportError.ffmpegNotFound.description
    )
}

@MainActor
@Test
func theRunningTaskReportsHowManyCardsAreDone() async throws {
    let (store, databaseURL) = try makeTaskQueueStore(runExport: { items, _, _, onItemExported in
        for index in items.indices {
            onItemExported(index + 1)
        }
    })
    defer { removeTemporaryDatabase(at: databaseURL) }

    store.enqueueAnkiExport(
        items: exportItems(4),
        options: AnkiExportOptions(),
        destinationURL: URL(fileURLWithPath: "/Exports/First.apkg")
    )
    let progress = try #require(store.current.first?.progress)

    await waitUntil { progress.exportedCount == 4 }

    #expect(progress.exportedCount == 4)
}

/// Removing a running task ends it, and the record says the reader removed it
/// rather than repeating whatever error the cancellation produced on the way
/// down.
@MainActor
@Test
func removingARunningTaskStopsItAndRecordsTheRemoval() async throws {
    let (store, databaseURL) = try makeTaskQueueStore()
    defer { removeTemporaryDatabase(at: databaseURL) }

    store.enqueueAnkiExport(
        items: exportItems(1),
        options: AnkiExportOptions(),
        destinationURL: URL(fileURLWithPath: "/Exports/First.apkg")
    )
    let running = try #require(store.current.first)
    #expect(running.record.state == .running)

    store.removeCurrentTask(id: running.id)
    await waitUntil { store.current.isEmpty }

    #expect(store.incomplete.map(\.fileName) == ["First.apkg"])
    #expect(store.incomplete.first?.errorMessage == L("task.error.cancelled"))
}

/// Removing the running task must not strand the queue behind it.
@MainActor
@Test
func theQueueKeepsGoingAfterTheRunningTaskIsRemoved() async throws {
    let (store, databaseURL) = try makeTaskQueueStore()
    defer { removeTemporaryDatabase(at: databaseURL) }

    store.enqueueAnkiExport(
        items: exportItems(1),
        options: AnkiExportOptions(),
        destinationURL: URL(fileURLWithPath: "/Exports/First.apkg")
    )
    store.enqueueAnkiExport(
        items: exportItems(1),
        options: AnkiExportOptions(),
        destinationURL: URL(fileURLWithPath: "/Exports/Second.apkg")
    )
    let running = try #require(store.current.first)

    store.removeCurrentTask(id: running.id)
    await waitUntil { store.current.count == 1 }

    #expect(store.current.map(\.record.fileName) == ["Second.apkg"])
    #expect(store.current.first?.record.state == .running)
}

/// The rename's two stages each reach the panel, and the finished task keeps
/// the paths it was queued with.
@MainActor
@Test
func aRenameReportsItsStagesAndCompletes() async throws {
    let (store, databaseURL) = try makeTaskQueueStore(runRename: { _, onStage in
        onStage(.renaming)
    })
    defer { removeTemporaryDatabase(at: databaseURL) }

    store.enqueueRename(
        showFolderRename,
        oldPaths: ["/Videos/Show"],
        newPaths: ["/Videos/Show Renamed"]
    )
    let progress = try #require(store.current.first?.progress)
    #expect(store.current.first?.record.kind == .renameFolder)

    await waitUntil { store.current.isEmpty }

    #expect(progress.renameStage == .renaming)
    #expect(store.completed.map(\.kind) == [.renameFolder])
    #expect(store.completed.first?.oldPaths == ["/Videos/Show"])
    #expect(store.completed.first?.newPaths == ["/Videos/Show Renamed"])
}

@MainActor
@Test
func aRefusedRenameCarriesTheConflictItHit() async throws {
    let (store, databaseURL) = try makeTaskQueueStore(runRename: { _, _ in
        throw LibraryRenameConflict.destinationExists(name: "Show Renamed")
    })
    defer { removeTemporaryDatabase(at: databaseURL) }

    store.enqueueRename(showFolderRename, oldPaths: ["/Videos/Show"], newPaths: ["/Videos/Show Renamed"])
    await waitUntil { store.current.isEmpty }

    #expect(store.incomplete.first?.errorMessage == L("rename.error.exists", "Show Renamed"))
}

@MainActor
@Test
func aRenameProceedsWithoutBeingBlockedByExports() async throws {
    let (store, databaseURL) = try makeTaskQueueStore(runRename: { _, _ in })
    defer { removeTemporaryDatabase(at: databaseURL) }

    store.enqueueAnkiExport(
        items: showEpisodeExportItems(),
        options: AnkiExportOptions(),
        destinationURL: URL(fileURLWithPath: "/Exports/Show.apkg")
    )
    store.enqueueRename(showFolderRename, oldPaths: ["/Videos/Show"], newPaths: ["/Videos/Show Renamed"])

    await waitUntil { !store.completed.isEmpty }

    #expect(store.completed.map(\.kind) == [.renameFolder])
    #expect(store.incomplete.isEmpty)
}

/// An export that comes to start while a rename is moving its files gives way.
@MainActor
@Test
func anExportGivesWayToARunningRenameOfItsFiles() async throws {
    let (store, databaseURL) = try makeTaskQueueStore()
    defer { removeTemporaryDatabase(at: databaseURL) }

    store.enqueueRename(showFolderRename, oldPaths: ["/Videos/Show"], newPaths: ["/Videos/Show Renamed"])
    store.enqueueAnkiExport(
        items: showEpisodeExportItems(),
        options: AnkiExportOptions(),
        destinationURL: URL(fileURLWithPath: "/Exports/Show.apkg")
    )

    await waitUntil { !store.incomplete.isEmpty }

    #expect(store.incomplete.map(\.fileName) == ["Show.apkg"])
    #expect(store.incomplete.first?.errorMessage == L("anki_export.error.rename_running"))
    #expect(store.current.map(\.record.kind) == [.renameFolder])
}

/// The two categories do not wait for each other: an export writes its own
/// package while an Index writes the library.
@MainActor
@Test
func anExportAndAnIndexRunTogether() throws {
    let (store, databaseURL) = try makeTaskQueueStore()
    defer { removeTemporaryDatabase(at: databaseURL) }

    store.enqueueAnkiExport(
        items: exportItems(1),
        options: AnkiExportOptions(),
        destinationURL: URL(fileURLWithPath: "/Exports/First.apkg")
    )
    store.enqueueIndex(folders: [showRootFolder])

    #expect(store.current.map(\.record.state) == [.running, .running])
    #expect(store.current.map(\.record.kind) == [.ankiExport, .index])
}

/// While one library task exists no other is taken, and nothing queues; the
/// queue itself refuses, whatever the pages show.
@MainActor
@Test
func aLibraryTaskRefusesEveryOtherWhileItExists() throws {
    let (store, databaseURL) = try makeTaskQueueStore()
    defer { removeTemporaryDatabase(at: databaseURL) }

    #expect(store.enqueueIndex(folders: [showRootFolder]))
    #expect(store.hasLibraryTask)

    #expect(!store.enqueueIndex(folders: [showRootFolder]))
    #expect(!store.enqueueAddFolder(URL(fileURLWithPath: "/Videos/Other")))
    #expect(!store.enqueueRemoveFolder(showRootFolder))
    #expect(!store.enqueueRename(
        showFolderRename,
        oldPaths: ["/Videos/Show"],
        newPaths: ["/Videos/Show Renamed"]
    ))

    store.enqueueAnkiExport(
        items: exportItems(1),
        options: AnkiExportOptions(),
        destinationURL: URL(fileURLWithPath: "/Exports/First.apkg")
    )
    #expect(store.current.map(\.record.kind) == [.index, .ankiExport])
    #expect(store.current.map(\.record.state) == [.running, .running])
}

@MainActor
@Test
func aLibraryTaskCanStartOnceTheLastOneEnds() async throws {
    let (store, databaseURL) = try makeTaskQueueStore(
        runIndex: { _, _ in 0 },
        runRemoveFolder: { _ in }
    )
    defer { removeTemporaryDatabase(at: databaseURL) }

    store.enqueueIndex(folders: [showRootFolder])
    await waitUntil { store.current.isEmpty }
    #expect(store.enqueueRemoveFolder(showRootFolder))
    await waitUntil { store.current.isEmpty }

    #expect(store.completed.map(\.kind) == [.removeFolder, .index])
    #expect(store.completed.first?.oldPaths == ["/Videos/Show"])
    #expect(!store.hasLibraryTask)
}

/// Index and Add Folder can be removed while they run; the record says the
/// reader removed them.
@MainActor
@Test
func aRunningIndexOrAddFolderCanBeRemoved() async throws {
    let (store, databaseURL) = try makeTaskQueueStore()
    defer { removeTemporaryDatabase(at: databaseURL) }

    store.enqueueIndex(folders: [showRootFolder])
    let index = try #require(store.current.first)
    #expect(index.record.state == .running)
    store.removeCurrentTask(id: index.id)
    await waitUntil { store.current.isEmpty }

    store.enqueueAddFolder(URL(fileURLWithPath: "/Videos/Other"))
    let addition = try #require(store.current.first)
    #expect(addition.record.state == .running)
    store.removeCurrentTask(id: addition.id)
    await waitUntil { store.current.isEmpty }

    #expect(store.incomplete.map(\.kind) == [.addFolder, .index])
    #expect(store.incomplete.allSatisfy { $0.errorMessage == L("task.error.cancelled") })
}

/// A folder removal is one transaction: once it runs it cannot be stopped.
@MainActor
@Test
func aRunningFolderRemovalCannotBeRemoved() throws {
    let (store, databaseURL) = try makeTaskQueueStore()
    defer { removeTemporaryDatabase(at: databaseURL) }

    store.enqueueRemoveFolder(showRootFolder)
    let running = try #require(store.current.first)
    #expect(running.record.state == .running)
    #expect(!running.canBeRemovedWhileRunning)

    store.removeCurrentTask(id: running.id)

    #expect(store.current.map(\.id) == [running.id])
    #expect(store.incomplete.isEmpty)
}

/// Index and Add Folder only know how much they indexed once they have run,
/// so the count reaches the record at the end.
@MainActor
@Test
func aFinishedIndexRecordsWhatItIndexed() async throws {
    let (store, databaseURL) = try makeTaskQueueStore(
        runIndex: { _, _ in 42 },
        runAddFolder: { _, _ in 7 }
    )
    defer { removeTemporaryDatabase(at: databaseURL) }

    store.enqueueIndex(folders: [showRootFolder])
    #expect(store.current.first?.record.oldPaths == ["/Videos/Show"])
    await waitUntil { store.current.isEmpty }
    store.enqueueAddFolder(URL(fileURLWithPath: "/Videos/Other"))
    await waitUntil { store.current.isEmpty }

    #expect(store.completed.map(\.itemCount) == [7, 42])
    let database = try TaskRecordDatabase(path: databaseURL)
    #expect(try database.records().map(\.itemCount).sorted() == [7, 42])
}

/// An Add Folder the previous launch left unfinished is handed back, so the
/// coordinator can take back what it indexed.
@MainActor
@Test
func relaunchAnswersTheFolderAdditionsItClosedOut() throws {
    let databaseURL = taskQueueTestDatabaseURL()
    defer { removeTemporaryDatabase(at: databaseURL) }
    try DatabaseBootstrap.prepare(at: databaseURL)

    let firstLaunch = TaskQueueStore(
        database: try TaskRecordDatabase(path: databaseURL),
        runAddFolder: neverFinishingIndex
    )
    firstLaunch.enqueueAddFolder(URL(fileURLWithPath: "/Videos/Added"))

    let secondLaunch = TaskQueueStore(database: try TaskRecordDatabase(path: databaseURL))
    let unfinished = secondLaunch.loadPersistedRecords()

    #expect(unfinished == [URL(fileURLWithPath: "/Videos/Added")])
    #expect(secondLaunch.incomplete.map(\.kind) == [.addFolder])
    #expect(secondLaunch.incomplete.first?.errorMessage == L("task.error.interrupted"))
    #expect(secondLaunch.loadPersistedRecords().isEmpty)
}

/// The bar gives each stage its fixed share of the folder it is on, and each
/// folder an equal share of the run.
@MainActor
@Test
func theIndexBarDividesFoldersThenStages() {
    #expect(TaskIndexProgress(stage: .scanningFiles).fraction == 0)
    #expect(
        TaskIndexProgress(
            stage: .indexingSubtitles,
            stageCompleted: 1,
            stageTotal: 2
        ).fraction == 0.4
    )
    // A stage with nothing to do sits at its own start and is stepped over.
    #expect(TaskIndexProgress(stage: .readingVideoInfo).fraction == 0.6)
    #expect(
        TaskIndexProgress(
            stage: .generatingCovers,
            stageCompleted: 4,
            stageTotal: 4
        ).fraction == 1
    )
    #expect(
        TaskIndexProgress(
            stage: .scanningFiles,
            completedFolders: 1,
            totalFolders: 2
        ).fraction == 0.5
    )
    #expect(
        TaskIndexProgress(
            stage: .generatingCovers,
            folderName: "Anime",
            stageCompleted: 12,
            stageTotal: 40
        ).label == "\(L("index.stage.covers")) · Anime · 12 / 40"
    )
    #expect(
        TaskIndexProgress(stage: .scanningFiles, folderName: "Anime").label
            == "\(L("index.stage.scanning")) · Anime"
    )
}

@MainActor
@Test
func aRunningRenameCannotBeRemoved() throws {
    let (store, databaseURL) = try makeTaskQueueStore()
    defer { removeTemporaryDatabase(at: databaseURL) }

    store.enqueueRename(showFolderRename, oldPaths: ["/Videos/Show"], newPaths: ["/Videos/Show Renamed"])
    let running = try #require(store.current.first)
    #expect(running.record.state == .running)

    store.removeCurrentTask(id: running.id)

    #expect(store.current.map(\.id) == [running.id])
    #expect(store.incomplete.isEmpty)
}

@MainActor
@Test
func taskRecordTitlesAndIconsFollowRedesignSpecification() throws {
    let ankiRecord = TaskRecord(
        id: 1,
        kind: .ankiExport,
        fileName: "japanese_core_2k.apkg",
        folderPath: "/Exports",
        itemCount: 500,
        state: .queued,
        errorMessage: nil,
        createdAt: Date(),
        stateChangedAt: Date()
    )
    #expect(ankiRecord.icon == .ankiStar)
    #expect(ankiRecord.titleActionPrefix == "Export to Anki: ")
    #expect(ankiRecord.titleTargetName == "japanese_core_2k.apkg")
    #expect(ankiRecord.displayTitle == "Export to Anki: japanese_core_2k.apkg")

    let renameFolderRecord = TaskRecord(
        id: 2,
        kind: .renameFolder,
        fileName: "Season 01 [FLAC]",
        folderPath: "",
        itemCount: 1,
        state: .queued,
        errorMessage: nil,
        createdAt: Date(),
        stateChangedAt: Date(),
        oldPaths: ["/Videos/Season 01"],
        newPaths: ["/Videos/Season 01 [FLAC]"]
    )
    #expect(renameFolderRecord.icon == .pencilSimple)
    #expect(renameFolderRecord.titleActionPrefix == "Renaming Folder: ")
    #expect(renameFolderRecord.titleTargetName == "Season 01 [FLAC]")
    #expect(renameFolderRecord.displayTitle == "Renaming Folder: Season 01 [FLAC]")

    let renameFilesRecord = TaskRecord(
        id: 3,
        kind: .renameFiles,
        fileName: "ep01-remastered",
        folderPath: "",
        itemCount: 2,
        state: .queued,
        errorMessage: nil,
        createdAt: Date(),
        stateChangedAt: Date(),
        oldPaths: ["/Videos/ep01.mkv", "/Videos/ep01.srt"],
        newPaths: ["/Videos/ep01-remastered.mkv", "/Videos/ep01-remastered.srt"]
    )
    #expect(renameFilesRecord.icon == .pencilSimple)
    #expect(renameFilesRecord.titleActionPrefix == "Renaming Files: ")
    #expect(renameFilesRecord.titleTargetName == "ep01-remastered")
    #expect(renameFilesRecord.displayTitle == "Renaming Files: ep01-remastered")

    let indexRecord = TaskRecord(
        id: 4,
        kind: .index,
        fileName: "",
        folderPath: "",
        itemCount: 0,
        state: .running,
        errorMessage: nil,
        createdAt: Date(),
        stateChangedAt: Date(),
        oldPaths: ["/Videos/Anime"]
    )
    #expect(indexRecord.icon == .arrowClockwise)
    #expect(indexRecord.titleActionPrefix == "Index All")
    #expect(indexRecord.titleTargetName == "")
    #expect(indexRecord.displayTitle == "Index All")

    let indexFolderRecord = TaskRecord(
        id: 7,
        kind: .index,
        fileName: "Anime",
        folderPath: "",
        itemCount: 0,
        state: .running,
        errorMessage: nil,
        createdAt: Date(),
        stateChangedAt: Date(),
        oldPaths: ["/Videos/Anime"]
    )
    #expect(indexFolderRecord.icon == .arrowClockwise)
    #expect(indexFolderRecord.titleActionPrefix == "Index: ")
    #expect(indexFolderRecord.titleTargetName == "Anime")
    #expect(indexFolderRecord.displayTitle == "Index: Anime")

    let addFolderRecord = TaskRecord(
        id: 5,
        kind: .addFolder,
        fileName: "Documentary 2026",
        folderPath: "",
        itemCount: 0,
        state: .queued,
        errorMessage: nil,
        createdAt: Date(),
        stateChangedAt: Date(),
        oldPaths: ["/Videos/Documentary 2026"]
    )
    #expect(addFolderRecord.icon == .folderPlus)
    #expect(addFolderRecord.titleActionPrefix == "Add Folder: ")
    #expect(addFolderRecord.titleTargetName == "Documentary 2026")
    #expect(addFolderRecord.displayTitle == "Add Folder: Documentary 2026")

    let removeFolderRecord = TaskRecord(
        id: 6,
        kind: .removeFolder,
        fileName: "OldArchiveFolder",
        folderPath: "",
        itemCount: 0,
        state: .completed,
        errorMessage: nil,
        createdAt: Date(),
        stateChangedAt: Date(),
        oldPaths: ["/Videos/OldArchiveFolder"]
    )
    #expect(removeFolderRecord.icon == .minusCircle)
    #expect(removeFolderRecord.titleActionPrefix == "Remove: ")
    #expect(removeFolderRecord.titleTargetName == "OldArchiveFolder")
    #expect(removeFolderRecord.displayTitle == "Remove: OldArchiveFolder")
}

@MainActor
@Test
func enqueueingLibraryTasksPopulatesFileNameForTitles() throws {
    let (store, databaseURL) = try makeTaskQueueStore()
    defer { removeTemporaryDatabase(at: databaseURL) }

    store.enqueueRename(
        .folder(path: "/Videos/Original", newName: "RenamedFolder"),
        oldPaths: ["/Videos/Original"],
        newPaths: ["/Videos/RenamedFolder"]
    )
    let folderTask = try #require(store.current.first)
    #expect(folderTask.record.fileName == "RenamedFolder")
    #expect(folderTask.record.titleTargetName == "RenamedFolder")
}

@MainActor
@Test
func enqueueIndexFolderPopulatesFolderNameAndRunsSingleFolderRunner() async throws {
    let (store, databaseURL) = try makeTaskQueueStore()
    defer { removeTemporaryDatabase(at: databaseURL) }

    var indexedFolders: [URL] = []
    store.runIndexFolder = { folders, _ in
        indexedFolders = folders
        return 3
    }

    #expect(store.enqueueIndexFolder(showRootFolder))
    let running = try #require(store.current.first)
    #expect(running.record.kind == .index)
    #expect(running.record.fileName == "Show")
    #expect(running.record.displayTitle == "Index: Show")
    #expect(running.record.oldPaths == ["/Videos/Show"])
    #expect(running.canBeRemovedWhileRunning)
    #expect(!store.enqueueIndex(folders: [showRootFolder]))

    await waitUntil { store.current.isEmpty }
    #expect(indexedFolders == [showRootFolder.standardizedMediaURL])
    #expect(store.completed.first?.displayTitle == "Index: Show")
    #expect(store.completed.first?.itemCount == 3)
}

@MainActor
@Test
func enqueueAddFoldersStartsFirstAndQueuesRemainingInOrder() async throws {
    let (holdingStore, holdingDBURL) = try makeTaskQueueStore()
    defer { removeTemporaryDatabase(at: holdingDBURL) }

    let accepted = holdingStore.enqueueAddFolders([
        URL(fileURLWithPath: "/WebDAV/Anime/Season 1"),
        URL(fileURLWithPath: "/WebDAV/Anime/Season 2"),
        URL(fileURLWithPath: "/WebDAV/Anime/OVA")
    ])
    #expect(accepted)
    #expect(holdingStore.current.count == 3)
    #expect(holdingStore.current.map(\.record.fileName) == ["Season 1", "Season 2", "OVA"])
    #expect(holdingStore.current.map(\.record.state) == [.running, .queued, .queued])

    var cancelledQueuedFolders: [String] = []
    holdingStore.onCancelQueuedAddFolder = { url in
        cancelledQueuedFolders.append(url.path)
    }
    holdingStore.removeCurrentTask(id: holdingStore.current[2].id)
    #expect(cancelledQueuedFolders == ["/WebDAV/Anime/OVA"])
    #expect(holdingStore.current.count == 2)

    let (finishingStore, finishingDBURL) = try makeTaskQueueStore(runAddFolder: { _, _ in 1 })
    defer { removeTemporaryDatabase(at: finishingDBURL) }

    #expect(finishingStore.enqueueAddFolders([
        URL(fileURLWithPath: "/WebDAV/Anime/Season 1"),
        URL(fileURLWithPath: "/WebDAV/Anime/Season 2")
    ]))
    await waitUntil { finishingStore.current.isEmpty }
    #expect(finishingStore.completed.map(\.fileName) == ["Season 2", "Season 1"])
}


