import Foundation

public enum ExcerptListIdentity {
    public static let defaultListID: Int64 = 1
}

public enum ExcerptListValidationError: Error, Equatable, Sendable {
    case emptyName
    case nameTooLong(maximumCharacters: Int, currentCharacters: Int)
    case descriptionTooLong(maximumCharacters: Int, currentCharacters: Int)
    case duplicateName
}

public enum ExcerptListMutationError: Error, Equatable, Sendable {
    case listNotFound
    case cannotDeleteOnlyList
}

public struct ExcerptListValidation: Equatable, Sendable {
    public let nameError: ExcerptListValidationError?
    public let descriptionError: ExcerptListValidationError?

    public var isValid: Bool {
        nameError == nil && descriptionError == nil
    }

    public init(
        nameError: ExcerptListValidationError?,
        descriptionError: ExcerptListValidationError?
    ) {
        self.nameError = nameError
        self.descriptionError = descriptionError
    }
}

public struct ExcerptList: Equatable, Sendable, Identifiable {
    public let id: Int64
    public let name: String
    public let description: String
    public let coverPath: String?
    public let createdAt: String
    public let recentCueID: Int64?
    public let recentSortOrder: String?
    public let recentPlayedAt: String?

    public init(
        id: Int64,
        name: String,
        description: String,
        coverPath: String?,
        createdAt: String,
        recentCueID: Int64? = nil,
        recentSortOrder: String? = nil,
        recentPlayedAt: String? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.coverPath = coverPath
        self.createdAt = createdAt
        self.recentCueID = recentCueID
        self.recentSortOrder = recentSortOrder
        self.recentPlayedAt = recentPlayedAt
    }
}

public struct ExcerptListSummary: Equatable, Sendable, Identifiable {
    public let list: ExcerptList
    public let cueCount: Int
    public let resumeExcerpt: Excerpt?
    public let resumePosition: Int?

    public var id: Int64 {
        list.id
    }

    public init(
        list: ExcerptList,
        cueCount: Int,
        resumeExcerpt: Excerpt? = nil,
        resumePosition: Int? = nil
    ) {
        self.list = list
        self.cueCount = cueCount
        self.resumeExcerpt = resumeExcerpt
        self.resumePosition = resumePosition
    }
}

public struct ExcerptListOverview: Equatable, Sendable {
    public let lists: [ExcerptListSummary]
    public let uniqueCueCount: Int

    public init(lists: [ExcerptListSummary], uniqueCueCount: Int) {
        self.lists = lists
        self.uniqueCueCount = uniqueCueCount
    }
}

public struct ExcerptRelation: Equatable, Sendable, Identifiable {
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

public struct ExcerptResidentSnapshot: Equatable, Sendable {
    public let relations: [ExcerptRelation]
    public let resolvedExcerpts: [Excerpt]
    public let cueContents: [CueContent]
    public let facetSnapshot: CueFacetSnapshot

    public init(
        relations: [ExcerptRelation],
        resolvedExcerpts: [Excerpt] = [],
        cueContents: [CueContent],
        facetSnapshot: CueFacetSnapshot = .empty
    ) {
        self.relations = relations
        self.resolvedExcerpts = resolvedExcerpts
        self.cueContents = cueContents
        self.facetSnapshot = facetSnapshot
    }
}

public enum ExcerptTransferError: Error, Equatable, Sendable {
    case sourceUnavailable
    case destinationUnavailable
    case destinationAlreadyContainsCue(listID: Int64)
}

public enum ExcerptUnavailableReason: String, Equatable, Sendable {
    case libraryUnavailable = "library_unavailable"
    case videoMissing = "video_missing"
    case subtitleMissing = "subtitle_missing"
    case cueMissing = "cue_missing"
}

public struct ExcerptCueContentChange: Equatable, Sendable {
    public let previousContent: String
    public let currentContent: String

    public init(previousContent: String, currentContent: String) {
        self.previousContent = previousContent
        self.currentContent = currentContent
    }
}

/// A resolved Excerpt value used by playback and legacy presentation call sites.
/// Persisted Excerpt state is represented by `ExcerptRelation`; every other field
/// here is resolved from the referenced current Cue.
public struct Excerpt: Equatable, Sendable, Identifiable {
    public static let cueGroupContentSeparator = "\u{001F}"

    public let id: Int64
    public let subtitleFileID: Int64?
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
    public let cueEventIndex: Int?
    public let cueDisplayOrder: Int?
    public let content: String
    public let cueGroupContent: String
    public let isValid: Bool
    public let unavailableReason: ExcerptUnavailableReason?
    public let contentChange: ExcerptCueContentChange?
    public let createdAt: String

    public init(
        id: Int64,
        subtitleFileID: Int64? = nil,
        subtitlePath: String,
        subtitleFormat: SubtitleFormat,
        videoPath: String,
        videoName: String,
        displayTitle: String? = nil,
        timeRange: String = "",
        startMilliseconds: Int,
        endMilliseconds: Int,
        durationMilliseconds: Int? = nil,
        characterWidth: Int? = nil,
        cueEventIndex: Int? = nil,
        cueDisplayOrder: Int? = nil,
        content: String,
        cueGroupContent: String? = nil,
        isValid: Bool,
        unavailableReason: ExcerptUnavailableReason? = nil,
        contentChange: ExcerptCueContentChange? = nil,
        createdAt: String
    ) {
        self.id = id
        self.subtitleFileID = subtitleFileID
        self.subtitlePath = subtitlePath
        self.subtitleFormat = subtitleFormat
        self.videoPath = videoPath
        self.videoName = videoName
        self.displayTitle = if let displayTitle, !displayTitle.isEmpty {
            displayTitle
        } else {
            videoName
        }
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
        self.cueEventIndex = cueEventIndex
        self.cueDisplayOrder = cueDisplayOrder
        self.content = content
        self.cueGroupContent = cueGroupContent ?? content
        self.unavailableReason = unavailableReason
        self.isValid = isValid && unavailableReason == nil
        self.contentChange = contentChange
        self.createdAt = createdAt
    }

    public init(relation: ExcerptRelation, cueContent: CueContent) {
        self.init(
            id: relation.id,
            subtitleFileID: cueContent.subtitleFileID,
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
            cueEventIndex: cueContent.cueEventIndex,
            cueDisplayOrder: cueContent.cueDisplayOrder,
            content: cueContent.content,
            cueGroupContent: cueContent.cueGroupLines.joined(
                separator: Self.cueGroupContentSeparator
            ),
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

public struct ExcerptCuePresentation: Equatable, Sendable {
    public let cueID: Int64?
    public let cueGroupID: Int64?
    public let primaryGroupIndex: Int?
    public let cueGroupTexts: [String]
    public let languages: Set<SubtitleLanguageCode>

    public init(
        cueID: Int64?,
        cueGroupID: Int64?,
        primaryGroupIndex: Int?,
        cueGroupTexts: [String],
        languages: Set<SubtitleLanguageCode>
    ) {
        self.cueID = cueID
        self.cueGroupID = cueGroupID
        self.primaryGroupIndex = primaryGroupIndex
        self.cueGroupTexts = cueGroupTexts
        self.languages = languages.isEmpty ? [.unknown] : languages
    }

    public init(cueContent: CueContent) {
        self.init(
            cueID: cueContent.cueID,
            cueGroupID: cueContent.cueGroupID,
            primaryGroupIndex: cueContent.primaryGroupIndex,
            cueGroupTexts: cueContent.cueGroupLines,
            languages: cueContent.languages
        )
    }
}

public enum ExcerptNavigationDirection: Equatable, Sendable {
    case previous
    case next
}

public enum ExcerptSortOrder: String, CaseIterable, Identifiable, Codable, Equatable, Sendable {
    case earliestDateAdded = "earliest_date_added"
    case latestDateAdded = "latest_date_added"
    case mostCharacters = "most_characters"
    case fewestCharacters = "fewest_characters"

    public var id: String { rawValue }
}
