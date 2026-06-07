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
    static let controlHeight: CGFloat = 46
    static let compactControlHeight: CGFloat = 40
    static let controlCornerRadius: CGFloat = 8
    static let tableCornerRadius: CGFloat = 8
    static let hairlineWidth: CGFloat = 0.5

    static let pageBackground = Color(
        red: 0.965,
        green: 0.965,
        blue: 0.958
    )
    static let surfaceFill = Color(nsColor: .textBackgroundColor)
    static let borderColor = Color(nsColor: .separatorColor)
    static let mutedText = Color(nsColor: .secondaryLabelColor)
    static let activeBlue = Color(red: 0.035, green: 0.412, blue: 0.957)
    static let activeBlueFill = Color(red: 0.910, green: 0.952, blue: 1.0)
}

private struct SearchCommandBar: View {
    var body: some View {
        HStack(spacing: 12) {
            searchField
                .frame(maxWidth: .infinity)

            toolbarButton(
                title: "View",
                systemImage: "slider.horizontal.3",
                showsChevron: true
            )
            .frame(width: 110)
        }
        .frame(height: SchemaWorkbenchStyle.controlHeight)
    }

    private var searchField: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(SchemaWorkbenchStyle.mutedText)

            Text("Search cues by name, lyrics, or keywords...")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(SchemaWorkbenchStyle.mutedText)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .frame(height: SchemaWorkbenchStyle.controlHeight)
        .background(controlBackground)
    }
}

private struct FilterControlBar: View {
    var body: some View {
        HStack(spacing: 10) {
            toolbarButton(
                title: "Filter Sets",
                systemImage: "line.3.horizontal.decrease",
                showsChevron: true
            )
            .frame(width: 150)

            activeFilterChip
                .frame(width: 190)

            toolbarButton(
                title: "Reset",
                systemImage: "xmark",
                showsChevron: false
            )
            .frame(width: 92)

            Spacer(minLength: 0)
        }
        .frame(height: SchemaWorkbenchStyle.compactControlHeight)
    }

    private var activeFilterChip: some View {
        HStack(spacing: 10) {
            Image(systemName: "line.3.horizontal.decrease")
                .font(.system(size: 16, weight: .semibold))

            Text("bangdream")
                .font(.system(size: 15, weight: .regular))

            Text("2 Filters")
                .font(.system(size: 15, weight: .semibold))

            Spacer(minLength: 0)
        }
        .foregroundStyle(SchemaWorkbenchStyle.activeBlue)
        .padding(.horizontal, 14)
        .frame(height: SchemaWorkbenchStyle.compactControlHeight)
        .background(
            RoundedRectangle(
                cornerRadius: SchemaWorkbenchStyle.controlCornerRadius,
                style: .continuous
            )
            .fill(SchemaWorkbenchStyle.activeBlueFill)
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: SchemaWorkbenchStyle.controlCornerRadius,
                style: .continuous
            )
            .strokeBorder(SchemaWorkbenchStyle.activeBlue.opacity(0.24), lineWidth: 1)
        )
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
        .background(SchemaWorkbenchStyle.surfaceFill)
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
                SchemaWorkbenchStyle.borderColor,
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
                .fill(SchemaWorkbenchStyle.borderColor)
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
                .fill(SchemaWorkbenchStyle.borderColor.opacity(0.55))
                .frame(height: SchemaWorkbenchStyle.hairlineWidth)
        }
    }

    @ViewBuilder
    private func headerCell(_ column: String) -> some View {
        let content = Text(column)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color(nsColor: .labelColor))
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
            .fill(Color(nsColor: .labelColor).opacity(opacity))
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

@MainActor
private func toolbarButton(
    title: String,
    systemImage: String,
    showsChevron: Bool
) -> some View {
    HStack(spacing: 10) {
        Image(systemName: systemImage)
            .font(.system(size: 16, weight: .medium))

        Text(title)
            .font(.system(size: 15, weight: .medium))

        if showsChevron {
            Spacer(minLength: 0)
            Image(systemName: "chevron.down")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(SchemaWorkbenchStyle.mutedText)
        }
    }
    .foregroundStyle(Color(nsColor: .labelColor))
    .padding(.horizontal, 14)
    .frame(height: SchemaWorkbenchStyle.compactControlHeight)
    .background(controlBackground)
}

@MainActor
private var controlBackground: some View {
    RoundedRectangle(
        cornerRadius: SchemaWorkbenchStyle.controlCornerRadius,
        style: .continuous
    )
    .fill(SchemaWorkbenchStyle.surfaceFill)
    .overlay(
        RoundedRectangle(
            cornerRadius: SchemaWorkbenchStyle.controlCornerRadius,
            style: .continuous
        )
        .strokeBorder(
            SchemaWorkbenchStyle.borderColor,
            lineWidth: SchemaWorkbenchStyle.hairlineWidth
        )
    )
}
