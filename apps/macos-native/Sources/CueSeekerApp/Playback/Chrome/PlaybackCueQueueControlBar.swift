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

        WorkbenchAccessibilityReader { accessibility in
            HStack(spacing: PlaybackChromeMetrics.cueQueueBarItemGap) {
                PlaybackCueQueueToggleButton(
                    label: L("playback.auto_pause"),
                    isOn: isAutoPauseEnabled,
                    isDisabled: false,
                    isFocused: accessibility?.isPlaybackFocused(.playerAutoPause) == true,
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
                    isFocused: accessibility?.isPlaybackFocused(.playerAutoSwitch) == true,
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
                    isDecreaseFocused: accessibility?.isPlaybackFocused(.playerAutoSwitchGapDecrease) == true,
                    isIncreaseFocused: accessibility?.isPlaybackFocused(.playerAutoSwitchGapIncrease) == true,
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
}

private struct PlaybackCueQueueToggleButton: View {
    let label: String
    let isOn: Bool
    let isDisabled: Bool
    var isFocused: Bool = false
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
                        isOn && !isDisabled
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
            .workbenchAccessibilityFocusRing(
                isFocused: isFocused,
                cornerRadius: PlaybackChromeMetrics.cueQueueControlRadius,
                isPlayerChrome: true
            )
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
            return PlaybackTheme.textTertiary
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
        if isHovered || isOn {
            return PlaybackTheme.controlHoverBackground
        }
        return Color.clear
    }
}

private struct PlaybackCueQueueGapStepper: View {
    let gapMilliseconds: Int
    let isEnabled: Bool
    let canDecrease: Bool
    let canIncrease: Bool
    var isDecreaseFocused: Bool = false
    var isIncreaseFocused: Bool = false
    let onDecrease: () -> Void
    let onIncrease: () -> Void

    var body: some View {
        let decreaseLabel = L(
            "tooltip.player.auto_switch_gap.decrease",
            SettingsStore.autoSwitchCueSequenceGapStepMilliseconds
        )
        let decreaseDisabledLabel = L(
            "tooltip.player.auto_switch_gap.decrease.disabled",
            SettingsStore.autoSwitchCueSequenceGapMinimumMilliseconds
        )
        let increaseLabel = L(
            "tooltip.player.auto_switch_gap.increase",
            SettingsStore.autoSwitchCueSequenceGapStepMilliseconds
        )
        let increaseDisabledLabel = L(
            "tooltip.player.auto_switch_gap.increase.disabled",
            SettingsStore.autoSwitchCueSequenceGapMaximumMilliseconds
        )

        HStack(spacing: 0) {
            PlaybackCueQueueStepperIconButton(
                icon: .minus,
                isDisabled: !isEnabled || !canDecrease,
                isFocused: isDecreaseFocused,
                accessibilityLabel: decreaseLabel,
                action: onDecrease
            )
            .workbenchTooltip(
                scenarioID: "player.control.auto_switch_gap.decrease",
                isActive: isEnabled,
                label: canDecrease ? decreaseLabel : decreaseDisabledLabel
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
                .foregroundStyle(
                    isEnabled ? PlaybackTheme.textPrimary : PlaybackTheme.textTertiary
                )
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
                isFocused: isIncreaseFocused,
                accessibilityLabel: increaseLabel,
                action: onIncrease
            )
            .workbenchTooltip(
                scenarioID: "player.control.auto_switch_gap.increase",
                isActive: isEnabled,
                label: canIncrease ? increaseLabel : increaseDisabledLabel
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
    var isFocused: Bool = false
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
            .workbenchAccessibilityFocusRing(
                isFocused: isFocused,
                cornerRadius: PlaybackChromeMetrics.cueQueueStepperButtonRadius,
                isPlayerChrome: true
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
