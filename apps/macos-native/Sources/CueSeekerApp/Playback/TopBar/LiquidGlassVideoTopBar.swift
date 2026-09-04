import SwiftUI

// Custom video-page top bar: the return button after the native window
// controls, which `AppWindowControls` places at the leading edge, and the
// centered video title over the topbar gradient. Player UI. Maps prototype
// v6 `.video-topbar`.
struct LiquidGlassVideoTopBar: View {
    let title: String
    let onReturn: () -> Void

    var body: some View {
        // Transparent standard-titlebar base: empty-area drag moves the window
        // and double-click performs the system AppleActionOnDoubleClick (zoom
        // via the serialized titlebar-zoom path, or minimize).
        TitlebarBackgroundView(
            backgroundColor: Color.clear,
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
            Text(title)
                .font(.system(size: PlaybackChromeMetrics.topbarTitleFontSize, weight: .semibold))
                .foregroundStyle(PlaybackTheme.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
                .shadow(
                    color: PlaybackTheme.topbarTitleShadowColor,
                    radius: PlaybackTheme.topbarTitleShadowRadius,
                    y: PlaybackTheme.topbarTitleShadowYOffset
                )
                .frame(maxWidth: PlaybackChromeMetrics.topbarTitleMaxWidth)
                .allowsHitTesting(false)
                .padding(.horizontal, PlaybackChromeMetrics.topbarHorizontalPadding)
        }
        .overlay(alignment: .topLeading) {
            PlaybackReturnButton(action: onReturn)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
