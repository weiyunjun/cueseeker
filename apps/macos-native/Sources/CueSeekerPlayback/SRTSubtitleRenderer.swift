import AppKit
import CoreImage
import CoreText
import CueSeekerCore
import Foundation
import QuartzCore

final class SRTSubtitleLayout: @unchecked Sendable {
    fileprivate let canvasSize: CGSize
    fileprivate let metrics: SRTSubtitleMetrics
    fileprivate let track: PlaybackSubtitleTrack
    fileprivate let items: [Int: SRTSubtitleItem]

    fileprivate init(
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

private struct SRTSubtitleItem {
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
private struct SRTSubtitleMetrics {
    let style: SRTSubtitleStyle
    let baseFont: CTFont
    let lineHeight: CGFloat
    let letterSpacing: CGFloat
    let lineSpacing: CGFloat
    /// Zero for Opaque Box, which draws no outline.
    let outlineWidth: CGFloat
    /// Zero for Outline, which draws no box.
    let boxPadding: CGFloat
    let blurSigma: CGFloat
    /// Zero for Background Box, which draws no shadow.
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
        outlineWidth = style.borderType == .opaqueBox
            ? 0
            : CGFloat(style.outlineWidth) * scale
        boxPadding = style.borderType == .outline
            ? 0
            : CGFloat(SRTSubtitleStyle.boxPadding) * scale
        // libass takes its blur value to a Gaussian deviation this way.
        blurSigma = CGFloat(style.blur) * scale * 2 / sqrt(log(256))
        shadowOffset = style.borderType == .backgroundBox
            ? 0
            : CGFloat(style.shadowOffset) * scale
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
        return CTFontCopyPostScriptName(font) as String == name ? font : systemFont
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
            try SRTParser.parseForRendering(data)
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
                if style.borderType == .opaqueBox {
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
        case .opaqueBox:
            path.addRects(lineBoxes)
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
        case .opaqueBox, .backgroundBox:
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

private extension SRTSubtitleStyle.Color {
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

/// Fonts for one layout, each sized so its ascent plus descent is the line
/// height, as libass sizes every face it uses.
private struct SRTFontCache {
    let lineHeight: CGFloat
    private var fonts: [String: (font: CTFont, syntheticBoldWidth: CGFloat)] = [:]

    init(lineHeight: CGFloat) {
        self.lineHeight = lineHeight
    }

    /// The face in the wanted bold and italic, falling back to libass's
    /// synthetic slant and widening when the family has no such face.
    mutating func font(
        for face: CTFont,
        bold: Bool,
        italic: Bool
    ) -> (font: CTFont, syntheticBoldWidth: CGFloat) {
        let key = "\(CTFontCopyPostScriptName(face))|\(bold)|\(italic)"
        if let cached = fonts[key] {
            return cached
        }

        var font = face
        var needsSyntheticBold = bold
        var needsSyntheticItalic = italic
        if bold, let boldFont = CTFontCreateCopyWithSymbolicTraits(
            font, 0, nil, .traitBold, .traitBold
        ) {
            font = boldFont
            needsSyntheticBold = false
        }
        if italic, let italicFont = CTFontCreateCopyWithSymbolicTraits(
            font, 0, nil, .traitItalic, .traitItalic
        ) {
            font = italicFont
            needsSyntheticItalic = false
        }

        let unitHeight = (CTFontGetAscent(font) + CTFontGetDescent(font)) / CTFontGetSize(font)
        let pointSize = unitHeight > 0 ? lineHeight / unitHeight : lineHeight
        if needsSyntheticItalic {
            var slant = CGAffineTransform(
                a: 1,
                b: 0,
                c: Self.syntheticSlant(for: font),
                d: 1,
                tx: 0,
                ty: 0
            )
            font = CTFontCreateCopyWithAttributes(font, pointSize, &slant, nil)
        } else {
            font = CTFontCreateCopyWithAttributes(font, pointSize, nil, nil)
        }

        // libass widens a synthetic bold outline by a 64th of the size.
        let resolved = (
            font: font,
            syntheticBoldWidth: needsSyntheticBold ? pointSize / 64 : 0
        )
        fonts[key] = resolved
        return resolved
    }

    /// libass slants PostScript outlines by 10° and TrueType ones by GDI's
    /// 18.77°.
    private static func syntheticSlant(for font: CTFont) -> CGFloat {
        let format = (CTFontCopyAttribute(font, kCTFontFormatAttribute) as? NSNumber)?
            .uint32Value
        let isPostScript = format == CTFontFormat.openTypePostScript.rawValue
            || format == CTFontFormat.postScript.rawValue
        return isPostScript ? 0x2D24 / 65536 : 0x5700 / 65536
    }
}

private enum SRTInlineText {
    static let syntheticBoldWidthKey = NSAttributedString.Key("CueSeekerSRTSyntheticBoldWidth")

    private struct Style {
        var bold = 0
        var italic = 0
        var underline = 0
        var colors: [NSColor]
    }

    static func attributedString(
        from source: String,
        metrics: SRTSubtitleMetrics,
        fonts: inout SRTFontCache
    ) -> NSAttributedString {
        let output = NSMutableAttributedString()
        let paragraph = NSMutableParagraphStyle()
        switch metrics.style.horizontalAlignment {
        case .left:
            paragraph.alignment = .left
        case .center:
            paragraph.alignment = .center
        case .right:
            paragraph.alignment = .right
        }
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.lineSpacing = metrics.lineSpacing
        let textColor = metrics.style.textColor.nsColor
        var style = Style(colors: [textColor])
        var index = source.startIndex
        var bufferedText = ""

        func flushBufferedText() {
            guard !bufferedText.isEmpty else { return }
            append(
                bufferedText,
                style: style,
                paragraph: paragraph,
                metrics: metrics,
                fonts: &fonts,
                to: output
            )
            bufferedText.removeAll(keepingCapacity: true)
        }

        while index < source.endIndex {
            if source[index] == "<",
               let close = source[index...].firstIndex(of: ">") {
                let token = String(source[index...close])
                flushBufferedText()
                if apply(tag: token, to: &style, textColor: textColor) {
                    index = source.index(after: close)
                    continue
                }
                if token.dropFirst().dropLast().allSatisfy({
                    $0.isLetter || $0.isNumber || $0.isWhitespace
                        || "/=\"'#".contains($0)
                }) {
                    index = source.index(after: close)
                    continue
                }
            }

            if source[index] == "{",
               let close = source[index...].firstIndex(of: "}") {
                let token = source[index...close].lowercased()
                if token.contains("\\an") || token.contains("\\pos")
                    || token.contains("\\move") {
                    index = source.index(after: close)
                    continue
                }
            }

            if source[index] == "&",
               let decoded = decodeEntity(in: source, at: index) {
                bufferedText.append(contentsOf: decoded.value)
                index = decoded.endIndex
                continue
            }

            bufferedText.append(source[index])
            index = source.index(after: index)
        }

        flushBufferedText()
        return output
    }

    private static func apply(
        tag: String,
        to style: inout Style,
        textColor: NSColor
    ) -> Bool {
        let token = tag.lowercased()
        switch token {
        case "<b>": style.bold += 1
        case "</b>": style.bold = max(0, style.bold - 1)
        case "<i>": style.italic += 1
        case "</i>": style.italic = max(0, style.italic - 1)
        case "<u>": style.underline += 1
        case "</u>": style.underline = max(0, style.underline - 1)
        case "</font>":
            if style.colors.count > 1 {
                style.colors.removeLast()
            }
        default:
            guard token.hasPrefix("<font"),
                  let range = token.range(of: "color"),
                  let equals = token[range.upperBound...].firstIndex(of: "=")
            else {
                return false
            }
            let value = token[token.index(after: equals)...]
                .trimmingCharacters(in: CharacterSet(charactersIn: " \t\"'>"))
            style.colors.append(color(String(value)) ?? style.colors.last ?? textColor)
        }
        return true
    }

    /// Appends the text run by run, each run in the face that has its
    /// characters.
    private static func append(
        _ text: String,
        style: Style,
        paragraph: NSParagraphStyle,
        metrics: SRTSubtitleMetrics,
        fonts: inout SRTFontCache,
        to output: NSMutableAttributedString
    ) {
        let bold = metrics.style.isBold || style.bold > 0
        let italic = metrics.style.isItalic || style.italic > 0
        let characters = text as NSString
        for (range, face) in faceRuns(in: characters, baseFont: metrics.baseFont) {
            let resolved = fonts.font(for: face, bold: bold, italic: italic)
            var attributes: [NSAttributedString.Key: Any] = [
                .font: resolved.font,
                .foregroundColor: style.colors.last ?? metrics.style.textColor.nsColor,
                .paragraphStyle: paragraph
            ]
            if metrics.letterSpacing != 0 {
                attributes[.kern] = metrics.letterSpacing
            }
            if style.underline > 0 {
                attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
            }
            if resolved.syntheticBoldWidth > 0 {
                attributes[syntheticBoldWidthKey] = resolved.syntheticBoldWidth
            }
            output.append(NSAttributedString(
                string: characters.substring(with: range),
                attributes: attributes
            ))
        }
    }

    /// Splits the text where the covering face changes: the base font where
    /// it has the characters, the system's fallback otherwise. Spaces and line
    /// breaks stay with the run before them.
    private static func faceRuns(
        in characters: NSString,
        baseFont: CTFont
    ) -> [(NSRange, CTFont)] {
        var runs: [(NSRange, CTFont)] = []
        var fallbackFont: CTFont?
        var index = 0
        while index < characters.length {
            let range = characters.rangeOfComposedCharacterSequence(at: index)
            let face: CTFont
            if let current = runs.last?.1,
               let scalar = UnicodeScalar(characters.character(at: range.location)),
               CharacterSet.whitespacesAndNewlines.contains(scalar) {
                face = current
            } else if covers(baseFont, characters, range) {
                face = baseFont
            } else if let fallbackFont, covers(fallbackFont, characters, range) {
                face = fallbackFont
            } else {
                let found = CTFontCreateForString(
                    baseFont,
                    characters,
                    CFRange(location: range.location, length: range.length)
                )
                fallbackFont = found
                face = found
            }

            if let last = runs.last, CFEqual(last.1, face) {
                runs[runs.count - 1].0.length += range.length
            } else {
                runs.append((range, face))
            }
            index = NSMaxRange(range)
        }
        return runs
    }

    private static func covers(
        _ font: CTFont,
        _ characters: NSString,
        _ range: NSRange
    ) -> Bool {
        var units = Array(repeating: UniChar(), count: range.length)
        characters.getCharacters(&units, range: range)
        var glyphs = Array(repeating: CGGlyph(), count: range.length)
        return CTFontGetGlyphsForCharacters(font, units, &glyphs, range.length)
    }

    private static func decodeEntity(
        in source: String,
        at start: String.Index
    ) -> (value: String, endIndex: String.Index)? {
        guard let semicolon = source[start...].prefix(12).firstIndex(of: ";") else {
            return nil
        }
        let body = String(source[source.index(after: start)..<semicolon]).lowercased()
        let value: String?
        switch body {
        case "amp": value = "&"
        case "lt": value = "<"
        case "gt": value = ">"
        case "quot": value = "\""
        default:
            let number: UInt32?
            if body.hasPrefix("#x") {
                number = UInt32(body.dropFirst(2), radix: 16)
            } else if body.hasPrefix("#") {
                number = UInt32(body.dropFirst())
            } else {
                number = nil
            }
            value = number.flatMap(UnicodeScalar.init).map(String.init)
        }
        return value.map { ($0, source.index(after: semicolon)) }
    }

    private static func color(_ value: String) -> NSColor? {
        let names: [String: NSColor] = [
            "white": .white, "black": .black, "red": .red, "green": .green,
            "blue": .blue, "yellow": .yellow, "cyan": .cyan, "magenta": .magenta
        ]
        if let named = names[value.lowercased()] {
            return named
        }
        let hex = value.hasPrefix("#") ? String(value.dropFirst()) : value
        guard hex.count == 6, let rgb = UInt32(hex, radix: 16) else {
            return nil
        }
        return NSColor(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}

@MainActor
final class SRTSubtitleOverlayView: NSView {
    var areSubtitlesVisible = true {
        didSet {
            guard !isApplyingPresentation,
                  oldValue != areSubtitlesVisible
            else { return }
            imageLayer.isHidden = !areSubtitlesVisible
            updateImage(force: true)
        }
    }
    var currentTimeMilliseconds = 0 {
        didSet {
            guard !isApplyingPresentation else { return }
            updateImage()
        }
    }
    var videoSize: CGSize? {
        didSet {
            guard !isApplyingPresentation, oldValue != videoSize else { return }
            rebuildLayout()
            needsLayout = true
        }
    }
    var style = SRTSubtitleStyle() {
        didSet {
            guard oldValue != style else { return }
            rebuildLayout()
        }
    }
    var onRenderingFailure: ((String) -> Void)?
    /// The subtitle file itself could not be read. Unlike the renderer's own
    /// in-flight failures this one is the user's to see, so it travels to the
    /// App and is shown in the player's error banner.
    var onSourceLoadFailure: ((URL) -> Void)?

    private var source: PlaybackSubtitleSource?
    private var loadTask: Task<Void, Never>?
    private var layoutTask: Task<Void, Never>?
    private var loadingSourceIdentity: URL?
    private var loadedSourceIdentity: URL?
    private var cues: [PlaybackSubtitleCue] = []
    private var preparedLayout: SRTSubtitleLayout?
    private var activeOrdinals: [Int] = []
    private var activeValidRangeMilliseconds: Range<Int>?
    private var renderedImage: CGImage?
    private var isApplyingPresentation = false
    private let imageLayer = CALayer()

    private(set) var sourceLoadCountForTesting = 0
    private(set) var layoutBuildCountForTesting = 0

    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        imageLayer.contentsGravity = .resize
        imageLayer.magnificationFilter = .linear
        imageLayer.minificationFilter = .linear
        imageLayer.actions = [
            "contents": NSNull(), "position": NSNull(),
            "bounds": NSNull(), "frame": NSNull()
        ]
        layer?.addSublayer(imageLayer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    deinit {
        loadTask?.cancel()
        layoutTask?.cancel()
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func layout() {
        super.layout()
        imageLayer.frame = videoRect()
    }

    func setSource(_ source: PlaybackSubtitleSource?) {
        guard let source, source.format == .srt else {
            loadTask?.cancel()
            layoutTask?.cancel()
            self.source = nil
            loadingSourceIdentity = nil
            loadedSourceIdentity = nil
            cues = []
            preparedLayout = nil
            activeOrdinals = []
            activeValidRangeMilliseconds = nil
            renderedImage = nil
            imageLayer.contents = nil
            return
        }

        let nextIdentity = Self.identity(for: source)
        let currentIdentity = self.source.map(Self.identity(for:))
        self.source = source
        if nextIdentity == currentIdentity,
           nextIdentity == loadingSourceIdentity
            || nextIdentity == loadedSourceIdentity {
            return
        }

        loadTask?.cancel()
        layoutTask?.cancel()
        loadingSourceIdentity = nextIdentity
        loadedSourceIdentity = nil
        cues = []
        preparedLayout = nil
        activeOrdinals = []
        activeValidRangeMilliseconds = nil
        renderedImage = nil
        imageLayer.contents = nil
        sourceLoadCountForTesting += 1

        loadTask = Task.detached(priority: .userInitiated) { [weak self] in
            do {
                let cues = try SRTSubtitleRenderer.loadPlaybackCues(
                    from: source,
                    isCancelled: { Task.isCancelled }
                )
                guard !Task.isCancelled else { return }
                let scheduledAt = PlaybackPerformanceProbe.now()
                await self?.finishLoading(
                    cues,
                    sourceIdentity: nextIdentity,
                    scheduledAt: scheduledAt
                )
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                let scheduledAt = PlaybackPerformanceProbe.now()
                await self?.finishLoading(
                    nil,
                    sourceIdentity: nextIdentity,
                    scheduledAt: scheduledAt,
                    errorMessage: "SRT renderer failed to load source: \(error.localizedDescription)"
                )
            }
        }
    }

    func setPresentation(
        source nextSource: PlaybackSubtitleSource?,
        videoSize nextVideoSize: CGSize?,
        milliseconds: Int,
        isVisible: Bool
    ) {
        let previousVideoSize = videoSize
        let previousIdentity = source.map(Self.identity(for:))

        isApplyingPresentation = true
        videoSize = nextVideoSize
        currentTimeMilliseconds = max(0, milliseconds)
        areSubtitlesVisible = isVisible
        isApplyingPresentation = false
        imageLayer.isHidden = !isVisible

        setSource(nextSource)

        guard let nextSource,
              previousIdentity == Self.identity(for: nextSource)
        else {
            return
        }

        if previousVideoSize != nextVideoSize {
            rebuildLayout()
            needsLayout = true
        } else {
            updateImage(force: true)
        }
    }

    private func finishLoading(
        _ cues: [PlaybackSubtitleCue]?,
        sourceIdentity expectedSourceIdentity: URL,
        scheduledAt: UInt64,
        errorMessage: String? = nil
    ) {
        PlaybackPerformanceProbe.logElapsed(
            "SRTSubtitleOverlayView.loadCompletion.mainDelay",
            since: scheduledAt,
            thresholdMilliseconds: 8
        )
        guard source.map(Self.identity(for:)) == expectedSourceIdentity,
              loadingSourceIdentity == expectedSourceIdentity
        else {
            return
        }
        loadTask = nil
        loadingSourceIdentity = nil
        if let errorMessage {
            loadedSourceIdentity = nil
            onRenderingFailure?(errorMessage)
            if let sourceURL = source?.url {
                onSourceLoadFailure?(sourceURL)
            }
            return
        }
        loadedSourceIdentity = expectedSourceIdentity
        self.cues = cues ?? []
        rebuildLayout()
    }

    private func rebuildLayout() {
        layoutTask?.cancel()
        guard let source, let videoSize else {
            preparedLayout = nil
            activeValidRangeMilliseconds = nil
            renderedImage = nil
            imageLayer.contents = nil
            return
        }
        let sourceIdentity = Self.identity(for: source)
        guard loadedSourceIdentity == sourceIdentity, !cues.isEmpty else {
            return
        }
        preparedLayout = nil
        renderedImage = nil
        activeOrdinals = []
        activeValidRangeMilliseconds = nil
        imageLayer.contents = nil
        let cues = self.cues
        let style = self.style
        layoutBuildCountForTesting += 1
        layoutTask = Task.detached(priority: .userInitiated) { [weak self] in
            let layout = PlaybackPerformanceProbe.measure(
                "SRTSubtitleRenderer.makeLayout",
                thresholdMilliseconds: 8
            ) {
                SRTSubtitleRenderer.makeLayout(
                    cues: cues,
                    canvasSize: videoSize,
                    style: style,
                    isCancelled: { Task.isCancelled }
                )
            }
            guard !Task.isCancelled else { return }
            let scheduledAt = PlaybackPerformanceProbe.now()
            await self?.finishLayout(
                layout,
                sourceIdentity: sourceIdentity,
                videoSize: videoSize,
                style: style,
                scheduledAt: scheduledAt
            )
        }
    }

    private func finishLayout(
        _ layout: SRTSubtitleLayout?,
        sourceIdentity expectedSourceIdentity: URL,
        videoSize expectedVideoSize: CGSize,
        style expectedStyle: SRTSubtitleStyle,
        scheduledAt: UInt64
    ) {
        PlaybackPerformanceProbe.logElapsed(
            "SRTSubtitleOverlayView.layoutCompletion.mainDelay",
            since: scheduledAt,
            thresholdMilliseconds: 8
        )
        guard source.map(Self.identity(for:)) == expectedSourceIdentity,
              loadedSourceIdentity == expectedSourceIdentity,
              videoSize == expectedVideoSize,
              style == expectedStyle
        else {
            return
        }
        layoutTask = nil
        preparedLayout = layout
        updateImage(force: true)
    }

    private func updateImage(force: Bool = false) {
        guard areSubtitlesVisible, let preparedLayout else {
            activeValidRangeMilliseconds = nil
            renderedImage = nil
            imageLayer.contents = nil
            return
        }
        if !force,
           let activeValidRangeMilliseconds,
           activeValidRangeMilliseconds.contains(currentTimeMilliseconds) {
            return
        }
        PlaybackPerformanceProbe.recordSRTUpdateCall()
        let nextValidRange = Self.validRange(
            for: preparedLayout.track.cues,
            at: currentTimeMilliseconds
        )
        activeValidRangeMilliseconds = nextValidRange
        let ordinals = preparedLayout.track
            .activeCues(atMilliseconds: currentTimeMilliseconds)
            .map(\.sourceOrdinal)
        guard force || ordinals != activeOrdinals else { return }
        activeOrdinals = ordinals
        PlaybackPerformanceProbe.recordSRTBitmapRender()
        renderedImage = PlaybackPerformanceProbe.measure(
            "SRTSubtitleRenderer.image",
            thresholdMilliseconds: 8
        ) {
            SRTSubtitleRenderer.image(
                layout: preparedLayout,
                atMilliseconds: currentTimeMilliseconds
            )
        }
        imageLayer.contents = renderedImage
    }

    func nextScheduledRenderMilliseconds(after timestampMilliseconds: Int) -> Int? {
        guard areSubtitlesVisible, source != nil else { return nil }
        guard let preparedLayout else {
            return timestampMilliseconds + 33
        }
        let range = activeValidRangeMilliseconds ?? Self.validRange(
            for: preparedLayout.track.cues,
            at: timestampMilliseconds
        )
        guard range.contains(timestampMilliseconds) else {
            return timestampMilliseconds
        }
        guard range.upperBound < Int.max else { return nil }
        return max(timestampMilliseconds + 1, range.upperBound)
    }

    private static func validRange(
        for cues: [PlaybackSubtitleCue],
        at timestampMilliseconds: Int
    ) -> Range<Int> {
        var lowerBound = 0
        var upperBound = Int.max
        for cue in cues {
            let startMs = max(0, cue.startMilliseconds)
            let endMs = max(startMs, cue.endMilliseconds)
            guard endMs > startMs else { continue }
            if timestampMilliseconds >= startMs && timestampMilliseconds < endMs {
                if startMs > lowerBound { lowerBound = startMs }
                if endMs < upperBound { upperBound = endMs }
            } else if endMs <= timestampMilliseconds {
                if endMs > lowerBound { lowerBound = endMs }
            } else if startMs > timestampMilliseconds {
                if startMs < upperBound { upperBound = startMs }
            }
        }
        if upperBound <= lowerBound {
            upperBound = max(lowerBound + 1, timestampMilliseconds + 1)
        }
        return lowerBound..<upperBound
    }

    func currentPresentationImage() -> CGImage? {
        areSubtitlesVisible ? renderedImage : nil
    }

    nonisolated private static func identity(
        for source: PlaybackSubtitleSource
    ) -> URL {
        source.url.standardizedMediaURL
    }

    private func videoRect() -> CGRect {
        guard let videoSize, videoSize.width > 0, videoSize.height > 0 else {
            return bounds
        }
        let scale = min(bounds.width / videoSize.width, bounds.height / videoSize.height)
        let size = CGSize(width: videoSize.width * scale, height: videoSize.height * scale)
        return CGRect(
            x: bounds.midX - (size.width / 2),
            y: bounds.midY - (size.height / 2),
            width: size.width,
            height: size.height
        )
    }

}
