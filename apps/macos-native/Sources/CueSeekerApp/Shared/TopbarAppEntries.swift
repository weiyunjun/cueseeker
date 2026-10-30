import SwiftUI

/// The App's entries in a top bar's trailing region: Task, then Settings, at
/// `--spacing-1`. The Workbench top bar, the player top bar and the Playback
/// Overlay's top bar all show the same pair, so what belongs to the App rather
/// than to the page is in the same place on every page. A bar that draws the
/// pair on another surface passes that surface's own colors.
struct TopbarAppEntries: View {
    @EnvironmentObject private var appState: AppCoordinator
    // Observed so the entries' labels are re-read when the language changes.
    @EnvironmentObject private var localization: AppLocalizationStore
    var showsCommandPanel: Bool = false
    var iconColor: Color? = nil
    var openIconColor: Color? = nil
    var hoverBackground: Color = WorkbenchRedesignColors.bgHover
    var pressedBackground: Color = WorkbenchRedesignColors.bgPressed
    var openBackground: Color? = nil
    var countBackground: Color = WorkbenchRedesignColors.badgeNeutralBg
    var countTextColor: Color = WorkbenchRedesignColors.textSecondary
    var isCommandPanelFocused: Bool = false
    var isTaskFocused: Bool = false
    var isSettingsFocused: Bool = false

    var body: some View {
        HStack(spacing: WorkbenchControlMetrics.redesignSpacing1) {
            if showsCommandPanel {
                CommandPanelEntryButton(
                    playback: appState.playback,
                    iconColor: iconColor,
                    openIconColor: openIconColor,
                    hoverBackground: hoverBackground,
                    pressedBackground: pressedBackground,
                    openBackground: openBackground,
                    isFocused: isCommandPanelFocused
                ) {
                    appState.performUserInitiatedAppCommand {
                        _ = appState.presentPlaybackCommandPanel()
                    }
                }
                .playerInteractiveRegion()
            }

            TaskEntryButton(
                tasks: appState.tasks,
                iconColor: iconColor,
                openIconColor: openIconColor,
                hoverBackground: hoverBackground,
                pressedBackground: pressedBackground,
                openBackground: openBackground,
                countBackground: countBackground,
                countTextColor: countTextColor,
                isFocused: isTaskFocused
            ) {
                appState.performUserInitiatedAppCommand {
                    appState.tasks.openPanel()
                }
            }
            .playerInteractiveRegion()

            SettingsEntryButton(
                layoutState: appState.workbenchLayout,
                iconColor: iconColor,
                openIconColor: openIconColor,
                hoverBackground: hoverBackground,
                pressedBackground: pressedBackground,
                openBackground: openBackground,
                isFocused: isSettingsFocused
            ) {
                appState.performUserInitiatedAppCommand {
                    NotificationCenter.default.post(name: .cueSeekerShowSettings, object: nil)
                }
            }
            .playerInteractiveRegion()
        }
    }
}

struct CommandPanelEntryButton: View {
    @ObservedObject var playback: PlaybackStore
    var iconColor: Color? = nil
    var openIconColor: Color? = nil
    var hoverBackground: Color = WorkbenchRedesignColors.bgHover
    var pressedBackground: Color = WorkbenchRedesignColors.bgPressed
    var openBackground: Color? = nil
    var isFocused: Bool = false
    let onOpen: () -> Void

    var body: some View {
        WorkbenchIconButton(
            icon: .magnifyingGlass,
            isOpen: playback.commandPanelPresentation != nil,
            isFocused: isFocused,
            hoverBackground: hoverBackground,
            pressedBackground: pressedBackground,
            openBackground: openBackground,
            iconColor: iconColor,
            openIconColor: openIconColor,
            action: onOpen
        )
        .workbenchTooltip(
            scenarioID: "topbar.entry.command_panel",
            label: L("settings.shortcuts.action.openCommandPanel"),
            shortcut: .action(.openCommandPanel)
        )
        .accessibilityLabel(L("settings.shortcuts.action.openCommandPanel"))
        .accessibilityIdentifier("topbar-command-panel-button")
    }
}

/// The Settings window's entry. It is the Task entry's component and states:
/// an Icon Button that stays lit for as long as the window it opens is open,
/// including while that window sits in the Dock. Like the Task entry it
/// observes the store that carries its state, handed to it by the caller.
struct SettingsEntryButton: View {
    @ObservedObject var layoutState: WorkbenchLayoutState
    var iconColor: Color? = nil
    var openIconColor: Color? = nil
    var hoverBackground: Color = WorkbenchRedesignColors.bgHover
    var pressedBackground: Color = WorkbenchRedesignColors.bgPressed
    var openBackground: Color? = nil
    var isFocused: Bool = false
    let onOpen: () -> Void

    var body: some View {
        WorkbenchIconButton(
            icon: .gear,
            isOpen: layoutState.isSettingsWindowOpen,
            isFocused: isFocused,
            hoverBackground: hoverBackground,
            pressedBackground: pressedBackground,
            openBackground: openBackground,
            iconColor: iconColor,
            openIconColor: openIconColor,
            action: onOpen
        )
        .workbenchTooltip(
            scenarioID: "topbar.entry.settings",
            label: L("topbar.settings"),
            shortcut: .fixed("⌘,")
        )
        .accessibilityLabel(L("topbar.settings"))
        .accessibilityIdentifier("topbar-settings-button")
    }
}
