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
private func withTemporaryWorkbenchLayoutUserDefaults(_ body: (UserDefaults) -> Void) {
    let suiteName = "CueSeekerWorkbenchLayoutStateTests-\(UUID().uuidString)"
    let userDefaults = UserDefaults(suiteName: suiteName)!
    defer {
        userDefaults.removePersistentDomain(forName: suiteName)
    }

    body(userDefaults)
}
