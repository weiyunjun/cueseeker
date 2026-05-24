import CueSeekerCore
import SwiftUI

struct SearchResultCardGroupView: View {
    let group: SearchResultFileGroup
    let query: String
    let onToggle: () -> Void
    let onOpenResult: (SubtitleSearchResult) -> Void
    let onResultAppear: (SubtitleSearchResult) -> Void
    let onExportToAnki: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CardGroupHeader(
                title: group.subtitleDisplayTitle,
                countText: resultCountText,
                isCollapsed: group.isCollapsed,
                onToggle: onToggle,
                onExportToAnki: group.results.isEmpty ? nil : onExportToAnki
            )

            if !group.isCollapsed {
                EqualHeightCardGridLayout(
                    minimumColumnWidth: SearchCardLayout.cardMinimumWidth,
                    horizontalSpacing: SearchCardLayout.cardHorizontalSpacing,
                    verticalSpacing: SearchCardLayout.cardVerticalSpacing
                ) {
                    ForEach(group.results, id: \.entryID) { result in
                        SearchResultCard(
                            result: result,
                            query: query,
                            onOpen: { onOpenResult(result) }
                        )
                        .id(result.entryID)
                        .focusable(false)
                        .onAppear {
                            onResultAppear(result)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var resultCountText: String {
        "\(group.totalCount) \(group.totalCount == 1 ? "result" : "results")"
    }
}

private struct SearchResultCard: View {
    let result: SubtitleSearchResult
    let query: String
    let onOpen: () -> Void
    @State private var isHovered = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        // Main-page cards retain no playback selection visual (doc 12 §6.4,
        // doc 11 §5/§7; audit finding F). Surface is the shared token-driven
        // LiquidGlassSelectableCard; content / highlight / equal-height are
        // unchanged from before P5.2.
        let tokens = LiquidGlassTokens(colorScheme: colorScheme)
        let textColor = tokens.text.opacity(0.88)
        let secondaryTextColor = tokens.text3
        let highlightState: SearchHighlightState = isHovered ? .hover : .default

        LiquidGlassSelectableCard(
            cornerRadius: SearchCardLayout.cardCornerRadius,
            action: onOpen
        ) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    Text("#\(result.searchRank + 1)")
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundStyle(secondaryTextColor)
                        .monospacedDigit()

                    Spacer(minLength: 8)

                    Text(formatTimestamp(result.startMilliseconds))
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundStyle(secondaryTextColor)
                        .lineLimit(1)
                        .monospacedDigit()
                }

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(displayLines.enumerated()), id: \.offset) { _, line in
                        Text(highlightedContent(
                            line,
                            query: query,
                            textColor: textColor,
                            state: highlightState
                        ))
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
        .onHover { isHovered = $0 }
        .accessibilityLabel("\(result.videoName), \(formatTimestamp(result.startMilliseconds))")
    }

    private var displayLines: [String] {
        subtitleDisplayLines(content: result.content, cueLines: result.cueLines)
    }
}
