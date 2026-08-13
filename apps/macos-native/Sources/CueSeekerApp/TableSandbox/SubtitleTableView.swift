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
    static let checkboxSize: CGFloat = 16
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

    static func legacy(
        contentWidth: CGFloat,
        height: CGFloat,
        showsDateAddedColumn: Bool = false,
        showsDisplayTitleColumn: Bool = true,
        showsTimeColumn: Bool = false,
        showsLanguageColumn: Bool
    ) -> SubtitleTableColumnLayout {
        let M = SubtitleTableMetrics.self
        let dateAddedWidth = showsDateAddedColumn ? M.dateAddedColumnWidth : 0
        let displayTitleWidth = showsDisplayTitleColumn ? M.nameColumnWidth : 0
        let timeWidth = showsTimeColumn ? M.timeColumnWidth : 0
        let languageWidth = showsLanguageColumn ? M.languageColumnWidth : 0
        let cuesWidth = max(0, contentWidth - M.indexColumnWidth - dateAddedWidth - displayTitleWidth - timeWidth - languageWidth)
        let cuesX = M.indexColumnWidth + dateAddedWidth + displayTitleWidth + timeWidth
        let languageRect = showsLanguageColumn ? CGRect(
            x: max(cuesX, contentWidth - M.languageColumnWidth),
            y: 0,
            width: M.languageColumnWidth,
            height: height
        ) : nil
        return SubtitleTableColumnLayout(
            indexRect: CGRect(x: 0, y: 0, width: M.indexColumnWidth, height: height),
            dateAddedRect: showsDateAddedColumn ? CGRect(x: M.indexColumnWidth, y: 0, width: dateAddedWidth, height: height) : nil,
            nameRect: CGRect(x: M.indexColumnWidth + dateAddedWidth, y: 0, width: displayTitleWidth, height: height),
            timeRect: showsTimeColumn ? CGRect(x: M.indexColumnWidth + dateAddedWidth + displayTitleWidth, y: 0, width: timeWidth, height: height) : nil,
            cuesRect: CGRect(
                x: cuesX,
                y: 0,
                width: cuesWidth,
                height: height
            ),
            languageRect: languageRect,
            contentWidth: contentWidth
        )
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

struct SubtitleTableTagStyle {
    let horizontalInset: CGFloat
    let verticalInset: CGFloat
    let cornerRadius: CGFloat
    let horizontalSpacing: CGFloat
    let verticalSpacing: CGFloat
    private let fixedHeight: CGFloat?

    static func resolve(isRedesign: Bool) -> SubtitleTableTagStyle {
        let M = SubtitleTableMetrics.self
        if isRedesign {
            return SubtitleTableTagStyle(
                horizontalInset: M.tagRedesignHorizontalInset,
                verticalInset: M.tagRedesignVerticalInset,
                cornerRadius: M.tagCornerRadius,
                horizontalSpacing: M.tagHorizontalSpacing,
                verticalSpacing: M.tagVerticalSpacing,
                fixedHeight: nil
            )
        }
        return SubtitleTableTagStyle(
            horizontalInset: M.tagHorizontalInset,
            verticalInset: 0,
            cornerRadius: M.tagCornerRadius,
            horizontalSpacing: M.tagHorizontalSpacing,
            verticalSpacing: M.tagVerticalSpacing,
            fixedHeight: M.tagHeight
        )
    }

    func height(for textSize: CGSize) -> CGFloat {
        fixedHeight ?? ceil(textSize.height) + 2 * verticalInset
    }

    func width(for textSize: CGSize) -> CGFloat {
        ceil(textSize.width) + 2 * horizontalInset
    }

    func fillColor(for tag: WorkbenchTag, isRedesign: Bool, isEnabled: Bool) -> NSColor {
        guard isRedesign else { return tag.colorID.appKitFillColor }
        guard isEnabled else { return WorkbenchRedesignColors.NS.bgDisabled }
        return tag.colorID.redesignFillColor()
    }
}

private struct SubtitleTableLaidOutTag {
    let tag: WorkbenchTag
    let attributed: NSAttributedString
    let textSize: CGSize
    let tagRect: CGRect
}

private struct SubtitleTableTagLayoutResult {
    let items: [SubtitleTableLaidOutTag]
    let blockHeight: CGFloat
}

// MARK: - Typography

enum SubtitleTableTextRole {
    case primaryContent
    case secondaryContext
    case metadata
}

@MainActor
enum SubtitleTableText {
    static let legacyBodyFont = NSFont.systemFont(ofSize: 13.5, weight: .semibold)
    static let indexFont = NSFont.systemFont(ofSize: 12, weight: .regular)
    static let headerFont = NSFont.systemFont(ofSize: 13, weight: .semibold)
    static let tagFont = NSFont.systemFont(ofSize: 12, weight: .semibold)
    static let lineSpacing: CGFloat = 4

    static func bodyParagraphStyle() -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = lineSpacing
        style.lineBreakMode = .byWordWrapping
        return style
    }

    static func body(
        _ text: String,
        role: SubtitleTableTextRole = .primaryContent,
        isRedesign: Bool = false,
        foregroundColor: NSColor? = nil
    ) -> NSAttributedString {
        NSAttributedString(string: text, attributes: [
            .font: bodyFont(role: role, isRedesign: isRedesign),
            .paragraphStyle: bodyParagraphStyle(),
            .foregroundColor: foregroundColor ?? bodyColor(role: role, isRedesign: isRedesign),
        ])
    }

    static func index(_ number: Int, isRedesign: Bool = false) -> NSAttributedString {
        NSAttributedString(string: "\(number)", attributes: [
            .font: indexFont,
            .foregroundColor: isRedesign ? WorkbenchRedesignColors.NS.textMuted : NSColor.secondaryLabelColor,
        ])
    }

    static func header(_ text: String, isRedesign: Bool = false) -> NSAttributedString {
        NSAttributedString(string: text, attributes: [
            .font: isRedesign ? redesignHeaderFont : headerFont,
            .foregroundColor: isRedesign ? WorkbenchRedesignColors.NS.textSecondary : NSColor.labelColor,
        ])
    }

    private static var redesignHeaderFont: NSFont {
        NSFont.systemFont(
            ofSize: WorkbenchControlMetrics.redesignFontSizeTableHeader,
            weight: .medium
        )
    }

    private static func bodyFont(role: SubtitleTableTextRole, isRedesign: Bool) -> NSFont {
        guard isRedesign else { return legacyBodyFont }
        switch role {
        case .primaryContent:
            return NSFont.systemFont(
                ofSize: WorkbenchControlMetrics.redesignFontSizeTable,
                weight: .medium
            )
        case .secondaryContext:
            return NSFont.systemFont(
                ofSize: WorkbenchControlMetrics.redesignFontSizeTable,
                weight: .medium
            )
        case .metadata:
            return NSFont.monospacedDigitSystemFont(
                ofSize: WorkbenchControlMetrics.redesignFontSizeTable,
                weight: .medium
            )
        }
    }

    private static func bodyColor(role: SubtitleTableTextRole, isRedesign: Bool) -> NSColor {
        guard isRedesign else { return NSColor.labelColor }
        switch role {
        case .primaryContent:
            return WorkbenchRedesignColors.NS.textSecondary
        case .secondaryContext, .metadata:
            return WorkbenchRedesignColors.NS.textMuted
        }
    }

    static func tag(_ tag: WorkbenchTag, isRedesign: Bool = false, isEnabled: Bool = true) -> NSAttributedString {
        let foregroundColor: NSColor
        if isRedesign, !isEnabled {
            foregroundColor = WorkbenchRedesignColors.NS.textDisabled
        } else {
            foregroundColor = isRedesign ? WorkbenchRedesignColors.NS.textMuted : tag.colorID.appKitForegroundColor
        }
        return NSAttributedString(string: tag.label, attributes: [
            .font: tagFont,
            .foregroundColor: foregroundColor,
        ])
    }
}

// MARK: - TextKit layout

@MainActor
final class SubtitleTextLayout {
    private let textStorage = NSTextStorage()
    private let layoutManager = NSLayoutManager()
    private let textContainer = NSTextContainer()

    init(maximumNumberOfLines: Int = 0) {
        textContainer.lineFragmentPadding = 0
        textContainer.maximumNumberOfLines = maximumNumberOfLines
        layoutManager.usesFontLeading = true
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
    }

    func update(attributedString: NSAttributedString, width: CGFloat) {
        textStorage.setAttributedString(attributedString)
        textContainer.size = CGSize(width: max(0, width), height: .greatestFiniteMagnitude)
        layoutManager.ensureLayout(for: textContainer)
    }

    var usedHeight: CGFloat {
        ceil(layoutManager.usedRect(for: textContainer).height)
    }

    var utf16Length: Int {
        textStorage.length
    }

    func draw(at origin: CGPoint) {
        let glyphRange = layoutManager.glyphRange(for: textContainer)
        guard glyphRange.length > 0 else { return }
        layoutManager.drawGlyphs(forGlyphRange: glyphRange, at: origin)
    }

    func containsText(at point: CGPoint, origin: CGPoint) -> Bool {
        lineUsedRects(at: origin).contains { $0.contains(point) }
    }

    func utf16Offset(at point: CGPoint, origin: CGPoint) -> Int {
        guard textStorage.length > 0 else { return 0 }
        let validGlyphRange = layoutManager.glyphRange(for: textContainer)
        guard validGlyphRange.length > 0 else { return 0 }
        var fraction: CGFloat = 0
        let localPoint = CGPoint(x: point.x - origin.x, y: point.y - origin.y)
        let rawGlyphIndex = layoutManager.glyphIndex(
            for: localPoint,
            in: textContainer,
            fractionOfDistanceThroughGlyph: &fraction
        )
        let glyphIndex = min(
            max(rawGlyphIndex, validGlyphRange.location),
            NSMaxRange(validGlyphRange) - 1
        )
        let characterRange = layoutManager.characterRange(
            forGlyphRange: NSRange(location: glyphIndex, length: 1),
            actualGlyphRange: nil
        )
        let characterIndex = fraction >= 0.5
            ? NSMaxRange(characterRange)
            : characterRange.location
        return min(max(0, characterIndex), textStorage.length)
    }

    func selectionRects(forUTF16Range range: NSRange, at origin: CGPoint) -> [CGRect] {
        let safeRange = NSIntersectionRange(
            range,
            NSRange(location: 0, length: textStorage.length)
        )
        guard safeRange.length > 0 else { return [] }
        let glyphRange = layoutManager.glyphRange(
            forCharacterRange: safeRange,
            actualCharacterRange: nil
        )
        var rects: [CGRect] = []
        layoutManager.enumerateEnclosingRects(
            forGlyphRange: glyphRange,
            withinSelectedGlyphRange: NSRange(location: NSNotFound, length: 0),
            in: textContainer
        ) { rect, _ in
            rects.append(rect.offsetBy(dx: origin.x, dy: origin.y))
        }
        return rects
    }

    func usedRects(at origin: CGPoint) -> [CGRect] {
        lineUsedRects(at: origin)
    }

    func unionUsedRect(at origin: CGPoint) -> CGRect? {
        let rects = lineUsedRects(at: origin)
        guard var result = rects.first else { return nil }
        for rect in rects.dropFirst() {
            result = result.union(rect)
        }
        return result
    }

    func underlineRects(
        at origin: CGPoint,
        thickness: CGFloat,
        offset: CGFloat,
        backingScaleFactor: CGFloat
    ) -> [CGRect] {
        let scale = max(1, backingScaleFactor)
        let lineThickness = max(1 / scale, thickness)
        return lineGlyphRanges().compactMap { glyphRange in
            guard glyphRange.length > 0 else { return nil }
            let usedRect = layoutManager.lineFragmentUsedRect(
                forGlyphAt: glyphRange.location,
                effectiveRange: nil
            )
            guard usedRect.width > 0 else { return nil }
            let baseline = origin.y + usedRect.minY + layoutManager.location(forGlyphAt: glyphRange.location).y
            let y = pixelAligned(baseline + offset, scale: scale)
            let minX = pixelFloored(origin.x + usedRect.minX, scale: scale)
            let maxX = pixelCeiled(origin.x + usedRect.maxX, scale: scale)
            return CGRect(
                x: minX,
                y: y,
                width: max(0, maxX - minX),
                height: lineThickness
            )
        }
    }

    func drawUnderline(
        at origin: CGPoint,
        color: NSColor,
        thickness: CGFloat,
        offset: CGFloat,
        backingScaleFactor: CGFloat
    ) {
        color.setFill()
        for rect in underlineRects(
            at: origin,
            thickness: thickness,
            offset: offset,
            backingScaleFactor: backingScaleFactor
        ) where rect.width > 0 {
            rect.fill()
        }
    }

    private func lineUsedRects(at origin: CGPoint) -> [CGRect] {
        lineGlyphRanges().compactMap { glyphRange in
            guard glyphRange.length > 0 else { return nil }
            let usedRect = layoutManager.lineFragmentUsedRect(
                forGlyphAt: glyphRange.location,
                effectiveRange: nil
            )
            guard usedRect.width > 0, usedRect.height > 0 else { return nil }
            return usedRect.offsetBy(dx: origin.x, dy: origin.y)
        }
    }

    private func lineGlyphRanges() -> [NSRange] {
        let glyphRange = layoutManager.glyphRange(for: textContainer)
        guard glyphRange.length > 0 else { return [] }

        var lineRanges: [NSRange] = []
        var glyphIndex = glyphRange.location
        let glyphUpperBound = NSMaxRange(glyphRange)
        while glyphIndex < glyphUpperBound {
            var effectiveRange = NSRange(location: 0, length: 0)
            _ = layoutManager.lineFragmentUsedRect(
                forGlyphAt: glyphIndex,
                effectiveRange: &effectiveRange
            )
            let lineRange = NSIntersectionRange(effectiveRange, glyphRange)
            if lineRange.length > 0 {
                lineRanges.append(lineRange)
            }
            let nextIndex = NSMaxRange(effectiveRange)
            guard nextIndex > glyphIndex else { break }
            glyphIndex = nextIndex
        }
        return lineRanges
    }

    private func pixelAligned(_ value: CGFloat, scale: CGFloat) -> CGFloat {
        (value * scale).rounded() / scale
    }

    private func pixelFloored(_ value: CGFloat, scale: CGFloat) -> CGFloat {
        floor(value * scale) / scale
    }

    private func pixelCeiled(_ value: CGFloat, scale: CGFloat) -> CGFloat {
        ceil(value * scale) / scale
    }
}

private struct SubtitleTableTextFragmentLayout {
    let attributed: NSAttributedString
    let origin: CGPoint
    let width: CGFloat
    let clipRect: CGRect
    let logicalUTF16Range: NSRange
}

// MARK: - Hover Play/Copy buttons

private struct CueHoverButtons: View {
    var isEnabled: Bool = true
    var onPlay: () -> Void
    var onCopy: () -> Void

    @State private var isHovered = false
    @State private var hasPushedCursor = false

    var body: some View {
        HStack(spacing: 2) {
            button(title: "Play", systemImage: "play.fill", action: onPlay)
            button(title: "Copy", systemImage: "doc.on.doc", action: onCopy)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(Color(nsColor: .textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
        )
        .onHover { inside in
            isHovered = inside
            updateCursor(inside: inside)
        }
        .onChange(of: isEnabled) { newValue in
            if isHovered {
                if hasPushedCursor {
                    NSCursor.pop()
                    hasPushedCursor = false
                }
                if newValue {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.operationNotAllowed.push()
                }
                hasPushedCursor = true
            }
        }
        .onDisappear {
            if hasPushedCursor {
                NSCursor.pop()
                hasPushedCursor = false
            }
        }
    }

    private func updateCursor(inside: Bool) {
        if inside {
            if !hasPushedCursor {
                if isEnabled {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.operationNotAllowed.push()
                }
                hasPushedCursor = true
            }
        } else {
            if hasPushedCursor {
                NSCursor.pop()
                hasPushedCursor = false
            }
        }
    }

    private func button(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: systemImage)
                Text(title)
            }
            .font(.system(size: 11, weight: .medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .contentShape(Rectangle())
        }
        .buttonStyle(ToolbarButtonStyle())
    }
}

enum SubtitleTableRowActionMenuStyle {
    case search
    case shiori
}

enum SubtitleTableProbeSurface: String, CaseIterable, Sendable {
    case search
    case shiori

    init(tableName: String) {
        let normalizedName = tableName.lowercased()
        if normalizedName.contains("shiori") {
            self = .shiori
        } else {
            self = .search
        }
    }

    func counterName(_ event: String) -> String {
        "table.\(rawValue).\(event)"
    }
}

@MainActor
final class SubtitleTableRowActionSubmenuState: ObservableObject {
    static let nativeHoverDelayNanoseconds: UInt64 = 300_000_000
    static let pointerTransferGraceNanoseconds: UInt64 = 100_000_000

    @Published private(set) var highlightedParent: SubtitleTableRowAction?
    @Published private(set) var openParent: SubtitleTableRowAction?
    var onOpenParentChange: ((SubtitleTableRowAction?) -> Void)?
    private let hoverDelayNanoseconds: UInt64
    private var hoverTask: Task<Void, Never>?
    private var pointerExitTask: Task<Void, Never>?
    private var parentItemFrames: [SubtitleTableRowAction: CGRect] = [:]
    private var isParentMenuHovered = false
    private var isSubmenuHovered = false

    init(
        hoverDelayNanoseconds: UInt64 = nativeHoverDelayNanoseconds
    ) {
        self.hoverDelayNanoseconds = hoverDelayNanoseconds
    }

    func setParentHovered(_ action: SubtitleTableRowAction, isHovered: Bool) {
        guard action.opensDestinationSubmenu else {
            return
        }
        guard isHovered else {
            hoverTask?.cancel()
            hoverTask = nil
            if openParent != action, highlightedParent == action {
                highlightedParent = nil
            }
            return
        }
        hoverTask?.cancel()
        highlightedParent = action
        if openParent != action {
            updateOpenParent(nil)
        }
        if hoverDelayNanoseconds == 0 {
            updateOpenParent(action)
            return
        }
        hoverTask = Task { @MainActor [weak self] in
            guard let self else {
                return
            }
            try? await Task.sleep(nanoseconds: self.hoverDelayNanoseconds)
            guard !Task.isCancelled,
                  self.highlightedParent == action
            else {
                return
            }
            self.updateOpenParent(action)
        }
    }

    func setOtherItemHovered(_ isHovered: Bool) {
        guard isHovered else {
            return
        }
        hoverTask?.cancel()
        pointerExitTask?.cancel()
        highlightedParent = nil
        updateOpenParent(nil)
    }

    func open(_ action: SubtitleTableRowAction) {
        guard action.opensDestinationSubmenu else {
            return
        }
        hoverTask?.cancel()
        pointerExitTask?.cancel()
        highlightedParent = action
        updateOpenParent(action)
    }

    @discardableResult
    func openHighlightedParent() -> Bool {
        guard let highlightedParent else {
            return false
        }
        open(highlightedParent)
        return true
    }

    @discardableResult
    func closeSubmenu() -> Bool {
        guard openParent != nil else {
            return false
        }
        hoverTask?.cancel()
        pointerExitTask?.cancel()
        updateOpenParent(nil)
        return true
    }

    func updateParentItemFrames(
        _ frames: [SubtitleTableRowAction: CGRect]
    ) {
        guard parentItemFrames != frames else {
            return
        }
        parentItemFrames = frames
        if let openParent {
            onOpenParentChange?(openParent)
        }
    }

    func parentItemFrame(
        for action: SubtitleTableRowAction
    ) -> CGRect? {
        parentItemFrames[action]
    }

    func setParentMenuHovered(_ isHovered: Bool) {
        isParentMenuHovered = isHovered
        updatePointerTransfer()
    }

    func setSubmenuHovered(_ isHovered: Bool) {
        isSubmenuHovered = isHovered
        updatePointerTransfer()
    }

    func reset() {
        hoverTask?.cancel()
        hoverTask = nil
        pointerExitTask?.cancel()
        pointerExitTask = nil
        highlightedParent = nil
        updateOpenParent(nil)
    }

    private func updatePointerTransfer() {
        pointerExitTask?.cancel()
        pointerExitTask = nil
        guard !isParentMenuHovered,
              !isSubmenuHovered,
              openParent != nil
        else {
            return
        }
        pointerExitTask = Task { @MainActor [weak self] in
            try? await Task.sleep(
                nanoseconds: Self.pointerTransferGraceNanoseconds
            )
            guard let self,
                  !Task.isCancelled,
                  !self.isParentMenuHovered,
                  !self.isSubmenuHovered
            else {
                return
            }
            self.highlightedParent = nil
            self.updateOpenParent(nil)
        }
    }

    private func updateOpenParent(_ action: SubtitleTableRowAction?) {
        guard openParent != action else {
            return
        }
        openParent = action
        onOpenParentChange?(action)
    }
}

private enum RowActionMenuCoordinateSpace {
    static let name = "SubtitleTableRowActionMenu"
}

private struct RowActionMenuItemFramePreferenceKey: PreferenceKey {
    static let defaultValue: [SubtitleTableRowAction: CGRect] = [:]

    static func reduce(
        value: inout [SubtitleTableRowAction: CGRect],
        nextValue: () -> [SubtitleTableRowAction: CGRect]
    ) {
        value.merge(nextValue(), uniquingKeysWith: { _, newValue in
            newValue
        })
    }
}

enum SubtitleTableRowActionSubmenuGeometry {
    static let horizontalGap: CGFloat = 0

    static func frame(
        parentMenuFrame: CGRect,
        parentItemFrame: CGRect,
        submenuSize: CGSize,
        visibleRect: CGRect
    ) -> CGRect {
        let width = max(0, submenuSize.width)
        let height = max(0, submenuSize.height)

        var x = parentMenuFrame.maxX + horizontalGap
        if x + width > visibleRect.maxX {
            x = parentMenuFrame.minX - horizontalGap - width
        }
        x = max(
            visibleRect.minX,
            min(x, visibleRect.maxX - width)
        )

        let parentItemTop = parentMenuFrame.maxY - parentItemFrame.minY
        var y = parentItemTop - height
        if y < visibleRect.minY {
            y = visibleRect.minY
        }
        if y + height > visibleRect.maxY {
            y = max(visibleRect.minY, visibleRect.maxY - height)
        }

        return CGRect(x: x, y: y, width: width, height: height)
    }
}

private struct RowActionMenu: View {
    var style: SubtitleTableRowActionMenuStyle = .search
    var showsCueGroup = false
    var canOpenFolder = true
    var disabledActions: Set<SubtitleTableRowAction> = []
    let destinations: [SubtitleTableRowActionDestination]
    @ObservedObject var submenuState: SubtitleTableRowActionSubmenuState
    var onAction: (SubtitleTableRowAction) -> Void

    var body: some View {
        WorkbenchPopoverPanel(isRedesign: true) {
            VStack(spacing: 0) {
                ForEach(Array(model.elements.enumerated()), id: \.offset) { _, element in
                    switch element {
                    case .divider:
                        Divider()
                            .onHover(perform: submenuState.setOtherItemHovered)
                    case .action(let action):
                        actionRow(action)
                    }
                }
            }
        }
        .coordinateSpace(name: RowActionMenuCoordinateSpace.name)
        .onPreferenceChange(RowActionMenuItemFramePreferenceKey.self) {
            submenuState.updateParentItemFrames($0)
        }
        .onHover(perform: submenuState.setParentMenuHovered)
    }

    private var model: SubtitleTableRowActionMenuModel {
        SubtitleTableRowActionMenuModel(style: style, showsCueGroup: showsCueGroup)
    }

    private func actionRow(_ action: SubtitleTableRowAction) -> some View {
        let isSubmenuParent = action.opensDestinationSubmenu
        let isEnabled = !disabledActions.contains(action)
            && (action != .openSubtitleFolder || canOpenFolder)
            && (!isSubmenuParent || !destinations.isEmpty)
        return WorkbenchPopoverRow(
            title: action.title,
            isHighlighted: submenuState.openParent == action,
            systemImage: action.systemImage,
            isRedesign: true,
            showsCheckmarkSlot: false,
            isEnabled: isEnabled,
            action: {
                if isSubmenuParent {
                    submenuState.open(action)
                } else {
                    submenuState.reset()
                    onAction(action)
                }
            },
            trailingSystemImage: isSubmenuParent ? "chevron.right" : nil,
            onHoverChange: { isHovered in
                if isSubmenuParent, isEnabled {
                    submenuState.setParentHovered(action, isHovered: isHovered)
                } else {
                    submenuState.setOtherItemHovered(isHovered)
                }
            }
        )
        .background(
            GeometryReader { proxy in
                Color.clear.preference(
                    key: RowActionMenuItemFramePreferenceKey.self,
                    value: [
                        action: proxy.frame(
                            in: .named(RowActionMenuCoordinateSpace.name)
                        ),
                    ]
                )
            }
        )
    }
}

private struct RowActionDestinationSubmenu: View {
    let destinations: [SubtitleTableRowActionDestination]
    @ObservedObject var submenuState: SubtitleTableRowActionSubmenuState
    var onDestinationAction: (SubtitleTableRowActionDestination) -> Void

    var body: some View {
        WorkbenchPopoverPanel(isRedesign: true) {
            VStack(spacing: 0) {
                ForEach(destinations) { destination in
                    WorkbenchPopoverRow(
                        title: destination.title,
                        isRedesign: true,
                        showsCheckmarkSlot: false,
                        action: {
                            onDestinationAction(destination)
                        }
                    )
                }
            }
        }
        .onHover(perform: submenuState.setSubmenuHovered)
    }
}

private struct CueStateTip: View {
    let state: SubtitleTableCueState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color(nsColor: WorkbenchRedesignColors.NS.textPrimary))
            switch state {
            case .normal:
                EmptyView()
            case .contentChanged(let previous, let current):
                Text("This cue changed after reindexing.")
                    .foregroundStyle(Color(nsColor: WorkbenchRedesignColors.NS.textSecondary))
                value(label: "Previous", text: previous)
                value(label: "Current", text: current)
            case .unavailable:
                Text(state.unavailableMessage ?? "")
                    .foregroundStyle(Color(nsColor: WorkbenchRedesignColors.NS.textSecondary))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .font(.system(size: 12))
        .padding(12)
        .frame(width: 300, alignment: .leading)
        .background(Color(nsColor: WorkbenchRedesignColors.NS.bgPopover))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: WorkbenchRedesignColors.NS.borderMuted), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.16), radius: 12, y: 4)
    }

    private var title: String {
        switch state {
        case .normal:
            ""
        case .contentChanged:
            "Content Changed"
        case .unavailable:
            "Unavailable"
        }
    }

    private func value(label: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .foregroundStyle(Color(nsColor: WorkbenchRedesignColors.NS.textMuted))
            Text(text)
                .foregroundStyle(Color(nsColor: WorkbenchRedesignColors.NS.textSecondary))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

}

enum CueStateTipGeometry {
    static let gap: CGFloat = 8

    static func frame(
        anchor: CGRect,
        size: CGSize,
        visibleRect: CGRect
    ) -> CGRect {
        var x = anchor.maxX + gap
        if x + size.width > visibleRect.maxX {
            x = anchor.minX - gap - size.width
        }
        x = max(visibleRect.minX, min(x, visibleRect.maxX - size.width))
        let y = max(
            visibleRect.minY,
            min(
                anchor.midY - size.height / 2,
                visibleRect.maxY - size.height
            )
        )
        return CGRect(origin: CGPoint(x: x, y: y), size: size)
    }
}

private final class CueStateTipHostingView: NSHostingView<AnyView> {
    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}

final class SubtitleTableMenuOverlayView: NSView {
    var onClick: (() -> Void)?
    weak var passthroughView: NSView?
    override var isFlipped: Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? {
        if let passthroughView,
           !passthroughView.isHidden,
           passthroughView.bounds.contains(convert(point, to: passthroughView)) {
            return nil
        }
        return super.hitTest(point)
    }

    override func mouseDown(with event: NSEvent) {
        onClick?()
    }

    override func rightMouseDown(with event: NSEvent) {
        onClick?()
    }
}

final class SubtitleTableMenuHostingView: NSHostingView<AnyView> {
    var onIntrinsicContentSizeInvalidated: (() -> Void)?

    override func invalidateIntrinsicContentSize() {
        super.invalidateIntrinsicContentSize()
        onIntrinsicContentSizeInvalidated?()
    }
}

private enum WorkbenchCheckboxDrawing {
    @MainActor
    static func draw(
        state: WorkbenchCheckboxState,
        isEnabled: Bool,
        in rect: CGRect,
        isFocused: Bool = false
    ) {
        WorkbenchCheckboxStyle.drawAppKitGlyph(
            for: state,
            isEnabled: isEnabled,
            size: SubtitleTableMetrics.checkboxSize,
            in: rect
        )

        guard isFocused, isEnabled else { return }
        let focusRect = rect.insetBy(
            dx: -WorkbenchControlMetrics.redesignFocusRingPathExpansion,
            dy: -WorkbenchControlMetrics.redesignFocusRingPathExpansion
        )
        let focusPath = NSBezierPath(ovalIn: focusRect)
        WorkbenchRedesignColors.NS.focusRing.setStroke()
        focusPath.lineWidth = WorkbenchControlMetrics.redesignFocusRingWidth
        focusPath.stroke()
    }
}

private struct WorkbenchCheckboxButton: View {
    let state: WorkbenchCheckboxState
    var isEnabled: Bool = true
    var action: () -> Void

    @FocusState private var isFocused: Bool
    @State private var suppressFocusRingUntilBlur = false

    var body: some View {
        Button(action: action) {
            WorkbenchCheckboxGlyph(
                state: state,
                isEnabled: isEnabled,
                size: SubtitleTableMetrics.checkboxSize
            )
            .overlay(
                Group {
                    if showsKeyboardFocus {
                        Circle()
                        .stroke(WorkbenchRedesignColors.focusRing, lineWidth: WorkbenchControlMetrics.redesignFocusRingWidth)
                        .padding(-WorkbenchControlMetrics.redesignFocusRingPathExpansion)
                    }
                }
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .subtitleTableTextSelectionInteractiveRegion(isActive: isEnabled)
        .focused($isFocused)
        .disableFocusEffect()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in suppressFocusRingUntilBlur = true }
        )
        .onChange(of: isFocused) { focused in
            if !focused {
                suppressFocusRingUntilBlur = false
            }
        }
    }

    private var showsKeyboardFocus: Bool {
        isFocused && isEnabled && !suppressFocusRingUntilBlur
    }
}

// MARK: - Container and header

final class SubtitleTableContainerView: NSView {
    var onLayout: (() -> Void)?
    var isRedesign: Bool = false { didSet { applyAppearanceColors() } }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        applyAppearanceColors()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layout() {
        super.layout()
        onLayout?()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyAppearanceColors()
    }

    private func applyAppearanceColors() {
        guard let layer else { return }
        effectiveAppearance.performAsCurrentDrawingAppearance {
            if isRedesign {
                layer.cornerRadius = 0
                layer.borderWidth = 0
                layer.masksToBounds = false
                layer.backgroundColor = WorkbenchRedesignColors.NS.bgSurface.cgColor
            } else {
                layer.cornerRadius = SubtitleTableMetrics.cornerRadius
                layer.borderWidth = 1
                layer.masksToBounds = true
                layer.backgroundColor = NSColor.textBackgroundColor.cgColor
                layer.borderColor = NSColor.separatorColor.cgColor
            }
        }
    }
}

final class SubtitleTablePageChromeViewportView: NSView {
    weak var scrollView: NSScrollView?

    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.masksToBounds = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let hit = super.hitTest(point)
        return hit === self ? nil : hit
    }

    override func scrollWheel(with event: NSEvent) {
        scrollView?.scrollWheel(with: event)
    }
}

struct SubtitleTableScrollbarMetrics {
    typealias Axis = TableScrollbarAxis

    var viewportSize: CGSize
    var contentSize: CGSize
    var contentOffset: CGPoint

    var presentation: TableScrollbarPresentation {
        TableScrollbarPresentation(
            vertical: axisPresentation(for: .vertical),
            horizontal: axisPresentation(for: .horizontal)
        )
    }

    func isVisible(_ axis: Axis) -> Bool {
        contentLength(for: axis) > viewportLength(for: axis) + 0.5
    }

    func trackRect(for axis: Axis, in bounds: CGRect) -> CGRect? {
        TableScrollbarGeometry(presentation: presentation)
            .trackRect(for: axis, in: bounds)
    }

    func thumbRect(for axis: Axis, in bounds: CGRect) -> CGRect? {
        TableScrollbarGeometry(presentation: presentation)
            .thumbRect(for: axis, in: bounds)
    }

    func interactiveThumbRect(for axis: Axis, in bounds: CGRect) -> CGRect? {
        TableScrollbarGeometry(presentation: presentation)
            .interactiveThumbRect(for: axis, in: bounds)
    }

    func scrollOffset(
        for axis: Axis,
        thumbPosition: CGFloat,
        in bounds: CGRect
    ) -> CGFloat {
        let fraction = TableScrollbarGeometry(presentation: presentation)
            .positionFraction(
                for: axis,
                thumbPosition: thumbPosition,
                in: bounds
            )
        return scrollOffset(for: axis, positionFraction: fraction)
    }

    func scrollOffset(
        for axis: Axis,
        dragStartThumbOrigin: CGFloat,
        dragDelta: CGFloat,
        in bounds: CGRect
    ) -> CGFloat {
        let fraction = TableScrollbarGeometry(presentation: presentation)
            .positionFraction(
                for: axis,
                dragStartThumbOrigin: dragStartThumbOrigin,
                dragDelta: dragDelta,
                in: bounds
            )
        return scrollOffset(for: axis, positionFraction: fraction)
    }

    func scrollOffset(
        for axis: Axis,
        positionFraction: CGFloat
    ) -> CGFloat {
        maxScroll(for: axis) * min(1, max(0, positionFraction))
    }

    private func axisPresentation(
        for axis: Axis
    ) -> TableScrollbarAxisPresentation? {
        guard isVisible(axis) else {
            return nil
        }
        let viewportLength = viewportLength(for: axis)
        let contentLength = contentLength(for: axis)
        let maxScroll = maxScroll(for: axis)
        let offset = axis == .vertical ? contentOffset.y : contentOffset.x
        return TableScrollbarAxisPresentation(
            visibleFraction: contentLength > 0 ? viewportLength / contentLength : 1,
            positionFraction: maxScroll > 0 ? offset / maxScroll : 0
        )
    }

    private func viewportLength(for axis: Axis) -> CGFloat {
        axis == .vertical ? viewportSize.height : viewportSize.width
    }

    private func contentLength(for axis: Axis) -> CGFloat {
        axis == .vertical ? contentSize.height : contentSize.width
    }

    private func maxScroll(for axis: Axis) -> CGFloat {
        max(0, contentLength(for: axis) - viewportLength(for: axis))
    }
}

final class SubtitleTableScrollbarOverlayView: TableScrollbarOverlayView {
    weak var scrollView: NSScrollView? {
        didSet {
            scrollbarMetricsDidChange()
        }
    }

    var isRedesign: Bool {
        get { isPresented }
        set { isPresented = newValue }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        presentationProvider = { [weak self] in
            self?.metrics()?.presentation
        }
        onDrag = { [weak self] event in
            self?.handleDrag(event)
        }
        onScrollWheel = { [weak self] event in
            self?.scrollView?.scrollWheel(with: event)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func scrollMetricsDidChange() {
        scrollbarMetricsDidChange()
    }

    private func handleDrag(_ event: TableScrollbarDragEvent) {
        guard event.phase == .changed,
              let scrollView,
              let metrics = metrics()
        else {
            return
        }

        let nextOffset = metrics.scrollOffset(
            for: event.axis,
            positionFraction: event.positionFraction
        )
        var origin = scrollView.contentView.bounds.origin
        switch event.axis {
        case .vertical:
            origin.y = nextOffset
        case .horizontal:
            origin.x = nextOffset
        }
        scrollView.contentView.scroll(to: origin)
        scrollView.reflectScrolledClipView(scrollView.contentView)
        scrollbarMetricsDidChange()
    }

    private func metrics() -> SubtitleTableScrollbarMetrics? {
        guard let scrollView,
              let documentView = scrollView.documentView
        else {
            return nil
        }
        return SubtitleTableScrollbarMetrics(
            viewportSize: scrollView.contentView.bounds.size,
            contentSize: documentView.frame.size,
            contentOffset: scrollView.contentView.bounds.origin
        )
    }
}

final class SubtitleTableHeaderTextOverlayView: NSView {
    weak var coordinator: SubtitleTableView.Coordinator?

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override var isOpaque: Bool { false }

    override func resignFirstResponder() -> Bool {
        coordinator?.cancelPendingTextInteraction()
        return super.resignFirstResponder()
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard !isHidden,
              NSApp.currentEvent?.type == .leftMouseDown,
              let headerView = superview as? SubtitleVirtualTableHeaderView,
              headerView.shouldRouteTextSelectionMouseDown(
                  at: convert(point, to: headerView),
                  excluding: self
              )
        else {
            return nil
        }
        return self
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        if coordinator?.handleHeaderMouseDown(windowPoint: event.locationInWindow) == true {
            return
        }
        super.mouseDown(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        if coordinator?.handleMouseDragged(windowPoint: event.locationInWindow) == true {
            return
        }
        super.mouseDragged(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        if coordinator?.handleMouseUp(windowPoint: event.locationInWindow) == true {
            return
        }
        super.mouseUp(with: event)
    }

    @IBAction override func selectAll(_ sender: Any?) {
        coordinator?.selectAllTableText()
    }

    @IBAction func copy(_ sender: Any?) {
        coordinator?.copyTableTextSelection()
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        coordinator?.drawHeaderTextSelection(in: dirtyRect)
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }
}

final class SubtitleVirtualTableHeaderView: NSView {
    weak var coordinator: SubtitleTableView.Coordinator?
    var isRedesign: Bool = false {
        didSet {
            refreshHeaderHosts()
            needsDisplay = true
        }
    }

    private var indexHeaderHost: NSHostingView<AnyView>?
    private var dateAddedHeaderHost: NSHostingView<AnyView>?
    private var nameHeaderHost: NSHostingView<AnyView>?
    private var timeHeaderHost: NSHostingView<AnyView>?
    private var cuesHeaderHost: NSHostingView<AnyView>?
    private var languageHeaderHost: NSHostingView<AnyView>?
    private var textInteractionOverlay: SubtitleTableHeaderTextOverlayView?
    private var lastHeaderLayout: SubtitleTableColumnLayout?

    private var hoverTracking: NSTrackingArea?
    private var isHeaderHovered = false {
        didSet {
            guard isHeaderHovered != oldValue else { return }
            needsDisplay = true
        }
    }

    override var isFlipped: Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverTracking {
            removeTrackingArea(hoverTracking)
        }
        let area = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .mouseMoved, .activeInActiveApp, .inVisibleRect],
            owner: self
        )
        addTrackingArea(area)
        hoverTracking = area
        updateHoverState()
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        updateHoverState()
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        updateHoverState()
    }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        updateHoverState()
    }

    private func updateHoverState() {
        guard isRedesign, let window = window else {
            isHeaderHovered = false
            return
        }
        if let coordinator = coordinator, (coordinator.isMenuOpen || coordinator.isExternalPopupLayerOpen) {
            isHeaderHovered = false
            return
        }
        let mouseLoc = window.mouseLocationOutsideOfEventStream
        let localLoc = convert(mouseLoc, from: nil)
        isHeaderHovered = bounds.contains(localLoc)
    }

    override func draw(_ dirtyRect: NSRect) {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            super.draw(dirtyRect)
            
            if isRedesign {
                WorkbenchRedesignColors.NS.borderDivider.setStroke()
                let path = NSBezierPath()
                path.move(to: NSPoint(x: bounds.minX, y: bounds.maxY - 0.5))
                path.line(to: NSPoint(x: bounds.maxX, y: bounds.maxY - 0.5))
                path.lineWidth = 1
                path.stroke()
                return
            }

            let M = SubtitleTableMetrics.self
            let showsDateAddedColumn = coordinator?.showsDateAddedColumnForRendering() ?? false
            let showsDisplayTitleColumn = coordinator?.showsDisplayTitleColumnForRendering() ?? true
            let showsTimeColumn = coordinator?.showsTimeColumnForRendering() ?? false
            let showsLanguageColumn = coordinator?.showsLanguageColumnForRendering() ?? false
            let dateAddedWidth = showsDateAddedColumn ? M.dateAddedColumnWidth : 0
            let displayTitleWidth = showsDisplayTitleColumn ? M.nameColumnWidth : 0
            let timeWidth = showsTimeColumn ? M.timeColumnWidth : 0
            let languageWidth = showsLanguageColumn ? M.languageColumnWidth : 0
            let cuesX = M.indexColumnWidth + dateAddedWidth + displayTitleWidth + timeWidth
            drawHeader(
                "#",
                rect: CGRect(x: 0, y: 0, width: M.indexColumnWidth, height: bounds.height),
                leading: M.indexHeaderHorizontalInset,
                trailing: M.indexTrailingInset
            )
            if showsDateAddedColumn {
                drawHeader(
                    coordinator?.dateAddedHeaderForRendering() ?? "Date Added",
                    rect: CGRect(x: M.indexColumnWidth, y: 0, width: dateAddedWidth, height: bounds.height),
                    leading: M.headerHorizontalInset,
                    trailing: M.trailingInset
                )
            }
            if showsDisplayTitleColumn {
                drawHeader(
                    coordinator?.displayTitleHeaderForRendering() ?? "Name",
                    rect: CGRect(x: M.indexColumnWidth + dateAddedWidth, y: 0, width: displayTitleWidth, height: bounds.height),
                    leading: M.headerHorizontalInset,
                    trailing: M.trailingInset
                )
            }
            if showsTimeColumn {
                drawHeader(
                    coordinator?.timeHeaderForRendering() ?? "Time Range",
                    rect: CGRect(x: M.indexColumnWidth + dateAddedWidth + displayTitleWidth, y: 0, width: timeWidth, height: bounds.height),
                    leading: M.headerHorizontalInset,
                    trailing: M.trailingInset
                )
            }
            drawHeader(
                coordinator?.cuesHeaderForRendering() ?? "Cues",
                rect: CGRect(
                    x: cuesX,
                    y: 0,
                    width: max(0, bounds.width - cuesX - languageWidth),
                    height: bounds.height
                ),
                leading: M.headerHorizontalInset,
                trailing: M.trailingInset
            )
            if showsLanguageColumn {
                drawHeader(
                    coordinator?.languageHeaderForRendering() ?? "Language",
                    rect: CGRect(
                        x: max(cuesX, bounds.width - M.languageColumnWidth),
                        y: 0,
                        width: M.languageColumnWidth,
                        height: bounds.height
                    ),
                    leading: M.headerHorizontalInset,
                    trailing: M.trailingInset
                )
            }
            NSColor.separatorColor.setStroke()
            let path = NSBezierPath()
            path.move(to: NSPoint(x: bounds.minX, y: bounds.maxY - 0.5))
            path.line(to: NSPoint(x: bounds.maxX, y: bounds.maxY - 0.5))
            path.lineWidth = 0.5
            path.stroke()
        }
    }

    private func drawHeader(_ text: String, rect: CGRect, leading: CGFloat, trailing: CGFloat) {
        let attributed = SubtitleTableText.header(text, isRedesign: isRedesign)
        let size = attributed.size()
        let origin = CGPoint(
            x: rect.minX + leading,
            y: rect.minY + max(0, (rect.height - size.height) / 2)
        )
        let clipped = CGRect(
            x: origin.x,
            y: origin.y,
            width: max(0, rect.width - leading - trailing),
            height: size.height
        )
        attributed.draw(in: clipped)
    }

    override func layout() {
        super.layout()
        textInteractionOverlay?.frame = bounds
        refreshHeaderHostsForLayoutChange()
    }

    func refreshHeaderHosts() {
        updateHoverState()
        guard isRedesign else {
            indexHeaderHost?.isHidden = true
            dateAddedHeaderHost?.isHidden = true
            nameHeaderHost?.isHidden = true
            timeHeaderHost?.isHidden = true
            cuesHeaderHost?.isHidden = true
            languageHeaderHost?.isHidden = true
            textInteractionOverlay?.isHidden = true
            lastHeaderLayout = nil
            return
        }

        let layout = currentHeaderLayout()

        if coordinator?.isSelectionModeForRendering() == true {
            updateSelectionHeaderHost(&indexHeaderHost, frame: layout.indexRect)
        } else {
            updateHeaderHost(
                &indexHeaderHost,
                title: "#",
                columnID: "selection",
                isSortable: false,
                frame: layout.indexRect
            )
        }
        if let dateAddedRect = layout.dateAddedRect {
            updateHeaderHost(&dateAddedHeaderHost, title: coordinator?.dateAddedHeaderForRendering() ?? "Date Added", columnID: "dateAdded", isSortable: true, frame: dateAddedRect)
        } else {
            dateAddedHeaderHost?.isHidden = true
        }
        if coordinator?.showsDisplayTitleColumnForRendering() ?? true {
            updateHeaderHost(&nameHeaderHost, title: coordinator?.displayTitleHeaderForRendering() ?? "Name", columnID: "display", isSortable: true, frame: layout.nameRect)
        } else {
            nameHeaderHost?.isHidden = true
        }
        if let timeRect = layout.timeRect {
            updateHeaderHost(&timeHeaderHost, title: coordinator?.timeHeaderForRendering() ?? "Time Range", columnID: "time", isSortable: true, frame: timeRect)
        } else {
            timeHeaderHost?.isHidden = true
        }
        updateHeaderHost(&cuesHeaderHost, title: coordinator?.cuesHeaderForRendering() ?? "Cues", columnID: "cues", isSortable: true, frame: layout.cuesRect)

        if let languageRect = layout.languageRect {
            updateHeaderHost(&languageHeaderHost, title: coordinator?.languageHeaderForRendering() ?? "Language", columnID: "language", isSortable: true, frame: languageRect)
        } else {
            languageHeaderHost?.isHidden = true
        }

        updateHeaderKeyViewBridge()
        if coordinator?.isSelectionModeForRendering() == true {
            textInteractionOverlay?.isHidden = true
        } else {
            ensureTextInteractionOverlay()
        }
        lastHeaderLayout = layout
    }

    func refreshHeaderFramesForHorizontalScroll() {
        guard isRedesign else {
            refreshHeaderHosts()
            return
        }
        let layout = currentHeaderLayout()
        updateHeaderFrame(
            &indexHeaderHost,
            frame: layout.indexRect
        )
        updateHeaderFrame(&dateAddedHeaderHost, frame: layout.dateAddedRect)
        updateHeaderFrame(
            &nameHeaderHost,
            frame: coordinator?.showsDisplayTitleColumnForRendering() ?? true
                ? layout.nameRect
                : nil
        )
        updateHeaderFrame(&timeHeaderHost, frame: layout.timeRect)
        updateHeaderFrame(&cuesHeaderHost, frame: layout.cuesRect)
        updateHeaderFrame(&languageHeaderHost, frame: layout.languageRect)
        textInteractionOverlay?.needsDisplay = true
        lastHeaderLayout = layout
    }

    private func ensureTextInteractionOverlay() {
        let overlay: SubtitleTableHeaderTextOverlayView
        if let textInteractionOverlay {
            overlay = textInteractionOverlay
        } else {
            overlay = SubtitleTableHeaderTextOverlayView(frame: bounds)
            overlay.autoresizingMask = [.width, .height]
            overlay.coordinator = coordinator
            textInteractionOverlay = overlay
        }
        overlay.frame = bounds
        overlay.isHidden = false
        if overlay.superview == nil {
            addSubview(overlay)
        } else {
            addSubview(overlay, positioned: .above, relativeTo: nil)
        }
        overlay.needsDisplay = true
    }

    func invalidateTextSelectionOverlay() {
        textInteractionOverlay?.needsDisplay = true
    }

    func textInteractionOverlayForTesting() -> SubtitleTableHeaderTextOverlayView? {
        textInteractionOverlay
    }

    func selectionHeaderIsVisibleForTesting() -> Bool {
        coordinator?.isSelectionModeForRendering() == true
            && indexHeaderHost?.isHidden == false
    }

    func sequenceHeaderIsVisibleForTesting() -> Bool {
        coordinator?.isSelectionModeForRendering() == false
            && indexHeaderHost?.isHidden == false
    }

    func shouldRouteTextSelectionMouseDownForTesting(at point: CGPoint) -> Bool {
        guard let textInteractionOverlay else { return false }
        return shouldRouteTextSelectionMouseDown(
            at: point,
            excluding: textInteractionOverlay
        )
    }

    func shouldRouteTextSelectionMouseDown(
        at point: CGPoint,
        excluding overlay: SubtitleTableHeaderTextOverlayView
    ) -> Bool {
        guard bounds.contains(point), !overlay.isHidden else { return false }
        if coordinator?.isHeaderTextHitForInteraction(at: point) == true {
            return true
        }
        if SubtitleTableTextSelectionHitTesting.containsInteractiveRegion(
            atWindowPoint: convert(point, to: nil),
            in: self
        ) {
            return false
        }

        let wasHidden = overlay.isHidden
        overlay.isHidden = true
        defer { overlay.isHidden = wasHidden }
        return !SubtitleTableTextSelectionHitTesting.isInteractive(hitTest(point))
    }

    @IBAction override func selectAll(_ sender: Any?) {
        coordinator?.selectAllTableText()
    }

    @IBAction func copy(_ sender: Any?) {
        coordinator?.copyTableTextSelection()
    }

    private func refreshHeaderHostsForLayoutChange() {
        guard isRedesign else {
            refreshHeaderHosts()
            return
        }

        let layout = currentHeaderLayout()
        guard layout != lastHeaderLayout else { return }
        refreshHeaderHosts()
    }

    private func currentHeaderLayout() -> SubtitleTableColumnLayout {
        let M = SubtitleTableMetrics.self
        return coordinator?.headerColumnLayoutForRendering(
            viewportWidth: bounds.width,
            height: bounds.height
        ) ?? SubtitleTableColumnLayout.resolve(
            contentWidth: bounds.width,
            height: bounds.height,
            showsDateAddedColumn: false,
            showsDisplayTitleColumn: false,
            showsTimeColumn: false,
            showsLanguageColumn: false,
            cuesMinimumWidth: max(0, bounds.width - M.indexColumnWidth)
        )
    }

    private func updateHeaderFrame(
        _ hostVar: inout NSHostingView<AnyView>?,
        frame: CGRect?
    ) {
        guard let frame else {
            hostVar?.isHidden = true
            return
        }
        hostVar?.frame = frame
        hostVar?.isHidden = false
    }

    private func updateSelectionHeaderHost(
        _ hostVar: inout NSHostingView<AnyView>?,
        frame: CGRect
    ) {
        guard let coordinator else { return }
        let checkboxView = WorkbenchCheckboxButton(
            state: coordinator.selectionHeaderStateForRendering(),
            isEnabled: coordinator.canToggleSelectionForRendering(),
            action: { [weak self] in
                self?.coordinator?.toggleAllRowSelection()
            }
        )
        let anyView = AnyView(checkboxView)

        if let host = hostVar {
            host.rootView = anyView
            host.frame = frame
            host.isHidden = false
        } else {
            let host = NSHostingView(rootView: anyView)
            host.wantsLayer = true
            host.layer?.masksToBounds = false
            addSubview(host)
            hostVar = host
            host.frame = frame
            host.isHidden = false
        }
    }

    private func updateHeaderHost(
        _ hostVar: inout NSHostingView<AnyView>?,
        title: String,
        columnID: String,
        isSortable: Bool,
        frame: CGRect
    ) {
        guard let coordinator else { return }
        let sortDirection = coordinator.sortedColumnID == columnID ? coordinator.sortDirection : nil
        let isMenuOpen = coordinator.isMenuOpen && coordinator.activeHeaderMenuColumnID == columnID
        let isEnabled = coordinator.isEnabled && !coordinator.isSelectionModeForRendering()

        let cellView = SubtitleTableHeaderCellView(
            title: title,
            columnID: columnID,
            isSortable: isSortable,
            isEnabled: isEnabled,
            sortDirection: sortDirection,
            isMenuOpen: isMenuOpen,
            columnRect: frame
        ) { [weak self] rect in
            self?.coordinator?.showHeaderMenu(for: columnID, triggerFrame: rect)
        }

        let anyView = AnyView(cellView)

        if let host = hostVar {
            host.rootView = anyView
            host.frame = frame
            host.isHidden = false
        } else {
            let host = NSHostingView(rootView: anyView)
            host.wantsLayer = true
            host.layer?.masksToBounds = false
            addSubview(host)
            hostVar = host
            host.frame = frame
            host.isHidden = false
        }
    }

    func isLastInteractiveHeaderResponder(_ responder: NSResponder?) -> Bool {
        guard let host = lastInteractiveHeaderHost(), let responderView = responder as? NSView else {
            return false
        }
        return responderView === host || responderView.isDescendant(of: host)
    }

    private func updateHeaderKeyViewBridge() {
        guard let lastHost = lastInteractiveHeaderHost(), let documentView = coordinator?.documentViewForKeyboardFocusBridge() else {
            return
        }
        lastHost.nextKeyView = documentView
    }

    private func lastInteractiveHeaderHost() -> NSView? {
        if let languageHeaderHost, !languageHeaderHost.isHidden {
            return languageHeaderHost
        }
        if let cuesHeaderHost, !cuesHeaderHost.isHidden {
            return cuesHeaderHost
        }
        if let timeHeaderHost, !timeHeaderHost.isHidden {
            return timeHeaderHost
        }
        if let nameHeaderHost, !nameHeaderHost.isHidden {
            return nameHeaderHost
        }
        if let dateAddedHeaderHost, !dateAddedHeaderHost.isHidden {
            return dateAddedHeaderHost
        }
        return nil
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }
}

// MARK: - Virtual document view

final class SubtitleVirtualTableDocumentView: NSView {
    weak var coordinator: SubtitleTableView.Coordinator?
    private var hoverTracking: NSTrackingArea?
    var isRedesign: Bool = false { didSet { needsDisplay = true } }

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    override func resignFirstResponder() -> Bool {
        coordinator?.clearFocusedCheckbox()
        coordinator?.cancelPendingTextInteraction()
        return super.resignFirstResponder()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverTracking {
            removeTrackingArea(hoverTracking)
        }
        let area = NSTrackingArea(
            rect: .zero,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect],
            owner: self
        )
        addTrackingArea(area)
        hoverTracking = area
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        coordinator?.installCursorRects(in: self)
    }

    override func mouseMoved(with event: NSEvent) {
        coordinator?.handleMouseHover(windowPoint: event.locationInWindow)
        coordinator?.refreshDocumentCursor(windowPoint: event.locationInWindow)
    }

    override func mouseEntered(with event: NSEvent) {
        coordinator?.handleMouseHover(windowPoint: event.locationInWindow)
        coordinator?.refreshDocumentCursor(windowPoint: event.locationInWindow)
    }

    override func mouseExited(with event: NSEvent) {
        coordinator?.clearHover()
        NSCursor.arrow.set()
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        if coordinator?.handleMouseDown(windowPoint: event.locationInWindow) == true {
            return
        }
        coordinator?.clearFocusedCheckbox()
        super.mouseDown(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        if coordinator?.handleMouseDragged(windowPoint: event.locationInWindow) == true {
            return
        }
        super.mouseDragged(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        if coordinator?.handleMouseUp(windowPoint: event.locationInWindow) == true {
            return
        }
        super.mouseUp(with: event)
    }

    override func rightMouseDown(with event: NSEvent) {
        if coordinator?.handleRightMouseDown(windowPoint: event.locationInWindow) == true {
            return
        }
        super.rightMouseDown(with: event)
    }

    override func keyDown(with event: NSEvent) {
        if coordinator?.handleKeyDown(event) == true {
            return
        }
        super.keyDown(with: event)
    }

    @IBAction override func selectAll(_ sender: Any?) {
        coordinator?.selectAllTableText()
    }

    @IBAction func copy(_ sender: Any?) {
        coordinator?.copyTableTextSelection()
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        coordinator?.drawRows(in: dirtyRect)
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }
}

// MARK: - SwiftUI bridge

struct IsWorkbenchPopupLayerOpenKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    var isWorkbenchPopupLayerOpen: Bool {
        get { self[IsWorkbenchPopupLayerOpenKey.self] }
        set { self[IsWorkbenchPopupLayerOpenKey.self] = newValue }
    }
}

typealias SubtitleTableTextCopyRowLoader = @MainActor (Range<Int>) async -> [SubtitleTableRow]?

struct SubtitleTablePageChrome {
    let scrollableHeader: AnyView
    let pinnedHeader: AnyView
    let scrollableHeaderHeight: CGFloat
    let pinnedHeaderHeight: CGFloat
    let horizontalInset: CGFloat
    let bottomInset: CGFloat
}

struct SubtitleTablePageScrollGeometry: Equatable {
    let scrollableHeaderHeight: CGFloat
    let pinnedHeaderHeight: CGFloat
    let tableHeaderHeight: CGFloat
    let bottomInset: CGFloat

    var rowsOriginY: CGFloat {
        scrollableHeaderHeight + pinnedHeaderHeight + tableHeaderHeight
    }

    func scrollableHeaderOriginY(scrollOffset: CGFloat) -> CGFloat {
        -max(0, scrollOffset)
    }

    func pinnedHeaderOriginY(scrollOffset: CGFloat) -> CGFloat {
        max(0, scrollableHeaderHeight - max(0, scrollOffset))
    }

    func tableBodyVisibleRect(
        scrollOffset: CGFloat,
        viewportSize: CGSize
    ) -> CGRect {
        let bodyOrigin = max(0, scrollOffset)
            + pinnedHeaderOriginY(scrollOffset: scrollOffset)
            + pinnedHeaderHeight
            + tableHeaderHeight
        return CGRect(
            x: 0,
            y: bodyOrigin,
            width: max(0, viewportSize.width),
            height: max(
                0,
                viewportSize.height
                    - pinnedHeaderOriginY(scrollOffset: scrollOffset)
                    - pinnedHeaderHeight
                    - tableHeaderHeight
            )
        )
    }

    func documentHeight(rowsHeight: CGFloat, viewportHeight: CGFloat) -> CGFloat {
        max(1, viewportHeight, rowsOriginY + max(0, rowsHeight) + bottomInset)
    }

    func scrollOffsetForRow(localRowY: CGFloat, maximumOffset: CGFloat) -> CGFloat {
        min(
            max(0, maximumOffset),
            max(0, scrollableHeaderHeight + max(0, localRowY))
        )
    }
}

final class SubtitleTablePageChromeHostingView: NSHostingView<AnyView> {
    weak var scrollView: NSScrollView?

    override func scrollWheel(with event: NSEvent) {
        scrollView?.scrollWheel(with: event)
    }
}

struct SubtitleTableView: NSViewRepresentable {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.isWorkbenchPopupLayerOpen) var isWorkbenchPopupLayerOpen
    @Environment(\.subtitleTableExternalTextSelectionSession) private var externalTextSelectionSession
    var tableName: String
    var probeSurface: SubtitleTableProbeSurface = .search
    var probeScope: String?
    var rowCount: Int
    var rowProvider: (Int) -> SubtitleTableRow?
    var rowsVersion: Int
    var rowsUpdate: TableSandboxRowsUpdate
    var dateAddedHeader = "Date Added"
    var displayTitleHeader = "Name"
    var timeHeader = "Time Range"
    var cuesHeader = "Cues"
    var languageHeader = "Language"
    var columnOrder: [String] = []
    var showsDateAddedColumn = false
    var showsDisplayTitleColumn = true
    var showsTimeColumn = false
    var showsLanguageColumn = false
    var showsCueGroup = false
    var scrollResetToken = 0
    var scrollTargetRow: Int?
    var suspendsMenuOutsideClickDismiss = false
    var onVisibleRowsChange: (Range<Int>) -> Void = { _ in }
    var isSelectionMode = false
    var isRowSelected: (Int) -> Bool = { _ in false }
    var selectionHeaderState: WorkbenchCheckboxState = .unchecked
    var onToggleRowSelection: (Int) -> Void = { _ in }
    var onToggleAllSelection: () -> Void = {}
    var allResultsTextCopyRowCount: Int?
    var loadRowsForTextCopy: SubtitleTableTextCopyRowLoader?
    var onPlay: (SubtitleTableRow) -> Void
    var onOpenSubtitleFile: (String) -> Void = { path in
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }
    var rowActionMenuStyle: SubtitleTableRowActionMenuStyle = .search
    var rowActionDestinations: [SubtitleTableRowActionDestination] = []
    var onMoveShiori: (SubtitleTableRow, Int64) -> Void = { _, _ in }
    var onDuplicateShiori: (SubtitleTableRow, Int64) -> Void = { _, _ in }
    var onRemoveShiori: (SubtitleTableRow) -> Void = { _ in }
    var isRedesign: Bool = false
    var pageChrome: SubtitleTablePageChrome?

    func makeCoordinator() -> Coordinator {
        let coordinator = Coordinator(
            tableName: tableName,
            probeSurface: probeSurface,
            probeScope: probeScope,
            rowCount: rowCount,
            rowProvider: rowProvider,
            rowsVersion: rowsVersion,
            dateAddedHeader: dateAddedHeader,
            displayTitleHeader: displayTitleHeader,
            timeHeader: timeHeader,
            cuesHeader: cuesHeader,
            languageHeader: languageHeader,
            columnOrder: columnOrder,
            showsDateAddedColumn: showsDateAddedColumn,
            showsDisplayTitleColumn: showsDisplayTitleColumn,
            showsTimeColumn: showsTimeColumn,
            showsLanguageColumn: showsLanguageColumn,
            showsCueGroup: showsCueGroup,
            scrollResetToken: scrollResetToken,
            scrollTargetRow: scrollTargetRow,
            onVisibleRowsChange: onVisibleRowsChange,
            isSelectionMode: isSelectionMode,
            isRowSelected: isRowSelected,
            selectionHeaderState: selectionHeaderState,
            onToggleRowSelection: onToggleRowSelection,
            onToggleAllSelection: onToggleAllSelection,
            allResultsTextCopyRowCount: allResultsTextCopyRowCount,
            loadRowsForTextCopy: loadRowsForTextCopy,
            onPlay: onPlay,
            onOpenSubtitleFile: onOpenSubtitleFile,
            rowActionMenuStyle: rowActionMenuStyle,
            rowActionDestinations: rowActionDestinations,
            onMoveShiori: onMoveShiori,
            onDuplicateShiori: onDuplicateShiori,
            onRemoveShiori: onRemoveShiori
        )
        coordinator.isRedesign = isRedesign
        return coordinator
    }

    func makeNSView(context: Context) -> SubtitleTableContainerView {
        UIInvalidationProbe.count(
            probeSurface.counterName("native_make"),
            scope: probeScope,
            details: "table=\(tableName)"
        )
        context.coordinator.isEnabled = isEnabled
        context.coordinator.isExternalPopupLayerOpen = isWorkbenchPopupLayerOpen
        context.coordinator.suspendsMenuOutsideClickDismiss = suspendsMenuOutsideClickDismiss
        let container = SubtitleTableContainerView()

        let header = SubtitleVirtualTableHeaderView()
        header.translatesAutoresizingMaskIntoConstraints = false
        header.coordinator = context.coordinator

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.automaticallyAdjustsContentInsets = false

        let scrollbarOverlayView = SubtitleTableScrollbarOverlayView()
        scrollbarOverlayView.translatesAutoresizingMaskIntoConstraints = false
        scrollbarOverlayView.scrollView = scrollView

        let documentView = SubtitleVirtualTableDocumentView()
        documentView.coordinator = context.coordinator
        documentView.frame = CGRect(origin: .zero, size: CGSize(width: 1, height: 1))
        scrollView.documentView = documentView
        scrollView.contentView.postsBoundsChangedNotifications = true

        let pageChromeViewport: SubtitleTablePageChromeViewportView?
        if pageChrome != nil {
            let viewport = SubtitleTablePageChromeViewportView()
            viewport.translatesAutoresizingMaskIntoConstraints = false
            viewport.scrollView = scrollView
            pageChromeViewport = viewport
        } else {
            pageChromeViewport = nil
        }

        context.coordinator.attach(
            container: container,
            headerView: header,
            scrollView: scrollView,
            scrollbarOverlayView: scrollbarOverlayView,
            documentView: documentView,
            pageChromeViewport: pageChromeViewport
        )
        context.coordinator.bindExternalTextSelectionSession(externalTextSelectionSession)
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.scrollContentDidChange),
            name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView
        )

        container.addSubview(scrollView)
        if let pageChromeViewport {
            container.addSubview(pageChromeViewport)
            pageChromeViewport.addSubview(header)
        } else {
            container.addSubview(header)
        }
        container.addSubview(scrollbarOverlayView)

        let headerHeightConstraint = header.heightAnchor.constraint(equalToConstant: context.coordinator.currentHeaderHeight)
        context.coordinator.headerHeightConstraint = headerHeightConstraint

        container.isRedesign = context.coordinator.isRedesign
        header.isRedesign = context.coordinator.isRedesign
        documentView.isRedesign = context.coordinator.isRedesign

        if let pageChrome, let pageChromeViewport {
            header.translatesAutoresizingMaskIntoConstraints = true
            NSLayoutConstraint.activate([
                pageChromeViewport.topAnchor.constraint(equalTo: container.topAnchor),
                pageChromeViewport.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                pageChromeViewport.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                pageChromeViewport.bottomAnchor.constraint(equalTo: container.bottomAnchor),

                scrollView.topAnchor.constraint(equalTo: container.topAnchor),
                scrollView.leadingAnchor.constraint(
                    equalTo: container.leadingAnchor,
                    constant: pageChrome.horizontalInset
                ),
                scrollView.trailingAnchor.constraint(
                    equalTo: container.trailingAnchor,
                    constant: -pageChrome.horizontalInset
                ),
                scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor),

                scrollbarOverlayView.topAnchor.constraint(equalTo: container.topAnchor),
                scrollbarOverlayView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                scrollbarOverlayView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                scrollbarOverlayView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            ])
        } else {
            NSLayoutConstraint.activate([
                header.topAnchor.constraint(equalTo: container.topAnchor),
                header.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                header.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                headerHeightConstraint,

                scrollView.topAnchor.constraint(equalTo: header.bottomAnchor),
                scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor),

                scrollbarOverlayView.topAnchor.constraint(equalTo: scrollView.topAnchor),
                scrollbarOverlayView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
                scrollbarOverlayView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
                scrollbarOverlayView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            ])
        }

        context.coordinator.resizeDocument()
        if pageChrome != nil {
            context.coordinator.scrollToTop()
        }
        context.coordinator.refreshPageScrollPresentation()
        context.coordinator.notifyVisibleRowsChanged()
        return container
    }

    func updateNSView(_ nsView: SubtitleTableContainerView, context: Context) {
        UIInvalidationProbe.count(
            probeSurface.counterName("native_update"),
            scope: probeScope,
            details: "table=\(tableName)"
        )
        context.coordinator.isRedesign = isRedesign
        context.coordinator.isEnabled = isEnabled
        context.coordinator.isExternalPopupLayerOpen = isWorkbenchPopupLayerOpen
        context.coordinator.suspendsMenuOutsideClickDismiss = suspendsMenuOutsideClickDismiss
        context.coordinator.updatePageChrome(pageChrome)
        context.coordinator.bindExternalTextSelectionSession(externalTextSelectionSession)
        context.coordinator.update(
            tableName: tableName,
            probeSurface: probeSurface,
            probeScope: probeScope,
            rowCount: rowCount,
            rowProvider: rowProvider,
            rowsVersion: rowsVersion,
            rowsUpdate: rowsUpdate,
            dateAddedHeader: dateAddedHeader,
            displayTitleHeader: displayTitleHeader,
            timeHeader: timeHeader,
            cuesHeader: cuesHeader,
            languageHeader: languageHeader,
            columnOrder: columnOrder,
            showsDateAddedColumn: showsDateAddedColumn,
            showsDisplayTitleColumn: showsDisplayTitleColumn,
            showsTimeColumn: showsTimeColumn,
            showsLanguageColumn: showsLanguageColumn,
            showsCueGroup: showsCueGroup,
            scrollResetToken: scrollResetToken,
            scrollTargetRow: scrollTargetRow,
            onVisibleRowsChange: onVisibleRowsChange,
            isSelectionMode: isSelectionMode,
            isRowSelected: isRowSelected,
            selectionHeaderState: selectionHeaderState,
            onToggleRowSelection: onToggleRowSelection,
            onToggleAllSelection: onToggleAllSelection,
            allResultsTextCopyRowCount: allResultsTextCopyRowCount,
            loadRowsForTextCopy: loadRowsForTextCopy,
            onPlay: onPlay,
            onOpenSubtitleFile: onOpenSubtitleFile,
            rowActionMenuStyle: rowActionMenuStyle,
            rowActionDestinations: rowActionDestinations,
            onMoveShiori: onMoveShiori,
            onDuplicateShiori: onDuplicateShiori,
            onRemoveShiori: onRemoveShiori
        )
    }

    static func dismantleNSView(
        _ nsView: SubtitleTableContainerView,
        coordinator: Coordinator
    ) {
        coordinator.unbindExternalTextSelectionSession()
        coordinator.cancelPendingTextInteraction()
    }

    // MARK: Coordinator

    @MainActor
    final class Coordinator: NSObject, SubtitleTableExternalTextSelectionTarget {
        private var tableName: String
        private var probeSurface: SubtitleTableProbeSurface
        private var probeScope: String?
        private var rowCount: Int
        private var rowProvider: (Int) -> SubtitleTableRow?
        private var rowsVersion: Int
        private var dateAddedHeader: String
        private var displayTitleHeader: String
        private var timeHeader: String
        private var cuesHeader: String
        private var languageHeader: String
        private var columnOrder: [String]
        private var showsDateAddedColumn: Bool
        private var showsDisplayTitleColumn: Bool
        private var showsTimeColumn: Bool
        private var showsLanguageColumn: Bool
        private var showsCueGroup: Bool
        private var scrollResetToken: Int
        private var scrollTargetRow: Int?
        private var onVisibleRowsChange: (Range<Int>) -> Void
        private var isSelectionMode: Bool
        private var isRowSelected: (Int) -> Bool
        private var selectionHeaderState: WorkbenchCheckboxState
        private var onToggleRowSelection: (Int) -> Void
        private var onToggleAllSelection: () -> Void
        private var allResultsTextCopyRowCount: Int
        private var loadRowsForTextCopy: SubtitleTableTextCopyRowLoader?
        private var onPlay: (SubtitleTableRow) -> Void
        private var onOpenSubtitleFile: (String) -> Void
        private var rowActionMenuStyle: SubtitleTableRowActionMenuStyle
        private var rowActionDestinations: [SubtitleTableRowActionDestination]
        private var onMoveShiori: (SubtitleTableRow, Int64) -> Void
        private var onDuplicateShiori: (SubtitleTableRow, Int64) -> Void
        private var onRemoveShiori: (SubtitleTableRow) -> Void

        var isRedesign: Bool = false {
            didSet {
                guard oldValue != isRedesign else { return }
                container?.isRedesign = isRedesign
                headerView?.isRedesign = isRedesign
                documentView?.isRedesign = isRedesign
                scrollbarOverlayView?.isRedesign = isRedesign
                configureScrollbars()

                headerHeightConstraint?.constant = currentHeaderHeight
                container?.layoutSubtreeIfNeeded()
                rowMeasurementCache.removeAll()
                rowHeightCache.removeAll()
                lastRowMeasurementLayoutKey = nil
                lastNotifiedVisibleRows = nil
                resizeDocument()
                notifyVisibleRowsChanged(force: true)
                updateHoveredColumnID(nil)
                updateHoveredCueTextRow(nil)
                updateHoveredCueStateRow(nil)
                invalidateDocumentCursorRects()
                layoutHoverButtons()
                headerView?.refreshHeaderHosts()
                headerView?.needsDisplay = true
                invalidateVisibleDocument()
            }
        }

        var isEnabled: Bool = true {
            didSet {
                guard oldValue != isEnabled else { return }
                if !isEnabled {
                    clearFocusedCheckbox()
                    cancelPendingTextInteraction()
                    updateHoveredColumnID(nil)
                    updateHoveredCueTextRow(nil)
                    updateHoveredCueStateRow(nil)
                }
                invalidateDocumentCursorRects()
                layoutHoverButtons()
                headerView?.refreshHeaderHosts()
            }
        }

        var headerHeightConstraint: NSLayoutConstraint?

        var currentHeaderHeight: CGFloat {
            isRedesign ? WorkbenchControlMetrics.redesignTableHeaderHeight : SubtitleTableMetrics.headerHeight
        }

        var currentRowHeight: CGFloat {
            isRedesign ? SubtitleTableCueGeometry.minimumRowHeight : SubtitleTableMetrics.estimatedRowHeight
        }

        private weak var container: SubtitleTableContainerView?
        private weak var headerView: SubtitleVirtualTableHeaderView?
        private weak var scrollView: NSScrollView?
        private weak var scrollbarOverlayView: SubtitleTableScrollbarOverlayView?
        private weak var documentView: SubtitleVirtualTableDocumentView?
        private weak var pageChromeViewport: SubtitleTablePageChromeViewportView?
        private var pageChrome: SubtitleTablePageChrome?
        private var scrollablePageChromeHost: SubtitleTablePageChromeHostingView?
        private var pinnedPageChromeHost: SubtitleTablePageChromeHostingView?
        private var buttonsHost: NSHostingView<CueHoverButtons>?
        fileprivate var isMenuOpen = false
        private var menuHost: SubtitleTableMenuHostingView?
        private var submenuHost: SubtitleTableMenuHostingView?
        private var menuOverlayView: SubtitleTableMenuOverlayView?
        private var activeMenuAnchor: ActiveMenuAnchor?
        private var activeRowMenuRow: Int?
        private var activeRowMenuColumnID: String?
        private var activeRowMenuTarget: SubtitleTableRow?
        private var rowActionSubmenuState: SubtitleTableRowActionSubmenuState?
        private var pendingMenuReposition = false
        nonisolated(unsafe) private var menuEventMonitor: Any?
        nonisolated(unsafe) private var keyboardFocusEventMonitor: Any?
        nonisolated(unsafe) private var textCopyTask: Task<Void, Never>?
        nonisolated(unsafe) private var textDragAutoScrollTimer: Timer?
        private weak var externalTextSelectionSession: SubtitleTableExternalTextSelectionSession?

        private enum ActiveMenuAnchor {
            case row(row: Int, columnID: String, anchorFrame: CGRect, clickPointInContainer: CGPoint?)
            case header(triggerFrame: CGRect)
        }

        struct DynamicScrollAnchor {
            let primaryCueIdentity: SubtitleTablePrimaryCueIdentity
            let row: Int
            let primaryFirstLineScreenY: CGFloat
        }

        enum TableSortDirection: Equatable {
            case asc
            case desc
        }

        var sortedColumnID: String?
        var sortDirection: TableSortDirection?
        var activeHeaderMenuColumnID: String?
        var suspendsMenuOutsideClickDismiss = false
        var isExternalPopupLayerOpen = false {
            didSet {
                guard isExternalPopupLayerOpen != oldValue else { return }
                if isExternalPopupLayerOpen {
                    cancelPendingTextInteraction()
                    if isMenuOpen {
                        dismissMenu(recalculateHover: false)
                    }
                    let invalidatedRows = [
                        hoveredRow,
                        hoveredCueTextRow,
                        hoveredCueStateRow,
                        hoveredRowActionRow,
                    ]
                    hoveredRow = nil
                    hoveredColumnID = nil
                    hoveredCueTextRow = nil
                    hoveredCueStateRow = nil
                    hoveredRowActionRow = nil
                    hideCueStateTip()
                    activeRowMenuColumnID = nil
                    invalidateDocumentCursorRects()
                    buttonsHost?.isHidden = true
                    layoutHoverButtons()
                    invalidateRows(invalidatedRows)
                    headerView?.refreshHeaderHosts()
                } else {
                    invalidateDocumentCursorRects()
                    if let window = documentView?.window {
                        handleMouseHover(windowPoint: window.mouseLocationOutsideOfEventStream)
                        refreshDocumentCursor(windowPoint: window.mouseLocationOutsideOfEventStream)
                    }
                    headerView?.refreshHeaderHosts()
                }
            }
        }

        private let textLayout = SubtitleTextLayout()
        private let cueTextMeasurer = SubtitleTableCueTextMeasurer()
        private var textSelection = SubtitleTableTextSelectionState()
        private var rowMeasurementCache = SubtitleTableRowHeightCache()
        private var rowHeightCache = SubtitleVirtualRowHeightCache()
        private var lastRowMeasurementLayoutKey: SubtitleTableRowMeasurementLayoutKey?
        private var isApplyingDynamicReflow = false
        private var isResizingDocument = false
        private var measurementComputeCount = 0
        private var drawnRowCount = 0
        private var textSelectionInvalidationCount = 0
        private var hoveredRow: Int?
        private var hoveredColumnID: String?
        private var hoveredCueTextRow: Int?
        private var hoveredCueStateRow: Int?
        private var hoveredRowActionRow: Int?
        private var focusedCheckboxRow: Int?
        private var cueStateTipHost: CueStateTipHostingView?
        private var lastNotifiedVisibleRows: Range<Int>?
        private var lastHeaderHorizontalOffset: CGFloat?
        private var isScrollbarDragging = false

        private enum PendingDirectTextAction {
            case none
            case play(row: Int)
            case headerMenu(columnID: String, triggerFrame: CGRect)
        }

        private struct PendingTextInteraction {
            let startPoint: CGPoint
            let anchor: SubtitleTableTextPosition?
            let directAction: PendingDirectTextAction
            var didDrag = false
            var selectionHasBegun = false
            var latestWindowPoint: CGPoint
        }

        private var pendingTextInteraction: PendingTextInteraction?
        private static let textDragThreshold: CGFloat = 3

        private enum TextSelectionRowProjection: Equatable {
            case none
            case full
            case bounded(SubtitleTableTextPosition, SubtitleTableTextPosition)
            case from(SubtitleTableTextPosition)
            case through(SubtitleTableTextPosition)
        }

        private struct HeaderTextFragmentLayout {
            let columnID: String
            let columnIndex: Int
            let cellRect: CGRect
            let fragment: SubtitleTableTextFragmentLayout
        }

        init(
            tableName: String,
            probeSurface: SubtitleTableProbeSurface = .search,
            probeScope: String? = nil,
            rowCount: Int,
            rowProvider: @escaping (Int) -> SubtitleTableRow?,
            rowsVersion: Int,
            dateAddedHeader: String = "Date Added",
            displayTitleHeader: String = "Name",
            timeHeader: String = "Time Range",
            cuesHeader: String = "Cues",
            languageHeader: String = "Language",
            columnOrder: [String] = [],
            showsDateAddedColumn: Bool = false,
            showsDisplayTitleColumn: Bool = true,
            showsTimeColumn: Bool = false,
            showsLanguageColumn: Bool = false,
            showsCueGroup: Bool = false,
            scrollResetToken: Int = 0,
            scrollTargetRow: Int? = nil,
            onVisibleRowsChange: @escaping (Range<Int>) -> Void,
            isSelectionMode: Bool = false,
            isRowSelected: @escaping (Int) -> Bool = { _ in false },
            selectionHeaderState: WorkbenchCheckboxState = .unchecked,
            onToggleRowSelection: @escaping (Int) -> Void = { _ in },
            onToggleAllSelection: @escaping () -> Void = {},
            allResultsTextCopyRowCount: Int? = nil,
            loadRowsForTextCopy: SubtitleTableTextCopyRowLoader? = nil,
            onPlay: @escaping (SubtitleTableRow) -> Void,
            onOpenSubtitleFile: @escaping (String) -> Void = { path in
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
            },
            rowActionMenuStyle: SubtitleTableRowActionMenuStyle = .search,
            rowActionDestinations: [SubtitleTableRowActionDestination] = [],
            onMoveShiori: @escaping (SubtitleTableRow, Int64) -> Void = { _, _ in },
            onDuplicateShiori: @escaping (SubtitleTableRow, Int64) -> Void = { _, _ in },
            onRemoveShiori: @escaping (SubtitleTableRow) -> Void = { _ in }
        ) {
            self.tableName = tableName
            self.probeSurface = probeSurface
            self.probeScope = probeScope
            self.rowCount = max(0, rowCount)
            self.rowProvider = rowProvider
            self.rowsVersion = rowsVersion
            self.dateAddedHeader = dateAddedHeader
            self.displayTitleHeader = displayTitleHeader
            self.timeHeader = timeHeader
            self.cuesHeader = cuesHeader
            self.languageHeader = languageHeader
            self.columnOrder = columnOrder
            self.showsDateAddedColumn = showsDateAddedColumn
            self.showsDisplayTitleColumn = showsDisplayTitleColumn
            self.showsTimeColumn = showsTimeColumn
            self.showsLanguageColumn = showsLanguageColumn
            self.showsCueGroup = showsCueGroup
            self.scrollResetToken = scrollResetToken
            self.scrollTargetRow = scrollTargetRow
            self.onVisibleRowsChange = onVisibleRowsChange
            self.isSelectionMode = isSelectionMode
            self.isRowSelected = isRowSelected
            self.selectionHeaderState = selectionHeaderState
            self.onToggleRowSelection = onToggleRowSelection
            self.onToggleAllSelection = onToggleAllSelection
            self.allResultsTextCopyRowCount = max(0, allResultsTextCopyRowCount ?? rowCount)
            self.loadRowsForTextCopy = loadRowsForTextCopy
            self.onPlay = onPlay
            self.onOpenSubtitleFile = onOpenSubtitleFile
            self.rowActionMenuStyle = rowActionMenuStyle
            self.rowActionDestinations = rowActionDestinations
            self.onMoveShiori = onMoveShiori
            self.onDuplicateShiori = onDuplicateShiori
            self.onRemoveShiori = onRemoveShiori
        }

        deinit {
            textCopyTask?.cancel()
            textDragAutoScrollTimer?.invalidate()
            NotificationCenter.default.removeObserver(self)
            if let monitor = menuEventMonitor {
                NSEvent.removeMonitor(monitor)
            }
            if let monitor = keyboardFocusEventMonitor {
                NSEvent.removeMonitor(monitor)
            }
        }

        func attach(
            container: SubtitleTableContainerView,
            headerView: SubtitleVirtualTableHeaderView,
            scrollView: NSScrollView,
            scrollbarOverlayView: SubtitleTableScrollbarOverlayView,
            documentView: SubtitleVirtualTableDocumentView,
            pageChromeViewport: SubtitleTablePageChromeViewportView? = nil
        ) {
            self.container = container
            self.headerView = headerView
            self.scrollView = scrollView
            self.scrollbarOverlayView = scrollbarOverlayView
            self.documentView = documentView
            self.pageChromeViewport = pageChromeViewport
            headerView.coordinator = self
            headerView.isRedesign = isRedesign
            documentView.coordinator = self
            documentView.isRedesign = isRedesign
            scrollbarOverlayView.onDragStateChanged = { [weak self] isDragging in
                self?.setScrollbarDragging(isDragging)
            }
            configureScrollbars()
            updatePageChromeHosts()

            if !isRedesign {
                let buttonsHost = NSHostingView(rootView: CueHoverButtons(
                    isEnabled: isEnabled,
                    onPlay: {},
                    onCopy: {}
                ))
                buttonsHost.isHidden = true
                buttonsHost.translatesAutoresizingMaskIntoConstraints = true
                documentView.addSubview(buttonsHost)
                self.buttonsHost = buttonsHost
            }

            container.onLayout = { [weak self] in
                self?.resizeDocument()
                self?.layoutPageChrome()
                self?.repositionOpenMenu()
            }
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(appLeftMouseDown),
                name: .cueSeekerLeftMouseDown,
                object: nil
            )
            installKeyboardFocusEventMonitor()
        }

        func bindExternalTextSelectionSession(
            _ session: SubtitleTableExternalTextSelectionSession?
        ) {
            guard externalTextSelectionSession !== session else { return }
            externalTextSelectionSession?.unbind(self)
            externalTextSelectionSession = session
            session?.bind(self)
        }

        func unbindExternalTextSelectionSession() {
            externalTextSelectionSession?.unbind(self)
            externalTextSelectionSession = nil
        }

        func updatePageChrome(_ pageChrome: SubtitleTablePageChrome?) {
            let geometryChanged = self.pageChrome?.scrollableHeaderHeight
                != pageChrome?.scrollableHeaderHeight
                || self.pageChrome?.pinnedHeaderHeight
                    != pageChrome?.pinnedHeaderHeight
                || self.pageChrome?.bottomInset != pageChrome?.bottomInset
            let previousPinnedHeaderHeight = self.pageChrome?.pinnedHeaderHeight
            self.pageChrome = pageChrome
            updatePageChromeHosts()
            if geometryChanged {
                resizeDocument()
                if let previousPinnedHeaderHeight,
                   let nextPinnedHeaderHeight = pageChrome?.pinnedHeaderHeight,
                   let scrollView {
                    let offset = scrollView.contentView.bounds.minY
                    let pinThreshold = pageChrome?.scrollableHeaderHeight ?? 0
                    if offset >= pinThreshold {
                        let delta = nextPinnedHeaderHeight - previousPinnedHeaderHeight
                        let maximumY = max(
                            0,
                            (documentView?.bounds.height ?? 0)
                                - scrollView.contentView.bounds.height
                        )
                        var origin = scrollView.contentView.bounds.origin
                        origin.y = min(max(0, origin.y + delta), maximumY)
                        scrollView.contentView.scroll(to: origin)
                        scrollView.reflectScrolledClipView(scrollView.contentView)
                    }
                }
            }
            layoutPageChrome()
        }

        private var pageScrollGeometry: SubtitleTablePageScrollGeometry? {
            guard let pageChrome else { return nil }
            return SubtitleTablePageScrollGeometry(
                scrollableHeaderHeight: pageChrome.scrollableHeaderHeight,
                pinnedHeaderHeight: pageChrome.pinnedHeaderHeight,
                tableHeaderHeight: currentHeaderHeight,
                bottomInset: pageChrome.bottomInset
            )
        }

        private var rowsOriginY: CGFloat {
            pageScrollGeometry?.rowsOriginY ?? 0
        }

        private func updatePageChromeHosts() {
            guard let pageChrome,
                  let pageChromeViewport,
                  let scrollView
            else {
                scrollablePageChromeHost?.removeFromSuperview()
                pinnedPageChromeHost?.removeFromSuperview()
                scrollablePageChromeHost = nil
                pinnedPageChromeHost = nil
                return
            }

            if let scrollablePageChromeHost {
                scrollablePageChromeHost.rootView = pageChrome.scrollableHeader
            } else {
                let host = SubtitleTablePageChromeHostingView(
                    rootView: pageChrome.scrollableHeader
                )
                host.scrollView = scrollView
                pageChromeViewport.addSubview(host)
                scrollablePageChromeHost = host
            }

            if let pinnedPageChromeHost {
                pinnedPageChromeHost.rootView = pageChrome.pinnedHeader
            } else {
                let host = SubtitleTablePageChromeHostingView(
                    rootView: pageChrome.pinnedHeader
                )
                host.scrollView = scrollView
                pageChromeViewport.addSubview(host)
                pinnedPageChromeHost = host
            }

            if let headerView {
                pageChromeViewport.addSubview(headerView)
            }
            if let pinnedPageChromeHost, let scrollablePageChromeHost {
                pageChromeViewport.addSubview(
                    pinnedPageChromeHost,
                    positioned: .above,
                    relativeTo: nil
                )
                pageChromeViewport.addSubview(
                    scrollablePageChromeHost,
                    positioned: .below,
                    relativeTo: pinnedPageChromeHost
                )
            }
        }

        private func layoutPageChrome() {
            guard let pageChrome,
                  let geometry = pageScrollGeometry,
                  let container,
                  let scrollView,
                  let headerView,
                  let scrollablePageChromeHost,
                  let pinnedPageChromeHost
            else {
                return
            }

            let scrollOffset = scrollView.contentView.bounds.minY
            let inset = max(0, pageChrome.horizontalInset)
            let contentWidth = max(0, container.bounds.width - 2 * inset)
            scrollablePageChromeHost.frame = CGRect(
                x: inset,
                y: geometry.scrollableHeaderOriginY(scrollOffset: scrollOffset),
                width: contentWidth,
                height: pageChrome.scrollableHeaderHeight
            )
            let pinnedOriginY = geometry.pinnedHeaderOriginY(
                scrollOffset: scrollOffset
            )
            pinnedPageChromeHost.frame = CGRect(
                x: inset,
                y: pinnedOriginY,
                width: contentWidth,
                height: pageChrome.pinnedHeaderHeight
            )
            headerView.frame = CGRect(
                x: inset,
                y: pinnedOriginY + pageChrome.pinnedHeaderHeight,
                width: contentWidth,
                height: currentHeaderHeight
            )
        }

        func refreshPageScrollPresentation() {
            layoutPageChrome()
            scrollbarOverlayView?.scrollMetricsDidChange()
            invalidateVisibleDocument()
        }

        func update(
            tableName: String,
            probeSurface: SubtitleTableProbeSurface = .search,
            probeScope: String? = nil,
            rowCount: Int,
            rowProvider: @escaping (Int) -> SubtitleTableRow?,
            rowsVersion: Int,
            rowsUpdate: TableSandboxRowsUpdate,
            dateAddedHeader: String = "Date Added",
            displayTitleHeader: String,
            timeHeader: String = "Time Range",
            cuesHeader: String = "Cues",
            languageHeader: String = "Language",
            columnOrder: [String] = [],
            showsDateAddedColumn: Bool = false,
            showsDisplayTitleColumn: Bool = true,
            showsTimeColumn: Bool = false,
            showsLanguageColumn: Bool,
            showsCueGroup: Bool = false,
            scrollResetToken: Int,
            scrollTargetRow: Int? = nil,
            onVisibleRowsChange: @escaping (Range<Int>) -> Void,
            isSelectionMode: Bool = false,
            isRowSelected: @escaping (Int) -> Bool,
            selectionHeaderState: WorkbenchCheckboxState,
            onToggleRowSelection: @escaping (Int) -> Void,
            onToggleAllSelection: @escaping () -> Void,
            allResultsTextCopyRowCount: Int? = nil,
            loadRowsForTextCopy: SubtitleTableTextCopyRowLoader? = nil,
            onPlay: @escaping (SubtitleTableRow) -> Void,
            onOpenSubtitleFile: @escaping (String) -> Void = { path in
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
            },
            rowActionMenuStyle: SubtitleTableRowActionMenuStyle = .search,
            rowActionDestinations: [SubtitleTableRowActionDestination] = [],
            onMoveShiori: @escaping (SubtitleTableRow, Int64) -> Void = { _, _ in },
            onDuplicateShiori: @escaping (SubtitleTableRow, Int64) -> Void = { _, _ in },
            onRemoveShiori: @escaping (SubtitleTableRow) -> Void = { _ in }
        ) {
            let tableChanged = tableName != self.tableName
            self.probeSurface = probeSurface
            self.probeScope = probeScope
            let nextRowCount = max(0, rowCount)
            let rowCountChanged = nextRowCount != self.rowCount
            let rowsVersionChanged = rowsVersion != self.rowsVersion
            let rowsChanged = rowCountChanged || rowsVersionChanged
            let effectiveRowsUpdate = rowsChanged ? rowsUpdate : .none
            let cuePresentationInputChanged = showsCueGroup != self.showsCueGroup ||
                columnOrder != self.columnOrder ||
                showsDateAddedColumn != self.showsDateAddedColumn ||
                showsDisplayTitleColumn != self.showsDisplayTitleColumn ||
                showsTimeColumn != self.showsTimeColumn ||
                showsLanguageColumn != self.showsLanguageColumn
            let heightAffectingCellsWillChange: Bool
            if case .cells(let cells) = effectiveRowsUpdate {
                let heightAffectingColumnIDs: Set<String> = [
                    "dateAdded", "display", "time", "cues", "language",
                ]
                heightAffectingCellsWillChange = cells.contains {
                    heightAffectingColumnIDs.contains($0.columnID)
                }
            } else {
                heightAffectingCellsWillChange = false
            }
            let preservesReloadAnchor = !tableChanged && effectiveRowsUpdate == .reload
            let presentationAnchor = (
                cuePresentationInputChanged || preservesReloadAnchor || heightAffectingCellsWillChange
            )
                ? captureDynamicScrollAnchor()
                : nil
            self.tableName = tableName
            self.rowProvider = rowProvider
            let dateAddedChanged = dateAddedHeader != self.dateAddedHeader
            self.dateAddedHeader = dateAddedHeader
            let displayTitleChanged = displayTitleHeader != self.displayTitleHeader
            self.displayTitleHeader = displayTitleHeader
            let timeChanged = timeHeader != self.timeHeader
            self.timeHeader = timeHeader
            let cuesHeaderChanged = cuesHeader != self.cuesHeader
            self.cuesHeader = cuesHeader
            let languageHeaderChanged = languageHeader != self.languageHeader
            self.languageHeader = languageHeader
            let columnOrderChanged = columnOrder != self.columnOrder
            self.columnOrder = columnOrder
            let dateAddedColumnChanged = showsDateAddedColumn != self.showsDateAddedColumn
            self.showsDateAddedColumn = showsDateAddedColumn
            let displayTitleColumnChanged = showsDisplayTitleColumn != self.showsDisplayTitleColumn
            self.showsDisplayTitleColumn = showsDisplayTitleColumn
            let timeColumnChanged = showsTimeColumn != self.showsTimeColumn
            self.showsTimeColumn = showsTimeColumn
            let languageColumnChanged = showsLanguageColumn != self.showsLanguageColumn
            self.showsLanguageColumn = showsLanguageColumn
            let showCueGroupChanged = showsCueGroup != self.showsCueGroup
            self.showsCueGroup = showsCueGroup
            let shouldResetScroll = scrollResetToken != self.scrollResetToken
            self.scrollResetToken = scrollResetToken
            self.scrollTargetRow = scrollTargetRow
            self.onVisibleRowsChange = onVisibleRowsChange
            let selectionModeChanged = isSelectionMode != self.isSelectionMode
            self.isSelectionMode = isSelectionMode
            self.isRowSelected = isRowSelected
            let selectionHeaderChanged = selectionHeaderState != self.selectionHeaderState
            self.selectionHeaderState = selectionHeaderState
            self.onToggleRowSelection = onToggleRowSelection
            self.onToggleAllSelection = onToggleAllSelection
            self.allResultsTextCopyRowCount = max(0, allResultsTextCopyRowCount ?? rowCount)
            self.loadRowsForTextCopy = loadRowsForTextCopy
            self.onPlay = onPlay
            self.onOpenSubtitleFile = onOpenSubtitleFile
            self.rowActionMenuStyle = rowActionMenuStyle
            self.rowActionDestinations = rowActionDestinations
            self.onMoveShiori = onMoveShiori
            self.onDuplicateShiori = onDuplicateShiori
            self.onRemoveShiori = onRemoveShiori

            self.rowCount = nextRowCount
            self.rowsVersion = rowsVersion
            if rowsChanged || shouldResetScroll {
                lastNotifiedVisibleRows = nil
            }
            if let focusedCheckboxRow, focusedCheckboxRow >= nextRowCount {
                updateFocusedCheckbox(nil)
            }

            let isAppendUpdate: Bool
            if case .append = effectiveRowsUpdate {
                isAppendUpdate = true
            } else {
                isAppendUpdate = false
            }
            let resetsMeasuredGeometry = tableChanged ||
                effectiveRowsUpdate == .reload ||
                (rowCountChanged && !isAppendUpdate)
            if resetsMeasuredGeometry || cuePresentationInputChanged {
                rowMeasurementCache.removeAll()
                rowHeightCache.removeAll()
            } else if case .cells(let cells) = effectiveRowsUpdate {
                let heightAffectingColumnIDs: Set<String> = [
                    "dateAdded", "display", "time", "cues", "language",
                ]
                for cell in cells where heightAffectingColumnIDs.contains(cell.columnID) {
                    rowMeasurementCache.remove(rowIndex: cell.row)
                    rowHeightCache.removeHeight(for: cell.row)
                }
            }
            rowHeightCache.configure(rowCount: nextRowCount, defaultHeight: currentRowHeight)

            let columnVisibilityChanged = dateAddedColumnChanged || displayTitleColumnChanged || timeColumnChanged || languageColumnChanged || columnOrderChanged
            let headerTitleChanged = dateAddedChanged || displayTitleChanged || timeChanged || cuesHeaderChanged || languageHeaderChanged
            let needsDocumentResize = tableChanged || rowsChanged || columnVisibilityChanged
            let rowsUpdateInvalidatesTextSelection: Bool
            switch effectiveRowsUpdate {
            case .reload, .cells:
                rowsUpdateInvalidatesTextSelection = true
            case .none, .append:
                rowsUpdateInvalidatesTextSelection = false
            }
            if tableChanged || shouldResetScroll || rowsUpdateInvalidatesTextSelection || columnVisibilityChanged || headerTitleChanged || showCueGroupChanged || selectionModeChanged {
                clearTextSelection()
            }
            if selectionModeChanged {
                clearFocusedCheckbox()
                updateHoveredColumnID(nil)
                updateHoveredCueTextRow(nil)
                updateHoveredCueStateRow(nil)
                if isMenuOpen {
                    dismissMenu(recalculateHover: false)
                }
            }

            if needsDocumentResize {
                resizeDocument(preserving: presentationAnchor)
            }
            if showCueGroupChanged {
                UIInvalidationProbe.count(
                    probeSurface.counterName("show_cue_group_owner_update"),
                    scope: probeScope,
                    details: "table=\(tableName) enabled=\(showsCueGroup)"
                )
                reflowVisibleRows(anchor: presentationAnchor)
            }
            if rowsChanged || columnVisibilityChanged {
                if isMenuOpen {
                    repositionOpenMenu()
                }
            }
            if shouldResetScroll {
                if let scrollTargetRow {
                    scrollToRow(scrollTargetRow)
                } else {
                    scrollToTop()
                }
            } else if rowsChanged || columnVisibilityChanged {
                notifyVisibleRowsChanged(force: rowsChanged)
            }
            if showCueGroupChanged {
                invalidateVisibleDocument()
                invalidateDocumentCursorRects()
                layoutHoverButtons()
                if isMenuOpen {
                    dismissMenu(recalculateHover: false)
                }
            }
            if tableChanged || rowsChanged || columnVisibilityChanged || headerTitleChanged || selectionHeaderChanged || selectionModeChanged {
                headerView?.refreshHeaderHosts()
            }
            if columnVisibilityChanged || headerTitleChanged || selectionHeaderChanged || selectionModeChanged {
                headerView?.needsDisplay = true
            }
            if columnVisibilityChanged || selectionModeChanged {
                invalidateVisibleDocument()
            }
            invalidateRows(for: effectiveRowsUpdate, rowsChanged: rowsChanged)
            if needsDocumentResize || columnVisibilityChanged || headerTitleChanged || shouldResetScroll || selectionModeChanged {
                invalidateDocumentCursorRects()
                layoutHoverButtons()
            }
        }

        func dateAddedHeaderForRendering() -> String {
            dateAddedHeader
        }

        func displayTitleHeaderForRendering() -> String {
            displayTitleHeader
        }

        func timeHeaderForRendering() -> String {
            timeHeader
        }

        func cuesHeaderForRendering() -> String {
            cuesHeader
        }

        func languageHeaderForRendering() -> String {
            languageHeader
        }

        func showsDateAddedColumnForRendering() -> Bool {
            showsDateAddedColumn
        }

        func showsDisplayTitleColumnForRendering() -> Bool {
            showsDisplayTitleColumn
        }

        func showsTimeColumnForRendering() -> Bool {
            showsTimeColumn
        }

        func showsLanguageColumnForRendering() -> Bool {
            showsLanguageColumn
        }

        func headerColumnLayoutForRendering(viewportWidth: CGFloat, height: CGFloat) -> SubtitleTableColumnLayout {
            let offsetX = scrollView?.contentView.bounds.origin.x ?? 0
            return tableColumnLayout(
                contentWidth: tableContentWidth(
                    viewportWidth: scrollView?.contentView.bounds.width
                        ?? viewportWidth
                ),
                height: height
            ).offsetBy(dx: -offsetX)
        }

        func textForLanguageColumn(row: Int) -> String {
            if let model = rowProvider(row) {
                return model.tags.map(\.label).joined(separator: ", ")
            }
            return ""
        }

        func numberOfRowsForTesting() -> Int {
            rowCount
        }

        func rowsVersionForTesting() -> Int {
            rowsVersion
        }

        func probeSurfaceForTesting() -> SubtitleTableProbeSurface {
            probeSurface
        }

        func showsCueGroupForTesting() -> Bool {
            showsCueGroup
        }

        func quiesceForTesting() {
            cancelPendingTextInteraction()
            unbindExternalTextSelectionSession()
            NotificationCenter.default.removeObserver(self)
            removeMenuDismissMonitor()
            if let monitor = keyboardFocusEventMonitor {
                NSEvent.removeMonitor(monitor)
                keyboardFocusEventMonitor = nil
            }
            container?.onLayout = nil
        }

        func primaryCueIdentityForTesting(row: Int) -> SubtitleTablePrimaryCueIdentity? {
            rowProvider(row)?.primaryCueIdentity
        }

        func primaryCueTextForTesting(row: Int) -> String? {
            rowProvider(row)?.primaryCueText
        }

        func rowSelectionStateForTesting(row: Int) -> Bool {
            isRowSelected(row)
        }

        func focusedCheckboxRowForTesting() -> Int? {
            focusedCheckboxRow
        }

        func isMenuOpenForTesting() -> Bool {
            isMenuOpen && menuHost?.isHidden == false && menuOverlayView?.isHidden == false
        }

        func menuFrameForTesting() -> CGRect? {
            menuHost?.frame
        }

        func submenuFrameForTesting() -> CGRect? {
            guard submenuHost?.isHidden == false else {
                return nil
            }
            return submenuHost?.frame
        }

        func submenuReceivesHitForTesting(
            containerPoint: CGPoint
        ) -> Bool {
            guard let container,
                  let submenuHost,
                  !submenuHost.isHidden,
                  let hitView = container.hitTest(containerPoint)
            else {
                return false
            }
            return hitView === submenuHost
                || hitView.isDescendant(of: submenuHost)
        }

        func rowActionParentItemFrameForTesting(
            _ action: SubtitleTableRowAction
        ) -> CGRect? {
            rowActionSubmenuState?.parentItemFrame(for: action)
        }

        func openRowActionSubmenuForTesting(
            _ action: SubtitleTableRowAction
        ) {
            rowActionSubmenuState?.open(action)
        }

        func menuContainsWindowPointForTesting(_ windowPoint: CGPoint) -> Bool {
            isWindowPointInsideOpenMenu(windowPoint)
        }

        func menuOutsideClickDismissesForTesting(windowPoint: CGPoint) -> Bool {
            shouldDismissOpenMenu(isEventInContainerWindow: true, windowPoint: windowPoint)
        }

        func dataCellRectForTesting(row: Int, columnID: String) -> CGRect? {
            guard let documentView else { return nil }
            let rowRect = rectForRow(row, width: documentView.bounds.width)
            return dataCellRect(columnID: columnID, rowRect: rowRect)
        }

        func cellContentHoverFrameForTesting(row: Int, columnID: String) -> CGRect? {
            cellContentHoverFrameInContainer(for: row, columnID: columnID)
        }

        func cellContentHoverDocumentRectForTesting(row: Int, columnID: String) -> CGRect? {
            cellContentHoverRectInDocument(row: row, columnID: columnID)
        }

        func isCellHoveredForTesting(row: Int, columnID: String) -> Bool {
            isCellHovered(row: row, columnID: columnID)
        }

        func rowBackgroundColorForTesting(row: Int) -> NSColor? {
            rowBackgroundColor(row: row)
        }

        func setFocusedCheckboxRowForTesting(_ row: Int?) {
            updateFocusedCheckbox(row)
        }

        func setSelectionModeForTesting(_ isSelectionMode: Bool) {
            self.isSelectionMode = isSelectionMode
        }

        func cueTextHitTestForTesting(row: Int, point: CGPoint) -> Bool {
            isPointInCueText(row: row, point: point)
        }

        @discardableResult
        func toggleRowCheckboxFromMouseForTesting(row: Int) -> Bool {
            toggleRowCheckboxFromMouse(row: row)
        }

        func tableContentWidthForTesting(viewportWidth: CGFloat) -> CGFloat {
            tableContentWidth(viewportWidth: viewportWidth)
        }

        func interactiveCellCursorRectsForTesting() -> [CGRect] {
            guard let documentView else { return [] }
            return interactiveCellCursorRects(
                in: currentTableBodyVisibleRect,
                documentWidth: documentView.bounds.width
            )
        }

        func isInteractiveCellCursorActiveForTesting(documentPoint: CGPoint) -> Bool {
            isInteractiveCellCursorActive(at: documentPoint)
        }

        func selectableTextCursorRectsForTesting() -> [CGRect] {
            guard let documentView else { return [] }
            return selectableTextCursorRects(
                in: currentTableBodyVisibleRect,
                documentWidth: documentView.bounds.width
            )
        }

        func isSelectableTextCursorActiveForTesting(documentPoint: CGPoint) -> Bool {
            isSelectableTextCursorActive(at: documentPoint)
        }

        func selectableTextForTesting(row: Int, columnID: String) -> String? {
            rowProvider(row).map { selectableText(for: columnID, model: $0) }
        }

        func textPositionForTesting(
            row: Int,
            columnID: String,
            point: CGPoint,
            requiresTextHit: Bool = true
        ) -> SubtitleTableTextPosition? {
            textPosition(
                row: row,
                columnID: columnID,
                point: point,
                requiresTextHit: requiresTextHit
            )
        }

        func textFragmentInfoForTesting(
            row: Int,
            columnID: String
        ) -> [(logicalRange: NSRange, textBounds: CGRect, clipRect: CGRect)] {
            guard let documentView else { return [] }
            let rowRect = rectForRow(row, width: documentView.bounds.width)
            return textFragments(row: row, columnID: columnID, rowRect: rowRect).map {
                (
                    logicalRange: $0.logicalUTF16Range,
                    textBounds: textBounds(for: $0),
                    clipRect: $0.clipRect
                )
            }
        }

        func cueTextFragmentInfoForTesting(
            row: Int,
            measurement: SubtitleTableRowMeasurement
        ) -> [(logicalRange: NSRange, textBounds: CGRect, clipRect: CGRect)] {
            guard let documentView,
                  let model = rowProvider(row)
            else {
                return []
            }
            let rowRect = rectForRow(row, width: documentView.bounds.width)
            guard let cellRect = dataCellRect(columnID: "cues", rowRect: rowRect) else {
                return []
            }
            return cueTextFragments(
                model: model,
                in: cellRect,
                measurement: measurement
            ).map {
                (
                    logicalRange: $0.logicalUTF16Range,
                    textBounds: textBounds(for: $0),
                    clipRect: $0.clipRect
                )
            }
        }

        func headerTextFragmentInfoForTesting() -> [(
            columnID: String,
            columnIndex: Int,
            textBounds: CGRect,
            clipRect: CGRect
        )] {
            headerTextFragments().map {
                (
                    columnID: $0.columnID,
                    columnIndex: $0.columnIndex,
                    textBounds: textBounds(for: $0.fragment),
                    clipRect: $0.fragment.clipRect
                )
            }
        }

        func headerTextPositionForTesting(
            point: CGPoint,
            requiresTextHit: Bool = true
        ) -> SubtitleTableTextPosition? {
            headerTextPosition(at: point, requiresTextHit: requiresTextHit)
        }

        func headerTextSelectionRectsForTesting(columnID: String) -> [CGRect] {
            guard let item = headerTextFragments().first(where: { $0.columnID == columnID }),
                  let selectedRange = textSelection.selectedUTF16Range(
                      row: .header,
                      columnIndex: item.columnIndex,
                      utf16Length: item.fragment.logicalUTF16Range.length
                  )
            else {
                return []
            }
            textLayout.update(
                attributedString: item.fragment.attributed,
                width: item.fragment.width
            )
            return textLayout.selectionRects(
                forUTF16Range: selectedRange,
                at: item.fragment.origin
            ).compactMap {
                let clipped = $0.intersection(item.fragment.clipRect)
                return clipped.isNull || clipped.width <= 0 || clipped.height <= 0
                    ? nil
                    : clipped
            }
        }

        func textSelectionRangeForTesting(row: Int, columnID: String) -> NSRange? {
            guard let model = rowProvider(row) else { return nil }
            return selectedUTF16Range(
                row: row,
                columnID: columnID,
                text: selectableText(for: columnID, model: model)
            )
        }

        func textSelectionRectsForTesting(row: Int, columnID: String) -> [CGRect] {
            guard let documentView,
                  let selectedRange = textSelectionRangeForTesting(row: row, columnID: columnID)
            else {
                return []
            }
            let rowRect = rectForRow(row, width: documentView.bounds.width)
            return textFragments(row: row, columnID: columnID, rowRect: rowRect).flatMap { fragment -> [CGRect] in
                textLayout.update(attributedString: fragment.attributed, width: fragment.width)
                guard let localRange = localSelectionRange(
                    selectedRange,
                    in: fragment.logicalUTF16Range
                ) else {
                    return []
                }
                return textLayout.selectionRects(forUTF16Range: localRange, at: fragment.origin).compactMap {
                    let clipped = $0.intersection(fragment.clipRect)
                    return clipped.isNull || clipped.width <= 0 || clipped.height <= 0
                        ? nil
                        : clipped
                }
            }
        }

        func clearTextSelectionForTesting() {
            clearTextSelection()
        }

        func textSelectionInvalidationCountForTesting() -> Int {
            textSelectionInvalidationCount
        }

        func resetTextSelectionInvalidationCountForTesting() {
            textSelectionInvalidationCount = 0
        }

        func textSelectionSelectsAllForTesting() -> Bool {
            textSelection.selectsAllResults
        }

        func pendingTextSelectionHasBegunForTesting() -> Bool {
            pendingTextInteraction?.selectionHasBegun == true
        }

        func documentTextPositionForTesting(
            point: CGPoint,
            requiresTextHit: Bool = true
        ) -> SubtitleTableTextPosition? {
            textPosition(atDocumentPoint: point, requiresTextHit: requiresTextHit)
        }

        func waitForTextCopyForTesting() async {
            await textCopyTask?.value
        }

        func cancelPendingTextInteraction() {
            stopTextDragAutoScroll()
            pendingTextInteraction = nil
        }

        var externalTextSelectionWindowRect: CGRect? {
            guard let container, container.window != nil else { return nil }
            return container.convert(container.bounds, to: nil)
        }

        var canBeginExternalTextSelection: Bool {
            isRedesign &&
                isEnabled &&
                !isSelectionMode &&
                pendingTextInteraction == nil &&
                container != nil &&
                container?.window != nil &&
                documentView != nil &&
                headerView != nil &&
                !visibleTextColumnOrder().isEmpty
        }

        func beginExternalTextSelection(
            startWindowPoint: CGPoint,
            currentWindowPoint: CGPoint
        ) -> Bool {
            guard canBeginExternalTextSelection,
                  externalTextSelectionWindowRect?.contains(currentWindowPoint) == true,
                  let anchor = textPosition(
                      atWindowPoint: startWindowPoint,
                      requiresTextHit: false
                  )
            else {
                return false
            }

            clearFocusedCheckbox()
            documentView?.window?.makeFirstResponder(documentView)
            var interaction = PendingTextInteraction(
                startPoint: startWindowPoint,
                anchor: anchor,
                directAction: .none,
                didDrag: true,
                latestWindowPoint: currentWindowPoint
            )
            beginPendingTextSelectionIfPossible(&interaction)
            guard interaction.selectionHasBegun else { return false }
            pendingTextInteraction = interaction
            updateTextSelectionFocus(atWindowPoint: currentWindowPoint)
            updateTextDragAutoScrollState(for: interaction)
            return true
        }

        func updateExternalTextSelection(windowPoint: CGPoint) -> Bool {
            handleMouseDragged(windowPoint: windowPoint)
        }

        func endExternalTextSelection(windowPoint: CGPoint) -> Bool {
            handleMouseUp(windowPoint: windowPoint)
        }

        func cancelExternalTextSelection() {
            cancelPendingTextInteraction()
        }

        private func startTextDragAutoScrollIfNeeded() {
            guard textDragAutoScrollTimer == nil else { return }
            let timer = Timer(
                timeInterval: 1.0 / 30.0,
                target: self,
                selector: #selector(textDragAutoScrollTick),
                userInfo: nil,
                repeats: true
            )
            textDragAutoScrollTimer = timer
            RunLoop.main.add(timer, forMode: .common)
        }

        private func updateTextDragAutoScrollState(
            for interaction: PendingTextInteraction
        ) {
            guard let target = textDragAutoScrollTarget(for: interaction),
                  target.nextOrigin != target.currentOrigin
            else {
                stopTextDragAutoScroll()
                return
            }
            startTextDragAutoScrollIfNeeded()
        }

        private func stopTextDragAutoScroll() {
            textDragAutoScrollTimer?.invalidate()
            textDragAutoScrollTimer = nil
        }

        @objc private func textDragAutoScrollTick() {
            guard let interaction = pendingTextInteraction,
                  interaction.didDrag,
                  interaction.selectionHasBegun,
                  interaction.anchor != nil,
                  let scrollView
            else {
                stopTextDragAutoScroll()
                return
            }
            if documentView?.window != nil, NSEvent.pressedMouseButtons & 1 == 0 {
                cancelPendingTextInteraction()
                return
            }
            guard let target = textDragAutoScrollTarget(for: interaction),
                  target.nextOrigin != target.currentOrigin
            else {
                stopTextDragAutoScroll()
                return
            }
            let clipView = scrollView.contentView
            clipView.scroll(to: target.nextOrigin)
            scrollView.reflectScrolledClipView(clipView)
            refreshHeaderForHorizontalScrollIfNeeded()
            scrollbarOverlayView?.scrollMetricsDidChange()
            notifyVisibleRowsChanged()
            updateTextSelectionFocus(atWindowPoint: interaction.latestWindowPoint)
        }

        private func textDragAutoScrollTarget(
            for interaction: PendingTextInteraction
        ) -> (currentOrigin: CGPoint, nextOrigin: CGPoint)? {
            guard interaction.didDrag,
                  interaction.selectionHasBegun,
                  interaction.anchor != nil,
                  let scrollView,
                  let documentView
            else {
                return nil
            }
            let clipView = scrollView.contentView
            let viewport = clipView.convert(clipView.bounds, to: nil)
            let allowsVerticalScrolling: Bool
            if interaction.anchor?.row == .header,
               let headerView
            {
                let headerRect = headerView.convert(headerView.bounds, to: nil)
                allowsVerticalScrolling = interaction.latestWindowPoint.y < headerRect.minY
            } else {
                allowsVerticalScrolling = true
            }
            let currentOrigin = clipView.bounds.origin
            return (
                currentOrigin,
                SubtitleTableTextDragAutoScrollGeometry.nextOrigin(
                    pointer: interaction.latestWindowPoint,
                    viewport: viewport,
                    currentOrigin: currentOrigin,
                    contentSize: documentView.bounds.size,
                    viewportSize: clipView.bounds.size,
                    allowsVerticalScrolling: allowsVerticalScrolling
                )
            )
        }

        private func updateTextSelectionFocus(atWindowPoint windowPoint: CGPoint) {
            guard let focus = textPosition(
                atWindowPoint: windowPoint,
                requiresTextHit: false
            ) else {
                return
            }
            let previousSelection = textSelection
            textSelection.updateFocus(to: focus)
            invalidateTextSelectionChange(from: previousSelection)
        }

        func textDragAutoScrollTickForTesting() {
            textDragAutoScrollTick()
        }

        func copyCellTextForTesting(row: Int, columnID: String) {
            copyCellText(row: row, columnID: columnID)
        }

        func copyCueTextForTesting(row: Int) {
            copyRow(row)
        }

        func copyDeepLinkForTesting(row: Int) {
            guard let model = rowProvider(row) else { return }
            copyDeepLink(target: model)
        }

        func copyCueGroupTextForTesting(row: Int) {
            copyCueGroup(row)
        }

        func rowMenuElementsForTesting() -> [SubtitleTableRowActionMenuElement] {
            SubtitleTableRowActionMenuModel(
                style: rowActionMenuStyle,
                showsCueGroup: showsCueGroup
            ).elements
        }

        func rowMenuItemsForTesting() -> [(title: String, systemImage: String)] {
            SubtitleTableRowActionMenuModel(
                style: rowActionMenuStyle,
                showsCueGroup: showsCueGroup
            ).actions.map { ($0.title, $0.systemImage) }
        }

        func performRowActionForTesting(_ action: SubtitleTableRowAction, row: Int) {
            performRowAction(action, row: row)
        }

        func performActiveRowMenuActionForTesting(_ action: SubtitleTableRowAction) {
            performActiveRowMenuAction(action, recalculateHover: false)
        }

        func performActiveRowMenuDestinationActionForTesting(
            _ action: SubtitleTableRowAction,
            destinationID: Int64
        ) {
            performActiveRowMenuDestinationAction(
                action,
                destinationID: destinationID,
                recalculateHover: false
            )
        }

        func activeRowMenuTargetForTesting() -> SubtitleTableRow? {
            activeRowMenuTarget
        }

        func rowHeightForTesting(_ row: Int) -> CGFloat {
            rowHeightCache.height(for: row)
        }

        func checkboxRectForTesting(row: Int) -> CGRect? {
            guard let documentView,
                  row >= 0,
                  row < rowCount
            else {
                return nil
            }
            let rowRect = rectForRow(row, width: documentView.bounds.width)
            return checkboxRect(forRowRect: rowRect)
        }

        func rowYOffsetForTesting(_ row: Int) -> CGFloat {
            rowDocumentY(for: row)
        }

        func totalRowsHeightForTesting() -> CGFloat {
            rowHeightCache.totalHeight
        }

        func primaryFirstLineScreenYForTesting(row: Int) -> CGFloat? {
            guard let scrollView,
                  let documentView,
                  let measurement = cachedMeasurement(for: row, documentWidth: documentView.bounds.width)
            else {
                return nil
            }
            return rowHeightCache.yOffset(for: row)
                + rowsOriginY
                + measurement.primaryFirstLineOffset
                - scrollView.contentView.bounds.minY
        }

        func measurementComputeCountForTesting() -> Int {
            measurementComputeCount
        }

        func retainedRowMeasurementCountForTesting() -> Int {
            rowMeasurementCache.count
        }

        func resetMeasurementComputeCountForTesting() {
            measurementComputeCount = 0
        }

        func drawnRowCountForTesting() -> Int {
            drawnRowCount
        }

        func resetDrawnRowCountForTesting() {
            drawnRowCount = 0
        }

        func drawingRowRangeForTesting(dirtyRect: CGRect) -> Range<Int>? {
            let viewportDirtyRect = dirtyRect.intersection(currentTableBodyVisibleRect)
            guard !viewportDirtyRect.isNull else { return nil }
            return visibleRowRange(in: viewportDirtyRect)
        }

        func measurementRowRangeForTesting() -> Range<Int>? {
            guard let scrollView else { return nil }
            return measurementRowRange(in: tableBodyVisibleRect(for: scrollView))
        }

        func openSubtitleFileForTesting(row: Int) {
            openSubtitleFile(row: row)
        }

        func selectionHeaderStateForRendering() -> WorkbenchCheckboxState {
            selectionHeaderState
        }

        func isSelectionModeForRendering() -> Bool {
            isSelectionMode
        }

        func canToggleSelectionForRendering() -> Bool {
            isEnabled && isSelectionMode && rowCount > 0
        }

        func usesOverlayScrollbarsForTesting() -> Bool {
            scrollbarOverlayView?.isRedesign == true &&
                scrollView?.hasVerticalScroller == false &&
                scrollView?.hasHorizontalScroller == false
        }

        func pageChromeFramesForTesting() -> (
            scrollable: CGRect,
            pinned: CGRect,
            tableHeader: CGRect,
            scrollbarOverlay: CGRect
        )? {
            guard let scrollablePageChromeHost,
                  let pinnedPageChromeHost,
                  let headerView,
                  let scrollbarOverlayView
            else {
                return nil
            }
            return (
                scrollablePageChromeHost.frame,
                pinnedPageChromeHost.frame,
                headerView.frame,
                scrollbarOverlayView.frame
            )
        }

        func rowActionButtonFrameForTesting(row: Int) -> CGRect? {
            rowActionButtonFrameInContainer(for: row)
        }

        func rowActionButtonDocumentFrameForTesting(row: Int) -> CGRect? {
            rowActionButtonFrameInDocument(for: row)
        }

        func rowActionButtonHitTestForTesting(row: Int, point: CGPoint) -> Bool {
            isPointInRowActionButton(row: row, point: point)
        }

        func documentViewForKeyboardFocusBridge() -> NSView? {
            documentView
        }

        private func configureScrollbars() {
            guard let scrollView else { return }
            if isRedesign {
                scrollView.hasVerticalScroller = false
                scrollView.hasHorizontalScroller = false
                scrollView.autohidesScrollers = true
            } else {
                scrollView.hasVerticalScroller = true
                scrollView.hasHorizontalScroller = false
                scrollView.autohidesScrollers = true
            }
            scrollbarOverlayView?.isRedesign = isRedesign
            scrollbarOverlayView?.isHidden = !isRedesign
            scrollbarOverlayView?.needsDisplay = true
            if !isRedesign {
                setScrollbarDragging(false)
            }
        }

        func toggleAllRowSelection() {
            guard isEnabled, isSelectionMode, rowCount > 0 else { return }
            onToggleAllSelection()
            headerView?.refreshHeaderHosts()
            invalidateVisibleDocument()
        }

        func cellFullText(row: Int, column: Int) -> String {
            if row == -1 {
                var headers = ["#"]
                for columnID in visibleTextColumnOrder() {
                    headers.append(headerTitle(for: columnID))
                }
                return headers.indices.contains(column) ? headers[column] : ""
            }
            guard row >= 0, row < rowCount else { return "" }
            guard column != 0 else { return "\(row + 1)" }
            guard let model = rowProvider(row) else { return "" }
            let textColumns = visibleTextColumnOrder()
            let textColumnIndex = column - 1
            guard textColumns.indices.contains(textColumnIndex) else { return "" }
            return text(for: textColumns[textColumnIndex], model: model)
        }

        func resizeDocument(preserving preservedAnchor: DynamicScrollAnchor? = nil) {
            guard !isResizingDocument, let scrollView, let documentView else { return }
            isResizingDocument = true
            defer { isResizingDocument = false }

            rowHeightCache.configure(rowCount: rowCount, defaultHeight: currentRowHeight)
            let viewportWidth = max(scrollView.contentSize.width, scrollView.bounds.width)
            let width = isRedesign
                ? tableContentWidth(viewportWidth: viewportWidth)
                : max(scrollView.contentSize.width, scrollView.bounds.width)
            let oldSize = documentView.frame.size
            let oldLayout = isRedesign
                ? tableColumnLayout(contentWidth: max(1, oldSize.width), height: currentRowHeight)
                : nil
            let newLayout = isRedesign
                ? tableColumnLayout(contentWidth: width, height: currentRowHeight)
                : nil
            let nextRowMeasurementLayoutKey = newLayout?.rowMeasurementLayoutKey
            let rowMeasurementLayoutChanged = isRedesign &&
                lastRowMeasurementLayoutKey != nil &&
                lastRowMeasurementLayoutKey != nextRowMeasurementLayoutKey
            let anchor = preservedAnchor ?? (rowMeasurementLayoutChanged ? captureDynamicScrollAnchor() : nil)
            if rowMeasurementLayoutChanged {
                UIInvalidationProbe.mark(
                    "ACTION UI.SubtitleTable.\(probeSurface.rawValue).width_reflow",
                    scope: probeScope,
                    details: "table=\(tableName)"
                )
                UIInvalidationProbe.count(
                    probeSurface.counterName("width_reflow_owner_update"),
                    scope: probeScope,
                    details: "table=\(tableName)"
                )
                rowMeasurementCache.removeAll()
                rowHeightCache.removeAll()
            }
            if isRedesign {
                lastRowMeasurementLayoutKey = nextRowMeasurementLayoutKey
            }

            let nextSize = CGSize(
                width: width,
                height: pageScrollGeometry?.documentHeight(
                    rowsHeight: rowHeightCache.totalHeight,
                    viewportHeight: scrollView.contentSize.height
                ) ?? max(1, scrollView.contentSize.height, rowHeightCache.totalHeight)
            )
            scrollbarOverlayView?.needsDisplay = true
            let sizeChanged = documentView.frame.size != nextSize
            if sizeChanged {
                documentView.setFrameSize(nextSize)
            }
            clampHorizontalScrollOffset(contentWidth: width)
            if isRedesign {
                reflowVisibleRows(anchor: anchor)
            }
            scrollbarOverlayView?.scrollMetricsDidChange()
            if rowMeasurementLayoutChanged,
               let oldLayout,
               let newLayout {
                invalidateColumnLayoutChange(
                    oldLayout: oldLayout,
                    newLayout: newLayout
                )
                headerView?.refreshHeaderHosts()
                refreshHeaderForHorizontalScrollIfNeeded()
            } else if oldSize.width != nextSize.width {
                refreshHeaderForHorizontalScrollIfNeeded(force: true)
            } else {
                refreshHeaderForHorizontalScrollIfNeeded()
            }
            invalidateDocumentCursorRects()
        }

        func notifyVisibleRowsChanged(force: Bool = false) {
            guard !isExternalPopupLayerOpen else { return }
            if isRedesign {
                reflowVisibleRows()
            }
            guard let scrollView,
                  let range = measurementRowRange(
                    in: tableBodyVisibleRect(for: scrollView)
                  )
            else { return }
            // Reflow can temporarily move the clip view while preserving a
            // primary-Cue anchor. Prune only after the visible range settles,
            // otherwise a second layout pass can lose that anchor measurement.
            rowMeasurementCache.retain(rowIndices: range)
            guard force || range != lastNotifiedVisibleRows else { return }
            lastNotifiedVisibleRows = range
            onVisibleRowsChange(range)
        }

        func scrollToTop() {
            guard let scrollView else {
                return
            }

            scrollView.contentView.scroll(to: CGPoint(
                x: 0,
                y: 0
            ))
            scrollView.reflectScrolledClipView(scrollView.contentView)
            layoutPageChrome()
            invalidateVisibleDocument()
            scrollbarOverlayView?.needsDisplay = true
            invalidateDocumentCursorRects()
            notifyVisibleRowsChanged(force: true)
        }

        func scrollToRow(_ row: Int) {
            guard let scrollView, let documentView else {
                return
            }

            let clampedRow = min(max(0, row), max(0, rowCount - 1))
            if isRedesign {
                reflowVisibleRows(explicitTargetRow: clampedRow)
            }
            let maxY = max(0, documentView.bounds.height - scrollView.contentView.bounds.height)
            let localRowY = rowHeightCache.yOffset(for: clampedRow)
            let y = pageScrollGeometry?.scrollOffsetForRow(
                localRowY: localRowY,
                maximumOffset: maxY
            ) ?? min(localRowY, maxY)
            var origin = scrollView.contentView.bounds.origin
            origin.y = y
            scrollView.contentView.scroll(to: origin)
            scrollView.reflectScrolledClipView(scrollView.contentView)
            layoutPageChrome()
            documentView.setNeedsDisplay(documentView.visibleRect)
            scrollbarOverlayView?.needsDisplay = true
            invalidateDocumentCursorRects()
            notifyVisibleRowsChanged(force: true)
        }

        func verticalScrollOffsetForTesting() -> CGFloat {
            scrollView?.contentView.bounds.origin.y ?? 0
        }

        private func clampHorizontalScrollOffset(contentWidth: CGFloat) {
            guard let scrollView else { return }
            let maxX = max(0, contentWidth - scrollView.contentView.bounds.width)
            var origin = scrollView.contentView.bounds.origin
            let clampedX = min(max(0, origin.x), maxX)
            guard abs(clampedX - origin.x) > 0.5 else { return }
            origin.x = clampedX
            scrollView.contentView.scroll(to: origin)
            scrollView.reflectScrolledClipView(scrollView.contentView)
            invalidateDocumentCursorRects()
        }

        @objc func scrollContentDidChange() {
            updateHoveredCueStateRow(nil)
            layoutPageChrome()
            notifyVisibleRowsChanged()
            scrollbarOverlayView?.scrollMetricsDidChange()
            refreshHeaderForHorizontalScrollIfNeeded()
            invalidateDocumentCursorRects()
            if isMenuOpen {
                repositionOpenMenu()
                layoutHoverButtons()
            } else if !isScrollbarDragging {
                layoutHoverButtons()
            }
        }

        private func tableContentWidth(viewportWidth: CGFloat) -> CGFloat {
            let cuesMinimumWidth = isRedesign ? SubtitleTableMetrics.cuesColumnMinimumWidth : 0
            let minimumWidth = SubtitleTableColumnLayout.minimumContentWidth(
                showsDateAddedColumn: showsDateAddedColumn,
                showsDisplayTitleColumn: showsDisplayTitleColumn,
                showsTimeColumn: showsTimeColumn,
                showsLanguageColumn: showsLanguageColumn,
                cuesMinimumWidth: cuesMinimumWidth
            )
            return max(viewportWidth, minimumWidth)
        }

        private func tableColumnLayout(contentWidth: CGFloat, height: CGFloat) -> SubtitleTableColumnLayout {
            guard isRedesign else {
                return SubtitleTableColumnLayout.legacy(
                    contentWidth: contentWidth,
                    height: height,
                    showsDateAddedColumn: showsDateAddedColumn,
                    showsDisplayTitleColumn: showsDisplayTitleColumn,
                    showsTimeColumn: showsTimeColumn,
                    showsLanguageColumn: showsLanguageColumn
                )
            }
            return SubtitleTableColumnLayout.resolve(
                contentWidth: contentWidth,
                height: height,
                showsDateAddedColumn: showsDateAddedColumn,
                showsDisplayTitleColumn: showsDisplayTitleColumn,
                showsTimeColumn: showsTimeColumn,
                showsLanguageColumn: showsLanguageColumn,
                cuesMinimumWidth: SubtitleTableMetrics.cuesColumnMinimumWidth,
                columnOrder: columnOrder
            )
        }

        private func visibleTextColumnOrder() -> [String] {
            SubtitleTableColumnLayout.resolvedTextColumnOrder(
                columnOrder,
                showsDateAddedColumn: showsDateAddedColumn,
                showsDisplayTitleColumn: showsDisplayTitleColumn,
                showsTimeColumn: showsTimeColumn,
                showsLanguageColumn: showsLanguageColumn
            )
        }

        private func clearTextSelection() {
            cancelPendingTextInteraction()
            let previousSelection = textSelection
            textSelection.clear()
            invalidateTextSelectionChange(from: previousSelection)
        }

        @objc private func appLeftMouseDown(_ notification: Notification) {
            clearTextSelection()
        }

        func selectAllTableText() {
            guard isRedesign, isEnabled, !isSelectionMode else { return }
            let previousSelection = textSelection
            textSelection.selectAll()
            invalidateTextSelectionChange(from: previousSelection)
        }

        func copyTableTextSelection(to pasteboard: NSPasteboard = .general) {
            guard isRedesign,
                  isEnabled,
                  !isSelectionMode,
                  textSelection.hasSelection
            else {
                return
            }
            let request = SubtitleTableTextCopyRequest(
                selection: textSelection,
                columns: visibleTextColumnOrder().map {
                    SubtitleTableTextCopyColumn(id: $0, title: headerTitle(for: $0))
                },
                rowCount: textSelection.selectsAllResults
                    ? allResultsTextCopyRowCount
                    : rowCount,
                showsCueGroup: showsCueGroup
            )
            guard !request.columns.isEmpty else { return }

            textCopyTask?.cancel()
            textCopyTask = nil
            let initialPasteboardChangeCount = pasteboard.changeCount
            if request.bodyRowRange.isEmpty {
                let builder = SubtitleTableTextCopyBuilder(request: request)
                guard pasteboard.changeCount == initialPasteboardChangeCount else { return }
                _ = SubtitleTableClipboard.copy(
                    representations: builder.representations,
                    to: pasteboard
                )
                return
            }

            let loader = request.selection.selectsAllResults
                ? loadRowsForTextCopy
                : nil
            let capturedRowProvider = rowProvider
            textCopyTask = Task { @MainActor in
                var builder = SubtitleTableTextCopyBuilder(request: request)
                let batchSize = 512
                var batchStart = request.bodyRowRange.lowerBound
                while batchStart < request.bodyRowRange.upperBound {
                    guard !Task.isCancelled else { return }
                    let batchEnd = min(batchStart + batchSize, request.bodyRowRange.upperBound)
                    let batchRange = batchStart..<batchEnd
                    let rows: [SubtitleTableRow]?
                    if let loader {
                        rows = await loader(batchRange)
                    } else {
                        let loadedRows = batchRange.compactMap(capturedRowProvider)
                        rows = loadedRows.count == batchRange.count ? loadedRows : nil
                    }
                    guard let rows,
                          rows.count == batchRange.count,
                          !Task.isCancelled
                    else {
                        return
                    }
                    builder.append(rows: rows, startingAt: batchStart)
                    batchStart = batchEnd
                }
                guard !Task.isCancelled,
                      pasteboard.changeCount == initialPasteboardChangeCount
                else {
                    return
                }
                _ = SubtitleTableClipboard.copy(
                    representations: builder.representations,
                    to: pasteboard
                )
            }
        }

        private func textSelectionProjection(
            _ selection: SubtitleTableTextSelectionState,
            for row: SubtitleTableTextRow
        ) -> TextSelectionRowProjection {
            guard selection.hasSelection else { return .none }
            if selection.selectsAllResults {
                return .full
            }
            guard let range = selection.orderedRange,
                  range.start.row <= row,
                  row <= range.end.row
            else {
                return .none
            }
            if range.start.row == row, range.end.row == row {
                return .bounded(range.start, range.end)
            }
            if range.start.row == row {
                return .from(range.start)
            }
            if range.end.row == row {
                return .through(range.end)
            }
            return .full
        }

        private func invalidateTextSelectionChange(
            from previousSelection: SubtitleTableTextSelectionState
        ) {
            guard previousSelection != textSelection else { return }

            if textSelectionProjection(previousSelection, for: .header) !=
                textSelectionProjection(textSelection, for: .header)
            {
                textSelectionInvalidationCount += 1
                headerView?.invalidateTextSelectionOverlay()
            }

            guard let documentView,
                  let visibleRows = visibleRowRange()
            else {
                return
            }
            for row in visibleRows where
                textSelectionProjection(previousSelection, for: .body(row)) !=
                textSelectionProjection(textSelection, for: .body(row))
            {
                textSelectionInvalidationCount += 1
                documentView.setNeedsDisplay(
                    rectForRow(row, width: documentView.bounds.width)
                )
            }
        }

        private func headerTitle(for columnID: String) -> String {
            switch columnID {
            case "dateAdded":
                return dateAddedHeader
            case "display":
                return displayTitleHeader
            case "time":
                return timeHeader
            case "cues":
                return cuesHeader
            case "language":
                return languageHeader
            default:
                return ""
            }
        }

        private func headerTextFragments() -> [HeaderTextFragmentLayout] {
            guard let headerView else { return [] }
            let columnIDs = visibleTextColumnOrder()
            let layout = headerColumnLayoutForRendering(
                viewportWidth: headerView.bounds.width,
                height: headerView.bounds.height
            )
            return columnIDs.enumerated().compactMap { columnIndex, columnID in
                guard let cellRect = layout.rect(for: columnID) else { return nil }
                let title = headerTitle(for: columnID)
                let attributed = SubtitleTableText.header(title, isRedesign: isRedesign)
                let size = attributed.size()
                let leading = WorkbenchControlMetrics.redesignPaddingHeaderTriggerX
                let origin = CGPoint(
                    x: cellRect.minX + leading,
                    y: cellRect.minY + max(0, (cellRect.height - size.height) / 2)
                )
                return HeaderTextFragmentLayout(
                    columnID: columnID,
                    columnIndex: columnIndex,
                    cellRect: cellRect,
                    fragment: SubtitleTableTextFragmentLayout(
                        attributed: attributed,
                        origin: origin,
                        width: max(1, cellRect.width - 2 * leading),
                        clipRect: CGRect(
                            x: origin.x,
                            y: origin.y,
                            width: max(0, min(size.width, cellRect.maxX - leading - origin.x)),
                            height: min(size.height, cellRect.height)
                        ),
                        logicalUTF16Range: NSRange(
                            location: 0,
                            length: (title as NSString).length
                        )
                    )
                )
            }
        }

        private func headerTextPosition(
            at point: CGPoint,
            requiresTextHit: Bool
        ) -> SubtitleTableTextPosition? {
            let fragments = headerTextFragments()
            let candidate: HeaderTextFragmentLayout?
            if requiresTextHit {
                candidate = fragments.first { item in
                    guard item.fragment.clipRect.contains(point) else { return false }
                    textLayout.update(
                        attributedString: item.fragment.attributed,
                        width: item.fragment.width
                    )
                    return textLayout.containsText(at: point, origin: item.fragment.origin)
                }
            } else {
                candidate = fragments.min { lhs, rhs in
                    squaredDistance(from: point, to: textBounds(for: lhs.fragment)) <
                        squaredDistance(from: point, to: textBounds(for: rhs.fragment))
                }
            }
            guard let candidate else { return nil }
            textLayout.update(
                attributedString: candidate.fragment.attributed,
                width: candidate.fragment.width
            )
            return SubtitleTableTextPosition(
                row: .header,
                columnIndex: candidate.columnIndex,
                utf16Offset: textLayout.utf16Offset(
                    at: point,
                    origin: candidate.fragment.origin
                )
            )
        }

        func isHeaderTextHitForInteraction(at point: CGPoint) -> Bool {
            headerTextPosition(at: point, requiresTextHit: true) != nil
        }

        func drawHeaderTextSelection(in dirtyRect: CGRect) {
            guard textSelection.hasSelection else { return }
            for item in headerTextFragments() where item.fragment.clipRect.intersects(dirtyRect) {
                let title = item.fragment.attributed.string
                guard let selectedRange = textSelection.selectedUTF16Range(
                    row: .header,
                    columnIndex: item.columnIndex,
                    utf16Length: (title as NSString).length
                ) else {
                    continue
                }
                NSGraphicsContext.saveGraphicsState()
                NSBezierPath.clip(item.fragment.clipRect)
                textLayout.update(
                    attributedString: item.fragment.attributed,
                    width: item.fragment.width
                )
                drawSelectionBackground(
                    selectedRange,
                    with: textLayout,
                    at: item.fragment.origin
                )
                textLayout.draw(at: item.fragment.origin)
                NSGraphicsContext.restoreGraphicsState()
            }
        }

        private func text(for columnID: String, model: SubtitleTableRow) -> String {
            switch columnID {
            case "dateAdded":
                return model.dateAdded
            case "display":
                return model.displayTitle
            case "time":
                return model.timeRange
            case "cues":
                return model.cues
            case "language":
                return model.tags.map(\.label).joined(separator: ", ")
            default:
                return ""
            }
        }

        private func displayedCueTexts(for model: SubtitleTableRow) -> [String] {
            [model.primaryCueText] + (showsCueGroup ? model.additionalCueTexts : [])
        }

        private func selectableText(for columnID: String, model: SubtitleTableRow) -> String {
            if columnID == "cues" {
                return displayedCueTexts(for: model).joined(separator: "\n")
            }
            return text(for: columnID, model: model)
        }

        private func selectedUTF16Range(
            row: Int,
            columnID: String,
            text: String
        ) -> NSRange? {
            guard textSelection.hasSelection else { return nil }
            guard let columnIndex = visibleTextColumnOrder().firstIndex(of: columnID) else {
                return nil
            }
            return textSelection.selectedUTF16Range(
                row: .body(row),
                columnIndex: columnIndex,
                utf16Length: (text as NSString).length
            )
        }

        private func refreshHeaderForHorizontalScrollIfNeeded(force: Bool = false) {
            let offset = scrollView?.contentView.bounds.origin.x ?? 0
            guard force || lastHeaderHorizontalOffset != offset else { return }
            lastHeaderHorizontalOffset = offset
            headerView?.refreshHeaderFramesForHorizontalScroll()
            headerView?.needsDisplay = true
        }

        func drawRows(in dirtyRect: CGRect) {
            guard let documentView else { return }
            documentView.effectiveAppearance.performAsCurrentDrawingAppearance {
                NSGraphicsContext.saveGraphicsState()
                drawRowsNow(in: dirtyRect)
                NSGraphicsContext.restoreGraphicsState()
            }
        }

        private func drawRowsNow(in dirtyRect: CGRect) {
            let viewportDirtyRect = dirtyRect.intersection(currentTableBodyVisibleRect)
            guard rowCount > 0,
                  let documentView,
                  !viewportDirtyRect.isNull,
                  let range = visibleRowRange(in: viewportDirtyRect)
            else {
                return
            }

            NSBezierPath(rect: viewportDirtyRect).addClip()
            for row in range {
                let rowRect = rectForRow(row, width: documentView.bounds.width)
                guard rowRect.intersects(viewportDirtyRect) else { continue }
                drawnRowCount += 1
                UIInvalidationProbe.count(
                    probeSurface.counterName("dynamic_row_draw"),
                    scope: probeScope,
                    details: "table=\(tableName) row=\(row)"
                )
                drawRowBackground(row: row, rect: rowRect)
                drawCellTexts(row: row, rowRect: rowRect)
            }
        }

        private func drawRowBackground(row: Int, rect: CGRect) {
            if let backgroundColor = rowBackgroundColor(row: row) {
                backgroundColor.setFill()
                rect.fill()
            }

            if isRedesign {
                WorkbenchRedesignColors.NS.borderDivider.setStroke()
            } else {
                NSColor.separatorColor.setStroke()
            }
            let path = NSBezierPath()
            path.move(to: NSPoint(x: rect.minX, y: rect.maxY - 0.5))
            path.line(to: NSPoint(x: rect.maxX, y: rect.maxY - 0.5))
            path.lineWidth = 1
            path.stroke()
        }

        private func rowBackgroundColor(row: Int) -> NSColor? {
            if isRedesign, isSelectionMode, isRowSelected(row) {
                return WorkbenchRedesignColors.NS.rowSelected
            }
            guard hoveredRow == row else { return nil }
            return isRedesign
                ? WorkbenchRedesignColors.NS.rowHover
                : NSColor.secondaryLabelColor.withAlphaComponent(0.06)
        }

        private func drawCellTexts(row: Int, rowRect: CGRect) {
            let model = rowProvider(row)
            let isUnavailable = model?.cueState.isUnavailable == true
            let M = SubtitleTableMetrics.self
            let hasTextSelection = textSelection.hasSelection
            let layout = tableColumnLayout(contentWidth: rowRect.width, height: rowRect.height)
            let measurement = cachedMeasurement(for: row, documentWidth: rowRect.width)
                ?? SubtitleTableRowMeasurement(
                    height: rowRect.height,
                    primaryLineCount: 1,
                    extraCueLineCounts: []
                )

            if isRedesign, isSelectionMode {
                let checkboxState: WorkbenchCheckboxState = isRowSelected(row) ? .checked : .unchecked
                WorkbenchCheckboxDrawing.draw(
                    state: checkboxState,
                    isEnabled: isEnabled,
                    in: checkboxRect(forRowRect: rowRect),
                    isFocused: isEnabled && focusedCheckboxRow == row && documentView?.window?.firstResponder === documentView
                )
            } else {
                drawIndex(row + 1, in: rowColumnRect(layout.indexRect, rowRect: rowRect))
            }
            if let dateAddedRect = layout.dateAddedRect {
                let cellRect = rowColumnRect(dateAddedRect, rowRect: rowRect)
                let text = model?.dateAdded ?? ""
                drawBody(
                    text,
                    in: cellRect,
                    trailing: M.trailingInset,
                    role: .metadata,
                    foregroundColor: isUnavailable ? WorkbenchRedesignColors.NS.textMuted : nil,
                    selectedRange: hasTextSelection
                        ? selectedUTF16Range(row: row, columnID: "dateAdded", text: text)
                        : nil
                )
            }
            if showsDisplayTitleColumn {
                let cellRect = rowColumnRect(layout.nameRect, rowRect: rowRect)
                let text = model?.displayTitle ?? ""
                drawBody(
                    text,
                    in: cellRect,
                    trailing: M.trailingInset,
                    role: .secondaryContext,
                    foregroundColor: isUnavailable ? WorkbenchRedesignColors.NS.textMuted : nil,
                    selectedRange: hasTextSelection
                        ? selectedUTF16Range(row: row, columnID: "display", text: text)
                        : nil
                )
            }
            if let timeRect = layout.timeRect {
                let cellRect = rowColumnRect(timeRect, rowRect: rowRect)
                let text = model?.timeRange ?? ""
                drawBody(
                    text,
                    in: cellRect,
                    trailing: M.trailingInset,
                    role: .metadata,
                    foregroundColor: isUnavailable ? WorkbenchRedesignColors.NS.textMuted : nil,
                    selectedRange: hasTextSelection
                        ? selectedUTF16Range(row: row, columnID: "time", text: text)
                        : nil
                )
            }
            let cuesRect = rowColumnRect(layout.cuesRect, rowRect: rowRect)
            let isCuesHovered = !isSelectionMode
                && !isUnavailable
                && isCellHovered(row: row, columnID: "cues")
            drawCues(
                model: model,
                in: cuesRect,
                measurement: measurement,
                isHovered: isCuesHovered,
                selectedRange: hasTextSelection ? model.flatMap {
                    let text = selectableText(for: "cues", model: $0)
                    return selectedUTF16Range(row: row, columnID: "cues", text: text)
                } : nil
            )
            if let model {
                drawCueStateIndicator(
                    row: row,
                    model: model,
                    cuesRect: cuesRect,
                    measurement: measurement
                )
            }
            if let languageRect = layout.languageRect {
                let cellRect = rowColumnRect(languageRect, rowRect: rowRect)
                let tags = model?.tags ?? []
                drawTags(
                    tags,
                    in: cellRect,
                    trailing: M.trailingInset,
                    isMuted: isUnavailable,
                    selectedRange: hasTextSelection ? selectedUTF16Range(
                        row: row,
                        columnID: "language",
                        text: tags.map(\.label).joined(separator: ", ")
                    ) : nil
                )
            }
        }

        private func isCellHovered(row: Int, columnID: String) -> Bool {
            guard isRedesign else { return false }
            return (hoveredRow == row && hoveredColumnID == columnID) ||
                (isMenuOpen && activeRowMenuRow == row && activeRowMenuColumnID == columnID)
        }

        private func contentHoverRect(rects: [CGRect], clippedTo clipRect: CGRect) -> CGRect? {
            let M = SubtitleTableMetrics.self
            guard var contentBounds = rects.first else { return nil }
            for rect in rects.dropFirst() {
                contentBounds = contentBounds.union(rect)
            }
            let hoverRect = contentBounds
                .insetBy(dx: -M.tableCellHoverPaddingX, dy: -M.tableCellHoverPaddingY)
                .intersection(clipRect)
            guard !hoverRect.isNull, hoverRect.width > 0, hoverRect.height > 0 else { return nil }
            return hoverRect
        }

        private func drawContentHoverBackground(rects: [CGRect], clippedTo clipRect: CGRect) {
            let M = SubtitleTableMetrics.self
            guard let hoverRect = contentHoverRect(rects: rects, clippedTo: clipRect) else { return }
            WorkbenchRedesignColors.NS.bgHover.setFill()
            NSBezierPath(
                roundedRect: hoverRect,
                xRadius: M.tableCellHoverRadius,
                yRadius: M.tableCellHoverRadius
            ).fill()
        }

        private func rowColumnRect(_ columnRect: CGRect, rowRect: CGRect) -> CGRect {
            CGRect(
                x: columnRect.minX,
                y: rowRect.minY,
                width: columnRect.width,
                height: rowRect.height
            )
        }

        private func drawIndex(_ number: Int, in rect: CGRect) {
            let M = SubtitleTableMetrics.self
            textLayout.update(
                attributedString: SubtitleTableText.index(number, isRedesign: isRedesign),
                width: max(0, rect.width - M.cellLeading - M.indexTrailingInset)
            )
            let yOffset = isRedesign ? rect.minY + (rect.height - textLayout.usedHeight) / 2 : rect.minY + M.rowVerticalInset
            textLayout.draw(at: CGPoint(x: rect.minX + M.cellLeading, y: yOffset))
        }

        private func localSelectionRange(
            _ selectedRange: NSRange?,
            in logicalRange: NSRange
        ) -> NSRange? {
            guard let selectedRange else { return nil }
            let intersection = NSIntersectionRange(selectedRange, logicalRange)
            guard intersection.length > 0 else { return nil }
            return NSRange(
                location: intersection.location - logicalRange.location,
                length: intersection.length
            )
        }

        private func drawSelectionBackground(
            _ range: NSRange?,
            with layout: SubtitleTextLayout,
            at origin: CGPoint
        ) {
            guard let range, range.length > 0 else { return }
            NSColor.selectedTextBackgroundColor.setFill()
            for rect in layout.selectionRects(forUTF16Range: range, at: origin) {
                rect.fill()
            }
        }

        private func drawBody(
            _ text: String,
            in rect: CGRect,
            trailing: CGFloat,
            role: SubtitleTableTextRole = .primaryContent,
            foregroundColor: NSColor? = nil,
            isHovered: Bool = false,
            underline: Bool = false,
            selectedRange: NSRange? = nil
        ) {
            let M = SubtitleTableMetrics.self
            guard !text.isEmpty else { return }
            NSGraphicsContext.saveGraphicsState()
            NSBezierPath.clip(rect)
            textLayout.update(
                attributedString: SubtitleTableText.body(
                    text,
                    role: role,
                    isRedesign: isRedesign,
                    foregroundColor: isHovered
                        ? WorkbenchRedesignColors.NS.textPrimary
                        : foregroundColor
                ),
                width: max(0, rect.width - M.cellLeading - trailing)
            )
            let origin = bodyTextOrigin(in: rect)
            if isHovered {
                if let textBounds = textLayout.unionUsedRect(at: origin) {
                    drawContentHoverBackground(rects: [textBounds], clippedTo: rect)
                }
            }
            drawSelectionBackground(selectedRange, with: textLayout, at: origin)
            if underline {
                textLayout.drawUnderline(
                    at: origin,
                    color: WorkbenchRedesignColors.NS.textPrimary,
                    thickness: M.interactiveTextUnderlineThickness,
                    offset: M.interactiveTextUnderlineOffset,
                    backingScaleFactor: backingScaleFactor()
                )
            }
            textLayout.draw(at: origin)
            NSGraphicsContext.restoreGraphicsState()
        }

        private func drawCues(
            model: SubtitleTableRow?,
            in rect: CGRect,
            measurement: SubtitleTableRowMeasurement,
            isHovered: Bool,
            selectedRange: NSRange?
        ) {
            guard let model else { return }
            let primaryColor = model.cueState.isUnavailable
                ? WorkbenchRedesignColors.NS.textMuted
                : isHovered
                    ? WorkbenchRedesignColors.NS.textPrimary
                    : WorkbenchRedesignColors.NS.textSecondary
            let extraColor = WorkbenchRedesignColors.NS.textMuted
            let fragments = cueTextFragments(
                model: model,
                in: rect,
                measurement: measurement,
                primaryColor: primaryColor,
                extraColor: extraColor
            )

            NSGraphicsContext.saveGraphicsState()
            NSBezierPath.clip(rect)

            for (index, fragment) in fragments.enumerated() {
                textLayout.update(
                    attributedString: fragment.attributed,
                    width: cuesTextWidth(in: rect, model: model)
                )
                drawSelectionBackground(
                    localSelectionRange(selectedRange, in: fragment.logicalUTF16Range),
                    with: textLayout,
                    at: fragment.origin
                )
                if isHovered {
                    textLayout.drawUnderline(
                        at: fragment.origin,
                        color: index == fragments.count - 1 ? WorkbenchRedesignColors.NS.textPrimary : extraColor,
                        thickness: SubtitleTableMetrics.interactiveTextUnderlineThickness,
                        offset: SubtitleTableMetrics.interactiveTextUnderlineOffset,
                        backingScaleFactor: backingScaleFactor()
                    )
                }
                textLayout.draw(at: fragment.origin)
            }
            NSGraphicsContext.restoreGraphicsState()
        }

        private func drawCueStateIndicator(
            row: Int,
            model: SubtitleTableRow,
            cuesRect: CGRect,
            measurement: SubtitleTableRowMeasurement
        ) {
            guard let systemImage = model.cueState.systemImage,
                  let rect = cueStateIndicatorRect(
                    model: model,
                    cuesRect: cuesRect,
                    measurement: measurement
                  ),
                  let image = NSImage(
                    systemSymbolName: systemImage,
                    accessibilityDescription: nil
                  )?
                    .withSymbolConfiguration(
                        NSImage.SymbolConfiguration(
                            hierarchicalColor: WorkbenchRedesignColors.NS.iconMuted
                        )
                    )
            else {
                return
            }
            image.draw(in: rect)
            if hoveredCueStateRow == row {
                WorkbenchRedesignColors.NS.iconMuted.withAlphaComponent(0.12).setFill()
                NSBezierPath(
                    roundedRect: rect.insetBy(dx: -3, dy: -3),
                    xRadius: 5,
                    yRadius: 5
                ).fill()
                image.draw(in: rect)
            }
        }

        private func cueStateIndicatorRect(
            model: SubtitleTableRow,
            cuesRect: CGRect,
            measurement: SubtitleTableRowMeasurement
        ) -> CGRect? {
            guard model.cueState.systemImage != nil,
                  let primary = cueTextFragments(
                    model: model,
                    in: cuesRect,
                    measurement: measurement
                  ).last
            else {
                return nil
            }
            textLayout.update(
                attributedString: primary.attributed,
                width: primary.width
            )
            guard let lastLine = textLayout.usedRects(at: primary.origin).last else {
                return nil
            }
            let size: CGFloat = 14
            let proposedX = lastLine.maxX + 8
            let x = min(proposedX, cuesRect.maxX - size - 4)
            return CGRect(
                x: max(cuesRect.minX, x),
                y: lastLine.midY - size / 2,
                width: size,
                height: size
            )
        }

        private func cueStateIndicatorRectInDocument(row: Int) -> CGRect? {
            guard let documentView,
                  let model = rowProvider(row)
            else {
                return nil
            }
            let rowRect = rectForRow(row, width: documentView.bounds.width)
            let layout = tableColumnLayout(
                contentWidth: rowRect.width,
                height: rowRect.height
            )
            let cuesRect = rowColumnRect(layout.cuesRect, rowRect: rowRect)
            let measurement = cachedMeasurement(
                for: row,
                documentWidth: documentView.bounds.width
            ) ?? SubtitleTableRowMeasurement(
                height: rowRect.height,
                primaryLineCount: 1,
                extraCueLineCounts: []
            )
            return cueStateIndicatorRect(
                model: model,
                cuesRect: cuesRect,
                measurement: measurement
            )
        }

        private func cuesTextWidth(
            in rect: CGRect,
            model: SubtitleTableRow
        ) -> CGFloat {
            let indicatorReservation: CGFloat =
                model.cueState.systemImage == nil ? 0 : 22
            return max(
                1,
                rect.width
                    - SubtitleTableCueGeometry.cellLeadingPadding
                    - SubtitleTableCueGeometry.cellTrailingPadding
                    - indicatorReservation
            )
        }

        private func cueTextFragments(
            model: SubtitleTableRow,
            in rect: CGRect,
            measurement: SubtitleTableRowMeasurement,
            primaryColor: NSColor = WorkbenchRedesignColors.NS.textSecondary,
            extraColor: NSColor = WorkbenchRedesignColors.NS.textMuted
        ) -> [SubtitleTableTextFragmentLayout] {
            let extraTexts = showsCueGroup ? model.additionalCueTexts : []
            let textX = rect.minX + SubtitleTableCueGeometry.cellLeadingPadding
            var fragments = [SubtitleTableTextFragmentLayout]()
            fragments.reserveCapacity(extraTexts.count + 1)

            let primaryText = model.primaryCueText
            let primaryLength = (primaryText as NSString).length
            fragments.append(SubtitleTableTextFragmentLayout(
                attributed: SubtitleTableCueTextMeasurer.attributedString(
                    primaryText,
                    style: .primary,
                    foregroundColor: primaryColor
                ),
                origin: CGPoint(
                    x: rect.minX + SubtitleTableCueGeometry.cellLeadingPadding,
                    y: rect.minY + measurement.primaryFirstLineOffset
                ),
                width: cuesTextWidth(in: rect, model: model),
                clipRect: rect,
                logicalUTF16Range: NSRange(location: 0, length: primaryLength)
            ))
            var logicalOffset = primaryLength + 1

            for (index, text) in extraTexts.enumerated() {
                let length = (text as NSString).length
                if measurement.extraCueOffsets.indices.contains(index) {
                    fragments.append(SubtitleTableTextFragmentLayout(
                        attributed: SubtitleTableCueTextMeasurer.attributedString(
                            text,
                            style: .extra,
                            foregroundColor: extraColor
                        ),
                        origin: CGPoint(
                            x: textX,
                            y: rect.minY + measurement.extraCueOffsets[index]
                        ),
                        width: cuesTextWidth(in: rect, model: model),
                        clipRect: rect,
                        logicalUTF16Range: NSRange(location: logicalOffset, length: length)
                    ))
                }
                logicalOffset += length + 1
            }
            return fragments
        }

        private func cuesTextTrailingInset(forRowRect _: CGRect) -> CGFloat {
            let M = SubtitleTableMetrics.self
            return M.trailingInset
        }

        private func bodyTextRole(for columnID: String) -> SubtitleTableTextRole {
            switch columnID {
            case "dateAdded", "time":
                return .metadata
            case "display":
                return .secondaryContext
            default:
                return .primaryContent
            }
        }

        private func bodyTextTrailingInset(for columnID: String, rowRect: CGRect) -> CGFloat {
            let M = SubtitleTableMetrics.self
            return columnID == "cues" ? cuesTextTrailingInset(forRowRect: rowRect) : M.trailingInset
        }

        private func bodyContentHoverRect(
            text: String,
            in rect: CGRect,
            trailing: CGFloat,
            role: SubtitleTableTextRole
        ) -> CGRect? {
            let M = SubtitleTableMetrics.self
            guard !text.isEmpty else { return nil }
            textLayout.update(
                attributedString: SubtitleTableText.body(
                    text,
                    role: role,
                    isRedesign: isRedesign
                ),
                width: max(0, rect.width - M.cellLeading - trailing)
            )
            let origin = bodyTextOrigin(in: rect)
            guard let textBounds = textLayout.unionUsedRect(at: origin) else { return nil }
            return contentHoverRect(rects: [textBounds], clippedTo: rect)
        }

        private func cuesContentHoverRect(
            model: SubtitleTableRow,
            in rect: CGRect,
            measurement: SubtitleTableRowMeasurement
        ) -> CGRect? {
            let textWidth = cuesTextWidth(in: rect, model: model)
            let textX = rect.minX + SubtitleTableCueGeometry.cellLeadingPadding
            var usedRects = [CGRect]()
            for (extraText, offset) in zip(
                showsCueGroup ? model.additionalCueTexts : [],
                measurement.extraCueOffsets
            ) {
                textLayout.update(
                    attributedString: SubtitleTableCueTextMeasurer.attributedString(
                        extraText,
                        style: .extra,
                        foregroundColor: WorkbenchRedesignColors.NS.textMuted
                    ),
                    width: textWidth
                )
                usedRects.append(contentsOf: textLayout.usedRects(at: CGPoint(
                    x: textX,
                    y: rect.minY + offset
                )))
            }
            textLayout.update(
                attributedString: SubtitleTableCueTextMeasurer.attributedString(
                    model.primaryCueText,
                    style: .primary,
                    foregroundColor: WorkbenchRedesignColors.NS.textSecondary
                ),
                width: textWidth
            )
            usedRects.append(contentsOf: textLayout.usedRects(at: CGPoint(
                x: textX,
                y: rect.minY + measurement.primaryFirstLineOffset
            )))
            return contentHoverRect(rects: usedRects, clippedTo: rect)
        }

        private func drawTags(
            _ tags: [WorkbenchTag],
            in rect: CGRect,
            trailing: CGFloat,
            isHovered: Bool = false,
            isMuted: Bool = false,
            selectedRange: NSRange? = nil
        ) {
            guard !tags.isEmpty else { return }

            NSGraphicsContext.saveGraphicsState()
            NSBezierPath.clip(rect)

            let tagStyle = SubtitleTableTagStyle.resolve(isRedesign: isRedesign)
            let laidOutTags = layoutTags(
                tags,
                in: rect,
                trailing: trailing,
                tagStyle: tagStyle
            )

            if isHovered {
                drawContentHoverBackground(rects: laidOutTags.map { $0.tagRect }, clippedTo: rect)
            }

            for item in laidOutTags {
                let path = NSBezierPath(
                    roundedRect: item.tagRect,
                    xRadius: tagStyle.cornerRadius,
                    yRadius: tagStyle.cornerRadius
                )
                tagStyle.fillColor(for: item.tag, isRedesign: isRedesign, isEnabled: isEnabled).setFill()
                path.fill()
            }

            if selectedRange == nil {
                for item in laidOutTags {
                    attributedTagText(item.attributed, isMuted: isMuted)
                        .draw(in: tagTextRect(for: item, tagStyle: tagStyle))
                }
                NSGraphicsContext.restoreGraphicsState()
                return
            }

            for fragment in tagTextFragments(
                laidOutTags,
                tagStyle: tagStyle,
                isMuted: isMuted
            ) {
                NSGraphicsContext.saveGraphicsState()
                NSBezierPath.clip(fragment.clipRect)
                textLayout.update(attributedString: fragment.attributed, width: fragment.width)
                drawSelectionBackground(
                    localSelectionRange(selectedRange, in: fragment.logicalUTF16Range),
                    with: textLayout,
                    at: fragment.origin
                )
                textLayout.draw(at: fragment.origin)
                NSGraphicsContext.restoreGraphicsState()
            }

            NSGraphicsContext.restoreGraphicsState()
        }

        private func tagTextRect(
            for item: SubtitleTableLaidOutTag,
            tagStyle: SubtitleTableTagStyle
        ) -> CGRect {
            CGRect(
                x: item.tagRect.minX + tagStyle.horizontalInset,
                y: item.tagRect.minY + max(0, (item.tagRect.height - item.textSize.height) / 2),
                width: max(0, item.tagRect.width - 2 * tagStyle.horizontalInset),
                height: item.textSize.height
            )
        }

        private func tagTextFragments(
            _ laidOutTags: [SubtitleTableLaidOutTag],
            tagStyle: SubtitleTableTagStyle,
            isMuted: Bool = false
        ) -> [SubtitleTableTextFragmentLayout] {
            var logicalOffset = 0
            return laidOutTags.enumerated().map { index, item in
                let length = (item.attributed.string as NSString).length
                let textRect = tagTextRect(for: item, tagStyle: tagStyle)
                defer { logicalOffset += length + (index == laidOutTags.indices.last ? 0 : 2) }
                return SubtitleTableTextFragmentLayout(
                    attributed: attributedTagText(item.attributed, isMuted: isMuted),
                    origin: textRect.origin,
                    width: textRect.width,
                    clipRect: textRect,
                    logicalUTF16Range: NSRange(location: logicalOffset, length: length)
                )
            }
        }

        private func attributedTagText(
            _ attributed: NSAttributedString,
            isMuted: Bool
        ) -> NSAttributedString {
            guard isMuted else {
                return attributed
            }
            let result = NSMutableAttributedString(attributedString: attributed)
            result.addAttribute(
                .foregroundColor,
                value: WorkbenchRedesignColors.NS.textMuted,
                range: NSRange(location: 0, length: result.length)
            )
            return result
        }

        private func tagContentHoverRect(
            tags: [WorkbenchTag],
            in rect: CGRect,
            trailing: CGFloat
        ) -> CGRect? {
            guard !tags.isEmpty else { return nil }
            let tagStyle = SubtitleTableTagStyle.resolve(isRedesign: isRedesign)
            let laidOutTags = layoutTags(
                tags,
                in: rect,
                trailing: trailing,
                tagStyle: tagStyle
            )
            return contentHoverRect(rects: laidOutTags.map { $0.tagRect }, clippedTo: rect)
        }

        private func layoutTags(
            _ tags: [WorkbenchTag],
            in rect: CGRect,
            trailing: CGFloat,
            tagStyle: SubtitleTableTagStyle
        ) -> [SubtitleTableLaidOutTag] {
            let M = SubtitleTableMetrics.self
            let naturalLayout = naturalTagLayout(
                tags,
                availableWidth: max(0, rect.width - M.cellLeading - trailing),
                tagStyle: tagStyle
            )
            let top = isRedesign
                ? rect.minY + max(0, (rect.height - naturalLayout.blockHeight) / 2)
                : rect.minY + M.rowVerticalInset - 1
            return naturalLayout.items.compactMap { item in
                let tagRect = item.tagRect.offsetBy(dx: rect.minX + M.cellLeading, dy: top)
                if !isRedesign, tagRect.maxY > rect.maxY - M.rowVerticalInset {
                    return nil
                }
                return SubtitleTableLaidOutTag(
                    tag: item.tag,
                    attributed: item.attributed,
                    textSize: item.textSize,
                    tagRect: tagRect
                )
            }
        }

        private func naturalTagLayout(
            _ tags: [WorkbenchTag],
            availableWidth: CGFloat,
            tagStyle: SubtitleTableTagStyle
        ) -> SubtitleTableTagLayoutResult {
            guard !tags.isEmpty, availableWidth > 0 else {
                return SubtitleTableTagLayoutResult(items: [], blockHeight: 0)
            }

            var x: CGFloat = 0
            var y: CGFloat = 0
            var currentRowHeight: CGFloat = 0
            var laidOutTags = [SubtitleTableLaidOutTag]()

            for tag in tags {
                let attributed = SubtitleTableText.tag(tag, isRedesign: isRedesign, isEnabled: isEnabled)
                let textSize = attributed.size()
                let tagHeight = tagStyle.height(for: textSize)
                let tagWidth = min(tagStyle.width(for: textSize), availableWidth)
                if x > 0, x + tagWidth > availableWidth {
                    x = 0
                    y += currentRowHeight + tagStyle.verticalSpacing
                    currentRowHeight = 0
                }

                let tagRect = CGRect(x: x, y: y, width: tagWidth, height: tagHeight)
                laidOutTags.append(SubtitleTableLaidOutTag(
                    tag: tag,
                    attributed: attributed,
                    textSize: textSize,
                    tagRect: tagRect
                ))
                currentRowHeight = max(currentRowHeight, tagHeight)
                x += tagWidth + tagStyle.horizontalSpacing
            }

            return SubtitleTableTagLayoutResult(
                items: laidOutTags,
                blockHeight: laidOutTags.isEmpty ? 0 : y + currentRowHeight
            )
        }

        private func effectiveCuesTextWidth(documentWidth: CGFloat) -> CGFloat {
            let layout = tableColumnLayout(contentWidth: documentWidth, height: currentRowHeight)
            return max(
                1,
                layout.cuesRect.width
                    - SubtitleTableCueGeometry.cellLeadingPadding
                    - SubtitleTableCueGeometry.cellTrailingPadding
            )
        }

        private func rowMeasurement(
            for model: SubtitleTableRow,
            documentWidth: CGFloat,
            effectiveCuesWidth: CGFloat
        ) -> SubtitleTableRowMeasurement {
            let layout = tableColumnLayout(contentWidth: documentWidth, height: currentRowHeight)
            var otherContentHeights = [SubtitleTableMetrics.checkboxSize]

            if let dateAddedRect = layout.dateAddedRect {
                otherContentHeights.append(bodyContentHeight(
                    model.dateAdded,
                    cellWidth: dateAddedRect.width,
                    trailing: SubtitleTableMetrics.trailingInset,
                    role: .metadata
                ))
            }
            if showsDisplayTitleColumn {
                otherContentHeights.append(bodyContentHeight(
                    model.displayTitle,
                    cellWidth: layout.nameRect.width,
                    trailing: SubtitleTableMetrics.trailingInset,
                    role: .secondaryContext
                ))
            }
            if let timeRect = layout.timeRect {
                otherContentHeights.append(bodyContentHeight(
                    model.timeRange,
                    cellWidth: timeRect.width,
                    trailing: SubtitleTableMetrics.trailingInset,
                    role: .metadata
                ))
            }

            let tagStyle = SubtitleTableTagStyle.resolve(isRedesign: isRedesign)
            if let languageRect = layout.languageRect {
                otherContentHeights.append(tagContentHeight(
                    model.tags,
                    cellWidth: languageRect.width,
                    trailing: SubtitleTableMetrics.trailingInset,
                    tagStyle: tagStyle
                ))
            }
            let measuredCuesWidth = max(
                1,
                effectiveCuesWidth
                    - (model.cueState.systemImage == nil ? 0 : 22)
            )
            return cueTextMeasurer.rowMeasurement(
                row: model,
                effectiveCuesWidth: measuredCuesWidth,
                showsCueGroup: showsCueGroup,
                otherContentHeights: otherContentHeights
            )
        }

        private func bodyContentHeight(
            _ text: String,
            cellWidth: CGFloat,
            trailing: CGFloat,
            role: SubtitleTableTextRole
        ) -> CGFloat {
            guard !text.isEmpty else { return 0 }
            textLayout.update(
                attributedString: SubtitleTableText.body(
                    text,
                    role: role,
                    isRedesign: isRedesign
                ),
                width: max(0, cellWidth - SubtitleTableMetrics.cellLeading - trailing)
            )
            return textLayout.usedHeight
        }

        private func tagContentHeight(
            _ tags: [WorkbenchTag],
            cellWidth: CGFloat,
            trailing: CGFloat,
            tagStyle: SubtitleTableTagStyle
        ) -> CGFloat {
            naturalTagLayout(
                tags,
                availableWidth: max(0, cellWidth - SubtitleTableMetrics.cellLeading - trailing),
                tagStyle: tagStyle
            ).blockHeight
        }

        private func cachedMeasurement(for row: Int, documentWidth: CGFloat) -> SubtitleTableRowMeasurement? {
            guard let model = rowProvider(row) else { return nil }
            let layout = tableColumnLayout(contentWidth: documentWidth, height: currentRowHeight)
            return rowMeasurementCache.cachedMeasurement(
                rowIndex: row,
                row: model,
                layoutKey: layout.rowMeasurementLayoutKey,
                showsCueGroup: showsCueGroup,
                styleRevision: SubtitleTableCueGeometry.styleRevision
            )
        }

        @discardableResult
        private func measureRow(_ row: Int, documentWidth: CGFloat) -> Bool {
            guard isRedesign,
                  row >= 0,
                  row < rowCount,
                  let model = rowProvider(row)
            else {
                return false
            }

            let effectiveWidth = effectiveCuesTextWidth(documentWidth: documentWidth)
            let layout = tableColumnLayout(contentWidth: documentWidth, height: currentRowHeight)
            let lookup = rowMeasurementCache.lookup(
                rowIndex: row,
                row: model,
                layoutKey: layout.rowMeasurementLayoutKey,
                showsCueGroup: showsCueGroup,
                styleRevision: SubtitleTableCueGeometry.styleRevision
            ) {
                measurementComputeCount += 1
                UIInvalidationProbe.count(
                    probeSurface.counterName("dynamic_row_measurement"),
                    scope: probeScope,
                    details: "table=\(tableName) row=\(row)"
                )
                return rowMeasurement(
                    for: model,
                    documentWidth: documentWidth,
                    effectiveCuesWidth: effectiveWidth
                )
            }
            return rowHeightCache.setHeight(lookup.height, for: row)
        }

        private func captureDynamicScrollAnchor() -> DynamicScrollAnchor? {
            guard isRedesign,
                  let scrollView,
                  let documentView,
                  let visibleRows = visibleRowRange()
            else {
                return nil
            }

            for row in visibleRows {
                guard let model = rowProvider(row) else {
                    continue
                }
                guard let measurement = cachedMeasurement(
                    for: row,
                    documentWidth: documentView.bounds.width
                ) ?? rowMeasurementCache.cachedMeasurement(
                    rowIndex: row,
                    primaryCueIdentity: model.primaryCueIdentity
                )
                else {
                    continue
                }
                let firstLineDocumentY = rowDocumentY(for: row)
                    + measurement.primaryFirstLineOffset
                return DynamicScrollAnchor(
                    primaryCueIdentity: model.primaryCueIdentity,
                    row: row,
                    primaryFirstLineScreenY: firstLineDocumentY - scrollView.contentView.bounds.minY
                )
            }
            return nil
        }

        private func restoreDynamicScrollAnchor(_ anchor: DynamicScrollAnchor?) {
            guard let anchor,
                  let scrollView,
                  let documentView,
                  let model = rowProvider(anchor.row),
                  model.primaryCueIdentity == anchor.primaryCueIdentity,
                  let measurement = cachedMeasurement(for: anchor.row, documentWidth: documentView.bounds.width)
            else {
                return
            }

            let firstLineDocumentY = rowDocumentY(for: anchor.row)
                + measurement.primaryFirstLineOffset
            let maximumY = max(0, documentView.bounds.height - scrollView.contentView.bounds.height)
            let nextY = min(
                max(0, firstLineDocumentY - anchor.primaryFirstLineScreenY),
                maximumY
            )
            var origin = scrollView.contentView.bounds.origin
            guard abs(origin.y - nextY) > 0.01 else { return }
            origin.y = nextY
            scrollView.contentView.scroll(to: origin)
            scrollView.reflectScrolledClipView(scrollView.contentView)
            UIInvalidationProbe.count(
                probeSurface.counterName("dynamic_scroll_anchor_correction"),
                scope: probeScope,
                details: "table=\(tableName) row=\(anchor.row)"
            )
        }

        private func reflowVisibleRows(
            anchor: DynamicScrollAnchor? = nil,
            explicitTargetRow: Int? = nil
        ) {
            guard isRedesign,
                  !isApplyingDynamicReflow,
                  let scrollView,
                  let documentView
            else {
                return
            }
            isApplyingDynamicReflow = true
            defer { isApplyingDynamicReflow = false }

            let resolvedAnchor = anchor ?? captureDynamicScrollAnchor()
            rowHeightCache.configure(rowCount: rowCount, defaultHeight: currentRowHeight)
            if anchor == nil,
               let measurementRange = measurementRowRange(
                    in: tableBodyVisibleRect(for: scrollView)
               )
            {
                for row in measurementRange {
                    _ = measureRow(row, documentWidth: documentView.bounds.width)
                }
            }
            let requiredTargetRow = explicitTargetRow ?? resolvedAnchor?.row
            if let requiredTargetRow,
               requiredTargetRow >= 0,
               requiredTargetRow < rowCount,
               measurementRowRange(
                    in: tableBodyVisibleRect(for: scrollView)
               )?.contains(requiredTargetRow) != true
            {
                _ = measureRow(requiredTargetRow, documentWidth: documentView.bounds.width)
            }

            let nextHeight = pageScrollGeometry?.documentHeight(
                rowsHeight: rowHeightCache.totalHeight,
                viewportHeight: scrollView.contentSize.height
            ) ?? max(1, scrollView.contentSize.height, rowHeightCache.totalHeight)
            if abs(documentView.frame.height - nextHeight) > 0.01 {
                documentView.setFrameSize(CGSize(width: documentView.frame.width, height: nextHeight))
            }
            restoreDynamicScrollAnchor(resolvedAnchor)
            var postRestoreHeightChanged = false
            if let postRestoreRange = measurementRowRange(
                in: tableBodyVisibleRect(for: scrollView)
            ) {
                for row in postRestoreRange {
                    postRestoreHeightChanged = measureRow(
                        row,
                        documentWidth: documentView.bounds.width
                    ) || postRestoreHeightChanged
                }
            }
            if postRestoreHeightChanged {
                let resolvedHeight = pageScrollGeometry?.documentHeight(
                    rowsHeight: rowHeightCache.totalHeight,
                    viewportHeight: scrollView.contentSize.height
                ) ?? max(1, scrollView.contentSize.height, rowHeightCache.totalHeight)
                if abs(documentView.frame.height - resolvedHeight) > 0.01 {
                    documentView.setFrameSize(CGSize(
                        width: documentView.frame.width,
                        height: resolvedHeight
                    ))
                }
                restoreDynamicScrollAnchor(resolvedAnchor)
            }
            scrollbarOverlayView?.scrollMetricsDidChange()
            scrollbarOverlayView?.needsDisplay = true
            documentView.setNeedsDisplay(documentView.visibleRect)
            invalidateDocumentCursorRects()
            layoutHoverButtons()
            if isMenuOpen {
                repositionOpenMenu()
            }
        }

        private func heightForRow(_ row: Int, width: CGFloat) -> CGFloat {
            _ = width
            return rowHeightCache.height(for: row)
        }

        private func rectForRow(_ row: Int, width: CGFloat) -> CGRect {
            let y = rowDocumentY(for: row)
            let height = heightForRow(row, width: width)
            return CGRect(x: 0, y: y, width: width, height: height)
        }

        private func rowDocumentY(for row: Int) -> CGFloat {
            rowsOriginY + rowHeightCache.yOffset(for: row)
        }

        private func checkboxRect(forRowRect rowRect: CGRect) -> CGRect {
            let size = SubtitleTableMetrics.checkboxSize
            return CGRect(
                x: (SubtitleTableMetrics.indexColumnWidth - size) / 2,
                y: rowRect.midY - size / 2,
                width: size,
                height: size
            )
        }

        private func checkboxHitRect(forRowRect rowRect: CGRect) -> CGRect {
            checkboxRect(forRowRect: rowRect).insetBy(
                dx: -SubtitleTableMetrics.checkboxHitSlop,
                dy: -SubtitleTableMetrics.checkboxHitSlop
            )
        }

        private func visibleRowRange() -> Range<Int>? {
            guard let scrollView else { return nil }
            return visibleRowRange(in: tableBodyVisibleRect(for: scrollView))
        }

        private func visibleRowRange(in rect: CGRect) -> Range<Int>? {
            rowRange(in: rect, overscan: 0)
        }

        private func measurementRowRange(in rect: CGRect) -> Range<Int>? {
            rowRange(in: rect, overscan: SubtitleTableCueGeometry.measurementOverscan)
        }

        private var currentTableBodyVisibleRect: CGRect {
            guard let scrollView else {
                return documentView?.visibleRect ?? .zero
            }
            return tableBodyVisibleRect(for: scrollView)
        }

        private func tableBodyVisibleRect(for scrollView: NSScrollView) -> CGRect {
            guard var visibleRect = pageScrollGeometry?.tableBodyVisibleRect(
                scrollOffset: scrollView.contentView.bounds.minY,
                viewportSize: scrollView.contentView.bounds.size
            ) else {
                return scrollView.contentView.bounds
            }
            visibleRect.origin.x = scrollView.contentView.bounds.minX
            return visibleRect
        }

        private func rowRange(in rect: CGRect, overscan: Int) -> Range<Int>? {
            guard rowCount > 0 else { return nil }
            let localMinY = rect.minY - rowsOriginY
            let localMaxY = rect.maxY - rowsOriginY
            guard localMaxY >= 0 else { return nil }
            let lower = rowHeightCache.rowIndex(atY: max(0, localMinY))
            let upperY = rect.maxY > rect.minY
                ? max(0, localMaxY).nextDown
                : max(0, localMinY)
            let upper = rowHeightCache.rowIndex(atY: upperY)
            let lowerBound = max(0, lower - overscan)
            let upperBound = min(rowCount, upper + overscan + 1)
            return lowerBound < upperBound ? lowerBound..<upperBound : nil
        }

        func installCursorRects(in documentView: SubtitleVirtualTableDocumentView) {
            let visibleRect = currentTableBodyVisibleRect
            for rect in selectableTextCursorRects(
                in: visibleRect,
                documentWidth: documentView.bounds.width
            ) {
                documentView.addCursorRect(rect, cursor: .iBeam)
            }
            for rect in interactiveCellCursorRects(
                in: visibleRect,
                documentWidth: documentView.bounds.width
            ) {
                documentView.addCursorRect(rect, cursor: .pointingHand)
            }
        }

        func refreshDocumentCursor(windowPoint: CGPoint) {
            guard !isExternalPopupLayerOpen, let documentView else { return }
            let point = documentView.convert(windowPoint, from: nil)
            guard currentTableBodyVisibleRect.contains(point) else {
                NSCursor.arrow.set()
                return
            }
            if isInteractiveCellCursorActive(at: point) {
                NSCursor.pointingHand.set()
            } else if isSelectableTextCursorActive(at: point) {
                NSCursor.iBeam.set()
            } else {
                NSCursor.arrow.set()
            }
        }

        private func invalidateDocumentCursorRects() {
            guard let documentView else { return }
            documentView.window?.invalidateCursorRects(for: documentView)
        }

        private func interactiveCellCursorRects(in visibleRect: CGRect, documentWidth: CGFloat) -> [CGRect] {
            guard isRedesign,
                  isEnabled,
                  !isMenuOpen,
                  !isExternalPopupLayerOpen,
                  let range = visibleRowRange(in: visibleRect)
            else {
                return []
            }

            if isSelectionMode {
                return range.compactMap { row in
                    guard rowProvider(row) != nil else { return nil }
                    let clipped = rectForRow(row, width: documentWidth).intersection(visibleRect)
                    return clipped.isNull || clipped.width <= 0 || clipped.height <= 0
                        ? nil
                        : clipped
                }
            }

            return range.flatMap { row -> [CGRect] in
                guard let model = rowProvider(row),
                      !model.cueState.isUnavailable
                else {
                    return []
                }
                let candidateRects = [
                    cellContentHoverRectInDocument(row: row, columnID: "cues"),
                ].compactMap { $0 }
                return candidateRects.compactMap { candidateRect in
                    let cursorRect = candidateRect.intersection(visibleRect)
                    guard !cursorRect.isNull, cursorRect.width > 0, cursorRect.height > 0 else {
                        return nil
                    }
                    return cursorRect
                }
            }
        }

        private func isInteractiveCellCursorActive(at point: CGPoint) -> Bool {
            guard let documentView,
                  currentTableBodyVisibleRect.contains(point)
            else {
                return false
            }
            return interactiveCellCursorRects(
                in: currentTableBodyVisibleRect,
                documentWidth: documentView.bounds.width
            ).contains { $0.contains(point) }
        }

        private func selectableTextCursorRects(
            in visibleRect: CGRect,
            documentWidth: CGFloat
        ) -> [CGRect] {
            guard isRedesign,
                  isEnabled,
                  !isSelectionMode,
                  !isMenuOpen,
                  !isExternalPopupLayerOpen,
                  let range = visibleRowRange(in: visibleRect)
            else {
                return []
            }

            let selectableColumnIDs = visibleTextColumnOrder().filter {
                $0 != "cues"
            }
            return range.flatMap { row -> [CGRect] in
                guard rowProvider(row) != nil else { return [] }
                let rowRect = rectForRow(row, width: documentWidth)
                return selectableColumnIDs.flatMap { columnID in
                    textFragments(row: row, columnID: columnID, rowRect: rowRect).flatMap { fragment in
                        textLayout.update(attributedString: fragment.attributed, width: fragment.width)
                        return textLayout.usedRects(at: fragment.origin).compactMap { rect in
                            let clipped = rect.intersection(fragment.clipRect).intersection(visibleRect)
                            return clipped.isNull || clipped.width <= 0 || clipped.height <= 0
                                ? nil
                                : clipped
                        }
                    }
                }
            }
        }

        private func isSelectableTextCursorActive(at point: CGPoint) -> Bool {
            guard isRedesign,
                  isEnabled,
                  !isMenuOpen,
                  !isExternalPopupLayerOpen,
                  let documentView,
                  currentTableBodyVisibleRect.contains(point),
                  let row = rowAtDocumentPoint(point)
            else {
                return false
            }
            let rowRect = rectForRow(row, width: documentView.bounds.width)
            guard let columnID = visibleTextColumnOrder().first(where: {
                $0 != "cues" &&
                    dataCellRect(columnID: $0, rowRect: rowRect)?.contains(point) == true
            }) else {
                return false
            }
            return textPosition(
                row: row,
                columnID: columnID,
                point: point,
                requiresTextHit: true
            ) != nil
        }

        private func rowAtDocumentPoint(_ point: CGPoint) -> Int? {
            guard rowCount > 0 else { return nil }
            guard point.y >= rowsOriginY else { return nil }
            let row = rowHeightCache.rowIndex(atY: point.y - rowsOriginY)
            let rect = rectForRow(row, width: documentView?.bounds.width ?? 0)
            return rect.contains(point) ? row : nil
        }

        private func rowActionButtonFrameInDocument(for row: Int) -> CGRect? {
            guard row >= 0,
                  row < rowCount,
                  let documentView
            else {
                return nil
            }
            let rowRect = rectForRow(row, width: documentView.bounds.width)
            return rowActionButtonFrameInDocument(forRowRect: rowRect)
        }

        private func rowActionButtonFrameInDocument(forRowRect _: CGRect) -> CGRect? {
            nil
        }

        private func rowActionButtonFrameInContainer(for row: Int) -> CGRect? {
            guard let container,
                  let scrollView,
                  let documentView,
                  let documentFrame = rowActionButtonFrameInDocument(for: row)
            else {
                return nil
            }
            let frame = container.convert(documentFrame, from: documentView)
            guard frame.intersects(scrollView.frame) else {
                return nil
            }
            return frame
        }

        private func bodyTextOrigin(in rect: CGRect) -> CGPoint {
            let M = SubtitleTableMetrics.self
            let yOffset = isRedesign
                ? rect.minY + max(0, (rect.height - textLayout.usedHeight) / 2)
                : rect.minY + M.rowVerticalInset
            return CGPoint(x: rect.minX + M.cellLeading, y: yOffset)
        }

        private func isPointInRowActionButton(row _: Int, point _: CGPoint) -> Bool {
            false
        }

        private func cellContentHoverRectInDocument(row: Int, columnID: String) -> CGRect? {
            guard let documentView,
                  let model = rowProvider(row),
                  row >= 0,
                  row < rowCount
            else {
                return nil
            }
            let rowRect = rectForRow(row, width: documentView.bounds.width)
            guard let cellRect = dataCellRect(columnID: columnID, rowRect: rowRect) else {
                return nil
            }
            let measurement = cachedMeasurement(for: row, documentWidth: documentView.bounds.width)
                ?? SubtitleTableRowMeasurement(
                    height: rowRect.height,
                    primaryLineCount: 1,
                    extraCueLineCounts: []
                )
            if columnID == "cues" {
                return cuesContentHoverRect(
                    model: model,
                    in: cellRect,
                    measurement: measurement
                )
            }
            if columnID == "language" {
                return tagContentHoverRect(
                    tags: model.tags,
                    in: cellRect,
                    trailing: SubtitleTableMetrics.trailingInset
                )
            }
            return bodyContentHoverRect(
                text: text(for: columnID, model: model),
                in: cellRect,
                trailing: bodyTextTrailingInset(for: columnID, rowRect: rowRect),
                role: bodyTextRole(for: columnID)
            )
        }

        private func cellContentHoverFrameInContainer(for row: Int, columnID: String) -> CGRect? {
            guard let container,
                  let scrollView,
                  let documentView,
                  let documentFrame = cellContentHoverRectInDocument(row: row, columnID: columnID)
            else {
                return nil
            }
            let frame = container.convert(documentFrame, from: documentView)
            guard frame.intersects(scrollView.frame) else {
                return nil
            }
            return frame
        }

        private func rowMenuTriggerFrameInContainer(row: Int, columnID: String, fallback: CGRect) -> CGRect {
            cellContentHoverFrameInContainer(for: row, columnID: columnID) ??
                fallback
        }

        private func dataCellRect(columnID: String, rowRect: CGRect) -> CGRect? {
            let layout = tableColumnLayout(contentWidth: rowRect.width, height: rowRect.height)
            switch columnID {
            case "dateAdded":
                return layout.dateAddedRect.map { rowColumnRect($0, rowRect: rowRect) }
            case "display":
                guard showsDisplayTitleColumn else { return nil }
                return rowColumnRect(layout.nameRect, rowRect: rowRect)
            case "time":
                return layout.timeRect.map { rowColumnRect($0, rowRect: rowRect) }
            case "cues":
                return rowColumnRect(layout.cuesRect, rowRect: rowRect)
            case "language":
                return layout.languageRect.map { rowColumnRect($0, rowRect: rowRect) }
            default:
                return nil
            }
        }

        private func textFragments(
            row: Int,
            columnID: String,
            rowRect: CGRect
        ) -> [SubtitleTableTextFragmentLayout] {
            guard let model = rowProvider(row),
                  let cellRect = dataCellRect(columnID: columnID, rowRect: rowRect)
            else {
                return []
            }

            if columnID == "cues" {
                let measurement = cachedMeasurement(for: row, documentWidth: rowRect.width)
                    ?? SubtitleTableRowMeasurement(
                        height: rowRect.height,
                        primaryLineCount: 1,
                        extraCueLineCounts: []
                    )
                return cueTextFragments(model: model, in: cellRect, measurement: measurement)
            }

            if columnID == "language" {
                let tagStyle = SubtitleTableTagStyle.resolve(isRedesign: isRedesign)
                let laidOutTags = layoutTags(
                    model.tags,
                    in: cellRect,
                    trailing: SubtitleTableMetrics.trailingInset,
                    tagStyle: tagStyle
                )
                return tagTextFragments(laidOutTags, tagStyle: tagStyle)
            }

            let cellText = selectableText(for: columnID, model: model)
            guard !cellText.isEmpty else { return [] }
            let attributed = SubtitleTableText.body(
                cellText,
                role: bodyTextRole(for: columnID),
                isRedesign: isRedesign
            )
            let width = max(
                0,
                cellRect.width
                    - SubtitleTableMetrics.cellLeading
                    - bodyTextTrailingInset(for: columnID, rowRect: rowRect)
            )
            textLayout.update(attributedString: attributed, width: width)
            return [SubtitleTableTextFragmentLayout(
                attributed: attributed,
                origin: bodyTextOrigin(in: cellRect),
                width: width,
                clipRect: cellRect,
                logicalUTF16Range: NSRange(
                    location: 0,
                    length: (cellText as NSString).length
                )
            )]
        }

        private func textPosition(
            row: Int,
            columnID: String,
            point: CGPoint,
            requiresTextHit: Bool
        ) -> SubtitleTableTextPosition? {
            guard let documentView,
                  let columnIndex = visibleTextColumnOrder().firstIndex(of: columnID),
                  let model = rowProvider(row)
            else {
                return nil
            }
            let rowRect = rectForRow(row, width: documentView.bounds.width)
            let fragments = textFragments(row: row, columnID: columnID, rowRect: rowRect)
            if fragments.isEmpty {
                guard !requiresTextHit,
                      selectableText(for: columnID, model: model).isEmpty
                else {
                    return nil
                }
                return SubtitleTableTextPosition(
                    row: .body(row),
                    columnIndex: columnIndex,
                    utf16Offset: 0
                )
            }

            let candidate: SubtitleTableTextFragmentLayout?
            if requiresTextHit {
                candidate = fragments.first { fragment in
                    guard fragment.clipRect.contains(point) else { return false }
                    textLayout.update(attributedString: fragment.attributed, width: fragment.width)
                    return textLayout.containsText(at: point, origin: fragment.origin)
                }
            } else {
                candidate = fragments.min { lhs, rhs in
                    squaredDistance(from: point, to: textBounds(for: lhs))
                        < squaredDistance(from: point, to: textBounds(for: rhs))
                }
            }
            guard let candidate else { return nil }
            textLayout.update(attributedString: candidate.attributed, width: candidate.width)
            let localOffset = textLayout.utf16Offset(at: point, origin: candidate.origin)
            return SubtitleTableTextPosition(
                row: .body(row),
                columnIndex: columnIndex,
                utf16Offset: candidate.logicalUTF16Range.location + localOffset
            )
        }

        private func textPosition(
            atDocumentPoint point: CGPoint,
            requiresTextHit: Bool
        ) -> SubtitleTableTextPosition? {
            guard let documentView else {
                return nil
            }
            let row: Int
            if requiresTextHit {
                guard let exactRow = rowAtDocumentPoint(point) else { return nil }
                row = exactRow
            } else {
                guard rowCount > 0 else {
                    return projectedHeaderTextPosition(forDocumentPoint: point)
                }
                row = rowHeightCache.rowIndex(
                    atY: max(0, point.y - rowsOriginY)
                )
            }
            let rowRect = rectForRow(row, width: documentView.bounds.width)
            let columnIDs = visibleTextColumnOrder()
            let columnID: String?
            if requiresTextHit {
                columnID = columnIDs.first(where: {
                    dataCellRect(columnID: $0, rowRect: rowRect)?.contains(point) == true
                })
            } else {
                columnID = columnIDs.min { lhs, rhs in
                    let lhsRect = dataCellRect(columnID: lhs, rowRect: rowRect) ?? .zero
                    let rhsRect = dataCellRect(columnID: rhs, rowRect: rowRect) ?? .zero
                    return squaredDistance(from: point, to: lhsRect) <
                        squaredDistance(from: point, to: rhsRect)
                }
            }
            guard let columnID else {
                return nil
            }
            return textPosition(
                row: row,
                columnID: columnID,
                point: point,
                requiresTextHit: requiresTextHit
            )
        }

        private func projectedHeaderTextPosition(
            forDocumentPoint point: CGPoint
        ) -> SubtitleTableTextPosition? {
            guard let documentView, let headerView else { return nil }
            let windowPoint = documentView.convert(point, to: nil)
            var headerPoint = headerView.convert(windowPoint, from: nil)
            headerPoint.x = min(
                max(headerView.bounds.minX, headerPoint.x),
                headerView.bounds.maxX.nextDown
            )
            headerPoint.y = headerView.bounds.midY
            return headerTextPosition(at: headerPoint, requiresTextHit: false)
        }

        private func textPosition(
            atWindowPoint windowPoint: CGPoint,
            requiresTextHit: Bool
        ) -> SubtitleTableTextPosition? {
            if let headerView {
                let headerWindowRect = headerView.convert(headerView.bounds, to: nil)
                let projectsToHeader = headerWindowRect.contains(windowPoint) ||
                    (!requiresTextHit && windowPointProjectsToHeader(
                        windowPoint,
                        headerWindowRect: headerWindowRect
                    ))
                if projectsToHeader {
                    var point = headerView.convert(windowPoint, from: nil)
                    if !requiresTextHit {
                        point.x = min(max(headerView.bounds.minX, point.x), headerView.bounds.maxX)
                        point.y = min(max(headerView.bounds.minY, point.y), headerView.bounds.maxY)
                    }
                    return headerTextPosition(at: point, requiresTextHit: requiresTextHit)
                }
            }

            guard let documentView else { return nil }
            var point = documentView.convert(windowPoint, from: nil)
            if !requiresTextHit {
                let visibleRect = currentTableBodyVisibleRect
                guard !visibleRect.isEmpty else { return nil }
                point.x = min(max(visibleRect.minX, point.x), visibleRect.maxX.nextDown)
                point.y = min(max(visibleRect.minY, point.y), visibleRect.maxY.nextDown)
            }
            return textPosition(
                atDocumentPoint: point,
                requiresTextHit: requiresTextHit
            )
        }

        private func windowPointProjectsToHeader(
            _ windowPoint: CGPoint,
            headerWindowRect: CGRect
        ) -> Bool {
            if windowPoint.y >= headerWindowRect.minY,
               windowPoint.y <= headerWindowRect.maxY {
                return true
            }

            guard let scrollView else { return false }
            let bodyWindowRect = scrollView.convert(scrollView.bounds, to: nil)
            if bodyWindowRect.midY < headerWindowRect.midY {
                return windowPoint.y > headerWindowRect.maxY
            }
            if bodyWindowRect.midY > headerWindowRect.midY {
                return windowPoint.y < headerWindowRect.minY
            }
            return false
        }

        private func textBounds(for fragment: SubtitleTableTextFragmentLayout) -> CGRect {
            textLayout.update(attributedString: fragment.attributed, width: fragment.width)
            return (textLayout.unionUsedRect(at: fragment.origin) ?? CGRect(origin: fragment.origin, size: .zero))
                .intersection(fragment.clipRect)
        }

        private func squaredDistance(from point: CGPoint, to rect: CGRect) -> CGFloat {
            let dx = max(rect.minX - point.x, 0, point.x - rect.maxX)
            let dy = max(rect.minY - point.y, 0, point.y - rect.maxY)
            return dx * dx + dy * dy
        }

        private func actionMenuColumnID(row: Int, point: CGPoint) -> String? {
            guard isRedesign,
                  row >= 0,
                  row < rowCount,
                  rowProvider(row) != nil,
                  let documentView
            else {
                return nil
            }
            let rowRect = rectForRow(row, width: documentView.bounds.width)
            return visibleTextColumnOrder().first { columnID in
                dataCellRect(columnID: columnID, rowRect: rowRect)?.contains(point) == true
            }
        }

        private func hoveredDataColumnID(row: Int, point: CGPoint) -> String? {
            guard isRedesign,
                  !isSelectionMode,
                  row >= 0,
                  row < rowCount,
                  rowProvider(row) != nil
            else {
                return nil
            }
            if rowProvider(row)?.cueState.isUnavailable != true,
               let hoverRect = cellContentHoverRectInDocument(row: row, columnID: "cues"),
               hoverRect.contains(point) {
                return "cues"
            }
            return nil
        }

        private func isPointInCheckbox(row: Int, point: CGPoint) -> Bool {
            guard isRedesign,
                  isEnabled,
                  isSelectionMode,
                  !isExternalPopupLayerOpen,
                  row >= 0,
                  row < rowCount,
                  rowProvider(row) != nil,
                  let documentView
            else {
                return false
            }
            let rowRect = rectForRow(row, width: documentView.bounds.width)
            return checkboxRect(forRowRect: rowRect).contains(point)
        }

        private func isPointInCueText(row: Int, point: CGPoint) -> Bool {
            guard !isSelectionMode,
                  row >= 0,
                  row < rowCount,
                  let model = rowProvider(row),
                  !model.primaryCueText.isEmpty,
                  let hoverRect = cellContentHoverRectInDocument(row: row, columnID: "cues")
            else {
                return false
            }
            return hoverRect.contains(point)
        }

        private func isPointInCueStateIndicator(
            row: Int,
            point: CGPoint
        ) -> Bool {
            cueStateIndicatorRectInDocument(row: row)?
                .insetBy(dx: -3, dy: -3)
                .contains(point) == true
        }

        func handleMouseHover(windowPoint: CGPoint) {
            if isMenuOpen || isExternalPopupLayerOpen {
                return
            }
            guard let documentView else { return }
            let point = documentView.convert(windowPoint, from: nil)
            guard currentTableBodyVisibleRect.contains(point) else {
                clearHover()
                return
            }
            let row = rowAtDocumentPoint(point)
            updateHoveredRow(row)
            if isSelectionMode {
                updateHoveredCueStateRow(nil)
                updateHoveredColumnID(nil)
                updateHoveredRowActionRow(nil)
                updateHoveredCueTextRow(nil)
                return
            }
            let cueStateRow = row.flatMap {
                isPointInCueStateIndicator(row: $0, point: point) ? $0 : nil
            }
            updateHoveredCueStateRow(cueStateRow)
            let hoveredColumn = row.flatMap { hoveredDataColumnID(row: $0, point: point) }
            updateHoveredColumnID(hoveredColumn)
            let cueTextRow = row.flatMap {
                hoveredColumn == "cues"
                    && rowProvider($0)?.cueState.isUnavailable != true
                    && isPointInCueText(row: $0, point: point)
                    ? $0
                    : nil
            }
            updateHoveredRowActionRow(nil)
            updateHoveredCueTextRow(cueTextRow)
        }

        func handleMouseDown(windowPoint: CGPoint) -> Bool {
            guard isRedesign,
                  isEnabled,
                  !isMenuOpen,
                  !isExternalPopupLayerOpen,
                  let documentView
            else {
                return false
            }
            let point = documentView.convert(windowPoint, from: nil)
            guard currentTableBodyVisibleRect.contains(point) else {
                return false
            }
            let row = rowAtDocumentPoint(point)
            if isSelectionMode {
                guard let row else { return false }
                return toggleRowCheckboxFromMouse(row: row)
            }
            if let row, isPointInCheckbox(row: row, point: point) {
                return toggleRowCheckboxFromMouse(row: row)
            }
            if let row, isPointInCueStateIndicator(row: row, point: point) {
                clearFocusedCheckbox()
                cancelPendingTextInteraction()
                return true
            }

            let directAction: PendingDirectTextAction
            if let row,
               rowProvider(row)?.cueState.isUnavailable != true,
               isPointInCueText(row: row, point: point)
            {
                directAction = .play(row: row)
            } else {
                directAction = .none
            }
            let exactAnchor = textPosition(atDocumentPoint: point, requiresTextHit: true)
            let anchor = exactAnchor ?? (
                isNoDirectTextAction(directAction)
                    ? textPosition(atDocumentPoint: point, requiresTextHit: false)
                    : nil
            )
            guard anchor != nil || !isNoDirectTextAction(directAction) else {
                return false
            }

            clearFocusedCheckbox()
            pendingTextInteraction = PendingTextInteraction(
                startPoint: windowPoint,
                anchor: anchor,
                directAction: directAction,
                latestWindowPoint: windowPoint
            )
            return true
        }

        func handleHeaderMouseDown(windowPoint: CGPoint) -> Bool {
            guard isRedesign,
                  isEnabled,
                  !isSelectionMode,
                  !isMenuOpen,
                  !isExternalPopupLayerOpen,
                  let headerView
            else {
                return false
            }
            let point = headerView.convert(windowPoint, from: nil)
            guard headerView.bounds.contains(point),
                  let anchor = headerTextPosition(at: point, requiresTextHit: false)
            else {
                return false
            }

            let exactAnchor = headerTextPosition(at: point, requiresTextHit: true)
            let directAction: PendingDirectTextAction
            if let exactAnchor,
               let headerFragment = headerTextFragments().first(where: {
                   $0.columnIndex == exactAnchor.columnIndex
               })
            {
                directAction = .headerMenu(
                    columnID: headerFragment.columnID,
                    triggerFrame: headerFragment.cellRect
                )
            } else {
                directAction = .none
            }

            clearFocusedCheckbox()
            pendingTextInteraction = PendingTextInteraction(
                startPoint: windowPoint,
                anchor: anchor,
                directAction: directAction,
                latestWindowPoint: windowPoint
            )
            return true
        }

        func handleMouseDragged(windowPoint: CGPoint) -> Bool {
            guard var interaction = pendingTextInteraction else {
                return false
            }
            interaction.latestWindowPoint = windowPoint
            let distance = hypot(
                windowPoint.x - interaction.startPoint.x,
                windowPoint.y - interaction.startPoint.y
            )
            if distance >= Self.textDragThreshold {
                interaction.didDrag = true
            }
            if interaction.didDrag {
                beginPendingTextSelectionIfPossible(&interaction)
            }
            pendingTextInteraction = interaction
            if interaction.selectionHasBegun {
                updateTextSelectionFocus(atWindowPoint: windowPoint)
                updateTextDragAutoScrollState(for: interaction)
            }
            return true
        }

        func handleMouseUp(windowPoint: CGPoint) -> Bool {
            guard var interaction = pendingTextInteraction else {
                return false
            }
            stopTextDragAutoScroll()
            pendingTextInteraction = nil
            if hypot(
                windowPoint.x - interaction.startPoint.x,
                windowPoint.y - interaction.startPoint.y
            ) >= Self.textDragThreshold {
                interaction.didDrag = true
            }
            if interaction.didDrag {
                beginPendingTextSelectionIfPossible(&interaction)
            }
            if interaction.selectionHasBegun {
                updateTextSelectionFocus(atWindowPoint: windowPoint)
            }
            guard !interaction.didDrag else { return true }

            switch interaction.directAction {
            case .none:
                break
            case .play(let row):
                playRow(row)
            case .headerMenu(let columnID, let triggerFrame):
                showHeaderMenu(for: columnID, triggerFrame: triggerFrame)
            }
            return true
        }

        private func beginPendingTextSelectionIfPossible(
            _ interaction: inout PendingTextInteraction
        ) {
            guard !interaction.selectionHasBegun,
                  let anchor = interaction.anchor
            else {
                return
            }
            let previousSelection = textSelection
            textSelection.begin(at: anchor)
            interaction.selectionHasBegun = true
            invalidateTextSelectionChange(from: previousSelection)
        }

        private func isNoDirectTextAction(_ action: PendingDirectTextAction) -> Bool {
            if case .none = action {
                return true
            }
            return false
        }

        func handleRightMouseDown(windowPoint: CGPoint) -> Bool {
            guard isRedesign,
                  isEnabled,
                  !isMenuOpen,
                  !isExternalPopupLayerOpen,
                  let documentView,
                  let container
            else {
                return false
            }
            let point = documentView.convert(windowPoint, from: nil)
            if isSelectionMode {
                return currentTableBodyVisibleRect.contains(point)
                    && rowAtDocumentPoint(point) != nil
            }
            guard currentTableBodyVisibleRect.contains(point),
                  let row = rowAtDocumentPoint(point),
                  let columnID = actionMenuColumnID(row: row, point: point)
            else {
                return false
            }
            let anchorPoint = container.convert(point, from: documentView)
            let fallbackFrame = CGRect(origin: anchorPoint, size: .zero)
            showMenu(
                for: row,
                columnID: columnID,
                buttonFrame: fallbackFrame,
                clickPointInContainer: anchorPoint
            )
            return true
        }

        private func toggleRowCheckboxFromMouse(row: Int) -> Bool {
            guard isRedesign,
                  isEnabled,
                  isSelectionMode,
                  !isMenuOpen,
                  !isExternalPopupLayerOpen,
                  row >= 0,
                  row < rowCount
            else {
                return false
            }
            clearFocusedCheckbox()
            onToggleRowSelection(row)
            invalidateRows([row])
            headerView?.refreshHeaderHosts()
            return true
        }

        func handleKeyDown(_ event: NSEvent) -> Bool {
            guard isRedesign,
                  isEnabled,
                  isSelectionMode,
                  !isMenuOpen,
                  !isExternalPopupLayerOpen
            else {
                return false
            }

            switch event.keyCode {
            case 48:
                guard event.modifierFlags.intersection([.command, .control, .option]).isEmpty else {
                    return false
                }
                if moveFocusedCheckboxByTab(isShiftPressed: event.modifierFlags.contains(.shift)) {
                    return true
                }
                exitFocusedCheckboxByTab(isShiftPressed: event.modifierFlags.contains(.shift))
                return true
            case 49:
                guard let focusedCheckboxRow,
                      focusedCheckboxRow >= 0,
                      focusedCheckboxRow < rowCount
                else {
                    return false
                }
                onToggleRowSelection(focusedCheckboxRow)
                invalidateRows([focusedCheckboxRow])
                headerView?.refreshHeaderHosts()
                return true
            case 125:
                guard focusedCheckboxRow != nil else { return false }
                moveFocusedCheckbox(by: 1)
                return true
            case 126:
                guard focusedCheckboxRow != nil else { return false }
                moveFocusedCheckbox(by: -1)
                return true
            default:
                return false
            }
        }

        func clearFocusedCheckbox() {
            updateFocusedCheckbox(nil)
        }

        private func moveFocusedCheckbox(by delta: Int) {
            guard rowCount > 0 else {
                updateFocusedCheckbox(nil)
                return
            }
            let current = focusedCheckboxRow ?? hoveredRow ?? visibleRowRange()?.lowerBound ?? 0
            let next = min(max(0, current + delta), rowCount - 1)
            updateFocusedCheckbox(next)
            scrollFocusedCheckboxIntoVisible()
        }

        private func moveFocusedCheckboxByTab(isShiftPressed: Bool) -> Bool {
            guard let focusedCheckboxRow, rowCount > 0 else {
                return false
            }
            let next = focusedCheckboxRow + (isShiftPressed ? -1 : 1)
            guard next >= 0, next < rowCount else {
                return false
            }
            updateFocusedCheckbox(next)
            scrollFocusedCheckboxIntoVisible()
            return true
        }

        private func exitFocusedCheckboxByTab(isShiftPressed: Bool) {
            clearFocusedCheckbox()
            if isShiftPressed {
                documentView?.window?.selectPreviousKeyView(documentView)
            } else {
                documentView?.window?.selectNextKeyView(documentView)
            }
        }

        private func updateFocusedCheckbox(_ row: Int?) {
            let nextRow = row.flatMap { $0 >= 0 && $0 < rowCount ? $0 : nil }
            guard nextRow != focusedCheckboxRow else { return }
            let oldRow = focusedCheckboxRow
            focusedCheckboxRow = nextRow
            invalidateRows([oldRow, nextRow])
        }

        private func scrollFocusedCheckboxIntoVisible() {
            guard let focusedCheckboxRow, let documentView else { return }
            documentView.scrollToVisible(rectForRow(focusedCheckboxRow, width: documentView.bounds.width))
            notifyVisibleRowsChanged()
        }

        @discardableResult
        func focusFirstVisibleCheckboxFromKeyboard() -> Bool {
            guard isRedesign,
                  isEnabled,
                  rowCount > 0,
                  !isMenuOpen,
                  !isExternalPopupLayerOpen,
                  let documentView
            else {
                return false
            }
            guard let row = firstFocusableCheckboxRow(visibleRows: visibleRowRange()) else {
                return false
            }
            documentView.window?.makeFirstResponder(documentView)
            updateFocusedCheckbox(row)
            scrollFocusedCheckboxIntoVisible()
            return true
        }

        func firstFocusableCheckboxRowForTesting(visibleRows: Range<Int>?) -> Int? {
            firstFocusableCheckboxRow(visibleRows: visibleRows)
        }

        private func firstFocusableCheckboxRow(visibleRows: Range<Int>?) -> Int? {
            guard rowCount > 0 else { return nil }
            guard let visibleRows, visibleRows.lowerBound < visibleRows.upperBound else {
                return 0
            }
            return min(max(0, visibleRows.lowerBound), rowCount - 1)
        }

        private func installKeyboardFocusEventMonitor() {
            guard keyboardFocusEventMonitor == nil else { return }
            keyboardFocusEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
                guard let self else { return event }
                return self.handleKeyboardFocusEvent(event)
            }
        }

        private func handleKeyboardFocusEvent(_ event: NSEvent) -> NSEvent? {
            if let container,
               event.window === container.window,
               isMenuOpen,
               activeRowMenuTarget != nil,
               let rowActionSubmenuState
            {
                switch event.keyCode {
                case 53:
                    dismissMenu()
                    return nil
                case 124:
                    return rowActionSubmenuState.openHighlightedParent()
                        ? nil
                        : event
                case 123:
                    return rowActionSubmenuState.closeSubmenu()
                        ? nil
                        : event
                default:
                    break
                }
            }

            guard event.keyCode == 48,
                  let container,
                  event.window === container.window,
                  isRedesign,
                  isEnabled,
                  !isMenuOpen,
                  !isExternalPopupLayerOpen,
                  event.modifierFlags.intersection([.command, .control, .option, .shift]).isEmpty,
                  let firstResponder = event.window?.firstResponder,
                  headerView?.isLastInteractiveHeaderResponder(firstResponder) == true
            else {
                return event
            }
            return focusFirstVisibleCheckboxFromKeyboard() ? nil : event
        }

        func clearHover() {
            updateHoveredColumnID(nil)
            updateHoveredRow(nil)
            updateHoveredCueTextRow(nil)
            updateHoveredCueStateRow(nil)
            updateHoveredRowActionRow(nil)
        }

        private func updateHoveredRow(_ newRow: Int?) {
            if isMenuOpen || isExternalPopupLayerOpen {
                return
            }
            guard newRow != hoveredRow else { return }
            let oldRow = hoveredRow
            hoveredRow = newRow
            invalidateRows([oldRow, newRow])
            layoutHoverButtons()
        }

        private func updateHoveredColumnID(_ newColumnID: String?) {
            guard newColumnID != hoveredColumnID else { return }
            let row = hoveredRow
            hoveredColumnID = newColumnID
            invalidateRows([row])
        }

        private func updateHoveredCueTextRow(_ newRow: Int?) {
            guard newRow != hoveredCueTextRow else { return }
            let oldRow = hoveredCueTextRow
            hoveredCueTextRow = newRow
            invalidateRows([oldRow, newRow])
        }

        private func updateHoveredCueStateRow(_ newRow: Int?) {
            guard newRow != hoveredCueStateRow else {
                if let newRow {
                    showCueStateTip(for: newRow)
                }
                return
            }
            let oldRow = hoveredCueStateRow
            hoveredCueStateRow = newRow
            invalidateRows([oldRow, newRow])
            if let newRow {
                showCueStateTip(for: newRow)
            } else {
                hideCueStateTip()
            }
        }

        private func showCueStateTip(for row: Int) {
            guard let container,
                  let documentView,
                  let model = rowProvider(row),
                  model.cueState.systemImage != nil,
                  let documentRect = cueStateIndicatorRectInDocument(row: row)
            else {
                hideCueStateTip()
                return
            }
            let host: CueStateTipHostingView
            if let cueStateTipHost {
                host = cueStateTipHost
            } else {
                host = CueStateTipHostingView(rootView: AnyView(EmptyView()))
                cueStateTipHost = host
            }
            host.rootView = AnyView(CueStateTip(state: model.cueState))
            host.invalidateIntrinsicContentSize()
            if host.superview !== container {
                container.addSubview(host)
            }
            host.layoutSubtreeIfNeeded()

            let anchor = container.convert(documentRect, from: documentView)
            let fittingSize = host.fittingSize
            let size = CGSize(
                width: max(300, fittingSize.width),
                height: max(1, fittingSize.height)
            )
            host.frame = CueStateTipGeometry.frame(
                anchor: anchor,
                size: size,
                visibleRect: container.bounds
            )
            host.isHidden = false
        }

        private func hideCueStateTip() {
            cueStateTipHost?.isHidden = true
        }

        private func updateHoveredRowActionRow(_ newRow: Int?) {
            guard newRow != hoveredRowActionRow else { return }
            let oldRow = hoveredRowActionRow
            hoveredRowActionRow = newRow
            invalidateRows([oldRow, newRow])
        }

        private func invalidateRows(_ rows: [Int?]) {
            guard let documentView else { return }
            for row in rows.compactMap({ $0 }) where row >= 0 && row < rowCount {
                documentView.setNeedsDisplay(rectForRow(row, width: documentView.bounds.width))
            }
        }

        private func invalidateVisibleDocument() {
            guard let documentView else { return }
            documentView.setNeedsDisplay(documentView.visibleRect)
        }

        private func invalidateColumnLayoutChange(
            oldLayout: SubtitleTableColumnLayout,
            newLayout: SubtitleTableColumnLayout
        ) {
            guard let documentView,
                  let visibleRows = visibleRowRange()
            else {
                return
            }

            for row in visibleRows {
                let rowRect = rectForRow(row, width: documentView.bounds.width)
                for columnID in visibleTextColumnOrder() {
                    var dirtyRect = CGRect.null
                    if let oldColumnRect = oldLayout.rect(for: columnID) {
                        dirtyRect = dirtyRect.union(rowColumnRect(oldColumnRect, rowRect: rowRect))
                    }
                    if let newColumnRect = newLayout.rect(for: columnID) {
                        dirtyRect = dirtyRect.union(rowColumnRect(newColumnRect, rowRect: rowRect))
                    }
                    if !dirtyRect.isNull {
                        documentView.setNeedsDisplay(dirtyRect)
                    }
                }
            }
        }

        private func invalidateRows(for rowsUpdate: TableSandboxRowsUpdate, rowsChanged: Bool) {
            guard rowsChanged else { return }
            switch rowsUpdate {
            case .none:
                break
            case .append(let range):
                guard let visibleRows = visibleRowRange() else { return }
                let lowerBound = max(range.lowerBound, visibleRows.lowerBound)
                let upperBound = min(range.upperBound, visibleRows.upperBound)
                guard lowerBound < upperBound else { return }
                invalidateRows((lowerBound..<upperBound).map { Optional($0) })
            case .cells(let cells):
                invalidateCells(cells)
            case .reload:
                invalidateVisibleDocument()
            }
        }

        private func invalidateCells(_ cells: [TableSandboxCellInvalidation]) {
            guard let documentView else { return }
            for cell in cells where cell.row >= 0 && cell.row < rowCount {
                let rowRect = rectForRow(cell.row, width: documentView.bounds.width)
                if let cellRect = dataCellRect(columnID: cell.columnID, rowRect: rowRect) {
                    documentView.setNeedsDisplay(cellRect)
                }
            }
        }

        private func setScrollbarDragging(_ isDragging: Bool) {
            guard isScrollbarDragging != isDragging else { return }
            isScrollbarDragging = isDragging
            if isDragging, !isRedesign {
                buttonsHost?.isHidden = true
                updateHoveredCueTextRow(nil)
            } else {
                layoutHoverButtons()
            }
        }

        private func backingScaleFactor() -> CGFloat {
            documentView?.window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 1
        }

        private func layoutHoverButtons() {
            if isRedesign {
                buttonsHost?.isHidden = true
                return
            }

            guard !isScrollbarDragging,
                  let buttonsHost,
                  let documentView,
                  let hoveredRow,
                  hoveredRow >= 0,
                  hoveredRow < rowCount,
                  let model = rowProvider(hoveredRow)
            else {
                buttonsHost?.isHidden = true
                return
            }

            let buttonFrame: CGRect
            let M = SubtitleTableMetrics.self
            let rowRect = rectForRow(hoveredRow, width: documentView.bounds.width)
            let dateAddedWidth = showsDateAddedColumn ? M.dateAddedColumnWidth : 0
            let displayTitleWidth = showsDisplayTitleColumn ? M.nameColumnWidth : 0
            let timeWidth = showsTimeColumn ? M.timeColumnWidth : 0
            let x = M.indexColumnWidth + dateAddedWidth + displayTitleWidth + timeWidth + M.cellLeading
            let y = rowRect.minY + M.rowVerticalInset - 4
            buttonFrame = CGRect(x: x, y: y, width: 120, height: 28)

            buttonsHost.rootView = CueHoverButtons(
                isEnabled: isEnabled,
                onPlay: { [weak self] in self?.playRow(hoveredRow) },
                onCopy: { [weak self] in self?.copyRow(hoveredRow) }
            )

            buttonsHost.frame = buttonFrame
            buttonsHost.isHidden = model.cues.isEmpty
        }

        private func setMenuHost<Content: View>(_ content: Content, in container: NSView) {
            let wrapped = AnyView(content)
            if let menuHost {
                menuHost.rootView = wrapped
                menuHost.invalidateIntrinsicContentSize()
            } else {
                let host = SubtitleTableMenuHostingView(rootView: wrapped)
                host.wantsLayer = true
                host.layer?.masksToBounds = false
                host.onIntrinsicContentSizeInvalidated = { [weak self] in
                    self?.requestOpenMenuReposition()
                }
                container.addSubview(host)
                menuHost = host
            }
            menuOverlayView?.passthroughView = menuHost
        }

        private func setSubmenuHost<Content: View>(
            _ content: Content,
            in container: NSView
        ) {
            let wrapped = AnyView(content)
            if let submenuHost {
                submenuHost.rootView = wrapped
                submenuHost.invalidateIntrinsicContentSize()
            } else {
                let host = SubtitleTableMenuHostingView(rootView: wrapped)
                host.wantsLayer = true
                host.layer?.masksToBounds = false
                container.addSubview(host)
                submenuHost = host
            }
        }

        private func requestOpenMenuReposition() {
            guard isMenuOpen, !pendingMenuReposition else { return }
            pendingMenuReposition = true
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.pendingMenuReposition = false
                self.repositionOpenMenu()
            }
        }

        private func positionMenu(triggerFrameInContainer: CGRect, menuSize: CGSize) -> CGRect {
            let visibleRect = container?.bounds ?? .zero
            let M = SubtitleTableMetrics.self
            let menuWidth = menuSize.width
            let menuHeight = menuSize.height

            var menuX = triggerFrameInContainer.minX
            if menuX + menuWidth > visibleRect.maxX - M.trailingInset {
                menuX = max(visibleRect.minX, visibleRect.maxX - menuWidth - M.trailingInset)
            }

            var menuY = triggerFrameInContainer.minY - menuHeight - WorkbenchControlMetrics.redesignSpacing1
            if menuY < visibleRect.minY {
                menuY = triggerFrameInContainer.maxY + WorkbenchControlMetrics.redesignSpacing1
                if menuY + menuHeight > visibleRect.maxY {
                    menuY = max(visibleRect.minY, visibleRect.maxY - menuHeight)
                }
            }

            return CGRect(x: menuX, y: menuY, width: menuWidth, height: menuHeight)
        }

        private func positionMenuBelowClick(clickPointInContainer: CGPoint, menuSize: CGSize) -> CGRect {
            let visibleRect = container?.bounds ?? .zero
            let M = SubtitleTableMetrics.self
            let gap = WorkbenchControlMetrics.redesignSpacing1
            let menuWidth = menuSize.width
            let menuHeight = menuSize.height

            var menuX = clickPointInContainer.x
            if menuX + menuWidth > visibleRect.maxX - M.trailingInset {
                menuX = max(visibleRect.minX, visibleRect.maxX - menuWidth - M.trailingInset)
            }
            menuX = max(visibleRect.minX, menuX)

            var menuY = clickPointInContainer.y - menuHeight - gap
            if menuY < visibleRect.minY {
                menuY = clickPointInContainer.y + gap
                if menuY + menuHeight > visibleRect.maxY {
                    menuY = max(visibleRect.minY, visibleRect.maxY - menuHeight)
                }
            }

            return CGRect(x: menuX, y: menuY, width: menuWidth, height: menuHeight)
        }

        func showMenu(
            for row: Int,
            columnID: String = "cues",
            buttonFrame: CGRect,
            clickPointInContainer: CGPoint? = nil
        ) {
            guard !isSelectionMode,
                  row >= 0,
                  row < rowCount,
                  let target = rowProvider(row)
            else {
                return
            }
            cancelPendingTextInteraction()
            updateHoveredCueStateRow(nil)
            isMenuOpen = true
            activeRowMenuRow = row
            activeRowMenuColumnID = columnID
            activeRowMenuTarget = target
            activeMenuAnchor = .row(
                row: row,
                columnID: columnID,
                anchorFrame: buttonFrame,
                clickPointInContainer: clickPointInContainer
            )
            layoutHoverButtons()
            invalidateRows([row])

            guard let container = self.container else {
                isMenuOpen = false
                activeRowMenuRow = nil
                activeRowMenuColumnID = nil
                activeRowMenuTarget = nil
                activeMenuAnchor = nil
                return
            }

            if menuOverlayView == nil {
                let overlay = SubtitleTableMenuOverlayView()
                overlay.onClick = { [weak self] in
                    self?.dismissMenu()
                }
                container.addSubview(overlay)
                menuOverlayView = overlay
            }
            menuOverlayView?.frame = container.bounds
            menuOverlayView?.isHidden = false

            let submenuState = SubtitleTableRowActionSubmenuState()
            rowActionSubmenuState = submenuState
            submenuState.onOpenParentChange = { [weak self] action in
                guard let self else {
                    return
                }
                if let action {
                    self.showRowActionDestinationSubmenu(for: action)
                } else {
                    self.hideRowActionDestinationSubmenu()
                }
            }
            let menuView = RowActionMenu(
                style: rowActionMenuStyle,
                showsCueGroup: showsCueGroup,
                canOpenFolder: canOpenSubtitleFile(target: target),
                disabledActions: disabledRowActions(for: target),
                destinations: rowActionDestinations,
                submenuState: submenuState,
                onAction: { [weak self] action in
                    self?.performActiveRowMenuAction(action)
                }
            )

            setMenuHost(menuView, in: container)

            if let menuOverlayView {
                container.addSubview(menuOverlayView)
            }
            if let menuHost {
                container.addSubview(menuHost)
            }

            menuHost?.layout()
            let menuSize = menuHost?.fittingSize ?? CGSize(width: 172, height: 128)

            let finalMenuFrame: CGRect
            if let clickPointInContainer {
                finalMenuFrame = positionMenuBelowClick(
                    clickPointInContainer: clickPointInContainer,
                    menuSize: menuSize
                )
            } else {
                let triggerFrameInContainer = rowMenuTriggerFrameInContainer(
                    row: row,
                    columnID: columnID,
                    fallback: buttonFrame
                )
                finalMenuFrame = positionMenu(triggerFrameInContainer: triggerFrameInContainer, menuSize: menuSize)
            }

            menuHost?.frame = finalMenuFrame
            menuHost?.isHidden = false

            installMenuDismissMonitor()
        }

        private func showRowActionDestinationSubmenu(
            for action: SubtitleTableRowAction
        ) {
            guard isMenuOpen,
                  let container,
                  let submenuState = rowActionSubmenuState,
                  let parentItemFrame = submenuState.parentItemFrame(
                    for: action
                  )
            else {
                return
            }
            let submenuView = RowActionDestinationSubmenu(
                destinations: rowActionDestinations,
                submenuState: submenuState,
                onDestinationAction: { [weak self] destination in
                    self?.performActiveRowMenuDestinationAction(
                        action,
                        destinationID: destination.id
                    )
                }
            )
            setSubmenuHost(submenuView, in: container)
            guard let menuHost,
                  let submenuHost
            else {
                return
            }
            container.addSubview(submenuHost)
            submenuHost.layoutSubtreeIfNeeded()
            submenuHost.frame = SubtitleTableRowActionSubmenuGeometry.frame(
                parentMenuFrame: menuHost.frame,
                parentItemFrame: parentItemFrame,
                submenuSize: submenuHost.fittingSize,
                visibleRect: container.bounds
            )
            submenuHost.isHidden = false
        }

        private func hideRowActionDestinationSubmenu() {
            submenuHost?.rootView = AnyView(EmptyView())
            submenuHost?.invalidateIntrinsicContentSize()
            submenuHost?.isHidden = true
        }

        func showHeaderMenu(for columnID: String, triggerFrame: CGRect) {
            guard !isSelectionMode else { return }
            cancelPendingTextInteraction()
            isMenuOpen = true
            activeRowMenuRow = nil
            activeRowMenuColumnID = nil
            activeRowMenuTarget = nil
            activeHeaderMenuColumnID = columnID
            activeMenuAnchor = .header(triggerFrame: triggerFrame)
            layoutHoverButtons()
            headerView?.refreshHeaderHosts()

            guard let container = self.container, let headerView = self.headerView else {
                isMenuOpen = false
                activeHeaderMenuColumnID = nil
                activeRowMenuColumnID = nil
                activeRowMenuTarget = nil
                activeMenuAnchor = nil
                return
            }

            if menuOverlayView == nil {
                let overlay = SubtitleTableMenuOverlayView()
                overlay.onClick = { [weak self] in
                    self?.dismissMenu()
                }
                container.addSubview(overlay)
                menuOverlayView = overlay
            }
            menuOverlayView?.frame = container.bounds
            menuOverlayView?.isHidden = false

            let sortDirection = (sortedColumnID == columnID) ? self.sortDirection : nil
            let menuView = ColumnHeaderMenu(
                sortDirection: sortDirection,
                onSortAscending: { [weak self] in
                    self?.sortedColumnID = columnID
                    self?.sortDirection = .asc
                    self?.dismissMenu()
                },
                onSortDescending: { [weak self] in
                    self?.sortedColumnID = columnID
                    self?.sortDirection = .desc
                    self?.dismissMenu()
                }
            )

            setMenuHost(menuView, in: container)

            if let menuOverlayView {
                container.addSubview(menuOverlayView)
            }
            if let menuHost {
                container.addSubview(menuHost)
            }

            menuHost?.layout()
            let menuSize = menuHost?.fittingSize ?? CGSize(width: 172, height: 128)

            let triggerFrameInContainer = container.convert(triggerFrame, from: headerView)
            let finalMenuFrame = positionMenu(triggerFrameInContainer: triggerFrameInContainer, menuSize: menuSize)

            menuHost?.frame = finalMenuFrame
            menuHost?.isHidden = false

            installMenuDismissMonitor()
        }

        func dismissMenu(recalculateHover: Bool = true) {
            let previousRowMenuRow = activeRowMenuRow
            let previousHoveredRow = hoveredRow
            isMenuOpen = false
            activeHeaderMenuColumnID = nil
            activeRowMenuRow = nil
            activeRowMenuColumnID = nil
            activeRowMenuTarget = nil
            rowActionSubmenuState?.reset()
            rowActionSubmenuState = nil
            activeMenuAnchor = nil
            updateHoveredColumnID(nil)
            updateHoveredCueTextRow(nil)
            updateHoveredRowActionRow(nil)
            menuHost?.rootView = AnyView(EmptyView())
            menuHost?.invalidateIntrinsicContentSize()
            menuHost?.isHidden = true
            hideRowActionDestinationSubmenu()
            menuOverlayView?.isHidden = true
            menuOverlayView?.passthroughView = nil
            invalidateDocumentCursorRects()
            removeMenuDismissMonitor()
            headerView?.refreshHeaderHosts()
            invalidateRows([previousRowMenuRow, previousHoveredRow])

            guard recalculateHover else { return }

            if let window = documentView?.window {
                handleMouseHover(windowPoint: window.mouseLocationOutsideOfEventStream)
                DispatchQueue.main.async { [weak self, weak window] in
                    guard let self, let window, !self.isMenuOpen else { return }
                    self.invalidateDocumentCursorRects()
                    self.refreshDocumentCursor(windowPoint: window.mouseLocationOutsideOfEventStream)
                }
            } else {
                layoutHoverButtons()
            }
        }

        private func installMenuDismissMonitor() {
            removeMenuDismissMonitor()
            menuEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
                guard let self else { return event }
                guard let container = self.container else { return event }
                if self.shouldDismissOpenMenu(
                    isEventInContainerWindow: event.window === container.window,
                    windowPoint: event.locationInWindow
                ) {
                    DispatchQueue.main.async {
                        self.dismissMenu()
                    }
                }
                return event
            }
        }

        private func shouldDismissOpenMenu(isEventInContainerWindow: Bool, windowPoint: CGPoint) -> Bool {
            guard isMenuOpen else { return false }
            guard !suspendsMenuOutsideClickDismiss else { return false }
            guard isEventInContainerWindow else { return true }
            return !isWindowPointInsideOpenMenu(windowPoint)
        }

        private func isWindowPointInsideOpenMenu(_ windowPoint: CGPoint) -> Bool {
            if let menuHost, !menuHost.isHidden {
                let point = menuHost.convert(windowPoint, from: nil)
                if menuHost.bounds.contains(point) {
                    return true
                }
            }
            if let submenuHost, !submenuHost.isHidden {
                let point = submenuHost.convert(windowPoint, from: nil)
                if submenuHost.bounds.contains(point) {
                    return true
                }
            }
            return false
        }

        private func repositionOpenMenu() {
            guard isMenuOpen,
                  let container,
                  let menuHost,
                  !menuHost.isHidden,
                  let activeMenuAnchor
            else {
                return
            }

            menuOverlayView?.frame = container.bounds
            menuOverlayView?.isHidden = false

            menuHost.layoutSubtreeIfNeeded()
            let menuSize = menuHost.fittingSize
            let resolvedMenuSize = CGSize(
                width: menuSize.width > 0 ? menuSize.width : menuHost.frame.width,
                height: menuSize.height > 0 ? menuSize.height : menuHost.frame.height
            )

            let finalMenuFrame: CGRect
            switch activeMenuAnchor {
            case .row(let row, let columnID, let anchorFrame, let clickPointInContainer):
                if let clickPointInContainer {
                    finalMenuFrame = positionMenuBelowClick(
                        clickPointInContainer: clickPointInContainer,
                        menuSize: resolvedMenuSize
                    )
                } else {
                    let triggerFrameInContainer = rowMenuTriggerFrameInContainer(
                        row: row,
                        columnID: columnID,
                        fallback: anchorFrame
                    )
                    finalMenuFrame = positionMenu(
                        triggerFrameInContainer: triggerFrameInContainer,
                        menuSize: resolvedMenuSize
                    )
                }
            case .header(let triggerFrame):
                guard let headerView else { return }
                let triggerFrameInContainer = container.convert(triggerFrame, from: headerView)
                finalMenuFrame = positionMenu(
                    triggerFrameInContainer: triggerFrameInContainer,
                    menuSize: resolvedMenuSize
                )
            }

            menuHost.frame = finalMenuFrame
            if let openParent = rowActionSubmenuState?.openParent {
                showRowActionDestinationSubmenu(for: openParent)
            }
        }

        private func removeMenuDismissMonitor() {
            if let monitor = menuEventMonitor {
                NSEvent.removeMonitor(monitor)
                menuEventMonitor = nil
            }
        }

        private func playRow(_ row: Int) {
            guard !isSelectionMode,
                  let model = rowProvider(row),
                  !model.cueState.isUnavailable
            else {
                return
            }
            onPlay(model)
        }

        private func performActiveRowMenuAction(
            _ action: SubtitleTableRowAction,
            recalculateHover: Bool = true
        ) {
            guard let target = activeRowMenuTarget else { return }
            dismissMenu(recalculateHover: recalculateHover)
            performRowAction(action, target: target)
        }

        private func performActiveRowMenuDestinationAction(
            _ action: SubtitleTableRowAction,
            destinationID: Int64,
            recalculateHover: Bool = true
        ) {
            guard let target = activeRowMenuTarget else {
                return
            }
            guard !disabledRowActions(for: target).contains(action) else {
                return
            }
            dismissMenu(recalculateHover: recalculateHover)
            switch action {
            case .moveToList:
                onMoveShiori(target, destinationID)
            case .duplicateToList:
                onDuplicateShiori(target, destinationID)
            default:
                break
            }
        }

        private func performRowAction(_ action: SubtitleTableRowAction, row: Int) {
            guard let target = rowProvider(row) else { return }
            performRowAction(action, target: target)
        }

        private func performRowAction(
            _ action: SubtitleTableRowAction,
            target: SubtitleTableRow
        ) {
            guard !disabledRowActions(for: target).contains(action) else {
                return
            }
            switch action {
            case .play:
                onPlay(target)
            case .openSubtitleFolder:
                openSubtitleFile(target: target)
            case .copyCueText:
                copyRow(target: target)
            case .copyDeepLink:
                copyDeepLink(target: target)
            case .copyCueGroupText:
                copyCueGroup(target: target)
            case .copyTimeRange:
                copyCellText(target: target, columnID: "time")
            case .moveToList, .duplicateToList:
                break
            case .removeShiori:
                onRemoveShiori(target)
            }
        }

        private func disabledRowActions(
            for target: SubtitleTableRow
        ) -> Set<SubtitleTableRowAction> {
            var actions = target.cueState.disabledRowActions
            if target.primaryCueID.map({ $0 <= 0 }) ?? true {
                actions.insert(.copyDeepLink)
            }
            return actions
        }

        private func copyRow(_ row: Int) {
            guard let model = rowProvider(row) else { return }
            copyRow(target: model)
        }

        private func copyRow(target: SubtitleTableRow) {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(target.primaryCueText, forType: .string)
        }

        private func copyDeepLink(target: SubtitleTableRow) {
            guard let cueID = target.primaryCueID else { return }
            _ = CueClipboard.copyDeepLink(
                cueText: target.primaryCueText,
                cueID: cueID,
                to: .general
            )
        }

        private func copyCueGroup(_ row: Int) {
            guard let model = rowProvider(row) else { return }
            copyCueGroup(target: model)
        }

        private func copyCueGroup(target: SubtitleTableRow) {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(target.cueGroupCopyText, forType: .string)
        }

        private func copyCellText(row: Int, columnID: String) {
            guard let model = rowProvider(row) else { return }
            copyCellText(target: model, columnID: columnID)
        }

        private func copyCellText(target: SubtitleTableRow, columnID: String) {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(text(for: columnID, model: target), forType: .string)
        }

        private func canOpenSubtitleFile(target: SubtitleTableRow) -> Bool {
            !target.subtitlePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        private func openSubtitleFile(row: Int) {
            guard let model = rowProvider(row) else { return }
            openSubtitleFile(target: model)
        }

        private func openSubtitleFile(target: SubtitleTableRow) {
            let path = target.subtitlePath.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !path.isEmpty else { return }
            onOpenSubtitleFile(path)
        }

        private func scheduleResizeAfterDrawing() {
            resizeDocument()
        }
    }
}

// MARK: - Header Cell and Header Menu Views

struct SubtitleTableHeaderCellView: View {
    let title: String
    let columnID: String
    let isSortable: Bool
    let isEnabled: Bool
    let sortDirection: SubtitleTableView.Coordinator.TableSortDirection?
    let isMenuOpen: Bool
    let columnRect: CGRect
    let onTrigger: (CGRect) -> Void

    @FocusState private var isFocused: Bool
    @State private var isHovered = false
    @State private var hasPushedCursor = false
    @State private var triggerWidth: CGFloat = 0

    var body: some View {
        HStack(spacing: 0) {
            if isSortable {
                Button(action: {
                    let triggerRect = CGRect(
                        x: columnRect.minX,
                        y: columnRect.minY,
                        width: triggerWidth,
                        height: columnRect.height
                    )
                    onTrigger(triggerRect)
                }) {
                    buttonContent
                        .background(
                            GeometryReader { geo in
                                Color.clear
                                    .onAppear { triggerWidth = geo.size.width }
                                    .onChange(of: geo.size.width) { newValue in triggerWidth = newValue }
                            }
                        )
                }
                .buttonStyle(.plain)
                .disabled(!isEnabled)
                .subtitleTableTextSelectionInteractiveRegion(isActive: isEnabled)
                .focused($isFocused)
                .disableFocusEffect()
                .overlay(
                    Group {
                        if isFocused && isEnabled {
                            RoundedRectangle(
                                cornerRadius: WorkbenchControlMetrics.redesignFieldRadius + WorkbenchControlMetrics.redesignFocusRingPathExpansion,
                                style: .continuous
                            )
                            .stroke(WorkbenchRedesignColors.focusRing, lineWidth: WorkbenchControlMetrics.redesignFocusRingWidth)
                            .padding(-WorkbenchControlMetrics.redesignFocusRingPathExpansion)
                        }
                    }
                )
                .contentShape(Rectangle())
                .onHover { inside in
                    if isEnabled {
                        isHovered = inside
                        updateCursor(inside: inside)
                    } else {
                        isHovered = false
                    }
                }
                .onChange(of: isEnabled) { newValue in
                    if isHovered {
                        if hasPushedCursor {
                            NSCursor.pop()
                            hasPushedCursor = false
                        }
                        if newValue {
                            NSCursor.pointingHand.push()
                        }
                        hasPushedCursor = newValue
                    }
                }
                .onDisappear {
                    if hasPushedCursor {
                        NSCursor.pop()
                        hasPushedCursor = false
                    }
                }
            } else {
                staticContent
            }
            Spacer(minLength: 0)
        }
        .frame(width: columnRect.width, height: columnRect.height, alignment: .leading)
    }

    private var buttonContent: some View {
        HStack(spacing: WorkbenchControlMetrics.redesignSpacing2) {
            Text(title)
                .font(.system(size: WorkbenchControlMetrics.redesignFontSizeTableHeader, weight: .medium))
                .foregroundStyle(textColor)
                .lineLimit(1)
            
            Image(systemName: sortIconName)
                .font(.system(
                    size: WorkbenchControlMetrics.redesignSelectIndicatorSymbolFontSizeMacOS,
                    weight: WorkbenchControlMetrics.redesignSelectIndicatorWeightMacOS
                ))
                .foregroundStyle(iconColor)
        }
        .padding(.horizontal, WorkbenchControlMetrics.redesignPaddingHeaderTriggerX)
        .frame(maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: WorkbenchControlMetrics.redesignFieldRadius, style: .continuous)
                .fill((isHovered || isMenuOpen) && isEnabled ? WorkbenchRedesignColors.bgHover : Color.clear)
        )
    }

    private var staticContent: some View {
        HStack(spacing: 0) {
            Text(title)
                .font(.system(size: WorkbenchControlMetrics.redesignFontSizeTableHeader, weight: .medium))
                .foregroundStyle(isEnabled ? WorkbenchRedesignColors.textSecondary : WorkbenchRedesignColors.textDisabled)
                .lineLimit(1)
        }
        .padding(.horizontal, WorkbenchControlMetrics.redesignPaddingHeaderTriggerX)
        .frame(maxHeight: .infinity)
    }

    private var textColor: Color {
        guard isEnabled else { return WorkbenchRedesignColors.textDisabled }
        return WorkbenchRedesignColors.textSecondary
    }

    private var iconColor: Color {
        guard isEnabled else { return WorkbenchRedesignColors.iconDisabled }
        return WorkbenchRedesignColors.iconDefault
    }

    private var sortIconName: String {
        switch sortDirection {
        case .asc:
            return "arrow.up"
        case .desc:
            return "arrow.down"
        case nil:
            return "chevron.up.chevron.down"
        }
    }

    private func updateCursor(inside: Bool) {
        if inside {
            if !hasPushedCursor {
                if isEnabled {
                    NSCursor.pointingHand.push()
                }
                hasPushedCursor = isEnabled
            }
        } else {
            if hasPushedCursor {
                NSCursor.pop()
                hasPushedCursor = false
            }
        }
    }
}

struct ColumnHeaderMenu: View {
    let sortDirection: SubtitleTableView.Coordinator.TableSortDirection?
    let onSortAscending: () -> Void
    let onSortDescending: () -> Void

    var body: some View {
        WorkbenchPopoverPanel(isRedesign: true) {
            VStack(spacing: 0) {
                WorkbenchPopoverRow(
                    title: "Sort Ascending",
                    isSelected: false,
                    isHighlighted: sortDirection == .asc,
                    systemImage: "arrow.up",
                    isRedesign: true,
                    showsCheckmarkSlot: false,
                    isEnabled: true,
                    action: onSortAscending
                )
                WorkbenchPopoverRow(
                    title: "Sort Descending",
                    isSelected: false,
                    isHighlighted: sortDirection == .desc,
                    systemImage: "arrow.down",
                    isRedesign: true,
                    showsCheckmarkSlot: false,
                    isEnabled: true,
                    action: onSortDescending
                )
            }
        }
    }
}
