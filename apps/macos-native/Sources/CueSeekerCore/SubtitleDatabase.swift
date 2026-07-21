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

public struct SubtitleDatabaseEntryIndexItem: Equatable, Sendable {
    public let id: Int64
    public let startMilliseconds: Int
    public let endMilliseconds: Int

    public init(id: Int64, startMilliseconds: Int, endMilliseconds: Int) {
        self.id = id
        self.startMilliseconds = startMilliseconds
        self.endMilliseconds = endMilliseconds
    }
}

public struct CueContent: Equatable, Sendable, Identifiable {
    public let cueID: Int64
    public let cueGroupID: Int64
    public let cueEventIndex: Int
    public let cueDisplayOrder: Int
    public let primaryGroupIndex: Int
    public let subtitlePath: String
    public let subtitleFormat: SubtitleFormat
    public let videoPath: String
    public let videoName: String
    public let displayTitle: String
    public let timeRange: String
    public let startMilliseconds: Int
    public let endMilliseconds: Int
    public let content: String
    public let cueLines: [String]
    public let cueGroupLines: [String]
    public let languages: Set<SubtitleLanguageCode>
    public let speakers: Set<String>

    public var id: Int64 { cueID }

    public init(
        cueID: Int64,
        cueGroupID: Int64,
        cueEventIndex: Int,
        cueDisplayOrder: Int,
        primaryGroupIndex: Int,
        subtitlePath: String,
        subtitleFormat: SubtitleFormat,
        videoPath: String,
        videoName: String,
        displayTitle: String,
        timeRange: String,
        startMilliseconds: Int,
        endMilliseconds: Int,
        content: String,
        cueLines: [String],
        cueGroupLines: [String],
        languages: Set<SubtitleLanguageCode>,
        speakers: Set<String>
    ) {
        self.cueID = cueID
        self.cueGroupID = cueGroupID
        self.cueEventIndex = cueEventIndex
        self.cueDisplayOrder = cueDisplayOrder
        self.primaryGroupIndex = max(0, primaryGroupIndex)
        self.subtitlePath = subtitlePath
        self.subtitleFormat = subtitleFormat
        self.videoPath = videoPath
        self.videoName = videoName
        self.displayTitle = displayTitle
        self.timeRange = timeRange.isEmpty
            ? SubtitleCueTimeRangeDisplay.text(
                startMilliseconds: startMilliseconds,
                endMilliseconds: endMilliseconds
            )
            : timeRange
        self.startMilliseconds = startMilliseconds
        self.endMilliseconds = endMilliseconds
        self.content = content
        self.cueLines = cueLines
        self.cueGroupLines = cueGroupLines.isEmpty ? [content] : cueGroupLines
        self.languages = languages.isEmpty ? [.unknown] : languages
        self.speakers = speakers
    }
}

public struct SubtitleSearchResult: Equatable, Sendable {
    public let entryID: Int64
    public let cueGroupID: Int64
    public let cueEventIndex: Int
    public let cueDisplayOrder: Int
    public let primaryGroupIndex: Int
    public let subtitlePath: String
    public let subtitleFormat: SubtitleFormat
    public let videoPath: String
    public let videoName: String
    public let displayTitle: String
    public let timeRange: String
    public let startMilliseconds: Int
    public let endMilliseconds: Int
    public let content: String
    public let cueLines: [String]
    public let cueGroupLines: [String]
    public let languages: Set<SubtitleLanguageCode>
    public let speakers: Set<String>
    public var searchRank: Int

    public var cueIdentity: SubtitleCueIdentity {
        SubtitleCueIdentity(
            eventIndex: cueEventIndex,
            startMilliseconds: startMilliseconds,
            endMilliseconds: endMilliseconds
        )
    }

    public init(
        entryID: Int64,
        cueGroupID: Int64? = nil,
        cueEventIndex: Int = 0,
        cueDisplayOrder: Int = 0,
        primaryGroupIndex: Int = 0,
        subtitlePath: String,
        subtitleFormat: SubtitleFormat,
        videoPath: String,
        videoName: String,
        displayTitle: String = "",
        timeRange: String = "",
        startMilliseconds: Int,
        endMilliseconds: Int,
        content: String,
        cueLines: [String],
        cueGroupLines: [String]? = nil,
        languages: Set<SubtitleLanguageCode> = [.unknown],
        speakers: Set<String> = [],
        searchRank: Int = 0
    ) {
        self.entryID = entryID
        self.cueGroupID = cueGroupID ?? entryID
        self.cueEventIndex = cueEventIndex
        self.cueDisplayOrder = cueDisplayOrder
        self.primaryGroupIndex = max(0, primaryGroupIndex)
        self.subtitlePath = subtitlePath
        self.subtitleFormat = subtitleFormat
        self.videoPath = videoPath
        self.videoName = videoName
        self.displayTitle = displayTitle
        self.timeRange = timeRange.isEmpty
            ? SubtitleCueTimeRangeDisplay.text(
                startMilliseconds: startMilliseconds,
                endMilliseconds: endMilliseconds
            )
            : timeRange
        self.startMilliseconds = startMilliseconds
        self.endMilliseconds = endMilliseconds
        self.content = content
        self.cueLines = cueLines
        self.cueGroupLines = cueGroupLines ?? (cueLines.isEmpty ? [content] : cueLines)
        self.languages = languages.isEmpty ? [.unknown] : languages
        self.speakers = speakers
        self.searchRank = searchRank
    }

    public init(cueContent: CueContent, searchRank: Int = 0) {
        self.init(
            entryID: cueContent.cueID,
            cueGroupID: cueContent.cueGroupID,
            cueEventIndex: cueContent.cueEventIndex,
            cueDisplayOrder: cueContent.cueDisplayOrder,
            primaryGroupIndex: cueContent.primaryGroupIndex,
            subtitlePath: cueContent.subtitlePath,
            subtitleFormat: cueContent.subtitleFormat,
            videoPath: cueContent.videoPath,
            videoName: cueContent.videoName,
            displayTitle: cueContent.displayTitle,
            timeRange: cueContent.timeRange,
            startMilliseconds: cueContent.startMilliseconds,
            endMilliseconds: cueContent.endMilliseconds,
            content: cueContent.content,
            cueLines: cueContent.cueLines,
            cueGroupLines: cueContent.cueGroupLines,
            languages: cueContent.languages,
            speakers: cueContent.speakers,
            searchRank: searchRank
        )
    }

    public var cueContent: CueContent {
        CueContent(
            cueID: entryID,
            cueGroupID: cueGroupID,
            cueEventIndex: cueEventIndex,
            cueDisplayOrder: cueDisplayOrder,
            primaryGroupIndex: primaryGroupIndex,
            subtitlePath: subtitlePath,
            subtitleFormat: subtitleFormat,
            videoPath: videoPath,
            videoName: videoName,
            displayTitle: displayTitle,
            timeRange: timeRange,
            startMilliseconds: startMilliseconds,
            endMilliseconds: endMilliseconds,
            content: content,
            cueLines: cueLines,
            cueGroupLines: cueGroupLines,
            languages: languages,
            speakers: speakers
        )
    }
}

public enum SubtitleCueTimeRangeDisplay {
    public static func text(startMilliseconds: Int, endMilliseconds: Int) -> String {
        let start = TimeParts(milliseconds: startMilliseconds)
        let end = TimeParts(milliseconds: max(startMilliseconds, endMilliseconds))
        if start.hours == 0, end.hours == 0 {
            return "\(start.shortText) - \(end.shortText)"
        }
        return "\(start.fullText) - \(end.fullText)"
    }

    private struct TimeParts {
        let hours: Int
        let minutes: Int
        let seconds: Int

        init(milliseconds: Int) {
            let totalSeconds = max(0, milliseconds) / 1_000
            hours = totalSeconds / 3_600
            minutes = (totalSeconds % 3_600) / 60
            seconds = totalSeconds % 60
        }

        var shortText: String {
            String(format: "%02d:%02d", minutes, seconds)
        }

        var fullText: String {
            String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        }
    }
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
    public let results: [SubtitleSearchResult]
    public let cueIDs: [Int64]

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
        fileSummaries: [SubtitleSearchFileSummary],
        results: [SubtitleSearchResult] = [],
        cueIDs: [Int64] = []
    ) {
        self.countSnapshot = countSnapshot
        self.fileSummaries = fileSummaries
        self.results = results
        self.cueIDs = cueIDs
    }
}

public typealias SubtitleSearchProgressSink = @Sendable (SubtitleSearchProgressSnapshot) -> Void

public enum SubtitleSearchPageMode: String, Equatable, Sendable, Codable {
    case exact
    case visibleWindow
}

public enum SubtitleSearchLanguageFilter: String, CaseIterable, Codable, Hashable, Sendable {
    case all
    case japanese = "ja"
    case english = "en"
    case chinese = "zh"
    case simplifiedChinese = "zh-Hans"
    case traditionalChinese = "zh-Hant"

    public var matchingLanguageCodes: Set<SubtitleLanguageCode> {
        switch self {
        case .all:
            return Set(SubtitleLanguageCode.allCases)
        case .japanese:
            return [.japanese]
        case .english:
            return [.english]
        case .chinese:
            return [.chinese, .simplifiedChinese, .traditionalChinese]
        case .simplifiedChinese:
            return [.chinese, .simplifiedChinese]
        case .traditionalChinese:
            return [.chinese, .traditionalChinese]
        }
    }
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

public enum ShioriTagValidationError: Error, Equatable {
    case emptyName
    case nameTooLong(maximumCharacters: Int)
    case invalidCharacters
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
    public let videoFileID: Int64?
    public let subtitleFileID: Int64?
    public let videoPath: String
    public let videoName: String
    public let duration: Double?
    public let subtitlePath: String
    public let subtitleFormat: SubtitleFormat

    public var id: String {
        videoPath
    }

    public init(
        videoFileID: Int64? = nil,
        subtitleFileID: Int64? = nil,
        videoPath: String,
        videoName: String,
        duration: Double?,
        subtitlePath: String,
        subtitleFormat: SubtitleFormat
    ) {
        self.videoFileID = videoFileID
        self.subtitleFileID = subtitleFileID
        self.videoPath = videoPath
        self.videoName = videoName
        self.duration = duration
        self.subtitlePath = subtitlePath
        self.subtitleFormat = subtitleFormat
    }
}

public enum LibraryCoverStatus: String, Sendable {
    case generated
    case failed
}

public enum LibraryCoverDisplayProfileVersion: Sendable {
    public static let current = 1
}

public struct LibraryCoverEligibleVideo: Equatable, Sendable, Identifiable {
    public let videoFileID: Int64
    public let videoPath: String
    public let videoName: String
    public let fileSize: Int64?
    public let duration: Double?
    public let subtitlePath: String
    public let subtitleFormat: SubtitleFormat
    public let folderPath: String

    public var id: Int64 {
        videoFileID
    }

    var libraryVideo: LibraryVideo {
        LibraryVideo(
            videoFileID: videoFileID,
            videoPath: videoPath,
            videoName: videoName,
            duration: duration,
            subtitlePath: subtitlePath,
            subtitleFormat: subtitleFormat
        )
    }
}

public struct LibraryVideoCover: Equatable, Sendable {
    public let videoFileID: Int64
    public let masterCoverPath: String
    public let displayCoverPath: String?
    public let displayProfileVersion: Int?
    public let sourceTimeMilliseconds: Int
    public let score: Double?
    public let algorithmVersion: Int
    public let generatedFileSize: Int64?
    public let generatedDuration: Double?
    public let status: LibraryCoverStatus
    public let errorMessage: String?
    public let generatedAt: String
}

public struct LibraryCoverDisplayCandidate: Equatable, Sendable, Identifiable {
    public let videoFileID: Int64
    public let videoPath: String
    public let masterCoverPath: String
    public let displayCoverPath: String?
    public let displayProfileVersion: Int?

    public var id: Int64 {
        videoFileID
    }
}

public struct LibraryFolderCover: Equatable, Sendable {
    public let folderPath: String
    public let masterCoverPath: String
    public let sourceVideoFileID: Int64
    public let generatedAt: String
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
    public let startedAt: String?
    public let completedAt: String?
    public let updatedAt: String
}

public struct SubtitlePlaybackFinishMetadata: Equatable, Sendable {
    public let primaryStyles: [String]
    public let primaryStyleLastEndMilliseconds: Int?
    public let lastSubtitleEndMilliseconds: Int?

    public init(
        primaryStyles: [String],
        primaryStyleLastEndMilliseconds: Int?,
        lastSubtitleEndMilliseconds: Int?
    ) {
        self.primaryStyles = primaryStyles
        self.primaryStyleLastEndMilliseconds = primaryStyleLastEndMilliseconds
        self.lastSubtitleEndMilliseconds = lastSubtitleEndMilliseconds
    }

    public func finishPointMilliseconds(videoDuration: Double) -> Int? {
        guard videoDuration.isFinite, videoDuration > 0 else {
            return nil
        }

        let videoDurationMilliseconds = Int((videoDuration * 1_000).rounded(.down))
        let thresholdMilliseconds = videoDuration * 1_000 * 0.8

        if let primaryStyleLastEndMilliseconds,
           Double(primaryStyleLastEndMilliseconds) >= thresholdMilliseconds {
            return primaryStyleLastEndMilliseconds
        }

        if let lastSubtitleEndMilliseconds,
           Double(lastSubtitleEndMilliseconds) >= thresholdMilliseconds {
            return lastSubtitleEndMilliseconds
        }

        return videoDurationMilliseconds
    }

    public static func finishPointMilliseconds(
        metadata: SubtitlePlaybackFinishMetadata?,
        videoDuration: Double
    ) -> Int? {
        guard videoDuration.isFinite, videoDuration > 0 else {
            return nil
        }

        guard let metadata else {
            return Int((videoDuration * 1_000).rounded(.down))
        }

        return metadata.finishPointMilliseconds(videoDuration: videoDuration)
    }
}

public enum LibraryWatchState: String, Equatable, Sendable {
    case unwatched
    case watching
    case finished

    public init(positionMilliseconds: Int, duration _: Double?) {
        self = max(0, positionMilliseconds) > 0 ? .watching : .unwatched
    }

    public init(
        positionMilliseconds: Int,
        duration _: Double?,
        startedAt: String?,
        completedAt: String?
    ) {
        if completedAt != nil {
            self = .finished
            return
        }

        if startedAt != nil {
            self = .watching
            return
        }

        self = .unwatched
    }
}

public enum SubtitleSearchWatchStateFilter: String, Equatable, Sendable {
    case all
    case onlyFinished
    case watchingAndFinished

    var states: [LibraryWatchState] {
        switch self {
        case .all:
            []
        case .onlyFinished:
            [.finished]
        case .watchingAndFinished:
            [.watching, .finished]
        }
    }
}

public struct RecentLibraryWatchingPresentation: Equatable, Sendable, Identifiable {
    public let videoPath: String
    public let videoName: String
    public let duration: Double?
    public let subtitlePath: String
    public let subtitleFormat: SubtitleFormat
    public let displayTitle: String
    public let fileExtension: String
    public let folderPath: String
    public let folderTitle: String
    public let episodeNumber: Int
    public let positionMilliseconds: Int
    public let playbackDuration: Double?
    public let startedAt: String?
    public let completedAt: String?
    public let updatedAt: String
    public let coverPath: String?
    public let coverRevision: String?

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

    public var watchState: LibraryWatchState {
        LibraryWatchState(
            positionMilliseconds: positionMilliseconds,
            duration: playbackDuration ?? duration,
            startedAt: startedAt,
            completedAt: completedAt
        )
    }
}

public struct CompleteLibraryVideoPresentation: Equatable, Sendable, Identifiable {
    public let videoPath: String
    public let videoName: String
    public let fileSize: Int64?
    public let videoCodec: String?
    public let videoWidth: Int?
    public let videoHeight: Int?
    public let frameRate: Double?
    public let duration: Double?
    public let subtitlePath: String
    public let subtitleFormat: SubtitleFormat
    public let displayTitle: String
    public let fileExtension: String
    public let episodeNumber: Int
    public let positionMilliseconds: Int
    public let playbackDuration: Double?
    public let startedAt: String?
    public let completedAt: String?
    public let historyUpdatedAt: String?
    public let coverPath: String?
    public let coverRevision: String?

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

    public var watchState: LibraryWatchState {
        LibraryWatchState(
            positionMilliseconds: positionMilliseconds,
            duration: playbackDuration ?? duration,
            startedAt: startedAt,
            completedAt: completedAt
        )
    }
}

public struct CompleteLibraryFolderSummaryPresentation: Equatable, Sendable, Identifiable {
    public let folderPath: String
    public let folderTitle: String
    public let coverPath: String?
    public let coverRevision: String?
    public let episodeCount: Int

    public var id: String {
        folderPath
    }
}

public struct CompleteLibraryFolderDetailPresentation: Equatable, Sendable, Identifiable {
    public let folderPath: String
    public let folderTitle: String
    public let videos: [CompleteLibraryVideoPresentation]

    public var id: String {
        folderPath
    }
}

public struct CompleteLibraryFolderPresentation: Equatable, Sendable, Identifiable {
    public let folderPath: String
    public let folderTitle: String
    public let folderCoverPath: String?
    public let folderCoverRevision: String?
    public let lastWatchedEpisodeNumber: Int?
    public let lastWatchedVideoPath: String?
    public let videos: [CompleteLibraryVideoPresentation]

    public var id: String {
        folderPath
    }

    public var continueWatchingVideo: CompleteLibraryVideoPresentation? {
        lastWatchedVideoPath.flatMap { videoPath in
            videos.first { $0.videoPath == videoPath }
        }
            ?? videos.first { $0.watchState == .unwatched }
            ?? videos.first
    }
}

public enum ShioriListIdentity {
    public static let defaultListID: Int64 = 1
}

public struct ShioriList: Equatable, Sendable, Identifiable {
    public let id: Int64
    public let name: String
    public let createdAt: String

    public init(id: Int64, name: String, createdAt: String) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
    }
}

public struct ShioriRelation: Equatable, Sendable, Identifiable {
    public let id: Int64
    public let listID: Int64
    public let cueID: Int64
    public let createdAt: String

    public init(id: Int64, listID: Int64, cueID: Int64, createdAt: String) {
        self.id = id
        self.listID = listID
        self.cueID = cueID
        self.createdAt = createdAt
    }
}

public struct ShioriResidentSnapshot: Equatable, Sendable {
    public let relations: [ShioriRelation]
    public let cueContents: [CueContent]
    public let tagsByShioriID: [Int64: [ShioriTag]]

    public init(
        relations: [ShioriRelation],
        cueContents: [CueContent],
        tagsByShioriID: [Int64: [ShioriTag]]
    ) {
        self.relations = relations
        self.cueContents = cueContents
        self.tagsByShioriID = tagsByShioriID
    }
}

/// A resolved Shiori value used by playback and legacy presentation call sites.
/// Persisted Shiori state is represented by `ShioriRelation`; every other field
/// here is resolved from the referenced current Cue.
public struct Shiori: Equatable, Sendable, Identifiable {
    public let id: Int64
    public let subtitlePath: String
    public let subtitleFormat: SubtitleFormat
    public let videoPath: String
    public let videoName: String
    public let timeRange: String
    public let startMilliseconds: Int
    public let endMilliseconds: Int
    public let cueEventIndex: Int?
    public let cueDisplayOrder: Int?
    public let content: String
    public let isValid: Bool
    public let createdAt: String

    public init(
        id: Int64,
        subtitlePath: String,
        subtitleFormat: SubtitleFormat,
        videoPath: String,
        videoName: String,
        timeRange: String = "",
        startMilliseconds: Int,
        endMilliseconds: Int,
        cueEventIndex: Int? = nil,
        cueDisplayOrder: Int? = nil,
        content: String,
        isValid: Bool,
        createdAt: String
    ) {
        self.id = id
        self.subtitlePath = subtitlePath
        self.subtitleFormat = subtitleFormat
        self.videoPath = videoPath
        self.videoName = videoName
        self.timeRange = timeRange.isEmpty
            ? SubtitleCueTimeRangeDisplay.text(
                startMilliseconds: startMilliseconds,
                endMilliseconds: endMilliseconds
            )
            : timeRange
        self.startMilliseconds = startMilliseconds
        self.endMilliseconds = endMilliseconds
        self.cueEventIndex = cueEventIndex
        self.cueDisplayOrder = cueDisplayOrder
        self.content = content
        self.isValid = isValid
        self.createdAt = createdAt
    }

    public init(relation: ShioriRelation, cueContent: CueContent) {
        self.init(
            id: relation.id,
            subtitlePath: cueContent.subtitlePath,
            subtitleFormat: cueContent.subtitleFormat,
            videoPath: cueContent.videoPath,
            videoName: cueContent.videoName,
            timeRange: cueContent.timeRange,
            startMilliseconds: cueContent.startMilliseconds,
            endMilliseconds: cueContent.endMilliseconds,
            cueEventIndex: cueContent.cueEventIndex,
            cueDisplayOrder: cueContent.cueDisplayOrder,
            content: cueContent.content,
            isValid: true,
            createdAt: relation.createdAt
        )
    }

    public var cueIdentity: SubtitleCueIdentity? {
        guard let cueEventIndex else {
            return nil
        }
        return SubtitleCueIdentity(
            eventIndex: cueEventIndex,
            startMilliseconds: startMilliseconds,
            endMilliseconds: endMilliseconds
        )
    }

    public var cueLines: [String] {
        content
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

public struct ShioriTag: Equatable, Sendable, Identifiable {
    public let id: Int64
    public let name: String
    public let createdAt: String

    public init(id: Int64, name: String, createdAt: String) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
    }
}

public struct ShioriTagDeletionResult: Equatable, Sendable {
    public let tagID: Int64
    public let didDelete: Bool
    public let affectedShioriIDs: [Int64]

    public init(tagID: Int64, didDelete: Bool, affectedShioriIDs: [Int64]) {
        self.tagID = tagID
        self.didDelete = didDelete
        self.affectedShioriIDs = affectedShioriIDs
    }
}

public struct ShioriCuePresentation: Equatable, Sendable {
    public let cueID: Int64?
    public let cueGroupID: Int64?
    public let primaryGroupIndex: Int?
    public let cueGroupTexts: [String]
    public let languages: Set<SubtitleLanguageCode>
    public let speakers: Set<String>

    public init(
        cueID: Int64?,
        cueGroupID: Int64?,
        primaryGroupIndex: Int?,
        cueGroupTexts: [String],
        languages: Set<SubtitleLanguageCode>,
        speakers: Set<String>
    ) {
        self.cueID = cueID
        self.cueGroupID = cueGroupID
        self.primaryGroupIndex = primaryGroupIndex
        self.cueGroupTexts = cueGroupTexts
        self.languages = languages.isEmpty ? [.unknown] : languages
        self.speakers = speakers
    }

    public init(cueContent: CueContent) {
        self.init(
            cueID: cueContent.cueID,
            cueGroupID: cueContent.cueGroupID,
            primaryGroupIndex: cueContent.primaryGroupIndex,
            cueGroupTexts: cueContent.cueGroupLines,
            languages: cueContent.languages,
            speakers: cueContent.speakers
        )
    }
}

public struct ShioriPage: Equatable, Sendable {
    public let shioris: [Shiori]
    public let totalCount: Int
    public let languagesByShioriID: [Int64: Set<SubtitleLanguageCode>]
    public let displayTitlesByShioriID: [Int64: String]
    public let cuePresentationsByShioriID: [Int64: ShioriCuePresentation]

    public init(
        shioris: [Shiori],
        totalCount: Int,
        languagesByShioriID: [Int64: Set<SubtitleLanguageCode>],
        displayTitlesByShioriID: [Int64: String] = [:],
        cuePresentationsByShioriID: [Int64: ShioriCuePresentation] = [:]
    ) {
        self.shioris = shioris
        self.totalCount = totalCount
        self.languagesByShioriID = languagesByShioriID
        self.displayTitlesByShioriID = displayTitlesByShioriID
        self.cuePresentationsByShioriID = cuePresentationsByShioriID
    }
}

public struct ShioriTableIDIndex: Equatable, Sendable {
    public let shioriIDs: [Int64]

    public init(shioriIDs: [Int64]) {
        self.shioriIDs = shioriIDs
    }

    public var totalCount: Int {
        shioriIDs.count
    }
}

public enum ShioriNavigationDirection: Equatable, Sendable {
    case previous
    case next
}

public struct SubtitleSearchPage: Equatable, Sendable {
    public let results: [SubtitleSearchResult]
    public let renderableResults: [SubtitleSearchResult]
    public let cueIDs: [Int64]
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
        renderableResults: [SubtitleSearchResult]? = nil,
        cueIDs: [Int64]? = nil,
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
        self.renderableResults = renderableResults ?? results
        self.cueIDs = cueIDs ?? results.map(\.entryID)
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

public struct SubtitleSearchResultIDIndexWindow: Equatable, Sendable {
    public let cueIDs: [Int64]
    public let offset: Int
    public let totalCount: Int
    public let fileSummaries: [SubtitleSearchFileSummary]
    public let countSnapshot: SubtitleSearchCountSnapshot
    public let appliedCursor: SubtitleSearchCursor
    public let nextCursor: SubtitleSearchCursor?

    public init(
        cueIDs: [Int64],
        offset: Int,
        totalCount: Int,
        fileSummaries: [SubtitleSearchFileSummary],
        countSnapshot: SubtitleSearchCountSnapshot,
        appliedCursor: SubtitleSearchCursor,
        nextCursor: SubtitleSearchCursor?
    ) {
        self.cueIDs = cueIDs
        self.offset = offset
        self.totalCount = totalCount
        self.fileSummaries = fileSummaries
        self.countSnapshot = countSnapshot
        self.appliedCursor = appliedCursor
        self.nextCursor = nextCursor
    }
}

private struct SearchResultIDIndex: Sendable {
    let cueIDs: [Int64]
    let fileSummaries: [SubtitleSearchFileSummary]
    let countSnapshot: SubtitleSearchCountSnapshot
}

public struct SearchNavigationAnchor: Equatable, Sendable {
    public let selectedEntryID: Int64?
    public let selectedSearchRank: Int?
    public let videoPath: String?
    public let subtitlePath: String?
    public let currentMilliseconds: Int

    public init(
        selectedEntryID: Int64?,
        selectedSearchRank: Int? = nil,
        videoPath: String?,
        subtitlePath: String?,
        currentMilliseconds: Int
    ) {
        self.selectedEntryID = selectedEntryID
        self.selectedSearchRank = selectedSearchRank
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

    public init(
        totalCount: Int,
        currentIndex: Int?,
        neighborhood: [SubtitleSearchResult],
        previous: SubtitleSearchResult?,
        current: SubtitleSearchResult?,
        next: SubtitleSearchResult?
    ) {
        self.totalCount = totalCount
        self.currentIndex = currentIndex
        self.neighborhood = neighborhood
        self.previous = previous
        self.current = current
        self.next = next
    }

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

public struct SubtitleCueIdentity: Equatable, Hashable, Sendable {
    public let eventIndex: Int
    public let startMilliseconds: Int
    public let endMilliseconds: Int

    public init(
        eventIndex: Int,
        startMilliseconds: Int,
        endMilliseconds: Int
    ) {
        let resolvedStartMilliseconds = max(0, startMilliseconds)
        self.eventIndex = eventIndex
        self.startMilliseconds = resolvedStartMilliseconds
        self.endMilliseconds = max(resolvedStartMilliseconds, endMilliseconds)
    }
}

public struct SubtitleCueLineRecord: Equatable, Sendable {
    public let id: Int64
    public let cueGroupID: Int64
    public let line: SubtitleCueLine

    public init(id: Int64, cueGroupID: Int64, line: SubtitleCueLine) {
        self.id = id
        self.cueGroupID = cueGroupID
        self.line = line
    }
}

public struct SubtitleCueLineSpeakerAssignment: Equatable, Sendable {
    public let cueLineID: Int64
    public let speakers: Set<String>

    public init(cueLineID: Int64, speakers: Set<String>) {
        self.cueLineID = cueLineID
        self.speakers = speakers
    }
}

public struct SubtitleCueTextSelection: Equatable, Sendable {
    public let cueGroupID: Int64
    public let cueLineID: Int64?
    public let startMilliseconds: Int
    public let endMilliseconds: Int
    public let cueEventIndex: Int?
    public let cueDisplayOrder: Int?
    public let content: String

    public var text: String {
        content
    }

    public var lines: [String] {
        content.components(separatedBy: .newlines)
    }

    public var cueIdentity: SubtitleCueIdentity? {
        guard let cueEventIndex else {
            return nil
        }
        return SubtitleCueIdentity(
            eventIndex: cueEventIndex,
            startMilliseconds: startMilliseconds,
            endMilliseconds: endMilliseconds
        )
    }

    public init(
        cueGroupID: Int64,
        cueLineID: Int64? = nil,
        startMilliseconds: Int,
        endMilliseconds: Int,
        cueEventIndex: Int?,
        cueDisplayOrder: Int?,
        content: String
    ) {
        let resolvedStartMilliseconds = max(0, startMilliseconds)
        self.cueGroupID = cueGroupID
        self.cueLineID = cueLineID
        self.startMilliseconds = resolvedStartMilliseconds
        self.endMilliseconds = max(resolvedStartMilliseconds, endMilliseconds)
        self.cueEventIndex = cueEventIndex
        self.cueDisplayOrder = cueDisplayOrder
        self.content = content
    }

    public init(
        cueGroupID: Int64,
        startMilliseconds: Int,
        endMilliseconds: Int,
        lines: [String]
    ) {
        self.init(
            cueGroupID: cueGroupID,
            startMilliseconds: startMilliseconds,
            endMilliseconds: endMilliseconds,
            cueEventIndex: nil,
            cueDisplayOrder: nil,
            content: lines.joined(separator: "\n")
        )
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
    public let indexAlgorithmVersion: Int
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
    public static let currentSchemaVersion: Int = 32
    public static let configuredBusyTimeoutMilliseconds: Int = 5_000
    public static let configuredCacheSizeKibibytes: Int = SQLiteDatabase.cacheSizeKibibytes
    public static let configuredMmapSizeBytes: Int = SQLiteDatabase.mmapSizeBytes
    private static let exactSearchCandidateBatchMinimum = 5_000
    private static let searchNavigationPlaybackAnchorBatchLimit = 64

    private let path: URL
    private let database: SQLiteDatabase

    private struct LibraryPathRecord {
        let id: Int64
        let rootURL: URL
    }

    private struct MediaPathIdentity {
        let libraryID: Int64
        let relativePath: String
    }

    public init(path: URL) throws {
        self.path = path
        database = try SQLiteDatabase(path: path)
    }

    public func cueOccurrenceCount(
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

    public func cueGroupOccurrenceCount(
        for query: String,
        under folders: [URL]? = nil
    ) throws -> Int {
        try cueOccurrenceCount(for: query, under: folders)
    }

    public func clearSearchResultCache() {}

    public func searchResultCacheStats() -> SubtitleSearchResultCacheStats {
        SubtitleSearchResultCacheStats(
            entries: 0,
            hits: 0,
            misses: 0,
            stores: 0,
            invalidations: 0
        )
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

        let shioriSchemaSQL: String
        if previousVersion >= 32 {
            shioriSchemaSQL = """
            CREATE TABLE IF NOT EXISTS shiori_lists (
                id INTEGER PRIMARY KEY,
                name TEXT NOT NULL,
                created_at TEXT NOT NULL
            );

            INSERT OR IGNORE INTO shiori_lists(id, name, created_at)
            VALUES (1, 'Shiori', '1970-01-01T00:00:00Z');

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
        } else {
            shioriSchemaSQL = """
            CREATE TABLE IF NOT EXISTS shioris (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                cue_id INTEGER,
                subtitle_path TEXT NOT NULL,
                subtitle_format TEXT NOT NULL,
                start_ms INTEGER NOT NULL,
                end_ms INTEGER NOT NULL,
                cue_event_index INTEGER,
                cue_display_order INTEGER,
                video_path TEXT NOT NULL,
                video_name TEXT NOT NULL,
                content TEXT NOT NULL,
                is_valid INTEGER NOT NULL DEFAULT 1,
                created_at TEXT NOT NULL,
                UNIQUE(subtitle_path, cue_event_index, start_ms, end_ms),
                FOREIGN KEY(cue_id) REFERENCES subtitle_cue_lines(id) ON DELETE SET NULL
            );

            CREATE INDEX IF NOT EXISTS idx_shioris_subtitle_path
                ON shioris(subtitle_path);

            CREATE INDEX IF NOT EXISTS idx_shioris_order
                ON shioris(subtitle_path, start_ms, end_ms);

            CREATE INDEX IF NOT EXISTS idx_shioris_created_order
                ON shioris(created_at DESC, id DESC);
            """
        }

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

        if previousVersion < 20 {
            if try !columnExists(table: "library_playback_history", column: "started_at") {
                try database.execute(
                    """
                    ALTER TABLE library_playback_history
                    ADD COLUMN started_at TEXT;
                    """
                )
            }
            if try !columnExists(table: "library_playback_history", column: "completed_at") {
                try database.execute(
                    """
                    ALTER TABLE library_playback_history
                    ADD COLUMN completed_at TEXT;
                    """
                )
            }
            try database.execute(
                """
                UPDATE library_playback_history
                SET started_at = updated_at
                WHERE started_at IS NULL
                  AND position_ms > 0;
                """
            )
            try database.execute(
                """
                UPDATE library_playback_history
                SET completed_at = updated_at
                WHERE completed_at IS NULL
                  AND duration IS NOT NULL
                  AND duration > 0
                  AND (
                      (CAST(position_ms AS REAL) / 1000.0) >= duration * 0.95
                      OR duration - (CAST(position_ms AS REAL) / 1000.0) <= 1
                  );
                """
            )
        }

        if previousVersion < 25 {
            try database.execute(
                """
                INSERT OR IGNORE INTO library_watch_states(video_path, state, updated_at)
                SELECT video_path,
                       CASE
                           WHEN completed_at IS NOT NULL THEN 'finished'
                           WHEN started_at IS NOT NULL OR position_ms > 0 THEN 'watching'
                           ELSE 'unwatched'
                       END,
                       COALESCE(completed_at, started_at, updated_at)
                FROM library_playback_history
                WHERE completed_at IS NOT NULL
                   OR started_at IS NOT NULL
                   OR position_ms > 0;
                """
            )
        }

        if previousVersion < 21,
           try !columnExists(table: "subtitle_files", column: "index_algorithm_version") {
            try database.execute(
                """
                ALTER TABLE subtitle_files
                ADD COLUMN index_algorithm_version INTEGER NOT NULL DEFAULT 0;
                """
            )
        }

        if previousVersion < 22,
           try !columnExists(table: "subtitle_cue_groups", column: "time_range") {
            try database.execute(
                """
                ALTER TABLE subtitle_cue_groups
                ADD COLUMN time_range TEXT NOT NULL DEFAULT '';
                """
            )
            try backfillCueGroupTimeRanges()
        }

        if previousVersion < 23 {
            if try !columnExists(table: "video_files", column: "video_width") {
                try database.execute(
                    """
                    ALTER TABLE video_files
                    ADD COLUMN video_width INTEGER;
                    """
                )
            }
            if try !columnExists(table: "video_files", column: "video_height") {
                try database.execute(
                    """
                    ALTER TABLE video_files
                    ADD COLUMN video_height INTEGER;
                    """
                )
            }
            if try !columnExists(table: "video_files", column: "frame_rate") {
                try database.execute(
                    """
                    ALTER TABLE video_files
                    ADD COLUMN frame_rate REAL;
                    """
                )
            }
        }

        if previousVersion < 27 {
            if try !columnExists(table: "video_covers", column: "display_cover_path") {
                try database.execute(
                    """
                    ALTER TABLE video_covers
                    ADD COLUMN display_cover_path TEXT;
                    """
                )
            }
            if try !columnExists(table: "video_covers", column: "display_profile_version") {
                try database.execute(
                    """
                    ALTER TABLE video_covers
                    ADD COLUMN display_profile_version INTEGER;
                    """
                )
            }
        }

        if previousVersion < 28,
           try !columnExists(table: "shioris", column: "cue_event_index") {
            try migrateLegacyShiorisToSingleCueIdentity()
        }
        if previousVersion < 28 {
            try database.execute(
                """
                DROP INDEX IF EXISTS idx_shioris_order;
                CREATE INDEX idx_shioris_order
                    ON shioris(subtitle_path, start_ms, end_ms, cue_event_index);
                """
            )
        }

        if previousVersion < 29 {
            try migratePermanentIdentityColumns()
        }
        if previousVersion < 30 {
            try database.execute(
                """
                DROP INDEX IF EXISTS idx_shioris_cue;
                CREATE UNIQUE INDEX idx_shioris_cue ON shioris(cue_id);
                """
            )
        }
        if previousVersion < 31 {
            try database.execute(
                """
                DROP TABLE IF EXISTS playback_navigation_state;
                DROP TABLE IF EXISTS playback_navigation_entries;
                """
            )
        }
        if previousVersion < 32 {
            try migrateShiorisToRelationArchitecture()
        }

        try database.execute("PRAGMA user_version = \(Self.currentSchemaVersion);")
    }

    private func migrateShiorisToRelationArchitecture() throws {
        let unresolvedCountStatement = try database.prepare(
            "SELECT COUNT(*) FROM shioris WHERE cue_id IS NULL;"
        )
        guard try unresolvedCountStatement.step() else {
            throw SQLiteDatabaseError.stepFailed(
                "Could not validate Shiori CueID relationships"
            )
        }
        let unresolvedCount = unresolvedCountStatement.intColumn(0)
        try unresolvedCountStatement.reset()
        guard unresolvedCount == 0 else {
            throw SQLiteDatabaseError.stepFailed(
                "Shiori relation migration requires every Shiori to have a CueID"
            )
        }

        try database.execute("PRAGMA foreign_keys = OFF;")
        do {
            try database.execute("BEGIN IMMEDIATE TRANSACTION;")
            try database.execute(
                """
                CREATE TABLE IF NOT EXISTS shiori_lists (
                    id INTEGER PRIMARY KEY,
                    name TEXT NOT NULL,
                    created_at TEXT NOT NULL
                );

                INSERT OR IGNORE INTO shiori_lists(id, name, created_at)
                VALUES (1, 'Shiori', '1970-01-01T00:00:00Z');

                DROP TABLE IF EXISTS shioris_v32;
                CREATE TABLE shioris_v32 (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    list_id INTEGER NOT NULL,
                    cue_id INTEGER NOT NULL,
                    created_at TEXT NOT NULL,
                    UNIQUE(list_id, cue_id),
                    FOREIGN KEY(list_id) REFERENCES shiori_lists(id) ON DELETE CASCADE,
                    FOREIGN KEY(cue_id) REFERENCES subtitle_cue_lines(id) ON DELETE CASCADE
                );

                INSERT INTO shioris_v32(id, list_id, cue_id, created_at)
                SELECT id, 1, cue_id, created_at
                FROM shioris
                ORDER BY id ASC;

                DROP INDEX IF EXISTS idx_shioris_cue;
                DROP INDEX IF EXISTS idx_shioris_subtitle_path;
                DROP INDEX IF EXISTS idx_shioris_order;
                DROP INDEX IF EXISTS idx_shioris_created_order;
                DROP TABLE shioris;
                ALTER TABLE shioris_v32 RENAME TO shioris;

                CREATE INDEX idx_shioris_list_order
                    ON shioris(list_id, created_at DESC, id DESC);
                CREATE INDEX idx_shioris_cue
                    ON shioris(cue_id);
                CREATE INDEX idx_shioris_created_order
                    ON shioris(created_at DESC, id DESC);
                """
            )

            let foreignKeyCheck = try database.prepare("PRAGMA foreign_key_check;")
            guard try !foreignKeyCheck.step() else {
                throw SQLiteDatabaseError.executeFailed(
                    "Shiori relation migration left an invalid foreign-key reference"
                )
            }
            try database.execute("COMMIT;")
            try database.execute("PRAGMA foreign_keys = ON;")
        } catch {
            try? database.execute("ROLLBACK;")
            try? database.execute("PRAGMA foreign_keys = ON;")
            throw error
        }
    }

    private func migratePermanentIdentityColumns() throws {
        if try !columnExists(table: "subtitle_files", column: "library_id") {
            try database.execute("ALTER TABLE subtitle_files ADD COLUMN library_id INTEGER REFERENCES search_paths(id);")
        }
        if try !columnExists(table: "subtitle_files", column: "relative_path") {
            try database.execute("ALTER TABLE subtitle_files ADD COLUMN relative_path TEXT;")
        }
        if try !columnExists(table: "video_files", column: "library_id") {
            try database.execute("ALTER TABLE video_files ADD COLUMN library_id INTEGER REFERENCES search_paths(id);")
        }
        if try !columnExists(table: "video_files", column: "relative_path") {
            try database.execute("ALTER TABLE video_files ADD COLUMN relative_path TEXT;")
        }
        if try !columnExists(table: "subtitle_cue_lines", column: "subtitle_file_id") {
            try database.execute("ALTER TABLE subtitle_cue_lines ADD COLUMN subtitle_file_id INTEGER REFERENCES subtitle_files(id);")
        }
        if try !columnExists(table: "library_playback_history", column: "video_file_id") {
            try database.execute("ALTER TABLE library_playback_history ADD COLUMN video_file_id INTEGER REFERENCES video_files(id);")
        }
        if try !columnExists(table: "library_watch_states", column: "video_file_id") {
            try database.execute("ALTER TABLE library_watch_states ADD COLUMN video_file_id INTEGER REFERENCES video_files(id);")
        }
        if try !columnExists(table: "library_video_rows", column: "video_file_id") {
            try database.execute("ALTER TABLE library_video_rows ADD COLUMN video_file_id INTEGER REFERENCES video_files(id);")
        }
        if try !columnExists(table: "library_video_rows", column: "subtitle_file_id") {
            try database.execute("ALTER TABLE library_video_rows ADD COLUMN subtitle_file_id INTEGER REFERENCES subtitle_files(id);")
        }
        if try !columnExists(table: "subtitle_search_order_rows", column: "subtitle_file_id") {
            try database.execute("ALTER TABLE subtitle_search_order_rows ADD COLUMN subtitle_file_id INTEGER REFERENCES subtitle_files(id);")
        }
        if try !columnExists(table: "shioris", column: "cue_id") {
            try database.execute("ALTER TABLE shioris ADD COLUMN cue_id INTEGER REFERENCES subtitle_cue_lines(id) ON DELETE SET NULL;")
        }

        try database.execute(
            """
            UPDATE subtitle_cue_lines
            SET subtitle_file_id = (
                SELECT g.subtitle_file_id
                FROM subtitle_cue_groups g
                WHERE g.id = subtitle_cue_lines.cue_group_id
            )
            WHERE subtitle_file_id IS NULL;

            UPDATE library_playback_history
            SET video_file_id = (
                SELECT vf.id FROM video_files vf
                WHERE vf.path = library_playback_history.video_path
            )
            WHERE video_file_id IS NULL;

            UPDATE library_watch_states
            SET video_file_id = (
                SELECT vf.id FROM video_files vf
                WHERE vf.path = library_watch_states.video_path
            )
            WHERE video_file_id IS NULL;

            UPDATE library_video_rows
            SET video_file_id = (
                    SELECT vf.id FROM video_files vf
                    WHERE vf.path = library_video_rows.video_path
                ),
                subtitle_file_id = (
                    SELECT sf.id FROM subtitle_files sf
                    WHERE sf.subtitle_path = library_video_rows.subtitle_path
                )
            WHERE video_file_id IS NULL OR subtitle_file_id IS NULL;

            UPDATE subtitle_search_order_rows
            SET subtitle_file_id = (
                SELECT sf.id FROM subtitle_files sf
                WHERE sf.subtitle_path = subtitle_search_order_rows.subtitle_path
            )
            WHERE subtitle_file_id IS NULL;

            CREATE INDEX IF NOT EXISTS idx_subtitle_files_library_relative_path
                ON subtitle_files(library_id, relative_path);
            CREATE INDEX IF NOT EXISTS idx_video_files_library_relative_path
                ON video_files(library_id, relative_path);
            CREATE INDEX IF NOT EXISTS idx_subtitle_cue_lines_subtitle_file
                ON subtitle_cue_lines(subtitle_file_id, id);
            CREATE UNIQUE INDEX IF NOT EXISTS idx_library_playback_history_video_file
                ON library_playback_history(video_file_id)
                WHERE video_file_id IS NOT NULL;
            CREATE UNIQUE INDEX IF NOT EXISTS idx_library_watch_states_video_file
                ON library_watch_states(video_file_id)
                WHERE video_file_id IS NOT NULL;
            CREATE INDEX IF NOT EXISTS idx_library_video_rows_video_file
                ON library_video_rows(video_file_id);
            CREATE INDEX IF NOT EXISTS idx_library_video_rows_subtitle_file
                ON library_video_rows(subtitle_file_id);
            CREATE INDEX IF NOT EXISTS idx_subtitle_search_order_file
                ON subtitle_search_order_rows(subtitle_file_id);
            """
        )
    }

    private func backfillCueGroupTimeRanges() throws {
        let selectStatement = try database.prepare(
            """
            SELECT id, start_ms, end_ms
            FROM subtitle_cue_groups
            WHERE time_range = '';
            """
        )
        var updates: [(cueGroupID: Int64, timeRange: String)] = []
        while try selectStatement.step() {
            updates.append(
                (
                    cueGroupID: selectStatement.int64Column(0),
                    timeRange: Self.cueTimeRange(
                        startMilliseconds: selectStatement.intColumn(1),
                        endMilliseconds: selectStatement.intColumn(2)
                    )
                )
            )
        }

        let updateStatement = try database.prepare(
            """
            UPDATE subtitle_cue_groups
            SET time_range = ?
            WHERE id = ?;
            """
        )
        for update in updates {
            try updateStatement.bind(update.timeRange, at: 1)
            try updateStatement.bind(update.cueGroupID, at: 2)
            try updateStatement.run()
            try updateStatement.reset()
            try updateStatement.clearBindings()
        }
    }

    private struct LegacyShioriMigrationRow {
        let id: Int64
        let subtitlePath: String
        let subtitleFormat: String
        let startMilliseconds: Int
        let endMilliseconds: Int
        let videoPath: String
        let videoName: String
        let content: String
        let isValid: Bool
        let createdAt: String
    }

    private struct LegacyShioriCueCandidate {
        let identity: SubtitleCueIdentity
        let displayOrder: Int
        let content: String
        let isJapanese: Bool
    }

    private struct MigratedShioriIdentityKey: Hashable {
        let subtitlePath: String
        let identity: SubtitleCueIdentity
    }

    private func migrateLegacyShiorisToSingleCueIdentity() throws {
        let legacyRows = try legacyShioriMigrationRows()
        var migratedRows: [(legacy: LegacyShioriMigrationRow, cue: LegacyShioriCueCandidate?)] = []
        migratedRows.reserveCapacity(legacyRows.count)
        var usedIdentities = Set<MigratedShioriIdentityKey>()

        for legacy in legacyRows {
            var cue = try legacyShioriCueCandidate(for: legacy)
            if let resolvedCue = cue {
                let key = MigratedShioriIdentityKey(
                    subtitlePath: legacy.subtitlePath,
                    identity: resolvedCue.identity
                )
                if !usedIdentities.insert(key).inserted {
                    cue = nil
                }
            }
            migratedRows.append((legacy: legacy, cue: cue))
        }

        try database.execute("PRAGMA foreign_keys = OFF;")
        do {
            try database.execute("BEGIN IMMEDIATE TRANSACTION;")
            try database.execute(
                """
                DROP TABLE IF EXISTS shioris_v28;

                CREATE TABLE shioris_v28 (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    subtitle_path TEXT NOT NULL,
                    subtitle_format TEXT NOT NULL,
                    start_ms INTEGER NOT NULL,
                    end_ms INTEGER NOT NULL,
                    cue_event_index INTEGER,
                    cue_display_order INTEGER,
                    video_path TEXT NOT NULL,
                    video_name TEXT NOT NULL,
                    content TEXT NOT NULL,
                    is_valid INTEGER NOT NULL DEFAULT 1,
                    created_at TEXT NOT NULL,
                    UNIQUE(subtitle_path, cue_event_index, start_ms, end_ms)
                );
                """
            )

            let insertStatement = try database.prepare(
                """
                INSERT INTO shioris_v28(
                    id,
                    subtitle_path,
                    subtitle_format,
                    start_ms,
                    end_ms,
                    cue_event_index,
                    cue_display_order,
                    video_path,
                    video_name,
                    content,
                    is_valid,
                    created_at
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
                """
            )

            for row in migratedRows {
                let identity = row.cue?.identity
                try insertStatement.bind(row.legacy.id, at: 1)
                try insertStatement.bind(row.legacy.subtitlePath, at: 2)
                try insertStatement.bind(row.legacy.subtitleFormat, at: 3)
                try insertStatement.bind(identity?.startMilliseconds ?? row.legacy.startMilliseconds, at: 4)
                try insertStatement.bind(identity?.endMilliseconds ?? row.legacy.endMilliseconds, at: 5)
                if let eventIndex = identity?.eventIndex {
                    try insertStatement.bind(eventIndex, at: 6)
                } else {
                    try insertStatement.bindNull(at: 6)
                }
                if let displayOrder = row.cue?.displayOrder {
                    try insertStatement.bind(displayOrder, at: 7)
                } else {
                    try insertStatement.bindNull(at: 7)
                }
                try insertStatement.bind(row.legacy.videoPath, at: 8)
                try insertStatement.bind(row.legacy.videoName, at: 9)
                try insertStatement.bind(row.cue?.content ?? row.legacy.content, at: 10)
                try insertStatement.bind(row.legacy.isValid ? 1 : 0, at: 11)
                try insertStatement.bind(row.legacy.createdAt, at: 12)
                try insertStatement.run()
                try insertStatement.reset()
                try insertStatement.clearBindings()
            }

            try database.execute(
                """
                DROP TABLE shioris;
                ALTER TABLE shioris_v28 RENAME TO shioris;

                CREATE INDEX idx_shioris_subtitle_path
                    ON shioris(subtitle_path);

                CREATE INDEX idx_shioris_order
                    ON shioris(subtitle_path, start_ms, end_ms, cue_event_index);

                CREATE INDEX idx_shioris_created_order
                    ON shioris(created_at DESC, id DESC);
                """
            )

            let foreignKeyCheck = try database.prepare(
                "PRAGMA foreign_key_check(shiori_tag_assignments);"
            )
            guard try !foreignKeyCheck.step() else {
                throw SQLiteDatabaseError.executeFailed(
                    "Shiori Cue migration left an invalid foreign-key reference"
                )
            }

            try database.execute("COMMIT;")
            try database.execute("PRAGMA foreign_keys = ON;")
        } catch {
            try? database.execute("ROLLBACK;")
            try? database.execute("PRAGMA foreign_keys = ON;")
            throw error
        }
    }

    private func legacyShioriMigrationRows() throws -> [LegacyShioriMigrationRow] {
        let statement = try database.prepare(
            """
            SELECT id, subtitle_path, subtitle_format, start_ms, end_ms,
                   video_path, video_name, content, is_valid, created_at
            FROM shioris
            ORDER BY id ASC;
            """
        )
        var rows: [LegacyShioriMigrationRow] = []
        while try statement.step() {
            rows.append(
                LegacyShioriMigrationRow(
                    id: statement.int64Column(0),
                    subtitlePath: statement.stringColumn(1),
                    subtitleFormat: statement.stringColumn(2),
                    startMilliseconds: statement.intColumn(3),
                    endMilliseconds: statement.intColumn(4),
                    videoPath: statement.stringColumn(5),
                    videoName: statement.stringColumn(6),
                    content: statement.stringColumn(7),
                    isValid: statement.intColumn(8) != 0,
                    createdAt: statement.stringColumn(9)
                )
            )
        }
        return rows
    }

    private func legacyShioriCueCandidate(
        for shiori: LegacyShioriMigrationRow
    ) throws -> LegacyShioriCueCandidate? {
        let statement = try database.prepare(
            """
            SELECT l.event_index, l.display_order, l.start_ms, l.end_ms, l.content,
                   EXISTS (
                       SELECT 1
                       FROM subtitle_language_detections d
                       WHERE d.subtitle_file_id = sf.id
                         AND d.scope = 'style'
                         AND d.scope_key = ltrim(COALESCE(l.source_style, ''), '*')
                   ) AS has_style_detection,
                   EXISTS (
                       SELECT 1
                       FROM subtitle_language_detections d
                       JOIN subtitle_language_detection_codes dc ON dc.detection_id = d.id
                       WHERE d.subtitle_file_id = sf.id
                         AND dc.language_code = 'ja'
                         AND d.scope = 'style'
                         AND d.scope_key = ltrim(COALESCE(l.source_style, ''), '*')
                   ) AS style_is_japanese,
                   (
                       SELECT COUNT(DISTINCT dc.language_code)
                       FROM subtitle_language_detections d
                       JOIN subtitle_language_detection_codes dc ON dc.detection_id = d.id
                       WHERE d.subtitle_file_id = sf.id
                         AND d.scope = 'style'
                         AND d.scope_key = ltrim(COALESCE(l.source_style, ''), '*')
                   ) AS style_language_count,
                   (
                       SELECT COUNT(DISTINCT dc.language_code)
                       FROM subtitle_language_detections d
                       JOIN subtitle_language_detection_codes dc ON dc.detection_id = d.id
                       WHERE d.subtitle_file_id = sf.id
                         AND d.scope = 'file'
                         AND d.scope_key = ''
                   ) AS file_language_count,
                   EXISTS (
                       SELECT 1
                       FROM subtitle_language_detections d
                       JOIN subtitle_language_detection_codes dc ON dc.detection_id = d.id
                       WHERE d.subtitle_file_id = sf.id
                         AND d.scope = 'file'
                         AND d.scope_key = ''
                         AND dc.language_code = 'ja'
                   ) AS file_is_japanese
            FROM subtitle_files sf
            JOIN subtitle_cue_groups g ON g.subtitle_file_id = sf.id
            JOIN subtitle_cue_lines l ON l.cue_group_id = g.id
            WHERE sf.subtitle_path = ?
              AND g.start_ms = ?
              AND g.end_ms = ?
            ORDER BY g.id ASC, l.display_order ASC, l.event_index ASC, l.id ASC;
            """
        )
        try statement.bind(shiori.subtitlePath, at: 1)
        try statement.bind(shiori.startMilliseconds, at: 2)
        try statement.bind(shiori.endMilliseconds, at: 3)

        let recognizer = SubtitleLanguageRecognizer(minimumEffectiveCharacterCount: 4)
        var candidates: [LegacyShioriCueCandidate] = []
        while try statement.step() {
            let content = statement.stringColumn(4)
            let hasStyleDetection = statement.intColumn(5) != 0
            let styleIsJapanese = statement.intColumn(6) != 0
            let styleLanguageCount = statement.intColumn(7)
            let fileLanguageCount = statement.intColumn(8)
            let fileIsJapanese = statement.intColumn(9) != 0
            let isJapanese: Bool
            if hasStyleDetection, styleLanguageCount == 1 {
                isJapanese = styleIsJapanese
            } else if hasStyleDetection, styleLanguageCount > 1, styleIsJapanese {
                isJapanese = recognizer.detectLanguages(
                    in: SubtitleLanguageAnalyzer.languageSegments(from: content)
                ).languages.contains(.japanese)
            } else if hasStyleDetection {
                isJapanese = false
            } else if fileLanguageCount == 1 {
                isJapanese = fileIsJapanese
            } else if fileLanguageCount > 1, fileIsJapanese {
                isJapanese = recognizer.detectLanguages(
                    in: SubtitleLanguageAnalyzer.languageSegments(from: content)
                ).languages.contains(.japanese)
            } else if fileLanguageCount > 0 {
                isJapanese = false
            } else {
                isJapanese = recognizer.detectLanguages(
                    in: SubtitleLanguageAnalyzer.languageSegments(from: content)
                ).languages.contains(.japanese)
            }
            candidates.append(
                LegacyShioriCueCandidate(
                    identity: SubtitleCueIdentity(
                        eventIndex: statement.intColumn(0),
                        startMilliseconds: statement.intColumn(2),
                        endMilliseconds: statement.intColumn(3)
                    ),
                    displayOrder: statement.intColumn(1),
                    content: content,
                    isJapanese: isJapanese
                )
            )
        }

        return candidates.last(where: \.isJapanese) ?? candidates.last
    }

    private static func cueTimeRange(startMilliseconds: Int, endMilliseconds: Int) -> String {
        SubtitleCueTimeRangeDisplay.text(
            startMilliseconds: startMilliseconds,
            endMilliseconds: endMilliseconds
        )
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

    private func bindPathPrefixes(
        _ pathPrefixes: [String]?,
        to statement: SQLiteStatement,
        startingAt startIndex: Int32
    ) throws -> Int32 {
        var bindIndex = startIndex
        if let pathPrefixes {
            for prefix in pathPrefixes {
                try statement.bind(prefix, at: bindIndex)
                bindIndex += 1
                try statement.bind(Self.pathPrefixUpperBound(for: prefix), at: bindIndex)
                bindIndex += 1
            }
        }
        return bindIndex
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
        let standardizedFolder = folder.standardizedFileURL
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
        try statement.bind(standardizedFolder.path, at: 2)
        try statement.bind(now, at: 3)
        try statement.bind(now, at: 4)

        let libraryID: Int64
        if try statement.step() {
            libraryID = statement.int64Column(0)
            _ = try statement.step()
        } else {
            libraryID = database.lastInsertRowID()
        }
        try backfillMediaPathIdentities(libraryID: libraryID, rootURL: standardizedFolder)
        return libraryID
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
        let playbackFinishMetadata = Self.playbackFinishMetadata(format: format, cueGroups: cueGroups)
        try database.execute("BEGIN IMMEDIATE TRANSACTION")

        do {
            let preservedCueLineSpeakers = try cueLineSpeakersByStableKey(forSubtitlePath: subtitleFile.path)
            try deleteIndexedSubtitlePath(
                subtitleFile.path,
                preserveFileIdentity: true
            )

            let subtitleFileID = try upsertSubtitleFile(
                subtitleFile: subtitleFile,
                format: format,
                fileSize: fileSize,
                modifiedAt: modifiedAt
            )
            let videoFileID = try upsertVideoFile(videoFile)
            try upsertSubtitleVideoMatch(subtitleFileID: subtitleFileID, videoFileID: videoFileID)
            try insertPlaybackFinishMetadata(
                subtitleFileID: subtitleFileID,
                subtitleFile: subtitleFile,
                metadata: playbackFinishMetadata
            )

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
                    let cueLineID = try insertCueLine(
                        subtitleFileID: subtitleFileID,
                        cueGroupID: cueGroupID,
                        line: line
                    )
                    let speakerKey = CueLineStableKey(line: line)
                    if let speakers = preservedCueLineSpeakers[speakerKey] {
                        try insertCueLineSpeakers(
                            cueLineID: cueLineID,
                            cueGroupID: cueGroupID,
                            speakers: speakers
                        )
                    }
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
            try database.execute("COMMIT")
            clearSearchResultCache()
        } catch {
            try? database.execute("ROLLBACK")
            throw error
        }
    }

    public func entries(forSubtitleFile subtitleFile: URL) throws -> [SubtitleDatabaseEntry] {
        try entries(forSubtitleFile: subtitleFile, limit: Int.max, offset: 0)
    }

    public func subtitleEntryIndex(
        forSubtitleFile subtitleFile: URL
    ) throws -> [SubtitleDatabaseEntryIndexItem] {
        let statement = try database.prepare(
            """
            SELECT g.id, g.start_ms, g.end_ms
            FROM subtitle_cue_groups g
            JOIN subtitle_files sf ON sf.id = g.subtitle_file_id
            JOIN subtitle_video_matches m ON m.subtitle_file_id = sf.id AND m.is_active = 1
            JOIN video_files vf ON vf.id = m.video_file_id
            WHERE sf.subtitle_path = ?
            ORDER BY g.start_ms ASC, g.id ASC;
            """
        )

        try statement.bind(subtitleFile.path, at: 1)

        var index: [SubtitleDatabaseEntryIndexItem] = []
        while try statement.step() {
            index.append(
                SubtitleDatabaseEntryIndexItem(
                    id: statement.int64Column(0),
                    startMilliseconds: statement.intColumn(1),
                    endMilliseconds: statement.intColumn(2)
                )
            )
        }

        return index
    }

    public func entries(
        forSubtitleFile subtitleFile: URL,
        limit: Int,
        offset: Int
    ) throws -> [SubtitleDatabaseEntry] {
        let requestedLimit = max(0, limit)
        guard requestedLimit > 0 else {
            return []
        }

        let statement = try database.prepare(
            """
            SELECT g.id, sf.subtitle_path, sf.format, vf.path, vf.video_name,
                   g.seq, g.start_time, g.end_time, g.start_ms, g.end_ms, g.search_content
            FROM subtitle_cue_groups g
            JOIN subtitle_files sf ON sf.id = g.subtitle_file_id
            JOIN subtitle_video_matches m ON m.subtitle_file_id = sf.id AND m.is_active = 1
            JOIN video_files vf ON vf.id = m.video_file_id
            WHERE sf.subtitle_path = ?
            ORDER BY g.start_ms ASC, g.id ASC
            LIMIT ? OFFSET ?;
            """
        )

        try statement.bind(subtitleFile.path, at: 1)
        try statement.bind(requestedLimit, at: 2)
        try statement.bind(max(0, offset), at: 3)

        var entries: [SubtitleDatabaseEntry] = []
        while try statement.step() {
            entries.append(entry(from: statement))
        }

        return entries
    }

    public func cueLineRecords(forSubtitleFile subtitleFile: URL) throws -> [SubtitleCueLineRecord] {
        let statement = try database.prepare(
            """
            SELECT l.id, l.cue_group_id, l.event_index, l.source_format,
                   l.source_style, l.source_layer, l.start_time, l.end_time,
                   l.start_ms, l.end_ms, l.content, l.display_x, l.display_y,
                   l.display_order
            FROM subtitle_cue_lines l
            JOIN subtitle_cue_groups g ON g.id = l.cue_group_id
            JOIN subtitle_files sf ON sf.id = g.subtitle_file_id
            WHERE sf.subtitle_path = ?
            ORDER BY g.start_ms ASC, g.id ASC, l.display_order ASC, l.event_index ASC, l.id ASC;
            """
        )

        try statement.bind(subtitleFile.path, at: 1)

        var records: [SubtitleCueLineRecord] = []
        while try statement.step() {
            records.append(cueLineRecord(from: statement))
        }
        return records
    }

    public func speakersByCueLineID(
        forSubtitleFile subtitleFile: URL
    ) throws -> [Int64: Set<String>] {
        let statement = try database.prepare(
            """
            SELECT l.id, s.speaker
            FROM subtitle_cue_line_speakers s
            JOIN subtitle_cue_lines l ON l.id = s.cue_line_id
            JOIN subtitle_cue_groups g ON g.id = l.cue_group_id
            JOIN subtitle_files sf ON sf.id = g.subtitle_file_id
            WHERE sf.subtitle_path = ?
            ORDER BY l.id ASC, s.speaker_key ASC;
            """
        )

        try statement.bind(subtitleFile.path, at: 1)

        var speakersByCueLineID: [Int64: Set<String>] = [:]
        while try statement.step() {
            speakersByCueLineID[statement.int64Column(0), default: []].insert(statement.stringColumn(1))
        }
        return speakersByCueLineID
    }

    public func speakersByCueGroupID(
        forSubtitleFile subtitleFile: URL
    ) throws -> [Int64: Set<String>] {
        let statement = try database.prepare(
            """
            SELECT g.id, s.speaker
            FROM subtitle_cue_line_speakers s
            JOIN subtitle_cue_lines l ON l.id = s.cue_line_id
            JOIN subtitle_cue_groups g ON g.id = l.cue_group_id
            JOIN subtitle_files sf ON sf.id = g.subtitle_file_id
            WHERE sf.subtitle_path = ?
            GROUP BY g.id, s.speaker_key, s.speaker
            ORDER BY g.id ASC, s.speaker_key ASC;
            """
        )

        try statement.bind(subtitleFile.path, at: 1)

        var speakersByCueGroupID: [Int64: Set<String>] = [:]
        while try statement.step() {
            speakersByCueGroupID[statement.int64Column(0), default: []].insert(statement.stringColumn(1))
        }
        return speakersByCueGroupID
    }

    public func replaceCueLineSpeakers(
        forSubtitleFile subtitleFile: URL,
        assignments: [SubtitleCueLineSpeakerAssignment]
    ) throws {
        let cueGroupIDsByLineID = try cueGroupIDsByCueLineID(forSubtitleFile: subtitleFile)
        let assignedLineIDs = Set(assignments.map(\.cueLineID))
        guard assignedLineIDs.isSubset(of: Set(cueGroupIDsByLineID.keys)) else {
            throw SQLiteDatabaseError.stepFailed(
                "Speaker assignments contain cue lines outside subtitle file: \(subtitleFile.path)"
            )
        }

        try database.execute("BEGIN IMMEDIATE TRANSACTION")
        do {
            try clearCueLineSpeakersInCurrentTransaction(forSubtitleFile: subtitleFile)
            for assignment in assignments {
                guard let cueGroupID = cueGroupIDsByLineID[assignment.cueLineID] else {
                    continue
                }
                try insertCueLineSpeakers(
                    cueLineID: assignment.cueLineID,
                    cueGroupID: cueGroupID,
                    speakers: assignment.speakers
                )
            }
            try database.execute("COMMIT")
            clearSearchResultCache()
        } catch {
            try? database.execute("ROLLBACK")
            throw error
        }
    }

    public func clearCueLineSpeakers(forSubtitleFile subtitleFile: URL) throws {
        try database.execute("BEGIN IMMEDIATE TRANSACTION")
        do {
            try clearCueLineSpeakersInCurrentTransaction(forSubtitleFile: subtitleFile)
            try database.execute("COMMIT")
            clearSearchResultCache()
        } catch {
            try? database.execute("ROLLBACK")
            throw error
        }
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

    public func cueGroupLanguages(
        forSubtitlePath subtitlePath: String,
        startMilliseconds: Int,
        endMilliseconds: Int
    ) throws -> Set<SubtitleLanguageCode> {
        let statement = try database.prepare(
            """
            SELECT cgl.language_code
            FROM subtitle_cue_groups g
            JOIN subtitle_files sf ON sf.id = g.subtitle_file_id
            JOIN subtitle_cue_group_languages cgl ON cgl.cue_group_id = g.id
            WHERE sf.subtitle_path = ?
              AND g.start_ms = ?
              AND g.end_ms = ?
            ORDER BY cgl.language_code ASC;
            """
        )
        try statement.bind(subtitlePath, at: 1)
        try statement.bind(startMilliseconds, at: 2)
        try statement.bind(endMilliseconds, at: 3)

        var languages = Set<SubtitleLanguageCode>()
        while try statement.step() {
            guard let language = SubtitleLanguageCode(rawValue: statement.stringColumn(0)) else {
                continue
            }
            languages.insert(language)
        }

        return languages.isEmpty ? [.unknown] : languages
    }

    public func cueGroupID(
        forSubtitlePath subtitlePath: String,
        startMilliseconds: Int,
        endMilliseconds: Int
    ) throws -> Int64? {
        let statement = try database.prepare(
            """
            SELECT g.id
            FROM subtitle_cue_groups g
            JOIN subtitle_files sf ON sf.id = g.subtitle_file_id
            WHERE sf.subtitle_path = ?
              AND g.start_ms = ?
              AND g.end_ms = ?
            ORDER BY g.id ASC
            LIMIT 1;
            """
        )
        try statement.bind(subtitlePath, at: 1)
        try statement.bind(startMilliseconds, at: 2)
        try statement.bind(endMilliseconds, at: 3)

        guard try statement.step() else {
            return nil
        }

        return statement.int64Column(0)
    }

    public func firstCueGroupID(forSubtitleFile subtitleFile: URL) throws -> Int64? {
        let statement = try database.prepare(
            """
            SELECT g.id
            FROM subtitle_cue_groups g
            JOIN subtitle_files sf ON sf.id = g.subtitle_file_id
            WHERE sf.subtitle_path = ?
            ORDER BY g.start_ms ASC, g.id ASC
            LIMIT 1;
            """
        )
        try statement.bind(subtitleFile.path, at: 1)

        guard try statement.step() else {
            return nil
        }

        return statement.int64Column(0)
    }

    public func firstCueID(forSubtitleFile subtitleFile: URL) throws -> Int64? {
        let statement = try database.prepare(
            """
            SELECT l.id
            FROM subtitle_cue_lines l
            JOIN subtitle_cue_groups g ON g.id = l.cue_group_id
            JOIN subtitle_files sf ON sf.id = g.subtitle_file_id
            WHERE sf.subtitle_path = ?
            ORDER BY g.start_ms ASC, g.end_ms ASC, g.id ASC,
                     l.display_order ASC, l.event_index ASC, l.id ASC
            LIMIT 1;
            """
        )
        try statement.bind(subtitleFile.path, at: 1)

        guard try statement.step() else {
            return nil
        }
        return statement.int64Column(0)
    }

    private func cueGroupLanguages(
        forCueGroupIDs cueGroupIDs: [Int64]
    ) throws -> [Int64: Set<SubtitleLanguageCode>] {
        guard !cueGroupIDs.isEmpty else {
            return [:]
        }

        let placeholders = cueGroupIDs.map { _ in "?" }.joined(separator: ", ")
        let statement = try database.prepare(
            """
            SELECT cue_group_id, language_code
            FROM subtitle_cue_group_languages
            WHERE cue_group_id IN (\(placeholders))
            ORDER BY cue_group_id ASC, language_code ASC;
            """
        )

        for (offset, cueGroupID) in cueGroupIDs.enumerated() {
            try statement.bind(cueGroupID, at: Int32(offset + 1))
        }

        var languagesByCueGroupID: [Int64: Set<SubtitleLanguageCode>] = [:]
        languagesByCueGroupID.reserveCapacity(cueGroupIDs.count)
        while try statement.step() {
            guard let language = SubtitleLanguageCode(rawValue: statement.stringColumn(1)) else {
                continue
            }
            languagesByCueGroupID[statement.int64Column(0), default: []].insert(language)
        }

        return languagesByCueGroupID
    }

    private func shioriLanguagesByID(
        forShioriIDs shioriIDs: [Int64]
    ) throws -> [Int64: Set<SubtitleLanguageCode>] {
        guard !shioriIDs.isEmpty else {
            return [:]
        }

        let placeholders = shioriIDs.map { _ in "?" }.joined(separator: ", ")
        let statement = try database.prepare(
            """
            SELECT s.id, cgl.language_code
            FROM shioris s
            JOIN subtitle_cue_lines l ON l.id = s.cue_id
            JOIN subtitle_cue_groups g ON g.id = l.cue_group_id
            JOIN subtitle_cue_group_languages cgl ON cgl.cue_group_id = g.id
            WHERE s.id IN (\(placeholders))
            ORDER BY s.id ASC, cgl.language_code ASC;
            """
        )

        for (offset, shioriID) in shioriIDs.enumerated() {
            try statement.bind(shioriID, at: Int32(offset + 1))
        }

        var languagesByShioriID: [Int64: Set<SubtitleLanguageCode>] = [:]
        languagesByShioriID.reserveCapacity(shioriIDs.count)
        while try statement.step() {
            guard let language = SubtitleLanguageCode(rawValue: statement.stringColumn(1)) else {
                continue
            }
            languagesByShioriID[statement.int64Column(0), default: []].insert(language)
        }

        return languagesByShioriID
    }

    private func cueGroupSpeakers(
        forCueGroupIDs cueGroupIDs: [Int64]
    ) throws -> [Int64: Set<String>] {
        guard !cueGroupIDs.isEmpty else {
            return [:]
        }

        let placeholders = cueGroupIDs.map { _ in "?" }.joined(separator: ", ")
        let statement = try database.prepare(
            """
            SELECT cue_group_id, speaker
            FROM subtitle_cue_line_speakers
            WHERE cue_group_id IN (\(placeholders))
            GROUP BY cue_group_id, speaker_key, speaker
            ORDER BY cue_group_id ASC, speaker_key ASC;
            """
        )

        for (offset, cueGroupID) in cueGroupIDs.enumerated() {
            try statement.bind(cueGroupID, at: Int32(offset + 1))
        }

        var speakersByCueGroupID: [Int64: Set<String>] = [:]
        while try statement.step() {
            speakersByCueGroupID[statement.int64Column(0), default: []].insert(statement.stringColumn(1))
        }

        return speakersByCueGroupID
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

    public func hasCurrentPlaybackFinishMetadata(forSubtitleFile subtitleFile: URL) throws -> Bool {
        let statement = try database.prepare(
            """
            SELECT 1
            FROM subtitle_playback_finish_metadata
            WHERE subtitle_path = ?
              AND algorithm_version = ?
            LIMIT 1;
            """
        )

        try statement.bind(subtitleFile.path, at: 1)
        try statement.bind(SubtitleCueIndexingRules.algorithmVersion, at: 2)
        return try statement.step()
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

    public func playbackFinishMetadata(
        forSubtitleFile subtitleFile: URL
    ) throws -> SubtitlePlaybackFinishMetadata? {
        let statement = try database.prepare(
            """
            SELECT primary_styles_json, primary_style_last_end_ms, last_subtitle_end_ms
            FROM subtitle_playback_finish_metadata
            WHERE subtitle_path = ?
              AND algorithm_version = ?;
            """
        )
        try statement.bind(subtitleFile.path, at: 1)
        try statement.bind(SubtitleCueIndexingRules.algorithmVersion, at: 2)

        guard try statement.step() else {
            return nil
        }

        return SubtitlePlaybackFinishMetadata(
            primaryStyles: try Self.decodePrimaryStyles(from: statement.stringColumn(0)),
            primaryStyleLastEndMilliseconds: statement.nullableIntColumn(1),
            lastSubtitleEndMilliseconds: statement.nullableIntColumn(2)
        )
    }

    public func playbackFinishMetadata(
        forVideoFile videoFile: URL
    ) throws -> SubtitlePlaybackFinishMetadata? {
        let statement = try database.prepare(
            """
            SELECT pfm.primary_styles_json, pfm.primary_style_last_end_ms,
                   pfm.last_subtitle_end_ms
            FROM video_files vf
            JOIN subtitle_video_matches m ON m.video_file_id = vf.id AND m.is_active = 1
            JOIN subtitle_files sf ON sf.id = m.subtitle_file_id
            JOIN subtitle_playback_finish_metadata pfm ON pfm.subtitle_file_id = sf.id
            WHERE vf.path = ?
              AND pfm.algorithm_version = ?
            ORDER BY sf.subtitle_path ASC
            LIMIT 1;
            """
        )
        try statement.bind(videoFile.path, at: 1)
        try statement.bind(SubtitleCueIndexingRules.algorithmVersion, at: 2)

        guard try statement.step() else {
            return nil
        }

        return SubtitlePlaybackFinishMetadata(
            primaryStyles: try Self.decodePrimaryStyles(from: statement.stringColumn(0)),
            primaryStyleLastEndMilliseconds: statement.nullableIntColumn(1),
            lastSubtitleEndMilliseconds: statement.nullableIntColumn(2)
        )
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

        if let selection = try bottommostCueTextSelection(forCueGroupID: group.cueGroupID) {
            return selection
        }

        return SubtitleCueTextSelection(
            cueGroupID: group.cueGroupID,
            startMilliseconds: group.startMilliseconds,
            endMilliseconds: group.endMilliseconds,
            cueEventIndex: nil,
            cueDisplayOrder: nil,
            content: group.searchContent
        )
    }

    private func bottommostCueTextSelection(
        forCueGroupID cueGroupID: Int64
    ) throws -> SubtitleCueTextSelection? {
        let statement = try database.prepare(
            """
            SELECT id, event_index, display_order, start_ms, end_ms, content
            FROM subtitle_cue_lines
            WHERE cue_group_id = ?
            ORDER BY display_order DESC, event_index DESC, id DESC
            LIMIT 1;
            """
        )
        try statement.bind(cueGroupID, at: 1)
        guard try statement.step() else {
            return nil
        }
        return SubtitleCueTextSelection(
            cueGroupID: cueGroupID,
            cueLineID: statement.int64Column(0),
            startMilliseconds: statement.intColumn(3),
            endMilliseconds: statement.intColumn(4),
            cueEventIndex: statement.intColumn(1),
            cueDisplayOrder: statement.intColumn(2),
            content: statement.stringColumn(5)
        )
    }

    public func subtitleFocusInitialSnapshot(
        forSubtitleFile subtitleFile: URL,
        atMilliseconds milliseconds: Int,
        policy: SubtitleFocusWindowPolicy = .standard
    ) throws -> SubtitleFocusSnapshot? {
        let timestamp = max(0, milliseconds)
        let activeGroup = try activeCueGroupSelection(
            forSubtitleFile: subtitleFile,
            atMilliseconds: timestamp
        )
        let activeCueID = try activeGroup.flatMap { group in
            try bottommostCueTextSelection(forCueGroupID: group.cueGroupID)?.cueLineID
        }
        guard let selectedCueID = try activeCueID
            ?? subtitleFocusPreviousCueLineID(
                forSubtitleFile: subtitleFile,
                beforeOrAtMilliseconds: timestamp
            )
            ?? subtitleFocusFirstCueLineID(forSubtitleFile: subtitleFile),
        let metadata = try subtitleFocusOrdinalMetadata(
            forSubtitleFile: subtitleFile,
            cueLineID: selectedCueID
        ) else {
            return nil
        }

        let range = policy.windowRange(
            totalCount: metadata.totalCount,
            selectedOrdinal: metadata.ordinal
        )
        let batch = try subtitleFocusCueBatch(
            forSubtitleFile: subtitleFile,
            totalCount: metadata.totalCount,
            startingAtOrdinal: range.lowerBound,
            limit: range.count
        )
        guard batch.cues.count == range.count,
              batch.cues.contains(where: {
                  $0.id == selectedCueID && $0.ordinal == metadata.ordinal
              }) else {
            return nil
        }
        return SubtitleFocusSnapshot(
            totalCount: metadata.totalCount,
            selectedOrdinal: metadata.ordinal,
            cues: batch.cues
        )
    }

    public func subtitleFocusCueBatch(
        forSubtitleFile subtitleFile: URL,
        totalCount requestedTotalCount: Int,
        startingAtOrdinal requestedOrdinal: Int,
        limit requestedLimit: Int
    ) throws -> SubtitleFocusCueBatch {
        try subtitleFocusCueBatch(
            forSubtitleFile: subtitleFile,
            totalCount: requestedTotalCount,
            startingAtOrdinal: requestedOrdinal,
            limit: requestedLimit,
            didReadCue: nil
        )
    }

    func subtitleFocusCueBatch(
        forSubtitleFile subtitleFile: URL,
        totalCount requestedTotalCount: Int,
        startingAtOrdinal requestedOrdinal: Int,
        limit requestedLimit: Int,
        didReadCue: ((Int) -> Void)?
    ) throws -> SubtitleFocusCueBatch {
        try Task.checkCancellation()
        let totalCount = max(0, requestedTotalCount)
        let startOrdinal = min(max(0, requestedOrdinal), totalCount)
        let limit = min(max(0, requestedLimit), max(0, totalCount - startOrdinal))
        guard limit > 0 else {
            return SubtitleFocusCueBatch(totalCount: totalCount, cues: [])
        }

        let statement = try database.prepare(
            """
            SELECT l.id, l.cue_group_id, l.event_index, l.display_order,
                   l.start_ms, l.end_ms, l.content
            FROM subtitle_cue_lines l
            JOIN subtitle_cue_groups g ON g.id = l.cue_group_id
            JOIN subtitle_files sf ON sf.id = g.subtitle_file_id
            WHERE sf.subtitle_path = ?
              AND g.end_ms > g.start_ms
            ORDER BY g.start_ms ASC, g.end_ms ASC, g.id ASC,
                     l.display_order ASC, l.event_index ASC, l.id ASC
            LIMIT ? OFFSET ?;
            """
        )
        try statement.bind(subtitleFile.path, at: 1)
        try statement.bind(limit, at: 2)
        try statement.bind(startOrdinal, at: 3)

        var cues: [SubtitleFocusCue] = []
        cues.reserveCapacity(limit)
        var offset = 0
        while true {
            try Task.checkCancellation()
            guard try statement.step() else {
                break
            }
            cues.append(SubtitleFocusCue(
                id: statement.int64Column(0),
                cueGroupID: statement.int64Column(1),
                ordinal: startOrdinal + offset,
                eventIndex: statement.intColumn(2),
                displayOrder: statement.intColumn(3),
                startMilliseconds: statement.intColumn(4),
                endMilliseconds: statement.intColumn(5),
                content: statement.stringColumn(6)
            ))
            offset += 1
            didReadCue?(offset)
        }
        return SubtitleFocusCueBatch(totalCount: totalCount, cues: cues)
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
                   sf.file_size, sf.modified_at, sf.indexed_at, sf.index_algorithm_version
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
                    indexedAt: statement.stringColumn(6),
                    indexAlgorithmVersion: statement.intColumn(7)
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
        inSubtitlePath subtitlePath: String? = nil,
        languageFilter: SubtitleSearchLanguageFilter = .all,
        watchStateFilter: SubtitleSearchWatchStateFilter = .all,
        filterSet: SubtitleSearchFilterSet = SubtitleSearchFilterSet()
    ) throws -> [SubtitleSearchResult] {
        try searchPage(
            query,
            limit: limit,
            offset: offset,
            under: folders,
            inSubtitlePath: subtitlePath,
            languageFilter: languageFilter,
            watchStateFilter: watchStateFilter,
            filterSet: filterSet
        ).results
    }

    public func searchPage(
        _ query: String,
        limit: Int = 50,
        offset: Int = 0,
        under folders: [URL]? = nil,
        inSubtitlePath subtitlePath: String? = nil,
        languageFilter: SubtitleSearchLanguageFilter = .all,
        watchStateFilter: SubtitleSearchWatchStateFilter = .all,
        filterSet: SubtitleSearchFilterSet = SubtitleSearchFilterSet(),
        diagnostics: SubtitleSearchDiagnosticSink? = nil,
        progress: SubtitleSearchProgressSink? = nil,
        progressResultLimit: Int? = nil,
        mode: SubtitleSearchPageMode = .exact
    ) throws -> SubtitleSearchPage {
        try searchPage(
            query,
            limit: limit,
            cursor: SubtitleSearchCursor(offset: offset),
            under: folders,
            inSubtitlePath: subtitlePath,
            languageFilter: languageFilter,
            watchStateFilter: watchStateFilter,
            filterSet: filterSet,
            diagnostics: diagnostics,
            progress: progress,
            progressResultLimit: progressResultLimit,
            mode: mode
        )
    }

    public func searchVisiblePage(
        _ query: String,
        limit: Int = 50,
        cursor: SubtitleSearchCursor?,
        under folders: [URL]? = nil,
        inSubtitlePath subtitlePath: String? = nil,
        languageFilter: SubtitleSearchLanguageFilter = .all,
        watchStateFilter: SubtitleSearchWatchStateFilter = .all,
        filterSet: SubtitleSearchFilterSet = SubtitleSearchFilterSet(),
        diagnostics: SubtitleSearchDiagnosticSink? = nil,
        progress: SubtitleSearchProgressSink? = nil
    ) throws -> SubtitleSearchPage {
        try searchPage(
            query,
            limit: limit,
            cursor: cursor,
            under: folders,
            inSubtitlePath: subtitlePath,
            languageFilter: languageFilter,
            watchStateFilter: watchStateFilter,
            filterSet: filterSet,
            diagnostics: diagnostics,
            progress: progress,
            mode: .visibleWindow
        )
    }

    public func allCuesVisiblePage(
        limit: Int = 50,
        cursor: SubtitleSearchCursor?,
        under folders: [URL]? = nil,
        filterSet: SubtitleSearchFilterSet = SubtitleSearchFilterSet()
    ) throws -> SubtitleSearchPage {
        try Task.checkCancellation()
        let appliedCursor = cursor ?? .start
        let requestedLimit = max(0, limit)
        let offset = appliedCursor.offset

        let pathPrefixes: [String]?
        if let folders {
            let prefixes = Self.folderPathPrefixes(for: folders)
            guard !prefixes.isEmpty else {
                return SubtitleSearchPage(
                    results: [],
                    totalCount: 0,
                    fileSummaries: [],
                    countSnapshot: .exact(totalCount: 0, fileSummaryCount: 0),
                    appliedCursor: appliedCursor,
                    pageMode: .visibleWindow
                )
            }
            pathPrefixes = prefixes
        } else {
            pathPrefixes = nil
        }

        let scopeCondition = pathPrefixes.map {
            let conditions = $0.map { _ in "(sf.subtitle_path >= ? AND sf.subtitle_path < ?)" }
                .joined(separator: " OR ")
            return "AND (\(conditions))"
        } ?? ""

        try requireCompleteSearchOrderRows(
            pathPrefixes: pathPrefixes,
            subtitlePath: nil
        )

        let statement = try database.prepare(
            """
            SELECT g.id, sf.id, sf.subtitle_path, sf.format, vf.path, vf.video_name,
                   g.start_ms, g.end_ms, g.time_range, g.search_content, g.line_count,
                   sor.subtitle_file_name, sor.display_title, sor.folder_order, sor.file_order,
                   l.id, l.cue_group_id, l.event_index, l.source_format,
                   l.source_style, l.source_layer, l.start_time, l.end_time,
                   l.start_ms, l.end_ms, l.content, l.display_x, l.display_y,
                   l.display_order,
                   (
                       SELECT GROUP_CONCAT(cgl.language_code)
                       FROM subtitle_cue_group_languages cgl
                       WHERE cgl.cue_group_id = g.id
                   ) AS language_values,
                   (
                       SELECT GROUP_CONCAT(speaker, char(31))
                       FROM (
                           SELECT speaker
                           FROM subtitle_cue_line_speakers cls
                           WHERE cls.cue_line_id = l.id
                           GROUP BY speaker_key, speaker
                           ORDER BY speaker_key ASC
                       )
                   ) AS speaker_values
            FROM subtitle_cue_groups g
            JOIN subtitle_files sf ON sf.id = g.subtitle_file_id
            JOIN subtitle_video_matches m ON m.subtitle_file_id = sf.id AND m.is_active = 1
            JOIN video_files vf ON vf.id = m.video_file_id
            JOIN subtitle_search_order_rows sor ON sor.subtitle_file_id = sf.id
            JOIN subtitle_cue_lines l ON l.cue_group_id = g.id
            WHERE 1 = 1
            \(scopeCondition)
            ORDER BY sor.folder_order ASC, sor.file_order ASC,
                     g.start_ms ASC, g.end_ms ASC, g.id ASC,
                     l.display_order ASC, l.event_index ASC, l.id ASC
            """
        )
        _ = try bindPathPrefixes(pathPrefixes, to: statement, startingAt: 1)

        var accepted: [AllCuePageCandidate] = []
        var fileSummaryAccumulator = SearchFileSummaryAccumulator()
        var languageDetectionsBySubtitleFileID: [Int64: SearchLanguageDetections] = [:]
        var acceptedCount = 0
        while try statement.step() {
            try Task.checkCancellation()
            let candidate = searchCandidate(from: statement)
            let cueLineRecord = cueLineRecord(from: statement, startingAt: 15)
            let languageDetections: SearchLanguageDetections
            if let cached = languageDetectionsBySubtitleFileID[candidate.subtitleFileID] {
                languageDetections = cached
            } else {
                let loaded = try searchLanguageDetections(
                    forSubtitleFileID: candidate.subtitleFileID
                )
                languageDetectionsBySubtitleFileID[candidate.subtitleFileID] = loaded
                languageDetections = loaded
            }
            let cueGroupLanguages = Self.languageValues(
                from: statement.nullableStringColumn(29)
            )
            let displayLanguages = Self.displayLanguages(
                for: cueLineRecord.line,
                candidate: candidate,
                detections: languageDetections,
                cueGroupLanguages: cueGroupLanguages
            )
            let displaySpeakers = Self.speakerValues(
                from: statement.nullableStringColumn(30)
            )
            guard filterSet.isEffectivelyEmpty || filterSet.matches(
                display: candidate.order.displayTitle,
                cues: cueLineRecord.line.content,
                languages: Self.filterSetLanguageValues(displayLanguages),
                speakers: Self.filterSetSpeakerValues(displaySpeakers)
            ) else {
                continue
            }

            fileSummaryAccumulator.add(candidate: candidate)
            if acceptedCount >= offset && accepted.count < requestedLimit {
                accepted.append(
                    AllCuePageCandidate(
                        candidate: candidate,
                        cueLineRecord: cueLineRecord,
                        displayLanguages: displayLanguages,
                        displaySpeakers: displaySpeakers
                    )
                )
            }
            acceptedCount += 1
        }

        let totalCount = acceptedCount
        let fileSummaries = fileSummaryAccumulator.fileSummaries()
        let acceptedCueGroupIDs = Array(Set(accepted.map { $0.candidate.cueGroupID })).sorted()
        let groupRecordsByID = try cueLineRecords(forCueGroupIDs: acceptedCueGroupIDs)
        var results: [SubtitleSearchResult] = []
        results.reserveCapacity(accepted.count)
        for (index, item) in accepted.enumerated() {
            try Task.checkCancellation()
            let groupRecords = groupRecordsByID[item.candidate.cueGroupID] ?? [item.cueLineRecord]
            var result = orderedSearchResult(
                for: item.candidate,
                match: SearchResultMatch(
                    cueLineRecord: item.cueLineRecord,
                    primaryGroupIndex: groupRecords.firstIndex {
                        $0.id == item.cueLineRecord.id
                    } ?? 0,
                    cueGroupLines: groupRecords.map(\.line.content),
                    displayLanguages: item.displayLanguages,
                    displaySpeakers: item.displaySpeakers
                )
            ).result
            result.searchRank = offset + index
            results.append(result)
        }
        let upperBound = min(totalCount, offset + results.count)

        return SubtitleSearchPage(
            results: results,
            totalCount: totalCount,
            fileSummaries: fileSummaries,
            countSnapshot: .exact(totalCount: totalCount, fileSummaryCount: fileSummaries.count),
            appliedCursor: appliedCursor,
            nextCursor: upperBound < totalCount ? SubtitleSearchCursor(offset: upperBound) : nil,
            pageMode: .visibleWindow,
            orderSource: "defaultCueOrder",
            materializedOrderRows: results.count
        )
    }

    public func cueContextSearchPage(
        subtitlePath: String,
        targetCueID: Int64,
        limit: Int = 50,
        cursor: SubtitleSearchCursor? = nil,
        anchorWindowSize: Int? = nil,
        anchorsInitialPage: Bool = false,
        under folders: [URL]? = nil
    ) throws -> SubtitleSearchPage? {
        let requestedLimit = max(0, limit)
        let appliedCursor = cursor ?? .start
        let offset = appliedCursor.offset
        guard requestedLimit > 0 else {
            return SubtitleSearchPage(
                results: [],
                totalCount: 0,
                fileSummaries: [],
                countSnapshot: .exact(totalCount: 0, fileSummaryCount: 0),
                appliedCursor: appliedCursor,
                pageMode: .visibleWindow,
                orderSource: "cueContextWindow",
                materializedOrderRows: 0
            )
        }

        let pathPrefixes: [String]?
        if let folders {
            let prefixes = Self.folderPathPrefixes(for: folders)
            guard !prefixes.isEmpty else {
                return SubtitleSearchPage(
                    results: [],
                    totalCount: 0,
                    fileSummaries: [],
                    countSnapshot: .exact(totalCount: 0, fileSummaryCount: 0),
                    appliedCursor: appliedCursor,
                    pageMode: .visibleWindow,
                    orderSource: "cueContextWindow",
                    materializedOrderRows: 0
                )
            }
            pathPrefixes = prefixes
        } else {
            pathPrefixes = nil
        }

        let scopeCondition = pathPrefixes.map {
            let conditions = $0.map { _ in "(sf.subtitle_path >= ? AND sf.subtitle_path < ?)" }
                .joined(separator: " OR ")
            return "AND (\(conditions))"
        } ?? ""

        try requireCompleteSearchOrderRows(
            pathPrefixes: pathPrefixes,
            subtitlePath: subtitlePath
        )

        let targetStatement = try database.prepare(
            """
            SELECT row_index, total_count, subtitle_file_name, display_title
            FROM (
                SELECT l.id AS cue_id,
                       ROW_NUMBER() OVER (
                           ORDER BY g.start_ms ASC, g.end_ms ASC, g.id ASC,
                                    l.display_order ASC, l.event_index ASC, l.id ASC
                       ) - 1 AS row_index,
                       COUNT(*) OVER () AS total_count,
                       sor.subtitle_file_name,
                       sor.display_title
                FROM subtitle_cue_groups g
                JOIN subtitle_cue_lines l ON l.cue_group_id = g.id
                JOIN subtitle_files sf ON sf.id = g.subtitle_file_id
                JOIN subtitle_video_matches m ON m.subtitle_file_id = sf.id AND m.is_active = 1
                JOIN subtitle_search_order_rows sor ON sor.subtitle_file_id = sf.id
                WHERE sf.subtitle_path = ?
                \(scopeCondition)
            ) ordered
            WHERE cue_id = ?;
            """
        )
        var bindIndex: Int32 = 1
        try targetStatement.bind(subtitlePath, at: bindIndex)
        bindIndex += 1
        bindIndex = try bindPathPrefixes(pathPrefixes, to: targetStatement, startingAt: bindIndex)
        try targetStatement.bind(targetCueID, at: bindIndex)

        guard try targetStatement.step() else {
            return nil
        }

        let targetIndex = targetStatement.intColumn(0)
        let fileCueCount = targetStatement.intColumn(1)
        let subtitleFileName = targetStatement.stringColumn(2)
        let subtitleDisplayTitle = targetStatement.stringColumn(3)
        let resolvedAnchorWindowSize = min(
            requestedLimit,
            max(1, anchorWindowSize ?? requestedLimit)
        )
        let anchorStart = min(targetIndex, max(0, fileCueCount - resolvedAnchorWindowSize))
        let totalCount = fileCueCount
        let requestedOffset = anchorsInitialPage && offset == 0 ? anchorStart : offset
        let boundedOffset = min(requestedOffset, totalCount)
        let windowLimit = min(requestedLimit, max(0, totalCount - boundedOffset))
        let rowOffset = boundedOffset

        let statement = try database.prepare(
            """
            SELECT l.id
            FROM subtitle_cue_groups g
            JOIN subtitle_cue_lines l ON l.cue_group_id = g.id
            JOIN subtitle_files sf ON sf.id = g.subtitle_file_id
            JOIN subtitle_video_matches m ON m.subtitle_file_id = sf.id AND m.is_active = 1
            WHERE sf.subtitle_path = ?
            \(scopeCondition)
            ORDER BY g.start_ms ASC, g.end_ms ASC, g.id ASC,
                     l.display_order ASC, l.event_index ASC, l.id ASC
            LIMIT ? OFFSET ?;
            """
        )
        bindIndex = 1
        try statement.bind(subtitlePath, at: bindIndex)
        bindIndex += 1
        bindIndex = try bindPathPrefixes(pathPrefixes, to: statement, startingAt: bindIndex)
        try statement.bind(windowLimit, at: bindIndex)
        bindIndex += 1
        try statement.bind(rowOffset, at: bindIndex)

        var cueIDs: [Int64] = []
        cueIDs.reserveCapacity(windowLimit)
        while try statement.step() {
            cueIDs.append(statement.int64Column(0))
        }

        let summaries = [
            SubtitleSearchFileSummary(
                subtitlePath: subtitlePath,
                subtitleFileName: subtitleFileName,
                subtitleDisplayTitle: subtitleDisplayTitle,
                matchCount: totalCount
            )
        ]
        let upperBound = min(totalCount, boundedOffset + cueIDs.count)
        let indexWindow = SubtitleSearchResultIDIndexWindow(
            cueIDs: cueIDs,
            offset: boundedOffset,
            totalCount: totalCount,
            fileSummaries: summaries,
            countSnapshot: .exact(totalCount: totalCount, fileSummaryCount: 1),
            appliedCursor: SubtitleSearchCursor(offset: boundedOffset),
            nextCursor: upperBound < totalCount ? SubtitleSearchCursor(offset: upperBound) : nil
        )
        guard let hydratedPage = try searchIndexedVisiblePage(from: indexWindow) else {
            return nil
        }

        return SubtitleSearchPage(
            results: hydratedPage.results,
            totalCount: totalCount,
            fileSummaries: summaries,
            countSnapshot: .exact(totalCount: totalCount, fileSummaryCount: summaries.count),
            appliedCursor: SubtitleSearchCursor(offset: boundedOffset),
            nextCursor: upperBound < totalCount ? SubtitleSearchCursor(offset: upperBound) : nil,
            pageMode: .visibleWindow,
            orderSource: "cueContextWindow",
            materializedOrderRows: hydratedPage.results.count
        )
    }

    private func searchCandidate(from statement: SQLiteStatement) -> SearchCandidate {
        SearchCandidate(
            cueGroupID: statement.int64Column(0),
            subtitleFileID: statement.int64Column(1),
            subtitlePath: statement.stringColumn(2),
            subtitleFormat: SubtitleFormat(rawValue: statement.stringColumn(3)) ?? .srt,
            videoPath: statement.stringColumn(4),
            videoName: statement.stringColumn(5),
            startMilliseconds: statement.intColumn(6),
            endMilliseconds: statement.intColumn(7),
            timeRange: statement.stringColumn(8),
            searchContent: statement.stringColumn(9),
            lineCount: statement.intColumn(10),
            order: SearchResultOrder(
                subtitleFileName: statement.stringColumn(11),
                displayTitle: statement.stringColumn(12),
                folderOrder: statement.intColumn(13),
                fileOrder: statement.intColumn(14)
            )
        )
    }

    private func cachedSearchResultIDIndex(
        _ query: String,
        under folders: [URL]? = nil,
        inSubtitlePath subtitlePath: String? = nil,
        languageFilter: SubtitleSearchLanguageFilter = .all,
        filterSet: SubtitleSearchFilterSet = SubtitleSearchFilterSet()
    ) -> SearchResultIDIndex? {
        _ = query
        _ = folders
        _ = subtitlePath
        _ = languageFilter
        _ = filterSet
        return nil
    }

    public func searchResultIDIndexWindow(
        _ query: String,
        limit: Int = 50,
        cursor: SubtitleSearchCursor?,
        under folders: [URL]? = nil,
        inSubtitlePath subtitlePath: String? = nil,
        languageFilter: SubtitleSearchLanguageFilter = .all,
        filterSet: SubtitleSearchFilterSet = SubtitleSearchFilterSet(),
        minimumKnownResultCount: Int? = nil
    ) -> SubtitleSearchResultIDIndexWindow? {
        let appliedCursor = cursor ?? .start
        let subtitlePathFilter = subtitlePath
        guard subtitlePathFilter?.isEmpty != true else {
            return SubtitleSearchResultIDIndexWindow(
                cueIDs: [],
                offset: 0,
                totalCount: 0,
                fileSummaries: [],
                countSnapshot: .exact(totalCount: 0, fileSummaryCount: 0),
                appliedCursor: appliedCursor,
                nextCursor: nil
            )
        }

        if let folders {
            let prefixes = Self.folderPathPrefixes(for: folders)
            guard !prefixes.isEmpty else {
                return SubtitleSearchResultIDIndexWindow(
                    cueIDs: [],
                    offset: 0,
                    totalCount: 0,
                    fileSummaries: [],
                    countSnapshot: .exact(totalCount: 0, fileSummaryCount: 0),
                    appliedCursor: appliedCursor,
                    nextCursor: nil
                )
            }
        }

        guard let resultIDIndex = cachedSearchResultIDIndex(
            query,
            under: folders,
            inSubtitlePath: subtitlePath,
            languageFilter: languageFilter,
            filterSet: filterSet
        ) else {
            return nil
        }

        let totalCount = resultIDIndex.countSnapshot.knownResultCount
        if let minimumKnownResultCount,
           totalCount < minimumKnownResultCount {
            return nil
        }

        let requestedLimit = max(0, limit)
        let offset = min(appliedCursor.offset, totalCount)
        let pageCount = min(requestedLimit, max(0, totalCount - offset))
        guard pageCount > 0 else {
            return SubtitleSearchResultIDIndexWindow(
                cueIDs: [],
                offset: offset,
                totalCount: totalCount,
                fileSummaries: resultIDIndex.fileSummaries,
                countSnapshot: resultIDIndex.countSnapshot,
                appliedCursor: appliedCursor,
                nextCursor: nil
            )
        }

        let upperBound = offset + pageCount
        return SubtitleSearchResultIDIndexWindow(
            cueIDs: Array(resultIDIndex.cueIDs[offset..<upperBound]),
            offset: offset,
            totalCount: totalCount,
            fileSummaries: resultIDIndex.fileSummaries,
            countSnapshot: resultIDIndex.countSnapshot,
            appliedCursor: appliedCursor,
            nextCursor: upperBound < totalCount ? SubtitleSearchCursor(offset: upperBound) : nil
        )
    }

    public func searchIndexedVisiblePage(
        from indexWindow: SubtitleSearchResultIDIndexWindow
    ) throws -> SubtitleSearchPage? {
        guard !indexWindow.cueIDs.isEmpty else {
            return SubtitleSearchPage(
                results: [],
                totalCount: indexWindow.totalCount,
                fileSummaries: indexWindow.fileSummaries,
                countSnapshot: indexWindow.countSnapshot,
                appliedCursor: indexWindow.appliedCursor,
                nextCursor: indexWindow.nextCursor,
                pageMode: .visibleWindow,
                orderSource: "resultIDIndex",
                materializedOrderRows: 0
            )
        }

        try Task.checkCancellation()
        let cueRecordsByID = try cueLineRecords(forCueIDs: indexWindow.cueIDs)
        try Task.checkCancellation()
        guard indexWindow.cueIDs.allSatisfy({ cueRecordsByID[$0] != nil }) else {
            return nil
        }

        var cueGroupIDs: [Int64] = []
        var seenCueGroupIDs = Set<Int64>()
        for cueID in indexWindow.cueIDs {
            guard let cueGroupID = cueRecordsByID[cueID]?.cueGroupID,
                  seenCueGroupIDs.insert(cueGroupID).inserted
            else {
                continue
            }
            cueGroupIDs.append(cueGroupID)
        }
        let candidatesByCueGroupID = try searchCandidates(forCueGroupIDs: cueGroupIDs)
        guard cueGroupIDs.allSatisfy({ candidatesByCueGroupID[$0] != nil }) else {
            return nil
        }
        let cueRecordsByCueGroupID = try cueLineRecords(forCueGroupIDs: cueGroupIDs)
        let languagesByCueGroupID = try cueGroupLanguages(forCueGroupIDs: cueGroupIDs)
        let speakersByCueID = try cueLineSpeakers(forCueIDs: indexWindow.cueIDs)
        var languageDetectionsBySubtitleFileID: [Int64: SearchLanguageDetections] = [:]
        try Task.checkCancellation()

        var results: [SubtitleSearchResult] = []
        results.reserveCapacity(indexWindow.cueIDs.count)
        for (index, cueID) in indexWindow.cueIDs.enumerated() {
            try Task.checkCancellation()
            guard let cueRecord = cueRecordsByID[cueID],
                  let candidate = candidatesByCueGroupID[cueRecord.cueGroupID]
            else {
                return nil
            }
            let groupRecords = cueRecordsByCueGroupID[cueRecord.cueGroupID] ?? [cueRecord]
            let languageDetections: SearchLanguageDetections
            if let cached = languageDetectionsBySubtitleFileID[candidate.subtitleFileID] {
                languageDetections = cached
            } else {
                let loaded = try searchLanguageDetections(
                    forSubtitleFileID: candidate.subtitleFileID
                )
                languageDetectionsBySubtitleFileID[candidate.subtitleFileID] = loaded
                languageDetections = loaded
            }
            let languages = Self.displayLanguages(
                for: cueRecord.line,
                candidate: candidate,
                detections: languageDetections,
                cueGroupLanguages: languagesByCueGroupID[cueRecord.cueGroupID] ?? [.unknown]
            )
            var result = orderedSearchResult(
                for: candidate,
                match: SearchResultMatch(
                    cueLineRecord: cueRecord,
                    primaryGroupIndex: groupRecords.firstIndex { $0.id == cueID } ?? 0,
                    cueGroupLines: groupRecords.map(\.line.content),
                    displayLanguages: languages,
                    displaySpeakers: speakersByCueID[cueID] ?? []
                )
            ).result
            result.searchRank = indexWindow.offset + index
            results.append(result)
        }

        return SubtitleSearchPage(
            results: results,
            totalCount: indexWindow.totalCount,
            fileSummaries: indexWindow.fileSummaries,
            countSnapshot: indexWindow.countSnapshot,
            appliedCursor: indexWindow.appliedCursor,
            nextCursor: indexWindow.nextCursor,
            pageMode: .visibleWindow,
            orderSource: "resultIDIndex",
            materializedOrderRows: results.count
        )
    }

    public func cueContents(forCueIDs cueIDs: [Int64]) throws -> [CueContent] {
        var seenCueIDs = Set<Int64>()
        let orderedCueIDs = cueIDs.filter { cueID in
            cueID > 0 && seenCueIDs.insert(cueID).inserted
        }
        guard !orderedCueIDs.isEmpty else { return [] }

        let page = try searchIndexedVisiblePage(
            from: SubtitleSearchResultIDIndexWindow(
                cueIDs: orderedCueIDs,
                offset: 0,
                totalCount: orderedCueIDs.count,
                fileSummaries: [],
                countSnapshot: .exact(
                    totalCount: orderedCueIDs.count,
                    fileSummaryCount: 0
                ),
                appliedCursor: .start,
                nextCursor: nil
            )
        )
        guard let page,
              page.results.map(\.entryID) == orderedCueIDs
        else {
            return []
        }
        return page.results.map(\.cueContent)
    }

    public func cuePlaybackResult(cueID: Int64) throws -> SubtitleSearchResult? {
        guard cueID > 0 else {
            return nil
        }
        return try cueContents(forCueIDs: [cueID]).first.map {
            SubtitleSearchResult(cueContent: $0)
        }
    }

    public func searchNavigationSnapshotFromResultIDIndex(
        _ query: String,
        under folders: [URL]? = nil,
        languageFilter: SubtitleSearchLanguageFilter = .all,
        filterSet: SubtitleSearchFilterSet = SubtitleSearchFilterSet(),
        anchor: SearchNavigationAnchor,
        radius: Int = 1
    ) throws -> SearchNavigationSnapshot? {
        guard let resultIDIndex = cachedSearchResultIDIndex(
            query,
            under: folders,
            languageFilter: languageFilter,
            filterSet: filterSet
        ) else {
            return nil
        }

        let totalCount = resultIDIndex.countSnapshot.knownResultCount
        guard totalCount > 0 else {
            return SearchNavigationSnapshot(
                totalCount: 0,
                currentIndex: nil,
                neighborhood: [],
                previous: nil,
                current: nil,
                next: nil
            )
        }

        let currentIndex = try searchNavigationPlaybackTimeIndex(
            query,
            resultIDIndex: resultIDIndex,
            under: folders,
            languageFilter: languageFilter,
            filterSet: filterSet,
            anchor: anchor
        ) ?? Self.searchNavigationIndex(
            in: resultIDIndex.cueIDs,
            anchor: anchor
        )
        let boundedRadius = max(1, radius)
        let lowerBound: Int
        let upperBound: Int
        if let currentIndex {
            lowerBound = max(0, currentIndex - boundedRadius)
            upperBound = min(totalCount, currentIndex + boundedRadius + 1)
        } else {
            lowerBound = 0
            upperBound = min(totalCount, (boundedRadius * 2) + 1)
        }

        let window = SubtitleSearchResultIDIndexWindow(
            cueIDs: Array(resultIDIndex.cueIDs[lowerBound..<upperBound]),
            offset: lowerBound,
            totalCount: totalCount,
            fileSummaries: resultIDIndex.fileSummaries,
            countSnapshot: resultIDIndex.countSnapshot,
            appliedCursor: SubtitleSearchCursor(offset: lowerBound),
            nextCursor: upperBound < totalCount ? SubtitleSearchCursor(offset: upperBound) : nil
        )
        guard let page = try searchIndexedVisiblePage(from: window) else {
            return nil
        }

        let previous = currentIndex.flatMap { index -> SubtitleSearchResult? in
            let localIndex = index - 1 - lowerBound
            return page.results.indices.contains(localIndex) ? page.results[localIndex] : nil
        }
        let current = currentIndex.flatMap { index -> SubtitleSearchResult? in
            let localIndex = index - lowerBound
            return page.results.indices.contains(localIndex) ? page.results[localIndex] : nil
        }
        let next = currentIndex.flatMap { index -> SubtitleSearchResult? in
            let localIndex = index + 1 - lowerBound
            return page.results.indices.contains(localIndex) ? page.results[localIndex] : nil
        }

        return SearchNavigationSnapshot(
            totalCount: totalCount,
            currentIndex: currentIndex,
            neighborhood: page.results,
            previous: previous,
            current: current,
            next: next
        )
    }

    private func searchNavigationPlaybackTimeIndex(
        _ query: String,
        resultIDIndex: SearchResultIDIndex,
        under folders: [URL]?,
        languageFilter: SubtitleSearchLanguageFilter,
        filterSet: SubtitleSearchFilterSet,
        anchor: SearchNavigationAnchor
    ) throws -> Int? {
        guard let videoPath = anchor.videoPath,
              let subtitlePath = anchor.subtitlePath,
              let plan = Self.searchQueryPlan(for: query)
        else {
            return nil
        }

        let pathPrefixes: [String]?
        if let folders {
            let prefixes = Self.folderPathPrefixes(for: folders)
            guard !prefixes.isEmpty else {
                return nil
            }
            pathPrefixes = prefixes
        } else {
            pathPrefixes = nil
        }

        try requireCompleteSearchOrderRows(
            pathPrefixes: pathPrefixes,
            subtitlePath: subtitlePath
        )

        let scopeCondition = pathPrefixes.map {
            let conditions = $0.map { _ in "(sf.subtitle_path >= ? AND sf.subtitle_path < ?)" }
                .joined(separator: " OR ")
            return "AND (\(conditions))"
        } ?? ""
        let languageFilterCodes = Self.languageCodesForSearchFilter(languageFilter)
        let languageFilterCodeSet = Set(languageFilterCodes)
        let languageConditionCodes = languageFilterCodes.contains(.unknown) ? [] : languageFilterCodes
        let languageCondition: String
        if languageConditionCodes.isEmpty {
            languageCondition = ""
        } else {
            let placeholders = Array(repeating: "?", count: languageConditionCodes.count)
                .joined(separator: ", ")
            languageCondition = """
            AND (
                EXISTS (
                    SELECT 1
                    FROM subtitle_cue_group_languages cgl
                    WHERE cgl.cue_group_id = g.id
                      AND cgl.language_code IN (\(placeholders))
                )
                OR NOT EXISTS (
                    SELECT 1
                    FROM subtitle_cue_group_languages cgl_missing
                    WHERE cgl_missing.cue_group_id = g.id
                )
            )
            """
        }

        let statement = try database.prepare(
            """
            SELECT g.id, sf.id, sf.subtitle_path, sf.format, vf.path, vf.video_name,
                   g.start_ms, g.end_ms, g.time_range, g.search_content, g.line_count,
                   sor.subtitle_file_name, sor.display_title, sor.folder_order, sor.file_order
            FROM subtitle_cue_groups_fts f
            JOIN subtitle_cue_groups g ON g.id = f.cue_group_id
            JOIN subtitle_files sf ON sf.id = g.subtitle_file_id
            JOIN subtitle_video_matches m ON m.subtitle_file_id = sf.id AND m.is_active = 1
            JOIN video_files vf ON vf.id = m.video_file_id
            JOIN subtitle_search_order_rows sor ON sor.subtitle_file_id = sf.id
            WHERE subtitle_cue_groups_fts MATCH ?
            \(scopeCondition)
              AND sf.subtitle_path = ?
              AND vf.path = ?
              AND g.start_ms <= ?
            \(languageCondition)
            ORDER BY g.start_ms DESC, g.id DESC
            LIMIT ? OFFSET ?;
            """
        )

        var candidateOffset = 0
        var languageDetectionsBySubtitleFileID: [Int64: SearchLanguageDetections] = [:]

        while true {
            try Task.checkCancellation()
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
            try statement.bind(subtitlePath, at: bindIndex)
            bindIndex += 1
            try statement.bind(videoPath, at: bindIndex)
            bindIndex += 1
            try statement.bind(anchor.currentMilliseconds, at: bindIndex)
            bindIndex += 1
            for languageCode in languageConditionCodes {
                try statement.bind(languageCode.rawValue, at: bindIndex)
                bindIndex += 1
            }
            try statement.bind(Self.searchNavigationPlaybackAnchorBatchLimit, at: bindIndex)
            bindIndex += 1
            try statement.bind(candidateOffset, at: bindIndex)

            var candidates: [SearchCandidate] = []
            while try statement.step() {
                candidates.append(
                    SearchCandidate(
                        cueGroupID: statement.int64Column(0),
                        subtitleFileID: statement.int64Column(1),
                        subtitlePath: statement.stringColumn(2),
                        subtitleFormat: SubtitleFormat(rawValue: statement.stringColumn(3)) ?? .srt,
                        videoPath: statement.stringColumn(4),
                        videoName: statement.stringColumn(5),
                        startMilliseconds: statement.intColumn(6),
                        endMilliseconds: statement.intColumn(7),
                        timeRange: statement.stringColumn(8),
                        searchContent: statement.stringColumn(9),
                        lineCount: statement.intColumn(10),
                        order: SearchResultOrder(
                            subtitleFileName: statement.stringColumn(11),
                            displayTitle: statement.stringColumn(12),
                            folderOrder: statement.intColumn(13),
                            fileOrder: statement.intColumn(14)
                        )
                    )
                )
            }

            guard !candidates.isEmpty else {
                return nil
            }

            let cueGroupIDs = candidates.map(\.cueGroupID)
            let cueLineRecordsByCueGroupID = try cueLineRecords(forCueGroupIDs: cueGroupIDs)
            let cueIDs = cueLineRecordsByCueGroupID.values.flatMap { records in
                records.map(\.id)
            }
            let speakersByCueID = try cueLineSpeakers(forCueIDs: cueIDs)
            for candidate in candidates {
                if languageDetectionsBySubtitleFileID[candidate.subtitleFileID] == nil {
                    languageDetectionsBySubtitleFileID[candidate.subtitleFileID] = try searchLanguageDetections(
                        forSubtitleFileID: candidate.subtitleFileID
                    )
                }
            }
            let languagesByCueGroupID = try cueGroupLanguages(forCueGroupIDs: cueGroupIDs)

            for candidate in candidates {
                let matchingResults = searchResults(
                    for: candidate,
                    cueLineRecords: cueLineRecordsByCueGroupID[candidate.cueGroupID] ?? [],
                    matching: plan,
                    languageFilterCodes: languageFilterCodeSet,
                    languageDetections: languageDetectionsBySubtitleFileID[candidate.subtitleFileID],
                    cueGroupLanguages: languagesByCueGroupID[candidate.cueGroupID] ?? [],
                    speakersByCueID: speakersByCueID,
                    filterSet: filterSet
                )
                for matchingResult in matchingResults.reversed() {
                    if let index = Self.searchNavigationIndex(
                        of: matchingResult.result.entryID,
                        in: resultIDIndex.cueIDs,
                        preferredSearchRank: anchor.selectedSearchRank
                    ) {
                        return index
                    }
                }
            }

            candidateOffset += candidates.count
            if candidates.count < Self.searchNavigationPlaybackAnchorBatchLimit {
                return nil
            }
        }
    }

    public func searchPage(
        _ query: String,
        limit: Int = 50,
        cursor: SubtitleSearchCursor?,
        under folders: [URL]? = nil,
        inSubtitlePath subtitlePath: String? = nil,
        languageFilter: SubtitleSearchLanguageFilter = .all,
        watchStateFilter: SubtitleSearchWatchStateFilter = .all,
        filterSet: SubtitleSearchFilterSet = SubtitleSearchFilterSet(),
        diagnostics: SubtitleSearchDiagnosticSink? = nil,
        progress: SubtitleSearchProgressSink? = nil,
        progressResultLimit: Int? = nil,
        mode: SubtitleSearchPageMode = .exact
    ) throws -> SubtitleSearchPage {
        try Task.checkCancellation()
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
        guard let plan = Self.searchQueryPlan(for: query) else {
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
                .init("hasSubtitlePathFilter", subtitlePathFilter == nil ? "false" : "true"),
                .init("languageFilter", languageFilter.rawValue),
                .init("watchStateFilter", watchStateFilter.rawValue),
                .init("hasFilterSet", filterSet.isEffectivelyEmpty ? "false" : "true")
            ]
        )

        do {
            let setupStart = Self.diagnosticNow()
            let candidateBatchLimit = Self.searchCandidateBatchLimit(for: limit, mode: mode)
            var candidateOffset = 0
            var exactCueIDs: [Int64] = []
            var exactPageResults: [OrderedSearchResult] = []
            var exactRenderableResults: [OrderedSearchResult] = []
            let resolvedProgressResultLimit = progressResultLimit.map {
                max(0, $0)
            }
            var visiblePrefixResults: [OrderedSearchResult] = []
            var visibleWindowResults: [OrderedSearchResult] = []
            var progressFileSummaries = SearchFileSummaryAccumulator()
            var acceptedSearchResultCount = 0
            var reachedVisibleLookahead = false
            var batchIndex = 0
            var totalCandidates = 0
            var totalMultiLineCandidates = 0
            var totalCueLineRows = 0
            var languageDetectionsBySubtitleFileID: [Int64: SearchLanguageDetections] = [:]
            func rankedResults(
                from orderedResults: [OrderedSearchResult],
                startingAt startIndex: Int = 0
            ) -> [SubtitleSearchResult] {
                var results = orderedResults.map(\.result)
                for index in results.indices {
                    results[index].searchRank = startIndex + index
                }
                return results
            }
            let scopeCondition = pathPrefixes.map {
                let conditions = $0.map { _ in "(sf.subtitle_path >= ? AND sf.subtitle_path < ?)" }
                    .joined(separator: " OR ")
                return "AND (\(conditions))"
            } ?? ""
            let subtitlePathCondition = subtitlePathFilter.map { _ in "AND sf.subtitle_path = ?" } ?? ""
            let languageFilterCodes = Self.languageCodesForSearchFilter(languageFilter)
            let languageFilterCodeSet = Set(languageFilterCodes)
            let filtersByMatchingLineLanguage = !languageFilterCodeSet.isEmpty
            let languageConditionCodes = languageFilterCodes.contains(.unknown) ? [] : languageFilterCodes
            let languageCondition: String
            if languageConditionCodes.isEmpty {
                languageCondition = ""
            } else {
                let placeholders = Array(repeating: "?", count: languageConditionCodes.count)
                    .joined(separator: ", ")
                languageCondition = """
                AND (
                    EXISTS (
                        SELECT 1
                        FROM subtitle_cue_group_languages cgl
                        WHERE cgl.cue_group_id = g.id
                          AND cgl.language_code IN (\(placeholders))
                    )
                    OR NOT EXISTS (
                        SELECT 1
                        FROM subtitle_cue_group_languages cgl_missing
                        WHERE cgl_missing.cue_group_id = g.id
                    )
                )
                """
            }
            let watchStateValues = watchStateFilter.states.map(\.rawValue)
            let watchStateJoin = watchStateValues.isEmpty
                ? ""
                : "JOIN library_watch_states ws ON ws.video_file_id = vf.id"
            let watchStateCondition: String
            if watchStateValues.isEmpty {
                watchStateCondition = ""
            } else {
                let placeholders = Array(repeating: "?", count: watchStateValues.count)
                    .joined(separator: ", ")
                watchStateCondition = "AND ws.state IN (\(placeholders))"
            }
            emit(
                "setup",
                since: setupStart,
                fields: [
                    .init("candidateBatchLimit", candidateBatchLimit),
                    .init("scopeCondition", scopeCondition.isEmpty ? "none" : "path"),
                    .init("subtitlePathFilter", subtitlePathFilter == nil ? "false" : "true"),
                    .init("languageFilter", languageFilter.rawValue),
                    .init("watchStateFilter", watchStateFilter.rawValue),
                    .init("hasFilterSet", filterSet.isEffectivelyEmpty ? "false" : "true"),
                    .init("metadataMode", mode.rawValue)
                ]
            )

            let searchOrderRowsStart = Self.diagnosticNow()
            try Task.checkCancellation()
            try requireCompleteSearchOrderRows(
                pathPrefixes: pathPrefixes,
                subtitlePath: subtitlePathFilter
            )
            emit("search_order_rows_validated", since: searchOrderRowsStart)

            let prepareStart = Self.diagnosticNow()
            let statement = try database.prepare(
                """
                SELECT g.id, sf.id, sf.subtitle_path, sf.format, vf.path, vf.video_name,
                       g.start_ms, g.end_ms, g.time_range, g.search_content, g.line_count,
                       sor.subtitle_file_name, sor.display_title, sor.folder_order, sor.file_order
                FROM subtitle_cue_groups_fts f
                JOIN subtitle_cue_groups g ON g.id = f.cue_group_id
                JOIN subtitle_files sf ON sf.id = g.subtitle_file_id
                JOIN subtitle_video_matches m ON m.subtitle_file_id = sf.id AND m.is_active = 1
                JOIN video_files vf ON vf.id = m.video_file_id
                \(watchStateJoin)
                JOIN subtitle_search_order_rows sor ON sor.subtitle_file_id = sf.id
                WHERE subtitle_cue_groups_fts MATCH ?
                \(scopeCondition)
                \(subtitlePathCondition)
                \(languageCondition)
                \(watchStateCondition)
                ORDER BY f.rowid ASC
                LIMIT ? OFFSET ?;
                """
            )
            emit("statement_prepare", since: prepareStart)

            while true {
                try Task.checkCancellation()
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
                for languageCode in languageConditionCodes {
                    try statement.bind(languageCode.rawValue, at: bindIndex)
                    bindIndex += 1
                }
                for watchStateValue in watchStateValues {
                    try statement.bind(watchStateValue, at: bindIndex)
                    bindIndex += 1
                }
                try statement.bind(candidateBatchLimit, at: bindIndex)
                bindIndex += 1
                try statement.bind(candidateOffset, at: bindIndex)

                var candidates: [SearchCandidate] = []
                while try statement.step() {
                    try Task.checkCancellation()
                    candidates.append(
                        SearchCandidate(
                            cueGroupID: statement.int64Column(0),
                            subtitleFileID: statement.int64Column(1),
                            subtitlePath: statement.stringColumn(2),
                            subtitleFormat: SubtitleFormat(rawValue: statement.stringColumn(3)) ?? .srt,
                            videoPath: statement.stringColumn(4),
                            videoName: statement.stringColumn(5),
                            startMilliseconds: statement.intColumn(6),
                            endMilliseconds: statement.intColumn(7),
                            timeRange: statement.stringColumn(8),
                            searchContent: statement.stringColumn(9),
                            lineCount: statement.intColumn(10),
                            order: SearchResultOrder(
                                subtitleFileName: statement.stringColumn(11),
                                displayTitle: statement.stringColumn(12),
                                folderOrder: statement.intColumn(13),
                                fileOrder: statement.intColumn(14)
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

                let candidateCueGroupIDs = candidates.map(\.cueGroupID)
                let multiLineCueGroupIDs = candidates
                    .filter { $0.lineCount > 1 }
                    .map(\.cueGroupID)
                totalMultiLineCandidates += multiLineCueGroupIDs.count
                let cueLinesStart = Self.diagnosticNow()
                let cueLineRecordsByCueGroupID = try cueLineRecords(
                    forCueGroupIDs: candidateCueGroupIDs
                )
                let cueLineRows = cueLineRecordsByCueGroupID.values.reduce(0) { $0 + $1.count }
                totalCueLineRows += cueLineRows
                let cueIDs = cueLineRecordsByCueGroupID.values.flatMap { records in
                    records.map(\.id)
                }
                let speakersByCueID = try cueLineSpeakers(forCueIDs: cueIDs)
                var fallbackLanguageCueGroupIDs: [Int64] = []
                fallbackLanguageCueGroupIDs.reserveCapacity(candidates.count)
                for candidate in candidates {
                    let languageDetections: SearchLanguageDetections
                    if let cached = languageDetectionsBySubtitleFileID[candidate.subtitleFileID] {
                        languageDetections = cached
                    } else {
                        let loaded = try searchLanguageDetections(forSubtitleFileID: candidate.subtitleFileID)
                        languageDetectionsBySubtitleFileID[candidate.subtitleFileID] = loaded
                        languageDetections = loaded
                    }
                    if !languageDetections.hasAnyDetection {
                        fallbackLanguageCueGroupIDs.append(candidate.cueGroupID)
                    }
                }
                let languagesByCueGroupID = try cueGroupLanguages(
                    forCueGroupIDs: candidateCueGroupIDs
                )
                emit(
                    "cue_lines",
                    since: cueLinesStart,
                    fields: [
                        .init("batch", batchIndex),
                        .init("multiLineCandidates", multiLineCueGroupIDs.count),
                        .init("lineLanguageFilteredCandidates", filtersByMatchingLineLanguage ? candidates.count : 0),
                        .init("fallbackLanguageCandidates", fallbackLanguageCueGroupIDs.count),
                        .init("cueLineRows", cueLineRows)
                    ]
                )

                let validationStart = Self.diagnosticNow()
                let acceptedBefore = acceptedSearchResultCount
                var matchedCandidateCount = 0
                for candidate in candidates {
                    try Task.checkCancellation()
                    let orderedMatches = searchResults(
                        for: candidate,
                        cueLineRecords: cueLineRecordsByCueGroupID[candidate.cueGroupID] ?? [],
                        matching: plan,
                        languageFilterCodes: languageFilterCodeSet,
                        languageDetections: languageDetectionsBySubtitleFileID[candidate.subtitleFileID],
                        cueGroupLanguages: languagesByCueGroupID[candidate.cueGroupID] ?? [],
                        speakersByCueID: speakersByCueID,
                        filterSet: filterSet
                    )
                    if !orderedMatches.isEmpty {
                        matchedCandidateCount += 1
                    }
                    for result in orderedMatches {
                        switch mode {
                        case .exact:
                            exactCueIDs.append(result.result.entryID)
                            progressFileSummaries.add(result)
                            if progress != nil,
                               resolvedProgressResultLimit.map({
                                   exactRenderableResults.count < $0
                               }) ?? true {
                                exactRenderableResults.append(result)
                            }
                            if acceptedSearchResultCount >= offset && exactPageResults.count < limit {
                                exactPageResults.append(result)
                            }
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
                        .init("rejected", candidates.count - matchedCandidateCount),
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
                            fileSummaries: progressSummaries,
                            results: rankedResults(from: exactRenderableResults),
                            cueIDs: exactCueIDs
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
                try Task.checkCancellation()
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
                return page
            }

            let sortStart = Self.diagnosticNow()
            try Task.checkCancellation()
            let totalExactResultCount = exactCueIDs.count
            let orderSource = totalExactResultCount > 0 ? "ftsRowid" : "none"
            let materializedOrderRows = exactPageResults.count
            emit(
                "sort_results",
                since: sortStart,
                fields: [
                    .init("results", totalExactResultCount),
                    .init("materializedResults", exactPageResults.count),
                    .init("resultIDs", exactCueIDs.count),
                    .init("orderSource", orderSource),
                    .init("materializedOrderRows", materializedOrderRows)
                ]
            )

            let pageStart = Self.diagnosticNow()
            let pageResults = rankedResults(from: exactPageResults, startingAt: offset)
            let renderableResults = progress == nil
                ? pageResults
                : rankedResults(from: exactRenderableResults)
            let nextCursor = limit > 0 && offset + pageResults.count < totalExactResultCount
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
            let fileSummaries = progressFileSummaries.fileSummaries()
            let countSnapshot = SubtitleSearchCountSnapshot.exact(
                totalCount: totalExactResultCount,
                fileSummaryCount: fileSummaries.count
            )
            emit(
                "file_summaries",
                since: summariesStart,
                fields: [
                    .init("summaries", fileSummaries.count),
                    .init("results", totalExactResultCount),
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
                    .init("accepted", totalExactResultCount),
                    .init("pageResults", pageResults.count),
                    .init("summaries", fileSummaries.count),
                    .init("orderSource", orderSource),
                    .init("materializedOrderRows", materializedOrderRows),
                    .init("countState", countSnapshot.state.rawValue),
                    .init("knownResultCount", countSnapshot.knownResultCount),
                    .init("knownFileCount", countSnapshot.knownFileCount)
                ]
            )
            let page = SubtitleSearchPage(
                results: pageResults,
                renderableResults: renderableResults,
                cueIDs: exactCueIDs,
                totalCount: totalExactResultCount,
                fileSummaries: fileSummaries,
                countSnapshot: countSnapshot,
                appliedCursor: appliedCursor,
                nextCursor: nextCursor,
                pageMode: mode,
                orderSource: orderSource,
                materializedOrderRows: materializedOrderRows
            )
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
        languageFilter: SubtitleSearchLanguageFilter = .all,
        anchor: SearchNavigationAnchor,
        radius: Int = 1
    ) throws -> SearchNavigationSnapshot {
        let countPage = try searchPage(
            query,
            limit: 1,
            offset: 0,
            under: folders,
            languageFilter: languageFilter
        )
        let page = if countPage.totalCount <= countPage.results.count {
            countPage
        } else {
            try searchPage(
                query,
                limit: countPage.totalCount,
                offset: 0,
                under: folders,
                languageFilter: languageFilter
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

    public func libraryCoverEligibleVideos(under folders: [URL]) throws -> [LibraryCoverEligibleVideo] {
        let pathPrefixes = Self.folderPathPrefixes(for: folders)
        guard !pathPrefixes.isEmpty else {
            return []
        }

        let scopeCondition = pathPrefixes.map { _ in "(sf.subtitle_path >= ? AND sf.subtitle_path < ?)" }
            .joined(separator: " OR ")
        let statement = try database.prepare(
            """
            SELECT vf.id, vf.path, vf.video_name, vf.file_size, vf.duration,
                   sf.subtitle_path, sf.format
            FROM subtitle_files sf INDEXED BY idx_subtitle_files_subtitle_path
            JOIN subtitle_video_matches m ON m.subtitle_file_id = sf.id AND m.is_active = 1
            JOIN video_files vf ON vf.id = m.video_file_id
            WHERE \(scopeCondition)
            ORDER BY vf.path ASC, sf.subtitle_path ASC;
            """
        )

        var bindIndex: Int32 = 1
        for prefix in pathPrefixes {
            try statement.bind(prefix, at: bindIndex)
            bindIndex += 1
            try statement.bind(Self.pathPrefixUpperBound(for: prefix), at: bindIndex)
            bindIndex += 1
        }

        var videosByID: [Int64: LibraryCoverEligibleVideo] = [:]
        while try statement.step() {
            let videoFileID = statement.int64Column(0)
            let subtitleFormat = SubtitleFormat(rawValue: statement.stringColumn(6)) ?? .srt
            let subtitlePath = statement.stringColumn(5)
            let video = LibraryCoverEligibleVideo(
                videoFileID: videoFileID,
                videoPath: statement.stringColumn(1),
                videoName: statement.stringColumn(2),
                fileSize: statement.nullableInt64Column(3),
                duration: statement.nullableDoubleColumn(4),
                subtitlePath: subtitlePath,
                subtitleFormat: subtitleFormat,
                folderPath: Self.folderPath(forSubtitlePath: subtitlePath)
            )

            if let existing = videosByID[videoFileID] {
                let subtitleComparison = video.subtitlePath.localizedStandardCompare(existing.subtitlePath)
                if subtitleComparison == .orderedAscending {
                    videosByID[videoFileID] = video
                }
            } else {
                videosByID[videoFileID] = video
            }
        }

        return videosByID.values.sorted { lhs, rhs in
            Self.libraryVideoSort(lhs.libraryVideo, rhs.libraryVideo)
        }
    }

    public func libraryCoverDisplayCandidates(
        under folders: [URL]
    ) throws -> [LibraryCoverDisplayCandidate] {
        let pathPrefixes = Self.folderPathPrefixes(for: folders)
        guard !pathPrefixes.isEmpty else {
            return []
        }

        let scopeCondition = pathPrefixes.map { _ in
            "(sf.subtitle_path >= ? AND sf.subtitle_path < ?)"
        }
            .joined(separator: " OR ")
        let statement = try database.prepare(
            """
            SELECT vc.video_file_id, vf.path, vc.cover_path,
                   vc.display_cover_path, vc.display_profile_version
            FROM subtitle_files sf INDEXED BY idx_subtitle_files_subtitle_path
            JOIN subtitle_video_matches m ON m.subtitle_file_id = sf.id AND m.is_active = 1
            JOIN video_files vf ON vf.id = m.video_file_id
            JOIN video_covers vc ON vc.video_file_id = vf.id AND vc.status = ?
            WHERE \(scopeCondition)
            ORDER BY vf.path ASC, sf.subtitle_path ASC;
            """
        )

        var bindIndex: Int32 = 1
        try statement.bind(LibraryCoverStatus.generated.rawValue, at: bindIndex)
        bindIndex += 1
        for prefix in pathPrefixes {
            try statement.bind(prefix, at: bindIndex)
            bindIndex += 1
            try statement.bind(Self.pathPrefixUpperBound(for: prefix), at: bindIndex)
            bindIndex += 1
        }

        var candidatesByID: [Int64: LibraryCoverDisplayCandidate] = [:]
        while try statement.step() {
            let videoFileID = statement.int64Column(0)
            guard candidatesByID[videoFileID] == nil else {
                continue
            }
            candidatesByID[videoFileID] = LibraryCoverDisplayCandidate(
                videoFileID: videoFileID,
                videoPath: statement.stringColumn(1),
                masterCoverPath: statement.stringColumn(2),
                displayCoverPath: statement.nullableStringColumn(3),
                displayProfileVersion: statement.nullableIntColumn(4)
            )
        }

        return candidatesByID.values.sorted {
            $0.videoPath.localizedStandardCompare($1.videoPath) == .orderedAscending
        }
    }

    public func libraryVideoCover(forVideoFileID videoFileID: Int64) throws -> LibraryVideoCover? {
        let statement = try database.prepare(
            """
            SELECT video_file_id, cover_path, display_cover_path, display_profile_version,
                   source_time_ms, score, algorithm_version, generated_file_size,
                   generated_duration, status, error_message, generated_at
            FROM video_covers
            WHERE video_file_id = ?;
            """
        )
        try statement.bind(videoFileID, at: 1)

        guard try statement.step() else {
            return nil
        }

        return Self.libraryVideoCover(from: statement)
    }

    public func upsertLibraryVideoCover(
        videoFileID: Int64,
        masterCoverPath: String,
        displayCoverPath: String? = nil,
        displayProfileVersion: Int? = nil,
        sourceTimeMilliseconds: Int,
        score: Double?,
        algorithmVersion: Int,
        generatedFileSize: Int64?,
        generatedDuration: Double?,
        status: LibraryCoverStatus,
        errorMessage: String?
    ) throws {
        try Self.validateDisplayCover(
            path: displayCoverPath,
            profileVersion: displayProfileVersion
        )
        let statement = try database.prepare(
            """
            INSERT INTO video_covers(
                video_file_id,
                cover_path,
                display_cover_path,
                display_profile_version,
                source_time_ms,
                score,
                algorithm_version,
                generated_file_size,
                generated_duration,
                status,
                error_message,
                generated_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(video_file_id) DO UPDATE SET
                cover_path = excluded.cover_path,
                display_cover_path = excluded.display_cover_path,
                display_profile_version = excluded.display_profile_version,
                source_time_ms = excluded.source_time_ms,
                score = excluded.score,
                algorithm_version = excluded.algorithm_version,
                generated_file_size = excluded.generated_file_size,
                generated_duration = excluded.generated_duration,
                status = excluded.status,
                error_message = excluded.error_message,
                generated_at = excluded.generated_at;
            """
        )

        try statement.bind(videoFileID, at: 1)
        try statement.bind(masterCoverPath, at: 2)
        if let displayCoverPath {
            try statement.bind(displayCoverPath, at: 3)
        } else {
            try statement.bindNull(at: 3)
        }
        if let displayProfileVersion {
            try statement.bind(displayProfileVersion, at: 4)
        } else {
            try statement.bindNull(at: 4)
        }
        try statement.bind(max(0, sourceTimeMilliseconds), at: 5)
        if let score, score.isFinite {
            try statement.bind(score, at: 6)
        } else {
            try statement.bindNull(at: 6)
        }
        try statement.bind(algorithmVersion, at: 7)
        if let generatedFileSize {
            try statement.bind(generatedFileSize, at: 8)
        } else {
            try statement.bindNull(at: 8)
        }
        if let generatedDuration, generatedDuration.isFinite, generatedDuration >= 0 {
            try statement.bind(generatedDuration, at: 9)
        } else {
            try statement.bindNull(at: 9)
        }
        try statement.bind(status.rawValue, at: 10)
        if let errorMessage, !errorMessage.isEmpty {
            try statement.bind(errorMessage, at: 11)
        } else {
            try statement.bindNull(at: 11)
        }
        try statement.bind(Self.libraryCoverRevisionTimestamp(), at: 12)
        try statement.run()
    }

    public func updateLibraryVideoDisplayCover(
        videoFileID: Int64,
        displayCoverPath: String?,
        displayProfileVersion: Int?
    ) throws {
        try Self.validateDisplayCover(
            path: displayCoverPath,
            profileVersion: displayProfileVersion
        )
        let statement = try database.prepare(
            """
            UPDATE video_covers
            SET display_cover_path = ?,
                display_profile_version = ?,
                generated_at = ?
            WHERE video_file_id = ?;
            """
        )
        if let displayCoverPath {
            try statement.bind(displayCoverPath, at: 1)
        } else {
            try statement.bindNull(at: 1)
        }
        if let displayProfileVersion {
            try statement.bind(displayProfileVersion, at: 2)
        } else {
            try statement.bindNull(at: 2)
        }
        try statement.bind(Self.libraryCoverRevisionTimestamp(), at: 3)
        try statement.bind(videoFileID, at: 4)
        try statement.run()
    }

    public func libraryFolderCover(folderPath: String) throws -> LibraryFolderCover? {
        let statement = try database.prepare(
            """
            SELECT folder_path, cover_path, source_video_file_id, generated_at
            FROM folder_covers
            WHERE folder_path = ?;
            """
        )
        try statement.bind(folderPath, at: 1)

        guard try statement.step() else {
            return nil
        }

        return LibraryFolderCover(
            folderPath: statement.stringColumn(0),
            masterCoverPath: statement.stringColumn(1),
            sourceVideoFileID: statement.int64Column(2),
            generatedAt: statement.stringColumn(3)
        )
    }

    public func upsertLibraryFolderCover(
        folderPath: String,
        masterCoverPath: String,
        sourceVideoFileID: Int64
    ) throws {
        let statement = try database.prepare(
            """
            INSERT INTO folder_covers(folder_path, cover_path, source_video_file_id, generated_at)
            VALUES (?, ?, ?, ?)
            ON CONFLICT(folder_path) DO UPDATE SET
                cover_path = excluded.cover_path,
                source_video_file_id = excluded.source_video_file_id,
                generated_at = excluded.generated_at;
            """
        )

        try statement.bind(folderPath, at: 1)
        try statement.bind(masterCoverPath, at: 2)
        try statement.bind(sourceVideoFileID, at: 3)
        try statement.bind(ISO8601DateFormatter().string(from: Date()), at: 4)
        try statement.run()
    }

    public func deleteLibraryFolderCover(folderPath: String) throws {
        let statement = try database.prepare(
            """
            DELETE FROM folder_covers
            WHERE folder_path = ?;
            """
        )

        try statement.bind(folderPath, at: 1)
        try statement.run()
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

    public func recentLibraryWatching(
        under folders: [URL],
        limit: Int = 5
    ) throws -> [RecentLibraryWatchingPresentation] {
        try Task.checkCancellation()
        let cappedLimit = max(0, limit)
        guard cappedLimit > 0 else {
            return []
        }

        let pathPrefixes = Self.folderPathPrefixes(for: folders)
        guard !pathPrefixes.isEmpty else {
            return []
        }

        let scopeCondition = pathPrefixes.map { _ in "(lvr.subtitle_path >= ? AND lvr.subtitle_path < ?)" }
            .joined(separator: " OR ")
        let statement = try database.prepare(
            """
            SELECT lvr.folder_path, lvr.folder_title, lvr.video_path, lvr.video_name,
                   lvr.duration, lvr.subtitle_path, lvr.subtitle_format, lvr.display_title,
                   lvr.file_extension, lvr.video_order, h.position_ms, h.duration,
                   CASE
                       WHEN ws.state = 'finished' THEN COALESCE(h.started_at, ws.updated_at)
                       WHEN ws.state = 'watching' THEN COALESCE(h.started_at, ws.updated_at)
                       WHEN ws.state = 'unwatched' THEN NULL
                       ELSE h.started_at
                   END,
                   CASE
                       WHEN ws.state = 'finished' THEN ws.updated_at
                       WHEN ws.state = 'watching' THEN NULL
                       WHEN ws.state = 'unwatched' THEN NULL
                       ELSE h.completed_at
                   END,
                   h.updated_at, vc.display_cover_path, vc.generated_at
            FROM library_playback_history h
            JOIN library_video_rows lvr ON lvr.video_file_id = h.video_file_id
            LEFT JOIN library_watch_states ws ON ws.video_file_id = lvr.video_file_id
            LEFT JOIN video_files vf ON vf.id = lvr.video_file_id
            LEFT JOIN video_covers vc ON vc.video_file_id = vf.id
                AND vc.status = ? AND vc.display_profile_version = ?
            WHERE \(scopeCondition)
            ORDER BY julianday(h.updated_at) DESC, h.updated_at DESC,
                     lvr.folder_order ASC, lvr.video_order ASC, lvr.video_path ASC;
            """
        )

        var bindIndex: Int32 = 1
        try statement.bind(LibraryCoverStatus.generated.rawValue, at: bindIndex)
        bindIndex += 1
        try statement.bind(LibraryCoverDisplayProfileVersion.current, at: bindIndex)
        bindIndex += 1
        for prefix in pathPrefixes {
            try statement.bind(prefix, at: bindIndex)
            bindIndex += 1
            try statement.bind(Self.pathPrefixUpperBound(for: prefix), at: bindIndex)
            bindIndex += 1
        }

        var rows: [RecentLibraryWatchingPresentation] = []
        var seenFolderPaths = Set<String>()

        while try statement.step(), rows.count < cappedLimit {
            try Task.checkCancellation()
            let folderPath = statement.stringColumn(0)
            guard seenFolderPaths.insert(folderPath).inserted else {
                continue
            }

            rows.append(
                RecentLibraryWatchingPresentation(
                    videoPath: statement.stringColumn(2),
                    videoName: statement.stringColumn(3),
                    duration: statement.nullableDoubleColumn(4),
                    subtitlePath: statement.stringColumn(5),
                    subtitleFormat: SubtitleFormat(rawValue: statement.stringColumn(6)) ?? .srt,
                    displayTitle: statement.stringColumn(7),
                    fileExtension: statement.stringColumn(8),
                    folderPath: folderPath,
                    folderTitle: statement.stringColumn(1),
                    episodeNumber: max(1, statement.intColumn(9) + 1),
                    positionMilliseconds: max(0, statement.intColumn(10)),
                    playbackDuration: statement.nullableDoubleColumn(11),
                    startedAt: statement.nullableStringColumn(12),
                    completedAt: statement.nullableStringColumn(13),
                    updatedAt: statement.stringColumn(14),
                    coverPath: statement.nullableStringColumn(15),
                    coverRevision: statement.nullableStringColumn(16)
                )
            )
        }

        return rows
    }

    public func completeLibraryPresentation(
        under folders: [URL]
    ) throws -> [CompleteLibraryFolderPresentation] {
        let pathPrefixes = Self.folderPathPrefixes(for: folders)
        guard !pathPrefixes.isEmpty else {
            return []
        }

        let scopeCondition = pathPrefixes.map { _ in "(lvr.subtitle_path >= ? AND lvr.subtitle_path < ?)" }
            .joined(separator: " OR ")
        let statement = try database.prepare(
            """
            SELECT lvr.folder_path, lvr.folder_title, lvr.video_path, lvr.video_name,
                   lvr.duration, lvr.subtitle_path, lvr.subtitle_format, lvr.display_title,
                   lvr.file_extension, lvr.video_order, h.position_ms, h.duration,
                   CASE
                       WHEN ws.state = 'finished' THEN COALESCE(h.started_at, ws.updated_at)
                       WHEN ws.state = 'watching' THEN COALESCE(h.started_at, ws.updated_at)
                       WHEN ws.state = 'unwatched' THEN NULL
                       ELSE h.started_at
                   END,
                   CASE
                       WHEN ws.state = 'finished' THEN ws.updated_at
                       WHEN ws.state = 'watching' THEN NULL
                       WHEN ws.state = 'unwatched' THEN NULL
                       ELSE h.completed_at
                   END,
                   h.updated_at, julianday(h.updated_at),
                   vc.display_cover_path, fvc.display_cover_path,
                   vf.file_size, vf.video_codec,
                   vf.video_width, vf.video_height, vf.frame_rate,
                   vc.generated_at, fvc.generated_at
            FROM library_video_rows lvr
            LEFT JOIN library_playback_history h ON h.video_file_id = lvr.video_file_id
            LEFT JOIN library_watch_states ws ON ws.video_file_id = lvr.video_file_id
            LEFT JOIN video_files vf ON vf.id = lvr.video_file_id
            LEFT JOIN video_covers vc ON vc.video_file_id = vf.id
                AND vc.status = ? AND vc.display_profile_version = ?
            LEFT JOIN folder_covers fc ON fc.folder_path = lvr.folder_path
            LEFT JOIN video_covers fvc ON fvc.video_file_id = fc.source_video_file_id
                AND fvc.status = ? AND fvc.display_profile_version = ?
            WHERE \(scopeCondition)
            ORDER BY lvr.folder_order ASC, lvr.video_order ASC, lvr.video_path ASC;
            """
        )

        var bindIndex: Int32 = 1
        try statement.bind(LibraryCoverStatus.generated.rawValue, at: bindIndex)
        bindIndex += 1
        try statement.bind(LibraryCoverDisplayProfileVersion.current, at: bindIndex)
        bindIndex += 1
        try statement.bind(LibraryCoverStatus.generated.rawValue, at: bindIndex)
        bindIndex += 1
        try statement.bind(LibraryCoverDisplayProfileVersion.current, at: bindIndex)
        bindIndex += 1
        for prefix in pathPrefixes {
            try statement.bind(prefix, at: bindIndex)
            bindIndex += 1
            try statement.bind(Self.pathPrefixUpperBound(for: prefix), at: bindIndex)
            bindIndex += 1
        }

        var groups: [CompleteLibraryFolderPresentation] = []
        var currentFolderPath: String?
        var currentFolderTitle = ""
        var currentFolderCoverPath: String?
        var currentFolderCoverRevision: String?
        var currentVideos: [CompleteLibraryVideoPresentation] = []
        var currentLastWatchedEpisodeNumber: Int?
        var currentLastWatchedVideoPath: String?
        var currentLastWatchedSortValue: Double?
        var currentLastWatchedUpdatedAt: String?

        func appendCurrentGroup() {
            guard let currentFolderPath else {
                return
            }

            groups.append(
                CompleteLibraryFolderPresentation(
                    folderPath: currentFolderPath,
                    folderTitle: currentFolderTitle,
                    folderCoverPath: currentFolderCoverPath,
                    folderCoverRevision: currentFolderCoverRevision,
                    lastWatchedEpisodeNumber: currentLastWatchedEpisodeNumber,
                    lastWatchedVideoPath: currentLastWatchedVideoPath,
                    videos: currentVideos
                )
            )
        }

        func resetCurrentGroup(folderPath: String) {
            currentFolderPath = folderPath
            currentFolderTitle = statement.stringColumn(1)
            currentFolderCoverPath = statement.nullableStringColumn(17)
            currentFolderCoverRevision = statement.nullableStringColumn(24)
            currentVideos = []
            currentLastWatchedEpisodeNumber = nil
            currentLastWatchedVideoPath = nil
            currentLastWatchedSortValue = nil
            currentLastWatchedUpdatedAt = nil
        }

        while try statement.step() {
            let folderPath = statement.stringColumn(0)
            if currentFolderPath != folderPath {
                appendCurrentGroup()
                resetCurrentGroup(folderPath: folderPath)
            }

            let episodeNumber = max(1, statement.intColumn(9) + 1)
            let historyUpdatedAt = statement.nullableStringColumn(14)
            if let historyUpdatedAt {
                let historySortValue = statement.nullableDoubleColumn(15) ?? 0
                let shouldUpdateLatest: Bool
                if let currentLastWatchedSortValue {
                    shouldUpdateLatest = historySortValue > currentLastWatchedSortValue
                        || (
                            historySortValue == currentLastWatchedSortValue
                            && historyUpdatedAt > (currentLastWatchedUpdatedAt ?? "")
                        )
                } else {
                    shouldUpdateLatest = true
                }

                if shouldUpdateLatest {
                    currentLastWatchedEpisodeNumber = episodeNumber
                    currentLastWatchedVideoPath = statement.stringColumn(2)
                    currentLastWatchedSortValue = historySortValue
                    currentLastWatchedUpdatedAt = historyUpdatedAt
                }
            }

            currentVideos.append(
                CompleteLibraryVideoPresentation(
                    videoPath: statement.stringColumn(2),
                    videoName: statement.stringColumn(3),
                    fileSize: statement.nullableInt64Column(18),
                    videoCodec: statement.nullableStringColumn(19),
                    videoWidth: statement.nullableIntColumn(20),
                    videoHeight: statement.nullableIntColumn(21),
                    frameRate: statement.nullableDoubleColumn(22),
                    duration: statement.nullableDoubleColumn(4),
                    subtitlePath: statement.stringColumn(5),
                    subtitleFormat: SubtitleFormat(rawValue: statement.stringColumn(6)) ?? .srt,
                    displayTitle: statement.stringColumn(7),
                    fileExtension: statement.stringColumn(8),
                    episodeNumber: episodeNumber,
                    positionMilliseconds: max(0, statement.nullableIntColumn(10) ?? 0),
                    playbackDuration: statement.nullableDoubleColumn(11),
                    startedAt: statement.nullableStringColumn(12),
                    completedAt: statement.nullableStringColumn(13),
                    historyUpdatedAt: historyUpdatedAt,
                    coverPath: statement.nullableStringColumn(16),
                    coverRevision: statement.nullableStringColumn(23)
                )
            )
        }

        appendCurrentGroup()
        return groups
    }

    public func completeLibraryFolderSummaries(
        under folders: [URL]
    ) throws -> [CompleteLibraryFolderSummaryPresentation] {
        try Task.checkCancellation()
        let pathPrefixes = Self.folderPathPrefixes(for: folders)
        guard !pathPrefixes.isEmpty else {
            return []
        }

        let scopeCondition = pathPrefixes.map { _ in "(lvr.subtitle_path >= ? AND lvr.subtitle_path < ?)" }
            .joined(separator: " OR ")
        let statement = try database.prepare(
            """
            SELECT lvr.folder_path, lvr.folder_title, COUNT(*) AS episode_count,
                   fvc.display_cover_path,
                   (
                       SELECT vc.display_cover_path
                       FROM library_video_rows first_lvr
                       LEFT JOIN video_files first_vf ON first_vf.id = first_lvr.video_file_id
                       LEFT JOIN video_covers vc ON vc.video_file_id = first_vf.id
                           AND vc.status = ? AND vc.display_profile_version = ?
                       WHERE first_lvr.folder_path = lvr.folder_path
                       ORDER BY first_lvr.video_order ASC, first_lvr.video_path ASC
                       LIMIT 1
                   ) AS first_video_cover_path,
                   fvc.generated_at,
                   (
                       SELECT vc.generated_at
                       FROM library_video_rows first_lvr
                       LEFT JOIN video_files first_vf ON first_vf.id = first_lvr.video_file_id
                       LEFT JOIN video_covers vc ON vc.video_file_id = first_vf.id
                           AND vc.status = 'generated'
                           AND vc.display_profile_version = \(LibraryCoverDisplayProfileVersion.current)
                       WHERE first_lvr.folder_path = lvr.folder_path
                       ORDER BY first_lvr.video_order ASC, first_lvr.video_path ASC
                       LIMIT 1
                   ) AS first_video_cover_revision
            FROM library_video_rows lvr
            LEFT JOIN folder_covers fc ON fc.folder_path = lvr.folder_path
            LEFT JOIN video_covers fvc ON fvc.video_file_id = fc.source_video_file_id
                AND fvc.status = ? AND fvc.display_profile_version = ?
            WHERE \(scopeCondition)
            GROUP BY lvr.folder_path, lvr.folder_title,
                     fvc.display_cover_path, fvc.generated_at
            ORDER BY MIN(lvr.folder_order) ASC, lvr.folder_path ASC;
            """
        )

        var bindIndex: Int32 = 1
        try statement.bind(LibraryCoverStatus.generated.rawValue, at: bindIndex)
        bindIndex += 1
        try statement.bind(LibraryCoverDisplayProfileVersion.current, at: bindIndex)
        bindIndex += 1
        try statement.bind(LibraryCoverStatus.generated.rawValue, at: bindIndex)
        bindIndex += 1
        try statement.bind(LibraryCoverDisplayProfileVersion.current, at: bindIndex)
        bindIndex += 1
        for prefix in pathPrefixes {
            try statement.bind(prefix, at: bindIndex)
            bindIndex += 1
            try statement.bind(Self.pathPrefixUpperBound(for: prefix), at: bindIndex)
            bindIndex += 1
        }

        var summaries: [CompleteLibraryFolderSummaryPresentation] = []
        while try statement.step() {
            try Task.checkCancellation()
            let folderCoverPath = statement.nullableStringColumn(3)
            let fallbackCoverPath = statement.nullableStringColumn(4)
            let coverPath: String?
            let coverRevision: String?
            if let folderCoverPath {
                coverPath = folderCoverPath
                coverRevision = statement.nullableStringColumn(5)
            } else if let fallbackCoverPath {
                coverPath = fallbackCoverPath
                coverRevision = statement.nullableStringColumn(6)
            } else {
                coverPath = nil
                coverRevision = nil
            }
            summaries.append(
                CompleteLibraryFolderSummaryPresentation(
                    folderPath: statement.stringColumn(0),
                    folderTitle: statement.stringColumn(1),
                    coverPath: coverPath,
                    coverRevision: coverRevision,
                    episodeCount: max(0, statement.intColumn(2))
                )
            )
        }
        return summaries
    }

    public func completeLibraryFolderDetail(
        folderPath: String
    ) throws -> CompleteLibraryFolderDetailPresentation? {
        try Task.checkCancellation()
        let statement = try database.prepare(
            """
            SELECT lvr.folder_path, lvr.folder_title, lvr.video_path, lvr.video_name,
                   lvr.duration, lvr.subtitle_path, lvr.subtitle_format, lvr.display_title,
                   lvr.file_extension, lvr.video_order, h.position_ms, h.duration,
                   CASE
                       WHEN ws.state = 'finished' THEN COALESCE(h.started_at, ws.updated_at)
                       WHEN ws.state = 'watching' THEN COALESCE(h.started_at, ws.updated_at)
                       WHEN ws.state = 'unwatched' THEN NULL
                       ELSE h.started_at
                   END,
                   CASE
                       WHEN ws.state = 'finished' THEN ws.updated_at
                       WHEN ws.state = 'watching' THEN NULL
                       WHEN ws.state = 'unwatched' THEN NULL
                       ELSE h.completed_at
                   END,
                   h.updated_at, vc.display_cover_path,
                   vf.file_size, vf.video_codec, vf.video_width, vf.video_height,
                   vf.frame_rate, vc.generated_at
            FROM library_video_rows lvr
            LEFT JOIN library_playback_history h ON h.video_file_id = lvr.video_file_id
            LEFT JOIN library_watch_states ws ON ws.video_file_id = lvr.video_file_id
            LEFT JOIN video_files vf ON vf.id = lvr.video_file_id
            LEFT JOIN video_covers vc ON vc.video_file_id = vf.id
                AND vc.status = ? AND vc.display_profile_version = ?
            WHERE lvr.folder_path = ?
            ORDER BY lvr.video_order ASC, lvr.video_path ASC;
            """
        )
        try statement.bind(LibraryCoverStatus.generated.rawValue, at: 1)
        try statement.bind(LibraryCoverDisplayProfileVersion.current, at: 2)
        try statement.bind(folderPath, at: 3)

        var resolvedFolderPath: String?
        var folderTitle = ""
        var videos: [CompleteLibraryVideoPresentation] = []

        while try statement.step() {
            try Task.checkCancellation()
            if resolvedFolderPath == nil {
                resolvedFolderPath = statement.stringColumn(0)
                folderTitle = statement.stringColumn(1)
            }

            videos.append(
                CompleteLibraryVideoPresentation(
                    videoPath: statement.stringColumn(2),
                    videoName: statement.stringColumn(3),
                    fileSize: statement.nullableInt64Column(16),
                    videoCodec: statement.nullableStringColumn(17),
                    videoWidth: statement.nullableIntColumn(18),
                    videoHeight: statement.nullableIntColumn(19),
                    frameRate: statement.nullableDoubleColumn(20),
                    duration: statement.nullableDoubleColumn(4),
                    subtitlePath: statement.stringColumn(5),
                    subtitleFormat: SubtitleFormat(rawValue: statement.stringColumn(6)) ?? .srt,
                    displayTitle: statement.stringColumn(7),
                    fileExtension: statement.stringColumn(8),
                    episodeNumber: max(1, statement.intColumn(9) + 1),
                    positionMilliseconds: max(0, statement.nullableIntColumn(10) ?? 0),
                    playbackDuration: statement.nullableDoubleColumn(11),
                    startedAt: statement.nullableStringColumn(12),
                    completedAt: statement.nullableStringColumn(13),
                    historyUpdatedAt: statement.nullableStringColumn(14),
                    coverPath: statement.nullableStringColumn(15),
                    coverRevision: statement.nullableStringColumn(21)
                )
            )
        }

        guard let resolvedFolderPath else {
            return nil
        }
        return CompleteLibraryFolderDetailPresentation(
            folderPath: resolvedFolderPath,
            folderTitle: folderTitle,
            videos: videos
        )
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
                    video_file_id,
                    subtitle_file_id,
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
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
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
                    if let videoFileID = video.videoFileID {
                        try insert.bind(videoFileID, at: 2)
                    } else {
                        try insert.bindNull(at: 2)
                    }
                    if let subtitleFileID = video.subtitleFileID {
                        try insert.bind(subtitleFileID, at: 3)
                    } else {
                        try insert.bindNull(at: 3)
                    }
                    try insert.bind(video.videoName, at: 4)
                    if let duration = video.duration {
                        try insert.bind(duration, at: 5)
                    } else {
                        try insert.bindNull(at: 5)
                    }
                    try insert.bind(video.subtitlePath, at: 6)
                    try insert.bind(video.subtitleFormat.rawValue, at: 7)
                    try insert.bind(folderPath, at: 8)
                    try insert.bind(folderTitle, at: 9)
                    try insert.bind("\(folderTitle) - \(sequence)", at: 10)
                    try insert.bind(fileExtension, at: 11)
                    try insert.bind(folderOrder, at: 12)
                    try insert.bind(videoOrder, at: 13)
                    try insert.bind(updatedAt, at: 14)
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
            LEFT JOIN subtitle_search_order_rows sor ON sor.subtitle_file_id = sf.id
            WHERE sor.subtitle_file_id IS NULL
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
                SELECT id, subtitle_path
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
                SELECT id, subtitle_path
                FROM subtitle_files
                ORDER BY subtitle_path ASC;
                """
            )
        }

        var files: [SearchOrderFile] = []
        while try statement.step() {
            let subtitleFileID = statement.int64Column(0)
            let subtitlePath = statement.stringColumn(1)
            let folderPath = Self.folderPath(forSubtitlePath: subtitlePath)
            files.append(
                SearchOrderFile(
                    subtitleFileID: subtitleFileID,
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
                subtitle_file_id,
                folder_path,
                folder_title,
                subtitle_file_name,
                display_title,
                folder_order,
                file_order,
                updated_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
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
                try insert.bind(file.subtitleFileID, at: 2)
                try insert.bind(file.folderPath, at: 3)
                try insert.bind(file.folderTitle, at: 4)
                try insert.bind(file.subtitleFileName, at: 5)
                try insert.bind(SubtitleDisplayTitleResolver.displayTitle(forSubtitlePath: file.subtitlePath), at: 6)
                try insert.bind(folderOrder, at: 7)
                try insert.bind(fileOrder, at: 8)
                try insert.bind(updatedAt, at: 9)
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
            SELECT vf.id, sf.id, vf.path, vf.video_name, vf.duration,
                   sf.subtitle_path, sf.format
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
            let subtitleFormat = SubtitleFormat(rawValue: statement.stringColumn(6)) ?? .srt
            let video = LibraryVideo(
                videoFileID: statement.int64Column(0),
                subtitleFileID: statement.int64Column(1),
                videoPath: statement.stringColumn(2),
                videoName: statement.stringColumn(3),
                duration: statement.nullableDoubleColumn(4),
                subtitlePath: statement.stringColumn(5),
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
            WHERE video_file_id = (
                SELECT id FROM video_files WHERE path = ?
            );
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

    public func updateVideoMetadata(
        videoFile: URL,
        duration: Double?,
        videoWidth: Int?,
        videoHeight: Int?,
        frameRate: Double?,
        videoCodec: String?
    ) throws {
        let statement = try database.prepare(
            """
            UPDATE video_files
            SET duration = ?,
                video_width = ?,
                video_height = ?,
                frame_rate = ?,
                video_codec = ?
            WHERE path = ?;
            """
        )

        if let duration, duration.isFinite, duration >= 0 {
            try statement.bind(duration, at: 1)
        } else {
            try statement.bindNull(at: 1)
        }

        if let videoWidth, videoWidth > 0 {
            try statement.bind(videoWidth, at: 2)
        } else {
            try statement.bindNull(at: 2)
        }

        if let videoHeight, videoHeight > 0 {
            try statement.bind(videoHeight, at: 3)
        } else {
            try statement.bindNull(at: 3)
        }

        if let frameRate, frameRate.isFinite, frameRate > 0 {
            try statement.bind(frameRate, at: 4)
        } else {
            try statement.bindNull(at: 4)
        }

        let normalizedVideoCodec = videoCodec?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let normalizedVideoCodec, !normalizedVideoCodec.isEmpty {
            try statement.bind(normalizedVideoCodec, at: 5)
        } else {
            try statement.bindNull(at: 5)
        }

        try statement.bind(videoFile.path, at: 6)
        try statement.run()

        let snapshotStatement = try database.prepare(
            """
            UPDATE library_video_rows
            SET duration = ?
            WHERE video_file_id = (
                SELECT id FROM video_files WHERE path = ?
            );
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

    public func refreshVideoFileMetadata(_ videoFile: URL) throws {
        _ = try upsertVideoFile(videoFile)
    }

    public func libraryPlaybackHistory(forVideoFile videoFile: URL) throws -> LibraryPlaybackHistory? {
        let videoFileID = try videoFileID(for: videoFile)
        let statement = try database.prepare(
            """
            SELECT COALESCE(vf.path, h.video_path), h.position_ms, h.duration,
                   CASE
                       WHEN ws.state = 'finished' THEN COALESCE(h.started_at, ws.updated_at)
                       WHEN ws.state = 'watching' THEN COALESCE(h.started_at, ws.updated_at)
                       WHEN ws.state = 'unwatched' THEN NULL
                       ELSE h.started_at
                   END,
                   CASE
                       WHEN ws.state = 'finished' THEN ws.updated_at
                       WHEN ws.state = 'watching' THEN NULL
                       WHEN ws.state = 'unwatched' THEN NULL
                       ELSE h.completed_at
                   END,
                   h.updated_at
            FROM library_playback_history h
            LEFT JOIN video_files vf ON vf.id = h.video_file_id
            LEFT JOIN library_watch_states ws
              ON ws.video_file_id = h.video_file_id
              OR (
                  h.video_file_id IS NULL
                  AND ws.video_file_id IS NULL
                  AND ws.video_path = h.video_path
              )
            WHERE h.video_file_id = ? OR h.video_path = ?;
            """
        )

        if let videoFileID {
            try statement.bind(videoFileID, at: 1)
        } else {
            try statement.bindNull(at: 1)
        }
        try statement.bind(videoFile.path, at: 2)

        guard try statement.step() else {
            return nil
        }

        return LibraryPlaybackHistory(
            videoPath: statement.stringColumn(0),
            positionMilliseconds: max(0, statement.intColumn(1)),
            duration: statement.nullableDoubleColumn(2),
            startedAt: statement.nullableStringColumn(3),
            completedAt: statement.nullableStringColumn(4),
            updatedAt: statement.stringColumn(5)
        )
    }

    public func upsertLibraryPlaybackHistory(
        videoFile: URL,
        positionMilliseconds: Int,
        duration: Double?,
        updatedAt: Date = Date(),
        markStarted: Bool = true,
        markCompleted: Bool = false
    ) throws {
        let videoFileID = try upsertVideoFile(videoFile)
        let updatedAtString = Self.libraryPlaybackHistoryUpdatedAtString(from: updatedAt)
        let clampedPositionMilliseconds = max(0, positionMilliseconds)
        let normalizedDuration = duration.flatMap { value in
            value.isFinite && value > 0 ? value : nil
        }
        let startedAt = markStarted || markCompleted ? updatedAtString : nil
        let completedAt = markCompleted ? updatedAtString : nil

        let statement = try database.prepare(
            """
            INSERT INTO library_playback_history(
                video_path,
                video_file_id,
                position_ms,
                duration,
                started_at,
                completed_at,
                updated_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(video_path) DO UPDATE SET
                video_file_id = excluded.video_file_id,
                position_ms = excluded.position_ms,
                duration = excluded.duration,
                started_at = COALESCE(library_playback_history.started_at, excluded.started_at),
                completed_at = COALESCE(library_playback_history.completed_at, excluded.completed_at),
                updated_at = excluded.updated_at;
            """
        )

        try statement.bind(videoFile.path, at: 1)
        try statement.bind(videoFileID, at: 2)
        try statement.bind(clampedPositionMilliseconds, at: 3)
        if let normalizedDuration {
            try statement.bind(normalizedDuration, at: 4)
        } else {
            try statement.bindNull(at: 4)
        }
        if let startedAt {
            try statement.bind(startedAt, at: 5)
        } else {
            try statement.bindNull(at: 5)
        }
        if let completedAt {
            try statement.bind(completedAt, at: 6)
        } else {
            try statement.bindNull(at: 6)
        }
        try statement.bind(updatedAtString, at: 7)
        try statement.run()

        if markCompleted {
            try upsertLibraryWatchState(videoFile: videoFile, state: .finished, updatedAt: updatedAt)
        } else if markStarted {
            let currentWatchState = try libraryPlaybackHistory(forVideoFile: videoFile).map {
                LibraryWatchState(
                    positionMilliseconds: $0.positionMilliseconds,
                    duration: $0.duration,
                    startedAt: $0.startedAt,
                    completedAt: $0.completedAt
                )
            } ?? .unwatched
            if currentWatchState != .finished {
                try upsertLibraryWatchState(videoFile: videoFile, state: .watching, updatedAt: updatedAt)
            }
        }
    }

    public func setLibraryWatchState(
        videoFile: URL,
        duration _: Double?,
        state: LibraryWatchState,
        updatedAt: Date = Date()
    ) throws {
        try upsertLibraryWatchState(videoFile: videoFile, state: state, updatedAt: updatedAt)
    }

    private func upsertLibraryWatchState(
        videoFile: URL,
        state: LibraryWatchState,
        updatedAt: Date = Date()
    ) throws {
        let videoFileID = try upsertVideoFile(videoFile)
        let updatedAtString = Self.libraryPlaybackHistoryUpdatedAtString(from: updatedAt)
        let statement = try database.prepare(
            """
            INSERT INTO library_watch_states(video_path, video_file_id, state, updated_at)
            VALUES (?, ?, ?, ?)
            ON CONFLICT(video_path) DO UPDATE SET
                video_file_id = excluded.video_file_id,
                state = excluded.state,
                updated_at = excluded.updated_at;
            """
        )
        try statement.bind(videoFile.path, at: 1)
        try statement.bind(videoFileID, at: 2)
        try statement.bind(state.rawValue, at: 3)
        try statement.bind(updatedAtString, at: 4)
        try statement.run()
    }

    private static let resolvedShioriSelectSQL = """
        SELECT s.id, sf.subtitle_path, sf.format, vf.path, vf.video_name,
               l.start_ms, l.end_ms, l.event_index, l.display_order,
               l.content, 1, s.created_at
        FROM shioris s
        JOIN subtitle_cue_lines l ON l.id = s.cue_id
        JOIN subtitle_files sf ON sf.id = l.subtitle_file_id
        JOIN subtitle_video_matches m
          ON m.subtitle_file_id = sf.id AND m.is_active = 1
        JOIN video_files vf ON vf.id = m.video_file_id
        """

    public func upsertShiori(
        subtitleFile: URL,
        subtitleFormat: SubtitleFormat,
        videoFile: URL,
        videoName: String,
        selection: SubtitleCueTextSelection,
        createdAt: Date = Date()
    ) throws -> Shiori {
        guard let cueID = selection.cueLineID else {
            throw SQLiteDatabaseError.stepFailed(
                "Shiori requires a CueID"
            )
        }

        _ = subtitleFile
        _ = subtitleFormat
        _ = videoFile
        _ = videoName

        let statement = try database.prepare(
            """
            INSERT INTO shioris(
                list_id,
                cue_id,
                created_at
            )
            VALUES (?, ?, ?)
            ON CONFLICT(list_id, cue_id) DO NOTHING;
            """
        )

        try statement.bind(ShioriListIdentity.defaultListID, at: 1)
        try statement.bind(cueID, at: 2)
        try statement.bind(ISO8601DateFormatter().string(from: createdAt), at: 3)
        try statement.run()

        guard let savedShiori = try shiori(
            cueID: cueID,
            listID: ShioriListIdentity.defaultListID
        ) else {
            throw SQLiteDatabaseError.stepFailed("Inserted Shiori could not be loaded")
        }

        return savedShiori
    }

    public func shiori(
        cueID: Int64,
        listID: Int64 = ShioriListIdentity.defaultListID
    ) throws -> Shiori? {
        let statement = try database.prepare(
            """
            \(Self.resolvedShioriSelectSQL)
            WHERE s.list_id = ? AND s.cue_id = ?;
            """
        )
        try statement.bind(listID, at: 1)
        try statement.bind(cueID, at: 2)
        guard try statement.step() else {
            return nil
        }
        return shiori(from: statement)
    }

    public func shioriLists() throws -> [ShioriList] {
        let statement = try database.prepare(
            """
            SELECT id, name, created_at
            FROM shiori_lists
            ORDER BY id ASC;
            """
        )
        var lists: [ShioriList] = []
        while try statement.step() {
            lists.append(ShioriList(
                id: statement.int64Column(0),
                name: statement.stringColumn(1),
                createdAt: statement.stringColumn(2)
            ))
        }
        return lists
    }

    public func shioriRelations(
        listID: Int64 = ShioriListIdentity.defaultListID
    ) throws -> [ShioriRelation] {
        let statement = try database.prepare(
            """
            SELECT id, list_id, cue_id, created_at
            FROM shioris
            WHERE list_id = ?
            ORDER BY created_at DESC, id DESC;
            """
        )
        try statement.bind(listID, at: 1)
        var relations: [ShioriRelation] = []
        while try statement.step() {
            relations.append(shioriRelation(from: statement))
        }
        return relations
    }

    public func shioriResidentSnapshot(
        listID: Int64 = ShioriListIdentity.defaultListID
    ) throws -> ShioriResidentSnapshot {
        let relations = try shioriRelations(listID: listID)
        let cueContents = try cueContents(forCueIDs: relations.map(\.cueID))
        guard cueContents.map(\.cueID) == relations.map(\.cueID) else {
            throw SQLiteDatabaseError.stepFailed(
                "Every Shiori relation must resolve its current Cue content"
            )
        }
        return ShioriResidentSnapshot(
            relations: relations,
            cueContents: cueContents,
            tagsByShioriID: try shioriTagsByShioriID(
                forShioriIDs: relations.map(\.id)
            )
        )
    }

    public func shioriRelation(id: Int64) throws -> ShioriRelation? {
        let statement = try database.prepare(
            """
            SELECT id, list_id, cue_id, created_at
            FROM shioris
            WHERE id = ?;
            """
        )
        try statement.bind(id, at: 1)
        guard try statement.step() else { return nil }
        return shioriRelation(from: statement)
    }

    public func cueID(forShioriID shioriID: Int64) throws -> Int64? {
        let statement = try database.prepare(
            "SELECT cue_id FROM shioris WHERE id = ?;"
        )
        try statement.bind(shioriID, at: 1)
        guard try statement.step() else {
            return nil
        }
        return statement.nullableInt64Column(0)
    }

    public func shiori(
        subtitleFile: URL,
        startMilliseconds: Int,
        endMilliseconds: Int
    ) throws -> Shiori? {
        let statement = try database.prepare(
            """
            \(Self.resolvedShioriSelectSQL)
            WHERE s.list_id = ?
              AND sf.subtitle_path = ?
              AND l.start_ms = ?
              AND l.end_ms = ?
            ORDER BY l.display_order DESC, l.event_index DESC, s.id ASC
            LIMIT 1;
            """
        )
        try statement.bind(ShioriListIdentity.defaultListID, at: 1)
        try statement.bind(subtitleFile.path, at: 2)
        try statement.bind(max(0, startMilliseconds), at: 3)
        try statement.bind(max(startMilliseconds, endMilliseconds), at: 4)
        guard try statement.step() else {
            return nil
        }
        return shiori(from: statement)
    }

    public func shiori(id: Int64) throws -> Shiori? {
        let statement = try database.prepare(
            """
            \(Self.resolvedShioriSelectSQL)
            WHERE s.id = ?;
            """
        )

        try statement.bind(id, at: 1)

        guard try statement.step() else {
            return nil
        }

        return shiori(from: statement)
    }

    public func adjacentShiori(
        to item: Shiori,
        direction: ShioriNavigationDirection
    ) throws -> Shiori? {
        let orderingPredicate: String
        let orderingClause: String
        switch direction {
        case .previous:
            orderingPredicate = "(s.created_at > ? OR (s.created_at = ? AND s.id > ?))"
            orderingClause = "ORDER BY s.created_at ASC, s.id ASC"
        case .next:
            orderingPredicate = "(s.created_at < ? OR (s.created_at = ? AND s.id < ?))"
            orderingClause = "ORDER BY s.created_at DESC, s.id DESC"
        }

        let statement = try database.prepare(
            """
            \(Self.resolvedShioriSelectSQL)
            WHERE s.list_id = ? AND \(orderingPredicate)
            \(orderingClause)
            LIMIT 1;
            """
        )

        try statement.bind(ShioriListIdentity.defaultListID, at: 1)
        try statement.bind(item.createdAt, at: 2)
        try statement.bind(item.createdAt, at: 3)
        try statement.bind(item.id, at: 4)

        guard try statement.step() else {
            return nil
        }

        return shiori(from: statement)
    }

    public func shioris() throws -> [Shiori] {
        let statement = try database.prepare(
            """
            \(Self.resolvedShioriSelectSQL)
            WHERE s.list_id = ?
            ORDER BY sf.subtitle_path ASC, l.start_ms ASC, l.end_ms ASC, s.id ASC;
            """
        )
        try statement.bind(ShioriListIdentity.defaultListID, at: 1)

        var shioris: [Shiori] = []
        while try statement.step() {
            shioris.append(shiori(from: statement))
        }
        return shioris
    }

    public func shioriCount() throws -> Int {
        let statement = try database.prepare(
            """
            SELECT COUNT(*)
            FROM shioris
            WHERE list_id = ?;
            """
        )
        try statement.bind(ShioriListIdentity.defaultListID, at: 1)

        guard try statement.step() else {
            return 0
        }
        return statement.intColumn(0)
    }

    public func shioriPage(limit: Int, offset: Int) throws -> ShioriPage {
        let totalCount = try shioriCount()
        let safeLimit = max(0, limit)
        let safeOffset = max(0, offset)
        guard safeLimit > 0, safeOffset < totalCount else {
            return ShioriPage(
                shioris: [],
                totalCount: totalCount,
                languagesByShioriID: [:]
            )
        }

        let candidates = try shioriTableCandidates(limit: safeLimit, offset: safeOffset)
        return shioriPage(from: candidates, totalCount: totalCount)
    }

    public func shioriPage(shioriIDs: [Int64]) throws -> ShioriPage {
        var seenIDs: Set<Int64> = []
        let orderedUniqueIDs = shioriIDs.filter { seenIDs.insert($0).inserted }
        guard !orderedUniqueIDs.isEmpty else {
            return ShioriPage(
                shioris: [],
                totalCount: 0,
                languagesByShioriID: [:]
            )
        }

        let candidates = try shioriTableCandidates(shioriIDs: orderedUniqueIDs)
        return shioriPage(from: candidates, totalCount: candidates.count)
    }

    public func shioriTableIDIndex(
        searchText: String,
        filterSet: SubtitleSearchFilterSet
    ) throws -> ShioriTableIDIndex {
        try shioriTableIDIndex(
            searchText: searchText,
            filterSet: filterSet,
            didReadCandidate: nil
        )
    }

    func shioriTableIDIndex(
        searchText: String,
        filterSet: SubtitleSearchFilterSet,
        didReadCandidate: ((Int) -> Void)?
    ) throws -> ShioriTableIDIndex {
        var shioriIDs: [Int64] = []
        _ = try scanShioriTableMatches(
            searchText: searchText,
            filterSet: filterSet,
            didReadCandidate: didReadCandidate
        ) { shioriID, _ in
            shioriIDs.append(shioriID)
        }
        return ShioriTableIDIndex(shioriIDs: shioriIDs)
    }

    public func shioriTablePage(
        limit: Int,
        offset: Int,
        searchText: String,
        filterSet: SubtitleSearchFilterSet
    ) throws -> ShioriPage {
        let safeLimit = max(0, limit)
        let safeOffset = max(0, offset)
        let trimmedSearchText = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSearchText.isEmpty || !filterSet.isEffectivelyEmpty else {
            return try shioriPage(limit: safeLimit, offset: safeOffset)
        }

        let requestedUpperBound: Int
        let (summedUpperBound, didOverflow) = safeOffset.addingReportingOverflow(
            safeLimit
        )
        requestedUpperBound = didOverflow ? Int.max : summedUpperBound
        let requestedRange = safeOffset..<requestedUpperBound
        var pageIDs: [Int64] = []
        pageIDs.reserveCapacity(min(safeLimit, 1_024))
        let totalCount = try scanShioriTableMatches(
            searchText: trimmedSearchText,
            filterSet: filterSet,
            didReadCandidate: nil
        ) { shioriID, ordinal in
            if requestedRange.contains(ordinal) {
                pageIDs.append(shioriID)
            }
        }
        let pageCandidates = try shioriTableCandidates(shioriIDs: pageIDs)
        return shioriPage(from: pageCandidates, totalCount: totalCount)
    }

    public func shiorisWithLanguages() throws -> ShioriPage {
        let candidates = try shioriTableCandidates(limit: nil, offset: 0)
        return shioriPage(from: candidates, totalCount: candidates.count)
    }

    private static let shioriTableCandidateSelectSQL = """
        SELECT s.id, sf.subtitle_path, sf.format, vf.path, vf.video_name,
               l.start_ms, l.end_ms, l.event_index, l.display_order,
               l.content, 1, s.created_at,
               sor.display_title,
               sf.id,
               l.id, l.cue_group_id, l.event_index, l.source_format,
               l.source_style, l.source_layer, l.start_time, l.end_time,
               l.start_ms, l.end_ms, l.content, l.display_x, l.display_y,
               l.display_order,
               resolved_group.line_count,
               (
                   SELECT GROUP_CONCAT(cgl.language_code)
                   FROM subtitle_cue_group_languages cgl
                   WHERE cgl.cue_group_id = l.cue_group_id
               ) AS language_values
        FROM shioris s
        JOIN subtitle_cue_lines l ON l.id = s.cue_id
        JOIN subtitle_cue_groups resolved_group ON resolved_group.id = l.cue_group_id
        JOIN subtitle_files sf ON sf.id = l.subtitle_file_id
        JOIN subtitle_video_matches m
          ON m.subtitle_file_id = sf.id AND m.is_active = 1
        JOIN video_files vf ON vf.id = m.video_file_id
        LEFT JOIN subtitle_search_order_rows sor ON sor.subtitle_file_id = sf.id
        """

    private func scanShioriTableMatches(
        searchText: String,
        filterSet: SubtitleSearchFilterSet,
        didReadCandidate: ((Int) -> Void)?,
        onMatch: (Int64, Int) -> Void
    ) throws -> Int {
        let trimmedSearchText = searchText.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let activeFields = Set(filterSet.rules.compactMap { rule in
            rule.isActive ? rule.field : nil
        })
        let requiresLanguages = activeFields.contains(.language)
        let requiresSpeakers = activeFields.contains(.speaker)

        if trimmedSearchText.isEmpty, filterSet.isEffectivelyEmpty {
            let statement = try database.prepare(
                """
                SELECT id
                FROM shioris
                WHERE list_id = 1
                ORDER BY created_at DESC, id DESC;
                """
            )
            var readCount = 0
            var acceptedCount = 0
            while true {
                try Task.checkCancellation()
                guard try statement.step() else {
                    break
                }
                try Task.checkCancellation()
                readCount += 1
                didReadCandidate?(readCount)
                try Task.checkCancellation()
                onMatch(statement.int64Column(0), acceptedCount)
                acceptedCount += 1
            }
            try Task.checkCancellation()
            return acceptedCount
        }

        if !requiresLanguages, !requiresSpeakers {
            let statement = try database.prepare(
                """
                SELECT s.id, l.content, sor.display_title, sf.subtitle_path
                FROM shioris s
                JOIN subtitle_cue_lines l ON l.id = s.cue_id
                JOIN subtitle_files sf ON sf.id = l.subtitle_file_id
                LEFT JOIN subtitle_search_order_rows sor
                  ON sor.subtitle_file_id = l.subtitle_file_id
                WHERE s.list_id = 1
                ORDER BY s.created_at DESC, s.id DESC;
                """
            )
            var readCount = 0
            var acceptedCount = 0
            while true {
                try Task.checkCancellation()
                guard try statement.step() else {
                    break
                }
                try Task.checkCancellation()
                readCount += 1
                didReadCandidate?(readCount)
                try Task.checkCancellation()

                let displayTitle = Self.shioriDisplayTitle(
                    rawValue: statement.nullableStringColumn(2),
                    subtitlePath: statement.stringColumn(3)
                )
                let cues = statement.stringColumn(1)
                guard Self.shioriMatchesSearchText(
                    trimmedSearchText,
                    displayTitle: displayTitle,
                    cues: cues
                ), filterSet.matches(
                    display: displayTitle,
                    cues: cues,
                    languages: [],
                    speakers: []
                ) else {
                    continue
                }
                onMatch(statement.int64Column(0), acceptedCount)
                acceptedCount += 1
            }
            try Task.checkCancellation()
            return acceptedCount
        }

        if requiresSpeakers, !requiresLanguages {
            let statement = try database.prepare(
                """
                SELECT s.id, l.content, sor.display_title, sf.subtitle_path,
                       (
                           SELECT GROUP_CONCAT(speaker_hex, ',')
                           FROM (
                               SELECT hex(speaker) AS speaker_hex
                               FROM subtitle_cue_line_speakers cls
                               WHERE cls.cue_line_id = l.id
                               GROUP BY speaker_key, speaker
                               ORDER BY speaker_key ASC
                           )
                       ) AS speaker_hex_values
                FROM shioris s
                JOIN subtitle_cue_lines l ON l.id = s.cue_id
                JOIN subtitle_files sf ON sf.id = l.subtitle_file_id
                LEFT JOIN subtitle_search_order_rows sor
                  ON sor.subtitle_file_id = l.subtitle_file_id
                WHERE s.list_id = 1
                ORDER BY s.created_at DESC, s.id DESC;
                """
            )
            var readCount = 0
            var acceptedCount = 0
            while true {
                try Task.checkCancellation()
                guard try statement.step() else {
                    break
                }
                try Task.checkCancellation()
                readCount += 1
                didReadCandidate?(readCount)
                try Task.checkCancellation()

                let displayTitle = Self.shioriDisplayTitle(
                    rawValue: statement.nullableStringColumn(2),
                    subtitlePath: statement.stringColumn(3)
                )
                let cues = statement.stringColumn(1)
                let speakers = Self.speakerHexValues(
                    from: statement.nullableStringColumn(4)
                )
                guard Self.shioriMatchesSearchText(
                    trimmedSearchText,
                    displayTitle: displayTitle,
                    cues: cues
                ), filterSet.matches(
                    display: displayTitle,
                    cues: cues,
                    languages: [],
                    speakers: Self.filterSetSpeakerValues(speakers)
                ) else {
                    continue
                }
                onMatch(statement.int64Column(0), acceptedCount)
                acceptedCount += 1
            }
            try Task.checkCancellation()
            return acceptedCount
        }

        let languageSelect = requiresLanguages ?
            """
            ,
                   (
                       SELECT GROUP_CONCAT(cgl.language_code)
                       FROM subtitle_cue_group_languages cgl
                       WHERE cgl.cue_group_id = l.cue_group_id
                   ) AS language_values
            """ : ""
        let speakerSelect = requiresSpeakers ?
            """
            ,
                   (
                       SELECT GROUP_CONCAT(speaker_hex, ',')
                       FROM (
                           SELECT hex(speaker) AS speaker_hex
                           FROM subtitle_cue_line_speakers cls
                           WHERE cls.cue_line_id = l.id
                           GROUP BY speaker_key, speaker
                           ORDER BY speaker_key ASC
                       )
                   ) AS speaker_hex_values
            """ : ""
        let statement = try database.prepare(
            """
            SELECT s.id, sf.subtitle_path, sf.format, l.content,
                   sor.display_title, sf.id,
                   l.id, l.cue_group_id, l.event_index, l.source_format,
                   l.source_style, l.source_layer, l.start_time, l.end_time,
                   l.start_ms, l.end_ms, l.content, l.display_x, l.display_y,
                   l.display_order, resolved_group.line_count
                   \(languageSelect)
                   \(speakerSelect)
            FROM shioris s
            JOIN subtitle_cue_lines l ON l.id = s.cue_id
            JOIN subtitle_cue_groups resolved_group
              ON resolved_group.id = l.cue_group_id
            JOIN subtitle_files sf ON sf.id = l.subtitle_file_id
            LEFT JOIN subtitle_search_order_rows sor
              ON sor.subtitle_file_id = sf.id
            WHERE s.list_id = 1
            ORDER BY s.created_at DESC, s.id DESC;
            """
        )
        let languageColumnIndex: Int? = requiresLanguages ? 21 : nil
        let speakerColumnIndex: Int? = requiresSpeakers
            ? (requiresLanguages ? 22 : 21)
            : nil
        var readCount = 0
        var acceptedCount = 0
        var languageDetectionsBySubtitleFileID: [Int64: SearchLanguageDetections] = [:]
        while true {
            try Task.checkCancellation()
            guard try statement.step() else {
                break
            }
            try Task.checkCancellation()
            readCount += 1
            didReadCandidate?(readCount)
            try Task.checkCancellation()

            let shioriID = statement.int64Column(0)
            let subtitlePath = statement.stringColumn(1)
            let subtitleFormat = SubtitleFormat(
                rawValue: statement.stringColumn(2)
            ) ?? .srt
            let cues = statement.stringColumn(3)
            let displayTitle = Self.shioriDisplayTitle(
                rawValue: statement.nullableStringColumn(4),
                subtitlePath: subtitlePath
            )
            let cueLineRecord: SubtitleCueLineRecord? = if statement
                .nullableInt64Column(6) != nil {
                cueLineRecord(from: statement, startingAt: 6)
            } else {
                nil
            }
            let languages: Set<SubtitleLanguageCode>
            if let languageColumnIndex {
                let cueGroupLanguages = Self.languageValues(
                    from: statement.nullableStringColumn(
                        Int32(languageColumnIndex)
                    )
                )
                if let subtitleFileID = statement.nullableInt64Column(5),
                   let cueLineRecord {
                    let languageDetections: SearchLanguageDetections
                    if let cached = languageDetectionsBySubtitleFileID[
                        subtitleFileID
                    ] {
                        languageDetections = cached
                    } else {
                        try Task.checkCancellation()
                        let loaded = try searchLanguageDetections(
                            forSubtitleFileID: subtitleFileID
                        )
                        try Task.checkCancellation()
                        languageDetectionsBySubtitleFileID[
                            subtitleFileID
                        ] = loaded
                        languageDetections = loaded
                    }
                    let languageCandidate = SearchCandidate(
                        cueGroupID: cueLineRecord.cueGroupID,
                        subtitleFileID: subtitleFileID,
                        subtitlePath: subtitlePath,
                        subtitleFormat: subtitleFormat,
                        videoPath: "",
                        videoName: "",
                        startMilliseconds: cueLineRecord.line.startMilliseconds,
                        endMilliseconds: cueLineRecord.line.endMilliseconds,
                        timeRange: "",
                        searchContent: cueLineRecord.line.content,
                        lineCount: statement.nullableIntColumn(20) ?? 1,
                        order: SearchResultOrder(
                            subtitleFileName: URL(
                                fileURLWithPath: subtitlePath
                            ).lastPathComponent,
                            displayTitle: displayTitle,
                            folderOrder: 0,
                            fileOrder: 0
                        )
                    )
                    languages = Self.displayLanguages(
                        for: cueLineRecord.line,
                        candidate: languageCandidate,
                        detections: languageDetections,
                        cueGroupLanguages: cueGroupLanguages
                    )
                } else {
                    languages = cueGroupLanguages
                }
            } else {
                languages = []
            }
            let speakers = speakerColumnIndex.map { columnIndex in
                Self.speakerHexValues(
                    from: statement.nullableStringColumn(Int32(columnIndex))
                )
            } ?? []
            guard Self.shioriMatchesSearchText(
                trimmedSearchText,
                displayTitle: displayTitle,
                cues: cues
            ), filterSet.matches(
                display: displayTitle,
                cues: cues,
                languages: Self.filterSetLanguageValues(languages),
                speakers: Self.filterSetSpeakerValues(speakers)
            ) else {
                continue
            }
            onMatch(shioriID, acceptedCount)
            acceptedCount += 1
        }
        try Task.checkCancellation()
        return acceptedCount
    }

    private func shioriTableCandidates(limit: Int?, offset: Int) throws -> [ShioriTableCandidate] {
        let limitClause = limit == nil ? "" : "LIMIT ? OFFSET ?"
        let statement = try database.prepare(
            """
            \(Self.shioriTableCandidateSelectSQL)
            WHERE s.list_id = 1
            ORDER BY s.created_at DESC, s.id DESC
            \(limitClause);
            """
        )

        if let limit {
            try statement.bind(max(0, limit), at: 1)
            try statement.bind(max(0, offset), at: 2)
        }

        return try shioriTableCandidates(from: statement)
    }

    private func shioriTableCandidates(shioriIDs: [Int64]) throws -> [ShioriTableCandidate] {
        guard !shioriIDs.isEmpty else {
            return []
        }

        let placeholders = shioriIDs.map { _ in "?" }.joined(separator: ", ")
        let statement = try database.prepare(
            """
            \(Self.shioriTableCandidateSelectSQL)
            WHERE s.list_id = 1 AND s.id IN (\(placeholders))
            ORDER BY s.id ASC;
            """
        )
        for (offset, shioriID) in shioriIDs.enumerated() {
            try statement.bind(shioriID, at: Int32(offset + 1))
        }

        let candidates = try shioriTableCandidates(from: statement)
        let candidatesByID = Dictionary(uniqueKeysWithValues: candidates.map { candidate in
            (candidate.shiori.id, candidate)
        })
        return shioriIDs.compactMap { candidatesByID[$0] }
    }

    private func shioriTableCandidates(
        from statement: SQLiteStatement
    ) throws -> [ShioriTableCandidate] {
        var unresolvedCandidates: [ShioriTableUnresolvedCandidate] = []
        var languageDetectionsBySubtitleFileID: [Int64: SearchLanguageDetections] = [:]
        while true {
            try Task.checkCancellation()
            guard try statement.step() else {
                break
            }
            try Task.checkCancellation()
            unresolvedCandidates.append(
                try shioriTableUnresolvedCandidate(
                    from: statement,
                    languageDetectionsBySubtitleFileID: &languageDetectionsBySubtitleFileID
                )
            )
        }
        try Task.checkCancellation()
        let cueGroupIDs = Array(Set(unresolvedCandidates.compactMap(\.cueGroupID))).sorted()
        let groupRecordsByID = try cueLineRecords(forCueGroupIDs: cueGroupIDs)
        let cueIDs = unresolvedCandidates.compactMap(\.cueLineID)
        let speakersByCueID = try cueLineSpeakers(forCueIDs: cueIDs)
        return unresolvedCandidates.map { candidate in
            let groupRecords = candidate.cueGroupID.flatMap { groupRecordsByID[$0] } ?? []
            let primaryGroupIndex = candidate.cueLineID.flatMap { cueID in
                groupRecords.firstIndex { $0.id == cueID }
            }
            let cueGroupTexts = groupRecords.isEmpty
                ? [candidate.shiori.content]
                : groupRecords.map(\.line.content)
            return ShioriTableCandidate(
                shiori: candidate.shiori,
                displayTitle: candidate.displayTitle,
                languages: candidate.languages,
                cuePresentation: ShioriCuePresentation(
                    cueID: candidate.cueLineID,
                    cueGroupID: candidate.cueGroupID,
                    primaryGroupIndex: primaryGroupIndex,
                    cueGroupTexts: cueGroupTexts,
                    languages: candidate.languages,
                    speakers: candidate.cueLineID.flatMap {
                        speakersByCueID[$0]
                    } ?? []
                )
            )
        }
    }

    private func shioriTableUnresolvedCandidate(
        from statement: SQLiteStatement,
        languageDetectionsBySubtitleFileID: inout [Int64: SearchLanguageDetections]
    ) throws -> ShioriTableUnresolvedCandidate {
        let shiori = shiori(from: statement)
        let cueLineRecord: SubtitleCueLineRecord? = if statement.nullableInt64Column(14) != nil {
            cueLineRecord(from: statement, startingAt: 14)
        } else {
            nil
        }
        let cueGroupLanguages = Self.languageValues(
            from: statement.nullableStringColumn(29)
        )
        let languages: Set<SubtitleLanguageCode>
        if let subtitleFileID = statement.nullableInt64Column(13),
           let cueLineRecord {
            let languageDetections: SearchLanguageDetections
            if let cached = languageDetectionsBySubtitleFileID[subtitleFileID] {
                languageDetections = cached
            } else {
                try Task.checkCancellation()
                let loaded = try searchLanguageDetections(
                    forSubtitleFileID: subtitleFileID
                )
                try Task.checkCancellation()
                languageDetectionsBySubtitleFileID[subtitleFileID] = loaded
                languageDetections = loaded
            }
            let languageCandidate = SearchCandidate(
                cueGroupID: cueLineRecord.cueGroupID,
                subtitleFileID: subtitleFileID,
                subtitlePath: shiori.subtitlePath,
                subtitleFormat: shiori.subtitleFormat,
                videoPath: shiori.videoPath,
                videoName: shiori.videoName,
                startMilliseconds: cueLineRecord.line.startMilliseconds,
                endMilliseconds: cueLineRecord.line.endMilliseconds,
                timeRange: shiori.timeRange,
                searchContent: cueLineRecord.line.content,
                lineCount: statement.nullableIntColumn(28) ?? 1,
                order: SearchResultOrder(
                    subtitleFileName: URL(fileURLWithPath: shiori.subtitlePath).lastPathComponent,
                    displayTitle: "",
                    folderOrder: 0,
                    fileOrder: 0
                )
            )
            languages = Self.displayLanguages(
                for: cueLineRecord.line,
                candidate: languageCandidate,
                detections: languageDetections,
                cueGroupLanguages: cueGroupLanguages
            )
        } else {
            languages = cueGroupLanguages
        }
        return ShioriTableUnresolvedCandidate(
            shiori: shiori,
            displayTitle: Self.shioriDisplayTitle(
                rawValue: statement.nullableStringColumn(12),
                subtitlePath: shiori.subtitlePath
            ),
            languages: languages,
            cueLineID: cueLineRecord?.id,
            cueGroupID: cueLineRecord?.cueGroupID
        )
    }

    private func shioriPage(
        from candidates: [ShioriTableCandidate],
        totalCount: Int
    ) -> ShioriPage {
        ShioriPage(
            shioris: candidates.map(\.shiori),
            totalCount: totalCount,
            languagesByShioriID: Dictionary(uniqueKeysWithValues: candidates.map { candidate in
                (candidate.shiori.id, candidate.languages)
            }),
            displayTitlesByShioriID: Dictionary(uniqueKeysWithValues: candidates.map { candidate in
                (candidate.shiori.id, candidate.displayTitle)
            }),
            cuePresentationsByShioriID: Dictionary(uniqueKeysWithValues: candidates.map { candidate in
                (candidate.shiori.id, candidate.cuePresentation)
            })
        )
    }

    public func shioriTags() throws -> [ShioriTag] {
        let statement = try database.prepare(
            """
            SELECT id, name, created_at
            FROM shiori_tags
            ORDER BY created_at ASC, id ASC;
            """
        )

        var tags: [ShioriTag] = []
        while try statement.step() {
            tags.append(shioriTag(from: statement))
        }
        return tags
    }

    public func shioriTag(id: Int64) throws -> ShioriTag? {
        let statement = try database.prepare(
            """
            SELECT id, name, created_at
            FROM shiori_tags
            WHERE id = ?;
            """
        )
        try statement.bind(id, at: 1)

        guard try statement.step() else {
            return nil
        }
        return shioriTag(from: statement)
    }

    public func shioriTag(named rawName: String) throws -> ShioriTag? {
        let normalizedName = try Self.validatedShioriTagName(rawName)
        return try shioriTag(normalizedName: normalizedName)
    }

    @discardableResult
    public func createShioriTag(
        named rawName: String,
        createdAt: Date = Date()
    ) throws -> ShioriTag {
        let normalizedName = try Self.validatedShioriTagName(rawName)
        let createdAtText = ISO8601DateFormatter().string(from: createdAt)
        let statement = try database.prepare(
            """
            INSERT OR IGNORE INTO shiori_tags(name, normalized_name, created_at)
            VALUES (?, ?, ?);
            """
        )
        try statement.bind(normalizedName, at: 1)
        try statement.bind(normalizedName, at: 2)
        try statement.bind(createdAtText, at: 3)
        try statement.run()

        guard let tag = try shioriTag(normalizedName: normalizedName) else {
            throw SQLiteDatabaseError.stepFailed("Shiori tag could not be saved")
        }
        return tag
    }

    public func shioriTags(forShioriID shioriID: Int64) throws -> [ShioriTag] {
        try shioriTagsByShioriID(forShioriIDs: [shioriID])[shioriID] ?? []
    }

    public func shioriTagsByShioriID(
        forShioriIDs shioriIDs: [Int64]
    ) throws -> [Int64: [ShioriTag]] {
        let uniqueIDs = Array(Set(shioriIDs)).sorted()
        guard !uniqueIDs.isEmpty else {
            return [:]
        }

        let placeholders = uniqueIDs.map { _ in "?" }.joined(separator: ", ")
        let statement = try database.prepare(
            """
            SELECT a.shiori_id, t.id, t.name, t.created_at
            FROM shiori_tag_assignments a
            JOIN shiori_tags t ON t.id = a.tag_id
            WHERE a.shiori_id IN (\(placeholders))
            ORDER BY a.shiori_id ASC, a.created_at ASC, t.id ASC;
            """
        )
        for (offset, id) in uniqueIDs.enumerated() {
            try statement.bind(id, at: Int32(offset + 1))
        }

        var tagsByShioriID = Dictionary(uniqueKeysWithValues: uniqueIDs.map { ($0, [ShioriTag]()) })
        while try statement.step() {
            let shioriID = statement.int64Column(0)
            tagsByShioriID[shioriID, default: []].append(
                ShioriTag(
                    id: statement.int64Column(1),
                    name: statement.stringColumn(2),
                    createdAt: statement.stringColumn(3)
                )
            )
        }
        return tagsByShioriID
    }

    @discardableResult
    public func assignShioriTag(
        named rawName: String,
        toShioriID shioriID: Int64,
        createdAt: Date = Date()
    ) throws -> ShioriTag {
        guard try shiori(id: shioriID) != nil else {
            throw SQLiteDatabaseError.stepFailed("Shiori tag assignment target does not exist")
        }

        let tag = try createShioriTag(named: rawName, createdAt: createdAt)
        try assignShioriTag(tagID: tag.id, toShioriID: shioriID, createdAt: createdAt)
        return tag
    }

    @discardableResult
    public func assignShioriTag(
        tagID: Int64,
        toShioriID shioriID: Int64,
        createdAt: Date = Date()
    ) throws -> Bool {
        guard try shiori(id: shioriID) != nil else {
            return false
        }
        guard try shioriTag(id: tagID) != nil else {
            return false
        }
        guard try !shioriTagAssignmentExists(tagID: tagID, shioriID: shioriID) else {
            return false
        }

        let statement = try database.prepare(
            """
            INSERT INTO shiori_tag_assignments(shiori_id, tag_id, created_at)
            VALUES (?, ?, ?);
            """
        )
        try statement.bind(shioriID, at: 1)
        try statement.bind(tagID, at: 2)
        try statement.bind(ISO8601DateFormatter().string(from: createdAt), at: 3)
        try statement.run()
        return true
    }

    @discardableResult
    public func removeShioriTagAssignment(
        tagID: Int64,
        fromShioriID shioriID: Int64
    ) throws -> Bool {
        guard try shioriTagAssignmentExists(tagID: tagID, shioriID: shioriID) else {
            return false
        }

        let statement = try database.prepare(
            """
            DELETE FROM shiori_tag_assignments
            WHERE shiori_id = ?
              AND tag_id = ?;
            """
        )
        try statement.bind(shioriID, at: 1)
        try statement.bind(tagID, at: 2)
        try statement.run()
        return true
    }

    public func deleteShioriTag(tagID: Int64) throws -> ShioriTagDeletionResult {
        guard try shioriTag(id: tagID) != nil else {
            return ShioriTagDeletionResult(tagID: tagID, didDelete: false, affectedShioriIDs: [])
        }

        let affectedIDs = try shioriIDsAssignedToTag(tagID: tagID)
        let statement = try database.prepare(
            """
            DELETE FROM shiori_tags
            WHERE id = ?;
            """
        )
        try statement.bind(tagID, at: 1)
        try statement.run()
        return ShioriTagDeletionResult(
            tagID: tagID,
            didDelete: true,
            affectedShioriIDs: affectedIDs
        )
    }

    private static func shioriDisplayTitle(rawValue: String?, subtitlePath: String) -> String {
        let trimmedTitle = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmedTitle.isEmpty {
            return trimmedTitle
        }
        return URL(fileURLWithPath: subtitlePath).lastPathComponent
    }

    private static func shioriMatchesSearchText(
        _ searchText: String,
        displayTitle: String,
        cues: String
    ) -> Bool {
        guard !searchText.isEmpty else {
            return true
        }
        return displayTitle.range(of: searchText, options: [.caseInsensitive, .diacriticInsensitive]) != nil
            || cues.range(of: searchText, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }

    @discardableResult
    public func removeShiori(id: Int64) throws -> Bool {
        guard try shiori(id: id) != nil else {
            return false
        }

        let statement = try database.prepare(
            """
            DELETE FROM shioris
            WHERE id = ?;
            """
        )
        try statement.bind(id, at: 1)
        try statement.run()
        return true
    }

    public func removeStaleEntries(under folder: URL, keeping subtitleFiles: Set<String>) throws {
        try removeIndexedData(
            under: folder,
            keeping: subtitleFiles,
            removeSearchPath: false,
            rebuildSearchDerivedIndex: true
        )
    }

    public func removeIndexedFolder(_ folder: URL) throws {
        try removeIndexedData(
            under: folder,
            keeping: [],
            removeSearchPath: true,
            rebuildSearchDerivedIndex: false
        )
    }

    private struct SearchCandidate {
        let cueGroupID: Int64
        let subtitleFileID: Int64
        let subtitlePath: String
        let subtitleFormat: SubtitleFormat
        let videoPath: String
        let videoName: String
        let startMilliseconds: Int
        let endMilliseconds: Int
        let timeRange: String
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

    private struct SearchResultMatch {
        let cueLineRecord: SubtitleCueLineRecord
        let primaryGroupIndex: Int
        let cueGroupLines: [String]
        let displayLanguages: Set<SubtitleLanguageCode>
        let displaySpeakers: Set<String>
    }

    private struct AllCuePageCandidate {
        let candidate: SearchCandidate
        let cueLineRecord: SubtitleCueLineRecord
        let displayLanguages: Set<SubtitleLanguageCode>
        let displaySpeakers: Set<String>
    }

    private struct ShioriTableCandidate {
        let shiori: Shiori
        let displayTitle: String
        let languages: Set<SubtitleLanguageCode>
        let cuePresentation: ShioriCuePresentation
    }

    private struct ShioriTableUnresolvedCandidate {
        let shiori: Shiori
        let displayTitle: String
        let languages: Set<SubtitleLanguageCode>
        let cueLineID: Int64?
        let cueGroupID: Int64?
    }

    private struct SearchLanguageDetections {
        let fileLanguages: Set<SubtitleLanguageCode>?
        let styleLanguagesByName: [String: Set<SubtitleLanguageCode>]

        var hasAnyDetection: Bool {
            fileLanguages != nil || !styleLanguagesByName.isEmpty
        }
    }

    private struct SearchFileSummaryAccumulator {
        private var countsByPath: [String: Int] = [:]
        private var pathsInOrder: [String] = []
        private var fileNamesByPath: [String: String] = [:]
        private var displayTitlesByPath: [String: String] = [:]

        mutating func add(_ orderedResult: OrderedSearchResult) {
            let result = orderedResult.result
            add(
                subtitlePath: result.subtitlePath,
                order: orderedResult.order
            )
        }

        mutating func add(candidate: SearchCandidate) {
            add(
                subtitlePath: candidate.subtitlePath,
                order: candidate.order
            )
        }

        private mutating func add(
            subtitlePath: String,
            order: SearchResultOrder
        ) {
            if countsByPath[subtitlePath] == nil {
                pathsInOrder.append(subtitlePath)
            }
            countsByPath[subtitlePath, default: 0] += 1
            fileNamesByPath[subtitlePath] = order.subtitleFileName
            displayTitlesByPath[subtitlePath] = order.displayTitle
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
        let subtitleFileID: Int64
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

    private struct PlaybackFinishCueGroup {
        let startMilliseconds: Int
        let endMilliseconds: Int
        let styles: Set<String>

        func overlapMilliseconds(with other: PlaybackFinishCueGroup) -> Int {
            min(endMilliseconds, other.endMilliseconds) - max(startMilliseconds, other.startMilliseconds)
        }
    }

    private struct PlaybackFinishCueGroupKey: Hashable {
        let startMilliseconds: Int
        let endMilliseconds: Int
    }

    private struct CueLineStableKey: Hashable {
        let sourceFormat: SubtitleFormat
        let sourceStyle: String?
        let sourceLayer: Int?
        let startTimecode: String
        let endTimecode: String
        let startMilliseconds: Int
        let endMilliseconds: Int
        let content: String
        let displayX: Double?
        let displayY: Double?

        init(line: SubtitleCueLine) {
            sourceFormat = line.sourceFormat
            sourceStyle = line.sourceStyle
            sourceLayer = line.sourceLayer
            startTimecode = line.startTimecode
            endTimecode = line.endTimecode
            startMilliseconds = line.startMilliseconds
            endMilliseconds = line.endMilliseconds
            content = line.content
            displayX = line.displayX
            displayY = line.displayY
        }

        init(statement: SQLiteStatement) {
            sourceFormat = SubtitleFormat(rawValue: statement.stringColumn(0)) ?? .srt
            sourceStyle = statement.nullableStringColumn(1)
            sourceLayer = statement.nullableIntColumn(2)
            startTimecode = statement.stringColumn(3)
            endTimecode = statement.stringColumn(4)
            startMilliseconds = statement.intColumn(5)
            endMilliseconds = statement.intColumn(6)
            content = statement.stringColumn(7)
            displayX = statement.nullableDoubleColumn(8)
            displayY = statement.nullableDoubleColumn(9)
        }
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

    private static func languageCodesForSearchFilter(
        _ languageFilter: SubtitleSearchLanguageFilter
    ) -> [SubtitleLanguageCode] {
        guard languageFilter != .all else {
            return []
        }

        var codes = languageFilter.matchingLanguageCodes
        codes.insert(.unknown)
        return codes.sorted { $0.rawValue < $1.rawValue }
    }

    private static func diagnosticNow() -> UInt64 {
        DispatchTime.now().uptimeNanoseconds
    }

    private static func diagnosticMilliseconds(between start: UInt64, and end: UInt64) -> Double {
        Double(end - start) / 1_000_000
    }

    private static func playbackFinishMetadata(
        format: SubtitleFormat,
        cueGroups: [SubtitleCueGroup]
    ) -> SubtitlePlaybackFinishMetadata {
        var stylesByTimeRange: [PlaybackFinishCueGroupKey: Set<String>] = [:]
        for group in cueGroups {
            let key = PlaybackFinishCueGroupKey(
                startMilliseconds: group.startMilliseconds,
                endMilliseconds: group.endMilliseconds
            )
            stylesByTimeRange[key, default: []].formUnion(
                group.cueLines.compactMap { line in
                    let style = line.sourceStyle?.trimmingCharacters(in: .whitespacesAndNewlines)
                    return style?.isEmpty == true ? nil : style
                }
            )
        }

        let groupedCues = stylesByTimeRange.map { key, styles in
            PlaybackFinishCueGroup(
                startMilliseconds: key.startMilliseconds,
                endMilliseconds: key.endMilliseconds,
                styles: styles
            )
        }

        let lastSubtitleEndMilliseconds = groupedCues.map(\.endMilliseconds).max()
        guard format == .ass else {
            return SubtitlePlaybackFinishMetadata(
                primaryStyles: [],
                primaryStyleLastEndMilliseconds: nil,
                lastSubtitleEndMilliseconds: lastSubtitleEndMilliseconds
            )
        }

        var styleCounts: [String: Int] = [:]
        for (index, group) in groupedCues.enumerated() {
            let hasOverlap = groupedCues.indices.contains { otherIndex in
                guard otherIndex != index else {
                    return false
                }

                return group.overlapMilliseconds(with: groupedCues[otherIndex]) >= 1
            }

            guard !hasOverlap else {
                continue
            }

            for style in group.styles {
                styleCounts[style, default: 0] += 1
            }
        }

        guard let primaryStyleCount = styleCounts.values.max(),
              primaryStyleCount > 0
        else {
            return SubtitlePlaybackFinishMetadata(
                primaryStyles: [],
                primaryStyleLastEndMilliseconds: nil,
                lastSubtitleEndMilliseconds: lastSubtitleEndMilliseconds
            )
        }

        let primaryStyles = styleCounts
            .filter { $0.value == primaryStyleCount }
            .map(\.key)
            .sorted()
        let primaryStyleSet = Set(primaryStyles)
        let primaryStyleLastEndMilliseconds = groupedCues
            .filter { !$0.styles.isDisjoint(with: primaryStyleSet) }
            .map(\.endMilliseconds)
            .max()

        return SubtitlePlaybackFinishMetadata(
            primaryStyles: primaryStyles,
            primaryStyleLastEndMilliseconds: primaryStyleLastEndMilliseconds,
            lastSubtitleEndMilliseconds: lastSubtitleEndMilliseconds
        )
    }

    private static func encodePrimaryStyles(_ primaryStyles: [String]) throws -> String {
        let data = try JSONEncoder().encode(primaryStyles)
        guard let json = String(data: data, encoding: .utf8) else {
            throw SQLiteDatabaseError.stepFailed("Primary style metadata could not be encoded.")
        }
        return json
    }

    private static func decodePrimaryStyles(from json: String) throws -> [String] {
        guard let data = json.data(using: .utf8) else {
            throw SQLiteDatabaseError.stepFailed("Primary style metadata could not be decoded.")
        }
        return try JSONDecoder().decode([String].self, from: data)
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

    private func searchResults(
        for candidate: SearchCandidate,
        cueLineRecords: [SubtitleCueLineRecord],
        matching plan: SearchQueryPlan,
        languageFilterCodes: Set<SubtitleLanguageCode>,
        languageDetections: SearchLanguageDetections?,
        cueGroupLanguages: Set<SubtitleLanguageCode>,
        speakersByCueID: [Int64: Set<String>],
        filterSet: SubtitleSearchFilterSet
    ) -> [OrderedSearchResult] {
        searchMatches(
            for: candidate,
            cueLineRecords: cueLineRecords,
            matching: plan,
            languageFilterCodes: languageFilterCodes,
            languageDetections: languageDetections,
            cueGroupLanguages: cueGroupLanguages,
            speakersByCueID: speakersByCueID,
            filterSet: filterSet
        ).map { orderedSearchResult(for: candidate, match: $0) }
    }

    private func searchMatches(
        for candidate: SearchCandidate,
        cueLineRecords: [SubtitleCueLineRecord],
        matching plan: SearchQueryPlan,
        languageFilterCodes: Set<SubtitleLanguageCode>,
        languageDetections: SearchLanguageDetections?,
        cueGroupLanguages: Set<SubtitleLanguageCode>,
        speakersByCueID: [Int64: Set<String>],
        filterSet: SubtitleSearchFilterSet
    ) -> [SearchResultMatch] {
        let lines = cueLineRecords.map(\.line)
        let cueGroupLines = lines.map(\.content)
        var matches: [SearchResultMatch] = []
        matches.reserveCapacity(cueLineRecords.count)

        for (index, record) in cueLineRecords.enumerated() {
            guard Self.line(record.line.content, matches: plan.lineMatchRule) else {
                continue
            }

            let displayLanguages = Self.displayLanguages(
                for: record.line,
                candidate: candidate,
                detections: languageDetections,
                cueGroupLanguages: cueGroupLanguages
            )
            guard languageFilterCodes.isEmpty
                    || !displayLanguages.isDisjoint(with: languageFilterCodes)
            else {
                continue
            }

            let displaySpeakers = speakersByCueID[record.id] ?? []
            if !filterSet.isEffectivelyEmpty,
               !filterSet.matches(
                   display: candidate.order.displayTitle,
                   cues: record.line.content,
                   languages: Self.filterSetLanguageValues(displayLanguages),
                   speakers: Self.filterSetSpeakerValues(displaySpeakers)
               ) {
                continue
            }

            matches.append(
                SearchResultMatch(
                    cueLineRecord: record,
                    primaryGroupIndex: index,
                    cueGroupLines: cueGroupLines,
                    displayLanguages: displayLanguages,
                    displaySpeakers: displaySpeakers
                )
            )
        }
        return matches
    }

    private func orderedSearchResult(
        for candidate: SearchCandidate,
        match: SearchResultMatch
    ) -> OrderedSearchResult {
        let cue = match.cueLineRecord
        return OrderedSearchResult(
            result: SubtitleSearchResult(
                entryID: cue.id,
                cueGroupID: candidate.cueGroupID,
                cueEventIndex: cue.line.eventIndex,
                cueDisplayOrder: cue.line.displayOrder,
                primaryGroupIndex: match.primaryGroupIndex,
                subtitlePath: candidate.subtitlePath,
                subtitleFormat: candidate.subtitleFormat,
                videoPath: candidate.videoPath,
                videoName: candidate.videoName,
                displayTitle: candidate.order.displayTitle,
                startMilliseconds: cue.line.startMilliseconds,
                endMilliseconds: cue.line.endMilliseconds,
                content: cue.line.content,
                cueLines: [cue.line.content],
                cueGroupLines: match.cueGroupLines,
                languages: match.displayLanguages,
                speakers: match.displaySpeakers
            ),
            order: candidate.order
        )
    }

    private static func filterSetLanguageValues(_ languages: Set<SubtitleLanguageCode>) -> [String] {
        let resolvedLanguages = languages.isEmpty ? Set([SubtitleLanguageCode.unknown]) : languages
        return resolvedLanguages
            .map(\.rawValue)
            .sorted()
    }

    private static func filterSetSpeakerValues(_ speakers: Set<String>) -> [String] {
        speakers
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .sorted()
    }

    private static func languageValues(from rawValue: String?) -> Set<SubtitleLanguageCode> {
        guard let rawValue, !rawValue.isEmpty else {
            return [.unknown]
        }

        let values = rawValue
            .split(separator: ",")
            .compactMap { SubtitleLanguageCode(rawValue: String($0)) }
        return values.isEmpty ? [.unknown] : Set(values)
    }

    private static func speakerValues(from rawValue: String?) -> Set<String> {
        guard let rawValue, !rawValue.isEmpty else {
            return []
        }

        return Set(
            rawValue
                .split(separator: "\u{1f}")
                .map(String.init)
                .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        )
    }

    private static func speakerHexValues(from rawValue: String?) -> Set<String> {
        guard let rawValue, !rawValue.isEmpty else {
            return []
        }

        return Set(rawValue.split(separator: ",").compactMap { encodedSpeaker in
            guard encodedSpeaker.count.isMultiple(of: 2) else {
                return nil
            }
            var bytes: [UInt8] = []
            bytes.reserveCapacity(encodedSpeaker.count / 2)
            var index = encodedSpeaker.startIndex
            while index < encodedSpeaker.endIndex {
                let nextIndex = encodedSpeaker.index(index, offsetBy: 2)
                guard let byte = UInt8(encodedSpeaker[index..<nextIndex], radix: 16) else {
                    return nil
                }
                bytes.append(byte)
                index = nextIndex
            }
            return String(bytes: bytes, encoding: .utf8)
        })
    }

    private static func languagesForMatchingLine(
        at index: Int,
        candidate: SearchCandidate,
        lines: [SubtitleCueLine],
        detections: SearchLanguageDetections
    ) -> Set<SubtitleLanguageCode> {
        guard index < lines.count else {
            return fallbackLanguagesForMatchingLine(candidate: candidate, detections: detections)
        }

        let line = lines[index]
        switch line.sourceFormat {
        case .srt:
            return detections.fileLanguages ?? [.unknown]
        case .ass:
            guard let styleName = SubtitleLanguageAnalyzer.canonicalASSStyleName(line.sourceStyle) else {
                return SubtitleLanguageAnalyzer.languageSegments(from: line.content).isEmpty ? [] : [.unknown]
            }
            return detections.styleLanguagesByName[styleName] ?? [.unknown]
        }
    }

    private static func displayLanguages(
        for cueLine: SubtitleCueLine,
        candidate: SearchCandidate,
        detections: SearchLanguageDetections?,
        cueGroupLanguages: Set<SubtitleLanguageCode>
    ) -> Set<SubtitleLanguageCode> {
        if let detections, detections.hasAnyDetection {
            return languagesForMatchingLine(
                at: 0,
                candidate: candidate,
                lines: [cueLine],
                detections: detections
            )
        }

        if candidate.subtitleFormat == .ass, candidate.lineCount > 1 {
            return SubtitleLanguageRecognizer(minimumEffectiveCharacterCount: 4)
                .detectLanguages(
                    in: SubtitleLanguageAnalyzer.languageSegments(from: cueLine.content)
                )
                .languages
        }

        return cueGroupLanguages.isEmpty ? [.unknown] : cueGroupLanguages
    }

    private static func fallbackLanguagesForMatchingLine(
        candidate: SearchCandidate,
        detections: SearchLanguageDetections
    ) -> Set<SubtitleLanguageCode> {
        switch candidate.subtitleFormat {
        case .srt:
            return detections.fileLanguages ?? [.unknown]
        case .ass:
            return [.unknown]
        }
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

    private static func searchNavigationIndex(
        in cueIDs: [Int64],
        anchor: SearchNavigationAnchor
    ) -> Int? {
        if let selectedEntryID = anchor.selectedEntryID,
           let selectedSearchRank = anchor.selectedSearchRank,
           cueIDs.indices.contains(selectedSearchRank),
           cueIDs[selectedSearchRank] == selectedEntryID {
            return selectedSearchRank
        }

        if anchor.selectedEntryID == nil,
           let selectedSearchRank = anchor.selectedSearchRank,
           cueIDs.indices.contains(selectedSearchRank) {
            return selectedSearchRank
        }

        if let selectedEntryID = anchor.selectedEntryID,
           let selectedIndex = cueIDs.firstIndex(of: selectedEntryID) {
            return selectedIndex
        }

        return nil
    }

    private static func searchNavigationIndex(
        of cueID: Int64,
        in cueIDs: [Int64],
        preferredSearchRank: Int?
    ) -> Int? {
        if let preferredSearchRank,
           cueIDs.indices.contains(preferredSearchRank),
           cueIDs[preferredSearchRank] == cueID {
            return preferredSearchRank
        }

        if let preferredSearchRank,
           cueIDs.indices.contains(preferredSearchRank) {
            var lowerIndex = preferredSearchRank - 1
            var upperIndex = preferredSearchRank + 1
            while lowerIndex >= 0 || upperIndex < cueIDs.count {
                if upperIndex < cueIDs.count {
                    if cueIDs[upperIndex] == cueID {
                        return upperIndex
                    }
                    upperIndex += 1
                }

                if lowerIndex >= 0 {
                    if cueIDs[lowerIndex] == cueID {
                        return lowerIndex
                    }
                    lowerIndex -= 1
                }
            }
        }

        return cueIDs.firstIndex(of: cueID)
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

    private static func searchQueryPlan(for query: String) -> SearchQueryPlan? {
        let trimmed = normalizeSearchSpaces(query)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
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
        let normalizedLine = normalizeSearchSpaces(line)
        return switch rule {
        case .latinPrefix(let token):
            tokenizeLatinTokens(normalizedLine).contains { $0.hasPrefix(token) }
        case .orderedLatinTokens(let tokens):
            matchesOrderedWholeTokens(normalizedLine, queryTokens: tokens)
        case .cjkSubstring(let query):
            normalizedLine.contains(query)
        case .explicitFTS(let query):
            matchesExplicitFTSLineFallback(normalizedLine, query: query)
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

    private static func normalizeSearchSpaces(_ text: String) -> String {
        text.replacingOccurrences(of: "\u{3000}", with: " ")
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

    private static func isASCIIWordCharacter(_ character: Character) -> Bool {
        isASCIILetterOrDigit(character) || character == "_"
    }

    private func removeIndexedData(
        under folder: URL,
        keeping subtitleFiles: Set<String>,
        removeSearchPath: Bool,
        rebuildSearchDerivedIndex: Bool
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

            let deletePlaybackFinishMetadata = try database.prepare(
                """
                DELETE FROM subtitle_playback_finish_metadata
                WHERE subtitle_file_id IN (
                    SELECT sf.id
                    FROM subtitle_files sf
                    WHERE (\(prefixCondition)) \(keepCondition)
                );
                """
            )
            try bindStaleEntryParameters(
                statement: deletePlaybackFinishMetadata,
                folderPathPrefixes: folderPathPrefixes,
                subtitleFiles: subtitleFiles
            )
            try deletePlaybackFinishMetadata.run()

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
                WHERE subtitle_file_id IN (
                    SELECT sf.id
                    FROM subtitle_files sf
                    WHERE (\(prefixCondition)) \(keepCondition)
                );
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
                WHERE subtitle_file_id IN (
                    SELECT sf.id
                    FROM subtitle_files sf
                    WHERE (\(prefixCondition)) \(keepCondition)
                );
                """
            )
            try bindStaleEntryParameters(
                statement: deleteSearchOrderRows,
                folderPathPrefixes: folderPathPrefixes,
                subtitleFiles: subtitleFiles
            )
            try deleteSearchOrderRows.run()

            let deleteCueLines = try database.prepare(
                """
                DELETE FROM subtitle_cue_lines
                WHERE subtitle_file_id IN (
                    SELECT sf.id
                    FROM subtitle_files sf
                    WHERE (\(prefixCondition)) \(keepCondition)
                );
                """
            )
            try bindStaleEntryParameters(
                statement: deleteCueLines,
                folderPathPrefixes: folderPathPrefixes,
                subtitleFiles: subtitleFiles
            )
            try deleteCueLines.run()

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

            try deleteOrphanedVideoFiles()

            if removeSearchPath {
                for searchPath in Self.folderPathVariants(for: folder) {
                    try deleteSearchPath(searchPath)
                }
            }

            if rebuildSearchDerivedIndex {
                try rebuildSearchDerivedIndexInCurrentTransaction()
            }
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
        modifiedAt: Date?,
        libraryID: Int64? = nil
    ) throws -> Int64 {
        let pathIdentity = try mediaPathIdentity(for: subtitleFile, preferredLibraryID: libraryID)
        let statement = try database.prepare(
            """
            INSERT INTO subtitle_files(
                library_id,
                relative_path,
                subtitle_path,
                format,
                file_size,
                modified_at,
                indexed_at,
                index_algorithm_version
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(subtitle_path) DO UPDATE SET
                library_id = excluded.library_id,
                relative_path = excluded.relative_path,
                format = excluded.format,
                file_size = excluded.file_size,
                modified_at = excluded.modified_at,
                indexed_at = excluded.indexed_at,
                index_algorithm_version = excluded.index_algorithm_version
            RETURNING id;
            """
        )

        if let pathIdentity {
            try statement.bind(pathIdentity.libraryID, at: 1)
            try statement.bind(pathIdentity.relativePath, at: 2)
        } else {
            try statement.bindNull(at: 1)
            try statement.bindNull(at: 2)
        }
        try statement.bind(subtitleFile.path, at: 3)
        try statement.bind(format.rawValue, at: 4)
        if let fileSize {
            try statement.bind(fileSize, at: 5)
        } else {
            try statement.bindNull(at: 5)
        }

        if let modifiedAt {
            try statement.bind(modifiedAt.timeIntervalSince1970, at: 6)
        } else {
            try statement.bindNull(at: 6)
        }

        try statement.bind(ISO8601DateFormatter().string(from: Date()), at: 7)
        try statement.bind(SubtitleCueIndexingRules.algorithmVersion, at: 8)

        guard try statement.step() else {
            return database.lastInsertRowID()
        }

        return statement.int64Column(0)
    }

    private func upsertVideoFile(_ videoFile: URL, libraryID: Int64? = nil) throws -> Int64 {
        let attributes = try? FileManager.default.attributesOfItem(atPath: videoFile.path)
        let fileSize = (attributes?[.size] as? NSNumber)?.int64Value
        let modifiedAt = attributes?[.modificationDate] as? Date
        let pathIdentity = try mediaPathIdentity(for: videoFile, preferredLibraryID: libraryID)
        let statement = try database.prepare(
            """
            INSERT INTO video_files(
                library_id, relative_path, path, video_name, file_size, modified_at
            )
            VALUES (?, ?, ?, ?, ?, ?)
            ON CONFLICT(path) DO UPDATE SET
                library_id = excluded.library_id,
                relative_path = excluded.relative_path,
                video_name = excluded.video_name,
                file_size = excluded.file_size,
                modified_at = excluded.modified_at
            RETURNING id;
            """
        )

        if let pathIdentity {
            try statement.bind(pathIdentity.libraryID, at: 1)
            try statement.bind(pathIdentity.relativePath, at: 2)
        } else {
            try statement.bindNull(at: 1)
            try statement.bindNull(at: 2)
        }
        try statement.bind(videoFile.path, at: 3)
        try statement.bind(videoFile.lastPathComponent, at: 4)
        if let fileSize {
            try statement.bind(fileSize, at: 5)
        } else {
            try statement.bindNull(at: 5)
        }

        if let modifiedAt {
            try statement.bind(modifiedAt.timeIntervalSince1970, at: 6)
        } else {
            try statement.bindNull(at: 6)
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
        guard let videoFileID = try videoFileID(for: videoFile) else {
            throw SQLiteDatabaseError.stepFailed("Video file is not indexed: \(videoFile.path)")
        }
        return videoFileID
    }

    private func videoFileID(for videoFile: URL) throws -> Int64? {
        let statement = try database.prepare(
            """
            SELECT id
            FROM video_files
            WHERE path = ?;
            """
        )
        try statement.bind(videoFile.path, at: 1)

        return try statement.step() ? statement.int64Column(0) : nil
    }

    private func cueLineSpeakersByStableKey(forSubtitlePath subtitlePath: String) throws -> [CueLineStableKey: Set<String>] {
        let statement = try database.prepare(
            """
            SELECT l.source_format, l.source_style, l.source_layer,
                   l.start_time, l.end_time, l.start_ms, l.end_ms,
                   l.content, l.display_x, l.display_y, s.speaker
            FROM subtitle_cue_line_speakers s
            JOIN subtitle_cue_lines l ON l.id = s.cue_line_id
            JOIN subtitle_cue_groups g ON g.id = l.cue_group_id
            JOIN subtitle_files sf ON sf.id = g.subtitle_file_id
            WHERE sf.subtitle_path = ?
            ORDER BY l.id ASC, s.speaker_key ASC;
            """
        )
        try statement.bind(subtitlePath, at: 1)

        var speakersByKey: [CueLineStableKey: Set<String>] = [:]
        while try statement.step() {
            let key = CueLineStableKey(statement: statement)
            speakersByKey[key, default: []].insert(statement.stringColumn(10))
        }
        return speakersByKey
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
                time_range,
                search_content,
                line_count
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
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
        try statement.bind(
            Self.cueTimeRange(
                startMilliseconds: group.startMilliseconds,
                endMilliseconds: group.endMilliseconds
            ),
            at: 8
        )
        try statement.bind(group.searchContent, at: 9)
        try statement.bind(max(1, group.cueLines.count), at: 10)
        try statement.run()

        return database.lastInsertRowID()
    }

    private func insertPlaybackFinishMetadata(
        subtitleFileID: Int64,
        subtitleFile: URL,
        metadata: SubtitlePlaybackFinishMetadata
    ) throws {
        let statement = try database.prepare(
            """
            INSERT OR REPLACE INTO subtitle_playback_finish_metadata(
                subtitle_file_id,
                subtitle_path,
                algorithm_version,
                primary_styles_json,
                primary_style_last_end_ms,
                last_subtitle_end_ms,
                indexed_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?);
            """
        )

        try statement.bind(subtitleFileID, at: 1)
        try statement.bind(subtitleFile.path, at: 2)
        try statement.bind(SubtitleCueIndexingRules.algorithmVersion, at: 3)
        try statement.bind(try Self.encodePrimaryStyles(metadata.primaryStyles), at: 4)
        if let primaryStyleLastEndMilliseconds = metadata.primaryStyleLastEndMilliseconds {
            try statement.bind(primaryStyleLastEndMilliseconds, at: 5)
        } else {
            try statement.bindNull(at: 5)
        }
        if let lastSubtitleEndMilliseconds = metadata.lastSubtitleEndMilliseconds {
            try statement.bind(lastSubtitleEndMilliseconds, at: 6)
        } else {
            try statement.bindNull(at: 6)
        }
        try statement.bind(ISO8601DateFormatter().string(from: Date()), at: 7)
        try statement.run()
    }

    private func insertCueLine(
        subtitleFileID: Int64,
        cueGroupID: Int64,
        line: SubtitleCueLine
    ) throws -> Int64 {
        let statement = try database.prepare(
            """
            INSERT INTO subtitle_cue_lines(
                subtitle_file_id,
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
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
            """
        )

        try statement.bind(subtitleFileID, at: 1)
        try statement.bind(cueGroupID, at: 2)
        try statement.bind(line.eventIndex, at: 3)
        try statement.bind(line.sourceFormat.rawValue, at: 4)
        if let sourceStyle = line.sourceStyle {
            try statement.bind(sourceStyle, at: 5)
        } else {
            try statement.bindNull(at: 5)
        }
        if let sourceLayer = line.sourceLayer {
            try statement.bind(sourceLayer, at: 6)
        } else {
            try statement.bindNull(at: 6)
        }
        try statement.bind(line.startTimecode, at: 7)
        try statement.bind(line.endTimecode, at: 8)
        try statement.bind(line.startMilliseconds, at: 9)
        try statement.bind(line.endMilliseconds, at: 10)
        try statement.bind(line.content, at: 11)
        if let displayX = line.displayX {
            try statement.bind(displayX, at: 12)
        } else {
            try statement.bindNull(at: 12)
        }
        if let displayY = line.displayY {
            try statement.bind(displayY, at: 13)
        } else {
            try statement.bindNull(at: 13)
        }
        try statement.bind(line.displayOrder, at: 14)
        try statement.run()
        return database.lastInsertRowID()
    }

    private func cueGroupIDsByCueLineID(forSubtitleFile subtitleFile: URL) throws -> [Int64: Int64] {
        let statement = try database.prepare(
            """
            SELECT l.id, l.cue_group_id
            FROM subtitle_cue_lines l
            JOIN subtitle_cue_groups g ON g.id = l.cue_group_id
            JOIN subtitle_files sf ON sf.id = g.subtitle_file_id
            WHERE sf.subtitle_path = ?;
            """
        )

        try statement.bind(subtitleFile.path, at: 1)

        var cueGroupIDsByLineID: [Int64: Int64] = [:]
        while try statement.step() {
            cueGroupIDsByLineID[statement.int64Column(0)] = statement.int64Column(1)
        }
        return cueGroupIDsByLineID
    }

    private func clearCueLineSpeakersInCurrentTransaction(forSubtitleFile subtitleFile: URL) throws {
        let statement = try database.prepare(
            """
            DELETE FROM subtitle_cue_line_speakers
            WHERE cue_line_id IN (
                SELECT l.id
                FROM subtitle_cue_lines l
                JOIN subtitle_cue_groups g ON g.id = l.cue_group_id
                JOIN subtitle_files sf ON sf.id = g.subtitle_file_id
                WHERE sf.subtitle_path = ?
            );
            """
        )
        try statement.bind(subtitleFile.path, at: 1)
        try statement.run()
    }

    private func insertCueLineSpeakers(
        cueLineID: Int64,
        cueGroupID: Int64,
        speakers: Set<String>
    ) throws {
        let normalizedSpeakers = Self.normalizedSpeakerValues(speakers)
        guard !normalizedSpeakers.isEmpty else {
            return
        }

        let statement = try database.prepare(
            """
            INSERT OR REPLACE INTO subtitle_cue_line_speakers(
                cue_line_id,
                cue_group_id,
                speaker,
                speaker_key
            )
            VALUES (?, ?, ?, ?);
            """
        )

        for speaker in normalizedSpeakers {
            try statement.reset()
            try statement.clearBindings()
            try statement.bind(cueLineID, at: 1)
            try statement.bind(cueGroupID, at: 2)
            try statement.bind(speaker, at: 3)
            try statement.bind(Self.speakerKey(for: speaker), at: 4)
            try statement.run()
        }
    }

    private static func normalizedSpeakerValues(_ speakers: Set<String>) -> [String] {
        speakers
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .sorted()
    }

    private static func speakerKey(for speaker: String) -> String {
        speaker.trimmingCharacters(in: .whitespacesAndNewlines)
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

    private func subtitleFocusPreviousCueLineID(
        forSubtitleFile subtitleFile: URL,
        beforeOrAtMilliseconds milliseconds: Int
    ) throws -> Int64? {
        let statement = try database.prepare(
            """
            SELECT l.id
            FROM subtitle_cue_lines l
            JOIN subtitle_cue_groups g ON g.id = l.cue_group_id
            JOIN subtitle_files sf ON sf.id = g.subtitle_file_id
            WHERE sf.subtitle_path = ?
              AND g.start_ms <= ?
              AND g.end_ms > g.start_ms
            ORDER BY g.start_ms DESC, g.end_ms DESC, g.id DESC,
                     l.display_order DESC, l.event_index DESC, l.id DESC
            LIMIT 1;
            """
        )

        try statement.bind(subtitleFile.path, at: 1)
        try statement.bind(milliseconds, at: 2)

        guard try statement.step() else {
            return nil
        }

        return statement.int64Column(0)
    }

    private func subtitleFocusFirstCueLineID(
        forSubtitleFile subtitleFile: URL
    ) throws -> Int64? {
        let statement = try database.prepare(
            """
            SELECT l.id
            FROM subtitle_cue_lines l
            JOIN subtitle_cue_groups g ON g.id = l.cue_group_id
            JOIN subtitle_files sf ON sf.id = g.subtitle_file_id
            WHERE sf.subtitle_path = ?
              AND g.end_ms > g.start_ms
            ORDER BY g.start_ms ASC, g.end_ms ASC, g.id ASC,
                     l.display_order ASC, l.event_index ASC, l.id ASC
            LIMIT 1;
            """
        )
        try statement.bind(subtitleFile.path, at: 1)

        guard try statement.step() else {
            return nil
        }
        return statement.int64Column(0)
    }

    private func subtitleFocusOrdinalMetadata(
        forSubtitleFile subtitleFile: URL,
        cueLineID: Int64
    ) throws -> (ordinal: Int, totalCount: Int)? {
        let statement = try database.prepare(
            """
            SELECT ordinal, total_count
            FROM (
                SELECT l.id AS cue_line_id,
                       ROW_NUMBER() OVER (
                           ORDER BY g.start_ms ASC, g.end_ms ASC, g.id ASC,
                                    l.display_order ASC, l.event_index ASC, l.id ASC
                       ) - 1 AS ordinal,
                       COUNT(*) OVER () AS total_count
                FROM subtitle_cue_lines l
                JOIN subtitle_cue_groups g ON g.id = l.cue_group_id
                JOIN subtitle_files sf ON sf.id = g.subtitle_file_id
                WHERE sf.subtitle_path = ?
                  AND g.end_ms > g.start_ms
            ) ordered
            WHERE cue_line_id = ?;
            """
        )
        try statement.bind(subtitleFile.path, at: 1)
        try statement.bind(cueLineID, at: 2)

        guard try statement.step() else {
            return nil
        }
        return (
            ordinal: statement.intColumn(0),
            totalCount: statement.intColumn(1)
        )
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
            JOIN subtitle_search_order_rows sor ON sor.subtitle_file_id = sf.id
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

    private func cueLineRecords(
        forCueGroupIDs cueGroupIDs: [Int64]
    ) throws -> [Int64: [SubtitleCueLineRecord]] {
        guard !cueGroupIDs.isEmpty else {
            return [:]
        }

        let placeholders = cueGroupIDs.map { _ in "?" }.joined(separator: ", ")
        let statement = try database.prepare(
            """
            SELECT l.id, l.cue_group_id, l.event_index, l.source_format,
                   l.source_style, l.source_layer, l.start_time, l.end_time,
                   l.start_ms, l.end_ms, l.content, l.display_x, l.display_y,
                   l.display_order
            FROM subtitle_cue_lines l
            WHERE l.cue_group_id IN (\(placeholders))
            ORDER BY l.cue_group_id ASC, l.display_order ASC, l.event_index ASC, l.id ASC;
            """
        )
        for (offset, cueGroupID) in cueGroupIDs.enumerated() {
            try statement.bind(cueGroupID, at: Int32(offset + 1))
        }

        var recordsByCueGroupID: [Int64: [SubtitleCueLineRecord]] = [:]
        recordsByCueGroupID.reserveCapacity(cueGroupIDs.count)
        while try statement.step() {
            let record = cueLineRecord(from: statement)
            recordsByCueGroupID[record.cueGroupID, default: []].append(record)
        }
        return recordsByCueGroupID
    }

    private func cueLineRecords(
        forCueIDs cueIDs: [Int64]
    ) throws -> [Int64: SubtitleCueLineRecord] {
        guard !cueIDs.isEmpty else {
            return [:]
        }

        let placeholders = cueIDs.map { _ in "?" }.joined(separator: ", ")
        let statement = try database.prepare(
            """
            SELECT l.id, l.cue_group_id, l.event_index, l.source_format,
                   l.source_style, l.source_layer, l.start_time, l.end_time,
                   l.start_ms, l.end_ms, l.content, l.display_x, l.display_y,
                   l.display_order
            FROM subtitle_cue_lines l
            WHERE l.id IN (\(placeholders));
            """
        )
        for (offset, cueID) in cueIDs.enumerated() {
            try statement.bind(cueID, at: Int32(offset + 1))
        }

        var recordsByCueID: [Int64: SubtitleCueLineRecord] = [:]
        recordsByCueID.reserveCapacity(cueIDs.count)
        while try statement.step() {
            let record = cueLineRecord(from: statement)
            recordsByCueID[record.id] = record
        }
        return recordsByCueID
    }

    private func cueLineSpeakers(
        forCueIDs cueIDs: [Int64]
    ) throws -> [Int64: Set<String>] {
        guard !cueIDs.isEmpty else {
            return [:]
        }

        let placeholders = cueIDs.map { _ in "?" }.joined(separator: ", ")
        let statement = try database.prepare(
            """
            SELECT cue_line_id, speaker
            FROM subtitle_cue_line_speakers
            WHERE cue_line_id IN (\(placeholders))
            ORDER BY cue_line_id ASC, speaker_key ASC;
            """
        )
        for (offset, cueID) in cueIDs.enumerated() {
            try statement.bind(cueID, at: Int32(offset + 1))
        }

        var speakersByCueID: [Int64: Set<String>] = [:]
        while try statement.step() {
            speakersByCueID[statement.int64Column(0), default: []].insert(
                statement.stringColumn(1)
            )
        }
        return speakersByCueID
    }

    private func searchCandidates(forCueGroupIDs cueGroupIDs: [Int64]) throws -> [Int64: SearchCandidate] {
        guard !cueGroupIDs.isEmpty else {
            return [:]
        }

        let placeholders = cueGroupIDs.map { _ in "?" }.joined(separator: ", ")
        let statement = try database.prepare(
            """
            SELECT g.id, sf.id, sf.subtitle_path, sf.format, vf.path, vf.video_name,
                   g.start_ms, g.end_ms, g.time_range, g.search_content, g.line_count,
                   sor.subtitle_file_name, sor.display_title, sor.folder_order, sor.file_order
            FROM subtitle_cue_groups g
            JOIN subtitle_files sf ON sf.id = g.subtitle_file_id
            JOIN subtitle_video_matches m ON m.subtitle_file_id = sf.id AND m.is_active = 1
            JOIN video_files vf ON vf.id = m.video_file_id
            JOIN subtitle_search_order_rows sor ON sor.subtitle_file_id = sf.id
            WHERE g.id IN (\(placeholders));
            """
        )

        for (offset, cueGroupID) in cueGroupIDs.enumerated() {
            try statement.bind(cueGroupID, at: Int32(offset + 1))
        }

        var candidates: [Int64: SearchCandidate] = [:]
        candidates.reserveCapacity(cueGroupIDs.count)
        while try statement.step() {
            let cueGroupID = statement.int64Column(0)
            candidates[cueGroupID] = SearchCandidate(
                cueGroupID: cueGroupID,
                subtitleFileID: statement.int64Column(1),
                subtitlePath: statement.stringColumn(2),
                subtitleFormat: SubtitleFormat(rawValue: statement.stringColumn(3)) ?? .srt,
                videoPath: statement.stringColumn(4),
                videoName: statement.stringColumn(5),
                startMilliseconds: statement.intColumn(6),
                endMilliseconds: statement.intColumn(7),
                timeRange: statement.stringColumn(8),
                searchContent: statement.stringColumn(9),
                lineCount: statement.intColumn(10),
                order: SearchResultOrder(
                    subtitleFileName: statement.stringColumn(11),
                    displayTitle: statement.stringColumn(12),
                    folderOrder: statement.intColumn(13),
                    fileOrder: statement.intColumn(14)
                )
            )
        }

        return candidates
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

    private func searchLanguageDetections(
        forSubtitleFileID subtitleFileID: Int64
    ) throws -> SearchLanguageDetections {
        let statement = try database.prepare(
            """
            SELECT d.scope, d.scope_key, c.language_code
            FROM subtitle_language_detections d
            JOIN subtitle_language_detection_codes c ON c.detection_id = d.id
            WHERE d.subtitle_file_id = ?
            ORDER BY d.scope ASC, d.scope_key ASC, c.language_code ASC;
            """
        )
        try statement.bind(subtitleFileID, at: 1)

        var fileLanguages: Set<SubtitleLanguageCode>?
        var styleLanguagesByName: [String: Set<SubtitleLanguageCode>] = [:]
        while try statement.step() {
            guard let language = SubtitleLanguageCode(rawValue: statement.stringColumn(2)) else {
                continue
            }

            switch SubtitleLanguageDetectionScope(rawValue: statement.stringColumn(0)) {
            case .file:
                var languages = fileLanguages ?? Set<SubtitleLanguageCode>()
                languages.insert(language)
                fileLanguages = languages
            case .style:
                let styleName = statement.stringColumn(1)
                guard !styleName.isEmpty else {
                    continue
                }
                styleLanguagesByName[styleName, default: []].insert(language)
            case nil:
                continue
            }
        }

        return SearchLanguageDetections(
            fileLanguages: fileLanguages,
            styleLanguagesByName: styleLanguagesByName
        )
    }

    private func deleteIndexedSubtitlePath(
        _ subtitlePath: String,
        preserveFileIdentity: Bool = false
    ) throws {
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

        let deleteASSFontResources = try database.prepare(
            """
            DELETE FROM ass_font_resources
            WHERE subtitle_file_id IN (
                SELECT id
                FROM subtitle_files
                WHERE subtitle_path = ?
            );
            """
        )
        try deleteASSFontResources.bind(subtitlePath, at: 1)
        try deleteASSFontResources.run()

        let deletePlaybackFinishMetadata = try database.prepare(
            """
            DELETE FROM subtitle_playback_finish_metadata
            WHERE subtitle_file_id IN (
                SELECT id
                FROM subtitle_files
                WHERE subtitle_path = ?
            );
            """
        )
        try deletePlaybackFinishMetadata.bind(subtitlePath, at: 1)
        try deletePlaybackFinishMetadata.run()

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

        guard !preserveFileIdentity else {
            let deleteMatches = try database.prepare(
                """
                DELETE FROM subtitle_video_matches
                WHERE subtitle_file_id IN (
                    SELECT id
                    FROM subtitle_files
                    WHERE subtitle_path = ?
                );
                """
            )
            try deleteMatches.bind(subtitlePath, at: 1)
            try deleteMatches.run()

            let deleteCueGroups = try database.prepare(
                """
                DELETE FROM subtitle_cue_groups
                WHERE subtitle_file_id IN (
                    SELECT id
                    FROM subtitle_files
                    WHERE subtitle_path = ?
                );
                """
            )
            try deleteCueGroups.bind(subtitlePath, at: 1)
            try deleteCueGroups.run()
            return
        }

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
            )
              AND id NOT IN (
                  SELECT video_file_id
                  FROM library_playback_history
                  WHERE video_file_id IS NOT NULL
              )
              AND id NOT IN (
                  SELECT video_file_id
                  FROM library_watch_states
                  WHERE video_file_id IS NOT NULL
              );
            """
        )
    }

    private func dropDerivedSubtitleIndexTables() throws {
        try database.execute(
            """
            DROP TABLE IF EXISTS subtitle_cue_groups_fts;
            DROP TABLE IF EXISTS subtitle_cue_line_speakers;
            DROP TABLE IF EXISTS subtitle_cue_group_languages;
            DROP TABLE IF EXISTS subtitle_language_detection_distribution;
            DROP TABLE IF EXISTS subtitle_language_detection_codes;
            DROP TABLE IF EXISTS subtitle_language_detections;
            DROP TABLE IF EXISTS subtitle_language_manifests;
            DROP TABLE IF EXISTS subtitle_playback_finish_metadata;
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

    private static func validateDisplayCover(
        path: String?,
        profileVersion: Int?
    ) throws {
        guard (path == nil) == (profileVersion == nil) else {
            throw SQLiteDatabaseError.stepFailed(
                "Display cover path and profile version must be stored together"
            )
        }
        if let profileVersion, profileVersion <= 0 {
            throw SQLiteDatabaseError.stepFailed(
                "Display cover profile version must be positive"
            )
        }
    }

    private static func libraryCoverRevisionTimestamp() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: Date())
    }

    private static func libraryVideoCover(from statement: SQLiteStatement) -> LibraryVideoCover {
        let status = LibraryCoverStatus(rawValue: statement.stringColumn(9)) ?? .failed
        return LibraryVideoCover(
            videoFileID: statement.int64Column(0),
            masterCoverPath: statement.stringColumn(1),
            displayCoverPath: statement.nullableStringColumn(2),
            displayProfileVersion: statement.nullableIntColumn(3),
            sourceTimeMilliseconds: max(0, statement.intColumn(4)),
            score: statement.nullableDoubleColumn(5),
            algorithmVersion: statement.intColumn(6),
            generatedFileSize: statement.nullableInt64Column(7),
            generatedDuration: statement.nullableDoubleColumn(8),
            status: status,
            errorMessage: statement.nullableStringColumn(10),
            generatedAt: statement.stringColumn(11)
        )
    }

    private func cueLineRecord(
        from statement: SQLiteStatement,
        startingAt columnOffset: Int32 = 0
    ) -> SubtitleCueLineRecord {
        SubtitleCueLineRecord(
            id: statement.int64Column(columnOffset),
            cueGroupID: statement.int64Column(columnOffset + 1),
            line: SubtitleCueLine(
                eventIndex: statement.intColumn(columnOffset + 2),
                sourceFormat: SubtitleFormat(rawValue: statement.stringColumn(columnOffset + 3)) ?? .srt,
                sourceStyle: statement.nullableStringColumn(columnOffset + 4),
                sourceLayer: statement.nullableIntColumn(columnOffset + 5),
                startTimecode: statement.stringColumn(columnOffset + 6),
                endTimecode: statement.stringColumn(columnOffset + 7),
                startMilliseconds: statement.intColumn(columnOffset + 8),
                endMilliseconds: statement.intColumn(columnOffset + 9),
                content: statement.stringColumn(columnOffset + 10),
                displayX: statement.nullableDoubleColumn(columnOffset + 11),
                displayY: statement.nullableDoubleColumn(columnOffset + 12),
                displayOrder: statement.intColumn(columnOffset + 13)
            )
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

    private func shioriTag(normalizedName: String) throws -> ShioriTag? {
        let statement = try database.prepare(
            """
            SELECT id, name, created_at
            FROM shiori_tags
            WHERE normalized_name = ?;
            """
        )
        try statement.bind(normalizedName, at: 1)

        guard try statement.step() else {
            return nil
        }
        return shioriTag(from: statement)
    }

    private func shioriTagAssignmentExists(tagID: Int64, shioriID: Int64) throws -> Bool {
        let statement = try database.prepare(
            """
            SELECT 1
            FROM shiori_tag_assignments
            WHERE shiori_id = ?
              AND tag_id = ?
            LIMIT 1;
            """
        )
        try statement.bind(shioriID, at: 1)
        try statement.bind(tagID, at: 2)
        return try statement.step()
    }

    private func shioriIDsAssignedToTag(tagID: Int64) throws -> [Int64] {
        let statement = try database.prepare(
            """
            SELECT shiori_id
            FROM shiori_tag_assignments
            WHERE tag_id = ?
            ORDER BY shiori_id ASC;
            """
        )
        try statement.bind(tagID, at: 1)

        var ids: [Int64] = []
        while try statement.step() {
            ids.append(statement.int64Column(0))
        }
        return ids
    }

    private func shioriTag(from statement: SQLiteStatement) -> ShioriTag {
        ShioriTag(
            id: statement.int64Column(0),
            name: statement.stringColumn(1),
            createdAt: statement.stringColumn(2)
        )
    }

    private func shioriRelation(from statement: SQLiteStatement) -> ShioriRelation {
        ShioriRelation(
            id: statement.int64Column(0),
            listID: statement.int64Column(1),
            cueID: statement.int64Column(2),
            createdAt: statement.stringColumn(3)
        )
    }

    private func shiori(from statement: SQLiteStatement, timeRange: String? = nil) -> Shiori {
        Shiori(
            id: statement.int64Column(0),
            subtitlePath: statement.stringColumn(1),
            subtitleFormat: SubtitleFormat(rawValue: statement.stringColumn(2)) ?? .srt,
            videoPath: statement.stringColumn(3),
            videoName: statement.stringColumn(4),
            timeRange: timeRange ?? "",
            startMilliseconds: statement.intColumn(5),
            endMilliseconds: statement.intColumn(6),
            cueEventIndex: statement.nullableIntColumn(7),
            cueDisplayOrder: statement.nullableIntColumn(8),
            content: statement.stringColumn(9),
            isValid: statement.intColumn(10) != 0,
            createdAt: statement.stringColumn(11)
        )
    }

    private static func validatedShioriTagName(_ rawName: String) throws -> String {
        guard !containsInvalidShioriTagCharacter(rawName) else {
            throw ShioriTagValidationError.invalidCharacters
        }

        let trimmedName = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw ShioriTagValidationError.emptyName
        }
        guard trimmedName.count <= 20 else {
            throw ShioriTagValidationError.nameTooLong(maximumCharacters: 20)
        }
        return trimmedName
    }

    private static func containsInvalidShioriTagCharacter(_ value: String) -> Bool {
        for scalar in value.unicodeScalars {
            switch scalar.properties.generalCategory {
            case .control, .format:
                return true
            default:
                break
            }
        }
        return false
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

    private func libraryPathRecords() throws -> [LibraryPathRecord] {
        let statement = try database.prepare(
            """
            SELECT id, path
            FROM search_paths
            ORDER BY LENGTH(path) DESC, id ASC;
            """
        )

        var records: [LibraryPathRecord] = []
        while try statement.step() {
            records.append(
                LibraryPathRecord(
                    id: statement.int64Column(0),
                    rootURL: URL(fileURLWithPath: statement.stringColumn(1)).standardizedFileURL
                )
            )
        }
        return records
    }

    private func mediaPathIdentity(
        for file: URL,
        preferredLibraryID: Int64? = nil
    ) throws -> MediaPathIdentity? {
        let libraries = try libraryPathRecords()
        if let preferredLibraryID,
           let library = libraries.first(where: { $0.id == preferredLibraryID }),
           let relativePath = Self.relativeMediaPath(for: file, under: library.rootURL) {
            return MediaPathIdentity(libraryID: library.id, relativePath: relativePath)
        }

        for library in libraries {
            if let relativePath = Self.relativeMediaPath(for: file, under: library.rootURL) {
                return MediaPathIdentity(libraryID: library.id, relativePath: relativePath)
            }
        }
        return nil
    }

    private func backfillMediaPathIdentities(libraryID: Int64, rootURL: URL) throws {
        let subtitleStatement = try database.prepare(
            """
            SELECT id, subtitle_path
            FROM subtitle_files
            WHERE library_id IS NULL;
            """
        )
        var subtitleUpdates: [(id: Int64, relativePath: String)] = []
        while try subtitleStatement.step() {
            let file = URL(fileURLWithPath: subtitleStatement.stringColumn(1))
            if let relativePath = Self.relativeMediaPath(for: file, under: rootURL) {
                subtitleUpdates.append((subtitleStatement.int64Column(0), relativePath))
            }
        }

        let videoStatement = try database.prepare(
            """
            SELECT id, path
            FROM video_files
            WHERE library_id IS NULL;
            """
        )
        var videoUpdates: [(id: Int64, relativePath: String)] = []
        while try videoStatement.step() {
            let file = URL(fileURLWithPath: videoStatement.stringColumn(1))
            if let relativePath = Self.relativeMediaPath(for: file, under: rootURL) {
                videoUpdates.append((videoStatement.int64Column(0), relativePath))
            }
        }

        let updateSubtitle = try database.prepare(
            "UPDATE subtitle_files SET library_id = ?, relative_path = ? WHERE id = ?;"
        )
        for update in subtitleUpdates {
            try updateSubtitle.bind(libraryID, at: 1)
            try updateSubtitle.bind(update.relativePath, at: 2)
            try updateSubtitle.bind(update.id, at: 3)
            try updateSubtitle.run()
            try updateSubtitle.reset()
        }

        let updateVideo = try database.prepare(
            "UPDATE video_files SET library_id = ?, relative_path = ? WHERE id = ?;"
        )
        for update in videoUpdates {
            try updateVideo.bind(libraryID, at: 1)
            try updateVideo.bind(update.relativePath, at: 2)
            try updateVideo.bind(update.id, at: 3)
            try updateVideo.run()
            try updateVideo.reset()
        }
    }

    private static func relativeMediaPath(for file: URL, under root: URL) -> String? {
        let rootPath = normalizedFolderPath(root.standardizedFileURL.path)
        let filePath = file.standardizedFileURL.path
        let prefix = rootPath == "/" ? rootPath : rootPath + "/"
        guard filePath.hasPrefix(prefix) else {
            return nil
        }

        let relativePath = String(filePath.dropFirst(prefix.count))
            .precomposedStringWithCanonicalMapping
        return relativePath.isEmpty ? nil : relativePath
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
        let detachSubtitleFiles = try database.prepare(
            """
            UPDATE subtitle_files
            SET library_id = NULL, relative_path = NULL
            WHERE library_id IN (
                SELECT id FROM search_paths WHERE path = ?
            );
            """
        )
        try detachSubtitleFiles.bind(searchPath, at: 1)
        try detachSubtitleFiles.run()

        let detachVideoFiles = try database.prepare(
            """
            UPDATE video_files
            SET library_id = NULL, relative_path = NULL
            WHERE library_id IN (
                SELECT id FROM search_paths WHERE path = ?
            );
            """
        )
        try detachVideoFiles.bind(searchPath, at: 1)
        try detachVideoFiles.run()

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

    private static func libraryPlaybackHistoryUpdatedAtString(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
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
