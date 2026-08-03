import Foundation

public enum SubtitleFocusNavigationDirection: Equatable, Sendable {
    case backward
    case forward
}

public struct SubtitleFocusSourceIdentity: Equatable, Hashable, Sendable {
    public let subtitleFileID: Int64?
    public let videoPath: String
    public let subtitlePath: String
    public let subtitleFormat: SubtitleFormat

    public init(
        subtitleFileID: Int64? = nil,
        videoPath: String,
        subtitlePath: String,
        subtitleFormat: SubtitleFormat
    ) {
        self.subtitleFileID = subtitleFileID
        self.videoPath = videoPath
        self.subtitlePath = subtitlePath
        self.subtitleFormat = subtitleFormat
    }
}

public struct SubtitleFocusCue: Equatable, Sendable, Identifiable {
    public let id: Int64
    public let cueGroupID: Int64
    public let ordinal: Int
    public let eventIndex: Int
    public let displayOrder: Int
    public let startMilliseconds: Int
    public let endMilliseconds: Int
    public let content: String

    public init(
        id: Int64,
        cueGroupID: Int64,
        ordinal: Int,
        eventIndex: Int,
        displayOrder: Int,
        startMilliseconds: Int,
        endMilliseconds: Int,
        content: String
    ) {
        let resolvedStartMilliseconds = max(0, startMilliseconds)
        self.id = id
        self.cueGroupID = cueGroupID
        self.ordinal = max(0, ordinal)
        self.eventIndex = eventIndex
        self.displayOrder = displayOrder
        self.startMilliseconds = resolvedStartMilliseconds
        self.endMilliseconds = max(resolvedStartMilliseconds, endMilliseconds)
        self.content = content
    }

    public var text: String {
        content
    }

    public var cueIdentity: SubtitleCueIdentity {
        SubtitleCueIdentity(
            eventIndex: eventIndex,
            startMilliseconds: startMilliseconds,
            endMilliseconds: endMilliseconds
        )
    }
}

public struct SubtitleFocusCueBatch: Equatable, Sendable {
    public let totalCount: Int
    public let cues: [SubtitleFocusCue]

    public init(totalCount: Int, cues: [SubtitleFocusCue]) {
        self.totalCount = max(0, totalCount)
        self.cues = cues.sorted { lhs, rhs in
            if lhs.ordinal == rhs.ordinal {
                return lhs.id < rhs.id
            }
            return lhs.ordinal < rhs.ordinal
        }
    }

    public var ordinalRange: Range<Int>? {
        guard let first = cues.first, let last = cues.last else {
            return nil
        }
        return first.ordinal..<(last.ordinal + 1)
    }
}

public struct SubtitleFocusSnapshot: Equatable, Sendable {
    public let totalCount: Int
    public let selectedOrdinal: Int
    public let cues: [SubtitleFocusCue]

    public init(
        totalCount: Int,
        selectedOrdinal: Int,
        cues: [SubtitleFocusCue]
    ) {
        self.totalCount = max(0, totalCount)
        self.selectedOrdinal = max(0, selectedOrdinal)
        self.cues = cues.sorted { lhs, rhs in
            if lhs.ordinal == rhs.ordinal {
                return lhs.id < rhs.id
            }
            return lhs.ordinal < rhs.ordinal
        }
    }

    public var selectedCue: SubtitleFocusCue? {
        cues.first { $0.ordinal == selectedOrdinal }
    }

    public var ordinalRange: Range<Int>? {
        SubtitleFocusCueBatch(totalCount: totalCount, cues: cues).ordinalRange
    }
}

public struct SubtitleFocusWindowPolicy: Equatable, Sendable {
    public static let standard = SubtitleFocusWindowPolicy(
        precedingCount: 6,
        followingCount: 3
    )

    public let precedingCount: Int
    public let followingCount: Int

    public init(
        precedingCount: Int,
        followingCount: Int
    ) {
        self.precedingCount = max(0, precedingCount)
        self.followingCount = max(0, followingCount)
    }

    public var initialCount: Int {
        precedingCount + 1 + followingCount
    }

    public func windowRange(totalCount: Int, selectedOrdinal: Int) -> Range<Int> {
        let boundedTotalCount = max(0, totalCount)
        guard boundedTotalCount > 0 else {
            return 0..<0
        }

        let count = min(initialCount, boundedTotalCount)
        let boundedSelectedOrdinal = min(max(0, selectedOrdinal), boundedTotalCount - 1)
        let preferredStart = boundedSelectedOrdinal - precedingCount
        let maximumStart = boundedTotalCount - count
        let start = min(max(0, preferredStart), maximumStart)
        return start..<(start + count)
    }
}
