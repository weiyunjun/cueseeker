import Foundation
import Combine
import Testing
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

        layoutState.selectPanelMode(.search)

        let reloadedLayoutState = WorkbenchLayoutState(userDefaults: userDefaults)
        #expect(reloadedLayoutState.panelMode == .search)
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
private func withTemporaryWorkbenchLayoutUserDefaults(_ body: (UserDefaults) -> Void) {
    let suiteName = "CueSeekerWorkbenchLayoutStateTests-\(UUID().uuidString)"
    let userDefaults = UserDefaults(suiteName: suiteName)!
    defer {
        userDefaults.removePersistentDomain(forName: suiteName)
    }

    body(userDefaults)
}
