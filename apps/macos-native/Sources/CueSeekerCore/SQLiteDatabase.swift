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

public enum DatabaseConnectionAccess: Equatable, Sendable {
    case readOnly
    case readWrite
}

final class SQLiteDatabase: @unchecked Sendable {
    static let busyTimeoutMilliseconds: Int32 = 5_000
    static let cacheSizeKibibytes: Int = 20_000
    static let mmapSizeBytes: Int = 256 * 1024 * 1024

    private let lock = NSRecursiveLock()
    private var handle: OpaquePointer?

    init(
        path: URL,
        access: DatabaseConnectionAccess = .readWrite,
        directIO: Bool = false
    ) throws {
        var database: OpaquePointer?
        let flags = switch access {
        case .readOnly:
            SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX
        case .readWrite:
            SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        }

        guard sqlite3_open_v2(path.path, &database, flags, nil) == SQLITE_OK else {
            let message = database.map { String(cString: sqlite3_errmsg($0)) } ?? "Unknown SQLite error"
            sqlite3_close(database)
            throw SQLiteDatabaseError.openFailed(message)
        }

        handle = database
        if directIO {
            Self.enableDirectIO(for: path)
        }
        do {
            try configureConnection(access: access, directIO: directIO)
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
        try withConnectionLock {
            var errorMessage: UnsafeMutablePointer<CChar>?
            guard sqlite3_exec(handle, sql, nil, nil, &errorMessage) == SQLITE_OK else {
                let message = errorMessage.map { String(cString: $0) } ?? lastErrorMessage
                sqlite3_free(errorMessage)
                throw SQLiteDatabaseError.executeFailed(message)
            }
        }
    }

    func prepare(_ sql: String) throws -> SQLiteStatement {
        try withConnectionLock {
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK,
                  let statement
            else {
                throw SQLiteDatabaseError.prepareFailed(lastErrorMessage)
            }

            return SQLiteStatement(database: self, statement: statement)
        }
    }

    func lastInsertRowID() -> Int64 {
        withConnectionLock {
            sqlite3_last_insert_rowid(handle)
        }
    }

    func changesCount() -> Int {
        withConnectionLock {
            Int(sqlite3_changes(handle))
        }
    }

    func withImmediateTransaction<T>(_ body: () throws -> T) throws -> T {
        try withConnectionLock {
            try execute("BEGIN IMMEDIATE TRANSACTION")
            do {
                let result = try body()
                try execute("COMMIT")
                return result
            } catch {
                try? execute("ROLLBACK")
                throw error
            }
        }
    }

    func withReadTransaction<T>(_ body: () throws -> T) throws -> T {
        try withConnectionLock {
            let alreadyInTransaction = isInTransaction()
            if !alreadyInTransaction {
                try execute("BEGIN DEFERRED TRANSACTION")
            }
            do {
                let result = try body()
                if !alreadyInTransaction {
                    try execute("COMMIT")
                }
                return result
            } catch {
                if !alreadyInTransaction {
                    try? execute("ROLLBACK")
                }
                throw error
            }
        }
    }

    func isInTransaction() -> Bool {
        withConnectionLock {
            guard let handle else { return false }
            return sqlite3_get_autocommit(handle) == 0
        }
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
        withConnectionLock {
            guard let handle else {
                return "SQLite database is closed"
            }

            return String(cString: sqlite3_errmsg(handle))
        }
    }

    func withConnectionLock<T>(_ body: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try body()
    }

    private func configureConnection(
        access: DatabaseConnectionAccess,
        directIO: Bool
    ) throws {
        guard let handle else {
            throw SQLiteDatabaseError.openFailed("SQLite database is closed")
        }

        guard sqlite3_busy_timeout(handle, Self.busyTimeoutMilliseconds) == SQLITE_OK else {
            throw SQLiteDatabaseError.openFailed(lastErrorMessage)
        }

        if access == .readWrite {
            try execute("PRAGMA journal_mode = WAL")
            try execute("PRAGMA synchronous = NORMAL")
        } else {
            try execute("PRAGMA query_only = ON")
        }
        try execute("PRAGMA foreign_keys = ON")
        try execute("PRAGMA cache_size = -\(Self.cacheSizeKibibytes)")
        try execute("PRAGMA mmap_size = \(directIO ? 0 : Self.mmapSizeBytes)")
    }

    private static func enableDirectIO(for path: URL) {
        let targetPrefix = path.standardizedFileURL.path
        var pathBuffer = [CChar](repeating: 0, count: Int(MAXPATHLEN))
        for fd: Int32 in 3..<128 {
            if fcntl(fd, F_GETPATH, &pathBuffer) >= 0 {
                let openPath = String(cString: pathBuffer)
                if openPath.hasPrefix(targetPrefix) {
                    _ = fcntl(fd, F_NOCACHE, 1)
                    _ = fcntl(fd, F_RDAHEAD, 0)
                }
            }
        }
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
        _ = database.withConnectionLock {
            sqlite3_finalize(statement)
        }
    }

    func bind(_ value: String, at index: Int32) throws {
        try database.withConnectionLock {
            let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            guard sqlite3_bind_text(statement, index, value, -1, transient) == SQLITE_OK else {
                throw SQLiteDatabaseError.bindFailed(database.lastErrorMessage)
            }
        }
    }

    func bind(_ value: Int, at index: Int32) throws {
        try database.withConnectionLock {
            guard sqlite3_bind_int64(statement, index, Int64(value)) == SQLITE_OK else {
                throw SQLiteDatabaseError.bindFailed(database.lastErrorMessage)
            }
        }
    }

    func bind(_ value: Int64, at index: Int32) throws {
        try database.withConnectionLock {
            guard sqlite3_bind_int64(statement, index, value) == SQLITE_OK else {
                throw SQLiteDatabaseError.bindFailed(database.lastErrorMessage)
            }
        }
    }

    func bind(_ value: Double, at index: Int32) throws {
        try database.withConnectionLock {
            guard sqlite3_bind_double(statement, index, value) == SQLITE_OK else {
                throw SQLiteDatabaseError.bindFailed(database.lastErrorMessage)
            }
        }
    }

    func bindNull(at index: Int32) throws {
        try database.withConnectionLock {
            guard sqlite3_bind_null(statement, index) == SQLITE_OK else {
                throw SQLiteDatabaseError.bindFailed(database.lastErrorMessage)
            }
        }
    }

    func step() throws -> Bool {
        try database.withConnectionLock {
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
    }

    func run() throws {
        _ = try step()
    }

    func reset() throws {
        try database.withConnectionLock {
            guard sqlite3_reset(statement) == SQLITE_OK else {
                throw SQLiteDatabaseError.stepFailed(database.lastErrorMessage)
            }
        }
    }

    func clearBindings() throws {
        try database.withConnectionLock {
            guard sqlite3_clear_bindings(statement) == SQLITE_OK else {
                throw SQLiteDatabaseError.bindFailed(database.lastErrorMessage)
            }
        }
    }

    func int64Column(_ index: Int32) -> Int64 {
        database.withConnectionLock {
            sqlite3_column_int64(statement, index)
        }
    }

    func intColumn(_ index: Int32) -> Int {
        Int(sqlite3_column_int64(statement, index))
    }

    func nullableIntColumn(_ index: Int32) -> Int? {
        database.withConnectionLock {
            guard sqlite3_column_type(statement, index) != SQLITE_NULL else {
                return nil
            }

            return intColumn(index)
        }
    }

    func nullableInt64Column(_ index: Int32) -> Int64? {
        database.withConnectionLock {
            guard sqlite3_column_type(statement, index) != SQLITE_NULL else {
                return nil
            }

            return int64Column(index)
        }
    }

    func nullableDoubleColumn(_ index: Int32) -> Double? {
        database.withConnectionLock {
            guard sqlite3_column_type(statement, index) != SQLITE_NULL else {
                return nil
            }

            return sqlite3_column_double(statement, index)
        }
    }

    func stringColumn(_ index: Int32) -> String {
        database.withConnectionLock {
            guard let text = sqlite3_column_text(statement, index) else {
                return ""
            }

            return String(cString: text)
        }
    }

    func nullableStringColumn(_ index: Int32) -> String? {
        database.withConnectionLock {
            guard sqlite3_column_type(statement, index) != SQLITE_NULL else {
                return nil
            }

            return stringColumn(index)
        }
    }
}
