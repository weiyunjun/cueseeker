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

    func isShioriSaved(
        context: PlaybackSubtitleFocusActionContext
    ) throws -> Bool {
        try Task.checkCancellation()
        let saved = try resolvedDatabase().shiori(
            subtitleFile: URL(fileURLWithPath: context.source.subtitlePath),
            startMilliseconds: context.cue.startMilliseconds,
            endMilliseconds: context.cue.endMilliseconds
        ) != nil
        try Task.checkCancellation()
        return saved
    }

    func saveShiori(
        context: PlaybackSubtitleFocusActionContext,
        videoName: String
    ) throws -> PlaybackSubtitleFocusShioriWriteResult {
        try Task.checkCancellation()
        let database = try resolvedDatabase()
        let subtitleFile = URL(fileURLWithPath: context.source.subtitlePath)
        if try database.shiori(
            subtitleFile: subtitleFile,
            startMilliseconds: context.cue.startMilliseconds,
            endMilliseconds: context.cue.endMilliseconds
        ) != nil {
            try Task.checkCancellation()
            return .alreadySaved
        }

        try Task.checkCancellation()
        do {
            _ = try database.upsertShiori(
                subtitleFile: subtitleFile,
                subtitleFormat: context.source.subtitleFormat,
                videoFile: URL(fileURLWithPath: context.source.videoPath),
                videoName: videoName,
                selection: context.cueTextSelection
            )
        } catch {
            guard try database.shiori(
                subtitleFile: subtitleFile,
                startMilliseconds: context.cue.startMilliseconds,
                endMilliseconds: context.cue.endMilliseconds
            ) != nil else {
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
