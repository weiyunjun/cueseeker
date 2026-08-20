import AppKit
import SwiftUI
import Testing
@testable import CueSeekerApp

@MainActor
@Test
func workbenchPageOwnsTheTableScrollbarAtItsOwnViewport() async throws {
    let host = NSHostingView(
        rootView: WorkbenchPageScrollbarFixture()
            .frame(width: 420, height: 320)
    )
    host.frame = CGRect(x: 0, y: 0, width: 420, height: 320)
    let window = NSWindow(
        contentRect: host.frame,
        styleMask: [.borderless],
        backing: .buffered,
        defer: false
    )
    window.contentView = host

    await settleWorkbenchPage(host)

    let overlay = try #require(
        firstWorkbenchPageSubview(
            of: SubtitleTableScrollbarOverlayView.self,
            in: host
        )
    )
    let container = try #require(
        firstWorkbenchPageSubview(of: SubtitleTableContainerView.self, in: host)
    )
    let scrollView = try #require(overlay.scrollView)

    // The table no longer owns a Scrollbar.
    #expect(!isWorkbenchPageDescendant(overlay, of: container))
    #expect(!isWorkbenchPageDescendant(overlay, of: scrollView))
    #expect(
        firstWorkbenchPageSubview(
            of: TableScrollbarOverlayView.self,
            in: container
        ) == nil
    )

    // The page viewport owns it, and is wider than the table scroll viewport.
    expectSameWorkbenchPageRect(
        overlay.convert(overlay.bounds, to: host),
        host.bounds
    )
    #expect(overlay.bounds.width > scrollView.bounds.width)
    #expect(overlay.bounds.height > scrollView.bounds.height)

    #expect(overlay.isPresented)
    #expect(!scrollView.hasVerticalScroller)
    #expect(!scrollView.hasHorizontalScroller)
    let presentation = try #require(overlay.presentationProvider())
    #expect(presentation.vertical != nil)
    #expect(presentation.horizontal != nil)

    // Both thumbs are drawn against the page viewport edges.
    let geometry = TableScrollbarGeometry(presentation: presentation)
    let verticalTrack = try #require(
        geometry.trackRect(for: .vertical, in: overlay.bounds)
    )
    let horizontalTrack = try #require(
        geometry.trackRect(for: .horizontal, in: overlay.bounds)
    )
    #expect(
        abs(verticalTrack.maxX - overlay.bounds.maxX)
            <= TableScrollbarPrimitiveMetrics.inset
    )
    #expect(
        abs(horizontalTrack.maxY - overlay.bounds.maxY)
            <= TableScrollbarPrimitiveMetrics.inset
    )
}

private struct WorkbenchPageScrollbarFixture: View {
    @State private var searchDraft = ""

    private let row = SubtitleTableRow(
        id: 1,
        primaryCueID: 1,
        displayTitle: "Episode 01",
        primaryCueText: "cue text",
        cueGroupTexts: ["cue text"],
        primaryGroupIndex: 0
    )

    var body: some View {
        SchemaWorkbenchSearchShell(
            searchDraft: $searchDraft,
            columns: SchemaWorkbenchSearchDefaults.columns,
            pageTitle: "Search",
            isRedesign: true,
            filterPanel: AnyView(EmptyView()),
            onToggleFilterPanel: {}
        ) { _ in
            SubtitleTableView(
                tableName: "page-scrollbar",
                rowCount: 500,
                rowProvider: { _ in row },
                rowsVersion: 1,
                rowsUpdate: .reload,
                onPlay: { _ in },
                isRedesign: true
            )
        }
    }
}

@MainActor
private func settleWorkbenchPage(_ host: NSView) async {
    for _ in 0..<4 {
        host.layoutSubtreeIfNeeded()
        await Task.yield()
    }
}

@MainActor
private func firstWorkbenchPageSubview<ViewType: NSView>(
    of type: ViewType.Type,
    in root: NSView
) -> ViewType? {
    for subview in root.subviews {
        if let match = subview as? ViewType {
            return match
        }
        if let match = firstWorkbenchPageSubview(of: type, in: subview) {
            return match
        }
    }
    return nil
}

@MainActor
private func isWorkbenchPageDescendant(_ view: NSView, of ancestor: NSView) -> Bool {
    var current = view.superview
    while let candidate = current {
        if candidate === ancestor {
            return true
        }
        current = candidate.superview
    }
    return false
}

private func expectSameWorkbenchPageRect(
    _ actual: CGRect,
    _ expected: CGRect,
    tolerance: CGFloat = 0.5
) {
    #expect(abs(actual.minX - expected.minX) <= tolerance)
    #expect(abs(actual.minY - expected.minY) <= tolerance)
    #expect(abs(actual.width - expected.width) <= tolerance)
    #expect(abs(actual.height - expected.height) <= tolerance)
}
