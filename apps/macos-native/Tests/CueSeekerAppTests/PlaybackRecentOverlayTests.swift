import AppKit
@testable import CueSeekerCore
import CueSeekerPlayback
import Foundation
import Testing
@testable import CueSeekerApp

@MainActor
@Test
func playbackRecentUsesWorkbenchStoreWithoutRetainingAnotherDataset() throws {
    let items = playbackRecentPresentations(count: 6)
    let library = LibraryStore()
    library.testRecentWatchingItems = items
    library.testRecentWatchingStatus = .completed
    var sourceRequestCount = 0
    let store = PlaybackRecentSessionStore(
        libraryStore: library,
        requestSource: { sourceRequestCount += 1 },
        isVideoAvailable: { $0 != items[0].videoPath }
    )
    let session = PlaybackSubtitleFocusSessionStore(
        openSnapshot: playbackRecentOpenSnapshot(),
        sessionGeneration: 1,
        availableModules: PlaybackOverlayModule.allCases,
        recentStore: store
    )

    #expect(publishPlaybackOverlayInitialTestSnapshot(session))
    #expect(session.selectModule(.recent))
    #expect(store.libraryStore === library)
    #expect(store.items == library.testRecentWatchingItems)
    #expect(store.selection.selectedItemID == items[1].id)
    #expect(sourceRequestCount == 1)

    #expect(session.dismissByUser() == false)
    #expect(session.recentStore == nil)
    #expect(store.selection.selectedItemID == nil)
    #expect(library.testRecentWatchingItems == items)
    #expect(library.testRecentWatchingStatus == .completed)
}

@MainActor
@Test
func playbackRecentSharedRefreshPreservesSessionSelectionAndScroll() {
    let items = playbackRecentPresentations(count: 4)
    let library = LibraryStore()
    library.testRecentWatchingItems = items
    library.testRecentWatchingStatus = .completed
    let store = PlaybackRecentSessionStore(
        libraryStore: library,
        isVideoAvailable: { _ in true }
    )

    store.activate()
    store.selection.updateColumnCount(4)
    #expect(store.selection.move(.right))
    let selectedID = store.selection.selectedItemID
    store.selection.recordScrollOffsetY(91.5)

    library.testRecentWatchingItems = Array(items.reversed())
    library.testRecentWatchingRevision += 1

    #expect(store.items == Array(items.reversed()))
    #expect(store.selection.selectedItemID == selectedID)
    #expect(store.selection.scrollOffsetY == 91.5)
}

@MainActor
@Test
func playbackRecentSourceOpensAsTheMediaPlaylist() async throws {
    let items = playbackRecentPresentations(count: 3)
    try await withPlaybackRecentApp { app in
        app.library.testRecentWatchingItems = items
        app.library.testRecentWatchingStatus = .completed
        app.library.selectedLibraryVideo = items[0].libraryVideo
        app.search.selectedSearchResult = nil
        app.activePlaybackSource = .library(videoPath: items[0].videoPath)
        app.playbackReturnContext = .recent
        app.ensurePlayerInitialized()

        #expect(app.openPlaybackSubtitleFocusFromUser())
        let session = try #require(app.playback.subtitleFocusSession)
        #expect(session.availableModules == [.current, .playlist])
        #expect(session.recentStore?.libraryStore === app.library)
        #expect(session.libraryStore == nil)
        app.invalidatePlaybackSubtitleFocusForSourceReplacement()
    }
}

@MainActor
@Test
func playbackRecentKeyboardRoutesSharedGridAndDestroysOnlySession() async throws {
    let items = playbackRecentPresentations(count: 6)
    try await withPlaybackRecentApp { app in
        app.library.testRecentWatchingItems = items
        app.library.testRecentWatchingStatus = .completed
        let store = PlaybackRecentSessionStore(
            libraryStore: app.library,
            isVideoAvailable: { _ in true }
        )
        let session = try #require(app.playback.beginSubtitleFocusSession(
            openSnapshot: playbackRecentOpenSnapshot(),
            recentStore: store
        ))
        #expect(publishPlaybackOverlayInitialTestSnapshot(session))
        #expect(session.selectModule(.playlist))
        store.selection.updateColumnCount(3)

        #expect(app.handlePlaybackKeyDown(keyCode: 124, modifierFlagsRawValue: 0))
        #expect(store.selection.selectedItemID == items[1].id)
        #expect(app.handlePlaybackKeyDown(keyCode: 125, modifierFlagsRawValue: 0))
        #expect(store.selection.selectedItemID == items[4].id)
        #expect(app.handlePlaybackKeyDown(keyCode: 123, modifierFlagsRawValue: 0))
        #expect(store.selection.selectedItemID == items[3].id)
        #expect(app.handlePlaybackKeyDown(keyCode: 126, modifierFlagsRawValue: 0))
        #expect(store.selection.selectedItemID == items[0].id)

        #expect(app.handlePlaybackKeyDown(
            keyCode: 36,
            modifierFlagsRawValue: 0,
            isRepeat: true
        ))
        #expect(app.playback.subtitleFocusSession === session)

        #expect(app.handlePlaybackKeyDown(keyCode: 36, modifierFlagsRawValue: 0))
        #expect(app.playback.subtitleFocusSession == nil)
        #expect(store.selection.selectedItemID == nil)
        #expect(app.library.testRecentWatchingItems == items)
        #expect(app.playbackRecentOpenTask != nil)

        app.cancelPlaybackRecentOpenTask()
    }
}

@MainActor
@Test
func playbackRecentPointerDispatcherUsesSharedWorkbenchItem() async throws {
    let items = playbackRecentPresentations(count: 3)
    try await withPlaybackRecentApp { app in
        app.library.testRecentWatchingItems = items
        app.library.testRecentWatchingStatus = .completed
        let store = PlaybackRecentSessionStore(
            libraryStore: app.library,
            isVideoAvailable: { _ in true }
        )
        let session = try #require(app.playback.beginSubtitleFocusSession(
            openSnapshot: playbackRecentOpenSnapshot(),
            availableModules: PlaybackOverlayModule.allCases,
            recentStore: store
        ))
        #expect(publishPlaybackOverlayInitialTestSnapshot(session))
        #expect(session.selectModule(.recent))

        let clickedItem = items[2]
        #expect(app.openPlaybackRecentItemFromOverlay(clickedItem))
        #expect(app.playback.subtitleFocusSession == nil)
        try await waitForPlaybackRecentCondition {
            app.library.selectedLibraryVideo?.videoPath == clickedItem.videoPath
        }
        #expect(app.library.testRecentWatchingItems == items)
        app.stopPlayback()
    }
}

@MainActor
private func withPlaybackRecentApp(
    _ body: @MainActor (AppCoordinator) async throws -> Void
) async throws {
    let suiteName = "CueSeekerPlaybackRecentTests-\(UUID().uuidString)"
    let userDefaults = try #require(UserDefaults(suiteName: suiteName))
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
        "CueSeekerPlaybackRecentTests-\(UUID().uuidString)",
        isDirectory: true
    )
    let databaseURL = directory.appendingPathComponent("recent.sqlite")
    defer {
        userDefaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: directory)
    }
    try FileManager.default.createDirectory(
        at: directory,
        withIntermediateDirectories: true
    )

    _ = NSApplication.shared
    let app = AppCoordinator(userDefaults: userDefaults, databaseURL: databaseURL)
    await app.startupDatabaseTask?.value
    configurePlaybackRecentSource(app)
    try await body(app)
    app.cancelPlaybackRecentOpenTask()
}

@MainActor
private func configurePlaybackRecentSource(_ app: AppCoordinator) {
    let source = playbackRecentOpenSnapshot().source
    app.search.selectedSearchResult = SubtitleSearchResult(
        entryID: 1,
        subtitlePath: source.subtitlePath,
        subtitleFormat: source.subtitleFormat,
        videoPath: source.videoPath,
        videoName: "Playback Recent Source",
        startMilliseconds: 1_000,
        endMilliseconds: 2_000,
        content: "source",
        cueLines: ["source"]
    )
    app.playback.playbackViewModel = PlaybackViewModel(player: PlaybackPlayer())
    app.playback.playbackStatus = .paused
}

private func playbackRecentPresentations(
    count: Int
) -> [RecentLibraryWatchingPresentation] {
    (0..<count).map { index in
        RecentLibraryWatchingPresentation(
            videoPath: "/Media/Show-\(index)/Episode-\(index).mkv",
            videoName: "Episode-\(index).mkv",
            duration: 100,
            subtitlePath: "/Media/Show-\(index)/Episode-\(index).srt",
            subtitleFormat: .srt,
            displayTitle: "Episode \(index)",
            fileExtension: "mkv",
            folderPath: "/Media/Show-\(index)",
            folderTitle: "Show \(index)",
            episodeNumber: index + 1,
            positionMilliseconds: (index + 1) * 1_000,
            playbackDuration: 100,
            startedAt: "2026-07-16T00:00:00Z",
            completedAt: nil,
            updatedAt: "2026-07-16T00:00:00Z",
            coverPath: nil,
            coverRevision: nil
        )
    }
}

private func playbackRecentOpenSnapshot() -> PlaybackSubtitleFocusOpenSnapshot {
    PlaybackSubtitleFocusOpenSnapshot(
        source: SubtitleFocusSourceIdentity(
            videoPath: "/Media/Playback-Recent-Source.mkv",
            subtitlePath: "/Media/Playback-Recent-Source.srt",
            subtitleFormat: .srt
        ),
        timestampMilliseconds: 1_500,
        wasPlaying: false
    )
}

@MainActor
private func waitForPlaybackRecentCondition(
    timeout: TimeInterval = 3,
    condition: @MainActor () async -> Bool
) async throws {
    let deadline = Date().addingTimeInterval(timeout)
    while !(await condition()) {
        guard Date() < deadline else {
            throw PlaybackRecentTestError.timedOut
        }
        try await Task.sleep(for: .milliseconds(10))
    }
}

private enum PlaybackRecentTestError: Error {
    case timedOut
}
