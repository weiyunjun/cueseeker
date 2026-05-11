import Foundation

public enum SearchResultPlaybackSequencer {
    public static let continuityWindowMilliseconds = 1_000

    public static func shouldPlayContinuously(
        current: SubtitleSearchResult,
        next: SubtitleSearchResult
    ) -> Bool {
        shouldPlayContinuously(
            currentSubtitlePath: current.subtitlePath,
            currentEndMilliseconds: current.endMilliseconds,
            nextSubtitlePath: next.subtitlePath,
            nextStartMilliseconds: next.startMilliseconds
        )
    }

    public static func shouldPlayContinuously(
        current: Shiori,
        next: Shiori
    ) -> Bool {
        shouldPlayContinuously(
            currentSubtitlePath: current.subtitlePath,
            currentEndMilliseconds: current.endMilliseconds,
            nextSubtitlePath: next.subtitlePath,
            nextStartMilliseconds: next.startMilliseconds
        )
    }

    private static func shouldPlayContinuously(
        currentSubtitlePath: String,
        currentEndMilliseconds: Int,
        nextSubtitlePath: String,
        nextStartMilliseconds: Int
    ) -> Bool {
        guard subtitleFilename(for: currentSubtitlePath) == subtitleFilename(for: nextSubtitlePath) else {
            return false
        }

        let overlapMilliseconds = currentEndMilliseconds - nextStartMilliseconds
        return overlapMilliseconds >= 0 && overlapMilliseconds <= continuityWindowMilliseconds
    }

    private static func subtitleFilename(for path: String) -> String {
        URL(fileURLWithPath: path).lastPathComponent
    }
}
