import Foundation
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
private func withTemporaryWorkbenchLayoutUserDefaults(_ body: (UserDefaults) -> Void) {
    let suiteName = "CueSeekerWorkbenchLayoutStateTests-\(UUID().uuidString)"
    let userDefaults = UserDefaults(suiteName: suiteName)!
    defer {
        userDefaults.removePersistentDomain(forName: suiteName)
    }

    body(userDefaults)
}
