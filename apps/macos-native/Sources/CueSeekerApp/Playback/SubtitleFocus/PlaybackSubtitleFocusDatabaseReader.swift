import CueSeekerCore
import Foundation

enum PlaybackSubtitleFocusShioriWriteResult: Equatable, Sendable {
    case saved
    case alreadySaved
}

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

    func completeCueBatch(
        subtitlePath: String,
        totalCount: Int
    ) throws -> SubtitleFocusCueBatch {
        try Task.checkCancellation()
        let batch = try resolvedDatabase().subtitleFocusCueBatch(
            forSubtitleFile: URL(fileURLWithPath: subtitlePath),
            totalCount: totalCount,
            startingAtOrdinal: 0,
            limit: totalCount
        )
        try Task.checkCancellation()
        return batch
    }

    func saveShiori(
        context: PlaybackSubtitleFocusActionContext,
        videoName: String
    ) throws -> PlaybackSubtitleFocusShioriWriteResult {
        try Task.checkCancellation()
        let database = try resolvedDatabase()
        if try database.shiori(cueID: context.cue.id) != nil {
            try Task.checkCancellation()
            return .alreadySaved
        }

        try Task.checkCancellation()
        do {
            _ = try database.upsertShiori(
                subtitleFile: URL(fileURLWithPath: context.source.subtitlePath),
                subtitleFormat: context.source.subtitleFormat,
                videoFile: URL(fileURLWithPath: context.source.videoPath),
                videoName: videoName,
                selection: context.cueTextSelection
            )
        } catch {
            guard try database.shiori(cueID: context.cue.id) != nil else {
                throw error
            }
        }
        return .saved
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
