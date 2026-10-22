import AppKit
import CueSeekerCore
import SwiftUI

// MARK: - Metrics

enum SubtitleTableMetrics {
    static let indexColumnWidth: CGFloat = 50
    static let dateAddedColumnWidth: CGFloat = 160
    static let timeColumnWidth: CGFloat = 190
    static let nameColumnWidth: CGFloat = 240
    static let cuesColumnMinimumWidth: CGFloat = 240
    static let languageColumnWidth: CGFloat = 160
    static let dateAddedColumnMinimumWidth: CGFloat = 120
    static let timeColumnMinimumWidth: CGFloat = 140
    static let displayTitleColumnMinimumWidth: CGFloat = 180
    static let languageColumnMinimumWidth: CGFloat = 120
    static let dateAddedColumnWeight: CGFloat = 2
    static let timeColumnWeight: CGFloat = 2
    static let displayTitleColumnWeight: CGFloat = 3
    static let cuesColumnWeight: CGFloat = 6
    static let languageColumnWeight: CGFloat = 2
    static let cellLeading: CGFloat = 12
    static let trailingInset: CGFloat = 14
    static let indexTrailingInset: CGFloat = 6
    static let rowVerticalInset: CGFloat = SubtitleTableCueGeometry.rowPaddingY
    static let headerHeight: CGFloat = 44
    static let headerHorizontalInset: CGFloat = 12
    static let indexHeaderHorizontalInset: CGFloat = 16
    static let cornerRadius: CGFloat = 10
    static let estimatedRowHeight: CGFloat = 56
    static let tagHeight: CGFloat = 22
    static let tagHorizontalInset: CGFloat = 8
    static let tagRedesignHorizontalInset: CGFloat = 10
    static let tagRedesignVerticalInset: CGFloat = 4
    static let tagCornerRadius: CGFloat = 6
    static let tagHorizontalSpacing: CGFloat = 6
    static let tagVerticalSpacing: CGFloat = 4
    /// Provisional --size-checkbox: 21px icon box (document: 16px)
    static let checkboxSize: CGFloat = 21
    /// Provisional: the cue state glyph after a row's last text line, 18px icon box.
    static let cueStateIndicatorSize: CGFloat = 18
    static let checkboxHitSlop: CGFloat = 8
    static let tableCellHoverPaddingX = WorkbenchControlMetrics.redesignTableCellHoverPaddingX
    static let tableCellHoverPaddingY = WorkbenchControlMetrics.redesignTableCellHoverPaddingY
    static let tableCellHoverRadius = WorkbenchControlMetrics.redesignTableCellHoverRadius
    static let scrollbarSize = TableScrollbarPrimitiveMetrics.size
    static let scrollbarInset = TableScrollbarPrimitiveMetrics.inset
    static let scrollbarMinThumbLength = TableScrollbarPrimitiveMetrics.minimumThumbLength
    static let scrollbarHitSlop = TableScrollbarPrimitiveMetrics.hitSlop
    static let interactiveTextUnderlineThickness = WorkbenchControlMetrics.redesignInteractiveTextUnderlineThickness
    static let interactiveTextUnderlineOffset = WorkbenchControlMetrics.redesignInteractiveTextUnderlineOffset
}

struct SubtitleTableTextDragAutoScrollGeometry {
    static let edgeZone: CGFloat = 32
    static let maximumStep: CGFloat = 24

    static func nextOrigin(
        pointer: CGPoint,
        viewport: CGRect,
        currentOrigin: CGPoint,
        contentSize: CGSize,
        viewportSize: CGSize,
        allowsVerticalScrolling: Bool = true
    ) -> CGPoint {
        guard !viewport.isEmpty else { return currentOrigin }
        let horizontalDelta = axisDelta(
            value: pointer.x,
            minimum: viewport.minX,
            maximum: viewport.maxX,
            leadingSign: -1,
            trailingSign: 1
        )
        let verticalDelta = allowsVerticalScrolling ? axisDelta(
            value: pointer.y,
            minimum: viewport.minY,
            maximum: viewport.maxY,
            leadingSign: 1,
            trailingSign: -1
        ) : 0
        let maximumX = max(0, contentSize.width - viewportSize.width)
        let maximumY = max(0, contentSize.height - viewportSize.height)
        return CGPoint(
            x: min(max(0, currentOrigin.x + horizontalDelta), maximumX),
            y: min(max(0, currentOrigin.y + verticalDelta), maximumY)
        )
    }

    private static func axisDelta(
        value: CGFloat,
        minimum: CGFloat,
        maximum: CGFloat,
        leadingSign: CGFloat,
        trailingSign: CGFloat
    ) -> CGFloat {
        let leadingPenetration = min(max(0, minimum + edgeZone - value) / edgeZone, 1)
        if leadingPenetration > 0 {
            return leadingSign * maximumStep * leadingPenetration * leadingPenetration
        }
        let trailingPenetration = min(max(0, value - (maximum - edgeZone)) / edgeZone, 1)
        if trailingPenetration > 0 {
            return trailingSign * maximumStep * trailingPenetration * trailingPenetration
        }
        return 0
    }
}

struct SubtitleTableColumnLayout: Equatable {
    var indexRect: CGRect
    var dateAddedRect: CGRect?
    var nameRect: CGRect
    var timeRect: CGRect?
    var cuesRect: CGRect
    var languageRect: CGRect?
    var contentWidth: CGFloat

    private static let defaultTextColumnOrder = [
        "display",
        "cues",
        "time",
        "dateAdded",
        "language",
    ]

    static func minimumContentWidth(
        showsDateAddedColumn: Bool = false,
        showsDisplayTitleColumn: Bool = true,
        showsTimeColumn: Bool = false,
        showsLanguageColumn: Bool,
        cuesMinimumWidth: CGFloat
    ) -> CGFloat {
        let M = SubtitleTableMetrics.self
        let columns = resolvedTextColumnOrder(
            [],
            showsDateAddedColumn: showsDateAddedColumn,
            showsDisplayTitleColumn: showsDisplayTitleColumn,
            showsTimeColumn: showsTimeColumn,
            showsLanguageColumn: showsLanguageColumn
        ).compactMap {
            weightedWidthSpec(for: $0, cuesMinimumWidth: cuesMinimumWidth)
        }
        return M.indexColumnWidth + columns.reduce(CGFloat.zero) {
            $0 + $1.minimumWidth
        }
    }

    static func resolve(
        contentWidth: CGFloat,
        height: CGFloat,
        showsDateAddedColumn: Bool = false,
        showsDisplayTitleColumn: Bool = true,
        showsTimeColumn: Bool = false,
        showsLanguageColumn: Bool,
        cuesMinimumWidth: CGFloat,
        columnOrder: [String] = []
    ) -> SubtitleTableColumnLayout {
        let M = SubtitleTableMetrics.self
        let minimumWidth = minimumContentWidth(
            showsDateAddedColumn: showsDateAddedColumn,
            showsDisplayTitleColumn: showsDisplayTitleColumn,
            showsTimeColumn: showsTimeColumn,
            showsLanguageColumn: showsLanguageColumn,
            cuesMinimumWidth: cuesMinimumWidth
        )
        let resolvedContentWidth = max(0, contentWidth, minimumWidth)
        let textColumnOrder = resolvedTextColumnOrder(
            columnOrder,
            showsDateAddedColumn: showsDateAddedColumn,
            showsDisplayTitleColumn: showsDisplayTitleColumn,
            showsTimeColumn: showsTimeColumn,
            showsLanguageColumn: showsLanguageColumn
        )
        let weightedWidths = WorkbenchWeightedColumnWidthResolver.resolve(
            textColumnOrder.compactMap {
                weightedWidthSpec(for: $0, cuesMinimumWidth: cuesMinimumWidth)
            },
            availableWidth: max(0, resolvedContentWidth - M.indexColumnWidth)
        )

        var x: CGFloat = 0
        let indexRect = CGRect(x: x, y: 0, width: M.indexColumnWidth, height: height)
        x += M.indexColumnWidth
        var dateAddedRect: CGRect?
        var nameRect = CGRect(x: x, y: 0, width: 0, height: height)
        var timeRect: CGRect?
        var cuesRect = CGRect(x: x, y: 0, width: weightedWidths["cues"] ?? cuesMinimumWidth, height: height)
        var languageRect: CGRect?

        for columnID in textColumnOrder {
            let width = weightedWidths[columnID] ?? 0
            switch columnID {
            case "dateAdded":
                dateAddedRect = CGRect(x: x, y: 0, width: width, height: height)
                x += width
            case "display":
                nameRect = CGRect(x: x, y: 0, width: width, height: height)
                x += width
            case "time":
                timeRect = CGRect(x: x, y: 0, width: width, height: height)
                x += width
            case "cues":
                cuesRect = CGRect(x: x, y: 0, width: width, height: height)
                x += width
            case "language":
                languageRect = CGRect(x: x, y: 0, width: width, height: height)
                x += width
            default:
                break
            }
        }

        return SubtitleTableColumnLayout(
            indexRect: indexRect,
            dateAddedRect: dateAddedRect,
            nameRect: nameRect,
            timeRect: timeRect,
            cuesRect: cuesRect,
            languageRect: languageRect,
            contentWidth: resolvedContentWidth
        )
    }

    private static func weightedWidthSpec(
        for columnID: String,
        cuesMinimumWidth: CGFloat
    ) -> WorkbenchWeightedColumnWidthSpec? {
        let M = SubtitleTableMetrics.self
        switch columnID {
        case "dateAdded":
            return WorkbenchWeightedColumnWidthSpec(
                id: columnID,
                weight: M.dateAddedColumnWeight,
                minimumWidth: M.dateAddedColumnMinimumWidth
            )
        case "display":
            return WorkbenchWeightedColumnWidthSpec(
                id: columnID,
                weight: M.displayTitleColumnWeight,
                minimumWidth: M.displayTitleColumnMinimumWidth
            )
        case "time":
            return WorkbenchWeightedColumnWidthSpec(
                id: columnID,
                weight: M.timeColumnWeight,
                minimumWidth: M.timeColumnMinimumWidth
            )
        case "cues":
            return WorkbenchWeightedColumnWidthSpec(
                id: columnID,
                weight: M.cuesColumnWeight,
                minimumWidth: cuesMinimumWidth
            )
        case "language":
            return WorkbenchWeightedColumnWidthSpec(
                id: columnID,
                weight: M.languageColumnWeight,
                minimumWidth: M.languageColumnMinimumWidth
            )
        default:
            return nil
        }
    }

    static func resolvedTextColumnOrder(
        _ columnOrder: [String],
        showsDateAddedColumn: Bool = false,
        showsDisplayTitleColumn: Bool = true,
        showsTimeColumn: Bool = false,
        showsLanguageColumn: Bool
    ) -> [String] {
        var result: [String] = []
        for columnID in columnOrder + defaultTextColumnOrder
        where !result.contains(columnID) && isTextColumnVisible(
            columnID,
            showsDateAddedColumn: showsDateAddedColumn,
            showsDisplayTitleColumn: showsDisplayTitleColumn,
            showsTimeColumn: showsTimeColumn,
            showsLanguageColumn: showsLanguageColumn
        ) {
            result.append(columnID)
        }
        return result
    }

    func rect(for columnID: String) -> CGRect? {
        switch columnID {
        case "rowNumber":
            return indexRect
        case "dateAdded":
            return dateAddedRect
        case "display":
            return nameRect
        case "time":
            return timeRect
        case "cues":
            return cuesRect
        case "language":
            return languageRect
        default:
            return nil
        }
    }

    var rowMeasurementLayoutKey: SubtitleTableRowMeasurementLayoutKey {
        SubtitleTableRowMeasurementLayoutKey(columnWidths: [
            "selection": indexRect.width,
            "dateAdded": dateAddedRect?.width,
            "display": nameRect.width > 0 ? nameRect.width : nil,
            "time": timeRect?.width,
            "cues": cuesRect.width,
            "language": languageRect?.width,
        ].compactMapValues { $0 })
    }

    private static func isTextColumnVisible(
        _ columnID: String,
        showsDateAddedColumn: Bool,
        showsDisplayTitleColumn: Bool,
        showsTimeColumn: Bool,
        showsLanguageColumn: Bool
    ) -> Bool {
        switch columnID {
        case "dateAdded":
            return showsDateAddedColumn
        case "display":
            return showsDisplayTitleColumn
        case "time":
            return showsTimeColumn
        case "cues":
            return true
        case "language":
            return showsLanguageColumn
        default:
            return false
        }
    }

    func offsetBy(dx: CGFloat) -> SubtitleTableColumnLayout {
        SubtitleTableColumnLayout(
            indexRect: indexRect.offsetBy(dx: dx, dy: 0),
            dateAddedRect: dateAddedRect?.offsetBy(dx: dx, dy: 0),
            nameRect: nameRect.offsetBy(dx: dx, dy: 0),
            timeRect: timeRect?.offsetBy(dx: dx, dy: 0),
            cuesRect: cuesRect.offsetBy(dx: dx, dy: 0),
            languageRect: languageRect?.offsetBy(dx: dx, dy: 0),
            contentWidth: contentWidth
        )
    }
}
