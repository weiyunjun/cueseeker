import AppKit
import SwiftUI
import CueSeekerCore

extension Notification.Name {
    static let cueSeekerShowSettings = Notification.Name("cueSeekerShowSettings")
    static let cueSeekerLeftMouseDown = Notification.Name("cueSeekerLeftMouseDown")
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
    private var windowButtonsProxy: WindowButtonsProxyView?
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
            .environmentObject(appState.indexing)
            .environmentObject(appState.shiori)
            .environmentObject(appState.library)
            .environmentObject(appState.search)
            .environmentObject(appState.playback)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: AppShellLayout.defaultWindowWidth, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.title = "CueSeeker"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = false
        window.acceptsMouseMovedEvents = true
        window.minSize = NSSize(width: AppShellLayout.minimumWindowWidth, height: AppShellLayout.minimumWindowHeight)
        window.delegate = self
        window.center()
        window.contentView = NSHostingView(rootView: contentView)

        if let screen = window.screen ?? NSScreen.main {
            window.setFrame(screen.visibleFrame, display: true)
        }

        self.window = window
        if showImmediately {
            window.makeKeyAndOrderFront(nil)
        }
        adjustTrafficLights()
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

    @objc private func showSettingsFromNotification(_ notification: Notification) {
        showSettings(notification.object)
    }

    @objc private func showSettings(_ sender: Any?) {
        appState.workbenchLayout.clearSearchFocus()

        if let settingsWindow {
            settingsWindow.makeKeyAndOrderFront(sender)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let contentView = SettingsView()
            .environmentObject(appState)
            .environmentObject(appState.workbenchLayout)
            .environmentObject(appState.workbenchLayout.route)
            .environmentObject(appState.settings)
            .environmentObject(appState.settings.cueGroupPresentation)
            .environmentObject(appState.indexing)
            .environmentObject(appState.shiori)
            .environmentObject(appState.library)
            .environmentObject(appState.search)
            .environmentObject(appState.playback)
        let settingsWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 520),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        settingsWindow.title = "Settings"
        settingsWindow.minSize = NSSize(width: 680, height: 420)
        settingsWindow.isReleasedWhenClosed = false
        settingsWindow.contentView = NSHostingView(rootView: contentView)
        settingsWindow.center()
        settingsWindow.makeKeyAndOrderFront(sender)
        self.settingsWindow = settingsWindow
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillEnterFullScreen(_ notification: Notification) {
        appState.playbackFullscreenManager.windowWillEnterFullScreen(notification)
        window?.titleVisibility = .visible
        windowButtonsProxy?.isHidden = true
        appState.workbenchLayout.isAppFullscreen = true
        syncPlaybackWindowTitle()
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // On the video page (including fullscreen via the native titlebar
        // close), close means "return to the originating info page", not quit.
        guard sender === window, appState.isPlaybackPageVisible else {
            return true
        }
        appState.workbenchLayout.clearSearchFocus()
        appState.stopPlayback()
        return false
    }

    private func syncPlaybackWindowTitle() {
        guard let window else { return }
        let desiredTitle = appState.isPlaybackPageVisible
            ? appState.currentPlaybackDisplayTitle
            : "CueSeeker"
        if window.title != desiredTitle {
            window.title = desiredTitle
        }
    }

    func windowDidEnterFullScreen(_ notification: Notification) {
        appState.playbackFullscreenManager.windowDidEnterFullScreen(notification)
    }

    func windowWillExitFullScreen(_ notification: Notification) {
        appState.playbackFullscreenManager.windowWillExitFullScreen(notification)
        window?.titleVisibility = .hidden
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
        DispatchQueue.main.async { [weak self] in
            self?.adjustTrafficLights()
        }
    }

    func windowDidFailToEnterFullScreen(_ window: NSWindow) {
        appState.playbackFullscreenManager.windowDidFailToEnterFullScreen(window)
        window.titleVisibility = .hidden
        appState.workbenchLayout.isAppFullscreen = false
        DispatchQueue.main.async { [weak self] in
            self?.adjustTrafficLights()
        }
    }

    func windowDidFailToExitFullScreen(_ window: NSWindow) {
        appState.playbackFullscreenManager.windowDidFailToExitFullScreen(window)
    }
    
    func windowDidResize(_ notification: Notification) {
        AppPerformanceProbe.measure("AppDelegate.windowDidResize", thresholdMilliseconds: 8) {
            adjustTrafficLights()
        }
    }
    
    func windowDidUpdate(_ notification: Notification) {
        AppPerformanceProbe.measure("AppDelegate.windowDidUpdate", thresholdMilliseconds: 8) {
            adjustTrafficLights()
            syncPlaybackWindowTitle()
        }
    }
    
    private func adjustTrafficLights() {
        AppPerformanceProbe.measure("AppDelegate.adjustTrafficLights", thresholdMilliseconds: 8) {
            guard let window = self.window else { return }

            let standardButtons: [NSWindow.ButtonType] = [.closeButton, .miniaturizeButton, .zoomButton]

            // Fullscreen: macOS owns the native fullscreen titlebar (close +
            // exit-fullscreen). The windowed video page may have hidden these
            // buttons, so restore them and just hide our reparenting proxy.
            if window.styleMask.contains(.fullScreen) {
                for type in standardButtons {
                    window.standardWindowButton(type)?.isHidden = false
                }
                windowButtonsProxy?.isHidden = true
                return
            }

            // Windowed video page: the custom top-bar cluster replaces the
            // native buttons, so hide them and the proxy. The buttons must be
            // hidden directly, not just the proxy, because AppKit can re-add
            // the standard buttons to the real titlebar.
            if appState.isPlaybackPageVisible {
                for type in standardButtons {
                    window.standardWindowButton(type)?.isHidden = true
                }
                windowButtonsProxy?.isHidden = true
                return
            }
        
            guard let contentView = window.contentView else { return }

            if windowButtonsProxy == nil {
                let proxy = WindowButtonsProxyView(
                    frame: NSRect(
                        x: WorkbenchControlMetrics.redesignSpacing6,
                        y: 0,
                        width: 80,
                        height: WorkbenchControlMetrics.redesignAppTopbarHeight
                    )
                )
                contentView.addSubview(proxy)
                windowButtonsProxy = proxy
            } else if let proxy = windowButtonsProxy, proxy.superview !== contentView {
                proxy.removeFromSuperview()
                contentView.addSubview(proxy)
            }
        
            guard let proxy = windowButtonsProxy else { return }
            proxy.isHidden = false
        
            let proxyY = contentView.isFlipped ? 0 : contentView.frame.height - proxy.frame.height
            proxy.frame.origin = CGPoint(
                x: WorkbenchControlMetrics.redesignSpacing6,
                y: proxyY
            )
        
            let buttons: [NSWindow.ButtonType] = [.closeButton, .miniaturizeButton, .zoomButton]
            var xOffset: CGFloat = 0
            let targetCenterFromTop = WorkbenchControlMetrics.redesignAppTopbarHeight / 2
        
            for type in buttons {
                guard let button = window.standardWindowButton(type) else { continue }

                // Restore visibility after video-page / fullscreen suppression.
                button.isHidden = false

                if button.superview !== proxy {
                    proxy.addSubview(button)
                }
            
                // Prevent clipping just in case
                button.superview?.clipsToBounds = false
            
                let targetY: CGFloat
                if proxy.isFlipped {
                    targetY = targetCenterFromTop - (button.frame.height / 2)
                } else {
                    targetY = proxy.frame.height - targetCenterFromTop - (button.frame.height / 2)
                }
            
                button.frame.origin = CGPoint(x: xOffset, y: targetY)
                // Native inter-button spacing is roughly 6pt (button width is typically 14, standard origin diff is 20)
                xOffset += button.frame.width + 6
            }
        }
    }

    private func configureMainMenu() {
        let mainMenu = NSMenu()

        // App Menu
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        let settingsItem = NSMenuItem(
            title: "Settings...",
            action: #selector(showSettings(_:)),
            keyEquivalent: ","
        )
        settingsItem.target = self
        appMenu.addItem(settingsItem)
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(
            NSMenuItem(
                title: "Quit \(ApplicationInfo.name)",
                action: #selector(NSApplication.terminate(_:)),
                keyEquivalent: "q"
            )
        )
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        // Edit Menu
        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(NSMenuItem(title: "Undo", action: Selector(("undo:")), keyEquivalent: "z"))
        editMenu.addItem(NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "Z"))
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem(title: "Delete", action: #selector(NSText.delete(_:)), keyEquivalent: "\u{8}")) // Backspace
        editMenu.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        NSApp.mainMenu = mainMenu
    }
}

/// A transparent proxy view that holds the native traffic light buttons.
/// It ignores hit testing on itself so clicks pass through to the background,
/// but allows clicks on its subviews (the buttons).
final class WindowButtonsProxyView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        let view = super.hitTest(point)
        return view === self ? nil : view
    }
}
