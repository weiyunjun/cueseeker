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

    private func findAccessibilityView(in root: NSView, identifier: String) -> NSView? {
        if root.accessibilityIdentifier() == identifier {
            return root
        }
        for subview in root.subviews {
            if let match = findAccessibilityView(in: subview, identifier: identifier) {
                return match
            }
        }
        return nil
    }

    @Test
    func fileOnboardingThreeStepFlowRetainsStepAcrossPagesAndPersistsCompletionAcrossRelaunch() throws {
        let env = try makeTestEnvironment()
        defer {
            env.userDefaults.removePersistentDomainAndPlist(forName: env.suiteName)
            try? FileManager.default.removeItem(at: env.rootDir)
        }

        _ = NSApplication.shared
        let app = AppCoordinator(userDefaults: env.userDefaults, databaseURL: env.databaseURL)
        #expect(!app.settings.hasCompletedFileOnboarding)
        #expect(app.indexing.selectedFolders.isEmpty)

        // Navigating to File with 0 folders and never clicked Done opens Step 1 (Next only).
        app.activateWorkbenchPanelMode(.file)
        #expect(app.workbenchLayout.currentRoute == .file)
        #expect(app.isFileOnboardingPresented)
        #expect(app.fileOnboardingStep == 1)
        let step1Targets = app.currentWorkbenchAccessibilityTargets()
        #expect(!step1Targets.contains(.fileOnboardingBackButton))
        #expect(step1Targets.contains(.fileOnboardingPrimaryButton))
        #expect(!step1Targets.contains(.fileAddFolderButton))

        // Step 1 -> Step 2 exposes Back + Next.
        #expect(app.activateWorkbenchAccessibilityTarget(.fileOnboardingPrimaryButton))
        #expect(app.fileOnboardingStep == 2)
        let step2Targets = app.currentWorkbenchAccessibilityTargets()
        #expect(step2Targets.contains(.fileOnboardingBackButton))
        #expect(step2Targets.contains(.fileOnboardingPrimaryButton))

        // Switching to Search and jumping back via Go to File retains Step 2.
        app.activateWorkbenchPanelMode(.search)
        #expect(app.workbenchLayout.currentRoute == .search)
        app.goToFileFromNoFolderOnboarding()
        #expect(app.workbenchLayout.currentRoute == .file)
        #expect(app.isFileOnboardingPresented)
        #expect(app.fileOnboardingStep == 2)

        // Back -> Step 1, Next -> Step 2, Next -> Step 3, Done -> New File Empty State.
        #expect(app.activateWorkbenchAccessibilityTarget(.fileOnboardingBackButton))
        #expect(app.fileOnboardingStep == 1)
        app.advanceFileOnboardingStep()
        app.advanceFileOnboardingStep()
        #expect(app.fileOnboardingStep == 3)
        app.advanceFileOnboardingStep()

        #expect(app.settings.hasCompletedFileOnboarding)
        #expect(!app.isFileOnboardingPresented)
        let emptyTargets = app.currentWorkbenchAccessibilityTargets()
        #expect(emptyTargets.contains(.fileViewTutorialButton))
        #expect(emptyTargets.contains(.fileAddFolderButton))
        #expect(!emptyTargets.contains(.fileIndexNowButton))
        #expect(!emptyTargets.contains(.fileStatusIndicatorText))

        // Relaunching with the same UserDefaults and 0 folders goes straight to New File Empty State.
        let relaunched = AppCoordinator(userDefaults: env.userDefaults, databaseURL: env.databaseURL)
        relaunched.activateWorkbenchPanelMode(.file)
        #expect(relaunched.settings.hasCompletedFileOnboarding)
        #expect(!relaunched.isFileOnboardingPresented)
        #expect(relaunched.currentWorkbenchAccessibilityTargets().contains(.fileViewTutorialButton))

        // Clicking View Tutorial opens Step 1.
        #expect(relaunched.activateWorkbenchAccessibilityTarget(.fileViewTutorialButton))
        #expect(relaunched.isFileOnboardingPresented)
        #expect(relaunched.fileOnboardingStep == 1)
    }

    @Test
    func fileZeroFolderEmptyStateKeepsMainBodyZeroJumpAcrossStatusChangesAndTutorialDoesNotAutoRefreshMidRead() throws {
        let env = try makeTestEnvironment()
        defer {
            env.userDefaults.removePersistentDomainAndPlist(forName: env.suiteName)
            try? FileManager.default.removeItem(at: env.rootDir)
        }

        _ = NSApplication.shared
        WorkbenchFileView.lastZeroFolderMainBodyFrameForTesting = nil
        let app = AppCoordinator(userDefaults: env.userDefaults, databaseURL: env.databaseURL)
        app.completeFileOnboarding()
        app.activateWorkbenchPanelMode(.file)

        let fileView = WorkbenchFileView(tasks: app.tasks)
            .environmentObject(app)
            .environmentObject(app.indexing)
            .environmentObject(app.workbenchLayout.route)
            .environmentObject(app.library)
            .environmentObject(app.settings.localization)
            .environment(\.workbenchAccessibility, app.workbenchAccessibility)

        let host = NSHostingView(rootView: fileView)
        host.frame = NSRect(x: 0, y: 0, width: 880, height: 640)
        let window = NSWindow(
            contentRect: host.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.03))
        host.layoutSubtreeIfNeeded()

        let idleFrame = try #require(WorkbenchFileView.lastZeroFolderMainBodyFrameForTesting)
        #expect(idleFrame.width > 0 && idleFrame.height > 0)
        #expect(!app.showsFileZeroFolderStatusIndicator)

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

        // Mid-tutorial non-auto-refresh: open tutorial while indexing, complete folder addition mid-read,
        // verify page stays on Step 2 until Step 3 Done is clicked, then shows root folder cards.
        app.indexing.clearTransientNotice()
        app.indexing.indexingStatus = .indexing(sampleFolder)
        app.openFileOnboarding()
        app.advanceFileOnboardingStep()
        #expect(app.isFileOnboardingPresented)
        #expect(app.fileOnboardingStep == 2)

        app.indexing.appendFolder(sampleFolder)
        app.indexing.indexingStatus = .idle
        #expect(app.isFileOnboardingPresented)
        #expect(app.fileOnboardingStep == 2)
        #expect(!app.currentWorkbenchAccessibilityTargets().contains(.fileCard(sampleFolder.mediaPath)))

        app.advanceFileOnboardingStep()
        #expect(app.fileOnboardingStep == 3)
        app.advanceFileOnboardingStep()
        #expect(!app.isFileOnboardingPresented)
        #expect(app.currentWorkbenchAccessibilityTargets().contains(.fileCard(sampleFolder.mediaPath)))
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

        // Activating Go to File from Command Panel exits Playback and enters File with back history.
        #expect(app.activatePlaybackAccessibilityTarget(.commandPanelGoToFileButton))
        #expect(app.playback.commandPanelPresentation == nil)
        #expect(!app.isPlaybackPageVisible)
        #expect(app.workbenchLayout.currentRoute == .file)
        #expect(app.workbenchLayout.route.canGoBack)
        #expect(app.isFileOnboardingPresented)
        #expect(app.fileOnboardingStep == 1)
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

        // Mandatory File onboarding was disarmed after removing the last folder -> File shows New Empty State!
        app.activateWorkbenchPanelMode(.file)
        #expect(!app.isFileOnboardingPresented)
        #expect(app.currentWorkbenchAccessibilityTargets().contains(.fileViewTutorialButton))

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
