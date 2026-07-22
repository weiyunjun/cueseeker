import Foundation
import SQLite3
import Testing
@testable import CueSeekerCore

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

private final class ShioriTableCancellationRowReadProbe: @unchecked Sendable {
    private let lock = NSLock()
    private var maximum = 0

    func record(_ count: Int) {
        lock.lock()
        maximum = max(maximum, count)
        lock.unlock()
    }

    var maximumReadCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return maximum
    }
}

@Test
func migratesFreshDatabaseToCurrentSchemaVersion() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    try DatabaseBootstrap.prepare(at: databaseURL)
    let database = try SubtitleDatabase(path: databaseURL)

    #expect(try database.schemaVersion() == DatabaseBootstrap.currentSchemaVersion)
}

@Test
func currentSchemaValidationDoesNotMutateStoredData() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    try DatabaseBootstrap.prepare(at: databaseURL)
    let database = try SubtitleDatabase(path: databaseURL)
    let folder = URL(fileURLWithPath: "/Media/Current Schema")
    _ = try database.addSearchPath(folder)

    try DatabaseBootstrap.prepare(at: databaseURL)

    #expect(try database.schemaVersion() == DatabaseBootstrap.currentSchemaVersion)
    #expect(try sqliteRowCount(in: "search_paths", databaseURL: databaseURL) == 1)
}

@Test
func rejectsUnsupportedLowerSchemaWithoutChangingVersion() throws {
    try expectUnsupportedSchemaVersion(32)
}

@Test
func rejectsNewerSchemaWithoutChangingVersion() throws {
    try expectUnsupportedSchemaVersion(34)
}

@Test
func readOnlyConnectionDoesNotCreateMissingDatabase() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    #expect(throws: (any Error).self) {
        _ = try SubtitleDatabase(path: databaseURL, access: .readOnly)
    }
    #expect(!FileManager.default.fileExists(atPath: databaseURL.path))
}

@Test
func readOnlyConnectionRejectsWrites() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    try DatabaseBootstrap.prepare(at: databaseURL)
    let database = try SubtitleDatabase(path: databaseURL, access: .readOnly)

    #expect(throws: SQLiteDatabaseError.self) {
        _ = try database.addSearchPath(URL(fileURLWithPath: "/Media/Read Only"))
    }
    #expect(try sqliteRowCount(in: "search_paths", databaseURL: databaseURL) == 0)
}

@Test
func freshSchemaOmitsLegacyPlaybackNavigationTables() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    try DatabaseBootstrap.prepare(at: databaseURL)

    #expect(try sqliteTableExists(
        "playback_navigation_state",
        databaseURL: databaseURL
    ) == false)
    #expect(try sqliteTableExists(
        "playback_navigation_entries",
        databaseURL: databaseURL
    ) == false)
}

@Test
func permanentIdentitySchemaIncludesLibraryRelativePathsAndIDReferences() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    try DatabaseBootstrap.prepare(at: databaseURL)

    #expect(try sqliteColumnNames(in: "subtitle_files", databaseURL: databaseURL).isSuperset(of: [
        "id", "library_id", "relative_path"
    ]))
    #expect(try sqliteColumnNames(in: "video_files", databaseURL: databaseURL).isSuperset(of: [
        "id", "library_id", "relative_path"
    ]))
    #expect(try sqliteColumnNames(in: "subtitle_cue_lines", databaseURL: databaseURL).isSuperset(of: [
        "id", "subtitle_file_id"
    ]))
    #expect(try sqliteColumnNames(in: "library_playback_history", databaseURL: databaseURL).contains("video_file_id"))
    #expect(try sqliteColumnNames(in: "library_watch_states", databaseURL: databaseURL).contains("video_file_id"))
    #expect(try sqliteColumnNames(in: "library_video_rows", databaseURL: databaseURL).isSuperset(of: [
        "video_file_id", "subtitle_file_id"
    ]))
    #expect(try sqliteColumnNames(in: "subtitle_search_order_rows", databaseURL: databaseURL).contains("subtitle_file_id"))
    #expect(try sqliteColumnNames(in: "shioris", databaseURL: databaseURL) == Set([
        "id", "list_id", "cue_id", "created_at"
    ]))
    #expect(try sqliteTableExists("shiori_lists", databaseURL: databaseURL))
}

@Test
func indexedMediaStoresLibraryIDAndRelativePaths() throws {
    let databaseURL = temporaryDatabaseURL()
    let libraryFolder = FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerIdentityLibrary-\(UUID().uuidString)")
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try DatabaseBootstrap.prepare(at: databaseURL)
    let libraryID = try database.addSearchPath(libraryFolder)
    let subtitleFile = libraryFolder
        .appendingPathComponent("Season 1")
        .appendingPathComponent("Episode 1.srt")
    let videoFile = libraryFolder
        .appendingPathComponent("Season 1")
        .appendingPathComponent("Episode 1.mkv")

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
                text: "relative identity"
            )
        ]
    )

    let subtitleIdentity = try sqliteMediaIdentity(
        table: "subtitle_files",
        pathColumn: "subtitle_path",
        path: subtitleFile.path,
        databaseURL: databaseURL
    )
    #expect(subtitleIdentity?.libraryID == libraryID)
    #expect(subtitleIdentity?.relativePath == "Season 1/Episode 1.srt")

    let videoIdentity = try sqliteMediaIdentity(
        table: "video_files",
        pathColumn: "path",
        path: videoFile.path,
        databaseURL: databaseURL
    )
    #expect(videoIdentity?.libraryID == libraryID)
    #expect(videoIdentity?.relativePath == "Season 1/Episode 1.mkv")
    #expect(try sqliteCueLinesReferenceSubtitleFile(databaseURL: databaseURL))
}

@Test
func reindexPreservesSubtitleIDAndLibraryStateReferencesVideoID() throws {
    let databaseURL = temporaryDatabaseURL()
    let libraryFolder = FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerPermanentState-\(UUID().uuidString)")
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try DatabaseBootstrap.prepare(at: databaseURL)
    _ = try database.addSearchPath(libraryFolder)
    let subtitleFile = libraryFolder.appendingPathComponent("Episode.srt")
    let videoFile = libraryFolder.appendingPathComponent("Episode.mkv")

    try database.replaceEntries(
        subtitleFile: subtitleFile,
        videoFile: videoFile,
        entries: [simpleTestEntry(text: "before")]
    )
    let originalSubtitleID = try #require(
        try sqliteRowID(
            table: "subtitle_files",
            pathColumn: "subtitle_path",
            path: subtitleFile.path,
            databaseURL: databaseURL
        )
    )
    let videoID = try #require(
        try sqliteRowID(
            table: "video_files",
            pathColumn: "path",
            path: videoFile.path,
            databaseURL: databaseURL
        )
    )

    try database.upsertLibraryPlaybackHistory(
        videoFile: videoFile,
        positionMilliseconds: 1_500,
        duration: 24 * 60
    )
    try database.rebuildLibraryPresentationSnapshot()
    try database.replaceEntries(
        subtitleFile: subtitleFile,
        videoFile: videoFile,
        entries: [simpleTestEntry(text: "after")]
    )

    #expect(
        try sqliteRowID(
            table: "subtitle_files",
            pathColumn: "subtitle_path",
            path: subtitleFile.path,
            databaseURL: databaseURL
        ) == originalSubtitleID
    )
    #expect(
        try sqliteReferencedID(
            table: "library_playback_history",
            idColumn: "video_file_id",
            pathColumn: "video_path",
            path: videoFile.path,
            databaseURL: databaseURL
        ) == videoID
    )
    #expect(
        try sqliteReferencedID(
            table: "library_watch_states",
            idColumn: "video_file_id",
            pathColumn: "video_path",
            path: videoFile.path,
            databaseURL: databaseURL
        ) == videoID
    )
}

@Test
func sqliteConnectionsUseBusyTimeoutAndWALMode() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    try DatabaseBootstrap.prepare(at: databaseURL)
    let database = try DatabaseMaintenanceDatabase(path: databaseURL)

    #expect(try database.busyTimeoutMilliseconds() == DatabaseMaintenanceDatabase.configuredBusyTimeoutMilliseconds)
    #expect(try database.journalMode().lowercased() == "wal")
    #expect(try database.synchronousMode() == 1)
    #expect(try database.cacheSize() == -DatabaseMaintenanceDatabase.configuredCacheSizeKibibytes)
    #expect(try database.mmapSize() == DatabaseMaintenanceDatabase.configuredMmapSizeBytes)
}

@Test
func visibleSearchReadersRejectPreCancelledTasks() async throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let searchTask = Task.detached { () throws -> SubtitleSearchPage in
        let database = try SubtitleDatabase(path: databaseURL)
        try DatabaseBootstrap.prepare(at: databaseURL)
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
func recentLibraryWatchingRejectsPreCancelledTasks() async throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    try DatabaseBootstrap.prepare(at: databaseURL)

    let recentTask = Task.detached { () throws -> [RecentLibraryWatchingPresentation] in
        let database = try SubtitleDatabase(path: databaseURL)
        withUnsafeCurrentTask { task in
            task?.cancel()
        }
        return try database.recentLibraryWatching(
            under: [URL(fileURLWithPath: "/Media")],
            limit: Int.max
        )
    }
    do {
        _ = try await recentTask.value
        Issue.record("Expected cancelled Recent query to stop")
    } catch is CancellationError {
        // Expected.
    }
}

@Test
func completeLibraryReadersRejectPreCancelledTasks() async throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    try DatabaseBootstrap.prepare(at: databaseURL)

    let summariesTask = Task.detached {
        () throws -> [CompleteLibraryFolderSummaryPresentation] in
        let database = try SubtitleDatabase(path: databaseURL)
        withUnsafeCurrentTask { task in
            task?.cancel()
        }
        return try database.completeLibraryFolderSummaries(
            under: [URL(fileURLWithPath: "/Media")]
        )
    }
    do {
        _ = try await summariesTask.value
        Issue.record("Expected cancelled Library summary query to stop")
    } catch is CancellationError {
        // Expected.
    }

    let detailTask = Task.detached {
        () throws -> CompleteLibraryFolderDetailPresentation? in
        let database = try SubtitleDatabase(path: databaseURL)
        withUnsafeCurrentTask { task in
            task?.cancel()
        }
        return try database.completeLibraryFolderDetail(
            folderPath: "/Media/Show"
        )
    }
    do {
        _ = try await detailTask.value
        Issue.record("Expected cancelled Library detail query to stop")
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
    try DatabaseBootstrap.prepare(at: databaseURL)

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
    try DatabaseBootstrap.prepare(at: databaseURL)

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
    try DatabaseBootstrap.prepare(at: databaseURL)

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

    let contextCues = try database.cueLineRecords(forSubtitleFile: contextSubtitleFile)
    let firstContextCue = try #require(contextCues.first)
    let thirdContextCue = try #require(contextCues.first { $0.line.content == "context cue 3" })
    let lastContextCue = try #require(contextCues.first { $0.line.content == "context cue 6" })

    #expect(
        try database.firstCueID(forSubtitleFile: contextSubtitleFile) == firstContextCue.id
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
    try DatabaseBootstrap.prepare(at: databaseURL)

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
    try DatabaseBootstrap.prepare(at: databaseURL)

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
    try DatabaseBootstrap.prepare(at: databaseURL)

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
    try DatabaseBootstrap.prepare(at: databaseURL)

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

    let maintenance = try DatabaseMaintenanceDatabase(path: databaseURL)
    let statsAfterClear = try maintenance.storageStats()
    #expect(statsAfterClear.pageSize > 0)
    #expect(statsAfterClear.pageCount > 0)
    #expect(statsAfterClear.freelistCount > 0)
    #expect(statsAfterClear.freelistBytes > 0)
    #expect(statsAfterClear.databaseFileBytes > 0)

    try maintenance.compactStorage()

    let statsAfterCompact = try maintenance.storageStats()
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
    try DatabaseBootstrap.prepare(at: databaseURL)

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

@Test
func storesSubtitleEntriesAndSearchesWithFTS5() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try DatabaseBootstrap.prepare(at: databaseURL)

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
    try DatabaseBootstrap.prepare(at: databaseURL)

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
    try DatabaseBootstrap.prepare(at: databaseURL)

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
    try DatabaseBootstrap.prepare(at: databaseURL)

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
    try DatabaseBootstrap.prepare(at: databaseURL)

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
    try DatabaseBootstrap.prepare(at: databaseURL)

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
    try DatabaseBootstrap.prepare(at: databaseURL)

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
    try DatabaseBootstrap.prepare(at: databaseURL)

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
    try DatabaseBootstrap.prepare(at: databaseURL)

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
    try DatabaseBootstrap.prepare(at: databaseURL)

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
    try DatabaseBootstrap.prepare(at: databaseURL)

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
    try DatabaseBootstrap.prepare(at: databaseURL)

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
    try DatabaseBootstrap.prepare(at: databaseURL)

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
    try DatabaseBootstrap.prepare(at: databaseURL)

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
    try DatabaseBootstrap.prepare(at: databaseURL)

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
    try DatabaseBootstrap.prepare(at: databaseURL)

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
    try DatabaseBootstrap.prepare(at: databaseURL)

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
    try DatabaseBootstrap.prepare(at: databaseURL)

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
    try DatabaseBootstrap.prepare(at: databaseURL)

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
func repeatedSearchPagesExecuteWithoutHiddenCacheEvents() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try DatabaseBootstrap.prepare(at: databaseURL)

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
    #expect(firstPage == secondPage)
    #expect(!firstDiagnostics.events.contains { $0.name.hasPrefix("search_cache_") })
    #expect(!secondDiagnostics.events.contains { $0.name.hasPrefix("search_cache_") })
    #expect(firstDiagnostics.events.contains { $0.name == "fts_batch" })
    #expect(secondDiagnostics.events.contains { $0.name == "fts_batch" })
}

@Test
func searchPageSeesIndexedContentChangesImmediately() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try DatabaseBootstrap.prepare(at: databaseURL)

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
    #expect(page.totalCount == 2)
    #expect(page.results.map(\.content) == [
        "Cache invalidation first",
        "Cache invalidation second"
    ])
    #expect(!diagnostics.events.contains { $0.name.hasPrefix("search_cache_") })
}

@Test
func searchVisiblePageUsesProductOrderedFTSRowIDsForEarlyTermination() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try DatabaseBootstrap.prepare(at: databaseURL)

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
    try DatabaseBootstrap.prepare(at: databaseURL)

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
    try DatabaseBootstrap.prepare(at: databaseURL)

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
    try DatabaseBootstrap.prepare(at: databaseURL)

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
    try DatabaseBootstrap.prepare(at: databaseURL)

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
    try DatabaseBootstrap.prepare(at: databaseURL)

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
    try DatabaseBootstrap.prepare(at: databaseURL)

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
    try DatabaseBootstrap.prepare(at: databaseURL)

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

    try LibraryDatabase(path: databaseURL).updateVideoDuration(videoFile: show2Episode2Video, duration: 125.4)

    let videos = try LibraryDatabase(path: databaseURL).libraryVideos(under: [URL(fileURLWithPath: "/Media")])

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
    try DatabaseBootstrap.prepare(at: databaseURL)

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
    try LibraryDatabase(path: databaseURL).updateVideoDuration(videoFile: episode2Video, duration: 125.4)

    let videos = try LibraryCoverDatabase(path: databaseURL).libraryCoverEligibleVideos(under: [URL(fileURLWithPath: "/Media")])

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
    try DatabaseBootstrap.prepare(at: databaseURL)

    let videoURL = URL(fileURLWithPath: "/Media/Show/Episode 1.mkv")
    try database.replaceEntries(
        subtitleFile: URL(fileURLWithPath: "/Media/Show/Episode 1.srt"),
        videoFile: videoURL,
        entries: [databaseTestEntry(text: "Cover candidate")]
    )
    try LibraryDatabase(path: databaseURL).updateVideoDuration(videoFile: videoURL, duration: 1440.25)

    let videos = try LibraryCoverDatabase(path: databaseURL).libraryCoverEligibleVideos(under: [URL(fileURLWithPath: "/Media")])
    let video = try #require(videos.first)
    try LibraryCoverDatabase(path: databaseURL).upsertLibraryVideoCover(
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
    let storedCover = try LibraryCoverDatabase(path: databaseURL).libraryVideoCover(forVideoFileID: video.videoFileID)
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

    try LibraryCoverDatabase(path: databaseURL).upsertLibraryFolderCover(
        folderPath: video.folderPath,
        masterCoverPath: cover.masterCoverPath,
        sourceVideoFileID: video.videoFileID
    )

    let storedFolderCover = try LibraryCoverDatabase(path: databaseURL).libraryFolderCover(folderPath: video.folderPath)
    let folderCover = try #require(storedFolderCover)
    #expect(folderCover.folderPath == "/Media/Show")
    #expect(folderCover.masterCoverPath == cover.masterCoverPath)
    #expect(folderCover.sourceVideoFileID == video.videoFileID)

    try LibraryCoverDatabase(path: databaseURL).updateLibraryVideoDisplayCover(
        videoFileID: video.videoFileID,
        displayCoverPath: nil,
        displayProfileVersion: nil
    )
    let clearedDisplayCover = try #require(
        try LibraryCoverDatabase(path: databaseURL).libraryVideoCover(forVideoFileID: video.videoFileID)
    )
    #expect(clearedDisplayCover.masterCoverPath == cover.masterCoverPath)
    #expect(clearedDisplayCover.displayCoverPath == nil)
    #expect(clearedDisplayCover.displayProfileVersion == nil)
}

@Test
func userLibraryCoversOverrideIndexCoversWithoutMutatingThem() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try DatabaseBootstrap.prepare(at: databaseURL)

    let root = URL(fileURLWithPath: "/Media")
    let folderPath = "/Media/Show"
    let videoFile = URL(fileURLWithPath: "/Media/Show/Episode 1.mkv")
    try database.replaceEntries(
        subtitleFile: URL(fileURLWithPath: "/Media/Show/Episode 1.srt"),
        videoFile: videoFile,
        entries: [databaseTestEntry(text: "Cover precedence")]
    )
    try database.rebuildLibraryPresentationSnapshot()
    try database.upsertLibraryPlaybackHistory(
        videoFile: videoFile,
        positionMilliseconds: 10_000,
        duration: 100
    )

    let candidate = try #require(
        try LibraryCoverDatabase(path: databaseURL).libraryCoverEligibleVideos(under: [root]).first
    )
    try LibraryCoverDatabase(path: databaseURL).upsertLibraryVideoCover(
        videoFileID: candidate.videoFileID,
        masterCoverPath: "/Covers/Videos/index-master.jpg",
        displayCoverPath: "/Covers/Display/v1/index-display.jpg",
        displayProfileVersion: LibraryCoverDisplayProfileVersion.current,
        sourceTimeMilliseconds: 1_000,
        score: 80,
        algorithmVersion: 1,
        generatedFileSize: candidate.fileSize,
        generatedDuration: candidate.duration,
        status: .generated,
        errorMessage: nil
    )
    try LibraryCoverDatabase(path: databaseURL).upsertLibraryFolderCover(
        folderPath: folderPath,
        masterCoverPath: "/Covers/Videos/index-master.jpg",
        sourceVideoFileID: candidate.videoFileID
    )

    try LibraryCoverDatabase(path: databaseURL).upsertLibraryUserVideoCover(
        forVideoFile: videoFile,
        displayCoverPath: "/Covers/User/Display/v1/user-video.jpg"
    )
    try LibraryCoverDatabase(path: databaseURL).upsertLibraryUserFolderCover(
        folderPath: folderPath,
        displayCoverPath: "/Covers/User/Display/v1/user-folder.jpg"
    )

    let userVideoCover = try #require(
        try LibraryCoverDatabase(path: databaseURL).libraryUserVideoCover(forVideoFile: videoFile)
    )
    let userFolderCover = try #require(
        try LibraryCoverDatabase(path: databaseURL).libraryUserFolderCover(folderPath: folderPath)
    )
    #expect(userVideoCover.displayCoverPath == "/Covers/User/Display/v1/user-video.jpg")
    #expect(userFolderCover.displayCoverPath == "/Covers/User/Display/v1/user-folder.jpg")

    let recent = try #require(try database.recentLibraryWatching(under: [root]).first)
    #expect(recent.coverPath == userVideoCover.displayCoverPath)
    #expect(recent.coverRevision == userVideoCover.revision)

    let complete = try #require(try database.completeLibraryPresentation(under: [root]).first)
    #expect(complete.folderCoverPath == userFolderCover.displayCoverPath)
    #expect(complete.folderCoverRevision == userFolderCover.revision)
    #expect(complete.videos.first?.coverPath == userVideoCover.displayCoverPath)
    #expect(complete.videos.first?.coverRevision == userVideoCover.revision)

    let summary = try #require(try database.completeLibraryFolderSummaries(under: [root]).first)
    #expect(summary.coverPath == userFolderCover.displayCoverPath)
    #expect(summary.coverRevision == userFolderCover.revision)

    let detail = try #require(try database.completeLibraryFolderDetail(folderPath: folderPath))
    #expect(detail.videos.first?.coverPath == userVideoCover.displayCoverPath)
    #expect(detail.videos.first?.coverRevision == userVideoCover.revision)

    try LibraryCoverDatabase(path: databaseURL).upsertLibraryVideoCover(
        videoFileID: candidate.videoFileID,
        masterCoverPath: "/Covers/Videos/reindexed-master.jpg",
        displayCoverPath: "/Covers/Display/v1/reindexed-display.jpg",
        displayProfileVersion: LibraryCoverDisplayProfileVersion.current,
        sourceTimeMilliseconds: 2_000,
        score: 90,
        algorithmVersion: 2,
        generatedFileSize: candidate.fileSize,
        generatedDuration: candidate.duration,
        status: .generated,
        errorMessage: nil
    )

    let reindexedCover = try #require(
        try LibraryCoverDatabase(path: databaseURL).libraryVideoCover(forVideoFileID: candidate.videoFileID)
    )
    #expect(reindexedCover.displayCoverPath == "/Covers/Display/v1/reindexed-display.jpg")
    #expect(
        try database.recentLibraryWatching(under: [root]).first?.coverPath
            == userVideoCover.displayCoverPath
    )

    try LibraryCoverDatabase(path: databaseURL).upsertLibraryUserVideoCover(
        forVideoFile: videoFile,
        displayCoverPath: "/Covers/User/Display/v1/replacement-video.jpg"
    )
    try LibraryCoverDatabase(path: databaseURL).upsertLibraryUserFolderCover(
        folderPath: folderPath,
        displayCoverPath: "/Covers/User/Display/v1/replacement-folder.jpg"
    )
    #expect(
        try LibraryCoverDatabase(path: databaseURL).libraryUserVideoCover(forVideoFile: videoFile)?.displayCoverPath
            == "/Covers/User/Display/v1/replacement-video.jpg"
    )
    #expect(
        try LibraryCoverDatabase(path: databaseURL).libraryUserFolderCover(folderPath: folderPath)?.displayCoverPath
            == "/Covers/User/Display/v1/replacement-folder.jpg"
    )
}

@Test
func libraryPresentationSnapshotStoresReadyDisplayRows() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try DatabaseBootstrap.prepare(at: databaseURL)

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
    try LibraryDatabase(path: databaseURL).updateVideoDuration(videoFile: episode2Video, duration: 125.4)

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
    try DatabaseBootstrap.prepare(at: databaseURL)

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
    try DatabaseBootstrap.prepare(at: databaseURL)

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
    try DatabaseBootstrap.prepare(at: databaseURL)

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
    try DatabaseBootstrap.prepare(at: databaseURL)

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
    try DatabaseBootstrap.prepare(at: databaseURL)

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
    try DatabaseBootstrap.prepare(at: databaseURL)

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
    try DatabaseBootstrap.prepare(at: databaseURL)

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
        try LibraryDatabase(path: databaseURL).updateVideoDuration(videoFile: videoFile, duration: 1_000.0)
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
    try DatabaseBootstrap.prepare(at: databaseURL)

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
        try LibraryDatabase(path: databaseURL).updateVideoDuration(videoFile: videoFile, duration: 1_000.0)
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
    try DatabaseBootstrap.prepare(at: databaseURL)

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
        try LibraryDatabase(path: databaseURL).updateVideoDuration(videoFile: videoFile, duration: 1_000.0)
    }
    try LibraryDatabase(path: databaseURL).updateVideoMetadata(
        videoFile: showA1,
        duration: 1_000.0,
        videoWidth: 1920,
        videoHeight: 1080,
        frameRate: 23.976,
        videoCodec: "hevc"
    )
    try database.rebuildLibraryPresentationSnapshot()

    let eligibleVideos = try LibraryCoverDatabase(path: databaseURL).libraryCoverEligibleVideos(under: [root])
    let showA1CoverCandidate = try #require(eligibleVideos.first { $0.videoPath == showA1.path })
    try LibraryCoverDatabase(path: databaseURL).upsertLibraryVideoCover(
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
        try LibraryCoverDatabase(path: databaseURL).libraryVideoCover(forVideoFileID: showA1CoverCandidate.videoFileID)
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
    try DatabaseBootstrap.prepare(at: databaseURL)

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
        try LibraryCoverDatabase(path: databaseURL).libraryCoverEligibleVideos(under: [root]).first
    )
    let masterPath = "/Covers/Videos/master-must-not-render.jpg"
    let displayPath = "/Covers/Display/v1/display.jpg"
    try LibraryCoverDatabase(path: databaseURL).upsertLibraryVideoCover(
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
    try LibraryCoverDatabase(path: databaseURL).upsertLibraryFolderCover(
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

    try LibraryCoverDatabase(path: databaseURL).updateLibraryVideoDisplayCover(
        videoFileID: candidate.videoFileID,
        displayCoverPath: displayPath,
        displayProfileVersion: LibraryCoverDisplayProfileVersion.current
    )
    let displayRevision = try #require(
        try LibraryCoverDatabase(path: databaseURL).libraryVideoCover(forVideoFileID: candidate.videoFileID)
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

    try LibraryCoverDatabase(path: databaseURL).updateLibraryVideoDisplayCover(
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
    try DatabaseBootstrap.prepare(at: databaseURL)

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
func cueContentsResolveCurrentCueDataInRequestedOrder() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try DatabaseBootstrap.prepare(at: databaseURL)
    let subtitleFile = URL(fileURLWithPath: "/Media/Show/Cue Contents.srt")
    let videoFile = URL(fileURLWithPath: "/Media/Show/Cue Contents.mkv")
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
                text: "First canonical Cue."
            ),
            SubtitleEntry(
                sequenceNumber: 2,
                startTimecode: "00:00:03,000",
                endTimecode: "00:00:04,000",
                startMilliseconds: 3_000,
                endMilliseconds: 4_000,
                text: "Second canonical Cue."
            ),
        ]
    )
    let firstID = try #require(try database.cueTextSelection(
        forSubtitleFile: subtitleFile,
        atMilliseconds: 1_500
    )?.cueLineID)
    let secondID = try #require(try database.cueTextSelection(
        forSubtitleFile: subtitleFile,
        atMilliseconds: 3_500
    )?.cueLineID)

    let contents = try database.cueContents(
        forCueIDs: [secondID, firstID, secondID, -1]
    )
    #expect(contents.map(\.cueID) == [secondID, firstID])
    #expect(contents.map(\.content) == [
        "Second canonical Cue.",
        "First canonical Cue.",
    ])
    #expect(contents.allSatisfy { $0.videoPath == videoFile.path })
}

@Test
func shioriResidentSnapshotLoadsRelationsCurrentCueContentAndTagsTogether() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try DatabaseBootstrap.prepare(at: databaseURL)
    let subtitleFile = URL(fileURLWithPath: "/Media/Show/Resident Shiori.srt")
    let videoFile = URL(fileURLWithPath: "/Media/Show/Resident Shiori.mkv")
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
                text: "Resident Cue"
            ),
        ]
    )
    let selection = try #require(try database.cueTextSelection(
        forSubtitleFile: subtitleFile,
        atMilliseconds: 1_500
    ))
    let saved = try database.upsertShiori(
        subtitleFile: subtitleFile,
        subtitleFormat: .srt,
        videoFile: videoFile,
        videoName: videoFile.lastPathComponent,
        selection: selection,
        createdAt: Date(timeIntervalSince1970: 1_700_000_000)
    )
    let tag = try database.assignShioriTag(
        named: "Review",
        toShioriID: saved.id
    )

    let snapshot = try database.shioriResidentSnapshot()

    #expect(snapshot.relations.map(\.id) == [saved.id])
    #expect(snapshot.relations.map(\.cueID) == snapshot.cueContents.map(\.cueID))
    #expect(snapshot.cueContents.map(\.content) == ["Resident Cue"])
    #expect(snapshot.tagsByShioriID[saved.id] == [tag])
}

@Test
func shioriRelationSchemaAllowsOneCueInDifferentListsOnly() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try DatabaseBootstrap.prepare(at: databaseURL)

    let subtitleFile = URL(fileURLWithPath: "/Media/Show/Relation Lists.srt")
    let videoFile = URL(fileURLWithPath: "/Media/Show/Relation Lists.mkv")
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
                text: "One Cue, two relation lists."
            )
        ]
    )
    let selection = try #require(try database.cueTextSelection(
        forSubtitleFile: subtitleFile,
        atMilliseconds: 1_500
    ))
    let cueID = try #require(selection.cueLineID)
    let defaultShiori = try database.upsertShiori(
        subtitleFile: subtitleFile,
        subtitleFormat: .srt,
        videoFile: videoFile,
        videoName: videoFile.lastPathComponent,
        selection: selection
    )

    try executeSQLite(
        at: databaseURL,
        """
        INSERT INTO shiori_lists(id, name, created_at)
        VALUES (2, 'Future List', '2026-07-21T00:00:00Z');
        INSERT INTO shioris(list_id, cue_id, created_at)
        VALUES (2, \(cueID), '2026-07-21T00:00:01Z');
        """
    )

    #expect(try database.shioriRelations().map(\.id) == [defaultShiori.id])
    let futureRelation = try #require(try database.shioriRelations(listID: 2).first)
    #expect(futureRelation.cueID == cueID)
    #expect(futureRelation.listID == 2)

    do {
        try executeSQLite(
            at: databaseURL,
            """
            INSERT INTO shioris(list_id, cue_id, created_at)
            VALUES (2, \(cueID), '2026-07-21T00:00:02Z');
            """
        )
        Issue.record("Expected one Shiori relation per Cue inside one list")
    } catch {
        // Expected unique(list_id, cue_id) enforcement.
    }
}

@Test
func shioriPersistsAndResolvesCueIDWhileTagsReferenceShioriID() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try DatabaseBootstrap.prepare(at: databaseURL)

    let subtitleFile = URL(fileURLWithPath: "/Media/Show/Permanent Identity.srt")
    let videoFile = URL(fileURLWithPath: "/Media/Show/Permanent Identity.mkv")
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
                text: "CueID is the Shiori relationship."
            )
        ]
    )

    let selection = try #require(try database.cueTextSelection(
        forSubtitleFile: subtitleFile,
        atMilliseconds: 1_500
    ))
    let cueID = try #require(selection.cueLineID)
    let shiori = try database.upsertShiori(
        subtitleFile: subtitleFile,
        subtitleFormat: .srt,
        videoFile: videoFile,
        videoName: videoFile.lastPathComponent,
        selection: selection
    )

    let relation = try #require(try database.shioriRelation(id: shiori.id))
    #expect(relation.cueID == cueID)
    #expect(relation.listID == ShioriListIdentity.defaultListID)
    #expect(try database.shioriLists().map(\.id) == [ShioriListIdentity.defaultListID])

    let page = try database.shioriPage(shioriIDs: [shiori.id])
    #expect(page.cuePresentationsByShioriID[shiori.id]?.cueID == cueID)

    let tag = try database.assignShioriTag(named: "CueID", toShioriID: shiori.id)
    #expect(try database.shioriTags(forShioriID: shiori.id) == [tag])
}

@Test
func rebuildingSubtitleRemapsShioriAndPreservesTagsWhenCueContentChanges() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try DatabaseBootstrap.prepare(at: databaseURL)

    let subtitleFile = URL(fileURLWithPath: "/Media/Show/Reindexed Shiori.srt")
    let videoFile = URL(fileURLWithPath: "/Media/Show/Reindexed Shiori.mkv")
    let originalEntry = SubtitleEntry(
        sequenceNumber: 1,
        startTimecode: "00:00:01,000",
        endTimecode: "00:00:03,000",
        startMilliseconds: 1_000,
        endMilliseconds: 3_000,
        text: "Original saved cue."
    )
    try database.replaceEntries(
        subtitleFile: subtitleFile,
        videoFile: videoFile,
        entries: [originalEntry]
    )

    let originalCue = try #require(
        try database.cueLineRecords(forSubtitleFile: subtitleFile).first
    )
    let originalShiori = try database.upsertShiori(
        subtitleFile: subtitleFile,
        subtitleFormat: .srt,
        videoFile: videoFile,
        videoName: videoFile.lastPathComponent,
        selection: shioriSelection(originalCue),
        createdAt: Date(timeIntervalSince1970: 1_700_000_000)
    )
    let tag = try database.assignShioriTag(
        named: "Keep after reindex",
        toShioriID: originalShiori.id
    )

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
                text: "Updated saved cue."
            ),
        ]
    )

    let rebuiltCue = try #require(
        try database.cueLineRecords(forSubtitleFile: subtitleFile).first
    )
    let rebuiltRelation = try #require(
        try database.shioriRelation(id: originalShiori.id)
    )
    let rebuiltShiori = try #require(try database.shiori(id: originalShiori.id))

    #expect(rebuiltCue.id != originalCue.id)
    #expect(rebuiltRelation.id == originalShiori.id)
    #expect(rebuiltRelation.cueID == rebuiltCue.id)
    #expect(rebuiltShiori.content == "Updated saved cue.")
    #expect(rebuiltShiori.createdAt == originalShiori.createdAt)
    #expect(try database.shioriTags(forShioriID: originalShiori.id) == [tag])
}

@Test
func shioriStoresSameTimeSiblingCuesSeparatelyAndDeduplicatesOneIdentity() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try DatabaseBootstrap.prepare(at: databaseURL)

    let subtitleFile = URL(fileURLWithPath: "/Media/Same Time.ass")
    let videoFile = URL(fileURLWithPath: "/Media/Same Time.mkv")
    try database.replaceCueGroups(
        subtitleFile: subtitleFile,
        videoFile: videoFile,
        format: .ass,
        cueGroups: [
            SubtitleCueGroup(
                sequenceNumber: nil,
                startTimecode: "0:00:01.00",
                endTimecode: "0:00:03.00",
                startMilliseconds: 1_000,
                endMilliseconds: 3_000,
                searchContent: "Chinese upper cue\nJapanese lower cue",
                cueLines: [
                    testCueLine(
                        eventIndex: 10,
                        startMilliseconds: 1_000,
                        endMilliseconds: 3_000,
                        content: "Chinese upper cue",
                        displayOrder: 0
                    ),
                    testCueLine(
                        eventIndex: 11,
                        startMilliseconds: 1_000,
                        endMilliseconds: 3_000,
                        content: "Japanese lower cue",
                        displayOrder: 1
                    ),
                ]
            )
        ]
    )
    let cueRecords = try database.cueLineRecords(forSubtitleFile: subtitleFile)
    let topSelection = shioriSelection(cueRecords[0])
    let bottomSelection = shioriSelection(cueRecords[1])

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

private func shioriSelection(
    _ record: SubtitleCueLineRecord
) -> SubtitleCueTextSelection {
    SubtitleCueTextSelection(
        cueGroupID: record.cueGroupID,
        cueLineID: record.id,
        startMilliseconds: record.line.startMilliseconds,
        endMilliseconds: record.line.endMilliseconds,
        cueEventIndex: record.line.eventIndex,
        cueDisplayOrder: record.line.displayOrder,
        content: record.line.content
    )
}

@Test
func shioriPageReturnsNewestRowsWithLanguages() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try DatabaseBootstrap.prepare(at: databaseURL)

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
    try DatabaseBootstrap.prepare(at: databaseURL)

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
func shioriCuePresentationUsesCueIDAndPrimaryCueMetadata() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try DatabaseBootstrap.prepare(at: databaseURL)

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

    let currentCues = try database.cueLineRecords(forSubtitleFile: subtitleFile)
    let currentJapaneseCue = try #require(currentCues.first { $0.line.eventIndex == 11 })
    let currentChineseCue = try #require(currentCues.first { $0.line.eventIndex == 10 })
    try database.replaceCueLineSpeakers(
        forSubtitleFile: subtitleFile,
        assignments: [
            SubtitleCueLineSpeakerAssignment(
                cueLineID: currentJapaneseCue.id,
                speakers: ["Japanese Speaker", "Control\u{1f}Speaker"]
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
    #expect(presentation.primaryGroupIndex == 1)
    #expect(presentation.cueGroupTexts == [chineseText, japaneseText])
    #expect(presentation.languages == [.japanese])
    #expect(presentation.speakers == ["Japanese Speaker", "Control\u{1f}Speaker"])
    #expect(page.languagesByShioriID[shiori.id] == [.japanese])
    #expect(try database.cueID(forShioriID: shiori.id) == currentJapaneseCue.id)

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
    let controlSpeakerPage = try database.shioriTablePage(
        limit: 10,
        offset: 0,
        searchText: "",
        filterSet: SubtitleSearchFilterSet(
            rules: [
                SubtitleSearchFilterRule(
                    field: .speaker,
                    operatorID: .contains,
                    value: "Control\u{1f}Speaker"
                )
            ]
        )
    )
    #expect(controlSpeakerPage.totalCount == 1)
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
    #expect(contextPage.results.contains { $0.entryID == currentJapaneseCue.id })
}

@Test
func shioriTablePageAppliesSearchAndFiltersBeforeSlicing() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try DatabaseBootstrap.prepare(at: databaseURL)

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
    let searchIndex = try database.shioriTableIDIndex(
        searchText: "middle",
        filterSet: SubtitleSearchFilterSet()
    )
    #expect(searchIndex.shioriIDs == searchPage.shioris.map(\.id))

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
    let filteredIndex = try database.shioriTableIDIndex(
        searchText: "",
        filterSet: languageFilter
    )
    #expect(filteredIndex.totalCount == 2)
    #expect(filteredIndex.shioriIDs[1] == filteredPage.shioris[0].id)

    let countOnlyPage = try database.shioriTablePage(
        limit: 0,
        offset: 0,
        searchText: "",
        filterSet: languageFilter
    )
    #expect(countOnlyPage.totalCount == 2)
    #expect(countOnlyPage.shioris.isEmpty)
}

@Test
func shioriTableIDIndexStopsImmediatelyAfterCancellationDuringScan() async throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try DatabaseBootstrap.prepare(at: databaseURL)
    let subtitleFile = URL(fileURLWithPath: "/Media/Shiori-Cancel.srt")
    let videoFile = URL(fileURLWithPath: "/Media/Shiori-Cancel.mkv")
    try database.replaceEntries(
        subtitleFile: subtitleFile,
        videoFile: videoFile,
        entries: (0..<512).map { ordinal in
            SubtitleEntry(
                sequenceNumber: ordinal + 1,
                startTimecode: "\(ordinal * 1_000)",
                endTimecode: "\(ordinal * 1_000 + 500)",
                startMilliseconds: ordinal * 1_000,
                endMilliseconds: ordinal * 1_000 + 500,
                text: "keep \(ordinal)"
            )
        }
    )
    let cueRecords = try database.cueLineRecords(forSubtitleFile: subtitleFile)
    var insertedIDs: [Int64] = []
    for (ordinal, cueRecord) in cueRecords.enumerated() {
        let shiori = try database.upsertShiori(
            subtitleFile: subtitleFile,
            subtitleFormat: .srt,
            videoFile: videoFile,
            videoName: videoFile.lastPathComponent,
            selection: shioriSelection(cueRecord),
            createdAt: Date(timeIntervalSince1970: TimeInterval(ordinal))
        )
        insertedIDs.append(shiori.id)
    }

    let unfilteredIndex = try database.shioriTableIDIndex(
        searchText: "",
        filterSet: SubtitleSearchFilterSet()
    )
    #expect(unfilteredIndex.shioriIDs == Array(insertedIDs.reversed()))

    let rowReadProbe = ShioriTableCancellationRowReadProbe()
    let task = Task.detached { () throws -> ShioriTableIDIndex in
        let database = try SubtitleDatabase(path: databaseURL)
        return try database.shioriTableIDIndex(
            searchText: "",
            filterSet: SubtitleSearchFilterSet(rules: [
                SubtitleSearchFilterRule(
                    field: .cues,
                    operatorID: .contains,
                    value: "keep"
                )
            ]),
            didReadCandidate: { readCount in
                rowReadProbe.record(readCount)
                guard readCount == 32 else {
                    return
                }
                withUnsafeCurrentTask { task in
                    task?.cancel()
                }
            }
        )
    }

    do {
        _ = try await task.value
        Issue.record("Expected Shiori table ID scan to stop during row iteration")
    } catch is CancellationError {
        // Expected.
    }
    #expect(rowReadProbe.maximumReadCount == 32)

    let enrichedRowReadProbe = ShioriTableCancellationRowReadProbe()
    let enrichedTask = Task.detached { () throws -> ShioriTableIDIndex in
        let database = try SubtitleDatabase(path: databaseURL)
        return try database.shioriTableIDIndex(
            searchText: "",
            filterSet: SubtitleSearchFilterSet(rules: [
                SubtitleSearchFilterRule(
                    field: .speaker,
                    operatorID: .isEmpty
                )
            ]),
            didReadCandidate: { readCount in
                enrichedRowReadProbe.record(readCount)
                guard readCount == 32 else {
                    return
                }
                withUnsafeCurrentTask { task in
                    task?.cancel()
                }
            }
        )
    }
    do {
        _ = try await enrichedTask.value
        Issue.record("Expected enriched Shiori scan to stop during row iteration")
    } catch is CancellationError {
        // Expected.
    }
    #expect(enrichedRowReadProbe.maximumReadCount == 32)
}

@Test
func freshSchemaCreatesShioriTablePerformanceIndexes() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    try DatabaseBootstrap.prepare(at: databaseURL)

    #expect(try sqliteIndexExists("idx_shioris_created_order", databaseURL: databaseURL))
    #expect(try sqliteIndexExists("idx_subtitle_cue_groups_file_time", databaseURL: databaseURL))
}

@Test
func freshSchemaCreatesShioriTagTablesAndIndexes() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    try DatabaseBootstrap.prepare(at: databaseURL)

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
    try DatabaseBootstrap.prepare(at: databaseURL)

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
    try DatabaseBootstrap.prepare(at: databaseURL)

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
func removingIndexedFolderRemovesCueBoundShioriRelation() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try DatabaseBootstrap.prepare(at: databaseURL)

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
    #expect(try database.shioris().isEmpty)
    #expect(try database.shioriRelations().isEmpty)
}

@Test
func removingIndexedFolderPreservesLibraryPlaybackHistory() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try DatabaseBootstrap.prepare(at: databaseURL)

    let folder = URL(fileURLWithPath: "/Media/Show")
    _ = try database.addSearchPath(folder)
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

    #expect(try LibraryDatabase(path: databaseURL).libraryVideos(under: [folder]).isEmpty)
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
    try DatabaseBootstrap.prepare(at: databaseURL)

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
    try DatabaseBootstrap.prepare(at: databaseURL)

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
    try DatabaseBootstrap.prepare(at: databaseURL)

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
    try DatabaseBootstrap.prepare(at: databaseURL)

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

    let playback = try PlaybackSubtitleDatabase(path: databaseURL)
    #expect(try playback.hasASSRenderSegments(forSubtitleFile: subtitleFile))
    let loadedSegment = try playback.assRenderSegment(forSubtitleFile: subtitleFile, atMilliseconds: 30_250)
    let segment = try #require(loadedSegment)
    #expect(segment.startMilliseconds == 30_000)
    #expect(segment.endMilliseconds == 60_000)
    #expect(segment.eventCount == 1)
    #expect(segment.scriptText.contains("Dialogue:"))
    #expect(try playback.assRenderSegment(forSubtitleFile: subtitleFile, atMilliseconds: 60_000) == nil)
}

@Test
func storesAndLoadsASSFontReferences() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try DatabaseBootstrap.prepare(at: databaseURL)

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

    let playback = try PlaybackSubtitleDatabase(path: databaseURL)
    #expect(try playback.hasCurrentASSFontReferenceManifest(forSubtitleFile: subtitleFile))
    #expect(try playback.assFontReferences(forSubtitleFile: subtitleFile) == [
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
    try DatabaseBootstrap.prepare(at: databaseURL)

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

    let playback = try PlaybackSubtitleDatabase(path: databaseURL)
    let loadedManifest = try playback.assFontResourceManifest(
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

    let updatedManifest = try #require(try playback.assFontResourceManifest(
        forSubtitleFile: subtitleFile,
        videoFile: videoFile
    ))
    #expect(updatedManifest.status == .readyWithoutFonts)
    #expect(updatedManifest.fontsDirectoryPath == nil)
    #expect(updatedManifest.resourceSignature == "signature-v2")
}

@Test
func insertingCueGroupsRecordsTheirLineCount() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try DatabaseBootstrap.prepare(at: databaseURL)

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
    try DatabaseBootstrap.prepare(at: databaseURL)

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
    try DatabaseBootstrap.prepare(at: databaseURL)

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
func removingIndexedFolderPreservesRetainedDerivedSearchRows() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
        try? FileManager.default.removeItem(atPath: databaseURL.path + "-wal")
        try? FileManager.default.removeItem(atPath: databaseURL.path + "-shm")
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try DatabaseBootstrap.prepare(at: databaseURL)

    let removedFolder = URL(fileURLWithPath: "/Media/00 Removed")
    let firstKeptFolder = URL(fileURLWithPath: "/Media/10 Kept")
    let secondKeptFolder = URL(fileURLWithPath: "/Media/20 Kept")
    for folder in [removedFolder, firstKeptFolder, secondKeptFolder] {
        _ = try database.addSearchPath(folder)
        try database.replaceEntries(
            subtitleFile: folder.appendingPathComponent("Episode.srt"),
            videoFile: folder.appendingPathComponent("Episode.mkv"),
            entries: [simpleTestEntry(text: "Shared removal ordering text")]
        )
    }

    let removedCueGroupID = try #require(try database.firstCueGroupID(
        forSubtitleFile: removedFolder.appendingPathComponent("Episode.srt")
    ))
    let firstKeptCueGroupID = try #require(try database.firstCueGroupID(
        forSubtitleFile: firstKeptFolder.appendingPathComponent("Episode.srt")
    ))
    let secondKeptCueGroupID = try #require(try database.firstCueGroupID(
        forSubtitleFile: secondKeptFolder.appendingPathComponent("Episode.srt")
    ))
    let firstKeptRowIDBefore = try #require(try sqliteFTSRowID(
        cueGroupID: firstKeptCueGroupID,
        databaseURL: databaseURL
    ))
    let secondKeptRowIDBefore = try #require(try sqliteFTSRowID(
        cueGroupID: secondKeptCueGroupID,
        databaseURL: databaseURL
    ))

    try database.removeIndexedFolder(removedFolder)

    #expect(try sqliteFTSRowID(
        cueGroupID: removedCueGroupID,
        databaseURL: databaseURL
    ) == nil)
    #expect(try sqliteFTSRowID(
        cueGroupID: firstKeptCueGroupID,
        databaseURL: databaseURL
    ) == firstKeptRowIDBefore)
    #expect(try sqliteFTSRowID(
        cueGroupID: secondKeptCueGroupID,
        databaseURL: databaseURL
    ) == secondKeptRowIDBefore)
    #expect(try database.search("Shared").map(\.videoPath) == [
        firstKeptFolder.appendingPathComponent("Episode.mkv").path,
        secondKeptFolder.appendingPathComponent("Episode.mkv").path
    ])
}

@Test
func scopedSearchOnlyReturnsEntriesUnderActiveFolders() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try DatabaseBootstrap.prepare(at: databaseURL)

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
    try DatabaseBootstrap.prepare(at: databaseURL)

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
    try DatabaseBootstrap.prepare(at: databaseURL)

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
    try DatabaseBootstrap.prepare(at: databaseURL)

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
    try DatabaseBootstrap.prepare(at: databaseURL)

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
    try DatabaseBootstrap.prepare(at: databaseURL)

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
    try DatabaseBootstrap.prepare(at: databaseURL)

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
    try DatabaseBootstrap.prepare(at: databaseURL)

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
    try DatabaseBootstrap.prepare(at: databaseURL)

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
func searchTreatsASCIIAndIdeographicSpacesAsEquivalent() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try DatabaseBootstrap.prepare(at: databaseURL)

    try database.replaceEntries(
        subtitleFile: URL(fileURLWithPath: "/Media/JapaneseSpaces.srt"),
        videoFile: URL(fileURLWithPath: "/Media/JapaneseSpaces.mkv"),
        entries: [
            SubtitleEntry(
                sequenceNumber: 1,
                startTimecode: "00:00:01,000",
                endTimecode: "00:00:03,000",
                startMilliseconds: 1_000,
                endMilliseconds: 3_000,
                text: "日本 語"
            ),
            SubtitleEntry(
                sequenceNumber: 2,
                startTimecode: "00:00:04,000",
                endTimecode: "00:00:06,000",
                startMilliseconds: 4_000,
                endMilliseconds: 6_000,
                text: "日本　語"
            )
        ]
    )

    let expectedContents = ["日本 語", "日本　語"]
    #expect(try database.search("日本 語").map(\.content) == expectedContents)
    #expect(try database.search("日本　語").map(\.content) == expectedContents)
}

@Test
func invalidExplicitFTSQueryReturnsNoResults() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try DatabaseBootstrap.prepare(at: databaseURL)

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
func searchesIndividualCuesAndRejectsCrossCueOnlyMatches() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try DatabaseBootstrap.prepare(at: databaseURL)

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
    try DatabaseBootstrap.prepare(at: databaseURL)

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
    try DatabaseBootstrap.prepare(at: databaseURL)
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
    try DatabaseBootstrap.prepare(at: databaseURL)

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
    try DatabaseBootstrap.prepare(at: databaseURL)

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
    try DatabaseBootstrap.prepare(at: databaseURL)

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
    try DatabaseBootstrap.prepare(at: databaseURL)

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
    try DatabaseBootstrap.prepare(at: databaseURL)

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
    try DatabaseBootstrap.prepare(at: databaseURL)

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

    let playback = try PlaybackSubtitleDatabase(path: databaseURL)
    let metadata = try #require(try playback.playbackFinishMetadata(forSubtitleFile: subtitleFile))
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
    try DatabaseBootstrap.prepare(at: databaseURL)

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

    let playback = try PlaybackSubtitleDatabase(path: databaseURL)
    let timings = try playback.cueTimings(
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
    try DatabaseBootstrap.prepare(at: databaseURL)

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
    try DatabaseBootstrap.prepare(at: databaseURL)

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
    try DatabaseBootstrap.prepare(at: databaseURL)

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
    try DatabaseBootstrap.prepare(at: databaseURL)

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

private func simpleTestEntry(text: String) -> SubtitleEntry {
    SubtitleEntry(
        sequenceNumber: 1,
        startTimecode: "00:00:01,000",
        endTimecode: "00:00:02,000",
        startMilliseconds: 1_000,
        endMilliseconds: 2_000,
        text: text
    )
}

private func temporaryDatabaseURL() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerDatabaseTests-\(UUID().uuidString)")
        .appendingPathExtension("sqlite")
}

private func sqliteColumnNames(in table: String, databaseURL: URL) throws -> Set<String> {
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
    guard sqlite3_prepare_v2(database, "PRAGMA table_info(\(table));", -1, &statement, nil) == SQLITE_OK,
          let statement
    else {
        let message = String(cString: sqlite3_errmsg(database))
        throw SQLiteFixtureError.executeFailed(message)
    }

    defer {
        sqlite3_finalize(statement)
    }

    var names: Set<String> = []
    while sqlite3_step(statement) == SQLITE_ROW {
        guard let value = sqlite3_column_text(statement, 1) else {
            continue
        }
        names.insert(String(cString: value))
    }
    return names
}

private func sqliteMediaIdentity(
    table: String,
    pathColumn: String,
    path: String,
    databaseURL: URL
) throws -> (libraryID: Int64, relativePath: String)? {
    var database: OpaquePointer?
    guard sqlite3_open_v2(databaseURL.path, &database, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
        let message = database.map { String(cString: sqlite3_errmsg($0)) } ?? "Unknown SQLite error"
        sqlite3_close(database)
        throw SQLiteFixtureError.openFailed(message)
    }
    defer { sqlite3_close(database) }

    var statement: OpaquePointer?
    let sql = "SELECT library_id, relative_path FROM \(table) WHERE \(pathColumn) = ? LIMIT 1;"
    guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
          let statement
    else {
        throw SQLiteFixtureError.executeFailed(String(cString: sqlite3_errmsg(database)))
    }
    defer { sqlite3_finalize(statement) }

    let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    sqlite3_bind_text(statement, 1, path, -1, transient)
    guard sqlite3_step(statement) == SQLITE_ROW,
          sqlite3_column_type(statement, 0) != SQLITE_NULL,
          let relativePath = sqlite3_column_text(statement, 1)
    else {
        return nil
    }
    return (sqlite3_column_int64(statement, 0), String(cString: relativePath))
}

private func sqliteRowID(
    table: String,
    pathColumn: String,
    path: String,
    databaseURL: URL
) throws -> Int64? {
    try sqliteReferencedID(
        table: table,
        idColumn: "id",
        pathColumn: pathColumn,
        path: path,
        databaseURL: databaseURL
    )
}

private func sqliteReferencedID(
    table: String,
    idColumn: String,
    pathColumn: String,
    path: String,
    databaseURL: URL
) throws -> Int64? {
    var database: OpaquePointer?
    guard sqlite3_open_v2(databaseURL.path, &database, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
        let message = database.map { String(cString: sqlite3_errmsg($0)) } ?? "Unknown SQLite error"
        sqlite3_close(database)
        throw SQLiteFixtureError.openFailed(message)
    }
    defer { sqlite3_close(database) }

    var statement: OpaquePointer?
    let sql = "SELECT \(idColumn) FROM \(table) WHERE \(pathColumn) = ? LIMIT 1;"
    guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
          let statement
    else {
        throw SQLiteFixtureError.executeFailed(String(cString: sqlite3_errmsg(database)))
    }
    defer { sqlite3_finalize(statement) }

    let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    sqlite3_bind_text(statement, 1, path, -1, transient)
    guard sqlite3_step(statement) == SQLITE_ROW,
          sqlite3_column_type(statement, 0) != SQLITE_NULL
    else {
        return nil
    }
    return sqlite3_column_int64(statement, 0)
}

private func sqliteFTSRowID(cueGroupID: Int64, databaseURL: URL) throws -> Int64? {
    var database: OpaquePointer?
    guard sqlite3_open_v2(databaseURL.path, &database, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
        let message = database.map { String(cString: sqlite3_errmsg($0)) } ?? "Unknown SQLite error"
        sqlite3_close(database)
        throw SQLiteFixtureError.openFailed(message)
    }
    defer { sqlite3_close(database) }

    var statement: OpaquePointer?
    guard sqlite3_prepare_v2(
        database,
        "SELECT rowid FROM subtitle_cue_groups_fts WHERE cue_group_id = ? LIMIT 1;",
        -1,
        &statement,
        nil
    ) == SQLITE_OK,
          let statement
    else {
        throw SQLiteFixtureError.executeFailed(String(cString: sqlite3_errmsg(database)))
    }
    defer { sqlite3_finalize(statement) }

    sqlite3_bind_int64(statement, 1, cueGroupID)
    guard sqlite3_step(statement) == SQLITE_ROW else {
        return nil
    }
    return sqlite3_column_int64(statement, 0)
}

private func sqliteCueLinesReferenceSubtitleFile(databaseURL: URL) throws -> Bool {
    var database: OpaquePointer?
    guard sqlite3_open_v2(databaseURL.path, &database, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
        let message = database.map { String(cString: sqlite3_errmsg($0)) } ?? "Unknown SQLite error"
        sqlite3_close(database)
        throw SQLiteFixtureError.openFailed(message)
    }
    defer { sqlite3_close(database) }

    var statement: OpaquePointer?
    guard sqlite3_prepare_v2(
        database,
        """
        SELECT COUNT(*)
        FROM subtitle_cue_lines l
        JOIN subtitle_cue_groups g ON g.id = l.cue_group_id
        WHERE l.subtitle_file_id = g.subtitle_file_id;
        """,
        -1,
        &statement,
        nil
    ) == SQLITE_OK,
        let statement
    else {
        throw SQLiteFixtureError.executeFailed(String(cString: sqlite3_errmsg(database)))
    }
    defer { sqlite3_finalize(statement) }

    return sqlite3_step(statement) == SQLITE_ROW && sqlite3_column_int64(statement, 0) > 0
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

private func expectUnsupportedSchemaVersion(_ version: Int) throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    try executeSQLite(at: databaseURL, "PRAGMA user_version = \(version);")
    do {
        try DatabaseBootstrap.prepare(at: databaseURL)
        Issue.record("Expected schema \(version) to be rejected")
    } catch let error as DatabaseBootstrapError {
        #expect(error == .unsupportedSchemaVersion(
            found: version,
            supported: DatabaseBootstrap.currentSchemaVersion
        ))
    }
    let database = try SubtitleDatabase(path: databaseURL, access: .readOnly)
    #expect(try database.schemaVersion() == version)
}

private func sqliteRowCount(in table: String, databaseURL: URL) throws -> Int {
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
    guard sqlite3_prepare_v2(database, "SELECT COUNT(*) FROM \(table);", -1, &statement, nil) == SQLITE_OK,
          let statement
    else {
        throw SQLiteFixtureError.executeFailed(String(cString: sqlite3_errmsg(database)))
    }
    defer {
        sqlite3_finalize(statement)
    }
    guard sqlite3_step(statement) == SQLITE_ROW else {
        throw SQLiteFixtureError.executeFailed(String(cString: sqlite3_errmsg(database)))
    }
    return Int(sqlite3_column_int64(statement, 0))
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
