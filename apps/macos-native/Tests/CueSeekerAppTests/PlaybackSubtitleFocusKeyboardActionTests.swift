import AppKit
@testable import CueSeekerCore
import CueSeekerPlayback
import Foundation
import SwiftUI
import Testing
@testable import CueSeekerApp

@Test
func subtitleFocusClipboardWritesExactCueText() throws {
    let pasteboard = NSPasteboard(name: .init("SubtitleFocus-\(UUID().uuidString)"))
    defer { pasteboard.releaseGlobally() }
    let text = "  first line  \n\nthird line"

    #expect(CueClipboard.copy(text, to: pasteboard))
    #expect(pasteboard.string(forType: .string) == text)
    #expect(!CueClipboard.copy("", to: pasteboard))
}

@Test
func subtitleFocusClipboardWritesPlainMarkdownCueLinkOnly() throws {
    let pasteboard = NSPasteboard(
        name: .init("SubtitleFocus-Markdown-\(UUID().uuidString)")
    )
    defer { pasteboard.releaseGlobally() }
    let cueText = "  first line  \n\nthird line"

    #expect(CueClipboard.copyDeepLink(
        cueText: cueText,
        cueID: 42,
        to: pasteboard
    ))
    #expect(
        pasteboard.string(forType: .string)
            == "[first line third line](cueseeker://cue?id=42)"
    )
    #expect(pasteboard.data(forType: .html) == nil)
    #expect(pasteboard.data(forType: .rtf) == nil)
    #expect(!CueClipboard.copyDeepLink(
        cueText: cueText,
        cueID: 0,
        to: pasteboard
    ))
}

@Test
func subtitleFocusActionContextPreservesExactCueIdentityAndContent() {
    let cue = SubtitleFocusCue(
        id: 42,
        cueGroupID: 7,
        ordinal: 6,
        eventIndex: 123,
        displayOrder: 2,
        startMilliseconds: 1_234,
        endMilliseconds: 2_345,
        content: "  first line  \n\nthird line"
    )
    let context = keyboardActionContext(cue: cue)

    #expect(context.cueTextSelection.cueGroupID == 7)
    #expect(context.cueTextSelection.cueLineID == 42)
    #expect(context.cueTextSelection.cueEventIndex == 123)
    #expect(context.cueTextSelection.cueDisplayOrder == 2)
    #expect(context.cueTextSelection.startMilliseconds == 1_234)
    #expect(context.cueTextSelection.endMilliseconds == 2_345)
    #expect(context.cueTextSelection.lines == ["  first line  ", "", "third line"])
    #expect(context.cueTextSelection.text == "  first line  \n\nthird line")
}

@MainActor
@Test
func playbackOverlayEnterQueuesPlayWhileSpaceRemainsInactive() async throws {
    try await withKeyboardActionApp { app, _ in
        let session = try #require(app.playback.beginSubtitleFocusSession(
            openSnapshot: keyboardActionOpenSnapshot(wasPlaying: false)
        ))
        #expect(session.publishInitialSnapshot(
            keyboardActionSnapshot(),
            token: session.token
        ))
        session.noteCueReelMotion(true)

        #expect(app.handlePlaybackKeyDown(keyCode: 49, modifierFlagsRawValue: 0))
        #expect(session.pendingKeyboardAction == nil)

        #expect(app.handlePlaybackKeyDown(keyCode: 36, modifierFlagsRawValue: 0))
        #expect(session.pendingKeyboardAction == .playFromThisCue)
        #expect(app.handlePlaybackKeyDown(
            keyCode: 36,
            modifierFlagsRawValue: 0,
            isRepeat: true
        ))
        #expect(app.playback.subtitleFocusSession === session)
        #expect(session.pendingKeyboardAction == .playFromThisCue)
        #expect(session.activeKeyboardAction == nil)
        #expect(session.currentSnapshot?.selectedOrdinal == 12)
        #expect(app.playback.playbackViewModel?.feedback == nil)
    }
}

@MainActor
@Test
func playbackOverlayPControlsExclusiveEditingCollageMode() async throws {
    try await withKeyboardActionApp { app, _ in
        app.settings.prefillCommandPanelWithFocusedCue = true
        let session = try #require(app.playback.beginSubtitleFocusSession(
            openSnapshot: keyboardActionOpenSnapshot(wasPlaying: false),
            availableModules: [.current, .playlist]
        ))
        #expect(session.publishInitialSnapshot(
            keyboardActionSnapshot(),
            token: session.token
        ))
        let subtitlesWereVisible = try #require(
            app.playback.playbackViewModel
        ).areSubtitlesVisible

        #expect(app.handlePlaybackKeyDown(keyCode: 35, modifierFlagsRawValue: 0))
        #expect(app.playback.subtitleFocusSession === session)
        #expect(session.isEditingCollage)
        #expect(session.collagePreviewStore != nil)
        #expect(app.playback.playbackViewModel?.feedback == nil)

        #expect(app.handlePlaybackKeyDown(
            keyCode: 35,
            modifierFlagsRawValue: 0,
            isRepeat: true
        ))
        #expect(session.isEditingCollage)
        #expect(app.handlePlaybackKeyDown(keyCode: 48, modifierFlagsRawValue: 0))
        #expect(session.selectedModule == .current)
        #expect(app.handlePlaybackKeyDown(keyCode: 12, modifierFlagsRawValue: 0))
        #expect(app.playback.playbackViewModel?.areSubtitlesVisible == subtitlesWereVisible)
        #expect(session.collageSelectionPlan.contains(cueID: 13))
        #expect(app.handlePlaybackKeyDown(keyCode: 36, modifierFlagsRawValue: 0))
        #expect(session.pendingKeyboardAction == nil)
        #expect(!session.collageSelectionPlan.contains(cueID: 13))
        #expect(app.handlePlaybackKeyDown(
            keyCode: 36,
            modifierFlagsRawValue: 0,
            isRepeat: true
        ))
        #expect(!session.collageSelectionPlan.contains(cueID: 13))
        #expect(app.handlePlaybackKeyDown(keyCode: 36, modifierFlagsRawValue: 0))
        #expect(session.collageSelectionPlan.contains(cueID: 13))
        #expect(app.handlePlaybackKeyDown(keyCode: 50, modifierFlagsRawValue: 0))
        #expect(app.playback.commandPanelPresentation == nil)
        #expect(app.handlePlaybackKeyDown(keyCode: 126, modifierFlagsRawValue: 0))
        #expect(session.keyboardNavigationRequest?.targetOrdinal == 11)
        #expect(app.handlePlaybackKeyDown(keyCode: 125, modifierFlagsRawValue: 0))
        #expect(session.keyboardNavigationRequest?.targetOrdinal == 12)

        #expect(app.handlePlaybackKeyDown(keyCode: 53, modifierFlagsRawValue: 0))
        #expect(!session.isEditingCollage)
        #expect(session.collagePreviewStore == nil)
        #expect(app.playback.subtitleFocusSession === session)
        #expect(session.selectModule(.playlist))
        #expect(app.handlePlaybackKeyDown(keyCode: 35, modifierFlagsRawValue: 0))
        #expect(!session.isEditingCollage)
    }
}

@MainActor
@Test
func playbackOverlayTabCyclesModulesAndIgnoresKeyRepeat() async throws {
    try await withKeyboardActionApp { app, _ in
        let session = try #require(app.playback.beginSubtitleFocusSession(
            openSnapshot: keyboardActionOpenSnapshot(wasPlaying: false),
            availableModules: [.current, .playlist]
        ))
        #expect(session.publishInitialSnapshot(
            keyboardActionSnapshot(),
            token: session.token
        ))

        #expect(app.handlePlaybackKeyDown(keyCode: 48, modifierFlagsRawValue: 0))
        #expect(session.selectedModule == .playlist)
        #expect(app.handlePlaybackKeyDown(
            keyCode: 48,
            modifierFlagsRawValue: 0,
            isRepeat: true
        ))
        #expect(session.selectedModule == .playlist)

        #expect(app.handlePlaybackKeyDown(keyCode: 48, modifierFlagsRawValue: 0))
        #expect(session.selectedModule == .current)
    }
}

@MainActor
@Test
func playbackControllerShouldersCycleOverlayModules() async throws {
    try await withKeyboardActionApp { app, _ in
        app.playback.isPlaybackSurfaceExpanded = true
        let session = try #require(app.playback.beginSubtitleFocusSession(
            openSnapshot: keyboardActionOpenSnapshot(wasPlaying: false),
            availableModules: [.current, .playlist]
        ))
        #expect(session.publishInitialSnapshot(
            keyboardActionSnapshot(),
            token: session.token
        ))

        #expect(app.handlePlaybackControllerInput(.button(.rightShoulder)))
        #expect(session.selectedModule == .playlist)
        #expect(app.handlePlaybackControllerInput(.button(.leftShoulder)))
        #expect(session.selectedModule == .current)
        #expect(app.handlePlaybackControllerInput(.button(.leftShoulder)))
        #expect(session.selectedModule == .playlist)
        #expect(!app.handlePlaybackControllerInput(.button(.centerSurface)))
    }
}

@MainActor
@Test
func playbackControllerUsesNativeTextActionsOnCommandPanelRoot() async throws {
    try await withKeyboardActionApp { app, _ in
        app.playback.isPlaybackSurfaceExpanded = true

        #expect(app.handlePlaybackControllerInput(.button(.auxiliaryRight)))
        #expect(app.playback.commandPanelPresentation?.page == .root)

        var actions: [PlaybackControllerTextAction] = []
        let editableInput = PlaybackKeyboardTextInputState(
            isEditableFocused: true,
            hasMarkedText: false
        )
        let recordAction: (PlaybackControllerTextAction) -> Bool = { action in
            actions.append(action)
            return true
        }
        #expect(app.handlePlaybackControllerInput(
            .button(.west),
            textInputState: editableInput,
            textActionHandler: recordAction
        ))
        #expect(app.handlePlaybackControllerInput(
            .button(.west, isRepeat: true),
            textInputState: editableInput,
            textActionHandler: recordAction
        ))
        #expect(app.handlePlaybackControllerInput(
            .button(.north),
            textInputState: editableInput,
            textActionHandler: recordAction
        ))
        #expect(!app.handlePlaybackControllerInput(
            .button(.north, isRepeat: true),
            textInputState: editableInput,
            textActionHandler: recordAction
        ))
        #expect(app.handlePlaybackControllerInput(
            .direction(.left, source: .directionalPad, isRepeat: false),
            textInputState: editableInput,
            textActionHandler: recordAction
        ))
        #expect(app.handlePlaybackControllerInput(
            .direction(.right, source: .directionalPad, isRepeat: false),
            textInputState: editableInput,
            textActionHandler: recordAction
        ))
        #expect(app.handlePlaybackControllerInput(
            .direction(.up, source: .directionalPad, isRepeat: false),
            textInputState: PlaybackKeyboardTextInputState(
                isEditableFocused: true,
                hasMarkedText: true
            ),
            textActionHandler: recordAction
        ))
        #expect(app.handlePlaybackControllerInput(
            .button(.auxiliaryRight, isRepeat: true),
            textInputState: editableInput,
            textActionHandler: recordAction
        ))
        #expect(actions == [
            .deleteBackward,
            .deleteBackward,
            .paste,
            .moveLeft,
            .moveRight,
            .moveUp,
            .insertText("`"),
        ])

        #expect(app.handlePlaybackControllerInput(.button(.east)))
        #expect(app.playback.commandPanelPresentation == nil)
    }
}

@MainActor
@Test
func playbackControllerPreservesNativeSearchTextEntry() async throws {
    try await withKeyboardActionApp { app, _ in
        app.playback.isPlaybackSurfaceExpanded = true
        let session = try #require(app.playback.beginSubtitleFocusSession(
            openSnapshot: keyboardActionOpenSnapshot(wasPlaying: false),
            availableModules: [.current, .search]
        ))
        #expect(session.publishInitialSnapshot(
            keyboardActionSnapshot(),
            token: session.token
        ))
        #expect(session.selectModule(.search))

        var actions: [PlaybackControllerTextAction] = []
        let recordAction: (PlaybackControllerTextAction) -> Bool = { action in
            actions.append(action)
            return true
        }
        let editableInput = PlaybackKeyboardTextInputState(
            isEditableFocused: true,
            hasMarkedText: false
        )

        #expect(app.handlePlaybackControllerInput(
            .button(.west, isRepeat: true),
            textInputState: editableInput,
            textActionHandler: recordAction
        ))
        #expect(app.handlePlaybackControllerInput(
            .button(.north, isRepeat: true),
            textInputState: editableInput,
            textActionHandler: recordAction
        ))
        #expect(actions == [.insertText("c"), .insertText("s")])
    }
}

@MainActor
@Test
func playbackControllerRepeatsSquareBackspaceInCommandPanelRoot() async throws {
    try await withKeyboardActionApp { app, _ in
        app.playback.isPlaybackSurfaceExpanded = true
        #expect(app.presentPlaybackCommandPanel())

        var actions: [PlaybackControllerTextAction] = []
        let editableInput = PlaybackKeyboardTextInputState(
            isEditableFocused: true,
            hasMarkedText: false
        )
        let monitor = GameControllerInputMonitor(
            repeatDelay: 0.01,
            repeatInterval: 0.01,
            inputEligibility: { true }
        ) { input in
            app.handlePlaybackControllerInput(
                input,
                textInputState: editableInput
            ) { action in
                actions.append(action)
                return true
            }
        }
        defer {
            monitor.stop()
        }

        monitor.handleButton(.west, isPressed: true)
        runControllerRepeatTimers()
        monitor.handleButton(.west, isPressed: false)

        #expect(actions.count >= 2)
        #expect(actions.allSatisfy { $0 == .deleteBackward })
    }
}

@MainActor
@Test
func playbackControllerRepeatsThumbstickUpOnNormalVideo() async throws {
    try await withKeyboardActionApp { app, _ in
        app.playback.isPlaybackSurfaceExpanded = true
        let viewModel = try #require(app.playback.playbackViewModel)
        viewModel.adjustVolume(by: -50)
        #expect(viewModel.volume == 50)

        let monitor = GameControllerInputMonitor(
            repeatDelay: 0.01,
            repeatInterval: 0.01,
            inputEligibility: { true }
        ) { input in
            app.handlePlaybackControllerInput(input)
        }
        defer {
            monitor.stop()
        }

        monitor.handleThumbstick(x: 0, y: 0.8)
        runControllerRepeatTimers()
        monitor.handleThumbstick(x: 0, y: 0)

        #expect(viewModel.volume > 55)
    }
}

@MainActor
@Test
func playbackEscapeExitsNormalVideoFullscreenWithoutRepeating() {
    var exitCount = 0
    let exitFullscreen = {
        exitCount += 1
    }

    #expect(AppCoordinator.handlePlaybackFullscreenEscape(
        keyCode: 53,
        isRepeat: false,
        isFullscreen: true,
        exitFullscreen: exitFullscreen
    ))
    #expect(exitCount == 1)
    #expect(AppCoordinator.handlePlaybackFullscreenEscape(
        keyCode: 53,
        isRepeat: true,
        isFullscreen: true,
        exitFullscreen: exitFullscreen
    ))
    #expect(exitCount == 1)
    #expect(!AppCoordinator.handlePlaybackFullscreenEscape(
        keyCode: 53,
        isRepeat: false,
        isFullscreen: false,
        exitFullscreen: exitFullscreen
    ))
}

@MainActor
@Test
func playbackControllerRoutesThumbstickRepeatThroughEveryInterface() async throws {
    try await withKeyboardActionApp { app, _ in
        let leftRepeat = ControllerInput.direction(
            .left,
            source: .leftThumbstick,
            isRepeat: true
        )
        let upRepeat = ControllerInput.direction(
            .up,
            source: .leftThumbstick,
            isRepeat: true
        )

        #expect(!app.handlePlaybackControllerInput(leftRepeat))
        app.playback.isPlaybackSurfaceExpanded = true
        #expect(app.handlePlaybackControllerInput(leftRepeat))
        #expect(app.handlePlaybackControllerInput(upRepeat))

        #expect(app.presentPlaybackCommandPanel())
        #expect(app.handlePlaybackControllerInput(leftRepeat))
        #expect(app.handlePlaybackControllerInput(upRepeat))
    }
}

@MainActor
@Test
func playbackCommandPanelBacktickOpensRootAndEscapeCloses() async throws {
    try await withKeyboardActionApp { app, _ in
        app.playback.isPlaybackSurfaceExpanded = true
        app.settings.prefillCommandPanelWithFocusedCue = true

        #expect(app.handlePlaybackKeyDown(
            keyCode: 50,
            modifierFlagsRawValue: 0
        ))
        let presentation = try #require(
            app.playback.commandPanelPresentation
        )
        #expect(presentation.page == .root)
        #expect(presentation.query.isEmpty)
        #expect(app.playback.subtitleFocusSession == nil)

        #expect(app.handlePlaybackKeyDown(
            keyCode: 53,
            modifierFlagsRawValue: 0
        ))
        #expect(app.playback.commandPanelPresentation == nil)

        #expect(!app.handlePlaybackKeyDown(
            keyCode: 50,
            modifierFlagsRawValue: NSEvent.ModifierFlags.shift.rawValue
        ))
        #expect(app.playback.commandPanelPresentation == nil)

        #expect(!app.handlePlaybackKeyDown(
            keyCode: 50,
            modifierFlagsRawValue: 0,
            textInputState: PlaybackKeyboardTextInputState(
                isEditableFocused: true,
                hasMarkedText: false
            )
        ))
        #expect(app.playback.commandPanelPresentation == nil)

        #expect(!app.handlePlaybackKeyDown(
            keyCode: 36,
            modifierFlagsRawValue: NSEvent.ModifierFlags.command.rawValue
        ))
        #expect(app.playback.commandPanelPresentation == nil)
    }
}

@MainActor
@Test
func playbackCommandPanelPreservesUnderlyingOverlay() async throws {
    try await withKeyboardActionApp { app, _ in
        app.playback.isPlaybackSurfaceExpanded = true
        let session = try #require(app.playback.beginSubtitleFocusSession(
            openSnapshot: keyboardActionOpenSnapshot(wasPlaying: false)
        ))
        #expect(session.publishInitialSnapshot(
            keyboardActionSnapshot(),
            token: session.token
        ))

        #expect(app.handlePlaybackKeyDown(
            keyCode: 50,
            modifierFlagsRawValue: 0
        ))
        #expect(app.playback.commandPanelPresentation?.page == .root)
        #expect(app.playback.subtitleFocusSession === session)

        #expect(app.handlePlaybackKeyDown(
            keyCode: 53,
            modifierFlagsRawValue: 0
        ))
        #expect(app.playback.commandPanelPresentation == nil)
        #expect(app.playback.subtitleFocusSession === session)
    }
}

@MainActor
@Test
func playbackCommandPanelPrefillsFocusedCurrentCueWithoutSearching() async throws {
    try await withKeyboardActionApp { app, _ in
        app.playback.isPlaybackSurfaceExpanded = true
        app.settings.prefillCommandPanelWithFocusedCue = true
        let session = try #require(app.playback.beginSubtitleFocusSession(
            openSnapshot: keyboardActionOpenSnapshot(wasPlaying: false)
        ))
        #expect(session.publishInitialSnapshot(
            keyboardActionSnapshot(lines: ["focused first", "focused second"]),
            token: session.token
        ))
        let previousSearchQuery = app.search.searchQuery

        #expect(app.presentPlaybackCommandPanel())

        #expect(app.playback.commandPanelPresentation?.page == .root)
        #expect(
            app.playback.commandPanelPresentation?.query
                == "focused first focused second"
        )
        #expect(app.search.searchQuery == previousSearchQuery)
        #expect(app.playback.subtitleFocusSession === session)
    }
}

@MainActor
@Test
func playbackCommandPanelPrefillsFocusedPlaylistCue() async throws {
    try await withKeyboardActionApp { app, _ in
        let result = keyboardActionPlaylistSearchResult(
            id: 1_001,
            videoPath: keyboardActionSource().videoPath,
            subtitlePath: keyboardActionSource().subtitlePath,
            startMilliseconds: 12_000,
            content: "playlist first\nplaylist second"
        )
        let item = PlaybackPlaylistItem(searchResult: result, ordinal: 0)
        let (session, _) = try await beginKeyboardActionPlaylistSession(
            app: app,
            item: item
        )
        app.playback.isPlaybackSurfaceExpanded = true
        app.settings.prefillCommandPanelWithFocusedCue = true

        #expect(app.presentPlaybackCommandPanel())

        #expect(
            app.playback.commandPanelPresentation?.query
                == "playlist first playlist second"
        )
        #expect(app.playback.subtitleFocusSession === session)
    }
}

@MainActor
@Test
func playbackCommandPanelKeepsQueryEmptyWhenFocusedCuePrefillIsOff() async throws {
    try await withKeyboardActionApp { app, _ in
        app.playback.isPlaybackSurfaceExpanded = true
        let session = try #require(app.playback.beginSubtitleFocusSession(
            openSnapshot: keyboardActionOpenSnapshot(wasPlaying: false)
        ))
        #expect(session.publishInitialSnapshot(
            keyboardActionSnapshot(),
            token: session.token
        ))

        #expect(app.presentPlaybackCommandPanel())

        #expect(app.playback.commandPanelPresentation?.query.isEmpty == true)
    }
}

@MainActor
@Test
func playbackCommandPanelRootNavigatesAndOpensRecentPages() async throws {
    try await withKeyboardActionApp { app, _ in
        app.playback.isPlaybackSurfaceExpanded = true
        #expect(app.presentPlaybackCommandPanel())
        #expect(app.playback.commandPanelPresentation?.selectedOrdinal == 0)

        let editableInput = PlaybackKeyboardTextInputState(
            isEditableFocused: true,
            hasMarkedText: false
        )
        #expect(app.handlePlaybackKeyDown(
            keyCode: 125,
            modifierFlagsRawValue: 0,
            textInputState: editableInput
        ))
        #expect(app.playback.commandPanelPresentation?.selectedOrdinal == 1)
        #expect(app.handlePlaybackKeyDown(
            keyCode: 36,
            modifierFlagsRawValue: 0,
            textInputState: editableInput
        ))
        #expect(app.playback.commandPanelPresentation?.page == .recentShioris)

        #expect(app.handlePlaybackKeyDown(
            keyCode: 53,
            modifierFlagsRawValue: 0
        ))
        #expect(app.playback.commandPanelPresentation?.page == .root)

        app.updatePlaybackCommandPanelQuery("大丈夫")
        #expect(app.playback.commandPanelPresentation?.selectedOrdinal == 0)
        #expect(app.handlePlaybackKeyDown(
            keyCode: 125,
            modifierFlagsRawValue: 0,
            textInputState: editableInput
        ))
        #expect(app.playback.commandPanelPresentation?.selectedOrdinal == 1)
        #expect(app.handlePlaybackKeyDown(
            keyCode: 36,
            modifierFlagsRawValue: 0,
            textInputState: editableInput
        ))
        #expect(app.playback.commandPanelPresentation?.page == .recentVideos)
    }
}

@MainActor
@Test
func playbackCommandPanelRecentVideosUsesFourVisualGridDirections() async throws {
    try await withKeyboardActionApp { app, _ in
        let items = (0..<7).map(keyboardActionRecentVideo)
        app.library.testRecentWatchingItems = items
        app.playback.isPlaybackSurfaceExpanded = true
        #expect(app.presentPlaybackCommandPanel())

        var presentation = try #require(
            app.playback.commandPanelPresentation
        )
        presentation.page = .recentVideos
        presentation.selectedOrdinal = 0
        app.playback.presentCommandPanel(presentation)
        app.updatePlaybackCommandPanelRecentVideoGridLayout(
            columnCount: 3,
            itemFramesByID: Dictionary(uniqueKeysWithValues: items.indices.map {
                ordinal in
                (
                    items[ordinal].id,
                    CGRect(
                        x: CGFloat(ordinal % 3) * 200,
                        y: CGFloat(ordinal / 3) * 300,
                        width: 180,
                        height: 260
                    )
                )
            })
        )

        #expect(app.handlePlaybackKeyDown(keyCode: 124, modifierFlagsRawValue: 0))
        #expect(app.playback.commandPanelPresentation?.selectedOrdinal == 1)
        #expect(app.handlePlaybackKeyDown(keyCode: 125, modifierFlagsRawValue: 0))
        #expect(app.playback.commandPanelPresentation?.selectedOrdinal == 4)
        #expect(app.handlePlaybackKeyDown(keyCode: 123, modifierFlagsRawValue: 0))
        #expect(app.playback.commandPanelPresentation?.selectedOrdinal == 3)
        #expect(app.handlePlaybackKeyDown(keyCode: 126, modifierFlagsRawValue: 0))
        #expect(app.playback.commandPanelPresentation?.selectedOrdinal == 0)

        #expect(app.handlePlaybackKeyDown(keyCode: 123, modifierFlagsRawValue: 0))
        #expect(app.playback.commandPanelPresentation?.selectedOrdinal == 0)
        #expect(app.handlePlaybackKeyDown(keyCode: 126, modifierFlagsRawValue: 0))
        #expect(app.playback.commandPanelPresentation?.selectedOrdinal == 0)

        #expect(app.handlePlaybackKeyDown(keyCode: 124, modifierFlagsRawValue: 0))
        #expect(app.handlePlaybackKeyDown(keyCode: 124, modifierFlagsRawValue: 0))
        #expect(app.playback.commandPanelPresentation?.selectedOrdinal == 2)
        #expect(app.handlePlaybackKeyDown(keyCode: 124, modifierFlagsRawValue: 0))
        #expect(app.playback.commandPanelPresentation?.selectedOrdinal == 2)
        #expect(app.handlePlaybackKeyDown(keyCode: 125, modifierFlagsRawValue: 0))
        #expect(app.playback.commandPanelPresentation?.selectedOrdinal == 5)
        #expect(app.handlePlaybackKeyDown(keyCode: 125, modifierFlagsRawValue: 0))
        #expect(app.playback.commandPanelPresentation?.selectedOrdinal == 6)
        #expect(app.handlePlaybackKeyDown(keyCode: 125, modifierFlagsRawValue: 0))
        #expect(app.playback.commandPanelPresentation?.selectedOrdinal == 6)
    }
}

@MainActor
@Test
func playbackCommandPanelRecentVideosUsesNearestEdgeForPartialAndLazyTargets() {
    let orderedItemIDs = (0..<25).map(String.init)
    let frames = [
        "0": CGRect(x: 0, y: -20, width: 180, height: 160),
        "15": CGRect(x: 0, y: 560, width: 180, height: 160),
        "19": CGRect(x: 784, y: 560, width: 180, height: 160),
    ]

    #expect(PlaybackCommandPanelRecentVideos.scrollAnchor(
        for: "0",
        orderedItemIDs: orderedItemIDs,
        itemFramesByID: frames,
        viewportHeight: 614
    ) == .top)
    #expect(PlaybackCommandPanelRecentVideos.scrollAnchor(
        for: "15",
        orderedItemIDs: orderedItemIDs,
        itemFramesByID: frames,
        viewportHeight: 614
    ) == .bottom)
    #expect(PlaybackCommandPanelRecentVideos.scrollAnchor(
        for: "20",
        orderedItemIDs: orderedItemIDs,
        itemFramesByID: frames,
        viewportHeight: 614
    ) == .bottom)
    #expect(PlaybackCommandPanelRecentVideos.scrollAnchor(
        for: "10",
        orderedItemIDs: orderedItemIDs,
        itemFramesByID: [
            "10": CGRect(x: 0, y: 320, width: 180, height: 160),
        ],
        viewportHeight: 614
    ) == nil)
}

@MainActor
@Test
func playbackCommandPanelSearchSupportsCueShortcutsAndFullPlaylist() async throws {
    try await withKeyboardActionApp { app, _ in
        let source = keyboardActionSource()
        let results = (0..<60).map { ordinal in
            let content: String
            if ordinal == 0 {
                content = "first command result"
            } else if ordinal == 1 {
                content = "second command result"
            } else {
                content = "command result \(ordinal)"
            }
            return keyboardActionPlaylistSearchResult(
                id: Int64(11 + ordinal),
                videoPath: source.videoPath,
                subtitlePath: source.subtitlePath,
                startMilliseconds: (ordinal + 1) * 1_000,
                content: content,
                displayTitle: "Command Episode \(ordinal)",
                cueGroupLines: ordinal == 0
                    ? [content, "command context"]
                    : nil
            )
        }
        app.search.replaceResidentResults(results)
        app.playback.isPlaybackSurfaceExpanded = true
        #expect(app.presentPlaybackCommandPanelSearch(
            query: "command",
            startsSearch: false
        ))
        NSPasteboard.general.clearContents()

        let previewWindow = try #require(
            app.playback.commandPanelSearchWindow
        )
        #expect(previewWindow.snapshot.totalCount == 50)
        #expect(previewWindow.snapshot.loadedItemCount == 50)
        #expect(previewWindow.selectedOrdinal == 0)
        let previewAdapter = PlaybackCueResultReelAdapter(
            windowStore: previewWindow,
            showsCueGroup: true
        )
        let firstResult = try #require(previewAdapter.cueResult(at: 0))
        #expect(previewAdapter.sequenceTotalCount == 50)
        #expect(firstResult.metadata == PlaybackCueMetadata(
            displayTitle: "Command Episode 0",
            timeRange: results[0].timeRange
        ))
        #expect(firstResult.additionalCueTexts == ["command context"])
        let firstPlan = PlaybackCueResultLayout().prepare(
            result: firstResult,
            showsCueGroup: true,
            isSelected: true,
            width: 800,
            viewportHeight: 800
        )
        #expect(firstPlan.visualLines.map(\.role) == [
            .primaryCue,
            .additionalCue(index: 0),
        ])
        let secondResult = try #require(previewAdapter.cueResult(at: 1))
        let secondPlan = PlaybackCueResultLayout().prepare(
            result: secondResult,
            showsCueGroup: true,
            isSelected: false,
            width: 800,
            viewportHeight: 800
        )
        #expect(secondPlan.metadata?.displayTitle == "Command Episode 1")
        #expect(secondPlan.metadata?.timeRange == results[1].timeRange)
        #expect(!secondPlan.isSelected)

        let previewSnapshot = previewAdapter.snapshot
        #expect(app.commitPlaybackCommandPanelSearchReelSelection(
            PlaybackVirtualReelSelectionCommit(
                datasetID: previewSnapshot.datasetID,
                generation: previewSnapshot.generation,
                ordinal: 1
            )
        ))
        #expect(previewWindow.selectedOrdinal == 1)
        #expect(app.movePlaybackCommandPanelSelection(-1))
        #expect(previewWindow.selectedOrdinal == 0)

        #expect(app.handlePlaybackKeyDown(keyCode: 8, modifierFlagsRawValue: 0))
        #expect(
            NSPasteboard.general.string(forType: .string)
                == "first command result"
        )

        #expect(app.handlePlaybackKeyDown(keyCode: 125, modifierFlagsRawValue: 0))
        #expect(previewWindow.selectedOrdinal == 1)
        #expect(app.handlePlaybackKeyDown(keyCode: 7, modifierFlagsRawValue: 0))
        #expect(
            NSPasteboard.general.string(forType: .string)
                == "[second command result](cueseeker://cue?id=12)"
        )

        #expect(app.handlePlaybackKeyDown(keyCode: 36, modifierFlagsRawValue: 0))
        #expect(app.playback.commandPanelPresentation == nil)
        #expect(app.playback.commandPanelSearchWindow == nil)
        #expect(app.search.searchQuery == "command")
        #expect(app.search.selectedSearchResult?.entryID == 12)
        #expect(app.playback.playlistSource?.boundary.totalCount == 60)
        #expect(app.playback.playbackSearchPlaylistOrdinal == 1)
    }
}

@MainActor
@Test
func playbackCommandPanelDatabaseSearchOpensCompletePlaylistOverlay() async throws {
    try await withKeyboardActionApp { app, _ in
        app.indexing.selectedFolders = [URL(fileURLWithPath: "/Media")]
        app.search.updateSearchFacetFilter(CueFacetFilter(
            durations: [.underOneSecond]
        ))
        app.ensurePlayerInitialized()
        app.playback.isPlaybackSurfaceExpanded = true

        #expect(app.presentPlaybackCommandPanelSearch(
            query: "keyboard action",
            startsSearch: true
        ))
        await app.search.searchTask?.value
        await app.search.exactCompletionTask?.value
        app.synchronizePlaybackCommandPanelSearchResults()

        #expect(app.search.searchResults.count == 30)
        #expect(app.search.projectedSearchResults.count == 30)
        let selectedResult = try #require(
            app.search.projectedSearchResults.dropFirst().first
        )
        #expect(app.requestPlaybackCommandPanelSearchAction(
            .playFromThisCue,
            ordinal: 1
        ))
        app.refreshSearchPlaybackPlaylistSource(
            resultListGeneration: app.search.resultListGeneration
        )

        app.playback.playbackStatus = .paused
        #expect(app.handlePlaybackKeyDown(
            keyCode: 36,
            modifierFlagsRawValue: 0
        ))
        let session = try #require(app.playback.subtitleFocusSession)
        #expect(session.availableModules == [.current, .playlist])
        await app.playbackSubtitleFocusInitialLoadTask?.value
        #expect(session.selectedModule == .playlist)

        let playlistWindow = try #require(session.playlistWindow)
        #expect(playlistWindow.snapshot.totalCount == 30)
        #expect(playlistWindow.selectedOrdinal == 1)
        #expect(
            playlistWindow.item(at: 1)?.identity
                == .search(selectedResult.entryID)
        )

        for expectedOrdinal in 2...3 {
            #expect(session.requestKeyboardNavigation(.forward))
            let request = try #require(session.keyboardNavigationRequest)
            #expect(request.targetOrdinal == expectedOrdinal)
            let datasetID = try #require(playlistWindow.reelDatasetID)
            #expect(session.commitVirtualReelSelection(
                PlaybackVirtualReelSelectionCommit(
                    datasetID: AnyHashable(datasetID),
                    generation: playlistWindow.snapshot.generation,
                    ordinal: expectedOrdinal
                ),
                module: .playlist
            ))
            #expect(playlistWindow.selectedOrdinal == expectedOrdinal)
        }
    }
}

@MainActor
@Test
func playbackCommandPanelSearchSavesSelectedCue() async throws {
    try await withKeyboardActionApp { app, _ in
        let source = keyboardActionSource()
        app.search.replaceResidentResults([
            keyboardActionPlaylistSearchResult(
                id: 1,
                videoPath: source.videoPath,
                subtitlePath: source.subtitlePath,
                startMilliseconds: 0,
                content: "keyboard action cue 0"
            )
        ])
        app.playback.isPlaybackSurfaceExpanded = true
        #expect(app.presentPlaybackCommandPanelSearch(
            query: "keyboard",
            startsSearch: false
        ))

        #expect(app.handlePlaybackKeyDown(keyCode: 1, modifierFlagsRawValue: 0))
        await app.playbackSubtitleFocusActionTask?.value

        let savedShiori = try? app.shioriDatabase?.shiori(
            cueID: 1,
            listID: ShioriListIdentity.defaultListID
        )
        #expect(savedShiori != nil)
        #expect(app.playback.commandPanelPresentation?.page == .searchResults)
    }
}

@MainActor
@Test
func subtitleFocusCopyKeyCopiesExactCueAndKeepsPausedSession() async throws {
    try await withKeyboardActionApp { app, _ in
        let session = try #require(app.playback.beginSubtitleFocusSession(
            openSnapshot: keyboardActionOpenSnapshot(wasPlaying: true)
        ))
        let snapshot = keyboardActionSnapshot(
            lines: ["  exact first  ", "", "exact third"]
        )
        #expect(session.publishInitialSnapshot(snapshot, token: session.token))
        NSPasteboard.general.clearContents()

        #expect(app.handlePlaybackKeyDown(keyCode: 8, modifierFlagsRawValue: 0))
        #expect(NSPasteboard.general.string(forType: .string) == "  exact first  \n\nexact third")
        #expect(app.playback.subtitleFocusSession === session)
        #expect(session.activeKeyboardAction == nil)
        #expect(session.currentSnapshot?.selectedOrdinal == 12)
        #expect(app.playback.playbackStatus == .paused)
        #expect(app.playback.playbackViewModel?.feedback?.text == "Cue Text Copied")

        #expect(app.handlePlaybackKeyDown(keyCode: 7, modifierFlagsRawValue: 0))
        #expect(
            NSPasteboard.general.string(forType: .string)
                == "[exact first exact third](cueseeker://cue?id=13)"
        )
        #expect(
            app.playback.playbackViewModel?.feedback?.text
                == "Deep Link Copied"
        )

        #expect(app.handlePlaybackKeyDown(
            keyCode: 8,
            modifierFlagsRawValue: 0,
            isRepeat: true
        ))
        #expect(session.activeKeyboardAction == nil)
    }
}

@MainActor
@Test
func subtitleFocusShioriKeySavesIdempotentlyAndKeepsPausedSession() async throws {
    try await withKeyboardActionApp { app, database in
        let shioriDatabase = try #require(app.shioriDatabase)
        let session = try #require(app.playback.beginSubtitleFocusSession(
            openSnapshot: keyboardActionOpenSnapshot(wasPlaying: true)
        ))
        let snapshot = keyboardActionSnapshot(
            lines: ["  exact first  ", "", "exact third"]
        )
        #expect(session.publishInitialSnapshot(snapshot, token: session.token))
        let tableRevisionBefore = app.shiori.tableDataRevision

        #expect(app.handlePlaybackKeyDown(keyCode: 1, modifierFlagsRawValue: 0))
        try await waitForKeyboardActionState {
            session.activeKeyboardAction == nil
                && app.playback.playbackViewModel?.feedback?.text == "Shiori Saved"
        }

        let saved = try #require(try shioriDatabase.shiori(
            subtitleFile: URL(fileURLWithPath: keyboardActionSource().subtitlePath),
            startMilliseconds: 12_000,
            endMilliseconds: 12_900
        ))
        #expect(saved.content == "keyboard action cue 12")
        #expect(try shioriDatabase.shioriCount() == 1)
        #expect(app.shiori.tableDataRevision == tableRevisionBefore + 1)
        #expect(app.playback.subtitleFocusSession === session)
        #expect(session.currentSnapshot?.selectedOrdinal == 12)
        #expect(app.playback.playbackStatus == .paused)

        #expect(app.handlePlaybackKeyDown(keyCode: 1, modifierFlagsRawValue: 0))
        try await waitForKeyboardActionState {
            session.activeKeyboardAction == nil
                && app.playback.playbackViewModel?.feedback?.text
                    == "Shiori Already Saved"
        }

        #expect(try shioriDatabase.shioriCount() == 1)
        #expect(app.shiori.tableDataRevision == tableRevisionBefore + 1)
        #expect(app.playback.subtitleFocusSession === session)
        #expect(app.playback.playbackStatus == .paused)
    }
}

@MainActor
@Test
func subtitleFocusShioriIdentityDistinguishesSameTimeSiblingCues() async throws {
    try await withKeyboardActionApp { app, database in
        let shioriDatabase = try #require(app.shioriDatabase)
        let session = try #require(app.playback.beginSubtitleFocusSession(
            openSnapshot: keyboardActionOpenSnapshot(wasPlaying: false)
        ))
        var cues = (6..<16).map { keyboardActionCue(ordinal: $0) }
        let firstCue = keyboardActionSiblingCue(
            id: 13,
            ordinal: 12,
            eventIndex: 120,
            displayOrder: 0,
            content: "same-time first"
        )
        let secondCue = keyboardActionSiblingCue(
            id: 14,
            ordinal: 13,
            eventIndex: 121,
            displayOrder: 1,
            content: "same-time second"
        )
        cues[6] = firstCue
        cues[7] = secondCue
        let snapshot = SubtitleFocusSnapshot(
            totalCount: 20,
            selectedOrdinal: 12,
            cues: cues
        )
        #expect(session.publishInitialSnapshot(snapshot, token: session.token))
        let tableRevisionBefore = app.shiori.tableDataRevision

        #expect(app.handlePlaybackKeyDown(keyCode: 1, modifierFlagsRawValue: 0))
        try await waitForKeyboardActionState {
            session.activeKeyboardAction == nil
                && app.shiori.tableDataRevision == tableRevisionBefore + 1
        }
        #expect(session.commitNativeReelSelection(ordinal: 13))

        #expect(app.handlePlaybackKeyDown(keyCode: 1, modifierFlagsRawValue: 0))
        try await waitForKeyboardActionState {
            session.activeKeyboardAction == nil
                && app.shiori.tableDataRevision == tableRevisionBefore + 2
        }

        let savedFirst = try #require(try shioriDatabase.shiori(cueID: firstCue.id))
        let savedSecond = try #require(try shioriDatabase.shiori(cueID: secondCue.id))
        #expect(savedFirst.id != savedSecond.id)
        #expect(savedFirst.content == "keyboard action cue 12")
        #expect(savedSecond.content == "keyboard action cue 13")
        #expect(try shioriDatabase.shioriCount() == 2)

        #expect(app.handlePlaybackKeyDown(keyCode: 1, modifierFlagsRawValue: 0))
        try await waitForKeyboardActionState {
            session.activeKeyboardAction == nil
                && app.playback.playbackViewModel?.feedback?.text
                    == "Shiori Already Saved"
        }
        #expect(try shioriDatabase.shioriCount() == 2)
        #expect(app.shiori.tableDataRevision == tableRevisionBefore + 2)
        #expect(session.currentSnapshot?.selectedCue == secondCue)
        #expect(app.playback.playbackStatus == .paused)
    }
}

@MainActor
@Test
func subtitleFocusDownThenShioriSavesTheFinalSettledCue() async throws {
    try await withKeyboardActionApp { app, database in
        let shioriDatabase = try #require(app.shioriDatabase)
        let session = try #require(app.playback.beginSubtitleFocusSession(
            openSnapshot: keyboardActionOpenSnapshot(wasPlaying: false)
        ))
        #expect(session.publishInitialSnapshot(
            keyboardActionSnapshot(),
            token: session.token
        ))

        #expect(session.requestKeyboardNavigation(.forward))
        let navigation = try #require(session.keyboardNavigationRequest)
        #expect(session.requestKeyboardAction(.shiori) == .deferred)
        session.noteCueReelMotion(true)
        #expect(session.commitKeyboardNavigation(navigation))
        session.noteCueReelMotion(false)
        let execution = try #require(
            session.consumeDeferredKeyboardActionIfReady()
        )

        #expect(execution.context.cue.ordinal == 13)
        #expect(app.executePlaybackSubtitleFocusAction(execution))
        try await waitForKeyboardActionState {
            session.activeKeyboardAction == nil
                && app.playback.playbackViewModel?.feedback?.text == "Shiori Saved"
        }

        #expect(try shioriDatabase.shiori(cueID: 13) == nil)
        let saved = try #require(try shioriDatabase.shiori(cueID: 14))
        #expect(saved.content == "keyboard action cue 13")
        #expect(app.playback.subtitleFocusSession === session)
        #expect(session.currentSnapshot?.selectedOrdinal == 13)
        #expect(app.playback.playbackStatus == .paused)
    }
}

@MainActor
@Test
func playbackPlaylistCopyAndShioriTargetTheSettledPrimaryCue() async throws {
    try await withKeyboardActionApp { app, database in
        let shioriDatabase = try #require(app.shioriDatabase)
        let result = keyboardActionPlaylistSearchResult(
            id: 22,
            videoPath: keyboardActionSource().videoPath,
            subtitlePath: keyboardActionSource().subtitlePath,
            startMilliseconds: 21_000,
            content: "  playlist first  \n\nplaylist third"
        )
        let item = PlaybackPlaylistItem(searchResult: result, ordinal: 0)
        let (session, window) = try await beginKeyboardActionPlaylistSession(
            app: app,
            item: item
        )
        NSPasteboard.general.clearContents()

        #expect(app.handlePlaybackKeyDown(keyCode: 8, modifierFlagsRawValue: 0))
        #expect(
            NSPasteboard.general.string(forType: .string)
                == "  playlist first  \n\nplaylist third"
        )
        #expect(app.playback.playbackViewModel?.feedback?.text == "Cue Text Copied")

        #expect(app.handlePlaybackKeyDown(keyCode: 7, modifierFlagsRawValue: 0))
        #expect(
            NSPasteboard.general.string(forType: .string)
                == "[playlist first playlist third](cueseeker://cue?id=22)"
        )
        #expect(
            app.playback.playbackViewModel?.feedback?.text
                == "Deep Link Copied"
        )
        #expect(app.playback.subtitleFocusSession === session)
        #expect(window.selectedOrdinal == 0)

        #expect(app.handlePlaybackKeyDown(keyCode: 1, modifierFlagsRawValue: 0))
        try await waitForKeyboardActionState {
            session.activeKeyboardAction == nil
                && app.playback.playbackViewModel?.feedback?.text == "Shiori Saved"
        }
        let saved = try #require(try shioriDatabase.shiori(
            subtitleFile: URL(fileURLWithPath: result.subtitlePath),
            startMilliseconds: result.startMilliseconds,
            endMilliseconds: result.endMilliseconds
        ))

        #expect(saved.content == "keyboard action cue 21")
        #expect(saved.videoName == result.videoName)
        #expect(app.playback.subtitleFocusSession === session)
        #expect(window.selectedOrdinal == 0)
        #expect(app.playback.playbackStatus == .paused)

        session.noteCueReelMotion(true)
        #expect(app.handlePlaybackKeyDown(keyCode: 36, modifierFlagsRawValue: 0))
        #expect(session.pendingKeyboardAction == .playFromThisCue)
    }
}

@MainActor
@Test
func playbackPlaylistShioriItemReportsAlreadySavedWithoutCreatingAnotherRow() async throws {
    try await withKeyboardActionApp { app, database in
        let shioriDatabase = try #require(app.shioriDatabase)
        let shiori = Shiori(
            id: 801,
            subtitlePath: "/subtitle/playlist-shiori.ass",
            subtitleFormat: .ass,
            videoPath: "/video/playlist-shiori.mkv",
            videoName: "playlist-shiori.mkv",
            startMilliseconds: 31_000,
            endMilliseconds: 31_900,
            content: "existing playlist shiori",
            isValid: true,
            createdAt: "2026-07-15T00:00:00Z"
        )
        let item = PlaybackPlaylistItem(
            shiori: shiori,
            cuePresentation: nil,
            ordinal: 0
        )
        let (session, window) = try await beginKeyboardActionPlaylistSession(
            app: app,
            item: item
        )

        #expect(app.handlePlaybackKeyDown(keyCode: 1, modifierFlagsRawValue: 0))

        #expect(
            app.playback.playbackViewModel?.feedback?.text
                == "Shiori Already Saved"
        )
        #expect(try shioriDatabase.shioriCount() == 0)
        #expect(session.activeKeyboardAction == nil)
        #expect(app.playback.subtitleFocusSession === session)
        #expect(window.selectedOrdinal == 0)
    }
}

@MainActor
@Test
func playbackPlaylistEnterDispatchesSelectedTargetAndDestroysOverlaySession() async throws {
    try await withKeyboardActionApp { app, _ in
        let result = keyboardActionPlaylistSearchResult(
            id: 901,
            videoPath: "/video/playlist-target.mkv",
            subtitlePath: "/subtitle/playlist-target.ass",
            startMilliseconds: 41_000,
            content: "playlist play target"
        )
        let item = PlaybackPlaylistItem(searchResult: result, ordinal: 0)
        let (session, _) = try await beginKeyboardActionPlaylistSession(
            app: app,
            item: item
        )

        let execution: PlaybackSubtitleFocusActionExecution
        switch session.requestKeyboardAction(.playFromThisCue) {
        case .ready(let readyExecution):
            execution = readyExecution
        case .deferred, .rejected:
            Issue.record("Expected an immediately ready Playlist play action")
            return
        }
        var openedItem: PlaybackPlaylistItem?

        #expect(app.executePlaybackSubtitleFocusAction(
            execution,
            playCurrentCue: { _ in false },
            openPlaylistItem: { openedItem = $0 }
        ))

        #expect(app.playback.subtitleFocusSession == nil)
        #expect(session.state == .closed)
        #expect(openedItem == item)
        #expect(app.playback.playbackViewModel?.feedback?.text == "Play")
    }
}

@MainActor
@Test
func playbackOverlayPlayActionUsesExactCueThenDestroysSession() async throws {
    try await withKeyboardActionApp { app, _ in
        let session = try #require(app.playback.beginSubtitleFocusSession(
            openSnapshot: keyboardActionOpenSnapshot(wasPlaying: false)
        ))
        #expect(session.publishInitialSnapshot(
            keyboardActionSnapshot(),
            token: session.token
        ))
        let execution: PlaybackSubtitleFocusActionExecution
        switch session.requestKeyboardAction(.playFromThisCue) {
        case .ready(let readyExecution):
            execution = readyExecution
        case .deferred, .rejected:
            Issue.record("Expected an immediately ready play action")
            return
        }
        var receivedContext: PlaybackSubtitleFocusActionContext?
        app.settings.autoPauseAfterCueFinishesEnabled = true
        app.beginCueAutoStopPlayback()
        app.activateCueAutoStopBoundary(PlaybackAutoStopBoundary(
            startMilliseconds: 10_000,
            endMilliseconds: 20_000
        ))
        let itemGeneration = app.cuePlaybackGeneration
        let itemSettings = app.activePlaylistCueSettings

        let didExecute = app.executePlaybackSubtitleFocusAction(
            execution,
            playCurrentCue: { context in
                #expect(app.playback.subtitleFocusSession == nil)
                #expect(session.state == .closed)
                #expect(!session.isActive)
                receivedContext = context
                app.handleCueAutoPauseSeekCommitted(
                    toMilliseconds: context.cue.startMilliseconds
                )
                return true
            }
        )

        #expect(didExecute)
        #expect(receivedContext == execution.context)
        #expect(receivedContext?.cue.startMilliseconds == 12_000)
        #expect(app.cuePlaybackGeneration == itemGeneration)
        #expect(app.activePlaylistCueSettings == itemSettings)
        #expect(app.activeCueAutoPauseBoundary?.endMilliseconds == 20_000)
        #expect(app.cueAutoPauseArmed)
        #expect(app.playback.subtitleFocusSession == nil)
        #expect(session.state == .closed)
        #expect(app.playback.playbackStatus == .playing)
        #expect(app.playback.playbackViewModel?.feedback?.text == "Play")
    }
}

@MainActor
@Test
func subtitleFocusCommittedShioriInvalidatesRowsAfterActionIsSuperseded() async throws {
    try await withKeyboardActionApp { app, _ in
        let session = try #require(app.playback.beginSubtitleFocusSession(
            openSnapshot: keyboardActionOpenSnapshot(wasPlaying: false)
        ))
        #expect(session.publishInitialSnapshot(
            keyboardActionSnapshot(),
            token: session.token
        ))
        let execution: PlaybackSubtitleFocusActionExecution
        switch session.requestKeyboardAction(.shiori) {
        case .ready(let readyExecution):
            execution = readyExecution
        case .deferred, .rejected:
            Issue.record("Expected an immediately ready Shiori action")
            return
        }
        let tableRevisionBefore = app.shiori.tableDataRevision
        app.shiori.markTableRowsLoaded(totalSavedRowCount: 7)

        app.finishPlaybackSubtitleFocusShioriSave(
            .saved(
                listID: ShioriListIdentity.defaultListID,
                uniqueCueCount: 1
            ),
            execution,
            session: session,
            taskGeneration: .min
        )

        #expect(app.shiori.tableDataRevision == tableRevisionBefore + 1)
        #expect(app.shiori.tableRowsNeedReload)
        #expect(app.shiori.tableHasLoadedInitialPage)
        #expect(app.shiori.tableTotalSavedRowCount == 7)
        #expect(app.playback.subtitleFocusSession === session)
        #expect(session.activeKeyboardAction == execution)
        #expect(app.playback.playbackViewModel?.feedback == nil)
    }
}

@MainActor
private func withKeyboardActionApp(
    _ body: (AppCoordinator, IndexingDatabase) async throws -> Void
) async throws {
    let suiteName = "CueSeekerSubtitleFocusKeyboardActionTests-\(UUID().uuidString)"
    let userDefaults = try #require(UserDefaults(suiteName: suiteName))
    let fixtureRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "CueSeekerSubtitleFocusKeyboardActionTests-\(UUID().uuidString)",
            isDirectory: true
        )
    let databaseURL = fixtureRoot.appendingPathComponent("keyboard-actions.sqlite")
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
    let source = keyboardActionSource()
    try database.replaceEntries(
        subtitleFile: URL(fileURLWithPath: source.subtitlePath),
        videoFile: URL(fileURLWithPath: source.videoPath),
        entries: (0..<30).map { ordinal in
            let startMilliseconds = ordinal == 13 ? 12_000 : ordinal * 1_000
            return SubtitleEntry(
                sequenceNumber: ordinal + 1,
                startTimecode: "\(startMilliseconds)",
                endTimecode: "\(startMilliseconds + 900)",
                startMilliseconds: startMilliseconds,
                endMilliseconds: startMilliseconds + 900,
                text: "keyboard action cue \(ordinal)"
            )
        }
    )
    app.search.selectResult(SubtitleSearchResult(
        entryID: 1,
        subtitlePath: source.subtitlePath,
        subtitleFormat: source.subtitleFormat,
        videoPath: source.videoPath,
        videoName: "Keyboard Action Video",
        startMilliseconds: 12_000,
        endMilliseconds: 12_900,
        content: "selected cue",
        cueLines: ["selected cue"]
    ))
    app.playback.playbackViewModel = PlaybackViewModel(player: PlaybackPlayer())
    app.playback.playbackStatus = .paused
    try await body(app, database)
}

@MainActor
private func beginKeyboardActionPlaylistSession(
    app: AppCoordinator,
    item: PlaybackPlaylistItem
) async throws -> (
    PlaybackSubtitleFocusSessionStore,
    PlaybackPlaylistSessionWindowStore
) {
    let source = PlaybackPlaylistSource(
        kind: item.target.playbackPlaylistSourceKind,
        totalCount: 1
    ) { ordinal in
        ordinal == 0 ? item : nil
    }
    app.playback.setPlaylistSource(source)
    let session = try #require(app.playback.beginSubtitleFocusSession(
        openSnapshot: keyboardActionOpenSnapshot(wasPlaying: false)
    ))
    #expect(session.publishInitialSnapshot(
        keyboardActionSnapshot(),
        token: session.token
    ))
    let window = try #require(session.playlistWindow)
    #expect(window.snapshot.loadedItemCount == 1)
    #expect(session.selectedModule == .playlist)
    return (session, window)
}

private func keyboardActionPlaylistSearchResult(
    id: Int64,
    videoPath: String,
    subtitlePath: String,
    startMilliseconds: Int,
    content: String,
    displayTitle: String = "",
    cueGroupLines: [String]? = nil
) -> SubtitleSearchResult {
    SubtitleSearchResult(
        entryID: id,
        cueGroupID: id + 1,
        cueEventIndex: Int(id),
        cueDisplayOrder: 0,
        primaryGroupIndex: 0,
        subtitlePath: subtitlePath,
        subtitleFormat: .ass,
        videoPath: videoPath,
        videoName: URL(fileURLWithPath: videoPath).lastPathComponent,
        displayTitle: displayTitle,
        startMilliseconds: startMilliseconds,
        endMilliseconds: startMilliseconds + 900,
        content: content,
        cueLines: [content],
        cueGroupLines: cueGroupLines ?? [content],
        searchRank: 0
    )
}

private func keyboardActionRecentVideo(
    _ ordinal: Int
) -> RecentLibraryWatchingPresentation {
    RecentLibraryWatchingPresentation(
        videoFileID: Int64(ordinal + 1),
        subtitleFileID: Int64(ordinal + 101),
        videoPath: "/Media/Show/Episode-\(ordinal).mkv",
        videoName: "Episode-\(ordinal).mkv",
        duration: 100,
        subtitlePath: "/Media/Show/Episode-\(ordinal).srt",
        subtitleFormat: .srt,
        displayTitle: "Episode \(ordinal)",
        fileExtension: "mkv",
        folderPath: "/Media/Show",
        folderTitle: "Show",
        episodeNumber: ordinal + 1,
        positionMilliseconds: ordinal * 1_000,
        playbackDuration: 100,
        startedAt: "2026-07-29T00:00:00Z",
        completedAt: nil,
        updatedAt: "2026-07-29T00:00:00Z",
        coverPath: nil,
        coverRevision: nil
    )
}

private extension PlaybackPlaylistItemTarget {
    var playbackPlaylistSourceKind: PlaybackPlaylistSourceKind {
        switch self {
        case .search:
            .search
        case .shiori:
            .shiori
        }
    }
}

@MainActor
private func waitForKeyboardActionState(
    timeout: TimeInterval = 3,
    condition: () -> Bool
) async throws {
    let deadline = Date().addingTimeInterval(timeout)
    while !condition() {
        guard Date() < deadline else {
            throw PlaybackSubtitleFocusKeyboardActionTestError.timedOut
        }
        try await Task.sleep(nanoseconds: 10_000_000)
    }
}

private enum PlaybackSubtitleFocusKeyboardActionTestError: Error {
    case timedOut
}

private func keyboardActionOpenSnapshot(
    wasPlaying: Bool
) -> PlaybackSubtitleFocusOpenSnapshot {
    PlaybackSubtitleFocusOpenSnapshot(
        source: keyboardActionSource(),
        timestampMilliseconds: 12_500,
        wasPlaying: wasPlaying
    )
}

private func keyboardActionSource() -> SubtitleFocusSourceIdentity {
    SubtitleFocusSourceIdentity(
        videoPath: "/Media/Keyboard-Actions.mkv",
        subtitlePath: "/Media/Keyboard-Actions.srt",
        subtitleFormat: .srt
    )
}

private func keyboardActionSnapshot(
    lines: [String]? = nil
) -> SubtitleFocusSnapshot {
    SubtitleFocusSnapshot(
        totalCount: 20,
        selectedOrdinal: 12,
        cues: (6..<16).map { ordinal in
            keyboardActionCue(
                ordinal: ordinal,
                lines: ordinal == 12 ? lines : nil
            )
        }
    )
}

private func keyboardActionCue(
    ordinal: Int,
    lines: [String]? = nil
) -> SubtitleFocusCue {
    SubtitleFocusCue(
        id: Int64(ordinal + 1),
        cueGroupID: Int64(ordinal + 1_001),
        ordinal: ordinal,
        eventIndex: ordinal,
        displayOrder: 0,
        startMilliseconds: ordinal * 1_000,
        endMilliseconds: ordinal * 1_000 + 900,
        content: lines?.joined(separator: "\n") ?? "keyboard action cue \(ordinal)"
    )
}

private func keyboardActionSiblingCue(
    id: Int64,
    ordinal: Int,
    eventIndex: Int,
    displayOrder: Int,
    content: String
) -> SubtitleFocusCue {
    SubtitleFocusCue(
        id: id,
        cueGroupID: 500,
        ordinal: ordinal,
        eventIndex: eventIndex,
        displayOrder: displayOrder,
        startMilliseconds: 12_000,
        endMilliseconds: 12_900,
        content: content
    )
}

private func keyboardActionContext(
    cue: SubtitleFocusCue
) -> PlaybackSubtitleFocusActionContext {
    PlaybackSubtitleFocusActionContext(
        source: keyboardActionSource(),
        cue: cue
    )
}
