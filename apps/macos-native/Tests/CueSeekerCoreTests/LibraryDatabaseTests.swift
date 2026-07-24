import Foundation
import Testing
@testable import CueSeekerCore

@Test
func recentLibraryWatchingRejectsPreCancelledTasks() async throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    try DatabaseBootstrap.prepare(at: databaseURL)

    let recentTask = Task.detached { () throws -> [RecentLibraryWatchingPresentation] in
        let database = try IndexingDatabase(path: databaseURL)
        withUnsafeCurrentTask { task in
            task?.cancel()
        }
        return try LibraryDatabase(path: database.path).recentLibraryWatching(
            under: [URL(fileURLWithPath: "/Media")],
            limit: Int.max
        )
    }
    do {
        _ = try await recentTask.value
        Issue.record("Expected cancelled Recent query to stop")
    } catch is CancellationError {
        // Expected.
    }
}

@Test
func completeLibraryReadersRejectPreCancelledTasks() async throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    try DatabaseBootstrap.prepare(at: databaseURL)

    let summariesTask = Task.detached {
        () throws -> [CompleteLibraryFolderSummaryPresentation] in
        let database = try IndexingDatabase(path: databaseURL)
        withUnsafeCurrentTask { task in
            task?.cancel()
        }
        return try LibraryDatabase(path: database.path).completeLibraryFolderSummaries(
            under: [URL(fileURLWithPath: "/Media")]
        )
    }
    do {
        _ = try await summariesTask.value
        Issue.record("Expected cancelled Library summary query to stop")
    } catch is CancellationError {
        // Expected.
    }

    let detailTask = Task.detached {
        () throws -> CompleteLibraryFolderDetailPresentation? in
        let database = try IndexingDatabase(path: databaseURL)
        withUnsafeCurrentTask { task in
            task?.cancel()
        }
        return try LibraryDatabase(path: database.path).completeLibraryFolderDetail(
            folderPath: "/Media/Show"
        )
    }
    do {
        _ = try await detailTask.value
        Issue.record("Expected cancelled Library detail query to stop")
    } catch is CancellationError {
        // Expected.
    }
}

@Test
func libraryVideosDeduplicateSortNaturallyAndExposeDuration() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try IndexingDatabase(path: databaseURL)
    try DatabaseBootstrap.prepare(at: databaseURL)

    let show2Episode2Video = URL(fileURLWithPath: "/Media/Show 2/Episode 2.mkv")
    let show2Episode11Video = URL(fileURLWithPath: "/Media/Show 2/Episode 11.mkv")
    let show11Episode1Video = URL(fileURLWithPath: "/Media/Show 11/Episode 1.mkv")

    try database.replaceEntries(
        subtitleFile: URL(fileURLWithPath: "/Media/Show 2/Episode 2.en.srt"),
        videoFile: show2Episode2Video,
        entries: [databaseTestEntry(text: "Shared duplicate English subtitle")]
    )
    try database.replaceEntries(
        subtitleFile: URL(fileURLWithPath: "/Media/Show 2/Episode 2.ja.srt"),
        videoFile: show2Episode2Video,
        entries: [databaseTestEntry(text: "Shared duplicate Japanese subtitle")]
    )
    try database.replaceEntries(
        subtitleFile: URL(fileURLWithPath: "/Media/Show 2/Episode 11.srt"),
        videoFile: show2Episode11Video,
        entries: [databaseTestEntry(text: "Shared later episode")]
    )
    try database.replaceEntries(
        subtitleFile: URL(fileURLWithPath: "/Media/Show 11/Episode 1.srt"),
        videoFile: show11Episode1Video,
        entries: [databaseTestEntry(text: "Shared other folder")]
    )

    try LibraryDatabase(path: databaseURL).updateVideoDuration(videoFile: show2Episode2Video, duration: 125.4)

    let videos = try LibraryDatabase(path: databaseURL).libraryVideos(under: [URL(fileURLWithPath: "/Media")])

    #expect(videos.map(\.videoPath) == [
        show2Episode2Video.path,
        show2Episode11Video.path,
        show11Episode1Video.path
    ])
    #expect(videos[0].duration == 125.4)
    #expect(videos[0].subtitlePath == "/Media/Show 2/Episode 2.en.srt")
}

@Test
func libraryCoverEligibleVideosFollowSubtitleMatchesAndLibraryOrder() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try IndexingDatabase(path: databaseURL)
    try DatabaseBootstrap.prepare(at: databaseURL)

    let episode2Video = URL(fileURLWithPath: "/Media/Show 2/Episode 2.mkv")
    let episode11Video = URL(fileURLWithPath: "/Media/Show 2/Episode 11.mkv")
    let otherFolderVideo = URL(fileURLWithPath: "/Media/Show 11/Episode 1.mkv")

    try database.replaceEntries(
        subtitleFile: URL(fileURLWithPath: "/Media/Show 2/Episode 2.ja.srt"),
        videoFile: episode2Video,
        entries: [databaseTestEntry(text: "Japanese subtitle")]
    )
    try database.replaceEntries(
        subtitleFile: URL(fileURLWithPath: "/Media/Show 2/Episode 2.en.srt"),
        videoFile: episode2Video,
        entries: [databaseTestEntry(text: "English subtitle")]
    )
    try database.replaceEntries(
        subtitleFile: URL(fileURLWithPath: "/Media/Show 2/Episode 11.srt"),
        videoFile: episode11Video,
        entries: [databaseTestEntry(text: "Later episode")]
    )
    try database.replaceEntries(
        subtitleFile: URL(fileURLWithPath: "/Media/Show 11/Episode 1.srt"),
        videoFile: otherFolderVideo,
        entries: [databaseTestEntry(text: "Other folder episode")]
    )
    try LibraryDatabase(path: databaseURL).updateVideoDuration(videoFile: episode2Video, duration: 125.4)

    let coverDatabase = try LibraryCoverDatabase(path: databaseURL)
    let videos = try coverDatabase.libraryCoverEligibleVideos(
        under: [URL(fileURLWithPath: "/Media")]
    )
    let selectedVideos = try coverDatabase.libraryCoverEligibleVideos(
        videoPaths: [episode11Video.path]
    )
    let selectedFolderVideos = try coverDatabase
        .libraryCoverEligibleVideos(
            inFolderPaths: ["/Media/Show 2"]
        )

    #expect(videos.map(\.videoPath) == [
        episode2Video.path,
        episode11Video.path,
        otherFolderVideo.path
    ])
    #expect(videos[0].duration == 125.4)
    #expect(videos[0].subtitlePath == "/Media/Show 2/Episode 2.en.srt")
    #expect(videos[0].folderPath == "/Media/Show 2")
    #expect(selectedVideos.map(\.videoPath) == [episode11Video.path])
    #expect(selectedFolderVideos.map(\.videoPath) == [
        episode2Video.path,
        episode11Video.path
    ])
}

@Test
func libraryCoverRecordsStoreVideoSnapshotAndFolderReference() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try IndexingDatabase(path: databaseURL)
    try DatabaseBootstrap.prepare(at: databaseURL)

    let videoURL = URL(fileURLWithPath: "/Media/Show/Episode 1.mkv")
    try database.replaceEntries(
        subtitleFile: URL(fileURLWithPath: "/Media/Show/Episode 1.srt"),
        videoFile: videoURL,
        entries: [databaseTestEntry(text: "Cover candidate")]
    )
    try LibraryDatabase(path: databaseURL).updateVideoDuration(videoFile: videoURL, duration: 1440.25)

    let videos = try LibraryCoverDatabase(path: databaseURL).libraryCoverEligibleVideos(under: [URL(fileURLWithPath: "/Media")])
    let video = try #require(videos.first)
    try LibraryCoverDatabase(path: databaseURL).upsertLibraryVideoCover(
        videoFileID: video.videoFileID,
        masterCoverPath: "/Library/Application Support/CueSeeker/Covers/Videos/example.jpg",
        displayCoverPath: "/Library/Application Support/CueSeeker/Covers/Display/v1/example.jpg",
        displayProfileVersion: 1,
        sourceTimeMilliseconds: 432_000,
        score: 82.5,
        algorithmVersion: 1,
        generatedFileSize: video.fileSize,
        generatedDuration: video.duration,
        status: .generated,
        errorMessage: nil
    )
    let storedCover = try LibraryCoverDatabase(path: databaseURL).libraryVideoCover(forVideoFileID: video.videoFileID)
    let cover = try #require(storedCover)
    let selectedDisplayCandidates = try LibraryCoverDatabase(
        path: databaseURL
    ).libraryCoverDisplayCandidates(videoPaths: [videoURL.path])
    #expect(cover.masterCoverPath == "/Library/Application Support/CueSeeker/Covers/Videos/example.jpg")
    #expect(cover.displayCoverPath == "/Library/Application Support/CueSeeker/Covers/Display/v1/example.jpg")
    #expect(cover.displayProfileVersion == 1)
    #expect(cover.sourceTimeMilliseconds == 432_000)
    #expect(cover.score == 82.5)
    #expect(cover.algorithmVersion == 1)
    #expect(cover.generatedFileSize == video.fileSize)
    #expect(cover.generatedDuration == 1440.25)
    #expect(cover.status == .generated)
    #expect(cover.errorMessage == nil)
    #expect(cover.generatedAt.contains("."))
    #expect(selectedDisplayCandidates.map(\.videoPath) == [videoURL.path])

    try LibraryCoverDatabase(path: databaseURL).upsertLibraryFolderCover(
        folderPath: video.folderPath,
        masterCoverPath: cover.masterCoverPath,
        sourceVideoFileID: video.videoFileID
    )

    let storedFolderCover = try LibraryCoverDatabase(path: databaseURL).libraryFolderCover(folderPath: video.folderPath)
    let folderCover = try #require(storedFolderCover)
    #expect(folderCover.folderPath == "/Media/Show")
    #expect(folderCover.masterCoverPath == cover.masterCoverPath)
    #expect(folderCover.sourceVideoFileID == video.videoFileID)

    try LibraryCoverDatabase(path: databaseURL).updateLibraryVideoDisplayCover(
        videoFileID: video.videoFileID,
        displayCoverPath: nil,
        displayProfileVersion: nil
    )
    let clearedDisplayCover = try #require(
        try LibraryCoverDatabase(path: databaseURL).libraryVideoCover(forVideoFileID: video.videoFileID)
    )
    #expect(clearedDisplayCover.masterCoverPath == cover.masterCoverPath)
    #expect(clearedDisplayCover.displayCoverPath == nil)
    #expect(clearedDisplayCover.displayProfileVersion == nil)
}

@Test
func userLibraryCoversOverrideIndexCoversWithoutMutatingThem() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try IndexingDatabase(path: databaseURL)
    try DatabaseBootstrap.prepare(at: databaseURL)

    let root = URL(fileURLWithPath: "/Media")
    let folderPath = "/Media/Show"
    let videoFile = URL(fileURLWithPath: "/Media/Show/Episode 1.mkv")
    try database.replaceEntries(
        subtitleFile: URL(fileURLWithPath: "/Media/Show/Episode 1.srt"),
        videoFile: videoFile,
        entries: [databaseTestEntry(text: "Cover precedence")]
    )
    try LibraryDatabase(path: database.path).refreshPresentationAfterIndexedContentChange()
    try LibraryDatabase(path: databaseURL).upsertLibraryPlaybackHistory(
        videoFile: videoFile,
        positionMilliseconds: 10_000,
        duration: 100
    )

    let candidate = try #require(
        try LibraryCoverDatabase(path: databaseURL).libraryCoverEligibleVideos(under: [root]).first
    )
    try LibraryCoverDatabase(path: databaseURL).upsertLibraryVideoCover(
        videoFileID: candidate.videoFileID,
        masterCoverPath: "/Covers/Videos/index-master.jpg",
        displayCoverPath: "/Covers/Display/v1/index-display.jpg",
        displayProfileVersion: LibraryCoverDisplayProfileVersion.current,
        sourceTimeMilliseconds: 1_000,
        score: 80,
        algorithmVersion: 1,
        generatedFileSize: candidate.fileSize,
        generatedDuration: candidate.duration,
        status: .generated,
        errorMessage: nil
    )
    try LibraryCoverDatabase(path: databaseURL).upsertLibraryFolderCover(
        folderPath: folderPath,
        masterCoverPath: "/Covers/Videos/index-master.jpg",
        sourceVideoFileID: candidate.videoFileID
    )

    try LibraryCoverDatabase(path: databaseURL).upsertLibraryUserVideoCover(
        forVideoFile: videoFile,
        displayCoverPath: "/Covers/User/Display/v1/user-video.jpg"
    )
    try LibraryCoverDatabase(path: databaseURL).upsertLibraryUserFolderCover(
        folderPath: folderPath,
        displayCoverPath: "/Covers/User/Display/v1/user-folder.jpg"
    )

    let userVideoCover = try #require(
        try LibraryCoverDatabase(path: databaseURL).libraryUserVideoCover(forVideoFile: videoFile)
    )
    let userFolderCover = try #require(
        try LibraryCoverDatabase(path: databaseURL).libraryUserFolderCover(folderPath: folderPath)
    )
    #expect(userVideoCover.displayCoverPath == "/Covers/User/Display/v1/user-video.jpg")
    #expect(userFolderCover.displayCoverPath == "/Covers/User/Display/v1/user-folder.jpg")

    let recent = try #require(
        try LibraryDatabase(path: database.path).recentLibraryWatching(under: [root]).first
    )
    #expect(recent.coverPath == userVideoCover.displayCoverPath)
    #expect(recent.coverRevision == userVideoCover.revision)

    let complete = try #require(
        try LibraryDatabase(path: database.path).completeLibraryPresentation(under: [root]).first
    )
    #expect(complete.folderCoverPath == userFolderCover.displayCoverPath)
    #expect(complete.folderCoverRevision == userFolderCover.revision)
    #expect(complete.videos.first?.coverPath == userVideoCover.displayCoverPath)
    #expect(complete.videos.first?.coverRevision == userVideoCover.revision)

    let summary = try #require(
        try LibraryDatabase(path: database.path).completeLibraryFolderSummaries(under: [root]).first
    )
    #expect(summary.coverPath == userFolderCover.displayCoverPath)
    #expect(summary.coverRevision == userFolderCover.revision)

    let detail = try #require(
        try LibraryDatabase(path: database.path).completeLibraryFolderDetail(folderPath: folderPath)
    )
    #expect(detail.videos.first?.coverPath == userVideoCover.displayCoverPath)
    #expect(detail.videos.first?.coverRevision == userVideoCover.revision)

    try LibraryCoverDatabase(path: databaseURL).upsertLibraryVideoCover(
        videoFileID: candidate.videoFileID,
        masterCoverPath: "/Covers/Videos/reindexed-master.jpg",
        displayCoverPath: "/Covers/Display/v1/reindexed-display.jpg",
        displayProfileVersion: LibraryCoverDisplayProfileVersion.current,
        sourceTimeMilliseconds: 2_000,
        score: 90,
        algorithmVersion: 2,
        generatedFileSize: candidate.fileSize,
        generatedDuration: candidate.duration,
        status: .generated,
        errorMessage: nil
    )

    let reindexedCover = try #require(
        try LibraryCoverDatabase(path: databaseURL).libraryVideoCover(forVideoFileID: candidate.videoFileID)
    )
    #expect(reindexedCover.displayCoverPath == "/Covers/Display/v1/reindexed-display.jpg")
    #expect(
        try LibraryDatabase(path: database.path).recentLibraryWatching(under: [root]).first?.coverPath
            == userVideoCover.displayCoverPath
    )

    try LibraryCoverDatabase(path: databaseURL).upsertLibraryUserVideoCover(
        forVideoFile: videoFile,
        displayCoverPath: "/Covers/User/Display/v1/replacement-video.jpg"
    )
    try LibraryCoverDatabase(path: databaseURL).upsertLibraryUserFolderCover(
        folderPath: folderPath,
        displayCoverPath: "/Covers/User/Display/v1/replacement-folder.jpg"
    )
    #expect(
        try LibraryCoverDatabase(path: databaseURL).libraryUserVideoCover(forVideoFile: videoFile)?.displayCoverPath
            == "/Covers/User/Display/v1/replacement-video.jpg"
    )
    #expect(
        try LibraryCoverDatabase(path: databaseURL).libraryUserFolderCover(folderPath: folderPath)?.displayCoverPath
            == "/Covers/User/Display/v1/replacement-folder.jpg"
    )
}

@Test
func libraryPresentationSnapshotStoresReadyDisplayRows() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try IndexingDatabase(path: databaseURL)
    try DatabaseBootstrap.prepare(at: databaseURL)

    let episode2Video = URL(fileURLWithPath: "/Media/Show 2/Episode 2.mkv")
    let episode11Video = URL(fileURLWithPath: "/Media/Show 2/Episode 11.mkv")

    try database.replaceEntries(
        subtitleFile: URL(fileURLWithPath: "/Media/Show 2/Episode 2.ja.srt"),
        videoFile: episode2Video,
        entries: [databaseTestEntry(text: "Japanese subtitle")]
    )
    try database.replaceEntries(
        subtitleFile: URL(fileURLWithPath: "/Media/Show 2/Episode 2.en.srt"),
        videoFile: episode2Video,
        entries: [databaseTestEntry(text: "English subtitle")]
    )
    try database.replaceEntries(
        subtitleFile: URL(fileURLWithPath: "/Media/Show 2/Episode 11.srt"),
        videoFile: episode11Video,
        entries: [databaseTestEntry(text: "Later episode")]
    )
    try LibraryDatabase(path: databaseURL).updateVideoDuration(videoFile: episode2Video, duration: 125.4)

    #expect(
        try LibraryDatabase(path: database.path)
            .libraryPresentation(under: [URL(fileURLWithPath: "/Media")])
            .isEmpty
    )

    try LibraryDatabase(path: database.path).refreshPresentationAfterIndexedContentChange()
    let groups = try LibraryDatabase(path: database.path)
        .libraryPresentation(under: [URL(fileURLWithPath: "/Media")])

    #expect(groups.count == 1)
    let group = try #require(groups.first)
    #expect(group.folderTitle == "Show 2")
    #expect(group.videos.map(\.videoPath) == [
        episode2Video.path,
        episode11Video.path
    ])
    #expect(group.videos.map(\.displayTitle) == [
        "Show 2 - 01",
        "Show 2 - 02"
    ])
    #expect(group.videos[0].fileExtension == "mkv")
    #expect(group.videos[0].duration == 125.4)
    #expect(group.videos[0].subtitlePath == "/Media/Show 2/Episode 2.en.srt")
}

@Test
func libraryPlaybackHistoryPersistsResumePositionByVideo() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    try DatabaseBootstrap.prepare(at: databaseURL)

    let videoFile = URL(fileURLWithPath: "/Media/Show/Episode 1.mkv")
    try LibraryDatabase(path: databaseURL).upsertLibraryPlaybackHistory(
        videoFile: videoFile,
        positionMilliseconds: 91_250,
        duration: 1_800.5
    )

    let initialHistory = try #require(try LibraryDatabase(path: databaseURL).libraryPlaybackHistory(forVideoFile: videoFile))
    #expect(initialHistory.videoPath == videoFile.path)
    #expect(initialHistory.positionMilliseconds == 91_250)
    #expect(initialHistory.duration == 1_800.5)
    #expect(initialHistory.startedAt != nil)
    #expect(initialHistory.completedAt == nil)

    try LibraryDatabase(path: databaseURL).upsertLibraryPlaybackHistory(
        videoFile: videoFile,
        positionMilliseconds: 0,
        duration: nil
    )

    let updatedHistory = try #require(try LibraryDatabase(path: databaseURL).libraryPlaybackHistory(forVideoFile: videoFile))
    #expect(updatedHistory.positionMilliseconds == 0)
    #expect(updatedHistory.duration == nil)
    #expect(updatedHistory.startedAt == initialHistory.startedAt)
    #expect(updatedHistory.completedAt == nil)
    #expect(LibraryWatchState(
        positionMilliseconds: updatedHistory.positionMilliseconds,
        duration: updatedHistory.duration,
        startedAt: updatedHistory.startedAt,
        completedAt: updatedHistory.completedAt
    ) == .watching)
}

@Test
func libraryPlaybackHistoryKeepsFinishedStateAfterSeekingBack() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    try DatabaseBootstrap.prepare(at: databaseURL)

    let videoFile = URL(fileURLWithPath: "/Media/Show/Episode 1.mkv")
    try LibraryDatabase(path: databaseURL).upsertLibraryPlaybackHistory(
        videoFile: videoFile,
        positionMilliseconds: 960_000,
        duration: 1_000.0,
        markCompleted: true
    )

    let finishedHistory = try #require(try LibraryDatabase(path: databaseURL).libraryPlaybackHistory(forVideoFile: videoFile))
    #expect(finishedHistory.completedAt != nil)
    #expect(LibraryWatchState(
        positionMilliseconds: finishedHistory.positionMilliseconds,
        duration: finishedHistory.duration,
        startedAt: finishedHistory.startedAt,
        completedAt: finishedHistory.completedAt
    ) == .finished)

    try LibraryDatabase(path: databaseURL).upsertLibraryPlaybackHistory(
        videoFile: videoFile,
        positionMilliseconds: 0,
        duration: 1_000.0
    )

    let rewoundHistory = try #require(try LibraryDatabase(path: databaseURL).libraryPlaybackHistory(forVideoFile: videoFile))
    #expect(rewoundHistory.positionMilliseconds == 0)
    #expect(rewoundHistory.startedAt == finishedHistory.startedAt)
    #expect(rewoundHistory.completedAt == finishedHistory.completedAt)
    #expect(LibraryWatchState(
        positionMilliseconds: rewoundHistory.positionMilliseconds,
        duration: rewoundHistory.duration,
        startedAt: rewoundHistory.startedAt,
        completedAt: rewoundHistory.completedAt
    ) == .finished)
}

@Test
func setLibraryWatchStatePreservesPlaybackProgressAndRecentHistory() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try IndexingDatabase(path: databaseURL)
    try DatabaseBootstrap.prepare(at: databaseURL)

    let root = URL(fileURLWithPath: "/Media")
    let videoFile = URL(fileURLWithPath: "/Media/Show/Episode 1.mkv")
    try database.replaceEntries(
        subtitleFile: videoFile.deletingPathExtension().appendingPathExtension("srt"),
        videoFile: videoFile,
        entries: [databaseTestEntry(text: "episode one")]
    )
    try LibraryDatabase(path: database.path).refreshPresentationAfterIndexedContentChange()

    let playedAt = Date(timeIntervalSince1970: 1_800_000_000)
    try LibraryDatabase(path: databaseURL).upsertLibraryPlaybackHistory(
        videoFile: videoFile,
        positionMilliseconds: 42_500,
        duration: 100.0,
        updatedAt: playedAt
    )

    let initialHistory = try #require(try LibraryDatabase(path: databaseURL).libraryPlaybackHistory(forVideoFile: videoFile))
    #expect(initialHistory.positionMilliseconds == 42_500)
    #expect(initialHistory.updatedAt == "2027-01-15T08:00:00.000Z")

    try LibraryDatabase(path: databaseURL).setLibraryWatchState(
        videoFile: videoFile,
        duration: 100.0,
        state: .finished
    )

    let finishedHistory = try #require(try LibraryDatabase(path: databaseURL).libraryPlaybackHistory(forVideoFile: videoFile))
    #expect(finishedHistory.positionMilliseconds == 42_500)
    #expect(finishedHistory.updatedAt == initialHistory.updatedAt)
    #expect(finishedHistory.completedAt != nil)
    #expect(LibraryWatchState(
        positionMilliseconds: finishedHistory.positionMilliseconds,
        duration: finishedHistory.duration,
        startedAt: finishedHistory.startedAt,
        completedAt: finishedHistory.completedAt
    ) == .finished)
    let finishedRecent = try #require(
        try LibraryDatabase(path: database.path).recentLibraryWatching(under: [root], limit: 5).first
    )
    #expect(finishedRecent.videoPath == videoFile.path)
    #expect(finishedRecent.positionMilliseconds == 42_500)
    #expect(finishedRecent.watchState == .finished)

    try LibraryDatabase(path: databaseURL).setLibraryWatchState(
        videoFile: videoFile,
        duration: 100.0,
        state: .unwatched
    )

    let unwatchedHistory = try #require(try LibraryDatabase(path: databaseURL).libraryPlaybackHistory(forVideoFile: videoFile))
    #expect(unwatchedHistory.positionMilliseconds == 42_500)
    #expect(unwatchedHistory.updatedAt == initialHistory.updatedAt)
    #expect(unwatchedHistory.startedAt == nil)
    #expect(unwatchedHistory.completedAt == nil)
    #expect(LibraryWatchState(
        positionMilliseconds: unwatchedHistory.positionMilliseconds,
        duration: unwatchedHistory.duration,
        startedAt: unwatchedHistory.startedAt,
        completedAt: unwatchedHistory.completedAt
    ) == .unwatched)
    let unwatchedRecent = try #require(
        try LibraryDatabase(path: database.path).recentLibraryWatching(under: [root], limit: 5).first
    )
    #expect(unwatchedRecent.videoPath == videoFile.path)
    #expect(unwatchedRecent.positionMilliseconds == 42_500)
    #expect(unwatchedRecent.watchState == .unwatched)
}

@Test
func libraryPlaybackHistoryDoesNotFinishFromResumePositionAlone() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    try DatabaseBootstrap.prepare(at: databaseURL)

    let videoFile = URL(fileURLWithPath: "/Media/Show/Episode 1.mkv")
    try LibraryDatabase(path: databaseURL).upsertLibraryPlaybackHistory(
        videoFile: videoFile,
        positionMilliseconds: 960_000,
        duration: 1_000.0
    )

    let history = try #require(try LibraryDatabase(path: databaseURL).libraryPlaybackHistory(forVideoFile: videoFile))
    #expect(history.startedAt != nil)
    #expect(history.completedAt == nil)
    #expect(LibraryWatchState(
        positionMilliseconds: history.positionMilliseconds,
        duration: history.duration,
        startedAt: history.startedAt,
        completedAt: history.completedAt
    ) == .watching)
}

@Test
func recentLibraryWatchingKeepsLatestVideoPerFolderWithinLimit() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try IndexingDatabase(path: databaseURL)
    try DatabaseBootstrap.prepare(at: databaseURL)

    let root = URL(fileURLWithPath: "/Media")
    let showA1 = root.appendingPathComponent("Show A/Episode 1.mkv")
    let showA2 = root.appendingPathComponent("Show A/Episode 2.mkv")
    let showB1 = root.appendingPathComponent("Show B/Episode 1.mkv")
    let showC1 = root.appendingPathComponent("Show C/Episode 1.mkv")
    let showD1 = root.appendingPathComponent("Show D/Episode 1.mkv")
    let showE1 = root.appendingPathComponent("Show E/Episode 1.mkv")
    let showF1 = root.appendingPathComponent("Show F/Episode 1.mkv")

    for videoFile in [showA1, showA2, showB1, showC1, showD1, showE1, showF1] {
        let subtitleFile = videoFile
            .deletingPathExtension()
            .appendingPathExtension("srt")
        try database.replaceEntries(
            subtitleFile: subtitleFile,
            videoFile: videoFile,
            entries: [databaseTestEntry(text: videoFile.lastPathComponent)]
        )
    }
    try LibraryDatabase(path: database.path).refreshPresentationAfterIndexedContentChange()

    let baseDate = Date(timeIntervalSince1970: 1_800_000_000)
    let history: [(URL, Int, TimeInterval)] = [
        (showA1, 10_000, 0),
        (showB1, 20_000, 1),
        (showC1, 30_000, 2),
        (showD1, 40_000, 3),
        (showE1, 50_000, 4),
        (showF1, 60_000, 5),
        (showA2, 70_000, 6)
    ]
    for (videoFile, positionMilliseconds, dateOffset) in history {
        try LibraryDatabase(path: databaseURL).upsertLibraryPlaybackHistory(
            videoFile: videoFile,
            positionMilliseconds: positionMilliseconds,
            duration: 1_200.0,
            updatedAt: baseDate.addingTimeInterval(dateOffset)
        )
    }

    let recent = try LibraryDatabase(path: database.path).recentLibraryWatching(under: [root], limit: 5)

    #expect(recent.map(\.videoPath) == [
        showA2.path,
        showF1.path,
        showE1.path,
        showD1.path,
        showC1.path
    ])
    #expect(recent.map(\.folderTitle) == ["Show A", "Show F", "Show E", "Show D", "Show C"])
    #expect(recent.first?.episodeNumber == 2)
    #expect(recent.first?.positionMilliseconds == 70_000)
    #expect(recent.first?.playbackDuration == 1_200.0)

    let allRecent = try LibraryDatabase(path: database.path)
        .recentLibraryWatching(under: [root], limit: Int.max)
    #expect(allRecent.map(\.videoPath) == [
        showA2.path,
        showF1.path,
        showE1.path,
        showD1.path,
        showC1.path,
        showB1.path
    ])
}

@Test
func recentLibraryWatchingUsesFractionalUpdatedAtWithinSameSecond() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try IndexingDatabase(path: databaseURL)
    try DatabaseBootstrap.prepare(at: databaseURL)

    let root = URL(fileURLWithPath: "/Media")
    let episode3 = root.appendingPathComponent("Show/Episode 3.mkv")
    let episode4 = root.appendingPathComponent("Show/Episode 4.mkv")

    for videoFile in [episode3, episode4] {
        try database.replaceEntries(
            subtitleFile: videoFile.deletingPathExtension().appendingPathExtension("srt"),
            videoFile: videoFile,
            entries: [databaseTestEntry(text: videoFile.lastPathComponent)]
        )
    }
    try LibraryDatabase(path: database.path).refreshPresentationAfterIndexedContentChange()

    let baseDate = Date(timeIntervalSince1970: 1_800_000_000)
    try LibraryDatabase(path: databaseURL).upsertLibraryPlaybackHistory(
        videoFile: episode3,
        positionMilliseconds: 30_000,
        duration: 1_200.0,
        updatedAt: baseDate.addingTimeInterval(0.100)
    )
    try LibraryDatabase(path: databaseURL).upsertLibraryPlaybackHistory(
        videoFile: episode4,
        positionMilliseconds: 40_000,
        duration: 1_200.0,
        updatedAt: baseDate.addingTimeInterval(0.200)
    )

    let recent = try LibraryDatabase(path: database.path).recentLibraryWatching(under: [root], limit: 5)

    #expect(recent.map(\.videoPath) == [episode4.path])
    #expect(recent.first?.positionMilliseconds == 40_000)
}

@Test
func completeLibraryPresentationBuildsFolderCardsAndContinueTargets() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try IndexingDatabase(path: databaseURL)
    try DatabaseBootstrap.prepare(at: databaseURL)

    let root = URL(fileURLWithPath: "/Media")
    let show = root.appendingPathComponent("Show")
    let episode1 = show.appendingPathComponent("Episode 1.mkv")
    let episode2 = show.appendingPathComponent("Episode 2.mkv")
    let episode3 = show.appendingPathComponent("Episode 3.mkv")
    let episode4 = show.appendingPathComponent("Episode 4.mkv")

    for videoFile in [episode1, episode2, episode3, episode4] {
        try database.replaceEntries(
            subtitleFile: videoFile.deletingPathExtension().appendingPathExtension("srt"),
            videoFile: videoFile,
            entries: [databaseTestEntry(text: videoFile.lastPathComponent)]
        )
        try LibraryDatabase(path: databaseURL).updateVideoDuration(videoFile: videoFile, duration: 1_000.0)
    }

    try LibraryDatabase(path: database.path).refreshPresentationAfterIndexedContentChange()

    let baseDate = Date(timeIntervalSince1970: 1_800_000_000)
    try LibraryDatabase(path: databaseURL).upsertLibraryPlaybackHistory(
        videoFile: episode2,
        positionMilliseconds: 960_000,
        duration: 1_000.0,
        updatedAt: baseDate.addingTimeInterval(1),
        markCompleted: true
    )
    try LibraryDatabase(path: databaseURL).upsertLibraryPlaybackHistory(
        videoFile: episode3,
        positionMilliseconds: 300_000,
        duration: 1_000.0,
        updatedAt: baseDate.addingTimeInterval(3)
    )
    try LibraryDatabase(path: databaseURL).upsertLibraryPlaybackHistory(
        videoFile: episode4,
        positionMilliseconds: 400_000,
        duration: 1_000.0,
        updatedAt: baseDate.addingTimeInterval(2)
    )

    let groups = try LibraryDatabase(path: database.path).completeLibraryPresentation(under: [root])
    let group = try #require(groups.first)

    #expect(groups.count == 1)
    #expect(group.folderTitle == "Show")
    #expect(group.lastWatchedEpisodeNumber == 3)
    #expect(group.videos.map(\.episodeNumber) == [1, 2, 3, 4])
    #expect(group.videos.map(\.watchState) == [.unwatched, .finished, .watching, .watching])
    #expect(group.continueWatchingVideo?.videoPath == episode3.path)
}

@Test
func completeLibraryContinueTargetUsesLatestHistoryThenFallsBackToFirstEpisode() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try IndexingDatabase(path: databaseURL)
    try DatabaseBootstrap.prepare(at: databaseURL)

    let root = URL(fileURLWithPath: "/Media")
    let showA1 = root.appendingPathComponent("Show A/Episode 1.mkv")
    let showA2 = root.appendingPathComponent("Show A/Episode 2.mkv")
    let showB1 = root.appendingPathComponent("Show B/Episode 1.mkv")
    let showB2 = root.appendingPathComponent("Show B/Episode 2.mkv")

    for videoFile in [showA1, showA2, showB1, showB2] {
        try database.replaceEntries(
            subtitleFile: videoFile.deletingPathExtension().appendingPathExtension("srt"),
            videoFile: videoFile,
            entries: [databaseTestEntry(text: videoFile.lastPathComponent)]
        )
        try LibraryDatabase(path: databaseURL).updateVideoDuration(videoFile: videoFile, duration: 1_000.0)
    }
    try LibraryDatabase(path: database.path).refreshPresentationAfterIndexedContentChange()

    let baseDate = Date(timeIntervalSince1970: 1_800_000_000)
    try LibraryDatabase(path: databaseURL).upsertLibraryPlaybackHistory(
        videoFile: showB1,
        positionMilliseconds: 960_000,
        duration: 1_000.0,
        updatedAt: baseDate.addingTimeInterval(1)
    )
    try LibraryDatabase(path: databaseURL).upsertLibraryPlaybackHistory(
        videoFile: showB2,
        positionMilliseconds: 960_000,
        duration: 1_000.0,
        updatedAt: baseDate.addingTimeInterval(2)
    )

    let groups = try LibraryDatabase(path: database.path).completeLibraryPresentation(under: [root])
    let showA = try #require(groups.first { $0.folderTitle == "Show A" })
    let showB = try #require(groups.first { $0.folderTitle == "Show B" })

    #expect(showA.continueWatchingVideo?.videoPath == showA1.path)
    #expect(showB.continueWatchingVideo?.videoPath == showB2.path)
}

@Test
func completeLibraryFolderSummariesAndDetailSplitFolderAndEpisodeData() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try IndexingDatabase(path: databaseURL)
    try DatabaseBootstrap.prepare(at: databaseURL)

    let root = URL(fileURLWithPath: "/Media")
    let showA1 = root.appendingPathComponent("Show A/Episode 1.mkv")
    let showA2 = root.appendingPathComponent("Show A/Episode 2.mkv")
    let showB1 = root.appendingPathComponent("Show B/Episode 1.mkv")

    for videoFile in [showA1, showA2, showB1] {
        try database.replaceEntries(
            subtitleFile: videoFile.deletingPathExtension().appendingPathExtension("srt"),
            videoFile: videoFile,
            entries: [databaseTestEntry(text: videoFile.lastPathComponent)]
        )
        try LibraryDatabase(path: databaseURL).updateVideoDuration(videoFile: videoFile, duration: 1_000.0)
    }
    try LibraryDatabase(path: databaseURL).updateVideoMetadata(
        videoFile: showA1,
        duration: 1_000.0,
        videoWidth: 1920,
        videoHeight: 1080,
        frameRate: 23.976,
        videoCodec: "hevc"
    )
    try LibraryDatabase(path: database.path).refreshPresentationAfterIndexedContentChange()

    let eligibleVideos = try LibraryCoverDatabase(path: databaseURL).libraryCoverEligibleVideos(under: [root])
    let showA1CoverCandidate = try #require(eligibleVideos.first { $0.videoPath == showA1.path })
    try LibraryCoverDatabase(path: databaseURL).upsertLibraryVideoCover(
        videoFileID: showA1CoverCandidate.videoFileID,
        masterCoverPath: "/Covers/show-a-episode-1.jpg",
        displayCoverPath: "/Covers/Display/v1/show-a-episode-1.jpg",
        displayProfileVersion: LibraryCoverDisplayProfileVersion.current,
        sourceTimeMilliseconds: 120_000,
        score: 90,
        algorithmVersion: 1,
        generatedFileSize: showA1CoverCandidate.fileSize,
        generatedDuration: showA1CoverCandidate.duration,
        status: .generated,
        errorMessage: nil
    )
    let showACoverRevision = try #require(
        try LibraryCoverDatabase(path: databaseURL).libraryVideoCover(forVideoFileID: showA1CoverCandidate.videoFileID)
    ).generatedAt

    try LibraryDatabase(path: databaseURL).upsertLibraryPlaybackHistory(
        videoFile: showA2,
        positionMilliseconds: 250_000,
        duration: 1_000.0
    )

    let summaries = try LibraryDatabase(path: database.path).completeLibraryFolderSummaries(under: [root])
    #expect(summaries.map(\.folderTitle) == ["Show A", "Show B"])

    let showASummary = try #require(summaries.first { $0.folderTitle == "Show A" })
    #expect(showASummary.episodeCount == 2)
    #expect(showASummary.coverPath == "/Covers/Display/v1/show-a-episode-1.jpg")
    #expect(showASummary.coverRevision == showACoverRevision)

    let detail = try #require(
        try LibraryDatabase(path: database.path)
            .completeLibraryFolderDetail(folderPath: showASummary.folderPath)
    )
    #expect(detail.folderTitle == "Show A")
    #expect(detail.videos.map(\.videoPath) == [showA1.path, showA2.path])
    #expect(detail.videos.map(\.episodeNumber) == [1, 2])
    #expect(detail.videos.map(\.watchState) == [.unwatched, .watching])
    #expect(detail.videos.first?.videoWidth == 1920)
    #expect(detail.videos.first?.videoHeight == 1080)
    #expect(detail.videos.first?.frameRate == 23.976)
    #expect(detail.videos.first?.videoCodec == "hevc")
    #expect(detail.videos.first?.coverPath == "/Covers/Display/v1/show-a-episode-1.jpg")
    #expect(detail.videos.first?.coverRevision == showACoverRevision)
}

@Test
func libraryCoverPresentationsNeverFallBackToMasterRendition() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try IndexingDatabase(path: databaseURL)
    try DatabaseBootstrap.prepare(at: databaseURL)

    let root = URL(fileURLWithPath: "/Media")
    let videoFile = root.appendingPathComponent("Show/Episode 1.mkv")
    try database.replaceEntries(
        subtitleFile: videoFile.deletingPathExtension().appendingPathExtension("srt"),
        videoFile: videoFile,
        entries: [databaseTestEntry(text: "display only")]
    )
    try LibraryDatabase(path: database.path).refreshPresentationAfterIndexedContentChange()
    try LibraryDatabase(path: databaseURL).upsertLibraryPlaybackHistory(
        videoFile: videoFile,
        positionMilliseconds: 1_000,
        duration: 100
    )

    let candidate = try #require(
        try LibraryCoverDatabase(path: databaseURL).libraryCoverEligibleVideos(under: [root]).first
    )
    let masterPath = "/Covers/Videos/master-must-not-render.jpg"
    let displayPath = "/Covers/Display/v1/display.jpg"
    try LibraryCoverDatabase(path: databaseURL).upsertLibraryVideoCover(
        videoFileID: candidate.videoFileID,
        masterCoverPath: masterPath,
        sourceTimeMilliseconds: 1_000,
        score: 75,
        algorithmVersion: 1,
        generatedFileSize: candidate.fileSize,
        generatedDuration: candidate.duration,
        status: .generated,
        errorMessage: nil
    )
    try LibraryCoverDatabase(path: databaseURL).upsertLibraryFolderCover(
        folderPath: candidate.folderPath,
        masterCoverPath: masterPath,
        sourceVideoFileID: candidate.videoFileID
    )

    let masterOnlyRecent = try #require(
        try LibraryDatabase(path: database.path).recentLibraryWatching(under: [root]).first
    )
    #expect(masterOnlyRecent.coverPath == nil)
    #expect(masterOnlyRecent.coverRevision == nil)
    let masterOnlyFull = try #require(
        try LibraryDatabase(path: database.path).completeLibraryPresentation(under: [root]).first
    )
    #expect(masterOnlyFull.folderCoverPath == nil)
    #expect(masterOnlyFull.folderCoverRevision == nil)
    #expect(masterOnlyFull.videos.first?.coverPath == nil)
    #expect(masterOnlyFull.videos.first?.coverRevision == nil)
    let masterOnlySummary = try #require(
        try LibraryDatabase(path: database.path).completeLibraryFolderSummaries(under: [root]).first
    )
    #expect(masterOnlySummary.coverPath == nil)
    #expect(masterOnlySummary.coverRevision == nil)
    let masterOnlyDetail = try #require(
        try LibraryDatabase(path: database.path)
            .completeLibraryFolderDetail(folderPath: candidate.folderPath)
    )
    #expect(masterOnlyDetail.videos.first?.coverPath == nil)
    #expect(masterOnlyDetail.videos.first?.coverRevision == nil)

    try LibraryCoverDatabase(path: databaseURL).updateLibraryVideoDisplayCover(
        videoFileID: candidate.videoFileID,
        displayCoverPath: displayPath,
        displayProfileVersion: LibraryCoverDisplayProfileVersion.current
    )
    let displayRevision = try #require(
        try LibraryCoverDatabase(path: databaseURL).libraryVideoCover(forVideoFileID: candidate.videoFileID)
    ).generatedAt
    #expect(displayRevision.contains("."))

    let displayRecent = try #require(
        try LibraryDatabase(path: database.path).recentLibraryWatching(under: [root]).first
    )
    #expect(displayRecent.coverPath == displayPath)
    #expect(displayRecent.coverRevision == displayRevision)
    let displayFull = try #require(
        try LibraryDatabase(path: database.path).completeLibraryPresentation(under: [root]).first
    )
    #expect(displayFull.folderCoverPath == displayPath)
    #expect(displayFull.folderCoverRevision == displayRevision)
    #expect(displayFull.videos.first?.coverPath == displayPath)
    #expect(displayFull.videos.first?.coverRevision == displayRevision)
    let displaySummary = try #require(
        try LibraryDatabase(path: database.path).completeLibraryFolderSummaries(under: [root]).first
    )
    #expect(displaySummary.coverPath == displayPath)
    #expect(displaySummary.coverRevision == displayRevision)
    let displayDetail = try #require(
        try LibraryDatabase(path: database.path)
            .completeLibraryFolderDetail(folderPath: candidate.folderPath)
    )
    #expect(displayDetail.videos.first?.coverPath == displayPath)
    #expect(displayDetail.videos.first?.coverRevision == displayRevision)

    try LibraryCoverDatabase(path: databaseURL).updateLibraryVideoDisplayCover(
        videoFileID: candidate.videoFileID,
        displayCoverPath: "/Covers/Display/v2/stale-profile.jpg",
        displayProfileVersion: LibraryCoverDisplayProfileVersion.current + 1
    )
    let staleRecent = try #require(
        try LibraryDatabase(path: database.path).recentLibraryWatching(under: [root]).first
    )
    #expect(staleRecent.coverPath == nil)
    #expect(staleRecent.coverRevision == nil)
    let staleSummary = try #require(
        try LibraryDatabase(path: database.path).completeLibraryFolderSummaries(under: [root]).first
    )
    #expect(staleSummary.coverPath == nil)
    #expect(staleSummary.coverRevision == nil)
}

@Test
func removingIndexedFolderPreservesLibraryPlaybackHistory() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try IndexingDatabase(path: databaseURL)
    try DatabaseBootstrap.prepare(at: databaseURL)

    let folder = URL(fileURLWithPath: "/Media/Show")
    _ = try database.addSearchPath(folder)
    let videoFile = folder.appendingPathComponent("Episode 1.mkv")
    try database.replaceEntries(
        subtitleFile: folder.appendingPathComponent("Episode 1.srt"),
        videoFile: videoFile,
        entries: [
            SubtitleEntry(
                sequenceNumber: 1,
                startTimecode: "00:00:01,000",
                endTimecode: "00:00:03,000",
                startMilliseconds: 1_000,
                endMilliseconds: 3_000,
                text: "Library history should survive index removal."
            )
        ]
    )
    try LibraryDatabase(path: databaseURL).upsertLibraryPlaybackHistory(
        videoFile: videoFile,
        positionMilliseconds: 42_000,
        duration: 1_200.0
    )

    try database.removeIndexedFolder(folder)

    #expect(try LibraryDatabase(path: databaseURL).libraryVideos(under: [folder]).isEmpty)
    let history = try #require(try LibraryDatabase(path: databaseURL).libraryPlaybackHistory(forVideoFile: videoFile))
    #expect(history.videoPath == videoFile.path)
    #expect(history.positionMilliseconds == 42_000)
    #expect(history.duration == 1_200.0)
}
