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

                WorkbenchSegmentedControl(
                    options: PlaybackDecodeMode.allCases,
                    selection: $settingsStore.playbackDecodeMode,
                    title: Self.displayName(for:),
                    accessibilityLabel: { L("settings.decode.accessibility", Self.displayName(for: $0)) }
                )
            }

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(WorkbenchRedesignColors.bgSurface)
    }

    /// The playback module only knows the raw mode, so the human-readable name
    /// is resolved here in the interface layer.
    private static func displayName(for mode: PlaybackDecodeMode) -> String {
        switch mode {
        case .hardware:
            L("settings.decode.hardware")
        case .software:
            L("settings.decode.software")
        case .auto:
            L("settings.decode.auto")
        }
    }
}
