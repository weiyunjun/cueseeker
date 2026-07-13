import AppKit
import SwiftUI

// MARK: - Metrics

enum SubtitleTableMetrics {
    static let indexColumnWidth: CGFloat = 50
    static let dateAddedColumnWidth: CGFloat = 160
    static let timeColumnWidth: CGFloat = 190
    static let nameColumnWidth: CGFloat = 240
    static let cuesColumnMinimumWidth: CGFloat = 520
    static let speakerColumnWidth: CGFloat = 180
    static let languageColumnWidth: CGFloat = 160
    static let tagsColumnWidth: CGFloat = 180
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
    static var checkboxLeadingInset: CGFloat { (indexColumnWidth - checkboxSize) / 2 }
    static let checkboxCornerRadius: CGFloat = 4
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

struct SubtitleTableColumnLayout: Equatable {
    var indexRect: CGRect
    var dateAddedRect: CGRect?
    var nameRect: CGRect
    var timeRect: CGRect?
    var cuesRect: CGRect
    var speakerRect: CGRect?
    var languageRect: CGRect?
    var tagsRect: CGRect?
    var contentWidth: CGFloat

    private static let defaultTextColumnOrder = [
        "display",
        "cues",
        "tags",
        "time",
        "dateAdded",
        "speaker",
        "language",
    ]

    static func minimumContentWidth(
        showsDateAddedColumn: Bool = false,
        showsDisplayTitleColumn: Bool = true,
        showsTimeColumn: Bool = false,
        showsSpeakerColumn: Bool,
        showsLanguageColumn: Bool,
        showsTagsColumn: Bool = false,
        cuesMinimumWidth: CGFloat
    ) -> CGFloat {
        let M = SubtitleTableMetrics.self
        let dateAddedWidth = showsDateAddedColumn ? M.dateAddedColumnWidth : 0
        let displayTitleWidth = showsDisplayTitleColumn ? M.nameColumnWidth : 0
        let timeWidth = showsTimeColumn ? M.timeColumnWidth : 0
        let speakerWidth = showsSpeakerColumn ? M.speakerColumnWidth : 0
        let languageWidth = showsLanguageColumn ? M.languageColumnWidth : 0
        let tagsWidth = showsTagsColumn ? M.tagsColumnWidth : 0
        return M.indexColumnWidth + dateAddedWidth + displayTitleWidth + timeWidth + cuesMinimumWidth + speakerWidth + languageWidth + tagsWidth
    }

    static func resolve(
        contentWidth: CGFloat,
        height: CGFloat,
        showsDateAddedColumn: Bool = false,
        showsDisplayTitleColumn: Bool = true,
        showsTimeColumn: Bool = false,
        showsSpeakerColumn: Bool,
        showsLanguageColumn: Bool,
        showsTagsColumn: Bool = false,
        cuesMinimumWidth: CGFloat,
        columnOrder: [String] = [],
        expandsToMinimumContentWidth: Bool = true
    ) -> SubtitleTableColumnLayout {
        let M = SubtitleTableMetrics.self
        let minimumWidth = minimumContentWidth(
            showsDateAddedColumn: showsDateAddedColumn,
            showsDisplayTitleColumn: showsDisplayTitleColumn,
            showsTimeColumn: showsTimeColumn,
            showsSpeakerColumn: showsSpeakerColumn,
            showsLanguageColumn: showsLanguageColumn,
            showsTagsColumn: showsTagsColumn,
            cuesMinimumWidth: cuesMinimumWidth
        )
        let resolvedContentWidth = expandsToMinimumContentWidth
            ? max(0, contentWidth, minimumWidth)
            : max(0, contentWidth)
        let dateAddedWidth = showsDateAddedColumn ? M.dateAddedColumnWidth : 0
        let displayTitleWidth = showsDisplayTitleColumn ? M.nameColumnWidth : 0
        let timeWidth = showsTimeColumn ? M.timeColumnWidth : 0
        let speakerWidth = showsSpeakerColumn ? M.speakerColumnWidth : 0
        let languageWidth = showsLanguageColumn ? M.languageColumnWidth : 0
        let tagsWidth = showsTagsColumn ? M.tagsColumnWidth : 0
        let cuesWidth = max(
            cuesMinimumWidth,
            resolvedContentWidth - M.indexColumnWidth - dateAddedWidth - displayTitleWidth - timeWidth - speakerWidth - languageWidth - tagsWidth
        )

        var x: CGFloat = 0
        let indexRect = CGRect(x: x, y: 0, width: M.indexColumnWidth, height: height)
        x += M.indexColumnWidth
        var dateAddedRect: CGRect?
        var nameRect = CGRect(x: x, y: 0, width: 0, height: height)
        var timeRect: CGRect?
        var cuesRect = CGRect(x: x, y: 0, width: cuesWidth, height: height)
        var speakerRect: CGRect?
        var languageRect: CGRect?
        var tagsRect: CGRect?

        for columnID in resolvedTextColumnOrder(
            columnOrder,
            showsDateAddedColumn: showsDateAddedColumn,
            showsDisplayTitleColumn: showsDisplayTitleColumn,
            showsTimeColumn: showsTimeColumn,
            showsSpeakerColumn: showsSpeakerColumn,
            showsLanguageColumn: showsLanguageColumn,
            showsTagsColumn: showsTagsColumn
        ) {
            switch columnID {
            case "dateAdded":
                dateAddedRect = CGRect(x: x, y: 0, width: M.dateAddedColumnWidth, height: height)
                x += M.dateAddedColumnWidth
            case "display":
                nameRect = CGRect(x: x, y: 0, width: displayTitleWidth, height: height)
                x += displayTitleWidth
            case "time":
                timeRect = CGRect(x: x, y: 0, width: M.timeColumnWidth, height: height)
                x += M.timeColumnWidth
            case "cues":
                cuesRect = CGRect(x: x, y: 0, width: cuesWidth, height: height)
                x += cuesWidth
            case "speaker":
                speakerRect = CGRect(x: x, y: 0, width: M.speakerColumnWidth, height: height)
                x += M.speakerColumnWidth
            case "language":
                languageRect = CGRect(x: x, y: 0, width: M.languageColumnWidth, height: height)
                x += M.languageColumnWidth
            case "tags":
                tagsRect = CGRect(x: x, y: 0, width: M.tagsColumnWidth, height: height)
                x += M.tagsColumnWidth
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
            speakerRect: speakerRect,
            languageRect: languageRect,
            tagsRect: tagsRect,
            contentWidth: resolvedContentWidth
        )
    }

    static func resolvedTextColumnOrder(
        _ columnOrder: [String],
        showsDateAddedColumn: Bool = false,
        showsDisplayTitleColumn: Bool = true,
        showsTimeColumn: Bool = false,
        showsSpeakerColumn: Bool,
        showsLanguageColumn: Bool,
        showsTagsColumn: Bool = false
    ) -> [String] {
        var result: [String] = []
        for columnID in columnOrder + defaultTextColumnOrder
        where !result.contains(columnID) && isTextColumnVisible(
            columnID,
            showsDateAddedColumn: showsDateAddedColumn,
            showsDisplayTitleColumn: showsDisplayTitleColumn,
            showsTimeColumn: showsTimeColumn,
            showsSpeakerColumn: showsSpeakerColumn,
            showsLanguageColumn: showsLanguageColumn,
            showsTagsColumn: showsTagsColumn
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
        case "speaker":
            return speakerRect
        case "language":
            return languageRect
        case "tags":
            return tagsRect
        default:
            return nil
        }
    }

    func isCuesOnlyWidthChange(from previous: SubtitleTableColumnLayout) -> Bool {
        indexRect.size == previous.indexRect.size &&
            dateAddedRect?.size == previous.dateAddedRect?.size &&
            nameRect.size == previous.nameRect.size &&
            timeRect?.size == previous.timeRect?.size &&
            speakerRect?.size == previous.speakerRect?.size &&
            languageRect?.size == previous.languageRect?.size &&
            tagsRect?.size == previous.tagsRect?.size &&
            cuesRect.origin == previous.cuesRect.origin &&
            cuesRect.height == previous.cuesRect.height &&
            cuesRect.width != previous.cuesRect.width
    }

    private static func isTextColumnVisible(
        _ columnID: String,
        showsDateAddedColumn: Bool,
        showsDisplayTitleColumn: Bool,
        showsTimeColumn: Bool,
        showsSpeakerColumn: Bool,
        showsLanguageColumn: Bool,
        showsTagsColumn: Bool
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
        case "speaker":
            return showsSpeakerColumn
        case "language":
            return showsLanguageColumn
        case "tags":
            return showsTagsColumn
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
        showsSpeakerColumn: Bool,
        showsLanguageColumn: Bool,
        showsTagsColumn: Bool = false
    ) -> SubtitleTableColumnLayout {
        let M = SubtitleTableMetrics.self
        let dateAddedWidth = showsDateAddedColumn ? M.dateAddedColumnWidth : 0
        let displayTitleWidth = showsDisplayTitleColumn ? M.nameColumnWidth : 0
        let timeWidth = showsTimeColumn ? M.timeColumnWidth : 0
        let languageWidth = showsLanguageColumn ? M.languageColumnWidth : 0
        let speakerWidth = showsSpeakerColumn ? M.speakerColumnWidth : 0
        let tagsWidth = showsTagsColumn ? M.tagsColumnWidth : 0
        let cuesWidth = max(0, contentWidth - M.indexColumnWidth - dateAddedWidth - displayTitleWidth - timeWidth - speakerWidth - languageWidth - tagsWidth)
        let cuesX = M.indexColumnWidth + dateAddedWidth + displayTitleWidth + timeWidth
        let speakerRect = showsSpeakerColumn ? CGRect(
            x: max(cuesX, contentWidth - languageWidth - M.speakerColumnWidth),
            y: 0,
            width: M.speakerColumnWidth,
            height: height
        ) : nil
        let languageRect = showsLanguageColumn ? CGRect(
            x: max(cuesX, contentWidth - M.languageColumnWidth),
            y: 0,
            width: M.languageColumnWidth,
            height: height
        ) : nil
        let tagsRect = showsTagsColumn ? CGRect(
            x: max(cuesX, contentWidth - M.tagsColumnWidth),
            y: 0,
            width: M.tagsColumnWidth,
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
            speakerRect: speakerRect,
            languageRect: languageRect,
            tagsRect: tagsRect,
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
            speakerRect: speakerRect?.offsetBy(dx: dx, dy: 0),
            languageRect: languageRect?.offsetBy(dx: dx, dy: 0),
            tagsRect: tagsRect?.offsetBy(dx: dx, dy: 0),
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
            .foregroundColor: isRedesign ? WorkbenchRedesignColors.NS.textPrimary : NSColor.labelColor,
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
        case .primaryContent, .secondaryContext, .metadata:
            return WorkbenchRedesignColors.NS.textSecondary
        }
    }

    static func tag(_ tag: WorkbenchTag, isRedesign: Bool = false, isEnabled: Bool = true) -> NSAttributedString {
        let foregroundColor: NSColor
        if isRedesign, !isEnabled {
            foregroundColor = WorkbenchRedesignColors.NS.textDisabled
        } else {
            foregroundColor = isRedesign ? tag.colorID.redesignForegroundColor() : tag.colorID.appKitForegroundColor
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

    func draw(at origin: CGPoint) {
        let glyphRange = layoutManager.glyphRange(for: textContainer)
        guard glyphRange.length > 0 else { return }
        layoutManager.drawGlyphs(forGlyphRange: glyphRange, at: origin)
    }

    func containsText(at point: CGPoint, origin: CGPoint) -> Bool {
        lineUsedRects(at: origin).contains { $0.contains(point) }
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
    case context
    case shiori

    init(tableName: String) {
        let normalizedName = tableName.lowercased()
        if normalizedName.contains("shiori") {
            self = .shiori
        } else if normalizedName.contains("context") {
            self = .context
        } else {
            self = .search
        }
    }

    func counterName(_ event: String) -> String {
        "table.\(rawValue).\(event)"
    }
}

private enum SubtitleTableCellActionMenuKind: Equatable {
    case cues
    case displayTitle
    case time
    case dateAdded

    init?(columnID: String) {
        switch columnID {
        case "cues":
            self = .cues
        case "display":
            self = .displayTitle
        case "time":
            self = .time
        case "dateAdded":
            self = .dateAdded
        default:
            return nil
        }
    }
}

private struct RowActionMenu: View {
    var kind: SubtitleTableCellActionMenuKind = .cues
    var style: SubtitleTableRowActionMenuStyle = .search
    var showsCueGroup = false
    var canOpenFolder = true
    var onPlay: () -> Void
    var onContext: () -> Void
    var onCopyCueText: () -> Void
    var onCopyCueGroupText: () -> Void
    var onOpenFolder: () -> Void
    var onCopyText: () -> Void
    var onRemoveShiori: () -> Void

    var body: some View {
        WorkbenchPopoverPanel(isRedesign: true) {
            VStack(spacing: 0) {
                switch kind {
                case .cues:
                    cuesRows
                case .displayTitle:
                    displayTitleRows
                case .time, .dateAdded:
                    copyTextRow
                }
            }
        }
    }

    private var cuesRows: some View {
        Group {
            WorkbenchPopoverRow(
                title: "Play",
                systemImage: "play.fill",
                isRedesign: true,
                showsCheckmarkSlot: false,
                isEnabled: true,
                action: onPlay
            )
            WorkbenchPopoverRow(
                title: "Context",
                systemImage: "doc.text",
                isRedesign: true,
                showsCheckmarkSlot: false,
                isEnabled: true,
                action: onContext
            )
            WorkbenchPopoverRow(
                title: "Copy Cue Text",
                systemImage: "doc.on.doc",
                isRedesign: true,
                showsCheckmarkSlot: false,
                isEnabled: true,
                action: onCopyCueText
            )
            if showsCueGroup {
                WorkbenchPopoverRow(
                    title: "Copy Cue Group Text",
                    systemImage: "doc.on.doc",
                    isRedesign: true,
                    showsCheckmarkSlot: false,
                    isEnabled: true,
                    action: onCopyCueGroupText
                )
            }
            if style == .shiori {
                WorkbenchPopoverRow(
                    title: "Remove Shiori",
                    systemImage: "bookmark.slash",
                    isRedesign: true,
                    showsCheckmarkSlot: false,
                    isEnabled: true,
                    action: onRemoveShiori
                )
            }
        }
    }

    private var displayTitleRows: some View {
        Group {
            WorkbenchPopoverRow(
                title: "Open Folder",
                systemImage: "folder",
                isRedesign: true,
                showsCheckmarkSlot: false,
                isEnabled: canOpenFolder,
                action: onOpenFolder
            )
            copyTextRow
        }
    }

    private var copyTextRow: some View {
        WorkbenchPopoverRow(
            title: "Copy Text",
            systemImage: "doc.on.doc",
            isRedesign: true,
            showsCheckmarkSlot: false,
            isEnabled: true,
            action: onCopyText
        )
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
    static func draw(state: WorkbenchCheckboxState, in rect: CGRect, isFocused: Bool = false) {
        let path = NSBezierPath(
            roundedRect: rect,
            xRadius: SubtitleTableMetrics.checkboxCornerRadius,
            yRadius: SubtitleTableMetrics.checkboxCornerRadius
        )
        switch state {
        case .unchecked:
            WorkbenchRedesignColors.NS.bgCheckboxUnchecked.setFill()
        case .checked, .indeterminate:
            WorkbenchRedesignColors.NS.bgCheckboxChecked.setFill()
        }
        path.fill()

        let borderColor: NSColor? = isFocused
            ? WorkbenchRedesignColors.NS.borderFocus
            : (state == .unchecked ? WorkbenchRedesignColors.NS.borderCheckbox : nil)
        if let borderColor {
            borderColor.setStroke()
            path.lineWidth = 1.5
            path.stroke()
        }

        switch state {
        case .unchecked:
            break
        case .checked:
            drawCheckmark(in: rect)
        case .indeterminate:
            drawIndeterminate(in: rect)
        }

        if isFocused {
            let focusRect = rect.insetBy(
                dx: -WorkbenchControlMetrics.redesignFocusRingWidth,
                dy: -WorkbenchControlMetrics.redesignFocusRingWidth
            )
            let focusPath = NSBezierPath(
                roundedRect: focusRect,
                xRadius: SubtitleTableMetrics.checkboxCornerRadius + WorkbenchControlMetrics.redesignFocusRingWidth,
                yRadius: SubtitleTableMetrics.checkboxCornerRadius + WorkbenchControlMetrics.redesignFocusRingWidth
            )
            WorkbenchRedesignColors.NS.focusRing.setStroke()
            focusPath.lineWidth = WorkbenchControlMetrics.redesignFocusRingWidth
            focusPath.stroke()
        }
    }

    private static func drawCheckmark(in rect: CGRect) {
        let path = NSBezierPath()
        path.move(to: CGPoint(x: rect.minX + 4, y: rect.minY + 8.5))
        path.line(to: CGPoint(x: rect.minX + 7, y: rect.minY + 11.5))
        path.line(to: CGPoint(x: rect.minX + 12.5, y: rect.minY + 5))
        WorkbenchRedesignColors.NS.checkboxIcon.setStroke()
        path.lineWidth = 2.5
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.stroke()
    }

    private static func drawIndeterminate(in rect: CGRect) {
        let path = NSBezierPath()
        path.move(to: CGPoint(x: rect.minX + 4, y: rect.midY))
        path.line(to: CGPoint(x: rect.maxX - 4, y: rect.midY))
        WorkbenchRedesignColors.NS.checkboxIcon.setStroke()
        path.lineWidth = 2.5
        path.lineCapStyle = .round
        path.stroke()
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
            ZStack {
                RoundedRectangle(cornerRadius: SubtitleTableMetrics.checkboxCornerRadius, style: .continuous)
                    .fill(backgroundColor)
                if let borderColor {
                    RoundedRectangle(cornerRadius: SubtitleTableMetrics.checkboxCornerRadius, style: .continuous)
                        .strokeBorder(borderColor, lineWidth: 1.5)
                }
                if state != .unchecked {
                    Image(systemName: state == .checked ? "checkmark" : "minus")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(WorkbenchRedesignColors.checkboxIcon)
                }
            }
            .frame(width: SubtitleTableMetrics.checkboxSize, height: SubtitleTableMetrics.checkboxSize)
            .overlay(
                Group {
                    if showsKeyboardFocus {
                        RoundedRectangle(
                            cornerRadius: SubtitleTableMetrics.checkboxCornerRadius + WorkbenchControlMetrics.redesignFocusRingWidth,
                            style: .continuous
                        )
                        .stroke(WorkbenchRedesignColors.focusRing, lineWidth: WorkbenchControlMetrics.redesignFocusRingWidth)
                        .padding(-WorkbenchControlMetrics.redesignFocusRingWidth)
                    }
                }
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
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

    private var backgroundColor: Color {
        switch state {
        case .unchecked:
            return WorkbenchRedesignColors.bgCheckboxUnchecked
        case .checked, .indeterminate:
            return WorkbenchRedesignColors.bgCheckboxChecked
        }
    }

    private var borderColor: Color? {
        if showsKeyboardFocus {
            return WorkbenchRedesignColors.borderFocus
        }
        return state == .unchecked ? WorkbenchRedesignColors.borderCheckbox : nil
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
        layer?.cornerRadius = SubtitleTableMetrics.cornerRadius
        layer?.borderWidth = 1
        layer?.masksToBounds = true
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
                layer.backgroundColor = WorkbenchRedesignColors.NS.bgSurface.cgColor
                layer.borderColor = WorkbenchRedesignColors.NS.borderControl.cgColor
            } else {
                layer.backgroundColor = NSColor.textBackgroundColor.cgColor
                layer.borderColor = NSColor.separatorColor.cgColor
            }
        }
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
    private var speakerHeaderHost: NSHostingView<AnyView>?
    private var languageHeaderHost: NSHostingView<AnyView>?
    private var tagsHeaderHost: NSHostingView<AnyView>?
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
                WorkbenchRedesignColors.NS.borderControl.setStroke()
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
            let showsSpeakerColumn = coordinator?.showsSpeakerColumnForRendering() ?? false
            let showsTagsColumn = coordinator?.showsTagsColumnForRendering() ?? false
            let dateAddedWidth = showsDateAddedColumn ? M.dateAddedColumnWidth : 0
            let displayTitleWidth = showsDisplayTitleColumn ? M.nameColumnWidth : 0
            let timeWidth = showsTimeColumn ? M.timeColumnWidth : 0
            let languageWidth = showsLanguageColumn ? M.languageColumnWidth : 0
            let speakerWidth = showsSpeakerColumn ? M.speakerColumnWidth : 0
            let tagsWidth = showsTagsColumn ? M.tagsColumnWidth : 0
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
                    width: max(0, bounds.width - cuesX - speakerWidth - languageWidth - tagsWidth),
                    height: bounds.height
                ),
                leading: M.headerHorizontalInset,
                trailing: M.trailingInset
            )
            if showsSpeakerColumn {
                drawHeader(
                    coordinator?.speakerHeaderForRendering() ?? "Speaker",
                    rect: CGRect(
                        x: max(cuesX, bounds.width - languageWidth - M.speakerColumnWidth),
                        y: 0,
                        width: M.speakerColumnWidth,
                        height: bounds.height
                    ),
                    leading: M.headerHorizontalInset,
                    trailing: M.trailingInset
                )
            }
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
            if showsTagsColumn {
                drawHeader(
                    coordinator?.tagsHeaderForRendering() ?? "Tags",
                    rect: CGRect(
                        x: max(cuesX, bounds.width - M.tagsColumnWidth),
                        y: 0,
                        width: M.tagsColumnWidth,
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
            speakerHeaderHost?.isHidden = true
            languageHeaderHost?.isHidden = true
            tagsHeaderHost?.isHidden = true
            lastHeaderLayout = nil
            return
        }

        let layout = currentHeaderLayout()

        updateSelectionHeaderHost(&indexHeaderHost, frame: layout.indexRect)
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

        if let speakerRect = layout.speakerRect {
            updateHeaderHost(&speakerHeaderHost, title: coordinator?.speakerHeaderForRendering() ?? "Speaker", columnID: "speaker", isSortable: true, frame: speakerRect)
        } else {
            speakerHeaderHost?.isHidden = true
        }

        if let languageRect = layout.languageRect {
            updateHeaderHost(&languageHeaderHost, title: coordinator?.languageHeaderForRendering() ?? "Language", columnID: "language", isSortable: true, frame: languageRect)
        } else {
            languageHeaderHost?.isHidden = true
        }

        if let tagsRect = layout.tagsRect {
            updateHeaderHost(&tagsHeaderHost, title: coordinator?.tagsHeaderForRendering() ?? "Tags", columnID: "tags", isSortable: true, frame: tagsRect)
        } else {
            tagsHeaderHost?.isHidden = true
        }
        updateHeaderKeyViewBridge()
        lastHeaderLayout = layout
    }

    func refreshHeaderHostsForCuesWidthChange() {
        guard isRedesign else {
            refreshHeaderHosts()
            return
        }

        let layout = currentHeaderLayout()
        updateHeaderFrame(&indexHeaderHost, frame: layout.indexRect)
        updateHeaderFrame(&dateAddedHeaderHost, frame: layout.dateAddedRect)
        updateHeaderFrame(&nameHeaderHost, frame: coordinator?.showsDisplayTitleColumnForRendering() ?? true ? layout.nameRect : nil)
        updateHeaderFrame(&timeHeaderHost, frame: layout.timeRect)
        updateHeaderHost(&cuesHeaderHost, title: coordinator?.cuesHeaderForRendering() ?? "Cues", columnID: "cues", isSortable: true, frame: layout.cuesRect)
        updateHeaderFrame(&speakerHeaderHost, frame: layout.speakerRect)
        updateHeaderFrame(&languageHeaderHost, frame: layout.languageRect)
        updateHeaderFrame(&tagsHeaderHost, frame: layout.tagsRect)
        updateHeaderKeyViewBridge()
        lastHeaderLayout = layout
    }

    private func refreshHeaderHostsForLayoutChange() {
        guard isRedesign else {
            refreshHeaderHosts()
            return
        }

        let layout = currentHeaderLayout()
        if let lastHeaderLayout,
           layout.isCuesOnlyWidthChange(from: lastHeaderLayout)
        {
            refreshHeaderHostsForCuesWidthChange()
        } else {
            refreshHeaderHosts()
        }
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
            showsSpeakerColumn: false,
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
        let isEnabled = coordinator.isEnabled

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
        if let tagsHeaderHost, !tagsHeaderHost.isHidden {
            return tagsHeaderHost
        }
        if let languageHeaderHost, !languageHeaderHost.isHidden {
            return languageHeaderHost
        }
        if let speakerHeaderHost, !speakerHeaderHost.isHidden {
            return speakerHeaderHost
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

struct SubtitleTableView: NSViewRepresentable {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.isWorkbenchPopupLayerOpen) var isWorkbenchPopupLayerOpen
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
    var speakerHeader = "Speaker"
    var languageHeader = "Language"
    var tagsHeader = "Tags"
    var columnOrder: [String] = []
    var showsDateAddedColumn = false
    var showsDisplayTitleColumn = true
    var showsTimeColumn = false
    var showsLanguageColumn = false
    var showsSpeakerColumn = false
    var showsTagsColumn = false
    var showsCueGroup = false
    var scrollResetToken = 0
    var scrollTargetRow: Int?
    var suspendsMenuOutsideClickDismiss = false
    var onVisibleRowsChange: (Range<Int>) -> Void = { _ in }
    var isRowSelected: (Int) -> Bool = { _ in false }
    var selectionHeaderState: WorkbenchCheckboxState = .unchecked
    var onToggleRowSelection: (Int) -> Void = { _ in }
    var onToggleAllSelection: () -> Void = {}
    var onPlay: (SubtitleTableRow) -> Void
    var onShowContext: (SubtitleTableRow) -> Void = { _ in }
    var onOpenSubtitleFile: (String) -> Void = { path in
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }
    var rowActionMenuStyle: SubtitleTableRowActionMenuStyle = .search
    var onRemoveShiori: (SubtitleTableRow) -> Void = { _ in }
    var makeTagsPopover: (SubtitleTableRow, @escaping () -> Void, @escaping () -> Void) -> AnyView? = { _, _, _ in nil }
    var isRedesign: Bool = false

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
            speakerHeader: speakerHeader,
            languageHeader: languageHeader,
            tagsHeader: tagsHeader,
            columnOrder: columnOrder,
            showsDateAddedColumn: showsDateAddedColumn,
            showsDisplayTitleColumn: showsDisplayTitleColumn,
            showsTimeColumn: showsTimeColumn,
            showsLanguageColumn: showsLanguageColumn,
            showsSpeakerColumn: showsSpeakerColumn,
            showsTagsColumn: showsTagsColumn,
            showsCueGroup: showsCueGroup,
            scrollResetToken: scrollResetToken,
            scrollTargetRow: scrollTargetRow,
            onVisibleRowsChange: onVisibleRowsChange,
            isRowSelected: isRowSelected,
            selectionHeaderState: selectionHeaderState,
            onToggleRowSelection: onToggleRowSelection,
            onToggleAllSelection: onToggleAllSelection,
            onPlay: onPlay,
            onShowContext: onShowContext,
            onOpenSubtitleFile: onOpenSubtitleFile,
            rowActionMenuStyle: rowActionMenuStyle,
            onRemoveShiori: onRemoveShiori,
            makeTagsPopover: makeTagsPopover
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

        context.coordinator.attach(
            container: container,
            headerView: header,
            scrollView: scrollView,
            scrollbarOverlayView: scrollbarOverlayView,
            documentView: documentView
        )
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.scrollContentDidChange),
            name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView
        )

        container.addSubview(header)
        container.addSubview(scrollView)
        container.addSubview(scrollbarOverlayView)

        let headerHeightConstraint = header.heightAnchor.constraint(equalToConstant: context.coordinator.currentHeaderHeight)
        context.coordinator.headerHeightConstraint = headerHeightConstraint

        container.isRedesign = context.coordinator.isRedesign
        header.isRedesign = context.coordinator.isRedesign
        documentView.isRedesign = context.coordinator.isRedesign

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

        context.coordinator.resizeDocument()
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
            speakerHeader: speakerHeader,
            languageHeader: languageHeader,
            tagsHeader: tagsHeader,
            columnOrder: columnOrder,
            showsDateAddedColumn: showsDateAddedColumn,
            showsDisplayTitleColumn: showsDisplayTitleColumn,
            showsTimeColumn: showsTimeColumn,
            showsLanguageColumn: showsLanguageColumn,
            showsSpeakerColumn: showsSpeakerColumn,
            showsTagsColumn: showsTagsColumn,
            showsCueGroup: showsCueGroup,
            scrollResetToken: scrollResetToken,
            scrollTargetRow: scrollTargetRow,
            onVisibleRowsChange: onVisibleRowsChange,
            isRowSelected: isRowSelected,
            selectionHeaderState: selectionHeaderState,
            onToggleRowSelection: onToggleRowSelection,
            onToggleAllSelection: onToggleAllSelection,
            onPlay: onPlay,
            onShowContext: onShowContext,
            onOpenSubtitleFile: onOpenSubtitleFile,
            rowActionMenuStyle: rowActionMenuStyle,
            onRemoveShiori: onRemoveShiori,
            makeTagsPopover: makeTagsPopover
        )
    }

    // MARK: Coordinator

    @MainActor
    final class Coordinator: NSObject {
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
        private var speakerHeader: String
        private var languageHeader: String
        private var tagsHeader: String
        private var columnOrder: [String]
        private var showsDateAddedColumn: Bool
        private var showsDisplayTitleColumn: Bool
        private var showsTimeColumn: Bool
        private var showsLanguageColumn: Bool
        private var showsSpeakerColumn: Bool
        private var showsTagsColumn: Bool
        private var showsCueGroup: Bool
        private var scrollResetToken: Int
        private var scrollTargetRow: Int?
        private var onVisibleRowsChange: (Range<Int>) -> Void
        private var isRowSelected: (Int) -> Bool
        private var selectionHeaderState: WorkbenchCheckboxState
        private var onToggleRowSelection: (Int) -> Void
        private var onToggleAllSelection: () -> Void
        private var onPlay: (SubtitleTableRow) -> Void
        private var onShowContext: (SubtitleTableRow) -> Void
        private var onOpenSubtitleFile: (String) -> Void
        private var rowActionMenuStyle: SubtitleTableRowActionMenuStyle
        private var onRemoveShiori: (SubtitleTableRow) -> Void
        private var makeTagsPopover: (SubtitleTableRow, @escaping () -> Void, @escaping () -> Void) -> AnyView?

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
                lastEffectiveCuesWidthKey = nil
                lastNotifiedVisibleRows = nil
                resizeDocument()
                notifyVisibleRowsChanged(force: true)
                updateHoveredColumnID(nil)
                updateHoveredCueTextRow(nil)
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
                    updateHoveredColumnID(nil)
                    updateHoveredCueTextRow(nil)
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
        private var buttonsHost: NSHostingView<CueHoverButtons>?
        fileprivate var isMenuOpen = false
        private var menuHost: SubtitleTableMenuHostingView?
        private var menuOverlayView: SubtitleTableMenuOverlayView?
        private var activeMenuAnchor: ActiveMenuAnchor?
        private var activeRowMenuRow: Int?
        private var activeRowMenuColumnID: String?
        private var pendingMenuReposition = false
        nonisolated(unsafe) private var menuEventMonitor: Any?
        nonisolated(unsafe) private var keyboardFocusEventMonitor: Any?

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
                    if isMenuOpen {
                        dismissMenu(recalculateHover: false)
                    }
                    let invalidatedRows = [
                        hoveredRow,
                        hoveredCueTextRow,
                        hoveredRowActionRow,
                    ]
                    hoveredRow = nil
                    hoveredColumnID = nil
                    hoveredCueTextRow = nil
                    hoveredRowActionRow = nil
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
        private var rowMeasurementCache = SubtitleTableRowHeightCache()
        private var rowHeightCache = SubtitleVirtualRowHeightCache()
        private var lastEffectiveCuesWidthKey: Int?
        private var isApplyingDynamicReflow = false
        private var isResizingDocument = false
        private var measurementComputeCount = 0
        private var drawnRowCount = 0
        private var hoveredRow: Int?
        private var hoveredColumnID: String?
        private var hoveredCueTextRow: Int?
        private var hoveredRowActionRow: Int?
        private var focusedCheckboxRow: Int?
        private var lastNotifiedVisibleRows: Range<Int>?
        private var lastHeaderHorizontalOffset: CGFloat?
        private var isScrollbarDragging = false

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
            speakerHeader: String = "Speaker",
            languageHeader: String = "Language",
            tagsHeader: String = "Tags",
            columnOrder: [String] = [],
            showsDateAddedColumn: Bool = false,
            showsDisplayTitleColumn: Bool = true,
            showsTimeColumn: Bool = false,
            showsLanguageColumn: Bool = false,
            showsSpeakerColumn: Bool = false,
            showsTagsColumn: Bool = false,
            showsCueGroup: Bool = false,
            scrollResetToken: Int = 0,
            scrollTargetRow: Int? = nil,
            onVisibleRowsChange: @escaping (Range<Int>) -> Void,
            isRowSelected: @escaping (Int) -> Bool = { _ in false },
            selectionHeaderState: WorkbenchCheckboxState = .unchecked,
            onToggleRowSelection: @escaping (Int) -> Void = { _ in },
            onToggleAllSelection: @escaping () -> Void = {},
            onPlay: @escaping (SubtitleTableRow) -> Void,
            onShowContext: @escaping (SubtitleTableRow) -> Void = { _ in },
            onOpenSubtitleFile: @escaping (String) -> Void = { path in
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
            },
            rowActionMenuStyle: SubtitleTableRowActionMenuStyle = .search,
            onRemoveShiori: @escaping (SubtitleTableRow) -> Void = { _ in },
            makeTagsPopover: @escaping (SubtitleTableRow, @escaping () -> Void, @escaping () -> Void) -> AnyView? = { _, _, _ in nil }
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
            self.speakerHeader = speakerHeader
            self.languageHeader = languageHeader
            self.tagsHeader = tagsHeader
            self.columnOrder = columnOrder
            self.showsDateAddedColumn = showsDateAddedColumn
            self.showsDisplayTitleColumn = showsDisplayTitleColumn
            self.showsTimeColumn = showsTimeColumn
            self.showsLanguageColumn = showsLanguageColumn
            self.showsSpeakerColumn = showsSpeakerColumn
            self.showsTagsColumn = showsTagsColumn
            self.showsCueGroup = showsCueGroup
            self.scrollResetToken = scrollResetToken
            self.scrollTargetRow = scrollTargetRow
            self.onVisibleRowsChange = onVisibleRowsChange
            self.isRowSelected = isRowSelected
            self.selectionHeaderState = selectionHeaderState
            self.onToggleRowSelection = onToggleRowSelection
            self.onToggleAllSelection = onToggleAllSelection
            self.onPlay = onPlay
            self.onShowContext = onShowContext
            self.onOpenSubtitleFile = onOpenSubtitleFile
            self.rowActionMenuStyle = rowActionMenuStyle
            self.onRemoveShiori = onRemoveShiori
            self.makeTagsPopover = makeTagsPopover
        }

        deinit {
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
            documentView: SubtitleVirtualTableDocumentView
        ) {
            self.container = container
            self.headerView = headerView
            self.scrollView = scrollView
            self.scrollbarOverlayView = scrollbarOverlayView
            self.documentView = documentView
            scrollbarOverlayView.onDragStateChanged = { [weak self] isDragging in
                self?.setScrollbarDragging(isDragging)
            }
            configureScrollbars()

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
                self?.repositionOpenMenu()
            }
            installKeyboardFocusEventMonitor()
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
            speakerHeader: String = "Speaker",
            languageHeader: String = "Language",
            tagsHeader: String = "Tags",
            columnOrder: [String] = [],
            showsDateAddedColumn: Bool = false,
            showsDisplayTitleColumn: Bool = true,
            showsTimeColumn: Bool = false,
            showsLanguageColumn: Bool,
            showsSpeakerColumn: Bool,
            showsTagsColumn: Bool = false,
            showsCueGroup: Bool = false,
            scrollResetToken: Int,
            scrollTargetRow: Int? = nil,
            onVisibleRowsChange: @escaping (Range<Int>) -> Void,
            isRowSelected: @escaping (Int) -> Bool,
            selectionHeaderState: WorkbenchCheckboxState,
            onToggleRowSelection: @escaping (Int) -> Void,
            onToggleAllSelection: @escaping () -> Void,
            onPlay: @escaping (SubtitleTableRow) -> Void,
            onShowContext: @escaping (SubtitleTableRow) -> Void = { _ in },
            onOpenSubtitleFile: @escaping (String) -> Void = { path in
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
            },
            rowActionMenuStyle: SubtitleTableRowActionMenuStyle = .search,
            onRemoveShiori: @escaping (SubtitleTableRow) -> Void = { _ in },
            makeTagsPopover: @escaping (SubtitleTableRow, @escaping () -> Void, @escaping () -> Void) -> AnyView? = { _, _, _ in nil }
        ) {
            let tableChanged = tableName != self.tableName
            self.probeSurface = probeSurface
            self.probeScope = probeScope
            let cuePresentationInputChanged = showsCueGroup != self.showsCueGroup ||
                columnOrder != self.columnOrder ||
                showsDateAddedColumn != self.showsDateAddedColumn ||
                showsDisplayTitleColumn != self.showsDisplayTitleColumn ||
                showsTimeColumn != self.showsTimeColumn ||
                showsLanguageColumn != self.showsLanguageColumn ||
                showsSpeakerColumn != self.showsSpeakerColumn ||
                showsTagsColumn != self.showsTagsColumn
            let cuesCellsWillChange: Bool
            if case .cells(let cells) = rowsUpdate {
                cuesCellsWillChange = cells.contains { $0.columnID == "cues" }
            } else {
                cuesCellsWillChange = false
            }
            let preservesReloadAnchor = !tableChanged && rowsUpdate == .reload
            let presentationAnchor = (
                cuePresentationInputChanged || preservesReloadAnchor || cuesCellsWillChange
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
            let speakerHeaderChanged = speakerHeader != self.speakerHeader
            self.speakerHeader = speakerHeader
            let languageHeaderChanged = languageHeader != self.languageHeader
            self.languageHeader = languageHeader
            let tagsHeaderChanged = tagsHeader != self.tagsHeader
            self.tagsHeader = tagsHeader
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
            let speakerColumnChanged = showsSpeakerColumn != self.showsSpeakerColumn
            self.showsSpeakerColumn = showsSpeakerColumn
            let tagsColumnChanged = showsTagsColumn != self.showsTagsColumn
            self.showsTagsColumn = showsTagsColumn
            let showCueGroupChanged = showsCueGroup != self.showsCueGroup
            self.showsCueGroup = showsCueGroup
            let shouldResetScroll = scrollResetToken != self.scrollResetToken
            self.scrollResetToken = scrollResetToken
            self.scrollTargetRow = scrollTargetRow
            self.onVisibleRowsChange = onVisibleRowsChange
            self.isRowSelected = isRowSelected
            let selectionHeaderChanged = selectionHeaderState != self.selectionHeaderState
            self.selectionHeaderState = selectionHeaderState
            self.onToggleRowSelection = onToggleRowSelection
            self.onToggleAllSelection = onToggleAllSelection
            self.onPlay = onPlay
            self.onShowContext = onShowContext
            self.onOpenSubtitleFile = onOpenSubtitleFile
            self.rowActionMenuStyle = rowActionMenuStyle
            self.onRemoveShiori = onRemoveShiori
            self.makeTagsPopover = makeTagsPopover

            let nextRowCount = max(0, rowCount)
            let rowCountChanged = nextRowCount != self.rowCount
            let rowsVersionChanged = rowsVersion != self.rowsVersion
            let rowsChanged = rowCountChanged || rowsVersionChanged
            self.rowCount = nextRowCount
            self.rowsVersion = rowsVersion
            if rowsChanged || shouldResetScroll {
                lastNotifiedVisibleRows = nil
            }
            if let focusedCheckboxRow, focusedCheckboxRow >= nextRowCount {
                updateFocusedCheckbox(nil)
            }

            let isAppendUpdate: Bool
            if case .append = rowsUpdate {
                isAppendUpdate = true
            } else {
                isAppendUpdate = false
            }
            let resetsMeasuredGeometry = tableChanged ||
                rowsUpdate == .reload ||
                (rowCountChanged && !isAppendUpdate)
            if resetsMeasuredGeometry || showCueGroupChanged {
                rowMeasurementCache.removeAll()
                rowHeightCache.removeAll()
            } else if case .cells(let cells) = rowsUpdate {
                for cell in cells where cell.columnID == "cues" {
                    rowMeasurementCache.remove(rowIndex: cell.row)
                    rowHeightCache.removeHeight(for: cell.row)
                }
            }
            rowHeightCache.configure(rowCount: nextRowCount, defaultHeight: currentRowHeight)

            let columnVisibilityChanged = dateAddedColumnChanged || displayTitleColumnChanged || timeColumnChanged || languageColumnChanged || speakerColumnChanged || tagsColumnChanged || columnOrderChanged
            let headerTitleChanged = dateAddedChanged || displayTitleChanged || timeChanged || cuesHeaderChanged || speakerHeaderChanged || languageHeaderChanged || tagsHeaderChanged
            let needsDocumentResize = tableChanged || rowsChanged || columnVisibilityChanged

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
            if tableChanged || rowsChanged || columnVisibilityChanged || headerTitleChanged || selectionHeaderChanged {
                headerView?.refreshHeaderHosts()
            }
            if columnVisibilityChanged || headerTitleChanged || selectionHeaderChanged {
                headerView?.needsDisplay = true
            }
            if columnVisibilityChanged {
                invalidateVisibleDocument()
            }
            invalidateRows(for: rowsUpdate, rowsChanged: rowsChanged)
            if needsDocumentResize || columnVisibilityChanged || headerTitleChanged || shouldResetScroll {
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

        func speakerHeaderForRendering() -> String {
            speakerHeader
        }

        func languageHeaderForRendering() -> String {
            languageHeader
        }

        func tagsHeaderForRendering() -> String {
            tagsHeader
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

        func showsSpeakerColumnForRendering() -> Bool {
            showsSpeakerColumn
        }

        func showsTagsColumnForRendering() -> Bool {
            showsTagsColumn
        }

        func headerColumnLayoutForRendering(viewportWidth: CGFloat, height: CGFloat) -> SubtitleTableColumnLayout {
            let offsetX = scrollView?.contentView.bounds.origin.x ?? 0
            return tableColumnLayout(
                contentWidth: tableContentWidth(viewportWidth: viewportWidth),
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

        func setFocusedCheckboxRowForTesting(_ row: Int?) {
            updateFocusedCheckbox(row)
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
            return interactiveCellCursorRects(in: documentView.visibleRect, documentWidth: documentView.bounds.width)
        }

        func isInteractiveCellCursorActiveForTesting(documentPoint: CGPoint) -> Bool {
            isInteractiveCellCursorActive(at: documentPoint)
        }

        func copyCellTextForTesting(row: Int, columnID: String) {
            copyCellText(row: row, columnID: columnID)
        }

        func copyCueTextForTesting(row: Int) {
            copyRow(row)
        }

        func copyCueGroupTextForTesting(row: Int) {
            copyCueGroup(row)
        }

        func cuesMenuItemsForTesting() -> [(title: String, systemImage: String)] {
            var items = [
                ("Play", "play.fill"),
                ("Context", "doc.text"),
                ("Copy Cue Text", "doc.on.doc"),
            ]
            if showsCueGroup {
                items.append(("Copy Cue Group Text", "doc.on.doc"))
            }
            if rowActionMenuStyle == .shiori {
                items.append(("Remove Shiori", "bookmark.slash"))
            }
            return items
        }

        func rowHeightForTesting(_ row: Int) -> CGFloat {
            rowHeightCache.height(for: row)
        }

        func checkboxRectForTesting(row: Int) -> CGRect? {
            guard let documentView,
                  let measurement = cachedMeasurement(for: row, documentWidth: documentView.bounds.width)
            else {
                return nil
            }
            let rowRect = rectForRow(row, width: documentView.bounds.width)
            return checkboxRect(
                forRowRect: rowRect,
                primaryFirstLineTop: rowRect.minY + measurement.primaryFirstLineOffset
            )
        }

        func rowYOffsetForTesting(_ row: Int) -> CGFloat {
            rowHeightCache.yOffset(for: row)
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
                + measurement.primaryFirstLineOffset
                - scrollView.contentView.bounds.minY
        }

        func measurementComputeCountForTesting() -> Int {
            measurementComputeCount
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
            guard let documentView else { return nil }
            let viewportDirtyRect = dirtyRect.intersection(documentView.visibleRect)
            guard !viewportDirtyRect.isNull else { return nil }
            return visibleRowRange(in: viewportDirtyRect)
        }

        func measurementRowRangeForTesting() -> Range<Int>? {
            guard let scrollView else { return nil }
            return measurementRowRange(in: scrollView.contentView.bounds)
        }

        func openSubtitleFileForTesting(row: Int) {
            openSubtitleFile(row: row)
        }

        func selectionHeaderStateForRendering() -> WorkbenchCheckboxState {
            selectionHeaderState
        }

        func canToggleSelectionForRendering() -> Bool {
            isEnabled && rowCount > 0
        }

        func usesOverlayScrollbarsForTesting() -> Bool {
            scrollbarOverlayView?.isRedesign == true &&
                scrollView?.hasVerticalScroller == false &&
                scrollView?.hasHorizontalScroller == false
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
            guard rowCount > 0 else { return }
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
            let nextEffectiveWidth = isRedesign
                ? effectiveCuesTextWidth(documentWidth: width)
                : 0
            let nextEffectiveWidthKey = SubtitleTableRowHeightCache.widthKey(nextEffectiveWidth)
            let effectiveWidthChanged = isRedesign &&
                lastEffectiveCuesWidthKey != nil &&
                lastEffectiveCuesWidthKey != nextEffectiveWidthKey
            let anchor = preservedAnchor ?? (effectiveWidthChanged ? captureDynamicScrollAnchor() : nil)
            if effectiveWidthChanged {
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
                lastEffectiveCuesWidthKey = nextEffectiveWidthKey
            }

            let nextSize = CGSize(
                width: width,
                height: max(1, scrollView.contentSize.height, rowHeightCache.totalHeight)
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
            if effectiveWidthChanged,
               let oldLayout,
               let newLayout
            {
                invalidateColumnLayoutChange(
                    columnID: "cues",
                    oldLayout: oldLayout,
                    newLayout: newLayout
                )
                headerView?.refreshHeaderHostsForCuesWidthChange()
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
                  let range = measurementRowRange(in: scrollView.contentView.bounds)
            else { return }
            guard force || range != lastNotifiedVisibleRows else { return }
            lastNotifiedVisibleRows = range
            onVisibleRowsChange(range)
        }

        func scrollToTop() {
            guard let scrollView else {
                return
            }

            scrollView.contentView.scroll(to: .zero)
            scrollView.reflectScrolledClipView(scrollView.contentView)
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
            let y = min(rowHeightCache.yOffset(for: clampedRow), maxY)
            var origin = scrollView.contentView.bounds.origin
            origin.y = y
            scrollView.contentView.scroll(to: origin)
            scrollView.reflectScrolledClipView(scrollView.contentView)
            documentView.setNeedsDisplay(documentView.visibleRect)
            scrollbarOverlayView?.needsDisplay = true
            invalidateDocumentCursorRects()
            notifyVisibleRowsChanged(force: true)
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
                showsSpeakerColumn: showsSpeakerColumn,
                showsLanguageColumn: showsLanguageColumn,
                showsTagsColumn: showsTagsColumn,
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
                    showsSpeakerColumn: showsSpeakerColumn,
                    showsLanguageColumn: showsLanguageColumn,
                    showsTagsColumn: showsTagsColumn
                )
            }
            return SubtitleTableColumnLayout.resolve(
                contentWidth: contentWidth,
                height: height,
                showsDateAddedColumn: showsDateAddedColumn,
                showsDisplayTitleColumn: showsDisplayTitleColumn,
                showsTimeColumn: showsTimeColumn,
                showsSpeakerColumn: showsSpeakerColumn,
                showsLanguageColumn: showsLanguageColumn,
                showsTagsColumn: showsTagsColumn,
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
                showsSpeakerColumn: showsSpeakerColumn,
                showsLanguageColumn: showsLanguageColumn,
                showsTagsColumn: showsTagsColumn
            )
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
            case "speaker":
                return speakerHeader
            case "language":
                return languageHeader
            case "tags":
                return tagsHeader
            default:
                return ""
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
            case "speaker":
                return model.speakerTags.map(\.label).joined(separator: ", ")
            case "language":
                return model.tags.map(\.label).joined(separator: ", ")
            case "tags":
                return model.shioriTags.map(\.label).joined(separator: ", ")
            default:
                return ""
            }
        }

        private func refreshHeaderForHorizontalScrollIfNeeded(force: Bool = false) {
            let offset = scrollView?.contentView.bounds.origin.x ?? 0
            guard force || lastHeaderHorizontalOffset != offset else { return }
            lastHeaderHorizontalOffset = offset
            headerView?.refreshHeaderHosts()
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
            let viewportDirtyRect = dirtyRect.intersection(documentView?.visibleRect ?? .zero)
            guard rowCount > 0,
                  let documentView,
                  !viewportDirtyRect.isNull,
                  let range = visibleRowRange(in: viewportDirtyRect)
            else {
                return
            }

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
            if !isRedesign, hoveredRow == row {
                NSColor.secondaryLabelColor.withAlphaComponent(0.06).setFill()
                rect.fill()
            }

            if isRedesign {
                WorkbenchRedesignColors.NS.borderControl.setStroke()
            } else {
                NSColor.separatorColor.setStroke()
            }
            let path = NSBezierPath()
            path.move(to: NSPoint(x: rect.minX, y: rect.maxY - 0.5))
            path.line(to: NSPoint(x: rect.maxX, y: rect.maxY - 0.5))
            path.lineWidth = 1
            path.stroke()
        }

        private func drawCellTexts(row: Int, rowRect: CGRect) {
            let model = rowProvider(row)
            let M = SubtitleTableMetrics.self
            let layout = tableColumnLayout(contentWidth: rowRect.width, height: rowRect.height)
            let measurement = cachedMeasurement(for: row, documentWidth: rowRect.width)
                ?? SubtitleTableRowMeasurement(
                    height: rowRect.height,
                    primaryLineCount: 1,
                    extraLineCount: 0
                )
            let primaryFirstLineTop = rowRect.minY + measurement.primaryFirstLineOffset

            if isRedesign {
                let checkboxState: WorkbenchCheckboxState = isRowSelected(row) ? .checked : .unchecked
                WorkbenchCheckboxDrawing.draw(
                    state: checkboxState,
                    in: checkboxRect(forRowRect: rowRect, primaryFirstLineTop: primaryFirstLineTop),
                    isFocused: isEnabled && focusedCheckboxRow == row && documentView?.window?.firstResponder === documentView
                )
            } else {
                drawIndex(row + 1, in: rowColumnRect(layout.indexRect, rowRect: rowRect))
            }
            if let dateAddedRect = layout.dateAddedRect {
                let cellRect = rowColumnRect(dateAddedRect, rowRect: rowRect)
                let isDateAddedHovered = isCellHovered(row: row, columnID: "dateAdded")
                drawBody(
                    model?.dateAdded ?? "",
                    in: cellRect,
                    trailing: M.trailingInset,
                    role: .metadata,
                    isHovered: isDateAddedHovered,
                    underline: isDateAddedHovered,
                    firstLineTop: primaryFirstLineTop
                )
            }
            if showsDisplayTitleColumn {
                let cellRect = rowColumnRect(layout.nameRect, rowRect: rowRect)
                let isDisplayHovered = isCellHovered(row: row, columnID: "display")
                drawBody(
                    model?.displayTitle ?? "",
                    in: cellRect,
                    trailing: M.trailingInset,
                    role: .secondaryContext,
                    isHovered: isDisplayHovered,
                    underline: isDisplayHovered,
                    firstLineTop: primaryFirstLineTop
                )
            }
            if let timeRect = layout.timeRect {
                let cellRect = rowColumnRect(timeRect, rowRect: rowRect)
                let isTimeHovered = isCellHovered(row: row, columnID: "time")
                drawBody(
                    model?.timeRange ?? "",
                    in: cellRect,
                    trailing: M.trailingInset,
                    role: .metadata,
                    isHovered: isTimeHovered,
                    underline: isTimeHovered,
                    firstLineTop: primaryFirstLineTop
                )
            }
            let cuesRect = rowColumnRect(layout.cuesRect, rowRect: rowRect)
            let isCuesHovered = isCellHovered(row: row, columnID: "cues")
            drawCues(
                model: model,
                in: cuesRect,
                measurement: measurement,
                isHovered: isCuesHovered
            )
            if let speakerRect = layout.speakerRect {
                let cellRect = rowColumnRect(speakerRect, rowRect: rowRect)
                drawTags(
                    model?.speakerTags ?? [],
                    in: cellRect,
                    trailing: M.trailingInset,
                    isHovered: isCellHovered(row: row, columnID: "speaker"),
                    firstLineTop: primaryFirstLineTop
                )
            }
            if let languageRect = layout.languageRect {
                let cellRect = rowColumnRect(languageRect, rowRect: rowRect)
                drawTags(
                    model?.tags ?? [],
                    in: cellRect,
                    trailing: M.trailingInset,
                    isHovered: isCellHovered(row: row, columnID: "language"),
                    firstLineTop: primaryFirstLineTop
                )
            }
            if let tagsRect = layout.tagsRect {
                let cellRect = rowColumnRect(tagsRect, rowRect: rowRect)
                drawTags(
                    model?.shioriTags ?? [],
                    in: cellRect,
                    trailing: M.trailingInset,
                    isHovered: isCellHovered(row: row, columnID: "tags"),
                    firstLineTop: primaryFirstLineTop
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

        private func drawBody(
            _ text: String,
            in rect: CGRect,
            trailing: CGFloat,
            role: SubtitleTableTextRole = .primaryContent,
            isHovered: Bool = false,
            underline: Bool = false,
            firstLineTop: CGFloat? = nil
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
                    foregroundColor: isHovered ? WorkbenchRedesignColors.NS.textPrimary : nil
                ),
                width: max(0, rect.width - M.cellLeading - trailing)
            )
            let origin = bodyTextOrigin(in: rect, firstLineTop: firstLineTop)
            if isHovered {
                if let textBounds = textLayout.unionUsedRect(at: origin) {
                    drawContentHoverBackground(rects: [textBounds], clippedTo: rect)
                }
            }
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
            isHovered: Bool
        ) {
            guard let model else { return }
            let textWidth = max(
                1,
                rect.width
                    - SubtitleTableCueGeometry.cellLeadingPadding
                    - SubtitleTableCueGeometry.cellTrailingPadding
            )
            let textX = rect.minX + SubtitleTableCueGeometry.cellLeadingPadding
            let extraText = showsCueGroup && !model.additionalCueTexts.isEmpty
                ? model.additionalCueTexts.joined(separator: "\n")
                : nil
            let extraOrigin = CGPoint(
                x: textX,
                y: rect.minY + SubtitleTableCueGeometry.rowPaddingY
            )
            let primaryOrigin = CGPoint(
                x: textX,
                y: rect.minY + measurement.primaryFirstLineOffset
            )
            let primaryColor = isHovered
                ? WorkbenchRedesignColors.NS.textPrimary
                : WorkbenchRedesignColors.NS.textSecondary
            let extraColor = WorkbenchRedesignColors.NS.textMuted

            NSGraphicsContext.saveGraphicsState()
            NSBezierPath.clip(rect)

            var usedRects = [CGRect]()
            if let extraText {
                textLayout.update(
                    attributedString: SubtitleTableCueTextMeasurer.attributedString(
                        extraText,
                        style: .extra,
                        foregroundColor: extraColor
                    ),
                    width: textWidth
                )
                usedRects.append(contentsOf: textLayout.usedRects(at: extraOrigin))
            }
            textLayout.update(
                attributedString: SubtitleTableCueTextMeasurer.attributedString(
                    model.primaryCueText,
                    style: .primary,
                    foregroundColor: primaryColor
                ),
                width: textWidth
            )
            usedRects.append(contentsOf: textLayout.usedRects(at: primaryOrigin))

            if isHovered {
                drawContentHoverBackground(rects: usedRects, clippedTo: rect)
            }

            if let extraText {
                textLayout.update(
                    attributedString: SubtitleTableCueTextMeasurer.attributedString(
                        extraText,
                        style: .extra,
                        foregroundColor: extraColor
                    ),
                    width: textWidth
                )
                if isHovered {
                    textLayout.drawUnderline(
                        at: extraOrigin,
                        color: extraColor,
                        thickness: SubtitleTableMetrics.interactiveTextUnderlineThickness,
                        offset: SubtitleTableMetrics.interactiveTextUnderlineOffset,
                        backingScaleFactor: backingScaleFactor()
                    )
                }
                textLayout.draw(at: extraOrigin)
            }

            textLayout.update(
                attributedString: SubtitleTableCueTextMeasurer.attributedString(
                    model.primaryCueText,
                    style: .primary,
                    foregroundColor: primaryColor
                ),
                width: textWidth
            )
            if isHovered {
                textLayout.drawUnderline(
                    at: primaryOrigin,
                    color: WorkbenchRedesignColors.NS.textPrimary,
                    thickness: SubtitleTableMetrics.interactiveTextUnderlineThickness,
                    offset: SubtitleTableMetrics.interactiveTextUnderlineOffset,
                    backingScaleFactor: backingScaleFactor()
                )
            }
            textLayout.draw(at: primaryOrigin)
            NSGraphicsContext.restoreGraphicsState()
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
            role: SubtitleTableTextRole,
            firstLineTop: CGFloat? = nil
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
            let origin = bodyTextOrigin(in: rect, firstLineTop: firstLineTop)
            guard let textBounds = textLayout.unionUsedRect(at: origin) else { return nil }
            return contentHoverRect(rects: [textBounds], clippedTo: rect)
        }

        private func cuesContentHoverRect(
            model: SubtitleTableRow,
            in rect: CGRect,
            measurement: SubtitleTableRowMeasurement
        ) -> CGRect? {
            let textWidth = max(
                1,
                rect.width
                    - SubtitleTableCueGeometry.cellLeadingPadding
                    - SubtitleTableCueGeometry.cellTrailingPadding
            )
            let textX = rect.minX + SubtitleTableCueGeometry.cellLeadingPadding
            var usedRects = [CGRect]()
            if showsCueGroup, !model.additionalCueTexts.isEmpty {
                textLayout.update(
                    attributedString: SubtitleTableCueTextMeasurer.attributedString(
                        model.additionalCueTexts.joined(separator: "\n"),
                        style: .extra,
                        foregroundColor: WorkbenchRedesignColors.NS.textMuted
                    ),
                    width: textWidth
                )
                usedRects.append(contentsOf: textLayout.usedRects(at: CGPoint(
                    x: textX,
                    y: rect.minY + SubtitleTableCueGeometry.rowPaddingY
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
            firstLineTop: CGFloat? = nil
        ) {
            guard !tags.isEmpty else { return }

            NSGraphicsContext.saveGraphicsState()
            NSBezierPath.clip(rect)

            let tagStyle = SubtitleTableTagStyle.resolve(isRedesign: isRedesign)
            let laidOutTags = layoutTags(
                tags,
                in: rect,
                trailing: trailing,
                tagStyle: tagStyle,
                firstLineTop: firstLineTop
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

                let textRect = CGRect(
                    x: item.tagRect.minX + tagStyle.horizontalInset,
                    y: item.tagRect.minY + max(0, (item.tagRect.height - item.textSize.height) / 2),
                    width: max(0, item.tagRect.width - 2 * tagStyle.horizontalInset),
                    height: item.textSize.height
                )
                item.attributed.draw(in: textRect)
            }

            NSGraphicsContext.restoreGraphicsState()
        }

        private func tagContentHoverRect(
            tags: [WorkbenchTag],
            in rect: CGRect,
            trailing: CGFloat,
            firstLineTop: CGFloat? = nil
        ) -> CGRect? {
            guard !tags.isEmpty else { return nil }
            let tagStyle = SubtitleTableTagStyle.resolve(isRedesign: isRedesign)
            let laidOutTags = layoutTags(
                tags,
                in: rect,
                trailing: trailing,
                tagStyle: tagStyle,
                firstLineTop: firstLineTop
            )
            return contentHoverRect(rects: laidOutTags.map { $0.tagRect }, clippedTo: rect)
        }

        private func layoutTags(
            _ tags: [WorkbenchTag],
            in rect: CGRect,
            trailing: CGFloat,
            tagStyle: SubtitleTableTagStyle,
            firstLineTop: CGFloat? = nil
        ) -> [(tag: WorkbenchTag, attributed: NSAttributedString, textSize: CGSize, tagRect: CGRect)] {
            let M = SubtitleTableMetrics.self
            var x = rect.minX + M.cellLeading
            var y: CGFloat?
            let maxX = rect.maxX - trailing
            let maxY = isRedesign ? rect.maxY : rect.maxY - M.rowVerticalInset
            var laidOutTags: [(tag: WorkbenchTag, attributed: NSAttributedString, textSize: CGSize, tagRect: CGRect)] = []

            for tag in tags {
                let attributed = SubtitleTableText.tag(tag, isRedesign: isRedesign, isEnabled: isEnabled)
                let textSize = attributed.size()
                let tagHeight = tagStyle.height(for: textSize)
                if y == nil {
                    if let firstLineTop, isRedesign {
                        y = firstLineTop
                            + (SubtitleTableCueGeometry.primaryLineHeight - tagHeight) / 2
                    } else {
                        y = isRedesign
                            ? rect.minY + (rect.height - tagHeight) / 2
                            : rect.minY + M.rowVerticalInset - 1
                    }
                }
                guard let currentY = y else { break }
                let tagWidth = tagStyle.width(for: textSize)
                if x > rect.minX + M.cellLeading, x + tagWidth > maxX {
                    x = rect.minX + M.cellLeading
                    y = currentY + tagHeight + tagStyle.verticalSpacing
                }
                guard let resolvedY = y, resolvedY + tagHeight <= maxY else {
                    break
                }

                let tagRect = CGRect(x: x, y: resolvedY, width: min(tagWidth, max(0, maxX - x)), height: tagHeight)
                laidOutTags.append((tag: tag, attributed: attributed, textSize: textSize, tagRect: tagRect))
                x += tagRect.width + tagStyle.horizontalSpacing
            }

            return laidOutTags
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

        private func cachedMeasurement(for row: Int, documentWidth: CGFloat) -> SubtitleTableRowMeasurement? {
            guard let model = rowProvider(row) else { return nil }
            return rowMeasurementCache.cachedMeasurement(
                rowIndex: row,
                row: model,
                effectiveCuesWidth: effectiveCuesTextWidth(documentWidth: documentWidth),
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
            let lookup = rowMeasurementCache.lookup(
                rowIndex: row,
                row: model,
                effectiveCuesWidth: effectiveWidth,
                showsCueGroup: showsCueGroup,
                styleRevision: SubtitleTableCueGeometry.styleRevision
            ) { [cueTextMeasurer] in
                measurementComputeCount += 1
                UIInvalidationProbe.count(
                    probeSurface.counterName("dynamic_row_measurement"),
                    scope: probeScope,
                    details: "table=\(tableName) row=\(row)"
                )
                return cueTextMeasurer.rowMeasurement(
                    row: model,
                    effectiveCuesWidth: effectiveWidth,
                    showsCueGroup: showsCueGroup
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
                let firstLineDocumentY = rowHeightCache.yOffset(for: row)
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

            let firstLineDocumentY = rowHeightCache.yOffset(for: anchor.row)
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
               let measurementRange = measurementRowRange(in: scrollView.contentView.bounds)
            {
                for row in measurementRange {
                    _ = measureRow(row, documentWidth: documentView.bounds.width)
                }
            }
            let requiredTargetRow = explicitTargetRow ?? resolvedAnchor?.row
            if let requiredTargetRow,
               requiredTargetRow >= 0,
               requiredTargetRow < rowCount,
               measurementRowRange(in: scrollView.contentView.bounds)?.contains(requiredTargetRow) != true
            {
                _ = measureRow(requiredTargetRow, documentWidth: documentView.bounds.width)
            }

            let nextHeight = max(1, scrollView.contentSize.height, rowHeightCache.totalHeight)
            if abs(documentView.frame.height - nextHeight) > 0.01 {
                documentView.setFrameSize(CGSize(width: documentView.frame.width, height: nextHeight))
            }
            restoreDynamicScrollAnchor(resolvedAnchor)
            var postRestoreHeightChanged = false
            if let postRestoreRange = measurementRowRange(in: scrollView.contentView.bounds) {
                for row in postRestoreRange {
                    postRestoreHeightChanged = measureRow(
                        row,
                        documentWidth: documentView.bounds.width
                    ) || postRestoreHeightChanged
                }
            }
            if postRestoreHeightChanged {
                let resolvedHeight = max(1, scrollView.contentSize.height, rowHeightCache.totalHeight)
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
            let y = rowHeightCache.yOffset(for: row)
            let height = heightForRow(row, width: width)
            return CGRect(x: 0, y: y, width: width, height: height)
        }

        private func checkboxRect(
            forRowRect rowRect: CGRect,
            primaryFirstLineTop: CGFloat? = nil
        ) -> CGRect {
            let size = SubtitleTableMetrics.checkboxSize
            let centerY = primaryFirstLineTop.map {
                $0 + SubtitleTableCueGeometry.primaryLineHeight / 2
            } ?? rowRect.midY
            return CGRect(
                x: (SubtitleTableMetrics.indexColumnWidth - size) / 2,
                y: centerY - size / 2,
                width: size,
                height: size
            )
        }

        private func checkboxHitRect(
            forRowRect rowRect: CGRect,
            primaryFirstLineTop: CGFloat? = nil
        ) -> CGRect {
            checkboxRect(
                forRowRect: rowRect,
                primaryFirstLineTop: primaryFirstLineTop
            ).insetBy(
                dx: -SubtitleTableMetrics.checkboxHitSlop,
                dy: -SubtitleTableMetrics.checkboxHitSlop
            )
        }

        private func visibleRowRange() -> Range<Int>? {
            guard let scrollView else { return nil }
            return visibleRowRange(in: scrollView.contentView.bounds)
        }

        private func visibleRowRange(in rect: CGRect) -> Range<Int>? {
            rowRange(in: rect, overscan: 0)
        }

        private func measurementRowRange(in rect: CGRect) -> Range<Int>? {
            rowRange(in: rect, overscan: SubtitleTableCueGeometry.measurementOverscan)
        }

        private func rowRange(in rect: CGRect, overscan: Int) -> Range<Int>? {
            guard rowCount > 0 else { return nil }
            let lower = rowHeightCache.rowIndex(atY: rect.minY)
            let upperY = rect.maxY > rect.minY
                ? rect.maxY.nextDown
                : rect.minY
            let upper = rowHeightCache.rowIndex(atY: upperY)
            let lowerBound = max(0, lower - overscan)
            let upperBound = min(rowCount, upper + overscan + 1)
            return lowerBound < upperBound ? lowerBound..<upperBound : nil
        }

        func installCursorRects(in documentView: SubtitleVirtualTableDocumentView) {
            for rect in interactiveCellCursorRects(in: documentView.visibleRect, documentWidth: documentView.bounds.width) {
                documentView.addCursorRect(rect, cursor: .pointingHand)
            }
        }

        func refreshDocumentCursor(windowPoint: CGPoint) {
            guard !isExternalPopupLayerOpen, let documentView else { return }
            let point = documentView.convert(windowPoint, from: nil)
            if isInteractiveCellCursorActive(at: point) {
                NSCursor.pointingHand.set()
            } else if documentView.visibleRect.contains(point) {
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

            return range.flatMap { row -> [CGRect] in
                guard rowProvider(row) != nil else { return [] }
                return interactiveCellColumnIDs().compactMap { columnID in
                    let rowRect = rectForRow(row, width: documentWidth)
                    let documentHoverRect = cellContentHoverRectInDocument(row: row, columnID: columnID)
                        ?? (columnID == "tags" ? dataCellRect(columnID: columnID, rowRect: rowRect) : nil)
                    guard let documentHoverRect else {
                        return nil
                    }
                    let cursorRect = documentHoverRect.intersection(visibleRect)
                    guard !cursorRect.isNull, cursorRect.width > 0, cursorRect.height > 0 else {
                        return nil
                    }
                    return cursorRect
                }
            }
        }

        private func isInteractiveCellCursorActive(at point: CGPoint) -> Bool {
            guard let documentView else { return false }
            return interactiveCellCursorRects(
                in: documentView.visibleRect,
                documentWidth: documentView.bounds.width
            ).contains { $0.contains(point) }
        }

        private func cellActionMenuColumnIDs() -> [String] {
            visibleTextColumnOrder().filter { SubtitleTableCellActionMenuKind(columnID: $0) != nil }
        }

        private func interactiveCellColumnIDs() -> [String] {
            visibleTextColumnOrder().filter { columnID in
                SubtitleTableCellActionMenuKind(columnID: columnID) != nil || columnID == "tags"
            }
        }

        private func rowAtDocumentPoint(_ point: CGPoint) -> Int? {
            guard rowCount > 0 else { return nil }
            let row = rowHeightCache.rowIndex(atY: point.y)
            let rect = rectForRow(row, width: documentView?.bounds.width ?? 0)
            return rect.contains(point) ? row : nil
        }

        private func cuesCellRect(forRowRect rowRect: CGRect) -> CGRect {
            rowColumnRect(
                tableColumnLayout(contentWidth: rowRect.width, height: rowRect.height).cuesRect,
                rowRect: rowRect
            )
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

        private func bodyTextOrigin(in rect: CGRect, firstLineTop: CGFloat? = nil) -> CGPoint {
            let M = SubtitleTableMetrics.self
            let yOffset: CGFloat
            if let firstLineTop, isRedesign {
                yOffset = firstLineTop
                    + max(0, (SubtitleTableCueGeometry.primaryLineHeight - textLayout.usedHeight) / 2)
            } else {
                yOffset = isRedesign
                    ? rect.minY + (rect.height - textLayout.usedHeight) / 2
                    : rect.minY + M.rowVerticalInset
            }
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
                    extraLineCount: 0
                )
            let primaryFirstLineTop = rowRect.minY + measurement.primaryFirstLineOffset
            if columnID == "cues" {
                return cuesContentHoverRect(
                    model: model,
                    in: cellRect,
                    measurement: measurement
                )
            }
            if columnID == "speaker" {
                return tagContentHoverRect(
                    tags: model.speakerTags,
                    in: cellRect,
                    trailing: SubtitleTableMetrics.trailingInset,
                    firstLineTop: primaryFirstLineTop
                )
            }
            if columnID == "language" {
                return tagContentHoverRect(
                    tags: model.tags,
                    in: cellRect,
                    trailing: SubtitleTableMetrics.trailingInset,
                    firstLineTop: primaryFirstLineTop
                )
            }
            if columnID == "tags" {
                return tagContentHoverRect(
                    tags: model.shioriTags,
                    in: cellRect,
                    trailing: SubtitleTableMetrics.trailingInset,
                    firstLineTop: primaryFirstLineTop
                )
            }
            return bodyContentHoverRect(
                text: text(for: columnID, model: model),
                in: cellRect,
                trailing: bodyTextTrailingInset(for: columnID, rowRect: rowRect),
                role: bodyTextRole(for: columnID),
                firstLineTop: primaryFirstLineTop
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
            case "speaker":
                return layout.speakerRect.map { rowColumnRect($0, rowRect: rowRect) }
            case "language":
                return layout.languageRect.map { rowColumnRect($0, rowRect: rowRect) }
            case "tags":
                return layout.tagsRect.map { rowColumnRect($0, rowRect: rowRect) }
            default:
                return nil
            }
        }

        private func isPointInCueCell(row: Int, point: CGPoint) -> Bool {
            guard isRedesign,
                  isEnabled,
                  !isExternalPopupLayerOpen,
                  row >= 0,
                  row < rowCount,
                  rowProvider(row) != nil,
                  let documentView
            else {
                return false
            }
            let rowRect = rectForRow(row, width: documentView.bounds.width)
            return cuesCellRect(forRowRect: rowRect).contains(point)
        }

        private func actionMenuColumnID(row: Int, point: CGPoint) -> String? {
            guard let columnID = hoveredDataColumnID(row: row, point: point),
                  SubtitleTableCellActionMenuKind(columnID: columnID) != nil
            else {
                return nil
            }
            return columnID
        }

        private func hoveredDataColumnID(row: Int, point: CGPoint) -> String? {
            guard isRedesign,
                  row >= 0,
                  row < rowCount,
                  rowProvider(row) != nil
            else {
                return nil
            }
            if let hoverRect = cellContentHoverRectInDocument(row: row, columnID: "dateAdded"),
               hoverRect.contains(point) {
                return "dateAdded"
            }
            if let hoverRect = cellContentHoverRectInDocument(row: row, columnID: "display"),
               hoverRect.contains(point) {
                return "display"
            }
            if let hoverRect = cellContentHoverRectInDocument(row: row, columnID: "time"),
               hoverRect.contains(point) {
                return "time"
            }
            if let hoverRect = cellContentHoverRectInDocument(row: row, columnID: "cues"),
               hoverRect.contains(point) {
                return "cues"
            }
            if let hoverRect = cellContentHoverRectInDocument(row: row, columnID: "speaker"),
               hoverRect.contains(point) {
                return "speaker"
            }
            if let hoverRect = cellContentHoverRectInDocument(row: row, columnID: "language"),
               hoverRect.contains(point) {
                return "language"
            }
            if isPointInTagsCell(row: row, point: point) {
                return "tags"
            }
            return nil
        }

        private func isPointInTagsCell(row: Int, point: CGPoint) -> Bool {
            guard isRedesign,
                  isEnabled,
                  !isExternalPopupLayerOpen,
                  row >= 0,
                  row < rowCount,
                  rowProvider(row) != nil,
                  let documentView
            else {
                return false
            }
            let rowRect = rectForRow(row, width: documentView.bounds.width)
            return dataCellRect(columnID: "tags", rowRect: rowRect)?.contains(point) == true
        }

        private func isPointInCueText(row: Int, point: CGPoint) -> Bool {
            guard row >= 0,
                  row < rowCount,
                  let model = rowProvider(row),
                  !model.primaryCueText.isEmpty,
                  let hoverRect = cellContentHoverRectInDocument(row: row, columnID: "cues")
            else {
                return false
            }
            return hoverRect.contains(point)
        }

        func handleMouseHover(windowPoint: CGPoint) {
            if isMenuOpen || isExternalPopupLayerOpen {
                return
            }
            guard let documentView else { return }
            let point = documentView.convert(windowPoint, from: nil)
            guard documentView.visibleRect.contains(point) else {
                clearHover()
                return
            }
            let row = rowAtDocumentPoint(point)
            updateHoveredRow(row)
            let hoveredColumn = row.flatMap { hoveredDataColumnID(row: $0, point: point) }
            updateHoveredColumnID(hoveredColumn)
            let cueTextRow = row.flatMap { hoveredColumn == "cues" && isPointInCueCell(row: $0, point: point) ? $0 : nil }
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
            guard documentView.visibleRect.contains(point),
                  let row = rowAtDocumentPoint(point)
            else {
                return false
            }
            if isPointInTagsCell(row: row, point: point) {
                return showTagsPopover(row: row, documentPoint: point)
            }
            if let columnID = actionMenuColumnID(row: row, point: point),
               performDefaultCellAction(row: row, columnID: columnID) {
                return true
            }
            return toggleRowCheckboxFromMouse(row: row)
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
            guard documentView.visibleRect.contains(point),
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

        @discardableResult
        private func performDefaultCellAction(row: Int, columnID: String) -> Bool {
            switch SubtitleTableCellActionMenuKind(columnID: columnID) {
            case .cues:
                playRow(row)
                return true
            case .displayTitle:
                openSubtitleFile(row: row)
                return true
            case .time, .dateAdded:
                copyCellText(row: row, columnID: columnID)
                return true
            case nil:
                return false
            }
        }

        private func toggleRowCheckboxFromMouse(row: Int) -> Bool {
            guard isRedesign,
                  isEnabled,
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
            columnID: String,
            oldLayout: SubtitleTableColumnLayout,
            newLayout: SubtitleTableColumnLayout
        ) {
            guard let documentView,
                  let visibleRows = visibleRowRange(in: documentView.visibleRect)
            else {
                return
            }

            for row in visibleRows {
                let rowRect = rectForRow(row, width: documentView.bounds.width)
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
            isMenuOpen = true
            activeRowMenuRow = row
            activeRowMenuColumnID = columnID
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

            let menuKind = SubtitleTableCellActionMenuKind(columnID: columnID) ?? .cues
            let menuView = RowActionMenu(
                kind: menuKind,
                style: rowActionMenuStyle,
                showsCueGroup: showsCueGroup,
                canOpenFolder: canOpenSubtitleFile(row: row),
                onPlay: { [weak self] in
                    self?.dismissMenu()
                    self?.playRow(row)
                },
                onContext: { [weak self] in
                    guard let self, let model = self.rowProvider(row) else { return }
                    self.dismissMenu()
                    self.onShowContext(model)
                },
                onCopyCueText: { [weak self] in
                    self?.copyRow(row)
                    self?.dismissMenu()
                },
                onCopyCueGroupText: { [weak self] in
                    self?.copyCueGroup(row)
                    self?.dismissMenu()
                },
                onOpenFolder: { [weak self] in
                    self?.openSubtitleFile(row: row)
                    self?.dismissMenu()
                },
                onCopyText: { [weak self] in
                    self?.copyCellText(row: row, columnID: columnID)
                    self?.dismissMenu()
                },
                onRemoveShiori: { [weak self] in
                    guard let self, let model = self.rowProvider(row) else { return }
                    self.dismissMenu()
                    self.onRemoveShiori(model)
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

        @discardableResult
        private func showTagsPopover(row: Int, documentPoint: CGPoint) -> Bool {
            guard let container,
                  let documentView,
                  let model = rowProvider(row),
                  let popoverView = makeTagsPopover(model, { [weak self] in
                      self?.dismissMenu()
                  }, { [weak self] in
                      self?.requestOpenMenuReposition()
                  })
            else {
                return false
            }

            isMenuOpen = true
            activeRowMenuRow = row
            activeRowMenuColumnID = "tags"
            let clickPointInContainer = container.convert(documentPoint, from: documentView)
            activeMenuAnchor = .row(
                row: row,
                columnID: "tags",
                anchorFrame: CGRect(origin: clickPointInContainer, size: .zero),
                clickPointInContainer: clickPointInContainer
            )
            layoutHoverButtons()
            invalidateRows([row])

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

            setMenuHost(popoverView, in: container)

            if let menuOverlayView {
                container.addSubview(menuOverlayView)
            }
            if let menuHost {
                container.addSubview(menuHost)
            }

            menuHost?.layout()
            let menuSize = menuHost?.fittingSize ?? CGSize(width: 420, height: 420)
            menuHost?.frame = positionMenuBelowClick(
                clickPointInContainer: clickPointInContainer,
                menuSize: menuSize
            )
            menuHost?.isHidden = false

            installMenuDismissMonitor()
            return true
        }

        func showHeaderMenu(for columnID: String, triggerFrame: CGRect) {
            isMenuOpen = true
            activeRowMenuRow = nil
            activeRowMenuColumnID = nil
            activeHeaderMenuColumnID = columnID
            activeMenuAnchor = .header(triggerFrame: triggerFrame)
            layoutHoverButtons()
            headerView?.refreshHeaderHosts()

            guard let container = self.container, let headerView = self.headerView else {
                isMenuOpen = false
                activeHeaderMenuColumnID = nil
                activeRowMenuColumnID = nil
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
            activeMenuAnchor = nil
            updateHoveredColumnID(nil)
            updateHoveredCueTextRow(nil)
            updateHoveredRowActionRow(nil)
            menuHost?.rootView = AnyView(EmptyView())
            menuHost?.invalidateIntrinsicContentSize()
            menuHost?.isHidden = true
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
            guard let menuHost, !menuHost.isHidden else {
                return false
            }
            let point = menuHost.convert(windowPoint, from: nil)
            return menuHost.bounds.contains(point)
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
        }

        private func removeMenuDismissMonitor() {
            if let monitor = menuEventMonitor {
                NSEvent.removeMonitor(monitor)
                menuEventMonitor = nil
            }
        }

        private func playRow(_ row: Int) {
            guard let model = rowProvider(row) else { return }
            onPlay(model)
        }

        private func copyRow(_ row: Int) {
            guard let model = rowProvider(row) else { return }
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(model.primaryCueText, forType: .string)
        }

        private func copyCueGroup(_ row: Int) {
            guard let model = rowProvider(row) else { return }
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(model.cueGroupCopyText, forType: .string)
        }

        private func copyCellText(row: Int, columnID: String) {
            guard let model = rowProvider(row) else { return }
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(text(for: columnID, model: model), forType: .string)
        }

        private func canOpenSubtitleFile(row: Int) -> Bool {
            guard let model = rowProvider(row) else { return false }
            return !model.subtitlePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        private func openSubtitleFile(row: Int) {
            guard let model = rowProvider(row) else { return }
            let path = model.subtitlePath.trimmingCharacters(in: .whitespacesAndNewlines)
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
                .focused($isFocused)
                .disableFocusEffect()
                .overlay(
                    Group {
                        if isFocused && isEnabled {
                            RoundedRectangle(
                                cornerRadius: WorkbenchControlMetrics.redesignFieldRadius + WorkbenchControlMetrics.redesignFocusRingWidth,
                                style: .continuous
                            )
                            .stroke(WorkbenchRedesignColors.focusRing, lineWidth: WorkbenchControlMetrics.redesignFocusRingWidth)
                            .padding(-WorkbenchControlMetrics.redesignFocusRingWidth)
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
                .foregroundStyle(isEnabled ? WorkbenchRedesignColors.textPrimary : WorkbenchRedesignColors.textDisabled)
                .lineLimit(1)
        }
        .padding(.horizontal, WorkbenchControlMetrics.redesignPaddingHeaderTriggerX)
        .frame(maxHeight: .infinity)
    }

    private var textColor: Color {
        guard isEnabled else { return WorkbenchRedesignColors.textDisabled }
        return WorkbenchRedesignColors.textPrimary
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
                Rectangle()
                    .fill(WorkbenchRedesignColors.borderDivider)
                    .frame(height: WorkbenchControlMetrics.hairlineWidth)
                    .padding(.vertical, WorkbenchControlMetrics.redesignSpacing1)
                WorkbenchPopoverRow(
                    title: "Hide Column",
                    isSelected: false,
                    isHighlighted: false,
                    systemImage: "eye.slash",
                    isRedesign: true,
                    showsCheckmarkSlot: false,
                    isEnabled: false,
                    action: nil
                )
            }
        }
    }
}
