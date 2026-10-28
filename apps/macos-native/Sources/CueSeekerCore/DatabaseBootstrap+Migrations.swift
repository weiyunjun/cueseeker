import Foundation

extension DatabaseBootstrap {
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

    /// Schema 48 rewrites every FTS row so its rowid encodes the subtitle file
    /// and the cue group's time position inside that file. Search reads hit
    /// rowids alone and orders them by file display rank, which keeps the first
    /// page cheap no matter in which order files were indexed.
    static func migrateSchema47To48(on database: SQLiteDatabase) throws {
        try database.withImmediateTransaction {
            let hasSearchTables = try !columnNames(of: "subtitle_cue_groups_fts", in: database).isEmpty
                && !columnNames(of: "subtitle_cue_groups", in: database).isEmpty
            if hasSearchTables {
                try SearchFTSRows.rebuild(on: database)
            }
            try database.execute("PRAGMA user_version = 48;")
        }
    }

    /// Schema 49 stores the settled language of every cue line. Search, cue
    /// content and the facet counts read it instead of deriving a language from
    /// detections and cue group languages at query time.
    static func migrateSchema48To49(on database: SQLiteDatabase) throws {
        try database.withImmediateTransaction {
            try database.execute(cueLineLanguagesTableSQL)
            let hasSearchTables = try !columnNames(of: "subtitle_cue_lines", in: database).isEmpty
                && !columnNames(of: "subtitle_cue_groups", in: database).isEmpty
            if hasSearchTables {
                try CueLineLanguages.rebuild(on: database)
                let indexedContent = try database.prepare(
                    "SELECT 1 FROM sqlite_schema WHERE type = 'table' AND name = 'subtitle_video_matches';"
                )
                if try indexedContent.step() {
                    try CueFacetCountCache.rebuildAll(on: database)
                }
            }
            try database.execute("PRAGMA user_version = 49;")
        }
    }

    /// Schema 50 counts the cues of every folder for the Filter dialog's
    /// Folder group; a library indexed before it has no folder counts yet.
    static func migrateSchema49To50(on database: SQLiteDatabase) throws {
        try database.withImmediateTransaction {
            let indexedContent = try database.prepare(
                "SELECT 1 FROM sqlite_schema WHERE type = 'table' AND name = 'subtitle_video_matches';"
            )
            if try indexedContent.step() {
                try CueFacetCountCache.rebuildAll(on: database)
            }
            try database.execute("PRAGMA user_version = 50;")
        }
    }

    /// Schema 51 records each video's audio tracks and keeps its default
    /// audio track. A video indexed before it has no track list, which the
    /// next Index reads as missing data and fills in.
    static func migrateSchema50To51(on database: SQLiteDatabase) throws {
        try database.withImmediateTransaction {
            let columns = try columnNames(of: "video_files", in: database)
            if !columns.isEmpty, !columns.contains("audio_tracks") {
                try database.execute("ALTER TABLE video_files ADD COLUMN audio_tracks TEXT;")
            }
            if !columns.isEmpty, !columns.contains("default_audio_track_index") {
                try database.execute(
                    "ALTER TABLE video_files ADD COLUMN default_audio_track_index INTEGER NOT NULL DEFAULT 0;"
                )
            }
            try database.execute("PRAGMA user_version = 51;")
        }
    }

    /// Schema 52 keeps each video's default subtitle. A video without one
    /// opens on its first subtitle.
    static func migrateSchema51To52(on database: SQLiteDatabase) throws {
        try database.withImmediateTransaction {
            let columns = try columnNames(of: "video_files", in: database)
            if !columns.isEmpty, !columns.contains("default_subtitle_file_id") {
                try database.execute("ALTER TABLE video_files ADD COLUMN default_subtitle_file_id INTEGER;")
            }
            try database.execute("PRAGMA user_version = 52;")
        }
    }

    /// Schema 54 keeps each video's Display Title on the video, named when
    /// Index publishes its core data instead of when it rebuilds the Library
    /// rows. The titles are named once here, and Search, Excerpt and the
    /// Library rows take them, including in a library whose Library rows still
    /// wait for a rebuild. Schema 53 only brought the search titles in line
    /// with the Library's, which this does too, so a schema 52 database comes
    /// straight here.
    static func migrateSchema53To54(on database: SQLiteDatabase) throws {
        try database.withImmediateTransaction {
            let videoColumns = try columnNames(of: "video_files", in: database)
            if !videoColumns.isEmpty, !videoColumns.contains("display_title") {
                try database.execute("ALTER TABLE video_files ADD COLUMN display_title TEXT;")
            }
            let readColumns: [String: Set<String>] = [
                "subtitle_files": ["id", "subtitle_path", "format"],
                "subtitle_video_matches": ["subtitle_file_id", "video_file_id", "is_active"],
                "video_files": ["id", "path", "video_name", "duration", "display_title"],
                "subtitle_search_order_rows": ["subtitle_file_id", "display_title"],
                "library_video_rows": ["video_path", "display_title"]
            ]
            let hasTitleTables = try readColumns.allSatisfy { table, columns in
                try columnNames(of: table, in: database).isSuperset(of: columns)
            }
            if hasTitleTables {
                try LibraryDatabase(sharing: database).refreshVideoDisplayTitles(inFolderPaths: nil)
                try SubtitleDisplayTitleResolver.refreshSearchOrderDisplayTitles(on: database)
                try database.execute(
                    """
                    UPDATE library_video_rows
                    SET display_title = (
                        SELECT vf.display_title
                        FROM video_files vf
                        WHERE vf.path = library_video_rows.video_path
                    )
                    WHERE EXISTS (
                        SELECT 1
                        FROM video_files vf
                        WHERE vf.path = library_video_rows.video_path
                          AND vf.display_title IS NOT NULL
                    );
                    """
                )
            }
            try database.execute("PRAGMA user_version = 54;")
        }
    }

    /// Schema 55 stores each cue line's FTS group rowid and settled language
    /// bitmask directly on `subtitle_cue_lines` and indexes them in a covering
    /// index so cold search reads all line fields and languages in one sequential
    /// index scan without touching `subtitle_cue_groups_fts_content`,
    /// `subtitle_cue_groups`, `subtitle_cue_line_languages`, or non-search columns.
    static func migrateSchema54To55(on database: SQLiteDatabase) throws {
        try database.withImmediateTransaction {
            let lineColumns = try columnNames(of: "subtitle_cue_lines", in: database)
            if !lineColumns.isEmpty {
                if !lineColumns.contains("fts_rowid") {
                    try database.execute(
                        "ALTER TABLE subtitle_cue_lines ADD COLUMN fts_rowid INTEGER NOT NULL DEFAULT 0;"
                    )
                }
                if !lineColumns.contains("language_mask") {
                    try database.execute(
                        "ALTER TABLE subtitle_cue_lines ADD COLUMN language_mask INTEGER NOT NULL DEFAULT 0;"
                    )
                }
                let updatedLineColumns = try columnNames(of: "subtitle_cue_lines", in: database)
                let requiredLineColumns: Set<String> = [
                    "id", "cue_group_id", "fts_rowid", "language_mask",
                    "display_order", "event_index", "start_ms", "end_ms", "content"
                ]
                let groupColumns = try columnNames(of: "subtitle_cue_groups", in: database)
                let langColumns = try columnNames(of: "subtitle_cue_line_languages", in: database)
                if updatedLineColumns.isSuperset(of: requiredLineColumns),
                   groupColumns.isSuperset(of: ["id", "subtitle_file_id", "start_ms", "end_ms"]),
                   langColumns.isSuperset(of: ["cue_id", "language_code"])
                {
                    try database.execute(
                        """
                        WITH group_fts AS (
                            SELECT id AS cue_group_id,
                                   (subtitle_file_id << 24) | ROW_NUMBER() OVER (
                                       PARTITION BY subtitle_file_id
                                       ORDER BY start_ms ASC, end_ms ASC, id ASC
                                   ) AS fts_rowid
                            FROM subtitle_cue_groups
                        ),
                        line_langs AS (
                            SELECT cue_id,
                                   SUM(
                                       CASE language_code
                                           WHEN 'en' THEN 1
                                           WHEN 'ja' THEN 2
                                           WHEN 'zh' THEN 4
                                           WHEN 'zh-Hans' THEN 8
                                           WHEN 'zh-Hant' THEN 16
                                           WHEN 'unknown' THEN 32
                                           ELSE 0
                                       END
                                   ) AS mask
                            FROM subtitle_cue_line_languages
                            GROUP BY cue_id
                        )
                        UPDATE subtitle_cue_lines
                        SET fts_rowid = COALESCE(
                                (SELECT g.fts_rowid FROM group_fts g WHERE g.cue_group_id = subtitle_cue_lines.cue_group_id),
                                0
                            ),
                            language_mask = COALESCE(
                                (SELECT ll.mask FROM line_langs ll WHERE ll.cue_id = subtitle_cue_lines.id),
                                32
                            );

                        CREATE INDEX IF NOT EXISTS idx_subtitle_cue_lines_fts_covering
                            ON subtitle_cue_lines(fts_rowid, display_order, event_index, id, cue_group_id, start_ms, end_ms, language_mask, content);
                        """
                    )
                }
            }
            try database.execute("PRAGMA user_version = 55;")
        }
    }

    /// Schema 56 recalculates the cached `Characters` facet counts using
    /// trimmed Unicode East Asian Width (`W`/`F` = 2, others = 1).
    static func migrateSchema55To56(on database: SQLiteDatabase) throws {
        try database.withImmediateTransaction {
            let indexedContent = try database.prepare(
                "SELECT 1 FROM sqlite_schema WHERE type = 'table' AND name = 'subtitle_video_matches';"
            )
            if try indexedContent.step() {
                try CueFacetCountCache.rebuildAll(on: database)
            }
            try database.execute("PRAGMA user_version = 56;")
        }
    }

    /// Schema 57 adds `video_tombstones` so a video that leaves active matching
    /// keeps its playback progress, watch state, manual cover, and default audio
    /// track for same-path recovery.
    static func migrateSchema56To57(on database: SQLiteDatabase) throws {
        try database.withImmediateTransaction {
            try database.execute(
                """
                \(videoTombstonesTableSQL)
                PRAGMA user_version = 57;
                """
            )
        }
    }

    static func ensureCueLinePrecomputedAttributeColumns(on database: SQLiteDatabase) throws {
        let lineColumns = try columnNames(of: "subtitle_cue_lines", in: database)
        guard !lineColumns.isEmpty else {
            return
        }
        if !lineColumns.contains("duration_ms") {
            try database.execute(
                "ALTER TABLE subtitle_cue_lines ADD COLUMN duration_ms INTEGER NOT NULL DEFAULT 0;"
            )
        }
        if !lineColumns.contains("character_width") {
            try database.execute(
                "ALTER TABLE subtitle_cue_lines ADD COLUMN character_width INTEGER NOT NULL DEFAULT 0;"
            )
        }
    }

    /// Schema 58 precomputes and persists each cue's duration (`duration_ms`) and
    /// trimmed East Asian character width (`character_width`) on `subtitle_cue_lines`
    /// and `cue_tombstones`, includes both in `idx_subtitle_cue_lines_fts_covering`,
    /// and rebuilds the cached facet counts from those columns.
    static func migrateSchema57To58(on database: SQLiteDatabase) throws {
        try database.withImmediateTransaction {
            try ensureCueLinePrecomputedAttributeColumns(on: database)
            let lineColumns = try columnNames(of: "subtitle_cue_lines", in: database)
            if lineColumns.isSuperset(of: ["start_ms", "end_ms", "content", "duration_ms", "character_width"]) {
                try database.execute(
                    """
                    UPDATE subtitle_cue_lines
                    SET duration_ms = MAX(0, end_ms - start_ms),
                        character_width = cue_character_width(content);
                    """
                )
            }
            let coveringColumns: Set<String> = [
                "fts_rowid", "display_order", "event_index", "id", "cue_group_id",
                "start_ms", "end_ms", "duration_ms", "character_width", "language_mask", "content"
            ]
            if lineColumns.isSuperset(of: coveringColumns) {
                try database.execute(
                    """
                    DROP INDEX IF EXISTS idx_subtitle_cue_lines_fts_covering;
                    CREATE TABLE _migration_freelist_hold (b BLOB);
                    INSERT INTO _migration_freelist_hold(b)
                    SELECT zeroblob(freelist_count * 4096)
                    FROM pragma_freelist_count()
                    WHERE freelist_count > 0;
                    CREATE INDEX IF NOT EXISTS idx_subtitle_cue_lines_fts_covering
                        ON subtitle_cue_lines(fts_rowid, display_order, event_index, id, cue_group_id, start_ms, end_ms, duration_ms, character_width, language_mask, content);
                    DROP TABLE _migration_freelist_hold;
                    """
                )
            }

            let tombstoneColumns = try columnNames(of: "cue_tombstones", in: database)
            if !tombstoneColumns.isEmpty {
                if !tombstoneColumns.contains("duration_ms") {
                    try database.execute(
                        "ALTER TABLE cue_tombstones ADD COLUMN duration_ms INTEGER NOT NULL DEFAULT 0;"
                    )
                }
                if !tombstoneColumns.contains("character_width") {
                    try database.execute(
                        "ALTER TABLE cue_tombstones ADD COLUMN character_width INTEGER NOT NULL DEFAULT 0;"
                    )
                }
                let updatedTombstoneColumns = try columnNames(of: "cue_tombstones", in: database)
                if updatedTombstoneColumns.isSuperset(of: ["start_ms", "end_ms", "content", "duration_ms", "character_width"]) {
                    try database.execute(
                        """
                        UPDATE cue_tombstones
                        SET duration_ms = MAX(0, end_ms - start_ms),
                            character_width = cue_character_width(content);
                        """
                    )
                }
            }

            let indexedContent = try database.prepare(
                "SELECT 1 FROM sqlite_schema WHERE type = 'table' AND name = 'subtitle_video_matches';"
            )
            if try indexedContent.step(), !lineColumns.isEmpty {
                try CueFacetCountCache.rebuildAll(on: database)
            }
            try database.execute("PRAGMA user_version = 58;")
        }
    }

    /// Schema 59 removes the legacy `ass_render_segments` table and its lookup
    /// index because ASS playback loads the full subtitle script directly with
    /// bounded libass caches instead of storing segmented script copies in SQLite.
    static func migrateSchema58To59(on database: SQLiteDatabase) throws {
        try database.withImmediateTransaction {
            try database.execute(
                """
                DROP INDEX IF EXISTS idx_ass_render_segments_lookup;
                DROP TABLE IF EXISTS ass_render_segments;
                PRAGMA user_version = 59;
                """
            )
        }
    }

    /// Schema 60 stores raw uncleaned cue count on `subtitle_files` and video
    /// bit depth and pixel format on `video_files`, marking existing videos to
    /// refresh their probed metadata on the next Index.
    static func migrateSchema59To60(on database: SQLiteDatabase) throws {
        try database.withImmediateTransaction {
            let subtitleColumns = try columnNames(of: "subtitle_files", in: database)
            if !subtitleColumns.isEmpty, !subtitleColumns.contains("raw_cue_count") {
                try database.execute("ALTER TABLE subtitle_files ADD COLUMN raw_cue_count INTEGER;")
            }
            let videoColumns = try columnNames(of: "video_files", in: database)
            if !videoColumns.isEmpty {
                if !videoColumns.contains("video_bit_depth") {
                    try database.execute("ALTER TABLE video_files ADD COLUMN video_bit_depth INTEGER;")
                }
                if !videoColumns.contains("video_pixel_format") {
                    try database.execute("ALTER TABLE video_files ADD COLUMN video_pixel_format TEXT;")
                }
                if videoColumns.contains("duration_retry_pending") {
                    try database.execute("UPDATE video_files SET duration_retry_pending = 1;")
                }
            }
            try database.execute("PRAGMA user_version = 60;")
        }
    }

    /// Schema 61 records when a task began running (`started_at`) so the Task
    /// Detail dialog can show the start timestamp alongside creation and
    /// completion/termination timestamps.
    static func migrateSchema60To61(on database: SQLiteDatabase) throws {
        try database.withImmediateTransaction {
            let columns = try columnNames(of: "task_records", in: database)
            if !columns.isEmpty, !columns.contains("started_at") {
                try database.execute("ALTER TABLE task_records ADD COLUMN started_at TEXT;")
            }
            try database.execute("PRAGMA user_version = 61;")
        }
    }

    /// Schema 62 stores added/updated timestamps for root folders (`library_root_folders`)
    /// and Level 2 subfolders (`library_folders.created_at` and `updated_at`) for
    /// the Folder Detail dialog, backfilling existing rows from `search_paths` and
    /// `subtitle_files`.
    static func migrateSchema61To62(on database: SQLiteDatabase) throws {
        try database.withImmediateTransaction {
            try database.execute(
                """
                CREATE TABLE IF NOT EXISTS library_root_folders (
                    path TEXT PRIMARY KEY,
                    created_at TEXT NOT NULL,
                    updated_at TEXT NOT NULL
                );
                """
            )
            let searchPathColumns = try columnNames(of: "search_paths", in: database)
            if searchPathColumns.isSuperset(of: ["path", "created_at", "updated_at"]) {
                let updatedExpr = searchPathColumns.contains("last_successful_index_at")
                    ? "COALESCE(NULLIF(last_successful_index_at, ''), NULLIF(updated_at, ''), created_at)"
                    : "COALESCE(NULLIF(updated_at, ''), created_at)"
                try database.execute(
                    """
                    INSERT OR IGNORE INTO library_root_folders(path, created_at, updated_at)
                    SELECT path,
                           created_at,
                           \(updatedExpr)
                    FROM search_paths;
                    """
                )
            }
            let folderColumns = try columnNames(of: "library_folders", in: database)
            if !folderColumns.isEmpty {
                if !folderColumns.contains("created_at") {
                    try database.execute(
                        "ALTER TABLE library_folders ADD COLUMN created_at TEXT NOT NULL DEFAULT '';"
                    )
                }
                if !folderColumns.contains("updated_at") {
                    try database.execute(
                        "ALTER TABLE library_folders ADD COLUMN updated_at TEXT NOT NULL DEFAULT '';"
                    )
                }
                let subtitleColumns = try columnNames(of: "subtitle_files", in: database)
                if subtitleColumns.isSuperset(of: ["folder_id", "indexed_at"]),
                   searchPathColumns.isSuperset(of: ["id", "created_at", "updated_at"])
                {
                    let spUpdatedExpr = searchPathColumns.contains("last_successful_index_at")
                        ? "COALESCE(NULLIF(sp.last_successful_index_at, ''), NULLIF(sp.updated_at, ''), sp.created_at)"
                        : "COALESCE(NULLIF(sp.updated_at, ''), sp.created_at)"
                    try database.execute(
                        """
                        UPDATE library_folders
                        SET created_at = COALESCE(
                                (
                                    SELECT MIN(sf.indexed_at)
                                    FROM subtitle_files sf
                                    WHERE sf.folder_id = library_folders.id AND sf.indexed_at != ''
                                ),
                                (
                                    SELECT sp.created_at
                                    FROM search_paths sp
                                    WHERE sp.id = library_folders.library_id
                                ),
                                ''
                            ),
                            updated_at = COALESCE(
                                (
                                    SELECT \(spUpdatedExpr)
                                    FROM search_paths sp
                                    WHERE sp.id = library_folders.library_id
                                ),
                                (
                                    SELECT MAX(sf.indexed_at)
                                    FROM subtitle_files sf
                                    WHERE sf.folder_id = library_folders.id AND sf.indexed_at != ''
                                ),
                                ''
                            )
                        WHERE created_at = '' OR updated_at = '';
                        """
                    )
                }
            }
            try database.execute("PRAGMA user_version = 62;")
        }
    }

    /// Schema 63 compacts existing databases once on upgrade to reclaim freelist
    /// pages and restore physical page contiguity across all tables and search
    /// indexes after historical full-library rewrites.
    static func migrateSchema62To63(on database: SQLiteDatabase) throws {
        try database.execute("PRAGMA wal_checkpoint(TRUNCATE);")
        try database.execute("VACUUM;")
        try database.execute("PRAGMA user_version = 63;")
        try database.execute("PRAGMA wal_checkpoint(TRUNCATE);")
    }

    /// Schema 64 stores the probed container format extension on `video_files`
    /// for the File Detail dialog, marking existing videos to refresh their
    /// probed metadata on the next Index.
    static func migrateSchema63To64(on database: SQLiteDatabase) throws {
        try database.withImmediateTransaction {
            let videoColumns = try columnNames(of: "video_files", in: database)
            if !videoColumns.isEmpty {
                if !videoColumns.contains("container_format") {
                    try database.execute("ALTER TABLE video_files ADD COLUMN container_format TEXT;")
                }
                if videoColumns.contains("duration_retry_pending") {
                    try database.execute("UPDATE video_files SET duration_retry_pending = 1;")
                }
            }
            try database.execute("PRAGMA user_version = 64;")
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
