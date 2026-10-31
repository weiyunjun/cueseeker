import SwiftUI

struct PlaybackChromeIconButton: View {
    let icon: AppIcon
    var iconWeight: AppIconWeight?
    /// The menu or mode it controls is open; it looks hovered for as long.
    var isOpen = false
    var isDisabled = false
    var isFocused = false
    let accessibilityLabel: String
    let action: () -> Void

    init(
        icon: AppIcon,
        iconWeight: AppIconWeight? = nil,
        isOpen: Bool = false,
        isDisabled: Bool = false,
        isFocused: Bool = false,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.iconWeight = iconWeight
        self.isOpen = isOpen
        self.isDisabled = isDisabled
        self.isFocused = isFocused
        self.accessibilityLabel = accessibilityLabel
        self.action = action
    }

    var body: some View {
        Button {
            guard !isDisabled else {
                return
            }
            action()
        } label: {
            AppIconImage(
                icon,
                size: WorkbenchControlMetrics.redesignControlIconSize,
                weight: iconWeight
            )
            .frame(
                width: WorkbenchControlMetrics.redesignIconButtonSize,
                height: WorkbenchControlMetrics.redesignIconButtonSize
            )
            .workbenchAccessibilityFocusRing(
                isFocused: isFocused,
                cornerRadius: WorkbenchControlMetrics.redesignCornerRadius,
                isPlayerChrome: true
            )
            .contentShape(
                RoundedRectangle(
                    cornerRadius: WorkbenchControlMetrics.redesignCornerRadius,
                    style: .continuous
                )
            )
        }
        .buttonStyle(
            PlaybackChromeIconButtonStyle(
                isOpen: isOpen
            )
        )
        .disabled(isDisabled)
        .focusable(false)
        .accessibilityLabel(accessibilityLabel)
        .playerInteractiveRegion()
    }
}

private struct PlaybackChromeIconButtonStyle: ButtonStyle {
    let isOpen: Bool
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(foregroundColor)
            .background(
                RoundedRectangle(
                    cornerRadius: WorkbenchControlMetrics.redesignCornerRadius,
                    style: .continuous
                )
                .fill(backgroundColor(isPressed: configuration.isPressed))
            )
            .onPointerHover { isHovered = $0 }
            .onChange(of: configuration.isPressed) { newValue in
                if newValue {
                    isHovered = true
                } else if (NSEvent.pressedMouseButtons & 1) != 0 {
                    isHovered = false
                }
            }
    }

    private var foregroundColor: Color {
        isEnabled ? PlaybackTheme.textPrimary : PlaybackTheme.textTertiary
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        guard isEnabled else {
            return Color.clear
        }
        if isPressed {
            return PlaybackTheme.controlPressedBackground
        }
        if isHovered || isOpen {
            return PlaybackTheme.controlHoverBackground
        }
        return Color.clear
    }
}
