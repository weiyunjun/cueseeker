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
        let excerptDatabase = try #require(app.excerptDatabase)
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
        #expect(try excerptDatabase.excerptCount() == 0)
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

    #expect(viewModel.feedback?.icon == .camera)
    #expect(viewModel.feedback?.text == "Screenshot Copied")
}

@MainActor
@Test
func autoPauseFeedbackAndReplayCurrentCueCopyMatchRequirements() {
    let viewModel = PlaybackViewModel(player: PlaybackPlayer())

    viewModel.showAutoPauseFeedback()
    #expect(viewModel.feedback?.icon == .pause)
    #expect(viewModel.feedback?.text == "Auto Pause")
    #expect(PlaybackShortcutAction.repeatCue.title == "Replay Current Cue")
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
    let userDefaults = try #require(UserDefaults.temporary(suiteName: suiteName))
    let fixtureRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "CueSeekerNormalPlaybackShortcutTests-\(UUID().uuidString)",
            isDirectory: true
        )
    let databaseURL = fixtureRoot.appendingPathComponent("normal-shortcuts.sqlite")
    defer {
        userDefaults.removePersistentDomainAndPlist(forName: suiteName)
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
        // The chrome's client view leaves the gate with the menu; the test
        // stands in for it.
        speedMenuSession.close()

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

        // The panel opens over the menus by a path other than the K key, which
        // the open menus spend. Neither menu closes: both belong to surfaces
        // below the panel, so they keep their state and stop taking keys.
        #expect(app.presentPlaybackCommandPanel())
        #expect(app.playback.commandPanelPresentation != nil)
        #expect(app.playback.isSpeedMenuOpen)
        #expect(highlight.highlightedPosition == 2)

        // The arrow keys reach the Command Panel instead of the frozen menus.
        #expect(app.handlePlaybackKeyDown(keyCode: 125, modifierFlagsRawValue: 0))
        #expect(seenKeyCodes.isEmpty)
        #expect(highlight.highlightedPosition == 2)

        // Escape closes the panel, and the menus underneath take keys again.
        #expect(app.handlePlaybackKeyDown(keyCode: 53, modifierFlagsRawValue: 0))
        #expect(app.playback.commandPanelPresentation == nil)
        #expect(app.playback.isSpeedMenuOpen)
        #expect(app.handlePlaybackKeyDown(keyCode: 125, modifierFlagsRawValue: 0))
        #expect(seenKeyCodes == [125])
    }
}

@MainActor
@Test
func openSpeedMenuSpendsEveryKeyItDoesNotTake() throws {
    try withNormalPlaybackApp { app, _ in
        let viewModel = try #require(app.playback.playbackViewModel)
        // The Command Panel opens only over a visible playback page.
        app.playback.isPlaybackSurfaceExpanded = true
        app.playback.openSpeedMenu(
            defaultPosition: PlaybackViewModel.speedPresetIndex(for: 1.0)
        )
        let speedMenuSession = openSpeedMenuGateClient(app)
        defer { speedMenuSession.close() }
        let volume = viewModel.volume

        // Every in-app function is spent while the menu is open, ⇧ ones too:
        // the Command Panel and the Playback Overlay do not open, playback does
        // not toggle, the speed in effect and the volume do not move, and Tab
        // and the seek and result keys do nothing.
        let spentKeys: [(keyCode: Int, modifiers: UInt)] = [
            (kVK_ANSI_K, 0),
            (kVK_Space, 0),
            (kVK_LeftArrow, 0),
            (kVK_RightArrow, 0),
            (kVK_ANSI_A, 0),
            (kVK_ANSI_D, 0),
            (kVK_Tab, 0),
            (kVK_ANSI_Period, NSEvent.ModifierFlags.shift.rawValue),
        ]
        for key in spentKeys {
            #expect(app.handlePlaybackKeyDown(
                keyCode: UInt16(key.keyCode),
                modifierFlagsRawValue: key.modifiers
            ))
        }
        #expect(app.playback.commandPanelPresentation == nil)
        #expect(app.playback.subtitleFocusSession == nil)
        #expect(app.playback.isSpeedMenuOpen)
        #expect(!viewModel.isPlaying)
        #expect(viewModel.playbackSpeed == 1.0)
        #expect(viewModel.volume == volume)

        // A ⌘ combination is not the menu's business and travels on.
        #expect(!app.handlePlaybackKeyDown(
            keyCode: UInt16(kVK_ANSI_K),
            modifierFlagsRawValue: NSEvent.ModifierFlags.command.rawValue
        ))
        #expect(app.playback.isSpeedMenuOpen)

        // Escape closes the menu, and the same key opens the Command Panel
        // once no menu is open.
        #expect(app.handlePlaybackKeyDown(keyCode: 53, modifierFlagsRawValue: 0))
        #expect(!app.playback.isSpeedMenuOpen)
        speedMenuSession.close()
        #expect(app.handlePlaybackKeyDown(
            keyCode: UInt16(kVK_ANSI_K),
            modifierFlagsRawValue: 0
        ))
        #expect(app.playback.commandPanelPresentation != nil)
    }
}

@MainActor
@Test
func openOverlayMenuSpendsTabAndTheFooterShortcuts() throws {
    try withNormalPlaybackApp { app, _ in
        let excerptDatabase = try #require(app.excerptDatabase)
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
        let module = session.selectedModule
        var seenKeyCodes: [UInt16] = []
        let menuSession = openSelectedTextMenuGateClient(app) { keyCode in
            seenKeyCodes.append(keyCode)
            return [125, 126, 36, 53].contains(keyCode)
        }
        defer { menuSession.close() }

        // Tab, the footer shortcuts and the Command Panel key are spent: the
        // module stays, nothing is saved, no second menu opens, the collage
        // editor stays closed and the panel does not open.
        for keyCode in [kVK_Tab, kVK_ANSI_S, kVK_ANSI_C, kVK_ANSI_X, kVK_ANSI_P, kVK_ANSI_K] {
            #expect(app.handlePlaybackKeyDown(
                keyCode: UInt16(keyCode),
                modifierFlagsRawValue: 0
            ))
        }
        #expect(session.selectedModule == module)
        #expect(app.playback.excerptDestinationMenu == nil)
        #expect(try excerptDatabase.excerptCount() == 0)
        #expect(!session.isEditingCollage)
        #expect(app.playback.commandPanelPresentation == nil)

        // The menu's own keys still reach it.
        seenKeyCodes = []
        #expect(app.handlePlaybackKeyDown(keyCode: 125, modifierFlagsRawValue: 0))
        #expect(seenKeyCodes == [125])
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
