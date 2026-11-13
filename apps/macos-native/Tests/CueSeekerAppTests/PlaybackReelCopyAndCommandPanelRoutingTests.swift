import AppKit
import Carbon.HIToolbox
import CueSeekerCore
import CueSeekerPlayback
import SwiftUI
import Testing
@testable import CueSeekerApp

@MainActor
@Suite(.serialized)
struct PlaybackReelCopyAndCommandPanelRoutingTests {
    @Test
    func commandPanelSecondaryPagesPassThroughCmdCAndWindowCopySucceedsForTitleSectionEmptyHintAndFooter() async throws {
        WorkbenchStaticTextSelectionCoordinator.shared.clearSelection()
        defer { WorkbenchStaticTextSelectionCoordinator.shared.clearSelection() }

        try await withRoutingCopyTestApp { app, _ in
            app.playback.isPlaybackSurfaceExpanded = true
            let nonEditableState = PlaybackKeyboardTextInputState(
                isEditableFocused: false,
                hasMarkedText: false
            )

            // 1. Search Results secondary page: Cmd + C, Cmd + , and Cmd + Q pass through without altering playback.
            #expect(app.presentPlaybackCommandPanelSearch(query: "cue", startsSearch: false))
            #expect(app.playback.commandPanelPresentation?.page == .searchResults)

            #expect(!app.handlePlaybackKeyDown(
                keyCode: UInt16(kVK_ANSI_C),
                modifierFlagsRawValue: NSEvent.ModifierFlags.command.rawValue,
                textInputState: nonEditableState
            ))
            #expect(!app.handlePlaybackKeyDown(
                keyCode: UInt16(kVK_ANSI_Comma),
                modifierFlagsRawValue: NSEvent.ModifierFlags.command.rawValue,
                textInputState: nonEditableState
            ))
            #expect(!app.handlePlaybackKeyDown(
                keyCode: UInt16(kVK_ANSI_Q),
                modifierFlagsRawValue: NSEvent.ModifierFlags.command.rawValue,
                textInputState: nonEditableState
            ))

            // Even with an explicit focus target on the secondary page, Cmd + C still passes through.
            app.applyPlaybackAccessibilityFocus(.commandPanelBackButton, surface: .commandPanel(.searchResults))
            #expect(!app.handlePlaybackKeyDown(
                keyCode: UInt16(kVK_ANSI_C),
                modifierFlagsRawValue: NSEvent.ModifierFlags.command.rawValue,
                textInputState: nonEditableState
            ))

            // Plain Space still stays absorbed by the Command Panel rather than falling through to Player Stage.
            app.applyPlaybackAccessibilityFocus(nil, surface: .commandPanel(.searchResults))
            #expect(app.handlePlaybackKeyDown(
                keyCode: 49,
                modifierFlagsRawValue: 0,
                textInputState: nonEditableState
            ))
            #expect(app.playback.playbackStatus == .paused)

            // 2. Recent Videos secondary page passes through Cmd + C (focused & unfocused).
            #expect(app.presentPlaybackCommandPanel())
            app.updatePlaybackCommandPanelQuery("")
            #expect(app.handlePlaybackKeyDown(keyCode: 36, modifierFlagsRawValue: 0, textInputState: nonEditableState))
            #expect(app.playback.commandPanelPresentation?.page == .recentVideos)
            #expect(!app.handlePlaybackKeyDown(
                keyCode: UInt16(kVK_ANSI_C),
                modifierFlagsRawValue: NSEvent.ModifierFlags.command.rawValue,
                textInputState: nonEditableState
            ))
            app.applyPlaybackAccessibilityFocus(.commandPanelFooterAction("open"), surface: .commandPanel(.recentVideos))
            #expect(!app.handlePlaybackKeyDown(
                keyCode: UInt16(kVK_ANSI_C),
                modifierFlagsRawValue: NSEvent.ModifierFlags.command.rawValue,
                textInputState: nonEditableState
            ))

            // 3. Recent Excerpt Lists secondary page passes through Cmd + C (focused & unfocused).
            #expect(app.presentPlaybackCommandPanel())
            app.updatePlaybackCommandPanelQuery("")
            #expect(app.handlePlaybackKeyDown(keyCode: 125, modifierFlagsRawValue: 0, textInputState: nonEditableState))
            #expect(app.handlePlaybackKeyDown(keyCode: 36, modifierFlagsRawValue: 0, textInputState: nonEditableState))
            #expect(app.playback.commandPanelPresentation?.page == .recentExcerpts)
            #expect(!app.handlePlaybackKeyDown(
                keyCode: UInt16(kVK_ANSI_C),
                modifierFlagsRawValue: NSEvent.ModifierFlags.command.rawValue,
                textInputState: nonEditableState
            ))

            // 4. Selecting secondary page title, section title, empty-state hint, or footer status count
            //    enables Edit -> Copy validation and copies via Cmd + C (performKeyEquivalent) and copy(_:).
            let layers = InterfaceLayerRegistry()
            layers.setOpen(.playbackPage, true)
            layers.setOpen(.commandPanel, true)

            let panelSurface = VStack(alignment: .leading, spacing: 12) {
                WorkbenchSelectableText(
                    "Search Results",
                    fontSize: 16,
                    weight: .semibold,
                    color: .primary
                )
                RecentSectionTitleView(title: "Today")
                WorkbenchEmptyHint(icon: .searchNoResults, message: "No matching subtitles found")
                WorkbenchSelectableText(
                    "12 / 120 cues",
                    fontSize: 13,
                    weight: .regular,
                    color: .secondary
                )
            }
            .padding(20)
            .environment(\.interfaceLayers, layers)
            .environment(\.interfaceLayerContext, InterfaceLayerContext(layer: .commandPanel, frozenLayers: layers.frozenLayers))

            let (window, hostingView) = makeOffscreenCueWindow(rootView: panelSurface, size: CGSize(width: 560, height: 320))
            defer { tearDownOffscreenWindow(window) }

            let selectableViews = collectSelectableTextViews(in: hostingView)
            let expectedTexts = ["Search Results", "Today", "No matching subtitles found", "12 / 120 cues"]
            let copyMenuItem = makeCopyMenuItem()
            let pasteboard = NSPasteboard.general

            for expected in expectedTexts {
                let targetView = try #require(selectableViews.first { $0.text == expected })
                selectWholeStaticTextView(targetView, in: window)

                #expect(WorkbenchStaticTextSelectionCoordinator.shared.selectedText == expected)
                #expect(!app.handlePlaybackKeyDown(
                    keyCode: UInt16(kVK_ANSI_C),
                    modifierFlagsRawValue: NSEvent.ModifierFlags.command.rawValue,
                    textInputState: nonEditableState,
                    window: window
                ))
                #expect(window.validateMenuItem(copyMenuItem))

                pasteboard.clearContents()
                #expect(window.performKeyEquivalent(with: makeCommandCEvent(windowNumber: window.windowNumber)))
                #expect(pasteboard.string(forType: .string) == expected)

                pasteboard.clearContents()
                window.copy(nil)
                #expect(pasteboard.string(forType: .string) == expected)
            }
        }
    }

    @Test
    func customCommandCPlaybackAndOverlayShortcutsYieldToActiveStaticOrReelSelectionAndResumeAfterClear() async throws {
        WorkbenchStaticTextSelectionCoordinator.shared.clearSelection()
        NotificationCenter.default.post(name: .cueSeekerClearTextSelection, object: nil)
        defer {
            WorkbenchStaticTextSelectionCoordinator.shared.clearSelection()
            NotificationCenter.default.post(name: .cueSeekerClearTextSelection, object: nil)
        }

        try await withRoutingCopyTestApp { app, _ in
            let viewModel = try #require(app.playback.playbackViewModel)
            app.playback.isPlaybackSurfaceExpanded = true
            let nonEditableState = PlaybackKeyboardTextInputState(
                isEditableFocused: false,
                hasMarkedText: false
            )
            let cmdC = PlaybackShortcutKey(keyCode: UInt16(kVK_ANSI_C), command: true)

            var playPauseCmdCKeymap = PlaybackShortcutKeymap.defaults
            playPauseCmdCKeymap.set(cmdC, for: .playPause)

            var openPanelCmdCKeymap = PlaybackShortcutKeymap.defaults
            openPanelCmdCKeymap.set(cmdC, for: .openCommandPanel)

            var overlayCopyCueCmdCKeymap = PlaybackShortcutKeymap.defaults
            overlayCopyCueCmdCKeymap.set(cmdC, for: .copyCueText)

            // Part A: Active static text selection overrides custom `Cmd + C` playback/command-panel shortcuts.
            let layers = app.interfaceLayers
            layers.setOpen(.playbackPage, true)

            let (staticWindow, staticHost) = makeOffscreenCueWindow(
                rootView: WorkbenchSelectableText("Episode Header Title")
                    .padding(16)
                    .environment(\.interfaceLayers, layers)
                    .environment(\.interfaceLayerContext, InterfaceLayerContext(layer: .playbackPage, frozenLayers: layers.frozenLayers)),
                size: CGSize(width: 440, height: 140)
            )
            defer { tearDownOffscreenWindow(staticWindow) }

            let staticView = try #require(collectSelectableTextViews(in: staticHost).first)
            selectWholeStaticTextView(staticView, in: staticWindow)
            #expect(WorkbenchStaticTextSelectionCoordinator.shared.selectedText == "Episode Header Title")

            #expect(!app.handlePlaybackKeyDown(
                keyCode: UInt16(kVK_ANSI_C),
                modifierFlagsRawValue: NSEvent.ModifierFlags.command.rawValue,
                textInputState: nonEditableState,
                shortcuts: playPauseCmdCKeymap,
                window: staticWindow
            ))
            #expect(app.playback.playbackStatus == .paused)

            #expect(!app.handlePlaybackKeyDown(
                keyCode: UInt16(kVK_ANSI_C),
                modifierFlagsRawValue: NSEvent.ModifierFlags.command.rawValue,
                textInputState: nonEditableState,
                shortcuts: openPanelCmdCKeymap,
                window: staticWindow
            ))
            #expect(app.playback.commandPanelPresentation == nil)

            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            #expect(staticWindow.performKeyEquivalent(with: makeCommandCEvent(windowNumber: staticWindow.windowNumber)))
            #expect(pasteboard.string(forType: .string) == "Episode Header Title")

            // After clearing static selection, custom `Cmd + C` shortcuts fire normally again.
            WorkbenchStaticTextSelectionCoordinator.shared.clearSelection()
            #expect(app.handlePlaybackKeyDown(
                keyCode: UInt16(kVK_ANSI_C),
                modifierFlagsRawValue: NSEvent.ModifierFlags.command.rawValue,
                textInputState: nonEditableState,
                shortcuts: playPauseCmdCKeymap,
                window: staticWindow
            ))
            #expect(app.playback.playbackStatus == .playing)
            app.playback.playbackStatus = .paused

            // Part B: Active subtitle reel selection overrides custom `Cmd + C` overlay & playback shortcuts.
            let session = try #require(app.playback.beginSubtitleFocusSession(
                openSnapshot: routingTestOpenSnapshot(wasPlaying: false)
            ))
            #expect(session.publishInitialSnapshot(
                routingTestSnapshot(line: "custom command c cue line"),
                token: session.token
            ))
            viewModel.feedback = nil
            layers.setOpen(.playbackOverlay, true)

            let (reelView, reelWindow) = makeMountedCurrentReel(
                cues: [routingTestCue(ordinal: 0, content: "custom command c cue line")],
                interfaceLayers: layers,
                menuOwner: .playbackOverlay
            )
            defer { tearDownReelWindow(reelView: reelView, window: reelWindow) }

            let selectedSubstring = try dragSelectPartialText(at: 0, in: reelView, window: reelWindow)
            #expect(!selectedSubstring.isEmpty)
            #expect(selectedSubstring != "custom command c cue line")
            #expect(reelView.selectedTextMenuFrameForTesting != nil)

            #expect(!app.handlePlaybackKeyDown(
                keyCode: UInt16(kVK_ANSI_C),
                modifierFlagsRawValue: NSEvent.ModifierFlags.command.rawValue,
                textInputState: nonEditableState,
                shortcuts: overlayCopyCueCmdCKeymap,
                window: reelWindow
            ))
            #expect(viewModel.feedback == nil)

            #expect(!app.handlePlaybackKeyDown(
                keyCode: UInt16(kVK_ANSI_C),
                modifierFlagsRawValue: NSEvent.ModifierFlags.command.rawValue,
                textInputState: nonEditableState,
                shortcuts: openPanelCmdCKeymap,
                window: reelWindow
            ))
            #expect(app.playback.commandPanelPresentation == nil)

            pasteboard.clearContents()
            #expect(reelWindow.performKeyEquivalent(with: makeCommandCEvent(windowNumber: reelWindow.windowNumber)))
            #expect(pasteboard.string(forType: .string) == selectedSubstring)

            // Part C: Editable text input focus always yields `Cmd + C` even when rebound.
            #expect(!app.handlePlaybackKeyDown(
                keyCode: UInt16(kVK_ANSI_C),
                modifierFlagsRawValue: NSEvent.ModifierFlags.command.rawValue,
                textInputState: PlaybackKeyboardTextInputState(
                    isEditableFocused: true,
                    hasMarkedText: false
                ),
                shortcuts: overlayCopyCueCmdCKeymap,
                window: reelWindow
            ))

            // After dismissing reel selection, custom `Cmd + C` overlay shortcut triggers full-cue copy action.
            NotificationCenter.default.post(name: .cueSeekerClearTextSelection, object: nil)
            #expect(!PlaybackSubtitleFocusReelContainerView.canCopySelection(in: reelWindow))
            pasteboard.clearContents()
            #expect(app.handlePlaybackKeyDown(
                keyCode: UInt16(kVK_ANSI_C),
                modifierFlagsRawValue: NSEvent.ModifierFlags.command.rawValue,
                textInputState: nonEditableState,
                shortcuts: overlayCopyCueCmdCKeymap,
                window: reelWindow
            ))
            #expect(pasteboard.string(forType: .string) == "custom command c cue line")
        }
    }

    @Test
    func playbackCurrentPlaylistAndCommandPanelSearchReelsSupportSilentCmdCAndEditCopyWithOpenMenu() throws {
        _ = NSApplication.shared
        WorkbenchStaticTextSelectionCoordinator.shared.clearSelection()
        NotificationCenter.default.post(name: .cueSeekerClearTextSelection, object: nil)
        defer {
            WorkbenchStaticTextSelectionCoordinator.shared.clearSelection()
            NotificationCenter.default.post(name: .cueSeekerClearTextSelection, object: nil)
        }

        let copyMenuItem = makeCopyMenuItem()
        let pasteboard = NSPasteboard.general

        // 1. Playback Current (`PlaybackSubtitleFocusCueReelAdapter`, `.playbackOverlay`)
        do {
            let layers = InterfaceLayerRegistry()
            layers.setOpen(.playbackPage, true)
            layers.setOpen(.playbackOverlay, true)

            let (reelView, window) = makeMountedCurrentReel(
                cues: [routingTestCue(ordinal: 0, content: "playback current selected fragment")],
                interfaceLayers: layers,
                menuOwner: .playbackOverlay
            )
            defer { tearDownReelWindow(reelView: reelView, window: window) }

            var menuActionCopiedTexts: [String] = []
            reelView.onCopySelectedText = { menuActionCopiedTexts.append($0) }

            let selected = try dragSelectPartialText(at: 0, in: reelView, window: window)
            #expect(!selected.isEmpty)
            #expect(reelView.selectedTextMenuFrameForTesting != nil)
            #expect(window.validateMenuItem(copyMenuItem))

            pasteboard.clearContents()
            #expect(window.performKeyEquivalent(with: makeCommandCEvent(windowNumber: window.windowNumber)))
            #expect(pasteboard.string(forType: .string) == selected)
            // Silent copy must not invoke menu Toast action and must keep selection + menu open.
            #expect(menuActionCopiedTexts.isEmpty)
            #expect(reelView.selectedTextForCopy == selected)
            #expect(reelView.selectedTextMenuFrameForTesting != nil)

            pasteboard.clearContents()
            window.copy(nil)
            #expect(pasteboard.string(forType: .string) == selected)
            #expect(menuActionCopiedTexts.isEmpty)
        }

        // 2. Playback Subtitle Playlist (`PlaybackPlaylistReelAdapter`, `.playbackOverlay`)
        do {
            let layers = InterfaceLayerRegistry()
            layers.setOpen(.playbackPage, true)
            layers.setOpen(.playbackOverlay, true)

            let source = makePlaylistSource(kind: .excerpt, totalCount: 3)
            let sessionWindow = try #require(source.makeSessionWindowStore())
            let adapter = PlaybackPlaylistReelAdapter(
                windowStore: sessionWindow,
                showsCueGroup: true
            )
            let (reelView, window) = makeMountedAdapterReel(
                adapter: adapter,
                interfaceLayers: layers,
                menuOwner: .playbackOverlay
            )
            defer {
                tearDownReelWindow(reelView: reelView, window: window)
                sessionWindow.invalidate()
                source.invalidate()
            }

            var menuActionCopiedTexts: [String] = []
            reelView.onCopySelectedText = { menuActionCopiedTexts.append($0) }

            let selected = try dragSelectPartialText(at: 0, in: reelView, window: window)
            #expect(!selected.isEmpty)
            #expect(reelView.selectedTextMenuFrameForTesting != nil)
            #expect(window.validateMenuItem(copyMenuItem))

            pasteboard.clearContents()
            #expect(window.performKeyEquivalent(with: makeCommandCEvent(windowNumber: window.windowNumber)))
            #expect(pasteboard.string(forType: .string) == selected)
            #expect(menuActionCopiedTexts.isEmpty)
            #expect(reelView.selectedTextForCopy == selected)
            #expect(reelView.selectedTextMenuFrameForTesting != nil)

            pasteboard.clearContents()
            window.copy(nil)
            #expect(pasteboard.string(forType: .string) == selected)
            #expect(menuActionCopiedTexts.isEmpty)
        }

        // 3. Command Panel Search Results (`PlaybackCueResultReelAdapter`, `.commandPanel`) including non-text drag entry
        do {
            let layers = InterfaceLayerRegistry()
            layers.setOpen(.playbackPage, true)
            layers.setOpen(.commandPanel, true)

            let source = makePlaylistSource(kind: .search, totalCount: 3)
            let sessionWindow = try #require(source.makeSessionWindowStore())
            let adapter = PlaybackCueResultReelAdapter(
                windowStore: sessionWindow,
                showsCueGroup: true
            )
            let (reelView, window) = makeMountedAdapterReel(
                adapter: adapter,
                interfaceLayers: layers,
                menuOwner: .commandPanel
            )
            defer {
                tearDownReelWindow(reelView: reelView, window: window)
                sessionWindow.invalidate()
                source.invalidate()
            }

            var menuActionCopiedTexts: [String] = []
            reelView.onCopySelectedText = { menuActionCopiedTexts.append($0) }

            let selected = try dragSelectFromMetadataMargin(at: 0, in: reelView, window: window)
            #expect(!selected.isEmpty)
            #expect(reelView.selectedTextMenuFrameForTesting != nil)
            #expect(window.validateMenuItem(copyMenuItem))

            pasteboard.clearContents()
            #expect(window.performKeyEquivalent(with: makeCommandCEvent(windowNumber: window.windowNumber)))
            #expect(pasteboard.string(forType: .string) == selected)
            #expect(menuActionCopiedTexts.isEmpty)
            #expect(reelView.selectedTextForCopy == selected)
            #expect(reelView.selectedTextMenuFrameForTesting != nil)

            pasteboard.clearContents()
            window.copy(nil)
            #expect(pasteboard.string(forType: .string) == selected)
            #expect(menuActionCopiedTexts.isEmpty)
        }
    }

    @Test
    func subtitleReelCmdCAndEditCopyRespectCommandPanelAndDialogOcclusionAndStaleStaticResponder() throws {
        _ = NSApplication.shared
        WorkbenchStaticTextSelectionCoordinator.shared.clearSelection()
        NotificationCenter.default.post(name: .cueSeekerClearTextSelection, object: nil)
        defer {
            WorkbenchStaticTextSelectionCoordinator.shared.clearSelection()
            NotificationCenter.default.post(name: .cueSeekerClearTextSelection, object: nil)
        }

        let layers = InterfaceLayerRegistry()
        layers.setOpen(.playbackPage, true)
        layers.setOpen(.playbackOverlay, true)

        let window = CueSeekerWindow(
            contentRect: CGRect(x: 0, y: 0, width: 720, height: 760),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        let root = NSView(frame: CGRect(x: 0, y: 0, width: 720, height: 760))
        window.contentView = root
        defer { window.contentView = nil }

        let staleStaticView = WorkbenchSelectableTextNSView(frame: CGRect(x: 20, y: 700, width: 200, height: 24))
        staleStaticView.configure(
            text: "Old Static Text",
            font: .systemFont(ofSize: 13),
            textColor: .labelColor,
            alignment: .left,
            lineLimit: 1,
            truncatesTail: true,
            isSelectable: true,
            preferredPointerShape: .iBeam,
            showsUnderline: false,
            onTap: nil,
            interfaceLayerContext: InterfaceLayerContext(layer: .playbackOverlay, frozenLayers: layers.frozenLayers)
        )
        root.addSubview(staleStaticView)
        staleStaticView.prepareLayoutForFlow()
        staleStaticView.selectAllText()
        #expect(window.firstResponder === staleStaticView)

        let overlayReel = PlaybackSubtitleFocusReelContainerView(
            frame: CGRect(x: 20, y: 20, width: 640, height: 640)
        )
        overlayReel.interfaceLayers = layers
        overlayReel.menuOwner = .playbackOverlay
        root.addSubview(overlayReel)
        let overlayCues = [routingTestCue(ordinal: 0, content: "overlay bottom cue text")]
        overlayReel.update(
            cues: overlayCues,
            totalCount: 1,
            selectedOrdinal: 0,
            displayTitle: "Overlay Title",
            keyboardNavigationRequest: nil,
            reducesMotion: true,
            isInteractionEnabled: true,
            cancelsWheelMotion: false,
            collageSelectedCueIDs: nil,
            collageCanSelectAnotherCue: true
        )
        root.layoutSubtreeIfNeeded()

        let overlaySelected = try dragSelectPartialText(at: 0, in: overlayReel, window: window)
        #expect(!overlaySelected.isEmpty)
        #expect(overlayReel.selectedTextMenuFrameForTesting != nil)
        // Even while cleared static text view remains firstResponder, responder-chain Copy validates & copies reel selection.
        #expect(!staleStaticView.hasSelection)
        let copyMenuItem = makeCopyMenuItem()
        #expect(staleStaticView.validateMenuItem(copyMenuItem))
        #expect(window.validateMenuItem(copyMenuItem))

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        staleStaticView.copy(nil)
        #expect(pasteboard.string(forType: .string) == overlaySelected)

        // Opening Command Panel covers Playback Overlay reel (even without flipping isCoveredByHigherLayer).
        layers.setOpen(.commandPanel, true)
        pasteboard.clearContents()
        pasteboard.setString("sentinel-unchanged", forType: .string)

        #expect(!window.validateMenuItem(copyMenuItem))
        #expect(!window.performKeyEquivalent(with: makeCommandCEvent(windowNumber: window.windowNumber)))
        #expect(pasteboard.string(forType: .string) == "sentinel-unchanged")
        #expect(!PlaybackSubtitleFocusReelContainerView.canCopySelection(in: window))

        // Mount uncovered Command Panel Search Results reel above the covered overlay reel.
        let searchSource = makePlaylistSource(kind: .search, totalCount: 2)
        let searchWindow = try #require(searchSource.makeSessionWindowStore())
        let searchAdapter = PlaybackCueResultReelAdapter(
            windowStore: searchWindow,
            showsCueGroup: true
        )
        let commandPanelReel = PlaybackSubtitleFocusReelContainerView(
            frame: CGRect(x: 40, y: 40, width: 600, height: 560)
        )
        commandPanelReel.interfaceLayers = layers
        commandPanelReel.menuOwner = .commandPanel
        root.addSubview(commandPanelReel)
        commandPanelReel.update(
            contentAdapter: searchAdapter,
            selectedOrdinal: 0,
            keyboardNavigationRequest: nil,
            reducesMotion: true,
            isInteractionEnabled: true,
            cancelsWheelMotion: false
        )
        root.layoutSubtreeIfNeeded()
        defer {
            commandPanelReel.invalidate()
            overlayReel.invalidate()
            searchWindow.invalidate()
            searchSource.invalidate()
        }

        let commandPanelSelected = try dragSelectPartialText(at: 0, in: commandPanelReel, window: window)
        #expect(!commandPanelSelected.isEmpty)
        #expect(window.validateMenuItem(copyMenuItem))

        pasteboard.clearContents()
        #expect(window.performKeyEquivalent(with: makeCommandCEvent(windowNumber: window.windowNumber)))
        #expect(pasteboard.string(forType: .string) == commandPanelSelected)

        // Opening Dialog covers Command Panel Search Results reel too.
        layers.setOpen(.dialog, true)
        pasteboard.clearContents()
        pasteboard.setString("dialog-sentinel", forType: .string)

        #expect(!window.validateMenuItem(copyMenuItem))
        #expect(!window.performKeyEquivalent(with: makeCommandCEvent(windowNumber: window.windowNumber)))
        #expect(pasteboard.string(forType: .string) == "dialog-sentinel")
        #expect(!PlaybackSubtitleFocusReelContainerView.canCopySelection(in: window))

        // Closing Dialog restores uncovered Command Panel reel copy ability.
        layers.setOpen(.dialog, false)
        #expect(window.validateMenuItem(copyMenuItem))
        pasteboard.clearContents()
        #expect(window.performKeyEquivalent(with: makeCommandCEvent(windowNumber: window.windowNumber)))
        #expect(pasteboard.string(forType: .string) == commandPanelSelected)
    }

    // MARK: - Test Helpers

    private func withRoutingCopyTestApp(
        _ body: (AppCoordinator, IndexingDatabase) async throws -> Void
    ) async throws {
        let suiteName = "CueSeekerReelCopyRoutingTests-\(UUID().uuidString)"
        let userDefaults = try #require(UserDefaults.temporary(suiteName: suiteName))
        let fixtureRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("CueSeekerReelCopyRoutingTests-\(UUID().uuidString)", isDirectory: true)
        let databaseURL = fixtureRoot.appendingPathComponent("routing-copy.sqlite")
        defer {
            userDefaults.removePersistentDomainAndPlist(forName: suiteName)
            try? FileManager.default.removeItem(at: fixtureRoot)
        }
        try FileManager.default.createDirectory(at: fixtureRoot, withIntermediateDirectories: true)

        _ = NSApplication.shared
        let app = AppCoordinator(userDefaults: userDefaults, databaseURL: databaseURL)
        let database = try #require(app.indexingDatabase)
        _ = try app.excerptDatabase?.createExcerptList(name: "Default")
        app.reloadExcerptListOverview()
        await app.excerptListOverviewTask?.value
        let source = routingTestSource()
        try database.replaceEntries(
            subtitleFile: URL(fileURLWithPath: source.subtitlePath),
            videoFile: URL(fileURLWithPath: source.videoPath),
            entries: (0..<10).map { ordinal in
                SubtitleEntry(
                    sequenceNumber: ordinal + 1,
                    startTimecode: "\(ordinal * 1_000)",
                    endTimecode: "\(ordinal * 1_000 + 900)",
                    startMilliseconds: ordinal * 1_000,
                    endMilliseconds: ordinal * 1_000 + 900,
                    text: "routing test cue \(ordinal)"
                )
            }
        )
        app.search.selectResult(SubtitleSearchResult(
            entryID: 1,
            subtitlePath: source.subtitlePath,
            subtitleFormat: source.subtitleFormat,
            videoPath: source.videoPath,
            videoName: "Routing-Test.mkv",
            startMilliseconds: 500,
            endMilliseconds: 900,
            content: "routing test cue 0",
            cueLines: ["routing test cue 0"]
        ))
        app.playback.playbackViewModel = PlaybackViewModel(player: PlaybackPlayer())
        app.playback.playbackStatus = .paused
        try await body(app, database)
    }

    private func makeOffscreenCueWindow<Content: View>(
        rootView: Content,
        size: CGSize
    ) -> (CueSeekerWindow, NSView) {
        let window = CueSeekerWindow(
            contentRect: CGRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        let hostingView = CueSeekerHostingView(rootView: AnyView(rootView))
        hostingView.frame = CGRect(origin: .zero, size: size)
        window.contentView = hostingView
        hostingView.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.02))
        return (window, hostingView)
    }

    private func makeMountedCurrentReel(
        cues: [SubtitleFocusCue],
        interfaceLayers: InterfaceLayerRegistry,
        menuOwner: InterfaceLayer
    ) -> (PlaybackSubtitleFocusReelContainerView, CueSeekerWindow) {
        let window = CueSeekerWindow(
            contentRect: CGRect(x: 0, y: 0, width: 640, height: 656),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        let reelView = PlaybackSubtitleFocusReelContainerView(
            frame: CGRect(x: 0, y: 0, width: 640, height: 656)
        )
        reelView.interfaceLayers = interfaceLayers
        reelView.menuOwner = menuOwner
        window.contentView = reelView
        reelView.update(
            cues: cues,
            totalCount: cues.count,
            selectedOrdinal: 0,
            displayTitle: "Episode 01",
            keyboardNavigationRequest: nil,
            reducesMotion: true,
            isInteractionEnabled: true,
            cancelsWheelMotion: false,
            collageSelectedCueIDs: nil,
            collageCanSelectAnotherCue: true
        )
        reelView.layoutSubtreeIfNeeded()
        return (reelView, window)
    }

    private func makeMountedAdapterReel(
        adapter: any PlaybackVirtualReelContentAdapter,
        interfaceLayers: InterfaceLayerRegistry,
        menuOwner: InterfaceLayer
    ) -> (PlaybackSubtitleFocusReelContainerView, CueSeekerWindow) {
        let window = CueSeekerWindow(
            contentRect: CGRect(x: 0, y: 0, width: 640, height: 656),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        let reelView = PlaybackSubtitleFocusReelContainerView(
            frame: CGRect(x: 0, y: 0, width: 640, height: 656)
        )
        reelView.interfaceLayers = interfaceLayers
        reelView.menuOwner = menuOwner
        window.contentView = reelView
        reelView.update(
            contentAdapter: adapter,
            selectedOrdinal: 0,
            keyboardNavigationRequest: nil,
            reducesMotion: true,
            isInteractionEnabled: true,
            cancelsWheelMotion: false
        )
        reelView.layoutSubtreeIfNeeded()
        return (reelView, window)
    }

    private func tearDownReelWindow(
        reelView: PlaybackSubtitleFocusReelContainerView,
        window: NSWindow
    ) {
        reelView.invalidate()
        window.contentView = nil
    }

    private func tearDownOffscreenWindow(_ window: NSWindow) {
        window.contentView = nil
    }

    private func selectWholeStaticTextView(
        _ view: WorkbenchSelectableTextNSView,
        in window: NSWindow
    ) {
        view.prepareLayoutForFlow()
        let point = view.convert(CGPoint(x: 8, y: view.bounds.midY), to: nil)
        view.mouseDown(with: makeMouseEvent(type: .leftMouseDown, locationInWindow: point, clickCount: 3, windowNumber: window.windowNumber))
        view.mouseUp(with: makeMouseEvent(type: .leftMouseUp, locationInWindow: point, clickCount: 3, windowNumber: window.windowNumber))
    }

    private func dragSelectPartialText(
        at ordinal: Int,
        in reelView: PlaybackSubtitleFocusReelContainerView,
        window: NSWindow
    ) throws -> String {
        let documentView = reelView.documentViewForTesting
        let lineRect = try #require(documentView.selectableTextRectsForTesting(at: ordinal).last)
        let start = CGPoint(x: lineRect.minX + 2, y: lineRect.midY)
        let end = CGPoint(x: min(lineRect.maxX - 4, lineRect.minX + lineRect.width * 0.6), y: lineRect.midY)

        documentView.mouseDown(with: makeMouseEvent(
            type: .leftMouseDown,
            locationInWindow: documentView.convert(start, to: nil),
            clickCount: 1,
            windowNumber: window.windowNumber
        ))
        documentView.mouseDragged(with: makeMouseEvent(
            type: .leftMouseDragged,
            locationInWindow: documentView.convert(end, to: nil),
            clickCount: 1,
            windowNumber: window.windowNumber
        ))
        documentView.mouseUp(with: makeMouseEvent(
            type: .leftMouseUp,
            locationInWindow: documentView.convert(end, to: nil),
            clickCount: 1,
            windowNumber: window.windowNumber
        ))
        return try #require(reelView.selectedTextForCopy)
    }

    private func dragSelectFromMetadataMargin(
        at ordinal: Int,
        in reelView: PlaybackSubtitleFocusReelContainerView,
        window: NSWindow
    ) throws -> String {
        let documentView = reelView.documentViewForTesting
        let placement = try #require(reelView.placementsForTesting.first { $0.ordinal == ordinal })
        let lineRects = documentView.selectableTextRectsForTesting(at: ordinal)
        let lastRect = try #require(lineRects.last)
        let marginStart = CGPoint(x: lastRect.maxX - 4, y: placement.rect.maxY - 6)
        #expect(!lineRects.contains { $0.contains(marginStart) })
        let insideLastLine = CGPoint(x: lastRect.minX + 18, y: lastRect.midY)

        documentView.mouseDown(with: makeMouseEvent(
            type: .leftMouseDown,
            locationInWindow: documentView.convert(marginStart, to: nil),
            clickCount: 1,
            windowNumber: window.windowNumber
        ))
        documentView.mouseDragged(with: makeMouseEvent(
            type: .leftMouseDragged,
            locationInWindow: documentView.convert(insideLastLine, to: nil),
            clickCount: 1,
            windowNumber: window.windowNumber
        ))
        documentView.mouseUp(with: makeMouseEvent(
            type: .leftMouseUp,
            locationInWindow: documentView.convert(insideLastLine, to: nil),
            clickCount: 1,
            windowNumber: window.windowNumber
        ))
        return try #require(reelView.selectedTextForCopy)
    }

    private func collectSelectableTextViews(in root: NSView) -> [WorkbenchSelectableTextNSView] {
        var result: [WorkbenchSelectableTextNSView] = []
        if let selectable = root as? WorkbenchSelectableTextNSView {
            result.append(selectable)
        }
        for subview in root.subviews {
            result.append(contentsOf: collectSelectableTextViews(in: subview))
        }
        return result
    }

    private func makeCopyMenuItem() -> NSMenuItem {
        NSMenuItem(
            title: "Copy",
            action: #selector(NSText.copy(_:)),
            keyEquivalent: "c"
        )
    }

    private func makeCommandCEvent(windowNumber: Int) -> NSEvent {
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [.command],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: windowNumber,
            context: nil,
            characters: "c",
            charactersIgnoringModifiers: "c",
            isARepeat: false,
            keyCode: UInt16(kVK_ANSI_C)
        )!
    }

    private func makeMouseEvent(
        type: NSEvent.EventType,
        locationInWindow: CGPoint,
        clickCount: Int,
        windowNumber: Int
    ) -> NSEvent {
        NSEvent.mouseEvent(
            with: type,
            location: locationInWindow,
            modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: windowNumber,
            context: nil,
            eventNumber: 0,
            clickCount: clickCount,
            pressure: type == .leftMouseUp ? 0 : 1
        )!
    }

    private func routingTestSource() -> SubtitleFocusSourceIdentity {
        SubtitleFocusSourceIdentity(
            videoPath: "/Media/Routing-Test.mkv",
            subtitlePath: "/Media/Routing-Test.srt",
            subtitleFormat: .srt
        )
    }

    private func routingTestOpenSnapshot(wasPlaying: Bool) -> PlaybackSubtitleFocusOpenSnapshot {
        PlaybackSubtitleFocusOpenSnapshot(
            source: routingTestSource(),
            timestampMilliseconds: 500,
            wasPlaying: wasPlaying
        )
    }

    private func routingTestCue(ordinal: Int, content: String) -> SubtitleFocusCue {
        SubtitleFocusCue(
            id: Int64(ordinal + 1),
            cueGroupID: Int64(ordinal + 101),
            ordinal: ordinal,
            eventIndex: ordinal,
            displayOrder: 0,
            startMilliseconds: ordinal * 1_000,
            endMilliseconds: ordinal * 1_000 + 900,
            content: content
        )
    }

    private func routingTestSnapshot(line: String) -> SubtitleFocusSnapshot {
        SubtitleFocusSnapshot(
            totalCount: 1,
            selectedOrdinal: 0,
            cues: [routingTestCue(ordinal: 0, content: line)]
        )
    }

    private func makePlaylistSource(
        kind: PlaybackPlaylistSourceKind,
        totalCount: Int
    ) -> PlaybackPlaylistSource {
        PlaybackPlaylistSource(kind: kind, totalCount: totalCount) { ordinal in
            guard ordinal >= 0, ordinal < totalCount else {
                return nil
            }
            let id = Int64(2_000 + ordinal)
            let primary = "searchable primary cue text \(ordinal)"
            return PlaybackPlaylistItem(
                searchResult: SubtitleSearchResult(
                    entryID: id,
                    cueGroupID: id + 100,
                    cueEventIndex: ordinal,
                    cueDisplayOrder: 1,
                    primaryGroupIndex: 1,
                    subtitlePath: "/subtitle/\(id).ass",
                    subtitleFormat: .ass,
                    videoPath: "/video/\(id).mkv",
                    videoName: "\(id).mkv",
                    startMilliseconds: ordinal * 1_000,
                    endMilliseconds: ordinal * 1_000 + 500,
                    content: primary,
                    cueLines: ["context line \(ordinal)", primary],
                    cueGroupLines: ["context line \(ordinal)", primary],
                    searchRank: ordinal
                ),
                ordinal: ordinal
            )
        }
    }
}
