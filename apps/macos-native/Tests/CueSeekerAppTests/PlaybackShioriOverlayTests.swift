import AppKit
@testable import CueSeekerCore
import CueSeekerPlayback
import Foundation
import Testing
@testable import CueSeekerApp

@MainActor
@Test
func playbackShioriUsesWorkbenchRowsWithoutRetainingAnotherDataset() throws {
    let fixtures = (0..<40).map(playbackSharedShioriFixture)
    let store = playbackSharedShioriStore(fixtures)
    let session = PlaybackSubtitleFocusSessionStore(
        openSnapshot: playbackSharedShioriOpenSnapshot(),
        sessionGeneration: 1,
        availableModules: PlaybackOverlayModule.allCases,
        shioriStore: store
    )
    let window = try #require(session.shioriWindow)

    #expect(session.shioriStore === store)
    #expect(window.snapshot.totalCount == 40)
    #expect(window.snapshot.loadedOrdinalRange == 0..<40)
    #expect(window.snapshot.isComplete)
    #expect(window.item(at: 39)?.identity == .shiori(10_039))
    #expect(window.item(at: 39)?.primaryCueText == "shiori-39")

    _ = session.dismissByUser()

    #expect(store.tableRowStore.snapshot.totalRowCount == 40)
    #expect(store.tableRowStore.snapshot.row(at: 39)?.primaryCueText == "shiori-39")
}

@MainActor
@Test
func playbackShioriEmptyWorkbenchCollectionKeepsAnEmptyModuleWindow() throws {
    let store = ShioriStore()
    let session = PlaybackSubtitleFocusSessionStore(
        openSnapshot: playbackSharedShioriOpenSnapshot(),
        sessionGeneration: 1,
        availableModules: PlaybackOverlayModule.allCases,
        shioriStore: store
    )
    let window = try #require(session.shioriWindow)

    #expect(window.snapshot.totalCount == 0)
    #expect(window.snapshot.isComplete)
    #expect(window.selectedOrdinal == nil)
    #expect(window.item(at: 0) == nil)
}

@MainActor
@Test
func playbackShioriUsesWorkbenchCuePresentationForActions() throws {
    let store = playbackSharedShioriStore([playbackSharedShioriFixture(0)])
    let session = PlaybackSubtitleFocusSessionStore(
        openSnapshot: playbackSharedShioriOpenSnapshot(),
        sessionGeneration: 1,
        availableModules: PlaybackOverlayModule.allCases,
        shioriStore: store
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
    #expect(session.selectModule(.shiori))

    guard case .ready(let execution) = session.requestKeyboardAction(
        .copyCueText
    ) else {
        Issue.record("Expected the shared Shiori row to be actionable")
        return
    }

    #expect(execution.target.primaryCueText == "shiori-0")
    guard case .shiori(let targetItem) = execution.target else {
        Issue.record("Expected a Shiori action target")
        return
    }
    #expect(targetItem.additionalCueTexts == ["before-0", "after-0"])
    #expect(execution.target.actionContext?.cue.id == 20_000)
    #expect(execution.target.representsSavedShiori)
}

@MainActor
@Test
func playbackShioriCopiesSettledPrimaryCueAsMarkdownLink() throws {
    _ = NSApplication.shared
    let databaseURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("playback-shiori-markdown-\(UUID().uuidString).sqlite")
    defer { try? FileManager.default.removeItem(at: databaseURL) }
    let app = AppCoordinator(databaseURL: databaseURL)
    app.playback.playbackViewModel = PlaybackViewModel(player: PlaybackPlayer())
    let store = playbackSharedShioriStore([playbackSharedShioriFixture(0)])
    let session = try #require(app.playback.beginSubtitleFocusSession(
        openSnapshot: playbackSharedShioriOpenSnapshot(),
        availableModules: PlaybackOverlayModule.allCases,
        shioriStore: store
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
    #expect(session.selectModule(.shiori))
    NSPasteboard.general.clearContents()

    guard case .ready(let execution) = session.requestKeyboardAction(
        .copyCueMarkdownLink
    ) else {
        Issue.record("Expected the settled Shiori Cue to be actionable")
        return
    }
    #expect(app.executePlaybackSubtitleFocusAction(execution))

    #expect(
        NSPasteboard.general.string(forType: .string)
            == "[shiori-0](cueseeker://cue?id=20000)"
    )
    #expect(
        app.playback.playbackViewModel?.feedback?.text
            == "Subtitle(markdown format) Copied"
    )
    #expect(session.activeKeyboardAction == nil)
}

@MainActor
@Test
func playbackShioriDispatchUsesCurrentWorkbenchResultOrder() throws {
    _ = NSApplication.shared
    let databaseURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("playback-shared-shiori-dispatch-\(UUID().uuidString).sqlite")
    defer { try? FileManager.default.removeItem(at: databaseURL) }
    let app = AppCoordinator(databaseURL: databaseURL)
    let fixtures = (0..<3).map(playbackSharedShioriFixture)
    let store = playbackSharedShioriStore(fixtures)
    app.shiori.tableRowStore.updateShioriRows(
        fixtures.map(playbackSharedShioriRowSource),
        tableName: "shiori"
    )
    app.shiori.installTableResultShioriIDs(fixtures.map(\.shiori.id))
    let item = PlaybackCueResultItem(
        shiori: fixtures[1].shiori,
        cuePresentation: fixtures[1].presentation,
        ordinal: 1
    )
    var receivedScope: [Int64]?

    let dispatched = app.dispatchPlaybackShioriOverlayItem(item) { _, scope in
        receivedScope = scope
    }

    #expect(dispatched)
    #expect(receivedScope == store.tableResultShioriIDs)
}

@MainActor
@Test
func sharedShioriPipelineAppliesWorkbenchSearchBeforePlaybackProjection() async throws {
    let suiteName = "PlaybackSharedShioriPipeline-\(UUID().uuidString)"
    let userDefaults = try #require(UserDefaults(suiteName: suiteName))
    let databaseURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("PlaybackSharedShioriPipeline-\(UUID().uuidString).sqlite")
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
    _ = try playbackDatabaseShiori(
        database: database,
        content: "alpha shared shiori",
        timestamp: 1_000
    )
    _ = try playbackDatabaseShiori(
        database: database,
        content: "beta shared shiori",
        timestamp: 2_000
    )
    app.shiori.tableSubmittedSearchText = "alpha"

    app.reloadShioriTableRows()
    await app.shioriTableRowsTask?.value

    #expect(app.shiori.tableResultRowCount == 1)
    #expect(app.shiori.tableRowStore.snapshot.totalRowCount == 1)
    #expect(
        app.shiori.tableRowStore.snapshot.row(at: 0)?.primaryCueText
            == "alpha shared shiori"
    )

    let session = PlaybackSubtitleFocusSessionStore(
        openSnapshot: playbackSharedShioriOpenSnapshot(),
        sessionGeneration: 1,
        shioriStore: app.shiori
    )
    let window = try #require(session.shioriWindow)
    #expect(window.snapshot.totalCount == 1)
    #expect(window.item(at: 0)?.primaryCueText == "alpha shared shiori")
}

@MainActor
@Test
func sharedShioriFacetSelectionRestoresAndProjectsWithoutDatabaseReload() async throws {
    let suiteName = "PlaybackSharedShioriFacet-\(UUID().uuidString)"
    let userDefaults = try #require(UserDefaults(suiteName: suiteName))
    let databaseURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("PlaybackSharedShioriFacet-\(UUID().uuidString).sqlite")
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
    let shortShiori = try playbackDatabaseShiori(
        database: database,
        content: "short shared shiori",
        timestamp: 1_000
    )
    let longShiori = try playbackDatabaseShiori(
        database: database,
        content: "long shared shiori",
        timestamp: 2_000,
        durationMilliseconds: 4_000
    )
    let listID = try #require(app.shiori.activeListID)
    let persistedFilter = CueFacetFilter(durations: [.underOneSecond])
    app.settings.setShioriFacetFilter(persistedFilter, forListID: listID)

    app.openShioriList(id: listID)
    await app.shioriTableRowsTask?.value

    let initialSnapshotID = app.shiori.tableResultSnapshotID
    #expect(app.shiori.tableFacetFilter == persistedFilter)
    #expect(app.shiori.residentFacetSnapshot?.distribution.totalCount == 2)
    #expect(app.shiori.tableResultRowCount == 1)
    #expect(app.shiori.playbackTableResultShioriIDs == [shortShiori.id])

    app.updateShioriFacetFilter(CueFacetFilter())

    #expect(app.shioriTableRowsTask == nil)
    #expect(app.shiori.tableResultSnapshotID != initialSnapshotID)
    #expect(app.shiori.tableResultRowCount == 2)
    #expect(app.shiori.tableRowStore.snapshot.totalRowCount == 2)
    #expect(Set(app.shiori.playbackTableResultShioriIDs ?? []) == [
        shortShiori.id,
        longShiori.id,
    ])

    app.updateShioriFacetFilter(CueFacetFilter(languages: [.unknown]))

    #expect(app.shioriTableRowsTask == nil)
    #expect(app.shiori.tableResultRowCount == 2)
    #expect(app.shiori.tableRowStore.snapshot.totalRowCount == 2)
    #expect(Set(app.shiori.playbackTableResultShioriIDs ?? []) == [
        shortShiori.id,
        longShiori.id,
    ])

    let session = PlaybackSubtitleFocusSessionStore(
        openSnapshot: playbackSharedShioriOpenSnapshot(),
        sessionGeneration: 1,
        shioriStore: app.shiori
    )
    let window = try #require(session.shioriWindow)
    #expect(window.snapshot.totalCount == 2)
}

private struct PlaybackSharedShioriFixture {
    let shiori: Shiori
    let presentation: ShioriCuePresentation
}

private func playbackSharedShioriFixture(
    _ ordinal: Int
) -> PlaybackSharedShioriFixture {
    let shioriID = Int64(10_000 + ordinal)
    return PlaybackSharedShioriFixture(
        shiori: Shiori(
            id: shioriID,
            subtitlePath: "/subtitle/shiori-\(ordinal).ass",
            subtitleFormat: .ass,
            videoPath: "/video/shiori-\(ordinal).mkv",
            videoName: "shiori-\(ordinal).mkv",
            startMilliseconds: ordinal * 1_000,
            endMilliseconds: ordinal * 1_000 + 900,
            cueEventIndex: ordinal,
            cueDisplayOrder: 1,
            content: "shiori-\(ordinal)",
            isValid: true,
            createdAt: "2026-07-15T00:00:00Z"
        ),
        presentation: ShioriCuePresentation(
            cueID: Int64(20_000 + ordinal),
            cueGroupID: Int64(30_000 + ordinal),
            primaryGroupIndex: 1,
            cueGroupTexts: [
                "before-\(ordinal)",
                "shiori-\(ordinal)",
                "after-\(ordinal)",
            ],
            languages: [.japanese],
        )
    )
}

@MainActor
private func playbackSharedShioriStore(
    _ fixtures: [PlaybackSharedShioriFixture]
) -> ShioriStore {
    let store = ShioriStore()
    store.tableRowStore.updateShioriRows(
        fixtures.map(playbackSharedShioriRowSource),
        tableName: "shiori"
    )
    store.installTableResultShioriIDs(fixtures.map(\.shiori.id))
    store.markTableRowsLoaded(totalSavedRowCount: fixtures.count)
    return store
}

private func playbackSharedShioriRowSource(
    _ fixture: PlaybackSharedShioriFixture
) -> TableSandboxShioriRowSource {
    TableSandboxShioriRowSource(
        shiori: fixture.shiori,
        displayTitle: fixture.shiori.videoName,
        dateAddedText: fixture.shiori.createdAt,
        languages: [.japanese],
        shioriTags: [],
        cuePresentation: fixture.presentation
    )
}

private func playbackDatabaseShiori(
    database: IndexingDatabase,
    content: String,
    timestamp: Int,
    durationMilliseconds: Int = 500
) throws -> Shiori {
    let subtitleFile = URL(fileURLWithPath: "/Media/Shiori-\(timestamp).srt")
    let videoFile = URL(fileURLWithPath: "/Media/Shiori-\(timestamp).mkv")
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
    return try ShioriDatabase(path: database.path).upsertShiori(
        selection: selection,
        createdAt: Date(timeIntervalSince1970: TimeInterval(timestamp))
    )
}

private func playbackSharedShioriOpenSnapshot()
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
