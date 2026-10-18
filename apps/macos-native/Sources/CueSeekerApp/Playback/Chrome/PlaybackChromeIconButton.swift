import SwiftUI

struct PlaybackChromeIconButton: View {
    let icon: AppIcon
    var iconWeight: AppIconWeight?
    var isSelected = false
    /// The menu it opens is open; it looks hovered for as long.
    var isOpen = false
    var isDisabled = false
    var suppressesInteraction = false
    let accessibilityLabel: String
    let action: () -> Void

    init(
        icon: AppIcon,
        iconWeight: AppIconWeight? = nil,
        isSelected: Bool = false,
        isOpen: Bool = false,
        isDisabled: Bool = false,
        suppressesInteraction: Bool = false,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.iconWeight = iconWeight
        self.isSelected = isSelected
        self.isOpen = isOpen
        self.isDisabled = isDisabled
        self.suppressesInteraction = suppressesInteraction
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
            AppIconImage(
                icon,
                size: WorkbenchControlMetrics.redesignControlIconSize,
                weight: iconWeight
            )
            .frame(
                width: WorkbenchControlMetrics.redesignIconButtonSize,
                height: WorkbenchControlMetrics.redesignIconButtonSize
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
                isSelected: isSelected,
                isOpen: isOpen,
                suppressesInteraction: suppressesInteraction
            )
        )
        .disabled(isDisabled)
        .focusable(false)
        .accessibilityLabel(accessibilityLabel)
        .playerInteractiveRegion()
    }
}

private struct PlaybackChromeIconButtonStyle: ButtonStyle {
    let isSelected: Bool
    let isOpen: Bool
    let suppressesInteraction: Bool
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
                .fill(backgroundColor)
            )
            .onPointerHover { isHovered = suppressesInteraction ? false : $0 }
            .onChange(of: suppressesInteraction) { isSuppressed in
                if isSuppressed {
                    isHovered = false
                }
            }
    }

    private var foregroundColor: Color {
        isEnabled ? PlaybackTheme.textPrimary : PlaybackTheme.textTertiary
    }

    private var backgroundColor: Color {
        guard isInteractive else {
            return Color.clear
        }
        if isHovered || isOpen || isSelected {
            return PlaybackTheme.controlHoverBackground
        }
        return Color.clear
    }

    private var isInteractive: Bool {
        isEnabled && !suppressesInteraction
    }
}
