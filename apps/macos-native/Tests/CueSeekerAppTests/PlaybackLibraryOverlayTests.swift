import AppKit
@testable import CueSeekerCore
import CueSeekerPlayback
import Foundation
import SwiftUI
import Testing
@testable import CueSeekerApp

@MainActor
@Test
func playbackLibraryUsesOnlyTheCurrentFolderEpisodes() throws {
    let fixture = playbackLibraryFixture(folderEpisodeCounts: [2, 3])
    let library = playbackLibraryStore(fixture)
    let folder = fixture.folders[1]
    let detail = try #require(
        fixture.detailsByFolderPath[folder.folderPath]
    )
    let store = PlaybackLibrarySessionStore(
        libraryStore: library,
        folderPath: folder.folderPath,
        isVideoAvailable: { _ in true }
    )

    store.activate()
    #expect(store.libraryStore === library)
    #expect(store.folderPath == folder.folderPath)
    #expect(store.detail == detail)
    #expect(store.selection.orderedItemIDs == detail.videos.map(\.id))
    #expect(store.selection.selectedItemID == detail.videos[0].id)
}

@MainActor
@Test
func playbackLibraryAsyncDetailStillSelectsTheCurrentVideo() throws {
    let fixture = playbackLibraryFixture(folderEpisodeCounts: [3])
    let library = LibraryStore()
    let folderPath = fixture.folders[0].folderPath
    let detail = try #require(fixture.detailsByFolderPath[folderPath])
    let currentVideo = detail.videos[2]
    let store = PlaybackLibrarySessionStore(
        libraryStore: library,
        folderPath: folderPath,
        initialVideoPath: currentVideo.videoPath,
        requestFolderDetail: { requestedFolderPath in
            library.completeLibraryFolderDetailsByPath[requestedFolderPath]
                = detail
        },
        isVideoAvailable: { _ in true }
    )

    store.activate()

    #expect(store.detail == detail)
    #expect(store.selection.selectedItemID == currentVideo.id)
}

@MainActor
@Test
func playbackLibraryModuleSwitchPreservesSessionButDismissalKeepsWorkbenchData() throws {
    let fixture = playbackLibraryFixture(folderEpisodeCounts: [3])
    let library = playbackLibraryStore(fixture)
    let folderPath = fixture.folders[0].folderPath
    let detail = try #require(fixture.detailsByFolderPath[folderPath])
    let initialVideo = detail.videos[1]
    let store = PlaybackLibrarySessionStore(
        libraryStore: library,
        folderPath: folderPath,
        initialVideoPath: initialVideo.videoPath,
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
    #expect(store.selection.selectedItemID == initialVideo.id)
    #expect(store.selection.move(.down))
    store.selection.recordScrollOffsetY(88.75)
    let selectedEpisodeID = store.selection.selectedItemID

    #expect(session.selectModule(.search))
    #expect(session.selectModule(.library))
    #expect(store.selection.selectedItemID == selectedEpisodeID)
    #expect(store.selection.scrollOffsetY == 88.75)

    #expect(session.dismissByUser() == false)
    #expect(session.libraryStore == nil)
    #expect(store.selection.selectedItemID == nil)
    #expect(library.completeLibraryFolderSummaries == fixture.folders)
    #expect(library.completeLibraryFolderDetailsByPath == fixture.detailsByFolderPath)
}

@MainActor
@Test
func playbackLibrarySharedDetailRefreshPreservesEpisodeSelection() throws {
    let fixture = playbackLibraryFixture(folderEpisodeCounts: [3])
    let library = playbackLibraryStore(fixture)
    let folderPath = fixture.folders[0].folderPath
    let store = PlaybackLibrarySessionStore(
        libraryStore: library,
        folderPath: folderPath,
        isVideoAvailable: { _ in true }
    )
    store.activate()
    #expect(store.selection.move(.down))
    let selectedID = store.selection.selectedItemID
    store.selection.recordScrollOffsetY(88.75)
    let detail = try #require(fixture.detailsByFolderPath[folderPath])

    library.completeLibraryFolderDetailsByPath = [:]
    library.completeLibraryFolderDetailStatusesByPath[folderPath] = .loading
    library.completeLibraryFolderDetailsByPath[folderPath] = detail
    library.completeLibraryFolderDetailStatusesByPath[folderPath] = .completed

    #expect(store.detail == library.completeLibraryFolderDetailsByPath[folderPath])
    #expect(store.selection.selectedItemID == selectedID)
    #expect(store.selection.scrollOffsetY == 88.75)
}

@MainActor
@Test
func playbackLibrarySourceOpensAsTheMediaPlaylist() async throws {
    let fixture = playbackLibraryFixture(folderEpisodeCounts: [3])
    try await withPlaybackLibraryApp { app in
        app.library.completeLibraryFolderSummaries = fixture.folders
        app.library.completeLibraryFolderDetailsByPath =
            fixture.detailsByFolderPath
        let folder = fixture.folders[0]
        let video = try #require(
            fixture.detailsByFolderPath[folder.folderPath]?.videos[0]
        )
        app.library.selectedLibraryVideo = video.libraryVideo
        app.search.selectResult(nil)
        app.activePlaybackSource = .library(videoPath: video.videoPath)
        app.playbackReturnContext = .libraryFolderDetail(
            folderPath: folder.folderPath
        )
        app.ensurePlayerInitialized()
        let expectedVideos = fixture
            .detailsByFolderPath[folder.folderPath]?.videos

        #expect(app.openPlaybackSubtitleFocusFromUser())
        let session = try #require(app.playback.subtitleFocusSession)
        #expect(session.availableModules == [.current, .playlist])
        #expect(session.libraryStore?.libraryStore === app.library)
        #expect(session.libraryStore?.folderPath == folder.folderPath)
        #expect(session.libraryStore?.detail?.videos == expectedVideos)
        app.invalidatePlaybackSubtitleFocusForSourceReplacement()
    }
}

@MainActor
@Test
func playbackRecentEntryUsesTheCurrentFolderLibraryPlaylist() async throws {
    let fixture = playbackLibraryFixture(folderEpisodeCounts: [3])
    try await withPlaybackLibraryApp { app in
        app.library.completeLibraryFolderSummaries = fixture.folders
        app.library.completeLibraryFolderDetailsByPath =
            fixture.detailsByFolderPath
        let folder = fixture.folders[0]
        let video = try #require(
            fixture.detailsByFolderPath[folder.folderPath]?.videos[0]
        )
        app.library.selectedLibraryVideo = video.libraryVideo
        app.search.selectResult(nil)
        app.activePlaybackSource = .library(videoPath: video.videoPath)
        app.playbackReturnContext = .recent
        app.ensurePlayerInitialized()

        #expect(app.openPlaybackSubtitleFocusFromUser())
        let session = try #require(app.playback.subtitleFocusSession)
        #expect(session.availableModules == [.current, .playlist])
        #expect(session.libraryStore?.folderPath == folder.folderPath)
        #expect(
            session.libraryStore?.detail?.videos
                == fixture.detailsByFolderPath[folder.folderPath]?.videos
        )
        #expect(app.playbackReturnContext == .recent)
        app.invalidatePlaybackSubtitleFocusForSourceReplacement()
    }
}

@MainActor
@Test
func playbackPageProvidesPointerVisibilityToLibraryPlaylist() async throws {
    let fixture = playbackLibraryFixture(folderEpisodeCounts: [3])
    try await withPlaybackLibraryApp { app in
        app.library.completeLibraryFolderSummaries = fixture.folders
        app.library.completeLibraryFolderDetailsByPath =
            fixture.detailsByFolderPath
        let store = PlaybackLibrarySessionStore(
            libraryStore: app.library,
            folderPath: fixture.folders[0].folderPath,
            isVideoAvailable: { _ in true }
        )
        let session = try #require(app.playback.beginSubtitleFocusSession(
            openSnapshot: playbackLibraryOpenSnapshot(),
            libraryStore: store
        ))
        #expect(publishPlaybackOverlayInitialTestSnapshot(session))
        #expect(session.selectModule(.playlist))

        let hostingView = NSHostingView(
            rootView: PlaybackPageView(
                playbackSurface: AnyView(Color.black),
                appState: app,
                onClose: {}
            )
            .environmentObject(app)
            .environmentObject(app.playback)
            .environmentObject(app.workbenchLayout)
            .frame(width: 1_280, height: 720)
        )
        hostingView.frame = CGRect(x: 0, y: 0, width: 1_280, height: 720)
        let window = NSWindow(
            contentRect: hostingView.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = hostingView
        window.layoutIfNeeded()
        hostingView.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(100))
        window.layoutIfNeeded()
        hostingView.layoutSubtreeIfNeeded()

        #expect(app.playback.subtitleFocusSession === session)
        withExtendedLifetime((hostingView, window)) {}
        app.invalidatePlaybackSubtitleFocusForSourceReplacement()
    }
}

@MainActor
@Test
func playbackLibraryKeyboardRoutesTheCurrentFolderEpisodes() async throws {
    let fixture = playbackLibraryFixture(folderEpisodeCounts: [3])
    try await withPlaybackLibraryApp { app in
        let library = playbackLibraryStore(fixture)
        let folderPath = fixture.folders[0].folderPath
        let store = PlaybackLibrarySessionStore(
            libraryStore: library,
            folderPath: folderPath,
            isVideoAvailable: { _ in true }
        )
        let session = try #require(app.playback.beginSubtitleFocusSession(
            openSnapshot: playbackLibraryOpenSnapshot(),
            libraryStore: store
        ))
        #expect(publishPlaybackOverlayInitialTestSnapshot(session))
        #expect(session.selectModule(.playlist))

        #expect(app.handlePlaybackKeyDown(
            keyCode: 36,
            modifierFlagsRawValue: 0,
            isRepeat: true
        ))
        #expect(store.selection.selectedItemID == store.detail?.videos[0].id)

        #expect(app.handlePlaybackKeyDown(keyCode: 125, modifierFlagsRawValue: 0))
        #expect(store.selection.selectedItemID == store.detail?.videos[1].id)
        let selectedEpisodeID = store.selection.selectedItemID
        #expect(!app.handlePlaybackKeyDown(
            keyCode: 125,
            modifierFlagsRawValue: NSEvent.ModifierFlags.command.rawValue
        ))
        #expect(store.selection.selectedItemID == selectedEpisodeID)

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
        let folder = fixture.folders[0]
        let store = PlaybackLibrarySessionStore(
            libraryStore: library,
            folderPath: folder.folderPath,
            isVideoAvailable: { _ in true }
        )
        let session = try #require(app.playback.beginSubtitleFocusSession(
            openSnapshot: playbackLibraryOpenSnapshot(),
            libraryStore: store
        ))
        #expect(publishPlaybackOverlayInitialTestSnapshot(session))
        #expect(session.selectModule(.playlist))
        let detail = try #require(store.detail)
        let clickedVideo = detail.videos[1]
        app.playback.isPlaybackSurfaceExpanded = true
        app.playbackReturnContext = .recent

        #expect(app.openPlaybackLibraryEpisodeFromOverlay(clickedVideo))
        await Task.yield()
        #expect(app.playback.subtitleFocusSession == nil)
        #expect(app.library.selectedLibraryVideo?.videoPath == clickedVideo.videoPath)
        #expect(app.playbackReturnContext == .recent)
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
        videoFileID: Int64(folderIndex * 100 + episodeNumber),
        subtitleFileID: Int64(folderIndex * 100 + episodeNumber + 10_000),
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
    app.search.selectResult(SubtitleSearchResult(
        entryID: 1,
        subtitlePath: source.subtitlePath,
        subtitleFormat: source.subtitleFormat,
        videoPath: source.videoPath,
        videoName: "Playback Library Source",
        startMilliseconds: 1_000,
        endMilliseconds: 2_000,
        content: "source",
        cueLines: ["source"]
    ))
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
