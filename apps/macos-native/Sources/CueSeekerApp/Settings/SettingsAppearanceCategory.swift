import SwiftUI

/// Settings / General's Appearance group.
struct SettingsAppearanceCategory: View {
    // Observed so the copy below is re-read when the language changes.
    @EnvironmentObject private var localization: AppLocalizationStore
    @EnvironmentObject private var settingsStore: SettingsStore

    var body: some View {
        SettingsGroup(
            title: L("settings.category.appearance"),
            description: L("settings.appearance.description")
        ) {
            SettingsRow(
                L("settings.appearance.mode"),
                note: L("settings.appearance.note")
            ) {
                WorkbenchSegmentedControl(
                    options: AppAppearanceMode.allCases,
                    selection: $settingsStore.appAppearanceMode,
                    title: \.displayName,
                    accessibilityLabel: { L("settings.appearance.accessibility", $0.displayName) }
                )
            }
        }
    }
}
