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
        // Keyboard input never hides the pointer.
        let initialPointerHideGeneration = app.playback.pointerHideRequestGeneration
        #expect(app.handlePlaybackKeyDown(keyCode: 12, modifierFlagsRawValue: 0))
        #expect(
            app.playback.pointerHideRequestGeneration
                == initialPointerHideGeneration
        )
        #expect(!viewModel.areSubtitlesVisible)
        #expect(viewModel.feedback?.text == "Subtitles Off")

        let feedbackAfterQ = viewModel.feedback
        #expect(!app.handlePlaybackKeyDown(keyCode: 1, modifierFlagsRawValue: 0))
        #expect(!app.handlePlaybackKeyDown(keyCode: 8, modifierFlagsRawValue: 0))
        #expect(
            app.playback.pointerHideRequestGeneration
                == initialPointerHideGeneration
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
        // Keyboard input never hides the pointer.
        #expect(
            app.playback.pointerHideRequestGeneration
                == initialPointerHideGeneration
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
                == initialPointerHideGeneration
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

    #expect(viewModel.feedback?.icon == .image)
    #expect(viewModel.feedback?.text == "Screenshot Copied")
}

@MainActor
@Test
func repeatAndAutoPauseFeedbackUseRequiredIconsAndText() {
    let viewModel = PlaybackViewModel(player: PlaybackPlayer())

    viewModel.showRepeatFeedback()
    #expect(viewModel.feedback?.icon == .repeatIcon)
    #expect(viewModel.feedback?.text == "Repeat")

    viewModel.showAutoPauseFeedback()
    #expect(viewModel.feedback?.icon == .pause)
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

    model.pointerHideRequested()
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
@Test
func normalPlaybackFollowsTheReboundKeyWhileTheControllerKeepsTheDefault() throws {
    try withNormalPlaybackApp { app, _ in
        let viewModel = try #require(app.playback.playbackViewModel)
        app.settings.playbackShortcuts.set(
            PlaybackShortcutKey(keyCode: UInt16(kVK_ANSI_V), shift: true),
            for: .toggleSubtitles
        )

        #expect(!app.handlePlaybackKeyDown(keyCode: 12, modifierFlagsRawValue: 0))
        #expect(!app.handlePlaybackKeyDown(
            keyCode: UInt16(kVK_ANSI_V),
            modifierFlagsRawValue: 0
        ))
        #expect(viewModel.areSubtitlesVisible)

        #expect(app.handlePlaybackKeyDown(
            keyCode: UInt16(kVK_ANSI_V),
            modifierFlagsRawValue: NSEvent.ModifierFlags.shift.rawValue
        ))
        #expect(!viewModel.areSubtitlesVisible)

        // The controller's thumbstick still presses Q.
        app.playback.isPlaybackSurfaceExpanded = true
        #expect(app.handlePlaybackControllerInput(.button(.leftThumbstick)))
        #expect(viewModel.areSubtitlesVisible)
    }
}

@MainActor
@Test
func normalPlaybackConflictingKeyRunsNeitherShortcut() throws {
    try withNormalPlaybackApp { app, _ in
        let viewModel = try #require(app.playback.playbackViewModel)
        app.settings.playbackShortcuts.set(
            PlaybackShortcutKey(keyCode: UInt16(kVK_Space)),
            for: .toggleSubtitles
        )

        #expect(!app.handlePlaybackKeyDown(keyCode: 49, modifierFlagsRawValue: 0))
        #expect(viewModel.areSubtitlesVisible)
        #expect(viewModel.feedback == nil)

        app.settings.playbackShortcuts.reset(.toggleSubtitles)
        #expect(app.handlePlaybackKeyDown(keyCode: 12, modifierFlagsRawValue: 0))
        #expect(!viewModel.areSubtitlesVisible)
    }
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

/// Registers the speed menu with the menu gate the way the chrome's client
/// view does when the menu opens, minus the pointer geometry no unit test
/// exercises.
@MainActor
private func openSpeedMenuGateClient(
    _ app: AppCoordinator
) -> MenuGate.Session {
    app.interfaceLayers.menuGate.open(
        MenuGate.Client(
            owner: .playbackPage,
            kind: .playerSpeedMenu,
            window: { nil },
            isPointerOnMenu: { _ in false },
            handleKey: { [weak app] keyCode, isRepeat in
                app?.playback.handleSpeedMenuKey(
                    keyCode,
                    isRepeat: isRepeat
                ) ?? false
            },
            dismiss: { _ in }
        )
    )
}

/// Registers a selected-text menu with the menu gate the way the overlay's
/// reel does, with the test's own key handler standing in for the menu.
@MainActor
private func openSelectedTextMenuGateClient(
    _ app: AppCoordinator,
    handleKey: @escaping (UInt16) -> Bool
) -> MenuGate.Session {
    app.interfaceLayers.menuGate.open(
        MenuGate.Client(
            owner: .playbackOverlay,
            kind: .selectedTextMenu,
            window: { nil },
            isPointerOnMenu: { _ in false },
            handleKey: { keyCode, _ in handleKey(keyCode) },
            dismiss: { _ in }
        )
    )
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
        let speedMenuSession = openSpeedMenuGateClient(app)
        defer { speedMenuSession.close() }
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
        let menuSession = openSelectedTextMenuGateClient(app) { keyCode in
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

        menuSession.close()
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
        let menuSession = openSelectedTextMenuGateClient(app) { keyCode in
            seenKeyCodes.append(keyCode)
            return true
        }
        defer { menuSession.close() }
        app.playback.openSpeedMenu(
            defaultPosition: PlaybackViewModel.speedPresetIndex(for: 1.0)
        )
        let speedMenuSession = openSpeedMenuGateClient(app)
        defer { speedMenuSession.close() }
        let highlight = app.playback.speedMenuHighlight
        #expect(app.playback.isSpeedMenuOpen)
        #expect(highlight.highlightedPosition == 2)

        #expect(app.handlePlaybackKeyDown(
            keyCode: UInt16(kVK_ANSI_K),
            modifierFlagsRawValue: 0
        ))

        // Opening the Command Panel closes the speed menu outright, while the
        // selected-text menu stays on screen: it belongs to the surface below
        // the panel, so it keeps its state and stops taking keys.
        #expect(app.playback.commandPanelPresentation != nil)
        #expect(!app.playback.isSpeedMenuOpen)
        #expect(highlight.highlightedPosition == nil)
        #expect(seenKeyCodes.isEmpty)

        // The arrow keys reach the Command Panel instead of the frozen menu.
        #expect(app.handlePlaybackKeyDown(keyCode: 125, modifierFlagsRawValue: 0))
        #expect(seenKeyCodes.isEmpty)

        menuSession.close()
        speedMenuSession.close()

        // Escape closes the panel.
        #expect(app.handlePlaybackKeyDown(keyCode: 53, modifierFlagsRawValue: 0))
        #expect(app.playback.commandPanelPresentation == nil)
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
