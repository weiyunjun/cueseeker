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
func visibleSearchReadersRejectPreCancelledTasks() async throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let searchTask = Task.detached { () throws -> SubtitleSearchPage in
        let database = try SubtitleDatabase(path: databaseURL)
        try database.migrate()
        withUnsafeCurrentTask { task in
            task?.cancel()
        }
        return try database.searchVisiblePage(
            "cue",
            limit: 1,
            cursor: .start
        )
    }
    do {
        _ = try await searchTask.value
        Issue.record("Expected cancelled visible search to stop")
    } catch is CancellationError {
        // Expected.
    }

    let allCueTask = Task.detached { () throws -> SubtitleSearchPage in
        let database = try SubtitleDatabase(path: databaseURL)
        withUnsafeCurrentTask { task in
            task?.cancel()
        }
        return try database.allCuesVisiblePage(limit: 1, cursor: .start)
    }
    do {
        _ = try await allCueTask.value
        Issue.record("Expected cancelled all-cue search to stop")
    } catch is CancellationError {
        // Expected.
    }
}

@Test
func allCuesVisiblePageReturnsDefaultOrderAndSpeakers() throws {
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
    let summarySubtitleFile = URL(fileURLWithPath: "/Media/ZZSummary.srt")
    try database.replaceEntries(
        subtitleFile: summarySubtitleFile,
        videoFile: URL(fileURLWithPath: "/Media/ZZSummary.mkv"),
        entries: [
            SubtitleEntry(
                sequenceNumber: 1,
                startTimecode: "00:00:03,000",
                endTimecode: "00:00:03,500",
                startMilliseconds: 3_000,
                endMilliseconds: 3_500,
                text: "third file cue"
            )
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

    let page = try database.allCuesVisiblePage(limit: 10, cursor: .start)

    #expect(page.totalCount == 3)
    #expect(page.results.map(\.content) == ["first cue", "second cue", "third file cue"])
    #expect(page.results.map(\.timeRange) == [
        "00:01 - 00:01",
        "00:02 - 00:02",
        "00:03 - 00:03",
    ])
    #expect(page.results[0].speakers == [])
    #expect(page.results[1].speakers == ["高松灯"])
    #expect(page.results[2].speakers == [])
    #expect(Dictionary(uniqueKeysWithValues: page.fileSummaries.map {
        ($0.subtitlePath, $0.matchCount)
    }) == [
        subtitleFile.path: 2,
        summarySubtitleFile.path: 1,
    ])

    let speakerPage = try database.allCuesVisiblePage(
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
func allCuesVisiblePageCountsFiltersAndPaginatesSiblingCuesIndependently() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    let subtitleFile = URL(fileURLWithPath: "/Media/AllCues.ass")
    let videoFile = URL(fileURLWithPath: "/Media/AllCues.mkv")
    let cueGroup = SubtitleCueGroup(
        sequenceNumber: nil,
        startTimecode: "0:00:01.00",
        endTimecode: "0:00:03.00",
        startMilliseconds: 1_000,
        endMilliseconds: 3_000,
        searchContent: "中文上方\n日本語の下側\n二行目",
        cueLines: [
            testCueLine(
                eventIndex: 10,
                startMilliseconds: 1_000,
                endMilliseconds: 3_000,
                content: "中文上方",
                displayOrder: 0,
                sourceStyle: "CN"
            ),
            testCueLine(
                eventIndex: 11,
                startMilliseconds: 1_000,
                endMilliseconds: 3_000,
                content: "日本語の下側\n二行目",
                displayOrder: 1,
                sourceStyle: "JP"
            ),
        ]
    )
    let analysis = SubtitleLanguageAnalysis(
        format: .ass,
        fileDetection: nil,
        styleDetections: [
            "CN": SubtitleLanguageDetectionResult(
                languages: [.simplifiedChinese],
                confidence: 1,
                segmentCount: 1,
                effectiveCharacterCount: 4,
                distribution: [SubtitleLanguageDistribution(language: .simplifiedChinese, share: 1)]
            ),
            "JP": SubtitleLanguageDetectionResult(
                languages: [.japanese],
                confidence: 1,
                segmentCount: 1,
                effectiveCharacterCount: 9,
                distribution: [SubtitleLanguageDistribution(language: .japanese, share: 1)]
            ),
        ],
        cueGroupLanguages: [[.simplifiedChinese, .japanese]]
    )
    try database.replaceCueGroups(
        subtitleFile: subtitleFile,
        videoFile: videoFile,
        format: .ass,
        cueGroups: [cueGroup],
        languageAnalysis: analysis
    )
    let cueRecords = try database.cueLineRecords(forSubtitleFile: subtitleFile)
    try database.replaceCueLineSpeakers(
        forSubtitleFile: subtitleFile,
        assignments: [
            SubtitleCueLineSpeakerAssignment(cueLineID: cueRecords[0].id, speakers: ["上方角色"]),
            SubtitleCueLineSpeakerAssignment(cueLineID: cueRecords[1].id, speakers: ["下方角色"]),
        ]
    )

    let firstPage = try database.allCuesVisiblePage(limit: 1, cursor: .start)
    #expect(firstPage.totalCount == 2)
    #expect(firstPage.results.map(\.entryID) == [cueRecords[0].id])
    #expect(firstPage.results[0].cueLines == ["中文上方"])
    #expect(firstPage.results[0].cueGroupLines == ["中文上方", "日本語の下側\n二行目"])
    #expect(firstPage.results[0].primaryGroupIndex == 0)
    #expect(firstPage.results[0].languages == [.simplifiedChinese])
    #expect(firstPage.results[0].speakers == ["上方角色"])
    #expect(firstPage.nextCursor == SubtitleSearchCursor(offset: 1))

    let secondPage = try database.allCuesVisiblePage(
        limit: 1,
        cursor: firstPage.nextCursor
    )
    #expect(secondPage.results.map(\.entryID) == [cueRecords[1].id])
    #expect(secondPage.results[0].content == "日本語の下側\n二行目")
    #expect(secondPage.results[0].cueLines == ["日本語の下側\n二行目"])
    #expect(secondPage.results[0].primaryGroupIndex == 1)
    #expect(secondPage.results[0].languages == [.japanese])
    #expect(secondPage.results[0].speakers == ["下方角色"])
    #expect(secondPage.results[0].cueGroupID == firstPage.results[0].cueGroupID)

    let filteredPage = try database.allCuesVisiblePage(
        limit: 10,
        cursor: .start,
        filterSet: SubtitleSearchFilterSet(
            rules: [
                SubtitleSearchFilterRule(field: .speaker, operatorID: .contains, value: "下方角色"),
                SubtitleSearchFilterRule(
                    join: .and,
                    field: .language,
                    operatorID: .contains,
                    value: "ja"
                ),
            ]
        )
    )
    #expect(filteredPage.totalCount == 1)
    #expect(filteredPage.results.map(\.entryID) == [cueRecords[1].id])
    #expect(filteredPage.fileSummaries.map(\.matchCount) == [1])
}

@Test
func cueContextSearchPageAnchorsFirstPageWithoutDroppingEarlierRows() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    let contextSubtitleFile = URL(fileURLWithPath: "/Media/ContextRank.srt")
    let contextVideoFile = URL(fileURLWithPath: "/Media/ContextRank.mkv")
    let otherSubtitleFile = URL(fileURLWithPath: "/Media/OtherRank.srt")
    let otherVideoFile = URL(fileURLWithPath: "/Media/OtherRank.mkv")
    try database.replaceEntries(
        subtitleFile: contextSubtitleFile,
        videoFile: contextVideoFile,
        entries: (1...6).map { index in
            SubtitleEntry(
                sequenceNumber: index,
                startTimecode: String(format: "00:00:%02d,000", index),
                endTimecode: String(format: "00:00:%02d,500", index),
                startMilliseconds: index * 1_000,
                endMilliseconds: index * 1_000 + 500,
                text: "context cue \(index)"
            )
        }
    )
    try database.replaceEntries(
        subtitleFile: otherSubtitleFile,
        videoFile: otherVideoFile,
        entries: [
            SubtitleEntry(
                sequenceNumber: 1,
                startTimecode: "00:00:01,000",
                endTimecode: "00:00:01,500",
                startMilliseconds: 1_000,
                endMilliseconds: 1_500,
                text: "other cue"
            ),
        ]
    )

    let contextEntries = try database.entries(forSubtitleFile: contextSubtitleFile)
    let thirdContextEntry = try #require(contextEntries.first { $0.content == "context cue 3" })
    let contextCues = try database.cueLineRecords(forSubtitleFile: contextSubtitleFile)
    let firstContextCue = try #require(contextCues.first)
    let thirdContextCue = try #require(contextCues.first { $0.line.content == "context cue 3" })
    let lastContextCue = try #require(contextCues.first { $0.line.content == "context cue 6" })

    #expect(
        try database.firstCueID(forSubtitleFile: contextSubtitleFile) == firstContextCue.id
    )
    #expect(
        try database.cueID(
            forSubtitlePath: contextSubtitleFile.path,
            cueIdentity: SubtitleCueIdentity(
                eventIndex: thirdContextCue.line.eventIndex,
                startMilliseconds: thirdContextEntry.startMilliseconds,
                endMilliseconds: thirdContextEntry.endMilliseconds
            )
        ) == thirdContextCue.id
    )

    let targetFirstPage = try #require(
        try database.cueContextSearchPage(
            subtitlePath: contextSubtitleFile.path,
            targetCueID: thirdContextCue.id,
            limit: 3,
            anchorsInitialPage: true
        )
    )
    #expect(targetFirstPage.totalCount == 6)
    #expect(targetFirstPage.appliedCursor == SubtitleSearchCursor(offset: 2))
    #expect(targetFirstPage.results.map(\.content) == [
        "context cue 3",
        "context cue 4",
        "context cue 5",
    ])
    #expect(targetFirstPage.results.map(\.searchRank) == [2, 3, 4])
    #expect(targetFirstPage.nextCursor == SubtitleSearchCursor(offset: 5))

    let precedingPage = try #require(
        try database.cueContextSearchPage(
            subtitlePath: contextSubtitleFile.path,
            targetCueID: thirdContextCue.id,
            limit: 2,
            cursor: SubtitleSearchCursor(offset: 0)
        )
    )
    #expect(precedingPage.totalCount == 6)
    #expect(precedingPage.results.map(\.content) == [
        "context cue 1",
        "context cue 2",
    ])
    #expect(precedingPage.results.map(\.searchRank) == [0, 1])

    let followingPage = try #require(
        try database.cueContextSearchPage(
            subtitlePath: contextSubtitleFile.path,
            targetCueID: thirdContextCue.id,
            limit: 3,
            cursor: SubtitleSearchCursor(offset: 5)
        )
    )
    #expect(followingPage.totalCount == 6)
    #expect(followingPage.results.map(\.content) == ["context cue 6"])
    #expect(followingPage.results.map(\.searchRank) == [5])

    let tailPage = try #require(
        try database.cueContextSearchPage(
            subtitlePath: contextSubtitleFile.path,
            targetCueID: lastContextCue.id,
            limit: 3,
            anchorsInitialPage: true
        )
    )
    #expect(tailPage.totalCount == 6)
    #expect(tailPage.appliedCursor == SubtitleSearchCursor(offset: 3))
    #expect(tailPage.results.map(\.content) == [
        "context cue 4",
        "context cue 5",
        "context cue 6",
    ])
    #expect(tailPage.results.map(\.searchRank) == [3, 4, 5])

    let oversizedAnchorPage = try #require(
        try database.cueContextSearchPage(
            subtitlePath: contextSubtitleFile.path,
            targetCueID: lastContextCue.id,
            limit: 2,
            anchorWindowSize: 5,
            anchorsInitialPage: true
        )
    )
    #expect(oversizedAnchorPage.appliedCursor == SubtitleSearchCursor(offset: 4))
    #expect(oversizedAnchorPage.results.map(\.content) == [
        "context cue 5",
        "context cue 6",
    ])
    #expect(oversizedAnchorPage.results.contains { $0.entryID == lastContextCue.id })
}

@Test
func cueContextSearchPageAnchorsExactSiblingCueInStableSourceOrder() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    let subtitleFile = URL(fileURLWithPath: "/Media/ContextSiblings.ass")
    let videoFile = URL(fileURLWithPath: "/Media/ContextSiblings.mkv")
    let firstGroup = SubtitleCueGroup(
        sequenceNumber: nil,
        startTimecode: "0:00:01.00",
        endTimecode: "0:00:03.00",
        startMilliseconds: 1_000,
        endMilliseconds: 3_000,
        searchContent: "upper sibling\nlower sibling",
        cueLines: [
            testCueLine(
                eventIndex: 10,
                startMilliseconds: 1_000,
                endMilliseconds: 3_000,
                content: "upper sibling",
                displayOrder: 0
            ),
            testCueLine(
                eventIndex: 11,
                startMilliseconds: 1_000,
                endMilliseconds: 3_000,
                content: "lower sibling",
                displayOrder: 1
            ),
        ]
    )
    let secondGroup = SubtitleCueGroup(
        sequenceNumber: nil,
        startTimecode: "0:00:04.00",
        endTimecode: "0:00:05.00",
        startMilliseconds: 4_000,
        endMilliseconds: 5_000,
        searchContent: "following cue",
        cueLines: [
            testCueLine(
                eventIndex: 12,
                startMilliseconds: 4_000,
                endMilliseconds: 5_000,
                content: "following cue",
                displayOrder: 0
            )
        ]
    )
    try database.replaceCueGroups(
        subtitleFile: subtitleFile,
        videoFile: videoFile,
        format: .ass,
        cueGroups: [firstGroup, secondGroup]
    )
    let cueRecords = try database.cueLineRecords(forSubtitleFile: subtitleFile)
    let lowerSibling = try #require(cueRecords.first { $0.line.eventIndex == 11 })

    let page = try #require(try database.cueContextSearchPage(
        subtitlePath: subtitleFile.path,
        targetCueID: lowerSibling.id,
        limit: 2,
        anchorsInitialPage: true
    ))

    #expect(page.totalCount == 3)
    #expect(page.appliedCursor == SubtitleSearchCursor(offset: 1))
    #expect(page.results.map(\.entryID) == [lowerSibling.id, cueRecords[2].id])
    #expect(page.results.map(\.content) == ["lower sibling", "following cue"])
    #expect(page.results[0].cueLines == ["lower sibling"])
    #expect(page.results[0].cueGroupLines == ["upper sibling", "lower sibling"])
    #expect(page.results[0].primaryGroupIndex == 1)
    #expect(page.results[0].cueGroupID == cueRecords[0].cueGroupID)
    #expect(page.results.map(\.searchRank) == [1, 2])

    let precedingPage = try #require(try database.cueContextSearchPage(
        subtitlePath: subtitleFile.path,
        targetCueID: lowerSibling.id,
        limit: 1,
        cursor: .start
    ))
    #expect(precedingPage.results.map(\.entryID) == [cueRecords[0].id])
    #expect(precedingPage.results.map(\.searchRank) == [0])
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
func preservesCueLineSpeakersWhenReplacingCueGroups() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    let subtitleFile = URL(fileURLWithPath: "/Media/SpeakerPreserve.srt")
    let videoFile = URL(fileURLWithPath: "/Media/SpeakerPreserve.mkv")
    let entries = [
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
    try database.replaceEntries(subtitleFile: subtitleFile, videoFile: videoFile, entries: entries)

    let initialCueLines = try database.cueLineRecords(forSubtitleFile: subtitleFile)
    let initialSecondCueLine = try #require(initialCueLines.first { $0.line.content == "second cue" })
    try database.replaceCueLineSpeakers(
        forSubtitleFile: subtitleFile,
        assignments: [
            SubtitleCueLineSpeakerAssignment(cueLineID: initialSecondCueLine.id, speakers: ["高松灯"])
        ]
    )

    try database.replaceEntries(subtitleFile: subtitleFile, videoFile: videoFile, entries: entries)

    let rebuiltCueLines = try database.cueLineRecords(forSubtitleFile: subtitleFile)
    let rebuiltSecondCueLine = try #require(rebuiltCueLines.first { $0.line.content == "second cue" })
    #expect(rebuiltSecondCueLine.id != initialSecondCueLine.id)
    #expect(try database.speakersByCueLineID(forSubtitleFile: subtitleFile) == [
        rebuiltSecondCueLine.id: ["高松灯"]
    ])
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
func searchFiltersByLibraryWatchState() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    let unwatchedSubtitleFile = URL(fileURLWithPath: "/Media/Unwatched.srt")
    let unwatchedVideoFile = URL(fileURLWithPath: "/Media/Unwatched.mkv")
    let watchingSubtitleFile = URL(fileURLWithPath: "/Media/Watching.srt")
    let watchingVideoFile = URL(fileURLWithPath: "/Media/Watching.mkv")
    let finishedSubtitleFile = URL(fileURLWithPath: "/Media/Finished.srt")
    let finishedVideoFile = URL(fileURLWithPath: "/Media/Finished.mkv")
    func entry(_ text: String) -> SubtitleEntry {
        SubtitleEntry(
            sequenceNumber: 1,
            startTimecode: "00:00:01,000",
            endTimecode: "00:00:03,000",
            startMilliseconds: 1_000,
            endMilliseconds: 3_000,
            text: text
        )
    }

    try database.replaceEntries(
        subtitleFile: unwatchedSubtitleFile,
        videoFile: unwatchedVideoFile,
        entries: [entry("scope shared unwatched")]
    )
    try database.replaceEntries(
        subtitleFile: watchingSubtitleFile,
        videoFile: watchingVideoFile,
        entries: [entry("scope shared watching")]
    )
    try database.replaceEntries(
        subtitleFile: finishedSubtitleFile,
        videoFile: finishedVideoFile,
        entries: [entry("scope shared finished")]
    )
    try database.setLibraryWatchState(
        videoFile: watchingVideoFile,
        duration: nil,
        state: .watching
    )
    try database.setLibraryWatchState(
        videoFile: finishedVideoFile,
        duration: nil,
        state: .finished
    )

    let allResults = try database.search("scope shared", watchStateFilter: .all)
    #expect(allResults.map(\.videoName).sorted() == [
        "Finished.mkv",
        "Unwatched.mkv",
        "Watching.mkv"
    ])

    let onlyFinishedResults = try database.search("scope shared", watchStateFilter: .onlyFinished)
    #expect(onlyFinishedResults.map(\.videoName) == ["Finished.mkv"])

    let watchingAndFinishedPage = try database.searchVisiblePage(
        "scope shared",
        limit: 10,
        cursor: .start,
        watchStateFilter: .watchingAndFinished
    )
    #expect(watchingAndFinishedPage.results.map(\.videoName).sorted() == [
        "Finished.mkv",
        "Watching.mkv"
    ])
    #expect(watchingAndFinishedPage.totalCount == 2)
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
    #expect(japaneseResults.first?.cueLines == ["今日は大丈夫です"])
    #expect(japaneseResults.first?.cueGroupLines == [
        "只是中文上下文",
        "今日は大丈夫です"
    ])
    #expect(japaneseResults.first?.languages == [.japanese])
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
func searchExactPageCanReturnOnlyCueIDsForCompletion() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    try database.replaceEntries(
        subtitleFile: URL(fileURLWithPath: "/Media/IDCompletion.srt"),
        videoFile: URL(fileURLWithPath: "/Media/IDCompletion.mkv"),
        entries: (0..<3).map { index in
            SubtitleEntry(
                sequenceNumber: index + 1,
                startTimecode: String(format: "00:00:%02d,000", index),
                endTimecode: String(format: "00:00:%02d,500", index),
                startMilliseconds: index * 1_000,
                endMilliseconds: index * 1_000 + 500,
                text: "Shared id completion \(index)"
            )
        }
    )

    let page = try database.searchPage("shared", limit: 0)

    #expect(page.results.isEmpty)
    #expect(page.renderableResults.isEmpty)
    #expect(page.totalCount == 3)
    #expect(page.cueIDs.count == 3)
    #expect(page.nextCursor == nil)
}

@Test
func searchFilterSetAppliesToExactAndVisiblePagesWithoutCachedIDIndex() throws {
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

    #expect(database.searchResultIDIndexWindow(
        "shared",
        limit: 1,
        cursor: SubtitleSearchCursor(offset: 2),
        filterSet: filterSet,
        minimumKnownResultCount: 3
    ) == nil)
    let visiblePage = try database.searchVisiblePage(
        "shared",
        limit: 1,
        cursor: SubtitleSearchCursor(offset: 2),
        filterSet: filterSet
    )

    #expect(visiblePage.totalCount == 3)
    #expect(visiblePage.nextCursor == nil)
    #expect(visiblePage.results.map(\.content) == ["Shared filtered keep 4"])
    #expect(visiblePage.results.map(\.searchRank) == [2])
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
func searchExactPageLeavesResultIDIndexWindowUnavailable() throws {
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

    #expect(database.searchResultIDIndexWindow(
        "shared",
        limit: 2,
        cursor: SubtitleSearchCursor(offset: 4),
        minimumKnownResultCount: 6
    ) == nil)

    let visiblePage = try database.searchVisiblePage(
        "shared",
        limit: 2,
        cursor: SubtitleSearchCursor(offset: 4)
    )

    #expect(visiblePage.pageMode == .visibleWindow)
    #expect(visiblePage.countState == .exactProgress)
    #expect(visiblePage.totalCount == 6)
    #expect(visiblePage.nextCursor?.offset == 6)
    #expect(visiblePage.orderSource == "ftsRowid")
    #expect(visiblePage.materializedOrderRows == 6)
    #expect(visiblePage.results.map(\.content) == [
        "Shared indexed window 4",
        "Shared indexed window 5",
    ])
    #expect(visiblePage.results.map(\.searchRank) == [4, 5])
}

@Test
func searchNavigationSnapshotFromResultIDIndexStaysUnavailableWhenCacheDisabled() throws {
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
    let stillMissingSnapshot = try database.searchNavigationSnapshotFromResultIDIndex(
        "shared",
        anchor: SearchNavigationAnchor(
            selectedEntryID: 5,
            selectedSearchRank: 4,
            videoPath: videoFile.path,
            subtitlePath: subtitleFile.path,
            currentMilliseconds: 4_000
        ),
        radius: 1
    )
    #expect(stillMissingSnapshot == nil)

    let snapshot = try database.searchNavigationSnapshot(
        "shared",
        under: nil,
        anchor: SearchNavigationAnchor(
            selectedEntryID: 2,
            selectedSearchRank: 1,
            videoPath: videoFile.path,
            subtitlePath: subtitleFile.path,
            currentMilliseconds: 4_100
        ),
        radius: 1
    )

    #expect(snapshot.currentIndex == 4)
    #expect(snapshot.previous?.content == "Shared indexed navigation 3")
    #expect(snapshot.current?.content == "Shared indexed navigation 4")
    #expect(snapshot.next?.content == "Shared indexed navigation 5")
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
    #expect(progress.allSatisfy { $0.results.count == $0.knownResultCount })
    #expect(progress.allSatisfy { $0.cueIDs.count == $0.knownResultCount })
    #expect(progress.last?.knownResultCount == 5_000)
    #expect(progress.last?.knownFileCount == 1)
    #expect(progress.last?.fileSummaries.map(\.matchCount) == [5_000])
    #expect(progress.last?.results.first?.content == "Progress count stream line 0")
    #expect(progress.last?.results.last?.content == "Progress count stream line 4999")
    #expect(Array(progress.last?.results.suffix(3).map(\.searchRank) ?? []) == [4_997, 4_998, 4_999])
    #expect(page.countState == .exact)
    #expect(page.results.count == 50)
    #expect(page.renderableResults.count == 5_100)
    #expect(page.renderableResults.count == page.cueIDs.count)
    #expect(page.totalCount == 5_100)
    #expect(page.knownResultCount == 5_100)
    #expect(page.fileSummaries.map(\.matchCount) == [5_100])
    #expect(page.renderableResults.last?.content == "Progress count stream line 5099")

    let boundedCollector = SearchProgressCollector()
    let boundedPage = try database.searchPage(
        "progress",
        limit: 0,
        cursor: .start,
        progress: { snapshot in
            boundedCollector.append(snapshot)
        },
        progressResultLimit: 32
    )
    let boundedProgress = boundedCollector.values()
    let finalBoundedProgress = try #require(boundedProgress.last)

    #expect(!boundedProgress.isEmpty)
    #expect(boundedProgress.allSatisfy { $0.results.count <= 32 })
    #expect(boundedProgress.allSatisfy {
        $0.cueIDs.count == $0.knownResultCount
    })
    #expect(boundedPage.results.isEmpty)
    #expect(boundedPage.renderableResults.count == 32)
    #expect(boundedPage.renderableResults.map(\.searchRank) == Array(0..<32))
    #expect(boundedPage.cueIDs.count == 5_100)
    #expect(boundedPage.totalCount == 5_100)
    #expect(finalBoundedProgress.results.count == 32)
    #expect(finalBoundedProgress.results.map(\.searchRank) == Array(0..<32))
    #expect(finalBoundedProgress.cueIDs == Array(
        boundedPage.cueIDs.prefix(finalBoundedProgress.knownResultCount)
    ))
}

@Test
func searchPageDoesNotCacheRepeatedQueries() throws {
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
    #expect(!firstDiagnostics.events.contains { $0.name.hasPrefix("search_cache_") })
    #expect(!secondDiagnostics.events.contains { $0.name.hasPrefix("search_cache_") })
    #expect(firstDiagnostics.events.contains { $0.name == "fts_batch" })
    #expect(secondDiagnostics.events.contains { $0.name == "fts_batch" })
    #expect(stats.entries == 0)
    #expect(stats.hits == 0)
    #expect(stats.misses == 0)
    #expect(stats.stores == 0)
    #expect(stats.invalidations == 0)
}

@Test
func searchPageSeesIndexedContentChangesWithoutCacheInvalidationState() throws {
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
    #expect(database.searchResultCacheStats().hits == 0)

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
    #expect(!diagnostics.events.contains { $0.name.hasPrefix("search_cache_") })
    #expect(stats.entries == 0)
    #expect(stats.hits == 0)
    #expect(stats.misses == 0)
    #expect(stats.stores == 0)
    #expect(stats.invalidations == 0)
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
func cueOccurrenceCountMatchesSearchPageExactTotals() throws {
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
    #expect(try database.cueOccurrenceCount(for: " 一級 ") == allCJKPage.totalCount)
    #expect(allCJKPage.totalCount == 3)

    let scopedCJKPage = try database.searchPage("一級", limit: 10, under: [mediaFolder])
    #expect(try database.cueOccurrenceCount(for: "一級", under: [mediaFolder]) == scopedCJKPage.totalCount)
    #expect(scopedCJKPage.totalCount == 2)

    let phrasePage = try database.searchPage("一級試験", limit: 10)
    #expect(try database.cueOccurrenceCount(for: "一級試験") == phrasePage.totalCount)
    #expect(phrasePage.totalCount == 2)

    let latinPage = try database.searchPage("mag", limit: 10)
    #expect(try database.cueOccurrenceCount(for: "mag") == latinPage.totalCount)
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
func libraryCoverEligibleVideosFollowSubtitleMatchesAndLibraryOrder() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    let episode2Video = URL(fileURLWithPath: "/Media/Show 2/Episode 2.mkv")
    let episode11Video = URL(fileURLWithPath: "/Media/Show 2/Episode 11.mkv")
    let otherFolderVideo = URL(fileURLWithPath: "/Media/Show 11/Episode 1.mkv")

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
    try database.replaceEntries(
        subtitleFile: URL(fileURLWithPath: "/Media/Show 11/Episode 1.srt"),
        videoFile: otherFolderVideo,
        entries: [databaseTestEntry(text: "Other folder episode")]
    )
    try database.updateVideoDuration(videoFile: episode2Video, duration: 125.4)

    let videos = try database.libraryCoverEligibleVideos(under: [URL(fileURLWithPath: "/Media")])

    #expect(videos.map(\.videoPath) == [
        episode2Video.path,
        episode11Video.path,
        otherFolderVideo.path
    ])
    #expect(videos[0].duration == 125.4)
    #expect(videos[0].subtitlePath == "/Media/Show 2/Episode 2.en.srt")
    #expect(videos[0].folderPath == "/Media/Show 2")
}

@Test
func libraryCoverRecordsStoreVideoSnapshotAndFolderReference() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    let videoURL = URL(fileURLWithPath: "/Media/Show/Episode 1.mkv")
    try database.replaceEntries(
        subtitleFile: URL(fileURLWithPath: "/Media/Show/Episode 1.srt"),
        videoFile: videoURL,
        entries: [databaseTestEntry(text: "Cover candidate")]
    )
    try database.updateVideoDuration(videoFile: videoURL, duration: 1440.25)

    let videos = try database.libraryCoverEligibleVideos(under: [URL(fileURLWithPath: "/Media")])
    let video = try #require(videos.first)
    try database.upsertLibraryVideoCover(
        videoFileID: video.videoFileID,
        masterCoverPath: "/Library/Application Support/CueSeeker/Covers/Videos/example.jpg",
        displayCoverPath: "/Library/Application Support/CueSeeker/Covers/Display/v1/example.jpg",
        displayProfileVersion: 1,
        sourceTimeMilliseconds: 432_000,
        score: 82.5,
        algorithmVersion: 1,
        generatedFileSize: video.fileSize,
        generatedDuration: video.duration,
        status: .generated,
        errorMessage: nil
    )
    let storedCover = try database.libraryVideoCover(forVideoFileID: video.videoFileID)
    let cover = try #require(storedCover)
    #expect(cover.masterCoverPath == "/Library/Application Support/CueSeeker/Covers/Videos/example.jpg")
    #expect(cover.displayCoverPath == "/Library/Application Support/CueSeeker/Covers/Display/v1/example.jpg")
    #expect(cover.displayProfileVersion == 1)
    #expect(cover.sourceTimeMilliseconds == 432_000)
    #expect(cover.score == 82.5)
    #expect(cover.algorithmVersion == 1)
    #expect(cover.generatedFileSize == video.fileSize)
    #expect(cover.generatedDuration == 1440.25)
    #expect(cover.status == .generated)
    #expect(cover.errorMessage == nil)
    #expect(cover.generatedAt.contains("."))

    try database.upsertLibraryFolderCover(
        folderPath: video.folderPath,
        masterCoverPath: cover.masterCoverPath,
        sourceVideoFileID: video.videoFileID
    )

    let storedFolderCover = try database.libraryFolderCover(folderPath: video.folderPath)
    let folderCover = try #require(storedFolderCover)
    #expect(folderCover.folderPath == "/Media/Show")
    #expect(folderCover.masterCoverPath == cover.masterCoverPath)
    #expect(folderCover.sourceVideoFileID == video.videoFileID)

    try database.updateLibraryVideoDisplayCover(
        videoFileID: video.videoFileID,
        displayCoverPath: nil,
        displayProfileVersion: nil
    )
    let clearedDisplayCover = try #require(
        try database.libraryVideoCover(forVideoFileID: video.videoFileID)
    )
    #expect(clearedDisplayCover.masterCoverPath == cover.masterCoverPath)
    #expect(clearedDisplayCover.displayCoverPath == nil)
    #expect(clearedDisplayCover.displayProfileVersion == nil)
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
    #expect(initialHistory.startedAt != nil)
    #expect(initialHistory.completedAt == nil)

    try database.upsertLibraryPlaybackHistory(
        videoFile: videoFile,
        positionMilliseconds: 0,
        duration: nil
    )

    let updatedHistory = try #require(try database.libraryPlaybackHistory(forVideoFile: videoFile))
    #expect(updatedHistory.positionMilliseconds == 0)
    #expect(updatedHistory.duration == nil)
    #expect(updatedHistory.startedAt == initialHistory.startedAt)
    #expect(updatedHistory.completedAt == nil)
    #expect(LibraryWatchState(
        positionMilliseconds: updatedHistory.positionMilliseconds,
        duration: updatedHistory.duration,
        startedAt: updatedHistory.startedAt,
        completedAt: updatedHistory.completedAt
    ) == .watching)
}

@Test
func libraryPlaybackHistoryKeepsFinishedStateAfterSeekingBack() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    let videoFile = URL(fileURLWithPath: "/Media/Show/Episode 1.mkv")
    try database.upsertLibraryPlaybackHistory(
        videoFile: videoFile,
        positionMilliseconds: 960_000,
        duration: 1_000.0,
        markCompleted: true
    )

    let finishedHistory = try #require(try database.libraryPlaybackHistory(forVideoFile: videoFile))
    #expect(finishedHistory.completedAt != nil)
    #expect(LibraryWatchState(
        positionMilliseconds: finishedHistory.positionMilliseconds,
        duration: finishedHistory.duration,
        startedAt: finishedHistory.startedAt,
        completedAt: finishedHistory.completedAt
    ) == .finished)

    try database.upsertLibraryPlaybackHistory(
        videoFile: videoFile,
        positionMilliseconds: 0,
        duration: 1_000.0
    )

    let rewoundHistory = try #require(try database.libraryPlaybackHistory(forVideoFile: videoFile))
    #expect(rewoundHistory.positionMilliseconds == 0)
    #expect(rewoundHistory.startedAt == finishedHistory.startedAt)
    #expect(rewoundHistory.completedAt == finishedHistory.completedAt)
    #expect(LibraryWatchState(
        positionMilliseconds: rewoundHistory.positionMilliseconds,
        duration: rewoundHistory.duration,
        startedAt: rewoundHistory.startedAt,
        completedAt: rewoundHistory.completedAt
    ) == .finished)
}

@Test
func setLibraryWatchStatePreservesPlaybackProgressAndRecentHistory() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    let root = URL(fileURLWithPath: "/Media")
    let videoFile = URL(fileURLWithPath: "/Media/Show/Episode 1.mkv")
    try database.replaceEntries(
        subtitleFile: videoFile.deletingPathExtension().appendingPathExtension("srt"),
        videoFile: videoFile,
        entries: [databaseTestEntry(text: "episode one")]
    )
    try database.rebuildLibraryPresentationSnapshot()

    let playedAt = Date(timeIntervalSince1970: 1_800_000_000)
    try database.upsertLibraryPlaybackHistory(
        videoFile: videoFile,
        positionMilliseconds: 42_500,
        duration: 100.0,
        updatedAt: playedAt
    )

    let initialHistory = try #require(try database.libraryPlaybackHistory(forVideoFile: videoFile))
    #expect(initialHistory.positionMilliseconds == 42_500)
    #expect(initialHistory.updatedAt == "2027-01-15T08:00:00.000Z")

    try database.setLibraryWatchState(
        videoFile: videoFile,
        duration: 100.0,
        state: .finished
    )

    let finishedHistory = try #require(try database.libraryPlaybackHistory(forVideoFile: videoFile))
    #expect(finishedHistory.positionMilliseconds == 42_500)
    #expect(finishedHistory.updatedAt == initialHistory.updatedAt)
    #expect(finishedHistory.completedAt != nil)
    #expect(LibraryWatchState(
        positionMilliseconds: finishedHistory.positionMilliseconds,
        duration: finishedHistory.duration,
        startedAt: finishedHistory.startedAt,
        completedAt: finishedHistory.completedAt
    ) == .finished)
    let finishedRecent = try #require(try database.recentLibraryWatching(under: [root], limit: 5).first)
    #expect(finishedRecent.videoPath == videoFile.path)
    #expect(finishedRecent.positionMilliseconds == 42_500)
    #expect(finishedRecent.watchState == .finished)

    try database.setLibraryWatchState(
        videoFile: videoFile,
        duration: 100.0,
        state: .unwatched
    )

    let unwatchedHistory = try #require(try database.libraryPlaybackHistory(forVideoFile: videoFile))
    #expect(unwatchedHistory.positionMilliseconds == 42_500)
    #expect(unwatchedHistory.updatedAt == initialHistory.updatedAt)
    #expect(unwatchedHistory.startedAt == nil)
    #expect(unwatchedHistory.completedAt == nil)
    #expect(LibraryWatchState(
        positionMilliseconds: unwatchedHistory.positionMilliseconds,
        duration: unwatchedHistory.duration,
        startedAt: unwatchedHistory.startedAt,
        completedAt: unwatchedHistory.completedAt
    ) == .unwatched)
    let unwatchedRecent = try #require(try database.recentLibraryWatching(under: [root], limit: 5).first)
    #expect(unwatchedRecent.videoPath == videoFile.path)
    #expect(unwatchedRecent.positionMilliseconds == 42_500)
    #expect(unwatchedRecent.watchState == .unwatched)
}

@Test
func libraryPlaybackHistoryDoesNotFinishFromResumePositionAlone() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    let videoFile = URL(fileURLWithPath: "/Media/Show/Episode 1.mkv")
    try database.upsertLibraryPlaybackHistory(
        videoFile: videoFile,
        positionMilliseconds: 960_000,
        duration: 1_000.0
    )

    let history = try #require(try database.libraryPlaybackHistory(forVideoFile: videoFile))
    #expect(history.startedAt != nil)
    #expect(history.completedAt == nil)
    #expect(LibraryWatchState(
        positionMilliseconds: history.positionMilliseconds,
        duration: history.duration,
        startedAt: history.startedAt,
        completedAt: history.completedAt
    ) == .watching)
}

@Test
func recentLibraryWatchingKeepsLatestVideoPerFolderWithinLimit() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    let root = URL(fileURLWithPath: "/Media")
    let showA1 = root.appendingPathComponent("Show A/Episode 1.mkv")
    let showA2 = root.appendingPathComponent("Show A/Episode 2.mkv")
    let showB1 = root.appendingPathComponent("Show B/Episode 1.mkv")
    let showC1 = root.appendingPathComponent("Show C/Episode 1.mkv")
    let showD1 = root.appendingPathComponent("Show D/Episode 1.mkv")
    let showE1 = root.appendingPathComponent("Show E/Episode 1.mkv")
    let showF1 = root.appendingPathComponent("Show F/Episode 1.mkv")

    for videoFile in [showA1, showA2, showB1, showC1, showD1, showE1, showF1] {
        let subtitleFile = videoFile
            .deletingPathExtension()
            .appendingPathExtension("srt")
        try database.replaceEntries(
            subtitleFile: subtitleFile,
            videoFile: videoFile,
            entries: [databaseTestEntry(text: videoFile.lastPathComponent)]
        )
    }
    try database.rebuildLibraryPresentationSnapshot()

    let baseDate = Date(timeIntervalSince1970: 1_800_000_000)
    let history: [(URL, Int, TimeInterval)] = [
        (showA1, 10_000, 0),
        (showB1, 20_000, 1),
        (showC1, 30_000, 2),
        (showD1, 40_000, 3),
        (showE1, 50_000, 4),
        (showF1, 60_000, 5),
        (showA2, 70_000, 6)
    ]
    for (videoFile, positionMilliseconds, dateOffset) in history {
        try database.upsertLibraryPlaybackHistory(
            videoFile: videoFile,
            positionMilliseconds: positionMilliseconds,
            duration: 1_200.0,
            updatedAt: baseDate.addingTimeInterval(dateOffset)
        )
    }

    let recent = try database.recentLibraryWatching(under: [root], limit: 5)

    #expect(recent.map(\.videoPath) == [
        showA2.path,
        showF1.path,
        showE1.path,
        showD1.path,
        showC1.path
    ])
    #expect(recent.map(\.folderTitle) == ["Show A", "Show F", "Show E", "Show D", "Show C"])
    #expect(recent.first?.episodeNumber == 2)
    #expect(recent.first?.positionMilliseconds == 70_000)
    #expect(recent.first?.playbackDuration == 1_200.0)

    let allRecent = try database.recentLibraryWatching(under: [root], limit: Int.max)
    #expect(allRecent.map(\.videoPath) == [
        showA2.path,
        showF1.path,
        showE1.path,
        showD1.path,
        showC1.path,
        showB1.path
    ])
}

@Test
func recentLibraryWatchingUsesFractionalUpdatedAtWithinSameSecond() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    let root = URL(fileURLWithPath: "/Media")
    let episode3 = root.appendingPathComponent("Show/Episode 3.mkv")
    let episode4 = root.appendingPathComponent("Show/Episode 4.mkv")

    for videoFile in [episode3, episode4] {
        try database.replaceEntries(
            subtitleFile: videoFile.deletingPathExtension().appendingPathExtension("srt"),
            videoFile: videoFile,
            entries: [databaseTestEntry(text: videoFile.lastPathComponent)]
        )
    }
    try database.rebuildLibraryPresentationSnapshot()

    let baseDate = Date(timeIntervalSince1970: 1_800_000_000)
    try database.upsertLibraryPlaybackHistory(
        videoFile: episode3,
        positionMilliseconds: 30_000,
        duration: 1_200.0,
        updatedAt: baseDate.addingTimeInterval(0.100)
    )
    try database.upsertLibraryPlaybackHistory(
        videoFile: episode4,
        positionMilliseconds: 40_000,
        duration: 1_200.0,
        updatedAt: baseDate.addingTimeInterval(0.200)
    )

    let recent = try database.recentLibraryWatching(under: [root], limit: 5)

    #expect(recent.map(\.videoPath) == [episode4.path])
    #expect(recent.first?.positionMilliseconds == 40_000)
}

@Test
func completeLibraryPresentationBuildsFolderCardsAndContinueTargets() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    let root = URL(fileURLWithPath: "/Media")
    let show = root.appendingPathComponent("Show")
    let episode1 = show.appendingPathComponent("Episode 1.mkv")
    let episode2 = show.appendingPathComponent("Episode 2.mkv")
    let episode3 = show.appendingPathComponent("Episode 3.mkv")
    let episode4 = show.appendingPathComponent("Episode 4.mkv")

    for videoFile in [episode1, episode2, episode3, episode4] {
        try database.replaceEntries(
            subtitleFile: videoFile.deletingPathExtension().appendingPathExtension("srt"),
            videoFile: videoFile,
            entries: [databaseTestEntry(text: videoFile.lastPathComponent)]
        )
        try database.updateVideoDuration(videoFile: videoFile, duration: 1_000.0)
    }

    try database.rebuildLibraryPresentationSnapshot()

    let baseDate = Date(timeIntervalSince1970: 1_800_000_000)
    try database.upsertLibraryPlaybackHistory(
        videoFile: episode2,
        positionMilliseconds: 960_000,
        duration: 1_000.0,
        updatedAt: baseDate.addingTimeInterval(1),
        markCompleted: true
    )
    try database.upsertLibraryPlaybackHistory(
        videoFile: episode3,
        positionMilliseconds: 300_000,
        duration: 1_000.0,
        updatedAt: baseDate.addingTimeInterval(3)
    )
    try database.upsertLibraryPlaybackHistory(
        videoFile: episode4,
        positionMilliseconds: 400_000,
        duration: 1_000.0,
        updatedAt: baseDate.addingTimeInterval(2)
    )

    let groups = try database.completeLibraryPresentation(under: [root])
    let group = try #require(groups.first)

    #expect(groups.count == 1)
    #expect(group.folderTitle == "Show")
    #expect(group.lastWatchedEpisodeNumber == 3)
    #expect(group.videos.map(\.episodeNumber) == [1, 2, 3, 4])
    #expect(group.videos.map(\.watchState) == [.unwatched, .finished, .watching, .watching])
    #expect(group.continueWatchingVideo?.videoPath == episode3.path)
}

@Test
func completeLibraryContinueTargetUsesLatestHistoryThenFallsBackToFirstEpisode() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    let root = URL(fileURLWithPath: "/Media")
    let showA1 = root.appendingPathComponent("Show A/Episode 1.mkv")
    let showA2 = root.appendingPathComponent("Show A/Episode 2.mkv")
    let showB1 = root.appendingPathComponent("Show B/Episode 1.mkv")
    let showB2 = root.appendingPathComponent("Show B/Episode 2.mkv")

    for videoFile in [showA1, showA2, showB1, showB2] {
        try database.replaceEntries(
            subtitleFile: videoFile.deletingPathExtension().appendingPathExtension("srt"),
            videoFile: videoFile,
            entries: [databaseTestEntry(text: videoFile.lastPathComponent)]
        )
        try database.updateVideoDuration(videoFile: videoFile, duration: 1_000.0)
    }
    try database.rebuildLibraryPresentationSnapshot()

    let baseDate = Date(timeIntervalSince1970: 1_800_000_000)
    try database.upsertLibraryPlaybackHistory(
        videoFile: showB1,
        positionMilliseconds: 960_000,
        duration: 1_000.0,
        updatedAt: baseDate.addingTimeInterval(1)
    )
    try database.upsertLibraryPlaybackHistory(
        videoFile: showB2,
        positionMilliseconds: 960_000,
        duration: 1_000.0,
        updatedAt: baseDate.addingTimeInterval(2)
    )

    let groups = try database.completeLibraryPresentation(under: [root])
    let showA = try #require(groups.first { $0.folderTitle == "Show A" })
    let showB = try #require(groups.first { $0.folderTitle == "Show B" })

    #expect(showA.continueWatchingVideo?.videoPath == showA1.path)
    #expect(showB.continueWatchingVideo?.videoPath == showB2.path)
}

@Test
func completeLibraryFolderSummariesAndDetailSplitFolderAndEpisodeData() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    let root = URL(fileURLWithPath: "/Media")
    let showA1 = root.appendingPathComponent("Show A/Episode 1.mkv")
    let showA2 = root.appendingPathComponent("Show A/Episode 2.mkv")
    let showB1 = root.appendingPathComponent("Show B/Episode 1.mkv")

    for videoFile in [showA1, showA2, showB1] {
        try database.replaceEntries(
            subtitleFile: videoFile.deletingPathExtension().appendingPathExtension("srt"),
            videoFile: videoFile,
            entries: [databaseTestEntry(text: videoFile.lastPathComponent)]
        )
        try database.updateVideoDuration(videoFile: videoFile, duration: 1_000.0)
    }
    try database.updateVideoMetadata(
        videoFile: showA1,
        duration: 1_000.0,
        videoWidth: 1920,
        videoHeight: 1080,
        frameRate: 23.976,
        videoCodec: "hevc"
    )
    try database.rebuildLibraryPresentationSnapshot()

    let eligibleVideos = try database.libraryCoverEligibleVideos(under: [root])
    let showA1CoverCandidate = try #require(eligibleVideos.first { $0.videoPath == showA1.path })
    try database.upsertLibraryVideoCover(
        videoFileID: showA1CoverCandidate.videoFileID,
        masterCoverPath: "/Covers/show-a-episode-1.jpg",
        displayCoverPath: "/Covers/Display/v1/show-a-episode-1.jpg",
        displayProfileVersion: LibraryCoverDisplayProfileVersion.current,
        sourceTimeMilliseconds: 120_000,
        score: 90,
        algorithmVersion: 1,
        generatedFileSize: showA1CoverCandidate.fileSize,
        generatedDuration: showA1CoverCandidate.duration,
        status: .generated,
        errorMessage: nil
    )
    let showACoverRevision = try #require(
        try database.libraryVideoCover(forVideoFileID: showA1CoverCandidate.videoFileID)
    ).generatedAt

    try database.upsertLibraryPlaybackHistory(
        videoFile: showA2,
        positionMilliseconds: 250_000,
        duration: 1_000.0
    )

    let summaries = try database.completeLibraryFolderSummaries(under: [root])
    #expect(summaries.map(\.folderTitle) == ["Show A", "Show B"])

    let showASummary = try #require(summaries.first { $0.folderTitle == "Show A" })
    #expect(showASummary.episodeCount == 2)
    #expect(showASummary.coverPath == "/Covers/Display/v1/show-a-episode-1.jpg")
    #expect(showASummary.coverRevision == showACoverRevision)

    let detail = try #require(try database.completeLibraryFolderDetail(folderPath: showASummary.folderPath))
    #expect(detail.folderTitle == "Show A")
    #expect(detail.videos.map(\.videoPath) == [showA1.path, showA2.path])
    #expect(detail.videos.map(\.episodeNumber) == [1, 2])
    #expect(detail.videos.map(\.watchState) == [.unwatched, .watching])
    #expect(detail.videos.first?.videoWidth == 1920)
    #expect(detail.videos.first?.videoHeight == 1080)
    #expect(detail.videos.first?.frameRate == 23.976)
    #expect(detail.videos.first?.videoCodec == "hevc")
    #expect(detail.videos.first?.coverPath == "/Covers/Display/v1/show-a-episode-1.jpg")
    #expect(detail.videos.first?.coverRevision == showACoverRevision)
}

@Test
func libraryCoverPresentationsNeverFallBackToMasterRendition() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    let root = URL(fileURLWithPath: "/Media")
    let videoFile = root.appendingPathComponent("Show/Episode 1.mkv")
    try database.replaceEntries(
        subtitleFile: videoFile.deletingPathExtension().appendingPathExtension("srt"),
        videoFile: videoFile,
        entries: [databaseTestEntry(text: "display only")]
    )
    try database.rebuildLibraryPresentationSnapshot()
    try database.upsertLibraryPlaybackHistory(
        videoFile: videoFile,
        positionMilliseconds: 1_000,
        duration: 100
    )

    let candidate = try #require(
        try database.libraryCoverEligibleVideos(under: [root]).first
    )
    let masterPath = "/Covers/Videos/master-must-not-render.jpg"
    let displayPath = "/Covers/Display/v1/display.jpg"
    try database.upsertLibraryVideoCover(
        videoFileID: candidate.videoFileID,
        masterCoverPath: masterPath,
        sourceTimeMilliseconds: 1_000,
        score: 75,
        algorithmVersion: 1,
        generatedFileSize: candidate.fileSize,
        generatedDuration: candidate.duration,
        status: .generated,
        errorMessage: nil
    )
    try database.upsertLibraryFolderCover(
        folderPath: candidate.folderPath,
        masterCoverPath: masterPath,
        sourceVideoFileID: candidate.videoFileID
    )

    let masterOnlyRecent = try #require(try database.recentLibraryWatching(under: [root]).first)
    #expect(masterOnlyRecent.coverPath == nil)
    #expect(masterOnlyRecent.coverRevision == nil)
    let masterOnlyFull = try #require(try database.completeLibraryPresentation(under: [root]).first)
    #expect(masterOnlyFull.folderCoverPath == nil)
    #expect(masterOnlyFull.folderCoverRevision == nil)
    #expect(masterOnlyFull.videos.first?.coverPath == nil)
    #expect(masterOnlyFull.videos.first?.coverRevision == nil)
    let masterOnlySummary = try #require(
        try database.completeLibraryFolderSummaries(under: [root]).first
    )
    #expect(masterOnlySummary.coverPath == nil)
    #expect(masterOnlySummary.coverRevision == nil)
    let masterOnlyDetail = try #require(
        try database.completeLibraryFolderDetail(folderPath: candidate.folderPath)
    )
    #expect(masterOnlyDetail.videos.first?.coverPath == nil)
    #expect(masterOnlyDetail.videos.first?.coverRevision == nil)

    try database.updateLibraryVideoDisplayCover(
        videoFileID: candidate.videoFileID,
        displayCoverPath: displayPath,
        displayProfileVersion: LibraryCoverDisplayProfileVersion.current
    )
    let displayRevision = try #require(
        try database.libraryVideoCover(forVideoFileID: candidate.videoFileID)
    ).generatedAt
    #expect(displayRevision.contains("."))

    let displayRecent = try #require(try database.recentLibraryWatching(under: [root]).first)
    #expect(displayRecent.coverPath == displayPath)
    #expect(displayRecent.coverRevision == displayRevision)
    let displayFull = try #require(try database.completeLibraryPresentation(under: [root]).first)
    #expect(displayFull.folderCoverPath == displayPath)
    #expect(displayFull.folderCoverRevision == displayRevision)
    #expect(displayFull.videos.first?.coverPath == displayPath)
    #expect(displayFull.videos.first?.coverRevision == displayRevision)
    let displaySummary = try #require(
        try database.completeLibraryFolderSummaries(under: [root]).first
    )
    #expect(displaySummary.coverPath == displayPath)
    #expect(displaySummary.coverRevision == displayRevision)
    let displayDetail = try #require(
        try database.completeLibraryFolderDetail(folderPath: candidate.folderPath)
    )
    #expect(displayDetail.videos.first?.coverPath == displayPath)
    #expect(displayDetail.videos.first?.coverRevision == displayRevision)

    try database.updateLibraryVideoDisplayCover(
        videoFileID: candidate.videoFileID,
        displayCoverPath: "/Covers/Display/v2/stale-profile.jpg",
        displayProfileVersion: LibraryCoverDisplayProfileVersion.current + 1
    )
    let staleRecent = try #require(try database.recentLibraryWatching(under: [root]).first)
    #expect(staleRecent.coverPath == nil)
    #expect(staleRecent.coverRevision == nil)
    let staleSummary = try #require(
        try database.completeLibraryFolderSummaries(under: [root]).first
    )
    #expect(staleSummary.coverPath == nil)
    #expect(staleSummary.coverRevision == nil)
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
func shioriStoresSameTimeSiblingCuesSeparatelyAndDeduplicatesOneIdentity() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    let subtitleFile = URL(fileURLWithPath: "/Media/Same Time.ass")
    let videoFile = URL(fileURLWithPath: "/Media/Same Time.mkv")
    let topSelection = SubtitleCueTextSelection(
        cueGroupID: 1,
        startMilliseconds: 1_000,
        endMilliseconds: 3_000,
        cueEventIndex: 10,
        cueDisplayOrder: 0,
        content: "Chinese upper cue"
    )
    let bottomSelection = SubtitleCueTextSelection(
        cueGroupID: 1,
        startMilliseconds: 1_000,
        endMilliseconds: 3_000,
        cueEventIndex: 11,
        cueDisplayOrder: 1,
        content: "Japanese lower cue"
    )

    let top = try database.upsertShiori(
        subtitleFile: subtitleFile,
        subtitleFormat: .ass,
        videoFile: videoFile,
        videoName: videoFile.lastPathComponent,
        selection: topSelection,
        createdAt: Date(timeIntervalSince1970: 1_700_000_000)
    )
    let bottom = try database.upsertShiori(
        subtitleFile: subtitleFile,
        subtitleFormat: .ass,
        videoFile: videoFile,
        videoName: videoFile.lastPathComponent,
        selection: bottomSelection,
        createdAt: Date(timeIntervalSince1970: 1_800_000_000)
    )
    let duplicateBottom = try database.upsertShiori(
        subtitleFile: subtitleFile,
        subtitleFormat: .ass,
        videoFile: videoFile,
        videoName: videoFile.lastPathComponent,
        selection: bottomSelection,
        createdAt: Date(timeIntervalSince1970: 1_900_000_000)
    )

    #expect(top.id != bottom.id)
    #expect(bottom.id == duplicateBottom.id)
    #expect(top.cueIdentity == topSelection.cueIdentity)
    #expect(bottom.cueIdentity == bottomSelection.cueIdentity)
    #expect(duplicateBottom.createdAt == bottom.createdAt)
    #expect(try database.shioriCount() == 2)
    #expect(try database.removeShiori(id: bottom.id))
    #expect(try database.shiori(id: top.id) != nil)
    #expect(try database.shiori(id: bottom.id) == nil)
}

@Test
func shioriPageReturnsNewestRowsWithLanguages() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    let subtitleFile = URL(fileURLWithPath: "/Media/Show/Shiori Page.srt")
    let videoFile = URL(fileURLWithPath: "/Media/Show/Shiori Page.mkv")
    try database.replaceEntries(
        subtitleFile: subtitleFile,
        videoFile: videoFile,
        entries: [
            SubtitleEntry(
                sequenceNumber: 1,
                startTimecode: "00:00:01,000",
                endTimecode: "00:00:02,000",
                startMilliseconds: 1_000,
                endMilliseconds: 2_000,
                text: "Old saved cue."
            ),
            SubtitleEntry(
                sequenceNumber: 2,
                startTimecode: "00:00:03,000",
                endTimecode: "00:00:04,000",
                startMilliseconds: 3_000,
                endMilliseconds: 4_000,
                text: "Middle saved cue."
            ),
            SubtitleEntry(
                sequenceNumber: 3,
                startTimecode: "00:00:05,000",
                endTimecode: "00:00:06,000",
                startMilliseconds: 5_000,
                endMilliseconds: 6_000,
                text: "Newest saved cue."
            ),
        ],
        languageAnalysis: SubtitleLanguageAnalysis(
            format: .srt,
            fileDetection: nil,
            styleDetections: [:],
            cueGroupLanguages: [
                [.japanese],
                [.simplifiedChinese],
                [.japanese, .simplifiedChinese]
            ]
        )
    )

    for (milliseconds, createdAt) in [
        (1_500, Date(timeIntervalSince1970: 1_700_000_000)),
        (3_500, Date(timeIntervalSince1970: 1_800_000_000)),
        (5_500, Date(timeIntervalSince1970: 1_900_000_000)),
    ] {
        let selection = try #require(try database.cueTextSelection(
            forSubtitleFile: subtitleFile,
            atMilliseconds: milliseconds
        ))
        _ = try database.upsertShiori(
            subtitleFile: subtitleFile,
            subtitleFormat: .srt,
            videoFile: videoFile,
            videoName: videoFile.lastPathComponent,
            selection: selection,
            createdAt: createdAt
        )
    }

    let page = try database.shioriPage(limit: 2, offset: 1)

    #expect(page.totalCount == 3)
    #expect(page.shioris.map(\.content) == [
        "Middle saved cue.",
        "Old saved cue."
    ])
    #expect(page.languagesByShioriID[page.shioris[0].id] == [.simplifiedChinese])
    #expect(page.languagesByShioriID[page.shioris[1].id] == [.japanese])
    #expect(page.displayTitlesByShioriID[page.shioris[0].id]?.isEmpty == false)
    #expect(page.displayTitlesByShioriID[page.shioris[1].id]?.isEmpty == false)

    let allShioris = try database.shioriPage(limit: 3, offset: 0).shioris
    let newest = try #require(allShioris.first { $0.content == "Newest saved cue." })
    let middle = try #require(allShioris.first { $0.content == "Middle saved cue." })
    let old = try #require(allShioris.first { $0.content == "Old saved cue." })

    #expect(try database.shiori(id: middle.id)?.content == "Middle saved cue.")
    #expect(try database.adjacentShiori(to: middle, direction: .previous)?.id == newest.id)
    #expect(try database.adjacentShiori(to: middle, direction: .next)?.id == old.id)
    #expect(try database.adjacentShiori(to: newest, direction: .previous) == nil)
    #expect(try database.adjacentShiori(to: old, direction: .next) == nil)
}

@Test
func shioriPageForIDsPreservesInputOrderAndCuePresentations() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    let subtitleFile = URL(fileURLWithPath: "/Media/Show/Shiori Scope.srt")
    let videoFile = URL(fileURLWithPath: "/Media/Show/Shiori Scope.mkv")
    try database.replaceEntries(
        subtitleFile: subtitleFile,
        videoFile: videoFile,
        entries: [
            SubtitleEntry(
                sequenceNumber: 1,
                startTimecode: "00:00:01,000",
                endTimecode: "00:00:02,000",
                startMilliseconds: 1_000,
                endMilliseconds: 2_000,
                text: "First scoped cue."
            ),
            SubtitleEntry(
                sequenceNumber: 2,
                startTimecode: "00:00:03,000",
                endTimecode: "00:00:04,000",
                startMilliseconds: 3_000,
                endMilliseconds: 4_000,
                text: "Second scoped cue."
            ),
            SubtitleEntry(
                sequenceNumber: 3,
                startTimecode: "00:00:05,000",
                endTimecode: "00:00:06,000",
                startMilliseconds: 5_000,
                endMilliseconds: 6_000,
                text: "Third scoped cue."
            ),
        ]
    )

    var savedShioris: [Shiori] = []
    for (milliseconds, createdAt) in [
        (1_500, Date(timeIntervalSince1970: 1_700_000_000)),
        (3_500, Date(timeIntervalSince1970: 1_800_000_000)),
        (5_500, Date(timeIntervalSince1970: 1_900_000_000)),
    ] {
        let selection = try #require(try database.cueTextSelection(
            forSubtitleFile: subtitleFile,
            atMilliseconds: milliseconds
        ))
        savedShioris.append(
            try database.upsertShiori(
                subtitleFile: subtitleFile,
                subtitleFormat: .srt,
                videoFile: videoFile,
                videoName: videoFile.lastPathComponent,
                selection: selection,
                createdAt: createdAt
            )
        )
    }

    let first = savedShioris[0]
    let second = savedShioris[1]
    let third = savedShioris[2]
    #expect(
        try database.shioriPage(limit: 3, offset: 0).shioris.map(\.id)
            == [third.id, second.id, first.id]
    )

    let page = try database.shioriPage(
        shioriIDs: [first.id, third.id, first.id, -1, second.id]
    )

    #expect(page.shioris.map(\.id) == [first.id, third.id, second.id])
    #expect(page.totalCount == 3)
    #expect(Set(page.cuePresentationsByShioriID.keys) == Set(page.shioris.map(\.id)))
    for shiori in page.shioris {
        let presentation = try #require(page.cuePresentationsByShioriID[shiori.id])
        #expect(presentation.cueID != nil)
        #expect(presentation.primaryGroupIndex == 0)
        #expect(presentation.cueGroupTexts == [shiori.content])
    }

    let emptyPage = try database.shioriPage(shioriIDs: [])
    #expect(emptyPage.shioris.isEmpty)
    #expect(emptyPage.totalCount == 0)
    #expect(emptyPage.languagesByShioriID.isEmpty)
    #expect(emptyPage.displayTitlesByShioriID.isEmpty)
    #expect(emptyPage.cuePresentationsByShioriID.isEmpty)
}

@Test
func shioriCuePresentationUsesDurableIdentityAndPrimaryCueMetadata() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    let subtitleFile = URL(fileURLWithPath: "/Media/ShioriPresentation.ass")
    let videoFile = URL(fileURLWithPath: "/Media/ShioriPresentation.mkv")
    let chineseText = "这是同一组里较长的中文字幕内容"
    let japaneseText = "これは同じグループの日本語字幕です\n改行も保持します"
    let groupOnlyLanguageAnalysis = SubtitleLanguageAnalysis(
        format: .ass,
        fileDetection: nil,
        styleDetections: [:],
        cueGroupLanguages: [[.japanese, .simplifiedChinese]]
    )
    let initialGroup = SubtitleCueGroup(
        sequenceNumber: nil,
        startTimecode: "0:00:01.00",
        endTimecode: "0:00:03.00",
        startMilliseconds: 1_000,
        endMilliseconds: 3_000,
        searchContent: "\(chineseText)\n\(japaneseText)",
        cueLines: [
            testCueLine(
                eventIndex: 10,
                startMilliseconds: 1_000,
                endMilliseconds: 3_000,
                content: chineseText,
                displayOrder: 0
            ),
            testCueLine(
                eventIndex: 11,
                startMilliseconds: 1_000,
                endMilliseconds: 3_000,
                content: japaneseText,
                displayOrder: 1
            ),
        ]
    )
    try database.replaceCueGroups(
        subtitleFile: subtitleFile,
        videoFile: videoFile,
        format: .ass,
        cueGroups: [initialGroup],
        languageAnalysis: groupOnlyLanguageAnalysis
    )
    let selection = try #require(try database.cueTextSelection(
        forSubtitleFile: subtitleFile,
        atMilliseconds: 1_500
    ))
    #expect(selection.cueEventIndex == 11)
    let saved = try database.upsertShiori(
        subtitleFile: subtitleFile,
        subtitleFormat: .ass,
        videoFile: videoFile,
        videoName: videoFile.lastPathComponent,
        selection: selection
    )
    #expect(saved.cueDisplayOrder == 1)

    let reorderedGroup = SubtitleCueGroup(
        sequenceNumber: nil,
        startTimecode: "0:00:01.00",
        endTimecode: "0:00:03.00",
        startMilliseconds: 1_000,
        endMilliseconds: 3_000,
        searchContent: "\(japaneseText)\n\(chineseText)",
        cueLines: [
            testCueLine(
                eventIndex: 11,
                startMilliseconds: 1_000,
                endMilliseconds: 3_000,
                content: japaneseText,
                displayOrder: 0
            ),
            testCueLine(
                eventIndex: 10,
                startMilliseconds: 1_000,
                endMilliseconds: 3_000,
                content: chineseText,
                displayOrder: 1
            ),
        ]
    )
    try database.replaceCueGroups(
        subtitleFile: subtitleFile,
        videoFile: videoFile,
        format: .ass,
        cueGroups: [reorderedGroup],
        languageAnalysis: groupOnlyLanguageAnalysis
    )
    let currentCues = try database.cueLineRecords(forSubtitleFile: subtitleFile)
    let currentJapaneseCue = try #require(currentCues.first { $0.line.eventIndex == 11 })
    let currentChineseCue = try #require(currentCues.first { $0.line.eventIndex == 10 })
    try database.replaceCueLineSpeakers(
        forSubtitleFile: subtitleFile,
        assignments: [
            SubtitleCueLineSpeakerAssignment(
                cueLineID: currentJapaneseCue.id,
                speakers: ["Japanese Speaker"]
            ),
            SubtitleCueLineSpeakerAssignment(
                cueLineID: currentChineseCue.id,
                speakers: ["Chinese Speaker"]
            ),
        ]
    )

    let allJapaneseCues = try database.allCuesVisiblePage(
        limit: 10,
        cursor: .start,
        filterSet: SubtitleSearchFilterSet(
            rules: [
                SubtitleSearchFilterRule(field: .language, operatorID: .contains, value: "ja")
            ]
        )
    )
    #expect(allJapaneseCues.results.map(\.entryID) == [currentJapaneseCue.id])
    let allChineseCues = try database.allCuesVisiblePage(
        limit: 10,
        cursor: .start,
        filterSet: SubtitleSearchFilterSet(
            rules: [
                SubtitleSearchFilterRule(field: .language, operatorID: .contains, value: "zh")
            ]
        )
    )
    #expect(allChineseCues.results.map(\.entryID) == [currentChineseCue.id])

    let page = try database.shioriPage(limit: 10, offset: 0)
    let shiori = try #require(page.shioris.first)
    let presentation = try #require(page.cuePresentationsByShioriID[shiori.id])
    #expect(shiori.cueDisplayOrder == 1)
    #expect(presentation.cueID == currentJapaneseCue.id)
    #expect(presentation.cueGroupID == currentJapaneseCue.cueGroupID)
    #expect(presentation.primaryGroupIndex == 0)
    #expect(presentation.cueGroupTexts == [japaneseText, chineseText])
    #expect(presentation.languages == [.japanese])
    #expect(presentation.speakers == ["Japanese Speaker"])
    #expect(page.languagesByShioriID[shiori.id] == [.japanese])
    #expect(
        try database.cueID(
            forSubtitlePath: subtitleFile.path,
            cueIdentity: try #require(shiori.cueIdentity)
        ) == currentJapaneseCue.id
    )

    let japaneseSpeakerPage = try database.shioriTablePage(
        limit: 10,
        offset: 0,
        searchText: "",
        filterSet: SubtitleSearchFilterSet(
            rules: [
                SubtitleSearchFilterRule(
                    field: .speaker,
                    operatorID: .contains,
                    value: "Japanese Speaker"
                )
            ]
        )
    )
    #expect(japaneseSpeakerPage.totalCount == 1)
    let siblingSpeakerPage = try database.shioriTablePage(
        limit: 10,
        offset: 0,
        searchText: "",
        filterSet: SubtitleSearchFilterSet(
            rules: [
                SubtitleSearchFilterRule(
                    field: .speaker,
                    operatorID: .contains,
                    value: "Chinese Speaker"
                )
            ]
        )
    )
    #expect(siblingSpeakerPage.totalCount == 0)

    let japaneseLanguagePage = try database.shioriTablePage(
        limit: 10,
        offset: 0,
        searchText: "",
        filterSet: SubtitleSearchFilterSet(
            rules: [
                SubtitleSearchFilterRule(field: .language, operatorID: .contains, value: "ja")
            ]
        )
    )
    #expect(japaneseLanguagePage.totalCount == 1)
    let chineseLanguagePage = try database.shioriTablePage(
        limit: 10,
        offset: 0,
        searchText: "",
        filterSet: SubtitleSearchFilterSet(
            rules: [
                SubtitleSearchFilterRule(
                    field: .language,
                    operatorID: .contains,
                    value: "zh"
                )
            ]
        )
    )
    #expect(chineseLanguagePage.totalCount == 0)

    let contextPage = try #require(try database.cueContextSearchPage(
        subtitlePath: subtitleFile.path,
        targetCueID: currentJapaneseCue.id,
        limit: 2,
        anchorsInitialPage: true
    ))
    #expect(contextPage.results.first?.entryID == currentJapaneseCue.id)
    #expect(contextPage.results.first?.cueDisplayOrder == 0)
    #expect(contextPage.results.first?.content == japaneseText)
}

@Test
func shioriTablePageAppliesSearchAndFiltersBeforeSlicing() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    let subtitleFile = URL(fileURLWithPath: "/Media/Show/Shiori Table.srt")
    let videoFile = URL(fileURLWithPath: "/Media/Show/Shiori Table.mkv")
    try database.replaceEntries(
        subtitleFile: subtitleFile,
        videoFile: videoFile,
        entries: [
            SubtitleEntry(
                sequenceNumber: 1,
                startTimecode: "00:00:01,000",
                endTimecode: "00:00:02,000",
                startMilliseconds: 1_000,
                endMilliseconds: 2_000,
                text: "Old saved cue."
            ),
            SubtitleEntry(
                sequenceNumber: 2,
                startTimecode: "00:00:03,000",
                endTimecode: "00:00:04,000",
                startMilliseconds: 3_000,
                endMilliseconds: 4_000,
                text: "Middle saved cue."
            ),
            SubtitleEntry(
                sequenceNumber: 3,
                startTimecode: "00:00:05,000",
                endTimecode: "00:00:06,000",
                startMilliseconds: 5_000,
                endMilliseconds: 6_000,
                text: "Newest saved cue."
            ),
        ],
        languageAnalysis: SubtitleLanguageAnalysis(
            format: .srt,
            fileDetection: nil,
            styleDetections: [:],
            cueGroupLanguages: [
                [.japanese],
                [.simplifiedChinese],
                [.japanese, .simplifiedChinese]
            ]
        )
    )

    for (milliseconds, createdAt) in [
        (1_500, Date(timeIntervalSince1970: 1_700_000_000)),
        (3_500, Date(timeIntervalSince1970: 1_800_000_000)),
        (5_500, Date(timeIntervalSince1970: 1_900_000_000)),
    ] {
        let selection = try #require(try database.cueTextSelection(
            forSubtitleFile: subtitleFile,
            atMilliseconds: milliseconds
        ))
        _ = try database.upsertShiori(
            subtitleFile: subtitleFile,
            subtitleFormat: .srt,
            videoFile: videoFile,
            videoName: videoFile.lastPathComponent,
            selection: selection,
            createdAt: createdAt
        )
    }

    let searchPage = try database.shioriTablePage(
        limit: 1,
        offset: 0,
        searchText: "middle",
        filterSet: SubtitleSearchFilterSet()
    )
    #expect(searchPage.totalCount == 1)
    #expect(searchPage.shioris.map(\.content) == ["Middle saved cue."])
    #expect(searchPage.displayTitlesByShioriID[searchPage.shioris[0].id]?.isEmpty == false)

    let languageFilter = SubtitleSearchFilterSet(rules: [
        SubtitleSearchFilterRule(
            field: .language,
            operatorID: .contains,
            value: "zh-Hans"
        )
    ])
    let filteredPage = try database.shioriTablePage(
        limit: 1,
        offset: 1,
        searchText: "",
        filterSet: languageFilter
    )

    #expect(filteredPage.totalCount == 2)
    #expect(filteredPage.shioris.map(\.content) == ["Middle saved cue."])
    #expect(filteredPage.languagesByShioriID[filteredPage.shioris[0].id] == [.simplifiedChinese])
}

@Test
func migrationCreatesShioriTablePerformanceIndexes() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    #expect(try sqliteIndexExists("idx_shioris_created_order", databaseURL: databaseURL))
    #expect(try sqliteIndexExists("idx_subtitle_cue_groups_file_time", databaseURL: databaseURL))
}

@Test
func migrationCreatesShioriTagTablesAndIndexes() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    #expect(try sqliteTableExists("shiori_tags", databaseURL: databaseURL))
    #expect(try sqliteTableExists("shiori_tag_assignments", databaseURL: databaseURL))
    #expect(try sqliteIndexExists("idx_shiori_tags_name", databaseURL: databaseURL))
    #expect(try sqliteIndexExists("idx_shiori_tag_assignments_tag", databaseURL: databaseURL))
    #expect(try sqliteIndexExists("idx_shiori_tag_assignments_shiori", databaseURL: databaseURL))
}

@Test
func shioriTagAPIsValidatePersistAndDeleteAssignments() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    let subtitleFile = URL(fileURLWithPath: "/Media/Tags.srt")
    let videoFile = URL(fileURLWithPath: "/Media/Tags.mkv")
    try database.replaceEntries(
        subtitleFile: subtitleFile,
        videoFile: videoFile,
        entries: [
            SubtitleEntry(
                sequenceNumber: 1,
                startTimecode: "00:00:01,000",
                endTimecode: "00:00:02,000",
                startMilliseconds: 1_000,
                endMilliseconds: 2_000,
                text: "First tagged shiori."
            ),
            SubtitleEntry(
                sequenceNumber: 2,
                startTimecode: "00:00:03,000",
                endTimecode: "00:00:04,000",
                startMilliseconds: 3_000,
                endMilliseconds: 4_000,
                text: "Second tagged shiori."
            ),
        ]
    )

    let firstSelection = try #require(try database.cueTextSelection(
        forSubtitleFile: subtitleFile,
        atMilliseconds: 1_500
    ))
    let secondSelection = try #require(try database.cueTextSelection(
        forSubtitleFile: subtitleFile,
        atMilliseconds: 3_500
    ))
    let firstShiori = try database.upsertShiori(
        subtitleFile: subtitleFile,
        subtitleFormat: .srt,
        videoFile: videoFile,
        videoName: videoFile.lastPathComponent,
        selection: firstSelection
    )
    let secondShiori = try database.upsertShiori(
        subtitleFile: subtitleFile,
        subtitleFormat: .srt,
        videoFile: videoFile,
        videoName: videoFile.lastPathComponent,
        selection: secondSelection
    )

    let createdAt = try #require(ISO8601DateFormatter().date(from: "2026-07-08T00:00:00Z"))
    let tag = try database.createShioriTag(named: "  Tag  ", createdAt: createdAt)
    let duplicate = try database.createShioriTag(named: "Tag")
    let lowerCaseTag = try database.createShioriTag(named: "tag")

    #expect(tag.name == "Tag")
    #expect(duplicate.id == tag.id)
    #expect(lowerCaseTag.id != tag.id)
    #expect(try database.shioriTag(named: " Tag ")?.id == tag.id)

    #expect(try database.assignShioriTag(tagID: tag.id, toShioriID: firstShiori.id))
    #expect(try !database.assignShioriTag(tagID: tag.id, toShioriID: firstShiori.id))
    let secondTag = try database.assignShioriTag(named: "復習", toShioriID: secondShiori.id)

    var tagsByShioriID = try database.shioriTagsByShioriID(
        forShioriIDs: [firstShiori.id, secondShiori.id]
    )
    #expect(tagsByShioriID[firstShiori.id]?.map(\.name) == ["Tag"])
    #expect(tagsByShioriID[secondShiori.id]?.map(\.name) == ["復習"])

    #expect(try database.removeShioriTagAssignment(tagID: tag.id, fromShioriID: firstShiori.id))
    #expect(try !database.removeShioriTagAssignment(tagID: tag.id, fromShioriID: firstShiori.id))
    #expect(try database.shioriTags(forShioriID: firstShiori.id).isEmpty)

    #expect(try database.assignShioriTag(tagID: tag.id, toShioriID: firstShiori.id))
    #expect(try database.assignShioriTag(tagID: tag.id, toShioriID: secondShiori.id))
    let deletion = try database.deleteShioriTag(tagID: tag.id)
    #expect(deletion.didDelete)
    #expect(deletion.affectedShioriIDs == [firstShiori.id, secondShiori.id].sorted())
    #expect(try database.shioriTag(id: tag.id) == nil)
    tagsByShioriID = try database.shioriTagsByShioriID(
        forShioriIDs: [firstShiori.id, secondShiori.id]
    )
    #expect(tagsByShioriID[firstShiori.id]?.isEmpty == true)
    #expect(tagsByShioriID[secondShiori.id]?.map(\.id) == [secondTag.id])

    let missingDeletion = try database.deleteShioriTag(tagID: -1)
    #expect(!missingDeletion.didDelete)
    #expect(missingDeletion.affectedShioriIDs.isEmpty)

    do {
        _ = try database.assignShioriTag(named: "Orphan", toShioriID: -1)
        Issue.record("Expected missing Shiori assignment to fail")
    } catch {
        #expect(try database.shioriTag(named: "Orphan") == nil)
    }
}

@Test
func shioriTagValidationRejectsInvalidNames() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    expectShioriTagValidationError(.emptyName) {
        _ = try database.createShioriTag(named: "   ")
    }
    expectShioriTagValidationError(.nameTooLong(maximumCharacters: 20)) {
        _ = try database.createShioriTag(named: "123456789012345678901")
    }
    expectShioriTagValidationError(.invalidCharacters) {
        _ = try database.createShioriTag(named: "hello\nworld")
    }
    expectShioriTagValidationError(.invalidCharacters) {
        _ = try database.createShioriTag(named: "\nhello")
    }
    expectShioriTagValidationError(.invalidCharacters) {
        _ = try database.createShioriTag(named: "hello\tworld")
    }
    expectShioriTagValidationError(.invalidCharacters) {
        _ = try database.createShioriTag(named: "hello\u{200B}world")
    }

    let allowed = try database.createShioriTag(named: #" C++ "Q" / \ & 😀 "#)
    #expect(allowed.name == #"C++ "Q" / \ & 😀"#)
}

@Test
func migrationAddsShioriTagsWithoutDroppingExistingShioris() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    try createVersionTwentyFiveDatabaseWithShiori(at: databaseURL)

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    #expect(try database.schemaVersion() == SubtitleDatabase.currentSchemaVersion)
    #expect(try sqliteTableExists("shiori_tags", databaseURL: databaseURL))
    #expect(try sqliteTableExists("shiori_tag_assignments", databaseURL: databaseURL))

    let shiori = try #require(try database.shioris().first)
    #expect(shiori.content == "Durable Shiori survives tag migration.")

    let tag = try database.assignShioriTag(named: "Review", toShioriID: shiori.id)
    #expect(tag.name == "Review")
    #expect(try database.shioriTags(forShioriID: shiori.id).map(\.name) == ["Review"])
}

@Test
func migrationConvertsLegacyShioriToJapaneseCueAndBottommostFallback() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    try createVersionTwentySevenCueGroupShioriDatabase(at: databaseURL)

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()
    try database.migrate()

    #expect(try database.schemaVersion() == 28)

    let japanese = try #require(try database.shiori(id: 42))
    #expect(japanese.content == "日本語の下段です")
    #expect(japanese.startMilliseconds == 1_050)
    #expect(japanese.endMilliseconds == 2_950)
    #expect(japanese.cueEventIndex == 102)
    #expect(japanese.cueDisplayOrder == 1)
    #expect(!japanese.isValid)
    #expect(japanese.createdAt == "2026-07-10T01:02:03Z")

    let fallback = try #require(try database.shiori(id: 44))
    #expect(fallback.content == "Lower fallback cue")
    #expect(fallback.cueEventIndex == 201)
    #expect(fallback.cueDisplayOrder == 1)

    let mixedFileDetection = try #require(try database.shiori(id: 45))
    #expect(mixedFileDetection.content == "これは日本語です")
    #expect(mixedFileDetection.cueEventIndex == 300)
    #expect(mixedFileDetection.cueDisplayOrder == 0)

    let mixedStyleDetection = try #require(try database.shiori(id: 46))
    #expect(mixedStyleDetection.content == "これは同じスタイルの日本語です")
    #expect(mixedStyleDetection.cueEventIndex == 400)
    #expect(mixedStyleDetection.cueDisplayOrder == 0)
}

@Test
func migrationPreservesLegacyShioriTagsAndUnindexedSnapshot() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    try createVersionTwentySevenCueGroupShioriDatabase(at: databaseURL)

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    #expect(try database.shioriTags(forShioriID: 42).map(\.name) == ["Review"])
    #expect(try database.shioriTags(forShioriID: 43).map(\.name) == ["Review"])

    let orphan = try #require(try database.shiori(id: 43))
    #expect(orphan.subtitlePath == "/Media/Missing.ass")
    #expect(orphan.content == "Unindexed Japanese and Chinese snapshot")
    #expect(orphan.startMilliseconds == 6_000)
    #expect(orphan.endMilliseconds == 7_000)
    #expect(orphan.cueIdentity == nil)
    #expect(orphan.isValid)
    #expect(orphan.createdAt == "2026-07-10T02:03:04Z")

    let page = try database.shioriPage(limit: 10, offset: 0)
    let presentation = try #require(page.cuePresentationsByShioriID[orphan.id])
    #expect(presentation.cueID == nil)
    #expect(presentation.cueGroupID == nil)
    #expect(presentation.primaryGroupIndex == nil)
    #expect(presentation.cueGroupTexts == [orphan.content])
    #expect(presentation.languages == [.unknown])
    #expect(presentation.speakers.isEmpty)
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
func migrationBackfillsLibraryPlaybackHistoryWatchStateColumns() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
        try? FileManager.default.removeItem(atPath: databaseURL.path + "-wal")
        try? FileManager.default.removeItem(atPath: databaseURL.path + "-shm")
    }

    try createVersionNineteenDatabaseWithLibraryPlaybackHistory(at: databaseURL)

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    #expect(try database.schemaVersion() == SubtitleDatabase.currentSchemaVersion)

    let startedVideo = URL(fileURLWithPath: "/Media/Started.mkv")
    let startedHistory = try #require(try database.libraryPlaybackHistory(forVideoFile: startedVideo))
    #expect(startedHistory.startedAt == startedHistory.updatedAt)
    #expect(startedHistory.completedAt == nil)
    #expect(LibraryWatchState(
        positionMilliseconds: startedHistory.positionMilliseconds,
        duration: startedHistory.duration,
        startedAt: startedHistory.startedAt,
        completedAt: startedHistory.completedAt
    ) == .watching)

    let completedVideo = URL(fileURLWithPath: "/Media/Completed.mkv")
    let completedHistory = try #require(try database.libraryPlaybackHistory(forVideoFile: completedVideo))
    #expect(completedHistory.startedAt == completedHistory.updatedAt)
    #expect(completedHistory.completedAt == completedHistory.updatedAt)
    #expect(LibraryWatchState(
        positionMilliseconds: completedHistory.positionMilliseconds,
        duration: completedHistory.duration,
        startedAt: completedHistory.startedAt,
        completedAt: completedHistory.completedAt
    ) == .finished)
}

@Test
func migrationAddsDisplayCoverFieldsWithoutReplacingMaster() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
        try? FileManager.default.removeItem(atPath: databaseURL.path + "-wal")
        try? FileManager.default.removeItem(atPath: databaseURL.path + "-shm")
    }

    try createVersionTwentySixDatabaseWithLibraryCover(at: databaseURL)

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()
    try database.migrate()

    #expect(try database.schemaVersion() == SubtitleDatabase.currentSchemaVersion)

    let cover = try #require(try database.libraryVideoCover(forVideoFileID: 1))
    #expect(cover.masterCoverPath == "/Covers/Videos/legacy-master.jpg")
    #expect(cover.displayCoverPath == nil)
    #expect(cover.displayProfileVersion == nil)
    #expect(cover.sourceTimeMilliseconds == 120_000)
    #expect(cover.status == .generated)

    let folderCover = try #require(
        try database.libraryFolderCover(folderPath: "/Media/Legacy Show")
    )
    #expect(folderCover.masterCoverPath == cover.masterCoverPath)
    #expect(folderCover.sourceVideoFileID == 1)
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
func searchesIndividualCuesAndRejectsCrossCueOnlyMatches() throws {
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
    #expect(alphaResults[0].content == "alpha")
    #expect(alphaResults[0].cueLines == ["alpha"])
    #expect(alphaResults[0].cueGroupLines == ["alpha", "beta"])
    #expect(alphaResults[0].cueEventIndex == 0)
    #expect(alphaResults[0].cueDisplayOrder == 0)
    #expect(alphaResults[0].videoPath == videoFile.path)
    #expect(alphaResults[0].startMilliseconds == 1_000)

    #expect(try database.search("alpha beta").isEmpty)
}

@Test
func searchCountsAndPaginatesMatchingSiblingCuesIndependently() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    let subtitleFile = URL(fileURLWithPath: "/Media/SiblingMatches.ass")
    let videoFile = URL(fileURLWithPath: "/Media/SiblingMatches.mkv")
    let cueGroup = SubtitleCueGroup(
        sequenceNumber: nil,
        startTimecode: "0:00:01.00",
        endTimecode: "0:00:03.00",
        startMilliseconds: 1_000,
        endMilliseconds: 3_000,
        searchContent: "shared upper\nshared lower",
        cueLines: [
            testCueLine(
                eventIndex: 10,
                startMilliseconds: 1_000,
                endMilliseconds: 3_000,
                content: "shared upper",
                displayOrder: 0
            ),
            testCueLine(
                eventIndex: 11,
                startMilliseconds: 1_000,
                endMilliseconds: 3_000,
                content: "shared lower",
                displayOrder: 1
            ),
        ]
    )
    try database.replaceCueGroups(
        subtitleFile: subtitleFile,
        videoFile: videoFile,
        format: .ass,
        cueGroups: [cueGroup]
    )

    let cueRecords = try database.cueLineRecords(forSubtitleFile: subtitleFile)
    let exactFirst = try database.searchPage(
        "shared",
        limit: 1,
        cursor: .start
    )
    #expect(exactFirst.totalCount == 2)
    #expect(exactFirst.results.map(\.content) == ["shared upper"])
    #expect(exactFirst.cueIDs == cueRecords.map(\.id))
    #expect(exactFirst.fileSummaries.map(\.matchCount) == [2])
    #expect(exactFirst.nextCursor == SubtitleSearchCursor(offset: 1))
    #expect(exactFirst.results[0].cueGroupLines == ["shared upper", "shared lower"])

    let exactSecond = try database.searchPage(
        "shared",
        limit: 1,
        cursor: exactFirst.nextCursor
    )
    #expect(exactSecond.results.map(\.content) == ["shared lower"])
    #expect(exactSecond.results.map(\.searchRank) == [1])
    #expect(exactSecond.nextCursor == nil)

    let visibleFirst = try database.searchVisiblePage(
        "shared",
        limit: 1,
        cursor: .start
    )
    let visibleSecond = try database.searchVisiblePage(
        "shared",
        limit: 1,
        cursor: visibleFirst.nextCursor
    )
    #expect(visibleFirst.results.map(\.content) == ["shared upper"])
    #expect(visibleSecond.results.map(\.content) == ["shared lower"])
    #expect(visibleFirst.results[0].cueGroupID == visibleSecond.results[0].cueGroupID)
    #expect(visibleFirst.results[0].entryID != visibleSecond.results[0].entryID)

    let hydratedPage = try #require(try database.searchIndexedVisiblePage(
        from: SubtitleSearchResultIDIndexWindow(
            cueIDs: exactFirst.cueIDs,
            offset: 0,
            totalCount: 2,
            fileSummaries: exactFirst.fileSummaries,
            countSnapshot: .exact(totalCount: 2, fileSummaryCount: 1),
            appliedCursor: .start,
            nextCursor: nil
        )
    ))
    #expect(hydratedPage.results.map(\.content) == ["shared upper", "shared lower"])
    #expect(hydratedPage.results.map(\.entryID) == exactFirst.cueIDs)

    let navigation = try database.searchNavigationSnapshot(
        "shared",
        anchor: SearchNavigationAnchor(
            selectedEntryID: exactFirst.cueIDs[1],
            selectedSearchRank: 1,
            videoPath: nil,
            subtitlePath: nil,
            currentMilliseconds: 0
        )
    )
    #expect(navigation.current?.content == "shared lower")
    #expect(navigation.previous?.content == "shared upper")
}

@Test
func searchPrimaryGroupIndexDistinguishesSiblingCuesWithIdenticalText() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()
    let subtitleFile = URL(fileURLWithPath: "/Media/DuplicateSiblingText.ass")
    let cueGroup = SubtitleCueGroup(
        sequenceNumber: nil,
        startTimecode: "0:00:01.00",
        endTimecode: "0:00:03.00",
        startMilliseconds: 1_000,
        endMilliseconds: 3_000,
        searchContent: "duplicate cue\nduplicate cue",
        cueLines: [
            testCueLine(
                eventIndex: 10,
                startMilliseconds: 1_000,
                endMilliseconds: 3_000,
                content: "duplicate cue",
                displayOrder: 0
            ),
            testCueLine(
                eventIndex: 11,
                startMilliseconds: 1_000,
                endMilliseconds: 3_000,
                content: "duplicate cue",
                displayOrder: 1
            ),
        ]
    )
    try database.replaceCueGroups(
        subtitleFile: subtitleFile,
        videoFile: URL(fileURLWithPath: "/Media/DuplicateSiblingText.mkv"),
        format: .ass,
        cueGroups: [cueGroup]
    )

    let cueRecords = try database.cueLineRecords(forSubtitleFile: subtitleFile)
    let page = try database.searchPage("duplicate", limit: 10, cursor: .start)

    #expect(page.results.map(\.entryID) == cueRecords.map(\.id))
    #expect(page.results.map(\.content) == ["duplicate cue", "duplicate cue"])
    #expect(page.results.map(\.cueGroupLines) == [
        ["duplicate cue", "duplicate cue"],
        ["duplicate cue", "duplicate cue"],
    ])
    #expect(page.results.map(\.primaryGroupIndex) == [0, 1])
}

@Test
func searchKeepsOneCueWithSourceLineBreaksAsOneResult() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    let subtitleFile = URL(fileURLWithPath: "/Media/MultilineCue.srt")
    let content = "shared first line\nshared second line"
    try database.replaceEntries(
        subtitleFile: subtitleFile,
        videoFile: URL(fileURLWithPath: "/Media/MultilineCue.mkv"),
        entries: [
            SubtitleEntry(
                sequenceNumber: 1,
                startTimecode: "00:00:01,000",
                endTimecode: "00:00:03,000",
                startMilliseconds: 1_000,
                endMilliseconds: 3_000,
                text: content
            )
        ]
    )

    let results = try database.search("shared first second")
    #expect(results.count == 1)
    #expect(results[0].content == content)
    #expect(results[0].cueLines == [content])
    #expect(results[0].cueGroupLines == [content])
}

@Test
func searchCueFiltersAndSpeakersDoNotLeakFromSiblingCue() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    let subtitleFile = URL(fileURLWithPath: "/Media/CueFilterIsolation.ass")
    let cueGroup = languageFilterASSCueGroup(
        startMilliseconds: 1_000,
        lines: [
            (style: "Primary", content: "target primary cue"),
            (style: "Context", content: "secret sibling cue"),
        ]
    )
    try database.replaceCueGroups(
        subtitleFile: subtitleFile,
        videoFile: URL(fileURLWithPath: "/Media/CueFilterIsolation.mkv"),
        format: .ass,
        cueGroups: [cueGroup]
    )
    let cueRecords = try database.cueLineRecords(forSubtitleFile: subtitleFile)
    let sibling = try #require(cueRecords.first { $0.line.content == "secret sibling cue" })
    try database.replaceCueLineSpeakers(
        forSubtitleFile: subtitleFile,
        assignments: [
            SubtitleCueLineSpeakerAssignment(cueLineID: sibling.id, speakers: ["Sibling Speaker"])
        ]
    )

    let siblingCueFilter = SubtitleSearchFilterSet(rules: [
        SubtitleSearchFilterRule(field: .cues, operatorID: .contains, value: "secret")
    ])
    let siblingSpeakerFilter = SubtitleSearchFilterSet(rules: [
        SubtitleSearchFilterRule(field: .speaker, operatorID: .contains, value: "Sibling Speaker")
    ])
    #expect(try database.search("target", filterSet: siblingCueFilter).isEmpty)
    #expect(try database.search("target", filterSet: siblingSpeakerFilter).isEmpty)

    let siblingResults = try database.search("secret")
    #expect(siblingResults.map(\.content) == ["secret sibling cue"])
    #expect(siblingResults.first?.speakers == ["Sibling Speaker"])
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
    #expect(results.map(\.content) == ["Chinese upper line"])
    #expect(results.first?.cueLines == ["Chinese upper line"])
    #expect(results.first?.cueGroupLines == ["Chinese upper line", "Japanese lower line"])
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
func storesASSPrimaryStylePlaybackFinishMetadata() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    let subtitleFile = URL(fileURLWithPath: "/Media/Primary.ass")
    let videoFile = URL(fileURLWithPath: "/Media/Primary.mkv")

    let sharedTimestampGroup = SubtitleCueGroup(
        sequenceNumber: nil,
        startTimecode: "1000",
        endTimecode: "2000",
        startMilliseconds: 1_000,
        endMilliseconds: 2_000,
        searchContent: "main jp\nmain cn",
        cueLines: [
            testCueLine(
                eventIndex: 0,
                startMilliseconds: 1_000,
                endMilliseconds: 2_000,
                content: "main jp",
                displayOrder: 0,
                sourceStyle: "MainJP"
            ),
            testCueLine(
                eventIndex: 1,
                startMilliseconds: 1_000,
                endMilliseconds: 2_000,
                content: "main cn",
                displayOrder: 1,
                sourceStyle: "MainCN"
            ),
            testCueLine(
                eventIndex: 2,
                startMilliseconds: 1_000,
                endMilliseconds: 2_000,
                content: "duplicate main cn",
                displayOrder: 2,
                sourceStyle: "MainCN"
            )
        ]
    )

    try database.replaceCueGroups(
        subtitleFile: subtitleFile,
        videoFile: videoFile,
        format: .ass,
        cueGroups: [
            sharedTimestampGroup,
            testCueGroup(
                startMilliseconds: 2_000,
                endMilliseconds: 3_000,
                content: "adjacent main jp",
                eventIndex: 3,
                sourceStyle: "MainJP"
            ),
            testCueGroup(
                startMilliseconds: 2_000,
                endMilliseconds: 3_000,
                content: "adjacent main cn",
                eventIndex: 4,
                sourceStyle: "MainCN"
            ),
            testCueGroup(
                startMilliseconds: 4_000,
                endMilliseconds: 5_000,
                content: "overlap sign",
                eventIndex: 5,
                sourceStyle: "Sign"
            ),
            testCueGroup(
                startMilliseconds: 4_500,
                endMilliseconds: 5_500,
                content: "overlap alt",
                eventIndex: 6,
                sourceStyle: "Alt"
            ),
            testCueGroup(
                startMilliseconds: 90_000,
                endMilliseconds: 91_000,
                content: "last main jp",
                eventIndex: 7,
                sourceStyle: "MainJP"
            ),
            testCueGroup(
                startMilliseconds: 92_000,
                endMilliseconds: 93_000,
                content: "last main cn",
                eventIndex: 8,
                sourceStyle: "MainCN"
            ),
            testCueGroup(
                startMilliseconds: 98_000,
                endMilliseconds: 99_000,
                content: "last subtitle",
                eventIndex: 9,
                sourceStyle: "Credits"
            )
        ]
    )

    let metadata = try #require(try database.playbackFinishMetadata(forSubtitleFile: subtitleFile))
    #expect(metadata.primaryStyles == ["MainCN", "MainJP"])
    #expect(metadata.primaryStyleLastEndMilliseconds == 93_000)
    #expect(metadata.lastSubtitleEndMilliseconds == 99_000)
    #expect(metadata.finishPointMilliseconds(videoDuration: 100) == 93_000)
}

@Test
func playbackFinishMetadataFallsBackToLastSubtitleOrVideoEnd() throws {
    let lastSubtitleMetadata = SubtitlePlaybackFinishMetadata(
        primaryStyles: ["Main"],
        primaryStyleLastEndMilliseconds: 70_000,
        lastSubtitleEndMilliseconds: 90_000
    )
    #expect(lastSubtitleMetadata.finishPointMilliseconds(videoDuration: 100) == 90_000)

    let videoEndMetadata = SubtitlePlaybackFinishMetadata(
        primaryStyles: [],
        primaryStyleLastEndMilliseconds: nil,
        lastSubtitleEndMilliseconds: 70_000
    )
    #expect(videoEndMetadata.finishPointMilliseconds(videoDuration: 100) == 100_000)
    #expect(SubtitlePlaybackFinishMetadata.finishPointMilliseconds(
        metadata: nil,
        videoDuration: 100
    ) == 100_000)
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
func cueTextSelectionReturnsPhysicallyBottommostCueAsSingleCue() throws {
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
    #expect(selection.lines == ["bottom"])
    #expect(selection.text == "bottom")
    #expect(selection.cueEventIndex == 0)
    #expect(selection.cueDisplayOrder == 1)
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

private func sqliteIndexExists(_ name: String, databaseURL: URL) throws -> Bool {
    var database: OpaquePointer?
    guard sqlite3_open_v2(databaseURL.path, &database, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
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
        "SELECT 1 FROM sqlite_master WHERE type = 'index' AND name = ? LIMIT 1;",
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

    let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    sqlite3_bind_text(statement, 1, name, -1, transient)
    return sqlite3_step(statement) == SQLITE_ROW
}

private func sqliteTableExists(_ name: String, databaseURL: URL) throws -> Bool {
    var database: OpaquePointer?
    guard sqlite3_open_v2(databaseURL.path, &database, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
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
        "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ? LIMIT 1;",
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

    let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    sqlite3_bind_text(statement, 1, name, -1, transient)
    return sqlite3_step(statement) == SQLITE_ROW
}

private func expectShioriTagValidationError(
    _ expected: ShioriTagValidationError,
    _ operation: () throws -> Void
) {
    var received: ShioriTagValidationError?
    do {
        try operation()
    } catch let error as ShioriTagValidationError {
        received = error
    } catch {
        Issue.record("Expected ShioriTagValidationError, received \(error)")
    }
    #expect(received == expected)
}

private func testCueGroup(
    startMilliseconds: Int,
    endMilliseconds: Int,
    content: String,
    eventIndex: Int,
    sourceStyle: String? = nil
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
                sourceStyle: sourceStyle,
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
    displayOrder: Int,
    sourceStyle: String? = nil
) -> SubtitleCueLine {
    SubtitleCueLine(
        eventIndex: eventIndex,
        sourceFormat: .ass,
        sourceStyle: sourceStyle,
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

private func createVersionNineteenDatabaseWithLibraryPlaybackHistory(at url: URL) throws {
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
        CREATE TABLE library_playback_history (
            video_path TEXT PRIMARY KEY,
            position_ms INTEGER NOT NULL,
            duration REAL,
            updated_at TEXT NOT NULL
        );

        INSERT INTO library_playback_history(video_path, position_ms, duration, updated_at)
        VALUES
            ('/Media/Started.mkv', 120000, 1000.0, '2026-06-01T00:00:00Z'),
            ('/Media/Completed.mkv', 960000, 1000.0, '2026-06-01T00:01:00Z');

        PRAGMA user_version = 19;
        """
    )
}

private func createVersionTwentyFiveDatabaseWithShiori(at url: URL) throws {
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
        CREATE TABLE shioris (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            subtitle_path TEXT NOT NULL,
            subtitle_format TEXT NOT NULL,
            start_ms INTEGER NOT NULL,
            end_ms INTEGER NOT NULL,
            video_path TEXT NOT NULL,
            video_name TEXT NOT NULL,
            content TEXT NOT NULL,
            is_valid INTEGER NOT NULL DEFAULT 1,
            created_at TEXT NOT NULL,
            UNIQUE(subtitle_path, start_ms, end_ms)
        );

        INSERT INTO shioris(
            subtitle_path,
            subtitle_format,
            start_ms,
            end_ms,
            video_path,
            video_name,
            content,
            is_valid,
            created_at
        )
        VALUES (
            '/Media/Durable.srt',
            'srt',
            1000,
            2000,
            '/Media/Durable.mkv',
            'Durable.mkv',
            'Durable Shiori survives tag migration.',
            1,
            '2026-07-08T00:00:00Z'
        );

        PRAGMA user_version = 25;
        """
    )
}

private func createVersionTwentySevenCueGroupShioriDatabase(at url: URL) throws {
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
        PRAGMA foreign_keys = ON;

        CREATE TABLE subtitle_files (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            subtitle_path TEXT NOT NULL UNIQUE,
            format TEXT NOT NULL,
            file_size INTEGER,
            modified_at REAL,
            indexed_at TEXT NOT NULL,
            index_algorithm_version INTEGER NOT NULL DEFAULT 0
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
            time_range TEXT NOT NULL DEFAULT '',
            search_content TEXT NOT NULL,
            line_count INTEGER NOT NULL DEFAULT 1,
            FOREIGN KEY(subtitle_file_id) REFERENCES subtitle_files(id) ON DELETE CASCADE
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
            display_order INTEGER NOT NULL,
            FOREIGN KEY(cue_group_id) REFERENCES subtitle_cue_groups(id) ON DELETE CASCADE
        );

        CREATE TABLE subtitle_language_detections (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            subtitle_file_id INTEGER NOT NULL,
            scope TEXT NOT NULL,
            scope_key TEXT NOT NULL DEFAULT '',
            algorithm_version INTEGER NOT NULL,
            confidence REAL NOT NULL,
            confidence_band TEXT NOT NULL,
            segment_count INTEGER NOT NULL,
            effective_character_count INTEGER NOT NULL,
            detected_at TEXT NOT NULL,
            UNIQUE(subtitle_file_id, scope, scope_key),
            FOREIGN KEY(subtitle_file_id) REFERENCES subtitle_files(id) ON DELETE CASCADE
        );

        CREATE TABLE subtitle_language_detection_codes (
            detection_id INTEGER NOT NULL,
            language_code TEXT NOT NULL,
            PRIMARY KEY(detection_id, language_code),
            FOREIGN KEY(detection_id) REFERENCES subtitle_language_detections(id) ON DELETE CASCADE
        );

        CREATE TABLE shioris (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            subtitle_path TEXT NOT NULL,
            subtitle_format TEXT NOT NULL,
            start_ms INTEGER NOT NULL,
            end_ms INTEGER NOT NULL,
            video_path TEXT NOT NULL,
            video_name TEXT NOT NULL,
            content TEXT NOT NULL,
            is_valid INTEGER NOT NULL DEFAULT 1,
            created_at TEXT NOT NULL,
            UNIQUE(subtitle_path, start_ms, end_ms)
        );

        CREATE TABLE shiori_tags (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            normalized_name TEXT NOT NULL UNIQUE,
            created_at TEXT NOT NULL
        );

        CREATE TABLE shiori_tag_assignments (
            shiori_id INTEGER NOT NULL,
            tag_id INTEGER NOT NULL,
            created_at TEXT NOT NULL,
            PRIMARY KEY(shiori_id, tag_id),
            FOREIGN KEY(shiori_id) REFERENCES shioris(id) ON DELETE CASCADE,
            FOREIGN KEY(tag_id) REFERENCES shiori_tags(id) ON DELETE CASCADE
        );

        INSERT INTO subtitle_files(
            id, subtitle_path, format, file_size, modified_at, indexed_at, index_algorithm_version
        )
        VALUES
            (1, '/Media/Legacy.ass', 'ass', 1000, 0, '2026-07-10T00:00:00Z', 3),
            (2, '/Media/Fallback.ass', 'ass', 1000, 0, '2026-07-10T00:00:00Z', 3),
            (3, '/Media/Mixed.ass', 'ass', 1000, 0, '2026-07-10T00:00:00Z', 3),
            (4, '/Media/MixedStyle.ass', 'ass', 1000, 0, '2026-07-10T00:00:00Z', 3);

        INSERT INTO subtitle_cue_groups(
            id, subtitle_file_id, subtitle_path, seq, start_time, end_time,
            start_ms, end_ms, time_range, search_content, line_count
        )
        VALUES
            (1, 1, '/Media/Legacy.ass', NULL, '0:00:01.00', '0:00:03.00',
             1000, 3000, '00:01 - 00:03', '日本語の字幕です\n日本語の下段です\n中文字幕', 3),
            (2, 2, '/Media/Fallback.ass', NULL, '0:00:04.00', '0:00:05.00',
             4000, 5000, '00:04 - 00:05', 'Upper fallback cue\nLower fallback cue', 2),
            (3, 3, '/Media/Mixed.ass', NULL, '0:00:08.00', '0:00:09.00',
             8000, 9000, '00:08 - 00:09', 'これは日本語です\n这是中文字幕', 2),
            (4, 4, '/Media/MixedStyle.ass', NULL, '0:00:10.00', '0:00:11.00',
             10000, 11000, '00:10 - 00:11', 'これは同じスタイルの日本語です\n这是同一样式的中文字幕', 2);

        INSERT INTO subtitle_cue_lines(
            id, cue_group_id, event_index, source_format, source_style, source_layer,
            start_time, end_time, start_ms, end_ms, content, display_x, display_y, display_order
        )
        VALUES
            (10, 1, 100, 'ass', 'ZH', 0, '0:00:01.20', '0:00:02.80',
             1200, 2800, '中文字幕', NULL, 300, 2),
            (11, 1, 101, 'ass', 'JP', 0, '0:00:01.10', '0:00:02.90',
             1100, 2900, '日本語の字幕です', NULL, 100, 0),
            (12, 1, 102, 'ass', 'JP', 0, '0:00:01.05', '0:00:02.95',
             1050, 2950, '日本語の下段です', NULL, 200, 1),
            (20, 2, 200, 'ass', NULL, 0, '0:00:04.10', '0:00:04.90',
             4100, 4900, 'Upper fallback cue', NULL, 100, 0),
            (21, 2, 201, 'ass', NULL, 0, '0:00:04.20', '0:00:04.80',
             4200, 4800, 'Lower fallback cue', NULL, 200, 1),
            (30, 3, 300, 'ass', NULL, 0, '0:00:08.00', '0:00:09.00',
             8000, 9000, 'これは日本語です', NULL, 100, 0),
            (31, 3, 301, 'ass', NULL, 0, '0:00:08.00', '0:00:09.00',
             8000, 9000, '这是中文字幕', NULL, 200, 1),
            (40, 4, 400, 'ass', 'MIXED', 0, '0:00:10.00', '0:00:11.00',
             10000, 11000, 'これは同じスタイルの日本語です', NULL, 100, 0),
            (41, 4, 401, 'ass', 'MIXED', 0, '0:00:10.00', '0:00:11.00',
             10000, 11000, '这是同一样式的中文字幕', NULL, 200, 1);

        INSERT INTO subtitle_language_detections(
            id, subtitle_file_id, scope, scope_key, algorithm_version, confidence,
            confidence_band, segment_count, effective_character_count, detected_at
        )
        VALUES
            (1, 1, 'style', 'ZH', 2, 0.99, 'high', 10, 100, '2026-07-10T00:00:00Z'),
            (2, 1, 'style', 'JP', 2, 0.99, 'high', 10, 100, '2026-07-10T00:00:00Z'),
            (3, 3, 'file', '', 2, 0.99, 'high', 10, 100, '2026-07-10T00:00:00Z'),
            (4, 4, 'style', 'MIXED', 2, 0.99, 'high', 10, 100, '2026-07-10T00:00:00Z');

        INSERT INTO subtitle_language_detection_codes(detection_id, language_code)
        VALUES
            (1, 'zh-Hans'),
            (2, 'ja'),
            (3, 'ja'),
            (3, 'zh-Hans'),
            (4, 'ja'),
            (4, 'zh-Hans');

        INSERT INTO shioris(
            id, subtitle_path, subtitle_format, start_ms, end_ms,
            video_path, video_name, content, is_valid, created_at
        )
        VALUES
            (42, '/Media/Legacy.ass', 'ass', 1000, 3000,
             '/Media/Legacy.mkv', 'Legacy.mkv', '日本語の字幕です\n日本語の下段です\n中文字幕', 0,
             '2026-07-10T01:02:03Z'),
            (43, '/Media/Missing.ass', 'ass', 6000, 7000,
             '/Media/Missing.mkv', 'Missing.mkv', 'Unindexed Japanese and Chinese snapshot', 1,
             '2026-07-10T02:03:04Z'),
            (44, '/Media/Fallback.ass', 'ass', 4000, 5000,
             '/Media/Fallback.mkv', 'Fallback.mkv', 'Upper fallback cue\nLower fallback cue', 1,
             '2026-07-10T03:04:05Z'),
            (45, '/Media/Mixed.ass', 'ass', 8000, 9000,
             '/Media/Mixed.mkv', 'Mixed.mkv', 'これは日本語です\n这是中文字幕', 1,
             '2026-07-10T04:05:06Z'),
            (46, '/Media/MixedStyle.ass', 'ass', 10000, 11000,
             '/Media/MixedStyle.mkv', 'MixedStyle.mkv',
             'これは同じスタイルの日本語です\n这是同一样式的中文字幕', 1,
             '2026-07-10T05:06:07Z');

        INSERT INTO shiori_tags(id, name, normalized_name, created_at)
        VALUES (7, 'Review', 'Review', '2026-07-10T00:00:00Z');

        INSERT INTO shiori_tag_assignments(shiori_id, tag_id, created_at)
        VALUES
            (42, 7, '2026-07-10T01:02:04Z'),
            (43, 7, '2026-07-10T02:03:05Z');

        PRAGMA user_version = 27;
        """
    )
}

private func createVersionTwentySixDatabaseWithLibraryCover(at url: URL) throws {
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
        CREATE TABLE video_files (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            path TEXT NOT NULL UNIQUE,
            video_name TEXT NOT NULL,
            file_size INTEGER,
            modified_at REAL,
            duration REAL,
            video_width INTEGER,
            video_height INTEGER,
            frame_rate REAL,
            video_codec TEXT,
            audio_codec TEXT,
            native_video_candidate INTEGER,
            native_audio_candidate INTEGER,
            native_compatibility_reason TEXT,
            native_failure_reason TEXT,
            compatibility_evaluated_at TEXT
        );

        CREATE TABLE video_covers (
            video_file_id INTEGER PRIMARY KEY,
            cover_path TEXT NOT NULL,
            source_time_ms INTEGER NOT NULL,
            score REAL,
            algorithm_version INTEGER NOT NULL,
            generated_file_size INTEGER,
            generated_duration REAL,
            status TEXT NOT NULL,
            error_message TEXT,
            generated_at TEXT NOT NULL,
            FOREIGN KEY(video_file_id) REFERENCES video_files(id) ON DELETE CASCADE
        );

        CREATE TABLE folder_covers (
            folder_path TEXT PRIMARY KEY,
            cover_path TEXT NOT NULL,
            source_video_file_id INTEGER NOT NULL,
            generated_at TEXT NOT NULL,
            FOREIGN KEY(source_video_file_id) REFERENCES video_files(id) ON DELETE CASCADE
        );

        INSERT INTO video_files(id, path, video_name, file_size, duration)
        VALUES (1, '/Media/Legacy Show/Episode 1.mkv', 'Episode 1.mkv', 2048, 1400.0);

        INSERT INTO video_covers(
            video_file_id,
            cover_path,
            source_time_ms,
            score,
            algorithm_version,
            generated_file_size,
            generated_duration,
            status,
            error_message,
            generated_at
        )
        VALUES (
            1,
            '/Covers/Videos/legacy-master.jpg',
            120000,
            88.0,
            1,
            2048,
            1400.0,
            'generated',
            NULL,
            '2026-07-10T00:00:00Z'
        );

        INSERT INTO folder_covers(folder_path, cover_path, source_video_file_id, generated_at)
        VALUES (
            '/Media/Legacy Show',
            '/Covers/Videos/legacy-master.jpg',
            1,
            '2026-07-10T00:00:00Z'
        );

        PRAGMA user_version = 26;
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
