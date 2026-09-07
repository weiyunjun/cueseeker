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
    defer { try? FileManager.default.removeItem(at: databaseURL) }

    try DatabaseBootstrap.prepare(at: databaseURL)

    #expect(try sqliteTableExists("task_records", databaseURL: databaseURL))
    #expect(
        try sqliteColumnNames(in: "task_records", databaseURL: databaseURL) == [
            "id", "kind", "file_name", "folder_path", "item_count",
            "state", "error_message", "created_at", "state_changed_at",
            "old_paths", "new_paths"
        ]
    )
}

@Test
func queuedTaskIsReadBackWithWhatItWillWrite() throws {
    let (database, databaseURL) = try makeTaskRecordDatabase()
    defer { try? FileManager.default.removeItem(at: databaseURL) }

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
}

@Test
func recordsComeBackOldestFirst() throws {
    let (database, databaseURL) = try makeTaskRecordDatabase()
    defer { try? FileManager.default.removeItem(at: databaseURL) }

    for index in 1...3 {
        _ = try database.insertQueuedTask(
            kind: .ankiExport,
            fileName: "Deck\(index).apkg",
            folderPath: "/Exports",
            itemCount: index
        )
    }

    #expect(try database.records().map(\.fileName) == [
        "Deck1.apkg", "Deck2.apkg", "Deck3.apkg"
    ])
}

@Test
func stateAndErrorAreWrittenThrough() throws {
    let (database, databaseURL) = try makeTaskRecordDatabase()
    defer { try? FileManager.default.removeItem(at: databaseURL) }

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
    defer { try? FileManager.default.removeItem(at: databaseURL) }

    let running = try database.insertQueuedTask(
        kind: .ankiExport,
        fileName: "Running.apkg",
        folderPath: "/Exports",
        itemCount: 10
    )
    try database.updateState(id: running.id, to: .running)
    _ = try database.insertQueuedTask(
        kind: .ankiExport,
        fileName: "Queued.apkg",
        folderPath: "/Exports",
        itemCount: 20
    )
    let finished = try database.insertQueuedTask(
        kind: .ankiExport,
        fileName: "Done.apkg",
        folderPath: "/Exports",
        itemCount: 30
    )
    try database.updateState(id: finished.id, to: .completed)

    let closed = try database.markUnfinishedTasksIncomplete(message: "Interrupted")

    #expect(closed == 2)
    let records = try database.records()
    #expect(records.map(\.state) == [.incomplete, .incomplete, .completed])
    #expect(records[0].errorMessage == "Interrupted")
    #expect(records[1].errorMessage == "Interrupted")
    #expect(records[2].errorMessage == nil)
}

@Test
func deletedRecordDoesNotComeBack() throws {
    let (database, databaseURL) = try makeTaskRecordDatabase()
    defer { try? FileManager.default.removeItem(at: databaseURL) }

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
    defer { try? FileManager.default.removeItem(at: databaseURL) }
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
    defer { try? FileManager.default.removeItem(at: databaseURL) }

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
