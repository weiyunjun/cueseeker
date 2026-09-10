import SwiftUI

struct PlaybackChromeSpeedMenu: View {
    let selectedSpeed: Double
    var suppressesInteraction = false
    @ObservedObject var highlight: MenuHighlightModel
    let onSelect: (Double) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: PlaybackChromeMetrics.speedMenuItemVerticalGap) {
            ForEach(
                Array(PlaybackViewModel.speedPresets.enumerated()),
                id: \.element
            ) { position, speed in
                Button {
                    guard !suppressesInteraction else {
                        return
                    }
                    onSelect(speed)
                } label: {
                    HStack(spacing: PlaybackChromeMetrics.speedMenuItemContentGap) {
                        AppIconImage(.check, size: PlaybackChromeMetrics.speedMenuCheckFontSize)
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
                        isHighlighted: highlight.highlightedPosition == position,
                        suppressesInteraction: suppressesInteraction,
                        onHoverChange: { isHovered in
                            highlight.noteHover(isHovered, at: position)
                        }
                    )
                )
                .focusable(false)
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
    let isHighlighted: Bool
    let suppressesInteraction: Bool
    let onHoverChange: (Bool) -> Void

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: PlaybackChromeMetrics.speedMenuItemRadius)
                    .fill(backgroundColor)
            )
            .onHover { isHovered in
                onHoverChange(suppressesInteraction ? false : isHovered)
            }
            .onChange(of: suppressesInteraction) { isSuppressed in
                if isSuppressed {
                    onHoverChange(false)
                }
            }
    }

    /// Only the menu's highlight paints a background. The item in effect is
    /// marked by its check mark, so the highlight is free to move away from it.
    private var backgroundColor: Color {
        if !suppressesInteraction && isHighlighted {
            return PlaybackTheme.menuItemHoverBackground
        }
        return .clear
    }
}
