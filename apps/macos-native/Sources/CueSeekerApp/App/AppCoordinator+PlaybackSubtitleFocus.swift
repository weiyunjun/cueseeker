import AppKit
import CueSeekerCore
import Foundation

typealias PlaybackSubtitleFocusInitialSnapshotLoader = @MainActor @Sendable (
    _ subtitleFileID: Int64,
    _ timestampMilliseconds: Int
) async throws -> SubtitleFocusSnapshot?

typealias PlaybackSubtitleFocusCompleteCueBatchLoader = @MainActor @Sendable (
    _ subtitleFileID: Int64,
    _ totalCount: Int
) async throws -> SubtitleFocusCueBatch

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
              let subtitleFileID = currentPlaybackSubtitleFileID,
              let subtitleFormat = currentPlaybackSubtitleFormat,
              playbackViewModel.currentTime.isFinite
        else {
            return false
        }

        let source = SubtitleFocusSourceIdentity(
            subtitleFileID: subtitleFileID,
            videoPath: URL(fileURLWithPath: videoPath).standardizedFileURL.path,
            subtitlePath: URL(fileURLWithPath: subtitlePath).standardizedFileURL.path,
            subtitleFormat: subtitleFormat
        )
        let timestampMilliseconds = Int(
            max(0, playbackViewModel.currentTime * 1_000).rounded(.down)
        )
        let openSnapshot = PlaybackSubtitleFocusOpenSnapshot(
            source: source,
            timestampMilliseconds: timestampMilliseconds,
            wasPlaying: playbackViewModel.isPlaying,
            videoPresentation: try? libraryDatabase?
                .completeLibraryFolderDetail(
                    folderPath: URL(fileURLWithPath: videoPath)
                        .deletingLastPathComponent()
                        .standardizedFileURL.path
                )?
                .videos
                .first { $0.videoPath == source.videoPath },
            subtitleRenderSource: playbackSubtitleSource(
                forSubtitleFile: URL(fileURLWithPath: source.subtitlePath),
                format: source.subtitleFormat,
                videoPath: source.videoPath,
                startingAtMilliseconds: timestampMilliseconds,
                fallbackEndMilliseconds: timestampMilliseconds
            )
        )
        let libraryStore: PlaybackLibrarySessionStore?
        if case .library = activePlaybackSource {
            libraryStore = makePlaybackLibrarySessionStore(
                folderPath: URL(fileURLWithPath: source.videoPath)
                    .deletingLastPathComponent()
                    .standardizedFileURL.path,
                initialVideoPath: source.videoPath
            )
        } else {
            libraryStore = nil
        }
        guard let session = playback.beginSubtitleFocusSession(
            openSnapshot: openSnapshot,
            libraryStore: libraryStore
        ) else {
            libraryStore?.invalidate()
            return false
        }

        guard suspendPlaybackForModalPresentation(
            wasPlaying: openSnapshot.wasPlaying
        ) else {
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
    func requestPlaybackLibraryPrimaryAction() -> Bool {
        guard let session = playback.subtitleFocusSession,
              (
                  session.selectedModule == .library
                      || session.selectedModule == .playlist
                          && session.libraryStore != nil
              ),
              let video = session.selectedLibraryPrimaryActionVideo()
        else {
            return false
        }
        return openPlaybackLibraryEpisodeFromOverlay(video)
    }

    @discardableResult
    func openPlaybackLibraryEpisodeFromOverlay(
        _ requestedVideo: CompleteLibraryVideoPresentation
    ) -> Bool {
        guard let session = playback.subtitleFocusSession,
              (
                  session.selectedModule == .library
                      || session.selectedModule == .playlist
                          && session.libraryStore != nil
              ),
              let libraryStore = session.libraryStore,
              let video = libraryStore.primaryActionVideo(
                  itemID: requestedVideo.id
              ),
              video == requestedVideo,
              let detail = libraryStore.detail,
              detail.videos.contains(where: { $0.id == video.id })
        else {
            return false
        }

        prepareLibraryNavigationVideos(detail.videos)
        invalidatePlaybackSubtitleFocusForSourceReplacement()
        openLibraryVideo(
            video.libraryVideo,
            displayTitle: video.displayTitle
        )
        return true
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
                playCurrentCue: playPlaybackSubtitleFocusCurrentCue,
                openPlaylistItem: openPlaybackPlaylistItem,
                openExcerptItem: openPlaybackExcerptItem
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
            playCurrentCue: playPlaybackSubtitleFocusCurrentCue,
            openPlaylistItem: openPlaybackPlaylistItem,
            openExcerptItem: openPlaybackExcerptItem
        )
    }

    @discardableResult
    func executePlaybackSubtitleFocusAction(
        _ execution: PlaybackSubtitleFocusActionExecution,
        playCurrentCue: (PlaybackSubtitleFocusActionContext) -> Bool
    ) -> Bool {
        guard let session = playback.subtitleFocusSession else {
            return false
        }
        return executePlaybackSubtitleFocusAction(
            execution,
            session: session,
            playCurrentCue: playCurrentCue,
            openPlaylistItem: openPlaybackPlaylistItem,
            openExcerptItem: openPlaybackExcerptItem
        )
    }

    @discardableResult
    func executePlaybackSubtitleFocusAction(
        _ execution: PlaybackSubtitleFocusActionExecution,
        playCurrentCue: (PlaybackSubtitleFocusActionContext) -> Bool,
        openPlaylistItem: (PlaybackPlaylistItem) -> Void
    ) -> Bool {
        guard let session = playback.subtitleFocusSession else {
            return false
        }
        return executePlaybackSubtitleFocusAction(
            execution,
            session: session,
            playCurrentCue: playCurrentCue,
            openPlaylistItem: openPlaylistItem,
            openExcerptItem: openPlaybackExcerptItem
        )
    }

    @discardableResult
    func executePlaybackSubtitleFocusAction(
        _ execution: PlaybackSubtitleFocusActionExecution,
        playCurrentCue: (PlaybackSubtitleFocusActionContext) -> Bool,
        openPlaylistItem: (PlaybackPlaylistItem) -> Void,
        openExcerptItem: (PlaybackCueResultItem) -> Void
    ) -> Bool {
        guard let session = playback.subtitleFocusSession else {
            return false
        }
        return executePlaybackSubtitleFocusAction(
            execution,
            session: session,
            playCurrentCue: playCurrentCue,
            openPlaylistItem: openPlaylistItem,
            openExcerptItem: openExcerptItem
        )
    }

    private func executePlaybackSubtitleFocusAction(
        _ execution: PlaybackSubtitleFocusActionExecution,
        session: PlaybackSubtitleFocusSessionStore,
        playCurrentCue: (PlaybackSubtitleFocusActionContext) -> Bool,
        openPlaylistItem: (PlaybackPlaylistItem) -> Void,
        openExcerptItem: (PlaybackCueResultItem) -> Void
    ) -> Bool {
        guard playback.subtitleFocusSession === session,
              session.activeKeyboardAction == execution
        else {
            return false
        }

        switch execution.action {
        case .excerpt:
            // A cue already saved somewhere still opens the menu: the point of
            // choosing a destination is that it can go to another list too.
            togglePlaybackExcerptDestinationMenu(
                surface: .playbackOverlay,
                context: execution.target.actionContext
            )
            _ = session.finishKeyboardAction(execution)
        case .copyCueText:
            let copied = copyPlaybackSubtitleFocusCueText(
                execution.target.primaryCueText
            )
            playback.playbackViewModel?.showSubtitleCopyFeedback(copied: copied)
            _ = session.finishKeyboardAction(execution)
        case .copyCueMarkdownLink:
            let copied: Bool
            if let cueID = execution.target.cueID {
                copied = CueClipboard.copyDeepLink(
                    cueText: execution.target.primaryCueText,
                    cueID: cueID,
                    to: .general
                )
            } else {
                copied = false
            }
            playback.playbackViewModel?.showSubtitleMarkdownLinkCopyFeedback(
                copied: copied
            )
            _ = session.finishKeyboardAction(execution)
        case .playFromThisCue:
            switch execution.target {
            case .current(let context):
                cancelPlaybackSubtitleFocusActionTask()
                cancelPlaybackSubtitleFocusCueLoadTasks()
                guard session.closeAfterPlay(execution) else {
                    return false
                }
                playback.releaseSubtitleFocusSession(session)
                guard playCurrentCue(context) else {
                    return true
                }
                playback.playbackStatus = .playing
                playback.playbackViewModel?.showPlayPauseFeedback(isPlaying: true)
            case .playlist(let item):
                invalidatePlaybackSubtitleFocusForSourceReplacement()
                openPlaylistItem(item)
                playback.playbackViewModel?.showPlayPauseFeedback(isPlaying: true)
            case .search(let item):
                guard case .search(let result) = item.target else {
                    _ = session.finishKeyboardAction(execution)
                    return true
                }
                let promotion = PlaybackSearchPromotion(
                    query: search.searchQuery,
                    scopePaths: indexing.selectedFolders.map {
                        $0.standardizedFileURL.path
                    },
                    selectedOrdinal: item.ordinal
                )
                openSearchResult(
                    result,
                    playbackSearchPromotion: promotion
                )
                playback.playbackViewModel?.showPlayPauseFeedback(isPlaying: true)
            case .excerpt(let item):
                invalidatePlaybackSubtitleFocusForSourceReplacement()
                openExcerptItem(item)
                playback.playbackViewModel?.showPlayPauseFeedback(isPlaying: true)
            }
        }
        return true
    }

    /// Opens the destination menu the `Save to Excerpt` button hangs off, or
    /// closes it when it is already up: the key and the button both toggle it.
    func togglePlaybackExcerptDestinationMenu(
        surface: PlaybackCueFooterSurface,
        context: PlaybackSubtitleFocusActionContext?
    ) {
        guard playback.excerptDestinationMenu?.surface != surface else {
            playback.closeExcerptDestinationMenu()
            return
        }
        guard let context, !context.cue.text.isEmpty else {
            playback.playbackViewModel?.showExcerptFeedback(.unavailable)
            return
        }
        playback.openExcerptDestinationMenu(
            PlaybackExcerptDestinationMenu(
                surface: surface,
                cueID: context.cue.id,
                destinations: excerpt.saveDestinations
            )
        )
    }

    private func copyPlaybackSubtitleFocusCueText(_ text: String) -> Bool {
        CueClipboard.copy(text, to: .general)
    }

    private func playPlaybackSubtitleFocusCurrentCue(
        _ context: PlaybackSubtitleFocusActionContext
    ) -> Bool {
        guard let playbackViewModel = playback.playbackViewModel,
              currentPlaybackVideoPath.map({
                  URL(fileURLWithPath: $0).standardizedFileURL.path
              }) == context.source.videoPath,
              currentPlaybackSubtitlePath.map({
                  URL(fileURLWithPath: $0).standardizedFileURL.path
              }) == context.source.subtitlePath,
              currentPlaybackSubtitleFormat == context.source.subtitleFormat
        else {
            return false
        }

        guard playbackViewModel.playFromCue(
            at: Double(context.cue.startMilliseconds) / 1_000,
            autoPauseBoundary: nil
        ) else {
            return false
        }
        return true
    }

    private func openPlaybackPlaylistItem(_ item: PlaybackPlaylistItem) {
        switch item.target {
        case .search(let result):
            let playbackSearchPromotion: PlaybackSearchPromotion?
            let playlistSourceOverride: PlaybackPlaylistSource?
            if let source = playback.playlistSource,
               source.kind == .search,
               activePlaybackSearchPlaylistContext != nil {
                playbackSearchPromotion = PlaybackSearchPromotion(
                    query: search.searchQuery,
                    scopePaths: indexing.selectedFolders.map {
                        $0.standardizedFileURL.path
                    },
                    selectedOrdinal: item.ordinal
                )
                playlistSourceOverride = nil
            } else if let source = playback.playlistSource,
                      case .cue = source.origin {
                playbackSearchPromotion = nil
                playlistSourceOverride = source
            } else {
                playbackSearchPromotion = nil
                playlistSourceOverride = nil
            }
            openSearchResult(
                result,
                playbackSearchPromotion: playbackSearchPromotion,
                playlistSourceOverride: playlistSourceOverride
            )
        case .excerpt(let excerpt):
            let playlistScope: PlaybackPlaylistExcerptScope?
            if let source = playback.playlistSource,
               case .excerpt(let scope) = source.origin {
                playlistScope = scope
            } else {
                playlistScope = nil
            }
            openExcerpt(
                excerpt,
                navigationScopeIDs: excerptPlaybackNavigationScopeIDs,
                playlistScope: playlistScope,
                playlistSelectedOrdinal: item.ordinal
            )
        }
    }

    private func openPlaybackExcerptItem(_ item: PlaybackCueResultItem) {
        _ = dispatchPlaybackExcerptOverlayItem(item) { excerpt, scope in
            let playlistScope = scope.map {
                PlaybackPlaylistExcerptScope.table(
                    PlaybackPlaylistExcerptTableContext(
                        runID: self.excerpt.tableResultSnapshotID,
                        searchText: self.excerpt.tableSearchDraft,
                        totalCount: $0.count
                    )
                )
            }
            openExcerpt(
                excerpt,
                navigationScopeIDs: scope,
                playlistScope: playlistScope,
                playlistSelectedOrdinal: item.ordinal
            )
        }
    }

    @discardableResult
    func dispatchPlaybackExcerptOverlayItem(
        _ item: PlaybackCueResultItem,
        open: (Excerpt, [Int64]?) -> Void
    ) -> Bool {
        guard case .excerpt(let excerpt) = item.target else {
            return false
        }
        let resultIDs = self.excerpt.playbackTableResultExcerptIDs
        open(excerpt, resultIDs)
        return true
    }

    func cancelPlaybackSubtitleFocusActionTask() {
        playbackSubtitleFocusActionGeneration += 1
        playbackSubtitleFocusActionTask?.cancel()
        playbackSubtitleFocusActionTask = nil
    }

    func startPlaybackSubtitleFocusInitialLoad(
        for session: PlaybackSubtitleFocusSessionStore,
        initialSnapshotLoader: PlaybackSubtitleFocusInitialSnapshotLoader? = nil,
        completeCueBatchLoader: PlaybackSubtitleFocusCompleteCueBatchLoader? = nil
    ) {
        playbackSubtitleFocusInitialLoadTask?.cancel()
        guard let subtitleFileID = session.openSnapshot.source.subtitleFileID else {
            finishPlaybackSubtitleFocusOpeningFailure(
                session: session,
                token: session.token,
                error: nil
            )
            return
        }
        let timestampMilliseconds = session.openSnapshot.timestampMilliseconds
        let token = session.token
        let databaseReader = playbackSubtitleFocusDatabaseReader
        let loadInitialSnapshot = initialSnapshotLoader ?? { subtitleFileID, timestamp in
            try await databaseReader.initialSnapshot(
                subtitleFileID: subtitleFileID,
                timestampMilliseconds: timestamp
            )
        }

        playbackSubtitleFocusInitialLoadTask = Task { @MainActor [weak self, weak session] in
            guard let self, let session else {
                return
            }

            do {
                let snapshot = try await loadInitialSnapshot(
                    subtitleFileID,
                    timestampMilliseconds
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
                self.startPlaybackSubtitleFocusCompleteLoadIfNeeded(
                    for: session,
                    loader: completeCueBatchLoader
                )
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

    func startPlaybackSubtitleFocusCompleteLoadIfNeeded(
        for session: PlaybackSubtitleFocusSessionStore,
        loader: PlaybackSubtitleFocusCompleteCueBatchLoader? = nil
    ) {
        guard let totalCount = session.completeCueLoadTotalCount else {
            return
        }

        playbackSubtitleFocusCompleteLoadTask?.cancel()
        guard let subtitleFileID = session.openSnapshot.source.subtitleFileID else {
            return
        }
        let token = session.token
        let databaseReader = playbackSubtitleFocusDatabaseReader
        let loadCompleteCueBatch = loader ?? { subtitleFileID, totalCount in
            try await databaseReader.completeCueBatch(
                subtitleFileID: subtitleFileID,
                totalCount: totalCount
            )
        }
        playbackSubtitleFocusCompleteLoadTask = Task { @MainActor [weak self, weak session] in
            guard let self, let session else {
                return
            }

            do {
                let batch = try await loadCompleteCueBatch(
                    subtitleFileID,
                    totalCount
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
