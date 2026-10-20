import AppKit
import CueSeekerCore
import Foundation

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
        guard isPlaybackPageVisible else {
            return false
        }
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
        preparePlaybackKeyboardFocus()
        return true
    }

    @discardableResult
    func presentPlaybackCommandPanelSearch(
        query: String,
        startsSearch: Bool
    ) -> Bool {
        let normalizedQuery = SearchInputNormalizer.singleLine(query)
        let trimmedQuery = normalizedQuery.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard isPlaybackPageVisible, !trimmedQuery.isEmpty else {
            return false
        }
        guard preparePlaybackCommandPanelPresentation() else {
            return false
        }

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
        search.updateQuery(trimmedQuery)
        search.updateActiveFilterSet(SubtitleSearchFilterSet())
        search.updateNavigationSnapshot(nil)
        if startsSearch {
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
        synchronizePlaybackCommandPanelSearchResults()
        preparePlaybackKeyboardFocus()
        return true
    }

    func updatePlaybackCommandPanelQuery(_ query: String) {
        guard let presentation = playback.commandPanelPresentation,
              presentation.page == .root
        else {
            return
        }
        var updated = presentation
        updated.query = SearchInputNormalizer.singleLine(query)
        updated.selectedOrdinal = 0
        playback.presentCommandPanel(updated)
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
        guard var presentation = playback.commandPanelPresentation,
              presentation.page == .root,
              page == .recentVideos || page == .recentExcerpts
        else {
            return false
        }

        switch page {
        case .recentVideos:
            refreshTestRecentWatching()
        case .recentExcerpts:
            reloadExcerptListOverview()
        case .root, .searchResults:
            return false
        }

        presentation.page = page
        presentation.selectedOrdinal =
            playbackCommandPanelItemCount(for: page) > 0 ? 0 : nil
        playback.presentCommandPanel(presentation)
        preparePlaybackKeyboardFocus()
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
        columnCount: Int,
        itemFramesByID: [String: CGRect]
    ) {
        playback.updateCommandPanelRecentCardGridLayout(
            columnCount: columnCount,
            itemFramesByID: itemFramesByID
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
            itemFramesByID: playback.commandPanelRecentCardItemFramesByID
        ) else {
            return true
        }

        presentation.selectedOrdinal = targetOrdinal
        playback.presentCommandPanel(presentation)
        return true
    }

    private func playbackCommandPanelRecentCardItemIDs(
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

        let results = search.searchResults
        let previewCount = min(
            results.count,
            PlaybackCommandPanelPresentation.previewLimit
        )
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
        playback.presentCommandPanel(updated)
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
        guard let presentation = playback.commandPanelPresentation,
              presentation.page != .root
        else {
            return false
        }
        var updated = presentation
        updated.page = .root
        updated.selectedOrdinal = 0
        playback.presentCommandPanel(updated)
        preparePlaybackKeyboardFocus()
        return true
    }

    @discardableResult
    func dismissPlaybackCommandPanelFromUser() -> Bool {
        guard let presentation = playback.dismissCommandPanel() else {
            return false
        }
        if presentation.resumesPlaybackOnDismiss,
           playback.subtitleFocusSession == nil {
            resumePlayback()
        }
        return true
    }

    private func dismissPlaybackCommandPanelForAction() -> Bool {
        guard playback.dismissCommandPanel() != nil else {
            return false
        }
        return true
    }

    private func playbackCommandPanelItemCount(
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
