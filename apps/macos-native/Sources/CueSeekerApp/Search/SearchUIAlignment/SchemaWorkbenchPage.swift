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

                WorkbenchDataTable()
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

private struct WorkbenchDataTable: View {
    private let columns = ["#", "Name", "Cues", "Language", "Speaker"]

    var body: some View {
        VStack(spacing: 0) {
            tableHeader

            VStack(spacing: 0) {
                ForEach(0..<10, id: \.self) { _ in
                    tablePlaceholderRow
                }

                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(WorkbenchControlColors.surfaceFill)
        .clipShape(
            RoundedRectangle(
                cornerRadius: SchemaWorkbenchStyle.tableCornerRadius,
                style: .continuous
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: SchemaWorkbenchStyle.tableCornerRadius,
                style: .continuous
            )
            .strokeBorder(
                WorkbenchControlColors.border,
                lineWidth: SchemaWorkbenchStyle.hairlineWidth
            )
        )
    }

    private var tableHeader: some View {
        HStack(spacing: 0) {
            ForEach(columns, id: \.self) { column in
                headerCell(column)
            }
        }
        .frame(height: 44)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(WorkbenchControlColors.border)
                .frame(height: SchemaWorkbenchStyle.hairlineWidth)
        }
    }

    private var tablePlaceholderRow: some View {
        HStack(spacing: 0) {
            rowCell(columnWidth: 54, barWidth: 14, opacity: 0.16)
            rowCell(columnWidth: 260, barWidth: 170, opacity: 0.12)
            rowCell(columnWidth: nil, barWidth: nil, opacity: 0.10)
            rowCell(columnWidth: 200, barWidth: 112, opacity: 0.12)
            rowCell(columnWidth: 180, barWidth: 104, opacity: 0.12)
        }
        .frame(height: 42)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(WorkbenchControlColors.border.opacity(0.55))
                .frame(height: SchemaWorkbenchStyle.hairlineWidth)
        }
    }

    @ViewBuilder
    private func headerCell(_ column: String) -> some View {
        let content = Text(column)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(WorkbenchControlColors.primaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, column == "#" ? 16 : 12)

        if let width = columnWidth(for: column) {
            content.frame(width: width, alignment: .leading)
        } else {
            content.frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func rowCell(columnWidth: CGFloat?, barWidth: CGFloat?, opacity: Double) -> some View {
        let content = Rectangle()
            .fill(WorkbenchControlColors.primaryText.opacity(opacity))
            .frame(width: barWidth, height: 10)
            .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
            .frame(maxWidth: barWidth == nil ? .infinity : barWidth, alignment: .leading)
            .padding(.horizontal, columnWidth == 54 ? 16 : 12)

        if let columnWidth {
            content.frame(width: columnWidth, alignment: .leading)
        } else {
            content.frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func columnWidth(for column: String) -> CGFloat? {
        switch column {
        case "#": return 54
        case "Name": return 260
        case "Language": return 200
        case "Speaker": return 180
        default: return nil
        }
    }
}
