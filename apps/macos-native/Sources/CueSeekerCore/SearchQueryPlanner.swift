import Foundation

enum SearchQueryPlanner {
    struct Plan {
        let ftsQuery: String
        let lineMatchRule: LineMatchRule
    }

    enum LineMatchRule {
        case latinPrefix(String)
        case orderedLatinTokens([String])
        case cjkSubstring(String)
        case explicitFTS(String)
    }

    static func plan(for query: String) -> Plan? {
        let trimmed = normalizeSpaces(query)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        let hasExplicitPhrase = trimmed.count >= 2 && trimmed.first == "\"" && trimmed.last == "\""
        let hasFTSSyntax = hasExplicitPhrase || trimmed.contains("*") || containsFTSOperator(in: trimmed)
        let hasCJK = containsCJKSearchCharacter(in: trimmed)
        let queryTokens = hasCJK ? [] : tokenizeLatin(trimmed)
        if !hasFTSSyntax && !hasCJK && queryTokens.isEmpty {
            return nil
        }

        if hasFTSSyntax {
            return Plan(
                ftsQuery: trimmed,
                lineMatchRule: .explicitFTS(trimmed)
            )
        }
        if hasCJK {
            let segmented = segmentForFTS(trimmed).trimmingCharacters(in: .whitespacesAndNewlines)
            return Plan(
                ftsQuery: "\"\(escapeFTSPhrase(segmented))\"",
                lineMatchRule: .cjkSubstring(trimmed)
            )
        }
        if queryTokens.count > 1 {
            return Plan(
                ftsQuery: queryTokens.joined(separator: " AND "),
                lineMatchRule: .orderedLatinTokens(queryTokens)
            )
        }
        return Plan(
            ftsQuery: "\(queryTokens[0])*",
            lineMatchRule: .latinPrefix(queryTokens[0])
        )
    }

    static func matches(_ line: String, rule: LineMatchRule) -> Bool {
        switch rule {
        case .cjkSubstring(let query):
            if !line.utf8.contains(0xE3) {
                return containsUTF8Substring(line, target: query)
            }
            let normalizedLine = normalizeSpaces(line)
            return containsUTF8Substring(normalizedLine, target: query)
        case .latinPrefix(let token):
            let normalizedLine = normalizeSpaces(line)
            return tokenizeLatin(normalizedLine).contains { $0.hasPrefix(token) }
        case .orderedLatinTokens(let tokens):
            let normalizedLine = normalizeSpaces(line)
            return matchesOrderedWholeTokens(normalizedLine, queryTokens: tokens)
        case .explicitFTS(let query):
            let normalizedLine = normalizeSpaces(line)
            return matchesExplicitFTSLineFallback(normalizedLine, query: query)
        }
    }

    private static func containsUTF8Substring(_ haystack: String, target needle: String) -> Bool {
        var h = haystack
        var n = needle
        return h.withUTF8 { hBuf in
            n.withUTF8 { nBuf in
                guard nBuf.count > 0 else { return true }
                guard hBuf.count >= nBuf.count else { return false }
                let firstByte = nBuf[0]
                let limit = hBuf.count - nBuf.count
                if nBuf.count == 1 {
                    for i in 0...limit where hBuf[i] == firstByte {
                        return true
                    }
                    return false
                }
                let hBase = hBuf.baseAddress!
                let nBase = nBuf.baseAddress!
                var i = 0
                while i <= limit {
                    if hBase[i] == firstByte && memcmp(hBase + i, nBase, nBuf.count) == 0 {
                        return true
                    }
                    i += 1
                }
                return false
            }
        }
    }

    static func matchRuleName(_ rule: LineMatchRule) -> String {
        switch rule {
        case .latinPrefix:
            "latinPrefix"
        case .orderedLatinTokens:
            "orderedLatinTokens"
        case .cjkSubstring:
            "cjkSubstring"
        case .explicitFTS:
            "explicitFTS"
        }
    }

    static func vocabularyTerms(in text: String) -> [String] {
        let operators = Set(["and", "or", "not", "near"])
        var terms: [String] = []
        var seen = Set<String>()
        var current = ""

        func appendTerm(_ rawTerm: String) {
            let term = rawTerm.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !term.isEmpty, !operators.contains(term), seen.insert(term).inserted else {
                return
            }
            terms.append(term)
        }

        func flushCurrent() {
            appendTerm(current)
            current = ""
        }

        for character in text {
            if character.unicodeScalars.count == 1,
               let scalar = character.unicodeScalars.first,
               isCJKSearchCharacter(scalar) {
                flushCurrent()
                appendTerm(String(character))
            } else if isASCIILetterOrDigit(character) {
                current.append(contentsOf: character.lowercased())
            } else if character == "'", !current.isEmpty {
                current.append(character)
            } else {
                flushCurrent()
            }
        }

        flushCurrent()
        return terms
    }

    static func segmentForFTS(_ text: String) -> String {
        var segmented = ""
        for scalar in text.unicodeScalars {
            segmented.unicodeScalars.append(scalar)
            if isCJKSearchCharacter(scalar) {
                segmented.append(" ")
            }
        }
        return segmented
    }

    private static func matchesExplicitFTSLineFallback(_ line: String, query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count >= 2, trimmed.first == "\"", trimmed.last == "\"" {
            let phrase = String(trimmed.dropFirst().dropLast())
            return line.range(of: phrase, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }

        let operators = Set(["AND", "OR", "NOT", "NEAR"])
        let queryTokens = tokenizeLatin(trimmed)
            .filter { !operators.contains($0.uppercased()) }
        guard !queryTokens.isEmpty else {
            return false
        }

        let lineTokens = tokenizeLatin(line)
        if trimmed.uppercased().contains(" OR ") {
            return queryTokens.contains { token in
                lineTokens.contains { $0 == token || $0.hasPrefix(token) }
            }
        }

        return queryTokens.allSatisfy { token in
            lineTokens.contains { $0 == token || $0.hasPrefix(token) }
        }
    }

    private static func containsFTSOperator(in text: String) -> Bool {
        let operators = Set(["AND", "OR", "NOT", "NEAR"])
        var current = ""

        func currentIsOperator() -> Bool {
            operators.contains(current)
        }

        for character in text {
            if isASCIIWordCharacter(character) {
                current.append(character)
            } else {
                if currentIsOperator() {
                    return true
                }
                current = ""
            }
        }

        return currentIsOperator()
    }

    private static func normalizeSpaces(_ text: String) -> String {
        text.replacingOccurrences(of: "\u{3000}", with: " ")
    }

    private static func tokenizeLatin(_ text: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        var containsApostrophe = false
        var index = text.startIndex

        func flushToken() {
            if !current.isEmpty {
                tokens.append(current)
                current = ""
            }
            containsApostrophe = false
        }

        while index < text.endIndex {
            let character = text[index]

            if isASCIILetterOrDigit(character) {
                current.append(contentsOf: character.lowercased())
            } else if character == "'", !current.isEmpty, !containsApostrophe {
                let nextIndex = text.index(after: index)
                if nextIndex < text.endIndex, isASCIILetterOrDigit(text[nextIndex]) {
                    current.append(character)
                    containsApostrophe = true
                } else {
                    flushToken()
                }
            } else {
                flushToken()
            }

            index = text.index(after: index)
        }

        flushToken()
        return tokens
    }

    private static func matchesOrderedWholeTokens(_ content: String, queryTokens: [String]) -> Bool {
        guard !queryTokens.isEmpty else {
            return false
        }

        let contentTokens = tokenizeLatin(content)
        guard contentTokens.count >= queryTokens.count else {
            return false
        }

        var queryIndex = 0
        for token in contentTokens where token == queryTokens[queryIndex] {
            queryIndex += 1
            if queryIndex == queryTokens.count {
                return true
            }
        }

        return false
    }

    private static func containsCJKSearchCharacter(in text: String) -> Bool {
        text.unicodeScalars.contains(where: isCJKSearchCharacter)
    }

    private static func isCJKSearchCharacter(_ scalar: UnicodeScalar) -> Bool {
        let value = Int(scalar.value)
        return (0x3400...0x4DBF).contains(value)
            || (0x4E00...0x9FFF).contains(value)
            || (0xF900...0xFAFF).contains(value)
            || (0x3040...0x309F).contains(value)
            || (0x30A0...0x30FF).contains(value)
            || (0x31F0...0x31FF).contains(value)
            || (0xFF66...0xFF9F).contains(value)
    }

    private static func isASCIILetterOrDigit(_ character: Character) -> Bool {
        guard character.unicodeScalars.count == 1,
              let value = character.unicodeScalars.first?.value
        else {
            return false
        }

        return (65...90).contains(value) || (97...122).contains(value) || (48...57).contains(value)
    }

    private static func escapeFTSPhrase(_ text: String) -> String {
        text.replacingOccurrences(of: "\"", with: "\"\"")
    }

    private static func isASCIIWordCharacter(_ character: Character) -> Bool {
        isASCIILetterOrDigit(character) || character == "_"
    }
}

public enum SubtitleSearchQueryMatcher {
    public static func matches(_ primaryCueText: String, query: String) -> Bool {
        guard let plan = SearchQueryPlanner.plan(for: query) else {
            return false
        }
        return SearchQueryPlanner.matches(primaryCueText, rule: plan.lineMatchRule)
    }
}
