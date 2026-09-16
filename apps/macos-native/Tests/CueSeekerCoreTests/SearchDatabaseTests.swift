import Foundation
import Testing
@testable import CueSeekerCore

@Test
func visibleSearchReadersRejectPreCancelledTasks() async throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let searchTask = Task.detached { () throws -> SubtitleSearchPage in
        let database = try IndexingDatabase(path: databaseURL)
        try DatabaseBootstrap.prepare(at: databaseURL)
        withUnsafeCurrentTask { task in
            task?.cancel()
        }
        return try SearchDatabase(path: database.path).searchVisiblePage(
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
        let database = try IndexingDatabase(path: databaseURL)
        withUnsafeCurrentTask { task in
            task?.cancel()
        }
        return try SearchDatabase(path: database.path).allCuesVisiblePage(limit: 1, cursor: .start)
    }
    do {
        _ = try await allCueTask.value
        Issue.record("Expected cancelled all-cue search to stop")
    } catch is CancellationError {
        // Expected.
    }
}

@Test
func allCuesVisiblePageReturnsDefaultOrder() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try IndexingDatabase(path: databaseURL)
    try DatabaseBootstrap.prepare(at: databaseURL)

    let subtitleFile = URL(fileURLWithPath: "/Media/OrderTest.srt")
    let videoFile = URL(fileURLWithPath: "/Media/OrderTest.mkv")
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
    let page = try SearchDatabase(path: database.path).allCuesVisiblePage(limit: 10, cursor: .start)

    #expect(page.totalCount == 3)
    #expect(page.results.map(\.content) == ["first cue", "second cue", "third file cue"])
    #expect(page.results.map(\.timeRange) == [
        "00:01 - 00:01",
        "00:02 - 00:02",
        "00:03 - 00:03",
    ])
    #expect(Dictionary(uniqueKeysWithValues: page.fileSummaries.map {
        ($0.subtitlePath, $0.matchCount)
    }) == [
        subtitleFile.path: 2,
        summarySubtitleFile.path: 1,
    ])
}

@Test
func allCuesVisiblePageCountsFiltersAndPaginatesSiblingCuesIndependently() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try IndexingDatabase(path: databaseURL)
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
    let cueRecords = try PlaybackSubtitleDatabase(path: database.path).cueLineRecords(forSubtitleFile: subtitleFile)
    let firstPage = try SearchDatabase(path: database.path).allCuesVisiblePage(limit: 1, cursor: .start)
    #expect(firstPage.totalCount == 2)
    #expect(firstPage.results.map(\.entryID) == [cueRecords[0].id])
    #expect(firstPage.results[0].cueLines == ["中文上方"])
    #expect(firstPage.results[0].cueGroupLines == ["中文上方", "日本語の下側\n二行目"])
    #expect(firstPage.results[0].primaryGroupIndex == 0)
    #expect(firstPage.results[0].languages == [.simplifiedChinese])
    #expect(firstPage.nextCursor == SubtitleSearchCursor(offset: 1))

    let secondPage = try SearchDatabase(path: database.path).allCuesVisiblePage(
        limit: 1,
        cursor: firstPage.nextCursor
    )
    #expect(secondPage.results.map(\.entryID) == [cueRecords[1].id])
    #expect(secondPage.results[0].content == "日本語の下側\n二行目")
    #expect(secondPage.results[0].cueLines == ["日本語の下側\n二行目"])
    #expect(secondPage.results[0].primaryGroupIndex == 1)
    #expect(secondPage.results[0].languages == [.japanese])
    #expect(secondPage.results[0].cueGroupID == firstPage.results[0].cueGroupID)

    let filteredPage = try SearchDatabase(path: database.path).allCuesVisiblePage(
        limit: 10,
        cursor: .start,
        filterSet: SubtitleSearchFilterSet(
            rules: [
                SubtitleSearchFilterRule(
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
func storesSubtitleEntriesAndSearchesWithFTS5() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try IndexingDatabase(path: databaseURL)
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

    let storedEntries = try PlaybackSubtitleDatabase(path: database.path).entries(forSubtitleFile: subtitleFile)
    #expect(storedEntries.count == 2)
    #expect(storedEntries[0].content == "Hello world.")
    #expect(storedEntries[0].videoName == "Movie.mkv")

    let results = try SearchDatabase(path: database.path).search("world")
    #expect(results.count == 1)
    #expect(results[0].subtitleFileID != nil)
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

    let database = try IndexingDatabase(path: databaseURL)
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
    try LibraryDatabase(path: databaseURL).setLibraryWatchState(
        videoFile: watchingVideoFile,
        duration: nil,
        state: .watching
    )
    try LibraryDatabase(path: databaseURL).setLibraryWatchState(
        videoFile: finishedVideoFile,
        duration: nil,
        state: .finished
    )

    let allResults = try SearchDatabase(path: database.path).search("scope shared", watchStateFilter: .all)
    #expect(allResults.map(\.videoName).sorted() == [
        "Finished.mkv",
        "Unwatched.mkv",
        "Watching.mkv"
    ])

    let onlyFinishedResults = try SearchDatabase(path: database.path).search("scope shared", watchStateFilter: .onlyFinished)
    #expect(onlyFinishedResults.map(\.videoName) == ["Finished.mkv"])

    let watchingAndFinishedPage = try SearchDatabase(path: database.path).searchVisiblePage(
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
func searchPaginatesBeyondDefaultResultLimit() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try IndexingDatabase(path: databaseURL)
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

    let firstPage = try SearchDatabase(path: database.path).search("shared", limit: 50)
    let secondPage = try SearchDatabase(path: database.path).search("shared", limit: 50, offset: 50)

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

    let database = try IndexingDatabase(path: databaseURL)
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

    let firstPage = try SearchDatabase(path: database.path).searchPage("shared", limit: 2)
    let secondPage = try SearchDatabase(path: database.path).searchPage("shared", limit: 2, cursor: firstPage.nextCursor)
    let thirdPage = try SearchDatabase(path: database.path).searchPage("shared", limit: 2, cursor: secondPage.nextCursor)

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

    let database = try IndexingDatabase(path: databaseURL)
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

    let firstPage = try SearchDatabase(path: database.path).searchVisiblePage("shared", limit: 2, cursor: .start)
    let secondPage = try SearchDatabase(path: database.path).searchVisiblePage("shared", limit: 3, cursor: firstPage.nextCursor)

    #expect(firstPage.pageMode == .visibleWindow)
    #expect(firstPage.countState == .exactProgress)
    #expect(firstPage.totalCount == 2)
    #expect(firstPage.knownResultCount == 2)
    #expect(firstPage.exactTotalCount == nil)
    #expect(firstPage.facetSnapshot == nil)
    #expect(firstPage.fileSummaries.map(\.matchCount) == [2])
    #expect(firstPage.nextCursor?.offset == 2)
    #expect(firstPage.results.map(\.content) == [
        "Shared visible line 0",
        "Shared visible line 1"
    ])

    #expect(secondPage.countState == .exact)
    #expect(secondPage.totalCount == 5)
    #expect(secondPage.exactTotalCount == 5)
    #expect(secondPage.facetSnapshot?.cueIDs.count == 5)
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

    let database = try IndexingDatabase(path: databaseURL)
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
    let page = try SearchDatabase(path: database.path).searchPage("shared", limit: 10, filterSet: filterSet)

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

    let database = try IndexingDatabase(path: databaseURL)
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

    let page = try SearchDatabase(path: database.path).searchPage("shared", limit: 0)

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

    let database = try IndexingDatabase(path: databaseURL)
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

    let exactPage = try SearchDatabase(path: database.path).searchPage("shared", limit: 2, filterSet: filterSet)
    #expect(exactPage.totalCount == 3)
    #expect(exactPage.nextCursor?.offset == 2)
    #expect(exactPage.results.map(\.content) == [
        "Shared filtered keep 0",
        "Shared filtered keep 2"
    ])

    let visiblePage = try SearchDatabase(path: database.path).searchVisiblePage(
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
func searchExactAndVisiblePagesPreserveIndependentPaging() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try IndexingDatabase(path: databaseURL)
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

    let exactPage = try SearchDatabase(path: database.path).searchPage("shared", limit: 2)
    #expect(exactPage.totalCount == 8)

    let visiblePage = try SearchDatabase(path: database.path).searchVisiblePage(
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
func searchNavigationSnapshotUsesCompleteSearchOrder() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try IndexingDatabase(path: databaseURL)
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

    let snapshot = try SearchDatabase(path: database.path).searchNavigationSnapshot(
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

    let database = try IndexingDatabase(path: databaseURL)
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
    let page = try SearchDatabase(path: database.path).searchPage(
        "progress",
        limit: 50,
        cursor: .start,
        progress: { snapshot in
            collector.append(snapshot)
        }
    )
    let progress = collector.values()
    let streamedResults = progress.flatMap(\.results)
    let streamedCueIDs = progress.flatMap(\.cueIDs)

    #expect(!progress.isEmpty)
    #expect(progress.allSatisfy { $0.countState == .exactProgress })
    #expect(progress.map(\.knownResultCount) == progress.map(\.knownResultCount).sorted())
    #expect(progress.allSatisfy { $0.resultOffset + $0.results.count == $0.knownResultCount })
    #expect(progress.allSatisfy { $0.results.count == $0.cueIDs.count })
    #expect(progress.first?.resultOffset == 0)
    // The first batch is a visible window's, 100 candidates for a page of 50;
    // the next batch reaches the last row.
    #expect(progress.last?.knownResultCount == 100)
    #expect(progress.last?.knownFileCount == 1)
    #expect(progress.last?.fileSummaries.map(\.matchCount) == [100])
    #expect(streamedResults.count == 100)
    #expect(streamedResults.first?.content == "Progress count stream line 0")
    #expect(streamedResults.last?.content == "Progress count stream line 99")
    #expect(streamedResults.map(\.searchRank) == Array(0..<100))
    #expect(streamedCueIDs == streamedResults.map(\.entryID))
    #expect(page.countState == .exact)
    #expect(page.results.count == 50)
    #expect(page.renderableResultsOffset == 100)
    #expect(page.renderableResults.count == 5_000)
    #expect(page.renderableResults.map(\.searchRank) == Array(100..<5_100))
    #expect(page.renderableResults.last?.content == "Progress count stream line 5099")
    #expect(page.cueIDs == streamedCueIDs + page.renderableResults.map(\.entryID))
    #expect(page.totalCount == 5_100)
    #expect(page.knownResultCount == 5_100)
    #expect(page.fileSummaries.map(\.matchCount) == [5_100])
}

@Test
func repeatedSearchPagesExecuteWithoutHiddenCacheEvents() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try IndexingDatabase(path: databaseURL)
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
    let firstPage = try SearchDatabase(path: database.path).searchPage("cache", limit: 10, diagnostics: firstDiagnostics.record)
    let secondDiagnostics = SearchDiagnosticRecorder()
    let secondPage = try SearchDatabase(path: database.path).searchPage("cache", limit: 10, diagnostics: secondDiagnostics.record)
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

    let database = try IndexingDatabase(path: databaseURL)
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

    _ = try SearchDatabase(path: database.path).searchPage("cache", limit: 10)
    _ = try SearchDatabase(path: database.path).searchPage("cache", limit: 10)

    try database.replaceEntries(
        subtitleFile: subtitleFile,
        videoFile: videoFile,
        entries: [
            databaseTestEntry(text: "Cache invalidation first"),
            databaseTestEntry(text: "Cache invalidation second")
        ]
    )

    let diagnostics = SearchDiagnosticRecorder()
    let page = try SearchDatabase(path: database.path).searchPage("cache", limit: 10, diagnostics: diagnostics.record)
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

    let database = try IndexingDatabase(path: databaseURL)
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

    let firstVisiblePage = try SearchDatabase(path: database.path).searchVisiblePage("shared product", limit: 1, cursor: .start)

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

    let database = try IndexingDatabase(path: databaseURL)
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

    let page = try SearchDatabase(path: database.path).searchPage("shared", limit: 2)

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

    let database = try IndexingDatabase(path: databaseURL)
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

    let allCJKPage = try SearchDatabase(path: database.path).searchPage("一級", limit: 10)
    #expect(try SearchDatabase(path: database.path).cueOccurrenceCount(for: " 一級 ") == allCJKPage.totalCount)
    #expect(allCJKPage.totalCount == 3)

    let scopedCJKPage = try SearchDatabase(path: database.path).searchPage("一級", limit: 10, under: [mediaFolder])
    #expect(try SearchDatabase(path: database.path).cueOccurrenceCount(for: "一級", under: [mediaFolder]) == scopedCJKPage.totalCount)
    #expect(scopedCJKPage.totalCount == 2)

    let phrasePage = try SearchDatabase(path: database.path).searchPage("一級試験", limit: 10)
    #expect(try SearchDatabase(path: database.path).cueOccurrenceCount(for: "一級試験") == phrasePage.totalCount)
    #expect(phrasePage.totalCount == 2)

    let latinPage = try SearchDatabase(path: database.path).searchPage("mag", limit: 10)
    #expect(try SearchDatabase(path: database.path).cueOccurrenceCount(for: "mag") == latinPage.totalCount)
    #expect(latinPage.totalCount == 1)
}

@Test
func searchPageExposesExactCountsWhenRowsContinue() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try IndexingDatabase(path: databaseURL)
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

    let page = try SearchDatabase(path: database.path).searchPage("shared", limit: 2)

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

    let database = try IndexingDatabase(path: databaseURL)
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

    let page = try SearchDatabase(path: database.path).searchPage("shared", limit: 10)

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

    let database = try IndexingDatabase(path: databaseURL)
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

    let diagnostics = try SearchDatabase(path: database.path, access: .readWrite)
        .ftsVocabularyDiagnostics(for: "shared alpha", topTermLimit: 2)

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

    let database = try IndexingDatabase(path: databaseURL)
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

    let page = try SearchDatabase(path: database.path).searchPage("shared", limit: 10, under: [URL(fileURLWithPath: "/Media")])
    #expect(page.results.map(\.content) == [
        "Shared alpha first",
        "Shared alpha second",
        "Shared beta only"
    ])

    let snapshot = try SearchDatabase(path: database.path).searchNavigationSnapshot(
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
func searchPageReturnsFriendlyFileSummaryDisplayTitles() throws {
    let databaseURL = temporaryDatabaseURL()
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerFriendlySummaryTests-\(UUID().uuidString)")
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
        try? FileManager.default.removeItem(at: root)
    }

    let database = try IndexingDatabase(path: databaseURL)
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
    let page = try SearchDatabase(path: database.path).searchPage("shared", limit: 10, diagnostics: diagnostics.record)
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

    let database = try IndexingDatabase(path: databaseURL)
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
    try executeDatabaseTestSQLite(at: databaseURL, "DELETE FROM subtitle_search_order_rows;")

    var thrownMessage: String?
    do {
        _ = try SearchDatabase(path: database.path).searchPage("shared", limit: 10)
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

    let database = try IndexingDatabase(path: databaseURL)
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

    let globalPage = try SearchDatabase(path: database.path).searchPage("shared", limit: 100)
    let zetaRows = try SearchDatabase(path: database.path).search(
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
func scopedSearchOnlyReturnsEntriesUnderActiveFolders() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try IndexingDatabase(path: databaseURL)
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

    #expect(try SearchDatabase(path: database.path).search("Shared").count == 2)
    #expect(try SearchDatabase(path: database.path).search("Shared", under: [activeFolder]).map(\.subtitlePath) == [
        activeFolder.appendingPathComponent("Episode.srt").path
    ])
    #expect(try SearchDatabase(path: database.path).search("Shared", under: []).isEmpty)
}

@Test
func emptySearchQueryReturnsNoResults() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try IndexingDatabase(path: databaseURL)
    try DatabaseBootstrap.prepare(at: databaseURL)

    #expect(try SearchDatabase(path: database.path).search("").isEmpty)
    #expect(try SearchDatabase(path: database.path).search("   ").isEmpty)
}

@Test
func searchNormalizesFTSQuerySyntaxCharacters() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try IndexingDatabase(path: databaseURL)
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

    let results = try SearchDatabase(path: database.path).search(#""hello": spider-man"#)

    #expect(results.count == 1)
    #expect(results[0].content == "He said hello to spider-man again.")
    #expect(try SearchDatabase(path: database.path).search(":::").isEmpty)
}

@Test
func searchUsesFlutterLikeSingleTokenPrefixMatching() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try IndexingDatabase(path: databaseURL)
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

    let results = try SearchDatabase(path: database.path).search("spi")

    #expect(results.count == 1)
    #expect(results[0].content == "Spider-man returns.")
}

@Test
func searchFiltersMultipleLatinTokensByWholeTokenOrder() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try IndexingDatabase(path: databaseURL)
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

    let results = try SearchDatabase(path: database.path).search("alpha beta")

    #expect(results.map(\.content) == ["alpha beta gamma", "alpha middle beta"])
}

@Test
func searchSegmentsCJKContentLikeFlutter() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try IndexingDatabase(path: databaseURL)
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

    let results = try SearchDatabase(path: database.path).search("好世")

    #expect(results.map(\.content) == ["你好世界"])
}

@Test
func searchSegmentsJapaneseKanaContent() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try IndexingDatabase(path: databaseURL)
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

    #expect(try SearchDatabase(path: database.path).search("ライン").map(\.content) == ["日本語ラインかなカナﾃｽﾄ"])
    #expect(try SearchDatabase(path: database.path).search("かな").map(\.content) == ["日本語ラインかなカナﾃｽﾄ"])
    #expect(try SearchDatabase(path: database.path).search("カナ").map(\.content) == ["日本語ラインかなカナﾃｽﾄ"])
    #expect(try SearchDatabase(path: database.path).search("ﾃｽﾄ").map(\.content) == ["日本語ラインかなカナﾃｽﾄ"])
}

@Test
func searchTreatsASCIIAndIdeographicSpacesAsEquivalent() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try IndexingDatabase(path: databaseURL)
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
    #expect(try SearchDatabase(path: database.path).search("日本 語").map(\.content) == expectedContents)
    #expect(try SearchDatabase(path: database.path).search("日本　語").map(\.content) == expectedContents)
}

@Test
func invalidExplicitFTSQueryReturnsNoResults() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try IndexingDatabase(path: databaseURL)
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

    #expect(try SearchDatabase(path: database.path).search("hello AND").isEmpty)
}

@Test
func searchesIndividualCuesAndRejectsCrossCueOnlyMatches() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try IndexingDatabase(path: databaseURL)
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

    let alphaResults = try SearchDatabase(path: database.path).search("alpha")
    #expect(alphaResults.count == 1)
    #expect(alphaResults[0].subtitleFormat == .ass)
    #expect(alphaResults[0].content == "alpha")
    #expect(alphaResults[0].cueLines == ["alpha"])
    #expect(alphaResults[0].cueGroupLines == ["alpha", "beta"])
    #expect(alphaResults[0].cueEventIndex == 0)
    #expect(alphaResults[0].cueDisplayOrder == 0)
    #expect(alphaResults[0].videoPath == videoFile.path)
    #expect(alphaResults[0].startMilliseconds == 1_000)

    #expect(try SearchDatabase(path: database.path).search("alpha beta").isEmpty)
}

@Test
func searchCountsAndPaginatesMatchingSiblingCuesIndependently() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try IndexingDatabase(path: databaseURL)
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

    let cueRecords = try PlaybackSubtitleDatabase(path: database.path).cueLineRecords(forSubtitleFile: subtitleFile)
    let exactFirst = try SearchDatabase(path: database.path).searchPage(
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

    let exactSecond = try SearchDatabase(path: database.path).searchPage(
        "shared",
        limit: 1,
        cursor: exactFirst.nextCursor
    )
    #expect(exactSecond.results.map(\.content) == ["shared lower"])
    #expect(exactSecond.results.map(\.searchRank) == [1])
    #expect(exactSecond.nextCursor == nil)

    let visibleFirst = try SearchDatabase(path: database.path).searchVisiblePage(
        "shared",
        limit: 1,
        cursor: .start
    )
    let visibleSecond = try SearchDatabase(path: database.path).searchVisiblePage(
        "shared",
        limit: 1,
        cursor: visibleFirst.nextCursor
    )
    #expect(visibleFirst.results.map(\.content) == ["shared upper"])
    #expect(visibleSecond.results.map(\.content) == ["shared lower"])
    #expect(visibleFirst.results[0].cueGroupID == visibleSecond.results[0].cueGroupID)
    #expect(visibleFirst.results[0].entryID != visibleSecond.results[0].entryID)

    let hydratedPage = try #require(try SearchDatabase(path: database.path).searchIndexedVisiblePage(
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

    let navigation = try SearchDatabase(path: database.path).searchNavigationSnapshot(
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

    let database = try IndexingDatabase(path: databaseURL)
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

    let cueRecords = try PlaybackSubtitleDatabase(path: database.path).cueLineRecords(forSubtitleFile: subtitleFile)
    let page = try SearchDatabase(path: database.path).searchPage("duplicate", limit: 10, cursor: .start)

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

    let database = try IndexingDatabase(path: databaseURL)
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

    let results = try SearchDatabase(path: database.path).search("shared first second")
    #expect(results.count == 1)
    #expect(results[0].content == content)
    #expect(results[0].cueLines == [content])
    #expect(results[0].cueGroupLines == [content])
}

@Test
func searchCueFiltersDoNotLeakFromSiblingCue() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try IndexingDatabase(path: databaseURL)
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
    let siblingCueFilter = SubtitleSearchFilterSet(rules: [
        SubtitleSearchFilterRule(field: .cues, operatorID: .contains, value: "secret")
    ])
    #expect(try SearchDatabase(path: database.path).search("target", filterSet: siblingCueFilter).isEmpty)

    let siblingResults = try SearchDatabase(path: database.path).search("secret")
    #expect(siblingResults.map(\.content) == ["secret sibling cue"])
}

@Test
func searchReadsASSIndexTimePhysicalOrderWithoutRuntimeReordering() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try IndexingDatabase(path: databaseURL)
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

    #expect(try PlaybackSubtitleDatabase(path: database.path).entries(forSubtitleFile: subtitleFile).map(\.content) == [
        "Chinese upper line\nJapanese lower line"
    ])

    let results = try SearchDatabase(path: database.path).search("Chinese")
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

    let database = try IndexingDatabase(path: databaseURL)
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

    let firstPage = try SearchDatabase(path: database.path).search("alpha beta", limit: 2)
    let secondPage = try SearchDatabase(path: database.path).search("alpha beta", limit: 2, offset: 2)

    #expect(firstPage.map(\.content) == ["alpha beta page 100", "alpha beta page 101"])
    #expect(secondPage.map(\.content) == ["alpha beta page 102"])
}

@Test
func visibleSearchContinuesPastFilteredFTSCandidates() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try IndexingDatabase(path: databaseURL)
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

    let firstPage = try SearchDatabase(path: database.path).searchVisiblePage("alpha beta", limit: 2, cursor: .start)
    let secondPage = try SearchDatabase(path: database.path).searchVisiblePage("alpha beta", limit: 2, cursor: firstPage.nextCursor)

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
func searchPageAppliesTheFacetFilterToResultsWhileTheSnapshotHoldsEveryMatch() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try IndexingDatabase(path: databaseURL)
    try DatabaseBootstrap.prepare(at: databaseURL)
    try database.replaceEntries(
        subtitleFile: URL(fileURLWithPath: "/Media/Facet.srt"),
        videoFile: URL(fileURLWithPath: "/Media/Facet.mkv"),
        entries: (0..<6).map { index in
            SubtitleEntry(
                sequenceNumber: index + 1,
                startTimecode: "00:00:0\(index),000",
                endTimecode: index.isMultiple(of: 2) ? "00:00:0\(index),500" : "00:00:0\(index),999",
                startMilliseconds: index * 1_000,
                endMilliseconds: index * 1_000 + (index.isMultiple(of: 2) ? 500 : 2_500),
                text: "Facet filtered line \(index)"
            )
        }
    )

    let shortCues = CueFacetFilter(durations: [.underOneSecond])
    let search = try SearchDatabase(path: databaseURL)

    let visiblePage = try search.searchVisiblePage(
        "facet",
        limit: 2,
        cursor: .start,
        facetFilter: shortCues
    )
    #expect(visiblePage.results.map(\.content) == ["Facet filtered line 0", "Facet filtered line 2"])
    #expect(visiblePage.nextCursor?.offset == 2)

    let exactPage = try search.searchPage("facet", limit: 10, facetFilter: shortCues)
    #expect(exactPage.results.map(\.content) == [
        "Facet filtered line 0", "Facet filtered line 2", "Facet filtered line 4"
    ])
    #expect(exactPage.results.map(\.searchRank) == [0, 1, 2])
    #expect(exactPage.totalCount == 3)
    #expect(exactPage.cueIDs == exactPage.results.map(\.entryID))
    #expect(exactPage.fileSummaries.map(\.matchCount) == [3])
    // The filter narrows only the results: the snapshot holds every match of
    // the query, the same as an unfiltered scan's.
    #expect(exactPage.facetSnapshot == (try search.searchPage("facet", limit: 10).facetSnapshot))
    #expect(exactPage.facetSnapshot?.distribution.durationCounts == [
        .underOneSecond: 3,
        .oneToUnderThreeSeconds: 3,
    ])

    // A two-line group whose lines fall on both sides of a character filter still
    // returns the whole group as context for the matching line.
    try database.replaceCueGroups(
        subtitleFile: URL(fileURLWithPath: "/Media/FacetGroup.ass"),
        videoFile: URL(fileURLWithPath: "/Media/FacetGroup.mkv"),
        format: .ass,
        cueGroups: [
            SubtitleCueGroup(
                sequenceNumber: nil,
                startTimecode: "10000",
                endTimecode: "10500",
                startMilliseconds: 10_000,
                endMilliseconds: 10_500,
                searchContent: "facet short\nfacet long line that runs past thirty characters",
                cueLines: [
                    testCueLine(eventIndex: 0, startMilliseconds: 10_000, endMilliseconds: 10_500, content: "facet short", displayOrder: 0),
                    testCueLine(eventIndex: 1, startMilliseconds: 10_000, endMilliseconds: 10_500, content: "facet long line that runs past thirty characters", displayOrder: 1)
                ]
            )
        ]
    )
    let longLines = try search.searchPage(
        "facet",
        limit: 10,
        facetFilter: CueFacetFilter(characters: [.thirtyOneOrMore])
    )
    #expect(longLines.totalCount == 1)
    #expect(longLines.results.first?.content == "facet long line that runs past thirty characters")
    #expect(longLines.results.first?.cueGroupLines.count == 2)
    #expect(longLines.results.first?.primaryGroupIndex == 1)

    let snapshot = try #require(try search.searchPage("facet", limit: 10).facetSnapshot)
    #expect(snapshot.cueIDs.count == 8)
    #expect(snapshot.distribution.durationCounts == [
        .underOneSecond: 5,
        .oneToUnderThreeSeconds: 3,
    ])
    #expect(snapshot.filteredCueIDs(using: shortCues, limit: 8).distribution.durationCounts == [
        .underOneSecond: 5,
        .oneToUnderThreeSeconds: 3,
    ])
    // Character counts apply the duration selection: the three short SRT lines
    // (21 characters), the short ASS line (11) and the long ASS line (48).
    #expect(snapshot.filteredCueIDs(using: shortCues, limit: 8).distribution.characterCounts == [
        .elevenToTwenty: 1,
        .twentyOneToThirty: 3,
        .thirtyOneOrMore: 1,
    ])
    #expect(snapshot.distribution.totalCount == 8)

    // Every filtered scan carries the unfiltered scan's snapshot, so its
    // results are exactly the snapshot's rows under the same selection. Two
    // checked cards: Duration `<1s` with Character `31+` leaves the long ASS
    // line, while the snapshot still counts all eight matches.
    let twoCards = CueFacetFilter(durations: [.underOneSecond], characters: [.thirtyOneOrMore])
    let twoCardRows = try search.searchPage("facet", limit: 10, facetFilter: twoCards)
    #expect(twoCardRows.totalCount == 1)
    #expect(twoCardRows.facetSnapshot == snapshot)
    #expect(twoCardRows.cueIDs == snapshot.filteredCueIDs(using: twoCards, limit: 8).cueIDs)

    // Watch state: with `finished` checked the SRT file is the result, and the
    // snapshot still holds the ASS file's two rows.
    try LibraryDatabase(path: databaseURL).setLibraryWatchState(
        videoFile: URL(fileURLWithPath: "/Media/Facet.mkv"),
        duration: nil,
        state: .finished
    )
    let finished = CueFacetFilter(watchStates: [.finished])
    let finishedRows = try search.searchPage("facet", limit: 10, facetFilter: finished)
    #expect(finishedRows.totalCount == 6)
    let watchedSnapshot = try #require(finishedRows.facetSnapshot)
    #expect(watchedSnapshot.cueIDs.count == 8)
    #expect(watchedSnapshot.distribution.watchStateCounts == [.finished: 6, .unwatched: 2])

    let finishedShort = CueFacetFilter(durations: [.underOneSecond], watchStates: [.finished])
    let finishedShortRows = try search.searchPage("facet", limit: 10, facetFilter: finishedShort)
    #expect(finishedShortRows.totalCount == 3)
    #expect(finishedShortRows.facetSnapshot == watchedSnapshot)
    #expect(finishedShortRows.cueIDs == watchedSnapshot.filteredCueIDs(using: finishedShort, limit: 8).cueIDs)
}

@Test
func searchPageReadsTheSelectedFoldersFirstAndKeepsTheSnapshotInDisplayOrder() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try IndexingDatabase(path: databaseURL)
    try DatabaseBootstrap.prepare(at: databaseURL)
    for folder in ["Alpha", "Beta"] {
        try database.replaceEntries(
            subtitleFile: URL(fileURLWithPath: "/Media/\(folder)/Folder.srt"),
            videoFile: URL(fileURLWithPath: "/Media/\(folder)/Folder.mkv"),
            entries: (0..<3).map { index in
                SubtitleEntry(
                    sequenceNumber: index + 1,
                    startTimecode: "00:00:0\(index),000",
                    endTimecode: "00:00:0\(index),500",
                    startMilliseconds: index * 1_000,
                    endMilliseconds: index * 1_000 + 500,
                    text: "Folder line \(index)"
                )
            }
        )
    }
    let search = try SearchDatabase(path: databaseURL)

    let unfiltered = try search.searchPage("folder", limit: 10)
    let snapshot = try #require(unfiltered.facetSnapshot)
    #expect(snapshot.distribution.folderCounts == ["/Media/Alpha": 3, "/Media/Beta": 3])
    #expect(try search.cueFacetDistribution().folderCounts == ["/Media/Alpha": 3, "/Media/Beta": 3])

    // Only the folder that comes last in display order is selected: the scan
    // reads it first, its rows are the results in their own order, and the
    // snapshot is back in display order, the same as the unfiltered scan's.
    let lastFolder = URL(fileURLWithPath: try #require(unfiltered.results.last).subtitlePath)
        .deletingLastPathComponent()
        .path
    let otherFolder = lastFolder == "/Media/Beta" ? "/Media/Alpha" : "/Media/Beta"
    let selected = CueFacetFilter(excludedFolders: [otherFolder])
    let selectedRows = try search.searchPage("folder", limit: 10, facetFilter: selected)
    #expect(selectedRows.totalCount == 3)
    #expect(selectedRows.results.map(\.content) == ["Folder line 0", "Folder line 1", "Folder line 2"])
    #expect(selectedRows.results.allSatisfy { $0.subtitlePath.hasPrefix(lastFolder + "/") })
    #expect(selectedRows.facetSnapshot == snapshot)
    #expect(selectedRows.cueIDs == snapshot.filteredCueIDs(using: selected, limit: 6).cueIDs)
}

@Test
func searchPageFiltersLanguagesInTheRowReadsAndCountsThemFromTheStoredTable() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try IndexingDatabase(path: databaseURL)
    try DatabaseBootstrap.prepare(at: databaseURL)
    func detection(_ language: SubtitleLanguageCode) -> SubtitleLanguageDetectionResult {
        SubtitleLanguageDetectionResult(
            languages: [language],
            confidence: 1,
            segmentCount: 1,
            effectiveCharacterCount: 12,
            distribution: [SubtitleLanguageDistribution(language: language, share: 1)]
        )
    }
    try database.replaceEntries(
        subtitleFile: URL(fileURLWithPath: "/Media/Japanese.srt"),
        videoFile: URL(fileURLWithPath: "/Media/Japanese.mkv"),
        entries: [
            languageFilterTestEntry(sequenceNumber: 1, text: "shared 日本語の一行目"),
            languageFilterTestEntry(sequenceNumber: 2, text: "shared 日本語の二行目")
        ],
        languageAnalysis: SubtitleLanguageAnalysis(
            format: .srt,
            fileDetection: detection(.japanese),
            styleDetections: [:],
            cueGroupLanguages: [[.japanese], [.japanese]]
        )
    )
    try database.replaceEntries(
        subtitleFile: URL(fileURLWithPath: "/Media/English.srt"),
        videoFile: URL(fileURLWithPath: "/Media/English.mkv"),
        entries: [languageFilterTestEntry(sequenceNumber: 1, text: "shared english line")],
        languageAnalysis: SubtitleLanguageAnalysis(
            format: .srt,
            fileDetection: detection(.english),
            styleDetections: [:],
            cueGroupLanguages: [[.english]]
        )
    )

    let search = try SearchDatabase(path: databaseURL)
    let englishOnly = try search.searchPage(
        "shared",
        limit: 10,
        facetFilter: CueFacetFilter(languages: [.english])
    )
    #expect(englishOnly.results.map(\.content) == ["shared english line"])
    #expect(englishOnly.results.map(\.languages) == [[.english]])
    #expect(englishOnly.totalCount == 1)
    // The snapshot still counts the rows in the other languages.
    #expect(englishOnly.facetSnapshot?.distribution.languageCounts == [.japanese: 2, .english: 1])

    let legacyEnglish = try search.searchPage(
        "shared",
        limit: 10,
        languageFilter: try #require(SubtitleSearchLanguageFilter(rawValue: "en"))
    )
    #expect(legacyEnglish.results.map(\.content) == ["shared english line"])

    let everything = try search.searchPage("shared", limit: 10)
    #expect(everything.totalCount == 3)
    #expect(everything.results.map(\.languages) == [[.english], [.japanese], [.japanese]])
    #expect(everything.facetSnapshot?.distribution.languageCounts == [.japanese: 2, .english: 1])
    #expect(try search.cueFacetDistribution().languageCounts == [.japanese: 2, .english: 1])
}
