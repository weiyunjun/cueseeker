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
func migratesSchema33ShioriListMetadataWithoutDroppingTheList() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    try executeDatabaseTestSQLite(
        at: databaseURL,
        """
        CREATE TABLE shiori_lists (
            id INTEGER PRIMARY KEY,
            name TEXT NOT NULL,
            created_at TEXT NOT NULL
        );
        INSERT INTO shiori_lists(id, name, created_at)
        VALUES (1, 'Shiori', '1970-01-01T00:00:00Z');
        PRAGMA user_version = 33;
        """
    )

    try DatabaseBootstrap.prepare(at: databaseURL)

    #expect(try sqliteSchemaVersion(at: databaseURL) == DatabaseBootstrap.currentSchemaVersion)
    #expect(try sqliteColumnNames(in: "shiori_lists", databaseURL: databaseURL) == Set([
        "id", "name", "normalized_name", "description", "cover_path", "created_at"
    ]))
    #expect(try sqliteIndexExists(
        "idx_shiori_lists_normalized_name",
        databaseURL: databaseURL
    ))
    let list = try #require(try ShioriDatabase(path: databaseURL).shioriLists().first)
    #expect(list.name == "Default")
    #expect(list.description.isEmpty)
    #expect(list.coverPath == nil)
    #expect(list.createdAt == "1970-01-01T00:00:00Z")
}

@Test
func rejectsUnsupportedLowerSchemaWithoutChangingVersion() throws {
    try expectUnsupportedSchemaVersion(32)
}

@Test
func rejectsNewerSchemaWithoutChangingVersion() throws {
    try expectUnsupportedSchemaVersion(35)
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
    #expect(try sqliteColumnNames(in: "shiori_lists", databaseURL: databaseURL) == Set([
        "id", "name", "normalized_name", "description", "cover_path", "created_at"
    ]))
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
