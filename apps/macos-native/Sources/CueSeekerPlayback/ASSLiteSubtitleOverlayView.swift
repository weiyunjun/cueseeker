import AppKit

@MainActor
final class ASSLiteSubtitleOverlayView: NSView {
    private let displayStyle = ASSLiteDisplayStyle.default

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
        let font = displayStyle.font(scaledBy: CGFloat(scaleY))
        let exteriorPadding = displayStyle.exteriorPadding(backingScale: backingScale)
        let textWidth = max(maxWidth - (exteriorPadding * 2), 24)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = horizontalTextAlignment(for: alignment)
        paragraphStyle.lineBreakMode = .byWordWrapping
        paragraphStyle.lineSpacing = displayStyle.lineSpacing

        let fillAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: displayStyle.textColor,
            .shadow: displayStyle.shadow(backingScale: backingScale),
            .paragraphStyle: paragraphStyle
        ]
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
            font: font,
            backingScale: backingScale
        )
    }

    private func drawText(
        _ text: String,
        in rect: CGRect,
        paragraphStyle: NSParagraphStyle,
        font: NSFont,
        backingScale: CGFloat
    ) {
        if displayStyle.outlineWidthPixels > 0 {
            let outlineAttributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: displayStyle.outlineColor,
                .paragraphStyle: paragraphStyle
            ]
            let outlineText = NSAttributedString(string: text, attributes: outlineAttributes)

            for offset in displayStyle.outlineOffsets(backingScale: backingScale) {
                outlineText.draw(
                    with: rect.offsetBy(dx: offset.width, dy: offset.height),
                    options: [.usesLineFragmentOrigin, .usesFontLeading]
                )
            }
        }

        let fillAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: displayStyle.textColor,
            .shadow: displayStyle.shadow(backingScale: backingScale),
            .paragraphStyle: paragraphStyle
        ]
        NSAttributedString(string: text, attributes: fillAttributes).draw(
            with: rect,
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

}

private struct ASSLiteDisplayStyle {
    var baseFontSize: CGFloat
    var minimumFontSize: CGFloat
    var textColor: NSColor
    var outlineColor: NSColor
    var outlineWidthPixels: CGFloat
    var shadowColor: NSColor
    var shadowRadiusPixels: CGFloat
    var shadowOffsetPixels: CGSize
    var boxEnabled: Bool
    var lineSpacing: CGFloat

    static let `default` = ASSLiteDisplayStyle(
        baseFontSize: 44,
        minimumFontSize: 14,
        textColor: .white,
        outlineColor: .black,
        outlineWidthPixels: 1,
        shadowColor: .black,
        shadowRadiusPixels: 2,
        shadowOffsetPixels: CGSize(width: 3, height: 3),
        boxEnabled: false,
        lineSpacing: 0
    )

    func font(scaledBy scaleY: CGFloat) -> NSFont {
        NSFont.systemFont(
            ofSize: max(baseFontSize * scaleY, minimumFontSize),
            weight: .regular
        )
    }

    func shadow(backingScale: CGFloat) -> NSShadow {
        let shadow = NSShadow()
        shadow.shadowColor = shadowColor
        shadow.shadowBlurRadius = shadowRadiusPixels / max(backingScale, 1)
        shadow.shadowOffset = CGSize(
            width: shadowOffsetPixels.width / max(backingScale, 1),
            height: shadowOffsetPixels.height / max(backingScale, 1)
        )
        return shadow
    }

    func exteriorPadding(backingScale: CGFloat) -> CGFloat {
        let scale = max(backingScale, 1)
        let outlinePadding = min(max(outlineWidthPixels, 0), 2) / scale
        let shadowPadding = (max(shadowRadiusPixels, 0) + max(abs(shadowOffsetPixels.width), abs(shadowOffsetPixels.height))) / scale
        return ceil(max(outlinePadding, shadowPadding))
    }

    func outlineOffsets(backingScale: CGFloat) -> [CGSize] {
        let offset = min(max(outlineWidthPixels, 0), 2) / max(backingScale, 1)
        guard offset > 0 else {
            return []
        }

        return [
            CGSize(width: -offset, height: -offset),
            CGSize(width: 0, height: -offset),
            CGSize(width: offset, height: -offset),
            CGSize(width: -offset, height: 0),
            CGSize(width: offset, height: 0),
            CGSize(width: -offset, height: offset),
            CGSize(width: 0, height: offset),
            CGSize(width: offset, height: offset)
        ]
    }
}
