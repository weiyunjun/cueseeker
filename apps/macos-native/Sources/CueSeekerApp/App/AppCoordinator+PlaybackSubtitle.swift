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
                forSubtitleFile: URL(fileURLWithPath: subtitle.subtitlePath),
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

    func setPlaybackDefaultSubtitle(_ index: Int) {
        guard let database = libraryDatabase,
              let videoPath = currentPlaybackVideoPath,
              let recorded = recordedSubtitles(forVideoPath: videoPath),
              recorded.subtitles.indices.contains(index),
              recorded.effectiveDefault != recorded.subtitles[index]
        else {
            return
        }
        let subtitleFileID = recorded.subtitles[index].subtitleFileID
        Task.detached(priority: .utility) {
            do {
                try database.setDefaultSubtitleFileID(
                    subtitleFileID,
                    forVideoFile: URL(fileURLWithPath: videoPath)
                )
            } catch {
                print("Failed to save the default subtitle: \(error)")
            }
        }
    }

    private func recordedSubtitles(forVideoPath videoPath: String) -> VideoSubtitles? {
        guard let database = libraryDatabase else {
            return nil
        }
        do {
            return try database.videoSubtitles(
                forVideoFile: URL(fileURLWithPath: videoPath)
            )
        } catch {
            print("Failed to load the subtitles: \(error)")
            return nil
        }
    }
}
