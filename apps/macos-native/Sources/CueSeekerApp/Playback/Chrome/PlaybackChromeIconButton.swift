import SwiftUI

enum PlaybackChromeButtonKind {
    case circle
    case transport
    case primaryTransport

    var size: CGFloat {
        switch self {
        case .circle:
            return 32
        case .transport:
            return 40
        case .primaryTransport:
            return 44
        }
    }

    var symbolSize: CGFloat {
        switch self {
        case .circle:
            return 15
        case .transport:
            return 18
        case .primaryTransport:
            return 20
        }
    }
}

enum PlaybackChromeIcon {
    case system(String)
    case copy
}

struct PlaybackChromeIconButton: View {
    let icon: PlaybackChromeIcon
    var kind: PlaybackChromeButtonKind = .circle
    var isSelected = false
    var isDisabled = false
    let accessibilityLabel: String
    let action: () -> Void

    init(
        systemName: String,
        kind: PlaybackChromeButtonKind = .circle,
        isSelected: Bool = false,
        isDisabled: Bool = false,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) {
        self.icon = .system(systemName)
        self.kind = kind
        self.isSelected = isSelected
        self.isDisabled = isDisabled
        self.accessibilityLabel = accessibilityLabel
        self.action = action
    }

    init(
        icon: PlaybackChromeIcon,
        kind: PlaybackChromeButtonKind = .circle,
        isSelected: Bool = false,
        isDisabled: Bool = false,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.kind = kind
        self.isSelected = isSelected
        self.isDisabled = isDisabled
        self.accessibilityLabel = accessibilityLabel
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            PlaybackChromeIconView(icon: icon, size: kind.symbolSize)
                .frame(width: kind.size, height: kind.size)
                .contentShape(Circle())
        }
        .buttonStyle(PlaybackChromeIconButtonStyle(kind: kind, isSelected: isSelected))
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.34 : 1)
        .accessibilityLabel(accessibilityLabel)
    }
}

private struct PlaybackChromeIconView: View {
    let icon: PlaybackChromeIcon
    let size: CGFloat

    var body: some View {
        switch icon {
        case .system(let systemName):
            Image(systemName: systemName)
                .font(.system(size: size, weight: .semibold))
        case .copy:
            PlaybackCopyGlyph()
                .stroke(style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                .frame(width: 17, height: 17)
        }
    }
}

struct PlaybackCopyGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        let scaleX = rect.width / 17
        let scaleY = rect.height / 17

        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * scaleX, y: rect.minY + y * scaleY)
        }

        func scaledRect(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) -> CGRect {
            CGRect(
                x: rect.minX + x * scaleX,
                y: rect.minY + y * scaleY,
                width: width * scaleX,
                height: height * scaleY
            )
        }

        var path = Path()
        path.addRoundedRect(
            in: scaledRect(x: 3.2, y: 5.2, width: 8.1, height: 9.2),
            cornerSize: CGSize(width: 1.2 * scaleX, height: 1.2 * scaleY)
        )
        path.move(to: point(6, 2.6))
        path.addLine(to: point(12.4, 2.6))
        path.addCurve(
            to: point(13.8, 4.0),
            control1: point(12.4, 2.6),
            control2: point(13.8, 2.6)
        )
        path.addLine(to: point(13.8, 11.2))
        return path
    }
}

private struct PlaybackChromeIconButtonStyle: ButtonStyle {
    let kind: PlaybackChromeButtonKind
    let isSelected: Bool
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(foregroundColor)
            .background(
                Circle()
                    .fill(backgroundColor(isPressed: configuration.isPressed))
                    .background(materialBackground(isPressed: configuration.isPressed))
            )
            .overlay(
                Circle()
                    .strokeBorder(borderColor, lineWidth: 0.5)
            )
            .shadow(color: shadowColor, radius: shadowRadius, y: shadowY)
            .scaleEffect(configuration.isPressed && isEnabled ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .animation(.easeOut(duration: 0.12), value: isHovered)
            .onHover { isHovered = $0 }
    }

    private var foregroundColor: Color {
        guard isEnabled else {
            return .white.opacity(0.46)
        }
        return isSelected ? Color(red: 0.10, green: 0.10, blue: 0.12) : .white.opacity(0.96)
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        guard isEnabled else {
            return .clear
        }
        if isSelected {
            return Color.white.opacity(isPressed ? 0.82 : 0.92)
        }
        if isHovered || isPressed {
            return Color.white.opacity(isPressed ? 0.14 : 0.18)
        }
        return .clear
    }

    @ViewBuilder
    private func materialBackground(isPressed: Bool) -> some View {
        if isEnabled && (isHovered || isSelected || isPressed) {
            Circle()
                .fill(.ultraThinMaterial)
        }
    }

    private var borderColor: Color {
        guard isEnabled else {
            return .clear
        }
        if isSelected {
            return Color.white.opacity(0.7)
        }
        return isHovered ? Color.white.opacity(0.10) : .clear
    }

    private var shadowColor: Color {
        isSelected ? Color.black.opacity(0.22) : Color.black.opacity(0)
    }

    private var shadowRadius: CGFloat {
        isSelected ? 4 : 0
    }

    private var shadowY: CGFloat {
        isSelected ? 1 : 0
    }
}
