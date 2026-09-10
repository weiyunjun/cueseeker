import AppKit

/// The main window, which refuses to hand the keyboard to anything while a
/// menu owns input, or to anything outside the open dialog.
///
/// Cancelling the focus when a menu opens is not enough on its own: a field
/// that autofocuses when it appears, or any other code that asks for focus,
/// takes it straight back and starts swallowing keystrokes again underneath
/// the menu. The refusal lives here because `makeFirstResponder` is the one
/// door focus comes through, so no caller has to know a menu is open.
///
/// A covered menu owns nothing — the layer above it does — so the refusal
/// follows the registry's answer rather than the mere existence of a menu.
///
/// See `docs/human/requirements/20260826-UI-Menu Modality Input Barrier And
/// Focus Cancellation.md`.
final class CueSeekerMainWindow: NSWindow {
    /// Set by the App once the interface layer registry exists.
    var isFocusLocked: () -> Bool = { false }

    /// The size of the dialog that owns input, or nil while none is open. Set
    /// by the App. A dialog used to be a window of its own, where the keyboard
    /// could not leave it; drawn in this window, it is kept in here instead.
    /// See `docs/human/requirements/20260911-UI-In-Window Dialogs And Only
    /// Confirmation Blocks Closing.md`.
    var dialogSize: () -> CGSize? = { nil }

    /// The zoom button, the View menu and the shortcut all arrive here. On the
    /// playback page an entry is the page's, so it goes through the same gate
    /// as the player's own fullscreen button. Returns whether it did.
    var handlesFullscreenRequest: () -> Bool = { false }

    /// A window already in fullscreen leaves it the system's way, whoever put
    /// it there — the tiling menu included. The gate decides entries only.
    override func toggleFullScreen(_ sender: Any?) {
        guard styleMask.contains(.fullScreen) || !handlesFullscreenRequest() else {
            return
        }
        super.toggleFullScreen(sender)
    }

    /// A real pointer movement is the one event that asks the shape to be
    /// decided again; it is asked after dispatch, so every surface has
    /// answered the movement first.
    override func sendEvent(_ event: NSEvent) {
        super.sendEvent(event)
        switch event.type {
        case .mouseMoved, .leftMouseDragged, .rightMouseDragged:
            AppPointerShape.pointerMoved(in: self, at: event.locationInWindow)
        default:
            break
        }
    }

    override func makeFirstResponder(_ responder: NSResponder?) -> Bool {
        // Giving the focus up is always allowed; that is how the menu cancels
        // it in the first place.
        guard responder != nil else {
            return super.makeFirstResponder(responder)
        }
        guard !isFocusLocked(), !isBehindDialog(responder) else {
            return false
        }
        return super.makeFirstResponder(responder)
    }

    /// Tab and Shift-Tab go round the dialog's own fields, as they went round
    /// the dialog's window, passing over everything the veil covers.
    override func selectKeyView(following view: NSView) {
        guard dialogSize() != nil else {
            return super.selectKeyView(following: view)
        }
        selectDialogKeyView(from: view, step: \.nextValidKeyView)
    }

    override func selectKeyView(preceding view: NSView) {
        guard dialogSize() != nil else {
            return super.selectKeyView(preceding: view)
        }
        selectDialogKeyView(from: view, step: \.previousValidKeyView)
    }

    private func selectDialogKeyView(from view: NSView, step: (NSView) -> NSView?) {
        var visited: Set<ObjectIdentifier> = []
        var candidate = step(view)
        while let next = candidate, visited.insert(ObjectIdentifier(next)).inserted {
            if !isBehindDialog(next), isUncovered(next) {
                _ = makeFirstResponder(next)
                return
            }
            candidate = step(next)
        }
    }

    /// Whether `responder` is a view of this window that lies outside the open
    /// dialog. Every dialog is centred in the window.
    private func isBehindDialog(_ responder: NSResponder?) -> Bool {
        guard let size = dialogSize(),
              let view = responder as? NSView,
              view.window === self,
              let content = contentView
        else {
            return false
        }
        let dialog = CGRect(
            x: (content.bounds.width - size.width) / 2,
            y: (content.bounds.height - size.height) / 2,
            width: size.width,
            height: size.height
        )
        return !dialog.insetBy(dx: -1, dy: -1).contains(content.convert(view.bounds, from: view))
    }

    /// Whether nothing is drawn over the middle of `view`, so a field that lies
    /// within the dialog's frame but behind it is passed over too.
    private func isUncovered(_ view: NSView) -> Bool {
        guard let content = contentView, let frame = content.superview else {
            return true
        }
        let middle = view.convert(NSPoint(x: view.bounds.midX, y: view.bounds.midY), to: frame)
        guard let hit = content.hitTest(middle) else {
            return false
        }
        return hit === view
            || hit.isDescendant(of: view)
            || (hit !== content && view.isDescendant(of: hit))
    }
}
