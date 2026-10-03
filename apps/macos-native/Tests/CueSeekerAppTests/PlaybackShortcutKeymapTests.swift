import AppKit
import Carbon.HIToolbox
import Foundation
import Testing
@testable import CueSeekerApp

private func key(_ keyCode: Int, shift: Bool = false) -> PlaybackShortcutKey {
    PlaybackShortcutKey(keyCode: UInt16(keyCode), shift: shift)
}

@Test
func defaultShortcutsHaveNoConflictEvenWhereTwoShareP() {
    let keymap = PlaybackShortcutKeymap.defaults

    for action in PlaybackShortcutAction.allCases {
        #expect(keymap.conflicts(for: action).isEmpty, "\(action)")
        #expect(keymap.effectiveKey(for: action) == action.defaultKey)
        #expect(keymap.isDefault(action))
    }
    #expect(keymap.action(for: key(kVK_ANSI_P), in: .playback) == .copyScreenshot)
    #expect(keymap.action(for: key(kVK_ANSI_P), in: .overlay) == .editCollage)
    #expect(keymap.action(for: key(kVK_ANSI_KeypadEnter), in: .playback) == .openPlaybackOverlay)
    #expect(keymap.action(for: key(kVK_ANSI_P, shift: true), in: .playback) == nil)
}

@Test
func sharedKeyInOneGroupDisablesEveryShortcutThatHasIt() {
    var keymap = PlaybackShortcutKeymap.defaults
    keymap.set(key(kVK_ANSI_F), for: .toggleSubtitles)

    #expect(keymap.conflicts(for: .toggleSubtitles) == [.toggleFullscreen])
    #expect(keymap.conflicts(for: .toggleFullscreen) == [.toggleSubtitles])
    #expect(keymap.effectiveKey(for: .toggleSubtitles) == nil)
    #expect(keymap.effectiveKey(for: .toggleFullscreen) == nil)
    #expect(keymap.action(for: key(kVK_ANSI_F), in: .playback) == nil)

    keymap.set(key(kVK_ANSI_F), for: .next)
    #expect(keymap.conflicts(for: .toggleFullscreen) == [.next, .toggleSubtitles])

    keymap.reset(.toggleSubtitles)
    keymap.reset(.next)
    #expect(keymap.conflicts(for: .toggleFullscreen).isEmpty)
    #expect(keymap.action(for: key(kVK_ANSI_F), in: .playback) == .toggleFullscreen)
}

@Test
func groupsMayShareKeysButOpenCommandPanelSharesWithNone() {
    var keymap = PlaybackShortcutKeymap.defaults
    keymap.set(key(kVK_ANSI_S), for: .copyScreenshot)
    #expect(keymap.conflicts(for: .copyScreenshot).isEmpty)
    #expect(keymap.action(for: key(kVK_ANSI_S), in: .playback) == .copyScreenshot)
    #expect(keymap.action(for: key(kVK_ANSI_S), in: .overlay) == .saveToExcerpt)

    keymap.set(key(kVK_ANSI_S), for: .openCommandPanel)
    #expect(keymap.conflicts(for: .openCommandPanel) == [.copyScreenshot, .saveToExcerpt])
    #expect(keymap.conflicts(for: .saveToExcerpt) == [.openCommandPanel])
    #expect(keymap.action(for: key(kVK_ANSI_S), in: .global) == nil)
    #expect(keymap.action(for: key(kVK_ANSI_S), in: .overlay) == nil)
}

@Test
func settingTheDefaultKeyIsTheSameAsRestoringIt() {
    var keymap = PlaybackShortcutKeymap.defaults
    keymap.set(key(kVK_ANSI_V), for: .toggleSubtitles)
    #expect(!keymap.isDefault(.toggleSubtitles))

    keymap.set(key(kVK_ANSI_Q), for: .toggleSubtitles)
    #expect(keymap.isDefault(.toggleSubtitles))
    #expect(keymap == .defaults)

    keymap.set(nil, for: .toggleSubtitles)
    #expect(!keymap.isDefault(.toggleSubtitles))
    #expect(keymap.key(for: .toggleSubtitles) == nil)
    #expect(keymap.conflicts(for: .toggleSubtitles).isEmpty)
}

@MainActor
@Test
func recordingAcceptsOneKeyOrShiftAndRefusesTheRest() {
    let none: NSEvent.ModifierFlags = []

    #expect(
        PlaybackShortcutAction.toggleSubtitles.recordedKey(
            keyCode: UInt16(kVK_Delete),
            modifierFlags: none
        ) == .success(key(kVK_Delete))
    )
    #expect(
        PlaybackShortcutAction.toggleSubtitles.recordedKey(
            keyCode: UInt16(kVK_ForwardDelete),
            modifierFlags: .function
        ) == .success(key(kVK_ForwardDelete))
    )
    #expect(
        PlaybackShortcutAction.speedUp.recordedKey(
            keyCode: UInt16(kVK_ANSI_Period),
            modifierFlags: [.shift, .capsLock]
        ) == .success(key(kVK_ANSI_Period, shift: true))
    )
    for modifier: NSEvent.ModifierFlags in [.command, .control, .option, [.shift, .command]] {
        #expect(
            PlaybackShortcutAction.toggleSubtitles.recordedKey(
                keyCode: UInt16(kVK_ANSI_Q),
                modifierFlags: modifier
            ) == .failure(.modifier)
        )
    }
    #expect(
        PlaybackShortcutAction.playPause.recordedKey(
            keyCode: UInt16(kVK_Tab),
            modifierFlags: none
        ) == .failure(.reserved)
    )
    for keyCode in [kVK_F5, kVK_Home, kVK_End, kVK_PageUp, kVK_PageDown] {
        #expect(
            PlaybackShortcutAction.playPause.recordedKey(
                keyCode: UInt16(keyCode),
                modifierFlags: .function
            ) == .failure(.unsupported)
        )
    }
}

@MainActor
@Test
func returnAndArrowsAreReservedWhereTheyConfirmAndMove() {
    for keyCode in [kVK_Return, kVK_ANSI_KeypadEnter, kVK_UpArrow, kVK_LeftArrow] {
        for action in [PlaybackShortcutAction.saveToExcerpt, .editCollage, .openCommandPanel] {
            #expect(
                action.recordedKey(keyCode: UInt16(keyCode), modifierFlags: .function)
                    == .failure(.reserved)
            )
        }
        #expect(
            PlaybackShortcutAction.playPause.recordedKey(
                keyCode: UInt16(keyCode),
                modifierFlags: .function
            ) == .success(key(keyCode))
        )
    }
}

@MainActor
@Test
func shortcutKeycapsDrawShiftAndTheReturnIcon() {
    #expect(key(kVK_Return).keycaps == [.returnKey])
    #expect(key(kVK_Space).keycaps == [.text("Space")])
    #expect(key(kVK_UpArrow, shift: true).keycaps == [.text("⇧"), .text("↑")])
    #expect(key(kVK_Delete).keycaps == [.text("⌫")])
    #expect(key(kVK_F5).keycaps.isEmpty)
    #expect(key(kVK_ANSI_S).keycaps.count == 1)
}

@MainActor
@Test
func everyShortcutHasATitleInEveryLanguage() {
    for action in PlaybackShortcutAction.allCases {
        #expect(action.title != "settings.shortcuts.action.\(action.rawValue)")
    }
}

@MainActor
@Test
func changedAndClearedShortcutsSurviveARelaunch() throws {
    let suiteName = "CueSeekerPlaybackShortcutStoreTests-\(UUID().uuidString)"
    let userDefaults = try #require(UserDefaults.temporary(suiteName: suiteName))
    defer {
        userDefaults.removePersistentDomainAndPlist(forName: suiteName)
    }

    let store = PlaybackShortcutStore(userDefaults: userDefaults)
    store.set(key(kVK_ANSI_F), for: .toggleSubtitles)
    store.set(nil, for: .copyDeepLink)
    store.set(key(kVK_ANSI_Comma, shift: true), for: .previous)

    let relaunched = PlaybackShortcutStore(userDefaults: userDefaults)
    #expect(relaunched.keymap == store.keymap)
    #expect(relaunched.keymap.key(for: .copyDeepLink) == nil)
    #expect(relaunched.keymap.effectiveKey(for: .toggleFullscreen) == nil)

    relaunched.reset(.toggleSubtitles)
    relaunched.reset(.copyDeepLink)
    relaunched.reset(.previous)
    #expect(userDefaults.object(forKey: "playbackShortcutOverrides") == nil)
    #expect(PlaybackShortcutStore(userDefaults: userDefaults).keymap == .defaults)
}
