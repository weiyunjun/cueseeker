import SwiftUI

struct PlaybackChromeSpeedMenu: View {
    let selectedSpeed: Double
    var suppressesInteraction = false
    @ObservedObject var highlight: MenuHighlightModel
    let onSelect: (Double) -> Void

    var body: some View {
        MenuItemStack(
            padding: MenuMetrics.padding,
            strip: 0,
            cap: .infinity
        ) {
            VStack(alignment: .leading, spacing: 0) {
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
                        HStack(spacing: WorkbenchControlMetrics.redesignSpacing2) {
                            AppIconImage(
                                .check,
                                size: WorkbenchControlMetrics.redesignSelectIndicatorSymbolFontSizeMacOS
                            )
                            .opacity(abs(selectedSpeed - speed) < 0.01 ? 1 : 0)
                            .frame(
                                width: WorkbenchControlMetrics.redesignSelectIndicatorSymbolFontSizeMacOS,
                                height: WorkbenchControlMetrics.redesignSelectIndicatorSymbolFontSizeMacOS
                            )

                            Text(PlaybackViewModel.formatSpeed(speed))
                                .font(.system(
                                    size: WorkbenchControlMetrics.redesignFontSizeControl,
                                    weight: .medium
                                ))
                                .monospacedDigit()

                            Spacer(minLength: 0)
                        }
                        .foregroundStyle(PlaybackTheme.textPrimary)
                        .padding(.horizontal, WorkbenchControlMetrics.redesignMenuItemHorizontalPadding)
                        .frame(maxWidth: .infinity)
                        .frame(height: WorkbenchControlMetrics.redesignMenuItemHeight)
                        .contentShape(
                            RoundedRectangle(
                                cornerRadius: WorkbenchControlMetrics.redesignMenuItemRadius,
                                style: .continuous
                            )
                        )
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
                    .playerInteractiveRegion()
                }
            }
        }
        .background(
            RoundedRectangle(
                cornerRadius: WorkbenchControlMetrics.redesignMenuRadius,
                style: .continuous
            )
            .fill(PlaybackTheme.menuBackground)
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: WorkbenchControlMetrics.redesignMenuRadius,
                style: .continuous
            )
            .strokeBorder(PlaybackTheme.textTertiary.opacity(0.3), lineWidth: 0.5)
        )
        .shadow(
            color: PlaybackTheme.overlayShadowColor,
            radius: PlaybackTheme.overlayShadowRadius,
            y: PlaybackTheme.overlayShadowYOffset
        )
    }
}

/// A Player Chrome menu item: only the menu's highlight paints a background.
struct PlaybackChromeMenuButtonStyle: ButtonStyle {
    let isHighlighted: Bool
    let suppressesInteraction: Bool
    let onHoverChange: (Bool) -> Void

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(
                    cornerRadius: WorkbenchControlMetrics.redesignMenuItemRadius,
                    style: .continuous
                )
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
