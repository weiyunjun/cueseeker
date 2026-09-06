import Foundation
import SwiftUI
import CueSeekerPlayback

enum PlaybackFeedbackPosition: Equatable {
    case center
    case leading
    case trailing
}

enum ShioriFeedbackState {
    case removed
    case unavailable
}

enum PlaybackFeedbackIcon: Equatable {
    case system(String)
    case copy
}

struct PlaybackFeedback: Identifiable, Equatable {
    let id = UUID()
    let position: PlaybackFeedbackPosition
    let icon: PlaybackFeedbackIcon?
    let text: String?

    init(
        position: PlaybackFeedbackPosition,
        systemImage: String? = nil,
        text: String?
    ) {
        self.position = position
        self.icon = systemImage.map { .system($0) }
        self.text = text
    }

    init(
        position: PlaybackFeedbackPosition,
        icon: PlaybackFeedbackIcon?,
        text: String?
    ) {
        self.position = position
        self.icon = icon
        self.text = text
    }
}

private struct PlaybackScreenshotRenderWorkItem: @unchecked Sendable {
    let presentation: PlaybackScreenshotPresentation
}

@MainActor
public final class PlaybackViewModel: ObservableObject {
    private struct PendingPresentation {
        var generation: UInt?
        var targetTime: Double
        let heldActiveSubtitleText: String?
        var stagedSubtitleTrack: PlaybackSubtitleTrack?
    }

    static let minimumPlaybackSpeed = 0.5
    static let maximumPlaybackSpeed = 2.0
    static let speedPresets = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0]
    private static let displayedCurrentTimePublishInterval: TimeInterval = 0.5
    private static let seekTimeProtectionDuration: TimeInterval = 1.5
    private static let seekTimeProtectionBaseTolerance = 0.75
    private static let defaultVolume = 100.0
    private static let defaultPlaybackSpeed = 1.0

    public let player: PlaybackPlayer

    @Published public var isPlaying: Bool = false
    public private(set) var currentTime: Double = 0
    @Published public private(set) var displayedCurrentTime: Double = 0
    @Published public var duration: Double = 0
    @Published public var volume: Double = 100
    @Published public var playbackSpeed: Double = 1.0
    @Published public var areSubtitlesVisible: Bool = true
    @Published public private(set) var videoAspectRatio: Double = 16.0 / 9.0
    @Published public private(set) var activeSubtitleText: String?
    @Published var feedback: PlaybackFeedback?

    private var feedbackClearTask: Task<Void, Never>?
    private var accumulatedForwardSeconds = 0
    private var accumulatedRewindSeconds = 0
    private var lastNonzeroVolume = 100.0
    private var subtitleTrack = PlaybackSubtitleTrack.empty
    private var subtitlePresentationHoldMilliseconds: Int?
    private var lastDisplayedCurrentTimePublishTimestamp: TimeInterval = 0
    private var timelineScrubbingWasPlaying: Bool?
    private var protectedSeekTargetTime: Double?
    private var protectedSeekStartedAt: TimeInterval = 0
    private var protectedSeekUntil: TimeInterval = 0
    private let onVolumeChanged: (Double) -> Void
    private let onLastNonzeroVolumeChanged: (Double) -> Void
    private let onPlaybackSpeedChanged: (Double) -> Void
    private let onSubtitlesVisibleChanged: (Bool) -> Void
    private let onPlaybackTimeUpdated: (Double, Double) -> Void
    private let onPlaybackFinished: () -> Void
    private let onAutoStopBoundaryReached: (Int) -> Void
    private let onSeekInteractionBegan: () -> Void
    private let onSeekCommitted: (Int) -> Void
    private let onPresentationCommitted: (Bool) -> Void
    private let uiProbeScope: String?
    private var pendingPresentation: PendingPresentation?
    private var screenshotRequestGeneration: UInt = 0
    private var lastCommittedScreenshotGeneration: UInt = 0

    public init(
        player: PlaybackPlayer,
        initialVolume: Double = 100,
        initialLastNonzeroVolume: Double = 100,
        initialPlaybackSpeed: Double = 1.0,
        initialSubtitlesVisible: Bool = true,
        uiProbeScope: String? = nil,
        onVolumeChanged: @escaping (Double) -> Void = { _ in },
        onLastNonzeroVolumeChanged: @escaping (Double) -> Void = { _ in },
        onPlaybackSpeedChanged: @escaping (Double) -> Void = { _ in },
        onSubtitlesVisibleChanged: @escaping (Bool) -> Void = { _ in },
        onPlaybackTimeUpdated: @escaping (Double, Double) -> Void = { _, _ in },
        onPlaybackFinished: @escaping () -> Void = {},
        onAutoStopBoundaryReached: @escaping (Int) -> Void = { _ in },
        onSeekInteractionBegan: @escaping () -> Void = {},
        onSeekCommitted: @escaping (Int) -> Void = { _ in },
        onPresentationCommitted: @escaping (Bool) -> Void = { _ in }
    ) {
        self.player = player
        self.onVolumeChanged = onVolumeChanged
        self.onLastNonzeroVolumeChanged = onLastNonzeroVolumeChanged
        self.onPlaybackSpeedChanged = onPlaybackSpeedChanged
        self.onSubtitlesVisibleChanged = onSubtitlesVisibleChanged
        self.onPlaybackTimeUpdated = onPlaybackTimeUpdated
        self.onPlaybackFinished = onPlaybackFinished
        self.onAutoStopBoundaryReached = onAutoStopBoundaryReached
        self.onSeekInteractionBegan = onSeekInteractionBegan
        self.onSeekCommitted = onSeekCommitted
        self.onPresentationCommitted = onPresentationCommitted
        self.uiProbeScope = uiProbeScope

        volume = Self.clampedVolume(initialVolume)
        lastNonzeroVolume = Self.restorableVolume(
            initialVolume > 0 ? initialVolume : initialLastNonzeroVolume
        )
        playbackSpeed = Self.clampedPlaybackSpeed(initialPlaybackSpeed)
        areSubtitlesVisible = initialSubtitlesVisible

        self.player.delegate = self
        applyInitialPlaybackPreferences()
    }

    public func togglePlayPause() {
        let willPlay = !isPlaying

        do {
            try player.setPaused(isPlaying) // if isPlaying is true, set pause to yes
            showPlayPauseFeedback(isPlaying: willPlay)
        } catch {
            print("Failed to toggle pause: \(error)")
        }
    }
    
    public func seek(to seconds: Double) {
        performSeek(to: seconds, resetsAccumulatedFeedback: true)
    }

    func preparePresentationTransition(
        to seconds: Double,
        subtitleCues: [PlaybackSubtitleCue]? = nil
    ) {
        let targetTime = seconds.isFinite ? max(seconds, 0) : 0
        let heldActiveSubtitleText = pendingPresentation?.heldActiveSubtitleText
            ?? activeSubtitleText
        let stagedSubtitleTrack = subtitleCues.map { PlaybackSubtitleTrack(cues: $0) }
            ?? pendingPresentation?.stagedSubtitleTrack
        pendingPresentation = PendingPresentation(
            generation: nil,
            targetTime: targetTime,
            heldActiveSubtitleText: heldActiveSubtitleText,
            stagedSubtitleTrack: stagedSubtitleTrack
        )
    }

    func bindPendingPresentation(to generation: UInt) {
        guard pendingPresentation != nil else {
            return
        }
        pendingPresentation?.generation = generation
    }

    func cancelPendingPresentation() {
        pendingPresentation = nil
        clearProtectedSeekTarget()
        player.cancelPendingPresentation()
    }

    @discardableResult
    public func playFromCue(
        at seconds: Double,
        autoPauseBoundary: PlaybackAutoStopBoundary?
    ) -> Bool {
        let targetTime = clampedPlaybackTime(seconds)
        onSeekInteractionBegan()
        preparePresentationTransition(
            to: targetTime
        )
        protectSeekTarget(targetTime)
        accumulatedForwardSeconds = 0
        accumulatedRewindSeconds = 0

        do {
            let generation: UInt
            if let autoPauseBoundary {
                generation = try player.seek(to: autoPauseBoundary)
            } else {
                generation = try player.seek(
                    toMilliseconds: Int(targetTime * 1_000),
                    pauseAfterFirstFrame: false
                )
            }
            onSeekCommitted(Int(targetTime * 1_000))
            bindPendingPresentation(to: generation)
            return true
        } catch {
            cancelPendingPresentation()
            print("Failed to play from cue: \(error)")
            return false
        }
    }

    public func beginTimelineScrubbing() {
        guard timelineScrubbingWasPlaying == nil else {
            return
        }

        clearSubtitlePresentationHold()
        onSeekInteractionBegan()
        timelineScrubbingWasPlaying = isPlaying
        clearProtectedSeekTarget()

        do {
            try player.beginTimelineScrubbing()
            if isPlaying {
                isPlaying = false
                publishDisplayedCurrentTimeIfNeeded(force: true)
            }
        } catch {
            timelineScrubbingWasPlaying = nil
            print("Failed to begin timeline scrubbing: \(error)")
        }
    }

    public func updateTimelineScrubbing(to seconds: Double) {
        guard timelineScrubbingWasPlaying != nil else {
            return
        }

        let targetTime = clampedPlaybackTime(seconds)
        updatePlaybackTime(targetTime, publishesControlsImmediately: true)
    }

    public func endTimelineScrubbing(to seconds: Double) {
        let shouldResumePlayback = timelineScrubbingWasPlaying ?? isPlaying
        timelineScrubbingWasPlaying = nil

        let targetTime = clampedPlaybackTime(seconds)
        preparePresentationTransition(
            to: targetTime
        )
        protectSeekTarget(targetTime)
        accumulatedForwardSeconds = 0
        accumulatedRewindSeconds = 0

        do {
            let generation = try player.seek(
                toMilliseconds: Int(targetTime * 1000),
                pauseAfterFirstFrame: !shouldResumePlayback
            )
            onSeekCommitted(Int(targetTime * 1_000))
            bindPendingPresentation(to: generation)
            if shouldResumePlayback {
                try player.setPaused(false)
            }
        } catch {
            try? player.endTimelineScrubbing()
            cancelPendingPresentation()
            print("Failed to end timeline scrubbing: \(error)")
        }
    }

    public func cancelTimelineScrubbing() {
        guard let wasPlaying = timelineScrubbingWasPlaying else {
            return
        }

        timelineScrubbingWasPlaying = nil
        clearProtectedSeekTarget()

        do {
            try player.endTimelineScrubbing()
            try player.setPaused(!wasPlaying)
            isPlaying = wasPlaying
        } catch {
            print("Failed to cancel timeline scrubbing: \(error)")
        }
    }

    private func performSeek(to seconds: Double, resetsAccumulatedFeedback: Bool) {
        let targetTime = clampedPlaybackTime(seconds)
        onSeekInteractionBegan()
        let shouldResumePlayback = isPlaying
        preparePresentationTransition(
            to: targetTime
        )
        protectSeekTarget(targetTime)
        if resetsAccumulatedFeedback {
            accumulatedForwardSeconds = 0
            accumulatedRewindSeconds = 0
        }

        do {
            let generation = try player.seek(
                toMilliseconds: Int(targetTime * 1000),
                pauseAfterFirstFrame: !shouldResumePlayback
            )
            onSeekCommitted(Int(targetTime * 1_000))
            bindPendingPresentation(to: generation)
            if shouldResumePlayback {
                try player.setPaused(false)
            }
        } catch {
            cancelPendingPresentation()
            print("Failed to seek: \(error)")
        }
    }

    private func protectSeekTarget(_ targetTime: Double) {
        let now = Date.timeIntervalSinceReferenceDate
        protectedSeekTargetTime = targetTime
        protectedSeekStartedAt = now
        protectedSeekUntil = now + Self.seekTimeProtectionDuration
    }

    private func clearProtectedSeekTarget() {
        protectedSeekTargetTime = nil
        protectedSeekStartedAt = 0
        protectedSeekUntil = 0
    }

    private func shouldAcceptNativePlaybackTime(_ time: Double) -> Bool {
        guard let protectedSeekTargetTime else {
            return true
        }

        let now = Date.timeIntervalSinceReferenceDate
        guard now < protectedSeekUntil else {
            clearProtectedSeekTarget()
            return true
        }

        let elapsed = max(0, now - protectedSeekStartedAt)
        let tolerance = Self.seekTimeProtectionBaseTolerance
            + elapsed * max(playbackSpeed, 1.0)
        return abs(time - protectedSeekTargetTime) <= tolerance
    }

    private func clampedPlaybackTime(_ seconds: Double) -> Double {
        let nonnegativeSeconds = seconds.isFinite ? max(seconds, 0) : 0
        return duration > 0 ? min(nonnegativeSeconds, duration) : nonnegativeSeconds
    }

    public func seekRelative(by seconds: Double) {
        let targetTime: Double
        let baseTime = pendingPresentation?.targetTime ?? currentTime

        if duration > 0 {
            targetTime = min(max(baseTime + seconds, 0), duration)
        } else {
            targetTime = max(baseTime + seconds, 0)
        }

        performSeek(to: targetTime, resetsAccumulatedFeedback: false)

        if seconds > 0 {
            accumulatedRewindSeconds = 0
            accumulatedForwardSeconds += Int(abs(seconds))
            showFeedback(
                PlaybackFeedback(
                    position: .trailing,
                    systemImage: "chevron.right",
                    text: "+ \(accumulatedForwardSeconds)s"
                )
            )
        } else {
            accumulatedForwardSeconds = 0
            accumulatedRewindSeconds += Int(abs(seconds))
            showFeedback(
                PlaybackFeedback(
                    position: .leading,
                    systemImage: "chevron.left",
                    text: "- \(accumulatedRewindSeconds)s"
                )
            )
        }
    }

    public func setVolume(_ value: Double, showsFeedback: Bool = true) {
        let clampedValue = Self.clampedVolume(value)
        let isIncrease = clampedValue > volume ? true : (clampedValue < volume ? false : nil)

        do {
            try player.setDoubleProperty("volume", value: clampedValue)
            applyVolumePreference(clampedValue)
            if showsFeedback {
                showVolumeFeedback(clampedValue, isIncrease: isIncrease)
            }
        } catch {
            print("Failed to set volume: \(error)")
        }
    }

    public func toggleMute() {
        setVolume(volume > 0 ? 0 : lastNonzeroVolume)
    }
    
    public func adjustVolume(by delta: Double) {
        let clampedValue = Self.clampedVolume(volume + delta)
        let isIncrease = delta > 0

        do {
            try player.setDoubleProperty("volume", value: clampedValue)
            applyVolumePreference(clampedValue)
            showVolumeFeedback(clampedValue, isIncrease: isIncrease)
        } catch {
            print("Failed to set volume: \(error)")
        }
    }

    public func setSpeed(_ value: Double, showsFeedback: Bool = true) {
        let clampedValue = Self.clampedPlaybackSpeed(value)

        do {
            try player.setDoubleProperty("speed", value: clampedValue)
            applyPlaybackSpeedPreference(clampedValue)
            if showsFeedback {
                showSpeedFeedback(clampedValue)
            }
        } catch {
            print("Failed to set speed: \(error)")
        }
    }

    public func adjustSpeed(by delta: Double) {
        setSpeed(playbackSpeed + delta)
    }

    public func toggleSubtitles() {
        setSubtitlesVisible(!areSubtitlesVisible)
    }

    public func setSubtitlesVisible(_ newValue: Bool, showsFeedback: Bool = true) {
        areSubtitlesVisible = newValue
        player.setSubtitlesVisible(newValue)
        onSubtitlesVisibleChanged(newValue)
        refreshActiveSubtitleText()
        if showsFeedback {
            showSubtitleFeedback(isVisible: newValue)
        }
    }

    public func setSubtitleCues(
        _ cues: [PlaybackSubtitleCue],
        currentTimeMilliseconds: Int? = nil
    ) {
        if pendingPresentation != nil {
            pendingPresentation?.stagedSubtitleTrack = PlaybackSubtitleTrack(cues: cues)
            if let currentTimeMilliseconds {
                pendingPresentation?.targetTime = Double(max(0, currentTimeMilliseconds)) / 1_000
            }
            return
        }

        clearSubtitlePresentationHold()
        subtitleTrack = PlaybackSubtitleTrack(cues: cues)
        if let currentTimeMilliseconds {
            updatePlaybackTime(
                Double(max(0, currentTimeMilliseconds)) / 1_000,
                publishesControlsImmediately: true
            )
        }
        refreshActiveSubtitleText()
    }

    public func clearSubtitleCues() {
        if pendingPresentation != nil {
            pendingPresentation?.stagedSubtitleTrack = .empty
            return
        }

        clearSubtitlePresentationHold()
        subtitleTrack = .empty
        refreshActiveSubtitleText()
    }

    public func holdSubtitlePresentation(atMilliseconds milliseconds: Int) {
        let safeMilliseconds = max(0, milliseconds)
        subtitlePresentationHoldMilliseconds = safeMilliseconds
        player.holdSubtitlePresentation(atMilliseconds: safeMilliseconds)
        refreshActiveSubtitleText()
    }

    public func clearSubtitlePresentationHold() {
        guard subtitlePresentationHoldMilliseconds != nil else {
            return
        }

        subtitlePresentationHoldMilliseconds = nil
        player.clearSubtitlePresentationHold()
        refreshActiveSubtitleText()
    }

    func showSubtitleCopyFeedback(copied: Bool) {
        showFeedback(
            PlaybackFeedback(
                position: .center,
                icon: copied ? .copy : .system("exclamationmark.triangle"),
                text: copied ? L("playback.hud.cue_text_copied") : L("playback.hud.no_subtitle")
            ),
            durationMilliseconds: 1_000
        )
    }

    func showSelectedTextCopyFeedback(copied: Bool) {
        showFeedback(
            PlaybackFeedback(
                position: .center,
                icon: copied ? .copy : .system("exclamationmark.triangle"),
                text: copied ? L("playback.hud.selected_text_copied") : L("playback.hud.copy_failed")
            ),
            durationMilliseconds: 1_000
        )
    }

    func copyCurrentFrameScreenshot() {
        guard timelineScrubbingWasPlaying == nil,
              let presentation = player.captureScreenshotPresentation()
        else {
            return
        }

        let workItem = PlaybackScreenshotRenderWorkItem(
            presentation: presentation
        )
        screenshotRequestGeneration &+= 1
        let requestGeneration = screenshotRequestGeneration

        Task.detached(priority: .userInitiated) { [weak self] in
            do {
                let image = try PlaybackCurrentFrameScreenshotRenderer.render(
                    workItem.presentation
                )
                let pngData = try PlaybackScreenshotPasteboardWriter.pngData(
                    for: image
                )
                await self?.commitCurrentFrameScreenshot(
                    pngData,
                    requestGeneration: requestGeneration
                )
            } catch {
                print("Failed to copy current frame screenshot: \(error)")
            }
        }
    }

    func showScreenshotCopiedFeedback() {
        showFeedback(
            PlaybackFeedback(
                position: .center,
                systemImage: "photo",
                text: L("playback.hud.screenshot_copied")
            ),
            durationMilliseconds: 1_000
        )
    }

    func showAutoPauseFeedback() {
        showFeedback(
            PlaybackFeedback(
                position: .center,
                systemImage: "pause.fill",
                text: L("playback.hud.auto_pause")
            )
        )
    }

    func showRepeatFeedback() {
        showFeedback(
            PlaybackFeedback(
                position: .center,
                systemImage: "repeat",
                text: L("playback.repeat")
            )
        )
    }

    func showSubtitleMarkdownLinkCopyFeedback(copied: Bool) {
        showFeedback(
            PlaybackFeedback(
                position: .center,
                icon: copied ? .copy : .system("exclamationmark.triangle"),
                text: copied ? L("playback.hud.deep_link_copied") : L("playback.hud.no_subtitle")
            ),
            durationMilliseconds: 1_000
        )
    }

    /// A `Save to Shiori` result on the playback page and in the Command Panel.
    /// The sentence is the registry's, the same one the Workbench shows in a
    /// Toast; only the container differs, and every outcome wears the same
    /// bookmark.
    func showShioriSaveFeedback(message: String) {
        showFeedback(
            PlaybackFeedback(
                position: .center,
                systemImage: "bookmark.fill",
                text: message
            ),
            durationMilliseconds: 1_000
        )
    }

    func showShioriFeedback(_ state: ShioriFeedbackState) {
        let feedback: PlaybackFeedback = switch state {
        case .removed:
            PlaybackFeedback(
                position: .center,
                systemImage: "bookmark",
                text: L("playback.hud.shiori_removed")
            )
        case .unavailable:
            PlaybackFeedback(
                position: .center,
                systemImage: "exclamationmark.triangle",
                text: L("playback.hud.no_subtitle")
            )
        }

        showFeedback(feedback, durationMilliseconds: 1_000)
    }

    func showPlayPauseFeedback(isPlaying: Bool) {
        showFeedback(
            PlaybackFeedback(
                position: .center,
                systemImage: isPlaying ? "play.fill" : "pause.fill",
                text: isPlaying ? L("playback.play") : L("playback.pause")
            )
        )
    }

    func showSearchNavigationFeedback(
        direction: SearchResultNavigationDirection,
        hasResult: Bool
    ) {
        showFeedback(
            PlaybackFeedback(
                position: direction == .previous ? .leading : .trailing,
                systemImage: direction == .previous ? "chevron.left" : "chevron.right",
                text: hasResult
                    ? (direction == .previous ? L("playback.hud.previous_result") : L("playback.hud.next_result"))
                    : L("playback.hud.no_result")
            ),
            durationMilliseconds: 1_000
        )
    }

    func showLibraryNavigationFeedback(
        direction: SearchResultNavigationDirection,
        hasResult: Bool
    ) {
        showFeedback(
            PlaybackFeedback(
                position: direction == .previous ? .leading : .trailing,
                systemImage: direction == .previous ? "chevron.left" : "chevron.right",
                text: hasResult
                    ? (direction == .previous ? L("playback.hud.previous_library_video") : L("playback.hud.next_library_video"))
                    : L("playback.hud.no_library_video")
            ),
            durationMilliseconds: 1_000
        )
    }

    func showShioriNavigationFeedback(
        direction: SearchResultNavigationDirection,
        hasResult: Bool
    ) {
        showFeedback(
            PlaybackFeedback(
                position: direction == .previous ? .leading : .trailing,
                systemImage: direction == .previous ? "chevron.left" : "chevron.right",
                text: hasResult
                    ? (direction == .previous ? L("playback.hud.previous_bookmark") : L("playback.hud.next_bookmark"))
                    : L("playback.hud.no_bookmark")
            ),
            durationMilliseconds: 1_000
        )
    }

    func showFullscreenFeedback(enteringFullscreen: Bool) {
        showFeedback(
            PlaybackFeedback(
                position: .center,
                text: enteringFullscreen ? L("playback.hud.enter_fullscreen") : L("playback.hud.exit_fullscreen")
            ),
            durationMilliseconds: 1_000
        )
    }

    private func showSubtitleFeedback(isVisible: Bool) {
        showFeedback(
            PlaybackFeedback(
                position: .center,
                systemImage: isVisible ? "captions.bubble.fill" : "captions.bubble",
                text: isVisible ? L("playback.hud.subtitles_on") : L("playback.hud.subtitles_off")
            ),
            durationMilliseconds: 1_000
        )
    }

    private func showSpeedFeedback(_ speed: Double) {
        showFeedback(
            PlaybackFeedback(
                position: .center,
                systemImage: "speedometer",
                text: Self.formatSpeed(speed)
            )
        )
    }

    private func showVolumeFeedback(_ volume: Double, isIncrease: Bool?) {
        let systemImage: String
        if volume <= 0 {
            systemImage = "speaker.slash.fill"
        } else if let isIncrease {
            systemImage = isIncrease ? "speaker.wave.3.fill" : "speaker.wave.1.fill"
        } else {
            systemImage = "speaker.wave.2.fill"
        }

        showFeedback(
            PlaybackFeedback(
                position: .center,
                systemImage: systemImage,
                text: volume > 0 ? "\(Int(volume.rounded()))%" : L("playback.hud.muted")
            )
        )
    }

    private func refreshActiveSubtitleText() {
        if let pendingPresentation {
            let nextText = areSubtitlesVisible
                ? pendingPresentation.heldActiveSubtitleText
                : nil
            if activeSubtitleText != nextText {
                activeSubtitleText = nextText
            }
            return
        }
        let subtitleTime = subtitlePresentationHoldMilliseconds.map { Double($0) / 1_000 } ?? currentTime
        let nextText = areSubtitlesVisible ? subtitleTrack.activeText(at: subtitleTime) : nil
        if activeSubtitleText != nextText {
            activeSubtitleText = nextText
        }
    }

    private func applyInitialPlaybackPreferences() {
        do {
            try player.setDoubleProperty("volume", value: volume)
        } catch {
            print("Failed to apply initial volume: \(error)")
        }

        do {
            try player.setDoubleProperty("speed", value: playbackSpeed)
        } catch {
            print("Failed to apply initial speed: \(error)")
        }

        player.setSubtitlesVisible(areSubtitlesVisible)
    }

    private func applyVolumePreference(_ nextVolume: Double) {
        let clampedVolume = Self.clampedVolume(nextVolume)
        if volume != clampedVolume {
            volume = clampedVolume
        }
        onVolumeChanged(clampedVolume)

        guard clampedVolume > 0 else {
            return
        }

        let restorableVolume = Self.restorableVolume(clampedVolume)
        if lastNonzeroVolume != restorableVolume {
            lastNonzeroVolume = restorableVolume
        }
        onLastNonzeroVolumeChanged(restorableVolume)
    }

    private func applyPlaybackSpeedPreference(_ nextSpeed: Double) {
        let clampedSpeed = Self.clampedPlaybackSpeed(nextSpeed)
        if playbackSpeed != clampedSpeed {
            playbackSpeed = clampedSpeed
        }
        onPlaybackSpeedChanged(clampedSpeed)
    }

    private static func clampedVolume(_ value: Double) -> Double {
        guard value.isFinite else {
            return defaultVolume
        }

        return min(max(value, 0), 100)
    }

    private static func restorableVolume(_ value: Double) -> Double {
        let clampedValue = clampedVolume(value)
        return clampedValue > 0 ? clampedValue : defaultVolume
    }

    private static func clampedPlaybackSpeed(_ value: Double) -> Double {
        guard value.isFinite else {
            return defaultPlaybackSpeed
        }

        return min(
            max(value, minimumPlaybackSpeed),
            maximumPlaybackSpeed
        )
    }

    private func updatePlaybackTime(
        _ time: Double,
        publishesControlsImmediately: Bool = false
    ) {
        currentTime = time.isFinite ? max(time, 0) : 0
        onPlaybackTimeUpdated(currentTime, duration)
        refreshActiveSubtitleText()
        publishDisplayedCurrentTimeIfNeeded(force: publishesControlsImmediately)
    }

    private func publishDisplayedCurrentTimeIfNeeded(force: Bool) {
        let now = Date.timeIntervalSinceReferenceDate
        guard force
            || now - lastDisplayedCurrentTimePublishTimestamp >= Self.displayedCurrentTimePublishInterval
            || abs(displayedCurrentTime - currentTime) >= 1.0
        else {
            return
        }

        displayedCurrentTime = currentTime
        lastDisplayedCurrentTimePublishTimestamp = now
        UIInvalidationProbe.count(
            "UI.PlaybackTime.published",
            details: String(format: "time=%.2f", displayedCurrentTime)
        )
        UIInvalidationProbe.count(
            "playback.high_frequency_chrome_update",
            scope: uiProbeScope,
            details: String(format: "time=%.2f", displayedCurrentTime)
        )
    }

    private func showFeedback(
        _ nextFeedback: PlaybackFeedback,
        durationMilliseconds: UInt64 = 800
    ) {
        feedback = nextFeedback
        feedbackClearTask?.cancel()
        feedbackClearTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: durationMilliseconds * 1_000_000)
            guard !Task.isCancelled else {
                return
            }

            await MainActor.run {
                self?.feedback = nil
                switch nextFeedback.position {
                case .trailing:
                    self?.accumulatedForwardSeconds = 0
                case .leading:
                    self?.accumulatedRewindSeconds = 0
                case .center:
                    self?.accumulatedForwardSeconds = 0
                    self?.accumulatedRewindSeconds = 0
                }
            }
        }
    }

    private func commitCurrentFrameScreenshot(
        _ pngData: Data,
        requestGeneration: UInt
    ) {
        guard requestGeneration > lastCommittedScreenshotGeneration else {
            return
        }

        do {
            try PlaybackScreenshotPasteboardWriter.write(pngData)
            lastCommittedScreenshotGeneration = requestGeneration
            showScreenshotCopiedFeedback()
        } catch {
            print("Failed to write current frame screenshot to pasteboard: \(error)")
        }
    }

    /// The preset the given speed is currently on, so the speed menu can open
    /// with its highlight already on the value in effect.
    static func speedPresetIndex(for speed: Double) -> Int? {
        speedPresets.firstIndex { abs($0 - speed) < 0.01 }
    }

    static func formatSpeed(_ speed: Double) -> String {
        if speed.rounded() == speed {
            return String(format: "%.0f×", speed)
        }

        if (speed * 10).rounded() == speed * 10 {
            return String(format: "%.1f×", speed)
        }

        return String(format: "%.2f×", speed)
    }
}

extension PlaybackViewModel: PlaybackPlayerDelegate {
    nonisolated public func player(_ player: PlaybackPlayer, didChangeProperty name: String, value: PlaybackPropertyValue?) {
        Task { @MainActor in
            guard let value else { return }
            if self.pendingPresentation != nil,
               (name == "time-pos"
                || name == "duration"
                || name == "video-aspect-ratio"
                || name == "pause") {
                return
            }
            switch name {
            case "time-pos":
                if case .double(let d) = value {
                    if self.timelineScrubbingWasPlaying != nil {
                        return
                    }
                    guard self.shouldAcceptNativePlaybackTime(d) else {
                        return
                    }
                    self.updatePlaybackTime(d)
                }
            case "duration":
                if case .double(let d) = value, self.duration != d {
                    self.duration = d
                }
            case "video-aspect-ratio":
                if case .double(let d) = value, d.isFinite, d > 0, self.videoAspectRatio != d {
                    self.videoAspectRatio = d
                }
            case "pause":
                if case .bool(let b) = value {
                    let nextIsPlaying = !b
                    if self.isPlaying != nextIsPlaying {
                        self.isPlaying = nextIsPlaying
                        self.publishDisplayedCurrentTimeIfNeeded(force: true)
                    }
                }
            case "volume":
                if case .double(let d) = value, self.volume != d {
                    self.volume = d
                }
            case "speed":
                if case .double(let d) = value, self.playbackSpeed != d {
                    self.playbackSpeed = d
                }
            default:
                break
            }
        }
    }

    nonisolated public func player(_ player: PlaybackPlayer, didFailWithMessage message: String) {
        print("Native playback failed: \(message)")
    }

    nonisolated public func playerDidFinishPlayback(_ player: PlaybackPlayer) {
        Task { @MainActor in
            self.isPlaying = false
            self.publishDisplayedCurrentTimeIfNeeded(force: true)
            self.onPlaybackFinished()
        }
    }

    nonisolated public func player(
        _ player: PlaybackPlayer,
        didReachAutoStopBoundaryAtMilliseconds endMilliseconds: Int
    ) {
        Task { @MainActor in
            self.isPlaying = false
            self.publishDisplayedCurrentTimeIfNeeded(force: true)
            self.onAutoStopBoundaryReached(endMilliseconds)
        }
    }

    public func player(
        _ player: PlaybackPlayer,
        didCommitPresentationAtMilliseconds milliseconds: Int,
        generation: UInt,
        playing: Bool,
        videoSize: CGSize?
    ) {
        guard let pendingPresentation,
              pendingPresentation.generation == generation
        else {
            return
        }

        self.pendingPresentation = nil
        if let stagedSubtitleTrack = pendingPresentation.stagedSubtitleTrack {
            subtitleTrack = stagedSubtitleTrack
        }
        if let videoSize,
           videoSize.width > 0,
           videoSize.height > 0 {
            let nextAspectRatio = Double(videoSize.width / videoSize.height)
            if nextAspectRatio.isFinite,
               videoAspectRatio != nextAspectRatio {
                videoAspectRatio = nextAspectRatio
            }
        }
        subtitlePresentationHoldMilliseconds = nil
        clearProtectedSeekTarget()
        isPlaying = playing
        if let committedDuration = try? player.getDoubleProperty("duration"),
           duration != committedDuration {
            duration = committedDuration
        }
        updatePlaybackTime(
            Double(max(0, milliseconds)) / 1_000,
            publishesControlsImmediately: true
        )
        onPresentationCommitted(playing)
    }
}
