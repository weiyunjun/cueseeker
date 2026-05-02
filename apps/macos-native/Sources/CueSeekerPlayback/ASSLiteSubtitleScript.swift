import Foundation

struct ASSLiteScript: Equatable, Sendable {
    var playResX: Double?
    var playResY: Double?
    var styles: [String: ASSLiteStyle]
    var dialogues: [ASSLiteDialogue]

    func activeDialogues(atMilliseconds milliseconds: Int) -> [ASSLiteDialogue] {
        dialogues
            .filter { $0.isActive(atMilliseconds: milliseconds) }
            .sorted {
                if $0.layer == $1.layer {
                    return $0.sourceOrder < $1.sourceOrder
                }

                return $0.layer < $1.layer
            }
    }
}

struct ASSLiteStyle: Equatable, Sendable {
    var name: String
    var fontName: String
    var fontSize: Double
    var primaryColor: ASSLiteColor
    var outlineColor: ASSLiteColor
    var backColor: ASSLiteColor
    var isBold: Bool
    var isItalic: Bool
    var alignment: Int
    var marginL: Double
    var marginR: Double
    var marginV: Double
    var outline: Double
    var shadow: Double

    static let fallback = ASSLiteStyle(
        name: "Default",
        fontName: "Arial",
        fontSize: 48,
        primaryColor: ASSLiteColor(red: 1, green: 1, blue: 1, alpha: 1),
        outlineColor: ASSLiteColor(red: 0, green: 0, blue: 0, alpha: 1),
        backColor: ASSLiteColor(red: 0, green: 0, blue: 0, alpha: 0.75),
        isBold: false,
        isItalic: false,
        alignment: 2,
        marginL: 20,
        marginR: 20,
        marginV: 20,
        outline: 2,
        shadow: 0
    )
}

struct ASSLiteDialogue: Equatable, Sendable {
    var layer: Int
    var sourceOrder: Int
    var startMilliseconds: Int
    var endMilliseconds: Int
    var styleName: String
    var marginL: Double?
    var marginR: Double?
    var marginV: Double?
    var alignmentOverride: Int?
    var text: String

    func isActive(atMilliseconds milliseconds: Int) -> Bool {
        milliseconds >= startMilliseconds && milliseconds < endMilliseconds
    }
}

struct ASSLiteColor: Equatable, Sendable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    init(red: Double, green: Double, blue: Double, alpha: Double) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    init?(assText: String) {
        let trimmed = assText.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized: String

        if trimmed.lowercased().hasPrefix("&h") {
            normalized = String(trimmed.dropFirst(2))
        } else if trimmed.lowercased().hasPrefix("h") {
            normalized = String(trimmed.dropFirst())
        } else if let decimal = UInt32(trimmed) {
            self.init(assValue: decimal)
            return
        } else {
            normalized = trimmed
        }

        guard let value = UInt32(normalized, radix: 16) else {
            return nil
        }

        self.init(assValue: value)
    }

    private init(assValue value: UInt32) {
        let alphaByte: UInt32
        let blueByte: UInt32
        let greenByte: UInt32
        let redByte: UInt32

        if value > 0x00FF_FFFF {
            alphaByte = (value >> 24) & 0xFF
            blueByte = (value >> 16) & 0xFF
            greenByte = (value >> 8) & 0xFF
            redByte = value & 0xFF
        } else {
            alphaByte = 0
            blueByte = (value >> 16) & 0xFF
            greenByte = (value >> 8) & 0xFF
            redByte = value & 0xFF
        }

        red = Double(redByte) / 255
        green = Double(greenByte) / 255
        blue = Double(blueByte) / 255
        alpha = 1 - (Double(alphaByte) / 255)
    }
}

enum ASSLiteParser {
    static func parse(_ contents: String) -> ASSLiteScript {
        var parser = Parser(contents: contents)
        return parser.parse()
    }

    private struct Parser {
        var contents: String
        var section: Section = .unknown
        var playResX: Double?
        var playResY: Double?
        var styleFormat = ASSLiteParser.defaultStyleFormat
        var eventFormat = ASSLiteParser.defaultEventFormat
        var styles: [String: ASSLiteStyle] = [:]
        var dialogues: [ASSLiteDialogue] = []

        mutating func parse() -> ASSLiteScript {
            let normalized = contents
                .replacingOccurrences(of: "\u{feff}", with: "")
                .replacingOccurrences(of: "\r\n", with: "\n")
                .replacingOccurrences(of: "\r", with: "\n")

            for rawLine in normalized.split(separator: "\n", omittingEmptySubsequences: false) {
                parseLine(String(rawLine))
            }

            return ASSLiteScript(
                playResX: playResX,
                playResY: playResY,
                styles: styles,
                dialogues: dialogues
            )
        }

        mutating func parseLine(_ rawLine: String) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty, !line.hasPrefix(";") else {
                return
            }

            if line.hasPrefix("[") && line.hasSuffix("]") {
                section = Section(rawValue: line.lowercased()) ?? .unknown
                return
            }

            switch section {
            case .scriptInfo:
                parseScriptInfo(line)
            case .styles:
                parseStyleLine(line)
            case .events:
                parseEventLine(line)
            case .unknown:
                return
            }
        }

        mutating func parseScriptInfo(_ line: String) {
            guard let separator = line.firstIndex(of: ":") else {
                return
            }

            let key = line[..<separator].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let value = line[line.index(after: separator)...].trimmingCharacters(in: .whitespacesAndNewlines)

            switch key {
            case "playresx":
                playResX = Double(value)
            case "playresy":
                playResY = Double(value)
            default:
                return
            }
        }

        mutating func parseStyleLine(_ line: String) {
            if line.lowercased().hasPrefix("format:") {
                styleFormat = ASSLiteParser.parseFormat(String(line.dropFirst("format:".count)))
                return
            }

            guard line.lowercased().hasPrefix("style:") else {
                return
            }

            let fields = ASSLiteParser.splitFields(
                String(line.dropFirst("style:".count)),
                expectedCount: styleFormat.count
            )
            guard fields.count == styleFormat.count,
                  let name = ASSLiteParser.value(named: "name", fields: fields, format: styleFormat),
                  !name.isEmpty
            else {
                return
            }

            let fallback = ASSLiteStyle.fallback
            let style = ASSLiteStyle(
                name: name,
                fontName: ASSLiteParser.value(named: "fontname", fields: fields, format: styleFormat) ?? fallback.fontName,
                fontSize: ASSLiteParser.doubleValue(named: "fontsize", fields: fields, format: styleFormat) ?? fallback.fontSize,
                primaryColor: ASSLiteParser.colorValue(named: "primarycolour", fields: fields, format: styleFormat) ?? fallback.primaryColor,
                outlineColor: ASSLiteParser.colorValue(named: "outlinecolour", fields: fields, format: styleFormat) ?? fallback.outlineColor,
                backColor: ASSLiteParser.colorValue(named: "backcolour", fields: fields, format: styleFormat) ?? fallback.backColor,
                isBold: ASSLiteParser.boolValue(named: "bold", fields: fields, format: styleFormat),
                isItalic: ASSLiteParser.boolValue(named: "italic", fields: fields, format: styleFormat),
                alignment: ASSLiteParser.intValue(named: "alignment", fields: fields, format: styleFormat) ?? fallback.alignment,
                marginL: ASSLiteParser.doubleValue(named: "marginl", fields: fields, format: styleFormat) ?? fallback.marginL,
                marginR: ASSLiteParser.doubleValue(named: "marginr", fields: fields, format: styleFormat) ?? fallback.marginR,
                marginV: ASSLiteParser.doubleValue(named: "marginv", fields: fields, format: styleFormat) ?? fallback.marginV,
                outline: ASSLiteParser.doubleValue(named: "outline", fields: fields, format: styleFormat) ?? fallback.outline,
                shadow: ASSLiteParser.doubleValue(named: "shadow", fields: fields, format: styleFormat) ?? fallback.shadow
            )

            styles[name] = style
        }

        mutating func parseEventLine(_ line: String) {
            if line.lowercased().hasPrefix("format:") {
                eventFormat = ASSLiteParser.parseFormat(String(line.dropFirst("format:".count)))
                return
            }

            guard line.lowercased().hasPrefix("dialogue:") else {
                return
            }

            let fields = ASSLiteParser.splitFields(
                String(line.dropFirst("dialogue:".count)),
                expectedCount: eventFormat.count
            )
            guard fields.count == eventFormat.count,
                  let startTimecode = ASSLiteParser.value(named: "start", fields: fields, format: eventFormat),
                  let endTimecode = ASSLiteParser.value(named: "end", fields: fields, format: eventFormat),
                  let startMilliseconds = ASSLiteParser.milliseconds(from: startTimecode),
                  let endMilliseconds = ASSLiteParser.milliseconds(from: endTimecode),
                  endMilliseconds >= startMilliseconds,
                  let rawText = ASSLiteParser.value(named: "text", fields: fields, format: eventFormat)
            else {
                return
            }

            let parsedText = ASSLiteParser.parseVisibleText(rawText)
            guard !parsedText.text.isEmpty else {
                return
            }

            dialogues.append(
                ASSLiteDialogue(
                    layer: ASSLiteParser.intValue(named: "layer", fields: fields, format: eventFormat) ?? 0,
                    sourceOrder: dialogues.count,
                    startMilliseconds: startMilliseconds,
                    endMilliseconds: endMilliseconds,
                    styleName: ASSLiteParser.value(named: "style", fields: fields, format: eventFormat) ?? "Default",
                    marginL: ASSLiteParser.positiveEventMargin(named: "marginl", fields: fields, format: eventFormat),
                    marginR: ASSLiteParser.positiveEventMargin(named: "marginr", fields: fields, format: eventFormat),
                    marginV: ASSLiteParser.positiveEventMargin(named: "marginv", fields: fields, format: eventFormat),
                    alignmentOverride: parsedText.alignmentOverride,
                    text: parsedText.text
                )
            )
        }
    }

    private enum Section: String {
        case scriptInfo = "[script info]"
        case styles = "[v4+ styles]"
        case events = "[events]"
        case unknown
    }

    private static let defaultStyleFormat = [
        "name", "fontname", "fontsize", "primarycolour", "secondarycolour",
        "outlinecolour", "backcolour", "bold", "italic", "underline",
        "strikeout", "scalex", "scaley", "spacing", "angle", "borderstyle",
        "outline", "shadow", "alignment", "marginl", "marginr", "marginv",
        "encoding"
    ]

    private static let defaultEventFormat = [
        "layer", "start", "end", "style", "name", "marginl", "marginr",
        "marginv", "effect", "text"
    ]

    private static func parseFormat(_ text: String) -> [String] {
        text.split(separator: ",", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
    }

    private static func splitFields(_ text: String, expectedCount: Int) -> [String] {
        guard expectedCount > 1 else {
            return [text.trimmingCharacters(in: .whitespacesAndNewlines)]
        }

        return text
            .split(separator: ",", maxSplits: expectedCount - 1, omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    private static func value(named name: String, fields: [String], format: [String]) -> String? {
        guard let index = format.firstIndex(of: name),
              fields.indices.contains(index)
        else {
            return nil
        }

        return fields[index]
    }

    private static func intValue(named name: String, fields: [String], format: [String]) -> Int? {
        value(named: name, fields: fields, format: format).flatMap(Int.init)
    }

    private static func doubleValue(named name: String, fields: [String], format: [String]) -> Double? {
        value(named: name, fields: fields, format: format).flatMap(Double.init)
    }

    private static func boolValue(named name: String, fields: [String], format: [String]) -> Bool {
        guard let value = intValue(named: name, fields: fields, format: format) else {
            return false
        }

        return value != 0
    }

    private static func colorValue(named name: String, fields: [String], format: [String]) -> ASSLiteColor? {
        value(named: name, fields: fields, format: format).flatMap(ASSLiteColor.init(assText:))
    }

    private static func positiveEventMargin(named name: String, fields: [String], format: [String]) -> Double? {
        guard let value = doubleValue(named: name, fields: fields, format: format),
              value > 0
        else {
            return nil
        }

        return value
    }

    private static func milliseconds(from timecode: String) -> Int? {
        let trimmed = timecode.trimmingCharacters(in: .whitespacesAndNewlines)
        let hourParts = trimmed.split(separator: ":", omittingEmptySubsequences: false)

        guard hourParts.count == 3,
              let hours = Int(hourParts[0]),
              let minutes = Int(hourParts[1]),
              minutes >= 0,
              minutes < 60
        else {
            return nil
        }

        let secondParts = hourParts[2].split(separator: ".", omittingEmptySubsequences: false)
        guard secondParts.count == 2,
              let seconds = Int(secondParts[0]),
              seconds >= 0,
              seconds < 60,
              let fraction = Int(secondParts[1])
        else {
            return nil
        }

        let fractionText = String(secondParts[1])
        let milliseconds: Int
        switch fractionText.count {
        case 1:
            milliseconds = fraction * 100
        case 2:
            milliseconds = fraction * 10
        case 3:
            milliseconds = fraction
        default:
            return nil
        }

        guard milliseconds >= 0, milliseconds < 1_000 else {
            return nil
        }

        return (((hours * 60) + minutes) * 60 + seconds) * 1_000 + milliseconds
    }

    private static func parseVisibleText(_ rawText: String) -> (text: String, alignmentOverride: Int?) {
        var visibleText = ""
        var overrideText = ""
        var alignmentOverride: Int?
        var isInsideOverride = false

        for character in rawText {
            if character == "{" {
                isInsideOverride = true
                overrideText = ""
            } else if character == "}" {
                if alignmentOverride == nil {
                    alignmentOverride = inlineAlignment(in: overrideText)
                }
                isInsideOverride = false
            } else if isInsideOverride {
                overrideText.append(character)
            } else {
                visibleText.append(character)
            }
        }

        let normalizedText = visibleText
            .replacingOccurrences(of: "\\N", with: "\n")
            .replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "\\h", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return (normalizedText, alignmentOverride)
    }

    private static func inlineAlignment(in overrideText: String) -> Int? {
        guard let regex = try? NSRegularExpression(pattern: #"\\an([1-9])"#) else {
            return nil
        }

        let range = NSRange(overrideText.startIndex..<overrideText.endIndex, in: overrideText)
        guard let match = regex.firstMatch(in: overrideText, range: range),
              let alignmentRange = Range(match.range(at: 1), in: overrideText)
        else {
            return nil
        }

        return Int(overrideText[alignmentRange])
    }
}
