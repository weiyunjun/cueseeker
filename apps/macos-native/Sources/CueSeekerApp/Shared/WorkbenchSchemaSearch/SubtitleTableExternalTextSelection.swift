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
                self.session = session
            }
            self.startPolicy = startPolicy
            if startPolicy.isBlocked {
                session.cancel()
            }
            installEventMonitorIfNeeded()
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if window == nil {
                session?.cancel()
                removeEventMonitor()
            } else {
                installEventMonitorIfNeeded()
            }
        }

        func tearDown() {
            session?.cancel()
            session = nil
            removeEventMonitor()
        }

        func routeForTesting(_ event: NSEvent) {
            route(event)
        }

        func startContextForTesting(
            atWindowPoint point: CGPoint
        ) -> SubtitleTableExternalTextSelectionStartContext? {
            startContext(atWindowPoint: point)
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
                    self?.route(event)
                }
                return event
            }
        }

        private func removeEventMonitor() {
            guard let eventMonitor else {
                return
            }
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }

        private func route(_ event: NSEvent) {
            guard let session else {
                return
            }
            if event.type == .leftMouseDown {
                session.cancel()
            }
            guard event.window === window else { return }

            switch event.type {
            case .leftMouseDown:
                guard let context = startContext(atWindowPoint: event.locationInWindow),
                      startPolicy.allowsStart(context)
                else {
                    return
                }
                _ = session.arm(startWindowPoint: event.locationInWindow)
            case .leftMouseDragged:
                _ = session.drag(windowPoint: event.locationInWindow)
            case .leftMouseUp:
                _ = session.end(windowPoint: event.locationInWindow)
            default:
                break
            }
        }

        private func startContext(
            atWindowPoint point: CGPoint
        ) -> SubtitleTableExternalTextSelectionStartContext? {
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

            return SubtitleTableExternalTextSelectionStartContext(
                isInsideWindowContent: contentFrame.contains(point),
                isInsideTable: session?.targetWindowRect?.contains(point) == true,
                isInteractive: SubtitleTableTextSelectionHitTesting.isInteractive(
                    hitView,
                    atWindowPoint: point,
                    in: contentView
                )
            )
        }
    }
}
