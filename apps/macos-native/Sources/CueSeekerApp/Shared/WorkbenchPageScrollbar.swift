import AppKit
import SwiftUI

/// Owner of the Scrollbars drawn over a Workbench page.
///
/// The table publishes its real scroll container here. The page draws the
/// vertical Scrollbar across the whole page, and the table's horizontal
/// Scrollbar over the table's own width — both bound to the same container.
@MainActor
final class WorkbenchPageScrollbar: ObservableObject {
    private weak var verticalOverlay: SubtitleTableScrollbarOverlayView?
    private weak var horizontalOverlay: SubtitleTableScrollbarOverlayView?
    private weak var scrollView: NSScrollView?
    private var isRedesign = false

    var onDragStateChanged: ((Bool) -> Void)?

    /// Height the table's horizontal Scrollbar keeps free at the bottom, so an
    /// outer page-level horizontal Scrollbar can take that place.
    var tableScrollbarBottomReserve: CGFloat = 0 {
        didSet {
            guard tableScrollbarBottomReserve != oldValue else { return }
            horizontalOverlay?.bottomReserve = tableScrollbarBottomReserve
        }
    }

    func overlayView(for axis: TableScrollbarAxis) -> SubtitleTableScrollbarOverlayView? {
        axis == .vertical ? verticalOverlay : horizontalOverlay
    }

    func attach(overlayView: SubtitleTableScrollbarOverlayView, axis: TableScrollbarAxis) {
        overlayView.visibleAxes = [axis]
        switch axis {
        case .vertical:
            verticalOverlay = overlayView
        case .horizontal:
            horizontalOverlay = overlayView
            overlayView.bottomReserve = tableScrollbarBottomReserve
        }
        overlayView.onDragStateChanged = { [weak self] isDragging in
            self?.onDragStateChanged?(isDragging)
        }
        applyBinding()
    }

    func detach(overlayView: SubtitleTableScrollbarOverlayView) {
        if verticalOverlay === overlayView { verticalOverlay = nil }
        if horizontalOverlay === overlayView { horizontalOverlay = nil }
        overlayView.onDragStateChanged = nil
        overlayView.scrollView = nil
        overlayView.isRedesign = false
    }

    func attach(scrollView: NSScrollView?, isRedesign: Bool) {
        self.scrollView = scrollView
        self.isRedesign = isRedesign
        applyBinding()
    }

    func detach(scrollView: NSScrollView) {
        guard self.scrollView === scrollView else { return }
        self.scrollView = nil
        applyBinding()
    }

    func metricsDidChange() {
        refreshCrossAxisReserves()
        verticalOverlay?.scrollMetricsDidChange()
        horizontalOverlay?.scrollMetricsDidChange()
    }

    /// Each axis keeps the crossing Scrollbar's slot free, the way a single
    /// two-axis Overlay used to.
    private func refreshCrossAxisReserves() {
        let presentation = verticalOverlay?.presentationProvider()
            ?? horizontalOverlay?.presentationProvider()
        let slot = TableScrollbarPrimitiveMetrics.size
            + TableScrollbarPrimitiveMetrics.inset
        verticalOverlay?.bottomReserve = presentation?.horizontal == nil
            ? 0
            : slot
        horizontalOverlay?.trailingReserve = presentation?.vertical == nil
            ? 0
            : slot
    }

    func setNeedsDisplay() {
        verticalOverlay?.needsDisplay = true
        horizontalOverlay?.needsDisplay = true
    }

    var drawsOverlayScrollbars: Bool {
        verticalOverlay?.isRedesign == true
            && verticalOverlay?.scrollView === scrollView
    }

    private func applyBinding() {
        for overlayView in [verticalOverlay, horizontalOverlay].compactMap({ $0 }) {
            overlayView.scrollView = isRedesign ? scrollView : nil
            overlayView.isRedesign = isRedesign && scrollView != nil
            overlayView.needsDisplay = true
        }
        refreshCrossAxisReserves()
    }
}

/// Renders one axis of the page-owned Scrollbars.
struct WorkbenchPageScrollbarOverlay: View {
    let scrollbar: WorkbenchPageScrollbar
    let axis: TableScrollbarAxis

    var body: some View {
        WorkbenchPageScrollbarRepresentable(scrollbar: scrollbar, axis: axis)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct WorkbenchPageScrollbarRepresentable: NSViewRepresentable {
    let scrollbar: WorkbenchPageScrollbar
    let axis: TableScrollbarAxis

    func makeNSView(context: Context) -> SubtitleTableScrollbarOverlayView {
        let view = SubtitleTableScrollbarOverlayView()
        scrollbar.attach(overlayView: view, axis: axis)
        return view
    }

    func updateNSView(
        _ nsView: SubtitleTableScrollbarOverlayView,
        context: Context
    ) {
        scrollbar.attach(overlayView: nsView, axis: axis)
        nsView.scrollMetricsDidChange()
    }

    static func dismantleNSView(
        _ nsView: SubtitleTableScrollbarOverlayView,
        coordinator: Void
    ) {
        nsView.onDragStateChanged = nil
        nsView.scrollView = nil
        nsView.isRedesign = false
    }
}

private struct WorkbenchPageScrollbarKey: EnvironmentKey {
    static let defaultValue: WorkbenchPageScrollbar? = nil
}

extension EnvironmentValues {
    var workbenchPageScrollbar: WorkbenchPageScrollbar? {
        get { self[WorkbenchPageScrollbarKey.self] }
        set { self[WorkbenchPageScrollbarKey.self] = newValue }
    }
}
