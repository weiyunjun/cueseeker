import AppKit
import Foundation
import SwiftUI

extension Notification.Name {
    static let cueSeekerScrollDebounceSettled = Notification.Name(
        "CueSeekerScrollDebounceSettled"
    )
}

/// Coordinates the 300ms scroll-end debounce and cursor visibility state for
/// pointer hover and pointer shape updates across the App.
@MainActor
final class PointerHoverScrollState: ObservableObject {
    static let shared = PointerHoverScrollState()
    static let debounceNanoseconds: UInt64 = 300_000_000

    @Published private(set) var isScrolling = false
    @Published private(set) var isCursorHidden = false
    @Published private(set) var isSuppressedByKeyboardOrController = false
    private var debounceTask: Task<Void, Never>?
    private var activeHoverListeners: [UUID: () -> Void] = [:]

    var isHoverSuppressed: Bool {
        isScrolling || isSuppressedByKeyboardOrController
    }

    var activeHoverListenerCountForTesting: Int {
        activeHoverListeners.count
    }

    func setActiveHoverListener(id: UUID, listener: (() -> Void)?) {
        if let listener {
            activeHoverListeners[id] = listener
        } else {
            activeHoverListeners.removeValue(forKey: id)
        }
    }

    private func notifyActiveHoverListeners() {
        let listeners = Array(activeHoverListeners.values)
        for listener in listeners {
            listener()
        }
    }

    func noteScrolled() {
        var didChange = false
        if !isScrolling {
            isScrolling = true
            didChange = true
        }
        if didChange {
            notifyActiveHoverListeners()
        }
        CardHighlightModel.broadcastScrolled()
        MenuHighlightModel.broadcastScrolled()
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: Self.debounceNanoseconds)
            guard !Task.isCancelled else {
                return
            }
            self?.settleScroll()
        }
    }

    func noteSelectionMovedByKeyboardOrController() {
        var didChange = false
        if !isSuppressedByKeyboardOrController {
            isSuppressedByKeyboardOrController = true
            didChange = true
        }
        if didChange {
            notifyActiveHoverListeners()
        }
        AppPointerShape.noteKeyboardOrControllerSuppressedHover()
        CardHighlightModel.broadcastSelectionMovedByKeyboardOrController()
        MenuHighlightModel.broadcastSelectionMovedByKeyboardOrController()
    }

    func notePointerMoved() {
        debounceTask?.cancel()
        debounceTask = nil
        var didChange = false
        if isScrolling {
            isScrolling = false
            didChange = true
        }
        if isSuppressedByKeyboardOrController {
            isSuppressedByKeyboardOrController = false
            didChange = true
        }
        if didChange {
            notifyActiveHoverListeners()
        }
        CardHighlightModel.broadcastPointerMoved()
        MenuHighlightModel.broadcastPointerMoved()
    }

    func cancelScrollDebounceForWindowResign() {
        debounceTask?.cancel()
        debounceTask = nil
        if isScrolling {
            isScrolling = false
            notifyActiveHoverListeners()
        }
    }

    func settleScroll() {
        debounceTask?.cancel()
        debounceTask = nil
        if isScrolling {
            isScrolling = false
            notifyActiveHoverListeners()
        }
        guard !isSuppressedByKeyboardOrController else {
            return
        }
        NotificationCenter.default.post(
            name: .cueSeekerScrollDebounceSettled,
            object: nil
        )
        CardHighlightModel.broadcastScrollSettled()
        MenuHighlightModel.broadcastScrollSettled()
        AppPointerShape.noteScrollSettled()
    }

    func noteCursorHiddenChanged(_ isHidden: Bool) {
        if isCursorHidden != isHidden {
            isCursorHidden = isHidden
            notifyActiveHoverListeners()
        }
    }

    func resetForTesting() {
        debounceTask?.cancel()
        debounceTask = nil
        isScrolling = false
        isSuppressedByKeyboardOrController = false
        isCursorHidden = AppCursorVisibility.isCursorHidden
    }
}

/// Hover for a visual effect, reported only while the surface's layer owns
/// input, the cursor is visible, and scroll debounce is not active.
extension View {
    func onPointerHover(_ action: @escaping (Bool) -> Void) -> some View {
        modifier(PointerHoverModifier(action: action))
    }
}

/// The delivery rule, kept out of the view so it can be pinned by tests.
struct PointerHoverGate: Equatable {
    /// What the pointer last did, whether or not the surface was allowed to
    /// answer it.
    private var reportedIsHovered = false
    /// What the surface was last told, which is what it is painting.
    private var deliveredIsHovered = false

    var hasActiveHover: Bool {
        reportedIsHovered || deliveredIsHovered
    }

    /// Records what the pointer did and returns what the surface should be
    /// told, or nil when it should be told nothing.
    mutating func report(
        _ isHovered: Bool,
        isFrozen: Bool,
        isScrolling: Bool = false,
        isCursorHidden: Bool = false,
        isSuppressedByKeyboard: Bool = false
    ) -> Bool? {
        reportedIsHovered = isHovered
        return delivery(
            isFrozen: isFrozen,
            isScrolling: isScrolling,
            isCursorHidden: isCursorHidden,
            isSuppressedByKeyboard: isSuppressedByKeyboard
        )
    }

    /// Returns what the surface should be told now that the freeze, scroll,
    /// cursor visibility, or keyboard suppression state changed.
    mutating func freezeChanged(
        isFrozen: Bool,
        isScrolling: Bool = false,
        isCursorHidden: Bool = false,
        isSuppressedByKeyboard: Bool = false
    ) -> Bool? {
        delivery(
            isFrozen: isFrozen,
            isScrolling: isScrolling,
            isCursorHidden: isCursorHidden,
            isSuppressedByKeyboard: isSuppressedByKeyboard
        )
    }

    private mutating func delivery(
        isFrozen: Bool,
        isScrolling: Bool,
        isCursorHidden: Bool,
        isSuppressedByKeyboard: Bool
    ) -> Bool? {
        if isCursorHidden {
            guard deliveredIsHovered else {
                return nil
            }
            deliveredIsHovered = false
            return false
        }
        if isSuppressedByKeyboard {
            guard !isFrozen, deliveredIsHovered else {
                return nil
            }
            deliveredIsHovered = false
            return false
        }
        guard !isFrozen, !isScrolling else {
            return nil
        }
        guard deliveredIsHovered != reportedIsHovered else {
            return nil
        }
        deliveredIsHovered = reportedIsHovered
        return reportedIsHovered
    }
}

@MainActor
final class PointerHoverSession: ObservableObject {
    private struct WeakBox {
        weak var value: PointerHoverSession?
    }

    private static var registeredSessions: [ObjectIdentifier: WeakBox] = [:]

    static func broadcastLayerFrozenChanged(
        _ isFrozen: Bool,
        matching predicate: (InterfaceLayer) -> Bool
    ) {
        registeredSessions = registeredSessions.filter { $0.value.value != nil }
        for box in registeredSessions.values {
            guard let session = box.value, predicate(session.layer) else {
                continue
            }
            session.setFrozen(isFrozen)
        }
    }

    let id = UUID()
    var gate = PointerHoverGate()
    var layer: InterfaceLayer = .workbenchPage
    var isFrozen = false
    var action: ((Bool) -> Void)?
    weak var probeView: NSView?
    private var hasInitializedFreeze = false
    private var isListeningToScrollState = false

    init() {
        Self.registeredSessions[ObjectIdentifier(self)] = WeakBox(value: self)
    }

    deinit {
        let id = self.id
        let key = ObjectIdentifier(self)
        if Thread.isMainThread {
            MainActor.assumeIsolated {
                Self.registeredSessions.removeValue(forKey: key)
                PointerHoverScrollState.shared.setActiveHoverListener(id: id, listener: nil)
            }
        } else {
            Task { @MainActor in
                Self.registeredSessions.removeValue(forKey: key)
                PointerHoverScrollState.shared.setActiveHoverListener(id: id, listener: nil)
            }
        }
    }

    func initializeIfNeeded(isFrozen: Bool) {
        guard !hasInitializedFreeze else {
            return
        }
        hasInitializedFreeze = true
        self.isFrozen = isFrozen
    }

    func setFrozen(_ isFrozen: Bool) {
        let wasFrozen = self.isFrozen
        hasInitializedFreeze = true
        self.isFrozen = isFrozen
        if !isFrozen, (wasFrozen || gate.hasActiveHover), currentPointerInsideView() == false {
            let scrollState = PointerHoverScrollState.shared
            let delivered = gate.report(
                false,
                isFrozen: false,
                isScrolling: scrollState.isScrolling,
                isCursorHidden: AppCursorVisibility.isCursorHidden,
                isSuppressedByKeyboard: scrollState.isSuppressedByKeyboardOrController
            )
            syncScrollListener()
            action?(delivered ?? false)
            return
        }
        guard wasFrozen != isFrozen else {
            return
        }
        handleStateChanged()
    }

    func report(_ isHovered: Bool) {
        let scrollState = PointerHoverScrollState.shared
        let delivered = gate.report(
            isHovered,
            isFrozen: isFrozen,
            isScrolling: scrollState.isScrolling,
            isCursorHidden: AppCursorVisibility.isCursorHidden,
            isSuppressedByKeyboard: scrollState.isSuppressedByKeyboardOrController
        )
        syncScrollListener()
        if let delivered {
            action?(delivered)
        }
    }

    func handleStateChanged() {
        let scrollState = PointerHoverScrollState.shared
        let delivered = gate.freezeChanged(
            isFrozen: isFrozen,
            isScrolling: scrollState.isScrolling,
            isCursorHidden: AppCursorVisibility.isCursorHidden,
            isSuppressedByKeyboard: scrollState.isSuppressedByKeyboardOrController
        )
        syncScrollListener()
        if let delivered {
            action?(delivered)
        }
    }

    func unregisterScrollListener() {
        guard isListeningToScrollState else {
            return
        }
        isListeningToScrollState = false
        PointerHoverScrollState.shared.setActiveHoverListener(id: id, listener: nil)
    }

    func syncScrollListener() {
        let shouldListen = gate.hasActiveHover
        guard shouldListen != isListeningToScrollState else {
            return
        }
        isListeningToScrollState = shouldListen
        if shouldListen {
            PointerHoverScrollState.shared.setActiveHoverListener(id: id) { [weak self] in
                self?.handleStateChanged()
            }
        } else {
            PointerHoverScrollState.shared.setActiveHoverListener(id: id, listener: nil)
        }
    }

    private func currentPointerInsideView() -> Bool? {
        guard let probeView,
              let window = probeView.window,
              !probeView.isHiddenOrHasHiddenAncestor,
              probeView.bounds.width > 0,
              probeView.bounds.height > 0
        else {
            return nil
        }
        let isWindowFocused: Bool
        if let cueSeekerWindow = window as? CueSeekerWindow {
            isWindowFocused = cueSeekerWindow.isFocusedForHover
        } else {
            isWindowFocused = NSApp.isActive && window.isKeyWindow
        }
        guard isWindowFocused else {
            return false
        }
        let overrideLocation = resolveMouseLocationOverride(from: probeView, in: window)
        if overrideLocation == nil,
           (window as? CueSeekerWindow)?.isWindowFocusedOverrideForTesting == nil {
            guard NSWindow.windowNumber(
                at: NSEvent.mouseLocation,
                belowWindowWithWindowNumber: 0
            ) == window.windowNumber else {
                return false
            }
        }
        let locationInWindow = overrideLocation ?? window.mouseLocationOutsideOfEventStream
        let localPoint = probeView.convert(locationInWindow, from: nil)
        let visibleBounds = probeView.bounds.intersection(probeView.visibleRect)
        return !visibleBounds.isEmpty && visibleBounds.contains(localPoint)
    }

    private func resolveMouseLocationOverride(
        from view: NSView,
        in window: NSWindow
    ) -> CGPoint? {
        var current: NSView? = view
        while let candidate = current {
            if let overrideSource = candidate as? CueSeekerHostingViewLocationOverride,
               let point = overrideSource.mouseLocationOverrideForTesting {
                return point
            }
            current = candidate.superview
        }
        return (window.contentView as? CueSeekerHostingViewLocationOverride)?
            .mouseLocationOverrideForTesting
    }
}

private final class PointerHoverProbeView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}

private struct PointerHoverProbe: NSViewRepresentable {
    let session: PointerHoverSession

    func makeNSView(context: Context) -> NSView {
        let view = PointerHoverProbeView()
        session.probeView = view
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        session.probeView = nsView
    }
}

private struct PointerHoverModifier: ViewModifier {
    let action: (Bool) -> Void
    @Environment(\.interfaceLayers) private var interfaceLayers
    @Environment(\.interfaceLayerContext) private var layerContext
    @StateObject private var session = PointerHoverSession()

    private var effectiveIsFrozen: Bool {
        interfaceLayers?.isFrozen(layerContext.layer) ?? layerContext.isFrozen
    }

    func body(content: Content) -> some View {
        let isFrozen = effectiveIsFrozen
        let _ = {
            session.action = action
            session.layer = layerContext.layer
            session.initializeIfNeeded(isFrozen: isFrozen)
        }()
        content
            .background(PointerHoverProbe(session: session))
            .onAppear {
                session.action = action
                session.layer = layerContext.layer
                session.setFrozen(effectiveIsFrozen)
                session.syncScrollListener()
            }
            .onHover { isHovered in
                session.action = action
                session.layer = layerContext.layer
                session.isFrozen = effectiveIsFrozen
                session.report(isHovered)
            }
            .onChange(of: layerContext.isFrozen) { isFrozen in
                session.action = action
                session.layer = layerContext.layer
                session.setFrozen(interfaceLayers?.isFrozen(layerContext.layer) ?? isFrozen)
            }
            .onDisappear {
                session.unregisterScrollListener()
            }
    }
}
