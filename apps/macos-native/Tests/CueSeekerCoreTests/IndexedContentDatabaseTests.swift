import Foundation
import Testing
@testable import CueSeekerCore

@Test
func indexedContentDatabaseReusesLibraryFolderSetAndOrder() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        removeTemporaryDatabase(at: databaseURL)
    }

    try DatabaseBootstrap.prepare(at: databaseURL)
    try executeDatabaseTestSQLite(
        at: databaseURL,
        """
        INSERT INTO search_paths(
            id, path, created_at, updated_at
        ) VALUES
            (1, '/Volumes/Alpha', 'created', 'updated'),
            (2, '/Volumes/Zeta/', 'created', 'updated');

        INSERT INTO library_folders(
            id, library_id, relative_path
        ) VALUES
            (10, 1, 'Show/Season 2'),
            (11, 1, '/Movie'),
            (12, 1, 'Empty'),
            (14, 1, 'Video Only');

        INSERT INTO video_files(
            id, library_id, folder_id, relative_path, path, video_name
        ) VALUES
            (100, 1, 11, 'Movie/B.mkv', '/Volumes/Alpha/Movie/B.mkv', 'B.mkv'),
            (101, 1, 11, 'Movie/A.mkv', '/Volumes/Alpha/Movie/A.mkv', 'A.mkv'),
            (102, 1, 10, 'Show/Season 2/Episode.mkv',
                '/Volumes/Alpha/Show/Season 2/Episode.mkv', 'Episode.mkv'),
            (104, 1, 14, 'Video Only/Unmatched.mkv',
                '/Volumes/Alpha/Video Only/Unmatched.mkv', 'Unmatched.mkv');

        INSERT INTO subtitle_files(
            id, library_id, folder_id, relative_path, subtitle_path,
            format, indexed_at
        ) VALUES
            (200, 1, 11, 'Movie/B.z.ass', '/Volumes/Alpha/Movie/B.z.ass', 'ass', 'indexed'),
            (201, 1, 11, 'Movie/B.a.ass', '/Volumes/Alpha/Movie/B.a.ass', 'ass', 'indexed'),
            (202, 1, 11, 'Movie/A.ass', '/Volumes/Alpha/Movie/A.ass', 'ass', 'indexed'),
            (203, 1, 10, 'Show/Season 2/Episode.ass',
                '/Volumes/Alpha/Show/Season 2/Episode.ass', 'ass', 'indexed'),
            (204, 1, 11, 'Movie/Inactive.ass', '/Volumes/Alpha/Movie/Inactive.ass',
                'ass', 'indexed');

        INSERT INTO subtitle_video_matches(
            subtitle_file_id, video_file_id, match_method, confidence, is_active
        ) VALUES
            (200, 100, 'test', 1, 1),
            (201, 100, 'test', 1, 1),
            (202, 101, 'test', 1, 1),
            (203, 102, 'test', 1, 1),
            (204, 100, 'test', 1, 0);

        INSERT INTO library_video_rows(
            video_path, video_file_id, subtitle_file_id, video_name, duration,
            subtitle_path, subtitle_format, folder_path, folder_title,
            display_title, file_extension, folder_order, video_order, updated_at
        ) VALUES
            ('/Volumes/Alpha/Movie/B.mkv', 100, 200, 'B.mkv', NULL,
                '/Volumes/Alpha/Movie/B.z.ass', 'ass', '/Volumes/Alpha/Movie', 'Movie',
                'Movie B', 'mkv', 50, 0, 'updated'),
            ('/Volumes/Alpha/Movie/A.mkv', 101, 202, 'A.mkv', NULL,
                '/Volumes/Alpha/Movie/A.ass', 'ass', '/Volumes/Alpha/Movie', 'Movie',
                'Movie A', 'mkv', 50, 1, 'updated'),
            ('/Volumes/Alpha/Show/Season 2/Episode.mkv', 102, 203, 'Episode.mkv', NULL,
                '/Volumes/Alpha/Show/Season 2/Episode.ass', 'ass',
                '/Volumes/Alpha/Show/Season 2', 'Season 2',
                'Episode', 'mkv', 0, 0, 'updated');
        """
    )

    let roots = try IndexedContentDatabase(path: databaseURL).contentTree()
    let libraryFolders = try LibraryDatabase(
        path: databaseURL,
        access: .readOnly
    ).libraryPresentation(under: [URL(fileURLWithPath: "/Volumes/Alpha")])

    #expect(roots.map(\.id) == [1, 2])
    #expect(roots.map(\.displayPath) == ["Volumes/Alpha", "Volumes/Zeta"])
    #expect(roots[0].folders.map(\.id) == [11, 10])
    #expect(roots[0].folders.map(\.displayPath) == [
        "Movie",
        "Show/Season 2"
    ])
    #expect(
        roots[0].folders.map { "/Volumes/Alpha/\($0.displayPath)" }
            == libraryFolders.map(\.folderPath)
    )
    #expect(
        roots[0].folders.map { $0.objects.map(\.id) }
            == libraryFolders.map { $0.videos.map(\.videoFileID) }
    )

    let movieObjects = roots[0].folders[0].objects
    #expect(movieObjects.map(\.id) == [100, 101])
    #expect(movieObjects.map(\.displayTitle) == ["Movie B", "Movie A"])
    #expect(movieObjects[0].videoName == "B.mkv")
    #expect(movieObjects[0].subtitles.map(\.id) == [201, 200])
    #expect(movieObjects[0].subtitles.map(\.name) == ["B.a.ass", "B.z.ass"])
    #expect(roots[0].folders[1].objects.map(\.id) == [102])
    #expect(roots[1].folders.isEmpty)
}

@Test
func indexedContentDatabaseOnDemandSubfoldersAndObjects() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        removeTemporaryDatabase(at: databaseURL)
    }

    try DatabaseBootstrap.prepare(at: databaseURL)
    try executeDatabaseTestSQLite(
        at: databaseURL,
        """
        INSERT INTO search_paths(
            id, path, created_at, updated_at
        ) VALUES
            (1, '/Volumes/Alpha', 'created', 'updated'),
            (2, '/Volumes/Zeta/', 'created', 'updated');

        INSERT INTO library_folders(
            id, library_id, relative_path
        ) VALUES
            (10, 1, 'Show/Season 2'),
            (11, 1, '/Movie');

        INSERT INTO video_files(
            id, library_id, folder_id, relative_path, path, video_name, file_size
        ) VALUES
            (100, 1, 11, 'Movie/B.mkv', '/Volumes/Alpha/Movie/B.mkv', 'B.mkv', 1048576),
            (101, 1, 11, 'Movie/A.mkv', '/Volumes/Alpha/Movie/A.mkv', 'A.mkv', 2097152),
            (102, 1, 10, 'Show/Season 2/Episode.mkv',
                '/Volumes/Alpha/Show/Season 2/Episode.mkv', 'Episode.mkv', 4194304);

        INSERT INTO subtitle_files(
            id, library_id, folder_id, relative_path, subtitle_path,
            format, indexed_at, file_size
        ) VALUES
            (200, 1, 11, 'Movie/B.z.ass', '/Volumes/Alpha/Movie/B.z.ass', 'ass', 'indexed', 1024),
            (201, 1, 11, 'Movie/B.a.ass', '/Volumes/Alpha/Movie/B.a.ass', 'ass', 'indexed', 2048),
            (202, 1, 11, 'Movie/A.ass', '/Volumes/Alpha/Movie/A.ass', 'ass', 'indexed', 3072),
            (203, 1, 10, 'Show/Season 2/Episode.ass',
                '/Volumes/Alpha/Show/Season 2/Episode.ass', 'ass', 'indexed', 4096);

        INSERT INTO subtitle_video_matches(
            subtitle_file_id, video_file_id, match_method, confidence, is_active
        ) VALUES
            (200, 100, 'test', 1, 1),
            (201, 100, 'test', 1, 1),
            (202, 101, 'test', 1, 1),
            (203, 102, 'test', 1, 1);

        INSERT INTO library_video_rows(
            video_path, video_file_id, subtitle_file_id, video_name, duration,
            subtitle_path, subtitle_format, folder_path, folder_title,
            display_title, file_extension, folder_order, video_order, updated_at
        ) VALUES
            ('/Volumes/Alpha/Movie/B.mkv', 100, 200, 'B.mkv', NULL,
                '/Volumes/Alpha/Movie/B.z.ass', 'ass', '/Volumes/Alpha/Movie', 'Movie',
                'Movie B', 'mkv', 50, 0, 'updated'),
            ('/Volumes/Alpha/Movie/A.mkv', 101, 202, 'A.mkv', NULL,
                '/Volumes/Alpha/Movie/A.ass', 'ass', '/Volumes/Alpha/Movie', 'Movie',
                'Movie A', 'mkv', 50, 1, 'updated'),
            ('/Volumes/Alpha/Show/Season 2/Episode.mkv', 102, 203, 'Episode.mkv', NULL,
                '/Volumes/Alpha/Show/Season 2/Episode.ass', 'ass',
                '/Volumes/Alpha/Show/Season 2', 'Season 2',
                'Episode', 'mkv', 0, 0, 'updated');
        """
    )

    let database = try IndexedContentDatabase(path: databaseURL)

    // 1. Subfolders for /Volumes/Alpha
    let alphaSubfolders = try database.subfolders(under: URL(fileURLWithPath: "/Volumes/Alpha"))
    #expect(alphaSubfolders.map(\.id) == [11, 10])
    #expect(alphaSubfolders.map(\.folderPath) == [
        "/Volumes/Alpha/Movie",
        "/Volumes/Alpha/Show/Season 2"
    ])
    #expect(alphaSubfolders[0].objects.isEmpty) // On-demand: does not populate objects

    // 2. Subfolders for /Volumes/Zeta (empty)
    let zetaSubfolders = try database.subfolders(under: URL(fileURLWithPath: "/Volumes/Zeta"))
    #expect(zetaSubfolders.isEmpty)

    // 3. Objects for /Volumes/Alpha/Movie
    let movieObjects = try database.objects(in: "/Volumes/Alpha/Movie")
    #expect(movieObjects.map(\.id) == [100, 101])
    #expect(movieObjects[0].fileSize == 1048576)
    #expect(movieObjects[0].videoName == "B.mkv")
    #expect(movieObjects[0].subtitles.map(\.name) == ["B.a.ass", "B.z.ass"])
    #expect(movieObjects[0].subtitles.map(\.fileSize) == [2048, 1024])
    #expect(movieObjects[1].fileSize == 2097152)
    #expect(movieObjects[1].videoName == "A.mkv")
    #expect(movieObjects[1].subtitles.map(\.name) == ["A.ass"])

    // 4. Objects for /Volumes/Alpha/Show/Season 2
    let showObjects = try database.objects(in: "/Volumes/Alpha/Show/Season 2")
    #expect(showObjects.map(\.id) == [102])
    #expect(showObjects[0].fileSize == 4194304)
    #expect(showObjects[0].videoName == "Episode.mkv")
    #expect(showObjects[0].subtitles.map(\.name) == ["Episode.ass"])
}

