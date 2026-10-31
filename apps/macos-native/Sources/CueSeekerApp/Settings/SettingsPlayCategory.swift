import SwiftUI

/// Settings / Play's Play group.
struct SettingsPlayCategory: View {
    // Observed so the copy below is re-read when the language changes.
    @EnvironmentObject private var localization: AppLocalizationStore
    @EnvironmentObject private var settingsStore: SettingsStore
    @State private var gapDraft = ""
    @FocusState private var isGapFieldFocused: Bool

    var body: some View {
        WorkbenchAccessibilityReader { accessibility in
            SettingsGroup(title: L("settings.category.play")) {
                SettingsRow(L("settings.play.auto_pause")) {
                    Toggle("", isOn: $settingsStore.autoPauseAfterCueFinishesEnabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .focusable(false)
                        .workbenchAccessibilityFocusRing(
                            isFocused: accessibility?.isSettingsFocused(.playAutoPause) == true,
                            isCapsule: true
                        )
                }

                SettingsRowDivider()

                SettingsRow(L("settings.play.auto_switch")) {
                    Toggle("", isOn: $settingsStore.autoSwitchToNextCuesInPlaylistEnabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .focusable(false)
                        .disabled(!settingsStore.autoPauseAfterCueFinishesEnabled)
                        .workbenchAccessibilityFocusRing(
                            isFocused: accessibility?.isSettingsFocused(.playAutoSwitch) == true,
                            isCapsule: true
                        )
                        .workbenchTooltip(
                            scenarioID: "disabled.settings.play.auto_switch",
                            surface: .settings,
                            isActive: !settingsStore.autoPauseAfterCueFinishesEnabled,
                            label: L("tooltip.disabled.settings.play.auto_switch")
                        )
                }

                SettingsRowDivider()

                SettingsRow(L("settings.play.auto_switch_gap")) {
                    WorkbenchNumberField(
                        placeholder: "\(SettingsStore.autoSwitchCueSequenceGapDefaultMilliseconds)",
                        text: Binding(
                            get: { gapDraft },
                            set: { newValue in
                                gapDraft = newValue
                                applyGapDraftChange(newValue)
                            }
                        ),
                        unit: "ms",
                        focus: $isGapFieldFocused,
                        normalizeDraft: Self.normalizeGapDraft,
                        onEditingEnded: commitGapDraft,
                        onSubmit: commitGapDraft,
                        settingsInputKind: .numberField(.autoSwitchGap)
                    )
                    .frame(width: WorkbenchControlMetrics.redesignSettingsNumberFieldWidth)
                }
            }
        }
        .onAppear {
            syncGapDraftFromStore()
        }
        .onDisappear {
            commitGapDraft()
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

    static func normalizeGapDraft(_ draft: String) -> String {
        WorkbenchNumberField.normalizeIntegerDraft(
            draft,
            maximum: SettingsStore.autoSwitchCueSequenceGapMaximumMilliseconds
        )
    }

    private func applyGapDraftChange(_ draft: String) {
        let normalizedDraft = Self.normalizeGapDraft(draft)
        guard normalizedDraft == draft else {
            gapDraft = normalizedDraft
            return
        }

        guard let milliseconds = Int(normalizedDraft) else {
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
