import SwiftUI

/// The way back to the Workbench from the playback page: a Player Circle
/// Button after the native window controls, in the player top bar and again
/// in the Playback Overlay's top bar, at the same place in both.
struct PlaybackReturnButton: View {
    let action: () -> Void

    var body: some View {
        PlaybackChromeIconButton(
            systemName: "chevron.left",
            accessibilityLabel: L("playback.close_and_return"),
            action: action
        )
        .accessibilityIdentifier("playback-return")
        .frame(height: PlaybackChromeMetrics.videoTopBarHeight)
        .padding(.leading, leadingInset)
    }

    /// After the window controls: their inset, their measured width, then
    /// the gap.
    private var leadingInset: CGFloat {
        PlaybackChromeMetrics.topbarHorizontalPadding
            + AppWindowControls.clusterWidth
            + PlaybackChromeMetrics.windowControlsReturnGap
    }
}
