import AppKit
import Foundation
import Testing
@testable import CueSeekerCore
@testable import CueSeekerApp

@MainActor
@Test
func removeShioriDoesNotHydrateLegacyPresentationWhenTableOnly() throws {
    let suiteName = "CueSeekerShioriPresentationTests-\(UUID().uuidString)"
    let userDefaults = try #require(UserDefaults(suiteName: suiteName))
    let fixtureRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerShioriPresentationTests-\(UUID().uuidString)", isDirectory: true)
    let databaseURL = fixtureRoot
        .appendingPathComponent("CueSeekerShioriPresentationTests.sqlite")
    defer {
        userDefaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: fixtureRoot)
    }

    try FileManager.default.createDirectory(
        at: fixtureRoot,
        withIntermediateDirectories: true
    )

    _ = NSApplication.shared
    let app = AppCoordinator(userDefaults: userDefaults, databaseURL: databaseURL)
    let database = try #require(app.indexingDatabase)
    let shioriDatabase = try #require(app.shioriDatabase)
    let first = try makeShiori(
        in: database,
        id: 1,
        content: "first saved cue"
    )
    _ = try makeShiori(
        in: database,
        id: 2,
        content: "second saved cue"
    )

    #expect(try shioriDatabase.shioriCount() == 2)
    #expect(app.shiori.residentRelations.isEmpty)

    #expect(app.removeShiori(first, reloadPresentation: true))

    #expect(try shioriDatabase.shioriCount() == 1)
    #expect(app.shiori.residentRelations.isEmpty)
    #expect(!app.shiori.tableHasLoadedInitialPage)
}

@MainActor
@Test
func shioriOverviewAndTableLoadingFollowTheSelectedList() async throws {
    let suiteName = "CueSeekerShioriListRoutingTests-\(UUID().uuidString)"
    let userDefaults = try #require(UserDefaults(suiteName: suiteName))
    let fixtureRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "CueSeekerShioriListRoutingTests-\(UUID().uuidString)",
            isDirectory: true
        )
    let databaseURL = fixtureRoot.appendingPathComponent("CueSeeker.sqlite")
    defer {
        userDefaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: fixtureRoot)
    }
    try FileManager.default.createDirectory(
        at: fixtureRoot,
        withIntermediateDirectories: true
    )

    _ = NSApplication.shared
    let app = AppCoordinator(userDefaults: userDefaults, databaseURL: databaseURL)
    let indexingDatabase = try #require(app.indexingDatabase)
    let shioriDatabase = try #require(app.shioriDatabase)
    let defaultList = try #require(try shioriDatabase.shioriList(
        id: ShioriListIdentity.defaultListID
    ))
    let secondList = try shioriDatabase.createShioriList(
        name: "Second",
        createdAt: Date(timeIntervalSince1970: 200)
    )
    let defaultItem = try makeShiori(
        in: indexingDatabase,
        id: 10,
        content: "Default list cue",
        listID: defaultList.id
    )
    let secondItem = try makeShiori(
        in: indexingDatabase,
        id: 20,
        content: "Second list cue",
        listID: secondList.id
    )
    try shioriDatabase.recordRecentShioriPlayback(
        shioriID: secondItem.id,
        playedAt: Date(timeIntervalSince1970: 300)
    )

    app.reloadShioriListOverview()
    try await waitForShioriTasksToFinish(app)
    #expect(app.shiori.listOverview.lists.map(\.id) == [secondList.id, defaultList.id])
    #expect(app.shiori.listOverview.lists.map(\.cueCount) == [1, 1])
    #expect(app.shiori.listOverview.uniqueCueCount == 2)
    #expect(app.shiori.recentListSummaries.map(\.id) == [secondList.id])
    #expect(app.shiori.recentListSummaries.first?.resumeShiori?.id == secondItem.id)

    app.openShioriList(id: defaultList.id)
    try await waitForShioriTasksToFinish(app)
    #expect(app.workbenchLayout.selectedShioriListID == defaultList.id)
    #expect(app.shiori.activeListID == defaultList.id)
    #expect(app.shiori.residentRelations.map(\.id) == [defaultItem.id])

    app.showShioriListOverview()
    #expect(app.workbenchLayout.selectedShioriListID == nil)
    #expect(app.shiori.activeListID == defaultList.id)
    #expect(app.shiori.residentRelations.map(\.id) == [defaultItem.id])
    #expect(app.shioriListOverviewTask == nil)

    app.openShioriList(id: secondList.id)
    try await waitForShioriTasksToFinish(app)
    #expect(app.workbenchLayout.selectedShioriListID == secondList.id)
    #expect(app.shiori.activeListID == secondList.id)
    #expect(app.shiori.activeListSummary?.list.id == secondList.id)
    #expect(app.shiori.activeListSummary?.list.name == secondList.name)
    #expect(app.shiori.activeListSummary?.cueCount == 1)
    #expect(app.shiori.activeListSummary?.resumeShiori?.id == secondItem.id)
    #expect(app.shiori.activeListHasPlayableContent)
    #expect(app.shiori.residentRelations.map(\.id) == [secondItem.id])

    app.showShioriListOverview()
    try await waitForShioriTasksToFinish(app)
    #expect(app.workbenchLayout.selectedShioriListID == nil)
    #expect(app.shiori.activeListID == secondList.id)

    let emptyList = try shioriDatabase.createShioriList(name: "Empty")
    app.reloadShioriListOverview()
    try await waitForShioriTasksToFinish(app)
    app.openShioriList(id: emptyList.id)
    try await waitForShioriTasksToFinish(app)
    #expect(app.shiori.activeListSummary?.cueCount == 0)
    #expect(app.shiori.activeListSummary?.resumeShiori == nil)
    #expect(!app.shiori.activeListHasPlayableContent)
}

@MainActor
@Test
func recentShioriPlaybackRefreshesCommandPanelBeforeKeyboardNavigation() async throws {
    let suiteName = "CueSeekerRecentShioriCommandPanelTests-\(UUID().uuidString)"
    let userDefaults = try #require(UserDefaults(suiteName: suiteName))
    let fixtureRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "CueSeekerRecentShioriCommandPanelTests-\(UUID().uuidString)",
            isDirectory: true
        )
    let databaseURL = fixtureRoot.appendingPathComponent("CueSeeker.sqlite")
    defer {
        userDefaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: fixtureRoot)
    }
    try FileManager.default.createDirectory(
        at: fixtureRoot,
        withIntermediateDirectories: true
    )

    _ = NSApplication.shared
    let app = AppCoordinator(userDefaults: userDefaults, databaseURL: databaseURL)
    let indexingDatabase = try #require(app.indexingDatabase)
    let shioriDatabase = try #require(app.shioriDatabase)
    let firstList = try #require(try shioriDatabase.shioriList(
        id: ShioriListIdentity.defaultListID
    ))
    let secondList = try shioriDatabase.createShioriList(name: "Second")
    let firstItem = try makeShiori(
        in: indexingDatabase,
        id: 40,
        content: "First list cue",
        listID: firstList.id
    )
    let secondItem = try makeShiori(
        in: indexingDatabase,
        id: 41,
        content: "Second list cue",
        listID: secondList.id
    )

    app.recordRecentShioriPlayback(for: firstItem)
    #expect(app.shiori.recentListSummaries.map(\.id) == [firstList.id])

    app.recordRecentShioriPlayback(for: secondItem)
    #expect(app.shiori.recentListSummaries.map(\.id) == [secondList.id, firstList.id])
    #expect(app.shiori.recentListSummaries.first?.resumeShiori?.id == secondItem.id)

    app.shiori.selectedShiori = secondItem
    app.playback.isPlaybackSurfaceExpanded = true
    #expect(app.presentPlaybackCommandPanel())
    #expect(app.presentPlaybackCommandPanelPage(.recentShioris))
    #expect(app.playback.commandPanelPresentation?.selectedOrdinal == 0)
    #expect(app.movePlaybackCommandPanelSelection(1))
    #expect(app.playback.commandPanelPresentation?.selectedOrdinal == 1)

    app.shioriListOverviewTask?.cancel()
    await app.shioriListOverviewTask?.value
}

@MainActor
@Test
func shioriTransfersRefreshPresentationAndPublishRegisteredToasts() async throws {
    let suiteName = "CueSeekerShioriTransferPresentationTests-\(UUID().uuidString)"
    let userDefaults = try #require(UserDefaults(suiteName: suiteName))
    let fixtureRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "CueSeekerShioriTransferPresentationTests-\(UUID().uuidString)",
            isDirectory: true
        )
    let databaseURL = fixtureRoot.appendingPathComponent("CueSeeker.sqlite")
    defer {
        userDefaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: fixtureRoot)
    }
    try FileManager.default.createDirectory(
        at: fixtureRoot,
        withIntermediateDirectories: true
    )

    _ = NSApplication.shared
    let app = AppCoordinator(userDefaults: userDefaults, databaseURL: databaseURL)
    let indexingDatabase = try #require(app.indexingDatabase)
    let shioriDatabase = try #require(app.shioriDatabase)
    let destination = try shioriDatabase.createShioriList(name: "Destination")
    let movedSource = try makeShiori(
        in: indexingDatabase,
        id: 30,
        content: "Move this cue",
        listID: ShioriListIdentity.defaultListID
    )
    let duplicatedSource = try makeShiori(
        in: indexingDatabase,
        id: 31,
        content: "Duplicate this cue",
        listID: ShioriListIdentity.defaultListID
    )
    app.reloadShioriListOverview()
    try await waitForShioriTasksToFinish(app)
    app.openShioriList(id: ShioriListIdentity.defaultListID)
    try await waitForShioriTasksToFinish(app)
    #expect(app.shiori.tableHasLoadedInitialPage)
    #expect(app.shiori.tableRowStore.snapshot.totalRowCount == 2)

    #expect(app.moveShiori(movedSource, toListID: destination.id))
    #expect(try shioriDatabase.shioriRelation(id: movedSource.id) == nil)
    #expect(app.toast.visibleItems.last?.request == ShioriToastRequest.moveSucceeded(
        listName: destination.name
    ))
    #expect(app.shiori.tableHasLoadedInitialPage)
    #expect(app.shiori.tableRowStore.snapshot.totalRowCount == 1)
    #expect(app.shiori.listOverview.lists.first {
        $0.id == ShioriListIdentity.defaultListID
    }?.cueCount == 1)
    #expect(app.shiori.listOverview.lists.first {
        $0.id == destination.id
    }?.cueCount == 1)

    #expect(app.duplicateShiori(duplicatedSource, toListID: destination.id))
    #expect(try shioriDatabase.shioriRelation(id: duplicatedSource.id) != nil)
    #expect(app.toast.visibleItems.last?.request == ShioriToastRequest.duplicateSucceeded(
        listName: destination.name
    ))
    #expect(app.shiori.tableRowStore.snapshot.totalRowCount == 1)
    #expect(app.shiori.listOverview.lists.first {
        $0.id == destination.id
    }?.cueCount == 2)

    #expect(!app.duplicateShiori(duplicatedSource, toListID: destination.id))
    #expect(
        app.toast.visibleItems.last?.request
            == ShioriToastRequest.destinationAlreadyContainsCue(
                listName: destination.name
            )
    )

    _ = try shioriDatabase.deleteShioriList(id: destination.id)
    #expect(!app.moveShiori(duplicatedSource, toListID: destination.id))
    #expect(
        app.toast.visibleItems.last?.request
            == ShioriToastRequest.destinationUnavailable
    )
    try await waitForShioriTasksToFinish(app)
}

private func makeShiori(
    in database: IndexingDatabase,
    id: Int,
    content: String,
    listID: Int64? = nil
) throws -> Shiori {
    let subtitleFile = URL(fileURLWithPath: "/Media/Shiori-\(id).srt")
    let videoFile = URL(fileURLWithPath: "/Media/Shiori-\(id).mkv")
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
    return try ShioriDatabase(path: database.path).upsertShiori(
        selection: selection,
        listID: listID
    )
}

@MainActor
private func waitForShioriTasksToFinish(_ app: AppCoordinator) async throws {
    for _ in 0..<200 {
        if app.shioriListOverviewTask == nil, app.shioriTableRowsTask == nil {
            return
        }
        try await Task.sleep(nanoseconds: 10_000_000)
    }
    Issue.record("Timed out waiting for Shiori list tasks")
}
