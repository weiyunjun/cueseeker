import SwiftUI

enum SchemaWorkbenchPopover: Equatable {
    case columnVisibility
}

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

    static let initialVisibleColumnIDs = Set(columns.map(\.id))
    static let initialVisibleShioriColumnIDs = Set(shioriColumns.map(\.id))

}

struct SchemaWorkbenchSearchShell<TableContent: View>: View {
    @Environment(\.isWorkbenchPopupLayerOpen) private var isParentWorkbenchPopupLayerOpen

    @Binding var searchDraft: String
    @Binding var visibleColumnIDs: Set<String>

    let columns: [WorkbenchTableColumn]
    let searchPlaceholder: String
    let isRedesign: Bool
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

    @State private var openPopover: SchemaWorkbenchPopover?
    @State private var shellDropdownFrames: [String: CGRect] = [:]
    @State private var openPopoverWidth: CGFloat = 0
    @StateObject private var externalTextSelectionSession = SubtitleTableExternalTextSelectionSession()

    init(
        searchDraft: Binding<String>,
        visibleColumnIDs: Binding<Set<String>>,
        columns: [WorkbenchTableColumn],
        searchPlaceholder: String = "Search cues by name, lyrics, or keywords...",
        isRedesign: Bool = false,
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
        _visibleColumnIDs = visibleColumnIDs
        self.columns = columns
        self.searchPlaceholder = searchPlaceholder
        self.isRedesign = isRedesign
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

            VStack(spacing: 0) {
                if isRedesign {
                    SchemaWorkbenchSearchToolbar(
                        placeholder: searchPlaceholder,
                        searchDraft: $searchDraft,
                        searchResultCountText: searchResultCountText,
                        isSelectionMode: isSelectionMode,
                        isFilterPanelOpen: isFilterPanelVisible,
                        isViewMenuOpen: openPopover == .columnVisibility,
                        canEnterSelectionMode: canEnterSelectionMode,
                        onSubmit: onSearchSubmit,
                        onFilter: {
                            openPopover = nil
                            onToggleFilterPanel()
                        },
                        onViewMenu: {
                            togglePopover(.columnVisibility)
                        },
                        onToggleSelectionMode: onToggleSelectionMode
                    )
                    .padding(.horizontal, SchemaWorkbenchStyle.pageHorizontalPadding)
                    .padding(.top, SchemaWorkbenchStyle.pageTopPadding)
                    .padding(.bottom, WorkbenchControlMetrics.redesignSpacing3)
                } else {
                    SchemaWorkbenchLegacySearchCommandBar(
                        placeholder: searchPlaceholder,
                        searchDraft: $searchDraft,
                        isViewMenuOpen: openPopover == .columnVisibility,
                        onSubmit: onSearchSubmit,
                        onViewMenu: {
                            togglePopover(.columnVisibility)
                        }
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
                    tableContent(visibleColumns)

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
                    .padding(.bottom, SchemaWorkbenchStyle.pageBottomPadding)
                    .frame(maxHeight: .infinity)
            }

            overlayLayer
        }
        .environment(\.isWorkbenchPopupLayerOpen, isAnyWorkbenchPopupLayerOpen)
        .environment(\.subtitleTableExternalTextSelectionSession, externalTextSelectionSession)
        .coordinateSpace(name: "SearchShellSpace")
        .onPreferenceChange(WorkbenchDropdownAnchorPreferenceKey.self) { frames in
            self.shellDropdownFrames = frames
        }
        .onChange(of: openPopover) { _ in
            self.openPopoverWidth = 0
        }
        .onChange(of: isSelectionMode) { isSelecting in
            if isSelecting {
                openPopover = nil
            }
        }
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

    private var isAnyWorkbenchPopupLayerOpen: Bool {
        isParentWorkbenchPopupLayerOpen || openPopover != nil
    }

    private var externalTextSelectionIsBlocked: Bool {
        !isRedesign || isParentWorkbenchPopupLayerOpen || isSelectionMode
    }

    private var externalTextSelectionStartPolicy: SubtitleTableExternalTextSelectionStartPolicy {
        return SubtitleTableExternalTextSelectionStartPolicy(
            isBlocked: externalTextSelectionIsBlocked
        )
    }

    @ViewBuilder
    private var overlayLayer: some View {
        if let openPopover {
            GeometryReader { geometry in
                ZStack(alignment: .topLeading) {
                    Button {
                        self.openPopover = nil
                    } label: {
                        Color.clear
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .subtitleTableTextSelectionInteractiveRegion()

                    popoverView(openPopover, geometry: geometry)
                }
            }
            .zIndex(10)
        }
    }

    @ViewBuilder
    private func popoverView(
        _ popover: SchemaWorkbenchPopover,
        geometry: GeometryProxy
    ) -> some View {
        switch popover {
        case .columnVisibility:
            SchemaWorkbenchColumnVisibilityPopover(
                columns: columns,
                visibleColumnIDs: visibleColumnIDs,
                isRedesign: isRedesign,
                onToggleColumn: toggleColumnVisibility
            )
            .frame(
                minWidth: isRedesign ? max(220, shellDropdownFrames["view"]?.width ?? 220) : 220,
                alignment: .topLeading
            )
            .fixedSize(horizontal: isRedesign, vertical: false)
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onAppear {
                            self.openPopoverWidth = geo.size.width
                        }
                        .onChange(of: geo.size.width) { newWidth in
                            self.openPopoverWidth = newWidth
                        }
                }
            )
            .offset(
                x: isRedesign ? {
                    let triggerMinX = shellDropdownFrames["view"]?.minX ?? (geometry.size.width - SchemaWorkbenchStyle.pageHorizontalPadding - 220)
                    let popoverWidth = self.openPopoverWidth > 0 ? self.openPopoverWidth : max(220, shellDropdownFrames["view"]?.width ?? 220)
                    let rightLimit = geometry.size.width - SchemaWorkbenchStyle.pageHorizontalPadding
                    return max(SchemaWorkbenchStyle.pageHorizontalPadding, min(triggerMinX, rightLimit - popoverWidth))
                }() : max(
                    SchemaWorkbenchStyle.pageHorizontalPadding,
                    geometry.size.width - SchemaWorkbenchStyle.pageHorizontalPadding - 220
                ),
                y: isRedesign ? ((shellDropdownFrames["view"]?.maxY ?? 0) + 4) : SchemaWorkbenchStyle.viewPopoverTop(isRedesign: isRedesign)
            )
        }
    }

    private func togglePopover(_ popover: SchemaWorkbenchPopover) {
        openPopover = openPopover == popover ? nil : popover
    }

    private var visibleColumns: [WorkbenchTableColumn] {
        columns.filter {
            visibleColumnIDs.contains($0.id) ||
                SchemaWorkbenchColumnVisibilityMenu.isLocked($0.id)
        }
    }

    private func toggleColumnVisibility(_ columnID: String) {
        guard !SchemaWorkbenchColumnVisibilityMenu.isLocked(columnID) else {
            visibleColumnIDs.insert(columnID)
            return
        }
        if visibleColumnIDs.contains(columnID) {
            visibleColumnIDs.remove(columnID)
        } else {
            visibleColumnIDs.insert(columnID)
        }
    }

}

enum SchemaWorkbenchStyle {
    static let pageHorizontalPadding = WorkbenchControlMetrics.redesignSpacing8
    static let pageTopPadding: CGFloat = 10
    static let pageBottomPadding: CGFloat = 14
    static let tableCornerRadius: CGFloat = 8
    static let hairlineWidth: CGFloat = 0.5

    static func viewPopoverTop(isRedesign: Bool) -> CGFloat {
        let searchHeight = isRedesign ? WorkbenchControlMetrics.redesignSearchHeight : WorkbenchControlMetrics.searchFieldHeight
        return pageTopPadding + searchHeight + 8
    }

}

struct SchemaWorkbenchSearchToolbar: View {
    let placeholder: String
    @Binding var searchDraft: String
    let searchResultCountText: String?
    var isSelectionMode: Bool = false
    var isFilterPanelOpen: Bool = false
    var isViewMenuOpen: Bool = false
    var canEnterSelectionMode: Bool = false
    var onSubmit: (() -> Void)?
    var onFilter: () -> Void
    var onViewMenu: () -> Void
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
                title: "View",
                systemImage: "slider.horizontal.3",
                showsChevron: true,
                isRedesign: true,
                isMenuOpen: isViewMenuOpen,
                action: onViewMenu
            )
            .workbenchDropdownAnchor(id: "view", in: "SearchShellSpace")
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
    var isViewMenuOpen: Bool = false
    var onSubmit: (() -> Void)?
    var onViewMenu: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            WorkbenchSearchField(
                placeholder: placeholder,
                text: $searchDraft,
                onSubmit: onSubmit
            )
            .frame(maxWidth: .infinity)

            WorkbenchToolbarButton(
                title: "View",
                systemImage: "slider.horizontal.3",
                showsChevron: true,
                isMenuOpen: isViewMenuOpen,
                action: onViewMenu
            )
            .workbenchDropdownAnchor(id: "view", in: "SearchShellSpace")
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

struct SchemaWorkbenchColumnVisibilityMenuItem: Identifiable, Equatable {
    let id: String
    let title: String
    let isSelected: Bool
    let isEnabled: Bool
}

enum SchemaWorkbenchColumnVisibilityMenu {
    static let lockedColumnIDs: Set<String> = ["cues"]

    static func isLocked(_ columnID: String) -> Bool {
        lockedColumnIDs.contains(columnID)
    }

    static func items(
        columns: [WorkbenchTableColumn],
        visibleColumnIDs: Set<String>
    ) -> [SchemaWorkbenchColumnVisibilityMenuItem] {
        columns
            .filter { $0.kind != .rowNumber }
            .map { column in
                let locked = isLocked(column.id)
                return SchemaWorkbenchColumnVisibilityMenuItem(
                    id: column.id,
                    title: column.title,
                    isSelected: locked || visibleColumnIDs.contains(column.id),
                    isEnabled: !locked
                )
            }
    }
}

struct SchemaWorkbenchColumnVisibilityPopover: View {
    let columns: [WorkbenchTableColumn]
    let visibleColumnIDs: Set<String>
    var isRedesign: Bool = false
    var onToggleColumn: (String) -> Void

    var body: some View {
        WorkbenchPopoverPanel(isRedesign: isRedesign) {
            VStack(spacing: 0) {
                ForEach(menuItems) { item in
                    WorkbenchPopoverRow(
                        title: item.title,
                        isSelected: item.isSelected,
                        isRedesign: isRedesign,
                        isEnabled: item.isEnabled,
                        action: item.isEnabled ? {
                            onToggleColumn(item.id)
                        } : nil
                    )
                }
            }
        }
    }

    private var menuItems: [SchemaWorkbenchColumnVisibilityMenuItem] {
        SchemaWorkbenchColumnVisibilityMenu.items(
            columns: columns,
            visibleColumnIDs: visibleColumnIDs
        )
    }
}
