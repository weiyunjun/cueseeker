import SwiftUI

// Custom video-page top bar: the return button after the native window
// controls, which `AppWindowControls` places at the leading edge, the centered
// video title over the topbar gradient, and the App's Task and Settings
// entries at the trailing edge. Player UI. Maps prototype v6 `.video-topbar`.
struct LiquidGlassVideoTopBar: View {
    let title: String
    let onReturn: () -> Void
    @Environment(\.isPlayerUIVisible) private var isPlayerUIVisible

    var body: some View {
        // Transparent standard-titlebar base: empty-area drag moves the window
        // and double-click performs the system AppleActionOnDoubleClick (zoom
        // via the serialized titlebar-zoom path, or minimize).
        TitlebarBackgroundView(
            backgroundColor: Color.clear,
            allowsHitTesting: isPlayerUIVisible,
            onDoubleClickZoom: { window in
                NotificationCenter.default.post(
                    name: .topbarTitlebarZoomRequested,
                    object: window
                )
                return true
            }
        )
        .overlay {
            LinearGradient(
                colors: [
                    PlaybackTheme.topbarGradientStart,
                    PlaybackTheme.topbarGradientEnd
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)
        }
        .overlay {
            WorkbenchAdaptiveHeaderBar(
                leadingInset: 0,
                trailingInset: WorkbenchControlMetrics.redesignAppTopbarContentTrailingPadding,
                minimumGap: WorkbenchControlMetrics.redesignSpacing3,
                keepsCenterOnMidline: true,
                centerMaxWidthCap: PlaybackChromeMetrics.topbarTitleMaxWidth
            ) {
                PlaybackReturnButton(
                    iconColor: PlaybackTheme.textPrimary,
                    hoverBackground: PlaybackTheme.controlHoverBackground,
                    pressedBackground: PlaybackTheme.controlPressedBackground,
                    action: onReturn
                )
            } center: {
                Text(title)
                    .font(.system(size: WorkbenchControlMetrics.redesignFontSizeBody, weight: .semibold))
                    .foregroundStyle(PlaybackTheme.textPrimary)
                    .lineLimit(1)
                    // The title reads `name - sequence`; the ellipsis takes the
                    // name so the sequence stays readable however narrow the
                    // window is.
                    .truncationMode(.middle)
                    .shadow(
                        color: PlaybackTheme.topbarTitleShadowColor,
                        radius: PlaybackTheme.topbarTitleShadowRadius,
                        y: PlaybackTheme.topbarTitleShadowYOffset
                    )
                    .workbenchTruncatedTextTooltip(
                        scenarioID: "truncated.player.title",
                        text: title,
                        font: .system(size: WorkbenchControlMetrics.redesignFontSizeBody, weight: .semibold)
                    )
                    .allowsHitTesting(false)
            } trailing: {
                TopbarAppEntries(
                    iconColor: PlaybackTheme.textPrimary,
                    hoverBackground: PlaybackTheme.controlHoverBackground,
                    pressedBackground: PlaybackTheme.controlPressedBackground,
                    countBackground: PlaybackTheme.controlHoverBackground,
                    countTextColor: PlaybackTheme.textSecondary
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
