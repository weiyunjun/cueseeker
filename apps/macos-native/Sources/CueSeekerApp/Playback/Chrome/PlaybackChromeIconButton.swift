import SwiftUI

enum PlaybackChromeButtonKind {
    case circle
    case transport
    case primaryTransport

    var size: CGFloat {
        switch self {
        case .circle:
            return PlaybackChromeMetrics.circleButtonSize
        case .transport:
            return PlaybackChromeMetrics.circleButtonSize
        case .primaryTransport:
            return 44
        }
    }

    var symbolSize: CGFloat {
        switch self {
        case .circle:
            return PlaybackChromeMetrics.circleButtonIconSize
        case .transport:
            return PlaybackChromeMetrics.circleButtonIconSize
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
        }
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
                            .fill(isSelected ? PlaybackTheme.textPrimary : PlaybackTheme.controlBackground)
                    } else if isSelected {
                        // Grouped buttons inside capsule: draw active white circle base
                        Circle()
                            .fill(PlaybackTheme.textPrimary)
                    }

                    // Concentric inner hover circle
                    if isInteractive && !isSelected && (isHovered || configuration.isPressed) {
                        Circle()
                            .fill(PlaybackTheme.controlHoverBackground)
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
            return PlaybackTheme.textTertiary
        }
        return isSelected ? PlaybackTheme.iconSelected : PlaybackTheme.textPrimary
    }

    private var isInteractive: Bool {
        isEnabled && !suppressesInteraction
    }
}
