import Foundation
import CueSeekerCore

struct AIChunkingResult: Equatable, Sendable {
    let normalizedSentence: String
    let items: [AIChunkItem]
    let usage: AIChunkingUsage?
}

struct AIChunkingUsage: Equatable, Sendable {
    static let inputPriceCNYPerMillionTokens = 1.0
    static let outputPriceCNYPerMillionTokens = 2.0

    let promptTokens: Int
    let completionTokens: Int
    let totalTokens: Int

    var estimatedCostCNY: Double {
        Double(promptTokens) / 1_000_000 * Self.inputPriceCNYPerMillionTokens
            + Double(completionTokens) / 1_000_000 * Self.outputPriceCNYPerMillionTokens
    }
}

struct DeepSeekChunkingClient: Sendable {
    var apiURL = URL(string: "https://api.deepseek.com/chat/completions")!
    static let defaultModel = "deepseek-v4-flash"
    static let promptVersion = "chunk-v1"

    var model = Self.defaultModel
    var maxTokens = 1000

    func chunks(for sentence: String, apiKey: String) async throws -> AIChunkingResult {
        let normalizedSentence = AIChunkTextNormalizer.normalizedSentence(sentence)
        guard !normalizedSentence.isEmpty else {
            throw AIChunkingClientError.emptySentence
        }

        let payload = DeepSeekChatCompletionRequest(
            model: model,
            messages: [
                DeepSeekChatMessage(
                    role: "user",
                    content: Self.prompt(for: normalizedSentence)
                )
            ],
            temperature: 0.2,
            responseFormat: DeepSeekResponseFormat(type: "json_object"),
            thinking: DeepSeekThinking(type: "disabled"),
            maxTokens: maxTokens,
            stream: false
        )

        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIChunkingClientError.invalidHTTPResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw AIChunkingClientError.requestFailed(statusCode: httpResponse.statusCode)
        }

        let completion = try JSONDecoder().decode(DeepSeekChatCompletionResponse.self, from: data)
        guard let content = completion.choices.first?.message.content,
              let contentData = content.data(using: .utf8)
        else {
            throw AIChunkingClientError.missingContent
        }

        let decodedContent: AIChunkingContent
        do {
            decodedContent = try JSONDecoder().decode(AIChunkingContent.self, from: contentData)
        } catch {
            throw AIChunkingClientError.invalidJSON
        }

        let items = try Self.validatedItems(
            decodedContent.items,
            normalizedSentence: normalizedSentence
        )
        return AIChunkingResult(
            normalizedSentence: normalizedSentence,
            items: items,
            usage: completion.usage?.aiChunkingUsage
        )
    }

    private static func prompt(for sentence: String) -> String {
        """
        从句子中抽取适合继续检索和语言学习的词块（Chunks），并提供每个词块的简体中文翻译。只返回 JSON 格式。

        格式要求：
        {
          "items": [
            {"item": "词块1", "translation": "词块1的简体中文翻译"},
            {"item": "词块2", "translation": "词块2的简体中文翻译"},
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

        句子：\(sentence)
        """
    }

    private static func validatedItems(
        _ rawItems: [AIChunkItem],
        normalizedSentence: String
    ) throws -> [AIChunkItem] {
        var seen = Set<String>()
        var items: [AIChunkItem] = []

        for rawItem in rawItems {
            let itemStr = rawItem.item.trimmingCharacters(in: .whitespacesAndNewlines)
            let translationStr = rawItem.translation.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !itemStr.isEmpty else {
                continue
            }
            guard seen.insert(itemStr).inserted else {
                continue
            }
            items.append(AIChunkItem(item: itemStr, translation: translationStr))
        }

        guard !items.isEmpty else {
            throw AIChunkingClientError.emptyItems
        }
        return items
    }
}

enum AIChunkingClientError: LocalizedError {
    case emptySentence
    case invalidHTTPResponse
    case requestFailed(statusCode: Int)
    case missingContent
    case invalidJSON
    case emptyItems
    case itemNotFound(String)

    var errorDescription: String? {
        switch self {
        case .emptySentence:
            return "The sentence is empty after cleanup."
        case .invalidHTTPResponse:
            return "The AI service returned an invalid response."
        case .requestFailed(let statusCode):
            return "The AI service request failed with HTTP \(statusCode)."
        case .missingContent:
            return "The AI service returned no content."
        case .invalidJSON:
            return "The AI service returned invalid JSON."
        case .emptyItems:
            return "The AI service returned no usable chunks."
        case .itemNotFound(let item):
            return "The AI service returned text outside the sentence: \(item)"
        }
    }
}

private struct DeepSeekChatCompletionRequest: Encodable {
    let model: String
    let messages: [DeepSeekChatMessage]
    let temperature: Double
    let responseFormat: DeepSeekResponseFormat
    let thinking: DeepSeekThinking
    let maxTokens: Int
    let stream: Bool

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case temperature
        case responseFormat = "response_format"
        case thinking
        case maxTokens = "max_tokens"
        case stream
    }
}

private struct DeepSeekChatMessage: Codable {
    let role: String
    let content: String
}

private struct DeepSeekResponseFormat: Encodable {
    let type: String
}

private struct DeepSeekThinking: Encodable {
    let type: String
}

private struct DeepSeekChatCompletionResponse: Decodable {
    let choices: [DeepSeekChatChoice]
    let usage: DeepSeekUsage?
}

private struct DeepSeekChatChoice: Decodable {
    let message: DeepSeekChatMessage
}

private struct AIChunkingContent: Decodable {
    let items: [AIChunkItem]
}

private struct DeepSeekUsage: Decodable {
    let promptTokens: Int?
    let completionTokens: Int?
    let totalTokens: Int?

    var aiChunkingUsage: AIChunkingUsage {
        let resolvedPromptTokens = promptTokens ?? 0
        let resolvedCompletionTokens = completionTokens ?? 0
        return AIChunkingUsage(
            promptTokens: resolvedPromptTokens,
            completionTokens: resolvedCompletionTokens,
            totalTokens: totalTokens ?? resolvedPromptTokens + resolvedCompletionTokens
        )
    }

    enum CodingKeys: String, CodingKey {
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case totalTokens = "total_tokens"
    }
}
