import AppKit
import Foundation
import Testing
@testable import CueSeekerApp

@MainActor
@Test
func settingsStoreDefaultsURLSchemePlayFirstSearchResultOff() {
    withTemporaryURLSchemeSettings { userDefaults, service in
        let store = SettingsStore(
            userDefaults: userDefaults,
            credentialStore: KeychainCredentialStore(service: service)
        )

        #expect(!store.urlSchemePlayFirstSearchResultEnabled)
    }
}

@MainActor
@Test
func settingsStorePersistsURLSchemePlayFirstSearchResult() {
    withTemporaryURLSchemeSettings { userDefaults, service in
        let store = SettingsStore(
            userDefaults: userDefaults,
            credentialStore: KeychainCredentialStore(service: service)
        )

        store.urlSchemePlayFirstSearchResultEnabled = true
        #expect(userDefaults.bool(forKey: "urlSchemePlayFirstSearchResultEnabled"))

        let reloadedStore = SettingsStore(
            userDefaults: userDefaults,
            credentialStore: KeychainCredentialStore(service: service)
        )
        #expect(reloadedStore.urlSchemePlayFirstSearchResultEnabled)
    }
}

@MainActor
private func withTemporaryURLSchemeSettings(
    _ body: (UserDefaults, String) -> Void
) {
    _ = NSApplication.shared
    let suiteName = "CueSeekerURLSchemeSettingsTests-\(UUID().uuidString)"
    let userDefaults = UserDefaults(suiteName: suiteName)!
    defer {
        userDefaults.removePersistentDomain(forName: suiteName)
    }
    body(userDefaults, suiteName)
}
