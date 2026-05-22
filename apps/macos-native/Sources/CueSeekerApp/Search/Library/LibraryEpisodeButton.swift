import SwiftUI

struct LibraryEpisodeButton: View {
    let rank: Int
    let isPlaying: Bool
    let action: () -> Void
    @State private var isHovered = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            Text(episodeLabel)
                .font(.system(size: LibraryLayout.episodeLabelSize, weight: .bold))
                .monospacedDigit()
        }
        .buttonStyle(
            LibraryEpisodeButtonStyle(
                isPlaying: isPlaying,
                isHovered: isHovered,
                tokens: LiquidGlassTokens(colorScheme: colorScheme)
            )
        )
        .onHover { isHovered = $0 }
        .focusable(false)
        .accessibilityLabel("Episode \(rank)")
    }

    // EP01-style compact rank label (finding H / doc 12 §7.2). `%02d` keeps
    // `EP01` at the 66pt minimum width while `EP120` widens its own card.
    private var episodeLabel: String {
        String(format: "EP%02d", rank)
    }
}

/// Library episode tile: the shared `LiquidGlassTokens` card skin drawn
/// directly (doc 11 §5). The Library-launched "playing" state is the doc 12
/// §7.2 mandated indicator (white-elevated fill + 2pt accent outline, no
/// shadow), NOT the shared selectable-card selected treatment.
private struct LibraryEpisodeButtonStyle: ButtonStyle {
    let isPlaying: Bool
    let isHovered: Bool
    let tokens: LiquidGlassTokens

    func makeBody(configuration: Configuration) -> some View {
        let lifted = isHovered && !isPlaying
        let shape = RoundedRectangle(
            cornerRadius: LibraryLayout.episodeCornerRadius,
            style: .continuous
        )

        return configuration.label
            .foregroundStyle(isPlaying ? tokens.textOnSelectedCard : tokens.text)
            .padding(.horizontal, LibraryLayout.episodeHorizontalPadding)
            .frame(minWidth: LibraryLayout.episodeMinWidth)
            .frame(height: LibraryLayout.episodeHeight)
            .background {
                shape
                    .fill(
                        isPlaying
                            ? tokens.playingIndicatorFill
                            : (lifted ? tokens.cardHoverFill : tokens.cardFill)
                    )
                    .overlay {
                        shape.strokeBorder(
                            isPlaying
                                ? tokens.selectedRing
                                : (lifted ? tokens.cardHoverHairline : tokens.cardHairline),
                            lineWidth: isPlaying ? 2 : 0.5
                        )
                    }
                    .shadow(
                        color: isPlaying
                            ? .clear
                            : (lifted ? tokens.cardHoverShadow : tokens.cardShadow),
                        radius: isPlaying ? 0 : (lifted ? 7 : 1.5),
                        x: 0,
                        y: isPlaying ? 0 : (lifted ? 4 : 1)
                    )
            }
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .contentShape(shape)
            .animation(.easeOut(duration: 0.14), value: isHovered)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
