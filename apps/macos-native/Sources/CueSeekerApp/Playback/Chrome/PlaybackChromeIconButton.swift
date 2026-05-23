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
    case sidebar(isOpen: Bool)
}

struct PlaybackChromeIconButton: View {
    let icon: PlaybackChromeIcon
    var kind: PlaybackChromeButtonKind = .circle
    var isSelected = false
    var isDisabled = false
    var suppressesInteraction = false
    var hasPersistentBase = true
    let accessibilityLabel: String
    let action: () -> Void

    init(
        systemName: String,
        kind: PlaybackChromeButtonKind = .circle,
        isSelected: Bool = false,
        isDisabled: Bool = false,
        suppressesInteraction: Bool = false,
        hasPersistentBase: Bool = true,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) {
        self.icon = .system(systemName)
        self.kind = kind
        self.isSelected = isSelected
        self.isDisabled = isDisabled
        self.suppressesInteraction = suppressesInteraction
        self.hasPersistentBase = hasPersistentBase
        self.accessibilityLabel = accessibilityLabel
        self.action = action
    }

    init(
        icon: PlaybackChromeIcon,
        kind: PlaybackChromeButtonKind = .circle,
        isSelected: Bool = false,
        isDisabled: Bool = false,
        suppressesInteraction: Bool = false,
        hasPersistentBase: Bool = true,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.kind = kind
        self.isSelected = isSelected
        self.isDisabled = isDisabled
        self.suppressesInteraction = suppressesInteraction
        self.hasPersistentBase = hasPersistentBase
        self.accessibilityLabel = accessibilityLabel
        self.action = action
    }

    var body: some View {
        Button {
            guard !isDisabled, !suppressesInteraction else {
                return
            }
            action()
        } label: {
            PlaybackChromeIconView(icon: icon, size: kind.symbolSize)
                .frame(width: kind.size, height: kind.size)
                .contentShape(Circle())
        }
        .buttonStyle(
            PlaybackChromeIconButtonStyle(
                kind: kind,
                isSelected: isSelected,
                suppressesInteraction: suppressesInteraction,
                hasPersistentBase: hasPersistentBase
            )
        )
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
            Image(systemName: "doc.on.doc")
                .font(.system(size: size, weight: .semibold))
        case .sidebar(let isOpen):
            PlaybackSidebarIconView(isOpen: isOpen, size: size)
        }
    }
}

struct PlaybackSidebarIconView: View {
    let isOpen: Bool
    let size: CGFloat

    var body: some View {
        ZStack {
            // Outer rounded rectangle outline (always drawn) using strokeBorder for perfect boundary alignment
            RoundedRectangle(cornerRadius: 3.2)
                .strokeBorder(lineWidth: 2.0)
            
            // Vertical dividing line (always drawn)
            GeometryReader { geo in
                Path { path in
                    let x = geo.size.width * 0.68
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: geo.size.height))
                }
                .stroke(lineWidth: 2.0)
            }
            
            // If open, fill the right chamber solid white
            if isOpen {
                RoundedRectangle(cornerRadius: 3.2)
                    .mask(
                        GeometryReader { geo in
                            HStack(spacing: 0) {
                                Spacer(minLength: 0)
                                // Add 1.0px to overlap the dividing line completely to prevent sub-pixel seams
                                Rectangle()
                                    .frame(width: geo.size.width * 0.32 + 1.0, height: geo.size.height)
                            }
                        }
                    )
            }
        }
        .frame(width: size, height: size)
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
    let suppressesInteraction: Bool
    let hasPersistentBase: Bool
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(foregroundColor)
            .background(
                ZStack {
                    // Outer persistent base
                    if hasPersistentBase {
                        Circle()
                            .fill(isSelected ? Color.white : PlaybackTheme.capsuleFill)
                    } else if isSelected {
                        // Grouped buttons inside capsule: draw active white circle base
                        Circle()
                            .fill(Color.white)
                    }

                    // Concentric inner hover circle
                    if isInteractive && !isSelected && (isHovered || configuration.isPressed) {
                        Circle()
                            .fill(PlaybackTheme.capsuleHoverFill)
                            .scaleEffect(0.85)
                    }
                }
            )
            .scaleEffect(configuration.isPressed && isInteractive ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .animation(.easeInOut(duration: 0.15), value: isHovered)
            .onHover { isHovered = suppressesInteraction ? false : $0 }
            .onChange(of: suppressesInteraction) { isSuppressed in
                if isSuppressed {
                    isHovered = false
                }
            }
    }

    private var foregroundColor: Color {
        guard isEnabled else {
            return .white.opacity(0.34)
        }
        return isSelected ? Color(red: 0.10, green: 0.10, blue: 0.12) : .white.opacity(0.96)
    }

    private var isInteractive: Bool {
        isEnabled && !suppressesInteraction
    }
}
