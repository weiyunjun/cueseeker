import AppKit
@testable import CueSeekerCore
import Foundation
import Testing
@testable import CueSeekerApp

@MainActor
@Test
func playbackLeavesTheWorkbenchOnThePageItWasEnteredFrom() throws {
    let fixture = try playbackReturnContextFixture("entry")
    defer { fixture.cleanup() }
    let app = fixture.app
    let folder = playbackReturnContextFolder()
    app.library.completeLibraryFolderSummaries = [folder]
    app.search.updateQuery("current shared query")

    let routes: [WorkbenchRoute] = [
        .search,
        .excerpt,
        .recent,
        .file,
        .libraryFolder(folderPath: folder.folderPath),
    ]
    for route in routes {
        app.navigateWorkbench(to: route)
        let historyBefore = app.workbenchLayout.route.history

        app.openSearchResult(playbackReturnContextResult())
        #expect(app.playback.isPlaybackSurfaceExpanded)
        #expect(app.workbenchLayout.currentRoute == route)

        app.stopPlayback()

        #expect(!app.playback.isPlaybackSurfaceExpanded)
        #expect(app.workbenchLayout.currentRoute == route)
        #expect(app.workbenchLayout.route.history == historyBefore)
        #expect(app.search.searchQuery == "current shared query")
    }
    #expect(app.workbenchLayout.selectedLibraryFolderPath == folder.folderPath)
}

@MainActor
@Test
func searchingDuringPlaybackDoesNotMoveTheWorkbench() throws {
    let fixture = try playbackReturnContextFixture("search")
    defer { fixture.cleanup() }
    let app = fixture.app
    app.navigateWorkbench(to: .recent)
    app.openSearchResult(playbackReturnContextResult())

    app.openSearchResult(
        playbackReturnContextResult(),
        playbackSearchPromotion: PlaybackSearchPromotion(
            query: "promoted",
            scopePaths: [],
            selectedOrdinal: 0
        )
    )
    #expect(app.workbenchLayout.currentRoute == .recent)

    app.stopPlayback()
    #expect(app.workbenchLayout.currentRoute == .recent)
    #expect(app.workbenchLayout.route.history == [.search, .recent])
}

@MainActor
private func playbackReturnContextFixture(
    _ suffix: String
) throws -> (
    app: AppCoordinator,
    cleanup: () -> Void
) {
    _ = NSApplication.shared
    let suiteName = "PlaybackReturnContext-\(suffix)-\(UUID().uuidString)"
    let userDefaults = try #require(UserDefaults(suiteName: suiteName))
    let databaseURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("\(suiteName).sqlite")
    let app = AppCoordinator(
        userDefaults: userDefaults,
        databaseURL: databaseURL
    )
    return (app, {
        userDefaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: databaseURL)
        try? FileManager.default.removeItem(atPath: databaseURL.path + "-wal")
        try? FileManager.default.removeItem(atPath: databaseURL.path + "-shm")
    })
}

private func playbackReturnContextFolder()
    -> CompleteLibraryFolderSummaryPresentation {
    CompleteLibraryFolderSummaryPresentation(
        folderPath: "/Media/Show",
        folderTitle: "Show",
        coverPath: nil,
        coverRevision: nil,
        episodeCount: 3
    )
}

private func playbackReturnContextResult() -> SubtitleSearchResult {
    SubtitleSearchResult(
        entryID: 1,
        subtitlePath: "/Media/Show/Episode.srt",
        subtitleFormat: .srt,
        videoPath: "/Media/Show/Episode.mkv",
        videoName: "Episode.mkv",
        startMilliseconds: 1_000,
        endMilliseconds: 2_000,
        content: "shared query",
        cueLines: ["shared query"]
    )
}
