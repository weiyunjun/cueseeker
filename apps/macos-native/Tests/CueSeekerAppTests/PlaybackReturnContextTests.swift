import AppKit
@testable import CueSeekerCore
import Foundation
import Testing
@testable import CueSeekerApp

@MainActor
@Test
func playbackReturnContextInitializesFromTheEnteringWorkbenchFeature() throws {
    let fixture = try playbackReturnContextFixture("initial")
    defer { fixture.cleanup() }
    let app = fixture.app

    app.workbenchLayout.selectPanelMode(.search)
    app.initializePlaybackReturnContextIfEntering()
    #expect(app.playbackReturnContext == .search)

    app.playbackReturnContext = nil
    app.workbenchLayout.selectPanelMode(.shiori)
    app.initializePlaybackReturnContextIfEntering()
    #expect(app.playbackReturnContext == .shiori)

    app.playbackReturnContext = nil
    app.workbenchLayout.selectPanelMode(.recentWatching)
    app.initializePlaybackReturnContextIfEntering()
    #expect(app.playbackReturnContext == .recent)

    let folder = playbackReturnContextFolder()
    app.library.completeLibraryFolderSummaries = [folder]
    app.workbenchLayout.selectPanelMode(.testLibrary)
    app.workbenchLayout.selectTestLibraryFolder(folder)
    app.playbackReturnContext = nil
    app.initializePlaybackReturnContextIfEntering()
    #expect(app.playbackReturnContext == .libraryFolderDetail(
        folderPath: folder.folderPath
    ))

    app.playback.isPlaybackSurfaceExpanded = true
    app.workbenchLayout.selectPanelMode(.search)
    app.initializePlaybackReturnContextIfEntering()
    #expect(app.playbackReturnContext == .libraryFolderDetail(
        folderPath: folder.folderPath
    ))
}

@MainActor
@Test
func playbackReturnContextChangesOnlyAfterSuccessfulPlayback() throws {
    let fixture = try playbackReturnContextFixture("success")
    defer { fixture.cleanup() }
    let app = fixture.app

    app.playbackReturnContext = .shiori
    app.commitPlaybackReturnContext(
        .search,
        afterSuccessfulPlayback: false
    )
    #expect(app.playbackReturnContext == .shiori)

    app.commitPlaybackReturnContext(
        .search,
        afterSuccessfulPlayback: true
    )
    #expect(app.playbackReturnContext == .search)

    app.commitPlaybackReturnContext(
        .recent,
        afterSuccessfulPlayback: true
    )
    #expect(app.playbackReturnContext == .recent)

    app.commitPlaybackReturnContext(
        .libraryFolderDetail(folderPath: "/Media/Show"),
        afterSuccessfulPlayback: true
    )
    #expect(app.playbackReturnContext == .libraryFolderDetail(
        folderPath: "/Media/Show"
    ))
}

@MainActor
@Test
func closingPlaybackRestoresEveryReturnTargetAndClearsTheContext() throws {
    let fixture = try playbackReturnContextFixture("restore")
    defer { fixture.cleanup() }
    let app = fixture.app
    let folder = playbackReturnContextFolder()
    app.library.completeLibraryFolderSummaries = [folder]
    app.search.searchQuery = "current shared query"

    let cases: [(PlaybackReturnContext, WorkbenchPanelMode)] = [
        (.search, .search),
        (.shiori, .shiori),
        (.recent, .recentWatching),
    ]
    for (context, expectedMode) in cases {
        app.workbenchLayout.selectPanelMode(.testLibrary)
        app.playback.isPlaybackSurfaceExpanded = true
        app.playbackReturnContext = context

        app.stopPlayback()

        #expect(app.workbenchLayout.panelMode == expectedMode)
        #expect(app.playbackReturnContext == nil)
        #expect(app.search.searchQuery == "current shared query")
    }

    app.workbenchLayout.selectPanelMode(.search)
    app.workbenchLayout.clearTestLibraryFolder()
    app.playback.isPlaybackSurfaceExpanded = true
    app.playbackReturnContext = .libraryFolderDetail(
        folderPath: folder.folderPath
    )

    app.stopPlayback()

    #expect(app.workbenchLayout.panelMode == .testLibrary)
    #expect(app.workbenchLayout.selectedTestLibraryFolder == folder)
    #expect(app.playbackReturnContext == nil)
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
