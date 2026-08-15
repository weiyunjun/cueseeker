import Foundation

public final class IndexedContentDatabase: @unchecked Sendable {
    private let database: SQLiteDatabase

    public init(
        path: URL,
        access: DatabaseConnectionAccess = .readOnly
    ) throws {
        database = try SQLiteDatabase(path: path, access: access)
    }

    public func contentTree() throws -> [IndexedContentRoot] {
        var roots = try loadRootBuilders()
        let folderLocations = Self.folderLocations(in: roots)
        try loadObjects(into: &roots, folderLocations: folderLocations)
        return roots.map(\.snapshot)
    }

    private func loadRootBuilders() throws -> [RootBuilder] {
        let statement = try database.prepare(
            """
            WITH ordered_folders AS (
                SELECT lf.id,
                       lf.library_id,
                       lf.relative_path,
                       COALESCE(
                           (
                               SELECT MIN(lvr.folder_order)
                               FROM video_files sort_vf
                               JOIN library_video_rows lvr
                                 ON lvr.video_file_id = sort_vf.id
                               WHERE sort_vf.folder_id = lf.id
                                 AND sort_vf.binding_state = 'available'
                           ),
                           9223372036854775807
                       ) AS folder_order
                FROM library_folders lf
                WHERE lf.binding_state = 'available'
            )
            SELECT sp.id,
                   sp.path,
                   ordered_folders.id,
                   ordered_folders.relative_path
            FROM search_paths sp
            LEFT JOIN ordered_folders
              ON ordered_folders.library_id = sp.id
            WHERE sp.is_configured = 1
              AND sp.binding_state = 'available'
            ORDER BY sp.path ASC,
                     ordered_folders.folder_order ASC,
                     ordered_folders.relative_path COLLATE NOCASE ASC,
                     ordered_folders.id ASC;
            """
        )

        var roots: [RootBuilder] = []
        var rootIndexByID: [Int64: Int] = [:]
        while try statement.step() {
            let rootID = statement.int64Column(0)
            let rootIndex: Int
            if let existingIndex = rootIndexByID[rootID] {
                rootIndex = existingIndex
            } else {
                rootIndex = roots.count
                rootIndexByID[rootID] = rootIndex
                roots.append(RootBuilder(
                    id: rootID,
                    path: statement.stringColumn(1),
                    folders: []
                ))
            }

            guard let folderID = statement.nullableInt64Column(2) else {
                continue
            }
            roots[rootIndex].folders.append(FolderBuilder(
                id: folderID,
                relativePath: statement.stringColumn(3),
                objects: []
            ))
        }
        return roots
    }

    private static func folderLocations(
        in roots: [RootBuilder]
    ) -> [Int64: FolderLocation] {
        var locations: [Int64: FolderLocation] = [:]
        for (rootIndex, root) in roots.enumerated() {
            for (folderIndex, folder) in root.folders.enumerated() {
                locations[folder.id] = FolderLocation(
                    rootIndex: rootIndex,
                    folderIndex: folderIndex
                )
            }
        }
        return locations
    }

    private func loadObjects(
        into roots: inout [RootBuilder],
        folderLocations: [Int64: FolderLocation]
    ) throws {
        let statement = try database.prepare(
            """
            WITH ordered_folders AS (
                SELECT lf.id,
                       lf.library_id,
                       lf.relative_path,
                       COALESCE(
                           (
                               SELECT MIN(lvr.folder_order)
                               FROM video_files sort_vf
                               JOIN library_video_rows lvr
                                 ON lvr.video_file_id = sort_vf.id
                               WHERE sort_vf.folder_id = lf.id
                                 AND sort_vf.binding_state = 'available'
                           ),
                           9223372036854775807
                       ) AS folder_order
                FROM library_folders lf
                WHERE lf.binding_state = 'available'
            )
            SELECT ordered_folders.id,
                   vf.id,
                   vf.path,
                   vf.video_name,
                   CASE
                       WHEN TRIM(COALESCE(lvr.display_title, '')) = ''
                           THEN vf.video_name
                       ELSE lvr.display_title
                   END,
                   sf.id,
                   sf.subtitle_path
            FROM search_paths sp
            JOIN ordered_folders
              ON ordered_folders.library_id = sp.id
            JOIN video_files vf
              ON vf.folder_id = ordered_folders.id
             AND vf.binding_state = 'available'
            JOIN subtitle_video_matches match
              ON match.video_file_id = vf.id
             AND match.is_active = 1
            JOIN subtitle_files sf
              ON sf.id = match.subtitle_file_id
             AND sf.binding_state = 'available'
            LEFT JOIN library_video_rows lvr
              ON lvr.video_file_id = vf.id
            WHERE sp.is_configured = 1
              AND sp.binding_state = 'available'
            ORDER BY sp.path ASC,
                     ordered_folders.folder_order ASC,
                     ordered_folders.relative_path COLLATE NOCASE ASC,
                     COALESCE(lvr.video_order, 9223372036854775807) ASC,
                     vf.path ASC,
                     sf.subtitle_path ASC;
            """
        )

        var objectLocations: [Int64: ObjectLocation] = [:]
        while try statement.step() {
            let folderID = statement.int64Column(0)
            let videoID = statement.int64Column(1)
            guard let folderLocation = folderLocations[folderID] else {
                continue
            }

            let objectLocation: ObjectLocation
            if let existingLocation = objectLocations[videoID] {
                objectLocation = existingLocation
            } else {
                let objectIndex = roots[folderLocation.rootIndex]
                    .folders[folderLocation.folderIndex]
                    .objects.count
                objectLocation = ObjectLocation(
                    rootIndex: folderLocation.rootIndex,
                    folderIndex: folderLocation.folderIndex,
                    objectIndex: objectIndex
                )
                objectLocations[videoID] = objectLocation
                roots[objectLocation.rootIndex]
                    .folders[objectLocation.folderIndex]
                    .objects.append(ObjectBuilder(
                        id: videoID,
                        displayTitle: statement.stringColumn(4),
                        videoPath: statement.stringColumn(2),
                        videoName: statement.stringColumn(3),
                        subtitles: []
                    ))
            }

            let subtitlePath = statement.stringColumn(6)
            roots[objectLocation.rootIndex]
                .folders[objectLocation.folderIndex]
                .objects[objectLocation.objectIndex]
                .subtitles.append(IndexedContentSubtitle(
                    id: statement.int64Column(5),
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

private struct FolderLocation {
    let rootIndex: Int
    let folderIndex: Int
}

private struct ObjectLocation {
    let rootIndex: Int
    let folderIndex: Int
    let objectIndex: Int
}
