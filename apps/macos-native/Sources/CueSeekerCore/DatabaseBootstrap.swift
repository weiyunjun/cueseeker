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
    public static let currentSchemaVersion = 34

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
                || previousVersion == DatabaseBootstrap.currentSchemaVersion
        else {
            throw DatabaseBootstrapError.unsupportedSchemaVersion(
                found: previousVersion,
                supported: DatabaseBootstrap.currentSchemaVersion
            )
        }
        if previousVersion == 33 {
            try migrateSchema33To34(on: database)
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
                    created_at TEXT NOT NULL,
                    updated_at TEXT NOT NULL
                );
                """
            )

            let shioriSchemaSQL = """
                CREATE TABLE IF NOT EXISTS shiori_lists (
                    id INTEGER PRIMARY KEY,
                    name TEXT NOT NULL,
                    normalized_name TEXT NOT NULL,
                    description TEXT NOT NULL DEFAULT '',
                    cover_path TEXT,
                    created_at TEXT NOT NULL
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
                    FOREIGN KEY(list_id) REFERENCES shiori_lists(id) ON DELETE CASCADE,
                    FOREIGN KEY(cue_id) REFERENCES subtitle_cue_lines(id) ON DELETE CASCADE
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
                relative_path TEXT,
                subtitle_path TEXT NOT NULL UNIQUE,
                format TEXT NOT NULL,
                file_size INTEGER,
                modified_at REAL,
                indexed_at TEXT NOT NULL,
                index_algorithm_version INTEGER NOT NULL DEFAULT 0,
                FOREIGN KEY(library_id) REFERENCES search_paths(id)
            );

            CREATE TABLE IF NOT EXISTS video_files (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                library_id INTEGER,
                relative_path TEXT,
                path TEXT NOT NULL UNIQUE,
                video_name TEXT NOT NULL,
                file_size INTEGER,
                modified_at REAL,
                duration REAL,
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
                FOREIGN KEY(library_id) REFERENCES search_paths(id)
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

            CREATE TABLE IF NOT EXISTS subtitle_cue_line_speakers (
                cue_line_id INTEGER NOT NULL,
                cue_group_id INTEGER NOT NULL,
                speaker TEXT NOT NULL,
                speaker_key TEXT NOT NULL,
                PRIMARY KEY(cue_line_id, speaker_key),
                FOREIGN KEY(cue_line_id) REFERENCES subtitle_cue_lines(id) ON DELETE CASCADE,
                FOREIGN KEY(cue_group_id) REFERENCES subtitle_cue_groups(id) ON DELETE CASCADE
            );

            CREATE INDEX IF NOT EXISTS idx_subtitle_cue_line_speakers_group
                ON subtitle_cue_line_speakers(cue_group_id, speaker_key);

            CREATE INDEX IF NOT EXISTS idx_subtitle_cue_line_speakers_speaker
                ON subtitle_cue_line_speakers(speaker_key, cue_group_id);

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
                cover_path TEXT NOT NULL,
                source_video_file_id INTEGER NOT NULL,
                generated_at TEXT NOT NULL,
                FOREIGN KEY(source_video_file_id) REFERENCES video_files(id) ON DELETE CASCADE
            );

            CREATE INDEX IF NOT EXISTS idx_folder_covers_source_video
                ON folder_covers(source_video_file_id);

            CREATE TABLE IF NOT EXISTS user_video_covers (
                video_file_id INTEGER PRIMARY KEY,
                display_cover_path TEXT NOT NULL,
                updated_at TEXT NOT NULL,
                FOREIGN KEY(video_file_id) REFERENCES video_files(id) ON DELETE CASCADE
            );

            CREATE TABLE IF NOT EXISTS user_folder_covers (
                folder_path TEXT PRIMARY KEY,
                display_cover_path TEXT NOT NULL,
                updated_at TEXT NOT NULL
            );

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

            CREATE TABLE IF NOT EXISTS ai_chunk_cache_entries (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                normalized_sentence TEXT NOT NULL,
                provider TEXT NOT NULL,
                model TEXT NOT NULL,
                prompt_version TEXT NOT NULL,
                chunks_json TEXT NOT NULL,
                cache_date TEXT NOT NULL,
                UNIQUE(normalized_sentence, provider, model, prompt_version)
            );

            CREATE INDEX IF NOT EXISTS idx_ai_chunk_cache_entries_lookup
                ON ai_chunk_cache_entries(
                    normalized_sentence,
                    provider,
                    model,
                    prompt_version
                );

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

}
