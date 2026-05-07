import AppKit
import SwiftUI
import CueSeekerCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var window: NSWindow?
    private var settingsWindow: NSWindow?
    private let appState = AppState()
    private var windowButtonsProxy: WindowButtonsProxyView?
    private var keyDownMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureMainMenu()
        createMainWindow()
        configurePlaybackKeyboardShortcuts()
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let keyDownMonitor {
            NSEvent.removeMonitor(keyDownMonitor)
            self.keyDownMonitor = nil
        }
        appState.saveCurrentLibraryPlaybackHistorySynchronously()
        appState.playbackFullscreenManager.exitFullscreen()
    }

    private func createMainWindow() {
        let contentView = ContentView()
            .environmentObject(appState)
            .environmentObject(appState.workbenchLayout)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: AppShellLayout.minimumWindowWidth, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.title = "CueSeeker"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = false
        window.minSize = NSSize(width: AppShellLayout.minimumWindowWidth, height: AppShellLayout.minimumWindowHeight)
        window.delegate = self
        window.center()
        window.contentView = NSHostingView(rootView: contentView)
        window.makeKeyAndOrderFront(nil)
        
        if let screen = window.screen {
            window.setFrame(screen.visibleFrame, display: true)
        }

        self.window = window
        adjustTrafficLights()
    }

    private func configurePlaybackKeyboardShortcuts() {
        keyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else {
                return event
            }

            let keyCode = event.keyCode
            let modifierFlags = event.modifierFlags
                .intersection(.deviceIndependentFlagsMask)
                .rawValue
            let handled = MainActor.assumeIsolated {
                self.appState.handlePlaybackKeyDown(
                    keyCode: keyCode,
                    modifierFlagsRawValue: modifierFlags
                )
            }

            return handled ? nil : event
        }
    }

    @objc private func showSettings(_ sender: Any?) {
        appState.clearSearchFocus()

        if let settingsWindow {
            settingsWindow.makeKeyAndOrderFront(sender)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let contentView = SettingsView()
            .environmentObject(appState)
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
        window?.titleVisibility = .visible
        windowButtonsProxy?.isHidden = true
    }

    func windowWillExitFullScreen(_ notification: Notification) {
        window?.titleVisibility = .hidden
    }

    func windowWillClose(_ notification: Notification) {
        appState.saveCurrentLibraryPlaybackHistorySynchronously()
        appState.playbackFullscreenManager.exitFullscreen()
    }

    func windowDidExitFullScreen(_ notification: Notification) {
        window?.titleVisibility = .hidden
        DispatchQueue.main.async { [weak self] in
            self?.adjustTrafficLights()
        }
    }
    
    func windowDidResize(_ notification: Notification) {
        AppPerformanceProbe.measure("AppDelegate.windowDidResize", thresholdMilliseconds: 8) {
            adjustTrafficLights()
        }
    }
    
    func windowDidUpdate(_ notification: Notification) {
        AppPerformanceProbe.measure("AppDelegate.windowDidUpdate", thresholdMilliseconds: 8) {
            adjustTrafficLights()
        }
    }
    
    private func adjustTrafficLights() {
        AppPerformanceProbe.measure("AppDelegate.adjustTrafficLights", thresholdMilliseconds: 8) {
            guard let window = self.window else { return }
        
            if window.styleMask.contains(.fullScreen) {
                windowButtonsProxy?.isHidden = true
                return
            }
        
            if windowButtonsProxy == nil, let themeFrame = window.contentView?.superview {
                // AppTopBar is 45pt tall, width 80 is enough for the 3 buttons
                let proxy = WindowButtonsProxyView(frame: NSRect(x: 24, y: 0, width: 80, height: 45))
                themeFrame.addSubview(proxy)
                windowButtonsProxy = proxy
            }
        
            guard let proxy = windowButtonsProxy else { return }
            proxy.isHidden = false
        
            if let themeFrame = proxy.superview {
                let proxyY = themeFrame.isFlipped ? 0 : themeFrame.frame.height - proxy.frame.height
                proxy.frame.origin = CGPoint(x: 24, y: proxyY)
            }
        
            let buttons: [NSWindow.ButtonType] = [.closeButton, .miniaturizeButton, .zoomButton]
            var xOffset: CGFloat = 0
            let targetCenterFromTop: CGFloat = 22.5
        
            for type in buttons {
                guard let button = window.standardWindowButton(type) else { continue }
            
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
