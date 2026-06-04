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

    public init(
        subtitlePath: String,
        subtitleFileName: String,
        subtitleDisplayTitle: String,
        matchCount: Int
    ) {
        self.subtitlePath = subtitlePath
        self.subtitleFileName = subtitleFileName
        self.subtitleDisplayTitle = subtitleDisplayTitle
        self.matchCount = matchCount
    }
}

public struct SubtitleSearchCursor: Equatable, Sendable, Codable {
    public static let start = SubtitleSearchCursor(offset: 0)

    public let offset: Int

    public init(offset: Int) {
        self.offset = max(0, offset)
    }
}

public enum SubtitleSearchCountState: String, Equatable, Sendable, Codable {
    case exact
    case exactProgress
}

public struct SubtitleSearchCountSnapshot: Equatable, Sendable, Codable {
    public let state: SubtitleSearchCountState
    public let knownResultCount: Int
    public let knownFileCount: Int
    public let exactTotalCount: Int?
    public let exactFileSummaryCount: Int?

    public static func exact(totalCount: Int, fileSummaryCount: Int) -> SubtitleSearchCountSnapshot {
        let resolvedTotalCount = max(0, totalCount)
        let resolvedFileSummaryCount = max(0, fileSummaryCount)
        return SubtitleSearchCountSnapshot(
            state: .exact,
            knownResultCount: resolvedTotalCount,
            knownFileCount: resolvedFileSummaryCount,
            exactTotalCount: resolvedTotalCount,
            exactFileSummaryCount: resolvedFileSummaryCount
        )
    }

    public static func exactProgress(knownResultCount: Int, knownFileCount: Int) -> SubtitleSearchCountSnapshot {
        SubtitleSearchCountSnapshot(
            state: .exactProgress,
            knownResultCount: max(0, knownResultCount),
            knownFileCount: max(0, knownFileCount),
            exactTotalCount: nil,
            exactFileSummaryCount: nil
        )
    }
}

public struct SubtitleSearchProgressSnapshot: Equatable, Sendable {
    public let countSnapshot: SubtitleSearchCountSnapshot
    public let fileSummaries: [SubtitleSearchFileSummary]

    public var countState: SubtitleSearchCountState {
        countSnapshot.state
    }

    public var knownResultCount: Int {
        countSnapshot.knownResultCount
    }

    public var knownFileCount: Int {
        countSnapshot.knownFileCount
    }

    public init(
        countSnapshot: SubtitleSearchCountSnapshot,
        fileSummaries: [SubtitleSearchFileSummary]
    ) {
        self.countSnapshot = countSnapshot
        self.fileSummaries = fileSummaries
    }
}

public typealias SubtitleSearchProgressSink = @Sendable (SubtitleSearchProgressSnapshot) -> Void

public enum SubtitleSearchPageMode: String, Equatable, Sendable, Codable {
    case exact
    case visibleWindow
}

public struct SubtitleSearchResultCacheStats: Equatable, Sendable {
    public let entries: Int
    public let hits: Int
    public let misses: Int
    public let stores: Int
    public let invalidations: Int
}

public struct AIChunkCacheKey: Equatable, Hashable, Sendable {
    public let normalizedSentence: String
    public let provider: String
    public let model: String
    public let promptVersion: String

    public init(
        normalizedSentence: String,
        provider: String,
        model: String,
        promptVersion: String
    ) {
        self.normalizedSentence = normalizedSentence
        self.provider = provider
        self.model = model
        self.promptVersion = promptVersion
    }
}

public enum AIChunkDisplayGroup: String, Codable, Sendable {
    case primary
    case additional
}

public struct AIChunkItem: Codable, Equatable, Sendable {
    public let item: String
    public let translation: String
    public let displayGroup: AIChunkDisplayGroup

    public init(
        item: String,
        translation: String,
        displayGroup: AIChunkDisplayGroup = .primary
    ) {
        self.item = item
        self.translation = translation
        self.displayGroup = displayGroup
    }

    private enum CodingKeys: String, CodingKey {
        case item
        case translation
        case displayGroup
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        item = try container.decode(String.self, forKey: .item)
        translation = try container.decode(String.self, forKey: .translation)
        displayGroup = try container.decodeIfPresent(AIChunkDisplayGroup.self, forKey: .displayGroup) ?? .primary
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(item, forKey: .item)
        try container.encode(translation, forKey: .translation)
        try container.encode(displayGroup, forKey: .displayGroup)
    }
}

public struct AIChunkCacheEntry: Equatable, Sendable {
    public let key: AIChunkCacheKey
    public let chunks: [AIChunkItem]
    public let cacheDate: String
}

public enum AIChunkCacheError: Error, Equatable {
    case emptyNormalizedSentence
    case emptyProvider
    case emptyModel
    case emptyPromptVersion
    case emptyChunks
}

public struct SubtitleFTSVocabularyTermDiagnostic: Equatable, Sendable {
    public let term: String
    public let documentCount: Int
    public let occurrenceCount: Int
}

public struct SubtitleFTSVocabularyDiagnostics: Equatable, Sendable {
    public let uniqueTermCount: Int
    public let totalDocumentReferences: Int
    public let totalOccurrences: Int
    public let mostFrequentTerms: [SubtitleFTSVocabularyTermDiagnostic]
    public let queryTerms: [SubtitleFTSVocabularyTermDiagnostic]
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

public enum PlaybackNavigationEntryKind: String, Equatable, Sendable, Codable {
    case library
    case search
    case shiori
}

public struct PlaybackNavigationLibraryPayload: Equatable, Sendable, Codable {
    public let videoPath: String

    public init(videoPath: String) {
        self.videoPath = videoPath
    }
}

public struct PlaybackNavigationSearchPayload: Equatable, Sendable, Codable {
    public let query: String
    public let scopePaths: [String]
    public let entryID: Int64?
    public let subtitlePath: String?
    public let videoPath: String?
    public let startMilliseconds: Int?
    public let endMilliseconds: Int?
    public let indexRevision: Int64

    public init(
        query: String,
        scopePaths: [String],
        entryID: Int64?,
        subtitlePath: String?,
        videoPath: String?,
        startMilliseconds: Int?,
        endMilliseconds: Int?,
        indexRevision: Int64
    ) {
        self.query = query
        self.scopePaths = scopePaths
        self.entryID = entryID
        self.subtitlePath = subtitlePath
        self.videoPath = videoPath
        self.startMilliseconds = startMilliseconds
        self.endMilliseconds = endMilliseconds
        self.indexRevision = indexRevision
    }
}

public struct PlaybackNavigationShioriPayload: Equatable, Sendable, Codable {
    public let id: Int64
    public let subtitlePath: String
    public let startMilliseconds: Int
    public let endMilliseconds: Int

    public init(
        id: Int64,
        subtitlePath: String,
        startMilliseconds: Int,
        endMilliseconds: Int
    ) {
        self.id = id
        self.subtitlePath = subtitlePath
        self.startMilliseconds = startMilliseconds
        self.endMilliseconds = endMilliseconds
    }
}

public enum PlaybackNavigationPayload: Equatable, Sendable, Codable {
    case library(PlaybackNavigationLibraryPayload)
    case search(PlaybackNavigationSearchPayload)
    case shiori(PlaybackNavigationShioriPayload)

    public var kind: PlaybackNavigationEntryKind {
        switch self {
        case .library:
            .library
        case .search:
            .search
        case .shiori:
            .shiori
        }
    }
}

public struct PlaybackNavigationEntry: Equatable, Sendable {
    public let id: Int64
    public let payload: PlaybackNavigationPayload
    public let createdAt: String
    public let updatedAt: String

    public var kind: PlaybackNavigationEntryKind {
        payload.kind
    }
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
    public let countSnapshot: SubtitleSearchCountSnapshot
    public let appliedCursor: SubtitleSearchCursor
    public let nextCursor: SubtitleSearchCursor?
    public let pageMode: SubtitleSearchPageMode
    public let orderSource: String?
    public let materializedOrderRows: Int?

    public var hasMore: Bool {
        nextCursor != nil
    }

    public var countState: SubtitleSearchCountState {
        countSnapshot.state
    }

    public var knownResultCount: Int {
        countSnapshot.knownResultCount
    }

    public var knownFileCount: Int {
        countSnapshot.knownFileCount
    }

    public var exactTotalCount: Int? {
        countSnapshot.exactTotalCount
    }

    public var exactFileSummaryCount: Int? {
        countSnapshot.exactFileSummaryCount
    }

    public init(
        results: [SubtitleSearchResult],
        totalCount: Int,
        fileSummaries: [SubtitleSearchFileSummary],
        countSnapshot: SubtitleSearchCountSnapshot? = nil,
        appliedCursor: SubtitleSearchCursor = .start,
        nextCursor: SubtitleSearchCursor? = nil,
        pageMode: SubtitleSearchPageMode = .exact,
        orderSource: String? = nil,
        materializedOrderRows: Int? = nil
    ) {
        self.results = results
        self.totalCount = totalCount
        self.fileSummaries = fileSummaries
        self.countSnapshot = countSnapshot ?? .exact(
            totalCount: totalCount,
            fileSummaryCount: fileSummaries.count
        )
        self.appliedCursor = appliedCursor
        self.nextCursor = nextCursor
        self.pageMode = pageMode
        self.orderSource = orderSource
        self.materializedOrderRows = materializedOrderRows
    }
}

private struct SearchResultCacheKey: Hashable, Sendable {
    let query: String
    let limit: Int
    let offset: Int
    let mode: SubtitleSearchPageMode
    let pathPrefixes: [String]?
    let subtitlePath: String?
}

private final class SearchResultPageCache: @unchecked Sendable {
    private let maxEntries: Int
    private let lock = NSLock()
    private var pages: [SearchResultCacheKey: SubtitleSearchPage] = [:]
    private var keys: [SearchResultCacheKey] = []
    private var hits = 0
    private var misses = 0
    private var stores = 0
    private var invalidations = 0

    init(maxEntries: Int) {
        self.maxEntries = max(1, maxEntries)
    }

    func page(for key: SearchResultCacheKey) -> SubtitleSearchPage? {
        lock.lock()
        defer { lock.unlock() }

        guard let page = pages[key] else {
            misses += 1
            return nil
        }

        hits += 1
        if let index = keys.firstIndex(of: key) {
            keys.remove(at: index)
        }
        keys.append(key)
        return page
    }

    func store(_ page: SubtitleSearchPage, for key: SearchResultCacheKey) {
        lock.lock()
        defer { lock.unlock() }

        if pages[key] == nil {
            keys.append(key)
        } else if let index = keys.firstIndex(of: key) {
            keys.remove(at: index)
            keys.append(key)
        }

        pages[key] = page
        stores += 1

        while keys.count > maxEntries, let first = keys.first {
            keys.removeFirst()
            pages.removeValue(forKey: first)
        }
    }

    func removeAll() {
        lock.lock()
        defer { lock.unlock() }

        if !pages.isEmpty {
            invalidations += 1
        }
        pages.removeAll()
        keys.removeAll()
    }

    func stats() -> SubtitleSearchResultCacheStats {
        lock.lock()
        defer { lock.unlock() }

        return SubtitleSearchResultCacheStats(
            entries: pages.count,
            hits: hits,
            misses: misses,
            stores: stores,
            invalidations: invalidations
        )
    }
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

public enum SubtitleLanguageDetectionScope: String, Equatable, Sendable {
    case file
    case style
}

public struct StoredSubtitleLanguageDetection: Equatable, Sendable {
    public let subtitlePath: String
    public let scope: SubtitleLanguageDetectionScope
    public let scopeKey: String?
    public let algorithmVersion: Int
    public let confidence: Double
    public let confidenceBand: SubtitleLanguageConfidenceBand
    public let segmentCount: Int
    public let effectiveCharacterCount: Int
    public let languages: Set<SubtitleLanguageCode>
    public let distribution: [SubtitleLanguageDistribution]
    public let detectedAt: String
}

public struct ASSRenderSegment: Equatable, Sendable {
    public let subtitlePath: String
    public let startMilliseconds: Int
    public let endMilliseconds: Int
    public let scriptText: String
    public let eventCount: Int
    public let byteCount: Int
}

public struct ASSFontReference: Equatable, Sendable {
    public let subtitlePath: String
    public let fontName: String
    public let source: ASSFontReferenceSource
    public let occurrenceCount: Int
    public let firstOccurrenceOrder: Int

    public init(
        subtitlePath: String,
        fontName: String,
        source: ASSFontReferenceSource,
        occurrenceCount: Int,
        firstOccurrenceOrder: Int
    ) {
        self.subtitlePath = subtitlePath
        self.fontName = fontName
        self.source = source
        self.occurrenceCount = occurrenceCount
        self.firstOccurrenceOrder = firstOccurrenceOrder
    }
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

public struct DatabaseStorageStats: Equatable, Sendable {
    public let databaseFileBytes: Int64
    public let walFileBytes: Int64
    public let shmFileBytes: Int64
    public let pageSize: Int
    public let pageCount: Int
    public let freelistCount: Int
    public let autoVacuumMode: Int

    public var allocatedBytes: Int64 {
        Int64(pageSize) * Int64(pageCount)
    }

    public var freelistBytes: Int64 {
        Int64(pageSize) * Int64(freelistCount)
    }

    public var usedBytesEstimate: Int64 {
        Int64(pageSize) * Int64(max(0, pageCount - freelistCount))
    }

    public var freelistRatio: Double {
        guard pageCount > 0 else {
            return 0
        }

        return Double(freelistCount) / Double(pageCount)
    }
}

public final class SubtitleDatabase: @unchecked Sendable {
    public static let currentSchemaVersion: Int = 17
    public static let configuredBusyTimeoutMilliseconds: Int = 5_000
    public static let configuredCacheSizeKibibytes: Int = SQLiteDatabase.cacheSizeKibibytes
    public static let configuredMmapSizeBytes: Int = SQLiteDatabase.mmapSizeBytes
    private static let exactSearchCandidateBatchMinimum = 5_000
    private static let maxSearchResultCacheEntries = 64
    private static let maxCachedSearchPageLimit = 500

    private let path: URL
    private let database: SQLiteDatabase
    private let searchResultCache = SearchResultPageCache(maxEntries: maxSearchResultCacheEntries)

    public init(path: URL) throws {
        self.path = path
        database = try SQLiteDatabase(path: path)
    }

    public func cueGroupOccurrenceCount(
        for query: String,
        under folders: [URL]? = nil
    ) throws -> Int {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            return 0
        }

        return try searchPage(
            trimmedQuery,
            limit: 1,
            cursor: .start,
            under: folders,
            mode: .exact
        ).totalCount
    }

    public func clearSearchResultCache() {
        searchResultCache.removeAll()
    }

    public func searchResultCacheStats() -> SubtitleSearchResultCacheStats {
        searchResultCache.stats()
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

            CREATE TABLE IF NOT EXISTS subtitle_search_order_rows (
                subtitle_path TEXT PRIMARY KEY,
                folder_path TEXT NOT NULL,
                folder_title TEXT NOT NULL,
                subtitle_file_name TEXT NOT NULL,
                display_title TEXT NOT NULL,
                folder_order INTEGER NOT NULL,
                file_order INTEGER NOT NULL,
                updated_at TEXT NOT NULL
            );

            CREATE INDEX IF NOT EXISTS idx_subtitle_search_order_rows_order
                ON subtitle_search_order_rows(folder_order, file_order, subtitle_path);

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

            CREATE TABLE IF NOT EXISTS playback_navigation_entries (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                kind TEXT NOT NULL,
                payload_json TEXT NOT NULL,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
            );

            CREATE INDEX IF NOT EXISTS idx_playback_navigation_entries_order
                ON playback_navigation_entries(id);

            CREATE TABLE IF NOT EXISTS playback_navigation_state (
                id INTEGER PRIMARY KEY CHECK(id = 1),
                current_entry_id INTEGER,
                index_revision INTEGER NOT NULL DEFAULT 0,
                updated_at TEXT NOT NULL,
                FOREIGN KEY(current_entry_id)
                    REFERENCES playback_navigation_entries(id)
                    ON DELETE SET NULL
            );
            """
        )
        try ensurePlaybackNavigationStateRow()

        if previousVersion >= 4 && previousVersion < 5 {
            try database.execute(
                """
                ALTER TABLE ass_render_segments
                ADD COLUMN algorithm_version INTEGER NOT NULL DEFAULT 0;
                """
            )
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

        if previousVersion < 12 {
            try rebuildSearchOrderRows()
        }

        if previousVersion < 13 {
            try rebuildFTSRows()
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

    public func storageStats() throws -> DatabaseStorageStats {
        DatabaseStorageStats(
            databaseFileBytes: Self.fileSize(at: path),
            walFileBytes: Self.fileSize(at: Self.sidecarPath(suffix: "-wal", for: path)),
            shmFileBytes: Self.fileSize(at: Self.sidecarPath(suffix: "-shm", for: path)),
            pageSize: try database.intPragma("page_size"),
            pageCount: try database.intPragma("page_count"),
            freelistCount: try database.intPragma("freelist_count"),
            autoVacuumMode: try database.intPragma("auto_vacuum")
        )
    }

    public func compactStorage() throws {
        try database.execute("PRAGMA wal_checkpoint(TRUNCATE);")
        try database.execute("VACUUM;")
        try database.execute("PRAGMA wal_checkpoint(TRUNCATE);")
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

    public func aiChunkCacheEntry(for key: AIChunkCacheKey) throws -> AIChunkCacheEntry? {
        try Self.validateAIChunkCacheKey(key)

        let statement = try database.prepare(
            """
            SELECT normalized_sentence, provider, model, prompt_version, chunks_json, cache_date
            FROM ai_chunk_cache_entries
            WHERE normalized_sentence = ?
              AND provider = ?
              AND model = ?
              AND prompt_version = ?
            LIMIT 1;
            """
        )

        try statement.bind(key.normalizedSentence, at: 1)
        try statement.bind(key.provider, at: 2)
        try statement.bind(key.model, at: 3)
        try statement.bind(key.promptVersion, at: 4)

        guard try statement.step() else {
            return nil
        }

        return try aiChunkCacheEntry(from: statement)
    }

    @discardableResult
    public func upsertAIChunkCacheEntry(
        key: AIChunkCacheKey,
        chunks: [AIChunkItem],
        cacheDate: String = ISO8601DateFormatter().string(from: Date())
    ) throws -> AIChunkCacheEntry {
        try Self.validateAIChunkCacheKey(key)
        try Self.validateAIChunkCacheChunks(chunks)

        let chunksJSON = try Self.encodeAIChunks(chunks)
        let statement = try database.prepare(
            """
            INSERT INTO ai_chunk_cache_entries(
                normalized_sentence,
                provider,
                model,
                prompt_version,
                chunks_json,
                cache_date
            )
            VALUES (?, ?, ?, ?, ?, ?)
            ON CONFLICT(normalized_sentence, provider, model, prompt_version)
            DO UPDATE SET chunks_json = excluded.chunks_json
            RETURNING normalized_sentence, provider, model, prompt_version, chunks_json, cache_date;
            """
        )

        try statement.bind(key.normalizedSentence, at: 1)
        try statement.bind(key.provider, at: 2)
        try statement.bind(key.model, at: 3)
        try statement.bind(key.promptVersion, at: 4)
        try statement.bind(chunksJSON, at: 5)
        try statement.bind(cacheDate, at: 6)

        guard try statement.step() else {
            throw SQLiteDatabaseError.stepFailed("AI chunk cache entry could not be saved")
        }

        return try aiChunkCacheEntry(from: statement)
    }

    public func clearAIChunkCacheEntries() throws {
        try database.execute("DELETE FROM ai_chunk_cache_entries;")
    }

    public func playbackNavigationIndexRevision() throws -> Int64 {
        let statement = try database.prepare(
            """
            SELECT index_revision
            FROM playback_navigation_state
            WHERE id = 1;
            """
        )

        guard try statement.step() else {
            return 0
        }

        return max(0, statement.int64Column(0))
    }

    public func playbackNavigationCurrentEntryID() throws -> Int64? {
        let statement = try database.prepare(
            """
            SELECT current_entry_id
            FROM playback_navigation_state
            WHERE id = 1;
            """
        )

        guard try statement.step() else {
            return nil
        }

        return statement.nullableInt64Column(0)
    }

    public func setPlaybackNavigationCurrentEntryID(_ entryID: Int64?) throws {
        let statement = try database.prepare(
            """
            UPDATE playback_navigation_state
            SET current_entry_id = ?, updated_at = ?
            WHERE id = 1;
            """
        )

        if let entryID {
            try statement.bind(entryID, at: 1)
        } else {
            try statement.bindNull(at: 1)
        }
        try statement.bind(ISO8601DateFormatter().string(from: Date()), at: 2)
        try statement.run()
    }

    @discardableResult
    public func appendPlaybackNavigationEntry(
        _ payload: PlaybackNavigationPayload
    ) throws -> PlaybackNavigationEntry {
        let now = ISO8601DateFormatter().string(from: Date())
        let statement = try database.prepare(
            """
            INSERT INTO playback_navigation_entries(kind, payload_json, created_at, updated_at)
            VALUES (?, ?, ?, ?);
            """
        )

        try statement.bind(payload.kind.rawValue, at: 1)
        try statement.bind(try Self.encodePlaybackNavigationPayload(payload), at: 2)
        try statement.bind(now, at: 3)
        try statement.bind(now, at: 4)
        try statement.run()

        let id = database.lastInsertRowID()
        return PlaybackNavigationEntry(
            id: id,
            payload: payload,
            createdAt: now,
            updatedAt: now
        )
    }

    @discardableResult
    public func updatePlaybackNavigationEntry(
        id: Int64,
        payload: PlaybackNavigationPayload
    ) throws -> PlaybackNavigationEntry? {
        let now = ISO8601DateFormatter().string(from: Date())
        let statement = try database.prepare(
            """
            UPDATE playback_navigation_entries
            SET kind = ?, payload_json = ?, updated_at = ?
            WHERE id = ?;
            """
        )

        try statement.bind(payload.kind.rawValue, at: 1)
        try statement.bind(try Self.encodePlaybackNavigationPayload(payload), at: 2)
        try statement.bind(now, at: 3)
        try statement.bind(id, at: 4)
        try statement.run()

        return try playbackNavigationEntry(id: id)
    }

    public func playbackNavigationEntry(id: Int64) throws -> PlaybackNavigationEntry? {
        let statement = try database.prepare(
            """
            SELECT id, kind, payload_json, created_at, updated_at
            FROM playback_navigation_entries
            WHERE id = ?;
            """
        )

        try statement.bind(id, at: 1)
        guard try statement.step() else {
            return nil
        }

        return try Self.playbackNavigationEntry(from: statement)
    }

    public func playbackNavigationEntries(limit: Int? = nil) throws -> [PlaybackNavigationEntry] {
        let boundedLimit = limit.map { max(0, $0) }
        let sql: String
        if boundedLimit != nil {
            sql = """
                SELECT id, kind, payload_json, created_at, updated_at
                FROM playback_navigation_entries
                ORDER BY id ASC
                LIMIT ?;
                """
        } else {
            sql = """
                SELECT id, kind, payload_json, created_at, updated_at
                FROM playback_navigation_entries
                ORDER BY id ASC;
                """
        }

        let statement = try database.prepare(sql)
        if let boundedLimit {
            try statement.bind(boundedLimit, at: 1)
        }

        var entries: [PlaybackNavigationEntry] = []
        while try statement.step() {
            entries.append(try Self.playbackNavigationEntry(from: statement))
        }
        return entries
    }

    public func deletePlaybackNavigationEntries(after entryID: Int64) throws {
        let statement = try database.prepare(
            """
            DELETE FROM playback_navigation_entries
            WHERE id > ?;
            """
        )
        try statement.bind(entryID, at: 1)
        try statement.run()
    }

    public func prunePlaybackNavigationEntries(keepingLatest count: Int) throws {
        let boundedCount = max(0, count)
        let statement = try database.prepare(
            """
            DELETE FROM playback_navigation_entries
            WHERE id NOT IN (
                SELECT id
                FROM playback_navigation_entries
                ORDER BY id DESC
                LIMIT ?
            );
            """
        )
        try statement.bind(boundedCount, at: 1)
        try statement.run()
    }

    private func ensurePlaybackNavigationStateRow() throws {
        let statement = try database.prepare(
            """
            INSERT OR IGNORE INTO playback_navigation_state(
                id,
                current_entry_id,
                index_revision,
                updated_at
            )
            VALUES (1, NULL, 0, ?);
            """
        )
        try statement.bind(ISO8601DateFormatter().string(from: Date()), at: 1)
        try statement.run()
    }

    private func bumpPlaybackNavigationIndexRevisionInCurrentTransaction() throws {
        let statement = try database.prepare(
            """
            UPDATE playback_navigation_state
            SET index_revision = index_revision + 1,
                updated_at = ?
            WHERE id = 1;
            """
        )
        try statement.bind(ISO8601DateFormatter().string(from: Date()), at: 1)
        try statement.run()
    }

    private static func playbackNavigationEntry(
        from statement: SQLiteStatement
    ) throws -> PlaybackNavigationEntry {
        let kind = statement.stringColumn(1)
        let payload = try decodePlaybackNavigationPayload(from: statement.stringColumn(2))
        guard payload.kind.rawValue == kind else {
            throw SQLiteDatabaseError.stepFailed(
                "Playback navigation entry kind does not match payload."
            )
        }

        return PlaybackNavigationEntry(
            id: statement.int64Column(0),
            payload: payload,
            createdAt: statement.stringColumn(3),
            updatedAt: statement.stringColumn(4)
        )
    }

    private static func encodePlaybackNavigationPayload(
        _ payload: PlaybackNavigationPayload
    ) throws -> String {
        String(decoding: try JSONEncoder().encode(payload), as: UTF8.self)
    }

    private static func decodePlaybackNavigationPayload(
        from json: String
    ) throws -> PlaybackNavigationPayload {
        guard let data = json.data(using: .utf8) else {
            throw SQLiteDatabaseError.stepFailed(
                "Playback navigation payload contains invalid UTF-8."
            )
        }
        return try JSONDecoder().decode(PlaybackNavigationPayload.self, from: data)
    }

    public func replaceEntries(
        subtitleFile: URL,
        videoFile: URL,
        entries: [SubtitleEntry],
        fileSize: Int64? = nil,
        modifiedAt: Date? = nil
    ) throws {
        try replaceCueGroupsPersistingLanguageAnalysis(
            subtitleFile: subtitleFile,
            videoFile: videoFile,
            format: .srt,
            cueGroups: entries.enumerated().map { index, entry in
                entry.cueGroup(eventIndex: index)
            },
            fileSize: fileSize,
            modifiedAt: modifiedAt,
            languageAnalysis: nil
        )
    }

    public func replaceEntries(
        subtitleFile: URL,
        videoFile: URL,
        entries: [SubtitleEntry],
        fileSize: Int64? = nil,
        modifiedAt: Date? = nil,
        languageAnalysis: SubtitleLanguageAnalysis
    ) throws {
        try replaceCueGroupsPersistingLanguageAnalysis(
            subtitleFile: subtitleFile,
            videoFile: videoFile,
            format: .srt,
            cueGroups: entries.enumerated().map { index, entry in
                entry.cueGroup(eventIndex: index)
            },
            fileSize: fileSize,
            modifiedAt: modifiedAt,
            languageAnalysis: languageAnalysis
        )
    }

    public func replaceCueGroups(
        subtitleFile: URL,
        videoFile: URL,
        format: SubtitleFormat,
        cueGroups: [SubtitleCueGroup],
        assRenderSegments: [ASSRenderSegmentPayload] = [],
        assFontReferences: [ASSFontReferenceIntent] = [],
        fileSize: Int64? = nil,
        modifiedAt: Date? = nil,
        rebuildSearchDerivedIndex: Bool = true
    ) throws {
        try replaceCueGroupsPersistingLanguageAnalysis(
            subtitleFile: subtitleFile,
            videoFile: videoFile,
            format: format,
            cueGroups: cueGroups,
            assRenderSegments: assRenderSegments,
            assFontReferences: assFontReferences,
            fileSize: fileSize,
            modifiedAt: modifiedAt,
            languageAnalysis: nil,
            rebuildSearchDerivedIndex: rebuildSearchDerivedIndex
        )
    }

    public func replaceCueGroups(
        subtitleFile: URL,
        videoFile: URL,
        format: SubtitleFormat,
        cueGroups: [SubtitleCueGroup],
        assRenderSegments: [ASSRenderSegmentPayload] = [],
        assFontReferences: [ASSFontReferenceIntent] = [],
        fileSize: Int64? = nil,
        modifiedAt: Date? = nil,
        languageAnalysis: SubtitleLanguageAnalysis,
        rebuildSearchDerivedIndex: Bool = true
    ) throws {
        try replaceCueGroupsPersistingLanguageAnalysis(
            subtitleFile: subtitleFile,
            videoFile: videoFile,
            format: format,
            cueGroups: cueGroups,
            assRenderSegments: assRenderSegments,
            assFontReferences: assFontReferences,
            fileSize: fileSize,
            modifiedAt: modifiedAt,
            languageAnalysis: languageAnalysis,
            rebuildSearchDerivedIndex: rebuildSearchDerivedIndex
        )
    }

    private func replaceCueGroupsPersistingLanguageAnalysis(
        subtitleFile: URL,
        videoFile: URL,
        format: SubtitleFormat,
        cueGroups: [SubtitleCueGroup],
        assRenderSegments: [ASSRenderSegmentPayload] = [],
        assFontReferences: [ASSFontReferenceIntent] = [],
        fileSize: Int64? = nil,
        modifiedAt: Date? = nil,
        languageAnalysis: SubtitleLanguageAnalysis?,
        rebuildSearchDerivedIndex: Bool = true
    ) throws {
        try validateLanguageAnalysis(languageAnalysis, format: format, cueGroupCount: cueGroups.count)
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

            if format == .ass {
                try insertASSFontReferenceManifest(
                    subtitleFileID: subtitleFileID,
                    referencedFontCount: assFontReferences.count
                )
                for reference in assFontReferences {
                    try insertASSFontReference(subtitleFileID: subtitleFileID, reference: reference)
                }
            }

            for segment in assRenderSegments {
                try insertASSRenderSegment(subtitleFileID: subtitleFileID, segment: segment)
            }

            if let languageAnalysis {
                try insertSubtitleLanguageManifest(
                    subtitleFileID: subtitleFileID,
                    detectionCount: languageAnalysis.styleDetections.count + (languageAnalysis.fileDetection == nil ? 0 : 1),
                    cueGroupCount: languageAnalysis.cueGroupLanguages.count
                )
                if let fileDetection = languageAnalysis.fileDetection {
                    try insertSubtitleLanguageDetection(
                        subtitleFileID: subtitleFileID,
                        scope: .file,
                        scopeKey: nil,
                        detection: fileDetection
                    )
                }
                for styleName in languageAnalysis.styleDetections.keys.sorted() {
                    guard let detection = languageAnalysis.styleDetections[styleName] else {
                        continue
                    }
                    try insertSubtitleLanguageDetection(
                        subtitleFileID: subtitleFileID,
                        scope: .style,
                        scopeKey: styleName,
                        detection: detection
                    )
                }
            }

            for (index, group) in cueGroups.enumerated() {
                let cueGroupID = try insertCueGroup(
                    subtitleFileID: subtitleFileID,
                    subtitleFile: subtitleFile,
                    group: group
                )
                for line in group.cueLines {
                    try insertCueLine(cueGroupID: cueGroupID, line: line)
                }
                try insertFTSRow(cueGroupID: cueGroupID, content: group.searchContent)
                if let languages = languageAnalysis?.cueGroupLanguages[index] {
                    try insertCueGroupLanguages(cueGroupID: cueGroupID, languages: languages)
                }
            }

            if rebuildSearchDerivedIndex {
                try rebuildSearchDerivedIndexInCurrentTransaction()
            }
            try deleteOrphanedVideoFiles()
            try bumpPlaybackNavigationIndexRevisionInCurrentTransaction()
            try database.execute("COMMIT")
            clearSearchResultCache()
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

    public func languageDetections(
        forSubtitleFile subtitleFile: URL
    ) throws -> [StoredSubtitleLanguageDetection] {
        let statement = try database.prepare(
            """
            SELECT d.id, sf.subtitle_path, d.scope, d.scope_key, d.algorithm_version,
                   d.confidence, d.confidence_band, d.segment_count,
                   d.effective_character_count, d.detected_at
            FROM subtitle_language_detections d
            JOIN subtitle_files sf ON sf.id = d.subtitle_file_id
            WHERE sf.subtitle_path = ?
            ORDER BY d.scope ASC, d.scope_key ASC, d.id ASC;
            """
        )
        try statement.bind(subtitleFile.path, at: 1)

        var records: [StoredSubtitleLanguageDetection] = []
        while try statement.step() {
            let detectionID = statement.int64Column(0)
            records.append(
                StoredSubtitleLanguageDetection(
                    subtitlePath: statement.stringColumn(1),
                    scope: SubtitleLanguageDetectionScope(rawValue: statement.stringColumn(2)) ?? .file,
                    scopeKey: statement.stringColumn(3).isEmpty ? nil : statement.stringColumn(3),
                    algorithmVersion: statement.intColumn(4),
                    confidence: statement.nullableDoubleColumn(5) ?? 0,
                    confidenceBand: SubtitleLanguageConfidenceBand(rawValue: statement.stringColumn(6)) ?? .none,
                    segmentCount: statement.intColumn(7),
                    effectiveCharacterCount: statement.intColumn(8),
                    languages: try subtitleLanguageDetectionCodes(detectionID: detectionID),
                    distribution: try subtitleLanguageDetectionDistribution(detectionID: detectionID),
                    detectedAt: statement.stringColumn(9)
                )
            )
        }

        return records
    }

    public func cueGroupLanguages(
        forSubtitleFile subtitleFile: URL
    ) throws -> [Int64: Set<SubtitleLanguageCode>] {
        let statement = try database.prepare(
            """
            SELECT g.id, cgl.language_code
            FROM subtitle_cue_groups g
            JOIN subtitle_files sf ON sf.id = g.subtitle_file_id
            JOIN subtitle_cue_group_languages cgl ON cgl.cue_group_id = g.id
            WHERE sf.subtitle_path = ?
            ORDER BY g.start_ms ASC, g.end_ms ASC, g.id ASC, cgl.language_code ASC;
            """
        )
        try statement.bind(subtitleFile.path, at: 1)

        var languagesByCueGroupID: [Int64: Set<SubtitleLanguageCode>] = [:]
        while try statement.step() {
            guard let language = SubtitleLanguageCode(rawValue: statement.stringColumn(1)) else {
                continue
            }
            languagesByCueGroupID[statement.int64Column(0), default: []].insert(language)
        }

        return languagesByCueGroupID
    }

    public func hasCurrentSubtitleLanguageManifest(forSubtitleFile subtitleFile: URL) throws -> Bool {
        let statement = try database.prepare(
            """
            SELECT lm.algorithm_version
            FROM subtitle_language_manifests lm
            JOIN subtitle_files sf ON sf.id = lm.subtitle_file_id
            WHERE sf.subtitle_path = ?;
            """
        )
        try statement.bind(subtitleFile.path, at: 1)

        guard try statement.step() else {
            return false
        }

        return statement.intColumn(0) == SubtitleLanguageRecognizer.algorithmVersion
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

    public func hasCurrentASSFontReferenceManifest(forSubtitleFile subtitleFile: URL) throws -> Bool {
        let statement = try database.prepare(
            """
            SELECT 1
            FROM ass_font_reference_manifests m
            JOIN subtitle_files sf ON sf.id = m.subtitle_file_id
            WHERE sf.subtitle_path = ?
              AND m.algorithm_version = ?
            LIMIT 1;
            """
        )

        try statement.bind(subtitleFile.path, at: 1)
        try statement.bind(ASSFontIntentExtractor.cacheAlgorithmVersion, at: 2)
        return try statement.step()
    }

    public func assFontReferences(forSubtitleFile subtitleFile: URL) throws -> [ASSFontReference] {
        let statement = try database.prepare(
            """
            SELECT sf.subtitle_path, r.font_name, r.source_location,
                   r.occurrence_count, r.first_occurrence_order
            FROM ass_font_references r
            JOIN subtitle_files sf ON sf.id = r.subtitle_file_id
            WHERE sf.subtitle_path = ?
              AND r.algorithm_version = ?
            ORDER BY r.first_occurrence_order ASC, r.id ASC;
            """
        )

        try statement.bind(subtitleFile.path, at: 1)
        try statement.bind(ASSFontIntentExtractor.cacheAlgorithmVersion, at: 2)

        var references: [ASSFontReference] = []
        while try statement.step() {
            references.append(
                ASSFontReference(
                    subtitlePath: statement.stringColumn(0),
                    fontName: statement.stringColumn(1),
                    source: ASSFontReferenceSource(rawValue: statement.stringColumn(2)) ?? .style,
                    occurrenceCount: statement.intColumn(3),
                    firstOccurrenceOrder: statement.intColumn(4)
                )
            )
        }

        return references
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
            try rebuildSearchDerivedIndexInCurrentTransaction()
            try bumpPlaybackNavigationIndexRevisionInCurrentTransaction()
            try database.execute("COMMIT")
            clearSearchResultCache()
        } catch {
            try? database.execute("ROLLBACK")
            throw error
        }
    }

    public func rebuildSearchDerivedIndex() throws {
        try database.execute("BEGIN IMMEDIATE TRANSACTION")
        do {
            try rebuildSearchDerivedIndexInCurrentTransaction()
            try bumpPlaybackNavigationIndexRevisionInCurrentTransaction()
            try database.execute("COMMIT")
            clearSearchResultCache()
        } catch {
            try? database.execute("ROLLBACK")
            throw error
        }
    }

    public func clearIndexedContent() throws {
        try database.execute("BEGIN IMMEDIATE TRANSACTION")
        do {
            try database.execute("DELETE FROM library_video_rows;")
            try database.execute("DELETE FROM subtitle_search_order_rows;")
            try database.execute("DELETE FROM subtitle_cue_groups_fts;")
            try database.execute("DELETE FROM ass_font_references;")
            try database.execute("DELETE FROM ass_font_reference_manifests;")
            try database.execute("DELETE FROM ass_render_segments;")
            try database.execute("DELETE FROM subtitle_files;")
            try database.execute("DELETE FROM video_files;")
            try database.execute("DELETE FROM search_paths;")
            try bumpPlaybackNavigationIndexRevisionInCurrentTransaction()
            try database.execute("COMMIT")
            clearSearchResultCache()
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
        diagnostics: SubtitleSearchDiagnosticSink? = nil,
        progress: SubtitleSearchProgressSink? = nil,
        mode: SubtitleSearchPageMode = .exact
    ) throws -> SubtitleSearchPage {
        try searchPage(
            query,
            limit: limit,
            cursor: SubtitleSearchCursor(offset: offset),
            under: folders,
            inSubtitlePath: subtitlePath,
            diagnostics: diagnostics,
            progress: progress,
            mode: mode
        )
    }

    public func searchVisiblePage(
        _ query: String,
        limit: Int = 50,
        cursor: SubtitleSearchCursor?,
        under folders: [URL]? = nil,
        inSubtitlePath subtitlePath: String? = nil,
        diagnostics: SubtitleSearchDiagnosticSink? = nil,
        progress: SubtitleSearchProgressSink? = nil
    ) throws -> SubtitleSearchPage {
        try searchPage(
            query,
            limit: limit,
            cursor: cursor,
            under: folders,
            inSubtitlePath: subtitlePath,
            diagnostics: diagnostics,
            progress: progress,
            mode: .visibleWindow
        )
    }

    public func searchPage(
        _ query: String,
        limit: Int = 50,
        cursor: SubtitleSearchCursor?,
        under folders: [URL]? = nil,
        inSubtitlePath subtitlePath: String? = nil,
        diagnostics: SubtitleSearchDiagnosticSink? = nil,
        progress: SubtitleSearchProgressSink? = nil,
        mode: SubtitleSearchPageMode = .exact
    ) throws -> SubtitleSearchPage {
        let searchPageStart = Self.diagnosticNow()
        let appliedCursor = cursor ?? .start

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
            return SubtitleSearchPage(
                results: [],
                totalCount: 0,
                fileSummaries: [],
                appliedCursor: appliedCursor,
                pageMode: mode
            )
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
        let offset = appliedCursor.offset
        let subtitlePathFilter = subtitlePath
        if let subtitlePathFilter, subtitlePathFilter.isEmpty {
            emit("scope_empty_subtitle_path", since: scopeStart)
            return SubtitleSearchPage(
                results: [],
                totalCount: 0,
                fileSummaries: [],
                appliedCursor: appliedCursor,
                pageMode: mode
            )
        }

        let pathPrefixes: [String]?
        if let folders {
            let prefixes = Self.folderPathPrefixes(for: folders)
            guard !prefixes.isEmpty else {
                emit("scope_empty_folders", since: scopeStart)
                return SubtitleSearchPage(
                    results: [],
                    totalCount: 0,
                    fileSummaries: [],
                    appliedCursor: appliedCursor,
                    pageMode: mode
                )
            }
            pathPrefixes = prefixes
        } else {
            pathPrefixes = nil
        }
        emit(
            "scope_resolved",
            since: scopeStart,
            fields: [
                .init("cursorOffset", appliedCursor.offset),
                .init("pathPrefixes", pathPrefixes?.count ?? 0),
                .init("hasSubtitlePathFilter", subtitlePathFilter == nil ? "false" : "true")
            ]
        )

        let cacheKey = SearchResultCacheKey(
            query: query,
            limit: limit,
            offset: offset,
            mode: mode,
            pathPrefixes: pathPrefixes.map { Array(Set($0)).sorted() },
            subtitlePath: subtitlePathFilter
        )
        let cacheStart = Self.diagnosticNow()
        if let cachedPage = searchResultCache.page(for: cacheKey) {
            emit(
                "search_cache_hit",
                since: cacheStart,
                fields: [
                    .init("metadataMode", mode.rawValue),
                    .init("limit", limit),
                    .init("offset", offset),
                    .init("results", cachedPage.results.count),
                    .init("totalCount", cachedPage.totalCount),
                    .init("summaries", cachedPage.fileSummaries.count)
                ]
            )
            return cachedPage
        }
        emit(
            "search_cache_miss",
            since: cacheStart,
            fields: [
                .init("metadataMode", mode.rawValue),
                .init("limit", limit),
                .init("offset", offset)
            ]
        )

        do {
            let setupStart = Self.diagnosticNow()
            let candidateBatchLimit = Self.searchCandidateBatchLimit(for: limit, mode: mode)
            var candidateOffset = 0
            var results: [OrderedSearchResult] = []
            var visiblePrefixResults: [OrderedSearchResult] = []
            var visibleWindowResults: [OrderedSearchResult] = []
            var progressFileSummaries = SearchFileSummaryAccumulator()
            var acceptedSearchResultCount = 0
            var reachedVisibleLookahead = false
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
                    .init("subtitlePathFilter", subtitlePathFilter == nil ? "false" : "true"),
                    .init("metadataMode", mode.rawValue)
                ]
            )

            let searchOrderRowsStart = Self.diagnosticNow()
            try requireCompleteSearchOrderRows(
                pathPrefixes: pathPrefixes,
                subtitlePath: subtitlePathFilter
            )
            emit("search_order_rows_validated", since: searchOrderRowsStart)

            let prepareStart = Self.diagnosticNow()
            let statement = try database.prepare(
                """
                SELECT g.id, sf.subtitle_path, sf.format, vf.path, vf.video_name,
                       g.start_ms, g.end_ms, g.search_content, g.line_count,
                       sor.subtitle_file_name, sor.display_title, sor.folder_order, sor.file_order
                FROM subtitle_cue_groups_fts f
                JOIN subtitle_cue_groups g ON g.id = f.cue_group_id
                JOIN subtitle_files sf ON sf.id = g.subtitle_file_id
                JOIN subtitle_video_matches m ON m.subtitle_file_id = sf.id AND m.is_active = 1
                JOIN video_files vf ON vf.id = m.video_file_id
                JOIN subtitle_search_order_rows sor ON sor.subtitle_path = sf.subtitle_path
                WHERE subtitle_cue_groups_fts MATCH ?
                \(scopeCondition)
                \(subtitlePathCondition)
                ORDER BY f.rowid ASC
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
                            lineCount: statement.intColumn(8),
                            order: SearchResultOrder(
                                subtitleFileName: statement.stringColumn(9),
                                displayTitle: statement.stringColumn(10),
                                folderOrder: statement.intColumn(11),
                                fileOrder: statement.intColumn(12)
                            )
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
                let acceptedBefore = acceptedSearchResultCount
                for candidate in candidates {
                    let lineContents: [String]
                    if candidate.lineCount > 1 {
                        let lines = linesByCueGroupID[candidate.cueGroupID] ?? []
                        lineContents = lines.isEmpty ? [candidate.searchContent] : lines.map(\.content)
                    } else {
                        lineContents = [candidate.searchContent]
                    }
                    if let result = searchResult(for: candidate, lineContents: lineContents, matching: plan) {
                        switch mode {
                        case .exact:
                            results.append(result)
                            progressFileSummaries.add(result)
                        case .visibleWindow:
                            if acceptedSearchResultCount < offset + limit {
                                visiblePrefixResults.append(result)
                            }
                            if acceptedSearchResultCount >= offset && visibleWindowResults.count < limit + 1 {
                                visibleWindowResults.append(result)
                                reachedVisibleLookahead = visibleWindowResults.count > limit
                            }
                        }
                        acceptedSearchResultCount += 1
                    }
                }
                let accepted = acceptedSearchResultCount - acceptedBefore
                emit(
                    "line_validation",
                    since: validationStart,
                    fields: [
                        .init("batch", batchIndex),
                        .init("candidates", candidates.count),
                        .init("accepted", accepted),
                        .init("rejected", candidates.count - accepted),
                        .init("acceptedSoFar", acceptedSearchResultCount)
                    ]
                )

                let isLastCandidateBatch = candidates.count < candidateBatchLimit
                if mode == .exact,
                   !isLastCandidateBatch,
                   acceptedSearchResultCount > 0 {
                    let progressSummaries = progressFileSummaries.fileSummaries()
                    let countSnapshot = SubtitleSearchCountSnapshot.exactProgress(
                        knownResultCount: acceptedSearchResultCount,
                        knownFileCount: progressSummaries.count
                    )
                    progress?(
                        SubtitleSearchProgressSnapshot(
                            countSnapshot: countSnapshot,
                            fileSummaries: progressSummaries
                        )
                    )
                    emit(
                        "count_progress",
                        since: searchPageStart,
                        fields: [
                            .init("countState", countSnapshot.state.rawValue),
                            .init("knownResultCount", countSnapshot.knownResultCount),
                            .init("knownFileCount", countSnapshot.knownFileCount),
                            .init("summaries", progressSummaries.count)
                        ]
                    )
                }

                if reachedVisibleLookahead {
                    break
                }

                if isLastCandidateBatch {
                    break
                }
            }

            if mode == .visibleWindow {
                let pageStart = Self.diagnosticNow()
                let hasMore = visibleWindowResults.count > limit
                let pageOrderedResults = Array(visibleWindowResults.prefix(limit))
                var pageResults = pageOrderedResults.map(\.result)
                for i in 0..<pageResults.count {
                    pageResults[i].searchRank = offset + i
                }
                let nextCursor = hasMore
                    ? SubtitleSearchCursor(offset: offset + pageResults.count)
                    : nil
                let orderSource = Self.searchOrderSource(for: pageOrderedResults)
                let materializedOrderRows = visiblePrefixResults.count
                emit(
                    "page_slice",
                    since: pageStart,
                    fields: [
                        .init("offset", offset),
                        .init("cursorOffset", appliedCursor.offset),
                        .init("nextCursorOffset", nextCursor?.offset ?? -1),
                        .init("limit", limit),
                        .init("pageResults", pageResults.count),
                        .init("hasMore", hasMore ? "true" : "false"),
                        .init("metadataMode", mode.rawValue)
                    ]
                )

                let summariesStart = Self.diagnosticNow()
                let fileSummaries = Self.fileSummaries(for: visiblePrefixResults)
                let countSnapshot: SubtitleSearchCountSnapshot = hasMore
                    ? .exactProgress(
                        knownResultCount: visiblePrefixResults.count,
                        knownFileCount: fileSummaries.count
                    )
                    : .exact(
                        totalCount: visiblePrefixResults.count,
                        fileSummaryCount: fileSummaries.count
                    )
                emit(
                    "file_summaries",
                    since: summariesStart,
                    fields: [
                        .init("summaries", fileSummaries.count),
                        .init("results", visiblePrefixResults.count),
                        .init("countState", countSnapshot.state.rawValue),
                        .init("knownResultCount", countSnapshot.knownResultCount),
                        .init("knownFileCount", countSnapshot.knownFileCount),
                        .init("metadataMode", mode.rawValue)
                    ]
                )

                emit(
                    "search_page_complete",
                    since: searchPageStart,
                    fields: [
                        .init("batches", batchIndex),
                        .init("cursorOffset", appliedCursor.offset),
                        .init("nextCursorOffset", nextCursor?.offset ?? -1),
                        .init("totalCandidates", totalCandidates),
                        .init("multiLineCandidates", totalMultiLineCandidates),
                        .init("cueLineRows", totalCueLineRows),
                        .init("accepted", visiblePrefixResults.count),
                        .init("pageResults", pageResults.count),
                        .init("summaries", fileSummaries.count),
                        .init("orderSource", orderSource),
                        .init("materializedOrderRows", materializedOrderRows),
                        .init("countState", countSnapshot.state.rawValue),
                        .init("knownResultCount", countSnapshot.knownResultCount),
                        .init("knownFileCount", countSnapshot.knownFileCount),
                        .init("metadataMode", mode.rawValue)
                    ]
                )
                let page = SubtitleSearchPage(
                    results: pageResults,
                    totalCount: countSnapshot.knownResultCount,
                    fileSummaries: fileSummaries,
                    countSnapshot: countSnapshot,
                    appliedCursor: appliedCursor,
                    nextCursor: nextCursor,
                    pageMode: mode,
                    orderSource: orderSource,
                    materializedOrderRows: materializedOrderRows
                )
                storeSearchResultPageIfCacheable(page, for: cacheKey, requestedLimit: limit, emit: emit)
                return page
            }

            let sortStart = Self.diagnosticNow()
            let sortedOrderedResults = results
            let sortedResults = sortedOrderedResults.map(\.result)
            let orderSource = Self.searchOrderSource(for: sortedOrderedResults)
            let materializedOrderRows = sortedOrderedResults.count
            emit(
                "sort_results",
                since: sortStart,
                fields: [
                    .init("results", sortedResults.count),
                    .init("uniqueSubtitlePaths", Set(sortedResults.map(\.subtitlePath)).count),
                    .init("orderSource", orderSource),
                    .init("materializedOrderRows", materializedOrderRows)
                ]
            )

            let pageStart = Self.diagnosticNow()
            var pageResults = Array(sortedResults.dropFirst(offset).prefix(limit))
            for i in 0..<pageResults.count {
                pageResults[i].searchRank = offset + i
            }
            let nextCursor = offset + pageResults.count < sortedResults.count
                ? SubtitleSearchCursor(offset: offset + pageResults.count)
                : nil
            emit(
                "page_slice",
                since: pageStart,
                fields: [
                    .init("offset", offset),
                    .init("cursorOffset", appliedCursor.offset),
                    .init("nextCursorOffset", nextCursor?.offset ?? -1),
                    .init("limit", limit),
                    .init("pageResults", pageResults.count)
                ]
            )

            let summariesStart = Self.diagnosticNow()
            let fileSummaries = Self.fileSummaries(for: sortedOrderedResults)
            let countSnapshot = SubtitleSearchCountSnapshot.exact(
                totalCount: sortedResults.count,
                fileSummaryCount: fileSummaries.count
            )
            emit(
                "file_summaries",
                since: summariesStart,
                fields: [
                    .init("summaries", fileSummaries.count),
                    .init("results", sortedResults.count),
                    .init("countState", countSnapshot.state.rawValue),
                    .init("knownResultCount", countSnapshot.knownResultCount),
                    .init("knownFileCount", countSnapshot.knownFileCount)
                ]
            )

            emit(
                "search_page_complete",
                since: searchPageStart,
                fields: [
                    .init("batches", batchIndex),
                    .init("cursorOffset", appliedCursor.offset),
                    .init("nextCursorOffset", nextCursor?.offset ?? -1),
                    .init("totalCandidates", totalCandidates),
                    .init("multiLineCandidates", totalMultiLineCandidates),
                    .init("cueLineRows", totalCueLineRows),
                    .init("accepted", sortedResults.count),
                    .init("pageResults", pageResults.count),
                    .init("summaries", fileSummaries.count),
                    .init("orderSource", orderSource),
                    .init("countState", countSnapshot.state.rawValue),
                    .init("knownResultCount", countSnapshot.knownResultCount),
                    .init("knownFileCount", countSnapshot.knownFileCount)
                ]
            )
            let page = SubtitleSearchPage(
                results: pageResults,
                totalCount: sortedResults.count,
                fileSummaries: fileSummaries,
                countSnapshot: countSnapshot,
                appliedCursor: appliedCursor,
                nextCursor: nextCursor,
                pageMode: mode,
                orderSource: orderSource,
                materializedOrderRows: materializedOrderRows
            )
            storeSearchResultPageIfCacheable(page, for: cacheKey, requestedLimit: limit, emit: emit)
            return page
        } catch {
            emit(
                "failed",
                since: searchPageStart,
                fields: [.init("error", error.localizedDescription)]
            )
            if Self.isFTSSyntaxError(error) {
                return SubtitleSearchPage(
                    results: [],
                    totalCount: 0,
                    fileSummaries: [],
                    appliedCursor: appliedCursor,
                    pageMode: mode
                )
            }
            throw error
        }
    }

    public func ftsVocabularyDiagnostics(
        for query: String,
        topTermLimit: Int = 12
    ) throws -> SubtitleFTSVocabularyDiagnostics {
        try database.execute(
            """
            CREATE VIRTUAL TABLE IF NOT EXISTS temp.subtitle_cue_groups_fts_vocab
            USING fts5vocab(main, subtitle_cue_groups_fts, 'row');
            """
        )

        let totals = try database.prepare(
            """
            SELECT COUNT(*), COALESCE(SUM(doc), 0), COALESCE(SUM(cnt), 0)
            FROM temp.subtitle_cue_groups_fts_vocab;
            """
        )
        _ = try totals.step()
        let uniqueTermCount = totals.intColumn(0)
        let totalDocumentReferences = totals.intColumn(1)
        let totalOccurrences = totals.intColumn(2)

        let topTerms = try ftsVocabularyTerms(
            matching: nil,
            limit: max(0, topTermLimit)
        )
        let queryTerms = try Self.ftsVocabularyTerms(in: query).map { term in
            try ftsVocabularyTerm(term)
        }

        return SubtitleFTSVocabularyDiagnostics(
            uniqueTermCount: uniqueTermCount,
            totalDocumentReferences: totalDocumentReferences,
            totalOccurrences: totalOccurrences,
            mostFrequentTerms: topTerms,
            queryTerms: queryTerms
        )
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

    private func rebuildSearchOrderRows() throws {
        try database.execute("DELETE FROM subtitle_search_order_rows;")
        try insertSearchOrderRows(for: try indexedSearchOrderFiles(inFolderPath: nil))
    }

    private func rebuildSearchDerivedIndexInCurrentTransaction() throws {
        try rebuildSearchOrderRows()
        try rebuildFTSRowsInProductOrder()
    }

    private func requireCompleteSearchOrderRows(
        pathPrefixes: [String]?,
        subtitlePath: String?
    ) throws {
        let scopeCondition = pathPrefixes.map {
            let conditions = $0.map { _ in "(sf.subtitle_path >= ? AND sf.subtitle_path < ?)" }
                .joined(separator: " OR ")
            return "AND (\(conditions))"
        } ?? ""
        let subtitlePathCondition = subtitlePath.map { _ in "AND sf.subtitle_path = ?" } ?? ""
        let statement = try database.prepare(
            """
            SELECT sf.subtitle_path
            FROM subtitle_files sf
            LEFT JOIN subtitle_search_order_rows sor ON sor.subtitle_path = sf.subtitle_path
            WHERE sor.subtitle_path IS NULL
            \(scopeCondition)
            \(subtitlePathCondition)
            LIMIT 1;
            """
        )

        var bindIndex: Int32 = 1
        if let pathPrefixes {
            for prefix in pathPrefixes {
                try statement.bind(prefix, at: bindIndex)
                bindIndex += 1
                try statement.bind(Self.pathPrefixUpperBound(for: prefix), at: bindIndex)
                bindIndex += 1
            }
        }
        if let subtitlePath {
            try statement.bind(subtitlePath, at: bindIndex)
        }

        guard try !statement.step() else {
            throw SQLiteDatabaseError.stepFailed(
                "Search order rows are missing for \(statement.stringColumn(0)). Rebuild derived Search order rows before searching."
            )
        }
    }

    private func indexedSearchOrderFiles(inFolderPath folderPath: String?) throws -> [SearchOrderFile] {
        let statement: SQLiteStatement
        if let folderPath {
            let prefix = Self.subtitlePathPrefix(forFolderPath: folderPath)
            statement = try database.prepare(
                """
                SELECT subtitle_path
                FROM subtitle_files
                WHERE subtitle_path >= ? AND subtitle_path < ?
                ORDER BY subtitle_path ASC;
                """
            )
            try statement.bind(prefix, at: 1)
            try statement.bind(Self.pathPrefixUpperBound(for: prefix), at: 2)
        } else {
            statement = try database.prepare(
                """
                SELECT subtitle_path
                FROM subtitle_files
                ORDER BY subtitle_path ASC;
                """
            )
        }

        var files: [SearchOrderFile] = []
        while try statement.step() {
            let subtitlePath = statement.stringColumn(0)
            let folderPath = Self.folderPath(forSubtitlePath: subtitlePath)
            files.append(
                SearchOrderFile(
                    subtitlePath: subtitlePath,
                    folderPath: folderPath,
                    folderTitle: URL(fileURLWithPath: folderPath).lastPathComponent,
                    subtitleFileName: URL(fileURLWithPath: subtitlePath).lastPathComponent
                )
            )
        }
        return files
    }

    private func insertSearchOrderRows(for files: [SearchOrderFile]) throws {
        guard !files.isEmpty else {
            return
        }

        let updatedAt = ISO8601DateFormatter().string(from: Date())
        let filesByFolderPath = Dictionary(grouping: files, by: \.folderPath)
        let folderPaths = filesByFolderPath.keys.sorted { lhs, rhs in
            let lhsTitle = URL(fileURLWithPath: lhs).lastPathComponent
            let rhsTitle = URL(fileURLWithPath: rhs).lastPathComponent
            let titleComparison = lhsTitle.localizedStandardCompare(rhsTitle)
            if titleComparison != .orderedSame {
                return titleComparison == .orderedAscending
            }

            return lhs.localizedStandardCompare(rhs) == .orderedAscending
        }
        let insert = try database.prepare(
            """
            INSERT INTO subtitle_search_order_rows(
                subtitle_path,
                folder_path,
                folder_title,
                subtitle_file_name,
                display_title,
                folder_order,
                file_order,
                updated_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?);
            """
        )

        for (folderOrder, folderPath) in folderPaths.enumerated() {
            let files = (filesByFolderPath[folderPath] ?? []).sorted { lhs, rhs in
                let filenameComparison = lhs.subtitleFileName.localizedStandardCompare(rhs.subtitleFileName)
                if filenameComparison != .orderedSame {
                    return filenameComparison == .orderedAscending
                }

                return lhs.subtitlePath.localizedStandardCompare(rhs.subtitlePath) == .orderedAscending
            }

            for (fileOrder, file) in files.enumerated() {
                try insert.bind(file.subtitlePath, at: 1)
                try insert.bind(file.folderPath, at: 2)
                try insert.bind(file.folderTitle, at: 3)
                try insert.bind(file.subtitleFileName, at: 4)
                try insert.bind(SubtitleDisplayTitleResolver.displayTitle(forSubtitlePath: file.subtitlePath), at: 5)
                try insert.bind(folderOrder, at: 6)
                try insert.bind(fileOrder, at: 7)
                try insert.bind(updatedAt, at: 8)
                try insert.run()
                try insert.reset()
                try insert.clearBindings()
            }
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
        let order: SearchResultOrder
    }

    private struct SearchResultOrder {
        let subtitleFileName: String
        let displayTitle: String
        let folderOrder: Int
        let fileOrder: Int
    }

    private struct OrderedSearchResult {
        let result: SubtitleSearchResult
        let order: SearchResultOrder
    }

    private struct SearchFileSummaryAccumulator {
        private var countsByPath: [String: Int] = [:]
        private var pathsInOrder: [String] = []
        private var fileNamesByPath: [String: String] = [:]
        private var displayTitlesByPath: [String: String] = [:]

        mutating func add(_ orderedResult: OrderedSearchResult) {
            let result = orderedResult.result
            if countsByPath[result.subtitlePath] == nil {
                pathsInOrder.append(result.subtitlePath)
            }
            countsByPath[result.subtitlePath, default: 0] += 1
            fileNamesByPath[result.subtitlePath] = orderedResult.order.subtitleFileName
            displayTitlesByPath[result.subtitlePath] = orderedResult.order.displayTitle
        }

        func fileSummaries() -> [SubtitleSearchFileSummary] {
            pathsInOrder.map { path in
                SubtitleSearchFileSummary(
                    subtitlePath: path,
                    subtitleFileName: fileNamesByPath[path]!,
                    subtitleDisplayTitle: displayTitlesByPath[path]!,
                    matchCount: countsByPath[path]!
                )
            }
        }
    }

    private struct SearchOrderFile {
        let subtitlePath: String
        let folderPath: String
        let folderTitle: String
        let subtitleFileName: String
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
    ) -> OrderedSearchResult? {
        guard lineContents.contains(where: { Self.line($0, matches: plan.lineMatchRule) }) else {
            return nil
        }

        return OrderedSearchResult(
            result: SubtitleSearchResult(
                entryID: candidate.cueGroupID,
                subtitlePath: candidate.subtitlePath,
                subtitleFormat: candidate.subtitleFormat,
                videoPath: candidate.videoPath,
                videoName: candidate.videoName,
                startMilliseconds: candidate.startMilliseconds,
                endMilliseconds: candidate.endMilliseconds,
                content: candidate.searchContent,
                cueLines: lineContents
            ),
            order: candidate.order
        )
    }

    private static func searchOrderSource(for results: [OrderedSearchResult]) -> String {
        guard !results.isEmpty else {
            return "none"
        }

        return "ftsRowid"
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

    private static func fileSummaries(for results: [OrderedSearchResult]) -> [SubtitleSearchFileSummary] {
        var countsByPath: [String: Int] = [:]
        var pathsInOrder: [String] = []
        var fileNamesByPath: [String: String] = [:]
        var displayTitlesByPath: [String: String] = [:]
        for orderedResult in results {
            let result = orderedResult.result
            if countsByPath[result.subtitlePath] == nil {
                pathsInOrder.append(result.subtitlePath)
            }
            countsByPath[result.subtitlePath, default: 0] += 1
            fileNamesByPath[result.subtitlePath] = orderedResult.order.subtitleFileName
            displayTitlesByPath[result.subtitlePath] = orderedResult.order.displayTitle
        }

        return pathsInOrder
        .map { path in
            SubtitleSearchFileSummary(
                subtitlePath: path,
                subtitleFileName: fileNamesByPath[path]!,
                subtitleDisplayTitle: displayTitlesByPath[path]!,
                matchCount: countsByPath[path]!
            )
        }
    }

    private static func isFTSSyntaxError(_ error: Error) -> Bool {
        String(describing: error).contains("fts5: syntax error")
    }

    private func ftsVocabularyTerms(
        matching term: String?,
        limit: Int
    ) throws -> [SubtitleFTSVocabularyTermDiagnostic] {
        guard limit > 0 else {
            return []
        }

        let statement: SQLiteStatement
        if let term {
            statement = try database.prepare(
                """
                SELECT term, doc, cnt
                FROM temp.subtitle_cue_groups_fts_vocab
                WHERE term = ?
                LIMIT ?;
                """
            )
            try statement.bind(term, at: 1)
            try statement.bind(limit, at: 2)
        } else {
            statement = try database.prepare(
                """
                SELECT term, doc, cnt
                FROM temp.subtitle_cue_groups_fts_vocab
                ORDER BY cnt DESC, doc DESC, term ASC
                LIMIT ?;
                """
            )
            try statement.bind(limit, at: 1)
        }

        var terms: [SubtitleFTSVocabularyTermDiagnostic] = []
        while try statement.step() {
            terms.append(
                SubtitleFTSVocabularyTermDiagnostic(
                    term: statement.stringColumn(0),
                    documentCount: statement.intColumn(1),
                    occurrenceCount: statement.intColumn(2)
                )
            )
        }
        return terms
    }

    private func ftsVocabularyTerm(_ term: String) throws -> SubtitleFTSVocabularyTermDiagnostic {
        try ftsVocabularyTerms(matching: term, limit: 1).first
            ?? SubtitleFTSVocabularyTermDiagnostic(
                term: term,
                documentCount: 0,
                occurrenceCount: 0
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

    private static func ftsVocabularyTerms(in text: String) -> [String] {
        let operators = Set(["and", "or", "not", "near"])
        var terms: [String] = []
        var seen = Set<String>()
        var current = ""

        func appendTerm(_ rawTerm: String) {
            let term = rawTerm.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !term.isEmpty, !operators.contains(term), seen.insert(term).inserted else {
                return
            }

            terms.append(term)
        }

        func flushCurrent() {
            appendTerm(current)
            current = ""
        }

        for character in text {
            if character.unicodeScalars.count == 1,
               let scalar = character.unicodeScalars.first,
               isCJKSearchCharacter(scalar) {
                flushCurrent()
                appendTerm(String(character))
            } else if isASCIILetterOrDigit(character) {
                current.append(contentsOf: character.lowercased())
            } else if character == "'", !current.isEmpty {
                current.append(character)
            } else {
                flushCurrent()
            }
        }

        flushCurrent()
        return terms
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

    private static func fileSize(at url: URL) -> Int64 {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        return (attributes?[.size] as? NSNumber)?.int64Value ?? 0
    }

    private static func sidecarPath(suffix: String, for path: URL) -> URL {
        URL(fileURLWithPath: path.path + suffix)
    }

    private static func expandedSQLLimit(for limit: Int) -> Int {
        let (expanded, overflow) = limit.multipliedReportingOverflow(by: 2)
        if overflow {
            return Int(Int32.max)
        }

        return min(expanded, Int(Int32.max))
    }

    private static func searchCandidateBatchLimit(
        for limit: Int,
        mode: SubtitleSearchPageMode
    ) -> Int {
        switch mode {
        case .exact:
            max(expandedSQLLimit(for: limit), exactSearchCandidateBatchMinimum)
        case .visibleWindow:
            max(expandedSQLLimit(for: limit), 100)
        }
    }

    private func storeSearchResultPageIfCacheable(
        _ page: SubtitleSearchPage,
        for key: SearchResultCacheKey,
        requestedLimit: Int,
        emit: (String, UInt64, [SubtitleSearchDiagnosticField]) -> Void
    ) {
        guard requestedLimit <= Self.maxCachedSearchPageLimit,
              page.results.count <= Self.maxCachedSearchPageLimit
        else {
            return
        }

        let storeStart = Self.diagnosticNow()
        searchResultCache.store(page, for: key)
        emit(
            "search_cache_store",
            storeStart,
            [
                .init("metadataMode", page.pageMode.rawValue),
                .init("limit", requestedLimit),
                .init("offset", key.offset),
                .init("results", page.results.count),
                .init("totalCount", page.totalCount),
                .init("summaries", page.fileSummaries.count)
            ]
        )
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
            let deleteASSFontReferences = try database.prepare(
                """
                DELETE FROM ass_font_references
                WHERE subtitle_file_id IN (
                    SELECT sf.id
                    FROM subtitle_files sf
                    WHERE (\(prefixCondition)) \(keepCondition)
                );
                """
            )
            try bindStaleEntryParameters(
                statement: deleteASSFontReferences,
                folderPathPrefixes: folderPathPrefixes,
                subtitleFiles: subtitleFiles
            )
            try deleteASSFontReferences.run()

            let deleteASSFontReferenceManifests = try database.prepare(
                """
                DELETE FROM ass_font_reference_manifests
                WHERE subtitle_file_id IN (
                    SELECT sf.id
                    FROM subtitle_files sf
                    WHERE (\(prefixCondition)) \(keepCondition)
                );
                """
            )
            try bindStaleEntryParameters(
                statement: deleteASSFontReferenceManifests,
                folderPathPrefixes: folderPathPrefixes,
                subtitleFiles: subtitleFiles
            )
            try deleteASSFontReferenceManifests.run()

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

            let deleteSearchOrderRows = try database.prepare(
                """
                DELETE FROM subtitle_search_order_rows
                WHERE (\(libraryRowPrefixCondition)) \(libraryRowKeepCondition);
                """
            )
            try bindStaleEntryParameters(
                statement: deleteSearchOrderRows,
                folderPathPrefixes: folderPathPrefixes,
                subtitleFiles: subtitleFiles
            )
            try deleteSearchOrderRows.run()

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
            try rebuildSearchDerivedIndexInCurrentTransaction()
            try bumpPlaybackNavigationIndexRevisionInCurrentTransaction()
            try database.execute("COMMIT")
            clearSearchResultCache()
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

    private func validateLanguageAnalysis(
        _ languageAnalysis: SubtitleLanguageAnalysis?,
        format: SubtitleFormat,
        cueGroupCount: Int
    ) throws {
        guard let languageAnalysis else {
            return
        }

        guard languageAnalysis.format == format else {
            throw SQLiteDatabaseError.stepFailed(
                "Subtitle language analysis format does not match subtitle format."
            )
        }

        guard languageAnalysis.cueGroupLanguages.count == cueGroupCount else {
            throw SQLiteDatabaseError.stepFailed(
                "Subtitle language analysis cue group count does not match indexed cue group count."
            )
        }
    }

    private func insertSubtitleLanguageManifest(
        subtitleFileID: Int64,
        detectionCount: Int,
        cueGroupCount: Int
    ) throws {
        let statement = try database.prepare(
            """
            INSERT INTO subtitle_language_manifests(
                subtitle_file_id,
                algorithm_version,
                detection_count,
                cue_group_count,
                analyzed_at
            )
            VALUES (?, ?, ?, ?, ?);
            """
        )

        try statement.bind(subtitleFileID, at: 1)
        try statement.bind(SubtitleLanguageRecognizer.algorithmVersion, at: 2)
        try statement.bind(detectionCount, at: 3)
        try statement.bind(cueGroupCount, at: 4)
        try statement.bind(ISO8601DateFormatter().string(from: Date()), at: 5)
        try statement.run()
    }

    private func insertSubtitleLanguageDetection(
        subtitleFileID: Int64,
        scope: SubtitleLanguageDetectionScope,
        scopeKey: String?,
        detection: SubtitleLanguageDetectionResult
    ) throws {
        let statement = try database.prepare(
            """
            INSERT INTO subtitle_language_detections(
                subtitle_file_id,
                scope,
                scope_key,
                algorithm_version,
                confidence,
                confidence_band,
                segment_count,
                effective_character_count,
                detected_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
            """
        )

        try statement.bind(subtitleFileID, at: 1)
        try statement.bind(scope.rawValue, at: 2)
        try statement.bind(scopeKey ?? "", at: 3)
        try statement.bind(SubtitleLanguageRecognizer.algorithmVersion, at: 4)
        try statement.bind(detection.confidence, at: 5)
        try statement.bind(detection.confidenceBand.rawValue, at: 6)
        try statement.bind(detection.segmentCount, at: 7)
        try statement.bind(detection.effectiveCharacterCount, at: 8)
        try statement.bind(ISO8601DateFormatter().string(from: Date()), at: 9)
        try statement.run()

        let detectionID = database.lastInsertRowID()
        for language in detection.languages.sorted(by: { $0.rawValue < $1.rawValue }) {
            try insertSubtitleLanguageDetectionCode(detectionID: detectionID, language: language)
        }
        for (rank, item) in detection.distribution.enumerated() {
            try insertSubtitleLanguageDetectionDistribution(
                detectionID: detectionID,
                item: item,
                rank: rank
            )
        }
    }

    private func insertSubtitleLanguageDetectionCode(
        detectionID: Int64,
        language: SubtitleLanguageCode
    ) throws {
        let statement = try database.prepare(
            """
            INSERT INTO subtitle_language_detection_codes(detection_id, language_code)
            VALUES (?, ?);
            """
        )
        try statement.bind(detectionID, at: 1)
        try statement.bind(language.rawValue, at: 2)
        try statement.run()
    }

    private func insertSubtitleLanguageDetectionDistribution(
        detectionID: Int64,
        item: SubtitleLanguageDistribution,
        rank: Int
    ) throws {
        let statement = try database.prepare(
            """
            INSERT INTO subtitle_language_detection_distribution(
                detection_id,
                language_code,
                share,
                rank
            )
            VALUES (?, ?, ?, ?);
            """
        )
        try statement.bind(detectionID, at: 1)
        try statement.bind(item.language.rawValue, at: 2)
        try statement.bind(item.share, at: 3)
        try statement.bind(rank, at: 4)
        try statement.run()
    }

    private func insertCueGroupLanguages(
        cueGroupID: Int64,
        languages: Set<SubtitleLanguageCode>
    ) throws {
        let resolvedLanguages = languages.isEmpty ? Set([SubtitleLanguageCode.unknown]) : languages
        let statement = try database.prepare(
            """
            INSERT INTO subtitle_cue_group_languages(cue_group_id, language_code)
            VALUES (?, ?);
            """
        )
        for language in resolvedLanguages.sorted(by: { $0.rawValue < $1.rawValue }) {
            try statement.reset()
            try statement.clearBindings()
            try statement.bind(cueGroupID, at: 1)
            try statement.bind(language.rawValue, at: 2)
            try statement.run()
        }
    }

    private func subtitleLanguageDetectionCodes(
        detectionID: Int64
    ) throws -> Set<SubtitleLanguageCode> {
        let statement = try database.prepare(
            """
            SELECT language_code
            FROM subtitle_language_detection_codes
            WHERE detection_id = ?
            ORDER BY language_code ASC;
            """
        )
        try statement.bind(detectionID, at: 1)

        var languages = Set<SubtitleLanguageCode>()
        while try statement.step() {
            if let language = SubtitleLanguageCode(rawValue: statement.stringColumn(0)) {
                languages.insert(language)
            }
        }

        return languages.isEmpty ? [.unknown] : languages
    }

    private func subtitleLanguageDetectionDistribution(
        detectionID: Int64
    ) throws -> [SubtitleLanguageDistribution] {
        let statement = try database.prepare(
            """
            SELECT language_code, share
            FROM subtitle_language_detection_distribution
            WHERE detection_id = ?
            ORDER BY rank ASC, language_code ASC;
            """
        )
        try statement.bind(detectionID, at: 1)

        var distribution: [SubtitleLanguageDistribution] = []
        while try statement.step() {
            guard let language = SubtitleLanguageCode(rawValue: statement.stringColumn(0)) else {
                continue
            }
            distribution.append(
                SubtitleLanguageDistribution(
                    language: language,
                    share: statement.nullableDoubleColumn(1) ?? 0
                )
            )
        }

        return distribution
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

    private func insertASSFontReferenceManifest(
        subtitleFileID: Int64,
        referencedFontCount: Int
    ) throws {
        let statement = try database.prepare(
            """
            INSERT INTO ass_font_reference_manifests(
                subtitle_file_id,
                algorithm_version,
                referenced_font_count,
                extracted_at
            )
            VALUES (?, ?, ?, ?);
            """
        )

        try statement.bind(subtitleFileID, at: 1)
        try statement.bind(ASSFontIntentExtractor.cacheAlgorithmVersion, at: 2)
        try statement.bind(referencedFontCount, at: 3)
        try statement.bind(ISO8601DateFormatter().string(from: Date()), at: 4)
        try statement.run()
    }

    private func insertASSFontReference(
        subtitleFileID: Int64,
        reference: ASSFontReferenceIntent
    ) throws {
        let statement = try database.prepare(
            """
            INSERT INTO ass_font_references(
                subtitle_file_id,
                font_name,
                source_location,
                occurrence_count,
                first_occurrence_order,
                algorithm_version
            )
            VALUES (?, ?, ?, ?, ?, ?);
            """
        )

        try statement.bind(subtitleFileID, at: 1)
        try statement.bind(reference.fontName, at: 2)
        try statement.bind(reference.source.rawValue, at: 3)
        try statement.bind(reference.occurrenceCount, at: 4)
        try statement.bind(reference.firstOccurrenceOrder, at: 5)
        try statement.bind(ASSFontIntentExtractor.cacheAlgorithmVersion, at: 6)
        try statement.run()
    }

    private func insertFTSRow(
        rowID: Int64? = nil,
        cueGroupID: Int64,
        content: String
    ) throws {
        let statement: SQLiteStatement
        if let rowID {
            statement = try database.prepare(
                """
                INSERT INTO subtitle_cue_groups_fts(rowid, content, cue_group_id)
                VALUES (?, ?, ?);
                """
            )
            try statement.bind(rowID, at: 1)
            try statement.bind(Self.segmentCJK(content), at: 2)
            try statement.bind(cueGroupID, at: 3)
        } else {
            statement = try database.prepare(
                """
                INSERT INTO subtitle_cue_groups_fts(content, cue_group_id)
                VALUES (?, ?);
                """
            )
            try statement.bind(Self.segmentCJK(content), at: 1)
            try statement.bind(cueGroupID, at: 2)
        }
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
            try rebuildFTSRowsInProductOrder()
            try database.execute("COMMIT")
            clearSearchResultCache()
        } catch {
            try? database.execute("ROLLBACK")
            throw error
        }
    }

    private func rebuildFTSRowsInProductOrder() throws {
        try requireCompleteSearchOrderRows(pathPrefixes: nil, subtitlePath: nil)
        try database.execute("DELETE FROM subtitle_cue_groups_fts;")

        var rows: [(cueGroupID: Int64, content: String)] = []
        let statement = try database.prepare(
            """
            SELECT g.id, g.search_content
            FROM subtitle_cue_groups g
            JOIN subtitle_files sf ON sf.id = g.subtitle_file_id
            JOIN subtitle_search_order_rows sor ON sor.subtitle_path = sf.subtitle_path
            ORDER BY sor.display_title COLLATE NOCASE ASC,
                     sf.subtitle_path COLLATE NOCASE ASC,
                     g.start_ms ASC,
                     g.end_ms ASC,
                     g.id ASC;
            """
        )

        while try statement.step() {
            rows.append((statement.int64Column(0), statement.stringColumn(1)))
        }

        for (index, row) in rows.enumerated() {
            try insertFTSRow(
                rowID: Int64(index + 1),
                cueGroupID: row.cueGroupID,
                content: row.content
            )
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
        let deleteLanguageDetectionDistribution = try database.prepare(
            """
            DELETE FROM subtitle_language_detection_distribution
            WHERE detection_id IN (
                SELECT d.id
                FROM subtitle_language_detections d
                JOIN subtitle_files sf ON sf.id = d.subtitle_file_id
                WHERE sf.subtitle_path = ?
            );
            """
        )
        try deleteLanguageDetectionDistribution.bind(subtitlePath, at: 1)
        try deleteLanguageDetectionDistribution.run()

        let deleteLanguageDetectionCodes = try database.prepare(
            """
            DELETE FROM subtitle_language_detection_codes
            WHERE detection_id IN (
                SELECT d.id
                FROM subtitle_language_detections d
                JOIN subtitle_files sf ON sf.id = d.subtitle_file_id
                WHERE sf.subtitle_path = ?
            );
            """
        )
        try deleteLanguageDetectionCodes.bind(subtitlePath, at: 1)
        try deleteLanguageDetectionCodes.run()

        let deleteLanguageDetections = try database.prepare(
            """
            DELETE FROM subtitle_language_detections
            WHERE subtitle_file_id IN (
                SELECT id
                FROM subtitle_files
                WHERE subtitle_path = ?
            );
            """
        )
        try deleteLanguageDetections.bind(subtitlePath, at: 1)
        try deleteLanguageDetections.run()

        let deleteLanguageManifests = try database.prepare(
            """
            DELETE FROM subtitle_language_manifests
            WHERE subtitle_file_id IN (
                SELECT id
                FROM subtitle_files
                WHERE subtitle_path = ?
            );
            """
        )
        try deleteLanguageManifests.bind(subtitlePath, at: 1)
        try deleteLanguageManifests.run()

        let deleteCueGroupLanguages = try database.prepare(
            """
            DELETE FROM subtitle_cue_group_languages
            WHERE cue_group_id IN (
                SELECT g.id
                FROM subtitle_cue_groups g
                JOIN subtitle_files sf ON sf.id = g.subtitle_file_id
                WHERE sf.subtitle_path = ?
            );
            """
        )
        try deleteCueGroupLanguages.bind(subtitlePath, at: 1)
        try deleteCueGroupLanguages.run()

        let deleteASSFontReferences = try database.prepare(
            """
            DELETE FROM ass_font_references
            WHERE subtitle_file_id IN (
                SELECT id
                FROM subtitle_files
                WHERE subtitle_path = ?
            );
            """
        )
        try deleteASSFontReferences.bind(subtitlePath, at: 1)
        try deleteASSFontReferences.run()

        let deleteASSFontReferenceManifests = try database.prepare(
            """
            DELETE FROM ass_font_reference_manifests
            WHERE subtitle_file_id IN (
                SELECT id
                FROM subtitle_files
                WHERE subtitle_path = ?
            );
            """
        )
        try deleteASSFontReferenceManifests.bind(subtitlePath, at: 1)
        try deleteASSFontReferenceManifests.run()

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

        let deleteSearchOrderRows = try database.prepare(
            "DELETE FROM subtitle_search_order_rows WHERE subtitle_path = ?;"
        )
        try deleteSearchOrderRows.bind(subtitlePath, at: 1)
        try deleteSearchOrderRows.run()

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
            DROP TABLE IF EXISTS subtitle_cue_group_languages;
            DROP TABLE IF EXISTS subtitle_language_detection_distribution;
            DROP TABLE IF EXISTS subtitle_language_detection_codes;
            DROP TABLE IF EXISTS subtitle_language_detections;
            DROP TABLE IF EXISTS subtitle_language_manifests;
            DROP TABLE IF EXISTS subtitle_cue_lines;
            DROP TABLE IF EXISTS subtitle_cue_groups;
            DROP TABLE IF EXISTS ass_font_references;
            DROP TABLE IF EXISTS ass_font_reference_manifests;
            DROP TABLE IF EXISTS ass_render_segments;
            DROP TABLE IF EXISTS subtitle_video_matches;
            DROP TABLE IF EXISTS video_files;
            DROP TABLE IF EXISTS subtitle_search_order_rows;
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

    private func aiChunkCacheEntry(from statement: SQLiteStatement) throws -> AIChunkCacheEntry {
        let key = AIChunkCacheKey(
            normalizedSentence: statement.stringColumn(0),
            provider: statement.stringColumn(1),
            model: statement.stringColumn(2),
            promptVersion: statement.stringColumn(3)
        )
        let chunks = try Self.decodeAIChunks(statement.stringColumn(4))

        return AIChunkCacheEntry(
            key: key,
            chunks: chunks,
            cacheDate: statement.stringColumn(5)
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

    private static func validateAIChunkCacheKey(_ key: AIChunkCacheKey) throws {
        guard !key.normalizedSentence.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AIChunkCacheError.emptyNormalizedSentence
        }
        guard !key.provider.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AIChunkCacheError.emptyProvider
        }
        guard !key.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AIChunkCacheError.emptyModel
        }
        guard !key.promptVersion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AIChunkCacheError.emptyPromptVersion
        }
    }

    private static func validateAIChunkCacheChunks(_ chunks: [AIChunkItem]) throws {
        guard !chunks.isEmpty,
              chunks.allSatisfy({ !$0.item.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
        else {
            throw AIChunkCacheError.emptyChunks
        }
    }

    private static func encodeAIChunks(_ chunks: [AIChunkItem]) throws -> String {
        String(decoding: try JSONEncoder().encode(chunks), as: UTF8.self)
    }

    private static func decodeAIChunks(_ chunksJSON: String) throws -> [AIChunkItem] {
        guard let data = chunksJSON.data(using: .utf8) else {
            throw SQLiteDatabaseError.stepFailed("AI chunk cache entry contains invalid UTF-8 JSON")
        }

        return try JSONDecoder().decode([AIChunkItem].self, from: data)
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

    private static func folderPath(forSubtitlePath subtitlePath: String) -> String {
        URL(fileURLWithPath: subtitlePath)
            .deletingLastPathComponent()
            .standardizedFileURL
            .path
    }

    private static func subtitlePathPrefix(forFolderPath folderPath: String) -> String {
        folderPath.hasSuffix("/") ? folderPath : folderPath + "/"
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
