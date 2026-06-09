import AppKit
import Foundation
import CueSeekerCore
import CueSeekerPlayback

private enum PlaybackQuickSearchAIChunkingRequestReason: String {
    case cacheMiss = "cache_miss"
    case manualRefresh = "manual_refresh"
}

struct PlaybackSubtitleWindowLoad: Sendable {
    let subtitlePath: String
    let index: [SubtitleDatabaseEntryIndexItem]
    let windowStartIndex: Int
    let entries: [SubtitleDatabaseEntry]
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

    func togglePlaybackSidePanelFromUser() {
        guard hasPlaybackSelection else {
            return
        }

        // The overlay panel floats over the video and never resizes it, so
        // this toggle is NOT a video-size-changing command: it must not pass
        // through the serialized resize gate (it must never be swallowed by
        // the rapid-repeat guard or serialized with fullscreen/zoom) and must
        // not animate as a video-size transition or mutate
        // playback.isPlaybackSurfaceExpanded (architecture §7.1, doc 12 §11). The
        // panel's own ~180 ms show/hide animation is owned by PlaybackPageView.
        playback.isPlaybackSidePanelVisible.toggle()
        playback.playbackViewModel?.showSidebarFeedback(isVisible: playback.isPlaybackSidePanelVisible)
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
            onSegmentFinished: { [weak self] endMilliseconds in
                self?.handlePlaybackSegmentFinished(endMilliseconds: endMilliseconds)
            }
        )
    }

    func rememberPlaybackOriginatingPanelModeIfEntering() {
        guard !playback.isPlaybackSurfaceExpanded else {
            return
        }
        playbackOriginatingPanelMode = workbenchLayout.panelMode
    }

    func openSearchResult(_ result: SubtitleSearchResult, recordsNavigationHistory: Bool = true) {
        UIInvalidationProbe.mark(
            "ACTION UI.SearchResult.opened",
            details: "time=\(String(format: "%.2f", Double(result.startMilliseconds) / 1000.0))"
        )
        preparePlaybackKeyboardFocus()
        rememberPlaybackOriginatingPanelModeIfEntering()
        saveCurrentLibraryPlaybackHistory()
        stopLibraryPlaybackHistoryTracking()
        if recordsNavigationHistory {
            recordPlaybackNavigationEntry(playbackNavigationPayload(for: result))
        }
        cancelAutoPlayCueSequenceTask()
        currentCueSegmentFinished = false
        activePlaybackSource = .search
        workbenchLayout.selectPanelMode(.search)
        search.selectedSearchResult = result
        shiori.selectedShiori = nil
        library.selectedLibraryVideo = nil
        playback.isPlaybackSurfaceExpanded = true
        Task { @MainActor in
            await Task.yield()
            play(result)
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

    func play(_ result: SubtitleSearchResult) {
        ensurePlayerInitialized()
        beginCueSegmentPlayback()
        saveCurrentLibraryPlaybackHistory()
        stopLibraryPlaybackHistoryTracking()
        activePlaybackSource = .search
        playback.playbackStatus = .opening
        playbackSubtitleCuesTask?.cancel()
        let subtitleCues = initialPlaybackSubtitleCues(for: result)
        playback.playbackViewModel?.setSubtitleCues(
            subtitleCues,
            currentTimeMilliseconds: result.startMilliseconds
        )

        do {
            let segment = autoSwitchCuePlaybackSegment(
                startMilliseconds: result.startMilliseconds,
                endMilliseconds: result.endMilliseconds
            )
            let request = try PlaybackRequest(
                videoURL: URL(fileURLWithPath: result.videoPath),
                startMilliseconds: result.startMilliseconds,
                segmentEndMilliseconds: segment?.endMilliseconds,
                subtitleSource: playbackSubtitleSource(for: result)
            )

            guard let player else {
                throw PlaybackError.playbackPlayerUnavailable
            }

            if player.currentVideoURL?.standardizedFileURL.path == request.videoURL.standardizedFileURL.path {
                player.loadSubtitleSource(request.subtitleSource)
                if let segment {
                    try player.seek(to: segment)
                } else {
                    try player.seek(toMilliseconds: result.startMilliseconds)
                }
            } else {
                try player.open(request)
            }

            try player.setPaused(false)
            playback.playbackStatus = .playing
            startPlaybackSubtitleCuesLoad(
                forSubtitleFile: URL(fileURLWithPath: result.subtitlePath),
                format: result.subtitleFormat,
                videoPath: result.videoPath
            )
            refreshSearchNavigationSnapshot()
        } catch {
            playbackSubtitleCuesTask?.cancel()
            playback.playbackViewModel?.clearSubtitleCues()
            playback.playbackStatus = .failed(Self.errorMessage(for: error))
        }
    }

    func autoSwitchCuePlaybackSegment(
        startMilliseconds: Int,
        endMilliseconds: Int
    ) -> PlaybackSegment? {
        guard settings.autoPlayCueSequenceEnabled else {
            return nil
        }

        return PlaybackSegment(
            startMilliseconds: startMilliseconds,
            endMilliseconds: endMilliseconds
        )
    }

    func pausePlayback() {
        do {
            cancelAutoPlayCueSequenceTask()
            try player?.setPaused(true)
            if hasPlaybackSelection {
                playback.playbackStatus = .paused
            }
            saveCurrentLibraryPlaybackHistory()
        } catch {
            playback.playbackStatus = .failed(Self.errorMessage(for: error))
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

        currentCueSegmentFinished = true
        playback.playbackStatus = .paused

        guard settings.autoPlayCueSequenceEnabled else {
            return
        }

        scheduleAutoPlayCueSequence()
    }

    func beginCueSegmentPlayback() {
        cueSegmentPlaybackGeneration += 1
        currentCueSegmentFinished = false
        cancelAutoPlayCueSequenceTask()
    }

    func clearCueSegmentPlayback() {
        cueSegmentPlaybackGeneration += 1
        currentCueSegmentFinished = false
        cancelAutoPlayCueSequenceTask()
    }

    func cancelAutoPlayCueSequenceTask() {
        autoPlayCueSequenceTask?.cancel()
        autoPlayCueSequenceTask = nil
    }

    private func isCurrentCueSegmentEnd(_ endMilliseconds: Int) -> Bool {
        switch activePlaybackSource {
        case .search:
            return search.selectedSearchResult?.endMilliseconds == endMilliseconds
        case .shiori:
            return shiori.selectedShiori?.endMilliseconds == endMilliseconds
        case .library, .none:
            return false
        }
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

    func refreshCurrentSubtitleEntries() {
        guard let currentPlaybackSubtitlePath,
              let database = subtitleDatabase
        else {
            currentSubtitleEntriesTask?.cancel()
            currentSubtitleEntriesTask = nil
            currentSubtitleEntriesTaskSubtitlePath = nil
            currentSubtitleEntriesTaskRequestID += 1
            applyCurrentSubtitleEntries([], subtitlePath: nil)
            return
        }

        let subtitleFile = URL(fileURLWithPath: currentPlaybackSubtitlePath)
        let subtitlePath = subtitleFile.path
        if playback.currentSubtitleEntrySubtitlePath == subtitlePath,
           !playback.currentSubtitleEntryIndex.isEmpty {
            return
        }
        if currentSubtitleEntriesTaskSubtitlePath == subtitlePath {
            return
        }

        currentSubtitleEntriesTask?.cancel()
        currentSubtitleEntriesTaskRequestID += 1
        let requestID = currentSubtitleEntriesTaskRequestID
        currentSubtitleEntriesTaskSubtitlePath = subtitlePath
        if playback.currentSubtitleEntrySubtitlePath != subtitlePath {
            applyCurrentSubtitleEntries([], subtitlePath: subtitlePath)
        }

        currentSubtitleEntriesTask = Task { [weak self] in
            do {
                let currentMilliseconds = await MainActor.run {
                    max(
                        0,
                        Int(((self?.playback.playbackViewModel?.displayedCurrentTime ?? 0) * 1_000).rounded(.down))
                    )
                }
                let window = try await Task.detached(priority: .userInitiated) {
                    let index = try database.subtitleEntryIndex(forSubtitleFile: subtitleFile)
                    let lookup = SubtitleActiveEntryLookup(entryIndex: index)
                    let activeID = lookup.activeEntryID(atMilliseconds: currentMilliseconds)
                    let activeIndex = activeID.flatMap { id in
                        index.firstIndex { $0.id == id }
                    } ?? 0
                    let windowStart = Self.playbackSubtitleWindowStart(
                        around: activeIndex,
                        totalCount: index.count
                    )
                    let entries = try database.entries(
                        forSubtitleFile: subtitleFile,
                        limit: Self.playbackSubtitleWindowLimit,
                        offset: windowStart
                    )
                    return PlaybackSubtitleWindowLoad(
                        subtitlePath: subtitleFile.path,
                        index: index,
                        windowStartIndex: windowStart,
                        entries: entries
                    )
                }.value

                guard !Task.isCancelled else {
                    return
                }

                guard self?.currentSubtitleEntriesTaskRequestID == requestID,
                      self?.currentPlaybackSubtitlePath == window.subtitlePath
                else {
                    return
                }

                self?.applyCurrentSubtitleWindow(window)
                self?.finishCurrentSubtitleEntriesTask(requestID: requestID)
            } catch {
                guard !Task.isCancelled else {
                    return
                }

                print("Failed to load current subtitle entries: \(error)")
                guard self?.currentSubtitleEntriesTaskRequestID == requestID,
                      self?.currentPlaybackSubtitlePath == subtitlePath
                else {
                    return
                }
                self?.applyCurrentSubtitleEntries([], subtitlePath: subtitlePath)
                self?.finishCurrentSubtitleEntriesTask(requestID: requestID)
            }
        }
    }

    func loadCurrentSubtitleEntriesAroundActiveCue(_ entryID: Int64?) {
        guard let entryID,
              let currentPlaybackSubtitlePath,
              let database = subtitleDatabase,
              !playback.currentSubtitleEntryIndex.isEmpty
        else {
            return
        }

        let currentRange = playback.currentSubtitleEntryWindowRange
        if playback.currentSubtitleEntries.contains(where: { $0.id == entryID }) {
            return
        }

        guard let activeIndex = playback.currentSubtitleEntryIndex.firstIndex(where: { $0.id == entryID }),
              !currentRange.contains(activeIndex)
        else {
            return
        }

        currentSubtitleEntriesTask?.cancel()
        currentSubtitleEntriesTaskRequestID += 1
        let requestID = currentSubtitleEntriesTaskRequestID
        let subtitleFile = URL(fileURLWithPath: currentPlaybackSubtitlePath)
        currentSubtitleEntriesTaskSubtitlePath = subtitleFile.path
        let index = playback.currentSubtitleEntryIndex
        let windowStart = Self.playbackSubtitleWindowStart(
            around: activeIndex,
            totalCount: index.count
        )
        currentSubtitleEntriesTask = Task { [weak self] in
            do {
                let entries = try await Task.detached(priority: .userInitiated) {
                    try database.entries(
                        forSubtitleFile: subtitleFile,
                        limit: Self.playbackSubtitleWindowLimit,
                        offset: windowStart
                    )
                }.value

                guard !Task.isCancelled else {
                    return
                }

                guard self?.currentSubtitleEntriesTaskRequestID == requestID,
                      self?.currentPlaybackSubtitlePath == subtitleFile.path
                else {
                    return
                }

                self?.applyCurrentSubtitleWindow(
                    PlaybackSubtitleWindowLoad(
                        subtitlePath: subtitleFile.path,
                        index: index,
                        windowStartIndex: windowStart,
                        entries: entries
                    )
                )
                self?.finishCurrentSubtitleEntriesTask(requestID: requestID)
            } catch {
                guard !Task.isCancelled else {
                    return
                }

                print("Failed to load current subtitle entries: \(error)")
                self?.finishCurrentSubtitleEntriesTask(requestID: requestID)
            }
        }
    }

    func loadCurrentSubtitleEntriesWindow(rows requestedRows: Range<Int>) {
        guard let currentPlaybackSubtitlePath,
              let database = subtitleDatabase,
              !playback.currentSubtitleEntryIndex.isEmpty
        else {
            return
        }

        let totalCount = playback.currentSubtitleEntryIndex.count
        let lowerBound = min(max(0, requestedRows.lowerBound), totalCount)
        let upperBound = min(max(lowerBound, requestedRows.upperBound), totalCount)
        guard lowerBound < upperBound else {
            return
        }

        let requestedRange = lowerBound..<upperBound
        let currentRange = playback.currentSubtitleEntryWindowRange
        if currentRange.lowerBound <= requestedRange.lowerBound
            && requestedRange.upperBound <= currentRange.upperBound {
            return
        }

        currentSubtitleEntriesTask?.cancel()
        currentSubtitleEntriesTaskRequestID += 1
        let requestID = currentSubtitleEntriesTaskRequestID
        let subtitleFile = URL(fileURLWithPath: currentPlaybackSubtitlePath)
        currentSubtitleEntriesTaskSubtitlePath = subtitleFile.path
        let index = playback.currentSubtitleEntryIndex
        currentSubtitleEntriesTask = Task { [weak self] in
            do {
                let entries = try await Task.detached(priority: .userInitiated) {
                    try database.entries(
                        forSubtitleFile: subtitleFile,
                        limit: requestedRange.count,
                        offset: requestedRange.lowerBound
                    )
                }.value

                guard !Task.isCancelled else {
                    return
                }

                guard self?.currentSubtitleEntriesTaskRequestID == requestID,
                      self?.currentPlaybackSubtitlePath == subtitleFile.path
                else {
                    return
                }

                self?.applyCurrentSubtitleWindow(
                    PlaybackSubtitleWindowLoad(
                        subtitlePath: subtitleFile.path,
                        index: index,
                        windowStartIndex: requestedRange.lowerBound,
                        entries: entries
                    )
                )
                self?.finishCurrentSubtitleEntriesTask(requestID: requestID)
            } catch {
                guard !Task.isCancelled else {
                    return
                }

                print("Failed to load current subtitle entries window: \(error)")
                self?.finishCurrentSubtitleEntriesTask(requestID: requestID)
            }
        }
    }

    @discardableResult
    func copyCurrentSubtitleToClipboard() -> Bool {
        guard let playbackViewModel = playback.playbackViewModel else {
            playback.playbackViewModel?.showSubtitleCopyFeedback(copied: false)
            return false
        }

        do {
            guard let selection = try currentPlaybackCueTextSelection(), !selection.text.isEmpty else {
                playbackViewModel.showSubtitleCopyFeedback(copied: false)
                return false
            }

            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            let copied = pasteboard.setString(selection.text, forType: .string)
            playbackViewModel.showSubtitleCopyFeedback(copied: copied)
            return copied
        } catch {
            print("Failed to copy current subtitle: \(error)")
            playbackViewModel.showSubtitleCopyFeedback(copied: false)
            return false
        }
    }

    @discardableResult
    func copyQuickSearchCurrentSentenceToClipboard() -> Bool {
        guard let playbackViewModel = playback.playbackViewModel else {
            playback.playbackViewModel?.showSubtitleCopyFeedback(copied: false)
            return false
        }

        guard let sentence = playback.selectedQuickSearchCurrentSentenceForCopy() else {
            playbackViewModel.showSubtitleCopyFeedback(copied: false)
            return false
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let copied = pasteboard.setString(sentence, forType: .string)
        playbackViewModel.showSubtitleCopyFeedback(copied: copied)
        return copied
    }

    @discardableResult
    func openPlaybackQuickSearchFromUser() -> Bool {
        guard currentPlaybackVideoPath != nil,
              let playbackViewModel = playback.playbackViewModel
        else {
            return false
        }

        guard !playback.isQuickSearchOverlayVisible else {
            playback.requestQuickSearchFocus()
            return true
        }

        playback.quickSearchPlaybackWasPlayingOnOpen = playbackViewModel.isPlaying
        cancelPlaybackQuickSearchAIChunking()
        cancelPlaybackQuickSearchChunkCount()
        capturePlaybackQuickSearchSearchContext()
        playback.resetQuickSearchResultSelection()
        playback.resetQuickSearchAIState()
        configurePlaybackQuickSearchSubtitleLineSelection()
        configurePlaybackQuickSearchAIEntry()
        configurePlaybackQuickSearchNavigationAvailability()
        playback.focusFirstVisibleQuickSearchOptionRow()
        playback.isQuickSearchOverlayVisible = true
        if playback.quickSearchFocusTarget == .input {
            playback.requestQuickSearchFocus()
        } else {
            playback.clearQuickSearchInputFocus()
        }
        startPlaybackQuickSearchSelectedChunkCountIfNeeded()
        pausePlayback()
        return true
    }

    @discardableResult
    func submitPlaybackQuickSearchFromUser() -> Bool {
        guard playback.isQuickSearchOverlayVisible else {
            return false
        }

        if playback.quickSearchSubmittedQuery == nil,
           playback.quickSearchFocusTarget == .navigation,
           case .visible(let commands, let selectedIndex) = playback.quickSearchNavigationState,
           commands.indices.contains(selectedIndex) {
            return executePlaybackQuickSearchNavigationCommand(commands[selectedIndex])
        }

        if playback.quickSearchSubmittedQuery == nil,
           playback.isQuickSearchAICopyOptionActive {
            return copyQuickSearchCurrentSentenceToClipboard()
        }

        if playback.quickSearchSubmittedQuery == nil,
           playback.isQuickSearchAIRefreshOptionActive,
           case .options(let chunks, _, .refresh) = playback.quickSearchAIState {
            return startPlaybackQuickSearchAIChunking(reason: chunks.isEmpty ? .cacheMiss : .manualRefresh)
        }

        var resultSource = PlaybackQuickSearchResultSource.direct
        if playback.quickSearchSubmittedQuery == nil,
           let selectedChunk = playback.selectedQuickSearchAIChunk() {
            playback.applyQuickSearchAIChunkQuery(selectedChunk)
            resultSource = .chunk
        }

        let trimmedQuery = playback.quickSearchDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            return true
        }

        if playback.quickSearchSubmittedQuery == trimmedQuery,
           let selectedResult = playback.selectedQuickSearchResult(in: search.searchResults) {
            openPlaybackQuickSearchResult(selectedResult)
            return true
        }

        UIInvalidationProbe.mark(
            "ACTION UI.PlaybackQuickSearch.submitted",
            details: "length=\(trimmedQuery.count)"
        )
        quickSearchSearchContextWasMutated = true
        workbenchLayout.selectPanelMode(.search)
        search.searchQuery = trimmedQuery
        search.searchNavigationSnapshot = nil
        search.searchNavigationResultGroups = []
        search.resetSearchNavigationVisibleWindow()
        playback.markQuickSearchSubmitted(query: trimmedQuery, source: resultSource)
        startSearch(query: trimmedQuery, cursor: .start, appending: false, debounce: false)
        return true
    }

    @discardableResult
    func movePlaybackQuickSearchFocus(by offset: Int) -> Bool {
        if playback.quickSearchSubmittedQuery != nil {
            return movePlaybackQuickSearchResultSelection(by: offset)
        }

        let didMove = playback.moveQuickSearchAIOptionFocus(by: offset)
        if didMove {
            startPlaybackQuickSearchSelectedChunkCountIfNeeded()
        }
        return didMove
    }

    @discardableResult
    func movePlaybackQuickSearchResultSelection(by offset: Int) -> Bool {
        let didMove = playback.moveQuickSearchResultSelection(
            by: offset,
            resultCount: search.searchResults.count
        )
        if didMove,
           let selectedResult = playback.selectedQuickSearchResult(in: search.searchResults) {
            loadMoreSearchResultsIfNeeded(currentResult: selectedResult)
        }
        return didMove
    }

    @discardableResult
    func movePlaybackQuickSearchOptionRowSelection(by offset: Int) -> Bool {
        let didMove = playback.moveQuickSearchOptionRowSelection(by: offset)
        if didMove {
            startPlaybackQuickSearchSelectedChunkCountIfNeeded()
        }
        return didMove
    }

    @discardableResult
    private func startPlaybackQuickSearchAIChunking(
        reason: PlaybackQuickSearchAIChunkingRequestReason
    ) -> Bool {
        guard playback.isQuickSearchOverlayVisible,
              playback.canStartQuickSearchAIChunkingRequest
        else {
            return false
        }

        let sentence = playback.quickSearchCurrentSentence.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sentence.isEmpty else {
            let requestID = playback.markQuickSearchAIChunkingStarted()
            playback.markQuickSearchAIChunkingFailed("The sentence is empty.", requestID: requestID)
            return true
        }

        guard settings.aiChunkingEnabled else {
            return false
        }

        let apiKey: String
        do {
            guard let storedAPIKey = try settings.deepSeekAPIKey(),
                  !storedAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else {
                settings.refreshDeepSeekAPIKeyStatus()
                return false
            }
            apiKey = storedAPIKey
        } catch {
            let requestID = playback.markQuickSearchAIChunkingStarted()
            playback.markQuickSearchAIChunkingFailed(Self.errorMessage(for: error), requestID: requestID)
            return true
        }

        cancelPlaybackQuickSearchAIChunking()
        let requestID = playback.markQuickSearchAIChunkingStarted()
        var client = DeepSeekChunkingClient()
        client.promptConfiguration = settings.aiChunkingPromptConfiguration
        let configuredClient = client
        let model = client.model
        let provider = AIProvider.deepSeek.rawValue
        let promptVersion = client.promptConfiguration.cachePromptVersion(
            baseVersion: DeepSeekChunkingClient.promptVersion
        )
        let requestContent: String
        do {
            requestContent = try client.renderedPrompt(for: sentence).content
        } catch {
            playback.markQuickSearchAIChunkingFailed(Self.errorMessage(for: error), requestID: requestID)
            return true
        }
        if reason == .manualRefresh {
            logPlaybackQuickSearchAIChunkManualRefreshBypass(
                provider: provider,
                model: model,
                promptVersion: promptVersion,
                sentence: sentence
            )
        }
        quickSearchAIChunkingTask = Task { [weak self] in
            do {
                let result = try await configuredClient.chunks(for: sentence, apiKey: apiKey)
                await MainActor.run {
                    guard let self else {
                        return
                    }

                    let cacheWritten = self.writePlaybackQuickSearchAIChunkCache(
                        normalizedSentence: result.normalizedSentence,
                        provider: provider,
                        model: model,
                        promptVersion: promptVersion,
                        chunks: result.items
                    )
                    self.logPlaybackQuickSearchAIChunkRequestFinished(
                        reason: reason,
                        provider: provider,
                        model: model,
                        promptVersion: promptVersion,
                        normalizedSentence: result.normalizedSentence,
                        usage: result.usage,
                        itemCount: result.items.count,
                        cacheWritten: cacheWritten,
                        durationMilliseconds: result.durationMilliseconds,
                        requestContent: result.requestContent,
                        responseContent: result.responseContent
                    )
                    self.playback.markQuickSearchAIChunkingSucceeded(
                        result.items,
                        requestID: requestID
                    )
                    self.startPlaybackQuickSearchSelectedChunkCountIfNeeded()
                }
            } catch is CancellationError {
                return
            } catch {
                await MainActor.run {
                    guard let self else {
                        return
                    }

                    self.logPlaybackQuickSearchAIChunkRequestFailed(
                        reason: reason,
                        provider: provider,
                        model: model,
                        promptVersion: promptVersion,
                        sentence: sentence,
                        error: error,
                        requestContent: requestContent
                    )
                    self.playback.markQuickSearchAIChunkingFailed(
                        Self.errorMessage(for: error),
                        requestID: requestID
                    )
                }
            }
        }
        return true
    }

    func openPlaybackQuickSearchResult(_ result: SubtitleSearchResult) {
        cancelPlaybackQuickSearchAIChunking()
        cancelPlaybackQuickSearchChunkCount()
        discardPlaybackQuickSearchSearchContext()
        playback.quickSearchPlaybackWasPlayingOnOpen = false
        playback.isQuickSearchFocused = false
        playback.isQuickSearchOverlayVisible = false
        playback.resetQuickSearchSubtitleLineNavigation()
        playback.resetQuickSearchResultSelection()
        playback.resetQuickSearchAIState()
        openSearchResult(result)
    }

    @discardableResult
    func handlePlaybackQuickSearchEscapeFromUser() -> Bool {
        guard playback.isQuickSearchOverlayVisible else {
            return false
        }

        if playback.quickSearchSubmittedQuery != nil {
            if playback.quickSearchResultSource == .chunk,
               playback.quickSearchFocusTarget == .result,
               playback.restoreQuickSearchAIOptionsAfterChunkSearch() {
                startPlaybackQuickSearchSelectedChunkCountIfNeeded()
                return true
            }

            if playback.quickSearchResultSource == .direct,
               playback.quickSearchFocusTarget == .result {
                playback.focusQuickSearchInput()
                return true
            }
        }

        return dismissPlaybackQuickSearchFromUser()
    }

    @discardableResult
    func dismissPlaybackQuickSearchFromUser() -> Bool {
        guard playback.isQuickSearchOverlayVisible else {
            return false
        }

        let shouldResume = playback.quickSearchPlaybackWasPlayingOnOpen
        cancelPlaybackQuickSearchAIChunking()
        cancelPlaybackQuickSearchChunkCount()
        restorePlaybackQuickSearchSearchContextIfNeeded()
        playback.quickSearchPlaybackWasPlayingOnOpen = false
        playback.isQuickSearchFocused = false
        playback.isQuickSearchOverlayVisible = false
        playback.resetQuickSearchSubtitleLineNavigation()
        playback.resetQuickSearchResultSelection()
        playback.resetQuickSearchAIState()

        if shouldResume {
            resumePlayback()
        }

        return true
    }

    @discardableResult
    func handlePlaybackKeyDown(
        keyCode: UInt16,
        modifierFlagsRawValue: UInt
    ) -> Bool {
        let isPlaybackInterfaceVisible = currentPlaybackVideoPath != nil || playbackFullscreenManager.isFullscreen

        guard isPlaybackInterfaceVisible else {
            return false
        }

        guard currentPlaybackVideoPath != nil, let viewModel = playback.playbackViewModel else {
            return false
        }

        if playback.isQuickSearchOverlayVisible {
            if keyCode == 53 {
                return handlePlaybackQuickSearchEscapeFromUser()
            }

            if playback.isQuickSearchFocused {
                return false
            }

            switch keyCode {
            case 36, 76:
                return submitPlaybackQuickSearchFromUser()
            case 126:
                return movePlaybackQuickSearchFocus(by: -1)
            case 125:
                return movePlaybackQuickSearchFocus(by: 1)
            case 123:
                return movePlaybackQuickSearchOptionRowSelection(by: -1)
            case 124:
                return movePlaybackQuickSearchOptionRowSelection(by: 1)
            default:
                return false
            }
        }

        guard !Self.isEditableTextInputFocused() else {
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
            copyCurrentSubtitleToClipboard()
            return true
        case 1:
            _ = toggleCurrentShiori()
            return true
        case 8:
            viewModel.toggleSubtitles()
            return true
        case 3:
            togglePlaybackFullscreenFromUser()
            return true
        case 49:
            togglePlaybackFromUser()
            return true
        case 36, 76:
            return openPlaybackQuickSearchFromUser()
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
        case 0, 1, 2, 3, 8, 12, 36, 49, 76, 123, 124, 125, 126:
            return true
        case 43, 47:
            return hasShift
        default:
            return false
        }
    }

    private func currentPlaybackCueTextSelection() throws -> SubtitleCueTextSelection? {
        guard let currentPlaybackSubtitlePath,
              let playbackViewModel = playback.playbackViewModel,
              let database = subtitleDatabase
        else {
            return nil
        }

        let milliseconds = max(0, Int((playbackViewModel.currentTime * 1_000).rounded(.down)))
        return try database.cueTextSelection(
            forSubtitleFile: URL(fileURLWithPath: currentPlaybackSubtitlePath),
            atMilliseconds: milliseconds
        )
    }

    private func configurePlaybackQuickSearchSubtitleLineSelection() {
        let candidates = currentPlaybackQuickSearchLineCandidates()
        let selectedIndex = currentPlaybackQuickSearchInitialLineIndex(in: candidates)
        playback.setQuickSearchSubtitleLineCandidates(candidates, selectedIndex: selectedIndex)
    }

    private func configurePlaybackQuickSearchAIEntry() {
        settings.refreshDeepSeekAPIKeyStatus()

        let cachedChunks = playbackQuickSearchAIChunkCacheEntryForCurrentDraft()?.chunks
        playback.showQuickSearchAIEntryIfPossible(
            isEnabled: settings.aiChunkingEnabled,
            hasAPIKey: settings.deepSeekAPIKeyConfigured,
            cachedChunks: cachedChunks
        )
    }

    private func configurePlaybackQuickSearchNavigationAvailability() {
        let availability = playbackNavigationAvailability()
        playback.configureQuickSearchNavigation(
            canMoveBack: availability.canMoveBack,
            canMoveForward: availability.canMoveForward
        )
    }

    private func playbackQuickSearchAIChunkCacheEntryForCurrentDraft() -> AIChunkCacheEntry? {
        guard settings.aiChunkingEnabled,
              settings.deepSeekAPIKeyConfigured,
              let database = subtitleDatabase,
              let key = playbackQuickSearchAIChunkCacheKeyForCurrentSentence()
        else {
            return nil
        }

        do {
            let entry = try database.aiChunkCacheEntry(for: key)
            if let entry, !entry.chunks.isEmpty {
                logPlaybackQuickSearchAIChunkCacheHit(entry: entry)
                return entry
            }

            logPlaybackQuickSearchAIChunkCacheMiss(key: key)
            return nil
        } catch {
            print(
                "[AIChunking] cache lookup failed provider=\(key.provider) model=\(key.model) " +
                    "prompt_version=\(key.promptVersion) text_hash=\(Self.shortLogHash(for: key.normalizedSentence)) " +
                    "error=\(Self.errorMessage(for: error))"
            )
            return nil
        }
    }

    private func playbackQuickSearchAIChunkCacheKeyForCurrentSentence() -> AIChunkCacheKey? {
        let normalizedSentence = AIChunkTextNormalizer.normalizedSentence(playback.quickSearchCurrentSentence)
        guard !normalizedSentence.isEmpty else {
            return nil
        }

        return AIChunkCacheKey(
            normalizedSentence: normalizedSentence,
            provider: AIProvider.deepSeek.rawValue,
            model: DeepSeekChunkingClient.defaultModel,
            promptVersion: settings.aiChunkingPromptConfiguration.cachePromptVersion(
                baseVersion: DeepSeekChunkingClient.promptVersion
            )
        )
    }

    private func logPlaybackQuickSearchAIChunkCacheHit(entry: AIChunkCacheEntry) {
        let key = entry.key
        print(
            "[AIChunking] cache hit, skip request provider=\(key.provider) model=\(key.model) " +
                "prompt_version=\(key.promptVersion) text_hash=\(Self.shortLogHash(for: key.normalizedSentence)) " +
                "items=\(entry.chunks.count)"
        )
    }

    private func logPlaybackQuickSearchAIChunkCacheMiss(key: AIChunkCacheKey) {
        print(
            "[AIChunking] cache miss, request requires current sentence chunk option provider=\(key.provider) model=\(key.model) " +
                "prompt_version=\(key.promptVersion) text_hash=\(Self.shortLogHash(for: key.normalizedSentence))"
        )
    }

    private func writePlaybackQuickSearchAIChunkCache(
        normalizedSentence: String,
        provider: String,
        model: String,
        promptVersion: String,
        chunks: [AIChunkItem]
    ) -> Bool {
        guard let database = subtitleDatabase else {
            return false
        }

        let key = AIChunkCacheKey(
            normalizedSentence: normalizedSentence,
            provider: provider,
            model: model,
            promptVersion: promptVersion
        )

        do {
            try database.upsertAIChunkCacheEntry(key: key, chunks: chunks)
            return true
        } catch {
            print(
                "[AIChunking] cache write failed provider=\(provider) model=\(model) " +
                    "prompt_version=\(promptVersion) text_hash=\(Self.shortLogHash(for: normalizedSentence)) " +
                    "error=\(Self.errorMessage(for: error))"
            )
            return false
        }
    }

    private func logPlaybackQuickSearchAIChunkManualRefreshBypass(
        provider: String,
        model: String,
        promptVersion: String,
        sentence: String
    ) {
        let normalizedSentence = AIChunkTextNormalizer.normalizedSentence(sentence)
        print(
            "[AIChunking] manual refresh, bypass cache provider=\(provider) model=\(model) " +
                "prompt_version=\(promptVersion) text_hash=\(Self.shortLogHash(for: normalizedSentence))"
        )
    }

    private func logPlaybackQuickSearchAIChunkRequestFinished(
        reason: PlaybackQuickSearchAIChunkingRequestReason,
        provider: String,
        model: String,
        promptVersion: String,
        normalizedSentence: String,
        usage: AIChunkingUsage?,
        itemCount: Int,
        cacheWritten: Bool,
        durationMilliseconds: Int,
        requestContent: String,
        responseContent: String
    ) {
        let promptTokens = usage?.promptTokens ?? 0
        let completionTokens = usage?.completionTokens ?? 0
        let totalTokens = usage?.totalTokens ?? promptTokens + completionTokens
        let estimatedCostCNY = usage?.estimatedCostCNY ?? 0
        print(
            "[AIChunking] request finished reason=\(reason.rawValue) provider=\(provider) model=\(model) " +
                "prompt_version=\(promptVersion) text_hash=\(Self.shortLogHash(for: normalizedSentence)) " +
                "prompt_tokens=\(promptTokens) completion_tokens=\(completionTokens) total_tokens=\(totalTokens) " +
                "estimated_cost_cny=\(String(format: "%.8f", estimatedCostCNY)) " +
                "items=\(itemCount) cache_written=\(cacheWritten) duration_ms=\(durationMilliseconds) " +
                "request_content=\"\(Self.aiChunkingLogContent(requestContent))\" " +
                "response_content=\"\(Self.aiChunkingLogContent(responseContent))\""
        )
    }

    private func logPlaybackQuickSearchAIChunkRequestFailed(
        reason: PlaybackQuickSearchAIChunkingRequestReason,
        provider: String,
        model: String,
        promptVersion: String,
        sentence: String,
        error: Error,
        requestContent: String
    ) {
        let normalizedSentence = AIChunkTextNormalizer.normalizedSentence(sentence)
        print(
            "[AIChunking] request failed reason=\(reason.rawValue) provider=\(provider) model=\(model) " +
                "prompt_version=\(promptVersion) text_hash=\(Self.shortLogHash(for: normalizedSentence)) " +
                "error=\(Self.aiChunkingLogErrorDescription(for: error)) " +
                "request_content=\"\(Self.aiChunkingLogContent(requestContent))\""
        )
    }

    private static func aiChunkingLogErrorDescription(for error: Error) -> String {
        if case AIChunkingClientError.requestFailed(let statusCode) = error {
            return "http_status_\(statusCode)"
        }

        return String(describing: type(of: error))
    }

    private static func aiChunkingLogContent(_ content: String) -> String {
        content
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\t", with: "\\t")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    private static func shortLogHash(for text: String) -> String {
        let hash = text.utf8.reduce(UInt64(14_695_981_039_346_656_037)) { partialResult, byte in
            (partialResult ^ UInt64(byte)) &* 1_099_511_628_211
        }
        return String(hash, radix: 16)
    }

    private func cancelPlaybackQuickSearchAIChunking() {
        quickSearchAIChunkingTask?.cancel()
        quickSearchAIChunkingTask = nil
    }

    private func startPlaybackQuickSearchSelectedChunkCountIfNeeded() {
        guard playback.isQuickSearchOverlayVisible,
              let query = playback.selectedQuickSearchAIChunkForCount()
        else {
            cancelPlaybackQuickSearchChunkCount()
            playback.resetQuickSearchSelectedChunkCount()
            return
        }

        guard !playback.isQuickSearchSelectedChunkCountCurrent(for: query) else {
            return
        }

        cancelPlaybackQuickSearchChunkCount()
        let requestID = playback.markQuickSearchSelectedChunkCountStarted(query: query)
        quickSearchChunkCountTaskRequestID = requestID

        guard let database = subtitleDatabase else {
            playback.markQuickSearchSelectedChunkCountFinished(
                query: query,
                count: 0,
                requestID: requestID
            )
            quickSearchChunkCountTaskRequestID = nil
            return
        }

        let folders = indexing.selectedFolders
        quickSearchChunkCountTask = Task { [weak self] in
            do {
                let count = try await Task.detached(priority: .utility) {
                    try database.cueGroupOccurrenceCount(for: query, under: folders)
                }.value

                guard !Task.isCancelled else {
                    return
                }

                await MainActor.run {
                    guard let self else {
                        return
                    }

                    self.playback.markQuickSearchSelectedChunkCountFinished(
                        query: query,
                        count: count,
                        requestID: requestID
                    )
                    self.clearPlaybackQuickSearchChunkCountTaskIfCurrent(requestID: requestID)
                }
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else {
                    return
                }

                await MainActor.run {
                    guard let self else {
                        return
                    }

                    print("[AIChunking] failed to get occurrence count for query='\(query)': \(error)")
                    self.playback.markQuickSearchSelectedChunkCountFinished(
                        query: query,
                        count: 0,
                        requestID: requestID
                    )
                    self.clearPlaybackQuickSearchChunkCountTaskIfCurrent(requestID: requestID)
                }
            }
        }
    }

    private func cancelPlaybackQuickSearchChunkCount() {
        quickSearchChunkCountTask?.cancel()
        quickSearchChunkCountTask = nil
        quickSearchChunkCountTaskRequestID = nil
    }

    private func clearPlaybackQuickSearchChunkCountTaskIfCurrent(requestID: Int) {
        guard quickSearchChunkCountTaskRequestID == requestID else {
            return
        }

        quickSearchChunkCountTask = nil
        quickSearchChunkCountTaskRequestID = nil
    }

    private func capturePlaybackQuickSearchSearchContext() {
        quickSearchSearchContextSnapshot = PlaybackQuickSearchSearchContextSnapshot(appState: self)
        quickSearchSearchContextWasMutated = false
    }

    private func restorePlaybackQuickSearchSearchContextIfNeeded() {
        guard let snapshot = quickSearchSearchContextSnapshot else {
            return
        }

        if quickSearchSearchContextWasMutated {
            cancelPlaybackQuickSearchSearchTasks()
        }
        snapshot.restore(to: self)
        quickSearchSearchContextSnapshot = nil
        quickSearchSearchContextWasMutated = false
    }

    private func discardPlaybackQuickSearchSearchContext() {
        quickSearchSearchContextSnapshot = nil
        quickSearchSearchContextWasMutated = false
    }

    private func cancelPlaybackQuickSearchSearchTasks() {
        searchTask?.cancel()
        searchTask = nil
        searchExactCompletionTask?.cancel()
        searchExactCompletionTask = nil
        searchNavigationTask?.cancel()
        searchNavigationTask = nil
        cancelSearchResultGroupTasks()
    }

    private func currentPlaybackQuickSearchInitialLineIndex(
        in candidates: [PlaybackQuickSearchLineCandidate]
    ) -> Int? {
        guard let playbackViewModel = playback.playbackViewModel else {
            return nil
        }

        let milliseconds = max(0, Int((playbackViewModel.displayedCurrentTime * 1_000).rounded(.down)))
        guard let entryID = playback.currentSubtitleEntryLookup.activeEntryID(atMilliseconds: milliseconds),
              let selectedIndex = candidates.lastIndex(where: { $0.entryID == entryID })
        else {
            return nil
        }

        return selectedIndex
    }

    private func currentPlaybackQuickSearchLineCandidates() -> [PlaybackQuickSearchLineCandidate] {
        playback.currentSubtitleEntries.enumerated().flatMap { entryIndex, entry in
            subtitleDisplayLines(content: entry.content, cueLines: [])
                .enumerated()
                .compactMap { lineIndex, line in
                    let text = line.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !text.isEmpty else {
                        return nil
                    }

                    return PlaybackQuickSearchLineCandidate(
                        entryID: entry.id,
                        entryIndex: entryIndex,
                        lineIndex: lineIndex,
                        text: text
                    )
                }
        }
    }

    func stopPlayback() {
        do {
            cancelPlaybackQuickSearchAIChunking()
            cancelPlaybackQuickSearchChunkCount()
            discardPlaybackQuickSearchSearchContext()
            saveCurrentLibraryPlaybackHistory()
            stopLibraryPlaybackHistoryTracking()
            playbackFullscreenManager.exitFullscreen()
            try player?.stop()
            playbackSubtitleCuesTask?.cancel()
            playbackSubtitleCuesTask = nil
            currentSubtitleEntriesTask?.cancel()
            currentSubtitleEntriesTask = nil
            currentSubtitleEntriesTaskSubtitlePath = nil
            currentSubtitleEntriesTaskRequestID += 1
            playback.playbackViewModel?.clearSubtitleCues()
            activePlaybackSource = .none
            search.selectedSearchResult = nil
            library.selectedLibraryVideo = nil
            shiori.selectedShiori = nil
            playback.isPlaybackSurfaceExpanded = false
            playback.isQuickSearchOverlayVisible = false
            playback.isQuickSearchFocused = false
            playback.quickSearchPlaybackWasPlayingOnOpen = false
            playback.resetQuickSearchSubtitleLineNavigation()
            playback.resetQuickSearchResultSelection()
            playback.resetQuickSearchAIState()
            applyCurrentSubtitleEntries([], subtitlePath: nil)
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

    func revealFile(atPath path: String) {
        NSWorkspace.shared.activateFileViewerSelecting([
            URL(fileURLWithPath: path)
        ])
    }

    nonisolated static var playbackSubtitleWindowLimit: Int {
        (playbackSubtitleWindowRadius * 2) + 1
    }

    nonisolated static func playbackSubtitleWindowStart(around index: Int, totalCount: Int) -> Int {
        guard totalCount > 0 else {
            return 0
        }

        let desiredStart = max(0, index - playbackSubtitleWindowRadius)
        let maxStart = max(0, totalCount - playbackSubtitleWindowLimit)
        return min(desiredStart, maxStart)
    }

    func applyCurrentSubtitleEntries(
        _ entries: [SubtitleDatabaseEntry],
        subtitlePath: String?
    ) {
        playback.currentSubtitleEntrySubtitlePath = subtitlePath
        playback.currentSubtitleEntries = entries
        playback.currentSubtitleEntryLookup = SubtitleActiveEntryLookup(entries: entries)
        playback.currentSubtitleEntryIndex = entries.map {
            SubtitleDatabaseEntryIndexItem(
                id: $0.id,
                startMilliseconds: $0.startMilliseconds,
                endMilliseconds: $0.endMilliseconds
            )
        }
        playback.currentSubtitleEntryWindowStartIndex = 0
        playback.currentSubtitleEntryTotalCount = entries.count
        playback.currentSubtitleEntryRowsVersion += 1
    }

    func applyCurrentSubtitleWindow(_ window: PlaybackSubtitleWindowLoad) {
        playback.currentSubtitleEntrySubtitlePath = window.subtitlePath
        playback.currentSubtitleEntries = window.entries
        playback.currentSubtitleEntryIndex = window.index
        playback.currentSubtitleEntryWindowStartIndex = window.windowStartIndex
        playback.currentSubtitleEntryTotalCount = window.index.count
        playback.currentSubtitleEntryLookup = SubtitleActiveEntryLookup(entryIndex: window.index)
        playback.currentSubtitleEntryRowsVersion += 1
    }

    func finishCurrentSubtitleEntriesTask(requestID: Int) {
        guard currentSubtitleEntriesTaskRequestID == requestID else {
            return
        }

        currentSubtitleEntriesTask = nil
        currentSubtitleEntriesTaskSubtitlePath = nil
    }

    func initialPlaybackSubtitleCues(for result: SubtitleSearchResult) -> [PlaybackSubtitleCue] {
        initialPlaybackSubtitleCues(
            forSubtitleFile: URL(fileURLWithPath: result.subtitlePath),
            format: result.subtitleFormat,
            fallbackStartMilliseconds: result.startMilliseconds,
            fallbackEndMilliseconds: result.endMilliseconds,
            fallbackContent: result.content,
            fallbackCueGroupID: result.entryID
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
            let speakersByCueGroupID = try subtitleDatabase.speakersByCueGroupID(forSubtitleFile: subtitleFile)
            let cues = SubtitleSpeakerDisplayCue.targetCues(
                records: records,
                speakersByCueGroupID: speakersByCueGroupID
            )
            SubtitleSpeakerDisplayDiagnostics.log(
                "app.assSpeakerDisplayCues.loaded",
                fields: [
                    "subtitle": subtitleFile.lastPathComponent,
                    "subtitlePath": subtitleFile.path,
                    "recordCount": "\(records.count)",
                    "speakerGroupCount": "\(speakersByCueGroupID.count)",
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
