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

    var presentationReadyCount = 0
    app.handleURLSchemeCommand(.search(keyword: "大丈夫")) {
        presentationReadyCount += 1
    }

    #expect(presentationReadyCount == 1)
    #expect(app.workbenchLayout.panelMode == .search)
    #expect(app.search.searchQuery == "大丈夫")
    #expect(app.search.activeFilterSet.isEffectivelyEmpty)
    #expect(app.search.cueContextSearchRequest == nil)
}

@MainActor
@Test
func urlSchemeSearchOpensOverlaySearchForActivePlaybackWithoutExistingSession() throws {
    let fixture = try makeURLSchemeRoutingFixture("OpenOverlaySearch")
    defer { fixture.cleanup() }
    let playingResult = makeURLSchemeSearchResult(
        id: 1,
        content: "existing playback"
    )
    fixture.app.ensurePlayerInitialized()
    fixture.app.search.selectedSearchResult = playingResult
    fixture.app.activePlaybackSource = .search
    fixture.app.playback.isPlaybackSurfaceExpanded = true
    fixture.app.playback.playbackStatus = .paused

    fixture.app.handleURLSchemeCommand(.search(keyword: "replacement"))

    let session = try #require(fixture.app.playback.subtitleFocusSession)
    #expect(session.selectedModule == .search)
    #expect(fixture.app.isPlaybackPageVisible)
    #expect(fixture.app.search.selectedSearchResult == playingResult)
    #expect(fixture.app.search.searchQuery == "replacement")
    #expect(fixture.app.search.isPlaybackTemporaryFilterActive)
}

@MainActor
@Test
func urlSchemeDirectPlayFallsBackToOverlaySearchWhenPlaybackIsActive() throws {
    let fixture = try makeURLSchemeRoutingFixture("DirectPlayFallback")
    defer { fixture.cleanup() }
    fixture.app.settings.urlSchemePlayFirstSearchResultEnabled = true
    fixture.app.workbenchLayout.selectPanelMode(.shiori)
    fixture.app.search.selectedSearchResult = makeURLSchemeSearchResult(
        id: 1,
        content: "existing playback"
    )
    fixture.app.playback.isPlaybackSurfaceExpanded = true
    fixture.app.playbackReturnContext = .shiori
    let originalResult = try #require(fixture.app.search.selectedSearchResult)
    let session = try installURLSchemePlaybackOverlaySession(
        app: fixture.app,
        result: originalResult
    )

    var presentationReadyCount = 0
    var presentedFallbackSearch = false
    fixture.app.handleURLSchemeCommand(.search(keyword: "missing")) {
        presentationReadyCount += 1
        presentedFallbackSearch = session.selectedModule == .search
            && fixture.app.isPlaybackPageVisible
    }

    #expect(presentationReadyCount == 1)
    #expect(presentedFallbackSearch)
    #expect(fixture.app.workbenchLayout.panelMode == .shiori)
    #expect(fixture.app.search.searchQuery == "missing")
    #expect(fixture.app.pendingURLSchemeDirectPlayIntent == nil)
    #expect(fixture.app.playback.isPlaybackSurfaceExpanded)
    #expect(fixture.app.search.selectedSearchResult == originalResult)
    #expect(fixture.app.search.isPlaybackTemporaryFilterActive)
}

@MainActor
@Test
func urlSchemeDirectPlayFallsBackToWorkbenchSearchWithoutPlayback() throws {
    let fixture = try makeURLSchemeRoutingFixture("DirectPlayWorkbenchFallback")
    defer { fixture.cleanup() }
    fixture.app.settings.urlSchemePlayFirstSearchResultEnabled = true
    fixture.app.workbenchLayout.selectPanelMode(.shiori)

    var presentationReadyCount = 0
    fixture.app.handleURLSchemeCommand(.search(keyword: "missing")) {
        presentationReadyCount += 1
    }

    #expect(presentationReadyCount == 1)
    #expect(fixture.app.workbenchLayout.panelMode == .search)
    #expect(fixture.app.search.searchQuery == "missing")
    #expect(fixture.app.playback.subtitleFocusSession == nil)
    #expect(!fixture.app.isPlaybackPageVisible)
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
    try """
    1
    00:00:05,000 --> 00:00:06,000
    alternate source result

    """.write(
        to: fixtureRoot.appendingPathComponent("Alternate.srt"),
        atomically: true,
        encoding: .utf8
    )
    #expect(FileManager.default.createFile(
        atPath: fixtureRoot.appendingPathComponent("Alternate.mkv").path,
        contents: Data()
    ))

    _ = NSApplication.shared
    let app = AppCoordinator(userDefaults: userDefaults, databaseURL: databaseURL)
    app.addFolder(fixtureRoot)
    await app.indexingTask?.value
    await app.libraryTask?.value
    app.settings.urlSchemePlayFirstSearchResultEnabled = true
    app.workbenchLayout.selectPanelMode(.shiori)

    var presentationReadyCount = 0
    var presentedPlayback = false
    app.handleURLSchemeCommand(.search(keyword: "shared pipeline")) {
        presentationReadyCount += 1
        presentedPlayback = app.isPlaybackPageVisible
            && app.workbenchLayout.panelMode == .search
    }

    #expect(presentationReadyCount == 0)
    #expect(app.workbenchLayout.panelMode == .shiori)
    await app.searchTask?.value

    #expect(presentationReadyCount == 1)
    #expect(presentedPlayback)
    #expect(app.search.searchResults.count == 2)
    #expect(app.search.selectedSearchResult == app.search.searchResults.first)
    #expect(app.search.selectedSearchResult?.content == "shared pipeline first result")
    #expect(app.workbenchLayout.panelMode == .search)
    #expect(app.playback.isPlaybackSurfaceExpanded)
    #expect(app.pendingURLSchemeDirectPlayIntent == nil)

    let originalPlaybackResult = try #require(app.search.selectedSearchResult)
    app.playbackReturnContext = .shiori
    var sameVideoPresentationReadyCount = 0
    app.handleURLSchemeCommand(.search(keyword: "shared pipeline")) {
        sameVideoPresentationReadyCount += 1
    }

    #expect(sameVideoPresentationReadyCount == 0)
    #expect(app.search.selectedSearchResult == originalPlaybackResult)
    #expect(app.playback.isPlaybackSurfaceExpanded)
    await app.searchTask?.value

    #expect(sameVideoPresentationReadyCount == 1)
    #expect(app.search.selectedSearchResult?.videoPath == originalPlaybackResult.videoPath)
    #expect(app.playback.isPlaybackSurfaceExpanded)
    #expect(app.playbackReturnContext == .shiori)

    let sameVideoPlaybackResult = try #require(app.search.selectedSearchResult)
    var differentVideoPresentationReadyCount = 0
    app.handleURLSchemeCommand(.search(keyword: "alternate source")) {
        differentVideoPresentationReadyCount += 1
    }

    #expect(differentVideoPresentationReadyCount == 0)
    #expect(app.search.selectedSearchResult == sameVideoPlaybackResult)
    #expect(app.playback.isPlaybackSurfaceExpanded)
    await app.searchTask?.value

    #expect(differentVideoPresentationReadyCount == 1)
    #expect(app.search.selectedSearchResult?.videoPath.hasSuffix("Alternate.mkv") == true)
    #expect(app.playback.isPlaybackSurfaceExpanded)
    #expect(app.playbackReturnContext == .shiori)

    app.stopPlayback()
    #expect(app.workbenchLayout.panelMode == .shiori)
    #expect(app.search.searchQuery == "alternate source")
    #expect(!app.playback.isPlaybackSurfaceExpanded)
}

@MainActor
@Test
func newURLSchemeCommandCancelsOldIntentAndPreservesPlaybackInOverlaySearch() throws {
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
    let session = try installURLSchemePlaybackOverlaySession(
        app: fixture.app,
        result: playbackResult
    )
    fixture.app.workbenchLayout.selectPanelMode(.shiori)

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
    #expect(fixture.app.playback.isPlaybackSurfaceExpanded)
    #expect(fixture.app.search.selectedSearchResult == playbackResult)
    #expect(fixture.app.search.searchQuery == "replacement")
    #expect(fixture.app.workbenchLayout.panelMode == .shiori)
    #expect(session.selectedModule == .search)
    #expect(fixture.app.search.isPlaybackTemporaryFilterActive)
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

@MainActor
private func installURLSchemePlaybackOverlaySession(
    app: AppCoordinator,
    result: SubtitleSearchResult
) throws -> PlaybackSubtitleFocusSessionStore {
    app.activePlaybackSource = .search
    let source = SubtitleFocusSourceIdentity(
        videoPath: result.videoPath,
        subtitlePath: result.subtitlePath,
        subtitleFormat: result.subtitleFormat
    )
    return try #require(app.playback.beginSubtitleFocusSession(
        openSnapshot: PlaybackSubtitleFocusOpenSnapshot(
            source: source,
            timestampMilliseconds: result.startMilliseconds,
            wasPlaying: false
        ),
        searchStore: app.search
    ))
}
