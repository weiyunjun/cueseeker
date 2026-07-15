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
                self?.markCurrentLibraryPlaybackCompletedIfNeeded(
                    currentTime: currentTime,
                    duration: duration
                )
            },
            onSegmentFinished: { [weak self] endMilliseconds in
                self?.handlePlaybackSegmentFinished(endMilliseconds: endMilliseconds)
            },
            onPresentationCommitted: { [weak self] isPlaying in
                guard let self, self.hasPlaybackSelection else {
                    return
                }
                self.playback.playbackStatus = isPlaying ? .playing : .paused
            }
        )
    }

    func rememberPlaybackOriginatingPanelModeIfEntering(
        preferredMode: WorkbenchPanelMode? = nil
    ) {
        if let preferredMode {
            playbackOriginatingPanelMode = preferredMode
            return
        }
        guard !playback.isPlaybackSurfaceExpanded else {
            return
        }
        playbackOriginatingPanelMode = workbenchLayout.panelMode
    }

    func openSearchResult(
        _ result: SubtitleSearchResult,
        recordsNavigationHistory: Bool = true,
        displayTitle: String? = nil,
        returnPanelMode: WorkbenchPanelMode? = nil,
        playsContinuouslyFromStart: Bool = false,
        playbackSearchPromotion: PlaybackSearchPromotion? = nil
    ) {
        invalidatePlaybackSubtitleFocusForSourceReplacement()
        if let playbackSearchPromotion {
            if playback.playlistSource !== playbackSearchPromotion.source {
                searchNavigationTask?.cancel()
                searchNavigationTask = nil
            }
            playback.setPlaylistSource(
                playbackSearchPromotion.source,
                playbackSearchSelectedOrdinal: playbackSearchPromotion
                    .selectedOrdinal
            )
        } else {
            installSearchPlaybackPlaylistSource(seed: result)
        }
        playback.playbackStatus = .opening
        UIInvalidationProbe.mark(
            "ACTION UI.SearchResult.opened",
            details: "time=\(String(format: "%.2f", Double(result.startMilliseconds) / 1000.0))"
        )
        preparePlaybackKeyboardFocus()
        rememberPlaybackOriginatingPanelModeIfEntering(preferredMode: returnPanelMode)
        saveCurrentLibraryPlaybackHistory()
        stopLibraryPlaybackHistoryTracking()
        if recordsNavigationHistory {
            recordPlaybackNavigationEntry(playbackNavigationPayload(
                for: result,
                searchQuery: playbackSearchPromotion?.query,
                scopePaths: playbackSearchPromotion?.scopePaths
            ))
        }
        clearCueSegmentPlayback()
        activePlaybackSource = .search
        search.selectedSearchResult = result
        if playbackSearchPromotion == nil {
            updateSearchNavigationSnapshotForOpenedResult(result)
        } else {
            search.searchNavigationSnapshot = nil
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
            play(
                result,
                playsContinuouslyFromStart: playsContinuouslyFromStart
            )
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

        clearCueSegmentPlayback()
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

    func play(
        _ result: SubtitleSearchResult,
        playsContinuouslyFromStart: Bool = false
    ) {
        ensurePlayerInitialized()
        beginCueSegmentPlayback()
        saveCurrentLibraryPlaybackHistory()
        stopLibraryPlaybackHistoryTracking()
        activePlaybackSource = .search
        playback.playbackStatus = .opening
        playbackSubtitleCuesTask?.cancel()
        let subtitleCues = initialPlaybackSubtitleCues(for: result)
        playback.playbackViewModel?.preparePresentationTransition(
            to: Double(result.startMilliseconds) / 1_000,
            subtitleCues: subtitleCues
        )

        do {
            let segment = autoSwitchCuePlaybackSegment(
                startMilliseconds: result.startMilliseconds,
                endMilliseconds: result.endMilliseconds,
                playsContinuouslyFromStart: playsContinuouslyFromStart
            )
            activateCueSegmentPlayback(segment)
            let request = try PlaybackRequest(
                videoURL: URL(fileURLWithPath: result.videoPath),
                startMilliseconds: result.startMilliseconds,
                segmentEndMilliseconds: segment?.endMilliseconds,
                subtitleSource: playbackSubtitleSource(for: result)
            )

            guard let player else {
                throw PlaybackError.playbackPlayerUnavailable
            }

            let generation: UInt
            if player.currentVideoURL?.standardizedFileURL.path == request.videoURL.standardizedFileURL.path {
                if let segment {
                    generation = try player.seek(
                        to: segment,
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
            startPlaybackSubtitleCuesLoad(
                forSubtitleFile: URL(fileURLWithPath: result.subtitlePath),
                format: result.subtitleFormat,
                videoPath: result.videoPath
            )
        } catch {
            playback.playbackViewModel?.cancelPendingPresentation()
            clearCueSegmentPlayback()
            playbackSubtitleCuesTask?.cancel()
            playback.playbackViewModel?.clearSubtitleCues()
            playback.playbackStatus = .failed(Self.errorMessage(for: error))
        }
    }

    func autoSwitchCuePlaybackSegment(
        startMilliseconds: Int,
        endMilliseconds: Int,
        playsContinuouslyFromStart: Bool = false
    ) -> PlaybackSegment? {
        guard !playsContinuouslyFromStart,
              settings.autoPlayCueSequenceEnabled
        else {
            return nil
        }

        return PlaybackSegment(
            startMilliseconds: startMilliseconds,
            endMilliseconds: endMilliseconds
        )
    }

    @discardableResult
    func pausePlayback() -> Bool {
        guard let player else {
            playback.playbackStatus = .failed(Self.errorMessage(for: PlaybackError.playbackPlayerUnavailable))
            return false
        }

        do {
            cancelAutoPlayCueSequenceTask()
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

    func resumePlayback() {
        if replayFinishedCueSegmentIfNeeded() {
            return
        }

        do {
            try player?.setPaused(false)
            if hasPlaybackSelection {
                playback.playbackStatus = .playing
            }
        } catch {
            playback.playbackStatus = .failed(Self.errorMessage(for: error))
        }
    }

    func handlePlaybackSegmentFinished(endMilliseconds: Int) {
        guard isCurrentCueSegmentEnd(endMilliseconds) else {
            return
        }

        activeCueSegmentEndMilliseconds = nil
        currentCueSegmentFinished = true
        playback.playbackStatus = .paused

        guard settings.autoPlayCueSequenceEnabled else {
            return
        }

        holdCurrentCueSubtitlePresentation(matchingEndMilliseconds: endMilliseconds)
        scheduleAutoPlayCueSequence()
    }

    func beginCueSegmentPlayback() {
        cueSegmentPlaybackGeneration += 1
        activeCueSegmentEndMilliseconds = nil
        currentCueSegmentFinished = false
        cancelAutoPlayCueSequenceTask()
    }

    func clearCueSegmentPlayback() {
        cueSegmentPlaybackGeneration += 1
        activeCueSegmentEndMilliseconds = nil
        currentCueSegmentFinished = false
        cancelAutoPlayCueSequenceTask()
    }

    func cancelAutoPlayCueSequenceTask() {
        autoPlayCueSequenceTask?.cancel()
        autoPlayCueSequenceTask = nil
    }

    func activateCueSegmentPlayback(_ segment: PlaybackSegment?) {
        activeCueSegmentEndMilliseconds = segment?.endMilliseconds
    }

    private func isCurrentCueSegmentEnd(_ endMilliseconds: Int) -> Bool {
        activeCueSegmentEndMilliseconds == endMilliseconds
    }

    func cueSubtitlePresentationHoldMilliseconds(
        startMilliseconds: Int,
        endMilliseconds: Int
    ) -> Int {
        let segment = PlaybackSegment(
            startMilliseconds: startMilliseconds,
            endMilliseconds: endMilliseconds
        )
        guard segment.endMilliseconds > segment.startMilliseconds else {
            return segment.startMilliseconds
        }

        return max(segment.startMilliseconds, segment.endMilliseconds - 1)
    }

    func clearCueSubtitlePresentationHold() {
        playback.playbackViewModel?.clearSubtitlePresentationHold()
    }

    private func holdCurrentCueSubtitlePresentation(matchingEndMilliseconds endMilliseconds: Int) {
        let holdMilliseconds: Int? = switch activePlaybackSource {
        case .search:
            if let result = search.selectedSearchResult,
               result.endMilliseconds == endMilliseconds {
                cueSubtitlePresentationHoldMilliseconds(
                    startMilliseconds: result.startMilliseconds,
                    endMilliseconds: result.endMilliseconds
                )
            } else {
                nil
            }
        case .shiori:
            if let shiori = shiori.selectedShiori,
               shiori.endMilliseconds == endMilliseconds {
                cueSubtitlePresentationHoldMilliseconds(
                    startMilliseconds: shiori.startMilliseconds,
                    endMilliseconds: shiori.endMilliseconds
                )
            } else {
                nil
            }
        case .library, .none:
            nil
        }

        guard let holdMilliseconds else {
            return
        }

        playback.playbackViewModel?.holdSubtitlePresentation(atMilliseconds: holdMilliseconds)
    }

    @discardableResult
    private func replayFinishedCueSegmentIfNeeded() -> Bool {
        guard currentCueSegmentFinished else {
            return false
        }

        cancelAutoPlayCueSequenceTask()
        switch activePlaybackSource {
        case .search:
            guard let selectedSearchResult = search.selectedSearchResult else {
                return false
            }
            play(selectedSearchResult)
            return true
        case .shiori:
            guard let selectedShiori = shiori.selectedShiori else {
                return false
            }
            play(selectedShiori)
            return true
        case .library, .none:
            return false
        }
    }

    private func scheduleAutoPlayCueSequence() {
        let generation = cueSegmentPlaybackGeneration
        let source = activePlaybackSource
        let gapMilliseconds = settings.autoPlayCueSequenceGapMilliseconds

        cancelAutoPlayCueSequenceTask()
        autoPlayCueSequenceTask = Task { [weak self] in
            if gapMilliseconds > 0 {
                try? await Task.sleep(nanoseconds: UInt64(gapMilliseconds) * 1_000_000)
            }

            guard !Task.isCancelled else {
                return
            }

            await MainActor.run {
                guard let self,
                      self.cueSegmentPlaybackGeneration == generation,
                      self.currentCueSegmentFinished,
                      self.activePlaybackSource == source,
                      self.settings.autoPlayCueSequenceEnabled
                else {
                    return
                }

                self.autoPlayCueSequenceTask = nil
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

        guard currentPlaybackVideoPath != nil, let viewModel = playback.playbackViewModel else {
            return false
        }

        if let subtitleFocusSession = playback.subtitleFocusSession {
            let modifierFlags = NSEvent.ModifierFlags(rawValue: modifierFlagsRawValue)
            let disallowedModifiers: NSEvent.ModifierFlags = [.command, .control, .option]
            let moduleSwitchModifiers: NSEvent.ModifierFlags = [
                .command,
                .control,
                .option,
                .shift,
            ]

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

            if subtitleFocusSession.selectedModule == .recent {
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
                        _ = requestPlaybackRecentOpenAction()
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

        let modifierFlags = NSEvent.ModifierFlags(rawValue: modifierFlagsRawValue)
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
        case 43, 47:
            return hasShift
        default:
            return false
        }
    }

    func stopPlayback() {
        invalidatePlaybackSubtitleFocusForSourceReplacement()
        playbackSearchPlaylistNavigationTask?.cancel()
        playbackSearchPlaylistNavigationTask = nil
        playback.clearPlaylistSource()
        do {
            saveCurrentLibraryPlaybackHistoryForPlaybackClose()
            stopLibraryPlaybackHistoryTracking()
            playbackFullscreenManager.exitFullscreen()
            playback.playbackViewModel?.cancelPendingPresentation()
            try player?.stop()
            playbackSubtitleCuesTask?.cancel()
            playbackSubtitleCuesTask = nil
            playback.playbackViewModel?.clearSubtitleCues()
            activePlaybackSource = .none
            search.selectedSearchResult = nil
            library.selectedLibraryVideo = nil
            shiori.selectedShiori = nil
            clearPlaybackChromeSnapshot()
            playback.isPlaybackSurfaceExpanded = false
            if let originatingMode = playbackOriginatingPanelMode {
                workbenchLayout.selectPanelMode(originatingMode)
                playbackOriginatingPanelMode = nil
            }
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

    func initialPlaybackSubtitleCues(for result: SubtitleSearchResult) -> [PlaybackSubtitleCue] {
        initialPlaybackSubtitleCues(
            forSubtitleFile: URL(fileURLWithPath: result.subtitlePath),
            format: result.subtitleFormat,
            fallbackStartMilliseconds: result.startMilliseconds,
            fallbackEndMilliseconds: result.endMilliseconds,
            fallbackContent: result.content,
            fallbackCueGroupID: result.cueGroupID
        )
    }

    func initialPlaybackSubtitleCues(for shiori: Shiori) -> [PlaybackSubtitleCue] {
        initialPlaybackSubtitleCues(
            forSubtitleFile: URL(fileURLWithPath: shiori.subtitlePath),
            format: shiori.subtitleFormat,
            fallbackStartMilliseconds: shiori.startMilliseconds,
            fallbackEndMilliseconds: shiori.endMilliseconds,
            fallbackContent: shiori.content,
            fallbackCueGroupID: nil
        )
    }

    func initialPlaybackSubtitleCues(
        forSubtitleFile subtitleFile: URL,
        format: SubtitleFormat,
        fallbackStartMilliseconds: Int,
        fallbackEndMilliseconds: Int,
        fallbackContent: String,
        fallbackCueGroupID: Int64?
    ) -> [PlaybackSubtitleCue] {
        guard format == .srt else {
            return []
        }

        guard !fallbackContent.isEmpty else {
            return []
        }

        let speakersByCueGroupID = playbackSpeakersByCueGroupID(forSubtitleFile: subtitleFile)
        let speakers = fallbackCueGroupID.flatMap { speakersByCueGroupID[$0] } ?? []
        return [
            PlaybackSubtitleCue(
                startMilliseconds: fallbackStartMilliseconds,
                endMilliseconds: fallbackEndMilliseconds,
                text: playbackSubtitleText(fallbackContent, speakers: speakers)
            )
        ]
    }

    func startPlaybackSubtitleCuesLoad(
        forSubtitleFile subtitleFile: URL,
        format: SubtitleFormat,
        videoPath: String
    ) {
        playbackSubtitleCuesTask?.cancel()

        guard format == .srt,
              let database = subtitleDatabase
        else {
            return
        }

        let subtitlePath = subtitleFile.path
        let speakerDisplayEnabled = settings.playbackSpeakerDisplayEnabled
        playbackSubtitleCuesTask = Task { [weak self] in
            do {
                let cues = try await Task.detached(priority: .utility) {
                    let speakersByCueGroupID: [Int64: Set<String>]
                    if speakerDisplayEnabled {
                        speakersByCueGroupID = (try? database.speakersByCueGroupID(forSubtitleFile: subtitleFile)) ?? [:]
                    } else {
                        speakersByCueGroupID = [:]
                    }

                    return try database.entries(forSubtitleFile: subtitleFile).map {
                        let speakers = speakersByCueGroupID[$0.id] ?? []
                        return PlaybackSubtitleCue(
                            startMilliseconds: $0.startMilliseconds,
                            endMilliseconds: $0.endMilliseconds,
                            text: speakerDisplayEnabled
                                ? SubtitleSpeakerDisplayFormatter.prefixedText($0.content, speakers: speakers)
                                : $0.content
                        )
                    }
                }.value

                guard !Task.isCancelled,
                      !cues.isEmpty,
                      let self,
                      self.currentPlaybackVideoPath == videoPath,
                      self.currentPlaybackSubtitlePath == subtitlePath
                else {
                    return
                }

                self.playback.playbackViewModel?.setSubtitleCues(cues)
            } catch {
                guard !Task.isCancelled else {
                    return
                }
                print("Failed to load playback subtitle track: \(error)")
            }
        }
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
        guard format == .ass else {
            return nil
        }

        let videoURL = URL(fileURLWithPath: videoPath)

        let speakerDisplayCues = playbackSpeakerDisplayCues(forSubtitleFile: subtitleURL)
        SubtitleSpeakerDisplayDiagnostics.log(
            "app.assSubtitleSource.created",
            fields: [
                "subtitle": subtitleURL.lastPathComponent,
                "subtitlePath": subtitleURL.path,
                "video": videoURL.lastPathComponent,
                "speakerDisplayEnabled": "\(settings.playbackSpeakerDisplayEnabled)",
                "speakerCueCount": "\(speakerDisplayCues.count)",
                "startMilliseconds": "\(startMilliseconds)",
                "fallbackEndMilliseconds": "\(fallbackEndMilliseconds)"
            ]
        )

        return PlaybackSubtitleSource(
            url: subtitleURL,
            format: .ass,
            matchedVideoURL: videoURL,
            initialTimestampMilliseconds: startMilliseconds,
            preparationTimeWindow: playbackSubtitleTimeWindow(
                forSubtitleFile: subtitleURL,
                startingAtMilliseconds: startMilliseconds,
                fallbackEndMilliseconds: fallbackEndMilliseconds
            ),
            renderCacheDatabaseURL: databaseURL,
            speakerDisplayCues: speakerDisplayCues
        )
    }

    func refreshCurrentPlaybackSubtitleDisplay() {
        guard let currentPlaybackSubtitlePath,
              let currentPlaybackSubtitleFormat,
              let currentPlaybackVideoPath
        else {
            return
        }

        let subtitleFile = URL(fileURLWithPath: currentPlaybackSubtitlePath)
        let currentMilliseconds = max(
            0,
            Int(((playback.playbackViewModel?.currentTime ?? 0) * 1_000).rounded(.down))
        )

        switch currentPlaybackSubtitleFormat {
        case .srt:
            startPlaybackSubtitleCuesLoad(
                forSubtitleFile: subtitleFile,
                format: currentPlaybackSubtitleFormat,
                videoPath: currentPlaybackVideoPath
            )
        case .ass:
            player?.loadSubtitleSource(
                playbackSubtitleSource(
                    forSubtitleFile: subtitleFile,
                    format: currentPlaybackSubtitleFormat,
                    videoPath: currentPlaybackVideoPath,
                    startingAtMilliseconds: currentMilliseconds,
                    fallbackEndMilliseconds: currentMilliseconds
                )
            )
        }
    }

    func playbackSpeakersByCueGroupID(forSubtitleFile subtitleFile: URL) -> [Int64: Set<String>] {
        guard settings.playbackSpeakerDisplayEnabled,
              let subtitleDatabase
        else {
            return [:]
        }

        do {
            return try subtitleDatabase.speakersByCueGroupID(forSubtitleFile: subtitleFile)
        } catch {
            print("Failed to load playback speaker labels: \(error)")
            return [:]
        }
    }

    func playbackSpeakerDisplayCues(forSubtitleFile subtitleFile: URL) -> [SubtitleSpeakerDisplayCue] {
        guard settings.playbackSpeakerDisplayEnabled else {
            SubtitleSpeakerDisplayDiagnostics.log(
                "app.assSpeakerDisplayCues.disabled",
                fields: [
                    "subtitle": subtitleFile.lastPathComponent,
                    "subtitlePath": subtitleFile.path
                ]
            )
            return []
        }

        guard let subtitleDatabase else {
            SubtitleSpeakerDisplayDiagnostics.log(
                "app.assSpeakerDisplayCues.noDatabase",
                fields: [
                    "subtitle": subtitleFile.lastPathComponent,
                    "subtitlePath": subtitleFile.path
                ]
            )
            return []
        }

        do {
            let records = try subtitleDatabase.cueLineRecords(forSubtitleFile: subtitleFile)
            let speakersByCueLineID = try subtitleDatabase.speakersByCueLineID(forSubtitleFile: subtitleFile)
            let cues = SubtitleSpeakerDisplayCue.targetCues(
                records: records,
                speakersByCueLineID: speakersByCueLineID
            )
            SubtitleSpeakerDisplayDiagnostics.log(
                "app.assSpeakerDisplayCues.loaded",
                fields: [
                    "subtitle": subtitleFile.lastPathComponent,
                    "subtitlePath": subtitleFile.path,
                    "recordCount": "\(records.count)",
                    "speakerLineCount": "\(speakersByCueLineID.count)",
                    "speakerCueCount": "\(cues.count)",
                    "firstCue": cues.first.map { "\($0.startMilliseconds)-\($0.endMilliseconds):\($0.sourceStyle ?? ""):\($0.cleanText)" } ?? ""
                ]
            )
            return cues
        } catch {
            SubtitleSpeakerDisplayDiagnostics.log(
                "app.assSpeakerDisplayCues.failed",
                fields: [
                    "subtitle": subtitleFile.lastPathComponent,
                    "subtitlePath": subtitleFile.path,
                    "error": Self.errorMessage(for: error)
                ]
            )
            print("Failed to load ASS playback speaker labels: \(error)")
            return []
        }
    }

    func playbackSubtitleText(_ text: String, speakers: Set<String>) -> String {
        guard settings.playbackSpeakerDisplayEnabled else {
            return text
        }

        return SubtitleSpeakerDisplayFormatter.prefixedText(text, speakers: speakers)
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

        guard let database = subtitleDatabase else {
            return fallback
        }

        do {
            let timings = try database.cueTimings(
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
