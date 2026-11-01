import AppKit
import CoreGraphics
import SwiftUI

enum LibraryCardContextMenuCoordinateSpace {
    static let name = "LibraryCardContextMenuCoordinateSpace"
}

/// The card whose menu is open reports its new anchor through this, so the menu
/// travels with the card when the page scrolls or the grid reflows.
private struct LibraryCardContextMenuAnchorUpdateKey: EnvironmentKey {
    nonisolated(unsafe) static let defaultValue: ((CGPoint) -> Void)? = nil
}

/// Which card the open menu belongs to, or nil when no menu is open.
private struct LibraryCardContextMenuOwnerKey: EnvironmentKey {
    static let defaultValue: String? = nil
}

/// Which card or control owns an open button-anchored (`...`) menu, or nil when
/// the menu was opened via right-click or no menu is open.
private struct LibraryCardContextMenuAnchorOwnerKey: EnvironmentKey {
    static let defaultValue: String? = nil
}

/// The nearest enclosing host's opener. A page that hosts the menu at its own
/// root publishes it here, so a grid inside that page hands its cards the page's
/// host instead of standing up one of its own.
private struct LibraryCardContextMenuOpenKey: EnvironmentKey {
    nonisolated(unsafe) static let defaultValue: (([LibraryCardContextMenuItem], CGPoint, String) -> Void)? = nil
}

private struct LibraryCardContextMenuToggleAnchorKey: EnvironmentKey {
    nonisolated(unsafe) static let defaultValue: (([LibraryCardContextMenuItem], MenuAnchorHandle, String) -> Void)? = nil
}

extension EnvironmentValues {
    var libraryCardContextMenuAnchorUpdate: ((CGPoint) -> Void)? {
        get { self[LibraryCardContextMenuAnchorUpdateKey.self] }
        set { self[LibraryCardContextMenuAnchorUpdateKey.self] = newValue }
    }

    var libraryCardContextMenuOpen: (([LibraryCardContextMenuItem], CGPoint, String) -> Void)? {
        get { self[LibraryCardContextMenuOpenKey.self] }
        set { self[LibraryCardContextMenuOpenKey.self] = newValue }
    }

    var libraryCardContextMenuToggleAnchor: (([LibraryCardContextMenuItem], MenuAnchorHandle, String) -> Void)? {
        get { self[LibraryCardContextMenuToggleAnchorKey.self] }
        set { self[LibraryCardContextMenuToggleAnchorKey.self] = newValue }
    }

    /// The card the open menu hangs off. A card that matches keeps its
    /// highlight while every other card is frozen.
    var libraryCardContextMenuOwner: String? {
        get { self[LibraryCardContextMenuOwnerKey.self] }
        set { self[LibraryCardContextMenuOwnerKey.self] = newValue }
    }

    /// The owner ID of a menu opened from a `...` button anchor (`anchorFrame != nil`).
    /// Right-click context menus leave this nil so the `...` button does not enter `Open` state.
    var libraryCardContextMenuAnchorOwner: String? {
        get { self[LibraryCardContextMenuAnchorOwnerKey.self] }
        set { self[LibraryCardContextMenuAnchorOwnerKey.self] = newValue }
    }
}

struct LibraryCardContextMenuItem: Identifiable {
    let title: String
    let icon: AppIcon
    var isEnabled = true
    let action: () -> Void

    var id: String {
        title
    }
}

enum LibraryCoverContextMenuItem {
    static let title = L("library.change_cover")
    static let icon = AppIcon.export
}

private struct LibraryCardContextMenuState: Identifiable {
    let id = UUID()
    /// Which card or control the menu hangs off. The card compares it with its
    /// own id to decide whether it is the one that stays lit.
    let ownerID: String
    var anchorPoint: CGPoint
    var anchorSize: CGSize = .zero
    var anchorFrame: CGRect? = nil
    let items: [LibraryCardContextMenuItem]
    /// Measured and decided when the menu opened. From then on the menu only
    /// translates, so nothing can send it to the other side mid-scroll.
    let menuSize: CGSize
    /// The room the side it opened on had for it, when that was less than the
    /// menu wanted. It scrolls the rest, and keeps this for as long as it stays
    /// open.
    let maximumHeight: CGFloat
    let placementOffset: CGSize
}

/// Answers "how much of this page can the reader see", which is what a menu
/// measures the room below a card against. Asked at the moment of the click, the
/// way the table asks its own scroll view, so nothing has to be published ahead
/// of time or kept in step.
@MainActor
private final class LibraryCardMenuHostGeometry {
    weak var probe: LibraryCardMenuViewportProbe.ProbeView?

    var visibleRect: CGRect {
        guard let probe else {
            return .zero
        }
        // A page that is not inside a scroll view is visible in full.
        let visible = probe.visibleRect
        return visible.isEmpty ? probe.bounds : visible
    }

    func anchorFrame(for handle: MenuAnchorHandle) -> CGRect? {
        guard let probe, let windowFrame = handle.windowFrame, probe.window != nil else {
            return nil
        }
        return probe.convert(windowFrame, from: nil)
    }
}

/// Sits behind the page at its exact size and reports what of it is unclipped.
private struct LibraryCardMenuViewportProbe: NSViewRepresentable {
    let geometry: LibraryCardMenuHostGeometry

    func makeNSView(context _: Context) -> ProbeView {
        let view = ProbeView()
        geometry.probe = view
        return view
    }

    func updateNSView(_ nsView: ProbeView, context _: Context) {
        geometry.probe = nsView
    }

    final class ProbeView: NSView {
        /// SwiftUI measures top-left down; this view has to answer in the same
        /// direction or every "below" becomes an "above".
        override var isFlipped: Bool {
            true
        }

        override func hitTest(_ point: NSPoint) -> NSView? {
            nil
        }
    }
}

struct LibraryCardContextMenuHost<Content: View>: View {
    @Environment(\.interfaceLayers) private var interfaceLayers
    /// The menu belongs to the layer its cards are on. Registering it against
    /// the workbench page from inside the Command Panel hands the gate a menu
    /// it considers covered, so the menu takes no keys, no outside press and
    /// no scroll ban, and the panel's own cards keep following the pointer.
    @Environment(\.interfaceLayerContext) private var layerContext
    /// Names the interface whose cards this host is showing. A host that spans
    /// several interfaces — the Recent page hosts one menu for its overview and
    /// both of its sections — closes the menu when the interface changes under
    /// it, because the card it hangs off is no longer on screen.
    var interfaceID: String = ""
    @State private var activeMenu: LibraryCardContextMenuState?
    @StateObject private var highlight = MenuHighlightModel()
    @State private var geometry = LibraryCardMenuHostGeometry()
    private let buildContent: (
        _ openContextMenu: @escaping ([LibraryCardContextMenuItem], CGPoint, String) -> Void,
        _ toggleAnchorMenu: @escaping ([LibraryCardContextMenuItem], MenuAnchorHandle, String) -> Void,
        _ activeOwnerID: String?
    ) -> Content

    init(
        interfaceID: String = "",
        @ViewBuilder content: @escaping (_ openContextMenu: @escaping ([LibraryCardContextMenuItem], CGPoint, String) -> Void) -> Content
    ) {
        self.interfaceID = interfaceID
        self.buildContent = { openContextMenu, _, _ in
            content(openContextMenu)
        }
    }

    init(
        interfaceID: String = "",
        @ViewBuilder content: @escaping (
            _ openContextMenu: @escaping ([LibraryCardContextMenuItem], CGPoint, String) -> Void,
            _ toggleAnchorMenu: @escaping ([LibraryCardContextMenuItem], MenuAnchorHandle, String) -> Void,
            _ activeOwnerID: String?
        ) -> Content
    ) {
        self.interfaceID = interfaceID
        self.buildContent = content
    }

    var body: some View {
        buildContent(openContextMenu, toggleAnchorMenu, activeMenu?.ownerID)
            .onChange(of: interfaceID) { _ in
                dismissContextMenu()
            }
            .environment(\.libraryCardContextMenuAnchorUpdate, updateAnchorPoint)
            .environment(\.libraryCardContextMenuOpen, openContextMenu)
            .environment(\.libraryCardContextMenuToggleAnchor, toggleAnchorMenu)
            .environment(\.libraryCardContextMenuOwner, activeMenu?.ownerID)
            .environment(
                \.libraryCardContextMenuAnchorOwner,
                activeMenu?.anchorFrame != nil ? activeMenu?.ownerID : nil
            )
            .coordinateSpace(name: LibraryCardContextMenuCoordinateSpace.name)
            .background(LibraryCardMenuViewportProbe(geometry: geometry))
            .overlay(alignment: .topLeading) {
                if let activeMenu {
                    let menuFrame = menuFrame(for: activeMenu)
                    ZStack(alignment: .topLeading) {
                        MenuGateClientView(
                            gate: interfaceLayers?.menuGate,
                            owner: layerContext.layer,
                            // On a playback layer the key owner offers keys to
                            // the gate before the Command Panel navigates, so
                            // the menu must take them there.
                            kind: .cardMenu,
                            menuFrame: menuFrame,
                            anchorFrame: activeMenu.anchorFrame,
                            handleKey: { keyCode, _ in
                                highlight.handleStandardMenuKey(
                                    keyCode: keyCode,
                                    onActivate: { _ = activateHighlightedItem() },
                                    onDismiss: { dismissContextMenu() }
                                )
                            },
                            dismiss: { _ in
                                dismissContextMenu(openedAs: activeMenu.id)
                            }
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .allowsHitTesting(false)

                        LibraryCardContextMenu(
                            items: activeMenu.items,
                            highlight: highlight,
                            maximumHeight: activeMenu.maximumHeight,
                            onDismiss: { dismissContextMenu() }
                        )
                        .offset(
                            CGSize(
                                width: menuFrame.minX,
                                height: menuFrame.minY
                            )
                        )
                    }
                    .id(activeMenu.id)
                    .zIndex(1000)
                }
            }
    }

    /// Measures the menu, chooses its side once, and remembers the offset — the
    /// same order the table's menus follow.
    private func openContextMenu(
        items: [LibraryCardContextMenuItem],
        anchorPoint: CGPoint,
        ownerID: String
    ) {
        openMenu(
            items: items,
            anchor: CGRect(origin: anchorPoint, size: .zero),
            anchorFrame: nil,
            ownerID: ownerID
        )
    }

    private func toggleAnchorMenu(
        items: [LibraryCardContextMenuItem],
        anchor: MenuAnchorHandle,
        ownerID: String
    ) {
        if activeMenu?.ownerID == ownerID, activeMenu?.anchorFrame != nil {
            dismissContextMenu()
            return
        }
        guard let anchorRect = geometry.anchorFrame(for: anchor) else {
            return
        }
        openMenu(
            items: items,
            anchor: anchorRect,
            anchorFrame: anchorRect,
            ownerID: ownerID
        )
    }

    private func openMenu(
        items: [LibraryCardContextMenuItem],
        anchor: CGRect,
        anchorFrame: CGRect?,
        ownerID: String
    ) {
        let startedAt = ProcessInfo.processInfo.systemUptime
        let measureStartedAt = ProcessInfo.processInfo.systemUptime
        let naturalSize = measuredMenuSize(
            for: items,
            maximumHeight: MenuMetrics.maximumHeight
        )
        let place = { (menuSize: CGSize) in
            MenuPlacement.openingFrame(
                anchor: anchor,
                menuSize: menuSize,
                in: geometry.visibleRect,
                gap: WorkbenchControlMetrics.redesignSpacing1,
                shrinksToFit: true
            )
        }
        var menuSize = naturalSize
        var maximumHeight = MenuMetrics.maximumHeight
        var openingFrame = place(naturalSize)
        if openingFrame.height < naturalSize.height {
            // Held to the room on its side, the menu gains its scrollbar and
            // widens, so it is measured and placed again.
            maximumHeight = openingFrame.height
            menuSize = measuredMenuSize(for: items, maximumHeight: maximumHeight)
            openingFrame = place(menuSize)
        }
        let measureMs = max(0, (ProcessInfo.processInfo.systemUptime - measureStartedAt) * 1_000)
        DebugInteractionLatencyProbe.markMenuTriggerContext(
            menuID: anchorFrame != nil ? "card_button_menu" : "card_context_menu",
            trigger: anchorFrame != nil ? "button_anchor" : "right_click",
            startedAt: startedAt,
            measureMs: measureMs
        )
        activeMenu = LibraryCardContextMenuState(
            ownerID: ownerID,
            anchorPoint: anchor.origin,
            anchorSize: anchor.size,
            anchorFrame: anchorFrame,
            items: items,
            menuSize: menuSize,
            maximumHeight: maximumHeight,
            placementOffset: MenuPlacement.offset(from: anchor, to: openingFrame)
        )
        highlight.open(
            selectablePositions: items.indices.filter { items[$0].isEnabled },
            allPositions: Array(items.indices)
        )
    }

    private func measuredMenuSize(
        for items: [LibraryCardContextMenuItem],
        maximumHeight: CGFloat
    ) -> CGSize {
        let host = NSHostingView(
            rootView: LibraryCardContextMenu(
                items: items,
                highlight: highlight,
                maximumHeight: maximumHeight,
                onDismiss: {}
            )
        )
        host.layoutSubtreeIfNeeded()
        return host.fittingSize
    }

    /// Closes the menu that was open when the caller decided to close it. A
    /// right-click relay opens the next menu on the same press, and the order
    /// two event monitors run in is not ours to choose, so a late dismissal
    /// must not take the new menu with it.
    private func dismissContextMenu(openedAs id: UUID? = nil) {
        if let id, activeMenu?.id != id {
            return
        }
        activeMenu = nil
        highlight.close()
    }

    /// Moves the open menu with its card. The side it opened on is already in
    /// `placementOffset`, so this is pure translation.
    private func updateAnchorPoint(_ anchorPoint: CGPoint) {
        guard var menu = activeMenu, menu.anchorPoint != anchorPoint else {
            return
        }
        menu.anchorPoint = anchorPoint
        if menu.anchorFrame != nil {
            menu.anchorFrame = CGRect(origin: anchorPoint, size: menu.anchorSize)
        }
        activeMenu = menu
    }

    /// Enter runs whatever the highlight sits on, so the keyboard and the
    /// pointer commit through one path.
    @discardableResult
    private func activateHighlightedItem() -> Bool {
        guard let position = highlight.activeTriggerPosition,
              let items = activeMenu?.items,
              items.indices.contains(position),
              items[position].isEnabled
        else {
            return false
        }
        let item = items[position]
        dismissContextMenu()
        item.action()
        return true
    }

    /// Pure translation. The side and the distance were settled when the menu
    /// opened, so a scrolling page moves the menu and never re-decides it.
    private func menuFrame(for menu: LibraryCardContextMenuState) -> CGRect {
        MenuPlacement.followingFrame(
            anchor: CGRect(origin: menu.anchorPoint, size: menu.anchorSize),
            offset: menu.placementOffset,
            menuSize: menu.menuSize
        )
    }
}

private struct LibraryCardContextMenu: View {
    let items: [LibraryCardContextMenuItem]
    @ObservedObject var highlight: MenuHighlightModel
    var maximumHeight: CGFloat = MenuMetrics.maximumHeight
    let onDismiss: () -> Void

    var body: some View {
        WorkbenchPopoverPanel(
            maximumHeight: maximumHeight,
            highlight: highlight
        ) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { position, item in
                    WorkbenchPopoverRow(
                        title: item.title,
                        isHighlighted: highlight.isSelected(position),
                        isRowHovered: highlight.isHovered(position),
                        isAccessibilityFocused: highlight.isAccessibilityFocused(position),
                        icon: item.icon,
                        showsCheckmarkSlot: false,
                        isEnabled: item.isEnabled,
                        action: {
                            onDismiss()
                            item.action()
                        },
                        onHoverChange: { isHovered in
                            highlight.noteHover(isHovered, at: position)
                        }
                    )
                    .id(position)
                }
            }
            .frame(minWidth: 220, alignment: .leading)
        }
        .fixedSize(horizontal: true, vertical: false)
    }
}

private struct LibraryCardContextMenuTriggerModifier: ViewModifier {
    let isEnabled: Bool
    let ownerID: String
    let items: [LibraryCardContextMenuItem]
    let openContextMenu: ([LibraryCardContextMenuItem], CGPoint, String) -> Void
    @Environment(\.interfaceLayers) private var interfaceLayers
    @Environment(\.interfaceLayerContext) private var layerContext
    @Environment(\.libraryCardContextMenuOwner) private var contextMenuOwnerID
    @Environment(\.libraryCardContextMenuAnchorUpdate) private var updateAnchor
    /// Set on the one card the open menu belongs to, so only that card reports
    /// where it moved to.
    @State private var localAnchorPoint: CGPoint?

    func body(content: Content) -> some View {
        content.background(
            GeometryReader { proxy in
                let frame = proxy.frame(in: .named(LibraryCardContextMenuCoordinateSpace.name))
                // An open menu is not a reason to refuse: the press that
                // closed it is the same press that opens this card's menu.
                LibraryCardRightClickMonitor(
                    isEnabled: isEnabled && !layerContext.isCovered,
                    menuGate: interfaceLayers?.menuGate
                ) { localPoint in
                    localAnchorPoint = localPoint
                    openContextMenu(
                        items,
                        CGPoint(
                            x: frame.minX + localPoint.x,
                            y: frame.minY + localPoint.y
                        ),
                        ownerID
                    )
                }
                .onChange(of: frame.origin) { origin in
                    guard contextMenuOwnerID != nil, let localAnchorPoint else {
                        return
                    }
                    updateAnchor?(
                        CGPoint(
                            x: origin.x + localAnchorPoint.x,
                            y: origin.y + localAnchorPoint.y
                        )
                    )
                }
                .onChange(of: contextMenuOwnerID == nil) { isClosed in
                    if isClosed {
                        localAnchorPoint = nil
                    }
                }
            }
        )
    }
}

private struct LibraryCardRightClickMonitor: NSViewRepresentable {
    let isEnabled: Bool
    let menuGate: MenuGate?
    let onRightClick: (CGPoint) -> Void

    func makeNSView(context _: Context) -> MonitoringView {
        MonitoringView()
    }

    func updateNSView(_ nsView: MonitoringView, context _: Context) {
        nsView.update(
            isEnabled: isEnabled,
            menuGate: menuGate,
            onRightClick: onRightClick
        )
    }

    final class MonitoringView: NSView {
        nonisolated(unsafe) private var monitor: Any?
        private var isEnabled = false
        private weak var menuGate: MenuGate?
        private var onRightClick: ((CGPoint) -> Void)?

        override var isFlipped: Bool {
            true
        }

        func update(
            isEnabled: Bool,
            menuGate: MenuGate?,
            onRightClick: @escaping (CGPoint) -> Void
        ) {
            self.isEnabled = isEnabled
            self.menuGate = menuGate
            self.onRightClick = onRightClick
            updateMonitor()
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            updateMonitor()
        }

        deinit {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
        }

        private func updateMonitor() {
            guard isEnabled, window != nil else {
                removeMonitor()
                return
            }
            guard monitor == nil else {
                return
            }
            monitor = NSEvent.addLocalMonitorForEvents(matching: [.rightMouseDown]) { [weak self] event in
                guard let self else {
                    return event
                }
                guard event.window === self.window else {
                    return event
                }

                let localPoint = self.convert(event.locationInWindow, from: nil)
                // Only the part of the card the reader can actually see answers:
                // a card the page has scrolled out of view must not claim a
                // press made over whatever covers it.
                guard self.bounds.intersection(self.visibleRect).contains(localPoint) else {
                    return event
                }

                // Card monitors are installed when cards appear, before any
                // menu opens, so they see a right-click before the gate's own
                // monitor does. Routing through the gate first lets an open
                // menu swallow a right-click inside its own surface or close
                // before this card opens its menu.
                if let menuGate = self.menuGate {
                    guard menuGate.route(event) != nil else {
                        return nil
                    }
                }

                self.onRightClick?(localPoint)
                return nil
            }
        }

        private func removeMonitor() {
            guard let monitor else {
                return
            }
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
}

extension View {
    func libraryCardContextMenuTrigger(
        isEnabled: Bool,
        ownerID: String,
        items: [LibraryCardContextMenuItem],
        openContextMenu: @escaping ([LibraryCardContextMenuItem], CGPoint, String) -> Void
    ) -> some View {
        modifier(
            LibraryCardContextMenuTriggerModifier(
                isEnabled: isEnabled,
                ownerID: ownerID,
                items: items,
                openContextMenu: openContextMenu
            )
        )
    }
}
