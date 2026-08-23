import Foundation
import Testing
@testable import CueSeekerCore

@Test
func movingLibraryRootGetsNewLibraryIDAndOldPathKeepsTheOriginalID() throws {
    let container = FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerLibraryBinding-\(UUID().uuidString)")
    let originalRoot = container.appendingPathComponent("Library")
    let movedRoot = container.appendingPathComponent("Moved Library")
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: container)
        try? FileManager.default.removeItem(at: databaseURL)
    }

    try FileManager.default.createDirectory(
        at: originalRoot,
        withIntermediateDirectories: true
    )
    try DatabaseBootstrap.prepare(at: databaseURL)
    let database = try IndexingDatabase(path: databaseURL)
    let originalID = try database.addSearchPath(originalRoot)

    try FileManager.default.moveItem(at: originalRoot, to: movedRoot)
    let movedID = try database.addSearchPath(movedRoot)
    try FileManager.default.createDirectory(
        at: originalRoot,
        withIntermediateDirectories: true
    )
    let replacementID = try database.addSearchPath(originalRoot)

    // The absolute path is the Library identity: a moved root is a new Library,
    // and whatever appears at the old path keeps the original LibraryID.
    #expect(movedID != originalID)
    #expect(replacementID == originalID)
}

@Test
func samePathAlwaysKeepsItsPermanentID() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }
    try DatabaseBootstrap.prepare(at: databaseURL)
    let database = try IndexingDatabase(path: databaseURL)
    let subtitle = URL(
        fileURLWithPath: "/Unavailable NAS/Episode.srt"
    )
    let video = URL(
        fileURLWithPath: "/Unavailable NAS/Episode.mkv"
    )

    try database.replaceEntries(
        subtitleFile: subtitle,
        videoFile: video,
        entries: [simpleTestEntry(text: "Original NAS text")]
    )
    let originalSubtitleID = try #require(
        try sqliteRowID(
            table: "subtitle_files",
            pathColumn: "subtitle_path",
            path: subtitle.path,
            databaseURL: databaseURL
        )
    )
    let originalVideoID = try #require(
        try sqliteRowID(
            table: "video_files",
            pathColumn: "path",
            path: video.path,
            databaseURL: databaseURL
        )
    )

    try database.replaceEntries(
        subtitleFile: subtitle,
        videoFile: video,
        entries: [simpleTestEntry(text: "Edited NAS text")]
    )

    #expect(
        try sqliteRowID(
            table: "subtitle_files",
            pathColumn: "subtitle_path",
            path: subtitle.path,
            databaseURL: databaseURL
        ) == originalSubtitleID
    )
    #expect(
        try sqliteRowID(
            table: "video_files",
            pathColumn: "path",
            path: video.path,
            databaseURL: databaseURL
        ) == originalVideoID
    )
}

@Test
func movingLibraryFolderCreatesNewVideoSubtitleAndCueIDs() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerBindingMove-\(UUID().uuidString)")
    let originalFolder = root.appendingPathComponent("Season")
    let movedFolder = root.appendingPathComponent("Renamed Season")
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: root)
        try? FileManager.default.removeItem(at: databaseURL)
    }

    try FileManager.default.createDirectory(
        at: originalFolder,
        withIntermediateDirectories: true
    )
    let originalSubtitle = originalFolder.appendingPathComponent("Episode.srt")
    let originalVideo = originalFolder.appendingPathComponent("Episode.mkv")
    try "stable subtitle".write(to: originalSubtitle, atomically: true, encoding: .utf8)
    try Data([0x01, 0x02]).write(to: originalVideo)

    try DatabaseBootstrap.prepare(at: databaseURL)
    let database = try IndexingDatabase(path: databaseURL)
    _ = try database.addSearchPath(root)
    try database.replaceEntries(
        subtitleFile: originalSubtitle,
        videoFile: originalVideo,
        entries: [simpleTestEntry(text: "stable subtitle")]
    )

    let originalFolderID = try #require(try sqliteRowID(
        table: "library_folders",
        pathColumn: "relative_path",
        path: "Season",
        databaseURL: databaseURL
    ))
    let originalSubtitleID = try #require(try sqliteRowID(
        table: "subtitle_files",
        pathColumn: "subtitle_path",
        path: originalSubtitle.path,
        databaseURL: databaseURL
    ))
    let originalVideoID = try #require(try sqliteRowID(
        table: "video_files",
        pathColumn: "path",
        path: originalVideo.path,
        databaseURL: databaseURL
    ))
    let originalCueID = try #require(
        try PlaybackSubtitleDatabase(path: databaseURL)
            .cueLineRecords(forSubtitleFile: originalSubtitle)
            .first?.id
    )

    try FileManager.default.moveItem(at: originalFolder, to: movedFolder)
    let movedSubtitle = movedFolder.appendingPathComponent("Episode.srt")
    let movedVideo = movedFolder.appendingPathComponent("Episode.mkv")
    try database.replaceEntries(
        subtitleFile: movedSubtitle,
        videoFile: movedVideo,
        entries: [simpleTestEntry(text: "stable subtitle")]
    )

    #expect(try sqliteRowID(
        table: "library_folders",
        pathColumn: "relative_path",
        path: "Renamed Season",
        databaseURL: databaseURL
    ) != originalFolderID)
    #expect(try sqliteRowID(
        table: "subtitle_files",
        pathColumn: "subtitle_path",
        path: movedSubtitle.path,
        databaseURL: databaseURL
    ) != originalSubtitleID)
    #expect(try sqliteRowID(
        table: "video_files",
        pathColumn: "path",
        path: movedVideo.path,
        databaseURL: databaseURL
    ) != originalVideoID)
    #expect(
        try PlaybackSubtitleDatabase(path: databaseURL)
            .cueLineRecords(forSubtitleFile: movedSubtitle)
            .first?.id != originalCueID
    )
}

@Test
func userFolderCoverStaysWithItsFolderPath() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerFolderCoverBinding-\(UUID().uuidString)")
    let originalFolder = root.appendingPathComponent("Season")
    let movedFolder = root.appendingPathComponent("Archive")
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: root)
        try? FileManager.default.removeItem(at: databaseURL)
    }

    try FileManager.default.createDirectory(
        at: originalFolder,
        withIntermediateDirectories: true
    )
    let originalSubtitle = originalFolder.appendingPathComponent("Episode.srt")
    let originalVideo = originalFolder.appendingPathComponent("Episode.mkv")
    try "original".write(to: originalSubtitle, atomically: true, encoding: .utf8)
    try Data([0x01]).write(to: originalVideo)

    try DatabaseBootstrap.prepare(at: databaseURL)
    let database = try IndexingDatabase(path: databaseURL)
    _ = try database.addSearchPath(root)
    try database.replaceEntries(
        subtitleFile: originalSubtitle,
        videoFile: originalVideo,
        entries: [simpleTestEntry(text: "original")]
    )
    let covers = try LibraryCoverDatabase(path: databaseURL)
    try covers.upsertLibraryUserFolderCover(
        folderPath: originalFolder.path,
        displayCoverPath: "/Covers/original.jpg"
    )

    try FileManager.default.moveItem(at: originalFolder, to: movedFolder)
    let movedSubtitle = movedFolder.appendingPathComponent("Episode.srt")
    let movedVideo = movedFolder.appendingPathComponent("Episode.mkv")
    try database.replaceEntries(
        subtitleFile: movedSubtitle,
        videoFile: movedVideo,
        entries: [simpleTestEntry(text: "original")]
    )

    // The relative path is the folder identity, so a renamed folder is a new
    // folder and the cover does not travel with it.
    #expect(try covers.libraryUserFolderCover(folderPath: movedFolder.path) == nil)
    #expect(try covers.libraryUserFolderCover(
        folderPath: originalFolder.path
    )?.displayCoverPath == "/Covers/original.jpg")

    try FileManager.default.createDirectory(
        at: originalFolder,
        withIntermediateDirectories: true
    )
    let replacementSubtitle = originalFolder.appendingPathComponent("Episode.srt")
    let replacementVideo = originalFolder.appendingPathComponent("Episode.mkv")
    try "replacement".write(
        to: replacementSubtitle,
        atomically: true,
        encoding: .utf8
    )
    try Data([0x09]).write(to: replacementVideo)
    try database.replaceEntries(
        subtitleFile: replacementSubtitle,
        videoFile: replacementVideo,
        entries: [simpleTestEntry(text: "replacement")]
    )

    try covers.upsertLibraryUserFolderCover(
        folderPath: originalFolder.path,
        displayCoverPath: "/Covers/replacement.jpg"
    )
    #expect(try covers.libraryUserFolderCover(
        folderPath: originalFolder.path
    )?.displayCoverPath == "/Covers/replacement.jpg")
    #expect(try covers.libraryUserFolderCover(folderPath: movedFolder.path) == nil)
}

@Test
func filesReturningToPreviousPathReusePathBoundMediaIDs() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerBindingReplacement-\(UUID().uuidString)")
    let originalFolder = root.appendingPathComponent("Season")
    let movedFolder = root.appendingPathComponent("Archive")
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: root)
        try? FileManager.default.removeItem(at: databaseURL)
    }

    try FileManager.default.createDirectory(
        at: originalFolder,
        withIntermediateDirectories: true
    )
    let originalSubtitle = originalFolder.appendingPathComponent("Episode.srt")
    let originalVideo = originalFolder.appendingPathComponent("Episode.mkv")
    try "original".write(to: originalSubtitle, atomically: true, encoding: .utf8)
    try Data([0x01]).write(to: originalVideo)

    try DatabaseBootstrap.prepare(at: databaseURL)
    let database = try IndexingDatabase(path: databaseURL)
    _ = try database.addSearchPath(root)
    try database.replaceEntries(
        subtitleFile: originalSubtitle,
        videoFile: originalVideo,
        entries: [simpleTestEntry(text: "original")]
    )
    let originalSubtitleID = try #require(try sqliteRowID(
        table: "subtitle_files",
        pathColumn: "subtitle_path",
        path: originalSubtitle.path,
        databaseURL: databaseURL
    ))
    let originalVideoID = try #require(try sqliteRowID(
        table: "video_files",
        pathColumn: "path",
        path: originalVideo.path,
        databaseURL: databaseURL
    ))

    try FileManager.default.moveItem(at: originalFolder, to: movedFolder)
    try FileManager.default.createDirectory(
        at: originalFolder,
        withIntermediateDirectories: true
    )
    let movedSubtitle = movedFolder.appendingPathComponent("Episode.srt")
    let movedVideo = movedFolder.appendingPathComponent("Episode.mkv")
    try database.replaceEntries(
        subtitleFile: movedSubtitle,
        videoFile: movedVideo,
        entries: [simpleTestEntry(text: "original")]
    )

    let replacementSubtitle = originalFolder.appendingPathComponent("Episode.srt")
    let replacementVideo = originalFolder.appendingPathComponent("Episode.mkv")
    try "replacement".write(
        to: replacementSubtitle,
        atomically: true,
        encoding: .utf8
    )
    try Data([0x09]).write(to: replacementVideo)
    try database.replaceEntries(
        subtitleFile: replacementSubtitle,
        videoFile: replacementVideo,
        entries: [simpleTestEntry(text: "replacement")]
    )

    #expect(try sqliteRowID(
        table: "subtitle_files",
        pathColumn: "subtitle_path",
        path: movedSubtitle.path,
        databaseURL: databaseURL
    ) != originalSubtitleID)
    #expect(try sqliteRowID(
        table: "video_files",
        pathColumn: "path",
        path: movedVideo.path,
        databaseURL: databaseURL
    ) != originalVideoID)
    #expect(try sqliteRowID(
        table: "subtitle_files",
        pathColumn: "subtitle_path",
        path: replacementSubtitle.path,
        databaseURL: databaseURL
    ) == originalSubtitleID)
    #expect(try sqliteRowID(
        table: "video_files",
        pathColumn: "path",
        path: replacementVideo.path,
        databaseURL: databaseURL
    ) == originalVideoID)
}

@Test
func samePathVideoReplacementKeepsPathBoundPlaybackHistory() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerVideoHistoryBinding-\(UUID().uuidString)")
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: root)
        try? FileManager.default.removeItem(at: databaseURL)
    }

    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let subtitle = root.appendingPathComponent("Episode.srt")
    let video = root.appendingPathComponent("Episode.mkv")
    let archivedSubtitle = root.appendingPathComponent("Archived.srt")
    let archivedVideo = root.appendingPathComponent("Archived.mkv")
    try "old subtitle".write(to: subtitle, atomically: true, encoding: .utf8)
    try Data([0x01]).write(to: video)

    try DatabaseBootstrap.prepare(at: databaseURL)
    let database = try IndexingDatabase(path: databaseURL)
    _ = try database.addSearchPath(root)
    try database.replaceEntries(
        subtitleFile: subtitle,
        videoFile: video,
        entries: [simpleTestEntry(text: "old subtitle")]
    )
    try LibraryDatabase(path: databaseURL).upsertLibraryPlaybackHistory(
        videoFile: video,
        positionMilliseconds: 42_000,
        duration: 1_200
    )

    try FileManager.default.moveItem(at: subtitle, to: archivedSubtitle)
    try FileManager.default.moveItem(at: video, to: archivedVideo)
    try database.replaceEntries(
        subtitleFile: archivedSubtitle,
        videoFile: archivedVideo,
        entries: [simpleTestEntry(text: "old subtitle")]
    )
    try "new subtitle".write(to: subtitle, atomically: true, encoding: .utf8)
    try Data([0x09]).write(to: video)
    try database.replaceEntries(
        subtitleFile: subtitle,
        videoFile: video,
        entries: [simpleTestEntry(text: "new subtitle")]
    )

    #expect(try LibraryDatabase(path: databaseURL)
        .libraryPlaybackHistory(forVideoFile: video)?
        .positionMilliseconds == 42_000)
    #expect(try LibraryDatabase(path: databaseURL)
        .libraryPlaybackHistory(forVideoFile: archivedVideo) == nil)
}

@Test
func copiedSubtitleAtDifferentPathReceivesNewSubtitleID() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerBindingCopy-\(UUID().uuidString)")
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: root)
        try? FileManager.default.removeItem(at: databaseURL)
    }

    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let originalSubtitle = root.appendingPathComponent("Original.srt")
    let copiedSubtitle = root.appendingPathComponent("Copied.srt")
    let video = root.appendingPathComponent("Episode.mkv")
    try "identical complete content".write(
        to: originalSubtitle,
        atomically: true,
        encoding: .utf8
    )
    try Data([0x01]).write(to: video)

    try DatabaseBootstrap.prepare(at: databaseURL)
    let database = try IndexingDatabase(path: databaseURL)
    _ = try database.addSearchPath(root)
    try database.replaceEntries(
        subtitleFile: originalSubtitle,
        videoFile: video,
        entries: [simpleTestEntry(text: "identical complete content")]
    )
    let originalID = try #require(try sqliteRowID(
        table: "subtitle_files",
        pathColumn: "subtitle_path",
        path: originalSubtitle.path,
        databaseURL: databaseURL
    ))

    try FileManager.default.copyItem(at: originalSubtitle, to: copiedSubtitle)
    try FileManager.default.removeItem(at: originalSubtitle)
    try database.replaceEntries(
        subtitleFile: copiedSubtitle,
        videoFile: video,
        entries: [simpleTestEntry(text: "identical complete content")]
    )

    #expect(try sqliteRowID(
        table: "subtitle_files",
        pathColumn: "subtitle_path",
        path: copiedSubtitle.path,
        databaseURL: databaseURL
    ) != originalID)
}

@Test
func sameContentAtDifferentPathGetsNewSubtitleID() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerBindingConflict-\(UUID().uuidString)")
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: root)
        try? FileManager.default.removeItem(at: databaseURL)
    }

    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let firstSubtitle = root.appendingPathComponent("First.srt")
    let secondSubtitle = root.appendingPathComponent("Second.srt")
    let candidateSubtitle = root.appendingPathComponent("Candidate.srt")
    let video = root.appendingPathComponent("Episode.mkv")
    for subtitle in [firstSubtitle, secondSubtitle] {
        try "duplicate complete content".write(
            to: subtitle,
            atomically: true,
            encoding: .utf8
        )
    }
    try Data([0x01]).write(to: video)

    try DatabaseBootstrap.prepare(at: databaseURL)
    let database = try IndexingDatabase(path: databaseURL)
    _ = try database.addSearchPath(root)
    try database.replaceEntries(
        subtitleFile: firstSubtitle,
        videoFile: video,
        entries: [simpleTestEntry(text: "duplicate complete content")]
    )
    try database.replaceEntries(
        subtitleFile: secondSubtitle,
        videoFile: video,
        entries: [simpleTestEntry(text: "duplicate complete content")]
    )
    let oldIDs = Set([
        try #require(try sqliteRowID(
            table: "subtitle_files",
            pathColumn: "subtitle_path",
            path: firstSubtitle.path,
            databaseURL: databaseURL
        )),
        try #require(try sqliteRowID(
            table: "subtitle_files",
            pathColumn: "subtitle_path",
            path: secondSubtitle.path,
            databaseURL: databaseURL
        ))
    ])

    try FileManager.default.removeItem(at: firstSubtitle)
    try FileManager.default.removeItem(at: secondSubtitle)
    try "duplicate complete content".write(
        to: candidateSubtitle,
        atomically: true,
        encoding: .utf8
    )
    try database.replaceEntries(
        subtitleFile: candidateSubtitle,
        videoFile: video,
        entries: [simpleTestEntry(text: "duplicate complete content")]
    )

    let candidateID = try #require(try sqliteRowID(
        table: "subtitle_files",
        pathColumn: "subtitle_path",
        path: candidateSubtitle.path,
        databaseURL: databaseURL
    ))
    #expect(!oldIDs.contains(candidateID))
}

@Test
func indexedMediaStoresLibraryIDAndRelativePaths() throws {
    let databaseURL = temporaryDatabaseURL()
    let libraryFolder = FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerIdentityLibrary-\(UUID().uuidString)")
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try IndexingDatabase(path: databaseURL)
    try DatabaseBootstrap.prepare(at: databaseURL)
    let libraryID = try database.addSearchPath(libraryFolder)
    let subtitleFile = libraryFolder
        .appendingPathComponent("Season 1")
        .appendingPathComponent("Episode 1.srt")
    let videoFile = libraryFolder
        .appendingPathComponent("Season 1")
        .appendingPathComponent("Episode 1.mkv")

    try database.replaceEntries(
        subtitleFile: subtitleFile,
        videoFile: videoFile,
        entries: [
            SubtitleEntry(
                sequenceNumber: 1,
                startTimecode: "00:00:01,000",
                endTimecode: "00:00:02,000",
                startMilliseconds: 1_000,
                endMilliseconds: 2_000,
                text: "relative identity"
            )
        ]
    )

    let subtitleIdentity = try sqliteMediaIdentity(
        table: "subtitle_files",
        pathColumn: "subtitle_path",
        path: subtitleFile.path,
        databaseURL: databaseURL
    )
    #expect(subtitleIdentity?.libraryID == libraryID)
    #expect(subtitleIdentity?.relativePath == "Season 1/Episode 1.srt")

    let videoIdentity = try sqliteMediaIdentity(
        table: "video_files",
        pathColumn: "path",
        path: videoFile.path,
        databaseURL: databaseURL
    )
    #expect(videoIdentity?.libraryID == libraryID)
    #expect(videoIdentity?.relativePath == "Season 1/Episode 1.mkv")
    #expect(try sqliteCueLinesReferenceSubtitleFile(databaseURL: databaseURL))
}

@Test
func reindexPreservesSubtitleIDAndLibraryStateReferencesVideoID() throws {
    let databaseURL = temporaryDatabaseURL()
    let libraryFolder = FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerPermanentState-\(UUID().uuidString)")
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try IndexingDatabase(path: databaseURL)
    try DatabaseBootstrap.prepare(at: databaseURL)
    _ = try database.addSearchPath(libraryFolder)
    let subtitleFile = libraryFolder.appendingPathComponent("Episode.srt")
    let videoFile = libraryFolder.appendingPathComponent("Episode.mkv")

    try database.replaceEntries(
        subtitleFile: subtitleFile,
        videoFile: videoFile,
        entries: [simpleTestEntry(text: "before")]
    )
    let originalSubtitleID = try #require(
        try sqliteRowID(
            table: "subtitle_files",
            pathColumn: "subtitle_path",
            path: subtitleFile.path,
            databaseURL: databaseURL
        )
    )
    let videoID = try #require(
        try sqliteRowID(
            table: "video_files",
            pathColumn: "path",
            path: videoFile.path,
            databaseURL: databaseURL
        )
    )

    try LibraryDatabase(path: databaseURL).upsertLibraryPlaybackHistory(
        videoFile: videoFile,
        positionMilliseconds: 1_500,
        duration: 24 * 60
    )
    try LibraryDatabase(path: database.path).refreshPresentationAfterIndexedContentChange()
    try database.replaceEntries(
        subtitleFile: subtitleFile,
        videoFile: videoFile,
        entries: [simpleTestEntry(text: "after")]
    )

    #expect(
        try sqliteRowID(
            table: "subtitle_files",
            pathColumn: "subtitle_path",
            path: subtitleFile.path,
            databaseURL: databaseURL
        ) == originalSubtitleID
    )
    // Progress and watch state are keyed by the VideoID, not by a path.
    #expect(
        try sqliteStringValue(
            at: databaseURL,
            sql: "SELECT video_file_id FROM library_playback_history;"
        ) == String(videoID)
    )
    #expect(
        try sqliteStringValue(
            at: databaseURL,
            sql: "SELECT video_file_id FROM library_watch_states;"
        ) == String(videoID)
    )
}

@Test
func upsertsSearchPathAndReturnsStableID() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try IndexingDatabase(path: databaseURL)
    try DatabaseBootstrap.prepare(at: databaseURL)

    let folder = URL(fileURLWithPath: "/tmp/CueSeeker/Subtitles")
    let firstID = try database.addSearchPath(folder)
    let secondID = try database.addSearchPath(folder)

    #expect(firstID == secondID)
}

@Test
func insertingCueGroupsRecordsTheirLineCount() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try IndexingDatabase(path: databaseURL)
    try DatabaseBootstrap.prepare(at: databaseURL)

    let subtitleFile = URL(fileURLWithPath: "/Media/Mixed.ass")
    let videoFile = URL(fileURLWithPath: "/Media/Mixed.mkv")

    try database.replaceCueGroups(
        subtitleFile: subtitleFile,
        videoFile: videoFile,
        format: .ass,
        cueGroups: [
            testCueGroup(
                startMilliseconds: 0,
                endMilliseconds: 1_000,
                content: "single",
                eventIndex: 0
            ),
            SubtitleCueGroup(
                sequenceNumber: nil,
                startTimecode: "1000",
                endTimecode: "2000",
                startMilliseconds: 1_000,
                endMilliseconds: 2_000,
                searchContent: "top\nbottom",
                cueLines: [
                    testCueLine(eventIndex: 1, startMilliseconds: 1_000, endMilliseconds: 2_000, content: "top", displayOrder: 0),
                    testCueLine(eventIndex: 2, startMilliseconds: 1_000, endMilliseconds: 2_000, content: "bottom", displayOrder: 1)
                ]
            )
        ]
    )

    let counts = try readCueGroupLineCounts(at: databaseURL)
    #expect(counts.values.sorted() == [1, 2])
}

@Test
func replacingEntriesRemovesStaleFTSRows() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try IndexingDatabase(path: databaseURL)
    try DatabaseBootstrap.prepare(at: databaseURL)

    let subtitleFile = URL(fileURLWithPath: "/Media/Episode.srt")
    let videoFile = URL(fileURLWithPath: "/Media/Episode.mp4")

    try database.replaceEntries(
        subtitleFile: subtitleFile,
        videoFile: videoFile,
        entries: [
            SubtitleEntry(
                sequenceNumber: 1,
                startTimecode: "00:00:01,000",
                endTimecode: "00:00:03,000",
                startMilliseconds: 1_000,
                endMilliseconds: 3_000,
                text: "Old searchable text."
            )
        ]
    )

    try database.replaceEntries(
        subtitleFile: subtitleFile,
        videoFile: videoFile,
        entries: [
            SubtitleEntry(
                sequenceNumber: 1,
                startTimecode: "00:00:09,000",
                endTimecode: "00:00:11,000",
                startMilliseconds: 9_000,
                endMilliseconds: 11_000,
                text: "Fresh searchable text."
            )
        ]
    )

    #expect(try SearchDatabase(path: database.path).search("Old").isEmpty)

    let freshResults = try SearchDatabase(path: database.path).search("Fresh")
    #expect(freshResults.count == 1)
    #expect(freshResults[0].startMilliseconds == 9_000)
}

@Test
func removingIndexedFolderDeletesIndexedRowsAndSearchPath() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try IndexingDatabase(path: databaseURL)
    try DatabaseBootstrap.prepare(at: databaseURL)

    let removedFolder = URL(fileURLWithPath: "/Media/Removed")
    let keptFolder = URL(fileURLWithPath: "/Media/Kept")
    let removedSearchPathID = try database.addSearchPath(removedFolder)
    _ = try database.addSearchPath(keptFolder)

    try database.replaceEntries(
        subtitleFile: removedFolder.appendingPathComponent("Episode.srt"),
        videoFile: removedFolder.appendingPathComponent("Episode.mkv"),
        entries: [
            SubtitleEntry(
                sequenceNumber: 1,
                startTimecode: "00:00:01,000",
                endTimecode: "00:00:03,000",
                startMilliseconds: 1_000,
                endMilliseconds: 3_000,
                text: "Removed folder searchable text."
            )
        ]
    )
    try database.replaceEntries(
        subtitleFile: keptFolder.appendingPathComponent("Episode.srt"),
        videoFile: keptFolder.appendingPathComponent("Episode.mkv"),
        entries: [
            SubtitleEntry(
                sequenceNumber: 1,
                startTimecode: "00:00:04,000",
                endTimecode: "00:00:06,000",
                startMilliseconds: 4_000,
                endMilliseconds: 6_000,
                text: "Kept folder searchable text."
            )
        ]
    )

    try database.removeIndexedFolder(removedFolder)

    #expect(try SearchDatabase(path: database.path).search("Removed").isEmpty)
    #expect(try SearchDatabase(path: database.path).search("Kept").count == 1)
    #expect(try database.subtitleFiles().map(\.subtitlePath) == [
        keptFolder.appendingPathComponent("Episode.srt").path
    ])

    let newRemovedSearchPathID = try database.addSearchPath(removedFolder)
    #expect(newRemovedSearchPathID != removedSearchPathID)
}

@Test
func removingIndexedFolderPreservesRetainedDerivedSearchRows() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
        try? FileManager.default.removeItem(atPath: databaseURL.path + "-wal")
        try? FileManager.default.removeItem(atPath: databaseURL.path + "-shm")
    }

    let database = try IndexingDatabase(path: databaseURL)
    try DatabaseBootstrap.prepare(at: databaseURL)

    let removedFolder = URL(fileURLWithPath: "/Media/00 Removed")
    let firstKeptFolder = URL(fileURLWithPath: "/Media/10 Kept")
    let secondKeptFolder = URL(fileURLWithPath: "/Media/20 Kept")
    for folder in [removedFolder, firstKeptFolder, secondKeptFolder] {
        _ = try database.addSearchPath(folder)
        try database.replaceEntries(
            subtitleFile: folder.appendingPathComponent("Episode.srt"),
            videoFile: folder.appendingPathComponent("Episode.mkv"),
            entries: [simpleTestEntry(text: "Shared removal ordering text")]
        )
    }

    let removedCueGroupID = try #require(try database.firstCueGroupID(
        forSubtitleFile: removedFolder.appendingPathComponent("Episode.srt")
    ))
    let firstKeptCueGroupID = try #require(try database.firstCueGroupID(
        forSubtitleFile: firstKeptFolder.appendingPathComponent("Episode.srt")
    ))
    let secondKeptCueGroupID = try #require(try database.firstCueGroupID(
        forSubtitleFile: secondKeptFolder.appendingPathComponent("Episode.srt")
    ))
    let firstKeptRowIDBefore = try #require(try sqliteFTSRowID(
        cueGroupID: firstKeptCueGroupID,
        databaseURL: databaseURL
    ))
    let secondKeptRowIDBefore = try #require(try sqliteFTSRowID(
        cueGroupID: secondKeptCueGroupID,
        databaseURL: databaseURL
    ))

    try database.removeIndexedFolder(removedFolder)

    #expect(try sqliteFTSRowID(
        cueGroupID: removedCueGroupID,
        databaseURL: databaseURL
    ) == nil)
    #expect(try sqliteFTSRowID(
        cueGroupID: firstKeptCueGroupID,
        databaseURL: databaseURL
    ) == firstKeptRowIDBefore)
    #expect(try sqliteFTSRowID(
        cueGroupID: secondKeptCueGroupID,
        databaseURL: databaseURL
    ) == secondKeptRowIDBefore)
    #expect(try SearchDatabase(path: database.path).search("Shared").map(\.videoPath) == [
        firstKeptFolder.appendingPathComponent("Episode.mkv").path,
        secondKeptFolder.appendingPathComponent("Episode.mkv").path
    ])
}

@Test
func reconcileIndexedContentClearsAllDataWhenNoFoldersAreActive() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try IndexingDatabase(path: databaseURL)
    try DatabaseBootstrap.prepare(at: databaseURL)

    let folder = URL(fileURLWithPath: "/Media/Removed")
    let searchPathID = try database.addSearchPath(folder)
    try database.replaceEntries(
        subtitleFile: folder.appendingPathComponent("Episode.srt"),
        videoFile: folder.appendingPathComponent("Episode.mkv"),
        entries: [
            SubtitleEntry(
                sequenceNumber: 1,
                startTimecode: "00:00:01,000",
                endTimecode: "00:00:03,000",
                startMilliseconds: 1_000,
                endMilliseconds: 3_000,
                text: "Temporary recovery searchable text."
            )
        ]
    )

    try database.reconcileIndexedContent(activeFolders: [])

    #expect(try SearchDatabase(path: database.path).search("Temporary").isEmpty)
    #expect(try database.subtitleFiles().isEmpty)

    let newSearchPathID = try database.addSearchPath(folder)
    #expect(newSearchPathID != searchPathID)
}

@Test
func reconcileIndexedContentPrunesDataOutsideActiveFolders() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try IndexingDatabase(path: databaseURL)
    try DatabaseBootstrap.prepare(at: databaseURL)

    let activeFolder = URL(fileURLWithPath: "/Media/Active")
    let staleFolder = URL(fileURLWithPath: "/Media/Stale")
    _ = try database.addSearchPath(activeFolder)
    let staleSearchPathID = try database.addSearchPath(staleFolder)
    try database.replaceEntries(
        subtitleFile: activeFolder.appendingPathComponent("Episode.srt"),
        videoFile: activeFolder.appendingPathComponent("Episode.mkv"),
        entries: [
            SubtitleEntry(
                sequenceNumber: 1,
                startTimecode: "00:00:01,000",
                endTimecode: "00:00:03,000",
                startMilliseconds: 1_000,
                endMilliseconds: 3_000,
                text: "Active folder searchable text."
            )
        ]
    )
    try database.replaceEntries(
        subtitleFile: staleFolder.appendingPathComponent("Episode.srt"),
        videoFile: staleFolder.appendingPathComponent("Episode.mkv"),
        entries: [
            SubtitleEntry(
                sequenceNumber: 1,
                startTimecode: "00:00:04,000",
                endTimecode: "00:00:06,000",
                startMilliseconds: 4_000,
                endMilliseconds: 6_000,
                text: "Stale folder searchable text."
            )
        ]
    )

    try database.reconcileIndexedContent(activeFolders: [activeFolder])

    #expect(try SearchDatabase(path: database.path).search("Active").count == 1)
    #expect(try SearchDatabase(path: database.path).search("Stale").isEmpty)
    #expect(try database.subtitleFiles().map(\.subtitlePath) == [
        activeFolder.appendingPathComponent("Episode.srt").path
    ])

    let newStaleSearchPathID = try database.addSearchPath(staleFolder)
    #expect(newStaleSearchPathID != staleSearchPathID)
}
