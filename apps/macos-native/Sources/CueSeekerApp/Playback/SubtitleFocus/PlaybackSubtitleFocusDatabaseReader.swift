import CueSeekerCore
import Foundation

actor PlaybackSubtitleFocusDatabaseReader {
    private let databaseURL: URL
    private var database: SubtitleDatabase?

    init(databaseURL: URL) {
        self.databaseURL = databaseURL
    }

    func initialSnapshot(
        subtitlePath: String,
        timestampMilliseconds: Int
    ) throws -> SubtitleFocusSnapshot? {
        try Task.checkCancellation()
        let snapshot = try resolvedDatabase().subtitleFocusInitialSnapshot(
            forSubtitleFile: URL(fileURLWithPath: subtitlePath),
            atMilliseconds: timestampMilliseconds
        )
        try Task.checkCancellation()
        return snapshot
    }

    func cueBatch(
        subtitlePath: String,
        request: PlaybackSubtitleFocusWindowLoadRequest
    ) throws -> SubtitleFocusCueBatch {
        try Task.checkCancellation()
        let batch = try resolvedDatabase().subtitleFocusCueBatch(
            forSubtitleFile: URL(fileURLWithPath: subtitlePath),
            totalCount: request.intent.totalCount,
            startingAtOrdinal: request.intent.range.lowerBound,
            limit: request.intent.range.count
        )
        try Task.checkCancellation()
        return batch
    }

    private func resolvedDatabase() throws -> SubtitleDatabase {
        if let database {
            return database
        }
        let database = try SubtitleDatabase(path: databaseURL)
        self.database = database
        return database
    }
}
