import AppKit
import CoreText
import CueSeekerCore
import SwiftUI

enum PlaybackSubtitleFocusScrollSettleDirective: Equatable {
    case none
    case cancel
    case debounce
    case immediate
}

struct PlaybackSubtitleFocusScrollSample: Equatable {
    enum Phase: Equatable {
        case none
        case began
        case changed
        case ended
        case cancelled
    }

    let deltaY: CGFloat
    let isPrecise: Bool
    let phase: Phase
    let momentumPhase: Phase
    let isInside: Bool
}

struct PlaybackVirtualReelItemExtent: Equatable {
    let visualLineCount: Int
    let visualLineStackHeight: CGFloat
    let resolvedContentHeight: CGFloat
    let firstVisualLineCenterOffset: CGFloat
    let naturalHeight: CGFloat
    let resolvedHeight: CGFloat
    let isOversized: Bool
}

typealias PlaybackSubtitleFocusCueMeasurement = PlaybackVirtualReelItemExtent

struct PlaybackVirtualReelSnapshot: Equatable {
    let datasetID: AnyHashable
    let generation: UInt64
    let revision: UInt64
    let totalCount: Int
    let loadedOrdinalRange: Range<Int>
    let loadedItemCount: Int
    let isComplete: Bool

    var isValid: Bool {
        totalCount >= 0
            && loadedOrdinalRange.lowerBound >= 0
            && loadedOrdinalRange.upperBound >= loadedOrdinalRange.lowerBound
            && loadedOrdinalRange.upperBound <= totalCount
            && loadedItemCount == loadedOrdinalRange.count
            && (!isComplete || (
                loadedOrdinalRange == 0..<totalCount
                    && loadedItemCount == totalCount
            ))
    }

    func belongsToSameDataset(as other: Self) -> Bool {
        datasetID == other.datasetID && generation == other.generation
    }
}

struct PlaybackVirtualReelSelectionCommit: Equatable {
    let datasetID: AnyHashable
    let generation: UInt64
    let ordinal: Int
}

enum PlaybackVirtualReelWindowRequestReason: Equatable {
    case visible
    case keyboard
    case wheel
    case scrollbar
}

struct PlaybackVirtualReelWindowRequest: Equatable {
    let datasetID: AnyHashable
    let generation: UInt64
    let revision: UInt64
    let targetOrdinal: Int
    let suggestedOrdinalRange: Range<Int>
    let reason: PlaybackVirtualReelWindowRequestReason
}

struct PlaybackVirtualReelWindowPolicy: Equatable {
    static let standard = Self(itemCount: 32, leadingItemCount: 16)

    let itemCount: Int
    let leadingItemCount: Int

    func windowRange(totalCount: Int, targetOrdinal: Int) -> Range<Int> {
        let resolvedTotalCount = max(0, totalCount)
        guard resolvedTotalCount > 0 else {
            return 0..<0
        }
        let count = min(max(1, itemCount), resolvedTotalCount)
        let target = min(max(0, targetOrdinal), resolvedTotalCount - 1)
        let maximumStart = resolvedTotalCount - count
        let start = min(
            max(0, target - max(0, leadingItemCount)),
            maximumStart
        )
        return start..<(start + count)
    }
}

typealias PlaybackTextSelectionHit = (
    lineUTF16Range: NSRange,
    utf16Offset: Int,
    boundaryPoint: CGPoint
)

@MainActor
protocol PlaybackVirtualReelContentAdapter: AnyObject {
    var snapshot: PlaybackVirtualReelSnapshot { get }
    var supportsWindowRequests: Bool { get }
    var measurementCacheCountForTesting: Int { get }
    var measuredOrdinalsForTesting: Set<Int> { get }

    func itemID(at ordinal: Int) -> AnyHashable?
    func extent(
        at ordinal: Int,
        isSelected: Bool,
        contentWidth: CGFloat,
        viewportHeight: CGFloat,
        uiProbeScope: String?
    ) -> PlaybackVirtualReelItemExtent?
    func drawItem(
        at ordinal: Int,
        isSelected: Bool,
        isEnabled: Bool,
        selectedTextRange: NSRange?,
        in rect: CGRect
    )
    func textSelectionHit(
        at ordinal: Int,
        point: CGPoint,
        in rect: CGRect,
        constrainedToLine lineUTF16Range: NSRange?
    ) -> PlaybackTextSelectionHit?
    func selectableTextRects(at ordinal: Int, in rect: CGRect) -> [CGRect]
    func selectedText(at ordinal: Int, range: NSRange) -> String?
    func requestWindow(_ request: PlaybackVirtualReelWindowRequest)
    func invalidateMeasurements()
    func invalidate()
}

extension PlaybackVirtualReelContentAdapter {
    var supportsWindowRequests: Bool {
        false
    }

    var measurementCacheCountForTesting: Int {
        0
    }

    var measuredOrdinalsForTesting: Set<Int> {
        []
    }

    func textSelectionHit(
        at ordinal: Int,
        point: CGPoint,
        in rect: CGRect,
        constrainedToLine lineUTF16Range: NSRange?
    ) -> PlaybackTextSelectionHit? {
        nil
    }

    func selectedText(at ordinal: Int, range: NSRange) -> String? {
        nil
    }

    func selectableTextRects(at ordinal: Int, in rect: CGRect) -> [CGRect] {
        []
    }

    func requestWindow(_ request: PlaybackVirtualReelWindowRequest) {}
}

struct PlaybackVisualLineStackSegment {
    let text: String
    let font: NSFont
    let color: NSColor
    let nominalLineHeight: CGFloat
}

struct PlaybackVisualLineStackLine: Equatable {
    let segmentIndex: Int
    let nominalLineHeight: CGFloat
    let glyphRange: NSRange
    let usedRect: CGRect
    let originalBaseline: CGFloat
    let ascent: CGFloat
    let descent: CGFloat
    let typographicTop: CGFloat
    let visibleCenterY: CGFloat

    var typographicHeight: CGFloat {
        ascent + descent
    }

    var typographicBottom: CGFloat {
        typographicTop + typographicHeight
    }
}

struct PlaybackVisualLineStackPlan: Equatable {
    let lines: [PlaybackVisualLineStackLine]
    let stackHeight: CGFloat
    let nominalContentHeight: CGFloat
    let resolvedContentHeight: CGFloat

    var visualLineCount: Int {
        lines.count
    }

    func typographicRects(in contentRect: CGRect) -> [CGRect] {
        lines.map { line in
            CGRect(
                x: contentRect.minX + line.usedRect.minX,
                y: contentRect.minY + line.typographicTop,
                width: line.usedRect.width,
                height: line.typographicHeight
            )
        }
    }
}

@MainActor
final class PlaybackVisualLineStackLayout {
    private struct DraftLine {
        let segmentIndex: Int
        let nominalLineHeight: CGFloat
        let glyphRange: NSRange
        let usedRect: CGRect
        let originalBaseline: CGFloat
        let ascent: CGFloat
        let descent: CGFloat
        let glyphBoundsMidY: CGFloat?

        var typographicHeight: CGFloat {
            ascent + descent
        }
    }

    private static let terminalLineSentinel = "\u{200B}"
    private static let segmentIndexAttribute = NSAttributedString.Key(
        "CueSeeker.PlaybackVisualLineStack.segmentIndex"
    )

    private let textStorage = NSTextStorage()
    private let layoutManager = NSLayoutManager()
    private let textContainer = NSTextContainer()
    private(set) var plan = PlaybackVisualLineStackPlan(
        lines: [],
        stackHeight: 0,
        nominalContentHeight: 0,
        resolvedContentHeight: 0
    )

    init() {
        textContainer.lineFragmentPadding = 0
        textContainer.maximumNumberOfLines = 0
        textContainer.lineBreakMode = .byWordWrapping
        layoutManager.usesFontLeading = false
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
    }

    @discardableResult
    func prepare(
        text: String,
        color: NSColor,
        width: CGFloat
    ) -> PlaybackVisualLineStackPlan {
        prepare(
            segments: [PlaybackVisualLineStackSegment(
                text: text,
                font: NSFont.systemFont(
                    ofSize: PlaybackSubtitleFocusMetrics.cueFontSize,
                    weight: PlaybackSubtitleFocusMetrics.cueFontWeight
                ),
                color: color,
                nominalLineHeight: PlaybackSubtitleFocusMetrics.cueLineHeight
            )],
            width: width
        )
    }

    @discardableResult
    func prepare(
        segments: [PlaybackVisualLineStackSegment],
        width: CGFloat
    ) -> PlaybackVisualLineStackPlan {
        let resolvedSegments = segments.isEmpty
            ? [PlaybackVisualLineStackSegment(
                text: "",
                font: NSFont.systemFont(
                    ofSize: PlaybackSubtitleFocusMetrics.cueFontSize,
                    weight: PlaybackSubtitleFocusMetrics.cueFontWeight
                ),
                color: .clear,
                nominalLineHeight: PlaybackSubtitleFocusMetrics.cueLineHeight
            )]
            : segments
        let attributedText = Self.attributedText(for: resolvedSegments)

        textStorage.setAttributedString(attributedText)
        textContainer.size = CGSize(
            width: max(1, width),
            height: 1_000_000
        )
        layoutManager.ensureLayout(for: textContainer)

        let glyphRange = layoutManager.glyphRange(for: textContainer)
        var draftLines: [DraftLine] = []
        layoutManager.enumerateLineFragments(
            forGlyphRange: glyphRange
        ) { [self] lineRect, usedRect, _, lineGlyphRange, _ in
            let characterRange = layoutManager.characterRange(
                forGlyphRange: lineGlyphRange,
                actualGlyphRange: nil
            )
            let segmentIndex = resolvedSegmentIndex(
                for: characterRange,
                segmentCount: resolvedSegments.count
            )
            let segment = resolvedSegments[segmentIndex]
            let metrics = typographicMetrics(
                for: lineGlyphRange,
                fallbackFont: segment.font
            )
            let originalBaseline = lineRect.minY
                + layoutManager.location(forGlyphAt: lineGlyphRange.location).y
            draftLines.append(DraftLine(
                segmentIndex: segmentIndex,
                nominalLineHeight: segment.nominalLineHeight,
                glyphRange: lineGlyphRange,
                usedRect: usedRect,
                originalBaseline: originalBaseline,
                ascent: metrics.ascent,
                descent: metrics.descent,
                glyphBoundsMidY: metrics.glyphBoundsMidY
            ))
        }

        if draftLines.isEmpty {
            let segment = resolvedSegments[0]
            let font = segment.font
            draftLines = [DraftLine(
                segmentIndex: 0,
                nominalLineHeight: segment.nominalLineHeight,
                glyphRange: NSRange(location: 0, length: 0),
                usedRect: .zero,
                originalBaseline: font.ascender,
                ascent: font.ascender,
                descent: -font.descender,
                glyphBoundsMidY: nil
            )]
        }

        let stackHeight = draftLines.reduce(CGFloat.zero) {
            $0 + $1.typographicHeight
        } + CGFloat(max(0, draftLines.count - 1))
            * PlaybackSubtitleFocusMetrics.internalLineGap
        let nominalContentHeight = draftLines.reduce(CGFloat.zero) {
            $0 + $1.nominalLineHeight
        }
        let resolvedContentHeight = max(nominalContentHeight, stackHeight)
        var nextTop = max(0, (resolvedContentHeight - stackHeight) / 2)
        let resolvedLines = draftLines.map { line in
            defer {
                nextTop += line.typographicHeight
                    + PlaybackSubtitleFocusMetrics.internalLineGap
            }
            return PlaybackVisualLineStackLine(
                segmentIndex: line.segmentIndex,
                nominalLineHeight: line.nominalLineHeight,
                glyphRange: line.glyphRange,
                usedRect: line.usedRect,
                originalBaseline: line.originalBaseline,
                ascent: line.ascent,
                descent: line.descent,
                typographicTop: nextTop,
                visibleCenterY: nextTop
                    + line.ascent
                    - (line.glyphBoundsMidY
                        ?? (line.ascent - line.descent) / 2)
            )
        }

        plan = PlaybackVisualLineStackPlan(
            lines: resolvedLines,
            stackHeight: stackHeight,
            nominalContentHeight: nominalContentHeight,
            resolvedContentHeight: resolvedContentHeight
        )
        return plan
    }

    func drawPreparedPlan(in contentRect: CGRect) {
        guard contentRect.width > 0,
              contentRect.height > 0,
              !plan.lines.isEmpty,
              let context = NSGraphicsContext.current
        else {
            return
        }

        context.saveGraphicsState()
        NSBezierPath(rect: contentRect).addClip()
        for line in plan.lines {
            guard line.glyphRange.length > 0 else {
                continue
            }
            let targetBaseline = contentRect.minY
                + line.typographicTop
                + line.ascent
            layoutManager.drawGlyphs(
                forGlyphRange: line.glyphRange,
                at: CGPoint(
                    x: contentRect.minX,
                    y: targetBaseline - line.originalBaseline
                )
            )
        }
        context.restoreGraphicsState()
    }

    func textSelectionHit(
        at point: CGPoint,
        in contentRect: CGRect,
        constrainedToLine constrainedLineRange: NSRange? = nil
    ) -> PlaybackTextSelectionHit? {
        let resolvedLineIndex: Int
        if let constrainedLineRange {
            let matchingLineIndices = plan.lines.indices.filter { index in
                NSIntersectionRange(
                    characterRange(for: plan.lines[index]),
                    constrainedLineRange
                ).length > 0
            }
            guard let firstLineIndex = matchingLineIndices.first,
                  let lastLineIndex = matchingLineIndices.last
            else {
                return nil
            }
            let firstRect = textRect(
                for: plan.lines[firstLineIndex],
                in: contentRect
            )
            if point.y < firstRect.minY {
                return (
                    constrainedLineRange,
                    constrainedLineRange.location,
                    CGPoint(x: firstRect.minX, y: firstRect.minY)
                )
            }
            let lastRect = textRect(
                for: plan.lines[lastLineIndex],
                in: contentRect
            )
            if point.y > lastRect.maxY {
                return (
                    constrainedLineRange,
                    NSMaxRange(constrainedLineRange),
                    CGPoint(x: lastRect.maxX, y: lastRect.minY)
                )
            }
            resolvedLineIndex = matchingLineIndices.min { left, right in
                abs(textRect(for: plan.lines[left], in: contentRect).midY - point.y)
                    < abs(textRect(for: plan.lines[right], in: contentRect).midY - point.y)
            } ?? firstLineIndex
        } else {
            guard let lineIndex = plan.lines.indices.first(where: { index in
                textRect(for: plan.lines[index], in: contentRect).contains(point)
            }) else {
                return nil
            }
            resolvedLineIndex = lineIndex
        }

        let line = plan.lines[resolvedLineIndex]
        let visualCharacterRange = characterRange(for: line)
        let lineUTF16Range = constrainedLineRange ?? logicalLineRange(
            containing: visualCharacterRange.location
        )
        let selectableCharacterRange = NSIntersectionRange(
            visualCharacterRange,
            lineUTF16Range
        )
        guard selectableCharacterRange.length > 0 else {
            return nil
        }

        let resolvedTextRect = textRect(for: line, in: contentRect)
        let localX = point.x - contentRect.minX
        if localX <= line.usedRect.minX {
            return (
                lineUTF16Range,
                selectableCharacterRange.location,
                CGPoint(x: resolvedTextRect.minX, y: resolvedTextRect.minY)
            )
        }
        if localX >= line.usedRect.maxX {
            return (
                lineUTF16Range,
                NSMaxRange(selectableCharacterRange),
                CGPoint(x: resolvedTextRect.maxX, y: resolvedTextRect.minY)
            )
        }

        let localPoint = CGPoint(
            x: localX,
            y: line.usedRect.midY
        )
        var fraction: CGFloat = 0
        let rawGlyphIndex = layoutManager.glyphIndex(
            for: localPoint,
            in: textContainer,
            fractionOfDistanceThroughGlyph: &fraction
        )
        let selectableGlyphRange = layoutManager.glyphRange(
            forCharacterRange: selectableCharacterRange,
            actualCharacterRange: nil
        )
        guard selectableGlyphRange.length > 0 else {
            return nil
        }
        let glyphIndex = min(
            max(rawGlyphIndex, selectableGlyphRange.location),
            NSMaxRange(selectableGlyphRange) - 1
        )
        let glyphCharacterRange = layoutManager.characterRange(
            forGlyphRange: NSRange(location: glyphIndex, length: 1),
            actualGlyphRange: nil
        )
        let usesTrailingBoundary = fraction >= 0.5
        let rawOffset = usesTrailingBoundary
            ? NSMaxRange(glyphCharacterRange)
            : glyphCharacterRange.location
        let glyphRect = layoutManager.boundingRect(
            forGlyphRange: NSRange(location: glyphIndex, length: 1),
            in: textContainer
        )
        return (
            lineUTF16Range,
            min(
                max(rawOffset, selectableCharacterRange.location),
                NSMaxRange(selectableCharacterRange)
            ),
            CGPoint(
                x: contentRect.minX
                    + (usesTrailingBoundary ? glyphRect.maxX : glyphRect.minX),
                y: resolvedTextRect.minY
            )
        )
    }

    func drawSelection(
        forUTF16Range range: NSRange,
        in contentRect: CGRect
    ) {
        let safeRange = NSIntersectionRange(
            range,
            NSRange(location: 0, length: textStorage.length)
        )
        guard safeRange.length > 0,
              let context = NSGraphicsContext.current
        else {
            return
        }

        context.saveGraphicsState()
        NSBezierPath(rect: contentRect).addClip()
        NSColor.selectedTextBackgroundColor.setFill()
        let selectionGlyphRange = layoutManager.glyphRange(
            forCharacterRange: safeRange,
            actualCharacterRange: nil
        )
        for line in plan.lines {
            let lineSelectionRange = NSIntersectionRange(
                selectionGlyphRange,
                line.glyphRange
            )
            guard lineSelectionRange.length > 0 else {
                continue
            }
            layoutManager.boundingRect(
                forGlyphRange: lineSelectionRange,
                in: textContainer
            ).offsetBy(
                dx: contentRect.minX,
                dy: contentRect.minY
                    + line.typographicTop
                    + line.ascent
                    - line.originalBaseline
            ).fill()
        }
        context.restoreGraphicsState()
    }

    func selectedText(forUTF16Range range: NSRange) -> String? {
        let safeRange = NSIntersectionRange(
            range,
            NSRange(location: 0, length: textStorage.length)
        )
        guard safeRange.length > 0 else {
            return nil
        }
        return (textStorage.string as NSString).substring(with: safeRange)
    }

    private func textRect(
        for line: PlaybackVisualLineStackLine,
        in contentRect: CGRect
    ) -> CGRect {
        CGRect(
            x: contentRect.minX + line.usedRect.minX,
            y: contentRect.minY + line.typographicTop,
            width: line.usedRect.width,
            height: line.typographicHeight
        )
    }

    private func characterRange(
        for line: PlaybackVisualLineStackLine
    ) -> NSRange {
        rangeWithoutLineTerminators(
            layoutManager.characterRange(
                forGlyphRange: line.glyphRange,
                actualGlyphRange: nil
            )
        )
    }

    private func logicalLineRange(containing offset: Int) -> NSRange {
        let string = textStorage.string as NSString
        let location = min(max(0, offset), max(0, string.length - 1))
        return rangeWithoutLineTerminators(
            string.lineRange(for: NSRange(location: location, length: 0))
        )
    }

    private func typographicMetrics(
        for glyphRange: NSRange,
        fallbackFont: NSFont
    ) -> (
        ascent: CGFloat,
        descent: CGFloat,
        glyphBoundsMidY: CGFloat?
    ) {
        let characterRange = layoutManager.characterRange(
            forGlyphRange: glyphRange,
            actualGlyphRange: nil
        )
        let metricRange = rangeWithoutLineTerminators(characterRange)
        guard metricRange.length > 0 else {
            return (fallbackFont.ascender, -fallbackFont.descender, nil)
        }

        let attributedLine = textStorage.attributedSubstring(from: metricRange)
        let coreTextLine = CTLineCreateWithAttributedString(attributedLine)
        let glyphBounds = CTLineGetBoundsWithOptions(
            coreTextLine,
            [.useGlyphPathBounds]
        )
        let glyphBoundsMidY = glyphBounds.isNull || glyphBounds.isEmpty
            ? nil
            : glyphBounds.midY
        let runs = CTLineGetGlyphRuns(coreTextLine) as NSArray
        var resolvedAscent: CGFloat = 0
        var resolvedDescent: CGFloat = 0
        for case let run as CTRun in runs {
            var ascent: CGFloat = 0
            var descent: CGFloat = 0
            var leading: CGFloat = 0
            _ = CTRunGetTypographicBounds(
                run,
                CFRange(location: 0, length: 0),
                &ascent,
                &descent,
                &leading
            )
            resolvedAscent = max(resolvedAscent, ascent)
            resolvedDescent = max(resolvedDescent, descent)
        }

        guard resolvedAscent > 0 || resolvedDescent > 0 else {
            return (
                fallbackFont.ascender,
                -fallbackFont.descender,
                glyphBoundsMidY
            )
        }
        return (resolvedAscent, resolvedDescent, glyphBoundsMidY)
    }

    private func resolvedSegmentIndex(
        for characterRange: NSRange,
        segmentCount: Int
    ) -> Int {
        guard textStorage.length > 0 else {
            return 0
        }
        let location = min(characterRange.location, textStorage.length - 1)
        let rawIndex = (textStorage.attribute(
            Self.segmentIndexAttribute,
            at: location,
            effectiveRange: nil
        ) as? NSNumber)?.intValue ?? 0
        return min(max(0, rawIndex), max(0, segmentCount - 1))
    }

    private func rangeWithoutLineTerminators(_ range: NSRange) -> NSRange {
        var result = range
        let string = textStorage.string as NSString
        while result.length > 0 {
            let characterRange = string.rangeOfComposedCharacterSequence(
                at: NSMaxRange(result) - 1
            )
            let character = string.substring(with: characterRange)
            guard character == "\n"
                    || character == "\r"
                    || character == Self.terminalLineSentinel
            else {
                break
            }
            result.length = characterRange.location - result.location
        }
        return result
    }

    private static func attributedText(
        for segments: [PlaybackVisualLineStackSegment]
    ) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for (index, segment) in segments.enumerated() {
            let normalizedText = normalizedText(segment.text)
            let attributes = attributes(for: segment, segmentIndex: index)
            if !normalizedText.isEmpty {
                result.append(NSAttributedString(
                    string: normalizedText,
                    attributes: attributes
                ))
            }

            if index < segments.count - 1 {
                result.append(NSAttributedString(
                    string: "\n",
                    attributes: attributes
                ))
            } else if normalizedText.isEmpty || normalizedText.hasSuffix("\n") {
                var sentinelAttributes = attributes
                sentinelAttributes[.foregroundColor] = NSColor.clear
                result.append(NSAttributedString(
                    string: terminalLineSentinel,
                    attributes: sentinelAttributes
                ))
            }
        }
        return result
    }

    private static func attributes(
        for segment: PlaybackVisualLineStackSegment,
        segmentIndex: Int
    ) -> [NSAttributedString.Key: Any] {
        [
            .font: segment.font,
            .foregroundColor: segment.color,
            .paragraphStyle: paragraphStyle(
                lineHeight: segment.nominalLineHeight
            ),
            segmentIndexAttribute: NSNumber(value: segmentIndex),
        ]
    }

    private static func paragraphStyle(lineHeight: CGFloat) -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byWordWrapping
        style.minimumLineHeight = max(0, lineHeight)
        style.maximumLineHeight = max(0, lineHeight)
        style.lineSpacing = 0
        style.paragraphSpacing = 0
        return style
    }

    private static func normalizedText(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
    }
}

@MainActor
final class PlaybackSubtitleFocusCueTextMeasurer {
    private let visualLineLayout = PlaybackVisualLineStackLayout()

    func measurement(
        text: String,
        width: CGFloat,
        viewportHeight: CGFloat
    ) -> PlaybackSubtitleFocusCueMeasurement {
        let plan = visualLineLayout.prepare(
            text: text,
            color: .white,
            width: width
        )
        let naturalHeight = max(
            PlaybackSubtitleFocusMetrics.minimumNaturalCueHeight,
            plan.resolvedContentHeight
                + PlaybackSubtitleFocusMetrics.cueVerticalPadding * 2
        )
        let safeViewportHeight = max(0, viewportHeight)
        return PlaybackSubtitleFocusCueMeasurement(
            visualLineCount: plan.visualLineCount,
            visualLineStackHeight: plan.stackHeight,
            resolvedContentHeight: plan.resolvedContentHeight,
            firstVisualLineCenterOffset:
                PlaybackSubtitleFocusMetrics.cueVerticalPadding
                    + (plan.lines.first?.visibleCenterY
                        ?? PlaybackSubtitleFocusMetrics.cueLineHeight / 2),
            naturalHeight: naturalHeight,
            resolvedHeight: min(naturalHeight, safeViewportHeight),
            isOversized: naturalHeight > safeViewportHeight
        )
    }

}

struct PlaybackVirtualReelLayout: Equatable {
    static let overscanItemCount = 4

    let viewportSize: CGSize
    let totalCount: Int
    let focusAnchorY: CGFloat
    let loadedOrdinalRange: Range<Int>
    let fractionalOrdinal: CGFloat

    init(
        viewportSize: CGSize,
        totalCount: Int,
        loadedOrdinalRange: Range<Int>,
        fractionalOrdinal: CGFloat
    ) {
        self.viewportSize = CGSize(
            width: max(0, viewportSize.width),
            height: max(0, viewportSize.height)
        )
        self.totalCount = max(0, totalCount)
        focusAnchorY = self.viewportSize.height / 2
        let lower = min(max(0, loadedOrdinalRange.lowerBound), self.totalCount)
        let upper = min(
            max(lower, loadedOrdinalRange.upperBound),
            self.totalCount
        )
        self.loadedOrdinalRange = lower..<upper
        self.fractionalOrdinal = Self.clampedFractionalOrdinal(
            fractionalOrdinal,
            to: self.loadedOrdinalRange
        )
    }

    var lowerOrdinal: Int {
        guard !loadedOrdinalRange.isEmpty else {
            return 0
        }
        return min(
            loadedOrdinalRange.upperBound - 1,
            max(loadedOrdinalRange.lowerBound, Int(floor(fractionalOrdinal)))
        )
    }

    var upperOrdinal: Int {
        min(max(loadedOrdinalRange.lowerBound, lowerOrdinal + 1), max(
            loadedOrdinalRange.lowerBound,
            loadedOrdinalRange.upperBound - 1
        ))
    }

    var interpolationFraction: CGFloat {
        guard upperOrdinal != lowerOrdinal else {
            return 0
        }
        return fractionalOrdinal - CGFloat(lowerOrdinal)
    }

    var nearestOrdinal: Int {
        guard !loadedOrdinalRange.isEmpty else {
            return 0
        }
        return min(
            loadedOrdinalRange.upperBound - 1,
            max(
                loadedOrdinalRange.lowerBound,
                Int(fractionalOrdinal.rounded())
            )
        )
    }

    func acceptedTop(forResolvedHeight height: CGFloat) -> CGFloat {
        focusAnchorY - max(0, height) / 2
    }

    func adjacentCenterDistance(
        from currentHeight: CGFloat,
        to targetHeight: CGFloat
    ) -> CGFloat {
        max(0, currentHeight) / 2
            + PlaybackSubtitleFocusMetrics.cueGap
            + max(0, targetHeight) / 2
    }

    func lowerCueTop(
        lowerResolvedHeight: CGFloat,
        upperResolvedHeight: CGFloat
    ) -> CGFloat {
        acceptedTop(forResolvedHeight: lowerResolvedHeight)
            - interpolationFraction * adjacentCenterDistance(
                from: lowerResolvedHeight,
                to: upperResolvedHeight
            )
    }

    static func clampedFractionalOrdinal(
        _ value: CGFloat,
        to range: Range<Int>
    ) -> CGFloat {
        guard !range.isEmpty else {
            return 0
        }
        let finiteValue = value.isFinite ? value : CGFloat(range.lowerBound)
        return min(
            CGFloat(range.upperBound - 1),
            max(CGFloat(range.lowerBound), finiteValue)
        )
    }

    var contentWidth: CGFloat {
        max(
            0,
            min(
                PlaybackSubtitleFocusMetrics.contentMaxWidth,
                viewportSize.width - PlaybackSubtitleFocusMetrics.contentInset * 2
            )
        )
    }

}

typealias PlaybackSubtitleFocusVirtualReelLayout = PlaybackVirtualReelLayout

struct PlaybackVirtualReelItemPlacement: Equatable {
    let ordinal: Int
    let itemID: AnyHashable
    let rect: CGRect
    let extent: PlaybackVirtualReelItemExtent

    var measurement: PlaybackVirtualReelItemExtent {
        extent
    }

    var cueID: Int64 {
        itemID.base as? Int64 ?? 0
    }
}

typealias PlaybackSubtitleFocusCuePlacement = PlaybackVirtualReelItemPlacement

@MainActor
private final class PlaybackSubtitleFocusCueMeasurementCache {
    private struct Key: Hashable {
        let cueID: Int64
        let text: String
        let width: CGFloat
        let viewportHeight: CGFloat
        let styleRevision: Int
    }

    private struct Entry {
        let measurement: PlaybackSubtitleFocusCueMeasurement
        let ordinal: Int
        var lastAccess: UInt64
    }

    private let capacity: Int
    private let measurer = PlaybackSubtitleFocusCueTextMeasurer()
    private var entries: [Key: Entry] = [:]
    private var accessSequence: UInt64 = 0
    private(set) var measurementCount = 0

    init(capacity: Int = 64) {
        self.capacity = max(1, capacity)
    }

    var count: Int {
        entries.count
    }

    var measuredOrdinals: Set<Int> {
        Set(entries.values.map(\.ordinal))
    }

    func measurement(
        for cue: SubtitleFocusCue,
        width: CGFloat,
        viewportHeight: CGFloat,
        uiProbeScope: String? = nil
    ) -> PlaybackSubtitleFocusCueMeasurement {
        accessSequence &+= 1
        let key = Key(
            cueID: cue.id,
            text: cue.text,
            width: width,
            viewportHeight: viewportHeight,
            styleRevision: 2
        )
        if var entry = entries[key] {
            entry.lastAccess = accessSequence
            entries[key] = entry
            return entry.measurement
        }

        let measurement = measurer.measurement(
            text: cue.text,
            width: width,
            viewportHeight: viewportHeight
        )
        measurementCount += 1
        UIInvalidationProbe.count(
            "playback.subtitle_focus.cue_measurement",
            scope: uiProbeScope,
            details: "ordinal=\(cue.ordinal)"
        )
        entries[key] = Entry(
            measurement: measurement,
            ordinal: cue.ordinal,
            lastAccess: accessSequence
        )
        evictIfNeeded()
        return measurement
    }

    func removeAll() {
        entries.removeAll(keepingCapacity: true)
    }

    private func evictIfNeeded() {
        while entries.count > capacity,
              let oldest = entries.min(by: {
                  $0.value.lastAccess < $1.value.lastAccess
              })?.key {
            entries.removeValue(forKey: oldest)
        }
    }
}

@MainActor
final class PlaybackSubtitleFocusCueReelAdapter:
    PlaybackVirtualReelContentAdapter
{
    private struct SnapshotSignature: Equatable {
        let totalCount: Int
        let cueCount: Int
        let firstID: Int64?
        let lastID: Int64?
        let firstOrdinal: Int?
        let lastOrdinal: Int?
        let storageAddress: UInt?

        init(cues: [SubtitleFocusCue], totalCount: Int) {
            self.totalCount = totalCount
            cueCount = cues.count
            firstID = cues.first?.id
            lastID = cues.last?.id
            firstOrdinal = cues.first?.ordinal
            lastOrdinal = cues.last?.ordinal
            storageAddress = cues.withUnsafeBufferPointer { buffer in
                buffer.baseAddress.map { UInt(bitPattern: $0) }
            }
        }
    }

    private let datasetID = AnyHashable("current")
    private let measurementCache = PlaybackSubtitleFocusCueMeasurementCache()
    private let textLayout = PlaybackSubtitleFocusNativeTextLayout()
    private var cues: [SubtitleFocusCue] = []
    private var firstLoadedOrdinal = 0
    private var signature: SnapshotSignature?
    private var revision: UInt64 = 0
    private var displayTitle = ""
    private(set) var snapshot = PlaybackVirtualReelSnapshot(
        datasetID: AnyHashable("current"),
        generation: 0,
        revision: 0,
        totalCount: 0,
        loadedOrdinalRange: 0..<0,
        loadedItemCount: 0,
        isComplete: true
    )

    var measurementCacheCountForTesting: Int {
        measurementCache.count
    }

    var measuredOrdinalsForTesting: Set<Int> {
        measurementCache.measuredOrdinals
    }

    var measurementCountForTesting: Int {
        measurementCache.measurementCount
    }

    func update(
        cues: [SubtitleFocusCue],
        totalCount: Int,
        displayTitle: String,
        generation: UInt64
    ) {
        let resolvedTotalCount = max(0, totalCount)
        let nextSignature = SnapshotSignature(
            cues: cues,
            totalCount: resolvedTotalCount
        )
        if snapshot.generation != generation {
            revision = 0
            invalidateMeasurements()
        } else if signature != nextSignature || self.displayTitle != displayTitle {
            revision &+= 1
        }
        signature = nextSignature
        self.cues = cues
        self.displayTitle = displayTitle
        firstLoadedOrdinal = cues.first?.ordinal ?? 0
        let loadedOrdinalRange: Range<Int>
        if let firstOrdinal = cues.first?.ordinal,
           let lastOrdinal = cues.last?.ordinal {
            loadedOrdinalRange = firstOrdinal..<(lastOrdinal + 1)
        } else {
            loadedOrdinalRange = 0..<0
        }
        snapshot = PlaybackVirtualReelSnapshot(
            datasetID: datasetID,
            generation: generation,
            revision: revision,
            totalCount: resolvedTotalCount,
            loadedOrdinalRange: loadedOrdinalRange,
            loadedItemCount: cues.count,
            isComplete: cues.count == resolvedTotalCount
                && loadedOrdinalRange == 0..<resolvedTotalCount
        )
    }

    func itemID(at ordinal: Int) -> AnyHashable? {
        cue(at: ordinal).map { AnyHashable($0.id) }
    }

    func extent(
        at ordinal: Int,
        isSelected _: Bool,
        contentWidth: CGFloat,
        viewportHeight: CGFloat,
        uiProbeScope: String?
    ) -> PlaybackVirtualReelItemExtent? {
        guard let cue = cue(at: ordinal) else {
            return nil
        }
        let baseMeasurement = measurementCache.measurement(
            for: cue,
            width: contentWidth,
            viewportHeight: viewportHeight,
            uiProbeScope: uiProbeScope
        )
        guard metadata(for: cue) != nil else {
            return baseMeasurement
        }
        return addingMetadataHeight(
            to: baseMeasurement,
            viewportHeight: viewportHeight
        )
    }

    func drawItem(
        at ordinal: Int,
        isSelected: Bool,
        isEnabled: Bool,
        selectedTextRange: NSRange?,
        in rect: CGRect
    ) {
        guard let cue = cue(at: ordinal) else {
            return
        }
        let cueRect = cueTextRect(in: rect, for: cue)
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(rect: rect).addClip()
        defer { NSGraphicsContext.restoreGraphicsState() }
        textLayout.draw(
            text: cue.text,
            color: isSelected
                ? PlaybackTheme.subtitleFocusCueSelectedNative
                : isEnabled
                    ? PlaybackTheme.subtitleFocusCueUnselectedNative
                    : WorkbenchRedesignColors.NS.textDisabled,
            selectedTextRange: selectedTextRange,
            in: cueRect
        )
        let metadata = metadata(for: cue)
        PlaybackCueMetadataLayout.draw(
            PlaybackCueMetadataLayout.makePlan(
                metadata: metadata,
                width: rect.width
            ),
            in: metadataRect(in: rect, for: cue),
            isEnabled: isEnabled
        )
    }

    func textSelectionHit(
        at ordinal: Int,
        point: CGPoint,
        in rect: CGRect,
        constrainedToLine lineUTF16Range: NSRange?
    ) -> PlaybackTextSelectionHit? {
        guard let cue = cue(at: ordinal) else {
            return nil
        }
        return textLayout.textSelectionHit(
            text: cue.text,
            point: point,
            in: cueTextRect(in: rect, for: cue),
            constrainedToLine: lineUTF16Range
        )
    }

    func selectedText(at ordinal: Int, range: NSRange) -> String? {
        guard cue(at: ordinal) != nil else {
            return nil
        }
        return textLayout.selectedText(range: range)
    }

    func selectableTextRects(at ordinal: Int, in rect: CGRect) -> [CGRect] {
        guard let cue = cue(at: ordinal) else {
            return []
        }
        return textLayout.visibleLineRects(
            text: cue.text,
            in: cueTextRect(in: rect, for: cue)
        )
    }

    func invalidate() {
        cues.removeAll(keepingCapacity: false)
        firstLoadedOrdinal = 0
        signature = nil
        displayTitle = ""
        invalidateMeasurements()
    }

    func invalidateMeasurements() {
        measurementCache.removeAll()
    }

    private func cueTextRect(
        in rect: CGRect,
        for cue: SubtitleFocusCue
    ) -> CGRect {
        let baseMeasurement = naturalMeasurement(for: cue, width: rect.width)
        return CGRect(
            x: rect.minX,
            y: rect.minY,
            width: rect.width,
            height: min(rect.height, baseMeasurement.naturalHeight)
        )
    }

    func metadata(at ordinal: Int) -> PlaybackCueMetadata? {
        cue(at: ordinal).flatMap(metadata(for:))
    }

    private func cue(at ordinal: Int) -> SubtitleFocusCue? {
        let index = ordinal - firstLoadedOrdinal
        guard cues.indices.contains(index), cues[index].ordinal == ordinal else {
            return nil
        }
        return cues[index]
    }

    private func metadata(for cue: SubtitleFocusCue) -> PlaybackCueMetadata? {
        guard !displayTitle.isEmpty else {
            return nil
        }
        return PlaybackCueMetadata(
            displayTitle: displayTitle,
            timeRange: PlaybackCueInformationText.timeRange(
                startMilliseconds: cue.startMilliseconds,
                endMilliseconds: cue.endMilliseconds
            )
        )
    }

    private func naturalMeasurement(
        for cue: SubtitleFocusCue,
        width: CGFloat
    ) -> PlaybackSubtitleFocusCueMeasurement {
        measurementCache.measurement(
            for: cue,
            width: width,
            viewportHeight: .greatestFiniteMagnitude
        )
    }

    private func metadataRect(
        in rect: CGRect,
        for cue: SubtitleFocusCue
    ) -> CGRect {
        let baseMeasurement = naturalMeasurement(for: cue, width: rect.width)
        return CGRect(
            x: rect.minX,
            y: rect.minY
                + PlaybackSubtitleFocusMetrics.cueVerticalPadding
                + baseMeasurement.resolvedContentHeight
                + PlaybackSubtitleFocusMetrics.metadataCueGap,
            width: rect.width,
            height: PlaybackSubtitleFocusMetrics.metadataLineHeight
        )
    }

    private func addingMetadataHeight(
        to base: PlaybackSubtitleFocusCueMeasurement,
        viewportHeight: CGFloat
    ) -> PlaybackSubtitleFocusCueMeasurement {
        let metadataHeight = PlaybackSubtitleFocusMetrics.metadataHeight
        let naturalHeight = base.naturalHeight + metadataHeight
        let safeViewportHeight = max(0, viewportHeight)
        return PlaybackSubtitleFocusCueMeasurement(
            visualLineCount: base.visualLineCount,
            visualLineStackHeight: base.visualLineStackHeight,
            resolvedContentHeight:
                base.resolvedContentHeight + metadataHeight,
            firstVisualLineCenterOffset: base.firstVisualLineCenterOffset,
            naturalHeight: naturalHeight,
            resolvedHeight: min(naturalHeight, safeViewportHeight),
            isOversized: naturalHeight > safeViewportHeight
        )
    }

}

struct PlaybackSubtitleFocusNativeScrollbarMetrics: Equatable {
    let totalCount: Int
    let fractionalOrdinal: CGFloat
    let visibleCueCapacity: Int

    init(
        totalCount: Int,
        fractionalOrdinal: CGFloat,
        visibleCueCapacity: Int
    ) {
        self.totalCount = max(0, totalCount)
        self.fractionalOrdinal = fractionalOrdinal.isFinite
            ? fractionalOrdinal
            : 0
        self.visibleCueCapacity = max(1, visibleCueCapacity)
    }

    var presentation: TableScrollbarPresentation {
        guard totalCount > visibleCueCapacity else {
            return TableScrollbarPresentation()
        }
        let lastOrdinal = max(0, totalCount - 1)
        let boundedOrdinal = min(
            CGFloat(lastOrdinal),
            max(0, fractionalOrdinal)
        )
        return TableScrollbarPresentation(
            vertical: TableScrollbarAxisPresentation(
                visibleFraction: min(
                    1,
                    CGFloat(max(1, visibleCueCapacity)) / CGFloat(totalCount)
                ),
                positionFraction: lastOrdinal > 0
                    ? boundedOrdinal / CGFloat(lastOrdinal)
                    : 0
            )
        )
    }

    func fractionalOrdinal(for positionFraction: CGFloat) -> CGFloat {
        let fraction = positionFraction.isFinite
            ? min(1, max(0, positionFraction))
            : 0
        return fraction * CGFloat(max(0, totalCount - 1))
    }

}

enum PlaybackSubtitleFocusNativeWheelMode: Equatable {
    case none
    case discrete(direction: SubtitleFocusNavigationDirection, stepCount: Int)
    case precise(deltaY: CGFloat, beginsGesture: Bool)
}

struct PlaybackSubtitleFocusNativeWheelOutput: Equatable {
    let shouldConsume: Bool
    let mode: PlaybackSubtitleFocusNativeWheelMode
    let settleDirective: PlaybackSubtitleFocusScrollSettleDirective

    static let passThrough = PlaybackSubtitleFocusNativeWheelOutput(
        shouldConsume: false,
        mode: .none,
        settleDirective: .none
    )

    static let consumedNoop = PlaybackSubtitleFocusNativeWheelOutput(
        shouldConsume: true,
        mode: .none,
        settleDirective: .none
    )
}

struct PlaybackSubtitleFocusNativeWheelState: Equatable {
    private var ownsPreciseGesture = false
    private var awaitsMomentum = false
    private var requiresNewGesture = false

    mutating func consume(
        _ sample: PlaybackSubtitleFocusScrollSample,
        isEnabled: Bool
    ) -> PlaybackSubtitleFocusNativeWheelOutput {
        guard isEnabled else {
            reset(requiresNewGesture: true)
            return .consumedNoop
        }

        let hasNoPhases = sample.phase == .none && sample.momentumPhase == .none
        let isDiscrete = !sample.isPrecise
        if requiresNewGesture {
            let startsFreshGesture = isDiscrete
                || sample.phase == .began
                || (sample.isPrecise && hasNoPhases && sample.isInside)
            guard startsFreshGesture else {
                return .consumedNoop
            }
            requiresNewGesture = false
        }

        if isDiscrete {
            guard sample.isInside else {
                return .passThrough
            }
            guard sample.deltaY.isFinite, sample.deltaY != 0 else {
                return .consumedNoop
            }
            let direction: SubtitleFocusNavigationDirection = sample.deltaY > 0
                ? .backward
                : .forward
            return PlaybackSubtitleFocusNativeWheelOutput(
                shouldConsume: true,
                mode: .discrete(
                    direction: direction,
                    stepCount: max(1, Int(abs(sample.deltaY).rounded(.up)))
                ),
                settleDirective: .none
            )
        }

        if sample.isPrecise && hasNoPhases {
            guard sample.isInside || ownsPreciseGesture else {
                return .passThrough
            }
            let beginsGesture = !ownsPreciseGesture
            ownsPreciseGesture = true
            return preciseOutput(
                sample,
                beginsGesture: beginsGesture,
                settleDirective: .debounce
            )
        }

        var beginsGesture = false
        if sample.phase == .began {
            ownsPreciseGesture = sample.isInside
            awaitsMomentum = false
            beginsGesture = ownsPreciseGesture
        } else if sample.momentumPhase == .began, awaitsMomentum {
            ownsPreciseGesture = true
            awaitsMomentum = false
        } else if !ownsPreciseGesture,
                  !awaitsMomentum,
                  sample.phase == .changed,
                  sample.isInside {
            ownsPreciseGesture = true
            beginsGesture = true
        }

        guard ownsPreciseGesture else {
            return .passThrough
        }
        if sample.phase == .cancelled || sample.momentumPhase == .cancelled {
            ownsPreciseGesture = false
            awaitsMomentum = false
            return preciseOutput(
                sample,
                beginsGesture: beginsGesture,
                settleDirective: .immediate
            )
        }
        if sample.momentumPhase == .ended {
            ownsPreciseGesture = false
            awaitsMomentum = false
            return preciseOutput(
                sample,
                beginsGesture: beginsGesture,
                settleDirective: .immediate
            )
        }
        if sample.momentumPhase == .began {
            ownsPreciseGesture = true
            awaitsMomentum = false
            return preciseOutput(
                sample,
                beginsGesture: beginsGesture,
                settleDirective: .cancel
            )
        }
        if sample.phase == .ended {
            ownsPreciseGesture = false
            awaitsMomentum = true
            return preciseOutput(
                sample,
                beginsGesture: beginsGesture,
                settleDirective: .debounce
            )
        }
        return preciseOutput(
            sample,
            beginsGesture: beginsGesture,
            settleDirective: .cancel
        )
    }

    mutating func finishPreciseGesture() {
        ownsPreciseGesture = false
        awaitsMomentum = false
    }

    mutating func reset(requiresNewGesture: Bool = false) {
        ownsPreciseGesture = false
        awaitsMomentum = false
        self.requiresNewGesture = requiresNewGesture
    }

    private func preciseOutput(
        _ sample: PlaybackSubtitleFocusScrollSample,
        beginsGesture: Bool,
        settleDirective: PlaybackSubtitleFocusScrollSettleDirective
    ) -> PlaybackSubtitleFocusNativeWheelOutput {
        let deltaY = sample.deltaY.isFinite ? sample.deltaY : 0
        return PlaybackSubtitleFocusNativeWheelOutput(
            shouldConsume: true,
            mode: .precise(
                deltaY: deltaY,
                beginsGesture: beginsGesture
            ),
            settleDirective: settleDirective
        )
    }
}

struct PlaybackSubtitleFocusReelRepresentable: NSViewRepresentable {
    let cues: [SubtitleFocusCue]
    let totalCount: Int
    let selectedOrdinal: Int
    let displayTitle: String
    let contentGeneration: Int
    let uiProbeScope: String?
    let keyboardNavigationRequest: PlaybackSubtitleFocusKeyboardNavigationRequest?
    let reducesMotion: Bool
    let isInteractionEnabled: Bool
    let cancelsWheelMotion: Bool
    let collageSelectedCueIDs: Set<Int64>?
    let collageCanSelectAnotherCue: Bool
    let onCommitKeyboardNavigation: (PlaybackSubtitleFocusKeyboardNavigationRequest) -> Bool
    let onCommitNativeReelSelection: (Int) -> Bool
    let onToggleCollageCueSelection: (Int) -> Void
    let onCopySelectedText: (String) -> Void
    let onSearchSelectedText: (String) -> Void
    let allowsNativeWheelInput: () -> Bool
    let allowsNativeScrollbarInput: () -> Bool
    let onScrollbarDraggingChanged: (Bool) -> Void
    let onNativeMotionGateChanged: (Bool) -> Void
    let onKeyboardMotionChanged: (Bool) -> Void
    var interfaceLayers: InterfaceLayerRegistry?
    var isCoveredByHigherLayer = false

    func makeNSView(context: Context) -> PlaybackSubtitleFocusReelContainerView {
        UIInvalidationProbe.count(
            "playback.subtitle_focus.native_make",
            scope: uiProbeScope
        )
        let view = PlaybackSubtitleFocusReelContainerView()
        update(view)
        return view
    }

    func updateNSView(
        _ nsView: PlaybackSubtitleFocusReelContainerView,
        context: Context
    ) {
        UIInvalidationProbe.count(
            "playback.subtitle_focus.native_update",
            scope: uiProbeScope
        )
        update(nsView)
    }

    static func dismantleNSView(
        _ nsView: PlaybackSubtitleFocusReelContainerView,
        coordinator: Void
    ) {
        nsView.invalidate()
    }

    private func update(_ view: PlaybackSubtitleFocusReelContainerView) {
        view.uiProbeScope = uiProbeScope
        view.onCommitKeyboardNavigation = onCommitKeyboardNavigation
        view.onCommitNativeReelSelection = onCommitNativeReelSelection
        view.onToggleCollageCueSelection = onToggleCollageCueSelection
        view.onCopySelectedText = onCopySelectedText
        view.onSearchSelectedText = onSearchSelectedText
        view.allowsNativeWheelInput = allowsNativeWheelInput
        view.allowsNativeScrollbarInput = allowsNativeScrollbarInput
        view.onScrollbarDraggingChanged = onScrollbarDraggingChanged
        view.onNativeMotionGateChanged = onNativeMotionGateChanged
        view.onKeyboardMotionChanged = onKeyboardMotionChanged
        view.interfaceLayers = interfaceLayers
        view.isCoveredByHigherLayer = isCoveredByHigherLayer
        view.update(
            cues: cues,
            totalCount: totalCount,
            selectedOrdinal: selectedOrdinal,
            displayTitle: displayTitle,
            contentGeneration: UInt64(max(0, contentGeneration)),
            keyboardNavigationRequest: keyboardNavigationRequest,
            reducesMotion: reducesMotion,
            isInteractionEnabled: isInteractionEnabled,
            cancelsWheelMotion: cancelsWheelMotion,
            collageSelectedCueIDs: collageSelectedCueIDs,
            collageCanSelectAnotherCue: collageCanSelectAnotherCue
        )
    }
}

final class PlaybackSubtitleFocusReelContainerView: NSView {
    private struct ContentToken: Equatable {
        let datasetID: AnyHashable
        let generation: UInt64
    }

    private enum PendingWindowSelection: Equatable {
        case keyboard(
            token: ContentToken,
            request: PlaybackSubtitleFocusKeyboardNavigationRequest
        )
        case native(
            token: ContentToken,
            ordinal: Int,
            reason: PlaybackVirtualReelWindowRequestReason
        )
        case restore(token: ContentToken, ordinal: Int)

        var token: ContentToken {
            switch self {
            case .keyboard(let token, _),
                 .native(let token, _, _),
                 .restore(let token, _):
                token
            }
        }

        var ordinal: Int {
            switch self {
            case .keyboard(_, let request):
                request.targetOrdinal
            case .native(_, let ordinal, _):
                ordinal
            case .restore(_, let ordinal):
                ordinal
            }
        }

        var requestReason: PlaybackVirtualReelWindowRequestReason {
            switch self {
            case .keyboard:
                .keyboard
            case .native(_, _, let reason):
                reason
            case .restore:
                .visible
            }
        }
    }

    private struct PendingScrollbarPreview: Equatable {
        let token: ContentToken
        let ordinal: Int
        let fractionalOrdinal: CGFloat
    }

    var uiProbeScope: String? {
        didSet {
            documentView.uiProbeScope = uiProbeScope
        }
    }
    var onCommitKeyboardNavigation: (PlaybackSubtitleFocusKeyboardNavigationRequest) -> Bool = {
        _ in false
    }
    var onCommitNativeReelSelection: (Int) -> Bool = { _ in false }
    var onToggleCollageCueSelection: (Int) -> Void = { _ in }
    var onCopySelectedText: (String) -> Void = { _ in }
    var onSearchSelectedText: (String) -> Void = { _ in }
    var onCommitVirtualReelSelection: ((PlaybackVirtualReelSelectionCommit) -> Bool)?
    var allowsNativeWheelInput: () -> Bool = { false }
    var allowsNativeScrollbarInput: () -> Bool = { false }
    var onScrollbarDraggingChanged: (Bool) -> Void = { _ in }
    var onNativeMotionGateChanged: (Bool) -> Void = { _ in }
    var onKeyboardMotionChanged: (Bool) -> Void = { _ in }
    /// The registry whose gate handles the selected-text menu's events, and
    /// which layer this reel's menu belongs to: the Playback Overlay for the
    /// overlay's reels, the Command Panel for the panel's.
    var interfaceLayers: InterfaceLayerRegistry?
    var menuOwner: InterfaceLayer = .playbackOverlay
    /// True while a higher surface covers this reel. Its menu keeps its place
    /// on screen and stops answering keys and presses: those belong to whatever
    /// is on top. Hit testing already stops at the covering surface, but an
    /// `NSEvent` monitor never sees hit testing, so the reel is told directly.
    var isCoveredByHigherLayer = false

    private let scrollView = PlaybackSubtitleFocusNativeScrollView()
    private let documentView = PlaybackSubtitleFocusReelDocumentView()
    private let scrollbarView = PlaybackSubtitleFocusNativeScrollbarView()
    private let currentCueAdapter = PlaybackSubtitleFocusCueReelAdapter()
    private var selectedTextMenuHost: MenuHostingView?
    /// What the selected-text menu settled on when it opened: the cue it hangs
    /// off, where inside that cue, how big it is, and the offset that carries it
    /// along. Nothing here is recomputed while the menu is open.
    private struct SelectedTextMenuPlacement {
        let ordinal: Int
        let pointInCue: CGPoint
        let menuSize: CGSize
        let offset: CGSize
    }

    private var selectedTextMenuPlacement: SelectedTextMenuPlacement?
    private var menuGateSession: MenuGate.Session?
    private let selectedTextMenuHighlight = MenuHighlightModel()
    private var selectedTextMenuActions: [() -> Void] = []
    private var mountedContentAdapter:
        (any PlaybackVirtualReelContentAdapter)?
    private var contentSnapshot: PlaybackVirtualReelSnapshot?
    private var totalCount = 0
    private var selectedOrdinal: Int?
    private var fractionalOrdinal: CGFloat = 0
    private var hasInitializedPosition = false
    private var loadedOrdinalRange: Range<Int> = 0..<0
    private var isInteractionEnabled = true
    private var reducesMotion = false
    private var hasCompleteItemCollection = false
    private var lastViewportSize: CGSize = .zero
    private var lastHandledKeyboardSequence = 0
    private var lastHandledGeneratedKeyboardToken: ContentToken?
    private var lastHandledGeneratedKeyboardSequence = 0
    private var activeKeyboardRequest: PlaybackSubtitleFocusKeyboardNavigationRequest?
    private var activeKeyboardContentGeneration: UInt64?
    private var isKeyboardMotionActive = false
    private var activeWheelTargetOrdinal: Int?
    private var activeWheelContentGeneration: UInt64?
    private var pendingWindowSelection: PendingWindowSelection?
    private var pendingScrollbarPreview: PendingScrollbarPreview?
    private var lastWindowRequest: PlaybackVirtualReelWindowRequest?
    private var observedExternalSelectionToken: ContentToken?
    private var observedExternalSelectedOrdinal: Int?
    private var preciseGestureStartOrdinal: Int?
    private var wheelState = PlaybackSubtitleFocusNativeWheelState()
    private var preciseSettleTask: Task<Void, Never>?
    nonisolated(unsafe) private var eventMonitor: Any?
    private var isWheelMotionActive = false
    private var isScrollbarDragging = false
    private var isScrollbarMotionActive = false
    private var reportedNativeMotionActive = false
    private var motionCallbackGeneration = 0
    private var motionCallbackTask: Task<Void, Never>?
    private lazy var keyboardAnimator = PlaybackSubtitleFocusReelPositionAnimator(
        onUpdate: { [weak self] position in
            self?.setFractionalOrdinal(position)
        },
        onCompletion: { [weak self] in
            self?.completeKeyboardMotion()
        }
    )
    private lazy var wheelAnimator = PlaybackSubtitleFocusReelPositionAnimator(
        onUpdate: { [weak self] position in
            self?.setFractionalOrdinal(position)
        },
        onCompletion: { [weak self] in
            self?.completeWheelMotion()
        }
    )

    override var isFlipped: Bool {
        true
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        scrollView.drawsBackground = false
        scrollView.hasHorizontalScroller = false
        scrollView.hasVerticalScroller = false
        scrollView.horizontalScrollElasticity = .none
        scrollView.verticalScrollElasticity = .none
        scrollView.autohidesScrollers = true
        scrollView.documentView = documentView
        addSubview(scrollView)

        documentView.onToggleCollageCueSelection = { [weak self] ordinal in
            self?.onToggleCollageCueSelection(ordinal)
        }
        documentView.onPresentSelectedTextActions = { [weak self] text, ordinal, pointInCue in
            self?.presentSelectedTextActions(
                text: text,
                ordinal: ordinal,
                pointInCue: pointInCue
            )
        }
        documentView.onDismissSelectedTextActions = { [weak self] in
            self?.dismissSelectedTextActions()
        }

        scrollbarView.appearanceMode = .inherited
        scrollbarView.presentationProvider = { [weak self] in
            self?.scrollbarMetrics.presentation
        }
        scrollbarView.allowsInteraction = { [weak self] in
            self?.allowsNativeScrollbarInput() == true
        }
        scrollbarView.onDrag = { [weak self] event in
            self?.handleScrollbarDrag(event)
        }
        scrollbarView.onDragStateChanged = { [weak self] isDragging in
            self?.handleScrollbarDraggingChanged(isDragging)
        }
        addSubview(scrollbarView)

    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func layout() {
        super.layout()
        let nextViewportSize = bounds.size
        if isScrollbarDragging,
           lastViewportSize != .zero,
           nextViewportSize != lastViewportSize {
            cancelActiveScrollbarDrag()
        }
        if lastViewportSize != .zero,
           nextViewportSize != lastViewportSize,
           !hasActiveNativeMotion,
           let selectedOrdinal {
            fractionalOrdinal = CGFloat(selectedOrdinal)
        }
        if lastViewportSize != .zero,
           nextViewportSize != lastViewportSize {
            UIInvalidationProbe.mark(
                "ACTION playback.subtitle_focus.reflow",
                scope: uiProbeScope,
                details: "width=\(nextViewportSize.width) height=\(nextViewportSize.height)"
            )
        }
        lastViewportSize = nextViewportSize
        scrollView.frame = bounds
        scrollbarView.frame = bounds
        updateDocumentGeometry()
        if !hasActiveNativeMotion {
            synchronizeFractionalOrdinalIfIdle()
        }
        updateScrollbarPresentation()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil {
            removeEventMonitor()
            NotificationCenter.default.removeObserver(
                self,
                name: .cueSeekerClearTextSelection,
                object: nil
            )
            dismissSelectedTextActions()
            resetWheelInteraction(requiresNewGesture: true)
        } else {
            installEventMonitorIfNeeded()
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(appClearTextSelection),
                name: .cueSeekerClearTextSelection,
                object: nil
            )
        }
    }

    /// A menu opening anywhere in the App takes every selection with it, so the
    /// reel drops its own — and the menu hanging off it — when one does.
    @objc private func appClearTextSelection(_ notification: Notification) {
        dismissSelectedTextActions()
    }

    func update(
        cues: [SubtitleFocusCue],
        totalCount: Int,
        selectedOrdinal: Int,
        displayTitle: String = "",
        contentGeneration: UInt64 = 0,
        keyboardNavigationRequest: PlaybackSubtitleFocusKeyboardNavigationRequest?,
        reducesMotion: Bool,
        isInteractionEnabled: Bool,
        cancelsWheelMotion: Bool,
        collageSelectedCueIDs: Set<Int64>? = nil,
        collageCanSelectAnotherCue: Bool = true
    ) {
        currentCueAdapter.update(
            cues: cues,
            totalCount: totalCount,
            displayTitle: displayTitle,
            generation: contentGeneration
        )
        update(
            contentAdapter: currentCueAdapter,
            selectedOrdinal: selectedOrdinal,
            keyboardNavigationRequest: keyboardNavigationRequest,
            reducesMotion: reducesMotion,
            isInteractionEnabled: isInteractionEnabled,
            cancelsWheelMotion: cancelsWheelMotion,
            collageSelectedCueIDs: collageSelectedCueIDs,
            collageCanSelectAnotherCue: collageCanSelectAnotherCue
        )
    }

    func update(
        contentAdapter: any PlaybackVirtualReelContentAdapter,
        selectedOrdinal: Int?,
        keyboardNavigationRequest: PlaybackSubtitleFocusKeyboardNavigationRequest?,
        reducesMotion: Bool,
        isInteractionEnabled: Bool,
        cancelsWheelMotion: Bool,
        collageSelectedCueIDs: Set<Int64>? = nil,
        collageCanSelectAnotherCue: Bool = true
    ) {
        let snapshot = contentAdapter.snapshot
        if let contentSnapshot,
           contentSnapshot.datasetID == snapshot.datasetID,
           (snapshot.generation < contentSnapshot.generation
               || (snapshot.generation == contentSnapshot.generation
                   && (
                       snapshot.revision < contentSnapshot.revision
                           || (snapshot.revision == contentSnapshot.revision
                               && snapshot != contentSnapshot)
                           || snapshot.totalCount != contentSnapshot.totalCount
                   ))) {
            rejectIncomingContentAdapter(contentAdapter)
            return
        }
        guard snapshot.isValid else {
            rejectIncomingContentAdapter(contentAdapter)
            return
        }
        let previousSnapshot = contentSnapshot
        let previousContentAdapter = mountedContentAdapter
        let changesDataset = previousSnapshot.map {
            !$0.belongsToSameDataset(as: snapshot)
        } ?? false
        let replacesRequestTransport = previousContentAdapter.map {
            $0 !== contentAdapter
        } ?? false
        let activeTargetOrdinal = activeKeyboardRequest?.targetOrdinal
            ?? activeWheelTargetOrdinal
            ?? preciseGestureStartOrdinal
        let removesActiveTarget = activeTargetOrdinal.map {
            !snapshot.loadedOrdinalRange.contains($0)
        } ?? false
        if changesDataset || removesActiveTarget {
            cancelMotionForContentReplacement()
        }
        if changesDataset {
            contentAdapter.invalidateMeasurements()
            hasInitializedPosition = false
        }
        if previousSnapshot != snapshot || replacesRequestTransport {
            lastWindowRequest = nil
        }
        contentSnapshot = snapshot
        mountedContentAdapter = contentAdapter
        self.totalCount = snapshot.totalCount
        let token = ContentToken(
            datasetID: snapshot.datasetID,
            generation: snapshot.generation
        )
        if let pendingWindowSelection,
           pendingWindowSelection.token != token {
            self.pendingWindowSelection = nil
        }
        if let pendingScrollbarPreview,
           pendingScrollbarPreview.token != token {
            self.pendingScrollbarPreview = nil
        }
        if observeExternalSelection(selectedOrdinal, for: token) {
            supersedePendingWindowIntent()
        }
        if case .restore(_, let ordinal) = pendingWindowSelection,
           resolvedOrdinal(selectedOrdinal, totalCount: snapshot.totalCount)
               != ordinal {
            supersedePendingWindowIntent(clearsScrollbarPreview: false)
        }
        if let pendingWindowSelection,
           !(0..<snapshot.totalCount).contains(pendingWindowSelection.ordinal) {
            supersedePendingWindowIntent(clearsScrollbarPreview: false)
        }
        if let pendingScrollbarPreview,
           (!isScrollbarDragging
               || !(0..<snapshot.totalCount).contains(
                   pendingScrollbarPreview.ordinal
               )) {
            self.pendingScrollbarPreview = nil
        }
        let readyPendingWindowSelection = pendingWindowSelection.flatMap {
            snapshot.loadedOrdinalRange.contains($0.ordinal) ? $0 : nil
        }
        let readyScrollbarPreview = pendingScrollbarPreview.flatMap {
            snapshot.loadedOrdinalRange.contains($0.ordinal) ? $0 : nil
        }
        let previousSelectedOrdinal = self.selectedOrdinal
        let requestedSelectedOrdinal = readyPendingWindowSelection?.ordinal
            ?? selectedOrdinal
        var unloadedRequestedOrdinal: Int?
        if let requestedSelectedOrdinal, snapshot.totalCount > 0 {
            let resolvedSelectedOrdinal = min(
                max(0, requestedSelectedOrdinal),
                snapshot.totalCount - 1
            )
            if snapshot.loadedOrdinalRange.contains(resolvedSelectedOrdinal) {
                self.selectedOrdinal = resolvedSelectedOrdinal
            } else {
                self.selectedOrdinal = nil
                if pendingWindowSelection == nil
                    && pendingScrollbarPreview == nil {
                    unloadedRequestedOrdinal = resolvedSelectedOrdinal
                }
            }
        } else {
            self.selectedOrdinal = nil
        }
        loadedOrdinalRange = snapshot.loadedOrdinalRange
        hasCompleteItemCollection = snapshot.isComplete
        self.reducesMotion = reducesMotion
        let wasInteractionEnabled = self.isInteractionEnabled
        self.isInteractionEnabled = isInteractionEnabled
        if cancelsWheelMotion {
            cancelActiveScrollbarDrag()
            resetWheelInteraction(requiresNewGesture: true)
        } else if wasInteractionEnabled, !isInteractionEnabled {
            suspendWheelInputForSuppression()
        }
        let activeScrollbarPreview = readyScrollbarPreview.flatMap { preview in
            pendingScrollbarPreview == preview && isScrollbarDragging
                ? preview
                : nil
        }
        documentView.updateContent(contentAdapter)
        documentView.updateCollageSelection(
            selectedCueIDs: collageSelectedCueIDs,
            canSelectAnotherCue: collageCanSelectAnotherCue
        )
        if let activeScrollbarPreview {
            fractionalOrdinal = activeScrollbarPreview.fractionalOrdinal
            hasInitializedPosition = true
        } else if !hasInitializedPosition,
                  let selectedOrdinal = self.selectedOrdinal {
            fractionalOrdinal = CGFloat(selectedOrdinal)
            hasInitializedPosition = true
        } else if previousSelectedOrdinal != self.selectedOrdinal,
                  !hasActiveNativeMotion,
                  let selectedOrdinal = self.selectedOrdinal {
            fractionalOrdinal = CGFloat(selectedOrdinal)
        }
        fractionalOrdinal = boundedLoadedFractionalOrdinal(fractionalOrdinal)
        updateDocumentGeometry()
        updateScrollbarPresentation()
        if let activeScrollbarPreview {
            documentView.updateSelection(activeScrollbarPreview.ordinal)
        } else if !hasActiveNativeMotion {
            documentView.updateSelection(self.selectedOrdinal)
            synchronizeFractionalOrdinalIfIdle()
        }
        if let unloadedRequestedOrdinal {
            _ = requestWindow(
                targetOrdinal: unloadedRequestedOrdinal,
                reason: .visible,
                pendingSelection: .restore(
                    token: token,
                    ordinal: unloadedRequestedOrdinal
                )
            )
        }
        handleKeyboardNavigation(
            keyboardNavigationRequest,
            reducesMotion: reducesMotion
        )
        if let readyPendingWindowSelection,
           pendingWindowSelection == readyPendingWindowSelection {
            pendingWindowSelection = nil
            finishPendingWindowSelection(
                readyPendingWindowSelection,
                fallbackSelectedOrdinal: selectedOrdinal
            )
        }
        if let pendingWindowSelection {
            _ = requestWindow(
                targetOrdinal: pendingWindowSelection.ordinal,
                reason: pendingWindowSelection.requestReason,
                pendingSelection: pendingWindowSelection
            )
        }
        if let pendingScrollbarPreview,
           readyScrollbarPreview == nil {
            _ = requestWindow(
                targetOrdinal: pendingScrollbarPreview.ordinal,
                reason: .scrollbar,
                pendingSelection: nil
            )
        }
        requestVisibleWindowIfNeeded()
    }

    private func rejectIncomingContentAdapter(
        _ contentAdapter: any PlaybackVirtualReelContentAdapter
    ) {
        if let mountedContentAdapter,
           mountedContentAdapter === contentAdapter {
            resetForInvalidContent(contentAdapter)
        } else {
            contentAdapter.invalidate()
        }
    }

    private func observeExternalSelection(
        _ ordinal: Int?,
        for token: ContentToken
    ) -> Bool {
        guard observedExternalSelectionToken == token else {
            observedExternalSelectionToken = token
            observedExternalSelectedOrdinal = ordinal
            return false
        }
        let didChange = observedExternalSelectedOrdinal != ordinal
        observedExternalSelectedOrdinal = ordinal
        return didChange
    }

    private func resolvedOrdinal(
        _ ordinal: Int?,
        totalCount: Int
    ) -> Int? {
        guard let ordinal, totalCount > 0 else {
            return nil
        }
        return min(max(0, ordinal), totalCount - 1)
    }

    private func supersedePendingWindowIntent(
        clearsScrollbarPreview: Bool = true
    ) {
        finishPendingWindowMotion(pendingWindowSelection)
        pendingWindowSelection = nil
        if clearsScrollbarPreview {
            pendingScrollbarPreview = nil
        }
        lastWindowRequest = nil
    }

    private func resetForInvalidContent(
        _ contentAdapter: any PlaybackVirtualReelContentAdapter
    ) {
        cancelMotionForContentReplacement()
        if let mountedContentAdapter,
           mountedContentAdapter !== contentAdapter {
            contentAdapter.invalidate()
        }
        contentSnapshot = nil
        mountedContentAdapter = nil
        totalCount = 0
        selectedOrdinal = nil
        fractionalOrdinal = 0
        loadedOrdinalRange = 0..<0
        hasCompleteItemCollection = false
        hasInitializedPosition = false
        observedExternalSelectionToken = nil
        observedExternalSelectedOrdinal = nil
        documentView.invalidate()
        updateDocumentGeometry()
        updateScrollbarPresentation()
    }

    private func cancelMotionForContentReplacement() {
        keyboardAnimator.cancel()
        wheelAnimator.cancel()
        preciseSettleTask?.cancel()
        preciseSettleTask = nil
        wheelState.reset(requiresNewGesture: true)
        activeKeyboardRequest = nil
        activeKeyboardContentGeneration = nil
        activeWheelTargetOrdinal = nil
        activeWheelContentGeneration = nil
        preciseGestureStartOrdinal = nil
        pendingWindowSelection = nil
        pendingScrollbarPreview = nil
        lastWindowRequest = nil
        if isScrollbarDragging {
            isScrollbarDragging = false
            onScrollbarDraggingChanged(false)
        }
        isKeyboardMotionActive = false
        isWheelMotionActive = false
        isScrollbarMotionActive = false
        motionCallbackGeneration += 1
        motionCallbackTask?.cancel()
        motionCallbackTask = nil
        if reportedNativeMotionActive {
            reportedNativeMotionActive = false
            onNativeMotionGateChanged(false)
            onKeyboardMotionChanged(false)
        }
    }

    func invalidate() {
        if reportedNativeMotionActive {
            onNativeMotionGateChanged(false)
        }
        motionCallbackGeneration += 1
        motionCallbackTask?.cancel()
        motionCallbackTask = nil
        onCommitKeyboardNavigation = { _ in false }
        onCommitNativeReelSelection = { _ in false }
        onToggleCollageCueSelection = { _ in }
        onCopySelectedText = { _ in }
        onSearchSelectedText = { _ in }
        onCommitVirtualReelSelection = nil
        allowsNativeWheelInput = { false }
        allowsNativeScrollbarInput = { false }
        if isScrollbarDragging {
            onScrollbarDraggingChanged(false)
        }
        onScrollbarDraggingChanged = { _ in }
        onNativeMotionGateChanged = { _ in }
        onKeyboardMotionChanged = { _ in }
        keyboardAnimator.cancel()
        wheelAnimator.cancel()
        preciseSettleTask?.cancel()
        preciseSettleTask = nil
        dismissSelectedTextActions()
        removeEventMonitor()
        wheelState.reset()
        activeKeyboardRequest = nil
        activeKeyboardContentGeneration = nil
        activeWheelTargetOrdinal = nil
        activeWheelContentGeneration = nil
        preciseGestureStartOrdinal = nil
        pendingWindowSelection = nil
        pendingScrollbarPreview = nil
        lastWindowRequest = nil
        observedExternalSelectionToken = nil
        observedExternalSelectedOrdinal = nil
        scrollbarView.onDrag = { _ in }
        scrollbarView.onDragStateChanged = nil
        scrollbarView.presentationProvider = { nil }
        scrollbarView.allowsInteraction = { false }
        scrollbarView.isPresented = false
        isScrollbarDragging = false
        isKeyboardMotionActive = false
        isWheelMotionActive = false
        isScrollbarMotionActive = false
        lastViewportSize = .zero
        reportedNativeMotionActive = false
        contentSnapshot = nil
        mountedContentAdapter = nil
        selectedOrdinal = nil
        fractionalOrdinal = 0
        loadedOrdinalRange = 0..<0
        totalCount = 0
        hasCompleteItemCollection = false
        hasInitializedPosition = false
        lastHandledKeyboardSequence = 0
        lastHandledGeneratedKeyboardToken = nil
        lastHandledGeneratedKeyboardSequence = 0
        isInteractionEnabled = false
        documentView.invalidate()
        scrollView.documentView = nil
    }

    private func presentSelectedTextActions(
        text: String,
        ordinal: Int,
        pointInCue: CGPoint
    ) {
        tearDownSelectedTextMenu()
        // The Scrollbar is outside the menu, so it stops answering the pointer
        // for as long as the menu is up.
        scrollbarView.isInteractionFrozen = true

        selectedTextMenuActions = [
            { [weak self] in
                self?.dismissSelectedTextActions()
                self?.onCopySelectedText(text)
            },
            { [weak self] in
                self?.dismissSelectedTextActions()
                self?.onSearchSelectedText(text)
            },
        ]
        selectedTextMenuHighlight.open(
            selectablePositions: Array(selectedTextMenuActions.indices)
        )

        let menu = PlaybackSelectedTextMenu(
            highlight: selectedTextMenuHighlight,
            items: [
                PlaybackSelectedTextMenu.Item(
                    title: L("playback.copy_selected_text"),
                    systemImage: "doc.on.doc"
                ),
                PlaybackSelectedTextMenu.Item(
                    title: L("playback.search_selected_text"),
                    systemImage: "magnifyingglass"
                ),
            ],
            onActivate: { [weak self] position in
                self?.activateSelectedTextAction(at: position)
            }
        )
        let host = MenuHostingView(rootView: AnyView(menu))
        host.translatesAutoresizingMaskIntoConstraints = true
        selectedTextMenuHost = host
        addSubview(host)
        host.layoutSubtreeIfNeeded()

        // Measured, placed once, and the offset kept — the same order every
        // other menu in the App follows. Afterwards the menu only translates.
        let menuSize = host.fittingSize
        let anchor = selectedTextAnchor(ordinal: ordinal, pointInCue: pointInCue)
            ?? .zero
        let openingFrame = selectedTextMenuFrame(anchor: anchor, size: menuSize)
        selectedTextMenuPlacement = SelectedTextMenuPlacement(
            ordinal: ordinal,
            pointInCue: pointInCue,
            menuSize: menuSize,
            offset: MenuPlacement.offset(
                from: CGRect(origin: anchor, size: .zero),
                to: openingFrame
            )
        )
        host.frame = openingFrame
        openMenuGateSession()
    }

    /// Where the menu hangs off, in this view's coordinates, as the reel lays
    /// its cues out now.
    private func selectedTextAnchor(
        ordinal: Int,
        pointInCue: CGPoint
    ) -> CGPoint? {
        guard let cueOrigin = documentView.cueContentOrigin(at: ordinal) else {
            return nil
        }
        return convert(
            CGPoint(
                x: cueOrigin.x + pointInCue.x,
                y: cueOrigin.y + pointInCue.y
            ),
            from: documentView
        )
    }

    /// Pure translation, run whenever the reel moves. The side was chosen when
    /// the menu opened and is never revisited. A cue carried outside the
    /// laid-out window leaves the menu where it last was, on its way out.
    private func repositionSelectedTextMenu() {
        guard let host = selectedTextMenuHost,
              let placement = selectedTextMenuPlacement,
              let anchor = selectedTextAnchor(
                  ordinal: placement.ordinal,
                  pointInCue: placement.pointInCue
              )
        else {
            return
        }
        host.frame = MenuPlacement.followingFrame(
            anchor: CGRect(origin: anchor, size: .zero),
            offset: placement.offset,
            menuSize: placement.menuSize
        )
    }

    func selectedTextMenuFrame(
        anchor: CGPoint,
        size: CGSize
    ) -> CGRect {
        MenuPlacement.openingFrame(
            anchor: CGRect(origin: anchor, size: .zero),
            menuSize: size,
            in: bounds,
            gap: WorkbenchControlMetrics.redesignSpacing1
        )
    }

    /// Closes the menu and takes the selection it hangs off with it. Clearing
    /// here does not report back, because a report is what asks for this in the
    /// first place.
    private func dismissSelectedTextActions() {
        tearDownSelectedTextMenu()
        documentView.discardTextSelection()
    }

    /// Removes the menu and leaves the selection alone, for the open path,
    /// which tears down any previous menu before putting up the one belonging
    /// to the selection just made.
    private func tearDownSelectedTextMenu() {
        selectedTextMenuHost?.removeFromSuperview()
        selectedTextMenuHost = nil
        selectedTextMenuPlacement = nil
        selectedTextMenuHighlight.close()
        selectedTextMenuActions = []
        menuGateSession?.close()
        menuGateSession = nil
        scrollbarView.isInteractionFrozen = false
    }

    /// Arrow keys, Enter and Escape for the open menu. Reported as handled so
    /// the playback page does not also navigate cues or seek.
    private func handleSelectedTextMenuKey(_ keyCode: UInt16) -> Bool {
        guard selectedTextMenuHost != nil else {
            return false
        }
        // Every arrow and Enter belongs to the open menu; the reel and the
        // page under it must not respond to any of them.
        switch keyCode {
        case 53:
            dismissSelectedTextActions()
            return true
        case 126:
            _ = selectedTextMenuHighlight.moveHighlight(by: -1)
            return true
        case 125:
            _ = selectedTextMenuHighlight.moveHighlight(by: 1)
            return true
        case 123, 124:
            return true
        case 36, 76:
            _ = activateHighlightedSelectedTextAction()
            return true
        default:
            return false
        }
    }

    private func activateSelectedTextAction(at position: Int) {
        guard selectedTextMenuActions.indices.contains(position) else {
            return
        }
        selectedTextMenuActions[position]()
    }

    /// Enter runs whatever the highlight currently sits on, so the keyboard and
    /// the pointer commit through one path.
    private func activateHighlightedSelectedTextAction() -> Bool {
        guard let position = selectedTextMenuHighlight.highlightedPosition
        else {
            return false
        }
        activateSelectedTextAction(at: position)
        return true
    }

    /// Hands the open selected-text menu to the menu gate, which owns the
    /// outside press, the whole-window scroll ban, and the menu's keys. The
    /// overlay's menu also receives its keys through the gate's route: the
    /// playback key owner sees keys first and offers them to the gate.
    private func openMenuGateSession() {
        guard menuGateSession == nil else {
            return
        }
        menuGateSession = interfaceLayers?.menuGate.open(
            MenuGate.Client(
                owner: menuOwner,
                kind: .selectedTextMenu,
                window: { [weak self] in self?.window },
                isPointerOnMenu: { [weak self] event in
                    guard let host = self?.selectedTextMenuHost else {
                        return false
                    }
                    return host.bounds.contains(
                        host.convert(event.locationInWindow, from: nil)
                    )
                },
                handleKey: { [weak self] keyCode, _ in
                    self?.handleSelectedTextMenuKey(keyCode) ?? false
                },
                dismiss: { [weak self] _ in
                    // The press that closes the menu is spent on closing it.
                    // It does not also land on the subtitle text underneath.
                    self?.dismissSelectedTextActions()
                }
            )
        )
    }

    var fractionalOrdinalForTesting: CGFloat {
        fractionalOrdinal
    }

    var selectedTextMenuFrameForTesting: CGRect? {
        selectedTextMenuHost?.frame
    }

    var documentViewForTesting: PlaybackSubtitleFocusReelDocumentView {
        documentView
    }

    var selectedOrdinalForTesting: Int {
        selectedOrdinal ?? 0
    }

    var optionalSelectedOrdinalForTesting: Int? {
        selectedOrdinal
    }

    var displayedSelectedOrdinalForTesting: Int? {
        documentView.selectedOrdinalForTesting
    }

    func toggleCollageCueForTesting(at ordinal: Int) -> Bool {
        documentView.toggleCollageCueForTesting(at: ordinal)
    }

    func toggleCollageCueForTesting(at point: CGPoint) -> Bool {
        documentView.toggleCollageCueForTesting(at: point)
    }

    func collageCheckboxRectForTesting(at ordinal: Int) -> CGRect? {
        documentView.collageCheckboxRectForTesting(at: ordinal)
    }

    func cueContentRectForTesting(at ordinal: Int) -> CGRect? {
        documentView.cueContentRectForTesting(at: ordinal)
    }

    var cueTimelineConnectorRectsForTesting: [CGRect] {
        documentView.cueTimelineConnectorRectsForTesting
    }

    func isCueHighlightedForTesting(at ordinal: Int) -> Bool {
        documentView.isCueHighlightedForTesting(at: ordinal)
    }

    func isCollageCueEnabledForTesting(at ordinal: Int) -> Bool {
        documentView.isCollageCueEnabledForTesting(at: ordinal)
    }

    var placementsForTesting: [PlaybackSubtitleFocusCuePlacement] {
        documentView.placements
    }

    var measuredOrdinalsForTesting: Set<Int> {
        documentView.measuredOrdinals
    }

    var measurementCacheCountForTesting: Int {
        documentView.measurementCacheCount
    }

    var scrollbarPresentationForTesting: TableScrollbarPresentation {
        scrollbarMetrics.presentation
    }

    var acceptsScrollbarInteractionForTesting: Bool {
        scrollbarView.acceptsInteraction && allowsNativeScrollbarInput()
    }

    func applyPreciseWheelDeltaForTesting(_ deltaY: CGFloat) {
        handlePreciseWheel(
            deltaY: deltaY,
            beginsGesture: preciseGestureStartOrdinal == nil
        )
    }

    func applyDiscreteWheelForTesting(
        direction: SubtitleFocusNavigationDirection,
        stepCount: Int = 1
    ) {
        handleDiscreteWheel(direction: direction, stepCount: stepCount)
    }

    func settlePreciseWheelForTesting() {
        settlePreciseWheel()
    }

    private func updateDocumentGeometry() {
        let layout = PlaybackSubtitleFocusVirtualReelLayout(
            viewportSize: scrollView.contentSize,
            totalCount: totalCount,
            loadedOrdinalRange: loadedOrdinalRange,
            fractionalOrdinal: fractionalOrdinal
        )
        documentView.updateLocalLayout(layout)
        if documentView.frame.size != layout.viewportSize {
            documentView.frame = CGRect(origin: .zero, size: layout.viewportSize)
        }
        if scrollView.contentView.bounds.origin != .zero {
            scrollView.contentView.scroll(to: .zero)
        }
        repositionSelectedTextMenu()
    }

    private func synchronizeFractionalOrdinalIfIdle() {
        guard !keyboardAnimator.isRunning,
              !wheelAnimator.isRunning,
              preciseGestureStartOrdinal == nil,
              let selectedOrdinal
        else {
            return
        }
        setFractionalOrdinal(CGFloat(selectedOrdinal))
    }

    private var currentLayout: PlaybackSubtitleFocusVirtualReelLayout {
        PlaybackSubtitleFocusVirtualReelLayout(
            viewportSize: scrollView.contentSize,
            totalCount: totalCount,
            loadedOrdinalRange: loadedOrdinalRange,
            fractionalOrdinal: fractionalOrdinal
        )
    }

    private var scrollbarMetrics: PlaybackSubtitleFocusNativeScrollbarMetrics {
        PlaybackSubtitleFocusNativeScrollbarMetrics(
            totalCount: totalCount,
            fractionalOrdinal: fractionalOrdinal,
            visibleCueCapacity: documentView.visibleCueCenterCapacity
        )
    }

    private func updateScrollbarPresentation() {
        scrollbarView.isPresented = scrollbarMetrics.presentation.vertical != nil
        updateScrollbarInteractionAvailability()
        scrollbarView.scrollbarMetricsDidChange()
    }

    private func updateScrollbarInteractionAvailability() {
        scrollbarView.acceptsInteraction = isInteractionEnabled
            && (hasCompleteItemCollection
                || mountedContentAdapter?.supportsWindowRequests == true)
            && selectedOrdinal != nil
            && !isKeyboardMotionActive
            && !isWheelMotionActive
    }

    private func cancelActiveScrollbarDrag() {
        guard isScrollbarDragging else {
            return
        }
        let restoresPresentation = scrollbarMetrics.presentation.vertical != nil
        scrollbarView.isPresented = false
        if isScrollbarDragging {
            handleScrollbarDrag(TableScrollbarDragEvent(
                axis: .vertical,
                phase: .cancelled,
                positionFraction: scrollbarMetrics.presentation.vertical?
                    .positionFraction ?? 0
            ))
            handleScrollbarDraggingChanged(false)
        }
        scrollbarView.isPresented = restoresPresentation
    }

    private func setFractionalOrdinal(
        _ position: CGFloat,
        refreshesScrollbar: Bool = true
    ) {
        let boundedPosition = boundedLoadedFractionalOrdinal(position)
        guard abs(fractionalOrdinal - boundedPosition) > 0.000_001 else {
            if refreshesScrollbar {
                scrollbarView.scrollbarMetricsDidChange()
            }
            return
        }
        fractionalOrdinal = boundedPosition
        updateDocumentGeometry()
        if refreshesScrollbar {
            scrollbarView.scrollbarMetricsDidChange()
        }
    }

    private func handleKeyboardNavigation(
        _ request: PlaybackSubtitleFocusKeyboardNavigationRequest?,
        reducesMotion: Bool
    ) {
        guard let request else {
            return
        }
        if let requestGeneration = request.contentGeneration {
            guard let contentSnapshot,
                  let contentDatasetID = request.contentDatasetID,
                  AnyHashable(contentDatasetID) == contentSnapshot.datasetID,
                  requestGeneration == contentSnapshot.generation
            else {
                return
            }
            let token = ContentToken(
                datasetID: contentSnapshot.datasetID,
                generation: requestGeneration
            )
            if lastHandledGeneratedKeyboardToken != token {
                lastHandledGeneratedKeyboardToken = token
                lastHandledGeneratedKeyboardSequence = 0
            }
            guard request.sequence > lastHandledGeneratedKeyboardSequence else {
                return
            }
            lastHandledGeneratedKeyboardSequence = request.sequence
        } else {
            guard request.sequence > lastHandledKeyboardSequence else {
                return
            }
            lastHandledKeyboardSequence = request.sequence
        }
        guard request.targetOrdinal >= 0,
              request.targetOrdinal < totalCount
        else {
            return
        }
        supersedePendingWindowIntent()
        guard loadedOrdinalRange.contains(request.targetOrdinal) else {
            guard let token = currentContentToken else {
                return
            }
            guard requestWindow(
                targetOrdinal: request.targetOrdinal,
                reason: .keyboard,
                pendingSelection: .keyboard(token: token, request: request)
            ) else {
                return
            }
            setKeyboardMotionActive(true)
            return
        }
        UIInvalidationProbe.mark(
            "ACTION playback.subtitle_focus.keyboard_navigation",
            scope: uiProbeScope,
            details: "target=\(request.targetOrdinal)"
        )
        activeKeyboardRequest = request
        activeKeyboardContentGeneration = contentSnapshot?.generation
        documentView.updateSelection(request.targetOrdinal)
        setKeyboardMotionActive(true)
        keyboardAnimator.retarget(
            from: fractionalOrdinal,
            to: CGFloat(request.targetOrdinal),
            duration: PlaybackSubtitleFocusMetrics
                .resolvedReelTransitionDuration(reducesMotion: reducesMotion)
        )
    }

    private func completeKeyboardMotion() {
        guard let request = activeKeyboardRequest,
              activeKeyboardContentGeneration == contentSnapshot?.generation
        else {
            return
        }
        let didCommit: Bool
        if let onCommitVirtualReelSelection {
            didCommit = selectionCommit(for: request.targetOrdinal).map(
                onCommitVirtualReelSelection
            ) ?? false
        } else {
            didCommit = onCommitKeyboardNavigation(request)
        }
        guard didCommit else {
            activeKeyboardRequest = nil
            activeKeyboardContentGeneration = nil
            documentView.updateSelection(selectedOrdinal)
            setKeyboardMotionActive(false)
            synchronizeFractionalOrdinalIfIdle()
            return
        }
        activeKeyboardRequest = nil
        activeKeyboardContentGeneration = nil
        selectedOrdinal = request.targetOrdinal
        setKeyboardMotionActive(false)
    }

    func handleScrollbarDraggingChanged(_ isDragging: Bool) {
        guard isScrollbarDragging != isDragging else {
            return
        }
        if isDragging {
            guard scrollbarView.acceptsInteraction else {
                return
            }
            guard allowsNativeScrollbarInput() else {
                return
            }
            resetWheelInteraction(requiresNewGesture: true)
            supersedePendingWindowIntent()
            UIInvalidationProbe.mark(
                "ACTION playback.subtitle_focus.scrollbar_drag",
                scope: uiProbeScope,
                details: "phase=began"
            )
            isScrollbarDragging = true
            onScrollbarDraggingChanged(true)
            setScrollbarMotionActive(true)
        } else {
            isScrollbarDragging = false
            onScrollbarDraggingChanged(false)
            setScrollbarMotionActive(false)
            if pendingScrollbarPreview != nil {
                restoreObservedExternalSelection()
            }
            updateScrollbarInteractionAvailability()
            scrollbarView.scrollbarMetricsDidChange()
        }
    }

    func handleScrollbarDrag(_ event: TableScrollbarDragEvent) {
        guard event.axis == .vertical,
              (hasCompleteItemCollection
                  || mountedContentAdapter?.supportsWindowRequests == true),
              isScrollbarDragging
        else {
            return
        }

        switch event.phase {
        case .began:
            break
        case .changed:
            _ = applyScrollbarPositionFraction(
                event.positionFraction,
                refreshesScrollbar: false,
                requestsCommit: false
            )
        case .ended:
            if applyScrollbarPositionFraction(
                event.positionFraction,
                refreshesScrollbar: true,
                requestsCommit: true
            ) {
                settleScrollbarDrag()
            }
        case .cancelled:
            wheelAnimator.cancel()
            activeWheelTargetOrdinal = nil
            activeWheelContentGeneration = nil
            restoreObservedExternalSelection()
        }
    }

    private func applyScrollbarPositionFraction(
        _ positionFraction: CGFloat,
        refreshesScrollbar: Bool,
        requestsCommit: Bool
    ) -> Bool {
        let metrics = scrollbarMetrics
        let position = metrics.fractionalOrdinal(for: positionFraction)
        let targetOrdinal = min(
            max(0, Int(position.rounded())),
            max(0, totalCount - 1)
        )
        guard let token = currentContentToken else {
            return false
        }
        if requestsCommit {
            pendingScrollbarPreview = nil
            pendingWindowSelection = nil
        } else {
            pendingScrollbarPreview = PendingScrollbarPreview(
                token: token,
                ordinal: targetOrdinal,
                fractionalOrdinal: position
            )
        }
        guard loadedOrdinalRange.contains(targetOrdinal) else {
            let pendingSelection: PendingWindowSelection? = requestsCommit
                ? .native(
                    token: token,
                    ordinal: targetOrdinal,
                    reason: .scrollbar
                )
                : nil
            let didRequestWindow = requestWindow(
                targetOrdinal: targetOrdinal,
                reason: .scrollbar,
                pendingSelection: pendingSelection
            )
            if requestsCommit, didRequestWindow {
                setWheelMotionActive(true)
            }
            return false
        }
        setFractionalOrdinal(position, refreshesScrollbar: refreshesScrollbar)
        documentView.updateSelection(currentLayout.nearestOrdinal)
        return true
    }

    private func restoreObservedExternalSelection() {
        pendingScrollbarPreview = nil
        lastWindowRequest = nil
        guard let token = currentContentToken,
              observedExternalSelectionToken == token,
              let targetOrdinal = resolvedOrdinal(
                  observedExternalSelectedOrdinal,
                  totalCount: totalCount
              )
        else {
            selectedOrdinal = nil
            documentView.updateSelection(nil)
            updateScrollbarPresentation()
            return
        }
        if loadedOrdinalRange.contains(targetOrdinal) {
            selectedOrdinal = targetOrdinal
            fractionalOrdinal = CGFloat(targetOrdinal)
            hasInitializedPosition = true
            documentView.updateSelection(targetOrdinal)
            updateDocumentGeometry()
            updateScrollbarPresentation()
        } else {
            selectedOrdinal = nil
            documentView.updateSelection(nil)
            _ = requestWindow(
                targetOrdinal: targetOrdinal,
                reason: .visible,
                pendingSelection: .restore(
                    token: token,
                    ordinal: targetOrdinal
                )
            )
            updateScrollbarPresentation()
        }
    }

    private func settleScrollbarDrag() {
        let targetOrdinal = currentLayout.nearestOrdinal
        activeWheelTargetOrdinal = targetOrdinal
        activeWheelContentGeneration = contentSnapshot?.generation
        documentView.updateSelection(targetOrdinal)
        setWheelMotionActive(true)
        wheelAnimator.retarget(
            from: fractionalOrdinal,
            to: CGFloat(targetOrdinal),
            duration: PlaybackSubtitleFocusMetrics
                .resolvedReelTransitionDuration(reducesMotion: reducesMotion)
        )
    }

    private func installEventMonitorIfNeeded() {
        guard eventMonitor == nil else {
            return
        }
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) {
            [weak self] event in
            guard let self,
                  let window = self.window,
                  event.window === window
            else {
                return event
            }
            let point = self.convert(event.locationInWindow, from: nil)
            let isInside = self.bounds.contains(point)
            // An open menu hands the wheel to the menu gate, which bans
            // scrolling for the whole window and leaves the menu its own. The
            // reel must not spend the wheel first: this monitor was installed
            // before the gate's, so it sees the event first. Every menu the
            // gate holds counts, not only this reel's own: the footer's
            // `Save to Shiori` menu is opened by another surface, and a reel
            // that recognised only its own selected-text menu went on scrolling
            // under it. A menu the gate reports as covered bans nothing — the
            // surface above it decides.
            if self.interfaceLayers?.menuGate.bansScrolling == true {
                return event
            }
            guard self.allowsNativeWheelInput() else {
                if self.isWheelMotionActive {
                    self.suspendWheelInputForSuppression()
                    return nil
                }
                // A reel that is not taking wheel input must not swallow it
                // either. Its rectangle still covers whatever is stacked on
                // top, so swallowing here would starve the overlay above it;
                // passing the event on lets that surface's own monitor take it.
                return event
            }
            let sample = PlaybackSubtitleFocusScrollSample(
                deltaY: event.scrollingDeltaY,
                isPrecise: event.hasPreciseScrollingDeltas,
                phase: Self.scrollPhase(from: event.phase),
                momentumPhase: Self.scrollPhase(from: event.momentumPhase),
                isInside: isInside
            )
            let output = self.wheelState.consume(
                sample,
                isEnabled: self.isInteractionEnabled
            )
            guard output.shouldConsume else {
                return event
            }
            self.handleWheelOutput(output)
            return nil
        }
    }

    private func removeEventMonitor() {
        guard let eventMonitor else {
            return
        }
        NSEvent.removeMonitor(eventMonitor)
        self.eventMonitor = nil
    }

    private func handleWheelOutput(
        _ output: PlaybackSubtitleFocusNativeWheelOutput
    ) {
        switch output.mode {
        case .none:
            break
        case .discrete(let direction, let stepCount):
            handleDiscreteWheel(direction: direction, stepCount: stepCount)
        case .precise(let deltaY, let beginsGesture):
            handlePreciseWheel(deltaY: deltaY, beginsGesture: beginsGesture)
        }

        switch output.settleDirective {
        case .none:
            break
        case .cancel:
            cancelPreciseSettle()
        case .debounce:
            schedulePreciseSettle()
        case .immediate:
            settlePreciseWheel()
        }
    }

    private func handleDiscreteWheel(
        direction: SubtitleFocusNavigationDirection,
        stepCount: Int
    ) {
        cancelPreciseSettle()
        wheelState.finishPreciseGesture()
        guard let startOrdinal = activeWheelTargetOrdinal ?? selectedOrdinal else {
            return
        }
        let delta = direction == .backward ? -stepCount : stepCount
        let targetOrdinal = min(
            max(0, startOrdinal + delta),
            max(0, totalCount - 1)
        )
        guard targetOrdinal != startOrdinal else {
            return
        }
        supersedePendingWindowIntent()
        guard loadedOrdinalRange.contains(targetOrdinal) else {
            guard let token = currentContentToken else {
                return
            }
            guard requestWindow(
                targetOrdinal: targetOrdinal,
                reason: .wheel,
                pendingSelection: .native(
                    token: token,
                    ordinal: targetOrdinal,
                    reason: .wheel
                )
            ) else {
                return
            }
            setWheelMotionActive(true)
            return
        }
        UIInvalidationProbe.mark(
            "ACTION playback.subtitle_focus.wheel",
            scope: uiProbeScope,
            details: "mode=discrete target=\(targetOrdinal)"
        )

        preciseGestureStartOrdinal = nil
        activeWheelTargetOrdinal = targetOrdinal
        activeWheelContentGeneration = contentSnapshot?.generation
        documentView.updateSelection(targetOrdinal)
        setWheelMotionActive(true)
        wheelAnimator.retarget(
            from: fractionalOrdinal,
            to: CGFloat(targetOrdinal),
            duration: PlaybackSubtitleFocusMetrics
                .resolvedReelTransitionDuration(reducesMotion: reducesMotion)
        )
    }

    private func handlePreciseWheel(
        deltaY: CGFloat,
        beginsGesture: Bool
    ) {
        guard selectedOrdinal != nil,
              totalCount > 0,
              !loadedOrdinalRange.isEmpty
        else {
            return
        }
        if beginsGesture || preciseGestureStartOrdinal == nil {
            cancelPreciseSettle()
            wheelAnimator.cancel()
            activeWheelTargetOrdinal = nil
            activeWheelContentGeneration = nil
            supersedePendingWindowIntent()
            preciseGestureStartOrdinal = currentLayout.nearestOrdinal
            UIInvalidationProbe.mark(
                "ACTION playback.subtitle_focus.wheel",
                scope: uiProbeScope,
                details: "mode=precise"
            )
        }

        let position = documentView.fractionalOrdinal(
            afterMovingBy: -deltaY,
            from: fractionalOrdinal
        )
        setFractionalOrdinal(position)
        documentView.updateSelection(currentLayout.nearestOrdinal)
        setWheelMotionActive(true)
        requestAdjacentWindowIfNeeded(deltaY: deltaY)
    }

    private func schedulePreciseSettle() {
        preciseSettleTask?.cancel()
        let generation = contentSnapshot?.generation
        preciseSettleTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 80_000_000)
            guard let self,
                  !Task.isCancelled,
                  self.contentSnapshot?.generation == generation
            else {
                return
            }
            self.preciseSettleTask = nil
            self.settlePreciseWheel()
        }
    }

    private func cancelPreciseSettle() {
        preciseSettleTask?.cancel()
        preciseSettleTask = nil
    }

    private func settlePreciseWheel() {
        cancelPreciseSettle()
        wheelState.finishPreciseGesture()
        guard selectedOrdinal != nil,
              !loadedOrdinalRange.isEmpty,
              preciseGestureStartOrdinal != nil
        else {
            return
        }

        let targetOrdinal = currentLayout.nearestOrdinal

        preciseGestureStartOrdinal = nil
        activeWheelTargetOrdinal = targetOrdinal
        activeWheelContentGeneration = contentSnapshot?.generation
        documentView.updateSelection(targetOrdinal)
        wheelAnimator.retarget(
            from: fractionalOrdinal,
            to: CGFloat(targetOrdinal),
            duration: PlaybackSubtitleFocusMetrics
                .resolvedReelTransitionDuration(reducesMotion: reducesMotion)
        )
    }

    private func completeWheelMotion() {
        guard let targetOrdinal = activeWheelTargetOrdinal,
              activeWheelContentGeneration == contentSnapshot?.generation
        else {
            return
        }
        let didCommit: Bool
        if let onCommitVirtualReelSelection {
            didCommit = selectionCommit(for: targetOrdinal).map(
                onCommitVirtualReelSelection
            ) ?? false
        } else {
            didCommit = onCommitNativeReelSelection(targetOrdinal)
        }
        activeWheelTargetOrdinal = nil
        activeWheelContentGeneration = nil
        if didCommit {
            selectedOrdinal = targetOrdinal
        } else if selectedOrdinal != nil {
            documentView.updateSelection(selectedOrdinal)
        } else {
            restoreObservedExternalSelection()
        }
        setWheelMotionActive(false)
        if !didCommit, selectedOrdinal != nil {
            synchronizeFractionalOrdinalIfIdle()
        }
    }

    private func resetWheelInteraction(requiresNewGesture: Bool) {
        cancelPreciseSettle()
        wheelState.reset(requiresNewGesture: requiresNewGesture)
        wheelAnimator.cancel()
        activeWheelTargetOrdinal = nil
        activeWheelContentGeneration = nil
        preciseGestureStartOrdinal = nil
        documentView.updateSelection(selectedOrdinal)
        setWheelMotionActive(false)
        synchronizeFractionalOrdinalIfIdle()
    }

    private func suspendWheelInputForSuppression() {
        cancelPreciseSettle()
        wheelState.reset(requiresNewGesture: true)
        if preciseGestureStartOrdinal != nil {
            settlePreciseWheel()
        }
    }

    private var currentContentToken: ContentToken? {
        contentSnapshot.map {
            ContentToken(datasetID: $0.datasetID, generation: $0.generation)
        }
    }

    @discardableResult
    private func requestWindow(
        targetOrdinal: Int,
        reason: PlaybackVirtualReelWindowRequestReason,
        pendingSelection: PendingWindowSelection?
    ) -> Bool {
        guard let contentSnapshot,
              let mountedContentAdapter,
              mountedContentAdapter.supportsWindowRequests,
              targetOrdinal >= 0,
              targetOrdinal < contentSnapshot.totalCount
        else {
            return false
        }
        let suggestedRange = PlaybackVirtualReelWindowPolicy.standard
            .windowRange(
                totalCount: contentSnapshot.totalCount,
                targetOrdinal: targetOrdinal
            )
        guard !suggestedRange.isEmpty else {
            return false
        }
        if let pendingSelection {
            self.pendingWindowSelection = pendingSelection
        }
        let request = PlaybackVirtualReelWindowRequest(
            datasetID: contentSnapshot.datasetID,
            generation: contentSnapshot.generation,
            revision: contentSnapshot.revision,
            targetOrdinal: targetOrdinal,
            suggestedOrdinalRange: suggestedRange,
            reason: reason
        )
        guard lastWindowRequest != request else {
            return true
        }
        lastWindowRequest = request
        mountedContentAdapter.requestWindow(request)
        return true
    }

    private func requestVisibleWindowIfNeeded() {
        guard pendingWindowSelection == nil,
              pendingScrollbarPreview == nil,
              let selectedOrdinal,
              let contentSnapshot,
              !contentSnapshot.isComplete,
              let mountedContentAdapter,
              mountedContentAdapter.supportsWindowRequests
        else {
            return
        }
        let suggestedRange = PlaybackVirtualReelWindowPolicy.standard
            .windowRange(
                totalCount: contentSnapshot.totalCount,
                targetOrdinal: selectedOrdinal
            )
        let loadedRange = contentSnapshot.loadedOrdinalRange
        guard suggestedRange.lowerBound < loadedRange.lowerBound
                || suggestedRange.upperBound > loadedRange.upperBound
        else {
            return
        }
        _ = requestWindow(
            targetOrdinal: selectedOrdinal,
            reason: .visible,
            pendingSelection: nil
        )
    }

    private func requestAdjacentWindowIfNeeded(deltaY: CGFloat) {
        guard deltaY != 0,
              let token = currentContentToken,
              !loadedOrdinalRange.isEmpty
        else {
            return
        }
        let nearestOrdinal = currentLayout.nearestOrdinal
        let targetOrdinal: Int?
        if deltaY < 0,
           nearestOrdinal == loadedOrdinalRange.upperBound - 1,
           loadedOrdinalRange.upperBound < totalCount {
            targetOrdinal = loadedOrdinalRange.upperBound
        } else if deltaY > 0,
                  nearestOrdinal == loadedOrdinalRange.lowerBound,
                  loadedOrdinalRange.lowerBound > 0 {
            targetOrdinal = loadedOrdinalRange.lowerBound - 1
        } else {
            targetOrdinal = nil
        }
        guard let targetOrdinal,
              requestWindow(
                  targetOrdinal: targetOrdinal,
                  reason: .wheel,
                  pendingSelection: .native(
                      token: token,
                      ordinal: targetOrdinal,
                      reason: .wheel
                  )
              )
        else {
            return
        }
        cancelPreciseSettle()
        preciseGestureStartOrdinal = nil
        documentView.updateSelection(selectedOrdinal)
        setWheelMotionActive(true)
    }

    private func finishPendingWindowSelection(
        _ pendingSelection: PendingWindowSelection,
        fallbackSelectedOrdinal: Int?
    ) {
        let didCommit: Bool
        switch pendingSelection {
        case .keyboard(_, let request):
            if let onCommitVirtualReelSelection {
                didCommit = selectionCommit(for: request.targetOrdinal).map(
                    onCommitVirtualReelSelection
                ) ?? false
            } else {
                didCommit = onCommitKeyboardNavigation(request)
            }
        case .native(_, let ordinal, _):
            if let onCommitVirtualReelSelection {
                didCommit = selectionCommit(for: ordinal).map(
                    onCommitVirtualReelSelection
                ) ?? false
            } else {
                didCommit = onCommitNativeReelSelection(ordinal)
            }
        case .restore:
            didCommit = true
        }
        guard !didCommit else {
            selectedOrdinal = pendingSelection.ordinal
            fractionalOrdinal = CGFloat(pendingSelection.ordinal)
            hasInitializedPosition = true
            documentView.updateSelection(selectedOrdinal)
            updateDocumentGeometry()
            updateScrollbarPresentation()
            finishPendingWindowMotion(pendingSelection)
            return
        }
        if let fallbackSelectedOrdinal,
           loadedOrdinalRange.contains(fallbackSelectedOrdinal) {
            selectedOrdinal = fallbackSelectedOrdinal
            fractionalOrdinal = CGFloat(fallbackSelectedOrdinal)
        } else {
            selectedOrdinal = nil
            fractionalOrdinal = boundedLoadedFractionalOrdinal(
                fractionalOrdinal
            )
            if let fallbackSelectedOrdinal,
               let token = currentContentToken,
               requestWindow(
                   targetOrdinal: fallbackSelectedOrdinal,
                   reason: .visible,
                   pendingSelection: .restore(
                       token: token,
                       ordinal: fallbackSelectedOrdinal
                   )
               ) {
                // Keep selection empty only while the prior window reloads.
            } else if let firstLoadedOrdinal = loadedOrdinalRange.first {
                selectedOrdinal = firstLoadedOrdinal
                fractionalOrdinal = CGFloat(firstLoadedOrdinal)
            }
        }
        documentView.updateSelection(selectedOrdinal)
        updateDocumentGeometry()
        updateScrollbarPresentation()
        finishPendingWindowMotion(pendingSelection)
    }

    private func finishPendingWindowMotion(
        _ pendingSelection: PendingWindowSelection?
    ) {
        switch pendingSelection {
        case .keyboard:
            setKeyboardMotionActive(false)
        case .native:
            setWheelMotionActive(false)
        case .restore, nil:
            break
        }
    }

    private func selectionCommit(
        for ordinal: Int
    ) -> PlaybackVirtualReelSelectionCommit? {
        guard let contentSnapshot,
              contentSnapshot.loadedOrdinalRange.contains(ordinal)
        else {
            return nil
        }
        return PlaybackVirtualReelSelectionCommit(
            datasetID: contentSnapshot.datasetID,
            generation: contentSnapshot.generation,
            ordinal: ordinal
        )
    }

    private func boundedLoadedFractionalOrdinal(_ ordinal: CGFloat) -> CGFloat {
        PlaybackSubtitleFocusVirtualReelLayout.clampedFractionalOrdinal(
            ordinal,
            to: loadedOrdinalRange
        )
    }

    private static func scrollPhase(
        from phase: NSEvent.Phase
    ) -> PlaybackSubtitleFocusScrollSample.Phase {
        if phase.contains(.began) {
            return .began
        }
        if phase.contains(.changed)
            || phase.contains(.mayBegin)
            || phase.contains(.stationary) {
            return .changed
        }
        if phase.contains(.ended) {
            return .ended
        }
        if phase.contains(.cancelled) {
            return .cancelled
        }
        return .none
    }

    private func setKeyboardMotionActive(_ isActive: Bool) {
        guard isKeyboardMotionActive != isActive else {
            return
        }
        isKeyboardMotionActive = isActive
        updateScrollbarInteractionAvailability()
        updateReportedNativeMotion()
    }

    private func setWheelMotionActive(_ isActive: Bool) {
        guard isWheelMotionActive != isActive else {
            return
        }
        isWheelMotionActive = isActive
        updateScrollbarInteractionAvailability()
        updateReportedNativeMotion()
    }

    private func setScrollbarMotionActive(_ isActive: Bool) {
        guard isScrollbarMotionActive != isActive else {
            return
        }
        isScrollbarMotionActive = isActive
        updateReportedNativeMotion()
    }

    private var hasActiveNativeMotion: Bool {
        isKeyboardMotionActive
            || isWheelMotionActive
            || activeKeyboardRequest != nil
            || activeWheelTargetOrdinal != nil
            || preciseGestureStartOrdinal != nil
            || isScrollbarDragging
            || keyboardAnimator.isRunning
            || wheelAnimator.isRunning
    }

    private func updateReportedNativeMotion() {
        let isActive = isKeyboardMotionActive
            || isWheelMotionActive
            || isScrollbarMotionActive
        guard reportedNativeMotionActive != isActive else {
            return
        }
        reportedNativeMotionActive = isActive
        onNativeMotionGateChanged(isActive)
        motionCallbackGeneration += 1
        let generation = motionCallbackGeneration
        motionCallbackTask?.cancel()
        motionCallbackTask = Task { @MainActor [weak self] in
            guard let self,
                  !Task.isCancelled,
                  self.motionCallbackGeneration == generation,
                  self.reportedNativeMotionActive == isActive
            else {
                return
            }
            self.motionCallbackTask = nil
            self.onKeyboardMotionChanged(isActive)
        }
    }
}

typealias PlaybackVirtualReelContainerView =
    PlaybackSubtitleFocusReelContainerView

private final class PlaybackSubtitleFocusNativeScrollView: NSScrollView {
    override func scrollWheel(with event: NSEvent) {
        nextResponder?.scrollWheel(with: event)
    }
}

private final class PlaybackSubtitleFocusNativeScrollbarView:
    TableScrollbarOverlayView
{
    var allowsInteraction: () -> Bool = { false }
    var acceptsInteraction = false

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard acceptsInteraction, allowsInteraction() else {
            return nil
        }
        return super.hitTest(point)
    }
}

struct PlaybackCueTimelineRowLayout: Equatable {
    let markerRect: CGRect
    let cueRect: CGRect
}

@MainActor
enum PlaybackCueTimelineLayout {
    static func leadingAccessoryWidth(usesCheckbox: Bool) -> CGFloat {
        markerSize(usesCheckbox: usesCheckbox)
            + PlaybackCueTimelineMetrics.markerHorizontalGap
    }

    static func rowLayout(
        in rowRect: CGRect,
        usesCheckbox: Bool,
        markerCenterY: CGFloat? = nil
    ) -> PlaybackCueTimelineRowLayout {
        let markerSize = markerSize(usesCheckbox: usesCheckbox)
        let resolvedMarkerCenterY = markerCenterY
            ?? rowRect.minY
            + PlaybackSubtitleFocusMetrics.cueVerticalPadding
            + PlaybackSubtitleFocusMetrics.cueLineHeight / 2
        let markerY = resolvedMarkerCenterY - markerSize / 2
        let cueX = rowRect.minX
            + markerSize
            + PlaybackCueTimelineMetrics.markerHorizontalGap
        return PlaybackCueTimelineRowLayout(
            markerRect: CGRect(
                x: rowRect.minX,
                y: markerY,
                width: markerSize,
                height: markerSize
            ),
            cueRect: CGRect(
                x: cueX,
                y: rowRect.minY,
                width: max(0, rowRect.maxX - cueX),
                height: rowRect.height
            )
        )
    }

    static func connectorRect(
        from current: PlaybackCueTimelineRowLayout,
        to next: PlaybackCueTimelineRowLayout
    ) -> CGRect? {
        let startY = current.markerRect.maxY
            + PlaybackCueTimelineMetrics.connectorMarkerGap
        let endY = next.markerRect.minY
            - PlaybackCueTimelineMetrics.connectorMarkerGap
        guard endY > startY else {
            return nil
        }
        return CGRect(
            x: current.markerRect.midX
                - PlaybackCueTimelineMetrics.connectorWidth / 2,
            y: startY,
            width: PlaybackCueTimelineMetrics.connectorWidth,
            height: endY - startY
        )
    }

    static func drawConnector(in rect: CGRect) {
        PlaybackTheme.cueTimelineMutedNative.setFill()
        NSBezierPath(rect: rect).fill()
    }

    static func drawDot(
        isFocused: Bool,
        isEnabled: Bool,
        in rect: CGRect
    ) {
        let color = isEnabled
            ? isFocused
                ? PlaybackTheme.cueTimelineFocusedNative
                : PlaybackTheme.cueTimelineMutedNative
            : WorkbenchRedesignColors.NS.textDisabled
        color.setFill()
        NSBezierPath(ovalIn: rect).fill()
    }

    private static func markerSize(usesCheckbox: Bool) -> CGFloat {
        usesCheckbox
            ? PlaybackCollageSelectionMetrics.checkboxSize
            : PlaybackCueTimelineMetrics.dotSize
    }
}

@MainActor
enum PlaybackCollageCheckboxDrawing {
    static func draw(
        isSelected: Bool,
        isEnabled: Bool,
        in rect: CGRect
    ) {
        WorkbenchCheckboxStyle.drawAppKitGlyph(
            for: isSelected ? .checked : .unchecked,
            isEnabled: isEnabled,
            size: PlaybackCollageSelectionMetrics.checkboxSize,
            in: rect
        )
    }

    static func image(
        isSelected: Bool,
        isEnabled: Bool
    ) -> NSImage? {
        WorkbenchCheckboxStyle.appKitImage(
            for: isSelected ? .checked : .unchecked,
            isEnabled: isEnabled,
            size: PlaybackCollageSelectionMetrics.checkboxSize
        )
    }

    static func color(
        isSelected: Bool,
        isEnabled: Bool
    ) -> NSColor {
        WorkbenchCheckboxStyle.controlColor(
            for: isSelected ? .checked : .unchecked,
            isEnabled: isEnabled
        )
    }
}

final class PlaybackSubtitleFocusReelDocumentView: NSView, PointerShapeProviding {
    private struct TextSelection {
        let ordinal: Int
        let itemID: AnyHashable
        let lineUTF16Range: NSRange
        let anchorUTF16Offset: Int
        let anchorPoint: CGPoint
        var focusUTF16Offset: Int
        var focusPoint: CGPoint

        var range: NSRange {
            let lower = min(anchorUTF16Offset, focusUTF16Offset)
            return NSRange(
                location: lower,
                length: max(anchorUTF16Offset, focusUTF16Offset) - lower
            )
        }
    }

    var uiProbeScope: String?
    var onToggleCollageCueSelection: (Int) -> Void = { _ in }
    /// The text, the cue it came from, and where the menu hangs off inside that
    /// cue. A point in the document is no use on its own: the reel scrolls by
    /// laying its cues out somewhere else, so only the place inside the cue
    /// stays true.
    var onPresentSelectedTextActions: (String, Int, CGPoint) -> Void = { _, _, _ in }
    var onDismissSelectedTextActions: () -> Void = {}
    private var layout = PlaybackSubtitleFocusVirtualReelLayout(
        viewportSize: .zero,
        totalCount: 0,
        loadedOrdinalRange: 0..<0,
        fractionalOrdinal: 0
    )
    private var contentAdapter: (any PlaybackVirtualReelContentAdapter)?
    private var contentSnapshot: PlaybackVirtualReelSnapshot?
    private var selectedOrdinal: Int?
    private var collageSelectedCueIDs: Set<Int64>?
    private var collageCanSelectAnotherCue = true
    private var textSelection: TextSelection?
    private(set) var placements: [PlaybackSubtitleFocusCuePlacement] = []
    /// Set while a drag started in this view is choosing text.
    private var isSelectingText = false

    override var isFlipped: Bool {
        true
    }

    override var acceptsFirstResponder: Bool {
        false
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }

    var selectedOrdinalForTesting: Int? {
        selectedOrdinal
    }

    func updateContent(
        _ contentAdapter: any PlaybackVirtualReelContentAdapter
    ) {
        let snapshot = contentAdapter.snapshot
        guard snapshot.isValid else {
            return
        }
        if snapshot == contentSnapshot {
            if let previousAdapter = self.contentAdapter,
               previousAdapter !== contentAdapter {
                previousAdapter.invalidate()
                self.contentAdapter = contentAdapter
                resolveLocalPlacementsIfNeeded()
                needsDisplay = true
            }
            return
        }
        if let contentSnapshot,
           contentSnapshot.belongsToSameDataset(as: snapshot),
           (snapshot.revision < contentSnapshot.revision
               || snapshot.revision == contentSnapshot.revision) {
            if let previousAdapter = self.contentAdapter {
                if previousAdapter === contentAdapter {
                    invalidate()
                } else {
                    contentAdapter.invalidate()
                }
            }
            return
        }
        clearTextSelection()
        if let previousAdapter = self.contentAdapter,
           previousAdapter !== contentAdapter {
            previousAdapter.invalidate()
        }
        if let contentSnapshot,
           !contentSnapshot.belongsToSameDataset(as: snapshot) {
            placements.removeAll(keepingCapacity: true)
        }
        self.contentAdapter = contentAdapter
        contentSnapshot = snapshot
        resolveLocalPlacementsIfNeeded()
        needsDisplay = true
    }

    func updateSelection(_ ordinal: Int?) {
        guard selectedOrdinal != ordinal else {
            return
        }
        let previousOrdinal = selectedOrdinal
        selectedOrdinal = ordinal
        if let previousOrdinal {
            invalidateRow(previousOrdinal)
        }
        if let selectedOrdinal {
            invalidateRow(selectedOrdinal)
        }
        resolveLocalPlacementsIfNeeded()
        needsDisplay = true
    }

    func updateCollageSelection(
        selectedCueIDs: Set<Int64>?,
        canSelectAnotherCue: Bool
    ) {
        guard collageSelectedCueIDs != selectedCueIDs
                || collageCanSelectAnotherCue != canSelectAnotherCue
        else {
            return
        }
        let changesMode = (collageSelectedCueIDs == nil) != (selectedCueIDs == nil)
        let changesAvailability = collageCanSelectAnotherCue != canSelectAnotherCue
        let changedCueIDs = (collageSelectedCueIDs ?? [])
            .symmetricDifference(selectedCueIDs ?? [])
        UIInvalidationProbe.count(
            "playback.subtitle_focus.collage_selection_update",
            scope: uiProbeScope,
            details: "changed=\(changedCueIDs.count)"
        )
        collageSelectedCueIDs = selectedCueIDs
        collageCanSelectAnotherCue = canSelectAnotherCue

        if changesMode {
            clearTextSelection()
            UIInvalidationProbe.count(
                "playback.subtitle_focus.collage_full_invalidation",
                scope: uiProbeScope,
                details: "reason=mode"
            )
            resolveLocalPlacementsIfNeeded()
            needsDisplay = true
        } else if changesAvailability {
            UIInvalidationProbe.count(
                "playback.subtitle_focus.collage_full_invalidation",
                scope: uiProbeScope,
                details: "reason=availability"
            )
            needsDisplay = true
        } else {
            for placement in placements {
                guard let cueID = cueID(at: placement.ordinal),
                      changedCueIDs.contains(cueID)
                else {
                    continue
                }
                UIInvalidationProbe.count(
                    "playback.subtitle_focus.collage_row_invalidation",
                    scope: uiProbeScope,
                    details: "ordinal=\(placement.ordinal)"
                )
                invalidateRow(placement.ordinal)
            }
        }
    }

    func updateLocalLayout(_ layout: PlaybackSubtitleFocusVirtualReelLayout) {
        guard self.layout != layout else {
            return
        }
        if self.layout.contentWidth != layout.contentWidth {
            clearTextSelection()
        }
        self.layout = layout
        UIInvalidationProbe.count(
            "playback.subtitle_focus.layout_update",
            scope: uiProbeScope,
            details: "ordinal=\(layout.fractionalOrdinal)"
        )
        resolveLocalPlacementsIfNeeded()
        needsDisplay = true
    }

    func invalidate() {
        contentAdapter?.invalidate()
        contentAdapter = nil
        contentSnapshot = nil
        selectedOrdinal = nil
        collageSelectedCueIDs = nil
        collageCanSelectAnotherCue = true
        textSelection = nil
        placements.removeAll(keepingCapacity: false)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let visibleDirtyRect = dirtyRect.intersection(visibleRect)
        guard !visibleDirtyRect.isNull, !visibleDirtyRect.isEmpty else {
            return
        }
        for connectorRect in cueTimelineConnectorRects
        where connectorRect.intersects(visibleDirtyRect) {
            PlaybackCueTimelineLayout.drawConnector(in: connectorRect)
        }
        for placement in placements where placement.rect.intersects(visibleDirtyRect) {
            UIInvalidationProbe.count(
                "playback.subtitle_focus.cue_draw",
                scope: uiProbeScope,
                details: "ordinal=\(placement.ordinal)"
            )
            let isChecked = isCollageCueChecked(at: placement.ordinal)
            let canToggle = !isEditingCollage
                || isChecked
                || collageCanSelectAnotherCue
            contentAdapter?.drawItem(
                at: placement.ordinal,
                isSelected: placement.ordinal == selectedOrdinal,
                isEnabled: canToggle,
                selectedTextRange: textSelection?.ordinal == placement.ordinal
                    ? textSelection?.range
                    : nil,
                in: cueContentRect(for: placement.rect)
            )
            let timelineLayout = cueTimelineRowLayout(for: placement)
            if isEditingCollage {
                PlaybackCollageCheckboxDrawing.draw(
                    isSelected: isChecked,
                    isEnabled: canToggle,
                    in: timelineLayout.markerRect
                )
            } else {
                PlaybackCueTimelineLayout.drawDot(
                    isFocused: placement.ordinal == selectedOrdinal,
                    isEnabled: canToggle,
                    in: timelineLayout.markerRect
                )
            }
        }
    }

    func fractionalOrdinal(
        afterMovingBy pixelTravel: CGFloat,
        from currentFractionalOrdinal: CGFloat
    ) -> CGFloat {
        guard !layout.loadedOrdinalRange.isEmpty,
              pixelTravel.isFinite, pixelTravel != 0 else {
            return layout.fractionalOrdinal
        }

        let range: Range<Int>
        if let firstPlacement = placements.first,
           let lastPlacement = placements.last {
            let lower = max(
                layout.loadedOrdinalRange.lowerBound,
                firstPlacement.ordinal
            )
            let upper = min(
                layout.loadedOrdinalRange.upperBound,
                lastPlacement.ordinal + 1
            )
            range = lower..<max(lower, upper)
        } else {
            range = layout.loadedOrdinalRange
        }
        var position = PlaybackSubtitleFocusVirtualReelLayout
            .clampedFractionalOrdinal(currentFractionalOrdinal, to: range)
        var remaining = abs(pixelTravel)
        let movesForward = pixelTravel > 0
        var safetyCount = 0

        while remaining > 0.000_1, safetyCount < range.count + 1 {
            safetyCount += 1
            if movesForward {
                guard position < CGFloat(range.upperBound - 1) else {
                    break
                }
                let lower = Int(floor(position))
                let upper = lower + 1
                guard let lowerMeasurement = measurement(at: lower, layout: layout),
                      let upperMeasurement = measurement(at: upper, layout: layout) else {
                    break
                }
                let distance = layout.adjacentCenterDistance(
                    from: lowerMeasurement.resolvedHeight,
                    to: upperMeasurement.resolvedHeight
                )
                guard distance > 0 else {
                    position = CGFloat(upper)
                    continue
                }
                let fraction = position - CGFloat(lower)
                let distanceToBoundary = (1 - fraction) * distance
                if remaining < distanceToBoundary {
                    position += remaining / distance
                    remaining = 0
                } else {
                    position = CGFloat(upper)
                    remaining -= distanceToBoundary
                }
            } else {
                guard position > CGFloat(range.lowerBound) else {
                    break
                }
                let upper = Int(ceil(position))
                let lower = upper - 1
                guard let lowerMeasurement = measurement(at: lower, layout: layout),
                      let upperMeasurement = measurement(at: upper, layout: layout) else {
                    break
                }
                let distance = layout.adjacentCenterDistance(
                    from: lowerMeasurement.resolvedHeight,
                    to: upperMeasurement.resolvedHeight
                )
                guard distance > 0 else {
                    position = CGFloat(lower)
                    continue
                }
                let fraction = position - CGFloat(lower)
                let distanceToBoundary = fraction * distance
                if remaining < distanceToBoundary {
                    position -= remaining / distance
                    remaining = 0
                } else {
                    position = CGFloat(lower)
                    remaining -= distanceToBoundary
                }
            }
        }

        return PlaybackSubtitleFocusVirtualReelLayout.clampedFractionalOrdinal(
            position,
            to: range
        )
    }

    var visibleCueCenterCapacity: Int {
        guard !placements.isEmpty else {
            return 1
        }
        let count = placements.reduce(into: 0) { result, placement in
            if placement.rect.midY >= 0,
               placement.rect.midY <= layout.viewportSize.height {
                result += 1
            }
        }
        return max(1, count)
    }

    var measurementCacheCount: Int {
        contentAdapter?.measurementCacheCountForTesting ?? 0
    }

    var measuredOrdinals: Set<Int> {
        contentAdapter?.measuredOrdinalsForTesting ?? []
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        clearTextSelection()
        if let placement = collagePlacement(containing: point) {
            _ = toggleCollageCue(at: placement.ordinal)
            return
        }
        beginTextSelection(at: point)
        isSelectingText = textSelection != nil
    }

    override func mouseDragged(with event: NSEvent) {
        updateTextSelection(
            focusPoint: convert(event.locationInWindow, from: nil)
        )
    }

    override func mouseUp(with event: NSEvent) {
        // A release only ends a drag this view began. The press that closes an
        // open menu is swallowed before it reaches here, and its release must
        // not be read as a finished selection and open the menu straight back
        // up.
        guard isSelectingText else {
            return
        }
        isSelectingText = false

        let point = convert(event.locationInWindow, from: nil)
        updateTextSelection(focusPoint: point)
        guard let textSelection,
              textSelection.range.length > 0,
              let text = contentAdapter?.selectedText(
                  at: textSelection.ordinal,
                  range: textSelection.range
              ),
              !text.isEmpty,
              let cueOrigin = cueContentOrigin(at: textSelection.ordinal)
        else {
            clearTextSelection()
            return
        }
        let anchorPoint = textSelection.focusUTF16Offset
            >= textSelection.anchorUTF16Offset
            ? textSelection.focusPoint
            : textSelection.anchorPoint
        onPresentSelectedTextActions(
            text,
            textSelection.ordinal,
            CGPoint(
                x: anchorPoint.x - cueOrigin.x,
                y: anchorPoint.y - cueOrigin.y
            )
        )
    }

    override func resetCursorRects() {
        addCursorRect(visibleRect, cursor: AppPointerShape.rectCursor)
    }

    /// The reel's answer to the pointer, asked by `AppPointerShape` when the
    /// pointer really moved: the I-beam over selectable cue text, the arrow
    /// elsewhere and throughout collage editing.
    func pointerShape(atWindowPoint windowPoint: CGPoint) -> PointerShape {
        guard !isEditingCollage, let contentAdapter else {
            return .arrow
        }
        let point = convert(windowPoint, from: nil)
        guard let placement = textPlacement(containing: point) else {
            return .arrow
        }
        let isOverText = contentAdapter.selectableTextRects(
            at: placement.ordinal,
            in: cueContentRect(for: placement.rect)
        ).contains { $0.contains(point) }
        return isOverText ? .iBeam : .arrow
    }

    func toggleCollageCueForTesting(at ordinal: Int) -> Bool {
        toggleCollageCue(at: ordinal)
    }

    func toggleCollageCueForTesting(at point: CGPoint) -> Bool {
        guard let placement = collagePlacement(containing: point) else {
            return false
        }
        return toggleCollageCue(at: placement.ordinal)
    }

    func collageCheckboxRectForTesting(at ordinal: Int) -> CGRect? {
        placements.first { $0.ordinal == ordinal }.map(collageCheckboxRect)
    }

    func cueContentRectForTesting(at ordinal: Int) -> CGRect? {
        placements.first { $0.ordinal == ordinal }.map {
            cueContentRect(for: $0.rect)
        }
    }

    var hasTextSelectionForTesting: Bool {
        textSelection != nil
    }

    /// The lines of a cue that can be selected, where they sit in the document.
    func selectableTextRectsForTesting(at ordinal: Int) -> [CGRect] {
        guard let placement = placements.first(where: { $0.ordinal == ordinal }),
              let contentAdapter
        else {
            return []
        }
        return contentAdapter.selectableTextRects(
            at: ordinal,
            in: cueContentRect(for: placement.rect)
        )
    }

    var cueTimelineConnectorRectsForTesting: [CGRect] {
        cueTimelineConnectorRects
    }

    func isCueHighlightedForTesting(at ordinal: Int) -> Bool {
        ordinal == selectedOrdinal
    }

    func isCollageCueEnabledForTesting(at ordinal: Int) -> Bool {
        !isEditingCollage
            || isCollageCueChecked(at: ordinal)
            || collageCanSelectAnotherCue
    }

    private func beginTextSelection(at point: CGPoint) {
        guard let placement = textPlacement(containing: point),
              let itemID = contentAdapter?.itemID(at: placement.ordinal),
              let hit = contentAdapter?.textSelectionHit(
                  at: placement.ordinal,
                  point: point,
                  in: cueContentRect(for: placement.rect),
                  constrainedToLine: nil
              )
        else {
            return
        }
        textSelection = TextSelection(
            ordinal: placement.ordinal,
            itemID: itemID,
            lineUTF16Range: hit.lineUTF16Range,
            anchorUTF16Offset: hit.utf16Offset,
            anchorPoint: hit.boundaryPoint,
            focusUTF16Offset: hit.utf16Offset,
            focusPoint: hit.boundaryPoint
        )
    }

    private func updateTextSelection(focusPoint: CGPoint) {
        guard let currentSelection = textSelection,
              let placement = placements.first(where: {
                  $0.ordinal == currentSelection.ordinal
                      && $0.itemID == currentSelection.itemID
              }),
              let hit = contentAdapter?.textSelectionHit(
                  at: currentSelection.ordinal,
                  point: focusPoint,
                  in: cueContentRect(for: placement.rect),
                  constrainedToLine: currentSelection.lineUTF16Range
              ),
              hit.lineUTF16Range == currentSelection.lineUTF16Range,
              hit.utf16Offset != currentSelection.focusUTF16Offset
        else {
            return
        }
        textSelection?.focusUTF16Offset = hit.utf16Offset
        textSelection?.focusPoint = hit.boundaryPoint
        invalidateRow(currentSelection.ordinal)
    }

    private func clearTextSelection() {
        guard let textSelection else {
            return
        }
        self.textSelection = nil
        onDismissSelectedTextActions()
        invalidateRow(textSelection.ordinal)
    }

    /// Drops the selection without reporting it, for the reel closing the menu
    /// that hangs off it.
    func discardTextSelection() {
        guard let textSelection else {
            return
        }
        self.textSelection = nil
        invalidateRow(textSelection.ordinal)
    }

    private func invalidateRow(_ ordinal: Int) {
        guard ordinal >= 0, ordinal < layout.totalCount else {
            return
        }
        if let placement = placements.first(where: { $0.ordinal == ordinal }) {
            setNeedsDisplay(placement.rect)
        }
    }

    private func resolveLocalPlacementsIfNeeded() {
        guard !layout.loadedOrdinalRange.isEmpty,
              layout.viewportSize.width > 0,
              layout.viewportSize.height > 0,
              let lowerMeasurement = measurement(
                  at: layout.lowerOrdinal,
                  layout: layout
              ) else {
            placements = []
            return
        }

        let upperMeasurement = measurement(
            at: layout.upperOrdinal,
            layout: layout
        ) ?? lowerMeasurement
        let lowerTop = layout.lowerCueTop(
            lowerResolvedHeight: lowerMeasurement.resolvedHeight,
            upperResolvedHeight: upperMeasurement.resolvedHeight
        )
        var resolved: [Int: PlaybackSubtitleFocusCuePlacement] = [:]
        guard let lowerPlacement = placement(
            ordinal: layout.lowerOrdinal,
            top: lowerTop,
            measurement: lowerMeasurement,
            layout: layout
        ) else {
            placements = []
            return
        }
        resolved[layout.lowerOrdinal] = lowerPlacement

        if layout.upperOrdinal != layout.lowerOrdinal {
            guard let upperPlacement = placement(
                ordinal: layout.upperOrdinal,
                top: lowerTop + lowerMeasurement.resolvedHeight
                    + PlaybackSubtitleFocusMetrics.cueGap,
                measurement: upperMeasurement,
                layout: layout
            ) else {
                placements = []
                return
            }
            resolved[layout.upperOrdinal] = upperPlacement
        }

        var nextTop = lowerTop
        var outsideCount = 0
        if layout.lowerOrdinal > layout.loadedOrdinalRange.lowerBound {
            for ordinal in stride(
                from: layout.lowerOrdinal - 1,
                through: layout.loadedOrdinalRange.lowerBound,
                by: -1
            ) {
                guard let measurement = measurement(at: ordinal, layout: layout) else {
                    placements = []
                    return
                }
                let top = nextTop
                    - PlaybackSubtitleFocusMetrics.cueGap
                    - measurement.resolvedHeight
                guard let item = placement(
                    ordinal: ordinal,
                    top: top,
                    measurement: measurement,
                    layout: layout
                ) else {
                    placements = []
                    return
                }
                resolved[ordinal] = item
                nextTop = top
                if item.rect.maxY < 0 {
                    outsideCount += 1
                    if outsideCount
                        >= PlaybackVirtualReelLayout.overscanItemCount {
                        break
                    }
                }
            }
        }

        let lastSeedOrdinal = layout.upperOrdinal
        var nextBottom = resolved[lastSeedOrdinal]?.rect.maxY
            ?? resolved[layout.lowerOrdinal]?.rect.maxY
            ?? lowerTop
        outsideCount = 0
        if lastSeedOrdinal < layout.loadedOrdinalRange.upperBound - 1 {
            for ordinal in (lastSeedOrdinal + 1)..<layout.loadedOrdinalRange.upperBound {
                guard let measurement = measurement(at: ordinal, layout: layout) else {
                    placements = []
                    return
                }
                let top = nextBottom + PlaybackSubtitleFocusMetrics.cueGap
                guard let item = placement(
                    ordinal: ordinal,
                    top: top,
                    measurement: measurement,
                    layout: layout
                ) else {
                    placements = []
                    return
                }
                resolved[ordinal] = item
                nextBottom = item.rect.maxY
                if item.rect.minY > layout.viewportSize.height {
                    outsideCount += 1
                    if outsideCount
                        >= PlaybackVirtualReelLayout.overscanItemCount {
                        break
                    }
                }
            }
        }

        placements = resolved.values.sorted { $0.ordinal < $1.ordinal }
    }

    private func measurement(
        at ordinal: Int,
        layout: PlaybackSubtitleFocusVirtualReelLayout
    ) -> PlaybackSubtitleFocusCueMeasurement? {
        contentAdapter?.extent(
            at: ordinal,
            isSelected: ordinal == selectedOrdinal,
            contentWidth: cueContentWidth(for: layout.contentWidth),
            viewportHeight: layout.viewportSize.height,
            uiProbeScope: uiProbeScope
        )
    }

    private func placement(
        ordinal: Int,
        top: CGFloat,
        measurement: PlaybackSubtitleFocusCueMeasurement,
        layout: PlaybackSubtitleFocusVirtualReelLayout
    ) -> PlaybackSubtitleFocusCuePlacement? {
        guard let itemID = contentAdapter?.itemID(at: ordinal) else {
            return nil
        }
        return PlaybackSubtitleFocusCuePlacement(
            ordinal: ordinal,
            itemID: itemID,
            rect: CGRect(
                x: (layout.viewportSize.width - layout.contentWidth) / 2,
                y: top,
                width: layout.contentWidth,
                height: measurement.resolvedHeight
            ),
            extent: measurement
        )
    }

    private var isEditingCollage: Bool {
        collageSelectedCueIDs != nil
    }

    private func cueID(at ordinal: Int) -> Int64? {
        contentAdapter?.itemID(at: ordinal)?.base as? Int64
    }

    private func isCollageCueChecked(at ordinal: Int) -> Bool {
        guard let cueID = cueID(at: ordinal) else {
            return false
        }
        return collageSelectedCueIDs?.contains(cueID) == true
    }

    private func cueContentWidth(for width: CGFloat) -> CGFloat {
        return max(
            0,
            width - PlaybackCueTimelineLayout.leadingAccessoryWidth(
                usesCheckbox: isEditingCollage
            )
        )
    }

    private func cueContentRect(for rect: CGRect) -> CGRect {
        cueTimelineRowLayout(for: rect).cueRect
    }

    /// Where a cue's text starts in the document as the reel lays it out now.
    /// `nil` once the reel has carried that cue outside the laid-out window.
    func cueContentOrigin(at ordinal: Int) -> CGPoint? {
        placements.first { $0.ordinal == ordinal }.map {
            cueContentRect(for: $0.rect).origin
        }
    }

    private func collageCheckboxRect(
        for placement: PlaybackSubtitleFocusCuePlacement
    ) -> CGRect {
        guard isEditingCollage else {
            return .null
        }
        return cueTimelineRowLayout(for: placement).markerRect
    }

    private func cueTimelineRowLayout(
        for rect: CGRect
    ) -> PlaybackCueTimelineRowLayout {
        PlaybackCueTimelineLayout.rowLayout(
            in: rect,
            usesCheckbox: isEditingCollage
        )
    }

    private func cueTimelineRowLayout(
        for placement: PlaybackSubtitleFocusCuePlacement
    ) -> PlaybackCueTimelineRowLayout {
        PlaybackCueTimelineLayout.rowLayout(
            in: placement.rect,
            usesCheckbox: isEditingCollage,
            markerCenterY: placement.rect.minY
                + placement.extent.firstVisualLineCenterOffset
        )
    }

    private var cueTimelineConnectorRects: [CGRect] {
        zip(placements, placements.dropFirst()).compactMap { current, next in
            guard next.ordinal == current.ordinal + 1 else {
                return nil
            }
            return PlaybackCueTimelineLayout.connectorRect(
                from: cueTimelineRowLayout(for: current),
                to: cueTimelineRowLayout(for: next)
            )
        }
    }

    private func collagePlacement(
        containing point: CGPoint
    ) -> PlaybackSubtitleFocusCuePlacement? {
        guard isEditingCollage else {
            return nil
        }
        return placements.first { $0.rect.contains(point) }
    }

    private func textPlacement(
        containing point: CGPoint
    ) -> PlaybackSubtitleFocusCuePlacement? {
        placements.first {
            cueContentRect(for: $0.rect).contains(point)
        }
    }

    private func toggleCollageCue(at ordinal: Int) -> Bool {
        guard isEditingCollage,
              placements.contains(where: { $0.ordinal == ordinal }),
              isCollageCueChecked(at: ordinal) || collageCanSelectAnotherCue
        else {
            return false
        }
        onToggleCollageCueSelection(ordinal)
        return true
    }
}

typealias PlaybackVirtualReelDocumentView =
    PlaybackSubtitleFocusReelDocumentView

@MainActor
final class PlaybackSubtitleFocusNativeTextLayout {
    private let visualLineLayout = PlaybackVisualLineStackLayout()

    func draw(
        text: String,
        color: NSColor,
        selectedTextRange: NSRange? = nil,
        in rect: CGRect
    ) {
        let textRect = Self.textRect(in: rect)
        guard textRect.width > 0, textRect.height > 0 else {
            return
        }
        visualLineLayout.prepare(
            text: text,
            color: color,
            width: textRect.width
        )
        if let selectedTextRange {
            visualLineLayout.drawSelection(
                forUTF16Range: selectedTextRange,
                in: textRect
            )
        }
        visualLineLayout.drawPreparedPlan(in: textRect)
    }

    func textSelectionHit(
        text: String,
        point: CGPoint,
        in rect: CGRect,
        constrainedToLine lineUTF16Range: NSRange? = nil
    ) -> PlaybackTextSelectionHit? {
        let textRect = Self.textRect(in: rect)
        guard textRect.width > 0, textRect.height > 0 else {
            return nil
        }
        visualLineLayout.prepare(
            text: text,
            color: .white,
            width: textRect.width
        )
        return visualLineLayout.textSelectionHit(
            at: point,
            in: textRect,
            constrainedToLine: lineUTF16Range
        )
    }

    func selectedText(range: NSRange) -> String? {
        return visualLineLayout.selectedText(forUTF16Range: range)
    }

    func visibleLineRects(
        text: String,
        in rect: CGRect
    ) -> [CGRect] {
        let textRect = Self.textRect(in: rect)
        guard textRect.width > 0, textRect.height > 0 else {
            return []
        }
        let plan = visualLineLayout.prepare(
            text: text,
            color: .white,
            width: textRect.width
        )
        return plan.typographicRects(in: textRect).compactMap { lineRect in
            let visibleRect = lineRect.intersection(textRect)
            guard !visibleRect.isNull,
                  visibleRect.width > 0,
                  visibleRect.height > 0
            else {
                return nil
            }
            return visibleRect
        }
    }

    private static func textRect(in cueRect: CGRect) -> CGRect {
        CGRect(
            x: cueRect.minX,
            y: cueRect.minY + PlaybackSubtitleFocusMetrics.cueVerticalPadding,
            width: cueRect.width,
            height: max(
                0,
                cueRect.height
                    - PlaybackSubtitleFocusMetrics.cueVerticalPadding * 2
            )
        )
    }
}

@MainActor
final class PlaybackSubtitleFocusReelPositionAnimator: NSObject {
    let onUpdate: (CGFloat) -> Void
    let onCompletion: () -> Void

    private(set) var isRunning = false
    private var timer: Timer?
    private var generation = 0
    private var startTime: TimeInterval = 0
    private var duration: TimeInterval = 0
    private var startOffset: CGFloat = 0
    private var targetOffset: CGFloat = 0

    init(
        onUpdate: @escaping (CGFloat) -> Void,
        onCompletion: @escaping () -> Void
    ) {
        self.onUpdate = onUpdate
        self.onCompletion = onCompletion
    }

    func retarget(
        from currentOffset: CGFloat,
        to targetOffset: CGFloat,
        duration: TimeInterval
    ) {
        generation += 1
        startTime = ProcessInfo.processInfo.systemUptime
        self.duration = max(0, duration)
        startOffset = currentOffset
        self.targetOffset = targetOffset
        isRunning = true

        guard self.duration > 0, abs(targetOffset - currentOffset) > 0.01 else {
            finishImmediately(generation: generation)
            return
        }
        if timer == nil {
            let timer = Timer(
                timeInterval: 1 / 120,
                target: self,
                selector: #selector(handleTimer),
                userInfo: nil,
                repeats: true
            )
            timer.tolerance = 1 / 240
            RunLoop.main.add(timer, forMode: .common)
            self.timer = timer
        }
    }

    func cancel() {
        generation += 1
        timer?.invalidate()
        timer = nil
        isRunning = false
    }

    static func easedProgress(_ linearProgress: CGFloat) -> CGFloat {
        let x = min(1, max(0, linearProgress))
        guard x > 0, x < 1 else {
            return x
        }

        var lower: CGFloat = 0
        var upper: CGFloat = 1
        var parameter = x
        for _ in 0..<10 {
            let estimatedX = cubicBezierValue(
                parameter,
                firstControl: 0.22,
                secondControl: 0.36
            )
            if estimatedX < x {
                lower = parameter
            } else {
                upper = parameter
            }
            parameter = (lower + upper) / 2
        }
        return cubicBezierValue(
            parameter,
            firstControl: 1,
            secondControl: 1
        )
    }

    @objc
    private func handleTimer() {
        let elapsed = ProcessInfo.processInfo.systemUptime - startTime
        let linearProgress = CGFloat(min(1, max(0, elapsed / duration)))
        let easedProgress = Self.easedProgress(linearProgress)
        onUpdate(
            startOffset + (targetOffset - startOffset) * easedProgress
        )
        guard linearProgress >= 1 else {
            return
        }

        timer?.invalidate()
        timer = nil
        isRunning = false
        onUpdate(targetOffset)
        onCompletion()
    }

    private func finishImmediately(generation expectedGeneration: Int) {
        timer?.invalidate()
        timer = nil
        onUpdate(targetOffset)
        Task { @MainActor [weak self] in
            guard let self,
                  self.generation == expectedGeneration,
                  self.isRunning
            else {
                return
            }
            self.isRunning = false
            self.onCompletion()
        }
    }

    private static func cubicBezierValue(
        _ parameter: CGFloat,
        firstControl: CGFloat,
        secondControl: CGFloat
    ) -> CGFloat {
        let inverse = 1 - parameter
        return 3 * inverse * inverse * parameter * firstControl
            + 3 * inverse * parameter * parameter * secondControl
            + parameter * parameter * parameter
    }
}

/// The menu offered after selecting subtitle text with the pointer.
///
/// It observes the highlight model so arrow keys and pointer motion move one
/// highlight; the rows never paint their own hover.
private struct PlaybackSelectedTextMenu: View {
    struct Item {
        let title: String
        let systemImage: String
    }

    @ObservedObject var highlight: MenuHighlightModel
    let items: [Item]
    let onActivate: (Int) -> Void

    var body: some View {
        WorkbenchPopoverPanel(isRedesign: true, highlight: highlight) {
            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.offset) { position, item in
                    WorkbenchPopoverRow(
                        title: item.title,
                        isHighlighted: highlight.highlightedPosition == position,
                        systemImage: item.systemImage,
                        isRedesign: true,
                        showsCheckmarkSlot: false,
                        action: { onActivate(position) },
                        onHoverChange: { isHovered in
                            highlight.noteHover(isHovered, at: position)
                        }
                    )
                    .id(position)
                }
            }
        }
    }
}
