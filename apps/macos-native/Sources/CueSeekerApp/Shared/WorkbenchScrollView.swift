import AppKit
import SwiftUI

@MainActor
final class WorkbenchScrollViewController {
    enum PointerDocumentQueryResult: Equatable {
        case windowNotFocused
        case outsideViewport
        case inside(CGPoint)
    }

    var onVerticalScrollChange: ((_ offsetY: CGFloat, _ viewportHeight: CGFloat) -> Void)?
    fileprivate weak var bridge: WorkbenchScrollViewBridge?

    var currentOffsetY: CGFloat {
        bridge?.currentVerticalOffset ?? 0
    }

    var currentViewportHeight: CGFloat {
        bridge?.currentViewportHeight ?? 0
    }

    var scrollViewForTesting: NSScrollView? {
        bridge?.scrollViewForTesting
    }

    func revealVerticalRange(minY: CGFloat, maxY: CGFloat) {
        bridge?.revealVerticalRange(minY: minY, maxY: maxY)
    }

    func scrollToTop() {
        bridge?.scrollToTop()
    }

    func queryPointerInDocument() -> PointerDocumentQueryResult {
        bridge?.queryPointerInDocument() ?? .windowNotFocused
    }
}

@MainActor
struct WorkbenchScrollView<Content: View>: View {
    private let axes: Axis.Set
    private let scrollbarInset: CGFloat
    private let controller: WorkbenchScrollViewController?
    private let content: Content
    @StateObject private var bridge: WorkbenchScrollViewBridge

    init(
        _ axes: Axis.Set = .vertical,
        scrollbarInset: CGFloat = TableScrollbarPrimitiveMetrics.inset,
        controller: WorkbenchScrollViewController? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.axes = axes
        self.scrollbarInset = scrollbarInset
        self.controller = controller
        self.content = content()
        _bridge = StateObject(wrappedValue: WorkbenchScrollViewBridge())
    }

    var body: some View {
        ScrollView(axes, showsIndicators: false) {
            content
                .background(alignment: .topLeading) {
                    WorkbenchScrollViewBindingRepresentable(
                        axes: axes,
                        bridge: bridge,
                        controller: controller
                    )
                    .frame(width: 0, height: 0)
                }
        }
        .overlay {
            WorkbenchScrollViewOverlayRepresentable(
                axes: axes,
                bridge: bridge,
                scrollbarInset: scrollbarInset
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

@MainActor
final class WorkbenchScrollViewOverlayView: TableScrollbarOverlayView {
    private(set) weak var targetScrollViewForTesting: NSScrollView?

    func setTargetScrollView(_ scrollView: NSScrollView?) {
        targetScrollViewForTesting = scrollView
    }
}

@MainActor
private struct WorkbenchScrollViewBindingRepresentable: NSViewRepresentable {
    let axes: Axis.Set
    let bridge: WorkbenchScrollViewBridge
    let controller: WorkbenchScrollViewController?

    func makeNSView(context: Context) -> WorkbenchScrollViewBindingView {
        let view = WorkbenchScrollViewBindingView()
        bridge.register(bindingView: view, axes: axes, controller: controller)
        return view
    }

    func updateNSView(
        _ nsView: WorkbenchScrollViewBindingView,
        context: Context
    ) {
        bridge.register(bindingView: nsView, axes: axes, controller: controller)
    }

    static func dismantleNSView(
        _ nsView: WorkbenchScrollViewBindingView,
        coordinator: Void
    ) {
        nsView.bridge?.remove(bindingView: nsView)
        nsView.bridge = nil
    }
}

@MainActor
private struct WorkbenchScrollViewOverlayRepresentable: NSViewRepresentable {
    let axes: Axis.Set
    let bridge: WorkbenchScrollViewBridge
    let scrollbarInset: CGFloat
    /// A menu open over this layer, or a higher layer covering it, freezes the
    /// Scrollbar the same way it freezes the cards beside it.
    @Environment(\.interfaceLayerContext) private var layerContext

    func makeNSView(context: Context) -> WorkbenchScrollViewOverlayView {
        let view = WorkbenchScrollViewOverlayView()
        view.isInteractionFrozen = layerContext.isFrozen
        view.edgeInset = scrollbarInset
        bridge.register(overlayView: view, axes: axes)
        return view
    }

    func updateNSView(
        _ nsView: WorkbenchScrollViewOverlayView,
        context: Context
    ) {
        nsView.isInteractionFrozen = layerContext.isFrozen
        nsView.edgeInset = scrollbarInset
        bridge.register(overlayView: nsView, axes: axes)
    }

    static func dismantleNSView(
        _ nsView: WorkbenchScrollViewOverlayView,
        coordinator: Void
    ) {
        nsView.setTargetScrollView(nil)
        nsView.presentationProvider = { nil }
        nsView.onDrag = { _ in }
        nsView.onScrollWheel = nil
        nsView.isPresented = false
    }
}

@MainActor
private final class WorkbenchScrollViewBindingView: NSView {
    weak var bridge: WorkbenchScrollViewBridge?

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        bridge?.resolveScrollView(for: self)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        bridge?.resolveScrollView(for: self)
    }

    override func layout() {
        super.layout()
        bridge?.resolveScrollView(for: self)
    }
}

@MainActor
private final class WorkbenchScrollViewBridge: NSObject, ObservableObject {
    private weak var bindingView: WorkbenchScrollViewBindingView?
    private weak var scrollView: NSScrollView?
    private weak var overlayView: WorkbenchScrollViewOverlayView?
    private weak var observedDocumentView: NSView?
    private weak var controller: WorkbenchScrollViewController?
    private var axes: Axis.Set = .vertical
    private var isObserving = false
    private var lastReportedOffset: CGFloat = -1
    private var lastReportedViewportHeight: CGFloat = -1

    var scrollViewForTesting: NSScrollView? {
        scrollView
    }

    var currentVerticalOffset: CGFloat {
        guard let scrollView, let documentView = scrollView.documentView else {
            return 0
        }
        return verticalOffset(
            visibleRect: scrollView.documentVisibleRect,
            documentView: documentView
        )
    }

    var currentViewportHeight: CGFloat {
        scrollView?.documentVisibleRect.height ?? 0
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func register(
        bindingView: WorkbenchScrollViewBindingView,
        axes: Axis.Set,
        controller: WorkbenchScrollViewController?
    ) {
        self.axes = axes
        self.bindingView = bindingView
        self.controller = controller
        controller?.bridge = self
        bindingView.bridge = self
        resolveScrollView(for: bindingView)
    }

    func register(
        overlayView: WorkbenchScrollViewOverlayView,
        axes: Axis.Set
    ) {
        self.axes = axes
        self.overlayView = overlayView
        overlayView.presentationProvider = { [weak self] in
            self?.presentation()
        }
        overlayView.onDrag = { [weak self] event in
            self?.handleDrag(event)
        }
        overlayView.onScrollWheel = { [weak self] event in
            self?.scrollView?.scrollWheel(with: event)
        }
        activateIfReady()
    }

    func remove(bindingView: WorkbenchScrollViewBindingView) {
        guard self.bindingView === bindingView else { return }
        self.bindingView = nil
        detachScrollView()
    }

    func resolveScrollView(for bindingView: WorkbenchScrollViewBindingView) {
        guard self.bindingView === bindingView,
              let resolvedScrollView = bindingView.enclosingScrollView
        else {
            return
        }
        guard scrollView !== resolvedScrollView else {
            activateIfReady()
            return
        }
        detachScrollView()
        scrollView = resolvedScrollView
        activateIfReady()
    }

    private func activateIfReady() {
        guard let scrollView, let overlayView else { return }

        if !isObserving {
            scrollView.hasVerticalScroller = false
            scrollView.hasHorizontalScroller = false
            scrollView.autohidesScrollers = true
            startObserving(scrollView)
            isObserving = true
        }

        overlayView.setTargetScrollView(scrollView)
        updatePresentation()
    }

    private func startObserving(_ scrollView: NSScrollView) {
        scrollView.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(scrollGeometryDidChange(_:)),
            name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView
        )
        observeDocumentView(scrollView.documentView)
    }

    private func observeDocumentView(_ documentView: NSView?) {
        observedDocumentView = documentView
        documentView?.postsFrameChangedNotifications = true
        guard let documentView else { return }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(scrollGeometryDidChange(_:)),
            name: NSView.frameDidChangeNotification,
            object: documentView
        )
    }

    private func refreshDocumentObservation() {
        guard scrollView?.documentView !== observedDocumentView else { return }
        if let observedDocumentView {
            NotificationCenter.default.removeObserver(
                self,
                name: NSView.frameDidChangeNotification,
                object: observedDocumentView
            )
        }
        observeDocumentView(scrollView?.documentView)
    }

    private func detachScrollView() {
        NotificationCenter.default.removeObserver(self)
        overlayView?.setTargetScrollView(nil)
        overlayView?.isPresented = false
        observedDocumentView = nil
        isObserving = false
        scrollView = nil
    }

    @objc
    private func scrollGeometryDidChange(_ notification: Notification) {
        updatePresentation()
    }

    private func updatePresentation() {
        refreshDocumentObservation()
        if let controller, let scrollView, let documentView = scrollView.documentView {
            let visibleRect = scrollView.documentVisibleRect
            let offset = verticalOffset(visibleRect: visibleRect, documentView: documentView)
            let viewport = visibleRect.height
            if abs(offset - lastReportedOffset) > 0.1 || abs(viewport - lastReportedViewportHeight) > 0.1 {
                lastReportedOffset = offset
                lastReportedViewportHeight = viewport
                controller.onVerticalScrollChange?(offset, viewport)
            }
        }
        guard let overlayView else { return }
        let presentation = presentation()
        overlayView.isPresented = presentation?.vertical != nil
            || presentation?.horizontal != nil
        if overlayView.isPresented {
            overlayView.scrollbarMetricsDidChange()
        }
    }

    func revealVerticalRange(minY: CGFloat, maxY: CGFloat) {
        guard let scrollView,
              let documentView = scrollView.documentView
        else {
            return
        }
        let visibleRect = scrollView.documentVisibleRect
        let viewportHeight = visibleRect.height
        let contentHeight = documentView.frame.height
        guard contentHeight > viewportHeight, viewportHeight > 0 else {
            return
        }
        let currentOffset = verticalOffset(
            visibleRect: visibleRect,
            documentView: documentView
        )
        let targetOffset: CGFloat
        if minY < currentOffset {
            targetOffset = minY
        } else if maxY > currentOffset + viewportHeight {
            targetOffset = maxY - viewportHeight
        } else {
            return
        }
        let maximumOffset = max(0, contentHeight - viewportHeight)
        let clampedOffset = min(max(0, targetOffset), maximumOffset)
        guard abs(clampedOffset - currentOffset) > 0.01 else {
            return
        }
        var origin = scrollView.contentView.bounds.origin
        origin.y = documentView.isFlipped
            ? documentView.frame.minY + clampedOffset
            : documentView.frame.maxY - viewportHeight - clampedOffset
        scrollView.contentView.scroll(to: origin)
        scrollView.reflectScrolledClipView(scrollView.contentView)
        updatePresentation()
    }

    func scrollToTop() {
        guard let scrollView,
              let documentView = scrollView.documentView
        else {
            return
        }
        let viewportHeight = scrollView.documentVisibleRect.height
        var origin = scrollView.contentView.bounds.origin
        origin.y = documentView.isFlipped
            ? documentView.frame.minY
            : max(documentView.frame.minY, documentView.frame.maxY - viewportHeight)
        scrollView.contentView.scroll(to: origin)
        scrollView.reflectScrolledClipView(scrollView.contentView)
        updatePresentation()
    }

    func queryPointerInDocument() -> WorkbenchScrollViewController.PointerDocumentQueryResult {
        guard let scrollView,
              let documentView = scrollView.documentView,
              let window = scrollView.window
        else {
            return .windowNotFocused
        }
        let isWindowFocused: Bool
        if let cueSeekerWindow = window as? CueSeekerWindow {
            isWindowFocused = cueSeekerWindow.isFocusedForHover
        } else {
            isWindowFocused = NSApp.isActive && window.isKeyWindow
        }
        guard isWindowFocused else {
            return .windowNotFocused
        }
        var overrideLocation: CGPoint?
        var current: NSView? = scrollView
        while let candidate = current {
            if let source = candidate as? CueSeekerHostingViewLocationOverride,
               let point = source.mouseLocationOverrideForTesting {
                overrideLocation = point
                break
            }
            current = candidate.superview
        }
        if overrideLocation == nil {
            overrideLocation = (window.contentView as? CueSeekerHostingViewLocationOverride)?
                .mouseLocationOverrideForTesting
        }
        if overrideLocation == nil,
           (window as? CueSeekerWindow)?.isWindowFocusedOverrideForTesting == nil {
            guard NSWindow.windowNumber(
                at: NSEvent.mouseLocation,
                belowWindowWithWindowNumber: 0
            ) == window.windowNumber else {
                return .windowNotFocused
            }
        }
        let locationInWindow = overrideLocation ?? window.mouseLocationOutsideOfEventStream
        let clipView = scrollView.contentView
        let pointInClip = clipView.convert(locationInWindow, from: nil)
        guard clipView.bounds.contains(pointInClip) else {
            return .outsideViewport
        }
        let rawPoint = documentView.convert(locationInWindow, from: nil)
        let topDownY = documentView.isFlipped
            ? (rawPoint.y - documentView.bounds.minY)
            : (documentView.bounds.maxY - rawPoint.y)
        return .inside(CGPoint(x: rawPoint.x - documentView.bounds.minX, y: topDownY))
    }

    private func presentation() -> TableScrollbarPresentation? {
        guard let scrollView,
              let documentView = scrollView.documentView
        else {
            return nil
        }
        let visibleRect = scrollView.documentVisibleRect
        let contentSize = documentView.frame.size
        return TableScrollbarPresentation(
            vertical: axes.contains(.vertical)
                ? axisPresentation(
                    viewportLength: visibleRect.height,
                    contentLength: contentSize.height,
                    offset: verticalOffset(
                        visibleRect: visibleRect,
                        documentView: documentView
                    )
                )
                : nil,
            horizontal: axes.contains(.horizontal)
                ? axisPresentation(
                    viewportLength: visibleRect.width,
                    contentLength: contentSize.width,
                    offset: visibleRect.minX - documentView.frame.minX
                )
                : nil
        )
    }

    private func axisPresentation(
        viewportLength: CGFloat,
        contentLength: CGFloat,
        offset: CGFloat
    ) -> TableScrollbarAxisPresentation? {
        let maximumOffset = max(0, contentLength - viewportLength)
        guard maximumOffset > 0.5 else { return nil }
        return TableScrollbarAxisPresentation(
            visibleFraction: viewportLength / contentLength,
            positionFraction: offset / maximumOffset
        )
    }

    private func verticalOffset(
        visibleRect: CGRect,
        documentView: NSView
    ) -> CGFloat {
        if documentView.isFlipped {
            return visibleRect.minY - documentView.frame.minY
        }
        return documentView.frame.maxY - visibleRect.maxY
    }

    private func handleDrag(_ event: TableScrollbarDragEvent) {
        guard event.phase == .changed,
              let scrollView,
              let documentView = scrollView.documentView
        else {
            return
        }
        let visibleRect = scrollView.documentVisibleRect
        var origin = scrollView.contentView.bounds.origin
        switch event.axis {
        case .vertical:
            let maximumOffset = max(
                0,
                documentView.frame.height - visibleRect.height
            )
            let offset = maximumOffset * event.positionFraction
            origin.y = documentView.isFlipped
                ? documentView.frame.minY + offset
                : documentView.frame.maxY - visibleRect.height - offset
        case .horizontal:
            let maximumOffset = max(
                0,
                documentView.frame.width - visibleRect.width
            )
            origin.x = documentView.frame.minX
                + maximumOffset * event.positionFraction
        }
        scrollView.contentView.scroll(to: origin)
        scrollView.reflectScrolledClipView(scrollView.contentView)
        updatePresentation()
    }
}
