import Foundation

public struct ContinuousPlaybackSettings: Equatable, Sendable {
    public static let minimumSentenceCount = 1
    public static let maximumSentenceCount = 9_999
    public static let minimumPrecedingSentenceCount = 0
    public static let maximumPrecedingSentenceCount = 10

    public let sentenceCount: Int
    public let precedingSentenceCount: Int

    public init(
        sentenceCount: Int = Self.minimumSentenceCount,
        precedingSentenceCount: Int = Self.minimumPrecedingSentenceCount
    ) {
        let clampedPrecedingSentenceCount = Self.clampPrecedingSentenceCount(
            precedingSentenceCount
        )
        let clampedSentenceCount = Self.clampSentenceCount(sentenceCount)

        self.precedingSentenceCount = clampedPrecedingSentenceCount
        self.sentenceCount = max(
            clampedSentenceCount,
            clampedPrecedingSentenceCount + 1
        )
    }

    public func updatingSentenceCount(_ value: Int) -> ContinuousPlaybackSettings {
        let nextSentenceCount = Self.clampSentenceCount(value)
        return ContinuousPlaybackSettings(
            sentenceCount: nextSentenceCount,
            precedingSentenceCount: min(precedingSentenceCount, nextSentenceCount - 1)
        )
    }

    public func updatingPrecedingSentenceCount(_ value: Int) -> ContinuousPlaybackSettings {
        let nextPrecedingSentenceCount = Self.clampPrecedingSentenceCount(value)
        return ContinuousPlaybackSettings(
            sentenceCount: max(sentenceCount, nextPrecedingSentenceCount + 1),
            precedingSentenceCount: nextPrecedingSentenceCount
        )
    }

    private static func clampSentenceCount(_ value: Int) -> Int {
        min(max(value, minimumSentenceCount), maximumSentenceCount)
    }

    private static func clampPrecedingSentenceCount(_ value: Int) -> Int {
        min(max(value, minimumPrecedingSentenceCount), maximumPrecedingSentenceCount)
    }
}

public struct ContinuousPlaybackSegment: Equatable, Sendable {
    public let selectedIndex: Int
    public let startIndex: Int
    public let endIndex: Int
    public let startMilliseconds: Int
    public let endMilliseconds: Int
    public let lastCueStartMilliseconds: Int
}

public enum ContinuousPlaybackPlanner {
    public static func segment(
        forSelectedEntryID selectedEntryID: Int64,
        entries: [SubtitleDatabaseEntry],
        settings: ContinuousPlaybackSettings
    ) -> ContinuousPlaybackSegment? {
        guard !entries.isEmpty,
              let selectedIndex = entries.firstIndex(where: { $0.id == selectedEntryID })
        else {
            return nil
        }

        let startIndex = max(0, selectedIndex - settings.precedingSentenceCount)
        let endIndex = min(entries.count - 1, startIndex + settings.sentenceCount - 1)
        let startEntry = entries[startIndex]
        let endEntry = entries[endIndex]

        return ContinuousPlaybackSegment(
            selectedIndex: selectedIndex,
            startIndex: startIndex,
            endIndex: endIndex,
            startMilliseconds: startEntry.startMilliseconds,
            endMilliseconds: endEntry.endMilliseconds,
            lastCueStartMilliseconds: endEntry.startMilliseconds
        )
    }

    public static func activationBoundaryMilliseconds(
        forCurrentMilliseconds currentMilliseconds: Int,
        segment: ContinuousPlaybackSegment,
        entries: [SubtitleDatabaseEntry]
    ) -> Int {
        guard currentMilliseconds > segment.endMilliseconds else {
            return segment.endMilliseconds
        }

        if let activeEntry = entries.first(where: {
            $0.startMilliseconds <= currentMilliseconds
                && currentMilliseconds < $0.endMilliseconds
        }) {
            return activeEntry.endMilliseconds
        }

        return currentMilliseconds
    }

    public static func shouldPrepareNextItem(
        currentMilliseconds: Int,
        segment: ContinuousPlaybackSegment
    ) -> Bool {
        currentMilliseconds >= segment.lastCueStartMilliseconds
    }
}
