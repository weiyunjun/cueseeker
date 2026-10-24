import AppKit
import SwiftUI

/// Cue queue playback control bar positioned above the left side of the player
/// progress bar during Search and Excerpt cue queue playback.
@MainActor
struct PlaybackCueQueueControlBar: View {
    // Observed so labels and tooltips update immediately when language changes.
    @EnvironmentObject private var localization: AppLocalizationStore
    @ObservedObject var settings: SettingsStore

    var body: some View {
        let isAutoPauseEnabled = settings.autoPauseAfterCueFinishesEnabled
        let isAutoSwitchEnabled = settings.autoSwitchToNextCuesInPlaylistEnabled

        HStack(spacing: PlaybackChromeMetrics.cueQueueBarItemGap) {
            PlaybackCueQueueToggleButton(
                label: L("playback.auto_pause"),
                isOn: isAutoPauseEnabled,
                isDisabled: false,
                accessibilityLabel: L("settings.play.auto_pause"),
                action: {
                    settings.autoPauseAfterCueFinishesEnabled.toggle()
                }
            )
            .workbenchTooltip(
                scenarioID: "player.control.auto_pause",
                label: L("settings.play.auto_pause")
            )

            PlaybackCueQueueToggleButton(
                label: L("playback.auto_switch"),
                isOn: isAutoSwitchEnabled,
                isDisabled: !isAutoPauseEnabled,
                accessibilityLabel: L("settings.play.auto_switch"),
                action: {
                    settings.autoSwitchToNextCuesInPlaylistEnabled.toggle()
                }
            )
            .workbenchTooltip(
                scenarioID: "player.control.auto_switch",
                label: isAutoPauseEnabled
                    ? L("settings.play.auto_switch")
                    : L("tooltip.disabled.settings.play.auto_switch")
            )

            PlaybackCueQueueGapStepper(
                gapMilliseconds: settings.autoSwitchCueSequenceGapMilliseconds,
                isEnabled: isAutoSwitchEnabled,
                canDecrease: settings.canDecreaseAutoSwitchCueSequenceGap,
                canIncrease: settings.canIncreaseAutoSwitchCueSequenceGap,
                onDecrease: {
                    settings.decreaseAutoSwitchCueSequenceGapMilliseconds()
                },
                onIncrease: {
                    settings.increaseAutoSwitchCueSequenceGapMilliseconds()
                }
            )
        }
        .padding(PlaybackChromeMetrics.cueQueueBarPadding)
        .frame(height: PlaybackChromeMetrics.cueQueueBarHeight)
        .background(
            RoundedRectangle(
                cornerRadius: PlaybackChromeMetrics.cueQueueBarRadius,
                style: .continuous
            )
            .fill(PlaybackTheme.menuBackground)
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: PlaybackChromeMetrics.cueQueueBarRadius,
                style: .continuous
            )
            .strokeBorder(
                PlaybackTheme.cueControlBarBorder,
                lineWidth: WorkbenchControlMetrics.redesignControlBorderWidth
            )
        )
        .contentShape(
            RoundedRectangle(
                cornerRadius: PlaybackChromeMetrics.cueQueueBarRadius,
                style: .continuous
            )
        )
        .onTapGesture {}
        .playerInteractiveRegion()
    }
}

private struct PlaybackCueQueueToggleButton: View {
    let label: String
    let isOn: Bool
    let isDisabled: Bool
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button {
            guard !isDisabled else {
                return
            }
            action()
        } label: {
            HStack(spacing: PlaybackChromeMetrics.cueQueueToggleDotGap) {
                Circle()
                    .fill(
                        isOn
                            ? PlaybackTheme.cueControlStatusActive
                            : PlaybackTheme.textTertiary
                    )
                    .frame(
                        width: PlaybackChromeMetrics.cueQueueStatusDotSize,
                        height: PlaybackChromeMetrics.cueQueueStatusDotSize
                    )

                Text(label)
                    .font(
                        .system(
                            size: PlaybackChromeMetrics.cueQueueToggleFontSize,
                            weight: .semibold
                        )
                    )
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .padding(.horizontal, PlaybackChromeMetrics.cueQueueToggleHorizontalPadding)
            .frame(height: PlaybackChromeMetrics.cueQueueControlHeight)
            .contentShape(
                RoundedRectangle(
                    cornerRadius: PlaybackChromeMetrics.cueQueueControlRadius,
                    style: .continuous
                )
            )
        }
        .buttonStyle(
            PlaybackCueQueueToggleButtonStyle(isOn: isOn)
        )
        .disabled(isDisabled)
        .opacity(isDisabled ? PlaybackChromeMetrics.cueQueueDisabledOpacity : 1)
        .focusable(false)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(isOn ? "1" : "0")
    }
}

private struct PlaybackCueQueueToggleButtonStyle: ButtonStyle {
    let isOn: Bool
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(foregroundColor(isPressed: configuration.isPressed))
            .background(
                RoundedRectangle(
                    cornerRadius: PlaybackChromeMetrics.cueQueueControlRadius,
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

    private func foregroundColor(isPressed: Bool) -> Color {
        guard isEnabled else {
            return PlaybackTheme.textSecondary
        }
        if isOn || isHovered || isPressed {
            return PlaybackTheme.textPrimary
        }
        return PlaybackTheme.textSecondary
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        guard isEnabled else {
            return Color.clear
        }
        if isPressed {
            return PlaybackTheme.controlPressedBackground
        }
        if isOn {
            return isHovered
                ? PlaybackTheme.menuItemSelectedBackground
                : PlaybackTheme.controlHoverBackground
        }
        if isHovered {
            return PlaybackTheme.menuItemHoverBackground
        }
        return Color.clear
    }
}

private struct PlaybackCueQueueGapStepper: View {
    let gapMilliseconds: Int
    let isEnabled: Bool
    let canDecrease: Bool
    let canIncrease: Bool
    let onDecrease: () -> Void
    let onIncrease: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            PlaybackCueQueueStepperIconButton(
                icon: .minus,
                isDisabled: !isEnabled || !canDecrease,
                accessibilityLabel: L("tooltip.player.auto_switch_gap.decrease"),
                action: onDecrease
            )
            .workbenchTooltip(
                scenarioID: "player.control.auto_switch_gap.decrease",
                isActive: isEnabled,
                label: canDecrease
                    ? L("tooltip.player.auto_switch_gap.decrease")
                    : L("tooltip.player.auto_switch_gap.decrease.disabled")
            )

            Text("\(gapMilliseconds) ms")
                .font(
                    .system(
                        size: PlaybackChromeMetrics.timeFontSize,
                        weight: .semibold,
                        design: .monospaced
                    )
                )
                .monospacedDigit()
                .foregroundStyle(PlaybackTheme.textPrimary)
                .lineLimit(1)
                .frame(
                    width: PlaybackChromeMetrics.cueQueueGapValueWidth,
                    height: PlaybackChromeMetrics.cueQueueStepperButtonSize,
                    alignment: .center
                )
                .allowsHitTesting(false)
                .accessibilityLabel(L("settings.play.auto_switch_gap"))
                .accessibilityValue("\(gapMilliseconds) ms")

            PlaybackCueQueueStepperIconButton(
                icon: .plus,
                isDisabled: !isEnabled || !canIncrease,
                accessibilityLabel: L("tooltip.player.auto_switch_gap.increase"),
                action: onIncrease
            )
            .workbenchTooltip(
                scenarioID: "player.control.auto_switch_gap.increase",
                isActive: isEnabled,
                label: canIncrease
                    ? L("tooltip.player.auto_switch_gap.increase")
                    : L("tooltip.player.auto_switch_gap.increase.disabled")
            )
        }
        .padding(PlaybackChromeMetrics.cueQueueStepperPadding)
        .frame(height: PlaybackChromeMetrics.cueQueueControlHeight)
        .background(
            RoundedRectangle(
                cornerRadius: PlaybackChromeMetrics.cueQueueControlRadius,
                style: .continuous
            )
            .fill(PlaybackTheme.cueControlStepperBackground)
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: PlaybackChromeMetrics.cueQueueControlRadius,
                style: .continuous
            )
            .strokeBorder(
                PlaybackTheme.cueControlStepperBorder,
                lineWidth: WorkbenchControlMetrics.redesignControlBorderWidth
            )
        )
        .opacity(isEnabled ? 1 : PlaybackChromeMetrics.cueQueueDisabledOpacity)
        .workbenchTooltip(
            scenarioID: "player.control.auto_switch_gap.disabled",
            isActive: !isEnabled,
            label: L("tooltip.player.auto_switch_gap.disabled")
        )
    }
}

private struct PlaybackCueQueueStepperIconButton: View {
    let icon: AppIcon
    let isDisabled: Bool
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button {
            guard !isDisabled else {
                return
            }
            action()
        } label: {
            AppIconImage(
                icon,
                size: PlaybackChromeMetrics.cueQueueStepperIconSize
            )
            .frame(
                width: PlaybackChromeMetrics.cueQueueStepperButtonSize,
                height: PlaybackChromeMetrics.cueQueueStepperButtonSize
            )
            .contentShape(
                RoundedRectangle(
                    cornerRadius: PlaybackChromeMetrics.cueQueueStepperButtonRadius,
                    style: .continuous
                )
            )
        }
        .buttonStyle(PlaybackCueQueueStepperIconButtonStyle())
        .disabled(isDisabled)
        .focusable(false)
        .accessibilityLabel(accessibilityLabel)
    }
}

private struct PlaybackCueQueueStepperIconButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(
                isEnabled ? PlaybackTheme.textPrimary : PlaybackTheme.textTertiary
            )
            .background(
                RoundedRectangle(
                    cornerRadius: PlaybackChromeMetrics.cueQueueStepperButtonRadius,
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

    private func backgroundColor(isPressed: Bool) -> Color {
        guard isEnabled else {
            return Color.clear
        }
        if isPressed {
            return PlaybackTheme.controlPressedBackground
        }
        if isHovered {
            return PlaybackTheme.controlHoverBackground
        }
        return Color.clear
    }
}
