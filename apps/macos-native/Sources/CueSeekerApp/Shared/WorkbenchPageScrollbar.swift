import AppKit
import SwiftUI

/// Page-level owner of a Workbench table Scrollbar.
///
/// The table publishes its real scroll container here; the page hosts the
/// overlay. The table never draws a Scrollbar of its own.
@MainActor
final class WorkbenchPageScrollbar: ObservableObject {
    private(set) weak var overlayView: SubtitleTableScrollbarOverlayView?
    private weak var scrollView: NSScrollView?
    private var isRedesign = false
    private var isPublishScheduled = false

    var onDragStateChanged: ((Bool) -> Void)?

    /// Horizontal geometry of the bound scroll container, published so the page
    /// chrome can stop shrinking and scroll together with the table.
    @Published private(set) var horizontalContentWidth: CGFloat = 0
    @Published private(set) var horizontalOffset: CGFloat = 0

    func attach(overlayView: SubtitleTableScrollbarOverlayView) {
        self.overlayView = overlayView
        overlayView.onDragStateChanged = { [weak self] isDragging in
            self?.onDragStateChanged?(isDragging)
        }
        applyBinding()
    }

    func detach(overlayView: SubtitleTableScrollbarOverlayView) {
        guard self.overlayView === overlayView else { return }
        overlayView.onDragStateChanged = nil
        overlayView.scrollView = nil
        overlayView.isRedesign = false
        self.overlayView = nil
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
        overlayView?.scrollMetricsDidChange()
        publishHorizontalGeometry()
    }

    func setNeedsDisplay() {
        overlayView?.needsDisplay = true
    }

    var drawsOverlayScrollbars: Bool {
        overlayView?.isRedesign == true && overlayView?.scrollView === scrollView
    }

    private func applyBinding() {
        guard let overlayView else { return }
        overlayView.scrollView = isRedesign ? scrollView : nil
        overlayView.isRedesign = isRedesign && scrollView != nil
        overlayView.needsDisplay = true
        publishHorizontalGeometry()
    }

    /// Publishing runs on the next main-queue turn: AppKit reports geometry from
    /// inside SwiftUI's own update pass, and mutating observed state there would
    /// re-enter the view body that reads it.
    private func publishHorizontalGeometry() {
        guard !isPublishScheduled else { return }
        isPublishScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.isPublishScheduled = false
            let contentWidth = self.scrollView?.documentView?.frame.width ?? 0
            let offset = self.scrollView?.contentView.bounds.minX ?? 0
            if self.horizontalContentWidth != contentWidth {
                self.horizontalContentWidth = contentWidth
            }
            if self.horizontalOffset != offset {
                self.horizontalOffset = offset
            }
        }
    }
}

/// Renders the page-owned Scrollbar over the page viewport.
struct WorkbenchPageScrollbarOverlay: View {
    let scrollbar: WorkbenchPageScrollbar

    var body: some View {
        WorkbenchPageScrollbarRepresentable(scrollbar: scrollbar)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct WorkbenchPageScrollbarRepresentable: NSViewRepresentable {
    let scrollbar: WorkbenchPageScrollbar

    func makeNSView(context: Context) -> SubtitleTableScrollbarOverlayView {
        let view = SubtitleTableScrollbarOverlayView()
        scrollbar.attach(overlayView: view)
        return view
    }

    func updateNSView(
        _ nsView: SubtitleTableScrollbarOverlayView,
        context: Context
    ) {
        scrollbar.attach(overlayView: nsView)
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
