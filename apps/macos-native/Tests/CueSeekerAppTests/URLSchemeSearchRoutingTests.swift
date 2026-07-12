import AppKit
import Foundation
import Testing
import CueSeekerCore
@testable import CueSeekerApp

@MainActor
@Test
func urlSchemeSearchClearsFiltersAndForcesSearchRoute() throws {
    let suiteName = "URLSchemeSearchRoutingTests-\(UUID().uuidString)"
    let userDefaults = try #require(UserDefaults(suiteName: suiteName))
    let databaseURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("URLSchemeSearchRoutingTests-\(UUID().uuidString).sqlite")
    defer {
        userDefaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: databaseURL)
        try? FileManager.default.removeItem(atPath: databaseURL.path + "-wal")
        try? FileManager.default.removeItem(atPath: databaseURL.path + "-shm")
    }

    _ = NSApplication.shared
    let app = AppCoordinator(userDefaults: userDefaults, databaseURL: databaseURL)
    app.workbenchLayout.selectPanelMode(.shiori)
    app.search.activeFilterSet = SubtitleSearchFilterSet(rules: [
        SubtitleSearchFilterRule(
            field: .display,
            operatorID: .contains,
            value: "old filter"
        )
    ])
    app.search.cueContextSearchRequest = CueContextSearchRequest(
        displayTitle: "Old context",
        subtitlePath: "/tmp/old.ass",
        targetCueID: 42
    )

    app.handleURLSchemeCommand(.search(keyword: "大丈夫"))

    #expect(app.workbenchLayout.panelMode == .search)
    #expect(app.search.searchQuery == "大丈夫")
    #expect(app.search.activeFilterSet.isEffectivelyEmpty)
    #expect(app.search.cueContextSearchRequest == nil)
}

@MainActor
@Test
func urlSchemeDirectPlayFallsBackToSearchWhenFirstPageCannotProduceResults() throws {
    let fixture = try makeURLSchemeRoutingFixture("DirectPlayFallback")
    defer { fixture.cleanup() }
    fixture.app.settings.urlSchemePlayFirstSearchResultEnabled = true
    fixture.app.workbenchLayout.selectPanelMode(.shiori)

    fixture.app.handleURLSchemeCommand(.search(keyword: "missing"))

    #expect(fixture.app.workbenchLayout.panelMode == .search)
    #expect(fixture.app.search.searchQuery == "missing")
    #expect(fixture.app.pendingURLSchemeDirectPlayIntent == nil)
    #expect(!fixture.app.playback.isPlaybackSurfaceExpanded)
}

@MainActor
@Test
func urlSchemeDirectPlayConsumesOnlyMatchingFirstPageGeneration() throws {
    let fixture = try makeURLSchemeRoutingFixture("DirectPlayGeneration")
    defer { fixture.cleanup() }
    let activeID = UUID()
    fixture.app.search.searchQuery = "target"
    fixture.app.pendingURLSchemeDirectPlayIntent = URLSchemeDirectPlayIntent(
        id: activeID,
        keyword: "target"
    )
    let result = makeURLSchemeSearchResult(id: 7, content: "target result")

    #expect(!fixture.app.resolveURLSchemeDirectPlayIntent(
        id: UUID(),
        firstPageResult: result
    ))
    #expect(fixture.app.pendingURLSchemeDirectPlayIntent?.id == activeID)

    #expect(fixture.app.resolveURLSchemeDirectPlayIntent(
        id: activeID,
        firstPageResult: result
    ))
    #expect(fixture.app.pendingURLSchemeDirectPlayIntent == nil)
    #expect(fixture.app.workbenchLayout.panelMode == .search)
    #expect(fixture.app.search.selectedSearchResult == result)
    #expect(fixture.app.playback.isPlaybackSurfaceExpanded)
}

@MainActor
@Test
func urlSchemeDirectPlayUsesFirstResultFromExistingCompleteFirstPage() async throws {
    let suiteName = "URLSchemeDirectPlayFirstPageTests-\(UUID().uuidString)"
    let userDefaults = try #require(UserDefaults(suiteName: suiteName))
    let fixtureRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("URLSchemeDirectPlayFirstPageTests-\(UUID().uuidString)", isDirectory: true)
    let databaseURL = fixtureRoot.appendingPathComponent("CueSeeker.sqlite")
    defer {
        userDefaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: fixtureRoot)
    }
    try FileManager.default.createDirectory(at: fixtureRoot, withIntermediateDirectories: true)
    try """
    1
    00:00:01,000 --> 00:00:02,000
    shared pipeline first result

    2
    00:00:03,000 --> 00:00:04,000
    shared pipeline second result

    """.write(
        to: fixtureRoot.appendingPathComponent("Episode.srt"),
        atomically: true,
        encoding: .utf8
    )
    #expect(FileManager.default.createFile(
        atPath: fixtureRoot.appendingPathComponent("Episode.mkv").path,
        contents: Data()
    ))

    _ = NSApplication.shared
    let app = AppCoordinator(userDefaults: userDefaults, databaseURL: databaseURL)
    app.addFolder(fixtureRoot)
    await app.indexingTask?.value
    await app.libraryTask?.value
    app.settings.urlSchemePlayFirstSearchResultEnabled = true
    app.workbenchLayout.selectPanelMode(.shiori)

    app.handleURLSchemeCommand(.search(keyword: "shared pipeline"))
    await app.searchTask?.value

    #expect(app.search.searchResults.count == 2)
    #expect(app.search.selectedSearchResult == app.search.searchResults.first)
    #expect(app.search.selectedSearchResult?.content == "shared pipeline first result")
    #expect(app.workbenchLayout.panelMode == .search)
    #expect(app.playback.isPlaybackSurfaceExpanded)
    #expect(app.pendingURLSchemeDirectPlayIntent == nil)

    app.stopPlayback()
    #expect(app.workbenchLayout.panelMode == .search)
    #expect(app.search.searchQuery == "shared pipeline")
    #expect(!app.playback.isPlaybackSurfaceExpanded)
}

@MainActor
@Test
func newURLSchemeCommandCancelsOldIntentSearchTasksAndPlaybackIndependentlyOfSetting() throws {
    let fixture = try makeURLSchemeRoutingFixture("CommandCancellation")
    defer { fixture.cleanup() }
    let playbackIntentID = UUID()
    let playbackResult = makeURLSchemeSearchResult(id: 11, content: "old playback")
    fixture.app.search.searchQuery = "old playback"
    fixture.app.pendingURLSchemeDirectPlayIntent = URLSchemeDirectPlayIntent(
        id: playbackIntentID,
        keyword: "old playback"
    )
    #expect(fixture.app.resolveURLSchemeDirectPlayIntent(
        id: playbackIntentID,
        firstPageResult: playbackResult
    ))
    #expect(fixture.app.playback.isPlaybackSurfaceExpanded)

    let staleIntent = URLSchemeDirectPlayIntent(id: UUID(), keyword: "stale")
    fixture.app.pendingURLSchemeDirectPlayIntent = staleIntent
    let oldSearchTask = Task<Void, Never> {
        try? await Task.sleep(nanoseconds: 10_000_000_000)
    }
    let oldExactTask = Task<Void, Never> {
        try? await Task.sleep(nanoseconds: 10_000_000_000)
    }
    fixture.app.searchTask = oldSearchTask
    fixture.app.searchExactCompletionTask = oldExactTask
    fixture.app.settings.urlSchemePlayFirstSearchResultEnabled = false

    fixture.app.handleURLSchemeCommand(.search(keyword: "replacement"))

    #expect(oldSearchTask.isCancelled)
    #expect(oldExactTask.isCancelled)
    #expect(fixture.app.pendingURLSchemeDirectPlayIntent == nil)
    #expect(!fixture.app.playback.isPlaybackSurfaceExpanded)
    #expect(fixture.app.search.selectedSearchResult == nil)
    #expect(fixture.app.search.searchQuery == "replacement")
    #expect(fixture.app.workbenchLayout.panelMode == .search)
}

@MainActor
private func makeURLSchemeRoutingFixture(
    _ name: String
) throws -> (app: AppCoordinator, cleanup: () -> Void) {
    let suiteName = "URLSchemeSearchRoutingTests-\(name)-\(UUID().uuidString)"
    let userDefaults = try #require(UserDefaults(suiteName: suiteName))
    let databaseURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("URLSchemeSearchRoutingTests-\(name)-\(UUID().uuidString).sqlite")
    _ = NSApplication.shared
    let app = AppCoordinator(userDefaults: userDefaults, databaseURL: databaseURL)
    return (
        app,
        {
            userDefaults.removePersistentDomain(forName: suiteName)
            try? FileManager.default.removeItem(at: databaseURL)
            try? FileManager.default.removeItem(atPath: databaseURL.path + "-wal")
            try? FileManager.default.removeItem(atPath: databaseURL.path + "-shm")
        }
    )
}

private func makeURLSchemeSearchResult(id: Int64, content: String) -> SubtitleSearchResult {
    SubtitleSearchResult(
        entryID: id,
        subtitlePath: "/Media/Episode.srt",
        subtitleFormat: .srt,
        videoPath: "/Media/Episode.mkv",
        videoName: "Episode.mkv",
        startMilliseconds: 1_000,
        endMilliseconds: 2_000,
        content: content,
        cueLines: [content]
    )
}
