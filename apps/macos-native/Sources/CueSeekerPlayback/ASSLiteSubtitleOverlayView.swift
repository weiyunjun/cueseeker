import AppKit

@MainActor
final class ASSLiteSubtitleOverlayView: NSView {
    var script: ASSLiteScript? {
        didSet {
            needsDisplay = true
        }
    }

    var currentTimeMilliseconds: Int = 0 {
        didSet {
            if oldValue != currentTimeMilliseconds {
                needsDisplay = true
            }
        }
    }

    var areSubtitlesVisible: Bool = true {
        didSet {
            if oldValue != areSubtitlesVisible {
                needsDisplay = true
            }
        }
    }

    var videoSize: CGSize? {
        didSet {
            if oldValue != videoSize {
                needsDisplay = true
            }
        }
    }

    override var isFlipped: Bool {
        true
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        postsFrameChangedNotifications = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard areSubtitlesVisible,
              let script
        else {
            return
        }

        let videoRect = displayedVideoRect(in: bounds)
        guard videoRect.width > 1, videoRect.height > 1 else {
            return
        }

        let scriptWidth = max(script.playResX ?? Double(videoRect.width), 1)
        let scriptHeight = max(script.playResY ?? Double(videoRect.height), 1)
        let scaleX = Double(videoRect.width) / scriptWidth
        let scaleY = Double(videoRect.height) / scriptHeight

        for dialogue in script.activeDialogues(atMilliseconds: currentTimeMilliseconds) {
            let style = script.styles[dialogue.styleName] ?? ASSLiteStyle.fallback
            draw(dialogue, style: style, in: videoRect, scaleX: scaleX, scaleY: scaleY)
        }
    }

    private func draw(
        _ dialogue: ASSLiteDialogue,
        style: ASSLiteStyle,
        in videoRect: CGRect,
        scaleX: Double,
        scaleY: Double
    ) {
        let alignment = effectiveAlignment(for: dialogue, style: style)
        let marginL = CGFloat((dialogue.marginL ?? style.marginL) * scaleX)
        let marginR = CGFloat((dialogue.marginR ?? style.marginR) * scaleX)
        let marginV = CGFloat((dialogue.marginV ?? style.marginV) * scaleY)
        let maxWidth = max(videoRect.width - marginL - marginR, 24)
        let backingScale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
        guard let renderStyle = ASSLiteResolvedRenderStyle(style: style, scaleX: scaleX, scaleY: scaleY) else {
            return
        }
        let exteriorPadding = renderStyle.exteriorPadding
        let textWidth = max((maxWidth - (exteriorPadding * 2)) / renderStyle.horizontalScale, 24)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = horizontalTextAlignment(for: alignment)
        paragraphStyle.lineBreakMode = .byWordWrapping
        paragraphStyle.lineSpacing = 0

        let fillAttributes = textAttributes(color: renderStyle.primaryColor, renderStyle: renderStyle, paragraphStyle: paragraphStyle)
        let attributedText = NSAttributedString(string: dialogue.text, attributes: fillAttributes)
        let measuredRect = attributedText.boundingRect(
            with: CGSize(width: textWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )
        let textHeight = ceil(measuredRect.height) + (exteriorPadding * 2)
        let y = verticalOrigin(
            for: alignment,
            textHeight: textHeight,
            marginV: marginV,
            in: videoRect
        )

        let drawRect = CGRect(
            x: videoRect.minX + marginL,
            y: y,
            width: maxWidth,
            height: textHeight
        ).insetBy(dx: exteriorPadding, dy: exteriorPadding)

        drawText(
            dialogue.text,
            in: drawRect,
            paragraphStyle: paragraphStyle,
            renderStyle: renderStyle,
            backingScale: backingScale
        )
    }

    private func drawText(
        _ text: String,
        in rect: CGRect,
        paragraphStyle: NSParagraphStyle,
        renderStyle: ASSLiteResolvedRenderStyle,
        backingScale: CGFloat
    ) {
        guard let context = NSGraphicsContext.current?.cgContext else {
            return
        }

        context.saveGState()
        if renderStyle.angle != 0 {
            context.translateBy(x: rect.midX, y: rect.midY)
            context.rotate(by: renderStyle.angle * .pi / 180)
            context.translateBy(x: -rect.midX, y: -rect.midY)
        }

        if renderStyle.borderStyle == 3 {
            drawOpaqueBox(in: rect, renderStyle: renderStyle)
        } else if renderStyle.shadowOffset.width != 0 || renderStyle.shadowOffset.height != 0 {
            let shadowAttributes = textAttributes(color: renderStyle.backColor, renderStyle: renderStyle, paragraphStyle: paragraphStyle)
            let shadowText = NSAttributedString(string: text, attributes: shadowAttributes)
            draw(
                shadowText,
                in: rect,
                offset: renderStyle.shadowOffset,
                horizontalScale: renderStyle.horizontalScale
            )
        }

        if renderStyle.borderStyle != 3, renderStyle.outlineWidth > 0 {
            let outlineAttributes = textAttributes(color: renderStyle.outlineColor, renderStyle: renderStyle, paragraphStyle: paragraphStyle)
            let outlineText = NSAttributedString(string: text, attributes: outlineAttributes)

            for offset in outlineOffsets(width: renderStyle.outlineWidth, backingScale: backingScale) {
                draw(
                    outlineText,
                    in: rect,
                    offset: offset,
                    horizontalScale: renderStyle.horizontalScale
                )
            }
        }

        let fillAttributes = textAttributes(color: renderStyle.primaryColor, renderStyle: renderStyle, paragraphStyle: paragraphStyle)
        let fillText = NSAttributedString(string: text, attributes: fillAttributes)
        draw(
            fillText,
            in: rect,
            offset: .zero,
            horizontalScale: renderStyle.horizontalScale
        )

        context.restoreGState()
    }

    private func textAttributes(
        color: NSColor,
        renderStyle: ASSLiteResolvedRenderStyle,
        paragraphStyle: NSParagraphStyle
    ) -> [NSAttributedString.Key: Any] {
        var attributes: [NSAttributedString.Key: Any] = [
            .font: renderStyle.font,
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle
        ]

        if renderStyle.spacing != 0 {
            attributes[.kern] = renderStyle.spacing
        }

        if renderStyle.isUnderline {
            attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
        }

        if renderStyle.isStrikeOut {
            attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
        }

        return attributes
    }

    private func draw(
        _ text: NSAttributedString,
        in rect: CGRect,
        offset: CGSize,
        horizontalScale: CGFloat
    ) {
        guard let context = NSGraphicsContext.current?.cgContext else {
            return
        }

        guard horizontalScale > 0 else {
            return
        }

        context.saveGState()
        context.translateBy(x: rect.minX + offset.width, y: rect.minY + offset.height)
        context.scaleBy(x: horizontalScale, y: 1)
        text.draw(
            with: CGRect(x: 0, y: 0, width: rect.width / horizontalScale, height: rect.height),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )
        context.restoreGState()
    }

    private func drawOpaqueBox(in rect: CGRect, renderStyle: ASSLiteResolvedRenderStyle) {
        let boxRect = rect.insetBy(dx: -renderStyle.outlineWidth, dy: -renderStyle.outlineWidth)
        renderStyle.backColor.setFill()
        NSBezierPath(rect: boxRect).fill()
    }

    private func outlineOffsets(width: CGFloat, backingScale: CGFloat) -> [CGSize] {
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

    private func displayedVideoRect(in bounds: CGRect) -> CGRect {
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

    private func effectiveAlignment(for dialogue: ASSLiteDialogue, style: ASSLiteStyle) -> Int {
        let alignment = dialogue.alignmentOverride ?? style.alignment
        return (1...9).contains(alignment) ? alignment : ASSLiteStyle.fallback.alignment
    }

    private func horizontalTextAlignment(for alignment: Int) -> NSTextAlignment {
        switch alignment {
        case 1, 4, 7:
            return .left
        case 3, 6, 9:
            return .right
        default:
            return .center
        }
    }

    private func verticalOrigin(
        for alignment: Int,
        textHeight: CGFloat,
        marginV: CGFloat,
        in videoRect: CGRect
    ) -> CGFloat {
        let y: CGFloat
        switch alignment {
        case 7, 8, 9:
            y = videoRect.minY + marginV
        case 4, 5, 6:
            y = videoRect.midY - (textHeight / 2)
        default:
            y = videoRect.maxY - marginV - textHeight
        }

        return min(max(y, videoRect.minY), max(videoRect.minY, videoRect.maxY - textHeight))
    }
}

private struct ASSLiteResolvedRenderStyle {
    var font: NSFont
    var primaryColor: NSColor
    var outlineColor: NSColor
    var backColor: NSColor
    var isUnderline: Bool
    var isStrikeOut: Bool
    var horizontalScale: CGFloat
    var spacing: CGFloat
    var angle: CGFloat
    var borderStyle: Int
    var outlineWidth: CGFloat
    var shadowOffset: CGSize

    var exteriorPadding: CGFloat {
        let shadowPadding = max(abs(shadowOffset.width), abs(shadowOffset.height))
        return ceil(max(outlineWidth, shadowPadding))
    }

    init?(style: ASSLiteStyle, scaleX: Double, scaleY: Double) {
        let xScale = CGFloat(scaleX)
        let yScale = CGFloat(scaleY)
        let verticalScale = CGFloat(style.scaleY) / 100
        let horizontalScale = CGFloat(style.scaleX) / 100
        let fontSize = CGFloat(style.fontSize) * yScale * verticalScale
        guard fontSize > 0, horizontalScale > 0 else {
            return nil
        }
        let baseFont = NSFont(name: style.fontName, size: fontSize) ?? NSFont.systemFont(ofSize: fontSize)
        var resolvedFont = baseFont

        if style.isBold {
            resolvedFont = NSFontManager.shared.convert(resolvedFont, toHaveTrait: .boldFontMask)
        }

        if style.isItalic {
            resolvedFont = NSFontManager.shared.convert(resolvedFont, toHaveTrait: .italicFontMask)
        }

        font = resolvedFont
        primaryColor = NSColor(assLiteColor: style.primaryColor)
        outlineColor = NSColor(assLiteColor: style.outlineColor)
        backColor = NSColor(assLiteColor: style.backColor)
        isUnderline = style.isUnderline
        isStrikeOut = style.isStrikeOut
        self.horizontalScale = horizontalScale
        spacing = CGFloat(style.spacing) * xScale
        angle = CGFloat(style.angle)
        borderStyle = style.borderStyle
        outlineWidth = max(CGFloat(style.outline) * yScale, 0)
        shadowOffset = CGSize(
            width: max(CGFloat(style.shadow), 0) * xScale,
            height: max(CGFloat(style.shadow), 0) * yScale
        )
    }
}

private extension NSColor {
    convenience init(assLiteColor color: ASSLiteColor) {
        self.init(
            calibratedRed: color.red,
            green: color.green,
            blue: color.blue,
            alpha: color.alpha
        )
    }
}
