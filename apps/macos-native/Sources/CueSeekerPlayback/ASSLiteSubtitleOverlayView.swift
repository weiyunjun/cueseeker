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
        let fontSize = max(style.fontSize * scaleY, 8)
        let font = resolvedFont(style: style, size: fontSize)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = horizontalTextAlignment(for: alignment)
        paragraphStyle.lineBreakMode = .byWordWrapping

        var attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor(assLiteColor: style.primaryColor),
            .paragraphStyle: paragraphStyle
        ]

        if style.outline > 0 {
            attributes[.strokeColor] = NSColor(assLiteColor: style.outlineColor)
            attributes[.strokeWidth] = -max(1.5, style.outline * scaleY * 2)
        }

        if style.shadow > 0 {
            let shadow = NSShadow()
            shadow.shadowColor = NSColor(assLiteColor: style.backColor)
            shadow.shadowBlurRadius = max(0, style.shadow * scaleY)
            shadow.shadowOffset = CGSize(width: style.shadow * scaleX, height: style.shadow * scaleY)
            attributes[.shadow] = shadow
        }

        let attributedText = NSAttributedString(string: dialogue.text, attributes: attributes)
        let measuredRect = attributedText.boundingRect(
            with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )
        let textHeight = ceil(measuredRect.height)
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
        )

        attributedText.draw(
            with: drawRect,
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )
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

    private func resolvedFont(style: ASSLiteStyle, size: Double) -> NSFont {
        let baseFont = NSFont(name: style.fontName, size: size) ?? NSFont.systemFont(ofSize: size)
        var font = baseFont

        if style.isBold {
            font = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
        }

        if style.isItalic {
            font = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
        }

        return font
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
