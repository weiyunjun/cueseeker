import Foundation
import SQLite3
import Testing
import CueSeekerCore

private func mockChunks(_ items: [String]) -> [AIChunkItem] {
    items.map { AIChunkItem(item: $0, translation: $0) }
}

private final class SearchProgressCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var snapshots: [SubtitleSearchProgressSnapshot] = []

    func append(_ snapshot: SubtitleSearchProgressSnapshot) {
        lock.lock()
        snapshots.append(snapshot)
        lock.unlock()
    }

    func values() -> [SubtitleSearchProgressSnapshot] {
        lock.lock()
        defer { lock.unlock() }
        return snapshots
    }
}

@Test
func migratesFreshDatabaseToCurrentSchemaVersion() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    #expect(try database.schemaVersion() == SubtitleDatabase.currentSchemaVersion)
}

@Test
func sqliteConnectionsUseBusyTimeoutAndWALMode() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    #expect(try database.busyTimeoutMilliseconds() == SubtitleDatabase.configuredBusyTimeoutMilliseconds)
    #expect(try database.journalMode().lowercased() == "wal")
    #expect(try database.synchronousMode() == 1)
    #expect(try database.cacheSize() == -SubtitleDatabase.configuredCacheSizeKibibytes)
    #expect(try database.mmapSize() == SubtitleDatabase.configuredMmapSizeBytes)
}

@Test
func allCueGroupsVisiblePageReturnsDefaultOrderAndSpeakers() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    let subtitleFile = URL(fileURLWithPath: "/Media/SpeakerTest.srt")
    let videoFile = URL(fileURLWithPath: "/Media/SpeakerTest.mkv")
    try database.replaceEntries(
        subtitleFile: subtitleFile,
        videoFile: videoFile,
        entries: [
            SubtitleEntry(
                sequenceNumber: 1,
                startTimecode: "00:00:01,000",
                endTimecode: "00:00:01,500",
                startMilliseconds: 1_000,
                endMilliseconds: 1_500,
                text: "first cue"
            ),
            SubtitleEntry(
                sequenceNumber: 2,
                startTimecode: "00:00:02,000",
                endTimecode: "00:00:02,500",
                startMilliseconds: 2_000,
                endMilliseconds: 2_500,
                text: "second cue"
            ),
        ]
    )
    let cueLines = try database.cueLineRecords(forSubtitleFile: subtitleFile)
    let secondCueLine = try #require(cueLines.first { $0.line.content == "second cue" })
    try database.replaceCueLineSpeakers(
        forSubtitleFile: subtitleFile,
        assignments: [
            SubtitleCueLineSpeakerAssignment(cueLineID: secondCueLine.id, speakers: ["高松灯"])
        ]
    )

    let page = try database.allCueGroupsVisiblePage(limit: 10, cursor: .start)

    #expect(page.totalCount == 2)
    #expect(page.results.map(\.content) == ["first cue", "second cue"])
    #expect(page.results[0].speakers == [])
    #expect(page.results[1].speakers == ["高松灯"])

    let speakerPage = try database.allCueGroupsVisiblePage(
        limit: 10,
        cursor: .start,
        filterSet: SubtitleSearchFilterSet(
            rules: [
                SubtitleSearchFilterRule(
                    field: .speaker,
                    operatorID: .contains,
                    value: "高松灯"
                )
            ]
        )
    )
    #expect(speakerPage.totalCount == 1)
    #expect(speakerPage.results.map(\.content) == ["second cue"])
}

@Test
func replacesCueLineSpeakersAsStringSets() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    let subtitleFile = URL(fileURLWithPath: "/Media/SpeakerSetTest.srt")
    let videoFile = URL(fileURLWithPath: "/Media/SpeakerSetTest.mkv")
    try database.replaceEntries(
        subtitleFile: subtitleFile,
        videoFile: videoFile,
        entries: [
            SubtitleEntry(
                sequenceNumber: 1,
                startTimecode: "00:00:01,000",
                endTimecode: "00:00:01,500",
                startMilliseconds: 1_000,
                endMilliseconds: 1_500,
                text: "first cue"
            ),
            SubtitleEntry(
                sequenceNumber: 2,
                startTimecode: "00:00:02,000",
                endTimecode: "00:00:02,500",
                startMilliseconds: 2_000,
                endMilliseconds: 2_500,
                text: "second cue"
            ),
        ]
    )

    let cueLines = try database.cueLineRecords(forSubtitleFile: subtitleFile)
    let firstCueLine = try #require(cueLines.first { $0.line.content == "first cue" })
    let secondCueLine = try #require(cueLines.first { $0.line.content == "second cue" })

    try database.replaceCueLineSpeakers(
        forSubtitleFile: subtitleFile,
        assignments: [
            SubtitleCueLineSpeakerAssignment(
                cueLineID: firstCueLine.id,
                speakers: ["高松灯", "疑似长崎素世", "  "]
            ),
            SubtitleCueLineSpeakerAssignment(
                cueLineID: secondCueLine.id,
                speakers: ["千早爱音"]
            )
        ]
    )

    #expect(try database.speakersByCueLineID(forSubtitleFile: subtitleFile) == [
        firstCueLine.id: ["高松灯", "疑似长崎素世"],
        secondCueLine.id: ["千早爱音"]
    ])
    #expect(try database.speakersByCueGroupID(forSubtitleFile: subtitleFile) == [
        firstCueLine.cueGroupID: ["高松灯", "疑似长崎素世"],
        secondCueLine.cueGroupID: ["千早爱音"]
    ])

    try database.replaceCueLineSpeakers(
        forSubtitleFile: subtitleFile,
        assignments: [
            SubtitleCueLineSpeakerAssignment(cueLineID: secondCueLine.id, speakers: ["椎名立希"])
        ]
    )

    #expect(try database.speakersByCueLineID(forSubtitleFile: subtitleFile) == [
        secondCueLine.id: ["椎名立希"]
    ])

    try database.clearCueLineSpeakers(forSubtitleFile: subtitleFile)

    #expect(try database.speakersByCueLineID(forSubtitleFile: subtitleFile).isEmpty)
}

@Test
func reportsStorageStatsAndCompactsFreelistPages() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
        try? FileManager.default.removeItem(atPath: databaseURL.path + "-wal")
        try? FileManager.default.removeItem(atPath: databaseURL.path + "-shm")
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    let subtitleFile = URL(fileURLWithPath: "/Media/Large.srt")
    let videoFile = URL(fileURLWithPath: "/Media/Large.mkv")
    let entries = (0..<5_000).map { index in
        SubtitleEntry(
            sequenceNumber: index + 1,
            startTimecode: "00:00:00,000",
            endTimecode: "00:00:01,000",
            startMilliseconds: index * 1_000,
            endMilliseconds: index * 1_000 + 500,
            text: "Searchable storage compaction line \(index) " + String(repeating: "payload ", count: 12)
        )
    }

    try database.replaceEntries(
        subtitleFile: subtitleFile,
        videoFile: videoFile,
        entries: entries
    )
    try database.clearIndexedContent()

    let statsAfterClear = try database.storageStats()
    #expect(statsAfterClear.pageSize > 0)
    #expect(statsAfterClear.pageCount > 0)
    #expect(statsAfterClear.freelistCount > 0)
    #expect(statsAfterClear.freelistBytes > 0)
    #expect(statsAfterClear.databaseFileBytes > 0)

    try database.compactStorage()

    let statsAfterCompact = try database.storageStats()
    #expect(statsAfterCompact.freelistCount == 0)
    #expect(statsAfterCompact.freelistBytes == 0)
    #expect(statsAfterCompact.databaseFileBytes <= statsAfterClear.databaseFileBytes)
}

@Test
func upsertsSearchPathAndReturnsStableID() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    let folder = URL(fileURLWithPath: "/tmp/CueSeeker/Subtitles")
    let firstID = try database.addSearchPath(folder)
    let secondID = try database.addSearchPath(folder)

    #expect(firstID == secondID)
}

@Test
func storesAndLoadsAIChunkCacheEntry() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    let key = AIChunkCacheKey(
        normalizedSentence: "運も実力のうちだ",
        provider: "deepseek",
        model: "deepseek-v4-flash",
        promptVersion: "chunk-v1"
    )
    let cacheDate = "2026-05-26T00:00:00Z"

    let saved = try database.upsertAIChunkCacheEntry(
        key: key,
        chunks: mockChunks(["運", "実力", "うち"]),
        cacheDate: cacheDate
    )
    let loaded = try database.aiChunkCacheEntry(for: key)

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

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    let key = AIChunkCacheKey(
        normalizedSentence: "春日影はわたくしたちの歌ですのね",
        provider: "deepseek",
        model: "deepseek-v4-flash",
        promptVersion: "chunk-v1"
    )

    try database.upsertAIChunkCacheEntry(
        key: key,
        chunks: mockChunks(["春日影", "わたくしたち", "歌"]),
        cacheDate: "2026-05-26T00:00:00Z"
    )
    let refreshed = try database.upsertAIChunkCacheEntry(
        key: key,
        chunks: mockChunks(["春日影", "わたくしたちの歌"]),
        cacheDate: "2026-05-27T00:00:00Z"
    )
    let loaded = try database.aiChunkCacheEntry(for: key)

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

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

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

    try database.upsertAIChunkCacheEntry(
        key: firstKey,
        chunks: mockChunks(["実力"]),
        cacheDate: "2026-05-26T00:00:00Z"
    )
    try database.upsertAIChunkCacheEntry(
        key: secondKey,
        chunks: mockChunks(["実力"]),
        cacheDate: "2026-05-27T00:00:00Z"
    )

    #expect(try database.aiChunkCacheEntry(for: firstKey)?.cacheDate == "2026-05-26T00:00:00Z")
    #expect(try database.aiChunkCacheEntry(for: secondKey)?.cacheDate == "2026-05-27T00:00:00Z")
}

@Test
func clearsAIChunkCacheEntries() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    let key = AIChunkCacheKey(
        normalizedSentence: "運も実力のうちだ",
        provider: "deepseek",
        model: "deepseek-v4-flash",
        promptVersion: "chunk-v1"
    )

    try database.upsertAIChunkCacheEntry(
        key: key,
        chunks: mockChunks(["運"])
    )
    try database.clearAIChunkCacheEntries()

    #expect(try database.aiChunkCacheEntry(for: key) == nil)
}

@Test
func storesSubtitleEntriesAndSearchesWithFTS5() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    let subtitleFile = URL(fileURLWithPath: "/Media/Movie.srt")
    let videoFile = URL(fileURLWithPath: "/Media/Movie.mkv")
    let entries = [
        SubtitleEntry(
            sequenceNumber: 1,
            startTimecode: "00:00:01,000",
            endTimecode: "00:00:03,000",
            startMilliseconds: 1_000,
            endMilliseconds: 3_000,
            text: "Hello world."
        ),
        SubtitleEntry(
            sequenceNumber: 2,
            startTimecode: "00:00:04,000",
            endTimecode: "00:00:06,000",
            startMilliseconds: 4_000,
            endMilliseconds: 6_000,
            text: "Another subtitle line."
        )
    ]

    try database.replaceEntries(
        subtitleFile: subtitleFile,
        videoFile: videoFile,
        entries: entries
    )

    let storedEntries = try database.entries(forSubtitleFile: subtitleFile)
    #expect(storedEntries.count == 2)
    #expect(storedEntries[0].content == "Hello world.")
    #expect(storedEntries[0].videoName == "Movie.mkv")

    let results = try database.search("world")
    #expect(results.count == 1)
    #expect(results[0].content == "Hello world.")
    #expect(results[0].videoPath == videoFile.path)
    #expect(results[0].startMilliseconds == 1_000)
}

@Test
func subtitleEntryIndexAndWindowLoadCurrentSubtitleRows() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    let subtitleFile = URL(fileURLWithPath: "/Media/WindowedSubtitles.srt")
    let videoFile = URL(fileURLWithPath: "/Media/WindowedSubtitles.mkv")
    let entries = (0..<6).map { index in
        SubtitleEntry(
            sequenceNumber: index + 1,
            startTimecode: String(format: "00:00:%02d,000", index),
            endTimecode: String(format: "00:00:%02d,500", index),
            startMilliseconds: index * 1_000,
            endMilliseconds: index * 1_000 + 500,
            text: "Current subtitle row \(index)"
        )
    }

    try database.replaceEntries(
        subtitleFile: subtitleFile,
        videoFile: videoFile,
        entries: entries
    )

    let index = try database.subtitleEntryIndex(forSubtitleFile: subtitleFile)
    #expect(index.count == 6)
    #expect(index.map(\.startMilliseconds) == [0, 1_000, 2_000, 3_000, 4_000, 5_000])

    let lookup = SubtitleActiveEntryLookup(entryIndex: index)
    #expect(lookup.activeEntryID(atMilliseconds: 2_250) == index[2].id)

    let window = try database.entries(forSubtitleFile: subtitleFile, limit: 2, offset: 3)
    #expect(window.map(\.content) == [
        "Current subtitle row 3",
        "Current subtitle row 4",
    ])
    #expect(try database.entries(forSubtitleFile: subtitleFile, limit: 0, offset: 3).isEmpty)
}

@Test
func persistsSRTLanguageAnalysisWithCueGroupLanguages() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    let subtitleFile = URL(fileURLWithPath: "/Media/Japanese.srt")
    let videoFile = URL(fileURLWithPath: "/Media/Japanese.mkv")
    let entries = [
        SubtitleEntry(
            sequenceNumber: 1,
            startTimecode: "00:00:01,000",
            endTimecode: "00:00:03,000",
            startMilliseconds: 1_000,
            endMilliseconds: 3_000,
            text: "今日はみんなで映画を見に行きます。"
        ),
        SubtitleEntry(
            sequenceNumber: 2,
            startTimecode: "00:00:04,000",
            endTimecode: "00:00:06,000",
            startMilliseconds: 4_000,
            endMilliseconds: 6_000,
            text: "明日は学校のあとで友達と話します。"
        )
    ]
    let cueGroups = entries.enumerated().map { index, entry in
        entry.cueGroup(eventIndex: index)
    }
    let analysis = SubtitleLanguageAnalyzer().analyze(format: .srt, cueGroups: cueGroups)

    try database.replaceEntries(
        subtitleFile: subtitleFile,
        videoFile: videoFile,
        entries: entries,
        languageAnalysis: analysis
    )

    #expect(try database.hasCurrentSubtitleLanguageManifest(forSubtitleFile: subtitleFile))

    let detections = try database.languageDetections(forSubtitleFile: subtitleFile)
    #expect(detections.count == 1)
    #expect(detections[0].scope == .file)
    #expect(detections[0].scopeKey == nil)
    #expect(detections[0].algorithmVersion == SubtitleLanguageRecognizer.algorithmVersion)
    #expect(detections[0].languages == [.japanese])
    #expect(detections[0].confidence >= SubtitleLanguageRecognizer.defaultConfidenceThreshold)

    let storedEntries = try database.entries(forSubtitleFile: subtitleFile)
    let languagesByCueGroupID = try database.cueGroupLanguages(forSubtitleFile: subtitleFile)
    #expect(languagesByCueGroupID[storedEntries[0].id] == [.japanese])
    #expect(languagesByCueGroupID[storedEntries[1].id] == [.japanese])
}

@Test
func persistsASSStyleLanguageAnalysisForUsedStylesOnly() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    let subtitleFile = URL(fileURLWithPath: "/Media/Bilingual.ass")
    let videoFile = URL(fileURLWithPath: "/Media/Bilingual.mkv")
    let contents = """
    [Script Info]
    PlayResX: 1920
    PlayResY: 1080

    [V4+ Styles]
    Format: Name, Alignment, MarginL, MarginR, MarginV
    Style: JP,2,20,20,30
    Style: CN,8,20,20,40
    Style: Unused,2,20,20,30

    [Events]
    Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
    Dialogue: 0,0:00:01.00,0:00:03.00,JP,,0,0,0,,今日はライブの準備をします
    Dialogue: 0,0:00:01.00,0:00:03.00,CN,,0,0,0,,我们今天准备演出，大家一起练习新的歌曲。
    Dialogue: 0,0:00:04.00,0:00:06.00,JP,,0,0,0,,明日はスタジオで練習します
    """
    let cueGroups = ASSParser.parseCueGroups(contents)
    let analysis = SubtitleLanguageAnalyzer().analyze(format: .ass, cueGroups: cueGroups)

    try database.replaceCueGroups(
        subtitleFile: subtitleFile,
        videoFile: videoFile,
        format: .ass,
        cueGroups: cueGroups,
        languageAnalysis: analysis
    )

    #expect(try database.hasCurrentSubtitleLanguageManifest(forSubtitleFile: subtitleFile))

    let detections = try database.languageDetections(forSubtitleFile: subtitleFile)
    #expect(detections.map(\.scopeKey) == ["CN", "JP"])
    #expect(detections.first { $0.scopeKey == "CN" }?.languages == [.simplifiedChinese])
    #expect(detections.first { $0.scopeKey == "JP" }?.languages == [.japanese])

    let storedEntries = try database.entries(forSubtitleFile: subtitleFile)
    let languagesByCueGroupID = try database.cueGroupLanguages(forSubtitleFile: subtitleFile)
    #expect(languagesByCueGroupID[storedEntries[0].id] == [.japanese, .simplifiedChinese])
    #expect(languagesByCueGroupID[storedEntries[1].id] == [.japanese])
}

@Test
func searchLanguageFilterMatchesCueGroupLanguagesOrUnknown() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    let subtitleFile = URL(fileURLWithPath: "/Media/LanguageFilter.srt")
    let videoFile = URL(fileURLWithPath: "/Media/LanguageFilter.mkv")
    let entries = [
        languageFilterTestEntry(sequenceNumber: 1, text: "Shared Japanese cue"),
        languageFilterTestEntry(sequenceNumber: 2, text: "Shared English cue"),
        languageFilterTestEntry(sequenceNumber: 3, text: "Shared Unknown cue"),
        languageFilterTestEntry(sequenceNumber: 4, text: "Shared Generic Chinese cue"),
        languageFilterTestEntry(sequenceNumber: 5, text: "Shared Mixed cue"),
        languageFilterTestEntry(sequenceNumber: 6, text: "Shared Traditional cue")
    ]
    let analysis = SubtitleLanguageAnalysis(
        format: .srt,
        fileDetection: nil,
        styleDetections: [:],
        cueGroupLanguages: [
            [.japanese],
            [.english],
            [.unknown],
            [.chinese],
            [.simplifiedChinese, .japanese],
            [.traditionalChinese]
        ]
    )

    try database.replaceEntries(
        subtitleFile: subtitleFile,
        videoFile: videoFile,
        entries: entries,
        languageAnalysis: analysis
    )

    #expect(try database.search("shared", languageFilter: .all).map(\.content) == [
        "Shared Japanese cue",
        "Shared English cue",
        "Shared Unknown cue",
        "Shared Generic Chinese cue",
        "Shared Mixed cue",
        "Shared Traditional cue"
    ])
    #expect(try database.search("shared", languageFilter: .japanese).map(\.content) == [
        "Shared Japanese cue",
        "Shared Unknown cue",
        "Shared Mixed cue"
    ])
    #expect(try database.search("shared", languageFilter: .english).map(\.content) == [
        "Shared English cue",
        "Shared Unknown cue"
    ])
    #expect(try database.search("shared", languageFilter: .chinese).map(\.content) == [
        "Shared Unknown cue",
        "Shared Generic Chinese cue",
        "Shared Mixed cue",
        "Shared Traditional cue"
    ])
    #expect(try database.search("shared", languageFilter: .simplifiedChinese).map(\.content) == [
        "Shared Unknown cue",
        "Shared Generic Chinese cue",
        "Shared Mixed cue"
    ])
    #expect(try database.search("shared", languageFilter: .traditionalChinese).map(\.content) == [
        "Shared Unknown cue",
        "Shared Generic Chinese cue",
        "Shared Traditional cue"
    ])

    let visiblePage = try database.searchVisiblePage(
        "shared",
        limit: 2,
        cursor: .start,
        languageFilter: .chinese
    )
    #expect(visiblePage.results.map(\.content) == [
        "Shared Unknown cue",
        "Shared Generic Chinese cue"
    ])
    #expect(visiblePage.nextCursor?.offset == 2)
}

@Test
func searchResultsExposeCueGroupLanguages() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    let subtitleFile = URL(fileURLWithPath: "/Media/LanguageResultTags.srt")
    let videoFile = URL(fileURLWithPath: "/Media/LanguageResultTags.mkv")
    let entries = [
        languageFilterTestEntry(sequenceNumber: 1, text: "Shared Japanese cue"),
        languageFilterTestEntry(sequenceNumber: 2, text: "Shared Mixed cue")
    ]
    let analysis = SubtitleLanguageAnalysis(
        format: .srt,
        fileDetection: nil,
        styleDetections: [:],
        cueGroupLanguages: [
            [.japanese],
            [.simplifiedChinese, .japanese]
        ]
    )

    try database.replaceEntries(
        subtitleFile: subtitleFile,
        videoFile: videoFile,
        entries: entries,
        languageAnalysis: analysis
    )

    let exactPage = try database.searchPage("shared", limit: 10)
    #expect(exactPage.results.map(\.displayTitle) == [
        "LanguageResultTags.srt",
        "LanguageResultTags.srt"
    ])
    #expect(exactPage.results.map(\.languages) == [
        [.japanese],
        [.japanese, .simplifiedChinese]
    ])

    let visiblePage = try database.searchVisiblePage("shared", limit: 2, cursor: .start)
    #expect(visiblePage.results.map(\.displayTitle) == [
        "LanguageResultTags.srt",
        "LanguageResultTags.srt"
    ])
    #expect(visiblePage.results.map(\.languages) == [
        [.japanese],
        [.japanese, .simplifiedChinese]
    ])
}

@Test
func searchLanguageFilterAppliesToMatchingLinesBeforeMergedDisplayGroups() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    let subtitleFile = URL(fileURLWithPath: "/Media/BilingualLineFilter.ass")
    let videoFile = URL(fileURLWithPath: "/Media/BilingualLineFilter.mkv")
    let cueGroups = [
        languageFilterASSCueGroup(
            startMilliseconds: 1_000,
            lines: [
                (style: "CN", content: "今天来了"),
                (style: "JP", content: "明日は来ません")
            ]
        ),
        languageFilterASSCueGroup(
            startMilliseconds: 2_000,
            lines: [
                (style: "CN", content: "只是中文上下文"),
                (style: "JP", content: "今日は大丈夫です")
            ]
        ),
        languageFilterASSCueGroup(
            startMilliseconds: 3_000,
            lines: [
                (style: nil, content: "今天没有样式"),
                (style: "JP", content: "明日も大丈夫です")
            ]
        )
    ]
    let analysis = SubtitleLanguageAnalysis(
        format: .ass,
        fileDetection: nil,
        styleDetections: [
            "CN": SubtitleLanguageDetectionResult(
                languages: [.simplifiedChinese],
                confidence: 1,
                segmentCount: 2,
                effectiveCharacterCount: 16,
                distribution: [SubtitleLanguageDistribution(language: .simplifiedChinese, share: 1)]
            ),
            "JP": SubtitleLanguageDetectionResult(
                languages: [.japanese],
                confidence: 1,
                segmentCount: 3,
                effectiveCharacterCount: 24,
                distribution: [SubtitleLanguageDistribution(language: .japanese, share: 1)]
            )
        ],
        cueGroupLanguages: [
            [.simplifiedChinese, .japanese],
            [.simplifiedChinese, .japanese],
            [.japanese]
        ]
    )

    try database.replaceCueGroups(
        subtitleFile: subtitleFile,
        videoFile: videoFile,
        format: .ass,
        cueGroups: cueGroups,
        languageAnalysis: analysis
    )

    #expect(try database.search("今天", languageFilter: .all).map(\.startMilliseconds) == [
        1_000,
        3_000
    ])
    #expect(try database.search("今天", languageFilter: .japanese).map(\.startMilliseconds) == [
        3_000
    ])
    #expect(try database.search("今天", languageFilter: .chinese).map(\.startMilliseconds) == [
        1_000,
        3_000
    ])

    let japaneseResults = try database.search("今日", languageFilter: .japanese)
    #expect(japaneseResults.map(\.startMilliseconds) == [2_000])
    #expect(japaneseResults.first?.cueLines == [
        "只是中文上下文",
        "今日は大丈夫です"
    ])
    #expect(try database.search("今日", languageFilter: .chinese).isEmpty)

    let visiblePage = try database.searchVisiblePage(
        "今天",
        limit: 1,
        cursor: .start,
        languageFilter: .japanese
    )
    #expect(visiblePage.results.map(\.startMilliseconds) == [3_000])
    #expect(visiblePage.nextCursor == nil)
}

@Test
func searchLanguageFilterTreatsMissingLanguageRowsAsUnknown() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    let subtitleFile = URL(fileURLWithPath: "/Media/LegacyLanguage.srt")
    let videoFile = URL(fileURLWithPath: "/Media/LegacyLanguage.mkv")
    try database.replaceEntries(
        subtitleFile: subtitleFile,
        videoFile: videoFile,
        entries: [
            languageFilterTestEntry(sequenceNumber: 1, text: "Legacy shared row")
        ]
    )

    #expect(try database.search("legacy", languageFilter: .japanese).map(\.content) == [
        "Legacy shared row"
    ])
}

@Test
func searchPaginatesBeyondDefaultResultLimit() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    let subtitleFile = URL(fileURLWithPath: "/Media/Series.srt")
    let videoFile = URL(fileURLWithPath: "/Media/Series.mkv")
    let entries = (0..<55).map { index in
        SubtitleEntry(
            sequenceNumber: index + 1,
            startTimecode: "00:00:\(String(format: "%02d", index)),000",
            endTimecode: "00:00:\(String(format: "%02d", index)),500",
            startMilliseconds: index * 1_000,
            endMilliseconds: index * 1_000 + 500,
            text: "Shared searchable line \(index)"
        )
    }

    try database.replaceEntries(
        subtitleFile: subtitleFile,
        videoFile: videoFile,
        entries: entries
    )

    let firstPage = try database.search("shared", limit: 50)
    let secondPage = try database.search("shared", limit: 50, offset: 50)

    #expect(firstPage.count == 50)
    #expect(secondPage.count == 5)
    #expect(firstPage[0].content == "Shared searchable line 0")
    #expect(firstPage[49].content == "Shared searchable line 49")
    #expect(secondPage[0].content == "Shared searchable line 50")
    #expect(secondPage[4].content == "Shared searchable line 54")
}

@Test
func searchPageReturnsContinuationCursorForNextPage() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    let subtitleFile = URL(fileURLWithPath: "/Media/Series.srt")
    let videoFile = URL(fileURLWithPath: "/Media/Series.mkv")
    let entries = (0..<5).map { index in
        SubtitleEntry(
            sequenceNumber: index + 1,
            startTimecode: "00:00:0\(index),000",
            endTimecode: "00:00:0\(index),500",
            startMilliseconds: index * 1_000,
            endMilliseconds: index * 1_000 + 500,
            text: "Shared cursor line \(index)"
        )
    }

    try database.replaceEntries(
        subtitleFile: subtitleFile,
        videoFile: videoFile,
        entries: entries
    )

    let firstPage = try database.searchPage("shared", limit: 2)
    let secondPage = try database.searchPage("shared", limit: 2, cursor: firstPage.nextCursor)
    let thirdPage = try database.searchPage("shared", limit: 2, cursor: secondPage.nextCursor)

    #expect(firstPage.appliedCursor.offset == 0)
    #expect(firstPage.nextCursor?.offset == 2)
    #expect(secondPage.appliedCursor.offset == 2)
    #expect(secondPage.nextCursor?.offset == 4)
    #expect(thirdPage.appliedCursor.offset == 4)
    #expect(thirdPage.nextCursor == nil)
    #expect((firstPage.results + secondPage.results + thirdPage.results).map(\.content) == [
        "Shared cursor line 0",
        "Shared cursor line 1",
        "Shared cursor line 2",
        "Shared cursor line 3",
        "Shared cursor line 4"
    ])
}

@Test
func searchVisiblePageReturnsExactProgressBeforeCompleteMetadata() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    let subtitleFile = URL(fileURLWithPath: "/Media/Series.srt")
    let videoFile = URL(fileURLWithPath: "/Media/Series.mkv")
    let entries = (0..<5).map { index in
        SubtitleEntry(
            sequenceNumber: index + 1,
            startTimecode: "00:00:0\(index),000",
            endTimecode: "00:00:0\(index),500",
            startMilliseconds: index * 1_000,
            endMilliseconds: index * 1_000 + 500,
            text: "Shared visible line \(index)"
        )
    }

    try database.replaceEntries(
        subtitleFile: subtitleFile,
        videoFile: videoFile,
        entries: entries
    )

    let firstPage = try database.searchVisiblePage("shared", limit: 2, cursor: .start)
    let secondPage = try database.searchVisiblePage("shared", limit: 3, cursor: firstPage.nextCursor)

    #expect(firstPage.pageMode == .visibleWindow)
    #expect(firstPage.countState == .exactProgress)
    #expect(firstPage.totalCount == 2)
    #expect(firstPage.knownResultCount == 2)
    #expect(firstPage.exactTotalCount == nil)
    #expect(firstPage.fileSummaries.map(\.matchCount) == [2])
    #expect(firstPage.nextCursor?.offset == 2)
    #expect(firstPage.results.map(\.content) == [
        "Shared visible line 0",
        "Shared visible line 1"
    ])

    #expect(secondPage.countState == .exact)
    #expect(secondPage.totalCount == 5)
    #expect(secondPage.exactTotalCount == 5)
    #expect(secondPage.fileSummaries.map(\.matchCount) == [5])
    #expect(secondPage.nextCursor == nil)
    #expect(secondPage.results.map(\.content) == [
        "Shared visible line 2",
        "Shared visible line 3",
        "Shared visible line 4"
    ])
}

@Test
func searchFilterSetMatchesDisplayTitleInDatabaseResults() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    try database.replaceEntries(
        subtitleFile: URL(fileURLWithPath: "/Media/Alpha.srt"),
        videoFile: URL(fileURLWithPath: "/Media/Alpha.mkv"),
        entries: [
            languageFilterTestEntry(sequenceNumber: 1, text: "Shared display alpha")
        ]
    )
    try database.replaceEntries(
        subtitleFile: URL(fileURLWithPath: "/Media/Beta.srt"),
        videoFile: URL(fileURLWithPath: "/Media/Beta.mkv"),
        entries: [
            languageFilterTestEntry(sequenceNumber: 1, text: "Shared display beta")
        ]
    )

    let filterSet = SubtitleSearchFilterSet(rules: [
        SubtitleSearchFilterRule(
            field: .display,
            operatorID: .contains,
            value: "Beta"
        )
    ])
    let page = try database.searchPage("shared", limit: 10, filterSet: filterSet)

    #expect(page.totalCount == 1)
    #expect(page.fileSummaries.map(\.subtitleDisplayTitle) == ["Beta.srt"])
    #expect(page.results.map(\.content) == ["Shared display beta"])
}

@Test
func searchFilterSetAppliesToExactPagesAndIndexedWindows() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    let subtitleFile = URL(fileURLWithPath: "/Media/FilteredWindow.srt")
    let videoFile = URL(fileURLWithPath: "/Media/FilteredWindow.mkv")
    let entries = (0..<6).map { index in
        SubtitleEntry(
            sequenceNumber: index + 1,
            startTimecode: String(format: "00:00:%02d,000", index),
            endTimecode: String(format: "00:00:%02d,500", index),
            startMilliseconds: index * 1_000,
            endMilliseconds: index * 1_000 + 500,
            text: index.isMultiple(of: 2)
                ? "Shared filtered keep \(index)"
                : "Shared filtered drop \(index)"
        )
    }

    try database.replaceEntries(
        subtitleFile: subtitleFile,
        videoFile: videoFile,
        entries: entries
    )

    let filterSet = SubtitleSearchFilterSet(rules: [
        SubtitleSearchFilterRule(
            field: .cues,
            operatorID: .contains,
            value: "keep"
        )
    ])

    let exactPage = try database.searchPage("shared", limit: 2, filterSet: filterSet)
    #expect(exactPage.totalCount == 3)
    #expect(exactPage.nextCursor?.offset == 2)
    #expect(exactPage.results.map(\.content) == [
        "Shared filtered keep 0",
        "Shared filtered keep 2"
    ])

    #expect(database.searchResultIDIndexWindow(
        "shared",
        limit: 1,
        cursor: .start,
        minimumKnownResultCount: 4
    ) == nil)

    let window = try #require(database.searchResultIDIndexWindow(
        "shared",
        limit: 1,
        cursor: SubtitleSearchCursor(offset: 2),
        filterSet: filterSet,
        minimumKnownResultCount: 3
    ))
    let indexedPage = try #require(try database.searchIndexedVisiblePage(from: window))

    #expect(indexedPage.totalCount == 3)
    #expect(indexedPage.nextCursor == nil)
    #expect(indexedPage.results.map(\.content) == ["Shared filtered keep 4"])
    #expect(indexedPage.results.map(\.searchRank) == [2])
}

@Test
func searchFilterSetMatchesLanguageCollectionValues() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    let subtitleFile = URL(fileURLWithPath: "/Media/FilterLanguages.srt")
    let videoFile = URL(fileURLWithPath: "/Media/FilterLanguages.mkv")
    let entries = [
        languageFilterTestEntry(sequenceNumber: 1, text: "Shared Japanese filter"),
        languageFilterTestEntry(sequenceNumber: 2, text: "Shared English filter"),
        languageFilterTestEntry(sequenceNumber: 3, text: "Shared Mixed filter")
    ]
    let analysis = SubtitleLanguageAnalysis(
        format: .srt,
        fileDetection: nil,
        styleDetections: [:],
        cueGroupLanguages: [
            [.japanese],
            [.english],
            [.simplifiedChinese, .japanese]
        ]
    )

    try database.replaceEntries(
        subtitleFile: subtitleFile,
        videoFile: videoFile,
        entries: entries,
        languageAnalysis: analysis
    )

    let filterSet = SubtitleSearchFilterSet(rules: [
        SubtitleSearchFilterRule(
            field: .language,
            operatorID: .contains,
            value: "ja"
        )
    ])
    let page = try database.searchPage("shared", limit: 10, filterSet: filterSet)

    #expect(page.totalCount == 2)
    #expect(page.results.map(\.content) == [
        "Shared Japanese filter",
        "Shared Mixed filter"
    ])
}

@Test
func searchExactPageCachesResultIDIndexForVisibleWindows() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    let subtitleFile = URL(fileURLWithPath: "/Media/IndexedWindow.srt")
    let videoFile = URL(fileURLWithPath: "/Media/IndexedWindow.mkv")
    let entries = (0..<8).map { index in
        SubtitleEntry(
            sequenceNumber: index + 1,
            startTimecode: String(format: "00:00:%02d,000", index),
            endTimecode: String(format: "00:00:%02d,500", index),
            startMilliseconds: index * 1_000,
            endMilliseconds: index * 1_000 + 500,
            text: "Shared indexed window \(index)"
        )
    }

    try database.replaceEntries(
        subtitleFile: subtitleFile,
        videoFile: videoFile,
        entries: entries
    )

    #expect(database.searchResultIDIndexWindow(
        "shared",
        limit: 2,
        cursor: SubtitleSearchCursor(offset: 4),
        minimumKnownResultCount: 6
    ) == nil)

    let exactPage = try database.searchPage("shared", limit: 2)
    #expect(exactPage.totalCount == 8)

    let window = try #require(database.searchResultIDIndexWindow(
        "shared",
        limit: 2,
        cursor: SubtitleSearchCursor(offset: 4),
        minimumKnownResultCount: 6
    ))
    let indexedPage = try #require(try database.searchIndexedVisiblePage(from: window))

    #expect(indexedPage.pageMode == .visibleWindow)
    #expect(indexedPage.countState == .exact)
    #expect(indexedPage.totalCount == 8)
    #expect(indexedPage.nextCursor?.offset == 6)
    #expect(indexedPage.orderSource == "resultIDIndex")
    #expect(indexedPage.materializedOrderRows == 2)
    #expect(indexedPage.results.map(\.content) == [
        "Shared indexed window 4",
        "Shared indexed window 5",
    ])
    #expect(indexedPage.results.map(\.searchRank) == [4, 5])
}

@Test
func searchNavigationSnapshotUsesCachedResultIDIndexWindow() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    let subtitleFile = URL(fileURLWithPath: "/Media/IndexedNavigation.srt")
    let videoFile = URL(fileURLWithPath: "/Media/IndexedNavigation.mkv")
    let entries = (0..<8).map { index in
        SubtitleEntry(
            sequenceNumber: index + 1,
            startTimecode: String(format: "00:00:%02d,000", index),
            endTimecode: String(format: "00:00:%02d,500", index),
            startMilliseconds: index * 1_000,
            endMilliseconds: index * 1_000 + 500,
            text: "Shared indexed navigation \(index)"
        )
    }

    try database.replaceEntries(
        subtitleFile: subtitleFile,
        videoFile: videoFile,
        entries: entries
    )

    let missingSnapshot = try database.searchNavigationSnapshotFromResultIDIndex(
        "shared",
        anchor: SearchNavigationAnchor(
            selectedEntryID: 4,
            selectedSearchRank: 3,
            videoPath: videoFile.path,
            subtitlePath: subtitleFile.path,
            currentMilliseconds: 3_000
        ),
        radius: 1
    )
    #expect(missingSnapshot == nil)

    _ = try database.searchPage("shared", limit: 2)
    let window = try #require(database.searchResultIDIndexWindow(
        "shared",
        limit: 1,
        cursor: SubtitleSearchCursor(offset: 4)
    ))
    let indexedPage = try #require(try database.searchIndexedVisiblePage(from: window))
    let selected = try #require(indexedPage.results.first)

    let snapshot = try #require(try database.searchNavigationSnapshotFromResultIDIndex(
        "shared",
        anchor: SearchNavigationAnchor(
            selectedEntryID: selected.entryID,
            selectedSearchRank: selected.searchRank,
            videoPath: selected.videoPath,
            subtitlePath: selected.subtitlePath,
            currentMilliseconds: selected.startMilliseconds
        ),
        radius: 1
    ))

    #expect(snapshot.totalCount == 8)
    #expect(snapshot.currentIndex == 4)
    #expect(snapshot.previous?.content == "Shared indexed navigation 3")
    #expect(snapshot.current?.content == "Shared indexed navigation 4")
    #expect(snapshot.next?.content == "Shared indexed navigation 5")
    #expect(snapshot.neighborhood.map(\.searchRank) == [3, 4, 5])

    let earlierWindow = try #require(database.searchResultIDIndexWindow(
        "shared",
        limit: 1,
        cursor: SubtitleSearchCursor(offset: 1)
    ))
    let earlierPage = try #require(try database.searchIndexedVisiblePage(from: earlierWindow))
    let earlierSelected = try #require(earlierPage.results.first)

    let timeAnchoredSnapshot = try #require(try database.searchNavigationSnapshotFromResultIDIndex(
        "shared",
        anchor: SearchNavigationAnchor(
            selectedEntryID: earlierSelected.entryID,
            selectedSearchRank: earlierSelected.searchRank,
            videoPath: earlierSelected.videoPath,
            subtitlePath: earlierSelected.subtitlePath,
            currentMilliseconds: 4_100
        ),
        radius: 1
    ))

    #expect(timeAnchoredSnapshot.currentIndex == 4)
    #expect(timeAnchoredSnapshot.previous?.content == "Shared indexed navigation 3")
    #expect(timeAnchoredSnapshot.current?.content == "Shared indexed navigation 4")
    #expect(timeAnchoredSnapshot.next?.content == "Shared indexed navigation 5")
}

@Test
func searchPageEmitsExactProgressCountSnapshotsBeforeFinalExactCounts() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    let subtitleFile = URL(fileURLWithPath: "/Media/Progress.srt")
    let videoFile = URL(fileURLWithPath: "/Media/Progress.mkv")
    let entries = (0..<5_100).map { index in
        SubtitleEntry(
            sequenceNumber: index + 1,
            startTimecode: String(format: "00:00:%02d,000", index % 60),
            endTimecode: String(format: "00:00:%02d,500", index % 60),
            startMilliseconds: index * 1_000,
            endMilliseconds: index * 1_000 + 500,
            text: "Progress count stream line \(index)"
        )
    }

    try database.replaceEntries(
        subtitleFile: subtitleFile,
        videoFile: videoFile,
        entries: entries
    )

    let collector = SearchProgressCollector()
    let page = try database.searchPage(
        "progress",
        limit: 50,
        cursor: .start,
        progress: { snapshot in
            collector.append(snapshot)
        }
    )
    let progress = collector.values()

    #expect(!progress.isEmpty)
    #expect(progress.allSatisfy { $0.countState == .exactProgress })
    #expect(progress.map(\.knownResultCount) == progress.map(\.knownResultCount).sorted())
    #expect(progress.last?.knownResultCount == 5_000)
    #expect(progress.last?.knownFileCount == 1)
    #expect(progress.last?.fileSummaries.map(\.matchCount) == [5_000])
    #expect(page.countState == .exact)
    #expect(page.totalCount == 5_100)
    #expect(page.knownResultCount == 5_100)
    #expect(page.fileSummaries.map(\.matchCount) == [5_100])
}

@Test
func searchPageUsesResultCacheForRepeatedQueries() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    let subtitleFile = URL(fileURLWithPath: "/Media/Cache.srt")
    let videoFile = URL(fileURLWithPath: "/Media/Cache.mkv")
    try database.replaceEntries(
        subtitleFile: subtitleFile,
        videoFile: videoFile,
        entries: [
            databaseTestEntry(text: "Cache query first"),
            databaseTestEntry(text: "Cache query second")
        ]
    )

    let firstDiagnostics = SearchDiagnosticRecorder()
    let firstPage = try database.searchPage("cache", limit: 10, diagnostics: firstDiagnostics.record)
    let secondDiagnostics = SearchDiagnosticRecorder()
    let secondPage = try database.searchPage("cache", limit: 10, diagnostics: secondDiagnostics.record)
    let stats = database.searchResultCacheStats()

    #expect(firstPage == secondPage)
    #expect(firstDiagnostics.events.contains { $0.name == "search_cache_miss" })
    #expect(firstDiagnostics.events.contains { $0.name == "search_cache_store" })
    #expect(secondDiagnostics.events.contains { $0.name == "search_cache_hit" })
    #expect(!secondDiagnostics.events.contains { $0.name == "fts_batch" })
    #expect(stats.entries == 1)
    #expect(stats.hits == 1)
    #expect(stats.misses == 1)
    #expect(stats.stores == 1)
}

@Test
func searchResultCacheInvalidatesWhenIndexedContentChanges() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    let subtitleFile = URL(fileURLWithPath: "/Media/CacheInvalidation.srt")
    let videoFile = URL(fileURLWithPath: "/Media/CacheInvalidation.mkv")
    try database.replaceEntries(
        subtitleFile: subtitleFile,
        videoFile: videoFile,
        entries: [
            databaseTestEntry(text: "Cache invalidation first")
        ]
    )

    _ = try database.searchPage("cache", limit: 10)
    _ = try database.searchPage("cache", limit: 10)
    #expect(database.searchResultCacheStats().hits == 1)

    try database.replaceEntries(
        subtitleFile: subtitleFile,
        videoFile: videoFile,
        entries: [
            databaseTestEntry(text: "Cache invalidation first"),
            databaseTestEntry(text: "Cache invalidation second")
        ]
    )

    let diagnostics = SearchDiagnosticRecorder()
    let page = try database.searchPage("cache", limit: 10, diagnostics: diagnostics.record)
    let stats = database.searchResultCacheStats()

    #expect(page.totalCount == 2)
    #expect(page.results.map(\.content) == [
        "Cache invalidation first",
        "Cache invalidation second"
    ])
    #expect(diagnostics.events.contains { $0.name == "search_cache_miss" })
    #expect(stats.invalidations >= 1)
    #expect(stats.misses == 2)
    #expect(stats.stores == 2)
}

@Test
func searchVisiblePageUsesProductOrderedFTSRowIDsForEarlyTermination() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    let betaSubtitle = URL(fileURLWithPath: "/Media/AFolder/Beta.srt")
    let betaVideo = URL(fileURLWithPath: "/Media/AFolder/Beta.mkv")
    let alphaSubtitle = URL(fileURLWithPath: "/Media/ZFolder/Alpha.srt")
    let alphaVideo = URL(fileURLWithPath: "/Media/ZFolder/Alpha.mkv")

    try database.replaceEntries(
        subtitleFile: betaSubtitle,
        videoFile: betaVideo,
        entries: [
            SubtitleEntry(
                sequenceNumber: 1,
                startTimecode: "00:00:01,000",
                endTimecode: "00:00:02,000",
                startMilliseconds: 1_000,
                endMilliseconds: 2_000,
                text: "Shared product-order beta"
            )
        ]
    )
    try database.replaceEntries(
        subtitleFile: alphaSubtitle,
        videoFile: alphaVideo,
        entries: [
            SubtitleEntry(
                sequenceNumber: 1,
                startTimecode: "00:00:01,000",
                endTimecode: "00:00:02,000",
                startMilliseconds: 1_000,
                endMilliseconds: 2_000,
                text: "Shared product-order alpha"
            )
        ]
    )

    let firstVisiblePage = try database.searchVisiblePage("shared product", limit: 1, cursor: .start)

    #expect(firstVisiblePage.results.map(\.subtitlePath) == [alphaSubtitle.path])
    #expect(firstVisiblePage.results.map(\.content) == ["Shared product-order alpha"])
    #expect(firstVisiblePage.countState == .exactProgress)
    #expect(firstVisiblePage.nextCursor?.offset == 1)
    #expect(firstVisiblePage.orderSource == "ftsRowid")
}

@Test
func searchPageReturnsTotalCountsAndFileSummaries() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    let alphaSubtitle = URL(fileURLWithPath: "/Media/ZFolder/Alpha.srt")
    let alphaVideo = URL(fileURLWithPath: "/Media/ZFolder/Alpha.mkv")
    let betaSubtitle = URL(fileURLWithPath: "/Media/AFolder/Beta.srt")
    let betaVideo = URL(fileURLWithPath: "/Media/AFolder/Beta.mkv")

    try database.replaceEntries(
        subtitleFile: alphaSubtitle,
        videoFile: alphaVideo,
        entries: [
            SubtitleEntry(
                sequenceNumber: 1,
                startTimecode: "00:00:05,000",
                endTimecode: "00:00:06,000",
                startMilliseconds: 5_000,
                endMilliseconds: 6_000,
                text: "Shared later alpha"
            ),
            SubtitleEntry(
                sequenceNumber: 2,
                startTimecode: "00:00:01,000",
                endTimecode: "00:00:02,000",
                startMilliseconds: 1_000,
                endMilliseconds: 2_000,
                text: "Shared earlier alpha"
            )
        ]
    )
    try database.replaceEntries(
        subtitleFile: betaSubtitle,
        videoFile: betaVideo,
        entries: [
            SubtitleEntry(
                sequenceNumber: 1,
                startTimecode: "00:00:03,000",
                endTimecode: "00:00:04,000",
                startMilliseconds: 3_000,
                endMilliseconds: 4_000,
                text: "Shared beta"
            )
        ]
    )

    let page = try database.searchPage("shared", limit: 2)

    #expect(page.totalCount == 3)
    #expect(page.countState == .exact)
    #expect(page.knownResultCount == 3)
    #expect(page.knownFileCount == 2)
    #expect(page.exactTotalCount == 3)
    #expect(page.exactFileSummaryCount == 2)
    #expect(page.fileSummaries.map(\.subtitleFileName) == ["Alpha.srt", "Beta.srt"])
    #expect(page.fileSummaries.map(\.matchCount) == [2, 1])
    #expect(page.results.map(\.content) == ["Shared earlier alpha", "Shared later alpha"])
}

@Test
func cueGroupOccurrenceCountMatchesSearchPageExactTotals() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    let mediaFolder = URL(fileURLWithPath: "/Media")
    let mediaSubtitle = mediaFolder.appendingPathComponent("Exam.srt")
    let mediaVideo = mediaFolder.appendingPathComponent("Exam.mkv")
    let archiveFolder = URL(fileURLWithPath: "/Archive")
    let archiveSubtitle = archiveFolder.appendingPathComponent("Exam.srt")
    let archiveVideo = archiveFolder.appendingPathComponent("Exam.mkv")

    try database.replaceEntries(
        subtitleFile: mediaSubtitle,
        videoFile: mediaVideo,
        entries: [
            databaseTestEntry(text: "一級試験は例年通りなら"),
            databaseTestEntry(text: "一級魔法使い")
        ]
    )
    try database.replaceEntries(
        subtitleFile: archiveSubtitle,
        videoFile: archiveVideo,
        entries: [
            databaseTestEntry(text: "一級試験"),
            databaseTestEntry(text: "magic circle")
        ]
    )

    let allCJKPage = try database.searchPage("一級", limit: 10)
    #expect(try database.cueGroupOccurrenceCount(for: " 一級 ") == allCJKPage.totalCount)
    #expect(allCJKPage.totalCount == 3)

    let scopedCJKPage = try database.searchPage("一級", limit: 10, under: [mediaFolder])
    #expect(try database.cueGroupOccurrenceCount(for: "一級", under: [mediaFolder]) == scopedCJKPage.totalCount)
    #expect(scopedCJKPage.totalCount == 2)

    let phrasePage = try database.searchPage("一級試験", limit: 10)
    #expect(try database.cueGroupOccurrenceCount(for: "一級試験") == phrasePage.totalCount)
    #expect(phrasePage.totalCount == 2)

    let latinPage = try database.searchPage("mag", limit: 10)
    #expect(try database.cueGroupOccurrenceCount(for: "mag") == latinPage.totalCount)
    #expect(latinPage.totalCount == 1)
}

@Test
func searchPageExposesExactCountsWhenRowsContinue() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    let alphaSubtitle = URL(fileURLWithPath: "/Media/Alpha/Episode.srt")
    let alphaVideo = URL(fileURLWithPath: "/Media/Alpha/Episode.mkv")
    let betaSubtitle = URL(fileURLWithPath: "/Media/Beta/Episode.srt")
    let betaVideo = URL(fileURLWithPath: "/Media/Beta/Episode.mkv")

    try database.replaceEntries(
        subtitleFile: alphaSubtitle,
        videoFile: alphaVideo,
        entries: [
            SubtitleEntry(
                sequenceNumber: 1,
                startTimecode: "00:00:01,000",
                endTimecode: "00:00:01,500",
                startMilliseconds: 1_000,
                endMilliseconds: 1_500,
                text: "Shared alpha one"
            ),
            SubtitleEntry(
                sequenceNumber: 2,
                startTimecode: "00:00:02,000",
                endTimecode: "00:00:02,500",
                startMilliseconds: 2_000,
                endMilliseconds: 2_500,
                text: "Shared alpha two"
            )
        ]
    )
    try database.replaceEntries(
        subtitleFile: betaSubtitle,
        videoFile: betaVideo,
        entries: [
            SubtitleEntry(
                sequenceNumber: 1,
                startTimecode: "00:00:03,000",
                endTimecode: "00:00:03,500",
                startMilliseconds: 3_000,
                endMilliseconds: 3_500,
                text: "Shared beta one"
            )
        ]
    )

    let page = try database.searchPage("shared", limit: 2)

    #expect(page.results.map(\.content) == ["Shared alpha one", "Shared alpha two"])
    #expect(page.countState == .exact)
    #expect(page.knownResultCount == 3)
    #expect(page.knownFileCount == 2)
    #expect(page.exactTotalCount == 3)
    #expect(page.exactFileSummaryCount == 2)
    #expect(page.totalCount == 3)
    #expect(page.fileSummaries.map(\.matchCount) == [2, 1])
    #expect(page.nextCursor?.offset == 2)
}

@Test
func searchPageExposesExactCountsWhenAllRowsFitInPage() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    let subtitle = URL(fileURLWithPath: "/Media/Alpha/Episode.srt")
    let video = URL(fileURLWithPath: "/Media/Alpha/Episode.mkv")
    try database.replaceEntries(
        subtitleFile: subtitle,
        videoFile: video,
        entries: [
            SubtitleEntry(
                sequenceNumber: 1,
                startTimecode: "00:00:01,000",
                endTimecode: "00:00:01,500",
                startMilliseconds: 1_000,
                endMilliseconds: 1_500,
                text: "Shared alpha one"
            )
        ]
    )

    let page = try database.searchPage("shared", limit: 10)

    #expect(page.countState == .exact)
    #expect(page.knownResultCount == 1)
    #expect(page.knownFileCount == 1)
    #expect(page.exactTotalCount == 1)
    #expect(page.exactFileSummaryCount == 1)
    #expect(page.nextCursor == nil)
}

@Test
func ftsVocabularyDiagnosticsReportsTopAndQueryTerms() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    let alphaSubtitle = URL(fileURLWithPath: "/Media/Alpha/Episode.srt")
    let alphaVideo = URL(fileURLWithPath: "/Media/Alpha/Episode.mkv")
    let betaSubtitle = URL(fileURLWithPath: "/Media/Beta/Episode.srt")
    let betaVideo = URL(fileURLWithPath: "/Media/Beta/Episode.mkv")

    try database.replaceEntries(
        subtitleFile: alphaSubtitle,
        videoFile: alphaVideo,
        entries: [
            SubtitleEntry(
                sequenceNumber: 1,
                startTimecode: "00:00:01,000",
                endTimecode: "00:00:01,500",
                startMilliseconds: 1_000,
                endMilliseconds: 1_500,
                text: "Shared alpha alpha alpha"
            )
        ]
    )
    try database.replaceEntries(
        subtitleFile: betaSubtitle,
        videoFile: betaVideo,
        entries: [
            SubtitleEntry(
                sequenceNumber: 1,
                startTimecode: "00:00:02,000",
                endTimecode: "00:00:02,500",
                startMilliseconds: 2_000,
                endMilliseconds: 2_500,
                text: "Shared beta"
            )
        ]
    )

    let diagnostics = try database.ftsVocabularyDiagnostics(for: "shared alpha", topTermLimit: 2)

    #expect(diagnostics.uniqueTermCount >= 3)
    #expect(diagnostics.totalOccurrences >= 6)
    #expect(diagnostics.totalDocumentReferences >= 4)
    #expect(diagnostics.mostFrequentTerms.count == 2)
    #expect(diagnostics.mostFrequentTerms.first?.term == "alpha")
    #expect(diagnostics.mostFrequentTerms.first?.documentCount == 1)
    #expect(diagnostics.mostFrequentTerms.first?.occurrenceCount == 3)
    #expect(diagnostics.queryTerms.map(\.term) == ["shared", "alpha"])
    #expect(diagnostics.queryTerms.map(\.documentCount) == [2, 1])
    #expect(diagnostics.queryTerms.map(\.occurrenceCount) == [2, 3])
}

@Test
func searchNavigationUsesCompleteResultOrderAndPlaybackTimeAnchor() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    let alphaSubtitle = URL(fileURLWithPath: "/Media/Alpha/Episode.srt")
    let alphaVideo = URL(fileURLWithPath: "/Media/Alpha/Episode.mkv")
    let betaSubtitle = URL(fileURLWithPath: "/Media/Beta/Episode.srt")
    let betaVideo = URL(fileURLWithPath: "/Media/Beta/Episode.mkv")

    try database.replaceEntries(
        subtitleFile: alphaSubtitle,
        videoFile: alphaVideo,
        entries: [
            SubtitleEntry(
                sequenceNumber: 1,
                startTimecode: "00:00:01,000",
                endTimecode: "00:00:02,000",
                startMilliseconds: 1_000,
                endMilliseconds: 2_000,
                text: "Shared alpha first"
            ),
            SubtitleEntry(
                sequenceNumber: 2,
                startTimecode: "00:00:03,000",
                endTimecode: "00:00:04,000",
                startMilliseconds: 3_000,
                endMilliseconds: 4_000,
                text: "Shared alpha second"
            )
        ]
    )
    try database.replaceEntries(
        subtitleFile: betaSubtitle,
        videoFile: betaVideo,
        entries: [
            SubtitleEntry(
                sequenceNumber: 1,
                startTimecode: "00:00:05,000",
                endTimecode: "00:00:06,000",
                startMilliseconds: 5_000,
                endMilliseconds: 6_000,
                text: "Shared beta only"
            )
        ]
    )

    let page = try database.searchPage("shared", limit: 10, under: [URL(fileURLWithPath: "/Media")])
    #expect(page.results.map(\.content) == [
        "Shared alpha first",
        "Shared alpha second",
        "Shared beta only"
    ])

    let snapshot = try database.searchNavigationSnapshot(
        "shared",
        under: [URL(fileURLWithPath: "/Media")],
        anchor: SearchNavigationAnchor(
            selectedEntryID: page.results[0].entryID,
            videoPath: alphaVideo.path,
            subtitlePath: alphaSubtitle.path,
            currentMilliseconds: 3_500
        ),
        radius: 1
    )

    #expect(snapshot.totalCount == 3)
    #expect(snapshot.currentPosition == 2)
    #expect(snapshot.previous?.content == "Shared alpha first")
    #expect(snapshot.current?.content == "Shared alpha second")
    #expect(snapshot.next?.content == "Shared beta only")
    #expect(snapshot.neighborhood.map(\.content) == [
        "Shared alpha first",
        "Shared alpha second",
        "Shared beta only"
    ])
}

@Test
func libraryVideosDeduplicateSortNaturallyAndExposeDuration() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    let show2Episode2Video = URL(fileURLWithPath: "/Media/Show 2/Episode 2.mkv")
    let show2Episode11Video = URL(fileURLWithPath: "/Media/Show 2/Episode 11.mkv")
    let show11Episode1Video = URL(fileURLWithPath: "/Media/Show 11/Episode 1.mkv")

    try database.replaceEntries(
        subtitleFile: URL(fileURLWithPath: "/Media/Show 2/Episode 2.en.srt"),
        videoFile: show2Episode2Video,
        entries: [databaseTestEntry(text: "Shared duplicate English subtitle")]
    )
    try database.replaceEntries(
        subtitleFile: URL(fileURLWithPath: "/Media/Show 2/Episode 2.ja.srt"),
        videoFile: show2Episode2Video,
        entries: [databaseTestEntry(text: "Shared duplicate Japanese subtitle")]
    )
    try database.replaceEntries(
        subtitleFile: URL(fileURLWithPath: "/Media/Show 2/Episode 11.srt"),
        videoFile: show2Episode11Video,
        entries: [databaseTestEntry(text: "Shared later episode")]
    )
    try database.replaceEntries(
        subtitleFile: URL(fileURLWithPath: "/Media/Show 11/Episode 1.srt"),
        videoFile: show11Episode1Video,
        entries: [databaseTestEntry(text: "Shared other folder")]
    )

    try database.updateVideoDuration(videoFile: show2Episode2Video, duration: 125.4)

    let videos = try database.libraryVideos(under: [URL(fileURLWithPath: "/Media")])

    #expect(videos.map(\.videoPath) == [
        show2Episode2Video.path,
        show2Episode11Video.path,
        show11Episode1Video.path
    ])
    #expect(videos[0].duration == 125.4)
    #expect(videos[0].subtitlePath == "/Media/Show 2/Episode 2.en.srt")
}

@Test
func libraryPresentationSnapshotStoresReadyDisplayRows() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    let episode2Video = URL(fileURLWithPath: "/Media/Show 2/Episode 2.mkv")
    let episode11Video = URL(fileURLWithPath: "/Media/Show 2/Episode 11.mkv")

    try database.replaceEntries(
        subtitleFile: URL(fileURLWithPath: "/Media/Show 2/Episode 2.ja.srt"),
        videoFile: episode2Video,
        entries: [databaseTestEntry(text: "Japanese subtitle")]
    )
    try database.replaceEntries(
        subtitleFile: URL(fileURLWithPath: "/Media/Show 2/Episode 2.en.srt"),
        videoFile: episode2Video,
        entries: [databaseTestEntry(text: "English subtitle")]
    )
    try database.replaceEntries(
        subtitleFile: URL(fileURLWithPath: "/Media/Show 2/Episode 11.srt"),
        videoFile: episode11Video,
        entries: [databaseTestEntry(text: "Later episode")]
    )
    try database.updateVideoDuration(videoFile: episode2Video, duration: 125.4)

    #expect(try database.libraryPresentation(under: [URL(fileURLWithPath: "/Media")]).isEmpty)

    try database.rebuildLibraryPresentationSnapshot()
    let groups = try database.libraryPresentation(under: [URL(fileURLWithPath: "/Media")])

    #expect(groups.count == 1)
    let group = try #require(groups.first)
    #expect(group.folderTitle == "Show 2")
    #expect(group.videos.map(\.videoPath) == [
        episode2Video.path,
        episode11Video.path
    ])
    #expect(group.videos.map(\.displayTitle) == [
        "Show 2 - 01",
        "Show 2 - 02"
    ])
    #expect(group.videos[0].fileExtension == "mkv")
    #expect(group.videos[0].duration == 125.4)
    #expect(group.videos[0].subtitlePath == "/Media/Show 2/Episode 2.en.srt")
}

@Test
func libraryPlaybackHistoryPersistsResumePositionByVideo() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    let videoFile = URL(fileURLWithPath: "/Media/Show/Episode 1.mkv")
    try database.upsertLibraryPlaybackHistory(
        videoFile: videoFile,
        positionMilliseconds: 91_250,
        duration: 1_800.5
    )

    let initialHistory = try #require(try database.libraryPlaybackHistory(forVideoFile: videoFile))
    #expect(initialHistory.videoPath == videoFile.path)
    #expect(initialHistory.positionMilliseconds == 91_250)
    #expect(initialHistory.duration == 1_800.5)

    try database.upsertLibraryPlaybackHistory(
        videoFile: videoFile,
        positionMilliseconds: 125_000,
        duration: nil
    )

    let updatedHistory = try #require(try database.libraryPlaybackHistory(forVideoFile: videoFile))
    #expect(updatedHistory.positionMilliseconds == 125_000)
    #expect(updatedHistory.duration == nil)
}

@Test
func shioriPersistsCueIdentityAndCreatedAt() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    let subtitleFile = URL(fileURLWithPath: "/Media/Show/Episode 1.srt")
    let videoFile = URL(fileURLWithPath: "/Media/Show/Episode 1.mkv")
    try database.replaceEntries(
        subtitleFile: subtitleFile,
        videoFile: videoFile,
        entries: [
            SubtitleEntry(
                sequenceNumber: 1,
                startTimecode: "00:00:01,000",
                endTimecode: "00:00:03,000",
                startMilliseconds: 1_000,
                endMilliseconds: 3_000,
                text: "First saved line.\nSecond saved line."
            )
        ]
    )

    let selection = try #require(try database.cueTextSelection(
        forSubtitleFile: subtitleFile,
        atMilliseconds: 1_500
    ))
    let createdAt = Date(timeIntervalSince1970: 1_700_000_000)

    let shiori = try database.upsertShiori(
        subtitleFile: subtitleFile,
        subtitleFormat: .srt,
        videoFile: videoFile,
        videoName: videoFile.lastPathComponent,
        selection: selection,
        createdAt: createdAt
    )
    let duplicate = try database.upsertShiori(
        subtitleFile: subtitleFile,
        subtitleFormat: .srt,
        videoFile: videoFile,
        videoName: videoFile.lastPathComponent,
        selection: selection,
        createdAt: Date(timeIntervalSince1970: 1_800_000_000)
    )

    #expect(shiori.id == duplicate.id)
    #expect(shiori.subtitlePath == subtitleFile.path)
    #expect(shiori.subtitleFormat == .srt)
    #expect(shiori.videoPath == videoFile.path)
    #expect(shiori.videoName == "Episode 1.mkv")
    #expect(shiori.startMilliseconds == 1_000)
    #expect(shiori.endMilliseconds == 3_000)
    #expect(shiori.cueLines == ["First saved line.", "Second saved line."])
    #expect(shiori.isValid)
    #expect(shiori.createdAt == ISO8601DateFormatter().string(from: createdAt))
    #expect(duplicate.createdAt == shiori.createdAt)
    #expect(try database.shioris().count == 1)
}

@Test
func removingIndexedFolderPreservesShiori() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    let folder = URL(fileURLWithPath: "/Media/Show")
    let subtitleFile = folder.appendingPathComponent("Episode 1.srt")
    let videoFile = folder.appendingPathComponent("Episode 1.mkv")
    try database.replaceEntries(
        subtitleFile: subtitleFile,
        videoFile: videoFile,
        entries: [
            SubtitleEntry(
                sequenceNumber: 1,
                startTimecode: "00:00:01,000",
                endTimecode: "00:00:03,000",
                startMilliseconds: 1_000,
                endMilliseconds: 3_000,
                text: "Shiori should survive index removal."
            )
        ]
    )
    let selection = try #require(try database.cueTextSelection(
        forSubtitleFile: subtitleFile,
        atMilliseconds: 1_500
    ))
    _ = try database.upsertShiori(
        subtitleFile: subtitleFile,
        subtitleFormat: .srt,
        videoFile: videoFile,
        videoName: videoFile.lastPathComponent,
        selection: selection
    )

    try database.removeIndexedFolder(folder)

    #expect(try database.search("Shiori").isEmpty)
    let shiori = try #require(try database.shioris().first)
    #expect(shiori.subtitlePath == subtitleFile.path)
    #expect(shiori.videoPath == videoFile.path)
    #expect(shiori.content == "Shiori should survive index removal.")
}

@Test
func removingIndexedFolderPreservesLibraryPlaybackHistory() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    let folder = URL(fileURLWithPath: "/Media/Show")
    let videoFile = folder.appendingPathComponent("Episode 1.mkv")
    try database.replaceEntries(
        subtitleFile: folder.appendingPathComponent("Episode 1.srt"),
        videoFile: videoFile,
        entries: [
            SubtitleEntry(
                sequenceNumber: 1,
                startTimecode: "00:00:01,000",
                endTimecode: "00:00:03,000",
                startMilliseconds: 1_000,
                endMilliseconds: 3_000,
                text: "Library history should survive index removal."
            )
        ]
    )
    try database.upsertLibraryPlaybackHistory(
        videoFile: videoFile,
        positionMilliseconds: 42_000,
        duration: 1_200.0
    )

    try database.removeIndexedFolder(folder)

    #expect(try database.libraryVideos(under: [folder]).isEmpty)
    let history = try #require(try database.libraryPlaybackHistory(forVideoFile: videoFile))
    #expect(history.videoPath == videoFile.path)
    #expect(history.positionMilliseconds == 42_000)
    #expect(history.duration == 1_200.0)
}

@Test
func searchPageReturnsFriendlyFileSummaryDisplayTitles() throws {
    let databaseURL = temporaryDatabaseURL()
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerFriendlySummaryTests-\(UUID().uuidString)")
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
        try? FileManager.default.removeItem(at: root)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    let series = root.appendingPathComponent("葬送的芙莉莲")
    try FileManager.default.createDirectory(at: series, withIntermediateDirectories: true)
    let firstSubtitle = series.appendingPathComponent("aa1.ass")
    let secondSubtitle = series.appendingPathComponent("aa2.ass")
    let eleventhSubtitle = series.appendingPathComponent("aa11.ass")
    for subtitleFile in [firstSubtitle, secondSubtitle, eleventhSubtitle] {
        try "subtitle".write(to: subtitleFile, atomically: true, encoding: .utf8)
    }

    try database.replaceEntries(
        subtitleFile: secondSubtitle,
        videoFile: series.appendingPathComponent("aa2.mkv"),
        entries: [
            SubtitleEntry(
                sequenceNumber: 1,
                startTimecode: "00:00:02,000",
                endTimecode: "00:00:03,000",
                startMilliseconds: 2_000,
                endMilliseconds: 3_000,
                text: "Shared second"
            )
        ]
    )
    try database.replaceEntries(
        subtitleFile: eleventhSubtitle,
        videoFile: series.appendingPathComponent("aa11.mkv"),
        entries: [
            SubtitleEntry(
                sequenceNumber: 1,
                startTimecode: "00:00:11,000",
                endTimecode: "00:00:12,000",
                startMilliseconds: 11_000,
                endMilliseconds: 12_000,
                text: "Shared eleventh"
            )
        ]
    )

    try FileManager.default.removeItem(at: series)

    let diagnostics = SearchDiagnosticRecorder()
    let page = try database.searchPage("shared", limit: 10, diagnostics: diagnostics.record)
    let sortEvent = try #require(diagnostics.events.first { $0.name == "sort_results" })
    let sortFields = Dictionary(uniqueKeysWithValues: sortEvent.fields.map { ($0.name, $0.value) })

    #expect(page.fileSummaries.map(\.subtitleFileName) == ["aa2.ass", "aa11.ass"])
    #expect(page.fileSummaries.map(\.subtitleDisplayTitle) == ["葬送的芙莉莲 - 02", "葬送的芙莉莲 - 03"])
    #expect(page.results.map(\.displayTitle) == ["葬送的芙莉莲 - 02", "葬送的芙莉莲 - 03"])
    #expect(page.results.map(\.content) == ["Shared second", "Shared eleventh"])
    #expect(sortFields["orderSource"] == "ftsRowid")
    #expect(sortFields["materializedOrderRows"] == "2")
}

@Test
func searchPageFailsWhenSearchOrderRowsAreMissing() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    try database.replaceEntries(
        subtitleFile: URL(fileURLWithPath: "/Media/Series/Episode.srt"),
        videoFile: URL(fileURLWithPath: "/Media/Series/Episode.mkv"),
        entries: [
            SubtitleEntry(
                sequenceNumber: 1,
                startTimecode: "00:00:01,000",
                endTimecode: "00:00:02,000",
                startMilliseconds: 1_000,
                endMilliseconds: 2_000,
                text: "Shared materialized row"
            )
        ]
    )
    try executeSQLite(at: databaseURL, "DELETE FROM subtitle_search_order_rows;")

    var thrownMessage: String?
    do {
        _ = try database.searchPage("shared", limit: 10)
    } catch {
        thrownMessage = String(describing: error)
    }

    #expect(thrownMessage?.contains("Search order rows are missing") == true)
}

@Test
func searchLoadsRowsForSpecificSubtitleFileOutsideGlobalPage() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    let alphaSubtitle = URL(fileURLWithPath: "/Media/Alpha.srt")
    let alphaVideo = URL(fileURLWithPath: "/Media/Alpha.mkv")
    let zetaSubtitle = URL(fileURLWithPath: "/Media/Zeta.srt")
    let zetaVideo = URL(fileURLWithPath: "/Media/Zeta.mkv")

    let alphaEntries = (0..<100).map { index in
        let minutes = index / 60
        let seconds = index % 60
        return SubtitleEntry(
            sequenceNumber: index + 1,
            startTimecode: String(format: "00:%02d:%02d,000", minutes, seconds),
            endTimecode: String(format: "00:%02d:%02d,500", minutes, seconds),
            startMilliseconds: index * 1_000,
            endMilliseconds: index * 1_000 + 500,
            text: "Shared alpha line \(index)"
        )
    }

    try database.replaceEntries(
        subtitleFile: alphaSubtitle,
        videoFile: alphaVideo,
        entries: alphaEntries
    )
    try database.replaceEntries(
        subtitleFile: zetaSubtitle,
        videoFile: zetaVideo,
        entries: [
            SubtitleEntry(
                sequenceNumber: 1,
                startTimecode: "00:02:00,000",
                endTimecode: "00:02:00,500",
                startMilliseconds: 120_000,
                endMilliseconds: 120_500,
                text: "Shared zeta line"
            )
        ]
    )

    let globalPage = try database.searchPage("shared", limit: 100)
    let zetaRows = try database.search(
        "shared",
        limit: 100,
        inSubtitlePath: zetaSubtitle.path
    )

    #expect(globalPage.totalCount == 101)
    #expect(globalPage.results.count == 100)
    #expect(globalPage.results.contains { $0.subtitlePath == zetaSubtitle.path } == false)
    #expect(globalPage.fileSummaries.map(\.matchCount) == [100, 1])
    #expect(zetaRows.map(\.content) == ["Shared zeta line"])
}

@Test
func storesAndLoadsASSRenderSegmentsByTimestamp() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    let subtitleFile = URL(fileURLWithPath: "/Media/Effects.ass")
    let videoFile = URL(fileURLWithPath: "/Media/Effects.mkv")
    let segments = [
        ASSRenderSegmentPayload(
            segmentIndex: 0,
            startMilliseconds: 0,
            endMilliseconds: 30_000,
            scriptText: "[Script Info]\n[Events]\n",
            eventCount: 0,
            byteCount: 23
        ),
        ASSRenderSegmentPayload(
            segmentIndex: 1,
            startMilliseconds: 30_000,
            endMilliseconds: 60_000,
            scriptText: "[Script Info]\n[Events]\nDialogue: 0,0:00:30.00,0:00:31.00,Default,,0,0,0,,fx\n",
            eventCount: 1,
            byteCount: 89
        )
    ]

    try database.replaceCueGroups(
        subtitleFile: subtitleFile,
        videoFile: videoFile,
        format: .ass,
        cueGroups: [],
        assRenderSegments: segments
    )

    #expect(try database.hasASSRenderSegments(forSubtitleFile: subtitleFile))
    let loadedSegment = try database.assRenderSegment(forSubtitleFile: subtitleFile, atMilliseconds: 30_250)
    let segment = try #require(loadedSegment)
    #expect(segment.startMilliseconds == 30_000)
    #expect(segment.endMilliseconds == 60_000)
    #expect(segment.eventCount == 1)
    #expect(segment.scriptText.contains("Dialogue:"))
    #expect(try database.assRenderSegment(forSubtitleFile: subtitleFile, atMilliseconds: 60_000) == nil)
}

@Test
func storesAndLoadsASSFontReferences() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    let subtitleFile = URL(fileURLWithPath: "/Media/Effects.ass")
    let videoFile = URL(fileURLWithPath: "/Media/Effects.mkv")
    let references = [
        ASSFontReferenceIntent(
            fontName: "华文中宋",
            source: .style,
            occurrenceCount: 2,
            firstOccurrenceOrder: 0
        ),
        ASSFontReferenceIntent(
            fontName: "汉仪小隶书简",
            source: .inlineOverride,
            occurrenceCount: 1,
            firstOccurrenceOrder: 2
        )
    ]

    try database.replaceCueGroups(
        subtitleFile: subtitleFile,
        videoFile: videoFile,
        format: .ass,
        cueGroups: [],
        assFontReferences: references
    )

    #expect(try database.hasCurrentASSFontReferenceManifest(forSubtitleFile: subtitleFile))
    #expect(try database.assFontReferences(forSubtitleFile: subtitleFile) == [
        ASSFontReference(
            subtitlePath: subtitleFile.path,
            fontName: "华文中宋",
            source: .style,
            occurrenceCount: 2,
            firstOccurrenceOrder: 0
        ),
        ASSFontReference(
            subtitlePath: subtitleFile.path,
            fontName: "汉仪小隶书简",
            source: .inlineOverride,
            occurrenceCount: 1,
            firstOccurrenceOrder: 2
        )
    ])
}

@Test
func storesAndLoadsASSFontResourceManifest() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    let subtitleFile = URL(fileURLWithPath: "/Media/Effects.ass")
    let videoFile = URL(fileURLWithPath: "/Media/Effects.mkv")
    let fontsDirectory = URL(fileURLWithPath: "/Cache/CueSeeker/ASSFontResources/abc")

    try database.replaceCueGroups(
        subtitleFile: subtitleFile,
        videoFile: videoFile,
        format: .ass,
        cueGroups: [
            testCueGroup(
                startMilliseconds: 0,
                endMilliseconds: 1_000,
                content: "Styled line",
                eventIndex: 0
            )
        ]
    )

    try database.upsertASSFontResourceManifest(
        subtitleFile: subtitleFile,
        videoFile: videoFile,
        status: .readyWithFonts,
        fontsDirectory: fontsDirectory,
        resourceSignature: "signature-v1"
    )

    let loadedManifest = try database.assFontResourceManifest(
        forSubtitleFile: subtitleFile,
        videoFile: videoFile
    )
    let manifest = try #require(loadedManifest)
    #expect(manifest.subtitlePath == subtitleFile.path)
    #expect(manifest.videoPath == videoFile.path)
    #expect(manifest.status == .readyWithFonts)
    #expect(manifest.fontsDirectoryPath == fontsDirectory.path)
    #expect(manifest.resourceSignature == "signature-v1")
    #expect(manifest.errorMessage == nil)
    #expect(!manifest.preparedAt.isEmpty)

    try database.upsertASSFontResourceManifest(
        subtitleFile: subtitleFile,
        videoFile: videoFile,
        status: .readyWithoutFonts,
        fontsDirectory: nil,
        resourceSignature: "signature-v2",
        errorMessage: nil
    )

    let updatedManifest = try #require(try database.assFontResourceManifest(
        forSubtitleFile: subtitleFile,
        videoFile: videoFile
    ))
    #expect(updatedManifest.status == .readyWithoutFonts)
    #expect(updatedManifest.fontsDirectoryPath == nil)
    #expect(updatedManifest.resourceSignature == "signature-v2")
}

@Test
func migrationInvalidatesOldASSRenderSegmentAlgorithmVersion() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let subtitleFile = URL(fileURLWithPath: "/Media/OldEffects.ass")
    try createVersionFourDatabaseWithASSRenderSegments(at: databaseURL, subtitlePath: subtitleFile.path)

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    #expect(try database.schemaVersion() == SubtitleDatabase.currentSchemaVersion)
    #expect(!(try database.hasASSRenderSegments(forSubtitleFile: subtitleFile)))
    #expect(try database.assRenderSegment(forSubtitleFile: subtitleFile, atMilliseconds: 1_000) == nil)
}

@Test
func migrationBackfillsCueGroupLineCountAndSearchOrderRows() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    try createVersionTenDatabaseWithMixedCueGroupLineCounts(at: databaseURL)

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    #expect(try database.schemaVersion() == SubtitleDatabase.currentSchemaVersion)

    let lineCountByGroupID = try readCueGroupLineCounts(at: databaseURL)
    #expect(lineCountByGroupID[1] == 1)
    #expect(lineCountByGroupID[2] == 2)
    #expect(lineCountByGroupID[3] == 3)

    let searchOrderRows = try readSearchOrderRows(at: databaseURL)
    #expect(searchOrderRows.map(\.subtitlePath) == ["/Media/Sample.ass"])
    #expect(searchOrderRows.map(\.displayTitle) == ["Sample.ass"])
    #expect(searchOrderRows.map(\.folderOrder) == [0])
    #expect(searchOrderRows.map(\.fileOrder) == [0])
}

@Test
func insertingCueGroupsRecordsTheirLineCount() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    let subtitleFile = URL(fileURLWithPath: "/Media/Mixed.ass")
    let videoFile = URL(fileURLWithPath: "/Media/Mixed.mkv")

    try database.replaceCueGroups(
        subtitleFile: subtitleFile,
        videoFile: videoFile,
        format: .ass,
        cueGroups: [
            testCueGroup(
                startMilliseconds: 0,
                endMilliseconds: 1_000,
                content: "single",
                eventIndex: 0
            ),
            SubtitleCueGroup(
                sequenceNumber: nil,
                startTimecode: "1000",
                endTimecode: "2000",
                startMilliseconds: 1_000,
                endMilliseconds: 2_000,
                searchContent: "top\nbottom",
                cueLines: [
                    testCueLine(eventIndex: 1, startMilliseconds: 1_000, endMilliseconds: 2_000, content: "top", displayOrder: 0),
                    testCueLine(eventIndex: 2, startMilliseconds: 1_000, endMilliseconds: 2_000, content: "bottom", displayOrder: 1)
                ]
            )
        ]
    )

    let counts = try readCueGroupLineCounts(at: databaseURL)
    #expect(counts.values.sorted() == [1, 2])
}

@Test
func replacingEntriesRemovesStaleFTSRows() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    let subtitleFile = URL(fileURLWithPath: "/Media/Episode.srt")
    let videoFile = URL(fileURLWithPath: "/Media/Episode.mp4")

    try database.replaceEntries(
        subtitleFile: subtitleFile,
        videoFile: videoFile,
        entries: [
            SubtitleEntry(
                sequenceNumber: 1,
                startTimecode: "00:00:01,000",
                endTimecode: "00:00:03,000",
                startMilliseconds: 1_000,
                endMilliseconds: 3_000,
                text: "Old searchable text."
            )
        ]
    )

    try database.replaceEntries(
        subtitleFile: subtitleFile,
        videoFile: videoFile,
        entries: [
            SubtitleEntry(
                sequenceNumber: 1,
                startTimecode: "00:00:09,000",
                endTimecode: "00:00:11,000",
                startMilliseconds: 9_000,
                endMilliseconds: 11_000,
                text: "Fresh searchable text."
            )
        ]
    )

    #expect(try database.search("Old").isEmpty)

    let freshResults = try database.search("Fresh")
    #expect(freshResults.count == 1)
    #expect(freshResults[0].startMilliseconds == 9_000)
}

@Test
func removingIndexedFolderDeletesIndexedRowsAndSearchPath() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    let removedFolder = URL(fileURLWithPath: "/Media/Removed")
    let keptFolder = URL(fileURLWithPath: "/Media/Kept")
    let removedSearchPathID = try database.addSearchPath(removedFolder)
    _ = try database.addSearchPath(keptFolder)

    try database.replaceEntries(
        subtitleFile: removedFolder.appendingPathComponent("Episode.srt"),
        videoFile: removedFolder.appendingPathComponent("Episode.mkv"),
        entries: [
            SubtitleEntry(
                sequenceNumber: 1,
                startTimecode: "00:00:01,000",
                endTimecode: "00:00:03,000",
                startMilliseconds: 1_000,
                endMilliseconds: 3_000,
                text: "Removed folder searchable text."
            )
        ]
    )
    try database.replaceEntries(
        subtitleFile: keptFolder.appendingPathComponent("Episode.srt"),
        videoFile: keptFolder.appendingPathComponent("Episode.mkv"),
        entries: [
            SubtitleEntry(
                sequenceNumber: 1,
                startTimecode: "00:00:04,000",
                endTimecode: "00:00:06,000",
                startMilliseconds: 4_000,
                endMilliseconds: 6_000,
                text: "Kept folder searchable text."
            )
        ]
    )

    try database.removeIndexedFolder(removedFolder)

    #expect(try database.search("Removed").isEmpty)
    #expect(try database.search("Kept").count == 1)
    #expect(try database.subtitleFiles().map(\.subtitlePath) == [
        keptFolder.appendingPathComponent("Episode.srt").path
    ])

    let newRemovedSearchPathID = try database.addSearchPath(removedFolder)
    #expect(newRemovedSearchPathID != removedSearchPathID)
}

@Test
func scopedSearchOnlyReturnsEntriesUnderActiveFolders() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    let activeFolder = URL(fileURLWithPath: "/Media/Active")
    let staleFolder = URL(fileURLWithPath: "/Media/Stale")
    try database.replaceEntries(
        subtitleFile: activeFolder.appendingPathComponent("Episode.srt"),
        videoFile: activeFolder.appendingPathComponent("Episode.mkv"),
        entries: [
            SubtitleEntry(
                sequenceNumber: 1,
                startTimecode: "00:00:01,000",
                endTimecode: "00:00:03,000",
                startMilliseconds: 1_000,
                endMilliseconds: 3_000,
                text: "Shared searchable text from active folder."
            )
        ]
    )
    try database.replaceEntries(
        subtitleFile: staleFolder.appendingPathComponent("Episode.srt"),
        videoFile: staleFolder.appendingPathComponent("Episode.mkv"),
        entries: [
            SubtitleEntry(
                sequenceNumber: 1,
                startTimecode: "00:00:04,000",
                endTimecode: "00:00:06,000",
                startMilliseconds: 4_000,
                endMilliseconds: 6_000,
                text: "Shared searchable text from stale folder."
            )
        ]
    )

    #expect(try database.search("Shared").count == 2)
    #expect(try database.search("Shared", under: [activeFolder]).map(\.subtitlePath) == [
        activeFolder.appendingPathComponent("Episode.srt").path
    ])
    #expect(try database.search("Shared", under: []).isEmpty)
}

@Test
func reconcileIndexedContentClearsAllDataWhenNoFoldersAreActive() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    let folder = URL(fileURLWithPath: "/Media/Removed")
    let searchPathID = try database.addSearchPath(folder)
    try database.replaceEntries(
        subtitleFile: folder.appendingPathComponent("Episode.srt"),
        videoFile: folder.appendingPathComponent("Episode.mkv"),
        entries: [
            SubtitleEntry(
                sequenceNumber: 1,
                startTimecode: "00:00:01,000",
                endTimecode: "00:00:03,000",
                startMilliseconds: 1_000,
                endMilliseconds: 3_000,
                text: "Temporary recovery searchable text."
            )
        ]
    )

    try database.reconcileIndexedContent(activeFolders: [])

    #expect(try database.search("Temporary").isEmpty)
    #expect(try database.subtitleFiles().isEmpty)

    let newSearchPathID = try database.addSearchPath(folder)
    #expect(newSearchPathID != searchPathID)
}

@Test
func reconcileIndexedContentPrunesDataOutsideActiveFolders() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    let activeFolder = URL(fileURLWithPath: "/Media/Active")
    let staleFolder = URL(fileURLWithPath: "/Media/Stale")
    _ = try database.addSearchPath(activeFolder)
    let staleSearchPathID = try database.addSearchPath(staleFolder)
    try database.replaceEntries(
        subtitleFile: activeFolder.appendingPathComponent("Episode.srt"),
        videoFile: activeFolder.appendingPathComponent("Episode.mkv"),
        entries: [
            SubtitleEntry(
                sequenceNumber: 1,
                startTimecode: "00:00:01,000",
                endTimecode: "00:00:03,000",
                startMilliseconds: 1_000,
                endMilliseconds: 3_000,
                text: "Active folder searchable text."
            )
        ]
    )
    try database.replaceEntries(
        subtitleFile: staleFolder.appendingPathComponent("Episode.srt"),
        videoFile: staleFolder.appendingPathComponent("Episode.mkv"),
        entries: [
            SubtitleEntry(
                sequenceNumber: 1,
                startTimecode: "00:00:04,000",
                endTimecode: "00:00:06,000",
                startMilliseconds: 4_000,
                endMilliseconds: 6_000,
                text: "Stale folder searchable text."
            )
        ]
    )

    try database.reconcileIndexedContent(activeFolders: [activeFolder])

    #expect(try database.search("Active").count == 1)
    #expect(try database.search("Stale").isEmpty)
    #expect(try database.subtitleFiles().map(\.subtitlePath) == [
        activeFolder.appendingPathComponent("Episode.srt").path
    ])

    let newStaleSearchPathID = try database.addSearchPath(staleFolder)
    #expect(newStaleSearchPathID != staleSearchPathID)
}

@Test
func emptySearchQueryReturnsNoResults() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    #expect(try database.search("").isEmpty)
    #expect(try database.search("   ").isEmpty)
}

@Test
func searchNormalizesFTSQuerySyntaxCharacters() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    let subtitleFile = URL(fileURLWithPath: "/Media/Special.srt")
    let videoFile = URL(fileURLWithPath: "/Media/Special.mkv")

    try database.replaceEntries(
        subtitleFile: subtitleFile,
        videoFile: videoFile,
        entries: [
            SubtitleEntry(
                sequenceNumber: 1,
                startTimecode: "00:00:01,000",
                endTimecode: "00:00:03,000",
                startMilliseconds: 1_000,
                endMilliseconds: 3_000,
                text: "He said hello to spider-man again."
            )
        ]
    )

    let results = try database.search(#""hello": spider-man"#)

    #expect(results.count == 1)
    #expect(results[0].content == "He said hello to spider-man again.")
    #expect(try database.search(":::").isEmpty)
}

@Test
func searchUsesFlutterLikeSingleTokenPrefixMatching() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    try database.replaceEntries(
        subtitleFile: URL(fileURLWithPath: "/Media/Prefix.srt"),
        videoFile: URL(fileURLWithPath: "/Media/Prefix.mkv"),
        entries: [
            SubtitleEntry(
                sequenceNumber: 1,
                startTimecode: "00:00:01,000",
                endTimecode: "00:00:03,000",
                startMilliseconds: 1_000,
                endMilliseconds: 3_000,
                text: "Spider-man returns."
            )
        ]
    )

    let results = try database.search("spi")

    #expect(results.count == 1)
    #expect(results[0].content == "Spider-man returns.")
}

@Test
func searchFiltersMultipleLatinTokensByWholeTokenOrder() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    try database.replaceEntries(
        subtitleFile: URL(fileURLWithPath: "/Media/Ordered.srt"),
        videoFile: URL(fileURLWithPath: "/Media/Ordered.mkv"),
        entries: [
            SubtitleEntry(
                sequenceNumber: 1,
                startTimecode: "00:00:01,000",
                endTimecode: "00:00:03,000",
                startMilliseconds: 1_000,
                endMilliseconds: 3_000,
                text: "alpha beta gamma"
            ),
            SubtitleEntry(
                sequenceNumber: 2,
                startTimecode: "00:00:04,000",
                endTimecode: "00:00:06,000",
                startMilliseconds: 4_000,
                endMilliseconds: 6_000,
                text: "beta alpha gamma"
            ),
            SubtitleEntry(
                sequenceNumber: 3,
                startTimecode: "00:00:07,000",
                endTimecode: "00:00:09,000",
                startMilliseconds: 7_000,
                endMilliseconds: 9_000,
                text: "alpha middle beta"
            )
        ]
    )

    let results = try database.search("alpha beta")

    #expect(results.map(\.content) == ["alpha beta gamma", "alpha middle beta"])
}

@Test
func searchSegmentsCJKContentLikeFlutter() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    try database.replaceEntries(
        subtitleFile: URL(fileURLWithPath: "/Media/CJK.srt"),
        videoFile: URL(fileURLWithPath: "/Media/CJK.mkv"),
        entries: [
            SubtitleEntry(
                sequenceNumber: 1,
                startTimecode: "00:00:01,000",
                endTimecode: "00:00:03,000",
                startMilliseconds: 1_000,
                endMilliseconds: 3_000,
                text: "你好世界"
            ),
            SubtitleEntry(
                sequenceNumber: 2,
                startTimecode: "00:00:04,000",
                endTimecode: "00:00:06,000",
                startMilliseconds: 4_000,
                endMilliseconds: 6_000,
                text: "世界你好"
            )
        ]
    )

    let results = try database.search("好世")

    #expect(results.map(\.content) == ["你好世界"])
}

@Test
func searchSegmentsJapaneseKanaContent() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    try database.replaceEntries(
        subtitleFile: URL(fileURLWithPath: "/Media/Japanese.srt"),
        videoFile: URL(fileURLWithPath: "/Media/Japanese.mkv"),
        entries: [
            SubtitleEntry(
                sequenceNumber: 1,
                startTimecode: "00:00:01,000",
                endTimecode: "00:00:03,000",
                startMilliseconds: 1_000,
                endMilliseconds: 3_000,
                text: "日本語ラインかなカナﾃｽﾄ"
            ),
            SubtitleEntry(
                sequenceNumber: 2,
                startTimecode: "00:00:04,000",
                endTimecode: "00:00:06,000",
                startMilliseconds: 4_000,
                endMilliseconds: 6_000,
                text: "別の字幕"
            )
        ]
    )

    #expect(try database.search("ライン").map(\.content) == ["日本語ラインかなカナﾃｽﾄ"])
    #expect(try database.search("かな").map(\.content) == ["日本語ラインかなカナﾃｽﾄ"])
    #expect(try database.search("カナ").map(\.content) == ["日本語ラインかなカナﾃｽﾄ"])
    #expect(try database.search("ﾃｽﾄ").map(\.content) == ["日本語ラインかなカナﾃｽﾄ"])
}

@Test
func invalidExplicitFTSQueryReturnsNoResults() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    try database.replaceEntries(
        subtitleFile: URL(fileURLWithPath: "/Media/InvalidSyntax.srt"),
        videoFile: URL(fileURLWithPath: "/Media/InvalidSyntax.mkv"),
        entries: [
            SubtitleEntry(
                sequenceNumber: 1,
                startTimecode: "00:00:01,000",
                endTimecode: "00:00:03,000",
                startMilliseconds: 1_000,
                endMilliseconds: 3_000,
                text: "hello syntax"
            )
        ]
    )

    #expect(try database.search("hello AND").isEmpty)
}

@Test
func migrationPreservesSearchPathsAndClearsLegacyDerivedIndex() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    try createLegacyVersionOneDatabase(at: databaseURL)

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    #expect(try database.schemaVersion() == SubtitleDatabase.currentSchemaVersion)
    #expect(try database.search("好世").isEmpty)

    let searchPathID = try database.addSearchPath(URL(fileURLWithPath: "/Media"))
    let sameSearchPathID = try database.addSearchPath(URL(fileURLWithPath: "/Media"))
    #expect(searchPathID == sameSearchPathID)
}

@Test
func migrationRebuildsFTSRowsForJapaneseKanaSearch() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    try createVersionFiveDatabaseWithUnsegmentedKanaFTS(at: databaseURL)

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    #expect(try database.schemaVersion() == SubtitleDatabase.currentSchemaVersion)
    #expect(try database.search("ライン").map(\.content) == ["日本語ライン"])
}

@Test
func searchesCueGroupsAndRejectsCrossLineOnlyMatches() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    let subtitleFile = URL(fileURLWithPath: "/Media/Movie.ass")
    let videoFile = URL(fileURLWithPath: "/Media/Movie.mkv")
    let cueGroup = SubtitleCueGroup(
        sequenceNumber: nil,
        startTimecode: "0:00:01.00",
        endTimecode: "0:00:03.00",
        startMilliseconds: 1_000,
        endMilliseconds: 3_000,
        searchContent: "alpha\nbeta",
        cueLines: [
            SubtitleCueLine(
                eventIndex: 0,
                sourceFormat: .ass,
                sourceStyle: "Top",
                sourceLayer: 0,
                startTimecode: "0:00:01.00",
                endTimecode: "0:00:03.00",
                startMilliseconds: 1_000,
                endMilliseconds: 3_000,
                content: "alpha",
                displayX: nil,
                displayY: 10,
                displayOrder: 0
            ),
            SubtitleCueLine(
                eventIndex: 1,
                sourceFormat: .ass,
                sourceStyle: "Bottom",
                sourceLayer: 1,
                startTimecode: "0:00:01.00",
                endTimecode: "0:00:03.00",
                startMilliseconds: 1_000,
                endMilliseconds: 3_000,
                content: "beta",
                displayX: nil,
                displayY: 900,
                displayOrder: 1
            )
        ]
    )

    try database.replaceCueGroups(
        subtitleFile: subtitleFile,
        videoFile: videoFile,
        format: .ass,
        cueGroups: [cueGroup]
    )

    let alphaResults = try database.search("alpha")
    #expect(alphaResults.count == 1)
    #expect(alphaResults[0].subtitleFormat == .ass)
    #expect(alphaResults[0].cueLines == ["alpha", "beta"])
    #expect(alphaResults[0].videoPath == videoFile.path)
    #expect(alphaResults[0].startMilliseconds == 1_000)

    #expect(try database.search("alpha beta").isEmpty)
}

@Test
func searchReadsASSIndexTimePhysicalOrderWithoutRuntimeReordering() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    let subtitleFile = URL(fileURLWithPath: "/Media/Bilingual.ass")
    let videoFile = URL(fileURLWithPath: "/Media/Bilingual.mkv")
    let contents = """
    [Script Info]
    PlayResX: 1920
    PlayResY: 1080

    [V4+ Styles]
    Format: Name, Fontsize, Alignment, MarginL, MarginR, MarginV
    Style: JP,25,2,10,10,13
    Style: CN,40,2,10,10,10

    [Events]
    Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
    Dialogue: 0,0:00:01.00,0:00:03.00,JP,,0000,0000,0000,,Japanese lower line
    Dialogue: 0,0:00:01.00,0:00:03.00,CN,,0000,0000,0000,,Chinese upper line
    """

    let cueGroups = ASSParser.parseCueGroups(contents)
    try database.replaceCueGroups(
        subtitleFile: subtitleFile,
        videoFile: videoFile,
        format: .ass,
        cueGroups: cueGroups
    )

    #expect(try database.entries(forSubtitleFile: subtitleFile).map(\.content) == [
        "Chinese upper line\nJapanese lower line"
    ])

    let results = try database.search("Chinese")
    #expect(results.map(\.content) == ["Chinese upper line\nJapanese lower line"])
    #expect(results.first?.cueLines == ["Chinese upper line", "Japanese lower line"])
}

@Test
func paginatedSearchContinuesPastFilteredFTSCandidates() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    let subtitleFile = URL(fileURLWithPath: "/Media/Filtered.ass")
    let videoFile = URL(fileURLWithPath: "/Media/Filtered.mkv")
    var cueGroups: [SubtitleCueGroup] = []

    for index in 0..<100 {
        let startMilliseconds = index * 1_000
        cueGroups.append(
            SubtitleCueGroup(
                sequenceNumber: nil,
                startTimecode: "\(startMilliseconds)",
                endTimecode: "\(startMilliseconds + 500)",
                startMilliseconds: startMilliseconds,
                endMilliseconds: startMilliseconds + 500,
                searchContent: "alpha\nbeta",
                cueLines: [
                    testCueLine(
                        eventIndex: index * 2,
                        startMilliseconds: startMilliseconds,
                        endMilliseconds: startMilliseconds + 500,
                        content: "alpha",
                        displayOrder: 0
                    ),
                    testCueLine(
                        eventIndex: index * 2 + 1,
                        startMilliseconds: startMilliseconds,
                        endMilliseconds: startMilliseconds + 500,
                        content: "beta",
                        displayOrder: 1
                    )
                ]
            )
        )
    }

    for index in 100..<103 {
        cueGroups.append(
            testCueGroup(
                startMilliseconds: index * 1_000,
                endMilliseconds: index * 1_000 + 500,
                content: "alpha beta page \(index)",
                eventIndex: index
            )
        )
    }

    try database.replaceCueGroups(
        subtitleFile: subtitleFile,
        videoFile: videoFile,
        format: .ass,
        cueGroups: cueGroups
    )

    let firstPage = try database.search("alpha beta", limit: 2)
    let secondPage = try database.search("alpha beta", limit: 2, offset: 2)

    #expect(firstPage.map(\.content) == ["alpha beta page 100", "alpha beta page 101"])
    #expect(secondPage.map(\.content) == ["alpha beta page 102"])
}

@Test
func visibleSearchContinuesPastFilteredFTSCandidates() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    let subtitleFile = URL(fileURLWithPath: "/Media/FilteredVisible.ass")
    let videoFile = URL(fileURLWithPath: "/Media/FilteredVisible.mkv")
    var cueGroups: [SubtitleCueGroup] = []

    for index in 0..<100 {
        let startMilliseconds = index * 1_000
        cueGroups.append(
            SubtitleCueGroup(
                sequenceNumber: nil,
                startTimecode: "\(startMilliseconds)",
                endTimecode: "\(startMilliseconds + 500)",
                startMilliseconds: startMilliseconds,
                endMilliseconds: startMilliseconds + 500,
                searchContent: "alpha\nbeta",
                cueLines: [
                    testCueLine(
                        eventIndex: index * 2,
                        startMilliseconds: startMilliseconds,
                        endMilliseconds: startMilliseconds + 500,
                        content: "alpha",
                        displayOrder: 0
                    ),
                    testCueLine(
                        eventIndex: index * 2 + 1,
                        startMilliseconds: startMilliseconds,
                        endMilliseconds: startMilliseconds + 500,
                        content: "beta",
                        displayOrder: 1
                    )
                ]
            )
        )
    }

    for index in 100..<103 {
        cueGroups.append(
            testCueGroup(
                startMilliseconds: index * 1_000,
                endMilliseconds: index * 1_000 + 500,
                content: "alpha beta visible page \(index)",
                eventIndex: index
            )
        )
    }

    try database.replaceCueGroups(
        subtitleFile: subtitleFile,
        videoFile: videoFile,
        format: .ass,
        cueGroups: cueGroups
    )

    let firstPage = try database.searchVisiblePage("alpha beta", limit: 2, cursor: .start)
    let secondPage = try database.searchVisiblePage("alpha beta", limit: 2, cursor: firstPage.nextCursor)

    #expect(firstPage.results.map(\.content) == [
        "alpha beta visible page 100",
        "alpha beta visible page 101"
    ])
    #expect(firstPage.countState == .exactProgress)
    #expect(firstPage.totalCount == 2)
    #expect(firstPage.nextCursor?.offset == 2)
    #expect(secondPage.results.map(\.content) == ["alpha beta visible page 102"])
    #expect(secondPage.countState == .exact)
    #expect(secondPage.totalCount == 3)
    #expect(secondPage.nextCursor == nil)
}

@Test
func returnsCueTimingsForWindowedASSPreparation() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    let subtitleFile = URL(fileURLWithPath: "/Media/Windowed.ass")
    let videoFile = URL(fileURLWithPath: "/Media/Windowed.mkv")

    try database.replaceCueGroups(
        subtitleFile: subtitleFile,
        videoFile: videoFile,
        format: .ass,
        cueGroups: [
            testCueGroup(startMilliseconds: 1_000, endMilliseconds: 1_500, content: "before", eventIndex: 0),
            testCueGroup(startMilliseconds: 2_000, endMilliseconds: 2_500, content: "selected", eventIndex: 1),
            testCueGroup(startMilliseconds: 4_000, endMilliseconds: 4_500, content: "next", eventIndex: 2),
            testCueGroup(startMilliseconds: 7_000, endMilliseconds: 7_500, content: "outside limit", eventIndex: 3)
        ]
    )

    let timings = try database.cueTimings(
        forSubtitleFile: subtitleFile,
        startingAtMilliseconds: 2_000,
        limit: 2
    )

    #expect(timings == [
        SubtitleCueTiming(startMilliseconds: 2_000, endMilliseconds: 2_500),
        SubtitleCueTiming(startMilliseconds: 4_000, endMilliseconds: 4_500)
    ])
}

@Test
func cueTextSelectionUsesShortestActiveCueAndLatestEndTieBreak() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    let subtitleFile = URL(fileURLWithPath: "/Media/Selection.ass")
    let videoFile = URL(fileURLWithPath: "/Media/Selection.mkv")

    try database.replaceCueGroups(
        subtitleFile: subtitleFile,
        videoFile: videoFile,
        format: .ass,
        cueGroups: [
            testCueGroup(startMilliseconds: 1_000, endMilliseconds: 8_000, content: "long", eventIndex: 0),
            testCueGroup(startMilliseconds: 3_000, endMilliseconds: 5_000, content: "short earlier", eventIndex: 1),
            testCueGroup(startMilliseconds: 3_500, endMilliseconds: 5_500, content: "short later", eventIndex: 2)
        ]
    )

    let selectedCue = try database.cueTextSelection(forSubtitleFile: subtitleFile, atMilliseconds: 4_000)
    let selection = try #require(selectedCue)
    #expect(selection.startMilliseconds == 3_500)
    #expect(selection.endMilliseconds == 5_500)
    #expect(selection.text == "short later")
}

@Test
func cueTextSelectionFallsBackToPreviousCueRange() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    let subtitleFile = URL(fileURLWithPath: "/Media/Previous.ass")
    let videoFile = URL(fileURLWithPath: "/Media/Previous.mkv")

    try database.replaceCueGroups(
        subtitleFile: subtitleFile,
        videoFile: videoFile,
        format: .ass,
        cueGroups: [
            testCueGroup(startMilliseconds: 1_000, endMilliseconds: 5_000, content: "wide previous", eventIndex: 0),
            testCueGroup(startMilliseconds: 4_500, endMilliseconds: 5_000, content: "short previous", eventIndex: 1),
            testCueGroup(startMilliseconds: 7_000, endMilliseconds: 8_000, content: "future", eventIndex: 2)
        ]
    )

    let selectedCue = try database.cueTextSelection(forSubtitleFile: subtitleFile, atMilliseconds: 6_000)
    let selection = try #require(selectedCue)
    #expect(selection.startMilliseconds == 4_500)
    #expect(selection.endMilliseconds == 5_000)
    #expect(selection.text == "short previous")

    #expect(try database.cueTextSelection(forSubtitleFile: subtitleFile, atMilliseconds: 500) == nil)
}

@Test
func cueTextSelectionReturnsLinesInSearchResultDisplayOrder() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    let subtitleFile = URL(fileURLWithPath: "/Media/Lines.ass")
    let videoFile = URL(fileURLWithPath: "/Media/Lines.mkv")
    let cueGroup = SubtitleCueGroup(
        sequenceNumber: nil,
        startTimecode: "0:00:01.00",
        endTimecode: "0:00:03.00",
        startMilliseconds: 1_000,
        endMilliseconds: 3_000,
        searchContent: "bottom\ntop",
        cueLines: [
            testCueLine(
                eventIndex: 0,
                startMilliseconds: 1_000,
                endMilliseconds: 3_000,
                content: "bottom",
                displayOrder: 1
            ),
            testCueLine(
                eventIndex: 1,
                startMilliseconds: 1_000,
                endMilliseconds: 3_000,
                content: "top",
                displayOrder: 0
            )
        ]
    )

    try database.replaceCueGroups(
        subtitleFile: subtitleFile,
        videoFile: videoFile,
        format: .ass,
        cueGroups: [cueGroup]
    )

    let selectedCue = try database.cueTextSelection(forSubtitleFile: subtitleFile, atMilliseconds: 2_000)
    let selection = try #require(selectedCue)
    #expect(selection.lines == ["top", "bottom"])
    #expect(selection.text == "top\nbottom")
}

@Test
func activeSubtitleEntryLookupKeepsLongRunningCueActivePastShortLaterCues() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    let subtitleFile = URL(fileURLWithPath: "/Media/Signs.srt")
    let videoFile = URL(fileURLWithPath: "/Media/Signs.mkv")
    try database.replaceEntries(
        subtitleFile: subtitleFile,
        videoFile: videoFile,
        entries: [
            SubtitleEntry(
                sequenceNumber: 1,
                startTimecode: "00:00:00,000",
                endTimecode: "00:02:00,000",
                startMilliseconds: 0,
                endMilliseconds: 120_000,
                text: "long running sign"
            ),
            SubtitleEntry(
                sequenceNumber: 2,
                startTimecode: "00:00:30,000",
                endTimecode: "00:00:35,000",
                startMilliseconds: 30_000,
                endMilliseconds: 35_000,
                text: "short dialogue"
            ),
            SubtitleEntry(
                sequenceNumber: 3,
                startTimecode: "00:01:00,000",
                endTimecode: "00:01:05,000",
                startMilliseconds: 60_000,
                endMilliseconds: 65_000,
                text: "later short dialogue"
            )
        ]
    )

    let entries = try database.entries(forSubtitleFile: subtitleFile)
    let lookup = SubtitleActiveEntryLookup(entries: entries)

    #expect(lookup.activeEntryID(atMilliseconds: 90_000) == entries[0].id)
    #expect(lookup.activeEntryID(atMilliseconds: 150_000) == entries[2].id)
    #expect(lookup.activeEntryID(atMilliseconds: -1) == nil)
}

@Test
func playbackNavigationStartsWithEmptyHistoryAndZeroRevision() throws {
    let databaseURL = temporaryDatabaseURL()
    defer { try? FileManager.default.removeItem(at: databaseURL) }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    #expect(try database.playbackNavigationEntries().isEmpty)
    #expect(try database.playbackNavigationCurrentEntryID() == nil)
    #expect(try database.playbackNavigationIndexRevision() == 0)
}

@Test
func appendPlaybackNavigationEntryPersistsPayloadAndAssignsIncrementingIDs() throws {
    let databaseURL = temporaryDatabaseURL()
    defer { try? FileManager.default.removeItem(at: databaseURL) }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    let first = try database.appendPlaybackNavigationEntry(
        .library(PlaybackNavigationLibraryPayload(videoPath: "/Media/A.mkv"))
    )
    let second = try database.appendPlaybackNavigationEntry(
        .shiori(
            PlaybackNavigationShioriPayload(
                id: 42,
                subtitlePath: "/Media/B.srt",
                startMilliseconds: 1_000,
                endMilliseconds: 2_000
            )
        )
    )

    #expect(second.id > first.id)

    let entries = try database.playbackNavigationEntries()
    #expect(entries.count == 2)
    #expect(entries[0].id == first.id)
    #expect(entries[0].payload == .library(
        PlaybackNavigationLibraryPayload(videoPath: "/Media/A.mkv")
    ))
    #expect(entries[1].id == second.id)
    #expect(entries[1].kind == .shiori)
    if case .shiori(let shiori) = entries[1].payload {
        #expect(shiori.id == 42)
        #expect(shiori.subtitlePath == "/Media/B.srt")
        #expect(shiori.startMilliseconds == 1_000)
        #expect(shiori.endMilliseconds == 2_000)
    } else {
        Issue.record("Expected shiori payload")
    }
}

@Test
func updatePlaybackNavigationEntryReplacesPayloadAndKeepsID() throws {
    let databaseURL = temporaryDatabaseURL()
    defer { try? FileManager.default.removeItem(at: databaseURL) }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    let entry = try database.appendPlaybackNavigationEntry(
        .library(PlaybackNavigationLibraryPayload(videoPath: "/Media/Old.mkv"))
    )

    let updated = try #require(try database.updatePlaybackNavigationEntry(
        id: entry.id,
        payload: .library(PlaybackNavigationLibraryPayload(videoPath: "/Media/New.mkv"))
    ))

    #expect(updated.id == entry.id)
    #expect(updated.payload == .library(
        PlaybackNavigationLibraryPayload(videoPath: "/Media/New.mkv")
    ))

    let reread = try #require(try database.playbackNavigationEntry(id: entry.id))
    #expect(reread.payload == .library(
        PlaybackNavigationLibraryPayload(videoPath: "/Media/New.mkv")
    ))
}

@Test
func deletePlaybackNavigationEntriesAfterTruncatesForwardEntries() throws {
    let databaseURL = temporaryDatabaseURL()
    defer { try? FileManager.default.removeItem(at: databaseURL) }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    let first = try database.appendPlaybackNavigationEntry(
        .library(PlaybackNavigationLibraryPayload(videoPath: "/Media/A.mkv"))
    )
    _ = try database.appendPlaybackNavigationEntry(
        .library(PlaybackNavigationLibraryPayload(videoPath: "/Media/B.mkv"))
    )
    _ = try database.appendPlaybackNavigationEntry(
        .library(PlaybackNavigationLibraryPayload(videoPath: "/Media/C.mkv"))
    )

    try database.deletePlaybackNavigationEntries(after: first.id)

    let entries = try database.playbackNavigationEntries()
    #expect(entries.count == 1)
    #expect(entries[0].id == first.id)
}

@Test
func prunePlaybackNavigationEntriesKeepsLatestN() throws {
    let databaseURL = temporaryDatabaseURL()
    defer { try? FileManager.default.removeItem(at: databaseURL) }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    var appendedIDs: [Int64] = []
    for index in 0..<5 {
        let entry = try database.appendPlaybackNavigationEntry(
            .library(PlaybackNavigationLibraryPayload(videoPath: "/Media/\(index).mkv"))
        )
        appendedIDs.append(entry.id)
    }

    try database.prunePlaybackNavigationEntries(keepingLatest: 2)

    let entries = try database.playbackNavigationEntries()
    #expect(entries.count == 2)
    #expect(entries.map(\.id) == Array(appendedIDs.suffix(2)))
}

@Test
func currentPlaybackNavigationEntryIDReadsAndWritesNullableValue() throws {
    let databaseURL = temporaryDatabaseURL()
    defer { try? FileManager.default.removeItem(at: databaseURL) }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    let entry = try database.appendPlaybackNavigationEntry(
        .library(PlaybackNavigationLibraryPayload(videoPath: "/Media/A.mkv"))
    )

    try database.setPlaybackNavigationCurrentEntryID(entry.id)
    #expect(try database.playbackNavigationCurrentEntryID() == entry.id)

    try database.setPlaybackNavigationCurrentEntryID(nil)
    #expect(try database.playbackNavigationCurrentEntryID() == nil)
}

@Test
func playbackNavigationIndexRevisionBumpsWhenIndexedContentChanges() throws {
    let databaseURL = temporaryDatabaseURL()
    defer { try? FileManager.default.removeItem(at: databaseURL) }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    let baseline = try database.playbackNavigationIndexRevision()

    try database.replaceEntries(
        subtitleFile: URL(fileURLWithPath: "/Media/Movie.srt"),
        videoFile: URL(fileURLWithPath: "/Media/Movie.mkv"),
        entries: [
            SubtitleEntry(
                sequenceNumber: 1,
                startTimecode: "00:00:01,000",
                endTimecode: "00:00:02,000",
                startMilliseconds: 1_000,
                endMilliseconds: 2_000,
                text: "hello"
            )
        ]
    )

    let afterReplace = try database.playbackNavigationIndexRevision()
    #expect(afterReplace > baseline)

    try database.clearIndexedContent()

    let afterClear = try database.playbackNavigationIndexRevision()
    #expect(afterClear > afterReplace)
}

private func temporaryDatabaseURL() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerDatabaseTests-\(UUID().uuidString)")
        .appendingPathExtension("sqlite")
}

private func testCueGroup(
    startMilliseconds: Int,
    endMilliseconds: Int,
    content: String,
    eventIndex: Int
) -> SubtitleCueGroup {
    SubtitleCueGroup(
        sequenceNumber: nil,
        startTimecode: "\(startMilliseconds)",
        endTimecode: "\(endMilliseconds)",
        startMilliseconds: startMilliseconds,
        endMilliseconds: endMilliseconds,
        searchContent: content,
        cueLines: [
            SubtitleCueLine(
                eventIndex: eventIndex,
                sourceFormat: .ass,
                sourceStyle: nil,
                sourceLayer: nil,
                startTimecode: "\(startMilliseconds)",
                endTimecode: "\(endMilliseconds)",
                startMilliseconds: startMilliseconds,
                endMilliseconds: endMilliseconds,
                content: content,
                displayX: nil,
                displayY: nil,
                displayOrder: 0
            )
        ]
    )
}

private func testCueLine(
    eventIndex: Int,
    startMilliseconds: Int,
    endMilliseconds: Int,
    content: String,
    displayOrder: Int
) -> SubtitleCueLine {
    SubtitleCueLine(
        eventIndex: eventIndex,
        sourceFormat: .ass,
        sourceStyle: nil,
        sourceLayer: nil,
        startTimecode: "\(startMilliseconds)",
        endTimecode: "\(endMilliseconds)",
        startMilliseconds: startMilliseconds,
        endMilliseconds: endMilliseconds,
        content: content,
        displayX: nil,
        displayY: nil,
        displayOrder: displayOrder
    )
}

private func createLegacyVersionOneDatabase(at url: URL) throws {
    var database: OpaquePointer?
    guard sqlite3_open_v2(url.path, &database, SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE, nil) == SQLITE_OK else {
        let message = database.map { String(cString: sqlite3_errmsg($0)) } ?? "Unknown SQLite error"
        sqlite3_close(database)
        throw SQLiteFixtureError.openFailed(message)
    }

    defer {
        sqlite3_close(database)
    }

    try executeSQLite(
        database,
        """
        CREATE TABLE subtitle_entries (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            srt_path TEXT NOT NULL,
            video_path TEXT NOT NULL,
            video_name TEXT NOT NULL,
            seq INTEGER,
            start_time TEXT NOT NULL,
            end_time TEXT NOT NULL,
            start_ms INTEGER NOT NULL,
            end_ms INTEGER NOT NULL,
            content TEXT NOT NULL
        );

        CREATE TABLE search_paths (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            type TEXT NOT NULL DEFAULT 'local',
            path TEXT NOT NULL UNIQUE,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
        );

        CREATE VIRTUAL TABLE subtitle_entries_fts USING fts5(
            content,
            subtitle_entry_id UNINDEXED
        );

        INSERT INTO subtitle_entries(
            srt_path,
            video_path,
            video_name,
            seq,
            start_time,
            end_time,
            start_ms,
            end_ms,
            content
        )
        VALUES (
            '/Media/LegacyCJK.srt',
            '/Media/LegacyCJK.mkv',
            'LegacyCJK.mkv',
            1,
            '00:00:01,000',
            '00:00:03,000',
            1000,
            3000,
            '你好世界'
        );

        INSERT INTO subtitle_entries_fts(content, subtitle_entry_id)
        VALUES ('你好世界', 1);

        INSERT INTO search_paths(type, path, created_at, updated_at)
        VALUES ('local', '/Media', '2026-05-02T00:00:00Z', '2026-05-02T00:00:00Z');

        PRAGMA user_version = 1;
        """
    )
}

private func createVersionFiveDatabaseWithUnsegmentedKanaFTS(at url: URL) throws {
    var database: OpaquePointer?
    guard sqlite3_open_v2(url.path, &database, SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE, nil) == SQLITE_OK else {
        let message = database.map { String(cString: sqlite3_errmsg($0)) } ?? "Unknown SQLite error"
        sqlite3_close(database)
        throw SQLiteFixtureError.openFailed(message)
    }

    defer {
        sqlite3_close(database)
    }

    try executeSQLite(
        database,
        """
        CREATE TABLE search_paths (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            type TEXT NOT NULL DEFAULT 'local',
            path TEXT NOT NULL UNIQUE,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
        );

        CREATE TABLE subtitle_files (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            subtitle_path TEXT NOT NULL UNIQUE,
            format TEXT NOT NULL,
            file_size INTEGER,
            modified_at REAL,
            indexed_at TEXT NOT NULL
        );

        CREATE TABLE video_files (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            path TEXT NOT NULL UNIQUE,
            video_name TEXT NOT NULL,
            file_size INTEGER,
            modified_at REAL,
            duration REAL,
            video_codec TEXT,
            audio_codec TEXT,
            native_video_candidate INTEGER,
            native_audio_candidate INTEGER,
            native_compatibility_reason TEXT,
            native_failure_reason TEXT,
            compatibility_evaluated_at TEXT
        );

        CREATE TABLE subtitle_video_matches (
            subtitle_file_id INTEGER NOT NULL,
            video_file_id INTEGER NOT NULL,
            match_method TEXT NOT NULL,
            confidence REAL NOT NULL,
            is_active INTEGER NOT NULL DEFAULT 1,
            PRIMARY KEY(subtitle_file_id, video_file_id)
        );

        CREATE TABLE subtitle_cue_groups (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            subtitle_file_id INTEGER NOT NULL,
            subtitle_path TEXT NOT NULL,
            seq INTEGER,
            start_time TEXT NOT NULL,
            end_time TEXT NOT NULL,
            start_ms INTEGER NOT NULL,
            end_ms INTEGER NOT NULL,
            search_content TEXT NOT NULL
        );

        CREATE TABLE subtitle_cue_lines (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            cue_group_id INTEGER NOT NULL,
            event_index INTEGER NOT NULL,
            source_format TEXT NOT NULL,
            source_style TEXT,
            source_layer INTEGER,
            start_time TEXT NOT NULL,
            end_time TEXT NOT NULL,
            start_ms INTEGER NOT NULL,
            end_ms INTEGER NOT NULL,
            content TEXT NOT NULL,
            display_x REAL,
            display_y REAL,
            display_order INTEGER NOT NULL
        );

        CREATE VIRTUAL TABLE subtitle_cue_groups_fts USING fts5(
            content,
            cue_group_id UNINDEXED
        );

        CREATE TABLE ass_render_segments (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            subtitle_file_id INTEGER NOT NULL,
            segment_index INTEGER NOT NULL,
            algorithm_version INTEGER NOT NULL DEFAULT 0,
            start_ms INTEGER NOT NULL,
            end_ms INTEGER NOT NULL,
            event_count INTEGER NOT NULL,
            byte_count INTEGER NOT NULL,
            script_text TEXT NOT NULL,
            UNIQUE(subtitle_file_id, segment_index)
        );

        INSERT INTO subtitle_files(subtitle_path, format, file_size, modified_at, indexed_at)
        VALUES ('/Media/Japanese.srt', 'srt', 128, 0, '2026-05-04T00:00:00Z');

        INSERT INTO video_files(path, video_name, file_size, modified_at)
        VALUES ('/Media/Japanese.mkv', 'Japanese.mkv', 0, 0);

        INSERT INTO subtitle_video_matches(subtitle_file_id, video_file_id, match_method, confidence, is_active)
        VALUES (1, 1, 'same-directory-basename', 1.0, 1);

        INSERT INTO subtitle_cue_groups(
            id,
            subtitle_file_id,
            subtitle_path,
            seq,
            start_time,
            end_time,
            start_ms,
            end_ms,
            search_content
        )
        VALUES (
            1,
            1,
            '/Media/Japanese.srt',
            1,
            '00:00:01,000',
            '00:00:03,000',
            1000,
            3000,
            '日本語ライン'
        );

        INSERT INTO subtitle_cue_lines(
            cue_group_id,
            event_index,
            source_format,
            start_time,
            end_time,
            start_ms,
            end_ms,
            content,
            display_order
        )
        VALUES (
            1,
            0,
            'srt',
            '00:00:01,000',
            '00:00:03,000',
            1000,
            3000,
            '日本語ライン',
            0
        );

        INSERT INTO subtitle_cue_groups_fts(content, cue_group_id)
        VALUES ('日本語ライン', 1);

        PRAGMA user_version = 5;
        """
    )
}

private func createVersionFourDatabaseWithASSRenderSegments(at url: URL, subtitlePath: String) throws {
    var database: OpaquePointer?
    guard sqlite3_open_v2(url.path, &database, SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE, nil) == SQLITE_OK else {
        let message = database.map { String(cString: sqlite3_errmsg($0)) } ?? "Unknown SQLite error"
        sqlite3_close(database)
        throw SQLiteFixtureError.openFailed(message)
    }

    defer {
        sqlite3_close(database)
    }

    try executeSQLite(
        database,
        """
        CREATE TABLE subtitle_files (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            subtitle_path TEXT NOT NULL UNIQUE,
            format TEXT NOT NULL,
            file_size INTEGER,
            modified_at REAL,
            indexed_at TEXT NOT NULL
        );

        CREATE TABLE ass_render_segments (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            subtitle_file_id INTEGER NOT NULL,
            segment_index INTEGER NOT NULL,
            start_ms INTEGER NOT NULL,
            end_ms INTEGER NOT NULL,
            event_count INTEGER NOT NULL,
            byte_count INTEGER NOT NULL,
            script_text TEXT NOT NULL,
            UNIQUE(subtitle_file_id, segment_index)
        );

        INSERT INTO subtitle_files(subtitle_path, format, file_size, modified_at, indexed_at)
        VALUES ('\(subtitlePath)', 'ass', 4096, 0, '2026-05-03T00:00:00Z');

        INSERT INTO ass_render_segments(
            subtitle_file_id,
            segment_index,
            start_ms,
            end_ms,
            event_count,
            byte_count,
            script_text
        )
        VALUES (1, 0, 0, 30000, 1, 32, '[Script Info]\n[Events]\n');

        PRAGMA user_version = 4;
        """
    )
}

private func createVersionTenDatabaseWithMixedCueGroupLineCounts(at url: URL) throws {
    var database: OpaquePointer?
    guard sqlite3_open_v2(url.path, &database, SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE, nil) == SQLITE_OK else {
        let message = database.map { String(cString: sqlite3_errmsg($0)) } ?? "Unknown SQLite error"
        sqlite3_close(database)
        throw SQLiteFixtureError.openFailed(message)
    }

    defer {
        sqlite3_close(database)
    }

    try executeSQLite(
        database,
        """
        CREATE TABLE subtitle_files (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            subtitle_path TEXT NOT NULL UNIQUE,
            format TEXT NOT NULL,
            file_size INTEGER,
            modified_at REAL,
            indexed_at TEXT NOT NULL
        );

        CREATE TABLE subtitle_cue_groups (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            subtitle_file_id INTEGER NOT NULL,
            subtitle_path TEXT NOT NULL,
            seq INTEGER,
            start_time TEXT NOT NULL,
            end_time TEXT NOT NULL,
            start_ms INTEGER NOT NULL,
            end_ms INTEGER NOT NULL,
            search_content TEXT NOT NULL
        );

        CREATE TABLE subtitle_cue_lines (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            cue_group_id INTEGER NOT NULL,
            event_index INTEGER NOT NULL,
            source_format TEXT NOT NULL,
            source_style TEXT,
            source_layer INTEGER,
            start_time TEXT NOT NULL,
            end_time TEXT NOT NULL,
            start_ms INTEGER NOT NULL,
            end_ms INTEGER NOT NULL,
            content TEXT NOT NULL,
            display_x REAL,
            display_y REAL,
            display_order INTEGER NOT NULL
        );

        INSERT INTO subtitle_files(subtitle_path, format, file_size, modified_at, indexed_at)
        VALUES ('/Media/Sample.ass', 'ass', 1024, 0, '2026-05-04T00:00:00Z');

        INSERT INTO subtitle_cue_groups(id, subtitle_file_id, subtitle_path, seq, start_time, end_time, start_ms, end_ms, search_content)
        VALUES (1, 1, '/Media/Sample.ass', NULL, '0', '1000', 0, 1000, 'single line');

        INSERT INTO subtitle_cue_groups(id, subtitle_file_id, subtitle_path, seq, start_time, end_time, start_ms, end_ms, search_content)
        VALUES (2, 1, '/Media/Sample.ass', NULL, '1000', '2000', 1000, 2000, 'left\nright');

        INSERT INTO subtitle_cue_groups(id, subtitle_file_id, subtitle_path, seq, start_time, end_time, start_ms, end_ms, search_content)
        VALUES (3, 1, '/Media/Sample.ass', NULL, '2000', '3000', 2000, 3000, 'top\nmid\nbot');

        INSERT INTO subtitle_cue_lines(cue_group_id, event_index, source_format, start_time, end_time, start_ms, end_ms, content, display_order)
        VALUES (1, 0, 'ass', '0', '1000', 0, 1000, 'single line', 0);

        INSERT INTO subtitle_cue_lines(cue_group_id, event_index, source_format, start_time, end_time, start_ms, end_ms, content, display_order)
        VALUES (2, 0, 'ass', '1000', '2000', 1000, 2000, 'left', 0);

        INSERT INTO subtitle_cue_lines(cue_group_id, event_index, source_format, start_time, end_time, start_ms, end_ms, content, display_order)
        VALUES (2, 1, 'ass', '1000', '2000', 1000, 2000, 'right', 1);

        INSERT INTO subtitle_cue_lines(cue_group_id, event_index, source_format, start_time, end_time, start_ms, end_ms, content, display_order)
        VALUES (3, 0, 'ass', '2000', '3000', 2000, 3000, 'top', 0);

        INSERT INTO subtitle_cue_lines(cue_group_id, event_index, source_format, start_time, end_time, start_ms, end_ms, content, display_order)
        VALUES (3, 1, 'ass', '2000', '3000', 2000, 3000, 'mid', 1);

        INSERT INTO subtitle_cue_lines(cue_group_id, event_index, source_format, start_time, end_time, start_ms, end_ms, content, display_order)
        VALUES (3, 2, 'ass', '2000', '3000', 2000, 3000, 'bot', 2);

        PRAGMA user_version = 10;
        """
    )
}

private func readCueGroupLineCounts(at url: URL) throws -> [Int64: Int] {
    var database: OpaquePointer?
    guard sqlite3_open_v2(url.path, &database, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
        let message = database.map { String(cString: sqlite3_errmsg($0)) } ?? "Unknown SQLite error"
        sqlite3_close(database)
        throw SQLiteFixtureError.openFailed(message)
    }

    defer {
        sqlite3_close(database)
    }

    var statement: OpaquePointer?
    guard sqlite3_prepare_v2(database, "SELECT id, line_count FROM subtitle_cue_groups;", -1, &statement, nil) == SQLITE_OK,
          let statement
    else {
        let message = String(cString: sqlite3_errmsg(database))
        throw SQLiteFixtureError.executeFailed(message)
    }

    defer {
        sqlite3_finalize(statement)
    }

    var result: [Int64: Int] = [:]
    while sqlite3_step(statement) == SQLITE_ROW {
        let id = sqlite3_column_int64(statement, 0)
        let count = Int(sqlite3_column_int64(statement, 1))
        result[id] = count
    }
    return result
}

private struct SearchOrderRow {
    let subtitlePath: String
    let displayTitle: String
    let folderOrder: Int
    let fileOrder: Int
}

private func readSearchOrderRows(at url: URL) throws -> [SearchOrderRow] {
    var database: OpaquePointer?
    guard sqlite3_open_v2(url.path, &database, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
        let message = database.map { String(cString: sqlite3_errmsg($0)) } ?? "Unknown SQLite error"
        sqlite3_close(database)
        throw SQLiteFixtureError.openFailed(message)
    }

    defer {
        sqlite3_close(database)
    }

    var statement: OpaquePointer?
    guard sqlite3_prepare_v2(
        database,
        """
        SELECT subtitle_path, display_title, folder_order, file_order
        FROM subtitle_search_order_rows
        ORDER BY folder_order ASC, file_order ASC, subtitle_path ASC;
        """,
        -1,
        &statement,
        nil
    ) == SQLITE_OK,
          let statement
    else {
        let message = String(cString: sqlite3_errmsg(database))
        throw SQLiteFixtureError.executeFailed(message)
    }

    defer {
        sqlite3_finalize(statement)
    }

    var result: [SearchOrderRow] = []
    while sqlite3_step(statement) == SQLITE_ROW {
        result.append(
            SearchOrderRow(
                subtitlePath: String(cString: sqlite3_column_text(statement, 0)),
                displayTitle: String(cString: sqlite3_column_text(statement, 1)),
                folderOrder: Int(sqlite3_column_int64(statement, 2)),
                fileOrder: Int(sqlite3_column_int64(statement, 3))
            )
        )
    }
    return result
}

private func executeSQLite(at url: URL, _ sql: String) throws {
    var database: OpaquePointer?
    guard sqlite3_open_v2(url.path, &database, SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE, nil) == SQLITE_OK else {
        let message = database.map { String(cString: sqlite3_errmsg($0)) } ?? "Unknown SQLite error"
        sqlite3_close(database)
        throw SQLiteFixtureError.openFailed(message)
    }

    defer {
        sqlite3_close(database)
    }

    try executeSQLite(database, sql)
}

private func executeSQLite(_ database: OpaquePointer?, _ sql: String) throws {
    var errorMessage: UnsafeMutablePointer<CChar>?
    guard sqlite3_exec(database, sql, nil, nil, &errorMessage) == SQLITE_OK else {
        let message = errorMessage.map { String(cString: $0) } ?? "Unknown SQLite error"
        sqlite3_free(errorMessage)
        throw SQLiteFixtureError.executeFailed(message)
    }
}

private func databaseTestEntry(text: String) -> SubtitleEntry {
    SubtitleEntry(
        sequenceNumber: 1,
        startTimecode: "00:00:01,000",
        endTimecode: "00:00:02,000",
        startMilliseconds: 1_000,
        endMilliseconds: 2_000,
        text: text
    )
}

private func languageFilterTestEntry(sequenceNumber: Int, text: String) -> SubtitleEntry {
    let startMilliseconds = sequenceNumber * 1_000
    let endMilliseconds = startMilliseconds + 500
    return SubtitleEntry(
        sequenceNumber: sequenceNumber,
        startTimecode: String(format: "00:00:%02d,000", sequenceNumber),
        endTimecode: String(format: "00:00:%02d,500", sequenceNumber),
        startMilliseconds: startMilliseconds,
        endMilliseconds: endMilliseconds,
        text: text
    )
}

private func languageFilterASSCueGroup(
    startMilliseconds: Int,
    lines: [(style: String?, content: String)]
) -> SubtitleCueGroup {
    let endMilliseconds = startMilliseconds + 1_000
    let cueLines = lines.enumerated().map { index, line in
        SubtitleCueLine(
            eventIndex: index,
            sourceFormat: .ass,
            sourceStyle: line.style,
            sourceLayer: 0,
            startTimecode: "\(startMilliseconds)",
            endTimecode: "\(endMilliseconds)",
            startMilliseconds: startMilliseconds,
            endMilliseconds: endMilliseconds,
            content: line.content,
            displayX: nil,
            displayY: nil,
            displayOrder: index
        )
    }
    return SubtitleCueGroup(
        sequenceNumber: nil,
        startTimecode: "\(startMilliseconds)",
        endTimecode: "\(endMilliseconds)",
        startMilliseconds: startMilliseconds,
        endMilliseconds: endMilliseconds,
        searchContent: lines.map(\.content).joined(separator: "\n"),
        cueLines: cueLines
    )
}

private final class SearchDiagnosticRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var recordedEvents: [SubtitleSearchDiagnosticEvent] = []

    var events: [SubtitleSearchDiagnosticEvent] {
        lock.lock()
        defer {
            lock.unlock()
        }
        return recordedEvents
    }

    func record(_ event: SubtitleSearchDiagnosticEvent) {
        lock.lock()
        recordedEvents.append(event)
        lock.unlock()
    }
}

private enum SQLiteFixtureError: Error {
    case openFailed(String)
    case executeFailed(String)
}
