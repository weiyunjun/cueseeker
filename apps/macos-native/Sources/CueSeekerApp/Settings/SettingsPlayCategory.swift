import SwiftUI

struct SettingsPlayCategory: View {
    // Observed so the copy below is re-read when the language changes.
    @EnvironmentObject private var localization: AppLocalizationStore
    @EnvironmentObject private var settingsStore: SettingsStore
    @State private var gapDraft = ""
    @FocusState private var isGapFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text(L("settings.category.play"))
                    .font(.title2)
                    .fontWeight(.semibold)
            }

            HStack(spacing: 16) {
                Text(L("settings.play.auto_pause"))
                    .font(.headline)

                Spacer()

                Toggle("", isOn: $settingsStore.autoPauseAfterCueFinishesEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .focusable(false)
            }

            HStack(spacing: 16) {
                Text(L("settings.play.auto_switch"))
                    .font(.headline)

                Spacer()

                Toggle("", isOn: $settingsStore.autoSwitchToNextCuesInPlaylistEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .focusable(false)
                    .disabled(!settingsStore.autoPauseAfterCueFinishesEnabled)
            }

            HStack(spacing: 16) {
                Text(L("settings.play.auto_switch_gap"))
                    .font(.headline)

                Spacer()

                WorkbenchNumberField(
                    placeholder: "\(SettingsStore.autoSwitchCueSequenceGapDefaultMilliseconds)",
                    text: $gapDraft,
                    unit: "ms",
                    focus: $isGapFieldFocused
                )
                .frame(width: 114)
            }

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(WorkbenchRedesignColors.bgSurface)
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
