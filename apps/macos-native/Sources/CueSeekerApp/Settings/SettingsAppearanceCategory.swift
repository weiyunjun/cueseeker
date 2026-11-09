import SwiftUI

/// Settings / General's Appearance group.
struct SettingsAppearanceCategory: View {
    // Observed so the copy below is re-read when the language changes.
    @EnvironmentObject private var localization: AppLocalizationStore
    @EnvironmentObject private var settingsStore: SettingsStore

    var body: some View {
        WorkbenchAccessibilityReader { accessibility in
            SettingsGroup(title: L("settings.category.appearance")) {
                SettingsRow(L("settings.appearance.mode")) {
                    WorkbenchSegmentedControl(
                        options: AppAppearanceMode.allCases,
                        selection: $settingsStore.appAppearanceMode,
                        title: \.displayName,
                        accessibilityLabel: { L("settings.appearance.accessibility", $0.displayName) },
                        focusedOption: AppAppearanceMode.allCases.first { mode in
                            accessibility?.isSettingsFocused(.appearanceMode(mode)) == true
                        }
                    )
                }

                SettingsRowDivider()

                SettingsRow(L("settings.appearance.hdr_screenshot")) {
                    Toggle("", isOn: $settingsStore.hdrScreenshotEnabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .focusable(false)
                        .workbenchAccessibilityFocusRing(
                            isFocused: accessibility?.isSettingsFocused(.hdrScreenshot) == true,
                            isCapsule: true
                        )
                }
            }
        }
    }
}
