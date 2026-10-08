import Foundation

public final class LibraryDatabase: @unchecked Sendable {
    let database: SQLiteDatabase

    public init(
        path: URL,
        access: DatabaseConnectionAccess = .readWrite
    ) throws {
        database = try SQLiteDatabase(path: path, access: access)
    }

    /// Reads and writes through a connection another database object owns, so
    /// that object's transaction can include the Library presentation rows.
    init(sharing database: SQLiteDatabase) {
        self.database = database
    }

    public func libraryVideos(under folders: [URL]) throws -> [LibraryVideo] {
        let pathPrefixes = Self.folderPathPrefixes(for: folders)
        guard !pathPrefixes.isEmpty else {
            return []
        }

        let scopeCondition = pathPrefixes.map { _ in
            "(sf.subtitle_path >= ? AND sf.subtitle_path < ?)"
        }
            .joined(separator: " OR ")
        let statement = try database.prepare(
            """
            SELECT vf.id, sf.id, vf.path, vf.video_name, vf.duration,
                   sf.subtitle_path, sf.format
            FROM subtitle_files sf INDEXED BY idx_subtitle_files_subtitle_path
            JOIN subtitle_video_matches m ON m.subtitle_file_id = sf.id AND m.is_active = 1
            JOIN video_files vf ON vf.id = m.video_file_id
            WHERE (\(scopeCondition))
            ORDER BY vf.path ASC, sf.subtitle_path ASC;
            """
        )

        var bindIndex: Int32 = 1
        for prefix in pathPrefixes {
            try statement.bind(prefix, at: bindIndex)
            bindIndex += 1
            try statement.bind(Self.pathPrefixUpperBound(for: prefix), at: bindIndex)
            bindIndex += 1
        }

        var videosByPath: [String: LibraryVideo] = [:]
        while try statement.step() {
            let video = LibraryVideo(
                videoFileID: statement.int64Column(0),
                subtitleFileID: statement.int64Column(1),
                videoPath: statement.stringColumn(2),
                videoName: statement.stringColumn(3),
                duration: statement.nullableDoubleColumn(4),
                subtitlePath: statement.stringColumn(5),
                subtitleFormat: SubtitleFormat(rawValue: statement.stringColumn(6)) ?? .srt
            )

            if let existing = videosByPath[video.videoPath] {
                if video.subtitlePath.localizedStandardCompare(existing.subtitlePath) == .orderedAscending {
                    videosByPath[video.videoPath] = video
                }
            } else {
                videosByPath[video.videoPath] = video
            }
        }

        return videosByPath.values.sorted(by: Self.libraryVideoSort)
    }

    public func refreshVideoFileMetadata(_ videoFile: URL) throws {
        _ = try upsertVideoFile(videoFile)
    }

    public func updateVideoDuration(videoFile: URL, duration: Double?) throws {
        let normalizedDuration = Self.normalizedDuration(duration)
        try database.withImmediateTransaction {
            let statement = try database.prepare(
                """
                UPDATE video_files
                SET duration = ?,
                    duration_retry_pending = 0
                WHERE path = ?;
                """
            )
            try bind(normalizedDuration, to: statement, at: 1)
            try statement.bind(videoFile.path, at: 2)
            try statement.run()

            try updatePresentationDuration(
                videoFile: videoFile,
                duration: normalizedDuration
            )
        }
    }

    public func updateVideoMetadata(
        videoFile: URL,
        duration: Double?,
        videoWidth: Int?,
        videoHeight: Int?,
        frameRate: Double?,
        videoCodec: String?,
        audioTracks: [VideoAudioTrack]
    ) throws {
        let normalizedDuration = Self.normalizedDuration(duration)
        let encodedAudioTracks = String(
            decoding: try JSONEncoder().encode(audioTracks),
            as: UTF8.self
        )
        try database.withImmediateTransaction {
            let statement = try database.prepare(
                """
                UPDATE video_files
                SET duration = ?,
                    video_width = ?,
                    video_height = ?,
                    frame_rate = ?,
                    video_codec = ?,
                    audio_tracks = ?,
                    duration_retry_pending = 0
                WHERE path = ?;
                """
            )
            try bind(normalizedDuration, to: statement, at: 1)
            try bind(
                videoWidth.flatMap { $0 > 0 ? $0 : nil },
                to: statement,
                at: 2
            )
            try bind(
                videoHeight.flatMap { $0 > 0 ? $0 : nil },
                to: statement,
                at: 3
            )
            try bind(
                frameRate.flatMap {
                    $0.isFinite && $0 > 0 ? $0 : nil
                },
                to: statement,
                at: 4
            )
            let normalizedVideoCodec = videoCodec?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            try bind(
                normalizedVideoCodec?.isEmpty == false
                    ? normalizedVideoCodec
                    : nil,
                to: statement,
                at: 5
            )
            try statement.bind(encodedAudioTracks, at: 6)
            try statement.bind(videoFile.path, at: 7)
            try statement.run()

            try updatePresentationDuration(
                videoFile: videoFile,
                duration: normalizedDuration
            )
        }
    }

    /// Nil when the video is not in the library. A video Index has not
    /// inspected yet has no tracks.
    public func videoAudioTracks(forVideoFile videoFile: URL) throws -> VideoAudioTracks? {
        let statement = try database.prepare(
            """
            SELECT audio_tracks, default_audio_track_index
            FROM video_files
            WHERE path = ?;
            """
        )
        try statement.bind(videoFile.path, at: 1)
        guard try statement.step() else {
            return nil
        }
        let tracks = statement.nullableStringColumn(0)
            .flatMap { try? JSONDecoder().decode([VideoAudioTrack].self, from: Data($0.utf8)) }
            ?? []
        return VideoAudioTracks(tracks: tracks, defaultIndex: statement.intColumn(1))
    }

    public func setDefaultAudioTrackIndex(_ index: Int, forVideoFile videoFile: URL) throws {
        let statement = try database.prepare(
            """
            UPDATE video_files
            SET default_audio_track_index = ?
            WHERE path = ?;
            """
        )
        try statement.bind(max(0, index), at: 1)
        try statement.bind(videoFile.path, at: 2)
        try statement.run()
    }

    public func videoCodec(forVideoPath videoPath: String) -> String? {
        guard let statement = try? database.prepare(
            """
            SELECT vf.video_codec
            FROM video_files vf
            WHERE vf.path = ?;
            """
        ) else {
            return nil
        }
        try? statement.bind(videoPath, at: 1)
        guard (try? statement.step()) == true else {
            return nil
        }
        return statement.nullableStringColumn(0)
    }

    /// The Display Title Index gave the video, read from the database only, so
    /// a file renamed or moved outside the App keeps the title it had. A video
    /// no subtitle matches any more has none.
    public func displayTitle(forVideoFile videoFile: URL) throws -> String? {
        let statement = try database.prepare(
            """
            SELECT vf.display_title
            FROM video_files vf
            WHERE vf.path = ?
              AND EXISTS (
                  SELECT 1
                  FROM subtitle_video_matches m
                  WHERE m.video_file_id = vf.id AND m.is_active = 1
              );
            """
        )
        try statement.bind(videoFile.path, at: 1)
        guard try statement.step() else {
            return nil
        }
        return statement.nullableStringColumn(0)
    }

    public func videoSubtitles(forVideoFile videoFile: URL) throws -> VideoSubtitles? {
        let statement = try database.prepare(
            """
            SELECT vf.default_subtitle_file_id, sf.id, sf.subtitle_path, sf.format
            FROM video_files vf
            LEFT JOIN subtitle_video_matches m
              ON m.video_file_id = vf.id AND m.is_active = 1
            LEFT JOIN subtitle_files sf ON sf.id = m.subtitle_file_id
            WHERE vf.path = ?;
            """
        )
        try statement.bind(videoFile.path, at: 1)
        var found = false
        var defaultSubtitleFileID: Int64?
        var subtitles: [VideoSubtitle] = []
        while try statement.step() {
            found = true
            defaultSubtitleFileID = statement.nullableInt64Column(0)
            if let subtitleFileID = statement.nullableInt64Column(1) {
                subtitles.append(
                    VideoSubtitle(
                        subtitleFileID: subtitleFileID,
                        subtitlePath: statement.stringColumn(2),
                        format: SubtitleFormat(rawValue: statement.stringColumn(3)) ?? .srt
                    )
                )
            }
        }
        guard found else {
            return nil
        }
        return VideoSubtitles(
            videoPath: videoFile.path,
            subtitles: subtitles,
            defaultSubtitleFileID: defaultSubtitleFileID
        )
    }

    public func setDefaultSubtitleFileID(_ subtitleFileID: Int64, forVideoFile videoFile: URL) throws {
        let statement = try database.prepare(
            """
            UPDATE video_files
            SET default_subtitle_file_id = ?
            WHERE path = ?;
            """
        )
        try statement.bind(subtitleFileID, at: 1)
        try statement.bind(videoFile.path, at: 2)
        try statement.run()
    }

    private func updatePresentationDuration(videoFile: URL, duration: Double?) throws {
        let statement = try database.prepare(
            """
            UPDATE library_video_rows
            SET duration = ?
            WHERE video_file_id = (
                SELECT id FROM video_files WHERE path = ?
            );
            """
        )
        try bind(duration, to: statement, at: 1)
        try statement.bind(videoFile.path, at: 2)
        try statement.run()
    }

    private func bind(_ value: Double?, to statement: SQLiteStatement, at index: Int32) throws {
        if let value {
            try statement.bind(value, at: index)
        } else {
            try statement.bindNull(at: index)
        }
    }

    private func bind(_ value: Int?, to statement: SQLiteStatement, at index: Int32) throws {
        if let value {
            try statement.bind(value, at: index)
        } else {
            try statement.bindNull(at: index)
        }
    }

    private func bind(_ value: Int64?, to statement: SQLiteStatement, at index: Int32) throws {
        if let value {
            try statement.bind(value, at: index)
        } else {
            try statement.bindNull(at: index)
        }
    }

    private func bind(_ value: String?, to statement: SQLiteStatement, at index: Int32) throws {
        if let value {
            try statement.bind(value, at: index)
        } else {
            try statement.bindNull(at: index)
        }
    }

    private static func normalizedDuration(_ duration: Double?) -> Double? {
        duration.flatMap { $0.isFinite && $0 >= 0 ? $0 : nil }
    }

    static func folderPathPrefixes(for folders: [URL]) -> [String] {
        Array(Set(folders.flatMap(folderPathPrefixes(for:)))).sorted()
    }

    private static func folderPathPrefixes(for folder: URL) -> [String] {
        var path = normalizedFolderPath(folder.standardizedFileURL.path)
        if !path.hasSuffix("/") {
            path.append("/")
        }
        var prefixes = Set([path])
        if path.hasPrefix("/var/") {
            prefixes.insert("/private" + path)
        } else if path.hasPrefix("/private/var/") {
            prefixes.insert(String(path.dropFirst("/private".count)))
        }
        return prefixes.sorted()
    }

    private static func normalizedFolderPath(_ path: String) -> String {
        var path = path
        while path.count > 1 && path.hasSuffix("/") {
            path.removeLast()
        }
        return path
    }

    static func pathPrefixUpperBound(for prefix: String) -> String {
        prefix + "\u{10FFFF}"
    }

    static func libraryVideoSort(_ lhs: LibraryVideo, _ rhs: LibraryVideo) -> Bool {
        let lhsFolder = URL(fileURLWithPath: lhs.videoPath)
            .deletingLastPathComponent()
            .lastPathComponent
        let rhsFolder = URL(fileURLWithPath: rhs.videoPath)
            .deletingLastPathComponent()
            .lastPathComponent
        let folderComparison = lhsFolder.localizedStandardCompare(rhsFolder)
        if folderComparison != .orderedSame {
            return folderComparison == .orderedAscending
        }
        let nameComparison = lhs.videoName.localizedStandardCompare(rhs.videoName)
        if nameComparison != .orderedSame {
            return nameComparison == .orderedAscending
        }
        return lhs.videoPath.localizedStandardCompare(rhs.videoPath) == .orderedAscending
    }
}

extension LibraryDatabase {
    public func libraryPlaybackHistory(forVideoFile videoFile: URL) throws -> LibraryPlaybackHistory? {
        let videoFileID = try videoFileID(for: videoFile)
        let statement = try database.prepare(
            """
            SELECT vf.path,
                   h.position_ms, h.duration,
                   CASE
                       WHEN ws.state = 'finished' THEN COALESCE(h.started_at, ws.updated_at)
                       WHEN ws.state = 'watching' THEN COALESCE(h.started_at, ws.updated_at)
                       WHEN ws.state = 'unwatched' THEN NULL
                       ELSE h.started_at
                   END,
                   CASE
                       WHEN ws.state = 'finished' THEN ws.updated_at
                       WHEN ws.state = 'watching' THEN NULL
                       WHEN ws.state = 'unwatched' THEN NULL
                       ELSE h.completed_at
                   END,
                   h.updated_at
            FROM library_playback_history h
            JOIN video_files vf ON vf.id = h.video_file_id
            LEFT JOIN library_watch_states ws ON ws.video_file_id = h.video_file_id
            WHERE h.video_file_id = ?;
            """
        )
        guard let videoFileID else {
            return nil
        }
        try statement.bind(videoFileID, at: 1)

        guard try statement.step() else {
            return nil
        }
        return LibraryPlaybackHistory(
            videoPath: statement.stringColumn(0),
            positionMilliseconds: max(0, statement.intColumn(1)),
            duration: statement.nullableDoubleColumn(2),
            startedAt: statement.nullableStringColumn(3),
            completedAt: statement.nullableStringColumn(4),
            updatedAt: statement.stringColumn(5)
        )
    }

    public func upsertLibraryPlaybackHistory(
        videoFile: URL,
        positionMilliseconds: Int,
        duration: Double?,
        updatedAt: Date = Date(),
        markStarted: Bool = true,
        markCompleted: Bool = false
    ) throws {
        guard let videoFileID = try upsertVideoFile(videoFile) else {
            return
        }
        let updatedAtString = Self.playbackHistoryTimestamp(from: updatedAt)
        let normalizedDuration = duration.flatMap { value in
            value.isFinite && value > 0 ? value : nil
        }
        let startedAt = markStarted || markCompleted ? updatedAtString : nil
        let completedAt = markCompleted ? updatedAtString : nil
        let statement = try database.prepare(
            """
            INSERT INTO library_playback_history(
                video_file_id, position_ms, duration,
                started_at, completed_at, updated_at
            )
            VALUES (?, ?, ?, ?, ?, ?)
            ON CONFLICT(video_file_id) DO UPDATE SET
                position_ms = excluded.position_ms,
                duration = excluded.duration,
                started_at = COALESCE(library_playback_history.started_at, excluded.started_at),
                completed_at = COALESCE(library_playback_history.completed_at, excluded.completed_at),
                updated_at = excluded.updated_at;
            """
        )
        try statement.bind(videoFileID, at: 1)
        try statement.bind(max(0, positionMilliseconds), at: 2)
        try bind(normalizedDuration, to: statement, at: 3)
        try bind(startedAt, to: statement, at: 4)
        try bind(completedAt, to: statement, at: 5)
        try statement.bind(updatedAtString, at: 6)
        try statement.run()

        if markCompleted {
            try upsertLibraryWatchState(videoFile: videoFile, state: .finished, updatedAt: updatedAt)
        } else if markStarted {
            let currentWatchState = try libraryPlaybackHistory(forVideoFile: videoFile).map {
                LibraryWatchState(
                    positionMilliseconds: $0.positionMilliseconds,
                    duration: $0.duration,
                    startedAt: $0.startedAt,
                    completedAt: $0.completedAt
                )
            } ?? .unwatched
            if currentWatchState != .finished {
                try upsertLibraryWatchState(videoFile: videoFile, state: .watching, updatedAt: updatedAt)
            }
        }
    }

    public func setLibraryWatchState(
        videoFile: URL,
        duration _: Double?,
        state: LibraryWatchState,
        updatedAt: Date = Date()
    ) throws {
        try upsertLibraryWatchState(videoFile: videoFile, state: state, updatedAt: updatedAt)
    }

    private func upsertLibraryWatchState(
        videoFile: URL,
        state: LibraryWatchState,
        updatedAt: Date
    ) throws {
        try database.withImmediateTransaction {
            guard let videoFileID = try upsertVideoFile(videoFile) else {
                return
            }
            let previousState = try database.prepare(
                "SELECT state FROM library_watch_states WHERE video_file_id = ?;"
            )
            try previousState.bind(videoFileID, at: 1)
            let previousValue = try previousState.step()
                ? LibraryWatchState(rawValue: previousState.stringColumn(0)) ?? .unwatched
                : .unwatched

            let statement = try database.prepare(
                """
                INSERT INTO library_watch_states(video_file_id, state, updated_at)
                VALUES (?, ?, ?)
                ON CONFLICT(video_file_id) DO UPDATE SET
                    state = excluded.state,
                    updated_at = excluded.updated_at;
                """
            )
            try statement.bind(videoFileID, at: 1)
            try statement.bind(state.rawValue, at: 2)
            try statement.bind(Self.playbackHistoryTimestamp(from: updatedAt), at: 3)
            try statement.run()

            if previousValue != state {
                try CueFacetCountCache.rebuildWatchStates(on: database)
            }
        }
    }

    private func upsertVideoFile(_ videoFile: URL) throws -> Int64? {
        let existingVideoFileID = try videoFileID(for: videoFile)
        let pathIdentity = try mediaPathIdentity(for: videoFile)
        if existingVideoFileID == nil, pathIdentity == nil, try hasSearchPaths() {
            return nil
        }
        let attributes = try? FileManager.default.attributesOfItem(atPath: videoFile.path)
        let fileSize = (attributes?[.size] as? NSNumber)?.int64Value
        let modifiedAt = attributes?[.modificationDate] as? Date
        let statement = try database.prepare(
            """
            INSERT INTO video_files(
                library_id, relative_path, path, video_name, file_size, modified_at
            )
            VALUES (?, ?, ?, ?, ?, ?)
            ON CONFLICT(path) DO UPDATE SET
                library_id = excluded.library_id,
                relative_path = excluded.relative_path,
                video_name = excluded.video_name,
                file_size = excluded.file_size,
                modified_at = excluded.modified_at
            RETURNING id;
            """
        )
        try bind(pathIdentity?.libraryID, to: statement, at: 1)
        try bind(pathIdentity?.relativePath, to: statement, at: 2)
        try statement.bind(videoFile.path, at: 3)
        try statement.bind(videoFile.lastPathComponent, at: 4)
        if let fileSize {
            try statement.bind(fileSize, at: 5)
        } else {
            try statement.bindNull(at: 5)
        }
        if let modifiedAt {
            try statement.bind(modifiedAt.timeIntervalSince1970, at: 6)
        } else {
            try statement.bindNull(at: 6)
        }
        guard try statement.step() else {
            return database.lastInsertRowID()
        }
        return statement.int64Column(0)
    }

    private func hasSearchPaths() throws -> Bool {
        let statement = try database.prepare("SELECT 1 FROM search_paths LIMIT 1;")
        return try statement.step()
    }

    private func videoFileID(for videoFile: URL) throws -> Int64? {
        let statement = try database.prepare(
            """
            SELECT id
            FROM video_files
            WHERE path = ?;
            """
        )
        try statement.bind(videoFile.path, at: 1)
        return try statement.step() ? statement.int64Column(0) : nil
    }

    private func mediaPathIdentity(
        for file: URL
    ) throws -> (libraryID: Int64, relativePath: String)? {
        let statement = try database.prepare(
            """
            SELECT id, path
            FROM search_paths
            ORDER BY LENGTH(path) DESC, id ASC;
            """
        )
        while try statement.step() {
            let libraryID = statement.int64Column(0)
            let root = URL(fileURLWithPath: statement.stringColumn(1)).standardizedFileURL
            if let relativePath = Self.relativeMediaPath(for: file, under: root) {
                return (libraryID, relativePath)
            }
        }
        return nil
    }

    private static func relativeMediaPath(for file: URL, under root: URL) -> String? {
        let rootPath = normalizedFolderPath(root.standardizedFileURL.path)
        let filePath = file.standardizedFileURL.path
        let prefix = rootPath == "/" ? rootPath : rootPath + "/"
        guard filePath.hasPrefix(prefix) else {
            return nil
        }
        let relativePath = String(filePath.dropFirst(prefix.count))
            .precomposedStringWithCanonicalMapping
        return relativePath.isEmpty ? nil : relativePath
    }

    private static func playbackHistoryTimestamp(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}
