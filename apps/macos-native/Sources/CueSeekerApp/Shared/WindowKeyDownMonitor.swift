import AppKit
import SwiftUI

/// Key-downs for the window this view is in. It lives and dies with the view,
/// so nothing else has to remember to switch it off.
///
/// The handler only sees keys pressed in its own window: a key pressed while
/// the Settings window — or any other window — is the key window belongs to
/// that window and is passed straight through. The handler returns whether it
/// spent the key, in which case nothing below sees it.
struct WindowKeyDownMonitor: NSViewRepresentable {
    let handle: (NSEvent) -> Bool

    func makeNSView(context _: Context) -> MonitoringView {
        MonitoringView()
    }

    func updateNSView(_ nsView: MonitoringView, context _: Context) {
        nsView.update(handle: handle)
    }

    static func dismantleNSView(_ nsView: MonitoringView, coordinator _: Void) {
        nsView.tearDown()
    }

    @MainActor
    final class MonitoringView: NSView {
        nonisolated(unsafe) private var eventMonitor: Any?
        private var handle: ((NSEvent) -> Bool)?

        func update(handle: @escaping (NSEvent) -> Bool) {
            self.handle = handle
            installEventMonitorIfNeeded()
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if window == nil {
                removeEventMonitor()
            } else {
                installEventMonitorIfNeeded()
            }
        }

        func tearDown() {
            handle = nil
            removeEventMonitor()
        }

        deinit {
            if let eventMonitor {
                NSEvent.removeMonitor(eventMonitor)
            }
        }

        private func installEventMonitorIfNeeded() {
            guard window != nil, eventMonitor == nil else {
                return
            }
            eventMonitor = NSEvent.addLocalMonitorForEvents(
                matching: .keyDown
            ) { [weak self] event in
                let handled = MainActor.assumeIsolated {
                    guard let self, event.window === self.window else {
                        return false
                    }
                    return self.handle?(event) ?? false
                }
                return handled ? nil : event
            }
        }

        private func removeEventMonitor() {
            guard let eventMonitor else {
                return
            }
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }
    }
}
