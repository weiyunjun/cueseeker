import AppKit
import SwiftUI

@MainActor
struct PlaybackChromeControls {
    let canGoPrevious: Bool
    let goPrevious: () -> Void
    let togglePlayPause: () -> Void
    let canGoNext: Bool
    let goNext: () -> Void
    let isFullscreen: Bool
    let isFullscreenToggleDisabled: Bool
    let toggleFullscreen: () -> Void
}

@MainActor
extension PlaybackChromeControls {
    static func appState(
        _ appState: AppCoordinator,
        snapshot: PlaybackChromeSnapshot,
        isFullscreen: Bool,
        isFullscreenToggleDisabled: Bool,
        fullscreenAction: (() -> Void)? = nil
    ) -> PlaybackChromeControls {
        PlaybackChromeControls(
            canGoPrevious: snapshot.canGoPrevious,
            goPrevious: { appState.goPrevious() },
            togglePlayPause: appState.togglePlaybackFromUser,
            canGoNext: snapshot.canGoNext,
            goNext: { appState.goNext() },
            isFullscreen: isFullscreen,
            isFullscreenToggleDisabled: isFullscreenToggleDisabled,
            toggleFullscreen: fullscreenAction ?? {
                appState.togglePlaybackFullscreenFromUser()
            }
        )
    }
}

private struct PlaybackSpeedButtonAnchorKey: PreferenceKey {
    static let defaultValue: Anchor<CGRect>? = nil

    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = nextValue() ?? value
    }
}

@MainActor
struct PlaybackChromeView: View {
    let viewModel: PlaybackViewModel
    let timeline: PlaybackTimelineInteractionStore
    let controls: PlaybackChromeControls
    @State private var isSpeedMenuVisible = false
    @State private var speedMenuEventMonitor: Any?
    @State private var speedButtonFrame: CGRect = .zero
    @State private var isTimeHovered = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.clear
                .allowsHitTesting(false)

            chromeSurface
                .zIndex(1)
        }
        .frame(height: PlaybackChromeMetrics.interactiveHeight, alignment: .bottom)
        .overlayPreferenceValue(PlaybackSpeedButtonAnchorKey.self) { anchor in
            speedMenuOverlay(anchor: anchor)
        }
        .background(
            PlaybackChromeTimelineResetter(
                timeline: timeline,
                isSpeedMenuVisible: $isSpeedMenuVisible,
                isTimeHovered: $isTimeHovered
            )
        )
        .onChange(of: isSpeedMenuVisible) { isVisible in
            if isVisible {
                installSpeedMenuDismissMonitor()
            } else {
                removeSpeedMenuDismissMonitor()
            }
        }
        .onDisappear {
            removeSpeedMenuDismissMonitor()
        }
    }

    private var chromeSurface: some View {
        VStack(spacing: 0) {
            scrubberRow
                .padding(.top, PlaybackChromeMetrics.progressTopPadding)

            HStack(spacing: 0) {
                leftGroup

                Spacer(minLength: 0)

                rightGroup
            }
            .padding(.horizontal, PlaybackChromeMetrics.chromeHorizontalPadding)
            .frame(height: PlaybackChromeMetrics.bottomControlsRowHeight)
            .padding(.bottom, PlaybackChromeMetrics.chromeBottomPadding)
        }
        .contentShape(Rectangle())
    }

    @MainActor
    @ViewBuilder
    private func speedMenuOverlay(anchor: Anchor<CGRect>?) -> some View {
        if isSpeedMenuVisible, let anchor {
            GeometryReader { proxy in
                let buttonFrame = proxy[anchor]
                let menuWidth = PlaybackChromeMetrics.speedMenuWidth
                let menuHeight = PlaybackChromeMetrics.speedMenuHeight
                let x = min(
                    max(buttonFrame.maxX - menuWidth / 2, menuWidth / 2),
                    proxy.size.width - menuWidth / 2
                )
                let calculatedY = buttonFrame.minY - PlaybackChromeMetrics.speedMenuGap - menuHeight / 2
                let maxMenuCenterY = proxy.size.width > 0
                    ? proxy.size.height - PlaybackChromeMetrics.height + PlaybackChromeMetrics.speedMenuOverlapClearance - menuHeight / 2
                    : calculatedY
                let y = max(
                    menuHeight / 2,
                    min(calculatedY, maxMenuCenterY)
                )

                PlaybackChromeSpeedMenu(
                    selectedSpeed: viewModel.playbackSpeed,
                    suppressesInteraction: timeline.isScrubbing,
                    onSelect: { speed in
                        viewModel.setSpeed(speed)
                        isSpeedMenuVisible = false
                    }
                )
                .frame(width: menuWidth, height: menuHeight)
                .position(x: x, y: y)
                .zIndex(2)
            }
        }
    }

    private var scrubberRow: some View {
        PlaybackProgressScrubber(
            viewModel: viewModel,
            timeline: timeline
        )
            .padding(.horizontal, PlaybackChromeMetrics.chromeHorizontalPadding)
    }

    private var leftGroup: some View {
        HStack(spacing: PlaybackChromeMetrics.leftControlsGap) {
            PlaybackPlayPauseChromeButton(
                viewModel: viewModel,
                timeline: timeline,
                action: controls.togglePlayPause
            )

            HStack(spacing: 0) {
                PlaybackTimelineChromeIconButton(
                    timeline: timeline,
                    systemName: "backward.end.fill",
                    kind: .transport,
                    isDisabled: !controls.canGoPrevious,
                    hasPersistentBase: false,
                    accessibilityLabel: "Previous video",
                    action: controls.goPrevious
                )

                PlaybackTimelineChromeIconButton(
                    timeline: timeline,
                    systemName: "forward.end.fill",
                    kind: .transport,
                    isDisabled: !controls.canGoNext,
                    hasPersistentBase: false,
                    accessibilityLabel: "Next video",
                    action: controls.goNext
                )
            }
            .frame(height: PlaybackChromeMetrics.capsuleButtonHeight)
            .background(Capsule().fill(PlaybackTheme.controlBackground))

            PlaybackVolumeControl(
                viewModel: viewModel,
                timeline: timeline
            )

            PlaybackChromeTimeCapsule(
                viewModel: viewModel,
                timeline: timeline,
                isTimeHovered: $isTimeHovered
            )
        }
    }

    private var rightGroup: some View {
        HStack(spacing: PlaybackChromeMetrics.rightControlsGap) {
            PlaybackTimelineChromeIconButton(
                timeline: timeline,
                systemName: "photo",
                kind: .transport,
                accessibilityLabel: "Copy screenshot",
                action: viewModel.copyCurrentFrameScreenshot
            )

            PlaybackSubtitleChromeButton(
                viewModel: viewModel,
                timeline: timeline
            )

            speedControl

            PlaybackTimelineChromeIconButton(
                timeline: timeline,
                systemName: controls.isFullscreen
                    ? "arrow.down.right.and.arrow.up.left"
                    : "viewfinder",
                kind: .transport,
                isDisabled: controls.isFullscreenToggleDisabled,
                accessibilityLabel: "Fullscreen",
                action: controls.toggleFullscreen
            )
        }
    }

    private var speedControl: some View {
        PlaybackSpeedChromeButton(
            viewModel: viewModel,
            timeline: timeline,
            isSpeedMenuVisible: $isSpeedMenuVisible,
            speedButtonFrame: $speedButtonFrame
        )
        .anchorPreference(key: PlaybackSpeedButtonAnchorKey.self, value: .bounds) { $0 }
    }

    private func installSpeedMenuDismissMonitor() {
        removeSpeedMenuDismissMonitor()
        speedMenuEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { event in
            if isSpeedMenuVisible {
                if let window = event.window {
                    let windowHeight = window.contentView?.bounds.height ?? 0
                    let clickPoint = CGPoint(
                        x: event.locationInWindow.x,
                        y: windowHeight - event.locationInWindow.y
                    )
                    if speedButtonFrame.contains(clickPoint) {
                        // Let the button action handle toggling isSpeedMenuVisible to false
                        return event
                    }
                }
                DispatchQueue.main.async {
                    isSpeedMenuVisible = false
                }
            }
            return event
        }
    }

    private func removeSpeedMenuDismissMonitor() {
        if let speedMenuEventMonitor {
            NSEvent.removeMonitor(speedMenuEventMonitor)
            self.speedMenuEventMonitor = nil
        }
    }

}

private struct PlaybackChromeTimelineResetter: View {
    @ObservedObject var timeline: PlaybackTimelineInteractionStore
    @Binding var isSpeedMenuVisible: Bool
    @Binding var isTimeHovered: Bool

    var body: some View {
        Color.clear
            .allowsHitTesting(false)
            .onChange(of: timeline.isScrubbing) { isScrubbing in
                if isScrubbing {
                    isSpeedMenuVisible = false
                    isTimeHovered = false
                }
            }
    }
}

private struct PlaybackTimelineChromeIconButton: View {
    @ObservedObject var timeline: PlaybackTimelineInteractionStore
    let systemName: String
    var kind: PlaybackChromeButtonKind = .circle
    var isSelected = false
    var isDisabled = false
    var hasPersistentBase = true
    let accessibilityLabel: String
    let action: () -> Void

    init(
        timeline: PlaybackTimelineInteractionStore,
        systemName: String,
        kind: PlaybackChromeButtonKind = .circle,
        isSelected: Bool = false,
        isDisabled: Bool = false,
        hasPersistentBase: Bool = true,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) {
        self.timeline = timeline
        self.systemName = systemName
        self.kind = kind
        self.isSelected = isSelected
        self.isDisabled = isDisabled
        self.hasPersistentBase = hasPersistentBase
        self.accessibilityLabel = accessibilityLabel
        self.action = action
    }

    var body: some View {
        PlaybackChromeIconButton(
            systemName: systemName,
            kind: kind,
            isSelected: isSelected,
            isDisabled: isDisabled,
            suppressesInteraction: timeline.isScrubbing,
            hasPersistentBase: hasPersistentBase,
            accessibilityLabel: accessibilityLabel,
            action: action
        )
    }
}

private struct PlaybackPlayPauseChromeButton: View {
    @ObservedObject var viewModel: PlaybackViewModel
    @ObservedObject var timeline: PlaybackTimelineInteractionStore
    let action: () -> Void

    var body: some View {
        PlaybackChromeIconButton(
            systemName: viewModel.isPlaying ? "pause.fill" : "play.fill",
            kind: .transport,
            suppressesInteraction: timeline.isScrubbing,
            accessibilityLabel: viewModel.isPlaying ? "Pause" : "Play",
            action: action
        )
    }
}

private struct PlaybackSubtitleChromeButton: View {
    @ObservedObject var viewModel: PlaybackViewModel
    @ObservedObject var timeline: PlaybackTimelineInteractionStore

    var body: some View {
        PlaybackChromeIconButton(
            systemName: viewModel.areSubtitlesVisible ? "captions.bubble.fill" : "captions.bubble",
            kind: .circle,
            isSelected: viewModel.areSubtitlesVisible,
            suppressesInteraction: timeline.isScrubbing,
            accessibilityLabel: "Subtitles",
            action: viewModel.toggleSubtitles
        )
    }
}

private struct PlaybackChromeTimeCapsule: View {
    @ObservedObject var viewModel: PlaybackViewModel
    @ObservedObject var timeline: PlaybackTimelineInteractionStore
    @ObservedObject private var scrubTimeStore: PlaybackTimelineScrubTimeStore
    @Binding var isTimeHovered: Bool

    init(
        viewModel: PlaybackViewModel,
        timeline: PlaybackTimelineInteractionStore,
        isTimeHovered: Binding<Bool>
    ) {
        self.viewModel = viewModel
        self.timeline = timeline
        _scrubTimeStore = ObservedObject(wrappedValue: timeline.scrubTimeStore)
        _isTimeHovered = isTimeHovered
    }

    var body: some View {
        HStack(spacing: PlaybackChromeMetrics.timeLabelGap) {
            Text(formatPlaybackTime(scrubTimeStore.scrubTime ?? viewModel.displayedCurrentTime))
                .foregroundStyle(PlaybackTheme.textPrimary)
            Text("/")
                .foregroundStyle(PlaybackTheme.textTertiary)
            Text(formatPlaybackTime(viewModel.duration))
                .foregroundStyle(PlaybackTheme.textPrimary)
        }
        .font(.system(size: PlaybackChromeMetrics.timeFontSize, weight: .semibold, design: .monospaced))
        .monospacedDigit()
        .padding(.horizontal, PlaybackChromeMetrics.capsuleButtonHorizontalPadding)
        .frame(height: PlaybackChromeMetrics.capsuleButtonHeight)
        .background(
            PlaybackCinematicBacking(
                shape: Capsule(),
                isHovered: isTimeHovered,
                scaleX: 0.92,
                scaleY: 0.85
            )
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isTimeHovered = timeline.isScrubbing ? false : hovering
            }
        }
    }
}

private struct PlaybackSpeedChromeButton: View {
    @ObservedObject var viewModel: PlaybackViewModel
    @ObservedObject var timeline: PlaybackTimelineInteractionStore
    @Binding var isSpeedMenuVisible: Bool
    @Binding var speedButtonFrame: CGRect

    var body: some View {
        Button {
            guard !timeline.isScrubbing else {
                return
            }
            isSpeedMenuVisible.toggle()
        } label: {
            Text(PlaybackViewModel.formatSpeed(viewModel.playbackSpeed))
                .font(.system(size: PlaybackChromeMetrics.timeFontSize, weight: .semibold))
                .monospacedDigit()
                .frame(width: PlaybackChromeMetrics.speedButtonWidth, height: PlaybackChromeMetrics.capsuleButtonHeight)
                .contentShape(Capsule())
        }
        .buttonStyle(
            PlaybackChromeCapsuleButtonStyle(
                suppressesInteraction: timeline.isScrubbing
            )
        )
        .accessibilityLabel("Playback speed")
        .frame(
            width: PlaybackChromeMetrics.speedButtonWidth,
            height: PlaybackChromeMetrics.capsuleButtonHeight,
            alignment: .center
        )
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear {
                        updateSpeedButtonFrame(geo.frame(in: .global))
                    }
                    .onChange(of: geo.frame(in: .global)) { newFrame in
                        updateSpeedButtonFrame(newFrame)
                    }
            }
        )
    }

    private func updateSpeedButtonFrame(_ newFrame: CGRect) {
        guard speedButtonFrame != newFrame else {
            return
        }
        speedButtonFrame = newFrame
    }
}

private func formatPlaybackTime(_ seconds: Double) -> String {
    let safeSeconds = seconds.isFinite ? max(0, seconds) : 0
    let totalSeconds = Int(safeSeconds.rounded(.down))
    let hours = totalSeconds / 3_600
    let minutes = (totalSeconds % 3_600) / 60
    let seconds = totalSeconds % 60

    if hours > 0 {
        return String(format: "%d:%02d:%02d", hours, minutes, seconds)
    }

    return String(format: "%02d:%02d", minutes, seconds)
}

private struct PlaybackChromeCapsuleButtonStyle: ButtonStyle {
    var suppressesInteraction = false
    @State private var isHovered = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(foregroundColor)
            .background(
                PlaybackCinematicBacking(
                    shape: Capsule(),
                    isHovered: isInteractive && isHovered,
                    isPressed: isInteractive && configuration.isPressed,
                    scaleX: 0.88,
                    scaleY: 0.85
                )
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
        isEnabled ? PlaybackTheme.textPrimary : PlaybackTheme.textTertiary
    }

    private var isInteractive: Bool {
        isEnabled && !suppressesInteraction
    }
}
