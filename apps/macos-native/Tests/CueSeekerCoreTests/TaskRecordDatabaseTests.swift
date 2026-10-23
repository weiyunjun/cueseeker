import Foundation
import Testing
@testable import CueSeekerCore

private func makeTaskRecordDatabase() throws -> (TaskRecordDatabase, URL) {
    let databaseURL = temporaryDatabaseURL()
    try DatabaseBootstrap.prepare(at: databaseURL)
    return (try TaskRecordDatabase(path: databaseURL), databaseURL)
}

@Test
func migratedSchemaCarriesTheTaskRecordTable() throws {
    let databaseURL = temporaryDatabaseURL()
    defer { removeTemporaryDatabase(at: databaseURL) }

    try DatabaseBootstrap.prepare(at: databaseURL)

    #expect(try sqliteTableExists("task_records", databaseURL: databaseURL))
    #expect(
        try sqliteColumnNames(in: "task_records", databaseURL: databaseURL) == [
            "id", "kind", "file_name", "folder_path", "item_count",
            "state", "error_message", "created_at", "state_changed_at",
            "old_paths", "new_paths", "started_at"
        ]
    )
}

@Test
func queuedTaskIsReadBackWithWhatItWillWrite() throws {
    let (database, databaseURL) = try makeTaskRecordDatabase()
    defer { removeTemporaryDatabase(at: databaseURL) }

    let inserted = try database.insertQueuedTask(
        kind: .ankiExport,
        fileName: "Deck.apkg",
        folderPath: "/Users/reader/Exports",
        itemCount: 80
    )

    let records = try database.records()
    #expect(records.count == 1)
    #expect(records.first?.id == inserted.id)
    #expect(records.first?.kind == .ankiExport)
    #expect(records.first?.fileName == "Deck.apkg")
    #expect(records.first?.folderPath == "/Users/reader/Exports")
    #expect(records.first?.itemCount == 80)
    #expect(records.first?.state == .queued)
    #expect(records.first?.errorMessage == nil)
    #expect(records.first?.startedAt == nil)
}

@Test
func recordsComeBackNewestFirst() throws {
    let (database, databaseURL) = try makeTaskRecordDatabase()
    defer { removeTemporaryDatabase(at: databaseURL) }

    for index in 1...3 {
        _ = try database.insertQueuedTask(
            kind: .ankiExport,
            fileName: "Deck\(index).apkg",
            folderPath: "/Exports",
            itemCount: index,
            createdAt: Date(timeIntervalSince1970: Double(index))
        )
    }

    #expect(try database.records().map(\.fileName) == [
        "Deck3.apkg", "Deck2.apkg", "Deck1.apkg"
    ])
}

@Test
func recordsOrderByLatestStateChangeBeforeID() throws {
    let (database, databaseURL) = try makeTaskRecordDatabase()
    defer { removeTemporaryDatabase(at: databaseURL) }

    let first = try database.insertQueuedTask(
        kind: .ankiExport,
        fileName: "First.apkg",
        folderPath: "/Exports",
        itemCount: 1,
        createdAt: Date(timeIntervalSince1970: 10)
    )
    let second = try database.insertQueuedTask(
        kind: .ankiExport,
        fileName: "Second.apkg",
        folderPath: "/Exports",
        itemCount: 1,
        createdAt: Date(timeIntervalSince1970: 20)
    )

    try database.updateState(
        id: second.id,
        to: .completed,
        changedAt: Date(timeIntervalSince1970: 30)
    )
    try database.updateState(
        id: first.id,
        to: .completed,
        changedAt: Date(timeIntervalSince1970: 30.005)
    )

    #expect(try database.records().map(\.fileName) == [
        "First.apkg", "Second.apkg"
    ])
}

@Test
func stateAndErrorAreWrittenThrough() throws {
    let (database, databaseURL) = try makeTaskRecordDatabase()
    defer { removeTemporaryDatabase(at: databaseURL) }

    let record = try database.insertQueuedTask(
        kind: .ankiExport,
        fileName: "Deck.apkg",
        folderPath: "/Exports",
        itemCount: 10
    )
    try database.updateState(
        id: record.id,
        to: .incomplete,
        errorMessage: "Cancelled by user"
    )

    #expect(try database.records().first?.state == .incomplete)
    #expect(try database.records().first?.errorMessage == "Cancelled by user")

    try database.updateState(id: record.id, to: .completed)
    #expect(try database.records().first?.state == .completed)
    #expect(try database.records().first?.errorMessage == nil)
}

/// A running or queued row belongs to a process that is gone, so the next
/// launch must close it out rather than show it as still working.
@Test
func unfinishedTasksFromAPreviousLaunchBecomeIncomplete() throws {
    let (database, databaseURL) = try makeTaskRecordDatabase()
    defer { removeTemporaryDatabase(at: databaseURL) }

    let running = try database.insertQueuedTask(
        kind: .ankiExport,
        fileName: "Running.apkg",
        folderPath: "/Exports",
        itemCount: 10,
        createdAt: Date(timeIntervalSince1970: 10)
    )
    try database.updateState(
        id: running.id,
        to: .running,
        changedAt: Date(timeIntervalSince1970: 11)
    )
    _ = try database.insertQueuedTask(
        kind: .ankiExport,
        fileName: "Queued.apkg",
        folderPath: "/Exports",
        itemCount: 20,
        createdAt: Date(timeIntervalSince1970: 12)
    )
    let finished = try database.insertQueuedTask(
        kind: .ankiExport,
        fileName: "Done.apkg",
        folderPath: "/Exports",
        itemCount: 30,
        createdAt: Date(timeIntervalSince1970: 13)
    )
    try database.updateState(
        id: finished.id,
        to: .completed,
        changedAt: Date(timeIntervalSince1970: 14)
    )

    let closed = try database.markUnfinishedTasksIncomplete(
        message: "Interrupted",
        at: Date(timeIntervalSince1970: 20)
    )

    #expect(closed == 2)
    let records = try database.records()
    #expect(records.map(\.fileName) == ["Queued.apkg", "Running.apkg", "Done.apkg"])
    #expect(records.map(\.state) == [.incomplete, .incomplete, .completed])
    #expect(records[0].errorMessage == "Interrupted")
    #expect(records[1].errorMessage == "Interrupted")
    #expect(records[2].errorMessage == nil)
    #expect(records[0].startedAt == nil)
    #expect(records[1].startedAt == Date(timeIntervalSince1970: 11))
}

@Test
func startedAtIsSetOnRunningAndPreservedThroughCompletionOrIncomplete() throws {
    let (database, databaseURL) = try makeTaskRecordDatabase()
    defer { removeTemporaryDatabase(at: databaseURL) }

    let createdTime = Date(timeIntervalSince1970: 100)
    let startedTime = Date(timeIntervalSince1970: 105)
    let completedTime = Date(timeIntervalSince1970: 120)

    let cancelledWhileQueued = try database.insertQueuedTask(
        kind: .ankiExport,
        fileName: "QueuedCancelled.apkg",
        folderPath: "/Exports",
        itemCount: 5,
        createdAt: createdTime
    )
    try database.updateState(
        id: cancelledWhileQueued.id,
        to: .incomplete,
        errorMessage: "Cancelled by user",
        changedAt: startedTime
    )

    let completed = try database.insertQueuedTask(
        kind: .index,
        fileName: "",
        folderPath: "/Media/Show",
        itemCount: 0,
        oldPaths: ["/Media/Show"],
        createdAt: createdTime
    )
    try database.updateState(
        id: completed.id,
        to: .running,
        changedAt: startedTime
    )
    try database.updateItemCount(id: completed.id, to: 12)
    try database.updateState(
        id: completed.id,
        to: .completed,
        changedAt: completedTime
    )

    let recordsByID = Dictionary(
        uniqueKeysWithValues: try database.records().map { ($0.id, $0) }
    )
    #expect(recordsByID[cancelledWhileQueued.id]?.startedAt == nil)
    #expect(recordsByID[completed.id]?.startedAt == startedTime)
    #expect(recordsByID[completed.id]?.stateChangedAt == completedTime)
    #expect(recordsByID[completed.id]?.itemCount == 12)

    let inMemoryQueued = cancelledWhileQueued.withState(
        .incomplete,
        errorMessage: "Cancelled by user",
        changedAt: startedTime
    )
    #expect(inMemoryQueued.startedAt == nil)

    let inMemoryRunning = completed
        .withState(.running, errorMessage: nil, changedAt: startedTime)
        .withItemCount(12)
        .withState(.completed, errorMessage: nil, changedAt: completedTime)
    #expect(inMemoryRunning.startedAt == startedTime)
    #expect(inMemoryRunning.stateChangedAt == completedTime)
}

@Test
func deletedRecordDoesNotComeBack() throws {
    let (database, databaseURL) = try makeTaskRecordDatabase()
    defer { removeTemporaryDatabase(at: databaseURL) }

    let record = try database.insertQueuedTask(
        kind: .ankiExport,
        fileName: "Deck.apkg",
        folderPath: "/Exports",
        itemCount: 10
    )
    try database.deleteRecord(id: record.id)

    #expect(try database.records().isEmpty)
}

/// Reopening is the part that matters: the history is what a later launch
/// reads, so it has to survive the connection that wrote it.
@Test
func historySurvivesReopeningTheDatabase() throws {
    let databaseURL = temporaryDatabaseURL()
    defer { removeTemporaryDatabase(at: databaseURL) }
    try DatabaseBootstrap.prepare(at: databaseURL)

    let writer = try TaskRecordDatabase(path: databaseURL)
    let record = try writer.insertQueuedTask(
        kind: .ankiExport,
        fileName: "Deck.apkg",
        folderPath: "/Exports",
        itemCount: 5
    )
    try writer.updateState(id: record.id, to: .completed)

    let reader = try TaskRecordDatabase(path: databaseURL)
    #expect(try reader.records().map(\.state) == [.completed])
}

@Test
func aRenameRecordKeepsItsPathsOnePerLine() throws {
    let (database, databaseURL) = try makeTaskRecordDatabase()
    defer { removeTemporaryDatabase(at: databaseURL) }

    let inserted = try database.insertQueuedTask(
        kind: .renameFiles,
        fileName: "",
        folderPath: "",
        itemCount: 2,
        oldPaths: ["/Show/EP01.mkv", "/Show/EP01.srt"],
        newPaths: ["/Show/EP09.mkv", "/Show/EP09.srt"]
    )

    let record = try #require(try database.records().first)
    #expect(record.id == inserted.id)
    #expect(record.kind == .renameFiles)
    #expect(record.oldPaths == ["/Show/EP01.mkv", "/Show/EP01.srt"])
    #expect(record.newPaths == ["/Show/EP09.mkv", "/Show/EP09.srt"])
}
