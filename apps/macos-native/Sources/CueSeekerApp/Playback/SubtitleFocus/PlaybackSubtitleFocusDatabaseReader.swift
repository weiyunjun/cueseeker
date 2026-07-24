import CueSeekerCore
import Foundation

enum PlaybackSubtitleFocusShioriWriteResult: Equatable, Sendable {
    case saved(listID: Int64, uniqueCueCount: Int)
    case alreadySaved
}

actor PlaybackSubtitleFocusDatabaseReader {
    private let databaseURL: URL
    private var playbackDatabase: PlaybackSubtitleDatabase?
    private var shioriDatabase: ShioriDatabase?

    init(databaseURL: URL) {
        self.databaseURL = databaseURL
    }

    func initialSnapshot(
        subtitlePath: String,
        timestampMilliseconds: Int
    ) throws -> SubtitleFocusSnapshot? {
        try Task.checkCancellation()
        let snapshot = try resolvedPlaybackDatabase().subtitleFocusInitialSnapshot(
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
        let batch = try resolvedPlaybackDatabase().subtitleFocusCueBatch(
            forSubtitleFile: URL(fileURLWithPath: subtitlePath),
            totalCount: totalCount,
            startingAtOrdinal: 0,
            limit: totalCount
        )
        try Task.checkCancellation()
        return batch
    }

    func saveShiori(
        context: PlaybackSubtitleFocusActionContext
    ) throws -> PlaybackSubtitleFocusShioriWriteResult {
        try Task.checkCancellation()
        let database = try resolvedShioriDatabase()
        guard let listID = try database.firstShioriListID() else {
            throw SQLiteDatabaseError.stepFailed(
                "Shiori requires a destination list"
            )
        }
        if try database.shiori(cueID: context.cue.id, listID: listID) != nil {
            try Task.checkCancellation()
            return .alreadySaved
        }

        try Task.checkCancellation()
        do {
            _ = try database.upsertShiori(
                selection: context.cueTextSelection,
                listID: listID
            )
        } catch {
            guard try database.shiori(
                cueID: context.cue.id,
                listID: listID
            ) != nil else {
                throw error
            }
        }
        return .saved(
            listID: listID,
            uniqueCueCount: try database.uniqueShioriCueCount()
        )
    }

    private func resolvedPlaybackDatabase() throws -> PlaybackSubtitleDatabase {
        if let playbackDatabase {
            return playbackDatabase
        }
        let database = try PlaybackSubtitleDatabase(path: databaseURL)
        playbackDatabase = database
        return database
    }

    private func resolvedShioriDatabase() throws -> ShioriDatabase {
        if let shioriDatabase {
            return shioriDatabase
        }
        let database = try ShioriDatabase(path: databaseURL)
        shioriDatabase = database
        return database
    }
}
