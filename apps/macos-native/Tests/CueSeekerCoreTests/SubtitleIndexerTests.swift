import Foundation
import SQLite3
import Testing
@testable import CueSeekerCore

@Test
func indexesFolderIntoSQLiteSearchDatabase() throws {
    let fixture = try IndexingFixture()
    defer {
        fixture.cleanUp()
    }

    try fixture.writeSubtitle(
        name: "Movie.srt",
        contents: """
        1
        00:00:01,000 --> 00:00:03,000
        Hello searchable world.

        2
        00:00:04,000 --> 00:00:06,000
        Another indexed line.

        """
    )
    try fixture.writeVideo(name: "Movie.mkv")

    let database = try IndexingDatabase(path: fixture.databaseURL)
    let indexer = SubtitleIndexer()

    let result = try indexer.index(folder: fixture.root, into: database)

    #expect(result.scannedSubtitleFiles == 1)
    #expect(result.indexedSubtitleFiles == 1)
    #expect(result.indexedSubtitleEntries == 2)
    #expect(result.skippedMissingVideo == 0)

    let searchResults = try SearchDatabase(path: fixture.databaseURL).search("searchable")
    #expect(searchResults.count == 1)
    #expect(searchResults[0].videoName == "Movie.mkv")
    #expect(searchResults[0].startMilliseconds == 1_000)

    let subtitleFiles = try database.subtitleFiles()
    #expect(subtitleFiles.count == 1)
    #expect(subtitleFiles[0].subtitlePath.hasSuffix("Movie.srt"))
    #expect(subtitleFiles[0].videoName == "Movie.mkv")
}

@Test
func indexingPrefersCompleteBasenameMatchAndStoresOneAssociation() throws {
    let fixture = try IndexingFixture()
    defer {
        fixture.cleanUp()
    }

    try fixture.writeSubtitle(
        name: "Episode.reference-track.srt",
        contents: """
        1
        00:00:01,000 --> 00:00:03,000
        Complete basename priority.

        """
    )
    let exactVideo = try fixture.writeVideo(name: "Episode.reference-track.mkv")
    _ = try fixture.writeVideo(name: "Episode.mp4")

    let database = try IndexingDatabase(path: fixture.databaseURL)
    let result = try SubtitleIndexer().index(folder: fixture.root, into: database)
    let subtitleFiles = try database.subtitleFiles()
    let searchResults = try SearchDatabase(path: fixture.databaseURL).search("priority")
    let storedVideo = URL(
        fileURLWithPath: try #require(subtitleFiles.first?.videoPath)
    ).resolvingSymlinksInPath()
    let searchedVideo = URL(
        fileURLWithPath: try #require(searchResults.first?.videoPath)
    ).resolvingSymlinksInPath()

    #expect(result.indexedSubtitleFiles == 1)
    #expect(subtitleFiles.count == 1)
    #expect(storedVideo == exactVideo.resolvingSymlinksInPath())
    #expect(searchResults.count == 1)
    #expect(searchedVideo == exactVideo.resolvingSymlinksInPath())
}

@Test
func reindexingSwitchesFromFallbackToCompleteBasenameMatch() throws {
    let fixture = try IndexingFixture()
    defer {
        fixture.cleanUp()
    }

    try fixture.writeSubtitle(
        name: "Episode.reference-track.srt",
        contents: """
        1
        00:00:01,000 --> 00:00:03,000
        Deterministic rematching.

        """
    )
    let fallbackVideo = try fixture.writeVideo(name: "Episode.mp4")

    let database = try IndexingDatabase(path: fixture.databaseURL)
    let indexer = SubtitleIndexer()

    let initialResult = try indexer.index(folder: fixture.root, into: database)
    let initialFiles = try database.subtitleFiles()

    let exactVideo = try fixture.writeVideo(name: "Episode.reference-track.mkv")
    let rematchedResult = try indexer.index(folder: fixture.root, into: database)
    let rematchedFiles = try database.subtitleFiles()
    let initialVideo = URL(
        fileURLWithPath: try #require(initialFiles.first?.videoPath)
    ).resolvingSymlinksInPath()
    let rematchedVideo = URL(
        fileURLWithPath: try #require(rematchedFiles.first?.videoPath)
    ).resolvingSymlinksInPath()

    #expect(initialResult.indexedSubtitleFiles == 1)
    #expect(initialFiles.count == 1)
    #expect(initialVideo == fallbackVideo.resolvingSymlinksInPath())
    #expect(rematchedResult.indexedSubtitleFiles == 0)
    #expect(rematchedResult.skippedUnchangedSubtitleFiles == 1)
    #expect(rematchedFiles.count == 1)
    #expect(rematchedVideo == exactVideo.resolvingSymlinksInPath())
}

@Test
func indexingSRTStoresLanguageAnalysisAfterVideoMatch() throws {
    let fixture = try IndexingFixture()
    defer {
        fixture.cleanUp()
    }

    _ = try fixture.writeSubtitle(
        name: "Japanese.srt",
        contents: """
        1
        00:00:01,000 --> 00:00:03,000
        今日はみんなで映画を見に行きます。

        2
        00:00:04,000 --> 00:00:06,000
        明日は学校のあとで友達と話します。

        """
    )
    try fixture.writeVideo(name: "Japanese.mkv")

    let database = try IndexingDatabase(path: fixture.databaseURL)
    let indexer = SubtitleIndexer()

    let result = try indexer.index(folder: fixture.root, into: database)

    #expect(result.indexedSubtitleFiles == 1)
    let indexedSubtitlePath = try #require(try database.subtitleFiles().first?.subtitlePath)
    let indexedSubtitleURL = URL(fileURLWithPath: indexedSubtitlePath)
    #expect(try database.hasCurrentSubtitleLanguageManifest(forSubtitleFile: indexedSubtitleURL))

    let detections = try database.languageDetections(forSubtitleFile: indexedSubtitleURL)
    #expect(detections.count == 1)
    let detection = try #require(detections.first)
    #expect(detection.scope == .file)
    #expect(detection.languages == [.japanese])

    let storedEntries = try PlaybackSubtitleDatabase(path: fixture.databaseURL)
        .entries(forSubtitleFile: indexedSubtitleURL)
    let firstEntry = try #require(storedEntries.first)
    let secondEntry = try #require(storedEntries.dropFirst().first)
    let languagesByCueGroupID = try database.cueGroupLanguages(forSubtitleFile: indexedSubtitleURL)
    #expect(languagesByCueGroupID[firstEntry.id] == [.japanese])
    #expect(languagesByCueGroupID[secondEntry.id] == [.japanese])
}

@Test
func skipsSubtitleFileWhenMatchingVideoIsMissing() throws {
    let fixture = try IndexingFixture()
    defer {
        fixture.cleanUp()
    }

    try fixture.writeSubtitle(
        name: "MissingVideo.srt",
        contents: """
        1
        00:00:01,000 --> 00:00:03,000
        This should not be indexed.

        """
    )

    let database = try IndexingDatabase(path: fixture.databaseURL)
    let indexer = SubtitleIndexer()

    let result = try indexer.index(folder: fixture.root, into: database)

    #expect(result.scannedSubtitleFiles == 1)
    #expect(result.indexedSubtitleFiles == 0)
    #expect(result.indexedSubtitleEntries == 0)
    #expect(result.skippedMissingVideo == 1)
    #expect(try SearchDatabase(path: fixture.databaseURL).search("indexed").isEmpty)
}

@Test
func reindexingFolderRemovesStaleSubtitleEntries() throws {
    let fixture = try IndexingFixture()
    defer {
        fixture.cleanUp()
    }

    let subtitleURL = try fixture.writeSubtitle(
        name: "Episode.srt",
        contents: """
        1
        00:00:01,000 --> 00:00:03,000
        Old searchable text.

        """
    )
    try fixture.writeVideo(name: "Episode.mp4")

    let database = try IndexingDatabase(path: fixture.databaseURL)
    let indexer = SubtitleIndexer()

    _ = try indexer.index(folder: fixture.root, into: database)
    #expect(try SearchDatabase(path: fixture.databaseURL).search("Old").count == 1)

    try FileManager.default.removeItem(at: subtitleURL)

    let result = try indexer.index(folder: fixture.root, into: database)

    #expect(result.scannedSubtitleFiles == 0)
    #expect(result.indexedSubtitleFiles == 0)
    #expect(try SearchDatabase(path: fixture.databaseURL).search("Old").isEmpty)
    #expect(try database.subtitleFiles().isEmpty)
}

@Test
func reindexingFolderReplacesChangedSubtitleContent() throws {
    let fixture = try IndexingFixture()
    defer {
        fixture.cleanUp()
    }

    try fixture.writeSubtitle(
        name: "Episode.srt",
        contents: """
        1
        00:00:01,000 --> 00:00:03,000
        Old searchable text.

        """
    )
    try fixture.writeVideo(name: "Episode.mp4")

    let database = try IndexingDatabase(path: fixture.databaseURL)
    let indexer = SubtitleIndexer()

    _ = try indexer.index(folder: fixture.root, into: database)

    try fixture.writeSubtitle(
        name: "Episode.srt",
        contents: """
        1
        00:00:09,000 --> 00:00:11,000
        Fresh searchable text.

        """
    )

    let result = try indexer.index(folder: fixture.root, into: database)

    #expect(result.indexedSubtitleEntries == 1)
    #expect(try SearchDatabase(path: fixture.databaseURL).search("Old").isEmpty)

    let freshResults = try SearchDatabase(path: fixture.databaseURL).search("Fresh")
    #expect(freshResults.count == 1)
    #expect(freshResults[0].startMilliseconds == 9_000)
}

@Test
func reindexingUnchangedSubtitleFileSkipsRewrite() throws {
    let fixture = try IndexingFixture()
    defer {
        fixture.cleanUp()
    }

    try fixture.writeSubtitle(
        name: "Episode.srt",
        contents: """
        1
        00:00:01,000 --> 00:00:03,000
        Stable searchable text.

        """
    )
    try fixture.writeVideo(name: "Episode.mp4")

    let database = try IndexingDatabase(path: fixture.databaseURL)
    let indexer = SubtitleIndexer()

    let initialResult = try indexer.index(folder: fixture.root, into: database)
    let unchangedResult = try indexer.index(folder: fixture.root, into: database)

    #expect(initialResult.indexedSubtitleFiles == 1)
    #expect(unchangedResult.scannedSubtitleFiles == 1)
    #expect(unchangedResult.indexedSubtitleFiles == 0)
    #expect(unchangedResult.indexedSubtitleEntries == 0)
    #expect(unchangedResult.skippedUnchangedSubtitleFiles == 1)

    let searchResults = try SearchDatabase(path: fixture.databaseURL).search("Stable")
    #expect(searchResults.count == 1)
    #expect(searchResults[0].content == "Stable searchable text.")
}

@Test
func unchangedIndexDoesNotWriteIndexedResourcesOrDerivedRows() throws {
    let fixture = try IndexingFixture()
    defer {
        fixture.cleanUp()
    }

    _ = try fixture.writeSubtitle(
        name: "Episode.srt",
        contents: """
        1
        00:00:01,000 --> 00:00:03,000
        Stable incremental text.

        """
    )
    _ = try fixture.writeVideo(name: "Episode.mkv")

    let database = try IndexingDatabase(path: fixture.databaseURL)
    let indexer = SubtitleIndexer()
    _ = try indexer.index(folder: fixture.root, into: database)
    let libraryDatabase = try LibraryDatabase(path: fixture.databaseURL)
    try libraryDatabase.refreshPresentationAfterIndexedContentChange()
    let ftsRowsBefore = try queryString(
        at: fixture.databaseURL,
        sql: """
        SELECT GROUP_CONCAT(rowid || ':' || cue_group_id, ',')
        FROM subtitle_cue_groups_fts;
        """
    )

    try executeSQLite(
        at: fixture.databaseURL,
        """
        CREATE TRIGGER reject_unchanged_cue_line_insert
        BEFORE INSERT ON subtitle_cue_lines
        BEGIN SELECT RAISE(ABORT, 'unexpected cue line insert'); END;
        CREATE TRIGGER reject_unchanged_cue_line_update
        BEFORE UPDATE ON subtitle_cue_lines
        BEGIN SELECT RAISE(ABORT, 'unexpected cue line update'); END;
        CREATE TRIGGER reject_unchanged_cue_line_delete
        BEFORE DELETE ON subtitle_cue_lines
        BEGIN SELECT RAISE(ABORT, 'unexpected cue line delete'); END;
        CREATE TRIGGER reject_unchanged_cue_group_insert
        BEFORE INSERT ON subtitle_cue_groups
        BEGIN SELECT RAISE(ABORT, 'unexpected cue group insert'); END;
        CREATE TRIGGER reject_unchanged_cue_group_update
        BEFORE UPDATE ON subtitle_cue_groups
        BEGIN SELECT RAISE(ABORT, 'unexpected cue group update'); END;
        CREATE TRIGGER reject_unchanged_cue_group_delete
        BEFORE DELETE ON subtitle_cue_groups
        BEGIN SELECT RAISE(ABORT, 'unexpected cue group delete'); END;
        CREATE TRIGGER reject_unchanged_search_order_insert
        BEFORE INSERT ON subtitle_search_order_rows
        BEGIN SELECT RAISE(ABORT, 'unexpected search order insert'); END;
        CREATE TRIGGER reject_unchanged_search_order_update
        BEFORE UPDATE ON subtitle_search_order_rows
        BEGIN SELECT RAISE(ABORT, 'unexpected search order update'); END;
        CREATE TRIGGER reject_unchanged_search_order_delete
        BEFORE DELETE ON subtitle_search_order_rows
        BEGIN SELECT RAISE(ABORT, 'unexpected search order delete'); END;
        CREATE TRIGGER reject_unchanged_video_update
        BEFORE UPDATE ON video_files
        BEGIN SELECT RAISE(ABORT, 'unexpected video update'); END;
        """
    )

    let result = try indexer.index(folder: fixture.root, into: database)

    #expect(result.skippedUnchangedSubtitleFiles == 1)
    #expect(!result.hasIndexedContentChanges)
    #expect(
        try queryString(
            at: fixture.databaseURL,
            sql: """
            SELECT GROUP_CONCAT(rowid || ':' || cue_group_id, ',')
            FROM subtitle_cue_groups_fts;
            """
        ) == ftsRowsBefore
    )
}

@Test
func changingOneSubtitleDoesNotRewriteUnrelatedFolderIndexRows() throws {
    let fixture = try IndexingFixture()
    defer {
        fixture.cleanUp()
    }

    let firstSubtitle = try fixture.writeSubtitle(
        name: "First/Episode.srt",
        contents: """
        1
        00:00:01,000 --> 00:00:03,000
        First original text.

        """
    )
    _ = try fixture.writeVideo(name: "First/Episode.mkv")
    _ = try fixture.writeSubtitle(
        name: "Second/Episode.srt",
        contents: """
        1
        00:00:01,000 --> 00:00:03,000
        Second stable text.

        """
    )
    _ = try fixture.writeVideo(name: "Second/Episode.mkv")

    let database = try IndexingDatabase(path: fixture.databaseURL)
    let indexer = SubtitleIndexer()
    _ = try indexer.index(folder: fixture.root, into: database)
    let libraryDatabase = try LibraryDatabase(path: fixture.databaseURL)
    try libraryDatabase.refreshPresentationAfterIndexedContentChange()
    let secondSubtitleID = try queryInt(
        at: fixture.databaseURL,
        sql: """
        SELECT id FROM subtitle_files
        WHERE subtitle_path LIKE '%/Second/Episode.srt';
        """
    )
    let secondCueID = try queryInt(
        at: fixture.databaseURL,
        sql: """
        SELECT id FROM subtitle_cue_lines
        WHERE subtitle_file_id = \(secondSubtitleID);
        """
    )
    let secondFTSRowID = try queryInt(
        at: fixture.databaseURL,
        sql: """
        SELECT f.rowid
        FROM subtitle_cue_groups_fts f
        JOIN subtitle_cue_groups g ON g.id = f.cue_group_id
        WHERE g.subtitle_file_id = \(secondSubtitleID);
        """
    )
    try executeSQLite(
        at: fixture.databaseURL,
        """
        CREATE TRIGGER reject_unrelated_search_order_delete
        BEFORE DELETE ON subtitle_search_order_rows
        WHEN OLD.subtitle_file_id = \(secondSubtitleID)
        BEGIN SELECT RAISE(ABORT, 'unrelated search order delete'); END;
        CREATE TRIGGER reject_unrelated_search_order_update
        BEFORE UPDATE ON subtitle_search_order_rows
        WHEN OLD.subtitle_file_id = \(secondSubtitleID)
          OR NEW.subtitle_file_id = \(secondSubtitleID)
        BEGIN SELECT RAISE(ABORT, 'unrelated search order update'); END;
        CREATE TRIGGER reject_unrelated_search_order_insert
        BEFORE INSERT ON subtitle_search_order_rows
        WHEN NEW.subtitle_file_id = \(secondSubtitleID)
        BEGIN SELECT RAISE(ABORT, 'unrelated search order insert'); END;
        CREATE TRIGGER reject_unrelated_library_row_delete
        BEFORE DELETE ON library_video_rows
        WHEN OLD.subtitle_file_id = \(secondSubtitleID)
        BEGIN SELECT RAISE(ABORT, 'unrelated Library row delete'); END;
        CREATE TRIGGER reject_unrelated_library_row_update
        BEFORE UPDATE ON library_video_rows
        WHEN OLD.subtitle_file_id = \(secondSubtitleID)
          OR NEW.subtitle_file_id = \(secondSubtitleID)
        BEGIN SELECT RAISE(ABORT, 'unrelated Library row update'); END;
        CREATE TRIGGER reject_unrelated_library_row_insert
        BEFORE INSERT ON library_video_rows
        WHEN NEW.subtitle_file_id = \(secondSubtitleID)
        BEGIN SELECT RAISE(ABORT, 'unrelated Library row insert'); END;
        """
    )

    try """
    1
    00:00:01,000 --> 00:00:03,000
    First changed text.

    """.write(to: firstSubtitle, atomically: true, encoding: .utf8)
    let result = try indexer.index(folder: fixture.root, into: database)
    try libraryDatabase.refreshPresentationAfterIndexedContentChange(
        affectedFolderPaths: Set(result.affectedFolderPaths)
    )

    #expect(result.changedSubtitlePaths.count == 1)
    #expect(
        URL(fileURLWithPath: try #require(result.changedSubtitlePaths.first))
            .resolvingSymlinksInPath()
            == firstSubtitle.resolvingSymlinksInPath()
    )
    #expect(
        result.affectedFolderPaths.count == 1
    )
    #expect(
        URL(fileURLWithPath: try #require(result.affectedFolderPaths.first))
            .resolvingSymlinksInPath()
            == firstSubtitle.deletingLastPathComponent()
                .resolvingSymlinksInPath()
    )
    #expect(
        try queryInt(
            at: fixture.databaseURL,
            sql: """
            SELECT id FROM subtitle_cue_lines
            WHERE subtitle_file_id = \(secondSubtitleID);
            """
        ) == secondCueID
    )
    #expect(
        try queryInt(
            at: fixture.databaseURL,
            sql: """
            SELECT f.rowid
            FROM subtitle_cue_groups_fts f
            JOIN subtitle_cue_groups g ON g.id = f.cue_group_id
            WHERE g.subtitle_file_id = \(secondSubtitleID);
            """
        ) == secondFTSRowID
    )
}

@Test
func failedMultiFilePublicationRollsBackTheWholeLibraryIndex() throws {
    let fixture = try IndexingFixture()
    defer {
        fixture.cleanUp()
    }

    _ = try fixture.writeSubtitle(
        name: "First.srt",
        contents: """
        1
        00:00:01,000 --> 00:00:03,000
        Original first.

        """
    )
    _ = try fixture.writeSubtitle(
        name: "Second.srt",
        contents: """
        1
        00:00:04,000 --> 00:00:06,000
        Original second.

        """
    )
    _ = try fixture.writeVideo(name: "First.mkv")
    _ = try fixture.writeVideo(name: "Second.mkv")

    let database = try IndexingDatabase(path: fixture.databaseURL)
    let indexer = SubtitleIndexer()
    _ = try indexer.index(folder: fixture.root, into: database)

    _ = try fixture.writeSubtitle(
        name: "First.srt",
        contents: """
        1
        00:00:01,000 --> 00:00:03,000
        Updated first.

        """
    )
    _ = try fixture.writeSubtitle(
        name: "Second.srt",
        contents: """
        1
        00:00:04,000 --> 00:00:06,000
        Updated second.

        """
    )
    try executeSQLite(
        at: fixture.databaseURL,
        """
        CREATE TRIGGER reject_second_index_write
        BEFORE INSERT ON subtitle_cue_lines
        WHEN NEW.content = 'Updated second.'
        BEGIN
            SELECT RAISE(ABORT, 'injected publication failure');
        END;
        """
    )

    #expect(throws: (any Error).self) {
        try indexer.index(folder: fixture.root, into: database)
    }

    let search = try SearchDatabase(path: fixture.databaseURL)
    #expect(try search.search("Original first").count == 1)
    #expect(try search.search("Original second").count == 1)
    #expect(try search.search("Updated first").isEmpty)
    #expect(try search.search("Updated second").isEmpty)
}

@Test
func malformedSubtitleDoesNotReplaceTheLastSuccessfulIndex() throws {
    let fixture = try IndexingFixture()
    defer {
        fixture.cleanUp()
    }

    _ = try fixture.writeSubtitle(
        name: "Episode.srt",
        contents: """
        1
        00:00:01,000 --> 00:00:03,000
        Last successful text.

        """
    )
    _ = try fixture.writeVideo(name: "Episode.mkv")

    let database = try IndexingDatabase(path: fixture.databaseURL)
    let indexer = SubtitleIndexer()
    _ = try indexer.index(folder: fixture.root, into: database)
    _ = try fixture.writeSubtitle(
        name: "Episode.srt",
        contents: """
        1
        this is not a time range
        Broken replacement.

        """
    )

    #expect(throws: SubtitleIndexingError.self) {
        try indexer.index(folder: fixture.root, into: database)
    }
    #expect(
        try SearchDatabase(path: fixture.databaseURL)
            .search("Last successful")
            .count == 1
    )
}

@Test
func staleLibraryIndexTokenCannotPublish() throws {
    let fixture = try IndexingFixture()
    defer {
        fixture.cleanUp()
    }

    let database = try IndexingDatabase(path: fixture.databaseURL)
    let older = try database.beginLibraryIndex(fixture.root)
    let newer = try database.beginLibraryIndex(fixture.root)

    #expect(
        throws: SubtitleIndexingError.stalePublication(
            libraryID: older.libraryID,
            token: older.token
        )
    ) {
        try database.publishLibraryIndex(
            PreparedLibraryIndex(
                folder: fixture.root,
                lease: older,
                changedFiles: [],
                bindingRefreshes: [],
                missingVideoSubtitleFiles: [],
                keptSubtitlePaths: []
            )
        )
    }

    _ = try database.publishLibraryIndex(
        PreparedLibraryIndex(
            folder: fixture.root,
            lease: newer,
            changedFiles: [],
            bindingRefreshes: [],
            missingVideoSubtitleFiles: [],
            keptSubtitlePaths: []
        )
    )
    #expect(
        try queryInt(
            at: fixture.databaseURL,
            sql: "SELECT published_index_token FROM search_paths WHERE id = \(newer.libraryID);"
        ) == newer.token
    )
}

@Test
func reindexingUnchangedSubtitleFileRefreshesVideoFileMetadata() throws {
    let fixture = try IndexingFixture()
    defer {
        fixture.cleanUp()
    }

    try fixture.writeSubtitle(
        name: "Episode.srt",
        contents: """
        1
        00:00:01,000 --> 00:00:03,000
        Stable searchable text.

        """
    )
    let videoURL = try fixture.writeVideo(name: "Episode.mp4")

    let database = try IndexingDatabase(path: fixture.databaseURL)
    let indexer = SubtitleIndexer()

    _ = try indexer.index(folder: fixture.root, into: database)
    try Data(repeating: 0x42, count: 16).write(to: videoURL)

    let unchangedResult = try indexer.index(folder: fixture.root, into: database)
    let coverVideos = try LibraryCoverDatabase(path: fixture.databaseURL).libraryCoverEligibleVideos(under: [fixture.root])
    let coverVideo = try #require(coverVideos.first)

    #expect(unchangedResult.skippedUnchangedSubtitleFiles == 1)
    #expect(unchangedResult.changedSubtitlePaths.isEmpty)
    let affectedVideoPath = try #require(
        unchangedResult.affectedVideoPaths.first
    )
    #expect(unchangedResult.affectedVideoPaths.count == 1)
    #expect(
        URL(fileURLWithPath: affectedVideoPath).lastPathComponent
            == videoURL.lastPathComponent
    )
    #expect(
        URL(fileURLWithPath: affectedVideoPath)
            .deletingLastPathComponent().lastPathComponent
            == fixture.root.lastPathComponent
    )
    #expect(unchangedResult.hasIndexedContentChanges)
    #expect(coverVideo.fileSize == 16)
}

@Test
func reindexingUnchangedSubtitleFileWithoutLanguageManifestRewritesOnce() throws {
    let fixture = try IndexingFixture()
    defer {
        fixture.cleanUp()
    }

    let contents = """
    1
    00:00:01,000 --> 00:00:03,000
    今日はみんなで映画を見に行きます。

    """
    _ = try fixture.writeSubtitle(name: "Episode.srt", contents: contents)
    _ = try fixture.writeVideo(name: "Episode.mp4")
    let scannedSubtitleURL = try #require(SubtitleFileScanner().scanSubtitleFiles(in: fixture.root).first)
    let videoURL = try #require(VideoMatcher().matchingVideo(for: scannedSubtitleURL))
    let metadata = try fixture.subtitleFileMetadata(for: scannedSubtitleURL)

    try DatabaseBootstrap.prepare(at: fixture.databaseURL)
    let database = try IndexingDatabase(path: fixture.databaseURL)
    try database.replaceEntries(
        subtitleFile: scannedSubtitleURL,
        videoFile: videoURL,
        entries: SRTParser.parse(contents),
        fileSize: metadata.fileSize,
        modifiedAt: metadata.modifiedAt
    )

    #expect(try !database.hasCurrentSubtitleLanguageManifest(forSubtitleFile: scannedSubtitleURL))

    let indexer = SubtitleIndexer()
    let result = try indexer.index(folder: fixture.root, into: database)

    #expect(result.scannedSubtitleFiles == 1)
    #expect(result.indexedSubtitleFiles == 1)
    #expect(result.skippedUnchangedSubtitleFiles == 0)
    #expect(try database.hasCurrentSubtitleLanguageManifest(forSubtitleFile: scannedSubtitleURL))
}

@Test
func indexesASSFilesAsGroupedCueResults() throws {
    let fixture = try IndexingFixture()
    defer {
        fixture.cleanUp()
    }

    try fixture.writeSubtitle(
        name: "Movie.scjp.ass",
        contents: """
        [Script Info]
        PlayResX: 1920
        PlayResY: 1080

        [V4+ Styles]
        Format: Name, Alignment, MarginL, MarginR, MarginV
        Style: Top,8,20,20,40
        Style: Bottom,2,20,20,30

        [Events]
        Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
        Dialogue: 0,0:00:01.00,0:00:03.00,Bottom,,0,0,0,,English line
        Dialogue: 0,0:00:01.00,0:00:03.00,Top,,0,0,0,,日本語ライン
        Dialogue: 0,0:00:04.00,0:00:06.00,Bottom,,0,0,0,,Another line
        """
    )
    try fixture.writeVideo(name: "Movie.mkv")

    let database = try IndexingDatabase(path: fixture.databaseURL)
    let indexer = SubtitleIndexer()

    let result = try indexer.index(folder: fixture.root, into: database)

    #expect(result.scannedSubtitleFiles == 1)
    #expect(result.indexedSubtitleFiles == 1)
    #expect(result.indexedSubtitleEntries == 2)

    let searchResults = try SearchDatabase(path: fixture.databaseURL).search("English")
    #expect(searchResults.count == 1)
    #expect(searchResults[0].subtitleFormat == .ass)
    #expect(searchResults[0].videoName == "Movie.mkv")
    #expect(searchResults[0].cueLines == ["English line"])
    #expect(searchResults[0].cueGroupLines == ["日本語ライン", "English line"])
    #expect(searchResults[0].startMilliseconds == 1_000)

    let kanaResults = try SearchDatabase(path: fixture.databaseURL).search("ライン")
    #expect(kanaResults.count == 1)
    #expect(kanaResults[0].subtitleFormat == .ass)
    #expect(kanaResults[0].cueLines == ["日本語ライン"])
    #expect(kanaResults[0].cueGroupLines == ["日本語ライン", "English line"])
}

@Test
func indexingASSStoresUsedStyleLanguageAnalysisOnly() throws {
    let fixture = try IndexingFixture()
    defer {
        fixture.cleanUp()
    }

    _ = try fixture.writeSubtitle(
        name: "Bilingual.ass",
        contents: """
        [Script Info]
        PlayResX: 1920
        PlayResY: 1080

        [V4+ Styles]
        Format: Name, Alignment, MarginL, MarginR, MarginV
        Style: JP,2,20,20,30
        Style: CN,8,20,20,40
        Style: Unused,2,20,20,30

        [Events]
        Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
        Dialogue: 0,0:00:01.00,0:00:03.00,JP,,0,0,0,,今日はライブの準備をします
        Dialogue: 0,0:00:01.00,0:00:03.00,CN,,0,0,0,,我们今天准备演出，大家一起学习新的歌曲。
        Dialogue: 0,0:00:04.00,0:00:06.00,JP,,0,0,0,,明日はスタジオで練習します
        """
    )
    try fixture.writeVideo(name: "Bilingual.mkv")

    let database = try IndexingDatabase(path: fixture.databaseURL)
    let indexer = SubtitleIndexer()

    let result = try indexer.index(folder: fixture.root, into: database)

    #expect(result.indexedSubtitleFiles == 1)
    let indexedSubtitlePath = try #require(try database.subtitleFiles().first?.subtitlePath)
    let indexedSubtitleURL = URL(fileURLWithPath: indexedSubtitlePath)
    #expect(try database.hasCurrentSubtitleLanguageManifest(forSubtitleFile: indexedSubtitleURL))

    let detections = try database.languageDetections(forSubtitleFile: indexedSubtitleURL)
    #expect(detections.map(\.scopeKey) == ["CN", "JP"])
    #expect(detections.first { $0.scopeKey == "CN" }?.languages == [.simplifiedChinese])
    #expect(detections.first { $0.scopeKey == "JP" }?.languages == [.japanese])

    let storedEntries = try PlaybackSubtitleDatabase(path: fixture.databaseURL)
        .entries(forSubtitleFile: indexedSubtitleURL)
    let firstEntry = try #require(storedEntries.first)
    let secondEntry = try #require(storedEntries.dropFirst().first)
    let languagesByCueGroupID = try database.cueGroupLanguages(forSubtitleFile: indexedSubtitleURL)
    #expect(languagesByCueGroupID[firstEntry.id] == [.japanese, .simplifiedChinese])
    #expect(languagesByCueGroupID[secondEntry.id] == [.japanese])
}

@Test
func addingASSStylesDoesNotChangeUnmodifiedJapaneseCueIDs() throws {
    let fixture = try IndexingFixture()
    defer {
        fixture.cleanUp()
    }

    let subtitleURL = try fixture.writeSubtitle(
        name: "Bilingual.ass",
        contents: """
        [Events]
        Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
        Dialogue: 0,0:00:01.00,0:00:03.00,JP,,0,0,0,,今日はライブの準備をします
        Dialogue: 0,0:00:04.00,0:00:06.00,JP,,0,0,0,,明日はスタジオで練習します
        """
    )
    _ = try fixture.writeVideo(name: "Bilingual.mkv")

    let database = try IndexingDatabase(path: fixture.databaseURL)
    let indexer = SubtitleIndexer()
    _ = try indexer.index(folder: fixture.root, into: database)
    let search = try SearchDatabase(path: fixture.databaseURL)
    let firstCueID = try #require(try search.search("ライブ").first?.entryID)
    let secondCueID = try #require(try search.search("スタジオ").first?.entryID)

    try """
    [Events]
    Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
    Dialogue: 0,0:00:01.00,0:00:03.00,CN,,0,0,0,,今天准备演出
    Dialogue: 0,0:00:01.00,0:00:03.00,JP,,0,0,0,,今日はライブの準備をします
    Dialogue: 0,0:00:04.00,0:00:06.00,CN,,0,0,0,,明天去录音室练习
    Dialogue: 0,0:00:04.00,0:00:06.00,JP,,0,0,0,,明日はスタジオで練習します
    """.write(to: subtitleURL, atomically: false, encoding: .utf8)
    _ = try indexer.index(folder: fixture.root, into: database)

    #expect(try search.search("ライブ").first?.entryID == firstCueID)
    #expect(try search.search("スタジオ").first?.entryID == secondCueID)
}

@Test
func ambiguousSameTimeSRTContentChangesReceiveNewCueIDs() throws {
    let fixture = try IndexingFixture()
    defer {
        fixture.cleanUp()
    }

    let subtitleURL = try fixture.writeSubtitle(
        name: "Ambiguous.srt",
        contents: """
        1
        00:00:01,000 --> 00:00:03,000
        First original.

        2
        00:00:01,000 --> 00:00:03,000
        Second original.

        """
    )
    _ = try fixture.writeVideo(name: "Ambiguous.mkv")

    let database = try IndexingDatabase(path: fixture.databaseURL)
    let indexer = SubtitleIndexer()
    _ = try indexer.index(folder: fixture.root, into: database)
    let search = try SearchDatabase(path: fixture.databaseURL)
    let oldCueIDs = Set([
        try #require(try search.search("First original").first?.entryID),
        try #require(try search.search("Second original").first?.entryID)
    ])

    try """
    1
    00:00:01,000 --> 00:00:03,000
    First replacement text.

    2
    00:00:01,000 --> 00:00:03,000
    Second replacement text.

    """.write(to: subtitleURL, atomically: false, encoding: .utf8)
    _ = try indexer.index(folder: fixture.root, into: database)

    let newCueIDs = Set([
        try #require(try search.search("First replacement").first?.entryID),
        try #require(try search.search("Second replacement").first?.entryID)
    ])
    #expect(oldCueIDs.isDisjoint(with: newCueIDs))
}

@Test
func inheritedTextChangeNoticeLastsForOneSuccessfulIndex() throws {
    let fixture = try IndexingFixture()
    defer {
        fixture.cleanUp()
    }

    let subtitleURL = try fixture.writeSubtitle(
        name: "Changed.srt",
        contents: """
        1
        00:00:01,000 --> 00:00:03,000
        Previous text.

        """
    )
    _ = try fixture.writeVideo(name: "Changed.mkv")

    let database = try IndexingDatabase(path: fixture.databaseURL)
    let indexer = SubtitleIndexer()
    _ = try indexer.index(folder: fixture.root, into: database)
    let search = try SearchDatabase(path: fixture.databaseURL)
    let originalCueID = try #require(try search.search("Previous").first?.entryID)

    try """
    1
    00:00:01,000 --> 00:00:03,000
    Current edited text.

    """.write(to: subtitleURL, atomically: false, encoding: .utf8)
    _ = try indexer.index(folder: fixture.root, into: database)

    #expect(try search.search("Current edited").first?.entryID == originalCueID)
    #expect(
        try queryString(
            at: fixture.databaseURL,
            sql: """
            SELECT previous_content || '|' || current_content
            FROM cue_change_notices
            WHERE cue_id = \(originalCueID);
            """
        ) == "Previous text.|Current edited text."
    )

    _ = try indexer.index(folder: fixture.root, into: database)
    #expect(
        try queryInt(
            at: fixture.databaseURL,
            sql: "SELECT COUNT(*) FROM cue_change_notices WHERE cue_id = \(originalCueID);"
        ) == 0
    )
}

@Test
func indexesASSFontReferencesAndSkipsUnchangedAfterManifest() throws {
    let fixture = try IndexingFixture()
    defer {
        fixture.cleanUp()
    }

    _ = try fixture.writeSubtitle(
        name: "Episode.ass",
        contents: """
        [Script Info]
        PlayResX: 1920
        PlayResY: 1080

        [V4+ Styles]
        Format: Name, Fontname, Fontsize
        Style: Default,华文中宋,42
        Style: Title,EPSON 太明朝体Ｂ,28

        [Events]
        Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
        Dialogue: 0,0:00:01.00,0:00:03.00,Default,,0,0,0,,{\\fn汉仪小隶书简}Styled text
        Dialogue: 0,0:00:04.00,0:00:05.00,Title,,0,0,0,,Plain title
        """
    )
    try fixture.writeVideo(name: "Episode.mkv")

    let database = try IndexingDatabase(path: fixture.databaseURL)
    let indexer = SubtitleIndexer()

    let initialResult = try indexer.index(folder: fixture.root, into: database)
    let indexedSubtitlePath = try #require(try database.subtitleFiles().first?.subtitlePath)
    let indexedSubtitleURL = URL(fileURLWithPath: indexedSubtitlePath)
    let playback = try PlaybackSubtitleDatabase(path: fixture.databaseURL)
    let references = try playback.assFontReferences(forSubtitleFile: indexedSubtitleURL)
    let unchangedResult = try indexer.index(folder: fixture.root, into: database)

    #expect(initialResult.indexedSubtitleFiles == 1)
    #expect(references.map(\.fontName) == ["华文中宋", "EPSON 太明朝体Ｂ", "汉仪小隶书简"])
    #expect(references.map(\.source) == [.style, .style, .inlineOverride])
    #expect(try playback.hasCurrentASSFontReferenceManifest(forSubtitleFile: indexedSubtitleURL))
    #expect(unchangedResult.indexedSubtitleFiles == 0)
    #expect(unchangedResult.skippedUnchangedSubtitleFiles == 1)
}

@Test
func reindexesUnchangedSubtitleWhenCueIndexAlgorithmVersionIsStale() throws {
    let fixture = try IndexingFixture()
    defer {
        fixture.cleanUp()
    }

    _ = try fixture.writeSubtitle(
        name: "Episode.srt",
        contents: """
        1
        00:00:01,000 --> 00:00:03,000
        Versioned searchable text.

        """
    )
    try fixture.writeVideo(name: "Episode.mkv")

    let database = try IndexingDatabase(path: fixture.databaseURL)
    let indexer = SubtitleIndexer()

    let initialResult = try indexer.index(folder: fixture.root, into: database)
    let initialMetadata = try #require(try database.subtitleFiles().first)
    try executeSQLite(
        at: fixture.databaseURL,
        "UPDATE subtitle_files SET index_algorithm_version = 0;"
    )

    let staleVersionResult = try indexer.index(folder: fixture.root, into: database)
    let refreshedMetadata = try #require(try database.subtitleFiles().first)

    #expect(initialResult.indexedSubtitleFiles == 1)
    #expect(initialMetadata.indexAlgorithmVersion == SubtitleCueIndexingRules.algorithmVersion)
    #expect(staleVersionResult.indexedSubtitleFiles == 1)
    #expect(staleVersionResult.skippedUnchangedSubtitleFiles == 0)
    #expect(refreshedMetadata.indexAlgorithmVersion == SubtitleCueIndexingRules.algorithmVersion)
}

@Test
func assRenderSegmenterBuildsWindowedScriptsWithOverlappingEvents() throws {
    let contents = """
    [Script Info]
    PlayResX: 1920
    PlayResY: 1080

    [V4+ Styles]
    Format: Name, Fontname, Fontsize
    Style: Default,Arial,48

    [Events]
    Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
    Dialogue: 0,0:00:25.00,0:00:35.00,Default,,0,0,0,fx,{\\blur2}overlap
    Dialogue: 0,0:01:05.00,0:01:06.00,Default,,0,0,0,,late
    """

    let segments = ASSRenderSegmenter.renderSegments(from: contents)

    #expect(segments.count == 2)
    #expect(segments[0].startMilliseconds == 0)
    #expect(segments[0].endMilliseconds == 60_000)
    #expect(segments[0].eventCount == 1)
    #expect(segments[0].scriptText.contains("overlap"))
    #expect(segments[1].eventCount == 1)
    #expect(segments[1].scriptText.contains("late"))
    #expect(segments[1].scriptText.contains("[V4+ Styles]"))
}

@Test
func assRenderSegmenterUsesComplexityBudgetForDenseEffects() throws {
    let denseLines = (0..<1_600)
        .map { index in
            "Dialogue: 0,0:01:25.00,0:02:55.00,Default,,0,0,0,,{\\p1\\clip(m 0 0 l 80 0 80 20 0 20)\\t(0,1000,\\blur8\\alpha&H80&)}m 0 0 l 80 0 80 20 0 20 dense-\(index)"
        }
        .joined(separator: "\n")
    let contents = """
    [Script Info]
    PlayResX: 1920
    PlayResY: 1080

    [V4+ Styles]
    Format: Name, Fontname, Fontsize
    Style: Default,Arial,48

    [Events]
    Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
    Dialogue: 0,0:00:05.00,0:00:06.00,Default,,0,0,0,,plain
    \(denseLines)
    Dialogue: 0,0:03:05.00,0:03:06.00,Default,,0,0,0,,late
    """

    let segments = ASSRenderSegmenter.renderSegments(from: contents)

    #expect(ASSRenderSegmenter.shouldSegment(format: .ass, fileSize: 256 * 1024))
    #expect(!ASSRenderSegmenter.shouldSegment(format: .ass, fileSize: 256 * 1024 - 1))
    #expect(!ASSRenderSegmenter.shouldSegment(format: .srt, fileSize: 512 * 1024))
    #expect(segments.first?.startMilliseconds == 0)
    #expect(segments.first?.endMilliseconds == 60_000)
    #expect(segments.contains { $0.startMilliseconds == 85_000 && $0.endMilliseconds == 90_000 })
    #expect(segments.contains { $0.startMilliseconds == 170_000 && $0.endMilliseconds == 175_000 })
    #expect(segments.first { $0.startMilliseconds == 85_000 }?.scriptText.contains("dense-0") == true)
    #expect(segments.last?.scriptText.contains("late") == true)
}

@Test
func referencedCueTombstoneSurvivesMissingResourcesAndRestoresCueID() throws {
    let fixture = try IndexingFixture()
    defer {
        fixture.cleanUp()
    }

    let contents = """
    [Script Info]
    PlayResX: 1920
    PlayResY: 1080

    [V4+ Styles]
    Format: Name, Fontname, Fontsize
    Style: Default,Arial,48

    [Events]
    Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
    Dialogue: 0,0:00:01.00,0:00:03.00,Default,,0,0,0,,Persisted Shiori Cue.\\NSecond line.
    Dialogue: 0,0:00:01.00,0:00:03.00,Default,,0,0,0,,Sibling Cue.
    Dialogue: 0,0:00:04.00,0:00:06.00,Default,,0,0,0,,Unreferenced Cue.
    """
    let subtitleFile = try fixture.writeSubtitle(
        name: "Lifecycle.ass",
        contents: contents
    )
    let videoFile = try fixture.writeVideo(name: "Lifecycle.mkv")
    let database = try IndexingDatabase(path: fixture.databaseURL)
    let indexer = SubtitleIndexer()
    let initialResult = try indexer.index(folder: fixture.root, into: database)
    #expect(initialResult.indexedSubtitleFiles == 1)
    #expect(initialResult.skippedMissingVideo == 0)
    let indexedMetadata = try #require(try database.subtitleFiles().first)
    let indexedSubtitleFile = URL(fileURLWithPath: indexedMetadata.subtitlePath)
    let indexedVideoFile = URL(
        fileURLWithPath: try #require(indexedMetadata.videoPath)
    )

    let selection = shioriSelection(
        try #require(
            try PlaybackSubtitleDatabase(path: fixture.databaseURL)
                .cueLineRecords(forSubtitleFile: indexedSubtitleFile)
                .first
        )
    )
    let originalCueID = try #require(selection.cueLineID)
    let shioriDatabase = try ShioriDatabase(path: fixture.databaseURL)
    let saved = try shioriDatabase.upsertShiori(selection: selection)
    let libraryDatabase = try LibraryDatabase(path: fixture.databaseURL)
    try libraryDatabase.refreshPresentationAfterIndexedContentChange()
    try libraryDatabase.upsertLibraryPlaybackHistory(
        videoFile: indexedVideoFile,
        positionMilliseconds: 1_500,
        duration: 120
    )
    #expect(try libraryDatabase.libraryPresentation(under: [fixture.root]).count == 1)
    #expect(try libraryDatabase.recentLibraryWatching(under: [fixture.root]).count == 1)
    let destination = try shioriDatabase.createShioriList(
        name: "Destination",
        description: "",
        coverPath: nil
    )

    try FileManager.default.removeItem(at: videoFile)
    _ = try indexer.index(folder: fixture.root, into: database)

    let videoUnavailable = try #require(try shioriDatabase.shiori(id: saved.id))
    #expect(videoUnavailable.unavailableReason == .videoMissing)
    #expect(
        URL(fileURLWithPath: videoUnavailable.subtitlePath).resolvingSymlinksInPath()
            == subtitleFile.resolvingSymlinksInPath()
    )
    #expect(try SearchDatabase(path: fixture.databaseURL).search("Persisted").isEmpty)
    #expect(try libraryDatabase.libraryPresentation(under: [fixture.root]).isEmpty)
    #expect(try libraryDatabase.recentLibraryWatching(under: [fixture.root]).isEmpty)
    #expect(
        try sqliteRowCount(
            in: "library_playback_history",
            databaseURL: fixture.databaseURL
        ) == 1
    )
    #expect(try sqliteRowCount(in: "cue_tombstones", databaseURL: fixture.databaseURL) == 0)

    _ = try fixture.writeVideo(name: "Lifecycle.mkv")
    _ = try indexer.index(folder: fixture.root, into: database)
    #expect(try shioriDatabase.shiori(id: saved.id)?.isValid == true)

    try FileManager.default.removeItem(at: subtitleFile)
    _ = try indexer.index(folder: fixture.root, into: database)

    let subtitleUnavailable = try #require(try shioriDatabase.shiori(id: saved.id))
    #expect(subtitleUnavailable.unavailableReason == .subtitleMissing)
    #expect(subtitleUnavailable.content == "Persisted Shiori Cue.\nSecond line.")
    #expect(
        subtitleUnavailable.cueGroupContent.components(
            separatedBy: Shiori.cueGroupContentSeparator
        ) == [
            "Persisted Shiori Cue.\nSecond line.",
            "Sibling Cue.",
        ]
    )
    #expect(try sqliteRowCount(in: "cue_tombstones", databaseURL: fixture.databaseURL) == 1)

    let detachedVideo = fixture.root
        .appendingPathComponent(".offline", isDirectory: true)
        .appendingPathComponent(videoFile.lastPathComponent)
    try FileManager.default.createDirectory(
        at: detachedVideo.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try FileManager.default.moveItem(at: videoFile, to: detachedVideo)
    _ = try indexer.index(folder: fixture.root, into: database)
    #expect(
        try shioriDatabase.shiori(id: saved.id)?.unavailableReason
            == .videoAndSubtitleMissing
    )

    try FileManager.default.moveItem(at: detachedVideo, to: videoFile)
    _ = try indexer.index(folder: fixture.root, into: database)
    #expect(
        try shioriDatabase.shiori(id: saved.id)?.unavailableReason
            == .subtitleMissing
    )

    #expect(throws: ShioriTransferError.sourceUnavailable) {
        _ = try shioriDatabase.duplicateShiori(
            id: saved.id,
            toListID: destination.id
        )
    }

    _ = try fixture.writeSubtitle(name: "Lifecycle.ass", contents: contents)
    _ = try indexer.index(folder: fixture.root, into: database)

    let restored = try #require(try shioriDatabase.shiori(id: saved.id))
    #expect(restored.isValid)
    #expect(try shioriDatabase.cueID(forShioriID: saved.id) == originalCueID)
    #expect(try sqliteRowCount(in: "cue_tombstones", databaseURL: fixture.databaseURL) == 0)

    try FileManager.default.removeItem(at: subtitleFile)
    _ = try indexer.index(folder: fixture.root, into: database)
    #expect(try sqliteRowCount(in: "cue_tombstones", databaseURL: fixture.databaseURL) == 1)
    #expect(try shioriDatabase.removeShiori(id: saved.id))
    #expect(try sqliteRowCount(in: "cue_tombstones", databaseURL: fixture.databaseURL) == 0)
}

private struct IndexingFixture {
    let root: URL
    let databaseURL: URL

    init() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("CueSeekerIndexerTests-\(UUID().uuidString)")
        databaseURL = root.appendingPathComponent("index.sqlite")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try DatabaseBootstrap.prepare(at: databaseURL)
    }

    @discardableResult
    func writeSubtitle(name: String, contents: String) throws -> URL {
        let url = root.appendingPathComponent(name)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    @discardableResult
    func writeVideo(name: String) throws -> URL {
        let url = root.appendingPathComponent(name)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data().write(to: url)
        return url
    }

    func subtitleFileMetadata(for url: URL) throws -> (fileSize: Int64?, modifiedAt: Date?) {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return (
            (attributes[.size] as? NSNumber)?.int64Value,
            attributes[.modificationDate] as? Date
        )
    }

    func cleanUp() {
        try? FileManager.default.removeItem(at: root)
    }
}

private enum SQLiteFixtureError: Error {
    case openFailed(String)
    case executeFailed(String)
}

private func executeSQLite(at url: URL, _ sql: String) throws {
    var database: OpaquePointer?
    guard sqlite3_open_v2(url.path, &database, SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE, nil) == SQLITE_OK else {
        let message = database.map { String(cString: sqlite3_errmsg($0)) } ?? "Unknown SQLite error"
        sqlite3_close(database)
        throw SQLiteFixtureError.openFailed(message)
    }
    defer {
        sqlite3_close(database)
    }

    var errorMessage: UnsafeMutablePointer<CChar>?
    guard sqlite3_exec(database, sql, nil, nil, &errorMessage) == SQLITE_OK else {
        let message = errorMessage.map { String(cString: $0) } ?? "Unknown SQLite error"
        sqlite3_free(errorMessage)
        throw SQLiteFixtureError.executeFailed(message)
    }
}

private func queryInt(at url: URL, sql: String) throws -> Int64 {
    var database: OpaquePointer?
    guard sqlite3_open_v2(url.path, &database, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
        let message = database.map { String(cString: sqlite3_errmsg($0)) } ?? "Unknown SQLite error"
        sqlite3_close(database)
        throw SQLiteFixtureError.openFailed(message)
    }
    defer {
        sqlite3_close(database)
    }

    var statement: OpaquePointer?
    guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
        throw SQLiteFixtureError.executeFailed(String(cString: sqlite3_errmsg(database)))
    }
    defer {
        sqlite3_finalize(statement)
    }
    guard sqlite3_step(statement) == SQLITE_ROW else {
        throw SQLiteFixtureError.executeFailed(
            "No row for query: \(sql)"
        )
    }
    return sqlite3_column_int64(statement, 0)
}

private func queryString(at url: URL, sql: String) throws -> String? {
    var database: OpaquePointer?
    guard sqlite3_open_v2(url.path, &database, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
        let message = database.map { String(cString: sqlite3_errmsg($0)) } ?? "Unknown SQLite error"
        sqlite3_close(database)
        throw SQLiteFixtureError.openFailed(message)
    }
    defer {
        sqlite3_close(database)
    }

    var statement: OpaquePointer?
    guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
        throw SQLiteFixtureError.executeFailed(String(cString: sqlite3_errmsg(database)))
    }
    defer {
        sqlite3_finalize(statement)
    }
    guard sqlite3_step(statement) == SQLITE_ROW,
          let value = sqlite3_column_text(statement, 0)
    else {
        return nil
    }
    return String(cString: value)
}
