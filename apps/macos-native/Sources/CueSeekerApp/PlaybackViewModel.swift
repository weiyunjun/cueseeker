import SwiftUI
import CueSeekerPlayback

enum PlaybackFeedbackPosition: Equatable {
    case center
    case leading
    case trailing
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

    public let player: PlaybackPlayer

    @Published public var isPlaying: Bool = false
    @Published public var currentTime: Double = 0 {
        didSet {
            refreshActiveSubtitleText()
        }
    }
    @Published public var duration: Double = 0
    @Published public var volume: Double = 100
    @Published public var playbackSpeed: Double = 1.0
    @Published public var areSubtitlesVisible: Bool = true
    @Published public private(set) var activeSubtitleText: String?
    @Published var feedback: PlaybackFeedback?

    private var feedbackClearTask: Task<Void, Never>?
    private var accumulatedForwardSeconds = 0
    private var accumulatedRewindSeconds = 0
    private var subtitleTrack = PlaybackSubtitleTrack.empty

    public init(player: PlaybackPlayer) {
        self.player = player
        self.player.delegate = self
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
        currentTime = targetTime
        if resetsAccumulatedFeedback {
            accumulatedForwardSeconds = 0
            accumulatedRewindSeconds = 0
        }

        do {
            try player.seek(toMilliseconds: Int(targetTime * 1000))
        } catch {
            currentTime = previousTime
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
        let clampedValue = min(max(value, 0), 100)

        do {
            try player.setDoubleProperty("volume", value: clampedValue)
            volume = clampedValue
            if showsFeedback {
                showVolumeFeedback(clampedValue)
            }
        } catch {
            print("Failed to set volume: \(error)")
        }
    }
    
    public func adjustVolume(by delta: Double) {
        setVolume(volume + delta)
    }

    public func setSpeed(_ value: Double, showsFeedback: Bool = true) {
        let clampedValue = min(
            max(value, Self.minimumPlaybackSpeed),
            Self.maximumPlaybackSpeed
        )

        do {
            try player.setDoubleProperty("speed", value: clampedValue)
            playbackSpeed = clampedValue
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
        let newValue = !areSubtitlesVisible

        areSubtitlesVisible = newValue
        player.setSubtitlesVisible(newValue)
        refreshActiveSubtitleText()
        showSubtitleFeedback(isVisible: newValue)
    }

    public func setSubtitleCues(
        _ cues: [PlaybackSubtitleCue],
        currentTimeMilliseconds: Int? = nil
    ) {
        subtitleTrack = PlaybackSubtitleTrack(cues: cues)
        if let currentTimeMilliseconds {
            currentTime = Double(max(0, currentTimeMilliseconds)) / 1_000
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
                    self.currentTime = d
                    self.refreshActiveSubtitleText()
                }
            case "duration":
                if case .double(let d) = value { self.duration = d }
            case "pause":
                if case .bool(let b) = value { self.isPlaying = !b }
            case "volume":
                if case .double(let d) = value { self.volume = d }
            case "speed":
                if case .double(let d) = value { self.playbackSpeed = d }
            default:
                break
            }
        }
    }

    nonisolated public func player(_ player: PlaybackPlayer, didFailWithMessage message: String) {
        print("Native playback failed: \(message)")
    }
}
