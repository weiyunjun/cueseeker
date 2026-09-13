import SwiftUI

/// Settings / Play's Play group.
struct SettingsPlayCategory: View {
    // Observed so the copy below is re-read when the language changes.
    @EnvironmentObject private var localization: AppLocalizationStore
    @EnvironmentObject private var settingsStore: SettingsStore
    @State private var gapDraft = ""
    @FocusState private var isGapFieldFocused: Bool

    var body: some View {
        SettingsGroup(title: L("settings.category.play")) {
            SettingsRow(L("settings.play.auto_pause")) {
                Toggle("", isOn: $settingsStore.autoPauseAfterCueFinishesEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .focusable(false)
            }

            SettingsRowDivider()

            SettingsRow(L("settings.play.auto_switch")) {
                Toggle("", isOn: $settingsStore.autoSwitchToNextCuesInPlaylistEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .focusable(false)
                    .disabled(!settingsStore.autoPauseAfterCueFinishesEnabled)
            }

            SettingsRowDivider()

            SettingsRow(L("settings.play.auto_switch_gap")) {
                WorkbenchNumberField(
                    placeholder: "\(SettingsStore.autoSwitchCueSequenceGapDefaultMilliseconds)",
                    text: $gapDraft,
                    unit: "ms",
                    focus: $isGapFieldFocused
                )
                .frame(width: WorkbenchControlMetrics.redesignSettingsNumberFieldWidth)
            }
        }
        .onAppear {
            syncGapDraftFromStore()
        }
        .onChange(of: gapDraft) { draft in
            applyGapDraftChange(draft)
        }
        .onChange(of: isGapFieldFocused) { isFocused in
            if !isFocused {
                commitGapDraft()
            }
        }
        .onChange(of: settingsStore.autoSwitchCueSequenceGapMilliseconds) { _ in
            if !isGapFieldFocused {
                syncGapDraftFromStore()
            }
        }
    }

    private func applyGapDraftChange(_ draft: String) {
        let numericDraft = draft.filter(\.isNumber)
        guard numericDraft == draft else {
            gapDraft = numericDraft
            return
        }

        guard let milliseconds = Int(numericDraft) else {
            return
        }

        let clampedMilliseconds = SettingsStore.clampedAutoSwitchCueSequenceGapMilliseconds(milliseconds)
        settingsStore.setAutoSwitchCueSequenceGapMilliseconds(clampedMilliseconds)
        if milliseconds != clampedMilliseconds {
            gapDraft = String(clampedMilliseconds)
        }
    }

    private func commitGapDraft() {
        guard let milliseconds = Int(gapDraft) else {
            syncGapDraftFromStore()
            return
        }

        let clampedMilliseconds = SettingsStore.clampedAutoSwitchCueSequenceGapMilliseconds(milliseconds)
        settingsStore.setAutoSwitchCueSequenceGapMilliseconds(clampedMilliseconds)
        gapDraft = String(clampedMilliseconds)
    }

    private func syncGapDraftFromStore() {
        gapDraft = String(settingsStore.autoSwitchCueSequenceGapMilliseconds)
    }
}
