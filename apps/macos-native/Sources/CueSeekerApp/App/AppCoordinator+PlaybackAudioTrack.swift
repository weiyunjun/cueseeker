import CueSeekerCore
import CueSeekerPlayback
import Foundation

/// The audio track a video plays and the one it opens on. See
/// `docs/human/requirements/20260917-Feature-In-Video Audio Track Switching And
/// Default Audio Track.md`.
@MainActor
extension AppCoordinator {
    /// The video's default audio track as set, counted from 0. The player
    /// falls back to the first track when the file does not have it.
    func defaultAudioTrackIndex(forVideoPath videoPath: String) -> Int {
        recordedAudioTracks(forVideoPath: videoPath)?.defaultIndex ?? 0
    }

    /// Whether opening an item can stay in the video already open and only
    /// seek: it is the same video, already playing the audio track the item
    /// opens on. Any other track reopens the video, so every item opened comes
    /// back to the default audio track.
    func canSeekInOpenVideo(for request: PlaybackRequest) -> Bool {
        guard let player,
              player.currentVideoURL?.mediaPath == request.videoURL.mediaPath
        else {
            return false
        }
        guard player.activeDecodeMode == player.decodeMode else {
            NSLog("[Playback] canSeekInOpenVideo: decodeMode mismatch (active=%@, target=%@), reopening session",
                  player.activeDecodeMode.rawValue,
                  player.decodeMode.rawValue)
            return false
        }
        let canSeek = player.currentAudioTrackIndex.map { $0 == request.audioTrackIndex } ?? true
        NSLog("[Playback] canSeekInOpenVideo: %@ -> canSeek=%d, activeMode=%@, usingHardware=%d",
              request.videoURL.lastPathComponent,
              canSeek ? 1 : 0,
              player.activeDecodeMode.rawValue,
              player.usingHardwareDecode ? 1 : 0)
        return canSeek
    }

    func togglePlaybackMoreMenu() {
        guard playback.moreMenu == nil else {
            playback.closeMoreMenu()
            return
        }
        // The lists are the database's for the current video, which a video
        // that failed to load still is; with nothing playing, the track it
        // would open on stands as the current one.
        guard let videoPath = currentPlaybackVideoPath else {
            return
        }
        let recorded = recordedAudioTracks(forVideoPath: videoPath)
        let tracks = recorded?.tracks ?? []
        let currentIndex = player?.currentAudioTrackIndex
            .flatMap { tracks.indices.contains($0) ? $0 : nil }
            ?? recorded?.effectiveDefaultIndex ?? 0
        playback.openMoreMenu(
            PlaybackMoreMenu(
                audioTracks: PlaybackMoreMenuList(
                    names: tracks.enumerated().map { index, track in
                        PlaybackAudioTrackName.name(for: track, at: index)
                    },
                    currentIndex: currentIndex,
                    defaultIndex: recorded?.effectiveDefaultIndex ?? 0
                ),
                subtitles: playbackSubtitleMenuList(forVideoPath: videoPath)
            )
        )
    }

    /// Switches this playback's audio track. The track already playing is
    /// left alone.
    func selectPlaybackAudioTrack(_ index: Int) {
        // A video that failed to load has no track to switch.
        guard let player,
              playback.playbackStatus != .loadFailed,
              player.currentAudioTrackIndex != index
        else {
            return
        }
        do {
            try player.selectAudioTrack(at: index)
        } catch {
            showPlaybackError(error)
        }
    }

    func setPlaybackDefaultAudioTrack(_ index: Int) {
        guard let database = libraryDatabase,
              let videoPath = currentPlaybackVideoPath,
              recordedAudioTracks(forVideoPath: videoPath)?.effectiveDefaultIndex != index
        else {
            return
        }
        Task.detached(priority: .utility) {
            do {
                try database.setDefaultAudioTrackIndex(
                    index,
                    forVideoFile: URL.fromMediaPath(videoPath)
                )
            } catch {
                print("Failed to save the default audio track: \(error)")
            }
        }
    }

    private func recordedAudioTracks(forVideoPath videoPath: String) -> VideoAudioTracks? {
        guard let database = libraryDatabase else {
            return nil
        }
        do {
            return try database.videoAudioTracks(
                forVideoFile: URL.fromMediaPath(videoPath)
            )
        } catch {
            print("Failed to load the audio tracks: \(error)")
            return nil
        }
    }
}
