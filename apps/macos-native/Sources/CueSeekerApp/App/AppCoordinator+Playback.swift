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
            animated: true,
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
            }
        )
    }

    func handlePlaybackTimeUpdated(currentTime: Double, duration: Double) {
        markCurrentLibraryPlaybackCompletedIfNeeded(
            currentTime: currentTime,
            duration: duration
        )
    }

    func initializePlaybackReturnContextIfEntering() {
        guard !playback.isPlaybackSurfaceExpanded else {
            return
        }
        playbackReturnContext = resolvedPlaybackReturnContext(
            for: workbenchLayout.panelMode
        )
    }

    func commitPlaybackReturnContext(
        _ context: PlaybackReturnContext,
        afterSuccessfulPlayback didStartPlayback: Bool
    ) {
        guard didStartPlayback else {
            return
        }
        playbackReturnContext = context
    }

    func commitPlaybackReturnContext(
        for panelMode: WorkbenchPanelMode,
        afterSuccessfulPlayback didStartPlayback: Bool
    ) {
        guard let context = resolvedPlaybackReturnContext(for: panelMode) else {
            return
        }
        commitPlaybackReturnContext(
            context,
            afterSuccessfulPlayback: didStartPlayback
        )
    }

    private func resolvedPlaybackReturnContext(
        for panelMode: WorkbenchPanelMode
    ) -> PlaybackReturnContext? {
        switch panelMode {
        case .search:
            .search
        case .shiori:
            .shiori
        case .recentWatching:
            .recent
        case .library, .testLibrary:
            workbenchLayout.selectedTestLibraryFolder.map {
                .libraryFolderDetail(folderPath: $0.folderPath)
            }
        }
    }

    func restorePlaybackReturnContext() {
        guard let context = playbackReturnContext else {
            return
        }
        playbackReturnContext = nil

        switch context {
        case .search:
            workbenchLayout.selectPanelMode(.search)
        case .shiori:
            workbenchLayout.selectPanelMode(.shiori)
        case .recent:
            workbenchLayout.selectPanelMode(.recentWatching)
        case .libraryFolderDetail(let folderPath):
            workbenchLayout.selectPanelMode(.testLibrary)
            guard let folder = library.completeLibraryFolderSummaries.first(
                where: { $0.folderPath == folderPath }
            ) else {
                workbenchLayout.clearTestLibraryFolder()
                return
            }
            workbenchLayout.selectTestLibraryFolder(folder)
            hydrateCompleteLibraryFolderDetailAsync(folderPath: folderPath)
        }
    }

    func openSearchResult(
        _ result: SubtitleSearchResult,
        displayTitle: String? = nil,
        returnPanelMode: WorkbenchPanelMode? = nil,
        playbackSearchPromotion: PlaybackSearchPromotion? = nil,
        playlistSourceOverride: PlaybackPlaylistSource? = nil
    ) {
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
            installSearchPlaybackPlaylistSource(seed: result)
        }
        if let playbackSearchPromotion,
           let source = playback.playlistSource {
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
        initializePlaybackReturnContextIfEntering()
        saveCurrentLibraryPlaybackHistory()
        stopLibraryPlaybackHistoryTracking()
        activePlaybackSource = .search
        search.selectResult(result)
        if playbackSearchPromotion == nil {
            updateSearchNavigationSnapshotForOpenedResult(result)
        } else {
            search.updateNavigationSnapshot(nil)
        }
        shiori.selectedShiori = nil
        library.selectedLibraryVideo = nil
        refreshPlaybackChromeSnapshot(
            displayTitle: playbackDisplayTitle(
                for: result,
                providedDisplayTitle: displayTitle
            )
        )
        playback.isPlaybackSurfaceExpanded = true
        workbenchLayout.selectPanelMode(.search)
        Task { @MainActor in
            await Task.yield()
            let didStartPlayback = play(result)
            if let returnPanelMode {
                commitPlaybackReturnContext(
                    for: returnPanelMode,
                    afterSuccessfulPlayback: didStartPlayback
                )
            }
            if playbackSearchPromotion != nil {
                commitPlaybackReturnContext(
                    .search,
                    afterSuccessfulPlayback: didStartPlayback
                )
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

    @discardableResult
    func play(_ result: SubtitleSearchResult) -> Bool {
        ensurePlayerInitialized()
        beginCueAutoStopPlayback()
        saveCurrentLibraryPlaybackHistory()
        stopLibraryPlaybackHistoryTracking()
        activePlaybackSource = .search
        playback.playbackStatus = .opening
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
                videoURL: URL(fileURLWithPath: result.videoPath),
                startMilliseconds: result.startMilliseconds,
                autoStopAtMilliseconds: autoStopBoundary?.endMilliseconds,
                subtitleSource: playbackSubtitleSource(for: result)
            )

            guard let player else {
                throw PlaybackError.playbackPlayerUnavailable
            }

            let generation: UInt
            if player.currentVideoURL?.standardizedFileURL.path == request.videoURL.standardizedFileURL.path {
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
            playback.playbackViewModel?.cancelPendingPresentation()
            clearCueAutoStopPlayback()
            playback.playbackViewModel?.clearSubtitleCues()
            playback.playbackStatus = .failed(Self.errorMessage(for: error))
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
        guard let player else {
            playback.playbackStatus = .failed(Self.errorMessage(for: PlaybackError.playbackPlayerUnavailable))
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
            playback.playbackStatus = .failed(Self.errorMessage(for: error))
            return false
        }
    }

    func suspendPlaybackForModalPresentation(wasPlaying: Bool) -> Bool {
        guard wasPlaying else {
            cancelAutoSwitchCueSequenceTask()
            return true
        }
        return pausePlayback()
    }

    func resumePlayback() {
        do {
            cancelAutoSwitchCueSequenceTask()
            clearCueSubtitlePresentationHold()
            currentCueAutoStopReached = false
            try player?.setPaused(false)
            if hasPlaybackSelection {
                playback.playbackStatus = .playing
            }
        } catch {
            playback.playbackStatus = .failed(Self.errorMessage(for: error))
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
              source == .search || source == .shiori
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
                case .shiori:
                    self.openNextShiori()
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
            } else if let selectedShiori = shiori.selectedShiori {
                play(selectedShiori)
            }
        case .opening, .failed:
            break
        }
    }

    func togglePlaybackFromUser() {
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

    @discardableResult
    func handlePlaybackKeyDown(
        keyCode: UInt16,
        modifierFlagsRawValue: UInt,
        isRepeat: Bool = false,
        textInputState: PlaybackKeyboardTextInputState
    ) -> Bool {
        let isPlaybackInterfaceVisible = currentPlaybackVideoPath != nil || playbackFullscreenManager.isFullscreen

        guard isPlaybackInterfaceVisible else {
            return false
        }

        playback.requestPointerHide()

        guard currentPlaybackVideoPath != nil, let viewModel = playback.playbackViewModel else {
            return false
        }

        let modifierFlags = NSEvent.ModifierFlags(
            rawValue: modifierFlagsRawValue
        )
        if let subtitleFocusSession = playback.subtitleFocusSession,
           subtitleFocusSession.isEditingCollage {
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
            case 35, 53:
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
        let commandPanelModifiers: NSEvent.ModifierFlags = [
            .command,
            .control,
            .option,
            .shift,
        ]
        if keyCode == 50,
           modifierFlags.intersection(commandPanelModifiers).isEmpty,
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
            guard modifierFlags.intersection(disallowedModifiers).isEmpty else {
                return true
            }
            switch keyCode {
            case 123 where commandPanel.page == .recentVideos:
                _ = movePlaybackCommandPanelRecentVideoSelection(.left)
            case 124 where commandPanel.page == .recentVideos:
                _ = movePlaybackCommandPanelRecentVideoSelection(.right)
            case 126:
                if commandPanel.page == .recentVideos {
                    _ = movePlaybackCommandPanelRecentVideoSelection(.up)
                } else {
                    _ = movePlaybackCommandPanelSelection(-1)
                }
            case 125:
                if commandPanel.page == .recentVideos {
                    _ = movePlaybackCommandPanelRecentVideoSelection(.down)
                } else {
                    _ = movePlaybackCommandPanelSelection(1)
                }
            case 1:
                if commandPanel.page == .searchResults, !isRepeat {
                    _ = requestPlaybackCommandPanelSearchAction(.shiori)
                }
            case 8:
                if commandPanel.page == .searchResults, !isRepeat {
                    _ = requestPlaybackCommandPanelSearchAction(.copyCueText)
                }
            case 7:
                if commandPanel.page == .searchResults, !isRepeat {
                    _ = requestPlaybackCommandPanelSearchAction(
                        .copyCueMarkdownLink
                    )
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
                .shift,
            ]

            if keyCode == 35,
               modifierFlags.intersection(moduleSwitchModifiers).isEmpty {
                if !isRepeat,
                   subtitleFocusSession.selectedModule == .current {
                    _ = subtitleFocusSession.toggleEditingCollage()
                }
                return true
            }

            if keyCode == 48,
               modifierFlags.intersection(moduleSwitchModifiers).isEmpty {
                if !isRepeat {
                    _ = subtitleFocusSession.selectNextModule()
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
            case 1:
                guard !isRepeat else {
                    return true
                }
                if subtitleFocusSession.selectedModule?.usesSharedCueShortcuts
                    == true {
                    _ = requestPlaybackSubtitleFocusAction(.shiori)
                }
                return true
            case 8:
                guard !isRepeat else {
                    return true
                }
                if subtitleFocusSession.selectedModule?.usesSharedCueShortcuts
                    == true {
                    _ = requestPlaybackSubtitleFocusAction(.copyCueText)
                }
                return true
            case 7:
                guard !isRepeat else {
                    return true
                }
                if subtitleFocusSession.selectedModule?.usesSharedCueShortcuts
                    == true {
                    _ = requestPlaybackSubtitleFocusAction(.copyCueMarkdownLink)
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

        guard !textInputState.isEditableFocused else {
            return false
        }

        let disallowedModifiers: NSEvent.ModifierFlags = [.command, .control, .option]

        guard modifierFlags.intersection(disallowedModifiers).isEmpty else {
            return false
        }

        let hasShift = modifierFlags.contains(.shift)

        if playback.isTimelineScrubbing {
            return Self.isPlaybackShortcutKey(keyCode: keyCode, hasShift: hasShift)
        }

        switch keyCode {
        case 0:
            goPrevious()
            return true
        case 2:
            goNext()
            return true
        case 12:
            viewModel.toggleSubtitles()
            return true
        case 35 where !hasShift:
            viewModel.copyCurrentFrameScreenshot()
            return true
        case 3:
            togglePlaybackFullscreenFromUser()
            return true
        case 49:
            togglePlaybackFromUser()
            return true
        case 36, 76:
            guard !isRepeat else {
                return true
            }
            return openPlaybackSubtitleFocusFromUser()
        case 123:
            viewModel.seekRelative(by: -5)
            return true
        case 124:
            viewModel.seekRelative(by: 5)
            return true
        case 126:
            viewModel.adjustVolume(by: 5)
            return true
        case 125:
            viewModel.adjustVolume(by: -5)
            return true
        case 43 where hasShift:
            viewModel.adjustSpeed(by: -0.25)
            return true
        case 47 where hasShift:
            viewModel.adjustSpeed(by: 0.25)
            return true
        default:
            return false
        }
    }

    private static func isPlaybackShortcutKey(keyCode: UInt16, hasShift: Bool) -> Bool {
        switch keyCode {
        case 0, 2, 3, 12, 36, 49, 76, 123, 124, 125, 126:
            return true
        case 35:
            return !hasShift
        case 43, 47:
            return hasShift
        default:
            return false
        }
    }

    func stopPlayback() {
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
            search.selectResult(nil)
            library.selectedLibraryVideo = nil
            shiori.selectedShiori = nil
            clearPlaybackChromeSnapshot()
            playback.isPlaybackSurfaceExpanded = false
            restorePlaybackReturnContext()
            playback.playbackStatus = .idle
        } catch {
            playback.playbackStatus = .failed(Self.errorMessage(for: error))
        }
    }

    static func isEditableTextInputFocused() -> Bool {
        guard let firstResponder = NSApplication.shared.keyWindow?.firstResponder else {
            return false
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
        guard let textView = NSApplication.shared.keyWindow?.firstResponder
            as? NSTextView
        else {
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
            forSubtitleFile: URL(fileURLWithPath: result.subtitlePath),
            format: result.subtitleFormat,
            videoPath: result.videoPath,
            startingAtMilliseconds: result.startMilliseconds,
            fallbackEndMilliseconds: result.endMilliseconds
        )
    }

    func playbackSubtitleSource(for shiori: Shiori) -> PlaybackSubtitleSource? {
        playbackSubtitleSource(
            forSubtitleFile: URL(fileURLWithPath: shiori.subtitlePath),
            format: shiori.subtitleFormat,
            videoPath: shiori.videoPath,
            startingAtMilliseconds: shiori.startMilliseconds,
            fallbackEndMilliseconds: shiori.endMilliseconds
        )
    }

    func playbackSubtitleSource(
        for video: LibraryVideo,
        startingAtMilliseconds startMilliseconds: Int
    ) -> PlaybackSubtitleSource? {
        playbackSubtitleSource(
            forSubtitleFile: URL(fileURLWithPath: video.subtitlePath),
            format: video.subtitleFormat,
            videoPath: video.videoPath,
            startingAtMilliseconds: startMilliseconds,
            fallbackEndMilliseconds: startMilliseconds
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
        case .srt:
            playbackFormat = .srt
        case .ass:
            playbackFormat = .ass
        }

        let videoURL = URL(fileURLWithPath: videoPath)

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
            forSubtitleFile: URL(fileURLWithPath: result.subtitlePath),
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
