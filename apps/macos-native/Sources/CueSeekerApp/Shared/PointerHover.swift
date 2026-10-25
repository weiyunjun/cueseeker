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

    func onPointerHoverLocation(_ action: @escaping (CGPoint?) -> Void) -> some View {
        modifier(PointerHoverLocationModifier(action: action))
    }
}

/// The continuous pointer location delivery rule, kept out of the view so it
/// can be pinned by tests.
struct PointerHoverLocationGate: Equatable {
    private(set) var reportedLocation: CGPoint?
    private(set) var deliveredLocation: CGPoint?

    var hasActiveHover: Bool {
        reportedLocation != nil || deliveredLocation != nil
    }

    mutating func report(
        _ location: CGPoint?,
        isFrozen: Bool,
        isScrolling: Bool = false,
        isCursorHidden: Bool = false,
        isSuppressedByKeyboard: Bool = false
    ) -> CGPoint?? {
        reportedLocation = location
        return delivery(
            isFrozen: isFrozen,
            isScrolling: isScrolling,
            isCursorHidden: isCursorHidden,
            isSuppressedByKeyboard: isSuppressedByKeyboard
        )
    }

    mutating func freezeChanged(
        isFrozen: Bool,
        isScrolling: Bool = false,
        isCursorHidden: Bool = false,
        isSuppressedByKeyboard: Bool = false
    ) -> CGPoint?? {
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
    ) -> CGPoint?? {
        if isCursorHidden {
            guard deliveredLocation != nil else {
                return nil
            }
            deliveredLocation = nil
            return .some(nil)
        }
        if isSuppressedByKeyboard {
            guard !isFrozen, deliveredLocation != nil else {
                return nil
            }
            deliveredLocation = nil
            return .some(nil)
        }
        guard !isFrozen, !isScrolling else {
            return nil
        }
        guard deliveredLocation != reportedLocation else {
            return nil
        }
        deliveredLocation = reportedLocation
        return .some(reportedLocation)
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
    private enum ProbeSample: Equatable {
        case unavailable
        case outside
        case inside(CGPoint)
    }

    private struct WeakBox {
        weak var value: PointerHoverSession?
    }

    private static var registeredSessions: [ObjectIdentifier: WeakBox] = [:]

    static func broadcastLayerFrozenChanged(
        _ isFrozen: Bool,
        in registry: InterfaceLayerRegistry? = nil,
        matching predicate: (InterfaceLayer) -> Bool
    ) {
        registeredSessions = registeredSessions.filter { $0.value.value != nil }
        for box in registeredSessions.values {
            guard let session = box.value,
                  (registry == nil || session.registry == nil || session.registry === registry),
                  predicate(session.layer)
            else {
                continue
            }
            session.setFrozen(isFrozen)
        }
    }

    static func notifyMouseMoved(in window: NSWindow, locationInWindow: CGPoint) {
        registeredSessions = registeredSessions.filter { $0.value.value != nil }
        for box in registeredSessions.values {
            guard let session = box.value,
                  session.tracksLocation,
                  session.probeView?.window === window
            else {
                continue
            }
            session.handleWindowMouseMoved(locationInWindow: locationInWindow)
        }
    }

    static func notifyMouseExited(in window: NSWindow) {
        registeredSessions = registeredSessions.filter { $0.value.value != nil }
        for box in registeredSessions.values {
            guard let session = box.value,
                  session.tracksLocation,
                  session.probeView?.window === window
            else {
                continue
            }
            session.reportLocation(nil)
        }
    }

    static func syncWindowFocusChanged(in window: NSWindow) {
        registeredSessions = registeredSessions.filter { $0.value.value != nil }
        for box in registeredSessions.values {
            guard let session = box.value,
                  session.tracksLocation,
                  session.probeView?.window === window
            else {
                continue
            }
            session.handleStateChanged()
        }
    }

    let id = UUID()
    var gate = PointerHoverGate()
    var locationGate = PointerHoverLocationGate()
    weak var registry: InterfaceLayerRegistry?
    var layer: InterfaceLayer = .workbenchPage
    var isFrozen = false
    var tracksLocation = false
    var action: ((Bool) -> Void)?
    var locationAction: ((CGPoint?) -> Void)?
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
        if tracksLocation {
            if !isFrozen {
                let hadActiveHover = locationGate.hasActiveHover
                let scrollState = PointerHoverScrollState.shared
                let isCursorHidden = AppCursorVisibility.isCursorHidden
                switch currentPointerSampleInView() {
                case .inside(let localPoint):
                    let delivered = locationGate.report(
                        localPoint,
                        isFrozen: false,
                        isScrolling: scrollState.isScrolling,
                        isCursorHidden: isCursorHidden,
                        isSuppressedByKeyboard: scrollState.isSuppressedByKeyboardOrController
                    )
                    syncScrollListener()
                    if let delivered {
                        locationAction?(delivered)
                    } else if wasFrozen,
                              !scrollState.isScrolling,
                              !isCursorHidden,
                              !scrollState.isSuppressedByKeyboardOrController {
                        locationAction?(localPoint)
                    }
                    return
                case .outside:
                    let delivered = locationGate.report(
                        nil,
                        isFrozen: false,
                        isScrolling: scrollState.isScrolling,
                        isCursorHidden: isCursorHidden,
                        isSuppressedByKeyboard: scrollState.isSuppressedByKeyboardOrController
                    )
                    syncScrollListener()
                    if let delivered {
                        locationAction?(delivered)
                    } else if hadActiveHover {
                        locationAction?(nil)
                    }
                    return
                case .unavailable:
                    break
                }
            }
            guard wasFrozen != isFrozen else {
                return
            }
            handleStateChanged()
            return
        }
        if !isFrozen, (wasFrozen || gate.hasActiveHover), let pointerInside = currentPointerInsideView() {
            let hadActiveHover = gate.hasActiveHover
            let scrollState = PointerHoverScrollState.shared
            let delivered = gate.report(
                pointerInside,
                isFrozen: false,
                isScrolling: scrollState.isScrolling,
                isCursorHidden: AppCursorVisibility.isCursorHidden,
                isSuppressedByKeyboard: scrollState.isSuppressedByKeyboardOrController
            )
            syncScrollListener()
            if let delivered {
                action?(delivered)
            } else if hadActiveHover, !pointerInside {
                action?(false)
            }
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

    func reportLocation(_ location: CGPoint?) {
        let scrollState = PointerHoverScrollState.shared
        let delivered = locationGate.report(
            location,
            isFrozen: isFrozen,
            isScrolling: scrollState.isScrolling,
            isCursorHidden: AppCursorVisibility.isCursorHidden,
            isSuppressedByKeyboard: scrollState.isSuppressedByKeyboardOrController
        )
        syncScrollListener()
        if let delivered {
            locationAction?(delivered)
        }
    }

    func handleWindowMouseMoved(locationInWindow: CGPoint) {
        guard let probeView,
              let window = probeView.window,
              !probeView.isHiddenOrHasHiddenAncestor,
              probeView.bounds.width > 0,
              probeView.bounds.height > 0
        else {
            return
        }
        let isWindowFocused: Bool
        if let cueSeekerWindow = window as? CueSeekerWindow {
            isWindowFocused = cueSeekerWindow.isFocusedForHover
        } else {
            isWindowFocused = NSApp.isActive && window.isKeyWindow
        }
        guard isWindowFocused else {
            return
        }
        let localPoint = probeView.convert(locationInWindow, from: nil)
        let visibleBounds = probeView.bounds.intersection(probeView.visibleRect)
        if !visibleBounds.isEmpty && visibleBounds.contains(localPoint) {
            reportLocation(localPoint)
        } else {
            reportLocation(nil)
        }
    }

    func handleStateChanged() {
        let scrollState = PointerHoverScrollState.shared
        let isCursorHidden = AppCursorVisibility.isCursorHidden
        if tracksLocation {
            if !isFrozen,
               !scrollState.isScrolling,
               !isCursorHidden,
               !scrollState.isSuppressedByKeyboardOrController {
                switch currentPointerSampleInView() {
                case .inside(let localPoint):
                    let delivered = locationGate.report(
                        localPoint,
                        isFrozen: false,
                        isScrolling: false,
                        isCursorHidden: false,
                        isSuppressedByKeyboard: false
                    )
                    syncScrollListener()
                    if let delivered {
                        locationAction?(delivered)
                    }
                    return
                case .outside:
                    if locationGate.hasActiveHover {
                        let delivered = locationGate.report(
                            nil,
                            isFrozen: false,
                            isScrolling: false,
                            isCursorHidden: false,
                            isSuppressedByKeyboard: false
                        )
                        syncScrollListener()
                        if let delivered {
                            locationAction?(delivered)
                        }
                        return
                    }
                case .unavailable:
                    break
                }
            }
            let delivered = locationGate.freezeChanged(
                isFrozen: isFrozen,
                isScrolling: scrollState.isScrolling,
                isCursorHidden: isCursorHidden,
                isSuppressedByKeyboard: scrollState.isSuppressedByKeyboardOrController
            )
            syncScrollListener()
            if let delivered {
                locationAction?(delivered)
            }
            return
        }
        if !isFrozen,
           !scrollState.isScrolling,
           !isCursorHidden,
           !scrollState.isSuppressedByKeyboardOrController,
           gate.hasActiveHover,
           let pointerInside = currentPointerInsideView() {
            let delivered = gate.report(
                pointerInside,
                isFrozen: false,
                isScrolling: false,
                isCursorHidden: false,
                isSuppressedByKeyboard: false
            )
            syncScrollListener()
            if let delivered {
                action?(delivered)
            }
            return
        }
        let delivered = gate.freezeChanged(
            isFrozen: isFrozen,
            isScrolling: scrollState.isScrolling,
            isCursorHidden: isCursorHidden,
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
        let shouldListen = tracksLocation ? locationGate.hasActiveHover : gate.hasActiveHover
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
        switch currentPointerSampleInView() {
        case .unavailable:
            return nil
        case .outside:
            return false
        case .inside:
            return true
        }
    }

    private func currentPointerSampleInView() -> ProbeSample {
        guard let probeView,
              let window = probeView.window,
              !probeView.isHiddenOrHasHiddenAncestor,
              probeView.bounds.width > 0,
              probeView.bounds.height > 0
        else {
            return .unavailable
        }
        let isWindowFocused: Bool
        if let cueSeekerWindow = window as? CueSeekerWindow {
            isWindowFocused = cueSeekerWindow.isFocusedForHover
        } else {
            isWindowFocused = NSApp.isActive && window.isKeyWindow
        }
        guard isWindowFocused else {
            return .outside
        }
        let overrideLocation = resolveMouseLocationOverride(from: probeView, in: window)
        if overrideLocation == nil,
           (window as? CueSeekerWindow)?.isWindowFocusedOverrideForTesting == nil {
            guard NSWindow.windowNumber(
                at: NSEvent.mouseLocation,
                belowWindowWithWindowNumber: 0
            ) == window.windowNumber else {
                return .outside
            }
        }
        let locationInWindow = overrideLocation ?? window.mouseLocationOutsideOfEventStream
        let localPoint = probeView.convert(locationInWindow, from: nil)
        let visibleBounds = probeView.bounds.intersection(probeView.visibleRect)
        guard !visibleBounds.isEmpty && visibleBounds.contains(localPoint) else {
            return .outside
        }
        return .inside(localPoint)
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
    weak var session: PointerHoverSession?
    var tracksLocation = false {
        didSet {
            if oldValue != tracksLocation {
                updateTrackingAreas()
            }
        }
    }

    override var isFlipped: Bool {
        true
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        guard tracksLocation else {
            return
        }
        addTrackingArea(
            NSTrackingArea(
                rect: .zero,
                options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect],
                owner: self,
                userInfo: nil
            )
        )
    }

    override func mouseEntered(with event: NSEvent) {
        guard tracksLocation else {
            return
        }
        session?.handleWindowMouseMoved(locationInWindow: event.locationInWindow)
    }

    override func mouseMoved(with event: NSEvent) {
        guard tracksLocation else {
            return
        }
        session?.handleWindowMouseMoved(locationInWindow: event.locationInWindow)
    }

    override func mouseExited(with event: NSEvent) {
        guard tracksLocation else {
            return
        }
        session?.reportLocation(nil)
    }
}

private struct PointerHoverProbe: NSViewRepresentable {
    let session: PointerHoverSession
    var tracksLocation = false

    func makeNSView(context: Context) -> PointerHoverProbeView {
        let view = PointerHoverProbeView()
        view.session = session
        view.tracksLocation = tracksLocation
        session.probeView = view
        return view
    }

    func updateNSView(_ nsView: PointerHoverProbeView, context: Context) {
        nsView.session = session
        nsView.tracksLocation = tracksLocation
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
            session.registry = interfaceLayers
            session.layer = layerContext.layer
            session.initializeIfNeeded(isFrozen: isFrozen)
        }()
        content
            .background(PointerHoverProbe(session: session))
            .onAppear {
                session.action = action
                session.registry = interfaceLayers
                session.layer = layerContext.layer
                session.setFrozen(effectiveIsFrozen)
                session.syncScrollListener()
            }
            .onHover { isHovered in
                session.action = action
                session.registry = interfaceLayers
                session.layer = layerContext.layer
                session.isFrozen = effectiveIsFrozen
                session.report(isHovered)
            }
            .onChange(of: layerContext.isFrozen) { isFrozen in
                session.action = action
                session.registry = interfaceLayers
                session.layer = layerContext.layer
                session.setFrozen(interfaceLayers?.isFrozen(layerContext.layer) ?? isFrozen)
            }
            .onDisappear {
                session.unregisterScrollListener()
            }
    }
}

private struct PointerHoverLocationModifier: ViewModifier {
    let action: (CGPoint?) -> Void
    @Environment(\.interfaceLayers) private var interfaceLayers
    @Environment(\.interfaceLayerContext) private var layerContext
    @StateObject private var session = PointerHoverSession()

    private var effectiveIsFrozen: Bool {
        interfaceLayers?.isFrozen(layerContext.layer) ?? layerContext.isFrozen
    }

    func body(content: Content) -> some View {
        let isFrozen = effectiveIsFrozen
        let _ = {
            session.tracksLocation = true
            session.locationAction = action
            session.registry = interfaceLayers
            session.layer = layerContext.layer
            session.initializeIfNeeded(isFrozen: isFrozen)
        }()
        content
            .background(PointerHoverProbe(session: session, tracksLocation: true))
            .onAppear {
                session.tracksLocation = true
                session.locationAction = action
                session.registry = interfaceLayers
                session.layer = layerContext.layer
                session.setFrozen(effectiveIsFrozen)
                session.syncScrollListener()
            }
            .onChange(of: layerContext.isFrozen) { isFrozen in
                session.tracksLocation = true
                session.locationAction = action
                session.registry = interfaceLayers
                session.layer = layerContext.layer
                session.setFrozen(interfaceLayers?.isFrozen(layerContext.layer) ?? isFrozen)
            }
            .onDisappear {
                session.unregisterScrollListener()
            }
    }
}
