import Foundation

public struct SubtitleCollageTimeRange: Equatable, Hashable, Sendable {
    public let startMilliseconds: Int
    public let endMilliseconds: Int

    public init(startMilliseconds: Int, endMilliseconds: Int) {
        let startMilliseconds = max(0, startMilliseconds)
        self.startMilliseconds = startMilliseconds
        self.endMilliseconds = max(startMilliseconds, endMilliseconds)
    }
}

public struct SubtitleCollageGroup: Equatable, Sendable {
    public let timeRanges: [SubtitleCollageTimeRange]
    public let cues: [SubtitleFocusCue]
    public let intersectionStartMilliseconds: Int
    public let intersectionEndMilliseconds: Int

    public var renderTimestampMilliseconds: Int {
        intersectionStartMilliseconds
            + ((intersectionEndMilliseconds - intersectionStartMilliseconds) / 2)
    }
}

public struct SubtitleCollageGroupChange: Equatable, Sendable {
    public let previousGroupRange: Range<Int>
    public let currentGroupRange: Range<Int>
}

public enum SubtitleCollageSelectionMutation: Equatable, Sendable {
    case unchanged
    case selectionLimitReached
    case changed(SubtitleCollageGroupChange)
}

public enum SubtitleCollageSelectionError: Error, Equatable, Sendable {
    case selectionLimitExceeded
}

public struct SubtitleCollageSelectionPlan: Equatable, Sendable {
    public static let maximumSelectedCueCount = 50
    public static let minimumGroupOverlapMilliseconds = 100

    public private(set) var groups: [SubtitleCollageGroup]

    private var selectedCuesByID: [Int64: SubtitleFocusCue]

    public init() {
        groups = []
        selectedCuesByID = [:]
    }

    public init(selectedCues: [SubtitleFocusCue]) throws {
        var selectedCuesByID: [Int64: SubtitleFocusCue] = [:]
        for cue in selectedCues where selectedCuesByID[cue.id] == nil {
            selectedCuesByID[cue.id] = cue
        }
        guard selectedCuesByID.count <= Self.maximumSelectedCueCount else {
            throw SubtitleCollageSelectionError.selectionLimitExceeded
        }

        let timestampBuckets = Self.makeTimestampBuckets(
            from: selectedCuesByID.values
        )
        self.selectedCuesByID = selectedCuesByID
        groups = Self.makeGroups(from: timestampBuckets)
    }

    public var selectedCues: [SubtitleFocusCue] {
        selectedCuesByID.values.sorted(by: Self.cuePrecedes)
    }

    public var selectedCueCount: Int {
        selectedCuesByID.count
    }

    public var canSelectAnotherCue: Bool {
        selectedCueCount < Self.maximumSelectedCueCount
    }

    public func contains(cueID: Int64) -> Bool {
        selectedCuesByID[cueID] != nil
    }

    @discardableResult
    public mutating func select(
        _ cue: SubtitleFocusCue
    ) -> SubtitleCollageSelectionMutation {
        guard selectedCuesByID[cue.id] == nil else {
            return .unchanged
        }
        guard canSelectAnotherCue else {
            return .selectionLimitReached
        }

        let previousGroups = groups
        selectedCuesByID[cue.id] = cue
        let timestampBuckets = Self.makeTimestampBuckets(
            from: selectedCuesByID.values
        )
        groups = Self.makeGroupsIncrementally(
            from: timestampBuckets,
            previousGroups: previousGroups,
            changedTimeRange: Self.timeRange(for: cue)
        )
        return .changed(Self.groupChange(from: previousGroups, to: groups))
    }

    @discardableResult
    public mutating func deselect(
        cueID: Int64
    ) -> SubtitleCollageSelectionMutation {
        guard let removedCue = selectedCuesByID.removeValue(forKey: cueID) else {
            return .unchanged
        }

        let previousGroups = groups
        let timestampBuckets = Self.makeTimestampBuckets(
            from: selectedCuesByID.values
        )
        groups = Self.makeGroupsIncrementally(
            from: timestampBuckets,
            previousGroups: previousGroups,
            changedTimeRange: Self.timeRange(for: removedCue)
        )
        return .changed(Self.groupChange(from: previousGroups, to: groups))
    }
}

private extension SubtitleCollageSelectionPlan {
    struct TimestampBucket: Equatable, Sendable {
        let timeRange: SubtitleCollageTimeRange
        let cues: [SubtitleFocusCue]
    }

    static func makeTimestampBuckets<Cues: Collection>(
        from cues: Cues
    ) -> [TimestampBucket] where Cues.Element == SubtitleFocusCue {
        Dictionary(grouping: cues, by: timeRange(for:))
            .map { timeRange, cues in
                TimestampBucket(
                    timeRange: timeRange,
                    cues: cues.sorted(by: cuePrecedes)
                )
            }
            .sorted {
                timeRangePrecedes($0.timeRange, $1.timeRange)
            }
    }

    static func makeGroups(
        from buckets: [TimestampBucket]
    ) -> [SubtitleCollageGroup] {
        var groups: [SubtitleCollageGroup] = []
        var bucketIndex = 0
        while bucketIndex < buckets.count {
            let result = makeGroup(from: buckets, startingAt: bucketIndex)
            groups.append(result.group)
            bucketIndex = result.nextBucketIndex
        }
        return groups
    }

    static func makeGroupsIncrementally(
        from buckets: [TimestampBucket],
        previousGroups: [SubtitleCollageGroup],
        changedTimeRange: SubtitleCollageTimeRange
    ) -> [SubtitleCollageGroup] {
        guard !buckets.isEmpty else {
            return []
        }
        guard !previousGroups.isEmpty else {
            return makeGroups(from: buckets)
        }

        let predecessor = buckets.last {
            timeRangePrecedes($0.timeRange, changedTimeRange)
        }
        let recomputedGroupIndex = predecessor.flatMap { predecessor in
            previousGroups.firstIndex {
                $0.timeRanges.contains(predecessor.timeRange)
            }
        } ?? 0

        var updatedGroups = Array(previousGroups.prefix(recomputedGroupIndex))
        let retainedLastTimeRange = updatedGroups.last?.timeRanges.last
        var bucketIndex = retainedLastTimeRange.flatMap { retainedLastTimeRange in
            buckets.firstIndex {
                timeRangePrecedes(retainedLastTimeRange, $0.timeRange)
            }
        } ?? 0

        let previousGroupIndexByFirstTimeRange = Dictionary(
            uniqueKeysWithValues: previousGroups.enumerated().compactMap {
                index, group in
                group.timeRanges.first.map { ($0, index) }
            }
        )

        while bucketIndex < buckets.count {
            let result = makeGroup(from: buckets, startingAt: bucketIndex)
            let group = result.group
            updatedGroups.append(group)
            bucketIndex = result.nextBucketIndex

            guard let lastTimeRange = group.timeRanges.last,
                  !timeRangePrecedes(lastTimeRange, changedTimeRange),
                  let firstTimeRange = group.timeRanges.first,
                  let previousGroupIndex = previousGroupIndexByFirstTimeRange[
                      firstTimeRange
                  ],
                  previousGroupIndex >= recomputedGroupIndex,
                  group == previousGroups[previousGroupIndex]
            else {
                continue
            }

            updatedGroups.append(
                contentsOf: previousGroups.suffix(
                    from: previousGroups.index(after: previousGroupIndex)
                )
            )
            break
        }

        return updatedGroups
    }

    static func makeGroup(
        from buckets: [TimestampBucket],
        startingAt startIndex: Int
    ) -> (group: SubtitleCollageGroup, nextBucketIndex: Int) {
        let firstBucket = buckets[startIndex]
        var groupedBuckets = [firstBucket]
        var intersectionStartMilliseconds = firstBucket.timeRange.startMilliseconds
        var intersectionEndMilliseconds = firstBucket.timeRange.endMilliseconds
        var nextBucketIndex = startIndex + 1

        while nextBucketIndex < buckets.count {
            let bucket = buckets[nextBucketIndex]
            let candidateIntersectionStart = max(
                intersectionStartMilliseconds,
                bucket.timeRange.startMilliseconds
            )
            let candidateIntersectionEnd = min(
                intersectionEndMilliseconds,
                bucket.timeRange.endMilliseconds
            )
            guard candidateIntersectionEnd - candidateIntersectionStart
                    >= minimumGroupOverlapMilliseconds
            else {
                break
            }

            groupedBuckets.append(bucket)
            intersectionStartMilliseconds = candidateIntersectionStart
            intersectionEndMilliseconds = candidateIntersectionEnd
            nextBucketIndex += 1
        }

        return (
            SubtitleCollageGroup(
                timeRanges: groupedBuckets.map(\.timeRange),
                cues: groupedBuckets.flatMap(\.cues),
                intersectionStartMilliseconds: intersectionStartMilliseconds,
                intersectionEndMilliseconds: intersectionEndMilliseconds
            ),
            nextBucketIndex
        )
    }

    static func groupChange(
        from previousGroups: [SubtitleCollageGroup],
        to currentGroups: [SubtitleCollageGroup]
    ) -> SubtitleCollageGroupChange {
        let sharedCount = min(previousGroups.count, currentGroups.count)
        var commonPrefixCount = 0
        while commonPrefixCount < sharedCount,
              previousGroups[commonPrefixCount] == currentGroups[commonPrefixCount] {
            commonPrefixCount += 1
        }

        var commonSuffixCount = 0
        while commonSuffixCount < sharedCount - commonPrefixCount,
              previousGroups[previousGroups.count - commonSuffixCount - 1]
                == currentGroups[currentGroups.count - commonSuffixCount - 1] {
            commonSuffixCount += 1
        }

        return SubtitleCollageGroupChange(
            previousGroupRange: commonPrefixCount..<(previousGroups.count - commonSuffixCount),
            currentGroupRange: commonPrefixCount..<(currentGroups.count - commonSuffixCount)
        )
    }

    static func timeRange(
        for cue: SubtitleFocusCue
    ) -> SubtitleCollageTimeRange {
        SubtitleCollageTimeRange(
            startMilliseconds: cue.startMilliseconds,
            endMilliseconds: cue.endMilliseconds
        )
    }

    static func timeRangePrecedes(
        _ lhs: SubtitleCollageTimeRange,
        _ rhs: SubtitleCollageTimeRange
    ) -> Bool {
        if lhs.startMilliseconds != rhs.startMilliseconds {
            return lhs.startMilliseconds < rhs.startMilliseconds
        }
        return lhs.endMilliseconds < rhs.endMilliseconds
    }

    static func cuePrecedes(
        _ lhs: SubtitleFocusCue,
        _ rhs: SubtitleFocusCue
    ) -> Bool {
        let lhsTimeRange = timeRange(for: lhs)
        let rhsTimeRange = timeRange(for: rhs)
        if lhsTimeRange != rhsTimeRange {
            return timeRangePrecedes(lhsTimeRange, rhsTimeRange)
        }
        if lhs.displayOrder != rhs.displayOrder {
            return lhs.displayOrder < rhs.displayOrder
        }
        if lhs.eventIndex != rhs.eventIndex {
            return lhs.eventIndex < rhs.eventIndex
        }
        return lhs.id < rhs.id
    }
}
