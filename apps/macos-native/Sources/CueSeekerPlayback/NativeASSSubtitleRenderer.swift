import AppKit

struct NativeASSSubtitleSurface {
    var image: CGImage
    var frame: CGRect
    var text: String
}

@MainActor
enum NativeASSSubtitleRenderer {
    static func renderSurfaces(
        document: NativeASSDocument,
        atMilliseconds milliseconds: Int,
        containerBounds: CGRect,
        videoSize: CGSize?,
        backingScale: CGFloat
    ) -> [NativeASSSubtitleSurface] {
        let videoRect = displayedVideoRect(in: containerBounds, videoSize: videoSize)
        guard videoRect.width > 1, videoRect.height > 1 else {
            return []
        }

        let scriptWidth = max(document.playResX ?? Double(videoRect.width), 1)
        let scriptHeight = max(document.playResY ?? Double(videoRect.height), 1)
        let scaleX = Double(videoRect.width) / scriptWidth
        let scaleY = Double(videoRect.height) / scriptHeight

        return document
            .activeCues(atMilliseconds: milliseconds)
            .compactMap { cue in
                renderSurface(
                    for: cue,
                    in: videoRect,
                    scaleX: scaleX,
                    scaleY: scaleY,
                    backingScale: backingScale
                )
            }
    }

    private static func renderSurface(
        for cue: NativeASSCue,
        in videoRect: CGRect,
        scaleX: Double,
        scaleY: Double,
        backingScale: CGFloat
    ) -> NativeASSSubtitleSurface? {
        let renderStyle = NativeASSResolvedRenderStyle(
            style: cue.style,
            styleOverride: cue.event.styleOverride,
            scaleX: scaleX,
            scaleY: scaleY
        )
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = horizontalTextAlignment(for: cue.effectiveAlignment)
        paragraphStyle.lineBreakMode = .byWordWrapping
        paragraphStyle.lineSpacing = 0

        let marginL = CGFloat(cue.marginL * scaleX)
        let marginR = CGFloat(cue.marginR * scaleX)
        let marginV = CGFloat(cue.marginV * scaleY)
        let maxWidth = max(videoRect.width - marginL - marginR, 24)
        let horizontalScale = renderStyle.horizontalScale
        let textWidth = max((maxWidth - (renderStyle.exteriorPadding * 2)) / horizontalScale, 24)
        let fillAttributes = textAttributes(
            color: renderStyle.primaryColor,
            renderStyle: renderStyle,
            paragraphStyle: paragraphStyle
        )
        let attributedText = NSAttributedString(string: cue.text, attributes: fillAttributes)
        let measuredRect = attributedText.boundingRect(
            with: CGSize(width: textWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )
        let surfaceSize = CGSize(
            width: min(max(ceil(measuredRect.width * horizontalScale) + (renderStyle.exteriorPadding * 2), 1), maxWidth),
            height: max(ceil(measuredRect.height) + (renderStyle.exteriorPadding * 2), 1)
        )
        guard surfaceSize.width > 0, surfaceSize.height > 0 else {
            return nil
        }

        let contentRect = CGRect(
            x: videoRect.minX + marginL,
            y: videoRect.minY,
            width: maxWidth,
            height: videoRect.height
        )
        let x = horizontalOrigin(
            for: cue.effectiveAlignment,
            surfaceWidth: surfaceSize.width,
            in: contentRect
        )
        let y = verticalOrigin(
            for: cue.effectiveAlignment,
            surfaceHeight: surfaceSize.height,
            marginV: marginV,
            in: videoRect
        )
        let frame = CGRect(origin: CGPoint(x: x, y: y), size: surfaceSize)

        guard let image = makeSurfaceImage(
            text: cue.text,
            size: surfaceSize,
            renderStyle: renderStyle,
            paragraphStyle: paragraphStyle,
            backingScale: backingScale
        ) else {
            return nil
        }

        return NativeASSSubtitleSurface(
            image: image,
            frame: frame,
            text: cue.text
        )
    }

    private static func makeSurfaceImage(
        text: String,
        size: CGSize,
        renderStyle: NativeASSResolvedRenderStyle,
        paragraphStyle: NSParagraphStyle,
        backingScale: CGFloat
    ) -> CGImage? {
        let scale = max(backingScale, 1)
        let pixelsWide = max(Int(ceil(size.width * scale)), 1)
        let pixelsHigh = max(Int(ceil(size.height * scale)), 1)
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelsWide,
            pixelsHigh: pixelsHigh,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: pixelsWide * 4,
            bitsPerPixel: 32
        ) else {
            return nil
        }

        bitmap.size = CGSize(width: pixelsWide, height: pixelsHigh)

        NSGraphicsContext.saveGraphicsState()
        defer {
            NSGraphicsContext.restoreGraphicsState()
        }

        guard let graphicsContext = NSGraphicsContext(bitmapImageRep: bitmap) else {
            return nil
        }
        NSGraphicsContext.current = graphicsContext

        graphicsContext.cgContext.scaleBy(x: scale, y: scale)

        NSColor.clear.setFill()
        CGRect(origin: .zero, size: size).fill()

        let drawRect = CGRect(
            x: renderStyle.exteriorPadding,
            y: renderStyle.exteriorPadding,
            width: max(size.width - (renderStyle.exteriorPadding * 2), 1),
            height: max(size.height - (renderStyle.exteriorPadding * 2), 1)
        )
        let hScale = renderStyle.horizontalScale

        if renderStyle.shadowOffset.width != 0 || renderStyle.shadowOffset.height != 0 {
            let shadowText = NSAttributedString(
                string: text,
                attributes: textAttributes(
                    color: renderStyle.shadowColor,
                    renderStyle: renderStyle,
                    paragraphStyle: paragraphStyle
                )
            )
            drawScaled(
                shadowText,
                in: drawRect,
                offset: renderStyle.shadowOffset,
                horizontalScale: hScale,
                context: graphicsContext.cgContext
            )
        }

        if renderStyle.outlineWidth > 0 {
            let outlineText = NSAttributedString(
                string: text,
                attributes: textAttributes(
                    color: renderStyle.outlineColor,
                    renderStyle: renderStyle,
                    paragraphStyle: paragraphStyle
                )
            )

            for offset in outlineOffsets(width: renderStyle.outlineWidth, backingScale: backingScale) {
                drawScaled(
                    outlineText,
                    in: drawRect,
                    offset: offset,
                    horizontalScale: hScale,
                    context: graphicsContext.cgContext
                )
            }
        }

        let fillText = NSAttributedString(
            string: text,
            attributes: textAttributes(
                color: renderStyle.primaryColor,
                renderStyle: renderStyle,
                paragraphStyle: paragraphStyle
            )
        )
        drawScaled(
            fillText,
            in: drawRect,
            offset: .zero,
            horizontalScale: hScale,
            context: graphicsContext.cgContext
        )

        return bitmap.cgImage
    }

    private static func displayedVideoRect(in bounds: CGRect, videoSize: CGSize?) -> CGRect {
        guard let videoSize,
              videoSize.width > 0,
              videoSize.height > 0,
              bounds.width > 0,
              bounds.height > 0
        else {
            return bounds
        }

        let scale = min(bounds.width / videoSize.width, bounds.height / videoSize.height)
        let width = videoSize.width * scale
        let height = videoSize.height * scale
        return CGRect(
            x: bounds.midX - (width / 2),
            y: bounds.midY - (height / 2),
            width: width,
            height: height
        )
    }

    private static func horizontalOrigin(
        for alignment: Int,
        surfaceWidth: CGFloat,
        in contentRect: CGRect
    ) -> CGFloat {
        switch alignment {
        case 1, 4, 7:
            return contentRect.minX
        case 3, 6, 9:
            return contentRect.maxX - surfaceWidth
        default:
            return contentRect.midX - (surfaceWidth / 2)
        }
    }

    private static func verticalOrigin(
        for alignment: Int,
        surfaceHeight: CGFloat,
        marginV: CGFloat,
        in videoRect: CGRect
    ) -> CGFloat {
        let y: CGFloat
        switch alignment {
        case 7, 8, 9:
            y = videoRect.minY + marginV
        case 4, 5, 6:
            y = videoRect.midY - (surfaceHeight / 2)
        default:
            y = videoRect.maxY - marginV - surfaceHeight
        }

        return min(max(y, videoRect.minY), max(videoRect.minY, videoRect.maxY - surfaceHeight))
    }

    private static func horizontalTextAlignment(for alignment: Int) -> NSTextAlignment {
        switch alignment {
        case 1, 4, 7:
            return .left
        case 3, 6, 9:
            return .right
        default:
            return .center
        }
    }

    private static func textAttributes(
        color: NSColor,
        renderStyle: NativeASSResolvedRenderStyle,
        paragraphStyle: NSParagraphStyle
    ) -> [NSAttributedString.Key: Any] {
        [
            .font: renderStyle.font,
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle
        ]
    }

    private static func drawScaled(
        _ text: NSAttributedString,
        in rect: CGRect,
        offset: CGSize,
        horizontalScale: CGFloat,
        context: CGContext
    ) {
        let scale = max(horizontalScale, 0.1)
        context.saveGState()
        context.translateBy(x: rect.minX + offset.width, y: rect.minY + offset.height)
        context.scaleBy(x: scale, y: 1)
        text.draw(
            with: CGRect(x: 0, y: 0, width: rect.width / scale, height: rect.height),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )
        context.restoreGState()
    }

    private static func outlineOffsets(width: CGFloat, backingScale: CGFloat) -> [CGSize] {
        guard width > 0 else {
            return []
        }

        let scale = max(backingScale, 1)
        let steps = max(1, Int(ceil(width * scale)))

        return (1...steps).flatMap { step in
            let radius = CGFloat(step) / scale
            return [
                CGSize(width: -radius, height: -radius),
                CGSize(width: 0, height: -radius),
                CGSize(width: radius, height: -radius),
                CGSize(width: -radius, height: 0),
                CGSize(width: radius, height: 0),
                CGSize(width: -radius, height: radius),
                CGSize(width: 0, height: radius),
                CGSize(width: radius, height: radius)
            ]
        }
    }
}

private struct NativeASSResolvedRenderStyle {
    var font: NSFont
    var primaryColor: NSColor
    var outlineColor: NSColor
    var shadowColor: NSColor
    var outlineWidth: CGFloat
    var shadowOffset: CGSize
    var horizontalScale: CGFloat

    var exteriorPadding: CGFloat {
        let shadowPadding = max(abs(shadowOffset.width), abs(shadowOffset.height))
        return ceil(max(outlineWidth, shadowPadding))
    }

    init(style: NativeASSStyle, styleOverride: NativeASSStyleOverride, scaleX: Double, scaleY: Double) {
        let xScale = CGFloat(scaleX)
        let yScale = CGFloat(scaleY)
        let sourceFontSize = styleOverride.fontSize ?? style.fontSize
        let sourceScaleX = styleOverride.scaleX ?? style.scaleX
        let sourceScaleY = styleOverride.scaleY ?? style.scaleY
        let verticalScale = max(CGFloat(sourceScaleY) / 100, 0.1)
        let fontSize = max(CGFloat(sourceFontSize) * yScale * verticalScale, 8)
        let baseFont = NSFont(name: style.fontName, size: fontSize) ?? NSFont.systemFont(ofSize: fontSize)
        var resolvedFont = baseFont

        if style.isBold {
            resolvedFont = NSFontManager.shared.convert(resolvedFont, toHaveTrait: .boldFontMask)
        }

        if style.isItalic {
            resolvedFont = NSFontManager.shared.convert(resolvedFont, toHaveTrait: .italicFontMask)
        }

        font = resolvedFont
        primaryColor = NSColor(nativeASSColor: style.primaryColor)
        outlineColor = NSColor(nativeASSColor: style.outlineColor)
        shadowColor = NSColor(nativeASSColor: style.shadowColor)
        horizontalScale = max(CGFloat(sourceScaleX) / 100, 0.1)
        outlineWidth = max(CGFloat(style.outline) * yScale, 0)
        shadowOffset = CGSize(
            width: max(CGFloat(style.shadow), 0) * xScale,
            height: max(CGFloat(style.shadow), 0) * yScale
        )
    }
}

private extension NSColor {
    convenience init(nativeASSColor color: NativeASSColor) {
        self.init(
            calibratedRed: color.red,
            green: color.green,
            blue: color.blue,
            alpha: color.alpha
        )
    }
}
