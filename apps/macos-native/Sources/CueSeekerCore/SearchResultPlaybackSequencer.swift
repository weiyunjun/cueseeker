import Foundation

public struct ResultAutoplayWindow: Equatable, Sendable {
    public let cueTimings: [SubtitleCueTiming]
    public let firstExcludedCueTiming: SubtitleCueTiming?
    public let startMilliseconds: Int
    public let endMilliseconds: Int

    public init(
        cueTimings: [SubtitleCueTiming],
        firstExcludedCueTiming: SubtitleCueTiming? = nil
    ) {
        let sortedCueTimings = cueTimings.sorted {
            if $0.startMilliseconds == $1.startMilliseconds {
                return $0.endMilliseconds < $1.endMilliseconds
            }

            return $0.startMilliseconds < $1.startMilliseconds
        }
        self.cueTimings = sortedCueTimings
        self.firstExcludedCueTiming = firstExcludedCueTiming
        self.startMilliseconds = sortedCueTimings.map(\.startMilliseconds).min() ?? 0
        self.endMilliseconds = sortedCueTimings.map(\.endMilliseconds).max() ?? startMilliseconds
    }

    public func containsCue(startMilliseconds: Int, endMilliseconds: Int) -> Bool {
        cueTimings.contains {
            $0.startMilliseconds == startMilliseconds
                && $0.endMilliseconds == endMilliseconds
        }
    }

    public func cueImmediatelyBefore(startMilliseconds: Int) -> SubtitleCueTiming? {
        cueTimings.last {
            $0.startMilliseconds < startMilliseconds
        }
    }
}

public enum SearchResultPlaybackSequencer {
    public static let minimumSubtitleCount = 1
    public static let maximumSubtitleCount = 999
    public static let continuityWindowMilliseconds = 1_000

    public static func clampedSubtitleCount(_ count: Int) -> Int {
        min(max(count, minimumSubtitleCount), maximumSubtitleCount)
    }

    public static func playbackWindow(
        startMilliseconds: Int,
        endMilliseconds: Int,
        availableCueTimings: [SubtitleCueTiming],
        subtitleCount: Int
    ) -> ResultAutoplayWindow {
        let fallbackTiming = SubtitleCueTiming(
            startMilliseconds: startMilliseconds,
            endMilliseconds: endMilliseconds
        )
        let subtitleCount = clampedSubtitleCount(subtitleCount)
        let normalizedTimings = availableCueTimings
            .filter { $0.startMilliseconds >= startMilliseconds }
            .sorted {
                if $0.startMilliseconds == $1.startMilliseconds {
                    return $0.endMilliseconds < $1.endMilliseconds
                }

                return $0.startMilliseconds < $1.startMilliseconds
            }

        var selectedTimings = [fallbackTiming]
        for timing in normalizedTimings where timing != fallbackTiming {
            guard selectedTimings.count < subtitleCount else {
                break
            }

            selectedTimings.append(timing)
        }

        let firstExcludedCueTiming = normalizedTimings.first {
            !selectedTimings.contains($0)
        }

        return ResultAutoplayWindow(
            cueTimings: selectedTimings,
            firstExcludedCueTiming: firstExcludedCueTiming
        )
    }

    public static func shouldPlayContinuously(
        current: SubtitleSearchResult,
        next: SubtitleSearchResult
    ) -> Bool {
        let currentWindow = playbackWindow(
            startMilliseconds: current.startMilliseconds,
            endMilliseconds: current.endMilliseconds,
            availableCueTimings: [],
            subtitleCount: 1
        )
        return shouldPlayContinuously(
            currentSubtitlePath: current.subtitlePath,
            currentWindow: currentWindow,
            nextSubtitlePath: next.subtitlePath,
            nextStartMilliseconds: next.startMilliseconds,
            nextEndMilliseconds: next.endMilliseconds
        )
    }

    public static func shouldPlayContinuously(
        current: SubtitleSearchResult,
        currentWindow: ResultAutoplayWindow,
        next: SubtitleSearchResult
    ) -> Bool {
        shouldPlayContinuously(
            currentSubtitlePath: current.subtitlePath,
            currentWindow: currentWindow,
            nextSubtitlePath: next.subtitlePath,
            nextStartMilliseconds: next.startMilliseconds,
            nextEndMilliseconds: next.endMilliseconds
        )
    }

    public static func shouldPlayContinuously(
        current: Shiori,
        next: Shiori
    ) -> Bool {
        let currentWindow = playbackWindow(
            startMilliseconds: current.startMilliseconds,
            endMilliseconds: current.endMilliseconds,
            availableCueTimings: [],
            subtitleCount: 1
        )
        return shouldPlayContinuously(
            currentSubtitlePath: current.subtitlePath,
            currentWindow: currentWindow,
            nextSubtitlePath: next.subtitlePath,
            nextStartMilliseconds: next.startMilliseconds,
            nextEndMilliseconds: next.endMilliseconds
        )
    }

    public static func shouldPlayContinuously(
        current: Shiori,
        currentWindow: ResultAutoplayWindow,
        next: Shiori
    ) -> Bool {
        shouldPlayContinuously(
            currentSubtitlePath: current.subtitlePath,
            currentWindow: currentWindow,
            nextSubtitlePath: next.subtitlePath,
            nextStartMilliseconds: next.startMilliseconds,
            nextEndMilliseconds: next.endMilliseconds
        )
    }

    private static func shouldPlayContinuously(
        currentSubtitlePath: String,
        currentWindow: ResultAutoplayWindow,
        nextSubtitlePath: String,
        nextStartMilliseconds: Int,
        nextEndMilliseconds: Int
    ) -> Bool {
        guard subtitleFilename(for: currentSubtitlePath) == subtitleFilename(for: nextSubtitlePath) else {
            return false
        }

        if currentWindow.containsCue(
            startMilliseconds: nextStartMilliseconds,
            endMilliseconds: nextEndMilliseconds
        ) {
            return true
        }

        if let firstExcludedCueTiming = currentWindow.firstExcludedCueTiming,
           firstExcludedCueTiming.startMilliseconds < nextStartMilliseconds {
            return false
        }

        guard let precedingCue = currentWindow.cueImmediatelyBefore(
            startMilliseconds: nextStartMilliseconds
        ) else {
            return false
        }

        let overlapMilliseconds = precedingCue.endMilliseconds - nextStartMilliseconds
        return overlapMilliseconds >= 0 && overlapMilliseconds <= continuityWindowMilliseconds
    }

    private static func subtitleFilename(for path: String) -> String {
        URL(fileURLWithPath: path).lastPathComponent
    }
}
