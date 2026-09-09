import AppKit
import SwiftUI

/// How far the Workbench page on screen is scrolled sideways.
///
/// Below the page content minimum width the page scrolls horizontally, and the
/// App top bar's function region is part of that same row, so it moves with the
/// page. The page's scroll view reports here and only the top bar observes this
/// object, so scrolling does not invalidate the page or the App shell.
@MainActor
final class WorkbenchPageScrollOffset: ObservableObject {
    @Published private(set) var horizontal: CGFloat = 0

    func report(horizontal offset: CGFloat) {
        let value = max(0, offset)
        guard abs(value - horizontal) >= 0.5 else {
            return
        }
        horizontal = value
    }
}

private struct WorkbenchPageScrollOffsetKey: EnvironmentKey {
    static let defaultValue: WorkbenchPageScrollOffset? = nil
}

extension EnvironmentValues {
    /// Set by the App shell around the Workbench pages; `nil` everywhere else,
    /// so a horizontal scroll view outside a page reports nothing.
    var workbenchPageScrollOffset: WorkbenchPageScrollOffset? {
        get { self[WorkbenchPageScrollOffsetKey.self] }
        set { self[WorkbenchPageScrollOffsetKey.self] = newValue }
    }
}

@MainActor
struct WorkbenchScrollView<Content: View>: View {
    private let axes: Axis.Set
    private let scrollbarInset: CGFloat
    private let content: Content
    @StateObject private var bridge: WorkbenchScrollViewBridge
    @Environment(\.workbenchPageScrollOffset) private var pageScrollOffset

    init(
        _ axes: Axis.Set = .vertical,
        scrollbarInset: CGFloat = TableScrollbarPrimitiveMetrics.inset,
        @ViewBuilder content: () -> Content
    ) {
        self.axes = axes
        self.scrollbarInset = scrollbarInset
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
                        pageScrollOffset: pageScrollOffset
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
    let pageScrollOffset: WorkbenchPageScrollOffset?

    func makeNSView(context: Context) -> WorkbenchScrollViewBindingView {
        let view = WorkbenchScrollViewBindingView()
        bridge.onHorizontalOffsetChange = horizontalOffsetReporter
        bridge.register(bindingView: view, axes: axes)
        return view
    }

    func updateNSView(
        _ nsView: WorkbenchScrollViewBindingView,
        context: Context
    ) {
        bridge.onHorizontalOffsetChange = horizontalOffsetReporter
        bridge.register(bindingView: nsView, axes: axes)
    }

    private var horizontalOffsetReporter: ((CGFloat) -> Void)? {
        guard let pageScrollOffset else {
            return nil
        }
        return { pageScrollOffset.report(horizontal: $0) }
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
    private var axes: Axis.Set = .vertical
    private var isObserving = false
    /// Set for the Workbench pages, so the App top bar's function region can
    /// move with the page it belongs to.
    var onHorizontalOffsetChange: ((CGFloat) -> Void)?

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func register(
        bindingView: WorkbenchScrollViewBindingView,
        axes: Axis.Set
    ) {
        self.axes = axes
        self.bindingView = bindingView
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
        reportHorizontalOffset()
        guard let overlayView else { return }
        let presentation = presentation()
        overlayView.isPresented = presentation?.vertical != nil
            || presentation?.horizontal != nil
        if overlayView.isPresented {
            overlayView.scrollbarMetricsDidChange()
        }
    }

    private func reportHorizontalOffset() {
        guard let onHorizontalOffsetChange,
              axes.contains(.horizontal),
              let scrollView,
              let documentView = scrollView.documentView
        else {
            return
        }
        onHorizontalOffsetChange(
            scrollView.documentVisibleRect.minX - documentView.frame.minX
        )
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
