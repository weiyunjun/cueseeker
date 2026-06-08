import SwiftUI

enum WorkbenchTableColumnKind: Equatable {
    case rowNumber
    case text
    case multiSelect
}

enum WorkbenchTableColumnWidth: Equatable {
    case fixed(CGFloat)
    case flexible(min: CGFloat)
    case weighted(min: CGFloat, weight: CGFloat)
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
            let resolvedColumns = WorkbenchResolvedTableColumn.resolve(
                columns,
                totalWidth: geometry.size.width
            )

            VStack(spacing: 0) {
                header(columns: resolvedColumns)

                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(rows) { row in
                            WorkbenchDataTableRow(
                                columns: resolvedColumns,
                                row: row
                            )
                        }
                    }
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

    private func header(columns: [WorkbenchResolvedTableColumn]) -> some View {
        HStack(spacing: 0) {
            ForEach(columns) { column in
                columnFrame(column) {
                    Text(column.column.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(WorkbenchControlColors.primaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, column.id == "rowNumber" ? 16 : 12)
                }
            }
        }
        .frame(height: WorkbenchTableMetrics.headerHeight)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(WorkbenchControlColors.border)
                .frame(height: WorkbenchControlMetrics.hairlineWidth)
        }
    }
}

private struct WorkbenchDataTableRow: View {
    let columns: [WorkbenchResolvedTableColumn]
    let row: WorkbenchTableRow

    var body: some View {
        HStack(spacing: 0) {
            ForEach(columns) { column in
                columnFrame(column) {
                    WorkbenchDataTableCell(
                        column: column.column,
                        value: row.cells[column.id] ?? .empty
                    )
                }
            }
        }
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

    static func resolve(
        _ columns: [WorkbenchTableColumn],
        totalWidth: CGFloat
    ) -> [WorkbenchResolvedTableColumn] {
        let weightedColumns = columns.compactMap { column -> (column: WorkbenchTableColumn, min: CGFloat, weight: CGFloat)? in
            switch column.width {
            case .fixed:
                return nil
            case .flexible(let minWidth):
                return (column, minWidth, 1)
            case .weighted(let minWidth, let weight):
                return (column, minWidth, max(0, weight))
            }
        }

        let fixedTotal = columns.reduce(CGFloat.zero) { total, column in
            switch column.width {
            case .fixed(let width):
                return total + width
            case .flexible, .weighted:
                return total
            }
        }

        let weightedMinTotal = weightedColumns.reduce(CGFloat.zero) { total, item in
            total + item.min
        }
        let weightedTotal = weightedColumns.reduce(CGFloat.zero) { total, item in
            total + item.weight
        }
        let extraWidth = max(0, totalWidth - fixedTotal - weightedMinTotal)

        return columns.map { column in
            WorkbenchResolvedTableColumn(
                column: column,
                width: resolvedWidth(
                    for: column,
                    extraWidth: extraWidth,
                    weightedTotal: weightedTotal
                )
            )
        }
    }

    private static func resolvedWidth(
        for column: WorkbenchTableColumn,
        extraWidth: CGFloat,
        weightedTotal: CGFloat
    ) -> CGFloat {
        switch column.width {
        case .fixed(let width):
            return width
        case .flexible(let minWidth):
            guard weightedTotal > 0 else {
                return minWidth
            }

            return minWidth + extraWidth / weightedTotal
        case .weighted(let minWidth, let weight):
            guard weightedTotal > 0 else {
                return minWidth
            }

            return minWidth + extraWidth * max(0, weight) / weightedTotal
        }
    }
}

private enum WorkbenchTableMetrics {
    static let cornerRadius: CGFloat = 8
    static let headerHeight: CGFloat = 44
    static let rowMinHeight: CGFloat = 58
}
