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

    var onDragStateChanged: ((Bool) -> Void)?

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
