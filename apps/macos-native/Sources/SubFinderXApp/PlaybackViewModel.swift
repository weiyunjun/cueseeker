import SwiftUI
import SubFinderXPlayback
import CMpv

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
    public let player: MPVPlayer
    
    @Published public var isPlaying: Bool = false
    @Published public var currentTime: Double = 0
    @Published public var duration: Double = 0
    @Published public var volume: Double = 100
    @Published public var playbackSpeed: Double = 1.0
    @Published public var areSubtitlesVisible: Bool = true
    @Published var feedback: PlaybackFeedback?

    private var feedbackClearTask: Task<Void, Never>?
    private var accumulatedForwardSeconds = 0
    private var accumulatedRewindSeconds = 0

    public init(player: MPVPlayer) {
        self.player = player
        self.player.delegate = self
        
        self.player.observeProperty("time-pos", format: MPV_FORMAT_DOUBLE)
        self.player.observeProperty("duration", format: MPV_FORMAT_DOUBLE)
        self.player.observeProperty("pause", format: MPV_FORMAT_FLAG)
        self.player.observeProperty("volume", format: MPV_FORMAT_DOUBLE)
        self.player.observeProperty("speed", format: MPV_FORMAT_DOUBLE)
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
        do {
            try player.seek(toMilliseconds: Int(seconds * 1000))
        } catch {
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

        seek(to: targetTime)

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
        let clampedValue = min(max(value, 0.25), 4.0)

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

        do {
            try player.setStringProperty("sid", value: newValue ? "auto" : "no")
            areSubtitlesVisible = newValue
            showSubtitleFeedback(isVisible: newValue)
        } catch {
            print("Failed to toggle subtitles: \(error)")
        }
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
                text: formatSpeed(speed),
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

    private func formatSpeed(_ speed: Double) -> String {
        if speed.rounded() == speed {
            return String(format: "%.0fx", speed)
        }

        if (speed * 10).rounded() == speed * 10 {
            return String(format: "%.1fx", speed)
        }

        return String(format: "%.2fx", speed)
    }
}

extension PlaybackViewModel: MPVPlayerDelegate {
    nonisolated public func player(_ player: MPVPlayer, didChangeProperty name: String, value: MPVPropertyValue?) {
        Task { @MainActor in
            guard let value else { return }
            switch name {
            case "time-pos":
                if case .double(let d) = value { self.currentTime = d }
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
}
