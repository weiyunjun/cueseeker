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
        userDefaults.set(WorkbenchPanelMode.library.rawValue, forKey: "workbenchPanelMode")

        let layoutState = WorkbenchLayoutState(userDefaults: userDefaults)

        #expect(layoutState.panelMode == .search)
    }
}

@MainActor
@Test
func workbenchLayoutStatePersistsSelectedPanelMode() {
    withTemporaryWorkbenchLayoutUserDefaults { userDefaults in
        let layoutState = WorkbenchLayoutState(userDefaults: userDefaults)

        layoutState.selectPanelMode(.data)

        let reloadedLayoutState = WorkbenchLayoutState(userDefaults: userDefaults)
        #expect(reloadedLayoutState.panelMode == .data)
    }
}

@MainActor
@Test
func workbenchLayoutStateDoesNotInvalidateAnAlreadySelectedDataPanel() {
    withTemporaryWorkbenchLayoutUserDefaults { userDefaults in
        let layoutState = WorkbenchLayoutState(userDefaults: userDefaults)
        layoutState.selectPanelMode(.data)
        var routeInvalidations = 0
        let cancellable = layoutState.route.objectWillChange.sink {
            routeInvalidations += 1
        }

        layoutState.selectPanelMode(.data)

        #expect(routeInvalidations == 0)
        #expect(layoutState.panelMode == .data)
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
func workbenchLayoutStateTracksShioriListDetailWithoutPersistingIt() {
    withTemporaryWorkbenchLayoutUserDefaults { userDefaults in
        let layoutState = WorkbenchLayoutState(userDefaults: userDefaults)

        layoutState.selectShioriList(id: 42)
        #expect(layoutState.selectedShioriListID == 42)
        #expect(layoutState.route.selectedShioriListID == 42)

        layoutState.clearShioriList()
        #expect(layoutState.selectedShioriListID == nil)

        let reloadedLayoutState = WorkbenchLayoutState(userDefaults: userDefaults)
        #expect(reloadedLayoutState.selectedShioriListID == nil)
    }
}

@MainActor
@Test
func workbenchLayoutStateTracksRecentSectionWithoutPersistingIt() {
    withTemporaryWorkbenchLayoutUserDefaults { userDefaults in
        let layoutState = WorkbenchLayoutState(userDefaults: userDefaults)

        layoutState.selectRecentSection(.videos)
        #expect(layoutState.selectedRecentSection == .videos)
        #expect(layoutState.route.selectedRecentSection == .videos)

        layoutState.selectRecentSection(.shioris)
        #expect(layoutState.selectedRecentSection == .shioris)

        layoutState.clearRecentSection()
        #expect(layoutState.selectedRecentSection == nil)

        let reloadedLayoutState = WorkbenchLayoutState(userDefaults: userDefaults)
        #expect(reloadedLayoutState.selectedRecentSection == nil)
    }
}

@MainActor
@Test
func workbenchRouteEnablesBackOnlyForSecondaryPages() {
    withTemporaryWorkbenchLayoutUserDefaults { userDefaults in
        let layoutState = WorkbenchLayoutState(userDefaults: userDefaults)

        #expect(!layoutState.route.canNavigateBack)

        layoutState.selectPanelMode(.recentWatching)
        #expect(!layoutState.route.canNavigateBack)
        layoutState.selectRecentSection(.videos)
        #expect(layoutState.route.canNavigateBack)
        layoutState.clearRecentSection()
        #expect(!layoutState.route.canNavigateBack)

        layoutState.selectPanelMode(.testLibrary)
        #expect(!layoutState.route.canNavigateBack)
        layoutState.selectTestLibraryFolder(
            CompleteLibraryFolderSummaryPresentation(
                folderPath: "/Media/Show",
                folderTitle: "Show",
                coverPath: nil,
                coverRevision: nil,
                episodeCount: 1
            )
        )
        #expect(layoutState.route.canNavigateBack)
        layoutState.clearTestLibraryFolder()
        #expect(!layoutState.route.canNavigateBack)

        layoutState.selectPanelMode(.shiori)
        #expect(!layoutState.route.canNavigateBack)
        layoutState.selectShioriList(id: 42)
        #expect(layoutState.route.canNavigateBack)
        layoutState.clearShioriList()
        #expect(!layoutState.route.canNavigateBack)

        layoutState.selectPanelMode(.search)
        #expect(!layoutState.route.canNavigateBack)

        layoutState.selectPanelMode(.data)
        #expect(!layoutState.route.canNavigateBack)
    }
}

@MainActor
private func withTemporaryWorkbenchLayoutUserDefaults(_ body: (UserDefaults) -> Void) {
    let suiteName = "CueSeekerWorkbenchLayoutStateTests-\(UUID().uuidString)"
    let userDefaults = UserDefaults(suiteName: suiteName)!
    defer {
        userDefaults.removePersistentDomain(forName: suiteName)
    }

    body(userDefaults)
}

@MainActor
@Test
func workbenchContentMinimumWidthFollowsTheCurrentPage() {
    let searchContent = WorkbenchContentMinimumWidth.contentWidth(
        panelMode: .search,
        isShioriListDetail: false
    )
    let shioriDetailContent = WorkbenchContentMinimumWidth.contentWidth(
        panelMode: .shiori,
        isShioriListDetail: true
    )
    let shioriOverviewContent = WorkbenchContentMinimumWidth.contentWidth(
        panelMode: .shiori,
        isShioriListDetail: false
    )
    let dataContent = WorkbenchContentMinimumWidth.contentWidth(
        panelMode: .data,
        isShioriListDetail: false
    )

    let pagePadding = 2 * WorkbenchControlMetrics.redesignWorkbenchPageHorizontalPadding
    #expect(
        searchContent == SubtitleTableColumnLayout.minimumContentWidth(
            showsDateAddedColumn: false,
            showsDisplayTitleColumn: true,
            showsTimeColumn: true,
            showsLanguageColumn: false,
            cuesMinimumWidth: SubtitleTableMetrics.cuesColumnMinimumWidth
        ) + pagePadding
    )
    // The Shiori table carries one more column than Search.
    #expect(shioriDetailContent > searchContent)
    // Pages without a table stay at the App minimum window width.
    #expect(shioriOverviewContent == AppShellLayout.minimumWindowWidth)
    #expect(dataContent == AppShellLayout.minimumWindowWidth)
}

@MainActor
@Test
func workbenchWindowMinimumWidthAddsTheSidebarInsteadOfShrinkingContent() {
    for (panelMode, isShioriListDetail) in [
        (WorkbenchPanelMode.search, false),
        (WorkbenchPanelMode.shiori, true),
        (WorkbenchPanelMode.data, false),
    ] {
        let content = WorkbenchContentMinimumWidth.contentWidth(
            panelMode: panelMode,
            isShioriListDetail: isShioriListDetail
        )
        let collapsed = WorkbenchContentMinimumWidth.windowWidth(
            panelMode: panelMode,
            isShioriListDetail: isShioriListDetail,
            isSidebarVisible: false
        )
        let expanded = WorkbenchContentMinimumWidth.windowWidth(
            panelMode: panelMode,
            isShioriListDetail: isShioriListDetail,
            isSidebarVisible: true
        )

        #expect(collapsed == content)
        #expect(expanded == content + AppShellLayout.sidebarWidth)
    }
}
