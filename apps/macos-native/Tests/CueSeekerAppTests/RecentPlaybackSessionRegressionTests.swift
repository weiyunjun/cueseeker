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
        try database.rebuildLibraryPresentationSnapshot()
        try app.libraryDatabase!.upsertLibraryPlaybackHistory(
            videoFile: episode2,
            positionMilliseconds: 120_000,
            duration: 1_800
        )

        let recentItem = try #require(try database.recentLibraryWatching(under: [root], limit: 5).first)

        await app.prepareRecentLibraryNavigation(for: recentItem)
        app.library.selectedLibraryVideo = recentItem.libraryVideo
        app.activePlaybackSource = .library(videoPath: recentItem.videoPath)

        #expect(app.canOpenPreviousLibraryVideo)
        #expect(app.canOpenNextLibraryVideo)
    }
}

@MainActor
@Test
func closingRecentLibraryPlaybackRefreshesRecentWatchingProgress() async throws {
    try await withTemporaryRecentPlaybackApp { app, database in
        let root = URL(fileURLWithPath: "/Media")
        let episode = root.appendingPathComponent("Show/Episode 1.mkv")
        try indexRecentPlaybackVideos([episode], in: database)
        try database.rebuildLibraryPresentationSnapshot()
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
        try database.rebuildLibraryPresentationSnapshot()
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

private func indexRecentPlaybackVideos(
    _ videoFiles: [URL],
    in database: SubtitleDatabase
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
    _ body: @MainActor (AppCoordinator, SubtitleDatabase) async throws -> Void
) async throws {
    let suiteName = "CueSeekerRecentPlaybackTests-\(UUID().uuidString)"
    let userDefaults = try #require(UserDefaults(suiteName: suiteName))
    let databaseURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerRecentPlaybackTests-\(UUID().uuidString)")
        .appendingPathExtension("sqlite")
    defer {
        userDefaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: databaseURL)
        try? FileManager.default.removeItem(atPath: databaseURL.path + "-wal")
        try? FileManager.default.removeItem(atPath: databaseURL.path + "-shm")
    }

    _ = NSApplication.shared
    let app = AppCoordinator(userDefaults: userDefaults, databaseURL: databaseURL)
    await app.startupDatabaseTask?.value
    let database = try #require(app.subtitleDatabase)
    try await body(app, database)
}
