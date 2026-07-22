import Foundation

public struct AIChunkCacheKey: Equatable, Hashable, Sendable {
    public let normalizedSentence: String
    public let provider: String
    public let model: String
    public let promptVersion: String

    public init(
        normalizedSentence: String,
        provider: String,
        model: String,
        promptVersion: String
    ) {
        self.normalizedSentence = normalizedSentence
        self.provider = provider
        self.model = model
        self.promptVersion = promptVersion
    }
}

public enum AIChunkDisplayGroup: String, Codable, Sendable {
    case primary
    case additional
}

public struct AIChunkItem: Codable, Equatable, Sendable {
    public let item: String
    public let translation: String
    public let displayGroup: AIChunkDisplayGroup

    public init(
        item: String,
        translation: String,
        displayGroup: AIChunkDisplayGroup = .primary
    ) {
        self.item = item
        self.translation = translation
        self.displayGroup = displayGroup
    }

    private enum CodingKeys: String, CodingKey {
        case item
        case translation
        case displayGroup
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        item = try container.decode(String.self, forKey: .item)
        translation = try container.decode(String.self, forKey: .translation)
        displayGroup = try container.decodeIfPresent(AIChunkDisplayGroup.self, forKey: .displayGroup) ?? .primary
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(item, forKey: .item)
        try container.encode(translation, forKey: .translation)
        try container.encode(displayGroup, forKey: .displayGroup)
    }
}

public struct AIChunkCacheEntry: Equatable, Sendable {
    public let key: AIChunkCacheKey
    public let chunks: [AIChunkItem]
    public let cacheDate: String
}

public enum AIChunkCacheError: Error, Equatable {
    case emptyNormalizedSentence
    case emptyProvider
    case emptyModel
    case emptyPromptVersion
    case emptyChunks
}

