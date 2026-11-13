import AppKit
import SwiftUI
import CueSeekerCore
import CueSeekerPlayback

extension Notification.Name {
    static let cueSeekerShowSettings = Notification.Name("cueSeekerShowSettings")
    static let cueSeekerAppLanguageChanged = Notification.Name("cueSeekerAppLanguageChanged")
    static let cueSeekerLeftMouseDown = Notification.Name("cueSeekerLeftMouseDown")
    /// Posted when a menu opens. Every surface holding selected text drops it,
    /// so no selection outlives the menu that covered it.
    static let cueSeekerClearTextSelection = Notification.Name("cueSeekerClearTextSelection")
    /// Posted when a pointer press on a click-only control transitions into
    /// external table text selection, cancelling any pressed visual state.
    static let cueSeekerCancelControlPress = Notification.Name("cueSeekerCancelControlPress")
}

enum CueSeekerPointerEventRouter {
    static func routeLeftMouseDown(_ event: NSEvent) -> NSEvent {
        NotificationCenter.default.post(
            name: .cueSeekerLeftMouseDown,
            object: event
        )
        return event
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuItemValidation {
    private var window: NSWindow?
    private var settingsWindow: NSWindow?
    private weak var pendingForegroundWindow: NSWindow?
    private let appState = AppCoordinator()
    private var keyDownMonitor: Any?
    private var leftMouseDownMonitor: Any?
    private var controllerInputMonitor: GameControllerInputMonitor?
    private var pendingURLSchemeCommand: URLSchemeCommand?
#if DEBUG
    private var debugE2EController: DebugE2EController?
#endif

    func applicationWillFinishLaunching(_ notification: Notification) {
        AppLogger.shared.performStartupMaintenance()
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURLEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let shortVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
        let buildVersion = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        let osVersion = ProcessInfo.processInfo.operatingSystemVersion
        let osVersionString = "\(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion)"
        let memoryGB = Int((Double(ProcessInfo.processInfo.physicalMemory) / (1024 * 1024 * 1024)).rounded())
        let maxEDRHeadroom = NSScreen.main?.maximumPotentialExtendedDynamicRangeColorComponentValue ?? 1.0
        let mainDisplayHDR = maxEDRHeadroom > 1.0
        AppLogger.shared.info(
            .app,
            "App launched",
            fields: [
                ("version", "\(shortVersion)(\(buildVersion))"),
                ("build", AppBuildConfiguration.current.rawValue),
                ("telemetry", AppDiagnosticTelemetryCollectionMode.current.rawValue),
                ("macOS", osVersionString),
                ("arch", Self.hardwareArchitectureString()),
                ("chip", Self.hardwareChipBrandString()),
                ("memory_gb", "\(memoryGB)"),
                ("main_display_hdr", mainDisplayHDR ? "1" : "0"),
                ("max_edr_headroom", String(format: "%.2f", maxEDRHeadroom))
            ]
        )
        AppPerformanceProbe.mark("MARK CueSeeker.applicationDidFinishLaunching")
        UIInvalidationProbe.markStartup()
        AppPerformanceProbe.startMainThreadWatchdog()
        AppPerformanceProbe.startMainRunLoopObserver()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(showSettingsFromNotification(_:)),
            name: .cueSeekerShowSettings,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applyLanguageChange(_:)),
            name: .cueSeekerAppLanguageChanged,
            object: nil
        )
        configureMainMenu()
        let launchesFromPendingURLSchemeCommand = pendingURLSchemeCommand != nil
        createMainWindow(showImmediately: !launchesFromPendingURLSchemeCommand)
        configurePlaybackKeyboardShortcuts()
        configureControllerInput()
        configurePointerEventRouting()
        consumePendingURLSchemeCommand()
        if !launchesFromPendingURLSchemeCommand {
            presentMainWindow()
        }
        DispatchQueue.main.async { [weak self, appState] in
            appState.ensurePlayerInitialized()
            _ = appState.player?.renderView
            PlaybackPlayer.warmUpSubtitleEnvironmentInBackground()
            guard let self,
                  let targetWindow = self.pendingForegroundWindow,
                  targetWindow.isVisible,
                  !targetWindow.isMiniaturized
            else {
                return
            }
            if !NSApp.isActive || !targetWindow.isKeyWindow {
                NSRunningApplication.current.activate(
                    options: [.activateAllWindows, .activateIgnoringOtherApps]
                )
                NSApp.activate(ignoringOtherApps: true)
                targetWindow.makeKeyAndOrderFront(nil)
            }
        }
#if DEBUG
        configureDebugE2EIfRequested()
#endif
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        guard let targetWindow = pendingForegroundWindow,
              targetWindow.isVisible,
              !targetWindow.isMiniaturized
        else {
            pendingForegroundWindow = nil
            return
        }
        targetWindow.makeKeyAndOrderFront(nil)
        DispatchQueue.main.async { [weak self, weak targetWindow] in
            guard let self,
                  let targetWindow,
                  self.pendingForegroundWindow === targetWindow,
                  targetWindow.isVisible,
                  !targetWindow.isMiniaturized
            else {
                return
            }
            if NSApp.isActive, !targetWindow.isKeyWindow {
                targetWindow.makeKeyAndOrderFront(nil)
            }
            self.pendingForegroundWindow = nil
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    /// Only a Confirmation keeps the App open: Cmd+Q and the Dock's Quit do
    /// nothing while one is up. The system's own quit — log out, restart,
    /// shut down — is never held; the confirmed action simply does not run.
    /// See `docs/human/requirements/20260911-UI-In-Window Dialogs And Only
    /// Confirmation Blocks Closing.md`.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard appState.isBlockingConfirmationPresented,
              !Self.isSystemQuit(NSAppleEventManager.shared().currentAppleEvent)
        else {
            return .terminateNow
        }
        return .terminateCancel
    }

    /// The system states why it asks the App to quit; Cmd+Q and the Dock do
    /// not.
    private static func isSystemQuit(_ event: NSAppleEventDescriptor?) -> Bool {
        guard let event,
              event.eventClass == AEEventClass(kCoreEventClass),
              event.eventID == AEEventID(kAEQuitApplication)
        else {
            return false
        }
        let keyword = AEKeyword(kAEQuitReason)
        let reason = event.paramDescriptor(forKeyword: keyword)
            ?? event.attributeDescriptor(forKeyword: keyword)
        guard let reason = reason?.enumCodeValue else {
            return false
        }
        return [kAEShutDown, kAERestart, kAEReallyLogOut, kAEQuitAll]
            .map { OSType($0) }
            .contains(reason)
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let keyDownMonitor {
            NSEvent.removeMonitor(keyDownMonitor)
            self.keyDownMonitor = nil
        }
        if let leftMouseDownMonitor {
            NSEvent.removeMonitor(leftMouseDownMonitor)
            self.leftMouseDownMonitor = nil
        }
        controllerInputMonitor?.stop()
        controllerInputMonitor = nil
        NotificationCenter.default.removeObserver(self)
        NSAppleEventManager.shared().removeEventHandler(
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
        appState.saveCurrentLibraryPlaybackHistorySynchronously()
        appState.playbackFullscreenManager.exitFullscreen()
        AppLogger.shared.info(.app, "App terminating")
        AppLogger.shared.flush()
    }

    @objc private func handleGetURLEvent(
        _ event: NSAppleEventDescriptor,
        withReplyEvent replyEvent: NSAppleEventDescriptor
    ) {
        guard let urlString = event.paramDescriptor(
            forKeyword: AEKeyword(keyDirectObject)
        )?.stringValue,
              let command = URLSchemeCommand(urlString: urlString)
        else {
            return
        }

        guard window != nil else {
            pendingURLSchemeCommand = command
            return
        }
        executeURLSchemeCommand(command)
    }

    private func consumePendingURLSchemeCommand() {
        guard let command = pendingURLSchemeCommand else {
            return
        }
        pendingURLSchemeCommand = nil
        executeURLSchemeCommand(command)
    }

    private func executeURLSchemeCommand(_ command: URLSchemeCommand) {
        appState.handleURLSchemeCommand(command) { [weak self] in
            self?.presentMainWindow()
        }
    }

    private func presentMainWindow() {
        activateWindowForForeground(window)
    }

    private func activateWindowForForeground(_ targetWindow: NSWindow?, sender: Any? = nil) {
        guard let targetWindow else {
            return
        }
        pendingForegroundWindow = targetWindow
        if targetWindow.isMiniaturized {
            targetWindow.deminiaturize(sender)
        }
        NSRunningApplication.current.activate(
            options: [.activateAllWindows, .activateIgnoringOtherApps]
        )
        NSApp.activate(ignoringOtherApps: true)
        targetWindow.makeKeyAndOrderFront(sender)

        DispatchQueue.main.async { [weak self, weak targetWindow] in
            guard let self,
                  let targetWindow,
                  self.pendingForegroundWindow === targetWindow,
                  targetWindow.isVisible,
                  !targetWindow.isMiniaturized
            else {
                return
            }
            if !NSApp.isActive || !targetWindow.isKeyWindow {
                NSRunningApplication.current.activate(
                    options: [.activateAllWindows, .activateIgnoringOtherApps]
                )
                NSApp.activate(ignoringOtherApps: true)
                targetWindow.makeKeyAndOrderFront(nil)
            }
            if NSApp.isActive && targetWindow.isKeyWindow {
                self.pendingForegroundWindow = nil
            }
        }
    }

    private func createMainWindow(showImmediately: Bool) {
        let contentView = ContentView()
            .environmentObject(appState)
            .environmentObject(appState.workbenchLayout)
            .environmentObject(appState.workbenchLayout.route)
            .environmentObject(appState.settings)
            .environmentObject(appState.settings.playbackShortcuts)
            .environmentObject(appState.settings.cueGroupPresentation)
            .environmentObject(appState.settings.localization)
            .environmentObject(appState.indexing)
            .environmentObject(appState.excerpt)
            .environmentObject(appState.library)
            .environmentObject(appState.search)
            .environmentObject(appState.playback)
            .environmentObject(appState.filterDialog)
            .environmentObject(appState.workbenchAccessibility)

        let window = CueSeekerMainWindow(
            contentRect: NSRect(x: 0, y: 0, width: AppShellLayout.defaultWindowWidth, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.onMouseDownClearAccessibility = { [appState] in
            MainActor.assumeIsolated {
                _ = appState.workbenchAccessibility.clear()
                _ = appState.workbenchAccessibility.clearDialog(keepTextInputFocus: true)
                appState.clearPlaybackAccessibilityFocus(keepTextInputFocus: true)
                MenuHighlightModel.broadcastMouseDown()
            }
        }
        // While a menu owns input nothing under it may take the keyboard back.
        window.isFocusLocked = { [appState] in
            MainActor.assumeIsolated {
                appState.interfaceLayers.hasUncoveredOpenMenu
            }
        }
        window.dialogSize = { [appState] in
            MainActor.assumeIsolated {
                appState.interfaceLayers.topDialogSize
            }
        }
        window.isWorkbenchCovered = { [appState] in
            MainActor.assumeIsolated {
                appState.interfaceLayers.isCovered(.workbenchPage)
            }
        }
        window.handlesFullscreenRequest = { [appState] in
            MainActor.assumeIsolated {
                guard appState.isPlaybackPageVisible,
                      appState.playbackFullscreenManager.state == .windowed
                else {
                    return false
                }
                appState.togglePlaybackFullscreenFromUser()
                return true
            }
        }

        window.title = L("app.name")
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = false
        window.acceptsMouseMovedEvents = true
        window.minSize = NSSize(width: AppShellLayout.minimumWindowWidth, height: AppShellLayout.minimumWindowHeight)
        window.delegate = self
        window.center()
        // Measured and placed before the content view is hosted: the top bar
        // reads the window controls' width on its first layout, and a reading
        // taken later would not reach a layout that never changes again.
        AppWindowControls.attach(to: window)
        let hostingView = CueSeekerHostingView(rootView: contentView)
        // The window controls' band is not a safe area to the pages: every
        // page lays itself out from the window's top edge with the band's
        // token. Left as a safe area, SwiftUI drops any subtree that lies
        // wholly inside the band - a top bar of exactly the band's height
        // is neither drawn nor hit-tested.
        if #available(macOS 13.3, *) {
            hostingView.safeAreaRegions = []
        }
        window.contentView = hostingView
        AppPointerShape.attach(
            to: window,
            isMenuOpen: { [appState] in
                appState.interfaceLayers.hasUncoveredOpenMenu
            },
            allowsMenuModalIBeam: { [appState] in
                appState.interfaceLayers.menuGate.isOpen(.coverSummaryDescriptionPopover)
            }
        )

        if let screen = window.screen ?? NSScreen.main {
            window.setFrame(screen.visibleFrame, display: true)
        }

        self.window = window
        if showImmediately {
            presentMainWindow()
        }
    }

    private func configurePlaybackKeyboardShortcuts() {
        keyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, event.window === self.window else {
                return event
            }

            let keyCode = event.keyCode
            let modifierFlags = event.modifierFlags
                .intersection(.deviceIndependentFlagsMask)
                .rawValue
            let handled = MainActor.assumeIsolated {
                // An open dialog owns the keyboard; the player under it hears
                // nothing.
                guard !self.appState.interfaceLayers.isOpen(.dialog) else {
                    return false
                }
                return self.appState.handlePlaybackKeyDown(
                    keyCode: keyCode,
                    modifierFlagsRawValue: modifierFlags,
                    isRepeat: event.isARepeat,
                    window: event.window
                )
            }

            return handled ? nil : event
        }
    }

    private func configurePointerEventRouting() {
        leftMouseDownMonitor = NSEvent.addLocalMonitorForEvents(
            matching: .leftMouseDown
        ) { event in
            CueSeekerPointerEventRouter.routeLeftMouseDown(event)
        }
    }

    private func configureControllerInput() {
        let monitor = GameControllerInputMonitor(
            inputEligibility: { [weak self] in
                guard let self else {
                    return false
                }
                let isMainFocused = NSApplication.shared.isActive && self.window?.isKeyWindow == true
                let isSettingsFocused = NSApplication.shared.isActive && self.settingsWindow?.isKeyWindow == true
                return isMainFocused || isSettingsFocused
            }
        ) { [weak self] input in
            guard let self else {
                return false
            }
            let isMainFocused = NSApplication.shared.isActive && self.window?.isKeyWindow == true
            let isSettingsFocused = NSApplication.shared.isActive && self.settingsWindow?.isKeyWindow == true
            return self.appState.handleGlobalControllerInput(
                input,
                isMainWindowKey: isMainFocused,
                isSettingsWindowKey: isSettingsFocused
            )
        }
        controllerInputMonitor = monitor
        monitor.start()
    }

#if DEBUG
    private func configureDebugE2EIfRequested() {
        guard DebugE2EController.isRequested(), let window else {
            return
        }

        do {
            let controller = try DebugE2EController(mainWindow: window)
            debugE2EController = controller
            controller.start()
        } catch {
            DebugE2EController.reportStartupError(error)
        }
    }
#endif

    /// The menu bar and window titles are AppKit state that does not take part
    /// in SwiftUI invalidation, so they are refreshed explicitly.
    @objc private func applyLanguageChange(_ notification: Notification) {
        AppLogger.shared.info(
            .app,
            "App language changed",
            details: "language=\(appState.settings.localization.language.rawValue)"
        )
        configureMainMenu()
        window?.title = L("app.name")
        settingsWindow?.title = L("settings.window.title")
    }

    @objc private func showSettingsFromNotification(_ notification: Notification) {
        showSettings(notification.object)
    }

    @objc private func showSettings(_ sender: Any?) {
        let startedAt = DebugInteractionLatencyProbe.now()
        let wasCreated = settingsWindow != nil
        let targetCategory = appState.workbenchAccessibility.selectedSettingsCategory.rawValue
        AppLogger.shared.info(.app, "Settings window opened")
        appState.workbenchLayout.clearSearchFocus()
        appState.workbenchLayout.isSettingsWindowOpen = true

        if let settingsWindow {
            // Ordering a window that sits in the Dock to the front draws it at
            // its own place for a frame before the system notices it is still
            // minimised, so the restore has to be asked for on its own.
            activateWindowForForeground(settingsWindow, sender: sender)
            DebugInteractionLatencyProbe.completeImmediateNavigation(
                domain: "settings",
                from: "closed_cached",
                to: "settings_\(targetCategory)",
                trigger: "open_settings_window",
                startedAt: startedAt
            )
            return
        }

        let settingsInterfaceLayers = appState.settingsInterfaceLayers
        let contentView = SettingsView()
            .modifier(InterfaceLayerCoverageBridge(layers: settingsInterfaceLayers))
            .environment(\.workbenchAccessibility, appState.workbenchAccessibility)
            .environmentObject(appState)
            .environmentObject(appState.workbenchLayout)
            .environmentObject(appState.workbenchLayout.route)
            .environmentObject(appState.settings)
            .environmentObject(appState.settings.cueGroupPresentation)
            .environmentObject(appState.settings.localization)
            .environmentObject(appState.settings.playbackShortcuts)
            .environmentObject(appState.indexing)
            .environmentObject(appState.excerpt)
            .environmentObject(appState.library)
            .environmentObject(appState.search)
            .environmentObject(appState.playback)
            .environmentObject(appState.workbenchAccessibility)
        let settingsWindow = CueSeekerWindow(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: WorkbenchControlMetrics.redesignSettingsWindowWidth,
                height: WorkbenchControlMetrics.redesignSettingsWindowHeight
            ),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        settingsWindow.onMouseDownClearAccessibility = { [appState] in
            MainActor.assumeIsolated {
                _ = appState.workbenchAccessibility.clearSettings(
                    keepTextInputFocus: true,
                    keepColorPopoverOpen: true
                )
                _ = appState.workbenchAccessibility.clearSettingsDialog()
                MenuHighlightModel.broadcastMouseDown()
            }
        }
        settingsWindow.isFocusLocked = { [settingsInterfaceLayers] in
            MainActor.assumeIsolated {
                settingsInterfaceLayers.hasUncoveredOpenMenu
                    || settingsInterfaceLayers.isOpen(.dialog)
            }
        }
        settingsWindow.title = L("settings.window.title")
        settingsWindow.titleVisibility = .hidden
        settingsWindow.titlebarAppearsTransparent = true
        settingsWindow.minSize = NSSize(
            width: WorkbenchControlMetrics.redesignSettingsWindowWidth,
            height: WorkbenchControlMetrics.redesignSettingsWindowMinimumHeight
        )
        settingsWindow.isReleasedWhenClosed = false
        settingsWindow.contentView = CueSeekerHostingView(rootView: contentView)
        settingsWindow.center()
        self.settingsWindow = settingsWindow
        // The topbar's Settings button stays lit while this window is open, so
        // the window's own close is what puts it out again.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(settingsWindowWillClose(_:)),
            name: NSWindow.willCloseNotification,
            object: settingsWindow
        )
        activateWindowForForeground(settingsWindow, sender: sender)
        _ = wasCreated
        DebugInteractionLatencyProbe.completeImmediateNavigation(
            domain: "settings",
            from: "closed_uninitialized",
            to: "settings_\(targetCategory)",
            trigger: "open_settings_window",
            startedAt: startedAt
        )
    }

    @objc private func settingsWindowWillClose(_ notification: Notification) {
        if pendingForegroundWindow === settingsWindow {
            pendingForegroundWindow = nil
        }
        appState.workbenchLayout.isSettingsWindowOpen = false
        _ = appState.workbenchAccessibility.clearSettings(
            keepTextInputFocus: false,
            keepColorPopoverOpen: false
        )
        _ = appState.workbenchAccessibility.clearSettingsDialog()
        if NSApp.isActive,
           let window,
           window.isVisible,
           !window.isMiniaturized {
            window.makeKeyAndOrderFront(nil)
        }
    }

    func windowWillEnterFullScreen(_ notification: Notification) {
        if let window = notification.object as? NSWindow {
            appState.windowWillEnterSystemFullscreen(window)
        }
        appState.playbackFullscreenManager.windowWillEnterFullScreen(notification)
        window?.titleVisibility = .visible
        AppWindowControls.windowWillEnterFullScreen()
        appState.workbenchLayout.isAppFullscreen = true
    }

    func windowDidEnterFullScreen(_ notification: Notification) {
        appState.playbackFullscreenManager.windowDidEnterFullScreen(notification)
        AppWindowControls.windowDidEnterFullScreen()
    }

    func windowWillExitFullScreen(_ notification: Notification) {
        appState.playbackFullscreenManager.windowWillExitFullScreen(notification)
        window?.titleVisibility = .hidden
        AppWindowControls.windowWillExitFullScreen()
        appState.workbenchLayout.isAppFullscreen = false
    }

    /// File panels and Export to Anki's replace warning are the only sheets
    /// left on the main window.
    func windowWillBeginSheet(_ notification: Notification) {
        appState.interfaceLayers.setSystemSheetAttached(true)
    }

    func windowDidEndSheet(_ notification: Notification) {
        appState.interfaceLayers.setSystemSheetAttached(window?.attachedSheet != nil)
    }

    func windowWillClose(_ notification: Notification) {
        AppLogger.shared.info(.app, "Main window closing")
        appState.playbackFullscreenManager.windowWillClose(notification)
        appState.saveCurrentLibraryPlaybackHistorySynchronously()
        appState.playbackFullscreenManager.exitFullscreen()
    }

    func windowDidExitFullScreen(_ notification: Notification) {
        appState.playbackFullscreenManager.windowDidExitFullScreen(notification)
        window?.titleVisibility = .hidden
        AppWindowControls.windowDidLeaveSystemTitlebar()
    }

    func windowDidFailToEnterFullScreen(_ window: NSWindow) {
        appState.playbackFullscreenManager.windowDidFailToEnterFullScreen(window)
        window.titleVisibility = .hidden
        appState.workbenchLayout.isAppFullscreen = false
        AppWindowControls.windowDidLeaveSystemTitlebar()
    }

    func windowDidFailToExitFullScreen(_ window: NSWindow) {
        appState.playbackFullscreenManager.windowDidFailToExitFullScreen(window)
        AppWindowControls.windowDidEnterFullScreen()
    }
    
    private func configureMainMenu() {
        let mainMenu = NSMenu()

        // App Menu
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        let settingsItem = NSMenuItem(
            title: L("menu.settings"),
            action: #selector(showSettings(_:)),
            keyEquivalent: ","
        )
        settingsItem.target = self
        appMenu.addItem(settingsItem)
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(
            NSMenuItem(
                title: L("menu.quit", L("app.name")),
                action: #selector(NSApplication.terminate(_:)),
                keyEquivalent: "q"
            )
        )
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        // Edit Menu
        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: L("menu.edit"))
        editMenu.addItem(NSMenuItem(title: L("menu.edit.undo"), action: Selector(("undo:")), keyEquivalent: "z"))
        editMenu.addItem(NSMenuItem(title: L("menu.edit.redo"), action: Selector(("redo:")), keyEquivalent: "Z"))
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(NSMenuItem(title: L("menu.edit.cut"), action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: L("menu.edit.copy"), action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: L("menu.edit.paste"), action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem(title: L("menu.edit.delete"), action: #selector(NSText.delete(_:)), keyEquivalent: "\u{8}")) // Backspace
        let selectAllItem = NSMenuItem(
            title: L("menu.edit.select_all"),
            action: #selector(performSelectAll(_:)),
            keyEquivalent: "a"
        )
        selectAllItem.target = self
        editMenu.addItem(selectAllItem)
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        // Window Menu
        let windowMenuItem = NSMenuItem(
            title: L("menu.window"),
            action: nil,
            keyEquivalent: ""
        )
        let windowMenu = NSMenu(title: L("menu.window"))
        windowMenu.addItem(
            NSMenuItem(
                title: L("menu.window.minimize"),
                action: #selector(NSWindow.performMiniaturize(_:)),
                keyEquivalent: "m"
            )
        )
        windowMenu.addItem(
            NSMenuItem(
                title: L("menu.window.zoom"),
                action: #selector(NSWindow.performZoom(_:)),
                keyEquivalent: ""
            )
        )
        windowMenu.addItem(NSMenuItem.separator())
        windowMenu.addItem(
            NSMenuItem(
                title: L("menu.window.bring_all_to_front"),
                action: #selector(NSApplication.arrangeInFront(_:)),
                keyEquivalent: ""
            )
        )
        windowMenuItem.submenu = windowMenu
        mainMenu.addItem(windowMenuItem)

        NSApp.mainMenu = mainMenu
        NSApp.windowsMenu = windowMenu
    }

    static func canPerformSelectAll(in window: NSWindow? = nil) -> Bool {
        AppCoordinator.isEditableTextInputFocused(in: window ?? CueSeekerWindow.activeKeyWindow)
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(performSelectAll(_:)) {
            return Self.canPerformSelectAll()
        }
        return true
    }

    @discardableResult
    static func performSelectAll(in window: NSWindow? = nil, sender: Any? = nil) -> Bool {
        let targetWindow = window
            ?? CueSeekerWindow.activeKeyWindow
            ?? NSApplication.shared.windows.first { $0 is CueSeekerMainWindow }
        guard let targetWindow,
              canPerformSelectAll(in: targetWindow),
              let responder = targetWindow.firstResponder
        else {
            return false
        }
        if let field = responder as? WorkbenchNativeSingleLineTextField {
            field.selectAllInCurrentEditor()
            return true
        }
        return responder.tryToPerform(#selector(NSText.selectAll(_:)), with: sender)
    }

    @objc func performSelectAll(_ sender: Any?) {
        _ = Self.performSelectAll(sender: sender)
    }

    private static func hardwareArchitectureString() -> String {
        #if arch(arm64)
        return "arm64"
        #elseif arch(x86_64)
        return "x86_64"
        #else
        return "unknown"
        #endif
    }

    private static func hardwareChipBrandString() -> String {
        if let brand = sysctlString(named: "machdep.cpu.brand_string"), !brand.isEmpty {
            return brand
        }
        if let model = sysctlString(named: "hw.model"), !model.isEmpty {
            return model
        }
        return "unknown"
    }

    private static func sysctlString(named name: String) -> String? {
        var size: Int = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else {
            return nil
        }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else {
            return nil
        }
        let nullTerminated = buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
        return String(decoding: nullTerminated, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
