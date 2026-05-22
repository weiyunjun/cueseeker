import SwiftUI

struct LiquidGlassWindowControlButton: View {
    enum Kind {
        case close
        case minimize
        case zoom

        var fill: Color {
            switch self {
            case .close:
                return Color(red: 1.0, green: 95 / 255, blue: 87 / 255)
            case .minimize:
                return Color(red: 254 / 255, green: 188 / 255, blue: 46 / 255)
            case .zoom:
                return Color(red: 40 / 255, green: 200 / 255, blue: 64 / 255)
            }
        }

        var accessibilityLabel: String {
            switch self {
            case .close:
                return "Close video and return to results"
            case .minimize:
                return "Minimize playback"
            case .zoom:
                return "Fullscreen"
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
                .frame(width: 13, height: 13)
                .overlay(
                    Circle()
                        .strokeBorder(Color.black.opacity(0.18), lineWidth: 0.5)
                )
                .overlay(
                    glyph
                        .opacity(glyphVisible ? 1 : 0)
                        .animation(.easeInOut(duration: 0.12), value: glyphVisible)
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(kind.accessibilityLabel)
    }

    @ViewBuilder
    private var glyph: some View {
        let color = Color.black.opacity(0.55)
        switch kind {
        case .close:
            Image(systemName: "xmark")
                .font(.system(size: 7, weight: .bold))
                .foregroundStyle(color)
        case .minimize:
            Image(systemName: "minus")
                .font(.system(size: 7, weight: .bold))
                .foregroundStyle(color)
        case .zoom:
            RoundedRectangle(cornerRadius: 0.5)
                .fill(color)
                .frame(width: 5, height: 5)
        }
    }
}
