import SwiftUI

struct SettingsAppearanceCategory: View {
    // Observed so the copy below is re-read when the language changes.
    @EnvironmentObject private var localization: AppLocalizationStore
    @EnvironmentObject private var settingsStore: SettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text(L("settings.category.appearance"))
                    .font(.title2)
                    .fontWeight(.semibold)
                Text(L("settings.appearance.description"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L("settings.appearance.mode"))
                        .font(.headline)
                    Text(L("settings.appearance.note"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                WorkbenchSegmentedControl(
                    options: AppAppearanceMode.allCases,
                    selection: $settingsStore.appAppearanceMode,
                    title: \.displayName,
                    accessibilityLabel: { L("settings.appearance.accessibility", $0.displayName) }
                )
            }

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(WorkbenchRedesignColors.bgSurface)
    }
}
