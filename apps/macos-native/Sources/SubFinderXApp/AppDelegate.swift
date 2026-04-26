import AppKit
import SwiftUI
import SubFinderXCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?
    private var titlebarControls: TitlebarControlsCoordinator?
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
        window.center()
        window.contentView = NSHostingView(rootView: contentView)
        window.makeKeyAndOrderFront(nil)

        titlebarControls = TitlebarControlsCoordinator(
            window: window,
            appState: appState
        )

        self.window = window
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
