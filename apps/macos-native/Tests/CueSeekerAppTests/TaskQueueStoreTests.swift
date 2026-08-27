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
private let neverFinishingExport: TaskExportRunner = { _, _, _ in
    try await Task.sleep(nanoseconds: .max)
}

@MainActor
private func makeTaskQueueStore(
    runExport: @escaping TaskExportRunner = neverFinishingExport
) throws -> (TaskQueueStore, URL) {
    let databaseURL = taskQueueTestDatabaseURL()
    try DatabaseBootstrap.prepare(at: databaseURL)
    let database = try TaskRecordDatabase(path: databaseURL)
    return (
        TaskQueueStore(database: database, runExport: runExport),
        databaseURL
    )
}

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

private func exportItems(_ count: Int) -> [AnkiExportItem] {
    (0..<count).map { index in
        AnkiExportItem(
            deckDisplayTitle: "Deck",
            videoPath: "/Videos/episode.mkv",
            startMilliseconds: index * 1_000,
            endMilliseconds: index * 1_000 + 500,
            text: "line \(index)"
        )
    }
}

/// The queue's whole point: a second export waits rather than starting a
/// competing ffmpeg pipeline.
@MainActor
@Test
func secondExportWaitsWhileTheFirstRuns() throws {
    let (store, databaseURL) = try makeTaskQueueStore()
    defer { try? FileManager.default.removeItem(at: databaseURL) }

    store.enqueueAnkiExport(
        items: exportItems(2),
        destinationURL: URL(fileURLWithPath: "/Exports/First.apkg")
    )
    store.enqueueAnkiExport(
        items: exportItems(3),
        destinationURL: URL(fileURLWithPath: "/Exports/Second.apkg")
    )

    #expect(store.current.map(\.record.state) == [.running, .queued])
    #expect(store.remainingTaskCount == 2)
}

@MainActor
@Test
func currentKeepsTheOrderTasksWereStartedIn() throws {
    let (store, databaseURL) = try makeTaskQueueStore()
    defer { try? FileManager.default.removeItem(at: databaseURL) }

    for index in 1...3 {
        store.enqueueAnkiExport(
            items: exportItems(index),
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
    defer { try? FileManager.default.removeItem(at: databaseURL) }

    store.enqueueAnkiExport(
        items: exportItems(80),
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
    defer { try? FileManager.default.removeItem(at: databaseURL) }

    store.enqueueAnkiExport(
        items: exportItems(1),
        destinationURL: URL(fileURLWithPath: "/Exports/First.apkg")
    )
    store.enqueueAnkiExport(
        items: exportItems(1),
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
    defer { try? FileManager.default.removeItem(at: databaseURL) }

    store.enqueueAnkiExport(
        items: exportItems(1),
        destinationURL: URL(fileURLWithPath: "/Exports/First.apkg")
    )
    store.enqueueAnkiExport(
        items: exportItems(1),
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
    defer { try? FileManager.default.removeItem(at: databaseURL) }
    try DatabaseBootstrap.prepare(at: databaseURL)

    let firstLaunch = TaskQueueStore(
        database: try TaskRecordDatabase(path: databaseURL),
        runExport: neverFinishingExport
    )
    firstLaunch.enqueueAnkiExport(
        items: exportItems(1),
        destinationURL: URL(fileURLWithPath: "/Exports/Running.apkg")
    )
    firstLaunch.enqueueAnkiExport(
        items: exportItems(1),
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
        "Running.apkg", "Queued.apkg"
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
    defer { try? FileManager.default.removeItem(at: databaseURL) }

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
    defer { try? FileManager.default.removeItem(at: databaseURL) }

    #expect(store.remainingTaskCount == 0)

    store.enqueueAnkiExport(
        items: exportItems(1),
        destinationURL: URL(fileURLWithPath: "/Exports/First.apkg")
    )
    store.enqueueAnkiExport(
        items: exportItems(1),
        destinationURL: URL(fileURLWithPath: "/Exports/Second.apkg")
    )
    #expect(store.remainingTaskCount == 2)

    store.removeCurrentTask(id: try #require(store.current.last).id)
    #expect(store.remainingTaskCount == 1)
}

/// The Task panel is a layer of its own, above the workbench page it covers
/// and below the dialogs its confirmations are presented as.
@Test
func theTaskPanelSitsBetweenTheWorkbenchPageAndTheDialogs() {
    #expect(InterfaceLayer.workbenchPage < InterfaceLayer.taskPanel)
    #expect(InterfaceLayer.taskPanel < InterfaceLayer.dialog)
}

@MainActor
@Test
func anOpenTaskPanelCoversTheWorkbenchPage() {
    let registry = InterfaceLayerRegistry()

    registry.setOpen(.taskPanel, true)

    #expect(registry.isCovered(.workbenchPage))
    #expect(registry.isFrozen(.workbenchPage))
    #expect(!registry.isCovered(.taskPanel))
}

@MainActor
@Test
func aFinishedExportMovesToCompletedAndLetsTheNextOneStart() async throws {
    let (store, databaseURL) = try makeTaskQueueStore(runExport: { _, _, _ in })
    defer { try? FileManager.default.removeItem(at: databaseURL) }

    store.enqueueAnkiExport(
        items: exportItems(1),
        destinationURL: URL(fileURLWithPath: "/Exports/First.apkg")
    )
    store.enqueueAnkiExport(
        items: exportItems(1),
        destinationURL: URL(fileURLWithPath: "/Exports/Second.apkg")
    )

    await waitUntil { store.current.isEmpty }

    #expect(store.completed.map(\.fileName) == ["First.apkg", "Second.apkg"])
    #expect(store.incomplete.isEmpty)
    #expect(store.remainingTaskCount == 0)
}

@MainActor
@Test
func aFailedExportMovesToIncompleteCarryingItsError() async throws {
    let (store, databaseURL) = try makeTaskQueueStore(runExport: { _, _, _ in
        throw AnkiPackageExportError.ffmpegNotFound
    })
    defer { try? FileManager.default.removeItem(at: databaseURL) }

    store.enqueueAnkiExport(
        items: exportItems(1),
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
    let (store, databaseURL) = try makeTaskQueueStore(runExport: { items, _, onItemExported in
        for index in items.indices {
            onItemExported(index + 1)
        }
    })
    defer { try? FileManager.default.removeItem(at: databaseURL) }

    store.enqueueAnkiExport(
        items: exportItems(4),
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
    defer { try? FileManager.default.removeItem(at: databaseURL) }

    store.enqueueAnkiExport(
        items: exportItems(1),
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
    defer { try? FileManager.default.removeItem(at: databaseURL) }

    store.enqueueAnkiExport(
        items: exportItems(1),
        destinationURL: URL(fileURLWithPath: "/Exports/First.apkg")
    )
    store.enqueueAnkiExport(
        items: exportItems(1),
        destinationURL: URL(fileURLWithPath: "/Exports/Second.apkg")
    )
    let running = try #require(store.current.first)

    store.removeCurrentTask(id: running.id)
    await waitUntil { store.current.count == 1 }

    #expect(store.current.map(\.record.fileName) == ["Second.apkg"])
    #expect(store.current.first?.record.state == .running)
}
