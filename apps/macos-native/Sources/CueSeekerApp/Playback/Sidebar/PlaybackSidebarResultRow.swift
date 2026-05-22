import CueSeekerCore
import SwiftUI

/// One Search Results row in the overlay panel, mirroring the prototype
/// `.sidebar-row`: a meta line (global rank + timestamp) above the cue lines,
/// with query-match highlighting reused from the info-page Search renderer.
struct PlaybackSidebarResultRow: View {
    let rank: Int
    let result: SubtitleSearchResult
    let query: String
    let isSelected: Bool
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
                        state: highlightState
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
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isSelected ? selectedRingColor : Color.clear, lineWidth: 1)
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
        isSelected ? .selected : (isHovered ? .hover : .default)
    }

    private var lineColor: Color {
        if isSelected {
            return colorScheme == .dark
                ? Color(red: 248 / 255, green: 246 / 255, blue: 251 / 255)
                : Color(red: 10 / 255, green: 20 / 255, blue: 38 / 255)
        }
        return Color.primary.opacity(0.86)
    }

    private var metaColor: Color {
        isSelected ? accentColor : Color.primary.opacity(0.45)
    }

    private var accentColor: Color {
        colorScheme == .dark
            ? Color(red: 110 / 255, green: 166 / 255, blue: 255 / 255)
            : Color(red: 10 / 255, green: 132 / 255, blue: 255 / 255)
    }

    private var selectedRingColor: Color {
        accentColor.opacity(colorScheme == .dark ? 0.52 : 0.55)
    }

    private var rowBackground: Color {
        if isSelected {
            return colorScheme == .dark ? Color.white.opacity(0.16) : Color.white.opacity(0.85)
        }
        if isHovered {
            return colorScheme == .dark ? Color.white.opacity(0.10) : Color.white.opacity(0.55)
        }
        return Color.clear
    }
}
