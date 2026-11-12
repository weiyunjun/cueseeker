import AppKit
import SwiftUI

enum WindowMouseEventDisposition {
    case passthrough
    case consume
    case redirect(NSEvent)
}

enum StaticTextFlowScope: Hashable {
    case menuModalPopover(windowNumber: Int)
    case dialog(windowNumber: Int, dialogID: WorkbenchDialogAccessibilityID?)
    case surface(windowNumber: Int, layer: InterfaceLayer)

    var windowNumber: Int {
        switch self {
        case .menuModalPopover(let wn), .dialog(let wn, _), .surface(let wn, _):
            return wn
        }
    }

    var priorityRank: Int {
        switch self {
        case .menuModalPopover:
            return 1_000
        case .dialog:
            return 500
        case .surface(_, let layer):
            return layer.rawValue
        }
    }
}

/// Global coordinator managing continuous static text flow selection within the active
/// UI scope, cross-control/blank-area drag entry, viewport edge auto-scrolling, clipboard
/// serialization (`\t` horizontal peers, `\n` vertical rows, full untruncated text on `...`),
/// and global single-selection mutual exclusion across the App.
@MainActor
final class WorkbenchStaticTextSelectionCoordinator: NSObject {
    static let shared = WorkbenchStaticTextSelectionCoordinator()
    private static let externalDragThreshold: CGFloat = 3.0
    private static let autoScrollInterval: TimeInterval = 1.0 / 30.0

    private final class WeakWindowRef {
        weak var window: CueSeekerWindow?
        init(_ window: CueSeekerWindow) {
            self.window = window
        }
    }

    private final class WeakViewRef {
        weak var view: NSView?
        init(_ view: NSView) {
            self.view = view
        }
    }

    private final class WeakSelectableViewRef {
        weak var view: WorkbenchSelectableTextNSView?
        init(_ view: WorkbenchSelectableTextNSView) {
            self.view = view
        }
    }

    private final class WeakControlRef {
        weak var control: NSControl?
        init(_ control: NSControl) {
            self.control = control
        }
    }

    struct FlowCursor {
        let view: WorkbenchSelectableTextNSView
        let utf16Offset: Int
    }

    struct FlowAnchor {
        let start: FlowCursor
        let end: FlowCursor
    }

    private struct FlowNode {
        let view: WorkbenchSelectableTextNSView
        let scrollContainerID: ObjectIdentifier?
        let containerTopY: CGFloat
        let innerSortMinY: CGFloat
        let innerSortMaxY: CGFloat
        let innerSortMinX: CGFloat
        let innerSortMaxX: CGFloat
        let visualBounds: CGRect
        let visibleVisualLineRects: [CGRect]

        var visibleMinX: CGFloat {
            visibleVisualLineRects.map(\.minX).min() ?? visualBounds.minX
        }

        var visibleMaxX: CGFloat {
            visibleVisualLineRects.map(\.maxX).max() ?? visualBounds.maxX
        }

        var visibleMinY: CGFloat {
            visibleVisualLineRects.map(\.minY).min() ?? visualBounds.minY
        }

        var visibleMaxY: CGFloat {
            visibleVisualLineRects.map(\.maxY).max() ?? visualBounds.maxY
        }
    }

    private struct FlowRowGroup {
        var nodes: [FlowNode]
        let scrollContainerID: ObjectIdentifier?
        var firstBandMinY: CGFloat
        var firstBandMaxY: CGFloat
        var minX: CGFloat
        var maxX: CGFloat
    }

    private struct VisibleFlowRow {
        let nodes: [FlowNode]
        let visibleMinY: CGFloat
        let visibleMaxY: CGFloat
    }

    private struct FlowSnapshot {
        let window: NSWindow
        let scope: StaticTextFlowScope
        let refHeight: CGFloat
        let rowGroups: [FlowRowGroup]
        let flatViews: [WorkbenchSelectableTextNSView]
        let visibleRows: [VisibleFlowRow]
    }

    private struct ExternalArmedSession {
        let window: WeakWindowRef
        let startWindowPoint: CGPoint
        var lastWindowPoint: CGPoint
        var armedHitView: WeakViewRef?
        var armedControl: WeakControlRef?
    }

    private struct ActiveFlowDragSession {
        let isExternalEntry: Bool
        let window: WeakWindowRef
        let scope: StaticTextFlowScope
        let startWindowPoint: CGPoint
        var latestWindowPoint: CGPoint
        let clickCount: Int
        let anchor: FlowAnchor
        var armedControl: WeakControlRef?
    }

    private var selectedViewRefs: [WeakSelectableViewRef] = []
    private var activeScope: StaticTextFlowScope?
    private weak var activeResponderView: WorkbenchSelectableTextNSView?
    private var externalArmedSession: ExternalArmedSession?
    private var activeDragSession: ActiveFlowDragSession?
    private var autoScrollTimer: Timer?

    var activeView: WorkbenchSelectableTextNSView? {
        if let activeResponderView, activeResponderView.window != nil {
            return activeResponderView
        }
        return liveSelectedViews.first
    }

    private var liveSelectedViews: [WorkbenchSelectableTextNSView] {
        selectedViewRefs.compactMap { ref in
            guard let view = ref.view, view.window != nil, view.hasSelection else {
                return nil
            }
            return view
        }
    }

    var hasSelection: Bool {
        liveSelectedViews.contains { $0.canInteract }
    }

    var selectedText: String? {
        let views = liveSelectedViews.filter(\.canInteract)
        guard let first = views.first else {
            return nil
        }
        return serializedSelectionText(in: first.window, fallbackViews: views)
    }

    var isDraggingSelection: Bool {
        if let activeDragSession,
           let window = activeDragSession.window.window,
           window.contentView != nil
        {
            return true
        }
        return false
    }

    var isDirectDragSelection: Bool {
        guard let activeDragSession, !activeDragSession.isExternalEntry else {
            return false
        }
        return activeDragSession.window.window != nil
    }

    var activeDraggingPointerShape: PointerShape? {
        isDraggingSelection ? .iBeam : nil
    }

    private override init() {
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleClearTextSelectionNotification(_:)),
            name: .cueSeekerClearTextSelection,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidResignActive(_:)),
            name: NSApplication.didResignActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWindowDidResignKey(_:)),
            name: NSWindow.didResignKeyNotification,
            object: nil
        )
    }

    func isResponderOwnedByActiveSelection(_ responder: NSResponder?) -> Bool {
        guard let view = responder as? WorkbenchSelectableTextNSView else {
            return false
        }
        if view === activeResponderView {
            return true
        }
        return selectedViewRefs.contains { $0.view === view }
    }

    func beginSingleNodeInteraction(in view: WorkbenchSelectableTextNSView) {
        stopAutoScroll()
        externalArmedSession = nil
        activeDragSession = nil
        clearSelectedViews(except: view)
        activeResponderView = view
        activeScope = view.flowScope
        selectedViewRefs = [WeakSelectableViewRef(view)]
        NotificationCenter.default.post(
            name: .cueSeekerClearTextSelection,
            object: view
        )
    }

    func clearSelection() {
        stopAutoScroll()
        externalArmedSession = nil
        activeDragSession = nil
        activeScope = nil
        let previousResponder = activeResponderView
        activeResponderView = nil
        let refs = selectedViewRefs
        selectedViewRefs.removeAll()
        for ref in refs {
            ref.view?.clearSelection(notifyCoordinator: false)
        }
        previousResponder?.clearSelection(notifyCoordinator: false)
    }

    func unregister(_ view: WorkbenchSelectableTextNSView) {
        selectedViewRefs.removeAll { $0.view == nil || $0.view === view }
        if activeResponderView === view {
            activeResponderView = liveSelectedViews.first
        }
        if selectedViewRefs.isEmpty, activeDragSession == nil {
            activeScope = nil
        }
    }

    // MARK: - Direct Node Mouse Tracking

    func prepareDirectMouseDown(
        in view: WorkbenchSelectableTextNSView,
        startWindowPoint: CGPoint,
        clickCount: Int,
        initialAnchorRange: NSRange?
    ) {
        stopAutoScroll()
        externalArmedSession = nil
        activeDragSession = nil
        clearSelectedViews(except: view)
        activeResponderView = view
        activeScope = view.flowScope
        NotificationCenter.default.post(
            name: .cueSeekerClearTextSelection,
            object: view
        )
        _ = view.window?.makeFirstResponder(view)

        if let initialAnchorRange, initialAnchorRange.length > 0 {
            selectedViewRefs = [WeakSelectableViewRef(view)]
            if clickCount >= 2,
               let window = view.window as? CueSeekerWindow,
               let scope = view.flowScope
            {
                let anchor = FlowAnchor(
                    start: FlowCursor(view: view, utf16Offset: initialAnchorRange.location),
                    end: FlowCursor(view: view, utf16Offset: NSMaxRange(initialAnchorRange))
                )
                activeDragSession = ActiveFlowDragSession(
                    isExternalEntry: false,
                    window: WeakWindowRef(window),
                    scope: scope,
                    startWindowPoint: startWindowPoint,
                    latestWindowPoint: startWindowPoint,
                    clickCount: clickCount,
                    anchor: anchor,
                    armedControl: nil
                )
            }
        } else {
            selectedViewRefs.removeAll()
        }
    }

    func updateDirectDrag(
        from originView: WorkbenchSelectableTextNSView,
        startWindowPoint: CGPoint,
        currentWindowPoint: CGPoint,
        clickCount: Int,
        initialAnchorRange: NSRange
    ) {
        guard let window = originView.window as? CueSeekerWindow,
              let scope = originView.flowScope,
              originView.canInteract
        else {
            clearSelection()
            return
        }

        guard let snapshot = buildFlowSnapshot(in: window, preferredScope: scope) else {
            clearSelection()
            return
        }

        if activeDragSession == nil {
            let anchor: FlowAnchor
            if clickCount >= 2 && originView.onTap == nil {
                anchor = FlowAnchor(
                    start: FlowCursor(view: originView, utf16Offset: initialAnchorRange.location),
                    end: FlowCursor(view: originView, utf16Offset: NSMaxRange(initialAnchorRange))
                )
            } else if let projectedStart = project(windowPoint: startWindowPoint, in: snapshot) {
                anchor = FlowAnchor(start: projectedStart, end: projectedStart)
            } else {
                let fallbackOffset = originView.utf16Offset(
                    at: originView.convert(startWindowPoint, from: nil)
                )
                let cursor = FlowCursor(view: originView, utf16Offset: fallbackOffset)
                anchor = FlowAnchor(start: cursor, end: cursor)
            }
            activeDragSession = ActiveFlowDragSession(
                isExternalEntry: false,
                window: WeakWindowRef(window),
                scope: scope,
                startWindowPoint: startWindowPoint,
                latestWindowPoint: currentWindowPoint,
                clickCount: originView.onTap == nil ? clickCount : 1,
                anchor: anchor,
                armedControl: nil
            )
        } else {
            activeDragSession?.latestWindowPoint = currentWindowPoint
        }

        guard let session = activeDragSession,
              let focus = project(windowPoint: currentWindowPoint, in: snapshot)
        else {
            return
        }

        applyFlowSelection(
            anchor: session.anchor,
            focus: focus,
            clickCount: session.clickCount,
            in: snapshot
        )
        updateAutoScrollState()
        AppPointerShape.pointerMoved(in: window, at: currentWindowPoint)
    }

    func endDirectDrag(
        from originView: WorkbenchSelectableTextNSView,
        currentWindowPoint: CGPoint
    ) {
        if let session = activeDragSession,
           let window = session.window.window,
           let snapshot = buildFlowSnapshot(in: window, preferredScope: session.scope),
           let focus = project(windowPoint: currentWindowPoint, in: snapshot)
        {
            applyFlowSelection(
                anchor: session.anchor,
                focus: focus,
                clickCount: session.clickCount,
                in: snapshot
            )
        }
        stopAutoScroll()
        activeDragSession = nil
        if let window = originView.window {
            AppPointerShape.pointerMoved(in: window, at: currentWindowPoint)
        }
        if !hasSelection {
            clearSelection()
        }
    }

    // MARK: - Window External Drag Entry & Control Cancellation

    func handleWindowLeftMouseDown(window: CueSeekerWindow, event: NSEvent) {
        let windowPoint = event.locationInWindow
        stopAutoScroll()
        externalArmedSession = nil
        activeDragSession = nil

        guard let contentView = window.contentView else {
            clearSelection()
            return
        }

        let contentFrame = contentView.convert(contentView.bounds, to: nil).standardized
        let hitView = contentView.superview?.hitTest(windowPoint)
            ?? contentView.hitTest(contentView.convert(windowPoint, from: nil))

        if let selectableHit = hitView as? WorkbenchSelectableTextNSView,
           selectableHit.canInteract
        {
            return
        }

        clearSelection()

        guard contentFrame.width > 0,
              contentFrame.height > 0,
              contentFrame.contains(windowPoint)
        else {
            return
        }

        if let mainWindow = window as? CueSeekerMainWindow,
           mainWindow.isFocusLocked(),
           !Self.hasInteractiveMenuModalSelectableTextView(in: contentView)
        {
            return
        }

        if Self.isInsideDedicatedTextSelectionSurface(hitView)
            || SubtitleTableActiveTextDragState.isDraggingSelection
        {
            return
        }

        if SubtitleTableTextSelectionHitTesting.ownsDragOrTextInputGesture(
            hitView,
            atWindowPoint: windowPoint,
            in: window
        ) {
            return
        }

        externalArmedSession = ExternalArmedSession(
            window: WeakWindowRef(window),
            startWindowPoint: windowPoint,
            lastWindowPoint: windowPoint,
            armedHitView: hitView.map(WeakViewRef.init),
            armedControl: Self.enclosingControl(of: hitView).map(WeakControlRef.init)
        )
    }

    func handleWindowLeftMouseDragged(
        window: CueSeekerWindow,
        event: NSEvent
    ) -> WindowMouseEventDisposition {
        let currentWindowPoint = event.locationInWindow

        if var dragSession = activeDragSession, dragSession.isExternalEntry {
            guard dragSession.window.window === window,
                  let snapshot = buildFlowSnapshot(in: window, preferredScope: dragSession.scope)
            else {
                clearSelection()
                return .passthrough
            }
            dragSession.latestWindowPoint = currentWindowPoint
            activeDragSession = dragSession

            if let focus = project(windowPoint: currentWindowPoint, in: snapshot) {
                applyFlowSelection(
                    anchor: dragSession.anchor,
                    focus: focus,
                    clickCount: 1,
                    in: snapshot
                )
            }
            updateAutoScrollState()
            AppPointerShape.pointerMoved(in: window, at: currentWindowPoint)
            if dragSession.armedControl?.control != nil,
               let redirected = Self.redirectedMouseEvent(
                   from: event,
                   type: .leftMouseDragged,
                   locationInWindow: CGPoint(x: -10_000, y: -10_000)
               )
            {
                return .redirect(redirected)
            }
            return .consume
        }

        guard var armed = externalArmedSession else {
            return .passthrough
        }
        guard armed.window.window === window,
              let contentView = window.contentView,
              !SubtitleTableActiveTextDragState.isDraggingSelection
        else {
            externalArmedSession = nil
            return .passthrough
        }

        let previousPoint = armed.lastWindowPoint
        armed.lastWindowPoint = currentWindowPoint
        externalArmedSession = armed

        guard hypot(
            currentWindowPoint.x - armed.startWindowPoint.x,
            currentWindowPoint.y - armed.startWindowPoint.y
        ) >= Self.externalDragThreshold else {
            return .passthrough
        }

        guard let snapshot = buildFlowSnapshot(in: window, preferredScope: nil),
              let hitView = Self.findHitSelectableTextView(
                  in: contentView,
                  allowedViews: Set(snapshot.flatViews.map(ObjectIdentifier.init)),
                  from: previousPoint,
                  to: currentWindowPoint
              ) ?? Self.findHitSelectableTextView(
                  in: contentView,
                  allowedViews: Set(snapshot.flatViews.map(ObjectIdentifier.init)),
                  from: armed.startWindowPoint,
                  to: currentWindowPoint
              ),
              let anchorPos = project(windowPoint: armed.startWindowPoint, in: snapshot),
              let focusPos = project(windowPoint: currentWindowPoint, in: snapshot),
              hasNonEmptyFlowSelection(from: anchorPos, to: focusPos, in: snapshot)
        else {
            return .passthrough
        }

        externalArmedSession = nil
        let anchor = FlowAnchor(start: anchorPos, end: anchorPos)
        activeScope = snapshot.scope
        activeResponderView = anchorPos.view
        NotificationCenter.default.post(
            name: .cueSeekerClearTextSelection,
            object: anchorPos.view
        )
        _ = window.makeFirstResponder(hitView)

        activeDragSession = ActiveFlowDragSession(
            isExternalEntry: true,
            window: armed.window,
            scope: snapshot.scope,
            startWindowPoint: armed.startWindowPoint,
            latestWindowPoint: currentWindowPoint,
            clickCount: 1,
            anchor: anchor,
            armedControl: armed.armedControl
        )

        applyFlowSelection(
            anchor: anchor,
            focus: focusPos,
            clickCount: 1,
            in: snapshot
        )
        cancelArmedOriginatingControl(armed: armed, window: window, triggerEvent: event)
        updateAutoScrollState()
        AppPointerShape.pointerMoved(in: window, at: currentWindowPoint)

        if armed.armedControl?.control != nil,
           let redirected = Self.redirectedMouseEvent(
               from: event,
               type: .leftMouseDragged,
               locationInWindow: CGPoint(x: -10_000, y: -10_000)
           )
        {
            return .redirect(redirected)
        }
        return .consume
    }

    func handleWindowLeftMouseUp(
        window: CueSeekerWindow,
        event: NSEvent
    ) -> WindowMouseEventDisposition {
        externalArmedSession = nil
        guard let dragSession = activeDragSession, dragSession.isExternalEntry else {
            return .passthrough
        }

        let currentWindowPoint = event.locationInWindow
        let hadArmedControl = dragSession.armedControl?.control != nil
        if dragSession.window.window === window,
           let snapshot = buildFlowSnapshot(in: window, preferredScope: dragSession.scope),
           let focus = project(windowPoint: currentWindowPoint, in: snapshot)
        {
            applyFlowSelection(
                anchor: dragSession.anchor,
                focus: focus,
                clickCount: 1,
                in: snapshot
            )
        }
        stopAutoScroll()
        activeDragSession = nil
        AppPointerShape.pointerMoved(in: window, at: currentWindowPoint)
        if !hasSelection {
            clearSelection()
        }

        if hadArmedControl,
           let redirected = Self.redirectedMouseEvent(
               from: event,
               type: .leftMouseUp,
               locationInWindow: CGPoint(x: -10_000, y: -10_000)
           )
        {
            return .redirect(redirected)
        }
        return .consume
    }

    private func cancelArmedOriginatingControl(
        armed: ExternalArmedSession,
        window: NSWindow,
        triggerEvent: NSEvent
    ) {
        NotificationCenter.default.post(
            name: .cueSeekerCancelControlPress,
            object: window
        )
        if let control = armed.armedControl?.control {
            control.cell?.isHighlighted = false
            control.needsDisplay = true
            return
        }
        guard let hitView = armed.armedHitView?.view else {
            return
        }
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

    // MARK: - Viewport Edge Auto-Scroll

    private func updateAutoScrollState() {
        guard resolveAutoScrollStep() != nil else {
            stopAutoScroll()
            return
        }
        guard autoScrollTimer == nil else {
            return
        }
        let timer = Timer(
            timeInterval: Self.autoScrollInterval,
            target: self,
            selector: #selector(handleAutoScrollTimerTick),
            userInfo: nil,
            repeats: true
        )
        autoScrollTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func stopAutoScroll() {
        autoScrollTimer?.invalidate()
        autoScrollTimer = nil
    }

    @objc private func handleAutoScrollTimerTick() {
        if NSEvent.pressedMouseButtons & 1 == 0 {
            stopAutoScroll()
            return
        }
        _ = stepAutoScroll()
    }

    @discardableResult
    func stepAutoScrollForTesting() -> Bool {
        stepAutoScroll()
    }

    private func stepAutoScroll() -> Bool {
        guard let session = activeDragSession,
              let window = session.window.window,
              let step = resolveAutoScrollStep()
        else {
            stopAutoScroll()
            return false
        }

        let clipView = step.scrollView.contentView
        clipView.scroll(to: step.nextClipOrigin)
        step.scrollView.reflectScrolledClipView(clipView)
        window.contentView?.layoutSubtreeIfNeeded()

        if let snapshot = buildFlowSnapshot(in: window, preferredScope: session.scope),
           let focus = project(windowPoint: session.latestWindowPoint, in: snapshot)
        {
            applyFlowSelection(
                anchor: session.anchor,
                focus: focus,
                clickCount: session.clickCount,
                in: snapshot
            )
        }
        if resolveAutoScrollStep() == nil {
            stopAutoScroll()
        }
        return true
    }

    private func resolveAutoScrollStep() -> (scrollView: NSScrollView, nextClipOrigin: CGPoint)? {
        guard let session = activeDragSession,
              let window = session.window.window,
              let snapshot = buildFlowSnapshot(in: window, preferredScope: session.scope)
        else {
            return nil
        }

        var seen = Set<ObjectIdentifier>()
        var candidates: [(scrollView: NSScrollView, viewportWindowRect: CGRect)] = []
        let orderedViews = [session.anchor.start.view] + snapshot.flatViews
        for view in orderedViews {
            guard let resolved = Self.resolveScrollableViewport(for: view),
                  seen.insert(ObjectIdentifier(resolved.scrollView)).inserted
            else {
                continue
            }
            candidates.append(resolved)
        }

        for candidate in candidates {
            guard let documentView = candidate.scrollView.documentView else {
                continue
            }
            let visibleRect = candidate.scrollView.documentVisibleRect
            let contentSize = documentView.frame.size
            guard contentSize.height > visibleRect.height + 0.5
                || contentSize.width > visibleRect.width + 0.5
            else {
                continue
            }
            let currentTopDown = CGPoint(
                x: visibleRect.minX - documentView.frame.minX,
                y: documentView.isFlipped
                    ? (visibleRect.minY - documentView.frame.minY)
                    : (documentView.frame.maxY - visibleRect.maxY)
            )
            let nextTopDown = SubtitleTableTextDragAutoScrollGeometry.nextOrigin(
                pointer: session.latestWindowPoint,
                viewport: candidate.viewportWindowRect,
                currentOrigin: currentTopDown,
                contentSize: contentSize,
                viewportSize: visibleRect.size,
                allowsVerticalScrolling: true
            )
            let delta = hypot(nextTopDown.x - currentTopDown.x, nextTopDown.y - currentTopDown.y)
            guard delta > 0.01 else {
                continue
            }
            let nextClipOrigin = CGPoint(
                x: documentView.frame.minX + nextTopDown.x,
                y: documentView.isFlipped
                    ? (documentView.frame.minY + nextTopDown.y)
                    : (documentView.frame.maxY - visibleRect.height - nextTopDown.y)
            )
            return (candidate.scrollView, nextClipOrigin)
        }
        return nil
    }

    private static func resolveScrollableViewport(
        for view: NSView
    ) -> (scrollView: NSScrollView, viewportWindowRect: CGRect)? {
        if let scrollView = view.enclosingScrollView {
            let clipView = scrollView.contentView
            let viewport = clipView.convert(clipView.bounds, to: nil).standardized
            guard !viewport.isNull, !viewport.isEmpty else { return nil }
            return (scrollView, viewport)
        }
        var current = view.superview
        while let ancestor = current {
            if let pageViewport = ancestor as? SubtitleTablePageChromeViewportView,
               let scrollView = pageViewport.scrollView
            {
                let viewport = pageViewport.convert(pageViewport.bounds, to: nil).standardized
                guard !viewport.isNull, !viewport.isEmpty else { return nil }
                return (scrollView, viewport)
            }
            current = ancestor.superview
        }
        return nil
    }

    // MARK: - Continuous Flow Snapshot, Projection & Selection Application

    private func buildFlowSnapshot(
        in window: NSWindow,
        preferredScope: StaticTextFlowScope?
    ) -> FlowSnapshot? {
        guard let contentView = window.contentView else {
            return nil
        }

        var interactiveViews: [WorkbenchSelectableTextNSView] = []
        func collect(_ view: NSView) {
            guard view.window != nil, !view.isHidden, view.alphaValue > 0 else {
                return
            }
            if let selectable = view as? WorkbenchSelectableTextNSView {
                if selectable.canInteract {
                    selectable.prepareLayoutForFlow()
                    if selectable.textLengthUTF16 > 0, !selectable.lineUsedRects().isEmpty {
                        interactiveViews.append(selectable)
                    }
                }
                return
            }
            for subview in view.subviews {
                collect(subview)
            }
        }
        collect(contentView)

        guard !interactiveViews.isEmpty else {
            return nil
        }

        let resolvedScope: StaticTextFlowScope
        if let preferredScope,
           interactiveViews.contains(where: { $0.flowScope == preferredScope })
        {
            resolvedScope = preferredScope
        } else {
            guard let topScope = interactiveViews
                .compactMap(\.flowScope)
                .max(by: { $0.priorityRank < $1.priorityRank })
            else {
                return nil
            }
            resolvedScope = topScope
        }

        let scopedViews = interactiveViews.filter { $0.flowScope == resolvedScope }
        guard !scopedViews.isEmpty else {
            return nil
        }

        let refHeight = max(1, window.frame.height)
        var rawNodes: [FlowNode] = []
        rawNodes.reserveCapacity(scopedViews.count)

        for view in scopedViews {
            let localLineRects = view.lineUsedRects()
            guard let firstLocalLine = localLineRects.first else { continue }

            let windowBounds = view.convert(view.bounds, to: nil).standardized
            let visualBounds = Self.toVisualRect(windowBounds, refHeight: refHeight)
            let visualLines = localLineRects.map { rect in
                Self.toVisualRect(view.convert(rect, to: nil).standardized, refHeight: refHeight)
            }

            let clipWindowRect = view.visibleWindowClipRect()
            let clipVisualRect = clipWindowRect.map { Self.toVisualRect($0, refHeight: refHeight) }
            let visibleVisualLines: [CGRect] = {
                guard let clipVisualRect else { return [] }
                return visualLines.compactMap { lineRect in
                    let clipped = lineRect.intersection(clipVisualRect)
                    guard !clipped.isNull, clipped.width > 0.5, clipped.height > 0.5 else {
                        return nil
                    }
                    return clipped
                }
            }()

            if let scrollView = view.enclosingScrollView,
               let docView = scrollView.documentView
            {
                let scrollWindowRect = scrollView.contentView
                    .convert(scrollView.contentView.bounds, to: nil)
                    .standardized
                let scrollVisualTopY = refHeight - scrollWindowRect.maxY
                let rawInDoc = view.convert(firstLocalLine, to: docView)
                let docLineRect = docView.isFlipped
                    ? rawInDoc
                    : CGRect(
                        x: rawInDoc.minX,
                        y: docView.bounds.maxY - rawInDoc.maxY,
                        width: rawInDoc.width,
                        height: rawInDoc.height
                    )
                let rawBoundsInDoc = view.convert(view.bounds, to: docView)
                let docBounds = docView.isFlipped
                    ? rawBoundsInDoc
                    : CGRect(
                        x: rawBoundsInDoc.minX,
                        y: docView.bounds.maxY - rawBoundsInDoc.maxY,
                        width: rawBoundsInDoc.width,
                        height: rawBoundsInDoc.height
                    )
                rawNodes.append(
                    FlowNode(
                        view: view,
                        scrollContainerID: ObjectIdentifier(scrollView),
                        containerTopY: scrollVisualTopY,
                        innerSortMinY: docLineRect.minY,
                        innerSortMaxY: docLineRect.maxY,
                        innerSortMinX: docBounds.minX,
                        innerSortMaxX: docBounds.maxX,
                        visualBounds: visualBounds,
                        visibleVisualLineRects: visibleVisualLines
                    )
                )
            } else {
                let firstVisualLine = visualLines[0]
                rawNodes.append(
                    FlowNode(
                        view: view,
                        scrollContainerID: nil,
                        containerTopY: firstVisualLine.minY,
                        innerSortMinY: firstVisualLine.minY,
                        innerSortMaxY: firstVisualLine.maxY,
                        innerSortMinX: visualBounds.minX,
                        innerSortMaxX: visualBounds.maxX,
                        visualBounds: visualBounds,
                        visibleVisualLineRects: visibleVisualLines
                    )
                )
            }
        }

        guard !rawNodes.isEmpty else {
            return nil
        }

        rawNodes.sort { lhs, rhs in
            let lhsKey = (
                lhs.containerTopY,
                lhs.scrollContainerID == nil ? 0 : 1,
                lhs.innerSortMinY,
                lhs.innerSortMinX
            )
            let rhsKey = (
                rhs.containerTopY,
                rhs.scrollContainerID == nil ? 0 : 1,
                rhs.innerSortMinY,
                rhs.innerSortMinX
            )
            return lhsKey < rhsKey
        }

        var rowGroups: [FlowRowGroup] = []
        for node in rawNodes {
            if let lastIndex = rowGroups.indices.last,
               rowGroups[lastIndex].scrollContainerID == node.scrollContainerID
            {
                let group = rowGroups[lastIndex]
                let vOverlap = min(group.firstBandMaxY, node.innerSortMaxY)
                    - max(group.firstBandMinY, node.innerSortMinY)
                let minHeight = min(
                    max(0, group.firstBandMaxY - group.firstBandMinY),
                    max(0, node.innerSortMaxY - node.innerSortMinY)
                )
                let hOverlap = min(group.maxX, node.innerSortMaxX)
                    - max(group.minX, node.innerSortMinX)
                if minHeight > 0,
                   vOverlap >= minHeight * 0.35,
                   hOverlap < 4
                {
                    rowGroups[lastIndex].nodes.append(node)
                    rowGroups[lastIndex].nodes.sort { $0.innerSortMinX < $1.innerSortMinX }
                    rowGroups[lastIndex].firstBandMinY = min(group.firstBandMinY, node.innerSortMinY)
                    rowGroups[lastIndex].firstBandMaxY = max(group.firstBandMaxY, node.innerSortMaxY)
                    rowGroups[lastIndex].minX = min(group.minX, node.innerSortMinX)
                    rowGroups[lastIndex].maxX = max(group.maxX, node.innerSortMaxX)
                    continue
                }
            }
            rowGroups.append(
                FlowRowGroup(
                    nodes: [node],
                    scrollContainerID: node.scrollContainerID,
                    firstBandMinY: node.innerSortMinY,
                    firstBandMaxY: node.innerSortMaxY,
                    minX: node.innerSortMinX,
                    maxX: node.innerSortMaxX
                )
            )
        }

        let flatViews = rowGroups.flatMap { $0.nodes.map(\.view) }
        var visibleRows: [VisibleFlowRow] = []
        for group in rowGroups {
            let visibleNodes = group.nodes.filter { !$0.visibleVisualLineRects.isEmpty }
            guard !visibleNodes.isEmpty else { continue }
            let minY = visibleNodes.map(\.visibleMinY).min() ?? 0
            let maxY = visibleNodes.map(\.visibleMaxY).max() ?? 0
            visibleRows.append(
                VisibleFlowRow(
                    nodes: visibleNodes,
                    visibleMinY: minY,
                    visibleMaxY: maxY
                )
            )
        }
        if visibleRows.isEmpty {
            visibleRows = rowGroups.map { group in
                let minY = group.nodes.map { $0.visualBounds.minY }.min() ?? 0
                let maxY = group.nodes.map { $0.visualBounds.maxY }.max() ?? 0
                return VisibleFlowRow(nodes: group.nodes, visibleMinY: minY, visibleMaxY: maxY)
            }
        }

        return FlowSnapshot(
            window: window,
            scope: resolvedScope,
            refHeight: refHeight,
            rowGroups: rowGroups,
            flatViews: flatViews,
            visibleRows: visibleRows
        )
    }

    private func project(
        windowPoint: CGPoint,
        in snapshot: FlowSnapshot
    ) -> FlowCursor? {
        let rows = snapshot.visibleRows
        guard let firstRow = rows.first,
              let firstNode = firstRow.nodes.first,
              let lastRow = rows.last,
              let lastNode = lastRow.nodes.last
        else {
            return nil
        }

        let p = CGPoint(
            x: windowPoint.x,
            y: snapshot.refHeight - windowPoint.y
        )

        // Strict top/bottom clamping: zero horizontal projection tolerance band outside [firstLine.minY, lastLine.maxY].
        if p.y < firstRow.visibleMinY {
            return FlowCursor(view: firstNode.view, utf16Offset: 0)
        }
        if p.y > lastRow.visibleMaxY {
            return FlowCursor(view: lastNode.view, utf16Offset: lastNode.view.textLengthUTF16)
        }

        for row in rows {
            if p.y < row.visibleMinY {
                // Strictly inside vertical blank/control gap between previous row and `row`.
                return FlowCursor(view: row.nodes[0].view, utf16Offset: 0)
            }
            if p.y <= row.visibleMaxY {
                if row.nodes.count == 1 {
                    let view = row.nodes[0].view
                    let localPoint = view.convert(windowPoint, from: nil)
                    return FlowCursor(view: view, utf16Offset: view.utf16Offset(at: localPoint))
                }
                let coveringPeers = row.nodes.filter { $0.visibleMaxY >= p.y - 2 }
                let peers = coveringPeers.isEmpty ? row.nodes : coveringPeers
                if p.x < peers[0].visibleMinX {
                    let view = peers[0].view
                    return FlowCursor(
                        view: view,
                        utf16Offset: view.utf16Offset(at: view.convert(windowPoint, from: nil))
                    )
                }
                for index in peers.indices {
                    let peer = peers[index]
                    if p.x <= peer.visibleMaxX {
                        let view = peer.view
                        return FlowCursor(
                            view: view,
                            utf16Offset: view.utf16Offset(at: view.convert(windowPoint, from: nil))
                        )
                    }
                    if index + 1 < peers.count, p.x < peers[index + 1].visibleMinX {
                        return FlowCursor(view: peers[index + 1].view, utf16Offset: 0)
                    }
                }
                let trailingView = peers[peers.count - 1].view
                return FlowCursor(
                    view: trailingView,
                    utf16Offset: trailingView.utf16Offset(
                        at: trailingView.convert(windowPoint, from: nil)
                    )
                )
            }
        }

        return FlowCursor(view: lastNode.view, utf16Offset: lastNode.view.textLengthUTF16)
    }

    private func hasNonEmptyFlowSelection(
        from anchor: FlowCursor,
        to focus: FlowCursor,
        in snapshot: FlowSnapshot
    ) -> Bool {
        let ranges = resolvedNodeSelectionRanges(
            anchor: FlowAnchor(start: anchor, end: anchor),
            focus: focus,
            clickCount: 1,
            in: snapshot
        )
        return ranges.contains { ($0?.length ?? 0) > 0 }
    }

    private func applyFlowSelection(
        anchor: FlowAnchor,
        focus: FlowCursor,
        clickCount: Int,
        in snapshot: FlowSnapshot
    ) {
        let ranges = resolvedNodeSelectionRanges(
            anchor: anchor,
            focus: focus,
            clickCount: clickCount,
            in: snapshot
        )
        let activeSet = Set(snapshot.flatViews.map(ObjectIdentifier.init))
        for ref in selectedViewRefs {
            if let existing = ref.view, !activeSet.contains(ObjectIdentifier(existing)) {
                existing.setFlowSelectedRange(nil)
            }
        }

        var nextSelected: [WeakSelectableViewRef] = []
        for (index, view) in snapshot.flatViews.enumerated() {
            let range = ranges[index]
            view.setFlowSelectedRange(range)
            if let range, range.length > 0 {
                nextSelected.append(WeakSelectableViewRef(view))
            }
        }
        selectedViewRefs = nextSelected
        activeScope = nextSelected.isEmpty ? activeDragSession?.scope : snapshot.scope
        if activeResponderView == nil || activeResponderView?.window == nil {
            activeResponderView = nextSelected.first?.view
        }
    }

    private func resolvedNodeSelectionRanges(
        anchor: FlowAnchor,
        focus: FlowCursor,
        clickCount: Int,
        in snapshot: FlowSnapshot
    ) -> [NSRange?] {
        let views = snapshot.flatViews
        guard !views.isEmpty else { return [] }

        func indexPosition(of cursor: FlowCursor) -> (nodeIndex: Int, offset: Int)? {
            guard let idx = views.firstIndex(where: { $0 === cursor.view }) else {
                return nil
            }
            let clamped = min(max(0, cursor.utf16Offset), views[idx].textLengthUTF16)
            return (idx, clamped)
        }

        guard let anchorStart = indexPosition(of: anchor.start),
              let anchorEnd = indexPosition(of: anchor.end),
              let rawFocus = indexPosition(of: focus)
        else {
            return Array(repeating: nil, count: views.count)
        }

        let focusStart: (nodeIndex: Int, offset: Int)
        let focusEnd: (nodeIndex: Int, offset: Int)
        let focusView = views[rawFocus.nodeIndex]
        if clickCount >= 3 {
            focusStart = (rawFocus.nodeIndex, 0)
            focusEnd = (rawFocus.nodeIndex, focusView.textLengthUTF16)
        } else if clickCount == 2 {
            let word = focusView.wordRange(at: rawFocus.offset)
            focusStart = (rawFocus.nodeIndex, word.location)
            focusEnd = (rawFocus.nodeIndex, NSMaxRange(word))
        } else {
            focusStart = rawFocus
            focusEnd = rawFocus
        }

        let low = anchorStart < focusStart ? anchorStart : focusStart
        let high = anchorEnd < focusEnd ? focusEnd : anchorEnd

        return views.indices.map { idx in
            let length = views[idx].textLengthUTF16
            guard length > 0, idx >= low.nodeIndex, idx <= high.nodeIndex else {
                return nil
            }
            if low.nodeIndex == high.nodeIndex {
                let span = high.offset - low.offset
                return span > 0 ? NSRange(location: low.offset, length: span) : nil
            }
            if idx == low.nodeIndex {
                let span = length - low.offset
                return span > 0 ? NSRange(location: low.offset, length: span) : nil
            }
            if idx == high.nodeIndex {
                return high.offset > 0 ? NSRange(location: 0, length: high.offset) : nil
            }
            return NSRange(location: 0, length: length)
        }
    }

    private func clearSelectedViews(except keptView: WorkbenchSelectableTextNSView?) {
        for ref in selectedViewRefs {
            guard let view = ref.view, view !== keptView else { continue }
            view.clearSelection(notifyCoordinator: false)
        }
    }

    private static func toVisualRect(_ windowRect: CGRect, refHeight: CGFloat) -> CGRect {
        CGRect(
            x: windowRect.minX,
            y: refHeight - windowRect.maxY,
            width: windowRect.width,
            height: windowRect.height
        )
    }

    // MARK: - Hit Testing & Clipboard Serialization

    private static func isInsideDedicatedTextSelectionSurface(_ hitView: NSView?) -> Bool {
        var current = hitView
        while let view = current {
            if view is SubtitleVirtualTableDocumentView
                || view is SubtitleTableHeaderTextOverlayView
                || view is PlaybackSubtitleFocusReelDocumentView
            {
                return true
            }
            current = view.superview
        }
        return false
    }

    private static func hasInteractiveMenuModalSelectableTextView(in rootView: NSView) -> Bool {
        guard rootView.window != nil, !rootView.isHidden, rootView.alphaValue > 0 else {
            return false
        }
        if let selectable = rootView as? WorkbenchSelectableTextNSView {
            return selectable.allowsMenuModalInteraction && selectable.canInteract
        }
        for subview in rootView.subviews.reversed() {
            if hasInteractiveMenuModalSelectableTextView(in: subview) {
                return true
            }
        }
        return false
    }

    private static func findHitSelectableTextView(
        in rootView: NSView,
        allowedViews: Set<ObjectIdentifier>,
        from startPoint: CGPoint,
        to endPoint: CGPoint
    ) -> WorkbenchSelectableTextNSView? {
        var bestMatch: (view: WorkbenchSelectableTextNSView, entryT: CGFloat, distanceSq: CGFloat)?

        func visit(_ view: NSView) {
            guard view.window != nil,
                  !view.isHidden,
                  view.alphaValue > 0
            else {
                return
            }
            if let selectable = view as? WorkbenchSelectableTextNSView {
                guard allowedViews.contains(ObjectIdentifier(selectable)),
                      selectable.canInteract,
                      let hitRect = selectable.windowSelectionHitRect(),
                      let entryT = segmentRectIntersectionParameter(
                          from: startPoint,
                          to: endPoint,
                          rect: hitRect
                      )
                else {
                    return
                }
                let distanceSq = squaredDistance(from: endPoint, to: hitRect)
                if let currentBest = bestMatch {
                    if entryT < currentBest.entryT - 0.0001
                        || (abs(entryT - currentBest.entryT) <= 0.0001 && distanceSq < currentBest.distanceSq)
                    {
                        bestMatch = (selectable, entryT, distanceSq)
                    }
                } else {
                    bestMatch = (selectable, entryT, distanceSq)
                }
                return
            }
            for subview in view.subviews.reversed() {
                visit(subview)
            }
        }

        visit(rootView)
        return bestMatch?.view
    }

    static func segmentRectIntersectionParameter(
        from p0: CGPoint,
        to p1: CGPoint,
        rect: CGRect
    ) -> CGFloat? {
        guard !rect.isNull, !rect.isEmpty else {
            return nil
        }
        if rect.contains(p0) {
            return 0
        }
        let dx = p1.x - p0.x
        let dy = p1.y - p0.y
        var tMin: CGFloat = 0
        var tMax: CGFloat = 1

        let checks: [(p: CGFloat, q: CGFloat)] = [
            (-dx, p0.x - rect.minX),
            (dx, rect.maxX - p0.x),
            (-dy, p0.y - rect.minY),
            (dy, rect.maxY - p0.y),
        ]

        for check in checks {
            if abs(check.p) < 1e-6 {
                if check.q < 0 {
                    return nil
                }
            } else {
                let t = check.q / check.p
                if check.p < 0 {
                    if t > tMax { return nil }
                    if t > tMin { tMin = t }
                } else {
                    if t < tMin { return nil }
                    if t < tMax { tMax = t }
                }
            }
        }
        return tMin <= tMax ? max(0, tMin) : nil
    }

    private static func squaredDistance(from point: CGPoint, to rect: CGRect) -> CGFloat {
        let dx = max(rect.minX - point.x, 0, point.x - rect.maxX)
        let dy = max(rect.minY - point.y, 0, point.y - rect.maxY)
        return dx * dx + dy * dy
    }

    func canCopySelection(in window: NSWindow?) -> Bool {
        guard let window else { return false }
        let matchingViews = liveSelectedViews.filter { $0.window === window && $0.canInteract }
        guard !matchingViews.isEmpty,
              let text = serializedSelectionText(in: window, fallbackViews: matchingViews),
              !text.isEmpty
        else {
            return false
        }
        return true
    }

    @discardableResult
    func copySelection(
        in window: NSWindow?,
        to pasteboard: NSPasteboard = .general
    ) -> Bool {
        guard let window else { return false }
        let matchingViews = liveSelectedViews.filter { $0.window === window && $0.canInteract }
        guard !matchingViews.isEmpty,
              let text = serializedSelectionText(in: window, fallbackViews: matchingViews),
              !text.isEmpty
        else {
            return false
        }
        pasteboard.clearContents()
        return pasteboard.setString(text, forType: .string)
    }

    @discardableResult
    func copyActiveSelection(to pasteboard: NSPasteboard = .general) -> Bool {
        let matchingViews = liveSelectedViews.filter(\.canInteract)
        guard let first = matchingViews.first,
              let text = serializedSelectionText(in: first.window, fallbackViews: matchingViews),
              !text.isEmpty
        else {
            return false
        }
        pasteboard.clearContents()
        return pasteboard.setString(text, forType: .string)
    }

    private func serializedSelectionText(
        in window: NSWindow?,
        fallbackViews: [WorkbenchSelectableTextNSView]
    ) -> String? {
        if let window,
           let snapshot = buildFlowSnapshot(in: window, preferredScope: activeScope)
        {
            var rowLines: [String] = []
            for group in snapshot.rowGroups {
                let peerPieces = group.nodes.compactMap { node -> String? in
                    guard node.view.canInteract,
                          let piece = node.view.selectedText,
                          !piece.isEmpty
                    else {
                        return nil
                    }
                    return piece
                }
                if !peerPieces.isEmpty {
                    rowLines.append(peerPieces.joined(separator: "\t"))
                }
            }
            if !rowLines.isEmpty {
                return rowLines.joined(separator: "\n")
            }
        }
        let fallbackPieces = fallbackViews.compactMap(\.selectedText).filter { !$0.isEmpty }
        guard !fallbackPieces.isEmpty else {
            return nil
        }
        return fallbackPieces.joined(separator: "\n")
    }

    @objc private func handleClearTextSelectionNotification(_ notification: Notification) {
        if let sender = notification.object as? WorkbenchSelectableTextNSView,
           isResponderOwnedByActiveSelection(sender)
        {
            return
        }
        clearSelection()
    }

    @objc private func handleAppDidResignActive(_ notification: Notification) {
        clearSelection()
    }

    @objc private func handleWindowDidResignKey(_ notification: Notification) {
        guard let resignedWindow = notification.object as? NSWindow else {
            return
        }
        if activeResponderView?.window === resignedWindow
            || liveSelectedViews.contains(where: { $0.window === resignedWindow })
        {
            clearSelection()
        }
    }
}

/// Reusable static text component supporting mouse drag selection, double-click word
/// selection, triple-click select-all, `Cmd + C` copy, `.iBeam` / `.grab` pointer shape,
/// and optional single-click action disambiguated from drag selection.
struct WorkbenchSelectableText: View {
    let text: String
    var fullCopyText: String? = nil
    var fontSize: CGFloat = WorkbenchControlMetrics.redesignFontSizeBody
    var weight: Font.Weight = .regular
    var monospacedDigits: Bool = false
    var color: Color = WorkbenchRedesignColors.textPrimary
    var lineLimit: Int? = nil
    var lineHeight: CGFloat? = nil
    var truncationMode: Text.TruncationMode = .tail
    var alignment: TextAlignment = .leading
    var isSelectable: Bool = true
    var preferredPointerShape: PointerShape = .iBeam
    var showsUnderline: Bool = false
    var allowsMenuModalInteraction: Bool = false
    var onTap: (() -> Void)? = nil

    @Environment(\.interfaceLayerContext) private var interfaceLayerContext
    @Environment(\.workbenchDialogID) private var dialogID
    @Environment(\.isWorkbenchDialogCovered) private var isDialogCovered

    init(
        _ text: String,
        fullCopyText: String? = nil,
        fontSize: CGFloat = WorkbenchControlMetrics.redesignFontSizeBody,
        weight: Font.Weight = .regular,
        monospacedDigits: Bool = false,
        color: Color = WorkbenchRedesignColors.textPrimary,
        lineLimit: Int? = nil,
        lineHeight: CGFloat? = nil,
        truncationMode: Text.TruncationMode = .tail,
        alignment: TextAlignment = .leading,
        isSelectable: Bool = true,
        preferredPointerShape: PointerShape = .iBeam,
        showsUnderline: Bool = false,
        allowsMenuModalInteraction: Bool = false,
        onTap: (() -> Void)? = nil
    ) {
        self.text = text
        self.fullCopyText = fullCopyText
        self.fontSize = fontSize
        self.weight = weight
        self.monospacedDigits = monospacedDigits
        self.color = color
        self.lineLimit = lineLimit
        self.lineHeight = lineHeight
        self.truncationMode = truncationMode
        self.alignment = alignment
        self.isSelectable = isSelectable
        self.preferredPointerShape = preferredPointerShape
        self.showsUnderline = showsUnderline
        self.allowsMenuModalInteraction = allowsMenuModalInteraction
        self.onTap = onTap
    }

    private var swiftUIFont: Font {
        let base = Font.system(size: fontSize, weight: weight)
        return monospacedDigits ? base.monospacedDigit() : base
    }

    private var nsFont: NSFont {
        let nsWeight = Self.nsFontWeight(for: weight)
        if monospacedDigits {
            return .monospacedDigitSystemFont(ofSize: fontSize, weight: nsWeight)
        }
        return .systemFont(ofSize: fontSize, weight: nsWeight)
    }

    private var nsAlignment: NSTextAlignment {
        switch alignment {
        case .leading:
            return .left
        case .center:
            return .center
        case .trailing:
            return .right
        }
    }

    private var isEffectivelySelectable: Bool {
        isSelectable && !text.isEmpty
    }

    var body: some View {
        let resolvedLineHeight: CGFloat? = (lineHeight ?? 0) > 0 ? lineHeight : nil
        WorkbenchSelectableTextSizingLayout(
            text: text,
            font: nsFont,
            lineLimit: lineLimit,
            lineHeight: resolvedLineHeight,
            truncatesTail: truncationMode == .tail
        ) {
            Text(text)
                .font(swiftUIFont)
                .foregroundStyle(color)
                .lineLimit(lineLimit)
                .truncationMode(truncationMode)
                .multilineTextAlignment(alignment)
                .opacity(isEffectivelySelectable ? 0 : 1)
        }
        .overlay {
            if isEffectivelySelectable {
                WorkbenchSelectableTextRepresentable(
                    text: text,
                    fullCopyText: fullCopyText,
                    font: nsFont,
                    textColor: NSColor(color),
                    alignment: nsAlignment,
                    lineLimit: lineLimit,
                    lineHeight: resolvedLineHeight,
                    truncatesTail: truncationMode == .tail,
                    isSelectable: isEffectivelySelectable,
                    preferredPointerShape: preferredPointerShape,
                    showsUnderline: showsUnderline,
                    allowsMenuModalInteraction: allowsMenuModalInteraction,
                    onTap: onTap,
                    interfaceLayerContext: interfaceLayerContext,
                    dialogID: dialogID,
                    isDialogCovered: isDialogCovered
                )
            }
        }
    }

    private static func nsFontWeight(for weight: Font.Weight) -> NSFont.Weight {
        switch weight {
        case .ultraLight:
            return .ultraLight
        case .thin:
            return .thin
        case .light:
            return .light
        case .regular:
            return .regular
        case .medium:
            return .medium
        case .semibold:
            return .semibold
        case .bold:
            return .bold
        case .heavy:
            return .heavy
        case .black:
            return .black
        default:
            return .regular
        }
    }
}

private struct WorkbenchSelectableTextSizingLayout: Layout {
    let text: String
    let font: NSFont
    let lineLimit: Int?
    let lineHeight: CGFloat?
    let truncatesTail: Bool

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        guard let subview = subviews.first else { return .zero }
        let baseSize = subview.sizeThatFits(proposal)
        guard let lineHeight, lineHeight > 0 else {
            return baseSize
        }
        if lineLimit == 1 {
            return CGSize(width: baseSize.width, height: lineHeight)
        }
        let targetWidth: CGFloat
        if let proposedWidth = proposal.width, proposedWidth.isFinite, proposedWidth > 0 {
            targetWidth = proposedWidth
        } else {
            targetWidth = baseSize.width
        }
        let measuredHeight = WorkbenchSelectableTextNSView.measuredMultilineHeight(
            for: text,
            font: font,
            lineHeight: lineHeight,
            lineLimit: lineLimit,
            truncatesTail: truncatesTail,
            width: targetWidth
        )
        return CGSize(
            width: targetWidth,
            height: max(baseSize.height, measuredHeight)
        )
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        for subview in subviews {
            subview.place(
                at: bounds.origin,
                proposal: ProposedViewSize(bounds.size)
            )
        }
    }
}

private struct WorkbenchSelectableTextRepresentable: NSViewRepresentable {
    let text: String
    let fullCopyText: String?
    let font: NSFont
    let textColor: NSColor
    let alignment: NSTextAlignment
    let lineLimit: Int?
    let lineHeight: CGFloat?
    let truncatesTail: Bool
    let isSelectable: Bool
    let preferredPointerShape: PointerShape
    let showsUnderline: Bool
    let allowsMenuModalInteraction: Bool
    let onTap: (() -> Void)?
    let interfaceLayerContext: InterfaceLayerContext
    let dialogID: WorkbenchDialogAccessibilityID?
    let isDialogCovered: Bool

    func makeNSView(context _: Context) -> WorkbenchSelectableTextNSView {
        let view = WorkbenchSelectableTextNSView()
        update(view)
        return view
    }

    func updateNSView(_ nsView: WorkbenchSelectableTextNSView, context _: Context) {
        update(nsView)
    }

    static func dismantleNSView(_ nsView: WorkbenchSelectableTextNSView, coordinator _: ()) {
        MainActor.assumeIsolated {
            nsView.clearSelection(notifyCoordinator: true)
            WorkbenchStaticTextSelectionCoordinator.shared.unregister(nsView)
        }
    }

    private func update(_ view: WorkbenchSelectableTextNSView) {
        view.configure(
            text: text,
            fullCopyText: fullCopyText,
            font: font,
            textColor: textColor,
            alignment: alignment,
            lineLimit: lineLimit,
            lineHeight: lineHeight,
            truncatesTail: truncatesTail,
            isSelectable: isSelectable,
            preferredPointerShape: preferredPointerShape,
            showsUnderline: showsUnderline,
            allowsMenuModalInteraction: allowsMenuModalInteraction,
            onTap: onTap,
            interfaceLayerContext: interfaceLayerContext,
            dialogID: dialogID,
            isDialogCovered: isDialogCovered
        )
    }
}

@MainActor
final class WorkbenchSelectableTextNSView:
    NSView,
    PointerShapeProviding,
    SubtitleTableTextSelectionInteractiveView,
    NSMenuItemValidation
{
    static let dragThreshold: CGFloat = 2.0

    private struct LineFragmentLayout {
        let usedRect: CGRect
        let glyphRange: NSRange
        let charRange: NSRange
        let hasTruncatedTail: Bool
    }

    private let textStorage = NSTextStorage()
    private let layoutManager = NSLayoutManager()
    private let textContainer = NSTextContainer()

    private(set) var text: String = ""
    private(set) var fullCopyText: String? = nil
    private(set) var font: NSFont = .systemFont(
        ofSize: WorkbenchControlMetrics.redesignFontSizeBody,
        weight: .regular
    )
    private(set) var textColor: NSColor = WorkbenchRedesignColors.NS.textPrimary
    private(set) var alignment: NSTextAlignment = .left
    private(set) var lineLimit: Int? = nil
    private(set) var lineHeight: CGFloat? = nil
    private(set) var truncatesTail: Bool = true
    private(set) var isSelectable: Bool = true
    private(set) var preferredPointerShape: PointerShape = .iBeam
    private(set) var showsUnderline: Bool = false
    private(set) var allowsMenuModalInteraction: Bool = false
    var onTap: (() -> Void)?
    private(set) var interfaceLayerContext = InterfaceLayerContext()
    private(set) var dialogID: WorkbenchDialogAccessibilityID? = nil
    private(set) var isDialogCovered: Bool = false

    private(set) var selectedRange: NSRange?
    private(set) var isTrackingMouse = false
    private var anchorRange = NSRange(location: 0, length: 0)
    private var startWindowPoint: CGPoint = .zero
    private var activeClickCount = 1
    private var didDrag = false
    private var needsTextLayout = true

    override var isFlipped: Bool { true }
    override var isOpaque: Bool { false }

    override var acceptsFirstResponder: Bool {
        canInteract
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    var textLengthUTF16: Int {
        (text as NSString).length
    }

    var flowScope: StaticTextFlowScope? {
        guard let window else { return nil }
        let wn = window.windowNumber
        if allowsMenuModalInteraction {
            return .menuModalPopover(windowNumber: wn)
        }
        if interfaceLayerContext.layer == .dialog {
            return .dialog(windowNumber: wn, dialogID: dialogID)
        }
        return .surface(windowNumber: wn, layer: interfaceLayerContext.layer)
    }

    var hasSelection: Bool {
        guard let selectedRange else { return false }
        return selectedRange.length > 0
    }

    var selectedText: String? {
        guard let selectedRange, selectedRange.length > 0 else {
            return nil
        }
        let nsText = text as NSString
        let safeRange = NSIntersectionRange(
            selectedRange,
            NSRange(location: 0, length: nsText.length)
        )
        guard safeRange.length > 0 else {
            return nil
        }
        if NSMaxRange(safeRange) >= nsText.length,
           let fullCopyText,
           !fullCopyText.isEmpty,
           fullCopyText != text
        {
            if safeRange.location == 0 {
                return fullCopyText
            }
            if text.hasSuffix("..."), nsText.length >= 3 {
                let stemLength = nsText.length - 3
                let stem = nsText.substring(to: stemLength)
                if fullCopyText.hasPrefix(stem) {
                    let start = min(safeRange.location, stemLength)
                    return (fullCopyText as NSString).substring(from: start)
                }
            }
            let normalizedFull = fullCopyText.replacingOccurrences(of: "\r\n", with: "\n")
            let nsFull = normalizedFull as NSString
            if nsFull.length == nsText.length, safeRange.location < nsFull.length {
                return nsFull.substring(from: safeRange.location)
            }
            if safeRange.location < nsFull.length,
               nsText.substring(to: safeRange.location) == nsFull.substring(to: safeRange.location)
            {
                return nsFull.substring(from: safeRange.location)
            }
        }
        return nsText.substring(with: safeRange)
    }

    var isFrozenOrCovered: Bool {
        if isDialogCovered {
            return true
        }
        if allowsMenuModalInteraction {
            return interfaceLayerContext.isCovered
        }
        return interfaceLayerContext.isFrozen || interfaceLayerContext.isCovered
    }

    var canInteract: Bool {
        guard isSelectable, !text.isEmpty, !isFrozenOrCovered, !isHiddenOrHasHiddenAncestor else {
            return false
        }
        if let mainWindow = window as? CueSeekerMainWindow {
            if mainWindow.isBehindDialog(self) {
                return false
            }
            if mainWindow.isFocusLocked(), !allowsMenuModalInteraction {
                return false
            }
            if mainWindow.isWorkbenchCovered(), interfaceLayerContext.layer == .workbenchPage {
                return false
            }
        }
        return true
    }

    var subtitleTableTextSelectionInteraction: SubtitleTableTextSelectionInteraction {
        canInteract ? .interactive : .nonInteractive
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        textContainer.lineFragmentPadding = 0
        layoutManager.usesFontLeading = true
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(
        text: String,
        fullCopyText: String? = nil,
        font: NSFont,
        textColor: NSColor,
        alignment: NSTextAlignment,
        lineLimit: Int?,
        lineHeight: CGFloat? = nil,
        truncatesTail: Bool,
        isSelectable: Bool,
        preferredPointerShape: PointerShape,
        showsUnderline: Bool,
        allowsMenuModalInteraction: Bool = false,
        onTap: (() -> Void)?,
        interfaceLayerContext: InterfaceLayerContext,
        dialogID: WorkbenchDialogAccessibilityID? = nil,
        isDialogCovered: Bool = false
    ) {
        let textChanged = self.text != text || self.fullCopyText != fullCopyText
        let styleChanged = self.font != font
            || self.textColor != textColor
            || self.alignment != alignment
            || self.lineLimit != lineLimit
            || self.lineHeight != lineHeight
            || self.truncatesTail != truncatesTail
            || self.isSelectable != isSelectable
            || self.preferredPointerShape != preferredPointerShape
            || self.showsUnderline != showsUnderline
            || self.allowsMenuModalInteraction != allowsMenuModalInteraction
        let layerChanged = self.interfaceLayerContext.layer != interfaceLayerContext.layer
            || self.interfaceLayerContext.isCovered != interfaceLayerContext.isCovered
            || self.interfaceLayerContext.isFrozen != interfaceLayerContext.isFrozen
            || self.dialogID != dialogID
            || self.isDialogCovered != isDialogCovered

        self.text = text
        self.fullCopyText = fullCopyText
        self.font = font
        self.textColor = textColor
        self.alignment = alignment
        self.lineLimit = lineLimit
        self.lineHeight = lineHeight
        self.truncatesTail = truncatesTail
        self.isSelectable = isSelectable
        self.preferredPointerShape = preferredPointerShape
        self.showsUnderline = showsUnderline
        self.allowsMenuModalInteraction = allowsMenuModalInteraction
        self.onTap = onTap
        self.interfaceLayerContext = interfaceLayerContext
        self.dialogID = dialogID
        self.isDialogCovered = isDialogCovered

        if textChanged || !canInteract {
            clearSelection(notifyCoordinator: true)
        }

        if textChanged || styleChanged || layerChanged {
            needsTextLayout = true
            updateTextLayout()
            window?.invalidateCursorRects(for: self)
            needsDisplay = true
        }
    }

    override func setFrameSize(_ newSize: NSSize) {
        let oldSize = frame.size
        super.setFrameSize(newSize)
        if oldSize != newSize {
            needsTextLayout = true
            updateTextLayout()
            window?.invalidateCursorRects(for: self)
            needsDisplay = true
        }
    }

    func prepareLayoutForFlow() {
        if needsTextLayout || textStorage.length != textLengthUTF16 {
            updateTextLayout()
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil {
            clearSelection(notifyCoordinator: true)
            WorkbenchStaticTextSelectionCoordinator.shared.unregister(self)
        } else {
            updateTextLayout()
            window?.invalidateCursorRects(for: self)
            if allowsMenuModalInteraction {
                Task { @MainActor [weak self] in
                    guard let self,
                          self.allowsMenuModalInteraction,
                          self.canInteract,
                          let window = self.window,
                          window.firstResponder == nil || window.firstResponder === window
                    else {
                        return
                    }
                    _ = window.makeFirstResponder(self)
                }
            }
        }
    }

    override func viewDidHide() {
        super.viewDidHide()
        clearSelection(notifyCoordinator: true)
    }

    override func resetCursorRects() {
        if AppPointerShape.manages(window) {
            addCursorRect(visibleRect, cursor: AppPointerShape.rectCursor)
        } else if canInteract {
            updateTextLayout()
            let origin = textOrigin()
            for rect in lineUsedRects(at: origin) {
                let clipped = rect.intersection(bounds)
                if !clipped.isNull, clipped.width > 0, clipped.height > 0 {
                    addCursorRect(clipped, cursor: preferredPointerShape.cursor)
                }
            }
        } else {
            super.resetCursorRects()
        }
    }

    func pointerShape(atWindowPoint windowPoint: CGPoint) -> PointerShape {
        guard canInteract else {
            return .arrow
        }
        let point = convert(windowPoint, from: nil)
        guard bounds.contains(point) else {
            return .arrow
        }
        if onTap != nil || lineLimit == 1 || containsText(at: point) {
            return preferredPointerShape
        }
        return .arrow
    }

    func containsWindowPoint(_ windowPoint: CGPoint) -> Bool {
        guard window != nil else { return false }
        let point = convert(windowPoint, from: nil)
        return bounds.contains(point)
    }

    func visibleWindowClipRect() -> CGRect? {
        guard let window,
              !isHiddenOrHasHiddenAncestor,
              bounds.width > 0,
              bounds.height > 0
        else {
            return nil
        }
        var rect = window.contentView.map {
            $0.convert($0.bounds, to: nil).standardized
        } ?? convert(bounds, to: nil).standardized
        var current = superview
        while !rect.isNull, !rect.isEmpty, let ancestor = current {
            guard !ancestor.isHidden, ancestor.alphaValue > 0 else {
                return nil
            }
            if ancestor is NSClipView
                || ancestor is NSScrollView
                || ancestor is SubtitleTablePageChromeViewportView
            {
                let clipRect = ancestor.convert(ancestor.bounds, to: nil).standardized
                rect = rect.intersection(clipRect)
            }
            if let pageHost = ancestor as? SubtitleTablePageChromeHostingView,
               let pageViewport = pageHost.superview as? SubtitleTablePageChromeViewportView,
               let myIndex = pageViewport.subviews.firstIndex(of: pageHost)
            {
                for sibling in pageViewport.subviews[(myIndex + 1)...] {
                    guard sibling is SubtitleTablePageChromeHostingView,
                          !sibling.isHidden,
                          sibling.alphaValue > 0
                    else {
                        continue
                    }
                    let occluder = sibling.convert(sibling.bounds, to: nil).standardized
                    if !occluder.isNull, !occluder.isEmpty, rect.intersects(occluder) {
                        if occluder.minY <= rect.maxY, occluder.maxY >= rect.maxY {
                            rect.size.height = max(0, occluder.minY - rect.minY)
                        }
                    }
                }
            }
            current = ancestor.superview
        }
        return (rect.isNull || rect.isEmpty) ? nil : rect
    }

    func windowSelectionHitRect() -> CGRect? {
        guard let clipRect = visibleWindowClipRect() else {
            return nil
        }
        let raw = convert(bounds.insetBy(dx: -4, dy: -2), to: nil).standardized
        let clipped = raw.intersection(clipRect)
        return (clipped.isNull || clipped.isEmpty) ? nil : clipped
    }

    func setFlowSelectedRange(_ range: NSRange?) {
        let normalized: NSRange? = {
            guard let range, range.length > 0 else { return nil }
            let safe = NSIntersectionRange(range, NSRange(location: 0, length: textLengthUTF16))
            return safe.length > 0 ? safe : nil
        }()
        if selectedRange != normalized {
            selectedRange = normalized
            needsDisplay = true
        }
    }

    // MARK: - Mouse & Keyboard Handling

    override func mouseDown(with event: NSEvent) {
        guard canInteract else {
            super.mouseDown(with: event)
            return
        }
        prepareLayoutForFlow()
        let point = convert(event.locationInWindow, from: nil)
        let offset = utf16Offset(at: point)
        let clickCount = max(1, event.clickCount)

        startWindowPoint = event.locationInWindow
        activeClickCount = clickCount
        isTrackingMouse = true

        let initialSelection: NSRange?
        if onTap != nil {
            anchorRange = NSRange(location: offset, length: 0)
            initialSelection = nil
            didDrag = false
        } else if clickCount >= 3 {
            let fullRange = NSRange(location: 0, length: textStorage.length)
            anchorRange = fullRange
            initialSelection = fullRange.length > 0 ? fullRange : nil
            didDrag = true
        } else if clickCount == 2 {
            let word = wordRange(at: offset)
            anchorRange = word
            initialSelection = word.length > 0 ? word : nil
            didDrag = true
        } else {
            anchorRange = NSRange(location: offset, length: 0)
            initialSelection = nil
            didDrag = false
        }

        selectedRange = initialSelection
        WorkbenchStaticTextSelectionCoordinator.shared.prepareDirectMouseDown(
            in: self,
            startWindowPoint: event.locationInWindow,
            clickCount: clickCount,
            initialAnchorRange: initialSelection
        )
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard isTrackingMouse else {
            super.mouseDragged(with: event)
            return
        }
        guard canInteract else {
            clearSelection(notifyCoordinator: true)
            return
        }
        let windowPoint = event.locationInWindow
        if !didDrag {
            let distance = hypot(
                windowPoint.x - startWindowPoint.x,
                windowPoint.y - startWindowPoint.y
            )
            guard distance >= Self.dragThreshold else {
                return
            }
            didDrag = true
        }

        if window is CueSeekerWindow {
            WorkbenchStaticTextSelectionCoordinator.shared.updateDirectDrag(
                from: self,
                startWindowPoint: startWindowPoint,
                currentWindowPoint: windowPoint,
                clickCount: activeClickCount,
                initialAnchorRange: anchorRange
            )
        } else {
            _ = autoscroll(with: event)
            updateSelectionForDrag(at: convert(windowPoint, from: nil))
        }
    }

    override func mouseUp(with event: NSEvent) {
        guard isTrackingMouse else {
            super.mouseUp(with: event)
            return
        }
        isTrackingMouse = false
        guard canInteract else {
            clearSelection(notifyCoordinator: true)
            return
        }

        let windowPoint = event.locationInWindow
        if !didDrag {
            let distance = hypot(
                windowPoint.x - startWindowPoint.x,
                windowPoint.y - startWindowPoint.y
            )
            if distance >= Self.dragThreshold {
                didDrag = true
                if window is CueSeekerWindow {
                    WorkbenchStaticTextSelectionCoordinator.shared.updateDirectDrag(
                        from: self,
                        startWindowPoint: startWindowPoint,
                        currentWindowPoint: windowPoint,
                        clickCount: activeClickCount,
                        initialAnchorRange: anchorRange
                    )
                }
            }
        }

        let point = convert(windowPoint, from: nil)
        if didDrag {
            if window is CueSeekerWindow {
                WorkbenchStaticTextSelectionCoordinator.shared.endDirectDrag(
                    from: self,
                    currentWindowPoint: windowPoint
                )
            } else {
                if activeClickCount == 1 || onTap != nil {
                    updateSelectionForDrag(at: point)
                }
                if !hasSelection {
                    WorkbenchStaticTextSelectionCoordinator.shared.clearSelection()
                }
            }
            return
        }

        WorkbenchStaticTextSelectionCoordinator.shared.clearSelection()
        if let onTap, bounds.insetBy(dx: -2, dy: -2).contains(point) {
            onTap()
        }
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.type == .keyDown {
            let flags = event.modifierFlags
                .intersection(.deviceIndependentFlagsMask)
                .subtracting([.numericPad, .function])
            if flags == .command,
               event.charactersIgnoringModifiers?.lowercased() == "c" || event.keyCode == 8,
               WorkbenchStaticTextSelectionCoordinator.shared.canCopySelection(in: window)
            {
                return WorkbenchStaticTextSelectionCoordinator.shared.copySelection(in: window)
            }
        }
        return super.performKeyEquivalent(with: event)
    }

    @IBAction func copy(_ sender: Any?) {
        _ = WorkbenchStaticTextSelectionCoordinator.shared.copySelection(in: window)
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(NSText.copy(_:)) {
            return WorkbenchStaticTextSelectionCoordinator.shared.canCopySelection(in: window)
        }
        return true
    }

    func selectAllText() {
        guard canInteract else { return }
        WorkbenchStaticTextSelectionCoordinator.shared.beginSingleNodeInteraction(in: self)
        _ = window?.makeFirstResponder(self)
        updateTextLayout()
        let fullRange = NSRange(location: 0, length: textStorage.length)
        anchorRange = fullRange
        selectedRange = fullRange.length > 0 ? fullRange : nil
        needsDisplay = true
    }

    func selectRangeForTesting(_ range: NSRange) {
        guard canInteract else { return }
        WorkbenchStaticTextSelectionCoordinator.shared.beginSingleNodeInteraction(in: self)
        _ = window?.makeFirstResponder(self)
        updateTextLayout()
        let safeRange = NSIntersectionRange(
            range,
            NSRange(location: 0, length: textStorage.length)
        )
        anchorRange = safeRange
        selectedRange = safeRange.length > 0 ? safeRange : nil
        needsDisplay = true
    }

    func clearSelection(notifyCoordinator: Bool) {
        isTrackingMouse = false
        didDrag = false
        let hadSelection = selectedRange != nil
        selectedRange = nil
        if notifyCoordinator {
            WorkbenchStaticTextSelectionCoordinator.shared.unregister(self)
        }
        if hadSelection {
            needsDisplay = true
        }
    }

    // MARK: - Drawing & TextKit Layout

    override func draw(_ dirtyRect: NSRect) {
        guard !text.isEmpty else { return }
        updateTextLayout()
        let origin = textOrigin()
        let glyphRange = layoutManager.glyphRange(for: textContainer)
        guard glyphRange.length > 0 else { return }

        if let selectedRange, selectedRange.length > 0 {
            NSColor.selectedTextBackgroundColor.setFill()
            for rect in selectionRects(forUTF16Range: selectedRange, at: origin) {
                rect.intersection(bounds).fill()
            }
        }

        if showsUnderline {
            drawUnderline(
                at: origin,
                color: textColor,
                thickness: WorkbenchControlMetrics.redesignInteractiveTextUnderlineThickness,
                offset: WorkbenchControlMetrics.redesignInteractiveTextUnderlineOffset,
                backingScaleFactor: window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2.0
            )
        }

        layoutManager.drawGlyphs(forGlyphRange: glyphRange, at: origin)
    }

    private func updateTextLayout() {
        let paragraphStyle = NSMutableParagraphStyle()
        let availableWidth = max(0, bounds.width)
        if let lineHeight, lineHeight > 0 {
            paragraphStyle.minimumLineHeight = lineHeight
            paragraphStyle.maximumLineHeight = lineHeight
        }

        if lineLimit == 1 {
            let naturalWidth = Self.measuredSingleLineWidth(for: text, font: font)
            let isTruncated = truncatesTail && availableWidth > 0 && availableWidth < naturalWidth - 1.5
            paragraphStyle.alignment = isTruncated ? alignment : .left
            paragraphStyle.lineBreakMode = isTruncated ? .byTruncatingTail : .byClipping
            paragraphStyle.tighteningFactorForTruncation = 0

            textContainer.maximumNumberOfLines = 1
            textContainer.lineBreakMode = isTruncated ? .byTruncatingTail : .byClipping
            textContainer.size = CGSize(
                width: isTruncated ? availableWidth : max(availableWidth, naturalWidth + 8),
                height: .greatestFiniteMagnitude
            )
        } else {
            paragraphStyle.alignment = alignment
            paragraphStyle.lineBreakMode = .byWordWrapping
            paragraphStyle.tighteningFactorForTruncation = 0

            let maxLines = lineLimit ?? 0
            textContainer.maximumNumberOfLines = maxLines
            textContainer.lineBreakMode = (maxLines > 0 && truncatesTail) ? .byTruncatingTail : .byWordWrapping
            textContainer.size = CGSize(
                width: max(0, availableWidth + 1.5),
                height: .greatestFiniteMagnitude
            )
        }

        var attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor,
            .paragraphStyle: paragraphStyle,
        ]
        let baselineOffset = Self.resolvedBaselineOffset(for: font, lineHeight: lineHeight)
        if baselineOffset > 0 {
            attributes[.baselineOffset] = baselineOffset
        }
        let attributed = NSAttributedString(
            string: text,
            attributes: attributes
        )
        textStorage.setAttributedString(attributed)
        layoutManager.ensureLayout(for: textContainer)
        needsTextLayout = false
    }

    nonisolated static func resolvedBaselineOffset(
        for font: NSFont,
        lineHeight: CGFloat?
    ) -> CGFloat {
        guard let lineHeight, lineHeight > 0 else { return 0 }
        let naturalLineHeight = ceil(font.ascender - font.descender + font.leading)
        return max(0, (lineHeight - naturalLineHeight) / 2)
    }

    nonisolated static func measuredSingleLineWidth(for text: String, font: NSFont) -> CGFloat {
        guard !text.isEmpty else { return 0 }
        return ceil((text as NSString).size(withAttributes: [.font: font]).width)
    }

    nonisolated static func measuredMultilineHeight(
        for text: String,
        font: NSFont,
        lineHeight: CGFloat? = nil,
        lineLimit: Int? = nil,
        truncatesTail: Bool = true,
        width: CGFloat
    ) -> CGFloat {
        let resolvedLineHeight = (lineHeight ?? 0) > 0 ? lineHeight : nil
        let defaultHeight = resolvedLineHeight ?? ceil(NSLayoutManager().defaultLineHeight(for: font))
        guard !text.isEmpty, width > 0 else {
            return defaultHeight
        }
        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(
            size: CGSize(width: max(0, width + 1.5), height: .greatestFiniteMagnitude)
        )
        let maxLines = max(0, lineLimit ?? 0)
        textContainer.lineFragmentPadding = 0
        textContainer.maximumNumberOfLines = maxLines
        textContainer.lineBreakMode = (maxLines > 0 && truncatesTail) ? .byTruncatingTail : .byWordWrapping
        layoutManager.usesFontLeading = true
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .left
        paragraphStyle.lineBreakMode = .byWordWrapping
        paragraphStyle.tighteningFactorForTruncation = 0
        if let resolvedLineHeight {
            paragraphStyle.minimumLineHeight = resolvedLineHeight
            paragraphStyle.maximumLineHeight = resolvedLineHeight
        }
        var attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: paragraphStyle,
        ]
        let baselineOffset = resolvedBaselineOffset(for: font, lineHeight: resolvedLineHeight)
        if baselineOffset > 0 {
            attributes[.baselineOffset] = baselineOffset
        }
        textStorage.setAttributedString(
            NSAttributedString(
                string: text,
                attributes: attributes
            )
        )
        layoutManager.ensureLayout(for: textContainer)
        let usedHeight = ceil(layoutManager.usedRect(for: textContainer).height)
        return max(defaultHeight, usedHeight)
    }

    private func textOrigin() -> CGPoint {
        let usedRect = layoutManager.usedRect(for: textContainer)
        let originY = lineLimit == 1
            ? max(0, (bounds.height - usedRect.height) / 2)
            : (lineHeight != nil ? 0 : max(0, (bounds.height - usedRect.height) / 2))
        if lineLimit == 1, textContainer.lineBreakMode == .byClipping {
            switch alignment {
            case .center:
                return CGPoint(
                    x: (bounds.width - usedRect.width) / 2 - usedRect.minX,
                    y: originY
                )
            case .right:
                return CGPoint(
                    x: bounds.width - usedRect.maxX,
                    y: originY
                )
            default:
                return CGPoint(x: 0, y: originY)
            }
        }
        return CGPoint(x: 0, y: originY)
    }

    private func updateSelectionForDrag(at point: CGPoint) {
        let offset = utf16Offset(at: point)
        let nextRange: NSRange?
        if activeClickCount >= 3, onTap == nil {
            let full = NSRange(location: 0, length: textStorage.length)
            nextRange = full.length > 0 ? full : nil
        } else if activeClickCount == 2, onTap == nil {
            let targetWord = wordRange(at: offset)
            let lower = min(anchorRange.location, targetWord.location)
            let upper = max(NSMaxRange(anchorRange), NSMaxRange(targetWord))
            nextRange = upper > lower ? NSRange(location: lower, length: upper - lower) : nil
        } else {
            let lower = min(anchorRange.location, offset)
            let upper = max(NSMaxRange(anchorRange), offset)
            nextRange = upper > lower ? NSRange(location: lower, length: upper - lower) : nil
        }
        if selectedRange != nextRange {
            selectedRange = nextRange
            needsDisplay = true
        }
    }

    func utf16Offset(at point: CGPoint) -> Int {
        prepareLayoutForFlow()
        guard textStorage.length > 0 else { return 0 }
        let validGlyphRange = layoutManager.glyphRange(for: textContainer)
        guard validGlyphRange.length > 0 else { return 0 }
        let origin = textOrigin()
        let lines = lineFragmentLayouts(at: origin)
        guard let firstLine = lines.first, let lastLine = lines.last else {
            return 0
        }

        // Strict reading-flow vertical clamping: zero horizontal tolerance band outside [firstLine.minY, lastLine.maxY].
        if point.y < firstLine.usedRect.minY {
            return 0
        }
        if point.y > lastLine.usedRect.maxY {
            return textStorage.length
        }

        var targetIndex = 0
        for index in lines.indices {
            if point.y < lines[index].usedRect.minY {
                return min(max(0, lines[index].charRange.location), textStorage.length)
            }
            if point.y <= lines[index].usedRect.maxY {
                targetIndex = index
                break
            }
            targetIndex = index
        }

        let targetLine = lines[targetIndex]
        if point.x <= targetLine.usedRect.minX {
            return min(max(0, targetLine.charRange.location), textStorage.length)
        }
        if point.x >= targetLine.usedRect.maxX {
            if targetIndex == lines.count - 1 {
                return textStorage.length
            }
            return lineSelectionEndOffset(for: targetLine)
        }

        let localPoint = CGPoint(
            x: point.x - origin.x,
            y: targetLine.usedRect.midY - origin.y
        )
        var fraction: CGFloat = 0
        let rawGlyphIndex = layoutManager.glyphIndex(
            for: localPoint,
            in: textContainer,
            fractionOfDistanceThroughGlyph: &fraction
        )
        let glyphIndex = min(
            max(rawGlyphIndex, targetLine.glyphRange.location),
            NSMaxRange(targetLine.glyphRange) - 1
        )
        if targetLine.hasTruncatedTail,
           glyphIndex == NSMaxRange(targetLine.glyphRange) - 1,
           fraction >= 0.5
        {
            return textStorage.length
        }
        let characterRange = layoutManager.characterRange(
            forGlyphRange: NSRange(location: glyphIndex, length: 1),
            actualGlyphRange: nil
        )
        let characterIndex = fraction >= 0.5
            ? NSMaxRange(characterRange)
            : characterRange.location
        return min(max(0, characterIndex), textStorage.length)
    }

    private func lineSelectionEndOffset(for line: LineFragmentLayout) -> Int {
        let nsText = textStorage.string as NSString
        var end = min(NSMaxRange(line.charRange), nsText.length)
        while end > line.charRange.location {
            let scalar = nsText.character(at: end - 1)
            if scalar == 0x0A || scalar == 0x0D {
                end -= 1
            } else {
                break
            }
        }
        return min(max(0, end), nsText.length)
    }

    func wordRange(at utf16Offset: Int) -> NSRange {
        prepareLayoutForFlow()
        guard textStorage.length > 0 else {
            return NSRange(location: 0, length: 0)
        }
        let clampedIndex = min(max(0, utf16Offset), textStorage.length - 1)
        return textStorage.doubleClick(at: clampedIndex)
    }

    private func containsText(at point: CGPoint) -> Bool {
        let origin = textOrigin()
        return lineUsedRects(at: origin).contains {
            $0.insetBy(dx: -2, dy: -2).contains(point)
        }
    }

    func selectionRects(forUTF16Range range: NSRange, at origin: CGPoint? = nil) -> [CGRect] {
        prepareLayoutForFlow()
        let resolvedOrigin = origin ?? textOrigin()
        let safeRange = NSIntersectionRange(
            range,
            NSRange(location: 0, length: textStorage.length)
        )
        guard safeRange.length > 0 else { return [] }
        let validGlyphRange = layoutManager.glyphRange(for: textContainer)
        guard validGlyphRange.length > 0 else { return [] }

        var glyphRange = layoutManager.glyphRange(
            forCharacterRange: safeRange,
            actualCharacterRange: nil
        )
        glyphRange = NSIntersectionRange(glyphRange, validGlyphRange)
        if NSMaxRange(safeRange) >= textStorage.length {
            let lastGlyph = NSMaxRange(validGlyphRange) - 1
            let truncated = layoutManager.truncatedGlyphRange(inLineFragmentForGlyphAt: lastGlyph)
            if truncated.location != NSNotFound {
                let startGlyph = glyphRange.length > 0
                    ? glyphRange.location
                    : lastGlyph
                glyphRange = NSRange(
                    location: min(startGlyph, lastGlyph),
                    length: NSMaxRange(validGlyphRange) - min(startGlyph, lastGlyph)
                )
            }
        }
        guard glyphRange.length > 0 else { return [] }

        var rects: [CGRect] = []
        layoutManager.enumerateEnclosingRects(
            forGlyphRange: glyphRange,
            withinSelectedGlyphRange: NSRange(location: NSNotFound, length: 0),
            in: textContainer
        ) { rect, _ in
            rects.append(rect.offsetBy(dx: resolvedOrigin.x, dy: resolvedOrigin.y))
        }
        return rects
    }

    private func lineFragmentLayouts(at origin: CGPoint? = nil) -> [LineFragmentLayout] {
        prepareLayoutForFlow()
        let resolvedOrigin = origin ?? textOrigin()
        let validGlyphRange = layoutManager.glyphRange(for: textContainer)
        guard validGlyphRange.length > 0 else { return [] }
        var fragments: [LineFragmentLayout] = []
        var glyphIndex = validGlyphRange.location
        while glyphIndex < NSMaxRange(validGlyphRange) {
            var lineRange = NSRange(location: 0, length: 0)
            let usedRect = layoutManager.lineFragmentUsedRect(
                forGlyphAt: glyphIndex,
                effectiveRange: &lineRange
            )
            let visibleLineGlyphs = NSIntersectionRange(lineRange, validGlyphRange)
            if usedRect.width > 0, usedRect.height > 0, visibleLineGlyphs.length > 0 {
                let charRange = layoutManager.characterRange(
                    forGlyphRange: visibleLineGlyphs,
                    actualGlyphRange: nil
                )
                let truncated = layoutManager.truncatedGlyphRange(
                    inLineFragmentForGlyphAt: visibleLineGlyphs.location
                )
                fragments.append(
                    LineFragmentLayout(
                        usedRect: usedRect.offsetBy(dx: resolvedOrigin.x, dy: resolvedOrigin.y),
                        glyphRange: visibleLineGlyphs,
                        charRange: charRange,
                        hasTruncatedTail: truncated.location != NSNotFound && truncated.length > 0
                    )
                )
            }
            guard lineRange.length > 0 else { break }
            glyphIndex = NSMaxRange(lineRange)
        }
        return fragments
    }

    func lineUsedRects(at origin: CGPoint? = nil) -> [CGRect] {
        lineFragmentLayouts(at: origin).map(\.usedRect)
    }

    func underlineRects(
        at origin: CGPoint? = nil,
        thickness: CGFloat = WorkbenchControlMetrics.redesignInteractiveTextUnderlineThickness,
        offset: CGFloat = WorkbenchControlMetrics.redesignInteractiveTextUnderlineOffset,
        backingScaleFactor: CGFloat
    ) -> [CGRect] {
        let resolvedOrigin = origin ?? textOrigin()
        let scale = max(1, backingScaleFactor)
        let lineThickness = max(1 / scale, thickness)
        let baselineOffset = Self.resolvedBaselineOffset(for: font, lineHeight: lineHeight)
        let validGlyphRange = layoutManager.glyphRange(for: textContainer)
        guard validGlyphRange.length > 0 else { return [] }

        var rects: [CGRect] = []
        var glyphIndex = validGlyphRange.location
        while glyphIndex < NSMaxRange(validGlyphRange) {
            var lineRange = NSRange(location: 0, length: 0)
            let usedRect = layoutManager.lineFragmentUsedRect(
                forGlyphAt: glyphIndex,
                effectiveRange: &lineRange
            )
            if usedRect.width > 0 {
                let baseline = resolvedOrigin.y
                    + usedRect.minY
                    + layoutManager.location(forGlyphAt: glyphIndex).y
                    - baselineOffset
                let y = ((baseline + offset) * scale).rounded() / scale
                let minX = floor((resolvedOrigin.x + usedRect.minX) * scale) / scale
                let maxX = ceil((resolvedOrigin.x + usedRect.maxX) * scale) / scale
                let rect = CGRect(
                    x: minX,
                    y: y,
                    width: max(0, maxX - minX),
                    height: lineThickness
                )
                if rect.width > 0 {
                    rects.append(rect)
                }
            }
            guard lineRange.length > 0 else { break }
            glyphIndex = NSMaxRange(lineRange)
        }
        return rects
    }

    private func drawUnderline(
        at origin: CGPoint,
        color: NSColor,
        thickness: CGFloat,
        offset: CGFloat,
        backingScaleFactor: CGFloat
    ) {
        color.setFill()
        for rect in underlineRects(
            at: origin,
            thickness: thickness,
            offset: offset,
            backingScaleFactor: backingScaleFactor
        ) {
            rect.fill()
        }
    }
}
