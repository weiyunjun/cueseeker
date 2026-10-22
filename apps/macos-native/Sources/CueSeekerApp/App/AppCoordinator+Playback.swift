import AppKit
import Foundation
import CueSeekerCore
import CueSeekerPlayback


@MainActor
extension AppCoordinator {
    func togglePlaybackFullscreenFromUser() {
        guard let player, let playbackViewModel = playback.playbackViewModel else {
            return
        }

        guard beginVideoSizeTransition() else {
            return
        }

        let enteringFullscreen = !playbackFullscreenManager.isFullscreen
        let started = playbackFullscreenManager.toggleFullscreen(
            player: player,
            onTransitionCompleted: { [weak self] in
                self?.endVideoSizeTransition()
            }
        )
        if !started {
            endVideoSizeTransition()
        } else {
            playbackViewModel.showFullscreenFeedback(enteringFullscreen: enteringFullscreen)
        }
    }

    func exitPlaybackFullscreenFromUser() {
        guard playbackFullscreenManager.isFullscreen else {
            return
        }

        guard beginVideoSizeTransition() else {
            return
        }

        let started = playbackFullscreenManager.exitFullscreen(
            fromUser: true,
            onTransitionCompleted: { [weak self] in
                self?.endVideoSizeTransition()
            }
        )
        if !started {
            endVideoSizeTransition()
        } else {
            playback.playbackViewModel?.showFullscreenFeedback(enteringFullscreen: false)
        }
    }

    /// The window is entering a system fullscreen the page did not ask for —
    /// the zoom button's tiling menu. On the playback page that is playback's
    /// fullscreen from here on: same gate, same feedback, and F, Escape, the
    /// player's button and the zoom button all mean "leave".
    func windowWillEnterSystemFullscreen(_ window: NSWindow) {
        guard isPlaybackPageVisible, playbackFullscreenManager.state == .windowed else {
            return
        }

        let gated = beginVideoSizeTransition()
        let adopted = playbackFullscreenManager.adoptSystemFullscreen(
            window: window,
            entering: true,
            onTransitionCompleted: gated ? { [weak self] in self?.endVideoSizeTransition() } : nil
        )
        guard adopted else {
            if gated {
                endVideoSizeTransition()
            }
            return
        }
        playback.playbackViewModel?.showFullscreenFeedback(enteringFullscreen: true)
    }

    /// The playback page appeared in a window that is already fullscreen —
    /// the Workbench entered it first. The page shows its fullscreen
    /// presentation; the Workbench gets its fullscreen back when the page
    /// closes.
    func playbackPageDidAppear() {
        guard let window = player?.renderView.window
            ?? NSApplication.shared.keyWindow
            ?? NSApplication.shared.mainWindow,
              window.styleMask.contains(.fullScreen)
        else {
            return
        }
        playbackFullscreenManager.adoptSystemFullscreen(window: window, entering: false)
    }

    func minimizePlaybackWindowFromUser() {
        // Minimize is windowed-only (the custom top bar is hidden in
        // fullscreen, which has no minimize affordance), so just miniaturize
        // the window to the Dock.
        let window = player?.renderView.window
            ?? NSApplication.shared.keyWindow
            ?? NSApplication.shared.mainWindow
        window?.miniaturize(nil)
    }

    func beginVideoSizeTransition(durationNanoseconds: UInt64) -> Bool {
        beginVideoSizeTransition(duration: TimeInterval(durationNanoseconds) / 1_000_000_000)
    }

    func beginVideoSizeTransition(duration: TimeInterval) -> Bool {
        guard beginVideoSizeTransition() else {
            return false
        }

        completeVideoSizeTransition(after: duration)
        return true
    }

    func beginVideoSizeTransition() -> Bool {
        guard workbenchLayout.beginVideoSizeTransition() else {
            return false
        }

        videoSizeTransitionTask?.cancel()
        return true
    }

    func completeVideoSizeTransition(after duration: TimeInterval?) {
        let duration = max(0, duration ?? 0)
        guard duration > 0 else {
            endVideoSizeTransition()
            return
        }

        videoSizeTransitionTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            guard !Task.isCancelled else {
                return
            }

            await MainActor.run {
                self?.endVideoSizeTransition()
            }
        }
    }

    func endVideoSizeTransition() {
        workbenchLayout.endVideoSizeTransition()
        videoSizeTransitionTask = nil
    }

    static func animationResizeDuration(
        for window: NSWindow,
        targetFrame: NSRect
    ) -> TimeInterval {
        max(0, window.animationResizeTime(targetFrame))
    }

    func ensurePlayerInitialized() {
        guard player == nil else { return }
        let player = PlaybackPlayer()
        player.decodeMode = settings.playbackDecodeMode
        player.srtSubtitleStyle = settings.srtSubtitleStyle
        self.player = player
        playback.playbackViewModel = PlaybackViewModel(
            player: player,
            initialVolume: Self.loadPlaybackVolume(from: userDefaults),
            initialLastNonzeroVolume: Self.loadPlaybackLastNonzeroVolume(from: userDefaults),
            initialPlaybackSpeed: Self.loadPlaybackSpeed(from: userDefaults),
            initialSubtitlesVisible: userDefaults.bool(forKey: Self.playbackSubtitlesVisibleKey),
            uiProbeScope: uiProbeScope,
            onVolumeChanged: { [weak self] volume in
                self?.userDefaults.set(volume, forKey: Self.playbackVolumeKey)
            },
            onLastNonzeroVolumeChanged: { [weak self] volume in
                self?.userDefaults.set(volume, forKey: Self.playbackLastNonzeroVolumeKey)
            },
            onPlaybackSpeedChanged: { [weak self] speed in
                self?.userDefaults.set(speed, forKey: Self.playbackSpeedKey)
            },
            onSubtitlesVisibleChanged: { [weak self] isVisible in
                self?.userDefaults.set(isVisible, forKey: Self.playbackSubtitlesVisibleKey)
            },
            onPlaybackTimeUpdated: { [weak self] currentTime, duration in
                self?.handlePlaybackTimeUpdated(
                    currentTime: currentTime,
                    duration: duration
                )
            },
            onPlaybackFinished: { [weak self] in
                self?.handlePlaybackFinishedNaturally()
            },
            onAutoStopBoundaryReached: { [weak self] endMilliseconds in
                self?.handleCueAutoStopBoundaryReached(endMilliseconds: endMilliseconds)
            },
            onSeekInteractionBegan: { [weak self] in
                self?.handleCueAutoPauseSeekInteractionBegan()
            },
            onSeekCommitted: { [weak self] milliseconds in
                self?.handleCueAutoPauseSeekCommitted(toMilliseconds: milliseconds)
            },
            onPresentationCommitted: { [weak self] isPlaying in
                guard let self, self.hasPlaybackSelection else {
                    return
                }
                self.playback.playbackStatus = isPlaying ? .playing : .paused
            },
            onSubtitleSourceLoadFailure: { [weak self] url in
                self?.handleSubtitleSourceLoadFailure(url)
            }
        )
    }

    /// Loads the subtitle as its own step, apart from the video: a file that
    /// cannot be read is not shown, nothing stands in for it (the ASS segment
    /// cache included), and it becomes the banner's subtitle line. Loading a
    /// subtitle replaces the one before, so the old line goes first. See
    /// `docs/human/requirements/20260921-Bug-Missing Files Treated As Missing
    /// Database Records.md`.
    func loadablePlaybackSubtitleSource(
        _ source: PlaybackSubtitleSource?
    ) -> PlaybackSubtitleSource? {
        playback.clearError(on: .subtitle)
        guard let source else {
            return nil
        }
        let isReadable = source.url.isRemoteMediaURL
            ? WebDAVSubtitleCache.shared.loadData(for: source.url) != nil
            : FileManager.default.isReadableFile(atPath: source.url.path)
        guard isReadable else {
            showSubtitleLoadError(path: source.url.mediaPath)
            return nil
        }
        return source
    }

    /// A subtitle the renderer could not read after all. A failure that arrives
    /// once the subtitle has been replaced belongs to nothing on screen.
    func handleSubtitleSourceLoadFailure(_ url: URL) {
        let failedPath = url.mediaPath
        guard let currentPath = currentPlaybackSubtitlePath,
              URL.fromMediaPath(currentPath).mediaPath == failedPath
        else {
            return
        }
        showSubtitleLoadError(path: failedPath)
    }

    private func showSubtitleLoadError(path: String) {
        playback.showError(L("playback.error.subtitle_load_failed", path), on: .subtitle)
    }

    /// A video that cannot be opened is still the current video: the title,
    /// the Playback Overlay, the playlist and the neighbouring videos follow
    /// the database as before. Only the player is emptied, so the previous
    /// video does not play on, and every control stays usable with nothing to
    /// act on. `cueStartMilliseconds` keeps Repeat available for a cue.
    func handlePlaybackOpenFailure(
        _ error: Error,
        videoPath: String,
        cueStartMilliseconds: Int? = nil
    ) {
        print("Failed to open the video: \(error)")
        stopLibraryPlaybackHistoryTracking()
        try? player?.stop()
        playback.playbackViewModel?.resetPresentationForStoppedPlayback()
        playback.playbackStatus = .loadFailed
        if let cueStartMilliseconds {
            playback.setCanRepeatCurrentCue(
                cueRepeatStartMilliseconds(at: Double(cueStartMilliseconds) / 1_000) != nil
            )
        }
        playback.showError(L("playback.error.video_load_failed", videoPath), on: .video)
    }

    /// A player failure other than loading a file shows on the video line and
    /// blocks nothing.
    func showPlaybackError(_ error: Error) {
        print("Playback failed: \(error)")
        playback.showError(
            L("playback.error.playback_failed", Self.errorMessage(for: error)),
            on: .video
        )
    }

    func handlePlaybackTimeUpdated(currentTime: Double, duration: Double) {
        markCurrentLibraryPlaybackCompletedIfNeeded(
            currentTime: currentTime,
            duration: duration
        )
        playback.setCanRepeatCurrentCue(
            cueRepeatStartMilliseconds(at: currentTime) != nil
        )
    }

    func openSearchResult(
        _ result: SubtitleSearchResult,
        displayTitle: String? = nil,
        playbackSearchPromotion: PlaybackSearchPromotion? = nil,
        playlistSourceOverride: PlaybackPlaylistSource? = nil
    ) {
        ensurePlayerInitialized()
        clearCueAutoStopPlayback()
        invalidatePlaybackSubtitleFocusForSourceReplacement()
        if let playlistSourceOverride {
            playback.setPlaylistSource(playlistSourceOverride)
            if case .cue = playlistSourceOverride.origin {
                _ = playback.setPlaylistPosition(
                    itemIdentity: .search(result.entryID),
                    ordinal: 0
                )
            }
        } else {
            synchronizeSearchAndPlaylistOnPlayback(seed: result)
        }
        // The ordinal counts in the list the result was chosen from, which a
        // database change may have left apart from the playlist.
        if let playbackSearchPromotion,
           let source = playback.playlistSource,
           source.itemIdentity(at: playbackSearchPromotion.selectedOrdinal)
               == .search(result.entryID) {
            playback.setPlaylistSource(
                source,
                playbackSearchSelectedOrdinal: playbackSearchPromotion.selectedOrdinal
            )
        }
        playback.playbackStatus = .opening
        UIInvalidationProbe.mark(
            "ACTION UI.SearchResult.opened",
            details: "time=\(String(format: "%.2f", Double(result.startMilliseconds) / 1000.0))"
        )
        preparePlaybackKeyboardFocus()
        saveCurrentLibraryPlaybackHistory()
        stopLibraryPlaybackHistoryTracking()
        activePlaybackSource = .search
        let itemInLibrary = isCueInLibrary(result.entryID)
        currentPlaybackItemLeftLibrary = !itemInLibrary
        search.selectResult(result)
        if itemInLibrary, playbackSearchPromotion == nil {
            updateSearchNavigationSnapshotForOpenedResult(result)
        } else {
            search.updateNavigationSnapshot(nil)
        }
        excerpt.selectedExcerpt = nil
        library.selectedLibraryVideo = nil
        refreshPlaybackChromeSnapshot(
            displayTitle: playbackDisplayTitle(
                for: result,
                providedDisplayTitle: displayTitle
            )
        )
        playback.isPlaybackSurfaceExpanded = true
        if !itemInLibrary {
            playback.clearPlaylistPosition()
            playback.playbackStatus = .loadFailed
            try? player?.stop()
            playback.playbackViewModel?.resetPresentationForStoppedPlayback()
            showPlaybackItemNotInLibrary()
            if (playback.playlistSource?.boundary.totalCount ?? 0) == 0 {
                playback.playbackViewModel?.showNoAvailableNavigationFeedback(
                    direction: nil,
                    text: L("playback.hud.no_available_results")
                )
            }
        } else {
            playback.clearError(on: .notInLibrary)
            Task { @MainActor in
                await Task.yield()
                _ = play(result)
            }
        }
    }

    func preparePlaybackKeyboardFocus() {
        workbenchLayout.clearSearchFocus()
        NSApplication.shared.keyWindow?.makeFirstResponder(nil)
    }

    /// Seeks the current playback to an absolute timestamp through the shared
    /// playback command model. Used by the overlay-panel Subtitles rows. It
    /// must not touch the native render/seek core; `PlaybackViewModel.seek`
    /// already owns that dispatch.
    func seekCurrentPlayback(toMilliseconds milliseconds: Int) {
        guard let playbackViewModel = playback.playbackViewModel else {
            return
        }

        playbackViewModel.seek(to: Double(max(0, milliseconds)) / 1_000)
    }

    func revealCurrentVideoFile() {
        guard let currentPlaybackVideoPath else {
            return
        }

        revealFile(atPath: currentPlaybackVideoPath)
    }

    func revealCurrentSubtitleFile() {
        guard let currentPlaybackSubtitlePath else {
            return
        }

        revealFile(atPath: currentPlaybackSubtitlePath)
    }

    func resolveInitialDecodeMode(forVideoPath videoPath: String) -> PlaybackDecodeMode {
        let configuredMode = settings.playbackDecodeMode
        guard configuredMode != .software else {
            return .software
        }

        // Gate 1: Check database indexed metadata for known codec hardware capability
        if let codec = libraryDatabase?.videoCodec(forVideoPath: videoPath),
           !PlaybackHardwareCapabilities.isHardwareDecodeSupported(forCodec: codec) {
            NSLog("[Playback] Gate 1 (Metadata Pre-routing): codec=%@ not supported by hardware on current device, pre-routing to software decode", codec)
            return .software
        }

        return configuredMode
    }

    @discardableResult
    func prepareDecodeModeForPlayback(videoPath: String) -> PlaybackDecodeMode {
        let targetMode = resolveInitialDecodeMode(forVideoPath: videoPath)
        player?.decodeMode = targetMode
        return targetMode
    }

    @discardableResult
    func play(_ result: SubtitleSearchResult) -> Bool {
        ensurePlayerInitialized()
        let targetDecodeMode = prepareDecodeModeForPlayback(videoPath: result.videoPath)
        let codec = libraryDatabase?.videoCodec(forVideoPath: result.videoPath) ?? "unknown"
        NSLog("[Playback] AppCoordinator.play: videoPath=%@, codec=%@, startMs=%ld, settingMode=%@, targetMode=%@",
              result.videoPath,
              codec,
              result.startMilliseconds,
              settings.playbackDecodeMode.rawValue,
              targetDecodeMode.rawValue)
        beginCueAutoStopPlayback()
        saveCurrentLibraryPlaybackHistory()
        stopLibraryPlaybackHistoryTracking()
        activePlaybackSource = .search
        playbackSubtitle = nil
        playback.playbackStatus = .opening
        playback.clearError(on: .video)
        playback.clearError(on: .notInLibrary)
        playback.playbackViewModel?.preparePresentationTransition(
            to: Double(result.startMilliseconds) / 1_000,
            subtitleCues: []
        )

        do {
            let autoStopBoundary = configureCueAutoStopBoundary(
                startMilliseconds: result.startMilliseconds,
                endMilliseconds: result.endMilliseconds
            )
            let request = try PlaybackRequest(
                videoURL: URL.fromMediaPath(result.videoPath),
                startMilliseconds: result.startMilliseconds,
                autoStopAtMilliseconds: autoStopBoundary?.endMilliseconds,
                subtitleSource: loadablePlaybackSubtitleSource(playbackSubtitleSource(for: result)),
                audioTrackIndex: defaultAudioTrackIndex(forVideoPath: result.videoPath)
            )

            guard let player else {
                throw PlaybackError.playbackPlayerUnavailable
            }

            let generation: UInt
            if canSeekInOpenVideo(for: request) {
                if let autoStopBoundary {
                    generation = try player.seek(
                        to: autoStopBoundary,
                        subtitleSource: request.subtitleSource
                    )
                } else {
                    generation = try player.seek(
                        toMilliseconds: result.startMilliseconds,
                        subtitleSource: request.subtitleSource
                    )
                }
            } else {
                generation = try player.open(request)
            }

            playback.playbackViewModel?.bindPendingPresentation(to: generation)
            return true
        } catch {
            handlePlaybackOpenFailure(
                error,
                videoPath: result.videoPath,
                cueStartMilliseconds: result.startMilliseconds
            )
            return false
        }
    }


    func stopPlayback() {
        playbackAwaitsLibraryReconcile = false
        _ = playback.dismissCommandPanel()
        invalidatePlaybackSubtitleFocusForSourceReplacement()
        playback.clearPlaylistSource()
        clearCueAutoStopPlayback()
        do {
            saveCurrentLibraryPlaybackHistoryForPlaybackClose()
            stopLibraryPlaybackHistoryTracking()
            playbackFullscreenManager.exitFullscreen()
            playback.playbackViewModel?.cancelPendingPresentation()
            try player?.stop()
            playback.playbackViewModel?.clearSubtitleCues()
            activePlaybackSource = .none
            currentPlaybackItemLeftLibrary = false
            search.selectResult(nil)
            library.selectedLibraryVideo = nil
            excerpt.selectedExcerpt = nil
            clearPlaybackChromeSnapshot()
            playback.isPlaybackSurfaceExpanded = false
            playback.playbackStatus = .idle
            switch workbenchLayout.currentRoute {
            case .excerpt, .excerptList:
                refreshExcerptOnReappearanceIfNeeded()
            case .recent:
                refreshExcerptOnReappearanceIfNeeded()
                refreshRecentOnReappearanceIfNeeded()
            case .library:
                refreshLibraryOnReappearanceIfNeeded()
            case .file:
                refreshFileOnReappearanceIfNeeded()
            case .search:
                refreshSearchOnReappearanceIfNeeded()
            case .libraryFolder, .fileFolder, .fileFiles:
                break
            }
            playback.clearAllErrors()
        } catch {
            showPlaybackError(error)
        }
    }

    func revealFile(atPath path: String) {
        NSWorkspace.shared.activateFileViewerSelecting([
            URL(fileURLWithPath: path)
        ])
    }

    func playbackSubtitleSource(for result: SubtitleSearchResult) -> PlaybackSubtitleSource? {
        playbackSubtitleSource(
            forSubtitleFile: URL.fromMediaPath(result.subtitlePath),
            format: result.subtitleFormat,
            videoPath: result.videoPath,
            startingAtMilliseconds: result.startMilliseconds,
            fallbackEndMilliseconds: result.endMilliseconds
        )
    }

    func playbackSubtitleSource(for excerpt: Excerpt) -> PlaybackSubtitleSource? {
        playbackSubtitleSource(
            forSubtitleFile: URL.fromMediaPath(excerpt.subtitlePath),
            format: excerpt.subtitleFormat,
            videoPath: excerpt.videoPath,
            startingAtMilliseconds: excerpt.startMilliseconds,
            fallbackEndMilliseconds: excerpt.endMilliseconds
        )
    }

    func playbackSubtitleSource(
        forSubtitleFile subtitleURL: URL,
        format: SubtitleFormat,
        videoPath: String,
        startingAtMilliseconds startMilliseconds: Int,
        fallbackEndMilliseconds: Int
    ) -> PlaybackSubtitleSource? {
        let playbackFormat: PlaybackSubtitleSourceFormat
        switch format {
        case .srt, .vtt:
            playbackFormat = .srt
        case .ass, .ssa:
            playbackFormat = .ass
        }

        let videoURL = URL.fromMediaPath(videoPath)

        return PlaybackSubtitleSource(
            url: subtitleURL,
            format: playbackFormat,
            matchedVideoURL: videoURL,
            initialTimestampMilliseconds: startMilliseconds,
            preparationTimeWindow: playbackSubtitleTimeWindow(
                forSubtitleFile: subtitleURL,
                startingAtMilliseconds: startMilliseconds,
                fallbackEndMilliseconds: fallbackEndMilliseconds
            ),
            renderCacheDatabaseURL: databaseURL
        )
    }

    func playbackSubtitleTimeWindow(for result: SubtitleSearchResult) -> PlaybackSubtitleTimeWindow {
        playbackSubtitleTimeWindow(
            forSubtitleFile: URL.fromMediaPath(result.subtitlePath),
            startingAtMilliseconds: result.startMilliseconds,
            fallbackEndMilliseconds: result.endMilliseconds
        )
    }

    func playbackSubtitleTimeWindow(
        forSubtitleFile subtitleFile: URL,
        startingAtMilliseconds startMilliseconds: Int,
        fallbackEndMilliseconds: Int
    ) -> PlaybackSubtitleTimeWindow {
        let fallback = PlaybackSubtitleTimeWindow(
            startMilliseconds: startMilliseconds,
            endMilliseconds: fallbackEndMilliseconds
        )

        guard let playbackSubtitleDatabase else {
            return fallback
        }

        do {
            let timings = try playbackSubtitleDatabase.cueTimings(
                forSubtitleFile: subtitleFile,
                startingAtMilliseconds: startMilliseconds,
                limit: Self.assSubtitlePreparationCueLimit
            )

            guard !timings.isEmpty else {
                return fallback
            }

            let startMilliseconds = min(
                fallback.startMilliseconds,
                timings.map(\.startMilliseconds).min() ?? fallback.startMilliseconds
            )
            let endMilliseconds = max(
                fallback.endMilliseconds,
                timings.map(\.endMilliseconds).max() ?? fallback.endMilliseconds
            )

            return PlaybackSubtitleTimeWindow(
                startMilliseconds: startMilliseconds,
                endMilliseconds: endMilliseconds
            )
        } catch {
            print("Failed to load ASS subtitle preparation window: \(error)")
            return fallback
        }
    }

    static func loadPlaybackVolume(from userDefaults: UserDefaults) -> Double {
        clampedPlaybackVolume(
            userDefaults.double(forKey: playbackVolumeKey),
            fallback: 100
        )
    }

    static func loadPlaybackLastNonzeroVolume(from userDefaults: UserDefaults) -> Double {
        let volume = clampedPlaybackVolume(
            userDefaults.double(forKey: playbackLastNonzeroVolumeKey),
            fallback: 100
        )

        return volume > 0 ? volume : 100
    }

    static func loadPlaybackSpeed(from userDefaults: UserDefaults) -> Double {
        let speed = userDefaults.double(forKey: playbackSpeedKey)
        guard speed.isFinite else {
            return 1.0
        }

        return min(
            max(speed, PlaybackViewModel.minimumPlaybackSpeed),
            PlaybackViewModel.maximumPlaybackSpeed
        )
    }

    static func clampedPlaybackVolume(_ volume: Double, fallback: Double) -> Double {
        guard volume.isFinite else {
            return fallback
        }

        return min(max(volume, 0), 100)
    }

}
