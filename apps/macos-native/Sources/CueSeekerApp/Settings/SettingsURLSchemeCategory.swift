import SwiftUI

struct SettingsURLSchemeCategory: View {
    @EnvironmentObject private var settingsStore: SettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("URL Scheme")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Choose how CueSeeker handles search links.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Play First Search Result")
                        .font(.headline)
                    Text("Automatically play the first result from the complete first search page.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Toggle(
                    "Play First Search Result",
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
