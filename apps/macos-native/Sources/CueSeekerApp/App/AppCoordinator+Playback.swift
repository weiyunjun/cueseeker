import AppKit
import Foundation
import CueSeekerCore
import CueSeekerPlayback

struct PlaybackKeyboardTextInputState: Equatable, Sendable {
    let isEditableFocused: Bool
    let hasMarkedText: Bool
}

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

    func cueAutoStopBoundary(
        startMilliseconds: Int,
        endMilliseconds: Int
    ) -> PlaybackAutoStopBoundary? {
        guard activePlaylistCueSettings?.autoPauseEnabled == true
        else {
            return nil
        }

        return PlaybackAutoStopBoundary(
            startMilliseconds: startMilliseconds,
            endMilliseconds: cueAutoPauseTimestampMilliseconds(
                startMilliseconds: startMilliseconds,
                endMilliseconds: endMilliseconds
            )
        )
    }

    func configureCueAutoStopBoundary(
        startMilliseconds: Int,
        endMilliseconds: Int
    ) -> PlaybackAutoStopBoundary? {
        let boundary = cueAutoStopBoundary(
            startMilliseconds: startMilliseconds,
            endMilliseconds: endMilliseconds
        )
        activateCueAutoStopBoundary(boundary)
        return boundary
    }

    @discardableResult
    func pausePlayback() -> Bool {
        // A video that failed to load has nothing to pause.
        guard playback.playbackStatus != .loadFailed else {
            return true
        }
        guard let player else {
            showPlaybackError(PlaybackError.playbackPlayerUnavailable)
            return false
        }

        do {
            cancelAutoSwitchCueSequenceTask()
            clearCueSubtitlePresentationHold()
            try player.setPaused(true)
            if hasPlaybackSelection {
                playback.playbackStatus = .paused
            }
            saveCurrentLibraryPlaybackHistory()
            return true
        } catch {
            showPlaybackError(error)
            return false
        }
    }

    func suspendPlaybackForModalPresentation(wasPlaying: Bool) -> Bool {
        if wasPlaying {
            guard pausePlayback() else {
                return false
            }
        } else {
            cancelAutoSwitchCueSequenceTask()
        }
        flushPendingLibraryPlaybackHistoryPresentations()
        return true
    }

    func resumePlayback() {
        guard playback.playbackStatus != .loadFailed else {
            return
        }
        do {
            cancelAutoSwitchCueSequenceTask()
            clearCueSubtitlePresentationHold()
            currentCueAutoStopReached = false
            try player?.setPaused(false)
            if hasPlaybackSelection {
                playback.playbackStatus = .playing
            }
        } catch {
            showPlaybackError(error)
        }
    }

    func handleCueAutoStopBoundaryReached(endMilliseconds: Int) {
        guard cueAutoPauseArmed,
              isCurrentCueAutoStopEnd(endMilliseconds),
              playback.playlistPosition == activePlaylistCuePosition,
              activePlaylistCueSettings?.autoPauseEnabled == true
        else {
            return
        }

        cueAutoPauseArmed = false
        currentCueAutoStopReached = true
        playback.playbackStatus = .paused
        holdCurrentCueSubtitlePresentation(matchingEndMilliseconds: endMilliseconds)
        playback.playbackViewModel?.showAutoPauseFeedback()

        guard activePlaylistCueSettings?.autoPauseEnabled == true,
              activePlaylistCueSettings?.autoSwitchEnabled == true
        else {
            return
        }

        scheduleAutoSwitchCueSequence()
    }

    func beginCueAutoStopPlayback() {
        cuePlaybackGeneration += 1
        activeCueAutoPauseBoundary = nil
        cueAutoPauseArmed = false
        currentCueAutoStopReached = false
        cancelAutoSwitchCueSequenceTask()
        player?.setAutoPauseBoundary(nil)
        activePlaylistCueSettings = PlaylistCueEffectiveSettings(
            autoPauseEnabled: settings.autoPauseAfterCueFinishesEnabled,
            autoSwitchEnabled: settings.autoSwitchToNextCuesInPlaylistEnabled,
            autoSwitchGapMilliseconds: settings.autoSwitchCueSequenceGapMilliseconds
        )
        activePlaylistCuePosition = playback.playlistPosition
        playback.setCanRepeatCurrentCue(false)
    }

    func clearCueAutoStopPlayback() {
        cuePlaybackGeneration += 1
        activeCueAutoPauseBoundary = nil
        cueAutoPauseArmed = false
        currentCueAutoStopReached = false
        cancelAutoSwitchCueSequenceTask()
        player?.setAutoPauseBoundary(nil)
        activePlaylistCueSettings = nil
        activePlaylistCuePosition = nil
        playback.setCanRepeatCurrentCue(false)
    }

    func cueRepeatStartMilliseconds(at currentTime: Double) -> Int? {
        guard isPlaybackPageVisible,
              currentTime.isFinite,
              activePlaylistCueSettings?.autoSwitchEnabled == false
        else {
            return nil
        }

        let startMilliseconds: Int
        let endMilliseconds: Int
        switch activePlaybackSource {
        case .search:
            guard let result = search.selectedSearchResult else {
                return nil
            }
            startMilliseconds = result.startMilliseconds
            endMilliseconds = result.endMilliseconds
        case .excerpt:
            guard let selectedExcerpt = excerpt.selectedExcerpt else {
                return nil
            }
            startMilliseconds = selectedExcerpt.startMilliseconds
            endMilliseconds = selectedExcerpt.endMilliseconds
        case .library, .none:
            return nil
        }

        let currentMilliseconds = currentTime * 1_000
        guard currentMilliseconds >= Double(startMilliseconds),
              currentMilliseconds <= Double(endMilliseconds)
        else {
            return nil
        }
        return startMilliseconds
    }

    @discardableResult
    func repeatCurrentPlaylistCue() -> Bool {
        guard let viewModel = playback.playbackViewModel,
              let startMilliseconds = cueRepeatStartMilliseconds(
                  at: viewModel.currentTime
              ),
              viewModel.playFromCue(
                  at: Double(startMilliseconds) / 1_000,
                  autoPauseBoundary: activeCueAutoPauseBoundary
              )
        else {
            return false
        }

        playback.playbackStatus = .playing
        playback.setCanRepeatCurrentCue(true)
        return true
    }

    func cancelAutoSwitchCueSequenceTask() {
        autoSwitchCueSequenceGeneration += 1
        autoSwitchCueSequenceTask?.cancel()
        autoSwitchCueSequenceTask = nil
    }

    func activateCueAutoStopBoundary(_ boundary: PlaybackAutoStopBoundary?) {
        activeCueAutoPauseBoundary = boundary
        cueAutoPauseArmed = boundary != nil
        player?.setAutoPauseBoundary(boundary)
    }

    private func isCurrentCueAutoStopEnd(_ endMilliseconds: Int) -> Bool {
        activeCueAutoPauseBoundary?.endMilliseconds == endMilliseconds
    }

    func handleCueAutoPauseSeekInteractionBegan() {
        cancelAutoSwitchCueSequenceTask()
        currentCueAutoStopReached = false
        clearCueSubtitlePresentationHold()
    }

    func handleCueAutoPauseSeekCommitted(toMilliseconds milliseconds: Int) {
        handleCueAutoPauseSeekInteractionBegan()
        cueAutoPauseArmed = activePlaylistCueSettings?.autoPauseEnabled == true
            && activeCueAutoPauseBoundary.map {
                max(0, milliseconds) < $0.endMilliseconds
            } == true
    }

    func cueAutoPauseTimestampMilliseconds(
        startMilliseconds: Int,
        endMilliseconds: Int
    ) -> Int {
        let boundary = PlaybackAutoStopBoundary(
            startMilliseconds: startMilliseconds,
            endMilliseconds: endMilliseconds
        )
        guard boundary.endMilliseconds > boundary.startMilliseconds else {
            return boundary.startMilliseconds
        }

        return max(boundary.startMilliseconds, boundary.endMilliseconds - 1)
    }

    func clearCueSubtitlePresentationHold() {
        playback.playbackViewModel?.clearSubtitlePresentationHold()
    }

    private func holdCurrentCueSubtitlePresentation(matchingEndMilliseconds endMilliseconds: Int) {
        guard activeCueAutoPauseBoundary?.endMilliseconds == endMilliseconds else {
            return
        }

        playback.playbackViewModel?.holdSubtitlePresentation(
            atMilliseconds: endMilliseconds
        )
    }

    private func scheduleAutoSwitchCueSequence() {
        let generation = cuePlaybackGeneration
        let source = activePlaybackSource
        let playlistPosition = activePlaylistCuePosition
        guard let effectiveSettings = activePlaylistCueSettings else {
            return
        }
        let gapMilliseconds = effectiveSettings.autoSwitchGapMilliseconds
        guard currentCueAutoStopReached,
              playback.playbackStatus == .paused,
              effectiveSettings.autoPauseEnabled,
              effectiveSettings.autoSwitchEnabled,
              playback.playlistPosition == playlistPosition,
              playback.subtitleFocusSession == nil,
              playback.commandPanelPresentation == nil,
              source == .search || source == .excerpt
        else {
            return
        }

        cancelAutoSwitchCueSequenceTask()
        let autoSwitchGeneration = autoSwitchCueSequenceGeneration
        autoSwitchCueSequenceTask = Task { [weak self] in
            if gapMilliseconds > 0 {
                try? await Task.sleep(nanoseconds: UInt64(gapMilliseconds) * 1_000_000)
            }

            guard !Task.isCancelled else {
                return
            }

            await MainActor.run {
                guard let self,
                      self.cuePlaybackGeneration == generation,
                      self.autoSwitchCueSequenceGeneration == autoSwitchGeneration,
                      self.currentCueAutoStopReached,
                      self.playback.playbackStatus == .paused,
                      self.playback.playlistPosition == playlistPosition,
                      self.playback.subtitleFocusSession == nil,
                      self.playback.commandPanelPresentation == nil,
                      self.activePlaybackSource == source,
                      self.activePlaylistCueSettings == effectiveSettings,
                      effectiveSettings.autoPauseEnabled,
                      effectiveSettings.autoSwitchEnabled
                else {
                    return
                }

                self.autoSwitchCueSequenceTask = nil
                self.currentCueAutoStopReached = false
                switch source {
                case .search:
                    self.openAdjacentSearchResult(.next)
                case .excerpt:
                    self.openNextExcerpt()
                case .library, .none:
                    break
                }
            }
        }
    }

    func togglePlayback() {
        switch playback.playbackStatus {
        case .playing, .paused:
            if playback.playbackViewModel?.isPlaying == true {
                pausePlayback()
            } else {
                resumePlayback()
            }
        case .idle:
            if let selectedSearchResult = search.selectedSearchResult {
                play(selectedSearchResult)
            } else if let selectedLibraryVideo = library.selectedLibraryVideo {
                play(selectedLibraryVideo)
            } else if let selectedExcerpt = excerpt.selectedExcerpt {
                play(selectedExcerpt)
            }
        case .opening, .loadFailed:
            break
        }
    }

    func togglePlaybackFromUser() {
        // Nothing plays or pauses, so nothing is reported either.
        guard playback.playbackStatus != .loadFailed else {
            return
        }
        let willPlay = !(playback.playbackViewModel?.isPlaying ?? false)
        togglePlayback()
        playback.playbackViewModel?.showPlayPauseFeedback(isPlaying: willPlay)
    }

    @discardableResult
    func handlePlaybackKeyDown(
        keyCode: UInt16,
        modifierFlagsRawValue: UInt,
        isRepeat: Bool = false
    ) -> Bool {
        handlePlaybackKeyDown(
            keyCode: keyCode,
            modifierFlagsRawValue: modifierFlagsRawValue,
            isRepeat: isRepeat,
            textInputState: PlaybackKeyboardTextInputState(
                isEditableFocused: Self.isEditableTextInputFocused(),
                hasMarkedText: Self.hasMarkedTextInFocusedEditor()
            )
        )
    }

    /// Applies whatever the speed-menu highlight sits on, so Enter and a click
    /// commit through one path.
    ///
    /// Rebindable keys are read from `shortcuts`, the user's keymap unless the
    /// caller passes another: a game controller presses the default keys.
    @discardableResult
    func handlePlaybackKeyDown(
        keyCode: UInt16,
        modifierFlagsRawValue: UInt,
        isRepeat: Bool = false,
        textInputState: PlaybackKeyboardTextInputState,
        shortcuts: PlaybackShortcutKeymap? = nil
    ) -> Bool {
        let isPlaybackInterfaceVisible = currentPlaybackVideoPath != nil || playbackFullscreenManager.isFullscreen

        guard isPlaybackInterfaceVisible else {
            return false
        }

        guard currentPlaybackVideoPath != nil,
              let viewModel = playback.playbackViewModel
        else {
            return Self.handlePlaybackFullscreenEscape(
                keyCode: keyCode,
                isRepeat: isRepeat,
                isFullscreen: playbackFullscreenManager.isFullscreen,
                exitFullscreen: exitPlaybackFullscreenFromUser
            )
        }

        // If a covered view somehow holds first responder, drop the orphaned focus
        // so covered fields cannot receive keystrokes.
        let activeWindow = NSApplication.shared.keyWindow
            ?? NSApplication.shared.windows.first { $0 is CueSeekerMainWindow }
        if let window = activeWindow as? CueSeekerMainWindow,
           let view = window.firstResponder as? NSView,
           window.isWorkbenchCovered(),
           !window.isUncovered(view) {
            _ = window.makeFirstResponder(nil)
        }

        let modifierFlags = NSEvent.ModifierFlags(
            rawValue: modifierFlagsRawValue
        )
        let shortcuts = shortcuts ?? settings.playbackShortcuts.keymap
        let flags = modifierFlags.intersection(.deviceIndependentFlagsMask)
        let shortcutKey = PlaybackShortcutKey(
            keyCode: keyCode,
            command: flags.contains(.command),
            option: flags.contains(.option),
            control: flags.contains(.control),
            shift: flags.contains(.shift)
        )
        func isShortcut(_ action: PlaybackShortcutAction) -> Bool {
            shortcuts.effectiveKey(for: action) == shortcutKey
        }
        // The cue action the press runs where the Playback Overlay and the
        // Command Panel's search results offer Save to Excerpt, Copy Cue Text
        // and Copy Deep Link.
        let cueShortcutAction: PlaybackSubtitleFocusAction? = shortcuts
            .action(for: shortcutKey, in: .overlay)
            .flatMap(Self.cueAction(for:))

        // An open menu owns the keyboard: the arrows, Enter, Esc and the key
        // that opened it go to the menu, and every other in-app function is
        // spent here, so nothing underneath answers a key the menu did not
        // want. Only a press held with ⌘ travels on. The gate skips
        // covered menus, so a menu below the Command Panel stays on screen and
        // takes nothing while the panel is open. See
        // `docs/human/requirements/20260912-UI-Open Menu Blocks In-App
        // Shortcuts.md`.
        if interfaceLayers.hasUncoveredOpenMenu {
            guard modifierFlags.contains(.command) else {
                if !modifierFlags.contains(.shift) {
                    _ = interfaceLayers.menuGate.routeKey(keyCode, isRepeat: isRepeat)
                }
                return true
            }
        }

        if let subtitleFocusSession = playback.subtitleFocusSession,
           subtitleFocusSession.isEditingCollage {
            if isShortcut(.editCollage) {
                if !isRepeat {
                    _ = subtitleFocusSession.toggleEditingCollage()
                }
                return true
            }
            if let collageShortcut = shortcuts.action(for: shortcutKey, in: .collage) {
                if !isRepeat {
                    switch collageShortcut {
                    case .copyCollage:
                        _ = subtitleFocusSession.copyCurrentCollage()
                    case .exportCollage:
                        _ = subtitleFocusSession.exportCurrentCollage()
                    default:
                        break
                    }
                }
                return true
            }
            let editingCollageModifiers: NSEvent.ModifierFlags = [
                .command,
                .control,
                .option,
                .shift,
            ]
            guard modifierFlags.intersection(editingCollageModifiers).isEmpty
            else {
                return false
            }

            switch keyCode {
            case 53:
                if !isRepeat {
                    _ = subtitleFocusSession.toggleEditingCollage()
                }
                return true
            case 36, 76:
                if !isRepeat {
                    _ = subtitleFocusSession.toggleFocusedCollageCueSelection()
                }
                return true
            case 126:
                _ = subtitleFocusSession.requestKeyboardNavigation(.backward)
                return true
            case 125:
                _ = subtitleFocusSession.requestKeyboardNavigation(.forward)
                return true
            case 123, 124:
                return true
            default:
                return true
            }
        }
        if isShortcut(.openCommandPanel),
           !textInputState.isEditableFocused {
            if !isRepeat {
                _ = presentPlaybackCommandPanel()
            }
            return true
        }

        if let commandPanel = playback.commandPanelPresentation {
            let disallowedModifiers: NSEvent.ModifierFlags = [
                .command,
                .control,
                .option,
            ]
            if keyCode == 53,
               modifierFlags.intersection(disallowedModifiers).isEmpty {
                guard !isRepeat else {
                    return true
                }
                if commandPanel.page == .root {
                    return dismissPlaybackCommandPanelFromUser()
                }
                return returnPlaybackCommandPanelToRoot()
            }

            if commandPanel.page == .root,
               textInputState.isEditableFocused {
                guard !textInputState.hasMarkedText else {
                    return false
                }
                guard modifierFlags.intersection(disallowedModifiers).isEmpty
                else {
                    return false
                }
                switch keyCode {
                case 126:
                    _ = movePlaybackCommandPanelSelection(-1)
                    return true
                case 125:
                    _ = movePlaybackCommandPanelSelection(1)
                    return true
                case 36, 76:
                    if !isRepeat {
                        _ = openSelectedPlaybackCommandPanelItem()
                    }
                    return true
                default:
                    return false
                }
            }
            if let cueShortcutAction {
                if commandPanel.page == .searchResults, !isRepeat {
                    _ = requestPlaybackCommandPanelSearchAction(cueShortcutAction)
                }
                return true
            }
            guard modifierFlags.intersection(disallowedModifiers).isEmpty else {
                return true
            }
            switch keyCode {
            case 123 where commandPanel.page.showsRecentCardGrid:
                _ = movePlaybackCommandPanelRecentCardSelection(.left)
            case 124 where commandPanel.page.showsRecentCardGrid:
                _ = movePlaybackCommandPanelRecentCardSelection(.right)
            case 126:
                if commandPanel.page.showsRecentCardGrid {
                    _ = movePlaybackCommandPanelRecentCardSelection(.up)
                } else {
                    _ = movePlaybackCommandPanelSelection(-1)
                }
            case 125:
                if commandPanel.page.showsRecentCardGrid {
                    _ = movePlaybackCommandPanelRecentCardSelection(.down)
                } else {
                    _ = movePlaybackCommandPanelSelection(1)
                }
            case 36, 76:
                if !isRepeat {
                    _ = openSelectedPlaybackCommandPanelItem()
                }
            default:
                break
            }
            return true
        }

        if let subtitleFocusSession = playback.subtitleFocusSession {
            let disallowedModifiers: NSEvent.ModifierFlags = [.command, .control, .option]
            let moduleSwitchModifiers: NSEvent.ModifierFlags = [
                .command,
                .control,
                .option,
            ]

            if isShortcut(.editCollage) {
                if !isRepeat,
                   subtitleFocusSession.selectedModule == .current {
                    _ = subtitleFocusSession.toggleEditingCollage()
                }
                return true
            }

            if keyCode == 48,
               modifierFlags.intersection(moduleSwitchModifiers).isEmpty {
                if !isRepeat {
                    if modifierFlags.contains(.shift) {
                        _ = subtitleFocusSession.selectPreviousModule()
                    } else {
                        _ = subtitleFocusSession.selectNextModule()
                    }
                }
                return true
            }

            if keyCode == 53,
               modifierFlags.intersection(disallowedModifiers).isEmpty {
                guard !isRepeat else {
                    return true
                }
                return dismissPlaybackSubtitleFocusFromUser()
            }

            if subtitleFocusSession.selectedModule == .search {
                if textInputState.hasMarkedText {
                    return false
                }

                let searchActionModifiers: NSEvent.ModifierFlags = [
                    .command,
                    .control,
                    .option,
                    .shift,
                ]
                if modifierFlags.intersection(searchActionModifiers).isEmpty {
                    switch keyCode {
                    case 126:
                        _ = subtitleFocusSession.requestKeyboardNavigation(
                            .backward
                        )
                        return true
                    case 125:
                        _ = subtitleFocusSession.requestKeyboardNavigation(
                            .forward
                        )
                        return true
                    case 36, 76:
                        guard !isRepeat else {
                            return true
                        }
                        _ = requestPlaybackSearchPlayAction()
                        return true
                    default:
                        break
                    }
                }

                return !textInputState.isEditableFocused
            }

            let usesMediaPlaylist =
                subtitleFocusSession.selectedModule == .playlist
                && subtitleFocusSession.libraryStore != nil
            if subtitleFocusSession.selectedModule == .library
                || usesMediaPlaylist {
                guard !textInputState.isEditableFocused else {
                    return false
                }

                let mediaActionModifiers: NSEvent.ModifierFlags = [
                    .command,
                    .control,
                    .option,
                    .shift,
                ]
                guard modifierFlags.intersection(mediaActionModifiers).isEmpty else {
                    return false
                }

                switch keyCode {
                case 123:
                    _ = subtitleFocusSession.requestMediaSelectionNavigation(.left)
                case 124:
                    _ = subtitleFocusSession.requestMediaSelectionNavigation(.right)
                case 126:
                    _ = subtitleFocusSession.requestMediaSelectionNavigation(.up)
                case 125:
                    _ = subtitleFocusSession.requestMediaSelectionNavigation(.down)
                case 36, 76:
                    if !isRepeat {
                        _ = requestPlaybackLibraryPrimaryAction()
                    }
                default:
                    break
                }
                return true
            }

            guard !textInputState.isEditableFocused else {
                return false
            }

            if let cueShortcutAction {
                guard !isRepeat else {
                    return true
                }
                if subtitleFocusSession.selectedModule?.usesSharedCueShortcuts
                    == true {
                    _ = requestPlaybackSubtitleFocusAction(cueShortcutAction)
                }
                return true
            }

            guard modifierFlags.intersection(disallowedModifiers).isEmpty else {
                return false
            }

            switch keyCode {
            case 126:
                if subtitleFocusSession.selectedModule?.usesSharedCueShortcuts
                    == true {
                    _ = subtitleFocusSession.requestKeyboardNavigation(.backward)
                }
                return true
            case 125:
                if subtitleFocusSession.selectedModule?.usesSharedCueShortcuts
                    == true {
                    _ = subtitleFocusSession.requestKeyboardNavigation(.forward)
                }
                return true
            case 36, 76:
                guard !isRepeat else {
                    return true
                }
                if subtitleFocusSession.selectedModule?.usesSharedCueShortcuts
                    == true {
                    _ = requestPlaybackSubtitleFocusAction(.playFromThisCue)
                }
                return true
            case 49:
                return true
            default:
                return true
            }
        }

        if Self.handlePlaybackFullscreenEscape(
            keyCode: keyCode,
            isRepeat: isRepeat,
            isFullscreen: playbackFullscreenManager.isFullscreen,
            exitFullscreen: exitPlaybackFullscreenFromUser
        ) {
            return true
        }

        guard !textInputState.isEditableFocused else {
            return false
        }

        let playbackShortcut = shortcuts.action(for: shortcutKey, in: .playback)

        if playback.isTimelineScrubbing {
            return playbackShortcut != nil
        }

        switch playbackShortcut {
        case .previous:
            goPrevious()
            return true
        case .next:
            goNext()
            return true
        case .toggleSubtitles:
            viewModel.toggleSubtitles()
            return true
        case .repeatCue:
            if !isRepeat {
                _ = repeatCurrentPlaylistCue()
            }
            return true
        case .copyScreenshot:
            viewModel.copyCurrentFrameScreenshot()
            return true
        case .toggleFullscreen:
            togglePlaybackFullscreenFromUser()
            return true
        case .playPause:
            togglePlaybackFromUser()
            return true
        case .openPlaybackOverlay:
            guard !isRepeat else {
                return true
            }
            return openPlaybackSubtitleFocusFromUser()
        case .seekBackward:
            viewModel.seekRelative(by: -5)
            return true
        case .seekForward:
            viewModel.seekRelative(by: 5)
            return true
        case .volumeUp:
            viewModel.adjustVolume(by: 5)
            return true
        case .volumeDown:
            viewModel.adjustVolume(by: -5)
            return true
        case .speedDown:
            viewModel.adjustSpeed(by: -0.25)
            return true
        case .speedUp:
            viewModel.adjustSpeed(by: 0.25)
            return true
        case .openCommandPanel, .saveToExcerpt, .copyCueText, .copyDeepLink,
             .editCollage, .copyCollage, .exportCollage, nil:
            return false
        }
    }

    static func handlePlaybackFullscreenEscape(
        keyCode: UInt16,
        isRepeat: Bool,
        isFullscreen: Bool,
        exitFullscreen: () -> Void
    ) -> Bool {
        guard keyCode == 53, isFullscreen else {
            return false
        }
        if !isRepeat {
            exitFullscreen()
        }
        return true
    }

    /// The cue action behind an Overlay shortcut, for the three the Playback
    /// Overlay and the Command Panel's search results share.
    private static func cueAction(
        for shortcut: PlaybackShortcutAction
    ) -> PlaybackSubtitleFocusAction? {
        switch shortcut {
        case .saveToExcerpt:
            .excerpt
        case .copyCueText:
            .copyCueText
        case .copyDeepLink:
            .copyCueMarkdownLink
        default:
            nil
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

    static func isEditableTextInputFocused() -> Bool {
        let activeWindow = NSApplication.shared.keyWindow
            ?? NSApplication.shared.windows.first { $0 is CueSeekerMainWindow }
        guard let firstResponder = activeWindow?.firstResponder else {
            return false
        }

        if let view = firstResponder as? NSView {
            if let window = view.window as? CueSeekerMainWindow,
               window.isWorkbenchCovered(),
               !window.isUncovered(view) {
                return false
            }
        }

        if let textView = firstResponder as? NSTextView {
            return textView.isEditable
        }

        if let textField = firstResponder as? NSTextField {
            return textField.isEditable
        }

        if let view = firstResponder as? NSView {
            return view.ancestorOrSelfContainsEditableTextInput
        }

        return false
    }

    static func hasMarkedTextInFocusedEditor() -> Bool {
        let activeWindow = NSApplication.shared.keyWindow
            ?? NSApplication.shared.windows.first { $0 is CueSeekerMainWindow }
        guard let textView = activeWindow?.firstResponder
            as? NSTextView
        else {
            return false
        }
        if let window = textView.window as? CueSeekerMainWindow,
           window.isWorkbenchCovered(),
           !window.isUncovered(textView) {
            return false
        }
        return textView.hasMarkedText()
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
        case .ass:
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
private extension NSView {
    var ancestorOrSelfContainsEditableTextInput: Bool {
        if let textView = self as? NSTextView {
            return textView.isEditable
        }

        if let textField = self as? NSTextField {
            return textField.isEditable
        }

        var ancestor = superview
        while let current = ancestor {
            if let textView = current as? NSTextView {
                return textView.isEditable
            }

            if let textField = current as? NSTextField {
                return textField.isEditable
            }
            ancestor = current.superview
        }

        return false
    }
}
