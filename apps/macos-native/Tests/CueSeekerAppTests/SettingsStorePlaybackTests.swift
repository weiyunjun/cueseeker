import AppKit
import Foundation
import Testing
@testable import CueSeekerApp

@MainActor
@Test
func settingsStoreDefaultsCueSequenceAutoPlaySettings() {
    withTemporaryPlaybackSettingsUserDefaults { userDefaults, service in
        let store = SettingsStore(
            userDefaults: userDefaults,
            credentialStore: KeychainCredentialStore(service: service)
        )

        #expect(!store.autoPlayCueSequenceEnabled)
        #expect(store.autoPlayCueSequenceGapMilliseconds == 500)
    }
}

@MainActor
@Test
func settingsStorePersistsCueSequenceAutoPlaySettings() {
    withTemporaryPlaybackSettingsUserDefaults { userDefaults, service in
        let store = SettingsStore(
            userDefaults: userDefaults,
            credentialStore: KeychainCredentialStore(service: service)
        )

        store.autoPlayCueSequenceEnabled = true
        store.setAutoPlayCueSequenceGapMilliseconds(750)

        let reloadedStore = SettingsStore(
            userDefaults: userDefaults,
            credentialStore: KeychainCredentialStore(service: service)
        )

        #expect(reloadedStore.autoPlayCueSequenceEnabled)
        #expect(reloadedStore.autoPlayCueSequenceGapMilliseconds == 750)
    }
}

@MainActor
@Test
func settingsStoreClampsCueSequenceAutoPlayGap() {
    withTemporaryPlaybackSettingsUserDefaults { userDefaults, service in
        let store = SettingsStore(
            userDefaults: userDefaults,
            credentialStore: KeychainCredentialStore(service: service)
        )

        store.setAutoPlayCueSequenceGapMilliseconds(-1)
        #expect(store.autoPlayCueSequenceGapMilliseconds == 0)

        store.setAutoPlayCueSequenceGapMilliseconds(10_001)
        #expect(store.autoPlayCueSequenceGapMilliseconds == 10_000)

        let reloadedStore = SettingsStore(
            userDefaults: userDefaults,
            credentialStore: KeychainCredentialStore(service: service)
        )

        #expect(reloadedStore.autoPlayCueSequenceGapMilliseconds == 10_000)
    }
}

@MainActor
private func withTemporaryPlaybackSettingsUserDefaults(_ body: (UserDefaults, String) -> Void) {
    _ = NSApplication.shared
    let suiteName = "CueSeekerPlaybackSettingsTests-\(UUID().uuidString)"
    let userDefaults = UserDefaults(suiteName: suiteName)!
    defer {
        userDefaults.removePersistentDomain(forName: suiteName)
    }

    body(userDefaults, suiteName)
}
