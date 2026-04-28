import AppKit
import SwiftUI
import Combine
import SubFinderXCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var window: NSWindow?
    private let appState = AppState()
    private var cancellables = Set<AnyCancellable>()
    private var windowButtonsProxy: WindowButtonsProxyView?

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureMainMenu()
        createMainWindow()
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    private func createMainWindow() {
        let contentView = ContentView()
            .environmentObject(appState)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1180, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.title = appState.selectedSection.title
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = false
        window.minSize = NSSize(width: 1040, height: 560)
        window.delegate = self
        window.center()
        window.contentView = NSHostingView(rootView: contentView)
        window.makeKeyAndOrderFront(nil)
        
        if let screen = window.screen {
            window.setFrame(screen.visibleFrame, display: true)
        }

        self.window = window
        
        appState.$selectedSection
            .sink { [weak self] section in
                self?.window?.title = section.title
                
                // Force AppKit to perform the pending titlebar layout synchronously,
                // then immediately re-apply our custom traffic light offsets.
                // This prevents the buttons from jumping to their default positions
                // for a single frame before windowDidUpdate catches them.
                if let themeFrame = self?.window?.contentView?.superview {
                    themeFrame.layoutSubtreeIfNeeded()
                }
                self?.adjustTrafficLights()
            }
            .store(in: &cancellables)
    }

    func windowWillEnterFullScreen(_ notification: Notification) {
        window?.titleVisibility = .visible
        windowButtonsProxy?.isHidden = true
    }

    func windowWillExitFullScreen(_ notification: Notification) {
        window?.titleVisibility = .hidden
    }

    func windowDidExitFullScreen(_ notification: Notification) {
        window?.titleVisibility = .hidden
        DispatchQueue.main.async { [weak self] in
            self?.adjustTrafficLights()
        }
    }
    
    func windowDidResize(_ notification: Notification) {
        adjustTrafficLights()
    }
    
    func windowDidUpdate(_ notification: Notification) {
        adjustTrafficLights()
    }
    
    private func adjustTrafficLights() {
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

    private func configureMainMenu() {
        let mainMenu = NSMenu()

        // App Menu
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
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
        editMenu.addItem(NSMenuItem(title: "Cut", action: Selector(("cut:")), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: "Copy", action: Selector(("copy:")), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "Paste", action: Selector(("paste:")), keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem(title: "Delete", action: Selector(("delete:")), keyEquivalent: "\u{8}")) // Backspace
        editMenu.addItem(NSMenuItem(title: "Select All", action: Selector(("selectAll:")), keyEquivalent: "a"))
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
