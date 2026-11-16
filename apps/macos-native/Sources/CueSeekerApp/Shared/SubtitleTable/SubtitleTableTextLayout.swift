import AppKit
import CoreText
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
    static let cellLineHeight = WorkbenchControlMetrics.redesignLineHeightTableCell

    /// Builds a fixed line-box paragraph style with zero trailing line or paragraph spacing.
    static func fixedLineParagraphStyle(
        lineHeight: CGFloat,
        lineBreakMode: NSLineBreakMode = .byWordWrapping,
        alignment: NSTextAlignment = .left
    ) -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = lineBreakMode
        style.alignment = alignment
        style.minimumLineHeight = lineHeight
        style.maximumLineHeight = lineHeight
        style.lineSpacing = 0
        style.paragraphSpacing = 0
        return style
    }

    static func bodyParagraphStyle() -> NSParagraphStyle {
        fixedLineParagraphStyle(lineHeight: cellLineHeight)
    }

    static func body(
        _ text: String,
        role: SubtitleTableTextRole = .primaryContent,
        foregroundColor: NSColor? = nil
    ) -> NSAttributedString {
        let font = bodyFont(role: role)
        return NSAttributedString(string: text, attributes: [
            .font: font,
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

    static func header(
        _ text: String,
        isEnabled: Bool = true,
        alignment: NSTextAlignment = .left
    ) -> NSAttributedString {
        let color = isEnabled
            ? WorkbenchRedesignColors.NS.textSecondary
            : WorkbenchRedesignColors.NS.textDisabled
        return NSAttributedString(string: text, attributes: [
            .font: redesignHeaderFont,
            .paragraphStyle: fixedLineParagraphStyle(
                lineHeight: cellLineHeight,
                lineBreakMode: .byTruncatingTail,
                alignment: alignment
            ),
            .foregroundColor: color,
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
            return WorkbenchRedesignColors.NS.textSecondary
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
    private let defaultMaximumNumberOfLines: Int

    init(maximumNumberOfLines: Int = 0) {
        self.defaultMaximumNumberOfLines = maximumNumberOfLines
        textContainer.lineFragmentPadding = 0
        textContainer.maximumNumberOfLines = maximumNumberOfLines
        layoutManager.usesFontLeading = false
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
    }

    func update(
        attributedString: NSAttributedString,
        width: CGFloat,
        maximumNumberOfLines: Int? = nil
    ) {
        textContainer.maximumNumberOfLines = maximumNumberOfLines ?? defaultMaximumNumberOfLines
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

    private struct VisualLineMetrics {
        let glyphRange: NSRange
        let lineFragmentRect: CGRect
        let usedRect: CGRect
        let originalBaselineY: CGFloat
        let fontSize: CGFloat
        let metricCenterYOffset: CGFloat
        let fixedLineHeight: CGFloat?
        let lowestUnderlineOffset: CGFloat
        let deltaY: CGFloat

        var fontCenterYOffset: CGFloat {
            lineFragmentRect.minY + originalBaselineY - metricCenterYOffset + deltaY
        }
    }

    var firstLineCenterYOffset: CGFloat? {
        visualLineMetrics().first?.fontCenterYOffset
    }

    func draw(at origin: CGPoint) {
        let glyphRange = layoutManager.glyphRange(for: textContainer)
        guard glyphRange.length > 0 else { return }
        for line in visualLineMetrics() {
            layoutManager.drawGlyphs(
                forGlyphRange: line.glyphRange,
                at: CGPoint(x: origin.x, y: origin.y + line.deltaY)
            )
        }
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

    func doubleClickUTF16Range(at point: CGPoint, origin: CGPoint) -> NSRange? {
        guard textStorage.length > 0 else { return nil }
        let validGlyphRange = layoutManager.glyphRange(for: textContainer)
        guard validGlyphRange.length > 0 else { return nil }
        let localPoint = CGPoint(x: point.x - origin.x, y: point.y - origin.y)
        let rawGlyphIndex = layoutManager.glyphIndex(
            for: localPoint,
            in: textContainer,
            fractionOfDistanceThroughGlyph: nil
        )
        let glyphIndex = min(
            max(rawGlyphIndex, validGlyphRange.location),
            NSMaxRange(validGlyphRange) - 1
        )
        let characterRange = layoutManager.characterRange(
            forGlyphRange: NSRange(location: glyphIndex, length: 1),
            actualGlyphRange: nil
        )
        let charIndex = min(
            max(0, characterRange.location),
            max(0, textStorage.length - 1)
        )
        let wordRange = textStorage.doubleClick(at: charIndex)
        return wordRange.length > 0 ? wordRange : nil
    }

    func selectionRects(
        forUTF16Range range: NSRange,
        at origin: CGPoint
    ) -> [CGRect] {
        let safeRange = NSIntersectionRange(
            range,
            NSRange(location: 0, length: textStorage.length)
        )
        guard safeRange.length > 0 else { return [] }
        let glyphRange = layoutManager.glyphRange(
            forCharacterRange: safeRange,
            actualCharacterRange: nil
        )
        let lines = visualLineMetrics()
        guard !lines.isEmpty else { return [] }
        var rects: [CGRect] = []
        for line in lines {
            let lineSelectionRange = NSIntersectionRange(glyphRange, line.glyphRange)
            guard lineSelectionRange.length > 0 else { continue }
            let baselineY = origin.y
                + line.lineFragmentRect.minY
                + line.originalBaselineY
                + line.deltaY
            let band = ReadOnlyTextSelectionMetrics.verticalBounds(
                baselineY: baselineY,
                fontSize: line.fontSize
            )
            layoutManager.enumerateEnclosingRects(
                forGlyphRange: lineSelectionRange,
                withinSelectedGlyphRange: NSRange(location: NSNotFound, length: 0),
                in: textContainer
            ) { rect, _ in
                guard rect.width > 0 else { return }
                rects.append(CGRect(
                    x: origin.x + rect.minX,
                    y: band.minY,
                    width: rect.width,
                    height: band.height
                ))
            }
        }
        return ReadOnlyTextSelectionMetrics.resolvingAdjacentLineOverlaps(rects)
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
        return visualLineMetrics().compactMap { line in
            guard line.usedRect.width > 0 else { return nil }
            let baseline = origin.y
                + line.lineFragmentRect.minY
                + line.originalBaselineY
                + line.deltaY
            let y = pixelAligned(baseline + line.lowestUnderlineOffset + offset, scale: scale)
            let minX = pixelFloored(origin.x + line.usedRect.minX, scale: scale)
            let maxX = pixelCeiled(origin.x + line.usedRect.maxX, scale: scale)
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

    private func visualLineMetrics() -> [VisualLineMetrics] {
        let nsText = textStorage.string as NSString
        return lineGlyphRanges().compactMap { glyphRange in
            guard glyphRange.length > 0 else { return nil }
            let lineFragmentRect = layoutManager.lineFragmentRect(
                forGlyphAt: glyphRange.location,
                effectiveRange: nil
            )
            let usedRect = layoutManager.lineFragmentUsedRect(
                forGlyphAt: glyphRange.location,
                effectiveRange: nil
            )
            let originalBaselineY = layoutManager.location(forGlyphAt: glyphRange.location).y
            let charRange = layoutManager.characterRange(
                forGlyphRange: glyphRange,
                actualGlyphRange: nil
            )
            let attrIndex = min(max(0, charRange.location), max(0, textStorage.length - 1))
            let attrs = textStorage.length > 0
                ? textStorage.attributes(at: attrIndex, effectiveRange: nil)
                : [:]
            let fallbackFont = (attrs[.font] as? NSFont) ?? SubtitleTableText.tagFont
            let paragraphStyle = attrs[.paragraphStyle] as? NSParagraphStyle
            let fixedLineHeight: CGFloat? = if let paragraphStyle,
                                               paragraphStyle.minimumLineHeight > 0,
                                               paragraphStyle.minimumLineHeight == paragraphStyle.maximumLineHeight
            {
                paragraphStyle.minimumLineHeight
            } else {
                nil
            }

            let clampedStart = min(max(0, charRange.location), nsText.length)
            var clampedEnd = min(max(clampedStart, NSMaxRange(charRange)), nsText.length)
            while clampedEnd > clampedStart {
                let scalar = nsText.character(at: clampedEnd - 1)
                if scalar == 0x0A || scalar == 0x0D {
                    clampedEnd -= 1
                } else {
                    break
                }
            }
            let trimmedRange = NSRange(location: clampedStart, length: clampedEnd - clampedStart)
            var maxUnderlineOffset: CGFloat?
            if trimmedRange.length > 0 {
                let ctLine = CTLineCreateWithAttributedString(
                    textStorage.attributedSubstring(from: trimmedRange)
                )
                for case let run as CTRun in (CTLineGetGlyphRuns(ctLine) as NSArray) {
                    let dict = CTRunGetAttributes(run) as NSDictionary
                    if let runFont = (dict[kCTFontAttributeName] as? NSFont)
                        ?? (dict[NSAttributedString.Key.font] as? NSFont)
                    {
                        maxUnderlineOffset = max(
                            maxUnderlineOffset ?? -runFont.underlinePosition,
                            -runFont.underlinePosition
                        )
                    }
                }
            }
            let fontSize = fallbackFont.pointSize
            let metricCenterYOffset = ReadOnlyTextSelectionMetrics
                .fixedLineHeightBaselineCenterOffset(fontSize: fontSize)
            let lowestUnderlineOffset = maxUnderlineOffset ?? -fallbackFont.underlinePosition
            let deltaY = fixedLineHeight.map {
                ($0 / 2) - (originalBaselineY - metricCenterYOffset)
            } ?? 0
            return VisualLineMetrics(
                glyphRange: glyphRange,
                lineFragmentRect: lineFragmentRect,
                usedRect: usedRect,
                originalBaselineY: originalBaselineY,
                fontSize: fontSize,
                metricCenterYOffset: metricCenterYOffset,
                fixedLineHeight: fixedLineHeight,
                lowestUnderlineOffset: lowestUnderlineOffset,
                deltaY: deltaY
            )
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
    var maximumNumberOfLines: Int = 0

    var foregroundColor: NSColor? {
        guard attributed.length > 0 else { return nil }
        return attributed.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor
    }
}
