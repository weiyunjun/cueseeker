import AppKit
import Carbon.HIToolbox
@testable import CueSeekerApp
@testable import CueSeekerCore
import CueSeekerPlayback
import Foundation
import SwiftUI
import Testing

@Suite(.serialized)
@MainActor
struct WorkbenchAccessibilityStep4Tests {
    @Test
    func chromeVisibilityWakesHoldsAndReevaluatesOnAccessibilityFocus() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        let view = PlaybackChromeTrackingNSView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        window.contentView?.addSubview(view)

        let model = PlaybackChromeVisibilityModel()
        var pointer = NSPoint(x: 400, y: 300)
        model.hasWindowFocus = { _ in true }
        model.pointerScreenLocation = { window.convertPoint(toScreen: pointer) }
        AppCursorVisibility.resetForTesting()
        model.enterVideoPage()
        model.updatePlayerAreaView(view)
        defer {
            model.leaveVideoPage()
            AppCursorVisibility.resetForTesting()
        }

        // Idle timeout hides both Player UI and pointer.
        model.idleElapsed()
        #expect(!model.isPlayerUIVisible)
        #expect(!model.isPointerVisible)

        // Entering Accessibility focus wakes and holds Player UI visible without unhiding a hidden pointer.
        model.setAccessibilityFocused(true)
        #expect(model.isPlayerUIVisible)
        #expect(!model.isPointerVisible)
        #expect(!model.isIdleCountdownRunning)

        // Move pointer to wake pointer, then move outside window; while Accessibility focus is active, Player UI stays visible.
        pointer = NSPoint(x: 410, y: 300)
        model.pointerMovedInPlayerArea(view: view)
        #expect(model.isPointerVisible)
        pointer = NSPoint(x: -50, y: -50)
        model.pointerExitedPlayerArea(view: view)
        #expect(model.isPlayerUIVisible)

        // Clearing Accessibility focus when pointer is inside and idle starts the countdown again.
        pointer = NSPoint(x: 200, y: 200)
        model.setAccessibilityFocused(false)
        #expect(model.isIdleCountdownRunning)
        model.idleElapsed()
        #expect(!model.isPlayerUIVisible)

        // Menu open also holds Player UI visible and stops idle countdown.
        pointer = NSPoint(x: 210, y: 200)
        model.pointerMovedInPlayerArea(view: view)
        #expect(model.isPlayerUIVisible)
        model.setMenuOpen(true)
        #expect(!model.isIdleCountdownRunning)
        model.setMenuOpen(false)
        #expect(model.isIdleCountdownRunning)
    }

    @Test
    func playerStageAccessibilityTraversesNormalAndCueQueueTargetsAndControlsChromeVisibility() throws {
        try withStep4TestApp { app in
            app.playback.isPlaybackSurfaceExpanded = true

            app.playback.setChromeSnapshot(
                PlaybackChromeSnapshot(
                    displayTitle: "Step 4",
                    canGoPrevious: false,
                    canGoNext: false,
                    hasPlaybackSelection: true,
                    isCueQueuePlayback: true
                )
            )

            // Cue Queue playback targets (search result selected)
            let cueQueueTargets = app.currentPlaybackAccessibilityTargets()
            #expect(cueQueueTargets == [
                .playerReturn,
                .playerCommandPanel,
                .playerTask,
                .playerSettings,
                .playerAutoPause,
                .playerAutoSwitch,
                .playerAutoSwitchGapDecrease,
                .playerAutoSwitchGapIncrease,
                .playerPlayPause,
                .playerPrevious,
                .playerNext,
                .playerMute,
                .playerPlaybackOverlay,
                .playerRepeat,
                .playerCopyScreenshot,
                .playerSubtitlesMenu,
                .playerSpeedMenu,
                .playerMoreMenu,
                .playerFullscreen,
            ])

            // Tab wakes Player UI and focuses .playerReturn
            app.playback.chromeVisibility.enteringFullscreen()
            #expect(!app.playback.chromeVisibility.isPlayerUIVisible)
            #expect(app.handlePlaybackKeyDown(keyCode: 48, modifierFlagsRawValue: 0))
            #expect(app.workbenchAccessibility.focusedPlaybackTarget == .playerReturn)
            #expect(app.playback.chromeVisibility.isAccessibilityFocused)
            #expect(app.playback.chromeVisibility.isPlayerUIVisible)

            // Shift+Tab wraps to .playerFullscreen
            #expect(app.handlePlaybackKeyDown(
                keyCode: 48,
                modifierFlagsRawValue: NSEvent.ModifierFlags.shift.rawValue
            ))
            #expect(app.workbenchAccessibility.focusedPlaybackTarget == .playerFullscreen)

            // Controller R1 / L1 with auto-repeat traverses targets
            #expect(app.handlePlaybackControllerInput(.button(.rightShoulder, isRepeat: true)))
            #expect(app.workbenchAccessibility.focusedPlaybackTarget == .playerReturn)
            #expect(app.handlePlaybackControllerInput(.button(.leftShoulder, isRepeat: true)))
            #expect(app.workbenchAccessibility.focusedPlaybackTarget == .playerFullscreen)

            // Esc clears focus ring and updates chrome visibility state
            #expect(app.handlePlaybackKeyDown(keyCode: 53, modifierFlagsRawValue: 0))
            #expect(app.workbenchAccessibility.focusedPlaybackTarget == nil)
            #expect(!app.playback.chromeVisibility.isAccessibilityFocused)

            // Disabled Cue Queue buttons can be focused and are no-ops when activated
            app.settings.autoPauseAfterCueFinishesEnabled = false
            app.settings.autoSwitchToNextCuesInPlaylistEnabled = false
            app.applyPlaybackAccessibilityFocus(.playerAutoSwitch, surface: .playerStage)
            #expect(app.handlePlaybackKeyDown(keyCode: 49, modifierFlagsRawValue: 0))
            #expect(!app.settings.autoSwitchToNextCuesInPlaylistEnabled)

            // Activating .playerAutoPause enables auto-pause, then .playerAutoSwitch can toggle
            app.applyPlaybackAccessibilityFocus(.playerAutoPause, surface: .playerStage)
            #expect(app.handlePlaybackKeyDown(keyCode: 49, modifierFlagsRawValue: 0))
            #expect(app.settings.autoPauseAfterCueFinishesEnabled)

            app.applyPlaybackAccessibilityFocus(.playerAutoSwitch, surface: .playerStage)
            #expect(app.handlePlaybackControllerInput(.button(.south)))
            #expect(app.settings.autoSwitchToNextCuesInPlaylistEnabled)

            // Opening Speed Menu via Accessibility clears the focus ring
            app.applyPlaybackAccessibilityFocus(.playerSpeedMenu, surface: .playerStage)
            #expect(app.handlePlaybackKeyDown(keyCode: 36, modifierFlagsRawValue: 0))
            #expect(app.playback.isSpeedMenuOpen)
            #expect(app.workbenchAccessibility.focusedPlaybackTarget == nil)
            app.playback.closeSpeedMenu()

            // Normal video playback omits the 4 Cue Queue Control Bar buttons
            app.playback.clearChromeSnapshot()
            app.search.selectResult(nil)
            app.library.selectedLibraryVideo = LibraryVideo(
                videoPath: "/Media/Episode1.mkv",
                videoName: "Episode1.mkv",
                duration: 120,
                subtitlePath: "/Media/Episode1.srt",
                subtitleFormat: .srt
            )
            let normalTargets = app.currentPlaybackAccessibilityTargets()
            #expect(!normalTargets.contains(.playerAutoPause))
            #expect(normalTargets.first == .playerReturn)
            #expect(normalTargets.last == .playerFullscreen)
        }
    }

    @Test
    func playbackOverlayAccessibilityHandlesSubViewsAndVideoPlaylistSelectCoordination() throws {
        try withStep4TestApp { app in
            app.playback.isPlaybackSurfaceExpanded = true
            let session = try #require(app.playback.beginSubtitleFocusSession(
                openSnapshot: step4OpenSnapshot(),
                availableModules: PlaybackOverlayModule.allCases
            ))
            #expect(session.publishInitialSnapshot(
                step4CueSnapshot(),
                token: session.token
            ))

            // Current view targets
            #expect(app.currentPlaybackAccessibilityTargets() == [
                .overlayReturn,
                .overlayTab(.current),
                .overlayTab(.playlist),
                .overlayTab(.collage),
                .overlayCommandPanel,
                .overlayTask,
                .overlaySettings,
                .overlayFooterAction("excerpt"),
                .overlayFooterAction("copy-cue-text"),
                .overlayFooterAction("copy-deep-link"),
                .overlayFooterAction("play"),
            ])

            // Focus .overlayTab(.collage) and activate it -> switches to Collage tab and keeps focus on .overlayTab(.collage)
            app.applyPlaybackAccessibilityFocus(.overlayTab(.collage), surface: .playbackOverlay)
            #expect(app.handlePlaybackKeyDown(keyCode: 36, modifierFlagsRawValue: 0))
            #expect(session.isEditingCollage)
            #expect(session.selectedModule == .collage)
            #expect(app.workbenchAccessibility.focusedPlaybackTarget == .overlayTab(.collage))
            #expect(app.currentPlaybackAccessibilityTargets() == [
                .overlayReturn,
                .overlayTab(.current),
                .overlayTab(.playlist),
                .overlayTab(.collage),
                .overlayCommandPanel,
                .overlayTask,
                .overlaySettings,
                .overlayFooterAction("copy-collage"),
                .overlayFooterAction("export-collage"),
                .overlayFooterAction("select"),
            ])

            // First Esc clears focus ring; second Esc closes Playback Overlay
            #expect(app.handlePlaybackKeyDown(keyCode: 53, modifierFlagsRawValue: 0))
            #expect(app.workbenchAccessibility.focusedPlaybackTarget == nil)
            #expect(session.isEditingCollage)
            #expect(app.handlePlaybackKeyDown(keyCode: 53, modifierFlagsRawValue: 0))
            #expect(!session.isEditingCollage)
            #expect(app.playback.subtitleFocusSession == nil)

            // Video Playlist view with cards
            let videos = [step4Video(0), step4Video(1), step4Video(2)]
            app.library.completeLibraryFolderDetailStatusesByPath["/Media/Show"] = .completed
            app.library.completeLibraryFolderDetailsByPath["/Media/Show"] = CompleteLibraryFolderDetailPresentation(
                folderPath: "/Media/Show",
                folderTitle: "Show",
                videos: videos
            )
            let libraryStore = PlaybackLibrarySessionStore(
                libraryStore: app.library,
                folderPath: "/Media/Show",
                initialVideoPath: videos[0].videoPath
            )
            libraryStore.activate()
            libraryStore.selection.updateColumnCount(2)
            app.playback.releaseSubtitleFocusSession(session)
            let videoSession = try #require(app.playback.beginSubtitleFocusSession(
                openSnapshot: step4OpenSnapshot(),
                availableModules: [.current, .playlist],
                libraryStore: libraryStore
            ))
            #expect(videoSession.publishInitialSnapshot(
                step4CueSnapshot(),
                token: videoSession.token
            ))
            #expect(videoSession.selectModule(.playlist))
            #expect(videoSession.selectedModule == .playlist)

            // Focus Topbar button: arrow keys do NOT move Video Card Select
            app.applyPlaybackAccessibilityFocus(.overlayReturn, surface: .playbackOverlay)
            #expect(libraryStore.selection.selectedItemID == videos[0].id)
            #expect(app.handlePlaybackKeyDown(keyCode: 124, modifierFlagsRawValue: 0))
            #expect(libraryStore.selection.selectedItemID == videos[0].id)

            // Tab to card 1's More button -> syncs Select to card 1
            app.applyPlaybackAccessibilityFocus(
                .overlayVideoCardActionButton(videos[1].id),
                surface: .playbackOverlay
            )
            #expect(libraryStore.selection.selectedItemID == videos[1].id)

            // Pressing Left Arrow while on card 1's More button moves Select to card 0 and moves focus ring to card 0 body
            #expect(app.handlePlaybackKeyDown(keyCode: 123, modifierFlagsRawValue: 0))
            #expect(libraryStore.selection.selectedItemID == videos[0].id)
            #expect(app.workbenchAccessibility.focusedPlaybackTarget == .overlayVideoCard(videos[0].id))
        }
    }

    @Test
    func commandPanelAccessibilityCoordinatesRootRecentGridsAndSearchResults() throws {
        try withStep4TestApp { app in
            app.playback.isPlaybackSurfaceExpanded = true
            app.library.testRecentWatchingItems = [
                step4RecentVideo(0),
                step4RecentVideo(1),
                step4RecentVideo(2),
            ]

            #expect(app.presentPlaybackCommandPanel())
            #expect(app.currentPlaybackAccessibilityTargets() == [
                .commandPanelSearchField,
                .commandPanelRootOption(0),
                .commandPanelRootOption(1),
                .commandPanelFooterAction("open"),
            ])

            // First Tab focuses .commandPanelSearchField; Up/Down does NOT move option Select while search field has focus ring
            #expect(app.handlePlaybackKeyDown(keyCode: 48, modifierFlagsRawValue: 0))
            #expect(app.workbenchAccessibility.focusedPlaybackTarget == .commandPanelSearchField)
            #expect(app.playback.commandPanelPresentation?.selectedOrdinal == 0)
            #expect(app.handlePlaybackKeyDown(keyCode: 125, modifierFlagsRawValue: 0))
            #expect(app.playback.commandPanelPresentation?.selectedOrdinal == 0)

            // Non-empty query adds .commandPanelSearchClearButton and 3rd root option
            app.updatePlaybackCommandPanelQuery("hello")
            #expect(app.currentPlaybackAccessibilityTargets() == [
                .commandPanelSearchField,
                .commandPanelSearchClearButton,
                .commandPanelRootOption(0),
                .commandPanelRootOption(1),
                .commandPanelRootOption(2),
                .commandPanelFooterAction("open"),
            ])

            // Tab to Clear Button, then Tab to Option 0, then Tab to Option 1 -> syncs selectedOrdinal
            #expect(app.handlePlaybackKeyDown(keyCode: 48, modifierFlagsRawValue: 0))
            #expect(app.workbenchAccessibility.focusedPlaybackTarget == .commandPanelSearchClearButton)
            #expect(app.handlePlaybackKeyDown(keyCode: 48, modifierFlagsRawValue: 0))
            #expect(app.workbenchAccessibility.focusedPlaybackTarget == .commandPanelRootOption(0))
            #expect(app.playback.commandPanelPresentation?.selectedOrdinal == 0)
            #expect(app.handlePlaybackKeyDown(keyCode: 48, modifierFlagsRawValue: 0))
            #expect(app.workbenchAccessibility.focusedPlaybackTarget == .commandPanelRootOption(1))
            #expect(app.playback.commandPanelPresentation?.selectedOrdinal == 1)

            // Down arrow on Option 1 moves Select and focus ring to Option 2 (Recent Excerpt Lists)
            #expect(app.handlePlaybackKeyDown(keyCode: 125, modifierFlagsRawValue: 0))
            #expect(app.workbenchAccessibility.focusedPlaybackTarget == .commandPanelRootOption(2))
            #expect(app.playback.commandPanelPresentation?.selectedOrdinal == 2)

            // Up arrow moves back to Option 1 (Recent Videos), then activate -> opens Recent Videos and clears focus ring
            #expect(app.handlePlaybackKeyDown(keyCode: 126, modifierFlagsRawValue: 0))
            #expect(app.workbenchAccessibility.focusedPlaybackTarget == .commandPanelRootOption(1))
            #expect(app.playback.commandPanelPresentation?.selectedOrdinal == 1)
            #expect(app.handlePlaybackKeyDown(keyCode: 36, modifierFlagsRawValue: 0))
            #expect(app.playback.commandPanelPresentation?.page == .recentVideos)
            #expect(app.workbenchAccessibility.focusedPlaybackTarget == nil)

            app.library.testRecentWatchingItems = [
                step4RecentVideo(0),
                step4RecentVideo(1),
                step4RecentVideo(2),
            ]
            app.synchronizePlaybackCommandPanelSelection()
            app.updatePlaybackCommandPanelRecentCardGridLayout(columnCount: 2)
            let recentIDs = app.library.testRecentWatchingItems.map(\.id)
            #expect(app.currentPlaybackAccessibilityTargets() == [
                .commandPanelBackButton,
                .commandPanelRecentCard(recentIDs[0]),
                .commandPanelRecentCardActionButton(recentIDs[0]),
                .commandPanelRecentCard(recentIDs[1]),
                .commandPanelRecentCardActionButton(recentIDs[1]),
                .commandPanelRecentCard(recentIDs[2]),
                .commandPanelRecentCardActionButton(recentIDs[2]),
                .commandPanelFooterAction("open"),
            ])

            // Focus Back Button: arrow keys do NOT move card Select, and Return activates Back Button instead of opening card
            #expect(app.handlePlaybackKeyDown(keyCode: 48, modifierFlagsRawValue: 0))
            #expect(app.workbenchAccessibility.focusedPlaybackTarget == .commandPanelBackButton)
            #expect(app.handlePlaybackKeyDown(keyCode: 124, modifierFlagsRawValue: 0))
            #expect(app.playback.commandPanelPresentation?.selectedOrdinal == 0)

            // Tab to Card 0, then Right Arrow moves Select and focus ring to Card 1
            #expect(app.handlePlaybackKeyDown(keyCode: 48, modifierFlagsRawValue: 0))
            #expect(app.workbenchAccessibility.focusedPlaybackTarget == .commandPanelRecentCard(recentIDs[0]))
            #expect(app.handlePlaybackKeyDown(keyCode: 124, modifierFlagsRawValue: 0))
            #expect(app.playback.commandPanelPresentation?.selectedOrdinal == 1)
            #expect(app.workbenchAccessibility.focusedPlaybackTarget == .commandPanelRecentCard(recentIDs[1]))

            // Focus Back Button and activate with controller South (✕) -> returns to Root
            app.applyPlaybackAccessibilityFocus(.commandPanelBackButton, surface: .commandPanel(.recentVideos))
            #expect(app.handlePlaybackControllerInput(.button(.south)))
            #expect(app.playback.commandPanelPresentation?.page == .root)
            #expect(app.workbenchAccessibility.focusedPlaybackTarget == nil)

            // Open Search Results and verify targets
            #expect(app.presentPlaybackCommandPanelSearch(query: "hello", startsSearch: false))
            #expect(app.currentPlaybackAccessibilityTargets() == [
                .commandPanelBackButton,
                .commandPanelFilterButton,
                .commandPanelSortButton,
                .commandPanelFooterAction("excerpt"),
                .commandPanelFooterAction("copy-cue-text"),
                .commandPanelFooterAction("copy-deep-link"),
                .commandPanelFooterAction("play"),
            ])
        }
    }

    @Test
    func playerTopBarAndOverlayTopBarReRenderFocusRingAcrossAllButtons() throws {
        try withStep4TestApp { app in
            app.playback.isPlaybackSurfaceExpanded = true

            // 1. Host LiquidGlassVideoTopBar and verify every button re-renders on Tab
            let playerTopBarView = LiquidGlassVideoTopBar(
                title: "Step4.mkv",
                onReturn: {}
            )
            .environment(\.workbenchAccessibility, app.workbenchAccessibility)
            .environmentObject(app)
            .environmentObject(app.settings.localization)
            .environmentObject(app.settings.playbackShortcuts)

            let playerWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 900, height: 60),
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            let playerHost = NSHostingView(rootView: playerTopBarView)
            playerHost.frame = NSRect(x: 0, y: 0, width: 900, height: 60)
            playerWindow.contentView = playerHost
            playerHost.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.02))

            let expectedPlayerTopBarSequence: [(PlaybackAccessibilityTarget, AppIcon)] = [
                (.playerReturn, .caretLeft),
                (.playerCommandPanel, .magnifyingGlass),
                (.playerTask, .tray),
                (.playerSettings, .gear),
            ]
            for (expectedTarget, expectedIcon) in expectedPlayerTopBarSequence {
                WorkbenchIconButton.lastFocusedIconForTesting = nil
                #expect(app.handlePlaybackKeyDown(keyCode: 48, modifierFlagsRawValue: 0))
                #expect(app.workbenchAccessibility.focusedPlaybackTarget == expectedTarget)
                playerHost.layoutSubtreeIfNeeded()
                RunLoop.main.run(until: Date().addingTimeInterval(0.02))
                #expect(WorkbenchIconButton.lastFocusedIconForTesting == expectedIcon)
            }

            // 2. Host PlaybackOverlayTopBar and verify Return, Tabs, Command Panel, Task, and Settings re-render on Tab
            let session = try #require(app.playback.beginSubtitleFocusSession(
                openSnapshot: step4OpenSnapshot(),
                availableModules: [.current, .playlist]
            ))
            #expect(session.publishInitialSnapshot(
                step4CueSnapshot(),
                token: session.token
            ))
            app.reconcilePlaybackAccessibilityFocus()

            let overlayTopBarView = PlaybackOverlayTopBar(
                modules: session.availableModules,
                selectedModule: session.selectedModule,
                onSelect: session.selectModule,
                onReturn: {}
            )
            .environment(\.workbenchAccessibility, app.workbenchAccessibility)
            .environmentObject(app)
            .environmentObject(app.settings.localization)
            .environmentObject(app.settings.playbackShortcuts)

            let overlayHost = NSHostingView(rootView: overlayTopBarView)
            overlayHost.frame = NSRect(x: 0, y: 0, width: 900, height: 60)
            playerWindow.contentView = overlayHost
            overlayHost.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.02))

            // 1st Tab -> .overlayReturn (.caretLeft)
            WorkbenchIconButton.lastFocusedIconForTesting = nil
            #expect(app.handlePlaybackKeyDown(keyCode: 48, modifierFlagsRawValue: 0))
            #expect(app.workbenchAccessibility.focusedPlaybackTarget == .overlayReturn)
            overlayHost.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.02))
            #expect(WorkbenchIconButton.lastFocusedIconForTesting == .caretLeft)

            // 2nd & 3rd Tab -> .overlayTab(.current), .overlayTab(.playlist)
            #expect(app.handlePlaybackKeyDown(keyCode: 48, modifierFlagsRawValue: 0))
            #expect(app.workbenchAccessibility.focusedPlaybackTarget == .overlayTab(.current))
            #expect(app.handlePlaybackKeyDown(keyCode: 48, modifierFlagsRawValue: 0))
            #expect(app.workbenchAccessibility.focusedPlaybackTarget == .overlayTab(.playlist))

            // 4th..6th Tab -> .overlayCommandPanel, .overlayTask, .overlaySettings
            let expectedOverlayTrailingSequence: [(PlaybackAccessibilityTarget, AppIcon)] = [
                (.overlayCommandPanel, .magnifyingGlass),
                (.overlayTask, .tray),
                (.overlaySettings, .gear),
            ]
            for (expectedTarget, expectedIcon) in expectedOverlayTrailingSequence {
                WorkbenchIconButton.lastFocusedIconForTesting = nil
                #expect(app.handlePlaybackKeyDown(keyCode: 48, modifierFlagsRawValue: 0))
                #expect(app.workbenchAccessibility.focusedPlaybackTarget == expectedTarget)
                overlayHost.layoutSubtreeIfNeeded()
                RunLoop.main.run(until: Date().addingTimeInterval(0.02))
                #expect(WorkbenchIconButton.lastFocusedIconForTesting == expectedIcon)
            }
        }
    }

    @Test
    func playbackCueFooterReRendersFocusRingAcrossOverlayAndCommandPanelActions() throws {
        try withStep4TestApp { app in
            defer {
                PlaybackCueFooter.lastFocusedActionIDForTesting = nil
            }
            app.playback.isPlaybackSurfaceExpanded = true

            let session = try #require(app.playback.beginSubtitleFocusSession(
                openSnapshot: step4OpenSnapshot(),
                availableModules: [.current, .playlist]
            ))
            #expect(session.publishInitialSnapshot(
                step4CueSnapshot(),
                token: session.token
            ))
            app.reconcilePlaybackAccessibilityFocus()

            let overlayFooterView = PlaybackCueFooter(
                surface: .playbackOverlay,
                status: "5 cues",
                actions: PlaybackCueFooterAction.cueActions(
                    playTitle: "Play",
                    request: { _ in }
                )
            )
            .environment(\.workbenchAccessibility, app.workbenchAccessibility)
            .environmentObject(app)
            .environmentObject(app.playback)
            .environmentObject(app.settings.localization)

            let footerWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 900, height: 60),
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            let overlayFooterHost = NSHostingView(rootView: overlayFooterView)
            overlayFooterHost.frame = NSRect(x: 0, y: 0, width: 900, height: 60)
            footerWindow.contentView = overlayFooterHost
            overlayFooterHost.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.02))

            for expectedActionID in ["excerpt", "copy-cue-text", "copy-deep-link", "play"] {
                PlaybackCueFooter.lastFocusedActionIDForTesting = nil
                app.applyPlaybackAccessibilityFocus(
                    .overlayFooterAction(expectedActionID),
                    surface: .playbackOverlay
                )
                overlayFooterHost.layoutSubtreeIfNeeded()
                RunLoop.main.run(until: Date().addingTimeInterval(0.02))
                #expect(PlaybackCueFooter.lastFocusedActionIDForTesting == expectedActionID)
            }

            // Command Panel footer actions
            #expect(app.presentPlaybackCommandPanel())
            let commandPanelFooterView = PlaybackCueFooter(
                surface: .commandPanel,
                status: nil,
                actions: [
                    .primary(id: "open", title: "Open", perform: {}),
                ]
            )
            .environment(\.workbenchAccessibility, app.workbenchAccessibility)
            .environmentObject(app)
            .environmentObject(app.playback)
            .environmentObject(app.settings.localization)

            let commandPanelFooterHost = NSHostingView(rootView: commandPanelFooterView)
            commandPanelFooterHost.frame = NSRect(x: 0, y: 0, width: 900, height: 60)
            footerWindow.contentView = commandPanelFooterHost
            commandPanelFooterHost.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.02))

            PlaybackCueFooter.lastFocusedActionIDForTesting = nil
            app.applyPlaybackAccessibilityFocus(
                .commandPanelFooterAction("open"),
                surface: .commandPanel(.root)
            )
            commandPanelFooterHost.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.02))
            #expect(PlaybackCueFooter.lastFocusedActionIDForTesting == "open")
        }
    }
}

@MainActor
private func withStep4TestApp(
    _ body: (AppCoordinator) throws -> Void
) throws {
    let suiteName = "CueSeekerAccessibilityStep4Tests-\(UUID().uuidString)"
    let userDefaults = try #require(UserDefaults.temporary(suiteName: suiteName))
    let fixtureRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "CueSeekerAccessibilityStep4Tests-\(UUID().uuidString)",
            isDirectory: true
        )
    let databaseURL = fixtureRoot.appendingPathComponent("step4.sqlite")
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
    app.search.selectResult(SubtitleSearchResult(
        entryID: 1,
        subtitlePath: "/Media/Step4.srt",
        subtitleFormat: .srt,
        videoPath: "/Media/Step4.mkv",
        videoName: "Step4.mkv",
        startMilliseconds: 1_000,
        endMilliseconds: 2_000,
        content: "step 4 cue",
        cueLines: ["step 4 cue"]
    ))
    app.playback.playbackViewModel = PlaybackViewModel(player: PlaybackPlayer())
    app.playback.playbackStatus = .paused
    try body(app)
}

private func step4OpenSnapshot() -> PlaybackSubtitleFocusOpenSnapshot {
    PlaybackSubtitleFocusOpenSnapshot(
        source: SubtitleFocusSourceIdentity(
            videoPath: "/Media/Step4.mkv",
            subtitlePath: "/Media/Step4.srt",
            subtitleFormat: .srt
        ),
        timestampMilliseconds: 1_500,
        wasPlaying: false
    )
}

private func step4CueSnapshot() -> SubtitleFocusSnapshot {
    var cues: [SubtitleFocusCue] = []
    for ordinal in 0..<5 {
        cues.append(
            SubtitleFocusCue(
                id: Int64(ordinal + 1),
                cueGroupID: Int64(ordinal + 101),
                ordinal: ordinal,
                eventIndex: ordinal,
                displayOrder: 0,
                startMilliseconds: ordinal * 1_000,
                endMilliseconds: ordinal * 1_000 + 800,
                content: "cue \(ordinal)"
            )
        )
    }
    return SubtitleFocusSnapshot(
        totalCount: 5,
        selectedOrdinal: 2,
        cues: cues
    )
}

private func step4Video(_ index: Int) -> CompleteLibraryVideoPresentation {
    CompleteLibraryVideoPresentation(
        videoFileID: Int64(index + 1),
        subtitleFileID: Int64(index + 101),
        videoPath: "/Media/Show/Ep\(index).mkv",
        videoName: "Ep\(index).mkv",
        fileSize: 1_024,
        videoCodec: "h264",
        videoWidth: 1_920,
        videoHeight: 1_080,
        frameRate: 24,
        duration: 120,
        subtitlePath: "/Media/Show/Ep\(index).srt",
        subtitleFormat: .srt,
        displayTitle: "Ep \(index)",
        fileExtension: "mkv",
        episodeNumber: index + 1,
        positionMilliseconds: 1_000,
        playbackDuration: 120,
        startedAt: "2026-07-22T00:00:00Z",
        completedAt: nil,
        historyUpdatedAt: "2026-07-22T00:00:00Z",
        coverPath: nil,
        coverRevision: nil
    )
}

private func step4RecentVideo(_ index: Int) -> RecentLibraryWatchingPresentation {
    RecentLibraryWatchingPresentation(
        videoFileID: Int64(index + 1),
        subtitleFileID: Int64(index + 101),
        videoPath: "/Media/Show/Ep\(index).mkv",
        videoName: "Ep\(index).mkv",
        duration: 100,
        subtitlePath: "/Media/Show/Ep\(index).srt",
        subtitleFormat: .srt,
        displayTitle: "Episode \(index)",
        fileExtension: "mkv",
        folderPath: "/Media/Show",
        folderTitle: "Show",
        episodeNumber: index + 1,
        positionMilliseconds: 1_000,
        playbackDuration: 100,
        startedAt: "2026-07-29T00:00:00Z",
        completedAt: nil,
        updatedAt: "2026-07-29T00:00:00Z",
        coverPath: nil,
        coverRevision: nil
    )
}

