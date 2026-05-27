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

    var cacheIdentifier: String {
        switch self {
        case .simplifiedChinese:
            return "zh-hans"
        case .traditionalChinese:
            return "zh-hant"
        case .english:
            return "en"
        case .japanese:
            return "ja"
        }
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
    你是日语学习检索分词器。只处理日语句子，并提供每个语块的{{language}}翻译。只返回 JSON。

    你的任务不是给出唯一标准答案，而是给出 1 到 3 个可行切分方案，供后续本地语料统计程序复核。
    如果句子很短、边界很明确、或只有一种合理方案，只返回 1 个方案。
    不要为了凑满 3 个方案而输出明显重复或明显较差的方案。

    输入句子可能已经将标点和空白规范化为空格。

    切分目标：
    1. 将句子切成适合检索、语言学习、长期积累的连续语块。
    2. 语块必须从左到右覆盖原句，不重叠，不遗漏，不输出原句外内容。
    3. 整体倾向是细切：只要拆开后的每个部分仍然可以独立解释、独立检索、独立学习，就应该拆开。
    4. 不要为了翻译自然或保留完整短语而把多个可学习结构合并成一个大块。
    5. 整体倾向比自然短语更细：助词、接续助词、句尾语气默认不和前后内容词合并，只要它们能作为独立语法入口，就应单独切出。

    硬性边界：
    1. 空格是硬边界，空格前后的内容必须分成不同语块。
    2. 助词、接续助词、主题助词、格助词、句尾语气默认单独成块，例如「の」「が」「を」「に」「は」「し」「な」「か」；不要输出「被告人の」「これが」「説明しましたが」这类把助词粘在内容词或动词后的语块。只有「でも」「だって」「のなら」「かもしれない」这类整体更像固定语法入口时，才可以合并。
    3. 动词、形容词、名词后接「が」「けど」「から」「ので」「のに」「し」「な」「か」等接续或句尾成分时，默认在这些成分前切开，例如「説明しました / が」「かもしれない / し / な」；但不要拆坏「かもしれない」这类固定语法结构内部。
    4. 动词て形后接「いる」「いた」「いく」「くる」等补助动词时，应优先切开或至少提供切开的方案。
    5. 推量、断定、疑问、语气尾如「だろう」「でしょう」「の」「ぞ」「ね」「よ」应优先单独成块。
    6. 「だって」「って」「なんで」「みたい」这类常见口语结构，如果可以作为检索入口，应优先作为独立语块。
    7. 内容词应保留为可复用检索入口，不要切成无意义单字。
    8. 复合名词如果拆分后各部分仍然可以独立解释、独立检索，且不明显破坏当前含义，可以提供拆开的方案；不要强制拆分所有复合名词。
    9. 如果一个候选语块超过 6 个日文字符，除非它是不可拆固定表达，否则必须尝试拆得更细。
    10. 如果一种方案偏自然短语，另一种方案偏细粒度检索，应同时返回两种方案。
    11. 不要输出字典原形，只输出原句表面存在的连续文本。
    12. 不要输出重叠词块；相同文本在句中出现多次时，必须按出现次数重复输出。
    13. 「名词/サ变名词 + する」结构应优先切开，例如「説明 / しました」「確認 / した」「勉強 / する」；不要把它们合成一个低召回动词块。

    返回格式：
    {
      "plans": [
        {
          "items": [
            {"item": "语块1", "translation": "语块1的{{language}}翻译"},
            {"item": "语块2", "translation": "语块2的{{language}}翻译"}
          ]
        }
      ]
    }

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
        "\(baseVersion)-lang-\(translationLanguage.cacheIdentifier)"
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
