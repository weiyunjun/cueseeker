import SwiftUI
import SubFinderXPlayback
import CMpv

@MainActor
public final class PlaybackViewModel: ObservableObject {
    public let player: MPVPlayer
    
    @Published public var isPlaying: Bool = false
    @Published public var currentTime: Double = 0
    @Published public var duration: Double = 0
    @Published public var volume: Double = 100
    @Published public var playbackSpeed: Double = 1.0
    @Published public var areSubtitlesVisible: Bool = true

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
        do {
            try player.setPaused(isPlaying) // if isPlaying is true, set pause to yes
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
    
    public func setVolume(_ value: Double) {
        do {
            try player.setDoubleProperty("volume", value: value)
        } catch {
            print("Failed to set volume: \(error)")
        }
    }
    
    public func setSpeed(_ value: Double) {
        do {
            try player.setDoubleProperty("speed", value: value)
        } catch {
            print("Failed to set speed: \(error)")
        }
    }

    public func toggleSubtitles() {
        let newValue = !areSubtitlesVisible

        do {
            try player.setStringProperty("sid", value: newValue ? "auto" : "no")
            areSubtitlesVisible = newValue
        } catch {
            print("Failed to toggle subtitles: \(error)")
        }
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
