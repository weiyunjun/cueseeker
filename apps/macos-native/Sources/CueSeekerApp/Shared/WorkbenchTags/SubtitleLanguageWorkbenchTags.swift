import CueSeekerCore

enum SubtitleLanguageWorkbenchTags {
    private static let languageOrder: [SubtitleLanguageCode: Int] = [
        .simplifiedChinese: 0,
        .traditionalChinese: 1,
        .chinese: 2,
        .english: 3,
        .japanese: 4,
        .unknown: 5,
    ]

    static func tags(for languages: Set<SubtitleLanguageCode>) -> [WorkbenchTag] {
        let resolvedLanguages = languages.isEmpty ? Set([SubtitleLanguageCode.unknown]) : languages
        return resolvedLanguages
            .sorted { lhs, rhs in
                let lhsOrder = languageOrder[lhs] ?? Int.max
                let rhsOrder = languageOrder[rhs] ?? Int.max
                if lhsOrder != rhsOrder {
                    return lhsOrder < rhsOrder
                }
                return lhs.rawValue < rhs.rawValue
            }
            .map { language in
                WorkbenchTag(key: tagKey(for: language), colorID: .blue)
            }
    }

    private static func tagKey(for language: SubtitleLanguageCode) -> String {
        switch language {
        case .simplifiedChinese:
            return "zh-hans"
        case .traditionalChinese:
            return "zh-hant"
        case .chinese:
            return "zh"
        case .english:
            return "en"
        case .japanese:
            return "jp"
        case .unknown:
            return "unknown"
        }
    }
}
