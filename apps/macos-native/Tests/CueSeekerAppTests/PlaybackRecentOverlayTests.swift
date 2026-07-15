import AppKit
import CueSeekerCore
import CueSeekerPlayback
import Foundation
import Testing
@testable import CueSeekerApp

@MainActor
@Test
func playbackRecentLiveLoaderUsesTheCompleteWorkbenchDataset() async throws {
    try await withPlaybackRecentDatabase(folderCount: 7) {
        databaseURL,
        root,
        expectedItems in
        let loader = PlaybackRecentLoader.live(
            databaseURL: databaseURL,
            folders: [root]
        )

        let loadedItems = try await loader.load()

        #expect(expectedItems.count == 7)
        #expect(loadedItems == expectedItems)
        #expect(loadedItems.count > 5)
    }
}

@MainActor
@Test
func playbackRecentDefaultsToFirstAvailableAndPreservesSessionState() async throws {
    let items = try makePlaybackRecentPresentations(count: 6)
    let unavailableID = try #require(items.first?.id)
    let store = PlaybackRecentSessionStore(
        loader: PlaybackRecentLoader { items },
        isVideoAvailable: { $0 != unavailableID }
    )
    let session = PlaybackSubtitleFocusSessionStore(
        openSnapshot: playbackRecentOpenSnapshot(),
        sessionGeneration: 1,
        recentStore: store
    )

    #expect(publishPlaybackOverlayInitialTestSnapshot(session))
    #expect(session.selectModule(.recent))
    try await waitForPlaybackRecentCondition { store.status == .completed }
    #expect(store.items == items)
    #expect(store.selection.selectedItemID == items[1].id)

    store.selection.updateColumnCount(2)
    #expect(store.selection.move(.down))
    let selectedID = store.selection.selectedItemID
    let selectedItemID = try #require(selectedID)
    store.selection.recordVisibleFrames(
        [selectedItemID: CGRect(x: 0, y: 0, width: 100, height: 60)],
        viewportHeight: 100
    )
    let scrollAnchorID = store.selection.scrollAnchorItemID

    #expect(session.selectModule(.search))
    #expect(session.selectModule(.recent))
    #expect(store.selection.selectedItemID == selectedID)
    #expect(store.selection.scrollAnchorItemID == scrollAnchorID)
    #expect(store.status == .completed)
}

@MainActor
@Test
func playbackRecentRefreshesItsSnapshotWithoutLosingSelection() async throws {
    let items = try makePlaybackRecentPresentations(count: 3)
    let refreshedItems = Array(items.reversed())
    var snapshots = [items, refreshedItems]
    let sourceRevision = PlaybackRecentRevisionProbe()
    let store = PlaybackRecentSessionStore(
        loader: PlaybackRecentLoader {
            snapshots.removeFirst()
        },
        isVideoAvailable: { _ in true },
        sourceRevision: { sourceRevision.value }
    )

    store.activate()
    try await waitForPlaybackRecentCondition {
        store.status == .completed && store.items == items
    }
    store.selection.updateColumnCount(3)
    #expect(store.selection.move(.right))
    let selectedItemID = store.selection.selectedItemID
    store.selection.recordScrollOffsetY(91.5)

    sourceRevision.value = 1
    store.activate(refreshesExistingSnapshot: true)
    try await waitForPlaybackRecentCondition {
        store.status == .completed && store.items == refreshedItems
    }

    #expect(store.selection.selectedItemID == selectedItemID)
    #expect(store.selection.scrollOffsetY == 91.5)
    store.activate(refreshesExistingSnapshot: true)
    #expect(store.status == .completed)
}

@MainActor
@Test
func playbackRecentReloadRejectsStaleSuccessAndFailure() async throws {
    let items = try makePlaybackRecentPresentations(count: 4)
    let refreshedItems = Array(items.reversed())
    let latestItems = Array(items.dropFirst())
    let sourceRevision = PlaybackRecentRevisionProbe()
    let probe = PlaybackRecentReloadProbe()
    let store = PlaybackRecentSessionStore(
        loader: PlaybackRecentLoader {
            try await probe.load()
        },
        isVideoAvailable: { _ in true },
        sourceRevision: { sourceRevision.value }
    )

    store.activate()
    try await waitForPlaybackRecentCondition { probe.requestCount == 1 }

    sourceRevision.value = 1
    store.activate(refreshesExistingSnapshot: true)
    try await waitForPlaybackRecentCondition { probe.requestCount == 2 }
    #expect(probe.complete(2, with: .success(refreshedItems)))
    try await waitForPlaybackRecentCondition {
        store.status == .completed && store.items == refreshedItems
    }

    #expect(probe.complete(1, with: .success(items)))
    try await Task.sleep(for: .milliseconds(10))
    #expect(store.status == .completed)
    #expect(store.items == refreshedItems)

    sourceRevision.value = 2
    store.refresh()
    try await waitForPlaybackRecentCondition { probe.requestCount == 3 }
    sourceRevision.value = 3
    store.refresh()
    try await waitForPlaybackRecentCondition { probe.requestCount == 4 }
    #expect(probe.complete(4, with: .success(latestItems)))
    try await waitForPlaybackRecentCondition {
        store.status == .completed && store.items == latestItems
    }

    #expect(probe.complete(3, with: .failure(PlaybackRecentReloadProbeError())))
    try await Task.sleep(for: .milliseconds(10))
    #expect(store.status == .completed)
    #expect(store.items == latestItems)
    #expect(!store.hasActiveLoadTask)
}

@MainActor
private final class PlaybackRecentRevisionProbe {
    var value = 0
}

private struct PlaybackRecentReloadProbeError: Error {}

@MainActor
private final class PlaybackRecentReloadProbe {
    private var continuations: [
        Int: CheckedContinuation<[RecentLibraryWatchingPresentation], Error>
    ] = [:]
    private(set) var requestCount = 0

    func load() async throws -> [RecentLibraryWatchingPresentation] {
        requestCount += 1
        let request = requestCount
        return try await withCheckedThrowingContinuation { continuation in
            continuations[request] = continuation
        }
    }

    @discardableResult
    func complete(
        _ request: Int,
        with result: Result<[RecentLibraryWatchingPresentation], Error>
    ) -> Bool {
        guard let continuation = continuations.removeValue(forKey: request) else {
            return false
        }
        continuation.resume(with: result)
        return true
    }
}

@MainActor
@Test
func playbackRecentModuleSwitchKeepsLoadButDismissalCancelsAndClearsIt() async throws {
    let probe = PlaybackRecentCancellationProbe()
    let store = PlaybackRecentSessionStore(loader: PlaybackRecentLoader {
        try await probe.load()
    })
    let session = PlaybackSubtitleFocusSessionStore(
        openSnapshot: playbackRecentOpenSnapshot(),
        sessionGeneration: 1,
        recentStore: store
    )

    #expect(publishPlaybackOverlayInitialTestSnapshot(session))
    #expect(session.selectModule(.recent))
    try await waitForPlaybackRecentCondition { await probe.didStart }
    #expect(store.status == .loading)
    #expect(store.hasActiveLoadTask)

    #expect(session.selectModule(.search))
    await Task.yield()
    #expect(!(await probe.wasCancelled))
    #expect(store.hasActiveLoadTask)

    #expect(session.dismissByUser() == false)
    try await waitForPlaybackRecentCondition { await probe.wasCancelled }
    #expect(session.recentStore == nil)
    #expect(store.status == .idle)
    #expect(store.items.isEmpty)
    #expect(store.selection.selectedItemID == nil)
    #expect(store.selection.scrollAnchorItemID == nil)
    #expect(!store.hasActiveLoadTask)
}

@MainActor
@Test
func playbackRecentKeyboardRoutesGridAndDestroysSessionBeforeOpening() async throws {
    let items = try makePlaybackRecentPresentations(count: 6)
    try await withPlaybackRecentApp { app in
        let store = PlaybackRecentSessionStore(
            loader: PlaybackRecentLoader { items },
            isVideoAvailable: { _ in true }
        )
        let session = try #require(app.playback.beginSubtitleFocusSession(
            openSnapshot: playbackRecentOpenSnapshot(),
            recentStore: store
        ))
        #expect(publishPlaybackOverlayInitialTestSnapshot(session))
        #expect(session.selectModule(.recent))
        try await waitForPlaybackRecentCondition { store.status == .completed }
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
        #expect(!session.isActive)
        #expect(store.status == .idle)
        #expect(store.items.isEmpty)
        #expect(store.selection.selectedItemID == nil)
        #expect(app.playbackRecentOpenTask != nil)
        #expect(app.openPlaybackSubtitleFocusFromUser())
        #expect(app.playback.subtitleFocusSession == nil)

        app.cancelPlaybackRecentOpenTask()
        #expect(app.playbackRecentOpenTask == nil)
    }
}

@MainActor
@Test
func playbackRecentPointerDispatcherOpensClickedItemWithFolderNavigation() async throws {
    try await withPlaybackRecentDatabase(folderCount: 3) {
        databaseURL,
        _,
        items in
        let suiteName = "CueSeekerPlaybackRecentPointerTests-\(UUID().uuidString)"
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }
        _ = NSApplication.shared
        let app = AppCoordinator(
            userDefaults: userDefaults,
            databaseURL: databaseURL
        )
        await app.startupDatabaseTask?.value
        configurePlaybackRecentSource(app)

        let store = PlaybackRecentSessionStore(
            loader: PlaybackRecentLoader { items },
            isVideoAvailable: { _ in true }
        )
        let session = try #require(app.playback.beginSubtitleFocusSession(
            openSnapshot: playbackRecentOpenSnapshot(),
            recentStore: store
        ))
        #expect(publishPlaybackOverlayInitialTestSnapshot(session))
        #expect(session.selectModule(.recent))
        try await waitForPlaybackRecentCondition { store.status == .completed }
        let selectedBeforeClick = store.selection.selectedItemID
        let clickedItem = items[2]
        #expect(selectedBeforeClick != clickedItem.id)

        #expect(app.openPlaybackRecentItemFromOverlay(clickedItem))
        #expect(app.playback.subtitleFocusSession == nil)
        try await waitForPlaybackRecentCondition {
            app.library.selectedLibraryVideo?.videoPath == clickedItem.videoPath
        }

        #expect(app.library.selectedLibraryVideo?.videoPath == clickedItem.videoPath)
        #expect(
            app.library.libraryPlaybackNavigationVideos.map(\.videoPath)
                == [clickedItem.videoPath]
        )
        #expect(
            app.libraryResumePositionMilliseconds(for: clickedItem.libraryVideo)
                == clickedItem.positionMilliseconds
        )
        try await waitForPlaybackRecentCondition {
            app.playback.playbackStatus != .opening
        }
        app.stopPlayback()
        await app.libraryPlaybackHistoryTask?.value
        await app.recentWatchingTask?.value
        await app.testRecentWatchingTask?.value
    }
}

private actor PlaybackRecentCancellationProbe {
    private(set) var didStart = false
    private(set) var wasCancelled = false

    func load() async throws -> [RecentLibraryWatchingPresentation] {
        didStart = true
        do {
            try await Task.sleep(nanoseconds: 60_000_000_000)
            return []
        } catch {
            wasCancelled = true
            throw error
        }
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

@MainActor
private func withPlaybackRecentDatabase(
    folderCount: Int,
    _ body: @MainActor (
        _ databaseURL: URL,
        _ root: URL,
        _ expectedItems: [RecentLibraryWatchingPresentation]
    ) async throws -> Void
) async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
        "CueSeekerPlaybackRecentLoaderTests-\(UUID().uuidString)",
        isDirectory: true
    )
    let databaseURL = directory.appendingPathComponent("recent.sqlite")
    let root = directory.appendingPathComponent("Media", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: directory)
    }
    try FileManager.default.createDirectory(
        at: directory,
        withIntermediateDirectories: true
    )
    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()
    try indexPlaybackRecentFolders(folderCount, root: root, database: database)
    let expected = try database.recentLibraryWatching(
        under: [root],
        limit: Int.max
    )
    try await body(databaseURL, root, expected)
}

private func makePlaybackRecentPresentations(
    count: Int
) throws -> [RecentLibraryWatchingPresentation] {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
        "CueSeekerPlaybackRecentPresentationTests-\(UUID().uuidString)",
        isDirectory: true
    )
    defer {
        try? FileManager.default.removeItem(at: directory)
    }
    try FileManager.default.createDirectory(
        at: directory,
        withIntermediateDirectories: true
    )
    let root = directory.appendingPathComponent("Media", isDirectory: true)
    let database = try SubtitleDatabase(
        path: directory.appendingPathComponent("recent.sqlite")
    )
    try database.migrate()
    try indexPlaybackRecentFolders(count, root: root, database: database)
    return try database.recentLibraryWatching(under: [root], limit: Int.max)
}

private func indexPlaybackRecentFolders(
    _ count: Int,
    root: URL,
    database: SubtitleDatabase
) throws {
    for index in 0..<count {
        let folder = root.appendingPathComponent("Show \(index)", isDirectory: true)
        let video = folder.appendingPathComponent("Episode \(index + 1).mkv")
        let subtitle = folder.appendingPathComponent("Episode \(index + 1).srt")
        try database.replaceEntries(
            subtitleFile: subtitle,
            videoFile: video,
            entries: [
                SubtitleEntry(
                    sequenceNumber: 1,
                    startTimecode: "00:00:01,000",
                    endTimecode: "00:00:02,000",
                    startMilliseconds: 1_000,
                    endMilliseconds: 2_000,
                    text: "recent \(index)"
                )
            ]
        )
        try database.upsertLibraryPlaybackHistory(
            videoFile: video,
            positionMilliseconds: (index + 1) * 1_000,
            duration: 100
        )
    }
    try database.rebuildLibraryPresentationSnapshot()
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
        try await Task.sleep(nanoseconds: 10_000_000)
    }
}

private enum PlaybackRecentTestError: Error {
    case timedOut
}
