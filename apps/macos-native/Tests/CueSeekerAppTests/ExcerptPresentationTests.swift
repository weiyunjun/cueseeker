import AppKit
import Foundation
import Testing
@testable import CueSeekerCore
@testable import CueSeekerApp

@MainActor
@Test
func removeExcerptDoesNotHydrateLegacyPresentationWhenTableOnly() async throws {
    let suiteName = "CueSeekerExcerptPresentationTests-\(UUID().uuidString)"
    let userDefaults = try #require(UserDefaults.temporary(suiteName: suiteName))
    let fixtureRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerExcerptPresentationTests-\(UUID().uuidString)", isDirectory: true)
    let databaseURL = fixtureRoot
        .appendingPathComponent("CueSeekerExcerptPresentationTests.sqlite")
    defer {
        userDefaults.removePersistentDomainAndPlist(forName: suiteName)
        try? FileManager.default.removeItem(at: fixtureRoot)
    }

    try FileManager.default.createDirectory(
        at: fixtureRoot,
        withIntermediateDirectories: true
    )

    _ = NSApplication.shared
    let app = AppCoordinator(userDefaults: userDefaults, databaseURL: databaseURL)
    let database = try #require(app.indexingDatabase)
    let excerptDatabase = try #require(app.excerptDatabase)
    let first = try makeExcerpt(
        in: database,
        id: 1,
        content: "first saved cue"
    )
    _ = try makeExcerpt(
        in: database,
        id: 2,
        content: "second saved cue"
    )

    #expect(try excerptDatabase.excerptCount() == 2)
    #expect(app.excerpt.residentRelations.isEmpty)

    #expect(app.removeExcerpt(first, reloadPresentation: true))
    try await waitForExcerptTasksToFinish(app)

    #expect(try excerptDatabase.excerptCount() == 1)
    #expect(app.excerpt.residentRelations.isEmpty)
    #expect(!app.excerpt.tableHasLoadedInitialPage)
}

@MainActor
@Test
func excerptOverviewAndTableLoadingFollowTheSelectedList() async throws {
    let suiteName = "CueSeekerExcerptListRoutingTests-\(UUID().uuidString)"
    let userDefaults = try #require(UserDefaults.temporary(suiteName: suiteName))
    let fixtureRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "CueSeekerExcerptListRoutingTests-\(UUID().uuidString)",
            isDirectory: true
        )
    let databaseURL = fixtureRoot.appendingPathComponent("CueSeeker.sqlite")
    defer {
        userDefaults.removePersistentDomainAndPlist(forName: suiteName)
        try? FileManager.default.removeItem(at: fixtureRoot)
    }
    try FileManager.default.createDirectory(
        at: fixtureRoot,
        withIntermediateDirectories: true
    )

    _ = NSApplication.shared
    let app = AppCoordinator(userDefaults: userDefaults, databaseURL: databaseURL)
    let indexingDatabase = try #require(app.indexingDatabase)
    let excerptDatabase = try #require(app.excerptDatabase)
    let defaultList = try #require(try excerptDatabase.excerptList(
        id: ExcerptListIdentity.defaultListID
    ))
    let secondList = try excerptDatabase.createExcerptList(
        name: "Second",
        createdAt: Date(timeIntervalSince1970: 200)
    )
    let defaultItem = try makeExcerpt(
        in: indexingDatabase,
        id: 10,
        content: "Default list cue",
        listID: defaultList.id
    )
    let secondItem = try makeExcerpt(
        in: indexingDatabase,
        id: 20,
        content: "Second list cue",
        listID: secondList.id
    )
    try excerptDatabase.recordRecentExcerptPlayback(
        excerptID: secondItem.id,
        playedAt: Date(timeIntervalSince1970: 300)
    )

    app.reloadExcerptListOverview()
    try await waitForExcerptTasksToFinish(app)
    #expect(app.excerpt.listOverview.lists.map(\.id) == [defaultList.id, secondList.id])
    #expect(app.excerpt.listOverview.lists.map(\.cueCount) == [1, 1])
    #expect(app.excerpt.listOverview.uniqueCueCount == 2)
    #expect(app.excerpt.recentListSummaries.map(\.id) == [secondList.id])
    #expect(app.excerpt.recentListSummaries.first?.resumeExcerpt?.id == secondItem.id)

    app.openExcerptList(id: defaultList.id)
    try await waitForExcerptTasksToFinish(app)
    #expect(app.workbenchLayout.selectedExcerptListID == defaultList.id)
    #expect(app.excerpt.activeListID == defaultList.id)
    #expect(app.excerpt.residentRelations.map(\.id) == [defaultItem.id])

    app.showExcerptListOverview()
    #expect(app.workbenchLayout.selectedExcerptListID == nil)
    #expect(app.excerpt.activeListID == defaultList.id)
    #expect(app.excerpt.residentRelations.map(\.id) == [defaultItem.id])
    #expect(app.excerptListOverviewTask == nil)

    app.openExcerptList(id: secondList.id)
    try await waitForExcerptTasksToFinish(app)
    #expect(app.workbenchLayout.selectedExcerptListID == secondList.id)
    #expect(app.excerpt.activeListID == secondList.id)
    #expect(app.excerpt.activeListSummary?.list.id == secondList.id)
    #expect(app.excerpt.activeListSummary?.list.name == secondList.name)
    #expect(app.excerpt.activeListSummary?.cueCount == 1)
    #expect(app.excerpt.activeListSummary?.resumeExcerpt?.id == secondItem.id)
    #expect(app.excerpt.activeListHasPlayableContent)
    #expect(app.excerpt.residentRelations.map(\.id) == [secondItem.id])

    app.showExcerptListOverview()
    try await waitForExcerptTasksToFinish(app)
    #expect(app.workbenchLayout.selectedExcerptListID == nil)
    #expect(app.excerpt.activeListID == secondList.id)

    let emptyList = try excerptDatabase.createExcerptList(name: "Empty")
    app.reloadExcerptListOverview()
    try await waitForExcerptTasksToFinish(app)
    app.openExcerptList(id: emptyList.id)
    try await waitForExcerptTasksToFinish(app)
    #expect(app.excerpt.activeListSummary?.cueCount == 0)
    #expect(app.excerpt.activeListSummary?.resumeExcerpt == nil)
    #expect(!app.excerpt.activeListHasPlayableContent)
}

@MainActor
@Test
func recentExcerptPlaybackRefreshesCommandPanelBeforeKeyboardNavigation() async throws {
    let suiteName = "CueSeekerRecentExcerptCommandPanelTests-\(UUID().uuidString)"
    let userDefaults = try #require(UserDefaults.temporary(suiteName: suiteName))
    let fixtureRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "CueSeekerRecentExcerptCommandPanelTests-\(UUID().uuidString)",
            isDirectory: true
        )
    let databaseURL = fixtureRoot.appendingPathComponent("CueSeeker.sqlite")
    defer {
        userDefaults.removePersistentDomainAndPlist(forName: suiteName)
        try? FileManager.default.removeItem(at: fixtureRoot)
    }
    try FileManager.default.createDirectory(
        at: fixtureRoot,
        withIntermediateDirectories: true
    )

    _ = NSApplication.shared
    let app = AppCoordinator(userDefaults: userDefaults, databaseURL: databaseURL)
    let indexingDatabase = try #require(app.indexingDatabase)
    let excerptDatabase = try #require(app.excerptDatabase)
    let firstList = try #require(try excerptDatabase.excerptList(
        id: ExcerptListIdentity.defaultListID
    ))
    let secondList = try excerptDatabase.createExcerptList(name: "Second")
    let firstItem = try makeExcerpt(
        in: indexingDatabase,
        id: 40,
        content: "First list cue",
        listID: firstList.id
    )
    let secondItem = try makeExcerpt(
        in: indexingDatabase,
        id: 41,
        content: "Second list cue",
        listID: secondList.id
    )

    app.recordRecentExcerptPlayback(for: firstItem)
    #expect(app.excerpt.recentListSummaries.map(\.id) == [firstList.id])

    app.recordRecentExcerptPlayback(for: secondItem)
    #expect(app.excerpt.recentListSummaries.map(\.id) == [secondList.id, firstList.id])
    #expect(app.excerpt.recentListSummaries.first?.resumeExcerpt?.id == secondItem.id)

    app.excerpt.selectedExcerpt = secondItem
    app.playback.isPlaybackSurfaceExpanded = true
    #expect(app.presentPlaybackCommandPanel())
    #expect(app.presentPlaybackCommandPanelPage(.recentExcerpts))
    #expect(app.playback.commandPanelPresentation?.selectedOrdinal == 0)
    #expect(app.movePlaybackCommandPanelSelection(1))
    #expect(app.playback.commandPanelPresentation?.selectedOrdinal == 1)

    app.excerptListOverviewTask?.cancel()
    await app.excerptListOverviewTask?.value
}

@MainActor
@Test
func excerptTransfersRefreshPresentationAndPublishRegisteredToasts() async throws {
    let suiteName = "CueSeekerExcerptTransferPresentationTests-\(UUID().uuidString)"
    let userDefaults = try #require(UserDefaults.temporary(suiteName: suiteName))
    let fixtureRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "CueSeekerExcerptTransferPresentationTests-\(UUID().uuidString)",
            isDirectory: true
        )
    let databaseURL = fixtureRoot.appendingPathComponent("CueSeeker.sqlite")
    defer {
        userDefaults.removePersistentDomainAndPlist(forName: suiteName)
        try? FileManager.default.removeItem(at: fixtureRoot)
    }
    try FileManager.default.createDirectory(
        at: fixtureRoot,
        withIntermediateDirectories: true
    )

    _ = NSApplication.shared
    let app = AppCoordinator(userDefaults: userDefaults, databaseURL: databaseURL)
    let indexingDatabase = try #require(app.indexingDatabase)
    let excerptDatabase = try #require(app.excerptDatabase)
    let destination = try excerptDatabase.createExcerptList(name: "Destination")
    let movedSource = try makeExcerpt(
        in: indexingDatabase,
        id: 30,
        content: "Move this cue",
        listID: ExcerptListIdentity.defaultListID
    )
    let duplicatedSource = try makeExcerpt(
        in: indexingDatabase,
        id: 31,
        content: "Duplicate this cue",
        listID: ExcerptListIdentity.defaultListID
    )
    app.reloadExcerptListOverview()
    try await waitForExcerptTasksToFinish(app)
    app.openExcerptList(id: ExcerptListIdentity.defaultListID)
    try await waitForExcerptTasksToFinish(app)
    #expect(app.excerpt.tableHasLoadedInitialPage)
    #expect(app.excerpt.tableRowStore.snapshot.totalRowCount == 2)

    #expect(app.moveExcerpt(
        movedSource,
        toListID: destination.id,
        listName: destination.name
    ))
    try await waitForExcerptTasksToFinish(app)
    #expect(try excerptDatabase.excerptRelation(id: movedSource.id) == nil)
    #expect(app.toast.visibleItems.last?.request == ExcerptToastRequest.moveSucceeded(
        listName: destination.name
    ))
    #expect(app.excerpt.tableHasLoadedInitialPage)
    #expect(app.excerpt.tableRowStore.snapshot.totalRowCount == 1)
    #expect(app.excerpt.listOverview.lists.first {
        $0.id == ExcerptListIdentity.defaultListID
    }?.cueCount == 1)
    #expect(app.excerpt.listOverview.lists.first {
        $0.id == destination.id
    }?.cueCount == 1)

    #expect(app.duplicateExcerpt(
        duplicatedSource,
        toListID: destination.id,
        listName: destination.name
    ))
    try await waitForExcerptTasksToFinish(app)
    #expect(try excerptDatabase.excerptRelation(id: duplicatedSource.id) != nil)
    #expect(app.toast.visibleItems.last?.request == ExcerptToastRequest.duplicateSucceeded(
        listName: destination.name
    ))
    #expect(app.excerpt.tableRowStore.snapshot.totalRowCount == 1)
    #expect(app.excerpt.listOverview.lists.first {
        $0.id == destination.id
    }?.cueCount == 2)

    #expect(!app.duplicateExcerpt(
        duplicatedSource,
        toListID: destination.id,
        listName: destination.name
    ))
    try await waitForExcerptTasksToFinish(app)
    #expect(
        app.toast.visibleItems.last?.request
            == ExcerptToastRequest.destinationAlreadyContainsCue(
                listName: destination.name
            )
    )

    _ = try excerptDatabase.deleteExcerptList(id: destination.id)
    // The list is gone, so the only name left is the one the menu displayed.
    #expect(!app.moveExcerpt(
        duplicatedSource,
        toListID: destination.id,
        listName: destination.name
    ))
    #expect(
        app.toast.visibleItems.last?.request
            == ExcerptToastRequest.destinationUnavailable(
                listName: destination.name
            )
    )
    try await waitForExcerptTasksToFinish(app)
}

@MainActor
@Test
func excerptTableRowsAndOverviewLoadDuringIndexing() async throws {
    let suiteName = "CueSeekerExcerptIndexingTests-\(UUID().uuidString)"
    let userDefaults = try #require(UserDefaults.temporary(suiteName: suiteName))
    let fixtureRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerExcerptIndexingTests-\(UUID().uuidString)", isDirectory: true)
    let databaseURL = fixtureRoot.appendingPathComponent("CueSeeker.sqlite")
    defer {
        userDefaults.removePersistentDomainAndPlist(forName: suiteName)
        try? FileManager.default.removeItem(at: fixtureRoot)
    }
    try FileManager.default.createDirectory(
        at: fixtureRoot,
        withIntermediateDirectories: true
    )

    _ = NSApplication.shared
    let app = AppCoordinator(userDefaults: userDefaults, databaseURL: databaseURL)
    let indexingDatabase = try #require(app.indexingDatabase)
    let excerptDatabase = try #require(app.excerptDatabase)
    let defaultList = try #require(try excerptDatabase.excerptList(
        id: ExcerptListIdentity.defaultListID
    ))
    let item = try makeExcerpt(
        in: indexingDatabase,
        id: 42,
        content: "Persisted excerpt during indexing",
        listID: defaultList.id
    )

    // Simulate indexing is in progress
    let indexingFolder = URL(fileURLWithPath: "/Media/ActiveFolder")
    app.indexing.indexingStatus = .indexing(indexingFolder)
    #expect(app.indexing.indexingStatus.isIndexing)

    // Verify overview loads during indexing
    app.reloadExcerptListOverview()
    try await waitForExcerptTasksToFinish(app)
    #expect(app.excerpt.hasLoadedListOverview)
    #expect(app.excerpt.listOverview.lists.map(\.id) == [defaultList.id])

    // Verify excerpt table rows load during indexing
    app.openExcerptList(id: defaultList.id)
    try await waitForExcerptTasksToFinish(app)
    #expect(app.excerpt.tableHasLoadedInitialPage)
    #expect(app.excerpt.residentRelations.map(\.id) == [item.id])
    #expect(app.excerpt.tableRowStore.snapshot.totalRowCount == 1)
}

@MainActor
@Test
func openExcerptListTriggersPerformanceTrackingAndCompletesOnVisibleRows() async throws {
    let suiteName = "CueSeekerExcerptPerformanceIntegrationTests-\(UUID().uuidString)"
    let userDefaults = try #require(UserDefaults.temporary(suiteName: suiteName))
    let fixtureRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "CueSeekerExcerptPerformanceIntegrationTests-\(UUID().uuidString)",
            isDirectory: true
        )
    let databaseURL = fixtureRoot.appendingPathComponent("CueSeeker.sqlite")
    defer {
        userDefaults.removePersistentDomainAndPlist(forName: suiteName)
        try? FileManager.default.removeItem(at: fixtureRoot)
    }
    try FileManager.default.createDirectory(
        at: fixtureRoot,
        withIntermediateDirectories: true
    )

    _ = NSApplication.shared
    let app = AppCoordinator(userDefaults: userDefaults, databaseURL: databaseURL)
    let indexingDatabase = try #require(app.indexingDatabase)
    let excerptDatabase = try #require(app.excerptDatabase)
    let list = try excerptDatabase.createExcerptList(
        name: "Tracked List",
        createdAt: Date()
    )
    _ = try makeExcerpt(
        in: indexingDatabase,
        id: 101,
        content: "Tracked cue item",
        listID: list.id
    )

    ExcerptOpenPerformanceTracker.reset(listID: list.id)
    defer { ExcerptOpenPerformanceTracker.reset(listID: list.id) }
    app.openExcerptList(id: list.id)
    try await waitForExcerptTasksToFinish(app)

    #expect(app.excerpt.residentRelations.count == 1)

    // Simulate visible rows rendered by table
    ExcerptOpenPerformanceTracker.recordVisibleRowsRendered(
        listID: list.id,
        visibleRows: 0..<1
    )

    let report = ExcerptOpenPerformanceTracker.lastReport(forListID: list.id)
    #expect(report?.listID == list.id)
    #expect(report?.title == list.name)
    #expect(report?.count == 1)
    #expect(report?.cacheHit == false)
    #expect((report?.totalDuration ?? -1) >= 0)
}

private func makeExcerpt(
    in database: IndexingDatabase,
    id: Int,
    content: String,
    listID: Int64? = nil
) throws -> Excerpt {
    let subtitleFile = URL(fileURLWithPath: "/Media/Excerpt-\(id).srt")
    let videoFile = URL(fileURLWithPath: "/Media/Excerpt-\(id).mkv")
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
                text: content
            )
        ]
    )
    let selection = try #require(try PlaybackSubtitleDatabase(path: database.path).cueTextSelection(
        forSubtitleFile: subtitleFile,
        atMilliseconds: 1_500
    ))
    return try ExcerptDatabase(path: database.path).upsertExcerpt(
        selection: selection,
        listID: listID
    )
}

@MainActor
private func waitForExcerptTasksToFinish(_ app: AppCoordinator) async throws {
    for _ in 0..<200 {
        if app.excerptListOverviewTask == nil, app.excerptTableRowsTask == nil, app.excerptMutationTask == nil {
            return
        }
        try await Task.sleep(nanoseconds: 10_000_000)
    }
    Issue.record("Timed out waiting for Excerpt list tasks")
}
