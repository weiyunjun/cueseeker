import AppKit
@testable import CueSeekerCore
import CueSeekerPlayback
import SwiftUI
import Testing
@testable import CueSeekerApp

@Suite(.serialized)
@MainActor
struct WorkbenchAccessibilityStep3Tests {
    private func makeTestCoordinator() -> (AppCoordinator, String, UserDefaults) {
        let suiteName = "WorkbenchAccessibilityStep3Tests-\(UUID().uuidString)"
        let userDefaults = UserDefaults.temporary(suiteName: suiteName)!
        let app = AppCoordinator(userDefaults: userDefaults)
        return (app, suiteName, userDefaults)
    }

    private func makeKeyEvent(
        keyCode: UInt16,
        flags: NSEvent.ModifierFlags = [],
        isRepeat: Bool = false
    ) -> NSEvent {
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: flags,
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: 0,
            context: nil,
            characters: "",
            charactersIgnoringModifiers: "",
            isARepeat: isRepeat,
            keyCode: keyCode
        )!
    }

    @Test
    func generalAndPlayCategoriesTraverseAllTargetsAndHandleSelectedOrDisabledControls() {
        let (app, suiteName, userDefaults) = makeTestCoordinator()
        defer { userDefaults.removePersistentDomainAndPlist(forName: suiteName) }

        app.workbenchAccessibility.selectedSettingsCategory = .general
        let expectedGeneralTargets: [SettingsAccessibilityTarget] = [
            .sidebarCategory(.general),
            .sidebarCategory(.play),
            .sidebarCategory(.shortcuts),
            .sidebarCategory(.subtitle),
            .sidebarCategory(.maintenance),
            .sidebarCategory(.developer),
            .appearanceMode(.light),
            .appearanceMode(.dark),
            .appearanceMode(.auto),
            .searchShowCueGroup,
            .searchPrefillCommandPanel,
            .languageDropdown,
            .deepLinkPlayFirstSearchResult,
        ]
        #expect(app.currentSettingsAccessibilityTargets() == expectedGeneralTargets)

        // First Tab focuses 1st item (.sidebarCategory(.general)), which is already selected.
        #expect(app.handleSettingsKeyDown(makeKeyEvent(keyCode: MenuGate.tabKeyCode)))
        #expect(app.workbenchAccessibility.focusedSettingsTarget == .sidebarCategory(.general))

        // Activating an already selected sidebar category is a no-op and keeps focus on it.
        #expect(app.handleSettingsKeyDown(makeKeyEvent(keyCode: 49)))
        #expect(app.workbenchAccessibility.selectedSettingsCategory == .general)
        #expect(app.workbenchAccessibility.focusedSettingsTarget == .sidebarCategory(.general))

        // Move to .sidebarCategory(.play) and activate it -> switches page while keeping focus on .sidebarCategory(.play).
        #expect(app.handleSettingsKeyDown(makeKeyEvent(keyCode: MenuGate.tabKeyCode)))
        #expect(app.workbenchAccessibility.focusedSettingsTarget == .sidebarCategory(.play))
        #expect(app.handleSettingsControllerInput(.button(.south, isRepeat: false)))
        #expect(app.workbenchAccessibility.selectedSettingsCategory == .play)
        #expect(app.workbenchAccessibility.focusedSettingsTarget == .sidebarCategory(.play))

        let expectedPlayTargets: [SettingsAccessibilityTarget] = [
            .sidebarCategory(.general),
            .sidebarCategory(.play),
            .sidebarCategory(.shortcuts),
            .sidebarCategory(.subtitle),
            .sidebarCategory(.maintenance),
            .sidebarCategory(.developer),
            .playAutoPause,
            .playAutoSwitch,
            .numberField(.autoSwitchGap),
            .decodeMode(.hardware),
            .decodeMode(.software),
            .decodeMode(.auto),
        ]
        #expect(app.currentSettingsAccessibilityTargets() == expectedPlayTargets)

        // Disable Auto Pause so Auto Switch becomes disabled.
        app.settings.autoPauseAfterCueFinishesEnabled = false
        #expect(!app.isSettingsAccessibilityTargetEnabled(.playAutoSwitch))

        // Disabled Auto Switch still participates in focus traversal, but activating it is a no-op.
        app.workbenchAccessibility.setSettingsFocus(.playAutoSwitch, isTargetEnabled: false)
        let previousAutoSwitch = app.settings.autoSwitchToNextCuesInPlaylistEnabled
        #expect(app.handleSettingsKeyDown(makeKeyEvent(keyCode: 49)))
        #expect(app.settings.autoSwitchToNextCuesInPlaylistEnabled == previousAutoSwitch)
    }

    @Test
    func shortcutsCategorySkipsKeyFieldsAutoExitsAfterRestoreDefaultAndBlocksDuringRecording() {
        let (app, suiteName, userDefaults) = makeTestCoordinator()
        defer { userDefaults.removePersistentDomainAndPlist(forName: suiteName) }

        app.workbenchAccessibility.selectedSettingsCategory = .shortcuts
        // When all shortcuts are at default, only the 6 sidebar categories are in the focus cycle.
        #expect(app.currentSettingsAccessibilityTargets() == SettingsCategory.allCases.map { .sidebarCategory($0) })

        // Customize one shortcut (.openCommandPanel, default K=40) to A=0 so its Restore Default button appears.
        app.settings.playbackShortcuts.set(
            PlaybackShortcutKey(keyCode: 0),
            for: .openCommandPanel
        )
        #expect(!app.settings.playbackShortcuts.keymap.isDefault(.openCommandPanel))
        let expectedShortcutTargets: [SettingsAccessibilityTarget] =
            SettingsCategory.allCases.map { .sidebarCategory($0) }
            + [.shortcutRestoreDefault(.openCommandPanel)]
        #expect(app.currentSettingsAccessibilityTargets() == expectedShortcutTargets)

        // Shift+Tab from initial state focuses the last item (.shortcutRestoreDefault(.openCommandPanel)).
        #expect(app.handleSettingsKeyDown(makeKeyEvent(keyCode: MenuGate.tabKeyCode, flags: .shift)))
        #expect(app.workbenchAccessibility.focusedSettingsTarget == .shortcutRestoreDefault(.openCommandPanel))

        // Activating Restore Default resets the shortcut and automatically exits Settings accessibility state.
        #expect(app.handleSettingsKeyDown(makeKeyEvent(keyCode: 36)))
        #expect(app.settings.playbackShortcuts.keymap.isDefault(.openCommandPanel))
        #expect(!app.workbenchAccessibility.isSettingsActive)
        #expect(app.workbenchAccessibility.focusedSettingsTarget == nil)

        // While a shortcut is recording, Tab/Shift+Tab/R1/L1 are ignored by Settings accessibility.
        app.workbenchAccessibility.isShortcutRecording = true
        #expect(!app.handleSettingsKeyDown(makeKeyEvent(keyCode: MenuGate.tabKeyCode)))
        #expect(!app.handleSettingsControllerInput(.button(.rightShoulder, isRepeat: false)))
        #expect(!app.workbenchAccessibility.isSettingsActive)
    }

    @Test
    func subtitleCategoryColorWellWholeBeforePartForwardAndBackwardAndTwoStageEscape() {
        let (app, suiteName, userDefaults) = makeTestCoordinator()
        defer { userDefaults.removePersistentDomainAndPlist(forName: suiteName) }

        app.workbenchAccessibility.selectedSettingsCategory = .subtitle
        var isTextColorFieldFocused = false
        app.workbenchAccessibility.registerSettingsTextInput(
            .subtitleColorField(.textColor),
            setFocused: { isTextColorFieldFocused = $0 },
            isCurrentlyFocused: { isTextColorFieldFocused }
        )

        // Start on .subtitleItalic (just before .subtitleColorField(.textColor)).
        app.workbenchAccessibility.setSettingsFocus(.subtitleItalic)
        #expect(app.workbenchAccessibility.activeSubtitleColorPopover == nil)
        #expect(!isTextColorFieldFocused)

        // Forward Tab lands on .subtitleColorField(.textColor), focuses its hex input, and opens the 6x2 preset popover.
        #expect(app.handleSettingsKeyDown(makeKeyEvent(keyCode: MenuGate.tabKeyCode)))
        #expect(app.workbenchAccessibility.focusedSettingsTarget == .subtitleColorField(.textColor))
        #expect(app.workbenchAccessibility.activeSubtitleColorPopover == .textColor)
        #expect(isTextColorFieldFocused)

        // Next forward Tab enters the 1st preset swatch (.subtitleColorPreset(.textColor, 0)),
        // unfocusing the hex input while keeping the preset popover open.
        #expect(app.handleSettingsKeyDown(makeKeyEvent(keyCode: MenuGate.tabKeyCode)))
        #expect(app.workbenchAccessibility.focusedSettingsTarget == .subtitleColorPreset(.textColor, 0))
        #expect(app.workbenchAccessibility.activeSubtitleColorPopover == .textColor)
        #expect(!isTextColorFieldFocused)

        // Traverse remaining 11 swatches (indices 1...11).
        for expectedIndex in 1..<12 {
            #expect(app.handleSettingsKeyDown(makeKeyEvent(keyCode: MenuGate.tabKeyCode)))
            #expect(app.workbenchAccessibility.focusedSettingsTarget == .subtitleColorPreset(.textColor, expectedIndex))
            #expect(app.workbenchAccessibility.activeSubtitleColorPopover == .textColor)
        }

        // Activating the 12th swatch (index 11, #5856D6) applies its RGB color while keeping popover open.
        #expect(app.handleSettingsControllerInput(.button(.south, isRepeat: false)))
        #expect(SettingsSubtitleColorField.hexString(for: app.settings.srtSubtitleStyle.textColor) == "5856D6")
        #expect(app.workbenchAccessibility.activeSubtitleColorPopover == .textColor)

        // Next forward Tab after the 12th swatch leaves Color Well to .numberField(.subtitleLetterSpacing)
        // and automatically closes the preset popover.
        #expect(app.handleSettingsKeyDown(makeKeyEvent(keyCode: MenuGate.tabKeyCode)))
        #expect(app.workbenchAccessibility.focusedSettingsTarget == .numberField(.subtitleLetterSpacing))
        #expect(app.workbenchAccessibility.activeSubtitleColorPopover == nil)

        // Backward Shift+Tab from .numberField(.subtitleLetterSpacing) enters Color Well via whole-before-part:
        // lands on .subtitleColorField(.textColor) FIRST (NOT the 12th swatch), focuses hex input, and opens popover!
        #expect(app.handleSettingsKeyDown(makeKeyEvent(keyCode: MenuGate.tabKeyCode, flags: .shift)))
        #expect(app.workbenchAccessibility.focusedSettingsTarget == .subtitleColorField(.textColor))
        #expect(app.workbenchAccessibility.activeSubtitleColorPopover == .textColor)
        #expect(isTextColorFieldFocused)

        // Backward Shift+Tab again from .subtitleColorField(.textColor) leaves to .subtitleItalic and closes popover.
        #expect(app.handleSettingsKeyDown(makeKeyEvent(keyCode: MenuGate.tabKeyCode, flags: .shift)))
        #expect(app.workbenchAccessibility.focusedSettingsTarget == .subtitleItalic)
        #expect(app.workbenchAccessibility.activeSubtitleColorPopover == nil)
        #expect(!isTextColorFieldFocused)

        // Re-enter .subtitleColorField(.textColor) and verify two-stage Esc / East:
        #expect(app.handleSettingsKeyDown(makeKeyEvent(keyCode: MenuGate.tabKeyCode)))
        #expect(app.workbenchAccessibility.focusedSettingsTarget == .subtitleColorField(.textColor))
        #expect(app.workbenchAccessibility.activeSubtitleColorPopover == .textColor)
        #expect(isTextColorFieldFocused)

        // 1st Esc clears only the outer accessibility focus ring; hex input focus and preset popover stay active.
        #expect(app.handleSettingsKeyDown(makeKeyEvent(keyCode: 53)))
        #expect(!app.workbenchAccessibility.isSettingsActive)
        #expect(app.workbenchAccessibility.activeSubtitleColorPopover == .textColor)
        #expect(isTextColorFieldFocused)

        // 2nd Esc closes the preset popover and unfocuses the hex input.
        #expect(app.handleSettingsKeyDown(makeKeyEvent(keyCode: 53)))
        #expect(app.workbenchAccessibility.activeSubtitleColorPopover == nil)
        #expect(!isTextColorFieldFocused)
    }

    @Test
    func maintenanceConfirmationDialogAndIndependentMainWindowFocusPreservation() {
        let (app, suiteName, userDefaults) = makeTestCoordinator()
        defer { userDefaults.removePersistentDomainAndPlist(forName: suiteName) }

        // Main window focus is preserved independently while interacting with Settings.
        app.workbenchAccessibility.setFocus(.topbarSettingsButton)
        app.workbenchAccessibility.selectedSettingsCategory = .maintenance
        #expect(app.currentSettingsAccessibilityTargets() == SettingsCategory.allCases.map { .sidebarCategory($0) } + [
            .maintenanceRefresh,
            .maintenanceCompactDatabase,
        ])

        app.workbenchAccessibility.setSettingsFocus(.maintenanceRefresh)
        #expect(app.workbenchAccessibility.focusedTarget == .topbarSettingsButton)
        #expect(app.workbenchAccessibility.focusedSettingsTarget == .maintenanceRefresh)

        // Open Settings Confirmation Dialog (Compact Database).
        var didConfirm = false
        var didCancel = false
        app.settings.confirmation.session = WorkbenchConfirmationSession(
            title: "Compact Database",
            message: "Compact now?",
            destructiveTitle: "Compact",
            cancelTitle: "Cancel",
            onDestructive: {
                didConfirm = true
            },
            onCancel: {
                didCancel = true
            }
        )
        app.reconcileSettingsAccessibilityFocus()
        app.reconcileSettingsDialogAccessibilityFocus()

        // Settings page focus is cleared, dialog starts unfocused, and main window focus remains intact.
        #expect(!app.workbenchAccessibility.isSettingsActive)
        #expect(!app.workbenchAccessibility.isSettingsDialogActive)
        #expect(app.workbenchAccessibility.focusedTarget == .topbarSettingsButton)
        #expect(app.currentSettingsDialogAccessibilityTargets() == [
            .dialogCloseButton,
            .confirmationAction("cancel"),
            .confirmationAction("destructive"),
        ])

        // Unfocused Return is consumed without triggering Cancel or Compact.
        #expect(app.handleSettingsKeyDown(makeKeyEvent(keyCode: 36)))
        #expect(!didConfirm)
        #expect(!didCancel)
        #expect(app.settings.confirmation.session != nil)

        // Tab -> .dialogCloseButton, Shift+Tab -> .confirmationAction("destructive").
        #expect(app.handleSettingsKeyDown(makeKeyEvent(keyCode: MenuGate.tabKeyCode)))
        #expect(app.workbenchAccessibility.focusedSettingsDialogTarget == .dialogCloseButton)
        #expect(app.handleSettingsKeyDown(makeKeyEvent(keyCode: MenuGate.tabKeyCode, flags: .shift)))
        #expect(app.workbenchAccessibility.focusedSettingsDialogTarget == .confirmationAction("destructive"))

        // 1st Esc clears dialog focus ring; 2nd Esc closes dialog.
        #expect(app.handleSettingsKeyDown(makeKeyEvent(keyCode: 53)))
        #expect(!app.workbenchAccessibility.isSettingsDialogActive)
        #expect(app.settings.confirmation.session != nil)

        #expect(app.handleSettingsKeyDown(makeKeyEvent(keyCode: 53)))
        #expect(app.settings.confirmation.session == nil)
        #expect(app.workbenchAccessibility.focusedTarget == .topbarSettingsButton)
    }
}
