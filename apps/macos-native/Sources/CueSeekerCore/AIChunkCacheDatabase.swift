import Foundation

public final class AIChunkCacheDatabase: @unchecked Sendable {
    private let database: SQLiteDatabase

    public init(
        path: URL,
        access: DatabaseConnectionAccess = .readWrite
    ) throws {
        database = try SQLiteDatabase(path: path, access: access)
    }

    public func aiChunkCacheEntry(for key: AIChunkCacheKey) throws -> AIChunkCacheEntry? {
        try Self.validateAIChunkCacheKey(key)

        let statement = try database.prepare(
            """
            SELECT normalized_sentence, provider, model, prompt_version, chunks_json, cache_date
            FROM ai_chunk_cache_entries
            WHERE normalized_sentence = ?
              AND provider = ?
              AND model = ?
              AND prompt_version = ?
            LIMIT 1;
            """
        )

        try statement.bind(key.normalizedSentence, at: 1)
        try statement.bind(key.provider, at: 2)
        try statement.bind(key.model, at: 3)
        try statement.bind(key.promptVersion, at: 4)

        guard try statement.step() else {
            return nil
        }

        return try aiChunkCacheEntry(from: statement)
    }

    @discardableResult
    public func upsertAIChunkCacheEntry(
        key: AIChunkCacheKey,
        chunks: [AIChunkItem],
        cacheDate: String = ISO8601DateFormatter().string(from: Date())
    ) throws -> AIChunkCacheEntry {
        try Self.validateAIChunkCacheKey(key)
        try Self.validateAIChunkCacheChunks(chunks)

        let chunksJSON = try Self.encodeAIChunks(chunks)
        let statement = try database.prepare(
            """
            INSERT INTO ai_chunk_cache_entries(
                normalized_sentence,
                provider,
                model,
                prompt_version,
                chunks_json,
                cache_date
            )
            VALUES (?, ?, ?, ?, ?, ?)
            ON CONFLICT(normalized_sentence, provider, model, prompt_version)
            DO UPDATE SET chunks_json = excluded.chunks_json
            RETURNING normalized_sentence, provider, model, prompt_version, chunks_json, cache_date;
            """
        )

        try statement.bind(key.normalizedSentence, at: 1)
        try statement.bind(key.provider, at: 2)
        try statement.bind(key.model, at: 3)
        try statement.bind(key.promptVersion, at: 4)
        try statement.bind(chunksJSON, at: 5)
        try statement.bind(cacheDate, at: 6)

        guard try statement.step() else {
            throw SQLiteDatabaseError.stepFailed("AI chunk cache entry could not be saved")
        }

        return try aiChunkCacheEntry(from: statement)
    }

    public func clearAIChunkCacheEntries() throws {
        try database.execute("DELETE FROM ai_chunk_cache_entries;")
    }


    private func aiChunkCacheEntry(from statement: SQLiteStatement) throws -> AIChunkCacheEntry {
        let key = AIChunkCacheKey(
            normalizedSentence: statement.stringColumn(0),
            provider: statement.stringColumn(1),
            model: statement.stringColumn(2),
            promptVersion: statement.stringColumn(3)
        )
        let chunks = try Self.decodeAIChunks(statement.stringColumn(4))

        return AIChunkCacheEntry(
            key: key,
            chunks: chunks,
            cacheDate: statement.stringColumn(5)
        )
    }


    private static func validateAIChunkCacheKey(_ key: AIChunkCacheKey) throws {
        guard !key.normalizedSentence.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AIChunkCacheError.emptyNormalizedSentence
        }
        guard !key.provider.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AIChunkCacheError.emptyProvider
        }
        guard !key.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AIChunkCacheError.emptyModel
        }
        guard !key.promptVersion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AIChunkCacheError.emptyPromptVersion
        }
    }

    private static func validateAIChunkCacheChunks(_ chunks: [AIChunkItem]) throws {
        guard !chunks.isEmpty,
              chunks.allSatisfy({ !$0.item.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
        else {
            throw AIChunkCacheError.emptyChunks
        }
    }

    private static func encodeAIChunks(_ chunks: [AIChunkItem]) throws -> String {
        String(decoding: try JSONEncoder().encode(chunks), as: UTF8.self)
    }

    private static func decodeAIChunks(_ chunksJSON: String) throws -> [AIChunkItem] {
        guard let data = chunksJSON.data(using: .utf8) else {
            throw SQLiteDatabaseError.stepFailed("AI chunk cache entry contains invalid UTF-8 JSON")
        }

        return try JSONDecoder().decode([AIChunkItem].self, from: data)
    }

}
