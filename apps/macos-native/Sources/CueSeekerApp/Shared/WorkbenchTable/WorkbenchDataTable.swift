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
