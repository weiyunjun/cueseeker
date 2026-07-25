import AppKit
@testable import CueSeekerCore
import CueSeekerPlayback
import Foundation
import Testing
@testable import CueSeekerApp

@MainActor
@Test
func playbackLibraryUsesWorkbenchStoreAndKeepsHierarchySessionLocal() throws {
    let fixture = playbackLibraryFixture(folderEpisodeCounts: [2, 3])
    let library = playbackLibraryStore(fixture)
    let store = PlaybackLibrarySessionStore(
        libraryStore: library,
        isVideoAvailable: { _ in true }
    )

    store.activate()
    #expect(store.libraryStore === library)
    #expect(store.folders == library.completeLibraryFolderSummaries)
    #expect(store.folderSelection.selectedItemID == fixture.folders[0].id)

    store.folderSelection.updateColumnCount(2)
    #expect(store.folderSelection.move(.right))
    let selectedFolderID = try #require(store.folderSelection.selectedItemID)
    store.folderSelection.recordScrollOffsetY(123.5)

    #expect(store.enterFolder())
    let firstEpisodeSelection = try #require(store.episodeSelection)
    let detail = try #require(store.detail)
    #expect(firstEpisodeSelection.selectedItemID == detail.videos[0].id)
    #expect(firstEpisodeSelection.move(.down))
    firstEpisodeSelection.recordScrollOffsetY(76.25)

    #expect(store.returnToFolders())
    #expect(store.level == .folders)
    #expect(store.folderSelection.selectedItemID == selectedFolderID)
    #expect(store.folderSelection.scrollOffsetY == 123.5)
    #expect(store.episodeSelection == nil)

    #expect(store.enterFolder())
    let secondEpisodeSelection = try #require(store.episodeSelection)
    #expect(secondEpisodeSelection !== firstEpisodeSelection)
    #expect(secondEpisodeSelection.selectedItemID == detail.videos[0].id)
    #expect(secondEpisodeSelection.scrollOffsetY == 0)
}

@MainActor
@Test
func playbackLibraryModuleSwitchPreservesSessionButDismissalKeepsWorkbenchData() throws {
    let fixture = playbackLibraryFixture(folderEpisodeCounts: [3])
    let library = playbackLibraryStore(fixture)
    let store = PlaybackLibrarySessionStore(
        libraryStore: library,
        isVideoAvailable: { _ in true }
    )
    let session = PlaybackSubtitleFocusSessionStore(
        openSnapshot: playbackLibraryOpenSnapshot(),
        sessionGeneration: 1,
        availableModules: PlaybackOverlayModule.allCases,
        libraryStore: store
    )

    #expect(publishPlaybackOverlayInitialTestSnapshot(session))
    #expect(session.selectModule(.library))
    store.folderSelection.recordScrollOffsetY(44.5)
    #expect(store.enterFolder())
    let episodeSelection = try #require(store.episodeSelection)
    #expect(episodeSelection.move(.down))
    episodeSelection.recordScrollOffsetY(88.75)
    let selectedEpisodeID = episodeSelection.selectedItemID

    #expect(session.selectModule(.search))
    #expect(session.selectModule(.library))
    #expect(store.level != .folders)
    #expect(store.folderSelection.scrollOffsetY == 44.5)
    #expect(store.episodeSelection?.selectedItemID == selectedEpisodeID)
    #expect(store.episodeSelection?.scrollOffsetY == 88.75)

    #expect(session.dismissByUser() == false)
    #expect(session.libraryStore == nil)
    #expect(store.level == .folders)
    #expect(store.folderSelection.selectedItemID == nil)
    #expect(store.episodeSelection == nil)
    #expect(library.completeLibraryFolderSummaries == fixture.folders)
    #expect(library.completeLibraryFolderDetailsByPath == fixture.detailsByFolderPath)
}

@MainActor
@Test
func playbackLibrarySharedDetailRefreshPreservesEpisodeSelection() throws {
    let fixture = playbackLibraryFixture(folderEpisodeCounts: [3])
    let library = playbackLibraryStore(fixture)
    let store = PlaybackLibrarySessionStore(
        libraryStore: library,
        isVideoAvailable: { _ in true }
    )
    store.activate()
    #expect(store.enterFolder())
    let selection = try #require(store.episodeSelection)
    #expect(selection.move(.down))
    let selectedID = selection.selectedItemID
    selection.recordScrollOffsetY(88.75)
    let folderPath = fixture.folders[0].folderPath
    let detail = try #require(fixture.detailsByFolderPath[folderPath])

    library.completeLibraryFolderDetailsByPath = [:]
    library.completeLibraryFolderDetailStatusesByPath[folderPath] = .loading
    library.completeLibraryFolderDetailsByPath[folderPath] = detail
    library.completeLibraryFolderDetailStatusesByPath[folderPath] = .completed

    #expect(store.detail == library.completeLibraryFolderDetailsByPath[folderPath])
    #expect(store.episodeSelection?.selectedItemID == selectedID)
    #expect(store.episodeSelection?.scrollOffsetY == 88.75)
}

@MainActor
@Test
func playbackLibraryKeyboardRoutesBothSharedLevels() async throws {
    let fixture = playbackLibraryFixture(folderEpisodeCounts: [3])
    try await withPlaybackLibraryApp { app in
        let library = playbackLibraryStore(fixture)
        let store = PlaybackLibrarySessionStore(
            libraryStore: library,
            isVideoAvailable: { _ in true }
        )
        let session = try #require(app.playback.beginSubtitleFocusSession(
            openSnapshot: playbackLibraryOpenSnapshot(),
            availableModules: PlaybackOverlayModule.allCases,
            libraryStore: store
        ))
        #expect(publishPlaybackOverlayInitialTestSnapshot(session))
        #expect(session.selectModule(.library))

        #expect(app.handlePlaybackKeyDown(
            keyCode: 36,
            modifierFlagsRawValue: 0,
            isRepeat: true
        ))
        #expect(store.level == .folders)
        #expect(app.handlePlaybackKeyDown(keyCode: 36, modifierFlagsRawValue: 0))
        #expect(store.level != .folders)

        let episodeSelection = try #require(store.episodeSelection)
        #expect(app.handlePlaybackKeyDown(keyCode: 125, modifierFlagsRawValue: 0))
        #expect(episodeSelection.selectedItemID == store.detail?.videos[1].id)
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
    }
}

@MainActor
@Test
func playbackLibraryEpisodeOpenUsesSharedFolderDetailOrder() async throws {
    let fixture = playbackLibraryFixture(folderEpisodeCounts: [3, 2])
    try await withPlaybackLibraryApp { app in
        let library = playbackLibraryStore(fixture)
        let store = PlaybackLibrarySessionStore(
            libraryStore: library,
            isVideoAvailable: { _ in true }
        )
        let session = try #require(app.playback.beginSubtitleFocusSession(
            openSnapshot: playbackLibraryOpenSnapshot(),
            availableModules: PlaybackOverlayModule.allCases,
            libraryStore: store
        ))
        #expect(publishPlaybackOverlayInitialTestSnapshot(session))
        #expect(session.selectModule(.library))
        let folder = fixture.folders[0]
        #expect(store.enterFolder(itemID: folder.id))
        let detail = try #require(store.detail)
        let clickedVideo = detail.videos[1]

        #expect(app.openPlaybackLibraryEpisodeFromOverlay(clickedVideo))
        #expect(app.playback.subtitleFocusSession == nil)
        #expect(app.library.selectedLibraryVideo?.videoPath == clickedVideo.videoPath)
        #expect(
            app.library.libraryPlaybackNavigationVideos.map(\.videoPath)
                == detail.videos.map(\.videoPath)
        )
        #expect(library.completeLibraryFolderDetailsByPath[folder.folderPath] == detail)
        app.stopPlayback()
    }
}

private struct PlaybackLibraryFixture {
    let folders: [CompleteLibraryFolderSummaryPresentation]
    let detailsByFolderPath: [String: CompleteLibraryFolderDetailPresentation]
}

private func playbackLibraryFixture(
    folderEpisodeCounts: [Int]
) -> PlaybackLibraryFixture {
    var folders: [CompleteLibraryFolderSummaryPresentation] = []
    var detailsByFolderPath: [String: CompleteLibraryFolderDetailPresentation]
        = [:]
    for (folderIndex, episodeCount) in folderEpisodeCounts.enumerated() {
        let folderPath = "/Media/Show-\(folderIndex)"
        let folderTitle = "Show \(folderIndex)"
        let folder = CompleteLibraryFolderSummaryPresentation(
            folderPath: folderPath,
            folderTitle: folderTitle,
            coverPath: nil,
            coverRevision: nil,
            episodeCount: episodeCount
        )
        let videos = (0..<episodeCount).map { episodeIndex in
            playbackLibraryVideo(
                folderIndex: folderIndex,
                episodeIndex: episodeIndex
            )
        }
        folders.append(folder)
        detailsByFolderPath[folderPath] = CompleteLibraryFolderDetailPresentation(
            folderPath: folderPath,
            folderTitle: folderTitle,
            videos: videos
        )
    }
    return PlaybackLibraryFixture(
        folders: folders,
        detailsByFolderPath: detailsByFolderPath
    )
}

private func playbackLibraryVideo(
    folderIndex: Int,
    episodeIndex: Int
) -> CompleteLibraryVideoPresentation {
    let episodeNumber = episodeIndex + 1
    return CompleteLibraryVideoPresentation(
        videoPath: "/Media/Show-\(folderIndex)/Episode-\(episodeNumber).mkv",
        videoName: "Episode-\(episodeNumber).mkv",
        fileSize: nil,
        videoCodec: nil,
        videoWidth: nil,
        videoHeight: nil,
        frameRate: nil,
        duration: 100,
        subtitlePath: "/Media/Show-\(folderIndex)/Episode-\(episodeNumber).srt",
        subtitleFormat: .srt,
        displayTitle: "Episode \(episodeNumber)",
        fileExtension: "mkv",
        episodeNumber: episodeNumber,
        positionMilliseconds: episodeNumber * 1_000,
        playbackDuration: 100,
        startedAt: "2026-07-16T00:00:00Z",
        completedAt: nil,
        historyUpdatedAt: "2026-07-16T00:00:00Z",
        coverPath: nil,
        coverRevision: nil
    )
}

@MainActor
private func playbackLibraryStore(
    _ fixture: PlaybackLibraryFixture
) -> LibraryStore {
    let library = LibraryStore()
    library.completeLibraryStatus = .completed
    library.completeLibraryFolderSummaries = fixture.folders
    library.completeLibraryFolderDetailsByPath = fixture.detailsByFolderPath
    library.completeLibraryFolderDetailStatusesByPath = Dictionary(
        uniqueKeysWithValues: fixture.folders.map {
            ($0.folderPath, LibraryStatus.completed)
        }
    )
    return library
}

@MainActor
private func withPlaybackLibraryApp(
    _ body: @MainActor (AppCoordinator) async throws -> Void
) async throws {
    let suiteName = "CueSeekerPlaybackLibraryAppTests-\(UUID().uuidString)"
    let userDefaults = try #require(UserDefaults(suiteName: suiteName))
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
        "CueSeekerPlaybackLibraryAppTests-\(UUID().uuidString)",
        isDirectory: true
    )
    let databaseURL = directory.appendingPathComponent("library.sqlite")
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
