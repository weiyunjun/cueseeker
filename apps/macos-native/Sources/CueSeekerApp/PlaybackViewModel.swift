import Foundation
import SwiftUI
import CueSeekerPlayback

enum PlaybackFeedbackPosition: Equatable {
    case center
    case leading
    case trailing
}

enum ShioriFeedbackState {
    case saved
    case removed
    case unavailable
}

struct PlaybackFeedback: Identifiable, Equatable {
    let id = UUID()
    let position: PlaybackFeedbackPosition
    let systemImage: String
    let text: String?
    let isCircular: Bool
}

@MainActor
public final class PlaybackViewModel: ObservableObject {
    static let minimumPlaybackSpeed = 0.5
    static let maximumPlaybackSpeed = 2.0
    static let speedPresets = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0]
    private static let displayedCurrentTimePublishInterval: TimeInterval = 0.5
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
    @Published public private(set) var activeSubtitleText: String?
    @Published var feedback: PlaybackFeedback?

    private var feedbackClearTask: Task<Void, Never>?
    private var accumulatedForwardSeconds = 0
    private var accumulatedRewindSeconds = 0
    private var lastNonzeroVolume = 100.0
    private var subtitleTrack = PlaybackSubtitleTrack.empty
    private var lastDisplayedCurrentTimePublishTimestamp: TimeInterval = 0
    private let onVolumeChanged: (Double) -> Void
    private let onLastNonzeroVolumeChanged: (Double) -> Void
    private let onPlaybackSpeedChanged: (Double) -> Void
    private let onSubtitlesVisibleChanged: (Bool) -> Void

    public init(
        player: PlaybackPlayer,
        initialVolume: Double = 100,
        initialLastNonzeroVolume: Double = 100,
        initialPlaybackSpeed: Double = 1.0,
        initialSubtitlesVisible: Bool = true,
        onVolumeChanged: @escaping (Double) -> Void = { _ in },
        onLastNonzeroVolumeChanged: @escaping (Double) -> Void = { _ in },
        onPlaybackSpeedChanged: @escaping (Double) -> Void = { _ in },
        onSubtitlesVisibleChanged: @escaping (Bool) -> Void = { _ in }
    ) {
        self.player = player
        self.onVolumeChanged = onVolumeChanged
        self.onLastNonzeroVolumeChanged = onLastNonzeroVolumeChanged
        self.onPlaybackSpeedChanged = onPlaybackSpeedChanged
        self.onSubtitlesVisibleChanged = onSubtitlesVisibleChanged

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

    private func performSeek(to seconds: Double, resetsAccumulatedFeedback: Bool) {
        let nonnegativeSeconds = seconds.isFinite ? max(seconds, 0) : 0
        let targetTime = duration > 0 ? min(nonnegativeSeconds, duration) : nonnegativeSeconds
        let previousTime = currentTime
        updatePlaybackTime(targetTime, publishesControlsImmediately: true)
        if resetsAccumulatedFeedback {
            accumulatedForwardSeconds = 0
            accumulatedRewindSeconds = 0
        }

        do {
            try player.seek(toMilliseconds: Int(targetTime * 1000))
        } catch {
            updatePlaybackTime(previousTime, publishesControlsImmediately: true)
            print("Failed to seek: \(error)")
        }
    }
    
    public func seekRelative(by seconds: Double) {
        let targetTime: Double

        if duration > 0 {
            targetTime = min(max(currentTime + seconds, 0), duration)
        } else {
            targetTime = max(currentTime + seconds, 0)
        }

        performSeek(to: targetTime, resetsAccumulatedFeedback: false)

        if seconds > 0 {
            accumulatedRewindSeconds = 0
            accumulatedForwardSeconds += Int(abs(seconds))
            showFeedback(
                PlaybackFeedback(
                    position: .trailing,
                    systemImage: "goforward.5",
                    text: "+ \(accumulatedForwardSeconds)s",
                    isCircular: false
                )
            )
        } else {
            accumulatedForwardSeconds = 0
            accumulatedRewindSeconds += Int(abs(seconds))
            showFeedback(
                PlaybackFeedback(
                    position: .leading,
                    systemImage: "gobackward.5",
                    text: "- \(accumulatedRewindSeconds)s",
                    isCircular: false
                )
            )
        }
    }

    public func setVolume(_ value: Double, showsFeedback: Bool = true) {
        let clampedValue = Self.clampedVolume(value)

        do {
            try player.setDoubleProperty("volume", value: clampedValue)
            applyVolumePreference(clampedValue)
            if showsFeedback {
                showVolumeFeedback(clampedValue)
            }
        } catch {
            print("Failed to set volume: \(error)")
        }
    }

    public func toggleMute() {
        setVolume(volume > 0 ? 0 : lastNonzeroVolume)
    }
    
    public func adjustVolume(by delta: Double) {
        setVolume(volume + delta)
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
        subtitleTrack = .empty
        refreshActiveSubtitleText()
    }

    func showSubtitleCopyFeedback(copied: Bool) {
        showFeedback(
            PlaybackFeedback(
                position: .center,
                systemImage: copied ? "pencil.tip" : "exclamationmark.triangle",
                text: copied ? "Copied" : "No Subtitle",
                isCircular: false
            ),
            durationMilliseconds: 1_000
        )
    }

    func showShioriFeedback(_ state: ShioriFeedbackState) {
        let feedback: PlaybackFeedback = switch state {
        case .saved:
            PlaybackFeedback(
                position: .center,
                systemImage: "bookmark.fill",
                text: "Shiori Saved",
                isCircular: false
            )
        case .removed:
            PlaybackFeedback(
                position: .center,
                systemImage: "bookmark",
                text: "Shiori Removed",
                isCircular: false
            )
        case .unavailable:
            PlaybackFeedback(
                position: .center,
                systemImage: "exclamationmark.triangle",
                text: "No Subtitle",
                isCircular: false
            )
        }

        showFeedback(feedback, durationMilliseconds: 1_000)
    }

    func showPlayPauseFeedback(isPlaying: Bool) {
        showFeedback(
            PlaybackFeedback(
                position: .center,
                systemImage: isPlaying ? "play.fill" : "pause.fill",
                text: nil,
                isCircular: true
            )
        )
    }

    private func showSubtitleFeedback(isVisible: Bool) {
        showFeedback(
            PlaybackFeedback(
                position: .center,
                systemImage: isVisible ? "captions.bubble.fill" : "captions.bubble",
                text: isVisible ? "Subtitles On" : "Subtitles Off",
                isCircular: false
            ),
            durationMilliseconds: 1_000
        )
    }

    private func showSpeedFeedback(_ speed: Double) {
        showFeedback(
            PlaybackFeedback(
                position: .center,
                systemImage: "speedometer",
                text: Self.formatSpeed(speed),
                isCircular: false
            )
        )
    }

    private func showVolumeFeedback(_ volume: Double) {
        showFeedback(
            PlaybackFeedback(
                position: .center,
                systemImage: volume > 0 ? "speaker.wave.3.fill" : "speaker.slash.fill",
                text: "\(Int(volume.rounded()))%",
                isCircular: false
            )
        )
    }

    private func refreshActiveSubtitleText() {
        let nextText = areSubtitlesVisible ? subtitleTrack.activeText(at: currentTime) : nil
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

    static func formatSpeed(_ speed: Double) -> String {
        if speed.rounded() == speed {
            return String(format: "%.0fx", speed)
        }

        if (speed * 10).rounded() == speed * 10 {
            return String(format: "%.1fx", speed)
        }

        return String(format: "%.2fx", speed)
    }
}

extension PlaybackViewModel: PlaybackPlayerDelegate {
    nonisolated public func player(_ player: PlaybackPlayer, didChangeProperty name: String, value: PlaybackPropertyValue?) {
        Task { @MainActor in
            guard let value else { return }
            switch name {
            case "time-pos":
                if case .double(let d) = value {
                    self.updatePlaybackTime(d)
                }
            case "duration":
                if case .double(let d) = value, self.duration != d {
                    self.duration = d
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
}
