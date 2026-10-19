import SwiftUI

/// The one Tabs / Tab implementation in the App: a label over a sliding
/// selection indicator. Recent topbar, Playback Overlay topbar, and the Task
/// dialog header all share it so top-level view switchers read identically.
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
                let isSelected = selection == item.value
                Button {
                    onSelect(item.value)
                } label: {
                    VStack(spacing: PlaybackOverlayMetrics.tabIndicatorGap) {
                        WorkbenchTabLabel(
                            label: item.label,
                            selectionProgress: isSelected ? 1 : 0
                        )

                        Color.clear
                            .frame(
                                width: PlaybackOverlayMetrics.tabIndicatorWidth,
                                height: PlaybackOverlayMetrics.tabIndicatorHeight
                            )
                    }
                    .padding(.horizontal, PlaybackOverlayMetrics.tabHorizontalPadding)
                    .contentShape(Rectangle())
                }
                .buttonStyle(StaticButtonStyle())
                .focusable(false)
                .anchorPreference(
                    key: WorkbenchTabBoundsKey<Value>.self,
                    value: .bounds
                ) { [item.value: $0] }
                .accessibilityLabel(item.label)
                .accessibilityValue(
                    isSelected ? L("facet.selected") : L("facet.not_selected")
                )
                .accessibilityIdentifier(item.accessibilityIdentifier)
            }
        }
        .animation(PlaybackOverlayMetrics.tabSelectionAnimation, value: selection)
        .overlayPreferenceValue(WorkbenchTabBoundsKey<Value>.self) { anchors in
            GeometryReader { proxy in
                if let selection, let anchor = anchors[selection] {
                    let indicatorFrame = PlaybackOverlayMetrics.tabIndicatorFrame(
                        for: proxy[anchor]
                    )
                    Capsule()
                        .fill(WorkbenchRedesignColors.textPrimary)
                        .frame(
                            width: indicatorFrame.width,
                            height: indicatorFrame.height
                        )
                        .offset(
                            x: indicatorFrame.minX,
                            y: indicatorFrame.minY
                        )
                        .animation(
                            PlaybackOverlayMetrics.tabSelectionAnimation,
                            value: selection
                        )
                }
            }
            .allowsHitTesting(false)
        }
        .padding(
            .leading,
            isLeadingEdgeAligned
                ? -PlaybackOverlayMetrics.tabHorizontalPadding
                : 0
        )
    }
}

private struct WorkbenchTabLabel: View, Animatable {
    let label: String
    var selectionProgress: Double

    nonisolated var animatableData: Double {
        get { selectionProgress }
        set { selectionProgress = newValue }
    }

    var body: some View {
        Text(label)
            .font(.system(
                size: PlaybackOverlayMetrics.tabFontSize,
                weight: PlaybackOverlayMetrics.tabFontWeight
            ))
            .lineLimit(1)
            .foregroundStyle(
                Color(nsColor: PlaybackOverlayMetrics.interpolatedTabTextColor(
                    progress: selectionProgress
                ))
            )
    }
}

private struct WorkbenchTabBoundsKey<Value: Hashable>: PreferenceKey {
    static var defaultValue: [Value: Anchor<CGRect>] { [:] }

    static func reduce(
        value: inout [Value: Anchor<CGRect>],
        nextValue: () -> [Value: Anchor<CGRect>]
    ) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}
