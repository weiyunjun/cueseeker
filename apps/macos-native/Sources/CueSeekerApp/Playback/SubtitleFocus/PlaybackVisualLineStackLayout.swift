import AppKit
import CoreText
import CueSeekerCore

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
