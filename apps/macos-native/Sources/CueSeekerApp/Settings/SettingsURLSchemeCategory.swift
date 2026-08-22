import SwiftUI

struct SettingsURLSchemeCategory: View {
    // Observed so the copy below is re-read when the language changes.
    @EnvironmentObject private var localization: AppLocalizationStore
    @EnvironmentObject private var settingsStore: SettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Deep Link")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text(L("settings.deep_link.description"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L("settings.deep_link.play_first"))
                        .font(.headline)
                    Text(L("settings.deep_link.play_first_note"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Toggle(
                    L("settings.deep_link.play_first"),
                    isOn: $settingsStore.urlSchemePlayFirstSearchResultEnabled
                )
                .labelsHidden()
                .toggleStyle(.switch)
                .accessibilityIdentifier("settings.url-scheme.play-first-search-result")
            }

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(WorkbenchRedesignColors.bgSurface)
    }
}
