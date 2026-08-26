import CueSeekerPlayback
import SwiftUI

struct SettingsDecodeCategory: View {
    // Observed so the copy below is re-read when the language changes.
    @EnvironmentObject private var localization: AppLocalizationStore
    @EnvironmentObject private var settingsStore: SettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text(L("settings.category.decode"))
                    .font(.title2)
                    .fontWeight(.semibold)
                Text(L("settings.decode.description"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L("settings.decode.decoder"))
                        .font(.headline)
                    Text(L("settings.decode.note"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                DecodeModeSegmentedControl(selection: $settingsStore.playbackDecodeMode)
            }

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(WorkbenchRedesignColors.bgSurface)
    }
}

private struct DecodeModeSegmentedControl: View {
    @Binding var selection: PlaybackDecodeMode

    /// The playback module only knows the raw mode, so the human-readable name
    /// is resolved here in the interface layer.
    static func displayName(for mode: PlaybackDecodeMode) -> String {
        switch mode {
        case .hardware:
            L("settings.decode.hardware")
        case .software:
            L("settings.decode.software")
        case .auto:
            L("settings.decode.auto")
        }
    }

    var body: some View {
        HStack(spacing: 2) {
            ForEach(PlaybackDecodeMode.allCases) { mode in
                let isSelected = selection == mode

                Button {
                    selection = mode
                } label: {
                    Text(Self.displayName(for: mode))
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
                .buttonStyle(StaticButtonStyle())
                .accessibilityLabel(L("settings.decode.accessibility", Self.displayName(for: mode)))
                .accessibilityValue(isSelected ? L("facet.selected") : L("facet.not_selected"))
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
