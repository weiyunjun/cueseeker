import AppKit
import CoreText
import CueSeekerCore
import Foundation

/// Fonts for one layout, each sized directly at the scaled point size.
struct SRTFontCache {
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

        let pointSize = lineHeight
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

enum SRTInlineText {
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
