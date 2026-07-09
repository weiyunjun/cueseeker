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

        playbackSubtitleFocusInitialLoadTask?.cancel()
        playbackSubtitleFocusInitialLoadTask = nil
        playbackSubtitleFocusWindowLoadTask?.cancel()
        playbackSubtitleFocusWindowLoadTask = nil
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
        playbackSubtitleFocusInitialLoadTask?.cancel()
        playbackSubtitleFocusInitialLoadTask = nil
        playbackSubtitleFocusWindowLoadTask?.cancel()
        playbackSubtitleFocusWindowLoadTask = nil
        guard let session = playback.subtitleFocusSession else {
            return
        }

        session.invalidateForSourceReplacement()
        playback.releaseSubtitleFocusSession(session)
    }

    @discardableResult
    func movePlaybackSubtitleFocusSelection(
        _ direction: SubtitleFocusNavigationDirection
    ) -> Bool {
        guard let session = playback.subtitleFocusSession else {
            return false
        }
        let moved = session.moveSelection(direction)
        startPlaybackSubtitleFocusWindowLoadIfNeeded(
            session.windowLoadRequestAfterNavigation(direction),
            session: session
        )
        return moved
    }

    func notePlaybackSubtitleFocusNavigationIntent(
        _ direction: SubtitleFocusNavigationDirection
    ) {
        guard let session = playback.subtitleFocusSession else {
            return
        }
        startPlaybackSubtitleFocusWindowLoadIfNeeded(
            session.windowLoadRequestAfterNavigation(direction),
            session: session
        )
    }

    func notePlaybackSubtitleFocusScrollbarPreview(ordinal: Int) {
        playback.subtitleFocusSession?.noteScrollbarPreviewChanged(ordinal: ordinal)
    }

    @discardableResult
    func commitPlaybackSubtitleFocusCachedScrollbarTarget(
        ordinal: Int
    ) -> Bool {
        playback.subtitleFocusSession?.commitCachedScrollbarTarget(
            ordinal: ordinal
        ) ?? false
    }

    func requestPlaybackSubtitleFocusScrollbarTarget(ordinal: Int) {
        guard let session = playback.subtitleFocusSession else {
            return
        }
        startPlaybackSubtitleFocusWindowLoadIfNeeded(
            session.windowLoadRequestForScrollbarTarget(ordinal: ordinal),
            session: session
        )
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

    private func startPlaybackSubtitleFocusWindowLoadIfNeeded(
        _ request: PlaybackSubtitleFocusWindowLoadRequest?,
        session: PlaybackSubtitleFocusSessionStore
    ) {
        guard let request,
              playbackSubtitleFocusWindowLoadTask == nil,
              playback.subtitleFocusSession === session,
              session.isActiveWindowLoad(request)
        else {
            return
        }

        let databaseReader = playbackSubtitleFocusDatabaseReader
        let subtitlePath = session.openSnapshot.source.subtitlePath
        playbackSubtitleFocusWindowLoadTask = Task { @MainActor [weak self, weak session] in
            guard let self, let session else {
                return
            }

            do {
                let batch = try await databaseReader.cueBatch(
                    subtitlePath: subtitlePath,
                    request: request
                )
                try Task.checkCancellation()
                guard self.playback.subtitleFocusSession === session,
                      session.isActiveWindowLoad(request)
                else {
                    return
                }

                self.playbackSubtitleFocusWindowLoadTask = nil
                let nextRequest = session.completeWindowLoad(
                    request,
                    batch: batch
                )
                self.startPlaybackSubtitleFocusWindowLoadIfNeeded(
                    nextRequest,
                    session: session
                )
            } catch is CancellationError {
                return
            } catch {
                guard self.playback.subtitleFocusSession === session,
                      session.isActiveWindowLoad(request)
                else {
                    return
                }

                self.playbackSubtitleFocusWindowLoadTask = nil
                print("Failed to load Playback Subtitle Focus window: \(error)")
                let nextRequest = session.completeWindowLoad(
                    request,
                    batch: nil
                )
                self.startPlaybackSubtitleFocusWindowLoadIfNeeded(
                    nextRequest,
                    session: session
                )
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

}
