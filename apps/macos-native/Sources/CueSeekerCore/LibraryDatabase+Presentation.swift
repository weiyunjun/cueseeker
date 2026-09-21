import Foundation

extension LibraryDatabase {
    public func libraryPresentation(under folders: [URL]) throws -> [LibraryFolderPresentation] {
        let pathPrefixes = Self.folderPathPrefixes(for: folders)
        guard !pathPrefixes.isEmpty else {
            return []
        }

        let scopeCondition = pathPrefixes.map { _ in
            "(lvr.subtitle_path >= ? AND lvr.subtitle_path < ?)"
        }
            .joined(separator: " OR ")
        let statement = try database.prepare(
            """
            SELECT lvr.video_file_id, lvr.subtitle_file_id,
                   lvr.folder_path, lvr.folder_title, lvr.video_path, lvr.video_name,
                   lvr.duration, lvr.subtitle_path, lvr.subtitle_format,
                   lvr.display_title, lvr.file_extension
            FROM library_video_rows lvr
            JOIN subtitle_files sf ON sf.id = lvr.subtitle_file_id
            JOIN video_files vf ON vf.id = lvr.video_file_id
            WHERE (\(scopeCondition))
            ORDER BY lvr.folder_title COLLATE NOCASE ASC,
                     lvr.folder_path COLLATE NOCASE ASC,
                     lvr.video_order ASC, lvr.video_path ASC;
            """
        )

        var bindIndex: Int32 = 1
        for prefix in pathPrefixes {
            try statement.bind(prefix, at: bindIndex)
            bindIndex += 1
            try statement.bind(Self.pathPrefixUpperBound(for: prefix), at: bindIndex)
            bindIndex += 1
        }

        var groups: [LibraryFolderPresentation] = []
        var currentFolderPath: String?
        var currentFolderTitle = ""
        var currentVideos: [LibraryVideoPresentation] = []

        func appendCurrentGroup() {
            guard let currentFolderPath else {
                return
            }

            groups.append(
                LibraryFolderPresentation(
                    folderPath: currentFolderPath,
                    folderTitle: currentFolderTitle,
                    videos: currentVideos
                )
            )
        }

        while try statement.step() {
            let folderPath = statement.stringColumn(2)
            if currentFolderPath != folderPath {
                appendCurrentGroup()
                currentFolderPath = folderPath
                currentFolderTitle = statement.stringColumn(3)
                currentVideos = []
            }

            currentVideos.append(
                LibraryVideoPresentation(
                    videoFileID: statement.int64Column(0),
                    subtitleFileID: statement.int64Column(1),
                    videoPath: statement.stringColumn(4),
                    videoName: statement.stringColumn(5),
                    duration: statement.nullableDoubleColumn(6),
                    subtitlePath: statement.stringColumn(7),
                    subtitleFormat: SubtitleFormat(rawValue: statement.stringColumn(8)) ?? .srt,
                    displayTitle: statement.stringColumn(9),
                    fileExtension: statement.stringColumn(10)
                )
            )
        }

        appendCurrentGroup()
        return groups
    }

    public func recentLibraryWatching(
        under folders: [URL],
        limit: Int = 5
    ) throws -> [RecentLibraryWatchingPresentation] {
        try Task.checkCancellation()
        let cappedLimit = max(0, limit)
        guard cappedLimit > 0 else {
            return []
        }

        let pathPrefixes = Self.folderPathPrefixes(for: folders)
        guard !pathPrefixes.isEmpty else {
            return []
        }

        let scopeCondition = pathPrefixes.map { _ in "(lvr.subtitle_path >= ? AND lvr.subtitle_path < ?)" }
            .joined(separator: " OR ")
        let statement = try database.prepare(
            """
            SELECT lvr.video_file_id, lvr.subtitle_file_id,
                   lvr.folder_path, lvr.folder_title, lvr.video_path, lvr.video_name,
                   lvr.duration, lvr.subtitle_path, lvr.subtitle_format, lvr.display_title,
                   lvr.file_extension, lvr.video_order, h.position_ms, h.duration,
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
                   h.updated_at,
                   COALESCE(uvc.display_cover_path, vc.display_cover_path),
                   COALESCE(uvc.updated_at, vc.generated_at)
            FROM library_playback_history h
            JOIN library_video_rows lvr ON lvr.video_file_id = h.video_file_id
            JOIN subtitle_files sf ON sf.id = lvr.subtitle_file_id
            LEFT JOIN library_watch_states ws ON ws.video_file_id = lvr.video_file_id
            JOIN video_files vf ON vf.id = lvr.video_file_id
            LEFT JOIN video_covers vc ON vc.video_file_id = vf.id
                AND vc.status = ? AND vc.display_profile_version = ?
            LEFT JOIN user_video_covers uvc ON uvc.video_file_id = vf.id
            WHERE (\(scopeCondition))
            ORDER BY julianday(h.updated_at) DESC, h.updated_at DESC,
                     lvr.folder_title COLLATE NOCASE ASC,
                     lvr.folder_path COLLATE NOCASE ASC,
                     lvr.video_order ASC, lvr.video_path ASC;
            """
        )

        var bindIndex: Int32 = 1
        try statement.bind(LibraryCoverStatus.generated.rawValue, at: bindIndex)
        bindIndex += 1
        try statement.bind(LibraryCoverDisplayProfileVersion.current, at: bindIndex)
        bindIndex += 1
        for prefix in pathPrefixes {
            try statement.bind(prefix, at: bindIndex)
            bindIndex += 1
            try statement.bind(Self.pathPrefixUpperBound(for: prefix), at: bindIndex)
            bindIndex += 1
        }

        var rows: [RecentLibraryWatchingPresentation] = []
        var seenFolderPaths = Set<String>()

        while try statement.step(), rows.count < cappedLimit {
            try Task.checkCancellation()
            let folderPath = statement.stringColumn(2)
            guard seenFolderPaths.insert(folderPath).inserted else {
                continue
            }

            rows.append(
                RecentLibraryWatchingPresentation(
                    videoFileID: statement.int64Column(0),
                    subtitleFileID: statement.int64Column(1),
                    videoPath: statement.stringColumn(4),
                    videoName: statement.stringColumn(5),
                    duration: statement.nullableDoubleColumn(6),
                    subtitlePath: statement.stringColumn(7),
                    subtitleFormat: SubtitleFormat(rawValue: statement.stringColumn(8)) ?? .srt,
                    displayTitle: statement.stringColumn(9),
                    fileExtension: statement.stringColumn(10),
                    folderPath: folderPath,
                    folderTitle: statement.stringColumn(3),
                    episodeNumber: max(1, statement.intColumn(11) + 1),
                    positionMilliseconds: max(0, statement.intColumn(12)),
                    playbackDuration: statement.nullableDoubleColumn(13),
                    startedAt: statement.nullableStringColumn(14),
                    completedAt: statement.nullableStringColumn(15),
                    updatedAt: statement.stringColumn(16),
                    coverPath: statement.nullableStringColumn(17),
                    coverRevision: statement.nullableStringColumn(18)
                )
            )
        }

        return rows
    }

    public func completeLibraryPresentation(
        under folders: [URL]
    ) throws -> [CompleteLibraryFolderPresentation] {
        let pathPrefixes = Self.folderPathPrefixes(for: folders)
        guard !pathPrefixes.isEmpty else {
            return []
        }

        let scopeCondition = pathPrefixes.map { _ in "(lvr.subtitle_path >= ? AND lvr.subtitle_path < ?)" }
            .joined(separator: " OR ")
        let statement = try database.prepare(
            """
            SELECT lvr.video_file_id, lvr.subtitle_file_id,
                   lvr.folder_path, lvr.folder_title, lvr.video_path, lvr.video_name,
                   lvr.duration, lvr.subtitle_path, lvr.subtitle_format, lvr.display_title,
                   lvr.file_extension, lvr.video_order, h.position_ms, h.duration,
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
                   h.updated_at, julianday(h.updated_at),
                   COALESCE(uvc.display_cover_path, vc.display_cover_path),
                   COALESCE(ufc.display_cover_path, fvc.display_cover_path),
                   vf.file_size, vf.video_codec,
                   vf.video_width, vf.video_height, vf.frame_rate,
                   COALESCE(uvc.updated_at, vc.generated_at),
                   COALESCE(ufc.updated_at, fvc.generated_at)
            FROM library_video_rows lvr
            JOIN subtitle_files sf ON sf.id = lvr.subtitle_file_id
            LEFT JOIN library_playback_history h ON h.video_file_id = lvr.video_file_id
            LEFT JOIN library_watch_states ws ON ws.video_file_id = lvr.video_file_id
            JOIN video_files vf ON vf.id = lvr.video_file_id
            LEFT JOIN video_covers vc ON vc.video_file_id = vf.id
                AND vc.status = ? AND vc.display_profile_version = ?
            LEFT JOIN user_video_covers uvc ON uvc.video_file_id = vf.id
            LEFT JOIN folder_covers fc ON fc.folder_path = lvr.folder_path
            LEFT JOIN video_covers fvc ON fvc.video_file_id = fc.source_video_file_id
                AND fvc.status = ? AND fvc.display_profile_version = ?
            LEFT JOIN user_folder_covers ufc ON ufc.folder_path = lvr.folder_path
            WHERE (\(scopeCondition))
            ORDER BY lvr.folder_title COLLATE NOCASE ASC,
                     lvr.folder_path COLLATE NOCASE ASC,
                     lvr.video_order ASC, lvr.video_path ASC;
            """
        )

        var bindIndex: Int32 = 1
        try statement.bind(LibraryCoverStatus.generated.rawValue, at: bindIndex)
        bindIndex += 1
        try statement.bind(LibraryCoverDisplayProfileVersion.current, at: bindIndex)
        bindIndex += 1
        try statement.bind(LibraryCoverStatus.generated.rawValue, at: bindIndex)
        bindIndex += 1
        try statement.bind(LibraryCoverDisplayProfileVersion.current, at: bindIndex)
        bindIndex += 1
        for prefix in pathPrefixes {
            try statement.bind(prefix, at: bindIndex)
            bindIndex += 1
            try statement.bind(Self.pathPrefixUpperBound(for: prefix), at: bindIndex)
            bindIndex += 1
        }

        var groups: [CompleteLibraryFolderPresentation] = []
        var currentFolderPath: String?
        var currentFolderTitle = ""
        var currentFolderCoverPath: String?
        var currentFolderCoverRevision: String?
        var currentVideos: [CompleteLibraryVideoPresentation] = []
        var currentLastWatchedEpisodeNumber: Int?
        var currentLastWatchedVideoPath: String?
        var currentLastWatchedSortValue: Double?
        var currentLastWatchedUpdatedAt: String?

        func appendCurrentGroup() {
            guard let currentFolderPath else {
                return
            }

            groups.append(
                CompleteLibraryFolderPresentation(
                    folderPath: currentFolderPath,
                    folderTitle: currentFolderTitle,
                    folderCoverPath: currentFolderCoverPath,
                    folderCoverRevision: currentFolderCoverRevision,
                    lastWatchedEpisodeNumber: currentLastWatchedEpisodeNumber,
                    lastWatchedVideoPath: currentLastWatchedVideoPath,
                    videos: currentVideos
                )
            )
        }

        func resetCurrentGroup(folderPath: String) {
            currentFolderPath = folderPath
            currentFolderTitle = statement.stringColumn(3)
            currentFolderCoverPath = statement.nullableStringColumn(19)
            currentFolderCoverRevision = statement.nullableStringColumn(26)
            currentVideos = []
            currentLastWatchedEpisodeNumber = nil
            currentLastWatchedVideoPath = nil
            currentLastWatchedSortValue = nil
            currentLastWatchedUpdatedAt = nil
        }

        while try statement.step() {
            let folderPath = statement.stringColumn(2)
            if currentFolderPath != folderPath {
                appendCurrentGroup()
                resetCurrentGroup(folderPath: folderPath)
            }

            let episodeNumber = max(1, statement.intColumn(11) + 1)
            let historyUpdatedAt = statement.nullableStringColumn(16)
            if let historyUpdatedAt {
                let historySortValue = statement.nullableDoubleColumn(17) ?? 0
                let shouldUpdateLatest: Bool
                if let currentLastWatchedSortValue {
                    shouldUpdateLatest = historySortValue > currentLastWatchedSortValue
                        || (
                            historySortValue == currentLastWatchedSortValue
                            && historyUpdatedAt > (currentLastWatchedUpdatedAt ?? "")
                        )
                } else {
                    shouldUpdateLatest = true
                }

                if shouldUpdateLatest {
                    currentLastWatchedEpisodeNumber = episodeNumber
                    currentLastWatchedVideoPath = statement.stringColumn(4)
                    currentLastWatchedSortValue = historySortValue
                    currentLastWatchedUpdatedAt = historyUpdatedAt
                }
            }

            currentVideos.append(
                CompleteLibraryVideoPresentation(
                    videoFileID: statement.int64Column(0),
                    subtitleFileID: statement.int64Column(1),
                    videoPath: statement.stringColumn(4),
                    videoName: statement.stringColumn(5),
                    fileSize: statement.nullableInt64Column(20),
                    videoCodec: statement.nullableStringColumn(21),
                    videoWidth: statement.nullableIntColumn(22),
                    videoHeight: statement.nullableIntColumn(23),
                    frameRate: statement.nullableDoubleColumn(24),
                    duration: statement.nullableDoubleColumn(6),
                    subtitlePath: statement.stringColumn(7),
                    subtitleFormat: SubtitleFormat(rawValue: statement.stringColumn(8)) ?? .srt,
                    displayTitle: statement.stringColumn(9),
                    fileExtension: statement.stringColumn(10),
                    episodeNumber: episodeNumber,
                    positionMilliseconds: max(0, statement.nullableIntColumn(12) ?? 0),
                    playbackDuration: statement.nullableDoubleColumn(13),
                    startedAt: statement.nullableStringColumn(14),
                    completedAt: statement.nullableStringColumn(15),
                    historyUpdatedAt: historyUpdatedAt,
                    coverPath: statement.nullableStringColumn(18),
                    coverRevision: statement.nullableStringColumn(25)
                )
            )
        }

        appendCurrentGroup()
        return groups
    }

    public func completeLibraryFolderSummaries(
        under folders: [URL]
    ) throws -> [CompleteLibraryFolderSummaryPresentation] {
        try Task.checkCancellation()
        let pathPrefixes = Self.folderPathPrefixes(for: folders)
        guard !pathPrefixes.isEmpty else {
            return []
        }

        let scopeCondition = pathPrefixes.map { _ in "(lvr.subtitle_path >= ? AND lvr.subtitle_path < ?)" }
            .joined(separator: " OR ")
        let statement = try database.prepare(
            """
            SELECT lvr.folder_path, lvr.folder_title, COUNT(*) AS episode_count,
                   COALESCE(ufc.display_cover_path, fvc.display_cover_path),
                   (
                       SELECT vc.display_cover_path
                       FROM library_video_rows first_lvr
                       JOIN subtitle_files first_sf ON first_sf.id = first_lvr.subtitle_file_id
                       JOIN video_files first_vf ON first_vf.id = first_lvr.video_file_id
                       LEFT JOIN video_covers vc ON vc.video_file_id = first_vf.id
                           AND vc.status = ? AND vc.display_profile_version = ?
                       WHERE first_lvr.folder_path = lvr.folder_path
                       ORDER BY first_lvr.video_order ASC, first_lvr.video_path ASC
                       LIMIT 1
                   ) AS first_video_cover_path,
                   COALESCE(ufc.updated_at, fvc.generated_at),
                   (
                       SELECT vc.generated_at
                       FROM library_video_rows first_lvr
                       JOIN subtitle_files first_sf ON first_sf.id = first_lvr.subtitle_file_id
                       JOIN video_files first_vf ON first_vf.id = first_lvr.video_file_id
                       LEFT JOIN video_covers vc ON vc.video_file_id = first_vf.id
                           AND vc.status = 'generated'
                           AND vc.display_profile_version = \(LibraryCoverDisplayProfileVersion.current)
                       WHERE first_lvr.folder_path = lvr.folder_path
                       ORDER BY first_lvr.video_order ASC, first_lvr.video_path ASC
                       LIMIT 1
                   ) AS first_video_cover_revision
            FROM library_video_rows lvr
            JOIN subtitle_files sf ON sf.id = lvr.subtitle_file_id
            JOIN video_files vf ON vf.id = lvr.video_file_id
            LEFT JOIN folder_covers fc ON fc.folder_path = lvr.folder_path
            LEFT JOIN video_covers fvc ON fvc.video_file_id = fc.source_video_file_id
                AND fvc.status = ? AND fvc.display_profile_version = ?
            LEFT JOIN user_folder_covers ufc ON ufc.folder_path = lvr.folder_path
            WHERE (\(scopeCondition))
            GROUP BY lvr.folder_path, lvr.folder_title,
                     ufc.display_cover_path, ufc.updated_at,
                     fvc.display_cover_path, fvc.generated_at
            ORDER BY lvr.folder_title COLLATE NOCASE ASC,
                     lvr.folder_path COLLATE NOCASE ASC;
            """
        )

        var bindIndex: Int32 = 1
        try statement.bind(LibraryCoverStatus.generated.rawValue, at: bindIndex)
        bindIndex += 1
        try statement.bind(LibraryCoverDisplayProfileVersion.current, at: bindIndex)
        bindIndex += 1
        try statement.bind(LibraryCoverStatus.generated.rawValue, at: bindIndex)
        bindIndex += 1
        try statement.bind(LibraryCoverDisplayProfileVersion.current, at: bindIndex)
        bindIndex += 1
        for prefix in pathPrefixes {
            try statement.bind(prefix, at: bindIndex)
            bindIndex += 1
            try statement.bind(Self.pathPrefixUpperBound(for: prefix), at: bindIndex)
            bindIndex += 1
        }

        var summaries: [CompleteLibraryFolderSummaryPresentation] = []
        while try statement.step() {
            try Task.checkCancellation()
            let folderCoverPath = statement.nullableStringColumn(3)
            let fallbackCoverPath = statement.nullableStringColumn(4)
            let coverPath: String?
            let coverRevision: String?
            if let folderCoverPath {
                coverPath = folderCoverPath
                coverRevision = statement.nullableStringColumn(5)
            } else if let fallbackCoverPath {
                coverPath = fallbackCoverPath
                coverRevision = statement.nullableStringColumn(6)
            } else {
                coverPath = nil
                coverRevision = nil
            }
            summaries.append(
                CompleteLibraryFolderSummaryPresentation(
                    folderPath: statement.stringColumn(0),
                    folderTitle: statement.stringColumn(1),
                    coverPath: coverPath,
                    coverRevision: coverRevision,
                    episodeCount: max(0, statement.intColumn(2))
                )
            )
        }
        return summaries
    }

    public func completeLibraryFolderDetail(
        folderPath: String
    ) throws -> CompleteLibraryFolderDetailPresentation? {
        try Task.checkCancellation()
        let statement = try database.prepare(
            """
            SELECT lvr.video_file_id, lvr.subtitle_file_id,
                   lvr.folder_path, lvr.folder_title, lvr.video_path, lvr.video_name,
                   lvr.duration, lvr.subtitle_path, lvr.subtitle_format, lvr.display_title,
                   lvr.file_extension, lvr.video_order, h.position_ms, h.duration,
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
                   h.updated_at,
                   COALESCE(uvc.display_cover_path, vc.display_cover_path),
                   vf.file_size, vf.video_codec, vf.video_width, vf.video_height,
                   vf.frame_rate, COALESCE(uvc.updated_at, vc.generated_at)
            FROM library_video_rows lvr
            JOIN subtitle_files sf ON sf.id = lvr.subtitle_file_id
            LEFT JOIN library_playback_history h ON h.video_file_id = lvr.video_file_id
            LEFT JOIN library_watch_states ws ON ws.video_file_id = lvr.video_file_id
            JOIN video_files vf ON vf.id = lvr.video_file_id
            LEFT JOIN video_covers vc ON vc.video_file_id = vf.id
                AND vc.status = ? AND vc.display_profile_version = ?
            LEFT JOIN user_video_covers uvc ON uvc.video_file_id = vf.id
            WHERE lvr.folder_path = ?
            ORDER BY lvr.video_order ASC, lvr.video_path ASC;
            """
        )
        try statement.bind(LibraryCoverStatus.generated.rawValue, at: 1)
        try statement.bind(LibraryCoverDisplayProfileVersion.current, at: 2)
        try statement.bind(folderPath, at: 3)

        var resolvedFolderPath: String?
        var folderTitle = ""
        var videos: [CompleteLibraryVideoPresentation] = []

        while try statement.step() {
            try Task.checkCancellation()
            if resolvedFolderPath == nil {
                resolvedFolderPath = statement.stringColumn(2)
                folderTitle = statement.stringColumn(3)
            }

            videos.append(
                CompleteLibraryVideoPresentation(
                    videoFileID: statement.int64Column(0),
                    subtitleFileID: statement.int64Column(1),
                    videoPath: statement.stringColumn(4),
                    videoName: statement.stringColumn(5),
                    fileSize: statement.nullableInt64Column(18),
                    videoCodec: statement.nullableStringColumn(19),
                    videoWidth: statement.nullableIntColumn(20),
                    videoHeight: statement.nullableIntColumn(21),
                    frameRate: statement.nullableDoubleColumn(22),
                    duration: statement.nullableDoubleColumn(6),
                    subtitlePath: statement.stringColumn(7),
                    subtitleFormat: SubtitleFormat(rawValue: statement.stringColumn(8)) ?? .srt,
                    displayTitle: statement.stringColumn(9),
                    fileExtension: statement.stringColumn(10),
                    episodeNumber: max(1, statement.intColumn(11) + 1),
                    positionMilliseconds: max(0, statement.nullableIntColumn(12) ?? 0),
                    playbackDuration: statement.nullableDoubleColumn(13),
                    startedAt: statement.nullableStringColumn(14),
                    completedAt: statement.nullableStringColumn(15),
                    historyUpdatedAt: statement.nullableStringColumn(16),
                    coverPath: statement.nullableStringColumn(17),
                    coverRevision: statement.nullableStringColumn(23)
                )
            )
        }

        guard let resolvedFolderPath else {
            return nil
        }
        return CompleteLibraryFolderDetailPresentation(
            folderPath: resolvedFolderPath,
            folderTitle: folderTitle,
            videos: videos
        )
    }

    public func refreshPresentationAfterIndexedContentChange() throws {
        let videosByFolderPath = Dictionary(grouping: try indexedLibraryVideos(scopedTo: nil)) {
            URL(fileURLWithPath: $0.videoPath)
                .deletingLastPathComponent()
                .standardizedFileURL
                .path
        }

        let folderPaths = videosByFolderPath.keys.sorted { lhs, rhs in
            let lhsTitle = URL(fileURLWithPath: lhs).lastPathComponent
            let rhsTitle = URL(fileURLWithPath: rhs).lastPathComponent
            let titleComparison = lhsTitle.localizedStandardCompare(rhsTitle)
            if titleComparison != .orderedSame {
                return titleComparison == .orderedAscending
            }

            return lhs.localizedStandardCompare(rhs) == .orderedAscending
        }

        try database.withImmediateTransaction {
            try database.execute("DELETE FROM library_video_rows;")
            try insertLibraryVideoRows(
                videosByFolderPath: videosByFolderPath,
                folderPaths: folderPaths
            )
        }
    }

    public func refreshPresentationAfterIndexedContentChange(
        affectedFolderPaths: Set<String>,
        clearingRetryForLibraryID libraryID: Int64? = nil
    ) throws {
        guard !affectedFolderPaths.isEmpty else {
            return
        }
        try database.withImmediateTransaction {
            try rebuildPresentationRowsInCurrentTransaction(
                folderPaths: affectedFolderPaths
            )
            if let libraryID {
                try clearPresentationRetry(libraryID: libraryID)
            }
        }
    }

    /// Replaces the rows of the given folders inside the caller's transaction.
    func rebuildPresentationRowsInCurrentTransaction(
        folderPaths affectedFolderPaths: Set<String>
    ) throws {
        guard !affectedFolderPaths.isEmpty else {
            return
        }
        let scopedFolderPaths = Set(
            Self.folderPathPrefixes(
                for: affectedFolderPaths.map(
                    URL.init(fileURLWithPath:)
                )
            ).map {
                $0.count > 1 && $0.hasSuffix("/")
                    ? String($0.dropLast())
                    : $0
            }
        )
        let folderPaths = scopedFolderPaths.sorted { lhs, rhs in
            let lhsTitle = URL(fileURLWithPath: lhs).lastPathComponent
            let rhsTitle = URL(fileURLWithPath: rhs).lastPathComponent
            let titleComparison = lhsTitle.localizedStandardCompare(rhsTitle)
            if titleComparison != .orderedSame {
                return titleComparison == .orderedAscending
            }
            return lhs.localizedStandardCompare(rhs) == .orderedAscending
        }
        let videosByFolderPath = Dictionary(
            grouping: try indexedLibraryVideos(
                inFolderPaths: scopedFolderPaths
            )
        ) {
            URL(fileURLWithPath: $0.videoPath)
                .deletingLastPathComponent()
                .standardizedFileURL
                .path
        }

        let placeholders = folderPaths.map { _ in "?" }
            .joined(separator: ", ")
        let delete = try database.prepare(
            """
            DELETE FROM library_video_rows
            WHERE folder_path IN (\(placeholders));
            """
        )
        for (offset, folderPath) in folderPaths.enumerated() {
            try delete.bind(folderPath, at: Int32(offset + 1))
        }
        try delete.run()
        try insertLibraryVideoRows(
            videosByFolderPath: videosByFolderPath,
            folderPaths: folderPaths
        )
    }

    public func refreshPresentationAfterIndexedContentChange(
        libraryID: Int64
    ) throws {
        let videos = try indexedLibraryVideos(libraryID: libraryID)
        let videosByFolderPath = Dictionary(grouping: videos) {
            URL(fileURLWithPath: $0.videoPath)
                .deletingLastPathComponent()
                .standardizedFileURL.path
        }
        var folderPaths = Set(videosByFolderPath.keys)
        let existingFolders = try database.prepare(
            """
            SELECT DISTINCT lvr.folder_path
            FROM library_video_rows lvr
            JOIN subtitle_files sf ON sf.id = lvr.subtitle_file_id
            WHERE sf.library_id = ?;
            """
        )
        try existingFolders.bind(libraryID, at: 1)
        while try existingFolders.step() {
            folderPaths.insert(existingFolders.stringColumn(0))
        }
        let sortedFolderPaths = folderPaths.sorted { lhs, rhs in
            let lhsTitle = URL(fileURLWithPath: lhs).lastPathComponent
            let rhsTitle = URL(fileURLWithPath: rhs).lastPathComponent
            let titleComparison =
                lhsTitle.localizedStandardCompare(rhsTitle)
            if titleComparison != .orderedSame {
                return titleComparison == .orderedAscending
            }
            return lhs.localizedStandardCompare(rhs)
                == .orderedAscending
        }

        try database.withImmediateTransaction {
            if !sortedFolderPaths.isEmpty {
                let placeholders = sortedFolderPaths.map { _ in "?" }
                    .joined(separator: ", ")
                let delete = try database.prepare(
                    """
                    DELETE FROM library_video_rows
                    WHERE folder_path IN (\(placeholders));
                    """
                )
                for (offset, folderPath) in
                    sortedFolderPaths.enumerated()
                {
                    try delete.bind(
                        folderPath,
                        at: Int32(offset + 1)
                    )
                }
                try delete.run()
            }
            try insertLibraryVideoRows(
                videosByFolderPath: videosByFolderPath,
                folderPaths: sortedFolderPaths
            )
            try clearPresentationRetry(libraryID: libraryID)
        }
    }

    private func clearPresentationRetry(libraryID: Int64) throws {
        let statement = try database.prepare(
            """
            UPDATE search_paths
            SET presentation_retry_pending = 0
            WHERE id = ?;
            """
        )
        try statement.bind(libraryID, at: 1)
        try statement.run()
    }

    private func insertLibraryVideoRows(
        videosByFolderPath: [String: [LibraryVideo]],
        folderPaths: [String]
    ) throws {
        let updatedAt = ISO8601DateFormatter().string(from: Date())
        let insert = try database.prepare(
            """
            INSERT INTO library_video_rows(
                video_path,
                video_file_id,
                subtitle_file_id,
                video_name,
                duration,
                subtitle_path,
                subtitle_format,
                folder_path,
                folder_title,
                display_title,
                file_extension,
                folder_order,
                video_order,
                updated_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
            """
        )

        for (folderOrder, folderPath) in folderPaths.enumerated() {
            let folderTitle = URL(fileURLWithPath: folderPath).lastPathComponent
            let videos = (videosByFolderPath[folderPath] ?? [])
                .sorted(by: Self.libraryVideoSort)
            let rankWidth = max(2, String(videos.count).count)

            for (videoOrder, video) in videos.enumerated() {
                let sequence = String(
                    format: "%0*d",
                    rankWidth,
                    videoOrder + 1
                )
                let fileExtension = URL(fileURLWithPath: video.videoPath)
                    .pathExtension.lowercased()
                try insert.bind(video.videoPath, at: 1)
                if let videoFileID = video.videoFileID {
                    try insert.bind(videoFileID, at: 2)
                } else {
                    try insert.bindNull(at: 2)
                }
                if let subtitleFileID = video.subtitleFileID {
                    try insert.bind(subtitleFileID, at: 3)
                } else {
                    try insert.bindNull(at: 3)
                }
                try insert.bind(video.videoName, at: 4)
                if let duration = video.duration {
                    try insert.bind(duration, at: 5)
                } else {
                    try insert.bindNull(at: 5)
                }
                try insert.bind(video.subtitlePath, at: 6)
                try insert.bind(video.subtitleFormat.rawValue, at: 7)
                try insert.bind(folderPath, at: 8)
                try insert.bind(folderTitle, at: 9)
                try insert.bind("\(folderTitle) - \(sequence)", at: 10)
                try insert.bind(fileExtension, at: 11)
                try insert.bind(folderOrder, at: 12)
                try insert.bind(videoOrder, at: 13)
                try insert.bind(updatedAt, at: 14)
                try insert.run()
                try insert.reset()
                try insert.clearBindings()
            }
        }
        // The videos' titles just changed, so their subtitles' titles follow.
        try SubtitleDisplayTitleResolver.refreshSearchOrderDisplayTitles(on: database)
    }

    private func indexedLibraryVideos(
        inFolderPaths folderPaths: Set<String>
    ) throws -> [LibraryVideo] {
        guard !folderPaths.isEmpty else {
            return []
        }
        let prefixes = Self.folderPathPrefixes(
            for: folderPaths.map(URL.init(fileURLWithPath:))
        )
        let exactFolderPaths = Set(prefixes.map {
            $0.count > 1 && $0.hasSuffix("/")
                ? String($0.dropLast())
                : $0
        })
        return try indexedLibraryVideos(scopedTo: prefixes).filter {
            exactFolderPaths.contains(
                URL(fileURLWithPath: $0.videoPath)
                    .deletingLastPathComponent()
                    .standardizedFileURL.path
            )
        }
    }

    private func indexedLibraryVideos(scopedTo pathPrefixes: [String]?) throws -> [LibraryVideo] {
        let scopeCondition = pathPrefixes?.map { _ in "(sf.subtitle_path >= ? AND sf.subtitle_path < ?)" }
            .joined(separator: " OR ") ?? ""
        let whereClause = pathPrefixes?.isEmpty == false
            ? "WHERE (\(scopeCondition))"
            : ""
        let statement = try database.prepare(
            """
            SELECT vf.id, sf.id, vf.path, vf.video_name, vf.duration,
                   sf.subtitle_path, sf.format
            FROM subtitle_files sf INDEXED BY idx_subtitle_files_subtitle_path
            JOIN subtitle_video_matches m ON m.subtitle_file_id = sf.id AND m.is_active = 1
            JOIN video_files vf ON vf.id = m.video_file_id
            \(whereClause)
            ORDER BY vf.path ASC, sf.subtitle_path ASC;
            """
        )

        if let pathPrefixes {
            var bindIndex: Int32 = 1
            for prefix in pathPrefixes {
                try statement.bind(prefix, at: bindIndex)
                bindIndex += 1
                try statement.bind(Self.pathPrefixUpperBound(for: prefix), at: bindIndex)
                bindIndex += 1
            }
        }

        var videosByPath: [String: LibraryVideo] = [:]
        while try statement.step() {
            let subtitleFormat = SubtitleFormat(rawValue: statement.stringColumn(6)) ?? .srt
            let video = LibraryVideo(
                videoFileID: statement.int64Column(0),
                subtitleFileID: statement.int64Column(1),
                videoPath: statement.stringColumn(2),
                videoName: statement.stringColumn(3),
                duration: statement.nullableDoubleColumn(4),
                subtitlePath: statement.stringColumn(5),
                subtitleFormat: subtitleFormat
            )

            if let existing = videosByPath[video.videoPath] {
                let subtitleComparison = video.subtitlePath.localizedStandardCompare(existing.subtitlePath)
                if subtitleComparison == .orderedAscending {
                    videosByPath[video.videoPath] = video
                }
            } else {
                videosByPath[video.videoPath] = video
            }
        }

        return videosByPath.values.sorted { lhs, rhs in
            Self.libraryVideoSort(lhs, rhs)
        }
    }

    private func indexedLibraryVideos(
        libraryID: Int64
    ) throws -> [LibraryVideo] {
        let statement = try database.prepare(
            """
            SELECT vf.id, sf.id, vf.path, vf.video_name, vf.duration,
                   sf.subtitle_path, sf.format
            FROM subtitle_files sf
            JOIN subtitle_video_matches m
              ON m.subtitle_file_id = sf.id AND m.is_active = 1
            JOIN video_files vf ON vf.id = m.video_file_id
            WHERE sf.library_id = ?
            ORDER BY vf.path ASC, sf.subtitle_path ASC;
            """
        )
        try statement.bind(libraryID, at: 1)
        var videosByPath: [String: LibraryVideo] = [:]
        while try statement.step() {
            let video = LibraryVideo(
                videoFileID: statement.int64Column(0),
                subtitleFileID: statement.int64Column(1),
                videoPath: statement.stringColumn(2),
                videoName: statement.stringColumn(3),
                duration: statement.nullableDoubleColumn(4),
                subtitlePath: statement.stringColumn(5),
                subtitleFormat: SubtitleFormat(
                    rawValue: statement.stringColumn(6)
                ) ?? .srt
            )
            if let existing = videosByPath[video.videoPath] {
                if video.subtitlePath.localizedStandardCompare(
                    existing.subtitlePath
                ) == .orderedAscending {
                    videosByPath[video.videoPath] = video
                }
            } else {
                videosByPath[video.videoPath] = video
            }
        }
        return videosByPath.values.sorted(by: Self.libraryVideoSort)
    }

}
