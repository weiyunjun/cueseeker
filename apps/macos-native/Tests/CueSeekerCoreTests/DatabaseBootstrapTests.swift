import Foundation
import Testing
@testable import CueSeekerCore

private let cueTombstoneFixtureSchemaSQL = """
    CREATE TABLE cue_tombstones (
        cue_id INTEGER PRIMARY KEY,
        subtitle_file_id INTEGER NOT NULL,
        source_format TEXT NOT NULL,
        source_style TEXT,
        source_identity_remainder TEXT NOT NULL DEFAULT '',
        start_time TEXT NOT NULL,
        end_time TEXT NOT NULL,
        start_ms INTEGER NOT NULL,
        end_ms INTEGER NOT NULL,
        content TEXT NOT NULL,
        cue_group_content TEXT NOT NULL,
        display_title TEXT NOT NULL,
        subtitle_path TEXT,
        video_path TEXT,
        unavailable_reason TEXT NOT NULL,
        tombstoned_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
    );
    """

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
func migratesSchema41DanglingShioriToProtectedTombstone() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    try DatabaseBootstrap.prepare(at: databaseURL)
    try executeDatabaseTestSQLite(
        at: databaseURL,
        """
        DROP TRIGGER protect_referenced_cue_deletion;
        DROP TRIGGER protect_referenced_tombstone_deletion;
        INSERT INTO shioris(id, list_id, cue_id, created_at)
        VALUES (780, 1, 9007505, '2026-08-03T13:27:29Z');
        PRAGMA user_version = 41;
        """
    )

    try DatabaseBootstrap.prepare(at: databaseURL)

    let repaired = try #require(
        try ShioriDatabase(path: databaseURL).shiori(id: 780)
    )
    #expect(repaired.unavailableReason == .cueMissing)
    #expect(repaired.content.isEmpty)
    #expect(
        try sqliteStringValue(
            at: databaseURL,
            sql: "SELECT unavailable_reason FROM cue_tombstones WHERE cue_id = 9007505;"
        ) == "cue_missing"
    )
    #expect(
        try sqliteStringValue(
            at: databaseURL,
            sql: "SELECT source_format FROM cue_tombstones WHERE cue_id = 9007505;"
        ) == ""
    )
    #expect(throws: (any Error).self) {
        try executeDatabaseTestSQLite(
            at: databaseURL,
            "DELETE FROM cue_tombstones WHERE cue_id = 9007505;"
        )
    }
    #expect(try sqliteRowCount(in: "cue_tombstones", databaseURL: databaseURL) == 1)
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
        CREATE TABLE search_paths (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            type TEXT NOT NULL DEFAULT 'local',
            path TEXT NOT NULL UNIQUE,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
        );
        CREATE TABLE subtitle_files (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            library_id INTEGER,
            relative_path TEXT,
            subtitle_path TEXT NOT NULL UNIQUE,
            format TEXT NOT NULL,
            file_size INTEGER,
            modified_at REAL,
            indexed_at TEXT NOT NULL,
            index_algorithm_version INTEGER NOT NULL DEFAULT 0
        );
        CREATE TABLE video_files (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            library_id INTEGER,
            relative_path TEXT,
            path TEXT NOT NULL UNIQUE,
            video_name TEXT NOT NULL,
            file_size INTEGER,
            modified_at REAL
        );
        CREATE TABLE subtitle_cue_lines (
            id INTEGER PRIMARY KEY AUTOINCREMENT
        );
        CREATE TABLE shiori_lists (
            id INTEGER PRIMARY KEY,
            name TEXT NOT NULL,
            created_at TEXT NOT NULL
        );
        CREATE TABLE shioris (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            list_id INTEGER NOT NULL,
            cue_id INTEGER NOT NULL,
            created_at TEXT NOT NULL,
            UNIQUE(list_id, cue_id),
            FOREIGN KEY(list_id) REFERENCES shiori_lists(id) ON DELETE CASCADE,
            FOREIGN KEY(cue_id) REFERENCES subtitle_cue_lines(id) ON DELETE CASCADE
        );
        CREATE TABLE shiori_tags (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            normalized_name TEXT NOT NULL UNIQUE,
            created_at TEXT NOT NULL
        );
        CREATE TABLE shiori_tag_assignments (
            shiori_id INTEGER NOT NULL,
            tag_id INTEGER NOT NULL,
            created_at TEXT NOT NULL,
            PRIMARY KEY(shiori_id, tag_id),
            FOREIGN KEY(shiori_id) REFERENCES shioris(id) ON DELETE CASCADE,
            FOREIGN KEY(tag_id) REFERENCES shiori_tags(id) ON DELETE CASCADE
        );
        CREATE TABLE folder_covers (
            folder_path TEXT PRIMARY KEY,
            cover_path TEXT NOT NULL,
            source_video_file_id INTEGER NOT NULL,
            generated_at TEXT NOT NULL
        );
        CREATE TABLE user_folder_covers (
            folder_path TEXT PRIMARY KEY,
            display_cover_path TEXT NOT NULL,
            updated_at TEXT NOT NULL
        );
        INSERT INTO shiori_lists(id, name, created_at)
        VALUES (1, 'Shiori', '1970-01-01T00:00:00Z');
        PRAGMA user_version = 33;
        """
    )

    try DatabaseBootstrap.prepare(at: databaseURL)

    #expect(try sqliteSchemaVersion(at: databaseURL) == DatabaseBootstrap.currentSchemaVersion)
    #expect(try sqliteColumnNames(in: "shiori_lists", databaseURL: databaseURL) == Set([
        "id", "name", "normalized_name", "description", "cover_path", "created_at",
        "recent_cue_id", "recent_sort_order", "recent_played_at"
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
    try expectUnsupportedSchemaVersion(43)
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
    #expect(try sqliteTableExists(
        "subtitle_cue_line_speakers",
        databaseURL: databaseURL
    ) == false)
    #expect(try sqliteTableExists(
        "ai_chunk_cache_entries",
        databaseURL: databaseURL
    ) == false)
}

@Test
func migratesSchema38ByDroppingOnlySpeakerAndAICacheStorage() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }
    try executeDatabaseTestSQLite(
        at: databaseURL,
        """
        CREATE TABLE subtitle_cue_lines (
            id INTEGER PRIMARY KEY,
            content TEXT NOT NULL
        );
        CREATE TABLE subtitle_cue_group_languages (
            cue_group_id INTEGER NOT NULL,
            language_code TEXT NOT NULL
        );
        CREATE TABLE shioris (
            id INTEGER PRIMARY KEY,
            cue_id INTEGER NOT NULL
        );
        \(cueTombstoneFixtureSchemaSQL)
        CREATE VIRTUAL TABLE subtitle_cue_groups_fts USING fts5(
            content,
            cue_group_id UNINDEXED
        );
        CREATE TABLE subtitle_cue_line_speakers (
            cue_line_id INTEGER NOT NULL,
            cue_group_id INTEGER NOT NULL,
            speaker TEXT NOT NULL,
            speaker_key TEXT NOT NULL,
            PRIMARY KEY(cue_line_id, speaker_key)
        );
        CREATE INDEX idx_subtitle_cue_line_speakers_group
            ON subtitle_cue_line_speakers(cue_group_id, speaker_key);
        CREATE INDEX idx_subtitle_cue_line_speakers_speaker
            ON subtitle_cue_line_speakers(speaker_key, cue_group_id);
        CREATE TABLE ai_chunk_cache_entries (
            id INTEGER PRIMARY KEY,
            normalized_sentence TEXT NOT NULL
        );
        CREATE INDEX idx_ai_chunk_cache_entries_lookup
            ON ai_chunk_cache_entries(normalized_sentence);

        INSERT INTO subtitle_cue_lines(id, content) VALUES (1, 'retained cue');
        INSERT INTO subtitle_cue_group_languages(cue_group_id, language_code)
            VALUES (10, 'ja');
        INSERT INTO shioris(id, cue_id) VALUES (20, 1);
        INSERT INTO subtitle_cue_groups_fts(content, cue_group_id)
            VALUES ('retained search', 10);
        INSERT INTO subtitle_cue_line_speakers(
            cue_line_id, cue_group_id, speaker, speaker_key
        ) VALUES (1, 10, 'legacy', 'legacy');
        INSERT INTO ai_chunk_cache_entries(id, normalized_sentence)
            VALUES (1, 'legacy');
        PRAGMA user_version = 38;
        """
    )

    try DatabaseBootstrap.prepare(at: databaseURL)

    #expect(try sqliteSchemaVersion(at: databaseURL) == DatabaseBootstrap.currentSchemaVersion)
    #expect(try sqliteTableExists("subtitle_cue_line_speakers", databaseURL: databaseURL) == false)
    #expect(try sqliteTableExists("ai_chunk_cache_entries", databaseURL: databaseURL) == false)
    #expect(try sqliteRowCount(in: "subtitle_cue_lines", databaseURL: databaseURL) == 1)
    #expect(try sqliteRowCount(in: "subtitle_cue_group_languages", databaseURL: databaseURL) == 1)
    #expect(try sqliteRowCount(in: "shioris", databaseURL: databaseURL) == 1)
    #expect(try sqliteRowCount(in: "subtitle_cue_groups_fts", databaseURL: databaseURL) == 1)
}

@Test
func permanentIdentitySchemaIncludesLibraryRelativePathsAndIDReferences() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    try DatabaseBootstrap.prepare(at: databaseURL)

    #expect(try sqliteColumnNames(in: "subtitle_files", databaseURL: databaseURL).isSuperset(of: [
        "id", "library_id", "folder_id", "relative_path", "last_known_path",
        "resource_identity", "content_fingerprint", "binding_state", "last_seen_at"
    ]))
    #expect(try sqliteColumnNames(in: "video_files", databaseURL: databaseURL).isSuperset(of: [
        "id", "library_id", "folder_id", "relative_path", "last_known_path",
        "resource_identity", "content_fingerprint", "binding_state", "last_seen_at",
        "duration_retry_pending"
    ]))
    #expect(try sqliteColumnNames(in: "subtitle_cue_lines", databaseURL: databaseURL).isSuperset(of: [
        "id", "subtitle_file_id", "source_identity_remainder"
    ]))
    #expect(try sqliteColumnNames(in: "search_paths", databaseURL: databaseURL).isSuperset(of: [
        "id", "last_known_path", "resource_identity", "binding_state", "is_configured",
        "latest_index_token", "published_index_token",
        "presentation_retry_pending"
    ]))
    #expect(try sqliteTableExists("library_folders", databaseURL: databaseURL))
    #expect(try sqliteTableExists("cue_tombstones", databaseURL: databaseURL))
    #expect(try sqliteTableExists("cue_change_notices", databaseURL: databaseURL))
    #expect(try sqliteTableExists("resource_binding_conflicts", databaseURL: databaseURL))
    #expect(try sqliteColumnNames(in: "folder_covers", databaseURL: databaseURL)
        .contains("folder_id"))
    #expect(try sqliteColumnNames(in: "user_folder_covers", databaseURL: databaseURL)
        .contains("folder_id"))
    #expect(try sqliteColumnNames(in: "library_playback_history", databaseURL: databaseURL).contains("video_file_id"))
    #expect(try sqliteColumnNames(in: "library_watch_states", databaseURL: databaseURL).contains("video_file_id"))
    #expect(try sqliteColumnNames(in: "library_video_rows", databaseURL: databaseURL).isSuperset(of: [
        "video_file_id", "subtitle_file_id"
    ]))
    #expect(try sqliteColumnNames(in: "subtitle_search_order_rows", databaseURL: databaseURL).contains("subtitle_file_id"))
    #expect(try sqliteColumnNames(in: "shioris", databaseURL: databaseURL) == Set([
        "id", "list_id", "cue_id", "created_at"
    ]))
    #expect(try sqliteForeignKeyTables(in: "shioris", databaseURL: databaseURL) == [
        "shiori_lists"
    ])
    #expect(try sqliteTableExists("shiori_lists", databaseURL: databaseURL))
    #expect(try sqliteColumnNames(in: "shiori_lists", databaseURL: databaseURL) == Set([
        "id", "name", "normalized_name", "description", "cover_path", "created_at",
        "recent_cue_id", "recent_sort_order", "recent_played_at"
    ]))
}

@Test
func migratesSchema37RecentShioriStateWithoutDroppingLists() throws {
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
            normalized_name TEXT NOT NULL,
            description TEXT NOT NULL DEFAULT '',
            cover_path TEXT,
            created_at TEXT NOT NULL
        );
        CREATE TABLE subtitle_cue_lines (
            id INTEGER PRIMARY KEY
        );
        CREATE TABLE shioris (
            id INTEGER PRIMARY KEY,
            cue_id INTEGER NOT NULL
        );
        \(cueTombstoneFixtureSchemaSQL)
        INSERT INTO shiori_lists(
            id, name, normalized_name, description, cover_path, created_at
        )
        VALUES (1, 'Default', 'default', '', NULL, 'created');
        PRAGMA user_version = 37;
        """
    )

    try DatabaseBootstrap.prepare(at: databaseURL)

    #expect(try sqliteSchemaVersion(at: databaseURL) == DatabaseBootstrap.currentSchemaVersion)
    #expect(try sqliteColumnNames(in: "shiori_lists", databaseURL: databaseURL) == Set([
        "id", "name", "normalized_name", "description", "cover_path", "created_at",
        "recent_cue_id", "recent_sort_order", "recent_played_at"
    ]))
    let list = try #require(try ShioriDatabase(path: databaseURL).shioriList(id: 1))
    #expect(list.name == "Default")
    #expect(list.recentCueID == nil)
    #expect(list.recentSortOrder == nil)
    #expect(list.recentPlayedAt == nil)
}

@Test
func migratesSchema36AuxiliaryRetryStateAndUnavailableReasons()
    throws
{
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }
    try executeDatabaseTestSQLite(
        at: databaseURL,
        """
        CREATE TABLE search_paths (
            id INTEGER PRIMARY KEY
        );
        CREATE TABLE video_files (
            id INTEGER PRIMARY KEY
        );
        CREATE TABLE subtitle_files (
            id INTEGER PRIMARY KEY,
            binding_state TEXT NOT NULL
        );
        CREATE TABLE subtitle_cue_lines (
            id INTEGER PRIMARY KEY
        );
        CREATE TABLE shioris (
            id INTEGER PRIMARY KEY,
            cue_id INTEGER NOT NULL
        );
        \(cueTombstoneFixtureSchemaSQL)
        CREATE TABLE shiori_lists (
            id INTEGER PRIMARY KEY,
            name TEXT NOT NULL,
            normalized_name TEXT NOT NULL,
            description TEXT NOT NULL DEFAULT '',
            cover_path TEXT,
            created_at TEXT NOT NULL
        );
        INSERT INTO subtitle_files(id, binding_state)
        VALUES (10, 'available'), (20, 'missing');
        INSERT INTO cue_tombstones(
            cue_id,
            subtitle_file_id,
            source_format,
            source_identity_remainder,
            start_time,
            end_time,
            start_ms,
            end_ms,
            content,
            cue_group_content,
            display_title,
            unavailable_reason,
            tombstoned_at,
            updated_at
        )
        VALUES
            (1, 10, 'srt', '', '', '', 0, 0, '', '', '',
             'video_and_subtitle_missing', 'created', 'created'),
            (2, 20, 'srt', '', '', '', 0, 0, '', '', '',
             'video_and_subtitle_missing', 'created', 'created');
        PRAGMA user_version = 36;
        """
    )

    try DatabaseBootstrap.prepare(at: databaseURL)

    #expect(
        try sqliteSchemaVersion(at: databaseURL)
            == DatabaseBootstrap.currentSchemaVersion
    )
    #expect(
        try sqliteColumnNames(
            in: "search_paths",
            databaseURL: databaseURL
        ).contains("presentation_retry_pending")
    )
    #expect(
        try sqliteColumnNames(
            in: "video_files",
            databaseURL: databaseURL
        ).contains("duration_retry_pending")
    )
    #expect(
        try sqliteStringValue(
            at: databaseURL,
            sql:
                "SELECT unavailable_reason "
                + "FROM cue_tombstones WHERE cue_id = 1;"
        ) == "cue_missing"
    )
    #expect(
        try sqliteStringValue(
            at: databaseURL,
            sql:
                "SELECT unavailable_reason "
                + "FROM cue_tombstones WHERE cue_id = 2;"
        ) == "subtitle_missing"
    )
}

@Test
func migratesSchema34IdentityFoundationWithoutLosingShioriAndRemovesTags() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    try executeDatabaseTestSQLite(
        at: databaseURL,
        """
        CREATE TABLE search_paths (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            type TEXT NOT NULL DEFAULT 'local',
            path TEXT NOT NULL UNIQUE,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
        );
        CREATE TABLE subtitle_files (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            library_id INTEGER,
            relative_path TEXT,
            subtitle_path TEXT NOT NULL UNIQUE,
            format TEXT NOT NULL,
            file_size INTEGER,
            modified_at REAL,
            indexed_at TEXT NOT NULL,
            index_algorithm_version INTEGER NOT NULL DEFAULT 0
        );
        CREATE TABLE video_files (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            library_id INTEGER,
            relative_path TEXT,
            path TEXT NOT NULL UNIQUE,
            video_name TEXT NOT NULL,
            file_size INTEGER,
            modified_at REAL
        );
        CREATE TABLE subtitle_cue_lines (
            id INTEGER PRIMARY KEY AUTOINCREMENT
        );
        CREATE TABLE shiori_lists (
            id INTEGER PRIMARY KEY,
            name TEXT NOT NULL,
            normalized_name TEXT NOT NULL,
            description TEXT NOT NULL DEFAULT '',
            cover_path TEXT,
            created_at TEXT NOT NULL
        );
        CREATE TABLE shioris (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            list_id INTEGER NOT NULL,
            cue_id INTEGER NOT NULL,
            created_at TEXT NOT NULL,
            UNIQUE(list_id, cue_id),
            FOREIGN KEY(list_id) REFERENCES shiori_lists(id) ON DELETE CASCADE,
            FOREIGN KEY(cue_id) REFERENCES subtitle_cue_lines(id) ON DELETE CASCADE
        );
        CREATE TABLE shiori_tags (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            normalized_name TEXT NOT NULL UNIQUE,
            created_at TEXT NOT NULL
        );
        CREATE TABLE shiori_tag_assignments (
            shiori_id INTEGER NOT NULL,
            tag_id INTEGER NOT NULL,
            created_at TEXT NOT NULL,
            PRIMARY KEY(shiori_id, tag_id),
            FOREIGN KEY(shiori_id) REFERENCES shioris(id) ON DELETE CASCADE,
            FOREIGN KEY(tag_id) REFERENCES shiori_tags(id) ON DELETE CASCADE
        );
        CREATE TABLE folder_covers (
            folder_path TEXT PRIMARY KEY,
            cover_path TEXT NOT NULL,
            source_video_file_id INTEGER NOT NULL,
            generated_at TEXT NOT NULL
        );
        CREATE TABLE user_folder_covers (
            folder_path TEXT PRIMARY KEY,
            display_cover_path TEXT NOT NULL,
            updated_at TEXT NOT NULL
        );
        INSERT INTO search_paths(id, path, created_at, updated_at)
        VALUES (9, '/Media', 'created', 'updated');
        INSERT INTO subtitle_files(
            id, library_id, relative_path, subtitle_path, format, indexed_at
        )
        VALUES (10, 9, 'Episode.ass', '/Media/Episode.ass', 'ass', 'indexed');
        INSERT INTO video_files(id, library_id, relative_path, path, video_name)
        VALUES (11, 9, 'Episode.mkv', '/Media/Episode.mkv', 'Episode.mkv');
        INSERT INTO subtitle_cue_lines(id) VALUES (12);
        INSERT INTO shiori_lists(
            id, name, normalized_name, description, cover_path, created_at
        )
        VALUES (1, 'Default', 'default', '', NULL, 'created');
        INSERT INTO shioris(id, list_id, cue_id, created_at)
        VALUES (13, 1, 12, 'created');
        INSERT INTO shiori_tags(id, name, normalized_name, created_at)
        VALUES (14, 'Tag', 'Tag', 'created');
        INSERT INTO shiori_tag_assignments(shiori_id, tag_id, created_at)
        VALUES (13, 14, 'created');
        PRAGMA user_version = 34;
        """
    )

    try DatabaseBootstrap.prepare(at: databaseURL)

    #expect(
        try sqliteSchemaVersion(at: databaseURL)
            == DatabaseBootstrap.currentSchemaVersion
    )
    #expect(try sqliteRowCount(in: "shioris", databaseURL: databaseURL) == 1)
    #expect(try sqliteTableExists("shiori_tags", databaseURL: databaseURL) == false)
    #expect(try sqliteTableExists("shiori_tag_assignments", databaseURL: databaseURL) == false)
    #expect(try sqliteForeignKeyTables(in: "shioris", databaseURL: databaseURL) == [
        "shiori_lists"
    ])
    #expect(try sqliteColumnNames(in: "subtitle_cue_lines", databaseURL: databaseURL)
        .contains("source_identity_remainder"))
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
func freshSchemaOmitsShioriTagTablesAndIndexes() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    try DatabaseBootstrap.prepare(at: databaseURL)

    #expect(try sqliteTableExists("shiori_tags", databaseURL: databaseURL) == false)
    #expect(try sqliteTableExists("shiori_tag_assignments", databaseURL: databaseURL) == false)
    #expect(try sqliteIndexExists("idx_shiori_tags_name", databaseURL: databaseURL) == false)
    #expect(try sqliteIndexExists("idx_shiori_tag_assignments_tag", databaseURL: databaseURL) == false)
    #expect(try sqliteIndexExists("idx_shiori_tag_assignments_shiori", databaseURL: databaseURL) == false)
}
