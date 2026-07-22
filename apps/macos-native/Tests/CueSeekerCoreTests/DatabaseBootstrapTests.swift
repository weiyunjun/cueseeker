import Foundation
import Testing
@testable import CueSeekerCore

@Test
func migratesFreshDatabaseToCurrentSchemaVersion() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    try DatabaseBootstrap.prepare(at: databaseURL)

    #expect(try sqliteSchemaVersion(at: databaseURL) == DatabaseBootstrap.currentSchemaVersion)
}

@Test
func currentSchemaValidationDoesNotMutateStoredData() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    try DatabaseBootstrap.prepare(at: databaseURL)
    let database = try IndexingDatabase(path: databaseURL)
    let folder = URL(fileURLWithPath: "/Media/Current Schema")
    _ = try database.addSearchPath(folder)

    try DatabaseBootstrap.prepare(at: databaseURL)

    #expect(try sqliteSchemaVersion(at: databaseURL) == DatabaseBootstrap.currentSchemaVersion)
    #expect(try sqliteRowCount(in: "search_paths", databaseURL: databaseURL) == 1)
}

@Test
func rejectsUnsupportedLowerSchemaWithoutChangingVersion() throws {
    try expectUnsupportedSchemaVersion(32)
}

@Test
func rejectsNewerSchemaWithoutChangingVersion() throws {
    try expectUnsupportedSchemaVersion(34)
}

@Test
func readOnlyConnectionDoesNotCreateMissingDatabase() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    #expect(throws: (any Error).self) {
        _ = try IndexingDatabase(path: databaseURL, access: .readOnly)
    }
    #expect(!FileManager.default.fileExists(atPath: databaseURL.path))
}

@Test
func readOnlyConnectionRejectsWrites() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    try DatabaseBootstrap.prepare(at: databaseURL)
    let database = try IndexingDatabase(path: databaseURL, access: .readOnly)

    #expect(throws: SQLiteDatabaseError.self) {
        _ = try database.addSearchPath(URL(fileURLWithPath: "/Media/Read Only"))
    }
    #expect(try sqliteRowCount(in: "search_paths", databaseURL: databaseURL) == 0)
}

@Test
func freshSchemaOmitsLegacyPlaybackNavigationTables() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    try DatabaseBootstrap.prepare(at: databaseURL)

    #expect(try sqliteTableExists(
        "playback_navigation_state",
        databaseURL: databaseURL
    ) == false)
    #expect(try sqliteTableExists(
        "playback_navigation_entries",
        databaseURL: databaseURL
    ) == false)
}

@Test
func permanentIdentitySchemaIncludesLibraryRelativePathsAndIDReferences() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    try DatabaseBootstrap.prepare(at: databaseURL)

    #expect(try sqliteColumnNames(in: "subtitle_files", databaseURL: databaseURL).isSuperset(of: [
        "id", "library_id", "relative_path"
    ]))
    #expect(try sqliteColumnNames(in: "video_files", databaseURL: databaseURL).isSuperset(of: [
        "id", "library_id", "relative_path"
    ]))
    #expect(try sqliteColumnNames(in: "subtitle_cue_lines", databaseURL: databaseURL).isSuperset(of: [
        "id", "subtitle_file_id"
    ]))
    #expect(try sqliteColumnNames(in: "library_playback_history", databaseURL: databaseURL).contains("video_file_id"))
    #expect(try sqliteColumnNames(in: "library_watch_states", databaseURL: databaseURL).contains("video_file_id"))
    #expect(try sqliteColumnNames(in: "library_video_rows", databaseURL: databaseURL).isSuperset(of: [
        "video_file_id", "subtitle_file_id"
    ]))
    #expect(try sqliteColumnNames(in: "subtitle_search_order_rows", databaseURL: databaseURL).contains("subtitle_file_id"))
    #expect(try sqliteColumnNames(in: "shioris", databaseURL: databaseURL) == Set([
        "id", "list_id", "cue_id", "created_at"
    ]))
    #expect(try sqliteTableExists("shiori_lists", databaseURL: databaseURL))
}

@Test
func sqliteConnectionsUseBusyTimeoutAndWALMode() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    try DatabaseBootstrap.prepare(at: databaseURL)
    let database = try DatabaseMaintenanceDatabase(path: databaseURL)

    #expect(try database.busyTimeoutMilliseconds() == DatabaseMaintenanceDatabase.configuredBusyTimeoutMilliseconds)
    #expect(try database.journalMode().lowercased() == "wal")
    #expect(try database.synchronousMode() == 1)
    #expect(try database.cacheSize() == -DatabaseMaintenanceDatabase.configuredCacheSizeKibibytes)
    #expect(try database.mmapSize() == DatabaseMaintenanceDatabase.configuredMmapSizeBytes)
}

@Test
func freshSchemaCreatesShioriTablePerformanceIndexes() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    try DatabaseBootstrap.prepare(at: databaseURL)

    #expect(try sqliteIndexExists("idx_shioris_created_order", databaseURL: databaseURL))
    #expect(try sqliteIndexExists("idx_subtitle_cue_groups_file_time", databaseURL: databaseURL))
}

@Test
func freshSchemaCreatesShioriTagTablesAndIndexes() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    try DatabaseBootstrap.prepare(at: databaseURL)

    #expect(try sqliteTableExists("shiori_tags", databaseURL: databaseURL))
    #expect(try sqliteTableExists("shiori_tag_assignments", databaseURL: databaseURL))
    #expect(try sqliteIndexExists("idx_shiori_tags_name", databaseURL: databaseURL))
    #expect(try sqliteIndexExists("idx_shiori_tag_assignments_tag", databaseURL: databaseURL))
    #expect(try sqliteIndexExists("idx_shiori_tag_assignments_shiori", databaseURL: databaseURL))
}
