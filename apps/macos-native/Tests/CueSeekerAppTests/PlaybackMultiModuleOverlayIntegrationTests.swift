import AppKit
import CueSeekerCore
import Foundation
import Testing
@testable import CueSeekerApp

@MainActor
@Test
func playbackMultiModuleOverlayPreservesOneSessionThenReopensFresh() async throws {
    try await withPlaybackMultiModuleFixture { fixture in
        let playlistItems = fixture.searchResults.enumerated().map {
            PlaybackCueResultItem(searchResult: $1, ordinal: $0)
        }
        let playlistSource = playbackMultiModuleSource(
            kind: .search,
            items: playlistItems
        )
        let searchStore = playbackMultiModuleSearchStore(fixture)
        searchStore.searchResults = fixture.searchResults
        let recentStore = PlaybackRecentSessionStore(
            loader: PlaybackRecentLoader { fixture.recentItems },
            isVideoAvailable: { _ in true }
        )
        let libraryStore = playbackMultiModuleLibraryStore(fixture)
        let shioriStore = playbackMultiModuleShioriStore(fixture.shiori)
        let session = PlaybackSubtitleFocusSessionStore(
            openSnapshot: playbackMultiModuleOpenSnapshot(fixture),
            sessionGeneration: 1,
            availableModules: PlaybackOverlayModule.allCases,
            playlistSource: playlistSource,
            searchStore: searchStore,
            recentStore: recentStore,
            libraryStore: libraryStore,
            shioriStore: shioriStore
        )

        #expect(session.availableModules == PlaybackOverlayModule.allCases)
        #expect(session.publishInitialSnapshot(
            playbackMultiModuleCurrentSnapshot(),
            token: session.token
        ))

        #expect(session.selectModule(.playlist))
        let playlistWindow = try #require(session.playlistWindow)
        #expect(playlistWindow.requestWindow(containing: 0))
        try await waitForPlaybackMultiModuleCondition {
            playlistWindow.snapshot.loadedItemCount == playlistItems.count
        }
        #expect(playbackMultiModuleCommit(ordinal: 1, in: playlistWindow))

        #expect(session.selectModule(.search))
        searchStore.searchQuery = "overlay"
        try await waitForPlaybackMultiModuleCondition {
            session.searchWindow?.snapshot.totalCount == 3
                && session.searchWindow?.snapshot.loadedItemCount == 3
        }
        let searchWindow = try #require(session.searchWindow)
        #expect(playbackMultiModuleCommit(ordinal: 1, in: searchWindow))

        #expect(session.selectModule(.recent))
        try await waitForPlaybackMultiModuleCondition {
            recentStore.status == .completed
        }
        recentStore.selection.updateColumnCount(1)
        #expect(recentStore.selection.move(.down))
        recentStore.selection.recordScrollOffsetY(41.5)
        let recentSelection = recentStore.selection.selectedItemID

        #expect(session.selectModule(.library))
        try await waitForPlaybackMultiModuleCondition {
            libraryStore.folderStatus == .completed
        }
        libraryStore.folderSelection.recordScrollOffsetY(23.25)
        #expect(libraryStore.enterFolder())
        try await waitForPlaybackMultiModuleCondition {
            libraryStore.detailStatus == .completed
        }
        let episodeSelection = try #require(libraryStore.episodeSelection)
        #expect(episodeSelection.move(.down))
        episodeSelection.recordScrollOffsetY(82.75)
        let selectedEpisodeID = episodeSelection.selectedItemID

        #expect(session.selectModule(.shiori))
        let shioriWindow = try #require(session.shioriWindow)
        #expect(shioriWindow.requestWindow(containing: 0))
        try await waitForPlaybackMultiModuleCondition {
            shioriWindow.snapshot.loadedItemCount == 1
        }

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
        #expect(playlistWindow.retainedItemCount == playlistItems.count)
        #expect(searchStore.searchQuery == "overlay")
        #expect(searchWindow.selectedOrdinal == 1)
        #expect(searchWindow.retainedItemCount == 0)
        #expect(recentStore.selection.selectedItemID == recentSelection)
        #expect(recentStore.selection.scrollOffsetY == 41.5)
        #expect(libraryStore.level != .folders)
        #expect(libraryStore.folderSelection.scrollOffsetY == 23.25)
        #expect(libraryStore.episodeSelection?.selectedItemID == selectedEpisodeID)
        #expect(libraryStore.episodeSelection?.scrollOffsetY == 82.75)
        #expect(shioriWindow.selectedOrdinal == 0)
        #expect(shioriWindow.retainedItemCount == 0)

        #expect(session.dismissByUser() == false)
        #expect(!session.isActive)
        #expect(session.selectedModule == nil)
        #expect(session.availableModules.isEmpty)
        #expect(session.playlistWindow == nil)
        #expect(session.searchStore == nil)
        #expect(session.recentStore == nil)
        #expect(session.libraryStore == nil)
        #expect(session.shioriWindow == nil)
        #expect(playlistWindow.retainedItemCount == 0)
        #expect(playlistWindow.selectedOrdinal == nil)
        #expect(searchStore.searchQuery == "overlay")
        #expect(searchStore.searchResults.count == 3)
        #expect(recentStore.status == .idle)
        #expect(recentStore.items.isEmpty)
        #expect(recentStore.selection.selectedItemID == nil)
        #expect(libraryStore.folderStatus == .idle)
        #expect(libraryStore.folders.isEmpty)
        #expect(libraryStore.detail == nil)
        #expect(libraryStore.episodeSelection == nil)
        #expect(shioriWindow.retainedItemCount == 0)
        #expect(shioriWindow.selectedOrdinal == nil)

        let freshSearchStore = playbackMultiModuleSearchStore(fixture)
        let freshRecentStore = PlaybackRecentSessionStore(
            loader: PlaybackRecentLoader { fixture.recentItems },
            isVideoAvailable: { _ in true }
        )
        let freshLibraryStore = playbackMultiModuleLibraryStore(fixture)
        let freshShioriStore = playbackMultiModuleShioriStore(fixture.shiori)
        let freshSession = PlaybackSubtitleFocusSessionStore(
            openSnapshot: playbackMultiModuleOpenSnapshot(fixture),
            sessionGeneration: 2,
            availableModules: PlaybackOverlayModule.allCases,
            playlistSource: playlistSource,
            searchStore: freshSearchStore,
            recentStore: freshRecentStore,
            libraryStore: freshLibraryStore,
            shioriStore: freshShioriStore
        )

        #expect(freshSession.selectedModule == .current)
        #expect(freshSearchStore.searchQuery.isEmpty)
        #expect(freshSearchStore.searchStatus == .idle)
        #expect(freshSession.searchWindow?.snapshot.totalCount == 0)
        #expect(freshRecentStore.status == .idle)
        #expect(freshRecentStore.selection.selectedItemID == nil)
        #expect(freshLibraryStore.level == .folders)
        #expect(freshLibraryStore.folderStatus == .idle)
        #expect(freshLibraryStore.folderSelection.selectedItemID == nil)
        #expect(freshSession.playlistWindow?.selectedOrdinal == 0)
        #expect(freshSession.shioriWindow?.selectedOrdinal == 0)
        #expect(freshSession.dismissByUser() == false)
    }
}

@MainActor
@Test
func playbackMultiModuleOverlayStopCancelsAllWorkAndRejectsLateResults() async throws {
    try await withPlaybackMultiModuleFixture { fixture in
        let suiteName = "CueSeekerPlaybackMultiModuleStopTests-\(UUID().uuidString)"
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }
        _ = NSApplication.shared
        let app = AppCoordinator(
            userDefaults: userDefaults,
            databaseURL: fixture.databaseURL
        )
        await app.startupDatabaseTask?.value

        let probe = PlaybackMultiModuleCancellationProbe()
        let playlistItems = fixture.searchResults.enumerated().map {
            PlaybackCueResultItem(searchResult: $1, ordinal: $0)
        }
        let playlistSource = playbackMultiModuleSuspendingSource(
            kind: .search,
            items: playlistItems,
            operation: .playlist,
            probe: probe
        )
        let shioriStore = playbackMultiModuleShioriStore(fixture.shiori)
        let searchStore = app.search
        let recentStore = PlaybackRecentSessionStore(
            loader: PlaybackRecentLoader {
                await probe.suspend(.recent)
                return fixture.recentItems
            },
            isVideoAvailable: { _ in true }
        )
        let libraryStore = PlaybackLibrarySessionStore(
            loader: PlaybackLibraryLoader(
                loadFolders: { fixture.folders },
                loadFolderDetail: { _ in
                    await probe.suspend(.libraryDetail)
                    return fixture.detail
                }
            ),
            isVideoAvailable: { _ in true }
        )

        app.playback.setPlaylistSource(playlistSource)
        let session = try #require(app.playback.beginSubtitleFocusSession(
            openSnapshot: playbackMultiModuleOpenSnapshot(fixture),
            availableModules: PlaybackOverlayModule.allCases,
            searchStore: searchStore,
            recentStore: recentStore,
            libraryStore: libraryStore,
            shioriStore: shioriStore
        ))
        app.startPlaybackSubtitleFocusInitialLoad(
            for: session,
            initialSnapshotLoader: { _, _ in
                await probe.suspend(.currentInitial)
                return playbackMultiModuleCurrentSnapshot()
            },
            completeCueBatchLoader: { _, _ in
                Issue.record("Cancelled Current initial load must not start completion")
                return SubtitleFocusCueBatch(totalCount: 0, cues: [])
            }
        )
        let playlistWindow = try #require(session.playlistWindow)
        let shioriWindow = try #require(session.shioriWindow)
        #expect(playlistWindow.requestWindow(containing: 0))
        #expect(shioriWindow.requestWindow(containing: 0))
        recentStore.activate()
        libraryStore.activate()
        try await waitForPlaybackMultiModuleCondition {
            libraryStore.folderStatus == .completed
        }
        #expect(libraryStore.enterFolder())
        let expectedOperations: Set<PlaybackMultiModuleCancellationOperation> = [
            .currentInitial,
            .playlist,
            .recent,
            .libraryDetail,
        ]
        try await waitForPlaybackMultiModuleCondition {
            probe.started == expectedOperations
        }

        app.stopPlayback()
        try await waitForPlaybackMultiModuleCondition {
            probe.cancelled == expectedOperations
        }
        try await Task.sleep(for: .milliseconds(20))

        #expect(app.playback.subtitleFocusSession == nil)
        #expect(app.playback.playlistSource == nil)
        #expect(!session.isActive)
        #expect(session.state == .closed)
        #expect(session.selectedModule == nil)
        #expect(session.availableModules.isEmpty)
        #expect(!session.selectNextModule())
        #expect(!session.requestKeyboardNavigation(.forward))
        #expect(session.requestKeyboardAction(.copyCueText) == .rejected)
        #expect(playlistSource.boundary.totalCount == 0)
        #expect(shioriStore.tableRowStore.snapshot.totalRowCount == 1)
        #expect(playlistWindow.retainedItemCount == 0)
        #expect(shioriWindow.retainedItemCount == 0)
        #expect(app.search === searchStore)
        #expect(session.searchStore == nil)
        #expect(recentStore.status == .idle)
        #expect(recentStore.items.isEmpty)
        #expect(!recentStore.hasActiveLoadTask)
        #expect(libraryStore.folderStatus == .idle)
        #expect(libraryStore.detailStatus == .idle)
        #expect(libraryStore.folders.isEmpty)
        #expect(libraryStore.detail == nil)
        #expect(!libraryStore.hasActiveFolderLoadTask)
        #expect(!libraryStore.hasActiveDetailLoadTask)
        #expect(app.playbackSubtitleFocusInitialLoadTask == nil)
        #expect(app.playbackSubtitleFocusCompleteLoadTask == nil)
    }
}

@MainActor
@Test
func playbackMultiModuleOverlayStopCancelsCurrentCompleteAndLibraryFolderLoads() async throws {
    try await withPlaybackMultiModuleFixture { fixture in
        let suiteName = "CueSeekerPlaybackMultiModuleRootStopTests-\(UUID().uuidString)"
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }
        _ = NSApplication.shared
        let app = AppCoordinator(
            userDefaults: userDefaults,
            databaseURL: fixture.databaseURL
        )
        await app.startupDatabaseTask?.value

        let probe = PlaybackMultiModuleCancellationProbe()
        let libraryStore = PlaybackLibrarySessionStore(
            loader: PlaybackLibraryLoader(
                loadFolders: {
                    await probe.suspend(.libraryFolders)
                    return fixture.folders
                },
                loadFolderDetail: { _ in
                    Issue.record("Folder cancellation must not enter Library Detail")
                    return fixture.detail
                }
            ),
            isVideoAvailable: { _ in true }
        )
        let session = try #require(app.playback.beginSubtitleFocusSession(
            openSnapshot: playbackMultiModuleOpenSnapshot(fixture),
            availableModules: [.current, .library],
            libraryStore: libraryStore
        ))
        app.startPlaybackSubtitleFocusInitialLoad(
            for: session,
            initialSnapshotLoader: { _, _ in
                SubtitleFocusSnapshot(
                    totalCount: 20,
                    selectedOrdinal: 12,
                    cues: (6..<16).map(playbackMultiModuleCue)
                )
            },
            completeCueBatchLoader: { _, totalCount in
                await probe.suspend(.currentComplete)
                return SubtitleFocusCueBatch(
                    totalCount: totalCount,
                    cues: (0..<totalCount).map(playbackMultiModuleCue)
                )
            }
        )
        libraryStore.activate()
        let expectedOperations: Set<PlaybackMultiModuleCancellationOperation> = [
            .currentComplete,
            .libraryFolders,
        ]
        try await waitForPlaybackMultiModuleCondition {
            probe.started == expectedOperations
        }

        app.stopPlayback()
        try await waitForPlaybackMultiModuleCondition {
            probe.cancelled == expectedOperations
        }
        try await Task.sleep(for: .milliseconds(20))

        #expect(app.playback.subtitleFocusSession == nil)
        #expect(!session.isActive)
        #expect(session.state == .closed)
        #expect(session.currentSnapshot == nil)
        #expect(app.playbackSubtitleFocusInitialLoadTask == nil)
        #expect(app.playbackSubtitleFocusCompleteLoadTask == nil)
        #expect(libraryStore.folderStatus == .idle)
        #expect(libraryStore.folders.isEmpty)
        #expect(!libraryStore.hasActiveFolderLoadTask)
        #expect(libraryStore.detail == nil)
    }
}

private struct PlaybackMultiModuleFixture {
    let databaseURL: URL
    let root: URL
    let videos: [URL]
    let subtitles: [URL]
    let searchResults: [SubtitleSearchResult]
    let recentItems: [RecentLibraryWatchingPresentation]
    let folders: [CompleteLibraryFolderSummaryPresentation]
    let detail: CompleteLibraryFolderDetailPresentation
    let shiori: Shiori
}

@MainActor
private func withPlaybackMultiModuleFixture(
    _ body: @MainActor (PlaybackMultiModuleFixture) async throws -> Void
) async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
        "CueSeekerPlaybackMultiModuleTests-\(UUID().uuidString)",
        isDirectory: true
    )
    let databaseURL = directory.appendingPathComponent("overlay.sqlite")
    let root = directory.appendingPathComponent("Media", isDirectory: true)
    let show = root.appendingPathComponent("A Overlay Show", isDirectory: true)
    let recentExtra = root.appendingPathComponent(
        "Z Recent Extra",
        isDirectory: true
    )
    defer {
        try? FileManager.default.removeItem(at: directory)
    }
    try FileManager.default.createDirectory(
        at: show,
        withIntermediateDirectories: true
    )
    try FileManager.default.createDirectory(
        at: recentExtra,
        withIntermediateDirectories: true
    )

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()
    var videos: [URL] = []
    var subtitles: [URL] = []
    var searchResults: [SubtitleSearchResult] = []
    for index in 0..<4 {
        let number = index + 1
        let folder = index < 3 ? show : recentExtra
        let content = index < 3
            ? "overlay integration \(number)"
            : "recent auxiliary"
        let video = folder.appendingPathComponent("Episode \(number).mkv")
        let subtitle = folder.appendingPathComponent("Episode \(number).srt")
        try Data().write(to: video)
        try Data(
            "1\n00:00:01,000 --> 00:00:02,000\n\(content)\n".utf8
        ).write(to: subtitle)
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
                    text: content
                )
            ]
        )
        try database.upsertLibraryPlaybackHistory(
            videoFile: video,
            positionMilliseconds: number * 1_000,
            duration: 100
        )
        videos.append(video)
        subtitles.append(subtitle)
        if index < 3 {
            searchResults.append(SubtitleSearchResult(
                entryID: Int64(10_000 + number),
                cueGroupID: Int64(20_000 + number),
                cueEventIndex: index,
                cueDisplayOrder: 0,
                primaryGroupIndex: 1,
                subtitlePath: subtitle.path,
                subtitleFormat: .srt,
                videoPath: video.path,
                videoName: video.lastPathComponent,
                startMilliseconds: 1_000,
                endMilliseconds: 2_000,
                content: content,
                cueLines: [content],
                cueGroupLines: ["context \(number)", content],
                searchRank: index
            ))
        }
    }
    try database.rebuildLibraryPresentationSnapshot()

    let selection = try #require(try database.cueTextSelection(
        forSubtitleFile: subtitles[0],
        atMilliseconds: 1_500
    ))
    let shiori = try database.upsertShiori(
        subtitleFile: subtitles[0],
        subtitleFormat: .srt,
        videoFile: videos[0],
        videoName: videos[0].lastPathComponent,
        selection: selection
    )
    let recentItems = try database.recentLibraryWatching(
        under: [root],
        limit: Int.max
    )
    let folders = try database.completeLibraryFolderSummaries(under: [root])
    let folder = try #require(folders.first)
    let detail = try #require(try database.completeLibraryFolderDetail(
        folderPath: folder.folderPath
    ))

    try await body(PlaybackMultiModuleFixture(
        databaseURL: databaseURL,
        root: root,
        videos: videos,
        subtitles: subtitles,
        searchResults: searchResults,
        recentItems: recentItems,
        folders: folders,
        detail: detail,
        shiori: shiori
    ))
}

@MainActor
private func playbackMultiModuleSearchStore(
    _: PlaybackMultiModuleFixture
) -> SearchStore {
    SearchStore()
}

@MainActor
private func playbackMultiModuleShioriStore(_ shiori: Shiori) -> ShioriStore {
    let store = ShioriStore()
    store.tableRowStore.updateShioriRows(
        [TableSandboxShioriRowSource(
            shiori: shiori,
            displayTitle: shiori.videoName,
            dateAddedText: shiori.createdAt,
            languages: [.unknown],
            shioriTags: []
        )],
        tableName: "shiori"
    )
    store.installTableResultShioriIDs([shiori.id])
    store.markTableRowsLoaded(totalSavedRowCount: 1)
    return store
}

@MainActor
private func playbackMultiModuleLibraryStore(
    _ fixture: PlaybackMultiModuleFixture
) -> PlaybackLibrarySessionStore {
    PlaybackLibrarySessionStore(
        loader: PlaybackLibraryLoader(
            loadFolders: { fixture.folders },
            loadFolderDetail: { folderPath in
                folderPath == fixture.detail.folderPath ? fixture.detail : nil
            }
        ),
        isVideoAvailable: { _ in true }
    )
}

@MainActor
private func playbackMultiModuleSource(
    kind: PlaybackPlaylistSourceKind,
    items: [PlaybackCueResultItem]
) -> PlaybackCueResultSource {
    PlaybackCueResultSource(
        kind: kind,
        totalCount: items.count,
        knownItemIDsByOrdinal: Dictionary(
            uniqueKeysWithValues: items.map { ($0.ordinal, $0.identity) }
        )
    ) { request in
        guard request.ordinalRange.upperBound <= items.count else {
            return nil
        }
        return PlaybackCueResultSourceWindowResponse(
            request: request,
            items: Array(items[request.ordinalRange])
        )
    }
}

@MainActor
private func playbackMultiModuleSuspendingSource(
    kind: PlaybackPlaylistSourceKind,
    items: [PlaybackCueResultItem],
    operation: PlaybackMultiModuleCancellationOperation,
    probe: PlaybackMultiModuleCancellationProbe
) -> PlaybackCueResultSource {
    PlaybackCueResultSource(
        kind: kind,
        totalCount: items.count,
        knownItemIDsByOrdinal: Dictionary(
            uniqueKeysWithValues: items.map { ($0.ordinal, $0.identity) }
        )
    ) { request in
        await probe.suspend(operation)
        guard request.ordinalRange.upperBound <= items.count else {
            return nil
        }
        return PlaybackCueResultSourceWindowResponse(
            request: request,
            items: Array(items[request.ordinalRange])
        )
    }
}

private enum PlaybackMultiModuleCancellationOperation: Hashable {
    case currentInitial
    case currentComplete
    case playlist
    case search
    case recent
    case libraryFolders
    case libraryDetail
    case shiori
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

private func playbackMultiModuleOpenSnapshot(
    _ fixture: PlaybackMultiModuleFixture
) -> PlaybackSubtitleFocusOpenSnapshot {
    PlaybackSubtitleFocusOpenSnapshot(
        source: SubtitleFocusSourceIdentity(
            videoPath: fixture.videos[0].path,
            subtitlePath: fixture.subtitles[0].path,
            subtitleFormat: .srt
        ),
        timestampMilliseconds: 1_500,
        wasPlaying: false
    )
}

private func playbackMultiModuleCurrentSnapshot() -> SubtitleFocusSnapshot {
    let cues = [
        playbackMultiModuleCue(ordinal: 0),
        playbackMultiModuleCue(ordinal: 1),
        playbackMultiModuleCue(ordinal: 2),
    ]
    return SubtitleFocusSnapshot(
        totalCount: 3,
        selectedOrdinal: 1,
        cues: cues
    )
}

private func playbackMultiModuleCue(ordinal: Int) -> SubtitleFocusCue {
    let id = Int64(ordinal + 1)
    let cueGroupID = Int64(ordinal + 101)
    let startMilliseconds = ordinal * 1_000
    return SubtitleFocusCue(
        id: id,
        cueGroupID: cueGroupID,
        ordinal: ordinal,
        eventIndex: ordinal,
        displayOrder: 0,
        startMilliseconds: startMilliseconds,
        endMilliseconds: startMilliseconds + 900,
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
