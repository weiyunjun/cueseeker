import Foundation

public struct CueContent: Equatable, Sendable, Identifiable {
    public let cueID: Int64
    public let cueGroupID: Int64
    public let subtitleFileID: Int64?
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
    public let durationMilliseconds: Int
    public let characterWidth: Int
    public let content: String
    public let cueLines: [String]
    public let cueGroupLines: [String]
    public let languages: Set<SubtitleLanguageCode>

    public var id: Int64 { cueID }

    public init(
        cueID: Int64,
        cueGroupID: Int64,
        subtitleFileID: Int64? = nil,
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
        durationMilliseconds: Int? = nil,
        characterWidth: Int? = nil,
        content: String,
        cueLines: [String],
        cueGroupLines: [String],
        languages: Set<SubtitleLanguageCode>
    ) {
        self.cueID = cueID
        self.cueGroupID = cueGroupID
        self.subtitleFileID = subtitleFileID
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
        self.durationMilliseconds = max(0, durationMilliseconds ?? (endMilliseconds - startMilliseconds))
        self.characterWidth = max(0, characterWidth ?? CueCharacterFacet.characterWidth(of: content))
        self.content = content
        self.cueLines = cueLines
        self.cueGroupLines = cueGroupLines.isEmpty ? [content] : cueGroupLines
        self.languages = languages.isEmpty ? [.unknown] : languages
    }
}

public struct SubtitleSearchResult: Equatable, Sendable {
    public let entryID: Int64
    public let cueGroupID: Int64
    public let subtitleFileID: Int64?
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
    public let durationMilliseconds: Int
    public let characterWidth: Int
    public let content: String
    public let cueLines: [String]
    public let cueGroupLines: [String]
    public let languages: Set<SubtitleLanguageCode>
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
        subtitleFileID: Int64? = nil,
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
        durationMilliseconds: Int? = nil,
        characterWidth: Int? = nil,
        content: String,
        cueLines: [String],
        cueGroupLines: [String]? = nil,
        languages: Set<SubtitleLanguageCode> = [.unknown],
        searchRank: Int = 0
    ) {
        self.entryID = entryID
        self.cueGroupID = cueGroupID ?? entryID
        self.subtitleFileID = subtitleFileID
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
        self.durationMilliseconds = max(0, durationMilliseconds ?? (endMilliseconds - startMilliseconds))
        self.characterWidth = max(0, characterWidth ?? CueCharacterFacet.characterWidth(of: content))
        self.content = content
        self.cueLines = cueLines
        self.cueGroupLines = cueGroupLines ?? (cueLines.isEmpty ? [content] : cueLines)
        self.languages = languages.isEmpty ? [.unknown] : languages
        self.searchRank = searchRank
    }

    public init(cueContent: CueContent, searchRank: Int = 0) {
        self.init(
            entryID: cueContent.cueID,
            cueGroupID: cueContent.cueGroupID,
            subtitleFileID: cueContent.subtitleFileID,
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
            durationMilliseconds: cueContent.durationMilliseconds,
            characterWidth: cueContent.characterWidth,
            content: cueContent.content,
            cueLines: cueContent.cueLines,
            cueGroupLines: cueContent.cueGroupLines,
            languages: cueContent.languages,
            searchRank: searchRank
        )
    }

    public var cueContent: CueContent {
        CueContent(
            cueID: entryID,
            cueGroupID: cueGroupID,
            subtitleFileID: subtitleFileID,
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
            durationMilliseconds: durationMilliseconds,
            characterWidth: characterWidth,
            content: content,
            cueLines: cueLines,
            cueGroupLines: cueGroupLines,
            languages: languages
        )
    }
}

public enum SubtitleCueTimeRangeDisplay {
    public static func text(startMilliseconds: Int, endMilliseconds: Int) -> String {
        let sTotal = max(0, startMilliseconds) / 1_000
        let eTotal = max(startMilliseconds, max(0, endMilliseconds)) / 1_000
        let sHours = sTotal / 3_600
        let eHours = eTotal / 3_600
        let sMinutes = (sTotal % 3_600) / 60
        let sSeconds = sTotal % 60
        let eMinutes = (eTotal % 3_600) / 60
        let eSeconds = eTotal % 60

        if sHours == 0, eHours == 0 {
            return "\(twoDigits(sMinutes)):\(twoDigits(sSeconds)) - \(twoDigits(eMinutes)):\(twoDigits(eSeconds))"
        }
        return "\(twoDigits(sHours)):\(twoDigits(sMinutes)):\(twoDigits(sSeconds)) - \(twoDigits(eHours)):\(twoDigits(eMinutes)):\(twoDigits(eSeconds))"
    }

    @inline(__always)
    private static func twoDigits(_ value: Int) -> String {
        if value >= 0 && value < 100 {
            return twoDigitStrings[value]
        }
        return String(value)
    }

    private static let twoDigitStrings: [String] = (0..<100).map {
        $0 < 10 ? "0\($0)" : "\($0)"
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
    /// Results accepted since the previous snapshot; `resultOffset` is the
    /// rank of the first one.
    public let results: [SubtitleSearchResult]
    public let cueIDs: [Int64]
    public let resultOffset: Int

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
        cueIDs: [Int64] = [],
        resultOffset: Int = 0
    ) {
        self.countSnapshot = countSnapshot
        self.fileSummaries = fileSummaries
        self.results = results
        self.cueIDs = cueIDs
        self.resultOffset = resultOffset
    }
}

public typealias SubtitleSearchProgressSink = @Sendable (SubtitleSearchProgressSnapshot) -> Void

public enum SubtitleSearchPageMode: String, Equatable, Sendable, Codable {
    case exact
    case visibleWindow
}

public enum SearchSortOrder: String, CaseIterable, Identifiable, Codable, Equatable, Sendable {
    case `default` = "default"
    case mostCharacters = "most_characters"
    case fewestCharacters = "fewest_characters"

    public var id: String { rawValue }
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


public struct SubtitleSearchPage: Equatable, Sendable {
    public let results: [SubtitleSearchResult]
    /// Results not yet delivered through progress snapshots; `renderableResultsOffset`
    /// is the rank of the first one.
    public let renderableResults: [SubtitleSearchResult]
    public let renderableResultsOffset: Int
    public let cueIDs: [Int64]
    public let totalCount: Int
    public let fileSummaries: [SubtitleSearchFileSummary]
    public let countSnapshot: SubtitleSearchCountSnapshot
    public let appliedCursor: SubtitleSearchCursor
    public let nextCursor: SubtitleSearchCursor?
    public let pageMode: SubtitleSearchPageMode
    public let orderSource: String?
    public let materializedOrderRows: Int?
    public let facetSnapshot: CueFacetSnapshot?

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
        renderableResultsOffset: Int? = nil,
        cueIDs: [Int64]? = nil,
        totalCount: Int,
        fileSummaries: [SubtitleSearchFileSummary],
        countSnapshot: SubtitleSearchCountSnapshot? = nil,
        appliedCursor: SubtitleSearchCursor = .start,
        nextCursor: SubtitleSearchCursor? = nil,
        pageMode: SubtitleSearchPageMode = .exact,
        orderSource: String? = nil,
        materializedOrderRows: Int? = nil,
        facetSnapshot: CueFacetSnapshot? = nil
    ) {
        self.results = results
        self.renderableResults = renderableResults ?? results
        self.renderableResultsOffset = renderableResultsOffset ?? appliedCursor.offset
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
        self.facetSnapshot = facetSnapshot
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
