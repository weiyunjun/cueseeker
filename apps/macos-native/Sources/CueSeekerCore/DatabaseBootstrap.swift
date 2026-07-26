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
    public static let currentSchemaVersion = 39

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
    static func prepareSchema(on database: SQLiteDatabase) throws {
        let previousVersion = try schemaVersion(in: database)

        guard previousVersion == 0
                || previousVersion == 33
                || previousVersion == 34
                || previousVersion == 35
                || previousVersion == 36
                || previousVersion == 37
                || previousVersion == 38
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
                    last_known_path TEXT NOT NULL DEFAULT '',
                    resource_identity TEXT,
                    binding_state TEXT NOT NULL DEFAULT 'available',
                    is_configured INTEGER NOT NULL DEFAULT 1,
                    last_seen_at TEXT,
                    last_successful_index_at TEXT,
                    latest_index_token INTEGER NOT NULL DEFAULT 0,
                    published_index_token INTEGER NOT NULL DEFAULT 0,
                    presentation_retry_pending INTEGER NOT NULL DEFAULT 0,
                    created_at TEXT NOT NULL,
                    updated_at TEXT NOT NULL
                );

                CREATE UNIQUE INDEX IF NOT EXISTS idx_search_paths_resource_identity
                    ON search_paths(resource_identity)
                    WHERE resource_identity IS NOT NULL;

                CREATE TABLE IF NOT EXISTS library_folders (
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

                CREATE UNIQUE INDEX IF NOT EXISTS idx_library_folders_resource_identity
                    ON library_folders(library_id, resource_identity)
                    WHERE resource_identity IS NOT NULL;
                """
            )

            let shioriSchemaSQL = """
                CREATE TABLE IF NOT EXISTS shiori_lists (
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

                INSERT OR IGNORE INTO shiori_lists(
                    id,
                    name,
                    normalized_name,
                    description,
                    cover_path,
                    created_at
                )
                VALUES (1, 'Default', 'default', '', NULL, '1970-01-01T00:00:00Z');

                CREATE UNIQUE INDEX IF NOT EXISTS idx_shiori_lists_normalized_name
                    ON shiori_lists(normalized_name);

                CREATE TABLE IF NOT EXISTS shioris (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    list_id INTEGER NOT NULL,
                    cue_id INTEGER NOT NULL,
                    created_at TEXT NOT NULL,
                    UNIQUE(list_id, cue_id),
                    FOREIGN KEY(list_id) REFERENCES shiori_lists(id) ON DELETE CASCADE
                );

                CREATE INDEX IF NOT EXISTS idx_shioris_list_order
                    ON shioris(list_id, created_at DESC, id DESC);

                CREATE INDEX IF NOT EXISTS idx_shioris_cue
                    ON shioris(cue_id);

                CREATE INDEX IF NOT EXISTS idx_shioris_created_order
                    ON shioris(created_at DESC, id DESC);
                """

            try database.execute(
            """
            CREATE TABLE IF NOT EXISTS subtitle_files (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                library_id INTEGER,
                folder_id INTEGER,
                relative_path TEXT,
                subtitle_path TEXT NOT NULL UNIQUE,
                last_known_path TEXT NOT NULL DEFAULT '',
                resource_identity TEXT,
                content_fingerprint TEXT,
                binding_state TEXT NOT NULL DEFAULT 'available',
                last_seen_at TEXT,
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
                last_known_path TEXT NOT NULL DEFAULT '',
                resource_identity TEXT,
                content_fingerprint TEXT,
                binding_state TEXT NOT NULL DEFAULT 'available',
                last_seen_at TEXT,
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

            CREATE UNIQUE INDEX IF NOT EXISTS idx_subtitle_files_resource_identity
                ON subtitle_files(library_id, resource_identity)
                WHERE resource_identity IS NOT NULL;

            CREATE UNIQUE INDEX IF NOT EXISTS idx_video_files_resource_identity
                ON video_files(library_id, resource_identity)
                WHERE resource_identity IS NOT NULL;

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
                video_path TEXT PRIMARY KEY,
                video_file_id INTEGER,
                position_ms INTEGER NOT NULL,
                duration REAL,
                started_at TEXT,
                completed_at TEXT,
                updated_at TEXT NOT NULL,
                FOREIGN KEY(video_file_id) REFERENCES video_files(id)
            );

            CREATE TABLE IF NOT EXISTS library_watch_states (
                video_path TEXT PRIMARY KEY,
                video_file_id INTEGER,
                state TEXT NOT NULL,
                updated_at TEXT NOT NULL,
                FOREIGN KEY(video_file_id) REFERENCES video_files(id)
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

            CREATE TABLE IF NOT EXISTS resource_binding_conflicts (
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

            CREATE INDEX IF NOT EXISTS idx_resource_binding_conflicts_unresolved
                ON resource_binding_conflicts(library_id, resolved_at, id);

            \(shioriSchemaSQL)

            CREATE TABLE IF NOT EXISTS shiori_tags (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                normalized_name TEXT NOT NULL UNIQUE,
                created_at TEXT NOT NULL
            );

            CREATE INDEX IF NOT EXISTS idx_shiori_tags_name
                ON shiori_tags(normalized_name);

            CREATE TABLE IF NOT EXISTS shiori_tag_assignments (
                shiori_id INTEGER NOT NULL,
                tag_id INTEGER NOT NULL,
                created_at TEXT NOT NULL,
                PRIMARY KEY(shiori_id, tag_id),
                FOREIGN KEY(shiori_id) REFERENCES shioris(id) ON DELETE CASCADE,
                FOREIGN KEY(tag_id) REFERENCES shiori_tags(id) ON DELETE CASCADE
            );

            CREATE INDEX IF NOT EXISTS idx_shiori_tag_assignments_tag
                ON shiori_tag_assignments(tag_id, shiori_id);

            CREATE INDEX IF NOT EXISTS idx_shiori_tag_assignments_shiori
                ON shiori_tag_assignments(shiori_id, created_at, tag_id);

            """
            )

            try database.execute("PRAGMA user_version = \(DatabaseBootstrap.currentSchemaVersion);")
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

}
