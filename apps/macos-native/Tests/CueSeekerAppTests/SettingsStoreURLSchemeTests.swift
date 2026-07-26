import AppKit
import Foundation
import Testing
@testable import CueSeekerApp

@MainActor
@Test
func settingsStoreDefaultsURLSchemePlayFirstSearchResultOff() {
    withTemporaryURLSchemeSettings { userDefaults in
        let store = SettingsStore(userDefaults: userDefaults)

        #expect(!store.urlSchemePlayFirstSearchResultEnabled)
    }
}

@MainActor
@Test
func settingsStorePersistsURLSchemePlayFirstSearchResult() {
    withTemporaryURLSchemeSettings { userDefaults in
        let store = SettingsStore(userDefaults: userDefaults)

        store.urlSchemePlayFirstSearchResultEnabled = true
        #expect(userDefaults.bool(forKey: "urlSchemePlayFirstSearchResultEnabled"))

        let reloadedStore = SettingsStore(userDefaults: userDefaults)
        #expect(reloadedStore.urlSchemePlayFirstSearchResultEnabled)
    }
}

@MainActor
private func withTemporaryURLSchemeSettings(
    _ body: (UserDefaults) -> Void
) {
    _ = NSApplication.shared
    let suiteName = "CueSeekerURLSchemeSettingsTests-\(UUID().uuidString)"
    let userDefaults = UserDefaults(suiteName: suiteName)!
    defer {
        userDefaults.removePersistentDomain(forName: suiteName)
    }
    body(userDefaults)
}
