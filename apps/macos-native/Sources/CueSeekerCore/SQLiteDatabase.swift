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
    static let slowOperationThresholdMilliseconds: Double = 20.0

    private let lock = NSRecursiveLock()
    private var handle: OpaquePointer?

    init(path: URL, access: DatabaseConnectionAccess = .readWrite) throws {
        let start = DispatchTime.now().uptimeNanoseconds
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
        do {
            try configureConnection(access: access)
        } catch {
            sqlite3_close(handle)
            handle = nil
            throw error
        }
        let duration = Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000
        if duration >= Self.slowOperationThresholdMilliseconds {
            fputs(String(format: "[SQLITE_SLOW_OPEN] isMain=%d duration=%.2fms path=%@\n", Thread.isMainThread ? 1 : 0, duration, path.path), stderr)
            fflush(stderr)
        }
    }

    deinit {
        let start = DispatchTime.now().uptimeNanoseconds
        sqlite3_close(handle)
        let duration = Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000
        if duration >= Self.slowOperationThresholdMilliseconds {
            fputs(String(format: "[SQLITE_SLOW_CLOSE] isMain=%d duration=%.2fms\n", Thread.isMainThread ? 1 : 0, duration), stderr)
            fflush(stderr)
        }
    }

    func execute(_ sql: String) throws {
        let start = DispatchTime.now().uptimeNanoseconds
        try withConnectionLock {
            var errorMessage: UnsafeMutablePointer<CChar>?
            guard sqlite3_exec(handle, sql, nil, nil, &errorMessage) == SQLITE_OK else {
                let message = errorMessage.map { String(cString: $0) } ?? lastErrorMessage
                sqlite3_free(errorMessage)
                throw SQLiteDatabaseError.executeFailed(message)
            }
        }
        let duration = Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000
        if duration >= Self.slowOperationThresholdMilliseconds {
            fputs(String(format: "[SQLITE_SLOW_EXEC] isMain=%d duration=%.2fms sql=%@\n", Thread.isMainThread ? 1 : 0, duration, sql), stderr)
            fflush(stderr)
        }
    }

    func prepare(_ sql: String) throws -> SQLiteStatement {
        let start = DispatchTime.now().uptimeNanoseconds
        let statement = try withConnectionLock {
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK,
                  let statement
            else {
                throw SQLiteDatabaseError.prepareFailed(lastErrorMessage)
            }

            return SQLiteStatement(database: self, statement: statement)
        }
        let duration = Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000
        if duration >= Self.slowOperationThresholdMilliseconds {
            fputs(String(format: "[SQLITE_SLOW_PREPARE] isMain=%d duration=%.2fms sql=%@\n", Thread.isMainThread ? 1 : 0, duration, sql), stderr)
            fflush(stderr)
        }
        return statement
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
        let start = DispatchTime.now().uptimeNanoseconds
        fputs(String(format: "[SQLITE_TX_BEGIN] isMain=%d\n", Thread.isMainThread ? 1 : 0), stderr)
        fflush(stderr)
        return try withConnectionLock {
            try execute("BEGIN IMMEDIATE TRANSACTION")
            do {
                let result = try body()
                try execute("COMMIT")
                let duration = Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000
                fputs(String(format: "[SQLITE_TX_COMMIT] isMain=%d duration=%.2fms\n", Thread.isMainThread ? 1 : 0, duration), stderr)
                fflush(stderr)
                return result
            } catch {
                try? execute("ROLLBACK")
                let duration = Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000
                fputs(String(format: "[SQLITE_TX_ROLLBACK] isMain=%d duration=%.2fms error=%@\n", Thread.isMainThread ? 1 : 0, duration, error.localizedDescription), stderr)
                fflush(stderr)
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
        let lockWaitStart = DispatchTime.now().uptimeNanoseconds
        lock.lock()
        defer { lock.unlock() }
        let lockWaitDuration = Double(DispatchTime.now().uptimeNanoseconds - lockWaitStart) / 1_000_000
        if lockWaitDuration >= Self.slowOperationThresholdMilliseconds {
            fputs(String(format: "[SQLITE_LOCK_WAIT] isMain=%d wait=%.2fms\n", Thread.isMainThread ? 1 : 0, lockWaitDuration), stderr)
            fflush(stderr)
        }
        return try body()
    }

    private func configureConnection(access: DatabaseConnectionAccess) throws {
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
        try execute("PRAGMA mmap_size = \(Self.mmapSizeBytes)")
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
        let start = DispatchTime.now().uptimeNanoseconds
        let result = try database.withConnectionLock {
            let res = sqlite3_step(statement)
            switch res {
            case SQLITE_ROW:
                return true
            case SQLITE_DONE:
                return false
            default:
                throw SQLiteDatabaseError.stepFailed(database.lastErrorMessage)
            }
        }
        let duration = Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000
        if duration >= SQLiteDatabase.slowOperationThresholdMilliseconds {
            fputs(String(format: "[SQLITE_SLOW_STEP] isMain=%d duration=%.2fms\n", Thread.isMainThread ? 1 : 0, duration), stderr)
            fflush(stderr)
        }
        return result
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
