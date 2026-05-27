import Foundation
import CueSeekerCore

struct AIChunkingResult: Equatable, Sendable {
    let normalizedSentence: String
    let items: [AIChunkItem]
    let usage: AIChunkingUsage?
    let requestContent: String
    let responseContent: String
    let durationMilliseconds: Int
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
    static let promptVersion = "chunk-v2"

    var model = Self.defaultModel
    var maxTokens = 1000
    var promptConfiguration = AIChunkingPromptConfiguration.defaultConfiguration

    func renderedPrompt(for sentence: String) throws -> AIChunkingRenderedPrompt {
        let normalizedSentence = AIChunkTextNormalizer.normalizedSentence(sentence)
        guard !normalizedSentence.isEmpty else {
            throw AIChunkingClientError.emptySentence
        }

        return AIChunkingRenderedPrompt(
            normalizedSentence: normalizedSentence,
            content: try promptConfiguration.renderedPrompt(for: normalizedSentence)
        )
    }

    func chunks(for sentence: String, apiKey: String) async throws -> AIChunkingResult {
        let renderedPrompt = try renderedPrompt(for: sentence)

        let payload = DeepSeekChatCompletionRequest(
            model: model,
            messages: [
                DeepSeekChatMessage(
                    role: "user",
                    content: renderedPrompt.content
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

        let requestStart = ContinuousClock.now
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
            normalizedSentence: renderedPrompt.normalizedSentence
        )
        let duration = requestStart.duration(to: ContinuousClock.now)
        return AIChunkingResult(
            normalizedSentence: renderedPrompt.normalizedSentence,
            items: items,
            usage: completion.usage?.aiChunkingUsage,
            requestContent: renderedPrompt.content,
            responseContent: content,
            durationMilliseconds: Self.durationMilliseconds(duration)
        )
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

    private static func durationMilliseconds(_ duration: Duration) -> Int {
        let components = duration.components
        return Int(
            components.seconds * 1_000 + components.attoseconds / 1_000_000_000_000_000
        )
    }
}

struct AIChunkingRenderedPrompt: Equatable, Sendable {
    let normalizedSentence: String
    let content: String
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
