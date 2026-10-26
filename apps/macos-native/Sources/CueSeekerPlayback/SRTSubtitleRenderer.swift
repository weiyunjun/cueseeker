import AppKit
import CoreImage
import CoreText
import CueSeekerCore
import Foundation

final class SRTSubtitleLayout: @unchecked Sendable {
    let canvasSize: CGSize
    let metrics: SRTSubtitleMetrics
    let track: PlaybackSubtitleTrack
    let items: [Int: SRTSubtitleItem]

    init(
        canvasSize: CGSize,
        metrics: SRTSubtitleMetrics,
        track: PlaybackSubtitleTrack,
        items: [Int: SRTSubtitleItem]
    ) {
        self.canvasSize = canvasSize
        self.metrics = metrics
        self.track = track
        self.items = items
    }

    var placements: [Int: CGRect] {
        items.mapValues(\.visualBounds)
    }

    var textPlacements: [Int: CGRect] {
        items.mapValues(\.textBounds)
    }

    var collisionPlacements: [Int: CGRect] {
        items.mapValues(\.collisionBounds)
    }

    func activePlacements(atMilliseconds milliseconds: Int) -> [CGRect] {
        track.activeCues(atMilliseconds: milliseconds).compactMap {
            guard let item = items[$0.sourceOrdinal], item.isDrawable else {
                return nil
            }
            return item.visualBounds
        }
    }
}

struct SRTPositionedLine: @unchecked Sendable {
    let line: CTLine
    /// The line's baseline origin inside the cue's text box (`textBox`).
    let origin: CGPoint
    /// Visible typographic width, excluding trailing whitespace and trailing
    /// letter spacing.
    let width: CGFloat
}

struct SRTSubtitleItem: @unchecked Sendable {
    let cue: PlaybackSubtitleCue
    let lines: [SRTPositionedLine]
    /// Where the text box's origin sits in the item, measured up from the
    /// item's bottom-left corner.
    let textOrigin: CGPoint
    /// Each line's box, padding included, in text box coordinates.
    let lineBoxes: [CGRect]
    /// Pure text layout box on the canvas (x rightward, y downward).
    let textBounds: CGRect
    /// Text with its outline or boxes on the canvas, used for collision
    /// stacking between overlapping cues.
    let collisionBounds: CGRect
    /// Full rendered extent on the canvas, including shadow and blur.
    let visualBounds: CGRect
    let isDrawable: Bool
}

/// A cue's text laid out, and the extent of everything drawn for it.
private struct SRTMeasuredText {
    let lines: [SRTPositionedLine]
    let lineBoxes: [CGRect]
    /// The pure text layout box (`0 ... width`, `0 ... height`). Margins and
    /// single-cue alignment place this rectangle directly.
    let textBox: CGRect
    /// The text with its outline or boxes, in text box coordinates. Multi-cue
    /// collision stacking avoids overlapping this rectangle.
    let collision: CGRect
    /// The full rendered extent with shadow and blur, in text box coordinates.
    let visual: CGRect
}

/// The style in the pixels of one canvas.
struct SRTSubtitleMetrics {
    let style: SRTSubtitleStyle
    let baseFont: CTFont
    let lineHeight: CGFloat
    let letterSpacing: CGFloat
    let lineSpacing: CGFloat
    /// Zero for Background Box, which draws no outline.
    let outlineWidth: CGFloat
    /// Zero for Outline, which draws no box.
    let boxPadding: CGFloat
    let blurSigma: CGFloat
    let shadowOffset: CGFloat
    let marginX: CGFloat
    let marginY: CGFloat

    init(style: SRTSubtitleStyle, canvasHeight: CGFloat) {
        let scale = canvasHeight / CGFloat(SRTSubtitleStyle.referenceHeight)
        self.style = style
        baseFont = Self.baseFont(named: style.fontName)
        lineHeight = CGFloat(style.size) * scale
        letterSpacing = CGFloat(style.letterSpacing) * scale
        lineSpacing = CGFloat(style.lineSpacing) * scale
        outlineWidth = style.borderType == .outline
            ? CGFloat(style.outlineWidth) * scale
            : 0
        boxPadding = style.borderType == .outline
            ? 0
            : CGFloat(SRTSubtitleStyle.boxPadding) * scale
        // libass takes its blur value to a Gaussian deviation this way.
        blurSigma = CGFloat(style.blur) * scale * 2 / sqrt(log(256))
        shadowOffset = CGFloat(style.shadowOffset) * scale
        marginX = CGFloat(style.marginX) * scale
        marginY = CGFloat(style.marginY) * scale
    }

    var blurExtent: CGFloat {
        ceil(3 * blurSigma)
    }

    /// Blur softens the outline when there is one and the text otherwise.
    var blursOutline: Bool {
        outlineWidth > 0
    }

    private static func baseFont(named name: String?) -> CTFont {
        let systemFont = CTFontCreateUIFontForLanguage(.system, 12, nil)
            ?? CTFontCreateWithName("Helvetica" as CFString, 12, nil)
        guard let name, !name.isEmpty else {
            return systemFont
        }
        let font = CTFontCreateWithName(name as CFString, 12, nil)
        // A name no installed font carries comes back as some other font.
        let postScriptMatch = CTFontCopyPostScriptName(font) as String == name
        let familyMatch = (CTFontCopyFamilyName(font) as String?) == name
        return (postScriptMatch || familyMatch) ? font : systemFont
    }
}

private struct SRTSubtitleRenderingError: Error, LocalizedError {
    let errorDescription: String?
}

enum SRTSubtitleRenderer {
    static func makeLayout(
        cues: [PlaybackSubtitleCue],
        canvasSize: CGSize,
        style: SRTSubtitleStyle,
        isCancelled: () -> Bool = { false }
    ) -> SRTSubtitleLayout? {
        guard canvasSize.width > 1, canvasSize.height > 1 else {
            return nil
        }

        let metrics = SRTSubtitleMetrics(style: style, canvasHeight: canvasSize.height)
        let maximumTextWidth = max(1, canvasSize.width - 2 * metrics.marginX)
        var fonts = SRTFontCache(lineHeight: metrics.lineHeight)
        let track = PlaybackSubtitleTrack(cues: cues)
        var items: [Int: SRTSubtitleItem] = [:]
        var activeItems: [SRTSubtitleItem] = []

        for cue in track.cues {
            guard !isCancelled() else {
                return nil
            }
            activeItems.removeAll { $0.cue.endMilliseconds <= cue.startMilliseconds }
            guard let measured = measure(
                text: cue.text,
                metrics: metrics,
                fonts: &fonts,
                maximumWidth: maximumTextWidth
            ) else {
                continue
            }

            let placed = placement(
                of: measured,
                below: activeItems,
                canvasSize: canvasSize,
                metrics: metrics
            )
            let drawable: Bool
            switch style.verticalAlignment {
            case .top, .center:
                drawable = placed.visualBounds.maxY <= canvasSize.height
                    || placed.visualBounds.height > canvasSize.height
            case .bottom:
                drawable = placed.visualBounds.minY >= 0
                    || placed.visualBounds.height > canvasSize.height
            }
            let item = SRTSubtitleItem(
                cue: cue,
                lines: measured.lines,
                textOrigin: CGPoint(x: -measured.visual.minX, y: -measured.visual.minY),
                lineBoxes: measured.lineBoxes,
                textBounds: placed.textBounds,
                collisionBounds: placed.collisionBounds,
                visualBounds: placed.visualBounds,
                isDrawable: drawable
            )
            items[cue.sourceOrdinal] = item
            if drawable {
                activeItems.append(item)
            }
        }

        return SRTSubtitleLayout(
            canvasSize: canvasSize,
            metrics: metrics,
            track: track,
            items: items
        )
    }

    /// The first cue aligns its pure text box (`textBox`) to `marginX` and
    /// `marginY`, or centers it on the canvas; each later overlapping cue stacks
    /// against `collisionBounds` (text + outline/box, excluding shadow and blur),
    /// upward for Bottom and downward for Top and Center.
    private static func placement(
        of measured: SRTMeasuredText,
        below activeItems: [SRTSubtitleItem],
        canvasSize: CGSize,
        metrics: SRTSubtitleMetrics
    ) -> (textBounds: CGRect, collisionBounds: CGRect, visualBounds: CGRect) {
        let textBox = measured.textBox
        let collision = measured.collision
        let visual = measured.visual

        let textX: CGFloat
        switch metrics.style.horizontalAlignment {
        case .left:
            textX = metrics.marginX
        case .center:
            textX = (canvasSize.width - textBox.width) / 2
        case .right:
            textX = canvasSize.width - metrics.marginX - textBox.width
        }

        let collisionTopOutset = collision.maxY - textBox.maxY
        let visualTopOutset = visual.maxY - textBox.maxY

        let textY: CGFloat
        switch metrics.style.verticalAlignment {
        case .top:
            if let stackTop = activeItems.map(\.collisionBounds.maxY).max() {
                textY = stackTop + collisionTopOutset
            } else {
                textY = metrics.marginY
            }
        case .center:
            if let stackTop = activeItems.map(\.collisionBounds.maxY).max() {
                textY = stackTop + collisionTopOutset
            } else {
                textY = (canvasSize.height - textBox.height) / 2
            }
        case .bottom:
            if let stackBottom = activeItems.map(\.collisionBounds.minY).min() {
                textY = stackBottom - collision.height + collisionTopOutset
            } else {
                textY = canvasSize.height - metrics.marginY - textBox.height
            }
        }

        let textBounds = CGRect(
            x: textX,
            y: textY,
            width: textBox.width,
            height: textBox.height
        )
        let collisionBounds = CGRect(
            x: textX + (collision.minX - textBox.minX),
            y: textY - collisionTopOutset,
            width: collision.width,
            height: collision.height
        )
        let visualBounds = CGRect(
            x: textX + (visual.minX - textBox.minX),
            y: textY - visualTopOutset,
            width: visual.width,
            height: visual.height
        )
        return (textBounds, collisionBounds, visualBounds)
    }

    static func loadPlaybackCues(
        from source: PlaybackSubtitleSource,
        isCancelled: () -> Bool = { false }
    ) throws -> [PlaybackSubtitleCue] {
        guard source.format == .srt else {
            throw SRTSubtitleRenderingError(
                errorDescription: "SRT renderer received a non-SRT source."
            )
        }
        try checkCancellation(isCancelled)
        let data = try PlaybackPerformanceProbe.measure(
            "SRTSubtitleRenderer.read",
            thresholdMilliseconds: 2
        ) {
            try WebDAVSubtitleCache.shared.readSubtitleData(from: source.url)
        }
        try checkCancellation(isCancelled)
        let entries = try PlaybackPerformanceProbe.measure(
            "SRTSubtitleRenderer.parse",
            thresholdMilliseconds: 2
        ) {
            try SRTParser.parseForRendering(
                data,
                format: SubtitleFormat(fileExtension: source.url.pathExtension) ?? .srt
            )
        }
        try checkCancellation(isCancelled)
        guard !entries.isEmpty else {
            throw SRTSubtitleRenderingError(
                errorDescription: "SRT renderer found no valid playback Cues."
            )
        }
        var cues: [PlaybackSubtitleCue] = []
        cues.reserveCapacity(entries.count)
        for (ordinal, entry) in entries.enumerated() {
            try checkCancellation(isCancelled)
            cues.append(PlaybackSubtitleCue(
                sourceOrdinal: ordinal,
                startMilliseconds: entry.startMilliseconds,
                endMilliseconds: entry.endMilliseconds,
                text: entry.text
            ))
        }
        return cues
    }

    static func image(
        layout: SRTSubtitleLayout,
        atMilliseconds milliseconds: Int
    ) -> CGImage? {
        let activeItems = layout.track
            .activeCues(atMilliseconds: milliseconds)
            .compactMap { layout.items[$0.sourceOrdinal] }
            .filter(\.isDrawable)
        guard !activeItems.isEmpty,
              let context = bitmapContext(size: layout.canvasSize)
        else {
            return nil
        }

        context.clip(to: CGRect(origin: .zero, size: layout.canvasSize))

        for item in activeItems {
            let bounds = item.visualBounds
            context.saveGState()
            context.translateBy(
                x: bounds.minX,
                y: layout.canvasSize.height - bounds.maxY
            )
            draw(item, metrics: layout.metrics, in: context)
            context.restoreGState()
        }

        return context.makeImage()
    }

    /// Shadow, then box or outline, then the text, as libass stacks them.
    private static func draw(
        _ item: SRTSubtitleItem,
        metrics: SRTSubtitleMetrics,
        in context: CGContext
    ) {
        let style = metrics.style
        let size = item.visualBounds.size
        let origin = item.textOrigin
        let paths = glyphPaths(lines: item.lines)
        let glyphs = paths.glyphs
        let boxes = boxPath(item.lineBoxes, borderType: style.borderType)

        if metrics.shadowOffset > 0 {
            drawLayer(
                in: context,
                size: size,
                origin: CGPoint(
                    x: origin.x + metrics.shadowOffset,
                    y: origin.y - metrics.shadowOffset
                ),
                opacity: style.shadowColor.alpha,
                blurSigma: metrics.blurSigma
            ) { layer in
                layer.setFillColor(style.shadowColor.opaqueCGColor)
                layer.setStrokeColor(style.shadowColor.opaqueCGColor)
                if style.borderType == .backgroundBox {
                    layer.addPath(boxes)
                    layer.fillPath()
                    return
                }
                layer.addPath(glyphs)
                layer.fillPath()
                if metrics.outlineWidth > 0 {
                    strokeOutline(glyphs, width: metrics.outlineWidth, in: layer)
                }
            }
        }

        if style.borderType != .outline {
            drawLayer(
                in: context,
                size: size,
                origin: origin,
                opacity: style.backgroundColor.alpha,
                blurSigma: 0
            ) { layer in
                layer.setFillColor(style.backgroundColor.opaqueCGColor)
                layer.addPath(boxes)
                layer.fillPath()
            }
        }

        if metrics.outlineWidth > 0 {
            drawLayer(
                in: context,
                size: size,
                origin: origin,
                opacity: style.outlineColor.alpha,
                blurSigma: metrics.blurSigma
            ) { layer in
                layer.setFillColor(style.outlineColor.opaqueCGColor)
                layer.setStrokeColor(style.outlineColor.opaqueCGColor)
                layer.addPath(glyphs)
                layer.fillPath()
                strokeOutline(glyphs, width: metrics.outlineWidth, in: layer)
            }
        }

        drawLayer(
            in: context,
            size: size,
            origin: origin,
            opacity: 1,
            blurSigma: metrics.blursOutline ? 0 : metrics.blurSigma
        ) { layer in
            for run in paths.runs {
                layer.setFillColor(run.color)
                layer.addPath(run.path)
                layer.fillPath()
            }
        }
    }

    /// Draws one part of a cue on its own so its opacity applies once to the
    /// whole part, blurring it first when asked. `origin` places the text
    /// box inside the item.
    private static func drawLayer(
        in context: CGContext,
        size: CGSize,
        origin: CGPoint,
        opacity: Double,
        blurSigma: CGFloat,
        _ draw: (CGContext) -> Void
    ) {
        guard opacity > 0 else {
            return
        }
        context.saveGState()
        defer {
            context.restoreGState()
        }
        context.setAlpha(CGFloat(opacity))

        if blurSigma > 0,
           let layer = bitmapContext(size: CGSize(
               width: ceil(size.width),
               height: ceil(size.height)
           )) {
            layer.translateBy(x: origin.x, y: origin.y)
            draw(layer)
            guard let image = layer.makeImage(),
                  let blurred = blurredImage(image, sigma: blurSigma)
            else {
                return
            }
            context.draw(
                blurred,
                in: CGRect(x: 0, y: 0, width: blurred.width, height: blurred.height)
            )
            return
        }

        context.beginTransparencyLayer(auxiliaryInfo: nil)
        context.translateBy(x: origin.x, y: origin.y)
        draw(context)
        context.endTransparencyLayer()
    }

    // A Core Image context is safe to share between threads.
    nonisolated(unsafe) private static let blurContext = CIContext(
        options: [.cacheIntermediates: false]
    )

    private static func blurredImage(_ image: CGImage, sigma: CGFloat) -> CGImage? {
        let input = CIImage(cgImage: image)
        let output = input
            .clampedToExtent()
            .applyingGaussianBlur(sigma: Double(sigma))
            .cropped(to: input.extent)
        return blurContext.createCGImage(
            output,
            from: input.extent,
            format: .RGBA8,
            colorSpace: CGColorSpace(name: CGColorSpace.sRGB)
        )
    }

    private static func strokeOutline(
        _ glyphs: CGPath,
        width: CGFloat,
        in context: CGContext
    ) {
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.setLineWidth(2 * width)
        context.addPath(glyphs)
        context.strokePath()
    }

    private static func boxPath(
        _ lineBoxes: [CGRect],
        borderType: SRTSubtitleStyle.BorderType
    ) -> CGPath {
        let path = CGMutablePath()
        switch borderType {
        case .outline:
            break
        case .backgroundBox:
            if let first = lineBoxes.first {
                path.addRect(lineBoxes.dropFirst().reduce(first) { $0.union($1) })
            }
        }
        return path
    }

    private struct LineMetrics {
        let line: CTLine
        let width: CGFloat
        let ascent: CGFloat
        let descent: CGFloat
        let extraInkOutset: CGFloat
        let underlineBottom: CGFloat
    }

    private static func measure(
        text: String,
        metrics: SRTSubtitleMetrics,
        fonts: inout SRTFontCache,
        maximumWidth: CGFloat
    ) -> SRTMeasuredText? {
        let attributedText = SRTInlineText.attributedString(
            from: text,
            metrics: metrics,
            fonts: &fonts
        )
        guard attributedText.length > 0 else {
            return nil
        }

        let fullString = attributedText.string as NSString
        let typesetter = CTTypesetterCreateWithAttributedString(attributedText)
        var measuredLines: [LineMetrics] = []
        var paragraphStart = 0

        while paragraphStart <= fullString.length {
            let searchRange = NSRange(
                location: paragraphStart,
                length: fullString.length - paragraphStart
            )
            let newlineRange = fullString.range(of: "\n", options: [], range: searchRange)
            let paragraphEnd = newlineRange.location == NSNotFound
                ? fullString.length
                : newlineRange.location
            let paragraphRange = CFRange(
                location: paragraphStart,
                length: paragraphEnd - paragraphStart
            )
            if paragraphRange.length > 0 {
                for lineRange in wrappedLineRanges(
                    in: paragraphRange,
                    typesetter: typesetter,
                    maximumWidth: maximumWidth,
                    letterSpacing: metrics.letterSpacing
                ) {
                    let line = CTTypesetterCreateLine(typesetter, lineRange)
                    measuredLines.append(measureLine(line, metrics: metrics))
                }
            }
            if newlineRange.location == NSNotFound {
                break
            }
            paragraphStart = newlineRange.location + newlineRange.length
        }

        let maxLineWidth = measuredLines.map(\.width).max() ?? 0
        guard !measuredLines.isEmpty, maxLineWidth > 0 else {
            return nil
        }

        let blockWidth = max(1, maxLineWidth)
        let blockHeight = max(
            1,
            measuredLines.reduce(0) { $0 + $1.ascent + $1.descent }
                + CGFloat(max(0, measuredLines.count - 1)) * metrics.lineSpacing
        )
        let textBox = CGRect(x: 0, y: 0, width: blockWidth, height: blockHeight)

        var positionedLines: [SRTPositionedLine] = []
        positionedLines.reserveCapacity(measuredLines.count)
        var lineBoxes: [CGRect] = []
        var ink = textBox
        var topY = blockHeight

        for measured in measuredLines {
            let originX: CGFloat
            switch metrics.style.horizontalAlignment {
            case .left:
                originX = 0
            case .center:
                originX = (blockWidth - measured.width) / 2
            case .right:
                originX = blockWidth - measured.width
            }
            let lineHeight = measured.ascent + measured.descent
            let bottomY = topY - lineHeight
            let origin = CGPoint(x: originX, y: bottomY + measured.descent)
            let lineRect = CGRect(
                x: originX,
                y: bottomY,
                width: measured.width,
                height: lineHeight
            )
            positionedLines.append(SRTPositionedLine(
                line: measured.line,
                origin: origin,
                width: measured.width
            ))

            let imageBounds = CTLineGetImageBounds(measured.line, nil)
            if !imageBounds.isNull, !imageBounds.isEmpty {
                ink = ink.union(
                    imageBounds
                        .offsetBy(dx: origin.x, dy: origin.y)
                        .insetBy(dx: -measured.extraInkOutset, dy: -measured.extraInkOutset)
                )
            }
            if measured.underlineBottom < 0, measured.width > 0 {
                let underlineY = origin.y + measured.underlineBottom
                ink = ink.union(CGRect(
                    x: originX,
                    y: underlineY,
                    width: measured.width,
                    height: max(1, origin.y - underlineY)
                ))
            }
            if measured.width > 0 {
                lineBoxes.append(
                    lineRect.insetBy(dx: -metrics.boxPadding, dy: -metrics.boxPadding)
                )
            }
            topY = bottomY - metrics.lineSpacing
        }

        var collision = textBox.insetBy(dx: -metrics.outlineWidth, dy: -metrics.outlineWidth)
        var visualContent = ink.insetBy(dx: -metrics.outlineWidth, dy: -metrics.outlineWidth)
        switch metrics.style.borderType {
        case .outline:
            break
        case .backgroundBox:
            collision = lineBoxes.reduce(collision) { $0.union($1) }
            visualContent = lineBoxes.reduce(visualContent) { $0.union($1) }
        }
        let visual = visualContent
            .union(visualContent.offsetBy(dx: metrics.shadowOffset, dy: -metrics.shadowOffset))
            .insetBy(dx: -metrics.blurExtent, dy: -metrics.blurExtent)

        return SRTMeasuredText(
            lines: positionedLines,
            lineBoxes: lineBoxes,
            textBox: textBox,
            collision: collision,
            visual: visual
        )
    }

    private static func measureLine(
        _ line: CTLine,
        metrics: SRTSubtitleMetrics
    ) -> LineMetrics {
        let width = visibleLineWidth(line, letterSpacing: metrics.letterSpacing)
        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        var extraInkOutset: CGFloat = 0
        var underlineBottom: CGFloat = 0

        for run in CTLineGetGlyphRuns(line) as! [CTRun] {
            let attributes = CTRunGetAttributes(run) as NSDictionary
            if let runAscent = attributes[SRTInlineText.ascentKey] as? CGFloat {
                ascent = max(ascent, runAscent)
            }
            if let runDescent = attributes[SRTInlineText.descentKey] as? CGFloat {
                descent = max(descent, runDescent)
            }
            if let boldWidth = attributes[SRTInlineText.syntheticBoldWidthKey] as? CGFloat {
                extraInkOutset = max(extraInkOutset, boldWidth)
            }
            if (attributes[SRTInlineText.underlineKey] as? Bool) == true,
               let fontValue = attributes[kCTFontAttributeName] {
                let font = fontValue as! CTFont
                let pos = CTFontGetUnderlinePosition(font)
                let thick = max(1, CTFontGetUnderlineThickness(font))
                underlineBottom = min(underlineBottom, pos - thick)
            }
        }
        if ascent + descent <= 0 {
            var ctAscent: CGFloat = 0
            var ctDescent: CGFloat = 0
            _ = CTLineGetTypographicBounds(line, &ctAscent, &ctDescent, nil)
            let total = max(1, ctAscent + ctDescent)
            ascent = metrics.lineHeight * (ctAscent / total)
            descent = metrics.lineHeight - ascent
        }
        return LineMetrics(
            line: line,
            width: width,
            ascent: ascent,
            descent: descent,
            extraInkOutset: extraInkOutset,
            underlineBottom: underlineBottom
        )
    }

    private static func visibleLineWidth(
        _ line: CTLine,
        letterSpacing: CGFloat
    ) -> CGFloat {
        let rawWidth = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
        let trailingWhitespace = CGFloat(CTLineGetTrailingWhitespaceWidth(line))
        let visibleRaw = max(0, rawWidth - trailingWhitespace)
        guard visibleRaw > 0 else {
            return 0
        }
        return max(0, visibleRaw - letterSpacing)
    }

    /// Wraps a single paragraph with balanced line lengths (libass WrapStyle 0).
    private static func wrappedLineRanges(
        in paragraphRange: CFRange,
        typesetter: CTTypesetter,
        maximumWidth: CGFloat,
        letterSpacing: CGFloat
    ) -> [CFRange] {
        let breakWidthLimit = max(1, maximumWidth + max(0, letterSpacing))
        let greedy = greedyLineRanges(
            in: paragraphRange,
            typesetter: typesetter,
            widthLimit: breakWidthLimit
        )
        guard greedy.count > 1 else {
            return greedy
        }

        let targetLineCount = greedy.count
        var low = max(1, breakWidthLimit / CGFloat(targetLineCount + 1))
        var high = breakWidthLimit
        var balanced = greedy
        for _ in 0..<14 {
            let mid = (low + high) / 2
            let candidate = greedyLineRanges(
                in: paragraphRange,
                typesetter: typesetter,
                widthLimit: mid
            )
            if candidate.count <= targetLineCount {
                balanced = candidate
                high = mid
            } else {
                low = mid
            }
        }

        // For a 2-line wrap, compare the tightest break (`line1 <= line2`) with
        // the next break (`line1 >= line2`), preferring the closer pair and
        // breaking ties with the wider top line as libass WrapStyle 0 does.
        if balanced.count == 2,
           balanced[0].length < greedy[0].length {
            let minFirstLength = balanced[0].length
            var nextLow = high
            var nextHigh = breakWidthLimit
            var nextFirstLength = greedy[0].length
            for _ in 0..<12 {
                let mid = (nextLow + nextHigh) / 2
                let count = CTTypesetterSuggestLineBreak(
                    typesetter,
                    paragraphRange.location,
                    Double(mid)
                )
                if count > minFirstLength {
                    nextFirstLength = min(count, paragraphRange.length)
                    nextHigh = mid
                } else {
                    nextLow = mid
                }
            }
            if nextFirstLength > minFirstLength,
               nextFirstLength < paragraphRange.length {
                let widerTop = [
                    CFRange(location: paragraphRange.location, length: nextFirstLength),
                    CFRange(
                        location: paragraphRange.location + nextFirstLength,
                        length: paragraphRange.length - nextFirstLength
                    )
                ]
                let balancedDiff = twoLineWidthDifference(
                    balanced,
                    typesetter: typesetter,
                    letterSpacing: letterSpacing
                )
                let widerTopDiff = twoLineWidthDifference(
                    widerTop,
                    typesetter: typesetter,
                    letterSpacing: letterSpacing
                )
                if widerTopDiff <= balancedDiff + 0.5 {
                    return widerTop
                }
            }
        }

        return balanced
    }

    private static func greedyLineRanges(
        in range: CFRange,
        typesetter: CTTypesetter,
        widthLimit: CGFloat
    ) -> [CFRange] {
        var result: [CFRange] = []
        var start = range.location
        let end = range.location + range.length
        while start < end {
            let count = max(
                1,
                CTTypesetterSuggestLineBreak(typesetter, start, Double(widthLimit))
            )
            let length = min(count, end - start)
            result.append(CFRange(location: start, length: length))
            start += length
        }
        return result
    }

    private static func twoLineWidthDifference(
        _ ranges: [CFRange],
        typesetter: CTTypesetter,
        letterSpacing: CGFloat
    ) -> CGFloat {
        guard ranges.count == 2 else {
            return .greatestFiniteMagnitude
        }
        let line0 = CTTypesetterCreateLine(typesetter, ranges[0])
        let line1 = CTTypesetterCreateLine(typesetter, ranges[1])
        let w0 = visibleLineWidth(line0, letterSpacing: letterSpacing)
        let w1 = visibleLineWidth(line1, letterSpacing: letterSpacing)
        return abs(w0 - w1)
    }

    private struct ColoredGlyphRun {
        let color: CGColor
        let path: CGPath
    }

    /// Builds normalized, synthetic-bold-widened, and underlined glyph paths for
    /// all runs so text fill, outline, blur, and shadow share identical geometry.
    private static func glyphPaths(
        lines: [SRTPositionedLine]
    ) -> (glyphs: CGPath, runs: [ColoredGlyphRun]) {
        let combined = CGMutablePath()
        var coloredRuns: [ColoredGlyphRun] = []

        for positioned in lines {
            let line = positioned.line
            let lineOrigin = positioned.origin
            let lineWidth = positioned.width
            for run in CTLineGetGlyphRuns(line) as! [CTRun] {
                let attributes = CTRunGetAttributes(run) as NSDictionary
                guard let fontValue = attributes[kCTFontAttributeName] else {
                    continue
                }
                let font = fontValue as! CTFont
                let rawPath = CGMutablePath()
                let count = CTRunGetGlyphCount(run)
                if count > 0 {
                    var glyphs = Array(repeating: CGGlyph(), count: count)
                    var positions = Array(repeating: CGPoint.zero, count: count)
                    CTRunGetGlyphs(run, CFRange(location: 0, length: 0), &glyphs)
                    CTRunGetPositions(run, CFRange(location: 0, length: 0), &positions)
                    for (glyph, position) in zip(glyphs, positions) {
                        var transform = CGAffineTransform(
                            translationX: lineOrigin.x + position.x,
                            y: lineOrigin.y + position.y
                        )
                        if let glyphPath = CTFontCreatePathForGlyph(font, glyph, &transform) {
                            rawPath.addPath(glyphPath)
                        }
                    }
                }

                var runPath: CGPath = rawPath.isEmpty
                    ? rawPath
                    : rawPath.normalized(using: .winding)

                if let boldWidth = attributes[SRTInlineText.syntheticBoldWidthKey] as? CGFloat,
                   boldWidth > 0,
                   !runPath.isEmpty {
                    let widened = runPath.copy(
                        strokingWithWidth: boldWidth,
                        lineCap: .round,
                        lineJoin: .round,
                        miterLimit: 2
                    )
                    runPath = runPath.union(widened, using: .winding)
                }

                if (attributes[SRTInlineText.underlineKey] as? Bool) == true {
                    let runRange = CTRunGetStringRange(run)
                    let startX = CTLineGetOffsetForStringIndex(line, runRange.location, nil)
                    let rawRunWidth = CGFloat(
                        CTRunGetTypographicBounds(
                            run,
                            CFRange(location: 0, length: 0),
                            nil,
                            nil,
                            nil
                        )
                    )
                    let endX = min(lineWidth, startX + rawRunWidth)
                    let underlineWidth = max(0, endX - startX)
                    if underlineWidth > 0 {
                        let thickness = max(1, CTFontGetUnderlineThickness(font))
                        let position = CTFontGetUnderlinePosition(font)
                        let rect = CGRect(
                            x: lineOrigin.x + startX,
                            y: lineOrigin.y + position - thickness / 2,
                            width: underlineWidth,
                            height: thickness
                        )
                        let underlinePath = CGPath(rect: rect, transform: nil)
                        runPath = runPath.isEmpty
                            ? underlinePath
                            : runPath.union(underlinePath, using: .winding)
                    }
                }

                guard !runPath.isEmpty else {
                    continue
                }
                combined.addPath(runPath)
                let color = (attributes[NSAttributedString.Key.foregroundColor] as? NSColor)?
                    .cgColor ?? NSColor.white.cgColor
                coloredRuns.append(ColoredGlyphRun(color: color, path: runPath))
            }
        }

        let normalizedGlyphs: CGPath = combined.isEmpty
            ? combined
            : combined.normalized(using: .winding)
        return (normalizedGlyphs, coloredRuns)
    }

    private static func checkCancellation(
        _ isCancelled: () -> Bool
    ) throws {
        if isCancelled() {
            throw CancellationError()
        }
    }

    private static func bitmapContext(size: CGSize) -> CGContext? {
        let width = Int(size.width.rounded())
        let height = Int(size.height.rounded())
        guard width > 1, height > 1 else {
            return nil
        }
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(
                rawValue: CGImageAlphaInfo.premultipliedLast.rawValue
                    | CGBitmapInfo.byteOrder32Big.rawValue
            ).rawValue
        )
        context?.setShouldAntialias(true)
        context?.setShouldSmoothFonts(false)
        context?.setAllowsFontSmoothing(false)
        return context
    }

}

extension SRTSubtitleStyle.Color {
    var nsColor: NSColor {
        NSColor(
            srgbRed: CGFloat(red),
            green: CGFloat(green),
            blue: CGFloat(blue),
            alpha: CGFloat(alpha)
        )
    }

    /// The color at full opacity; the layer it is drawn in carries the alpha.
    var opaqueCGColor: CGColor {
        CGColor(
            srgbRed: CGFloat(red),
            green: CGFloat(green),
            blue: CGFloat(blue),
            alpha: 1
        )
    }
}
