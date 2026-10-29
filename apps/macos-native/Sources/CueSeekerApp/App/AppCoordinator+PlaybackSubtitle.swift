import CueSeekerCore
import Foundation

/// The subtitle a video plays and the one it opens on. See
/// `docs/human/requirements/20260918-Feature-In-Video Subtitle Switching And
/// Default Subtitle.md`.
@MainActor
extension AppCoordinator {
    /// The video's default subtitle as it takes effect, which a Library open
    /// plays.
    func defaultPlaybackSubtitle(forVideoPath videoPath: String) -> VideoSubtitle? {
        recordedSubtitles(forVideoPath: videoPath)?.effectiveDefault
    }

    func playbackSubtitleMenuList(forVideoPath videoPath: String) -> PlaybackMoreMenuList {
        let recorded = recordedSubtitles(forVideoPath: videoPath)
        let subtitles = recorded?.subtitles ?? []
        let currentID = currentPlaybackSubtitleFileID
        let defaultID = recorded?.effectiveDefault?.subtitleFileID
        return PlaybackMoreMenuList(
            names: subtitles.map { PlaybackSubtitleName.name(forSubtitlePath: $0.subtitlePath) },
            currentIndex: subtitles.firstIndex { $0.subtitleFileID == currentID } ?? 0,
            defaultIndex: subtitles.firstIndex { $0.subtitleFileID == defaultID } ?? 0
        )
    }

    func togglePlaybackSubtitleMenu() {
        guard playback.subtitleMenu == nil else {
            playback.closeSubtitleMenu()
            return
        }
        guard let videoPath = currentPlaybackVideoPath else {
            return
        }
        playback.openSubtitleMenu(
            PlaybackSubtitleMenu(
                subtitles: playbackSubtitleMenuList(forVideoPath: videoPath),
                areSubtitlesVisible: playback.playbackViewModel?.areSubtitlesVisible ?? false
            )
        )
    }

    /// Handles a choice in the Player Subtitle Menu: a subtitle row (`0 ..< count`)
    /// or the trailing `Off` row (`count`). Choosing the already-checked row
    /// does nothing and shows no HUD.
    func selectPlaybackSubtitleMenuItem(_ position: Int) {
        guard let videoPath = currentPlaybackVideoPath else {
            return
        }
        let subtitles = recordedSubtitles(forVideoPath: videoPath)?.subtitles ?? []
        let wasVisible = playback.playbackViewModel?.areSubtitlesVisible ?? false

        if position == subtitles.count {
            guard wasVisible else {
                return
            }
            playback.playbackViewModel?.setSubtitlesVisible(false, showsFeedback: true)
            return
        }

        guard subtitles.indices.contains(position) else {
            return
        }
        let isSameSubtitle = subtitles[position].subtitleFileID == currentPlaybackSubtitleFileID
        if wasVisible {
            guard !isSameSubtitle else {
                return
            }
            selectPlaybackSubtitle(position)
            playback.playbackViewModel?.showSubtitleSwitchedFeedback()
        } else if isSameSubtitle {
            playback.playbackViewModel?.setSubtitlesVisible(true, showsFeedback: true)
        } else {
            selectPlaybackSubtitle(position)
            playback.playbackViewModel?.setSubtitlesVisible(true, showsFeedback: false)
            playback.playbackViewModel?.showSubtitleSwitchedFeedback()
        }
    }

    /// Switches this playback's subtitle where it stands: the time, playing or
    /// paused, and the Playlist stay as they are. The subtitle already playing
    /// is left alone. The subtitle loads on its own, so a video that failed to
    /// load still switches it and the Playback Overlay follows.
    func selectPlaybackSubtitle(_ index: Int) {
        guard let videoPath = currentPlaybackVideoPath,
              let subtitles = recordedSubtitles(forVideoPath: videoPath)?.subtitles,
              subtitles.indices.contains(index),
              subtitles[index].subtitleFileID != currentPlaybackSubtitleFileID
        else {
            return
        }
        let subtitle = subtitles[index]
        let seconds = playback.playbackViewModel?.currentTime ?? 0
        let milliseconds = seconds.isFinite ? Int(max(0, seconds * 1_000).rounded(.down)) : 0
        let source = loadablePlaybackSubtitleSource(
            playbackSubtitleSource(
                forSubtitleFile: URL.fromMediaPath(subtitle.subtitlePath),
                format: subtitle.format,
                videoPath: videoPath,
                startingAtMilliseconds: milliseconds,
                fallbackEndMilliseconds: milliseconds
            )
        )
        if let player, playback.playbackStatus != .loadFailed {
            player.loadSubtitleSource(source)
        }
        playbackSubtitle = subtitle
    }

    private func recordedSubtitles(forVideoPath videoPath: String) -> VideoSubtitles? {
        guard let database = libraryDatabase else {
            return nil
        }
        do {
            return try database.videoSubtitles(
                forVideoFile: URL.fromMediaPath(videoPath)
            )
        } catch {
            print("Failed to load the subtitles: \(error)")
            return nil
        }
    }
}
