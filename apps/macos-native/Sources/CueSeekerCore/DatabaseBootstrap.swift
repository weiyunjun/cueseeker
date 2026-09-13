import Foundation

public enum DatabaseBootstrapError: Error, Equatable, CustomStringConvertible {
    case unsupportedSchemaVersion(found: Int, supported: Int)

    public var description: String {
        switch self {
        case .unsupportedSchemaVersion(let found, let supported):
            "Unsupported database schema version \(found); this build supports schema \(supported)."
        }
    }
}

public enum DatabaseBootstrap {
    public static let currentSchemaVersion = 47

    public static func prepare(at path: URL) throws {
        let database = try SQLiteDatabase(path: path, access: .readWrite)
        try prepareSchema(on: database)
    }

    private static func schemaVersion(in database: SQLiteDatabase) throws -> Int {
        let statement = try database.prepare("PRAGMA user_version")
        guard try statement.step() else {
            return 0
        }
        return statement.intColumn(0)
    }
}

private extension DatabaseBootstrap {
    static func columnNames(
        of table: String,
        in database: SQLiteDatabase
    ) throws -> Set<String> {
        let statement = try database.prepare("PRAGMA table_info(\(table))")
        var names: Set<String> = []
        while try statement.step() {
            names.insert(statement.stringColumn(1))
        }
        return names
    }

    static func prepareSchema(on database: SQLiteDatabase) throws {
        let previousVersion = try schemaVersion(in: database)

        guard previousVersion == 0
                || previousVersion == 33
                || previousVersion == 34
                || previousVersion == 35
                || previousVersion == 36
                || previousVersion == 37
                || previousVersion == 38
                || previousVersion == 39
                || previousVersion == 40
                || previousVersion == 41
                || previousVersion == 42
                || previousVersion == 43
                || previousVersion == 44
                || previousVersion == 45
                || previousVersion == 46
                || previousVersion == DatabaseBootstrap.currentSchemaVersion
        else {
            throw DatabaseBootstrapError.unsupportedSchemaVersion(
                found: previousVersion,
                supported: DatabaseBootstrap.currentSchemaVersion
            )
        }
        if previousVersion == 33 {
            try migrateSchema33To34(on: database)
        }
        if previousVersion == 33 || previousVersion == 34 {
            try migrateSchema34To35(on: database)
        }
        if previousVersion == 33 || previousVersion == 34 || previousVersion == 35 {
            try migrateSchema35To36(on: database)
        }
        if previousVersion == 33
            || previousVersion == 34
            || previousVersion == 35
            || previousVersion == 36
        {
            try migrateSchema36To37(on: database)
        }
        if previousVersion == 33
            || previousVersion == 34
            || previousVersion == 35
            || previousVersion == 36
            || previousVersion == 37
        {
            try migrateSchema37To38(on: database)
        }
        if previousVersion == 33
            || previousVersion == 34
            || previousVersion == 35
            || previousVersion == 36
            || previousVersion == 37
            || previousVersion == 38
        {
            try migrateSchema38To39(on: database)
        }
        if previousVersion == 33
            || previousVersion == 34
            || previousVersion == 35
            || previousVersion == 36
            || previousVersion == 37
            || previousVersion == 38
            || previousVersion == 39
        {
            try migrateSchema39To40(on: database)
        }
        if previousVersion == 33
            || previousVersion == 34
            || previousVersion == 35
            || previousVersion == 36
            || previousVersion == 37
            || previousVersion == 38
            || previousVersion == 39
            || previousVersion == 40
        {
            try migrateSchema40To41(on: database)
        }
        if previousVersion == 33
            || previousVersion == 34
            || previousVersion == 35
            || previousVersion == 36
            || previousVersion == 37
            || previousVersion == 38
            || previousVersion == 39
            || previousVersion == 40
            || previousVersion == 41
        {
            try migrateSchema41To42(on: database)
        }
        if previousVersion >= 33, previousVersion <= 42 {
            try migrateSchema42To43(on: database)
        }
        if previousVersion >= 33, previousVersion <= 43 {
            try migrateSchema43To44(on: database)
        }
        if previousVersion >= 33, previousVersion <= 44 {
            try migrateSchema44To45(on: database)
        }
        if previousVersion >= 33, previousVersion <= 45 {
            try migrateSchema45To46(on: database)
        }
        if previousVersion >= 33, previousVersion <= 46 {
            try migrateSchema46To47(on: database)
            return
        }
        guard previousVersion == 0 else {
            return
        }

        try database.withImmediateTransaction {
            try database.execute(
                """
                CREATE TABLE IF NOT EXISTS search_paths (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    type TEXT NOT NULL DEFAULT 'local',
                    path TEXT NOT NULL UNIQUE,
                    last_successful_index_at TEXT,
                    presentation_retry_pending INTEGER NOT NULL DEFAULT 0,
                    created_at TEXT NOT NULL,
                    updated_at TEXT NOT NULL
                );

                CREATE TABLE IF NOT EXISTS library_folders (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    library_id INTEGER NOT NULL,
                    relative_path TEXT NOT NULL,
                    UNIQUE(library_id, relative_path),
                    FOREIGN KEY(library_id) REFERENCES search_paths(id)
                );
                """
            )

            let shioriSchemaSQL = """
                CREATE TABLE IF NOT EXISTS excerpt_lists (
                    id INTEGER PRIMARY KEY,
                    name TEXT NOT NULL,
                    normalized_name TEXT NOT NULL,
                    description TEXT NOT NULL DEFAULT '',
                    cover_path TEXT,
                    created_at TEXT NOT NULL,
                    recent_cue_id INTEGER,
                    recent_sort_order TEXT,
                    recent_played_at TEXT
                );

                INSERT OR IGNORE INTO excerpt_lists(
                    id,
                    name,
                    normalized_name,
                    description,
                    cover_path,
                    created_at
                )
                VALUES (1, 'Default', 'default', '', NULL, '1970-01-01T00:00:00Z');

                CREATE UNIQUE INDEX IF NOT EXISTS idx_excerpt_lists_normalized_name
                    ON excerpt_lists(normalized_name);

                CREATE TABLE IF NOT EXISTS excerpts (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    list_id INTEGER NOT NULL,
                    cue_id INTEGER NOT NULL,
                    created_at TEXT NOT NULL,
                    UNIQUE(list_id, cue_id),
                    FOREIGN KEY(list_id) REFERENCES excerpt_lists(id) ON DELETE CASCADE
                );

                CREATE INDEX IF NOT EXISTS idx_excerpts_list_order
                    ON excerpts(list_id, created_at DESC, id DESC);

                CREATE INDEX IF NOT EXISTS idx_excerpts_cue
                    ON excerpts(cue_id);

                CREATE INDEX IF NOT EXISTS idx_excerpts_created_order
                    ON excerpts(created_at DESC, id DESC);
                """

            try database.execute(
            """
            CREATE TABLE IF NOT EXISTS subtitle_files (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                library_id INTEGER,
                folder_id INTEGER,
                relative_path TEXT,
                subtitle_path TEXT NOT NULL UNIQUE,
                format TEXT NOT NULL,
                file_size INTEGER,
                modified_at REAL,
                indexed_at TEXT NOT NULL,
                index_algorithm_version INTEGER NOT NULL DEFAULT 0,
                FOREIGN KEY(library_id) REFERENCES search_paths(id),
                FOREIGN KEY(folder_id) REFERENCES library_folders(id)
            );

            CREATE TABLE IF NOT EXISTS video_files (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                library_id INTEGER,
                folder_id INTEGER,
                relative_path TEXT,
                path TEXT NOT NULL UNIQUE,
                video_name TEXT NOT NULL,
                file_size INTEGER,
                modified_at REAL,
                duration REAL,
                duration_retry_pending INTEGER NOT NULL DEFAULT 0,
                video_width INTEGER,
                video_height INTEGER,
                frame_rate REAL,
                video_codec TEXT,
                audio_codec TEXT,
                native_video_candidate INTEGER,
                native_audio_candidate INTEGER,
                native_compatibility_reason TEXT,
                native_failure_reason TEXT,
                compatibility_evaluated_at TEXT,
                FOREIGN KEY(library_id) REFERENCES search_paths(id),
                FOREIGN KEY(folder_id) REFERENCES library_folders(id)
            );

            CREATE TABLE IF NOT EXISTS subtitle_video_matches (
                subtitle_file_id INTEGER NOT NULL,
                video_file_id INTEGER NOT NULL,
                match_method TEXT NOT NULL,
                confidence REAL NOT NULL,
                is_active INTEGER NOT NULL DEFAULT 1,
                PRIMARY KEY(subtitle_file_id, video_file_id),
                FOREIGN KEY(subtitle_file_id) REFERENCES subtitle_files(id) ON DELETE CASCADE,
                FOREIGN KEY(video_file_id) REFERENCES video_files(id) ON DELETE CASCADE
            );

            CREATE TABLE IF NOT EXISTS subtitle_cue_groups (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                subtitle_file_id INTEGER NOT NULL,
                subtitle_path TEXT NOT NULL,
                seq INTEGER,
                start_time TEXT NOT NULL,
                end_time TEXT NOT NULL,
                start_ms INTEGER NOT NULL,
                end_ms INTEGER NOT NULL,
                time_range TEXT NOT NULL DEFAULT '',
                search_content TEXT NOT NULL,
                line_count INTEGER NOT NULL DEFAULT 1,
                FOREIGN KEY(subtitle_file_id) REFERENCES subtitle_files(id) ON DELETE CASCADE
            );

            CREATE TABLE IF NOT EXISTS subtitle_cue_lines (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                subtitle_file_id INTEGER,
                cue_group_id INTEGER NOT NULL,
                event_index INTEGER NOT NULL,
                source_format TEXT NOT NULL,
                source_style TEXT,
                source_layer INTEGER,
                source_identity_remainder TEXT NOT NULL DEFAULT '',
                start_time TEXT NOT NULL,
                end_time TEXT NOT NULL,
                start_ms INTEGER NOT NULL,
                end_ms INTEGER NOT NULL,
                content TEXT NOT NULL,
                display_x REAL,
                display_y REAL,
                display_order INTEGER NOT NULL,
                FOREIGN KEY(subtitle_file_id) REFERENCES subtitle_files(id),
                FOREIGN KEY(cue_group_id) REFERENCES subtitle_cue_groups(id) ON DELETE CASCADE
            );

            CREATE TABLE IF NOT EXISTS cue_tombstones (
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

            CREATE INDEX IF NOT EXISTS idx_cue_tombstones_subtitle
                ON cue_tombstones(subtitle_file_id, cue_id);

            CREATE TABLE IF NOT EXISTS cue_change_notices (
                cue_id INTEGER PRIMARY KEY,
                previous_content TEXT NOT NULL,
                current_content TEXT NOT NULL,
                changed_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS subtitle_playback_finish_metadata (
                subtitle_file_id INTEGER PRIMARY KEY,
                subtitle_path TEXT NOT NULL UNIQUE,
                algorithm_version INTEGER NOT NULL,
                primary_styles_json TEXT NOT NULL,
                primary_style_last_end_ms INTEGER,
                last_subtitle_end_ms INTEGER,
                indexed_at TEXT NOT NULL,
                FOREIGN KEY(subtitle_file_id) REFERENCES subtitle_files(id) ON DELETE CASCADE
            );

            CREATE INDEX IF NOT EXISTS idx_subtitle_files_subtitle_path
                ON subtitle_files(subtitle_path);

            CREATE INDEX IF NOT EXISTS idx_subtitle_cue_groups_subtitle_path
                ON subtitle_cue_groups(subtitle_path);

            CREATE INDEX IF NOT EXISTS idx_subtitle_cue_groups_start_ms
                ON subtitle_cue_groups(start_ms);

            CREATE INDEX IF NOT EXISTS idx_subtitle_cue_groups_file_time
                ON subtitle_cue_groups(subtitle_file_id, start_ms, end_ms, id);

            CREATE INDEX IF NOT EXISTS idx_subtitle_cue_lines_group_order
                ON subtitle_cue_lines(cue_group_id, display_order, event_index);

            CREATE INDEX IF NOT EXISTS idx_subtitle_playback_finish_metadata_path
                ON subtitle_playback_finish_metadata(subtitle_path);

            CREATE VIRTUAL TABLE IF NOT EXISTS subtitle_cue_groups_fts USING fts5(
                content,
                cue_group_id UNINDEXED
            );

            CREATE TABLE IF NOT EXISTS subtitle_language_manifests (
                subtitle_file_id INTEGER PRIMARY KEY,
                algorithm_version INTEGER NOT NULL,
                detection_count INTEGER NOT NULL,
                cue_group_count INTEGER NOT NULL,
                analyzed_at TEXT NOT NULL,
                FOREIGN KEY(subtitle_file_id) REFERENCES subtitle_files(id) ON DELETE CASCADE
            );

            CREATE TABLE IF NOT EXISTS subtitle_language_detections (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                subtitle_file_id INTEGER NOT NULL,
                scope TEXT NOT NULL,
                scope_key TEXT NOT NULL DEFAULT '',
                algorithm_version INTEGER NOT NULL,
                confidence REAL NOT NULL,
                confidence_band TEXT NOT NULL,
                segment_count INTEGER NOT NULL,
                effective_character_count INTEGER NOT NULL,
                detected_at TEXT NOT NULL,
                UNIQUE(subtitle_file_id, scope, scope_key),
                FOREIGN KEY(subtitle_file_id) REFERENCES subtitle_files(id) ON DELETE CASCADE
            );

            CREATE TABLE IF NOT EXISTS subtitle_language_detection_codes (
                detection_id INTEGER NOT NULL,
                language_code TEXT NOT NULL,
                PRIMARY KEY(detection_id, language_code),
                FOREIGN KEY(detection_id) REFERENCES subtitle_language_detections(id) ON DELETE CASCADE
            );

            CREATE TABLE IF NOT EXISTS subtitle_language_detection_distribution (
                detection_id INTEGER NOT NULL,
                language_code TEXT NOT NULL,
                share REAL NOT NULL,
                rank INTEGER NOT NULL,
                PRIMARY KEY(detection_id, language_code),
                FOREIGN KEY(detection_id) REFERENCES subtitle_language_detections(id) ON DELETE CASCADE
            );

            CREATE TABLE IF NOT EXISTS subtitle_cue_group_languages (
                cue_group_id INTEGER NOT NULL,
                language_code TEXT NOT NULL,
                PRIMARY KEY(cue_group_id, language_code),
                FOREIGN KEY(cue_group_id) REFERENCES subtitle_cue_groups(id) ON DELETE CASCADE
            );

            CREATE INDEX IF NOT EXISTS idx_subtitle_language_detections_lookup
                ON subtitle_language_detections(subtitle_file_id, scope, scope_key);

            CREATE INDEX IF NOT EXISTS idx_subtitle_cue_group_languages_language
                ON subtitle_cue_group_languages(language_code, cue_group_id);

            CREATE TABLE IF NOT EXISTS ass_render_segments (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                subtitle_file_id INTEGER NOT NULL,
                segment_index INTEGER NOT NULL,
                algorithm_version INTEGER NOT NULL DEFAULT 0,
                start_ms INTEGER NOT NULL,
                end_ms INTEGER NOT NULL,
                event_count INTEGER NOT NULL,
                byte_count INTEGER NOT NULL,
                script_text TEXT NOT NULL,
                UNIQUE(subtitle_file_id, segment_index),
                FOREIGN KEY(subtitle_file_id) REFERENCES subtitle_files(id) ON DELETE CASCADE
            );

            CREATE INDEX IF NOT EXISTS idx_ass_render_segments_lookup
                ON ass_render_segments(subtitle_file_id, start_ms, end_ms);

            CREATE TABLE IF NOT EXISTS ass_font_reference_manifests (
                subtitle_file_id INTEGER PRIMARY KEY,
                algorithm_version INTEGER NOT NULL,
                referenced_font_count INTEGER NOT NULL,
                extracted_at TEXT NOT NULL,
                FOREIGN KEY(subtitle_file_id) REFERENCES subtitle_files(id) ON DELETE CASCADE
            );

            CREATE TABLE IF NOT EXISTS ass_font_references (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                subtitle_file_id INTEGER NOT NULL,
                font_name TEXT NOT NULL,
                source_location TEXT NOT NULL,
                occurrence_count INTEGER NOT NULL,
                first_occurrence_order INTEGER NOT NULL,
                algorithm_version INTEGER NOT NULL,
                UNIQUE(subtitle_file_id, font_name, source_location, algorithm_version),
                FOREIGN KEY(subtitle_file_id) REFERENCES subtitle_files(id) ON DELETE CASCADE
            );

            CREATE INDEX IF NOT EXISTS idx_ass_font_references_lookup
                ON ass_font_references(subtitle_file_id, algorithm_version, first_occurrence_order);

            CREATE TABLE IF NOT EXISTS ass_font_resources (
                subtitle_file_id INTEGER PRIMARY KEY,
                video_file_id INTEGER NOT NULL,
                status TEXT NOT NULL,
                fonts_directory TEXT,
                resource_signature TEXT NOT NULL,
                error_message TEXT,
                prepared_at TEXT NOT NULL,
                FOREIGN KEY(subtitle_file_id) REFERENCES subtitle_files(id) ON DELETE CASCADE,
                FOREIGN KEY(video_file_id) REFERENCES video_files(id) ON DELETE CASCADE
            );

            CREATE TABLE IF NOT EXISTS library_playback_history (
                video_file_id INTEGER PRIMARY KEY,
                position_ms INTEGER NOT NULL,
                duration REAL,
                started_at TEXT,
                completed_at TEXT,
                updated_at TEXT NOT NULL,
                FOREIGN KEY(video_file_id) REFERENCES video_files(id) ON DELETE CASCADE
            );

            CREATE TABLE IF NOT EXISTS library_watch_states (
                video_file_id INTEGER PRIMARY KEY,
                state TEXT NOT NULL,
                updated_at TEXT NOT NULL,
                FOREIGN KEY(video_file_id) REFERENCES video_files(id) ON DELETE CASCADE
            );

            CREATE TABLE IF NOT EXISTS library_video_rows (
                video_path TEXT PRIMARY KEY,
                video_file_id INTEGER,
                subtitle_file_id INTEGER,
                video_name TEXT NOT NULL,
                duration REAL,
                subtitle_path TEXT NOT NULL,
                subtitle_format TEXT NOT NULL,
                folder_path TEXT NOT NULL,
                folder_title TEXT NOT NULL,
                display_title TEXT NOT NULL,
                file_extension TEXT NOT NULL,
                folder_order INTEGER NOT NULL,
                video_order INTEGER NOT NULL,
                updated_at TEXT NOT NULL,
                FOREIGN KEY(video_file_id) REFERENCES video_files(id),
                FOREIGN KEY(subtitle_file_id) REFERENCES subtitle_files(id)
            );

            CREATE INDEX IF NOT EXISTS idx_library_video_rows_scope
                ON library_video_rows(subtitle_path);

            CREATE INDEX IF NOT EXISTS idx_library_video_rows_order
                ON library_video_rows(folder_order, video_order);

            CREATE TABLE IF NOT EXISTS video_covers (
                video_file_id INTEGER PRIMARY KEY,
                cover_path TEXT NOT NULL,
                display_cover_path TEXT,
                display_profile_version INTEGER,
                source_time_ms INTEGER NOT NULL,
                score REAL,
                algorithm_version INTEGER NOT NULL,
                generated_file_size INTEGER,
                generated_duration REAL,
                status TEXT NOT NULL,
                error_message TEXT,
                generated_at TEXT NOT NULL,
                FOREIGN KEY(video_file_id) REFERENCES video_files(id) ON DELETE CASCADE
            );

            CREATE INDEX IF NOT EXISTS idx_video_covers_status
                ON video_covers(status);

            CREATE TABLE IF NOT EXISTS folder_covers (
                folder_path TEXT PRIMARY KEY,
                folder_id INTEGER,
                cover_path TEXT NOT NULL,
                source_video_file_id INTEGER NOT NULL,
                generated_at TEXT NOT NULL,
                FOREIGN KEY(folder_id) REFERENCES library_folders(id),
                FOREIGN KEY(source_video_file_id) REFERENCES video_files(id) ON DELETE CASCADE
            );

            CREATE INDEX IF NOT EXISTS idx_folder_covers_source_video
                ON folder_covers(source_video_file_id);

            CREATE UNIQUE INDEX IF NOT EXISTS idx_folder_covers_folder_id
                ON folder_covers(folder_id)
                WHERE folder_id IS NOT NULL;

            CREATE TABLE IF NOT EXISTS user_video_covers (
                video_file_id INTEGER PRIMARY KEY,
                display_cover_path TEXT NOT NULL,
                updated_at TEXT NOT NULL,
                FOREIGN KEY(video_file_id) REFERENCES video_files(id) ON DELETE CASCADE
            );

            CREATE TABLE IF NOT EXISTS user_folder_covers (
                folder_path TEXT PRIMARY KEY,
                folder_id INTEGER,
                display_cover_path TEXT NOT NULL,
                updated_at TEXT NOT NULL,
                FOREIGN KEY(folder_id) REFERENCES library_folders(id)
            );

            CREATE UNIQUE INDEX IF NOT EXISTS idx_user_folder_covers_folder_id
                ON user_folder_covers(folder_id)
                WHERE folder_id IS NOT NULL;

            CREATE TABLE IF NOT EXISTS subtitle_search_order_rows (
                subtitle_path TEXT PRIMARY KEY,
                subtitle_file_id INTEGER,
                folder_path TEXT NOT NULL,
                folder_title TEXT NOT NULL,
                subtitle_file_name TEXT NOT NULL,
                display_title TEXT NOT NULL,
                folder_order INTEGER NOT NULL,
                file_order INTEGER NOT NULL,
                updated_at TEXT NOT NULL,
                FOREIGN KEY(subtitle_file_id) REFERENCES subtitle_files(id)
            );

            CREATE INDEX IF NOT EXISTS idx_subtitle_search_order_rows_order
                ON subtitle_search_order_rows(folder_order, file_order, subtitle_path);

            CREATE TABLE IF NOT EXISTS cue_facet_counts (
                facet TEXT NOT NULL,
                value TEXT NOT NULL,
                cue_count INTEGER NOT NULL CHECK(cue_count >= 0),
                PRIMARY KEY(facet, value)
            );

            \(shioriSchemaSQL)

            \(taskRecordSchemaSQL)

            \(cueReferenceIntegrityTriggerSQL(excerptTable: "excerpts"))

            """
            )

            try database.execute("PRAGMA user_version = \(DatabaseBootstrap.currentSchemaVersion);")
        }
    }

    /// The task queue's history. Written by `TaskRecordDatabase`; see its
    /// documentation for why progress is not a column.
    static let taskRecordSchemaSQL = """
        CREATE TABLE IF NOT EXISTS task_records (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            kind TEXT NOT NULL,
            file_name TEXT NOT NULL,
            folder_path TEXT NOT NULL,
            item_count INTEGER NOT NULL,
            state TEXT NOT NULL,
            error_message TEXT,
            created_at TEXT NOT NULL,
            state_changed_at TEXT NOT NULL,
            old_paths TEXT,
            new_paths TEXT
        );
        """

    /// Adds the task queue's history. Nothing existing is read or rewritten.
    /// The table is created as version 45 had it; 45 to 46 adds its columns.
    static func migrateSchema44To45(on database: SQLiteDatabase) throws {
        try database.withImmediateTransaction {
            try database.execute(
                """
                CREATE TABLE IF NOT EXISTS task_records (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    kind TEXT NOT NULL,
                    file_name TEXT NOT NULL,
                    folder_path TEXT NOT NULL,
                    item_count INTEGER NOT NULL,
                    state TEXT NOT NULL,
                    error_message TEXT,
                    created_at TEXT NOT NULL,
                    state_changed_at TEXT NOT NULL
                );

                PRAGMA user_version = 45;
                """
            )
        }
    }

    /// Adds the paths a rename task records, so its history can name what it
    /// moved. Export records leave them empty.
    static func migrateSchema45To46(on database: SQLiteDatabase) throws {
        try database.withImmediateTransaction {
            let columns = try columnNames(of: "task_records", in: database)
            for column in ["old_paths", "new_paths"] where !columns.contains(column) {
                try database.execute("ALTER TABLE task_records ADD COLUMN \(column) TEXT;")
            }
            try database.execute("PRAGMA user_version = 46;")
        }
    }

    /// Shiori became Excerpt: its two tables and their indexes take the new
    /// names, keeping every row, id and cover path. The triggers name the
    /// Excerpt table, so they are dropped before the rename and recreated after.
    static func migrateSchema46To47(on database: SQLiteDatabase) throws {
        try database.withImmediateTransaction {
            try database.execute(
                """
                DROP TRIGGER IF EXISTS protect_referenced_cue_deletion;
                DROP TRIGGER IF EXISTS protect_referenced_tombstone_deletion;

                ALTER TABLE shiori_lists RENAME TO excerpt_lists;
                ALTER TABLE shioris RENAME TO excerpts;

                DROP INDEX IF EXISTS idx_shiori_lists_normalized_name;
                DROP INDEX IF EXISTS idx_shioris_list_order;
                DROP INDEX IF EXISTS idx_shioris_cue;
                DROP INDEX IF EXISTS idx_shioris_created_order;

                CREATE UNIQUE INDEX IF NOT EXISTS idx_excerpt_lists_normalized_name
                    ON excerpt_lists(normalized_name);

                CREATE INDEX IF NOT EXISTS idx_excerpts_list_order
                    ON excerpts(list_id, created_at DESC, id DESC);

                CREATE INDEX IF NOT EXISTS idx_excerpts_cue
                    ON excerpts(cue_id);

                CREATE INDEX IF NOT EXISTS idx_excerpts_created_order
                    ON excerpts(created_at DESC, id DESC);

                \(cueReferenceIntegrityTriggerSQL(excerptTable: "excerpts"))

                PRAGMA user_version = 47;
                """
            )
        }
    }

    static func migrateSchema33To34(on database: SQLiteDatabase) throws {
        try database.withImmediateTransaction {
            try database.execute(
                """
                ALTER TABLE shiori_lists
                    ADD COLUMN normalized_name TEXT NOT NULL DEFAULT '';
                ALTER TABLE shiori_lists
                    ADD COLUMN description TEXT NOT NULL DEFAULT '';
                ALTER TABLE shiori_lists
                    ADD COLUMN cover_path TEXT;

                UPDATE shiori_lists
                SET name = 'Default'
                WHERE id = 1 AND name = 'Shiori';

                UPDATE shiori_lists
                SET normalized_name = lower(trim(name));

                CREATE UNIQUE INDEX idx_shiori_lists_normalized_name
                    ON shiori_lists(normalized_name);

                PRAGMA user_version = 34;
                """
            )
        }
    }

    static func migrateSchema34To35(on database: SQLiteDatabase) throws {
        try database.withImmediateTransaction {
            try database.execute(
                """
                ALTER TABLE search_paths
                    ADD COLUMN last_known_path TEXT NOT NULL DEFAULT '';
                ALTER TABLE search_paths
                    ADD COLUMN resource_identity TEXT;
                ALTER TABLE search_paths
                    ADD COLUMN binding_state TEXT NOT NULL DEFAULT 'available';
                ALTER TABLE search_paths
                    ADD COLUMN is_configured INTEGER NOT NULL DEFAULT 1;
                ALTER TABLE search_paths
                    ADD COLUMN last_seen_at TEXT;
                ALTER TABLE search_paths
                    ADD COLUMN last_successful_index_at TEXT;
                ALTER TABLE search_paths
                    ADD COLUMN latest_index_token INTEGER NOT NULL DEFAULT 0;
                ALTER TABLE search_paths
                    ADD COLUMN published_index_token INTEGER NOT NULL DEFAULT 0;

                UPDATE search_paths
                SET last_known_path = path
                WHERE last_known_path = '';

                CREATE UNIQUE INDEX idx_search_paths_resource_identity
                    ON search_paths(resource_identity)
                    WHERE resource_identity IS NOT NULL;

                CREATE TABLE library_folders (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    library_id INTEGER NOT NULL,
                    relative_path TEXT NOT NULL,
                    last_known_path TEXT NOT NULL,
                    resource_identity TEXT,
                    binding_state TEXT NOT NULL DEFAULT 'available',
                    last_seen_at TEXT,
                    UNIQUE(library_id, relative_path),
                    FOREIGN KEY(library_id) REFERENCES search_paths(id)
                );

                CREATE UNIQUE INDEX idx_library_folders_resource_identity
                    ON library_folders(library_id, resource_identity)
                    WHERE resource_identity IS NOT NULL;

                ALTER TABLE subtitle_files
                    ADD COLUMN folder_id INTEGER REFERENCES library_folders(id);
                ALTER TABLE subtitle_files
                    ADD COLUMN last_known_path TEXT NOT NULL DEFAULT '';
                ALTER TABLE subtitle_files
                    ADD COLUMN resource_identity TEXT;
                ALTER TABLE subtitle_files
                    ADD COLUMN content_fingerprint TEXT;
                ALTER TABLE subtitle_files
                    ADD COLUMN binding_state TEXT NOT NULL DEFAULT 'available';
                ALTER TABLE subtitle_files
                    ADD COLUMN last_seen_at TEXT;

                UPDATE subtitle_files
                SET last_known_path = subtitle_path
                WHERE last_known_path = '';

                CREATE UNIQUE INDEX idx_subtitle_files_resource_identity
                    ON subtitle_files(library_id, resource_identity)
                    WHERE resource_identity IS NOT NULL;

                ALTER TABLE video_files
                    ADD COLUMN folder_id INTEGER REFERENCES library_folders(id);
                ALTER TABLE video_files
                    ADD COLUMN last_known_path TEXT NOT NULL DEFAULT '';
                ALTER TABLE video_files
                    ADD COLUMN resource_identity TEXT;
                ALTER TABLE video_files
                    ADD COLUMN content_fingerprint TEXT;
                ALTER TABLE video_files
                    ADD COLUMN binding_state TEXT NOT NULL DEFAULT 'available';
                ALTER TABLE video_files
                    ADD COLUMN last_seen_at TEXT;

                UPDATE video_files
                SET last_known_path = path
                WHERE last_known_path = '';

                CREATE UNIQUE INDEX idx_video_files_resource_identity
                    ON video_files(library_id, resource_identity)
                    WHERE resource_identity IS NOT NULL;

                ALTER TABLE subtitle_cue_lines
                    ADD COLUMN source_identity_remainder TEXT NOT NULL DEFAULT '';

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

                CREATE INDEX idx_cue_tombstones_subtitle
                    ON cue_tombstones(subtitle_file_id, cue_id);

                CREATE TABLE cue_change_notices (
                    cue_id INTEGER PRIMARY KEY,
                    previous_content TEXT NOT NULL,
                    current_content TEXT NOT NULL,
                    changed_at TEXT NOT NULL
                );

                CREATE TABLE shioris_v35 (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    list_id INTEGER NOT NULL,
                    cue_id INTEGER NOT NULL,
                    created_at TEXT NOT NULL,
                    UNIQUE(list_id, cue_id),
                    FOREIGN KEY(list_id) REFERENCES shiori_lists(id) ON DELETE CASCADE
                );

                INSERT INTO shioris_v35(id, list_id, cue_id, created_at)
                SELECT id, list_id, cue_id, created_at
                FROM shioris;

                CREATE TABLE shiori_tag_assignments_v35 (
                    shiori_id INTEGER NOT NULL,
                    tag_id INTEGER NOT NULL,
                    created_at TEXT NOT NULL,
                    PRIMARY KEY(shiori_id, tag_id),
                    FOREIGN KEY(shiori_id) REFERENCES shioris_v35(id) ON DELETE CASCADE,
                    FOREIGN KEY(tag_id) REFERENCES shiori_tags(id) ON DELETE CASCADE
                );

                INSERT INTO shiori_tag_assignments_v35(shiori_id, tag_id, created_at)
                SELECT shiori_id, tag_id, created_at
                FROM shiori_tag_assignments;

                DROP TABLE shiori_tag_assignments;
                DROP TABLE shioris;
                ALTER TABLE shioris_v35 RENAME TO shioris;
                ALTER TABLE shiori_tag_assignments_v35 RENAME TO shiori_tag_assignments;

                CREATE INDEX idx_shioris_list_order
                    ON shioris(list_id, created_at DESC, id DESC);
                CREATE INDEX idx_shioris_cue
                    ON shioris(cue_id);
                CREATE INDEX idx_shioris_created_order
                    ON shioris(created_at DESC, id DESC);
                CREATE INDEX idx_shiori_tag_assignments_tag
                    ON shiori_tag_assignments(tag_id, shiori_id);
                CREATE INDEX idx_shiori_tag_assignments_shiori
                    ON shiori_tag_assignments(shiori_id, created_at, tag_id);

                CREATE TABLE resource_binding_conflicts (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    library_id INTEGER NOT NULL,
                    resource_kind TEXT NOT NULL,
                    existing_resource_id INTEGER,
                    candidate_path TEXT NOT NULL,
                    reason TEXT NOT NULL,
                    created_at TEXT NOT NULL,
                    resolved_at TEXT,
                    FOREIGN KEY(library_id) REFERENCES search_paths(id)
                );

                CREATE INDEX idx_resource_binding_conflicts_unresolved
                    ON resource_binding_conflicts(library_id, resolved_at, id);

                PRAGMA user_version = 35;
                """
            )
        }
    }

    static func migrateSchema35To36(on database: SQLiteDatabase) throws {
        try database.withImmediateTransaction {
            try database.execute(
                """
                ALTER TABLE folder_covers
                    ADD COLUMN folder_id INTEGER REFERENCES library_folders(id);
                CREATE UNIQUE INDEX idx_folder_covers_folder_id
                    ON folder_covers(folder_id)
                    WHERE folder_id IS NOT NULL;

                ALTER TABLE user_folder_covers
                    ADD COLUMN folder_id INTEGER REFERENCES library_folders(id);
                CREATE UNIQUE INDEX idx_user_folder_covers_folder_id
                    ON user_folder_covers(folder_id)
                    WHERE folder_id IS NOT NULL;

                PRAGMA user_version = 36;
                """
            )
        }
    }

    static func migrateSchema36To37(on database: SQLiteDatabase) throws {
        try database.withImmediateTransaction {
            try database.execute(
                """
                ALTER TABLE search_paths
                    ADD COLUMN presentation_retry_pending INTEGER NOT NULL DEFAULT 0;
                ALTER TABLE video_files
                    ADD COLUMN duration_retry_pending INTEGER NOT NULL DEFAULT 0;

                UPDATE cue_tombstones
                SET unavailable_reason = CASE
                    WHEN unavailable_reason = 'cue_missing'
                    THEN 'cue_missing'
                    WHEN EXISTS (
                        SELECT 1
                        FROM subtitle_files sf
                        WHERE sf.id = cue_tombstones.subtitle_file_id
                          AND sf.binding_state = 'removed'
                    )
                    THEN 'library_unavailable'
                    WHEN EXISTS (
                        SELECT 1
                        FROM subtitle_files sf
                        WHERE sf.id = cue_tombstones.subtitle_file_id
                          AND sf.binding_state <> 'available'
                    )
                    THEN 'subtitle_missing'
                    ELSE 'cue_missing'
                END;

                PRAGMA user_version = 37;
                """
            )
        }
    }

    static func migrateSchema37To38(on database: SQLiteDatabase) throws {
        try database.withImmediateTransaction {
            try database.execute(
                """
                ALTER TABLE shiori_lists
                    ADD COLUMN recent_cue_id INTEGER;
                ALTER TABLE shiori_lists
                    ADD COLUMN recent_sort_order TEXT;
                ALTER TABLE shiori_lists
                    ADD COLUMN recent_played_at TEXT;

                PRAGMA user_version = 38;
                """
            )
        }
    }

    static func migrateSchema38To39(on database: SQLiteDatabase) throws {
        try database.withImmediateTransaction {
            try database.execute(
                """
                DROP INDEX IF EXISTS idx_subtitle_cue_line_speakers_group;
                DROP INDEX IF EXISTS idx_subtitle_cue_line_speakers_speaker;
                DROP TABLE IF EXISTS subtitle_cue_line_speakers;

                DROP INDEX IF EXISTS idx_ai_chunk_cache_entries_lookup;
                DROP TABLE IF EXISTS ai_chunk_cache_entries;

                PRAGMA user_version = 39;
                """
            )
        }
    }

    static func migrateSchema39To40(on database: SQLiteDatabase) throws {
        try database.withImmediateTransaction {
            try database.execute(
                """
                CREATE TABLE cue_facet_counts (
                    facet TEXT NOT NULL,
                    value TEXT NOT NULL,
                    cue_count INTEGER NOT NULL CHECK(cue_count >= 0),
                    PRIMARY KEY(facet, value)
                );
                """
            )
            let indexedContent = try database.prepare(
                "SELECT 1 FROM sqlite_schema WHERE type = 'table' AND name = 'subtitle_video_matches';"
            )
            if try indexedContent.step() {
                try CueFacetCountCache.rebuildAll(on: database)
            }
            try database.execute("PRAGMA user_version = 40;")
        }
    }

    static func migrateSchema40To41(on database: SQLiteDatabase) throws {
        try database.withImmediateTransaction {
            try database.execute(
                """
                DROP TABLE IF EXISTS shiori_tag_assignments;
                DROP TABLE IF EXISTS shiori_tags;

                PRAGMA user_version = 41;
                """
            )
        }
    }

    static func migrateSchema41To42(on database: SQLiteDatabase) throws {
        try database.withImmediateTransaction {
            try database.execute(
                """
                INSERT INTO cue_tombstones(
                    cue_id,
                    subtitle_file_id,
                    source_format,
                    source_style,
                    source_identity_remainder,
                    start_time,
                    end_time,
                    start_ms,
                    end_ms,
                    content,
                    cue_group_content,
                    display_title,
                    subtitle_path,
                    video_path,
                    unavailable_reason,
                    tombstoned_at,
                    updated_at
                )
                SELECT DISTINCT s.cue_id,
                       0,
                       '',
                       NULL,
                       '',
                       '',
                       '',
                       0,
                       0,
                       '',
                       '',
                       '',
                       NULL,
                       NULL,
                       'cue_missing',
                       strftime('%Y-%m-%dT%H:%M:%fZ', 'now'),
                       strftime('%Y-%m-%dT%H:%M:%fZ', 'now')
                FROM shioris s
                LEFT JOIN subtitle_cue_lines l ON l.id = s.cue_id
                LEFT JOIN cue_tombstones t ON t.cue_id = s.cue_id
                WHERE l.id IS NULL AND t.cue_id IS NULL;

                \(cueReferenceIntegrityTriggerSQL(excerptTable: "shioris"))

                PRAGMA user_version = 42;
                """
            )
        }
    }

    /// Watch state, progress and playback history reference the VideoID, never a path.
    static func migrateSchema43To44(on database: SQLiteDatabase) throws {
        guard try columnNames(of: "library_watch_states", in: database).contains("video_path")
        else {
            try database.execute("PRAGMA user_version = 44;")
            return
        }

        try database.withImmediateTransaction {
            try database.execute(
                """
                CREATE TABLE library_playback_history_v44 (
                    video_file_id INTEGER PRIMARY KEY,
                    position_ms INTEGER NOT NULL,
                    duration REAL,
                    started_at TEXT,
                    completed_at TEXT,
                    updated_at TEXT NOT NULL,
                    FOREIGN KEY(video_file_id) REFERENCES video_files(id) ON DELETE CASCADE
                );

                INSERT INTO library_playback_history_v44(
                    video_file_id, position_ms, duration,
                    started_at, completed_at, updated_at
                )
                SELECT video_file_id, position_ms, duration,
                       started_at, completed_at, updated_at
                FROM library_playback_history
                WHERE video_file_id IS NOT NULL;

                DROP TABLE library_playback_history;
                ALTER TABLE library_playback_history_v44
                    RENAME TO library_playback_history;

                CREATE TABLE library_watch_states_v44 (
                    video_file_id INTEGER PRIMARY KEY,
                    state TEXT NOT NULL,
                    updated_at TEXT NOT NULL,
                    FOREIGN KEY(video_file_id) REFERENCES video_files(id) ON DELETE CASCADE
                );

                INSERT INTO library_watch_states_v44(video_file_id, state, updated_at)
                SELECT video_file_id, state, updated_at
                FROM library_watch_states
                WHERE video_file_id IS NOT NULL;

                DROP TABLE library_watch_states;
                ALTER TABLE library_watch_states_v44
                    RENAME TO library_watch_states;

                PRAGMA user_version = 44;
                """
            )
        }
    }

    /// Removes the platform resource identity and binding state machine.
    ///
    /// Resources that had already left the index keep no data: their rows and the
    /// covers, watch states, progress and playback history that belong to them are
    /// deleted. Cues still referenced by a Shiori are tombstoned first.
    static func migrateSchema42To43(on database: SQLiteDatabase) throws {
        guard try columnNames(of: "search_paths", in: database).contains("binding_state")
        else {
            try database.execute("PRAGMA user_version = 43;")
            return
        }

        try database.withImmediateTransaction {
            try database.execute(
                """
                CREATE TEMP TABLE retired_libraries AS
                    SELECT id FROM search_paths
                    WHERE binding_state <> 'available' OR is_configured = 0;

                CREATE TEMP TABLE retired_folders AS
                    SELECT id FROM library_folders
                    WHERE binding_state <> 'available'
                       OR library_id IN (SELECT id FROM retired_libraries);

                CREATE TEMP TABLE retired_subtitles AS
                    SELECT id FROM subtitle_files
                    WHERE binding_state <> 'available'
                       OR library_id IN (SELECT id FROM retired_libraries);

                CREATE TEMP TABLE retired_videos AS
                    SELECT id FROM video_files
                    WHERE binding_state <> 'available'
                       OR library_id IN (SELECT id FROM retired_libraries);

                INSERT INTO cue_tombstones(
                    cue_id,
                    subtitle_file_id,
                    source_format,
                    source_style,
                    source_identity_remainder,
                    start_time,
                    end_time,
                    start_ms,
                    end_ms,
                    content,
                    cue_group_content,
                    display_title,
                    subtitle_path,
                    video_path,
                    unavailable_reason,
                    tombstoned_at,
                    updated_at
                )
                SELECT l.id,
                       l.subtitle_file_id,
                       l.source_format,
                       l.source_style,
                       l.source_identity_remainder,
                       l.start_time,
                       l.end_time,
                       l.start_ms,
                       l.end_ms,
                       l.content,
                       COALESCE(
                         (
                           SELECT GROUP_CONCAT(ordered.content, char(31))
                           FROM (
                             SELECT group_cue.content
                             FROM subtitle_cue_lines group_cue
                             WHERE group_cue.cue_group_id = l.cue_group_id
                             ORDER BY group_cue.display_order ASC,
                                      group_cue.event_index ASC,
                                      group_cue.id ASC
                           ) ordered
                         ),
                         l.content
                       ),
                       COALESCE(
                         (
                           SELECT lvr.display_title
                           FROM library_video_rows lvr
                           WHERE lvr.subtitle_file_id = sf.id
                           LIMIT 1
                         ),
                         vf.video_name,
                         ''
                       ),
                       COALESCE(NULLIF(sf.last_known_path, ''), sf.subtitle_path),
                       COALESCE(NULLIF(vf.last_known_path, ''), vf.path),
                       'cue_missing',
                       strftime('%Y-%m-%dT%H:%M:%fZ', 'now'),
                       strftime('%Y-%m-%dT%H:%M:%fZ', 'now')
                FROM subtitle_cue_lines l
                JOIN shioris s ON s.cue_id = l.id
                JOIN subtitle_files sf ON sf.id = l.subtitle_file_id
                LEFT JOIN cue_tombstones t ON t.cue_id = l.id
                LEFT JOIN subtitle_video_matches m
                  ON m.subtitle_file_id = sf.id AND m.is_active = 1
                LEFT JOIN video_files vf ON vf.id = m.video_file_id
                WHERE t.cue_id IS NULL
                  AND sf.id IN (SELECT id FROM retired_subtitles);

                DELETE FROM subtitle_search_order_rows
                WHERE subtitle_file_id IN (SELECT id FROM retired_subtitles);

                DELETE FROM library_video_rows
                WHERE subtitle_file_id IN (SELECT id FROM retired_subtitles)
                   OR video_file_id IN (SELECT id FROM retired_videos);

                DELETE FROM library_playback_history
                WHERE video_file_id IN (SELECT id FROM retired_videos);

                DELETE FROM library_watch_states
                WHERE video_file_id IN (SELECT id FROM retired_videos);

                DELETE FROM folder_covers
                WHERE folder_id IN (SELECT id FROM retired_folders);

                DELETE FROM user_folder_covers
                WHERE folder_id IN (SELECT id FROM retired_folders);

                DELETE FROM subtitle_files
                WHERE id IN (SELECT id FROM retired_subtitles);

                DELETE FROM video_files
                WHERE id IN (SELECT id FROM retired_videos);

                UPDATE subtitle_files SET folder_id = NULL
                WHERE folder_id IN (SELECT id FROM retired_folders);

                UPDATE video_files SET folder_id = NULL
                WHERE folder_id IN (SELECT id FROM retired_folders);

                DELETE FROM library_folders
                WHERE id IN (SELECT id FROM retired_folders);

                DELETE FROM search_paths
                WHERE id IN (SELECT id FROM retired_libraries);

                DROP TABLE retired_videos;
                DROP TABLE retired_subtitles;
                DROP TABLE retired_folders;
                DROP TABLE retired_libraries;

                DROP TABLE IF EXISTS resource_binding_conflicts;
                DROP INDEX IF EXISTS idx_search_paths_resource_identity;
                DROP INDEX IF EXISTS idx_library_folders_resource_identity;
                DROP INDEX IF EXISTS idx_subtitle_files_resource_identity;
                DROP INDEX IF EXISTS idx_video_files_resource_identity;

                ALTER TABLE search_paths DROP COLUMN resource_identity;
                ALTER TABLE search_paths DROP COLUMN binding_state;
                ALTER TABLE search_paths DROP COLUMN last_known_path;
                ALTER TABLE search_paths DROP COLUMN last_seen_at;
                ALTER TABLE search_paths DROP COLUMN is_configured;
                ALTER TABLE search_paths DROP COLUMN latest_index_token;
                ALTER TABLE search_paths DROP COLUMN published_index_token;

                ALTER TABLE library_folders DROP COLUMN resource_identity;
                ALTER TABLE library_folders DROP COLUMN binding_state;
                ALTER TABLE library_folders DROP COLUMN last_known_path;
                ALTER TABLE library_folders DROP COLUMN last_seen_at;

                ALTER TABLE subtitle_files DROP COLUMN resource_identity;
                ALTER TABLE subtitle_files DROP COLUMN content_fingerprint;
                ALTER TABLE subtitle_files DROP COLUMN binding_state;
                ALTER TABLE subtitle_files DROP COLUMN last_known_path;
                ALTER TABLE subtitle_files DROP COLUMN last_seen_at;

                ALTER TABLE video_files DROP COLUMN resource_identity;
                ALTER TABLE video_files DROP COLUMN content_fingerprint;
                ALTER TABLE video_files DROP COLUMN binding_state;
                ALTER TABLE video_files DROP COLUMN last_known_path;
                ALTER TABLE video_files DROP COLUMN last_seen_at;

                PRAGMA user_version = 43;
                """
            )

            try CueFacetCountCache.rebuildAll(on: database)
        }
    }

}

extension DatabaseBootstrap {
    /// Refuses to delete a Cue, or its Tombstone, while an Excerpt still refers
    /// to it. The table is a parameter because the 41 to 42 migration creates
    /// these triggers while the table still has its pre-47 name.
    static func cueReferenceIntegrityTriggerSQL(excerptTable: String) -> String {
        """
        CREATE TRIGGER IF NOT EXISTS protect_referenced_cue_deletion
        BEFORE DELETE ON subtitle_cue_lines
        WHEN EXISTS (
               SELECT 1 FROM \(excerptTable) WHERE cue_id = OLD.id
             )
             AND NOT EXISTS (
               SELECT 1 FROM cue_tombstones WHERE cue_id = OLD.id
             )
        BEGIN
            SELECT RAISE(ABORT, 'Referenced Cue requires a Tombstone before deletion');
        END;

        CREATE TRIGGER IF NOT EXISTS protect_referenced_tombstone_deletion
        BEFORE DELETE ON cue_tombstones
        WHEN EXISTS (
               SELECT 1 FROM \(excerptTable) WHERE cue_id = OLD.cue_id
             )
             AND NOT EXISTS (
               SELECT 1 FROM subtitle_cue_lines WHERE id = OLD.cue_id
             )
        BEGIN
            SELECT RAISE(ABORT, 'Referenced Tombstone cannot be deleted without a live Cue');
        END;
        """
    }
}
