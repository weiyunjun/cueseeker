import SwiftUI

/// Settings / General's Deep Link group.
struct SettingsURLSchemeCategory: View {
    // Observed so the copy below is re-read when the language changes.
    @EnvironmentObject private var localization: AppLocalizationStore
    @EnvironmentObject private var settingsStore: SettingsStore

    var body: some View {
        SettingsGroup(
            title: "Deep Link",
            description: L("settings.deep_link.description")
        ) {
            SettingsRow(
                L("settings.deep_link.play_first"),
                note: L("settings.deep_link.play_first_note")
            ) {
                Toggle(
                    L("settings.deep_link.play_first"),
                    isOn: $settingsStore.urlSchemePlayFirstSearchResultEnabled
                )
                .labelsHidden()
                .toggleStyle(.switch)
                .focusable(false)
                .accessibilityIdentifier("settings.url-scheme.play-first-search-result")
            }
        }
    }
}
