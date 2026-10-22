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
    public static let currentSchemaVersion = 58

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

extension DatabaseBootstrap {
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
                || previousVersion == 47
                || previousVersion == 48
                || previousVersion == 49
                || previousVersion == 50
                || previousVersion == 51
                || previousVersion == 52
                || previousVersion == 53
                || previousVersion == 54
                || previousVersion == 55
                || previousVersion == 56
                || previousVersion == 57
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
        // Earlier migrations rebuild the facet counts, which read the cue line
        // language table from schema 49 on and the precomputed duration and
        // character width columns from schema 58 on, so they exist before any
        // of them runs; schema 49 and schema 58 fill them.
        if previousVersion >= 33, previousVersion <= 48 {
            try database.execute(cueLineLanguagesTableSQL)
        }
        if previousVersion >= 33, previousVersion <= 55 {
            try ensureCueLinePrecomputedAttributeColumns(on: database)
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
        }
        if previousVersion >= 33, previousVersion <= 47 {
            try migrateSchema47To48(on: database)
        }
        if previousVersion >= 33, previousVersion <= 48 {
            try migrateSchema48To49(on: database)
        }
        if previousVersion >= 33, previousVersion <= 49 {
            try migrateSchema49To50(on: database)
        }
        if previousVersion >= 33, previousVersion <= 50 {
            try migrateSchema50To51(on: database)
        }
        if previousVersion >= 33, previousVersion <= 51 {
            try migrateSchema51To52(on: database)
        }
        if previousVersion >= 33, previousVersion <= 53 {
            try migrateSchema53To54(on: database)
        }
        if previousVersion >= 33, previousVersion <= 54 {
            try migrateSchema54To55(on: database)
        }
        if previousVersion >= 33, previousVersion <= 55 {
            try migrateSchema55To56(on: database)
        }
        if previousVersion >= 33, previousVersion <= 56 {
            try migrateSchema56To57(on: database)
        }
        if previousVersion >= 33, previousVersion <= 57 {
            try migrateSchema57To58(on: database)
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

            let excerptSchemaSQL = """
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
                display_title TEXT,
                file_size INTEGER,
                modified_at REAL,
                duration REAL,
                duration_retry_pending INTEGER NOT NULL DEFAULT 0,
                video_width INTEGER,
                video_height INTEGER,
                frame_rate REAL,
                video_codec TEXT,
                audio_codec TEXT,
                audio_tracks TEXT,
                default_audio_track_index INTEGER NOT NULL DEFAULT 0,
                default_subtitle_file_id INTEGER,
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
                fts_rowid INTEGER NOT NULL DEFAULT 0,
                language_mask INTEGER NOT NULL DEFAULT 0,
                event_index INTEGER NOT NULL,
                source_format TEXT NOT NULL,
                source_style TEXT,
                source_layer INTEGER,
                source_identity_remainder TEXT NOT NULL DEFAULT '',
                start_time TEXT NOT NULL,
                end_time TEXT NOT NULL,
                start_ms INTEGER NOT NULL,
                end_ms INTEGER NOT NULL,
                duration_ms INTEGER NOT NULL DEFAULT 0,
                character_width INTEGER NOT NULL DEFAULT 0,
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
                duration_ms INTEGER NOT NULL DEFAULT 0,
                character_width INTEGER NOT NULL DEFAULT 0,
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

            CREATE INDEX IF NOT EXISTS idx_subtitle_cue_lines_fts_covering
                ON subtitle_cue_lines(fts_rowid, display_order, event_index, id, cue_group_id, start_ms, end_ms, duration_ms, character_width, language_mask, content);

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

            \(cueLineLanguagesTableSQL)

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

            CREATE INDEX IF NOT EXISTS idx_library_video_rows_folder_path
                ON library_video_rows(folder_path);

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

            CREATE INDEX IF NOT EXISTS idx_subtitle_search_order_rows_file_id
                ON subtitle_search_order_rows(subtitle_file_id);

            CREATE TABLE IF NOT EXISTS cue_facet_counts (
                facet TEXT NOT NULL,
                value TEXT NOT NULL,
                cue_count INTEGER NOT NULL CHECK(cue_count >= 0),
                PRIMARY KEY(facet, value)
            );

            \(excerptSchemaSQL)

            \(taskRecordSchemaSQL)

            \(videoTombstonesTableSQL)

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

    static let videoTombstonesTableSQL = """
        CREATE TABLE IF NOT EXISTS video_tombstones (
            video_path TEXT PRIMARY KEY,
            position_ms INTEGER NOT NULL DEFAULT 0,
            duration REAL,
            watch_state TEXT NOT NULL DEFAULT 'unwatched',
            user_cover_path TEXT,
            default_audio_track_index INTEGER NOT NULL DEFAULT 0,
            tombstoned_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
        );
        """

    static let cueLineLanguagesTableSQL = """
        CREATE TABLE IF NOT EXISTS subtitle_cue_line_languages (
            cue_id INTEGER NOT NULL,
            language_code TEXT NOT NULL,
            PRIMARY KEY(cue_id, language_code),
            FOREIGN KEY(cue_id) REFERENCES subtitle_cue_lines(id) ON DELETE CASCADE
        );
        """

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
