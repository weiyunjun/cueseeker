import Foundation

/// Normalizes subtitle and query text under one shared rule and builds FTS5
/// candidate queries plus exact line-level literal substring rules.
enum SearchQueryPlanner {
    struct Plan {
        let ftsQuery: String
        let lineMatchRule: LineMatchRule
    }

    enum LineMatchRule {
        case literalSubstring(normalizedQuery: String, normalizedUTF8: [UInt8])
    }

    /// Normalizes a query string (NFKC+NFC, limited punctuation synonyms,
    /// lowercasing, collapsing whitespace runs to `" "`, and trimming edges).
    static func normalizeQuery(_ query: String) -> String {
        normalize(query, trimEdges: true)
    }

    /// Normalizes target text while keeping collapsed leading/trailing spaces.
    static func normalizeText(_ text: String) -> String {
        normalize(text, trimEdges: false)
    }

    static func plan(for query: String) -> Plan? {
        let normalized = normalizeQuery(query)
        guard !normalized.isEmpty else {
            return nil
        }

        let segments = normalized.split(separator: " ", omittingEmptySubsequences: true)
        let ftsQuery = segments.map { segment in
            let expanded = segment.map { String($0) }.joined(separator: " ")
            return "\"\(escapeFTSPhrase(expanded))\""
        }.joined(separator: " AND ")

        return Plan(
            ftsQuery: ftsQuery,
            lineMatchRule: .literalSubstring(
                normalizedQuery: normalized,
                normalizedUTF8: Array(normalized.utf8)
            )
        )
    }

    static func matches(_ line: String, rule: LineMatchRule) -> Bool {
        switch rule {
        case let .literalSubstring(_, normalizedUTF8):
            return matchesNormalized(line, normalizedNeedleUTF8: normalizedUTF8)
        }
    }

    static func matchesNormalized(_ line: String, normalizedQuery: String) -> Bool {
        guard !normalizedQuery.isEmpty else {
            return false
        }
        return matchesNormalized(line, normalizedNeedleUTF8: Array(normalizedQuery.utf8))
    }

    static func matchRuleName(_ rule: LineMatchRule) -> String {
        switch rule {
        case .literalSubstring:
            "literalSubstring"
        }
    }

    static func vocabularyTerms(in text: String) -> [String] {
        let normalized = normalizeQuery(text)
        guard !normalized.isEmpty else {
            return []
        }

        var terms: [String] = []
        var seen = Set<String>()
        for character in normalized where !character.isWhitespace {
            let term = String(character)
            if seen.insert(term).inserted {
                terms.append(term)
            }
        }
        return terms
    }

    /// Normalizes `text` and separates every non-whitespace extended grapheme
    /// cluster with a space so FTS5 indexes every character individually.
    static func segmentForFTS(_ text: String) -> String {
        if let fast = fastSegmentForFTS(text) {
            return fast
        }

        let normalized = normalizeText(text)
        var segmented = ""
        segmented.reserveCapacity(normalized.utf8.count * 2)
        for character in normalized where !character.isWhitespace {
            if !segmented.isEmpty {
                segmented.append(" ")
            }
            segmented.append(character)
        }
        return segmented
    }

    private static func matchesNormalized(
        _ line: String,
        normalizedNeedleUTF8: [UInt8]
    ) -> Bool {
        guard !normalizedNeedleUTF8.isEmpty, !line.isEmpty else {
            return false
        }

        let fastResult: Bool?
        if let result = line.utf8.withContiguousStorageIfAvailable({ hBuf in
            fastMatchUTF8(hBuf, needleUTF8: normalizedNeedleUTF8)
        }) {
            fastResult = result
        } else {
            var mutableLine = line
            fastResult = mutableLine.withUTF8 { hBuf in
                fastMatchUTF8(hBuf, needleUTF8: normalizedNeedleUTF8)
            }
        }
        if let fastResult {
            return fastResult
        }

        return matchesNormalizedFallback(line, normalizedNeedleUTF8: normalizedNeedleUTF8)
    }

    private static func matchesNormalizedFallback(
        _ line: String,
        normalizedNeedleUTF8: [UInt8]
    ) -> Bool {
        let normalizedLine = normalizeText(line)
        guard !normalizedLine.isEmpty else {
            return false
        }

        var mutableLine = normalizedLine
        return mutableLine.withUTF8 { hBuf in
            guard let hBase = hBuf.baseAddress,
                  hBuf.count >= normalizedNeedleUTF8.count
            else {
                return false
            }
            return normalizedNeedleUTF8.withUnsafeBufferPointer { nBuf in
                guard let nBase = nBuf.baseAddress else {
                    return false
                }
                let nCount = nBuf.count
                let limit = hBuf.count - nCount
                let firstByte = nBase[0]
                var i = 0
                while i <= limit {
                    if hBase[i] == firstByte && (nCount == 1 || memcmp(hBase + i, nBase, nCount) == 0) {
                        let startIndex = normalizedLine.utf8.index(
                            normalizedLine.startIndex,
                            offsetBy: i
                        )
                        let endIndex = normalizedLine.utf8.index(
                            startIndex,
                            offsetBy: nCount
                        )
                        if String.Index(startIndex, within: normalizedLine) != nil,
                           String.Index(endIndex, within: normalizedLine) != nil
                        {
                            return true
                        }
                    }
                    i += 1
                }
                return false
            }
        }
    }

    private static func normalize(_ text: String, trimEdges: Bool) -> String {
        guard !text.isEmpty else {
            return ""
        }

        let fastResult: String?
        if let result = text.utf8.withContiguousStorageIfAvailable({ hBuf in
            fastNormalizeString(hBuf, trimEdges: trimEdges)
        }) {
            fastResult = result
        } else {
            var mutableText = text
            fastResult = mutableText.withUTF8 { hBuf in
                fastNormalizeString(hBuf, trimEdges: trimEdges)
            }
        }
        if let fastResult {
            return fastResult
        }

        return fullNormalize(text, trimEdges: trimEdges)
    }

    private static func fullNormalize(_ text: String, trimEdges: Bool) -> String {
        // Chain NFC after NFKC because Foundation's NFKC leaves halfwidth
        // voiced/semi-voiced kana marks (e.g. U+FF9E/U+FF9F) decomposed.
        let compat = text.precomposedStringWithCompatibilityMapping
            .precomposedStringWithCanonicalMapping

        var mapped = ""
        mapped.reserveCapacity(compat.utf8.count)
        for scalar in compat.unicodeScalars {
            switch scalar.value {
            case 0x301C:
                mapped.append("~")
            case 0x22EF:
                mapped.append("...")
            case 0x2018, 0x2019:
                mapped.append("'")
            case 0x201C, 0x201D:
                mapped.append("\"")
            default:
                mapped.unicodeScalars.append(scalar)
            }
        }

        let lowered = mapped.lowercased()
        var result = ""
        result.reserveCapacity(lowered.utf8.count)
        var pendingSpace = false
        for character in lowered {
            if character.isWhitespace {
                if !trimEdges || !result.isEmpty {
                    pendingSpace = true
                }
            } else {
                if pendingSpace {
                    result.append(" ")
                    pendingSpace = false
                }
                result.append(character)
            }
        }
        if !trimEdges && pendingSpace {
            result.append(" ")
        }
        return result
    }

    private static func fastNormalizeString(
        _ hBuf: UnsafeBufferPointer<UInt8>,
        trimEdges: Bool
    ) -> String? {
        guard !hBuf.isEmpty else {
            return ""
        }
        return withUnsafeTemporaryAllocation(of: UInt8.self, capacity: hBuf.count) { normBuf in
            guard let normBase = normBuf.baseAddress,
                  let normCount = fastNormalizeUTF8(hBuf, trimEdges: trimEdges, into: normBase)
            else {
                return nil
            }
            guard normCount > 0 else {
                return ""
            }
            return String(
                decoding: UnsafeBufferPointer(start: normBase, count: normCount),
                as: UTF8.self
            )
        }
    }

    private static func fastMatchUTF8(
        _ hBuf: UnsafeBufferPointer<UInt8>,
        needleUTF8: [UInt8]
    ) -> Bool? {
        guard !needleUTF8.isEmpty, !hBuf.isEmpty else {
            return false
        }
        return withUnsafeTemporaryAllocation(of: UInt8.self, capacity: hBuf.count) { normBuf in
            guard let normBase = normBuf.baseAddress,
                  let normCount = fastNormalizeUTF8(hBuf, trimEdges: false, into: normBase)
            else {
                return nil
            }
            return needleUTF8.withUnsafeBufferPointer { nBuf in
                guard let nBase = nBuf.baseAddress else {
                    return false
                }
                return containsUTF8Bytes(
                    haystack: normBase,
                    haystackCount: normCount,
                    needle: nBase,
                    needleCount: nBuf.count
                )
            }
        }
    }

    private static func fastSegmentForFTS(_ text: String) -> String? {
        func segment(_ hBuf: UnsafeBufferPointer<UInt8>) -> String? {
            guard !hBuf.isEmpty else {
                return ""
            }
            return withUnsafeTemporaryAllocation(of: UInt8.self, capacity: hBuf.count) { normBuf in
                guard let normBase = normBuf.baseAddress,
                      let normCount = fastNormalizeUTF8(hBuf, trimEdges: true, into: normBase)
                else {
                    return nil
                }
                guard normCount > 0 else {
                    return ""
                }
                return withUnsafeTemporaryAllocation(of: UInt8.self, capacity: normCount * 2) { outBuf in
                    guard let outBase = outBuf.baseAddress else {
                        return nil
                    }
                    var j = 0
                    var outLen = 0
                    while j < normCount {
                        let b0 = normBase[j]
                        if b0 == 0x20 {
                            j += 1
                            continue
                        }
                        if outLen > 0 {
                            outBase[outLen] = 0x20
                            outLen += 1
                        }
                        if b0 < 0x80 {
                            outBase[outLen] = b0
                            outLen += 1
                            j += 1
                        } else {
                            outBase[outLen] = b0
                            outBase[outLen + 1] = normBase[j + 1]
                            outBase[outLen + 2] = normBase[j + 2]
                            outLen += 3
                            j += 3
                        }
                    }
                    return String(
                        decoding: UnsafeBufferPointer(start: outBase, count: outLen),
                        as: UTF8.self
                    )
                }
            }
        }

        if let result = text.utf8.withContiguousStorageIfAvailable(segment) {
            return result
        }
        var mutableText = text
        return mutableText.withUTF8(segment)
    }

    /// Zero-allocation fast path for ASCII, U+3001..U+301B, U+3041..U+3096,
    /// U+30A1..U+30FE, U+4000..U+9FFF, U+FF01..U+FF5E, U+3000, U+00A0, U+301C,
    /// U+2026, U+22EF, and curly quotes. Returns `nil` when any byte outside
    /// this set appears so the caller falls back to full Foundation NFKC.
    private static func fastNormalizeUTF8(
        _ hBuf: UnsafeBufferPointer<UInt8>,
        trimEdges: Bool,
        into out: UnsafeMutablePointer<UInt8>
    ) -> Int? {
        guard let p = hBuf.baseAddress else {
            return 0
        }
        let count = hBuf.count
        var i = 0
        var outLen = 0
        var pendingSpace = false

        @inline(__always)
        func flushSpaceIfNeeded() {
            if pendingSpace {
                out[outLen] = 0x20
                outLen += 1
                pendingSpace = false
            }
        }

        @inline(__always)
        func recordSpace() {
            if !trimEdges || outLen > 0 {
                pendingSpace = true
            }
        }

        while i < count {
            let b0 = p[i]
            if b0 < 0x80 {
                if b0 >= 0x21 && b0 <= 0x7E {
                    flushSpaceIfNeeded()
                    out[outLen] = (b0 >= 0x41 && b0 <= 0x5A) ? (b0 | 0x20) : b0
                    outLen += 1
                    i += 1
                    continue
                }
                if b0 == 0x20 || (b0 >= 0x09 && b0 <= 0x0D) {
                    recordSpace()
                    i += 1
                    continue
                }
                return nil
            }
            if b0 >= 0xE4 && b0 <= 0xE9 {
                guard i + 2 < count else {
                    return nil
                }
                flushSpaceIfNeeded()
                out[outLen] = b0
                out[outLen + 1] = p[i + 1]
                out[outLen + 2] = p[i + 2]
                outLen += 3
                i += 3
                continue
            }
            if b0 == 0xE3 {
                guard i + 2 < count else {
                    return nil
                }
                let b1 = p[i + 1]
                let b2 = p[i + 2]
                if b1 == 0x80 {
                    if b2 == 0x80 {
                        recordSpace()
                        i += 3
                        continue
                    }
                    if b2 >= 0x81 && b2 <= 0x9B {
                        flushSpaceIfNeeded()
                        out[outLen] = b0
                        out[outLen + 1] = b1
                        out[outLen + 2] = b2
                        outLen += 3
                        i += 3
                        continue
                    }
                    if b2 == 0x9C {
                        flushSpaceIfNeeded()
                        out[outLen] = 0x7E
                        outLen += 1
                        i += 3
                        continue
                    }
                    return nil
                }
                let isSafeKana = (b1 == 0x81 && b2 >= 0x81)
                    || (b1 == 0x82 && (b2 <= 0x96 || b2 >= 0xA1))
                    || (b1 == 0x83 && b2 <= 0xBE)
                if isSafeKana {
                    flushSpaceIfNeeded()
                    out[outLen] = b0
                    out[outLen + 1] = b1
                    out[outLen + 2] = b2
                    outLen += 3
                    i += 3
                    continue
                }
                return nil
            }
            if b0 == 0xEF {
                guard i + 2 < count else {
                    return nil
                }
                let b1 = p[i + 1]
                let b2 = p[i + 2]
                if b1 == 0xBC && b2 >= 0x81 {
                    let ascii = b2 - 0x60
                    flushSpaceIfNeeded()
                    out[outLen] = (ascii >= 0x41 && ascii <= 0x5A) ? (ascii | 0x20) : ascii
                    outLen += 1
                    i += 3
                    continue
                }
                if b1 == 0xBD && b2 <= 0x9E {
                    let ascii = b2 - 0x20
                    flushSpaceIfNeeded()
                    out[outLen] = ascii
                    outLen += 1
                    i += 3
                    continue
                }
                return nil
            }
            if b0 == 0xE2 {
                guard i + 2 < count else {
                    return nil
                }
                let b1 = p[i + 1]
                let b2 = p[i + 2]
                if b1 == 0x80 {
                    if b2 == 0xA6 {
                        flushSpaceIfNeeded()
                        out[outLen] = 0x2E
                        out[outLen + 1] = 0x2E
                        out[outLen + 2] = 0x2E
                        outLen += 3
                        i += 3
                        continue
                    }
                    if b2 == 0x98 || b2 == 0x99 {
                        flushSpaceIfNeeded()
                        out[outLen] = 0x27
                        outLen += 1
                        i += 3
                        continue
                    }
                    if b2 == 0x9C || b2 == 0x9D {
                        flushSpaceIfNeeded()
                        out[outLen] = 0x22
                        outLen += 1
                        i += 3
                        continue
                    }
                } else if b1 == 0x8B && b2 == 0xAF {
                    flushSpaceIfNeeded()
                    out[outLen] = 0x2E
                    out[outLen + 1] = 0x2E
                    out[outLen + 2] = 0x2E
                    outLen += 3
                    i += 3
                    continue
                }
                return nil
            }
            if b0 == 0xC2 {
                guard i + 1 < count, p[i + 1] == 0xA0 else {
                    return nil
                }
                recordSpace()
                i += 2
                continue
            }
            return nil
        }

        if !trimEdges && pendingSpace {
            out[outLen] = 0x20
            outLen += 1
        }
        return outLen
    }

    private static func containsUTF8Bytes(
        haystack: UnsafePointer<UInt8>,
        haystackCount: Int,
        needle: UnsafePointer<UInt8>,
        needleCount: Int
    ) -> Bool {
        guard needleCount > 0 else {
            return true
        }
        guard haystackCount >= needleCount else {
            return false
        }
        let firstByte = needle[0]
        if needleCount == 1 {
            for i in 0..<haystackCount where haystack[i] == firstByte {
                return true
            }
            return false
        }
        let lastOffset = needleCount - 1
        let lastByte = needle[lastOffset]
        let limit = haystackCount - needleCount
        var i = 0
        if needleCount == 2 {
            while i <= limit {
                if haystack[i] == firstByte && haystack[i + 1] == lastByte {
                    return true
                }
                i += 1
            }
            return false
        }
        if needleCount == 3 {
            let middleByte = needle[1]
            while i <= limit {
                if haystack[i] == firstByte
                    && haystack[i + 2] == lastByte
                    && haystack[i + 1] == middleByte
                {
                    return true
                }
                i += 1
            }
            return false
        }
        while i <= limit {
            if haystack[i] == firstByte
                && haystack[i + lastOffset] == lastByte
                && memcmp(haystack + i + 1, needle + 1, needleCount - 2) == 0
            {
                return true
            }
            i += 1
        }
        return false
    }

    private static func escapeFTSPhrase(_ text: String) -> String {
        text.replacingOccurrences(of: "\"", with: "\"\"")
    }
}

public enum SubtitleSearchQueryMatcher {
    public static func matches(_ primaryCueText: String, query: String) -> Bool {
        let normalizedQuery = SearchQueryPlanner.normalizeQuery(query)
        guard !normalizedQuery.isEmpty else {
            return false
        }
        return SearchQueryPlanner.matchesNormalized(primaryCueText, normalizedQuery: normalizedQuery)
    }
}
