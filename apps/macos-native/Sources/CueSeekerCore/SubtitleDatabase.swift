import Foundation

public struct SubtitleDatabaseEntry: Equatable, Sendable {
    public let id: Int64
    public let subtitlePath: String
    public let subtitleFormat: SubtitleFormat
    public let videoPath: String
    public let videoName: String
    public let sequenceNumber: Int?
    public let startTimecode: String
    public let endTimecode: String
    public let startMilliseconds: Int
    public let endMilliseconds: Int
    public let content: String
}

public struct SubtitleSearchResult: Equatable, Sendable {
    public let entryID: Int64
    public let subtitlePath: String
    public let subtitleFormat: SubtitleFormat
    public let videoPath: String
    public let videoName: String
    public let startMilliseconds: Int
    public let endMilliseconds: Int
    public let content: String
    public let cueLines: [String]
    public var searchRank: Int = 0
}

public struct SubtitleSearchFileSummary: Equatable, Sendable {
    public let subtitlePath: String
    public let subtitleFileName: String
    public let subtitleDisplayTitle: String
    public let matchCount: Int
}

public struct LibraryVideo: Equatable, Sendable, Identifiable {
    public let videoPath: String
    public let videoName: String
    public let duration: Double?
    public let subtitlePath: String
    public let subtitleFormat: SubtitleFormat

    public var id: String {
        videoPath
    }
}

public struct LibraryVideoPresentation: Equatable, Sendable, Identifiable {
    public let videoPath: String
    public let videoName: String
    public let duration: Double?
    public let subtitlePath: String
    public let subtitleFormat: SubtitleFormat
    public let displayTitle: String
    public let fileExtension: String

    public var id: String {
        videoPath
    }

    public var libraryVideo: LibraryVideo {
        LibraryVideo(
            videoPath: videoPath,
            videoName: videoName,
            duration: duration,
            subtitlePath: subtitlePath,
            subtitleFormat: subtitleFormat
        )
    }
}

public struct LibraryFolderPresentation: Equatable, Sendable, Identifiable {
    public let folderPath: String
    public let folderTitle: String
    public let videos: [LibraryVideoPresentation]

    public var id: String {
        folderPath
    }
}

public struct LibraryPlaybackHistory: Equatable, Sendable {
    public let videoPath: String
    public let positionMilliseconds: Int
    public let duration: Double?
    public let updatedAt: String
}

public struct Shiori: Equatable, Sendable, Identifiable {
    public let id: Int64
    public let subtitlePath: String
    public let subtitleFormat: SubtitleFormat
    public let videoPath: String
    public let videoName: String
    public let startMilliseconds: Int
    public let endMilliseconds: Int
    public let content: String
    public let isValid: Bool
    public let createdAt: String

    public var cueLines: [String] {
        content
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

public struct SubtitleSearchPage: Equatable, Sendable {
    public let results: [SubtitleSearchResult]
    public let totalCount: Int
    public let fileSummaries: [SubtitleSearchFileSummary]
}

public struct SearchNavigationAnchor: Equatable, Sendable {
    public let selectedEntryID: Int64?
    public let videoPath: String?
    public let subtitlePath: String?
    public let currentMilliseconds: Int

    public init(
        selectedEntryID: Int64?,
        videoPath: String?,
        subtitlePath: String?,
        currentMilliseconds: Int
    ) {
        self.selectedEntryID = selectedEntryID
        self.videoPath = videoPath
        self.subtitlePath = subtitlePath
        self.currentMilliseconds = max(0, currentMilliseconds)
    }
}

public struct SearchNavigationSnapshot: Equatable, Sendable {
    public let totalCount: Int
    public let currentIndex: Int?
    public let neighborhood: [SubtitleSearchResult]
    public let previous: SubtitleSearchResult?
    public let current: SubtitleSearchResult?
    public let next: SubtitleSearchResult?

    public var currentPosition: Int? {
        currentIndex.map { $0 + 1 }
    }
}

public struct SubtitleCueTiming: Equatable, Sendable {
    public let startMilliseconds: Int
    public let endMilliseconds: Int

    public init(startMilliseconds: Int, endMilliseconds: Int) {
        self.startMilliseconds = startMilliseconds
        self.endMilliseconds = endMilliseconds
    }
}

public struct SubtitleCueTextSelection: Equatable, Sendable {
    public let cueGroupID: Int64
    public let startMilliseconds: Int
    public let endMilliseconds: Int
    public let lines: [String]

    public var text: String {
        lines.joined(separator: "\n")
    }

    public init(
        cueGroupID: Int64,
        startMilliseconds: Int,
        endMilliseconds: Int,
        lines: [String]
    ) {
        self.cueGroupID = cueGroupID
        self.startMilliseconds = startMilliseconds
        self.endMilliseconds = endMilliseconds
        self.lines = lines
    }
}

public struct SubtitleFileMetadata: Equatable, Sendable {
    public let subtitlePath: String
    public let subtitleFormat: SubtitleFormat
    public let videoPath: String?
    public let videoName: String?
    public let fileSize: Int64?
    public let modifiedAt: Date?
    public let indexedAt: String
}

public struct ASSRenderSegment: Equatable, Sendable {
    public let subtitlePath: String
    public let startMilliseconds: Int
    public let endMilliseconds: Int
    public let scriptText: String
    public let eventCount: Int
    public let byteCount: Int
}

public enum ASSFontResourceStatus: String, Equatable, Sendable {
    case readyWithFonts
    case readyWithoutFonts
    case failed
}

public struct ASSFontResourceManifest: Equatable, Sendable {
    public let subtitlePath: String
    public let videoPath: String
    public let status: ASSFontResourceStatus
    public let fontsDirectoryPath: String?
    public let resourceSignature: String
    public let errorMessage: String?
    public let preparedAt: String
}

public final class SubtitleDatabase: @unchecked Sendable {
    public static let currentSchemaVersion: Int = 11
    public static let configuredBusyTimeoutMilliseconds: Int = 5_000
    public static let configuredCacheSizeKibibytes: Int = SQLiteDatabase.cacheSizeKibibytes
    public static let configuredMmapSizeBytes: Int = SQLiteDatabase.mmapSizeBytes

    private let database: SQLiteDatabase

    public init(path: URL) throws {
        database = try SQLiteDatabase(path: path)
    }

    public func migrate() throws {
        let previousVersion = try schemaVersion()

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

        if previousVersion < 3 {
            try dropDerivedSubtitleIndexTables()
        }

        try database.execute(
            """
            CREATE TABLE IF NOT EXISTS subtitle_files (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                subtitle_path TEXT NOT NULL UNIQUE,
                format TEXT NOT NULL,
                file_size INTEGER,
                modified_at REAL,
                indexed_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS video_files (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                path TEXT NOT NULL UNIQUE,
                video_name TEXT NOT NULL,
                file_size INTEGER,
                modified_at REAL,
                duration REAL,
                video_codec TEXT,
                audio_codec TEXT,
                native_video_candidate INTEGER,
                native_audio_candidate INTEGER,
                native_compatibility_reason TEXT,
                native_failure_reason TEXT,
                compatibility_evaluated_at TEXT
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
                search_content TEXT NOT NULL,
                line_count INTEGER NOT NULL DEFAULT 1,
                FOREIGN KEY(subtitle_file_id) REFERENCES subtitle_files(id) ON DELETE CASCADE
            );

            CREATE TABLE IF NOT EXISTS subtitle_cue_lines (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
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
                FOREIGN KEY(cue_group_id) REFERENCES subtitle_cue_groups(id) ON DELETE CASCADE
            );

            CREATE INDEX IF NOT EXISTS idx_subtitle_files_subtitle_path
                ON subtitle_files(subtitle_path);

            CREATE INDEX IF NOT EXISTS idx_subtitle_cue_groups_subtitle_path
                ON subtitle_cue_groups(subtitle_path);

            CREATE INDEX IF NOT EXISTS idx_subtitle_cue_groups_start_ms
                ON subtitle_cue_groups(start_ms);

            CREATE INDEX IF NOT EXISTS idx_subtitle_cue_lines_group_order
                ON subtitle_cue_lines(cue_group_id, display_order, event_index);

            CREATE VIRTUAL TABLE IF NOT EXISTS subtitle_cue_groups_fts USING fts5(
                content,
                cue_group_id UNINDEXED
            );

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
                position_ms INTEGER NOT NULL,
                duration REAL,
                updated_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS library_video_rows (
                video_path TEXT PRIMARY KEY,
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
                updated_at TEXT NOT NULL
            );

            CREATE INDEX IF NOT EXISTS idx_library_video_rows_scope
                ON library_video_rows(subtitle_path);

            CREATE INDEX IF NOT EXISTS idx_library_video_rows_order
                ON library_video_rows(folder_order, video_order);

            CREATE TABLE IF NOT EXISTS shioris (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                subtitle_path TEXT NOT NULL,
                subtitle_format TEXT NOT NULL,
                start_ms INTEGER NOT NULL,
                end_ms INTEGER NOT NULL,
                video_path TEXT NOT NULL,
                video_name TEXT NOT NULL,
                content TEXT NOT NULL,
                is_valid INTEGER NOT NULL DEFAULT 1,
                created_at TEXT NOT NULL,
                UNIQUE(subtitle_path, start_ms, end_ms)
            );

            CREATE INDEX IF NOT EXISTS idx_shioris_subtitle_path
                ON shioris(subtitle_path);

            CREATE INDEX IF NOT EXISTS idx_shioris_order
                ON shioris(subtitle_path, start_ms, end_ms);
            """
        )

        if previousVersion >= 4 && previousVersion < 5 {
            try database.execute(
                """
                ALTER TABLE ass_render_segments
                ADD COLUMN algorithm_version INTEGER NOT NULL DEFAULT 0;
                """
            )
        }

        if previousVersion < 6 {
            try rebuildFTSRows()
        }

        if previousVersion < 9 {
            try rebuildLibraryPresentationSnapshot()
        }

        if previousVersion >= 3 && previousVersion < 11,
           try !columnExists(table: "subtitle_cue_groups", column: "line_count") {
            try database.execute(
                """
                ALTER TABLE subtitle_cue_groups
                ADD COLUMN line_count INTEGER NOT NULL DEFAULT 1;
                """
            )
            try database.execute(
                """
                UPDATE subtitle_cue_groups
                SET line_count = MAX(1, (
                    SELECT COUNT(*) FROM subtitle_cue_lines
                    WHERE cue_group_id = subtitle_cue_groups.id
                ));
                """
            )
        }

        try database.execute("PRAGMA user_version = \(Self.currentSchemaVersion);")
    }

    private func columnExists(table: String, column: String) throws -> Bool {
        let statement = try database.prepare("PRAGMA table_info(\(table));")
        while try statement.step() {
            if statement.stringColumn(1) == column {
                return true
            }
        }
        return false
    }

    public func schemaVersion() throws -> Int {
        let statement = try database.prepare("PRAGMA user_version")
        guard try statement.step() else {
            return 0
        }

        return statement.intColumn(0)
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

    @discardableResult
    public func addSearchPath(_ folder: URL, type: String = "local") throws -> Int64 {
        let now = ISO8601DateFormatter().string(from: Date())
        let statement = try database.prepare(
            """
            INSERT INTO search_paths(type, path, created_at, updated_at)
            VALUES (?, ?, ?, ?)
            ON CONFLICT(path) DO UPDATE SET
                type = excluded.type,
                updated_at = excluded.updated_at
            RETURNING id;
            """
        )

        try statement.bind(type, at: 1)
        try statement.bind(folder.path, at: 2)
        try statement.bind(now, at: 3)
        try statement.bind(now, at: 4)

        guard try statement.step() else {
            return database.lastInsertRowID()
        }

        return statement.int64Column(0)
    }

    public func replaceEntries(
        subtitleFile: URL,
        videoFile: URL,
        entries: [SubtitleEntry],
        fileSize: Int64? = nil,
        modifiedAt: Date? = nil
    ) throws {
        try replaceCueGroups(
            subtitleFile: subtitleFile,
            videoFile: videoFile,
            format: .srt,
            cueGroups: entries.enumerated().map { index, entry in
                entry.cueGroup(eventIndex: index)
            },
            fileSize: fileSize,
            modifiedAt: modifiedAt
        )
    }

    public func replaceCueGroups(
        subtitleFile: URL,
        videoFile: URL,
        format: SubtitleFormat,
        cueGroups: [SubtitleCueGroup],
        assRenderSegments: [ASSRenderSegmentPayload] = [],
        fileSize: Int64? = nil,
        modifiedAt: Date? = nil
    ) throws {
        try database.execute("BEGIN IMMEDIATE TRANSACTION")

        do {
            try deleteIndexedSubtitlePath(subtitleFile.path)

            let subtitleFileID = try upsertSubtitleFile(
                subtitleFile: subtitleFile,
                format: format,
                fileSize: fileSize,
                modifiedAt: modifiedAt
            )
            let videoFileID = try upsertVideoFile(videoFile)
            try upsertSubtitleVideoMatch(subtitleFileID: subtitleFileID, videoFileID: videoFileID)

            for segment in assRenderSegments {
                try insertASSRenderSegment(subtitleFileID: subtitleFileID, segment: segment)
            }

            for group in cueGroups {
                let cueGroupID = try insertCueGroup(
                    subtitleFileID: subtitleFileID,
                    subtitleFile: subtitleFile,
                    group: group
                )
                for line in group.cueLines {
                    try insertCueLine(cueGroupID: cueGroupID, line: line)
                }
                try insertFTSRow(cueGroupID: cueGroupID, content: group.searchContent)
            }

            try deleteOrphanedVideoFiles()
            try database.execute("COMMIT")
        } catch {
            try? database.execute("ROLLBACK")
            throw error
        }
    }

    public func entries(forSubtitleFile subtitleFile: URL) throws -> [SubtitleDatabaseEntry] {
        let statement = try database.prepare(
            """
            SELECT g.id, sf.subtitle_path, sf.format, vf.path, vf.video_name,
                   g.seq, g.start_time, g.end_time, g.start_ms, g.end_ms, g.search_content
            FROM subtitle_cue_groups g
            JOIN subtitle_files sf ON sf.id = g.subtitle_file_id
            JOIN subtitle_video_matches m ON m.subtitle_file_id = sf.id AND m.is_active = 1
            JOIN video_files vf ON vf.id = m.video_file_id
            WHERE sf.subtitle_path = ?
            ORDER BY g.start_ms ASC, g.id ASC;
            """
        )

        try statement.bind(subtitleFile.path, at: 1)

        var entries: [SubtitleDatabaseEntry] = []
        while try statement.step() {
            entries.append(entry(from: statement))
        }

        return entries
    }

    public func cueTimings(
        forSubtitleFile subtitleFile: URL,
        startingAtMilliseconds startMilliseconds: Int,
        limit: Int
    ) throws -> [SubtitleCueTiming] {
        let limit = min(max(0, limit), 100)
        guard limit > 0 else {
            return []
        }

        let statement = try database.prepare(
            """
            SELECT g.start_ms, g.end_ms
            FROM subtitle_cue_groups g
            JOIN subtitle_files sf ON sf.id = g.subtitle_file_id
            WHERE sf.subtitle_path = ?
              AND g.start_ms >= ?
            ORDER BY g.start_ms ASC, g.id ASC
            LIMIT ?;
            """
        )

        try statement.bind(subtitleFile.path, at: 1)
        try statement.bind(max(0, startMilliseconds), at: 2)
        try statement.bind(limit, at: 3)

        var timings: [SubtitleCueTiming] = []
        while try statement.step() {
            timings.append(
                SubtitleCueTiming(
                    startMilliseconds: statement.intColumn(0),
                    endMilliseconds: statement.intColumn(1)
                )
            )
        }

        return timings
    }

    public func cueTextSelection(
        forSubtitleFile subtitleFile: URL,
        atMilliseconds milliseconds: Int
    ) throws -> SubtitleCueTextSelection? {
        let timestamp = max(0, milliseconds)
        guard let group = try activeCueGroupSelection(
            forSubtitleFile: subtitleFile,
            atMilliseconds: timestamp
        ) ?? previousCueGroupSelection(
            forSubtitleFile: subtitleFile,
            beforeOrAtMilliseconds: timestamp
        ) else {
            return nil
        }

        let lineContents = try cueLines(forCueGroupID: group.cueGroupID)
            .map(\.content)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let fallbackLines = group.searchContent
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return SubtitleCueTextSelection(
            cueGroupID: group.cueGroupID,
            startMilliseconds: group.startMilliseconds,
            endMilliseconds: group.endMilliseconds,
            lines: lineContents.isEmpty ? fallbackLines : lineContents
        )
    }

    public func hasASSRenderSegments(forSubtitleFile subtitleFile: URL) throws -> Bool {
        let statement = try database.prepare(
            """
            SELECT 1
            FROM ass_render_segments s
            JOIN subtitle_files sf ON sf.id = s.subtitle_file_id
            WHERE sf.subtitle_path = ?
              AND s.algorithm_version = ?
            LIMIT 1;
            """
        )

        try statement.bind(subtitleFile.path, at: 1)
        try statement.bind(ASSRenderSegmenter.cacheAlgorithmVersion, at: 2)
        return try statement.step()
    }

    public func assRenderSegment(
        forSubtitleFile subtitleFile: URL,
        atMilliseconds milliseconds: Int
    ) throws -> ASSRenderSegment? {
        let timestamp = max(0, milliseconds)
        let statement = try database.prepare(
            """
            SELECT sf.subtitle_path, s.start_ms, s.end_ms, s.script_text,
                   s.event_count, s.byte_count
            FROM ass_render_segments s
            JOIN subtitle_files sf ON sf.id = s.subtitle_file_id
            WHERE sf.subtitle_path = ?
              AND s.algorithm_version = ?
              AND s.start_ms <= ?
              AND s.end_ms > ?
            ORDER BY s.start_ms DESC, s.segment_index DESC
            LIMIT 1;
            """
        )

        try statement.bind(subtitleFile.path, at: 1)
        try statement.bind(ASSRenderSegmenter.cacheAlgorithmVersion, at: 2)
        try statement.bind(timestamp, at: 3)
        try statement.bind(timestamp, at: 4)

        guard try statement.step() else {
            return nil
        }

        return ASSRenderSegment(
            subtitlePath: statement.stringColumn(0),
            startMilliseconds: statement.intColumn(1),
            endMilliseconds: statement.intColumn(2),
            scriptText: statement.stringColumn(3),
            eventCount: statement.intColumn(4),
            byteCount: statement.intColumn(5)
        )
    }

    public func assFontResourceManifest(
        forSubtitleFile subtitleFile: URL,
        videoFile: URL
    ) throws -> ASSFontResourceManifest? {
        let statement = try database.prepare(
            """
            SELECT sf.subtitle_path, vf.path, r.status, r.fonts_directory,
                   r.resource_signature, r.error_message, r.prepared_at
            FROM ass_font_resources r
            JOIN subtitle_files sf ON sf.id = r.subtitle_file_id
            JOIN video_files vf ON vf.id = r.video_file_id
            WHERE sf.subtitle_path = ? AND vf.path = ?;
            """
        )

        try statement.bind(subtitleFile.path, at: 1)
        try statement.bind(videoFile.path, at: 2)

        guard try statement.step() else {
            return nil
        }

        let status = ASSFontResourceStatus(rawValue: statement.stringColumn(2)) ?? .failed
        return ASSFontResourceManifest(
            subtitlePath: statement.stringColumn(0),
            videoPath: statement.stringColumn(1),
            status: status,
            fontsDirectoryPath: statement.nullableStringColumn(3),
            resourceSignature: statement.stringColumn(4),
            errorMessage: statement.nullableStringColumn(5),
            preparedAt: statement.stringColumn(6)
        )
    }

    public func upsertASSFontResourceManifest(
        subtitleFile: URL,
        videoFile: URL,
        status: ASSFontResourceStatus,
        fontsDirectory: URL?,
        resourceSignature: String,
        errorMessage: String? = nil
    ) throws {
        let subtitleFileID = try requireSubtitleFileID(for: subtitleFile)
        let videoFileID = try requireVideoFileID(for: videoFile)
        let statement = try database.prepare(
            """
            INSERT INTO ass_font_resources(
                subtitle_file_id,
                video_file_id,
                status,
                fonts_directory,
                resource_signature,
                error_message,
                prepared_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(subtitle_file_id) DO UPDATE SET
                video_file_id = excluded.video_file_id,
                status = excluded.status,
                fonts_directory = excluded.fonts_directory,
                resource_signature = excluded.resource_signature,
                error_message = excluded.error_message,
                prepared_at = excluded.prepared_at;
            """
        )

        try statement.bind(subtitleFileID, at: 1)
        try statement.bind(videoFileID, at: 2)
        try statement.bind(status.rawValue, at: 3)
        if let fontsDirectory {
            try statement.bind(fontsDirectory.path, at: 4)
        } else {
            try statement.bindNull(at: 4)
        }
        try statement.bind(resourceSignature, at: 5)
        if let errorMessage {
            try statement.bind(errorMessage, at: 6)
        } else {
            try statement.bindNull(at: 6)
        }
        try statement.bind(ISO8601DateFormatter().string(from: Date()), at: 7)
        try statement.run()
    }

    public func subtitleFiles() throws -> [SubtitleFileMetadata] {
        let statement = try database.prepare(
            """
            SELECT sf.subtitle_path, sf.format, vf.path, vf.video_name,
                   sf.file_size, sf.modified_at, sf.indexed_at
            FROM subtitle_files sf
            LEFT JOIN subtitle_video_matches m ON m.subtitle_file_id = sf.id AND m.is_active = 1
            LEFT JOIN video_files vf ON vf.id = m.video_file_id
            ORDER BY sf.subtitle_path ASC;
            """
        )

        var files: [SubtitleFileMetadata] = []
        while try statement.step() {
            files.append(
                SubtitleFileMetadata(
                    subtitlePath: statement.stringColumn(0),
                    subtitleFormat: SubtitleFormat(rawValue: statement.stringColumn(1)) ?? .srt,
                    videoPath: statement.nullableStringColumn(2),
                    videoName: statement.nullableStringColumn(3),
                    fileSize: statement.nullableInt64Column(4),
                    modifiedAt: statement.nullableDoubleColumn(5).map(Date.init(timeIntervalSince1970:)),
                    indexedAt: statement.stringColumn(6)
                )
            )
        }

        return files
    }

    public func reconcileIndexedContent(activeFolders folders: [URL]) throws {
        let folders = folders.map(\.standardizedFileURL)
        guard !folders.isEmpty else {
            try clearIndexedContent()
            return
        }

        try database.execute("BEGIN IMMEDIATE TRANSACTION")
        do {
            let inactiveSubtitlePaths = try indexedSubtitlePaths()
                .filter { !Self.path($0, isUnderAny: folders) }
            for subtitlePath in inactiveSubtitlePaths {
                try deleteIndexedSubtitlePath(subtitlePath)
            }

            let inactiveSearchPaths = try searchPaths()
                .filter { !Self.folderPath($0, matchesAny: folders) }
            for searchPath in inactiveSearchPaths {
                try deleteSearchPath(searchPath)
            }

            try deleteOrphanedVideoFiles()
            try database.execute("COMMIT")
        } catch {
            try? database.execute("ROLLBACK")
            throw error
        }
    }

    public func clearIndexedContent() throws {
        try database.execute("BEGIN IMMEDIATE TRANSACTION")
        do {
            try database.execute("DELETE FROM library_video_rows;")
            try database.execute("DELETE FROM subtitle_cue_groups_fts;")
            try database.execute("DELETE FROM ass_render_segments;")
            try database.execute("DELETE FROM subtitle_files;")
            try database.execute("DELETE FROM video_files;")
            try database.execute("DELETE FROM search_paths;")
            try database.execute("COMMIT")
        } catch {
            try? database.execute("ROLLBACK")
            throw error
        }
    }

    public func search(
        _ query: String,
        limit: Int = 50,
        offset: Int = 0,
        under folders: [URL]? = nil,
        inSubtitlePath subtitlePath: String? = nil
    ) throws -> [SubtitleSearchResult] {
        try searchPage(
            query,
            limit: limit,
            offset: offset,
            under: folders,
            inSubtitlePath: subtitlePath
        ).results
    }

    public func searchPage(
        _ query: String,
        limit: Int = 50,
        offset: Int = 0,
        under folders: [URL]? = nil,
        inSubtitlePath subtitlePath: String? = nil,
        diagnostics: SubtitleSearchDiagnosticSink? = nil
    ) throws -> SubtitleSearchPage {
        let searchPageStart = Self.diagnosticNow()

        func emit(
            _ name: String,
            since start: UInt64,
            fields: [SubtitleSearchDiagnosticField] = []
        ) {
            diagnostics?(
                SubtitleSearchDiagnosticEvent(
                    name: name,
                    phaseMilliseconds: Self.diagnosticMilliseconds(between: start, and: Self.diagnosticNow()),
                    fields: fields
                )
            )
        }

        let planStart = Self.diagnosticNow()
        guard let plan = Self.searchQueryPlan(for: query, limit: limit) else {
            emit("query_plan_empty", since: planStart)
            return SubtitleSearchPage(results: [], totalCount: 0, fileSummaries: [])
        }
        emit(
            "query_plan",
            since: planStart,
            fields: [
                .init("ftsQueryLength", plan.ftsQuery.count),
                .init("lineRule", Self.lineMatchRuleName(plan.lineMatchRule))
            ]
        )

        let scopeStart = Self.diagnosticNow()
        let offset = max(0, offset)
        let subtitlePathFilter = subtitlePath
        if let subtitlePathFilter, subtitlePathFilter.isEmpty {
            emit("scope_empty_subtitle_path", since: scopeStart)
            return SubtitleSearchPage(results: [], totalCount: 0, fileSummaries: [])
        }

        let pathPrefixes: [String]?
        if let folders {
            let prefixes = Self.folderPathPrefixes(for: folders)
            guard !prefixes.isEmpty else {
                emit("scope_empty_folders", since: scopeStart)
                return SubtitleSearchPage(results: [], totalCount: 0, fileSummaries: [])
            }
            pathPrefixes = prefixes
        } else {
            pathPrefixes = nil
        }
        emit(
            "scope_resolved",
            since: scopeStart,
            fields: [
                .init("pathPrefixes", pathPrefixes?.count ?? 0),
                .init("hasSubtitlePathFilter", subtitlePathFilter == nil ? "false" : "true")
            ]
        )

        do {
            let setupStart = Self.diagnosticNow()
            let candidateBatchLimit = Self.searchCandidateBatchLimit(for: limit)
            var candidateOffset = 0
            var results: [SubtitleSearchResult] = []
            var batchIndex = 0
            var totalCandidates = 0
            var totalMultiLineCandidates = 0
            var totalCueLineRows = 0
            let scopeCondition = pathPrefixes.map {
                let conditions = $0.map { _ in "(sf.subtitle_path >= ? AND sf.subtitle_path < ?)" }
                    .joined(separator: " OR ")
                return "AND (\(conditions))"
            } ?? ""
            let subtitlePathCondition = subtitlePathFilter.map { _ in "AND sf.subtitle_path = ?" } ?? ""
            emit(
                "setup",
                since: setupStart,
                fields: [
                    .init("candidateBatchLimit", candidateBatchLimit),
                    .init("scopeCondition", scopeCondition.isEmpty ? "none" : "path"),
                    .init("subtitlePathFilter", subtitlePathFilter == nil ? "false" : "true")
                ]
            )

            let prepareStart = Self.diagnosticNow()
            let statement = try database.prepare(
                """
                SELECT g.id, sf.subtitle_path, sf.format, vf.path, vf.video_name,
                       g.start_ms, g.end_ms, g.search_content, g.line_count
                FROM subtitle_cue_groups_fts f
                JOIN subtitle_cue_groups g ON g.id = f.cue_group_id
                JOIN subtitle_files sf ON sf.id = g.subtitle_file_id
                JOIN subtitle_video_matches m ON m.subtitle_file_id = sf.id AND m.is_active = 1
                JOIN video_files vf ON vf.id = m.video_file_id
                WHERE subtitle_cue_groups_fts MATCH ?
                \(scopeCondition)
                \(subtitlePathCondition)
                ORDER BY g.id ASC
                LIMIT ? OFFSET ?;
                """
            )
            emit("statement_prepare", since: prepareStart)

            while true {
                batchIndex += 1
                let queryStart = Self.diagnosticNow()
                try statement.reset()
                try statement.clearBindings()

                try statement.bind(plan.ftsQuery, at: 1)
                var bindIndex: Int32 = 2
                if let pathPrefixes {
                    for prefix in pathPrefixes {
                        try statement.bind(prefix, at: bindIndex)
                        bindIndex += 1
                        try statement.bind(Self.pathPrefixUpperBound(for: prefix), at: bindIndex)
                        bindIndex += 1
                    }
                }
                if let subtitlePathFilter {
                    try statement.bind(subtitlePathFilter, at: bindIndex)
                    bindIndex += 1
                }
                try statement.bind(candidateBatchLimit, at: bindIndex)
                bindIndex += 1
                try statement.bind(candidateOffset, at: bindIndex)

                var candidates: [SearchCandidate] = []
                while try statement.step() {
                    candidates.append(
                        SearchCandidate(
                            cueGroupID: statement.int64Column(0),
                            subtitlePath: statement.stringColumn(1),
                            subtitleFormat: SubtitleFormat(rawValue: statement.stringColumn(2)) ?? .srt,
                            videoPath: statement.stringColumn(3),
                            videoName: statement.stringColumn(4),
                            startMilliseconds: statement.intColumn(5),
                            endMilliseconds: statement.intColumn(6),
                            searchContent: statement.stringColumn(7),
                            lineCount: statement.intColumn(8)
                        )
                    )
                }
                emit(
                    "fts_batch",
                    since: queryStart,
                    fields: [
                        .init("batch", batchIndex),
                        .init("candidateOffset", candidateOffset),
                        .init("candidateBatchLimit", candidateBatchLimit),
                        .init("candidates", candidates.count)
                    ]
                )

                guard !candidates.isEmpty else {
                    break
                }

                candidateOffset += candidates.count
                totalCandidates += candidates.count

                let multiLineCueGroupIDs = candidates
                    .filter { $0.lineCount > 1 }
                    .map(\.cueGroupID)
                totalMultiLineCandidates += multiLineCueGroupIDs.count
                let cueLinesStart = Self.diagnosticNow()
                let linesByCueGroupID = try cueLines(forCueGroupIDs: multiLineCueGroupIDs)
                let cueLineRows = linesByCueGroupID.values.reduce(0) { $0 + $1.count }
                totalCueLineRows += cueLineRows
                emit(
                    "cue_lines",
                    since: cueLinesStart,
                    fields: [
                        .init("batch", batchIndex),
                        .init("multiLineCandidates", multiLineCueGroupIDs.count),
                        .init("cueLineRows", cueLineRows)
                    ]
                )

                let validationStart = Self.diagnosticNow()
                let acceptedBefore = results.count
                for candidate in candidates {
                    let lineContents: [String]
                    if candidate.lineCount > 1 {
                        let lines = linesByCueGroupID[candidate.cueGroupID] ?? []
                        lineContents = lines.isEmpty ? [candidate.searchContent] : lines.map(\.content)
                    } else {
                        lineContents = [candidate.searchContent]
                    }
                    if let result = searchResult(for: candidate, lineContents: lineContents, matching: plan) {
                        results.append(result)
                    }
                }
                let accepted = results.count - acceptedBefore
                emit(
                    "line_validation",
                    since: validationStart,
                    fields: [
                        .init("batch", batchIndex),
                        .init("candidates", candidates.count),
                        .init("accepted", accepted),
                        .init("rejected", candidates.count - accepted),
                        .init("acceptedSoFar", results.count)
                    ]
                )

                if candidates.count < candidateBatchLimit {
                    break
                }
            }

            let sortStart = Self.diagnosticNow()
            let sortedResults = Self.sortedSearchResults(results)
            emit(
                "sort_results",
                since: sortStart,
                fields: [
                    .init("results", sortedResults.count),
                    .init("uniqueSubtitlePaths", Set(sortedResults.map(\.subtitlePath)).count)
                ]
            )

            let pageStart = Self.diagnosticNow()
            var pageResults = Array(sortedResults.dropFirst(offset).prefix(limit))
            for i in 0..<pageResults.count {
                pageResults[i].searchRank = offset + i
            }
            emit(
                "page_slice",
                since: pageStart,
                fields: [
                    .init("offset", offset),
                    .init("limit", limit),
                    .init("pageResults", pageResults.count)
                ]
            )

            let summariesStart = Self.diagnosticNow()
            let fileSummaries = Self.fileSummaries(for: sortedResults)
            emit(
                "file_summaries",
                since: summariesStart,
                fields: [
                    .init("summaries", fileSummaries.count),
                    .init("results", sortedResults.count)
                ]
            )

            emit(
                "search_page_complete",
                since: searchPageStart,
                fields: [
                    .init("batches", batchIndex),
                    .init("totalCandidates", totalCandidates),
                    .init("multiLineCandidates", totalMultiLineCandidates),
                    .init("cueLineRows", totalCueLineRows),
                    .init("accepted", sortedResults.count),
                    .init("pageResults", pageResults.count),
                    .init("summaries", fileSummaries.count)
                ]
            )
            return SubtitleSearchPage(
                results: pageResults,
                totalCount: sortedResults.count,
                fileSummaries: fileSummaries
            )
        } catch {
            emit(
                "failed",
                since: searchPageStart,
                fields: [.init("error", error.localizedDescription)]
            )
            return SubtitleSearchPage(results: [], totalCount: 0, fileSummaries: [])
        }
    }

    public func searchNavigationSnapshot(
        _ query: String,
        under folders: [URL]? = nil,
        anchor: SearchNavigationAnchor,
        radius: Int = 1
    ) throws -> SearchNavigationSnapshot {
        let countPage = try searchPage(
            query,
            limit: 1,
            offset: 0,
            under: folders
        )
        let page = if countPage.totalCount <= countPage.results.count {
            countPage
        } else {
            try searchPage(
                query,
                limit: countPage.totalCount,
                offset: 0,
                under: folders
            )
        }
        let results = page.results
        let currentIndex = Self.searchNavigationIndex(
            in: results,
            anchor: anchor
        )
        let boundedRadius = max(1, radius)
        let neighborhood: [SubtitleSearchResult]
        if let currentIndex {
            let lowerBound = max(0, currentIndex - boundedRadius)
            let upperBound = min(results.count, currentIndex + boundedRadius + 1)
            neighborhood = Array(results[lowerBound..<upperBound])
        } else {
            neighborhood = Array(results.prefix((boundedRadius * 2) + 1))
        }

        let previous = currentIndex.flatMap { index in
            index > 0 ? results[index - 1] : nil
        }
        let current = currentIndex.map { results[$0] }
        let next = currentIndex.flatMap { index in
            index + 1 < results.count ? results[index + 1] : nil
        }

        return SearchNavigationSnapshot(
            totalCount: page.totalCount,
            currentIndex: currentIndex,
            neighborhood: neighborhood,
            previous: previous,
            current: current,
            next: next
        )
    }

    public func libraryVideos(under folders: [URL]) throws -> [LibraryVideo] {
        let pathPrefixes = Self.folderPathPrefixes(for: folders)
        guard !pathPrefixes.isEmpty else {
            return []
        }

        return try indexedLibraryVideos(scopedTo: pathPrefixes)
    }

    public func libraryPresentation(under folders: [URL]) throws -> [LibraryFolderPresentation] {
        let pathPrefixes = Self.folderPathPrefixes(for: folders)
        guard !pathPrefixes.isEmpty else {
            return []
        }

        let scopeCondition = pathPrefixes.map { _ in "(subtitle_path >= ? AND subtitle_path < ?)" }
            .joined(separator: " OR ")
        let statement = try database.prepare(
            """
            SELECT folder_path, folder_title, video_path, video_name, duration,
                   subtitle_path, subtitle_format, display_title, file_extension
            FROM library_video_rows
            WHERE \(scopeCondition)
            ORDER BY folder_order ASC, video_order ASC, video_path ASC;
            """
        )

        var bindIndex: Int32 = 1
        for prefix in pathPrefixes {
            try statement.bind(prefix, at: bindIndex)
            bindIndex += 1
            try statement.bind(Self.pathPrefixUpperBound(for: prefix), at: bindIndex)
            bindIndex += 1
        }

        var groups: [LibraryFolderPresentation] = []
        var currentFolderPath: String?
        var currentFolderTitle = ""
        var currentVideos: [LibraryVideoPresentation] = []

        func appendCurrentGroup() {
            guard let currentFolderPath else {
                return
            }

            groups.append(
                LibraryFolderPresentation(
                    folderPath: currentFolderPath,
                    folderTitle: currentFolderTitle,
                    videos: currentVideos
                )
            )
        }

        while try statement.step() {
            let folderPath = statement.stringColumn(0)
            if currentFolderPath != folderPath {
                appendCurrentGroup()
                currentFolderPath = folderPath
                currentFolderTitle = statement.stringColumn(1)
                currentVideos = []
            }

            currentVideos.append(
                LibraryVideoPresentation(
                    videoPath: statement.stringColumn(2),
                    videoName: statement.stringColumn(3),
                    duration: statement.nullableDoubleColumn(4),
                    subtitlePath: statement.stringColumn(5),
                    subtitleFormat: SubtitleFormat(rawValue: statement.stringColumn(6)) ?? .srt,
                    displayTitle: statement.stringColumn(7),
                    fileExtension: statement.stringColumn(8)
                )
            )
        }

        appendCurrentGroup()
        return groups
    }

    public func rebuildLibraryPresentationSnapshot() throws {
        let videosByFolderPath = Dictionary(grouping: try indexedLibraryVideos(scopedTo: nil)) {
            URL(fileURLWithPath: $0.videoPath)
                .deletingLastPathComponent()
                .standardizedFileURL
                .path
        }

        let folderPaths = videosByFolderPath.keys.sorted { lhs, rhs in
            let lhsTitle = URL(fileURLWithPath: lhs).lastPathComponent
            let rhsTitle = URL(fileURLWithPath: rhs).lastPathComponent
            let titleComparison = lhsTitle.localizedStandardCompare(rhsTitle)
            if titleComparison != .orderedSame {
                return titleComparison == .orderedAscending
            }

            return lhs.localizedStandardCompare(rhs) == .orderedAscending
        }

        try database.execute("BEGIN IMMEDIATE TRANSACTION")
        do {
            try database.execute("DELETE FROM library_video_rows;")

            let updatedAt = ISO8601DateFormatter().string(from: Date())
            let insert = try database.prepare(
                """
                INSERT INTO library_video_rows(
                    video_path,
                    video_name,
                    duration,
                    subtitle_path,
                    subtitle_format,
                    folder_path,
                    folder_title,
                    display_title,
                    file_extension,
                    folder_order,
                    video_order,
                    updated_at
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
                """
            )

            for (folderOrder, folderPath) in folderPaths.enumerated() {
                let folderTitle = URL(fileURLWithPath: folderPath).lastPathComponent
                let videos = (videosByFolderPath[folderPath] ?? []).sorted(by: Self.libraryVideoSort)
                let rankWidth = max(2, String(videos.count).count)

                for (videoOrder, video) in videos.enumerated() {
                    let sequence = String(format: "%0*d", rankWidth, videoOrder + 1)
                    let fileExtension = URL(fileURLWithPath: video.videoPath).pathExtension.lowercased()
                    try insert.bind(video.videoPath, at: 1)
                    try insert.bind(video.videoName, at: 2)
                    if let duration = video.duration {
                        try insert.bind(duration, at: 3)
                    } else {
                        try insert.bindNull(at: 3)
                    }
                    try insert.bind(video.subtitlePath, at: 4)
                    try insert.bind(video.subtitleFormat.rawValue, at: 5)
                    try insert.bind(folderPath, at: 6)
                    try insert.bind(folderTitle, at: 7)
                    try insert.bind("\(folderTitle) - \(sequence)", at: 8)
                    try insert.bind(fileExtension, at: 9)
                    try insert.bind(folderOrder, at: 10)
                    try insert.bind(videoOrder, at: 11)
                    try insert.bind(updatedAt, at: 12)
                    try insert.run()
                    try insert.reset()
                    try insert.clearBindings()
                }
            }

            try database.execute("COMMIT")
        } catch {
            try? database.execute("ROLLBACK")
            throw error
        }
    }

    private func indexedLibraryVideos(scopedTo pathPrefixes: [String]?) throws -> [LibraryVideo] {
        let scopeCondition = pathPrefixes?.map { _ in "(sf.subtitle_path >= ? AND sf.subtitle_path < ?)" }
            .joined(separator: " OR ") ?? ""
        let whereClause = pathPrefixes?.isEmpty == false ? "WHERE \(scopeCondition)" : ""
        let statement = try database.prepare(
            """
            SELECT vf.path, vf.video_name, vf.duration, sf.subtitle_path, sf.format
            FROM subtitle_files sf INDEXED BY idx_subtitle_files_subtitle_path
            JOIN subtitle_video_matches m ON m.subtitle_file_id = sf.id AND m.is_active = 1
            JOIN video_files vf ON vf.id = m.video_file_id
            \(whereClause)
            ORDER BY vf.path ASC, sf.subtitle_path ASC;
            """
        )

        if let pathPrefixes {
            var bindIndex: Int32 = 1
            for prefix in pathPrefixes {
                try statement.bind(prefix, at: bindIndex)
                bindIndex += 1
                try statement.bind(Self.pathPrefixUpperBound(for: prefix), at: bindIndex)
                bindIndex += 1
            }
        }

        var videosByPath: [String: LibraryVideo] = [:]
        while try statement.step() {
            let subtitleFormat = SubtitleFormat(rawValue: statement.stringColumn(4)) ?? .srt
            let video = LibraryVideo(
                videoPath: statement.stringColumn(0),
                videoName: statement.stringColumn(1),
                duration: statement.nullableDoubleColumn(2),
                subtitlePath: statement.stringColumn(3),
                subtitleFormat: subtitleFormat
            )

            if let existing = videosByPath[video.videoPath] {
                let subtitleComparison = video.subtitlePath.localizedStandardCompare(existing.subtitlePath)
                if subtitleComparison == .orderedAscending {
                    videosByPath[video.videoPath] = video
                }
            } else {
                videosByPath[video.videoPath] = video
            }
        }

        return videosByPath.values.sorted { lhs, rhs in
            Self.libraryVideoSort(lhs, rhs)
        }
    }

    public func updateVideoDuration(videoFile: URL, duration: Double?) throws {
        let statement = try database.prepare(
            """
            UPDATE video_files
            SET duration = ?
            WHERE path = ?;
            """
        )

        if let duration, duration.isFinite, duration >= 0 {
            try statement.bind(duration, at: 1)
        } else {
            try statement.bindNull(at: 1)
        }
        try statement.bind(videoFile.path, at: 2)
        try statement.run()

        let snapshotStatement = try database.prepare(
            """
            UPDATE library_video_rows
            SET duration = ?
            WHERE video_path = ?;
            """
        )
        if let duration, duration.isFinite, duration >= 0 {
            try snapshotStatement.bind(duration, at: 1)
        } else {
            try snapshotStatement.bindNull(at: 1)
        }
        try snapshotStatement.bind(videoFile.path, at: 2)
        try snapshotStatement.run()
    }

    public func libraryPlaybackHistory(forVideoFile videoFile: URL) throws -> LibraryPlaybackHistory? {
        let statement = try database.prepare(
            """
            SELECT video_path, position_ms, duration, updated_at
            FROM library_playback_history
            WHERE video_path = ?;
            """
        )

        try statement.bind(videoFile.path, at: 1)

        guard try statement.step() else {
            return nil
        }

        return LibraryPlaybackHistory(
            videoPath: statement.stringColumn(0),
            positionMilliseconds: max(0, statement.intColumn(1)),
            duration: statement.nullableDoubleColumn(2),
            updatedAt: statement.stringColumn(3)
        )
    }

    public func upsertLibraryPlaybackHistory(
        videoFile: URL,
        positionMilliseconds: Int,
        duration: Double?
    ) throws {
        let statement = try database.prepare(
            """
            INSERT INTO library_playback_history(video_path, position_ms, duration, updated_at)
            VALUES (?, ?, ?, ?)
            ON CONFLICT(video_path) DO UPDATE SET
                position_ms = excluded.position_ms,
                duration = excluded.duration,
                updated_at = excluded.updated_at;
            """
        )

        try statement.bind(videoFile.path, at: 1)
        try statement.bind(max(0, positionMilliseconds), at: 2)
        if let duration, duration.isFinite, duration > 0 {
            try statement.bind(duration, at: 3)
        } else {
            try statement.bindNull(at: 3)
        }
        try statement.bind(ISO8601DateFormatter().string(from: Date()), at: 4)
        try statement.run()
    }

    public func upsertShiori(
        subtitleFile: URL,
        subtitleFormat: SubtitleFormat,
        videoFile: URL,
        videoName: String,
        selection: SubtitleCueTextSelection,
        createdAt: Date = Date()
    ) throws -> Shiori {
        let statement = try database.prepare(
            """
            INSERT INTO shioris(
                subtitle_path,
                subtitle_format,
                start_ms,
                end_ms,
                video_path,
                video_name,
                content,
                is_valid,
                created_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, 1, ?)
            ON CONFLICT(subtitle_path, start_ms, end_ms) DO UPDATE SET
                subtitle_format = excluded.subtitle_format,
                video_path = excluded.video_path,
                video_name = excluded.video_name,
                content = excluded.content,
                is_valid = 1;
            """
        )

        try statement.bind(subtitleFile.path, at: 1)
        try statement.bind(subtitleFormat.rawValue, at: 2)
        try statement.bind(max(0, selection.startMilliseconds), at: 3)
        try statement.bind(max(selection.startMilliseconds, selection.endMilliseconds), at: 4)
        try statement.bind(videoFile.path, at: 5)
        try statement.bind(videoName, at: 6)
        try statement.bind(selection.text, at: 7)
        try statement.bind(ISO8601DateFormatter().string(from: createdAt), at: 8)
        try statement.run()

        guard let shiori = try shiori(
            subtitleFile: subtitleFile,
            startMilliseconds: selection.startMilliseconds,
            endMilliseconds: selection.endMilliseconds
        ) else {
            throw SQLiteDatabaseError.stepFailed("Inserted Shiori could not be loaded")
        }

        return shiori
    }

    public func shiori(
        subtitleFile: URL,
        startMilliseconds: Int,
        endMilliseconds: Int
    ) throws -> Shiori? {
        let statement = try database.prepare(
            """
            SELECT id, subtitle_path, subtitle_format, video_path, video_name,
                   start_ms, end_ms, content, is_valid, created_at
            FROM shioris
            WHERE subtitle_path = ?
              AND start_ms = ?
              AND end_ms = ?;
            """
        )

        try statement.bind(subtitleFile.path, at: 1)
        try statement.bind(max(0, startMilliseconds), at: 2)
        try statement.bind(max(startMilliseconds, endMilliseconds), at: 3)

        guard try statement.step() else {
            return nil
        }

        return shiori(from: statement)
    }

    public func shioris() throws -> [Shiori] {
        let statement = try database.prepare(
            """
            SELECT id, subtitle_path, subtitle_format, video_path, video_name,
                   start_ms, end_ms, content, is_valid, created_at
            FROM shioris
            ORDER BY subtitle_path ASC, start_ms ASC, end_ms ASC, id ASC;
            """
        )

        var shioris: [Shiori] = []
        while try statement.step() {
            shioris.append(shiori(from: statement))
        }
        return shioris
    }

    @discardableResult
    public func removeShiori(
        subtitleFile: URL,
        startMilliseconds: Int,
        endMilliseconds: Int
    ) throws -> Bool {
        guard try shiori(
            subtitleFile: subtitleFile,
            startMilliseconds: startMilliseconds,
            endMilliseconds: endMilliseconds
        ) != nil else {
            return false
        }

        let statement = try database.prepare(
            """
            DELETE FROM shioris
            WHERE subtitle_path = ?
              AND start_ms = ?
              AND end_ms = ?;
            """
        )

        try statement.bind(subtitleFile.path, at: 1)
        try statement.bind(max(0, startMilliseconds), at: 2)
        try statement.bind(max(startMilliseconds, endMilliseconds), at: 3)
        try statement.run()
        return true
    }

    public func removeStaleEntries(under folder: URL, keeping subtitleFiles: Set<String>) throws {
        try removeIndexedData(
            under: folder,
            keeping: subtitleFiles,
            removeSearchPath: false
        )
    }

    public func removeIndexedFolder(_ folder: URL) throws {
        try removeIndexedData(
            under: folder,
            keeping: [],
            removeSearchPath: true
        )
    }

    private struct SearchCandidate {
        let cueGroupID: Int64
        let subtitlePath: String
        let subtitleFormat: SubtitleFormat
        let videoPath: String
        let videoName: String
        let startMilliseconds: Int
        let endMilliseconds: Int
        let searchContent: String
        let lineCount: Int
    }

    private struct CueGroupSelection {
        let cueGroupID: Int64
        let startMilliseconds: Int
        let endMilliseconds: Int
        let searchContent: String
    }

    private struct SearchQueryPlan {
        let ftsQuery: String
        let lineMatchRule: LineMatchRule
    }

    private enum LineMatchRule {
        case latinPrefix(String)
        case orderedLatinTokens([String])
        case cjkSubstring(String)
        case explicitFTS(String)
    }

    private static func diagnosticNow() -> UInt64 {
        DispatchTime.now().uptimeNanoseconds
    }

    private static func diagnosticMilliseconds(between start: UInt64, and end: UInt64) -> Double {
        Double(end - start) / 1_000_000
    }

    private static func lineMatchRuleName(_ rule: LineMatchRule) -> String {
        switch rule {
        case .latinPrefix:
            return "latinPrefix"
        case .orderedLatinTokens:
            return "orderedLatinTokens"
        case .cjkSubstring:
            return "cjkSubstring"
        case .explicitFTS:
            return "explicitFTS"
        }
    }

    private func searchResult(
        for candidate: SearchCandidate,
        lineContents: [String],
        matching plan: SearchQueryPlan
    ) -> SubtitleSearchResult? {
        guard lineContents.contains(where: { Self.line($0, matches: plan.lineMatchRule) }) else {
            return nil
        }

        return SubtitleSearchResult(
            entryID: candidate.cueGroupID,
            subtitlePath: candidate.subtitlePath,
            subtitleFormat: candidate.subtitleFormat,
            videoPath: candidate.videoPath,
            videoName: candidate.videoName,
            startMilliseconds: candidate.startMilliseconds,
            endMilliseconds: candidate.endMilliseconds,
            content: candidate.searchContent,
            cueLines: lineContents
        )
    }

    private static func sortedSearchResults(_ results: [SubtitleSearchResult]) -> [SubtitleSearchResult] {
        let displayTitlesByPath = displayTitlesByPath(for: results.map(\.subtitlePath))

        return results.sorted { lhs, rhs in
            let lhsDisplayTitle = displayTitlesByPath[lhs.subtitlePath] ?? URL(fileURLWithPath: lhs.subtitlePath).lastPathComponent
            let rhsDisplayTitle = displayTitlesByPath[rhs.subtitlePath] ?? URL(fileURLWithPath: rhs.subtitlePath).lastPathComponent
            let displayTitleComparison = SubtitleDisplayTitleResolver.compareDisplayTitles(lhsDisplayTitle, rhsDisplayTitle)
            if displayTitleComparison != .orderedSame {
                return displayTitleComparison == .orderedAscending
            }

            let pathComparison = lhs.subtitlePath.localizedStandardCompare(rhs.subtitlePath)
            if pathComparison != .orderedSame {
                return pathComparison == .orderedAscending
            }

            if lhs.startMilliseconds != rhs.startMilliseconds {
                return lhs.startMilliseconds < rhs.startMilliseconds
            }

            if lhs.endMilliseconds != rhs.endMilliseconds {
                return lhs.endMilliseconds < rhs.endMilliseconds
            }

            return lhs.entryID < rhs.entryID
        }
    }

    private static func searchNavigationIndex(
        in results: [SubtitleSearchResult],
        anchor: SearchNavigationAnchor
    ) -> Int? {
        if let videoPath = anchor.videoPath,
           let subtitlePath = anchor.subtitlePath {
            let normalizedVideoPath = URL(fileURLWithPath: videoPath).standardizedFileURL.path
            let normalizedSubtitlePath = URL(fileURLWithPath: subtitlePath).standardizedFileURL.path
            var timeMatchedIndex: Int?

            for (index, result) in results.enumerated() {
                let resultVideoPath = URL(fileURLWithPath: result.videoPath).standardizedFileURL.path
                let resultSubtitlePath = URL(fileURLWithPath: result.subtitlePath).standardizedFileURL.path
                guard resultVideoPath == normalizedVideoPath,
                      resultSubtitlePath == normalizedSubtitlePath,
                      result.startMilliseconds <= anchor.currentMilliseconds
                else {
                    continue
                }

                timeMatchedIndex = index
            }

            if let timeMatchedIndex {
                return timeMatchedIndex
            }
        }

        if let selectedEntryID = anchor.selectedEntryID,
           let selectedIndex = results.firstIndex(where: { $0.entryID == selectedEntryID }) {
            return selectedIndex
        }

        return nil
    }

    private static func fileSummaries(for results: [SubtitleSearchResult]) -> [SubtitleSearchFileSummary] {
        var countsByPath: [String: Int] = [:]
        for result in results {
            countsByPath[result.subtitlePath, default: 0] += 1
        }

        let displayTitlesByPath = displayTitlesByPath(for: Array(countsByPath.keys))

        return countsByPath.keys.sorted { lhs, rhs in
            let lhsDisplayTitle = displayTitlesByPath[lhs] ?? URL(fileURLWithPath: lhs).lastPathComponent
            let rhsDisplayTitle = displayTitlesByPath[rhs] ?? URL(fileURLWithPath: rhs).lastPathComponent
            let displayTitleComparison = SubtitleDisplayTitleResolver.compareDisplayTitles(lhsDisplayTitle, rhsDisplayTitle)
            if displayTitleComparison != .orderedSame {
                return displayTitleComparison == .orderedAscending
            }

            return lhs.localizedStandardCompare(rhs) == .orderedAscending
        }
        .map { path in
            SubtitleSearchFileSummary(
                subtitlePath: path,
                subtitleFileName: URL(fileURLWithPath: path).lastPathComponent,
                subtitleDisplayTitle: displayTitlesByPath[path] ?? URL(fileURLWithPath: path).lastPathComponent,
                matchCount: countsByPath[path] ?? 0
            )
        }
    }

    private static func displayTitlesByPath(for subtitlePaths: [String]) -> [String: String] {
        Dictionary(
            uniqueKeysWithValues: Set(subtitlePaths).map { path in
                (
                    path,
                    SubtitleDisplayTitleResolver.displayTitle(forSubtitlePath: path)
                )
            }
        )
    }

    private static func searchQueryPlan(for query: String, limit: Int) -> SearchQueryPlan? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, limit > 0 else {
            return nil
        }

        let hasExplicitPhrase = trimmed.count >= 2 && trimmed.first == "\"" && trimmed.last == "\""
        let hasFTSSyntax = hasExplicitPhrase || trimmed.contains("*") || containsFTSOperator(in: trimmed)
        let hasCJK = containsCJKSearchCharacter(in: trimmed)
        let queryTokens = hasCJK ? [] : tokenizeLatinTokens(trimmed)
        if !hasFTSSyntax && !hasCJK && queryTokens.isEmpty {
            return nil
        }

        let ftsQuery: String
        let lineMatchRule: LineMatchRule
        if hasFTSSyntax {
            ftsQuery = trimmed
            lineMatchRule = .explicitFTS(trimmed)
        } else if hasCJK {
            ftsQuery = "\"\(escapeFTSPhrase(segmentCJK(trimmed).trimmingCharacters(in: .whitespacesAndNewlines)))\""
            lineMatchRule = .cjkSubstring(trimmed)
        } else if queryTokens.count > 1 {
            ftsQuery = queryTokens.joined(separator: " AND ")
            lineMatchRule = .orderedLatinTokens(queryTokens)
        } else {
            ftsQuery = "\(queryTokens[0])*"
            lineMatchRule = .latinPrefix(queryTokens[0])
        }

        return SearchQueryPlan(
            ftsQuery: ftsQuery,
            lineMatchRule: lineMatchRule
        )
    }

    private static func line(_ line: String, matches rule: LineMatchRule) -> Bool {
        switch rule {
        case .latinPrefix(let token):
            tokenizeLatinTokens(line).contains { $0.hasPrefix(token) }
        case .orderedLatinTokens(let tokens):
            matchesOrderedWholeTokens(line, queryTokens: tokens)
        case .cjkSubstring(let query):
            line.contains(query)
        case .explicitFTS(let query):
            matchesExplicitFTSLineFallback(line, query: query)
        }
    }

    private static func matchesExplicitFTSLineFallback(_ line: String, query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count >= 2, trimmed.first == "\"", trimmed.last == "\"" {
            let phrase = String(trimmed.dropFirst().dropLast())
            return line.range(of: phrase, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }

        let operators = Set(["AND", "OR", "NOT", "NEAR"])
        let queryTokens = tokenizeLatinTokens(trimmed)
            .filter { !operators.contains($0.uppercased()) }
        guard !queryTokens.isEmpty else {
            return false
        }

        let lineTokens = tokenizeLatinTokens(line)
        if trimmed.uppercased().contains(" OR ") {
            return queryTokens.contains { token in
                lineTokens.contains { $0 == token || $0.hasPrefix(token) }
            }
        }

        return queryTokens.allSatisfy { token in
            lineTokens.contains { $0 == token || $0.hasPrefix(token) }
        }
    }

    private static func containsFTSOperator(in text: String) -> Bool {
        let operators = Set(["AND", "OR", "NOT", "NEAR"])
        var current = ""

        func currentIsOperator() -> Bool {
            operators.contains(current)
        }

        for character in text {
            if isASCIIWordCharacter(character) {
                current.append(character)
            } else {
                if currentIsOperator() {
                    return true
                }
                current = ""
            }
        }

        return currentIsOperator()
    }

    private static func tokenizeLatinTokens(_ text: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        var containsApostrophe = false
        var index = text.startIndex

        func flushToken() {
            if !current.isEmpty {
                tokens.append(current)
                current = ""
            }
            containsApostrophe = false
        }

        while index < text.endIndex {
            let character = text[index]

            if isASCIILetterOrDigit(character) {
                current.append(contentsOf: character.lowercased())
            } else if character == "'", !current.isEmpty, !containsApostrophe {
                let nextIndex = text.index(after: index)
                if nextIndex < text.endIndex, isASCIILetterOrDigit(text[nextIndex]) {
                    current.append(character)
                    containsApostrophe = true
                } else {
                    flushToken()
                }
            } else {
                flushToken()
            }

            index = text.index(after: index)
        }

        flushToken()
        return tokens
    }

    private static func matchesOrderedWholeTokens(_ content: String, queryTokens: [String]) -> Bool {
        guard !queryTokens.isEmpty else {
            return false
        }

        let contentTokens = tokenizeLatinTokens(content)
        guard contentTokens.count >= queryTokens.count else {
            return false
        }

        var queryIndex = 0
        for token in contentTokens where token == queryTokens[queryIndex] {
            queryIndex += 1
            if queryIndex == queryTokens.count {
                return true
            }
        }

        return false
    }

    private static func segmentCJK(_ text: String) -> String {
        var segmented = ""
        for scalar in text.unicodeScalars {
            segmented.unicodeScalars.append(scalar)
            if isCJKSearchCharacter(scalar) {
                segmented.append(" ")
            }
        }
        return segmented
    }

    private static func containsCJKSearchCharacter(in text: String) -> Bool {
        text.unicodeScalars.contains(where: isCJKSearchCharacter)
    }

    private static func isCJKSearchCharacter(_ scalar: UnicodeScalar) -> Bool {
        let value = Int(scalar.value)
        return (0x3400...0x4DBF).contains(value)
            || (0x4E00...0x9FFF).contains(value)
            || (0xF900...0xFAFF).contains(value)
            || (0x3040...0x309F).contains(value)
            || (0x30A0...0x30FF).contains(value)
            || (0x31F0...0x31FF).contains(value)
            || (0xFF66...0xFF9F).contains(value)
    }

    private static func isASCIILetterOrDigit(_ character: Character) -> Bool {
        guard character.unicodeScalars.count == 1,
              let value = character.unicodeScalars.first?.value
        else {
            return false
        }

        return (65...90).contains(value) || (97...122).contains(value) || (48...57).contains(value)
    }

    private static func escapeFTSPhrase(_ text: String) -> String {
        text.replacingOccurrences(of: "\"", with: "\"\"")
    }

    private static func expandedSQLLimit(for limit: Int) -> Int {
        let (expanded, overflow) = limit.multipliedReportingOverflow(by: 2)
        if overflow {
            return Int(Int32.max)
        }

        return min(expanded, Int(Int32.max))
    }

    private static func searchCandidateBatchLimit(for limit: Int) -> Int {
        max(expandedSQLLimit(for: limit), 100)
    }

    private static func isASCIIWordCharacter(_ character: Character) -> Bool {
        isASCIILetterOrDigit(character) || character == "_"
    }

    private func removeIndexedData(
        under folder: URL,
        keeping subtitleFiles: Set<String>,
        removeSearchPath: Bool
    ) throws {
        let folderPathPrefixes = Self.folderPathPrefixes(for: folder)
        let prefixCondition = folderPathPrefixes
            .map { _ in "substr(sf.subtitle_path, 1, ?) = ?" }
            .joined(separator: " OR ")
        let libraryRowPrefixCondition = folderPathPrefixes
            .map { _ in "substr(subtitle_path, 1, ?) = ?" }
            .joined(separator: " OR ")
        let keepCondition: String
        let libraryRowKeepCondition: String
        let keepPlaceholders: String

        if subtitleFiles.isEmpty {
            keepCondition = ""
            libraryRowKeepCondition = ""
            keepPlaceholders = ""
        } else {
            keepPlaceholders = subtitleFiles.map { _ in "?" }.joined(separator: ", ")
            keepCondition = "AND sf.subtitle_path NOT IN (\(keepPlaceholders))"
            libraryRowKeepCondition = "AND subtitle_path NOT IN (\(keepPlaceholders))"
        }

        try database.execute("BEGIN IMMEDIATE TRANSACTION")
        do {
            let deleteASSRenderSegments = try database.prepare(
                """
                DELETE FROM ass_render_segments
                WHERE subtitle_file_id IN (
                    SELECT sf.id
                    FROM subtitle_files sf
                    WHERE (\(prefixCondition)) \(keepCondition)
                );
                """
            )
            try bindStaleEntryParameters(
                statement: deleteASSRenderSegments,
                folderPathPrefixes: folderPathPrefixes,
                subtitleFiles: subtitleFiles
            )
            try deleteASSRenderSegments.run()

            let deleteFTS = try database.prepare(
                """
                DELETE FROM subtitle_cue_groups_fts
                WHERE cue_group_id IN (
                    SELECT g.id
                    FROM subtitle_cue_groups g
                    JOIN subtitle_files sf ON sf.id = g.subtitle_file_id
                    WHERE (\(prefixCondition)) \(keepCondition)
                );
                """
            )
            try bindStaleEntryParameters(
                statement: deleteFTS,
                folderPathPrefixes: folderPathPrefixes,
                subtitleFiles: subtitleFiles
            )
            try deleteFTS.run()

            let deleteLibraryRows = try database.prepare(
                """
                DELETE FROM library_video_rows
                WHERE (\(libraryRowPrefixCondition)) \(libraryRowKeepCondition);
                """
            )
            try bindStaleEntryParameters(
                statement: deleteLibraryRows,
                folderPathPrefixes: folderPathPrefixes,
                subtitleFiles: subtitleFiles
            )
            try deleteLibraryRows.run()

            let deleteFiles = try database.prepare(
                """
                DELETE FROM subtitle_files
                WHERE id IN (
                    SELECT sf.id
                    FROM subtitle_files sf
                    WHERE (\(prefixCondition)) \(keepCondition)
                );
                """
            )
            try bindStaleEntryParameters(
                statement: deleteFiles,
                folderPathPrefixes: folderPathPrefixes,
                subtitleFiles: subtitleFiles
            )
            try deleteFiles.run()

            if removeSearchPath {
                let searchPathVariants = Self.folderPathVariants(for: folder)
                let searchPathPlaceholders = searchPathVariants.map { _ in "?" }.joined(separator: ", ")
                let deleteSearchPath = try database.prepare(
                    """
                    DELETE FROM search_paths
                    WHERE path IN (\(searchPathPlaceholders));
                    """
                )

                for (offset, path) in searchPathVariants.enumerated() {
                    try deleteSearchPath.bind(path, at: Int32(offset + 1))
                }
                try deleteSearchPath.run()
            }

            try deleteOrphanedVideoFiles()
            try database.execute("COMMIT")
        } catch {
            try? database.execute("ROLLBACK")
            throw error
        }
    }

    private func upsertSubtitleFile(
        subtitleFile: URL,
        format: SubtitleFormat,
        fileSize: Int64?,
        modifiedAt: Date?
    ) throws -> Int64 {
        let statement = try database.prepare(
            """
            INSERT INTO subtitle_files(subtitle_path, format, file_size, modified_at, indexed_at)
            VALUES (?, ?, ?, ?, ?)
            ON CONFLICT(subtitle_path) DO UPDATE SET
                format = excluded.format,
                file_size = excluded.file_size,
                modified_at = excluded.modified_at,
                indexed_at = excluded.indexed_at
            RETURNING id;
            """
        )

        try statement.bind(subtitleFile.path, at: 1)
        try statement.bind(format.rawValue, at: 2)
        if let fileSize {
            try statement.bind(fileSize, at: 3)
        } else {
            try statement.bindNull(at: 3)
        }

        if let modifiedAt {
            try statement.bind(modifiedAt.timeIntervalSince1970, at: 4)
        } else {
            try statement.bindNull(at: 4)
        }

        try statement.bind(ISO8601DateFormatter().string(from: Date()), at: 5)

        guard try statement.step() else {
            return database.lastInsertRowID()
        }

        return statement.int64Column(0)
    }

    private func upsertVideoFile(_ videoFile: URL) throws -> Int64 {
        let attributes = try? FileManager.default.attributesOfItem(atPath: videoFile.path)
        let fileSize = (attributes?[.size] as? NSNumber)?.int64Value
        let modifiedAt = attributes?[.modificationDate] as? Date
        let statement = try database.prepare(
            """
            INSERT INTO video_files(path, video_name, file_size, modified_at)
            VALUES (?, ?, ?, ?)
            ON CONFLICT(path) DO UPDATE SET
                video_name = excluded.video_name,
                file_size = excluded.file_size,
                modified_at = excluded.modified_at
            RETURNING id;
            """
        )

        try statement.bind(videoFile.path, at: 1)
        try statement.bind(videoFile.lastPathComponent, at: 2)
        if let fileSize {
            try statement.bind(fileSize, at: 3)
        } else {
            try statement.bindNull(at: 3)
        }

        if let modifiedAt {
            try statement.bind(modifiedAt.timeIntervalSince1970, at: 4)
        } else {
            try statement.bindNull(at: 4)
        }

        guard try statement.step() else {
            return database.lastInsertRowID()
        }

        return statement.int64Column(0)
    }

    private func upsertSubtitleVideoMatch(subtitleFileID: Int64, videoFileID: Int64) throws {
        let clearActive = try database.prepare(
            """
            UPDATE subtitle_video_matches
            SET is_active = 0
            WHERE subtitle_file_id = ?;
            """
        )
        try clearActive.bind(subtitleFileID, at: 1)
        try clearActive.run()

        let statement = try database.prepare(
            """
            INSERT INTO subtitle_video_matches(
                subtitle_file_id,
                video_file_id,
                match_method,
                confidence,
                is_active
            )
            VALUES (?, ?, 'same-directory-basename', 1.0, 1)
            ON CONFLICT(subtitle_file_id, video_file_id) DO UPDATE SET
                match_method = excluded.match_method,
                confidence = excluded.confidence,
                is_active = excluded.is_active;
            """
        )
        try statement.bind(subtitleFileID, at: 1)
        try statement.bind(videoFileID, at: 2)
        try statement.run()
    }

    private func requireSubtitleFileID(for subtitleFile: URL) throws -> Int64 {
        let statement = try database.prepare(
            """
            SELECT id
            FROM subtitle_files
            WHERE subtitle_path = ?;
            """
        )
        try statement.bind(subtitleFile.path, at: 1)

        guard try statement.step() else {
            throw SQLiteDatabaseError.stepFailed("Subtitle file is not indexed: \(subtitleFile.path)")
        }

        return statement.int64Column(0)
    }

    private func requireVideoFileID(for videoFile: URL) throws -> Int64 {
        let statement = try database.prepare(
            """
            SELECT id
            FROM video_files
            WHERE path = ?;
            """
        )
        try statement.bind(videoFile.path, at: 1)

        guard try statement.step() else {
            throw SQLiteDatabaseError.stepFailed("Video file is not indexed: \(videoFile.path)")
        }

        return statement.int64Column(0)
    }

    private func insertCueGroup(
        subtitleFileID: Int64,
        subtitleFile: URL,
        group: SubtitleCueGroup
    ) throws -> Int64 {
        let statement = try database.prepare(
            """
            INSERT INTO subtitle_cue_groups(
                subtitle_file_id,
                subtitle_path,
                seq,
                start_time,
                end_time,
                start_ms,
                end_ms,
                search_content,
                line_count
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
            """
        )

        try statement.bind(subtitleFileID, at: 1)
        try statement.bind(subtitleFile.path, at: 2)
        if let sequenceNumber = group.sequenceNumber {
            try statement.bind(sequenceNumber, at: 3)
        } else {
            try statement.bindNull(at: 3)
        }
        try statement.bind(group.startTimecode, at: 4)
        try statement.bind(group.endTimecode, at: 5)
        try statement.bind(group.startMilliseconds, at: 6)
        try statement.bind(group.endMilliseconds, at: 7)
        try statement.bind(group.searchContent, at: 8)
        try statement.bind(max(1, group.cueLines.count), at: 9)
        try statement.run()

        return database.lastInsertRowID()
    }

    private func insertCueLine(cueGroupID: Int64, line: SubtitleCueLine) throws {
        let statement = try database.prepare(
            """
            INSERT INTO subtitle_cue_lines(
                cue_group_id,
                event_index,
                source_format,
                source_style,
                source_layer,
                start_time,
                end_time,
                start_ms,
                end_ms,
                content,
                display_x,
                display_y,
                display_order
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
            """
        )

        try statement.bind(cueGroupID, at: 1)
        try statement.bind(line.eventIndex, at: 2)
        try statement.bind(line.sourceFormat.rawValue, at: 3)
        if let sourceStyle = line.sourceStyle {
            try statement.bind(sourceStyle, at: 4)
        } else {
            try statement.bindNull(at: 4)
        }
        if let sourceLayer = line.sourceLayer {
            try statement.bind(sourceLayer, at: 5)
        } else {
            try statement.bindNull(at: 5)
        }
        try statement.bind(line.startTimecode, at: 6)
        try statement.bind(line.endTimecode, at: 7)
        try statement.bind(line.startMilliseconds, at: 8)
        try statement.bind(line.endMilliseconds, at: 9)
        try statement.bind(line.content, at: 10)
        if let displayX = line.displayX {
            try statement.bind(displayX, at: 11)
        } else {
            try statement.bindNull(at: 11)
        }
        if let displayY = line.displayY {
            try statement.bind(displayY, at: 12)
        } else {
            try statement.bindNull(at: 12)
        }
        try statement.bind(line.displayOrder, at: 13)
        try statement.run()
    }

    private func insertASSRenderSegment(
        subtitleFileID: Int64,
        segment: ASSRenderSegmentPayload
    ) throws {
        let statement = try database.prepare(
            """
            INSERT INTO ass_render_segments(
                subtitle_file_id,
                segment_index,
                algorithm_version,
                start_ms,
                end_ms,
                event_count,
                byte_count,
                script_text
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?);
            """
        )

        try statement.bind(subtitleFileID, at: 1)
        try statement.bind(segment.segmentIndex, at: 2)
        try statement.bind(ASSRenderSegmenter.cacheAlgorithmVersion, at: 3)
        try statement.bind(segment.startMilliseconds, at: 4)
        try statement.bind(segment.endMilliseconds, at: 5)
        try statement.bind(segment.eventCount, at: 6)
        try statement.bind(segment.byteCount, at: 7)
        try statement.bind(segment.scriptText, at: 8)
        try statement.run()
    }

    private func insertFTSRow(cueGroupID: Int64, content: String) throws {
        let statement = try database.prepare(
            """
            INSERT INTO subtitle_cue_groups_fts(content, cue_group_id)
            VALUES (?, ?);
            """
        )

        try statement.bind(Self.segmentCJK(content), at: 1)
        try statement.bind(cueGroupID, at: 2)
        try statement.run()
    }

    private func activeCueGroupSelection(
        forSubtitleFile subtitleFile: URL,
        atMilliseconds milliseconds: Int
    ) throws -> CueGroupSelection? {
        let statement = try database.prepare(
            """
            SELECT g.id, g.start_ms, g.end_ms, g.search_content
            FROM subtitle_cue_groups g
            JOIN subtitle_files sf ON sf.id = g.subtitle_file_id
            WHERE sf.subtitle_path = ?
              AND g.start_ms <= ?
              AND g.end_ms > ?
              AND g.end_ms > g.start_ms
            ORDER BY (g.end_ms - g.start_ms) ASC,
                     g.end_ms DESC,
                     g.start_ms DESC,
                     g.id ASC
            LIMIT 1;
            """
        )

        try statement.bind(subtitleFile.path, at: 1)
        try statement.bind(milliseconds, at: 2)
        try statement.bind(milliseconds, at: 3)

        guard try statement.step() else {
            return nil
        }

        return cueGroupSelection(from: statement)
    }

    private func previousCueGroupSelection(
        forSubtitleFile subtitleFile: URL,
        beforeOrAtMilliseconds milliseconds: Int
    ) throws -> CueGroupSelection? {
        let statement = try database.prepare(
            """
            SELECT g.id, g.start_ms, g.end_ms, g.search_content
            FROM subtitle_cue_groups g
            JOIN subtitle_files sf ON sf.id = g.subtitle_file_id
            WHERE sf.subtitle_path = ?
              AND g.end_ms <= ?
              AND g.end_ms > g.start_ms
            ORDER BY g.end_ms DESC,
                     (g.end_ms - g.start_ms) ASC,
                     g.start_ms DESC,
                     g.id ASC
            LIMIT 1;
            """
        )

        try statement.bind(subtitleFile.path, at: 1)
        try statement.bind(milliseconds, at: 2)

        guard try statement.step() else {
            return nil
        }

        return cueGroupSelection(from: statement)
    }

    private func rebuildFTSRows() throws {
        try database.execute("BEGIN IMMEDIATE TRANSACTION")
        do {
            try database.execute("DELETE FROM subtitle_cue_groups_fts;")

            var rows: [(cueGroupID: Int64, content: String)] = []
            do {
                let statement = try database.prepare(
                    """
                    SELECT id, search_content
                    FROM subtitle_cue_groups
                    ORDER BY id ASC;
                    """
                )

                while try statement.step() {
                    rows.append((statement.int64Column(0), statement.stringColumn(1)))
                }
            }

            for row in rows {
                try insertFTSRow(cueGroupID: row.cueGroupID, content: row.content)
            }

            try database.execute("COMMIT")
        } catch {
            try? database.execute("ROLLBACK")
            throw error
        }
    }

    private func cueLines(forCueGroupID cueGroupID: Int64) throws -> [SubtitleCueLine] {
        let statement = try database.prepare(
            """
            SELECT event_index, source_format, source_style, source_layer,
                   start_time, end_time, start_ms, end_ms, content,
                   display_x, display_y, display_order
            FROM subtitle_cue_lines
            WHERE cue_group_id = ?
            ORDER BY display_order ASC, event_index ASC, id ASC;
            """
        )

        try statement.bind(cueGroupID, at: 1)

        var lines: [SubtitleCueLine] = []
        while try statement.step() {
            lines.append(
                SubtitleCueLine(
                    eventIndex: statement.intColumn(0),
                    sourceFormat: SubtitleFormat(rawValue: statement.stringColumn(1)) ?? .srt,
                    sourceStyle: statement.nullableStringColumn(2),
                    sourceLayer: statement.nullableIntColumn(3),
                    startTimecode: statement.stringColumn(4),
                    endTimecode: statement.stringColumn(5),
                    startMilliseconds: statement.intColumn(6),
                    endMilliseconds: statement.intColumn(7),
                    content: statement.stringColumn(8),
                    displayX: statement.nullableDoubleColumn(9),
                    displayY: statement.nullableDoubleColumn(10),
                    displayOrder: statement.intColumn(11)
                )
            )
        }

        return lines
    }

    private func cueLines(forCueGroupIDs cueGroupIDs: [Int64]) throws -> [Int64: [SubtitleCueLine]] {
        guard !cueGroupIDs.isEmpty else {
            return [:]
        }

        let placeholders = cueGroupIDs.map { _ in "?" }.joined(separator: ", ")
        let statement = try database.prepare(
            """
            SELECT cue_group_id, event_index, source_format, source_style, source_layer,
                   start_time, end_time, start_ms, end_ms, content,
                   display_x, display_y, display_order
            FROM subtitle_cue_lines
            WHERE cue_group_id IN (\(placeholders))
            ORDER BY cue_group_id ASC, display_order ASC, event_index ASC, id ASC;
            """
        )

        for (offset, cueGroupID) in cueGroupIDs.enumerated() {
            try statement.bind(cueGroupID, at: Int32(offset + 1))
        }

        var linesByCueGroupID: [Int64: [SubtitleCueLine]] = [:]
        linesByCueGroupID.reserveCapacity(cueGroupIDs.count)
        while try statement.step() {
            let cueGroupID = statement.int64Column(0)
            let line = SubtitleCueLine(
                eventIndex: statement.intColumn(1),
                sourceFormat: SubtitleFormat(rawValue: statement.stringColumn(2)) ?? .srt,
                sourceStyle: statement.nullableStringColumn(3),
                sourceLayer: statement.nullableIntColumn(4),
                startTimecode: statement.stringColumn(5),
                endTimecode: statement.stringColumn(6),
                startMilliseconds: statement.intColumn(7),
                endMilliseconds: statement.intColumn(8),
                content: statement.stringColumn(9),
                displayX: statement.nullableDoubleColumn(10),
                displayY: statement.nullableDoubleColumn(11),
                displayOrder: statement.intColumn(12)
            )
            linesByCueGroupID[cueGroupID, default: []].append(line)
        }

        return linesByCueGroupID
    }

    private func deleteIndexedSubtitlePath(_ subtitlePath: String) throws {
        let deleteASSRenderSegments = try database.prepare(
            """
            DELETE FROM ass_render_segments
            WHERE subtitle_file_id IN (
                SELECT id
                FROM subtitle_files
                WHERE subtitle_path = ?
            );
            """
        )
        try deleteASSRenderSegments.bind(subtitlePath, at: 1)
        try deleteASSRenderSegments.run()

        let deleteFTS = try database.prepare(
            """
            DELETE FROM subtitle_cue_groups_fts
            WHERE cue_group_id IN (
                SELECT g.id
                FROM subtitle_cue_groups g
                JOIN subtitle_files sf ON sf.id = g.subtitle_file_id
                WHERE sf.subtitle_path = ?
            );
            """
        )
        try deleteFTS.bind(subtitlePath, at: 1)
        try deleteFTS.run()

        let deleteLibraryRows = try database.prepare(
            "DELETE FROM library_video_rows WHERE subtitle_path = ?;"
        )
        try deleteLibraryRows.bind(subtitlePath, at: 1)
        try deleteLibraryRows.run()

        let deleteFile = try database.prepare(
            "DELETE FROM subtitle_files WHERE subtitle_path = ?;"
        )
        try deleteFile.bind(subtitlePath, at: 1)
        try deleteFile.run()
    }

    private func deleteOrphanedVideoFiles() throws {
        try database.execute(
            """
            DELETE FROM video_files
            WHERE id NOT IN (
                SELECT DISTINCT video_file_id FROM subtitle_video_matches
            );
            """
        )
    }

    private func dropDerivedSubtitleIndexTables() throws {
        try database.execute(
            """
            DROP TABLE IF EXISTS subtitle_cue_groups_fts;
            DROP TABLE IF EXISTS subtitle_cue_lines;
            DROP TABLE IF EXISTS subtitle_cue_groups;
            DROP TABLE IF EXISTS ass_render_segments;
            DROP TABLE IF EXISTS subtitle_video_matches;
            DROP TABLE IF EXISTS video_files;
            DROP TABLE IF EXISTS subtitle_entries_fts;
            DROP TABLE IF EXISTS subtitle_entries;
            DROP TABLE IF EXISTS subtitle_files;
            """
        )
    }

    private func entry(from statement: SQLiteStatement) -> SubtitleDatabaseEntry {
        SubtitleDatabaseEntry(
            id: statement.int64Column(0),
            subtitlePath: statement.stringColumn(1),
            subtitleFormat: SubtitleFormat(rawValue: statement.stringColumn(2)) ?? .srt,
            videoPath: statement.stringColumn(3),
            videoName: statement.stringColumn(4),
            sequenceNumber: statement.nullableIntColumn(5),
            startTimecode: statement.stringColumn(6),
            endTimecode: statement.stringColumn(7),
            startMilliseconds: statement.intColumn(8),
            endMilliseconds: statement.intColumn(9),
            content: statement.stringColumn(10)
        )
    }

    private func cueGroupSelection(from statement: SQLiteStatement) -> CueGroupSelection {
        CueGroupSelection(
            cueGroupID: statement.int64Column(0),
            startMilliseconds: statement.intColumn(1),
            endMilliseconds: statement.intColumn(2),
            searchContent: statement.stringColumn(3)
        )
    }

    private func shiori(from statement: SQLiteStatement) -> Shiori {
        Shiori(
            id: statement.int64Column(0),
            subtitlePath: statement.stringColumn(1),
            subtitleFormat: SubtitleFormat(rawValue: statement.stringColumn(2)) ?? .srt,
            videoPath: statement.stringColumn(3),
            videoName: statement.stringColumn(4),
            startMilliseconds: statement.intColumn(5),
            endMilliseconds: statement.intColumn(6),
            content: statement.stringColumn(7),
            isValid: statement.intColumn(8) != 0,
            createdAt: statement.stringColumn(9)
        )
    }

    private func bindStaleEntryParameters(
        statement: SQLiteStatement,
        folderPathPrefixes: [String],
        subtitleFiles: Set<String>
    ) throws {
        var bindIndex: Int32 = 1
        for prefix in folderPathPrefixes {
            try statement.bind(prefix.count, at: bindIndex)
            bindIndex += 1
            try statement.bind(prefix, at: bindIndex)
            bindIndex += 1
        }

        for (offset, path) in subtitleFiles.sorted().enumerated() {
            try statement.bind(path, at: bindIndex + Int32(offset))
        }
    }

    private func indexedSubtitlePaths() throws -> [String] {
        let statement = try database.prepare(
            """
            SELECT subtitle_path
            FROM subtitle_files
            ORDER BY subtitle_path ASC;
            """
        )

        var paths: [String] = []
        while try statement.step() {
            paths.append(statement.stringColumn(0))
        }
        return paths
    }

    private func searchPaths() throws -> [String] {
        let statement = try database.prepare(
            """
            SELECT path
            FROM search_paths
            ORDER BY path ASC;
            """
        )

        var paths: [String] = []
        while try statement.step() {
            paths.append(statement.stringColumn(0))
        }
        return paths
    }

    private func deleteSearchPath(_ searchPath: String) throws {
        let statement = try database.prepare(
            "DELETE FROM search_paths WHERE path = ?;"
        )
        try statement.bind(searchPath, at: 1)
        try statement.run()
    }

    private static func path(_ path: String, isUnderAny folders: [URL]) -> Bool {
        let standardizedPath = URL(fileURLWithPath: path).standardizedFileURL.path
        return folders.contains { folder in
            folderPathPrefixes(for: folder).contains { prefix in
                standardizedPath.hasPrefix(prefix)
            }
        }
    }

    private static func folderPath(_ path: String, matchesAny folders: [URL]) -> Bool {
        let standardizedPath = normalizedFolderPath(URL(fileURLWithPath: path).standardizedFileURL.path)
        return folders.contains { folder in
            folderPathVariants(for: folder).contains(standardizedPath)
        }
    }

    private static func folderPathPrefixes(for folders: [URL]) -> [String] {
        Array(Set(folders.flatMap(folderPathPrefixes(for:)))).sorted()
    }

    private static func folderPathPrefixes(for folder: URL) -> [String] {
        var path = normalizedFolderPath(folder.standardizedFileURL.path)
        if !path.hasSuffix("/") {
            path.append("/")
        }

        var prefixes = Set([path])

        if path.hasPrefix("/var/") {
            prefixes.insert("/private" + path)
        } else if path.hasPrefix("/private/var/") {
            prefixes.insert(String(path.dropFirst("/private".count)))
        }

        return prefixes.sorted()
    }

    private static func pathPrefixUpperBound(for prefix: String) -> String {
        prefix + "\u{10FFFF}"
    }

    private static func libraryVideoSort(_ lhs: LibraryVideo, _ rhs: LibraryVideo) -> Bool {
        let lhsFolder = URL(fileURLWithPath: lhs.videoPath).deletingLastPathComponent().lastPathComponent
        let rhsFolder = URL(fileURLWithPath: rhs.videoPath).deletingLastPathComponent().lastPathComponent
        let folderComparison = lhsFolder.localizedStandardCompare(rhsFolder)
        if folderComparison != .orderedSame {
            return folderComparison == .orderedAscending
        }

        let nameComparison = lhs.videoName.localizedStandardCompare(rhs.videoName)
        if nameComparison != .orderedSame {
            return nameComparison == .orderedAscending
        }

        return lhs.videoPath.localizedStandardCompare(rhs.videoPath) == .orderedAscending
    }

    private static func folderPathVariants(for folder: URL) -> [String] {
        let path = normalizedFolderPath(folder.standardizedFileURL.path)
        var paths = Set([path])

        if path.hasPrefix("/var/") {
            paths.insert("/private" + path)
        } else if path.hasPrefix("/private/var/") {
            paths.insert(String(path.dropFirst("/private".count)))
        }

        return paths.sorted()
    }

    private static func normalizedFolderPath(_ path: String) -> String {
        var path = path
        while path.count > 1 && path.hasSuffix("/") {
            path.removeLast()
        }
        return path
    }
}
