import AppKit
import SwiftUI
import Combine
import SubFinderXCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var window: NSWindow?
    private let appState = AppState()
    private var cancellables = Set<AnyCancellable>()

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

        window.title = appState.selectedSection.title
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.minSize = NSSize(width: 860, height: 560)
        window.delegate = self
        window.center()
        window.contentView = NSHostingView(rootView: contentView)
        window.makeKeyAndOrderFront(nil)

        self.window = window
        
        appState.$selectedSection
            .sink { [weak self] section in
                self?.window?.title = section.title
            }
            .store(in: &cancellables)
    }

    func windowWillEnterFullScreen(_ notification: Notification) {
        window?.titleVisibility = .visible
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
        
        if window.styleMask.contains(.fullScreen) { return }
        
        if let close = window.standardWindowButton(.closeButton),
           let titlebarView = close.superview,
           let titlebarContainer = titlebarView.superview {
            
            // AppTopBar is 45pt. NSTitlebarContainerView is 28pt.
            // Center of container is 14pt from top. Center of top bar is 22.5pt.
            // We need to shift the container down by ~8.5pt (we use 9.0) to align them.
            let offset: CGFloat = 9.0
            let isFlipped = titlebarContainer.superview?.isFlipped ?? false
            
            let targetY: CGFloat
            if isFlipped {
                targetY = offset
            } else {
                let naturalY = window.frame.height - titlebarContainer.frame.height
                targetY = naturalY - offset
            }
            
            if titlebarContainer.frame.origin.y != targetY {
                titlebarContainer.frame.origin.y = targetY
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
