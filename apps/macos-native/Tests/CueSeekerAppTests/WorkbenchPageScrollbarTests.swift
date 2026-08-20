import AppKit
import SwiftUI
import Testing
@testable import CueSeekerApp

/// Hosting-based cases share AppKit window state, so they must not interleave.
@MainActor
@Suite(.serialized)
struct WorkbenchPageScrollbarHostingTests {
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

    // The page viewport owns it, and the scroll viewport fills the same page
    // region — the page padding travels inside the scrolled content.
    expectSameWorkbenchPageRect(
        overlay.convert(overlay.bounds, to: host),
        host.bounds
    )
    let scrollFrame = scrollView.convert(scrollView.bounds, to: host)
    #expect(abs(scrollFrame.minX) < 0.5)
    #expect(abs(scrollFrame.width - host.bounds.width) < 0.5)

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

@Test
func workbenchPageChromeStopsShrinkingWithTheTableColumns() async throws {
    let host = NSHostingView(
        rootView: WorkbenchPageScrollbarFixture()
            .frame(width: 480, height: 640)
    )
    host.frame = CGRect(x: 0, y: 0, width: 480, height: 640)
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
    let documentView = try #require(scrollView.documentView)

    let tableMinimumWidth = SubtitleTableColumnLayout.minimumContentWidth(
        showsDateAddedColumn: false,
        showsDisplayTitleColumn: true,
        showsTimeColumn: true,
        showsLanguageColumn: false,
        cuesMinimumWidth: SubtitleTableMetrics.cuesColumnMinimumWidth
    )

    // No fixed gutter outside the viewport: container and viewport fill the page.
    let containerFrame = container.convert(container.bounds, to: host)
    #expect(abs(containerFrame.minX) < 0.5)
    #expect(abs(containerFrame.width - host.bounds.width) < 0.5)
    #expect(
        abs(scrollView.contentView.bounds.width - host.bounds.width) < 0.5
    )

    // The columns stop at their minimums and the page padding rides along, so
    // the page scrolls horizontally.
    let padding = 2 * SchemaWorkbenchStyle.pageHorizontalPadding
    #expect(abs(documentView.frame.width - (tableMinimumWidth + padding)) < 0.5)
    #expect(documentView.frame.width > scrollView.contentView.bounds.width)

    let maximumOffset = documentView.frame.width - scrollView.contentView.bounds.width
    scrollView.contentView.scroll(to: CGPoint(x: maximumOffset, y: 0))
    scrollView.reflectScrolledClipView(scrollView.contentView)
    await settleWorkbenchPage(host)

    // Scrolled to the end, the content's own trailing padding meets the viewport
    // edge instead of leaving a permanent blank strip.
    #expect(
        abs(
            documentView.frame.width
                - (scrollView.contentView.bounds.minX
                    + scrollView.contentView.bounds.width)
        ) < 0.5
    )
    let horizontal = try #require(overlay.presentationProvider()?.horizontal)
    #expect(abs(horizontal.positionFraction - 1) < 0.01)
}

@Test
func workbenchPageWithoutATableStopsAtTheContentMinimumWidth() async throws {
    let available: CGFloat = 300
    let host = NSHostingView(
        rootView: LibraryOverviewLayout(
            title: "Library",
            summaryText: "0 Folders",
            actionTitle: "Add Content",
            actionSystemImage: "plus",
            action: {}
        ) {
            Color.clear.frame(height: 40)
        }
        .frame(width: available, height: 400)
    )
    host.frame = CGRect(x: 0, y: 0, width: available, height: 400)
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
            of: WorkbenchScrollViewOverlayView.self,
            in: host
        )
    )
    let scrollView = try #require(overlay.targetScrollViewForTesting)
    let documentView = try #require(scrollView.documentView)

    // The page keeps the App-minimum right region width and overflows instead.
    #expect(available < AppShellLayout.pageContentMinimumWidth)
    #expect(
        abs(documentView.frame.width - AppShellLayout.pageContentMinimumWidth) < 0.5
    )
    #expect(overlay.presentationProvider()?.horizontal != nil)
}

@Test
func subtitleTablePageChromeFollowsTheHorizontalScrollOffset() async throws {
    let row = SubtitleTableRow(
        id: 1,
        primaryCueID: 1,
        displayTitle: "Episode 01",
        primaryCueText: "cue text",
        cueGroupTexts: ["cue text"],
        primaryGroupIndex: 0
    )
    let coordinator = SubtitleTableView.Coordinator(
        tableName: "shiori",
        probeSurface: .shiori,
        rowCount: 20,
        rowProvider: { _ in row },
        rowsVersion: 1,
        displayTitleHeader: "Display Title",
        showsLanguageColumn: false,
        onVisibleRowsChange: { _ in },
        isRowSelected: { _ in false },
        onPlay: { _ in }
    )
    coordinator.isRedesign = true
    coordinator.horizontalContentInset = 32

    let inset: CGFloat = 32
    let container = SubtitleTableContainerView(
        frame: CGRect(x: 0, y: 0, width: 400, height: 600)
    )
    let viewport = SubtitleTablePageChromeViewportView(
        frame: CGRect(x: inset, y: 0, width: 400 - 2 * inset, height: 600)
    )
    let header = SubtitleVirtualTableHeaderView()
    let scrollView = NSScrollView(
        frame: CGRect(x: inset, y: 0, width: 400 - 2 * inset, height: 600)
    )
    let documentView = SubtitleVirtualTableDocumentView(
        frame: CGRect(x: 0, y: 0, width: 400 - 2 * inset, height: 1)
    )
    container.addSubview(scrollView)
    container.addSubview(viewport)
    viewport.addSubview(header)
    scrollView.documentView = documentView

    let overlay = SubtitleTableScrollbarOverlayView(frame: container.bounds)
    let pageScrollbar = WorkbenchPageScrollbar()
    pageScrollbar.attach(overlayView: overlay)
    coordinator.attach(
        container: container,
        headerView: header,
        scrollView: scrollView,
        pageScrollbar: pageScrollbar,
        documentView: documentView,
        pageChromeViewport: viewport
    )
    coordinator.updatePageChrome(SubtitleTablePageChrome(
        scrollableHeader: AnyView(Color.clear),
        pinnedHeader: AnyView(Color.clear),
        scrollableHeaderHeight: 100,
        pinnedHeaderHeight: 52,
        bottomInset: 14
    ))
    coordinator.resizeDocument()

    let contentWidth = documentView.frame.width
    #expect(contentWidth > scrollView.contentView.bounds.width)

    var frames = try #require(coordinator.pageChromeFramesForTesting())
    #expect(frames.scrollable.minX == inset)
    // Chrome spans the document minus its padding, matching the columns.
    #expect(abs(frames.scrollable.width - (contentWidth - 2 * inset)) < 0.5)
    #expect(abs(frames.pinned.width - (contentWidth - 2 * inset)) < 0.5)
    // The header keeps the viewport frame and offsets its own columns.
    #expect(frames.tableHeader.minX == 0)
    #expect(abs(frames.tableHeader.width - scrollView.contentView.bounds.width) < 0.5)

    scrollView.contentView.scroll(to: CGPoint(x: 40, y: 0))
    scrollView.reflectScrolledClipView(scrollView.contentView)
    coordinator.scrollContentDidChange()

    frames = try #require(coordinator.pageChromeFramesForTesting())
    #expect(frames.scrollable.minX == inset - 40)
    #expect(frames.pinned.minX == inset - 40)
    #expect(frames.tableHeader.minX == 0)

    // Columns live inside the document's own padding.
    let firstCell = try #require(
        coordinator.dataCellRectForTesting(row: 0, columnID: "cues")
    )
    #expect(firstCell.minX >= inset)

    // The page chrome geometry the SwiftUI page reads is published on the next
    // main-queue turn.
    await Task.yield()
    #expect(pageScrollbar.horizontalOffset == 40)
    #expect(abs(pageScrollbar.horizontalContentWidth - contentWidth) < 0.5)
}

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
                showsTimeColumn: true,
                onPlay: { _ in },
                isRedesign: true,
                horizontalContentInset: SchemaWorkbenchStyle.pageHorizontalPadding
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
