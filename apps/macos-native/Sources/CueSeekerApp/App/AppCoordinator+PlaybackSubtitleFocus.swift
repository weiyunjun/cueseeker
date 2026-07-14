import AppKit
import CueSeekerCore
import Foundation

@MainActor
extension AppCoordinator {
    @discardableResult
    func openPlaybackSubtitleFocusFromUser() -> Bool {
        if playback.subtitleFocusSession != nil {
            return true
        }

        guard !playback.isTimelineScrubbing,
              playback.playbackStatus == .playing || playback.playbackStatus == .paused,
              let playbackViewModel = playback.playbackViewModel,
              player != nil,
              let videoPath = currentPlaybackVideoPath,
              let subtitlePath = currentPlaybackSubtitlePath,
              let subtitleFormat = currentPlaybackSubtitleFormat,
              playbackViewModel.currentTime.isFinite
        else {
            return false
        }

        let source = SubtitleFocusSourceIdentity(
            videoPath: URL(fileURLWithPath: videoPath).standardizedFileURL.path,
            subtitlePath: URL(fileURLWithPath: subtitlePath).standardizedFileURL.path,
            subtitleFormat: subtitleFormat
        )
        let openSnapshot = PlaybackSubtitleFocusOpenSnapshot(
            source: source,
            timestampMilliseconds: Int(
                max(0, playbackViewModel.currentTime * 1_000).rounded(.down)
            ),
            wasPlaying: playbackViewModel.isPlaying
        )
        let searchStore = makePlaybackSearchSessionStore()
        let shioriSource = makePlaybackShioriOverlaySource()
        guard let session = playback.beginSubtitleFocusSession(
            openSnapshot: openSnapshot,
            searchStore: searchStore,
            shioriSource: shioriSource
        ) else {
            searchStore.invalidate()
            shioriSource.invalidate()
            return false
        }

        guard pausePlayback() else {
            _ = session.failOpening(token: session.token)
            playback.releaseSubtitleFocusSession(session)
            return false
        }

        startPlaybackSubtitleFocusInitialLoad(for: session)
        return true
    }

    @discardableResult
    func dismissPlaybackSubtitleFocusFromUser() -> Bool {
        guard let session = playback.subtitleFocusSession else {
            return false
        }

        cancelPlaybackSubtitleFocusActionTask()
        cancelPlaybackSubtitleFocusCueLoadTasks()
        guard let shouldResume = session.dismissByUser() else {
            playback.releaseSubtitleFocusSession(session)
            return false
        }
        playback.releaseSubtitleFocusSession(session)

        if shouldResume {
            resumePlayback()
        }
        return true
    }

    func invalidatePlaybackSubtitleFocusForSourceReplacement() {
        cancelPlaybackSubtitleFocusActionTask()
        cancelPlaybackSubtitleFocusCueLoadTasks()
        guard let session = playback.subtitleFocusSession else {
            return
        }

        session.invalidateForSourceReplacement()
        playback.releaseSubtitleFocusSession(session)
    }

    @discardableResult
    func requestPlaybackSubtitleFocusAction(
        _ action: PlaybackSubtitleFocusAction
    ) -> Bool {
        guard let session = playback.subtitleFocusSession else {
            return false
        }

        switch session.requestKeyboardAction(action) {
        case .rejected:
            return false
        case .deferred:
            return true
        case .ready(let execution):
            return executePlaybackSubtitleFocusAction(
                execution,
                session: session,
                continuousPlay: playContinuouslyFromPlaybackSubtitleFocusCue,
                openPlaylistItem: openPlaybackPlaylistItem,
                openShioriItem: openPlaybackShioriItem
            )
        }
    }

    @discardableResult
    func requestPlaybackSearchPlayAction() -> Bool {
        guard let session = playback.subtitleFocusSession else {
            return false
        }

        switch session.requestSettledSearchPlayAction() {
        case .rejected:
            return false
        case .deferred:
            return false
        case .ready(let execution):
            return executePlaybackSubtitleFocusAction(execution)
        }
    }

    @discardableResult
    func executePlaybackSubtitleFocusAction(
        _ execution: PlaybackSubtitleFocusActionExecution
    ) -> Bool {
        guard let session = playback.subtitleFocusSession else {
            return false
        }
        return executePlaybackSubtitleFocusAction(
            execution,
            session: session,
            continuousPlay: playContinuouslyFromPlaybackSubtitleFocusCue,
            openPlaylistItem: openPlaybackPlaylistItem,
            openShioriItem: openPlaybackShioriItem
        )
    }

    @discardableResult
    func executePlaybackSubtitleFocusAction(
        _ execution: PlaybackSubtitleFocusActionExecution,
        continuousPlay: (PlaybackSubtitleFocusActionContext) -> Bool
    ) -> Bool {
        guard let session = playback.subtitleFocusSession else {
            return false
        }
        return executePlaybackSubtitleFocusAction(
            execution,
            session: session,
            continuousPlay: continuousPlay,
            openPlaylistItem: openPlaybackPlaylistItem,
            openShioriItem: openPlaybackShioriItem
        )
    }

    @discardableResult
    func executePlaybackSubtitleFocusAction(
        _ execution: PlaybackSubtitleFocusActionExecution,
        continuousPlay: (PlaybackSubtitleFocusActionContext) -> Bool,
        openPlaylistItem: (PlaybackPlaylistItem) -> Void
    ) -> Bool {
        guard let session = playback.subtitleFocusSession else {
            return false
        }
        return executePlaybackSubtitleFocusAction(
            execution,
            session: session,
            continuousPlay: continuousPlay,
            openPlaylistItem: openPlaylistItem,
            openShioriItem: openPlaybackShioriItem
        )
    }

    @discardableResult
    func executePlaybackSubtitleFocusAction(
        _ execution: PlaybackSubtitleFocusActionExecution,
        continuousPlay: (PlaybackSubtitleFocusActionContext) -> Bool,
        openPlaylistItem: (PlaybackPlaylistItem) -> Void,
        openShioriItem: (PlaybackCueResultItem) -> Void
    ) -> Bool {
        guard let session = playback.subtitleFocusSession else {
            return false
        }
        return executePlaybackSubtitleFocusAction(
            execution,
            session: session,
            continuousPlay: continuousPlay,
            openPlaylistItem: openPlaylistItem,
            openShioriItem: openShioriItem
        )
    }

    private func executePlaybackSubtitleFocusAction(
        _ execution: PlaybackSubtitleFocusActionExecution,
        session: PlaybackSubtitleFocusSessionStore,
        continuousPlay: (PlaybackSubtitleFocusActionContext) -> Bool,
        openPlaylistItem: (PlaybackPlaylistItem) -> Void,
        openShioriItem: (PlaybackCueResultItem) -> Void
    ) -> Bool {
        guard playback.subtitleFocusSession === session,
              session.activeKeyboardAction == execution
        else {
            return false
        }

        switch execution.action {
        case .shiori:
            if execution.target.representsSavedShiori {
                playback.playbackViewModel?.showShioriFeedback(.alreadySaved)
                _ = session.finishKeyboardAction(execution)
                return true
            }
            startPlaybackSubtitleFocusShioriSave(execution, session: session)
        case .copyCueText:
            let copied = copyPlaybackSubtitleFocusCueText(
                execution.target.primaryCueText
            )
            playback.playbackViewModel?.showSubtitleCopyFeedback(copied: copied)
            _ = session.finishKeyboardAction(execution)
        case .playFromThisCue:
            switch execution.target {
            case .current(let context):
                guard continuousPlay(context) else {
                    _ = session.finishKeyboardAction(execution)
                    return true
                }
                clearCueSegmentPlayback()
                playback.playbackStatus = .playing
                playback.playbackViewModel?.showPlayPauseFeedback(isPlaying: true)
                cancelPlaybackSubtitleFocusActionTask()
                cancelPlaybackSubtitleFocusCueLoadTasks()
                guard session.closeAfterPlay(execution) else {
                    return false
                }
                playback.releaseSubtitleFocusSession(session)
            case .playlist(let item):
                invalidatePlaybackSubtitleFocusForSourceReplacement()
                openPlaylistItem(item)
                playback.playbackViewModel?.showPlayPauseFeedback(isPlaying: true)
            case .search(let item):
                guard case .search(let result) = item.target,
                      let promotion = session.promoteSearchForPlayback(
                          selectedItem: item
                      )
                else {
                    _ = session.finishKeyboardAction(execution)
                    return true
                }
                openSearchResult(
                    result,
                    playsContinuouslyFromStart: true,
                    playbackSearchPromotion: promotion
                )
                playback.playbackViewModel?.showPlayPauseFeedback(isPlaying: true)
            case .shiori(let item):
                invalidatePlaybackSubtitleFocusForSourceReplacement()
                openShioriItem(item)
                playback.playbackViewModel?.showPlayPauseFeedback(isPlaying: true)
            }
        }
        return true
    }

    private func startPlaybackSubtitleFocusShioriSave(
        _ execution: PlaybackSubtitleFocusActionExecution,
        session: PlaybackSubtitleFocusSessionStore
    ) {
        guard let actionContext = execution.target.actionContext,
              !actionContext.cue.text.isEmpty
        else {
            playback.playbackViewModel?.showShioriFeedback(.unavailable)
            _ = session.finishKeyboardAction(execution)
            return
        }
        cancelPlaybackSubtitleFocusActionTask()
        let taskGeneration = playbackSubtitleFocusActionGeneration
        let databaseReader = playbackSubtitleFocusDatabaseReader
        let videoName = execution.target.sourceVideoName ?? currentPlaybackTitle
        playbackSubtitleFocusActionTask = Task { @MainActor [weak self, weak session] in
            guard let self, let session else {
                return
            }

            do {
                let result = try await databaseReader.saveShiori(
                    context: actionContext,
                    videoName: videoName
                )
                self.finishPlaybackSubtitleFocusShioriSave(
                    result,
                    execution,
                    session: session,
                    taskGeneration: taskGeneration
                )
            } catch is CancellationError {
                if self.playbackSubtitleFocusActionGeneration == taskGeneration {
                    self.playbackSubtitleFocusActionTask = nil
                }
            } catch {
                guard self.playbackSubtitleFocusActionGeneration == taskGeneration,
                      self.playback.subtitleFocusSession === session
                else {
                    return
                }
                self.playbackSubtitleFocusActionTask = nil
                print("Failed to save Playback Subtitle Focus Shiori: \(error)")
                self.playback.playbackViewModel?.showShioriFeedback(.unavailable)
                _ = session.finishKeyboardAction(execution)
            }
        }
    }

    func finishPlaybackSubtitleFocusShioriSave(
        _ result: PlaybackSubtitleFocusShioriWriteResult,
        _ execution: PlaybackSubtitleFocusActionExecution,
        session: PlaybackSubtitleFocusSessionStore,
        taskGeneration: Int
    ) {
        if result == .saved {
            shiori.invalidateTableRows()
        }
        guard playbackSubtitleFocusActionGeneration == taskGeneration,
              playback.subtitleFocusSession === session,
              session.activeKeyboardAction == execution
        else {
            return
        }
        playbackSubtitleFocusActionTask = nil
        if result == .saved {
            _ = session.refreshShioriAfterSave()
        }
        playback.playbackViewModel?.showShioriFeedback(
            result == .saved ? .saved : .alreadySaved
        )
        _ = session.finishKeyboardAction(execution)
    }

    private func copyPlaybackSubtitleFocusCueText(_ text: String) -> Bool {
        PlaybackSubtitleFocusClipboard.copy(text, to: .general)
    }

    private func playContinuouslyFromPlaybackSubtitleFocusCue(
        _ context: PlaybackSubtitleFocusActionContext
    ) -> Bool {
        guard let playbackViewModel = playback.playbackViewModel,
              currentPlaybackVideoPath.map({
                  URL(fileURLWithPath: $0).standardizedFileURL.path
              }) == context.source.videoPath,
              currentPlaybackSubtitlePath.map({
                  URL(fileURLWithPath: $0).standardizedFileURL.path
              }) == context.source.subtitlePath,
              currentPlaybackSubtitleFormat == context.source.subtitleFormat,
              playbackViewModel.playContinuously(
                  from: Double(context.cue.startMilliseconds) / 1_000
              )
        else {
            return false
        }

        return true
    }

    private func openPlaybackPlaylistItem(_ item: PlaybackPlaylistItem) {
        switch item.target {
        case .search(let result):
            let playbackSearchPromotion: PlaybackSearchPromotion?
            if let source = playback.playlistSource,
               source === activePlaybackSearchPlaylistContext?.source {
                playbackSearchPromotion = PlaybackSearchPromotion(
                    source: source,
                    selectedOrdinal: item.ordinal
                )
            } else {
                playbackSearchPromotion = nil
            }
            openSearchResult(
                result,
                playsContinuouslyFromStart: true,
                playbackSearchPromotion: playbackSearchPromotion
            )
        case .shiori(let shiori):
            openShiori(
                shiori,
                navigationScopeIDs: shioriPlaybackNavigationScopeIDs,
                playsContinuouslyFromStart: true
            )
        }
    }

    private func openPlaybackShioriItem(_ item: PlaybackCueResultItem) {
        _ = dispatchPlaybackShioriOverlayItem(item) { shiori, scope, continuous in
            openShiori(
                shiori,
                navigationScopeIDs: scope,
                playsContinuouslyFromStart: continuous
            )
        }
    }

    @discardableResult
    func dispatchPlaybackShioriOverlayItem(
        _ item: PlaybackCueResultItem,
        open: (Shiori, [Int64]?, Bool) -> Void
    ) -> Bool {
        guard case .shiori(let shiori) = item.target else {
            return false
        }
        open(shiori, nil, true)
        return true
    }

    private func cancelPlaybackSubtitleFocusActionTask() {
        playbackSubtitleFocusActionGeneration += 1
        playbackSubtitleFocusActionTask?.cancel()
        playbackSubtitleFocusActionTask = nil
    }

    private func startPlaybackSubtitleFocusInitialLoad(
        for session: PlaybackSubtitleFocusSessionStore
    ) {
        playbackSubtitleFocusInitialLoadTask?.cancel()
        let subtitlePath = session.openSnapshot.source.subtitlePath
        let timestampMilliseconds = session.openSnapshot.timestampMilliseconds
        let token = session.token
        let databaseReader = playbackSubtitleFocusDatabaseReader

        playbackSubtitleFocusInitialLoadTask = Task { @MainActor [weak self, weak session] in
            guard let self, let session else {
                return
            }

            do {
                let snapshot = try await databaseReader.initialSnapshot(
                    subtitlePath: subtitlePath,
                    timestampMilliseconds: timestampMilliseconds
                )
                try Task.checkCancellation()
                guard self.playback.subtitleFocusSession === session else {
                    return
                }

                self.playbackSubtitleFocusInitialLoadTask = nil
                guard let snapshot,
                      session.publishInitialSnapshot(snapshot, token: token)
                else {
                    self.finishPlaybackSubtitleFocusOpeningFailure(
                        session: session,
                        token: token,
                        error: nil
                    )
                    return
                }
                self.startPlaybackSubtitleFocusCompleteLoadIfNeeded(for: session)
            } catch is CancellationError {
                return
            } catch {
                guard self.playback.subtitleFocusSession === session else {
                    return
                }
                self.playbackSubtitleFocusInitialLoadTask = nil
                self.finishPlaybackSubtitleFocusOpeningFailure(
                    session: session,
                    token: token,
                    error: error
                )
            }
        }
    }

    private func startPlaybackSubtitleFocusCompleteLoadIfNeeded(
        for session: PlaybackSubtitleFocusSessionStore
    ) {
        guard let totalCount = session.completeCueLoadTotalCount else {
            return
        }

        playbackSubtitleFocusCompleteLoadTask?.cancel()
        let subtitlePath = session.openSnapshot.source.subtitlePath
        let token = session.token
        let databaseReader = playbackSubtitleFocusDatabaseReader
        playbackSubtitleFocusCompleteLoadTask = Task { @MainActor [weak self, weak session] in
            guard let self, let session else {
                return
            }

            do {
                let batch = try await databaseReader.completeCueBatch(
                    subtitlePath: subtitlePath,
                    totalCount: totalCount
                )
                try Task.checkCancellation()
                guard self.playback.subtitleFocusSession === session else {
                    return
                }
                self.playbackSubtitleFocusCompleteLoadTask = nil
                _ = session.publishCompleteCueBatch(batch, token: token)
            } catch is CancellationError {
                return
            } catch {
                guard self.playback.subtitleFocusSession === session else {
                    return
                }
                self.playbackSubtitleFocusCompleteLoadTask = nil
                print("Failed to load complete Playback Subtitle Focus cues: \(error)")
            }
        }
    }

    private func finishPlaybackSubtitleFocusOpeningFailure(
        session: PlaybackSubtitleFocusSessionStore,
        token: PlaybackSubtitleFocusSessionToken,
        error: Error?
    ) {
        guard playback.subtitleFocusSession === session,
              let shouldResume = session.failOpening(token: token)
        else {
            return
        }

        playback.releaseSubtitleFocusSession(session)
        if let error {
            print("Failed to open Playback Subtitle Focus: \(error)")
        }
        if shouldResume {
            resumePlayback()
        }
    }

    private func cancelPlaybackSubtitleFocusCueLoadTasks() {
        playbackSubtitleFocusInitialLoadTask?.cancel()
        playbackSubtitleFocusInitialLoadTask = nil
        playbackSubtitleFocusCompleteLoadTask?.cancel()
        playbackSubtitleFocusCompleteLoadTask = nil
    }

}
