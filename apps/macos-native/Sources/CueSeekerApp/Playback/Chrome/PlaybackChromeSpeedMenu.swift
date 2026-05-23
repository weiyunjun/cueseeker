import SwiftUI

struct PlaybackChromeSpeedMenu: View {
    let selectedSpeed: Double
    var suppressesInteraction = false
    let onSelect: (Double) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(PlaybackViewModel.speedPresets, id: \.self) { speed in
                Button {
                    guard !suppressesInteraction else {
                        return
                    }
                    onSelect(speed)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .opacity(abs(selectedSpeed - speed) < 0.01 ? 1 : 0)
                            .frame(width: 14)

                        Text(PlaybackViewModel.formatSpeed(speed))
                            .font(.system(size: 13, weight: abs(selectedSpeed - speed) < 0.01 ? .bold : .medium))
                            .monospacedDigit()

                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(.white.opacity(0.94))
                    .padding(.horizontal, 8)
                    .frame(width: 160, height: 30)
                    .contentShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(
                    PlaybackChromeMenuButtonStyle(
                        isSelected: abs(selectedSpeed - speed) < 0.01,
                        suppressesInteraction: suppressesInteraction
                    )
                )
            }
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(PlaybackTheme.cinematicBacking)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(PlaybackTheme.textTertiary.opacity(0.3), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.42), radius: 24, y: 12)
    }
}

private struct PlaybackChromeMenuButtonStyle: ButtonStyle {
    let isSelected: Bool
    let suppressesInteraction: Bool
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(backgroundColor(isPressed: configuration.isPressed))
            )
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .onHover { isHovered = suppressesInteraction ? false : $0 }
            .onChange(of: suppressesInteraction) { isSuppressed in
                if isSuppressed {
                    isHovered = false
                }
            }
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        if !suppressesInteraction && (isPressed || isHovered || isSelected) {
            return PlaybackTheme.menuItemHighlight
        }
        return .clear
    }
}
