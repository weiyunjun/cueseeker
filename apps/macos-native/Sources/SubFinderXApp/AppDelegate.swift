import AppKit
import SwiftUI
import SubFinderXCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var window: NSWindow?
    private let appState = AppState()

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
            contentRect: NSRect(x: 0, y: 0, width: 1080, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.title = ApplicationInfo.name
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.minSize = NSSize(width: 860, height: 560)
        window.delegate = self
        window.center()
        window.contentView = NSHostingView(rootView: contentView)
        window.makeKeyAndOrderFront(nil)

        self.window = window
    }

    func windowWillEnterFullScreen(_ notification: Notification) {
        // Removed titleVisibility modifications to prevent full-screen layout bugs
    }

    func windowDidExitFullScreen(_ notification: Notification) {
        // Removed titleVisibility modifications to prevent full-screen layout bugs
        // Re-adjust traffic lights after exiting full screen
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
        
        // System handles traffic lights natively in full screen; do not interfere.
        if window.styleMask.contains(.fullScreen) { return }
        
        // AppTopBar is 45pt tall. Buttons are ~16pt tall. 
        // To center them vertically: (45 - 16) / 2 ≈ 14.5
        let targetY: CGFloat = 14.0
        
        if let close = window.standardWindowButton(.closeButton),
           let min = window.standardWindowButton(.miniaturizeButton),
           let zoom = window.standardWindowButton(.zoomButton) {
            
            for btn in [close, min, zoom] {
                if btn.frame.origin.y != targetY {
                    btn.frame.origin.y = targetY
                }
            }
        }
    }

    private func configureMainMenu() {
        let mainMenu = NSMenu()
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
        NSApp.mainMenu = mainMenu
    }
}
