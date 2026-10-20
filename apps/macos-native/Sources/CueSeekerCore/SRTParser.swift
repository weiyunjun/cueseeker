import Foundation

public enum SRTParsingError: Error, Equatable, Sendable {
    case malformedBlock(Int)
    case undecodableData
}

public enum SRTParser {
    public static func parse(_ contents: String, format: SubtitleFormat = .srt) -> [SubtitleEntry] {
        parseEntries(
            contents,
            format: format,
            deduplicates: true,
            minimumDurationMilliseconds: SubtitleCueIndexingRules.minimumDurationMilliseconds,
            allowsTrailingEndParameters: format == .vtt
        )
    }

    public static func parseForRendering(_ contents: String, format: SubtitleFormat = .srt) -> [SubtitleEntry] {
        parseEntries(
            contents,
            format: format,
            deduplicates: false,
            minimumDurationMilliseconds: 1,
            allowsTrailingEndParameters: true
        )
    }

    public static func parseForRendering(_ data: Data) throws -> [SubtitleEntry] {
        try parseForRendering(data, format: .srt)
    }

    public static func parseForRendering(_ data: Data, format: SubtitleFormat) throws -> [SubtitleEntry] {
        let contents: String
        do {
            contents = try SubtitleTextDecoder.decode(data, format: format)
        } catch {
            throw SRTParsingError.undecodableData
        }
        let effectiveFormat: SubtitleFormat =
            (format == .vtt || hasWEBVTTHeader(contents)) ? .vtt : format
        return parseForRendering(contents, format: effectiveFormat)
    }

    private static func parseEntries(
        _ contents: String,
        format: SubtitleFormat,
        deduplicates: Bool,
        minimumDurationMilliseconds: Int,
        allowsTrailingEndParameters: Bool
    ) -> [SubtitleEntry] {
        var seenEntries = Set<SRTEntryDeduplicationKey>()
        return splitBlocks(contents, format: format).compactMap { block in
            guard let entry = parseBlock(
                block,
                format: format,
                minimumDurationMilliseconds: minimumDurationMilliseconds,
                allowsTrailingEndParameters: allowsTrailingEndParameters
            ) else {
                return nil
            }

            let key = SRTEntryDeduplicationKey(entry: entry)
            guard !deduplicates || seenEntries.insert(key).inserted else {
                return nil
            }

            return entry
        }
    }

    public static func parseCueGroups(_ contents: String, format: SubtitleFormat = .srt) -> [SubtitleCueGroup] {
        parse(contents, format: format).enumerated().map { index, entry in
            entry.cueGroup(eventIndex: index, sourceFormat: format)
        }
    }

    public static func hasValidStructure(_ contents: String, format: SubtitleFormat = .srt) -> Bool {
        if format == .vtt, hasWEBVTTHeader(contents) {
            return true
        }
        let blocks = splitBlocks(contents, format: format)
        return !blocks.isEmpty && blocks.contains { isStructurallyValid($0, format: format) }
    }

    public static func parseCueGroupsForIndexing(_ contents: String, format: SubtitleFormat = .srt) throws -> [SubtitleCueGroup] {
        for (index, block) in splitBlocks(contents, format: format).enumerated() {
            guard isStructurallyValid(block, format: format) else {
                throw SRTParsingError.malformedBlock(index + 1)
            }
        }
        return parseCueGroups(contents, format: format)
    }

    public static func milliseconds(from timecode: String) -> Int? {
        let trimmed = timecode.trimmingCharacters(in: .whitespacesAndNewlines)
        let timeParts = trimmed.split(separator: ":", omittingEmptySubsequences: false)

        let hours: Int
        let minutes: Int
        let secondsAndFractionPart: Substring
        switch timeParts.count {
        case 3:
            guard let parsedHours = Int(timeParts[0]),
                  let parsedMinutes = Int(timeParts[1])
            else {
                return nil
            }
            hours = parsedHours
            minutes = parsedMinutes
            secondsAndFractionPart = timeParts[2]
        case 2:
            guard let parsedMinutes = Int(timeParts[0]) else {
                return nil
            }
            hours = 0
            minutes = parsedMinutes
            secondsAndFractionPart = timeParts[1]
        default:
            return nil
        }

        guard hours >= 0,
              minutes >= 0,
              minutes < 60
        else {
            return nil
        }

        let secondParts = secondsAndFractionPart.split(
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

    private static func parseBlock(
        _ lines: [String],
        format: SubtitleFormat = .srt,
        minimumDurationMilliseconds: Int = SubtitleCueIndexingRules.minimumDurationMilliseconds,
        allowsTrailingEndParameters: Bool = false
    ) -> SubtitleEntry? {
        guard !lines.isEmpty else {
            return nil
        }

        let firstLine = lines[0].trimmingCharacters(in: .whitespacesAndNewlines)
        let sequenceNumber: Int?
        let timeLineIndex: Int
        if format == .vtt {
            if isTimecodeLine(lines[0], allowsTrailingEndParameters: true) {
                sequenceNumber = nil
                timeLineIndex = 0
            } else {
                sequenceNumber = Int(firstLine)
                timeLineIndex = 1
            }
        } else {
            sequenceNumber = Int(firstLine)
            timeLineIndex = sequenceNumber == nil ? 0 : 1
        }

        guard lines.indices.contains(timeLineIndex) else {
            return nil
        }

        let timeLine = lines[timeLineIndex].trimmingCharacters(in: .whitespacesAndNewlines)
        guard let range = timeLine.range(of: "-->") else {
            return nil
        }

        let startTimecode = String(timeLine[..<range.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let endRemainder = String(timeLine[range.upperBound...])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let endTimecode = allowsTrailingEndParameters
            ? endRemainder.split(whereSeparator: \.isWhitespace).first.map(String.init) ?? ""
            : endRemainder

        guard let startMilliseconds = milliseconds(from: startTimecode),
              let endMilliseconds = milliseconds(from: endTimecode),
              endMilliseconds >= startMilliseconds,
              endMilliseconds - startMilliseconds >= minimumDurationMilliseconds
        else {
            return nil
        }

        let textLines = lines.dropFirst(timeLineIndex + 1)
        let text = textLines
            .map { line in
                let cleaned = format == .vtt ? stripVTTInlineTags(line) : line
                return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
            }
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

    private static func isStructurallyValid(_ lines: [String], format: SubtitleFormat = .srt) -> Bool {
        guard !lines.isEmpty else {
            return false
        }

        if format == .vtt {
            if isTimecodeLine(lines[0]) {
                return true
            }
            return lines.count > 1 && !lines[0].contains("-->") && isTimecodeLine(lines[1])
        }

        let firstLine = lines[0].trimmingCharacters(in: .whitespacesAndNewlines)
        let timeLineIndex = Int(firstLine) == nil ? 0 : 1
        guard lines.indices.contains(timeLineIndex) else {
            return false
        }

        return isTimecodeLine(lines[timeLineIndex])
    }

    private static func isTimecodeLine(
        _ rawLine: String,
        allowsTrailingEndParameters: Bool = true
    ) -> Bool {
        let timeLine = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let range = timeLine.range(of: "-->") else {
            return false
        }
        let startTimecode = String(timeLine[..<range.lowerBound])
        let endRemainder = String(timeLine[range.upperBound...])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let endTimecode = allowsTrailingEndParameters
            ? endRemainder.split(whereSeparator: \.isWhitespace).first.map(String.init) ?? ""
            : endRemainder
        return milliseconds(from: startTimecode) != nil
            && milliseconds(from: endTimecode) != nil
    }

    private static func splitBlocks(_ contents: String, format: SubtitleFormat = .srt) -> [[String]] {
        let normalized = contents
            .replacingOccurrences(of: "\u{feff}", with: "")
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        let allLines = normalized
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
        var blocks: [[String]] = []
        var currentBlock: [String] = []
        var currentBlockHasTimecode = false

        for (index, stringLine) in allLines.enumerated() {
            let trimmed = stringLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                if !currentBlock.isEmpty {
                    blocks.append(currentBlock)
                    currentBlock.removeAll()
                    currentBlockHasTimecode = false
                }
                continue
            }

            let startsCueAfterVTTMetadataBlock =
                format == .vtt
                && !currentBlock.isEmpty
                && !currentBlockHasTimecode
                && isVTTNonCueBlock(currentBlock)
                && isTimecodeLine(stringLine)

            let startsNextBlockWithoutBlankLine =
                startsCueAfterVTTMetadataBlock
                || (
                    currentBlockHasTimecode
                    && (
                        isTimecodeLine(stringLine)
                        || (
                            Int(trimmed) != nil
                            && index + 1 < allLines.count
                            && isTimecodeLine(allLines[index + 1])
                        )
                    )
                )
            if startsNextBlockWithoutBlankLine {
                blocks.append(currentBlock)
                currentBlock.removeAll()
                currentBlockHasTimecode = false
            }

            if isTimecodeLine(stringLine) {
                currentBlockHasTimecode = true
            }
            currentBlock.append(stringLine)
        }

        if !currentBlock.isEmpty {
            blocks.append(currentBlock)
        }

        if format == .vtt {
            return blocks.filter { !isVTTNonCueBlock($0) }
        }
        return blocks
    }

    private static func hasWEBVTTHeader(_ contents: String) -> Bool {
        let normalized = contents
            .replacingOccurrences(of: "\u{feff}", with: "")
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        for line in normalized.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                continue
            }
            return isWEBVTTHeaderLine(trimmed)
        }
        return false
    }

    private static func isVTTNonCueBlock(_ lines: [String]) -> Bool {
        guard let firstLine = lines.first?.trimmingCharacters(in: .whitespacesAndNewlines),
              !firstLine.isEmpty
        else {
            return false
        }
        if isTimecodeLine(firstLine) {
            return false
        }
        return isVTTNonCueBlockHeaderLine(firstLine)
    }

    private static func isWEBVTTHeaderLine(_ trimmedLine: String) -> Bool {
        let lowercased = trimmedLine.lowercased()
        guard lowercased.hasPrefix("webvtt") else {
            return false
        }
        let remainder = lowercased.dropFirst("webvtt".count)
        guard let nextCharacter = remainder.first else {
            return true
        }
        return nextCharacter.isWhitespace || nextCharacter == "-"
    }

    private static func isVTTNonCueBlockHeaderLine(_ trimmedLine: String) -> Bool {
        if isWEBVTTHeaderLine(trimmedLine) {
            return true
        }
        let lowercased = trimmedLine.lowercased()
        for keyword in ["note", "style", "region"] {
            guard lowercased.hasPrefix(keyword) else {
                continue
            }
            let remainder = lowercased.dropFirst(keyword.count)
            if remainder.isEmpty || remainder.first?.isWhitespace == true {
                return true
            }
        }
        return false
    }

    private static func stripVTTInlineTags(_ line: String) -> String {
        var result = ""
        result.reserveCapacity(line.count)
        var index = line.startIndex
        while index < line.endIndex {
            if line[index] == "<" {
                let afterOpen = line.index(after: index)
                if let closingIndex = line[afterOpen...].firstIndex(of: ">"),
                   !line[afterOpen..<closingIndex].contains("<")
                {
                    index = line.index(after: closingIndex)
                    continue
                }
            }
            result.append(line[index])
            index = line.index(after: index)
        }
        return result
    }

    private struct SRTEntryDeduplicationKey: Hashable {
        let startMilliseconds: Int
        let endMilliseconds: Int
        let text: String

        init(entry: SubtitleEntry) {
            startMilliseconds = entry.startMilliseconds
            endMilliseconds = entry.endMilliseconds
            text = entry.text
        }
    }
}
