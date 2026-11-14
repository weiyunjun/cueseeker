import Foundation

public final class IndexedContentDatabase: @unchecked Sendable {
    private let libraryDatabase: LibraryDatabase

    private var database: SQLiteDatabase {
        libraryDatabase.database
    }

    public init(
        path: URL,
        access: DatabaseConnectionAccess = .readOnly
    ) throws {
        libraryDatabase = try LibraryDatabase(path: path, access: access)
    }

    public func contentTree() throws -> [IndexedContentRoot] {
        var roots = try loadRootBuilders()
        let rootIndexes = Dictionary(
            uniqueKeysWithValues: roots.enumerated().map {
                ($0.element.id, $0.offset)
            }
        )
        let videoLocations = try loadVideoLocations()
        let libraryFolders = try libraryDatabase.libraryPresentation(
            under: roots.map { URL.fromMediaPath($0.path) }
        )
        var objectLocations: [Int64: ObjectLocation] = [:]

        for libraryFolder in libraryFolders {
            guard
                let firstVideo = libraryFolder.videos.first,
                let videoLocation = videoLocations[firstVideo.videoFileID],
                let rootIndex = rootIndexes[videoLocation.rootID]
            else {
                continue
            }

            let folderIndex = roots[rootIndex].folders.count
            roots[rootIndex].folders.append(FolderBuilder(
                id: videoLocation.folderID,
                relativePath: videoLocation.relativePath,
                folderPath: libraryFolder.folderPath,
                objects: libraryFolder.videos.map { video in
                    ObjectBuilder(
                        id: video.videoFileID,
                        displayTitle: video.displayTitle,
                        videoPath: video.videoPath,
                        videoName: video.videoName,
                        fileSize: videoLocations[video.videoFileID]?.fileSize,
                        videoWidth: videoLocations[video.videoFileID]?.videoWidth,
                        videoHeight: videoLocations[video.videoFileID]?.videoHeight,
                        videoCodec: videoLocations[video.videoFileID]?.videoCodec,
                        duration: videoLocations[video.videoFileID]?.duration,
                        subtitles: []
                    )
                }
            ))

            for (objectIndex, video) in libraryFolder.videos.enumerated() {
                objectLocations[video.videoFileID] = ObjectLocation(
                    rootIndex: rootIndex,
                    folderIndex: folderIndex,
                    objectIndex: objectIndex
                )
            }
        }

        try loadSubtitles(into: &roots, objectLocations: objectLocations)
        return roots.map(\.snapshot)
    }

    /// Returns the folders under a specific root folder without loading objects or subtitles.
    public func subfolders(under rootURL: URL) throws -> [IndexedContentFolder] {
        let roots = try loadRootBuilders()
        let standardizedRootURL = rootURL.standardizedMediaURL
        let standardizedRootPath = standardizedRootURL.mediaPath
        let exactMatch = roots.first(where: {
            $0.path == rootURL.mediaPath
                || URL.fromMediaPath($0.path).mediaPath == rootURL.mediaPath
                || URL.fromMediaPath($0.path).standardizedMediaURL.mediaPath == standardizedRootPath
        })
        guard let root = exactMatch ?? roots.first(where: {
            LibraryRootGroups.holds(
                URL.fromMediaPath($0.path).standardizedMediaURL,
                standardizedRootURL
            )
        }) else {
            return []
        }

        let statement = try database.prepare(
            """
            SELECT lf.id,
                   lf.relative_path,
                   lvr.folder_path,
                   lvr.folder_title
            FROM library_video_rows lvr
            JOIN video_files vf ON vf.id = lvr.video_file_id
            JOIN library_folders lf ON lf.id = vf.folder_id
            WHERE vf.library_id = ?
            GROUP BY lf.id, lf.relative_path, lvr.folder_path, lvr.folder_title
            ORDER BY lvr.folder_title COLLATE NOCASE ASC, lvr.folder_path COLLATE NOCASE ASC;
            """
        )
        try statement.bind(root.id, at: 1)

        let isNestedRoot = exactMatch == nil
        let rootPrefix = standardizedRootPath.hasSuffix("/")
            ? standardizedRootPath
            : standardizedRootPath + "/"

        var folders: [IndexedContentFolder] = []
        while try statement.step() {
            let folderID = statement.int64Column(0)
            let rawRelativePath = statement.stringColumn(1)
            let folderPath = statement.stringColumn(2)
            if isNestedRoot {
                let standardizedFolderURL = URL.fromMediaPath(folderPath).standardizedMediaURL
                guard LibraryRootGroups.holds(standardizedRootURL, standardizedFolderURL) else {
                    continue
                }
                let standardizedFolderPath = standardizedFolderURL.mediaPath
                let relativePath: String
                if standardizedFolderPath == standardizedRootPath {
                    relativePath = ""
                } else if standardizedFolderPath.hasPrefix(rootPrefix) {
                    relativePath = String(standardizedFolderPath.dropFirst(rootPrefix.count))
                } else {
                    relativePath = rawRelativePath
                }
                folders.append(IndexedContentFolder(
                    id: folderID,
                    relativePath: relativePath,
                    folderPath: folderPath,
                    objects: []
                ))
            } else {
                folders.append(IndexedContentFolder(
                    id: folderID,
                    relativePath: rawRelativePath,
                    folderPath: folderPath,
                    objects: []
                ))
            }
        }
        return folders.sorted { lhs, rhs in
            let lhsTitle = URL.fromMediaPath(lhs.folderPath).lastPathComponent
            let rhsTitle = URL.fromMediaPath(rhs.folderPath).lastPathComponent
            let titleComparison = lhsTitle.localizedStandardCompare(rhsTitle)
            if titleComparison != .orderedSame {
                return titleComparison == .orderedAscending
            }
            return lhs.folderPath.localizedStandardCompare(rhs.folderPath) == .orderedAscending
        }
    }

    /// Returns the indexed objects (videos with subtitles) in a specific folder.
    public func objects(in folderPath: String) throws -> [IndexedContentObject] {
        let standardized = URL.fromMediaPath(folderPath).mediaPath
        let statement = try database.prepare(
            """
            SELECT lvr.video_file_id,
                   lvr.display_title,
                   lvr.video_path,
                   lvr.video_name,
                   vf.file_size,
                   vf.video_width,
                   vf.video_height,
                   vf.video_codec,
                   vf.duration
            FROM library_video_rows lvr
            JOIN video_files vf ON vf.id = lvr.video_file_id
            WHERE lvr.folder_path = ? OR lvr.folder_path = ?
            ORDER BY lvr.video_order ASC, lvr.video_path ASC;
            """
        )
        try statement.bind(folderPath, at: 1)
        try statement.bind(standardized, at: 2)

        var objects: [IndexedContentObject] = []
        var videoIDs: [Int64] = []
        var objectIndices: [Int64: Int] = [:]

        var index = 0
        while try statement.step() {
            guard let videoFileID = statement.nullableInt64Column(0) else {
                continue
            }
            let displayTitle = statement.stringColumn(1)
            let videoPath = statement.stringColumn(2)
            let videoName = statement.stringColumn(3)

            objects.append(IndexedContentObject(
                id: videoFileID,
                displayTitle: displayTitle,
                videoPath: videoPath,
                videoName: videoName,
                fileSize: statement.nullableInt64Column(4),
                videoWidth: statement.nullableIntColumn(5),
                videoHeight: statement.nullableIntColumn(6),
                videoCodec: statement.nullableStringColumn(7),
                duration: statement.nullableDoubleColumn(8),
                subtitles: []
            ))
            videoIDs.append(videoFileID)
            objectIndices[videoFileID] = index
            index += 1
        }

        try loadSubtitles(for: videoIDs, into: &objects, objectIndices: objectIndices)
        return objects
    }

    private func loadRootBuilders() throws -> [RootBuilder] {
        let statement = try database.prepare(
            """
            SELECT sp.id,
                   sp.path
            FROM search_paths sp
            ORDER BY sp.path ASC;
            """
        )

        var roots: [RootBuilder] = []
        while try statement.step() {
            roots.append(RootBuilder(
                id: statement.int64Column(0),
                path: statement.stringColumn(1),
                folders: []
            ))
        }
        return roots
    }

    private func loadVideoLocations(forRootID rootID: Int64? = nil) throws -> [Int64: VideoLocation] {
        let fromClause = rootID == nil
            ? "FROM search_paths sp JOIN video_files vf ON vf.library_id = sp.id"
            : "FROM video_files vf"
        let whereClause = rootID == nil ? "" : "WHERE vf.library_id = ?"
        let sql = """
            SELECT vf.id,
                   vf.library_id,
                   vf.folder_id,
                   lf.relative_path,
                   vf.file_size,
                   vf.video_width,
                   vf.video_height,
                   vf.video_codec,
                   vf.duration
            \(fromClause)
            JOIN library_folders lf
              ON lf.id = vf.folder_id
            \(whereClause);
            """
        let statement = try database.prepare(sql)
        if let rootID {
            try statement.bind(rootID, at: 1)
        }

        var locations: [Int64: VideoLocation] = [:]
        while try statement.step() {
            locations[statement.int64Column(0)] = VideoLocation(
                rootID: statement.int64Column(1),
                folderID: statement.int64Column(2),
                relativePath: statement.stringColumn(3),
                fileSize: statement.nullableInt64Column(4),
                videoWidth: statement.nullableIntColumn(5),
                videoHeight: statement.nullableIntColumn(6),
                videoCodec: statement.nullableStringColumn(7),
                duration: statement.nullableDoubleColumn(8)
            )
        }
        return locations
    }

    private func loadSubtitles(
        for videoIDs: [Int64],
        into objects: inout [IndexedContentObject],
        objectIndices: [Int64: Int]
    ) throws {
        guard !videoIDs.isEmpty else { return }
        let placeholders = Array(repeating: "?", count: videoIDs.count).joined(separator: ", ")
        let statement = try database.prepare(
            """
            SELECT match.video_file_id,
                   sf.id,
                   sf.subtitle_path,
                   sf.format,
                   sf.file_size,
                   sf.raw_cue_count
            FROM subtitle_video_matches match
            JOIN subtitle_files sf
              ON sf.id = match.subtitle_file_id
            WHERE match.is_active = 1
              AND match.video_file_id IN (\(placeholders))
            ORDER BY match.video_file_id ASC,
                     sf.subtitle_path ASC,
                     sf.id ASC;
            """
        )
        for (i, id) in videoIDs.enumerated() {
            try statement.bind(id, at: Int32(i + 1))
        }
        let parsed = try readMatchedSubtitles(from: statement, filteringVideoID: { _ in true })
        for (videoID, subs) in parsed {
            if let index = objectIndices[videoID] {
                let sortedSubs = Self.sortedSubtitles(subs, forVideoPath: objects[index].videoPath)
                objects[index] = objects[index].withSubtitles(sortedSubs)
            }
        }
    }

    private func loadSubtitles(
        into roots: inout [RootBuilder],
        objectLocations: [Int64: ObjectLocation]
    ) throws {
        let statement = try database.prepare(
            """
            SELECT match.video_file_id,
                   sf.id,
                   sf.subtitle_path,
                   sf.format,
                   sf.file_size,
                   sf.raw_cue_count
            FROM subtitle_video_matches match
            JOIN subtitle_files sf
              ON sf.id = match.subtitle_file_id
            WHERE match.is_active = 1
            ORDER BY match.video_file_id ASC,
                     sf.subtitle_path ASC,
                     sf.id ASC;
            """
        )

        let parsed = try readMatchedSubtitles(
            from: statement,
            filteringVideoID: { objectLocations[$0] != nil }
        )

        for (videoID, subs) in parsed {
            guard let objectLocation = objectLocations[videoID] else {
                continue
            }
            let videoPath = roots[objectLocation.rootIndex]
                .folders[objectLocation.folderIndex]
                .objects[objectLocation.objectIndex]
                .videoPath
            let sortedSubs = Self.sortedSubtitles(subs, forVideoPath: videoPath)
            roots[objectLocation.rootIndex]
                .folders[objectLocation.folderIndex]
                .objects[objectLocation.objectIndex]
                .subtitles = sortedSubs
        }
    }

    private func readMatchedSubtitles(
        from statement: SQLiteStatement,
        filteringVideoID: (Int64) -> Bool
    ) throws -> [Int64: [(subtitle: IndexedContentSubtitle, format: SubtitleFormat)]] {
        var subtitlesByVideoID: [Int64: [(subtitle: IndexedContentSubtitle, format: SubtitleFormat)]] = [:]
        var subtitleIDs: [Int64] = []

        while try statement.step() {
            let videoID = statement.int64Column(0)
            guard filteringVideoID(videoID) else {
                continue
            }

            let subtitleID = statement.int64Column(1)
            let subtitlePath = statement.stringColumn(2)
            let format = SubtitleFormat(rawValue: statement.stringColumn(3)) ?? .srt
            subtitleIDs.append(subtitleID)
            subtitlesByVideoID[videoID, default: []].append((
                subtitle: IndexedContentSubtitle(
                    id: subtitleID,
                    path: subtitlePath,
                    name: URL.fromMediaPath(subtitlePath).lastPathComponent,
                    fileSize: statement.nullableInt64Column(4),
                    rawCueCount: statement.nullableIntColumn(5)
                ),
                format: format
            ))
        }

        let validCueCounts = try loadValidCueCounts(for: subtitleIDs)
        for videoID in subtitlesByVideoID.keys {
            subtitlesByVideoID[videoID] = subtitlesByVideoID[videoID]?.map { entry in
                (
                    subtitle: entry.subtitle.withValidCueCount(validCueCounts[entry.subtitle.id] ?? 0),
                    format: entry.format
                )
            }
        }
        return subtitlesByVideoID
    }

    /// Queries valid cue counts directly from `subtitle_cue_lines` using the
    /// `subtitle_file_id` foreign-key index without joining intermediate group tables.
    private func loadValidCueCounts(for subtitleIDs: [Int64]) throws -> [Int64: Int] {
        let uniqueIDs = Array(Set(subtitleIDs)).sorted()
        guard !uniqueIDs.isEmpty else { return [:] }

        let batchSize = 500
        var counts: [Int64: Int] = [:]
        var startIndex = 0
        while startIndex < uniqueIDs.count {
            let endIndex = min(startIndex + batchSize, uniqueIDs.count)
            let batch = Array(uniqueIDs[startIndex..<endIndex])
            let placeholders = Array(repeating: "?", count: batch.count).joined(separator: ", ")
            let statement = try database.prepare(
                """
                SELECT subtitle_file_id, COUNT(*)
                FROM subtitle_cue_lines
                WHERE subtitle_file_id IN (\(placeholders))
                GROUP BY subtitle_file_id;
                """
            )
            for (offset, subtitleID) in batch.enumerated() {
                try statement.bind(subtitleID, at: Int32(offset + 1))
            }
            while try statement.step() {
                if let subtitleID = statement.nullableInt64Column(0) {
                    counts[subtitleID] = statement.intColumn(1)
                }
            }
            startIndex = endIndex
        }
        return counts
    }

    private static func sortedSubtitles(
        _ subtitles: [(subtitle: IndexedContentSubtitle, format: SubtitleFormat)],
        forVideoPath videoPath: String
    ) -> [IndexedContentSubtitle] {
        subtitles.sorted { lhs, rhs in
            VideoSubtitles.compareSubtitles(
                lhsSubtitlePath: lhs.subtitle.path,
                lhsFormat: lhs.format,
                rhsSubtitlePath: rhs.subtitle.path,
                rhsFormat: rhs.format,
                forVideoPath: videoPath
            )
        }.map(\.subtitle)
    }
}

private struct RootBuilder {
    let id: Int64
    let path: String
    var folders: [FolderBuilder]

    var snapshot: IndexedContentRoot {
        IndexedContentRoot(
            id: id,
            path: path,
            folders: folders.map(\.snapshot)
        )
    }
}

private struct FolderBuilder {
    let id: Int64
    let relativePath: String
    let folderPath: String
    var objects: [ObjectBuilder]

    var snapshot: IndexedContentFolder {
        IndexedContentFolder(
            id: id,
            relativePath: relativePath,
            folderPath: folderPath,
            objects: objects.map(\.snapshot)
        )
    }
}

private struct ObjectBuilder {
    let id: Int64
    let displayTitle: String
    let videoPath: String
    let videoName: String
    let fileSize: Int64?
    let videoWidth: Int?
    let videoHeight: Int?
    let videoCodec: String?
    let duration: Double?
    var subtitles: [IndexedContentSubtitle]

    var snapshot: IndexedContentObject {
        IndexedContentObject(
            id: id,
            displayTitle: displayTitle,
            videoPath: videoPath,
            videoName: videoName,
            fileSize: fileSize,
            videoWidth: videoWidth,
            videoHeight: videoHeight,
            videoCodec: videoCodec,
            duration: duration,
            subtitles: subtitles
        )
    }
}

private struct VideoLocation {
    let rootID: Int64
    let folderID: Int64
    let relativePath: String
    let fileSize: Int64?
    let videoWidth: Int?
    let videoHeight: Int?
    let videoCodec: String?
    let duration: Double?
}

private struct ObjectLocation {
    let rootIndex: Int
    let folderIndex: Int
    let objectIndex: Int
}
