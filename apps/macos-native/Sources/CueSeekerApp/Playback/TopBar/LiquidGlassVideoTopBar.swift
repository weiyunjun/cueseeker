import SwiftUI

// Custom video-page top bar: the return button after the native window
// controls, which `AppWindowControls` places at the leading edge, the centered
// video title over the topbar gradient, and the App's Task and Settings
// entries at the trailing edge. Player UI. Maps prototype v6 `.video-topbar`.
struct LiquidGlassVideoTopBar: View {
    let title: String
    let onReturn: () -> Void
    @Environment(\.isAppFullscreen) private var isAppFullscreen

    var body: some View {
        GeometryReader { proxy in
            bar(titleMaxWidth: titleMaxWidth(barWidth: proxy.size.width))
        }
    }

    private func bar(titleMaxWidth: CGFloat) -> some View {
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
                .frame(maxWidth: titleMaxWidth)
                .allowsHitTesting(false)
        }
        .overlay(alignment: .leading) {
            PlaybackReturnButton(
                iconColor: PlaybackTheme.textPrimary,
                hoverBackground: PlaybackTheme.controlHoverBackground,
                action: onReturn
            )
        }
        .overlay(alignment: .trailing) {
            TopbarAppEntries(
                iconColor: PlaybackTheme.textPrimary,
                hoverBackground: PlaybackTheme.controlHoverBackground,
                countBackground: PlaybackTheme.textPrimary,
                countTextColor: PlaybackTheme.iconSelected
            )
            .padding(.trailing, PlaybackChromeMetrics.topbarHorizontalPadding)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Its own maximum, and never more than the space the return button and
    /// the trailing entries leave on the bar's centre line.
    private func titleMaxWidth(barWidth: CGFloat) -> CGFloat {
        min(
            PlaybackChromeMetrics.topbarTitleMaxWidth,
            PlaybackChromeMetrics.topbarCenterMaxWidth(
                barWidth: barWidth,
                isFullscreen: isAppFullscreen,
                trailingButtonCount: 2,
                trailingPadding: PlaybackChromeMetrics.topbarHorizontalPadding
            )
        )
    }
}
