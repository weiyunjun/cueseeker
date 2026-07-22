import Foundation

public final class DatabaseMaintenanceDatabase: @unchecked Sendable {
    public static let configuredBusyTimeoutMilliseconds = Int(SQLiteDatabase.busyTimeoutMilliseconds)
    public static let configuredCacheSizeKibibytes = SQLiteDatabase.cacheSizeKibibytes
    public static let configuredMmapSizeBytes = SQLiteDatabase.mmapSizeBytes

    private let path: URL
    private let database: SQLiteDatabase

    public init(
        path: URL,
        access: DatabaseConnectionAccess = .readWrite
    ) throws {
        self.path = path
        database = try SQLiteDatabase(path: path, access: access)
    }

    public func busyTimeoutMilliseconds() throws -> Int {
        try database.intPragma("busy_timeout")
    }

    public func journalMode() throws -> String {
        try database.stringPragma("journal_mode")
    }

    public func synchronousMode() throws -> Int {
        try database.intPragma("synchronous")
    }

    public func cacheSize() throws -> Int {
        try database.intPragma("cache_size")
    }

    public func mmapSize() throws -> Int {
        try database.intPragma("mmap_size")
    }

    public func storageStats() throws -> DatabaseStorageStats {
        DatabaseStorageStats(
            databaseFileBytes: Self.fileSize(at: path),
            walFileBytes: Self.fileSize(at: Self.sidecarPath(suffix: "-wal", for: path)),
            shmFileBytes: Self.fileSize(at: Self.sidecarPath(suffix: "-shm", for: path)),
            pageSize: try database.intPragma("page_size"),
            pageCount: try database.intPragma("page_count"),
            freelistCount: try database.intPragma("freelist_count"),
            autoVacuumMode: try database.intPragma("auto_vacuum")
        )
    }

    public func compactStorage() throws {
        try database.execute("PRAGMA wal_checkpoint(TRUNCATE);")
        try database.execute("VACUUM;")
        try database.execute("PRAGMA wal_checkpoint(TRUNCATE);")
    }


    private static func fileSize(at url: URL) -> Int64 {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        return (attributes?[.size] as? NSNumber)?.int64Value ?? 0
    }

    private static func sidecarPath(suffix: String, for path: URL) -> URL {
        URL(fileURLWithPath: path.path + suffix)
    }

}
