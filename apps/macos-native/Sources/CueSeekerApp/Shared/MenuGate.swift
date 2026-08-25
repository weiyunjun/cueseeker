import AppKit
import SwiftUI

/// The one implementation of menu event handling.
///
/// Every open menu registers here as a client, and the gate owns what used to
/// be five separate event monitors: installing and removing the monitor,
/// arrow keys, Enter and Esc, the outside press (through `MenuOutsidePress`),
/// and the wheel (through the design's per-menu scroll table). A menu covered
/// by a higher layer — the registry answers — stays on screen and takes no
/// input. Clients only describe their menu: which layer owns it, where it is,
/// what its keys do, and how it dismisses.
///
/// Clients are processed in the order their menus opened, each seeing the
/// event only if the ones before it passed it on — the same contract the
/// separate `NSEvent` monitors had, collapsed into one implementation.
@MainActor
final class MenuGate {
    struct Client {
        let owner: InterfaceLayer
        /// The window the menu lives in. While unknown, a press counts as
        /// this window's, so a menu can never become impossible to close.
        var window: () -> NSWindow?
        let isPointerOnMenu: (NSEvent) -> Bool
        /// A press here is left to the control that toggles the menu (the
        /// speed button), so the toggle does not run twice.
        var isPointerOnAnchorControl: ((NSEvent) -> Bool)?
        /// From the design's menu scroll table: whether the whole window is
        /// banned from scrolling while this menu is open.
        let bansScrolling: Bool
        /// Whether the menu surface consumes the wheel itself. When it does
        /// not, the gate spends a wheel over the menu so nothing moves
        /// underneath it.
        let menuTakesWheel: Bool
        /// Whether the gate's own monitor feeds this menu keys. The speed
        /// menu receives keys only from the playback key owner instead:
        /// monitors run in install order, and the app-wide playback monitor
        /// installed at launch sees keys first.
        var receivesKeysFromMonitor = true
        /// Whether the playback key owner offers this menu keys through
        /// `routeKey` before seeking, volume and cue navigation see them.
        var receivesKeysFromRouter = false
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

    init(interfaceLayers: InterfaceLayerRegistry) {
        self.interfaceLayers = interfaceLayers
    }

    func open(_ client: Client) -> Session {
        let id = UUID()
        clients.append((id: id, client: client))
        installMonitorIfNeeded()
        return Session(
            gate: self,
            id: id,
            registration: interfaceLayers.registerOpenMenu(
                ownedBy: client.owner
            )
        )
    }

    private func close(id: UUID) {
        clients.removeAll { $0.id == id }
        if clients.isEmpty {
            removeMonitor()
        }
    }

    /// Keys the playback key owner offers the open menus before seeking,
    /// volume and cue navigation see them. Returns whether a menu spent the
    /// key.
    func routeKey(_ keyCode: UInt16, isRepeat: Bool) -> Bool {
        for (_, client) in clients {
            guard client.receivesKeysFromRouter,
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
            matching: [.keyDown, .leftMouseDown, .rightMouseDown, .scrollWheel]
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
        var event: NSEvent? = event
        for (_, client) in clients {
            guard let current = event else {
                return nil
            }
            event = route(current, to: client)
        }
        return event
    }

    private func route(_ event: NSEvent, to client: Client) -> NSEvent? {
        // A covered menu stays on screen and takes no input; the layer above
        // it owns the event.
        guard !interfaceLayers.isMenuCovered(ownedBy: client.owner) else {
            return event
        }

        switch event.type {
        case .keyDown:
            guard client.receivesKeysFromMonitor,
                  let eventWindow = event.window,
                  eventWindow === client.window()
            else {
                return event
            }
            return client.handleKey(event.keyCode, event.isARepeat)
                ? nil
                : event

        case .scrollWheel:
            let menuWindow = client.window() ?? event.window
            guard !MenuOutsidePress.isFromAnotherWindow(
                event,
                menuWindow: menuWindow
            ) else {
                return event
            }
            if client.isPointerOnMenu(event) {
                // The menu is the one surface that may still scroll; a menu
                // that cannot scroll spends the wheel so nothing moves
                // underneath it.
                return client.menuTakesWheel ? event : nil
            }
            return client.bansScrolling ? nil : event

        case .leftMouseDown, .rightMouseDown:
            switch MenuOutsidePress.decide(
                event,
                menuWindow: client.window() ?? event.window,
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

        default:
            return event
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
    let bansScrolling: Bool
    let menuTakesWheel: Bool
    var receivesKeysFromMonitor = true
    var receivesKeysFromRouter = false
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
                    bansScrolling: representable.bansScrolling,
                    menuTakesWheel: representable.menuTakesWheel,
                    receivesKeysFromMonitor:
                        representable.receivesKeysFromMonitor,
                    receivesKeysFromRouter:
                        representable.receivesKeysFromRouter,
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
