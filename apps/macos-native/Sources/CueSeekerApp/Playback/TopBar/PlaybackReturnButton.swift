import SwiftUI

/// The way back to the Workbench from the playback page: an Icon Button after
/// the native window controls, in the player top bar and again in the
/// Playback Overlay's top bar, at the same place in both. Both bars are the
/// window controls' band, so centring the button in the bar puts it on the
/// controls' centre line.
struct PlaybackReturnButton: View {
    /// The colors of the surface the button is drawn on.
    var iconColor: Color? = nil
    let hoverBackground: Color
    var scenarioID: String = "player.topbar.return"
    let action: () -> Void
    @Environment(\.isAppFullscreen) private var isAppFullscreen

    var body: some View {
        WorkbenchIconButton(
            icon: .caretLeft,
            isRedesign: true,
            hoverBackground: hoverBackground,
            iconColor: iconColor,
            action: action
        )
        .workbenchTooltip(
            scenarioID: scenarioID,
            label: L("tooltip.playback.return_to_workbench")
        )
        .accessibilityLabel(L("playback.close_and_return"))
        .accessibilityIdentifier("playback-return")
        .playerInteractiveRegion()
        .padding(.leading, leadingInset)
    }

    /// After the window controls: their inset, their measured width, then
    /// the gap. In fullscreen the system titlebar owns them, so the button
    /// takes the bar's own leading padding instead of their empty band.
    private var leadingInset: CGFloat {
        PlaybackChromeMetrics.topbarReturnLeadingInset(
            isFullscreen: isAppFullscreen
        )
    }
}
