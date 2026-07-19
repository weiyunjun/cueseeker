import SwiftUI

struct SettingsAppearanceCategory: View {
    @EnvironmentObject private var settingsStore: SettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Appearance")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Choose how CueSeeker follows light and dark mode.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Appearance Mode")
                        .font(.headline)
                    Text("Auto follows the current macOS system appearance.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                AppearanceModeSegmentedControl(selection: $settingsStore.appAppearanceMode)
            }

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(WorkbenchRedesignColors.bgSurface)
    }
}

private struct AppearanceModeSegmentedControl: View {
    @Binding var selection: AppAppearanceMode

    var body: some View {
        HStack(spacing: 2) {
            ForEach(AppAppearanceMode.allCases) { mode in
                let isSelected = selection == mode

                Button {
                    selection = mode
                } label: {
                    Text(mode.displayName)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                        .frame(width: 72, height: 26)
                        .foregroundStyle(isSelected ? Color.white : Color.primary)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(isSelected ? Color.accentColor : Color.clear)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Appearance \(mode.displayName)")
                .accessibilityValue(isSelected ? "Selected" : "Not selected")
            }
        }
        .padding(3)
        .background(Color(nsColor: .controlBackgroundColor))
        .overlay {
            RoundedRectangle(cornerRadius: 7)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 7))
    }
}
