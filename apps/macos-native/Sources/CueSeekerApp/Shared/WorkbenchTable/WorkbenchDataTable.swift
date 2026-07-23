import SwiftUI

enum WorkbenchTableColumnKind: Equatable {
    case rowNumber
    case text
    case multiSelect
}

enum WorkbenchTableColumnWidth: Equatable {
    case fixed(CGFloat)
    case flexible(min: CGFloat)
    case weighted(weight: CGFloat, min: CGFloat)
}

struct WorkbenchWeightedColumnWidthSpec: Equatable {
    let id: String
    let weight: CGFloat
    let minimumWidth: CGFloat
}

enum WorkbenchWeightedColumnWidthResolver {
    static func resolve(
        _ columns: [WorkbenchWeightedColumnWidthSpec],
        availableWidth: CGFloat
    ) -> [String: CGFloat] {
        guard !columns.isEmpty else { return [:] }

        var unresolved = columns
        var widths: [String: CGFloat] = [:]
        var remainingWidth = max(
            availableWidth,
            columns.reduce(CGFloat.zero) { $0 + max(0, $1.minimumWidth) }
        )

        while !unresolved.isEmpty {
            let totalWeight = unresolved.reduce(CGFloat.zero) { $0 + max(0, $1.weight) }
            guard totalWeight > 0 else {
                for column in unresolved {
                    widths[column.id] = max(0, column.minimumWidth)
                }
                break
            }

            let widthPerWeight = remainingWidth / totalWeight
            let constrained = unresolved.filter {
                widthPerWeight * max(0, $0.weight) < max(0, $0.minimumWidth)
            }
            guard !constrained.isEmpty else {
                var assignedWidth: CGFloat = 0
                for (index, column) in unresolved.enumerated() {
                    let width = index == unresolved.indices.last
                        ? remainingWidth - assignedWidth
                        : widthPerWeight * max(0, column.weight)
                    widths[column.id] = max(0, width)
                    assignedWidth += width
                }
                break
            }

            let constrainedIDs = Set(constrained.map(\.id))
            for column in constrained {
                let width = max(0, column.minimumWidth)
                widths[column.id] = width
                remainingWidth -= width
            }
            unresolved.removeAll { constrainedIDs.contains($0.id) }
        }

        return widths
    }
}

struct WorkbenchTableColumn: Identifiable, Equatable {
    let id: String
    let title: String
    let kind: WorkbenchTableColumnKind
    let width: WorkbenchTableColumnWidth
}

struct WorkbenchTableRow: Identifiable, Equatable {
    let id: String
    let cells: [String: WorkbenchTableCellValue]
}

enum WorkbenchTableCellValue: Equatable {
    case rowNumber(Int)
    case text(String)
    case multiSelect([WorkbenchMultiSelectOption])
    case empty
}

struct WorkbenchMultiSelectOption: Identifiable, Equatable {
    let title: String
    let style: WorkbenchBadgeStyle

    var id: String {
        title
    }
}

enum WorkbenchBadgeStyle: Equatable {
    case blue
    case pink
    case gray

    var foregroundColor: Color {
        switch self {
        case .blue:
            return Color(red: 0.078, green: 0.322, blue: 0.647)
        case .pink:
            return Color(red: 0.529, green: 0.122, blue: 0.337)
        case .gray:
            return WorkbenchControlColors.mutedText
        }
    }

    var fillColor: Color {
        switch self {
        case .blue:
            return Color(red: 0.855, green: 0.925, blue: 1.0)
        case .pink:
            return Color(red: 0.969, green: 0.855, blue: 0.929)
        case .gray:
            return Color(nsColor: .labelColor).opacity(0.08)
        }
    }
}

struct WorkbenchDataTable: View {
    let columns: [WorkbenchTableColumn]
    let rows: [WorkbenchTableRow]

    var body: some View {
        GeometryReader { geometry in
            let layout = WorkbenchResolvedTableLayout.resolve(
                columns,
                totalWidth: geometry.size.width
            )

            VStack(spacing: 0) {
                header(layout: layout)

                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(rows) { row in
                            WorkbenchDataTableRow(
                                layout: layout,
                                row: row
                            )
                        }
                    }
                    .frame(width: layout.contentWidth, alignment: .topLeading)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .scrollIndicators(.visible)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(WorkbenchControlColors.surfaceFill)
        .clipShape(
            RoundedRectangle(
                cornerRadius: WorkbenchTableMetrics.cornerRadius,
                style: .continuous
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: WorkbenchTableMetrics.cornerRadius,
                style: .continuous
            )
            .strokeBorder(
                WorkbenchControlColors.border,
                lineWidth: WorkbenchControlMetrics.hairlineWidth
            )
        )
    }

    private func header(layout: WorkbenchResolvedTableLayout) -> some View {
        HStack(spacing: 0) {
            ForEach(layout.columns) { column in
                columnFrame(column) {
                    Text(column.column.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(WorkbenchControlColors.primaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, column.id == "rowNumber" ? 16 : 12)
                }
            }
        }
        .frame(width: layout.contentWidth, alignment: .topLeading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: WorkbenchTableMetrics.headerHeight)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(WorkbenchControlColors.border)
                .frame(height: WorkbenchControlMetrics.hairlineWidth)
        }
    }
}

private struct WorkbenchDataTableRow: View {
    let layout: WorkbenchResolvedTableLayout
    let row: WorkbenchTableRow

    var body: some View {
        HStack(spacing: 0) {
            ForEach(layout.columns) { column in
                columnFrame(column) {
                    WorkbenchDataTableCell(
                        column: column.column,
                        value: row.cells[column.id] ?? .empty
                    )
                }
            }
        }
        .frame(width: layout.contentWidth, alignment: .topLeading)
        .frame(minHeight: WorkbenchTableMetrics.rowMinHeight, alignment: .top)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(WorkbenchControlColors.border.opacity(0.55))
                .frame(height: WorkbenchControlMetrics.hairlineWidth)
        }
    }
}

private struct WorkbenchDataTableCell: View {
    let column: WorkbenchTableColumn
    let value: WorkbenchTableCellValue

    var body: some View {
        Group {
            switch resolvedValue {
            case .rowNumber(let number):
                Text("\(number)")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(WorkbenchControlColors.primaryText)
                    .lineLimit(1)
            case .text(let text):
                Text(text)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(WorkbenchControlColors.primaryText)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            case .multiSelect(let options):
                WorkbenchMultiSelectCell(options: options)
            case .empty:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(.horizontal, column.id == "rowNumber" ? 16 : 12)
        .padding(.vertical, 9)
    }

    private var resolvedValue: WorkbenchTableCellValue {
        switch value {
        case .empty:
            switch column.kind {
            case .rowNumber:
                return .rowNumber(0)
            case .text:
                return .text("")
            case .multiSelect:
                return .multiSelect([])
            }
        default:
            return value
        }
    }
}

private struct WorkbenchMultiSelectCell: View {
    let options: [WorkbenchMultiSelectOption]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(options) { option in
                WorkbenchBadge(
                    title: option.title,
                    foregroundColor: option.style.foregroundColor,
                    fillColor: option.style.fillColor
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

@ViewBuilder
private func columnFrame<Content: View>(
    _ column: WorkbenchResolvedTableColumn,
    @ViewBuilder content: () -> Content
) -> some View {
    content()
        .frame(width: column.width, alignment: .topLeading)
}

private struct WorkbenchResolvedTableColumn: Identifiable {
    let column: WorkbenchTableColumn
    let width: CGFloat

    var id: String {
        column.id
    }
}

private struct WorkbenchResolvedTableLayout {
    let columns: [WorkbenchResolvedTableColumn]
    let contentWidth: CGFloat

    static func resolve(
        _ columns: [WorkbenchTableColumn],
        totalWidth: CGFloat
    ) -> WorkbenchResolvedTableLayout {
        let fixedTotal = columns.reduce(CGFloat.zero) { total, column in
            switch column.width {
            case .fixed(let width):
                return total + width
            case .flexible, .weighted:
                return total
            }
        }
        let flexibleMinTotal = columns.reduce(CGFloat.zero) { total, column in
            switch column.width {
            case .fixed:
                return total
            case .flexible(let minWidth):
                return total + minWidth
            case .weighted(_, let minWidth):
                return total + minWidth
            }
        }
        let minimumContentWidth = fixedTotal + flexibleMinTotal
        let contentWidth = max(totalWidth, minimumContentWidth)
        let usesExplicitWeights = columns.contains {
            if case .weighted = $0.width {
                return true
            }
            return false
        }
        let weightedWidths: [String: CGFloat]
        if usesExplicitWeights {
            weightedWidths = WorkbenchWeightedColumnWidthResolver.resolve(
                columns.compactMap { column in
                    switch column.width {
                    case .fixed:
                        return nil
                    case .flexible(let minWidth):
                        return WorkbenchWeightedColumnWidthSpec(
                            id: column.id,
                            weight: 1,
                            minimumWidth: minWidth
                        )
                    case .weighted(let weight, let minWidth):
                        return WorkbenchWeightedColumnWidthSpec(
                            id: column.id,
                            weight: weight,
                            minimumWidth: minWidth
                        )
                    }
                },
                availableWidth: contentWidth - fixedTotal
            )
        } else {
            let flexibleCount = columns.reduce(CGFloat.zero) {
                if case .flexible = $1.width {
                    return $0 + 1
                }
                return $0
            }
            let extraWidth = max(0, contentWidth - minimumContentWidth)
            weightedWidths = Dictionary(uniqueKeysWithValues: columns.compactMap { column in
                guard case .flexible(let minWidth) = column.width else { return nil }
                return (column.id, minWidth + extraWidth / max(1, flexibleCount))
            })
        }

        return WorkbenchResolvedTableLayout(
            columns: columns.map { column in
                WorkbenchResolvedTableColumn(
                    column: column,
                    width: resolvedWidth(
                        for: column,
                        weightedWidths: weightedWidths
                    )
                )
            },
            contentWidth: contentWidth
        )
    }

    private static func resolvedWidth(
        for column: WorkbenchTableColumn,
        weightedWidths: [String: CGFloat]
    ) -> CGFloat {
        switch column.width {
        case .fixed(let width):
            return width
        case .flexible(let minWidth), .weighted(_, let minWidth):
            return weightedWidths[column.id] ?? minWidth
        }
    }
}

private enum WorkbenchTableMetrics {
    static let cornerRadius: CGFloat = 8
    static let headerHeight: CGFloat = 44
    static let rowMinHeight: CGFloat = 58
}
