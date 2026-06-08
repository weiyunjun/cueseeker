import Foundation

public struct SubtitleSearchFilterSet: Codable, Equatable, Hashable, Sendable {
    public var rules: [SubtitleSearchFilterRule]

    public init(rules: [SubtitleSearchFilterRule] = []) {
        self.rules = rules
    }

    public var isEffectivelyEmpty: Bool {
        activeRules.isEmpty
    }

    public var cacheSignature: String {
        guard !isEffectivelyEmpty else {
            return ""
        }

        let ruleSignatures = activeRules.map { rule in
            [
                rule.join?.rawValue ?? "",
                rule.field.rawValue,
                rule.operatorID.rawValue,
                rule.value,
            ].joined(separator: "\u{1f}")
        }

        return "\(resolvedJoin.rawValue):" + ruleSignatures.joined(separator: "\u{1e}")
    }

    public func matches(display: String, cues: String, languages: [String]) -> Bool {
        let activeRules = activeRules
        guard !activeRules.isEmpty else {
            return true
        }

        let results = activeRules.map { rule in
            rule.matches(display: display, cues: cues, languages: languages)
        }

        switch resolvedJoin {
        case .and:
            return results.allSatisfy { $0 }
        case .or:
            return results.contains(true)
        }
    }

    private var activeRules: [SubtitleSearchFilterRule] {
        rules.filter { $0.isActive }
    }

    private var resolvedJoin: SubtitleSearchFilterJoin {
        rules.dropFirst().first?.join ?? .and
    }
}

public struct SubtitleSearchFilterRule: Codable, Equatable, Hashable, Sendable {
    public var join: SubtitleSearchFilterJoin?
    public var field: SubtitleSearchFilterField
    public var operatorID: SubtitleSearchFilterOperator
    public var value: String

    public init(
        join: SubtitleSearchFilterJoin? = nil,
        field: SubtitleSearchFilterField,
        operatorID: SubtitleSearchFilterOperator,
        value: String = ""
    ) {
        self.join = join
        self.field = field
        self.operatorID = operatorID
        self.value = value
    }

    public var isActive: Bool {
        !operatorID.requiresValue || !value.isEmpty
    }

    public func matches(display: String, cues: String, languages: [String]) -> Bool {
        switch field.dataType {
        case .string:
            return matchesString(stringValue(forDisplay: display, cues: cues))
        case .stringSet:
            return matchesStringSet(languages)
        case .number:
            return false
        }
    }

    private func stringValue(forDisplay display: String, cues: String) -> String {
        switch field {
        case .display:
            return display
        case .cues:
            return cues
        case .language:
            return ""
        }
    }

    private func matchesString(_ candidate: String) -> Bool {
        switch operatorID {
        case .is:
            return candidate == value
        case .isNot:
            return candidate != value
        case .contains:
            return candidate.contains(value)
        case .doesNotContain:
            return !candidate.contains(value)
        case .isEmpty:
            return candidate.isEmpty
        case .isNotEmpty:
            return !candidate.isEmpty
        case .equals,
             .doesNotEqual,
             .greaterThan,
             .greaterThanOrEqualTo,
             .lessThan,
             .lessThanOrEqualTo:
            return false
        }
    }

    private func matchesStringSet(_ candidates: [String]) -> Bool {
        switch operatorID {
        case .contains:
            return candidates.contains { $0.contains(value) }
        case .doesNotContain:
            return !candidates.contains { $0.contains(value) }
        case .isEmpty:
            return candidates.isEmpty
        case .isNotEmpty:
            return !candidates.isEmpty
        case .is,
             .isNot,
             .equals,
             .doesNotEqual,
             .greaterThan,
             .greaterThanOrEqualTo,
             .lessThan,
             .lessThanOrEqualTo:
            return false
        }
    }
}

public enum SubtitleSearchFilterJoin: String, Codable, CaseIterable, Hashable, Sendable {
    case and
    case or
}

public enum SubtitleSearchFilterField: String, Codable, CaseIterable, Hashable, Sendable {
    case display
    case cues
    case language

    public var dataType: SubtitleSearchFilterDataType {
        switch self {
        case .display, .cues:
            return .string
        case .language:
            return .stringSet
        }
    }
}

public enum SubtitleSearchFilterDataType: String, Codable, Hashable, Sendable {
    case string
    case stringSet
    case number
}

public enum SubtitleSearchFilterOperator: String, Codable, CaseIterable, Hashable, Sendable {
    case `is`
    case isNot
    case contains
    case doesNotContain
    case isEmpty
    case isNotEmpty
    case equals
    case doesNotEqual
    case greaterThan
    case greaterThanOrEqualTo
    case lessThan
    case lessThanOrEqualTo

    public var requiresValue: Bool {
        switch self {
        case .isEmpty, .isNotEmpty:
            return false
        case .is,
             .isNot,
             .contains,
             .doesNotContain,
             .equals,
             .doesNotEqual,
             .greaterThan,
             .greaterThanOrEqualTo,
             .lessThan,
             .lessThanOrEqualTo:
            return true
        }
    }

    public static func allowed(for dataType: SubtitleSearchFilterDataType) -> [SubtitleSearchFilterOperator] {
        switch dataType {
        case .string:
            return [.is, .isNot, .contains, .doesNotContain, .isEmpty, .isNotEmpty]
        case .stringSet:
            return [.contains, .doesNotContain, .isEmpty, .isNotEmpty]
        case .number:
            return [
                .equals,
                .doesNotEqual,
                .greaterThan,
                .greaterThanOrEqualTo,
                .lessThan,
                .lessThanOrEqualTo,
                .isEmpty,
                .isNotEmpty,
            ]
        }
    }
}
