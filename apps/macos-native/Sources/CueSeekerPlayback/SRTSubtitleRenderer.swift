import AppKit
import CoreText
import CueSeekerCore
import Foundation
import QuartzCore

final class SRTSubtitleLayout: @unchecked Sendable {
    fileprivate let canvasSize: CGSize
    fileprivate let borderSize: CGFloat
    fileprivate let track: PlaybackSubtitleTrack
    fileprivate let items: [Int: SRTSubtitleItem]

    fileprivate init(
        canvasSize: CGSize,
        borderSize: CGFloat,
        track: PlaybackSubtitleTrack,
        items: [Int: SRTSubtitleItem]
    ) {
        self.canvasSize = canvasSize
        self.borderSize = borderSize
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
    let outlinePath: CGPath
    let visualBounds: CGRect
    let isDrawable: Bool
}

private struct SRTSubtitleRenderingError: Error, LocalizedError {
    let errorDescription: String?
}

enum SRTSubtitleRenderer {
    static let baseFontSize: CGFloat = 44
    private static let referenceHeight: CGFloat = 720

    static func makeLayout(
        cues: [PlaybackSubtitleCue],
        canvasSize: CGSize
    ) -> SRTSubtitleLayout? {
        guard canvasSize.width > 1, canvasSize.height > 1 else {
            return nil
        }

        let scale = canvasSize.height / referenceHeight
        let fontSize = baseFontSize * scale
        let borderSize = 3 * scale
        let marginX = 25 * scale
        let marginY = 22 * scale
        let maximumTextWidth = max(1, canvasSize.width - (2 * (marginX + borderSize)))
        let track = PlaybackSubtitleTrack(cues: cues)
        var items: [Int: SRTSubtitleItem] = [:]
        var activeItems: [SRTSubtitleItem] = []

        for cue in track.cues {
            activeItems.removeAll { $0.cue.endMilliseconds <= cue.startMilliseconds }
            guard let measured = measuredFrame(
                text: cue.text,
                fontSize: fontSize,
                maximumWidth: maximumTextWidth,
                borderSize: borderSize
            ) else {
                continue
            }

            let bottom = activeItems.map(\.visualBounds.minY).min()
                ?? (canvasSize.height - marginY)
            let bounds = CGRect(
                x: (canvasSize.width - measured.size.width) / 2,
                y: bottom - measured.size.height,
                width: measured.size.width,
                height: measured.size.height
            )
            let drawable = bounds.minY >= 0 || measured.size.height > canvasSize.height
            let item = SRTSubtitleItem(
                cue: cue,
                frame: measured.frame,
                outlinePath: measured.outlinePath,
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
            borderSize: borderSize,
            track: track,
            items: items
        )
    }

    static func loadPlaybackCues(
        from source: PlaybackSubtitleSource
    ) throws -> [PlaybackSubtitleCue] {
        guard source.format == .srt else {
            throw SRTSubtitleRenderingError(
                errorDescription: "SRT renderer received a non-SRT source."
            )
        }
        let data = try Data(contentsOf: source.url, options: .mappedIfSafe)
        let entries = try SRTParser.parseForRendering(data)
        guard !entries.isEmpty else {
            throw SRTSubtitleRenderingError(
                errorDescription: "SRT renderer found no valid playback Cues."
            )
        }
        let speakers = Dictionary(
            source.speakerDisplayCues.map {
                (
                    speakerKey(
                        $0.startMilliseconds,
                        $0.endMilliseconds,
                        $0.cleanText
                    ),
                    $0.speakers
                )
            },
            uniquingKeysWith: { first, _ in first }
        )
        return entries.enumerated().map { ordinal, entry in
            let speakerSet = speakers[
                speakerKey(
                    entry.startMilliseconds,
                    entry.endMilliseconds,
                    entry.text
                )
            ] ?? []
            return PlaybackSubtitleCue(
                sourceOrdinal: ordinal,
                startMilliseconds: entry.startMilliseconds,
                endMilliseconds: entry.endMilliseconds,
                text: SubtitleSpeakerDisplayFormatter.prefixedText(
                    entry.text,
                    speakers: speakerSet
                )
            )
        }
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

        context.setShouldAntialias(true)
        context.setShouldSmoothFonts(true)
        context.clip(to: CGRect(origin: .zero, size: layout.canvasSize))

        for item in activeItems {
            let bounds = item.visualBounds
            context.saveGState()
            context.translateBy(
                x: bounds.minX,
                y: layout.canvasSize.height - bounds.maxY
            )
            context.textMatrix = .identity
            context.setLineJoin(.round)
            context.setStrokeColor(NSColor.black.cgColor)
            context.setLineWidth(2 * layout.borderSize)
            context.addPath(item.outlinePath)
            context.strokePath()

            context.saveGState()
            context.setTextDrawingMode(.fill)
            CTFrameDraw(item.frame, context)
            context.restoreGState()
            context.restoreGState()
        }

        return context.makeImage()
    }

    private static func measuredFrame(
        text: String,
        fontSize: CGFloat,
        maximumWidth: CGFloat,
        borderSize: CGFloat
    ) -> (frame: CTFrame, outlinePath: CGPath, size: CGSize)? {
        let attributedText = SRTInlineText.attributedString(
            from: text,
            fontSize: fontSize
        )
        guard attributedText.length > 0 else {
            return nil
        }

        let framesetter = CTFramesetterCreateWithAttributedString(attributedText)
        let constraint = CGSize(width: maximumWidth, height: 1_000_000)
        let suggested = CTFramesetterSuggestFrameSizeWithConstraints(
            framesetter,
            CFRange(location: 0, length: attributedText.length),
            nil,
            constraint,
            nil
        )
        let textSize = CGSize(
            width: min(maximumWidth, max(1, ceil(suggested.width))),
            height: max(1, ceil(suggested.height))
        )
        let path = CGPath(
            rect: CGRect(
                x: borderSize,
                y: borderSize,
                width: textSize.width,
                height: textSize.height
            ),
            transform: nil
        )
        let frame = CTFramesetterCreateFrame(
            framesetter,
            CFRange(location: 0, length: attributedText.length),
            path,
            nil
        )
        return (
            frame,
            glyphPath(
                frame: frame,
                pathOrigin: CGPoint(x: borderSize, y: borderSize)
            ),
            CGSize(
                width: textSize.width + (2 * borderSize),
                height: textSize.height + (2 * borderSize)
            )
        )
    }

    private static func glyphPath(
        frame: CTFrame,
        pathOrigin: CGPoint
    ) -> CGPath {
        let result = CGMutablePath()
        let lines = CTFrameGetLines(frame) as! [CTLine]
        var origins = Array(repeating: CGPoint.zero, count: lines.count)
        CTFrameGetLineOrigins(frame, CFRange(location: 0, length: 0), &origins)

        for (line, origin) in zip(lines, origins) {
            for run in CTLineGetGlyphRuns(line) as! [CTRun] {
                let attributes = CTRunGetAttributes(run) as NSDictionary
                guard let fontValue = attributes[kCTFontAttributeName] else {
                    continue
                }
                let font = fontValue as! CTFont
                let count = CTRunGetGlyphCount(run)
                var glyphs = Array(repeating: CGGlyph(), count: count)
                var positions = Array(repeating: CGPoint.zero, count: count)
                CTRunGetGlyphs(run, CFRange(location: 0, length: 0), &glyphs)
                CTRunGetPositions(run, CFRange(location: 0, length: 0), &positions)
                for (glyph, position) in zip(glyphs, positions) {
                    var transform = CGAffineTransform(
                        translationX: pathOrigin.x + origin.x + position.x,
                        y: pathOrigin.y + origin.y + position.y
                    )
                    if let path = CTFontCreatePathForGlyph(font, glyph, &transform) {
                        result.addPath(path)
                    }
                }
            }
        }
        return result
    }

    private static func bitmapContext(size: CGSize) -> CGContext? {
        let width = Int(size.width.rounded())
        let height = Int(size.height.rounded())
        guard width > 1, height > 1 else {
            return nil
        }
        return CGContext(
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
    }

    private static func speakerKey(
        _ start: Int,
        _ end: Int,
        _ text: String
    ) -> String {
        "\(start):\(end):\(text.trimmingCharacters(in: .whitespacesAndNewlines))"
    }
}

private enum SRTInlineText {
    private struct Style {
        var bold = 0
        var italic = 0
        var underline = 0
        var colors: [NSColor] = [.white]
    }

    static func attributedString(
        from source: String,
        fontSize: CGFloat
    ) -> NSAttributedString {
        let output = NSMutableAttributedString()
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byWordWrapping
        var style = Style()
        var index = source.startIndex

        func append(_ text: String) {
            guard !text.isEmpty else { return }
            output.append(
                NSAttributedString(
                    string: text,
                    attributes: attributes(
                        style: style,
                        fontSize: fontSize,
                        paragraph: paragraph
                    )
                )
            )
        }

        while index < source.endIndex {
            if source[index] == "<",
               let close = source[index...].firstIndex(of: ">") {
                let token = String(source[index...close])
                if apply(tag: token, to: &style) {
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
                append(decoded.value)
                index = decoded.endIndex
                continue
            }

            append(String(source[index]))
            index = source.index(after: index)
        }

        return output
    }

    private static func apply(tag: String, to style: inout Style) -> Bool {
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
            style.colors.append(color(String(value)) ?? style.colors.last ?? .white)
        }
        return true
    }

    private static func attributes(
        style: Style,
        fontSize: CGFloat,
        paragraph: NSParagraphStyle
    ) -> [NSAttributedString.Key: Any] {
        let base = CTFontCreateUIFontForLanguage(.system, fontSize, nil)
            ?? CTFontCreateWithName("Helvetica" as CFString, fontSize, nil)
        var traits: CTFontSymbolicTraits = []
        if style.bold > 0 {
            traits.insert(.boldTrait)
        }
        if style.italic > 0 {
            traits.insert(.italicTrait)
        }
        let font = traits.isEmpty
            ? base
            : CTFontCreateCopyWithSymbolicTraits(base, fontSize, nil, traits, traits) ?? base
        var result: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: style.colors.last ?? NSColor.white,
            .paragraphStyle: paragraph
        ]
        if style.underline > 0 {
            result[.underlineStyle] = NSUnderlineStyle.single.rawValue
        }
        return result
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
            imageLayer.isHidden = !areSubtitlesVisible
            updateImage(force: true)
        }
    }
    var currentTimeMilliseconds = 0 {
        didSet { updateImage() }
    }
    var videoSize: CGSize? {
        didSet {
            rebuildLayout()
            needsLayout = true
        }
    }
    var onRenderingFailure: ((String) -> Void)?

    private var source: PlaybackSubtitleSource?
    private var loadTask: Task<Void, Never>?
    private var layoutTask: Task<Void, Never>?
    private var cues: [PlaybackSubtitleCue] = []
    private var preparedLayout: SRTSubtitleLayout?
    private var activeOrdinals: [Int] = []
    private var renderedImage: CGImage?
    private let imageLayer = CALayer()

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
        loadTask?.cancel()
        layoutTask?.cancel()
        self.source = source
        cues = []
        preparedLayout = nil
        activeOrdinals = []
        renderedImage = nil
        imageLayer.contents = nil
        guard let source, source.format == .srt else { return }

        loadTask = Task.detached(priority: .userInitiated) { [weak self] in
            do {
                let cues = try SRTSubtitleRenderer.loadPlaybackCues(from: source)
                guard !Task.isCancelled else { return }
                await self?.finishLoading(cues, source: source)
            } catch {
                guard !Task.isCancelled else { return }
                await self?.finishLoading(
                    nil,
                    source: source,
                    errorMessage: "SRT renderer failed to load source: \(error.localizedDescription)"
                )
            }
        }
    }

    private func finishLoading(
        _ cues: [PlaybackSubtitleCue]?,
        source expectedSource: PlaybackSubtitleSource,
        errorMessage: String? = nil
    ) {
        guard source == expectedSource else { return }
        if let errorMessage {
            onRenderingFailure?(errorMessage)
            return
        }
        self.cues = cues ?? []
        rebuildLayout()
    }

    private func rebuildLayout() {
        layoutTask?.cancel()
        guard let source, let videoSize else {
            preparedLayout = nil
            renderedImage = nil
            imageLayer.contents = nil
            return
        }
        preparedLayout = nil
        renderedImage = nil
        activeOrdinals = []
        imageLayer.contents = nil
        let cues = self.cues
        layoutTask = Task.detached(priority: .userInitiated) { [weak self] in
            let layout = SRTSubtitleRenderer.makeLayout(
                cues: cues,
                canvasSize: videoSize
            )
            guard !Task.isCancelled else { return }
            await self?.finishLayout(
                layout,
                source: source,
                videoSize: videoSize
            )
        }
    }

    private func finishLayout(
        _ layout: SRTSubtitleLayout?,
        source expectedSource: PlaybackSubtitleSource,
        videoSize expectedVideoSize: CGSize
    ) {
        guard source == expectedSource, videoSize == expectedVideoSize else { return }
        preparedLayout = layout
        updateImage(force: true)
    }

    private func updateImage(force: Bool = false) {
        guard areSubtitlesVisible, let preparedLayout else {
            renderedImage = nil
            imageLayer.contents = nil
            return
        }
        let ordinals = preparedLayout.track
            .activeCues(atMilliseconds: currentTimeMilliseconds)
            .map(\.sourceOrdinal)
        guard force || ordinals != activeOrdinals else { return }
        activeOrdinals = ordinals
        renderedImage = SRTSubtitleRenderer.image(
            layout: preparedLayout,
            atMilliseconds: currentTimeMilliseconds
        )
        imageLayer.contents = renderedImage
    }

    func currentPresentationImage() -> CGImage? {
        areSubtitlesVisible ? renderedImage : nil
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
