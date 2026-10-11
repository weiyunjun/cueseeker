import Foundation
import Combine
import Testing
@testable import CueSeekerCore
@testable import CueSeekerApp

@MainActor
@Test
func workbenchLayoutStateDefaultsToSearchWithExpandedSidebar() {
    withTemporaryWorkbenchLayoutUserDefaults { userDefaults in
        let layoutState = WorkbenchLayoutState(userDefaults: userDefaults)

        #expect(layoutState.panelMode == .search)
        #expect(layoutState.isSidebarVisible)
    }
}

@MainActor
@Test
func workbenchLayoutStateMigratesLegacyLibraryPanelToSearch() {
    withTemporaryWorkbenchLayoutUserDefaults { userDefaults in
        userDefaults.set("library", forKey: "workbenchPanelMode")

        let layoutState = WorkbenchLayoutState(userDefaults: userDefaults)

        #expect(layoutState.panelMode == .search)
    }
}

@MainActor
@Test
func workbenchLayoutStatePersistsSelectedPanelMode() {
    withTemporaryWorkbenchLayoutUserDefaults { userDefaults in
        let layoutState = WorkbenchLayoutState(userDefaults: userDefaults)

        layoutState.navigate(to: .library)

        let reloadedLayoutState = WorkbenchLayoutState(userDefaults: userDefaults)
        #expect(reloadedLayoutState.panelMode == .testLibrary)
    }
}

@MainActor
@Test
func workbenchLayoutStateDoesNotInvalidateAnAlreadySelectedLibraryPanel() {
    withTemporaryWorkbenchLayoutUserDefaults { userDefaults in
        let layoutState = WorkbenchLayoutState(userDefaults: userDefaults)
        layoutState.navigate(to: .library)
        var routeInvalidations = 0
        let cancellable = layoutState.route.objectWillChange.sink {
            routeInvalidations += 1
        }

        layoutState.navigate(to: .library)

        #expect(routeInvalidations == 0)
        #expect(layoutState.panelMode == .testLibrary)
        withExtendedLifetime(cancellable) {}
    }
}

@MainActor
@Test
func workbenchLayoutStatePersistsSidebarVisibility() {
    withTemporaryWorkbenchLayoutUserDefaults { userDefaults in
        let layoutState = WorkbenchLayoutState(userDefaults: userDefaults)

        layoutState.toggleSidebarVisibility()

        let reloadedLayoutState = WorkbenchLayoutState(userDefaults: userDefaults)
        #expect(!reloadedLayoutState.isSidebarVisible)
    }
}

@MainActor
@Test
func sidebarVisibilityDoesNotInvalidateRouteState() {
    withTemporaryWorkbenchLayoutUserDefaults { userDefaults in
        let layoutState = WorkbenchLayoutState(userDefaults: userDefaults)
        var routeInvalidations = 0
        var layoutInvalidations = 0

        let routeCancellable = layoutState.route.objectWillChange.sink {
            routeInvalidations += 1
        }
        let layoutCancellable = layoutState.objectWillChange.sink {
            layoutInvalidations += 1
        }

        layoutState.toggleSidebarVisibility()

        #expect(routeInvalidations == 0)
        #expect(layoutInvalidations == 1)
        #expect(layoutState.panelMode == .search)

        withExtendedLifetime(routeCancellable) {}
        withExtendedLifetime(layoutCancellable) {}
    }
}

@MainActor
@Test
func workbenchLayoutStateCollapsesSidebarForCompactWindowOnce() {
    withTemporaryWorkbenchLayoutUserDefaults { userDefaults in
        let layoutState = WorkbenchLayoutState(userDefaults: userDefaults)

        let collapsed = layoutState.collapseSidebarForCompactWindowIfNeeded(
            width: 760,
            threshold: 760
        )
        let expandedAgain = layoutState.collapseSidebarForCompactWindowIfNeeded(
            width: 900,
            threshold: 760
        )

        let reloadedLayoutState = WorkbenchLayoutState(userDefaults: userDefaults)
        #expect(collapsed)
        #expect(!expandedAgain)
        #expect(!layoutState.isSidebarVisible)
        #expect(!reloadedLayoutState.isSidebarVisible)
    }
}

@MainActor
@Test
func workbenchLayoutStateIgnoresNonPositiveCompactWindowWidth() {
    withTemporaryWorkbenchLayoutUserDefaults { userDefaults in
        let layoutState = WorkbenchLayoutState(userDefaults: userDefaults)

        let collapsed = layoutState.collapseSidebarForCompactWindowIfNeeded(
            width: 0,
            threshold: 760
        )

        #expect(!collapsed)
        #expect(layoutState.isSidebarVisible)
    }
}

@MainActor
@Test
func workbenchLayoutStateTracksExcerptListDetailWithoutPersistingIt() {
    withTemporaryWorkbenchLayoutUserDefaults { userDefaults in
        let layoutState = WorkbenchLayoutState(userDefaults: userDefaults)

        layoutState.navigate(to: .excerptList(id: 42))
        #expect(layoutState.selectedExcerptListID == 42)
        #expect(layoutState.route.selectedExcerptListID == 42)

        layoutState.navigate(to: .excerpt)
        #expect(layoutState.selectedExcerptListID == nil)

        let reloadedLayoutState = WorkbenchLayoutState(userDefaults: userDefaults)
        #expect(reloadedLayoutState.selectedExcerptListID == nil)
    }
}

@MainActor
@Test
func workbenchLayoutStateTracksRecentSectionWithoutPersistingIt() {
    withTemporaryWorkbenchLayoutUserDefaults { userDefaults in
        let layoutState = WorkbenchLayoutState(userDefaults: userDefaults)
        #expect(layoutState.selectedRecentSection == .videos)

        layoutState.selectRecentSection(.excerpts)
        #expect(layoutState.selectedRecentSection == .excerpts)
        #expect(layoutState.route.selectedRecentSection == .excerpts)

        layoutState.navigate(to: .file)
        #expect(layoutState.selectedRecentSection == .excerpts)

        let reloadedLayoutState = WorkbenchLayoutState(userDefaults: userDefaults)
        #expect(reloadedLayoutState.selectedRecentSection == .videos)
    }
}

@MainActor
@Test
func workbenchHistoryStepsThroughPagesAndDropsForwardOnNewNavigation() {
    withTemporaryWorkbenchLayoutUserDefaults { userDefaults in
        let layoutState = WorkbenchLayoutState(userDefaults: userDefaults)
        #expect(layoutState.currentRoute == .search)
        #expect(!layoutState.route.canGoBack)
        #expect(!layoutState.route.canGoForward)

        layoutState.navigate(to: .recent)
        layoutState.navigate(to: .library)
        layoutState.navigate(to: .libraryFolder(folderPath: "/Media/Show"))
        #expect(layoutState.panelMode == .testLibrary)
        #expect(layoutState.selectedLibraryFolderPath == "/Media/Show")
        #expect(layoutState.route.canGoBack)
        #expect(!layoutState.route.canGoForward)

        layoutState.goBack()
        #expect(layoutState.currentRoute == .library)
        #expect(layoutState.selectedLibraryFolderPath == nil)
        #expect(layoutState.route.canGoForward)
        layoutState.goBack()
        #expect(layoutState.currentRoute == .recent)
        layoutState.goBack()
        #expect(layoutState.currentRoute == .search)
        #expect(!layoutState.route.canGoBack)
        layoutState.goBack()
        #expect(layoutState.currentRoute == .search)

        layoutState.goForward()
        layoutState.goForward()
        layoutState.goForward()
        #expect(layoutState.currentRoute == .libraryFolder(folderPath: "/Media/Show"))
        #expect(!layoutState.route.canGoForward)
        layoutState.goForward()
        #expect(layoutState.currentRoute == .libraryFolder(folderPath: "/Media/Show"))

        layoutState.goBack()
        layoutState.navigate(to: .excerpt)
        #expect(layoutState.currentRoute == .excerpt)
        #expect(!layoutState.route.canGoForward)
        #expect(layoutState.route.history == [.search, .recent, .library, .excerpt])

        layoutState.navigate(to: .excerpt)
        #expect(layoutState.route.history.count == 4)

        layoutState.navigate(to: .excerptList(id: 42))
        #expect(layoutState.selectedExcerptListID == 42)
        layoutState.goBack()
        #expect(layoutState.selectedExcerptListID == nil)
        #expect(layoutState.panelMode == .excerpt)
    }
}

@MainActor
private func withTemporaryWorkbenchLayoutUserDefaults(_ body: (UserDefaults) -> Void) {
    let suiteName = "CueSeekerWorkbenchLayoutStateTests-\(UUID().uuidString)"
    let userDefaults = UserDefaults.temporary(suiteName: suiteName)!
    defer {
        userDefaults.removePersistentDomainAndPlist(forName: suiteName)
    }

    body(userDefaults)
}

@Test
func workbenchSidebarCollapsesBeforeThePageDropsBelowItsMinimumWidth() {
    #expect(
        AppShellLayout.sidebarAutoCollapseWindowWidth
            == AppShellLayout.pageContentMinimumWidth + AppShellLayout.sidebarWidth
    )
    #expect(AppShellLayout.sidebarAutoCollapseWindowWidth == 720)

    // At the threshold an expanded sidebar leaves exactly the page content
    // minimum, so widening past it never needs page-level horizontal scrolling.
    #expect(
        AppShellLayout.sidebarAutoCollapseWindowWidth - AppShellLayout.sidebarWidth
            == AppShellLayout.pageContentMinimumWidth
    )
}

@Test
func workbenchRecentSectionLabelsAndShortLabelsMatchSpecification() {
    #expect(WorkbenchRecentSection.videos.label == "Recent Videos")
    #expect(WorkbenchRecentSection.excerpts.label == "Recent Excerpt Lists")
    #expect(WorkbenchRecentSection.videos.shortLabel == "Videos")
    #expect(WorkbenchRecentSection.excerpts.shortLabel == "Excerpt Lists")
}
