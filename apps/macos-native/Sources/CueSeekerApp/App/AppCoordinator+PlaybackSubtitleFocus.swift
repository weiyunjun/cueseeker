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
        guard let session = playback.beginSubtitleFocusSession(openSnapshot: openSnapshot) else {
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

        cancelPlaybackSubtitleFocusMenuTasks()
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
        cancelPlaybackSubtitleFocusMenuTasks()
        cancelPlaybackSubtitleFocusCueLoadTasks()
        guard let session = playback.subtitleFocusSession else {
            return
        }

        session.invalidateForSourceReplacement()
        playback.releaseSubtitleFocusSession(session)
    }

    @discardableResult
    func openPlaybackSubtitleFocusActionMenuFromKeyboard() -> Bool {
        guard let session = playback.subtitleFocusSession,
              let cue = session.actionMenuCandidateForKeyboard()
        else {
            return false
        }
        guard session.openActionMenuFromKeyboard(for: cue) else {
            return false
        }
        startPlaybackSubtitleFocusShioriLookup(for: session)
        return true
    }

    @discardableResult
    func openPlaybackSubtitleFocusActionMenu(
        for cue: SubtitleFocusCue,
        focusAnchorY: CGFloat
    ) -> Bool {
        guard let session = playback.subtitleFocusSession,
              session.canOpenActionMenuFromPointer(for: cue)
        else {
            return false
        }
        guard session.openActionMenuFromPointer(
            for: cue,
            focusAnchorY: focusAnchorY
        ) else {
            return false
        }
        startPlaybackSubtitleFocusShioriLookup(for: session)
        return true
    }

    @discardableResult
    func dismissPlaybackSubtitleFocusActionMenuFromUser() -> Bool {
        guard let session = playback.subtitleFocusSession,
              session.dismissActionMenu()
        else {
            return false
        }
        cancelPlaybackSubtitleFocusShioriLookup()
        return true
    }

    @discardableResult
    func executePlaybackSubtitleFocusAction(
        _ requestedAction: PlaybackSubtitleFocusAction? = nil
    ) -> Bool {
        guard let session = playback.subtitleFocusSession,
              let execution = session.beginActionMenuExecution(
                  action: requestedAction
              )
        else {
            return false
        }

        switch execution.action {
        case .shiori:
            startPlaybackSubtitleFocusShioriSave(
                execution,
                session: session
            )
            return true
        case .copyCueText:
            guard copyPlaybackSubtitleFocusCueText(execution.context.cue.text) else {
                _ = session.failActionMenuExecution(
                    menuGeneration: execution.menuGeneration
                )
                return true
            }
        case .playFromThisCue:
            guard playContinuouslyFromPlaybackSubtitleFocusCue(execution.context) else {
                _ = session.failActionMenuExecution(
                    menuGeneration: execution.menuGeneration
                )
                return true
            }
        }

        completePlaybackSubtitleFocusAction(execution, session: session)
        return true
    }

    private func completePlaybackSubtitleFocusAction(
        _ execution: PlaybackSubtitleFocusActionExecution,
        session: PlaybackSubtitleFocusSessionStore
    ) {
        cancelPlaybackSubtitleFocusMenuTasks()
        cancelPlaybackSubtitleFocusCueLoadTasks()
        guard let shouldResume = session.completeActionMenuExecution(
            menuGeneration: execution.menuGeneration
        ) else {
            return
        }
        playback.releaseSubtitleFocusSession(session)

        if execution.action != .playFromThisCue, shouldResume {
            resumePlayback()
        }
    }

    private func startPlaybackSubtitleFocusShioriLookup(
        for session: PlaybackSubtitleFocusSessionStore
    ) {
        guard let request = session.actionMenuShioriLookupRequest else {
            return
        }
        cancelPlaybackSubtitleFocusShioriLookup()
        let taskGeneration = playbackSubtitleFocusShioriLookupGeneration
        let databaseReader = playbackSubtitleFocusDatabaseReader
        playbackSubtitleFocusShioriLookupTask = Task { @MainActor [weak self, weak session] in
            guard let self, let session else {
                return
            }

            do {
                let isSaved = try await databaseReader.isShioriSaved(
                    context: request.context
                )
                try Task.checkCancellation()
                guard self.playbackSubtitleFocusShioriLookupGeneration == taskGeneration,
                      self.playback.subtitleFocusSession === session
                else {
                    return
                }
                self.playbackSubtitleFocusShioriLookupTask = nil
                _ = session.resolveActionMenuShioriAvailability(
                    isSaved ? .alreadySaved : .available,
                    request: request
                )
            } catch is CancellationError {
                if self.playbackSubtitleFocusShioriLookupGeneration == taskGeneration {
                    self.playbackSubtitleFocusShioriLookupTask = nil
                }
            } catch {
                guard self.playbackSubtitleFocusShioriLookupGeneration == taskGeneration,
                      self.playback.subtitleFocusSession === session
                else {
                    return
                }
                self.playbackSubtitleFocusShioriLookupTask = nil
                print("Failed to resolve Playback Subtitle Focus Shiori state: \(error)")
                _ = session.resolveActionMenuShioriAvailability(
                    .unavailable,
                    request: request
                )
            }
        }
    }

    private func startPlaybackSubtitleFocusShioriSave(
        _ execution: PlaybackSubtitleFocusActionExecution,
        session: PlaybackSubtitleFocusSessionStore
    ) {
        guard !execution.context.cue.text.isEmpty else {
            _ = session.failActionMenuExecution(
                menuGeneration: execution.menuGeneration
            )
            return
        }
        cancelPlaybackSubtitleFocusActionTask()
        let taskGeneration = playbackSubtitleFocusActionGeneration
        let databaseReader = playbackSubtitleFocusDatabaseReader
        let videoName = currentPlaybackTitle
        playbackSubtitleFocusActionTask = Task { @MainActor [weak self, weak session] in
            guard let self, let session else {
                return
            }

            do {
                let result = try await databaseReader.saveShiori(
                    context: execution.context,
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
                _ = session.failActionMenuExecution(
                    menuGeneration: execution.menuGeneration
                )
            }
        }
    }

    func finishPlaybackSubtitleFocusShioriSave(
        _: PlaybackSubtitleFocusShioriWriteResult,
        _ execution: PlaybackSubtitleFocusActionExecution,
        session: PlaybackSubtitleFocusSessionStore,
        taskGeneration: Int
    ) {
        shiori.invalidateTableRows()
        guard playbackSubtitleFocusActionGeneration == taskGeneration,
              playback.subtitleFocusSession === session
        else {
            return
        }
        playbackSubtitleFocusActionTask = nil
        _ = session.markActionMenuShioriSaved(
            menuGeneration: execution.menuGeneration
        )
        completePlaybackSubtitleFocusAction(
            execution,
            session: session
        )
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

        clearCueSegmentPlayback()
        playback.playbackStatus = .playing
        return true
    }

    private func cancelPlaybackSubtitleFocusMenuTasks() {
        cancelPlaybackSubtitleFocusShioriLookup()
        cancelPlaybackSubtitleFocusActionTask()
    }

    private func cancelPlaybackSubtitleFocusShioriLookup() {
        playbackSubtitleFocusShioriLookupGeneration += 1
        playbackSubtitleFocusShioriLookupTask?.cancel()
        playbackSubtitleFocusShioriLookupTask = nil
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
