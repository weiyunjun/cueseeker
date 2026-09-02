import AppKit

/// The main window, which refuses to hand the keyboard to anything while a
/// menu owns input.
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
        guard responder != nil, isFocusLocked() else {
            return super.makeFirstResponder(responder)
        }
        return false
    }
}
