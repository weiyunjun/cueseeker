import CueSeekerPlayback
import SwiftUI

struct SettingsDecodeCategory: View {
    @EnvironmentObject private var settingsStore: SettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Decode")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Choose the video decode mode used by playback.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Decoder")
                        .font(.headline)
                    Text("Applies to newly opened playback sessions.")
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
        .background(Color.white)
    }
}

private struct DecodeModeSegmentedControl: View {
    @Binding var selection: PlaybackDecodeMode

    var body: some View {
        HStack(spacing: 2) {
            ForEach(PlaybackDecodeMode.allCases) { mode in
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
                .accessibilityLabel("Decoder \(mode.displayName)")
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
