import SwiftUI

// Custom video-page top bar: left traffic-light cluster + centered video
// title. Player UI. Maps prototype v6 `.video-topbar` / `.video-traffic`.
struct LiquidGlassVideoTopBar: View {
    let title: String
    let onClose: () -> Void
    let onMinimize: () -> Void
    let onZoom: () -> Void

    @State private var isClusterActive = false

    var body: some View {
        // Transparent standard-titlebar base: empty-area drag moves the window
        // and double-click performs the system AppleActionOnDoubleClick (zoom
        // via the serialized titlebar-zoom path, or minimize). The control
        // buttons sit on top and consume their own clicks.
        TitlebarBackgroundView(
            backgroundColor: .clear,
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
                    Color(red: 18 / 255, green: 18 / 255, blue: 24 / 255).opacity(0.66),
                    Color(red: 18 / 255, green: 18 / 255, blue: 24 / 255).opacity(0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)
        }
        .overlay {
            ZStack {
                HStack(spacing: 0) {
                    HStack(spacing: 8) {
                        LiquidGlassWindowControlButton(
                            kind: .close,
                            glyphVisible: isClusterActive,
                            action: onClose
                        )
                        LiquidGlassWindowControlButton(
                            kind: .minimize,
                            glyphVisible: isClusterActive,
                            action: onMinimize
                        )
                        LiquidGlassWindowControlButton(
                            kind: .zoom,
                            glyphVisible: isClusterActive,
                            action: onZoom
                        )
                    }
                    .onHover { isClusterActive = $0 }

                    Spacer(minLength: 0)
                }

                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .tracking(0.13)
                    .foregroundStyle(Color.white.opacity(0.92))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .shadow(color: .black.opacity(0.5), radius: 2, y: 1)
                    .frame(maxWidth: 520)
                    .allowsHitTesting(false)
            }
            .padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
