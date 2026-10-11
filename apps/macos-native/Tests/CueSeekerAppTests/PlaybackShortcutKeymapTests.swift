import AppKit
import Carbon.HIToolbox
import Foundation
import Testing
@testable import CueSeekerApp

private func key(
    _ keyCode: Int,
    command: Bool = false,
    option: Bool = false,
    control: Bool = false,
    shift: Bool = false
) -> PlaybackShortcutKey {
    PlaybackShortcutKey(
        keyCode: UInt16(keyCode),
        command: command,
        option: option,
        control: control,
        shift: shift
    )
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
func recordingAcceptsModifiersAndFunctionKeysAndSilentlyExcludesReserved() {
    let none: NSEvent.ModifierFlags = []

    #expect(
        PlaybackShortcutAction.toggleSubtitles.recordedKey(
            keyCode: UInt16(kVK_Delete),
            modifierFlags: none
        ) == key(kVK_Delete)
    )
    #expect(
        PlaybackShortcutAction.toggleSubtitles.recordedKey(
            keyCode: UInt16(kVK_ForwardDelete),
            modifierFlags: .function
        ) == key(kVK_ForwardDelete)
    )
    #expect(
        PlaybackShortcutAction.speedUp.recordedKey(
            keyCode: UInt16(kVK_ANSI_Period),
            modifierFlags: [.shift, .capsLock]
        ) == key(kVK_ANSI_Period, shift: true)
    )
    #expect(
        PlaybackShortcutAction.copyCueText.recordedKey(
            keyCode: UInt16(kVK_ANSI_C),
            modifierFlags: .command
        ) == key(kVK_ANSI_C, command: true)
    )
    #expect(
        PlaybackShortcutAction.copyScreenshot.recordedKey(
            keyCode: UInt16(kVK_ANSI_P),
            modifierFlags: [.command, .shift]
        ) == key(kVK_ANSI_P, command: true, shift: true)
    )
    #expect(
        PlaybackShortcutAction.seekForward.recordedKey(
            keyCode: UInt16(kVK_RightArrow),
            modifierFlags: .option
        ) == key(kVK_RightArrow, option: true)
    )
    for keyCode in [kVK_F5, kVK_Home, kVK_End, kVK_PageUp, kVK_PageDown] {
        #expect(
            PlaybackShortcutAction.playPause.recordedKey(
                keyCode: UInt16(keyCode),
                modifierFlags: .function
            ) == key(keyCode)
        )
    }

    // Excluded: pure modifier keys
    for modKey in [kVK_Command, kVK_Shift, kVK_Option, kVK_Control] {
        #expect(
            PlaybackShortcutAction.toggleSubtitles.recordedKey(
                keyCode: UInt16(modKey),
                modifierFlags: none
            ) == nil
        )
    }

    // Excluded: system and window key combinations
    for sysKey in [kVK_ANSI_Q, kVK_ANSI_Comma, kVK_ANSI_W, kVK_ANSI_M, kVK_ANSI_H] {
        #expect(
            PlaybackShortcutAction.toggleSubtitles.recordedKey(
                keyCode: UInt16(sysKey),
                modifierFlags: .command
            ) == nil
        )
    }
    #expect(
        PlaybackShortcutAction.toggleSubtitles.recordedKey(
            keyCode: UInt16(kVK_ANSI_H),
            modifierFlags: [.command, .option]
        ) == nil
    )

    // Excluded: Tab
    #expect(
        PlaybackShortcutAction.playPause.recordedKey(
            keyCode: UInt16(kVK_Tab),
            modifierFlags: none
        ) == nil
    )
}

@MainActor
@Test
func returnAndArrowsAreReservedWhereTheyConfirmAndMove() {
    for keyCode in [kVK_Return, kVK_ANSI_KeypadEnter, kVK_UpArrow, kVK_LeftArrow] {
        for action in [PlaybackShortcutAction.saveToExcerpt, .editCollage, .openCommandPanel] {
            #expect(
                action.recordedKey(keyCode: UInt16(keyCode), modifierFlags: .function)
                    == nil
            )
        }
        #expect(
            PlaybackShortcutAction.playPause.recordedKey(
                keyCode: UInt16(keyCode),
                modifierFlags: .function
            ) == key(keyCode)
        )
    }
}

@MainActor
@Test
func shortcutKeycapsDrawShiftAndTheReturnIcon() {
    #expect(key(kVK_Return).keycaps == [.returnKey])
    #expect(key(kVK_Space).keycaps == [.text("Space")])
    #expect(key(kVK_UpArrow, shift: true).keycaps == [.text("⇧"), .text("↑")])
    #expect(key(kVK_ANSI_C, command: true).keycaps == [.text("⌘"), .text("C")])
    #expect(
        key(kVK_ANSI_P, command: true, option: true, control: true, shift: true).keycaps
            == [.text("⌃"), .text("⌥"), .text("⇧"), .text("⌘"), .text("P")]
    )
    #expect(key(kVK_Delete).keycaps == [.text("⌫")])
    #expect(key(kVK_F5).keycaps == [.text("F5")])
    #expect(key(kVK_Home).keycaps == [.text("Home")])
    #expect(key(kVK_PageUp).keycaps == [.text("Page Up")])
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
