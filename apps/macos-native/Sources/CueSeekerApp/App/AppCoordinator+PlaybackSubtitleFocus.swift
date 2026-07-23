import AppKit
import CueSeekerCore
import Foundation

typealias PlaybackSubtitleFocusInitialSnapshotLoader = @MainActor @Sendable (
    _ subtitlePath: String,
    _ timestampMilliseconds: Int
) async throws -> SubtitleFocusSnapshot?

typealias PlaybackSubtitleFocusCompleteCueBatchLoader = @MainActor @Sendable (
    _ subtitlePath: String,
    _ totalCount: Int
) async throws -> SubtitleFocusCueBatch

@MainActor
extension AppCoordinator {
    @discardableResult
    func openPlaybackSubtitleFocusFromUser(
        presenting requestedModule: PlaybackOverlayModule? = nil
    ) -> Bool {
        if let session = playback.subtitleFocusSession {
            guard let requestedModule else {
                return true
            }
            return session.presentModule(requestedModule)
        }
        if playbackRecentOpenTask != nil {
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
        let recentStore = makePlaybackRecentSessionStore()
        let libraryStore = makePlaybackLibrarySessionStore()
        loadShioriTableRowsIfNeeded()
        guard let session = playback.beginSubtitleFocusSession(
            openSnapshot: openSnapshot,
            searchStore: search,
            recentStore: recentStore,
            libraryStore: libraryStore,
            shioriStore: shiori
        ) else {
            recentStore.invalidate()
            libraryStore.invalidate()
            return false
        }

        if let requestedModule,
           !session.presentModule(requestedModule) {
            playback.releaseSubtitleFocusSession(session)
            return false
        }

        cancelAutoSwitchCueSequenceTask()

        if playbackViewModel.isPlaying {
            guard pausePlayback() else {
                _ = session.failOpening(token: session.token)
                playback.releaseSubtitleFocusSession(session)
                return false
            }
        }

        flushPendingLibraryPlaybackHistoryPresentations()
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
        finishPlaybackSearchHost(committingEmptyFilter: false)
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

    func invalidatePlaybackSubtitleFocusForSourceReplacement(
        finishesPlaybackSearchHost: Bool = true
    ) {
        cancelPlaybackRecentOpenTask()
        cancelPlaybackSubtitleFocusActionTask()
        cancelPlaybackSubtitleFocusCueLoadTasks()
        if finishesPlaybackSearchHost {
            finishPlaybackSearchHost(committingEmptyFilter: false)
        }
        guard let session = playback.subtitleFocusSession else {
            return
        }

        session.invalidateForSourceReplacement()
        playback.releaseSubtitleFocusSession(session)
    }

    @discardableResult
    func requestPlaybackRecentOpenAction() -> Bool {
        guard let item = playback.subtitleFocusSession?
            .selectedRecentPrimaryActionItem()
        else {
            return false
        }
        return openPlaybackRecentItemFromOverlay(item)
    }

    @discardableResult
    func openPlaybackRecentItemFromOverlay(
        _ requestedItem: RecentLibraryWatchingPresentation
    ) -> Bool {
        guard let session = playback.subtitleFocusSession,
              session.selectedModule == .recent,
              let recentStore = session.recentStore,
              let item = recentStore.primaryActionItem(itemID: requestedItem.id),
              item == requestedItem
        else {
            return false
        }

        let source = session.openSnapshot.source
        invalidatePlaybackSubtitleFocusForSourceReplacement()

        playbackRecentOpenGeneration &+= 1
        let generation = playbackRecentOpenGeneration
        playbackRecentOpenTask = Task { @MainActor [weak self] in
            guard let self else {
                return
            }
            defer {
                if playbackRecentOpenGeneration == generation {
                    playbackRecentOpenTask = nil
                }
            }

            await prepareRecentLibraryNavigation(for: item)
            guard !Task.isCancelled,
                  playbackRecentOpenGeneration == generation,
                  currentPlaybackVideoPath.map({
                      URL(fileURLWithPath: $0).standardizedFileURL.path
                  }) == source.videoPath,
                  currentPlaybackSubtitlePath.map({
                      URL(fileURLWithPath: $0).standardizedFileURL.path
                  }) == source.subtitlePath,
                  currentPlaybackSubtitleFormat == source.subtitleFormat
            else {
                return
            }

            playbackRecentOpenTask = nil
            openLibraryVideo(
                item.libraryVideo,
                displayTitle: item.displayTitle,
                playbackReturnContextOnSuccessfulPlay: .recent
            )
        }
        return true
    }

    func cancelPlaybackRecentOpenTask() {
        guard playbackRecentOpenTask != nil else {
            return
        }
        playbackRecentOpenGeneration &+= 1
        playbackRecentOpenTask?.cancel()
        playbackRecentOpenTask = nil
    }

    @discardableResult
    func requestPlaybackLibraryPrimaryAction() -> Bool {
        guard let session = playback.subtitleFocusSession,
              session.selectedModule == .library,
              let libraryStore = session.libraryStore
        else {
            return false
        }
        switch libraryStore.level {
        case .folders:
            return session.enterSelectedLibraryFolder()
        case .folderDetail:
            guard let video = session.selectedLibraryPrimaryActionVideo() else {
                return false
            }
            return openPlaybackLibraryEpisodeFromOverlay(video)
        }
    }

    @discardableResult
    func openPlaybackLibraryEpisodeFromOverlay(
        _ requestedVideo: CompleteLibraryVideoPresentation
    ) -> Bool {
        guard let session = playback.subtitleFocusSession,
              session.selectedModule == .library,
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
            displayTitle: video.displayTitle,
            playbackReturnContextOnSuccessfulPlay: .libraryFolderDetail(
                folderPath: detail.folderPath
            )
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
            playCurrentCue: playPlaybackSubtitleFocusCurrentCue,
            openPlaylistItem: openPlaybackPlaylistItem,
            openShioriItem: openPlaybackShioriItem
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
            openShioriItem: openPlaybackShioriItem
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
            openShioriItem: openPlaybackShioriItem
        )
    }

    @discardableResult
    func executePlaybackSubtitleFocusAction(
        _ execution: PlaybackSubtitleFocusActionExecution,
        playCurrentCue: (PlaybackSubtitleFocusActionContext) -> Bool,
        openPlaylistItem: (PlaybackPlaylistItem) -> Void,
        openShioriItem: (PlaybackCueResultItem) -> Void
    ) -> Bool {
        guard let session = playback.subtitleFocusSession else {
            return false
        }
        return executePlaybackSubtitleFocusAction(
            execution,
            session: session,
            playCurrentCue: playCurrentCue,
            openPlaylistItem: openPlaylistItem,
            openShioriItem: openShioriItem
        )
    }

    private func executePlaybackSubtitleFocusAction(
        _ execution: PlaybackSubtitleFocusActionExecution,
        session: PlaybackSubtitleFocusSessionStore,
        playCurrentCue: (PlaybackSubtitleFocusActionContext) -> Bool,
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
        case .copyCueMarkdownLink:
            let copied: Bool
            if let cueID = execution.target.cueID {
                copied = PlaybackSubtitleFocusClipboard.copyMarkdownLink(
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
                finishPlaybackSearchHost(committingEmptyFilter: false)
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
        playbackSubtitleFocusActionTask = Task { @MainActor [weak self, weak session] in
            guard let self, let session else {
                return
            }

            do {
                let result = try await databaseReader.saveShiori(context: actionContext)
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
            reloadShioriListOverview()
            loadShioriTableRowsIfNeeded()
        }
        guard playbackSubtitleFocusActionGeneration == taskGeneration,
              playback.subtitleFocusSession === session,
              session.activeKeyboardAction == execution
        else {
            return
        }
        playbackSubtitleFocusActionTask = nil
        playback.playbackViewModel?.showShioriFeedback(
            result == .saved ? .saved : .alreadySaved
        )
        _ = session.finishKeyboardAction(execution)
    }

    private func copyPlaybackSubtitleFocusCueText(_ text: String) -> Bool {
        PlaybackSubtitleFocusClipboard.copy(text, to: .general)
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
        case .shiori(let shiori):
            let playlistScope: PlaybackPlaylistShioriScope?
            if let source = playback.playlistSource,
               case .shiori(let scope) = source.origin {
                playlistScope = scope
            } else {
                playlistScope = nil
            }
            openShiori(
                shiori,
                navigationScopeIDs: shioriPlaybackNavigationScopeIDs,
                playlistScope: playlistScope,
                playlistSelectedOrdinal: item.ordinal
            )
        }
    }

    private func openPlaybackShioriItem(_ item: PlaybackCueResultItem) {
        _ = dispatchPlaybackShioriOverlayItem(item) { shiori, scope in
            let playlistScope = scope.map {
                PlaybackPlaylistShioriScope.table(
                    PlaybackPlaylistShioriTableContext(
                        runID: self.shiori.tableResultSnapshotID,
                        searchText: self.shiori.tableSubmittedSearchText,
                        filterSet: self.shiori.tableFilterRules.subtitleSearchFilterSet,
                        totalCount: $0.count
                    )
                )
            }
            openShiori(
                shiori,
                navigationScopeIDs: scope,
                playlistScope: playlistScope,
                playlistSelectedOrdinal: item.ordinal,
                playbackReturnContextOnSuccessfulPlay: .shiori
            )
        }
    }

    @discardableResult
    func dispatchPlaybackShioriOverlayItem(
        _ item: PlaybackCueResultItem,
        open: (Shiori, [Int64]?) -> Void
    ) -> Bool {
        guard case .shiori(let shiori) = item.target else {
            return false
        }
        let resultIDs = self.shiori.tableResultShioriIDs.flatMap { shioriIDs in
            shioriIDs.count == self.shiori.tableResultRowCount
                ? shioriIDs
                : nil
        }
        open(shiori, resultIDs)
        return true
    }

    private func cancelPlaybackSubtitleFocusActionTask() {
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
        let subtitlePath = session.openSnapshot.source.subtitlePath
        let timestampMilliseconds = session.openSnapshot.timestampMilliseconds
        let token = session.token
        let databaseReader = playbackSubtitleFocusDatabaseReader
        let loadInitialSnapshot = initialSnapshotLoader ?? { subtitlePath, timestamp in
            try await databaseReader.initialSnapshot(
                subtitlePath: subtitlePath,
                timestampMilliseconds: timestamp
            )
        }

        playbackSubtitleFocusInitialLoadTask = Task { @MainActor [weak self, weak session] in
            guard let self, let session else {
                return
            }

            do {
                let snapshot = try await loadInitialSnapshot(
                    subtitlePath,
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
        let subtitlePath = session.openSnapshot.source.subtitlePath
        let token = session.token
        let databaseReader = playbackSubtitleFocusDatabaseReader
        let loadCompleteCueBatch = loader ?? { subtitlePath, totalCount in
            try await databaseReader.completeCueBatch(
                subtitlePath: subtitlePath,
                totalCount: totalCount
            )
        }
        playbackSubtitleFocusCompleteLoadTask = Task { @MainActor [weak self, weak session] in
            guard let self, let session else {
                return
            }

            do {
                let batch = try await loadCompleteCueBatch(
                    subtitlePath,
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
