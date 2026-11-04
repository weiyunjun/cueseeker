import CueSeekerCore
import CueSeekerPlayback
import Foundation

/// The audio track a video plays and the one it opens on. See
/// `docs/human/requirements/20260917-Feature-In-Video Audio Track Switching And
/// Default Audio Track.md`.
@MainActor
extension AppCoordinator {
    func invalidateCachedVideoPlaybackMetadata() {
        cachedVideoPlaybackMetadataByMediaPath.removeAll(keepingCapacity: true)
    }

    private func synchronizeCachedVideoPlaybackMetadataRevision() {
        let currentRevision = search.indexedCueDataRevision
        guard cachedVideoPlaybackMetadataRevision != currentRevision else {
            return
        }
        cachedVideoPlaybackMetadataRevision = currentRevision
        cachedVideoPlaybackMetadataByMediaPath.removeAll(keepingCapacity: true)
    }

    func resolvedOpenVideoPlaybackMetadata(
        forVideoPath videoPath: String
    ) -> (codec: String?, defaultAudioTrackIndex: Int) {
        let mediaPath = URL.fromMediaPath(videoPath).mediaPath
        synchronizeCachedVideoPlaybackMetadataRevision()
        if let cached = cachedVideoPlaybackMetadataByMediaPath[mediaPath],
           cached.hasLoadedCodecAndAudioTrack {
            return (cached.codec, cached.defaultAudioTrackIndex)
        }
        let codec = libraryDatabase?.videoCodec(forVideoPath: videoPath)
        let defaultAudioTrackIndex = recordedAudioTracks(forVideoPath: videoPath)?.defaultIndex ?? 0
        if libraryDatabase != nil {
            var entry = cachedVideoPlaybackMetadataByMediaPath[mediaPath]
                ?? CachedVideoPlaybackMetadata(
                    codec: codec,
                    defaultAudioTrackIndex: defaultAudioTrackIndex
                )
            entry.codec = codec
            entry.defaultAudioTrackIndex = defaultAudioTrackIndex
            entry.hasLoadedCodecAndAudioTrack = true
            cachedVideoPlaybackMetadataByMediaPath[mediaPath] = entry
        }
        return (codec, defaultAudioTrackIndex)
    }

    func resolvedStoredPlaybackDisplayTitle(
        forVideoPath videoPath: String
    ) -> String? {
        let mediaPath = URL.fromMediaPath(videoPath).mediaPath
        synchronizeCachedVideoPlaybackMetadataRevision()
        if let cached = cachedVideoPlaybackMetadataByMediaPath[mediaPath],
           cached.hasLoadedStoredDisplayTitle {
            return cached.storedDisplayTitle
        }
        let storedDisplayTitle = (try? libraryDatabase?.displayTitle(
            forVideoFile: URL.fromMediaPath(videoPath)
        ))?.trimmingCharacters(in: .whitespacesAndNewlines)
        if libraryDatabase != nil {
            var entry = cachedVideoPlaybackMetadataByMediaPath[mediaPath]
                ?? CachedVideoPlaybackMetadata(
                    codec: nil,
                    defaultAudioTrackIndex: 0
                )
            entry.storedDisplayTitle = storedDisplayTitle
            entry.hasLoadedStoredDisplayTitle = true
            cachedVideoPlaybackMetadataByMediaPath[mediaPath] = entry
        }
        return storedDisplayTitle
    }

    /// The video's default audio track as set, counted from 0. The player
    /// falls back to the first track when the file does not have it.
    func defaultAudioTrackIndex(forVideoPath videoPath: String) -> Int {
        resolvedOpenVideoPlaybackMetadata(forVideoPath: videoPath).defaultAudioTrackIndex
    }

    func canSeekInCurrentlyOpenVideo(forVideoPath videoPath: String) -> Bool {
        guard playback.playbackViewModel?.isOpeningNewVideo != true,
              let player,
              player.currentVideoURL?.mediaPath == URL.fromMediaPath(videoPath).mediaPath
        else {
            return false
        }
        let metadata = resolvedOpenVideoPlaybackMetadata(forVideoPath: videoPath)
        let targetDecodeMode = resolveInitialDecodeMode(
            forVideoPath: videoPath,
            codec: metadata.codec
        )
        guard player.activeDecodeMode == targetDecodeMode else {
            return false
        }
        return player.currentAudioTrackIndex.map { $0 == metadata.defaultAudioTrackIndex } ?? true
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
            AppLogger.shared.debug(
                .playback,
                "Reopening playback session due to decode mode mismatch",
                details: "active=\(player.activeDecodeMode.rawValue) target=\(player.decodeMode.rawValue)"
            )
            return false
        }
        let canSeek = player.currentAudioTrackIndex.map { $0 == request.audioTrackIndex } ?? true
        AppLogger.shared.debug(
            .playback,
            "Evaluated in-session seek eligibility",
            details: "video=\"\(request.videoURL.lastPathComponent)\" can_seek=\(canSeek ? 1 : 0) active_mode=\(player.activeDecodeMode.rawValue) hw_decode=\(player.usingHardwareDecode ? 1 : 0)"
        )
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
                )
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
            AppLogger.shared.info(
                .playback,
                "Audio track switched",
                details: "video=\"\(player.currentVideoURL?.lastPathComponent ?? "none")\" track_index=\(index)"
            )
        } catch {
            showPlaybackError(error)
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
            AppLogger.shared.warn(
                .database,
                "Failed to load video audio tracks",
                details: "error=\"\(error.localizedDescription)\""
            )
            return nil
        }
    }
}
