import Foundation

public struct ASSRenderSegmentPayload: Equatable, Sendable {
    public let segmentIndex: Int
    public let startMilliseconds: Int
    public let endMilliseconds: Int
    public let scriptText: String
    public let eventCount: Int
    public let byteCount: Int

    public init(
        segmentIndex: Int,
        startMilliseconds: Int,
        endMilliseconds: Int,
        scriptText: String,
        eventCount: Int,
        byteCount: Int
    ) {
        self.segmentIndex = segmentIndex
        self.startMilliseconds = startMilliseconds
        self.endMilliseconds = endMilliseconds
        self.scriptText = scriptText
        self.eventCount = eventCount
        self.byteCount = byteCount
    }
}

public enum ASSRenderSegmenter {
    public static let largeFileThresholdBytes: Int64 = 2 * 1024 * 1024
    public static let segmentDurationMilliseconds = 30_000

    public static func shouldSegment(format: SubtitleFormat, fileSize: Int64?) -> Bool {
        format == .ass && (fileSize ?? 0) >= largeFileThresholdBytes
    }

    public static func renderSegments(from contents: String) -> [ASSRenderSegmentPayload] {
        let parser = Parser(contents: contents)
        return parser.renderSegments()
    }

    private struct Parser {
        var contents: String

        func renderSegments() -> [ASSRenderSegmentPayload] {
            let normalized = contents
                .replacingOccurrences(of: "\u{feff}", with: "")
                .replacingOccurrences(of: "\r\n", with: "\n")
                .replacingOccurrences(of: "\r", with: "\n")
            let lines = normalized.split(separator: "\n", omittingEmptySubsequences: false)
                .map(String.init)

            var prefixLines: [String] = []
            var eventHeaderLines: [String] = []
            var events: [RawEvent] = []
            var section = Section.unknown
            var eventFormat = defaultEventFormat
            var sawEventsSection = false

            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                let lowercased = trimmed.lowercased()

                if lowercased.hasPrefix("[") && lowercased.hasSuffix("]") {
                    section = Section(rawValue: lowercased) ?? .unknown
                    if section == .events {
                        sawEventsSection = true
                        eventHeaderLines.append(line)
                    } else {
                        prefixLines.append(line)
                    }
                    continue
                }

                guard sawEventsSection, section == .events else {
                    prefixLines.append(line)
                    continue
                }

                if lowercased.hasPrefix("format:") {
                    eventFormat = ASSRenderSegmenter.parseFormat(
                        String(line.dropFirst(ASSRenderSegmenter.linePrefixLength(before: ":", in: line)))
                    )
                    eventHeaderLines.append(line)
                    continue
                }

                guard lowercased.hasPrefix("dialogue:") else {
                    continue
                }

                if let event = parseDialogueLine(line, eventFormat: eventFormat) {
                    events.append(event)
                }
            }

            guard sawEventsSection, !eventHeaderLines.isEmpty, !events.isEmpty else {
                return []
            }

            let maxEndMilliseconds = events.map(\.endMilliseconds).max() ?? 0
            guard maxEndMilliseconds > 0 else {
                return []
            }

            let segmentCount = max(1, Int(ceil(Double(maxEndMilliseconds) / Double(ASSRenderSegmenter.segmentDurationMilliseconds))))
            return (0..<segmentCount).compactMap { segmentIndex in
                let startMilliseconds = segmentIndex * ASSRenderSegmenter.segmentDurationMilliseconds
                let endMilliseconds = startMilliseconds + ASSRenderSegmenter.segmentDurationMilliseconds
                let segmentEvents = events.filter {
                    ASSRenderSegmenter.overlaps(
                        startMilliseconds: $0.startMilliseconds,
                        endMilliseconds: $0.endMilliseconds,
                        windowStartMilliseconds: startMilliseconds,
                        windowEndMilliseconds: endMilliseconds
                    )
                }

                let scriptLines = prefixLines + eventHeaderLines + segmentEvents.map(\.rawLine)
                let scriptText = scriptLines.joined(separator: "\n") + "\n"
                return ASSRenderSegmentPayload(
                    segmentIndex: segmentIndex,
                    startMilliseconds: startMilliseconds,
                    endMilliseconds: endMilliseconds,
                    scriptText: scriptText,
                    eventCount: segmentEvents.count,
                    byteCount: scriptText.lengthOfBytes(using: .utf8)
                )
            }
        }

        private func parseDialogueLine(_ line: String, eventFormat: [String]) -> RawEvent? {
            let body = String(line.dropFirst(ASSRenderSegmenter.linePrefixLength(before: ":", in: line)))
            let fields = ASSRenderSegmenter.splitFields(body, expectedCount: eventFormat.count)
            guard fields.count == eventFormat.count,
                  let startText = ASSRenderSegmenter.value(named: "start", fields: fields, format: eventFormat),
                  let endText = ASSRenderSegmenter.value(named: "end", fields: fields, format: eventFormat),
                  let startMilliseconds = ASSParser.milliseconds(from: startText),
                  let endMilliseconds = ASSParser.milliseconds(from: endText),
                  endMilliseconds >= startMilliseconds
            else {
                return nil
            }

            return RawEvent(
                rawLine: line,
                startMilliseconds: startMilliseconds,
                endMilliseconds: endMilliseconds
            )
        }
    }

    private enum Section: String {
        case events = "[events]"
        case unknown
    }

    private struct RawEvent {
        let rawLine: String
        let startMilliseconds: Int
        let endMilliseconds: Int
    }

    private static let defaultEventFormat = [
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

    private static func overlaps(
        startMilliseconds: Int,
        endMilliseconds: Int,
        windowStartMilliseconds: Int,
        windowEndMilliseconds: Int
    ) -> Bool {
        if startMilliseconds == endMilliseconds {
            return startMilliseconds >= windowStartMilliseconds
                && startMilliseconds <= windowEndMilliseconds
        }

        return startMilliseconds < windowEndMilliseconds
            && endMilliseconds > windowStartMilliseconds
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
        return fields.isEmpty ? defaultEventFormat : fields
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
}
