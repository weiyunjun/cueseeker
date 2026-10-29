import CueSeekerCore
import Foundation

/// The subtitle a video plays and the one it opens on.
@MainActor
extension AppCoordinator {
    /// The video's default subtitle as it takes effect, which a Library open
    /// plays.
    func defaultPlaybackSubtitle(forVideoPath videoPath: String) -> VideoSubtitle? {
        recordedSubtitles(forVideoPath: videoPath)?.effectiveDefault
    }

    func makePlaybackSubtitleMenu(forVideoPath videoPath: String) -> PlaybackSubtitleMenu {
        let recorded = recordedSubtitles(forVideoPath: videoPath)
        let subtitles = recorded?.subtitles ?? []
        let currentID = currentPlaybackSubtitleFileID
        let defaultID = recorded?.effectiveDefault?.subtitleFileID
        return PlaybackSubtitleMenu(
            records: subtitles,
            subtitles: PlaybackMoreMenuList(
                names: subtitles.map { PlaybackSubtitleName.name(forSubtitlePath: $0.subtitlePath) },
                currentIndex: subtitles.firstIndex { $0.subtitleFileID == currentID } ?? 0,
                defaultIndex: subtitles.firstIndex { $0.subtitleFileID == defaultID } ?? 0
            ),
            areSubtitlesVisible: playback.playbackViewModel?.areSubtitlesVisible ?? false
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
        playback.openSubtitleMenu(makePlaybackSubtitleMenu(forVideoPath: videoPath))
    }

    /// Handles a choice in the Player Subtitle Menu using the snapshot captured
    /// when the menu opened, without re-querying the database. Choosing the
    /// already-checked row does nothing and shows no HUD.
    func selectPlaybackSubtitleMenuItem(_ position: Int) {
        guard let videoPath = currentPlaybackVideoPath else {
            return
        }
        let menu = playback.subtitleMenu ?? makePlaybackSubtitleMenu(forVideoPath: videoPath)
        let wasVisible = playback.playbackViewModel?.areSubtitlesVisible ?? false

        switch menu.choice(at: position) {
        case .off:
            guard wasVisible else {
                return
            }
            playback.playbackViewModel?.setSubtitlesVisible(false, showsFeedback: true)

        case .subtitle(let index):
            guard menu.records.indices.contains(index) else {
                return
            }
            let subtitle = menu.records[index]
            let isSameSubtitle = subtitle.subtitleFileID == currentPlaybackSubtitleFileID
            if wasVisible {
                guard !isSameSubtitle else {
                    return
                }
                applyPlaybackSubtitle(subtitle, forVideoPath: videoPath)
                playback.playbackViewModel?.showSubtitleSwitchedFeedback()
            } else if isSameSubtitle {
                playback.playbackViewModel?.setSubtitlesVisible(true, showsFeedback: true)
            } else {
                applyPlaybackSubtitle(subtitle, forVideoPath: videoPath)
                playback.playbackViewModel?.setSubtitlesVisible(true, showsFeedback: false)
                playback.playbackViewModel?.showSubtitleSwitchedFeedback()
            }

        case nil:
            return
        }
    }

    /// Switches this playback's subtitle where it stands: the time, playing or
    /// paused, and the Playlist stay as they are. The subtitle already playing
    /// is left alone. The subtitle loads on its own, so a video that failed to
    /// load still switches it and the Playback Overlay follows.
    func selectPlaybackSubtitle(_ index: Int) {
        guard let videoPath = currentPlaybackVideoPath,
              let subtitles = recordedSubtitles(forVideoPath: videoPath)?.subtitles,
              subtitles.indices.contains(index)
        else {
            return
        }
        applyPlaybackSubtitle(subtitles[index], forVideoPath: videoPath)
    }

    private func applyPlaybackSubtitle(_ subtitle: VideoSubtitle, forVideoPath videoPath: String) {
        guard subtitle.subtitleFileID != currentPlaybackSubtitleFileID else {
            return
        }
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
