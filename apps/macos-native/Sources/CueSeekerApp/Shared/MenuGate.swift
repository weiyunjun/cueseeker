import AppKit
import SwiftUI

/// The one implementation of menu event handling.
///
/// Every open menu registers here as a client, and the gate owns the whole of
/// what an open menu does to the App: the event monitor, arrow keys, Enter and
/// Esc, the outside press (through `MenuOutsidePress`), the wheel, and the
/// barrier that keeps everything else from reaching the interface underneath
/// (through `MenuInputBarrier`). A menu covered by a higher layer — the
/// registry answers — stays on screen and takes no input. Clients only describe
/// their menu: which layer owns it, which menu it is, where it is, what its
/// keys do, and how it dismisses.
///
/// Clients are processed in the order their menus opened, each seeing the
/// event only if the ones before it passed it on — the same contract the
/// separate `NSEvent` monitors had, collapsed into one implementation.
@MainActor
final class MenuGate {
    /// The menus the design names, and the only things it lets them differ in:
    /// the scroll table in `docs/human/design/UI Application Rules.md` 菜单模态
    /// 6, and where the menu's keys come from. A caller states which menu it is
    /// opening and nothing else, so a menu added later cannot quietly invent a
    /// modality of its own.
    enum Kind {
        case tableRowMenu
        case filterMenu
        case cardMenu
        case selectedTextMenu
        case playerSpeedMenu

        /// 菜单模态 6: the speed menu is the one menu the scroll table leaves
        /// free.
        var bansScrolling: Bool {
            self != .playerSpeedMenu
        }

        /// Whether the menu surface spends the wheel itself. When it does not,
        /// the gate spends a wheel over the menu so nothing moves underneath
        /// it.
        var takesWheel: Bool {
            switch self {
            case .tableRowMenu, .filterMenu, .selectedTextMenu:
                true
            case .cardMenu, .playerSpeedMenu:
                false
            }
        }

        /// Whether the gate's own monitor feeds this menu keys. The speed menu
        /// receives keys only from the playback key owner instead: monitors run
        /// in install order, and the app-wide playback monitor installed at
        /// launch sees keys first.
        var receivesKeysFromMonitor: Bool {
            self != .playerSpeedMenu
        }

        /// Whether the playback key owner offers this menu keys through
        /// `routeKey` before seeking, volume, cue navigation and Command Panel
        /// navigation see them.
        var receivesKeysFromRouter: Bool {
            self != .tableRowMenu
        }

        /// 选中文字菜单 hangs off the very selection it would clear, so it is
        /// the one menu that keeps the selection and clears it on the way out
        /// instead.
        var clearsTextSelection: Bool {
            self != .selectedTextMenu
        }
    }

    struct Client {
        let owner: InterfaceLayer
        let kind: Kind
        /// The window the menu lives in. While unknown, a press counts as
        /// this window's, so a menu can never become impossible to close.
        var window: () -> NSWindow?
        let isPointerOnMenu: (NSEvent) -> Bool
        /// A press here is left to the control that toggles the menu (the
        /// speed button), so the toggle does not run twice.
        var isPointerOnAnchorControl: ((NSEvent) -> Bool)?
        /// Where the pointer is, on every move in this window. The barrier
        /// spends the moves that land outside the menu, and AppKit only works
        /// out that a pointer left a tracking area while it is delivering
        /// them — so a menu that waits to be told it was left is never told.
        /// The gate already has the answer for its own decision; this hands
        /// it over.
        var notePointer: ((NSEvent) -> Void)?
        /// Returns whether the key was spent on the menu.
        let handleKey: (_ keyCode: UInt16, _ isRepeat: Bool) -> Bool
        /// forwarding: the press closed the menu and travels on, so whatever
        /// it lands on can open its own menu in the same press.
        let dismiss: (_ forwarding: Bool) -> Void
    }

    /// Held by a menu owner while its menu is open. Releasing it — on
    /// dismissal, or by the owner being torn down with the menu open —
    /// removes the client and its registry entry, so no teardown path can
    /// leave a menu registered.
    final class Session {
        nonisolated(unsafe) private weak var gate: MenuGate?
        private let id: UUID
        // Held so the menu stays registered exactly as long as the session.
        private let registration: InterfaceLayerRegistry.OpenMenuToken?

        fileprivate init(
            gate: MenuGate,
            id: UUID,
            registration: InterfaceLayerRegistry.OpenMenuToken?
        ) {
            self.gate = gate
            self.id = id
            self.registration = registration
        }

        @MainActor
        func close() {
            gate?.close(id: id)
        }

        deinit {
            // Menu owners live on the main actor, so the session is released
            // there too.
            let gate = gate
            let id = id
            MainActor.assumeIsolated {
                gate?.close(id: id)
            }
        }
    }

    private unowned let interfaceLayers: InterfaceLayerRegistry
    private var clients: [(id: UUID, client: Client)] = []
    nonisolated(unsafe) private var eventMonitor: Any?
    /// The window the barrier was applied to, so exactly what was switched off
    /// when the first menu opened is switched back on when the last one closes.
    private var barrierWindow: NSWindow?
    /// Whether a press landed on a menu and has not been released yet. The
    /// drag it started belongs to the menu wherever the pointer travels.
    private var isTrackingMenuDrag = false

    init(interfaceLayers: InterfaceLayerRegistry) {
        self.interfaceLayers = interfaceLayers
    }

    func open(_ client: Client) -> Session {
        let id = UUID()
        let isFirstMenu = clients.isEmpty
        clients.append((id: id, client: client))
        installMonitorIfNeeded()
        let session = Session(
            gate: self,
            id: id,
            registration: interfaceLayers.registerOpenMenu(
                ownedBy: client.owner
            )
        )
        if isFirstMenu {
            applyBarrier(to: client.window() ?? NSApp.keyWindow)
        }
        if client.kind.clearsTextSelection {
            NotificationCenter.default.post(
                name: .cueSeekerClearTextSelection,
                object: nil
            )
        }
        return session
    }

    private func close(id: UUID) {
        clients.removeAll { $0.id == id }
        if clients.isEmpty {
            removeMonitor()
            releaseBarrier()
            isTrackingMenuDrag = false
        }
    }

    /// Everything an open menu switches off in its window, applied once and
    /// undone once.
    ///
    /// The cursor is the App's, not each surface's: cursor rects are switched
    /// off so no view under the menu can state a shape, and the pointer gives
    /// up whatever shape it was already wearing. The keyboard is nobody's: the
    /// focus is cancelled, and `CueSeekerMainWindow` refuses to hand it back
    /// while a menu is open, so a field cannot take it again on its own.
    private func applyBarrier(to window: NSWindow?) {
        guard let window else {
            return
        }
        barrierWindow = window
        window.disableCursorRects()
        NSCursor.arrow.set()
        window.makeFirstResponder(nil)
    }

    private func releaseBarrier() {
        guard let barrierWindow else {
            return
        }
        barrierWindow.enableCursorRects()
        barrierWindow.resetCursorRects()
        self.barrierWindow = nil
    }

    /// Keys the playback key owner offers the open menus before seeking,
    /// volume, cue navigation and Command Panel navigation see them. Returns
    /// whether a menu spent the key.
    func routeKey(_ keyCode: UInt16, isRepeat: Bool) -> Bool {
        for (_, client) in clients {
            guard client.kind.receivesKeysFromRouter,
                  !interfaceLayers.isMenuCovered(ownedBy: client.owner)
            else {
                continue
            }
            if client.handleKey(keyCode, isRepeat) {
                return true
            }
        }
        return false
    }

    private func installMonitorIfNeeded() {
        guard eventMonitor == nil else {
            return
        }
        eventMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [
                .keyDown,
                .leftMouseDown, .rightMouseDown, .otherMouseDown,
                .leftMouseUp, .rightMouseUp, .otherMouseUp,
                .leftMouseDragged, .rightMouseDragged, .otherMouseDragged,
                .mouseMoved, .mouseEntered, .mouseExited, .cursorUpdate,
                .scrollWheel,
            ]
        ) { [weak self] event in
            var routed: NSEvent? = event
            MainActor.assumeIsolated {
                routed = self?.route(event)
            }
            return routed
        }
    }

    private func removeMonitor() {
        guard let eventMonitor else {
            return
        }
        NSEvent.removeMonitor(eventMonitor)
        self.eventMonitor = nil
    }

    private func route(_ event: NSEvent) -> NSEvent? {
        noteDragTrackingBeforeRouting(event)
        var routed: NSEvent? = event
        for (_, client) in clients {
            guard let current = routed else {
                break
            }
            routed = route(current, to: client)
        }
        noteDragTrackingAfterRouting(event)
        return routed
    }

    private func noteDragTrackingBeforeRouting(_ event: NSEvent) {
        switch event.type {
        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            isTrackingMenuDrag = clients.contains { entry in
                !interfaceLayers.isMenuCovered(ownedBy: entry.client.owner)
                    && entry.client.isPointerOnMenu(event)
            }
        default:
            break
        }
    }

    private func noteDragTrackingAfterRouting(_ event: NSEvent) {
        switch event.type {
        case .leftMouseUp, .rightMouseUp, .otherMouseUp:
            isTrackingMenuDrag = false
        default:
            break
        }
    }

    private func route(_ event: NSEvent, to client: Client) -> NSEvent? {
        // A covered menu stays on screen and takes no input; the layer above
        // it owns the event.
        guard !interfaceLayers.isMenuCovered(ownedBy: client.owner) else {
            return event
        }

        let menuWindow = client.window() ?? event.window
        let isFromAnotherWindow = MenuOutsidePress.isFromAnotherWindow(
            event,
            menuWindow: menuWindow
        )

        switch event.type {
        case .keyDown:
            if client.kind.receivesKeysFromMonitor,
               !isFromAnotherWindow,
               client.handleKey(event.keyCode, event.isARepeat) {
                return nil
            }
            return MenuInputBarrier.passesKey(
                isFromAnotherWindow: isFromAnotherWindow,
                isShortcut: event.modifierFlags
                    .intersection(.deviceIndependentFlagsMask)
                    .contains(.command)
            ) ? event : nil

        case .scrollWheel:
            guard !isFromAnotherWindow else {
                return event
            }
            if client.isPointerOnMenu(event) {
                // The menu is the one surface that may still scroll; a menu
                // that cannot scroll spends the wheel so nothing moves
                // underneath it.
                return client.kind.takesWheel ? event : nil
            }
            return client.kind.bansScrolling ? nil : event

        case .leftMouseDown, .rightMouseDown:
            switch MenuOutsidePress.decide(
                event,
                menuWindow: menuWindow,
                isPointerOnMenu: { client.isPointerOnMenu(event) }
            ) {
            case .leaveToOtherWindow, .leaveToMenu:
                return event
            case .dismissAndForward:
                client.dismiss(true)
                return event
            case .dismissAndConsume:
                if client.isPointerOnAnchorControl?(event) == true {
                    return event
                }
                client.dismiss(false)
                return nil
            }

        case .otherMouseDown, .leftMouseUp, .rightMouseUp, .otherMouseUp:
            // The middle press never closes a menu, and a release belongs to
            // the press it completes. Outside the menu both are spent.
            return MenuInputBarrier.passesNonDismissingButton(
                isFromAnotherWindow: isFromAnotherWindow,
                isPointerOnMenu: client.isPointerOnMenu(event),
                isPointerOnAnchorControl:
                    client.isPointerOnAnchorControl?(event) == true,
                isTrackingMenuDrag: isTrackingMenuDrag
            ) ? event : nil

        default:
            // Pointer motion, tracking area crossings, cursor updates and
            // drags.
            let isPointerOnMenu = client.isPointerOnMenu(event)
            if !isFromAnotherWindow {
                // Another window's event carries that window's coordinates,
                // which say nothing about where this menu is.
                client.notePointer?(event)
            }
            let passes = MenuInputBarrier.passesPointerTracking(
                isTrackingAreaCrossing: event.type == .mouseEntered
                    || event.type == .mouseExited,
                isFromAnotherWindow: isFromAnotherWindow,
                isPointerOnMenu: isPointerOnMenu,
                isTrackingMenuDrag: isTrackingMenuDrag
            )
            return passes ? event : nil
        }
    }
}

/// Registers one open menu with the gate for a SwiftUI-hosted menu, keeping
/// the client's geometry and closures fresh across renders the way the old
/// monitor views kept theirs. Mount it exactly while the menu is open.
///
/// `menuFrame` and `anchorFrame` are in this view's own top-left-down
/// coordinate space, so place it over the same area the frames are measured
/// in. The hosting window and the pointer hit tests are supplied by this
/// view.
struct MenuGateClientView: NSViewRepresentable {
    let gate: MenuGate?
    let owner: InterfaceLayer
    let kind: MenuGate.Kind
    let menuFrame: CGRect
    var anchorFrame: CGRect?
    var handleKey: (_ keyCode: UInt16, _ isRepeat: Bool) -> Bool = { _, _ in
        false
    }
    let dismiss: (_ forwarding: Bool) -> Void

    func makeNSView(context _: Context) -> ClientView {
        ClientView()
    }

    func updateNSView(_ nsView: ClientView, context _: Context) {
        nsView.update(gate: gate, representable: self)
    }

    static func dismantleNSView(_ nsView: ClientView, coordinator _: ()) {
        nsView.closeSession()
    }

    final class ClientView: NSView {
        private var session: MenuGate.Session?
        private(set) var menuFrame = CGRect.zero
        private var anchorFrame: CGRect?
        private var handleKey: (UInt16, Bool) -> Bool = { _, _ in false }
        private var dismiss: (Bool) -> Void = { _ in }

        override var isFlipped: Bool {
            true
        }

        override func hitTest(_ point: NSPoint) -> NSView? {
            nil
        }

        fileprivate func update(
            gate: MenuGate?,
            representable: MenuGateClientView
        ) {
            menuFrame = representable.menuFrame
            anchorFrame = representable.anchorFrame
            handleKey = representable.handleKey
            dismiss = representable.dismiss
            guard session == nil else {
                return
            }
            session = gate?.open(
                MenuGate.Client(
                    owner: representable.owner,
                    kind: representable.kind,
                    window: { [weak self] in self?.window },
                    isPointerOnMenu: { [weak self] event in
                        guard let self else {
                            return false
                        }
                        return self.menuFrame.contains(
                            self.convert(event.locationInWindow, from: nil)
                        )
                    },
                    isPointerOnAnchorControl: { [weak self] event in
                        guard let self, let anchorFrame = self.anchorFrame
                        else {
                            return false
                        }
                        return anchorFrame.contains(
                            self.convert(event.locationInWindow, from: nil)
                        )
                    },
                    handleKey: { [weak self] keyCode, isRepeat in
                        self?.handleKey(keyCode, isRepeat) ?? false
                    },
                    dismiss: { [weak self] forwarding in
                        self?.dismiss(forwarding)
                    }
                )
            )
        }

        func closeSession() {
            session?.close()
            session = nil
        }
    }
}
