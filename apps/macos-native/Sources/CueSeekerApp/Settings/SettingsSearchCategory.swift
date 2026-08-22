import SwiftUI

struct SettingsSearchCategory: View {
    // Observed so the copy below is re-read when the language changes.
    @EnvironmentObject private var localization: AppLocalizationStore
    @EnvironmentObject private var settingsStore: SettingsStore
    @EnvironmentObject private var cueGroupPresentation: CueGroupPresentationStore

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text(L("settings.category.search"))
                    .font(.title2)
                    .fontWeight(.semibold)
                Text(L("settings.search.description"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 16) {
                    Text(L("settings.search.show_cue_group"))
                        .font(.headline)

                    Spacer()

                    Toggle(L("settings.search.show_cue_group"), isOn: Binding(
                        get: { cueGroupPresentation.isEnabled },
                        set: { cueGroupPresentation.setFromUser($0) }
                    ))
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .accessibilityIdentifier("settings.search.show-cue-group")
                }

                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L("settings.search.prefill"))
                            .font(.headline)
                        Text(
                            L("settings.search.prefill_note")
                        )
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Toggle(
                        L("settings.search.prefill"),
                        isOn: $settingsStore.prefillCommandPanelWithFocusedCue
                    )
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .accessibilityIdentifier(
                        "settings.search.prefill-command-panel-with-focused-cue"
                    )
                }
            }

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(WorkbenchRedesignColors.bgSurface)
    }
}
