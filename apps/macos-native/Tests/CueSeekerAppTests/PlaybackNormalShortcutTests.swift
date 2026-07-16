import AppKit
import Combine
import CueSeekerCore
import CueSeekerPlayback
import Foundation
import Testing
@testable import CueSeekerApp

@MainActor
@Test
func normalPlaybackQToggleSubtitlesWhileSAndCDoNothing() throws {
    try withNormalPlaybackApp { app, database in
        let viewModel = try #require(app.playback.playbackViewModel)

        #expect(viewModel.areSubtitlesVisible)
        let initialPointerHideGeneration = app.playback.pointerHideRequestGeneration
        #expect(app.handlePlaybackKeyDown(keyCode: 12, modifierFlagsRawValue: 0))
        #expect(
            app.playback.pointerHideRequestGeneration
                == initialPointerHideGeneration + 1
        )
        #expect(!viewModel.areSubtitlesVisible)
        #expect(viewModel.feedback?.text == "Subtitles Off")

        let feedbackAfterQ = viewModel.feedback
        #expect(!app.handlePlaybackKeyDown(keyCode: 1, modifierFlagsRawValue: 0))
        #expect(!app.handlePlaybackKeyDown(keyCode: 8, modifierFlagsRawValue: 0))
        #expect(
            app.playback.pointerHideRequestGeneration
                == initialPointerHideGeneration + 3
        )

        #expect(!viewModel.areSubtitlesVisible)
        #expect(viewModel.feedback == feedbackAfterQ)
        #expect(try database.shioriCount() == 0)
    }
}

@MainActor
@Test
func playbackPointerStartsHiddenAndOnlyMovementRestoresIt() {
    let model = PlaybackChromeVisibilityModel()
    let view = NSView()

    model.enterVideoPage()
    #expect(!model.isPointerVisible)

    model.pointerMovedInPlayerArea(view: view)
    #expect(model.isPointerVisible)

    model.keyboardInputReceived()
    #expect(!model.isPointerVisible)

    model.leaveVideoPage()
}

@MainActor
@Test
func playbackPointerHideRequestDoesNotInvalidatePlaybackStore() {
    let store = PlaybackStore(userDefaults: .standard)
    var playbackStoreInvalidations = 0
    var pointerHideRequests = 0
    let invalidationCancellable = store.objectWillChange.sink {
        playbackStoreInvalidations += 1
    }
    let requestCancellable = store.pointerHideRequests.sink {
        pointerHideRequests += 1
    }

    store.requestPointerHide()

    #expect(pointerHideRequests == 1)
    #expect(playbackStoreInvalidations == 0)
    withExtendedLifetime((invalidationCancellable, requestCancellable)) {}
}

@MainActor
private func withNormalPlaybackApp(
    _ body: (AppCoordinator, SubtitleDatabase) throws -> Void
) throws {
    let suiteName = "CueSeekerNormalPlaybackShortcutTests-\(UUID().uuidString)"
    let userDefaults = try #require(UserDefaults(suiteName: suiteName))
    let fixtureRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "CueSeekerNormalPlaybackShortcutTests-\(UUID().uuidString)",
            isDirectory: true
        )
    let databaseURL = fixtureRoot.appendingPathComponent("normal-shortcuts.sqlite")
    defer {
        userDefaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: fixtureRoot)
    }
    try FileManager.default.createDirectory(
        at: fixtureRoot,
        withIntermediateDirectories: true
    )

    _ = NSApplication.shared
    let app = AppCoordinator(userDefaults: userDefaults, databaseURL: databaseURL)
    let database = try #require(app.subtitleDatabase)
    app.search.selectedSearchResult = SubtitleSearchResult(
        entryID: 1,
        subtitlePath: "/Media/Normal-Playback.srt",
        subtitleFormat: .srt,
        videoPath: "/Media/Normal-Playback.mkv",
        videoName: "Normal Playback",
        startMilliseconds: 1_000,
        endMilliseconds: 2_000,
        content: "normal playback cue",
        cueLines: ["normal playback cue"]
    )
    app.playback.playbackViewModel = PlaybackViewModel(player: PlaybackPlayer())
    app.playback.playbackStatus = .paused
    try body(app, database)
}
