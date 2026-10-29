import AppKit

/// Base window that hides `mouseLocationOutsideOfEventStream` while the window
/// is not the active key window so background layout passes inside
/// `NSHostingView` never synthesize hover on an unfocused window.
class CueSeekerWindow: NSWindow {
    var isWindowFocusedOverrideForTesting: Bool?
    /// Set by the App once the interface layer registry exists.
    var isFocusLocked: () -> Bool = { false }

    var isFocusedForHover: Bool {
        if let isWindowFocusedOverrideForTesting {
            return isWindowFocusedOverrideForTesting
        }
        return NSApp.isActive && isKeyWindow
    }

    override var mouseLocationOutsideOfEventStream: NSPoint {
        guard isFocusedForHover else {
            return NSPoint(x: -10_000, y: -10_000)
        }
        return super.mouseLocationOutsideOfEventStream
    }

    override func makeFirstResponder(_ responder: NSResponder?) -> Bool {
        guard responder != nil else {
            return super.makeFirstResponder(responder)
        }
        guard !isFocusLocked() else {
            return false
        }
        return super.makeFirstResponder(responder)
    }

    override func sendEvent(_ event: NSEvent) {
        if isFocusedForHover {
            switch event.type {
            case .scrollWheel:
                PointerHoverScrollState.shared.noteScrolled()
            case .mouseMoved, .leftMouseDragged, .rightMouseDragged:
                PointerHoverScrollState.shared.notePointerMoved()
            default:
                break
            }
        }
        switch event.type {
        case .leftMouseDown:
            cancelFocusedTextInputIfOutside(at: event.locationInWindow)
        case .rightMouseDown:
            if isPointInsideFocusedTextInput(at: event.locationInWindow) {
                return
            }
            cancelFocusedTextInputIfOutside(at: event.locationInWindow)
            if handleRightMouseDownOnUnfocusedTextInput(with: event) {
                return
            }
        default:
            break
        }
        super.sendEvent(event)
    }

    func cancelFocusedTextInputIfOutside(at windowPoint: NSPoint) {
        guard hasFocusedTextInput else {
            return
        }
        if !isPointInsideFocusedTextInput(at: windowPoint) {
            _ = makeFirstResponder(nil)
        }
    }

    private func handleRightMouseDownOnUnfocusedTextInput(with event: NSEvent) -> Bool {
        guard let root = contentView,
              let hit = root.superview?.hitTest(event.locationInWindow) ?? root.hitTest(root.convert(event.locationInWindow, from: nil))
        else {
            return false
        }
        if let overlay = hit as? WorkbenchSingleLineContainerOverlayView {
            overlay.rightMouseDown(with: event)
            return true
        }
        if let field = hit as? WorkbenchNativeSingleLineTextField {
            field.rightMouseDown(with: event)
            return true
        }
        if let secureField = hit as? WorkbenchNativeSecureTextField {
            secureField.rightMouseDown(with: event)
            return true
        }
        if let textAreaView = hit as? WorkbenchTextAreaNativeTextView {
            textAreaView.rightMouseDown(with: event)
            return true
        }
        return false
    }

    private var hasFocusedTextInput: Bool {
        guard let responder = firstResponder else {
            return false
        }
        if responder is WorkbenchTextAreaNativeTextView
            || responder is WorkbenchNativeSingleLineTextField
            || responder is WorkbenchNativeSecureTextField {
            return true
        }
        if let textView = responder as? NSTextView,
           textView.isFieldEditor {
            return true
        }
        return false
    }

    private func isPointInsideFocusedTextInput(at windowPoint: NSPoint) -> Bool {
        guard let responder = firstResponder else {
            return false
        }
        if let root = contentView,
           Self.containsPointInCompanionView(windowPoint, in: root) {
            return true
        }
        if let textAreaView = responder as? WorkbenchTextAreaNativeTextView {
            if let container = sequence(first: textAreaView as NSView, next: \.superview)
                .compactMap({ $0 as? WorkbenchTextAreaContainerView })
                .first {
                return container.containsWindowPoint(windowPoint)
            }
            let localPoint = textAreaView.convert(windowPoint, from: nil)
            return textAreaView.bounds.contains(localPoint)
        }
        let activeField: NSTextField? = {
            if let field = responder as? NSTextField {
                return field
            }
            if let textView = responder as? NSTextView {
                if let delegateField = textView.delegate as? NSTextField {
                    return delegateField
                }
                return sequence(first: textView as NSView, next: \.superview)
                    .compactMap({ $0 as? NSTextField })
                    .first
            }
            return nil
        }()
        guard let activeField else {
            return false
        }
        if let root = contentView,
           let overlay = Self.findOverlay(enclosing: activeField, in: root) {
            return overlay.containsWindowPoint(windowPoint)
        }
        let localPoint = activeField.convert(windowPoint, from: nil)
        return activeField.bounds.contains(localPoint)
    }

    private static func findOverlay(
        enclosing field: NSTextField,
        in view: NSView
    ) -> WorkbenchSingleLineContainerOverlayView? {
        if let overlay = view as? WorkbenchSingleLineContainerOverlayView,
           !overlay.isHiddenOrHasHiddenAncestor,
           overlay.enclosesField(field) {
            return overlay
        }
        for subview in view.subviews {
            if let found = findOverlay(enclosing: field, in: subview) {
                return found
            }
        }
        return nil
    }

    private static func containsPointInCompanionView(
        _ windowPoint: NSPoint,
        in view: NSView
    ) -> Bool {
        if let companion = view as? FocusedTextInputCompanionView,
           companion.containsWindowPoint(windowPoint) {
            return true
        }
        for subview in view.subviews {
            if containsPointInCompanionView(windowPoint, in: subview) {
                return true
            }
        }
        return false
    }
}

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
final class CueSeekerMainWindow: CueSeekerWindow {
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

    /// Whether a higher layer (such as the playback page or a dialog) covers
    /// the workbench page. When false, the workbench page is the base active
    /// layer and its views are never blocked by layer coverage.
    var isWorkbenchCovered: () -> Bool = { false }

    override func makeFirstResponder(_ responder: NSResponder?) -> Bool {
        // Giving the focus up is always allowed; that is how the menu cancels
        // it in the first place.
        guard responder != nil else {
            return super.makeFirstResponder(responder)
        }
        guard !isFocusLocked(), !isBehindDialog(responder) else {
            return false
        }
        if isWorkbenchCovered(), let view = focusTargetView(for: responder) {
            guard isUncovered(view) else {
                return false
            }
        }
        return super.makeFirstResponder(responder)
    }

    /// Tab and Shift-Tab cycle only among visible, uncovered fields in this
    /// window, passing over everything that a higher layer (like a dialog or
    /// the playback page) covers.
    override func selectKeyView(following view: NSView) {
        guard dialogSize() != nil || isWorkbenchCovered() else {
            return super.selectKeyView(following: view)
        }
        selectUncoveredKeyView(from: view, step: \.nextValidKeyView)
    }

    override func selectKeyView(preceding view: NSView) {
        guard dialogSize() != nil || isWorkbenchCovered() else {
            return super.selectKeyView(preceding: view)
        }
        selectUncoveredKeyView(from: view, step: \.previousValidKeyView)
    }

    private func selectUncoveredKeyView(from view: NSView, step: (NSView) -> NSView?) {
        var visited: Set<ObjectIdentifier> = []
        let start = focusTargetView(for: view) ?? view
        var candidate = step(start)
        while let next = candidate, visited.insert(ObjectIdentifier(next)).inserted {
            if !isBehindDialog(next), isUncovered(next) {
                _ = makeFirstResponder(next)
                return
            }
            candidate = step(next)
        }
    }

    /// The control a field editor or scrollable text view edits on behalf of.
    /// A single-line field editor grows its own bounds to the width of the
    /// text pasted into it, while the control hosting it keeps the field's
    /// frame inside the dialog.
    private func focusTargetView(for responder: NSResponder?) -> NSView? {
        guard let view = responder as? NSView else {
            return nil
        }
        if let textView = view as? NSTextView {
            if let control = sequence(first: textView as NSView, next: \.superview)
                .first(where: { $0 is NSControl }) {
                return control
            }
            if let delegateView = textView.delegate as? NSView {
                return delegateView
            }
            if let scrollView = textView.enclosingScrollView {
                return scrollView
            }
            if let clipView = textView.superview {
                return clipView
            }
        }
        return view
    }

    /// Whether `responder` is a view of this window that lies outside the open
    /// dialog. Every dialog is centred in the window.
    func isBehindDialog(_ responder: NSResponder?) -> Bool {
        guard let size = dialogSize(),
              let view = focusTargetView(for: responder),
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
        let allowedBounds = dialog.insetBy(
            dx: -2,
            dy: -(WorkbenchDialogMotion.distance + 2)
        )
        return !allowedBounds.contains(content.convert(view.bounds, from: view))
    }

    /// Whether nothing is drawn over the middle of `view`, so a field that lies
    /// within a covered layer or behind a dialog is passed over too.
    func isUncovered(_ view: NSView) -> Bool {
        let target = focusTargetView(for: view) ?? view
        guard target.window === self else {
            return false
        }
        guard !target.isHiddenOrHasHiddenAncestor else {
            return false
        }
        if let field = target as? WorkbenchNativeSingleLineTextField,
           field.interfaceLayer == .dialog,
           !isBehindDialog(target) {
            return true
        }
        guard let content = contentView, let frame = content.superview else {
            return true
        }
        let middle = target.convert(NSPoint(x: target.bounds.midX, y: target.bounds.midY), to: frame)
        guard let hit = content.hitTest(middle) else {
            return false
        }
        return hit === target
            || hit.isDescendant(of: target)
            || (hit !== content && target.isDescendant(of: hit))
    }
}
