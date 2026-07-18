import AppKit
import Foundation
import Testing
@testable import CueSeekerApp

@MainActor
@Test
func settingsStoreDefaultsPlaylistCueSettingsIndependently() {
    withTemporaryPlaybackSettingsUserDefaults { userDefaults, service in
        let store = SettingsStore(
            userDefaults: userDefaults,
            credentialStore: KeychainCredentialStore(service: service)
        )

        #expect(store.onlyPlayCuesInPlaylistEnabled)
        #expect(!store.autoSwitchToNextCuesInPlaylistEnabled)
        #expect(store.autoSwitchCueSequenceGapMilliseconds == 500)
        #expect(!store.playbackSpeakerDisplayEnabled)
    }
}

@MainActor
@Test
func settingsStorePersistsPlaylistCueSettingsIndependently() {
    withTemporaryPlaybackSettingsUserDefaults { userDefaults, service in
        let store = SettingsStore(
            userDefaults: userDefaults,
            credentialStore: KeychainCredentialStore(service: service)
        )

        store.onlyPlayCuesInPlaylistEnabled = false
        store.autoSwitchToNextCuesInPlaylistEnabled = true
        store.setAutoSwitchCueSequenceGapMilliseconds(750)
        store.playbackSpeakerDisplayEnabled = true

        let reloadedStore = SettingsStore(
            userDefaults: userDefaults,
            credentialStore: KeychainCredentialStore(service: service)
        )

        #expect(!reloadedStore.onlyPlayCuesInPlaylistEnabled)
        #expect(reloadedStore.autoSwitchToNextCuesInPlaylistEnabled)
        #expect(reloadedStore.autoSwitchCueSequenceGapMilliseconds == 750)
        #expect(reloadedStore.playbackSpeakerDisplayEnabled)
    }
}

@MainActor
@Test
func settingsStoreMigratesEnabledLegacyAutoPlayToBothPlaylistBehaviors() {
    withTemporaryPlaybackSettingsUserDefaults { userDefaults, service in
        userDefaults.set(true, forKey: "autoPlayCueSequenceEnabled")

        let store = SettingsStore(
            userDefaults: userDefaults,
            credentialStore: KeychainCredentialStore(service: service)
        )

        #expect(store.onlyPlayCuesInPlaylistEnabled)
        #expect(store.autoSwitchToNextCuesInPlaylistEnabled)

        userDefaults.set(false, forKey: "autoPlayCueSequenceEnabled")
        let reloadedStore = SettingsStore(
            userDefaults: userDefaults,
            credentialStore: KeychainCredentialStore(service: service)
        )

        #expect(reloadedStore.onlyPlayCuesInPlaylistEnabled)
        #expect(reloadedStore.autoSwitchToNextCuesInPlaylistEnabled)
    }
}

@MainActor
@Test
func settingsStoreClampsCueSequenceAutoSwitchGap() {
    withTemporaryPlaybackSettingsUserDefaults { userDefaults, service in
        let store = SettingsStore(
            userDefaults: userDefaults,
            credentialStore: KeychainCredentialStore(service: service)
        )

        store.setAutoSwitchCueSequenceGapMilliseconds(-1)
        #expect(store.autoSwitchCueSequenceGapMilliseconds == 0)

        store.setAutoSwitchCueSequenceGapMilliseconds(10_001)
        #expect(store.autoSwitchCueSequenceGapMilliseconds == 10_000)

        let reloadedStore = SettingsStore(
            userDefaults: userDefaults,
            credentialStore: KeychainCredentialStore(service: service)
        )

        #expect(reloadedStore.autoSwitchCueSequenceGapMilliseconds == 10_000)
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
