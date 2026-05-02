import Foundation

public enum ASSParser {
    public static func parseCueGroups(_ contents: String) -> [SubtitleCueGroup] {
        var parser = Parser(contents: contents)
        return parser.parse()
    }

    public static func milliseconds(from timecode: String) -> Int? {
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

    public static func cleanText(_ text: String) -> String {
        var cleaned = ""
        var isInsideOverride = false
        var index = text.startIndex

        while index < text.endIndex {
            let character = text[index]
            if character == "{" {
                isInsideOverride = true
            } else if character == "}" {
                isInsideOverride = false
            } else if !isInsideOverride {
                cleaned.append(character)
            }

            index = text.index(after: index)
        }

        return cleaned
            .replacingOccurrences(of: "\\N", with: "\n")
            .replacingOccurrences(of: "\\n", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private struct Parser {
        var contents: String
        var section: Section = .unknown
        var playResX: Double?
        var playResY: Double?
        var styleFormat: [String] = []
        var styles: [String: ASSStyle] = [:]
        var eventFormat: [String] = []
        var parsedLines: [ParsedCueLine] = []

        mutating func parse() -> [SubtitleCueGroup] {
            let normalized = contents
                .replacingOccurrences(of: "\u{feff}", with: "")
                .replacingOccurrences(of: "\r\n", with: "\n")
                .replacingOccurrences(of: "\r", with: "\n")

            for rawLine in normalized.split(separator: "\n", omittingEmptySubsequences: false) {
                parseLine(String(rawLine))
            }

            return groupedCueLines()
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

            if key == "playresx" {
                playResX = Double(value)
            } else if key == "playresy" {
                playResY = Double(value)
            }
        }

        mutating func parseStyleLine(_ line: String) {
            if line.lowercased().hasPrefix("format:") {
                styleFormat = parseFormat(String(line.dropFirst("format:".count)))
                return
            }

            guard line.lowercased().hasPrefix("style:"),
                  !styleFormat.isEmpty
            else {
                return
            }

            let fields = splitFields(String(line.dropFirst("style:".count)), expectedCount: styleFormat.count)
            guard fields.count == styleFormat.count,
                  let name = value(named: "name", fields: fields, format: styleFormat),
                  !name.isEmpty
            else {
                return
            }

            styles[name] = ASSStyle(
                alignment: value(named: "alignment", fields: fields, format: styleFormat).flatMap(Int.init),
                marginL: value(named: "marginl", fields: fields, format: styleFormat).flatMap(Double.init),
                marginR: value(named: "marginr", fields: fields, format: styleFormat).flatMap(Double.init),
                marginV: value(named: "marginv", fields: fields, format: styleFormat).flatMap(Double.init)
            )
        }

        mutating func parseEventLine(_ line: String) {
            if line.lowercased().hasPrefix("format:") {
                eventFormat = parseFormat(String(line.dropFirst("format:".count)))
                return
            }

            guard line.lowercased().hasPrefix("dialogue:"),
                  !eventFormat.isEmpty
            else {
                return
            }

            let eventIndex = parsedLines.count
            let fields = splitFields(String(line.dropFirst("dialogue:".count)), expectedCount: eventFormat.count)
            guard fields.count == eventFormat.count,
                  let startTimecode = value(named: "start", fields: fields, format: eventFormat),
                  let endTimecode = value(named: "end", fields: fields, format: eventFormat),
                  let startMilliseconds = ASSParser.milliseconds(from: startTimecode),
                  let endMilliseconds = ASSParser.milliseconds(from: endTimecode),
                  endMilliseconds >= startMilliseconds,
                  let rawText = value(named: "text", fields: fields, format: eventFormat)
            else {
                return
            }

            let content = ASSParser.cleanText(rawText)
            guard !content.isEmpty else {
                return
            }

            let sourceStyle = value(named: "style", fields: fields, format: eventFormat)
            let sourceLayer = value(named: "layer", fields: fields, format: eventFormat).flatMap(Int.init)
            let layout = layoutProjection(
                rawText: rawText,
                styleName: sourceStyle,
                marginL: value(named: "marginl", fields: fields, format: eventFormat).flatMap(Double.init),
                marginR: value(named: "marginr", fields: fields, format: eventFormat).flatMap(Double.init),
                marginV: value(named: "marginv", fields: fields, format: eventFormat).flatMap(Double.init)
            )

            parsedLines.append(
                ParsedCueLine(
                    eventIndex: eventIndex,
                    sourceStyle: sourceStyle?.isEmpty == true ? nil : sourceStyle,
                    sourceLayer: sourceLayer,
                    startTimecode: startTimecode.trimmingCharacters(in: .whitespacesAndNewlines),
                    endTimecode: endTimecode.trimmingCharacters(in: .whitespacesAndNewlines),
                    startMilliseconds: startMilliseconds,
                    endMilliseconds: endMilliseconds,
                    content: content,
                    displayX: layout.x,
                    displayY: layout.y
                )
            )
        }

        func layoutProjection(
            rawText: String,
            styleName: String?,
            marginL eventMarginL: Double?,
            marginR eventMarginR: Double?,
            marginV eventMarginV: Double?
        ) -> (x: Double?, y: Double?) {
            if let position = inlinePosition(in: rawText) {
                return position
            }

            let style = styleName.flatMap { styles[$0] }
            let alignment = inlineAlignment(in: rawText) ?? style?.alignment
            guard let alignment,
                  let playResY
            else {
                return (nil, nil)
            }

            let marginL = positive(eventMarginL) ?? style?.marginL ?? 0
            let marginR = positive(eventMarginR) ?? style?.marginR ?? 0
            let marginV = positive(eventMarginV) ?? style?.marginV ?? 0

            let y: Double
            switch alignment {
            case 7, 8, 9:
                y = marginV
            case 4, 5, 6:
                y = playResY / 2
            default:
                y = playResY - marginV
            }

            let x: Double?
            if let playResX {
                switch alignment {
                case 1, 4, 7:
                    x = marginL
                case 3, 6, 9:
                    x = playResX - marginR
                default:
                    x = playResX / 2
                }
            } else {
                x = nil
            }

            return (x, y)
        }

        func groupedCueLines() -> [SubtitleCueGroup] {
            let groups = Dictionary(grouping: parsedLines) { line in
                CueGroupKey(
                    startTimecode: line.startTimecode,
                    endTimecode: line.endTimecode,
                    startMilliseconds: line.startMilliseconds,
                    endMilliseconds: line.endMilliseconds
                )
            }

            return groups
                .map { key, lines in
                    let sortedLines = sortedCueLines(lines)
                    let cueLines = sortedLines.enumerated().map { displayOrder, line in
                        SubtitleCueLine(
                            eventIndex: line.eventIndex,
                            sourceFormat: .ass,
                            sourceStyle: line.sourceStyle,
                            sourceLayer: line.sourceLayer,
                            startTimecode: line.startTimecode,
                            endTimecode: line.endTimecode,
                            startMilliseconds: line.startMilliseconds,
                            endMilliseconds: line.endMilliseconds,
                            content: line.content,
                            displayX: line.displayX,
                            displayY: line.displayY,
                            displayOrder: displayOrder
                        )
                    }

                    return SubtitleCueGroup(
                        sequenceNumber: nil,
                        startTimecode: key.startTimecode,
                        endTimecode: key.endTimecode,
                        startMilliseconds: key.startMilliseconds,
                        endMilliseconds: key.endMilliseconds,
                        searchContent: cueLines.map(\.content).joined(separator: "\n"),
                        cueLines: cueLines
                    )
                }
                .sorted {
                    if $0.startMilliseconds == $1.startMilliseconds {
                        if $0.endMilliseconds == $1.endMilliseconds {
                            return ($0.cueLines.first?.eventIndex ?? 0) < ($1.cueLines.first?.eventIndex ?? 0)
                        }

                        return $0.endMilliseconds < $1.endMilliseconds
                    }

                    return $0.startMilliseconds < $1.startMilliseconds
                }
        }

        func sortedCueLines(_ lines: [ParsedCueLine]) -> [ParsedCueLine] {
            lines.sorted {
                switch ($0.displayY, $1.displayY) {
                case let (lhs?, rhs?) where lhs != rhs:
                    return lhs < rhs
                case (.some, nil):
                    return true
                case (nil, .some):
                    return false
                default:
                    break
                }

                switch ($0.displayX, $1.displayX) {
                case let (lhs?, rhs?) where lhs != rhs:
                    return lhs < rhs
                case (.some, nil):
                    return true
                case (nil, .some):
                    return false
                default:
                    return $0.eventIndex < $1.eventIndex
                }
            }
        }

        func inlineAlignment(in text: String) -> Int? {
            firstOverrideMatch(in: text, pattern: #"\\an([1-9])"#).flatMap(Int.init)
        }

        func inlinePosition(in text: String) -> (x: Double, y: Double)? {
            if let match = firstOverrideMatch(in: text, pattern: #"\\pos\(([-0-9.]+),\s*([-0-9.]+)\)"#),
               let separator = match.firstIndex(of: ",") {
                let xText = match[..<separator]
                let yText = match[match.index(after: separator)...].trimmingCharacters(in: .whitespacesAndNewlines)
                if let x = Double(xText), let y = Double(yText) {
                    return (x, y)
                }
            }

            if let match = firstOverrideMatch(in: text, pattern: #"\\move\(([-0-9.]+),\s*([-0-9.]+),"#),
               let separator = match.firstIndex(of: ",") {
                let xText = match[..<separator]
                let yText = match[match.index(after: separator)...].trimmingCharacters(in: .whitespacesAndNewlines)
                if let x = Double(xText), let y = Double(yText) {
                    return (x, y)
                }
            }

            return nil
        }

        func firstOverrideMatch(in text: String, pattern: String) -> String? {
            guard let regex = try? NSRegularExpression(pattern: pattern) else {
                return nil
            }

            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            guard let match = regex.firstMatch(in: text, range: range),
                  match.numberOfRanges > 1,
                  let swiftRange = Range(match.range(at: 1), in: text)
            else {
                return nil
            }

            if match.numberOfRanges > 2,
               let secondRange = Range(match.range(at: 2), in: text) {
                return "\(text[swiftRange]),\(text[secondRange])"
            }

            return String(text[swiftRange])
        }
    }

    private enum Section: String {
        case scriptInfo = "[script info]"
        case styles = "[v4+ styles]"
        case events = "[events]"
        case unknown
    }

    private struct ASSStyle {
        let alignment: Int?
        let marginL: Double?
        let marginR: Double?
        let marginV: Double?
    }

    private struct ParsedCueLine {
        let eventIndex: Int
        let sourceStyle: String?
        let sourceLayer: Int?
        let startTimecode: String
        let endTimecode: String
        let startMilliseconds: Int
        let endMilliseconds: Int
        let content: String
        let displayX: Double?
        let displayY: Double?
    }

    private struct CueGroupKey: Hashable {
        let startTimecode: String
        let endTimecode: String
        let startMilliseconds: Int
        let endMilliseconds: Int
    }

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

    private static func positive(_ value: Double?) -> Double? {
        guard let value, value > 0 else {
            return nil
        }

        return value
    }
}
