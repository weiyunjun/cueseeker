import AppKit
import SwiftUI

/// What an open menu does with a mouse press that did not land on it.
///
/// One answer for every menu in the App, so a press means the same thing
/// wherever it lands. A press that belongs to another window is none of the
/// menu's business. Within the menu's own window the left button is spent
/// closing the menu, and the right button closes it and travels on, so whatever
/// it lands on can open its own menu in the same press — the way macOS hands a
/// right-click from one menu straight to the next.
///
/// An event with no window of its own — the system menu bar is the one that
/// matters here — is treated as the menu's own surface, because the reader is
/// still working inside this app.
enum MenuOutsidePress {
    enum Decision {
        /// Another window owns the press. The menu neither closes nor takes it.
        case leaveToOtherWindow
        /// The press is on the menu itself.
        case leaveToMenu
        /// Close the menu; the press is spent doing it.
        case dismissAndConsume
        /// Close the menu and let the press go on.
        case dismissAndForward
    }

    static func isFromAnotherWindow(
        _ event: NSEvent,
        menuWindow: NSWindow?
    ) -> Bool {
        guard let eventWindow = event.window else {
            return false
        }
        return eventWindow !== menuWindow
    }

    static func decide(
        _ event: NSEvent,
        menuWindow: NSWindow?,
        isPointerOnMenu: () -> Bool
    ) -> Decision {
        if let eventWindow = event.window {
            guard eventWindow === menuWindow else {
                return .leaveToOtherWindow
            }
            if isPointerOnMenu() {
                return .leaveToMenu
            }
        }
        return event.type == .rightMouseDown
            ? .dismissAndForward
            : .dismissAndConsume
    }
}

/// Reports the window a SwiftUI surface is hosted in.
///
/// A menu drawn by SwiftUI has no view of its own to ask, but its dismissal
/// monitor has to tell its own window from another one. Menus built on AppKit
/// views already know this from `NSView.window`.
struct MenuHostWindowReader: NSViewRepresentable {
    @Binding var window: NSWindow?

    func makeNSView(context _: Context) -> ReaderView {
        let view = ReaderView()
        view.onWindowChange = { window = $0 }
        return view
    }

    func updateNSView(_ nsView: ReaderView, context _: Context) {
        nsView.onWindowChange = { window = $0 }
    }

    final class ReaderView: NSView {
        var onWindowChange: ((NSWindow?) -> Void)?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            let window = window
            DispatchQueue.main.async { [weak self] in
                self?.onWindowChange?(window)
            }
        }

        override func hitTest(_ point: NSPoint) -> NSView? {
            nil
        }
    }
}
