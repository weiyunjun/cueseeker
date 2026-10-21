import AppKit
import CueSeekerCore
import SwiftUI

struct SchemaWorkbenchTableSummary: Equatable {
    let totalRowCount: Int
    /// The rows Select Mode can select: the total less the unavailable rows.
    let selectableRowCount: Int
    let selectedRowCount: Int
}

struct SchemaWorkbenchSortOption: Identifiable, Equatable {
    let id: String
    let title: String
}

extension SearchSortOrder {
    var title: String {
        switch self {
        case .default:
            return L("search.sort.default")
        case .mostCharacters:
            return L("search.sort.most_characters")
        case .fewestCharacters:
            return L("search.sort.fewest_characters")
        }
    }

    static var workbenchSortOptions: [SchemaWorkbenchSortOption] {
        allCases.map { SchemaWorkbenchSortOption(id: $0.rawValue, title: $0.title) }
    }
}

extension ExcerptSortOrder {
    var title: String {
        switch self {
        case .earliestDateAdded:
            return L("excerpt.sort.earliest_date_added")
        case .latestDateAdded:
            return L("excerpt.sort.latest_date_added")
        case .mostCharacters:
            return L("excerpt.sort.most_characters")
        case .fewestCharacters:
            return L("excerpt.sort.fewest_characters")
        }
    }

    static var workbenchSortOptions: [SchemaWorkbenchSortOption] {
        allCases.map { SchemaWorkbenchSortOption(id: $0.rawValue, title: $0.title) }
    }
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
    let isFilterDialogOpen: Bool
    let filterSelectionCount: Int
    let onOpenFilterDialog: () -> Void
    let sortOptions: [SchemaWorkbenchSortOption]
    let selectedSortOptionID: String
    let onSelectSortOption: (String) -> Void
    let externalSortButtonAnchor: MenuAnchorHandle?
    let externalIsSortMenuOpen: Binding<Bool>?
    /// Registered with the Selection Action Overlay's own area, so the table
    /// can tell when the pointer is over it.
    let selectionOverlayAnchor: MenuAnchorHandle?
    var onSearchSubmit: (() -> Void)?
    let tableContent: ([WorkbenchTableColumn]) -> TableContent

    @StateObject private var externalTextSelectionSession = SubtitleTableExternalTextSelectionSession()
    @StateObject private var pageScrollbar = WorkbenchPageScrollbar()
    @State private var internalSortButtonAnchor = MenuAnchorHandle()
    @State private var sortMenuHostAnchor = MenuAnchorHandle()
    @State private var activeSortMenu: SchemaWorkbenchSortMenuState?
    @StateObject private var sortMenuHighlight = MenuHighlightModel()

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
        sortOptions: [SchemaWorkbenchSortOption] = SearchSortOrder.workbenchSortOptions,
        selectedSortOptionID: String = SearchSortOrder.default.rawValue,
        onSelectSortOption: @escaping (String) -> Void = { _ in },
        sortButtonAnchor: MenuAnchorHandle? = nil,
        isSortMenuOpen: Binding<Bool>? = nil,
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
        self.sortOptions = sortOptions
        self.selectedSortOptionID = selectedSortOptionID
        self.onSelectSortOption = onSelectSortOption
        self.externalSortButtonAnchor = sortButtonAnchor
        self.externalIsSortMenuOpen = isSortMenuOpen
        self.selectionOverlayAnchor = selectionOverlayAnchor
        self.onSearchSubmit = onSearchSubmit
        self.tableContent = tableContent
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                pageBody
                    .frame(
                        width: geometry.size.width,
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

                WorkbenchPageScrollbarOverlay(
                    scrollbar: pageScrollbar,
                    axis: .vertical
                )
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .background(MenuAnchorProbe(handle: sortMenuHostAnchor))
            .overlay(alignment: .topLeading) {
                if let activeSortMenu {
                    let menuFrame = activeSortMenu.menuFrame
                    ZStack(alignment: .topLeading) {
                        MenuGateClientView(
                            gate: interfaceLayers?.menuGate,
                            owner: layerContext.layer,
                            kind: .cardMenu,
                            menuFrame: menuFrame,
                            anchorFrame: activeSortMenu.anchorFrame,
                            handleKey: { keyCode, _ in
                                switch keyCode {
                                case 53:
                                    dismissSortMenu()
                                    return true
                                case 126:
                                    _ = sortMenuHighlight.moveHighlight(by: -1)
                                    return true
                                case 125:
                                    _ = sortMenuHighlight.moveHighlight(by: 1)
                                    return true
                                case 123, 124:
                                    return true
                                case 36, 76:
                                    activateHighlightedSortItem()
                                    return true
                                default:
                                    return false
                                }
                            },
                            dismiss: { _ in
                                dismissSortMenu()
                            }
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .allowsHitTesting(false)

                        SchemaWorkbenchSortMenuPopover(
                            options: sortOptions,
                            selectedOptionID: selectedSortOptionID,
                            highlight: sortMenuHighlight,
                            onSelect: { optionID in
                                onSelectSortOption(optionID)
                                dismissSortMenu()
                            },
                            onDismiss: {
                                dismissSortMenu()
                            }
                        )
                        .offset(x: menuFrame.minX, y: menuFrame.minY)
                    }
                    .zIndex(1001)
                }
            }
            .onChange(of: externalIsSortMenuOpen?.wrappedValue ?? false) { isOpen in
                if isOpen {
                    if activeSortMenu == nil {
                        openSortMenu(viewportSize: geometry.size)
                    }
                } else if activeSortMenu != nil {
                    dismissSortMenu()
                }
            }
        }
        .environment(\.subtitleTableExternalTextSelectionSession, externalTextSelectionSession)
        .environment(\.workbenchPageScrollbar, pageScrollbar)
        .onChange(of: externalTextSelectionIsBlocked) { isBlocked in
            if isBlocked {
                externalTextSelectionSession.cancel()
            }
        }
        .onChange(of: isSelectionMode) { inSelectionMode in
            if inSelectionMode {
                dismissSortMenu()
            }
        }
        .onChange(of: isFilterDialogOpen) { isOpen in
            if isOpen {
                dismissSortMenu()
            }
        }
        .onChange(of: isWorkbenchPageCovered) { isCovered in
            if isCovered {
                dismissSortMenu()
            }
        }
        .onDisappear {
            dismissSortMenu()
            externalTextSelectionSession.cancel()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                // The detail hosts its page chrome inside the table, so the
                // table would otherwise run to the window edge and put the
                // content a page margin lower than every other Workbench page.
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
                            .padding(.bottom, SchemaWorkbenchStyle.toolbarBottomGap)
                    }

                    tableContent(columns)
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

    private var externalTextSelectionIsBlocked: Bool {
        !isRedesign || isWorkbenchPageCovered || isSelectionMode
    }

    private var externalTextSelectionStartPolicy: SubtitleTableExternalTextSelectionStartPolicy {
        return SubtitleTableExternalTextSelectionStartPolicy(
            isBlocked: externalTextSelectionIsBlocked
        )
    }

    private var resolvedSortButtonAnchor: MenuAnchorHandle {
        externalSortButtonAnchor ?? internalSortButtonAnchor
    }

    private var currentSortTitle: String {
        sortOptions.first(where: { $0.id == selectedSortOptionID })?.title
            ?? sortOptions.first?.title
            ?? L("search.sort.default")
    }

    private var selectedCountText: String? {
        guard let tableSummary else { return nil }
        return schemaWorkbenchSelectedCountText(
            selectedRowCount: tableSummary.selectedRowCount,
            selectableRowCount: tableSummary.selectableRowCount
        )
    }

    private var searchToolbar: some View {
        SchemaWorkbenchSearchToolbar(
            placeholder: searchPlaceholder,
            searchDraft: $searchDraft,
            searchResultCountText: searchResultCountText,
            selectedCountText: selectedCountText,
            selectionActions: selectionActions ?? [],
            isSelectionMode: isSelectionMode,
            isFilterDialogOpen: isFilterDialogOpen,
            filterSelectionCount: filterSelectionCount,
            canEnterSelectionMode: canEnterSelectionMode,
            sortTitle: currentSortTitle,
            isSortMenuOpen: activeSortMenu != nil,
            sortButtonAnchor: resolvedSortButtonAnchor,
            onSubmit: onSearchSubmit,
            onFilter: {
                dismissSortMenu()
                onOpenFilterDialog()
            },
            onSort: toggleSortMenu,
            onToggleSelectionMode: onToggleSelectionMode
        )
    }

    private func toggleSortMenu() {
        if activeSortMenu != nil {
            dismissSortMenu()
        } else {
            let viewportSize = sortMenuHostAnchor.bounds?.size ?? .zero
            openSortMenu(viewportSize: viewportSize)
        }
    }

    private func openSortMenu(viewportSize: CGSize) {
        guard !isSelectionMode,
              !sortOptions.isEmpty,
              let anchorFrame = resolvedSortButtonAnchor.frame(in: sortMenuHostAnchor)
        else {
            externalIsSortMenuOpen?.wrappedValue = false
            return
        }
        let resolvedViewportSize = viewportSize == .zero
            ? (sortMenuHostAnchor.bounds?.size ?? .zero)
            : viewportSize
        let naturalSize = measuredSortMenuSize()
        let container = CGRect(origin: .zero, size: resolvedViewportSize)
        let openingFrame = MenuPlacement.openingFrame(
            anchor: anchorFrame,
            menuSize: naturalSize,
            in: container,
            gap: WorkbenchControlMetrics.redesignSpacing1,
            shrinksToFit: false
        )
        activeSortMenu = SchemaWorkbenchSortMenuState(
            anchorFrame: anchorFrame,
            menuFrame: openingFrame
        )
        externalIsSortMenuOpen?.wrappedValue = true
        sortMenuHighlight.open(
            selectablePositions: Array(sortOptions.indices),
            defaultPosition: 0
        )
    }

    private func dismissSortMenu() {
        activeSortMenu = nil
        if externalIsSortMenuOpen?.wrappedValue == true {
            externalIsSortMenuOpen?.wrappedValue = false
        }
        sortMenuHighlight.close()
    }

    private func activateHighlightedSortItem() {
        guard let position = sortMenuHighlight.highlightedPosition,
              sortOptions.indices.contains(position)
        else {
            return
        }
        let option = sortOptions[position]
        onSelectSortOption(option.id)
        dismissSortMenu()
    }

    private func measuredSortMenuSize() -> CGSize {
        let host = NSHostingView(
            rootView: SchemaWorkbenchSortMenuPopover(
                options: sortOptions,
                selectedOptionID: selectedSortOptionID,
                highlight: sortMenuHighlight,
                onSelect: { _ in },
                onDismiss: {}
            )
        )
        host.layoutSubtreeIfNeeded()
        return host.fittingSize
    }
}

enum SchemaWorkbenchStyle {
    static let pageHorizontalPadding =
        WorkbenchControlMetrics.redesignWorkbenchPageHorizontalPadding
    static let toolbarRowSpacing =
        WorkbenchControlMetrics.redesignSpacing2
    static let toolbarBottomGap =
        WorkbenchControlMetrics.redesignSpacing2
    static let resultCountLeadingPadding: CGFloat = 0
    static let selectionSummaryLeadingPadding: CGFloat = 0
    static let selectionActionRowLeadingPadding: CGFloat = 0
    static let pinnedToolbarHeight =
        WorkbenchControlMetrics.redesignHeight * 2
            + toolbarRowSpacing
            + toolbarBottomGap
}

struct SchemaWorkbenchSearchToolbar: View {
    @Environment(\.interfaceLayerContext) private var layerContext

    let placeholder: String
    @Binding var searchDraft: String
    let searchResultCountText: String?
    var selectedCountText: String? = nil
    var selectionActions: [SchemaWorkbenchSelectionAction] = []
    var isSelectionMode: Bool = false
    var isFilterDialogOpen: Bool = false
    /// The options the table's selection holds; nothing is drawn at zero.
    var filterSelectionCount: Int = 0
    var canEnterSelectionMode: Bool = false
    var sortTitle: String = L("search.sort.default")
    var isSortMenuOpen: Bool = false
    var sortButtonAnchor: MenuAnchorHandle? = nil
    var onSubmit: (() -> Void)?
    var onFilter: () -> Void
    var onSort: () -> Void = {}
    var onToggleSelectionMode: () -> Void

    var body: some View {
        VStack(spacing: SchemaWorkbenchStyle.toolbarRowSpacing) {
            if isSelectionMode {
                selectionSummaryRow
                selectionActionsRow
            } else {
                topInputAndActionsRow
                defaultResultCountRow
            }
        }
        .background {
            if isSelectionMode {
                WindowKeyDownMonitor(handle: handleSelectionShortcut)
            }
        }
    }

    private var searchField: some View {
        WorkbenchSearchField(
            placeholder: placeholder,
            text: $searchDraft,
            isRedesign: true,
            trailingStatusText: nil,
            onSubmit: onSubmit
        )
    }

    private var filterButton: some View {
        WorkbenchButton(
            title: L("table.filter"),
            icon: .funnel,
            count: filterSelectionCount,
            isRedesign: true,
            isOpen: isFilterDialogOpen,
            action: onFilter
        )
        .accessibilityLabel(L("table.filter"))
    }

    private var sortButton: some View {
        WorkbenchButton(
            title: sortTitle,
            icon: .funnelSimple,
            isRedesign: true,
            isOpen: isSortMenuOpen,
            action: onSort
        )
        .background {
            if let sortButtonAnchor {
                MenuAnchorProbe(handle: sortButtonAnchor)
            }
        }
        .accessibilityLabel(sortTitle)
    }

    private var topInputAndActionsRow: some View {
        HStack(spacing: WorkbenchControlMetrics.redesignSpacing4) {
            searchField
                .frame(minWidth: 0, maxWidth: .infinity)

            filterButton
                .layoutPriority(1)

            sortButton
                .layoutPriority(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: WorkbenchControlMetrics.redesignHeight)
    }

    private var defaultResultCountRow: some View {
        HStack(spacing: WorkbenchControlMetrics.redesignSpacing4) {
            if let searchResultCountText, !searchResultCountText.isEmpty {
                WorkbenchStatusIndicator(searchResultCountText)
                    .padding(.leading, SchemaWorkbenchStyle.resultCountLeadingPadding)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: WorkbenchControlMetrics.redesignHeight)
    }

    private var selectionSummaryRow: some View {
        let bannerHint = L("table.batch_selection_banner_hint")
        return HStack(spacing: WorkbenchControlMetrics.redesignSpacing4) {
            if let selectedCountText, !selectedCountText.isEmpty {
                WorkbenchStatusIndicator(selectedCountText)
                    .fixedSize(horizontal: true, vertical: false)
                    .layoutPriority(1)
            }

            Text(bannerHint)
                .font(.system(
                    size: WorkbenchControlMetrics.redesignFontSizeBody,
                    weight: .regular
                ))
                .foregroundStyle(WorkbenchRedesignColors.textMuted)
                .lineLimit(1)
                .truncationMode(.tail)
                .workbenchTruncatedTextTooltip(
                    scenarioID: "truncated.toolbar.batch_selection_banner",
                    text: bannerHint,
                    font: .system(
                        size: WorkbenchControlMetrics.redesignFontSizeBody,
                        weight: .regular
                    )
                )

            Spacer(minLength: 0)

            WorkbenchDestructiveButton(
                title: L("table.exit_select"),
                icon: .signOut,
                action: onToggleSelectionMode
            )
            .workbenchTooltip(
                scenarioID: "toolbar.selection.exit",
                label: L("table.exit_select"),
                shortcut: .fixed("Esc")
            )
            .layoutPriority(1)
        }
        .padding(.leading, SchemaWorkbenchStyle.selectionSummaryLeadingPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: WorkbenchControlMetrics.redesignHeight)
    }

    private var selectionActionsRow: some View {
        HStack(spacing: WorkbenchControlMetrics.redesignSpacing4) {
            ForEach(selectionActions) { action in
                SchemaWorkbenchSelectionActionButton(action: action)
            }

            Spacer(minLength: 0)
        }
        .padding(.leading, SchemaWorkbenchStyle.selectionActionRowLeadingPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: WorkbenchControlMetrics.redesignHeight)
    }

    private func handleSelectionShortcut(_ event: NSEvent) -> Bool {
        guard isSelectionMode,
              !layerContext.isFrozen,
              event.modifierFlags
                  .intersection([.command, .control, .option, .shift])
                  .isEmpty,
              !AppCoordinator.isEditableTextInputFocused()
        else {
            return false
        }
        if event.keyCode == 53 {
            if !event.isARepeat {
                onToggleSelectionMode()
            }
            return true
        }
        guard let action = selectionActions.first(where: { $0.keyCode == event.keyCode }) else {
            return false
        }
        if !event.isARepeat {
            action.perform()
        }
        return true
    }
}

struct SchemaWorkbenchSortMenuState: Identifiable {
    let id = UUID()
    let anchorFrame: CGRect
    let menuFrame: CGRect
}

struct SchemaWorkbenchSortMenuPopover: View {
    let options: [SchemaWorkbenchSortOption]
    let selectedOptionID: String
    @ObservedObject var highlight: MenuHighlightModel
    let onSelect: (String) -> Void
    let onDismiss: () -> Void

    var body: some View {
        WorkbenchPopoverPanel(
            isRedesign: true,
            maximumHeight: MenuMetrics.maximumHeight,
            highlight: highlight
        ) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(options.enumerated()), id: \.element.id) { position, option in
                    WorkbenchPopoverRow(
                        title: option.title,
                        isSelected: selectedOptionID == option.id,
                        isHighlighted: highlight.highlightedPosition == position,
                        isRedesign: true,
                        showsCheckmarkSlot: true,
                        action: {
                            onDismiss()
                            onSelect(option.id)
                        },
                        onHoverChange: { isHovered in
                            highlight.noteHover(isHovered, at: position)
                        }
                    )
                    .id(position)
                }
            }
            .fixedSize(horizontal: true, vertical: false)
        }
    }
}
