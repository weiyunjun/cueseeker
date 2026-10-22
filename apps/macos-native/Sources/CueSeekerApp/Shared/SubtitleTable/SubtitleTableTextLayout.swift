import AppKit
import CueSeekerCore
import SwiftUI

struct SubtitleTableTagStyle {
    let horizontalInset: CGFloat
    let verticalInset: CGFloat
    let cornerRadius: CGFloat
    let horizontalSpacing: CGFloat
    let verticalSpacing: CGFloat

    static func resolve() -> SubtitleTableTagStyle {
        let M = SubtitleTableMetrics.self
        return SubtitleTableTagStyle(
            horizontalInset: M.tagRedesignHorizontalInset,
            verticalInset: M.tagRedesignVerticalInset,
            cornerRadius: M.tagCornerRadius,
            horizontalSpacing: M.tagHorizontalSpacing,
            verticalSpacing: M.tagVerticalSpacing
        )
    }

    func height(for textSize: CGSize) -> CGFloat {
        ceil(textSize.height) + 2 * verticalInset
    }

    func width(for textSize: CGSize) -> CGFloat {
        ceil(textSize.width) + 2 * horizontalInset
    }

    func fillColor(for tag: WorkbenchTag, isEnabled: Bool) -> NSColor {
        guard isEnabled else { return WorkbenchRedesignColors.NS.bgDisabled }
        return tag.colorID.redesignFillColor()
    }
}

struct SubtitleTableLaidOutTag {
    let tag: WorkbenchTag
    let attributed: NSAttributedString
    let textSize: CGSize
    let tagRect: CGRect
}

struct SubtitleTableTagLayoutResult {
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
        foregroundColor: NSColor? = nil
    ) -> NSAttributedString {
        NSAttributedString(string: text, attributes: [
            .font: bodyFont(role: role),
            .paragraphStyle: bodyParagraphStyle(),
            .foregroundColor: foregroundColor ?? bodyColor(role: role),
        ])
    }

    static func index(_ number: Int) -> NSAttributedString {
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        style.lineBreakMode = .byClipping
        return NSAttributedString(string: "\(number)", attributes: [
            .font: redesignIndexFont,
            .foregroundColor: WorkbenchRedesignColors.NS.textMuted,
            .paragraphStyle: style,
        ])
    }

    private static var redesignIndexFont: NSFont {
        NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
    }

    static func header(_ text: String) -> NSAttributedString {
        NSAttributedString(string: text, attributes: [
            .font: redesignHeaderFont,
            .foregroundColor: WorkbenchRedesignColors.NS.textSecondary,
        ])
    }

    private static var redesignHeaderFont: NSFont {
        NSFont.systemFont(
            ofSize: WorkbenchControlMetrics.redesignFontSizeTableHeader,
            weight: .medium
        )
    }

    private static func bodyFont(role: SubtitleTableTextRole) -> NSFont {
        switch role {
        case .primaryContent:
            return NSFont.systemFont(
                ofSize: WorkbenchControlMetrics.redesignFontSizeTable,
                weight: .medium
            )
        case .secondaryContext:
            return NSFont.systemFont(
                ofSize: WorkbenchControlMetrics.redesignFontSizeTable,
                weight: .regular
            )
        case .metadata:
            return NSFont.monospacedDigitSystemFont(
                ofSize: WorkbenchControlMetrics.redesignFontSizeTable,
                weight: .regular
            )
        }
    }

    private static func bodyColor(role: SubtitleTableTextRole) -> NSColor {
        switch role {
        case .primaryContent:
            return WorkbenchRedesignColors.NS.textPrimary
        case .secondaryContext, .metadata:
            return WorkbenchRedesignColors.NS.textSecondary
        }
    }

    static func tag(_ tag: WorkbenchTag, isEnabled: Bool = true) -> NSAttributedString {
        let foregroundColor = isEnabled
            ? WorkbenchRedesignColors.NS.textMuted
            : WorkbenchRedesignColors.NS.textDisabled
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

struct SubtitleTableTextFragmentLayout {
    let attributed: NSAttributedString
    let origin: CGPoint
    let width: CGFloat
    let clipRect: CGRect
    let logicalUTF16Range: NSRange

    var foregroundColor: NSColor? {
        guard attributed.length > 0 else { return nil }
        return attributed.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor
    }
}
