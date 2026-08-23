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
                objects: libraryFolder.videos.map { video in
                    ObjectBuilder(
                        id: video.videoFileID,
                        displayTitle: video.displayTitle,
                        videoPath: video.videoPath,
                        videoName: video.videoName,
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

    private func loadVideoLocations() throws -> [Int64: VideoLocation] {
        let statement = try database.prepare(
            """
            SELECT vf.id,
                   vf.library_id,
                   vf.folder_id,
                   lf.relative_path
            FROM search_paths sp
            JOIN video_files vf
              ON vf.library_id = sp.id
            JOIN library_folders lf
              ON lf.id = vf.folder_id;
            """
        )

        var locations: [Int64: VideoLocation] = [:]
        while try statement.step() {
            locations[statement.int64Column(0)] = VideoLocation(
                rootID: statement.int64Column(1),
                folderID: statement.int64Column(2),
                relativePath: statement.stringColumn(3)
            )
        }
        return locations
    }

    private func loadSubtitles(
        into roots: inout [RootBuilder],
        objectLocations: [Int64: ObjectLocation]
    ) throws {
        let statement = try database.prepare(
            """
            SELECT match.video_file_id,
                   sf.id,
                   sf.subtitle_path
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
                    name: URL(fileURLWithPath: subtitlePath).lastPathComponent
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
    var objects: [ObjectBuilder]

    var snapshot: IndexedContentFolder {
        IndexedContentFolder(
            id: id,
            relativePath: relativePath,
            objects: objects.map(\.snapshot)
        )
    }
}

private struct ObjectBuilder {
    let id: Int64
    let displayTitle: String
    let videoPath: String
    let videoName: String
    var subtitles: [IndexedContentSubtitle]

    var snapshot: IndexedContentObject {
        IndexedContentObject(
            id: id,
            displayTitle: displayTitle,
            videoPath: videoPath,
            videoName: videoName,
            subtitles: subtitles
        )
    }
}

private struct VideoLocation {
    let rootID: Int64
    let folderID: Int64
    let relativePath: String
}

private struct ObjectLocation {
    let rootIndex: Int
    let folderIndex: Int
    let objectIndex: Int
}
