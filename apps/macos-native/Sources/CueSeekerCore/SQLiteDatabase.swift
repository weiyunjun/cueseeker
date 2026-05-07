import Foundation
import SQLite3

public enum SQLiteDatabaseError: Error, Equatable, CustomStringConvertible {
    case openFailed(String)
    case prepareFailed(String)
    case executeFailed(String)
    case bindFailed(String)
    case stepFailed(String)

    public var description: String {
        switch self {
        case .openFailed(let message):
            "Open failed: \(message)"
        case .prepareFailed(let message):
            "Prepare failed: \(message)"
        case .executeFailed(let message):
            "Execute failed: \(message)"
        case .bindFailed(let message):
            "Bind failed: \(message)"
        case .stepFailed(let message):
            "Step failed: \(message)"
        }
    }
}

final class SQLiteDatabase {
    static let busyTimeoutMilliseconds: Int32 = 5_000

    private var handle: OpaquePointer?

    init(path: URL) throws {
        var database: OpaquePointer?
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX

        guard sqlite3_open_v2(path.path, &database, flags, nil) == SQLITE_OK else {
            let message = database.map { String(cString: sqlite3_errmsg($0)) } ?? "Unknown SQLite error"
            sqlite3_close(database)
            throw SQLiteDatabaseError.openFailed(message)
        }

        handle = database
        do {
            try configureConnection()
        } catch {
            sqlite3_close(handle)
            handle = nil
            throw error
        }
    }

    deinit {
        sqlite3_close(handle)
    }

    func execute(_ sql: String) throws {
        var errorMessage: UnsafeMutablePointer<CChar>?
        guard sqlite3_exec(handle, sql, nil, nil, &errorMessage) == SQLITE_OK else {
            let message = errorMessage.map { String(cString: $0) } ?? lastErrorMessage
            sqlite3_free(errorMessage)
            throw SQLiteDatabaseError.executeFailed(message)
        }
    }

    func prepare(_ sql: String) throws -> SQLiteStatement {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK,
              let statement
        else {
            throw SQLiteDatabaseError.prepareFailed(lastErrorMessage)
        }

        return SQLiteStatement(database: self, statement: statement)
    }

    func lastInsertRowID() -> Int64 {
        sqlite3_last_insert_rowid(handle)
    }

    func intPragma(_ name: String) throws -> Int {
        let statement = try prepare("PRAGMA \(name);")
        guard try statement.step() else {
            return 0
        }

        return statement.intColumn(0)
    }

    func stringPragma(_ name: String) throws -> String {
        let statement = try prepare("PRAGMA \(name);")
        guard try statement.step() else {
            return ""
        }

        return statement.stringColumn(0)
    }

    var lastErrorMessage: String {
        guard let handle else {
            return "SQLite database is closed"
        }

        return String(cString: sqlite3_errmsg(handle))
    }

    private func configureConnection() throws {
        guard let handle else {
            throw SQLiteDatabaseError.openFailed("SQLite database is closed")
        }

        guard sqlite3_busy_timeout(handle, Self.busyTimeoutMilliseconds) == SQLITE_OK else {
            throw SQLiteDatabaseError.openFailed(lastErrorMessage)
        }

        try execute("PRAGMA journal_mode = WAL")
        try execute("PRAGMA synchronous = NORMAL")
        try execute("PRAGMA foreign_keys = ON")
    }
}

final class SQLiteStatement {
    private let database: SQLiteDatabase
    private let statement: OpaquePointer

    init(database: SQLiteDatabase, statement: OpaquePointer) {
        self.database = database
        self.statement = statement
    }

    deinit {
        sqlite3_finalize(statement)
    }

    func bind(_ value: String, at index: Int32) throws {
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        guard sqlite3_bind_text(statement, index, value, -1, transient) == SQLITE_OK else {
            throw SQLiteDatabaseError.bindFailed(database.lastErrorMessage)
        }
    }

    func bind(_ value: Int, at index: Int32) throws {
        guard sqlite3_bind_int64(statement, index, Int64(value)) == SQLITE_OK else {
            throw SQLiteDatabaseError.bindFailed(database.lastErrorMessage)
        }
    }

    func bind(_ value: Int64, at index: Int32) throws {
        guard sqlite3_bind_int64(statement, index, value) == SQLITE_OK else {
            throw SQLiteDatabaseError.bindFailed(database.lastErrorMessage)
        }
    }

    func bind(_ value: Double, at index: Int32) throws {
        guard sqlite3_bind_double(statement, index, value) == SQLITE_OK else {
            throw SQLiteDatabaseError.bindFailed(database.lastErrorMessage)
        }
    }

    func bindNull(at index: Int32) throws {
        guard sqlite3_bind_null(statement, index) == SQLITE_OK else {
            throw SQLiteDatabaseError.bindFailed(database.lastErrorMessage)
        }
    }

    func step() throws -> Bool {
        let result = sqlite3_step(statement)
        switch result {
        case SQLITE_ROW:
            return true
        case SQLITE_DONE:
            return false
        default:
            throw SQLiteDatabaseError.stepFailed(database.lastErrorMessage)
        }
    }

    func run() throws {
        _ = try step()
    }

    func reset() throws {
        guard sqlite3_reset(statement) == SQLITE_OK else {
            throw SQLiteDatabaseError.stepFailed(database.lastErrorMessage)
        }
    }

    func clearBindings() throws {
        guard sqlite3_clear_bindings(statement) == SQLITE_OK else {
            throw SQLiteDatabaseError.bindFailed(database.lastErrorMessage)
        }
    }

    func int64Column(_ index: Int32) -> Int64 {
        sqlite3_column_int64(statement, index)
    }

    func intColumn(_ index: Int32) -> Int {
        Int(sqlite3_column_int64(statement, index))
    }

    func nullableIntColumn(_ index: Int32) -> Int? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL else {
            return nil
        }

        return intColumn(index)
    }

    func nullableInt64Column(_ index: Int32) -> Int64? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL else {
            return nil
        }

        return int64Column(index)
    }

    func nullableDoubleColumn(_ index: Int32) -> Double? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL else {
            return nil
        }

        return sqlite3_column_double(statement, index)
    }

    func stringColumn(_ index: Int32) -> String {
        guard let text = sqlite3_column_text(statement, index) else {
            return ""
        }

        return String(cString: text)
    }

    func nullableStringColumn(_ index: Int32) -> String? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL else {
            return nil
        }

        return stringColumn(index)
    }
}
