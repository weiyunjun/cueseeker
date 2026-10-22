import AppKit
@testable import CueSeekerCore
import Foundation
import Testing
@testable import CueSeekerApp

@MainActor
@Test
func sharedExcerptPipelineAppliesLivePrimaryCueSearchBeforePlaybackProjection() async throws {
    let suiteName = "PlaybackSharedExcerptPipeline-\(UUID().uuidString)"
    let userDefaults = try #require(UserDefaults.temporary(suiteName: suiteName))
    let databaseURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("PlaybackSharedExcerptPipeline-\(UUID().uuidString).sqlite")
    defer {
        userDefaults.removePersistentDomainAndPlist(forName: suiteName)
        removeTemporaryDatabase(at: databaseURL)
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
            .contains { $0.localizedCaseInsensitiveContains("Media - 01") }
    )

    app.updateExcerptSearchQuery("alp")

    #expect(app.excerpt.tableResultRowCount == 1)
    #expect(app.excerpt.tableRowStore.snapshot.totalRowCount == 1)
    #expect(
        app.excerpt.tableRowStore.snapshot.row(at: 0)?.primaryCueText
            == "alpha shared excerpt"
    )

    app.updateExcerptSearchQuery("Media - 01")
    #expect(app.excerpt.tableResultRowCount == 0)
    #expect(app.excerpt.tableRowStore.snapshot.totalRowCount == 0)

    app.updateExcerptSearchQuery("alp")
    #expect(app.excerpt.tableResultRowCount == 1)
    #expect(
        app.excerpt.tableRowStore.snapshot.row(at: 0)?.primaryCueText
            == "alpha shared excerpt"
    )
}

@MainActor
@Test
func sharedExcerptFacetSelectionRestoresAndProjectsWithoutDatabaseReload() async throws {
    let suiteName = "PlaybackSharedExcerptFacet-\(UUID().uuidString)"
    let userDefaults = try #require(UserDefaults.temporary(suiteName: suiteName))
    let databaseURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("PlaybackSharedExcerptFacet-\(UUID().uuidString).sqlite")
    defer {
        userDefaults.removePersistentDomainAndPlist(forName: suiteName)
        removeTemporaryDatabase(at: databaseURL)
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
