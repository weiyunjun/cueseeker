import AppKit
import SwiftUI
import Testing
import CueSeekerCore
@testable import CueSeekerApp

@MainActor
@Test
func workbenchPageAndTableOwnOneScrollbarAxisEach() async throws {
    // At the 600px page minimum, the table (520px) is narrower than its minimum column sum, so the table's horizontal Scrollbar is present.
    let width = AppShellLayout.pageContentMinimumWidth
    let host = NSHostingView(
        rootView: WorkbenchPageScrollbarFixture()
            .frame(width: width, height: 320)
    )
    host.frame = CGRect(x: 0, y: 0, width: width, height: 320)
    let window = NSWindow(
        contentRect: host.frame,
        styleMask: [.borderless],
        backing: .buffered,
        defer: false
    )
    window.contentView = host

    await settleWorkbenchPage(host)

    let overlays = workbenchPageSubviews(
        of: SubtitleTableScrollbarOverlayView.self,
        in: host
    )
    let vertical = try #require(
        overlays.first { $0.visibleAxes == [.vertical] }
    )
    let horizontal = try #require(
        overlays.first { $0.visibleAxes == [.horizontal] }
    )
    let container = try #require(
        firstWorkbenchPageSubview(of: SubtitleTableContainerView.self, in: host)
    )
    let scrollView = try #require(vertical.scrollView)

    // The table draws no Scrollbar of its own inside its view tree.
    #expect(!isWorkbenchPageDescendant(vertical, of: container))
    #expect(!isWorkbenchPageDescendant(horizontal, of: container))
    #expect(
        firstWorkbenchPageSubview(
            of: TableScrollbarOverlayView.self,
            in: container
        ) == nil
    )
    #expect(!scrollView.hasVerticalScroller)
    #expect(!scrollView.hasHorizontalScroller)

    // Vertical spans the page; horizontal spans the table's own width.
    expectSameWorkbenchPageRect(
        vertical.convert(vertical.bounds, to: host),
        host.bounds
    )
    #expect(
        abs(
            horizontal.bounds.width
                - (width - 2 * SchemaWorkbenchStyle.pageHorizontalPadding)
        ) < 0.5
    )

    // Each Overlay reports only its own axis.
    let verticalPresentation = try #require(vertical.currentPresentation())
    #expect(verticalPresentation.vertical != nil)
    #expect(verticalPresentation.horizontal == nil)

    let horizontalPresentation = try #require(horizontal.currentPresentation())
    #expect(horizontalPresentation.horizontal != nil)
    #expect(horizontalPresentation.vertical == nil)

    // Each keeps the crossing Scrollbar's slot free.
    let slot = TableScrollbarPrimitiveMetrics.size
        + TableScrollbarPrimitiveMetrics.inset
    #expect(vertical.bottomReserve == slot)
    #expect(horizontal.trailingReserve == slot)

    // The table's horizontal Scrollbar sits at the bottom of the page.
    #expect(horizontal.bottomReserve == 0)
    let track = try #require(
        TableScrollbarGeometry(presentation: horizontalPresentation)
            .trackRect(for: .horizontal, in: horizontal.geometryBounds)
    )
    #expect(
        abs(track.maxY - horizontal.bounds.maxY)
            <= TableScrollbarPrimitiveMetrics.inset
    )
    #expect(
        abs(
            horizontal.convert(horizontal.bounds, to: host).maxY
                - host.bounds.maxY
        ) < 0.5
    )
}

@MainActor
@Test
func workbenchPageWithoutATableUsesViewportWidthWithoutHorizontalPageScrollbar() async throws {
    let available = AppShellLayout.pageContentMinimumWidth
    let host = NSHostingView(
        rootView: LibraryOverviewLayout(
            summaryText: "0 Folders",
            actionTitle: "Add Folder",
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

    #expect(
        abs(documentView.frame.width - available) < 0.5
    )
    #expect(overlay.presentationProvider()?.horizontal == nil)
}

@MainActor
@Test
func workbenchTableScrollbarStaysAtBottomWithoutOuterPageHorizontalScrollbar() async throws {
    let width = AppShellLayout.pageContentMinimumWidth
    let host = NSHostingView(
        rootView: WorkbenchPageScrollbarFixture()
            .frame(width: width, height: 320)
    )
    host.frame = CGRect(x: 0, y: 0, width: width, height: 320)
    let window = NSWindow(
        contentRect: host.frame,
        styleMask: [.borderless],
        backing: .buffered,
        defer: false
    )
    window.contentView = host

    await settleWorkbenchPage(host)

    let overlays = workbenchPageSubviews(
        of: SubtitleTableScrollbarOverlayView.self,
        in: host
    )
    let tableHorizontal = try #require(
        overlays.first { $0.visibleAxes == [.horizontal] }
    )
    let pageOverlay = firstWorkbenchPageSubview(
        of: WorkbenchScrollViewOverlayView.self,
        in: host
    )

    #expect(pageOverlay == nil)
    #expect(tableHorizontal.bottomReserve == 0)
}

@MainActor
@Test
func playbackOverlayTopBarMountsDraggableTitlebarBackgroundInModuleAndCollageModes() async throws {
    let app = AppCoordinator()
    let localization = makeTestAppLocalizationStore()

    for isEditingCollage in [false, true] {
        let host = NSHostingView(
            rootView: PlaybackOverlayTopBar(
                modules: [.current, .playlist],
                selectedModule: .current,
                isEditingCollage: isEditingCollage,
                onSelect: { _ in true },
                onToggleEditingCollage: { true },
                onReturn: {}
            )
            .environmentObject(app)
            .environmentObject(localization)
            .environmentObject(app.settings.playbackShortcuts)
            .frame(width: 600, height: WorkbenchControlMetrics.redesignAppTopbarHeight)
        )
        host.frame = CGRect(
            x: 0,
            y: 0,
            width: 600,
            height: WorkbenchControlMetrics.redesignAppTopbarHeight
        )
        let window = NSWindow(
            contentRect: host.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = host

        await settleWorkbenchPage(host)

        let draggableView = try #require(
            firstWorkbenchPageSubview(
                of: DraggableNSView.self,
                in: host
            )
        )
        #expect(abs(draggableView.bounds.width - 600) < 0.5)
        #expect(
            abs(
                draggableView.bounds.height
                    - WorkbenchControlMetrics.redesignAppTopbarHeight
            ) < 0.5
        )

        var zoomedWindow: NSWindow?
        let observer = NotificationCenter.default.addObserver(
            forName: .topbarTitlebarZoomRequested,
            object: window,
            queue: .main
        ) { notification in
            zoomedWindow = notification.object as? NSWindow
        }
        defer {
            NotificationCenter.default.removeObserver(observer)
        }

        #expect(draggableView.onDoubleClickZoom?(window) == true)
        #expect(zoomedWindow === window)
    }
}

@MainActor
@Test
func workbenchTableHeaderStaysWithinTheTableWidth() async throws {
    let width = AppShellLayout.pageContentMinimumWidth
    let host = NSHostingView(
        rootView: WorkbenchPageScrollbarFixture()
            .frame(width: width, height: 320)
    )
    host.frame = CGRect(x: 0, y: 0, width: width, height: 320)
    let window = NSWindow(
        contentRect: host.frame,
        styleMask: [.borderless],
        backing: .buffered,
        defer: false
    )
    window.contentView = host

    await settleWorkbenchPage(host)

    let headerView = try #require(
        firstWorkbenchPageSubview(
            of: SubtitleVirtualTableHeaderView.self,
            in: host
        )
    )
    let overlay = try #require(
        workbenchPageSubviews(
            of: SubtitleTableScrollbarOverlayView.self,
            in: host
        ).first { $0.visibleAxes == [.vertical] }
    )
    let scrollView = try #require(overlay.scrollView)
    let documentView = try #require(scrollView.documentView)

    // Header and table body cover the same horizontal range.
    let headerFrame = headerView.convert(headerView.bounds, to: host)
    let scrollFrame = scrollView.convert(scrollView.bounds, to: host)
    #expect(abs(headerFrame.minX - scrollFrame.minX) < 0.5)
    #expect(abs(headerFrame.width - scrollFrame.width) < 0.5)

    // Columns shift with the horizontal offset, so the header must clip them.
    #expect(documentView.frame.width > scrollView.contentView.bounds.width)
    #expect(headerView.layer?.masksToBounds == true)
}

@MainActor
@Test
func unifiedTwoRowToolbarShrinksSearchFieldFirstAndDisablesRowOneInSelectMode() async throws {
    let wideWidth: CGFloat = 800
    let narrowWidth: CGFloat = 480

    let localization = AppLocalizationStore(
        language: .english,
        userDefaults: .standard,
        userDefaultsKey: "WorkbenchPageScrollbarTests.language"
    )

    func mountToolbar(width: CGFloat, isSelectionMode: Bool) async -> NSHostingView<AnyView> {
        let host = NSHostingView(
            rootView: AnyView(
                SchemaWorkbenchSearchToolbar(
                    placeholder: "Search in excerpt list...",
                    searchDraft: .constant(""),
                    searchResultCountText: "42 excerpts",
                    selectedCountText: "1 / 42 rows selected",
                    selectionActions: SchemaWorkbenchSelectionAction.exportActions(
                        exportToAnki: {},
                        copyDeepLinks: {},
                        copyTable: {}
                    ),
                    isSelectionMode: isSelectionMode,
                    isFilterDialogOpen: false,
                    filterSelectionCount: 0,
                    canEnterSelectionMode: true,
                    sortTitle: ExcerptSortOrder.earliestDateAdded.title,
                    onSubmit: nil,
                    onFilter: {},
                    onSort: {},
                    onToggleSelectionMode: {}
                )
                .environmentObject(localization)
                .frame(width: width)
            )
        )
        host.frame = CGRect(x: 0, y: 0, width: width, height: 100)
        let window = NSWindow(
            contentRect: host.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = host
        await settleWorkbenchPage(host)
        return host
    }

    let wideHost = await mountToolbar(width: wideWidth, isSelectionMode: false)
    let narrowHost = await mountToolbar(width: narrowWidth, isSelectionMode: false)

    let wideSearchField = try #require(
        workbenchPageSubviews(of: NSTextField.self, in: wideHost).first { $0.isEditable }
    )
    let narrowSearchField = try #require(
        workbenchPageSubviews(of: NSTextField.self, in: narrowHost).first { $0.isEditable }
    )

    // When container width decreases by 320px, the search field absorbs the full reduction
    // while Filter button and Sort button keep their intrinsic widths.
    let widthDelta = wideWidth - narrowWidth
    let searchFieldDelta = wideSearchField.bounds.width - narrowSearchField.bounds.width
    #expect(abs(searchFieldDelta - widthDelta) <= 1.0)

    // In Select Mode, the search field is hidden while the two-row toolbar height remains unchanged.
    let selectionHost = await mountToolbar(width: wideWidth, isSelectionMode: true)
    let selectionSearchField = workbenchPageSubviews(of: NSTextField.self, in: selectionHost).first {
        $0.placeholderAttributedString?.string == "Search in excerpt list..."
            || $0.placeholderString == "Search in excerpt list..."
    }
    #expect(selectionSearchField == nil)
    #expect(abs(wideHost.fittingSize.height - 80) <= 1.0)
    #expect(abs(selectionHost.fittingSize.height - 80) <= 1.0)
}

@MainActor
@Test
func filePageFreezesTopActionAndBreadcrumbRowsAboveVerticalScrollView() async throws {
    let suiteName = "FileFrozenHeaderTests-\(UUID().uuidString)"
    let defaults = UserDefaults.temporary(suiteName: suiteName)!
    let tempDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("FileFrozenHeaderTests-\(UUID().uuidString)", isDirectory: true)
    defer {
        defaults.removePersistentDomainAndPlist(forName: suiteName)
        try? FileManager.default.removeItem(at: tempDir)
    }

    let appState = AppCoordinator(
        userDefaults: defaults,
        databaseURL: tempDir.appendingPathComponent("cueseeker.sqlite")
    )
    let rootURL = URL(fileURLWithPath: "/Volumes/Media/Anime")
    appState.indexing.selectedFolders = [rootURL]
    appState.workbenchLayout.navigate(to: .fileFolder(rootPath: rootURL.path))

    let width = AppShellLayout.pageContentMinimumWidth + 120
    let height: CGFloat = 360
    let host = NSHostingView(
        rootView: WorkbenchFileView(tasks: appState.tasks)
            .environmentObject(appState.settings.localization)
            .environmentObject(appState)
            .environmentObject(appState.indexing)
            .environmentObject(appState.workbenchLayout.route)
            .environmentObject(appState.library)
            .frame(width: width, height: height)
    )
    host.frame = CGRect(x: 0, y: 0, width: width, height: height)
    let window = NSWindow(
        contentRect: host.frame,
        styleMask: [.borderless],
        backing: .buffered,
        defer: false
    )
    window.contentView = host

    await settleWorkbenchPage(host)

    let overlays = workbenchPageSubviews(of: WorkbenchScrollViewOverlayView.self, in: host)
    #expect(overlays.count == 1)

    let innerVerticalScrollView = try #require(
        overlays
            .compactMap { $0.targetScrollViewForTesting }
            .first { $0.bounds.height < height - 50 }
    )
    // Top frozen rows (4px top padding + 36px action row + 16px spacing + 17px breadcrumb + 12px spacing = 85px)
    // stay outside and above the vertical scroll view, leaving height - 85px for the vertical scroll view.
    let frozenHeaderHeight =
        WorkbenchControlMetrics.redesignWorkbenchPageTopPadding
        + WorkbenchControlMetrics.redesignHeight
        + WorkbenchControlMetrics.redesignSpacing4
        + 17
        + WorkbenchControlMetrics.redesignSpacing3
    let expectedVerticalScrollHeight = height - frozenHeaderHeight
    #expect(abs(innerVerticalScrollView.bounds.height - expectedVerticalScrollHeight) <= 1.0)
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
            isRedesign: true,
            onOpenFilterDialog: {}
        ) { _ in
            SubtitleTableView(
                tableName: "page-scrollbar",
                rowCount: 500,
                rowProvider: { _ in row },
                rowsVersion: 1,
                rowsUpdate: .reload,
                showsTimeColumn: true,
                showsLanguageColumn: true,
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
private func workbenchPageSubviews<ViewType: NSView>(
    of type: ViewType.Type,
    in root: NSView
) -> [ViewType] {
    var matches: [ViewType] = []
    for subview in root.subviews {
        if let match = subview as? ViewType {
            matches.append(match)
        }
        matches.append(contentsOf: workbenchPageSubviews(of: type, in: subview))
    }
    return matches
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
