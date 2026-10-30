import AppKit
import CueSeekerPlayback
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
@Test
func settingsStoreStepsCueSequenceAutoSwitchGapByHundredMillisecondsAndClampsAtBoundaries() {
    withTemporaryPlaybackSettingsUserDefaults { userDefaults in
        let store = SettingsStore(userDefaults: userDefaults)
        #expect(store.autoSwitchCueSequenceGapMilliseconds == 500)
        #expect(store.canDecreaseAutoSwitchCueSequenceGap)
        #expect(store.canIncreaseAutoSwitchCueSequenceGap)

        store.decreaseAutoSwitchCueSequenceGapMilliseconds()
        #expect(store.autoSwitchCueSequenceGapMilliseconds == 400)

        store.increaseAutoSwitchCueSequenceGapMilliseconds()
        #expect(store.autoSwitchCueSequenceGapMilliseconds == 500)

        store.setAutoSwitchCueSequenceGapMilliseconds(100)
        #expect(store.canDecreaseAutoSwitchCueSequenceGap)
        store.decreaseAutoSwitchCueSequenceGapMilliseconds()
        #expect(store.autoSwitchCueSequenceGapMilliseconds == 0)
        #expect(!store.canDecreaseAutoSwitchCueSequenceGap)
        #expect(store.canIncreaseAutoSwitchCueSequenceGap)

        store.decreaseAutoSwitchCueSequenceGapMilliseconds()
        #expect(store.autoSwitchCueSequenceGapMilliseconds == 0)

        store.setAutoSwitchCueSequenceGapMilliseconds(9_900)
        #expect(store.canIncreaseAutoSwitchCueSequenceGap)
        store.increaseAutoSwitchCueSequenceGapMilliseconds()
        #expect(store.autoSwitchCueSequenceGapMilliseconds == 10_000)
        #expect(!store.canIncreaseAutoSwitchCueSequenceGap)
        #expect(store.canDecreaseAutoSwitchCueSequenceGap)

        store.increaseAutoSwitchCueSequenceGapMilliseconds()
        #expect(store.autoSwitchCueSequenceGapMilliseconds == 10_000)

        let reloadedStore = SettingsStore(userDefaults: userDefaults)
        #expect(reloadedStore.autoSwitchCueSequenceGapMilliseconds == 10_000)
    }
}

@MainActor
@Test
func settingsStoreKeepsTheSRTSubtitleStyleAcrossLaunches() {
    withTemporaryPlaybackSettingsUserDefaults { userDefaults in
        let store = SettingsStore(userDefaults: userDefaults)
        #expect(store.srtSubtitleStyle == SRTSubtitleStyle())

        store.srtSubtitleStyle.size = 42
        store.srtSubtitleStyle.borderType = .backgroundBox
        store.srtSubtitleStyle.horizontalAlignment = .left

        let reloadedStore = SettingsStore(userDefaults: userDefaults)

        #expect(reloadedStore.srtSubtitleStyle == store.srtSubtitleStyle)
    }
}

@MainActor
@Test
func settingsLanguageMenuMatchesPopupWidthAndMapsLocalRowPositions() {
    #expect(
        SettingsLanguageMenu.panelSize.width
            == WorkbenchControlMetrics.redesignSettingsPopupWidth
    )
    #expect(
        SettingsLanguageMenu.panelSize.height
            == CGFloat(AppLanguage.allCases.count) * WorkbenchControlMetrics.redesignMenuItemHeight
                + MenuMetrics.padding * 2
    )
    #expect(SettingsLanguageMenu.position(atLocalPoint: CGPoint(x: 20, y: 2)) == nil)
    for index in AppLanguage.allCases.indices {
        let midY = MenuMetrics.padding
            + (CGFloat(index) + 0.5) * WorkbenchControlMetrics.redesignMenuItemHeight
        #expect(
            SettingsLanguageMenu.position(atLocalPoint: CGPoint(x: 20, y: midY)) == index
        )
    }
    #expect(
        SettingsLanguageMenu.position(
            atLocalPoint: CGPoint(x: 20, y: SettingsLanguageMenu.panelSize.height - 1)
        ) == nil
    )
}

@MainActor
@Test
func compactDatabaseConfirmationUsesUnifiedConfirmationSessionAndBlocksTermination() throws {
    let tempRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerCompactConfirmationTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempRoot) }

    withTemporaryPlaybackSettingsUserDefaults { userDefaults in
        let app = AppCoordinator(
            userDefaults: userDefaults,
            databaseURL: tempRoot.appendingPathComponent("index.sqlite")
        )
        #expect(!app.isBlockingConfirmationPresented)
        #expect(app.settings.confirmation.session == nil)

        app.requestCompactDatabaseConfirmation()

        #expect(app.isBlockingConfirmationPresented)
        guard let session = app.settings.confirmation.session else {
            Issue.record("Expected Settings compact database confirmation session")
            return
        }
        #expect(session.title == L("settings.maintenance.compact_title"))
        #expect(session.message == L("settings.maintenance.compact_message"))
        #expect(session.actions.count == 2)
        #expect(session.actions[0].style == .neutral)
        #expect(session.actions[0].isDefault)
        #expect(session.actions[0].isCancel)
        #expect(session.actions[1].style == .destructive)
        #expect(session.actions[1].title == L("settings.maintenance.compact_confirm"))

        session.actions[0].action()
        #expect(app.settings.confirmation.session == nil)
        #expect(!app.isBlockingConfirmationPresented)
    }
}

@MainActor
private func withTemporaryPlaybackSettingsUserDefaults(_ body: (UserDefaults) -> Void) {
    _ = NSApplication.shared
    let suiteName = "CueSeekerPlaybackSettingsTests-\(UUID().uuidString)"
    let userDefaults = UserDefaults.temporary(suiteName: suiteName)!
    defer {
        userDefaults.removePersistentDomainAndPlist(forName: suiteName)
    }

    body(userDefaults)
}
