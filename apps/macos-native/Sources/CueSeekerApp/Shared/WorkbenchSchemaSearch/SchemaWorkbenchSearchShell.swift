import SwiftUI

struct SchemaWorkbenchTableSummary: Equatable {
    let totalRowCount: Int
    /// The rows Select Mode can select: the total less the unavailable rows.
    let selectableRowCount: Int
    let selectedRowCount: Int
}

func schemaWorkbenchResultCountText(_ count: Int) -> String {
    let safeCount = max(0, count)
    return safeCount == 1
        ? L("table.result_count.one")
        : L("table.result_count.other", safeCount)
}

func schemaWorkbenchSelectedCountText(
    selectedRowCount: Int,
    selectableRowCount: Int
) -> String {
    L("table.selected_count", max(0, selectedRowCount), max(0, selectableRowCount))
}

/// Select Mode needs the exact result set and at least one row it can select.
func schemaWorkbenchCanEnterSelectionMode(
    hasExactResultSet: Bool,
    selectableRowCount: Int
) -> Bool {
    hasExactResultSet && selectableRowCount > 0
}

enum SchemaWorkbenchSearchDefaults {
    static var columns: [WorkbenchTableColumn] {
        [
        WorkbenchTableColumn(
            id: "rowNumber",
            title: "#",
            kind: .rowNumber,
            width: .fixed(50)
        ),
        WorkbenchTableColumn(
            id: "cues",
            title: L("table.column.cues"),
            kind: .text,
            width: .weighted(weight: 6, min: 240)
        ),
        WorkbenchTableColumn(
            id: "display",
            title: L("table.column.display_title"),
            kind: .text,
            width: .weighted(weight: 3, min: 180)
        ),
        WorkbenchTableColumn(
            id: "time",
            title: L("table.column.time_range"),
            kind: .text,
            width: .weighted(weight: 2, min: 140)
        ),
        ]
    }

    static var excerptColumns: [WorkbenchTableColumn] {
        [
        WorkbenchTableColumn(
            id: "rowNumber",
            title: "#",
            kind: .rowNumber,
            width: .fixed(50)
        ),
        WorkbenchTableColumn(
            id: "cues",
            title: L("table.column.cues"),
            kind: .text,
            width: .weighted(weight: 6, min: 240)
        ),
        WorkbenchTableColumn(
            id: "display",
            title: L("table.column.display_title"),
            kind: .text,
            width: .weighted(weight: 3, min: 180)
        ),
        WorkbenchTableColumn(
            id: "time",
            title: L("table.column.time_range"),
            kind: .text,
            width: .weighted(weight: 2, min: 140)
        ),
        WorkbenchTableColumn(
            id: "dateAdded",
            title: L("table.column.date_added"),
            kind: .text,
            width: .weighted(weight: 2, min: 120)
        ),
        ]
    }
}

struct SchemaWorkbenchSearchShell<TableContent: View>: View {
    @Environment(\.isWorkbenchPageCovered) private var isWorkbenchPageCovered
    @Environment(\.interfaceLayers) private var interfaceLayers
    @Environment(\.interfaceLayerContext) private var layerContext
    // Observed so the copy below is re-read when the language changes.
    @EnvironmentObject private var localization: AppLocalizationStore

    @Binding var searchDraft: String

    let columns: [WorkbenchTableColumn]
    let searchPlaceholder: String
    let isRedesign: Bool
    let summaryContent: AnyView?
    let hostsPageChromeInTable: Bool
    let tableSummary: SchemaWorkbenchTableSummary?
    let searchResultCountText: String?
    let selectionActions: [SchemaWorkbenchSelectionAction]?
    let isSelectionMode: Bool
    let canEnterSelectionMode: Bool
    let onToggleSelectionMode: () -> Void
    let filterMenu: CueFacetFilterMenuModel
    let isFilterMenuOpen: Bool
    let onToggleFilterMenu: () -> Void
    let onDismissFilterMenu: () -> Void
    /// Supplied when the caller hosts the toolbar itself (the Excerpt detail
    /// pins it inside the table); the shell's own toolbar registers into the
    /// shell-owned handle instead.
    let externalFilterMenuAnchor: MenuAnchorHandle?
    /// Registered with the Selection Action Overlay's own area, so the table
    /// can tell when the pointer is over it.
    let selectionOverlayAnchor: MenuAnchorHandle?
    var onSearchSubmit: (() -> Void)?
    let tableContent: ([WorkbenchTableColumn]) -> TableContent

    @StateObject private var externalTextSelectionSession = SubtitleTableExternalTextSelectionSession()
    @StateObject private var pageScrollbar = WorkbenchPageScrollbar()
    @StateObject private var filterMenuHighlight = MenuHighlightModel()
    @State private var ownFilterMenuAnchor = MenuAnchorHandle()
    @State private var filterMenuHost = MenuAnchorHandle()
    /// Measured when the menu opens and when its content changes — never
    /// during a view update, which AttributeGraph forbids.
    @State private var filterMenuSize: CGSize?
    /// What the menu measures once its scrollbar is up. Kept beside the natural
    /// size so a render that has to shorten the menu already knows how much
    /// wider the scrollbar makes it, without measuring again.
    @State private var filterMenuScrollingWidth: CGFloat?

    init(
        searchDraft: Binding<String>,
        columns: [WorkbenchTableColumn],
        searchPlaceholder: String = L("table.search_placeholder"),
        isRedesign: Bool = false,
        summaryContent: AnyView? = nil,
        hostsPageChromeInTable: Bool = false,
        tableSummary: SchemaWorkbenchTableSummary? = nil,
        searchResultCountText: String? = nil,
        selectionActions: [SchemaWorkbenchSelectionAction]? = nil,
        isSelectionMode: Bool = false,
        canEnterSelectionMode: Bool = false,
        onToggleSelectionMode: @escaping () -> Void = {},
        filterMenu: CueFacetFilterMenuModel,
        isFilterMenuOpen: Bool = false,
        onToggleFilterMenu: @escaping () -> Void,
        onDismissFilterMenu: @escaping () -> Void,
        externalFilterMenuAnchor: MenuAnchorHandle? = nil,
        selectionOverlayAnchor: MenuAnchorHandle? = nil,
        onSearchSubmit: (() -> Void)? = nil,
        @ViewBuilder tableContent: @escaping ([WorkbenchTableColumn]) -> TableContent
    ) {
        _searchDraft = searchDraft
        self.columns = columns
        self.searchPlaceholder = searchPlaceholder
        self.isRedesign = isRedesign
        self.summaryContent = summaryContent
        self.hostsPageChromeInTable = hostsPageChromeInTable
        self.tableSummary = tableSummary
        self.searchResultCountText = searchResultCountText
        self.selectionActions = selectionActions
        self.isSelectionMode = isSelectionMode
        self.canEnterSelectionMode = canEnterSelectionMode
        self.onToggleSelectionMode = onToggleSelectionMode
        self.filterMenu = filterMenu
        self.isFilterMenuOpen = isFilterMenuOpen
        self.onToggleFilterMenu = onToggleFilterMenu
        self.onDismissFilterMenu = onDismissFilterMenu
        self.externalFilterMenuAnchor = externalFilterMenuAnchor
        self.selectionOverlayAnchor = selectionOverlayAnchor
        self.onSearchSubmit = onSearchSubmit
        self.tableContent = tableContent
    }

    var body: some View {
        GeometryReader { geometry in
            let contentWidth = max(
                geometry.size.width,
                AppShellLayout.pageContentMinimumWidth
            )
            let pageScrollsHorizontally = contentWidth > geometry.size.width

            ZStack {
                // Below the page minimum the whole page scrolls sideways; the
                // table's own Scrollbar then moves up a row to make room.
                WorkbenchScrollView([.horizontal]) {
                    pageBody
                        .frame(
                            width: contentWidth,
                            height: geometry.size.height,
                            alignment: .topLeading
                        )
                        .overlay(alignment: .bottomLeading) {
                            WorkbenchPageScrollbarOverlay(
                                scrollbar: pageScrollbar,
                                axis: .horizontal
                            )
                            .padding(
                                .horizontal,
                                SchemaWorkbenchStyle.pageHorizontalPadding
                            )
                        }
                }

                WorkbenchPageScrollbarOverlay(
                    scrollbar: pageScrollbar,
                    axis: .vertical
                )
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .background(MenuAnchorProbe(handle: filterMenuHost))
            .overlay(alignment: .topLeading) {
                if isRedesign, isFilterMenuOpen {
                    filterMenuOverlay
                }
            }
            .onAppear {
                updateTableScrollbarReserve(pageScrollsHorizontally)
            }
            .onChange(of: pageScrollsHorizontally) { scrolls in
                updateTableScrollbarReserve(scrolls)
            }
        }
        .environment(\.subtitleTableExternalTextSelectionSession, externalTextSelectionSession)
        .environment(\.workbenchPageScrollbar, pageScrollbar)
        .onChange(of: externalTextSelectionIsBlocked) { isBlocked in
            if isBlocked {
                externalTextSelectionSession.cancel()
            }
        }
        .onChange(of: isFilterMenuOpen) { isOpen in
            if isOpen {
                filterMenuHighlight.open(
                    selectablePositions: filterMenu.selectablePositions
                )
                measureFilterMenu()
            } else {
                filterMenuHighlight.close()
                filterMenuSize = nil
                filterMenuScrollingWidth = nil
            }
        }
        .onChange(of: filterMenu.contentHash) { _ in
            guard isFilterMenuOpen else { return }
            measureFilterMenu()
        }
        .onDisappear {
            externalTextSelectionSession.cancel()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func updateTableScrollbarReserve(_ pageScrollsHorizontally: Bool) {
        pageScrollbar.tableScrollbarBottomReserve = pageScrollsHorizontally
            ? TableScrollbarPrimitiveMetrics.size
                + TableScrollbarPrimitiveMetrics.inset
            : 0
    }

    private var activeFilterMenuAnchor: MenuAnchorHandle {
        externalFilterMenuAnchor ?? ownFilterMenuAnchor
    }

    /// The filter menu, hanging off the filter button and drawn above the
    /// whole page. The button never moves within the page — the toolbar is
    /// pinned — so placement is simply redone against its current frame each
    /// render, and a window resize keeps the menu on its button.
    @ViewBuilder
    private var filterMenuOverlay: some View {
        if let menuSize = filterMenuSize,
           let anchorFrame = activeFilterMenuAnchor.frame(in: filterMenuHost),
           let hostBounds = filterMenuHost.bounds {
            let placement = filterMenuPlacement(
                naturalSize: menuSize,
                anchorFrame: anchorFrame,
                hostBounds: hostBounds
            )
            let menuFrame = placement.frame
            let menuView = CueFacetFilterMenu(
                model: filterMenu,
                highlight: filterMenuHighlight,
                maximumHeight: placement.maximumHeight
            )
            ZStack(alignment: .topLeading) {
                MenuGateClientView(
                    gate: interfaceLayers?.menuGate,
                    owner: layerContext.layer,
                    // The menu's own content scrolls; whatever the content
                    // does not spend stops at the menu's hosting view instead
                    // of reaching the page.
                    kind: .filterMenu,
                    menuFrame: menuFrame,
                    anchorFrame: anchorFrame,
                    handleKey: handleFilterMenuKey,
                    dismiss: { _ in onDismissFilterMenu() }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(false)

                FilterMenuSurfaceHost(menu: menuView)
                    .frame(width: menuFrame.width, height: menuFrame.height)
                    .offset(x: menuFrame.minX, y: menuFrame.minY)
            }
            .zIndex(1000)
        }
    }

    /// The box the filter menu stays inside: the page's content column, whose
    /// trailing edge is where the table's row dividers end. Clamping to the
    /// page itself would let the menu hang over the page margin and the
    /// Scrollbar channel, past the dividers under it.
    private func filterMenuBounds(in hostBounds: CGRect) -> CGRect {
        let leading = WorkbenchControlMetrics.redesignWorkbenchPageHorizontalPadding
        let trailing = WorkbenchControlMetrics.redesignWorkbenchPageTrailingPadding
        return CGRect(
            x: hostBounds.minX + leading,
            y: hostBounds.minY,
            width: max(0, hostBounds.width - leading - trailing),
            height: hostBounds.height
        )
    }

    /// Where the filter menu sits and how tall it may be there. The page's
    /// content column is short enough on a low window that the menu cannot
    /// always be had whole; when that happens it is held to the room on its
    /// side, which brings its scrollbar up and widens it, so the placement is
    /// taken again against the wider surface.
    private func filterMenuPlacement(
        naturalSize: CGSize,
        anchorFrame: CGRect,
        hostBounds: CGRect
    ) -> (frame: CGRect, maximumHeight: CGFloat) {
        let bounds = filterMenuBounds(in: hostBounds)
        let frame = MenuPlacement.openingFrame(
            anchor: anchorFrame,
            menuSize: naturalSize,
            in: bounds,
            gap: WorkbenchControlMetrics.redesignSpacing1,
            shrinksToFit: true
        )
        guard frame.height < naturalSize.height else {
            return (frame, MenuMetrics.maximumHeight)
        }
        let scrollingSize = CGSize(
            width: filterMenuScrollingWidth ?? naturalSize.width,
            height: frame.height
        )
        return (
            MenuPlacement.openingFrame(
                anchor: anchorFrame,
                menuSize: scrollingSize,
                in: bounds,
                gap: WorkbenchControlMetrics.redesignSpacing1,
                shrinksToFit: true
            ),
            frame.height
        )
    }

    private func measureFilterMenu() {
        filterMenuSize = measuredFilterMenuSize(
            maximumHeight: MenuMetrics.maximumHeight
        )
        // Measured against no room at all, so the scrollbar is certainly up and
        // the width is the one a shortened menu ends up with.
        filterMenuScrollingWidth = measuredFilterMenuSize(maximumHeight: 0).width
    }

    private func measuredFilterMenuSize(maximumHeight: CGFloat) -> CGSize {
        let host = NSHostingView(
            rootView: CueFacetFilterMenu(
                model: filterMenu,
                highlight: filterMenuHighlight,
                maximumHeight: maximumHeight
            )
        )
        host.layoutSubtreeIfNeeded()
        return host.fittingSize
    }

    private func handleFilterMenuKey(
        _ keyCode: UInt16,
        _ isRepeat: Bool
    ) -> Bool {
        // Every arrow, Enter and Esc belongs to the open menu; the page under
        // it must not respond to any of them.
        switch keyCode {
        case 53:
            onDismissFilterMenu()
            return true
        case 126:
            _ = filterMenuHighlight.moveHighlight(by: -1)
            return true
        case 125:
            _ = filterMenuHighlight.moveHighlight(by: 1)
            return true
        case 123, 124:
            return true
        case 36, 76:
            toggleHighlightedFilterOption()
            return true
        default:
            return false
        }
    }

    /// Enter checks whatever the highlight sits on and leaves the menu open,
    /// the same commitment the pointer makes with a click.
    private func toggleHighlightedFilterOption() {
        guard !filterMenu.isCalculating,
              let position = filterMenuHighlight.highlightedPosition,
              let option = filterMenu.option(at: position)
        else {
            return
        }
        option.toggle()
    }

    @ViewBuilder
    private var pageBody: some View {
        ZStack {
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(false)

            SubtitleTableExternalTextSelectionEventMonitor(
                session: externalTextSelectionSession,
                startPolicy: externalTextSelectionStartPolicy
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .allowsHitTesting(false)

            if isRedesign, summaryContent != nil, hostsPageChromeInTable {
                tableContent(columns)
                    .overlay(alignment: .bottom) {
                        // The table runs to the window edge here, so the
                        // Overlay takes the page margins the table's content
                        // region has.
                        selectionActionOverlay
                            .workbenchPageInlinePadding()
                    }
                // The detail hosts its page chrome inside the table, so the
                // table would otherwise run to the window edge and put the
                // Overlay a page margin lower than every other Workbench page.
                .padding(
                    .bottom,
                    WorkbenchControlMetrics.redesignWorkbenchPageBottomPadding
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 0) {
                    if isRedesign {
                        searchToolbar
                            .workbenchPageInlinePadding()
                            .padding(
                                .top,
                                WorkbenchControlMetrics.redesignWorkbenchPageTopPadding
                            )
                            .padding(.bottom, WorkbenchControlMetrics.redesignSpacing3)
                    }

                    tableContent(columns)
                        .overlay(alignment: .bottom) {
                            if isRedesign {
                                selectionActionOverlay
                            }
                        }
                        .workbenchPageInlinePadding()
                    .padding(
                        .bottom,
                        WorkbenchControlMetrics.redesignWorkbenchPageBottomPadding
                    )
                    .frame(maxHeight: .infinity)
                }
            }

        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Drawn as the table's overlay, so it is offered the table's size and can
    /// never widen the page, however long its content.
    @ViewBuilder
    private var selectionActionOverlay: some View {
        if isSelectionMode,
           let tableSummary,
           let selectionActions {
            SchemaWorkbenchSelectionActionOverlay(
                selectedRowCount: tableSummary.selectedRowCount,
                selectableRowCount: tableSummary.selectableRowCount,
                actions: selectionActions,
                anchor: selectionOverlayAnchor,
                onExitSelectionMode: onToggleSelectionMode
            )
            .padding(.bottom, WorkbenchControlMetrics.redesignSpacing4)
        }
    }

    private var externalTextSelectionIsBlocked: Bool {
        !isRedesign || isWorkbenchPageCovered || isSelectionMode
    }

    private var externalTextSelectionStartPolicy: SubtitleTableExternalTextSelectionStartPolicy {
        return SubtitleTableExternalTextSelectionStartPolicy(
            isBlocked: externalTextSelectionIsBlocked
        )
    }

    private var searchToolbar: some View {
        SchemaWorkbenchSearchToolbar(
            placeholder: searchPlaceholder,
            searchDraft: $searchDraft,
            searchResultCountText: searchResultCountText,
            isSelectionMode: isSelectionMode,
            isFilterMenuOpen: isFilterMenuOpen,
            canEnterSelectionMode: canEnterSelectionMode,
            filterMenuAnchor: activeFilterMenuAnchor,
            onSubmit: onSearchSubmit,
            onFilter: onToggleFilterMenu,
            onToggleSelectionMode: onToggleSelectionMode
        )
    }

}

enum SchemaWorkbenchStyle {
    static let pageHorizontalPadding =
        WorkbenchControlMetrics.redesignWorkbenchPageHorizontalPadding
}

struct SchemaWorkbenchSearchToolbar: View {
    let placeholder: String
    @Binding var searchDraft: String
    let searchResultCountText: String?
    var isSelectionMode: Bool = false
    var isFilterMenuOpen: Bool = false
    var canEnterSelectionMode: Bool = false
    /// Where the filter menu should hang: the probe behind the filter button
    /// registers into this handle so the menu host can find the button across
    /// hosting boundaries.
    var filterMenuAnchor: MenuAnchorHandle?
    var onSubmit: (() -> Void)?
    var onFilter: () -> Void
    var onToggleSelectionMode: () -> Void

    var body: some View {
        HStack(spacing: WorkbenchControlMetrics.redesignSpacing3) {
            WorkbenchSearchField(
                placeholder: placeholder,
                text: $searchDraft,
                isRedesign: true,
                trailingStatusText: searchResultCountText,
                onSubmit: onSubmit
            )
            .frame(maxWidth: .infinity)
            .disabled(isSelectionMode)

            WorkbenchIconButton(
                icon: .funnel,
                isRedesign: true,
                isOpen: isFilterMenuOpen,
                action: onFilter
            )
            .background {
                if let filterMenuAnchor {
                    MenuAnchorProbe(handle: filterMenuAnchor)
                }
            }
            .accessibilityLabel(L("table.filter"))
            .disabled(isSelectionMode)

            WorkbenchIconButton(
                icon: .notePencil,
                isRedesign: true,
                isOpen: isSelectionMode,
                action: onToggleSelectionMode
            )
            .accessibilityLabel(isSelectionMode ? L("table.exit_select") : L("table.select"))
            .disabled(!isSelectionMode && !canEnterSelectionMode)
        }
        .frame(height: WorkbenchControlMetrics.redesignHeight)
    }
}

/// Hosts the filter menu's SwiftUI surface in the menu hosting view, so a
/// wheel the menu's own scrolling does not spend stops there instead of
/// scrolling the page, and the menu's scrollbar escapes the page-wide
/// interaction freeze that an open menu imposes.
private struct FilterMenuSurfaceHost: NSViewRepresentable {
    let menu: CueFacetFilterMenu

    func makeNSView(context _: Context) -> MenuHostingView {
        MenuHostingView(rootView: AnyView(menu))
    }

    func updateNSView(_ nsView: MenuHostingView, context _: Context) {
        nsView.rootView = AnyView(menu)
    }
}
