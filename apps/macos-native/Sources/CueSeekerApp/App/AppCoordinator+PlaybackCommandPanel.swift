import AppKit
import CueSeekerCore
import Foundation

extension PlaybackCommandPanelPage {
    var diagnosticLabel: String {
        switch self {
        case .root:
            return "command_panel_root"
        case .searchResults:
            return "command_panel_search_results"
        case .recentVideos:
            return "command_panel_recent_videos"
        case .recentExcerpts:
            return "command_panel_recent_excerpts"
        }
    }
}

@MainActor
extension AppCoordinator {
    func copyPlaybackSelectedText(_ text: String) {
        let copied = CueClipboard.copy(text, to: .general)
        playback.playbackViewModel?
            .showSelectedTextCopyFeedback(copied: copied)
    }

    func searchPlaybackSelectedText(_ text: String) {
        _ = presentPlaybackCommandPanelSearch(
            query: text,
            startsSearch: true
        )
    }

    @discardableResult
    func presentPlaybackCommandPanel() -> Bool {
        let startedAt = DebugInteractionLatencyProbe.now()
        guard isPlaybackPageVisible else {
            return false
        }
        DebugInteractionLatencyProbe.beginNavigation(
            domain: "command_panel",
            from: "closed",
            to: PlaybackCommandPanelPage.root.diagnosticLabel,
            trigger: "open_command_panel",
            startedAt: startedAt
        )
        guard preparePlaybackCommandPanelPresentation() else {
            return false
        }

        guard var presentation = playback.commandPanelPresentation else {
            return false
        }
        let focusedCueText = playback.subtitleFocusSession?
            .focusedCueTextForCommandPanel
        presentation.page = .root
        presentation.query = settings.prefillCommandPanelWithFocusedCue
            ? SearchInputNormalizer.singleLine(focusedCueText ?? "")
            : ""
        presentation.selectedOrdinal = 0
        playback.presentCommandPanel(presentation)
        AppLogger.shared.info(
            .playback,
            "Command panel opened",
            fields: [("prefilled_query", presentation.query.isEmpty ? nil : presentation.query)]
        )
        if !presentation.query.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).isEmpty {
            startPlaybackCommandPanelLiveSearch(query: presentation.query)
        }
        preparePlaybackKeyboardFocus()
        DebugInteractionLatencyProbe.markNavigationSyncPrepFinished(domain: "command_panel")
        return true
    }

    @discardableResult
    func presentPlaybackCommandPanelSearch(
        query: String,
        startsSearch: Bool
    ) -> Bool {
        let startedAt = DebugInteractionLatencyProbe.now()
        let previousPageLabel = playback.commandPanelPresentation?.page.diagnosticLabel ?? "closed"
        let normalizedQuery = SearchInputNormalizer.singleLine(query)
        let trimmedQuery = normalizedQuery.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard isPlaybackPageVisible, !trimmedQuery.isEmpty else {
            return false
        }
        DebugInteractionLatencyProbe.beginNavigation(
            domain: "command_panel",
            from: previousPageLabel,
            to: PlaybackCommandPanelPage.searchResults.diagnosticLabel,
            trigger: "command_panel_search",
            startedAt: startedAt
        )
        guard preparePlaybackCommandPanelPresentation() else {
            return false
        }

        let normalizedFacetFilter =
            synchronizePlaybackCommandPanelSearchParameters()
        let shouldStartSearch = startsSearch
            && !hasReusablePlaybackCommandPanelSearch(
                for: trimmedQuery,
                facetFilter: normalizedFacetFilter,
                sortOrder: search.searchSortOrder,
                allowsDebouncing: false
            )
        search.updateQuery(trimmedQuery)
        search.updateActiveFilterSet(SubtitleSearchFilterSet())
        search.updateNavigationSnapshot(nil)
        if shouldStartSearch {
            startSearch(
                query: trimmedQuery,
                cursor: .start,
                appending: false,
                debounce: false
            )
        }

        guard var presentation = playback.commandPanelPresentation else {
            return false
        }
        presentation.page = .searchResults
        presentation.query = trimmedQuery
        presentation.selectedOrdinal = nil
        playback.presentCommandPanel(presentation)
        AppLogger.shared.info(
            .playback,
            "Command panel search opened",
            fields: [
                ("query", trimmedQuery),
                ("starts_search", "\(shouldStartSearch)")
            ]
        )
        synchronizePlaybackCommandPanelSearchResults()
        preparePlaybackKeyboardFocus()
        DebugInteractionLatencyProbe.markNavigationSyncPrepFinished(domain: "command_panel")
        return true
    }

    func updatePlaybackCommandPanelQuery(_ query: String) {
        guard let presentation = playback.commandPanelPresentation,
              presentation.page == .root
        else {
            return
        }
        let normalizedQuery = SearchInputNormalizer.singleLine(query)
        guard normalizedQuery != presentation.query else {
            return
        }
        var updated = presentation
        updated.query = normalizedQuery
        updated.selectedOrdinal = 0
        playback.presentCommandPanel(updated)
        startPlaybackCommandPanelLiveSearch(query: normalizedQuery)
    }

    private func startPlaybackCommandPanelLiveSearch(query: String) {
        let normalizedQuery = SearchInputNormalizer.singleLine(query)
        let trimmedQuery = normalizedQuery.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let normalizedFacetFilter =
            synchronizePlaybackCommandPanelSearchParameters()
        guard !hasReusablePlaybackCommandPanelSearch(
            for: trimmedQuery,
            facetFilter: normalizedFacetFilter,
            sortOrder: search.searchSortOrder,
            allowsDebouncing: true
        ) else {
            return
        }
        search.updateQuery(normalizedQuery)
        UIInvalidationProbe.mark(
            "ACTION UI.SearchQuery.changed",
            details: "length=\(search.searchQuery.count)"
        )
        search.updateActiveFilterSet(SubtitleSearchFilterSet())
        search.updateNavigationSnapshot(nil)
        startSearch(
            query: search.searchQuery,
            cursor: .start,
            appending: false,
            debounce: true
        )
    }

    private func synchronizePlaybackCommandPanelSearchParameters() -> CueFacetFilter {
        let normalizedFacetFilter = search.normalizedFacetFilter(
            search.searchFacetFilter
        )
        _ = search.updateSearchFacetFilter(normalizedFacetFilter)
        if settings.searchFacetFilter != normalizedFacetFilter {
            settings.searchFacetFilter = normalizedFacetFilter
        }
        if settings.searchSortOrder != search.searchSortOrder {
            settings.searchSortOrder = search.searchSortOrder
        }
        return normalizedFacetFilter
    }

    private func hasReusablePlaybackCommandPanelSearch(
        for trimmedQuery: String,
        facetFilter: CueFacetFilter,
        sortOrder: SearchSortOrder,
        allowsDebouncing: Bool
    ) -> Bool {
        guard !trimmedQuery.isEmpty,
              search.hasReusableQueryExecution,
              !search.hasMutatedSinceSearchSnapshot,
              search.searchQuery.trimmingCharacters(
                  in: .whitespacesAndNewlines
              ) == trimmedQuery,
              search.resultFacetFilter == facetFilter,
              search.resultSortOrder == sortOrder,
              search.resultFilterSet == SubtitleSearchFilterSet(),
              search.acceptsFolderScope(
                  indexing.selectedFolders,
                  generation: search.resultFolderScopeGeneration
              )
        else {
            return false
        }
        switch search.searchStatus {
        case .completed:
            return search.searchCountState == .exact
                && !search.isSearchDebouncing
        case .searching:
            return allowsDebouncing || !search.isSearchDebouncing
        case .idle, .failed:
            return false
        }
    }

    @discardableResult
    func submitPlaybackCommandPanelSearch() -> Bool {
        guard let presentation = playback.commandPanelPresentation,
              presentation.page == .root
        else {
            return false
        }
        let trimmedQuery = presentation.query.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !trimmedQuery.isEmpty else {
            return openSelectedPlaybackCommandPanelItem()
        }
        return presentPlaybackCommandPanelSearch(
            query: trimmedQuery,
            startsSearch: true
        )
    }

    @discardableResult
    func presentPlaybackCommandPanelPage(
        _ page: PlaybackCommandPanelPage
    ) -> Bool {
        let startedAt = DebugInteractionLatencyProbe.now()
        guard var presentation = playback.commandPanelPresentation,
              presentation.page == .root,
              page == .recentVideos || page == .recentExcerpts
        else {
            return false
        }
        DebugInteractionLatencyProbe.beginNavigation(
            domain: "command_panel",
            from: PlaybackCommandPanelPage.root.diagnosticLabel,
            to: page.diagnosticLabel,
            trigger: "command_panel_page_select",
            startedAt: startedAt
        )

        switch page {
        case .recentVideos:
            refreshTestRecentWatching()
        case .recentExcerpts:
            refreshExcerptOnReappearanceIfNeeded()
            loadExcerptListOverviewIfNeeded()
        case .root, .searchResults:
            return false
        }

        presentation.page = page
        presentation.selectedOrdinal =
            playbackCommandPanelItemCount(for: page) > 0 ? 0 : nil
        playback.presentCommandPanel(presentation)
        preparePlaybackKeyboardFocus()
        DebugInteractionLatencyProbe.markNavigationSyncPrepFinished(domain: "command_panel")
        return true
    }

    @discardableResult
    func movePlaybackCommandPanelSelection(_ offset: Int) -> Bool {
        guard var presentation = playback.commandPanelPresentation else {
            return false
        }
        let itemCount = playbackCommandPanelItemCount(for: presentation.page)
        guard itemCount > 0 else {
            presentation.selectedOrdinal = nil
            playback.presentCommandPanel(presentation)
            return true
        }

        if presentation.page == .searchResults {
            let current = playback.commandPanelSearchWindow?
                .selectedOrdinal ?? 0
            let target = min(max(0, current + offset), itemCount - 1)
            return playback.restoreCommandPanelSearchSelection(at: target)
        }

        PointerHoverScrollState.shared.noteSelectionMovedByKeyboardOrController()
        let current = presentation.selectedOrdinal ?? 0
        let target = min(max(0, current + offset), itemCount - 1)
        presentation.selectedOrdinal = target
        playback.presentCommandPanel(presentation)
        return true
    }

    /// Moves the Command Panel selection onto the pointer. Nothing scrolls: the
    /// item is already under the cursor.
    func selectPlaybackCommandPanelItem(at ordinal: Int) {
        guard var presentation = playback.commandPanelPresentation,
              presentation.selectedOrdinal != ordinal,
              ordinal >= 0,
              ordinal < playbackCommandPanelItemCount(for: presentation.page)
        else {
            return
        }
        presentation.selectedOrdinal = ordinal
        playback.presentCommandPanel(presentation)
    }

    func updatePlaybackCommandPanelRecentCardGridLayout(
        columnCount: Int
    ) {
        playback.updateCommandPanelRecentCardGridLayout(
            columnCount: columnCount
        )
    }

    @discardableResult
    func movePlaybackCommandPanelRecentCardSelection(
        _ direction: PlaybackMediaSelectionDirection
    ) -> Bool {
        guard var presentation = playback.commandPanelPresentation,
              presentation.page.showsRecentCardGrid
        else {
            return false
        }
        PointerHoverScrollState.shared.noteSelectionMovedByKeyboardOrController()
        let itemIDs = playbackCommandPanelRecentCardItemIDs(
            for: presentation.page
        )
        guard let selectedOrdinal = presentation.selectedOrdinal,
              itemIDs.indices.contains(selectedOrdinal)
        else {
            synchronizePlaybackCommandPanelSelection()
            return true
        }
        guard let targetOrdinal = PlaybackMediaSelectionStore.targetIndex(
            from: selectedOrdinal,
            direction: direction,
            orderedItemIDs: itemIDs,
            availableItemIDs: Set(itemIDs),
            columnCount: playback.commandPanelRecentCardColumnCount,
            sectionItemCounts: playbackCommandPanelRecentCardSectionItemCounts(
                for: presentation.page
            )
        ) else {
            return true
        }

        presentation.selectedOrdinal = targetOrdinal
        playback.noteCommandPanelRecentCardSelectionMoved()
        playback.presentCommandPanel(presentation)
        return true
    }

    func playbackCommandPanelRecentCardItemIDs(
        for page: PlaybackCommandPanelPage
    ) -> [String] {
        switch page {
        case .recentVideos:
            return playbackCommandPanelRecentVideos.map(\.id)
        case .recentExcerpts:
            return playbackCommandPanelRecentExcerpts.map { String($0.id) }
        case .root, .searchResults:
            return []
        }
    }

    private func playbackCommandPanelRecentCardSectionItemCounts(
        for page: PlaybackCommandPanelPage
    ) -> [Int] {
        switch page {
        case .recentVideos:
            return RecentTimeSection.group(
                playbackCommandPanelRecentVideos,
                timestamp: \.updatedAt
            ).map(\.items.count)
        case .recentExcerpts:
            return RecentTimeSection.group(
                playbackCommandPanelRecentExcerpts,
                timestamp: \.list.recentPlayedAt
            ).map(\.items.count)
        case .root, .searchResults:
            return []
        }
    }

    func synchronizePlaybackCommandPanelSelection() {
        guard var presentation = playback.commandPanelPresentation else {
            return
        }
        if presentation.page == .searchResults {
            synchronizePlaybackCommandPanelSearchResults()
            return
        }
        let itemCount = playbackCommandPanelItemCount(for: presentation.page)
        presentation.selectedOrdinal = itemCount > 0
            ? min(max(0, presentation.selectedOrdinal ?? 0), itemCount - 1)
            : nil
        playback.presentCommandPanel(presentation)
    }

    @discardableResult
    func openSelectedPlaybackCommandPanelItem() -> Bool {
        guard let presentation = playback.commandPanelPresentation else {
            return false
        }

        switch presentation.page {
        case .root:
            guard let selectedOrdinal = presentation.selectedOrdinal else {
                return false
            }
            let hasQuery = !presentation.query.trimmingCharacters(
                in: .whitespacesAndNewlines
            ).isEmpty
            if hasQuery, selectedOrdinal == 0 {
                return presentPlaybackCommandPanelSearch(
                    query: presentation.query,
                    startsSearch: true
                )
            }
            let recentOrdinal = selectedOrdinal - (hasQuery ? 1 : 0)
            if recentOrdinal == 0 {
                return presentPlaybackCommandPanelPage(.recentVideos)
            }
            if recentOrdinal == 1 {
                return presentPlaybackCommandPanelPage(.recentExcerpts)
            }
            return false
        case .searchResults:
            guard let selectedOrdinal = playback.commandPanelSearchWindow?
                .selectedOrdinal
            else {
                return false
            }
            return requestPlaybackCommandPanelSearchAction(
                .playFromThisCue,
                ordinal: selectedOrdinal
            )
        case .recentVideos:
            guard let selectedOrdinal = presentation.selectedOrdinal else {
                return false
            }
            return openPlaybackCommandPanelRecentVideo(
                at: selectedOrdinal
            )
        case .recentExcerpts:
            guard let selectedOrdinal = presentation.selectedOrdinal else {
                return false
            }
            return openPlaybackCommandPanelRecentExcerpt(
                at: selectedOrdinal
            )
        }
    }

    func synchronizePlaybackCommandPanelSearchResults() {
        guard let presentation = playback.commandPanelPresentation,
              presentation.page == .searchResults,
              playback.commandPanelHeldPage == nil
        else {
            return
        }

        let results = search.searchResultsPrefix(
            PlaybackCommandPanelPresentation.previewLimit
        )
        let previewCount = results.count
        let resultListGeneration = search.resultListGeneration
        let isSameGeneration =
            playback.commandPanelSearchResultListGeneration
                == resultListGeneration
        let selectedOrdinal: Int?
        if previewCount == 0 {
            selectedOrdinal = nil
        } else if isSameGeneration,
                  let current = playback.commandPanelSearchWindow?
                      .selectedOrdinal {
            selectedOrdinal = min(max(0, current), previewCount - 1)
        } else {
            selectedOrdinal = 0
        }
        var updated = presentation
        updated.selectedOrdinal = nil
        if updated != presentation {
            playback.presentCommandPanel(updated)
        }
        playback.synchronizeCommandPanelSearchPreview(
            results: results,
            selectedOrdinal: selectedOrdinal,
            resultListGeneration: resultListGeneration
        )
    }

    @discardableResult
    func commitPlaybackCommandPanelSearchReelSelection(
        _ commit: PlaybackVirtualReelSelectionCommit
    ) -> Bool {
        guard playback.commandPanelPresentation?.page == .searchResults
        else {
            return false
        }
        return playback.commitCommandPanelSearchSelection(commit)
    }

    @discardableResult
    func requestPlaybackCommandPanelSearchAction(
        _ action: PlaybackSubtitleFocusAction,
        ordinal requestedOrdinal: Int? = nil
    ) -> Bool {
        // The result is the one the page shows, which a database change may
        // have left behind the search results.
        guard let presentation = playback.commandPanelPresentation,
              presentation.page == .searchResults,
              let ordinal = requestedOrdinal
                ?? playback.commandPanelSearchWindow?.selectedOrdinal,
              ordinal >= 0,
              ordinal < PlaybackCommandPanelPresentation.previewLimit,
              let item = playback.commandPanelSearchWindow?.item(at: ordinal),
              case .search(let result) = item.target
        else {
            return false
        }

        let isInLibrary = isCueInLibrary(result.entryID)
        switch action {
        case .excerpt:
            if playback.excerptDestinationMenu?.surface != .commandPanel,
               !isInLibrary {
                playback.playbackViewModel?.showNotInLibraryFeedback()
                return true
            }
            togglePlaybackExcerptDestinationMenu(
                surface: .commandPanel,
                context: item.actionContext
            )
        case .copyCueText:
            let copied = CueClipboard.copy(
                result.content,
                to: .general
            )
            playback.playbackViewModel?
                .showSubtitleCopyFeedback(copied: copied)
        case .copyCueMarkdownLink:
            guard isInLibrary else {
                playback.playbackViewModel?.showNotInLibraryFeedback()
                return true
            }
            let copied = CueClipboard.copyDeepLink(
                cueText: result.content,
                cueID: result.entryID,
                to: .general
            )
            playback.playbackViewModel?
                .showSubtitleMarkdownLinkCopyFeedback(copied: copied)
        case .playFromThisCue:
            guard isInLibrary else {
                showPlaybackItemNotInLibrary()
                return true
            }
            guard dismissPlaybackCommandPanelForAction() else {
                return false
            }
            playback.clearError(on: .notInLibrary)
            openSearchResult(
                result,
                playbackSearchPromotion: PlaybackSearchPromotion(
                    query: search.searchQuery,
                    scopePaths: indexing.selectedFolders.map(\.mediaPath),
                    selectedOrdinal: ordinal
                )
            )
        }
        return true
    }

    @discardableResult
    func openPlaybackCommandPanelRecentVideo(at ordinal: Int) -> Bool {
        let items = playbackCommandPanelRecentVideos
        guard playback.commandPanelPresentation?.page == .recentVideos,
              items.indices.contains(ordinal)
        else {
            return false
        }
        let item = items[ordinal]
        guard !libraryHasLost(videoPath: item.libraryVideo.videoPath) else {
            showPlaybackItemNotInLibrary()
            return true
        }
        guard dismissPlaybackCommandPanelForAction() else {
            return false
        }
        playback.clearError(on: .notInLibrary)
        Task { @MainActor [weak self] in
            guard let self else {
                return
            }
            await prepareRecentLibraryNavigation(for: item)
            openLibraryVideo(
                item.libraryVideo,
                displayTitle: item.displayTitle
            )
        }
        return true
    }

    @discardableResult
    func openPlaybackCommandPanelRecentExcerpt(at ordinal: Int) -> Bool {
        let summaries = playbackCommandPanelRecentExcerpts
        guard playback.commandPanelPresentation?.page == .recentExcerpts,
              summaries.indices.contains(ordinal)
        else {
            return false
        }
        let summary = summaries[ordinal]
        guard (try? excerptDatabase?.excerpts(listID: summary.list.id))?
            .contains(where: \.isValid) == true
        else {
            playback.playbackViewModel?.showNoAvailableNavigationFeedback(
                direction: nil,
                text: L("playback.hud.no_available_results")
            )
            return true
        }
        guard dismissPlaybackCommandPanelForAction() else {
            return false
        }
        playback.clearError(on: .notInLibrary)
        openRecentExcerpt(summary)
        return true
    }

    @discardableResult
    func returnPlaybackCommandPanelToRoot() -> Bool {
        let startedAt = DebugInteractionLatencyProbe.now()
        guard let presentation = playback.commandPanelPresentation,
              presentation.page != .root
        else {
            return false
        }
        DebugInteractionLatencyProbe.beginNavigation(
            domain: "command_panel",
            from: presentation.page.diagnosticLabel,
            to: PlaybackCommandPanelPage.root.diagnosticLabel,
            trigger: "command_panel_back",
            startedAt: startedAt
        )
        var updated = presentation
        updated.page = .root
        updated.selectedOrdinal = 0
        playback.presentCommandPanel(updated)
        preparePlaybackKeyboardFocus()
        DebugInteractionLatencyProbe.markNavigationSyncPrepFinished(domain: "command_panel")
        return true
    }

    @discardableResult
    func dismissPlaybackCommandPanelFromUser() -> Bool {
        let startedAt = DebugInteractionLatencyProbe.now()
        guard let presentation = playback.dismissCommandPanel() else {
            return false
        }
        if presentation.resumesPlaybackOnDismiss,
           playback.subtitleFocusSession == nil {
            resumePlayback()
        }
        DebugInteractionLatencyProbe.completeImmediateNavigation(
            domain: "command_panel",
            from: presentation.page.diagnosticLabel,
            to: "closed",
            trigger: "command_panel_dismiss",
            startedAt: startedAt
        )
        return true
    }

    private func dismissPlaybackCommandPanelForAction() -> Bool {
        guard playback.dismissCommandPanel() != nil else {
            return false
        }
        return true
    }

    func playbackCommandPanelItemCount(
        for page: PlaybackCommandPanelPage
    ) -> Int {
        switch page {
        case .root:
            guard let query = playback.commandPanelPresentation?.query else {
                return 0
            }
            return query.trimmingCharacters(
                in: .whitespacesAndNewlines
            ).isEmpty ? 2 : 3
        case .searchResults:
            return playback.commandPanelSearchWindow?.snapshot.totalCount ?? 0
        case .recentVideos:
            return playbackCommandPanelRecentVideos.count
        case .recentExcerpts:
            return playbackCommandPanelRecentExcerpts.count
        }
    }

    /// What the Recent pages list: what the page kept through a database
    /// change, or what the library has now.
    var playbackCommandPanelRecentVideos: [RecentLibraryWatchingPresentation] {
        if case .recentVideos(let items) = playback.commandPanelHeldPage {
            return items
        }
        return library.testRecentWatchingItems
    }

    var playbackCommandPanelRecentExcerpts: [ExcerptListSummary] {
        if case .recentExcerpts(let summaries) = playback.commandPanelHeldPage {
            return summaries
        }
        return excerpt.recentListSummaries
    }

    var isPlaybackCommandPanelRecentVideosLoading: Bool {
        if case .recentVideos = playback.commandPanelHeldPage {
            return false
        }
        if library.testRecentWatchingStatus == .loading || recentNeedsReloadAfterIndexedMutation {
            return true
        }
        if indexing.selectedFolders.isEmpty {
            return false
        }
        return !Self.isCommandPanelLibraryStatusResolved(library.testRecentWatchingStatus)
            && library.testRecentWatchingItems.isEmpty
    }

    var isPlaybackCommandPanelRecentExcerptsLoading: Bool {
        if case .recentExcerpts = playback.commandPanelHeldPage {
            return false
        }
        if excerpt.listOverviewTask != nil || excerptNeedsReloadAfterIndexedContentMutation {
            return true
        }
        return !excerpt.hasLoadedListOverview && excerpt.recentListSummaries.isEmpty
    }

    func isPlaybackCommandPanelPageReadyForPresentation(
        _ page: PlaybackCommandPanelPage
    ) -> Bool {
        switch page {
        case .root, .searchResults:
            return true
        case .recentVideos:
            if case .recentVideos(let heldItems) = playback.commandPanelHeldPage {
                return Self.areCommandPanelCoversReady(
                    firstScreenCommandPanelRecentVideoCoverKeys(from: heldItems)
                )
            }
            guard !isPlaybackCommandPanelRecentVideosLoading else {
                return false
            }
            return Self.areCommandPanelCoversReady(
                firstScreenCommandPanelRecentVideoCoverKeys(
                    from: playbackCommandPanelRecentVideos
                )
            )
        case .recentExcerpts:
            if case .recentExcerpts(let heldSummaries) = playback.commandPanelHeldPage {
                return Self.areCommandPanelCoversReady(
                    firstScreenCommandPanelRecentExcerptCoverKeys(from: heldSummaries)
                )
            }
            guard !isPlaybackCommandPanelRecentExcerptsLoading else {
                return false
            }
            return Self.areCommandPanelCoversReady(
                firstScreenCommandPanelRecentExcerptCoverKeys(
                    from: playbackCommandPanelRecentExcerpts
                )
            )
        }
    }

    @discardableResult
    func preparePlaybackCommandPanelPageForPresentation(
        _ page: PlaybackCommandPanelPage
    ) async -> (dataReadyAt: UInt64, coverStats: LibraryCoverPrewarmStats) {
        switch page {
        case .root, .searchResults:
            return (DebugInteractionLatencyProbe.now(), .zero)
        case .recentVideos:
            if playback.commandPanelHeldPage == nil {
                if library.testRecentWatchingStatus != .loading,
                   isPlaybackCommandPanelRecentVideosLoading
                {
                    refreshRecentOnReappearanceIfNeeded()
                    hydrateTestRecentWatchingAsync()
                }
                await testRecentWatchingTask?.value
                guard !Task.isCancelled else {
                    return (DebugInteractionLatencyProbe.now(), .zero)
                }
                if playback.commandPanelPresentation?.page == .recentVideos {
                    synchronizePlaybackCommandPanelSelection()
                }
            }
            let dataReadyAt = DebugInteractionLatencyProbe.now()
            let stats = await LibraryCoverImagePipeline.shared.prewarm(
                keys: firstScreenCommandPanelRecentVideoCoverKeys(
                    from: playbackCommandPanelRecentVideos
                )
            )
            return (dataReadyAt, stats)
        case .recentExcerpts:
            if playback.commandPanelHeldPage == nil {
                refreshExcerptOnReappearanceIfNeeded()
                loadExcerptListOverviewIfNeeded()
                await excerpt.listOverviewTask?.value
                guard !Task.isCancelled else {
                    return (DebugInteractionLatencyProbe.now(), .zero)
                }
                if playback.commandPanelPresentation?.page == .recentExcerpts {
                    synchronizePlaybackCommandPanelSelection()
                }
            }
            let dataReadyAt = DebugInteractionLatencyProbe.now()
            let stats = await LibraryCoverImagePipeline.shared.prewarm(
                keys: firstScreenCommandPanelRecentExcerptCoverKeys(
                    from: playbackCommandPanelRecentExcerpts
                )
            )
            return (dataReadyAt, stats)
        }
    }

    func cachedCommandPanelCoverStats(
        for page: PlaybackCommandPanelPage
    ) -> LibraryCoverPrewarmStats {
        let keys: [LibraryCoverImageKey]
        switch page {
        case .root, .searchResults:
            return .zero
        case .recentVideos:
            keys = firstScreenCommandPanelRecentVideoCoverKeys(
                from: playbackCommandPanelRecentVideos
            )
        case .recentExcerpts:
            keys = firstScreenCommandPanelRecentExcerptCoverKeys(
                from: playbackCommandPanelRecentExcerpts
            )
        }
        let boundedKeys = LibraryCoverImagePipeline.boundedUniqueKeys(from: keys)
        let hits = boundedKeys.filter {
            LibraryCoverImagePipeline.shared.isReadyForPresentation(for: $0)
        }.count
        return LibraryCoverPrewarmStats(
            totalCount: boundedKeys.count,
            cacheHitCount: hits,
            decodedCount: 0,
            elapsedMilliseconds: 0
        )
    }

    private static func isCommandPanelLibraryStatusResolved(
        _ status: LibraryStatus
    ) -> Bool {
        switch status {
        case .completed, .failed:
            return true
        case .idle, .loading:
            return false
        }
    }

    private static func areCommandPanelCoversReady(
        _ keys: [LibraryCoverImageKey]
    ) -> Bool {
        let boundedKeys = LibraryCoverImagePipeline.boundedUniqueKeys(from: keys)
        return boundedKeys.allSatisfy {
            LibraryCoverImagePipeline.shared.isReadyForPresentation(for: $0)
        }
    }

    private func firstScreenCommandPanelRecentVideoCoverKeys(
        from items: [RecentLibraryWatchingPresentation]
    ) -> [LibraryCoverImageKey] {
        let orderedItems = RecentTimeSection.group(
            items,
            timestamp: \.updatedAt
        ).flatMap(\.items)
        return LibraryCoverImagePipeline.boundedUniqueKeys(
            from: orderedItems.compactMap {
                LibraryCoverImageKey.current(
                    path: $0.coverPath,
                    revision: $0.coverRevision
                )
            }
        )
    }

    private func firstScreenCommandPanelRecentExcerptCoverKeys(
        from summaries: [ExcerptListSummary]
    ) -> [LibraryCoverImageKey] {
        let orderedItems = RecentTimeSection.group(
            summaries,
            timestamp: \.list.recentPlayedAt
        ).flatMap(\.items)
        return LibraryCoverImagePipeline.boundedUniqueKeys(
            from: orderedItems.compactMap { summary in
                guard let path = summary.list.coverPath, !path.isEmpty else {
                    return nil
                }
                return LibraryCoverImageKey(path: path, revision: path)
            }
        )
    }

    private func preparePlaybackCommandPanelPresentation() -> Bool {
        if playback.commandPanelPresentation != nil {
            return true
        }
        let wasPlaying = playback.playbackViewModel?.isPlaying == true
        guard suspendPlaybackForModalPresentation(
            wasPlaying: wasPlaying
        ) else {
            return false
        }
        playback.presentCommandPanel(
            PlaybackCommandPanelPresentation(
                page: .root,
                query: "",
                selectedOrdinal: 0,
                resumesPlaybackOnDismiss:
                    playback.subtitleFocusSession == nil && wasPlaying
            )
        )
        return true
    }
}
