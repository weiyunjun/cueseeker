import CueSeekerPlayback
import SwiftUI

/// Settings / Play's Decode group.
struct SettingsDecodeCategory: View {
    // Observed so the copy below is re-read when the language changes.
    @EnvironmentObject private var localization: AppLocalizationStore
    @EnvironmentObject private var settingsStore: SettingsStore

    var body: some View {
        SettingsGroup(
            title: L("settings.category.decode"),
            description: L("settings.decode.description")
        ) {
            SettingsRow(
                L("settings.decode.decoder"),
                note: L("settings.decode.note")
            ) {
                WorkbenchSegmentedControl(
                    options: PlaybackDecodeMode.allCases,
                    selection: $settingsStore.playbackDecodeMode,
                    title: Self.displayName(for:),
                    accessibilityLabel: { L("settings.decode.accessibility", Self.displayName(for: $0)) }
                )
            }
        }
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
