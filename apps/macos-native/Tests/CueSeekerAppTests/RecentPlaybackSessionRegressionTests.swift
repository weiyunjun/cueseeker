import AppKit
import Foundation
import Testing
import CueSeekerCore
@testable import CueSeekerApp

@MainActor
@Test
func recentPlaybackNavigationPreparesSameFolderEpisodes() async throws {
    try await withTemporaryRecentPlaybackApp { app, database in
        let root = URL(fileURLWithPath: "/Media")
        let episode1 = root.appendingPathComponent("Show/Episode 1.mkv")
        let episode2 = root.appendingPathComponent("Show/Episode 2.mkv")
        let episode3 = root.appendingPathComponent("Show/Episode 3.mkv")
        try indexRecentPlaybackVideos([episode1, episode2, episode3], in: database)
        try app.libraryDatabase!.refreshPresentationAfterIndexedContentChange()
        try app.libraryDatabase!.upsertLibraryPlaybackHistory(
            videoFile: episode2,
            positionMilliseconds: 120_000,
            duration: 1_800
        )

        let recentItem = try #require(
            try app.libraryDatabase!.recentLibraryWatching(under: [root], limit: 5).first
        )

        await app.prepareRecentLibraryNavigation(for: recentItem)
        app.library.selectedLibraryVideo = recentItem.libraryVideo
        app.activePlaybackSource = .library(videoPath: recentItem.videoPath)

        #expect(app.canOpenPreviousLibraryVideo)
        #expect(app.canOpenNextLibraryVideo)
    }
}

@MainActor
@Test
func recordingLibraryPlaybackStartRefreshesLoadedRecentWatching() async throws {
    try await withTemporaryRecentPlaybackApp { app, database in
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "CueSeekerRecentPlaybackMedia-\(UUID().uuidString)",
                isDirectory: true
            )
        defer {
            try? FileManager.default.removeItem(at: root)
        }
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: true
        )
        let episode = root.appendingPathComponent("Show/Episode 1.mkv")
        try indexRecentPlaybackVideos([episode], in: database)
        try app.libraryDatabase!.refreshPresentationAfterIndexedContentChange()
        app.indexing.selectedFolders = [root]
        app.refreshRecentWatching()
        app.refreshTestRecentWatching()
        await app.recentWatchingTask?.value
        await app.testRecentWatchingTask?.value
        #expect(app.library.recentWatchingItems.isEmpty)
        #expect(app.library.testRecentWatchingItems.map(\.videoPath) == [episode.path])
        #expect(app.library.testRecentWatchingItems.first?.updatedAt.isEmpty == true)

        let video = try #require(
            try app.libraryDatabase!.libraryVideos(under: [root]).first
        )
        app.recordRecentLibraryWatching(for: video)
        await app.recentWatchingTask?.value
        await app.testRecentWatchingTask?.value

        #expect(app.library.recentWatchingItems.first?.videoPath == episode.path)
        #expect(app.library.testRecentWatchingItems.first?.videoPath == episode.path)
        #expect(app.library.testRecentWatchingItems.first?.updatedAt.isEmpty == false)
    }
}

@MainActor
@Test
func closingRecentLibraryPlaybackRefreshesRecentWatchingProgress() async throws {
    try await withTemporaryRecentPlaybackApp { app, database in
        let root = URL(fileURLWithPath: "/Media")
        let episode = root.appendingPathComponent("Show/Episode 1.mkv")
        try indexRecentPlaybackVideos([episode], in: database)
        try app.libraryDatabase!.refreshPresentationAfterIndexedContentChange()
        try app.libraryDatabase!.upsertLibraryPlaybackHistory(
            videoFile: episode,
            positionMilliseconds: 10_000,
            duration: 100
        )
        app.indexing.selectedFolders = [root]
        app.refreshRecentWatching()
        await app.recentWatchingTask?.value
        #expect(app.library.recentWatchingItems.first?.positionMilliseconds == 10_000)

        app.ensurePlayerInitialized()
        let playbackViewModel = try #require(app.playback.playbackViewModel)
        let player = try #require(app.player)
        app.activePlaybackSource = .library(videoPath: episode.path)
        playbackViewModel.player(player, didChangeProperty: "time-pos", value: .double(42.5))
        playbackViewModel.player(player, didChangeProperty: "duration", value: .double(100))
        await Task.yield()

        app.saveCurrentLibraryPlaybackHistoryForPlaybackClose()
        await app.recentWatchingTask?.value

        #expect(app.library.recentWatchingItems.first?.positionMilliseconds == 42_500)
    }
}

@MainActor
@Test
func closingNonLibraryPlaybackFlushesPendingLibraryProgress() async throws {
    try await withTemporaryRecentPlaybackApp { app, database in
        let root = URL(fileURLWithPath: "/Media")
        let episode = root.appendingPathComponent("Show/Episode 1.mkv")
        try indexRecentPlaybackVideos([episode], in: database)
        try app.libraryDatabase!.refreshPresentationAfterIndexedContentChange()
        try app.libraryDatabase!.upsertLibraryPlaybackHistory(
            videoFile: episode,
            positionMilliseconds: 10_000,
            duration: 100
        )
        app.indexing.selectedFolders = [root]
        app.refreshTestRecentWatching()
        await app.testRecentWatchingTask?.value
        #expect(app.library.testRecentWatchingItems.first?.positionMilliseconds == 10_000)

        app.ensurePlayerInitialized()
        let playbackViewModel = try #require(app.playback.playbackViewModel)
        let player = try #require(app.player)
        app.activePlaybackSource = .library(videoPath: episode.path)
        playbackViewModel.player(player, didChangeProperty: "time-pos", value: .double(42.5))
        playbackViewModel.player(player, didChangeProperty: "duration", value: .double(100))
        await Task.yield()

        app.saveCurrentLibraryPlaybackHistory()
        app.activePlaybackSource = .search
        app.saveCurrentLibraryPlaybackHistoryForPlaybackClose()
        await app.testRecentWatchingTask?.value

        #expect(app.pendingLibraryPlaybackHistoryPresentationVideoPaths.isEmpty)
        #expect(app.library.testRecentWatchingItems.first?.positionMilliseconds == 42_500)
    }
}

@MainActor
@Test
func presentingPlaybackCommandPanelPublishesPendingLibraryProgress() async throws {
    try await withTemporaryRecentPlaybackApp { app, database in
        let root = URL(fileURLWithPath: "/Media")
        let episode = root.appendingPathComponent("Show/Episode 1.mkv")
        try indexRecentPlaybackVideos([episode], in: database)
        try app.libraryDatabase!.refreshPresentationAfterIndexedContentChange()
        try app.libraryDatabase!.upsertLibraryPlaybackHistory(
            videoFile: episode,
            positionMilliseconds: 10_000,
            duration: 100
        )
        app.indexing.selectedFolders = [root]
        app.refreshRecentWatching()
        app.refreshTestRecentWatching()
        await app.recentWatchingTask?.value
        await app.testRecentWatchingTask?.value
        #expect(app.library.recentWatchingItems.first?.positionMilliseconds == 10_000)
        #expect(app.library.testRecentWatchingItems.first?.positionMilliseconds == 10_000)

        let video = try #require(
            try app.libraryDatabase!.libraryVideos(under: [root]).first
        )
        app.library.selectedLibraryVideo = video
        app.playback.isPlaybackSurfaceExpanded = true
        app.ensurePlayerInitialized()
        let playbackViewModel = try #require(app.playback.playbackViewModel)
        let player = try #require(app.player)
        app.activePlaybackSource = .library(videoPath: episode.path)
        playbackViewModel.player(
            player,
            didChangeProperty: "duration",
            value: .double(100)
        )
        playbackViewModel.player(
            player,
            didChangeProperty: "time-pos",
            value: .double(42.5)
        )
        await Task.yield()
        app.saveCurrentLibraryPlaybackHistory()

        #expect(app.presentPlaybackCommandPanel())
        let history = try #require(
            try app.libraryDatabase!.libraryPlaybackHistory(forVideoFile: episode)
        )
        #expect(app.pendingLibraryPlaybackHistoryPresentationVideoPaths.isEmpty)
        #expect(history.positionMilliseconds == 42_500)
        #expect(app.libraryResumePositionMilliseconds(for: video) == 42_500)

        await app.recentWatchingTask?.value
        await app.testRecentWatchingTask?.value
        #expect(
            app.library.recentWatchingItems.first?.positionMilliseconds
                == 42_500
        )
        #expect(
            app.library.testRecentWatchingItems.first?.positionMilliseconds
                == 42_500
        )
    }
}

@MainActor
@Test
func synchronousPlaybackHistorySaveDrainsPendingWriteAfterSourceChange() async throws {
    try await withTemporaryRecentPlaybackApp { app, database in
        let root = URL(fileURLWithPath: "/Media")
        let episode = root.appendingPathComponent("Show/Episode 1.mkv")
        try indexRecentPlaybackVideos([episode], in: database)
        try app.libraryDatabase!.refreshPresentationAfterIndexedContentChange()
        try app.libraryDatabase!.upsertLibraryPlaybackHistory(
            videoFile: episode,
            positionMilliseconds: 10_000,
            duration: 100
        )

        app.ensurePlayerInitialized()
        let playbackViewModel = try #require(app.playback.playbackViewModel)
        let player = try #require(app.player)
        app.activePlaybackSource = .library(videoPath: episode.path)
        playbackViewModel.player(
            player,
            didChangeProperty: "duration",
            value: .double(100)
        )
        playbackViewModel.player(
            player,
            didChangeProperty: "time-pos",
            value: .double(42.5)
        )
        await Task.yield()

        let releaseWriter = DispatchSemaphore(value: 0)
        app.libraryPlaybackHistoryWriter.queue.async {
            releaseWriter.wait()
        }
        app.saveCurrentLibraryPlaybackHistory()
        app.activePlaybackSource = .search
        let revisionBeforeSave = app.library.libraryPlaybackHistoryRevision
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.05) {
            releaseWriter.signal()
        }

        app.saveCurrentLibraryPlaybackHistorySynchronously()

        let history = try #require(
            try app.libraryDatabase!.libraryPlaybackHistory(forVideoFile: episode)
        )
        #expect(history.positionMilliseconds == 42_500)
        #expect(
            app.pendingLibraryPlaybackHistoryPresentationVideoPaths
                == Set([episode.path])
        )
        #expect(app.library.libraryPlaybackHistoryRevision == revisionBeforeSave)
    }
}

@MainActor
@Test
func markingWatchStateWhileInRecentPanelModeRefreshesImmediately() async throws {
    try await withTemporaryRecentPlaybackApp { app, database in
        let root = URL(fileURLWithPath: "/Media")
        let episode = root.appendingPathComponent("Show/Episode 1.mkv")
        try indexRecentPlaybackVideos([episode], in: database)
        try app.libraryDatabase!.refreshPresentationAfterIndexedContentChange()
        try app.libraryDatabase!.upsertLibraryPlaybackHistory(
            videoFile: episode,
            positionMilliseconds: 10_000,
            duration: 100
        )
        app.indexing.selectedFolders = [root]
        app.refreshTestRecentWatching()
        await app.testRecentWatchingTask?.value
        #expect(app.library.testRecentWatchingItems.first?.watchState == .watching)

        app.activateWorkbenchPanelMode(.recentWatching)
        let video = try #require(
            try app.libraryDatabase!.libraryVideos(under: [root]).first
        )

        // 1. Mark as finished (watched)
        app.testRecentWatchingTask = nil
        app.markLibraryVideo(video, as: .finished)

        for _ in 0..<30 {
            if let task = app.testRecentWatchingTask {
                await task.value
                break
            }
            try await Task.sleep(nanoseconds: 10_000_000)
        }

        #expect(!app.recentNeedsReloadAfterIndexedMutation)
        #expect(app.library.testRecentWatchingItems.first?.watchState == .finished)

        // 2. Mark as unwatched
        app.testRecentWatchingTask = nil
        app.markLibraryVideo(video, as: .unwatched)

        for _ in 0..<30 {
            if let task = app.testRecentWatchingTask {
                await task.value
                break
            }
            try await Task.sleep(nanoseconds: 10_000_000)
        }

        #expect(!app.recentNeedsReloadAfterIndexedMutation)
        #expect(app.library.testRecentWatchingItems.first?.watchState == .unwatched)
    }
}

@MainActor
@Test
func startingPlaybackWhileInRecentPanelModeRefreshesWithoutDeferral() async throws {
    try await withTemporaryRecentPlaybackApp { app, database in
        let root = URL(fileURLWithPath: "/Media")
        let episode1 = root.appendingPathComponent("Show/Episode 1.mkv")
        let episode2 = root.appendingPathComponent("Show/Episode 2.mkv")
        try indexRecentPlaybackVideos([episode1, episode2], in: database)
        try app.libraryDatabase!.refreshPresentationAfterIndexedContentChange()
        try app.libraryDatabase!.upsertLibraryPlaybackHistory(
            videoFile: episode1,
            positionMilliseconds: 10_000,
            duration: 100
        )
        app.indexing.selectedFolders = [root]
        app.refreshTestRecentWatching()
        await app.testRecentWatchingTask?.value
        #expect(app.library.testRecentWatchingItems.count == 1)
        #expect(app.library.testRecentWatchingItems.first?.videoPath == episode1.path)

        app.activateWorkbenchPanelMode(.recentWatching)
        let video2 = try #require(
            try app.libraryDatabase!.libraryVideos(under: [root]).first { $0.videoPath == episode2.path }
        )
        app.recordRecentLibraryWatching(for: video2)
        await app.testRecentWatchingTask?.value

        #expect(!app.recentNeedsReloadAfterIndexedMutation)
        #expect(app.library.testRecentWatchingItems.first?.videoPath == episode2.path)
    }
}

@MainActor
@Test
func commandPanelRecentVideosRefreshesWhenStatusAlreadyCompleted() async throws {
    try await withTemporaryRecentPlaybackApp { app, database in
        let root = URL(fileURLWithPath: "/Media")
        let episode1 = root.appendingPathComponent("Show/Episode 1.mkv")
        let episode2 = root.appendingPathComponent("Show/Episode 2.mkv")
        try indexRecentPlaybackVideos([episode1, episode2], in: database)
        try app.libraryDatabase!.refreshPresentationAfterIndexedContentChange()
        try app.libraryDatabase!.upsertLibraryPlaybackHistory(
            videoFile: episode1,
            positionMilliseconds: 10_000,
            duration: 100
        )
        app.indexing.selectedFolders = [root]
        app.refreshTestRecentWatching()
        await app.testRecentWatchingTask?.value
        #expect(app.library.testRecentWatchingStatus == .completed)
        #expect(app.library.testRecentWatchingItems.count == 1)

        let video1 = try #require(
            try app.libraryDatabase!.libraryVideos(under: [root]).first { $0.videoPath == episode1.path }
        )
        app.library.selectedLibraryVideo = video1
        app.playback.isPlaybackSurfaceExpanded = true

        // Simulate switching to episode 2 in database
        try app.libraryDatabase!.upsertLibraryPlaybackHistory(
            videoFile: episode2,
            positionMilliseconds: 20_000,
            duration: 100
        )

        // Open command panel and navigate to recentVideos page
        #expect(app.presentPlaybackCommandPanel())
        #expect(app.presentPlaybackCommandPanelPage(.recentVideos))
        await app.testRecentWatchingTask?.value

        #expect(app.playbackCommandPanelRecentVideos.first?.videoPath == episode2.path)
    }
}

private func indexRecentPlaybackVideos(
    _ videoFiles: [URL],
    in database: IndexingDatabase
) throws {
    for (index, videoFile) in videoFiles.enumerated() {
        let subtitleFile = videoFile
            .deletingPathExtension()
            .appendingPathExtension("srt")
        try database.replaceEntries(
            subtitleFile: subtitleFile,
            videoFile: videoFile,
            entries: [
                SubtitleEntry(
                    sequenceNumber: index + 1,
                    startTimecode: "00:00:01,000",
                    endTimecode: "00:00:02,000",
                    startMilliseconds: 1_000,
                    endMilliseconds: 2_000,
                    text: "recent playback \(index + 1)"
                )
            ]
        )
    }
}

@MainActor
private func withTemporaryRecentPlaybackApp(
    _ body: @MainActor (AppCoordinator, IndexingDatabase) async throws -> Void
) async throws {
    let suiteName = "CueSeekerRecentPlaybackTests-\(UUID().uuidString)"
    let userDefaults = try #require(UserDefaults.temporary(suiteName: suiteName))
    let databaseURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerRecentPlaybackTests-\(UUID().uuidString)")
        .appendingPathExtension("sqlite")
    defer {
        userDefaults.removePersistentDomainAndPlist(forName: suiteName)
        removeTemporaryDatabase(at: databaseURL)
        try? FileManager.default.removeItem(atPath: databaseURL.path + "-wal")
        try? FileManager.default.removeItem(atPath: databaseURL.path + "-shm")
    }

    _ = NSApplication.shared
    let app = AppCoordinator(userDefaults: userDefaults, databaseURL: databaseURL)
    await app.startupDatabaseTask?.value
    let database = try #require(app.indexingDatabase)
    try await body(app, database)
}
