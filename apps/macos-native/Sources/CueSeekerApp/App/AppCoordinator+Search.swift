import Foundation
import CueSeekerCore

@MainActor
extension AppCoordinator {
    func updateSearchQuery(_ query: String) {
        UIInvalidationProbe.mark(
            "ACTION UI.SearchQuery.changed",
            details: "length=\(query.count)"
        )
        search.updateQuery(query)
        search.updateActiveFilterSet(SubtitleSearchFilterSet())
        startSearch(query: query, cursor: .start, appending: false, debounce: true)
    }

    func activatePlaybackSearchHost() {
        guard !search.isPlaybackTemporaryFilterActive else {
            return
        }

        startSearch(
            query: search.searchQuery,
            cursor: .start,
            appending: false,
            debounce: false,
            filterSetOverride: SubtitleSearchFilterSet()
        )
        search.activatePlaybackTemporaryFilter()
    }

    func updatePlaybackSearchQuery(_ query: String) {
        UIInvalidationProbe.mark(
            "ACTION UI.PlaybackSearchQuery.changed",
            details: "length=\(query.count)"
        )
        search.updateQuery(query)
        if search.isPlaybackTemporaryFilterActive {
            startSearch(
                query: query,
                cursor: .start,
                appending: false,
                debounce: true,
                filterSetOverride: SubtitleSearchFilterSet()
            )
        } else {
            activatePlaybackSearchHost()
        }
    }

    func finishPlaybackSearchHost(committingEmptyFilter: Bool) {
        guard let restoreFilterSet = search.finishPlaybackTemporaryFilter(
            committingEmptyFilter: committingEmptyFilter
        ) else {
            return
        }
        startSearch(
            query: search.searchQuery,
            cursor: .start,
            appending: false,
            debounce: false,
            filterSetOverride: restoreFilterSet
        )
    }

    func updateSearchFilterSet(_ filterSet: SubtitleSearchFilterSet) {
        let previousSignature = search.activeFilterSetSignature
        search.updateActiveFilterSet(filterSet)

        guard previousSignature != filterSet.cacheSignature else {
            return
        }

        refreshCurrentSearch(clearExistingResults: true)
    }

    func submitSearch(_ query: String) {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        UIInvalidationProbe.mark(
            "ACTION UI.Search.submitted",
            details: "length=\(trimmedQuery.count)"
        )
        if playback.playbackViewModel?.isPlaying == true {
            pausePlayback()
        }
        workbenchLayout.selectPanelMode(.search)
        search.updateQuery(trimmedQuery)
        search.updateActiveFilterSet(SubtitleSearchFilterSet())
        search.updateNavigationSnapshot(nil)
        startSearch(query: trimmedQuery, cursor: .start, appending: false, debounce: false)
    }

    func openSearchResultContext(_ result: SubtitleSearchResult) {
        openCueContextSearch(
            displayTitle: result.displayTitle,
            subtitlePath: result.subtitlePath,
            targetCueID: result.entryID
        )
    }

    func openShioriContext(_ item: Shiori, displayTitle: String) {
        guard item.isValid else {
            return
        }
        let targetCueID = shiori.residentRelations
            .first { $0.id == item.id }?
            .cueID
            ?? {
                guard let database = shioriDatabase else { return nil }
                do {
                    return try database.shioriRelation(id: item.id)?.cueID
                } catch {
                    print("Failed to resolve Shiori context cue: \(error)")
                    return nil
                }
            }()

        guard let targetCueID else {
            return
        }

        openCueContextSearch(
            displayTitle: displayTitle,
            subtitlePath: item.subtitlePath,
            targetCueID: targetCueID
        )
    }

    func openLibraryVideoContext(_ video: LibraryVideo, displayTitle: String) {
        do {
            guard let targetCueID = try search.firstCueID(
                forSubtitleFile: URL(fileURLWithPath: video.subtitlePath)
            ) else {
                return
            }
            let contextTitle = displayTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? video.videoName
                : displayTitle
            openCueContextSearch(
                displayTitle: contextTitle,
                subtitlePath: video.subtitlePath,
                targetCueID: targetCueID
            )
        } catch {
            print("Failed to open Library video context: \(error)")
        }
    }

    func openCueContextSearch(
        displayTitle: String,
        subtitlePath: String,
        targetCueID: Int64
    ) {
        let trimmedDisplayTitle = displayTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedDisplayTitle.isEmpty,
              !subtitlePath.isEmpty
        else {
            return
        }

        UIInvalidationProbe.mark(
            "ACTION UI.CueContext.opened",
            details: "hasTarget=true"
        )
        let request = CueContextSearchRequest(
            displayTitle: trimmedDisplayTitle,
            subtitlePath: subtitlePath,
            targetCueID: targetCueID
        )
        search.updateContextRequest(request)
        workbenchLayout.selectPanelMode(.search)
    }

    func loadMoreSearchResultsIfNeeded(currentResult result: SubtitleSearchResult) {
        guard search.hasMoreSearchResults, !search.isSearching else {
            return
        }

        guard let index = search.searchResults.firstIndex(where: { $0.entryID == result.entryID }),
              index >= search.searchResults.count - SearchStore.searchPrefetchThreshold
        else {
            return
        }

        loadMoreSearchResultsIfNeeded()
    }

    func loadMoreSearchResultsIfNeeded() {
        guard search.hasMoreSearchResults, !search.isSearching else {
            return
        }

        guard let cursor = search.nextGlobalCursor else {
            return
        }

        startSearch(
            query: search.searchQuery,
            cursor: cursor,
            appending: true,
            debounce: false
        )
    }

    var searchNavigationTotalCount: Int {
        max(
            search.searchNavigationSnapshot?.totalCount ?? 0,
            search.searchResultTotalCount,
            search.searchResults.count
        )
    }

    func startSearch(
        query: String,
        cursor: SubtitleSearchCursor,
        appending: Bool,
        debounce: Bool,
        urlSchemeIntentID: UUID? = nil,
        filterSetOverride: SubtitleSearchFilterSet? = nil,
        folderScopeOverride: [URL]? = nil
    ) {
        if pendingURLSchemeDirectPlayIntent?.id != urlSchemeIntentID {
            pendingURLSchemeDirectPlayIntent = nil
        }

        let folders = folderScopeOverride ?? indexing.selectedFolders
        let languageFilter = SubtitleSearchLanguageFilter.all
        let watchStateFilter = SubtitleSearchWatchStateFilter.all
        search.startSearch(
            query: query,
            cursor: cursor,
            appending: appending,
            debounce: debounce,
            folders: folders,
            languageFilter: languageFilter,
            watchStateFilter: watchStateFilter,
            databaseIsCompacting: indexing.databaseMaintenanceStatus.isCompacting,
            e2eLoggingEnabled: settings.searchE2ELoggingEnabled,
            shouldClearSelectionWhenUnavailable:
                activePlaybackSource != .search || !isPlaybackPageVisible,
            filterSetOverride: filterSetOverride,
            probeScope: uiProbeScope,
            isContextCurrent: { [weak self] in
                guard let self else { return false }
                return self.indexing.selectedFolders == folders
            },
            onResultsChanged: { [weak self] generation in
                self?.refreshSearchPlaybackPlaylistSource(
                    resultListGeneration: generation
                )
            },
            onFirstPageResolved: { [weak self] result in
                guard let self else { return false }
                return self.resolveURLSchemeDirectPlayIntent(
                    id: urlSchemeIntentID,
                    firstPageResult: result
                )
            }
        )
    }

    func refreshSearchNavigationSnapshot() {
        loadSearchNavigationSnapshot(opening: nil)
    }

    func openAdjacentSearchResult(_ direction: SearchResultNavigationDirection) {
        guard !isCueDeepLinkPlaybackSource else {
            playback.playbackViewModel?.showSearchNavigationFeedback(
                direction: direction,
                hasResult: false
            )
            return
        }
        if let context = activePlaybackSearchPlaylistContext {
            openAdjacentPlaybackSearchPlaylistResult(
                direction,
                context: context
            )
            return
        }
        loadSearchNavigationSnapshot(opening: direction)
    }

    func refreshCurrentSearch(
        clearExistingResults: Bool = false,
        folderScopeOverride: [URL]? = nil
    ) {
        guard !search.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        if clearExistingResults {
            let releasedRows = search.clearResults()
            AppMemoryPressureRelief.relieveAfterLargeResultRelease(estimatedReleasedRows: releasedRows)
        }

        guard let folderScopeOverride else {
            updateSearchQuery(search.searchQuery)
            return
        }
        startSearch(
            query: search.searchQuery,
            cursor: .start,
            appending: false,
            debounce: true,
            folderScopeOverride: folderScopeOverride
        )
    }

    func refreshSearchForLibraryWatchStateChange() {
        search.reloadEmptySearchFacetDistribution()

        let query = search.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return
        }

        if search.isPlaybackTemporaryFilterActive {
            startSearch(
                query: query,
                cursor: .start,
                appending: false,
                debounce: false,
                filterSetOverride: SubtitleSearchFilterSet()
            )
        } else {
            refreshCurrentSearch()
        }
    }

    func loadSearchNavigationSnapshot(opening direction: SearchResultNavigationDirection?) {
        search.cancelNavigationTask()

        let trimmedQuery = search.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !indexing.selectedFolders.isEmpty,
              search.isDatabaseAvailable
        else {
            search.updateNavigationSnapshot(nil)
            if let direction {
                playback.playbackViewModel?.showSearchNavigationFeedback(direction: direction, hasResult: false)
            }
            return
        }

        let anchor = currentSearchNavigationAnchor()
        let panelRadius = Self.searchNavigationPanelRadius
        if trimmedQuery.isEmpty {
            loadAllCueSearchNavigationSnapshot(
                opening: direction,
                anchor: anchor,
                radius: panelRadius
            )
            return
        }

        let filterSet = search.resultFilterSet
        let filterSignature = filterSet.cacheSignature
        search.replaceNavigationTask(Task { [weak self] in
            guard !Task.isCancelled, let self else {
                return
            }
            guard self.search.resultFilterSetSignature == filterSignature
            else {
                return
            }

            guard let resolvedSnapshot = self.loadedSearchNavigationSnapshot(
                anchor: anchor,
                radius: panelRadius
            ) else {
                if let direction {
                    self.playback.playbackViewModel?.showSearchNavigationFeedback(
                        direction: direction,
                        hasResult: false
                    )
                }
                return
            }

            self.applySearchNavigationSnapshot(resolvedSnapshot)
            let target: SubtitleSearchResult? = switch direction {
            case .previous:
                resolvedSnapshot.previous
            case .next:
                resolvedSnapshot.next
            case nil:
                nil
            }

            if let target, let direction {
                self.playback.playbackViewModel?.showSearchNavigationFeedback(direction: direction, hasResult: true)
                self.openSearchResult(target)
            } else if let direction {
                self.playback.playbackViewModel?.showSearchNavigationFeedback(direction: direction, hasResult: false)
            }
        })
    }

    private func loadAllCueSearchNavigationSnapshot(
        opening direction: SearchResultNavigationDirection?,
        anchor: SearchNavigationAnchor,
        radius: Int
    ) {
        let totalCount = searchNavigationTotalCount
        guard totalCount > 0 else {
            search.updateNavigationSnapshot(nil)
            if let direction {
                playback.playbackViewModel?.showSearchNavigationFeedback(direction: direction, hasResult: false)
            }
            return
        }

        let boundedRadius = max(1, radius)
        let anchorRank = anchor.selectedSearchRank.map { min(max(0, $0), totalCount - 1) }
        let lowerBound: Int
        let upperBound: Int
        if let anchorRank {
            lowerBound = max(0, anchorRank - boundedRadius)
            upperBound = min(totalCount, anchorRank + boundedRadius + 1)
        } else {
            lowerBound = 0
            upperBound = min(totalCount, (boundedRadius * 2) + 1)
        }
        let requestedRange = lowerBound..<upperBound

        search.replaceNavigationTask(Task { [weak self] in
            guard let self,
                  let page = await self.search.loadAllCueRows(
                    range: requestedRange,
                    folders: self.indexing.selectedFolders
                  )
            else {
                return
            }

            guard !Task.isCancelled else {
                return
            }

            self.search.applyAllCueSearchContext(page)
            self.refreshSearchPlaybackPlaylistSource(
                resultListGeneration: self.search.resultListGeneration
            )
            guard let resolvedSnapshot = self.loadedSearchNavigationSnapshot(
                anchor: anchor,
                radius: boundedRadius
            ) else {
                if let direction {
                    self.playback.playbackViewModel?.showSearchNavigationFeedback(
                        direction: direction,
                        hasResult: false
                    )
                }
                return
            }

            self.applySearchNavigationSnapshot(resolvedSnapshot)
            let target: SubtitleSearchResult? = switch direction {
            case .previous:
                resolvedSnapshot.previous
            case .next:
                resolvedSnapshot.next
            case nil:
                nil
            }

            if let target, let direction {
                self.playback.playbackViewModel?.showSearchNavigationFeedback(direction: direction, hasResult: true)
                self.openSearchResult(target)
            } else if let direction {
                self.playback.playbackViewModel?.showSearchNavigationFeedback(direction: direction, hasResult: false)
            }
        })
    }

    func currentSearchNavigationAnchor() -> SearchNavigationAnchor {
        let milliseconds = max(
            0,
            Int(((playback.playbackViewModel?.currentTime ?? 0) * 1_000).rounded(.down))
        )

        return SearchNavigationAnchor(
            selectedEntryID: search.selectedSearchResult?.entryID,
            selectedSearchRank: search.selectedSearchResult?.searchRank,
            videoPath: currentPlaybackVideoPath,
            subtitlePath: currentPlaybackSubtitlePath,
            currentMilliseconds: milliseconds
        )
    }

    func loadedSearchNavigationSnapshot(
        anchor: SearchNavigationAnchor,
        radius: Int
    ) -> SearchNavigationSnapshot? {
        let loadedResults = search.searchResults.sorted { lhs, rhs in
            lhs.searchRank < rhs.searchRank
        }
        guard !loadedResults.isEmpty else {
            return nil
        }

        let currentIndex: Int?
        if let selectedEntryID = anchor.selectedEntryID {
            currentIndex = loadedResults.firstIndex { $0.entryID == selectedEntryID }
        } else if let selectedSearchRank = anchor.selectedSearchRank {
            currentIndex = loadedResults.firstIndex { $0.searchRank == selectedSearchRank }
        } else {
            currentIndex = nil
        }

        let boundedRadius = max(1, radius)
        let neighborhood: [SubtitleSearchResult]
        if let currentIndex {
            let lowerBound = max(0, currentIndex - boundedRadius)
            let upperBound = min(loadedResults.count, currentIndex + boundedRadius + 1)
            neighborhood = Array(loadedResults[lowerBound..<upperBound])
        } else {
            neighborhood = Array(loadedResults.prefix((boundedRadius * 2) + 1))
        }

        let previous = currentIndex.flatMap { index in
            index > 0 ? loadedResults[index - 1] : nil
        }
        let current = currentIndex.map { loadedResults[$0] }
        let next = currentIndex.flatMap { index in
            index + 1 < loadedResults.count ? loadedResults[index + 1] : nil
        }

        return SearchNavigationSnapshot(
            totalCount: max(search.searchResultTotalCount, loadedResults.count),
            currentIndex: current?.searchRank,
            neighborhood: neighborhood,
            previous: previous,
            current: current,
            next: next
        )
    }

    func applySearchNavigationSnapshot(_ snapshot: SearchNavigationSnapshot) {
        search.updateNavigationSnapshot(snapshot)
        guard activePlaybackSource == .search,
              search.selectedSearchResult?.entryID == snapshot.current?.entryID
        else {
            return
        }

        refreshPlaybackChromeSnapshot(
            displayTitle: playback.chromeSnapshot.displayTitle
        )
    }

    func updateSearchNavigationSnapshotForOpenedResult(_ result: SubtitleSearchResult) {
        let radius = Self.searchNavigationPanelRadius
        if let snapshot = searchNavigationSnapshot(
            containing: result,
            in: search.searchResults,
            totalCount: search.searchResultTotalCount,
            radius: radius
        ) {
            applySearchNavigationSnapshot(snapshot)
            return
        }

        if let existingSnapshot = search.searchNavigationSnapshot,
           let snapshot = searchNavigationSnapshot(
               containing: result,
               in: existingSnapshot.neighborhood,
               totalCount: existingSnapshot.totalCount,
               radius: radius
           ) {
            applySearchNavigationSnapshot(snapshot)
            return
        }

        search.updateNavigationSnapshot(nil)
    }

    private func searchNavigationSnapshot(
        containing result: SubtitleSearchResult,
        in results: [SubtitleSearchResult],
        totalCount: Int,
        radius: Int
    ) -> SearchNavigationSnapshot? {
        let loadedResults = results.sorted { lhs, rhs in
            lhs.searchRank < rhs.searchRank
        }
        guard let currentIndex = loadedResults.firstIndex(where: { $0.entryID == result.entryID }) else {
            return nil
        }

        let boundedRadius = max(1, radius)
        let lowerBound = max(0, currentIndex - boundedRadius)
        let upperBound = min(loadedResults.count, currentIndex + boundedRadius + 1)
        let previous = currentIndex > 0 ? loadedResults[currentIndex - 1] : nil
        let current = loadedResults[currentIndex]
        let next = currentIndex + 1 < loadedResults.count ? loadedResults[currentIndex + 1] : nil

        return SearchNavigationSnapshot(
            totalCount: max(totalCount, loadedResults.count),
            currentIndex: current.searchRank,
            neighborhood: Array(loadedResults[lowerBound..<upperBound]),
            previous: previous,
            current: current,
            next: next
        )
    }

}
