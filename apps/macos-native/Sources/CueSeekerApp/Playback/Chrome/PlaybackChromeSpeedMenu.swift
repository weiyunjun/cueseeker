import SwiftUI

struct PlaybackChromeSpeedMenu: View {
    let selectedSpeed: Double
    var suppressesInteraction = false
    let onSelect: (Double) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: PlaybackChromeMetrics.speedMenuItemVerticalGap) {
            ForEach(PlaybackViewModel.speedPresets, id: \.self) { speed in
                Button {
                    guard !suppressesInteraction else {
                        return
                    }
                    onSelect(speed)
                } label: {
                    HStack(spacing: PlaybackChromeMetrics.speedMenuItemContentGap) {
                        Image(systemName: "checkmark")
                            .font(.system(size: PlaybackChromeMetrics.speedMenuCheckFontSize, weight: .bold))
                            .opacity(abs(selectedSpeed - speed) < 0.01 ? 1 : 0)
                            .frame(width: PlaybackChromeMetrics.speedMenuCheckColumnWidth)

                        Text(PlaybackViewModel.formatSpeed(speed))
                            .font(.system(
                                size: PlaybackChromeMetrics.speedMenuItemFontSize,
                                weight: abs(selectedSpeed - speed) < 0.01 ? .bold : .medium
                            ))
                            .monospacedDigit()

                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(PlaybackTheme.textPrimary)
                    .padding(.horizontal, PlaybackChromeMetrics.speedMenuItemHorizontalPadding)
                    .frame(
                        width: PlaybackChromeMetrics.speedMenuItemWidth,
                        height: PlaybackChromeMetrics.speedMenuItemHeight
                    )
                    .contentShape(RoundedRectangle(cornerRadius: PlaybackChromeMetrics.speedMenuItemRadius))
                }
                .buttonStyle(
                    PlaybackChromeMenuButtonStyle(
                        isSelected: abs(selectedSpeed - speed) < 0.01,
                        suppressesInteraction: suppressesInteraction
                    )
                )
            }
        }
        .padding(PlaybackChromeMetrics.speedMenuPadding)
        .background(
            RoundedRectangle(cornerRadius: PlaybackChromeMetrics.speedMenuRadius)
                .fill(PlaybackTheme.menuBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: PlaybackChromeMetrics.speedMenuRadius)
                .strokeBorder(PlaybackTheme.textTertiary.opacity(0.3), lineWidth: 0.5)
        )
        .shadow(
            color: PlaybackTheme.overlayShadowColor,
            radius: PlaybackTheme.overlayShadowRadius,
            y: PlaybackTheme.overlayShadowYOffset
        )
    }
}

private struct PlaybackChromeMenuButtonStyle: ButtonStyle {
    let isSelected: Bool
    let suppressesInteraction: Bool
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: PlaybackChromeMetrics.speedMenuItemRadius)
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
            return PlaybackTheme.menuItemHoverBackground
        }
        return .clear
    }
}
