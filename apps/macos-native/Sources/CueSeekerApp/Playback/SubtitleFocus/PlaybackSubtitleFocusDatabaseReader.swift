import CueSeekerCore
import Foundation

actor PlaybackSubtitleFocusDatabaseReader {
    private let databaseURL: URL
    private var playbackDatabase: PlaybackSubtitleDatabase?

    init(databaseURL: URL) {
        self.databaseURL = databaseURL
    }

    func initialSnapshot(
        subtitleFileID: Int64,
        timestampMilliseconds: Int
    ) throws -> SubtitleFocusSnapshot? {
        try Task.checkCancellation()
        let snapshot = try resolvedPlaybackDatabase().subtitleFocusInitialSnapshot(
            forSubtitleFileID: subtitleFileID,
            atMilliseconds: timestampMilliseconds
        )
        try Task.checkCancellation()
        return snapshot
    }

    func completeCueBatch(
        subtitleFileID: Int64,
        totalCount: Int
    ) throws -> SubtitleFocusCueBatch {
        try Task.checkCancellation()
        let batch = try resolvedPlaybackDatabase().subtitleFocusCueBatch(
            forSubtitleFileID: subtitleFileID,
            totalCount: totalCount,
            startingAtOrdinal: 0,
            limit: totalCount
        )
        try Task.checkCancellation()
        return batch
    }

    private func resolvedPlaybackDatabase() throws -> PlaybackSubtitleDatabase {
        if let playbackDatabase {
            return playbackDatabase
        }
        let database = try PlaybackSubtitleDatabase(path: databaseURL)
        playbackDatabase = database
        return database
    }
}
