import Foundation

public enum SubtitleSpeakerDisplayDiagnostics {
    public static func log(_ event: String, fields: [String: String] = [:]) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let entry = fields.merging([
            "event": event,
            "timestamp": timestamp
        ]) { current, _ in current }
        queue.async {
            write(entry)
        }
    }

    private static let queue = DispatchQueue(label: "app.cueseeker.speaker-subtitle-diagnostics")

    private static func write(_ entry: [String: String]) {
        do {
            let directory = logDirectoryURL()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let fileURL = directory.appendingPathComponent("speaker-subtitle-\(dateStamp()).jsonl")
            let data = try JSONSerialization.data(withJSONObject: entry, options: [.sortedKeys])
            guard let line = String(data: data, encoding: .utf8)?.appending("\n"),
                  let lineData = line.data(using: .utf8)
            else {
                return
            }

            if !FileManager.default.fileExists(atPath: fileURL.path) {
                FileManager.default.createFile(atPath: fileURL.path, contents: nil)
            }
            let handle = try FileHandle(forWritingTo: fileURL)
            try handle.seekToEnd()
            try handle.write(contentsOf: lineData)
            try handle.close()
        } catch {
            print("Failed to write speaker subtitle diagnostics: \(error)")
        }
    }

    private static func logDirectoryURL() -> URL {
        projectRootURL()
            .appendingPathComponent("logs", isDirectory: true)
            .appendingPathComponent("speaker-subtitle", isDirectory: true)
    }

    private static func projectRootURL() -> URL {
        var directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        while directory.path != "/" {
            let macOSPackageURL = directory
                .appendingPathComponent("apps", isDirectory: true)
                .appendingPathComponent("macos-native", isDirectory: true)
            if FileManager.default.fileExists(atPath: macOSPackageURL.path) {
                return directory
            }
            directory.deleteLastPathComponent()
        }

        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
    }

    private static func dateStamp() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}

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

    private static func targetLineSort(_ lhs: SubtitleCueLineRecord, _ rhs: SubtitleCueLineRecord) -> Bool {
        if lhs.line.displayOrder != rhs.line.displayOrder {
            return lhs.line.displayOrder < rhs.line.displayOrder
        }
        if lhs.line.eventIndex != rhs.line.eventIndex {
            return lhs.line.eventIndex < rhs.line.eventIndex
        }

        return lhs.id < rhs.id
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
        var context = RewriteContext(debugTargetKey: cues.first.map(DialogueKey.init))
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

        let remainingCueCount = remainingSpeakersByKey.values.reduce(0) { partialResult, speakerQueues in
            partialResult + speakerQueues.count
        }
        SubtitleSpeakerDisplayDiagnostics.log(
            "core.assRewriter.summary",
            fields: [
                "cueCount": "\(cues.count)",
                "initialKeyCount": "\(Dictionary(grouping: cues, by: DialogueKey.init).count)",
                "parsedDialogueCount": "\(context.parsedDialogueCount)",
                "unparsedDialogueCount": "\(context.unparsedDialogueCount)",
                "matchedDialogueCount": "\(context.matchedDialogueCount)",
                "remainingCueCount": "\(remainingCueCount)",
                "firstCueKey": context.debugTargetKey?.debugDescription ?? "",
                "firstCueTimeKeys": context.debugTargetTimeKeys.joined(separator: " | "),
                "firstParsedKey": context.firstParsedKey?.debugDescription ?? "",
                "firstUnparsedDialogue": context.firstUnparsedDialogue ?? ""
            ]
        )

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

        guard lowercased.hasPrefix("dialogue:") else {
            return line
        }

        guard let parsed = parseDialogue(line: line, eventFormat: context.eventFormat) else {
            context.unparsedDialogueCount += 1
            if context.firstUnparsedDialogue == nil {
                context.firstUnparsedDialogue = String(line.prefix(180))
            }
            return line
        }

        context.parsedDialogueCount += 1
        context.firstParsedKey = context.firstParsedKey ?? parsed.key
        if let debugTargetKey = context.debugTargetKey,
           parsed.key.hasSameTiming(as: debugTargetKey),
           context.debugTargetTimeKeys.count < 8 {
            context.debugTargetTimeKeys.append(parsed.key.debugDescription)
        }

        guard var speakerQueue = remainingSpeakersByKey[parsed.key],
              !speakerQueue.isEmpty
        else {
            return line
        }

        context.matchedDialogueCount += 1
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
        let debugTargetKey: DialogueKey?
        var parsedDialogueCount = 0
        var unparsedDialogueCount = 0
        var matchedDialogueCount = 0
        var firstParsedKey: DialogueKey?
        var firstUnparsedDialogue: String?
        var debugTargetTimeKeys: [String] = []

        init(debugTargetKey: DialogueKey? = nil) {
            self.debugTargetKey = debugTargetKey
        }
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

        var debugDescription: String {
            let style = sourceStyle ?? ""
            let layer = sourceLayer.map(String.init) ?? ""
            return "\(startMilliseconds)-\(endMilliseconds):\(style):\(layer):\(cleanText)"
        }

        func hasSameTiming(as other: DialogueKey) -> Bool {
            startMilliseconds == other.startMilliseconds
                && endMilliseconds == other.endMilliseconds
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
        let nsString = self as NSString
        var result: [(line: String, terminator: String)] = []
        var position = 0

        while position < nsString.length {
            var lineStart = 0
            var lineEnd = 0
            var contentsEnd = 0
            nsString.getLineStart(
                &lineStart,
                end: &lineEnd,
                contentsEnd: &contentsEnd,
                for: NSRange(location: position, length: 0)
            )

            result.append((
                line: nsString.substring(with: NSRange(location: lineStart, length: contentsEnd - lineStart)),
                terminator: nsString.substring(with: NSRange(location: contentsEnd, length: lineEnd - contentsEnd))
            ))
            position = lineEnd
        }

        return result
    }
}
