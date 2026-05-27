import Foundation

enum AIChunkingTranslationLanguage: String, CaseIterable, Identifiable, Sendable {
    case simplifiedChinese = "简体中文"
    case traditionalChinese = "繁體中文"
    case english = "English"
    case japanese = "日本語"

    static let defaultValue: Self = .simplifiedChinese

    var id: String {
        rawValue
    }
}

struct AIChunkingPromptConfiguration: Equatable, Sendable {
    static let sentencePlaceholder = "{{sentence}}"
    static let languagePlaceholder = "{{language}}"
    static let requiredPlaceholders = [
        sentencePlaceholder,
        languagePlaceholder
    ]
    private static let supportedPlaceholders = Set(requiredPlaceholders)

    static let defaultTemplate = """
    从句子中抽取适合继续检索和语言学习的词块（Chunks），并提供每个词块的{{language}}翻译。只返回 JSON 格式。

    格式要求：
    {
      "items": [
        {"item": "词块1", "translation": "词块1的{{language}}翻译"},
        {"item": "词块2", "translation": "词块2的{{language}}翻译"},
        ...
      ]
    }

    规则：
    1. 自动识别输入句子的语言，并针对该语言进行“多层级、高召回率”的词块提取，允许并鼓励词块在原句中重叠；
    2. 词块应覆盖多个学习层级：
       - 核心词汇：名词、形容词、副词、动词。对于有词性/时态变化的语言，动词和形容词应同时提取“原句中的具体活用形态”和“对应的字典原型/原形”；
       - 语法句型与接续：提取句子中的关键语法句型、固定搭配、短语尾缀、连词/接续词；
       - 复合短语与文节：提取由词汇和助词/介词组合而成的复合短语、连体修饰块或语言学文节，以展示真实的词汇语境搭配；
    3. 过滤无意义字符：避免单独提取无检索和学习价值的单字符助词（如日语中单独的“の”、“を”，英语中单独的“a”、“the”），但它们与核心词组合而成的完整词块应当保留；
    4. 数量动态决定：词块数量应当根据输入句子的长度与复杂度自然决定。长句应提取出丰富的多层级词块，短句则仅保留有价值的少数核心词块，切忌为了凑数而强行拆解无意义的字词；
    5. 词块翻译要求：精准翻译每个词块在“当前句子语境下”的含义和语法作用（如果是助词/连词/句式，可以说明其语法功能，如“格助词，表示宾语”或“表示限定的假定语法”）。

    句子：{{sentence}}
    """

    static let defaultConfiguration = AIChunkingPromptConfiguration(
        template: defaultTemplate,
        translationLanguage: AIChunkingTranslationLanguage.defaultValue
    )

    let template: String
    let translationLanguage: AIChunkingTranslationLanguage

    func renderedPrompt(for sentence: String) throws -> String {
        try Self.validateTemplate(template)

        return template
            .replacingOccurrences(of: Self.languagePlaceholder, with: translationLanguage.rawValue)
            .replacingOccurrences(of: Self.sentencePlaceholder, with: sentence)
    }

    func cachePromptVersion(baseVersion: String) -> String {
        let signatureSource = template + "\n--translation-language--\n" + translationLanguage.rawValue
        return "\(baseVersion)-cfg-\(Self.shortHash(for: signatureSource))"
    }

    static func validateTemplate(_ template: String) throws {
        if let unsupportedPlaceholder = firstUnsupportedPlaceholder(in: template) {
            throw AIChunkingPromptTemplateError.unsupportedPlaceholder(unsupportedPlaceholder)
        }

        for placeholder in requiredPlaceholders where !template.contains(placeholder) {
            throw AIChunkingPromptTemplateError.missingRequiredPlaceholder(placeholder)
        }
    }

    private static func firstUnsupportedPlaceholder(in template: String) -> String? {
        var searchRange = template.startIndex..<template.endIndex

        while let openingRange = template.range(of: "{{", options: [], range: searchRange) {
            if let closingBeforeOpening = template.range(of: "}}", options: [], range: searchRange),
               closingBeforeOpening.lowerBound < openingRange.lowerBound
            {
                return "}}"
            }

            guard let closingRange = template.range(
                of: "}}",
                options: [],
                range: openingRange.upperBound..<template.endIndex
            ) else {
                return String(template[openingRange.lowerBound..<template.endIndex])
            }

            let placeholder = String(template[openingRange.lowerBound..<closingRange.upperBound])
            if !supportedPlaceholders.contains(placeholder) {
                return placeholder
            }

            searchRange = closingRange.upperBound..<template.endIndex
        }

        if template.range(of: "}}", options: [], range: searchRange) != nil {
            return "}}"
        }

        return nil
    }

    private static func shortHash(for text: String) -> String {
        let hash = text.utf8.reduce(UInt64(14_695_981_039_346_656_037)) { partialResult, byte in
            (partialResult ^ UInt64(byte)) &* 1_099_511_628_211
        }
        return String(hash, radix: 16)
    }
}

enum AIChunkingPromptTemplateError: LocalizedError, Equatable {
    case missingRequiredPlaceholder(String)
    case unsupportedPlaceholder(String)

    var errorDescription: String? {
        switch self {
        case .missingRequiredPlaceholder(let placeholder):
            return "The AI chunking prompt must include \(placeholder)."
        case .unsupportedPlaceholder(let placeholder):
            return "The AI chunking prompt includes unsupported placeholder \(placeholder)."
        }
    }
}
