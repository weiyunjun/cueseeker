import AppKit
@testable import CueSeekerCore
import Foundation
import Testing
@testable import CueSeekerApp

@Suite("Workbench Invalidation Handling")
struct WorkbenchInvalidationTests {

    @MainActor
    @Test
    func recentAndLibraryDeferReloadWhileActiveUntilReappearance() async throws {
        try await withWorkbenchInvalidationTestApp { app in
            app.activateWorkbenchPanelMode(.recentWatching)
            app.refreshRecentWatching()
            app.refreshLoadedTestRecentWatching()
            #expect(app.recentNeedsReloadAfterIndexedMutation)

            app.activateWorkbenchPanelMode(.testLibrary)
            app.refreshLibrary()
            app.refreshCompleteLibrary()
            #expect(app.libraryNeedsReloadAfterIndexedMutation)

            app.refreshRecentOnReappearanceIfNeeded()
            #expect(!app.recentNeedsReloadAfterIndexedMutation)

            app.refreshLibraryOnReappearanceIfNeeded()
            #expect(!app.libraryNeedsReloadAfterIndexedMutation)
        }
    }

    @MainActor
    @Test
    func heldWorkbenchRoutePreservesKnownRouteAcrossMutationsUntilDeparture() async throws {
        try await withWorkbenchInvalidationTestApp { app in
            app.indexing.selectedFolders = [URL(fileURLWithPath: "/Media/Show")]
            app.library.completeLibraryFolderSummaries = [
                CompleteLibraryFolderSummaryPresentation(
                    folderPath: "/Media/Show",
                    folderTitle: "Show",
                    coverPath: nil,
                    coverRevision: nil,
                    episodeCount: 1
                )
            ]
            app.library.completeLibraryStatus = .completed

            let goneFolder = WorkbenchRoute.libraryFolder(folderPath: "/Media/Gone")
            let goneFileFolder = WorkbenchRoute.fileFolder(rootPath: "/Media/Gone")
            let goneFileFiles = WorkbenchRoute.fileFiles(rootPath: "/Media/Gone", folderPath: "/Media/Gone/Sub")

            // Without hold, removed routes read as unknown
            #expect(app.isWorkbenchRouteUnknown(goneFolder))
            #expect(app.isWorkbenchRouteUnknown(goneFileFolder))
            #expect(app.isWorkbenchRouteUnknown(goneFileFiles))

            // When held, active routes are protected from premature invalidation
            app.heldWorkbenchRoute = goneFolder
            #expect(!app.isWorkbenchRouteUnknown(goneFolder))

            // Navigating away clears the hold and reconciles
            app.navigateWorkbench(to: .library)
            #expect(app.heldWorkbenchRoute == nil)
            #expect(app.isWorkbenchRouteUnknown(goneFolder))
        }
    }

    @MainActor
    @Test
    func openingInvalidLibraryVideoStopsPlayerAndShowsNotInLibraryError() async throws {
        try await withWorkbenchInvalidationTestApp { app in
            let invalidVideo = LibraryVideo(
                videoPath: "/Media/Missing/Episode1.mp4",
                videoName: "Episode1.mp4",
                duration: 120.0,
                subtitlePath: "/Media/Missing/Episode1.srt",
                subtitleFormat: .srt
            )

            app.openLibraryVideo(invalidVideo)

            #expect(app.currentPlaybackItemLeftLibrary)
            #expect(app.playback.playbackStatus == .loadFailed)
            #expect(app.playback.errorMessages[.notInLibrary] != nil)
        }
    }

    @MainActor
    @Test
    func libraryFolderStaysHeldDuringFolderRemovalUntilDeparture() async throws {
        try await withWorkbenchInvalidationTestApp { app in
            let folderURL = URL(fileURLWithPath: "/Media/Show")
            app.indexing.selectedFolders = [folderURL]
            app.library.completeLibraryFolderSummaries = [
                CompleteLibraryFolderSummaryPresentation(
                    folderPath: "/Media/Show",
                    folderTitle: "Show",
                    coverPath: nil,
                    coverRevision: nil,
                    episodeCount: 1
                )
            ]
            app.library.completeLibraryStatus = .completed

            // User navigates to Level 2
            app.activateWorkbenchPanelMode(.testLibrary)
            app.navigateWorkbench(to: .libraryFolder(folderPath: "/Media/Show"))

            // Folder removal mutation finishes
            app.holdActiveWorkbenchRouteBeforeContentMutation()
            #expect(app.heldWorkbenchRoute == .libraryFolder(folderPath: "/Media/Show"))

            app.indexing.removeFolder(folderURL)
            app.clearSearchAndPlaybackState(under: folderURL)
            app.refreshLibrary()
            app.refreshCompleteLibrary()

            // Level 2 remains held: summaries preserved, route known
            #expect(!app.isWorkbenchRouteUnknown(.libraryFolder(folderPath: "/Media/Show")))
            #expect(app.library.completeLibraryFolderSummaries.contains { $0.folderPath == "/Media/Show" })
            #expect(app.libraryNeedsReloadAfterIndexedMutation)

            // Returning to Level 1 clears hold and cleanses summaries
            app.navigateWorkbench(to: .library)
            await app.completeLibraryTask?.value
            #expect(app.heldWorkbenchRoute == nil)
            #expect(!app.libraryNeedsReloadAfterIndexedMutation)
            #expect(app.library.completeLibraryFolderSummaries.isEmpty)
            #expect(app.isWorkbenchRouteUnknown(.libraryFolder(folderPath: "/Media/Show")))
        }
    }
}

@MainActor
private func withWorkbenchInvalidationTestApp(
    _ body: @MainActor (AppCoordinator) async throws -> Void
) async throws {
    let suiteName = "WorkbenchInvalidationTestApp-\(UUID().uuidString)"
    let userDefaults = try #require(UserDefaults.temporary(suiteName: suiteName))
    let databaseURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("WorkbenchInvalidationTestApp-\(UUID().uuidString)")
        .appendingPathExtension("sqlite")
    defer {
        userDefaults.removePersistentDomainAndPlist(forName: suiteName)
        removeTemporaryDatabase(at: databaseURL)
        try? FileManager.default.removeItem(atPath: databaseURL.path + "-wal")
        try? FileManager.default.removeItem(atPath: databaseURL.path + "-shm")
    }

    _ = NSApplication.shared
    let app = AppCoordinator(userDefaults: userDefaults, databaseURL: databaseURL)
    await app.startupDatabaseTask?.value
    try await body(app)
}
