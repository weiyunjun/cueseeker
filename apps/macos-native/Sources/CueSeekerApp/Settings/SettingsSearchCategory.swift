import SwiftUI

struct SettingsSearchCategory: View {
    @EnvironmentObject private var settingsStore: SettingsStore
    @EnvironmentObject private var cueGroupPresentation: CueGroupPresentationStore

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Search")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Choose default filters for regular Search results.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 16) {
                    Text("Primary Search Language")
                        .font(.headline)

                    Spacer()

                    Picker("Primary Search Language", selection: $settingsStore.primarySearchLanguage) {
                        ForEach(PrimarySearchLanguage.allCases) { language in
                            Text(language.displayName)
                                .tag(language)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 180)
                }

                HStack(spacing: 16) {
                    Text("Search Scope")
                        .font(.headline)

                    Spacer()

                    Picker("Search Scope", selection: $settingsStore.searchScope) {
                        ForEach(SearchScope.allCases) { scope in
                            Text(scope.displayName)
                                .tag(scope)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 180)
                }

                HStack(spacing: 16) {
                    Text("Show Cue Group")
                        .font(.headline)

                    Spacer()

                    Toggle("Show Cue Group", isOn: Binding(
                        get: { cueGroupPresentation.isEnabled },
                        set: { cueGroupPresentation.setFromUser($0) }
                    ))
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .accessibilityIdentifier("settings.search.show-cue-group")
                }
            }

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(WorkbenchRedesignColors.bgSurface)
    }
}
