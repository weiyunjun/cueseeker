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

/// A returning folder and video at the exact same path restore manual covers,
/// watch state, playback progress, and default audio track from tombstone without
/// restoring Recent watching or altering Folder Resume order.
@Test
func returningFolderRestoresCoverWatchStateAndProgressWithoutRestoringRecent() throws {
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
    let untouchedEpisode = try fixture.writeEpisode(
        in: "Season",
        name: "Episode2",
        text: "Second untouched line."
    )
    let initialIndex = try indexer.index(folder: fixture.root, into: database)
    try libraryDatabase.refreshPresentationAfterIndexedContentChange(
        affectedFolderPaths: Set(initialIndex.affectedFolderPaths),
        clearingRetryForLibraryID: initialIndex.libraryID
    )

    try covers.upsertLibraryUserFolderCover(
        folderPath: folder.path,
        displayCoverPath: "/Covers/season.jpg"
    )
    try covers.upsertLibraryUserVideoCover(
        forVideoFile: episode.video,
        displayCoverPath: "/Covers/episode1-manual.jpg"
    )
    try libraryDatabase.setDefaultAudioTrackIndex(2, forVideoFile: episode.video)
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
    #expect(try libraryDatabase.recentLibraryWatching(under: [fixture.root]).count == 1)

    let originalVideoID = try #require(
        try sqliteRowID(
            table: "video_files",
            pathColumn: "path",
            path: episode.video.mediaPath,
            databaseURL: fixture.databaseURL
        )
    )

    try FileManager.default.removeItem(at: folder)
    let removedIndex = try indexer.index(folder: fixture.root, into: database)
    try libraryDatabase.refreshPresentationAfterIndexedContentChange(
        affectedFolderPaths: Set(removedIndex.affectedFolderPaths),
        clearingRetryForLibraryID: removedIndex.libraryID
    )

    // Only Episode (which had user state) enters video_tombstones; untouched Episode2 does not.
    #expect(try sqliteRowCount(in: "video_tombstones", databaseURL: fixture.databaseURL) == 1)
    #expect(try covers.libraryUserFolderCover(folderPath: folder.path)?.displayCoverPath == "/Covers/season.jpg")
    #expect(try libraryDatabase.libraryPlaybackHistory(forVideoFile: episode.video) == nil)
    #expect(try libraryDatabase.libraryPlaybackHistory(forVideoFile: untouchedEpisode.video) == nil)
    #expect(try libraryDatabase.recentLibraryWatching(under: [fixture.root]).isEmpty)

    try fixture.writeEpisode(in: "Season", name: "Episode", text: "Findable line.")
    try fixture.writeEpisode(in: "Season", name: "Episode2", text: "Second untouched line.")
    let restoredIndex = try indexer.index(folder: fixture.root, into: database)
    try libraryDatabase.refreshPresentationAfterIndexedContentChange(
        affectedFolderPaths: Set(restoredIndex.affectedFolderPaths),
        clearingRetryForLibraryID: restoredIndex.libraryID
    )

    let returnedVideoID = try #require(
        try sqliteRowID(
            table: "video_files",
            pathColumn: "path",
            path: episode.video.mediaPath,
            databaseURL: fixture.databaseURL
        )
    )
    #expect(returnedVideoID != originalVideoID)
    #expect(try sqliteRowCount(in: "video_tombstones", databaseURL: fixture.databaseURL) == 0)
    #expect(try covers.libraryUserFolderCover(folderPath: folder.path)?.displayCoverPath == "/Covers/season.jpg")
    #expect(try covers.libraryUserVideoCover(forVideoFile: episode.video)?.displayCoverPath == "/Covers/episode1-manual.jpg")
    #expect(try libraryDatabase.videoAudioTracks(forVideoFile: episode.video)?.defaultIndex == 2)

    let restoredHistory = try #require(
        try libraryDatabase.libraryPlaybackHistory(forVideoFile: episode.video)
    )
    #expect(restoredHistory.positionMilliseconds == 42_000)
    #expect(restoredHistory.updatedAt.isEmpty)
    #expect(try libraryDatabase.recentLibraryWatching(under: [fixture.root]).isEmpty)

    let folderPresentation = try #require(
        try libraryDatabase.completeLibraryPresentation(under: [fixture.root]).first
    )
    #expect(folderPresentation.lastWatchedEpisodeNumber == nil)
    #expect(folderPresentation.lastWatchedVideoPath == nil)
    #expect(folderPresentation.videos.first?.positionMilliseconds == 42_000)
    #expect(folderPresentation.videos.first?.completedAt != nil)
    #expect(folderPresentation.videos.first?.historyUpdatedAt == nil)
}

/// Replacing a matched video with a different format (e.g. .mov -> .mkv) must
/// not transfer watch state or progress across extensions, while restoring the
/// exact same path (.mov) recovers its tombstoned watch state and progress
/// without restoring Recent watching.
@Test
func replacingVideoFormatIsolatesByExtensionAndRestoresExactPathTombstone() throws {
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
    #expect(try sqliteRowCount(in: "video_tombstones", databaseURL: fixture.databaseURL) == 1)

    // Record watch state on Episode.mkv, then replace it back with Episode.mov.
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
    let restoredMovHistory = try #require(
        try libraryDatabase.libraryPlaybackHistory(forVideoFile: movVideo)
    )
    #expect(restoredMovHistory.positionMilliseconds == 600_000)
    #expect(restoredMovHistory.updatedAt.isEmpty)
    #expect(try libraryDatabase.libraryPlaybackHistory(forVideoFile: mkvVideo) == nil)
    #expect(try libraryDatabase.recentLibraryWatching(under: [fixture.root]).isEmpty)
}

@Test
func shorterNewVideoDurationResetsProgressAndWatchStateForBothDirectReplacementAndTombstoneRecovery() throws {
    let fixture = try PathIdentityFixture()
    defer { fixture.cleanUp() }

    let database = try IndexingDatabase(path: fixture.databaseURL)
    let libraryDatabase = try LibraryDatabase(path: fixture.databaseURL)
    let covers = try LibraryCoverDatabase(path: fixture.databaseURL)
    let indexer = SubtitleIndexer()

    let ep1 = try fixture.writeEpisode(in: "Season", name: "Episode1", text: "Episode 1 line.")
    let ep2 = try fixture.writeEpisode(in: "Season", name: "Episode2", text: "Episode 2 line.")
    _ = try indexer.index(folder: fixture.root, into: database)

    // Both episodes watched to 20:00 (1,200,000 ms) out of 30:00 (1,800s).
    for ep in [ep1, ep2] {
        try libraryDatabase.upsertLibraryPlaybackHistory(
            videoFile: ep.video,
            positionMilliseconds: 1_200_000,
            duration: 1_800
        )
        try libraryDatabase.setLibraryWatchState(
            videoFile: ep.video,
            duration: 1_800,
            state: .watching
        )
    }
    try covers.upsertLibraryUserVideoCover(
        forVideoFile: ep2.video,
        displayCoverPath: "/Covers/ep2-manual.jpg"
    )

    // Case A: Direct same-path replacement of Episode1 with a 10:00 (600s) video.
    try Data([0x09, 0x08, 0x07]).write(to: ep1.video)
    _ = try indexer.index(folder: fixture.root, into: database)
    try libraryDatabase.updateVideoDuration(videoFile: ep1.video, duration: 600)

    #expect(try libraryDatabase.libraryPlaybackHistory(forVideoFile: ep1.video) == nil)

    // Case B: Tombstone recovery of Episode2 with a 10:00 (600s) video.
    try FileManager.default.removeItem(at: ep2.video)
    _ = try indexer.index(folder: fixture.root, into: database)
    #expect(try sqliteRowCount(in: "video_tombstones", databaseURL: fixture.databaseURL) == 1)

    try Data([0x05, 0x04]).write(to: ep2.video)
    _ = try indexer.index(folder: fixture.root, into: database)
    try libraryDatabase.updateVideoMetadata(
        videoFile: ep2.video,
        duration: 600,
        videoWidth: 1920,
        videoHeight: 1080,
        frameRate: 24,
        videoCodec: "h264",
        audioTracks: []
    )

    #expect(try libraryDatabase.libraryPlaybackHistory(forVideoFile: ep2.video) == nil)
    #expect(try sqliteRowCount(in: "library_watch_states", databaseURL: fixture.databaseURL) == 0)
    #expect(try covers.libraryUserVideoCover(forVideoFile: ep2.video)?.displayCoverPath == "/Covers/ep2-manual.jpg")
}

@Test
func resurrectingVideoAndCueDoesNotAlterExistingFolderOrExcerptListResumeOrder() throws {
    let fixture = try PathIdentityFixture()
    defer { fixture.cleanUp() }

    let database = try IndexingDatabase(path: fixture.databaseURL)
    let libraryDatabase = try LibraryDatabase(path: fixture.databaseURL)
    let excerptDatabase = try ExcerptDatabase(path: fixture.databaseURL)
    let indexer = SubtitleIndexer()

    let ep1 = try fixture.writeEpisode(in: "Season", name: "Episode1", text: "First episode cue.")
    let ep2 = try fixture.writeEpisode(in: "Season", name: "Episode2", text: "Second episode cue.")
    let firstIndex = try indexer.index(folder: fixture.root, into: database)
    try libraryDatabase.refreshPresentationAfterIndexedContentChange(
        affectedFolderPaths: Set(firstIndex.affectedFolderPaths),
        clearingRetryForLibraryID: firstIndex.libraryID
    )

    // Watch Episode 1 at t1, then Episode 2 at t2 so Episode 2 is the Folder's Resume target.
    try libraryDatabase.upsertLibraryPlaybackHistory(
        videoFile: ep1.video,
        positionMilliseconds: 30_000,
        duration: 600,
        updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
    )
    try libraryDatabase.upsertLibraryPlaybackHistory(
        videoFile: ep2.video,
        positionMilliseconds: 90_000,
        duration: 600,
        updatedAt: Date(timeIntervalSince1970: 1_700_000_100)
    )

    let cue1 = try #require(
        try PlaybackSubtitleDatabase(path: fixture.databaseURL)
            .cueLineRecords(forSubtitleFile: ep1.subtitle)
            .first
    )
    let cue2 = try #require(
        try PlaybackSubtitleDatabase(path: fixture.databaseURL)
            .cueLineRecords(forSubtitleFile: ep2.subtitle)
            .first
    )
    let saved1 = try excerptDatabase.upsertExcerpt(selection: excerptSelection(cue1))
    let saved2 = try excerptDatabase.upsertExcerpt(selection: excerptSelection(cue2))
    try excerptDatabase.recordRecentExcerptPlayback(
        excerptID: saved2.id,
        playedAt: Date(timeIntervalSince1970: 1_700_000_200)
    )
    #expect(try excerptDatabase.recentExcerptListSummaries().first?.resumeExcerpt?.id == saved2.id)

    // Remove Episode2.mkv and re-index: Episode2 video and Cue 2 enter tombstones.
    try FileManager.default.removeItem(at: ep2.video)
    let secondIndex = try indexer.index(folder: fixture.root, into: database)
    try libraryDatabase.refreshPresentationAfterIndexedContentChange(
        affectedFolderPaths: Set(secondIndex.affectedFolderPaths),
        clearingRetryForLibraryID: secondIndex.libraryID
    )

    // Folder Resume and Recent watching fall back to Episode 1; Excerpt List Resume falls back to saved1.
    #expect(try libraryDatabase.recentLibraryWatching(under: [fixture.root]).map(\.videoPath) == [ep1.video.mediaPath])
    #expect(try libraryDatabase.completeLibraryPresentation(under: [fixture.root]).first?.lastWatchedEpisodeNumber == 1)
    let summaryDuringTombstone = try #require(try excerptDatabase.recentExcerptListSummaries().first)
    #expect(summaryDuringTombstone.resumeExcerpt?.id == saved1.id)
    #expect(summaryDuringTombstone.resumePosition == 1)
    #expect(summaryDuringTombstone.list.recentCueID == cue1.id)

    // Restore Episode2.mkv and re-index: Episode2 and Cue 2 resurrect, but neither hijacks Resume!
    try Data([0x01]).write(to: ep2.video)
    let thirdIndex = try indexer.index(folder: fixture.root, into: database)
    try libraryDatabase.refreshPresentationAfterIndexedContentChange(
        affectedFolderPaths: Set(thirdIndex.affectedFolderPaths),
        clearingRetryForLibraryID: thirdIndex.libraryID
    )

    #expect(try libraryDatabase.libraryPlaybackHistory(forVideoFile: ep2.video)?.positionMilliseconds == 90_000)
    #expect(try libraryDatabase.recentLibraryWatching(under: [fixture.root]).map(\.videoPath) == [ep1.video.mediaPath])
    #expect(try libraryDatabase.completeLibraryPresentation(under: [fixture.root]).first?.lastWatchedEpisodeNumber == 1)

    let restoredExcerpt2 = try #require(try excerptDatabase.excerpt(id: saved2.id))
    #expect(restoredExcerpt2.isValid)
    let summaryAfterResurrection = try #require(try excerptDatabase.recentExcerptListSummaries().first)
    #expect(summaryAfterResurrection.resumeExcerpt?.id == saved1.id)
    #expect(summaryAfterResurrection.resumePosition == 1)
    #expect(summaryAfterResurrection.list.recentCueID == cue1.id)
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
