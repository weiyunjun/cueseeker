import AppKit
import CueSeekerCore
import CueSeekerPlayback
import Foundation
import Testing
@testable import CueSeekerApp

@MainActor
@Test
func playbackLibraryLiveLoaderMatchesWorkbenchSummaryAndDetailOrder() async throws {
    try await withPlaybackLibraryFixture(folderEpisodeCounts: [2, 3]) { fixture in
        let loader = PlaybackLibraryLoader.live(
            databaseURL: fixture.databaseURL,
            folders: [fixture.root]
        )

        let folders = try await loader.loadFolders()
        #expect(folders == fixture.folders)
        #expect(folders.map(\.episodeCount) == [2, 3])

        for folder in folders {
            let detail = try await loader.loadFolderDetail(folder.folderPath)
            #expect(detail == fixture.detailsByFolderPath[folder.folderPath])
            #expect(detail?.videos.map(\.episodeNumber) == Array(1...folder.episodeCount))
        }
    }
}

@MainActor
@Test
func playbackLibraryDefaultsEachLevelAndBackRestoresFolderState() async throws {
    try await withPlaybackLibraryFixture(folderEpisodeCounts: [2, 3]) { fixture in
        let store = makePlaybackLibraryStore(fixture)
        store.activate()
        try await waitForPlaybackLibraryCondition {
            store.folderStatus == .completed
        }

        #expect(store.folderSelection.selectedItemID == fixture.folders[0].id)
        store.folderSelection.updateColumnCount(2)
        #expect(store.folderSelection.move(.right))
        let selectedFolderID = try #require(store.folderSelection.selectedItemID)
        #expect(selectedFolderID == fixture.folders[1].id)
        store.folderSelection.recordScrollOffsetY(123.5)

        #expect(store.enterFolder())
        try await waitForPlaybackLibraryCondition {
            store.detailStatus == .completed
        }
        let firstEpisodeSelection = try #require(store.episodeSelection)
        let detail = try #require(store.detail)
        #expect(firstEpisodeSelection.selectedItemID == detail.videos[0].id)
        #expect(firstEpisodeSelection.move(.down))
        firstEpisodeSelection.recordScrollOffsetY(76.25)

        #expect(store.returnToFolders())
        #expect(store.level == .folders)
        #expect(store.folderSelection.selectedItemID == selectedFolderID)
        #expect(store.folderSelection.scrollOffsetY == 123.5)
        #expect(store.detail == nil)
        #expect(store.detailStatus == .idle)
        #expect(store.episodeSelection == nil)

        #expect(store.enterFolder())
        try await waitForPlaybackLibraryCondition {
            store.detailStatus == .completed
        }
        let secondEpisodeSelection = try #require(store.episodeSelection)
        #expect(secondEpisodeSelection !== firstEpisodeSelection)
        #expect(secondEpisodeSelection.selectedItemID == store.detail?.videos[0].id)
        #expect(secondEpisodeSelection.scrollOffsetY == 0)
    }
}

@MainActor
@Test
func playbackLibraryModuleSwitchPreservesHierarchyAndDismissalClearsIt() async throws {
    try await withPlaybackLibraryFixture(folderEpisodeCounts: [3]) { fixture in
        let probe = PlaybackLibraryImmediateLoadProbe(fixture: fixture)
        let revision = PlaybackLibraryRevisionProbe()
        let libraryStore = PlaybackLibrarySessionStore(
            loader: probe.loader,
            isVideoAvailable: { _ in true },
            sourceRevision: { revision.value }
        )
        let session = PlaybackSubtitleFocusSessionStore(
            openSnapshot: playbackLibraryOpenSnapshot(),
            sessionGeneration: 1,
            libraryStore: libraryStore
        )

        #expect(publishPlaybackOverlayInitialTestSnapshot(session))
        #expect(session.selectModule(.library))
        try await waitForPlaybackLibraryCondition {
            libraryStore.folderStatus == .completed
        }
        libraryStore.folderSelection.recordScrollOffsetY(44.5)
        #expect(libraryStore.enterFolder())
        try await waitForPlaybackLibraryCondition {
            libraryStore.detailStatus == .completed
        }
        let episodeSelection = try #require(libraryStore.episodeSelection)
        #expect(episodeSelection.move(.down))
        episodeSelection.recordScrollOffsetY(88.75)
        let selectedEpisodeID = episodeSelection.selectedItemID

        revision.value = PlaybackLibrarySourceRevision(
            folders: 0,
            playbackHistory: 1
        )
        libraryStore.refreshForSourceRevision()
        try await waitForPlaybackLibraryCondition {
            libraryStore.detailStatus == .completed
                && probe.detailLoadCount == 2
        }
        #expect(libraryStore.episodeSelection?.selectedItemID == selectedEpisodeID)
        #expect(libraryStore.episodeSelection?.scrollOffsetY == 88.75)

        #expect(session.selectModule(.search))
        #expect(session.selectModule(.library))
        #expect(probe.folderLoadCount == 1)
        #expect(probe.detailLoadCount == 2)
        #expect(libraryStore.level != .folders)
        #expect(libraryStore.folderSelection.scrollOffsetY == 44.5)
        #expect(libraryStore.episodeSelection?.selectedItemID == selectedEpisodeID)
        #expect(libraryStore.episodeSelection?.scrollOffsetY == 88.75)

        #expect(session.dismissByUser() == false)
        #expect(session.libraryStore == nil)
        #expect(libraryStore.folderStatus == .idle)
        #expect(libraryStore.folders.isEmpty)
        #expect(libraryStore.folderSelection.selectedItemID == nil)
        #expect(libraryStore.folderSelection.scrollOffsetY == 0)
        #expect(libraryStore.detail == nil)
        #expect(libraryStore.episodeSelection == nil)
        #expect(!libraryStore.hasActiveFolderLoadTask)
        #expect(!libraryStore.hasActiveDetailLoadTask)
    }
}

@MainActor
@Test
func playbackLibraryRejectsStaleDetailSuccessFailureAndDismissal() async throws {
    try await withPlaybackLibraryFixture(folderEpisodeCounts: [2, 2]) { fixture in
        let probe = PlaybackLibraryDetailLoadProbe(fixture: fixture)
        let store = PlaybackLibrarySessionStore(
            loader: probe.loader,
            isVideoAvailable: { _ in true }
        )
        store.activate()
        try await waitForPlaybackLibraryCondition {
            store.folderStatus == .completed
        }

        let firstFolder = fixture.folders[0]
        let secondFolder = fixture.folders[1]
        #expect(store.enterFolder(itemID: firstFolder.id))
        try await waitForPlaybackLibraryCondition { probe.detailRequestCount == 1 }
        #expect(store.returnToFolders())
        #expect(store.enterFolder(itemID: secondFolder.id))
        try await waitForPlaybackLibraryCondition { probe.detailRequestCount == 2 }
        #expect(probe.completeDetailRequest(
            2,
            with: .success(fixture.detailsByFolderPath[secondFolder.folderPath])
        ))
        try await waitForPlaybackLibraryCondition {
            store.detailStatus == .completed
        }
        #expect(store.folderSelection.selectedItemID == firstFolder.id)
        #expect(probe.completeDetailRequest(
            1,
            with: .success(fixture.detailsByFolderPath[firstFolder.folderPath])
        ))
        try await Task.sleep(for: .milliseconds(10))
        #expect(store.detail?.folderPath == secondFolder.folderPath)
        #expect(store.folderSelection.selectedItemID == firstFolder.id)

        #expect(store.returnToFolders())
        #expect(store.enterFolder(itemID: firstFolder.id))
        try await waitForPlaybackLibraryCondition { probe.detailRequestCount == 3 }
        #expect(store.returnToFolders())
        #expect(store.enterFolder(itemID: secondFolder.id))
        try await waitForPlaybackLibraryCondition { probe.detailRequestCount == 4 }
        #expect(probe.completeDetailRequest(
            4,
            with: .success(fixture.detailsByFolderPath[secondFolder.folderPath])
        ))
        try await waitForPlaybackLibraryCondition {
            store.detailStatus == .completed
        }
        #expect(probe.completeDetailRequest(
            3,
            with: .failure(PlaybackLibraryProbeError())
        ))
        try await Task.sleep(for: .milliseconds(10))
        #expect(store.detail?.folderPath == secondFolder.folderPath)
        #expect(store.detailStatus == .completed)

        #expect(store.returnToFolders())
        #expect(store.enterFolder(itemID: firstFolder.id))
        try await waitForPlaybackLibraryCondition { probe.detailRequestCount == 5 }
        store.invalidate()
        #expect(probe.completeDetailRequest(
            5,
            with: .success(fixture.detailsByFolderPath[firstFolder.folderPath])
        ))
        try await Task.sleep(for: .milliseconds(10))
        #expect(store.level == .folders)
        #expect(store.detail == nil)
        #expect(store.episodeSelection == nil)
        #expect(store.folderStatus == .idle)
        #expect(store.folders.isEmpty)
    }
}

@MainActor
@Test
func playbackLibraryKeyboardRoutesBothLevelsAndConsumesRepeat() async throws {
    try await withPlaybackLibraryFixture(folderEpisodeCounts: [3]) { fixture in
        try await withPlaybackLibraryApp(databaseURL: fixture.databaseURL) { app in
            let libraryStore = makePlaybackLibraryStore(fixture)
            let session = try #require(app.playback.beginSubtitleFocusSession(
                openSnapshot: playbackLibraryOpenSnapshot(),
                libraryStore: libraryStore
            ))
            #expect(publishPlaybackOverlayInitialTestSnapshot(session))
            #expect(session.selectModule(.library))
            try await waitForPlaybackLibraryCondition {
                libraryStore.folderStatus == .completed
            }

            #expect(app.handlePlaybackKeyDown(
                keyCode: 36,
                modifierFlagsRawValue: 0,
                isRepeat: true
            ))
            #expect(libraryStore.level == .folders)
            #expect(app.handlePlaybackKeyDown(keyCode: 36, modifierFlagsRawValue: 0))
            try await waitForPlaybackLibraryCondition {
                libraryStore.detailStatus == .completed
            }
            #expect(app.playback.subtitleFocusSession === session)

            let episodeSelection = try #require(libraryStore.episodeSelection)
            #expect(app.handlePlaybackKeyDown(keyCode: 125, modifierFlagsRawValue: 0))
            #expect(episodeSelection.selectedItemID == libraryStore.detail?.videos[1].id)
            let selectedEpisodeID = episodeSelection.selectedItemID
            #expect(!app.handlePlaybackKeyDown(
                keyCode: 125,
                modifierFlagsRawValue: NSEvent.ModifierFlags.command.rawValue
            ))
            #expect(episodeSelection.selectedItemID == selectedEpisodeID)

            #expect(app.handlePlaybackKeyDown(
                keyCode: 36,
                modifierFlagsRawValue: 0,
                isRepeat: true
            ))
            #expect(app.playback.subtitleFocusSession === session)
            #expect(libraryStore.detail != nil)
        }
    }
}

@MainActor
@Test
func playbackLibraryExplicitEpisodeOpenUsesCurrentFolderNavigation() async throws {
    try await withPlaybackLibraryFixture(folderEpisodeCounts: [3, 2]) { fixture in
        try await withPlaybackLibraryApp(databaseURL: fixture.databaseURL) { app in
            let libraryStore = makePlaybackLibraryStore(fixture)
            let session = try #require(app.playback.beginSubtitleFocusSession(
                openSnapshot: playbackLibraryOpenSnapshot(),
                libraryStore: libraryStore
            ))
            #expect(publishPlaybackOverlayInitialTestSnapshot(session))
            #expect(session.selectModule(.library))
            try await waitForPlaybackLibraryCondition {
                libraryStore.folderStatus == .completed
            }
            let folder = fixture.folders[0]
            #expect(libraryStore.enterFolder(itemID: folder.id))
            try await waitForPlaybackLibraryCondition {
                libraryStore.detailStatus == .completed
            }
            let detail = try #require(libraryStore.detail)
            let clickedVideo = detail.videos[1]
            #expect(libraryStore.episodeSelection?.selectedItemID != clickedVideo.id)

            #expect(app.openPlaybackLibraryEpisodeFromOverlay(clickedVideo))
            #expect(app.playback.subtitleFocusSession == nil)
            #expect(!session.isActive)
            #expect(app.library.selectedLibraryVideo?.videoPath == clickedVideo.videoPath)
            #expect(
                app.library.libraryPlaybackNavigationVideos.map(\.videoPath)
                    == detail.videos.map(\.videoPath)
            )
            #expect(
                app.libraryResumePositionMilliseconds(for: clickedVideo.libraryVideo)
                    == clickedVideo.positionMilliseconds
            )
            #expect(app.playback.chromeSnapshot.displayTitle == clickedVideo.displayTitle)
            #expect(!app.openPlaybackLibraryEpisodeFromOverlay(clickedVideo))

            try await waitForPlaybackLibraryCondition {
                app.playback.playbackStatus != .opening
            }
            app.stopPlayback()
            await app.libraryPlaybackHistoryTask?.value
            await app.recentWatchingTask?.value
            await app.testRecentWatchingTask?.value
        }
    }
}

private struct PlaybackLibraryFixture {
    let databaseURL: URL
    let root: URL
    let folders: [CompleteLibraryFolderSummaryPresentation]
    let detailsByFolderPath: [String: CompleteLibraryFolderDetailPresentation]
}

@MainActor
private func withPlaybackLibraryFixture(
    folderEpisodeCounts: [Int],
    _ body: @MainActor (PlaybackLibraryFixture) async throws -> Void
) async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
        "CueSeekerPlaybackLibraryTests-\(UUID().uuidString)",
        isDirectory: true
    )
    let databaseURL = directory.appendingPathComponent("library.sqlite")
    let root = directory.appendingPathComponent("Media", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: directory)
    }
    try FileManager.default.createDirectory(
        at: root,
        withIntermediateDirectories: true
    )

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()
    for (folderIndex, episodeCount) in folderEpisodeCounts.enumerated() {
        let folder = root.appendingPathComponent(
            "Show \(folderIndex + 1)",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: folder,
            withIntermediateDirectories: true
        )
        for episodeIndex in 0..<episodeCount {
            let episodeNumber = episodeIndex + 1
            let video = folder.appendingPathComponent("Episode \(episodeNumber).mkv")
            let subtitle = folder.appendingPathComponent("Episode \(episodeNumber).srt")
            try Data().write(to: video)
            try Data("1\n00:00:01,000 --> 00:00:02,000\nLibrary\n".utf8)
                .write(to: subtitle)
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
                        text: "library \(folderIndex) \(episodeIndex)"
                    )
                ]
            )
            try database.upsertLibraryPlaybackHistory(
                videoFile: video,
                positionMilliseconds: episodeNumber * 1_000,
                duration: 100
            )
        }
    }
    try database.rebuildLibraryPresentationSnapshot()

    let folders = try database.completeLibraryFolderSummaries(under: [root])
    var detailsByFolderPath: [String: CompleteLibraryFolderDetailPresentation]
        = [:]
    for folder in folders {
        if let detail = try database.completeLibraryFolderDetail(
            folderPath: folder.folderPath
        ) {
            detailsByFolderPath[folder.folderPath] = detail
        }
    }
    try await body(PlaybackLibraryFixture(
        databaseURL: databaseURL,
        root: root,
        folders: folders,
        detailsByFolderPath: detailsByFolderPath
    ))
}

@MainActor
private func makePlaybackLibraryStore(
    _ fixture: PlaybackLibraryFixture
) -> PlaybackLibrarySessionStore {
    PlaybackLibrarySessionStore(
        loader: PlaybackLibraryLoader(
            loadFolders: { fixture.folders },
            loadFolderDetail: { folderPath in
                fixture.detailsByFolderPath[folderPath]
            }
        )
    )
}

@MainActor
private final class PlaybackLibraryImmediateLoadProbe {
    private let fixture: PlaybackLibraryFixture
    private(set) var folderLoadCount = 0
    private(set) var detailLoadCount = 0

    init(fixture: PlaybackLibraryFixture) {
        self.fixture = fixture
    }

    var loader: PlaybackLibraryLoader {
        PlaybackLibraryLoader(
            loadFolders: { [weak self] in
                guard let self else {
                    return []
                }
                folderLoadCount += 1
                return fixture.folders
            },
            loadFolderDetail: { [weak self] folderPath in
                guard let self else {
                    return nil
                }
                detailLoadCount += 1
                return fixture.detailsByFolderPath[folderPath]
            }
        )
    }
}

private struct PlaybackLibraryProbeError: Error {}

@MainActor
private final class PlaybackLibraryRevisionProbe {
    var value = PlaybackLibrarySourceRevision(folders: 0, playbackHistory: 0)
}

@MainActor
private final class PlaybackLibraryDetailLoadProbe {
    private let fixture: PlaybackLibraryFixture
    private var continuations: [
        Int: CheckedContinuation<CompleteLibraryFolderDetailPresentation?, Error>
    ] = [:]
    private(set) var detailRequestCount = 0

    init(fixture: PlaybackLibraryFixture) {
        self.fixture = fixture
    }

    var loader: PlaybackLibraryLoader {
        PlaybackLibraryLoader(
            loadFolders: { [fixture] in fixture.folders },
            loadFolderDetail: { [weak self] _ in
                guard let self else {
                    return nil
                }
                detailRequestCount += 1
                let request = detailRequestCount
                return try await withCheckedThrowingContinuation { continuation in
                    continuations[request] = continuation
                }
            }
        )
    }

    @discardableResult
    func completeDetailRequest(
        _ request: Int,
        with result: Result<CompleteLibraryFolderDetailPresentation?, Error>
    ) -> Bool {
        guard let continuation = continuations.removeValue(forKey: request) else {
            return false
        }
        continuation.resume(with: result)
        return true
    }
}

@MainActor
private func withPlaybackLibraryApp(
    databaseURL: URL,
    _ body: @MainActor (AppCoordinator) async throws -> Void
) async throws {
    let suiteName = "CueSeekerPlaybackLibraryAppTests-\(UUID().uuidString)"
    let userDefaults = try #require(UserDefaults(suiteName: suiteName))
    defer {
        userDefaults.removePersistentDomain(forName: suiteName)
    }
    _ = NSApplication.shared
    let app = AppCoordinator(userDefaults: userDefaults, databaseURL: databaseURL)
    await app.startupDatabaseTask?.value
    configurePlaybackLibrarySource(app)
    try await body(app)
}

@MainActor
private func configurePlaybackLibrarySource(_ app: AppCoordinator) {
    let source = playbackLibraryOpenSnapshot().source
    app.search.selectedSearchResult = SubtitleSearchResult(
        entryID: 1,
        subtitlePath: source.subtitlePath,
        subtitleFormat: source.subtitleFormat,
        videoPath: source.videoPath,
        videoName: "Playback Library Source",
        startMilliseconds: 1_000,
        endMilliseconds: 2_000,
        content: "source",
        cueLines: ["source"]
    )
    app.playback.playbackViewModel = PlaybackViewModel(player: PlaybackPlayer())
    app.playback.playbackStatus = .paused
}

private func playbackLibraryOpenSnapshot() -> PlaybackSubtitleFocusOpenSnapshot {
    PlaybackSubtitleFocusOpenSnapshot(
        source: SubtitleFocusSourceIdentity(
            videoPath: "/Media/Playback-Library-Source.mkv",
            subtitlePath: "/Media/Playback-Library-Source.srt",
            subtitleFormat: .srt
        ),
        timestampMilliseconds: 1_500,
        wasPlaying: false
    )
}

@MainActor
private func waitForPlaybackLibraryCondition(
    _ condition: @escaping @MainActor () async -> Bool
) async throws {
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: .seconds(2))
    while !(await condition()) {
        guard clock.now < deadline else {
            Issue.record("Timed out waiting for Playback Library condition")
            return
        }
        try await Task.sleep(for: .milliseconds(5))
    }
}
