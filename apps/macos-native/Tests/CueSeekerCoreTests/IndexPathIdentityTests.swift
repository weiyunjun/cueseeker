import Foundation
import Testing
@testable import CueSeekerCore

/// Regression coverage for the accepted rule: the current scan result is the only
/// truth. Path and file name decide identity, size and modification time decide
/// change, and a resource that leaves the result is forgotten.
private struct PathIdentityFixture {
    let root: URL
    let databaseURL: URL

    init() throws {
        let container = FileManager.default.temporaryDirectory
            .appendingPathComponent("CueSeekerPathIdentity-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: container,
            withIntermediateDirectories: true
        )
        // The scanner reports the real path, so the fixture must use it too.
        root = PathIdentityFixture.realPath(of: container)
        databaseURL = root.appendingPathComponent("index.sqlite")
        try DatabaseBootstrap.prepare(at: databaseURL)
    }

    private static func realPath(of url: URL) -> URL {
        guard let resolved = realpath(url.path, nil) else {
            return url
        }
        defer { free(resolved) }
        return URL(fileURLWithPath: String(cString: resolved))
    }

    @discardableResult
    func writeEpisode(in folder: String, name: String, text: String) throws -> (
        subtitle: URL, video: URL
    ) {
        let directory = folder.isEmpty ? root : root.appendingPathComponent(folder)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let subtitle = directory.appendingPathComponent("\(name).srt")
        let video = directory.appendingPathComponent("\(name).mkv")
        try """
        1
        00:00:01,000 --> 00:00:03,000
        \(text)

        """.write(to: subtitle, atomically: true, encoding: .utf8)
        try Data([0x01]).write(to: video)
        return (subtitle, video)
    }

    func cleanUp() {
        try? FileManager.default.removeItem(at: root)
    }
}

/// The reported P0: a Library that was removed once could never be added again.
@Test
func removedLibraryCanBeAddedAgainAtTheSamePath() throws {
    let fixture = try PathIdentityFixture()
    defer { fixture.cleanUp() }

    let database = try IndexingDatabase(path: fixture.databaseURL)
    let indexer = SubtitleIndexer()
    try fixture.writeEpisode(in: "Season", name: "Episode", text: "Findable line.")

    let first = try indexer.index(folder: fixture.root, into: database)
    #expect(first.indexedSubtitleFiles == 1)

    try database.removeIndexedFolder(fixture.root)
    #expect(try sqliteRowCount(in: "search_paths", databaseURL: fixture.databaseURL) == 0)

    let second = try indexer.index(folder: fixture.root, into: database)
    #expect(second.indexedSubtitleFiles == 1)
    #expect(try SearchDatabase(path: fixture.databaseURL).search("Findable").count == 1)
}

/// A folder that disappears is forgotten: nothing comes back with it.
@Test
func returningFolderDoesNotRestoreCoverWatchStateOrProgress() throws {
    let fixture = try PathIdentityFixture()
    defer { fixture.cleanUp() }

    let database = try IndexingDatabase(path: fixture.databaseURL)
    let libraryDatabase = try LibraryDatabase(path: fixture.databaseURL)
    let covers = try LibraryCoverDatabase(path: fixture.databaseURL)
    let indexer = SubtitleIndexer()

    let folder = fixture.root.appendingPathComponent("Season")
    let episode = try fixture.writeEpisode(
        in: "Season",
        name: "Episode",
        text: "Findable line."
    )
    _ = try indexer.index(folder: fixture.root, into: database)

    try covers.upsertLibraryUserFolderCover(
        folderPath: folder.path,
        displayCoverPath: "/Covers/season.jpg"
    )
    try libraryDatabase.upsertLibraryPlaybackHistory(
        videoFile: episode.video,
        positionMilliseconds: 42_000,
        duration: 1_200
    )
    try libraryDatabase.setLibraryWatchState(
        videoFile: episode.video,
        duration: 1_200,
        state: .finished
    )
    let originalVideoID = try #require(
        try sqliteRowID(
            table: "video_files",
            pathColumn: "path",
            path: episode.video.mediaPath,
            databaseURL: fixture.databaseURL
        )
    )

    try FileManager.default.removeItem(at: folder)
    _ = try indexer.index(folder: fixture.root, into: database)

    #expect(try covers.libraryUserFolderCover(folderPath: folder.path) == nil)
    #expect(
        try libraryDatabase.libraryPlaybackHistory(forVideoFile: episode.video) == nil
    )

    try fixture.writeEpisode(in: "Season", name: "Episode", text: "Findable line.")
    _ = try indexer.index(folder: fixture.root, into: database)

    let returnedVideoID = try #require(
        try sqliteRowID(
            table: "video_files",
            pathColumn: "path",
            path: episode.video.mediaPath,
            databaseURL: fixture.databaseURL
        )
    )
    #expect(returnedVideoID != originalVideoID)
    #expect(try covers.libraryUserFolderCover(folderPath: folder.path) == nil)
    #expect(
        try libraryDatabase.libraryPlaybackHistory(forVideoFile: episode.video) == nil
    )
    #expect(
        try sqliteRowCount(
            in: "library_watch_states",
            databaseURL: fixture.databaseURL
        ) == 0
    )
}

/// Replacing a matched video with a different format (e.g. .mov -> .mkv) must
/// purge the unmatched video and its watch state/progress so a later .mov at the
/// same path starts fresh with a new VideoID.
@Test
func replacingVideoFormatCleansUpOldVideoAndDoesNotRestoreWatchStateWhenNameReturns() throws {
    let fixture = try PathIdentityFixture()
    defer { fixture.cleanUp() }

    let database = try IndexingDatabase(path: fixture.databaseURL)
    let libraryDatabase = try LibraryDatabase(path: fixture.databaseURL)
    let indexer = SubtitleIndexer()

    let directory = fixture.root.appendingPathComponent("Season")
    try FileManager.default.createDirectory(
        at: directory,
        withIntermediateDirectories: true
    )
    let subtitle = directory.appendingPathComponent("Episode.srt")
    let movVideo = directory.appendingPathComponent("Episode.mov")
    let mkvVideo = directory.appendingPathComponent("Episode.mkv")

    try """
    1
    00:00:01,000 --> 00:00:03,000
    Findable line.

    """.write(to: subtitle, atomically: true, encoding: .utf8)
    try Data([0x01]).write(to: movVideo)

    _ = try indexer.index(folder: fixture.root, into: database)
    try libraryDatabase.upsertLibraryPlaybackHistory(
        videoFile: movVideo,
        positionMilliseconds: 600_000,
        duration: 1_800
    )
    try libraryDatabase.setLibraryWatchState(
        videoFile: movVideo,
        duration: 1_800,
        state: .watching
    )
    let originalMovVideoID = try #require(
        try sqliteRowID(
            table: "video_files",
            pathColumn: "path",
            path: movVideo.mediaPath,
            databaseURL: fixture.databaseURL
        )
    )

    // Step 2: Replace Episode.mov with Episode.mkv while Episode.srt is unchanged.
    try FileManager.default.removeItem(at: movVideo)
    try Data([0x02, 0x03]).write(to: mkvVideo)
    _ = try indexer.index(folder: fixture.root, into: database)

    #expect(
        try sqliteRowID(
            table: "video_files",
            pathColumn: "path",
            path: movVideo.mediaPath,
            databaseURL: fixture.databaseURL
        ) == nil
    )
    #expect(try libraryDatabase.libraryPlaybackHistory(forVideoFile: movVideo) == nil)
    #expect(try libraryDatabase.libraryPlaybackHistory(forVideoFile: mkvVideo) == nil)
    #expect(
        try sqliteRowCount(
            in: "library_watch_states",
            databaseURL: fixture.databaseURL
        ) == 0
    )

    // Record watch state on Episode.mkv, then replace it back with a new Episode.mov
    // while also editing Episode.srt (covering the changed-subtitle rebind path).
    try libraryDatabase.upsertLibraryPlaybackHistory(
        videoFile: mkvVideo,
        positionMilliseconds: 300_000,
        duration: 1_800
    )
    try libraryDatabase.setLibraryWatchState(
        videoFile: mkvVideo,
        duration: 1_800,
        state: .watching
    )
    try FileManager.default.removeItem(at: mkvVideo)
    try Data([0x04, 0x05, 0x06]).write(to: movVideo)
    try """
    1
    00:00:01,000 --> 00:00:03,000
    Updated subtitle line after format swap.

    """.write(to: subtitle, atomically: true, encoding: .utf8)
    _ = try indexer.index(folder: fixture.root, into: database)

    let returnedMovVideoID = try #require(
        try sqliteRowID(
            table: "video_files",
            pathColumn: "path",
            path: movVideo.mediaPath,
            databaseURL: fixture.databaseURL
        )
    )
    #expect(returnedMovVideoID != originalMovVideoID)
    #expect(
        try sqliteRowID(
            table: "video_files",
            pathColumn: "path",
            path: mkvVideo.mediaPath,
            databaseURL: fixture.databaseURL
        ) == nil
    )
    #expect(try libraryDatabase.libraryPlaybackHistory(forVideoFile: movVideo) == nil)
    #expect(try libraryDatabase.libraryPlaybackHistory(forVideoFile: mkvVideo) == nil)
    #expect(
        try sqliteRowCount(
            in: "library_watch_states",
            databaseURL: fixture.databaseURL
        ) == 0
    )
}

/// Only content the current scan confirms is gone may leave; a scan that fails
/// must keep the previous result untouched.
@Test
func failedScanKeepsThePreviousIndex() throws {
    let fixture = try PathIdentityFixture()
    defer { fixture.cleanUp() }

    let database = try IndexingDatabase(path: fixture.databaseURL)
    let indexer = SubtitleIndexer()
    try fixture.writeEpisode(in: "Season", name: "Episode", text: "Findable line.")
    _ = try indexer.index(folder: fixture.root, into: database)

    let missingRoot = fixture.root.appendingPathComponent("Does Not Exist")
    #expect(throws: (any Error).self) {
        _ = try indexer.index(folder: missingRoot, into: database)
    }
    #expect(try SearchDatabase(path: fixture.databaseURL).search("Findable").count == 1)
}

/// Same path and file name always keep the permanent IDs, and size plus
/// modification time are the only change signal.
@Test
func samePathKeepsPermanentIDsAcrossContentChange() throws {
    let fixture = try PathIdentityFixture()
    defer { fixture.cleanUp() }

    let database = try IndexingDatabase(path: fixture.databaseURL)
    let indexer = SubtitleIndexer()
    let episode = try fixture.writeEpisode(
        in: "Season",
        name: "Episode",
        text: "Original line."
    )
    let firstResult = try indexer.index(folder: fixture.root, into: database)
    #expect(firstResult.indexedSubtitleFiles == 1)
    #expect(firstResult.failedFiles.isEmpty)
    #expect(firstResult.skippedMissingVideo == 0)

    let subtitleID = try #require(
        try sqliteRowID(
            table: "subtitle_files",
            pathColumn: "subtitle_path",
            path: episode.subtitle.mediaPath,
            databaseURL: fixture.databaseURL
        )
    )
    let videoID = try #require(
        try sqliteRowID(
            table: "video_files",
            pathColumn: "path",
            path: episode.video.mediaPath,
            databaseURL: fixture.databaseURL
        )
    )

    try """
    1
    00:00:01,000 --> 00:00:03,000
    Rewritten line with a different length.

    """.write(to: episode.subtitle, atomically: true, encoding: .utf8)
    let result = try indexer.index(folder: fixture.root, into: database)

    #expect(result.indexedSubtitleFiles == 1)
    #expect(try SearchDatabase(path: fixture.databaseURL).search("Rewritten").count == 1)
    #expect(try SearchDatabase(path: fixture.databaseURL).search("Original").isEmpty)
    #expect(
        try sqliteRowID(
            table: "subtitle_files",
            pathColumn: "subtitle_path",
            path: episode.subtitle.mediaPath,
            databaseURL: fixture.databaseURL
        ) == subtitleID
    )
    #expect(
        try sqliteRowID(
            table: "video_files",
            pathColumn: "path",
            path: episode.video.mediaPath,
            databaseURL: fixture.databaseURL
        ) == videoID
    )
}

/// A Cue a Excerpt points at must never simply vanish.
@Test
func referencedCueIsTombstonedWhenItsLibraryIsRemoved() throws {
    let fixture = try PathIdentityFixture()
    defer { fixture.cleanUp() }

    let database = try IndexingDatabase(path: fixture.databaseURL)
    let indexer = SubtitleIndexer()
    let episode = try fixture.writeEpisode(
        in: "Season",
        name: "Episode",
        text: "Saved line."
    )
    _ = try indexer.index(folder: fixture.root, into: database)

    let cue = try #require(
        try PlaybackSubtitleDatabase(path: fixture.databaseURL)
            .cueLineRecords(forSubtitleFile: episode.subtitle)
            .first
    )
    let excerptDatabase = try ExcerptDatabase(path: fixture.databaseURL)
    let saved = try excerptDatabase.upsertExcerpt(selection: excerptSelection(cue))

    try database.removeIndexedFolder(fixture.root)

    let unavailable = try #require(try excerptDatabase.excerpt(id: saved.id))
    #expect(!unavailable.isValid)
    #expect(unavailable.unavailableReason == .libraryUnavailable)
    #expect(try sqliteRowCount(in: "cue_tombstones", databaseURL: fixture.databaseURL) == 1)

    _ = try indexer.index(folder: fixture.root, into: database)
    let restored = try #require(try excerptDatabase.excerpt(id: saved.id))
    #expect(restored.isValid)
    #expect(restored.unavailableReason == nil)
    #expect(try excerptDatabase.cueID(forExcerptID: saved.id) == cue.id)
    #expect(try sqliteRowCount(in: "cue_tombstones", databaseURL: fixture.databaseURL) == 0)
}

/// The current schema must not be reachable with any identity or binding state
/// left over.
@Test
func migratedSchemaKeepsNoIdentityOrBindingState() throws {
    let databaseURL = temporaryDatabaseURL()
    defer { removeTemporaryDatabase(at: databaseURL) }

    try DatabaseBootstrap.prepare(at: databaseURL)

    #expect(
        try sqliteSchemaVersion(at: databaseURL)
            == DatabaseBootstrap.currentSchemaVersion
    )
    #expect(try !sqliteTableExists("resource_binding_conflicts", databaseURL: databaseURL))
    for table in ["search_paths", "library_folders", "subtitle_files", "video_files"] {
        let columns = try sqliteColumnNames(in: table, databaseURL: databaseURL)
        #expect(columns.isDisjoint(with: [
            "resource_identity", "content_fingerprint", "binding_state",
            "last_known_path", "last_seen_at", "is_configured",
            "latest_index_token", "published_index_token"
        ]))
    }
    for table in ["library_playback_history", "library_watch_states"] {
        let columns = try sqliteColumnNames(in: table, databaseURL: databaseURL)
        #expect(columns.contains("video_file_id"))
        #expect(!columns.contains("video_path"))
    }
}
