import SwiftUI
import CueSeekerCore

enum SchemaWorkbenchPopover: Equatable {
    case columnVisibility
    case filterSets
    case filterBuilder
}

struct SchemaWorkbenchTableSummary: Equatable {
    let totalRowCount: Int
    let selectedRowCount: Int
}

struct SchemaWorkbenchCountSummarySegment: Equatable {
    enum Tone: Equatable {
        case primary
        case secondary
    }

    let text: String
    let tone: Tone
}

enum SchemaWorkbenchCountSummaryText {
    static let overflowLimit = 99_999

    static func formattedCount(_ count: Int) -> String {
        let safeCount = max(0, count)
        return safeCount > overflowLimit ? "\(overflowLimit)+" : "\(safeCount)"
    }

    static func segments(for summary: SchemaWorkbenchTableSummary) -> [SchemaWorkbenchCountSummarySegment] {
        let totalText = formattedCount(summary.totalRowCount)
        let selectedText = formattedCount(summary.selectedRowCount)
        guard summary.selectedRowCount > 0 else {
            return [
                SchemaWorkbenchCountSummarySegment(text: totalText, tone: .primary),
                SchemaWorkbenchCountSummarySegment(text: " rows", tone: .secondary),
            ]
        }

        return [
            SchemaWorkbenchCountSummarySegment(text: selectedText, tone: .primary),
            SchemaWorkbenchCountSummarySegment(text: " / ", tone: .secondary),
            SchemaWorkbenchCountSummarySegment(text: totalText, tone: .primary),
            SchemaWorkbenchCountSummarySegment(text: " rows selected", tone: .secondary),
        ]
    }
}

struct SchemaWorkbenchFilterSet: Identifiable, Equatable, Codable {
    let id: String
    let name: String
    let rules: [SchemaWorkbenchFilterRule]
}

struct SchemaWorkbenchFilterRule: Identifiable, Equatable, Codable {
    let id: String
    var join: SchemaWorkbenchFilterJoin?
    var fieldID: String
    var operatorID: SchemaWorkbenchFilterOperatorID
    var value: String
}

extension Array where Element == SchemaWorkbenchFilterRule {
    var subtitleSearchFilterSet: SubtitleSearchFilterSet {
        SubtitleSearchFilterSet(
            rules: compactMap { rule in
                guard let field = SubtitleSearchFilterField(workbenchFieldID: rule.fieldID) else {
                    return nil
                }

                return SubtitleSearchFilterRule(
                    join: rule.join?.coreJoin,
                    field: field,
                    operatorID: rule.operatorID.coreOperator,
                    value: rule.value
                )
            }
        )
    }
}

private extension SubtitleSearchFilterField {
    init?(workbenchFieldID: String) {
        switch workbenchFieldID {
        case "display":
            self = .display
        case "cues":
            self = .cues
        case "language":
            self = .language
        case "speaker":
            self = .speaker
        default:
            return nil
        }
    }
}

enum SchemaWorkbenchFilterJoin: String, CaseIterable, Identifiable, Codable {
    case and
    case or

    var id: String {
        rawValue
    }

    var title: String {
        rawValue
    }

    var coreJoin: SubtitleSearchFilterJoin {
        switch self {
        case .and:
            return .and
        case .or:
            return .or
        }
    }
}

enum SchemaWorkbenchFilterOperatorID: String, Identifiable, Codable {
    case contains
    case doesNotContain
    case `is`
    case isNot
    case isEmpty
    case isNotEmpty
    case equals
    case doesNotEqual
    case greaterThan
    case greaterThanOrEqualTo
    case lessThan
    case lessThanOrEqualTo

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .contains:
            return "contains"
        case .doesNotContain:
            return "does not contain"
        case .is:
            return "is"
        case .isNot:
            return "is not"
        case .isEmpty:
            return "is empty"
        case .isNotEmpty:
            return "is not empty"
        case .equals:
            return "equals"
        case .doesNotEqual:
            return "does not equal"
        case .greaterThan:
            return "greater than"
        case .greaterThanOrEqualTo:
            return "greater than or equal to"
        case .lessThan:
            return "less than"
        case .lessThanOrEqualTo:
            return "less than or equal to"
        }
    }

    var coreOperator: SubtitleSearchFilterOperator {
        switch self {
        case .contains:
            return .contains
        case .doesNotContain:
            return .doesNotContain
        case .is:
            return .is
        case .isNot:
            return .isNot
        case .isEmpty:
            return .isEmpty
        case .isNotEmpty:
            return .isNotEmpty
        case .equals:
            return .equals
        case .doesNotEqual:
            return .doesNotEqual
        case .greaterThan:
            return .greaterThan
        case .greaterThanOrEqualTo:
            return .greaterThanOrEqualTo
        case .lessThan:
            return .lessThan
        case .lessThanOrEqualTo:
            return .lessThanOrEqualTo
        }
    }

    init?(_ coreOperator: SubtitleSearchFilterOperator) {
        self.init(rawValue: coreOperator.rawValue)
    }
}

enum SchemaWorkbenchSearchDefaults {
    static let columns: [WorkbenchTableColumn] = [
        WorkbenchTableColumn(
            id: "rowNumber",
            title: "#",
            kind: .rowNumber,
            width: .fixed(84)
        ),
        WorkbenchTableColumn(
            id: "display",
            title: "Display Title",
            kind: .text,
            width: .fixed(300)
        ),
        WorkbenchTableColumn(
            id: "cues",
            title: "Cues",
            kind: .text,
            width: .flexible(min: 580)
        ),
        WorkbenchTableColumn(
            id: "time",
            title: "Time",
            kind: .text,
            width: .fixed(190)
        ),
    ]

    static let shioriColumns: [WorkbenchTableColumn] = [
        WorkbenchTableColumn(
            id: "rowNumber",
            title: "#",
            kind: .rowNumber,
            width: .fixed(84)
        ),
        WorkbenchTableColumn(
            id: "display",
            title: "Display Title",
            kind: .text,
            width: .fixed(300)
        ),
        WorkbenchTableColumn(
            id: "cues",
            title: "Cues",
            kind: .text,
            width: .flexible(min: 580)
        ),
        WorkbenchTableColumn(
            id: "time",
            title: "Time",
            kind: .text,
            width: .fixed(190)
        ),
        WorkbenchTableColumn(
            id: "dateAdded",
            title: "Date Added",
            kind: .text,
            width: .fixed(190)
        ),
    ]

    static let initialVisibleColumnIDs = Set(columns.map(\.id))
    static let initialVisibleShioriColumnIDs = Set(shioriColumns.map(\.id))

    static let defaultFilterSetID: String? = nil

    static var defaultFilterRules: [SchemaWorkbenchFilterRule] {
        []
    }

    static let filterSets: [SchemaWorkbenchFilterSet] = []

    static func makeFilterRule(
        id: String = UUID().uuidString,
        join: SchemaWorkbenchFilterJoin?,
        fieldID: String,
        operatorID: SchemaWorkbenchFilterOperatorID,
        value: String
    ) -> SchemaWorkbenchFilterRule {
        SchemaWorkbenchFilterRule(
            id: id,
            join: join,
            fieldID: fieldID,
            operatorID: operatorID,
            value: value
        )
    }
}

struct SchemaWorkbenchSearchShell<TableContent: View>: View {
    @Binding var searchDraft: String
    @Binding var visibleColumnIDs: Set<String>
    @Binding var activeFilterSetID: String?
    @Binding var filterRules: [SchemaWorkbenchFilterRule]
    @Binding var filterSets: [SchemaWorkbenchFilterSet]

    let columns: [WorkbenchTableColumn]
    let searchPlaceholder: String
    let isRedesign: Bool
    let tableSummary: SchemaWorkbenchTableSummary?
    let tableSummaryLeadingInset: CGFloat
    let tableSummaryAction: AnyView?
    let filterableColumnIDs: Set<String>?
    var onSearchSubmit: (() -> Void)?
    let tableContent: ([WorkbenchTableColumn]) -> TableContent

    @State private var openPopover: SchemaWorkbenchPopover?
    @State private var shellDropdownFrames: [String: CGRect] = [:]
    @State private var openPopoverWidth: CGFloat = 0

    init(
        searchDraft: Binding<String>,
        visibleColumnIDs: Binding<Set<String>>,
        activeFilterSetID: Binding<String?>,
        filterRules: Binding<[SchemaWorkbenchFilterRule]>,
        filterSets: Binding<[SchemaWorkbenchFilterSet]>,
        columns: [WorkbenchTableColumn],
        searchPlaceholder: String = "Search cues by name, lyrics, or keywords...",
        isRedesign: Bool = false,
        tableSummary: SchemaWorkbenchTableSummary? = nil,
        tableSummaryLeadingInset: CGFloat = 0,
        tableSummaryAction: AnyView? = nil,
        filterableColumnIDs: Set<String>? = nil,
        onSearchSubmit: (() -> Void)? = nil,
        @ViewBuilder tableContent: @escaping ([WorkbenchTableColumn]) -> TableContent
    ) {
        _searchDraft = searchDraft
        _visibleColumnIDs = visibleColumnIDs
        _activeFilterSetID = activeFilterSetID
        _filterRules = filterRules
        _filterSets = filterSets
        self.columns = columns
        self.searchPlaceholder = searchPlaceholder
        self.isRedesign = isRedesign
        self.tableSummary = tableSummary
        self.tableSummaryLeadingInset = tableSummaryLeadingInset
        self.tableSummaryAction = tableSummaryAction
        self.filterableColumnIDs = filterableColumnIDs
        self.onSearchSubmit = onSearchSubmit
        self.tableContent = tableContent
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                if isRedesign {
                    SchemaWorkbenchSearchFilterBar(
                        placeholder: searchPlaceholder,
                        searchDraft: $searchDraft,
                        activeFilterSetName: activeFilterSetName,
                        filterCount: filterRules.count,
                        isRedesign: true,
                        isFilterSetsMenuOpen: openPopover == .filterSets,
                        isFilterBuilderMenuOpen: openPopover == .filterBuilder,
                        onSubmit: onSearchSubmit,
                        onFilterSets: {
                            togglePopover(.filterSets)
                        },
                        onFilterBuilder: {
                            openFilterBuilder()
                        },
                        onReset: {
                            resetFilters()
                        }
                    )
                    .padding(.horizontal, SchemaWorkbenchStyle.pageHorizontalPadding)
                    .padding(.top, SchemaWorkbenchStyle.pageTopPadding)
                    .padding(.bottom, WorkbenchControlMetrics.redesignSpacing3)

                    SchemaWorkbenchTableUtilityBar(
                        tableSummary: tableSummary,
                        summaryLeadingInset: tableSummaryLeadingInset,
                        summaryAction: tableSummaryAction,
                        isRedesign: true,
                        isViewMenuOpen: openPopover == .columnVisibility,
                        onViewMenu: {
                            togglePopover(.columnVisibility)
                        }
                    )
                    .padding(.horizontal, SchemaWorkbenchStyle.pageHorizontalPadding)
                    .padding(.bottom, 12)
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
                        activeFilterSetName: activeFilterSetName,
                        filterCount: filterRules.count,
                        isFilterSetsMenuOpen: openPopover == .filterSets,
                        isFilterBuilderMenuOpen: openPopover == .filterBuilder,
                        onFilterSets: {
                            togglePopover(.filterSets)
                        },
                        onFilterBuilder: {
                            openFilterBuilder()
                        },
                        onReset: {
                            resetFilters()
                        }
                    )
                    .padding(.horizontal, SchemaWorkbenchStyle.pageHorizontalPadding)
                    .padding(.bottom, 12)
                }

                tableContent(visibleColumns)
                    .padding(.horizontal, SchemaWorkbenchStyle.pageHorizontalPadding)
                    .padding(.bottom, SchemaWorkbenchStyle.pageBottomPadding)
                    .frame(maxHeight: .infinity)
            }

            overlayLayer
        }
        .environment(\.isWorkbenchPopupLayerOpen, openPopover != nil)
        .coordinateSpace(name: "SearchShellSpace")
        .onPreferenceChange(WorkbenchDropdownAnchorPreferenceKey.self) { frames in
            self.shellDropdownFrames = frames
        }
        .onChange(of: openPopover) { _ in
            self.openPopoverWidth = 0
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var overlayLayer: some View {
        if let openPopover {
            GeometryReader { geometry in
                ZStack(alignment: .topLeading) {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            self.openPopover = nil
                        }

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
        case .filterSets:
            SchemaWorkbenchFilterSetPopover(
                options: filterSets,
                activeFilterSetID: activeFilterSetID,
                isRedesign: isRedesign,
                onSelect: selectFilterSet
            )
            .frame(
                minWidth: isRedesign ? max(260, shellDropdownFrames["filterSets"]?.width ?? 260) : 260,
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
                    let triggerMinX = shellDropdownFrames["filterSets"]?.minX ?? SchemaWorkbenchStyle.pageHorizontalPadding
                    let popoverWidth = self.openPopoverWidth > 0 ? self.openPopoverWidth : max(260, shellDropdownFrames["filterSets"]?.width ?? 260)
                    let rightLimit = geometry.size.width - SchemaWorkbenchStyle.pageHorizontalPadding
                    return max(SchemaWorkbenchStyle.pageHorizontalPadding, min(triggerMinX, rightLimit - popoverWidth))
                }() : SchemaWorkbenchStyle.pageHorizontalPadding,
                y: isRedesign ? ((shellDropdownFrames["filterSets"]?.maxY ?? 0) + 4) : SchemaWorkbenchStyle.filterPopoverTop(isRedesign: isRedesign)
            )
        case .filterBuilder:
            SchemaWorkbenchFilterBuilderPopover(
                columns: filterableColumns,
                rules: $filterRules,
                isRedesign: isRedesign,
                onSave: {
                    saveFilterSet()
                }
            )
            .frame(width: min(760, max(360, geometry.size.width - 2 * SchemaWorkbenchStyle.pageHorizontalPadding)))
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
                    let triggerMinX = shellDropdownFrames["filterBuilder"]?.minX ?? SchemaWorkbenchStyle.pageHorizontalPadding
                    let popoverWidth = self.openPopoverWidth > 0 ? self.openPopoverWidth : min(760, max(360, geometry.size.width - 2 * SchemaWorkbenchStyle.pageHorizontalPadding))
                    let rightLimit = geometry.size.width - SchemaWorkbenchStyle.pageHorizontalPadding
                    return max(SchemaWorkbenchStyle.pageHorizontalPadding, min(triggerMinX, rightLimit - popoverWidth))
                }() : SchemaWorkbenchStyle.pageHorizontalPadding,
                y: isRedesign ? ((shellDropdownFrames["filterBuilder"]?.maxY ?? 0) + 4) : SchemaWorkbenchStyle.filterPopoverTop(isRedesign: isRedesign)
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

    private var activeFilterSetName: String? {
        guard let activeFilterSetID else {
            return nil
        }

        return filterSets.first { $0.id == activeFilterSetID }?.name
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

    private func selectFilterSet(_ filterSet: SchemaWorkbenchFilterSet) {
        activeFilterSetID = filterSet.id
        filterRules = normalizedFilterRules(filterSet.rules)
        openPopover = nil
    }

    private func openFilterBuilder() {
        if filterRules.isEmpty, let firstColumn = filterableColumns.first {
            activeFilterSetID = nil
            filterRules = [
                SchemaWorkbenchSearchDefaults.makeFilterRule(
                    join: nil,
                    fieldID: firstColumn.id,
                    operatorID: SchemaWorkbenchFilterRuleRow.operators(for: firstColumn).first ?? .contains,
                    value: ""
                ),
            ]
        }

        openPopover = .filterBuilder
    }

    private func resetFilters() {
        activeFilterSetID = nil
        filterRules = []
        openPopover = nil
    }

    private func saveFilterSet() {
        let normalizedRules = normalizedFilterRules(filterRules)
        let saveResult = SchemaWorkbenchFilterSetSaveAction.save(
            rules: normalizedRules,
            activeFilterSetID: activeFilterSetID,
            existingFilterSets: filterSets,
            makeID: { number in
                "filter-set-\(number)-\(UUID().uuidString)"
            }
        )

        filterSets = saveResult.filterSets
        activeFilterSetID = saveResult.activeFilterSetID
        filterRules = normalizedRules
        openPopover = nil
    }

    private var filterableColumns: [WorkbenchTableColumn] {
        columns.filter { column in
            column.kind != .rowNumber
                && (filterableColumnIDs == nil || filterableColumnIDs?.contains(column.id) == true)
        }
    }

    private func normalizedFilterRules(_ sourceRules: [SchemaWorkbenchFilterRule]) -> [SchemaWorkbenchFilterRule] {
        guard !sourceRules.isEmpty else {
            return []
        }

        var normalizedRules = sourceRules
        let fallbackColumn = filterableColumns.first
        let resolvedJoin = normalizedRules.dropFirst().first?.join ?? .and
        for index in normalizedRules.indices {
            if index == 0 {
                normalizedRules[index].join = nil
            } else {
                normalizedRules[index].join = resolvedJoin
            }

            let column = filterableColumns.first { $0.id == normalizedRules[index].fieldID } ?? fallbackColumn
            if let column {
                normalizedRules[index].fieldID = column.id
                let operators = SchemaWorkbenchFilterRuleRow.operators(for: column)
                if !operators.contains(normalizedRules[index].operatorID) {
                    normalizedRules[index].operatorID = operators.first ?? .contains
                    normalizedRules[index].value = ""
                }
            }

            if SchemaWorkbenchFilterRuleRow.doesOperatorNeedNoValue(normalizedRules[index].operatorID) {
                normalizedRules[index].value = ""
            }
        }

        return normalizedRules
    }
}

struct SchemaWorkbenchFilterSetSaveResult: Equatable {
    let filterSets: [SchemaWorkbenchFilterSet]
    let activeFilterSetID: String
}

enum SchemaWorkbenchFilterSetSaveAction {
    static func save(
        rules: [SchemaWorkbenchFilterRule],
        activeFilterSetID: String?,
        existingFilterSets: [SchemaWorkbenchFilterSet],
        makeID: (Int) -> String
    ) -> SchemaWorkbenchFilterSetSaveResult {
        if let activeFilterSetID,
           let activeIndex = existingFilterSets.firstIndex(where: { $0.id == activeFilterSetID })
        {
            var filterSets = existingFilterSets
            let activeFilterSet = filterSets[activeIndex]
            filterSets[activeIndex] = SchemaWorkbenchFilterSet(
                id: activeFilterSet.id,
                name: activeFilterSet.name,
                rules: rules
            )

            return SchemaWorkbenchFilterSetSaveResult(
                filterSets: filterSets,
                activeFilterSetID: activeFilterSet.id
            )
        }

        var filterSets = existingFilterSets
        let nextNumber = filterSets.count + 1
        let id = makeID(nextNumber)
        filterSets.append(
            SchemaWorkbenchFilterSet(
                id: id,
                name: "Filter Set \(nextNumber)",
                rules: rules
            )
        )

        return SchemaWorkbenchFilterSetSaveResult(
            filterSets: filterSets,
            activeFilterSetID: id
        )
    }
}

private enum FilterBuilderDropdownKind: Hashable {
    case join
    case field
    case filterOperator
    case value
}

private struct FilterBuilderDropdownID: Hashable {
    let ruleID: String
    let kind: FilterBuilderDropdownKind
}

private enum FilterBuilderLayout {
    static let panelPadding: CGFloat = 16
    static let titleHeight: CGFloat = 22
    static let titleRowGap: CGFloat = 14
    static let rowHeight = WorkbenchControlMetrics.controlHeight
    static let rowSpacing: CGFloat = 12
    static let dropdownGap: CGFloat = 4

    static let prefixWidth: CGFloat = 58
    static let fieldWidth: CGFloat = 110
    static let operatorWidth: CGFloat = 150
    static let rowColumnGap: CGFloat = 10

    static func dropdownWidth(for kind: FilterBuilderDropdownKind) -> CGFloat {
        switch kind {
        case .join:
            return 96
        case .field:
            return 150
        case .filterOperator:
            return 190
        case .value:
            return 170
        }
    }

    static func dropdownX(for kind: FilterBuilderDropdownKind) -> CGFloat {
        switch kind {
        case .join:
            return panelPadding
        case .field:
            return panelPadding + prefixWidth + rowColumnGap
        case .filterOperator:
            return panelPadding + prefixWidth + rowColumnGap + fieldWidth + rowColumnGap
        case .value:
            return panelPadding
                + prefixWidth
                + rowColumnGap
                + fieldWidth
                + rowColumnGap
                + operatorWidth
                + rowColumnGap
        }
    }

    static func dropdownY(forRowAt index: Int) -> CGFloat {
        panelPadding
            + titleHeight
            + titleRowGap
            + CGFloat(index) * (rowHeight + rowSpacing)
            + rowHeight
            + dropdownGap
    }
}

enum SchemaWorkbenchStyle {
    static let pageHorizontalPadding: CGFloat = 12
    static let pageTopPadding: CGFloat = 10
    static let pageBottomPadding: CGFloat = 14
    static let tableCornerRadius: CGFloat = 8
    static let hairlineWidth: CGFloat = 0.5
    static let rowGap: CGFloat = 12

    static func viewPopoverTop(isRedesign: Bool) -> CGFloat {
        let searchHeight = isRedesign ? WorkbenchControlMetrics.redesignSearchHeight : WorkbenchControlMetrics.searchFieldHeight
        return pageTopPadding + searchHeight + 8
    }

    static func filterPopoverTop(isRedesign: Bool) -> CGFloat {
        let searchHeight = isRedesign ? WorkbenchControlMetrics.redesignSearchHeight : WorkbenchControlMetrics.searchFieldHeight
        let controlHeight = isRedesign ? WorkbenchControlMetrics.redesignHeight : WorkbenchControlMetrics.controlHeight
        return pageTopPadding
            + searchHeight
            + rowGap
            + controlHeight
            + 8
    }
}

struct SchemaWorkbenchSearchFilterBar: View {
    let placeholder: String
    @Binding var searchDraft: String
    let activeFilterSetName: String?
    let filterCount: Int
    var isRedesign: Bool = false
    var isFilterSetsMenuOpen: Bool = false
    var isFilterBuilderMenuOpen: Bool = false
    var onSubmit: (() -> Void)?
    var onFilterSets: () -> Void
    var onFilterBuilder: () -> Void
    var onReset: () -> Void

    var body: some View {
        let filterCountText = filterCount == 1 ? "1 Filter" : "\(filterCount) Filters"
        HStack(spacing: isRedesign ? WorkbenchControlMetrics.redesignSpacing3 : 10) {
            WorkbenchSearchField(
                placeholder: placeholder,
                text: $searchDraft,
                isRedesign: isRedesign,
                onSubmit: onSubmit
            )
            .frame(maxWidth: .infinity)

            WorkbenchToolbarButton(
                title: "Filter Sets",
                systemImage: "line.3.horizontal.decrease",
                showsChevron: true,
                isRedesign: isRedesign,
                isMenuOpen: isFilterSetsMenuOpen,
                action: onFilterSets
            )
            .workbenchDropdownAnchor(id: "filterSets", in: "SearchShellSpace")

            if filterCount > 0 {
                if isRedesign {
                    WorkbenchFilterPanelTriggerButton(
                        title: activeFilterSetName ?? filterCountText,
                        detail: activeFilterSetName == nil ? nil : filterCountText,
                        isMenuOpen: isFilterBuilderMenuOpen,
                        onTrigger: onFilterBuilder,
                        onClear: onReset
                    )
                    .workbenchDropdownAnchor(id: "filterBuilder", in: "SearchShellSpace")
                } else {
                    WorkbenchFilterChip(
                        systemImage: "line.3.horizontal.decrease",
                        title: activeFilterSetName ?? filterCountText,
                        detail: activeFilterSetName == nil ? nil : filterCountText,
                        action: onFilterBuilder
                    )

                    WorkbenchToolbarButton(
                        title: "Reset",
                        systemImage: "xmark",
                        showsChevron: false,
                        isRedesign: isRedesign,
                        action: onReset
                    )
                }
            } else {
                WorkbenchPlainActionButton(
                    title: "New Filter Set",
                    systemImage: "plus",
                    isRedesign: isRedesign,
                    action: onFilterBuilder
                )
                .workbenchDropdownAnchor(id: "filterBuilder", in: "SearchShellSpace")
            }
        }
        .frame(height: isRedesign ? WorkbenchControlMetrics.redesignHeight : WorkbenchControlMetrics.controlHeight)
    }
}

struct SchemaWorkbenchTableUtilityBar: View {
    var tableSummary: SchemaWorkbenchTableSummary?
    var summaryLeadingInset: CGFloat = 0
    var summaryAction: AnyView? = nil
    var isRedesign: Bool = false
    var isViewMenuOpen: Bool = false
    var onViewMenu: () -> Void

    var body: some View {
        HStack(spacing: isRedesign ? WorkbenchControlMetrics.redesignSpacing3 : 12) {
            if let tableSummary {
                SchemaWorkbenchCountSummaryView(summary: tableSummary)
                    .padding(.leading, summaryLeadingInset)
            }

            if let summaryAction {
                summaryAction
            }

            Spacer(minLength: 0)

            WorkbenchToolbarButton(
                title: "View",
                systemImage: "slider.horizontal.3",
                showsChevron: true,
                isRedesign: isRedesign,
                isMenuOpen: isViewMenuOpen,
                action: onViewMenu
            )
            .workbenchDropdownAnchor(id: "view", in: "SearchShellSpace")
        }
        .frame(height: isRedesign ? WorkbenchControlMetrics.redesignTableUtilityBarHeight : WorkbenchControlMetrics.controlHeight)
    }
}

struct SchemaWorkbenchCountSummaryView: View {
    let summary: SchemaWorkbenchTableSummary

    var body: some View {
        summaryText
            .font(.system(size: WorkbenchControlMetrics.redesignFontSizeBody, weight: .regular))
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .frame(height: WorkbenchControlMetrics.redesignTableUtilityBarHeight, alignment: .center)
    }

    private var summaryText: Text {
        SchemaWorkbenchCountSummaryText.segments(for: summary).reduce(Text("")) { partial, segment in
            partial + Text(segment.text).foregroundColor(color(for: segment.tone))
        }
    }

    private func color(for tone: SchemaWorkbenchCountSummarySegment.Tone) -> Color {
        switch tone {
        case .primary:
            return WorkbenchRedesignColors.textPrimary
        case .secondary:
            return WorkbenchRedesignColors.textMuted
        }
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
    let activeFilterSetName: String?
    let filterCount: Int
    var isFilterSetsMenuOpen: Bool = false
    var isFilterBuilderMenuOpen: Bool = false
    var onFilterSets: () -> Void
    var onFilterBuilder: () -> Void
    var onReset: () -> Void

    var body: some View {
        let filterCountText = filterCount == 1 ? "1 Filter" : "\(filterCount) Filters"
        HStack(spacing: 10) {
            WorkbenchToolbarButton(
                title: "Filter Sets",
                systemImage: "line.3.horizontal.decrease",
                showsChevron: true,
                isMenuOpen: isFilterSetsMenuOpen,
                action: onFilterSets
            )
            .workbenchDropdownAnchor(id: "filterSets", in: "SearchShellSpace")

            if filterCount > 0 {
                WorkbenchFilterChip(
                    systemImage: "line.3.horizontal.decrease",
                    title: activeFilterSetName ?? filterCountText,
                    detail: activeFilterSetName == nil ? nil : filterCountText,
                    action: onFilterBuilder
                )

                WorkbenchToolbarButton(
                    title: "Reset",
                    systemImage: "xmark",
                    showsChevron: false,
                    action: onReset
                )
            } else {
                WorkbenchPlainActionButton(
                    title: "New Filter Set",
                    systemImage: "plus",
                    action: onFilterBuilder
                )
                .workbenchDropdownAnchor(id: "filterBuilder", in: "SearchShellSpace")
            }

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

struct SchemaWorkbenchFilterSetPopover: View {
    let options: [SchemaWorkbenchFilterSet]
    let activeFilterSetID: String?
    var isRedesign: Bool = false
    var onSelect: (SchemaWorkbenchFilterSet) -> Void

    var body: some View {
        WorkbenchPopoverPanel(isRedesign: isRedesign) {
            VStack(spacing: 0) {
                ForEach(options) { option in
                    WorkbenchPopoverRow(
                        title: option.name,
                        isSelected: option.id == activeFilterSetID,
                        isHighlighted: option.id == activeFilterSetID,
                        isRedesign: isRedesign,
                        action: {
                            onSelect(option)
                        }
                    )
                }
            }
        }
    }
}

private struct DropdownFramePreferenceKey: PreferenceKey {
    typealias Value = [FilterBuilderDropdownID: CGRect]
    static var defaultValue: Value { [:] }
    static func reduce(value: inout Value, nextValue: () -> Value) {
        value.merge(nextValue()) { $1 }
    }
}

struct SchemaWorkbenchFilterBuilderPopover: View {
    let columns: [WorkbenchTableColumn]
    @Binding var rules: [SchemaWorkbenchFilterRule]
    var isRedesign: Bool = false
    var onSave: () -> Void
    @State private var openDropdown: FilterBuilderDropdownID?
    @State private var dropdownFrames: [FilterBuilderDropdownID: CGRect] = [:]
    @State private var openDropdownWidth: CGFloat = 0

    var body: some View {
        GeometryReader { popoverGeometry in
            ZStack(alignment: .topLeading) {
                WorkbenchPopoverPanel(isRedesign: isRedesign) {
                    VStack(alignment: .leading, spacing: 14) {
                        VStack(spacing: FilterBuilderLayout.rowSpacing) {
                            ForEach(Array(rules.enumerated()), id: \.element.id) { index, rule in
                                SchemaWorkbenchFilterRuleRow(
                                    rule: rule,
                                    rowIndex: index,
                                    columns: columns,
                                    openDropdown: openDropdown,
                                    isRedesign: isRedesign,
                                    onToggleDropdown: toggleDropdown,
                                    onChange: updateRule,
                                    onDelete: {
                                        deleteRule(rule.id)
                                    }
                                )
                                .zIndex(Double(rules.count - index))
                            }
                        }

                        HStack(spacing: 16) {
                            WorkbenchPlainActionButton(
                                title: "New Filter",
                                systemImage: "plus",
                                isRedesign: isRedesign,
                                action: addRule
                            )

                            Spacer(minLength: 0)
                        }

                        WorkbenchButton(title: "Save Filter Set", isRedesign: isRedesign, action: onSave)
                    }
                    .padding(8)
                }
                .coordinateSpace(name: "FilterBuilderSpace")
                .onPreferenceChange(DropdownFramePreferenceKey.self) { frames in
                    self.dropdownFrames = frames
                }

                dropdownOverlay(in: popoverGeometry.size.width)
                    .zIndex(1000)
            }
            .onChange(of: openDropdown) { _ in
                self.openDropdownWidth = 0
            }
        }
    }

    @ViewBuilder
    private func dropdownOverlay(in containerWidth: CGFloat) -> some View {
        if let openDropdown,
           let rowIndex = rules.firstIndex(where: { $0.id == openDropdown.ruleID }),
           let frame = dropdownFrames[openDropdown]
        {
            WorkbenchDropdownPanel(
                choices: dropdownChoices(for: openDropdown),
                selectedID: selectedDropdownID(for: openDropdown),
                isRedesign: isRedesign,
                onSelect: { choice in
                    selectDropdownChoice(choice, for: openDropdown)
                    self.openDropdown = nil
                }
            )
            .frame(
                minWidth: isRedesign ? frame.width : FilterBuilderLayout.dropdownWidth(for: openDropdown.kind),
                alignment: .topLeading
            )
            .fixedSize(horizontal: isRedesign, vertical: false)
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onAppear {
                            self.openDropdownWidth = geo.size.width
                        }
                        .onChange(of: geo.size.width) { newWidth in
                            self.openDropdownWidth = newWidth
                        }
                }
            )
            .offset(
                x: isRedesign ? {
                    let triggerMinX = frame.minX
                    let popoverWidth = self.openDropdownWidth > 0 ? self.openDropdownWidth : max(220, frame.width)
                    let rightLimit = containerWidth - 8
                    return max(8, min(triggerMinX, rightLimit - popoverWidth))
                }() : FilterBuilderLayout.dropdownX(for: openDropdown.kind),
                y: isRedesign ? (frame.maxY + 4) : FilterBuilderLayout.dropdownY(forRowAt: rowIndex)
            )
        }
    }

    private func toggleDropdown(_ id: FilterBuilderDropdownID) {
        openDropdown = openDropdown == id ? nil : id
    }

    private func dropdownChoices(for id: FilterBuilderDropdownID) -> [WorkbenchDropdownChoice] {
        guard let rule = rules.first(where: { $0.id == id.ruleID }) else {
            return []
        }

        switch id.kind {
        case .join:
            return Self.joinChoices
        case .field:
            return fieldChoices
        case .filterOperator:
            return operatorChoices(for: rule)
        case .value:
            return Self.multiSelectChoices
        }
    }

    private func selectedDropdownID(for id: FilterBuilderDropdownID) -> String? {
        guard let rule = rules.first(where: { $0.id == id.ruleID }) else {
            return nil
        }

        switch id.kind {
        case .join:
            return rule.join?.id ?? SchemaWorkbenchFilterJoin.and.id
        case .field:
            return rule.fieldID
        case .filterOperator:
            return rule.operatorID.id
        case .value:
            return rule.value.isEmpty ? nil : rule.value
        }
    }

    private func selectDropdownChoice(
        _ choice: WorkbenchDropdownChoice,
        for id: FilterBuilderDropdownID
    ) {
        guard let rule = rules.first(where: { $0.id == id.ruleID }) else {
            return
        }

        var updatedRule = rule

        switch id.kind {
        case .join:
            guard let join = SchemaWorkbenchFilterJoin(rawValue: choice.id) else {
                return
            }

            updatedRule.join = join
        case .field:
            guard let column = columns.first(where: { $0.id == choice.id }) else {
                return
            }

            updatedRule.fieldID = column.id
            updatedRule.operatorID = SchemaWorkbenchFilterRuleRow.operators(for: column).first ?? .contains
            updatedRule.value = ""
        case .filterOperator:
            guard let operatorID = SchemaWorkbenchFilterOperatorID(rawValue: choice.id) else {
                return
            }

            updatedRule.operatorID = operatorID
            if SchemaWorkbenchFilterRuleRow.doesOperatorNeedNoValue(operatorID) {
                updatedRule.value = ""
            }
        case .value:
            updatedRule.value = choice.id
        }

        updateRule(updatedRule)
    }

    private func addRule() {
        guard let firstColumn = filterableColumns.first else {
            return
        }

        let resolvedJoin = rules.count <= 1 ? SchemaWorkbenchFilterJoin.and : (rules.dropFirst().first?.join ?? .and)
        rules.append(
            SchemaWorkbenchFilterRule(
                id: UUID().uuidString,
                join: rules.isEmpty ? nil : resolvedJoin,
                fieldID: firstColumn.id,
                operatorID: SchemaWorkbenchFilterRuleRow.operators(for: firstColumn).first ?? .contains,
                value: ""
            )
        )
    }

    private func updateRule(_ updatedRule: SchemaWorkbenchFilterRule) {
        guard let index = rules.firstIndex(where: { $0.id == updatedRule.id }) else {
            return
        }

        rules[index] = updatedRule
        normalizeRules()
    }

    private func normalizeRules() {
        guard !rules.isEmpty else {
            return
        }

        let resolvedJoin = rules.dropFirst().first?.join ?? .and
        for index in rules.indices {
            rules[index].join = index == 0 ? nil : resolvedJoin

            let column = filterableColumns.first { $0.id == rules[index].fieldID } ?? filterableColumns.first
            if let column {
                rules[index].fieldID = column.id
                let operators = SchemaWorkbenchFilterRuleRow.operators(for: column)
                if !operators.contains(rules[index].operatorID) {
                    rules[index].operatorID = operators.first ?? .contains
                    rules[index].value = ""
                }
            }

            if SchemaWorkbenchFilterRuleRow.doesOperatorNeedNoValue(rules[index].operatorID) {
                rules[index].value = ""
            }
        }
    }

    private func deleteRule(_ id: String) {
        rules.removeAll { $0.id == id }

        if rules.isEmpty {
            addRule()
        } else {
            normalizeRules()
        }
    }

    private var fieldChoices: [WorkbenchDropdownChoice] {
        filterableColumns.map { column in
            WorkbenchDropdownChoice(id: column.id, title: column.title)
        }
    }

    private var filterableColumns: [WorkbenchTableColumn] {
        columns.filter { $0.kind != .rowNumber }
    }

    private func operatorChoices(for rule: SchemaWorkbenchFilterRule) -> [WorkbenchDropdownChoice] {
        let column = columns.first { $0.id == rule.fieldID }

        return SchemaWorkbenchFilterRuleRow.operators(for: column).map { operatorID in
            WorkbenchDropdownChoice(id: operatorID.id, title: operatorID.title)
        }
    }

    private static let joinChoices = SchemaWorkbenchFilterJoin.allCases.map { join in
        WorkbenchDropdownChoice(id: join.id, title: join.title)
    }

    private static let multiSelectChoices: [WorkbenchDropdownChoice] = []
}

private struct SchemaWorkbenchFilterRuleRow: View {
    let rule: SchemaWorkbenchFilterRule
    let rowIndex: Int
    let columns: [WorkbenchTableColumn]
    let openDropdown: FilterBuilderDropdownID?
    var isRedesign: Bool = false
    var onToggleDropdown: (FilterBuilderDropdownID) -> Void
    var onChange: (SchemaWorkbenchFilterRule) -> Void
    var onDelete: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        HStack(spacing: 10) {
            Group {
                if rowIndex == 0 {
                    Text("Where")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(isRedesign ? (isEnabled ? WorkbenchRedesignColors.textPrimary : WorkbenchRedesignColors.textDisabled) : WorkbenchControlColors.primaryText)
                        .frame(height: isRedesign ? WorkbenchControlMetrics.redesignFieldHeight : nil)
                } else if rowIndex == 1 {
                    WorkbenchInlineDropdown(
                        title: rule.join?.title ?? SchemaWorkbenchFilterJoin.and.title,
                        isOpen: isDropdownOpen(.join),
                        isRedesign: isRedesign,
                        action: {
                            onToggleDropdown(dropdownID(.join))
                        }
                    )
                    .background(
                        GeometryReader { geo in
                            Color.clear
                                .preference(
                                    key: DropdownFramePreferenceKey.self,
                                    value: [dropdownID(.join): geo.frame(in: .named("FilterBuilderSpace"))]
                                )
                        }
                    )
                } else {
                    Text(rule.join?.title ?? SchemaWorkbenchFilterJoin.and.title)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(isRedesign ? (isEnabled ? WorkbenchRedesignColors.textPrimary : WorkbenchRedesignColors.textDisabled) : WorkbenchControlColors.primaryText)
                        .frame(height: isRedesign ? WorkbenchControlMetrics.redesignFieldHeight : nil)
                }
            }
            .frame(width: isRedesign ? nil : 58, alignment: .leading)

            WorkbenchInlineDropdown(
                title: selectedColumn?.title ?? "Field",
                isOpen: isDropdownOpen(.field),
                isRedesign: isRedesign,
                action: {
                    onToggleDropdown(dropdownID(.field))
                }
            )
            .background(
                GeometryReader { geo in
                    Color.clear
                        .preference(
                            key: DropdownFramePreferenceKey.self,
                            value: [dropdownID(.field): geo.frame(in: .named("FilterBuilderSpace"))]
                        )
                }
            )
            .frame(width: isRedesign ? nil : 110)

            WorkbenchInlineDropdown(
                title: rule.operatorID.title,
                isOpen: isDropdownOpen(.filterOperator),
                isRedesign: isRedesign,
                action: {
                    onToggleDropdown(dropdownID(.filterOperator))
                }
            )
            .background(
                GeometryReader { geo in
                    Color.clear
                        .preference(
                            key: DropdownFramePreferenceKey.self,
                            value: [dropdownID(.filterOperator): geo.frame(in: .named("FilterBuilderSpace"))]
                        )
                }
            )
            .frame(width: isRedesign ? nil : 150)

            valueInput
                .frame(maxWidth: .infinity)

            WorkbenchIconButton(systemImage: "trash", isRedesign: isRedesign, action: onDelete)
                .frame(width: 40)
        }
    }

    @ViewBuilder
    private var valueInput: some View {
        if Self.doesOperatorNeedNoValue(rule.operatorID) {
            WorkbenchReadonlyField(title: "No value needed", isRedesign: isRedesign)
        } else {
            WorkbenchTextInputField(
                placeholder: valuePlaceholder,
                text: Binding(
                    get: {
                        rule.value
                    },
                    set: { value in
                        var updatedRule = rule
                        updatedRule.value = sanitizedInput(value)
                        onChange(updatedRule)
                    }
                ),
                isRedesign: isRedesign
            )
        }
    }

    private var selectedColumn: WorkbenchTableColumn? {
        columns.first { $0.id == rule.fieldID }
    }

    private var valuePlaceholder: String {
        switch selectedColumn?.kind {
        case .rowNumber:
            return "Enter number..."
        case .multiSelect:
            return "Enter a value..."
        case .text, nil:
            return "Enter a value..."
        }
    }

    private func sanitizedInput(_ value: String) -> String {
        guard selectedColumn?.kind == .rowNumber else {
            return value
        }

        return String(value.filter { $0.isNumber })
    }

    private func isDropdownOpen(_ kind: FilterBuilderDropdownKind) -> Bool {
        openDropdown == dropdownID(kind)
    }

    private func dropdownID(_ kind: FilterBuilderDropdownKind) -> FilterBuilderDropdownID {
        FilterBuilderDropdownID(ruleID: rule.id, kind: kind)
    }

    fileprivate static func operators(for column: WorkbenchTableColumn?) -> [SchemaWorkbenchFilterOperatorID] {
        switch column?.kind {
        case .rowNumber:
            return [
                .equals,
                .doesNotEqual,
                .greaterThan,
                .greaterThanOrEqualTo,
                .lessThan,
                .lessThanOrEqualTo,
                .isEmpty,
                .isNotEmpty,
            ]
        case .multiSelect:
            return [.contains, .doesNotContain, .isEmpty, .isNotEmpty]
        case .text, nil:
            return [.contains, .doesNotContain, .is, .isNot, .isEmpty, .isNotEmpty]
        }
    }

    fileprivate static func doesOperatorNeedNoValue(_ operatorID: SchemaWorkbenchFilterOperatorID) -> Bool {
        operatorID == .isEmpty || operatorID == .isNotEmpty
    }
}
