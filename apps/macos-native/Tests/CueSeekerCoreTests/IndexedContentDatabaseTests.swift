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

@Test
func indexedContentDatabaseSortsSubfoldersNaturallyAndSubtitlesByVideoSubtitlePriority() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        removeTemporaryDatabase(at: databaseURL)
    }

    try DatabaseBootstrap.prepare(at: databaseURL)
    try executeDatabaseTestSQLite(
        at: databaseURL,
        """
        INSERT INTO search_paths(id, path, created_at, updated_at)
        VALUES (1, '/Volumes/Alpha', 'created', 'updated');

        INSERT INTO library_folders(id, library_id, relative_path)
        VALUES
            (10, 1, 'Season 10'),
            (11, 1, 'Season 2');

        INSERT INTO video_files(id, library_id, folder_id, relative_path, path, video_name, file_size)
        VALUES
            (100, 1, 10, 'Season 10/Ep1.mkv', '/Volumes/Alpha/Season 10/Ep1.mkv', 'Ep1.mkv', 1000),
            (101, 1, 11, 'Season 2/Ep1.mkv', '/Volumes/Alpha/Season 2/Ep1.mkv', 'Ep1.mkv', 1000);

        INSERT INTO subtitle_files(id, library_id, folder_id, relative_path, subtitle_path, format, indexed_at, file_size)
        VALUES
            (200, 1, 10, 'Season 10/Ep1.srt', '/Volumes/Alpha/Season 10/Ep1.srt', 'srt', 'indexed', 100),
            (201, 1, 11, 'Season 2/Ep1.chs.ass', '/Volumes/Alpha/Season 2/Ep1.chs.ass', 'ass', 'indexed', 100),
            (202, 1, 11, 'Season 2/Ep1.srt', '/Volumes/Alpha/Season 2/Ep1.srt', 'srt', 'indexed', 100),
            (203, 1, 11, 'Season 2/Ep1.ass', '/Volumes/Alpha/Season 2/Ep1.ass', 'ass', 'indexed', 100);

        INSERT INTO subtitle_video_matches(subtitle_file_id, video_file_id, match_method, confidence, is_active)
        VALUES
            (200, 100, 'test', 1, 1),
            (201, 101, 'test', 1, 1),
            (202, 101, 'test', 1, 1),
            (203, 101, 'test', 1, 1);

        INSERT INTO library_video_rows(
            video_path, video_file_id, subtitle_file_id, video_name, duration,
            subtitle_path, subtitle_format, folder_path, folder_title,
            display_title, file_extension, folder_order, video_order, updated_at
        ) VALUES
            ('/Volumes/Alpha/Season 10/Ep1.mkv', 100, 200, 'Ep1.mkv', NULL,
                '/Volumes/Alpha/Season 10/Ep1.srt', 'srt', '/Volumes/Alpha/Season 10', 'Season 10',
                'Season 10 - 01', 'mkv', 1, 0, 'updated'),
            ('/Volumes/Alpha/Season 2/Ep1.mkv', 101, 203, 'Ep1.mkv', NULL,
                '/Volumes/Alpha/Season 2/Ep1.ass', 'ass', '/Volumes/Alpha/Season 2', 'Season 2',
                'Season 2 - 01', 'mkv', 0, 0, 'updated');
        """
    )

    let database = try IndexedContentDatabase(path: databaseURL)
    let subfolders = try database.subfolders(under: URL(fileURLWithPath: "/Volumes/Alpha"))
    #expect(subfolders.map(\.folderPath) == [
        "/Volumes/Alpha/Season 2",
        "/Volumes/Alpha/Season 10"
    ])

    let objects = try database.objects(in: "/Volumes/Alpha/Season 2")
    #expect(objects.count == 1)
    #expect(objects[0].subtitles.map(\.name) == [
        "Ep1.ass",
        "Ep1.srt",
        "Ep1.chs.ass"
    ])
}

@Test
func indexedContentDatabasePreservesNullVsZeroAndLoadsRichCardMetadata() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        removeTemporaryDatabase(at: databaseURL)
    }

    try DatabaseBootstrap.prepare(at: databaseURL)
    try executeDatabaseTestSQLite(
        at: databaseURL,
        """
        INSERT INTO search_paths(id, path, created_at, updated_at)
        VALUES (1, '/Volumes/Alpha', 'created', 'updated');

        INSERT INTO library_folders(id, library_id, relative_path)
        VALUES (10, 1, 'Show');

        INSERT INTO video_files(
            id, library_id, folder_id, relative_path, path, video_name,
            file_size, video_width, video_height, video_codec, duration
        ) VALUES
            (100, 1, 10, 'Show/Ep1.mkv', '/Volumes/Alpha/Show/Ep1.mkv', 'Ep1.mkv',
                831650000, 1920, 1080, 'hevc', 1422.0),
            (101, 1, 10, 'Show/Ep2.mkv', '/Volumes/Alpha/Show/Ep2.mkv', 'Ep2.mkv',
                NULL, NULL, NULL, NULL, NULL),
            (102, 1, 10, 'Show/Ep3.mkv', '/Volumes/Alpha/Show/Ep3.mkv', 'Ep3.mkv',
                0, 1280, 720, 'h264', 185.0);

        INSERT INTO subtitle_files(
            id, library_id, folder_id, relative_path, subtitle_path,
            format, file_size, raw_cue_count, indexed_at
        ) VALUES
            (200, 1, 10, 'Show/Ep1.ass', '/Volumes/Alpha/Show/Ep1.ass',
                'ass', 128400, 523, 'indexed'),
            (201, 1, 10, 'Show/Ep2.srt', '/Volumes/Alpha/Show/Ep2.srt',
                'srt', NULL, NULL, 'indexed'),
            (202, 1, 10, 'Show/Ep3.srt', '/Volumes/Alpha/Show/Ep3.srt',
                'srt', 0, 0, 'indexed');

        INSERT INTO subtitle_video_matches(
            subtitle_file_id, video_file_id, match_method, confidence, is_active
        ) VALUES
            (200, 100, 'test', 1, 1),
            (201, 101, 'test', 1, 1),
            (202, 102, 'test', 1, 1);

        INSERT INTO subtitle_cue_groups(
            id, subtitle_file_id, subtitle_path, seq, start_time, end_time, start_ms, end_ms, search_content
        ) VALUES
            (300, 200, '/Volumes/Alpha/Show/Ep1.ass', 1, '0:00:01.00', '0:00:02.00', 1000, 2000, 'a'),
            (301, 200, '/Volumes/Alpha/Show/Ep1.ass', 2, '0:00:03.00', '0:00:04.00', 3000, 4000, 'b');

        INSERT INTO subtitle_cue_lines(
            id, subtitle_file_id, cue_group_id, fts_rowid, language_mask, event_index,
            source_format, start_time, end_time, start_ms, end_ms, content, display_order
        ) VALUES
            (400, 200, 300, 1, 1, 0, 'ass', '0:00:01.00', '0:00:02.00', 1000, 2000, 'a', 0),
            (401, 200, 301, 2, 1, 1, 'ass', '0:00:03.00', '0:00:04.00', 3000, 4000, 'b', 0),
            (402, 200, 301, 2, 1, 2, 'ass', '0:00:03.00', '0:00:04.00', 3000, 4000, 'c', 1);

        INSERT INTO library_video_rows(
            video_path, video_file_id, subtitle_file_id, video_name, duration,
            subtitle_path, subtitle_format, folder_path, folder_title,
            display_title, file_extension, folder_order, video_order, updated_at
        ) VALUES
            ('/Volumes/Alpha/Show/Ep1.mkv', 100, 200, 'Ep1.mkv', 1422.0,
                '/Volumes/Alpha/Show/Ep1.ass', 'ass', '/Volumes/Alpha/Show', 'Show',
                'Show - 01', 'mkv', 0, 0, 'updated'),
            ('/Volumes/Alpha/Show/Ep2.mkv', 101, 201, 'Ep2.mkv', NULL,
                '/Volumes/Alpha/Show/Ep2.srt', 'srt', '/Volumes/Alpha/Show', 'Show',
                'Show - 02', 'mkv', 0, 1, 'updated'),
            ('/Volumes/Alpha/Show/Ep3.mkv', 102, 202, 'Ep3.mkv', 185.0,
                '/Volumes/Alpha/Show/Ep3.srt', 'srt', '/Volumes/Alpha/Show', 'Show',
                'Show - 03', 'mkv', 0, 2, 'updated');
        """
    )

    let indexedDatabase = try IndexedContentDatabase(path: databaseURL)
    let folderObjects = try indexedDatabase.objects(in: "/Volumes/Alpha/Show")
    let treeObjects = try indexedDatabase.contentTree()[0].folders[0].objects

    for objects in [folderObjects, treeObjects] {
        #expect(objects.count == 3)

        // Full metadata video + subtitle
        #expect(objects[0].fileSize == 831_650_000)
        #expect(objects[0].videoWidth == 1920)
        #expect(objects[0].videoHeight == 1080)
        #expect(objects[0].videoCodec == "hevc")
        #expect(objects[0].duration == 1422.0)
        #expect(objects[0].subtitles[0].fileSize == 128_400)
        #expect(objects[0].subtitles[0].rawCueCount == 523)
        #expect(objects[0].subtitles[0].validCueCount == 3)

        // NULL metadata must stay nil (never coerced to 0)
        #expect(objects[1].fileSize == nil)
        #expect(objects[1].videoWidth == nil)
        #expect(objects[1].videoHeight == nil)
        #expect(objects[1].videoCodec == nil)
        #expect(objects[1].duration == nil)
        #expect(objects[1].subtitles[0].fileSize == nil)
        #expect(objects[1].subtitles[0].rawCueCount == nil)
        #expect(objects[1].subtitles[0].validCueCount == 0)

        // Authentic zero byte size & zero cue counts must remain 0 (not nil)
        #expect(objects[2].fileSize == 0)
        #expect(objects[2].videoWidth == 1280)
        #expect(objects[2].videoHeight == 720)
        #expect(objects[2].videoCodec == "h264")
        #expect(objects[2].duration == 185.0)
        #expect(objects[2].subtitles[0].fileSize == 0)
        #expect(objects[2].subtitles[0].rawCueCount == 0)
        #expect(objects[2].subtitles[0].validCueCount == 0)
    }
}

