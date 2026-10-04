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
            under: roots.map { URL(fileURLWithPath: $0.path) }
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
                        fileSize: videoLocations[video.videoFileID]?.fileSize ?? 0,
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
        guard let root = roots.first(where: {
            $0.path == rootURL.path
                || URL(fileURLWithPath: $0.path).standardizedFileURL.path == rootURL.standardizedFileURL.path
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

        var folders: [IndexedContentFolder] = []
        while try statement.step() {
            folders.append(IndexedContentFolder(
                id: statement.int64Column(0),
                relativePath: statement.stringColumn(1),
                folderPath: statement.stringColumn(2),
                objects: []
            ))
        }
        return folders
    }

    /// Returns the indexed objects (videos with subtitles) in a specific folder.
    public func objects(in folderPath: String) throws -> [IndexedContentObject] {
        let standardized = URL(fileURLWithPath: folderPath).standardizedFileURL.path
        let statement = try database.prepare(
            """
            SELECT lvr.video_file_id,
                   lvr.display_title,
                   lvr.video_path,
                   lvr.video_name,
                   COALESCE(vf.file_size, 0)
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
            let fileSize = statement.int64Column(4)

            objects.append(IndexedContentObject(
                id: videoFileID,
                displayTitle: displayTitle,
                videoPath: videoPath,
                videoName: videoName,
                fileSize: fileSize,
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
        let sql: String
        if let rootID {
            sql = """
            SELECT vf.id,
                   vf.library_id,
                   vf.folder_id,
                   lf.relative_path,
                   COALESCE(vf.file_size, 0)
            FROM video_files vf
            JOIN library_folders lf
              ON lf.id = vf.folder_id
            WHERE vf.library_id = ?;
            """
        } else {
            sql = """
            SELECT vf.id,
                   vf.library_id,
                   vf.folder_id,
                   lf.relative_path,
                   COALESCE(vf.file_size, 0)
            FROM search_paths sp
            JOIN video_files vf
              ON vf.library_id = sp.id
            JOIN library_folders lf
              ON lf.id = vf.folder_id;
            """
        }
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
                fileSize: statement.int64Column(4)
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
                   COALESCE(sf.file_size, 0)
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
        var subtitlesByVideoID: [Int64: [IndexedContentSubtitle]] = [:]
        while try statement.step() {
            let videoID = statement.int64Column(0)
            let subtitlePath = statement.stringColumn(2)
            subtitlesByVideoID[videoID, default: []].append(IndexedContentSubtitle(
                id: statement.int64Column(1),
                path: subtitlePath,
                name: URL(fileURLWithPath: subtitlePath).lastPathComponent,
                fileSize: statement.int64Column(3)
            ))
        }
        for (videoID, subs) in subtitlesByVideoID {
            if let index = objectIndices[videoID] {
                objects[index] = IndexedContentObject(
                    id: objects[index].id,
                    displayTitle: objects[index].displayTitle,
                    videoPath: objects[index].videoPath,
                    videoName: objects[index].videoName,
                    fileSize: objects[index].fileSize,
                    subtitles: subs
                )
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
                   COALESCE(sf.file_size, 0)
            FROM subtitle_video_matches match
            JOIN subtitle_files sf
              ON sf.id = match.subtitle_file_id
            WHERE match.is_active = 1
            ORDER BY match.video_file_id ASC,
                     sf.subtitle_path ASC,
                     sf.id ASC;
            """
        )

        while try statement.step() {
            let videoID = statement.int64Column(0)
            guard let objectLocation = objectLocations[videoID] else {
                continue
            }

            let subtitlePath = statement.stringColumn(2)
            roots[objectLocation.rootIndex]
                .folders[objectLocation.folderIndex]
                .objects[objectLocation.objectIndex]
                .subtitles.append(IndexedContentSubtitle(
                    id: statement.int64Column(1),
                    path: subtitlePath,
                    name: URL(fileURLWithPath: subtitlePath).lastPathComponent,
                    fileSize: statement.int64Column(3)
                ))
        }
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
    let fileSize: Int64
    var subtitles: [IndexedContentSubtitle]

    var snapshot: IndexedContentObject {
        IndexedContentObject(
            id: id,
            displayTitle: displayTitle,
            videoPath: videoPath,
            videoName: videoName,
            fileSize: fileSize,
            subtitles: subtitles
        )
    }
}

private struct VideoLocation {
    let rootID: Int64
    let folderID: Int64
    let relativePath: String
    let fileSize: Int64
}

private struct ObjectLocation {
    let rootIndex: Int
    let folderIndex: Int
    let objectIndex: Int
}
