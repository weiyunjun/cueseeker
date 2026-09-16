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

    func togglePlaybackMoreMenu() {
        guard playback.moreMenu == nil else {
            playback.closeMoreMenu()
            return
        }
        guard let videoPath = player?.currentVideoURL?.path else {
            return
        }
        let recorded = recordedAudioTracks(forVideoPath: videoPath)
        let tracks = recorded?.tracks ?? []
        let currentIndex = player?.currentAudioTrackIndex
            .flatMap { tracks.indices.contains($0) ? $0 : nil } ?? 0
        playback.openMoreMenu(
            PlaybackAudioTrackMenu(
                trackNames: tracks.enumerated().map { index, track in
                    PlaybackAudioTrackName.name(for: track, at: index)
                },
                currentIndex: currentIndex,
                defaultIndex: recorded?.effectiveDefaultIndex ?? 0
            )
        )
    }

    /// Switches this playback's audio track. The track already playing is
    /// left alone.
    func selectPlaybackAudioTrack(_ index: Int) {
        guard let player, player.currentAudioTrackIndex != index else {
            return
        }
        do {
            try player.selectAudioTrack(at: index)
        } catch {
            playback.playbackStatus = .failed(Self.errorMessage(for: error))
        }
    }

    func setPlaybackDefaultAudioTrack(_ index: Int) {
        guard let database = libraryDatabase,
              let videoPath = player?.currentVideoURL?.path,
              recordedAudioTracks(forVideoPath: videoPath)?.effectiveDefaultIndex != index
        else {
            return
        }
        do {
            try database.setDefaultAudioTrackIndex(
                index,
                forVideoFile: URL(fileURLWithPath: videoPath)
            )
        } catch {
            print("Failed to save the default audio track: \(error)")
        }
    }

    private func recordedAudioTracks(forVideoPath videoPath: String) -> VideoAudioTracks? {
        guard let database = libraryDatabase else {
            return nil
        }
        do {
            return try database.videoAudioTracks(
                forVideoFile: URL(fileURLWithPath: videoPath)
            )
        } catch {
            print("Failed to load the audio tracks: \(error)")
            return nil
        }
    }
}
