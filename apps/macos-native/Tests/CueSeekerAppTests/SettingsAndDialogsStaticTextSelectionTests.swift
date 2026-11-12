import AppKit
import CueSeekerCore
import CueSeekerPlayback
import SwiftUI
import Testing
@testable import CueSeekerApp

extension WorkbenchSelectableTextTests {
    private func makeOffscreenHostingWindow<Content: View>(
        rootView: Content,
        size: CGSize = CGSize(width: 820, height: 640),
        isMainWindow: Bool = true
    ) -> (CueSeekerWindow, CueSeekerHostingView<Content>) {
        _ = NSApplication.shared
        let window: CueSeekerWindow = isMainWindow
            ? CueSeekerMainWindow(
                contentRect: CGRect(origin: .zero, size: size),
                styleMask: [.titled, .closable, .resizable],
                backing: .buffered,
                defer: false
            )
            : CueSeekerWindow(
                contentRect: CGRect(origin: .zero, size: size),
                styleMask: [.titled, .closable, .resizable],
                backing: .buffered,
                defer: false
            )
        window.isReleasedWhenClosed = false
        let hostingView = CueSeekerHostingView(rootView: rootView)
        hostingView.frame = CGRect(origin: .zero, size: size)
        window.contentView = hostingView
        hostingView.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.03))
        hostingView.layoutSubtreeIfNeeded()
        return (window, hostingView)
    }

    private func tearDownOffscreenWindow(_ window: CueSeekerWindow) {
        WorkbenchStaticTextSelectionCoordinator.shared.clearSelection()
        window.isFocusLocked = { false }
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        _ = window.makeFirstResponder(nil)
        window.orderOut(nil)
        window.contentView = nil
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
    }

    private func collectInteractiveSelectableViews(in root: NSView) -> [WorkbenchSelectableTextNSView] {
        var result: [WorkbenchSelectableTextNSView] = []
        func visit(_ view: NSView) {
            guard !view.isHidden, view.alphaValue > 0.001 else { return }
            if let selectable = view as? WorkbenchSelectableTextNSView, selectable.canInteract {
                selectable.prepareLayoutForFlow()
                result.append(selectable)
            }
            for subview in view.subviews {
                visit(subview)
            }
        }
        visit(root)
        return result
    }

    private func collectSwitches(in root: NSView) -> [NSSwitch] {
        var result: [NSSwitch] = []
        func visit(_ view: NSView) {
            guard !view.isHidden, view.alphaValue > 0.001 else { return }
            if let toggle = view as? NSSwitch, toggle.isEnabled {
                result.append(toggle)
            }
            for subview in view.subviews {
                visit(subview)
            }
        }
        visit(root)
        return result
    }

    private func makeQueuedMouseEvent(
        type: NSEvent.EventType,
        locationInWindow: CGPoint,
        clickCount: Int = 1,
        eventNumber: Int = 10,
        windowNumber: Int
    ) -> NSEvent {
        NSEvent.mouseEvent(
            with: type,
            location: locationInWindow,
            modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: windowNumber,
            context: nil,
            eventNumber: eventNumber,
            clickCount: clickCount,
            pressure: type == .leftMouseUp ? 0 : 1
        )!
    }

    private func makeTestCGImage(width: Int = 320, height: Int = 180) throws -> CGImage {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = try #require(
            CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        )
        context.setFillColor(red: 0.25, green: 0.45, blue: 0.75, alpha: 1.0)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return try #require(context.makeImage())
    }

    @Test
    func settingsGeneralCategoryAndSwitchDragCancellation() throws {
        WorkbenchStaticTextSelectionCoordinator.shared.clearSelection()
        AppLocalization.apply(.english)
        defer {
            WorkbenchStaticTextSelectionCoordinator.shared.clearSelection()
            AppLocalization.apply(.english)
        }

        let suiteName = "CueSeekerTests.SettingsGeneralSelection.\(UUID().uuidString)"
        let userDefaults = try #require(UserDefaults.temporary(suiteName: suiteName))
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("SettingsGeneralSelection-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer {
            userDefaults.removePersistentDomainAndPlist(forName: suiteName)
            try? FileManager.default.removeItem(at: tempRoot)
        }

        let appState = AppCoordinator(
            userDefaults: userDefaults,
            databaseURL: tempRoot.appendingPathComponent("CueSeeker.sqlite")
        )
        let settingsStore = appState.settings
        let accessibility = appState.workbenchAccessibility
        let settingsLayers = appState.settingsInterfaceLayers

        let root = SettingsView()
            .modifier(InterfaceLayerCoverageBridge(layers: settingsLayers))
            .environment(\.workbenchAccessibility, accessibility)
            .environmentObject(appState)
            .environmentObject(appState.workbenchLayout)
            .environmentObject(appState.workbenchLayout.route)
            .environmentObject(settingsStore)
            .environmentObject(settingsStore.cueGroupPresentation)
            .environmentObject(settingsStore.localization)
            .environmentObject(settingsStore.playbackShortcuts)
            .environmentObject(appState.indexing)
            .environmentObject(appState.excerpt)
            .environmentObject(appState.library)
            .environmentObject(appState.search)
            .environmentObject(appState.playback)
            .environmentObject(accessibility)

        let (window, hostingView) = makeOffscreenHostingWindow(
            rootView: root,
            size: CGSize(width: 780, height: 680),
            isMainWindow: false
        )
        defer {
            tearDownOffscreenWindow(window)
        }
        window.isFocusLocked = { [weak settingsLayers] in
            guard let settingsLayers else { return false }
            return settingsLayers.hasUncoveredOpenMenu || settingsLayers.isOpen(.dialog)
        }

        // 1. General category: group titles & row labels selectable; sidebar & topbar excluded.
        accessibility.selectedSettingsCategory = .general
        RunLoop.main.run(until: Date().addingTimeInterval(0.03))
        hostingView.layoutSubtreeIfNeeded()

        let generalViews = collectInteractiveSelectableViews(in: hostingView)
        let generalTexts = Set(generalViews.map(\.text))
        #expect(generalTexts.contains(L("settings.category.appearance")))
        #expect(generalTexts.contains(L("settings.appearance.mode")))
        #expect(generalTexts.contains(L("settings.appearance.hdr_screenshot")))
        #expect(generalTexts.contains(L("settings.category.search")))
        #expect(generalTexts.contains(L("settings.search.show_cue_group")))
        #expect(generalTexts.contains(L("settings.category.language")))
        #expect(generalTexts.contains("Deep Link"))
        // Sidebar category titles ("General", "Shortcuts", "Subtitle") & topbar title ("General") are NOT selectable.
        #expect(!generalTexts.contains(L("settings.category.general")))
        #expect(!generalTexts.contains(L("settings.category.shortcuts")))
        #expect(!generalTexts.contains(L("settings.category.subtitle")))

        // Verify I-beam pointer and cross-group continuous selection from Appearance down into Search.
        let appearanceTitleView = try #require(
            generalViews.first { $0.text == L("settings.category.appearance") }
        )
        let showCueGroupView = try #require(
            generalViews.first { $0.text == L("settings.search.show_cue_group") }
        )
        let appearanceStart = appearanceTitleView.convert(CGPoint(x: 2, y: 8), to: nil)
        #expect(appearanceTitleView.pointerShape(atWindowPoint: appearanceStart) == .iBeam)

        let searchRowEnd = showCueGroupView.convert(
            CGPoint(x: showCueGroupView.bounds.maxX - 2, y: 8),
            to: nil
        )
        appearanceTitleView.mouseDown(
            with: makeQueuedMouseEvent(
                type: .leftMouseDown,
                locationInWindow: appearanceStart,
                windowNumber: window.windowNumber
            )
        )
        appearanceTitleView.mouseDragged(
            with: makeQueuedMouseEvent(
                type: .leftMouseDragged,
                locationInWindow: searchRowEnd,
                windowNumber: window.windowNumber
            )
        )
        appearanceTitleView.mouseUp(
            with: makeQueuedMouseEvent(
                type: .leftMouseUp,
                locationInWindow: searchRowEnd,
                windowNumber: window.windowNumber
            )
        )
        #expect(
            WorkbenchStaticTextSelectionCoordinator.shared.selectedText
                == [
                    L("settings.category.appearance"),
                    L("settings.appearance.mode"),
                    L("settings.appearance.hdr_screenshot"),
                    L("settings.category.search"),
                    L("settings.search.show_cue_group"),
                ].joined(separator: "\n")
        )

        // 2. Real NSSwitch click vs drag-left-into-label cancellation (both OFF and ON initial states).
        let hdrLabelView = try #require(
            generalViews.first { $0.text == L("settings.appearance.hdr_screenshot") }
        )
        let hdrLabelWindowMidY = hdrLabelView.convert(
            CGPoint(x: 4, y: hdrLabelView.bounds.midY),
            to: nil
        ).y
        let hdrSwitch = try #require(
            collectSwitches(in: hostingView).min { lhs, rhs in
                let lhsMidY = lhs.convert(CGPoint(x: lhs.bounds.midX, y: lhs.bounds.midY), to: nil).y
                let rhsMidY = rhs.convert(CGPoint(x: rhs.bounds.midX, y: rhs.bounds.midY), to: nil).y
                return abs(lhsMidY - hdrLabelWindowMidY) < abs(rhsMidY - hdrLabelWindowMidY)
            }
        )
        let switchCenter = hdrSwitch.convert(
            CGPoint(x: hdrSwitch.bounds.midX, y: hdrSwitch.bounds.midY),
            to: nil
        )

        @MainActor
        func sendOffscreenControlMouseDown(
            _ downEvent: NSEvent,
            queuedTrackingEvents: [NSEvent],
            on control: NSControl
        ) {
            WorkbenchStaticTextSelectionCoordinator.shared.handleWindowLeftMouseDown(
                window: window,
                event: downEvent
            )
            let began = window.beginTrackedControlMouseSessionIfNeeded(for: downEvent)
            defer {
                if began {
                    window.endTrackedControlMouseSession()
                }
            }
            let mainRunLoop = CFRunLoopGetMain()
            CFRunLoopPerformBlock(mainRunLoop, RunLoop.Mode.eventTracking.rawValue as CFString) {
                for event in queuedTrackingEvents {
                    NSApp.postEvent(event, atStart: false)
                }
            }
            CFRunLoopWakeUp(mainRunLoop)
            control.mouseDown(with: downEvent)
        }

        // 2a. Plain click on NSSwitch still toggles binding normally (OFF -> ON).
        settingsStore.hdrScreenshotEnabled = false
        RunLoop.main.run(until: Date().addingTimeInterval(0.02))
        #expect(hdrSwitch.state == .off)

        let clickDown = makeQueuedMouseEvent(
            type: .leftMouseDown,
            locationInWindow: switchCenter,
            eventNumber: 21,
            windowNumber: window.windowNumber
        )
        let clickUp = makeQueuedMouseEvent(
            type: .leftMouseUp,
            locationInWindow: switchCenter,
            eventNumber: 21,
            windowNumber: window.windowNumber
        )
        sendOffscreenControlMouseDown(clickDown, queuedTrackingEvents: [clickUp], on: hdrSwitch)
        RunLoop.main.run(until: Date().addingTimeInterval(0.02))
        #expect(settingsStore.hdrScreenshotEnabled == true)
        #expect(hdrSwitch.state == .on)

        // 2b. Dragging left from ON NSSwitch into "HDR Screenshot" and up into "Appearance Mode"
        //     selects multi-row text WITHOUT toggling switch OFF.
        let modeLabelView = try #require(
            generalViews.first { $0.text == L("settings.appearance.mode") }
        )
        let hdrLabelStart = hdrLabelView.convert(CGPoint(x: 2, y: hdrLabelView.bounds.midY), to: nil)
        let modeLabelStart = modeLabelView.convert(CGPoint(x: 2, y: modeLabelView.bounds.midY), to: nil)
        let dragFromOnDown = makeQueuedMouseEvent(
            type: .leftMouseDown,
            locationInWindow: switchCenter,
            eventNumber: 22,
            windowNumber: window.windowNumber
        )
        let dragFromOnIntoLabel = makeQueuedMouseEvent(
            type: .leftMouseDragged,
            locationInWindow: hdrLabelStart,
            eventNumber: 22,
            windowNumber: window.windowNumber
        )
        let dragFromOnUpToMode = makeQueuedMouseEvent(
            type: .leftMouseDragged,
            locationInWindow: modeLabelStart,
            eventNumber: 22,
            windowNumber: window.windowNumber
        )
        let dragFromOnUp = makeQueuedMouseEvent(
            type: .leftMouseUp,
            locationInWindow: modeLabelStart,
            eventNumber: 22,
            windowNumber: window.windowNumber
        )
        sendOffscreenControlMouseDown(
            dragFromOnDown,
            queuedTrackingEvents: [dragFromOnIntoLabel, dragFromOnUpToMode, dragFromOnUp],
            on: hdrSwitch
        )
        RunLoop.main.run(until: Date().addingTimeInterval(0.02))

        #expect(settingsStore.hdrScreenshotEnabled == true)
        #expect(hdrSwitch.state == .on)
        #expect(
            WorkbenchStaticTextSelectionCoordinator.shared.selectedText
                == [L("settings.appearance.mode"), L("settings.appearance.hdr_screenshot")].joined(separator: "\n")
        )

        // 2c. Dragging left from OFF NSSwitch into "HDR Screenshot" also leaves switch OFF.
        WorkbenchStaticTextSelectionCoordinator.shared.clearSelection()
        settingsStore.hdrScreenshotEnabled = false
        RunLoop.main.run(until: Date().addingTimeInterval(0.02))
        #expect(hdrSwitch.state == .off)

        let dragFromOffDown = makeQueuedMouseEvent(
            type: .leftMouseDown,
            locationInWindow: switchCenter,
            eventNumber: 23,
            windowNumber: window.windowNumber
        )
        let dragFromOffIntoLabel = makeQueuedMouseEvent(
            type: .leftMouseDragged,
            locationInWindow: hdrLabelStart,
            eventNumber: 23,
            windowNumber: window.windowNumber
        )
        let dragFromOffUp = makeQueuedMouseEvent(
            type: .leftMouseUp,
            locationInWindow: hdrLabelStart,
            eventNumber: 23,
            windowNumber: window.windowNumber
        )
        sendOffscreenControlMouseDown(
            dragFromOffDown,
            queuedTrackingEvents: [dragFromOffIntoLabel, dragFromOffUp],
            on: hdrSwitch
        )
        RunLoop.main.run(until: Date().addingTimeInterval(0.02))

        #expect(settingsStore.hdrScreenshotEnabled == false)
        #expect(hdrSwitch.state == .off)
        #expect(
            WorkbenchStaticTextSelectionCoordinator.shared.selectedText
                == L("settings.appearance.hdr_screenshot")
        )
    }

    @Test
    func settingsPlaySubtitleShortcutsAndFocusLockedConfirmationSelection() throws {
        WorkbenchStaticTextSelectionCoordinator.shared.clearSelection()
        AppLocalization.apply(.english)
        defer {
            WorkbenchStaticTextSelectionCoordinator.shared.clearSelection()
            AppLocalization.apply(.english)
        }

        let suiteName = "CueSeekerTests.SettingsOtherCategories.\(UUID().uuidString)"
        let userDefaults = try #require(UserDefaults.temporary(suiteName: suiteName))
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("SettingsOtherCategories-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer {
            userDefaults.removePersistentDomainAndPlist(forName: suiteName)
            try? FileManager.default.removeItem(at: tempRoot)
        }

        let appState = AppCoordinator(
            userDefaults: userDefaults,
            databaseURL: tempRoot.appendingPathComponent("CueSeeker.sqlite")
        )
        let settingsStore = appState.settings
        let accessibility = appState.workbenchAccessibility
        let settingsLayers = appState.settingsInterfaceLayers

        let root = SettingsView()
            .modifier(InterfaceLayerCoverageBridge(layers: settingsLayers))
            .environment(\.workbenchAccessibility, accessibility)
            .environmentObject(appState)
            .environmentObject(appState.workbenchLayout)
            .environmentObject(appState.workbenchLayout.route)
            .environmentObject(settingsStore)
            .environmentObject(settingsStore.cueGroupPresentation)
            .environmentObject(settingsStore.localization)
            .environmentObject(settingsStore.playbackShortcuts)
            .environmentObject(appState.indexing)
            .environmentObject(appState.excerpt)
            .environmentObject(appState.library)
            .environmentObject(appState.search)
            .environmentObject(appState.playback)
            .environmentObject(accessibility)

        let (window, hostingView) = makeOffscreenHostingWindow(
            rootView: root,
            size: CGSize(width: 780, height: 680),
            isMainWindow: false
        )
        defer {
            tearDownOffscreenWindow(window)
        }

        // Play & Subtitle categories cover all group titles and setting row names.
        accessibility.selectedSettingsCategory = .play
        RunLoop.main.run(until: Date().addingTimeInterval(0.03))
        hostingView.layoutSubtreeIfNeeded()
        let playTexts = Set(collectInteractiveSelectableViews(in: hostingView).map(\.text))
        #expect(playTexts.contains(L("settings.category.play")))
        #expect(playTexts.contains(L("settings.play.auto_pause")))
        #expect(playTexts.contains(L("settings.play.auto_switch")))
        #expect(playTexts.contains(L("settings.play.auto_switch_gap")))
        #expect(playTexts.contains(L("settings.category.decode")))
        #expect(playTexts.contains(L("settings.decode.decoder")))

        accessibility.selectedSettingsCategory = .subtitle
        RunLoop.main.run(until: Date().addingTimeInterval(0.03))
        hostingView.layoutSubtreeIfNeeded()
        let subtitleTexts = Set(collectInteractiveSelectableViews(in: hostingView).map(\.text))
        #expect(subtitleTexts.contains(L("settings.subtitle.section.text")))
        #expect(subtitleTexts.contains(L("settings.subtitle.font")))
        #expect(subtitleTexts.contains(L("settings.subtitle.section.position")))
        #expect(subtitleTexts.contains(L("settings.subtitle.section.border")))
        #expect(subtitleTexts.contains(L("settings.subtitle.section.shadow")))
        #expect(!subtitleTexts.contains(L("settings.subtitle.restore_defaults")))

        // Shortcuts category: group titles + action names + red conflict validation message form one flow,
        // while Keycap / Shortcut Field stays non-selectable.
        let actions = PlaybackShortcutAction.allCases.filter { $0.group == .playback }
        let firstAction = try #require(actions.first)
        let secondAction = try #require(actions.dropFirst().first)
        if let firstKey = settingsStore.playbackShortcuts.keymap.key(for: firstAction) {
            settingsStore.playbackShortcuts.set(firstKey, for: secondAction)
        }
        accessibility.selectedSettingsCategory = .shortcuts
        RunLoop.main.run(until: Date().addingTimeInterval(0.03))
        hostingView.layoutSubtreeIfNeeded()

        let shortcutViews = collectInteractiveSelectableViews(in: hostingView)
        let shortcutTexts = shortcutViews.map(\.text)
        #expect(shortcutTexts.contains(L("settings.category.shortcuts")))
        #expect(shortcutTexts.contains(L("settings.shortcuts.section.playback")))
        #expect(shortcutTexts.contains(firstAction.title))
        #expect(shortcutTexts.contains(secondAction.title))
        let conflictText = try #require(
            shortcutTexts.first { $0.contains(secondAction.title) && $0 != secondAction.title }
        )
        #expect(!shortcutTexts.contains(L("settings.shortcuts.placeholder")))

        let groupView = try #require(
            shortcutViews.first { $0.text == L("settings.shortcuts.section.playback") }
        )
        let conflictView = try #require(
            shortcutViews.first { $0.text == conflictText }
        )
        let sStart = groupView.convert(CGPoint(x: 2, y: 8), to: nil)
        let sEnd = conflictView.convert(CGPoint(x: conflictView.bounds.maxX - 2, y: 6), to: nil)
        groupView.mouseDown(with: makeQueuedMouseEvent(type: .leftMouseDown, locationInWindow: sStart, windowNumber: window.windowNumber))
        groupView.mouseDragged(with: makeQueuedMouseEvent(type: .leftMouseDragged, locationInWindow: sEnd, windowNumber: window.windowNumber))
        groupView.mouseUp(with: makeQueuedMouseEvent(type: .leftMouseUp, locationInWindow: sEnd, windowNumber: window.windowNumber))
        #expect(
            WorkbenchStaticTextSelectionCoordinator.shared.selectedText
                == [L("settings.shortcuts.section.playback"), firstAction.title, conflictText].joined(separator: "\n")
        )

        // Confirmation dialog inside a focus-locked Settings CueSeekerWindow (isMainWindow == false)
        // allows dialog header + message selection and firstResponder acquisition.
        WorkbenchStaticTextSelectionCoordinator.shared.clearSelection()
        let confirmSession = WorkbenchConfirmationSession(
            title: "Reset Shortcuts",
            message: "All custom shortcuts will be restored.",
            destructiveTitle: "Reset",
            cancelTitle: "Cancel",
            onDestructive: {},
            onCancel: {}
        )
        let (confirmWindow, confirmHost) = makeOffscreenHostingWindow(
            rootView: WorkbenchConfirmationDialog(
                session: confirmSession,
                onClose: {}
            )
            .environment(\.interfaceLayerContext, InterfaceLayerContext(layer: .dialog)),
            size: CGSize(width: 480, height: 320),
            isMainWindow: false
        )
        defer {
            tearDownOffscreenWindow(confirmWindow)
        }
        confirmWindow.isFocusLocked = { true }
        #expect(confirmWindow.isFocusLocked())

        let confirmationViews = collectInteractiveSelectableViews(in: confirmHost)
        let confirmTitle = try #require(confirmationViews.first { $0.text == "Reset Shortcuts" })
        let confirmBody = try #require(confirmationViews.first { $0.text == "All custom shortcuts will be restored." })
        let cStart = confirmTitle.convert(CGPoint(x: 2, y: 8), to: nil)
        let cEnd = confirmBody.convert(CGPoint(x: confirmBody.bounds.maxX - 2, y: 8), to: nil)
        confirmTitle.mouseDown(with: makeQueuedMouseEvent(type: .leftMouseDown, locationInWindow: cStart, windowNumber: confirmWindow.windowNumber))
        confirmTitle.mouseDragged(with: makeQueuedMouseEvent(type: .leftMouseDragged, locationInWindow: cEnd, windowNumber: confirmWindow.windowNumber))
        confirmTitle.mouseUp(with: makeQueuedMouseEvent(type: .leftMouseUp, locationInWindow: cEnd, windowNumber: confirmWindow.windowNumber))
        #expect(confirmWindow.firstResponder === confirmTitle)
        #expect(
            WorkbenchStaticTextSelectionCoordinator.shared.selectedText
                == "Reset Shortcuts\nAll custom shortcuts will be restored."
        )
    }

    @Test
    func detailDialogsCoverHeaderObjectTitleGroupsAndIndexedKeyValuesWhileExcludingFilePairedDropdown() throws {
        WorkbenchStaticTextSelectionCoordinator.shared.clearSelection()
        AppLocalization.apply(.english)
        defer {
            WorkbenchStaticTextSelectionCoordinator.shared.clearSelection()
            AppLocalization.apply(.english)
        }

        // 1. Folder Info: dialog title + top folder object header + property group titles + left/right key-values.
        let folderInfo = FileDetailFolderInfo(
            path: "/Media/Anime",
            name: "Season 01",
            isRootFolder: false,
            folderCount: 3,
            videoCount: 12,
            subtitleCount: 24,
            addedAt: nil,
            updatedAt: nil
        )
        let folderSession = FileDetailDialogSession(kind: .folder(folderInfo))
        let (folderWindow, folderHost) = makeOffscreenHostingWindow(
            rootView: WorkbenchFileDetailDialog(session: folderSession, onClose: {})
                .environment(\.interfaceLayerContext, InterfaceLayerContext(layer: .dialog))
                .environment(\.workbenchDialogAvailableSize, CGSize(width: 680, height: 640)),
            size: CGSize(width: 680, height: 640)
        )
        defer { tearDownOffscreenWindow(folderWindow) }
        let folderViews = collectInteractiveSelectableViews(in: folderHost)
        let folderTexts = folderViews.map(\.text)
        #expect(folderTexts.contains(L("file_detail.folder_title")))
        #expect(folderTexts.contains("Season 01"))
        #expect(folderTexts.contains(L("file_detail.section.folder_info")))
        #expect(folderTexts.contains(L("file_detail.section.index_info")))
        #expect(folderTexts.contains(L("file_detail.path")))
        #expect(folderTexts.contains("/Media/Anime"))

        let pathLabelView = try #require(folderViews.first { $0.text == L("file_detail.path") })
        let folderCountValueView = try #require(folderViews.first { $0.text == "3" })
        let fStart = pathLabelView.convert(CGPoint(x: 1, y: 8), to: nil)
        let fEnd = folderCountValueView.convert(CGPoint(x: folderCountValueView.bounds.maxX - 1, y: 8), to: nil)
        pathLabelView.mouseDown(with: makeQueuedMouseEvent(type: .leftMouseDown, locationInWindow: fStart, windowNumber: folderWindow.windowNumber))
        pathLabelView.mouseDragged(with: makeQueuedMouseEvent(type: .leftMouseDragged, locationInWindow: fEnd, windowNumber: folderWindow.windowNumber))
        pathLabelView.mouseUp(with: makeQueuedMouseEvent(type: .leftMouseUp, locationInWindow: fEnd, windowNumber: folderWindow.windowNumber))
        #expect(
            WorkbenchStaticTextSelectionCoordinator.shared.selectedText
                == "\(L("file_detail.path"))\t/Media/Anime\n\(L("file_detail.folder_count"))\t3"
        )

        // 2. File Info: dialog title + group titles + left labels (#1, #2) + right values selectable,
        //    while top paired-file dropdown switcher trigger ("Episode_01.mkv") is EXCLUDED.
        WorkbenchStaticTextSelectionCoordinator.shared.clearSelection()
        let videoInfo = FileDetailVideoInfo(
            path: "/Media/Anime/Episode_01.mkv",
            name: "Episode_01.mkv",
            fileSize: 1024 * 1024 * 250,
            duration: 1440,
            videoWidth: 1920,
            videoHeight: 1080,
            frameRate: 23.976,
            videoCodec: "hevc",
            audioTracks: [],
            subtitles: [
                .init(subtitleFileID: 1, subtitlePath: "/Media/Anime/Episode_01.ja.ass", format: .ass),
                .init(subtitleFileID: 2, subtitlePath: "/Media/Anime/Episode_01.en.srt", format: .srt),
            ],
            createdAt: nil,
            modifiedAt: nil
        )
        let fileSession = FileDetailDialogSession(kind: .video(videoInfo))
        let (fileWindow, fileHost) = makeOffscreenHostingWindow(
            rootView: WorkbenchFileDetailDialog(session: fileSession, onClose: {})
                .environment(\.interfaceLayerContext, InterfaceLayerContext(layer: .dialog))
                .environment(\.workbenchDialogAvailableSize, CGSize(width: 680, height: 760)),
            size: CGSize(width: 680, height: 760)
        )
        defer { tearDownOffscreenWindow(fileWindow) }
        let fileViews = collectInteractiveSelectableViews(in: fileHost)
        let fileTexts = fileViews.map(\.text)
        #expect(fileTexts.contains(L("file_detail.title")))
        #expect(fileTexts.contains(L("file_detail.video")))
        #expect(fileTexts.contains(L("file_detail.resolution")))
        #expect(fileTexts.contains(L("file_detail.subtitles")))
        #expect(fileTexts.contains("#1"))
        #expect(fileTexts.contains("#2"))
        #expect(fileTexts.contains("Episode_01.ja.ass"))
        #expect(fileTexts.contains("Episode_01.en.srt"))
        // Top paired-file dropdown trigger text ("Episode_01.mkv") must NOT be a selectable text node.
        #expect(!fileTexts.contains("Episode_01.mkv"))

        let index1Label = try #require(fileViews.first { $0.text == "#1" })
        let sub2Value = try #require(fileViews.first { $0.text == "Episode_01.ja.ass" })
        let idxStart = index1Label.convert(CGPoint(x: 1, y: 8), to: nil)
        let idxEnd = sub2Value.convert(CGPoint(x: sub2Value.bounds.maxX - 1, y: 8), to: nil)
        index1Label.mouseDown(with: makeQueuedMouseEvent(type: .leftMouseDown, locationInWindow: idxStart, windowNumber: fileWindow.windowNumber))
        index1Label.mouseDragged(with: makeQueuedMouseEvent(type: .leftMouseDragged, locationInWindow: idxEnd, windowNumber: fileWindow.windowNumber))
        index1Label.mouseUp(with: makeQueuedMouseEvent(type: .leftMouseUp, locationInWindow: idxEnd, windowNumber: fileWindow.windowNumber))
        #expect(
            WorkbenchStaticTextSelectionCoordinator.shared.selectedText
                == "#1\tEpisode_01.en.srt\n#2\tEpisode_01.ja.ass"
        )

        // 3. Task Info: dialog title + static task type header + group titles + #1/#2 indexed rows.
        WorkbenchStaticTextSelectionCoordinator.shared.clearSelection()
        let taskRecord = TaskRecord(
            id: 7,
            kind: .renameFiles,
            fileName: "ep01-remastered",
            folderPath: "",
            itemCount: 2,
            state: .completed,
            errorMessage: nil,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            stateChangedAt: Date(timeIntervalSince1970: 1_700_000_060),
            oldPaths: ["/Videos/ep01.mkv", "/Videos/ep01.srt"],
            newPaths: ["/Videos/ep01-remastered.mkv", "/Videos/ep01-remastered.srt"]
        )
        let (taskWindow, taskHost) = makeOffscreenHostingWindow(
            rootView: TaskDetailDialog(record: taskRecord, progress: nil, onClose: {})
                .environment(\.interfaceLayerContext, InterfaceLayerContext(layer: .dialog))
                .environment(\.workbenchDialogAvailableSize, CGSize(width: 680, height: 760)),
            size: CGSize(width: 680, height: 760)
        )
        defer { tearDownOffscreenWindow(taskWindow) }
        let taskViews = collectInteractiveSelectableViews(in: taskHost)
        let taskTexts = taskViews.map(\.text)
        #expect(taskTexts.contains(L("task_detail.title")))
        #expect(taskTexts.contains(taskRecord.typeTitle))
        #expect(taskTexts.contains(L("task_detail.section.original_file_names")))
        #expect(taskTexts.contains(L("task_detail.section.new_file_names")))
        #expect(taskTexts.contains(L("task_detail.section.task_status")))

        let tHeader = try #require(taskViews.first { $0.text == L("task_detail.title") })
        let tType = try #require(taskViews.first { $0.text == taskRecord.typeTitle })
        let tStart = tHeader.convert(CGPoint(x: 1, y: 8), to: nil)
        let tEnd = tType.convert(CGPoint(x: tType.bounds.maxX - 1, y: 8), to: nil)
        tHeader.mouseDown(with: makeQueuedMouseEvent(type: .leftMouseDown, locationInWindow: tStart, windowNumber: taskWindow.windowNumber))
        tHeader.mouseDragged(with: makeQueuedMouseEvent(type: .leftMouseDragged, locationInWindow: tEnd, windowNumber: taskWindow.windowNumber))
        tHeader.mouseUp(with: makeQueuedMouseEvent(type: .leftMouseUp, locationInWindow: tEnd, windowNumber: taskWindow.windowNumber))
        #expect(
            WorkbenchStaticTextSelectionCoordinator.shared.selectedText
                == "\(L("task_detail.title"))\n\(taskRecord.typeTitle)"
        )
    }

    @Test
    func modalDialogsAndEmptyHintCoverHeadersFormLabelsSupportTextAndPreserveNativeDragBoundaries() throws {
        WorkbenchStaticTextSelectionCoordinator.shared.clearSelection()
        AppLocalization.apply(.english)
        defer {
            WorkbenchStaticTextSelectionCoordinator.shared.clearSelection()
            AppLocalization.apply(.english)
        }

        // 1. Rename Dialog: header + "Current Name\t<value>" + "New Name" label.
        let renameSession = LibraryRenameSession(rootFolder: URL(fileURLWithPath: "/Media/Season_01"))
        let (renameWindow, renameHost) = makeOffscreenHostingWindow(
            rootView: LibraryRenameDialog(session: renameSession, onConfirm: {}, onClose: {})
                .environment(\.interfaceLayerContext, InterfaceLayerContext(layer: .dialog))
                .environment(\.workbenchDialogAvailableSize, CGSize(width: 560, height: 340)),
            size: CGSize(width: 560, height: 340)
        )
        defer { tearDownOffscreenWindow(renameWindow) }
        let renameViews = collectInteractiveSelectableViews(in: renameHost)
        let renameTitle = try #require(renameViews.first { $0.text == renameSession.title })
        let currentNameLabel = try #require(renameViews.first { $0.text == L("rename.current_name") })
        let currentNameValue = try #require(renameViews.first { $0.text == "Season_01" })
        let newNameLabel = try #require(renameViews.first { $0.text == L("rename.new_name") })
        #expect(!renameViews.map(\.text).contains(L("rename.confirm")))

        let rStart = currentNameLabel.convert(CGPoint(x: 1, y: 8), to: nil)
        let rEnd = newNameLabel.convert(CGPoint(x: newNameLabel.bounds.maxX - 1, y: 8), to: nil)
        _ = renameTitle
        _ = currentNameValue
        currentNameLabel.mouseDown(with: makeQueuedMouseEvent(type: .leftMouseDown, locationInWindow: rStart, windowNumber: renameWindow.windowNumber))
        currentNameLabel.mouseDragged(with: makeQueuedMouseEvent(type: .leftMouseDragged, locationInWindow: rEnd, windowNumber: renameWindow.windowNumber))
        currentNameLabel.mouseUp(with: makeQueuedMouseEvent(type: .leftMouseUp, locationInWindow: rEnd, windowNumber: renameWindow.windowNumber))
        #expect(
            WorkbenchStaticTextSelectionCoordinator.shared.selectedText
                == "\(L("rename.current_name"))\tSeason_01\n\(L("rename.new_name"))"
        )

        // 2. Export to Anki: header, "Front\tBack" peer columns, "File Name" & "Location" labels;
        //    draggable card badges stay non-selectable and preserve .nativeDrag gesture ownership.
        WorkbenchStaticTextSelectionCoordinator.shared.clearSelection()
        let ankiSession = AnkiExportSession(
            items: [],
            options: AnkiExportOptions(
                frontItems: [.cueText, .displayTitle],
                backItems: [.screenshot]
            ),
            folderURL: URL(fileURLWithPath: "/tmp"),
            onOptionsChange: { _ in }
        )
        let (ankiWindow, ankiHost) = makeOffscreenHostingWindow(
            rootView: AnkiExportDialog(
                session: ankiSession,
                onChooseFolder: {},
                onExport: {},
                onClose: {}
            )
            .environment(\.interfaceLayerContext, InterfaceLayerContext(layer: .dialog))
            .environment(\.workbenchDialogAvailableSize, CGSize(width: 680, height: 680)),
            size: CGSize(width: 680, height: 680)
        )
        defer { tearDownOffscreenWindow(ankiWindow) }
        let ankiViews = collectInteractiveSelectableViews(in: ankiHost)
        let ankiTexts = ankiViews.map(\.text)
        #expect(ankiTexts.contains(L("anki_export.title")))
        #expect(ankiTexts.contains(L("anki_export.side.front")))
        #expect(ankiTexts.contains(L("anki_export.side.back")))
        #expect(ankiTexts.contains(L("anki_export.file_name")))
        #expect(ankiTexts.contains(L("anki_export.location")))
        // Draggable card badge titles must NOT be selectable text nodes.
        #expect(!ankiTexts.contains(AnkiCardItem.cueText.title))
        #expect(!ankiTexts.contains(AnkiCardItem.screenshot.title))

        let frontHeader = try #require(ankiViews.first { $0.text == L("anki_export.side.front") })
        let backHeader = try #require(ankiViews.first { $0.text == L("anki_export.side.back") })
        let aStart = frontHeader.convert(CGPoint(x: 1, y: 8), to: nil)
        let aEnd = backHeader.convert(CGPoint(x: backHeader.bounds.maxX - 1, y: 8), to: nil)
        frontHeader.mouseDown(with: makeQueuedMouseEvent(type: .leftMouseDown, locationInWindow: aStart, windowNumber: ankiWindow.windowNumber))
        frontHeader.mouseDragged(with: makeQueuedMouseEvent(type: .leftMouseDragged, locationInWindow: aEnd, windowNumber: ankiWindow.windowNumber))
        frontHeader.mouseUp(with: makeQueuedMouseEvent(type: .leftMouseUp, locationInWindow: aEnd, windowNumber: ankiWindow.windowNumber))
        #expect(
            WorkbenchStaticTextSelectionCoordinator.shared.selectedText
                == "\(L("anki_export.side.front"))\t\(L("anki_export.side.back"))"
        )

        let nativeDragRegions = descendantsForTesting(in: ankiHost).compactMap {
            $0 as? SubtitleTableTextSelectionInteractiveRegionView
        }.filter { $0.interaction == .nativeDrag && $0.bounds.width > 10 && $0.bounds.height > 10 }
        #expect(!nativeDragRegions.isEmpty)
        if let badgeRegion = nativeDragRegions.first {
            let badgePoint = badgeRegion.convert(CGPoint(x: badgeRegion.bounds.midX, y: badgeRegion.bounds.midY), to: nil)
            let hit = ankiHost.hitTest(ankiHost.convert(badgePoint, from: nil))
            #expect(
                SubtitleTableTextSelectionHitTesting.ownsDragOrTextInputGesture(
                    hit,
                    atWindowPoint: badgePoint,
                    in: ankiWindow
                )
            )
        }

        // 3. Filter Dialog: header + section titles selectable; count badges & filter chips excluded.
        WorkbenchStaticTextSelectionCoordinator.shared.clearSelection()
        var activeFilter = CueFacetFilter()
        activeFilter.languages.insert(.japanese)
        let filterSession = CueFacetFilterDialogSession(
            source: .search,
            filter: activeFilter,
            apply: { _ in }
        )
        let (filterWindow, filterHost) = makeOffscreenHostingWindow(
            rootView: CueFacetFilterDialog(
                session: filterSession,
                counts: .unknown,
                availableLanguages: [.japanese, .english],
                availableFolders: [CueFacetFolderOption(path: "/Media/Anime", title: "Anime")],
                onClose: {}
            )
            .environment(\.interfaceLayerContext, InterfaceLayerContext(layer: .dialog))
            .environment(\.workbenchDialogAvailableSize, CGSize(width: 680, height: 640)),
            size: CGSize(width: 680, height: 640)
        )
        defer { tearDownOffscreenWindow(filterWindow) }
        let filterTexts = Set(collectInteractiveSelectableViews(in: filterHost).map(\.text))
        #expect(filterTexts.contains(L("table.filter")))
        #expect(filterTexts.contains(L("facet.language")))
        #expect(filterTexts.contains(L("facet.watch_status")))
        #expect(filterTexts.contains(L("facet.folder")))
        // Filter chips ("Anime", "Japanese") and count badge ("1") must NOT be selectable text nodes.
        #expect(!filterTexts.contains("Anime"))
        #expect(!filterTexts.contains(SubtitleLanguageCode.japanese.title))
        #expect(!filterTexts.contains("1"))

        // 4. Edit Cover & Excerpt List Editor: headers, Name/Description labels, and Cover Support Text selectable;
        //    Cover Crop Editor preserves .nativeDrag gesture ownership.
        let cgImage = try makeTestCGImage()
        let coverSession = LibraryCoverEditingSession(
            target: .video(path: "/Media/ep01.mkv"),
            currentCoverPath: nil,
            currentCoverRevision: nil
        )
        coverSession.selectSource(LibraryUserCoverSource(image: cgImage))
        let (coverWindow, coverHost) = makeOffscreenHostingWindow(
            rootView: LibraryEditCoverDialog(
                session: coverSession,
                onChooseImage: {},
                onCancel: {},
                onSave: {}
            )
            .environment(\.interfaceLayerContext, InterfaceLayerContext(layer: .dialog))
            .environment(\.workbenchDialogAvailableSize, CGSize(width: 520, height: 520)),
            size: CGSize(width: 520, height: 520)
        )
        defer { tearDownOffscreenWindow(coverWindow) }
        let coverTexts = Set(collectInteractiveSelectableViews(in: coverHost).map(\.text))
        #expect(coverTexts.contains(LibraryCoverEditingCopy.dialogTitle))
        #expect(coverTexts.contains(LibraryCoverEditingCopy.hint))
        #expect(!coverTexts.contains(LibraryCoverEditingCopy.saveButtonTitle))

        let cropDragRegion = try #require(
            descendantsForTesting(in: coverHost)
                .compactMap { $0 as? SubtitleTableTextSelectionInteractiveRegionView }
                .first { $0.interaction == .nativeDrag && $0.bounds.width > 40 && $0.bounds.height > 40 }
        )
        let cropCenter = cropDragRegion.convert(
            CGPoint(x: cropDragRegion.bounds.midX, y: cropDragRegion.bounds.midY),
            to: nil
        )
        #expect(
            SubtitleTableTextSelectionHitTesting.ownsDragOrTextInputGesture(
                coverHost.hitTest(coverHost.convert(cropCenter, from: nil)),
                atWindowPoint: cropCenter,
                in: coverWindow
            )
        )

        let excerptSession = ExcerptListEditorSession(mode: .newList)
        let (excerptWindow, excerptHost) = makeOffscreenHostingWindow(
            rootView: ExcerptListEditorDialog(
                session: excerptSession,
                onChooseImage: {},
                onValidate: {},
                onSave: {},
                onClose: {}
            )
            .environment(\.interfaceLayerContext, InterfaceLayerContext(layer: .dialog))
            .environment(\.workbenchDialogAvailableSize, CGSize(width: 560, height: 640)),
            size: CGSize(width: 560, height: 640)
        )
        defer { tearDownOffscreenWindow(excerptWindow) }
        let excerptTexts = Set(collectInteractiveSelectableViews(in: excerptHost).map(\.text))
        #expect(excerptTexts.contains(L("excerpt.new_list")))
        #expect(excerptTexts.contains(LibraryCoverEditingCopy.hint))
        #expect(excerptTexts.contains(L("excerpt.list_name")))
        #expect(excerptTexts.contains(L("excerpt.description")))

        // 5. WebDAV Remote Folder Dialog (Step 1 form labels & Step 2 Empty State) + standalone Empty State (with & without action).
        let webdavSession = WebDAVFolderDialogSession()
        let (webdavWindow, webdavStep1Host) = makeOffscreenHostingWindow(
            rootView: WebDAVFolderDialog(session: webdavSession, onConfirm: {}, onClose: {})
                .environment(\.interfaceLayerContext, InterfaceLayerContext(layer: .dialog))
                .environment(\.workbenchDialogAvailableSize, CGSize(width: 680, height: 560)),
            size: CGSize(width: 680, height: 560)
        )
        defer { tearDownOffscreenWindow(webdavWindow) }
        let step1Texts = Set(collectInteractiveSelectableViews(in: webdavStep1Host).map(\.text))
        #expect(step1Texts.contains(L("webdav.dialog.title")))
        #expect(step1Texts.contains(L("webdav.field.address")))
        #expect(step1Texts.contains(L("webdav.field.username")))
        #expect(step1Texts.contains(L("webdav.field.password")))

        webdavSession.step = .browser
        webdavSession.items = []
        RunLoop.main.run(until: Date().addingTimeInterval(0.03))
        webdavStep1Host.layoutSubtreeIfNeeded()
        let step2Texts = Set(collectInteractiveSelectableViews(in: webdavStep1Host).map(\.text))
        #expect(step2Texts.contains(L("webdav.dialog.title")))
        #expect(step2Texts.contains(L("webdav.empty_folder_items")))

        // Standalone WorkbenchEmptyHint without action button & with action button.
        let (emptyWindow, emptyHost) = makeOffscreenHostingWindow(
            rootView: VStack {
                WorkbenchEmptyHint(icon: .videoQuestion, message: "No matching subtitles found")
                WorkbenchEmptyHint(
                    icon: .folder,
                    message: "Add a media folder to start indexing",
                    actionTitle: "Add Folder",
                    actionIcon: .plus,
                    action: {}
                )
            },
            size: CGSize(width: 480, height: 360)
        )
        defer { tearDownOffscreenWindow(emptyWindow) }
        let emptyViews = collectInteractiveSelectableViews(in: emptyHost)
        let emptyTexts = Set(emptyViews.map(\.text))
        #expect(emptyTexts == ["No matching subtitles found", "Add a media folder to start indexing"])
        #expect(!emptyTexts.contains("Add Folder"))

        let firstEmptyView = try #require(emptyViews.first { $0.text == "No matching subtitles found" })
        let ePoint = firstEmptyView.convert(CGPoint(x: 12, y: 8), to: nil)
        #expect(firstEmptyView.pointerShape(atWindowPoint: ePoint) == .iBeam)
        firstEmptyView.mouseDown(
            with: makeQueuedMouseEvent(
                type: .leftMouseDown,
                locationInWindow: ePoint,
                clickCount: 3,
                windowNumber: emptyWindow.windowNumber
            )
        )
        firstEmptyView.mouseUp(
            with: makeQueuedMouseEvent(
                type: .leftMouseUp,
                locationInWindow: ePoint,
                clickCount: 3,
                windowNumber: emptyWindow.windowNumber
            )
        )
        #expect(WorkbenchStaticTextSelectionCoordinator.shared.selectedText == "No matching subtitles found")

        // 6. Task Panel: top-left "Task" header + empty-state message selectable; center tabs excluded.
        let taskSuiteName = "CueSeekerTests.TaskPanelStaticSelection.\(UUID().uuidString)"
        let taskDefaults = try #require(UserDefaults.temporary(suiteName: taskSuiteName))
        let taskTempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("TaskPanelStaticSelection-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: taskTempRoot, withIntermediateDirectories: true)
        defer {
            taskDefaults.removePersistentDomainAndPlist(forName: taskSuiteName)
            try? FileManager.default.removeItem(at: taskTempRoot)
        }
        let taskLocalization = AppLocalizationStore(
            language: .english,
            userDefaults: taskDefaults,
            userDefaultsKey: "test.task.appLanguage"
        )
        let taskCoordinator = AppCoordinator(
            userDefaults: taskDefaults,
            databaseURL: taskTempRoot.appendingPathComponent("CueSeeker.sqlite")
        )
        let (taskPanelWindow, taskPanelHost) = makeOffscreenHostingWindow(
            rootView: TaskPanel(tasks: taskCoordinator.tasks, confirmation: taskCoordinator.confirmation)
                .environmentObject(taskCoordinator)
                .environmentObject(taskLocalization)
                .environment(\.interfaceLayerContext, InterfaceLayerContext(layer: .dialog))
                .environment(\.workbenchDialogAvailableSize, CGSize(width: 720, height: 560)),
            size: CGSize(width: 720, height: 560)
        )
        defer { tearDownOffscreenWindow(taskPanelWindow) }
        let taskPanelTexts = Set(collectInteractiveSelectableViews(in: taskPanelHost).map(\.text))
        #expect(taskPanelTexts.contains(L("task.title")))
        #expect(taskPanelTexts.contains(L("task.empty.current")))
        #expect(!taskPanelTexts.contains(TaskQueueTab.current.label))
        #expect(!taskPanelTexts.contains(TaskQueueTab.completed.label))
        #expect(!taskPanelTexts.contains(TaskQueueTab.incomplete.label))
    }

    private func descendantsForTesting(in root: NSView) -> [NSView] {
        var output: [NSView] = [root]
        for child in root.subviews {
            output.append(contentsOf: descendantsForTesting(in: child))
        }
        return output
    }
}
