import SwiftUI

struct SchemaWorkbenchPage: View {
    @State private var openPopover: SchemaWorkbenchPopover?
    @State private var searchDraft: String
    @State private var visibleColumnIDs: Set<String>
    @State private var activeFilterSetID: String?
    @State private var filterRules: [SchemaWorkbenchFilterRule]

    init() {
        _searchDraft = State(initialValue: "")
        _visibleColumnIDs = State(initialValue: Self.initialVisibleColumnIDs)
        _activeFilterSetID = State(initialValue: Self.defaultFilterSetID)
        _filterRules = State(initialValue: Self.defaultFilterRules)
    }

    var body: some View {
        ZStack {
            SchemaWorkbenchStyle.pageBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                SearchCommandBar(
                    searchDraft: $searchDraft,
                    onViewMenu: {
                        togglePopover(.columnVisibility)
                    }
                )
                    .padding(.horizontal, SchemaWorkbenchStyle.pageHorizontalPadding)
                    .padding(.top, SchemaWorkbenchStyle.pageTopPadding)
                    .padding(.bottom, 12)

                FilterControlBar(
                    activeFilterSetName: activeFilterSetName,
                    filterCount: filterRules.count,
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

                WorkbenchDataTable(
                    columns: visibleColumns,
                    rows: Self.tableRows
                )
                    .padding(.horizontal, SchemaWorkbenchStyle.pageHorizontalPadding)
                    .padding(.bottom, SchemaWorkbenchStyle.pageBottomPadding)
                    .frame(maxHeight: .infinity)
            }

            overlayLayer
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
            ColumnVisibilityPopover(
                columns: Self.tableColumns,
                visibleColumnIDs: visibleColumnIDs,
                onToggleColumn: toggleColumnVisibility
            )
            .frame(width: 220)
            .offset(
                x: max(
                    SchemaWorkbenchStyle.pageHorizontalPadding,
                    geometry.size.width - SchemaWorkbenchStyle.pageHorizontalPadding - 220
                ),
                y: SchemaWorkbenchStyle.viewPopoverTop
            )
        case .filterSets:
            FilterSetPopover(
                options: Self.filterSets,
                activeFilterSetID: activeFilterSetID,
                onSelect: selectFilterSet
            )
            .frame(width: 260)
            .offset(
                x: SchemaWorkbenchStyle.pageHorizontalPadding,
                y: SchemaWorkbenchStyle.filterPopoverTop
            )
        case .filterBuilder:
            FilterBuilderPopover(
                columns: Self.tableColumns,
                rules: $filterRules,
                onSave: {
                    openPopover = nil
                }
            )
            .frame(width: min(760, max(360, geometry.size.width - 2 * SchemaWorkbenchStyle.pageHorizontalPadding)))
            .offset(
                x: SchemaWorkbenchStyle.pageHorizontalPadding,
                y: SchemaWorkbenchStyle.filterPopoverTop
            )
        }
    }

    private func togglePopover(_ popover: SchemaWorkbenchPopover) {
        openPopover = openPopover == popover ? nil : popover
    }

    private var visibleColumns: [WorkbenchTableColumn] {
        Self.tableColumns.filter { visibleColumnIDs.contains($0.id) }
    }

    private var activeFilterSetName: String? {
        guard let activeFilterSetID else {
            return nil
        }

        return Self.filterSets.first { $0.id == activeFilterSetID }?.name
    }

    private func toggleColumnVisibility(_ columnID: String) {
        if visibleColumnIDs.contains(columnID) {
            visibleColumnIDs.remove(columnID)
        } else {
            visibleColumnIDs.insert(columnID)
        }
    }

    private func selectFilterSet(_ filterSet: SchemaWorkbenchFilterSet) {
        activeFilterSetID = filterSet.id
        filterRules = filterSet.rules
        openPopover = nil
    }

    private func openFilterBuilder() {
        if filterRules.isEmpty {
            activeFilterSetID = nil
            filterRules = [
                Self.makeFilterRule(
                    join: nil,
                    fieldID: "name",
                    operatorID: .contains,
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

    private static let tableColumns: [WorkbenchTableColumn] = [
        WorkbenchTableColumn(
            id: "rowNumber",
            title: "#",
            kind: .rowNumber,
            width: .fixed(84)
        ),
        WorkbenchTableColumn(
            id: "name",
            title: "Name",
            kind: .text,
            width: .fixed(300)
        ),
        WorkbenchTableColumn(
            id: "cues",
            title: "Cues",
            kind: .text,
            width: .weighted(min: 580, weight: 3)
        ),
        WorkbenchTableColumn(
            id: "language",
            title: "Language",
            kind: .multiSelect,
            width: .weighted(min: 230, weight: 2.5)
        ),
        WorkbenchTableColumn(
            id: "speaker",
            title: "Speaker",
            kind: .text,
            width: .weighted(min: 220, weight: 0.5)
        ),
    ]

    private static let initialVisibleColumnIDs = Set(tableColumns.map(\.id))

    private static let defaultFilterSetID = "bangdream"

    private static var defaultFilterRules: [SchemaWorkbenchFilterRule] {
        filterSets.first { $0.id == defaultFilterSetID }?.rules ?? []
    }

    private static let filterSets: [SchemaWorkbenchFilterSet] = [
        SchemaWorkbenchFilterSet(
            id: "bangdream",
            name: "bangdream",
            rules: [
                makeFilterRule(
                    id: "bangdream-name",
                    join: nil,
                    fieldID: "name",
                    operatorID: .contains,
                    value: "Ave Mujica"
                ),
                makeFilterRule(
                    id: "bangdream-language",
                    join: .and,
                    fieldID: "language",
                    operatorID: .contains,
                    value: "中文"
                ),
            ]
        ),
        SchemaWorkbenchFilterSet(
            id: "ave-mujica",
            name: "Ave Mujica",
            rules: [
                makeFilterRule(
                    id: "ave-name",
                    join: nil,
                    fieldID: "name",
                    operatorID: .contains,
                    value: "Ave Mujica"
                ),
                makeFilterRule(
                    id: "ave-speaker",
                    join: .and,
                    fieldID: "speaker",
                    operatorID: .contains,
                    value: "祥子"
                ),
            ]
        ),
        SchemaWorkbenchFilterSet(
            id: "chinese-only",
            name: "Chinese Only",
            rules: [
                makeFilterRule(
                    id: "chinese-language",
                    join: nil,
                    fieldID: "language",
                    operatorID: .contains,
                    value: "中文"
                ),
            ]
        ),
        SchemaWorkbenchFilterSet(
            id: "speaker-focus",
            name: "Speaker Focus",
            rules: [
                makeFilterRule(
                    id: "speaker-sakiko",
                    join: nil,
                    fieldID: "speaker",
                    operatorID: .contains,
                    value: "丰川祥子"
                ),
                makeFilterRule(
                    id: "speaker-mutsumi",
                    join: .or,
                    fieldID: "speaker",
                    operatorID: .contains,
                    value: "若叶睦"
                ),
                makeFilterRule(
                    id: "speaker-cues",
                    join: .and,
                    fieldID: "cues",
                    operatorID: .contains,
                    value: "大丈夫"
                ),
            ]
        ),
    ]

    private static func makeFilterRule(
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

    private static let tableRows: [WorkbenchTableRow] = [
        tableRow(
            1,
            name: "Ave Mujica - 01",
            cues: "母親担心 月曜日会为我们的她做醒\n大丈夫月の光迎えにしてくれますわ",
            speaker: "丰川祥子"
        ),
        tableRow(
            2,
            name: "Ave Mujica - 01",
            cues: "没问题的 波を跳踊的侍轻视我\n大丈夫あなたの言葉こそ航標よ",
            speaker: "若叶睦"
        ),
        tableRow(
            3,
            name: "Ave Mujica - 01",
            cues: "枠　言渡迷　没问题吧\n枠　言渡迷　大丈夫",
            speaker: "高松灯"
        ),
        tableRow(
            4,
            name: "Ave Mujica - 01",
            cues: "当然没问题\n大丈夫に決まっているでしょう",
            speaker: "千早爱音"
        ),
        tableRow(
            5,
            name: "Ave Mujica - 02",
            cues: "小初 你没事吧\nういちゃん　大丈夫",
            speaker: "长崎素世"
        ),
        tableRow(
            6,
            name: "Ave Mujica - 02",
            cues: "我没事\n私は大丈夫だよ",
            speaker: "丰川祥子"
        ),
        tableRow(
            7,
            name: "Ave Mujica - 03",
            cues: "应该没问题吧\n大丈夫かなぁ",
            speaker: "若叶睦"
        ),
        tableRow(
            8,
            name: "Ave Mujica - 03",
            cues: "所以已经没事了\nだから　もう大丈夫",
            speaker: "高松灯"
        ),
        tableRow(
            9,
            name: "Ave Mujica - 04",
            cues: "没有害怕也没关系对吧\nギターなんてなくても大丈夫だったでしょう",
            speaker: "千早爱音"
        ),
        tableRow(
            10,
            name: "Ave Mujica - 05",
            cues: "小睦别看很心 虽然美不会有事吧\n睦ちゃんすごい叫んでたけど　大丈夫かな",
            speaker: "长崎素世"
        ),
        tableRow(
            11,
            name: "Ave Mujica - 05",
            cues: "灯灯 你还好吗\nともらん　大丈夫",
            speaker: "丰川祥子"
        ),
        tableRow(
            12,
            name: "Ave Mujica - 06",
            cues: "没事的 我会从一切恐怖的东西那里保护你\n大丈夫　怖いことからは全部　私が守ってあげる",
            speaker: "若叶睦"
        ),
    ]

    private static func tableRow(
        _ rowNumber: Int,
        name: String,
        cues: String,
        speaker: String
    ) -> WorkbenchTableRow {
        WorkbenchTableRow(
            id: "mock-\(rowNumber)",
            cells: [
                "rowNumber": .rowNumber(rowNumber),
                "name": .text(name),
                "cues": .text(cues),
                "language": .multiSelect([
                    WorkbenchMultiSelectOption(title: "中文", style: .pink),
                    WorkbenchMultiSelectOption(title: "日本語", style: .blue),
                ]),
                "speaker": .text(speaker),
            ]
        )
    }
}

private enum SchemaWorkbenchPopover: Equatable {
    case columnVisibility
    case filterSets
    case filterBuilder
}

private struct SchemaWorkbenchFilterSet: Identifiable, Equatable {
    let id: String
    let name: String
    let rules: [SchemaWorkbenchFilterRule]
}

private struct SchemaWorkbenchFilterRule: Identifiable, Equatable {
    let id: String
    var join: SchemaWorkbenchFilterJoin?
    var fieldID: String
    var operatorID: SchemaWorkbenchFilterOperatorID
    var value: String
}

private enum SchemaWorkbenchFilterJoin: String, CaseIterable, Identifiable {
    case and
    case or

    var id: String {
        rawValue
    }

    var title: String {
        rawValue
    }
}

private enum SchemaWorkbenchFilterOperatorID: String, Identifiable {
    case contains
    case doesNotContain
    case `is`
    case isNot
    case isEmpty
    case isNotEmpty

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
        }
    }
}

private enum SchemaWorkbenchStyle {
    static let pageHorizontalPadding: CGFloat = 12
    static let pageTopPadding: CGFloat = 10
    static let pageBottomPadding: CGFloat = 14
    static let tableCornerRadius: CGFloat = 8
    static let hairlineWidth: CGFloat = 0.5
    static let rowGap: CGFloat = 12

    static let viewPopoverTop = pageTopPadding + WorkbenchControlMetrics.searchFieldHeight + 8
    static let filterPopoverTop = pageTopPadding
        + WorkbenchControlMetrics.searchFieldHeight
        + rowGap
        + WorkbenchControlMetrics.controlHeight
        + 8

    static let pageBackground = Color(
        red: 0.965,
        green: 0.965,
        blue: 0.958
    )
}

private struct SearchCommandBar: View {
    @Binding var searchDraft: String
    var onViewMenu: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            WorkbenchSearchField(
                placeholder: "Search cues by name, lyrics, or keywords...",
                text: $searchDraft
            )
                .frame(maxWidth: .infinity)

            WorkbenchToolbarButton(
                title: "View",
                systemImage: "slider.horizontal.3",
                showsChevron: true,
                action: onViewMenu
            )
            .frame(width: 110)
        }
        .frame(height: WorkbenchControlMetrics.searchFieldHeight)
    }
}

private struct FilterControlBar: View {
    let activeFilterSetName: String?
    let filterCount: Int
    var onFilterSets: () -> Void
    var onFilterBuilder: () -> Void
    var onReset: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            WorkbenchToolbarButton(
                title: "Filter Sets",
                systemImage: "line.3.horizontal.decrease",
                showsChevron: true,
                action: onFilterSets
            )
            .frame(width: 150)

            if filterCount > 0 {
                WorkbenchFilterChip(
                    systemImage: "line.3.horizontal.decrease",
                    title: activeFilterSetName ?? "\(filterCount) Filters",
                    detail: activeFilterSetName == nil ? nil : "\(filterCount) Filters",
                    action: onFilterBuilder
                )
                .frame(width: activeFilterSetName == nil ? 132 : 190)

                WorkbenchToolbarButton(
                    title: "Reset",
                    systemImage: "xmark",
                    showsChevron: false,
                    action: onReset
                )
                .frame(width: 92)
            } else {
                WorkbenchPlainActionButton(
                    title: "New Filter Set",
                    systemImage: "plus",
                    action: onFilterBuilder
                )
                .frame(width: 170)
            }

            Spacer(minLength: 0)
        }
        .frame(height: WorkbenchControlMetrics.controlHeight)
    }
}

private struct ColumnVisibilityPopover: View {
    let columns: [WorkbenchTableColumn]
    let visibleColumnIDs: Set<String>
    var onToggleColumn: (String) -> Void

    var body: some View {
        WorkbenchPopoverPanel {
            VStack(spacing: 0) {
                ForEach(columns) { column in
                    WorkbenchPopoverRow(
                        title: column.title,
                        isSelected: visibleColumnIDs.contains(column.id),
                        action: {
                            onToggleColumn(column.id)
                        }
                    )
                }
            }
        }
    }
}

private struct FilterSetPopover: View {
    let options: [SchemaWorkbenchFilterSet]
    let activeFilterSetID: String?
    var onSelect: (SchemaWorkbenchFilterSet) -> Void

    var body: some View {
        WorkbenchPopoverPanel {
            VStack(spacing: 0) {
                ForEach(options) { option in
                    WorkbenchPopoverRow(
                        title: option.name,
                        isSelected: option.id == activeFilterSetID,
                        isHighlighted: option.id == activeFilterSetID,
                        action: {
                            onSelect(option)
                        }
                    )
                }
            }
        }
    }
}

private struct FilterBuilderPopover: View {
    let columns: [WorkbenchTableColumn]
    @Binding var rules: [SchemaWorkbenchFilterRule]
    var onSave: () -> Void

    var body: some View {
        WorkbenchPopoverPanel {
            VStack(alignment: .leading, spacing: 14) {
                Text("New Filter Set")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(WorkbenchControlColors.primaryText)

                VStack(spacing: 12) {
                    ForEach(Array(rules.enumerated()), id: \.element.id) { index, rule in
                        FilterRuleRow(
                            rule: rule,
                            isFirst: index == 0,
                            columns: columns,
                            onChange: updateRule,
                            onDelete: {
                                deleteRule(rule.id)
                            }
                        )
                        .zIndex(Double(rules.count - index))
                    }
                }

                HStack(spacing: 16) {
                    Button(action: addRule) {
                        HStack(spacing: 8) {
                            Image(systemName: "plus")
                            Text("New Filter")
                        }
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(WorkbenchControlColors.primaryText)
                    }
                    .buttonStyle(.plain)

                    Spacer(minLength: 0)
                }

                Button(action: onSave) {
                    Text("Save Filter Set")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(WorkbenchControlColors.primaryText)
                        .padding(.horizontal, 14)
                        .frame(height: 36)
                        .background(WorkbenchControlBackground())
                }
                .buttonStyle(.plain)
            }
            .padding(8)
        }
    }

    private func addRule() {
        guard let firstColumn = columns.first else {
            return
        }

        rules.append(
            SchemaWorkbenchFilterRule(
                id: UUID().uuidString,
                join: rules.isEmpty ? nil : .and,
                fieldID: firstColumn.id,
                operatorID: FilterRuleRow.operators(for: firstColumn).first ?? .contains,
                value: ""
            )
        )
    }

    private func updateRule(_ updatedRule: SchemaWorkbenchFilterRule) {
        guard let index = rules.firstIndex(where: { $0.id == updatedRule.id }) else {
            return
        }

        var normalizedRule = updatedRule
        normalizedRule.join = index == 0 ? nil : (normalizedRule.join ?? .and)

        if let column = columns.first(where: { $0.id == normalizedRule.fieldID }) {
            let operators = FilterRuleRow.operators(for: column)
            if !operators.contains(normalizedRule.operatorID) {
                normalizedRule.operatorID = operators.first ?? .contains
                normalizedRule.value = ""
            }
        }

        rules[index] = normalizedRule
    }

    private func deleteRule(_ id: String) {
        rules.removeAll { $0.id == id }

        if rules.isEmpty {
            addRule()
        } else {
            rules[0].join = nil
        }
    }
}

private struct FilterRuleRow: View {
    let rule: SchemaWorkbenchFilterRule
    let isFirst: Bool
    let columns: [WorkbenchTableColumn]
    var onChange: (SchemaWorkbenchFilterRule) -> Void
    var onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Group {
                if isFirst {
                    Text("Where")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(WorkbenchControlColors.primaryText)
                } else {
                    WorkbenchInlineDropdown(
                        title: rule.join?.title ?? SchemaWorkbenchFilterJoin.and.title,
                        choices: Self.joinChoices,
                        selectedID: rule.join?.id ?? SchemaWorkbenchFilterJoin.and.id,
                        onSelect: selectJoin
                    )
                }
            }
            .frame(width: 58, alignment: .leading)

            WorkbenchInlineDropdown(
                title: selectedColumn?.title ?? "Field",
                choices: fieldChoices,
                selectedID: rule.fieldID,
                onSelect: selectField
            )
            .frame(width: 110)

            WorkbenchInlineDropdown(
                title: rule.operatorID.title,
                choices: operatorChoices,
                selectedID: rule.operatorID.id,
                onSelect: selectOperator
            )
            .frame(width: 150)

            valueInput
                .frame(maxWidth: .infinity)

            WorkbenchIconButton(systemImage: "trash", action: onDelete)
                .frame(width: 40)
        }
    }

    @ViewBuilder
    private var valueInput: some View {
        if Self.doesOperatorNeedNoValue(rule.operatorID) {
            HStack {
                Text("No value needed")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(WorkbenchControlColors.mutedText)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .frame(height: WorkbenchControlMetrics.controlHeight)
            .background(WorkbenchControlBackground())
        } else if selectedColumn?.kind == .multiSelect {
            WorkbenchInlineDropdown(
                title: rule.value.isEmpty ? "Select value..." : rule.value,
                choices: Self.multiSelectChoices,
                selectedID: rule.value.isEmpty ? nil : rule.value,
                onSelect: selectMultiSelectValue
            )
        } else {
            WorkbenchTextInputField(
                placeholder: valuePlaceholder,
                text: Binding(
                    get: {
                        rule.value
                    },
                    set: { value in
                        var updatedRule = rule
                        updatedRule.value = value
                        onChange(updatedRule)
                    }
                )
            )
        }
    }

    private var selectedColumn: WorkbenchTableColumn? {
        columns.first { $0.id == rule.fieldID }
    }

    private var fieldChoices: [WorkbenchDropdownChoice] {
        columns.map { column in
            WorkbenchDropdownChoice(id: column.id, title: column.title)
        }
    }

    private var operatorChoices: [WorkbenchDropdownChoice] {
        Self.operators(for: selectedColumn).map { operatorID in
            WorkbenchDropdownChoice(id: operatorID.id, title: operatorID.title)
        }
    }

    private var valuePlaceholder: String {
        switch selectedColumn?.kind {
        case .rowNumber:
            return "Enter number..."
        case .multiSelect:
            return "Select value..."
        case .text, nil:
            return "Enter a value..."
        }
    }

    private func selectJoin(_ choice: WorkbenchDropdownChoice) {
        guard let join = SchemaWorkbenchFilterJoin(rawValue: choice.id) else {
            return
        }

        var updatedRule = rule
        updatedRule.join = join
        onChange(updatedRule)
    }

    private func selectField(_ choice: WorkbenchDropdownChoice) {
        guard let column = columns.first(where: { $0.id == choice.id }) else {
            return
        }

        var updatedRule = rule
        updatedRule.fieldID = column.id
        updatedRule.operatorID = Self.operators(for: column).first ?? .contains
        updatedRule.value = ""
        onChange(updatedRule)
    }

    private func selectOperator(_ choice: WorkbenchDropdownChoice) {
        guard let operatorID = SchemaWorkbenchFilterOperatorID(rawValue: choice.id) else {
            return
        }

        var updatedRule = rule
        updatedRule.operatorID = operatorID
        if Self.doesOperatorNeedNoValue(operatorID) {
            updatedRule.value = ""
        }
        onChange(updatedRule)
    }

    private func selectMultiSelectValue(_ choice: WorkbenchDropdownChoice) {
        var updatedRule = rule
        updatedRule.value = choice.id
        onChange(updatedRule)
    }

    fileprivate static func operators(for column: WorkbenchTableColumn?) -> [SchemaWorkbenchFilterOperatorID] {
        switch column?.kind {
        case .rowNumber:
            return [.is, .isNot, .isEmpty, .isNotEmpty]
        case .multiSelect:
            return [.contains, .doesNotContain, .is, .isNot, .isEmpty, .isNotEmpty]
        case .text, nil:
            return [.contains, .doesNotContain, .is, .isNot, .isEmpty, .isNotEmpty]
        }
    }

    private static func doesOperatorNeedNoValue(_ operatorID: SchemaWorkbenchFilterOperatorID) -> Bool {
        operatorID == .isEmpty || operatorID == .isNotEmpty
    }

    private static let joinChoices = SchemaWorkbenchFilterJoin.allCases.map { join in
        WorkbenchDropdownChoice(id: join.id, title: join.title)
    }

    private static let multiSelectChoices = ["中文", "日本語"].map { value in
        WorkbenchDropdownChoice(id: value, title: value)
    }
}
