import Foundation

public final class LibraryDatabase: @unchecked Sendable {
    private let database: SQLiteDatabase

    public init(
        path: URL,
        access: DatabaseConnectionAccess = .readWrite
    ) throws {
        database = try SQLiteDatabase(path: path, access: access)
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

    public func updateVideoDuration(videoFile: URL, duration: Double?) throws {
        let normalizedDuration = Self.normalizedDuration(duration)
        let statement = try database.prepare(
            """
            UPDATE video_files
            SET duration = ?
            WHERE path = ?;
            """
        )
        try bind(normalizedDuration, to: statement, at: 1)
        try statement.bind(videoFile.path, at: 2)
        try statement.run()

        try updatePresentationDuration(videoFile: videoFile, duration: normalizedDuration)
    }

    public func updateVideoMetadata(
        videoFile: URL,
        duration: Double?,
        videoWidth: Int?,
        videoHeight: Int?,
        frameRate: Double?,
        videoCodec: String?
    ) throws {
        let normalizedDuration = Self.normalizedDuration(duration)
        let statement = try database.prepare(
            """
            UPDATE video_files
            SET duration = ?,
                video_width = ?,
                video_height = ?,
                frame_rate = ?,
                video_codec = ?
            WHERE path = ?;
            """
        )
        try bind(normalizedDuration, to: statement, at: 1)
        try bind(videoWidth.flatMap { $0 > 0 ? $0 : nil }, to: statement, at: 2)
        try bind(videoHeight.flatMap { $0 > 0 ? $0 : nil }, to: statement, at: 3)
        try bind(
            frameRate.flatMap { $0.isFinite && $0 > 0 ? $0 : nil },
            to: statement,
            at: 4
        )
        let normalizedVideoCodec = videoCodec?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        try bind(
            normalizedVideoCodec?.isEmpty == false ? normalizedVideoCodec : nil,
            to: statement,
            at: 5
        )
        try statement.bind(videoFile.path, at: 6)
        try statement.run()

        try updatePresentationDuration(videoFile: videoFile, duration: normalizedDuration)
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

    private static func folderPathPrefixes(for folders: [URL]) -> [String] {
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

    private static func pathPrefixUpperBound(for prefix: String) -> String {
        prefix + "\u{10FFFF}"
    }

    private static func libraryVideoSort(_ lhs: LibraryVideo, _ rhs: LibraryVideo) -> Bool {
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
