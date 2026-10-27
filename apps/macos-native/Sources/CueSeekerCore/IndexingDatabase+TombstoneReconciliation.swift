import Foundation

extension IndexingDatabase {
    struct StoredCueState {
        let identity: StoredCueIdentity
    }

    func snapshotVideoTombstoneIfNeeded(videoFileID: Int64) throws {
        let select = try database.prepare(
            """
            SELECT
                vf.path,
                vf.duration,
                COALESCE(vf.default_audio_track_index, 0),
                COALESCE(h.position_ms, 0),
                h.duration,
                COALESCE(
                    ws.state,
                    CASE
                        WHEN COALESCE(h.position_ms, 0) > 0 THEN 'watching'
                        ELSE 'unwatched'
                    END
                ),
                uvc.display_cover_path
            FROM video_files vf
            LEFT JOIN library_playback_history h ON h.video_file_id = vf.id
            LEFT JOIN library_watch_states ws ON ws.video_file_id = vf.id
            LEFT JOIN user_video_covers uvc ON uvc.video_file_id = vf.id
            WHERE vf.id = ?
            LIMIT 1;
            """
        )
        try select.bind(videoFileID, at: 1)
        guard try select.step() else {
            return
        }

        let videoPath = select.stringColumn(0)
        let videoDuration = select.nullableDoubleColumn(1)
        let defaultAudioTrackIndex = select.intColumn(2)
        let positionMilliseconds = max(0, select.intColumn(3))
        let historyDuration = select.nullableDoubleColumn(4)
        let watchState = select.stringColumn(5)
        let userCoverPath = select.nullableStringColumn(6).flatMap { $0.isEmpty ? nil : $0 }

        let hasUserAccumulatedState =
            positionMilliseconds > 0
            || watchState != LibraryWatchState.unwatched.rawValue
            || userCoverPath != nil
            || defaultAudioTrackIndex > 0
        guard hasUserAccumulatedState else {
            return
        }

        let now = ISO8601DateFormatter().string(from: Date())
        let upsert = try database.prepare(
            """
            INSERT INTO video_tombstones(
                video_path,
                position_ms,
                duration,
                watch_state,
                user_cover_path,
                default_audio_track_index,
                tombstoned_at,
                updated_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(video_path) DO UPDATE SET
                position_ms = excluded.position_ms,
                duration = excluded.duration,
                watch_state = excluded.watch_state,
                user_cover_path = excluded.user_cover_path,
                default_audio_track_index = excluded.default_audio_track_index,
                tombstoned_at = excluded.tombstoned_at,
                updated_at = excluded.updated_at;
            """
        )
        try upsert.bind(videoPath, at: 1)
        try upsert.bind(positionMilliseconds, at: 2)
        try bindOptional(videoDuration ?? historyDuration, to: upsert, at: 3)
        try upsert.bind(watchState, at: 4)
        try bindOptional(userCoverPath, to: upsert, at: 5)
        try upsert.bind(defaultAudioTrackIndex, at: 6)
        try upsert.bind(now, at: 7)
        try upsert.bind(now, at: 8)
        try upsert.run()
    }

    func restoreVideoTombstoneIfNeeded(
        forVideoFile videoFile: URL,
        videoFileID: Int64
    ) throws {
        let pathVariants = Self.folderPathVariants(for: videoFile).sorted()
        guard !pathVariants.isEmpty else {
            return
        }
        let placeholders = pathVariants.map { _ in "?" }.joined(separator: ", ")
        let select = try database.prepare(
            """
            SELECT
                position_ms,
                duration,
                watch_state,
                user_cover_path,
                default_audio_track_index,
                updated_at
            FROM video_tombstones
            WHERE video_path IN (\(placeholders))
            ORDER BY CASE WHEN video_path = ? THEN 0 ELSE 1 END, updated_at DESC
            LIMIT 1;
            """
        )
        for (offset, variant) in pathVariants.enumerated() {
            try select.bind(variant, at: Int32(offset + 1))
        }
        try select.bind(videoFile.mediaPath, at: Int32(pathVariants.count + 1))
        guard try select.step() else {
            return
        }

        let positionMilliseconds = max(0, select.intColumn(0))
        let tombstoneDuration = select.nullableDoubleColumn(1)
        let watchState = select.stringColumn(2)
        let userCoverPath = select.nullableStringColumn(3).flatMap { $0.isEmpty ? nil : $0 }
        let defaultAudioTrackIndex = max(0, select.intColumn(4))
        let tombstoneUpdatedAt = select.stringColumn(5)

        if defaultAudioTrackIndex > 0 {
            let updateAudioTrack = try database.prepare(
                """
                UPDATE video_files
                SET default_audio_track_index = ?
                WHERE id = ?;
                """
            )
            try updateAudioTrack.bind(defaultAudioTrackIndex, at: 1)
            try updateAudioTrack.bind(videoFileID, at: 2)
            try updateAudioTrack.run()
        }

        if let userCoverPath {
            let upsertCover = try database.prepare(
                """
                INSERT INTO user_video_covers(video_file_id, display_cover_path, updated_at)
                VALUES (?, ?, ?)
                ON CONFLICT(video_file_id) DO UPDATE SET
                    display_cover_path = excluded.display_cover_path,
                    updated_at = excluded.updated_at;
                """
            )
            try upsertCover.bind(videoFileID, at: 1)
            try upsertCover.bind(userCoverPath, at: 2)
            try upsertCover.bind(tombstoneUpdatedAt, at: 3)
            try upsertCover.run()
        }

        let durationStatement = try database.prepare(
            "SELECT duration FROM video_files WHERE id = ? LIMIT 1;"
        )
        try durationStatement.bind(videoFileID, at: 1)
        let currentVideoDuration: Double? = try durationStatement.step()
            ? durationStatement.nullableDoubleColumn(0)
            : nil

        let shouldResetForShorterDuration: Bool = {
            guard let currentVideoDuration, currentVideoDuration > 0 else {
                return false
            }
            let durationMilliseconds = Int((currentVideoDuration * 1_000).rounded(.down))
            return positionMilliseconds > durationMilliseconds
        }()

        if !shouldResetForShorterDuration {
            if watchState != LibraryWatchState.unwatched.rawValue {
                let upsertWatchState = try database.prepare(
                    """
                    INSERT INTO library_watch_states(video_file_id, state, updated_at)
                    VALUES (?, ?, ?)
                    ON CONFLICT(video_file_id) DO UPDATE SET
                        state = excluded.state,
                        updated_at = excluded.updated_at;
                    """
                )
                try upsertWatchState.bind(videoFileID, at: 1)
                try upsertWatchState.bind(watchState, at: 2)
                try upsertWatchState.bind(tombstoneUpdatedAt, at: 3)
                try upsertWatchState.run()
            }

            if positionMilliseconds > 0 {
                let startedAt: String? =
                    watchState == LibraryWatchState.unwatched.rawValue ? nil : tombstoneUpdatedAt
                let completedAt: String? =
                    watchState == LibraryWatchState.finished.rawValue ? tombstoneUpdatedAt : nil
                let upsertHistory = try database.prepare(
                    """
                    INSERT INTO library_playback_history(
                        video_file_id,
                        position_ms,
                        duration,
                        started_at,
                        completed_at,
                        updated_at
                    )
                    VALUES (?, ?, ?, ?, ?, '')
                    ON CONFLICT(video_file_id) DO UPDATE SET
                        position_ms = excluded.position_ms,
                        duration = excluded.duration,
                        started_at = excluded.started_at,
                        completed_at = excluded.completed_at,
                        updated_at = excluded.updated_at;
                    """
                )
                try upsertHistory.bind(videoFileID, at: 1)
                try upsertHistory.bind(positionMilliseconds, at: 2)
                try bindOptional(currentVideoDuration ?? tombstoneDuration, to: upsertHistory, at: 3)
                try bindOptional(startedAt, to: upsertHistory, at: 4)
                try bindOptional(completedAt, to: upsertHistory, at: 5)
                try upsertHistory.run()
            }
        }

        let deleteTombstone = try database.prepare(
            "DELETE FROM video_tombstones WHERE video_path IN (\(placeholders));"
        )
        for (offset, variant) in pathVariants.enumerated() {
            try deleteTombstone.bind(variant, at: Int32(offset + 1))
        }
        try deleteTombstone.run()
    }

    func reconcileExcerptListRecentCues() throws {
        let selectLists = try database.prepare(
            """
            SELECT el.id
            FROM excerpt_lists el
            WHERE el.recent_played_at IS NOT NULL
              AND (
                  el.recent_cue_id IS NULL
                  OR NOT EXISTS (
                      SELECT 1
                      FROM excerpts s
                      JOIN subtitle_cue_lines l ON l.id = s.cue_id
                      JOIN subtitle_files sf ON sf.id = l.subtitle_file_id
                      JOIN subtitle_video_matches m
                        ON m.subtitle_file_id = sf.id
                       AND m.is_active = 1
                      JOIN video_files vf ON vf.id = m.video_file_id
                      WHERE s.list_id = el.id
                        AND s.cue_id = el.recent_cue_id
                  )
              )
            ORDER BY el.id ASC;
            """
        )
        var listIDs: [Int64] = []
        while try selectLists.step() {
            listIDs.append(selectLists.int64Column(0))
        }
        guard !listIDs.isEmpty else {
            return
        }

        let selectFirstPlayableCue = try database.prepare(
            """
            SELECT s.cue_id
            FROM excerpts s
            JOIN subtitle_cue_lines l ON l.id = s.cue_id
            JOIN subtitle_files sf ON sf.id = l.subtitle_file_id
            JOIN subtitle_video_matches m
              ON m.subtitle_file_id = sf.id
             AND m.is_active = 1
            JOIN video_files vf ON vf.id = m.video_file_id
            WHERE s.list_id = ?
            ORDER BY s.created_at ASC, s.id ASC
            LIMIT 1;
            """
        )
        let updateFallback = try database.prepare(
            "UPDATE excerpt_lists SET recent_cue_id = ? WHERE id = ?;"
        )
        let clearRecent = try database.prepare(
            """
            UPDATE excerpt_lists
            SET recent_cue_id = NULL,
                recent_sort_order = NULL,
                recent_played_at = NULL
            WHERE id = ?;
            """
        )

        for listID in listIDs {
            try selectFirstPlayableCue.bind(listID, at: 1)
            let fallbackCueID: Int64? = try selectFirstPlayableCue.step()
                ? selectFirstPlayableCue.int64Column(0)
                : nil
            try selectFirstPlayableCue.reset()

            if let fallbackCueID {
                try updateFallback.bind(fallbackCueID, at: 1)
                try updateFallback.bind(listID, at: 2)
                try updateFallback.run()
                try updateFallback.reset()
            } else {
                try clearRecent.bind(listID, at: 1)
                try clearRecent.run()
                try clearRecent.reset()
            }
        }
    }

    func adoptTombstones(
        forSubtitleFile subtitleFile: URL,
        subtitleFileID: Int64
    ) throws {
        let pathVariants = Self.folderPathVariants(for: subtitleFile).sorted()
        guard !pathVariants.isEmpty else {
            return
        }
        let placeholders = pathVariants.map { _ in "?" }.joined(separator: ", ")
        let statement = try database.prepare(
            """
            UPDATE cue_tombstones
            SET subtitle_file_id = ?,
                subtitle_path = ?
            WHERE subtitle_path IN (\(placeholders));
            """
        )
        try statement.bind(subtitleFileID, at: 1)
        try statement.bind(subtitleFile.mediaPath, at: 2)
        for (offset, variant) in pathVariants.enumerated() {
            try statement.bind(variant, at: Int32(offset + 3))
        }
        try statement.run()
    }

    func reconcileDetachedTombstoneUnavailableReasons(
        folderPathPrefixes: [String],
        missingVideoVariants: Set<String>,
        defaultUnavailableReason: ExcerptUnavailableReason
    ) throws -> Set<String> {
        guard !folderPathPrefixes.isEmpty else {
            return []
        }
        let prefixCondition = folderPathPrefixes
            .map { _ in "substr(t.subtitle_path, 1, ?) = ?" }
            .joined(separator: " OR ")
        let select = try database.prepare(
            """
            SELECT t.cue_id, t.subtitle_path, t.unavailable_reason
            FROM cue_tombstones t
            WHERE (\(prefixCondition))
              AND NOT EXISTS (
                  SELECT 1
                  FROM subtitle_files sf
                  WHERE sf.id = t.subtitle_file_id
              )
              AND t.unavailable_reason != 'cue_missing'
            ORDER BY t.cue_id ASC;
            """
        )
        var bindIndex: Int32 = 1
        for prefix in folderPathPrefixes {
            try select.bind(prefix.unicodeScalars.count, at: bindIndex)
            bindIndex += 1
            try select.bind(prefix, at: bindIndex)
            bindIndex += 1
        }
        var updates: [(cueID: Int64, subtitlePath: String, newReason: String)] = []
        while try select.step() {
            let cueID = select.int64Column(0)
            let subtitlePath = select.stringColumn(1)
            let currentReason = select.stringColumn(2)
            let targetReason: ExcerptUnavailableReason =
                missingVideoVariants.contains(subtitlePath)
                ? .videoMissing
                : defaultUnavailableReason
            if currentReason != targetReason.rawValue {
                updates.append((cueID, subtitlePath, targetReason.rawValue))
            }
        }
        guard !updates.isEmpty else {
            return []
        }
        let now = ISO8601DateFormatter().string(from: Date())
        let updateStatement = try database.prepare(
            """
            UPDATE cue_tombstones
            SET unavailable_reason = ?,
                updated_at = ?
            WHERE cue_id = ?;
            """
        )
        var affectedFolders = Set<String>()
        for update in updates {
            try updateStatement.bind(update.newReason, at: 1)
            try updateStatement.bind(now, at: 2)
            try updateStatement.bind(update.cueID, at: 3)
            try updateStatement.run()
            try updateStatement.reset()
            affectedFolders.insert(
                Self.folderPath(forSubtitlePath: update.subtitlePath)
            )
        }
        return affectedFolders
    }

    func hasActiveSubtitleMatch(videoFileID: Int64) throws -> Bool {
        let statement = try database.prepare(
            """
            SELECT 1
            FROM subtitle_video_matches m
            JOIN subtitle_files sf ON sf.id = m.subtitle_file_id
            WHERE m.video_file_id = ? AND m.is_active = 1
            LIMIT 1;
            """
        )
        try statement.bind(videoFileID, at: 1)
        return try statement.step()
    }

    func storedCueStates(subtitleFileID: Int64) throws -> [StoredCueState] {
        let statement = try database.prepare(
            """
            SELECT l.id, l.source_format, l.source_style,
                   l.source_identity_remainder, l.start_ms, l.end_ms,
                   l.content
            FROM subtitle_cue_lines l
            WHERE l.subtitle_file_id = ?
            ORDER BY l.id ASC;
            """
        )
        try statement.bind(subtitleFileID, at: 1)

        var stateByCueID: [Int64: StoredCueState] = [:]
        while try statement.step() {
            let cueID = statement.int64Column(0)
            stateByCueID[cueID] = StoredCueState(
                identity: StoredCueIdentity(
                    cueID: cueID,
                    sourceFormat: SubtitleFormat(
                        rawValue: statement.stringColumn(1)
                    ) ?? .srt,
                    sourceStyle: statement.nullableStringColumn(2),
                    sourceIdentityRemainder: statement.stringColumn(3),
                    startMilliseconds: statement.intColumn(4),
                    endMilliseconds: statement.intColumn(5),
                    content: statement.stringColumn(6)
                )
            )
        }

        let tombstones = try database.prepare(
            """
            SELECT cue_id, source_format, source_style,
                   source_identity_remainder, start_ms, end_ms, content
            FROM cue_tombstones
            WHERE subtitle_file_id = ?
            ORDER BY cue_id ASC;
            """
        )
        try tombstones.bind(subtitleFileID, at: 1)
        while try tombstones.step() {
            let cueID = tombstones.int64Column(0)
            guard stateByCueID[cueID] == nil else {
                continue
            }
            stateByCueID[cueID] = StoredCueState(
                identity: StoredCueIdentity(
                    cueID: cueID,
                    sourceFormat: SubtitleFormat(
                        rawValue: tombstones.stringColumn(1)
                    ) ?? .srt,
                    sourceStyle: tombstones.nullableStringColumn(2),
                    sourceIdentityRemainder: tombstones.stringColumn(3),
                    startMilliseconds: tombstones.intColumn(4),
                    endMilliseconds: tombstones.intColumn(5),
                    content: tombstones.stringColumn(6)
                )
            )
        }

        return stateByCueID.values.sorted {
            $0.identity.cueID < $1.identity.cueID
        }
    }

    func snapshotReferencedCues(
        subtitleFileID: Int64,
        unavailableReason: ExcerptUnavailableReason
    ) throws {
        let now = ISO8601DateFormatter().string(from: Date())
        let statement = try database.prepare(
            """
            INSERT INTO cue_tombstones(
                cue_id,
                subtitle_file_id,
                source_format,
                source_style,
                source_identity_remainder,
                start_time,
                end_time,
                start_ms,
                end_ms,
                duration_ms,
                character_width,
                content,
                cue_group_content,
                display_title,
                subtitle_path,
                video_path,
                unavailable_reason,
                tombstoned_at,
                updated_at
            )
            SELECT l.id,
                   l.subtitle_file_id,
                   l.source_format,
                   l.source_style,
                   l.source_identity_remainder,
                   l.start_time,
                   l.end_time,
                   l.start_ms,
                   l.end_ms,
                   l.duration_ms,
                   l.character_width,
                   l.content,
                   COALESCE(
                     (
                       SELECT GROUP_CONCAT(ordered.content, char(31))
                       FROM (
                         SELECT group_cue.content
                         FROM subtitle_cue_lines group_cue
                         WHERE group_cue.cue_group_id = l.cue_group_id
                         ORDER BY group_cue.display_order ASC,
                                  group_cue.event_index ASC,
                                  group_cue.id ASC
                       ) ordered
                     ),
                     l.content
                   ),
                   \(SubtitleDisplayTitleResolver.matchedVideoDisplayTitleSQL(subtitleFileID: "sf.id")),
                   sf.subtitle_path,
                   vf.path,
                   ?,
                   ?,
                   ?
            FROM subtitle_cue_lines l
            JOIN excerpts s ON s.cue_id = l.id
            JOIN subtitle_cue_groups g ON g.id = l.cue_group_id
            JOIN subtitle_files sf ON sf.id = l.subtitle_file_id
            LEFT JOIN subtitle_video_matches m
              ON m.subtitle_file_id = sf.id AND m.is_active = 1
            LEFT JOIN video_files vf ON vf.id = m.video_file_id
            WHERE l.subtitle_file_id = ?
            ON CONFLICT(cue_id) DO UPDATE SET
                subtitle_file_id = excluded.subtitle_file_id,
                source_format = excluded.source_format,
                source_style = excluded.source_style,
                source_identity_remainder = excluded.source_identity_remainder,
                start_time = excluded.start_time,
                end_time = excluded.end_time,
                start_ms = excluded.start_ms,
                end_ms = excluded.end_ms,
                duration_ms = excluded.duration_ms,
                character_width = excluded.character_width,
                content = excluded.content,
                cue_group_content = excluded.cue_group_content,
                display_title = excluded.display_title,
                subtitle_path = excluded.subtitle_path,
                video_path = excluded.video_path,
                unavailable_reason = excluded.unavailable_reason,
                updated_at = excluded.updated_at;
            """
        )
        try statement.bind(unavailableReason.rawValue, at: 1)
        try statement.bind(now, at: 2)
        try statement.bind(now, at: 3)
        try statement.bind(subtitleFileID, at: 4)
        try statement.run()
    }

    func recomputeTombstoneUnavailableReasons(
        subtitleFileID: Int64
    ) throws {
        let statement = try database.prepare(
            """
            UPDATE cue_tombstones
            SET unavailable_reason = CASE
                  WHEN EXISTS (
                    SELECT 1
                    FROM subtitle_files sf
                    WHERE sf.id = cue_tombstones.subtitle_file_id
                  )
                  THEN 'cue_missing'
                  ELSE unavailable_reason
                END,
                updated_at = ?
            WHERE subtitle_file_id = ?;
            """
        )
        try statement.bind(
            ISO8601DateFormatter().string(from: Date()),
            at: 1
        )
        try statement.bind(subtitleFileID, at: 2)
        try statement.run()
    }

    func deleteCueTombstone(cueID: Int64) throws {
        let statement = try database.prepare(
            "DELETE FROM cue_tombstones WHERE cue_id = ?;"
        )
        try statement.bind(cueID, at: 1)
        try statement.run()
    }

    func clearPriorCueChangeNotices(
        subtitleFileID: Int64
    ) throws {
        let statement = try database.prepare(
            """
            DELETE FROM cue_change_notices
            WHERE EXISTS (
                SELECT 1
                FROM subtitle_cue_lines l
                JOIN subtitle_files sf ON sf.id = l.subtitle_file_id
                WHERE l.id = cue_change_notices.cue_id
                  AND sf.id = ?
            )
               OR EXISTS (
                SELECT 1
                FROM cue_tombstones t
                JOIN subtitle_files sf ON sf.id = t.subtitle_file_id
                WHERE t.cue_id = cue_change_notices.cue_id
                  AND sf.id = ?
            );
            """
        )
        try statement.bind(subtitleFileID, at: 1)
        try statement.bind(subtitleFileID, at: 2)
        try statement.run()
    }

    func clearPriorCueChangeNotices(
        libraryID: Int64,
        under folder: URL
    ) throws -> Bool {
        let prefixes = Self.folderPathPrefixes(for: folder)
        guard !prefixes.isEmpty else {
            return false
        }
        let prefixCondition = prefixes
            .map { _ in "substr(sf.subtitle_path, 1, ?) = ?" }
            .joined(separator: " OR ")
        let statement = try database.prepare(
            """
            DELETE FROM cue_change_notices
            WHERE EXISTS (
                SELECT 1
                FROM subtitle_cue_lines l
                JOIN subtitle_files sf ON sf.id = l.subtitle_file_id
                WHERE l.id = cue_change_notices.cue_id
                  AND sf.library_id = ?
                  AND (\(prefixCondition))
            )
               OR EXISTS (
                SELECT 1
                FROM cue_tombstones t
                JOIN subtitle_files sf ON sf.id = t.subtitle_file_id
                WHERE t.cue_id = cue_change_notices.cue_id
                  AND sf.library_id = ?
                  AND (\(prefixCondition))
            );
            """
        )
        var bindIndex: Int32 = 1
        for _ in 0..<2 {
            try statement.bind(libraryID, at: bindIndex)
            bindIndex += 1
            for prefix in prefixes {
                try statement.bind(prefix.unicodeScalars.count, at: bindIndex)
                bindIndex += 1
                try statement.bind(prefix, at: bindIndex)
                bindIndex += 1
            }
        }
        try statement.run()
        return database.changesCount() > 0
    }

    func insertCueChangeNotice(
        cueID: Int64,
        previousContent: String,
        currentContent: String
    ) throws {
        let statement = try database.prepare(
            """
            INSERT INTO cue_change_notices(
                cue_id,
                previous_content,
                current_content,
                changed_at
            )
            VALUES (?, ?, ?, ?)
            ON CONFLICT(cue_id) DO UPDATE SET
                previous_content = excluded.previous_content,
                current_content = excluded.current_content,
                changed_at = excluded.changed_at;
            """
        )
        try statement.bind(cueID, at: 1)
        try statement.bind(previousContent, at: 2)
        try statement.bind(currentContent, at: 3)
        try statement.bind(ISO8601DateFormatter().string(from: Date()), at: 4)
        try statement.run()
    }

    private func bindOptional(
        _ value: String?,
        to statement: SQLiteStatement,
        at index: Int32
    ) throws {
        if let value {
            try statement.bind(value, at: index)
        } else {
            try statement.bindNull(at: index)
        }
    }

}
