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

public struct SubtitleFileMetadata: Equatable, Sendable {
    public let subtitlePath: String
    public let videoPath: String?
    public let videoName: String?
    public let fileSize: Int64?
    public let modifiedAt: Date?
    public let indexedAt: String
}

public final class SubtitleDatabase {
    public static let currentSchemaVersion: Int = 2

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
            """
        )

        if previousVersion < 2 {
            try rebuildFTSIndexForSearchAlgorithm()
        }

        try database.execute("PRAGMA user_version = \(Self.currentSchemaVersion);")
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

    public func subtitleFiles() throws -> [SubtitleFileMetadata] {
        let statement = try database.prepare(
            """
            SELECT srt_path, video_path, video_name, file_size, modified_at, indexed_at
            FROM subtitle_files
            ORDER BY srt_path ASC;
            """
        )

        var files: [SubtitleFileMetadata] = []
        while try statement.step() {
            files.append(
                SubtitleFileMetadata(
                    subtitlePath: statement.stringColumn(0),
                    videoPath: statement.nullableStringColumn(1),
                    videoName: statement.nullableStringColumn(2),
                    fileSize: statement.nullableInt64Column(3),
                    modifiedAt: statement.nullableDoubleColumn(4).map(Date.init(timeIntervalSince1970:)),
                    indexedAt: statement.stringColumn(5)
                )
            )
        }

        return files
    }

    public func search(_ query: String, limit: Int = 50) throws -> [SubtitleSearchResult] {
        guard let plan = Self.searchQueryPlan(for: query, limit: limit) else {
            return []
        }

        do {
            let statement = try database.prepare(
                """
                SELECT e.id, e.srt_path, e.video_path, e.video_name, e.start_ms, e.end_ms, e.content
                FROM subtitle_entries_fts f
                JOIN subtitle_entries e ON e.id = f.subtitle_entry_id
                WHERE subtitle_entries_fts MATCH ?
                ORDER BY e.video_name ASC, e.start_ms ASC, e.id ASC
                LIMIT ?;
                """
            )

            try statement.bind(plan.ftsQuery, at: 1)
            try statement.bind(plan.sqlLimit, at: 2)

            var results: [SubtitleSearchResult] = []
            while try statement.step() {
                let result = SubtitleSearchResult(
                    entryID: statement.int64Column(0),
                    subtitlePath: statement.stringColumn(1),
                    videoPath: statement.stringColumn(2),
                    videoName: statement.stringColumn(3),
                    startMilliseconds: statement.intColumn(4),
                    endMilliseconds: statement.intColumn(5),
                    content: statement.stringColumn(6)
                )

                if let orderedTokens = plan.orderedLatinTokens,
                   !Self.matchesOrderedWholeTokens(result.content, queryTokens: orderedTokens) {
                    continue
                }

                results.append(result)
                if results.count == limit {
                    break
                }
            }

            return results
        } catch {
            return []
        }
    }

    private struct SearchQueryPlan {
        let ftsQuery: String
        let sqlLimit: Int
        let orderedLatinTokens: [String]?
    }

    private static func searchQueryPlan(for query: String, limit: Int) -> SearchQueryPlan? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, limit > 0 else {
            return nil
        }

        let hasExplicitPhrase = trimmed.count >= 2 && trimmed.first == "\"" && trimmed.last == "\""
        let hasFTSSyntax = hasExplicitPhrase || trimmed.contains("*") || containsFTSOperator(in: trimmed)
        let hasCJK = containsFlutterCJK(in: trimmed)
        let queryTokens = hasCJK ? [] : tokenizeLatinTokens(trimmed)
        let useOrderedTokenFilter = !hasFTSSyntax && !hasCJK && queryTokens.count > 1

        if !hasFTSSyntax && !hasCJK && queryTokens.isEmpty {
            return nil
        }

        let ftsQuery: String
        if hasFTSSyntax {
            ftsQuery = trimmed
        } else if hasCJK {
            ftsQuery = "\"\(escapeFTSPhrase(segmentCJK(trimmed).trimmingCharacters(in: .whitespacesAndNewlines)))\""
        } else if queryTokens.count > 1 {
            ftsQuery = queryTokens.joined(separator: " AND ")
        } else {
            ftsQuery = "\(queryTokens[0])*"
        }

        let sqlLimit = useOrderedTokenFilter ? expandedSQLLimit(for: limit) : limit
        return SearchQueryPlan(
            ftsQuery: ftsQuery,
            sqlLimit: sqlLimit,
            orderedLatinTokens: useOrderedTokenFilter ? queryTokens : nil
        )
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
            if isFlutterCJK(scalar) {
                segmented.append(" ")
            }
        }
        return segmented
    }

    private static func containsFlutterCJK(in text: String) -> Bool {
        text.unicodeScalars.contains(where: isFlutterCJK)
    }

    private static func isFlutterCJK(_ scalar: UnicodeScalar) -> Bool {
        (0x4E00...0x9FA5).contains(Int(scalar.value))
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
        let (expanded, overflow) = limit.multipliedReportingOverflow(by: 5)
        if overflow {
            return Int(Int32.max)
        }

        return min(expanded, Int(Int32.max))
    }

    private static func isASCIIWordCharacter(_ character: Character) -> Bool {
        isASCIILetterOrDigit(character) || character == "_"
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

    private func removeIndexedData(
        under folder: URL,
        keeping subtitleFiles: Set<String>,
        removeSearchPath: Bool
    ) throws {
        let folderPathPrefixes = Self.folderPathPrefixes(for: folder)
        let prefixCondition = folderPathPrefixes
            .map { _ in "substr(srt_path, 1, ?) = ?" }
            .joined(separator: " OR ")
        let keepCondition: String
        let keepPlaceholders: String

        if subtitleFiles.isEmpty {
            keepCondition = ""
            keepPlaceholders = ""
        } else {
            keepPlaceholders = subtitleFiles.map { _ in "?" }.joined(separator: ", ")
            keepCondition = "AND srt_path NOT IN (\(keepPlaceholders))"
        }

        try database.execute("BEGIN IMMEDIATE TRANSACTION")
        do {
            let deleteFTS = try database.prepare(
                """
                DELETE FROM subtitle_entries_fts
                WHERE subtitle_entry_id IN (
                    SELECT id FROM subtitle_entries
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

            let deleteEntries = try database.prepare(
                """
                DELETE FROM subtitle_entries
                WHERE (\(prefixCondition)) \(keepCondition);
                """
            )
            try bindStaleEntryParameters(
                statement: deleteEntries,
                folderPathPrefixes: folderPathPrefixes,
                subtitleFiles: subtitleFiles
            )
            try deleteEntries.run()

            let deleteFiles = try database.prepare(
                """
                DELETE FROM subtitle_files
                WHERE (\(prefixCondition)) \(keepCondition);
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

            try database.execute("COMMIT")
        } catch {
            try? database.execute("ROLLBACK")
            throw error
        }
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

        try insertFTS.bind(Self.segmentCJK(entry.text), at: 1)
        try insertFTS.bind(entryID, at: 2)
        try insertFTS.run()
    }

    private func rebuildFTSIndexForSearchAlgorithm() throws {
        try database.execute("BEGIN IMMEDIATE TRANSACTION")

        do {
            try database.execute("DELETE FROM subtitle_entries_fts;")

            let selectEntries = try database.prepare(
                """
                SELECT id, content
                FROM subtitle_entries
                ORDER BY id ASC;
                """
            )

            while try selectEntries.step() {
                let insertFTS = try database.prepare(
                    """
                    INSERT INTO subtitle_entries_fts(content, subtitle_entry_id)
                    VALUES (?, ?);
                    """
                )
                try insertFTS.bind(Self.segmentCJK(selectEntries.stringColumn(1)), at: 1)
                try insertFTS.bind(selectEntries.int64Column(0), at: 2)
                try insertFTS.run()
            }

            try database.execute("COMMIT")
        } catch {
            try? database.execute("ROLLBACK")
            throw error
        }
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

    private static func folderPathPrefixes(for folder: URL) -> [String] {
        var path = folder.standardizedFileURL.path
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

    private static func folderPathVariants(for folder: URL) -> [String] {
        let path = folder.standardizedFileURL.path
        var paths = Set([path])

        if path.hasPrefix("/var/") {
            paths.insert("/private" + path)
        } else if path.hasPrefix("/private/var/") {
            paths.insert(String(path.dropFirst("/private".count)))
        }

        return paths.sorted()
    }
}
