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
        let normalizedLine = normalizeSpaces(line)
        return switch rule {
        case .latinPrefix(let token):
            tokenizeLatin(normalizedLine).contains { $0.hasPrefix(token) }
        case .orderedLatinTokens(let tokens):
            matchesOrderedWholeTokens(normalizedLine, queryTokens: tokens)
        case .cjkSubstring(let query):
            normalizedLine.contains(query)
        case .explicitFTS(let query):
            matchesExplicitFTSLineFallback(normalizedLine, query: query)
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
