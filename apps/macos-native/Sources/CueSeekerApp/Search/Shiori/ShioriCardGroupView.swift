import CueSeekerCore
import SwiftUI

struct ShioriCardGroupView: View {
    let group: ShioriFileGroup
    let onToggle: () -> Void
    let onOpenShiori: (Shiori) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CardGroupHeader(
                title: group.subtitleDisplayTitle,
                countText: "\(group.totalCount) \(group.totalCount == 1 ? "shiori" : "shioris")",
                isCollapsed: group.isCollapsed,
                onToggle: onToggle
            )

            if !group.isCollapsed {
                EqualHeightCardGridLayout(
                    minimumColumnWidth: SearchCardLayout.cardMinimumWidth,
                    horizontalSpacing: SearchCardLayout.cardHorizontalSpacing,
                    verticalSpacing: SearchCardLayout.cardVerticalSpacing
                ) {
                    ForEach(Array(group.shioris.enumerated()), id: \.element.id) { index, shiori in
                        ShioriCard(
                            shiori: shiori,
                            rank: index + 1,
                            onOpen: { onOpenShiori(shiori) }
                        )
                        .focusable(false)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ShioriCard: View {
    let shiori: Shiori
    let rank: Int
    let onOpen: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        // Shiori has no `.shiori-card` overrides in v6: this is the P5.2-B
        // `.result-card` spec verbatim (the shared LiquidGlassSelectableCard),
        // so P5.4-B introduces no new pixel values. Main-page cards retain no
        // playback selection visual (doc 12 §6.4, doc 11 §5/§7; finding F);
        // the vestigial `isSelected` plumbing is excised in P5.4-2.
        let tokens = LiquidGlassTokens(colorScheme: colorScheme)
        let textColor = tokens.text.opacity(0.88)
        let secondaryTextColor = tokens.text3

        LiquidGlassSelectableCard(
            cornerRadius: SearchCardLayout.cardCornerRadius,
            action: onOpen
        ) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    Text("#\(rank)")
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundStyle(secondaryTextColor)
                        .monospacedDigit()

                    Spacer(minLength: 8)

                    Text(formatTimestamp(shiori.startMilliseconds))
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundStyle(secondaryTextColor)
                        .lineLimit(1)
                        .monospacedDigit()
                }

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(displayLines.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.system(size: 13.5, weight: .semibold))
                            .foregroundStyle(textColor)
                            .lineLimit(nil)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 11)
            .frame(
                maxWidth: .infinity,
                minHeight: SearchCardLayout.cardMinHeight,
                maxHeight: .infinity,
                alignment: .topLeading
            )
        }
        .accessibilityLabel("\(shiori.videoName), \(formatTimestamp(shiori.startMilliseconds))")
    }

    private var displayLines: [String] {
        subtitleDisplayLines(content: shiori.content, cueLines: shiori.cueLines)
    }
}
