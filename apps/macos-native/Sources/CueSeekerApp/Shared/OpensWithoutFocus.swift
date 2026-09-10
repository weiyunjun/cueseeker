import AppKit
import SwiftUI

extension View {
    /// The window this view is in never hands the keyboard to a control on its
    /// own. See `docs/human/requirements/20260911-UI-Keyboard Focus Ignores
    /// System Setting And Has No Default Focus.md`.
    func opensWithoutFocus() -> some View {
        background(OpensWithoutFocusProbe())
    }
}

/// AppKit puts the caret in a window's first text field whenever the window
/// becomes key with nothing focused: when it first appears, and again each time
/// it comes back from another window or App. Interfaces open without focus, so
/// that pick is taken back in the same turn, before the window draws. Focus the
/// window still had when it last stopped being key is the user's, and stays.
private struct OpensWithoutFocusProbe: NSViewRepresentable {
    func makeNSView(context _: Context) -> ProbeView {
        ProbeView()
    }

    func updateNSView(_: ProbeView, context _: Context) {}

    final class ProbeView: NSView {
        private var hadFocusWhenResigned = false

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            NotificationCenter.default.removeObserver(self)
            guard let window else {
                return
            }
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(windowDidResignKey),
                name: NSWindow.didResignKeyNotification,
                object: window
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(windowDidBecomeKey),
                name: NSWindow.didBecomeKeyNotification,
                object: window
            )
        }

        @objc private func windowDidResignKey() {
            guard let window else {
                return
            }
            hadFocusWhenResigned = window.firstResponder !== window
        }

        @objc private func windowDidBecomeKey() {
            guard let window, !hadFocusWhenResigned else {
                return
            }
            window.makeFirstResponder(nil)
        }
    }
}
