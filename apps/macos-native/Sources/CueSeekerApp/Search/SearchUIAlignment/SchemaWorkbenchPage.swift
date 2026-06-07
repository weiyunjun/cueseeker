import SwiftUI

struct SchemaWorkbenchPage: View {
    var body: some View {
        ZStack {
            SchemaWorkbenchStyle.pageBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                SearchCommandBar()
                    .padding(.horizontal, SchemaWorkbenchStyle.pageHorizontalPadding)
                    .padding(.top, SchemaWorkbenchStyle.pageTopPadding)
                    .padding(.bottom, 12)

                FilterControlBar()
                    .padding(.horizontal, SchemaWorkbenchStyle.pageHorizontalPadding)
                    .padding(.bottom, 12)

                WorkbenchDataTable()
                    .padding(.horizontal, SchemaWorkbenchStyle.pageHorizontalPadding)
                    .padding(.bottom, SchemaWorkbenchStyle.pageBottomPadding)
                    .frame(maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private enum SchemaWorkbenchStyle {
    static let pageHorizontalPadding: CGFloat = 12
    static let pageTopPadding: CGFloat = 10
    static let pageBottomPadding: CGFloat = 14
    static let tableCornerRadius: CGFloat = 8
    static let hairlineWidth: CGFloat = 0.5

    static let pageBackground = Color(
        red: 0.965,
        green: 0.965,
        blue: 0.958
    )
}

private struct SearchCommandBar: View {
    var body: some View {
        HStack(spacing: 12) {
            WorkbenchSearchField(placeholder: "Search cues by name, lyrics, or keywords...")
                .frame(maxWidth: .infinity)

            WorkbenchToolbarButton(
                title: "View",
                systemImage: "slider.horizontal.3",
                showsChevron: true
            )
            .frame(width: 110)
        }
        .frame(height: WorkbenchControlMetrics.searchFieldHeight)
    }
}

private struct FilterControlBar: View {
    var body: some View {
        HStack(spacing: 10) {
            WorkbenchToolbarButton(
                title: "Filter Sets",
                systemImage: "line.3.horizontal.decrease",
                showsChevron: true
            )
            .frame(width: 150)

            WorkbenchFilterChip(
                systemImage: "line.3.horizontal.decrease",
                title: "bangdream",
                detail: "2 Filters"
            )
                .frame(width: 190)

            WorkbenchToolbarButton(
                title: "Reset",
                systemImage: "xmark",
                showsChevron: false
            )
            .frame(width: 92)

            Spacer(minLength: 0)
        }
        .frame(height: WorkbenchControlMetrics.controlHeight)
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
