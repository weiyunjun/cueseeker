import CueSeekerCore
import SwiftUI

/// The overlay-panel Subtitles tab: the current subtitle file in timestamp
/// order. Observes the view model so the active-cue selection follows the
/// rate-limited displayed time (not the frame-cadence clock).
struct PlaybackSubtitlesList: View {
    @ObservedObject var appState: AppCoordinator
    @ObservedObject var viewModel: PlaybackViewModel
    @EnvironmentObject private var playback: PlaybackStore

    private var orderedEntries: [SubtitleDatabaseEntry] {
        playback.currentSubtitleEntries
    }

    /// The cue active at the current displayed time: the entry that contains
    /// it, otherwise the last entry that has already started (handles gaps).
    private var activeEntryID: Int64? {
        let ms = Int((viewModel.displayedCurrentTime * 1_000).rounded(.down))
        return playback.currentSubtitleEntryLookup.activeEntryID(atMilliseconds: ms)
    }

    var body: some View {
        let entries = orderedEntries
        let activeID = activeEntryID
        return ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(entries, id: \.id) { entry in
                        PlaybackSidebarSubtitleRow(
                            entry: entry,
                            isSelected: entry.id == activeID,
                            onSeek: {
                                appState.seekCurrentPlayback(
                                    toMilliseconds: entry.startMilliseconds
                                )
                            }
                        )
                        .id(entry.id)
                    }
                }
                .padding(EdgeInsets(top: 6, leading: 8, bottom: 14, trailing: 8))
            }
            .background(ScrollViewIntrospector { scrollView in
                scrollView.drawsBackground = false
                scrollView.borderType = .noBorder
                scrollView.scrollerStyle = .overlay
                if !(scrollView.verticalScroller is PlaybackTransparentScroller) {
                    scrollView.verticalScroller = PlaybackTransparentScroller()
                }
                scrollView.appearance = NSAppearance(named: .darkAqua)
            })
            .onAppear { scrollActiveIntoView(proxy, id: activeID) }
            .onChange(of: activeID) { newValue in
                scrollActiveIntoView(proxy, id: newValue)
            }
        }
    }

    private func scrollActiveIntoView(_ proxy: ScrollViewProxy, id: Int64?) {
        guard let id else {
            return
        }

        withAnimation(.easeInOut(duration: 0.18)) {
            proxy.scrollTo(id, anchor: .center)
        }
    }
}

/// One Subtitles row, mirroring the prototype `.sidebar-row`: a timestamp meta
/// line above the cue lines. No rank and no keyword highlight (doc 12 §11).
private struct PlaybackSidebarSubtitleRow: View {
    let entry: SubtitleDatabaseEntry
    let isSelected: Bool
    let onSeek: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false

    var body: some View {
        Button(action: onSeek) {
            VStack(alignment: .leading, spacing: 4) {
                Text(formatTimestamp(entry.startMilliseconds))
                    .font(.system(size: 11.5, weight: isSelected ? .semibold : .regular))
                    .monospacedDigit()
                    .foregroundStyle(metaColor)

                ForEach(Array(displayLines.enumerated()), id: \.offset) { _, line in
                    Text(line)
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
        subtitleDisplayLines(content: entry.content, cueLines: [])
    }

    private var lineColor: Color {
        isSelected ? Color.white : Color.white.opacity(0.90)
    }

    private var metaColor: Color {
        isSelected ? Color.white : Color.white.opacity(0.55)
    }

    private var rowBackground: Color {
        if isSelected || isHovered {
            return PlaybackTheme.menuItemHighlight
        }
        return Color.clear
    }
}
