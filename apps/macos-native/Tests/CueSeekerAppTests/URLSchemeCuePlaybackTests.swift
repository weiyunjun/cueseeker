import AppKit
import CueSeekerCore
import Foundation
import Testing
@testable import CueSeekerApp

@MainActor
@Test
func urlSchemeCueDeepLinkBuildsOneItemPlaylistAndReturnsToSearch() async throws {
    let fixture = try makeURLSchemeCuePlaybackFixture("OneItemPlaylist")
    defer { fixture.cleanup() }
    fixture.app.addFolder(fixture.root)
    await fixture.app.indexingTask?.value
    await fixture.app.libraryTask?.value
    guard case .completed = fixture.app.indexing.indexingStatus else {
        Issue.record("Fixture indexing did not complete: \(fixture.app.indexing.indexingStatus)")
        return
    }

    let searchDatabase = try #require(fixture.app.search.database)
    let cueID = try #require(
        try searchDatabase.allCuesVisiblePage(
            limit: 1,
            cursor: .start
        ).results.first?.entryID
    )
    let resolvedResult = try #require(try searchDatabase.cuePlaybackResult(cueID: cueID))
    #expect(resolvedResult.entryID == cueID)
    #expect(try searchDatabase.cuePlaybackResult(cueID: Int64.max) == nil)

    fixture.app.workbenchLayout.navigate(to: .excerpt)
    var presentationReadyCount = 0
    fixture.app.handleURLSchemeCommand(.cue(id: cueID)) {
        presentationReadyCount += 1
    }
    let lookupTask = try #require(fixture.app.urlSchemeCueLookupTask)
    await lookupTask.value

    #expect(presentationReadyCount == 1)
    #expect(fixture.app.pendingURLSchemeCuePlaybackIntent == nil)
    #expect(fixture.app.search.selectedSearchResult?.entryID == cueID)
    #expect(fixture.app.playback.isPlaybackSurfaceExpanded)
    #expect(fixture.app.workbenchLayout.panelMode == .excerpt)

    let source = try #require(fixture.app.playback.playlistSource)
    let position = try #require(fixture.app.playback.playlistPosition)
    #expect(source.origin == .cue(cueID: cueID))
    #expect(source.boundary.totalCount == 1)
    #expect(position.datasetID == source.boundary.datasetID)
    #expect(position.itemIdentity == .search(cueID))
    #expect(position.ordinal == 0)
    let item = try #require(source.item(at: 0))
    #expect(item.primaryCueIdentity == .cue(cueID))
    #expect(item.primaryCueText == "direct cue target with enough searchable text")
    #expect(source.item(at: 1) == nil)
    #expect(!fixture.app.canGoPrevious)
    #expect(!fixture.app.canGoNext)

    let overlaySession = try #require(fixture.app.playback.beginSubtitleFocusSession(
        openSnapshot: PlaybackSubtitleFocusOpenSnapshot(
            source: SubtitleFocusSourceIdentity(
                videoPath: resolvedResult.videoPath,
                subtitlePath: resolvedResult.subtitlePath,
                subtitleFormat: resolvedResult.subtitleFormat
            ),
            timestampMilliseconds: resolvedResult.startMilliseconds,
            wasPlaying: false
        ),
        searchStore: fixture.app.search
    ))
    #expect(overlaySession.availableModules.contains(.playlist))
    #expect(overlaySession.playlistWindow?.snapshot.totalCount == 1)
    #expect(overlaySession.playlistWindow?.selectedOrdinal == 0)
    #expect(overlaySession.playlistWindow?.item(at: 0)?.primaryCueIdentity == .cue(cueID))

    fixture.app.stopPlayback()
    #expect(fixture.app.workbenchLayout.panelMode == .excerpt)
    #expect(!fixture.app.playback.isPlaybackSurfaceExpanded)
}

@MainActor
@Test
func urlSchemeUnavailableCueDoesNotReplaceCurrentPresentation() async throws {
    let fixture = try makeURLSchemeCuePlaybackFixture("Unavailable")
    defer { fixture.cleanup() }
    fixture.app.workbenchLayout.navigate(to: .excerpt)
    fixture.app.search.updateQuery("keep me")

    var presentationReadyCount = 0
    fixture.app.handleURLSchemeCommand(.cue(id: Int64.max)) {
        presentationReadyCount += 1
    }
    let lookupTask = try #require(fixture.app.urlSchemeCueLookupTask)
    await lookupTask.value

    #expect(presentationReadyCount == 1)
    #expect(fixture.app.pendingURLSchemeCuePlaybackIntent == nil)
    #expect(fixture.app.workbenchLayout.panelMode == .excerpt)
    #expect(fixture.app.search.searchQuery == "keep me")
    #expect(!fixture.app.isPlaybackPageVisible)
    #expect(fixture.app.playback.playlistSource == nil)
}

@MainActor
@Test
func newURLSchemeCommandCancelsPendingCueLookup() throws {
    let fixture = try makeURLSchemeCuePlaybackFixture("Cancellation")
    defer { fixture.cleanup() }
    let pendingTask = Task<Void, Never> {
        try? await Task.sleep(for: .seconds(10))
    }
    fixture.app.pendingURLSchemeCuePlaybackIntent = URLSchemeCuePlaybackIntent(
        id: UUID(),
        cueID: 1
    )
    fixture.app.urlSchemeCueLookupTask = pendingTask

    fixture.app.handleURLSchemeCommand(.search(keyword: "replacement"))

    #expect(pendingTask.isCancelled)
    #expect(fixture.app.pendingURLSchemeCuePlaybackIntent == nil)
    #expect(fixture.app.urlSchemeCueLookupTask == nil)
    #expect(fixture.app.search.searchQuery == "replacement")
}

@MainActor
private func makeURLSchemeCuePlaybackFixture(
    _ name: String
) throws -> (
    app: AppCoordinator,
    root: URL,
    cleanup: () -> Void
) {
    let suiteName = "URLSchemeCuePlaybackTests-\(name)-\(UUID().uuidString)"
    let userDefaults = try #require(UserDefaults(suiteName: suiteName))
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("URLSchemeCuePlaybackTests-\(name)-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try """
    1
    00:00:01,000 --> 00:00:02,000
    direct cue target with enough searchable text

    2
    00:00:03,000 --> 00:00:04,000
    other cue with enough searchable text

    """.write(
        to: root.appendingPathComponent("Episode.srt"),
        atomically: true,
        encoding: .utf8
    )
    #expect(FileManager.default.createFile(
        atPath: root.appendingPathComponent("Episode.mkv").path,
        contents: Data()
    ))
    _ = NSApplication.shared
    let app = AppCoordinator(
        userDefaults: userDefaults,
        databaseURL: root.appendingPathComponent("CueSeeker.sqlite")
    )
    return (
        app,
        root,
        {
            userDefaults.removePersistentDomain(forName: suiteName)
            try? FileManager.default.removeItem(at: root)
        }
    )
}
