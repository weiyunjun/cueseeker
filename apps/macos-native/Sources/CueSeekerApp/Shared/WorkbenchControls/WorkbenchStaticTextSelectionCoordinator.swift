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

    private struct WeakBox<Object: AnyObject> {
        weak var value: Object?
        init(_ value: Object? = nil) {
            self.value = value
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
        let containerID: ObjectIdentifier?
        let containerTopY: CGFloat
        let containerSubRank: Int
        let allowsInvisiblePeerMerge: Bool
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
        let containerID: ObjectIdentifier?
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
        weak var window: CueSeekerWindow?
        let startWindowPoint: CGPoint
        var lastWindowPoint: CGPoint
        weak var armedHitView: NSView?
        weak var armedControl: NSControl?
    }

    private struct ActiveFlowDragSession {
        let isExternalEntry: Bool
        weak var window: NSWindow?
        let scope: StaticTextFlowScope
        let startWindowPoint: CGPoint
        var latestWindowPoint: CGPoint
        let clickCount: Int
        let anchor: FlowAnchor
        weak var armedControl: NSControl?
    }

    private var selectedViewRefs: [WeakBox<WorkbenchSelectableTextNSView>] = []
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
            guard let view = ref.value, view.window != nil, view.hasSelection else {
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
        guard let activeDragSession,
              let window = activeDragSession.window,
              window.contentView != nil
        else {
            return false
        }
        return true
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
        return selectedViewRefs.contains { $0.value === view }
    }

    func beginSingleNodeInteraction(in view: WorkbenchSelectableTextNSView) {
        stopAutoScroll()
        externalArmedSession = nil
        activeDragSession = nil
        clearSelectedViews(except: view)
        activeResponderView = view
        activeScope = view.flowScope
        selectedViewRefs = [WeakBox(view)]
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
            ref.value?.clearSelection(notifyCoordinator: false)
        }
        previousResponder?.clearSelection(notifyCoordinator: false)
    }

    func unregister(_ view: WorkbenchSelectableTextNSView) {
        selectedViewRefs.removeAll { $0.value == nil || $0.value === view }
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
            selectedViewRefs = [WeakBox(view)]
            if clickCount >= 2,
               let window = view.window,
               let scope = view.flowScope
            {
                let anchor = FlowAnchor(
                    start: FlowCursor(view: view, utf16Offset: initialAnchorRange.location),
                    end: FlowCursor(view: view, utf16Offset: NSMaxRange(initialAnchorRange))
                )
                activeDragSession = ActiveFlowDragSession(
                    isExternalEntry: false,
                    window: window,
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
        guard let window = originView.window,
              let scope = originView.flowScope,
              originView.canInteract,
              let snapshot = buildFlowSnapshot(in: window, preferredScope: scope)
        else {
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
                window: window,
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
           let window = session.window,
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
           !Self.collectInteractiveViews(in: contentView).contains(where: \.allowsMenuModalInteraction)
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
            window: window,
            startWindowPoint: windowPoint,
            lastWindowPoint: windowPoint,
            armedHitView: hitView,
            armedControl: SubtitleTableTextSelectionHitTesting.enclosingEnabledControl(of: hitView)
        )
    }

    func handleWindowLeftMouseDragged(
        window: CueSeekerWindow,
        event: NSEvent
    ) -> WindowMouseEventDisposition {
        let currentWindowPoint = event.locationInWindow

        if var dragSession = activeDragSession, dragSession.isExternalEntry {
            guard dragSession.window === window,
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
            if dragSession.armedControl != nil,
               let redirected = SubtitleTableTextSelectionHitTesting.offscreenMouseEvent(
                   from: event,
                   type: .leftMouseDragged
               )
            {
                return .redirect(redirected)
            }
            return .consume
        }

        guard var armed = externalArmedSession else {
            return .passthrough
        }
        guard armed.window === window,
              window.contentView != nil,
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
              snapshot.flatViews.contains(where: { view in
                  guard let hitRect = view.windowSelectionHitRect() else { return false }
                  return Self.segmentIntersectsRect(from: previousPoint, to: currentWindowPoint, rect: hitRect)
                      || Self.segmentIntersectsRect(from: armed.startWindowPoint, to: currentWindowPoint, rect: hitRect)
              }),
              let anchorPos = project(windowPoint: armed.startWindowPoint, in: snapshot),
              let focusPos = project(windowPoint: currentWindowPoint, in: snapshot),
              hasNonEmptyFlowSelection(from: anchorPos, to: focusPos, in: snapshot)
        else {
            return .passthrough
        }

        externalArmedSession = nil
        let anchor = FlowAnchor(start: anchorPos, end: anchorPos)
        let ownerView = anchorPos.view
        activeScope = snapshot.scope
        activeResponderView = ownerView
        activeDragSession = ActiveFlowDragSession(
            isExternalEntry: true,
            window: window,
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
        NotificationCenter.default.post(
            name: .cueSeekerClearTextSelection,
            object: ownerView
        )
        if window.firstResponder !== ownerView {
            _ = window.makeFirstResponder(ownerView)
        }

        SubtitleTableTextSelectionHitTesting.cancelOriginatingControlPress(
            hitView: armed.armedHitView,
            control: armed.armedControl,
            in: window,
            triggerEvent: event
        )
        updateAutoScrollState()
        AppPointerShape.pointerMoved(in: window, at: currentWindowPoint)

        if armed.armedControl != nil,
           let redirected = SubtitleTableTextSelectionHitTesting.offscreenMouseEvent(
               from: event,
               type: .leftMouseDragged
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
        let hadArmedControl = dragSession.armedControl != nil
        if dragSession.window === window,
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
           let redirected = SubtitleTableTextSelectionHitTesting.offscreenMouseEvent(
               from: event,
               type: .leftMouseUp
           )
        {
            return .redirect(redirected)
        }
        return .consume
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
              let window = session.window,
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
              let window = session.window,
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

    private static func enclosingPageChromeChild(
        for view: NSView
    ) -> (viewport: SubtitleTablePageChromeViewportView, child: NSView)? {
        var current = view.superview
        while let ancestor = current {
            if let pageViewport = ancestor.superview as? SubtitleTablePageChromeViewportView {
                return (pageViewport, ancestor)
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

        let interactiveViews = Self.collectInteractiveViews(in: contentView).filter { selectable in
            selectable.prepareLayoutForFlow()
            return selectable.textLengthUTF16 > 0 && !selectable.lineUsedRects().isEmpty
        }

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

            let clipVisualRect = view.visibleWindowClipRect().map {
                Self.toVisualRect($0, refHeight: refHeight)
            }
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
                let docLineRect = Self.topDownRect(view.convert(firstLocalLine, to: docView), in: docView)
                let docBounds = Self.topDownRect(view.convert(view.bounds, to: docView), in: docView)
                rawNodes.append(
                    FlowNode(
                        view: view,
                        containerID: ObjectIdentifier(scrollView),
                        containerTopY: scrollVisualTopY,
                        containerSubRank: 1,
                        allowsInvisiblePeerMerge: true,
                        innerSortMinY: docLineRect.minY,
                        innerSortMaxY: docLineRect.maxY,
                        innerSortMinX: docBounds.minX,
                        innerSortMaxX: docBounds.maxX,
                        visualBounds: visualBounds,
                        visibleVisualLineRects: visibleVisualLines
                    )
                )
                continue
            }

            let isRetainedSelectionNode = view.hasSelection
                || activeDragSession?.anchor.start.view === view
                || activeDragSession?.anchor.end.view === view
            guard !visibleVisualLines.isEmpty || isRetainedSelectionNode else {
                continue
            }

            if let (pageViewport, pageChild) = Self.enclosingPageChromeChild(for: view) {
                let viewportWindowRect = pageViewport.convert(pageViewport.bounds, to: nil).standardized
                let viewportVisualTopY = refHeight - viewportWindowRect.maxY
                let childTopInViewport = pageViewport.isFlipped
                    ? pageChild.frame.minY
                    : (pageViewport.bounds.maxY - pageChild.frame.maxY)
                let childLineRect = Self.topDownRect(view.convert(firstLocalLine, to: pageChild), in: pageChild)
                let childBounds = Self.topDownRect(view.convert(view.bounds, to: pageChild), in: pageChild)
                rawNodes.append(
                    FlowNode(
                        view: view,
                        containerID: ObjectIdentifier(pageChild),
                        containerTopY: viewportVisualTopY,
                        containerSubRank: 2,
                        allowsInvisiblePeerMerge: false,
                        innerSortMinY: childTopInViewport + childLineRect.minY,
                        innerSortMaxY: childTopInViewport + childLineRect.maxY,
                        innerSortMinX: pageChild.frame.minX + childBounds.minX,
                        innerSortMaxX: pageChild.frame.minX + childBounds.maxX,
                        visualBounds: visualBounds,
                        visibleVisualLineRects: visibleVisualLines
                    )
                )
            } else {
                let firstVisualLine = visualLines[0]
                rawNodes.append(
                    FlowNode(
                        view: view,
                        containerID: nil,
                        containerTopY: firstVisualLine.minY,
                        containerSubRank: 0,
                        allowsInvisiblePeerMerge: false,
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
                lhs.containerSubRank,
                lhs.innerSortMinY,
                lhs.innerSortMinX
            )
            let rhsKey = (
                rhs.containerTopY,
                rhs.containerSubRank,
                rhs.innerSortMinY,
                rhs.innerSortMinX
            )
            return lhsKey < rhsKey
        }

        var rowGroups: [FlowRowGroup] = []
        for node in rawNodes {
            if let lastIndex = rowGroups.indices.last,
               rowGroups[lastIndex].containerID == node.containerID,
               (node.allowsInvisiblePeerMerge
                   || (!node.visibleVisualLineRects.isEmpty
                       && rowGroups[lastIndex].nodes.allSatisfy { !$0.visibleVisualLineRects.isEmpty }))
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
                    containerID: node.containerID,
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

        return FlowSnapshot(
            window: window,
            scope: resolvedScope,
            refHeight: refHeight,
            rowGroups: rowGroups,
            flatViews: flatViews,
            visibleRows: visibleRows
        )
    }

    private static func topDownRect(_ rawRect: CGRect, in container: NSView) -> CGRect {
        if container.isFlipped {
            return rawRect
        }
        return CGRect(
            x: rawRect.minX,
            y: container.bounds.maxY - rawRect.maxY,
            width: rawRect.width,
            height: rawRect.height
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
            return FlowCursor(
                view: firstNode.view,
                utf16Offset: Self.firstVisibleLineStartOffset(for: firstNode, refHeight: snapshot.refHeight)
            )
        }
        if p.y > lastRow.visibleMaxY {
            return FlowCursor(view: lastNode.view, utf16Offset: lastNode.view.textLengthUTF16)
        }

        for row in rows {
            if p.y < row.visibleMinY {
                let targetNode = row.nodes[0]
                return FlowCursor(
                    view: targetNode.view,
                    utf16Offset: Self.firstVisibleLineStartOffset(for: targetNode, refHeight: snapshot.refHeight)
                )
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
                        let nextPeer = peers[index + 1]
                        return FlowCursor(
                            view: nextPeer.view,
                            utf16Offset: Self.firstVisibleLineStartOffset(for: nextPeer, refHeight: snapshot.refHeight)
                        )
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

    private static func firstVisibleLineStartOffset(for node: FlowNode, refHeight: CGFloat) -> Int {
        guard !node.visibleVisualLineRects.isEmpty else { return 0 }
        let sampleVisualY = min(
            node.visibleMinY + 0.25,
            (node.visibleMinY + node.visibleMaxY) * 0.5
        )
        let sampleWindowPoint = CGPoint(
            x: node.visibleMinX - 1,
            y: refHeight - sampleVisualY
        )
        return node.view.utf16Offset(at: node.view.convert(sampleWindowPoint, from: nil))
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
            if let existing = ref.value, !activeSet.contains(ObjectIdentifier(existing)) {
                existing.setFlowSelectedRange(nil)
            }
        }

        var nextSelected: [WeakBox<WorkbenchSelectableTextNSView>] = []
        for (index, view) in snapshot.flatViews.enumerated() {
            let range = ranges[index]
            view.setFlowSelectedRange(range)
            if let range, range.length > 0 {
                nextSelected.append(WeakBox(view))
            }
        }
        selectedViewRefs = nextSelected
        activeScope = nextSelected.isEmpty ? activeDragSession?.scope : snapshot.scope
        if activeResponderView == nil || activeResponderView?.window == nil {
            activeResponderView = nextSelected.first?.value
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
            guard let view = ref.value, view !== keptView else { continue }
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

    private static func collectInteractiveViews(in rootView: NSView) -> [WorkbenchSelectableTextNSView] {
        var views: [WorkbenchSelectableTextNSView] = []
        func visit(_ view: NSView) {
            guard view.window != nil, !view.isHidden, view.alphaValue > 0 else {
                return
            }
            if let selectable = view as? WorkbenchSelectableTextNSView {
                if selectable.canInteract {
                    views.append(selectable)
                }
                return
            }
            for subview in view.subviews {
                visit(subview)
            }
        }
        visit(rootView)
        return views
    }

    private static func segmentIntersectsRect(
        from p0: CGPoint,
        to p1: CGPoint,
        rect: CGRect
    ) -> Bool {
        guard !rect.isNull, !rect.isEmpty else {
            return false
        }
        if rect.contains(p0) || rect.contains(p1) {
            return true
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
                    return false
                }
            } else {
                let t = check.q / check.p
                if check.p < 0 {
                    if t > tMax { return false }
                    if t > tMin { tMin = t }
                } else {
                    if t < tMin { return false }
                    if t < tMax { tMax = t }
                }
            }
        }
        return tMin <= tMax
    }

    func canCopySelection(in window: NSWindow?) -> Bool {
        serializedSelectionText(for: window) != nil
    }

    @discardableResult
    func copySelection(
        in window: NSWindow?,
        to pasteboard: NSPasteboard = .general
    ) -> Bool {
        guard let text = serializedSelectionText(for: window) else {
            return false
        }
        pasteboard.clearContents()
        return pasteboard.setString(text, forType: .string)
    }

    @discardableResult
    func copyActiveSelection(to pasteboard: NSPasteboard = .general) -> Bool {
        copySelection(in: liveSelectedViews.first(where: \.canInteract)?.window, to: pasteboard)
    }

    private func serializedSelectionText(for window: NSWindow?) -> String? {
        guard let window else { return nil }
        let matchingViews = liveSelectedViews.filter { $0.window === window && $0.canInteract }
        guard !matchingViews.isEmpty,
              let text = serializedSelectionText(in: window, fallbackViews: matchingViews),
              !text.isEmpty
        else {
            return nil
        }
        return text
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
