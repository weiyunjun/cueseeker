import Foundation

public struct SubtitleDatabaseEntry: Equatable, Sendable {
    public let id: Int64
    public let subtitlePath: String
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
    public let videoPath: String
    public let videoName: String
    public let startMilliseconds: Int
    public let endMilliseconds: Int
    public let content: String
}

public final class SubtitleDatabase {
    public static let currentSchemaVersion: Int = 1

    private let database: SQLiteDatabase

    public init(path: URL) throws {
        database = try SQLiteDatabase(path: path)
    }

    public func migrate() throws {
        try database.execute(
            """
            CREATE TABLE IF NOT EXISTS search_paths (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                type TEXT NOT NULL DEFAULT 'local',
                path TEXT NOT NULL UNIQUE,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS subtitle_files (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                srt_path TEXT NOT NULL UNIQUE,
                video_path TEXT,
                video_name TEXT,
                file_size INTEGER,
                modified_at REAL,
                indexed_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS subtitle_entries (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                srt_path TEXT NOT NULL,
                video_path TEXT NOT NULL,
                video_name TEXT NOT NULL,
                seq INTEGER,
                start_time TEXT NOT NULL,
                end_time TEXT NOT NULL,
                start_ms INTEGER NOT NULL,
                end_ms INTEGER NOT NULL,
                content TEXT NOT NULL
            );

            CREATE INDEX IF NOT EXISTS idx_subtitle_entries_srt_path
                ON subtitle_entries(srt_path);

            CREATE INDEX IF NOT EXISTS idx_subtitle_entries_video_path
                ON subtitle_entries(video_path);

            CREATE INDEX IF NOT EXISTS idx_subtitle_entries_start_ms
                ON subtitle_entries(start_ms);

            CREATE VIRTUAL TABLE IF NOT EXISTS subtitle_entries_fts USING fts5(
                content,
                subtitle_entry_id UNINDEXED
            );

            PRAGMA user_version = 1;
            """
        )
    }

    public func schemaVersion() throws -> Int {
        let statement = try database.prepare("PRAGMA user_version")
        guard try statement.step() else {
            return 0
        }

        return statement.intColumn(0)
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
        try database.execute("BEGIN IMMEDIATE TRANSACTION")

        do {
            try deleteEntries(forSubtitlePath: subtitleFile.path)
            try upsertSubtitleFile(
                subtitleFile: subtitleFile,
                videoFile: videoFile,
                fileSize: fileSize,
                modifiedAt: modifiedAt
            )

            for entry in entries {
                try insertEntry(
                    subtitleFile: subtitleFile,
                    videoFile: videoFile,
                    entry: entry
                )
            }

            try database.execute("COMMIT")
        } catch {
            try? database.execute("ROLLBACK")
            throw error
        }
    }

    public func entries(forSubtitleFile subtitleFile: URL) throws -> [SubtitleDatabaseEntry] {
        let statement = try database.prepare(
            """
            SELECT id, srt_path, video_path, video_name, seq, start_time, end_time, start_ms, end_ms, content
            FROM subtitle_entries
            WHERE srt_path = ?
            ORDER BY start_ms ASC, id ASC;
            """
        )

        try statement.bind(subtitleFile.path, at: 1)

        var entries: [SubtitleDatabaseEntry] = []
        while try statement.step() {
            entries.append(entry(from: statement))
        }

        return entries
    }

    public func search(_ query: String, limit: Int = 50) throws -> [SubtitleSearchResult] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty, limit > 0 else {
            return []
        }

        let statement = try database.prepare(
            """
            SELECT e.id, e.srt_path, e.video_path, e.video_name, e.start_ms, e.end_ms, e.content
            FROM subtitle_entries_fts f
            JOIN subtitle_entries e ON e.id = f.subtitle_entry_id
            WHERE subtitle_entries_fts MATCH ?
            ORDER BY bm25(subtitle_entries_fts), e.start_ms ASC, e.id ASC
            LIMIT ?;
            """
        )

        try statement.bind(trimmedQuery, at: 1)
        try statement.bind(limit, at: 2)

        var results: [SubtitleSearchResult] = []
        while try statement.step() {
            results.append(
                SubtitleSearchResult(
                    entryID: statement.int64Column(0),
                    subtitlePath: statement.stringColumn(1),
                    videoPath: statement.stringColumn(2),
                    videoName: statement.stringColumn(3),
                    startMilliseconds: statement.intColumn(4),
                    endMilliseconds: statement.intColumn(5),
                    content: statement.stringColumn(6)
                )
            )
        }

        return results
    }

    private func upsertSubtitleFile(
        subtitleFile: URL,
        videoFile: URL,
        fileSize: Int64?,
        modifiedAt: Date?
    ) throws {
        let statement = try database.prepare(
            """
            INSERT INTO subtitle_files(srt_path, video_path, video_name, file_size, modified_at, indexed_at)
            VALUES (?, ?, ?, ?, ?, ?)
            ON CONFLICT(srt_path) DO UPDATE SET
                video_path = excluded.video_path,
                video_name = excluded.video_name,
                file_size = excluded.file_size,
                modified_at = excluded.modified_at,
                indexed_at = excluded.indexed_at;
            """
        )

        try statement.bind(subtitleFile.path, at: 1)
        try statement.bind(videoFile.path, at: 2)
        try statement.bind(videoFile.lastPathComponent, at: 3)
        if let fileSize {
            try statement.bind(fileSize, at: 4)
        } else {
            try statement.bindNull(at: 4)
        }

        if let modifiedAt {
            try statement.bind(modifiedAt.timeIntervalSince1970, at: 5)
        } else {
            try statement.bindNull(at: 5)
        }

        try statement.bind(ISO8601DateFormatter().string(from: Date()), at: 6)
        try statement.run()
    }

    private func deleteEntries(forSubtitlePath subtitlePath: String) throws {
        let deleteFTS = try database.prepare(
            """
            DELETE FROM subtitle_entries_fts
            WHERE subtitle_entry_id IN (
                SELECT id FROM subtitle_entries WHERE srt_path = ?
            );
            """
        )
        try deleteFTS.bind(subtitlePath, at: 1)
        try deleteFTS.run()

        let deleteEntries = try database.prepare(
            "DELETE FROM subtitle_entries WHERE srt_path = ?;"
        )
        try deleteEntries.bind(subtitlePath, at: 1)
        try deleteEntries.run()
    }

    private func insertEntry(
        subtitleFile: URL,
        videoFile: URL,
        entry: SubtitleEntry
    ) throws {
        let insertEntry = try database.prepare(
            """
            INSERT INTO subtitle_entries(
                srt_path,
                video_path,
                video_name,
                seq,
                start_time,
                end_time,
                start_ms,
                end_ms,
                content
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
            """
        )

        try insertEntry.bind(subtitleFile.path, at: 1)
        try insertEntry.bind(videoFile.path, at: 2)
        try insertEntry.bind(videoFile.lastPathComponent, at: 3)
        if let sequenceNumber = entry.sequenceNumber {
            try insertEntry.bind(sequenceNumber, at: 4)
        } else {
            try insertEntry.bindNull(at: 4)
        }
        try insertEntry.bind(entry.startTimecode, at: 5)
        try insertEntry.bind(entry.endTimecode, at: 6)
        try insertEntry.bind(entry.startMilliseconds, at: 7)
        try insertEntry.bind(entry.endMilliseconds, at: 8)
        try insertEntry.bind(entry.text, at: 9)
        try insertEntry.run()

        let entryID = database.lastInsertRowID()
        let insertFTS = try database.prepare(
            """
            INSERT INTO subtitle_entries_fts(content, subtitle_entry_id)
            VALUES (?, ?);
            """
        )

        try insertFTS.bind(entry.text, at: 1)
        try insertFTS.bind(entryID, at: 2)
        try insertFTS.run()
    }

    private func entry(from statement: SQLiteStatement) -> SubtitleDatabaseEntry {
        SubtitleDatabaseEntry(
            id: statement.int64Column(0),
            subtitlePath: statement.stringColumn(1),
            videoPath: statement.stringColumn(2),
            videoName: statement.stringColumn(3),
            sequenceNumber: statement.nullableIntColumn(4),
            startTimecode: statement.stringColumn(5),
            endTimecode: statement.stringColumn(6),
            startMilliseconds: statement.intColumn(7),
            endMilliseconds: statement.intColumn(8),
            content: statement.stringColumn(9)
        )
    }
}

