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

func schemaWorkbenchExcerptCountText(_ count: Int) -> String {
    let safeCount = max(0, count)
    return safeCount == 1
        ? L("table.excerpt_count.one")
        : L("table.excerpt_count.other", safeCount)
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
    let isFilterDialogOpen: Bool
    let filterSelectionCount: Int
    let onOpenFilterDialog: () -> Void
    /// Registered with the Selection Action Overlay's own area, so the table
    /// can tell when the pointer is over it.
    let selectionOverlayAnchor: MenuAnchorHandle?
    var onSearchSubmit: (() -> Void)?
    let tableContent: ([WorkbenchTableColumn]) -> TableContent

    @StateObject private var externalTextSelectionSession = SubtitleTableExternalTextSelectionSession()
    @StateObject private var pageScrollbar = WorkbenchPageScrollbar()

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
        isFilterDialogOpen: Bool = false,
        filterSelectionCount: Int = 0,
        onOpenFilterDialog: @escaping () -> Void,
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
        self.isFilterDialogOpen = isFilterDialogOpen
        self.filterSelectionCount = filterSelectionCount
        self.onOpenFilterDialog = onOpenFilterDialog
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
            isFilterDialogOpen: isFilterDialogOpen,
            filterSelectionCount: filterSelectionCount,
            canEnterSelectionMode: canEnterSelectionMode,
            onSubmit: onSearchSubmit,
            onFilter: onOpenFilterDialog,
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
    var isFilterDialogOpen: Bool = false
    /// The options the table's selection holds; nothing is drawn at zero.
    var filterSelectionCount: Int = 0
    var canEnterSelectionMode: Bool = false
    var onSubmit: (() -> Void)?
    var onFilter: () -> Void
    var onToggleSelectionMode: () -> Void

    var body: some View {
        VStack(spacing: WorkbenchControlMetrics.redesignSpacing2) {
            WorkbenchSearchField(
                placeholder: placeholder,
                text: $searchDraft,
                isRedesign: true,
                trailingStatusText: nil,
                onSubmit: onSubmit
            )
            .frame(maxWidth: .infinity)
            .frame(height: WorkbenchControlMetrics.redesignSearchHeight)
            .disabled(isSelectionMode)

            if isSelectionMode {
                selectionBanner
            } else {
                defaultActionRow
            }
        }
    }

    private var defaultActionRow: some View {
        HStack(spacing: WorkbenchControlMetrics.redesignSpacing3) {
            if let searchResultCountText, !searchResultCountText.isEmpty {
                Text(searchResultCountText)
                    .font(.system(
                        size: WorkbenchControlMetrics.redesignFontSizeBody,
                        weight: .regular
                    ))
                    .foregroundStyle(WorkbenchRedesignColors.textMuted)
                    .lineLimit(1)
            }

            Spacer()

            WorkbenchButton(
                icon: .funnel,
                count: filterSelectionCount,
                isRedesign: true,
                isOpen: isFilterDialogOpen,
                action: onFilter
            )
            .accessibilityLabel(L("table.filter"))
        }
        .frame(maxWidth: .infinity)
        .frame(height: WorkbenchControlMetrics.redesignSearchHeight)
    }

    private var selectionBanner: some View {
        HStack(spacing: WorkbenchControlMetrics.redesignSpacing3) {
            Text(L("table.batch_selection_banner_hint"))
                .font(.system(
                    size: WorkbenchControlMetrics.redesignFontSizeBody,
                    weight: .regular
                ))
                .foregroundStyle(WorkbenchRedesignColors.filterChipSelectedContent)
                .lineLimit(1)
                .padding(.leading, WorkbenchControlMetrics.redesignSpacing3)

            Spacer()

            WorkbenchButton(
                title: L("table.exit_select"),
                isRedesign: true,
                action: onToggleSelectionMode
            )
            .padding(.trailing, WorkbenchControlMetrics.redesignSpacing1)
        }
        .frame(maxWidth: .infinity)
        .frame(height: WorkbenchControlMetrics.redesignSearchHeight)
        .background(
            RoundedRectangle(
                cornerRadius: WorkbenchControlMetrics.redesignCornerRadius,
                style: .continuous
            )
            .fill(WorkbenchRedesignColors.filterChipSelectedBg)
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: WorkbenchControlMetrics.redesignCornerRadius,
                style: .continuous
            )
            .strokeBorder(WorkbenchRedesignColors.filterChipSelectedContent, lineWidth: 1)
        )
    }
}
