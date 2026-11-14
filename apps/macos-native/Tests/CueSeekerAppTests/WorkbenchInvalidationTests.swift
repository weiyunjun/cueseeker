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
    func initialLibraryHydrationProceedsWhileInLibraryPanelMode() async throws {
        try await withWorkbenchInvalidationTestApp { app in
            app.indexing.selectedFolders = [URL(fileURLWithPath: "/Media/Show")]
            app.activateWorkbenchPanelMode(.testLibrary)

            #expect(app.library.completeLibraryStatus == .idle)
            #expect(!app.libraryNeedsReloadAfterIndexedMutation)

            app.hydrateCompleteLibraryAsync()

            #expect(!app.libraryNeedsReloadAfterIndexedMutation)
            #expect(app.library.completeLibraryStatus == .loading || app.library.completeLibraryStatus == .completed)
            await app.completeLibraryTask?.value
            #expect(app.library.completeLibraryStatus == .completed)
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

    @MainActor
    @Test
    func workbenchSurfaceTransitionWaitsForStoreHydrationBeforeMarkingSurfaceReady() async throws {
        try await withWorkbenchInvalidationTestApp { app in
            app.indexing.selectedFolders = [URL(fileURLWithPath: "/Media/Show")]

            #expect(!app.isWorkbenchSurfaceReadyForPresentation(.recent(.videos)))
            #expect(!app.isWorkbenchSurfaceReadyForPresentation(.libraryRoot))
            #expect(!app.isWorkbenchSurfaceReadyForPresentation(.excerptOverview))

            await app.prepareWorkbenchSurfaceForPresentation(.recent(.videos))
            #expect(app.isWorkbenchSurfaceReadyForPresentation(.recent(.videos)))

            await app.prepareWorkbenchSurfaceForPresentation(.libraryRoot)
            #expect(app.isWorkbenchSurfaceReadyForPresentation(.libraryRoot))

            await app.prepareWorkbenchSurfaceForPresentation(.excerptOverview)
            #expect(app.isWorkbenchSurfaceReadyForPresentation(.excerptOverview))
        }
    }

    @Test("Playback overlay library playlist and command panel recent pages wait for readiness before presentation")
    @MainActor
    func playbackOverlayAndCommandPanelWaitForReadinessBeforePresentation() async throws {
        try await withWorkbenchInvalidationTestApp { app in
            let folderURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("PlaybackTransitionReady-\(UUID().uuidString)")
            app.indexing.selectedFolders = [folderURL]

            #expect(app.isPlaybackCommandPanelPageReadyForPresentation(.root))
            #expect(app.isPlaybackCommandPanelPageReadyForPresentation(.searchResults))
            #expect(!app.isPlaybackCommandPanelPageReadyForPresentation(.recentVideos))
            #expect(!app.isPlaybackCommandPanelPageReadyForPresentation(.recentExcerpts))

            await app.preparePlaybackCommandPanelPageForPresentation(.recentVideos)
            #expect(app.isPlaybackCommandPanelPageReadyForPresentation(.recentVideos))

            await app.preparePlaybackCommandPanelPageForPresentation(.recentExcerpts)
            #expect(app.isPlaybackCommandPanelPageReadyForPresentation(.recentExcerpts))

            let librarySession = app.makePlaybackLibrarySessionStore(
                folderPath: folderURL.path,
                initialVideoPath: folderURL.appendingPathComponent("Episode1.mkv").path
            )
            #expect(!librarySession.isReadyForPresentation)
            await librarySession.prepareForPresentation()
            #expect(librarySession.isReadyForPresentation)
        }
    }

    @MainActor
    @Test
    func backgroundAuxiliaryVideoMetadataMutationInvalidatesAndRefreshesFileTreeCache() async throws {
        try await withWorkbenchInvalidationTestApp { app in
            let rootURL = URL(fileURLWithPath: "/Media")
            let folderPath = "/Media/Show"
            let videoPath = "/Media/Show/EP01.mkv"
            let subtitlePath = "/Media/Show/EP01.ass"
            let databaseURL = app.databaseURL

            try SQLiteDatabase(path: databaseURL).execute(
                """
                INSERT INTO search_paths(id, type, path, created_at, updated_at)
                VALUES (1, 'local', '/Media', '2026-11-14T00:00:00Z', '2026-11-14T00:00:00Z');

                INSERT INTO library_root_folders(path, created_at, updated_at)
                VALUES ('/Media', '2026-11-14T00:00:00Z', '2026-11-14T00:00:00Z');

                INSERT INTO library_folders(id, library_id, relative_path)
                VALUES (10, 1, 'Show');

                INSERT INTO video_files(
                    id, library_id, folder_id, relative_path, path, video_name, file_size
                ) VALUES (
                    100, 1, 10, 'Show/EP01.mkv', '\(videoPath)', 'EP01.mkv', 831650000
                );

                INSERT INTO subtitle_files(
                    id, library_id, folder_id, relative_path, subtitle_path,
                    format, file_size, raw_cue_count, indexed_at
                ) VALUES (
                    200, 1, 10, 'Show/EP01.ass', '\(subtitlePath)',
                    'ass', 128400, 12, '2026-11-14T00:00:00Z'
                );

                INSERT INTO subtitle_video_matches(
                    subtitle_file_id, video_file_id, match_method, confidence, is_active
                ) VALUES (200, 100, 'same-directory-basename', 1.0, 1);

                INSERT INTO library_video_rows(
                    video_path, video_file_id, subtitle_file_id, video_name, duration,
                    subtitle_path, subtitle_format, folder_path, folder_title,
                    display_title, file_extension, folder_order, video_order, updated_at
                ) VALUES (
                    '\(videoPath)', 100, 200, 'EP01.mkv', NULL,
                    '\(subtitlePath)', 'ass', '\(folderPath)', 'Show',
                    'Show - 01', 'mkv', 0, 0, '2026-11-14T00:00:00Z'
                );
                """
            )
            app.indexing.selectedFolders = [rootURL]

            // Populate File page cache before video metadata enrichment runs
            app.loadFileObjects(folderPath: folderPath)
            let initialObjects = app.library.fileObjects(for: folderPath)
            #expect(initialObjects.count == 1)
            #expect(initialObjects[0].videoWidth == nil)
            #expect(initialObjects[0].videoCodec == nil)
            #expect(initialObjects[0].duration == nil)
            #expect(FileCardSubtitleFormatter.videoSubtitle(for: initialObjects[0]) == "831.65 MB")

            // Backfill video metadata in SQLite as background indexing does
            let libraryDB = try LibraryDatabase(path: databaseURL)
            try libraryDB.updateVideoMetadata(
                videoFile: URL(fileURLWithPath: videoPath),
                duration: 1422.0,
                videoWidth: 1920,
                videoHeight: 1080,
                frameRate: 23.976,
                videoCodec: "hevc",
                videoBitDepth: 10,
                videoPixelFormat: "yuv420p10le",
                containerFormat: "matroska",
                audioTracks: []
            )

            // Non-File route: finishing auxiliary-only index run must immediately invalidate cache
            let revisionBefore = app.library.fileTreeRevision
            app.navigateWorkbench(to: .library)
            app.finishIndexRun(
                SubtitleIndexingResult(),
                folders: [rootURL],
                auxiliaryFailures: [],
                refreshedAuxiliaryData: true,
                status: .completed(rootURL, SubtitleIndexingResult())
            )
            #expect(app.library.fileObjectsByFolderPath[folderPath] == nil)
            #expect(app.library.fileTreeRevision == revisionBefore + 1)

            // Reloading File objects reflects the enriched video metadata
            app.loadFileObjects(folderPath: folderPath)
            let refreshedObjects = app.library.fileObjects(for: folderPath)
            #expect(refreshedObjects.count == 1)
            #expect(
                FileCardSubtitleFormatter.videoSubtitle(for: refreshedObjects[0])
                    == "1080P  HEVC  23:42  831.65 MB"
            )

            // Active Level 3 File route defers until reappearance and then reloads fresh metadata
            try libraryDB.updateVideoMetadata(
                videoFile: URL(fileURLWithPath: videoPath),
                duration: 3930.0,
                videoWidth: 3840,
                videoHeight: 2160,
                frameRate: 24.0,
                videoCodec: "av1",
                videoBitDepth: 10,
                videoPixelFormat: "yuv420p10le",
                containerFormat: "matroska",
                audioTracks: []
            )
            app.navigateWorkbench(to: .fileFiles(rootPath: rootURL.mediaPath, folderPath: folderPath))
            app.finishIndexRun(
                SubtitleIndexingResult(),
                folders: [rootURL],
                auxiliaryFailures: [],
                refreshedAuxiliaryData: true,
                status: .completed(rootURL, SubtitleIndexingResult())
            )
            #expect(app.fileNeedsReloadAfterIndexedMutation)

            app.navigateWorkbench(to: .fileFolder(rootPath: rootURL.mediaPath))
            #expect(!app.fileNeedsReloadAfterIndexedMutation)
            #expect(app.library.fileObjectsByFolderPath[folderPath] == nil)

            app.hydrateFileObjectsAsync(folderPath: folderPath)
            await app.library.fileObjectTasks[URL.fromMediaPath(folderPath).mediaPath]?.value
            #expect(
                FileCardSubtitleFormatter.videoSubtitle(for: app.library.fileObjects(for: folderPath)[0])
                    == "4K  AV1  01:05:30  831.65 MB"
            )
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
