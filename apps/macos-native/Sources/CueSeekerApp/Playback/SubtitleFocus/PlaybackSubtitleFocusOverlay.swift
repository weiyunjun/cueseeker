import CueSeekerCore
import SwiftUI

struct PlaybackSubtitleFocusLayer: View {
    @ObservedObject var session: PlaybackSubtitleFocusSessionStore

    var body: some View {
        switch session.state {
        case .closed, .opening:
            EmptyView()
        case .cueSelection(let snapshot):
            PlaybackSubtitleFocusOverlay(snapshot: snapshot)
        }
    }
}

struct PlaybackSubtitleFocusOverlay: View {
    let snapshot: SubtitleFocusSnapshot

    var body: some View {
        GeometryReader { geometry in
            let viewportSize = geometry.size
            let contentWidth = max(
                0,
                min(
                    PlaybackSubtitleFocusMetrics.contentMaxWidth,
                    viewportSize.width - PlaybackSubtitleFocusMetrics.contentInset * 2
                )
            )
            let cueViewportHeight = max(
                0,
                viewportSize.height - PlaybackSubtitleFocusMetrics.contentInset * 2
            )
            let reelOffset = PlaybackSubtitleFocusMetrics.loadedReelOffset(
                viewportHeight: cueViewportHeight,
                totalCount: snapshot.totalCount,
                selectedOrdinal: snapshot.selectedOrdinal,
                loadedStartOrdinal: snapshot.cues.first?.ordinal ?? 0
            )

            ZStack(alignment: .top) {
                PlaybackTheme.subtitleFocusOverlayBackground

                ZStack(alignment: .topLeading) {
                    VStack(alignment: .leading, spacing: PlaybackSubtitleFocusMetrics.cueGap) {
                        ForEach(snapshot.cues) { cue in
                            PlaybackSubtitleFocusCue(
                                cue: cue,
                                isSelected: cue.ordinal == snapshot.selectedOrdinal
                            )
                        }
                    }
                    .frame(width: contentWidth, alignment: .topLeading)
                    .offset(y: reelOffset)
                }
                .frame(
                    width: contentWidth,
                    height: cueViewportHeight,
                    alignment: .topLeading
                )
                .clipped()
                .offset(y: PlaybackSubtitleFocusMetrics.contentInset)
            }
            .frame(width: viewportSize.width, height: viewportSize.height)
            .clipped()
            .contentShape(Rectangle())
            .environment(\.colorScheme, .dark)
        }
    }
}

private struct PlaybackSubtitleFocusCue: View {
    let cue: SubtitleFocusCue
    let isSelected: Bool
    @State private var isHovered = false

    var body: some View {
        PlaybackSubtitleFocusCueText(
            text: cue.text,
            isSelected: isSelected,
            isHovered: isHovered
        )
        .onHover { isInside in
            isHovered = !isSelected && isInside
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(
            height: PlaybackSubtitleFocusMetrics.cueSlotHeight,
            alignment: .topLeading
        )
        .clipped()
        .accessibilityLabel(cue.text)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .onChange(of: isSelected) { selected in
            if selected {
                isHovered = false
            }
        }
    }
}

struct PlaybackSubtitleFocusCueText: View {
    let text: String
    let isSelected: Bool
    var isHovered = false

    var body: some View {
        Text(text)
            .font(.system(
                size: PlaybackSubtitleFocusMetrics.cueFontSize,
                weight: .semibold
            ))
            .lineSpacing(PlaybackSubtitleFocusMetrics.cueLineSpacing)
            .foregroundStyle(cueColor)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var cueColor: Color {
        if isSelected {
            return PlaybackTheme.subtitleFocusCueSelected
        }
        if isHovered {
            return PlaybackTheme.subtitleFocusCueHover
        }
        return PlaybackTheme.subtitleFocusCueUnselected
    }
}
