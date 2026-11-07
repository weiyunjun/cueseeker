import SwiftUI

/// Settings / General's Deep Link group.
struct SettingsURLSchemeCategory: View {
    // Observed so the copy below is re-read when the language changes.
    @EnvironmentObject private var localization: AppLocalizationStore
    @EnvironmentObject private var settingsStore: SettingsStore

    var body: some View {
        WorkbenchAccessibilityReader { accessibility in
            SettingsGroup(title: "Deep Link") {
                SettingsRow(L("settings.deep_link.play_first")) {
                    Toggle(
                        L("settings.deep_link.play_first"),
                        isOn: $settingsStore.urlSchemePlayFirstSearchResultEnabled
                    )
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .focusable(false)
                    .workbenchAccessibilityFocusRing(
                        isFocused: accessibility?.isSettingsFocused(.deepLinkPlayFirstSearchResult) == true,
                        isCapsule: true
                    )
                    .accessibilityIdentifier("settings.url-scheme.play-first-search-result")
                }
            }
        }
    }
}
