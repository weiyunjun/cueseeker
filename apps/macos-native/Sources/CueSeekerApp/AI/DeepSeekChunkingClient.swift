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

struct AIChunkingValidatedChunk: Equatable, Sendable {
    let item: AIChunkItem
    let startOffset: Int
    let endOffset: Int
}

struct AIChunkingValidatedPlan: Equatable, Sendable {
    let chunks: [AIChunkingValidatedChunk]

    var items: [AIChunkItem] {
        chunks.map(\.item)
    }
}

private struct AIChunkingSplitCandidate {
    let planIndex: Int
    let chunkIndex: Int
    let chunk: AIChunkingValidatedChunk
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

        let items = try Self.validatedItems(
            responseContentData: contentData,
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

    static func validatedItems(
        responseContent: String,
        normalizedSentence: String
    ) throws -> [AIChunkItem] {
        guard let contentData = responseContent.data(using: .utf8) else {
            throw AIChunkingClientError.invalidJSON
        }

        return try validatedItems(
            responseContentData: contentData,
            normalizedSentence: normalizedSentence
        )
    }

    private static func validatedItems(
        responseContentData: Data,
        normalizedSentence: String
    ) throws -> [AIChunkItem] {
        let decodedContent: AIChunkingContent
        do {
            decodedContent = try JSONDecoder().decode(AIChunkingContent.self, from: responseContentData)
        } catch {
            throw AIChunkingClientError.invalidJSON
        }

        let validatedPlans = try validatedPlans(
            decodedContent.plans.map(\.items),
            normalizedSentence: normalizedSentence
        )
        return mergedItems(from: validatedPlans)
    }

    static func validatedPlans(
        _ rawPlans: [[AIChunkItem]],
        normalizedSentence: String
    ) throws -> [AIChunkingValidatedPlan] {
        guard (1...3).contains(rawPlans.count) else {
            throw AIChunkingClientError.invalidPlanCount
        }

        let plans = rawPlans.compactMap { rawItems in
            try? validatedPlan(rawItems, normalizedSentence: normalizedSentence)
        }

        guard !plans.isEmpty else {
            throw AIChunkingClientError.noValidPlans
        }
        return plans
    }

    static func mergedItems(from plans: [AIChunkingValidatedPlan]) -> [AIChunkItem] {
        guard let basePlan = plans.first else {
            return []
        }
        guard plans.count > 1 else {
            return basePlan.items
        }

        let splitSourcePlans = Array(plans.dropFirst())
        let splitPlan = AIChunkingValidatedPlan(
            chunks: basePlan.chunks.flatMap { baseChunk in
                splitChunks(for: baseChunk, using: splitSourcePlans) ?? [baseChunk]
            }
        )
        return deduplicatedItems(from: [splitPlan] + plans)
    }

    private static func splitChunks(
        for baseChunk: AIChunkingValidatedChunk,
        using plans: [AIChunkingValidatedPlan]
    ) -> [AIChunkingValidatedChunk]? {
        let candidates = splitCandidates(for: baseChunk, using: plans)
        guard !candidates.isEmpty,
              let chunks = splitChunks(
                from: baseChunk.startOffset,
                to: baseChunk.endOffset,
                using: candidates
              ),
              chunks.count > 1
        else {
            return nil
        }

        return chunks
    }

    private static func splitCandidates(
        for baseChunk: AIChunkingValidatedChunk,
        using plans: [AIChunkingValidatedPlan]
    ) -> [AIChunkingSplitCandidate] {
        plans.enumerated().flatMap { planIndex, plan in
            plan.chunks.enumerated().compactMap { chunkIndex, chunk in
                guard chunk.startOffset >= baseChunk.startOffset,
                      chunk.endOffset <= baseChunk.endOffset,
                      chunk.startOffset != baseChunk.startOffset || chunk.endOffset != baseChunk.endOffset
                else {
                    return nil
                }

                return AIChunkingSplitCandidate(
                    planIndex: planIndex,
                    chunkIndex: chunkIndex,
                    chunk: chunk
                )
            }
        }
        .sorted { lhs, rhs in
            if lhs.planIndex != rhs.planIndex {
                return lhs.planIndex < rhs.planIndex
            }
            return lhs.chunkIndex < rhs.chunkIndex
        }
    }

    private static func splitChunks(
        from startOffset: Int,
        to endOffset: Int,
        using candidates: [AIChunkingSplitCandidate]
    ) -> [AIChunkingValidatedChunk]? {
        guard startOffset < endOffset else {
            return []
        }

        for candidate in candidates where candidate.chunk.startOffset == startOffset {
            guard let tail = splitChunks(
                from: candidate.chunk.endOffset,
                to: endOffset,
                using: candidates
            ) else {
                continue
            }

            return [candidate.chunk] + tail
        }

        return nil
    }

    private static func deduplicatedItems(from plans: [AIChunkingValidatedPlan]) -> [AIChunkItem] {
        var seen = Set<String>()
        var items: [AIChunkItem] = []

        for item in plans.flatMap(\.items) where seen.insert(item.item).inserted {
            items.append(item)
        }
        return items
    }

    private static func validatedPlan(
        _ rawItems: [AIChunkItem],
        normalizedSentence: String
    ) throws -> AIChunkingValidatedPlan {
        guard !rawItems.isEmpty else {
            throw AIChunkingClientError.emptyItems
        }

        var chunks: [AIChunkingValidatedChunk] = []
        var currentIndex = normalizedSentence.startIndex

        for rawItem in rawItems {
            currentIndex = skipSpaces(in: normalizedSentence, from: currentIndex)

            let itemStr = rawItem.item.trimmingCharacters(in: .whitespacesAndNewlines)
            let translationStr = rawItem.translation.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !itemStr.isEmpty else {
                throw AIChunkingClientError.emptyItems
            }
            guard itemStr.rangeOfCharacter(from: .whitespacesAndNewlines) == nil else {
                throw AIChunkingClientError.itemNotFound(itemStr)
            }
            guard normalizedSentence[currentIndex...].hasPrefix(itemStr),
                  let endIndex = normalizedSentence.index(
                    currentIndex,
                    offsetBy: itemStr.count,
                    limitedBy: normalizedSentence.endIndex
                  )
            else {
                throw AIChunkingClientError.itemNotFound(itemStr)
            }

            chunks.append(AIChunkingValidatedChunk(
                item: AIChunkItem(item: itemStr, translation: translationStr),
                startOffset: normalizedSentence.distance(
                    from: normalizedSentence.startIndex,
                    to: currentIndex
                ),
                endOffset: normalizedSentence.distance(
                    from: normalizedSentence.startIndex,
                    to: endIndex
                )
            ))
            currentIndex = endIndex
        }

        let finalIndex = skipSpaces(in: normalizedSentence, from: currentIndex)
        guard finalIndex == normalizedSentence.endIndex else {
            throw AIChunkingClientError.itemNotFound(String(normalizedSentence[finalIndex...]))
        }

        return AIChunkingValidatedPlan(chunks: chunks)
    }

    private static func skipSpaces(in string: String, from startIndex: String.Index) -> String.Index {
        var index = startIndex
        while index < string.endIndex,
              string[index].unicodeScalars.allSatisfy({ CharacterSet.whitespacesAndNewlines.contains($0) })
        {
            index = string.index(after: index)
        }
        return index
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
    case invalidPlanCount
    case noValidPlans
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
        case .invalidPlanCount:
            return "The AI service returned an invalid number of chunking plans."
        case .noValidPlans:
            return "The AI service returned no valid chunking plans."
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
    let plans: [AIChunkingPlanContent]
}

private struct AIChunkingPlanContent: Decodable {
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
