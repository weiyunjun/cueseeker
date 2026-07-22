import Foundation
import Testing
@testable import CueSeekerCore

@Test
func storesAndLoadsAIChunkCacheEntry() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    try DatabaseBootstrap.prepare(at: databaseURL)
    let cache = try AIChunkCacheDatabase(path: databaseURL)

    let key = AIChunkCacheKey(
        normalizedSentence: "運も実力のうちだ",
        provider: "deepseek",
        model: "deepseek-v4-flash",
        promptVersion: "chunk-v1"
    )
    let cacheDate = "2026-05-26T00:00:00Z"

    let saved = try cache.upsertAIChunkCacheEntry(
        key: key,
        chunks: mockChunks(["運", "実力", "うち"]),
        cacheDate: cacheDate
    )
    let loaded = try cache.aiChunkCacheEntry(for: key)

    #expect(saved.key == key)
    #expect(saved.chunks == mockChunks(["運", "実力", "うち"]))
    #expect(saved.cacheDate == cacheDate)
    #expect(loaded == saved)
}

@Test
func decodesLegacyAIChunkItemsWithoutDisplayGroups() throws {
    let data = """
    [
      {"item": "運", "translation": "运气"}
    ]
    """.data(using: .utf8)!

    let chunks = try JSONDecoder().decode([AIChunkItem].self, from: data)

    #expect(chunks == [
        AIChunkItem(item: "運", translation: "运气")
    ])
}

@Test
func refreshingAIChunkCachePreservesCacheDate() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    try DatabaseBootstrap.prepare(at: databaseURL)
    let cache = try AIChunkCacheDatabase(path: databaseURL)

    let key = AIChunkCacheKey(
        normalizedSentence: "春日影はわたくしたちの歌ですのね",
        provider: "deepseek",
        model: "deepseek-v4-flash",
        promptVersion: "chunk-v1"
    )

    try cache.upsertAIChunkCacheEntry(
        key: key,
        chunks: mockChunks(["春日影", "わたくしたち", "歌"]),
        cacheDate: "2026-05-26T00:00:00Z"
    )
    let refreshed = try cache.upsertAIChunkCacheEntry(
        key: key,
        chunks: mockChunks(["春日影", "わたくしたちの歌"]),
        cacheDate: "2026-05-27T00:00:00Z"
    )
    let loaded = try cache.aiChunkCacheEntry(for: key)

    #expect(refreshed.chunks == mockChunks(["春日影", "わたくしたちの歌"]))
    #expect(refreshed.cacheDate == "2026-05-26T00:00:00Z")
    #expect(loaded == refreshed)
}

@Test
func storesSameAIChunkSeparatelyForDifferentSubtitleLines() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    try DatabaseBootstrap.prepare(at: databaseURL)
    let cache = try AIChunkCacheDatabase(path: databaseURL)

    let firstKey = AIChunkCacheKey(
        normalizedSentence: "運も実力のうちだ",
        provider: "deepseek",
        model: "deepseek-v4-flash",
        promptVersion: "chunk-v1"
    )
    let secondKey = AIChunkCacheKey(
        normalizedSentence: "これが実力だ",
        provider: "deepseek",
        model: "deepseek-v4-flash",
        promptVersion: "chunk-v1"
    )

    try cache.upsertAIChunkCacheEntry(
        key: firstKey,
        chunks: mockChunks(["実力"]),
        cacheDate: "2026-05-26T00:00:00Z"
    )
    try cache.upsertAIChunkCacheEntry(
        key: secondKey,
        chunks: mockChunks(["実力"]),
        cacheDate: "2026-05-27T00:00:00Z"
    )

    #expect(try cache.aiChunkCacheEntry(for: firstKey)?.cacheDate == "2026-05-26T00:00:00Z")
    #expect(try cache.aiChunkCacheEntry(for: secondKey)?.cacheDate == "2026-05-27T00:00:00Z")
}

@Test
func clearsAIChunkCacheEntries() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    try DatabaseBootstrap.prepare(at: databaseURL)
    let cache = try AIChunkCacheDatabase(path: databaseURL)

    let key = AIChunkCacheKey(
        normalizedSentence: "運も実力のうちだ",
        provider: "deepseek",
        model: "deepseek-v4-flash",
        promptVersion: "chunk-v1"
    )

    try cache.upsertAIChunkCacheEntry(
        key: key,
        chunks: mockChunks(["運"])
    )
    try cache.clearAIChunkCacheEntries()

    #expect(try cache.aiChunkCacheEntry(for: key) == nil)
}
