import Foundation
import SQLite3
import Testing
@testable import CueSeekerCore

final class SearchProgressCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var snapshots: [SubtitleSearchProgressSnapshot] = []

    func append(_ snapshot: SubtitleSearchProgressSnapshot) {
        lock.lock()
        snapshots.append(snapshot)
        lock.unlock()
    }

    func values() -> [SubtitleSearchProgressSnapshot] {
        lock.lock()
        defer { lock.unlock() }
        return snapshots
    }
}

func excerptSelection(
    _ record: SubtitleCueLineRecord
) -> SubtitleCueTextSelection {
    SubtitleCueTextSelection(
        cueGroupID: record.cueGroupID,
        cueLineID: record.id,
        startMilliseconds: record.line.startMilliseconds,
        endMilliseconds: record.line.endMilliseconds,
        cueEventIndex: record.line.eventIndex,
        cueDisplayOrder: record.line.displayOrder,
        content: record.line.content
    )
}

func simpleTestEntry(text: String) -> SubtitleEntry {
    SubtitleEntry(
        sequenceNumber: 1,
        startTimecode: "00:00:01,000",
        endTimecode: "00:00:02,000",
        startMilliseconds: 1_000,
        endMilliseconds: 2_000,
        text: text
    )
}

func temporaryDatabaseURL() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerDatabaseTests-\(UUID().uuidString)")
        .appendingPathExtension("sqlite")
}

func removeTemporaryDatabase(at url: URL) {
    let fm = FileManager.default
    try? fm.removeItem(at: url)
    try? fm.removeItem(atPath: url.path + "-wal")
    try? fm.removeItem(atPath: url.path + "-shm")
}

func sqliteColumnNames(in table: String, databaseURL: URL) throws -> Set<String> {
    var database: OpaquePointer?
    guard sqlite3_open_v2(databaseURL.path, &database, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
        let message = database.map { String(cString: sqlite3_errmsg($0)) } ?? "Unknown SQLite error"
        sqlite3_close(database)
        throw DatabaseTestSQLiteError.openFailed(message)
    }

    defer {
        sqlite3_close(database)
    }

    var statement: OpaquePointer?
    guard sqlite3_prepare_v2(database, "PRAGMA table_info(\(table));", -1, &statement, nil) == SQLITE_OK,
          let statement
    else {
        let message = String(cString: sqlite3_errmsg(database))
        throw DatabaseTestSQLiteError.executeFailed(message)
    }

    defer {
        sqlite3_finalize(statement)
    }

    var names: Set<String> = []
    while sqlite3_step(statement) == SQLITE_ROW {
        guard let value = sqlite3_column_text(statement, 1) else {
            continue
        }
        names.insert(String(cString: value))
    }
    return names
}

func sqliteForeignKeyTables(in table: String, databaseURL: URL) throws -> Set<String> {
    var database: OpaquePointer?
    guard sqlite3_open_v2(databaseURL.path, &database, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
        let message = database.map { String(cString: sqlite3_errmsg($0)) } ?? "Unknown SQLite error"
        sqlite3_close(database)
        throw DatabaseTestSQLiteError.openFailed(message)
    }
    defer {
        sqlite3_close(database)
    }

    var statement: OpaquePointer?
    guard sqlite3_prepare_v2(
        database,
        "PRAGMA foreign_key_list(\(table));",
        -1,
        &statement,
        nil
    ) == SQLITE_OK,
    let statement
    else {
        throw DatabaseTestSQLiteError.executeFailed(String(cString: sqlite3_errmsg(database)))
    }
    defer {
        sqlite3_finalize(statement)
    }

    var tables = Set<String>()
    while sqlite3_step(statement) == SQLITE_ROW,
          let bytes = sqlite3_column_text(statement, 2)
    {
        tables.insert(String(cString: bytes))
    }
    return tables
}

func sqliteMediaIdentity(
    table: String,
    pathColumn: String,
    path: String,
    databaseURL: URL
) throws -> (libraryID: Int64, relativePath: String)? {
    var database: OpaquePointer?
    guard sqlite3_open_v2(databaseURL.path, &database, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
        let message = database.map { String(cString: sqlite3_errmsg($0)) } ?? "Unknown SQLite error"
        sqlite3_close(database)
        throw DatabaseTestSQLiteError.openFailed(message)
    }
    defer { sqlite3_close(database) }

    var statement: OpaquePointer?
    let sql = "SELECT library_id, relative_path FROM \(table) WHERE \(pathColumn) = ? LIMIT 1;"
    guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
          let statement
    else {
        throw DatabaseTestSQLiteError.executeFailed(String(cString: sqlite3_errmsg(database)))
    }
    defer { sqlite3_finalize(statement) }

    let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    sqlite3_bind_text(statement, 1, path, -1, transient)
    guard sqlite3_step(statement) == SQLITE_ROW,
          sqlite3_column_type(statement, 0) != SQLITE_NULL,
          let relativePath = sqlite3_column_text(statement, 1)
    else {
        return nil
    }
    return (sqlite3_column_int64(statement, 0), String(cString: relativePath))
}

func sqliteRowID(
    table: String,
    pathColumn: String,
    path: String,
    databaseURL: URL
) throws -> Int64? {
    try sqliteReferencedID(
        table: table,
        idColumn: "id",
        pathColumn: pathColumn,
        path: path,
        databaseURL: databaseURL
    )
}

func sqliteReferencedID(
    table: String,
    idColumn: String,
    pathColumn: String,
    path: String,
    databaseURL: URL
) throws -> Int64? {
    var database: OpaquePointer?
    guard sqlite3_open_v2(databaseURL.path, &database, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
        let message = database.map { String(cString: sqlite3_errmsg($0)) } ?? "Unknown SQLite error"
        sqlite3_close(database)
        throw DatabaseTestSQLiteError.openFailed(message)
    }
    defer { sqlite3_close(database) }

    var statement: OpaquePointer?
    let sql = "SELECT \(idColumn) FROM \(table) WHERE \(pathColumn) = ? LIMIT 1;"
    guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
          let statement
    else {
        throw DatabaseTestSQLiteError.executeFailed(String(cString: sqlite3_errmsg(database)))
    }
    defer { sqlite3_finalize(statement) }

    let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    sqlite3_bind_text(statement, 1, path, -1, transient)
    guard sqlite3_step(statement) == SQLITE_ROW,
          sqlite3_column_type(statement, 0) != SQLITE_NULL
    else {
        return nil
    }
    return sqlite3_column_int64(statement, 0)
}

func sqliteFTSRowID(cueGroupID: Int64, databaseURL: URL) throws -> Int64? {
    var database: OpaquePointer?
    guard sqlite3_open_v2(databaseURL.path, &database, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
        let message = database.map { String(cString: sqlite3_errmsg($0)) } ?? "Unknown SQLite error"
        sqlite3_close(database)
        throw DatabaseTestSQLiteError.openFailed(message)
    }
    defer { sqlite3_close(database) }

    var statement: OpaquePointer?
    guard sqlite3_prepare_v2(
        database,
        "SELECT rowid FROM subtitle_cue_groups_fts WHERE cue_group_id = ? LIMIT 1;",
        -1,
        &statement,
        nil
    ) == SQLITE_OK,
          let statement
    else {
        throw DatabaseTestSQLiteError.executeFailed(String(cString: sqlite3_errmsg(database)))
    }
    defer { sqlite3_finalize(statement) }

    sqlite3_bind_int64(statement, 1, cueGroupID)
    guard sqlite3_step(statement) == SQLITE_ROW else {
        return nil
    }
    return sqlite3_column_int64(statement, 0)
}

func sqliteCueLinesReferenceSubtitleFile(databaseURL: URL) throws -> Bool {
    var database: OpaquePointer?
    guard sqlite3_open_v2(databaseURL.path, &database, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
        let message = database.map { String(cString: sqlite3_errmsg($0)) } ?? "Unknown SQLite error"
        sqlite3_close(database)
        throw DatabaseTestSQLiteError.openFailed(message)
    }
    defer { sqlite3_close(database) }

    var statement: OpaquePointer?
    guard sqlite3_prepare_v2(
        database,
        """
        SELECT COUNT(*)
        FROM subtitle_cue_lines l
        JOIN subtitle_cue_groups g ON g.id = l.cue_group_id
        WHERE l.subtitle_file_id = g.subtitle_file_id;
        """,
        -1,
        &statement,
        nil
    ) == SQLITE_OK,
        let statement
    else {
        throw DatabaseTestSQLiteError.executeFailed(String(cString: sqlite3_errmsg(database)))
    }
    defer { sqlite3_finalize(statement) }

    return sqlite3_step(statement) == SQLITE_ROW && sqlite3_column_int64(statement, 0) > 0
}

func sqliteIndexExists(_ name: String, databaseURL: URL) throws -> Bool {
    var database: OpaquePointer?
    guard sqlite3_open_v2(databaseURL.path, &database, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
        let message = database.map { String(cString: sqlite3_errmsg($0)) } ?? "Unknown SQLite error"
        sqlite3_close(database)
        throw DatabaseTestSQLiteError.openFailed(message)
    }

    defer {
        sqlite3_close(database)
    }

    var statement: OpaquePointer?
    guard sqlite3_prepare_v2(
        database,
        "SELECT 1 FROM sqlite_master WHERE type = 'index' AND name = ? LIMIT 1;",
        -1,
        &statement,
        nil
    ) == SQLITE_OK,
        let statement
    else {
        let message = String(cString: sqlite3_errmsg(database))
        throw DatabaseTestSQLiteError.executeFailed(message)
    }

    defer {
        sqlite3_finalize(statement)
    }

    let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    sqlite3_bind_text(statement, 1, name, -1, transient)
    return sqlite3_step(statement) == SQLITE_ROW
}

func sqliteTableExists(_ name: String, databaseURL: URL) throws -> Bool {
    var database: OpaquePointer?
    guard sqlite3_open_v2(databaseURL.path, &database, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
        let message = database.map { String(cString: sqlite3_errmsg($0)) } ?? "Unknown SQLite error"
        sqlite3_close(database)
        throw DatabaseTestSQLiteError.openFailed(message)
    }

    defer {
        sqlite3_close(database)
    }

    var statement: OpaquePointer?
    guard sqlite3_prepare_v2(
        database,
        "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ? LIMIT 1;",
        -1,
        &statement,
        nil
    ) == SQLITE_OK,
        let statement
    else {
        let message = String(cString: sqlite3_errmsg(database))
        throw DatabaseTestSQLiteError.executeFailed(message)
    }

    defer {
        sqlite3_finalize(statement)
    }

    let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    sqlite3_bind_text(statement, 1, name, -1, transient)
    return sqlite3_step(statement) == SQLITE_ROW
}

func testCueGroup(
    startMilliseconds: Int,
    endMilliseconds: Int,
    content: String,
    eventIndex: Int,
    sourceStyle: String? = nil
) -> SubtitleCueGroup {
    SubtitleCueGroup(
        sequenceNumber: nil,
        startTimecode: "\(startMilliseconds)",
        endTimecode: "\(endMilliseconds)",
        startMilliseconds: startMilliseconds,
        endMilliseconds: endMilliseconds,
        searchContent: content,
        cueLines: [
            SubtitleCueLine(
                eventIndex: eventIndex,
                sourceFormat: .ass,
                sourceStyle: sourceStyle,
                sourceLayer: nil,
                startTimecode: "\(startMilliseconds)",
                endTimecode: "\(endMilliseconds)",
                startMilliseconds: startMilliseconds,
                endMilliseconds: endMilliseconds,
                content: content,
                displayX: nil,
                displayY: nil,
                displayOrder: 0
            )
        ]
    )
}

func testCueLine(
    eventIndex: Int,
    startMilliseconds: Int,
    endMilliseconds: Int,
    content: String,
    displayOrder: Int,
    sourceStyle: String? = nil
) -> SubtitleCueLine {
    SubtitleCueLine(
        eventIndex: eventIndex,
        sourceFormat: .ass,
        sourceStyle: sourceStyle,
        sourceLayer: nil,
        startTimecode: "\(startMilliseconds)",
        endTimecode: "\(endMilliseconds)",
        startMilliseconds: startMilliseconds,
        endMilliseconds: endMilliseconds,
        content: content,
        displayX: nil,
        displayY: nil,
        displayOrder: displayOrder
    )
}

func readCueGroupLineCounts(at url: URL) throws -> [Int64: Int] {
    var database: OpaquePointer?
    guard sqlite3_open_v2(url.path, &database, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
        let message = database.map { String(cString: sqlite3_errmsg($0)) } ?? "Unknown SQLite error"
        sqlite3_close(database)
        throw DatabaseTestSQLiteError.openFailed(message)
    }

    defer {
        sqlite3_close(database)
    }

    var statement: OpaquePointer?
    guard sqlite3_prepare_v2(database, "SELECT id, line_count FROM subtitle_cue_groups;", -1, &statement, nil) == SQLITE_OK,
          let statement
    else {
        let message = String(cString: sqlite3_errmsg(database))
        throw DatabaseTestSQLiteError.executeFailed(message)
    }

    defer {
        sqlite3_finalize(statement)
    }

    var result: [Int64: Int] = [:]
    while sqlite3_step(statement) == SQLITE_ROW {
        let id = sqlite3_column_int64(statement, 0)
        let count = Int(sqlite3_column_int64(statement, 1))
        result[id] = count
    }
    return result
}

func executeDatabaseTestSQLite(at url: URL, _ sql: String) throws {
    var database: OpaquePointer?
    guard sqlite3_open_v2(url.path, &database, SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE, nil) == SQLITE_OK else {
        let message = database.map { String(cString: sqlite3_errmsg($0)) } ?? "Unknown SQLite error"
        sqlite3_close(database)
        throw DatabaseTestSQLiteError.openFailed(message)
    }

    defer {
        sqlite3_close(database)
    }

    try executeDatabaseTestSQLite(database, sql)
}

func executeDatabaseTestSQLite(_ database: OpaquePointer?, _ sql: String) throws {
    var errorMessage: UnsafeMutablePointer<CChar>?
    guard sqlite3_exec(database, sql, nil, nil, &errorMessage) == SQLITE_OK else {
        let message = errorMessage.map { String(cString: $0) } ?? "Unknown SQLite error"
        sqlite3_free(errorMessage)
        throw DatabaseTestSQLiteError.executeFailed(message)
    }
}

func expectUnsupportedSchemaVersion(_ version: Int) throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        removeTemporaryDatabase(at: databaseURL)
    }

    try executeDatabaseTestSQLite(at: databaseURL, "PRAGMA user_version = \(version);")
    do {
        try DatabaseBootstrap.prepare(at: databaseURL)
        Issue.record("Expected schema \(version) to be rejected")
    } catch let error as DatabaseBootstrapError {
        #expect(error == .unsupportedSchemaVersion(
            found: version,
            supported: DatabaseBootstrap.currentSchemaVersion
        ))
    }
    #expect(try sqliteSchemaVersion(at: databaseURL) == version)
}

func sqliteSchemaVersion(at databaseURL: URL) throws -> Int {
    var database: OpaquePointer?
    guard sqlite3_open_v2(databaseURL.path, &database, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
        let message = database.map { String(cString: sqlite3_errmsg($0)) } ?? "Unknown SQLite error"
        sqlite3_close(database)
        throw DatabaseTestSQLiteError.openFailed(message)
    }
    defer {
        sqlite3_close(database)
    }

    var statement: OpaquePointer?
    guard sqlite3_prepare_v2(database, "PRAGMA user_version;", -1, &statement, nil) == SQLITE_OK,
          let statement
    else {
        throw DatabaseTestSQLiteError.executeFailed(String(cString: sqlite3_errmsg(database)))
    }
    defer {
        sqlite3_finalize(statement)
    }
    guard sqlite3_step(statement) == SQLITE_ROW else {
        throw DatabaseTestSQLiteError.executeFailed(String(cString: sqlite3_errmsg(database)))
    }
    return Int(sqlite3_column_int64(statement, 0))
}

func sqliteStringValue(at databaseURL: URL, sql: String) throws -> String? {
    var database: OpaquePointer?
    guard sqlite3_open_v2(
        databaseURL.path,
        &database,
        SQLITE_OPEN_READONLY,
        nil
    ) == SQLITE_OK
    else {
        let message = database.map {
            String(cString: sqlite3_errmsg($0))
        } ?? "Unknown SQLite error"
        sqlite3_close(database)
        throw DatabaseTestSQLiteError.openFailed(message)
    }
    defer {
        sqlite3_close(database)
    }

    var statement: OpaquePointer?
    guard sqlite3_prepare_v2(
        database,
        sql,
        -1,
        &statement,
        nil
    ) == SQLITE_OK,
    let statement
    else {
        throw DatabaseTestSQLiteError.executeFailed(
            String(cString: sqlite3_errmsg(database))
        )
    }
    defer {
        sqlite3_finalize(statement)
    }

    guard sqlite3_step(statement) == SQLITE_ROW,
          sqlite3_column_type(statement, 0) != SQLITE_NULL,
          let value = sqlite3_column_text(statement, 0)
    else {
        return nil
    }
    return String(cString: value)
}

func sqliteRowCount(in table: String, databaseURL: URL) throws -> Int {
    var database: OpaquePointer?
    guard sqlite3_open_v2(databaseURL.path, &database, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
        let message = database.map { String(cString: sqlite3_errmsg($0)) } ?? "Unknown SQLite error"
        sqlite3_close(database)
        throw DatabaseTestSQLiteError.openFailed(message)
    }
    defer {
        sqlite3_close(database)
    }

    var statement: OpaquePointer?
    guard sqlite3_prepare_v2(database, "SELECT COUNT(*) FROM \(table);", -1, &statement, nil) == SQLITE_OK,
          let statement
    else {
        throw DatabaseTestSQLiteError.executeFailed(String(cString: sqlite3_errmsg(database)))
    }
    defer {
        sqlite3_finalize(statement)
    }
    guard sqlite3_step(statement) == SQLITE_ROW else {
        throw DatabaseTestSQLiteError.executeFailed(String(cString: sqlite3_errmsg(database)))
    }
    return Int(sqlite3_column_int64(statement, 0))
}

func databaseTestEntry(text: String) -> SubtitleEntry {
    SubtitleEntry(
        sequenceNumber: 1,
        startTimecode: "00:00:01,000",
        endTimecode: "00:00:02,000",
        startMilliseconds: 1_000,
        endMilliseconds: 2_000,
        text: text
    )
}

func languageFilterTestEntry(sequenceNumber: Int, text: String) -> SubtitleEntry {
    let startMilliseconds = sequenceNumber * 1_000
    let endMilliseconds = startMilliseconds + 500
    return SubtitleEntry(
        sequenceNumber: sequenceNumber,
        startTimecode: String(format: "00:00:%02d,000", sequenceNumber),
        endTimecode: String(format: "00:00:%02d,500", sequenceNumber),
        startMilliseconds: startMilliseconds,
        endMilliseconds: endMilliseconds,
        text: text
    )
}

func languageFilterASSCueGroup(
    startMilliseconds: Int,
    lines: [(style: String?, content: String)]
) -> SubtitleCueGroup {
    let endMilliseconds = startMilliseconds + 1_000
    let cueLines = lines.enumerated().map { index, line in
        SubtitleCueLine(
            eventIndex: index,
            sourceFormat: .ass,
            sourceStyle: line.style,
            sourceLayer: 0,
            startTimecode: "\(startMilliseconds)",
            endTimecode: "\(endMilliseconds)",
            startMilliseconds: startMilliseconds,
            endMilliseconds: endMilliseconds,
            content: line.content,
            displayX: nil,
            displayY: nil,
            displayOrder: index
        )
    }
    return SubtitleCueGroup(
        sequenceNumber: nil,
        startTimecode: "\(startMilliseconds)",
        endTimecode: "\(endMilliseconds)",
        startMilliseconds: startMilliseconds,
        endMilliseconds: endMilliseconds,
        searchContent: lines.map(\.content).joined(separator: "\n"),
        cueLines: cueLines
    )
}

final class SearchDiagnosticRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var recordedEvents: [SubtitleSearchDiagnosticEvent] = []

    var events: [SubtitleSearchDiagnosticEvent] {
        lock.lock()
        defer {
            lock.unlock()
        }
        return recordedEvents
    }

    func record(_ event: SubtitleSearchDiagnosticEvent) {
        lock.lock()
        recordedEvents.append(event)
        lock.unlock()
    }
}

private enum DatabaseTestSQLiteError: Error {
    case openFailed(String)
    case executeFailed(String)
}

/// Turns a freshly prepared database's Excerpt tables, their indexes and the
/// Cue reference triggers back into what a database before schema 47 has, so
/// a fixture can start an older migration from the current schema.
let preSchema47ExcerptTablesSQL = """
    DROP TRIGGER protect_referenced_cue_deletion;
    DROP TRIGGER protect_referenced_tombstone_deletion;
    ALTER TABLE excerpt_lists RENAME TO shiori_lists;
    ALTER TABLE excerpts RENAME TO shioris;
    DROP INDEX idx_excerpt_lists_normalized_name;
    DROP INDEX idx_excerpts_list_order;
    DROP INDEX idx_excerpts_cue;
    DROP INDEX idx_excerpts_created_order;
    CREATE UNIQUE INDEX idx_shiori_lists_normalized_name
        ON shiori_lists(normalized_name);
    CREATE INDEX idx_shioris_list_order
        ON shioris(list_id, created_at DESC, id DESC);
    CREATE INDEX idx_shioris_cue
        ON shioris(cue_id);
    CREATE INDEX idx_shioris_created_order
        ON shioris(created_at DESC, id DESC);
    """
