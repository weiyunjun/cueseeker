import Foundation

public struct SubtitleSpeakerDisplayCue: Equatable, Sendable {
    public let cueGroupID: Int64
    public let startMilliseconds: Int
    public let endMilliseconds: Int
    public let sourceStyle: String?
    public let sourceLayer: Int?
    public let cleanText: String
    public let speakers: Set<String>

    public init(
        cueGroupID: Int64,
        startMilliseconds: Int,
        endMilliseconds: Int,
        sourceStyle: String?,
        sourceLayer: Int?,
        cleanText: String,
        speakers: Set<String>
    ) {
        self.cueGroupID = cueGroupID
        self.startMilliseconds = max(0, startMilliseconds)
        self.endMilliseconds = max(self.startMilliseconds, endMilliseconds)
        let normalizedStyle = sourceStyle?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.sourceStyle = normalizedStyle?.isEmpty == true ? nil : normalizedStyle
        self.sourceLayer = sourceLayer
        self.cleanText = cleanText.trimmingCharacters(in: .whitespacesAndNewlines)
        self.speakers = speakers
    }

    public static func targetCues(
        records: [SubtitleCueLineRecord],
        speakersByCueGroupID: [Int64: Set<String>]
    ) -> [SubtitleSpeakerDisplayCue] {
        Dictionary(grouping: records, by: \.cueGroupID)
            .compactMap { cueGroupID, groupRecords -> SubtitleSpeakerDisplayCue? in
                guard let speakers = speakersByCueGroupID[cueGroupID],
                      !speakers.isEmpty,
                      let target = groupRecords
                        .filter({ !$0.line.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
                        .sorted(by: targetLineSort)
                        .first
                else {
                    return nil
                }

                return SubtitleSpeakerDisplayCue(
                    cueGroupID: cueGroupID,
                    startMilliseconds: target.line.startMilliseconds,
                    endMilliseconds: target.line.endMilliseconds,
                    sourceStyle: target.line.sourceStyle,
                    sourceLayer: target.line.sourceLayer,
                    cleanText: target.line.content,
                    speakers: speakers
                )
            }
            .sorted {
                if $0.startMilliseconds == $1.startMilliseconds {
                    return $0.cueGroupID < $1.cueGroupID
                }

                return $0.startMilliseconds < $1.startMilliseconds
            }
    }

    public static func targetCues(
        records: [SubtitleCueLineRecord],
        speakersByCueLineID: [Int64: Set<String>]
    ) -> [SubtitleSpeakerDisplayCue] {
        records
            .compactMap { record -> SubtitleSpeakerDisplayCue? in
                guard let speakers = speakersByCueLineID[record.id],
                      !speakers.isEmpty,
                      !record.line.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                else {
                    return nil
                }

                return SubtitleSpeakerDisplayCue(
                    cueGroupID: record.cueGroupID,
                    startMilliseconds: record.line.startMilliseconds,
                    endMilliseconds: record.line.endMilliseconds,
                    sourceStyle: record.line.sourceStyle,
                    sourceLayer: record.line.sourceLayer,
                    cleanText: record.line.content,
                    speakers: speakers
                )
            }
            .sorted(by: targetCueSort)
    }

    private static func targetLineSort(_ lhs: SubtitleCueLineRecord, _ rhs: SubtitleCueLineRecord) -> Bool {
        if lhs.line.displayOrder != rhs.line.displayOrder {
            return lhs.line.displayOrder < rhs.line.displayOrder
        }
        if lhs.line.eventIndex != rhs.line.eventIndex {
            return lhs.line.eventIndex < rhs.line.eventIndex
        }

        return lhs.id < rhs.id
    }

    private static func targetCueSort(_ lhs: SubtitleSpeakerDisplayCue, _ rhs: SubtitleSpeakerDisplayCue) -> Bool {
        if lhs.startMilliseconds != rhs.startMilliseconds {
            return lhs.startMilliseconds < rhs.startMilliseconds
        }
        if lhs.cueGroupID != rhs.cueGroupID {
            return lhs.cueGroupID < rhs.cueGroupID
        }
        if lhs.endMilliseconds != rhs.endMilliseconds {
            return lhs.endMilliseconds < rhs.endMilliseconds
        }
        if lhs.sourceLayer != rhs.sourceLayer {
            return (lhs.sourceLayer ?? Int.min) < (rhs.sourceLayer ?? Int.min)
        }
        if lhs.sourceStyle != rhs.sourceStyle {
            return (lhs.sourceStyle ?? "") < (rhs.sourceStyle ?? "")
        }

        return lhs.cleanText < rhs.cleanText
    }
}

public enum SubtitleSpeakerDisplayFormatter {
    public static let suspectedSpeakerPrefix = "疑似"

    public static func orderedSpeakers(_ speakers: Set<String>) -> [String] {
        let labels = speakers
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let regular = labels
            .filter { !$0.hasPrefix(suspectedSpeakerPrefix) }
            .sorted(by: localizedSpeakerSort)
        let suspected = labels
            .filter { $0.hasPrefix(suspectedSpeakerPrefix) }
            .sorted(by: localizedSpeakerSort)
        return regular + suspected
    }

    public static func speakerPrefix(for speakers: Set<String>) -> String? {
        let orderedSpeakers = orderedSpeakers(speakers)
        guard !orderedSpeakers.isEmpty else {
            return nil
        }

        return orderedSpeakers.joined(separator: ",")
    }

    public static func prefixedText(_ text: String, speakers: Set<String>) -> String {
        guard let prefix = speakerPrefix(for: speakers) else {
            return text
        }

        return "\(prefix): \(text)"
    }

    public static func prefixedASSDialogueText(_ text: String, speakers: Set<String>) -> String {
        guard let prefix = speakerPrefix(for: speakers) else {
            return text
        }

        let insertionIndex = leadingASSOverrideTagEndIndex(in: text)
        return String(text[..<insertionIndex]) + "\(prefix): " + String(text[insertionIndex...])
    }

    private static func localizedSpeakerSort(_ lhs: String, _ rhs: String) -> Bool {
        lhs.localizedStandardCompare(rhs) == .orderedAscending
    }

    private static func leadingASSOverrideTagEndIndex(in text: String) -> String.Index {
        var index = text.startIndex
        while index < text.endIndex, text[index] == "{" {
            guard let closeIndex = text[index...].firstIndex(of: "}") else {
                return index
            }

            let block = text[index...closeIndex]
            guard block.contains("\\") else {
                return index
            }

            index = text.index(after: closeIndex)
        }

        return index
    }
}

public enum ASSSpeakerDisplayRewriter {
    public static func rewrite(script: String, cues: [SubtitleSpeakerDisplayCue]) -> String {
        guard !cues.isEmpty else {
            return script
        }

        var remainingSpeakersByKey = Dictionary(grouping: cues, by: DialogueKey.init)
            .mapValues { $0.map(\.speakers) }
        var context = RewriteContext()
        var rewritten = ""

        for (line, terminator) in script.assLinesWithTerminators() {
            let nextLine = rewrite(
                line: line,
                context: &context,
                remainingSpeakersByKey: &remainingSpeakersByKey
            )
            rewritten += nextLine
            rewritten += terminator
        }

        return rewritten
    }

    private static func rewrite(
        line: String,
        context: inout RewriteContext,
        remainingSpeakersByKey: inout [DialogueKey: [Set<String>]]
    ) -> String {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercased = trimmed.lowercased()

        if lowercased.hasPrefix("[") && lowercased.hasSuffix("]") {
            context.isInEventsSection = lowercased == "[events]"
            return line
        }

        guard context.isInEventsSection else {
            return line
        }

        if lowercased.hasPrefix("format:") {
            let body = String(line.dropFirst(linePrefixLength(before: ":", in: line)))
            context.eventFormat = parseFormat(body)
            return line
        }

        guard lowercased.hasPrefix("dialogue:"),
              let parsed = parseDialogue(line: line, eventFormat: context.eventFormat),
              var speakerQueue = remainingSpeakersByKey[parsed.key],
              !speakerQueue.isEmpty
        else {
            return line
        }

        let speakers = speakerQueue.removeFirst()
        remainingSpeakersByKey[parsed.key] = speakerQueue
        var fields = parsed.fields
        fields[parsed.textIndex] = SubtitleSpeakerDisplayFormatter.prefixedASSDialogueText(
            fields[parsed.textIndex],
            speakers: speakers
        )
        return String(line[..<parsed.bodyStartIndex]) + fields.joined(separator: ",")
    }

    private static func parseDialogue(line: String, eventFormat: [String]) -> ParsedDialogue? {
        let bodyStartIndex = line.index(line.startIndex, offsetBy: linePrefixLength(before: ":", in: line))
        let body = String(line[bodyStartIndex...])
        let fields = splitFields(body, expectedCount: eventFormat.count)
        guard fields.count == eventFormat.count,
              let startText = value(named: "start", fields: fields, format: eventFormat),
              let endText = value(named: "end", fields: fields, format: eventFormat),
              let startMilliseconds = ASSParser.milliseconds(from: startText),
              let endMilliseconds = ASSParser.milliseconds(from: endText),
              let text = value(named: "text", fields: fields, format: eventFormat),
              let textIndex = eventFormat.firstIndex(of: "text")
        else {
            return nil
        }

        let rawStyle = value(named: "style", fields: fields, format: eventFormat)
        let style = rawStyle?.isEmpty == true ? nil : rawStyle
        let sourceLayer = value(named: "layer", fields: fields, format: eventFormat).flatMap(Int.init)
        let key = DialogueKey(
            startMilliseconds: startMilliseconds,
            endMilliseconds: endMilliseconds,
            sourceStyle: style,
            sourceLayer: sourceLayer,
            cleanText: ASSParser.cleanText(text).trimmingCharacters(in: .whitespacesAndNewlines)
        )
        return ParsedDialogue(
            bodyStartIndex: bodyStartIndex,
            fields: fields,
            textIndex: textIndex,
            key: key
        )
    }

    private static func linePrefixLength(before separator: Character, in line: String) -> Int {
        guard let separatorIndex = line.firstIndex(of: separator) else {
            return 0
        }

        return line.distance(from: line.startIndex, to: line.index(after: separatorIndex))
    }

    private static func parseFormat(_ text: String) -> [String] {
        let fields = text
            .split(separator: ",", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
        return fields.isEmpty ? RewriteContext.defaultEventFormat : fields
    }

    private static func splitFields(_ text: String, expectedCount: Int) -> [String] {
        guard expectedCount > 1 else {
            return [text]
        }

        return text
            .split(separator: ",", maxSplits: expectedCount - 1, omittingEmptySubsequences: false)
            .map(String.init)
    }

    private static func value(named name: String, fields: [String], format: [String]) -> String? {
        guard let index = format.firstIndex(of: name),
              fields.indices.contains(index)
        else {
            return nil
        }

        return fields[index].trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private struct RewriteContext {
        static let defaultEventFormat = [
            "layer",
            "start",
            "end",
            "style",
            "name",
            "marginl",
            "marginr",
            "marginv",
            "effect",
            "text"
        ]

        var isInEventsSection = false
        var eventFormat = defaultEventFormat
    }

    private struct DialogueKey: Hashable {
        let startMilliseconds: Int
        let endMilliseconds: Int
        let sourceStyle: String?
        let sourceLayer: Int?
        let cleanText: String

        init(
            startMilliseconds: Int,
            endMilliseconds: Int,
            sourceStyle: String?,
            sourceLayer: Int?,
            cleanText: String
        ) {
            self.startMilliseconds = startMilliseconds
            self.endMilliseconds = endMilliseconds
            self.sourceStyle = sourceStyle
            self.sourceLayer = sourceLayer
            self.cleanText = cleanText
        }

        init(_ cue: SubtitleSpeakerDisplayCue) {
            self.init(
                startMilliseconds: cue.startMilliseconds,
                endMilliseconds: cue.endMilliseconds,
                sourceStyle: cue.sourceStyle,
                sourceLayer: cue.sourceLayer,
                cleanText: cue.cleanText
            )
        }
    }

    private struct ParsedDialogue {
        let bodyStartIndex: String.Index
        let fields: [String]
        let textIndex: Int
        let key: DialogueKey
    }
}

private extension String {
    func assLinesWithTerminators() -> [(line: String, terminator: String)] {
        var result: [(line: String, terminator: String)] = []
        var lineStart = startIndex

        while lineStart < endIndex {
            guard let newlineIndex = self[lineStart...].firstIndex(of: "\n") else {
                result.append((String(self[lineStart...]), ""))
                return result
            }

            let lineEnd: String.Index
            let terminator: String
            if newlineIndex > lineStart {
                let beforeNewline = index(before: newlineIndex)
                if self[beforeNewline] == "\r" {
                    lineEnd = beforeNewline
                    terminator = "\r\n"
                } else {
                    lineEnd = newlineIndex
                    terminator = "\n"
                }
            } else {
                lineEnd = newlineIndex
                terminator = "\n"
            }

            result.append((String(self[lineStart..<lineEnd]), terminator))
            lineStart = index(after: newlineIndex)
        }

        return result
    }
}
