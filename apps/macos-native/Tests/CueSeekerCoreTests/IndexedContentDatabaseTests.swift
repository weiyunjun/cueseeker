import Foundation
import Testing
@testable import CueSeekerCore

@Test
func indexedContentDatabaseReusesLibraryFolderSetAndOrder() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    try DatabaseBootstrap.prepare(at: databaseURL)
    try executeDatabaseTestSQLite(
        at: databaseURL,
        """
        INSERT INTO search_paths(
            id, path, binding_state, is_configured, created_at, updated_at
        ) VALUES
            (1, '/Volumes/Alpha', 'available', 1, 'created', 'updated'),
            (2, '/Volumes/Zeta/', 'available', 1, 'created', 'updated'),
            (3, '/Volumes/Hidden', 'available', 0, 'created', 'updated'),
            (4, '/Volumes/Unavailable', 'unavailable', 1, 'created', 'updated');

        INSERT INTO library_folders(
            id, library_id, relative_path, last_known_path, binding_state
        ) VALUES
            (10, 1, 'Show/Season 2', '/Volumes/Alpha/Show/Season 2', 'available'),
            (11, 1, '/Movie', '/Volumes/Alpha/Movie', 'available'),
            (12, 1, 'Empty', '/Volumes/Alpha/Empty', 'available'),
            (14, 1, 'Video Only', '/Volumes/Alpha/Video Only', 'available'),
            (13, 1, 'Unavailable Folder', '/Volumes/Alpha/Unavailable Folder', 'unavailable'),
            (30, 3, 'Hidden Folder', '/Volumes/Hidden/Hidden Folder', 'available'),
            (40, 4, 'Unavailable Root Folder', '/Volumes/Unavailable/Folder', 'available');

        INSERT INTO video_files(
            id, library_id, folder_id, relative_path, path,
            last_known_path, binding_state, video_name
        ) VALUES
            (100, 1, 11, 'Movie/B.mkv', '/Volumes/Alpha/Movie/B.mkv',
                '/Volumes/Alpha/Movie/B.mkv', 'available', 'B.mkv'),
            (101, 1, 11, 'Movie/A.mkv', '/Volumes/Alpha/Movie/A.mkv',
                '/Volumes/Alpha/Movie/A.mkv', 'available', 'A.mkv'),
            (102, 1, 10, 'Show/Season 2/Episode.mkv', '/Volumes/Alpha/Show/Season 2/Episode.mkv',
                '/Volumes/Alpha/Show/Season 2/Episode.mkv', 'available', 'Episode.mkv'),
            (103, 1, 11, 'Movie/Gone.mkv', '/Volumes/Alpha/Movie/Gone.mkv',
                '/Volumes/Alpha/Movie/Gone.mkv', 'unavailable', 'Gone.mkv'),
            (104, 1, 14, 'Video Only/Unmatched.mkv', '/Volumes/Alpha/Video Only/Unmatched.mkv',
                '/Volumes/Alpha/Video Only/Unmatched.mkv', 'available', 'Unmatched.mkv');

        INSERT INTO subtitle_files(
            id, library_id, folder_id, relative_path, subtitle_path,
            last_known_path, binding_state, format, indexed_at
        ) VALUES
            (200, 1, 11, 'Movie/B.z.ass', '/Volumes/Alpha/Movie/B.z.ass',
                '/Volumes/Alpha/Movie/B.z.ass', 'available', 'ass', 'indexed'),
            (201, 1, 11, 'Movie/B.a.ass', '/Volumes/Alpha/Movie/B.a.ass',
                '/Volumes/Alpha/Movie/B.a.ass', 'available', 'ass', 'indexed'),
            (202, 1, 11, 'Movie/A.ass', '/Volumes/Alpha/Movie/A.ass',
                '/Volumes/Alpha/Movie/A.ass', 'available', 'ass', 'indexed'),
            (203, 1, 10, 'Show/Season 2/Episode.ass', '/Volumes/Alpha/Show/Season 2/Episode.ass',
                '/Volumes/Alpha/Show/Season 2/Episode.ass', 'available', 'ass', 'indexed'),
            (204, 1, 11, 'Movie/Inactive.ass', '/Volumes/Alpha/Movie/Inactive.ass',
                '/Volumes/Alpha/Movie/Inactive.ass', 'available', 'ass', 'indexed'),
            (205, 1, 11, 'Movie/Unavailable.ass', '/Volumes/Alpha/Movie/Unavailable.ass',
                '/Volumes/Alpha/Movie/Unavailable.ass', 'unavailable', 'ass', 'indexed'),
            (206, 1, 11, 'Movie/Gone.ass', '/Volumes/Alpha/Movie/Gone.ass',
                '/Volumes/Alpha/Movie/Gone.ass', 'available', 'ass', 'indexed');

        INSERT INTO subtitle_video_matches(
            subtitle_file_id, video_file_id, match_method, confidence, is_active
        ) VALUES
            (200, 100, 'test', 1, 1),
            (201, 100, 'test', 1, 1),
            (202, 101, 'test', 1, 1),
            (203, 102, 'test', 1, 1),
            (204, 100, 'test', 1, 0),
            (205, 100, 'test', 1, 1),
            (206, 103, 'test', 1, 1);

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
