import SwiftUI

struct SettingsLanguageCategory: View {
    @EnvironmentObject private var localization: AppLocalizationStore

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text(L("settings.category.language"))
                    .font(.title2)
                    .fontWeight(.semibold)
                Text(L("settings.language.description"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 16) {
                Text(L("settings.language.field"))
                    .font(.headline)

                Spacer()

                Picker("", selection: selection) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.displayName).tag(language)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 180)
            }

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(WorkbenchRedesignColors.bgSurface)
    }

    private var selection: Binding<AppLanguage> {
        Binding(
            get: { localization.language },
            set: { localization.set($0) }
        )
    }
}
