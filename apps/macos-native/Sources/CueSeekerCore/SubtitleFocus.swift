import Foundation

public enum SubtitleFocusNavigationDirection: Equatable, Sendable {
    case backward
    case forward
}

public struct SubtitleFocusSourceIdentity: Equatable, Hashable, Sendable {
    public let videoPath: String
    public let subtitlePath: String
    public let subtitleFormat: SubtitleFormat

    public init(
        videoPath: String,
        subtitlePath: String,
        subtitleFormat: SubtitleFormat
    ) {
        self.videoPath = videoPath
        self.subtitlePath = subtitlePath
        self.subtitleFormat = subtitleFormat
    }
}

public struct SubtitleFocusCue: Equatable, Sendable, Identifiable {
    public let id: Int64
    public let ordinal: Int
    public let startMilliseconds: Int
    public let endMilliseconds: Int
    public let lines: [String]

    public init(
        id: Int64,
        ordinal: Int,
        startMilliseconds: Int,
        endMilliseconds: Int,
        lines: [String]
    ) {
        let resolvedStartMilliseconds = max(0, startMilliseconds)
        self.id = id
        self.ordinal = max(0, ordinal)
        self.startMilliseconds = resolvedStartMilliseconds
        self.endMilliseconds = max(resolvedStartMilliseconds, endMilliseconds)
        self.lines = lines
    }

    public var text: String {
        lines.joined(separator: "\n")
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
        followingCount: 3,
        batchSize: 10,
        maximumRetainedCount: 30,
        prefetchThreshold: 2
    )

    public let precedingCount: Int
    public let followingCount: Int
    public let batchSize: Int
    public let maximumRetainedCount: Int
    public let prefetchThreshold: Int

    public init(
        precedingCount: Int,
        followingCount: Int,
        batchSize: Int,
        maximumRetainedCount: Int,
        prefetchThreshold: Int
    ) {
        self.precedingCount = max(0, precedingCount)
        self.followingCount = max(0, followingCount)
        self.batchSize = max(1, batchSize)
        self.maximumRetainedCount = max(1, maximumRetainedCount)
        self.prefetchThreshold = max(0, prefetchThreshold)
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

    public func shouldPrefetch(
        selectedOrdinal: Int,
        loadedRange: Range<Int>,
        direction: SubtitleFocusNavigationDirection
    ) -> Bool {
        guard !loadedRange.isEmpty, loadedRange.contains(selectedOrdinal) else {
            return false
        }

        switch direction {
        case .backward:
            return selectedOrdinal - loadedRange.lowerBound <= prefetchThreshold
        case .forward:
            return loadedRange.upperBound - selectedOrdinal - 1 <= prefetchThreshold
        }
    }

    public func prefetchRange(
        totalCount: Int,
        loadedRange: Range<Int>,
        direction: SubtitleFocusNavigationDirection
    ) -> Range<Int>? {
        let boundedTotalCount = max(0, totalCount)
        switch direction {
        case .backward:
            guard loadedRange.lowerBound > 0 else {
                return nil
            }
            let end = min(loadedRange.lowerBound, boundedTotalCount)
            return max(0, end - batchSize)..<end
        case .forward:
            let start = min(max(0, loadedRange.upperBound), boundedTotalCount)
            guard start < boundedTotalCount else {
                return nil
            }
            return start..<min(boundedTotalCount, start + batchSize)
        }
    }
}

public struct SubtitleFocusCueCache: Equatable, Sendable {
    public let policy: SubtitleFocusWindowPolicy
    private var cuesByOrdinal: [Int: SubtitleFocusCue]

    public init(policy: SubtitleFocusWindowPolicy = .standard) {
        self.policy = policy
        cuesByOrdinal = [:]
    }

    public var count: Int {
        cuesByOrdinal.count
    }

    public var cues: [SubtitleFocusCue] {
        cuesByOrdinal.values.sorted { lhs, rhs in
            if lhs.ordinal == rhs.ordinal {
                return lhs.id < rhs.id
            }
            return lhs.ordinal < rhs.ordinal
        }
    }

    public var ordinalRange: Range<Int>? {
        SubtitleFocusCueBatch(totalCount: count, cues: cues).ordinalRange
    }

    public subscript(ordinal: Int) -> SubtitleFocusCue? {
        cuesByOrdinal[ordinal]
    }

    public mutating func replace(with batch: SubtitleFocusCueBatch) {
        cuesByOrdinal = Dictionary(
            batch.cues.prefix(policy.maximumRetainedCount).map { ($0.ordinal, $0) },
            uniquingKeysWith: { _, replacement in replacement }
        )
    }

    @discardableResult
    public mutating func merge(
        _ batch: SubtitleFocusCueBatch,
        direction: SubtitleFocusNavigationDirection
    ) -> [Int] {
        for cue in batch.cues {
            cuesByOrdinal[cue.ordinal] = cue
        }

        guard cuesByOrdinal.count > policy.maximumRetainedCount else {
            return []
        }

        let candidates = cuesByOrdinal.keys.sorted { lhs, rhs in
            switch direction {
            case .backward:
                return lhs > rhs
            case .forward:
                return lhs < rhs
            }
        }
        let overflowCount = cuesByOrdinal.count - policy.maximumRetainedCount
        let removalCount = min(
            candidates.count,
            max(overflowCount, policy.batchSize)
        )
        let removedOrdinals = Array(candidates.prefix(removalCount))
        for ordinal in removedOrdinals {
            cuesByOrdinal.removeValue(forKey: ordinal)
        }
        return removedOrdinals
    }

    public mutating func removeAll() {
        cuesByOrdinal.removeAll(keepingCapacity: false)
    }
}

public struct SubtitleFocusRequestToken: Equatable, Sendable {
    public let source: SubtitleFocusSourceIdentity
    public let sessionGeneration: Int
    public let requestGeneration: Int
    public let targetOrdinal: Int
}

public struct SubtitleFocusRequestGate: Equatable, Sendable {
    public let source: SubtitleFocusSourceIdentity
    public let sessionGeneration: Int
    public private(set) var latestRequestGeneration: Int
    public private(set) var isActive: Bool

    public init(
        source: SubtitleFocusSourceIdentity,
        sessionGeneration: Int
    ) {
        self.source = source
        self.sessionGeneration = sessionGeneration
        latestRequestGeneration = 0
        isActive = true
    }

    public mutating func issueRequest(targetOrdinal: Int) -> SubtitleFocusRequestToken? {
        guard isActive else {
            return nil
        }
        latestRequestGeneration += 1
        return SubtitleFocusRequestToken(
            source: source,
            sessionGeneration: sessionGeneration,
            requestGeneration: latestRequestGeneration,
            targetOrdinal: max(0, targetOrdinal)
        )
    }

    public func accepts(_ token: SubtitleFocusRequestToken) -> Bool {
        isActive
            && token.source == source
            && token.sessionGeneration == sessionGeneration
            && token.requestGeneration == latestRequestGeneration
    }

    public mutating func invalidate() {
        isActive = false
        latestRequestGeneration += 1
    }
}
