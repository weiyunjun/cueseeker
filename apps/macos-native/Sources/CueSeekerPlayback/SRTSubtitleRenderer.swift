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

    func activePlacements(atMilliseconds milliseconds: Int) -> [CGRect] {
        track.activeCues(atMilliseconds: milliseconds).compactMap {
            guard let item = items[$0.sourceOrdinal], item.isDrawable else {
                return nil
            }
            return item.visualBounds
        }
    }
}

struct SRTSubtitleItem {
    let cue: PlaybackSubtitleCue
    let frame: CTFrame
    /// Where the text frame's origin sits in the item, measured up from the
    /// item's bottom-left corner.
    let textOrigin: CGPoint
    /// Each line's box, padding included, in text frame coordinates.
    let lineBoxes: [CGRect]
    let visualBounds: CGRect
    let isDrawable: Bool
}

/// A cue's text laid out, and the extent of everything drawn for it.
private struct SRTMeasuredText {
    let frame: CTFrame
    let lineBoxes: [CGRect]
    /// The text with its outline or boxes, in text frame coordinates. Margins
    /// and alignment place this rectangle.
    let content: CGRect
    /// The content with its shadow and blur, in text frame coordinates.
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
        let decoration = max(metrics.outlineWidth, metrics.boxPadding) + metrics.blurExtent
        let maximumTextWidth = max(
            1,
            canvasSize.width - 2 * (metrics.marginX + decoration) - metrics.shadowOffset
        )
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

            let bounds = placement(
                of: measured,
                below: activeItems,
                canvasSize: canvasSize,
                metrics: metrics
            )
            let drawable: Bool
            switch style.verticalAlignment {
            case .top:
                drawable = bounds.maxY <= canvasSize.height || bounds.height > canvasSize.height
            case .center, .bottom:
                drawable = bounds.minY >= 0 || bounds.height > canvasSize.height
            }
            let item = SRTSubtitleItem(
                cue: cue,
                frame: measured.frame,
                textOrigin: CGPoint(x: -measured.visual.minX, y: -measured.visual.minY),
                lineBoxes: measured.lineBoxes,
                visualBounds: bounds,
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

    /// The first cue sits at its margins, or in the middle for Center; each
    /// later cue stacks on the cues still showing, upward for Bottom and
    /// Center and downward for Top.
    private static func placement(
        of measured: SRTMeasuredText,
        below activeItems: [SRTSubtitleItem],
        canvasSize: CGSize,
        metrics: SRTSubtitleMetrics
    ) -> CGRect {
        let visual = measured.visual
        let content = measured.content
        // The content's edges inside the item, x rightward and y downward.
        let contentLeft = content.minX - visual.minX
        let contentTop = visual.maxY - content.maxY

        let x: CGFloat
        switch metrics.style.horizontalAlignment {
        case .left:
            x = metrics.marginX - contentLeft
        case .center:
            x = (canvasSize.width - content.width) / 2 - contentLeft
        case .right:
            x = canvasSize.width - metrics.marginX - content.width - contentLeft
        }

        let y: CGFloat
        switch metrics.style.verticalAlignment {
        case .top:
            y = activeItems.map(\.visualBounds.maxY).max()
                ?? metrics.marginY - contentTop
        case .center:
            y = activeItems.map(\.visualBounds.minY).min().map { $0 - visual.height }
                ?? (canvasSize.height - content.height) / 2 - contentTop
        case .bottom:
            y = activeItems.map(\.visualBounds.minY).min().map { $0 - visual.height }
                ?? canvasSize.height - metrics.marginY - content.height - contentTop
        }

        return CGRect(x: x, y: y, width: visual.width, height: visual.height)
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
        let glyphs = glyphPath(frame: item.frame)
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
                layer.setStrokeColor(style.outlineColor.opaqueCGColor)
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
            layer.textMatrix = .identity
            CTFrameDraw(item.frame, layer)
            strokeSyntheticBold(frame: item.frame, in: layer)
        }
    }

    /// Draws one part of a cue on its own so its opacity applies once to the
    /// whole part, blurring it first when asked. `origin` places the text
    /// frame inside the item.
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
        context.setLineJoin(.round)
        context.setLineWidth(2 * width)
        context.addPath(glyphs)
        context.strokePath()
    }

    /// Widens the runs whose font has no bold face, as libass does.
    private static func strokeSyntheticBold(frame: CTFrame, in context: CGContext) {
        forEachRun(of: frame) { run, lineOrigin in
            let attributes = CTRunGetAttributes(run) as NSDictionary
            guard let width = attributes[SRTInlineText.syntheticBoldWidthKey] as? CGFloat,
                  let color = attributes[NSAttributedString.Key.foregroundColor] as? NSColor
            else {
                return
            }
            let path = CGMutablePath()
            addGlyphs(of: run, lineOrigin: lineOrigin, to: path)
            context.setStrokeColor(color.cgColor)
            context.setLineJoin(.round)
            context.setLineWidth(width)
            context.addPath(path)
            context.strokePath()
        }
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

        let range = CFRange(location: 0, length: attributedText.length)
        let framesetter = CTFramesetterCreateWithAttributedString(attributedText)
        let suggested = CTFramesetterSuggestFrameSizeWithConstraints(
            framesetter,
            range,
            nil,
            CGSize(width: maximumWidth, height: 1_000_000),
            nil
        )
        let textRect = CGRect(
            x: 0,
            y: 0,
            width: min(maximumWidth, max(1, ceil(suggested.width))),
            height: max(1, ceil(suggested.height))
        )
        let frame = CTFramesetterCreateFrame(
            framesetter,
            range,
            CGPath(rect: textRect, transform: nil),
            nil
        )

        // The text spans each line's ascent and descent: some faces make
        // CoreText's frame taller than that, and the size is only ascent plus
        // descent. Glyphs can reach past those lines, a slanted face most of
        // all, so the ink counts too.
        var ink = CGRect.null
        var lineBoxes: [CGRect] = []
        let lines = CTFrameGetLines(frame) as! [CTLine]
        var origins = Array(repeating: CGPoint.zero, count: lines.count)
        CTFrameGetLineOrigins(frame, CFRange(location: 0, length: 0), &origins)
        for (line, origin) in zip(lines, origins) {
            var ascent: CGFloat = 0
            var descent: CGFloat = 0
            let width = CGFloat(CTLineGetTypographicBounds(line, &ascent, &descent, nil))
                - CGFloat(CTLineGetTrailingWhitespaceWidth(line))
            let lineRect = CGRect(
                x: origin.x,
                y: origin.y - descent,
                width: max(0, width),
                height: ascent + descent
            )
            ink = ink.union(lineRect)
            let imageBounds = CTLineGetImageBounds(line, nil)
            if !imageBounds.isNull, !imageBounds.isEmpty {
                ink = ink.union(imageBounds.offsetBy(dx: origin.x, dy: origin.y))
            }
            guard width > 0 else {
                continue
            }
            lineBoxes.append(
                lineRect.insetBy(dx: -metrics.boxPadding, dy: -metrics.boxPadding)
            )
        }
        if ink.isNull {
            ink = textRect
        }

        var content = ink.insetBy(dx: -metrics.outlineWidth, dy: -metrics.outlineWidth)
        switch metrics.style.borderType {
        case .outline:
            break
        case .backgroundBox:
            content = lineBoxes.reduce(content) { $0.union($1) }
        }
        let visual = content
            .union(content.offsetBy(dx: metrics.shadowOffset, dy: -metrics.shadowOffset))
            .insetBy(dx: -metrics.blurExtent, dy: -metrics.blurExtent)

        return SRTMeasuredText(
            frame: frame,
            lineBoxes: lineBoxes,
            content: content,
            visual: visual
        )
    }

    private static func glyphPath(frame: CTFrame) -> CGPath {
        let path = CGMutablePath()
        forEachRun(of: frame) { run, lineOrigin in
            addGlyphs(of: run, lineOrigin: lineOrigin, to: path)
        }
        return path
    }

    private static func forEachRun(
        of frame: CTFrame,
        _ body: (CTRun, CGPoint) -> Void
    ) {
        let lines = CTFrameGetLines(frame) as! [CTLine]
        var origins = Array(repeating: CGPoint.zero, count: lines.count)
        CTFrameGetLineOrigins(frame, CFRange(location: 0, length: 0), &origins)
        for (line, origin) in zip(lines, origins) {
            for run in CTLineGetGlyphRuns(line) as! [CTRun] {
                body(run, origin)
            }
        }
    }

    private static func addGlyphs(
        of run: CTRun,
        lineOrigin: CGPoint,
        to path: CGMutablePath
    ) {
        let attributes = CTRunGetAttributes(run) as NSDictionary
        guard let fontValue = attributes[kCTFontAttributeName] else {
            return
        }
        let font = fontValue as! CTFont
        let count = CTRunGetGlyphCount(run)
        var glyphs = Array(repeating: CGGlyph(), count: count)
        var positions = Array(repeating: CGPoint.zero, count: count)
        CTRunGetGlyphs(run, CFRange(location: 0, length: 0), &glyphs)
        CTRunGetPositions(run, CFRange(location: 0, length: 0), &positions)
        for (glyph, position) in zip(glyphs, positions) {
            // The font's own matrix, a synthetic slant included, is applied by
            // the glyph path itself.
            var transform = CGAffineTransform(
                translationX: lineOrigin.x + position.x,
                y: lineOrigin.y + position.y
            )
            if let glyphPath = CTFontCreatePathForGlyph(font, glyph, &transform) {
                path.addPath(glyphPath)
            }
        }
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
        context?.setShouldSmoothFonts(true)
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
