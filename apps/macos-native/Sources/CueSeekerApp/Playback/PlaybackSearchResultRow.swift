import CueSeekerCore
import SwiftUI

/// Compact playback search-result row used by the Quick Search overlay.
struct PlaybackSearchResultRow: View {
    let rank: Int
    let result: SubtitleSearchResult
    let query: String
    let isSelected: Bool
    var allowsHoverHighlight = true
    let onOpen: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("#\(rank)")
                    Text(formatTimestamp(result.startMilliseconds))
                }
                .font(.system(size: 11.5, weight: isSelected ? .semibold : .regular))
                .monospacedDigit()
                .foregroundStyle(metaColor)

                ForEach(Array(displayLines.enumerated()), id: \.offset) { _, line in
                    Text(highlightedContent(
                        line,
                        query: query,
                        textColor: lineColor,
                        state: highlightState,
                        highlightBackgroundColor: Color.clear
                    ))
                    .font(.system(size: 12.5, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(lineColor)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 11)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(rowBackground)
            )
            .contentShape(RoundedRectangle(cornerRadius: 8))
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }

    private var displayLines: [String] {
        subtitleDisplayLines(content: result.content, cueLines: result.cueLines)
    }

    private var highlightState: SearchHighlightState {
        isSelected ? .selected : (showsHoverHighlight ? .hover : .default)
    }

    private var lineColor: Color {
        isSelected ? Color.white : Color.white.opacity(0.90)
    }

    private var metaColor: Color {
        isSelected ? Color.white : Color.white.opacity(0.55)
    }

    private var rowBackground: Color {
        if isSelected || showsHoverHighlight {
            return PlaybackTheme.menuItemHighlight
        }
        return Color.clear
    }

    private var showsHoverHighlight: Bool {
        allowsHoverHighlight && isHovered
    }
}
