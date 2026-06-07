import AppKit
import CueSeekerCore
import SwiftUI

/// The overlay-panel Subtitles tab: the current subtitle file in timestamp
/// order. Observes the view model so the active-cue selection follows the
/// rate-limited displayed time (not the frame-cadence clock).
struct PlaybackSubtitlesList: View {
    private static let estimatedSubtitleRowHeight: CGFloat = 58

    @ObservedObject var appState: AppCoordinator
    @ObservedObject var viewModel: PlaybackViewModel
    @EnvironmentObject private var playback: PlaybackStore

    /// The cue active at the current displayed time: the entry that contains
    /// it, otherwise the last entry that has already started (handles gaps).
    private var activeEntryID: Int64? {
        let ms = Int((viewModel.displayedCurrentTime * 1_000).rounded(.down))
        return playback.currentSubtitleEntryLookup.activeEntryID(atMilliseconds: ms)
    }

    var body: some View {
        PlaybackSidebarVirtualList(
            rowCount: subtitleTotalCount,
            rowHeight: Self.estimatedSubtitleRowHeight,
            rowHeightForRow: { row, width in
                subtitleRowHeight(at: row, rowWidth: width)
            },
            rowsVersion: playback.currentSubtitleEntryRowsVersion,
            scrollTargetRow: activeEntryIndex,
            scrollTargetVersion: activeEntryScrollTargetVersion,
            onVisibleRowsChange: { rows in
                appState.loadCurrentSubtitleEntriesWindow(rows: rows)
            },
            rowContent: { row in
                subtitleRow(at: row)
            }
        )
        .onAppear {
            if playback.currentSubtitleEntryIndex.isEmpty {
                appState.refreshCurrentSubtitleEntries()
            }
        }
    }

    private var subtitleTotalCount: Int {
        max(playback.currentSubtitleEntryTotalCount, playback.currentSubtitleEntryIndex.count)
    }

    private var activeEntryIndex: Int? {
        guard let activeEntryID else {
            return nil
        }
        return playback.currentSubtitleEntryIndex.firstIndex { $0.id == activeEntryID }
    }

    private var activeEntryScrollTargetVersion: Int {
        guard let activeEntryID, let activeEntryIndex else {
            return 0
        }
        return activeEntryIndex ^ Int(truncatingIfNeeded: activeEntryID)
    }

    private func subtitleRow(at row: Int) -> AnyView {
        guard let entry = playback.currentSubtitleEntry(at: row) else {
            return AnyView(Color.clear)
        }

        return AnyView(
            PlaybackSidebarSubtitleRow(
                entry: entry,
                isSelected: entry.id == activeEntryID,
                onSeek: {
                    appState.seekCurrentPlayback(toMilliseconds: entry.startMilliseconds)
                }
            )
        )
    }

    private func subtitleRowHeight(at row: Int, rowWidth: CGFloat) -> CGFloat {
        guard let entry = playback.currentSubtitleEntry(at: row) else {
            return Self.estimatedSubtitleRowHeight
        }

        return PlaybackSidebarSubtitleRowMetrics.rowHeight(
            forDisplayLines: subtitleDisplayLines(content: entry.content, cueLines: []),
            rowWidth: rowWidth
        )
    }
}

enum PlaybackSidebarSubtitleRowMetrics {
    static let minimumRowHeight: CGFloat = 58
    private static let horizontalPadding: CGFloat = 22
    private static let verticalPadding: CGFloat = 22
    private static let rowSpacing: CGFloat = 4
    private static var metadataFont: NSFont {
        NSFont.systemFont(ofSize: 11.5, weight: .regular)
    }

    private static var contentFont: NSFont {
        NSFont.systemFont(ofSize: 12.5, weight: .regular)
    }

    static func rowHeight(forDisplayLines displayLines: [String], rowWidth: CGFloat) -> CGFloat {
        let lines = displayLines.isEmpty ? [""] : displayLines
        let textWidth = max(1, rowWidth - horizontalPadding)
        let metadataHeight = ceil(metadataFont.ascender - metadataFont.descender + metadataFont.leading)
        let contentHeight = lines.reduce(CGFloat(0)) { height, line in
            height + measuredTextHeight(line, width: textWidth)
        }
        let spacingHeight = CGFloat(lines.count) * rowSpacing
        let measuredHeight = metadataHeight + contentHeight + spacingHeight + verticalPadding
        return max(minimumRowHeight, ceil(measuredHeight))
    }

    private static func measuredTextHeight(_ text: String, width: CGFloat) -> CGFloat {
        let measuredText = text.isEmpty ? " " : text
        let attributed = NSAttributedString(
            string: measuredText,
            attributes: [.font: contentFont]
        )
        let rect = attributed.boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )
        return max(ceil(rect.height), ceil(contentFont.ascender - contentFont.descender + contentFont.leading))
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
