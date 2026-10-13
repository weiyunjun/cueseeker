import Foundation

public final class LibraryCoverDatabase: @unchecked Sendable {
    private let database: SQLiteDatabase

    public init(
        path: URL,
        access: DatabaseConnectionAccess = .readWrite
    ) throws {
        database = try SQLiteDatabase(path: path, access: access)
    }

    public func libraryCoverEligibleVideos(under folders: [URL]) throws -> [LibraryCoverEligibleVideo] {
        let pathPrefixes = Self.folderPathPrefixes(for: folders)
        guard !pathPrefixes.isEmpty else {
            return []
        }

        let scopeCondition = pathPrefixes.map { _ in "(sf.subtitle_path >= ? AND sf.subtitle_path < ?)" }
            .joined(separator: " OR ")
        let statement = try database.prepare(
            """
            SELECT vf.id, vf.path, vf.video_name, vf.file_size, vf.duration,
                   sf.subtitle_path, sf.format,
                   EXISTS (
                       SELECT 1
                       FROM user_video_covers uvc
                       WHERE uvc.video_file_id = vf.id
                   )
            FROM subtitle_files sf INDEXED BY idx_subtitle_files_subtitle_path
            JOIN subtitle_video_matches m ON m.subtitle_file_id = sf.id AND m.is_active = 1
            JOIN video_files vf ON vf.id = m.video_file_id
            WHERE \(scopeCondition)
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

        var videosByID: [Int64: LibraryCoverEligibleVideo] = [:]
        while try statement.step() {
            let videoFileID = statement.int64Column(0)
            let subtitleFormat = SubtitleFormat(rawValue: statement.stringColumn(6)) ?? .srt
            let subtitlePath = statement.stringColumn(5)
            let video = LibraryCoverEligibleVideo(
                videoFileID: videoFileID,
                videoPath: statement.stringColumn(1),
                videoName: statement.stringColumn(2),
                fileSize: statement.nullableInt64Column(3),
                duration: statement.nullableDoubleColumn(4),
                subtitlePath: subtitlePath,
                subtitleFormat: subtitleFormat,
                folderPath: Self.folderPath(forSubtitlePath: subtitlePath),
                hasUserCover: statement.intColumn(7) != 0
            )

            if let existing = videosByID[videoFileID] {
                if video.subtitlePath.localizedStandardCompare(existing.subtitlePath) == .orderedAscending {
                    videosByID[videoFileID] = video
                }
            } else {
                videosByID[videoFileID] = video
            }
        }

        return videosByID.values.sorted { lhs, rhs in
            Self.libraryVideoSort(lhs.libraryVideo, rhs.libraryVideo)
        }
    }

    public func libraryCoverEligibleVideos(
        videoPaths: Set<String>
    ) throws -> [LibraryCoverEligibleVideo] {
        guard !videoPaths.isEmpty else {
            return []
        }
        return try libraryCoverEligibleVideos(
            whereClause: "vf.path IN",
            values: videoPaths
        )
    }

    public func libraryCoverDisplayCandidates(
        under folders: [URL]
    ) throws -> [LibraryCoverDisplayCandidate] {
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
            SELECT vc.video_file_id, vf.path, vc.cover_path,
                   vc.display_cover_path, vc.display_profile_version
            FROM subtitle_files sf INDEXED BY idx_subtitle_files_subtitle_path
            JOIN subtitle_video_matches m ON m.subtitle_file_id = sf.id AND m.is_active = 1
            JOIN video_files vf ON vf.id = m.video_file_id
            JOIN video_covers vc ON vc.video_file_id = vf.id AND vc.status = ?
            WHERE \(scopeCondition)
            ORDER BY vf.path ASC, sf.subtitle_path ASC;
            """
        )

        var bindIndex: Int32 = 1
        try statement.bind(LibraryCoverStatus.generated.rawValue, at: bindIndex)
        bindIndex += 1
        for prefix in pathPrefixes {
            try statement.bind(prefix, at: bindIndex)
            bindIndex += 1
            try statement.bind(Self.pathPrefixUpperBound(for: prefix), at: bindIndex)
            bindIndex += 1
        }

        var candidatesByID: [Int64: LibraryCoverDisplayCandidate] = [:]
        while try statement.step() {
            let videoFileID = statement.int64Column(0)
            guard candidatesByID[videoFileID] == nil else {
                continue
            }
            candidatesByID[videoFileID] = LibraryCoverDisplayCandidate(
                videoFileID: videoFileID,
                videoPath: statement.stringColumn(1),
                masterCoverPath: statement.stringColumn(2),
                displayCoverPath: statement.nullableStringColumn(3),
                displayProfileVersion: statement.nullableIntColumn(4)
            )
        }

        return candidatesByID.values.sorted {
            $0.videoPath.localizedStandardCompare($1.videoPath) == .orderedAscending
        }
    }

    public func libraryCoverDisplayCandidates(
        videoPaths: Set<String>
    ) throws -> [LibraryCoverDisplayCandidate] {
        guard !videoPaths.isEmpty else {
            return []
        }
        let paths = videoPaths.sorted()
        let placeholders = paths.map { _ in "?" }.joined(separator: ", ")
        let statement = try database.prepare(
            """
            SELECT vc.video_file_id, vf.path, vc.cover_path,
                   vc.display_cover_path, vc.display_profile_version
            FROM video_files vf
            JOIN video_covers vc
              ON vc.video_file_id = vf.id AND vc.status = ?
            WHERE vf.path IN (\(placeholders))
            ORDER BY vf.path ASC;
            """
        )
        try statement.bind(LibraryCoverStatus.generated.rawValue, at: 1)
        for (offset, path) in paths.enumerated() {
            try statement.bind(path, at: Int32(offset + 2))
        }
        var candidates: [LibraryCoverDisplayCandidate] = []
        while try statement.step() {
            candidates.append(
                LibraryCoverDisplayCandidate(
                    videoFileID: statement.int64Column(0),
                    videoPath: statement.stringColumn(1),
                    masterCoverPath: statement.stringColumn(2),
                    displayCoverPath: statement.nullableStringColumn(3),
                    displayProfileVersion: statement.nullableIntColumn(4)
                )
            )
        }
        return candidates
    }

    public func libraryVideoCover(forVideoFileID videoFileID: Int64) throws -> LibraryVideoCover? {
        let statement = try database.prepare(
            """
            SELECT video_file_id, cover_path, display_cover_path, display_profile_version,
                   source_time_ms, score, algorithm_version, generated_file_size,
                   generated_duration, status, error_message, generated_at
            FROM video_covers
            WHERE video_file_id = ?;
            """
        )
        try statement.bind(videoFileID, at: 1)

        guard try statement.step() else {
            return nil
        }
        return Self.libraryVideoCover(from: statement)
    }

    public func upsertLibraryVideoCover(
        videoFileID: Int64,
        masterCoverPath: String,
        displayCoverPath: String? = nil,
        displayProfileVersion: Int? = nil,
        sourceTimeMilliseconds: Int,
        score: Double?,
        algorithmVersion: Int,
        generatedFileSize: Int64?,
        generatedDuration: Double?,
        status: LibraryCoverStatus,
        errorMessage: String?
    ) throws {
        try Self.validateDisplayCover(path: displayCoverPath, profileVersion: displayProfileVersion)
        let statement = try database.prepare(
            """
            INSERT INTO video_covers(
                video_file_id, cover_path, display_cover_path, display_profile_version,
                source_time_ms, score, algorithm_version, generated_file_size,
                generated_duration, status, error_message, generated_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(video_file_id) DO UPDATE SET
                cover_path = excluded.cover_path,
                display_cover_path = excluded.display_cover_path,
                display_profile_version = excluded.display_profile_version,
                source_time_ms = excluded.source_time_ms,
                score = excluded.score,
                algorithm_version = excluded.algorithm_version,
                generated_file_size = excluded.generated_file_size,
                generated_duration = excluded.generated_duration,
                status = excluded.status,
                error_message = excluded.error_message,
                generated_at = excluded.generated_at;
            """
        )

        try statement.bind(videoFileID, at: 1)
        try statement.bind(masterCoverPath, at: 2)
        try bind(displayCoverPath, to: statement, at: 3)
        if let displayProfileVersion {
            try statement.bind(displayProfileVersion, at: 4)
        } else {
            try statement.bindNull(at: 4)
        }
        try statement.bind(max(0, sourceTimeMilliseconds), at: 5)
        if let score, score.isFinite {
            try statement.bind(score, at: 6)
        } else {
            try statement.bindNull(at: 6)
        }
        try statement.bind(algorithmVersion, at: 7)
        if let generatedFileSize {
            try statement.bind(generatedFileSize, at: 8)
        } else {
            try statement.bindNull(at: 8)
        }
        if let generatedDuration, generatedDuration.isFinite, generatedDuration >= 0 {
            try statement.bind(generatedDuration, at: 9)
        } else {
            try statement.bindNull(at: 9)
        }
        try statement.bind(status.rawValue, at: 10)
        try bind(errorMessage?.isEmpty == false ? errorMessage : nil, to: statement, at: 11)
        try statement.bind(Self.revisionTimestamp(), at: 12)
        try statement.run()
    }

    public func updateLibraryVideoDisplayCover(
        videoFileID: Int64,
        displayCoverPath: String?,
        displayProfileVersion: Int?
    ) throws {
        try Self.validateDisplayCover(path: displayCoverPath, profileVersion: displayProfileVersion)
        let statement = try database.prepare(
            """
            UPDATE video_covers
            SET display_cover_path = ?, display_profile_version = ?, generated_at = ?
            WHERE video_file_id = ?;
            """
        )
        try bind(displayCoverPath, to: statement, at: 1)
        if let displayProfileVersion {
            try statement.bind(displayProfileVersion, at: 2)
        } else {
            try statement.bindNull(at: 2)
        }
        try statement.bind(Self.revisionTimestamp(), at: 3)
        try statement.bind(videoFileID, at: 4)
        try statement.run()
    }

    public func libraryFolderCover(folderPath: String) throws -> LibraryFolderCover? {
        let folderID = try libraryFolderID(forPath: folderPath)
        let statement = try database.prepare(
            """
            SELECT folder_path, cover_path, source_video_file_id, generated_at
            FROM folder_covers
            WHERE folder_id = ?
               OR (folder_id IS NULL AND folder_path = ?)
            ORDER BY CASE WHEN folder_id IS NULL THEN 1 ELSE 0 END
            LIMIT 1;
            """
        )
        try bind(folderID, to: statement, at: 1)
        try statement.bind(folderPath, at: 2)
        guard try statement.step() else {
            return nil
        }
        return LibraryFolderCover(
            folderPath: statement.stringColumn(0),
            masterCoverPath: statement.stringColumn(1),
            sourceVideoFileID: statement.int64Column(2),
            generatedAt: statement.stringColumn(3)
        )
    }

    public func upsertLibraryFolderCover(
        folderPath: String,
        masterCoverPath: String,
        sourceVideoFileID: Int64
    ) throws {
        let folderID = try libraryFolderID(forPath: folderPath)
        try database.withImmediateTransaction {
            if let folderID {
                try releaseGeneratedFolderCoverPath(
                    folderPath,
                    exceptFolderID: folderID
                )
                let update = try database.prepare(
                    """
                    UPDATE folder_covers
                    SET folder_path = ?,
                        cover_path = ?,
                        source_video_file_id = ?,
                        generated_at = ?
                    WHERE folder_id = ?;
                    """
                )
                try update.bind(folderPath, at: 1)
                try update.bind(masterCoverPath, at: 2)
                try update.bind(sourceVideoFileID, at: 3)
                try update.bind(Self.revisionTimestamp(), at: 4)
                try update.bind(folderID, at: 5)
                try update.run()
                if database.changesCount() > 0 {
                    return
                }
            }

            let statement = try database.prepare(
                """
                INSERT INTO folder_covers(
                    folder_path,
                    folder_id,
                    cover_path,
                    source_video_file_id,
                    generated_at
                )
                VALUES (?, ?, ?, ?, ?)
                ON CONFLICT(folder_path) DO UPDATE SET
                    folder_id = excluded.folder_id,
                    cover_path = excluded.cover_path,
                    source_video_file_id = excluded.source_video_file_id,
                    generated_at = excluded.generated_at;
                """
            )
            try statement.bind(folderPath, at: 1)
            try bind(folderID, to: statement, at: 2)
            try statement.bind(masterCoverPath, at: 3)
            try statement.bind(sourceVideoFileID, at: 4)
            try statement.bind(Self.revisionTimestamp(), at: 5)
            try statement.run()
        }
    }

    public func deleteLibraryFolderCover(folderPath: String) throws {
        let folderID = try libraryFolderID(forPath: folderPath)
        let statement = try database.prepare(
            """
            DELETE FROM folder_covers
            WHERE folder_id = ?
               OR (folder_id IS NULL AND folder_path = ?);
            """
        )
        try bind(folderID, to: statement, at: 1)
        try statement.bind(folderPath, at: 2)
        try statement.run()
    }

    public func libraryUserVideoCover(forVideoFile videoFile: URL) throws -> LibraryUserCover? {
        let statement = try database.prepare(
            """
            SELECT uvc.display_cover_path, uvc.updated_at
            FROM user_video_covers uvc
            JOIN video_files vf ON vf.id = uvc.video_file_id
            WHERE vf.path = ?;
            """
        )
        try statement.bind(videoFile.mediaPath, at: 1)
        guard try statement.step() else {
            return nil
        }
        return LibraryUserCover(
            displayCoverPath: statement.stringColumn(0),
            revision: statement.stringColumn(1)
        )
    }

    public func upsertLibraryUserVideoCover(
        forVideoFile videoFile: URL,
        displayCoverPath: String
    ) throws {
        let statement = try database.prepare(
            """
            INSERT INTO user_video_covers(video_file_id, display_cover_path, updated_at)
            VALUES ((SELECT id FROM video_files WHERE path = ?), ?, ?)
            ON CONFLICT(video_file_id) DO UPDATE SET
                display_cover_path = excluded.display_cover_path,
                updated_at = excluded.updated_at;
            """
        )
        try statement.bind(videoFile.mediaPath, at: 1)
        try statement.bind(displayCoverPath, at: 2)
        try statement.bind(Self.revisionTimestamp(), at: 3)
        do {
            try statement.run()
        } catch {
            if try videoFileID(for: videoFile) == nil {
                throw SQLiteDatabaseError.stepFailed("Video file is not indexed: \(videoFile.mediaPath)")
            }
            throw error
        }
    }

    public func deleteLibraryUserVideoCover(forVideoFile videoFile: URL) throws {
        let statement = try database.prepare(
            """
            DELETE FROM user_video_covers
            WHERE video_file_id = (SELECT id FROM video_files WHERE path = ?);
            """
        )
        try statement.bind(videoFile.mediaPath, at: 1)
        try statement.run()
    }

    public func libraryUserFolderCover(folderPath: String) throws -> LibraryUserCover? {
        let folderID = try libraryFolderID(forPath: folderPath)
        let statement = try database.prepare(
            """
            SELECT display_cover_path, updated_at
            FROM user_folder_covers
            WHERE folder_id = ?
               OR (folder_id IS NULL AND folder_path = ?)
            ORDER BY CASE WHEN folder_id IS NULL THEN 1 ELSE 0 END
            LIMIT 1;
            """
        )
        try bind(folderID, to: statement, at: 1)
        try statement.bind(folderPath, at: 2)
        guard try statement.step() else {
            return nil
        }
        return LibraryUserCover(
            displayCoverPath: statement.stringColumn(0),
            revision: statement.stringColumn(1)
        )
    }

    public func upsertLibraryUserFolderCover(
        folderPath: String,
        displayCoverPath: String
    ) throws {
        let folderID = try libraryFolderID(forPath: folderPath)
        try database.withImmediateTransaction {
            if let folderID {
                try releaseUserFolderCoverPath(folderPath, exceptFolderID: folderID)
                let update = try database.prepare(
                    """
                    UPDATE user_folder_covers
                    SET folder_path = ?,
                        display_cover_path = ?,
                        updated_at = ?
                    WHERE folder_id = ?;
                    """
                )
                try update.bind(folderPath, at: 1)
                try update.bind(displayCoverPath, at: 2)
                try update.bind(Self.revisionTimestamp(), at: 3)
                try update.bind(folderID, at: 4)
                try update.run()
                if database.changesCount() > 0 {
                    return
                }
            }

            let statement = try database.prepare(
                """
                INSERT INTO user_folder_covers(
                    folder_path,
                    folder_id,
                    display_cover_path,
                    updated_at
                )
                VALUES (?, ?, ?, ?)
                ON CONFLICT(folder_path) DO UPDATE SET
                    folder_id = excluded.folder_id,
                    display_cover_path = excluded.display_cover_path,
                    updated_at = excluded.updated_at;
                """
            )
            try statement.bind(folderPath, at: 1)
            try bind(folderID, to: statement, at: 2)
            try statement.bind(displayCoverPath, at: 3)
            try statement.bind(Self.revisionTimestamp(), at: 4)
            try statement.run()
        }
    }

    public func deleteLibraryUserFolderCover(folderPath: String) throws {
        let folderID = try libraryFolderID(forPath: folderPath)
        let statement = try database.prepare(
            """
            DELETE FROM user_folder_covers
            WHERE folder_id = ?
               OR (folder_id IS NULL AND folder_path = ?);
            """
        )
        try bind(folderID, to: statement, at: 1)
        try statement.bind(folderPath, at: 2)
        try statement.run()
    }

    private func libraryFolderID(forPath folderPath: String) throws -> Int64? {
        let statement = try database.prepare(
            """
            SELECT lf.id
            FROM library_folders lf
            JOIN search_paths sp ON sp.id = lf.library_id
            WHERE rtrim(sp.path || '/' || lf.relative_path, '/') = ?
            ORDER BY lf.id DESC
            LIMIT 1;
            """
        )
        // The Library root is stored standardized, so the lookup must be too.
        try statement.bind(
            URL.fromMediaPath(folderPath).mediaPath,
            at: 1
        )
        return try statement.step() ? statement.int64Column(0) : nil
    }

    private func releaseGeneratedFolderCoverPath(
        _ folderPath: String,
        exceptFolderID: Int64
    ) throws {
        let statement = try database.prepare(
            """
            DELETE FROM folder_covers
            WHERE folder_path = ?
              AND (folder_id IS NULL OR folder_id <> ?);
            """
        )
        try statement.bind(folderPath, at: 1)
        try statement.bind(exceptFolderID, at: 2)
        try statement.run()
    }

    private func releaseUserFolderCoverPath(
        _ folderPath: String,
        exceptFolderID: Int64
    ) throws {
        let statement = try database.prepare(
            """
            DELETE FROM user_folder_covers
            WHERE folder_path = ?
              AND (folder_id IS NULL OR folder_id <> ?);
            """
        )
        try statement.bind(folderPath, at: 1)
        try statement.bind(exceptFolderID, at: 2)
        try statement.run()
    }

    private func videoFileID(for videoFile: URL) throws -> Int64? {
        let statement = try database.prepare("SELECT id FROM video_files WHERE path = ?;")
        try statement.bind(videoFile.mediaPath, at: 1)
        return try statement.step() ? statement.int64Column(0) : nil
    }

    private func libraryCoverEligibleVideos(
        whereClause: String,
        values: Set<String>
    ) throws -> [LibraryCoverEligibleVideo] {
        let sortedValues = values.sorted()
        let placeholders = sortedValues.map { _ in "?" }
            .joined(separator: ", ")
        let statement = try database.prepare(
            """
            SELECT vf.id, vf.path, vf.video_name, vf.file_size, vf.duration,
                   sf.subtitle_path, sf.format,
                   EXISTS (
                       SELECT 1
                       FROM user_video_covers uvc
                       WHERE uvc.video_file_id = vf.id
                   )
            FROM subtitle_files sf
            JOIN subtitle_video_matches m
              ON m.subtitle_file_id = sf.id AND m.is_active = 1
            JOIN video_files vf ON vf.id = m.video_file_id
            WHERE \(whereClause) (\(placeholders))
            ORDER BY vf.path ASC, sf.subtitle_path ASC;
            """
        )
        for (offset, value) in sortedValues.enumerated() {
            try statement.bind(value, at: Int32(offset + 1))
        }

        var videosByID: [Int64: LibraryCoverEligibleVideo] = [:]
        while try statement.step() {
            let videoFileID = statement.int64Column(0)
            let subtitlePath = statement.stringColumn(5)
            let video = LibraryCoverEligibleVideo(
                videoFileID: videoFileID,
                videoPath: statement.stringColumn(1),
                videoName: statement.stringColumn(2),
                fileSize: statement.nullableInt64Column(3),
                duration: statement.nullableDoubleColumn(4),
                subtitlePath: subtitlePath,
                subtitleFormat: SubtitleFormat(
                    rawValue: statement.stringColumn(6)
                ) ?? .srt,
                folderPath: Self.folderPath(forSubtitlePath: subtitlePath),
                hasUserCover: statement.intColumn(7) != 0
            )
            if let existing = videosByID[videoFileID] {
                if video.subtitlePath.localizedStandardCompare(
                    existing.subtitlePath
                ) == .orderedAscending {
                    videosByID[videoFileID] = video
                }
            } else {
                videosByID[videoFileID] = video
            }
        }
        return videosByID.values.sorted {
            Self.libraryVideoSort($0.libraryVideo, $1.libraryVideo)
        }
    }

    private func bind(_ value: String?, to statement: SQLiteStatement, at index: Int32) throws {
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

    private static func validateDisplayCover(path: String?, profileVersion: Int?) throws {
        guard (path == nil) == (profileVersion == nil) else {
            throw SQLiteDatabaseError.stepFailed(
                "Display cover path and profile version must be stored together"
            )
        }
        if let profileVersion, profileVersion <= 0 {
            throw SQLiteDatabaseError.stepFailed("Display cover profile version must be positive")
        }
    }

    private static func revisionTimestamp() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: Date())
    }

    private static func libraryVideoCover(from statement: SQLiteStatement) -> LibraryVideoCover {
        LibraryVideoCover(
            videoFileID: statement.int64Column(0),
            masterCoverPath: statement.stringColumn(1),
            displayCoverPath: statement.nullableStringColumn(2),
            displayProfileVersion: statement.nullableIntColumn(3),
            sourceTimeMilliseconds: max(0, statement.intColumn(4)),
            score: statement.nullableDoubleColumn(5),
            algorithmVersion: statement.intColumn(6),
            generatedFileSize: statement.nullableInt64Column(7),
            generatedDuration: statement.nullableDoubleColumn(8),
            status: LibraryCoverStatus(rawValue: statement.stringColumn(9)) ?? .failed,
            errorMessage: statement.nullableStringColumn(10),
            generatedAt: statement.stringColumn(11)
        )
    }

    private static func folderPathPrefixes(for folders: [URL]) -> [String] {
        Array(Set(folders.flatMap(folderPathPrefixes(for:)))).sorted()
    }

    private static func folderPathPrefixes(for folder: URL) -> [String] {
        var path = normalizedFolderPath(folder.mediaPath)
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

    private static func pathPrefixUpperBound(for prefix: String) -> String {
        prefix + "\u{10FFFF}"
    }

    private static func folderPath(forSubtitlePath subtitlePath: String) -> String {
        URL.fromMediaPath(subtitlePath)
            .deletingLastPathComponent()
            .mediaPath
    }

    private static func libraryVideoSort(_ lhs: LibraryVideo, _ rhs: LibraryVideo) -> Bool {
        let lhsFolder = URL.fromMediaPath(lhs.videoPath).deletingLastPathComponent().lastPathComponent
        let rhsFolder = URL.fromMediaPath(rhs.videoPath).deletingLastPathComponent().lastPathComponent
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
