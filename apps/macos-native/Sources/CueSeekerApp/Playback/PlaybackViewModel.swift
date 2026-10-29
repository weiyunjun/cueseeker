import Foundation
import SwiftUI
import CueSeekerPlayback

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
    static let maximumPlaybackSpeed = 3.0
    static let speedPresets = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 3.0]
    private static let displayedCurrentTimePublishInterval: TimeInterval = 0.5
    private static let seekTimeProtectionDuration: TimeInterval = 1.5
    private static let seekTimeProtectionBaseTolerance = 0.75
    private static let defaultVolume = 100.0
    private static let defaultPlaybackSpeed = 1.0

    public let player: PlaybackPlayer
    var timelineThumbnailStore: PlaybackTimelineThumbnailStore

    @Published public var isPlaying: Bool = false
    public private(set) var currentTime: Double = 0
    @Published public private(set) var displayedCurrentTime: Double = 0
    @Published public var duration: Double = 0 {
        didSet {
            if oldValue != duration {
                refreshActiveTimelineThumbnailPreviewIfNeeded()
            }
        }
    }
    @Published private(set) var timelineThumbnailContextRevision: UInt = 0
    @Published public var volume: Double = 100
    @Published public var playbackSpeed: Double = 1.0
    @Published public var areSubtitlesVisible: Bool = true
    @Published public private(set) var videoAspectRatio: Double = 16.0 / 9.0
    @Published public private(set) var activeSubtitleText: String?
    @Published var feedback: PlaybackFeedback?
    @Published private(set) var isLoadingFeedbackVisible = false
    @Published private(set) var isOpeningNewVideo = false

    var effectiveFeedback: PlaybackFeedback? {
        feedback ?? (isLoadingFeedbackVisible ? .loading : nil)
    }

    var feedbackClearTask: Task<Void, Never>?
    var loadingFeedbackTask: Task<Void, Never>?
    var accumulatedForwardSeconds = 0
    var accumulatedRewindSeconds = 0
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
    private let onSubtitleSourceLoadFailure: (URL) -> Void
    private let onVideoOpenFailure: (URL, Error) -> Void
    private let uiProbeScope: String?
    private var pendingPresentation: PendingPresentation?
    private var activeTimelineHoverProgress: Double?
    private var activeTimelineThumbnailScaleFactor: CGFloat = 2.0
    private var needsTimelineThumbnailRefreshAfterReset = false
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
        onPresentationCommitted: @escaping (Bool) -> Void = { _ in },
        onSubtitleSourceLoadFailure: @escaping (URL) -> Void = { _ in },
        onVideoOpenFailure: @escaping (URL, Error) -> Void = { _, _ in }
    ) {
        self.player = player
        self.timelineThumbnailStore = PlaybackTimelineThumbnailStore(player: player)
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
        self.onSubtitleSourceLoadFailure = onSubtitleSourceLoadFailure
        self.onVideoOpenFailure = onVideoOpenFailure
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
        guard !isOpeningNewVideo else {
            return
        }
        let willPlay = !isPlaying

        do {
            try player.setPaused(isPlaying) // if isPlaying is true, set pause to yes
            isPlaying = willPlay
            showPlayPauseFeedback(isPlaying: willPlay)
        } catch {
            print("Failed to toggle pause: \(error)")
        }
    }
    
    public func seek(to seconds: Double) {
        performSeek(to: seconds, resetsAccumulatedFeedback: true)
    }

    func prepareNewVideoOpening(
        to seconds: Double,
        subtitleCues: [PlaybackSubtitleCue]? = nil,
        resetsLoadingTimer: Bool = true
    ) {
        let targetTime = seconds.isFinite ? max(seconds, 0) : 0
        let heldActiveSubtitleText = pendingPresentation?.heldActiveSubtitleText
            ?? activeSubtitleText
        let stagedSubtitleTrack = subtitleCues.map { PlaybackSubtitleTrack(cues: $0) }
            ?? pendingPresentation?.stagedSubtitleTrack
        isOpeningNewVideo = true
        pendingPresentation = PendingPresentation(
            generation: nil,
            targetTime: targetTime,
            heldActiveSubtitleText: heldActiveSubtitleText,
            stagedSubtitleTrack: stagedSubtitleTrack
        )
        clearProtectedSeekTarget()
        clearTimelineThumbnailPreview()
        duration = 0
        isPlaying = true
        updatePlaybackTime(0, publishesControlsImmediately: true)
        scheduleLoadingFeedback(reset: resetsLoadingTimer)
    }

    func preparePresentationTransition(
        to seconds: Double,
        subtitleCues: [PlaybackSubtitleCue]? = nil,
        resetsLoadingTimer: Bool = true
    ) {
        let targetTime = clampedPlaybackTime(seconds)
        let heldActiveSubtitleText = pendingPresentation?.heldActiveSubtitleText
            ?? activeSubtitleText
        let stagedSubtitleTrack = subtitleCues.map { PlaybackSubtitleTrack(cues: $0) }
            ?? pendingPresentation?.stagedSubtitleTrack
        isOpeningNewVideo = false
        pendingPresentation = PendingPresentation(
            generation: nil,
            targetTime: targetTime,
            heldActiveSubtitleText: heldActiveSubtitleText,
            stagedSubtitleTrack: stagedSubtitleTrack
        )
        protectSeekTarget(targetTime)
        updatePlaybackTime(targetTime, publishesControlsImmediately: true)
        scheduleLoadingFeedback(reset: resetsLoadingTimer)
    }

    func bindPendingPresentation(to generation: UInt) {
        // A video opened, so the player holds one again.
        isPlayerEmpty = false
        guard pendingPresentation != nil else {
            return
        }
        pendingPresentation?.generation = generation
    }

    func cancelPendingPresentation() {
        pendingPresentation = nil
        isOpeningNewVideo = false
        cancelLoadingFeedback()
        clearProtectedSeekTarget()
        player.cancelPendingPresentation()
    }

    private func scheduleLoadingFeedback(reset: Bool = true) {
        if !reset, (isLoadingFeedbackVisible || loadingFeedbackTask != nil) {
            return
        }
        loadingFeedbackTask?.cancel()
        isLoadingFeedbackVisible = false
        let delayNanoseconds = PlaybackChromeMetrics.loadingFeedbackDelayMilliseconds * 1_000_000
        loadingFeedbackTask = Task.detached(priority: .userInitiated) { [weak self] in
            try? await Task.sleep(nanoseconds: delayNanoseconds)
            guard !Task.isCancelled else {
                return
            }
            await MainActor.run {
                guard !Task.isCancelled, let self, self.pendingPresentation != nil else {
                    return
                }
                self.isLoadingFeedbackVisible = true
            }
        }
    }

    private func cancelLoadingFeedback() {
        loadingFeedbackTask?.cancel()
        loadingFeedbackTask = nil
        if isLoadingFeedbackVisible {
            isLoadingFeedbackVisible = false
        }
    }

    /// A video that failed to load leaves the player empty until another one
    /// opens. Its controls stay usable but have nothing to act on, so they
    /// neither move the picture nor show Playback Feedback. See
    /// `docs/human/requirements/20260921-Bug-Missing Files Treated As Missing
    /// Database Records.md`.
    private(set) var isPlayerEmpty = false

    /// Returns the chrome to an empty player after a video that failed to load
    /// stopped the one before it: no time, no duration, nothing playing. The
    /// native player reports nothing once it is stopped, so the last video's
    /// numbers would otherwise stay on screen.
    func resetPresentationForStoppedPlayback() {
        cancelPendingPresentation()
        clearTimelineThumbnailPreview()
        clearSubtitleCues()
        duration = 0
        isPlaying = false
        updatePlaybackTime(0, publishesControlsImmediately: true)
        isPlayerEmpty = true
    }

    func updateTimelineHoverPreview(
        progress: Double,
        backingScaleFactor: CGFloat
    ) {
        let clampedProgress = progress.isFinite ? min(max(progress, 0), 1) : 0
        activeTimelineHoverProgress = clampedProgress
        if backingScaleFactor.isFinite, backingScaleFactor > 0 {
            activeTimelineThumbnailScaleFactor = backingScaleFactor
        }
        refreshActiveTimelineThumbnailPreviewIfNeeded()
    }

    func clearTimelineHoverPreview() {
        activeTimelineHoverProgress = nil
        timelineThumbnailStore.clear()
    }

    func refreshActiveTimelineThumbnailPreviewIfNeeded() {
        guard let progress = activeTimelineHoverProgress else {
            return
        }
        guard !isPlayerEmpty, duration > 0 else {
            timelineThumbnailStore.clear()
            return
        }
        updateTimelineThumbnailPreview(
            at: progress * duration,
            backingScaleFactor: activeTimelineThumbnailScaleFactor
        )
    }

    func updateTimelineThumbnailPreview(
        at seconds: Double,
        backingScaleFactor: CGFloat
    ) {
        guard !isPlayerEmpty, duration > 0 else {
            timelineThumbnailStore.clear()
            return
        }
        let targetTime = clampedPlaybackTime(seconds)
        timelineThumbnailStore.updatePreview(
            forSeconds: targetTime,
            backingScaleFactor: backingScaleFactor
        )
    }

    func clearTimelineThumbnailPreview() {
        timelineThumbnailStore.clear()
    }

    @discardableResult
    public func playFromCue(
        at seconds: Double,
        autoPauseBoundary: PlaybackAutoStopBoundary?
    ) -> Bool {
        guard !isPlayerEmpty else {
            return false
        }
        let targetTime = clampedPlaybackTime(seconds)
        onSeekInteractionBegan()
        isPlaying = true
        preparePresentationTransition(
            to: targetTime
        )
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

        cancelLoadingFeedback()
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
        isPlaying = shouldResumePlayback
        preparePresentationTransition(
            to: targetTime
        )
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
        guard !isPlayerEmpty else {
            return
        }
        let targetTime = clampedPlaybackTime(seconds)
        onSeekInteractionBegan()
        let shouldResumePlayback = isPlaying
        preparePresentationTransition(
            to: targetTime
        )
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
        guard !isPlayerEmpty else {
            return
        }
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
                    icon: .caretRight,
                    text: L("playback.hud.seek_forward", accumulatedForwardSeconds)
                ),
                durationMilliseconds: 1_000
            )
        } else {
            accumulatedForwardSeconds = 0
            accumulatedRewindSeconds += Int(abs(seconds))
            showFeedback(
                PlaybackFeedback(
                    icon: .caretLeft,
                    text: L("playback.hud.seek_backward", accumulatedRewindSeconds)
                ),
                durationMilliseconds: 1_000
            )
        }
    }

    public func setVolume(_ value: Double, showsFeedback: Bool = true) {
        let clampedValue = Self.clampedVolume(value)
        let isIncrease = clampedValue > volume ? true : (clampedValue < volume ? false : nil)

        player.setVolume(clampedValue)
        applyVolumePreference(clampedValue)
        if showsFeedback, !isPlayerEmpty {
            showVolumeFeedback(clampedValue, isIncrease: isIncrease)
        }
    }

    public func toggleMute() {
        setVolume(volume > 0 ? 0 : lastNonzeroVolume)
    }
    
    public func adjustVolume(by delta: Double) {
        let clampedValue = Self.clampedVolume(volume + delta)
        let isIncrease = delta > 0

        player.setVolume(clampedValue)
        applyVolumePreference(clampedValue)
        if !isPlayerEmpty {
            showVolumeFeedback(clampedValue, isIncrease: isIncrease)
        }
    }

    public func setSpeed(_ value: Double, showsFeedback: Bool = true) {
        let clampedValue = Self.clampedPlaybackSpeed(value)

        player.setPlaybackSpeed(clampedValue)
        applyPlaybackSpeedPreference(clampedValue)
        if showsFeedback, !isPlayerEmpty {
            showSpeedFeedback(clampedValue)
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
        player.setVolume(volume)
        player.setPlaybackSpeed(playbackSpeed)
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
    nonisolated public func player(_ player: PlaybackPlayer, didUpdateTimePosition seconds: Double) {
        Task { @MainActor in
            guard self.pendingPresentation == nil,
                  self.timelineScrubbingWasPlaying == nil,
                  self.shouldAcceptNativePlaybackTime(seconds)
            else {
                return
            }
            self.updatePlaybackTime(seconds)
        }
    }

    nonisolated public func player(_ player: PlaybackPlayer, didUpdateDuration seconds: Double) {
        let applyUpdate = { @MainActor in
            guard self.pendingPresentation == nil else {
                return
            }
            if self.duration != seconds {
                self.duration = seconds
            }
            if self.needsTimelineThumbnailRefreshAfterReset, seconds > 0 {
                self.needsTimelineThumbnailRefreshAfterReset = false
                self.timelineThumbnailContextRevision &+= 1
            }
            self.refreshActiveTimelineThumbnailPreviewIfNeeded()
        }
        if Thread.isMainThread {
            MainActor.assumeIsolated {
                applyUpdate()
            }
        } else {
            Task { @MainActor in
                applyUpdate()
            }
        }
    }

    nonisolated public func player(_ player: PlaybackPlayer, didUpdateVideoAspectRatio aspectRatio: Double) {
        Task { @MainActor in
            guard self.pendingPresentation == nil,
                    aspectRatio.isFinite,
                    aspectRatio > 0,
                    self.videoAspectRatio != aspectRatio
            else {
                return
            }
            self.videoAspectRatio = aspectRatio
        }
    }

    nonisolated public func player(_ player: PlaybackPlayer, didUpdatePaused isPaused: Bool) {
        Task { @MainActor in
            guard self.pendingPresentation == nil else {
                return
            }
            let nextIsPlaying = !isPaused
            if self.isPlaying != nextIsPlaying {
                self.isPlaying = nextIsPlaying
                self.publishDisplayedCurrentTimeIfNeeded(force: true)
            }
        }
    }

    nonisolated public func player(_ player: PlaybackPlayer, didUpdateVolume volume: Double) {
        Task { @MainActor in
            if self.volume != volume {
                self.volume = volume
            }
        }
    }

    nonisolated public func player(_ player: PlaybackPlayer, didUpdatePlaybackSpeed speed: Double) {
        Task { @MainActor in
            if self.playbackSpeed != speed {
                self.playbackSpeed = speed
            }
        }
    }

    nonisolated public func player(_ player: PlaybackPlayer, didFailWithMessage message: String) {
        print("Native playback failed: \(message)")
    }

    nonisolated public func player(
        _ player: PlaybackPlayer,
        didFailToLoadSubtitleSource url: URL
    ) {
        Task { @MainActor in
            self.onSubtitleSourceLoadFailure(url)
        }
    }

    nonisolated public func player(
        _ player: PlaybackPlayer,
        didFailToOpenVideoAt url: URL,
        error: Error
    ) {
        Task { @MainActor in
            self.onVideoOpenFailure(url, error)
        }
    }

    nonisolated public func playerDidFinishPlayback(_ player: PlaybackPlayer) {
        Task { @MainActor in
            self.needsTimelineThumbnailRefreshAfterReset = true
            self.clearTimelineThumbnailPreview()
            self.isPlaying = false
            self.publishDisplayedCurrentTimeIfNeeded(force: true)
            self.onPlaybackFinished()
        }
    }

    nonisolated public func playerDidResetTimelineThumbnails(_ player: PlaybackPlayer) {
        if Thread.isMainThread {
            MainActor.assumeIsolated {
                self.needsTimelineThumbnailRefreshAfterReset = true
                self.clearTimelineThumbnailPreview()
            }
        } else {
            Task { @MainActor in
                self.needsTimelineThumbnailRefreshAfterReset = true
                self.clearTimelineThumbnailPreview()
            }
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
        isOpeningNewVideo = false
        cancelLoadingFeedback()
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
        let committedDuration = player.duration()
        if duration != committedDuration {
            duration = committedDuration
        }
        needsTimelineThumbnailRefreshAfterReset = false
        timelineThumbnailContextRevision &+= 1
        refreshActiveTimelineThumbnailPreviewIfNeeded()
        updatePlaybackTime(
            Double(max(0, milliseconds)) / 1_000,
            publishesControlsImmediately: true
        )
        onPresentationCommitted(playing)
    }
}
