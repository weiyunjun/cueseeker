import Foundation

public enum ShioriTagValidationError: Error, Equatable {
    case emptyName
    case nameTooLong(maximumCharacters: Int)
    case invalidCharacters
}


public enum ShioriListIdentity {
    public static let defaultListID: Int64 = 1
}

public enum ShioriListValidationError: Error, Equatable, Sendable {
    case emptyName
    case nameTooLong(maximumCharacters: Int, currentCharacters: Int)
    case descriptionTooLong(maximumCharacters: Int, currentCharacters: Int)
    case duplicateName
}

public enum ShioriListMutationError: Error, Equatable, Sendable {
    case listNotFound
    case cannotDeleteOnlyList
}

public struct ShioriListValidation: Equatable, Sendable {
    public let nameError: ShioriListValidationError?
    public let descriptionError: ShioriListValidationError?

    public var isValid: Bool {
        nameError == nil && descriptionError == nil
    }

    public init(
        nameError: ShioriListValidationError?,
        descriptionError: ShioriListValidationError?
    ) {
        self.nameError = nameError
        self.descriptionError = descriptionError
    }
}

public struct ShioriList: Equatable, Sendable, Identifiable {
    public let id: Int64
    public let name: String
    public let description: String
    public let coverPath: String?
    public let createdAt: String

    public init(
        id: Int64,
        name: String,
        description: String,
        coverPath: String?,
        createdAt: String
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.coverPath = coverPath
        self.createdAt = createdAt
    }
}

public struct ShioriListSummary: Equatable, Sendable, Identifiable {
    public let list: ShioriList
    public let cueCount: Int

    public var id: Int64 {
        list.id
    }

    public init(list: ShioriList, cueCount: Int) {
        self.list = list
        self.cueCount = cueCount
    }
}

public struct ShioriListOverview: Equatable, Sendable {
    public let lists: [ShioriListSummary]
    public let uniqueCueCount: Int

    public init(lists: [ShioriListSummary], uniqueCueCount: Int) {
        self.lists = lists
        self.uniqueCueCount = uniqueCueCount
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

public enum ShioriNavigationDirection: Equatable, Sendable {
    case previous
    case next
}
