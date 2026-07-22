import Foundation

public struct PlaybackSubtitleEntry: Equatable, Sendable {
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

public struct PlaybackSubtitleEntryIndexItem: Equatable, Sendable {
    public let id: Int64
    public let startMilliseconds: Int
    public let endMilliseconds: Int

    public init(id: Int64, startMilliseconds: Int, endMilliseconds: Int) {
        self.id = id
        self.startMilliseconds = startMilliseconds
        self.endMilliseconds = endMilliseconds
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
