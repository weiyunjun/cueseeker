import SwiftUI

struct SchemaWorkbenchTableSummary: Equatable {
    let totalRowCount: Int
    let selectedRowCount: Int
}

func schemaWorkbenchResultCountText(_ count: Int) -> String {
    let safeCount = max(0, count)
    return safeCount == 1 ? "1 result" : "\(safeCount) results"
}

func schemaWorkbenchSelectedCountText(_ count: Int) -> String {
    "\(max(0, count)) selected"
}

func schemaWorkbenchCanEnterSelectionMode(hasExactResultSet: Bool) -> Bool {
    hasExactResultSet
}

enum SchemaWorkbenchSearchDefaults {
    static let columns: [WorkbenchTableColumn] = [
        WorkbenchTableColumn(
            id: "rowNumber",
            title: "#",
            kind: .rowNumber,
            width: .fixed(50)
        ),
        WorkbenchTableColumn(
            id: "cues",
            title: "Cues",
            kind: .text,
            width: .weighted(weight: 6, min: 240)
        ),
        WorkbenchTableColumn(
            id: "display",
            title: "Display Title",
            kind: .text,
            width: .weighted(weight: 3, min: 180)
        ),
        WorkbenchTableColumn(
            id: "time",
            title: "Time Range",
            kind: .text,
            width: .weighted(weight: 2, min: 140)
        ),
    ]

    static let shioriColumns: [WorkbenchTableColumn] = [
        WorkbenchTableColumn(
            id: "rowNumber",
            title: "#",
            kind: .rowNumber,
            width: .fixed(50)
        ),
        WorkbenchTableColumn(
            id: "cues",
            title: "Cues",
            kind: .text,
            width: .weighted(weight: 6, min: 240)
        ),
        WorkbenchTableColumn(
            id: "display",
            title: "Display Title",
            kind: .text,
            width: .weighted(weight: 3, min: 180)
        ),
        WorkbenchTableColumn(
            id: "time",
            title: "Time Range",
            kind: .text,
            width: .weighted(weight: 2, min: 140)
        ),
        WorkbenchTableColumn(
            id: "dateAdded",
            title: "Date Added",
            kind: .text,
            width: .weighted(weight: 2, min: 120)
        ),
    ]
}

struct SchemaWorkbenchSearchShell<TableContent: View>: View {
    @Environment(\.isWorkbenchPopupLayerOpen) private var isParentWorkbenchPopupLayerOpen

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
    let filterPanel: AnyView
    let isFilterPanelVisible: Bool
    let onToggleFilterPanel: () -> Void
    var onSearchSubmit: (() -> Void)?
    let tableContent: ([WorkbenchTableColumn]) -> TableContent

    @StateObject private var externalTextSelectionSession = SubtitleTableExternalTextSelectionSession()

    init(
        searchDraft: Binding<String>,
        columns: [WorkbenchTableColumn],
        pageTitle: String? = nil,
        searchPlaceholder: String = "Search cues by name, lyrics, or keywords...",
        isRedesign: Bool = false,
        summaryContent: AnyView? = nil,
        hostsPageChromeInTable: Bool = false,
        tableSummary: SchemaWorkbenchTableSummary? = nil,
        searchResultCountText: String? = nil,
        selectionActions: AnyView? = nil,
        isSelectionMode: Bool = false,
        canEnterSelectionMode: Bool = false,
        onToggleSelectionMode: @escaping () -> Void = {},
        filterPanel: AnyView,
        isFilterPanelVisible: Bool = false,
        onToggleFilterPanel: @escaping () -> Void,
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
        self.filterPanel = filterPanel
        self.isFilterPanelVisible = isFilterPanelVisible
        self.onToggleFilterPanel = onToggleFilterPanel
        self.onSearchSubmit = onSearchSubmit
        self.tableContent = tableContent
    }

    var body: some View {
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
                            actions: selectionActions
                        )
                        .padding(.bottom, WorkbenchControlMetrics.redesignSpacing4)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 0) {
                    if isRedesign, let pageTitle {
                        WorkbenchPageTitle(pageTitle)
                            .padding(.horizontal, SchemaWorkbenchStyle.pageHorizontalPadding)
                            .padding(
                                .top,
                                WorkbenchControlMetrics.redesignWorkbenchPageTopPadding
                            )
                            .padding(.bottom, WorkbenchControlMetrics.redesignSpacing4)
                    }

                    if isRedesign {
                        searchToolbar
                            .padding(.horizontal, SchemaWorkbenchStyle.pageHorizontalPadding)
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
                        .padding(.horizontal, SchemaWorkbenchStyle.pageHorizontalPadding)
                        .padding(.top, SchemaWorkbenchStyle.pageTopPadding)
                        .padding(.bottom, 12)

                        SchemaWorkbenchLegacyFilterControlBar(
                            isFilterPanelOpen: isFilterPanelVisible,
                            onFilter: onToggleFilterPanel
                        )
                        .padding(.horizontal, SchemaWorkbenchStyle.pageHorizontalPadding)
                        .padding(.bottom, 12)
                    }

                    if isRedesign,
                       isFilterPanelVisible {
                        filterPanel
                            .padding(.horizontal, SchemaWorkbenchStyle.pageHorizontalPadding)
                            .padding(.bottom, WorkbenchControlMetrics.redesignSpacing3)
                    }

                    ZStack(alignment: .bottom) {
                        tableContent(columns)

                        if isRedesign,
                           let tableSummary,
                           tableSummary.selectedRowCount > 0,
                           let selectionActions {
                            SchemaWorkbenchSelectionActionOverlay(
                                selectedRowCount: tableSummary.selectedRowCount,
                                actions: selectionActions
                            )
                            .padding(.bottom, WorkbenchControlMetrics.redesignSpacing4)
                        }
                    }
                    .padding(.horizontal, SchemaWorkbenchStyle.pageHorizontalPadding)
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
        .environment(\.subtitleTableExternalTextSelectionSession, externalTextSelectionSession)
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

    private var externalTextSelectionIsBlocked: Bool {
        !isRedesign || isParentWorkbenchPopupLayerOpen || isSelectionMode
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
            isFilterPanelOpen: isFilterPanelVisible,
            canEnterSelectionMode: canEnterSelectionMode,
            onSubmit: onSearchSubmit,
            onFilter: onToggleFilterPanel,
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
    var isFilterPanelOpen: Bool = false
    var canEnterSelectionMode: Bool = false
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

            WorkbenchToolbarButton(
                title: "Filter",
                systemImage: "line.3.horizontal.decrease",
                showsChevron: true,
                isRedesign: true,
                isMenuOpen: isFilterPanelOpen,
                action: onFilter
            )
            .disabled(isSelectionMode)

            WorkbenchToolbarButton(
                title: isSelectionMode ? "Exit Select" : "Select",
                systemImage: "square.and.pencil",
                isRedesign: true,
                action: onToggleSelectionMode
            )
            .disabled(!isSelectionMode && !canEnterSelectionMode)
        }
        .frame(height: WorkbenchControlMetrics.redesignHeight)
    }
}

struct SchemaWorkbenchSelectionActionOverlay: View {
    let selectedRowCount: Int
    let actions: AnyView

    var body: some View {
        HStack(spacing: WorkbenchControlMetrics.redesignSpacing3) {
            Text(schemaWorkbenchSelectedCountText(selectedRowCount))
                .font(.system(
                    size: WorkbenchControlMetrics.redesignFontSizeBody,
                    weight: .regular
                ))
                .foregroundStyle(WorkbenchRedesignColors.textSecondary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)

            actions
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

struct SchemaWorkbenchLegacyFilterControlBar: View {
    var isFilterPanelOpen: Bool = false
    var onFilter: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            WorkbenchToolbarButton(
                title: "Filter",
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
