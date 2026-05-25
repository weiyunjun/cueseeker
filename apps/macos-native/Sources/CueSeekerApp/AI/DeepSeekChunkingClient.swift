import Foundation

struct AIChunkingResult: Equatable, Sendable {
    let normalizedSentence: String
    let items: [String]
}

struct DeepSeekChunkingClient: Sendable {
    var apiURL = URL(string: "https://api.deepseek.com/chat/completions")!
    var model = "deepseek-v4-flash"
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
        return AIChunkingResult(normalizedSentence: normalizedSentence, items: items)
    }

    private static func prompt(for sentence: String) -> String {
        """
        从句子中抽取适合继续检索的最小学习项。只返回 JSON。
        格式：{"items":["项1","项2"]}。
        规则：items 必须是原句中的连续原文片段；不要求覆盖整句；允许重叠；只抽取最小可独立查询单位；优先抽取名词、动词、形容词、固定表达、语法结构；不要擅自合并相邻词成短语；语法结构要返回完整形式，不要删掉助词或组成部分；不要返回普通代词、普通助词或无意义半截字符；通常返回 4 到 10 个。句子：\(sentence)
        """
    }

    private static func validatedItems(
        _ rawItems: [String],
        normalizedSentence: String
    ) throws -> [String] {
        var seen = Set<String>()
        var items: [String] = []

        for rawItem in rawItems {
            let item = rawItem.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !item.isEmpty else {
                continue
            }
            guard normalizedSentence.contains(item) else {
                throw AIChunkingClientError.itemNotFound(item)
            }
            guard seen.insert(item).inserted else {
                continue
            }
            items.append(item)
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
}

private struct DeepSeekChatChoice: Decodable {
    let message: DeepSeekChatMessage
}

private struct AIChunkingContent: Decodable {
    let items: [String]
}
