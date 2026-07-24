import Foundation

public enum SRTParsingError: Error, Equatable, Sendable {
    case malformedBlock(Int)
}

public enum SRTParser {
    public static func parse(_ contents: String) -> [SubtitleEntry] {
        var seenEntries = Set<SRTEntryDeduplicationKey>()
        return splitBlocks(contents).compactMap { block in
            guard let entry = parseBlock(block) else {
                return nil
            }

            let key = SRTEntryDeduplicationKey(entry: entry)
            guard seenEntries.insert(key).inserted else {
                return nil
            }

            return entry
        }
    }

    public static func parseCueGroups(_ contents: String) -> [SubtitleCueGroup] {
        parse(contents).enumerated().map { index, entry in
            entry.cueGroup(eventIndex: index)
        }
    }

    public static func parseCueGroupsForIndexing(_ contents: String) throws -> [SubtitleCueGroup] {
        for (index, block) in splitBlocks(contents).enumerated() {
            guard isStructurallyValid(block) else {
                throw SRTParsingError.malformedBlock(index + 1)
            }
        }
        return parseCueGroups(contents)
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

        let secondParts = hourParts[2].split(
            omittingEmptySubsequences: false,
            whereSeparator: { $0 == "," || $0 == "." }
        )

        guard secondParts.count == 2,
              let seconds = Int(secondParts[0]),
              seconds >= 0,
              seconds < 60,
              let milliseconds = Int(secondParts[1]),
              milliseconds >= 0,
              milliseconds < 1000
        else {
            return nil
        }

        return (((hours * 60) + minutes) * 60 + seconds) * 1000 + milliseconds
    }

    private static func parseBlock(_ lines: [String]) -> SubtitleEntry? {
        guard !lines.isEmpty else {
            return nil
        }

        let firstLine = lines[0].trimmingCharacters(in: .whitespacesAndNewlines)
        let sequenceNumber = Int(firstLine)
        let timeLineIndex = sequenceNumber == nil ? 0 : 1

        guard lines.indices.contains(timeLineIndex) else {
            return nil
        }

        let timeLine = lines[timeLineIndex].trimmingCharacters(in: .whitespacesAndNewlines)
        guard let range = timeLine.range(of: "-->") else {
            return nil
        }

        let startTimecode = String(timeLine[..<range.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let endTimecode = String(timeLine[range.upperBound...])
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let startMilliseconds = milliseconds(from: startTimecode),
              let endMilliseconds = milliseconds(from: endTimecode),
              endMilliseconds >= startMilliseconds,
              endMilliseconds - startMilliseconds >= SubtitleCueIndexingRules.minimumDurationMilliseconds
        else {
            return nil
        }

        let textLines = lines.dropFirst(timeLineIndex + 1)
        let text = textLines
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !text.isEmpty else {
            return nil
        }

        return SubtitleEntry(
            sequenceNumber: sequenceNumber,
            startTimecode: startTimecode,
            endTimecode: endTimecode,
            startMilliseconds: startMilliseconds,
            endMilliseconds: endMilliseconds,
            text: text
        )
    }

    private static func isStructurallyValid(_ lines: [String]) -> Bool {
        guard !lines.isEmpty else {
            return false
        }

        let firstLine = lines[0].trimmingCharacters(in: .whitespacesAndNewlines)
        let timeLineIndex = Int(firstLine) == nil ? 0 : 1
        guard lines.indices.contains(timeLineIndex) else {
            return false
        }

        let timeLine = lines[timeLineIndex].trimmingCharacters(in: .whitespacesAndNewlines)
        guard let range = timeLine.range(of: "-->") else {
            return false
        }
        let startTimecode = String(timeLine[..<range.lowerBound])
        let endTimecode = String(timeLine[range.upperBound...])
        guard milliseconds(from: startTimecode) != nil,
              milliseconds(from: endTimecode) != nil
        else {
            return false
        }

        return lines.dropFirst(timeLineIndex + 1).contains {
            !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private static func splitBlocks(_ contents: String) -> [[String]] {
        let normalized = contents
            .replacingOccurrences(of: "\u{feff}", with: "")
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        var blocks: [[String]] = []
        var currentBlock: [String] = []

        for line in normalized.split(separator: "\n", omittingEmptySubsequences: false) {
            let stringLine = String(line)
            if stringLine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if !currentBlock.isEmpty {
                    blocks.append(currentBlock)
                    currentBlock.removeAll()
                }
            } else {
                currentBlock.append(stringLine)
            }
        }

        if !currentBlock.isEmpty {
            blocks.append(currentBlock)
        }

        return blocks
    }

    private struct SRTEntryDeduplicationKey: Hashable {
        let startTimecode: String
        let endTimecode: String
        let startMilliseconds: Int
        let endMilliseconds: Int
        let text: String

        init(entry: SubtitleEntry) {
            startTimecode = entry.startTimecode
            endTimecode = entry.endTimecode
            startMilliseconds = entry.startMilliseconds
            endMilliseconds = entry.endMilliseconds
            text = entry.text
        }
    }
}
