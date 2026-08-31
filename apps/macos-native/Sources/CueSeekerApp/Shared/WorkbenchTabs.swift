import SwiftUI

/// The one Tabs / Tab implementation in the App: a label over a selection
/// indicator. Playback Overlay, the Task panel and the Library pages all use
/// it, so the segment controls cannot read as different things.
struct WorkbenchTabs<Value: Hashable>: View {
    struct Item: Identifiable {
        let value: Value
        let label: String
        let accessibilityIdentifier: String

        var id: Value { value }
    }

    let items: [Item]
    let selection: Value?
    /// Pulls the first label flush with the surrounding content instead of
    /// leaving it inset by the hit-area padding every tab carries.
    var isLeadingEdgeAligned = false
    let onSelect: (Value) -> Void

    var body: some View {
        HStack(spacing: PlaybackOverlayMetrics.tabGap) {
            ForEach(items) { item in
                Button {
                    onSelect(item.value)
                } label: {
                    VStack(spacing: PlaybackOverlayMetrics.tabIndicatorGap) {
                        Text(item.label)
                            .font(.system(
                                size: PlaybackOverlayMetrics.tabFontSize,
                                weight: selection == item.value
                                    ? .semibold
                                    : .regular
                            ))
                            .lineLimit(1)

                        Capsule()
                            .fill(PlaybackTheme.playbackModuleSidebarSelected)
                            .frame(
                                width: PlaybackOverlayMetrics.tabIndicatorWidth,
                                height: PlaybackOverlayMetrics.tabIndicatorHeight
                            )
                            .opacity(selection == item.value ? 1 : 0)
                    }
                    .foregroundStyle(
                        selection == item.value
                            ? PlaybackTheme.playbackModuleSidebarSelected
                            : PlaybackTheme.playbackModuleSidebarUnselected
                    )
                    .padding(.horizontal, PlaybackOverlayMetrics.tabHorizontalPadding)
                    .contentShape(Rectangle())
                }
                .buttonStyle(StaticButtonStyle())
                .focusable(false)
                .accessibilityLabel(item.label)
                .accessibilityIdentifier(item.accessibilityIdentifier)
            }
        }
        .padding(
            .leading,
            isLeadingEdgeAligned
                ? -PlaybackOverlayMetrics.tabHorizontalPadding
                : 0
        )
    }
}
