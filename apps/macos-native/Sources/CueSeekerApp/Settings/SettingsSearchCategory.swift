import SwiftUI

struct SettingsSearchCategory: View {
    @EnvironmentObject private var settingsStore: SettingsStore
    @EnvironmentObject private var cueGroupPresentation: CueGroupPresentationStore

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Search")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Choose how cues are presented in Search.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 16) {
                    Text("Show Cue Group")
                        .font(.headline)

                    Spacer()

                    Toggle("Show Cue Group", isOn: Binding(
                        get: { cueGroupPresentation.isEnabled },
                        set: { cueGroupPresentation.setFromUser($0) }
                    ))
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .accessibilityIdentifier("settings.search.show-cue-group")
                }

                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Prefill with Focused Cue")
                            .font(.headline)
                        Text(
                            "Automatically fill the Command Panel with the focused cue when opened from Playback Overlay."
                        )
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Toggle(
                        "Prefill with Focused Cue",
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
