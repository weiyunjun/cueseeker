import AppKit
import Foundation
import CueSeekerCore
import CueSeekerPlayback

@MainActor
extension AppCoordinator {
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
        guard player.currentVideoURL != nil else {
            cancelAutoSwitchCueSequenceTask()
            clearCueSubtitlePresentationHold()
            if hasPlaybackSelection {
                playback.playbackStatus = .paused
            }
            return true
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

    func isCurrentCueAutoStopEnd(_ endMilliseconds: Int) -> Bool {
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

    func holdCurrentCueSubtitlePresentation(matchingEndMilliseconds endMilliseconds: Int) {
        guard activeCueAutoPauseBoundary?.endMilliseconds == endMilliseconds else {
            return
        }

        playback.playbackViewModel?.holdSubtitlePresentation(
            atMilliseconds: endMilliseconds
        )
    }

    func scheduleAutoSwitchCueSequence() {
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
        guard playback.playbackStatus != .loadFailed,
              playback.playbackStatus != .opening,
              playback.playbackViewModel?.isOpeningNewVideo != true
        else {
            return
        }
        let willPlay = !(playback.playbackViewModel?.isPlaying ?? false)
        togglePlayback()
        playback.playbackViewModel?.showPlayPauseFeedback(isPlaying: willPlay)
    }
}
