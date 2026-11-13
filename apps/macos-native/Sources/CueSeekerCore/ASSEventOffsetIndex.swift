import CoreFoundation
import Foundation

public enum ASSEventOffsetIndexError: Error, Equatable, Sendable {
    case corruptedPayload
}

public struct ASSEventByteRange: Equatable, Sendable {
    public let startMilliseconds: Int
    public let endMilliseconds: Int
    public let byteOffset: Int64
    public let byteLength: Int

    public init(
        startMilliseconds: Int,
        endMilliseconds: Int,
        byteOffset: Int64,
        byteLength: Int
    ) {
        self.startMilliseconds = startMilliseconds
        self.endMilliseconds = endMilliseconds
        self.byteOffset = byteOffset
        self.byteLength = byteLength
    }
}

public struct ASSEventOffsetIndex: Equatable, Sendable {
    public let subtitlePath: String
    public let algorithmVersion: Int
    public let fileSize: Int64
    public let modifiedAt: Date
    public let encodingName: String
    public let headerText: String
    public let events: [ASSEventByteRange]

    public init(
        subtitlePath: String,
        algorithmVersion: Int,
        fileSize: Int64,
        modifiedAt: Date,
        encodingName: String,
        headerText: String,
        events: [ASSEventByteRange]
    ) {
        self.subtitlePath = subtitlePath
        self.algorithmVersion = algorithmVersion
        self.fileSize = fileSize
        self.modifiedAt = modifiedAt
        self.encodingName = encodingName
        self.headerText = headerText
        self.events = events
    }

    public var eventCount: Int {
        events.count
    }

    /// Returns all events overlapping the half-open window `[lowerBound, upperBound)`
    /// in strict original source-file line order.
    public func overlappingEvents(in windowMilliseconds: Range<Int>) -> [ASSEventByteRange] {
        guard !windowMilliseconds.isEmpty else {
            return []
        }
        let windowStart = windowMilliseconds.lowerBound
        let windowEnd = windowMilliseconds.upperBound
        var matched: [ASSEventByteRange] = []
        for event in events
        where event.endMilliseconds > windowStart
            && event.startMilliseconds < windowEnd
            && event.endMilliseconds > event.startMilliseconds
        {
            matched.append(event)
        }
        return matched
    }

    /// Returns all events active at `timestampMilliseconds` (`start <= t && t < end`)
    /// in strict original source-file line order.
    public func activeEvents(atMilliseconds timestampMilliseconds: Int) -> [ASSEventByteRange] {
        guard timestampMilliseconds < Int.max else {
            return []
        }
        return overlappingEvents(in: timestampMilliseconds ..< (timestampMilliseconds + 1))
    }

    public func decodeEventLines(
        _ eventRanges: [ASSEventByteRange],
        from sourceData: Data
    ) -> [String]? {
        guard let encoding = SubtitleTextDecoder.stringEncoding(named: encodingName) else {
            return nil
        }
        var lines: [String] = []
        lines.reserveCapacity(eventRanges.count)
        for range in eventRanges {
            guard range.byteOffset >= 0,
                  range.byteLength > 0,
                  let start = Int(exactly: range.byteOffset)
            else {
                return nil
            }
            let (end, overflow) = start.addingReportingOverflow(range.byteLength)
            guard !overflow, end >= start, end <= sourceData.count else {
                return nil
            }
            let slice = sourceData.subdata(in: start..<end)
            guard let decoded = String(data: slice, encoding: encoding) else {
                return nil
            }
            lines.append(decoded)
        }
        return lines
    }

    public func readAndDecodeEventLines(
        _ eventRanges: [ASSEventByteRange],
        from subtitleFile: URL
    ) throws -> [String]? {
        guard let encoding = SubtitleTextDecoder.stringEncoding(named: encodingName) else {
            return nil
        }
        guard !eventRanges.isEmpty else {
            return []
        }
        let handle = try FileHandle(forReadingFrom: subtitleFile)
        defer {
            try? handle.close()
        }
        var lines: [String] = []
        lines.reserveCapacity(eventRanges.count)
        for range in eventRanges {
            guard range.byteOffset >= 0, range.byteLength > 0 else {
                return nil
            }
            try handle.seek(toOffset: UInt64(range.byteOffset))
            guard let slice = try handle.read(upToCount: range.byteLength),
                  slice.count == range.byteLength,
                  let decoded = String(data: slice, encoding: encoding)
            else {
                return nil
            }
            lines.append(decoded)
        }
        return lines
    }
}

enum ASSEventOffsetIndexStatus: String, Equatable, Sendable {
    case ready
    case ineligible
}

struct PreparedASSEventOffsetIndex: Equatable, Sendable {
    let algorithmVersion: Int
    let status: ASSEventOffsetIndexStatus
    let encodingName: String?
    let headerText: String?
    let eventCount: Int
    let compressedEvents: Data?

    static func ineligible(
        algorithmVersion: Int = ASSEventOffsetIndexer.currentAlgorithmVersion
    ) -> PreparedASSEventOffsetIndex {
        PreparedASSEventOffsetIndex(
            algorithmVersion: algorithmVersion,
            status: .ineligible,
            encodingName: nil,
            headerText: nil,
            eventCount: 0,
            compressedEvents: nil
        )
    }
}

public enum ASSEventOffsetIndexer {
    public static let currentAlgorithmVersion = 1

    private enum SectionState {
        case beforeFirstSection
        case scriptInfo
        case styles
        case events
        case ignoredMetadata
    }

    static func build(
        from data: Data,
        format: SubtitleFormat,
        encoding: String.Encoding,
        encodingName: String
    ) -> PreparedASSEventOffsetIndex {
        guard format.usesASSSemantics,
              !isStatefulEncoding(encoding, encodingName: encodingName),
              SubtitleTextDecoder.stringEncoding(named: encodingName) != nil
        else {
            return .ineligible()
        }

        let bomLength = SubtitleTextDecoder.leadingByteOrderMarkLength(in: data)
        guard bomLength <= data.count else {
            return .ineligible()
        }

        var section: SectionState = .beforeFirstSection
        var hasSeenEventsSection = false
        var hasSeenDialogue = false
        var headerLines: [String] = []
        var eventFormatFieldCount = 0
        var startFieldIndex: Int?
        var endFieldIndex: Int?
        var eventFormatLine: String?
        var events: [ASSEventByteRange] = []

        let didScanCleanly = scanRawLines(
            in: data,
            bomLength: bomLength,
            encoding: encoding
        ) { lineRange, rawBytes in
            if lineRange.isEmpty {
                return true
            }

            guard let decodedLine = decodeRawSlice(
                rawBytes,
                in: lineRange,
                encoding: encoding
            ) else {
                return false
            }

            let trimmed = trimBOMAndWhitespace(decodedLine)
            if trimmed.isEmpty || trimmed.hasPrefix(";") || trimmed.hasPrefix("!:") {
                return true
            }

            if trimmed.hasPrefix("["), trimmed.hasSuffix("]") {
                let lowerSection = trimmed.lowercased()
                if lowerSection == "[fonts]" || lowerSection == "[graphics]" {
                    return false
                }
                if lowerSection.hasPrefix("[aegisub ") {
                    section = .ignoredMetadata
                    return true
                }
                if lowerSection == "[script info]" {
                    guard !hasSeenEventsSection else {
                        return false
                    }
                    section = .scriptInfo
                    headerLines.append(String(trimmed))
                    return true
                }
                if lowerSection == "[v4+ styles]"
                    || lowerSection == "[v4 styles]"
                    || lowerSection == "[v4++ styles]"
                {
                    guard !hasSeenEventsSection else {
                        return false
                    }
                    section = .styles
                    headerLines.append(String(trimmed))
                    return true
                }
                if lowerSection == "[events]" {
                    guard !hasSeenEventsSection else {
                        return false
                    }
                    hasSeenEventsSection = true
                    section = .events
                    return true
                }
                return false
            }

            switch section {
            case .beforeFirstSection:
                return false

            case .ignoredMetadata:
                return true

            case .scriptInfo, .styles:
                let sanitized = decodedLine.replacingOccurrences(of: "\u{feff}", with: "")
                headerLines.append(sanitized)
                return true

            case .events:
                if hasCaseInsensitivePrefix(trimmed, "comment:") {
                    return true
                }
                if hasCaseInsensitivePrefix(trimmed, "format:") {
                    guard !hasSeenDialogue else {
                        return false
                    }
                    let formatPayload = trimmed.dropFirst("format:".count)
                    let columns = formatPayload
                        .split(separator: ",", omittingEmptySubsequences: false)
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                    guard columns.count >= 3,
                          let startIdx = columns.firstIndex(of: "start"),
                          let endIdx = columns.firstIndex(of: "end"),
                          let textIdx = columns.firstIndex(of: "text"),
                          textIdx == columns.count - 1
                    else {
                        return false
                    }
                    eventFormatFieldCount = columns.count
                    startFieldIndex = startIdx
                    endFieldIndex = endIdx
                    eventFormatLine = String(trimmed)
                    return true
                }
                if hasCaseInsensitivePrefix(trimmed, "dialogue:") {
                    guard eventFormatFieldCount >= 3,
                          let startIdx = startFieldIndex,
                          let endIdx = endFieldIndex,
                          lineRange.lowerBound >= 0,
                          lineRange.lowerBound <= Int(UInt32.max),
                          lineRange.count > 0,
                          lineRange.count <= Int(UInt32.max)
                    else {
                        return false
                    }
                    hasSeenDialogue = true
                    let payload = trimmed.dropFirst("dialogue:".count)
                    guard let (startSlice, endSlice) = extractDialogueTimestampFields(
                        from: payload,
                        expectedFieldCount: eventFormatFieldCount,
                        startFieldIndex: startIdx,
                        endFieldIndex: endIdx
                    ),
                    let startMs = parseASSTimestampMilliseconds(startSlice),
                    let endMs = parseASSTimestampMilliseconds(endSlice),
                    startMs >= 0,
                    endMs >= 0,
                    startMs <= Int(Int32.max),
                    endMs <= Int(Int32.max)
                    else {
                        return false
                    }
                    if endMs > startMs {
                        events.append(
                            ASSEventByteRange(
                                startMilliseconds: startMs,
                                endMilliseconds: endMs,
                                byteOffset: Int64(lineRange.lowerBound),
                                byteLength: lineRange.count
                            )
                        )
                    }
                    return true
                }
                return false
            }
        }

        guard didScanCleanly,
              hasSeenEventsSection,
              let eventFormatLine,
              !events.isEmpty
        else {
            return .ineligible()
        }

        headerLines.append("[Events]")
        headerLines.append(eventFormatLine)
        let headerText = headerLines.joined(separator: "\n")

        guard let compressedEvents = try? packAndCompressEvents(events) else {
            return .ineligible()
        }

        return PreparedASSEventOffsetIndex(
            algorithmVersion: currentAlgorithmVersion,
            status: .ready,
            encodingName: encodingName,
            headerText: headerText,
            eventCount: events.count,
            compressedEvents: compressedEvents
        )
    }

    static func packAndCompressEvents(_ events: [ASSEventByteRange]) throws -> Data {
        var rawBytes = Data(count: events.count * 16)
        rawBytes.withUnsafeMutableBytes { buffer in
            guard let base = buffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                return
            }
            for (index, event) in events.enumerated() {
                let p = base.advanced(by: index * 16)
                let startBits = UInt32(bitPattern: Int32(event.startMilliseconds))
                let endBits = UInt32(bitPattern: Int32(event.endMilliseconds))
                let offsetBits = UInt32(event.byteOffset)
                let lengthBits = UInt32(event.byteLength)

                p[0] = UInt8(truncatingIfNeeded: startBits)
                p[1] = UInt8(truncatingIfNeeded: startBits >> 8)
                p[2] = UInt8(truncatingIfNeeded: startBits >> 16)
                p[3] = UInt8(truncatingIfNeeded: startBits >> 24)

                p[4] = UInt8(truncatingIfNeeded: endBits)
                p[5] = UInt8(truncatingIfNeeded: endBits >> 8)
                p[6] = UInt8(truncatingIfNeeded: endBits >> 16)
                p[7] = UInt8(truncatingIfNeeded: endBits >> 24)

                p[8] = UInt8(truncatingIfNeeded: offsetBits)
                p[9] = UInt8(truncatingIfNeeded: offsetBits >> 8)
                p[10] = UInt8(truncatingIfNeeded: offsetBits >> 16)
                p[11] = UInt8(truncatingIfNeeded: offsetBits >> 24)

                p[12] = UInt8(truncatingIfNeeded: lengthBits)
                p[13] = UInt8(truncatingIfNeeded: lengthBits >> 8)
                p[14] = UInt8(truncatingIfNeeded: lengthBits >> 16)
                p[15] = UInt8(truncatingIfNeeded: lengthBits >> 24)
            }
        }
        return try (rawBytes as NSData).compressed(using: .zlib) as Data
    }

    static func decompressAndUnpackEvents(
        _ compressedData: Data,
        expectedCount: Int
    ) throws -> [ASSEventByteRange] {
        guard expectedCount > 0 else {
            return []
        }
        let rawBytes = try (compressedData as NSData).decompressed(using: .zlib) as Data
        let expectedByteCount = expectedCount * 16
        guard rawBytes.count == expectedByteCount else {
            throw ASSEventOffsetIndexError.corruptedPayload
        }
        return rawBytes.withUnsafeBytes { buffer -> [ASSEventByteRange] in
            guard let base = buffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                return []
            }
            var events: [ASSEventByteRange] = []
            events.reserveCapacity(expectedCount)
            for index in 0..<expectedCount {
                let p = base.advanced(by: index * 16)
                let startBits =
                    UInt32(p[0])
                    | (UInt32(p[1]) << 8)
                    | (UInt32(p[2]) << 16)
                    | (UInt32(p[3]) << 24)
                let endBits =
                    UInt32(p[4])
                    | (UInt32(p[5]) << 8)
                    | (UInt32(p[6]) << 16)
                    | (UInt32(p[7]) << 24)
                let offsetBits =
                    UInt32(p[8])
                    | (UInt32(p[9]) << 8)
                    | (UInt32(p[10]) << 16)
                    | (UInt32(p[11]) << 24)
                let lengthBits =
                    UInt32(p[12])
                    | (UInt32(p[13]) << 8)
                    | (UInt32(p[14]) << 16)
                    | (UInt32(p[15]) << 24)
                events.append(
                    ASSEventByteRange(
                        startMilliseconds: Int(Int32(bitPattern: startBits)),
                        endMilliseconds: Int(Int32(bitPattern: endBits)),
                        byteOffset: Int64(offsetBits),
                        byteLength: Int(lengthBits)
                    )
                )
            }
            return events
        }
    }

    private static func isStatefulEncoding(
        _ encoding: String.Encoding,
        encodingName: String
    ) -> Bool {
        if encoding == .iso2022JP {
            return true
        }
        let lower = encodingName.lowercased()
        return lower.contains("iso-2022")
            || lower.contains("hz-gb")
            || lower.contains("utf-7")
    }

    private static func scanRawLines(
        in data: Data,
        bomLength: Int,
        encoding: String.Encoding,
        body: (_ lineRange: Range<Int>, _ rawBytes: UnsafeRawBufferPointer) -> Bool
    ) -> Bool {
        data.withUnsafeBytes { rawBuffer in
            let count = rawBuffer.count
            guard bomLength <= count else {
                return false
            }

            switch encoding {
            case .utf32LittleEndian, .utf32BigEndian:
                let isLittleEndian = (encoding == .utf32LittleEndian)
                guard (count - bomLength).isMultiple(of: 4) else {
                    return false
                }
                guard let base = rawBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                    return true
                }
                var index = bomLength
                while index < count {
                    var end = index
                    while end < count {
                        let unit = readUInt32(base, at: end, littleEndian: isLittleEndian)
                        if unit == 0x0A || unit == 0x0D {
                            break
                        }
                        end += 4
                    }
                    if !body(index..<end, rawBuffer) {
                        return false
                    }
                    guard end < count else {
                        return true
                    }
                    let term = readUInt32(base, at: end, littleEndian: isLittleEndian)
                    var next = end + 4
                    if term == 0x0D, next < count,
                       readUInt32(base, at: next, littleEndian: isLittleEndian) == 0x0A
                    {
                        next += 4
                    }
                    index = next
                }
                return true

            case .utf16LittleEndian, .utf16BigEndian:
                let isLittleEndian = (encoding == .utf16LittleEndian)
                guard (count - bomLength).isMultiple(of: 2) else {
                    return false
                }
                guard let base = rawBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                    return true
                }
                var index = bomLength
                while index < count {
                    var end = index
                    while end < count {
                        let unit = readUInt16(base, at: end, littleEndian: isLittleEndian)
                        if unit == 0x0A || unit == 0x0D {
                            break
                        }
                        end += 2
                    }
                    if !body(index..<end, rawBuffer) {
                        return false
                    }
                    guard end < count else {
                        return true
                    }
                    let term = readUInt16(base, at: end, littleEndian: isLittleEndian)
                    var next = end + 2
                    if term == 0x0D, next < count,
                       readUInt16(base, at: next, littleEndian: isLittleEndian) == 0x0A
                    {
                        next += 2
                    }
                    index = next
                }
                return true

            case .utf16, .utf32:
                return false

            default:
                guard let base = rawBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                    return true
                }
                var index = bomLength
                while index < count {
                    var end = index
                    while end < count {
                        let byte = base[end]
                        if byte == 0x0A || byte == 0x0D {
                            break
                        }
                        end += 1
                    }
                    if !body(index..<end, rawBuffer) {
                        return false
                    }
                    guard end < count else {
                        return true
                    }
                    var next = end + 1
                    if base[end] == 0x0D, next < count, base[next] == 0x0A {
                        next += 1
                    }
                    index = next
                }
                return true
            }
        }
    }

    private static func readUInt16(
        _ base: UnsafePointer<UInt8>,
        at offset: Int,
        littleEndian: Bool
    ) -> UInt16 {
        let b0 = UInt16(base[offset])
        let b1 = UInt16(base[offset + 1])
        return littleEndian ? (b0 | (b1 << 8)) : ((b0 << 8) | b1)
    }

    private static func readUInt32(
        _ base: UnsafePointer<UInt8>,
        at offset: Int,
        littleEndian: Bool
    ) -> UInt32 {
        let b0 = UInt32(base[offset])
        let b1 = UInt32(base[offset + 1])
        let b2 = UInt32(base[offset + 2])
        let b3 = UInt32(base[offset + 3])
        if littleEndian {
            return b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
        }
        return (b0 << 24) | (b1 << 16) | (b2 << 8) | b3
    }

    private static func decodeRawSlice(
        _ rawBuffer: UnsafeRawBufferPointer,
        in range: Range<Int>,
        encoding: String.Encoding
    ) -> String? {
        guard let baseAddress = rawBuffer.baseAddress else {
            return range.isEmpty ? "" : nil
        }
        let slicePointer = UnsafeMutableRawPointer(mutating: baseAddress.advanced(by: range.lowerBound))
        let sliceData = Data(
            bytesNoCopy: slicePointer,
            count: range.count,
            deallocator: .none
        )
        return String(data: sliceData, encoding: encoding)
    }

    private static func trimBOMAndWhitespace(_ text: String) -> Substring {
        var slice = text[...]
        while let first = slice.first,
              first == "\u{feff}" || first == " " || first == "\t" || first.isWhitespace
        {
            slice = slice.dropFirst()
        }
        while let last = slice.last,
              last == "\u{feff}" || last == " " || last == "\t" || last.isWhitespace
        {
            slice = slice.dropLast()
        }
        return slice
    }

    private static func hasCaseInsensitivePrefix(
        _ text: Substring,
        _ prefix: StaticString
    ) -> Bool {
        prefix.withUTF8Buffer { expected in
            var index = text.startIndex
            for expectedByte in expected {
                guard index < text.endIndex else {
                    return false
                }
                let scalar = text[index].unicodeScalars.first?.value ?? UInt32.max
                guard scalar < 0x80 else {
                    return false
                }
                let byte = UInt8(scalar)
                let lowered = (byte >= 0x41 && byte <= 0x5A) ? (byte + 0x20) : byte
                guard lowered == expectedByte else {
                    return false
                }
                index = text.index(after: index)
            }
            return true
        }
    }

    private static func extractDialogueTimestampFields(
        from payload: Substring,
        expectedFieldCount: Int,
        startFieldIndex: Int,
        endFieldIndex: Int
    ) -> (Substring, Substring)? {
        let requiredCommas = expectedFieldCount - 1
        var fieldIndex = 0
        var fieldStart = payload.startIndex
        var startSlice: Substring?
        var endSlice: Substring?
        var cursor = payload.startIndex

        while cursor < payload.endIndex, fieldIndex < requiredCommas {
            if payload[cursor] == "," {
                if fieldIndex == startFieldIndex {
                    startSlice = payload[fieldStart..<cursor]
                }
                if fieldIndex == endFieldIndex {
                    endSlice = payload[fieldStart..<cursor]
                }
                fieldIndex += 1
                fieldStart = payload.index(after: cursor)
            }
            cursor = payload.index(after: cursor)
        }

        guard fieldIndex == requiredCommas else {
            return nil
        }

        if startFieldIndex == requiredCommas {
            startSlice = payload[fieldStart..<payload.endIndex]
        }
        if endFieldIndex == requiredCommas {
            endSlice = payload[fieldStart..<payload.endIndex]
        }

        guard let startSlice, let endSlice else {
            return nil
        }
        return (startSlice, endSlice)
    }

    private static func parseASSTimestampMilliseconds(_ raw: Substring) -> Int? {
        var trimmed = raw
        while let first = trimmed.first, first.isWhitespace {
            trimmed = trimmed.dropFirst()
        }
        while let last = trimmed.last, last.isWhitespace {
            trimmed = trimmed.dropLast()
        }

        let hourParts = trimmed.split(separator: ":", omittingEmptySubsequences: false)
        guard hourParts.count == 3,
              let hours = Int(hourParts[0]),
              hours >= 0,
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
              let fraction = Int(secondParts[1]),
              fraction >= 0
        else {
            return nil
        }

        let milliseconds: Int
        switch secondParts[1].count {
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
}
