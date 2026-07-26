import AppKit
import Foundation
import Testing
@testable import CueSeekerApp

@MainActor
@Test
func settingsStoreDefaultsToValidOnOffPlaylistCueState() {
    withTemporaryPlaybackSettingsUserDefaults { userDefaults in
        let store = SettingsStore(userDefaults: userDefaults)

        #expect(store.autoPauseAfterCueFinishesEnabled)
        #expect(!store.autoSwitchToNextCuesInPlaylistEnabled)
        #expect(store.autoSwitchCueSequenceGapMilliseconds == 500)
    }
}

@MainActor
@Test
func settingsStorePersistsOnlyTheThreeValidPlaylistCueStates() {
    withTemporaryPlaybackSettingsUserDefaults { userDefaults in
        let store = SettingsStore(userDefaults: userDefaults)

        store.autoSwitchToNextCuesInPlaylistEnabled = true
        store.setAutoSwitchCueSequenceGapMilliseconds(750)

        #expect(store.autoPauseAfterCueFinishesEnabled)
        #expect(store.autoSwitchToNextCuesInPlaylistEnabled)

        store.autoPauseAfterCueFinishesEnabled = false

        #expect(!store.autoPauseAfterCueFinishesEnabled)
        #expect(!store.autoSwitchToNextCuesInPlaylistEnabled)

        store.autoSwitchToNextCuesInPlaylistEnabled = true

        #expect(!store.autoSwitchToNextCuesInPlaylistEnabled)

        let reloadedStore = SettingsStore(userDefaults: userDefaults)

        #expect(!reloadedStore.autoPauseAfterCueFinishesEnabled)
        #expect(!reloadedStore.autoSwitchToNextCuesInPlaylistEnabled)
        #expect(reloadedStore.autoSwitchCueSequenceGapMilliseconds == 750)
    }
}

@MainActor
@Test
func settingsStoreMigratesAndNormalizesPersistedOffOnPlaylistCueState() {
    withTemporaryPlaybackSettingsUserDefaults { userDefaults in
        userDefaults.set(false, forKey: "onlyPlayCuesInPlaylistEnabled")
        userDefaults.set(true, forKey: "autoSwitchToNextCuesInPlaylistEnabled")

        let store = SettingsStore(userDefaults: userDefaults)

        #expect(!store.autoPauseAfterCueFinishesEnabled)
        #expect(!store.autoSwitchToNextCuesInPlaylistEnabled)
        #expect(!userDefaults.bool(
            forKey: "autoSwitchToNextCuesInPlaylistEnabled"
        ))
        #expect(userDefaults.object(forKey: "onlyPlayCuesInPlaylistEnabled") == nil)
        #expect(!userDefaults.bool(forKey: "autoPauseAfterCueFinishesEnabled"))
    }
}

@MainActor
@Test
func settingsStoreMigratesStoredAutoStopPreferenceOverLegacyOnlyPlayValue() {
    withTemporaryPlaybackSettingsUserDefaults { userDefaults in
        userDefaults.set(false, forKey: "onlyPlayCuesInPlaylistEnabled")
        userDefaults.set(true, forKey: "autoStopAfterCueFinishesEnabled")

        let store = SettingsStore(userDefaults: userDefaults)

        #expect(store.autoPauseAfterCueFinishesEnabled)
        #expect(userDefaults.object(forKey: "onlyPlayCuesInPlaylistEnabled") == nil)
        #expect(userDefaults.object(forKey: "autoStopAfterCueFinishesEnabled") == nil)
        #expect(userDefaults.bool(forKey: "autoPauseAfterCueFinishesEnabled"))
    }
}

@MainActor
@Test
func settingsStoreKeepsStoredAutoPausePreferenceOverLegacyAutoStopValue() {
    withTemporaryPlaybackSettingsUserDefaults { userDefaults in
        userDefaults.set(false, forKey: "autoStopAfterCueFinishesEnabled")
        userDefaults.set(true, forKey: "autoPauseAfterCueFinishesEnabled")

        let store = SettingsStore(userDefaults: userDefaults)

        #expect(store.autoPauseAfterCueFinishesEnabled)
        #expect(userDefaults.object(forKey: "autoStopAfterCueFinishesEnabled") == nil)
        #expect(userDefaults.bool(forKey: "autoPauseAfterCueFinishesEnabled"))
    }
}

@MainActor
@Test
func settingsStoreMigratesEnabledLegacyAutoPlayToBothPlaylistBehaviors() {
    withTemporaryPlaybackSettingsUserDefaults { userDefaults in
        userDefaults.set(true, forKey: "autoPlayCueSequenceEnabled")

        let store = SettingsStore(userDefaults: userDefaults)

        #expect(store.autoPauseAfterCueFinishesEnabled)
        #expect(store.autoSwitchToNextCuesInPlaylistEnabled)

        userDefaults.set(false, forKey: "autoPlayCueSequenceEnabled")
        let reloadedStore = SettingsStore(userDefaults: userDefaults)

        #expect(reloadedStore.autoPauseAfterCueFinishesEnabled)
        #expect(reloadedStore.autoSwitchToNextCuesInPlaylistEnabled)
    }
}

@MainActor
@Test
func settingsStoreClampsCueSequenceAutoSwitchGap() {
    withTemporaryPlaybackSettingsUserDefaults { userDefaults in
        let store = SettingsStore(userDefaults: userDefaults)

        store.setAutoSwitchCueSequenceGapMilliseconds(-1)
        #expect(store.autoSwitchCueSequenceGapMilliseconds == 0)

        store.setAutoSwitchCueSequenceGapMilliseconds(10_001)
        #expect(store.autoSwitchCueSequenceGapMilliseconds == 10_000)

        let reloadedStore = SettingsStore(userDefaults: userDefaults)

        #expect(reloadedStore.autoSwitchCueSequenceGapMilliseconds == 10_000)
    }
}

@MainActor
private func withTemporaryPlaybackSettingsUserDefaults(_ body: (UserDefaults) -> Void) {
    _ = NSApplication.shared
    let suiteName = "CueSeekerPlaybackSettingsTests-\(UUID().uuidString)"
    let userDefaults = UserDefaults(suiteName: suiteName)!
    defer {
        userDefaults.removePersistentDomain(forName: suiteName)
    }

    body(userDefaults)
}
