import AppKit
import Foundation
import Testing
import CueSeekerCore
@testable import CueSeekerApp

@MainActor
@Test
func libraryRouteHydrationReusesCompletedSnapshotsUntilExplicitRefresh() async throws {
    try await withTemporaryLibraryRouteApp { app, database in
        app.hydrateLibraryAsync()
        app.hydrateRecentWatchingAsync()
        app.hydrateTestRecentWatchingAsync()
        app.hydrateCompleteLibraryAsync()

        #expect(app.library.libraryPresentationRevision == 0)
        #expect(app.library.recentWatchingRevision == 0)
        #expect(app.library.testRecentWatchingRevision == 0)
        #expect(app.library.completeLibraryRevision == 0)

        let fixture = try prepareLibraryRouteFixture(in: database)
        app.indexing.selectedFolders = [fixture.root]

        app.hydrateLibraryAsync()
        app.hydrateRecentWatchingAsync()
        let displayBackfillTask = try #require(app.libraryDisplayRenditionTask)
        app.hydrateTestRecentWatchingAsync()
        app.hydrateCompleteLibraryAsync()

        await app.libraryTask?.value
        await app.recentWatchingTask?.value
        await app.testRecentWatchingTask?.value
        await app.completeLibraryTask?.value
        await displayBackfillTask.value

        #expect(app.library.libraryStatus == .completed)
        #expect(app.library.recentWatchingStatus == .completed)
        #expect(app.library.testRecentWatchingStatus == .completed)
        #expect(app.library.completeLibraryStatus == .completed)
        #expect(app.library.libraryVideos.count == 1)
        #expect(app.library.recentWatchingItems.count == 1)
        #expect(app.library.testRecentWatchingItems.count == 1)
        #expect(app.library.completeLibraryFolderSummaries.count == 1)

        let folderPath = try #require(
            app.library.completeLibraryFolderSummaries.first?.folderPath
        )
        let sharedDetail = try #require(
            await app.completeLibraryFolderDetailFromStore(
                folderPath: folderPath
            )
        )
        #expect(
            app.library.completeLibraryFolderDetailsByPath[folderPath]
                == sharedDetail
        )
        let cachedDetail = await app.completeLibraryFolderDetailFromStore(
            folderPath: folderPath
        )
        #expect(cachedDetail == sharedDetail)

        let libraryRevision = app.library.libraryPresentationRevision
        let recentRevision = app.library.recentWatchingRevision
        let testRecentRevision = app.library.testRecentWatchingRevision
        let completeRevision = app.library.completeLibraryRevision

        app.libraryTask = nil
        app.recentWatchingTask = nil
        app.testRecentWatchingTask = nil
        app.completeLibraryTask = nil

        app.hydrateLibraryAsync()
        app.hydrateRecentWatchingAsync()
        app.hydrateTestRecentWatchingAsync()
        app.hydrateCompleteLibraryAsync()
        await Task.yield()

        #expect(app.libraryTask == nil)
        #expect(app.recentWatchingTask == nil)
        #expect(app.testRecentWatchingTask == nil)
        #expect(app.completeLibraryTask == nil)
        #expect(app.library.libraryPresentationRevision == libraryRevision)
        #expect(app.library.recentWatchingRevision == recentRevision)
        #expect(app.library.testRecentWatchingRevision == testRecentRevision)
        #expect(app.library.completeLibraryRevision == completeRevision)

        app.refreshLibrary()
        app.refreshRecentWatching()
        app.refreshTestRecentWatching()
        app.refreshCompleteLibrary()

        await app.libraryTask?.value
        await app.recentWatchingTask?.value
        await app.testRecentWatchingTask?.value
        await app.completeLibraryTask?.value

        #expect(app.library.libraryPresentationRevision == libraryRevision + 1)
        #expect(app.library.recentWatchingRevision == recentRevision + 1)
        #expect(app.library.testRecentWatchingRevision == testRecentRevision + 1)
        #expect(app.library.completeLibraryRevision == completeRevision + 1)
        #expect(app.library.completeLibraryFolderDetailsByPath.isEmpty)
    }
}

@MainActor
@Test
func playbackHistoryChangesReloadRecentAndDetailWithoutRebuildingLibrarySummary() async throws {
    try await withTemporaryLibraryRouteApp { app, database in
        let fixture = try prepareLibraryRouteFixture(in: database)
        app.indexing.selectedFolders = [fixture.root]
        app.applyCompleteLibrary(
            try database.completeLibraryFolderSummaries(under: [fixture.root])
        )
        let folderPath = try #require(
            app.library.completeLibraryFolderSummaries.first?.folderPath
        )
        _ = try #require(
            await app.completeLibraryFolderDetailFromStore(folderPath: folderPath)
        )
        app.library.testRecentWatchingStatus = .completed

        let initialHistoryRevision = app.library.libraryPlaybackHistoryRevision
        let initialCompleteRevision = app.library.completeLibraryRevision
        app.recordRecentLibraryWatching(for: fixture.video)

        await app.recentWatchingTask?.value
        await app.testRecentWatchingTask?.value

        #expect(app.library.libraryPlaybackHistoryRevision == initialHistoryRevision + 1)
        #expect(app.library.completeLibraryRevision == initialCompleteRevision)
        #expect(app.completeLibraryTask == nil)
        #expect(app.library.recentWatchingItems.count == 1)
        #expect(app.library.testRecentWatchingItems.count == 1)

        app.recentWatchingTask = nil
        app.testRecentWatchingTask = nil
        let manualHistoryRevision = app.library.libraryPlaybackHistoryRevision
        let manualCompleteRevision = app.library.completeLibraryRevision
        app.markLibraryVideo(fixture.video, as: .finished)

        try await waitForLibraryRouteCondition {
            app.library.libraryPlaybackHistoryRevision == manualHistoryRevision + 1
        }
        #expect(app.library.completeLibraryFolderDetailsByPath[folderPath] != nil)
        #expect(
            app.library.completeLibraryFolderDetailStatusesByPath[folderPath]
                == .completed
        )
        await app.completeLibraryFolderDetailTasks[folderPath]?.value
        await app.recentWatchingTask?.value
        await app.testRecentWatchingTask?.value

        #expect(app.library.completeLibraryRevision == manualCompleteRevision)
        #expect(app.completeLibraryTask == nil)
        #expect(
            try database.libraryPlaybackHistory(forVideoFile: fixture.videoURL)?.completedAt != nil
        )
        #expect(
            app.library.completeLibraryFolderDetailsByPath[folderPath]?
                .videos.first?.watchState == .finished
        )
    }
}

@MainActor
@Test
func deferredPlaybackHistoryFlushUpdatesSharedRecentAndLibraryDetail() async throws {
    try await withTemporaryLibraryRouteApp { app, database in
        let fixture = try prepareLibraryRouteFixture(in: database)
        try database.setLibraryWatchState(
            videoFile: fixture.videoURL,
            duration: fixture.video.duration,
            state: .unwatched
        )
        app.indexing.selectedFolders = [fixture.root]
        app.applyCompleteLibrary(
            try database.completeLibraryFolderSummaries(under: [fixture.root])
        )
        let folderPath = try #require(
            app.library.completeLibraryFolderSummaries.first?.folderPath
        )
        let initialDetail = try #require(
            await app.completeLibraryFolderDetailFromStore(folderPath: folderPath)
        )
        #expect(initialDetail.videos.first?.watchState == .unwatched)
        app.library.testRecentWatchingItems = []
        app.library.testRecentWatchingStatus = .completed

        app.recordRecentLibraryWatching(
            for: fixture.video,
            refreshPresentation: false
        )

        #expect(
            app.pendingLibraryPlaybackHistoryPresentationVideoPaths
                == Set([fixture.videoURL.path])
        )
        #expect(
            app.library.completeLibraryFolderDetailsByPath[folderPath]?
                .videos.first?.watchState == .unwatched
        )

        app.flushPendingLibraryPlaybackHistoryPresentations()

        #expect(app.pendingLibraryPlaybackHistoryPresentationVideoPaths.isEmpty)
        #expect(app.library.completeLibraryFolderDetailsByPath[folderPath] != nil)
        await app.completeLibraryFolderDetailTasks[folderPath]?.value
        await app.testRecentWatchingTask?.value

        #expect(
            app.library.completeLibraryFolderDetailsByPath[folderPath]?
                .videos.first?.watchState == .watching
        )
        #expect(app.library.testRecentWatchingItems.first?.videoPath == fixture.videoURL.path)
        #expect(app.library.testRecentWatchingItems.first?.watchState == .watching)
    }
}

private struct LibraryRouteFixture {
    let root: URL
    let videoURL: URL
    let video: LibraryVideo
}

private func prepareLibraryRouteFixture(
    in database: SubtitleDatabase
) throws -> LibraryRouteFixture {
    let root = URL(fileURLWithPath: "/Media/Library Route Snapshot", isDirectory: true)
    let videoURL = root.appendingPathComponent("Show/Episode 1.mkv")
    let subtitleURL = root.appendingPathComponent("Show/Episode 1.srt")
    try database.replaceEntries(
        subtitleFile: subtitleURL,
        videoFile: videoURL,
        entries: [
            SubtitleEntry(
                sequenceNumber: 1,
                startTimecode: "00:00:01,000",
                endTimecode: "00:00:02,000",
                startMilliseconds: 1_000,
                endMilliseconds: 2_000,
                text: "route hydration snapshot"
            )
        ]
    )
    try database.rebuildLibraryPresentationSnapshot()
    try database.upsertLibraryPlaybackHistory(
        videoFile: videoURL,
        positionMilliseconds: 10_000,
        duration: 100
    )
    let presentation = try #require(
        try database.libraryPresentation(under: [root]).first?.videos.first
    )
    return LibraryRouteFixture(
        root: root,
        videoURL: videoURL,
        video: presentation.libraryVideo
    )
}

@MainActor
private func waitForLibraryRouteCondition(
    _ condition: () -> Bool
) async throws {
    for _ in 0..<300 {
        if condition() {
            return
        }
        try await Task.sleep(nanoseconds: 5_000_000)
    }
    throw LibraryRouteSnapshotTestError.timeout
}

private enum LibraryRouteSnapshotTestError: Error {
    case timeout
}

@MainActor
private func withTemporaryLibraryRouteApp(
    _ body: @MainActor (AppCoordinator, SubtitleDatabase) async throws -> Void
) async throws {
    let suiteName = "CueSeekerLibraryRouteSnapshotTests-\(UUID().uuidString)"
    let userDefaults = try #require(UserDefaults(suiteName: suiteName))
    let databaseURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerLibraryRouteSnapshotTests-\(UUID().uuidString)")
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
