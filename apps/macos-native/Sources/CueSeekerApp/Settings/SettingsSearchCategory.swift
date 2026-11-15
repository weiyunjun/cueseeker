import SwiftUI

/// Settings / General's Search group.
struct SettingsSearchCategory: View {
    // Observed so the copy below is re-read when the language changes.
    @EnvironmentObject private var localization: AppLocalizationStore
    @EnvironmentObject private var cueGroupPresentation: CueGroupPresentationStore

    var body: some View {
        WorkbenchAccessibilityReader { accessibility in
            SettingsGroup(title: L("settings.category.search")) {
                SettingsRow(L("settings.search.show_cue_group")) {
                    Toggle(L("settings.search.show_cue_group"), isOn: Binding(
                        get: { cueGroupPresentation.isEnabled },
                        set: { cueGroupPresentation.setFromUser($0) }
                    ))
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .focusable(false)
                        .workbenchAccessibilityFocusRing(
                            isFocused: accessibility?.isSettingsFocused(.searchShowCueGroup) == true,
                            isCapsule: true
                        )
                        .accessibilityIdentifier("settings.search.show-cue-group")
                }
            }
        }
    }
}
