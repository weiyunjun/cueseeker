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

public final class SubtitleDatabase {
    public static let currentSchemaVersion: Int = 6

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
        under folders: [URL]? = nil
    ) throws -> [SubtitleSearchResult] {
        guard let plan = Self.searchQueryPlan(for: query, limit: limit) else {
            return []
        }
        let offset = max(0, offset)

        let pathPrefixes: [String]?
        if let folders {
            let prefixes = Self.folderPathPrefixes(for: folders)
            guard !prefixes.isEmpty else {
                return []
            }
            pathPrefixes = prefixes
        } else {
            pathPrefixes = nil
        }

        do {
            let candidateBatchLimit = Self.searchCandidateBatchLimit(for: limit)
            var candidateOffset = 0
            var matchedOffset = 0
            var results: [SubtitleSearchResult] = []
            let scopeCondition = pathPrefixes.map {
                let conditions = $0.map { _ in "substr(sf.subtitle_path, 1, ?) = ?" }
                    .joined(separator: " OR ")
                return "AND (\(conditions))"
            } ?? ""

            while results.count < limit {
                let statement = try database.prepare(
                    """
                    SELECT g.id, sf.subtitle_path, sf.format, vf.path, vf.video_name,
                           g.start_ms, g.end_ms, g.search_content
                    FROM subtitle_cue_groups_fts f
                    JOIN subtitle_cue_groups g ON g.id = f.cue_group_id
                    JOIN subtitle_files sf ON sf.id = g.subtitle_file_id
                    JOIN subtitle_video_matches m ON m.subtitle_file_id = sf.id AND m.is_active = 1
                    JOIN video_files vf ON vf.id = m.video_file_id
                    WHERE subtitle_cue_groups_fts MATCH ?
                    \(scopeCondition)
                    ORDER BY vf.video_name ASC, g.start_ms ASC, g.id ASC
                    LIMIT ? OFFSET ?;
                    """
                )

                try statement.bind(plan.ftsQuery, at: 1)
                var bindIndex: Int32 = 2
                if let pathPrefixes {
                    for prefix in pathPrefixes {
                        try statement.bind(prefix.count, at: bindIndex)
                        bindIndex += 1
                        try statement.bind(prefix, at: bindIndex)
                        bindIndex += 1
                    }
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
                            searchContent: statement.stringColumn(7)
                        )
                    )
                }

                guard !candidates.isEmpty else {
                    break
                }

                candidateOffset += candidates.count

                for candidate in candidates {
                    let cueLines = try cueLines(forCueGroupID: candidate.cueGroupID)
                    let lineContents = cueLines.map(\.content)
                    let searchableLines = lineContents.isEmpty ? [candidate.searchContent] : lineContents

                    guard searchableLines.contains(where: { Self.line($0, matches: plan.lineMatchRule) }) else {
                        continue
                    }

                    if matchedOffset < offset {
                        matchedOffset += 1
                        continue
                    }

                    results.append(
                        SubtitleSearchResult(
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
                    )

                    if results.count == limit {
                        break
                    }
                }

                if candidates.count < candidateBatchLimit {
                    break
                }
            }

            return results
        } catch {
            return []
        }
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
        let (expanded, overflow) = limit.multipliedReportingOverflow(by: 5)
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
        let keepCondition: String
        let keepPlaceholders: String

        if subtitleFiles.isEmpty {
            keepCondition = ""
            keepPlaceholders = ""
        } else {
            keepPlaceholders = subtitleFiles.map { _ in "?" }.joined(separator: ", ")
            keepCondition = "AND sf.subtitle_path NOT IN (\(keepPlaceholders))"
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
                search_content
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?);
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
