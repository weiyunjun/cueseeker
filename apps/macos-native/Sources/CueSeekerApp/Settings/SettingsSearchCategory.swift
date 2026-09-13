import SwiftUI

/// Settings / General's Search group.
struct SettingsSearchCategory: View {
    // Observed so the copy below is re-read when the language changes.
    @EnvironmentObject private var localization: AppLocalizationStore
    @EnvironmentObject private var settingsStore: SettingsStore
    @EnvironmentObject private var cueGroupPresentation: CueGroupPresentationStore

    var body: some View {
        SettingsGroup(
            title: L("settings.category.search"),
            description: L("settings.search.description")
        ) {
            SettingsRow(L("settings.search.show_cue_group")) {
                Toggle(L("settings.search.show_cue_group"), isOn: Binding(
                    get: { cueGroupPresentation.isEnabled },
                    set: { cueGroupPresentation.setFromUser($0) }
                ))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .focusable(false)
                    .accessibilityIdentifier("settings.search.show-cue-group")
            }

            SettingsRowDivider()

            SettingsRow(
                L("settings.search.prefill"),
                note: L("settings.search.prefill_note")
            ) {
                Toggle(
                    L("settings.search.prefill"),
                    isOn: $settingsStore.prefillCommandPanelWithFocusedCue
                )
                .labelsHidden()
                .toggleStyle(.switch)
                .focusable(false)
                .accessibilityIdentifier(
                    "settings.search.prefill-command-panel-with-focused-cue"
                )
            }
        }
    }
}
