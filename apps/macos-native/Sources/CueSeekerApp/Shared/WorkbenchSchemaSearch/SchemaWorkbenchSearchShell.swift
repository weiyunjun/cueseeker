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

@MainActor
final class SchemaWorkbenchSelectionMenuController: ObservableObject {
    @Published var activeActionID: String?
    private var buttonAnchors: [String: MenuAnchorHandle] = [:]

    func anchor(for actionID: String) -> MenuAnchorHandle {
        if let existing = buttonAnchors[actionID] {
            return existing
        }
        let handle = MenuAnchorHandle()
        buttonAnchors[actionID] = handle
        return handle
    }

    func isMenuOpen(for actionID: String) -> Bool {
        activeActionID == actionID
    }

    func toggleMenu(for actionID: String) {
        if activeActionID == actionID {
            activeActionID = nil
        } else {
            activeActionID = actionID
        }
    }

    func dismiss() {
        if activeActionID != nil {
            activeActionID = nil
        }
    }
}

struct SchemaWorkbenchSearchShell<TableContent: View>: View {
    @Environment(\.isWorkbenchPageCovered) private var isWorkbenchPageCovered
    // Observed so the copy below is re-read when the language changes.
    @EnvironmentObject private var localization: AppLocalizationStore

    @Binding var searchDraft: String

    let columns: [WorkbenchTableColumn]
    let searchPlaceholder: String
    let autofocusSearchOnAppear: Bool
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
    let externalSelectionMenuController: SchemaWorkbenchSelectionMenuController?
    /// Registered with the Selection Action Overlay's own area, so the table
    /// can tell when the pointer is over it.
    let selectionOverlayAnchor: MenuAnchorHandle?
    var onSearchSubmit: (() -> Void)?
    let tableContent: ([WorkbenchTableColumn]) -> TableContent

    @StateObject private var externalTextSelectionSession = SubtitleTableExternalTextSelectionSession()
    @StateObject private var pageScrollbar = WorkbenchPageScrollbar()
    @StateObject private var internalSelectionMenuController = SchemaWorkbenchSelectionMenuController()

    init(
        searchDraft: Binding<String>,
        columns: [WorkbenchTableColumn],
        searchPlaceholder: String = L("table.search_placeholder"),
        autofocusSearchOnAppear: Bool = false,
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
        selectionMenuController: SchemaWorkbenchSelectionMenuController? = nil,
        selectionOverlayAnchor: MenuAnchorHandle? = nil,
        onSearchSubmit: (() -> Void)? = nil,
        @ViewBuilder tableContent: @escaping ([WorkbenchTableColumn]) -> TableContent
    ) {
        _searchDraft = searchDraft
        self.columns = columns
        self.searchPlaceholder = searchPlaceholder
        self.autofocusSearchOnAppear = autofocusSearchOnAppear
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
        self.externalSelectionMenuController = selectionMenuController
        self.selectionOverlayAnchor = selectionOverlayAnchor
        self.onSearchSubmit = onSearchSubmit
        self.tableContent = tableContent
    }

    private var resolvedSelectionMenuController: SchemaWorkbenchSelectionMenuController {
        externalSelectionMenuController ?? internalSelectionMenuController
    }

    var body: some View {
        SchemaWorkbenchSortMenuHost(
            sortOptions: sortOptions,
            selectedSortOptionID: selectedSortOptionID,
            onSelectSortOption: onSelectSortOption,
            selectionActions: selectionActions ?? [],
            selectionMenuController: resolvedSelectionMenuController,
            isFilterDialogOpen: isFilterDialogOpen,
            isSelectionMode: isSelectionMode,
            externalSortButtonAnchor: externalSortButtonAnchor,
            externalIsSortMenuOpen: externalIsSortMenuOpen
        ) { sortMenu in
            GeometryReader { geometry in
                ZStack {
                    pageBody(sortMenu: sortMenu)
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

    @ViewBuilder
    private func pageBody(
        sortMenu: SchemaWorkbenchSortMenuTriggerContext
    ) -> some View {
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

            if summaryContent != nil, hostsPageChromeInTable {
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
                    searchToolbar(sortMenu: sortMenu)
                        .workbenchPageInlinePadding()
                        .padding(
                            .top,
                            WorkbenchControlMetrics.redesignWorkbenchPageTopPadding
                        )
                        .padding(.bottom, SchemaWorkbenchStyle.toolbarBottomGap)

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
        isWorkbenchPageCovered || isSelectionMode
    }

    private var externalTextSelectionStartPolicy: SubtitleTableExternalTextSelectionStartPolicy {
        return SubtitleTableExternalTextSelectionStartPolicy(
            isBlocked: externalTextSelectionIsBlocked
        )
    }

    private var selectedCountText: String? {
        guard let tableSummary else { return nil }
        return schemaWorkbenchSelectedCountText(
            selectedRowCount: tableSummary.selectedRowCount,
            selectableRowCount: tableSummary.selectableRowCount
        )
    }

    private func searchToolbar(
        sortMenu: SchemaWorkbenchSortMenuTriggerContext
    ) -> some View {
        SchemaWorkbenchSearchToolbar(
            placeholder: searchPlaceholder,
            searchDraft: $searchDraft,
            searchResultCountText: searchResultCountText,
            autofocusSearchOnAppear: autofocusSearchOnAppear,
            selectedCountText: selectedCountText,
            selectionActions: selectionActions ?? [],
            selectionMenuController: resolvedSelectionMenuController,
            isSelectionMode: isSelectionMode,
            isFilterDialogOpen: isFilterDialogOpen,
            filterSelectionCount: filterSelectionCount,
            canEnterSelectionMode: canEnterSelectionMode,
            sortTitle: sortMenu.sortTitle,
            isSortMenuOpen: sortMenu.isSortMenuOpen,
            sortButtonAnchor: sortMenu.sortButtonAnchor,
            onSubmit: onSearchSubmit,
            onFilter: {
                sortMenu.dismissSortMenu()
                onOpenFilterDialog()
            },
            onSort: sortMenu.toggleSortMenu,
            onToggleSelectionMode: onToggleSelectionMode
        )
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

    @MainActor
    private static var cachedSelectionButtonWidths: [String: CGFloat] = [:]

    @MainActor
    static func selectionButtonWidth(for action: SchemaWorkbenchSelectionAction) -> CGFloat {
        let key = "\(action.icon.rawValue)|\(action.title)"
        if let cached = cachedSelectionButtonWidths[key] {
            return cached
        }
        let host = NSHostingView(
            rootView: WorkbenchButton(
                title: action.title,
                icon: action.icon,
                action: {}
            )
        )
        let width = ceil(host.fittingSize.width)
        cachedSelectionButtonWidths[key] = width
        return width
    }

    @MainActor
    static func pinnedToolbarHeight(
        forWidth width: CGFloat,
        isSelectionMode: Bool,
        selectionActions: [SchemaWorkbenchSelectionAction]
    ) -> CGFloat {
        guard isSelectionMode, !selectionActions.isEmpty, width > 0 else {
            return pinnedToolbarHeight
        }
        let availableWidth = max(1, width - selectionActionRowLeadingPadding)
        let horizontalSpacing = WorkbenchControlMetrics.redesignSpacing4
        var lineCount = 1
        var currentX: CGFloat = 0
        for action in selectionActions {
            let itemWidth = selectionButtonWidth(for: action)
            if currentX > 0, currentX + itemWidth > availableWidth {
                lineCount += 1
                currentX = itemWidth + horizontalSpacing
            } else {
                currentX += itemWidth + horizontalSpacing
            }
        }
        let actionRowsHeight = CGFloat(lineCount) * WorkbenchControlMetrics.redesignHeight
            + CGFloat(max(0, lineCount - 1)) * toolbarRowSpacing
        return WorkbenchControlMetrics.redesignHeight
            + toolbarRowSpacing
            + actionRowsHeight
            + toolbarBottomGap
    }
}

struct SchemaWorkbenchSearchToolbar: View {
    @Environment(\.interfaceLayerContext) private var layerContext
    @Environment(\.workbenchAccessibility) private var workbenchAccessibility

    let placeholder: String
    @Binding var searchDraft: String
    let searchResultCountText: String?
    var autofocusSearchOnAppear: Bool = false
    var selectedCountText: String? = nil
    var selectionActions: [SchemaWorkbenchSelectionAction] = []
    var selectionMenuController: SchemaWorkbenchSelectionMenuController? = nil
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

    @State private var hasConsumedInitialAutofocus = false
    @StateObject private var defaultSelectionMenuController = SchemaWorkbenchSelectionMenuController()

    private var resolvedSelectionMenuController: SchemaWorkbenchSelectionMenuController {
        selectionMenuController ?? defaultSelectionMenuController
    }

    var body: some View {
        WorkbenchAccessibilityReader { accessibility in
            let _ = syncAccessibilityCallbacks(accessibility)
            VStack(spacing: SchemaWorkbenchStyle.toolbarRowSpacing) {
                if isSelectionMode {
                    selectionSummaryRow(accessibility: accessibility)
                    SchemaWorkbenchSelectionActionsRow(
                        selectionActions: selectionActions,
                        selectionMenuController: resolvedSelectionMenuController,
                        focusedTarget: accessibility?.focusedTarget,
                        onTriggerAction: triggerSelectionAction
                    )
                } else {
                    topInputAndActionsRow(accessibility: accessibility)
                    defaultResultCountRow
                }
            }
            .onAppear {
                syncAccessibilityCallbacks(accessibility)
            }
            .onChange(of: isSelectionMode) { inSelectionMode in
                if inSelectionMode {
                    hasConsumedInitialAutofocus = true
                } else {
                    resolvedSelectionMenuController.dismiss()
                }
                accessibility?.isTableInSelectionMode = inSelectionMode
            }
            .onDisappear {
                resolvedSelectionMenuController.dismiss()
                accessibility?.isTableInSelectionMode = false
                accessibility?.onOpenToolbarFilterDialog = nil
                accessibility?.onToggleToolbarSortMenu = nil
                accessibility?.onExitTableSelectionMode = nil
                accessibility?.onPerformSelectionAction = nil
            }
        }
        .background {
            if isSelectionMode {
                WindowKeyDownMonitor(handle: handleSelectionShortcut)
            }
        }
    }

    private func syncAccessibilityCallbacks(_ accessibility: WorkbenchAccessibilityCoordinator?) {
        accessibility?.isTableInSelectionMode = isSelectionMode
        accessibility?.onOpenToolbarFilterDialog = onFilter
        accessibility?.onToggleToolbarSortMenu = onSort
        accessibility?.onExitTableSelectionMode = onToggleSelectionMode
        accessibility?.onPerformSelectionAction = { actionID in
            if let matched = selectionActions.first(where: { $0.id == actionID.rawValue }) {
                triggerSelectionAction(matched)
            }
        }
    }

    private func triggerSelectionAction(_ action: SchemaWorkbenchSelectionAction) {
        if action.destinationMenu != nil {
            resolvedSelectionMenuController.toggleMenu(for: action.id)
        } else {
            resolvedSelectionMenuController.dismiss()
            action.perform()
        }
    }

    private func searchField(accessibility: WorkbenchAccessibilityCoordinator?) -> some View {
        WorkbenchSearchField(
            placeholder: placeholder,
            text: $searchDraft,
            autofocus: autofocusSearchOnAppear && !hasConsumedInitialAutofocus && !isSelectionMode,
            trailingStatusText: nil,
            isSearchAccessibilityFocused: accessibility?.isFocused(.toolbarSearchField) == true,
            isClearAccessibilityFocused: accessibility?.isFocused(.toolbarSearchClearButton) == true,
            onSubmit: onSubmit,
            onBindAccessibilityTextField: { field in
                accessibility?.activeSearchTextField = field
            }
        )
    }

    private func topInputAndActionsRow(accessibility: WorkbenchAccessibilityCoordinator?) -> some View {
        HStack(spacing: WorkbenchControlMetrics.redesignSpacing4) {
            searchField(accessibility: accessibility)
                .frame(minWidth: 0, maxWidth: .infinity)

            SchemaWorkbenchFilterAndSortControls(
                filterSelectionCount: filterSelectionCount,
                isFilterDialogOpen: isFilterDialogOpen,
                sortTitle: sortTitle,
                isSortMenuOpen: isSortMenuOpen,
                isFilterFocused: accessibility?.isFocused(.toolbarFilterButton) == true,
                isSortFocused: accessibility?.isFocused(.toolbarSortButton) == true,
                sortButtonAnchor: sortButtonAnchor,
                onFilter: onFilter,
                onSort: onSort
            )
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

    private func selectionSummaryRow(accessibility: WorkbenchAccessibilityCoordinator?) -> some View {
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
                isFocused: accessibility?.isFocused(.toolbarExitSelectButton) == true,
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
            guard workbenchAccessibility?.isActive != true else {
                return false
            }
            if !event.isARepeat {
                onToggleSelectionMode()
            }
            return true
        }
        guard let action = selectionActions.first(where: { $0.keyCode == event.keyCode }) else {
            return false
        }
        if !event.isARepeat {
            triggerSelectionAction(action)
        }
        return true
    }
}

private struct SchemaWorkbenchSelectionActionsRow: View {
    let selectionActions: [SchemaWorkbenchSelectionAction]
    @ObservedObject var selectionMenuController: SchemaWorkbenchSelectionMenuController
    let focusedTarget: WorkbenchAccessibilityTarget?
    let onTriggerAction: (SchemaWorkbenchSelectionAction) -> Void

    var body: some View {
        WrappingFlowLayout(
            alignment: .leading,
            horizontalSpacing: WorkbenchControlMetrics.redesignSpacing4,
            verticalSpacing: SchemaWorkbenchStyle.toolbarRowSpacing
        ) {
            ForEach(selectionActions) { action in
                let actionID = SchemaWorkbenchSelectionActionID(rawValue: action.id)
                let isFocused = actionID.map { focusedTarget == .toolbarSelectionAction($0) } ?? false
                let hasMenu = action.destinationMenu != nil
                let isOpen = hasMenu && selectionMenuController.isMenuOpen(for: action.id)
                SchemaWorkbenchSelectionActionButton(
                    action: action,
                    isOpen: isOpen,
                    isFocused: isFocused,
                    anchor: hasMenu ? selectionMenuController.anchor(for: action.id) : nil,
                    onTrigger: {
                        onTriggerAction(action)
                    }
                )
            }
        }
        .padding(.leading, SchemaWorkbenchStyle.selectionActionRowLeadingPadding)
        .frame(maxWidth: .infinity, minHeight: WorkbenchControlMetrics.redesignHeight, alignment: .leading)
    }
}

struct SchemaWorkbenchFilterAndSortControls: View {
    // Observed so the copy below is re-read when the language changes.
    @EnvironmentObject private var localization: AppLocalizationStore

    let filterSelectionCount: Int
    let isFilterDialogOpen: Bool
    let sortTitle: String
    let isSortMenuOpen: Bool
    var isFilterFocused: Bool = false
    var isSortFocused: Bool = false
    var sortButtonAnchor: MenuAnchorHandle? = nil
    let onFilter: () -> Void
    let onSort: () -> Void

    var body: some View {
        HStack(spacing: WorkbenchControlMetrics.redesignSpacing4) {
            WorkbenchButton(
                title: L("table.filter"),
                icon: .funnel,
                count: filterSelectionCount,
                isOpen: isFilterDialogOpen,
                isFocused: isFilterFocused,
                action: onFilter
            )
            .layoutPriority(1)
            .accessibilityLabel(L("table.filter"))

            WorkbenchButton(
                title: sortTitle,
                icon: .funnelSimple,
                isOpen: isSortMenuOpen,
                isFocused: isSortFocused,
                action: onSort
            )
            .background {
                if let sortButtonAnchor {
                    MenuAnchorProbe(handle: sortButtonAnchor)
                }
            }
            .layoutPriority(1)
            .accessibilityLabel(sortTitle)
        }
    }
}

extension Array where Element == SchemaWorkbenchSortOption {
    func resolvedSortTitle(for selectedOptionID: String) -> String {
        first(where: { $0.id == selectedOptionID })?.title
            ?? first?.title
            ?? L("search.sort.default")
    }
}

struct SchemaWorkbenchSortMenuTriggerContext {
    let sortTitle: String
    let isSortMenuOpen: Bool
    let sortButtonAnchor: MenuAnchorHandle
    let toggleSortMenu: () -> Void
    let dismissSortMenu: () -> Void
}

struct SchemaWorkbenchSortMenuHost<Content: View>: View {
    @Environment(\.interfaceLayers) private var interfaceLayers
    @Environment(\.interfaceLayerContext) private var layerContext
    @Environment(\.isWorkbenchPageCovered) private var isWorkbenchPageCovered
    // Observed so the copy below is re-read when the language changes.
    @EnvironmentObject private var localization: AppLocalizationStore

    let sortOptions: [SchemaWorkbenchSortOption]
    let selectedSortOptionID: String
    let onSelectSortOption: (String) -> Void
    var selectionActions: [SchemaWorkbenchSelectionAction] = []
    @ObservedObject var selectionMenuController: SchemaWorkbenchSelectionMenuController
    var isFilterDialogOpen: Bool = false
    var isSelectionMode: Bool = false
    var externalSortButtonAnchor: MenuAnchorHandle? = nil
    var externalIsSortMenuOpen: Binding<Bool>? = nil
    @ViewBuilder let content: (SchemaWorkbenchSortMenuTriggerContext) -> Content

    @State private var internalSortButtonAnchor = MenuAnchorHandle()
    @State private var sortMenuHostAnchor = MenuAnchorHandle()
    @State private var activeSortMenu: SchemaWorkbenchSortMenuState?
    @State private var activeSelectionMenu: SchemaWorkbenchSelectionDestinationMenuState?
    @StateObject private var sortMenuHighlight = MenuHighlightModel()
    @StateObject private var selectionMenuHighlight = MenuHighlightModel()

    @MainActor
    init(
        sortOptions: [SchemaWorkbenchSortOption],
        selectedSortOptionID: String,
        onSelectSortOption: @escaping (String) -> Void,
        selectionActions: [SchemaWorkbenchSelectionAction] = [],
        selectionMenuController: SchemaWorkbenchSelectionMenuController? = nil,
        isFilterDialogOpen: Bool = false,
        isSelectionMode: Bool = false,
        externalSortButtonAnchor: MenuAnchorHandle? = nil,
        externalIsSortMenuOpen: Binding<Bool>? = nil,
        @ViewBuilder content: @escaping (SchemaWorkbenchSortMenuTriggerContext) -> Content
    ) {
        self.sortOptions = sortOptions
        self.selectedSortOptionID = selectedSortOptionID
        self.onSelectSortOption = onSelectSortOption
        self.selectionActions = selectionActions
        self.selectionMenuController = selectionMenuController ?? SchemaWorkbenchSelectionMenuController()
        self.isFilterDialogOpen = isFilterDialogOpen
        self.isSelectionMode = isSelectionMode
        self.externalSortButtonAnchor = externalSortButtonAnchor
        self.externalIsSortMenuOpen = externalIsSortMenuOpen
        self.content = content
    }

    var body: some View {
        content(
            SchemaWorkbenchSortMenuTriggerContext(
                sortTitle: currentSortTitle,
                isSortMenuOpen: activeSortMenu != nil,
                sortButtonAnchor: resolvedSortButtonAnchor,
                toggleSortMenu: toggleSortMenu,
                dismissSortMenu: dismissSortMenu
            )
        )
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
                            sortMenuHighlight.handleStandardMenuKey(
                                keyCode: keyCode,
                                onActivate: { activateHighlightedSortItem() },
                                onDismiss: { dismissSortMenu() }
                            )
                        },
                        dismiss: { _ in
                            dismissSortMenu()
                        }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .allowsHitTesting(false)

                    SchemaWorkbenchSortMenuSurfaceHost(
                        menu: SchemaWorkbenchSortMenuPopover(
                            options: sortOptions,
                            selectedOptionID: selectedSortOptionID,
                            highlight: sortMenuHighlight,
                            onSelect: { optionID in
                                selectSortOption(optionID)
                            },
                            onDismiss: {
                                dismissSortMenu()
                            }
                        )
                    )
                    .frame(width: menuFrame.width, height: menuFrame.height)
                    .offset(x: menuFrame.minX, y: menuFrame.minY)
                }
                .zIndex(1001)
            }

            if let activeSelectionMenu,
               let action = selectionActions.first(where: { $0.id == activeSelectionMenu.actionID }),
               let destinationMenu = action.destinationMenu {
                let menuFrame = activeSelectionMenu.menuFrame
                ZStack(alignment: .topLeading) {
                    MenuGateClientView(
                        gate: interfaceLayers?.menuGate,
                        owner: layerContext.layer,
                        kind: .excerptDestinationMenu,
                        menuFrame: menuFrame,
                        anchorFrame: activeSelectionMenu.anchorFrame,
                        handleKey: { keyCode, isRepeat in
                            handleSelectionDestinationMenuKey(
                                keyCode,
                                isRepeat: isRepeat,
                                action: action,
                                destinationMenu: destinationMenu
                            )
                        },
                        dismiss: { _ in
                            dismissSelectionDestinationMenu()
                        }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .allowsHitTesting(false)

                    SchemaWorkbenchSelectionDestinationMenuSurfaceHost(
                        menu: ExcerptDestinationMenu(
                            destinations: destinationMenu.destinations,
                            highlight: selectionMenuHighlight,
                            maximumHeight: activeSelectionMenu.maximumHeight,
                            onSelect: { destination in
                                dismissSelectionDestinationMenu()
                                destinationMenu.onSelect(destination)
                            },
                            onCreateList: {
                                dismissSelectionDestinationMenu()
                                destinationMenu.onCreateList()
                            }
                        )
                    )
                    .frame(width: menuFrame.width, height: menuFrame.height)
                    .offset(x: menuFrame.minX, y: menuFrame.minY)
                }
                .zIndex(1001)
            }
        }
        .onChange(of: externalIsSortMenuOpen?.wrappedValue ?? false) { isOpen in
            if isOpen {
                if activeSortMenu == nil {
                    openSortMenu()
                }
            } else if activeSortMenu != nil {
                dismissSortMenu()
            }
        }
        .onChange(of: selectionMenuController.activeActionID) { actionID in
            if let actionID {
                openSelectionDestinationMenu(for: actionID)
            } else if activeSelectionMenu != nil {
                dismissSelectionDestinationMenu()
            }
        }
        .onChange(of: isSelectionMode) { inSelectionMode in
            if inSelectionMode {
                dismissSortMenu()
            } else {
                dismissSelectionDestinationMenu()
            }
        }
        .onChange(of: isFilterDialogOpen) { isOpen in
            if isOpen {
                dismissSortMenu()
                dismissSelectionDestinationMenu()
            }
        }
        .onChange(of: isHostCovered) { isCovered in
            if isCovered {
                dismissSortMenu()
                dismissSelectionDestinationMenu()
            }
        }
        .onDisappear {
            dismissSortMenu()
            dismissSelectionDestinationMenu()
        }
    }

    private var isHostCovered: Bool {
        layerContext.isCovered
            || (layerContext.layer == .workbenchPage && isWorkbenchPageCovered)
    }

    private var resolvedSortButtonAnchor: MenuAnchorHandle {
        externalSortButtonAnchor ?? internalSortButtonAnchor
    }

    private var currentSortTitle: String {
        sortOptions.resolvedSortTitle(for: selectedSortOptionID)
    }

    private func toggleSortMenu() {
        if activeSortMenu != nil {
            dismissSortMenu()
        } else {
            openSortMenu()
        }
    }

    private func openSortMenu() {
        guard !isSelectionMode,
              !sortOptions.isEmpty,
              let viewportSize = sortMenuHostAnchor.bounds?.size,
              let anchorFrame = resolvedSortButtonAnchor.frame(in: sortMenuHostAnchor)
        else {
            externalIsSortMenuOpen?.wrappedValue = false
            return
        }
        let naturalSize = measuredSortMenuSize()
        let container = CGRect(origin: .zero, size: viewportSize)
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

    private func openSelectionDestinationMenu(for actionID: String) {
        guard isSelectionMode,
              let action = selectionActions.first(where: { $0.id == actionID }),
              let destinationMenu = action.destinationMenu
        else {
            dismissSelectionDestinationMenu()
            return
        }
        dismissSortMenu()
        let viewportSize = sortMenuHostAnchor.bounds?.size ?? CGSize(width: 900, height: 600)
        let buttonAnchor = selectionMenuController.anchor(for: actionID)
        let anchorFrame = buttonAnchor.frame(in: sortMenuHostAnchor)
            ?? buttonAnchor.bounds
            ?? CGRect(x: 0, y: 0, width: 120, height: WorkbenchControlMetrics.redesignHeight)
        let naturalSize = measuredSelectionDestinationMenuSize(
            destinations: destinationMenu.destinations,
            maximumHeight: MenuMetrics.maximumHeight
        )
        let scrollingWidth = measuredSelectionDestinationMenuSize(
            destinations: destinationMenu.destinations,
            maximumHeight: 0
        ).width
        let container = CGRect(origin: .zero, size: viewportSize)
        let initialFrame = MenuPlacement.openingFrame(
            anchor: anchorFrame,
            menuSize: naturalSize,
            in: container,
            gap: WorkbenchControlMetrics.redesignSpacing1,
            shrinksToFit: true
        )
        let openingFrame: CGRect
        let maximumHeight: CGFloat
        if initialFrame.height < naturalSize.height {
            openingFrame = MenuPlacement.openingFrame(
                anchor: anchorFrame,
                menuSize: CGSize(width: scrollingWidth, height: initialFrame.height),
                in: container,
                gap: WorkbenchControlMetrics.redesignSpacing1,
                shrinksToFit: true
            )
            maximumHeight = initialFrame.height
        } else {
            openingFrame = initialFrame
            maximumHeight = MenuMetrics.maximumHeight
        }
        activeSelectionMenu = SchemaWorkbenchSelectionDestinationMenuState(
            actionID: actionID,
            anchorFrame: anchorFrame,
            menuFrame: openingFrame,
            maximumHeight: maximumHeight
        )
        selectionMenuHighlight.open(
            selectablePositions: ExcerptDestinationMenu.selectablePositions(
                destinationCount: destinationMenu.destinations.count
            ),
            defaultPosition: ExcerptDestinationMenu.defaultPosition(
                destinations: destinationMenu.destinations
            )
        )
    }

    private func dismissSelectionDestinationMenu() {
        activeSelectionMenu = nil
        selectionMenuController.dismiss()
        selectionMenuHighlight.close()
    }

    private func handleSelectionDestinationMenuKey(
        _ keyCode: UInt16,
        isRepeat: Bool,
        action: SchemaWorkbenchSelectionAction,
        destinationMenu: SchemaWorkbenchSelectionDestinationMenu
    ) -> Bool {
        if keyCode == action.keyCode {
            if !isRepeat {
                dismissSelectionDestinationMenu()
            }
            return true
        }
        return selectionMenuHighlight.handleStandardMenuKey(
            keyCode: keyCode,
            onActivate: {
                guard !isRepeat,
                      let position = selectionMenuHighlight.activeTriggerPosition
                else {
                    return
                }
                activateSelectionDestination(at: position, destinationMenu: destinationMenu)
            },
            onDismiss: {
                if !isRepeat {
                    dismissSelectionDestinationMenu()
                }
            }
        )
    }

    private func activateSelectionDestination(
        at position: Int,
        destinationMenu: SchemaWorkbenchSelectionDestinationMenu
    ) {
        if destinationMenu.destinations.indices.contains(position) {
            let destination = destinationMenu.destinations[position]
            dismissSelectionDestinationMenu()
            destinationMenu.onSelect(destination)
        } else if position == destinationMenu.destinations.count {
            dismissSelectionDestinationMenu()
            destinationMenu.onCreateList()
        }
    }

    private func activateHighlightedSortItem() {
        guard let position = sortMenuHighlight.activeTriggerPosition,
              sortOptions.indices.contains(position)
        else {
            return
        }
        let option = sortOptions[position]
        selectSortOption(option.id)
        dismissSortMenu()
    }

    private func selectSortOption(_ optionID: String) {
        guard optionID != selectedSortOptionID else {
            return
        }
        onSelectSortOption(optionID)
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

    private func measuredSelectionDestinationMenuSize(
        destinations: [SubtitleTableRowActionDestination],
        maximumHeight: CGFloat
    ) -> CGSize {
        let host = NSHostingView(
            rootView: ExcerptDestinationMenu(
                destinations: destinations,
                highlight: selectionMenuHighlight,
                maximumHeight: maximumHeight,
                onSelect: { _ in },
                onCreateList: {}
            )
        )
        host.layoutSubtreeIfNeeded()
        return host.fittingSize
    }
}

private struct SchemaWorkbenchSortMenuSurfaceHost: NSViewRepresentable {
    let menu: SchemaWorkbenchSortMenuPopover

    func makeNSView(context _: Context) -> MenuHostingView {
        MenuHostingView(rootView: AnyView(menu))
    }

    func updateNSView(_ nsView: MenuHostingView, context _: Context) {
        nsView.rootView = AnyView(menu)
    }
}

private struct SchemaWorkbenchSelectionDestinationMenuSurfaceHost: NSViewRepresentable {
    let menu: ExcerptDestinationMenu

    func makeNSView(context _: Context) -> MenuHostingView {
        MenuHostingView(rootView: AnyView(menu))
    }

    func updateNSView(_ nsView: MenuHostingView, context _: Context) {
        nsView.rootView = AnyView(menu)
    }
}

struct SchemaWorkbenchSortMenuState: Identifiable {
    let id = UUID()
    let anchorFrame: CGRect
    let menuFrame: CGRect
}

struct SchemaWorkbenchSelectionDestinationMenuState: Identifiable {
    let id = UUID()
    let actionID: String
    let anchorFrame: CGRect
    let menuFrame: CGRect
    let maximumHeight: CGFloat
}

struct SchemaWorkbenchSortMenuPopover: View {
    let options: [SchemaWorkbenchSortOption]
    let selectedOptionID: String
    @ObservedObject var highlight: MenuHighlightModel
    let onSelect: (String) -> Void
    let onDismiss: () -> Void

    var body: some View {
        WorkbenchPopoverPanel(
            maximumHeight: MenuMetrics.maximumHeight,
            highlight: highlight
        ) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(options.enumerated()), id: \.element.id) { position, option in
                    WorkbenchPopoverRow(
                        title: option.title,
                        isSelected: selectedOptionID == option.id,
                        isHighlighted: highlight.isSelected(position),
                        isRowHovered: highlight.isHovered(position),
                        isAccessibilityFocused: highlight.isAccessibilityFocused(position),
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
