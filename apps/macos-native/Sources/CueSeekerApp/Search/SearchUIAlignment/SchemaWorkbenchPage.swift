import SwiftUI

struct SchemaWorkbenchPage: View {
    @State private var openPopover: SchemaWorkbenchPopover?

    var body: some View {
        ZStack {
            SchemaWorkbenchStyle.pageBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                SearchCommandBar(
                    onViewMenu: {
                        togglePopover(.columnVisibility)
                    }
                )
                    .padding(.horizontal, SchemaWorkbenchStyle.pageHorizontalPadding)
                    .padding(.top, SchemaWorkbenchStyle.pageTopPadding)
                    .padding(.bottom, 12)

                FilterControlBar(
                    onFilterSets: {
                        togglePopover(.filterSets)
                    },
                    onFilterBuilder: {
                        togglePopover(.filterBuilder)
                    },
                    onReset: {
                        openPopover = nil
                    }
                )
                    .padding(.horizontal, SchemaWorkbenchStyle.pageHorizontalPadding)
                    .padding(.bottom, 12)

                WorkbenchDataTable(
                    columns: Self.tableColumns,
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
            ColumnVisibilityPopover {
                openPopover = nil
            }
            .frame(width: 220)
            .offset(
                x: max(
                    SchemaWorkbenchStyle.pageHorizontalPadding,
                    geometry.size.width - SchemaWorkbenchStyle.pageHorizontalPadding - 220
                ),
                y: SchemaWorkbenchStyle.viewPopoverTop
            )
        case .filterSets:
            FilterSetPopover {
                openPopover = nil
            }
            .frame(width: 260)
            .offset(
                x: SchemaWorkbenchStyle.pageHorizontalPadding,
                y: SchemaWorkbenchStyle.filterPopoverTop
            )
        case .filterBuilder:
            FilterBuilderPopover {
                openPopover = nil
            }
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

    private static let tableColumns: [WorkbenchTableColumn] = [
        WorkbenchTableColumn(
            id: "rowNumber",
            title: "#",
            kind: .rowNumber,
            width: .fixed(54)
        ),
        WorkbenchTableColumn(
            id: "name",
            title: "Name",
            kind: .text,
            width: .fixed(260)
        ),
        WorkbenchTableColumn(
            id: "cues",
            title: "Cues",
            kind: .text,
            width: .flexible(min: 360)
        ),
        WorkbenchTableColumn(
            id: "language",
            title: "Language",
            kind: .multiSelect,
            width: .fixed(200)
        ),
        WorkbenchTableColumn(
            id: "speaker",
            title: "Speaker",
            kind: .text,
            width: .fixed(180)
        ),
    ]

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
    var onViewMenu: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            WorkbenchSearchField(placeholder: "Search cues by name, lyrics, or keywords...")
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

            WorkbenchFilterChip(
                systemImage: "line.3.horizontal.decrease",
                title: "bangdream",
                detail: "2 Filters",
                action: onFilterBuilder
            )
                .frame(width: 190)

            WorkbenchToolbarButton(
                title: "Reset",
                systemImage: "xmark",
                showsChevron: false,
                action: onReset
            )
            .frame(width: 92)

            Spacer(minLength: 0)
        }
        .frame(height: WorkbenchControlMetrics.controlHeight)
    }
}

private struct ColumnVisibilityPopover: View {
    let onDismiss: () -> Void
    private let columns = ["#", "Name", "Cues", "Language", "Speaker"]

    var body: some View {
        WorkbenchPopoverPanel {
            VStack(spacing: 0) {
                ForEach(columns, id: \.self) { column in
                    WorkbenchPopoverRow(
                        title: column,
                        isSelected: true,
                        action: onDismiss
                    )
                }
            }
        }
    }
}

private struct FilterSetPopover: View {
    let onDismiss: () -> Void
    private let options = ["bangdream", "Ave Mujica", "Chinese Only", "Speaker Focus"]

    var body: some View {
        WorkbenchPopoverPanel {
            VStack(spacing: 0) {
                ForEach(options, id: \.self) { option in
                    WorkbenchPopoverRow(
                        title: option,
                        isSelected: option == "bangdream",
                        action: onDismiss
                    )
                }
            }
        }
    }
}

private struct FilterBuilderPopover: View {
    let onDismiss: () -> Void

    var body: some View {
        WorkbenchPopoverPanel {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("New Filter Set")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(WorkbenchControlColors.primaryText)

                    Spacer(minLength: 0)

                    WorkbenchIconButton(systemImage: "xmark", action: onDismiss)
                        .frame(width: 32, height: 32)
                }

                VStack(spacing: 12) {
                    FilterRuleRow(prefix: "Where", joiner: nil)
                    FilterRuleRow(prefix: nil, joiner: "and")
                    FilterRuleRow(prefix: nil, joiner: "or")
                }

                HStack(spacing: 16) {
                    Button(action: {}) {
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

                Button(action: onDismiss) {
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
}

private struct FilterRuleRow: View {
    let prefix: String?
    let joiner: String?

    var body: some View {
        HStack(spacing: 10) {
            Group {
                if let prefix {
                    Text(prefix)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(WorkbenchControlColors.primaryText)
                } else if let joiner {
                    WorkbenchSelectField(title: joiner)
                }
            }
            .frame(width: 58, alignment: .leading)

            WorkbenchSelectField(title: "Name")
            .frame(width: 110)

            WorkbenchSelectField(title: "contains")
            .frame(width: 150)

            HStack {
                Text("Enter a value...")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(WorkbenchControlColors.mutedText)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .frame(height: WorkbenchControlMetrics.controlHeight)
            .background(WorkbenchControlBackground())
            .frame(maxWidth: .infinity)

            WorkbenchIconButton(systemImage: "trash")
                .frame(width: 40)
        }
    }
}
