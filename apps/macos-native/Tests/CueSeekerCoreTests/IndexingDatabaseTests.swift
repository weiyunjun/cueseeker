import Foundation
import Testing
@testable import CueSeekerCore

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
    #expect(
        try sqliteReferencedID(
            table: "library_playback_history",
            idColumn: "video_file_id",
            pathColumn: "video_path",
            path: videoFile.path,
            databaseURL: databaseURL
        ) == videoID
    )
    #expect(
        try sqliteReferencedID(
            table: "library_watch_states",
            idColumn: "video_file_id",
            pathColumn: "video_path",
            path: videoFile.path,
            databaseURL: databaseURL
        ) == videoID
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
