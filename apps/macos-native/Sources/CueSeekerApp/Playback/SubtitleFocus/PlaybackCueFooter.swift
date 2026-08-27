import SwiftUI

enum PlaybackCueFooterMetrics {
    /// Provisional --height-playback-cue-footer, a floor rather than a fixed
    /// height: the actions wrap and the footer grows rather than truncating.
    static let minimumHeight: CGFloat = 48
}

/// Which surface the footer is drawn on. The two surfaces have different
/// backgrounds, so each carries its own keycap and button colours; it also
/// says which interface layer the buttons answer the pointer for.
enum PlaybackCueFooterSurface {
    case playbackOverlay
    case commandPanel

    var interfaceLayer: InterfaceLayer {
        switch self {
        case .playbackOverlay:
            .playbackOverlay
        case .commandPanel:
            .commandPanel
        }
    }

    var buttonHoverBackground: Color {
        switch self {
        case .playbackOverlay:
            WorkbenchRedesignColors.playbackOverlayShortcutButtonHoverBg
        case .commandPanel:
            WorkbenchRedesignColors.commandPanelShortcutButtonHoverBg
        }
    }

    var keycapBackground: Color {
        switch self {
        case .playbackOverlay:
            WorkbenchRedesignColors.playbackOverlayKeycapBg
        case .commandPanel:
            WorkbenchRedesignColors.commandPanelKeycapBg
        }
    }

    var keycapHoverBackground: Color {
        switch self {
        case .playbackOverlay:
            WorkbenchRedesignColors.playbackOverlayKeycapHoverBg
        case .commandPanel:
            WorkbenchRedesignColors.commandPanelKeycapHoverBg
        }
    }
}

enum PlaybackCueFooterKeycap: Equatable {
    case text(String)
    case systemImage(String)

    static let returnKey = Self.systemImage("return")
}

/// One footer action: what it says, which key does the same thing, and the
/// work itself. Clicking runs exactly what the shortcut runs.
struct PlaybackCueFooterAction: Identifiable {
    let id: String
    let title: String
    let keycap: PlaybackCueFooterKeycap
    let perform: () -> Void

    /// The four cue actions shared by Current, the subtitle Playlist and the
    /// Command Panel's search results.
    static func cueActions(
        playTitle: String,
        request: @escaping (PlaybackSubtitleFocusAction) -> Void
    ) -> [Self] {
        [
            Self(
                id: "shiori",
                title: L("playback.save_to_shiori"),
                keycap: .text("S"),
                perform: { request(.shiori) }
            ),
            Self(
                id: "copy-cue-text",
                title: L("row_menu.copy_cue_text"),
                keycap: .text("C"),
                perform: { request(.copyCueText) }
            ),
            Self(
                id: "copy-deep-link",
                title: L("row_menu.copy_deep_link"),
                keycap: .text("X"),
                perform: { request(.copyCueMarkdownLink) }
            ),
            Self(
                id: "play",
                title: playTitle,
                keycap: .returnKey,
                perform: { request(.playFromThisCue) }
            ),
        ]
    }

    /// The single action of a footer whose only key is Return.
    static func primary(
        id: String,
        title: String,
        perform: @escaping () -> Void
    ) -> Self {
        Self(id: id, title: title, keycap: .returnKey, perform: perform)
    }
}

enum PlaybackCueFooterStatus {
    static func cues(totalCount: Int) -> String {
        L("playback.cue_count", max(0, totalCount))
    }

    static func videos(totalCount: Int) -> String {
        L("playback.video_count", max(0, totalCount))
    }

    static func searchResults(
        totalCount: Int,
        previewLimit: Int,
        hasMoreResults: Bool
    ) -> String {
        let resolvedTotalCount = max(0, totalCount)
        let resolvedPreviewLimit = max(0, previewLimit)
        guard resolvedTotalCount > resolvedPreviewLimit || hasMoreResults else {
            return L("playback.result_count", resolvedTotalCount)
        }
        return L("playback.result_count", resolvedTotalCount) + " "
            + L("playback.result_preview_note", resolvedPreviewLimit)
    }
}

/// Reports the footer's laid-out height to a surface that has to subtract it
/// from its own content area.
struct PlaybackCueFooterHeightKey: PreferenceKey {
    static let defaultValue = PlaybackCueFooterMetrics.minimumHeight

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct PlaybackCueFooter: View {
    // Observed so the copy below is re-read when the language changes.
    @EnvironmentObject private var localization: AppLocalizationStore
    let surface: PlaybackCueFooterSurface
    let status: String?
    let actions: [PlaybackCueFooterAction]

    var body: some View {
        HStack(spacing: WorkbenchControlMetrics.redesignSpacing3) {
            if let status {
                Text(status)
                    .font(.system(
                        size: WorkbenchControlMetrics.redesignFontSizeBody,
                        weight: .regular
                    ))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("playback-cue-footer-status")
            }

            PlaybackCueFooterActionFlow(
                horizontalSpacing: WorkbenchControlMetrics.redesignSpacing1,
                verticalSpacing: WorkbenchControlMetrics.redesignSpacing1
            ) {
                ForEach(actions) { action in
                    PlaybackCueFooterActionButton(
                        surface: surface,
                        action: action
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .foregroundStyle(WorkbenchRedesignColors.textMuted)
        .padding(.vertical, WorkbenchControlMetrics.redesignSpacing2)
        .frame(minHeight: PlaybackCueFooterMetrics.minimumHeight)
        .background {
            GeometryReader { geometry in
                Color.clear.preference(
                    key: PlaybackCueFooterHeightKey.self,
                    value: geometry.size.height
                )
            }
        }
        .interfaceLayer(surface.interfaceLayer)
        .accessibilityIdentifier("playback-cue-footer")
    }
}

private struct PlaybackCueFooterActionButton: View {
    let surface: PlaybackCueFooterSurface
    let action: PlaybackCueFooterAction

    @State private var isHovered = false

    var body: some View {
        Button(action: action.perform) {
            HStack(spacing: WorkbenchControlMetrics.redesignSpacing1) {
                Text(action.title)
                    .font(.system(
                        size: WorkbenchControlMetrics.redesignFontSizeBody,
                        weight: WorkbenchControlMetrics.redesignFontWeightControl
                    ))
                    .fixedSize(horizontal: true, vertical: false)

                PlaybackCueFooterKeycapView(
                    keycap: action.keycap,
                    background: isHovered
                        ? surface.keycapHoverBackground
                        : surface.keycapBackground
                )
            }
            .padding(.horizontal, WorkbenchControlMetrics.redesignSpacing2)
            .padding(.vertical, WorkbenchControlMetrics.redesignSpacing1)
            .background {
                RoundedRectangle(
                    cornerRadius: WorkbenchControlMetrics.redesignChipRadius,
                    style: .continuous
                )
                .fill(
                    isHovered
                        ? surface.buttonHoverBackground
                        : Color.clear
                )
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(StaticButtonStyle())
        .focusable(false)
        .onPointerHover { isHovered = $0 }
        .accessibilityIdentifier("playback-cue-footer-action-\(action.id)")
    }
}

private struct PlaybackCueFooterKeycapView: View {
    let keycap: PlaybackCueFooterKeycap
    let background: Color

    var body: some View {
        label
            .font(.system(
                size: WorkbenchControlMetrics.redesignFontSizeCaption,
                weight: WorkbenchControlMetrics.redesignFontWeightControl
            ))
            .padding(
                .horizontal,
                WorkbenchControlMetrics.redesignKeycapHorizontalPadding
            )
            .frame(minWidth: WorkbenchControlMetrics.redesignKeycapHeight)
            .frame(height: WorkbenchControlMetrics.redesignKeycapHeight)
            .background {
                RoundedRectangle(
                    cornerRadius: WorkbenchControlMetrics.redesignKeycapRadius,
                    style: .continuous
                )
                .fill(background)
            }
    }

    @ViewBuilder
    private var label: some View {
        switch keycap {
        case .text(let text):
            Text(text)
        case .systemImage(let systemName):
            Image(systemName: systemName)
        }
    }
}

/// Right-aligned wrapping row. The actions keep their full width and move to
/// another line when the footer is too narrow, so nothing is ever shortened.
private struct PlaybackCueFooterActionFlow: Layout {
    var horizontalSpacing: CGFloat
    var verticalSpacing: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Void
    ) -> CGSize {
        let rows = rows(in: proposal.width ?? .infinity, subviews: subviews)
        let width = rows.map(\.width).max() ?? 0
        let height = rows.reduce(0) { $0 + $1.height }
            + verticalSpacing * CGFloat(max(0, rows.count - 1))
        return CGSize(width: width, height: height)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Void
    ) {
        var y = bounds.minY
        for row in rows(in: bounds.width, subviews: subviews) {
            var x = bounds.maxX - row.width
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(
                    at: CGPoint(x: x, y: y + (row.height - size.height) / 2),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(size)
                )
                x += size.width + horizontalSpacing
            }
            y += row.height + verticalSpacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func rows(in maxWidth: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var row = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let advance = row.indices.isEmpty
                ? size.width
                : horizontalSpacing + size.width
            if !row.indices.isEmpty, row.width + advance > maxWidth {
                rows.append(row)
                row = Row()
                row.indices = [index]
                row.width = size.width
                row.height = size.height
            } else {
                row.indices.append(index)
                row.width += advance
                row.height = max(row.height, size.height)
            }
        }
        if !row.indices.isEmpty {
            rows.append(row)
        }
        return rows
    }
}
