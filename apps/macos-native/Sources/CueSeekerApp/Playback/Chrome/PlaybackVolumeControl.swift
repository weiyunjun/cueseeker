import SwiftUI

struct PlaybackVolumeControl: View {
    @ObservedObject var viewModel: PlaybackViewModel
    @ObservedObject var timeline: PlaybackTimelineInteractionStore
    @State private var isHovered = false
    @State private var isSpeakerPressed = false

    var body: some View {
        HStack(spacing: 0) {
            Button {
                guard !timeline.isScrubbing else {
                    return
                }
                viewModel.toggleMute()
            } label: {
                AppIconImage(
                    volumeIcon,
                    size: WorkbenchControlMetrics.redesignControlIconSize
                )
                .foregroundStyle(PlaybackTheme.textPrimary)
                .frame(
                    width: WorkbenchControlMetrics.redesignIconButtonSize,
                    height: WorkbenchControlMetrics.redesignIconButtonSize
                )
                .background(
                    RoundedRectangle(
                        cornerRadius: WorkbenchControlMetrics.redesignCornerRadius,
                        style: .continuous
                    )
                    .fill(
                        !timeline.isScrubbing && isSpeakerPressed
                            ? PlaybackTheme.controlPressedBackground
                            : Color.clear
                    )
                )
                .contentShape(
                    RoundedRectangle(
                        cornerRadius: WorkbenchControlMetrics.redesignCornerRadius,
                        style: .continuous
                    )
                )
            }
            .buttonStyle(PressableButtonStyle(isPressed: $isSpeakerPressed, isHovered: $isHovered))
            .focusable(false)
            .workbenchTooltip(
                scenarioID: "player.control.mute",
                isActive: !timeline.isScrubbing,
                label: viewModel.volume <= 0 ? L("tooltip.player.unmute") : L("playback.mute")
            )
            .accessibilityLabel(L("playback.mute"))

            if isHovered {
                HStack(spacing: WorkbenchControlMetrics.redesignSpacing1) {
                    PlaybackVolumeSlider(
                        volume: Binding(
                            get: { viewModel.volume },
                            set: { viewModel.setVolume($0, showsFeedback: false) }
                        ),
                        timeline: timeline
                    )
                    .frame(
                        width: PlaybackChromeMetrics.volumeSliderWidth,
                        height: WorkbenchControlMetrics.redesignIconButtonSize
                    )

                    Text("\(Int(viewModel.volume.rounded()))%")
                        .font(.system(
                            size: PlaybackChromeMetrics.timeFontSize,
                            weight: .semibold,
                            design: .monospaced
                        ))
                        .foregroundStyle(PlaybackTheme.textPrimary)
                        .monospacedDigit()
                        .frame(
                            width: PlaybackChromeMetrics.volumeValueWidth,
                            alignment: .trailing
                        )
                }
                .padding(.trailing, PlaybackChromeMetrics.volumeTrailingPadding)
                .transition(.opacity)
            }
        }
        .frame(
            width: isHovered
                ? PlaybackChromeMetrics.volumeExpandedWidth
                : WorkbenchControlMetrics.redesignIconButtonSize,
            height: WorkbenchControlMetrics.redesignIconButtonSize,
            alignment: .leading
        )
        .background(
            RoundedRectangle(
                cornerRadius: WorkbenchControlMetrics.redesignCornerRadius,
                style: .continuous
            )
            .fill(
                !timeline.isScrubbing && isHovered
                    ? PlaybackTheme.controlHoverBackground
                    : Color.clear
            )
        )
        .playerInteractiveRegion()
        .onPointerHover { hovering in
            withAnimation(.easeInOut(duration: PlaybackChromeMetrics.volumeExpandDuration)) {
                isHovered = timeline.isScrubbing ? false : hovering
            }
        }
        .onChange(of: timeline.isScrubbing) { isScrubbing in
            if isScrubbing {
                withAnimation(.easeInOut(duration: PlaybackChromeMetrics.volumeExpandDuration)) {
                    isHovered = false
                }
            }
        }
    }

    private var volumeIcon: AppIcon {
        viewModel.volume <= 0 ? .speakerX : .speakerHigh
    }
}

private struct PlaybackVolumeSlider: View {
    @Binding var volume: Double
    let timeline: PlaybackTimelineInteractionStore

    var body: some View {
        GeometryReader { geometry in
            let width = max(0, geometry.size.width)
            let progress = min(max(volume / 100, 0), 1)
            let thumbSize = PlaybackChromeMetrics.volumeThumbSize
            let trackHeight = PlaybackChromeMetrics.progressTrackHeight

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(PlaybackTheme.progressTrack)
                    .frame(height: trackHeight)

                Capsule()
                    .fill(Color.white)
                    .frame(width: width * progress, height: trackHeight)

                Circle()
                    .fill(Color.white)
                    .frame(width: thumbSize, height: thumbSize)
                    .offset(x: max(0, (width - thumbSize) * progress))
            }
            .frame(height: WorkbenchControlMetrics.redesignIconButtonSize, alignment: .center)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        timeline.isDraggingVolume = true
                        volume = Double(min(max(value.location.x / max(width, 1), 0), 1)) * 100
                    }
                    .onEnded { _ in
                        timeline.isDraggingVolume = false
                    }
            )
        }
        .onDisappear {
            timeline.isDraggingVolume = false
        }
    }
}
