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
        
        let buttons: [NSWindow.ButtonType] = [.closeButton, .miniaturizeButton, .zoomButton]
        
        for type in buttons {
            guard let button = window.standardWindowButton(type),
                  let superview = button.superview else { continue }
            
            // Prevent clipping if the buttons are shifted outside their standard view bounds
            superview.clipsToBounds = false
            superview.superview?.clipsToBounds = false
            
            // AppTopBar is 45pt. We want the traffic lights centered vertically.
            // Center of top bar is 22.5pt from the top.
            let targetCenterFromTop: CGFloat = 22.5
            let isFlipped = superview.isFlipped
            
            let targetY: CGFloat
            if isFlipped {
                targetY = targetCenterFromTop - (button.frame.height / 2)
            } else {
                targetY = superview.frame.height - targetCenterFromTop - (button.frame.height / 2)
            }
            
            if abs(button.frame.origin.y - targetY) > 0.1 {
                button.frame.origin.y = targetY
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
