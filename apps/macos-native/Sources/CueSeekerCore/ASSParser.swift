import Foundation

public enum ASSParsingError: Error, Equatable, Sendable {
    case malformedDialogue
}

public enum ASSParser {
    public static func parseCueGroups(_ contents: String) -> [SubtitleCueGroup] {
        var parser = Parser(contents: contents)
        return parser.parse()
    }

    public static func parseCueGroupsForIndexing(_ contents: String) throws -> [SubtitleCueGroup] {
        var parser = Parser(contents: contents)
        let groups = parser.parse()
        guard parser.malformedDialogueCount == 0 else {
            throw ASSParsingError.malformedDialogue
        }
        return groups
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
        var seenCueLineKeys = Set<ParsedCueLineDeduplicationKey>()
        var malformedDialogueCount = 0
        var nextDialogueEventIndex = 0

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
                fontSize: value(named: "fontsize", fields: fields, format: styleFormat).flatMap(Double.init),
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

            guard line.lowercased().hasPrefix("dialogue:") else {
                return
            }
            guard !eventFormat.isEmpty else {
                malformedDialogueCount += 1
                return
            }

            let eventIndex = nextDialogueEventIndex
            nextDialogueEventIndex += 1
            let fields = splitFields(String(line.dropFirst("dialogue:".count)), expectedCount: eventFormat.count)
            guard fields.count == eventFormat.count,
                  let startTimecode = value(named: "start", fields: fields, format: eventFormat),
                  let endTimecode = value(named: "end", fields: fields, format: eventFormat),
                  let startMilliseconds = ASSParser.milliseconds(from: startTimecode),
                  let endMilliseconds = ASSParser.milliseconds(from: endTimecode),
                  let rawText = value(named: "text", fields: fields, format: eventFormat)
            else {
                malformedDialogueCount += 1
                return
            }

            guard endMilliseconds >= startMilliseconds,
                  endMilliseconds - startMilliseconds >= SubtitleCueIndexingRules.minimumDurationMilliseconds
            else {
                return
            }

            let content = ASSParser.cleanText(rawText)
            guard !content.isEmpty else {
                return
            }

            let sourceStyle = value(named: "style", fields: fields, format: eventFormat)
            let sourceLayer = value(named: "layer", fields: fields, format: eventFormat).flatMap(Int.init)
            let sourceIdentityRemainder = identityRemainder(
                fields: fields,
                format: eventFormat
            )
            let layout = layoutMetadata(
                rawText: rawText,
                styleName: sourceStyle,
                effect: value(named: "effect", fields: fields, format: eventFormat),
                marginL: value(named: "marginl", fields: fields, format: eventFormat).flatMap(Double.init),
                marginR: value(named: "marginr", fields: fields, format: eventFormat).flatMap(Double.init),
                marginV: value(named: "marginv", fields: fields, format: eventFormat).flatMap(Double.init)
            )

            let parsedLine = ParsedCueLine(
                eventIndex: eventIndex,
                sourceStyle: sourceStyle?.isEmpty == true ? nil : sourceStyle,
                sourceLayer: sourceLayer,
                sourceIdentityRemainder: sourceIdentityRemainder,
                startTimecode: startTimecode.trimmingCharacters(in: .whitespacesAndNewlines),
                endTimecode: endTimecode.trimmingCharacters(in: .whitespacesAndNewlines),
                startMilliseconds: startMilliseconds,
                endMilliseconds: endMilliseconds,
                content: content,
                layout: layout
            )
            let key = ParsedCueLineDeduplicationKey(line: parsedLine)
            guard seenCueLineKeys.insert(key).inserted else {
                return
            }

            parsedLines.append(parsedLine)
        }

        func layoutMetadata(
            rawText: String,
            styleName: String?,
            effect: String?,
            marginL eventMarginL: Double?,
            marginR eventMarginR: Double?,
            marginV eventMarginV: Double?
        ) -> ASSLayoutMetadata {
            let style = styleName.flatMap { styles[$0] }
            let explicitPosition = inlinePosition(in: rawText)
            let effectiveAlignment = inlineAlignment(in: rawText) ?? style?.alignment
            let effectiveFontSize = inlineFontSize(in: rawText) ?? style?.fontSize
            let marginL = positive(eventMarginL) ?? style?.marginL ?? 0
            let marginR = positive(eventMarginR) ?? style?.marginR ?? 0
            let marginV = positive(eventMarginV) ?? style?.marginV ?? 0
            let projection = layoutProjection(
                explicitPosition: explicitPosition,
                effectiveAlignment: effectiveAlignment,
                marginL: marginL,
                marginR: marginR,
                marginV: marginV
            )

            return ASSLayoutMetadata(
                effectiveFontSize: effectiveFontSize,
                effectiveAlignment: effectiveAlignment,
                explicitPosition: explicitPosition,
                detectsCollisions: explicitPosition == nil
                    && !disablesCollisionDetection(rawText: rawText, effect: effect),
                displayX: projection.x,
                displayY: projection.y
            )
        }

        func layoutProjection(
            explicitPosition: ASSPoint?,
            effectiveAlignment: Int?,
            marginL: Double,
            marginR: Double,
            marginV: Double
        ) -> (x: Double?, y: Double?) {
            if let explicitPosition {
                return (explicitPosition.x, explicitPosition.y)
            }

            guard let effectiveAlignment,
                  let playResY
            else {
                return (nil, nil)
            }

            let y: Double
            switch effectiveAlignment {
            case 7, 8, 9:
                y = marginV
            case 4, 5, 6:
                y = playResY / 2
            default:
                y = playResY - marginV
            }

            let x: Double?
            if let playResX {
                switch effectiveAlignment {
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
                    startMilliseconds: line.startMilliseconds,
                    endMilliseconds: line.endMilliseconds
                )
            }

            return groups
                .map { key, lines in
                    let sortedLines = sortedCueLines(lines)
                    let sourceTime = sortedLines[0]
                    let cueLines = sortedLines.enumerated().map { displayOrder, line in
                        SubtitleCueLine(
                            eventIndex: line.eventIndex,
                            sourceFormat: .ass,
                            sourceStyle: line.sourceStyle,
                            sourceLayer: line.sourceLayer,
                            sourceIdentityRemainder: line.sourceIdentityRemainder,
                            startTimecode: line.startTimecode,
                            endTimecode: line.endTimecode,
                            startMilliseconds: line.startMilliseconds,
                            endMilliseconds: line.endMilliseconds,
                            content: line.content,
                            displayX: line.layout.displayX,
                            displayY: line.layout.displayY,
                            displayOrder: displayOrder
                        )
                    }

                    return SubtitleCueGroup(
                        sequenceNumber: nil,
                        startTimecode: sourceTime.startTimecode,
                        endTimecode: sourceTime.endTimecode,
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
            collisionPlacedLines(lines)
                .sorted { comparePlacedCueLines($0, $1) }
                .map(\.line)
        }

        func identityRemainder(fields: [String], format: [String]) -> String {
            let excludedFields: Set<String> = ["start", "end", "style", "text"]
            var components: [(name: String, index: Int, value: String)] = []
            for (index, name) in format.enumerated()
                where !excludedFields.contains(name)
            {
                components.append((name: name, index: index, value: fields[index]))
            }
            components.sort {
                $0.name == $1.name ? $0.index < $1.index : $0.name < $1.name
            }
            return components.map { component in
                "\(component.name.utf8.count):\(component.name)"
                    + "\(component.value.utf8.count):\(component.value)"
            }.joined()
        }

        func collisionPlacedLines(_ lines: [ParsedCueLine]) -> [CollisionPlacedLine] {
            var placedLines = lines.map { line in
                CollisionPlacedLine(line: line, rect: collisionRect(for: line))
            }
            let indicesByLayer = Dictionary(grouping: placedLines.indices) { index in
                placedLines[index].line.sourceLayer ?? 0
            }

            for indices in indicesByLayer.values {
                let orderedIndices = indices.sorted {
                    placedLines[$0].line.eventIndex < placedLines[$1].line.eventIndex
                }
                var usedRects: [CollisionRect] = []

                for index in orderedIndices {
                    guard placedLines[index].line.layout.detectsCollisions,
                          var rect = placedLines[index].rect
                    else {
                        continue
                    }

                    let shift = collisionShift(for: rect, usedRects: usedRects)
                    if shift != 0 {
                        rect = rect.shifted(by: shift)
                        placedLines[index].rect = rect
                    }

                    usedRects.append(rect)
                    usedRects.sort { $0.y0 < $1.y0 }
                }
            }

            return placedLines
        }

        func collisionShift(for rect: CollisionRect, usedRects: [CollisionRect]) -> Double {
            var shift = 0.0
            let candidates = rect.shiftDirection == .down ? usedRects : usedRects.reversed()

            for usedRect in candidates {
                guard rect.shifted(by: shift).overlaps(usedRect) else {
                    continue
                }

                switch rect.shiftDirection {
                case .down:
                    shift = usedRect.y1 - rect.y0
                case .up:
                    shift = usedRect.y0 - rect.y1
                }
            }

            return shift
        }

        func collisionRect(for line: ParsedCueLine) -> CollisionRect? {
            guard let displayX = line.layout.displayX,
                  let displayY = line.layout.displayY
            else {
                return nil
            }

            let fontSize = line.layout.effectiveFontSize ?? 20
            let lineCount = max(1, line.content.components(separatedBy: .newlines).count)
            let height = max(1, fontSize * 1.2 * Double(lineCount))
            let width = max(1, estimatedTextWidth(line.content, fontSize: fontSize))
            let alignment = line.layout.effectiveAlignment ?? 2

            let x0: Double
            switch horizontalAlignment(for: alignment) {
            case .left:
                x0 = displayX
            case .center:
                x0 = displayX - (width / 2)
            case .right:
                x0 = displayX - width
            }

            let y0: Double
            let shiftDirection: CollisionShiftDirection
            switch verticalAlignment(for: alignment) {
            case .top:
                y0 = displayY
                shiftDirection = .down
            case .middle:
                y0 = displayY - (height / 2)
                shiftDirection = .down
            case .bottom:
                y0 = displayY - height
                shiftDirection = .up
            }

            return CollisionRect(
                x0: x0,
                y0: y0,
                x1: x0 + width,
                y1: y0 + height,
                shiftDirection: shiftDirection
            )
        }

        func comparePlacedCueLines(_ lhs: CollisionPlacedLine, _ rhs: CollisionPlacedLine) -> Bool {
            switch (lhs.rect?.y0, rhs.rect?.y0) {
            case let (lhsY?, rhsY?) where lhsY != rhsY:
                return lhsY < rhsY
            case (.some, nil):
                return true
            case (nil, .some):
                return false
            default:
                break
            }

            switch (lhs.rect?.x0, rhs.rect?.x0) {
            case let (lhsX?, rhsX?) where lhsX != rhsX:
                return lhsX < rhsX
            case (.some, nil):
                return true
            case (nil, .some):
                return false
            default:
                return lhs.line.eventIndex < rhs.line.eventIndex
            }
        }

        func inlineAlignment(in text: String) -> Int? {
            firstOverrideMatch(in: text, pattern: #"\\an([1-9])"#).flatMap(Int.init)
        }

        func inlinePosition(in text: String) -> ASSPoint? {
            if let match = firstOverrideMatch(in: text, pattern: #"\\pos\(([-0-9.]+),\s*([-0-9.]+)\)"#),
               let separator = match.firstIndex(of: ",") {
                let xText = match[..<separator]
                let yText = match[match.index(after: separator)...].trimmingCharacters(in: .whitespacesAndNewlines)
                if let x = Double(xText), let y = Double(yText) {
                    return ASSPoint(x: x, y: y)
                }
            }

            if let match = firstOverrideMatch(in: text, pattern: #"\\move\(([-0-9.]+),\s*([-0-9.]+),"#),
               let separator = match.firstIndex(of: ",") {
                let xText = match[..<separator]
                let yText = match[match.index(after: separator)...].trimmingCharacters(in: .whitespacesAndNewlines)
                if let x = Double(xText), let y = Double(yText) {
                    return ASSPoint(x: x, y: y)
                }
            }

            return nil
        }

        func inlineFontSize(in text: String) -> Double? {
            guard let match = firstOverrideMatch(in: text, pattern: #"\\fs(?!c)([-+]?[0-9.]+)"#),
                  !match.hasPrefix("+"),
                  !match.hasPrefix("-"),
                  let fontSize = Double(match),
                  fontSize > 0
            else {
                return nil
            }

            return fontSize
        }

        func disablesCollisionDetection(rawText: String, effect: String?) -> Bool {
            hasOverrideMatch(in: rawText, pattern: #"\\(?:org|t)\b"#)
                || effectDisablesCollisionDetection(effect)
        }

        func effectDisablesCollisionDetection(_ effect: String?) -> Bool {
            guard let effect else {
                return false
            }

            let normalized = effect.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return normalized.hasPrefix("banner;")
                || normalized.hasPrefix("scroll up;")
                || normalized.hasPrefix("scroll down;")
        }

        func estimatedTextWidth(_ text: String, fontSize: Double) -> Double {
            let widestLine = text.components(separatedBy: .newlines)
                .map { line in
                    line.unicodeScalars.reduce(0.0) { width, scalar in
                        width + estimatedCharacterWidth(scalar, fontSize: fontSize)
                    }
                }
                .max() ?? 0
            return max(fontSize, widestLine)
        }

        func estimatedCharacterWidth(_ scalar: UnicodeScalar, fontSize: Double) -> Double {
            if CharacterSet.whitespacesAndNewlines.contains(scalar) {
                return fontSize * 0.33
            }
            if scalar.value >= 0x1100 {
                return fontSize
            }
            return fontSize * 0.58
        }

        func hasOverrideMatch(in text: String, pattern: String) -> Bool {
            guard let regex = try? NSRegularExpression(pattern: pattern) else {
                return false
            }

            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            return regex.firstMatch(in: text, range: range) != nil
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
        let fontSize: Double?
        let alignment: Int?
        let marginL: Double?
        let marginR: Double?
        let marginV: Double?
    }

    private struct ASSPoint {
        let x: Double
        let y: Double
    }

    private struct ASSLayoutMetadata {
        let effectiveFontSize: Double?
        let effectiveAlignment: Int?
        let explicitPosition: ASSPoint?
        let detectsCollisions: Bool
        let displayX: Double?
        let displayY: Double?
    }

    private struct CollisionPlacedLine {
        let line: ParsedCueLine
        var rect: CollisionRect?
    }

    private struct CollisionRect {
        let x0: Double
        let y0: Double
        let x1: Double
        let y1: Double
        let shiftDirection: CollisionShiftDirection

        func shifted(by offset: Double) -> CollisionRect {
            CollisionRect(
                x0: x0,
                y0: y0 + offset,
                x1: x1,
                y1: y1 + offset,
                shiftDirection: shiftDirection
            )
        }

        func overlaps(_ other: CollisionRect) -> Bool {
            !(y0 >= other.y1 || other.y0 >= y1 || x0 >= other.x1 || other.x0 >= x1)
        }
    }

    private enum CollisionShiftDirection {
        case up
        case down
    }

    private enum ASSHorizontalAlignment {
        case left
        case center
        case right
    }

    private enum ASSVerticalAlignment {
        case top
        case middle
        case bottom
    }

    private struct ParsedCueLine {
        let eventIndex: Int
        let sourceStyle: String?
        let sourceLayer: Int?
        let sourceIdentityRemainder: String
        let startTimecode: String
        let endTimecode: String
        let startMilliseconds: Int
        let endMilliseconds: Int
        let content: String
        let layout: ASSLayoutMetadata
    }

    private struct ParsedCueLineDeduplicationKey: Hashable {
        let sourceStyle: String?
        let sourceIdentityRemainder: String
        let startMilliseconds: Int
        let endMilliseconds: Int
        let content: String

        init(line: ParsedCueLine) {
            sourceStyle = line.sourceStyle
            sourceIdentityRemainder = line.sourceIdentityRemainder
            startMilliseconds = line.startMilliseconds
            endMilliseconds = line.endMilliseconds
            content = line.content
        }
    }

    private struct CueGroupKey: Hashable {
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

    private static func horizontalAlignment(for alignment: Int) -> ASSHorizontalAlignment {
        switch alignment {
        case 1, 4, 7:
            return .left
        case 3, 6, 9:
            return .right
        default:
            return .center
        }
    }

    private static func verticalAlignment(for alignment: Int) -> ASSVerticalAlignment {
        switch alignment {
        case 7, 8, 9:
            return .top
        case 4, 5, 6:
            return .middle
        default:
            return .bottom
        }
    }
}
