import Foundation

public enum SearchResultPlaybackSequencer {
    public static let continuityWindowMilliseconds = 1_000

    public static func shouldPlayContinuously(
        current: SubtitleSearchResult,
        next: SubtitleSearchResult
    ) -> Bool {
        guard subtitleFilename(for: current.subtitlePath) == subtitleFilename(for: next.subtitlePath) else {
            return false
        }

        let overlapMilliseconds = current.endMilliseconds - next.startMilliseconds
        return overlapMilliseconds >= 0 && overlapMilliseconds <= continuityWindowMilliseconds
    }

    private static func subtitleFilename(for path: String) -> String {
        URL(fileURLWithPath: path).lastPathComponent
    }
}
