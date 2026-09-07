import AppKit
import SwiftUI
import CueSeekerCore

extension Notification.Name {
    static let cueSeekerShowSettings = Notification.Name("cueSeekerShowSettings")
    static let cueSeekerAppLanguageChanged = Notification.Name("cueSeekerAppLanguageChanged")
    static let cueSeekerLeftMouseDown = Notification.Name("cueSeekerLeftMouseDown")
    /// Posted when a menu opens. Every surface holding selected text drops it,
    /// so no selection outlives the menu that covered it.
    static let cueSeekerClearTextSelection = Notification.Name("cueSeekerClearTextSelection")
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
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var window: NSWindow?
    private var settingsWindow: NSWindow?
    private let appState = AppCoordinator()
    private var keyDownMonitor: Any?
    private var leftMouseDownMonitor: Any?
    private var controllerInputMonitor: GameControllerInputMonitor?
    private var pendingURLSchemeCommand: URLSchemeCommand?
#if DEBUG
    private var debugE2EController: DebugE2EController?
#endif

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURLEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
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
            NSApp.activate(ignoringOtherApps: true)
        }
#if DEBUG
        configureDebugE2EIfRequested()
#endif
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
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
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func createMainWindow(showImmediately: Bool) {
        let contentView = ContentView()
            .environmentObject(appState)
            .environmentObject(appState.workbenchLayout)
            .environmentObject(appState.workbenchLayout.route)
            .environmentObject(appState.settings)
            .environmentObject(appState.settings.cueGroupPresentation)
            .environmentObject(appState.settings.localization)
            .environmentObject(appState.indexing)
            .environmentObject(appState.shiori)
            .environmentObject(appState.library)
            .environmentObject(appState.search)
            .environmentObject(appState.playback)

        let window = CueSeekerMainWindow(
            contentRect: NSRect(x: 0, y: 0, width: AppShellLayout.defaultWindowWidth, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        // While a menu owns input nothing under it may take the keyboard back.
        window.isFocusLocked = { [appState] in
            MainActor.assumeIsolated {
                appState.interfaceLayers.hasUncoveredOpenMenu
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
        window.contentView = CueSeekerHostingView(rootView: contentView)
        AppPointerShape.attach(to: window) { [appState] in
            appState.interfaceLayers.hasUncoveredOpenMenu
        }

        if let screen = window.screen ?? NSScreen.main {
            window.setFrame(screen.visibleFrame, display: true)
        }

        self.window = window
        if showImmediately {
            window.makeKeyAndOrderFront(nil)
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
                self.appState.handlePlaybackKeyDown(
                    keyCode: keyCode,
                    modifierFlagsRawValue: modifierFlags,
                    isRepeat: event.isARepeat
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
                guard let self,
                      NSApplication.shared.isActive,
                      self.window?.isKeyWindow == true
                else {
                    return false
                }
                return self.appState.isPlaybackPageVisible
                    || self.appState.playbackFullscreenManager.isFullscreen
            }
        ) { [weak self] input in
            guard let self else {
                return false
            }
            return self.appState.handlePlaybackControllerInput(input)
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
        configureMainMenu()
        window?.title = L("app.name")
        settingsWindow?.title = L("settings.window.title")
    }

    @objc private func showSettingsFromNotification(_ notification: Notification) {
        showSettings(notification.object)
    }

    @objc private func showSettings(_ sender: Any?) {
        appState.workbenchLayout.clearSearchFocus()
        appState.workbenchLayout.isSettingsWindowOpen = true

        if let settingsWindow {
            // Ordering a window that sits in the Dock to the front draws it at
            // its own place for a frame before the system notices it is still
            // minimised, so the restore has to be asked for on its own.
            if settingsWindow.isMiniaturized {
                settingsWindow.deminiaturize(sender)
            } else {
                settingsWindow.makeKeyAndOrderFront(sender)
            }
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let contentView = SettingsView()
            .environmentObject(appState)
            .environmentObject(appState.workbenchLayout)
            .environmentObject(appState.workbenchLayout.route)
            .environmentObject(appState.settings)
            .environmentObject(appState.settings.cueGroupPresentation)
            .environmentObject(appState.settings.localization)
            .environmentObject(appState.indexing)
            .environmentObject(appState.shiori)
            .environmentObject(appState.library)
            .environmentObject(appState.search)
            .environmentObject(appState.playback)
        let settingsWindow = NSWindow(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: WorkbenchControlMetrics.redesignSettingsWindowDefaultWidth,
                height: WorkbenchControlMetrics.redesignSettingsWindowDefaultHeight
            ),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        settingsWindow.title = L("settings.window.title")
        settingsWindow.titleVisibility = .hidden
        settingsWindow.titlebarAppearsTransparent = true
        settingsWindow.minSize = NSSize(
            width: WorkbenchControlMetrics.redesignSettingsWindowMinimumWidth,
            height: WorkbenchControlMetrics.redesignSettingsWindowMinimumHeight
        )
        settingsWindow.isReleasedWhenClosed = false
        settingsWindow.contentView = NSHostingView(rootView: contentView)
        settingsWindow.center()
        settingsWindow.makeKeyAndOrderFront(sender)
        self.settingsWindow = settingsWindow
        // The topbar's Settings button stays lit while this window is open, so
        // the window's own close is what puts it out again.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(settingsWindowWillClose(_:)),
            name: NSWindow.willCloseNotification,
            object: settingsWindow
        )
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func settingsWindowWillClose(_ notification: Notification) {
        appState.workbenchLayout.isSettingsWindowOpen = false
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

    func windowWillClose(_ notification: Notification) {
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
        editMenu.addItem(NSMenuItem(title: L("menu.edit.select_all"), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
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
}
