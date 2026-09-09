import Foundation

public enum ASSScriptLineKind: Equatable, Sendable {
    case sectionHeader(isEvents: Bool)
    case eventFormat
    case dialogue(eventIndex: Int)
    case other
}

/// Walks an ASS script line by line over its UTF-8 bytes.
///
/// Classifying a line only needs its leading keyword, so the scan compares raw
/// bytes instead of trimming and lowercasing every line as a `String`. Lines
/// whose trimmed edges are not ASCII fall back to full Unicode handling so the
/// classification stays identical to the string-based form.
public enum ASSScriptScanner {
    public static func withScriptBytes<R>(
        _ script: String,
        _ body: (UnsafeBufferPointer<UInt8>) -> R
    ) -> R {
        var script = script
        return script.withUTF8 { body($0) }
    }

    public static func scanLines(
        _ bytes: UnsafeBufferPointer<UInt8>,
        _ body: (_ lineRange: Range<Int>, _ kind: ASSScriptLineKind) -> Void
    ) {
        var state = ScanState()
        var index = byteOrderMarkLength(bytes, at: 0)

        while true {
            var end = index
            while end < bytes.count, !isLineBreak(bytes[end]) {
                end += 1
            }
            body(index..<end, classify(bytes, in: index..<end, state: &state))

            guard end < bytes.count else {
                return
            }

            var next = end
            if bytes[next] == 0x0D {
                next += 1
                if next < bytes.count, bytes[next] == 0x0A {
                    next += 1
                }
            } else {
                next += 1
            }
            index = next

            if index == bytes.count {
                body(index..<index, classify(bytes, in: index..<index, state: &state))
                return
            }
        }
    }

    private struct ScanState {
        var isInsideEvents = false
        var hasEventFormat = false
        var nextEventIndex = 0
    }

    private static func classify(
        _ bytes: UnsafeBufferPointer<UInt8>,
        in lineRange: Range<Int>,
        state: inout ScanState
    ) -> ASSScriptLineKind {
        var start = lineRange.lowerBound
        var end = lineRange.upperBound

        while start < end, isASCIIWhitespace(bytes[start]) {
            start += 1
        }
        var markLength = byteOrderMarkLength(bytes, at: start, limit: end)
        while markLength > 0 {
            start += markLength
            while start < end, isASCIIWhitespace(bytes[start]) {
                start += 1
            }
            markLength = byteOrderMarkLength(bytes, at: start, limit: end)
        }
        while end > start, isASCIIWhitespace(bytes[end - 1]) {
            end -= 1
        }

        guard start < end else {
            return .other
        }
        // A non-ASCII first byte can still be Unicode whitespace hiding a keyword,
        // and a non-ASCII last byte only matters while looking for a section
        // header's closing bracket. Dialogue text never reaches the slow path.
        if bytes[start] >= 0x80 || (bytes[start] == 0x5B && bytes[end - 1] >= 0x80) {
            return classifyDecoded(bytes, in: lineRange, state: &state)
        }

        return classify(bytes, trimmed: start..<end, state: &state)
    }

    private static func classify(
        _ bytes: UnsafeBufferPointer<UInt8>,
        trimmed: Range<Int>,
        state: inout ScanState
    ) -> ASSScriptLineKind {
        if bytes[trimmed.lowerBound] == 0x5B, bytes[trimmed.upperBound - 1] == 0x5D {
            let isEvents = equalsIgnoringASCIICase(bytes, trimmed, Self.eventsSection)
            state.isInsideEvents = isEvents
            return .sectionHeader(isEvents: isEvents)
        }
        if state.isInsideEvents, hasPrefixIgnoringASCIICase(bytes, trimmed, Self.formatPrefix) {
            state.hasEventFormat = true
            return .eventFormat
        }
        if state.isInsideEvents,
           state.hasEventFormat,
           hasPrefixIgnoringASCIICase(bytes, trimmed, Self.dialoguePrefix) {
            let eventIndex = state.nextEventIndex
            state.nextEventIndex += 1
            return .dialogue(eventIndex: eventIndex)
        }
        return .other
    }

    private static func classifyDecoded(
        _ bytes: UnsafeBufferPointer<UInt8>,
        in lineRange: Range<Int>,
        state: inout ScanState
    ) -> ASSScriptLineKind {
        let line = String(decoding: bytes[lineRange], as: UTF8.self)
            .replacingOccurrences(of: "\u{feff}", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        if line.hasPrefix("["), line.hasSuffix("]") {
            let isEvents = line == "[events]"
            state.isInsideEvents = isEvents
            return .sectionHeader(isEvents: isEvents)
        }
        if state.isInsideEvents, line.hasPrefix("format:") {
            state.hasEventFormat = true
            return .eventFormat
        }
        if state.isInsideEvents, state.hasEventFormat, line.hasPrefix("dialogue:") {
            let eventIndex = state.nextEventIndex
            state.nextEventIndex += 1
            return .dialogue(eventIndex: eventIndex)
        }
        return .other
    }

    private static let eventsSection = Array("[events]".utf8)
    private static let formatPrefix = Array("format:".utf8)
    private static let dialoguePrefix = Array("dialogue:".utf8)

    private static func byteOrderMarkLength(
        _ bytes: UnsafeBufferPointer<UInt8>,
        at index: Int,
        limit: Int? = nil
    ) -> Int {
        let end = limit ?? bytes.count
        guard end - index >= 3,
              bytes[index] == 0xEF,
              bytes[index + 1] == 0xBB,
              bytes[index + 2] == 0xBF
        else {
            return 0
        }
        return 3
    }

    private static func isLineBreak(_ byte: UInt8) -> Bool {
        byte == 0x0A || byte == 0x0D
    }

    private static func isASCIIWhitespace(_ byte: UInt8) -> Bool {
        byte == 0x20 || (byte >= 0x09 && byte <= 0x0D)
    }

    private static func lowercasedASCII(_ byte: UInt8) -> UInt8 {
        byte >= 0x41 && byte <= 0x5A ? byte + 0x20 : byte
    }

    private static func equalsIgnoringASCIICase(
        _ bytes: UnsafeBufferPointer<UInt8>,
        _ range: Range<Int>,
        _ expected: [UInt8]
    ) -> Bool {
        guard range.count == expected.count else {
            return false
        }
        return hasPrefixIgnoringASCIICase(bytes, range, expected)
    }

    private static func hasPrefixIgnoringASCIICase(
        _ bytes: UnsafeBufferPointer<UInt8>,
        _ range: Range<Int>,
        _ expected: [UInt8]
    ) -> Bool {
        guard range.count >= expected.count else {
            return false
        }
        for offset in expected.indices
        where lowercasedASCII(bytes[range.lowerBound + offset]) != expected[offset] {
            return false
        }
        return true
    }
}
