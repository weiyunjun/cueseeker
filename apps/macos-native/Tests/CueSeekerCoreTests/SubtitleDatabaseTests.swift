import Foundation
import SQLite3
import Testing
import CueSeekerCore

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
    #expect(page.fileSummaries.map(\.subtitleFileName) == ["Alpha.srt", "Beta.srt"])
    #expect(page.fileSummaries.map(\.matchCount) == [2, 1])
    #expect(page.results.map(\.content) == ["Shared earlier alpha", "Shared later alpha"])
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

    let page = try database.searchPage("shared", limit: 10)

    #expect(page.fileSummaries.map(\.subtitleFileName) == ["aa2.ass", "aa11.ass"])
    #expect(page.fileSummaries.map(\.subtitleDisplayTitle) == ["葬送的芙莉莲 - 02", "葬送的芙莉莲 - 03"])
    #expect(page.results.map(\.content) == ["Shared second", "Shared eleventh"])
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
func migrationToSchemaVersion11BackfillsCueGroupLineCount() throws {
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

private enum SQLiteFixtureError: Error {
    case openFailed(String)
    case executeFailed(String)
}
