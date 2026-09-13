import SwiftUI

/// Settings / General's Language group.
struct SettingsLanguageCategory: View {
    @EnvironmentObject private var localization: AppLocalizationStore

    var body: some View {
        SettingsGroup(
            title: L("settings.category.language"),
            description: L("settings.language.description")
        ) {
            SettingsRow(L("settings.language.field")) {
                Picker("", selection: selection) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.displayName).tag(language)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .focusable(false)
                .frame(width: WorkbenchControlMetrics.redesignSettingsPopupWidth)
            }
        }
    }

    private var selection: Binding<AppLanguage> {
        Binding(
            get: { localization.language },
            set: { localization.set($0) }
        )
    }
}
