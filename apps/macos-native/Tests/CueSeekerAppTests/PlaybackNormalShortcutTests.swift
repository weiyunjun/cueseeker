import AppKit
import Carbon.HIToolbox
import Combine
import CueSeekerCore
import CueSeekerPlayback
import Foundation
import Testing
@testable import CueSeekerApp

@MainActor
@Test
func selectedTextCopyUsesRequiredPlaybackFeedback() {
    let viewModel = PlaybackViewModel(player: PlaybackPlayer())

    viewModel.showSelectedTextCopyFeedback(copied: true)

    #expect(viewModel.feedback?.text == "Selected Text Copied")
    #expect(viewModel.feedback?.icon == .copy)
}

@MainActor
@Test
func normalPlaybackQToggleSubtitlesWhileSAndCDoNothing() throws {
    try withNormalPlaybackApp { app, database in
        let shioriDatabase = try #require(app.shioriDatabase)
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
        #expect(try shioriDatabase.shioriCount() == 0)
    }
}

@MainActor
@Test
func normalPlaybackBarePCopiesScreenshotWhileShiftPDoesNothing() throws {
    try withNormalPlaybackApp { app, _ in
        let viewModel = try #require(app.playback.playbackViewModel)
        let initialPointerHideGeneration = app.playback.pointerHideRequestGeneration

        #expect(app.handlePlaybackKeyDown(keyCode: 35, modifierFlagsRawValue: 0))
        #expect(
            app.playback.pointerHideRequestGeneration
                == initialPointerHideGeneration + 1
        )
        #expect(viewModel.feedback == nil)

        #expect(app.handlePlaybackKeyDown(
            keyCode: 35,
            modifierFlagsRawValue: 0,
            isRepeat: true
        ))

        #expect(!app.handlePlaybackKeyDown(
            keyCode: 35,
            modifierFlagsRawValue: NSEvent.ModifierFlags.shift.rawValue
        ))
        #expect(
            app.playback.pointerHideRequestGeneration
                == initialPointerHideGeneration + 3
        )
    }
}

@MainActor
@Test
func timelineScrubbingConsumesBarePWithoutTakingScreenshot() throws {
    try withNormalPlaybackApp { app, _ in
        let viewModel = try #require(app.playback.playbackViewModel)
        app.playback.isTimelineScrubbing = true

        #expect(app.handlePlaybackKeyDown(keyCode: 35, modifierFlagsRawValue: 0))
        #expect(viewModel.feedback == nil)
    }
}

@MainActor
@Test
func screenshotCopiedFeedbackUsesRequiredIconAndText() {
    let viewModel = PlaybackViewModel(player: PlaybackPlayer())

    viewModel.showScreenshotCopiedFeedback()

    #expect(viewModel.feedback?.position == .center)
    #expect(viewModel.feedback?.icon == .system("photo"))
    #expect(viewModel.feedback?.text == "Screenshot Copied")
}

@MainActor
@Test
func repeatAndAutoPauseFeedbackUseRequiredIconsAndText() {
    let viewModel = PlaybackViewModel(player: PlaybackPlayer())

    viewModel.showRepeatFeedback()
    #expect(viewModel.feedback?.position == .center)
    #expect(viewModel.feedback?.icon == .system("repeat"))
    #expect(viewModel.feedback?.text == "Repeat")

    viewModel.showAutoPauseFeedback()
    #expect(viewModel.feedback?.position == .center)
    #expect(viewModel.feedback?.icon == .system("pause.fill"))
    #expect(viewModel.feedback?.text == "Auto Pause")
}

@MainActor
@Test
func normalPlaybackBareRAndTriangleConsumeUnavailableRepeatSilently() throws {
    try withNormalPlaybackApp { app, _ in
        let viewModel = try #require(app.playback.playbackViewModel)
        app.playback.isPlaybackSurfaceExpanded = true

        #expect(app.handlePlaybackKeyDown(
            keyCode: UInt16(kVK_ANSI_R),
            modifierFlagsRawValue: 0
        ))
        #expect(app.handlePlaybackKeyDown(
            keyCode: UInt16(kVK_ANSI_R),
            modifierFlagsRawValue: 0,
            isRepeat: true
        ))
        #expect(!app.handlePlaybackKeyDown(
            keyCode: UInt16(kVK_ANSI_R),
            modifierFlagsRawValue: NSEvent.ModifierFlags.shift.rawValue
        ))
        #expect(app.handlePlaybackControllerInput(.button(.north)))
        #expect(viewModel.feedback == nil)
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
    _ body: (AppCoordinator, IndexingDatabase) throws -> Void
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
    let database = try #require(app.indexingDatabase)
    app.search.selectResult(SubtitleSearchResult(
        entryID: 1,
        subtitlePath: "/Media/Normal-Playback.srt",
        subtitleFormat: .srt,
        videoPath: "/Media/Normal-Playback.mkv",
        videoName: "Normal Playback",
        startMilliseconds: 1_000,
        endMilliseconds: 2_000,
        content: "normal playback cue",
        cueLines: ["normal playback cue"]
    ))
    app.playback.playbackViewModel = PlaybackViewModel(player: PlaybackPlayer())
    app.playback.playbackStatus = .paused
    try body(app, database)
}

@MainActor
@Test
func openSpeedMenuOwnsArrowKeysInsteadOfVolume() throws {
    try withNormalPlaybackApp { app, _ in
        let viewModel = try #require(app.playback.playbackViewModel)
        let initialVolume = viewModel.volume
        #expect(viewModel.playbackSpeed == 1.0)

        // Arrow keys change the volume while no menu is open. Volume starts at
        // its maximum, so the down arrow is the one that can move it.
        #expect(app.handlePlaybackKeyDown(keyCode: 125, modifierFlagsRawValue: 0))
        #expect(viewModel.volume != initialVolume)
        let volumeBeforeMenu = viewModel.volume

        app.playback.openSpeedMenu(
            defaultPosition: PlaybackViewModel.speedPresetIndex(for: 1.0)
        )
        let highlight = app.playback.speedMenuHighlight
        #expect(highlight.highlightedPosition == 2)

        // With the menu open the same keys move its highlight and must not
        // touch the volume or the speed in effect.
        #expect(app.handlePlaybackKeyDown(keyCode: 125, modifierFlagsRawValue: 0))
        #expect(highlight.highlightedPosition == 3)
        #expect(app.handlePlaybackKeyDown(keyCode: 125, modifierFlagsRawValue: 0))
        #expect(highlight.highlightedPosition == 4)
        #expect(app.handlePlaybackKeyDown(keyCode: 126, modifierFlagsRawValue: 0))
        #expect(highlight.highlightedPosition == 3)
        #expect(viewModel.volume == volumeBeforeMenu)
        #expect(viewModel.playbackSpeed == 1.0)

        // Enter applies the highlighted preset and closes the menu.
        #expect(app.handlePlaybackKeyDown(keyCode: 36, modifierFlagsRawValue: 0))
        #expect(viewModel.playbackSpeed == 1.25)
        #expect(!app.playback.isSpeedMenuOpen)
        #expect(viewModel.volume == volumeBeforeMenu)

        // Volume responds again once the menu is closed.
        #expect(app.handlePlaybackKeyDown(keyCode: 125, modifierFlagsRawValue: 0))
        #expect(viewModel.volume != volumeBeforeMenu)
    }
}

@MainActor
@Test
func openSelectedTextMenuOwnsArrowKeysInsteadOfVolume() throws {
    try withNormalPlaybackApp { app, _ in
        let viewModel = try #require(app.playback.playbackViewModel)
        var seenKeyCodes: [UInt16] = []
        app.playback.selectedTextMenuKeyHandler = { keyCode in
            seenKeyCodes.append(keyCode)
            return [53, 125, 126, 36, 76].contains(keyCode)
        }
        let volumeBeforeMenu = viewModel.volume

        #expect(app.handlePlaybackKeyDown(keyCode: 125, modifierFlagsRawValue: 0))
        #expect(app.handlePlaybackKeyDown(keyCode: 126, modifierFlagsRawValue: 0))
        #expect(seenKeyCodes == [125, 126])
        #expect(viewModel.volume == volumeBeforeMenu)

        // A key the menu declines still reaches the playback shortcuts.
        #expect(app.handlePlaybackKeyDown(keyCode: 12, modifierFlagsRawValue: 0))
        #expect(seenKeyCodes == [125, 126, 12])

        app.playback.selectedTextMenuKeyHandler = nil
        #expect(app.handlePlaybackKeyDown(keyCode: 125, modifierFlagsRawValue: 0))
        #expect(viewModel.volume != volumeBeforeMenu)
    }
}

@MainActor
@Test
func openingCommandPanelFreezesTheMenusUnderneathIt() throws {
    try withNormalPlaybackApp { app, _ in
        app.playback.isPlaybackSurfaceExpanded = true
        var seenKeyCodes: [UInt16] = []
        app.playback.selectedTextMenuKeyHandler = { keyCode in
            seenKeyCodes.append(keyCode)
            return true
        }
        app.playback.openSpeedMenu(
            defaultPosition: PlaybackViewModel.speedPresetIndex(for: 1.0)
        )
        let highlight = app.playback.speedMenuHighlight
        #expect(app.playback.isSpeedMenuOpen)
        #expect(highlight.highlightedPosition == 2)

        #expect(app.handlePlaybackKeyDown(
            keyCode: UInt16(kVK_ANSI_K),
            modifierFlagsRawValue: 0
        ))

        // Both menus stay on screen. They belong to the surfaces below the
        // panel, so they keep their state and stop taking keys.
        #expect(app.playback.commandPanelPresentation != nil)
        #expect(app.playback.isSpeedMenuOpen)
        #expect(app.playback.selectedTextMenuKeyHandler != nil)
        #expect(seenKeyCodes.isEmpty)

        // The arrow keys reach the Command Panel instead of either menu.
        #expect(app.handlePlaybackKeyDown(keyCode: 125, modifierFlagsRawValue: 0))
        #expect(highlight.highlightedPosition == 2)
        #expect(seenKeyCodes.isEmpty)

        // Escape closes the panel and the speed menu answers the arrows again.
        #expect(app.handlePlaybackKeyDown(keyCode: 53, modifierFlagsRawValue: 0))
        #expect(app.playback.commandPanelPresentation == nil)
        #expect(app.playback.isSpeedMenuOpen)
        #expect(app.handlePlaybackKeyDown(keyCode: 125, modifierFlagsRawValue: 0))
        #expect(highlight.highlightedPosition == 3)
    }
}

@MainActor
@Test
func openCommandPanelTakesWheelAndScrollbarFromThePlaybackOverlay() throws {
    try withNormalPlaybackApp { app, _ in
        app.playback.isPlaybackSurfaceExpanded = true
        let session = try #require(app.playback.beginSubtitleFocusSession(
            openSnapshot: PlaybackSubtitleFocusOpenSnapshot(
                source: SubtitleFocusSourceIdentity(
                    videoPath: "/Media/Normal-Playback.mkv",
                    subtitlePath: "/Media/Normal-Playback.srt",
                    subtitleFormat: .srt
                ),
                timestampMilliseconds: 1_000,
                wasPlaying: false
            )
        ))
        #expect(session.allowsNativeWheelInput())

        #expect(app.handlePlaybackKeyDown(
            keyCode: UInt16(kVK_ANSI_K),
            modifierFlagsRawValue: 0
        ))
        #expect(!session.allowsNativeWheelInput())
        #expect(!session.allowsNativeScrollbarInput())

        #expect(app.handlePlaybackKeyDown(keyCode: 53, modifierFlagsRawValue: 0))
        #expect(session.allowsNativeWheelInput())
    }
}
