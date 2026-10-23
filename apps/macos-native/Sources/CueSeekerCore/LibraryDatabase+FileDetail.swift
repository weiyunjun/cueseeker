import Foundation

public struct FileDetailVideoInfo: Equatable, Sendable {
    public let path: String
    public let name: String
    public let fileSize: Int64
    public let duration: Double?
    public let videoWidth: Int?
    public let videoHeight: Int?
    public let frameRate: Double?
    public let videoCodec: String?
    public let videoBitDepth: Int?
    public let videoPixelFormat: String?
    public let audioTracks: [VideoAudioTrack]
    public let subtitles: [VideoSubtitle]
    public let createdAt: Date?
    public let modifiedAt: Date?

    public init(
        path: String,
        name: String,
        fileSize: Int64,
        duration: Double?,
        videoWidth: Int?,
        videoHeight: Int?,
        frameRate: Double?,
        videoCodec: String?,
        videoBitDepth: Int? = nil,
        videoPixelFormat: String? = nil,
        audioTracks: [VideoAudioTrack],
        subtitles: [VideoSubtitle],
        createdAt: Date?,
        modifiedAt: Date?
    ) {
        self.path = path
        self.name = name
        self.fileSize = fileSize
        self.duration = duration
        self.videoWidth = videoWidth
        self.videoHeight = videoHeight
        self.frameRate = frameRate
        self.videoCodec = videoCodec
        self.videoBitDepth = videoBitDepth
        self.videoPixelFormat = videoPixelFormat
        self.audioTracks = audioTracks
        self.subtitles = subtitles
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }
}

public struct FileDetailSubtitleInfo: Equatable, Sendable {
    public let path: String
    public let name: String
    public let fileSize: Int64
    public let format: SubtitleFormat
    public let encoding: String
    public let cueCount: Int
    public let rawCueCount: Int
    public let associatedVideoPath: String?
    public let createdAt: Date?
    public let modifiedAt: Date?

    public init(
        path: String,
        name: String,
        fileSize: Int64,
        format: SubtitleFormat,
        encoding: String,
        cueCount: Int,
        rawCueCount: Int = 0,
        associatedVideoPath: String?,
        createdAt: Date?,
        modifiedAt: Date?
    ) {
        self.path = path
        self.name = name
        self.fileSize = fileSize
        self.format = format
        self.encoding = encoding
        self.cueCount = cueCount
        self.rawCueCount = rawCueCount
        self.associatedVideoPath = associatedVideoPath
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }
}

public struct FileDetailFolderInfo: Equatable, Sendable {
    public let path: String
    public let name: String
    public let isRootFolder: Bool
    public let folderCount: Int
    public let videoCount: Int
    public let subtitleCount: Int
    public let addedAt: Date?
    public let updatedAt: Date?

    public init(
        path: String,
        name: String,
        isRootFolder: Bool,
        folderCount: Int,
        videoCount: Int,
        subtitleCount: Int,
        addedAt: Date?,
        updatedAt: Date?
    ) {
        self.path = path
        self.name = name
        self.isRootFolder = isRootFolder
        self.folderCount = folderCount
        self.videoCount = videoCount
        self.subtitleCount = subtitleCount
        self.addedAt = addedAt
        self.updatedAt = updatedAt
    }
}

extension LibraryDatabase {
    public func fileDetailVideoInfo(for videoPath: String) throws -> FileDetailVideoInfo? {
        let statement = try database.prepare(
            """
            SELECT vf.path, vf.video_name, vf.file_size, vf.duration,
                   vf.video_width, vf.video_height, vf.frame_rate,
                   vf.video_codec, vf.video_bit_depth, vf.video_pixel_format,
                   vf.audio_tracks, vf.modified_at
            FROM video_files vf
            WHERE vf.path = ?;
            """
        )
        try statement.bind(videoPath, at: 1)
        guard try statement.step() else {
            return nil
        }
        let path = statement.stringColumn(0)
        let name = statement.stringColumn(1)
        let dbFileSize = statement.nullableInt64Column(2) ?? 0
        let duration = statement.nullableDoubleColumn(3)
        let videoWidth = statement.nullableIntColumn(4)
        let videoHeight = statement.nullableIntColumn(5)
        let frameRate = statement.nullableDoubleColumn(6)
        let videoCodec = statement.nullableStringColumn(7)
        let videoBitDepth = statement.nullableIntColumn(8)
        let videoPixelFormat = statement.nullableStringColumn(9)
        let tracks = statement.nullableStringColumn(10)
            .flatMap { try? JSONDecoder().decode([VideoAudioTrack].self, from: Data($0.utf8)) }
            ?? []
        let modifiedAtSec = statement.nullableDoubleColumn(11)
        let dbModifiedDate = modifiedAtSec.map { Date(timeIntervalSince1970: $0) }

        let fileURL = URL.fromMediaPath(path)
        let attributes = path.isRemoteMediaPath
            ? nil
            : (try? FileManager.default.attributesOfItem(atPath: path))
        let createdDate = attributes?[.creationDate] as? Date
        let modifiedDate = (attributes?[.modificationDate] as? Date) ?? dbModifiedDate
        let fileSize = (attributes?[.size] as? NSNumber)?.int64Value ?? dbFileSize

        let subtitles = (try? videoSubtitles(forVideoFile: fileURL))?.subtitles ?? []

        return FileDetailVideoInfo(
            path: path,
            name: name,
            fileSize: fileSize,
            duration: duration,
            videoWidth: videoWidth,
            videoHeight: videoHeight,
            frameRate: frameRate,
            videoCodec: videoCodec,
            videoBitDepth: videoBitDepth,
            videoPixelFormat: videoPixelFormat,
            audioTracks: tracks,
            subtitles: subtitles,
            createdAt: createdDate,
            modifiedAt: modifiedDate
        )
    }

    public func fileDetailSubtitleInfo(for subtitlePath: String) throws -> FileDetailSubtitleInfo? {
        let statement = try database.prepare(
            """
            SELECT sf.id, sf.subtitle_path, sf.format, sf.file_size, sf.modified_at,
                   sf.raw_cue_count, vf.path AS video_path
            FROM subtitle_files sf
            LEFT JOIN subtitle_video_matches m
              ON m.subtitle_file_id = sf.id AND m.is_active = 1
            LEFT JOIN video_files vf
              ON vf.id = m.video_file_id
            WHERE sf.subtitle_path = ?;
            """
        )
        try statement.bind(subtitlePath, at: 1)
        guard try statement.step() else {
            return nil
        }
        let subtitleFileID = statement.int64Column(0)
        let path = statement.stringColumn(1)
        let format = SubtitleFormat(rawValue: statement.stringColumn(2)) ?? .srt
        let dbFileSize = statement.nullableInt64Column(3) ?? 0
        let dbModifiedDate = statement.nullableDoubleColumn(4).map { Date(timeIntervalSince1970: $0) }
        let dbRawCueCount = statement.nullableIntColumn(5)
        let videoPath = statement.nullableStringColumn(6)

        let cueStatement = try database.prepare(
            """
            SELECT COUNT(*)
            FROM subtitle_cue_lines
            WHERE subtitle_file_id = ?;
            """
        )
        try cueStatement.bind(subtitleFileID, at: 1)
        let cueCount = try cueStatement.step() ? cueStatement.intColumn(0) : 0

        let attributes = path.isRemoteMediaPath
            ? nil
            : (try? FileManager.default.attributesOfItem(atPath: path))
        let createdDate = attributes?[.creationDate] as? Date
        let modifiedDate = (attributes?[.modificationDate] as? Date) ?? dbModifiedDate
        let fileSize = (attributes?[.size] as? NSNumber)?.int64Value ?? dbFileSize

        let subtitleURL = URL.fromMediaPath(path)
        let encoding: String
        let fallbackRawCueCount: Int?
        if let data = try? WebDAVSubtitleCache.shared.readSubtitleData(from: subtitleURL) {
            encoding = SubtitleTextDecoder.detectedEncodingName(in: data)
            if dbRawCueCount == nil,
               let contents = try? SubtitleTextDecoder.decode(data, format: format) {
                fallbackRawCueCount = SubtitleRawCueCounter.count(in: contents, format: format)
            } else {
                fallbackRawCueCount = nil
            }
        } else {
            encoding = "UTF-8"
            fallbackRawCueCount = nil
        }

        let rawCueCount = dbRawCueCount ?? fallbackRawCueCount ?? cueCount

        return FileDetailSubtitleInfo(
            path: path,
            name: subtitleURL.lastPathComponent,
            fileSize: fileSize,
            format: format,
            encoding: encoding,
            cueCount: cueCount,
            rawCueCount: rawCueCount,
            associatedVideoPath: videoPath,
            createdAt: createdDate,
            modifiedAt: modifiedDate
        )
    }

    public func fileDetailFolderInfo(
        for folderPath: String,
        name: String? = nil,
        isRootFolder: Bool
    ) throws -> FileDetailFolderInfo {
        let (standardizedPath, defaultName, variants, pathPrefixes) = Self.folderScopeStrings(for: folderPath)
        let resolvedName = name ?? defaultName

        var folderCount = isRootFolder ? 0 : 1
        var videoCount = 0
        var subtitleCount = 0

        if !pathPrefixes.isEmpty {
            let scopeCondition = pathPrefixes.map { _ in
                "(sf.subtitle_path >= ? AND sf.subtitle_path < ?)"
            }.joined(separator: " OR ")

            if isRootFolder {
                let statement = try database.prepare(
                    """
                    SELECT COUNT(DISTINCT COALESCE(CAST(vf.folder_id AS TEXT), rtrim(substr(vf.path, 1, length(vf.path) - length(vf.video_name)), '/'))),
                           COUNT(DISTINCT vf.id),
                           COUNT(DISTINCT sf.id)
                    FROM subtitle_files sf INDEXED BY idx_subtitle_files_subtitle_path
                    JOIN subtitle_video_matches m ON m.subtitle_file_id = sf.id AND m.is_active = 1
                    JOIN video_files vf ON vf.id = m.video_file_id
                    WHERE (\(scopeCondition));
                    """
                )
                var bindIndex: Int32 = 1
                for prefix in pathPrefixes {
                    try statement.bind(prefix, at: bindIndex)
                    bindIndex += 1
                    try statement.bind(Self.pathPrefixUpperBound(for: prefix), at: bindIndex)
                    bindIndex += 1
                }
                if try statement.step() {
                    folderCount = statement.intColumn(0)
                    videoCount = statement.intColumn(1)
                    subtitleCount = statement.intColumn(2)
                }
            } else if !variants.isEmpty {
                let variantPlaceholders = variants.map { _ in "?" }.joined(separator: ", ")
                let statement = try database.prepare(
                    """
                    SELECT COUNT(DISTINCT vf.id),
                           COUNT(DISTINCT sf.id)
                    FROM subtitle_files sf INDEXED BY idx_subtitle_files_subtitle_path
                    JOIN subtitle_video_matches m ON m.subtitle_file_id = sf.id AND m.is_active = 1
                    JOIN video_files vf ON vf.id = m.video_file_id
                    WHERE (\(scopeCondition))
                      AND rtrim(substr(vf.path, 1, length(vf.path) - length(vf.video_name)), '/') IN (\(variantPlaceholders));
                    """
                )
                var bindIndex: Int32 = 1
                for prefix in pathPrefixes {
                    try statement.bind(prefix, at: bindIndex)
                    bindIndex += 1
                    try statement.bind(Self.pathPrefixUpperBound(for: prefix), at: bindIndex)
                    bindIndex += 1
                }
                for variant in variants {
                    try statement.bind(variant, at: bindIndex)
                    bindIndex += 1
                }
                if try statement.step() {
                    videoCount = statement.intColumn(0)
                    subtitleCount = statement.intColumn(1)
                }
            }
        }

        let (addedAt, updatedAt) = try folderDetailTimestamps(
            variants: variants,
            pathPrefixes: pathPrefixes,
            isRootFolder: isRootFolder
        )

        return FileDetailFolderInfo(
            path: standardizedPath,
            name: resolvedName,
            isRootFolder: isRootFolder,
            folderCount: folderCount,
            videoCount: videoCount,
            subtitleCount: subtitleCount,
            addedAt: addedAt,
            updatedAt: updatedAt
        )
    }

    private static func folderScopeStrings(
        for folderPath: String
    ) -> (standardizedPath: String, name: String, variants: [String], prefixes: [String]) {
        if folderPath.isRemoteMediaPath {
            let folderURL = URL.fromMediaPath(folderPath).standardizedMediaURL
            let standardizedPath = folderURL.mediaPath
            return (
                standardizedPath,
                folderURL.lastPathComponent,
                MediaFolderPathMatching.folderPathVariants(forPath: standardizedPath),
                MediaFolderPathMatching.folderPathPrefixes(forPath: standardizedPath)
            )
        }
        let normalized = MediaFolderPathMatching.normalizedFolderPath(folderPath)
        let name = (normalized as NSString).lastPathComponent
        return (
            normalized,
            name,
            MediaFolderPathMatching.folderPathVariants(forPath: normalized),
            MediaFolderPathMatching.folderPathPrefixes(forPath: normalized)
        )
    }

    private func folderDetailTimestamps(
        variants: [String],
        pathPrefixes: [String],
        isRootFolder: Bool
    ) throws -> (addedAt: Date?, updatedAt: Date?) {
        guard !variants.isEmpty else {
            return (nil, nil)
        }
        let placeholders = variants.map { _ in "?" }.joined(separator: ", ")

        if isRootFolder {
            let rootStatement = try database.prepare(
                """
                SELECT created_at, updated_at
                FROM library_root_folders
                WHERE path IN (\(placeholders))
                LIMIT 1;
                """
            )
            for (offset, variant) in variants.enumerated() {
                try rootStatement.bind(variant, at: Int32(offset + 1))
            }
            if try rootStatement.step() {
                let created = Self.parseISO8601Date(rootStatement.stringColumn(0))
                let updated = Self.parseISO8601Date(rootStatement.stringColumn(1)) ?? created
                if created != nil || updated != nil {
                    return (created, updated)
                }
            }

            let spStatement = try database.prepare(
                """
                SELECT created_at,
                       COALESCE(NULLIF(last_successful_index_at, ''), NULLIF(updated_at, ''), created_at)
                FROM search_paths
                WHERE path IN (\(placeholders))
                LIMIT 1;
                """
            )
            for (offset, variant) in variants.enumerated() {
                try spStatement.bind(variant, at: Int32(offset + 1))
            }
            if try spStatement.step() {
                let created = Self.parseISO8601Date(spStatement.stringColumn(0))
                let updated = Self.parseISO8601Date(spStatement.stringColumn(1)) ?? created
                return (created, updated)
            }

            let allSearchPaths = try database.prepare(
                """
                SELECT path,
                       created_at,
                       COALESCE(NULLIF(last_successful_index_at, ''), NULLIF(updated_at, ''), created_at)
                FROM search_paths
                ORDER BY LENGTH(path) DESC, id ASC;
                """
            )
            while try allSearchPaths.step() {
                let outerPath = allSearchPaths.stringColumn(0)
                let (_, _, _, outerPrefixes) = Self.folderScopeStrings(for: outerPath)
                if variants.contains(where: { variant in
                    MediaFolderPathMatching.pathMatchesPrefixes(variant, prefixes: outerPrefixes)
                }) {
                    let outerCreated = Self.parseISO8601Date(allSearchPaths.stringColumn(1))
                    let outerUpdated = Self.parseISO8601Date(allSearchPaths.stringColumn(2)) ?? outerCreated
                    let earliestSubtitleIndexed = try earliestSubtitleIndexedDate(
                        pathPrefixes: pathPrefixes
                    )
                    return (earliestSubtitleIndexed ?? outerCreated, outerUpdated)
                }
            }
            return (nil, nil)
        }

        let folderStatement = try database.prepare(
            """
            SELECT lf.id,
                   lf.created_at,
                   lf.updated_at,
                   sp.created_at,
                   COALESCE(NULLIF(sp.last_successful_index_at, ''), NULLIF(sp.updated_at, ''), sp.created_at)
            FROM library_folders lf
            JOIN search_paths sp ON sp.id = lf.library_id
            WHERE rtrim(sp.path || '/' || lf.relative_path, '/') IN (\(placeholders))
            LIMIT 1;
            """
        )
        for (offset, variant) in variants.enumerated() {
            try folderStatement.bind(variant, at: Int32(offset + 1))
        }
        if try folderStatement.step() {
            let folderID = folderStatement.int64Column(0)
            let rawCreated = folderStatement.stringColumn(1)
            let rawUpdated = folderStatement.stringColumn(2)
            let spCreated = Self.parseISO8601Date(folderStatement.stringColumn(3))
            let spUpdated = Self.parseISO8601Date(folderStatement.stringColumn(4)) ?? spCreated

            let created: Date?
            if let parsed = Self.parseISO8601Date(rawCreated) {
                created = parsed
            } else {
                created = try earliestSubtitleIndexedDate(forFolderID: folderID) ?? spCreated
            }

            let updated: Date?
            if let parsed = Self.parseISO8601Date(rawUpdated) {
                updated = parsed
            } else {
                updated = spUpdated ?? created
            }
            return (created, updated)
        }

        let earliest = try earliestSubtitleIndexedDate(pathPrefixes: pathPrefixes)
        return (earliest, earliest)
    }

    private func earliestSubtitleIndexedDate(forFolderID folderID: Int64) throws -> Date? {
        let statement = try database.prepare(
            """
            SELECT MIN(indexed_at)
            FROM subtitle_files
            WHERE folder_id = ? AND indexed_at != '';
            """
        )
        try statement.bind(folderID, at: 1)
        guard try statement.step(),
              let raw = statement.nullableStringColumn(0)
        else {
            return nil
        }
        return Self.parseISO8601Date(raw)
    }

    private func earliestSubtitleIndexedDate(pathPrefixes: [String]) throws -> Date? {
        guard !pathPrefixes.isEmpty else {
            return nil
        }
        let scopeCondition = pathPrefixes.map { _ in
            "(subtitle_path >= ? AND subtitle_path < ?)"
        }.joined(separator: " OR ")
        let statement = try database.prepare(
            """
            SELECT MIN(indexed_at)
            FROM subtitle_files INDEXED BY idx_subtitle_files_subtitle_path
            WHERE (\(scopeCondition)) AND indexed_at != '';
            """
        )
        var bindIndex: Int32 = 1
        for prefix in pathPrefixes {
            try statement.bind(prefix, at: bindIndex)
            bindIndex += 1
            try statement.bind(Self.pathPrefixUpperBound(for: prefix), at: bindIndex)
            bindIndex += 1
        }
        guard try statement.step(),
              let raw = statement.nullableStringColumn(0)
        else {
            return nil
        }
        return Self.parseISO8601Date(raw)
    }

    private static func parseISO8601Date(_ raw: String) -> Date? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: trimmed) {
            return date
        }
        return ISO8601DateFormatter().date(from: trimmed)
    }
}
