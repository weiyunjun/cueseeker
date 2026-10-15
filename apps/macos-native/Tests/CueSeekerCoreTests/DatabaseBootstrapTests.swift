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
        removeTemporaryDatabase(at: databaseURL)
    }

    try DatabaseBootstrap.prepare(at: databaseURL)

    #expect(try sqliteSchemaVersion(at: databaseURL) == DatabaseBootstrap.currentSchemaVersion)
}

@Test
func currentSchemaValidationDoesNotMutateStoredData() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        removeTemporaryDatabase(at: databaseURL)
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
func migratesSchema41DanglingExcerptToProtectedTombstone() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        removeTemporaryDatabase(at: databaseURL)
    }

    try DatabaseBootstrap.prepare(at: databaseURL)
    try executeDatabaseTestSQLite(
        at: databaseURL,
        """
        \(preSchema47ExcerptTablesSQL)
        INSERT INTO shioris(id, list_id, cue_id, created_at)
        VALUES (780, 1, 9007505, '2026-08-03T13:27:29Z');
        PRAGMA user_version = 41;
        """
    )

    try DatabaseBootstrap.prepare(at: databaseURL)

    let repaired = try #require(
        try ExcerptDatabase(path: databaseURL).excerpt(id: 780)
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
func migratesSchema46ByRenamingShioriTablesToExcerptTables() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        removeTemporaryDatabase(at: databaseURL)
    }

    try DatabaseBootstrap.prepare(at: databaseURL)
    try executeDatabaseTestSQLite(
        at: databaseURL,
        """
        \(preSchema47ExcerptTablesSQL)
        \(DatabaseBootstrap.cueReferenceIntegrityTriggerSQL(excerptTable: "shioris"))
        INSERT INTO shiori_lists(
            id, name, normalized_name, description, cover_path, created_at
        )
        VALUES (2, 'Kept', 'kept', 'Kept description', '/Covers/Shiori/Display/v1/kept.jpg', 'created');
        INSERT INTO shioris(id, list_id, cue_id, created_at)
        VALUES (30, 2, 40, 'saved');
        PRAGMA user_version = 46;
        """
    )

    try DatabaseBootstrap.prepare(at: databaseURL)

    #expect(try sqliteSchemaVersion(at: databaseURL) == DatabaseBootstrap.currentSchemaVersion)
    #expect(try sqliteTableExists("shiori_lists", databaseURL: databaseURL) == false)
    #expect(try sqliteTableExists("shioris", databaseURL: databaseURL) == false)
    #expect(try sqliteForeignKeyTables(in: "excerpts", databaseURL: databaseURL) == [
        "excerpt_lists"
    ])
    for index in [
        "idx_excerpt_lists_normalized_name", "idx_excerpts_list_order",
        "idx_excerpts_cue", "idx_excerpts_created_order"
    ] {
        #expect(try sqliteIndexExists(index, databaseURL: databaseURL))
    }
    for index in [
        "idx_shiori_lists_normalized_name", "idx_shioris_list_order",
        "idx_shioris_cue", "idx_shioris_created_order"
    ] {
        #expect(try sqliteIndexExists(index, databaseURL: databaseURL) == false)
    }
    let list = try #require(try ExcerptDatabase(path: databaseURL).excerptList(id: 2))
    #expect(list.description == "Kept description")
    #expect(list.coverPath == "/Covers/Shiori/Display/v1/kept.jpg")
    #expect(
        try sqliteStringValue(
            at: databaseURL,
            sql: "SELECT created_at FROM excerpts WHERE id = 30 AND list_id = 2 AND cue_id = 40;"
        ) == "saved"
    )
    for trigger in ["protect_referenced_cue_deletion", "protect_referenced_tombstone_deletion"] {
        let sql = try #require(
            try sqliteStringValue(
                at: databaseURL,
                sql: "SELECT sql FROM sqlite_master WHERE type = 'trigger' AND name = '\(trigger)';"
            )
        )
        #expect(sql.contains("FROM excerpts"))
        #expect(!sql.contains("shioris"))
    }
}

@Test
func migratesSchema33ExcerptListMetadataWithoutDroppingTheList() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        removeTemporaryDatabase(at: databaseURL)
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
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            subtitle_file_id INTEGER,
            cue_group_id INTEGER,
            event_index INTEGER NOT NULL DEFAULT 0,
            source_format TEXT NOT NULL DEFAULT 'srt',
            source_style TEXT,
            start_time TEXT NOT NULL DEFAULT '',
            end_time TEXT NOT NULL DEFAULT '',
            start_ms INTEGER NOT NULL DEFAULT 0,
            end_ms INTEGER NOT NULL DEFAULT 0,
            content TEXT NOT NULL DEFAULT '',
            display_order INTEGER NOT NULL DEFAULT 0
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
        \(identityEraFixtureSchemaSQL)
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
    #expect(try sqliteColumnNames(in: "excerpt_lists", databaseURL: databaseURL) == Set([
        "id", "name", "normalized_name", "description", "cover_path", "created_at",
        "recent_cue_id", "recent_sort_order", "recent_played_at"
    ]))
    #expect(try sqliteIndexExists(
        "idx_excerpt_lists_normalized_name",
        databaseURL: databaseURL
    ))
    let list = try #require(try ExcerptDatabase(path: databaseURL).excerptLists().first)
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
    try expectUnsupportedSchemaVersion(DatabaseBootstrap.currentSchemaVersion + 1)
}

@Test
func readOnlyConnectionDoesNotCreateMissingDatabase() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        removeTemporaryDatabase(at: databaseURL)
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
        removeTemporaryDatabase(at: databaseURL)
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
        removeTemporaryDatabase(at: databaseURL)
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
        removeTemporaryDatabase(at: databaseURL)
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
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            list_id INTEGER NOT NULL,
            cue_id INTEGER NOT NULL,
            created_at TEXT NOT NULL
        );
        CREATE TABLE shiori_lists (
            id INTEGER PRIMARY KEY,
            name TEXT NOT NULL,
            normalized_name TEXT NOT NULL,
            description TEXT NOT NULL DEFAULT '',
            cover_path TEXT,
            created_at TEXT NOT NULL
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
        INSERT INTO shioris(id, list_id, cue_id, created_at) VALUES (20, 1, 1, 'created');
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
    #expect(try sqliteRowCount(in: "excerpts", databaseURL: databaseURL) == 1)
    #expect(try sqliteRowCount(in: "subtitle_cue_groups_fts", databaseURL: databaseURL) == 1)
}

@Test
func permanentIdentitySchemaIncludesLibraryRelativePathsAndIDReferences() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        removeTemporaryDatabase(at: databaseURL)
    }

    try DatabaseBootstrap.prepare(at: databaseURL)

    let subtitleColumns = try sqliteColumnNames(in: "subtitle_files", databaseURL: databaseURL)
    let videoColumns = try sqliteColumnNames(in: "video_files", databaseURL: databaseURL)
    let searchPathColumns = try sqliteColumnNames(in: "search_paths", databaseURL: databaseURL)

    #expect(subtitleColumns.isSuperset(of: [
        "id", "library_id", "folder_id", "relative_path", "subtitle_path"
    ]))
    #expect(videoColumns.isSuperset(of: [
        "id", "library_id", "folder_id", "relative_path", "path",
        "duration_retry_pending"
    ]))
    #expect(try sqliteColumnNames(in: "subtitle_cue_lines", databaseURL: databaseURL).isSuperset(of: [
        "id", "subtitle_file_id", "source_identity_remainder"
    ]))
    #expect(searchPathColumns.isSuperset(of: [
        "id", "path", "presentation_retry_pending"
    ]))

    // Path and file name are the only identity; nothing else may decide it.
    let retiredColumns: Set<String> = [
        "resource_identity", "content_fingerprint", "binding_state",
        "last_known_path", "last_seen_at", "is_configured",
        "latest_index_token", "published_index_token"
    ]
    #expect(subtitleColumns.isDisjoint(with: retiredColumns))
    #expect(videoColumns.isDisjoint(with: retiredColumns))
    #expect(searchPathColumns.isDisjoint(with: retiredColumns))
    #expect(
        try sqliteColumnNames(in: "library_folders", databaseURL: databaseURL)
            .isDisjoint(with: retiredColumns)
    )
    #expect(try sqliteTableExists("library_folders", databaseURL: databaseURL))
    #expect(try sqliteTableExists("cue_tombstones", databaseURL: databaseURL))
    #expect(try sqliteTableExists("cue_change_notices", databaseURL: databaseURL))
    #expect(try !sqliteTableExists("resource_binding_conflicts", databaseURL: databaseURL))
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
    #expect(try sqliteColumnNames(in: "excerpts", databaseURL: databaseURL) == Set([
        "id", "list_id", "cue_id", "created_at"
    ]))
    #expect(try sqliteForeignKeyTables(in: "excerpts", databaseURL: databaseURL) == [
        "excerpt_lists"
    ])
    #expect(try sqliteTableExists("excerpt_lists", databaseURL: databaseURL))
    #expect(try sqliteColumnNames(in: "excerpt_lists", databaseURL: databaseURL) == Set([
        "id", "name", "normalized_name", "description", "cover_path", "created_at",
        "recent_cue_id", "recent_sort_order", "recent_played_at"
    ]))
}

@Test
func migratesSchema37RecentExcerptStateWithoutDroppingLists() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        removeTemporaryDatabase(at: databaseURL)
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
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            list_id INTEGER NOT NULL,
            cue_id INTEGER NOT NULL,
            created_at TEXT NOT NULL
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
    #expect(try sqliteColumnNames(in: "excerpt_lists", databaseURL: databaseURL) == Set([
        "id", "name", "normalized_name", "description", "cover_path", "created_at",
        "recent_cue_id", "recent_sort_order", "recent_played_at"
    ]))
    let list = try #require(try ExcerptDatabase(path: databaseURL).excerptList(id: 1))
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
        removeTemporaryDatabase(at: databaseURL)
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
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            list_id INTEGER NOT NULL,
            cue_id INTEGER NOT NULL,
            created_at TEXT NOT NULL
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
func migratesSchema34IdentityFoundationWithoutLosingExcerptsAndRemovesTags() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        removeTemporaryDatabase(at: databaseURL)
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
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            subtitle_file_id INTEGER,
            cue_group_id INTEGER,
            event_index INTEGER NOT NULL DEFAULT 0,
            source_format TEXT NOT NULL DEFAULT 'srt',
            source_style TEXT,
            start_time TEXT NOT NULL DEFAULT '',
            end_time TEXT NOT NULL DEFAULT '',
            start_ms INTEGER NOT NULL DEFAULT 0,
            end_ms INTEGER NOT NULL DEFAULT 0,
            content TEXT NOT NULL DEFAULT '',
            display_order INTEGER NOT NULL DEFAULT 0
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
        \(identityEraFixtureSchemaSQL)
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
    #expect(try sqliteRowCount(in: "excerpts", databaseURL: databaseURL) == 1)
    #expect(try sqliteTableExists("shiori_tags", databaseURL: databaseURL) == false)
    #expect(try sqliteTableExists("shiori_tag_assignments", databaseURL: databaseURL) == false)
    #expect(try sqliteForeignKeyTables(in: "excerpts", databaseURL: databaseURL) == [
        "excerpt_lists"
    ])
    #expect(try sqliteColumnNames(in: "subtitle_cue_lines", databaseURL: databaseURL)
        .contains("source_identity_remainder"))
}

@Test
func sqliteConnectionsUseBusyTimeoutAndWALMode() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        removeTemporaryDatabase(at: databaseURL)
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
func freshSchemaCreatesExcerptTablePerformanceIndexes() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        removeTemporaryDatabase(at: databaseURL)
    }

    try DatabaseBootstrap.prepare(at: databaseURL)

    #expect(try sqliteIndexExists("idx_excerpts_created_order", databaseURL: databaseURL))
    #expect(try sqliteIndexExists("idx_subtitle_cue_groups_file_time", databaseURL: databaseURL))
}

@Test
func freshSchemaOmitsShioriTagTablesAndIndexes() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        removeTemporaryDatabase(at: databaseURL)
    }

    try DatabaseBootstrap.prepare(at: databaseURL)

    #expect(try sqliteTableExists("shiori_tags", databaseURL: databaseURL) == false)
    #expect(try sqliteTableExists("shiori_tag_assignments", databaseURL: databaseURL) == false)
    #expect(try sqliteIndexExists("idx_shiori_tags_name", databaseURL: databaseURL) == false)
    #expect(try sqliteIndexExists("idx_shiori_tag_assignments_tag", databaseURL: databaseURL) == false)
    #expect(try sqliteIndexExists("idx_shiori_tag_assignments_shiori", databaseURL: databaseURL) == false)
}

/// Tables a real pre-43 database always has and that the schema 43 migration
/// touches while it removes the resource identity and binding state machine.
let identityEraFixtureSchemaSQL = """
    CREATE TABLE IF NOT EXISTS subtitle_video_matches (
        subtitle_file_id INTEGER NOT NULL,
        video_file_id INTEGER NOT NULL,
        match_method TEXT NOT NULL DEFAULT 'exact',
        confidence REAL NOT NULL DEFAULT 1.0,
        is_active INTEGER NOT NULL DEFAULT 1,
        PRIMARY KEY(subtitle_file_id, video_file_id)
    );
    CREATE TABLE IF NOT EXISTS library_video_rows (
        video_path TEXT PRIMARY KEY,
        video_file_id INTEGER,
        subtitle_file_id INTEGER,
        display_title TEXT NOT NULL DEFAULT ''
    );
    CREATE TABLE IF NOT EXISTS subtitle_search_order_rows (
        subtitle_path TEXT PRIMARY KEY,
        subtitle_file_id INTEGER
    );
    CREATE TABLE IF NOT EXISTS library_playback_history (
        video_path TEXT PRIMARY KEY,
        video_file_id INTEGER,
        position_ms INTEGER NOT NULL DEFAULT 0,
        duration REAL,
        started_at TEXT,
        completed_at TEXT,
        updated_at TEXT NOT NULL DEFAULT ''
    );
    CREATE TABLE IF NOT EXISTS library_watch_states (
        video_path TEXT PRIMARY KEY,
        video_file_id INTEGER,
        state TEXT NOT NULL DEFAULT 'unwatched',
        updated_at TEXT NOT NULL DEFAULT ''
    );
    CREATE TABLE IF NOT EXISTS subtitle_language_detections (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        subtitle_file_id INTEGER NOT NULL,
        scope TEXT NOT NULL,
        scope_key TEXT
    );
    CREATE TABLE IF NOT EXISTS subtitle_language_detection_codes (
        detection_id INTEGER NOT NULL,
        language_code TEXT NOT NULL
    );
    CREATE TABLE IF NOT EXISTS subtitle_cue_group_languages (
        cue_group_id INTEGER NOT NULL,
        language_code TEXT NOT NULL
    );
    """

@Test
func migratesSchema47ByEncodingFTSRowIDsByFileAndTime() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        removeTemporaryDatabase(at: databaseURL)
    }

    try DatabaseBootstrap.prepare(at: databaseURL)
    let database = try IndexingDatabase(path: databaseURL)
    try database.replaceEntries(
        subtitleFile: URL(fileURLWithPath: "/Media/Alpha.srt"),
        videoFile: URL(fileURLWithPath: "/Media/Alpha.mkv"),
        entries: [
            SubtitleEntry(
                sequenceNumber: 1,
                startTimecode: "00:00:05,000",
                endTimecode: "00:00:06,000",
                startMilliseconds: 5_000,
                endMilliseconds: 6_000,
                text: "Later alpha"
            ),
            SubtitleEntry(
                sequenceNumber: 2,
                startTimecode: "00:00:01,000",
                endTimecode: "00:00:02,000",
                startMilliseconds: 1_000,
                endMilliseconds: 2_000,
                text: "Earlier alpha"
            )
        ]
    )
    try database.replaceEntries(
        subtitleFile: URL(fileURLWithPath: "/Media/Beta.srt"),
        videoFile: URL(fileURLWithPath: "/Media/Beta.mkv"),
        entries: [
            SubtitleEntry(
                sequenceNumber: 1,
                startTimecode: "00:00:03,000",
                endTimecode: "00:00:04,000",
                startMilliseconds: 3_000,
                endMilliseconds: 4_000,
                text: "Only beta"
            )
        ]
    )
    // Give the rows the appended rowids schema 47 left behind, then migrate again.
    try executeDatabaseTestSQLite(
        at: databaseURL,
        """
        CREATE TEMP TABLE scrambled AS
            SELECT rowid AS old_rowid, content, cue_group_id FROM subtitle_cue_groups_fts;
        DELETE FROM subtitle_cue_groups_fts;
        INSERT INTO subtitle_cue_groups_fts(rowid, content, cue_group_id)
            SELECT old_rowid + 100000, content, cue_group_id FROM scrambled;
        PRAGMA user_version = 47;
        """
    )

    try DatabaseBootstrap.prepare(at: databaseURL)

    #expect(try sqliteSchemaVersion(at: databaseURL) == DatabaseBootstrap.currentSchemaVersion)
    #expect(try sqliteRowCount(in: "subtitle_cue_groups_fts", databaseURL: databaseURL) == 3)
    #expect(
        try sqliteStringValue(
            at: databaseURL,
            sql: """
            SELECT COUNT(*)
            FROM subtitle_cue_groups_fts f
            JOIN (
                SELECT id,
                       (subtitle_file_id << 24)
                           | ROW_NUMBER() OVER (
                               PARTITION BY subtitle_file_id
                               ORDER BY start_ms ASC, end_ms ASC, id ASC
                           ) AS expected_rowid
                FROM subtitle_cue_groups
            ) g ON g.id = f.cue_group_id
            WHERE f.rowid = g.expected_rowid;
            """
        ) == "3"
    )
    #expect(
        try SearchDatabase(path: databaseURL).searchPage("alpha", limit: 10).results.map(\.content)
            == ["Earlier alpha", "Later alpha"]
    )
}

@Test
func migratesSchema48ByStoringTheLanguageOfEveryCueLine() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        removeTemporaryDatabase(at: databaseURL)
    }

    try DatabaseBootstrap.prepare(at: databaseURL)
    let database = try IndexingDatabase(path: databaseURL)
    try database.replaceCueGroups(
        subtitleFile: URL(fileURLWithPath: "/Media/Styled.ass"),
        videoFile: URL(fileURLWithPath: "/Media/Styled.mkv"),
        format: .ass,
        cueGroups: [
            languageFilterASSCueGroup(
                startMilliseconds: 1_000,
                lines: [(style: "CN", content: "中文上方"), (style: "JP", content: "日本語の下側")]
            ),
            languageFilterASSCueGroup(
                startMilliseconds: 3_000,
                lines: [(style: nil, content: "12345")]
            )
        ],
        languageAnalysis: SubtitleLanguageAnalysis(
            format: .ass,
            fileDetection: nil,
            styleDetections: [
                "CN": SubtitleLanguageDetectionResult(
                    languages: [.simplifiedChinese],
                    confidence: 1,
                    segmentCount: 1,
                    effectiveCharacterCount: 4,
                    distribution: [SubtitleLanguageDistribution(language: .simplifiedChinese, share: 1)]
                ),
                "JP": SubtitleLanguageDetectionResult(
                    languages: [.japanese],
                    confidence: 1,
                    segmentCount: 1,
                    effectiveCharacterCount: 6,
                    distribution: [SubtitleLanguageDistribution(language: .japanese, share: 1)]
                ),
            ],
            cueGroupLanguages: [[.simplifiedChinese, .japanese], []]
        )
    )
    let rowsSQL = """
        SELECT GROUP_CONCAT(cue_id || ':' || language_code, ',')
        FROM (SELECT cue_id, language_code FROM subtitle_cue_line_languages ORDER BY cue_id, language_code);
        """
    let indexedRows = try #require(try sqliteStringValue(at: databaseURL, sql: rowsSQL))
    #expect(indexedRows.split(separator: ",").count == 3)
    #expect(indexedRows.hasSuffix(":unknown"))

    try executeDatabaseTestSQLite(
        at: databaseURL,
        """
        DELETE FROM subtitle_cue_line_languages;
        DELETE FROM cue_facet_counts WHERE facet = 'language';
        PRAGMA user_version = 48;
        """
    )

    try DatabaseBootstrap.prepare(at: databaseURL)

    #expect(try sqliteSchemaVersion(at: databaseURL) == DatabaseBootstrap.currentSchemaVersion)
    #expect(try sqliteStringValue(at: databaseURL, sql: rowsSQL) == indexedRows)
    #expect(
        try sqliteStringValue(
            at: databaseURL,
            sql: "SELECT GROUP_CONCAT(value || '=' || cue_count, ',') FROM (SELECT value, cue_count FROM cue_facet_counts WHERE facet = 'language' ORDER BY value);"
        ) == "ja=1,unknown=1,zh-Hans=1"
    )
}

@Test
func migratesSchema49ByCountingTheCuesOfEveryFolder() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        removeTemporaryDatabase(at: databaseURL)
    }

    try DatabaseBootstrap.prepare(at: databaseURL)
    let database = try IndexingDatabase(path: databaseURL)
    for (folder, lineCount) in [("Alpha", 2), ("Beta", 1)] {
        try database.replaceEntries(
            subtitleFile: URL(fileURLWithPath: "/Media/\(folder)/Folder.srt"),
            videoFile: URL(fileURLWithPath: "/Media/\(folder)/Folder.mkv"),
            entries: (0..<lineCount).map { index in
                SubtitleEntry(
                    sequenceNumber: index + 1,
                    startTimecode: "00:00:0\(index),000",
                    endTimecode: "00:00:0\(index),500",
                    startMilliseconds: index * 1_000,
                    endMilliseconds: index * 1_000 + 500,
                    text: "Folder line \(index)"
                )
            }
        )
    }
    let folderCountsSQL = "SELECT GROUP_CONCAT(value || '=' || cue_count, ',') FROM (SELECT value, cue_count FROM cue_facet_counts WHERE facet = 'folder' ORDER BY value);"
    #expect(try sqliteStringValue(at: databaseURL, sql: folderCountsSQL) == "/Media/Alpha=2,/Media/Beta=1")

    // A library indexed before schema 50 has every other count but no folder.
    try executeDatabaseTestSQLite(
        at: databaseURL,
        """
        DELETE FROM cue_facet_counts WHERE facet = 'folder';
        PRAGMA user_version = 49;
        """
    )

    try DatabaseBootstrap.prepare(at: databaseURL)

    #expect(try sqliteSchemaVersion(at: databaseURL) == DatabaseBootstrap.currentSchemaVersion)
    #expect(try sqliteStringValue(at: databaseURL, sql: folderCountsSQL) == "/Media/Alpha=2,/Media/Beta=1")
}

@Test
func migratesSchema50ByAddingAudioTrackColumnsWithoutTouchingVideos() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        removeTemporaryDatabase(at: databaseURL)
    }

    try DatabaseBootstrap.prepare(at: databaseURL)
    let database = try IndexingDatabase(path: databaseURL)
    let videoFile = URL(fileURLWithPath: "/Media/Show/Episode.mkv")
    try database.replaceEntries(
        subtitleFile: URL(fileURLWithPath: "/Media/Show/Episode.srt"),
        videoFile: videoFile,
        entries: [databaseTestEntry(text: "Audio tracks")]
    )
    try executeDatabaseTestSQLite(
        at: databaseURL,
        """
        ALTER TABLE video_files DROP COLUMN audio_tracks;
        ALTER TABLE video_files DROP COLUMN default_audio_track_index;
        PRAGMA user_version = 50;
        """
    )

    try DatabaseBootstrap.prepare(at: databaseURL)

    #expect(try sqliteSchemaVersion(at: databaseURL) == DatabaseBootstrap.currentSchemaVersion)
    #expect(try sqliteRowCount(in: "video_files", databaseURL: databaseURL) == 1)
    // Not inspected yet: no tracks, and the first track is the default.
    #expect(
        try LibraryDatabase(path: databaseURL).videoAudioTracks(forVideoFile: videoFile)
            == VideoAudioTracks(tracks: [], defaultIndex: 0)
    )
}

@Test
func migratesSchema51ByAddingTheDefaultSubtitleColumnWithoutTouchingVideos() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        removeTemporaryDatabase(at: databaseURL)
    }

    try DatabaseBootstrap.prepare(at: databaseURL)
    let database = try IndexingDatabase(path: databaseURL)
    let videoFile = URL(fileURLWithPath: "/Media/Show/Episode.mkv")
    try database.replaceEntries(
        subtitleFile: URL(fileURLWithPath: "/Media/Show/Episode.srt"),
        videoFile: videoFile,
        entries: [databaseTestEntry(text: "Subtitles")]
    )
    try executeDatabaseTestSQLite(
        at: databaseURL,
        """
        ALTER TABLE video_files DROP COLUMN default_subtitle_file_id;
        PRAGMA user_version = 51;
        """
    )

    try DatabaseBootstrap.prepare(at: databaseURL)

    #expect(try sqliteSchemaVersion(at: databaseURL) == DatabaseBootstrap.currentSchemaVersion)
    #expect(try sqliteRowCount(in: "video_files", databaseURL: databaseURL) == 1)
    // No default set: the only subtitle takes effect.
    let subtitles = try #require(try LibraryDatabase(path: databaseURL).videoSubtitles(forVideoFile: videoFile))
    #expect(subtitles.defaultSubtitleFileID == nil)
    #expect(subtitles.effectiveDefault?.subtitlePath == "/Media/Show/Episode.srt")
}

@Test
func migratesSchema54ByAddingFTSCoveringIndexAndLineLanguageMask() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        removeTemporaryDatabase(at: databaseURL)
    }

    try DatabaseBootstrap.prepare(at: databaseURL)
    let database = try IndexingDatabase(path: databaseURL)
    try database.replaceEntries(
        subtitleFile: URL(fileURLWithPath: "/Media/Show/Episode.srt"),
        videoFile: URL(fileURLWithPath: "/Media/Show/Episode.mkv"),
        entries: [databaseTestEntry(text: "大丈夫です")]
    )
    try executeDatabaseTestSQLite(
        at: databaseURL,
        """
        DROP INDEX IF EXISTS idx_subtitle_cue_lines_fts_covering;
        ALTER TABLE subtitle_cue_lines DROP COLUMN fts_rowid;
        ALTER TABLE subtitle_cue_lines DROP COLUMN language_mask;
        PRAGMA user_version = 54;
        """
    )

    try DatabaseBootstrap.prepare(at: databaseURL)

    #expect(try sqliteSchemaVersion(at: databaseURL) == DatabaseBootstrap.currentSchemaVersion)
    #expect(try sqliteIndexExists("idx_subtitle_cue_lines_fts_covering", databaseURL: databaseURL))
    let searchPage = try SearchDatabase(path: databaseURL).searchPage("大丈夫", limit: 10)
    #expect(searchPage.totalCount == 1)
    #expect(searchPage.results.first?.content == "大丈夫です")
}

