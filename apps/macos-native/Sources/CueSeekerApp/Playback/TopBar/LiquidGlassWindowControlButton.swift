import SwiftUI

struct LiquidGlassWindowControlButton: View {
    enum Kind {
        case close
        case minimize
        case zoom

        var fill: Color {
            switch self {
            case .close:
                return PlaybackTheme.windowClose
            case .minimize:
                return PlaybackTheme.windowMinimize
            case .zoom:
                return PlaybackTheme.windowZoom
            }
        }

        var accessibilityLabel: String {
            switch self {
            case .close:
                return L("playback.close_and_return")
            case .minimize:
                return L("playback.minimize")
            case .zoom:
                return L("playback.fullscreen")
            }
        }
    }

    let kind: Kind
    let glyphVisible: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(kind.fill)
                .frame(
                    width: PlaybackChromeMetrics.windowControlButtonSize,
                    height: PlaybackChromeMetrics.windowControlButtonSize
                )
                .overlay(
                    Circle()
                        .strokeBorder(
                            PlaybackTheme.windowControlBorder,
                            lineWidth: PlaybackChromeMetrics.windowControlBorderWidth
                        )
                )
                .overlay(
                    glyph
                        .opacity(glyphVisible ? 1 : 0)
                        .animation(.easeInOut(duration: 0.12), value: glyphVisible)
                )
                .contentShape(Circle())
        }
        .buttonStyle(StaticButtonStyle())
        .accessibilityLabel(kind.accessibilityLabel)
    }

    @ViewBuilder
    private var glyph: some View {
        switch kind {
        case .close:
            Image(systemName: "xmark")
                .font(.system(size: PlaybackChromeMetrics.windowControlGlyphSize, weight: .bold))
                .foregroundStyle(PlaybackTheme.windowControlGlyph)
        case .minimize:
            Image(systemName: "minus")
                .font(.system(size: PlaybackChromeMetrics.windowControlGlyphSize, weight: .bold))
                .foregroundStyle(PlaybackTheme.windowControlGlyph)
        case .zoom:
            RoundedRectangle(cornerRadius: 0.5)
                .fill(PlaybackTheme.windowControlGlyph)
                .frame(
                    width: PlaybackChromeMetrics.windowControlZoomGlyphSize,
                    height: PlaybackChromeMetrics.windowControlZoomGlyphSize
                )
        }
    }
}
