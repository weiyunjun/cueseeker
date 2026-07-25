import AppKit
@testable import CueSeekerCore
import Foundation
import Testing
@testable import CueSeekerApp

@MainActor
@Test
func playbackMultiModuleOverlayPreservesOneSessionThenReopensFresh() async throws {
    let fixture = playbackMultiModuleFixture()
    let featureLibrary = playbackMultiModuleFeatureLibrary(fixture)
    let searchStore = SearchStore()
    searchStore.searchResults = fixture.searchResults
    let shioriStore = playbackMultiModuleShioriStore(fixture.shiori)
    let recentStore = PlaybackRecentSessionStore(
        libraryStore: featureLibrary,
        isVideoAvailable: { _ in true }
    )
    let libraryStore = PlaybackLibrarySessionStore(
        libraryStore: featureLibrary,
        folderPath: fixture.detail.folderPath,
        isVideoAvailable: { _ in true }
    )
    let playlistItems = fixture.searchResults.enumerated().map {
        PlaybackCueResultItem(searchResult: $1, ordinal: $0)
    }
    let playlistSource = playbackMultiModuleSource(items: playlistItems)
    let session = PlaybackSubtitleFocusSessionStore(
        openSnapshot: fixture.openSnapshot,
        sessionGeneration: 1,
        availableModules: PlaybackOverlayModule.allCases,
        playlistSource: playlistSource,
        searchStore: searchStore,
        recentStore: recentStore,
        libraryStore: libraryStore,
        shioriStore: shioriStore
    )

    #expect(session.publishInitialSnapshot(
        playbackMultiModuleCurrentSnapshot(),
        token: session.token
    ))
    #expect(session.selectModule(.playlist))
    let playlistWindow = try #require(session.playlistWindow)
    #expect(playlistWindow.snapshot.loadedItemCount == playlistItems.count)
    #expect(playbackMultiModuleCommit(ordinal: 1, in: playlistWindow))

    #expect(session.selectModule(.search))
    searchStore.searchQuery = "overlay"
    let searchWindow = try #require(session.searchWindow)
    #expect(playbackMultiModuleCommit(ordinal: 1, in: searchWindow))

    #expect(session.selectModule(.recent))
    recentStore.selection.updateColumnCount(1)
    #expect(recentStore.selection.move(.down))
    recentStore.selection.recordScrollOffsetY(41.5)
    let recentSelection = recentStore.selection.selectedItemID

    #expect(session.selectModule(.library))
    #expect(libraryStore.selection.move(.down))
    libraryStore.selection.recordScrollOffsetY(82.75)
    let selectedEpisodeID = libraryStore.selection.selectedItemID

    #expect(session.selectModule(.shiori))
    let shioriWindow = try #require(session.shioriWindow)
    #expect(session.selectModule(.current))
    #expect(session.commitNativeReelSelection(ordinal: 2))

    for expectedModule in [
        PlaybackOverlayModule.playlist,
        .search,
        .recent,
        .library,
        .shiori,
        .current,
    ] {
        #expect(session.selectNextModule())
        #expect(session.selectedModule == expectedModule)
    }

    #expect(session.currentSnapshot?.selectedOrdinal == 2)
    #expect(playlistWindow.selectedOrdinal == 1)
    #expect(searchStore.searchQuery == "overlay")
    #expect(searchWindow.selectedOrdinal == 1)
    #expect(recentStore.selection.selectedItemID == recentSelection)
    #expect(recentStore.selection.scrollOffsetY == 41.5)
    #expect(libraryStore.selection.selectedItemID == selectedEpisodeID)
    #expect(libraryStore.selection.scrollOffsetY == 82.75)
    #expect(shioriWindow.selectedOrdinal == 0)

    #expect(session.dismissByUser() == false)
    #expect(!session.isActive)
    #expect(session.selectedModule == nil)
    #expect(recentStore.selection.selectedItemID == nil)
    #expect(libraryStore.selection.selectedItemID == nil)
    #expect(searchStore.searchQuery == "overlay")
    #expect(searchStore.searchResults == fixture.searchResults)
    #expect(featureLibrary.testRecentWatchingItems == fixture.recentItems)
    #expect(featureLibrary.completeLibraryFolderSummaries == fixture.folders)
    #expect(shioriStore.tableRowStore.snapshot.totalRowCount == 1)

    let freshRecentStore = PlaybackRecentSessionStore(
        libraryStore: featureLibrary,
        isVideoAvailable: { _ in true }
    )
    let freshLibraryStore = PlaybackLibrarySessionStore(
        libraryStore: featureLibrary,
        folderPath: fixture.detail.folderPath,
        isVideoAvailable: { _ in true }
    )
    let freshSession = PlaybackSubtitleFocusSessionStore(
        openSnapshot: fixture.openSnapshot,
        sessionGeneration: 2,
        availableModules: PlaybackOverlayModule.allCases,
        playlistSource: playlistSource,
        searchStore: searchStore,
        recentStore: freshRecentStore,
        libraryStore: freshLibraryStore,
        shioriStore: shioriStore
    )

    #expect(freshSession.selectedModule == .current)
    #expect(freshSession.searchWindow?.snapshot.totalCount == 3)
    #expect(freshRecentStore.selection.selectedItemID == nil)
    #expect(freshLibraryStore.selection.selectedItemID == nil)
    #expect(freshSession.dismissByUser() == false)
}

@MainActor
@Test
func playbackMultiModuleStopCancelsSessionWorkButPreservesFeatureStores() async throws {
    let fixture = playbackMultiModuleFixture()
    let suiteName = "CueSeekerPlaybackMultiModuleStopTests-\(UUID().uuidString)"
    let userDefaults = try #require(UserDefaults(suiteName: suiteName))
    let databaseURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("PlaybackMultiModule-\(UUID().uuidString).sqlite")
    defer {
        userDefaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: databaseURL)
    }
    _ = NSApplication.shared
    let app = AppCoordinator(
        userDefaults: userDefaults,
        databaseURL: databaseURL
    )
    await app.startupDatabaseTask?.value
    let featureLibrary = app.library
    featureLibrary.testRecentWatchingItems = fixture.recentItems
    featureLibrary.testRecentWatchingStatus = .completed
    featureLibrary.completeLibraryFolderSummaries = fixture.folders
    featureLibrary.completeLibraryStatus = .completed
    featureLibrary.completeLibraryFolderDetailsByPath = [
        fixture.detail.folderPath: fixture.detail,
    ]
    featureLibrary.completeLibraryFolderDetailStatusesByPath = [
        fixture.detail.folderPath: .completed,
    ]
    app.search.searchResults = fixture.searchResults
    app.shiori.tableRowStore.updateShioriRows(
        [playbackMultiModuleShioriRow(fixture.shiori)],
        tableName: "shiori"
    )

    let probe = PlaybackMultiModuleCancellationProbe()
    let playlistItems = fixture.searchResults.enumerated().map {
        PlaybackCueResultItem(searchResult: $1, ordinal: $0)
    }
    let playlistSource = playbackMultiModuleSource(items: playlistItems)
    let recentStore = PlaybackRecentSessionStore(
        libraryStore: featureLibrary,
        isVideoAvailable: { _ in true }
    )
    let libraryStore = PlaybackLibrarySessionStore(
        libraryStore: featureLibrary,
        folderPath: fixture.detail.folderPath,
        isVideoAvailable: { _ in true }
    )
    app.playback.setPlaylistSource(playlistSource)
    let session = try #require(app.playback.beginSubtitleFocusSession(
        openSnapshot: fixture.openSnapshot,
        availableModules: PlaybackOverlayModule.allCases,
        searchStore: app.search,
        recentStore: recentStore,
        libraryStore: libraryStore,
        shioriStore: app.shiori
    ))
    app.startPlaybackSubtitleFocusInitialLoad(
        for: session,
        initialSnapshotLoader: { _, _ in
            await probe.suspend(.current)
            return playbackMultiModuleCurrentSnapshot()
        },
        completeCueBatchLoader: { _, _ in
            Issue.record("Cancelled initial load must not start completion")
            return SubtitleFocusCueBatch(totalCount: 0, cues: [])
        }
    )
    _ = try #require(session.playlistWindow)
    recentStore.activate()
    libraryStore.activate()
    try await waitForPlaybackMultiModuleCondition {
        probe.started == [.current]
    }

    app.stopPlayback()
    try await waitForPlaybackMultiModuleCondition {
        probe.cancelled == [.current]
    }

    #expect(app.playback.subtitleFocusSession == nil)
    #expect(!session.isActive)
    #expect(playlistSource.boundary.totalCount == 0)
    #expect(recentStore.selection.selectedItemID == nil)
    #expect(libraryStore.selection.selectedItemID == nil)
    #expect(app.search.searchResults == fixture.searchResults)
    #expect(featureLibrary.testRecentWatchingItems == fixture.recentItems)
    #expect(featureLibrary.completeLibraryFolderSummaries == fixture.folders)
    #expect(featureLibrary.completeLibraryFolderDetailsByPath[fixture.detail.folderPath] == fixture.detail)
    #expect(app.shiori.tableRowStore.snapshot.totalRowCount == 1)
}

private struct PlaybackMultiModuleFixture {
    let openSnapshot: PlaybackSubtitleFocusOpenSnapshot
    let searchResults: [SubtitleSearchResult]
    let recentItems: [RecentLibraryWatchingPresentation]
    let folders: [CompleteLibraryFolderSummaryPresentation]
    let detail: CompleteLibraryFolderDetailPresentation
    let shiori: Shiori
}

private func playbackMultiModuleFixture() -> PlaybackMultiModuleFixture {
    let searchResults = (0..<3).map { ordinal in
        SubtitleSearchResult(
            entryID: Int64(ordinal + 1),
            subtitlePath: "/Media/Show/Episode-\(ordinal).srt",
            subtitleFormat: .srt,
            videoPath: "/Media/Show/Episode-\(ordinal).mkv",
            videoName: "Episode-\(ordinal).mkv",
            startMilliseconds: ordinal * 1_000,
            endMilliseconds: ordinal * 1_000 + 900,
            content: "search \(ordinal)",
            cueLines: ["search \(ordinal)"],
            searchRank: ordinal
        )
    }
    let videos = (0..<3).map { ordinal in
        playbackMultiModuleVideo(ordinal)
    }
    let folder = CompleteLibraryFolderSummaryPresentation(
        folderPath: "/Media/Show",
        folderTitle: "Show",
        coverPath: nil,
        coverRevision: nil,
        episodeCount: videos.count
    )
    let detail = CompleteLibraryFolderDetailPresentation(
        folderPath: folder.folderPath,
        folderTitle: folder.folderTitle,
        videos: videos
    )
    let recentItems = videos.map { video in
        RecentLibraryWatchingPresentation(
            videoPath: video.videoPath,
            videoName: video.videoName,
            duration: video.duration,
            subtitlePath: video.subtitlePath,
            subtitleFormat: video.subtitleFormat,
            displayTitle: video.displayTitle,
            fileExtension: video.fileExtension,
            folderPath: folder.folderPath,
            folderTitle: folder.folderTitle,
            episodeNumber: video.episodeNumber,
            positionMilliseconds: video.positionMilliseconds,
            playbackDuration: video.playbackDuration,
            startedAt: video.startedAt,
            completedAt: video.completedAt,
            updatedAt: video.historyUpdatedAt ?? "2026-07-16T00:00:00Z",
            coverPath: nil,
            coverRevision: nil
        )
    }
    let shiori = Shiori(
        id: 9,
        subtitlePath: searchResults[0].subtitlePath,
        subtitleFormat: .srt,
        videoPath: searchResults[0].videoPath,
        videoName: searchResults[0].videoName,
        startMilliseconds: 0,
        endMilliseconds: 900,
        content: "saved",
        isValid: true,
        createdAt: "2026-07-16T00:00:00Z"
    )
    return PlaybackMultiModuleFixture(
        openSnapshot: PlaybackSubtitleFocusOpenSnapshot(
            source: SubtitleFocusSourceIdentity(
                videoPath: searchResults[0].videoPath,
                subtitlePath: searchResults[0].subtitlePath,
                subtitleFormat: .srt
            ),
            timestampMilliseconds: 500,
            wasPlaying: false
        ),
        searchResults: searchResults,
        recentItems: recentItems,
        folders: [folder],
        detail: detail,
        shiori: shiori
    )
}

private func playbackMultiModuleVideo(
    _ ordinal: Int
) -> CompleteLibraryVideoPresentation {
    CompleteLibraryVideoPresentation(
        videoPath: "/Media/Show/Episode-\(ordinal).mkv",
        videoName: "Episode-\(ordinal).mkv",
        fileSize: nil,
        videoCodec: nil,
        videoWidth: nil,
        videoHeight: nil,
        frameRate: nil,
        duration: 100,
        subtitlePath: "/Media/Show/Episode-\(ordinal).srt",
        subtitleFormat: .srt,
        displayTitle: "Episode \(ordinal)",
        fileExtension: "mkv",
        episodeNumber: ordinal + 1,
        positionMilliseconds: ordinal * 1_000,
        playbackDuration: 100,
        startedAt: "2026-07-16T00:00:00Z",
        completedAt: nil,
        historyUpdatedAt: "2026-07-16T00:00:00Z",
        coverPath: nil,
        coverRevision: nil
    )
}

@MainActor
private func playbackMultiModuleFeatureLibrary(
    _ fixture: PlaybackMultiModuleFixture
) -> LibraryStore {
    let library = LibraryStore()
    library.testRecentWatchingItems = fixture.recentItems
    library.testRecentWatchingStatus = .completed
    library.completeLibraryFolderSummaries = fixture.folders
    library.completeLibraryStatus = .completed
    library.completeLibraryFolderDetailsByPath = [
        fixture.detail.folderPath: fixture.detail,
    ]
    library.completeLibraryFolderDetailStatusesByPath = [
        fixture.detail.folderPath: .completed,
    ]
    return library
}

@MainActor
private func playbackMultiModuleShioriStore(_ shiori: Shiori) -> ShioriStore {
    let store = ShioriStore()
    store.tableRowStore.updateShioriRows(
        [playbackMultiModuleShioriRow(shiori)],
        tableName: "shiori"
    )
    store.installTableResultShioriIDs([shiori.id])
    store.markTableRowsLoaded(totalSavedRowCount: 1)
    return store
}

private func playbackMultiModuleShioriRow(
    _ shiori: Shiori
) -> TableSandboxShioriRowSource {
    TableSandboxShioriRowSource(
        shiori: shiori,
        displayTitle: shiori.videoName,
        dateAddedText: shiori.createdAt,
        languages: [.unknown],
        shioriTags: []
    )
}

@MainActor
private func playbackMultiModuleSource(
    items: [PlaybackCueResultItem]
) -> PlaybackCueResultSource {
    PlaybackCueResultSource(
        kind: .search,
        totalCount: items.count
    ) { ordinal in
        guard items.indices.contains(ordinal) else {
            return nil
        }
        return items[ordinal]
    }
}

private enum PlaybackMultiModuleCancellationOperation: Hashable {
    case current
}

@MainActor
private final class PlaybackMultiModuleCancellationProbe {
    private(set) var started: Set<PlaybackMultiModuleCancellationOperation> = []
    private(set) var cancelled: Set<PlaybackMultiModuleCancellationOperation> = []

    func suspend(_ operation: PlaybackMultiModuleCancellationOperation) async {
        started.insert(operation)
        do {
            try await Task.sleep(for: .seconds(60))
        } catch is CancellationError {
            cancelled.insert(operation)
        } catch {
            Issue.record("Unexpected cancellation probe error: \(error)")
        }
    }
}

@MainActor
private func playbackMultiModuleCommit(
    ordinal: Int,
    in window: PlaybackCueResultSessionWindowStore
) -> Bool {
    guard let datasetID = window.reelDatasetID else {
        return false
    }
    return window.commitSelection(PlaybackVirtualReelSelectionCommit(
        datasetID: AnyHashable(datasetID),
        generation: window.snapshot.generation,
        ordinal: ordinal
    ))
}

private func playbackMultiModuleCurrentSnapshot() -> SubtitleFocusSnapshot {
    let cues = (0..<3).map(playbackMultiModuleCue)
    return SubtitleFocusSnapshot(
        totalCount: 3,
        selectedOrdinal: 1,
        cues: cues
    )
}

private func playbackMultiModuleCue(_ ordinal: Int) -> SubtitleFocusCue {
    SubtitleFocusCue(
        id: Int64(ordinal + 1),
        cueGroupID: Int64(ordinal + 101),
        ordinal: ordinal,
        eventIndex: ordinal,
        displayOrder: 0,
        startMilliseconds: ordinal * 1_000,
        endMilliseconds: ordinal * 1_000 + 900,
        content: "current \(ordinal)"
    )
}

@MainActor
private func waitForPlaybackMultiModuleCondition(
    _ condition: @escaping @MainActor () async -> Bool
) async throws {
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: .seconds(3))
    while !(await condition()) {
        guard clock.now < deadline else {
            Issue.record("Timed out waiting for Playback multi-module state")
            return
        }
        try await Task.sleep(for: .milliseconds(5))
    }
}
