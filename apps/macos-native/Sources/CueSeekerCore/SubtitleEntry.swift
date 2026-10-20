import Foundation

public enum SubtitleFormat: String, Equatable, Sendable {
    case srt
    case ass
    case ssa
    case vtt

    public init?(fileExtension: String) {
        switch fileExtension.lowercased() {
        case "srt":
            self = .srt
        case "ass":
            self = .ass
        case "ssa":
            self = .ssa
        case "vtt":
            self = .vtt
        default:
            return nil
        }
    }

    public var sortPriority: Int {
        switch self {
        case .ass:
            return 0
        case .ssa:
            return 1
        case .srt:
            return 2
        case .vtt:
            return 3
        }
    }

    public var usesASSSemantics: Bool {
        switch self {
        case .ass, .ssa:
            return true
        case .srt, .vtt:
            return false
        }
    }
}

public struct SubtitleEntry: Equatable, Sendable {
    public let sequenceNumber: Int?
    public let startTimecode: String
    public let endTimecode: String
    public let startMilliseconds: Int
    public let endMilliseconds: Int
    public let text: String

    public init(
        sequenceNumber: Int?,
        startTimecode: String,
        endTimecode: String,
        startMilliseconds: Int,
        endMilliseconds: Int,
        text: String
    ) {
        self.sequenceNumber = sequenceNumber
        self.startTimecode = startTimecode
        self.endTimecode = endTimecode
        self.startMilliseconds = startMilliseconds
        self.endMilliseconds = endMilliseconds
        self.text = text
    }

    public func cueGroup(
        eventIndex: Int,
        sourceFormat: SubtitleFormat = .srt
    ) -> SubtitleCueGroup {
        let line = SubtitleCueLine(
            eventIndex: eventIndex,
            sourceFormat: sourceFormat,
            sourceStyle: nil,
            sourceLayer: nil,
            startTimecode: startTimecode,
            endTimecode: endTimecode,
            startMilliseconds: startMilliseconds,
            endMilliseconds: endMilliseconds,
            content: text,
            displayX: nil,
            displayY: nil,
            displayOrder: 0
        )

        return SubtitleCueGroup(
            sequenceNumber: sequenceNumber,
            startTimecode: startTimecode,
            endTimecode: endTimecode,
            startMilliseconds: startMilliseconds,
            endMilliseconds: endMilliseconds,
            searchContent: text,
            cueLines: [line]
        )
    }
}

public struct SubtitleCueGroup: Equatable, Sendable {
    public let sequenceNumber: Int?
    public let startTimecode: String
    public let endTimecode: String
    public let startMilliseconds: Int
    public let endMilliseconds: Int
    public let searchContent: String
    public let cueLines: [SubtitleCueLine]

    public init(
        sequenceNumber: Int?,
        startTimecode: String,
        endTimecode: String,
        startMilliseconds: Int,
        endMilliseconds: Int,
        searchContent: String,
        cueLines: [SubtitleCueLine]
    ) {
        self.sequenceNumber = sequenceNumber
        self.startTimecode = startTimecode
        self.endTimecode = endTimecode
        self.startMilliseconds = startMilliseconds
        self.endMilliseconds = endMilliseconds
        self.searchContent = searchContent
        self.cueLines = cueLines
    }
}

public struct SubtitleCueLine: Equatable, Sendable {
    public let eventIndex: Int
    public let sourceFormat: SubtitleFormat
    public let sourceStyle: String?
    public let sourceLayer: Int?
    public let sourceIdentityRemainder: String
    public let startTimecode: String
    public let endTimecode: String
    public let startMilliseconds: Int
    public let endMilliseconds: Int
    public let durationMilliseconds: Int
    public let characterWidth: Int
    public let content: String
    public let displayX: Double?
    public let displayY: Double?
    public let displayOrder: Int

    public init(
        eventIndex: Int,
        sourceFormat: SubtitleFormat,
        sourceStyle: String?,
        sourceLayer: Int?,
        sourceIdentityRemainder: String,
        startTimecode: String,
        endTimecode: String,
        startMilliseconds: Int,
        endMilliseconds: Int,
        durationMilliseconds: Int? = nil,
        characterWidth: Int? = nil,
        content: String,
        displayX: Double?,
        displayY: Double?,
        displayOrder: Int
    ) {
        self.eventIndex = eventIndex
        self.sourceFormat = sourceFormat
        self.sourceStyle = sourceStyle
        self.sourceLayer = sourceLayer
        self.sourceIdentityRemainder = sourceIdentityRemainder
        self.startTimecode = startTimecode
        self.endTimecode = endTimecode
        self.startMilliseconds = startMilliseconds
        self.endMilliseconds = endMilliseconds
        self.durationMilliseconds = max(0, durationMilliseconds ?? (endMilliseconds - startMilliseconds))
        self.characterWidth = max(0, characterWidth ?? CueCharacterFacet.characterWidth(of: content))
        self.content = content
        self.displayX = displayX
        self.displayY = displayY
        self.displayOrder = displayOrder
    }

    public init(
        eventIndex: Int,
        sourceFormat: SubtitleFormat,
        sourceStyle: String?,
        sourceLayer: Int?,
        startTimecode: String,
        endTimecode: String,
        startMilliseconds: Int,
        endMilliseconds: Int,
        content: String,
        displayX: Double?,
        displayY: Double?,
        displayOrder: Int
    ) {
        self.init(
            eventIndex: eventIndex,
            sourceFormat: sourceFormat,
            sourceStyle: sourceStyle,
            sourceLayer: sourceLayer,
            sourceIdentityRemainder: "",
            startTimecode: startTimecode,
            endTimecode: endTimecode,
            startMilliseconds: startMilliseconds,
            endMilliseconds: endMilliseconds,
            durationMilliseconds: nil,
            characterWidth: nil,
            content: content,
            displayX: displayX,
            displayY: displayY,
            displayOrder: displayOrder
        )
    }

    public init(
        eventIndex: Int,
        sourceFormat: SubtitleFormat,
        sourceStyle: String?,
        sourceLayer: Int?,
        startTimecode: String,
        endTimecode: String,
        startMilliseconds: Int,
        endMilliseconds: Int,
        durationMilliseconds: Int?,
        characterWidth: Int?,
        content: String,
        displayX: Double?,
        displayY: Double?,
        displayOrder: Int
    ) {
        self.init(
            eventIndex: eventIndex,
            sourceFormat: sourceFormat,
            sourceStyle: sourceStyle,
            sourceLayer: sourceLayer,
            sourceIdentityRemainder: "",
            startTimecode: startTimecode,
            endTimecode: endTimecode,
            startMilliseconds: startMilliseconds,
            endMilliseconds: endMilliseconds,
            durationMilliseconds: durationMilliseconds,
            characterWidth: characterWidth,
            content: content,
            displayX: displayX,
            displayY: displayY,
            displayOrder: displayOrder
        )
    }
}
