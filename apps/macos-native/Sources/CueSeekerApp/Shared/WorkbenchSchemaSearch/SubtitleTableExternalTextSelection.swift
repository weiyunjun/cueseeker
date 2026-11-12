import AppKit
import SwiftUI

@MainActor
protocol SubtitleTableExternalTextSelectionTarget: AnyObject {
    var externalTextSelectionWindowRect: CGRect? { get }
    var canBeginExternalTextSelection: Bool { get }

    func beginExternalTextSelection(
        startWindowPoint: CGPoint,
        currentWindowPoint: CGPoint
    ) -> Bool
    func updateExternalTextSelection(windowPoint: CGPoint) -> Bool
    func endExternalTextSelection(windowPoint: CGPoint) -> Bool
    func cancelExternalTextSelection()
}

@MainActor
final class SubtitleTableExternalTextSelectionSession: ObservableObject {
    private static let dragThreshold: CGFloat = 3

    enum Phase: Equatable {
        case idle
        case armed
        case selecting
    }

    private(set) var phase: Phase = .idle
    private weak var target: (any SubtitleTableExternalTextSelectionTarget)?
    private var targetIdentity: ObjectIdentifier?
    private var startWindowPoint: CGPoint?

    var targetWindowRect: CGRect? {
        validTargetWindowRect
    }

    func bind(_ target: any SubtitleTableExternalTextSelectionTarget) {
        let identity = ObjectIdentifier(target)
        guard self.target == nil || targetIdentity != identity else {
            return
        }

        cancel()
        self.target = target
        targetIdentity = identity
    }

    func unbind(_ target: any SubtitleTableExternalTextSelectionTarget) {
        guard targetIdentity == ObjectIdentifier(target) else {
            return
        }

        cancel()
        self.target = nil
        targetIdentity = nil
    }

    @discardableResult
    func arm(startWindowPoint: CGPoint) -> Bool {
        cancel()
        guard target?.canBeginExternalTextSelection == true,
              validTargetWindowRect != nil
        else {
            return false
        }

        self.startWindowPoint = startWindowPoint
        phase = .armed
        return true
    }

    @discardableResult
    func drag(windowPoint: CGPoint) -> Bool {
        if WorkbenchStaticTextSelectionCoordinator.shared.isDraggingSelection {
            reset()
            return false
        }
        guard let target else {
            reset()
            return false
        }

        switch phase {
        case .idle:
            return false
        case .armed:
            guard target.canBeginExternalTextSelection,
                  let targetWindowRect = validTargetWindowRect,
                  targetWindowRect.contains(windowPoint),
                  let startWindowPoint,
                  hypot(
                      windowPoint.x - startWindowPoint.x,
                      windowPoint.y - startWindowPoint.y
                  ) >= Self.dragThreshold
            else {
                if !target.canBeginExternalTextSelection || validTargetWindowRect == nil {
                    reset()
                }
                return false
            }

            guard target.beginExternalTextSelection(
                startWindowPoint: startWindowPoint,
                currentWindowPoint: windowPoint
            ) else {
                return false
            }
            phase = .selecting
            return true
        case .selecting:
            guard target.updateExternalTextSelection(windowPoint: windowPoint) else {
                target.cancelExternalTextSelection()
                reset()
                return false
            }
            return true
        }
    }

    @discardableResult
    func end(windowPoint: CGPoint) -> Bool {
        guard phase == .selecting, let target else {
            reset()
            return false
        }

        let handled = target.endExternalTextSelection(windowPoint: windowPoint)
        if !handled {
            target.cancelExternalTextSelection()
        }
        reset()
        return handled
    }

    func cancel() {
        if phase == .selecting {
            target?.cancelExternalTextSelection()
        }
        reset()
    }

    private var validTargetWindowRect: CGRect? {
        guard let rect = target?.externalTextSelectionWindowRect,
              rect.width > 0,
              rect.height > 0,
              !rect.isNull,
              !rect.isInfinite
        else {
            return nil
        }
        return rect
    }

    private func reset() {
        phase = .idle
        startWindowPoint = nil
    }
}

private struct SubtitleTableExternalTextSelectionSessionKey: EnvironmentKey {
    static let defaultValue: SubtitleTableExternalTextSelectionSession? = nil
}

extension EnvironmentValues {
    var subtitleTableExternalTextSelectionSession: SubtitleTableExternalTextSelectionSession? {
        get { self[SubtitleTableExternalTextSelectionSessionKey.self] }
        set { self[SubtitleTableExternalTextSelectionSessionKey.self] = newValue }
    }
}

@MainActor
protocol SubtitleTableTextSelectionInteractiveView: AnyObject {
    var subtitleTableTextSelectionInteraction: SubtitleTableTextSelectionInteraction { get }
}

enum SubtitleTableTextSelectionInteraction {
    case interactive
    case nonInteractive
}

extension SubtitleTableTextSelectionInteractiveView {
    var subtitleTableTextSelectionInteraction: SubtitleTableTextSelectionInteraction {
        .interactive
    }
}

@MainActor
final class SubtitleTableTextSelectionInteractiveRegionView: NSView,
    SubtitleTableTextSelectionInteractiveView
{
    var isActive = true
    var cornerRadius: CGFloat = 0

    var subtitleTableTextSelectionInteraction: SubtitleTableTextSelectionInteraction {
        isActive ? .interactive : .nonInteractive
    }

    func contains(windowPoint: CGPoint) -> Bool {
        let localPoint = convert(windowPoint, from: nil)
        guard bounds.contains(localPoint) else {
            return false
        }
        guard cornerRadius > 0 else {
            return true
        }
        let radius = min(cornerRadius, min(bounds.width / 2, bounds.height / 2))
        return RoundedRectangle(cornerRadius: radius, style: .continuous)
            .path(in: bounds)
            .contains(localPoint)
    }

    override func hitTest(_: NSPoint) -> NSView? {
        nil
    }
}

struct SubtitleTableTextSelectionInteractiveRegion: NSViewRepresentable {
    let isActive: Bool
    let cornerRadius: CGFloat

    func makeNSView(context _: Context) -> SubtitleTableTextSelectionInteractiveRegionView {
        let view = SubtitleTableTextSelectionInteractiveRegionView()
        view.isActive = isActive
        view.cornerRadius = cornerRadius
        return view
    }

    func updateNSView(
        _ nsView: SubtitleTableTextSelectionInteractiveRegionView,
        context _: Context
    ) {
        nsView.isActive = isActive
        nsView.cornerRadius = cornerRadius
    }
}

extension View {
    func subtitleTableTextSelectionInteractiveRegion(
        isActive: Bool = true,
        cornerRadius: CGFloat = 0
    ) -> some View {
        background(
            SubtitleTableTextSelectionInteractiveRegion(
                isActive: isActive,
                cornerRadius: cornerRadius
            )
                .allowsHitTesting(false)
        )
    }

    func subtitleTableTextSelectionNonInteractiveRegion(
        cornerRadius: CGFloat = 0
    ) -> some View {
        subtitleTableTextSelectionInteractiveRegion(
            isActive: false,
            cornerRadius: cornerRadius
        )
    }

    func cueSeekerNativeDragRegion(isActive: Bool = true) -> some View {
        background(
            CueSeekerNativeDragRegion(isActive: isActive)
                .allowsHitTesting(false)
        )
    }
}

@MainActor
final class CueSeekerNativeDragRegionView: NSView {
    var isActive = true

    func contains(windowPoint: CGPoint) -> Bool {
        guard isActive, window != nil else {
            return false
        }
        let localPoint = convert(windowPoint, from: nil)
        return bounds.contains(localPoint)
    }

    override func hitTest(_: NSPoint) -> NSView? {
        nil
    }
}

private struct CueSeekerNativeDragRegion: NSViewRepresentable {
    let isActive: Bool

    func makeNSView(context _: Context) -> CueSeekerNativeDragRegionView {
        let view = CueSeekerNativeDragRegionView()
        view.isActive = isActive
        return view
    }

    func updateNSView(_ nsView: CueSeekerNativeDragRegionView, context _: Context) {
        nsView.isActive = isActive
    }
}

@MainActor
enum SubtitleTableTextSelectionHitTesting {
    static func isInteractive(_ hitView: NSView?) -> Bool {
        var candidate = hitView
        while let view = candidate {
            if let control = view as? NSControl, control.isEnabled {
                return true
            }
            if let textView = view as? NSTextView,
               textView.isEditable || textView.isSelectable
            {
                return true
            }
            if let semanticView = view as? any SubtitleTableTextSelectionInteractiveView {
                return semanticView.subtitleTableTextSelectionInteraction == .interactive
            }
            if view is NSScroller {
                return true
            }
            candidate = view.superview
        }
        return false
    }

    static func isInteractive(
        _ hitView: NSView?,
        atWindowPoint point: CGPoint,
        in rootView: NSView
    ) -> Bool {
        if isInteractive(hitView) {
            return true
        }
        return topmostSemanticInteraction(
            atWindowPoint: point,
            in: rootView
        ) == .interactive
    }

    static func containsInteractiveRegion(
        atWindowPoint point: CGPoint,
        in rootView: NSView
    ) -> Bool {
        topmostSemanticInteraction(
            atWindowPoint: point,
            in: rootView
        ) == .interactive
    }

    static func ownsDragOrTextInputGesture(
        _ hitView: NSView?,
        atWindowPoint point: CGPoint,
        in window: NSWindow?
    ) -> Bool {
        if let window {
            for buttonType: NSWindow.ButtonType in [.closeButton, .miniaturizeButton, .zoomButton] {
                guard let button = window.standardWindowButton(buttonType),
                      !button.isHidden
                else {
                    continue
                }
                if hitView === button
                    || (hitView?.isDescendant(of: button) == true)
                    || button.convert(button.bounds, to: nil).contains(point)
                {
                    return true
                }
            }
        }

        var candidate = hitView
        while let view = candidate {
            if let draggable = view as? DraggableNSView, draggable.allowsHitTesting {
                return true
            }
            if let nativeDrag = view as? CueSeekerNativeDragRegionView, nativeDrag.isActive {
                return true
            }
            if let selectable = view as? WorkbenchSelectableTextNSView, selectable.canInteract {
                return true
            }
            if let overlay = view as? WorkbenchSingleLineContainerOverlayView,
               overlay.isEnabled,
               overlay.onPressRelease == nil
            {
                return true
            }
            if let textView = view as? NSTextView,
               textView.isEditable || textView.isSelectable
            {
                return true
            }
            if let textField = view as? NSTextField,
               textField.isEditable || textField.isSelectable
            {
                return true
            }
            if view is NSScroller
                || view is TableScrollbarOverlayView
                || view is NSSlider
            {
                return true
            }
            candidate = view.superview
        }

        if let rootView = window?.contentView,
           containsNativeDragRegion(atWindowPoint: point, in: rootView)
        {
            return true
        }
        return false
    }

    private static func containsNativeDragRegion(
        atWindowPoint point: CGPoint,
        in rootView: NSView
    ) -> Bool {
        guard rootView.window != nil,
              !rootView.isHiddenOrHasHiddenAncestor,
              rootView.alphaValue > 0,
              windowBounds(of: rootView).contains(point)
        else {
            return false
        }
        if let region = rootView as? CueSeekerNativeDragRegionView,
           region.contains(windowPoint: point)
        {
            return true
        }
        for subview in rootView.subviews.reversed() {
            if containsNativeDragRegion(atWindowPoint: point, in: subview) {
                return true
            }
        }
        return false
    }

    private static func topmostSemanticInteraction(
        atWindowPoint point: CGPoint,
        in rootView: NSView
    ) -> SubtitleTableTextSelectionInteraction? {
        guard rootView.window != nil,
              !rootView.isHiddenOrHasHiddenAncestor,
              rootView.alphaValue > 0,
              windowBounds(of: rootView).contains(point)
        else {
            return nil
        }

        for subview in rootView.subviews.reversed() {
            if let interaction = topmostSemanticInteraction(
                atWindowPoint: point,
                in: subview
            ) {
                return interaction
            }
        }

        guard let semanticView = rootView as? any SubtitleTableTextSelectionInteractiveView else {
            return nil
        }
        if let region = semanticView as? SubtitleTableTextSelectionInteractiveRegionView,
           !region.contains(windowPoint: point)
        {
            return nil
        }
        return semanticView.subtitleTableTextSelectionInteraction
    }

    private static func windowBounds(of view: NSView) -> CGRect {
        var rect = view.convert(view.bounds, to: nil).standardized
        var ancestor = view.superview
        while !rect.isNull, !rect.isEmpty, let current = ancestor {
            guard !current.isHidden, current.alphaValue > 0 else {
                return .null
            }
            rect = rect.intersection(
                current.convert(current.bounds, to: nil).standardized
            )
            ancestor = current.superview
        }
        return rect
    }
}

struct SubtitleTableExternalTextSelectionStartContext: Equatable {
    let isInsideWindowContent: Bool
    let isInsideTable: Bool
    let isInteractive: Bool
}

struct SubtitleTableExternalTextSelectionStartPolicy: Equatable {
    let isBlocked: Bool

    func allowsStart(_ context: SubtitleTableExternalTextSelectionStartContext) -> Bool {
        !isBlocked &&
            context.isInsideWindowContent &&
            !context.isInsideTable &&
            !context.isInteractive
    }
}

struct SubtitleTableExternalTextSelectionEventMonitor: NSViewRepresentable {
    let session: SubtitleTableExternalTextSelectionSession
    let startPolicy: SubtitleTableExternalTextSelectionStartPolicy

    func makeNSView(context _: Context) -> MonitoringView {
        MonitoringView()
    }

    func updateNSView(_ nsView: MonitoringView, context _: Context) {
        nsView.update(session: session, startPolicy: startPolicy)
    }

    static func dismantleNSView(_ nsView: MonitoringView, coordinator _: Void) {
        nsView.tearDown()
    }

    @MainActor
    final class MonitoringView: NSView {
        nonisolated(unsafe) private var eventMonitor: Any?
        private weak var session: SubtitleTableExternalTextSelectionSession?
        private weak var armedHitView: NSView?
        private weak var armedControl: NSControl?
        private var startPolicy = SubtitleTableExternalTextSelectionStartPolicy(
            isBlocked: true
        )

        override var isFlipped: Bool { true }

        func update(
            session: SubtitleTableExternalTextSelectionSession,
            startPolicy: SubtitleTableExternalTextSelectionStartPolicy
        ) {
            if self.session !== session {
                self.session?.cancel()
                clearArmedOrigin()
                self.session = session
            }
            self.startPolicy = startPolicy
            if startPolicy.isBlocked {
                session.cancel()
                clearArmedOrigin()
            }
            installEventMonitorIfNeeded()
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if window == nil {
                session?.cancel()
                clearArmedOrigin()
                removeEventMonitor()
            } else {
                installEventMonitorIfNeeded()
            }
        }

        func tearDown() {
            session?.cancel()
            clearArmedOrigin()
            session = nil
            removeEventMonitor()
        }

        @discardableResult
        func routeForTesting(_ event: NSEvent) -> NSEvent? {
            route(event)
        }

        func startContextForTesting(
            atWindowPoint point: CGPoint
        ) -> SubtitleTableExternalTextSelectionStartContext? {
            resolvedStartContext(atWindowPoint: point)?.context
        }

        deinit {
            if let eventMonitor {
                NSEvent.removeMonitor(eventMonitor)
            }
        }

        private func installEventMonitorIfNeeded() {
            guard window != nil, eventMonitor == nil else {
                return
            }
            eventMonitor = NSEvent.addLocalMonitorForEvents(
                matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp]
            ) { [weak self] event in
                MainActor.assumeIsolated {
                    guard let self else { return event }
                    return self.route(event)
                }
            }
        }

        private func removeEventMonitor() {
            guard let eventMonitor else {
                return
            }
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }

        private func clearArmedOrigin() {
            armedHitView = nil
            armedControl = nil
        }

        private func cancelArmedOriginatingControl(for triggerEvent: NSEvent) {
            NotificationCenter.default.post(
                name: .cueSeekerCancelControlPress,
                object: window
            )
            if let control = armedControl {
                control.cell?.isHighlighted = false
                control.needsDisplay = true
                return
            }
            guard let hitView = armedHitView else { return }
            let offscreen = CGPoint(x: -10_000, y: -10_000)
            if let dragEvent = Self.redirectedMouseEvent(
                from: triggerEvent,
                type: .leftMouseDragged,
                locationInWindow: offscreen
            ) {
                hitView.mouseDragged(with: dragEvent)
            }
            if let upEvent = Self.redirectedMouseEvent(
                from: triggerEvent,
                type: .leftMouseUp,
                locationInWindow: offscreen
            ) {
                hitView.mouseUp(with: upEvent)
            }
            armedHitView = nil
        }

        private static func enclosingControl(of hitView: NSView?) -> NSControl? {
            var candidate = hitView
            while let view = candidate {
                if let control = view as? NSControl, control.isEnabled {
                    return control
                }
                candidate = view.superview
            }
            return nil
        }

        private static func isHandledDirectlyByTableSurface(_ hitView: NSView?) -> Bool {
            var candidate = hitView
            while let view = candidate {
                if view is SubtitleVirtualTableDocumentView
                    || view is SubtitleTableHeaderTextOverlayView
                {
                    return true
                }
                candidate = view.superview
            }
            return false
        }

        private static func redirectedMouseEvent(
            from event: NSEvent,
            type: NSEvent.EventType,
            locationInWindow: CGPoint
        ) -> NSEvent? {
            NSEvent.mouseEvent(
                with: type,
                location: locationInWindow,
                modifierFlags: event.modifierFlags,
                timestamp: event.timestamp,
                windowNumber: event.windowNumber,
                context: nil,
                eventNumber: event.eventNumber,
                clickCount: 1,
                pressure: type == .leftMouseUp ? 0 : 1
            )
        }

        private func route(_ event: NSEvent) -> NSEvent? {
            guard let session else {
                return event
            }
            if event.type == .leftMouseDown {
                session.cancel()
                clearArmedOrigin()
            }
            guard event.window === window else { return event }

            switch event.type {
            case .leftMouseDown:
                guard let resolved = resolvedStartContext(atWindowPoint: event.locationInWindow),
                      startPolicy.allowsStart(resolved.context)
                else {
                    return event
                }
                if session.arm(startWindowPoint: event.locationInWindow) {
                    armedHitView = resolved.hitView
                    armedControl = Self.enclosingControl(of: resolved.hitView)
                }
                return event

            case .leftMouseDragged:
                let wasArmed = session.phase == .armed
                let handled = session.drag(windowPoint: event.locationInWindow)
                guard handled else {
                    return event
                }
                if wasArmed && session.phase == .selecting {
                    cancelArmedOriginatingControl(for: event)
                }
                PointerHoverScrollState.shared.notePointerMoved()
                if let window {
                    AppPointerShape.pointerMoved(in: window, at: event.locationInWindow)
                }
                if armedControl != nil {
                    return Self.redirectedMouseEvent(
                        from: event,
                        type: .leftMouseDragged,
                        locationInWindow: CGPoint(x: -10_000, y: -10_000)
                    ) ?? event
                }
                return nil

            case .leftMouseUp:
                let wasSelecting = session.phase == .selecting
                let hadArmedControl = armedControl != nil
                let handled = session.end(windowPoint: event.locationInWindow)
                clearArmedOrigin()
                guard wasSelecting || handled else {
                    return event
                }
                if let window {
                    AppPointerShape.pointerMoved(in: window, at: event.locationInWindow)
                }
                if hadArmedControl {
                    return Self.redirectedMouseEvent(
                        from: event,
                        type: .leftMouseUp,
                        locationInWindow: CGPoint(x: -10_000, y: -10_000)
                    )
                }
                return nil

            default:
                return event
            }
        }

        private func resolvedStartContext(
            atWindowPoint point: CGPoint
        ) -> (context: SubtitleTableExternalTextSelectionStartContext, hitView: NSView?)? {
            guard let window,
                  let contentView = window.contentView
            else {
                return nil
            }

            let contentFrame = contentView.convert(contentView.bounds, to: nil).standardized
            guard contentFrame.width > 0,
                  contentFrame.height > 0,
                  !contentFrame.isNull,
                  !contentFrame.isInfinite
            else {
                return nil
            }

            let hitTestPoint = contentView.superview?.convert(point, from: nil)
                ?? contentView.convert(point, from: nil)
            let hitView = contentView.hitTest(hitTestPoint)

            return (
                SubtitleTableExternalTextSelectionStartContext(
                    isInsideWindowContent: contentFrame.contains(point),
                    isInsideTable: session?.targetWindowRect?.contains(point) == true
                        || Self.isHandledDirectlyByTableSurface(hitView),
                    isInteractive: SubtitleTableTextSelectionHitTesting.ownsDragOrTextInputGesture(
                        hitView,
                        atWindowPoint: point,
                        in: window
                    )
                ),
                hitView
            )
        }
    }
}
