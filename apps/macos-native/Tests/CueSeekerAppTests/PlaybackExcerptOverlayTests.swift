import AppKit
@testable import CueSeekerCore
import CueSeekerPlayback
import Foundation
import Testing
@testable import CueSeekerApp

@MainActor
@Test
func playbackExcerptUsesWorkbenchRowsWithoutRetainingAnotherDataset() throws {
    let fixtures = (0..<40).map(playbackSharedExcerptFixture)
    let store = playbackSharedExcerptStore(fixtures)
    let session = PlaybackSubtitleFocusSessionStore(
        openSnapshot: playbackSharedExcerptOpenSnapshot(),
        sessionGeneration: 1,
        availableModules: PlaybackOverlayModule.allCases,
        excerptStore: store
    )
    let window = try #require(session.excerptWindow)

    #expect(session.excerptStore === store)
    #expect(window.snapshot.totalCount == 40)
    #expect(window.snapshot.loadedOrdinalRange == 0..<40)
    #expect(window.snapshot.isComplete)
    #expect(window.item(at: 39)?.identity == .excerpt(10_039))
    #expect(window.item(at: 39)?.primaryCueText == "excerpt-39")

    _ = session.dismissByUser()

    #expect(store.tableRowStore.snapshot.totalRowCount == 40)
    #expect(store.tableRowStore.snapshot.row(at: 39)?.primaryCueText == "excerpt-39")
}

@MainActor
@Test
func playbackExcerptEmptyWorkbenchCollectionKeepsAnEmptyModuleWindow() throws {
    let store = ExcerptStore()
    let session = PlaybackSubtitleFocusSessionStore(
        openSnapshot: playbackSharedExcerptOpenSnapshot(),
        sessionGeneration: 1,
        availableModules: PlaybackOverlayModule.allCases,
        excerptStore: store
    )
    let window = try #require(session.excerptWindow)

    #expect(window.snapshot.totalCount == 0)
    #expect(window.snapshot.isComplete)
    #expect(window.selectedOrdinal == nil)
    #expect(window.item(at: 0) == nil)
}

@MainActor
@Test
func playbackExcerptUsesWorkbenchCuePresentationForActions() throws {
    let store = playbackSharedExcerptStore([playbackSharedExcerptFixture(0)])
    let session = PlaybackSubtitleFocusSessionStore(
        openSnapshot: playbackSharedExcerptOpenSnapshot(),
        sessionGeneration: 1,
        availableModules: PlaybackOverlayModule.allCases,
        excerptStore: store
    )
    #expect(session.publishInitialSnapshot(
        SubtitleFocusSnapshot(
            totalCount: 1,
            selectedOrdinal: 0,
            cues: [SubtitleFocusCue(
                id: 1,
                cueGroupID: 2,
                ordinal: 0,
                eventIndex: 0,
                displayOrder: 0,
                startMilliseconds: 0,
                endMilliseconds: 900,
                content: "current"
            )]
        ),
        token: session.token
    ))
    #expect(session.selectModule(.excerpt))

    guard case .ready(let execution) = session.requestKeyboardAction(
        .copyCueText
    ) else {
        Issue.record("Expected the shared Excerpt row to be actionable")
        return
    }

    #expect(execution.target.primaryCueText == "excerpt-0")
    guard case .excerpt(let targetItem) = execution.target else {
        Issue.record("Expected a Excerpt action target")
        return
    }
    #expect(targetItem.additionalCueTexts == ["before-0", "after-0"])
    #expect(execution.target.actionContext?.cue.id == 20_000)
}

@MainActor
@Test
func playbackExcerptCopiesSettledPrimaryCueAsMarkdownLink() throws {
    _ = NSApplication.shared
    let databaseURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("playback-excerpt-markdown-\(UUID().uuidString).sqlite")
    defer { try? FileManager.default.removeItem(at: databaseURL) }
    let app = AppCoordinator(databaseURL: databaseURL)
    app.playback.playbackViewModel = PlaybackViewModel(player: PlaybackPlayer())
    let store = playbackSharedExcerptStore([playbackSharedExcerptFixture(0)])
    let session = try #require(app.playback.beginSubtitleFocusSession(
        openSnapshot: playbackSharedExcerptOpenSnapshot(),
        availableModules: PlaybackOverlayModule.allCases,
        excerptStore: store
    ))
    #expect(session.publishInitialSnapshot(
        SubtitleFocusSnapshot(
            totalCount: 1,
            selectedOrdinal: 0,
            cues: [SubtitleFocusCue(
                id: 1,
                cueGroupID: 2,
                ordinal: 0,
                eventIndex: 0,
                displayOrder: 0,
                startMilliseconds: 0,
                endMilliseconds: 900,
                content: "current"
            )]
        ),
        token: session.token
    ))
    #expect(session.selectModule(.excerpt))
    NSPasteboard.general.clearContents()

    guard case .ready(let execution) = session.requestKeyboardAction(
        .copyCueMarkdownLink
    ) else {
        Issue.record("Expected the settled Excerpt Cue to be actionable")
        return
    }
    #expect(app.executePlaybackSubtitleFocusAction(execution))

    #expect(
        NSPasteboard.general.string(forType: .string)
            == "[excerpt-0](cueseeker://cue?id=20000)"
    )
    #expect(
        app.playback.playbackViewModel?.feedback?.text
            == "Deep Link Copied"
    )
    #expect(session.activeKeyboardAction == nil)
}

@MainActor
@Test
func playbackExcerptDispatchUsesCurrentWorkbenchResultOrder() throws {
    _ = NSApplication.shared
    let databaseURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("playback-shared-excerpt-dispatch-\(UUID().uuidString).sqlite")
    defer { try? FileManager.default.removeItem(at: databaseURL) }
    let app = AppCoordinator(databaseURL: databaseURL)
    let fixtures = (0..<3).map(playbackSharedExcerptFixture)
    let store = playbackSharedExcerptStore(fixtures)
    app.excerpt.tableRowStore.updateExcerptRows(
        fixtures.map(playbackSharedExcerptRowSource),
        tableName: "excerpt"
    )
    app.excerpt.installTableResultExcerptIDs(fixtures.map(\.excerpt.id))
    let item = PlaybackCueResultItem(
        excerpt: fixtures[1].excerpt,
        cuePresentation: fixtures[1].presentation,
        ordinal: 1
    )
    var receivedScope: [Int64]?

    let dispatched = app.dispatchPlaybackExcerptOverlayItem(item) { _, scope in
        receivedScope = scope
    }

    #expect(dispatched)
    #expect(receivedScope == store.tableResultExcerptIDs)
}

@MainActor
@Test
func sharedExcerptPipelineAppliesLivePrimaryCueSearchBeforePlaybackProjection() async throws {
    let suiteName = "PlaybackSharedExcerptPipeline-\(UUID().uuidString)"
    let userDefaults = try #require(UserDefaults(suiteName: suiteName))
    let databaseURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("PlaybackSharedExcerptPipeline-\(UUID().uuidString).sqlite")
    defer {
        userDefaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: databaseURL)
        try? FileManager.default.removeItem(atPath: databaseURL.path + "-wal")
        try? FileManager.default.removeItem(atPath: databaseURL.path + "-shm")
    }
    _ = NSApplication.shared
    let app = AppCoordinator(
        userDefaults: userDefaults,
        databaseURL: databaseURL
    )
    await app.startupDatabaseTask?.value
    let database = try #require(app.indexingDatabase)
    _ = try playbackDatabaseExcerpt(
        database: database,
        content: "alpha shared excerpt",
        timestamp: 1_000
    )
    _ = try playbackDatabaseExcerpt(
        database: database,
        content: "beta shared excerpt",
        timestamp: 2_000
    )
    app.reloadExcerptTableRows()
    await app.excerptTableRowsTask?.value

    #expect(
        (0..<app.excerpt.tableRowStore.snapshot.totalRowCount)
            .compactMap { app.excerpt.tableRowStore.snapshot.row(at: $0)?.displayTitle }
            .contains { $0.localizedCaseInsensitiveContains("Excerpt-1000") }
    )

    app.updateExcerptSearchQuery("alp")

    #expect(app.excerpt.tableResultRowCount == 1)
    #expect(app.excerpt.tableRowStore.snapshot.totalRowCount == 1)
    #expect(
        app.excerpt.tableRowStore.snapshot.row(at: 0)?.primaryCueText
            == "alpha shared excerpt"
    )

    app.updateExcerptSearchQuery("Excerpt-1000")
    #expect(app.excerpt.tableResultRowCount == 0)
    #expect(app.excerpt.tableRowStore.snapshot.totalRowCount == 0)

    app.updateExcerptSearchQuery("alp")

    let session = PlaybackSubtitleFocusSessionStore(
        openSnapshot: playbackSharedExcerptOpenSnapshot(),
        sessionGeneration: 1,
        excerptStore: app.excerpt
    )
    let window = try #require(session.excerptWindow)
    #expect(window.snapshot.totalCount == 1)
    #expect(window.item(at: 0)?.primaryCueText == "alpha shared excerpt")
}

@MainActor
@Test
func sharedExcerptFacetSelectionRestoresAndProjectsWithoutDatabaseReload() async throws {
    let suiteName = "PlaybackSharedExcerptFacet-\(UUID().uuidString)"
    let userDefaults = try #require(UserDefaults(suiteName: suiteName))
    let databaseURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("PlaybackSharedExcerptFacet-\(UUID().uuidString).sqlite")
    defer {
        userDefaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: databaseURL)
        try? FileManager.default.removeItem(atPath: databaseURL.path + "-wal")
        try? FileManager.default.removeItem(atPath: databaseURL.path + "-shm")
    }
    _ = NSApplication.shared
    let app = AppCoordinator(
        userDefaults: userDefaults,
        databaseURL: databaseURL
    )
    await app.startupDatabaseTask?.value
    let database = try #require(app.indexingDatabase)
    let shortExcerpt = try playbackDatabaseExcerpt(
        database: database,
        content: "short shared excerpt",
        timestamp: 1_000
    )
    let longExcerpt = try playbackDatabaseExcerpt(
        database: database,
        content: "long shared excerpt",
        timestamp: 2_000,
        durationMilliseconds: 4_000
    )
    let listID = try #require(app.excerpt.activeListID)
    let persistedFilter = CueFacetFilter(durations: [.underOneSecond])
    app.settings.setExcerptFacetFilter(persistedFilter, forListID: listID)

    app.openExcerptList(id: listID)
    await app.excerptTableRowsTask?.value

    let initialSnapshotID = app.excerpt.tableResultSnapshotID
    #expect(app.excerpt.tableFacetFilter == persistedFilter)
    #expect(app.excerpt.residentFacetSnapshot?.distribution.totalCount == 2)
    let persistedProjection = app.residentExcerptTableProjection(
        searchText: app.excerpt.tableSearchDraft,
        facetFilter: persistedFilter
    )
    #expect(persistedProjection.distribution.totalCount == 1)
    #expect(persistedProjection.distribution.durationCounts == [
        .underOneSecond: 1,
        .threeToUnderFiveSeconds: 1,
    ])
    #expect(app.excerpt.tableResultRowCount == 1)
    #expect(app.excerpt.playbackTableResultExcerptIDs == [shortExcerpt.id])

    app.updateExcerptFacetFilter(CueFacetFilter())

    #expect(app.excerptTableRowsTask == nil)
    #expect(app.excerpt.tableResultSnapshotID != initialSnapshotID)
    #expect(app.residentExcerptTableProjection(
        searchText: app.excerpt.tableSearchDraft,
        facetFilter: CueFacetFilter()
    ).distribution.totalCount == 2)
    #expect(app.excerpt.tableResultRowCount == 2)
    #expect(app.excerpt.tableRowStore.snapshot.totalRowCount == 2)
    #expect(Set(app.excerpt.playbackTableResultExcerptIDs ?? []) == [
        shortExcerpt.id,
        longExcerpt.id,
    ])

    app.updateExcerptFacetFilter(CueFacetFilter(languages: [.unknown]))

    #expect(app.excerptTableRowsTask == nil)
    #expect(app.excerpt.tableResultRowCount == 2)
    #expect(app.excerpt.tableRowStore.snapshot.totalRowCount == 2)
    #expect(Set(app.excerpt.playbackTableResultExcerptIDs ?? []) == [
        shortExcerpt.id,
        longExcerpt.id,
    ])

    let session = PlaybackSubtitleFocusSessionStore(
        openSnapshot: playbackSharedExcerptOpenSnapshot(),
        sessionGeneration: 1,
        excerptStore: app.excerpt
    )
    let window = try #require(session.excerptWindow)
    #expect(window.snapshot.totalCount == 2)
}

private struct PlaybackSharedExcerptFixture {
    let excerpt: Excerpt
    let presentation: ExcerptCuePresentation
}

private func playbackSharedExcerptFixture(
    _ ordinal: Int
) -> PlaybackSharedExcerptFixture {
    let excerptID = Int64(10_000 + ordinal)
    return PlaybackSharedExcerptFixture(
        excerpt: Excerpt(
            id: excerptID,
            subtitlePath: "/subtitle/excerpt-\(ordinal).ass",
            subtitleFormat: .ass,
            videoPath: "/video/excerpt-\(ordinal).mkv",
            videoName: "excerpt-\(ordinal).mkv",
            startMilliseconds: ordinal * 1_000,
            endMilliseconds: ordinal * 1_000 + 900,
            cueEventIndex: ordinal,
            cueDisplayOrder: 1,
            content: "excerpt-\(ordinal)",
            isValid: true,
            createdAt: "2026-07-15T00:00:00Z"
        ),
        presentation: ExcerptCuePresentation(
            cueID: Int64(20_000 + ordinal),
            cueGroupID: Int64(30_000 + ordinal),
            primaryGroupIndex: 1,
            cueGroupTexts: [
                "before-\(ordinal)",
                "excerpt-\(ordinal)",
                "after-\(ordinal)",
            ],
            languages: [.japanese],
        )
    )
}

@MainActor
private func playbackSharedExcerptStore(
    _ fixtures: [PlaybackSharedExcerptFixture]
) -> ExcerptStore {
    let store = ExcerptStore()
    store.tableRowStore.updateExcerptRows(
        fixtures.map(playbackSharedExcerptRowSource),
        tableName: "excerpt"
    )
    store.installTableResultExcerptIDs(fixtures.map(\.excerpt.id))
    store.markTableRowsLoaded(totalSavedRowCount: fixtures.count)
    return store
}

private func playbackSharedExcerptRowSource(
    _ fixture: PlaybackSharedExcerptFixture
) -> TableSandboxExcerptRowSource {
    TableSandboxExcerptRowSource(
        excerpt: fixture.excerpt,
        displayTitle: fixture.excerpt.videoName,
        dateAddedText: fixture.excerpt.createdAt,
        languages: [.japanese],
        cuePresentation: fixture.presentation
    )
}

private func playbackDatabaseExcerpt(
    database: IndexingDatabase,
    content: String,
    timestamp: Int,
    durationMilliseconds: Int = 500
) throws -> Excerpt {
    let subtitleFile = URL(fileURLWithPath: "/Media/Excerpt-\(timestamp).srt")
    let videoFile = URL(fileURLWithPath: "/Media/Excerpt-\(timestamp).mkv")
    try database.replaceEntries(
        subtitleFile: subtitleFile,
        videoFile: videoFile,
        entries: [
            SubtitleEntry(
                sequenceNumber: 1,
                startTimecode: "00:00:00,000",
                endTimecode: "00:00:00,500",
                startMilliseconds: timestamp,
                endMilliseconds: timestamp + durationMilliseconds,
                text: content
            )
        ]
    )
    let selection = try #require(try PlaybackSubtitleDatabase(path: database.path).cueTextSelection(
        forSubtitleFile: subtitleFile,
        atMilliseconds: timestamp
    ))
    return try ExcerptDatabase(path: database.path).upsertExcerpt(
        selection: selection,
        createdAt: Date(timeIntervalSince1970: TimeInterval(timestamp))
    )
}

private func playbackSharedExcerptOpenSnapshot()
    -> PlaybackSubtitleFocusOpenSnapshot {
    PlaybackSubtitleFocusOpenSnapshot(
        source: SubtitleFocusSourceIdentity(
            videoPath: "/video/current.mkv",
            subtitlePath: "/subtitle/current.ass",
            subtitleFormat: .ass
        ),
        timestampMilliseconds: 0,
        wasPlaying: false
    )
}
