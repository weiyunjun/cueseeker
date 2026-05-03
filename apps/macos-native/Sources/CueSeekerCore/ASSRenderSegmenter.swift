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
    public static let cacheAlgorithmVersion = 2
    public static let largeFileThresholdBytes: Int64 = 256 * 1024
    public static let minimumSegmentDurationMilliseconds = 5_000
    public static let segmentDurationMilliseconds = 30_000
    public static let maximumSegmentDurationMilliseconds = 60_000

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

            var windows: [RenderWindow] = []
            var startMilliseconds = 0
            while startMilliseconds < maxEndMilliseconds {
                let durationMilliseconds = ASSRenderSegmenter.segmentDuration(
                    startingAt: startMilliseconds,
                    events: events
                )
                let endMilliseconds = startMilliseconds + durationMilliseconds
                windows.append(
                    RenderWindow(
                        startMilliseconds: startMilliseconds,
                        endMilliseconds: endMilliseconds
                    )
                )
                startMilliseconds = endMilliseconds
            }

            return windows.enumerated().compactMap { segmentIndex, window in
                let segmentEvents = events.filter {
                    ASSRenderSegmenter.overlaps(
                        startMilliseconds: $0.startMilliseconds,
                        endMilliseconds: $0.endMilliseconds,
                        windowStartMilliseconds: window.startMilliseconds,
                        windowEndMilliseconds: window.endMilliseconds
                    )
                }

                let scriptLines = prefixLines + eventHeaderLines + segmentEvents.map(\.rawLine)
                let scriptText = scriptLines.joined(separator: "\n") + "\n"
                return ASSRenderSegmentPayload(
                    segmentIndex: segmentIndex,
                    startMilliseconds: window.startMilliseconds,
                    endMilliseconds: window.endMilliseconds,
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

            let text = ASSRenderSegmenter.value(named: "text", fields: fields, format: eventFormat) ?? ""
            let complexity = ASSRenderSegmenter.complexity(rawLine: line, text: text)
            return RawEvent(
                rawLine: line,
                startMilliseconds: startMilliseconds,
                endMilliseconds: endMilliseconds,
                rawByteCount: complexity.rawByteCount,
                parseCost: complexity.parseCost,
                activeCost: complexity.activeCost
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
        let rawByteCount: Int
        let parseCost: Int
        let activeCost: Int
    }

    private struct RenderWindow {
        let startMilliseconds: Int
        let endMilliseconds: Int
    }

    private struct EventComplexity {
        let rawByteCount: Int
        let parseCost: Int
        let activeCost: Int
    }

    private struct SegmentMetrics {
        let eventCount: Int
        let rawByteCount: Int
        let parseCost: Int
        let peakActiveCost: Int

        var fitsBudget: Bool {
            eventCount <= ASSRenderSegmenter.segmentEventBudget
                && rawByteCount <= ASSRenderSegmenter.segmentRawByteBudget
                && parseCost <= ASSRenderSegmenter.segmentParseCostBudget
                && peakActiveCost <= ASSRenderSegmenter.segmentPeakActiveCostBudget
        }
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
    private static let candidateDurationsMilliseconds = [
        maximumSegmentDurationMilliseconds,
        segmentDurationMilliseconds,
        15_000,
        10_000,
        minimumSegmentDurationMilliseconds
    ]
    private static let segmentEventBudget = 1_200
    private static let segmentRawByteBudget = 512 * 1024
    private static let segmentParseCostBudget = 30_000
    private static let segmentPeakActiveCostBudget = 8_000
    private static let activeCostSampleIntervalMilliseconds = 1_000

    private static func segmentDuration(startingAt startMilliseconds: Int, events: [RawEvent]) -> Int {
        for durationMilliseconds in candidateDurationsMilliseconds {
            let endMilliseconds = startMilliseconds + durationMilliseconds
            let metrics = segmentMetrics(
                events: events,
                windowStartMilliseconds: startMilliseconds,
                windowEndMilliseconds: endMilliseconds
            )
            if metrics.fitsBudget {
                return durationMilliseconds
            }
        }

        return minimumSegmentDurationMilliseconds
    }

    private static func segmentMetrics(
        events: [RawEvent],
        windowStartMilliseconds: Int,
        windowEndMilliseconds: Int
    ) -> SegmentMetrics {
        let segmentEvents = events.filter {
            overlaps(
                startMilliseconds: $0.startMilliseconds,
                endMilliseconds: $0.endMilliseconds,
                windowStartMilliseconds: windowStartMilliseconds,
                windowEndMilliseconds: windowEndMilliseconds
            )
        }
        let rawByteCount = segmentEvents.reduce(0) { $0 + $1.rawByteCount }
        let parseCost = segmentEvents.reduce(0) { $0 + $1.parseCost }
        let shouldSampleActiveCost = segmentEvents.count <= segmentEventBudget
            && rawByteCount <= segmentRawByteBudget
            && parseCost <= segmentParseCostBudget
        let peakActiveCost = shouldSampleActiveCost
            ? peakActiveCost(
                events: segmentEvents,
                windowStartMilliseconds: windowStartMilliseconds,
                windowEndMilliseconds: windowEndMilliseconds
            )
            : segmentPeakActiveCostBudget + 1

        return SegmentMetrics(
            eventCount: segmentEvents.count,
            rawByteCount: rawByteCount,
            parseCost: parseCost,
            peakActiveCost: peakActiveCost
        )
    }

    private static func peakActiveCost(
        events: [RawEvent],
        windowStartMilliseconds: Int,
        windowEndMilliseconds: Int
    ) -> Int {
        guard !events.isEmpty else {
            return 0
        }

        var peak = 0
        var sampleMilliseconds = windowStartMilliseconds
        while sampleMilliseconds < windowEndMilliseconds {
            peak = max(peak, activeCost(at: sampleMilliseconds, events: events))
            sampleMilliseconds += activeCostSampleIntervalMilliseconds
        }

        let finalSampleMilliseconds = max(windowStartMilliseconds, windowEndMilliseconds - 1)
        return max(peak, activeCost(at: finalSampleMilliseconds, events: events))
    }

    private static func activeCost(at timestampMilliseconds: Int, events: [RawEvent]) -> Int {
        events.reduce(0) { result, event in
            guard event.startMilliseconds <= timestampMilliseconds,
                  event.endMilliseconds > timestampMilliseconds
            else {
                return result
            }
            return result + event.activeCost
        }
    }

    private static func complexity(rawLine: String, text: String) -> EventComplexity {
        let rawByteCount = rawLine.lengthOfBytes(using: .utf8)
        let overrideBlockCount = text.reduce(0) { count, character in
            count + (character == "{" ? 1 : 0)
        }
        let tagCount = text.reduce(0) { count, character in
            count + (character == "\\" ? 1 : 0)
        }
        let transformCount = countTag("t", in: text)
        let moveCount = countTag("move", in: text)
        let fadeCount = countTag("fad", in: text) + countTag("fade", in: text)
        let blurCount = countTag("blur", in: text) + countTag("be", in: text)
        let clipCount = countTag("clip", in: text) + countTag("iclip", in: text)
        let drawingCount = countTag("p", in: text)
        let karaokeCount = countTags(["k", "kf", "ko"], in: text)
        let vectorLikeByteCount = (drawingCount > 0 || clipCount > 0) ? rawByteCount : 0

        let parseCost = 1
            + rawByteCount / 32
            + overrideBlockCount * 4
            + tagCount * 8
            + transformCount * 80
            + moveCount * 50
            + fadeCount * 35
            + blurCount * 35
            + clipCount * 90
            + drawingCount * 120
            + karaokeCount * 25
            + vectorLikeByteCount / 8
        let activeCost = 1
            + tagCount * 3
            + transformCount * 70
            + moveCount * 45
            + fadeCount * 25
            + blurCount * 35
            + clipCount * 100
            + drawingCount * 140
            + karaokeCount * 20
            + vectorLikeByteCount / 16

        return EventComplexity(
            rawByteCount: rawByteCount,
            parseCost: parseCost,
            activeCost: activeCost
        )
    }

    private static func countTags(_ tags: [String], in text: String) -> Int {
        tags.reduce(0) { $0 + countTag($1, in: text) }
    }

    private static func countTag(_ tag: String, in text: String) -> Int {
        let lowercasedText = text.lowercased()
        let tag = tag.lowercased()
        var count = 0
        var searchStart = lowercasedText.startIndex

        while let slashIndex = lowercasedText[searchStart...].firstIndex(of: "\\") {
            let tagStart = lowercasedText.index(after: slashIndex)
            guard tagStart < lowercasedText.endIndex else {
                break
            }

            if let tagEnd = lowercasedText.index(
                tagStart,
                offsetBy: tag.count,
                limitedBy: lowercasedText.endIndex
            ),
                lowercasedText[tagStart..<tagEnd] == tag,
                isTagBoundary(at: tagEnd, in: lowercasedText)
            {
                count += 1
            }

            searchStart = tagStart
        }

        return count
    }

    private static func isTagBoundary(at index: String.Index, in text: String) -> Bool {
        guard index < text.endIndex else {
            return true
        }

        return !isTagNameCharacter(text[index])
    }

    private static func isTagNameCharacter(_ character: Character) -> Bool {
        guard character.unicodeScalars.count == 1,
              let scalar = character.unicodeScalars.first
        else {
            return false
        }

        return CharacterSet.letters.contains(scalar)
    }

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
