import AppKit
import Foundation
import SwiftUI

extension Notification.Name {
    static let cueSeekerScrollDebounceSettled = Notification.Name(
        "CueSeekerScrollDebounceSettled"
    )
    static let cueSeekerHoverSuppressed = Notification.Name(
        "CueSeekerHoverSuppressed"
    )
}

/// Coordinates the 300ms scroll-end debounce and cursor visibility state for
/// pointer hover and pointer shape updates across the App.
@MainActor
final class PointerHoverScrollState: ObservableObject {
    static let shared = PointerHoverScrollState()
    static let debounceNanoseconds: UInt64 = 300_000_000
    static let wakeMovementThreshold: CGFloat = 0.5

    @Published private(set) var isScrolling = false
    @Published private(set) var isCursorHidden = false
    @Published private(set) var isSuppressedByKeyboardOrController = false
    private var suppressedOriginScreenLocation: CGPoint?
    private var isWorkbenchTransitionTrackingActive = false
    private var pendingWorkbenchTransitionRevision: UInt64 = 0
    private var completedWorkbenchTransitionRevision: UInt64 = 0
    private var debounceTask: Task<Void, Never>?
    private var activeHoverListeners: [UUID: () -> Void] = [:]
    nonisolated(unsafe) private var focusObserverTokens: [NSObjectProtocol] = []

    init() {
        let center = NotificationCenter.default
        for name in [
            NSApplication.didBecomeActiveNotification,
            NSWindow.didBecomeKeyNotification,
        ] {
            let token = center.addObserver(
                forName: name,
                object: nil,
                queue: .main
            ) { notification in
                MainActor.assumeIsolated {
                    let window = notification.object as? NSWindow
                    PointerHoverSession.syncWindowFocusChanged(in: window)
                    if NSApp?.isActive == true {
                        AppPointerShape.reevaluate()
                    }
                }
            }
            focusObserverTokens.append(token)
        }
    }

    var isHoverSuppressed: Bool {
        isScrolling || isSuppressedByKeyboardOrController
    }

    var isAwaitingWorkbenchTransitionPresentation: Bool {
        isWorkbenchTransitionTrackingActive
            && pendingWorkbenchTransitionRevision != completedWorkbenchTransitionRevision
    }

    func setWorkbenchTransitionTrackingActive(_ isActive: Bool) {
        isWorkbenchTransitionTrackingActive = isActive
        if !isActive {
            completedWorkbenchTransitionRevision = pendingWorkbenchTransitionRevision
        }
    }

    @discardableResult
    func beginWorkbenchTransitionSuppression() -> UInt64 {
        suppressHoverUntilMouseMoves(clearsFrozenHover: true)
        guard isWorkbenchTransitionTrackingActive else {
            return completedWorkbenchTransitionRevision
        }
        pendingWorkbenchTransitionRevision &+= 1
        return pendingWorkbenchTransitionRevision
    }

    func completeWorkbenchTransitionSuppression(through revision: UInt64) {
        guard isWorkbenchTransitionTrackingActive,
              revision > completedWorkbenchTransitionRevision
        else {
            return
        }
        completedWorkbenchTransitionRevision = min(revision, pendingWorkbenchTransitionRevision)
        if !isAwaitingWorkbenchTransitionPresentation, isSuppressedByKeyboardOrController {
            suppressedOriginScreenLocation = NSEvent.mouseLocation
        }
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
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: Self.debounceNanoseconds)
            guard !Task.isCancelled else {
                return
            }
            self?.settleScroll()
        }
    }

    static func hasMovedAtLeastWakeThreshold(from origin: CGPoint, to current: CGPoint) -> Bool {
        hypot(current.x - origin.x, current.y - origin.y) >= wakeMovementThreshold
    }

    func suppressHoverUntilMouseMoves(clearsFrozenHover: Bool = false) {
        suppressedOriginScreenLocation = NSEvent.mouseLocation
        let didChange = !isSuppressedByKeyboardOrController
        if didChange {
            isSuppressedByKeyboardOrController = true
        }
        if clearsFrozenHover {
            PointerHoverSession.broadcastClearHoverForInterfaceSwitch()
        }
        if didChange {
            notifyActiveHoverListeners()
        }
        CardHighlightModel.broadcastSelectionMovedByKeyboardOrController(
            clearsFrozenHover: clearsFrozenHover
        )
        MenuHighlightModel.broadcastSelectionMovedByKeyboardOrController()
        AppPointerShape.noteKeyboardOrControllerSuppressedHover()
        TooltipCenter.shared.hideImmediately()
        NotificationCenter.default.post(
            name: .cueSeekerHoverSuppressed,
            object: nil,
            userInfo: clearsFrozenHover ? ["clearsFrozenHover": true] : nil
        )
    }

    func clearSuppressionForOverlayClose(recalculate: Bool = true) {
        suppressedOriginScreenLocation = nil
        completedWorkbenchTransitionRevision = pendingWorkbenchTransitionRevision
        var didChange = false
        if isSuppressedByKeyboardOrController {
            isSuppressedByKeyboardOrController = false
            didChange = true
        }
        let didUnsuppressCards = CardHighlightModel.broadcastClearKeyboardSuppression()
        let didUnsuppressMenus = MenuHighlightModel.broadcastClearKeyboardSuppression()
        if didChange {
            notifyActiveHoverListeners()
        }
        if recalculate, !isScrolling, !isCursorHidden {
            recalculateHoverState(
                postNotification: true,
                recheckCardsAndMenus: didUnsuppressCards || didUnsuppressMenus
            )
        }
    }

    func noteSelectionMovedByKeyboardOrController() {
        suppressHoverUntilMouseMoves()
    }

    @discardableResult
    func notePointerMoved(atScreenLocation screenLocation: CGPoint? = nil) -> Bool {
        if let screenLocation, isSuppressedByKeyboardOrController {
            if isAwaitingWorkbenchTransitionPresentation {
                suppressedOriginScreenLocation = screenLocation
                return false
            }
            if let origin = suppressedOriginScreenLocation,
               !Self.hasMovedAtLeastWakeThreshold(from: origin, to: screenLocation)
            {
                MenuHighlightModel.broadcastPointerMoved(atScreenLocation: screenLocation)
                return false
            }
        }
        let wasSuppressed = isSuppressedByKeyboardOrController
        let wasScrolling = isScrolling
        debounceTask?.cancel()
        debounceTask = nil
        var didChange = false
        if isScrolling {
            isScrolling = false
            didChange = true
        }
        if isSuppressedByKeyboardOrController {
            isSuppressedByKeyboardOrController = false
            suppressedOriginScreenLocation = nil
            didChange = true
        }
        if didChange {
            notifyActiveHoverListeners()
        }
        if wasSuppressed || wasScrolling {
            PointerHoverSession.syncScrollSettled()
        }
        let didWakeMenu = MenuHighlightModel.broadcastPointerMoved(atScreenLocation: screenLocation)
        CardHighlightModel.broadcastPointerMoved()
        if wasSuppressed || wasScrolling || didWakeMenu {
            recalculateHoverState(
                postNotification: wasSuppressed || wasScrolling,
                recheckCardsAndMenus: false
            )
        }
        return !isSuppressedByKeyboardOrController
    }

    private func recalculateHoverState(
        postNotification: Bool,
        recheckCardsAndMenus: Bool
    ) {
        if recheckCardsAndMenus {
            CardHighlightModel.broadcastPointerMoved()
            MenuHighlightModel.broadcastPointerMoved()
        }
        PointerHoverSession.syncScrollSettled()
        if postNotification {
            NotificationCenter.default.post(
                name: .cueSeekerScrollDebounceSettled,
                object: nil
            )
        }
        if NSApp?.isActive == true {
            AppPointerShape.reevaluate()
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
        PointerHoverSession.syncScrollSettled()
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

    func syncAfterMouseButtonReleased(atScreenLocation screenLocation: CGPoint) {
        guard !isCursorHidden else {
            return
        }
        if isHoverSuppressed {
            guard !isScrolling,
                  !isAwaitingWorkbenchTransitionPresentation,
                  let origin = suppressedOriginScreenLocation,
                  Self.hasMovedAtLeastWakeThreshold(from: origin, to: screenLocation)
            else {
                return
            }
            _ = notePointerMoved(atScreenLocation: screenLocation)
            return
        }
        recalculateHoverState(
            postNotification: true,
            recheckCardsAndMenus: false
        )
    }

    func resetForTesting() {
        debounceTask?.cancel()
        debounceTask = nil
        suppressedOriginScreenLocation = nil
        isWorkbenchTransitionTrackingActive = false
        pendingWorkbenchTransitionRevision = 0
        completedWorkbenchTransitionRevision = 0
        isScrolling = false
        isSuppressedByKeyboardOrController = false
        isCursorHidden = AppCursorVisibility.isCursorHidden
    }
}

/// Hover for a visual effect, reported only while the surface's layer owns
/// input, the cursor is visible, and scroll debounce is not active.
extension View {
    func onPointerHover(
        showsHand: Bool = false,
        ignoresLayerFreeze: Bool = false,
        _ action: @escaping (Bool) -> Void
    ) -> some View {
        modifier(PointerHoverModifier(
            showsHand: showsHand,
            ignoresLayerFreeze: ignoresLayerFreeze,
            action: action
        ))
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
    private(set) var deliveredIsHovered = false

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

    static func syncFrozenStates(in registry: InterfaceLayerRegistry) {
        registeredSessions = registeredSessions.filter { $0.value.value != nil }
        for box in registeredSessions.values {
            guard let session = box.value,
                  session.registry === registry || (!session.ignoresLayerFreeze && session.registry == nil)
            else {
                continue
            }
            let frozen = session.ignoresLayerFreeze
                ? registry.isCovered(session.layer)
                : registry.isFrozen(session.layer)
            session.setFrozen(frozen)
        }
    }

    static func resyncHoverForMenuRelay(
        on layer: InterfaceLayer,
        in registry: InterfaceLayerRegistry? = nil
    ) {
        registeredSessions = registeredSessions.filter { $0.value.value != nil }
        for box in registeredSessions.values {
            guard let session = box.value,
                  (registry == nil || session.registry == nil || session.registry === registry),
                  session.layer == layer
            else {
                continue
            }
            let remainedFrozen = session.isFrozen
            if remainedFrozen {
                session.setFrozen(false)
                session.setFrozen(true)
            } else {
                session.handleStateChanged()
            }
        }
    }

    static func broadcastClearHoverForInterfaceSwitch() {
        registeredSessions = registeredSessions.filter { $0.value.value != nil }
        for box in registeredSessions.values {
            box.value?.clearHoverForInterfaceSwitch()
        }
    }

    static func syncScrollSettled() {
        registeredSessions = registeredSessions.filter { $0.value.value != nil }
        for box in registeredSessions.values {
            guard let session = box.value,
                  !session.isFrozen,
                  session.probeView?.window != nil
            else {
                continue
            }
            session.handleStateChanged()
        }
    }

    static func syncWindowFocusChanged(in window: NSWindow? = nil) {
        registeredSessions = registeredSessions.filter { $0.value.value != nil }
        for box in registeredSessions.values {
            guard let session = box.value else {
                continue
            }
            if let window,
               let sessionWindow = session.probeView?.window,
               sessionWindow !== window {
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
    var ignoresLayerFreeze = false
    var tracksLocation = false
    var showsHand = false
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
        let showsHand = self.showsHand
        let key = ObjectIdentifier(self)
        if Thread.isMainThread {
            MainActor.assumeIsolated {
                Self.registeredSessions.removeValue(forKey: key)
                PointerHoverScrollState.shared.setActiveHoverListener(id: id, listener: nil)
                if showsHand {
                    AppPointerShape.noteCardHover(
                        false,
                        id: id.uuidString,
                        showsHand: true,
                        followsPointer: false
                    )
                }
            }
        } else {
            Task { @MainActor in
                Self.registeredSessions.removeValue(forKey: key)
                PointerHoverScrollState.shared.setActiveHoverListener(id: id, listener: nil)
                if showsHand {
                    AppPointerShape.noteCardHover(
                        false,
                        id: id.uuidString,
                        showsHand: true,
                        followsPointer: false
                    )
                }
            }
        }
    }

    private func syncPointerHandShape(_ isHovered: Bool, followsPointer: Bool) {
        guard showsHand else {
            return
        }
        AppPointerShape.noteCardHover(
            isHovered,
            id: id.uuidString,
            showsHand: true,
            followsPointer: followsPointer
        )
    }

    func clearPointerHandShape() {
        guard showsHand else {
            return
        }
        AppPointerShape.noteCardHover(
            false,
            id: id.uuidString,
            showsHand: true,
            followsPointer: false
        )
    }

    func handleProbeBoundsChanged() {
        guard gate.hasActiveHover else {
            return
        }
        handleStateChanged()
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
        if isFrozen {
            clearPointerHandShape()
        }
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
            let isCursorHidden = AppCursorVisibility.isCursorHidden
            if let probe = probeView as? PointerHoverProbeView {
                probe.setAssumesMouseInside(pointerInside)
            }
            let canFollowPointer = !scrollState.isScrolling
                && !scrollState.isSuppressedByKeyboardOrController
                && !isCursorHidden
            if !scrollState.isSuppressedByKeyboardOrController {
                syncPointerHandShape(pointerInside, followsPointer: canFollowPointer)
            }
            let delivered = gate.report(
                pointerInside,
                isFrozen: false,
                isScrolling: scrollState.isScrolling,
                isCursorHidden: isCursorHidden,
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
        if !tracksLocation,
           !isFrozen,
           probeView?.window != nil,
           (NSEvent.pressedMouseButtons & 0b11) != 0
        {
            return
        }
        if !isHovered, let probe = probeView as? PointerHoverProbeView {
            probe.setAssumesMouseInside(false)
        }
        let scrollState = PointerHoverScrollState.shared
        let isCursorHidden = AppCursorVisibility.isCursorHidden
        let followsPointer = !isFrozen
            && !scrollState.isScrolling
            && !scrollState.isSuppressedByKeyboardOrController
            && !isCursorHidden
        if !isFrozen, !scrollState.isSuppressedByKeyboardOrController {
            syncPointerHandShape(isHovered, followsPointer: followsPointer)
        }
        let delivered = gate.report(
            isHovered,
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
              probeView.window != nil,
              !probeView.isHiddenOrHasHiddenAncestor,
              probeView.bounds.width > 0,
              probeView.bounds.height > 0
        else {
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
           let pointerInside = currentPointerInsideView() {
            if let probe = probeView as? PointerHoverProbeView {
                probe.setAssumesMouseInside(pointerInside)
            }
            syncPointerHandShape(pointerInside, followsPointer: true)
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
        if isFrozen || scrollState.isSuppressedByKeyboardOrController || isCursorHidden {
            syncPointerHandShape(false, followsPointer: !isFrozen && !isCursorHidden)
        } else if let delivered, !scrollState.isScrolling {
            syncPointerHandShape(delivered, followsPointer: true)
        }
        syncScrollListener()
        if let delivered {
            action?(delivered)
        }
    }

    func clearHoverForInterfaceSwitch() {
        clearPointerHandShape()
        if tracksLocation {
            let hadDelivered = locationGate.freezeChanged(
                isFrozen: false,
                isScrolling: false,
                isCursorHidden: AppCursorVisibility.isCursorHidden,
                isSuppressedByKeyboard: true
            )
            _ = locationGate.report(
                nil,
                isFrozen: isFrozen,
                isScrolling: PointerHoverScrollState.shared.isScrolling,
                isCursorHidden: AppCursorVisibility.isCursorHidden,
                isSuppressedByKeyboard: true
            )
            syncScrollListener()
            if let hadDelivered {
                locationAction?(hadDelivered)
            }
            return
        }
        if let probe = probeView as? PointerHoverProbeView {
            probe.setAssumesMouseInside(false)
        }
        let hadDelivered = gate.freezeChanged(
            isFrozen: false,
            isScrolling: false,
            isCursorHidden: AppCursorVisibility.isCursorHidden,
            isSuppressedByKeyboard: true
        )
        _ = gate.report(
            false,
            isFrozen: isFrozen,
            isScrolling: PointerHoverScrollState.shared.isScrolling,
            isCursorHidden: AppCursorVisibility.isCursorHidden,
            isSuppressedByKeyboard: true
        )
        syncScrollListener()
        if let hadDelivered {
            action?(hadDelivered)
        }
    }

    func handleViewDisappeared() {
        if let probe = probeView as? PointerHoverProbeView {
            probe.setAssumesMouseInside(false)
        }
        let hadDeliveredHover = !tracksLocation && gate.deliveredIsHovered
        gate = PointerHoverGate()
        unregisterScrollListener()
        if hadDeliveredHover {
            action?(false)
        }
    }

    func unregisterScrollListener() {
        clearPointerHandShape()
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
        guard NSWindow.windowNumber(
            at: NSEvent.mouseLocation,
            belowWindowWithWindowNumber: 0
        ) == window.windowNumber else {
            return .outside
        }
        let locationInWindow = window.mouseLocationOutsideOfEventStream
        let localPoint = probeView.convert(locationInWindow, from: nil)
        let visibleBounds = probeView.bounds.intersection(probeView.visibleRect)
        guard !visibleBounds.isEmpty && visibleBounds.contains(localPoint) else {
            return .outside
        }
        return .inside(localPoint)
    }
}

final class PointerHoverProbeView: NSView {
    weak var session: PointerHoverSession?
    private(set) var assumesMouseInside = false
    var tracksLocation = false {
        didSet {
            if oldValue != tracksLocation {
                updateTrackingAreas()
            }
        }
    }

    func setAssumesMouseInside(_ value: Bool) {
        guard assumesMouseInside != value else {
            return
        }
        assumesMouseInside = value
        updateTrackingAreas()
    }

    override var isFlipped: Bool {
        true
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    override func setFrameSize(_ newSize: NSSize) {
        let oldSize = frame.size
        super.setFrameSize(newSize)
        if oldSize != newSize, session?.showsHand == true {
            session?.handleProbeBoundsChanged()
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        var options: NSTrackingArea.Options = [
            .mouseEnteredAndExited,
            .activeAlways,
            .inVisibleRect,
        ]
        if tracksLocation {
            options.insert(.mouseMoved)
        }
        if assumesMouseInside {
            options.insert(.assumeInside)
        }
        addTrackingArea(
            NSTrackingArea(
                rect: .zero,
                options: options,
                owner: self,
                userInfo: nil
            )
        )
    }

    override func mouseEntered(with event: NSEvent) {
        if tracksLocation {
            session?.handleWindowMouseMoved(locationInWindow: event.locationInWindow)
            return
        }
        setAssumesMouseInside(true)
        session?.report(true)
    }

    override func mouseMoved(with event: NSEvent) {
        guard tracksLocation else {
            return
        }
        session?.handleWindowMouseMoved(locationInWindow: event.locationInWindow)
    }

    override func mouseExited(with event: NSEvent) {
        setAssumesMouseInside(false)
        if tracksLocation {
            session?.reportLocation(nil)
        } else {
            session?.report(false)
        }
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
    var showsHand = false
    var ignoresLayerFreeze = false
    let action: (Bool) -> Void
    @Environment(\.interfaceLayers) private var interfaceLayers
    @Environment(\.interfaceLayerContext) private var layerContext
    @StateObject private var session = PointerHoverSession()

    private var observedLayerFreeze: Bool {
        ignoresLayerFreeze ? layerContext.isCovered : layerContext.isFrozen
    }

    private var effectiveIsFrozen: Bool {
        if ignoresLayerFreeze {
            return interfaceLayers?.isCovered(layerContext.layer) ?? layerContext.isCovered
        }
        return interfaceLayers?.isFrozen(layerContext.layer) ?? layerContext.isFrozen
    }

    func body(content: Content) -> some View {
        let isFrozen = effectiveIsFrozen
        let _ = {
            session.showsHand = showsHand
            session.ignoresLayerFreeze = ignoresLayerFreeze
            session.action = action
            session.registry = interfaceLayers
            session.layer = layerContext.layer
            session.initializeIfNeeded(isFrozen: isFrozen)
        }()
        content
            .background(PointerHoverProbe(session: session))
            .onAppear {
                session.showsHand = showsHand
                session.ignoresLayerFreeze = ignoresLayerFreeze
                session.action = action
                session.registry = interfaceLayers
                session.layer = layerContext.layer
                session.setFrozen(effectiveIsFrozen)
                session.syncScrollListener()
            }
            .onChange(of: observedLayerFreeze) { isFrozen in
                session.showsHand = showsHand
                session.ignoresLayerFreeze = ignoresLayerFreeze
                session.action = action
                session.registry = interfaceLayers
                session.layer = layerContext.layer
                let resolved = ignoresLayerFreeze
                    ? (interfaceLayers?.isCovered(layerContext.layer) ?? isFrozen)
                    : (interfaceLayers?.isFrozen(layerContext.layer) ?? isFrozen)
                session.setFrozen(resolved)
            }
            .onChange(of: showsHand) { newShowsHand in
                session.showsHand = newShowsHand
                if !newShowsHand {
                    AppPointerShape.noteCardHover(
                        false,
                        id: session.id.uuidString,
                        showsHand: true,
                        followsPointer: false
                    )
                }
            }
            .onDisappear {
                session.handleViewDisappeared()
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
                session.handleViewDisappeared()
            }
    }
}
