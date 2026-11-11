import AppKit
@testable import CueSeekerCore
import SwiftUI
import Testing
@testable import CueSeekerApp

@Suite(.serialized)
@MainActor
struct NoFolderOnboardingAndFileEmptyStateTests {
    private func makeTestEnvironment(
        name: String = UUID().uuidString
    ) throws -> (suiteName: String, userDefaults: UserDefaults, rootDir: URL, databaseURL: URL) {
        let suiteName = "NoFolderOnboardingTests-\(name)"
        let userDefaults = try #require(UserDefaults.temporary(suiteName: suiteName))
        let rootDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("NoFolderOnboardingTests-\(name)", isDirectory: true)
        try FileManager.default.createDirectory(at: rootDir, withIntermediateDirectories: true)
        let databaseURL = rootDir.appendingPathComponent("CueSeeker.sqlite")
        return (suiteName, userDefaults, rootDir, databaseURL)
    }

    @Test
    func firstLaunchOpensFilePagePersistsItAndSubsequentLaunchesRestoreLastPrimaryPageUnlessDatabaseIsRecreated() throws {
        let env = try makeTestEnvironment()
        defer {
            env.userDefaults.removePersistentDomainAndPlist(forName: env.suiteName)
            try? FileManager.default.removeItem(at: env.rootDir)
        }

        // Verify DatabaseBootstrap reports fresh schema creation vs existing database accurately.
        let bootstrapProbeURL = env.rootDir.appendingPathComponent("BootstrapProbe.sqlite")
        #expect(try DatabaseBootstrap.prepare(at: bootstrapProbeURL).didCreateSchema)
        #expect(try !DatabaseBootstrap.prepare(at: bootstrapProbeURL).didCreateSchema)

        _ = NSApplication.shared

        // 1. Brand-new launch (no saved primary page record + newly created SQLite database)
        // opens directly on File Level 1 and persists "file".
        #expect(env.userDefaults.string(forKey: "workbenchPanelMode") == nil)
        let firstApp = AppCoordinator(userDefaults: env.userDefaults, databaseURL: env.databaseURL)
        #expect(firstApp.indexing.selectedFolders.isEmpty)
        #expect(firstApp.workbenchLayout.panelMode == .file)
        #expect(firstApp.workbenchLayout.currentRoute == .file)
        #expect(firstApp.workbenchLayout.route.history == [.file])
        #expect(!firstApp.workbenchLayout.route.canGoBack)
        #expect(!firstApp.workbenchLayout.route.canGoForward)
        #expect(env.userDefaults.string(forKey: "workbenchPanelMode") == WorkbenchPanelMode.file.rawValue)

        let emptyTargets = firstApp.currentWorkbenchAccessibilityTargets()
        #expect(emptyTargets.contains(.fileAddFolderButton))
        #expect(!emptyTargets.contains(.fileIndexNowButton))
        #expect(!emptyTargets.contains(.fileStatusIndicatorText))

        // 2. Subsequent launch without switching pages keeps opening on File.
        let secondApp = AppCoordinator(userDefaults: env.userDefaults, databaseURL: env.databaseURL)
        #expect(secondApp.workbenchLayout.panelMode == .file)
        #expect(secondApp.workbenchLayout.currentRoute == .file)

        // 3. Switching to Search or Excerpt and relaunching restores the last visited primary page.
        secondApp.activateWorkbenchPanelMode(.search)
        #expect(secondApp.workbenchLayout.currentRoute == .search)
        #expect(env.userDefaults.string(forKey: "workbenchPanelMode") == WorkbenchPanelMode.search.rawValue)

        let thirdApp = AppCoordinator(userDefaults: env.userDefaults, databaseURL: env.databaseURL)
        #expect(thirdApp.workbenchLayout.panelMode == .search)
        #expect(thirdApp.workbenchLayout.currentRoute == .search)

        thirdApp.activateWorkbenchPanelMode(.excerpt)
        let fourthApp = AppCoordinator(userDefaults: env.userDefaults, databaseURL: env.databaseURL)
        #expect(fourthApp.workbenchLayout.panelMode == .excerpt)
        #expect(fourthApp.workbenchLayout.currentRoute == .excerpt)

        // 4. Deleting the local SQLite database while UserDefaults still holds "search"
        // triggers fresh schema initialization on launch and resets initial page & persistence to File.
        fourthApp.activateWorkbenchPanelMode(.search)
        #expect(env.userDefaults.string(forKey: "workbenchPanelMode") == WorkbenchPanelMode.search.rawValue)
        let reinitializedDBURL = env.rootDir.appendingPathComponent("ReinitializedCueSeeker.sqlite")
        let fifthApp = AppCoordinator(userDefaults: env.userDefaults, databaseURL: reinitializedDBURL)
        #expect(fifthApp.workbenchLayout.panelMode == .file)
        #expect(fifthApp.workbenchLayout.currentRoute == .file)
        #expect(fifthApp.workbenchLayout.route.history == [.file])
        #expect(!fifthApp.workbenchLayout.route.canGoBack)
        #expect(env.userDefaults.string(forKey: "workbenchPanelMode") == WorkbenchPanelMode.file.rawValue)
    }

    @Test
    func fileZeroFolderEmptyStateKeepsMainBodyZeroJumpAcrossStatusChangesAndTransitionsImmediatelyOnFirstFolder() throws {
        let env = try makeTestEnvironment()
        defer {
            env.userDefaults.removePersistentDomainAndPlist(forName: env.suiteName)
            try? FileManager.default.removeItem(at: env.rootDir)
        }

        _ = NSApplication.shared
        WorkbenchFileView.lastZeroFolderMainBodyFrameForTesting = nil
        let app = AppCoordinator(userDefaults: env.userDefaults, databaseURL: env.databaseURL)
        #expect(app.workbenchLayout.currentRoute == .file)

        let fileView = WorkbenchFileView(tasks: app.tasks)
            .environmentObject(app)
            .environmentObject(app.indexing)
            .environmentObject(app.workbenchLayout.route)
            .environmentObject(app.library)
            .environmentObject(app.settings.localization)
            .environment(\.workbenchAccessibility, app.workbenchAccessibility)

        let host = NSHostingView(rootView: fileView)
        host.frame = NSRect(x: 0, y: 0, width: 880, height: 640)
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.03))
        host.layoutSubtreeIfNeeded()

        let idleFrame = try #require(WorkbenchFileView.lastZeroFolderMainBodyFrameForTesting)
        #expect(idleFrame.width > 0 && idleFrame.height > 0)
        #expect(!app.showsFileZeroFolderStatusIndicator)
        #expect(app.currentWorkbenchAccessibilityTargets().contains(.fileAddFolderButton))

        // Transition 1: Indexing in progress -> separate-line status appears, main body moves 0.0pt.
        let sampleFolder = env.rootDir.appendingPathComponent("Anime", isDirectory: true)
        app.indexing.indexingStatus = .indexing(sampleFolder)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.03))
        host.layoutSubtreeIfNeeded()

        #expect(app.showsFileZeroFolderStatusIndicator)
        #expect(app.currentWorkbenchAccessibilityTargets().contains(.fileStatusIndicatorText))
        let indexingFrame = try #require(WorkbenchFileView.lastZeroFolderMainBodyFrameForTesting)
        #expect(abs(indexingFrame.origin.x - idleFrame.origin.x) < 0.01)
        #expect(abs(indexingFrame.origin.y - idleFrame.origin.y) < 0.01)
        #expect(abs(indexingFrame.size.width - idleFrame.size.width) < 0.01)
        #expect(abs(indexingFrame.size.height - idleFrame.size.height) < 0.01)

        // Transition 2: Index failed -> status stays visible, main body moves 0.0pt.
        app.indexing.indexingStatus = .failed(sampleFolder, "Read failed")
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.03))
        host.layoutSubtreeIfNeeded()

        #expect(app.showsFileZeroFolderStatusIndicator)
        let failedFrame = try #require(WorkbenchFileView.lastZeroFolderMainBodyFrameForTesting)
        #expect(abs(failedFrame.origin.x - idleFrame.origin.x) < 0.01)
        #expect(abs(failedFrame.origin.y - idleFrame.origin.y) < 0.01)

        // Transition 3: First folder finishes indexing -> immediately switches to root folder list.
        app.indexing.clearTransientNotice()
        app.indexing.appendFolder(sampleFolder)
        app.indexing.indexingStatus = .idle
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.03))
        host.layoutSubtreeIfNeeded()

        let populatedTargets = app.currentWorkbenchAccessibilityTargets()
        #expect(populatedTargets.contains(.fileAddFolderButton))
        #expect(populatedTargets.contains(.fileIndexNowButton))
        #expect(populatedTargets.contains(.fileCard(sampleFolder.mediaPath)))
    }

    @Test
    func otherSurfacesAndCommandPanelShowNoFolderOnboardingAndRespectExistingExcerptLists() async throws {
        let env = try makeTestEnvironment()
        defer {
            env.userDefaults.removePersistentDomainAndPlist(forName: env.suiteName)
            try? FileManager.default.removeItem(at: env.rootDir)
        }

        _ = NSApplication.shared
        let app = AppCoordinator(userDefaults: env.userDefaults, databaseURL: env.databaseURL)
        app.reloadExcerptListOverview()
        await app.excerpt.listOverviewTask?.value

        // 1. Search (0 folders) -> hides toolbar, exposes .noFolderGoToFileButton
        app.activateWorkbenchPanelMode(.search)
        #expect(app.showsNoFolderSearchOnboarding)
        let searchTargets = app.currentWorkbenchAccessibilityTargets()
        #expect(!searchTargets.contains(.toolbarSearchField))
        #expect(searchTargets.contains(.noFolderGoToFileButton))

        // 2. Library (0 folders) -> hides toolbar, exposes .noFolderGoToFileButton
        app.activateWorkbenchPanelMode(.testLibrary)
        #expect(app.showsNoFolderLibraryOnboarding)
        let libraryTargets = app.currentWorkbenchAccessibilityTargets()
        #expect(!libraryTargets.contains(.toolbarSearchField))
        #expect(libraryTargets.contains(.noFolderGoToFileButton))

        // 3. Excerpt (0 folders + 0 lists) -> exposes .noFolderGoToFileButton (not .excerptNewListButton)
        app.excerpt.overviewSearchDraft = "stale"
        app.activateWorkbenchPanelMode(.excerpt)
        #expect(app.showsNoFolderExcerptOnboarding)
        let excerptZeroTargets = app.currentWorkbenchAccessibilityTargets()
        #expect(!excerptZeroTargets.contains(.toolbarSearchField))
        #expect(!excerptZeroTargets.contains(.excerptNewListButton))
        #expect(excerptZeroTargets.contains(.noFolderGoToFileButton))

        // 4. Recent (0 folders + 0 videos + 0 lists) -> keeps topbar segments + exposes .noFolderGoToFileButton
        app.activateWorkbenchPanelMode(.recentWatching)
        app.workbenchLayout.selectRecentSection(.videos)
        #expect(app.showsNoFolderRecentVideosOnboarding)
        let recentVideoTargets = app.currentWorkbenchAccessibilityTargets()
        #expect(recentVideoTargets.contains(.topbarRecentSegment(.videos)))
        #expect(recentVideoTargets.contains(.topbarRecentSegment(.excerpts)))
        #expect(recentVideoTargets.contains(.noFolderGoToFileButton))

        app.workbenchLayout.selectRecentSection(.excerpts)
        #expect(app.showsNoFolderRecentExcerptsOnboarding)
        #expect(app.currentWorkbenchAccessibilityTargets().contains(.noFolderGoToFileButton))

        // 5. Creating an Excerpt List while 0 folders -> Excerpt & Recent Excerpt Lists show list cards!
        let excerptDB = try #require(app.excerptDatabase)
        let createdList = try excerptDB.createExcerptList(name: "Vocab")
        app.reloadExcerptListOverview()
        await app.excerpt.listOverviewTask?.value

        app.activateWorkbenchPanelMode(.excerpt)
        #expect(!app.showsNoFolderExcerptOnboarding)
        let excerptWithListTargets = app.currentWorkbenchAccessibilityTargets()
        #expect(excerptWithListTargets.contains(.toolbarSearchField))
        #expect(excerptWithListTargets.contains(.mediaCard(String(createdList.id))))
        #expect(!excerptWithListTargets.contains(.noFolderGoToFileButton))

        app.activateWorkbenchPanelMode(.recentWatching)
        app.workbenchLayout.selectRecentSection(.excerpts)
        #expect(!app.showsNoFolderRecentExcerptsOnboarding)
        #expect(app.currentWorkbenchAccessibilityTargets().contains(.mediaCard(String(createdList.id))))
        #expect(!app.currentWorkbenchAccessibilityTargets().contains(.noFolderGoToFileButton))

        // Delete the list again to test Command Panel -> Recent Videos & Recent Excerpts at 0 lists + 0 folders
        #expect(app.deleteExcerptList(id: createdList.id))
        await app.excerpt.listOverviewTask?.value

        app.activateWorkbenchPanelMode(.search)
        app.search.selectResult(SubtitleSearchResult(
            entryID: 1,
            subtitlePath: "/Media/Sample.srt",
            subtitleFormat: .srt,
            videoPath: "/Media/Sample.mkv",
            videoName: "Sample.mkv",
            startMilliseconds: 1_000,
            endMilliseconds: 2_000,
            content: "sample cue",
            cueLines: ["sample cue"]
        ))
        app.playback.isPlaybackSurfaceExpanded = true
        #expect(app.presentPlaybackCommandPanel())
        #expect(app.presentPlaybackCommandPanelPage(.recentExcerpts))
        #expect(app.showsPlaybackCommandPanelNoFolderRecentExcerptsOnboarding)
        #expect(app.currentPlaybackAccessibilityTargets() == [
            .commandPanelBackButton,
            .commandPanelGoToFileButton,
            .commandPanelFooterAction("open"),
        ])

        #expect(app.returnPlaybackCommandPanelToRoot())
        #expect(app.presentPlaybackCommandPanelPage(.recentVideos))
        #expect(app.showsPlaybackCommandPanelNoFolderRecentVideosOnboarding)
        #expect(app.currentPlaybackAccessibilityTargets() == [
            .commandPanelBackButton,
            .commandPanelGoToFileButton,
            .commandPanelFooterAction("open"),
        ])

        // Activating Go to File from Command Panel exits Playback and enters File empty state with back history.
        #expect(app.activatePlaybackAccessibilityTarget(.commandPanelGoToFileButton))
        #expect(app.playback.commandPanelPresentation == nil)
        #expect(!app.isPlaybackPageVisible)
        #expect(app.workbenchLayout.currentRoute == .file)
        #expect(app.workbenchLayout.route.canGoBack)
        #expect(app.currentWorkbenchAccessibilityTargets().contains(.fileAddFolderButton))
        #expect(!app.currentWorkbenchAccessibilityTargets().contains(.fileIndexNowButton))
    }

    @Test
    func removingLastFolderFreezesCurrentSurfaceUntilRefreshTabSwitchOrPageSwitch() async throws {
        let env = try makeTestEnvironment()
        defer {
            env.userDefaults.removePersistentDomainAndPlist(forName: env.suiteName)
            try? FileManager.default.removeItem(at: env.rootDir)
        }

        let mediaFolder = env.rootDir.appendingPathComponent("Season1", isDirectory: true)
        try FileManager.default.createDirectory(at: mediaFolder, withIntermediateDirectories: true)
        let srtURL = mediaFolder.appendingPathComponent("ep01.srt")
        try """
        1
        00:00:01,000 --> 00:00:03,000
        Hello CueSeeker onboarding test
        """.write(to: srtURL, atomically: true, encoding: .utf8)

        _ = NSApplication.shared
        let app = AppCoordinator(userDefaults: env.userDefaults, databaseURL: env.databaseURL)
        app.reloadExcerptListOverview()
        await app.excerpt.listOverviewTask?.value

        // Add first folder while on Search -> Search immediately exits no-folder onboarding.
        app.activateWorkbenchPanelMode(.search)
        #expect(app.showsNoFolderSearchOnboarding)
        app.addFolder(mediaFolder)
        while app.tasks.hasLibraryTask {
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        #expect(app.indexing.selectedFolders.count == 1)
        #expect(!app.showsNoFolderSearchOnboarding)

        // Remove the last folder while staying on Search -> Search stays frozen until refresh action!
        app.removeFolder(mediaFolder)
        while app.tasks.hasLibraryTask {
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        #expect(app.indexing.selectedFolders.isEmpty)
        #expect(app.workbenchLayout.route.heldNoFolderSurface == .search)
        #expect(!app.showsNoFolderSearchOnboarding)

        // Triggering filter/sort/search refresh on frozen Search unfreezes into no-folder onboarding!
        app.updateSearchSortOrder(.mostCharacters)
        #expect(app.workbenchLayout.route.heldNoFolderSurface == nil)
        #expect(app.showsNoFolderSearchOnboarding)
        #expect(app.currentWorkbenchAccessibilityTargets().contains(.noFolderGoToFileButton))

        // Navigating to File shows the simplified File zero-folder empty state!
        app.activateWorkbenchPanelMode(.file)
        #expect(app.currentWorkbenchAccessibilityTargets().contains(.fileAddFolderButton))
        #expect(!app.currentWorkbenchAccessibilityTargets().contains(.fileIndexNowButton))

        // Re-add folder and test Recent freeze -> topbar segment switch unfreezes!
        app.addFolder(mediaFolder)
        while app.tasks.hasLibraryTask {
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        app.activateWorkbenchPanelMode(.recentWatching)
        app.workbenchLayout.selectRecentSection(.videos)
        #expect(!app.showsNoFolderRecentVideosOnboarding)

        app.removeFolder(mediaFolder)
        while app.tasks.hasLibraryTask {
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        #expect(app.workbenchLayout.route.heldNoFolderSurface == .recent(.videos))
        #expect(!app.showsNoFolderRecentVideosOnboarding)

        // Switching Recent segment to Excerpt Lists unfreezes!
        app.workbenchLayout.selectRecentSection(.excerpts)
        #expect(app.workbenchLayout.route.heldNoFolderSurface == nil)
        #expect(app.showsNoFolderRecentExcerptsOnboarding)
        app.workbenchLayout.selectRecentSection(.videos)
        #expect(app.showsNoFolderRecentVideosOnboarding)
    }
}
