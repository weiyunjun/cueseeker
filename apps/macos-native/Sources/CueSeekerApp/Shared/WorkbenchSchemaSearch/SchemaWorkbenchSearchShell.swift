import SwiftUI

struct SchemaWorkbenchTableSummary: Equatable {
    let totalRowCount: Int
    let selectedRowCount: Int
}

func schemaWorkbenchResultCountText(_ count: Int) -> String {
    let safeCount = max(0, count)
    return safeCount == 1
        ? L("table.result_count.one")
        : L("table.result_count.other", safeCount)
}

func schemaWorkbenchSelectedCountText(_ count: Int) -> String {
    L("table.selected_count", max(0, count))
}

func schemaWorkbenchCanEnterSelectionMode(hasExactResultSet: Bool) -> Bool {
    hasExactResultSet
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

    static var shioriColumns: [WorkbenchTableColumn] {
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
    let pageTitle: String?
    let searchPlaceholder: String
    let isRedesign: Bool
    let summaryContent: AnyView?
    let hostsPageChromeInTable: Bool
    let tableSummary: SchemaWorkbenchTableSummary?
    let searchResultCountText: String?
    let selectionActions: AnyView?
    let isSelectionMode: Bool
    let canEnterSelectionMode: Bool
    let onToggleSelectionMode: () -> Void
    let filterMenu: CueFacetFilterMenuModel
    let isFilterMenuOpen: Bool
    let onToggleFilterMenu: () -> Void
    let onDismissFilterMenu: () -> Void
    /// Supplied when the caller hosts the toolbar itself (the Shiori detail
    /// pins it inside the table); the shell's own toolbar registers into the
    /// shell-owned handle instead.
    let externalFilterMenuAnchor: MenuAnchorHandle?
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

    init(
        searchDraft: Binding<String>,
        columns: [WorkbenchTableColumn],
        pageTitle: String? = nil,
        searchPlaceholder: String = L("table.search_placeholder"),
        isRedesign: Bool = false,
        summaryContent: AnyView? = nil,
        hostsPageChromeInTable: Bool = false,
        tableSummary: SchemaWorkbenchTableSummary? = nil,
        searchResultCountText: String? = nil,
        selectionActions: AnyView? = nil,
        isSelectionMode: Bool = false,
        canEnterSelectionMode: Bool = false,
        onToggleSelectionMode: @escaping () -> Void = {},
        filterMenu: CueFacetFilterMenuModel,
        isFilterMenuOpen: Bool = false,
        onToggleFilterMenu: @escaping () -> Void,
        onDismissFilterMenu: @escaping () -> Void,
        externalFilterMenuAnchor: MenuAnchorHandle? = nil,
        onSearchSubmit: (() -> Void)? = nil,
        @ViewBuilder tableContent: @escaping ([WorkbenchTableColumn]) -> TableContent
    ) {
        _searchDraft = searchDraft
        self.columns = columns
        self.pageTitle = pageTitle
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
                filterMenuSize = measuredFilterMenuSize()
            } else {
                filterMenuHighlight.close()
                filterMenuSize = nil
            }
        }
        .onChange(of: filterMenu.contentHash) { _ in
            guard isFilterMenuOpen else { return }
            filterMenuSize = measuredFilterMenuSize()
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
            let menuView = CueFacetFilterMenu(
                model: filterMenu,
                highlight: filterMenuHighlight
            )
            let menuFrame = MenuPlacement.openingFrame(
                anchor: anchorFrame,
                menuSize: menuSize,
                in: filterMenuBounds(in: hostBounds),
                gap: WorkbenchControlMetrics.redesignSpacing1
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

    private func measuredFilterMenuSize() -> CGSize {
        let host = NSHostingView(
            rootView: CueFacetFilterMenu(
                model: filterMenu,
                highlight: filterMenuHighlight
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
                ZStack(alignment: .bottom) {
                    tableContent(columns)

                    if let tableSummary,
                       tableSummary.selectedRowCount > 0,
                       let selectionActions {
                        SchemaWorkbenchSelectionActionOverlay(
                            selectedRowCount: tableSummary.selectedRowCount,
                            actions: selectionActions,
                            onExitSelectionMode: onToggleSelectionMode
                        )
                        .padding(.bottom, WorkbenchControlMetrics.redesignSpacing4)
                    }
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
                    if isRedesign, let pageTitle {
                        WorkbenchPageTitle(pageTitle)
                            .workbenchPageInlinePadding()
                            .padding(
                                .top,
                                WorkbenchControlMetrics.redesignWorkbenchPageTopPadding
                            )
                            .padding(.bottom, WorkbenchControlMetrics.redesignSpacing4)
                    }

                    if isRedesign {
                        searchToolbar
                            .workbenchPageInlinePadding()
                            .padding(
                                .top,
                                pageTitle == nil
                                    ? SchemaWorkbenchStyle.pageTopPadding
                                    : 0
                            )
                            .padding(.bottom, WorkbenchControlMetrics.redesignSpacing3)
                    } else {
                        SchemaWorkbenchLegacySearchCommandBar(
                            placeholder: searchPlaceholder,
                            searchDraft: $searchDraft,
                            onSubmit: onSearchSubmit
                        )
                        .workbenchPageInlinePadding()
                        .padding(.top, SchemaWorkbenchStyle.pageTopPadding)
                        .padding(.bottom, 12)

                        SchemaWorkbenchLegacyFilterControlBar(
                            isFilterPanelOpen: isFilterMenuOpen,
                            onFilter: onToggleFilterMenu
                        )
                        .workbenchPageInlinePadding()
                        .padding(.bottom, 12)
                    }

                    ZStack(alignment: .bottom) {
                        tableContent(columns)

                        if isRedesign,
                           let tableSummary,
                           tableSummary.selectedRowCount > 0,
                           let selectionActions {
                            SchemaWorkbenchSelectionActionOverlay(
                                selectedRowCount: tableSummary.selectedRowCount,
                                actions: selectionActions,
                                onExitSelectionMode: onToggleSelectionMode
                            )
                            .padding(.bottom, WorkbenchControlMetrics.redesignSpacing4)
                        }
                    }
                    .workbenchPageInlinePadding()
                    .padding(
                        .bottom,
                        pageTitle == nil
                            ? SchemaWorkbenchStyle.pageBottomPadding
                            : WorkbenchControlMetrics.redesignWorkbenchPageBottomPadding
                    )
                    .frame(maxHeight: .infinity)
                }
            }

        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
    static let pageTopPadding: CGFloat = 10
    static let pageBottomPadding: CGFloat = 14
    static let tableCornerRadius: CGFloat = 8
    static let hairlineWidth: CGFloat = 0.5
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
                systemImage: "line.3.horizontal.decrease",
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
                systemImage: "square.and.pencil",
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

struct SchemaWorkbenchSelectionActionOverlay: View {
    let selectedRowCount: Int
    let actions: AnyView
    let onExitSelectionMode: () -> Void

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: WorkbenchControlMetrics.redesignSpacing2
        ) {
            Text(schemaWorkbenchSelectedCountText(selectedRowCount))
                .font(.system(
                    size: WorkbenchControlMetrics.redesignFontSizeBody,
                    weight: .regular
                ))
                .foregroundStyle(WorkbenchRedesignColors.textMuted)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)

            HStack(spacing: WorkbenchControlMetrics.redesignSpacing3) {
                actions

                WorkbenchButton(
                    title: L("table.toolbar.exit"),
                    systemImage: "xmark",
                    isRedesign: true,
                    action: onExitSelectionMode
                )
            }
        }
        .padding(.horizontal, WorkbenchControlMetrics.redesignSpacing3)
        .padding(.vertical, WorkbenchControlMetrics.redesignSpacing2)
        .background(
            RoundedRectangle(
                cornerRadius: WorkbenchControlMetrics.redesignCornerRadius,
                style: .continuous
            )
            .fill(WorkbenchRedesignColors.bgPopover)
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: WorkbenchControlMetrics.redesignCornerRadius,
                style: .continuous
            )
            .strokeBorder(WorkbenchRedesignColors.borderMuted, lineWidth: 1)
        )
        .shadowToken(WorkbenchRedesignColors.shadowPopover)
        .contentShape(
            RoundedRectangle(
                cornerRadius: WorkbenchControlMetrics.redesignCornerRadius,
                style: .continuous
            )
        )
    }
}

struct SchemaWorkbenchLegacySearchCommandBar: View {
    let placeholder: String
    @Binding var searchDraft: String
    var onSubmit: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            WorkbenchSearchField(
                placeholder: placeholder,
                text: $searchDraft,
                onSubmit: onSubmit
            )
            .frame(maxWidth: .infinity)
        }
        .frame(height: WorkbenchControlMetrics.searchFieldHeight)
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

struct SchemaWorkbenchLegacyFilterControlBar: View {
    var isFilterPanelOpen: Bool = false
    var onFilter: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            WorkbenchToolbarButton(
                title: L("table.filter"),
                systemImage: "line.3.horizontal.decrease",
                showsChevron: true,
                isMenuOpen: isFilterPanelOpen,
                action: onFilter
            )

            Spacer(minLength: 0)
        }
        .frame(height: WorkbenchControlMetrics.controlHeight)
    }
}
