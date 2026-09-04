import SwiftUI

/// The way back to the Workbench from the playback page: a Player Circle
/// Button after the native window controls, in the player top bar and again
/// in the Playback Overlay's top bar, at the same place in both. The window
/// controls sit where they do on every page, so the button is laid out on
/// their centre line — the top-aligned `--height-app-topbar` band — not on
/// the centre line of whichever bar holds it.
struct PlaybackReturnButton: View {
    let action: () -> Void

    var body: some View {
        PlaybackChromeIconButton(
            systemName: "chevron.left",
            accessibilityLabel: L("playback.close_and_return"),
            action: action
        )
        .accessibilityIdentifier("playback-return")
        .frame(height: WorkbenchControlMetrics.redesignAppTopbarHeight)
        .padding(.leading, leadingInset)
    }

    /// After the window controls: their inset, their measured width, then
    /// the gap.
    private var leadingInset: CGFloat {
        WorkbenchControlMetrics.redesignSpacing6
            + AppWindowControls.clusterWidth
            + PlaybackChromeMetrics.windowControlsReturnGap
    }
}
