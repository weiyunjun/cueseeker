import Foundation
import CueSeekerCore

private struct SearchPageLoad: Sendable {
    let page: SubtitleSearchPage
    let databaseSearchMilliseconds: Double
}

@MainActor
extension AppCoordinator {
    func updateSearchQuery(_ query: String) {
        UIInvalidationProbe.mark(
            "ACTION UI.SearchQuery.changed",
            details: "length=\(query.count)"
        )
        search.searchQuery = query
        startSearch(query: query, cursor: .start, appending: false, debounce: true)
    }

    func submitTopbarSearch(_ query: String) {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        UIInvalidationProbe.mark(
            "ACTION UI.TopbarSearch.submitted",
            details: "length=\(trimmedQuery.count)"
        )
        if playback.playbackViewModel?.isPlaying == true {
            pausePlayback()
        }
        workbenchLayout.selectPanelMode(.search)
        search.searchQuery = trimmedQuery
        search.searchNavigationSnapshot = nil
        search.searchNavigationResultGroups = []
        startSearch(query: trimmedQuery, cursor: .start, appending: false, debounce: false)
    }

    func loadMoreSearchResultsIfNeeded(currentResult result: SubtitleSearchResult) {
        if search.searchResultPresentationState == .collapsed {
            loadMoreSearchResultGroupRowsIfNeeded(currentResult: result)
            return
        }

        guard search.hasMoreSearchResults, !search.isSearching else {
            return
        }

        guard let index = search.searchResults.firstIndex(where: { $0.entryID == result.entryID }),
              index >= search.searchResults.count - Self.searchPrefetchThreshold
        else {
            return
        }

        loadMoreSearchResultsIfNeeded()
    }

    func loadMoreSearchResultsIfNeeded() {
        guard search.searchResultPresentationState != .collapsed else {
            return
        }

        guard search.hasMoreSearchResults, !search.isSearching else {
            return
        }

        guard let cursor = nextGlobalSearchCursor else {
            return
        }

        startSearch(
            query: search.searchQuery,
            cursor: cursor,
            appending: true,
            debounce: false
        )
    }

    func loadTableSandboxSearchRows(range: Range<Int>) async -> TableSandboxSearchHydrationPage? {
        let trimmedQuery = search.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let folders = indexing.selectedFolders
        let languageFilter = settings.primarySearchLanguage.searchLanguageFilter

        guard !trimmedQuery.isEmpty,
              !folders.isEmpty,
              let database = subtitleDatabase
        else {
            return nil
        }
        let searchDatabaseURL = databaseURL

        let totalCount = search.searchResultTotalCount
        guard totalCount > 0 else { return nil }

        let lowerBound = min(max(0, range.lowerBound), totalCount)
        let upperBound = min(max(lowerBound, range.upperBound), totalCount)
        guard lowerBound < upperBound else { return nil }

        do {
            guard let indexWindow = database.searchResultIDIndexWindow(
                trimmedQuery,
                limit: upperBound - lowerBound,
                cursor: SubtitleSearchCursor(offset: lowerBound),
                under: folders,
                languageFilter: languageFilter,
                minimumKnownResultCount: upperBound
            ) else {
                return nil
            }

            let page = try await Task.detached(priority: .userInitiated) {
                let pageDatabase = try SubtitleDatabase(path: searchDatabaseURL)
                return try pageDatabase.searchIndexedVisiblePage(from: indexWindow)
            }.value

            guard !Task.isCancelled,
                  let page,
                  search.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines) == trimmedQuery,
                  indexing.selectedFolders.map(\.path) == folders.map(\.path),
                  settings.primarySearchLanguage.searchLanguageFilter == languageFilter
            else {
                return nil
            }

            return TableSandboxSearchHydrationPage(
                range: lowerBound..<(lowerBound + page.results.count),
                results: page.results,
                totalRowCount: page.totalCount
            )
        } catch {
            return nil
        }
    }

    func toggleSearchResultGroup(_ subtitlePath: String) {
        let hasLoadedRows = searchResultGroupHasLoadedRows(subtitlePath)
        UIInvalidationProbe.mark(
            "ACTION UI.SearchResultGroup.toggled",
            details: "collapsedBefore=\(search.collapsedSearchResultGroupPaths.contains(subtitlePath)) loadedRows=\(hasLoadedRows)"
        )
        if search.collapsedSearchResultGroupPaths.contains(subtitlePath) {
            search.collapsedSearchResultGroupPaths.remove(subtitlePath)
            rebuildSearchResultGroups()
            if search.searchResultPresentationState == .collapsed {
                revealInitialSearchResultGroupPage(for: subtitlePath)
            }
        } else if hasLoadedRows {
            search.collapsedSearchResultGroupPaths.insert(subtitlePath)
            rebuildSearchResultGroups()
        } else if searchResultGroupTasks[subtitlePath] == nil {
            revealInitialSearchResultGroupPage(for: subtitlePath)
        } else {
            return
        }
    }

    func collapseAllSearchResultGroups() {
        guard search.canCollapseAllSearchResultGroups else {
            return
        }

        let groupPaths = Set(search.searchFileSummaries.map(\.subtitlePath))
        guard !groupPaths.isEmpty else {
            return
        }

        UIInvalidationProbe.mark(
            "ACTION UI.SearchResults.collapseAll",
            details: "groups=\(groupPaths.count)"
        )
        search.searchResultPresentationState = .collapsed
        search.expandedSearchResultGroupRowsByPath = [:]
        search.collapsedSearchResultGroupPaths = groupPaths
        rebuildSearchResultGroups()
    }

    func startSearch(
        query: String,
        cursor: SubtitleSearchCursor,
        appending: Bool,
        debounce: Bool
    ) {
        searchTask?.cancel()
        if !appending {
            searchExactCompletionTask?.cancel()
            searchExactCompletionTask = nil
        }

        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let folders = indexing.selectedFolders
        let pageSize = Self.searchPageSize
        let offset = cursor.offset
        let languageFilter = settings.primarySearchLanguage.searchLanguageFilter
        if let activeSearchPerformanceRun {
            SearchPerformanceLogger.mark(activeSearchPerformanceRun, "search_superseded_by_new_search")
            SearchPerformanceLogger.writeE2ESearchPage(
                activeSearchPerformanceRun,
                event: "search_superseded_by_new_search",
                page: nil,
                status: "cancelled"
            )
        }
        let searchPerformanceRun = SearchPerformanceLogger.startRun(
            query: trimmedQuery,
            queryLength: trimmedQuery.count,
            offset: offset,
            cursor: cursor,
            limit: pageSize,
            appending: appending,
            debounce: debounce,
            folderPaths: folders.map(\.path),
            e2eLoggingEnabled: settings.searchE2ELoggingEnabled
        )
        activeSearchPerformanceRun = searchPerformanceRun
        pendingSearchVisibleEntryIDs = []

        if !appending {
            let resetStart = SearchPerformanceLogger.now()
            resetSearchResultLoadingState()
            SearchPerformanceLogger.mark(
                searchPerformanceRun,
                "search_state_reset",
                phaseStart: resetStart,
                groupCount: search.searchResultGroups.count,
                renderedRowCount: search.renderedSearchResultCount,
                status: "reset"
            )
        }

        guard !trimmedQuery.isEmpty else {
            search.searchStatus = .idle
            SearchPerformanceLogger.mark(searchPerformanceRun, "search_skipped_empty_query", status: "idle")
            SearchPerformanceLogger.writeE2ESearchPage(
                searchPerformanceRun,
                event: "search_skipped_empty_query",
                page: nil,
                status: "idle"
            )
            clearSearchPerformanceRunIfActive(searchPerformanceRun)
            return
        }

        guard !folders.isEmpty else {
            search.searchStatus = .completed
            search.selectedSearchResult = nil
            SearchPerformanceLogger.mark(searchPerformanceRun, "search_skipped_no_folders", status: "completed")
            SearchPerformanceLogger.writeE2ESearchPage(
                searchPerformanceRun,
                event: "search_skipped_no_folders",
                page: nil,
                status: "completed"
            )
            clearSearchPerformanceRunIfActive(searchPerformanceRun)
            return
        }

        search.searchStatus = .searching
        SearchPerformanceLogger.mark(searchPerformanceRun, "search_status_searching", status: "searching")

        guard !indexing.databaseMaintenanceStatus.isCompacting else {
            search.searchStatus = .failed("Database compaction is running")
            SearchPerformanceLogger.mark(
                searchPerformanceRun,
                "search_failed_database_compacting",
                status: "failed",
                error: "Database compaction is running"
            )
            SearchPerformanceLogger.writeE2ESearchPage(
                searchPerformanceRun,
                event: "search_failed_database_compacting",
                page: nil,
                status: "failed",
                error: "Database compaction is running"
            )
            clearSearchPerformanceRunIfActive(searchPerformanceRun)
            return
        }

        guard let database = subtitleDatabase else {
            search.searchStatus = .failed("Database is not initialized")
            SearchPerformanceLogger.mark(
                searchPerformanceRun,
                "search_failed_no_database",
                status: "failed",
                error: "Database is not initialized"
            )
            SearchPerformanceLogger.writeE2ESearchPage(
                searchPerformanceRun,
                event: "search_failed_no_database",
                page: nil,
                status: "failed",
                error: "Database is not initialized"
            )
            clearSearchPerformanceRunIfActive(searchPerformanceRun)
            return
        }
        searchTask = Task {
            do {
                if debounce {
                    let debounceStart = SearchPerformanceLogger.now()
                    try await Task.sleep(nanoseconds: 250_000_000)
                    SearchPerformanceLogger.mark(
                        searchPerformanceRun,
                        "search_debounce_finished",
                        phaseStart: debounceStart
                    )
                }

                SearchPerformanceLogger.mark(searchPerformanceRun, "database_search_started")
                let diagnosticsSink = SearchPerformanceLogger.coreDiagnosticsSink(for: searchPerformanceRun)
                let pageLoad = try await Task.detached(priority: .userInitiated) {
                    let databaseSearchStart = SearchPerformanceLogger.now()
                    let page = try database.searchVisiblePage(
                        trimmedQuery,
                        limit: pageSize,
                        cursor: cursor,
                        under: folders,
                        languageFilter: languageFilter,
                        diagnostics: diagnosticsSink
                    )
                    let databaseSearchMilliseconds = SearchPerformanceLogger.elapsedMilliseconds(
                        since: databaseSearchStart
                    )
                    SearchPerformanceLogger.mark(
                        searchPerformanceRun,
                        "database_search_returned",
                        phaseStart: databaseSearchStart,
                        resultCount: page.results.count,
                        totalCount: page.totalCount,
                        fileSummaryCount: page.fileSummaries.count
                    )
                    return SearchPageLoad(
                        page: page,
                        databaseSearchMilliseconds: databaseSearchMilliseconds
                    )
                }.value
                let page = pageLoad.page
                SearchPerformanceLogger.mark(
                    searchPerformanceRun,
                    "database_page_received_on_main",
                    resultCount: page.results.count,
                    totalCount: page.totalCount,
                    fileSummaryCount: page.fileSummaries.count
                )

                guard !Task.isCancelled else {
                    SearchPerformanceLogger.mark(searchPerformanceRun, "search_cancelled_after_database")
                    SearchPerformanceLogger.writeE2ESearchPage(
                        searchPerformanceRun,
                        event: "search_cancelled_after_database",
                        page: page,
                        databaseSearchMilliseconds: pageLoad.databaseSearchMilliseconds,
                        status: "cancelled"
                    )
                    return
                }

                let stateAssignStart = SearchPerformanceLogger.now()
                if appending {
                    appendGlobalSearchResults(page.results)
                    loadedGlobalSearchResultCount = max(
                        loadedGlobalSearchResultCount,
                        offset + page.results.count
                    )
                } else {
                    search.searchResults = page.results
                    loadedGlobalSearchResultCount = page.results.count
                }
                let shouldPreserveExactMetadata = appending && search.searchCountState == .exact
                if shouldPreserveExactMetadata && page.countState != .exact {
                    search.searchKnownResultCount = max(search.searchKnownResultCount, page.knownResultCount)
                    search.searchKnownFileCount = max(search.searchKnownFileCount, page.knownFileCount)
                } else {
                    search.searchResultTotalCount = page.totalCount
                    search.searchFileSummaries = page.fileSummaries
                    search.searchCountState = page.countState
                    search.searchKnownResultCount = page.knownResultCount
                    search.searchKnownFileCount = page.knownFileCount
                }
                search.hasMoreSearchResults = page.hasMore
                nextGlobalSearchCursor = page.nextCursor
                let stateAssignMilliseconds = SearchPerformanceLogger.elapsedMilliseconds(since: stateAssignStart)
                SearchPerformanceLogger.mark(
                    searchPerformanceRun,
                    "search_state_assigned",
                    phaseStart: stateAssignStart,
                    resultCount: search.searchResults.count,
                    totalCount: search.searchResultTotalCount,
                    fileSummaryCount: search.searchFileSummaries.count
                )

                let rebuildStart = SearchPerformanceLogger.now()
                rebuildSearchResultGroups()
                updatePlaybackQuickSearchDefaultResultSelectionIfNeeded(
                    query: trimmedQuery,
                    appending: appending
                )
                let groupRebuildMilliseconds = SearchPerformanceLogger.elapsedMilliseconds(since: rebuildStart)
                SearchPerformanceLogger.mark(
                    searchPerformanceRun,
                    "search_groups_rebuilt",
                    phaseStart: rebuildStart,
                    resultCount: search.searchResults.count,
                    totalCount: search.searchResultTotalCount,
                    fileSummaryCount: search.searchFileSummaries.count,
                    groupCount: search.searchResultGroups.count,
                    renderedRowCount: search.renderedSearchResultCount
                )
                prepareSearchPerformanceVisibility(
                    for: searchPerformanceRun,
                    resultsAwaitingFirstAppearance: page.results
                )

                let completionStart = SearchPerformanceLogger.now()
                let pageCompletesSearch = page.countState == .exact || shouldPreserveExactMetadata
                if pageCompletesSearch {
                    search.searchStatus = .completed
                } else {
                    search.searchStatus = .searching
                }
                let statusCompletionMilliseconds = SearchPerformanceLogger.elapsedMilliseconds(since: completionStart)
                let logPageHasExactCounts = page.countState == .exact
                let statusText = logPageHasExactCounts ? "completed" : "searching"
                let eventName = logPageHasExactCounts ? "search_status_completed" : "search_visible_page_loaded"
                SearchPerformanceLogger.mark(
                    searchPerformanceRun,
                    eventName,
                    phaseStart: completionStart,
                    resultCount: search.searchResults.count,
                    totalCount: search.searchResultTotalCount,
                    fileSummaryCount: search.searchFileSummaries.count,
                    groupCount: search.searchResultGroups.count,
                    renderedRowCount: search.renderedSearchResultCount,
                    status: statusText
                )
                SearchPerformanceLogger.writeE2ESearchPage(
                    searchPerformanceRun,
                    event: eventName,
                    page: page,
                    databaseSearchMilliseconds: pageLoad.databaseSearchMilliseconds,
                    stateAssignMilliseconds: stateAssignMilliseconds,
                    groupRebuildMilliseconds: groupRebuildMilliseconds,
                    statusCompletionMilliseconds: statusCompletionMilliseconds,
                    groupCount: search.searchResultGroups.count,
                    renderedRowCount: search.renderedSearchResultCount,
                    status: statusText
                )
                if !appending && !pageCompletesSearch {
                    startSearchExactCompletion(
                        query: trimmedQuery,
                        folders: folders,
                        languageFilter: languageFilter,
                        run: searchPerformanceRun
                    )
                }
                if page.results.isEmpty {
                    SearchPerformanceLogger.mark(searchPerformanceRun, "search_no_result_rows_to_render")
                    clearSearchPerformanceRunIfActive(searchPerformanceRun)
                }
            } catch is CancellationError {
                SearchPerformanceLogger.mark(searchPerformanceRun, "search_cancelled")
                SearchPerformanceLogger.writeE2ESearchPage(
                    searchPerformanceRun,
                    event: "search_cancelled",
                    page: nil,
                    status: "cancelled"
                )
                return
            } catch {
                guard !Task.isCancelled else {
                    SearchPerformanceLogger.mark(searchPerformanceRun, "search_cancelled_after_error")
                    SearchPerformanceLogger.writeE2ESearchPage(
                        searchPerformanceRun,
                        event: "search_cancelled_after_error",
                        page: nil,
                        status: "cancelled"
                    )
                    return
                }

                if !appending {
                    let resetStart = SearchPerformanceLogger.now()
                    resetSearchResultLoadingState()
                    SearchPerformanceLogger.mark(
                        searchPerformanceRun,
                        "search_state_reset_after_error",
                        phaseStart: resetStart,
                        groupCount: search.searchResultGroups.count,
                        renderedRowCount: search.renderedSearchResultCount
                    )
                }
                search.hasMoreSearchResults = false
                let message = Self.errorMessage(for: error)
                search.searchStatus = .failed(message)
                SearchPerformanceLogger.mark(
                    searchPerformanceRun,
                    "search_failed",
                    status: "failed",
                    error: message
                )
                SearchPerformanceLogger.writeE2ESearchPage(
                    searchPerformanceRun,
                    event: "search_failed",
                    page: nil,
                    groupCount: search.searchResultGroups.count,
                    renderedRowCount: search.renderedSearchResultCount,
                    status: "failed",
                    error: message
                )
                clearSearchPerformanceRunIfActive(searchPerformanceRun)
            }
        }
    }

    func updatePlaybackQuickSearchDefaultResultSelectionIfNeeded(
        query trimmedQuery: String,
        appending: Bool
    ) {
        guard playback.isQuickSearchOverlayVisible,
              playback.quickSearchSubmittedQuery == trimmedQuery,
              !appending
        else {
            return
        }

        playback.selectDefaultQuickSearchResultIfNeeded(resultCount: search.searchResults.count)
    }

    func applySearchCountProgress(
        _ progress: SubtitleSearchProgressSnapshot,
        query trimmedQuery: String,
        folderPaths: [String],
        languageFilter: SubtitleSearchLanguageFilter,
        run searchPerformanceRun: SearchPerformanceRun?
    ) {
        guard progress.countState == .exactProgress,
              search.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines) == trimmedQuery,
              indexing.selectedFolders.map(\.path) == folderPaths,
              settings.primarySearchLanguage.searchLanguageFilter == languageFilter,
              search.searchCountState != .exact,
              progress.knownResultCount >= search.searchKnownResultCount,
              progress.knownFileCount >= search.searchKnownFileCount
        else {
            return
        }

        let now = SearchPerformanceLogger.now()
        if lastSearchCountProgressUpdate != 0,
           now - lastSearchCountProgressUpdate < Self.searchCountProgressMinimumIntervalNanoseconds {
            return
        }
        lastSearchCountProgressUpdate = now

        search.searchResultTotalCount = progress.knownResultCount
        search.searchFileSummaries = progress.fileSummaries
        search.searchCountState = progress.countState
        search.searchKnownResultCount = progress.knownResultCount
        search.searchKnownFileCount = progress.knownFileCount
        if loadedGlobalSearchResultCount < search.searchResultTotalCount {
            search.hasMoreSearchResults = true
            nextGlobalSearchCursor = nextGlobalSearchCursor
                ?? SubtitleSearchCursor(offset: loadedGlobalSearchResultCount)
        }
        rebuildSearchResultGroups()

        SearchPerformanceLogger.mark(
            searchPerformanceRun,
            "search_count_progress",
            resultCount: search.searchResults.count,
            totalCount: search.searchResultTotalCount,
            fileSummaryCount: search.searchFileSummaries.count,
            groupCount: search.searchResultGroups.count,
            renderedRowCount: search.renderedSearchResultCount,
            status: "searching"
        )
        SearchPerformanceLogger.writeE2ECountProgress(
            searchPerformanceRun,
            progress: progress,
            resultCount: search.searchResults.count,
            groupCount: search.searchResultGroups.count,
            renderedRowCount: search.renderedSearchResultCount
        )
    }

    func startSearchExactCompletion(
        query trimmedQuery: String,
        folders: [URL],
        languageFilter: SubtitleSearchLanguageFilter,
        run searchPerformanceRun: SearchPerformanceRun?
    ) {
        searchExactCompletionTask?.cancel()

        guard let database = subtitleDatabase else {
            return
        }

        let pageSize = Self.searchPageSize
        let folderPaths = folders.map(\.path)
        let progressSink: SubtitleSearchProgressSink = { [weak self] snapshot in
            Task { @MainActor [weak self] in
                self?.applySearchCountProgress(
                    snapshot,
                    query: trimmedQuery,
                    folderPaths: folderPaths,
                    languageFilter: languageFilter,
                    run: searchPerformanceRun
                )
            }
        }
        searchExactCompletionTask = Task {
            do {
                SearchPerformanceLogger.mark(searchPerformanceRun, "database_exact_completion_started")
                let diagnosticsSink = SearchPerformanceLogger.coreDiagnosticsSink(for: searchPerformanceRun)
                let pageLoad = try await Task.detached(priority: .utility) {
                    let databaseSearchStart = SearchPerformanceLogger.now()
                    let page = try database.searchPage(
                        trimmedQuery,
                        limit: pageSize,
                        cursor: .start,
                        under: folders,
                        languageFilter: languageFilter,
                        diagnostics: diagnosticsSink,
                        progress: progressSink
                    )
                    let databaseSearchMilliseconds = SearchPerformanceLogger.elapsedMilliseconds(
                        since: databaseSearchStart
                    )
                    return SearchPageLoad(
                        page: page,
                        databaseSearchMilliseconds: databaseSearchMilliseconds
                    )
                }.value
                let page = pageLoad.page

                guard !Task.isCancelled else {
                    SearchPerformanceLogger.mark(searchPerformanceRun, "search_exact_completion_cancelled")
                    SearchPerformanceLogger.writeE2ESearchPage(
                        searchPerformanceRun,
                        event: "search_exact_completion_cancelled",
                        page: page,
                        databaseSearchMilliseconds: pageLoad.databaseSearchMilliseconds,
                        status: "cancelled"
                    )
                    return
                }

                guard search.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines) == trimmedQuery,
                      indexing.selectedFolders.map(\.path) == folderPaths,
                      settings.primarySearchLanguage.searchLanguageFilter == languageFilter
                else {
                    SearchPerformanceLogger.mark(searchPerformanceRun, "search_exact_completion_stale")
                    SearchPerformanceLogger.writeE2ESearchPage(
                        searchPerformanceRun,
                        event: "search_exact_completion_stale",
                        page: page,
                        databaseSearchMilliseconds: pageLoad.databaseSearchMilliseconds,
                        status: "cancelled"
                    )
                    return
                }

                let stateAssignStart = SearchPerformanceLogger.now()
                search.searchResultTotalCount = page.totalCount
                search.searchFileSummaries = page.fileSummaries
                search.searchCountState = page.countState
                search.searchKnownResultCount = page.knownResultCount
                search.searchKnownFileCount = page.knownFileCount
                search.hasMoreSearchResults = loadedGlobalSearchResultCount < page.totalCount
                nextGlobalSearchCursor = search.hasMoreSearchResults
                    ? (nextGlobalSearchCursor ?? SubtitleSearchCursor(offset: loadedGlobalSearchResultCount))
                    : nil
                let stateAssignMilliseconds = SearchPerformanceLogger.elapsedMilliseconds(since: stateAssignStart)

                let rebuildStart = SearchPerformanceLogger.now()
                rebuildSearchResultGroups()
                let groupRebuildMilliseconds = SearchPerformanceLogger.elapsedMilliseconds(since: rebuildStart)

                let completionStart = SearchPerformanceLogger.now()
                search.searchStatus = .completed
                searchExactCompletionTask = nil
                let statusCompletionMilliseconds = SearchPerformanceLogger.elapsedMilliseconds(since: completionStart)
                SearchPerformanceLogger.mark(
                    searchPerformanceRun,
                    "search_status_completed",
                    phaseStart: completionStart,
                    resultCount: search.searchResults.count,
                    totalCount: search.searchResultTotalCount,
                    fileSummaryCount: search.searchFileSummaries.count,
                    groupCount: search.searchResultGroups.count,
                    renderedRowCount: search.renderedSearchResultCount,
                    status: "completed"
                )
                SearchPerformanceLogger.writeE2ESearchPage(
                    searchPerformanceRun,
                    event: "search_status_completed",
                    page: page,
                    databaseSearchMilliseconds: pageLoad.databaseSearchMilliseconds,
                    stateAssignMilliseconds: stateAssignMilliseconds,
                    groupRebuildMilliseconds: groupRebuildMilliseconds,
                    statusCompletionMilliseconds: statusCompletionMilliseconds,
                    groupCount: search.searchResultGroups.count,
                    renderedRowCount: search.renderedSearchResultCount,
                    status: "completed"
                )
            } catch is CancellationError {
                SearchPerformanceLogger.mark(searchPerformanceRun, "search_exact_completion_cancelled")
                SearchPerformanceLogger.writeE2ESearchPage(
                    searchPerformanceRun,
                    event: "search_exact_completion_cancelled",
                    page: nil,
                    status: "cancelled"
                )
                return
            } catch {
                guard !Task.isCancelled else {
                    SearchPerformanceLogger.mark(searchPerformanceRun, "search_exact_completion_cancelled_after_error")
                    SearchPerformanceLogger.writeE2ESearchPage(
                        searchPerformanceRun,
                        event: "search_exact_completion_cancelled_after_error",
                        page: nil,
                        status: "cancelled"
                    )
                    return
                }

                guard search.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines) == trimmedQuery,
                      indexing.selectedFolders.map(\.path) == folderPaths,
                      settings.primarySearchLanguage.searchLanguageFilter == languageFilter
                else {
                    SearchPerformanceLogger.mark(searchPerformanceRun, "search_exact_completion_error_stale")
                    return
                }

                let message = Self.errorMessage(for: error)
                search.searchStatus = .failed(message)
                searchExactCompletionTask = nil
                SearchPerformanceLogger.mark(
                    searchPerformanceRun,
                    "search_exact_completion_failed",
                    status: "failed",
                    error: message
                )
                SearchPerformanceLogger.writeE2ESearchPage(
                    searchPerformanceRun,
                    event: "search_exact_completion_failed",
                    page: nil,
                    groupCount: search.searchResultGroups.count,
                    renderedRowCount: search.renderedSearchResultCount,
                    status: "failed",
                    error: message
                )
            }
        }
    }

    func markSearchResultVisible(_ result: SubtitleSearchResult) {
        guard let activeSearchPerformanceRun,
              pendingSearchVisibleEntryIDs.contains(result.entryID)
        else {
            return
        }

        pendingSearchVisibleEntryIDs = []
        SearchPerformanceLogger.mark(
            activeSearchPerformanceRun,
            "first_result_row_appeared",
            resultCount: search.searchResults.count,
            totalCount: search.searchResultTotalCount,
            fileSummaryCount: search.searchFileSummaries.count,
            groupCount: search.searchResultGroups.count,
            renderedRowCount: search.renderedSearchResultCount,
            entryID: result.entryID
        )
        SearchPerformanceLogger.writeE2EFirstVisible(
            activeSearchPerformanceRun,
            result: result,
            resultCount: search.searchResults.count,
            countState: search.searchCountState,
            knownResultCount: search.searchKnownResultCount,
            knownFileCount: search.searchKnownFileCount,
            totalCount: search.searchResultTotalCount,
            fileSummaryCount: search.searchFileSummaries.count,
            groupCount: search.searchResultGroups.count,
            renderedRowCount: search.renderedSearchResultCount
        )
        clearSearchPerformanceRunIfActive(activeSearchPerformanceRun)
    }

    func prepareSearchPerformanceVisibility(
        for run: SearchPerformanceRun?,
        resultsAwaitingFirstAppearance results: [SubtitleSearchResult]
    ) {
        guard let run, activeSearchPerformanceRun?.id == run.id else {
            return
        }

        pendingSearchVisibleEntryIDs = Set(results.map(\.entryID))
    }

    func clearSearchPerformanceRunIfActive(_ run: SearchPerformanceRun?) {
        guard let run, activeSearchPerformanceRun?.id == run.id else {
            return
        }

        activeSearchPerformanceRun = nil
        pendingSearchVisibleEntryIDs = []
    }

    func refreshSearchNavigationSnapshot() {
        loadSearchNavigationSnapshot(opening: nil)
    }

    func openAdjacentSearchResult(_ direction: SearchResultNavigationDirection) {
        loadSearchNavigationSnapshot(opening: direction)
    }

    func refreshCurrentSearch(clearExistingResults: Bool = false) {
        guard !search.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        if clearExistingResults {
            search.searchResults = []
            search.searchResultTotalCount = 0
            search.searchFileSummaries = []
            search.expandedSearchResultGroupRowsByPath = [:]
            search.searchCountState = .exact
            search.searchKnownResultCount = 0
            search.searchKnownFileCount = 0
            search.hasMoreSearchResults = false
            loadedGlobalSearchResultCount = 0
            lastSearchCountProgressUpdate = 0
            nextGlobalSearchCursor = nil
            rebuildSearchResultGroups()
        }

        updateSearchQuery(search.searchQuery)
    }

    func loadSearchNavigationSnapshot(opening direction: SearchResultNavigationDirection?) {
        searchNavigationTask?.cancel()

        let trimmedQuery = search.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty,
              !indexing.selectedFolders.isEmpty,
              let database = subtitleDatabase
        else {
            search.searchNavigationSnapshot = nil
            search.searchNavigationResultGroups = []
            if let direction {
                playback.playbackViewModel?.showSearchNavigationFeedback(direction: direction, hasResult: false)
            }
            return
        }

        let folders = indexing.selectedFolders
        let anchor = currentSearchNavigationAnchor()
        let panelRadius = Self.searchNavigationPanelRadius
        let languageFilter = settings.primarySearchLanguage.searchLanguageFilter
        searchNavigationTask = Task { [weak self] in
            do {
                let snapshot = try await Task.detached(priority: .userInitiated) {
                    try database.searchNavigationSnapshot(
                        trimmedQuery,
                        under: folders,
                        languageFilter: languageFilter,
                        anchor: anchor,
                        radius: panelRadius
                    )
                }.value

                guard !Task.isCancelled else {
                    return
                }

                guard let self else {
                    return
                }

                guard self.settings.primarySearchLanguage.searchLanguageFilter == languageFilter else {
                    return
                }

                self.applySearchNavigationSnapshot(snapshot)
                let target: SubtitleSearchResult? = switch direction {
                case .previous:
                    snapshot.previous
                case .next:
                    snapshot.next
                case nil:
                    nil
                }

                if let target, let direction {
                    self.playback.playbackViewModel?.showSearchNavigationFeedback(direction: direction, hasResult: true)
                    self.openSearchResult(target)
                } else if let direction {
                    self.playback.playbackViewModel?.showSearchNavigationFeedback(direction: direction, hasResult: false)
                }
            } catch {
                guard !Task.isCancelled else {
                    return
                }

                print("Failed to load Search navigation snapshot: \(error)")
                self?.search.searchNavigationSnapshot = nil
                self?.search.searchNavigationResultGroups = []
            }
        }
    }

    func currentSearchNavigationAnchor() -> SearchNavigationAnchor {
        let milliseconds = max(
            0,
            Int(((playback.playbackViewModel?.currentTime ?? 0) * 1_000).rounded(.down))
        )

        return SearchNavigationAnchor(
            selectedEntryID: search.selectedSearchResult?.entryID,
            videoPath: currentPlaybackVideoPath,
            subtitlePath: currentPlaybackSubtitlePath,
            currentMilliseconds: milliseconds
        )
    }

    func applySearchNavigationSnapshot(_ snapshot: SearchNavigationSnapshot) {
        search.searchNavigationSnapshot = snapshot
        let paths = Set(snapshot.neighborhood.map(\.subtitlePath))
        let summaries = search.searchFileSummaries.filter { paths.contains($0.subtitlePath) }
        search.searchNavigationResultGroups = Self.makeSearchResultGroups(
            results: snapshot.neighborhood,
            fileSummaries: summaries,
            expandedRowsByPath: [:],
            collapsedGroupPaths: [],
            includesSummaryOnlyGroups: false
        )
    }

    func revealInitialSearchResultGroupPage(for subtitlePath: String) {
        let currentRows = loadedRowsForSearchResultGroup(subtitlePath)
        if !currentRows.isEmpty {
            search.expandedSearchResultGroupRowsByPath[subtitlePath] = Array(currentRows.prefix(Self.searchPageSize))
            rebuildSearchResultGroups()
        }

        loadSearchResultGroupPage(for: subtitlePath, offset: 0)
    }

    func loadMoreSearchResultGroupRowsIfNeeded(currentResult result: SubtitleSearchResult) {
        let subtitlePath = result.subtitlePath
        guard searchResultGroupTasks[subtitlePath] == nil else {
            return
        }

        let currentRows = loadedRowsForSearchResultGroup(subtitlePath)
        guard let index = currentRows.firstIndex(where: { $0.entryID == result.entryID }),
              index >= currentRows.count - Self.searchPrefetchThreshold
        else {
            return
        }

        guard let totalCount = search.searchFileSummaries.first(where: { $0.subtitlePath == subtitlePath })?.matchCount,
              currentRows.count < totalCount
        else {
            return
        }

        loadSearchResultGroupPage(for: subtitlePath, offset: currentRows.count)
    }

    func loadSearchResultGroupPage(for subtitlePath: String, offset: Int) {
        guard searchResultGroupTasks[subtitlePath] == nil else {
            return
        }

        let currentRows = loadedRowsForSearchResultGroup(subtitlePath)
        let rowsBefore = currentRows.count
        let trimmedQuery = search.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty, !indexing.selectedFolders.isEmpty else {
            return
        }

        let folders = indexing.selectedFolders
        guard let database = subtitleDatabase else {
            return
        }
        let pageSize = Self.searchPageSize
        let languageFilter = settings.primarySearchLanguage.searchLanguageFilter
        let subtitleDisplayTitle = search.searchFileSummaries
            .first(where: { $0.subtitlePath == subtitlePath })?
            .subtitleDisplayTitle
            ?? SubtitleDisplayTitleResolver.displayTitle(forSubtitlePath: subtitlePath)
        let totalCount = search.searchFileSummaries
            .first(where: { $0.subtitlePath == subtitlePath })?
            .matchCount
        let loadMoreRun = SearchPerformanceLogger.startRun(
            query: trimmedQuery,
            queryLength: trimmedQuery.count,
            offset: offset,
            limit: pageSize,
            appending: true,
            debounce: false,
            folderPaths: folders.map(\.path),
            e2eLoggingEnabled: settings.searchE2ELoggingEnabled
        )
        searchResultGroupTasks[subtitlePath] = Task { [weak self] in
            do {
                let pageLoad = try await Task.detached(priority: .userInitiated) {
                    let databaseSearchStart = SearchPerformanceLogger.now()
                    let results = try database.search(
                        trimmedQuery,
                        limit: pageSize,
                        offset: offset,
                        under: folders,
                        inSubtitlePath: subtitlePath,
                        languageFilter: languageFilter
                    )
                    let databaseSearchMilliseconds = SearchPerformanceLogger.elapsedMilliseconds(
                        since: databaseSearchStart
                    )
                    return (results, databaseSearchMilliseconds)
                }.value
                let results = pageLoad.0
                let databaseSearchMilliseconds = pageLoad.1

                guard !Task.isCancelled else {
                    SearchPerformanceLogger.writeE2EFileLoadMore(
                        loadMoreRun,
                        subtitlePath: subtitlePath,
                        subtitleDisplayTitle: subtitleDisplayTitle,
                        rowsBefore: rowsBefore,
                        rowsAfter: nil,
                        returned: nil,
                        totalCount: totalCount,
                        databaseSearchMilliseconds: databaseSearchMilliseconds,
                        status: "cancelled"
                    )
                    return
                }

                guard let self,
                      self.search.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines) == trimmedQuery,
                      self.settings.primarySearchLanguage.searchLanguageFilter == languageFilter,
                      self.search.searchFileSummaries.contains(where: { $0.subtitlePath == subtitlePath })
                else {
                    SearchPerformanceLogger.writeE2EFileLoadMore(
                        loadMoreRun,
                        subtitlePath: subtitlePath,
                        subtitleDisplayTitle: subtitleDisplayTitle,
                        rowsBefore: rowsBefore,
                        rowsAfter: nil,
                        returned: results.count,
                        totalCount: totalCount,
                        databaseSearchMilliseconds: databaseSearchMilliseconds,
                        status: "cancelled"
                    )
                    return
                }

                let mergedResults: [SubtitleSearchResult]
                if offset == 0 {
                    mergedResults = results
                } else {
                    let existingEntryIDs = Set(currentRows.map(\.entryID))
                    mergedResults = (currentRows + results.filter { !existingEntryIDs.contains($0.entryID) })
                        .sorted(by: Self.searchResultSort)
                }
                self.search.expandedSearchResultGroupRowsByPath[subtitlePath] = mergedResults
                self.searchResultGroupTasks.removeValue(forKey: subtitlePath)
                self.rebuildSearchResultGroups()
                SearchPerformanceLogger.writeE2EFileLoadMore(
                    loadMoreRun,
                    subtitlePath: subtitlePath,
                    subtitleDisplayTitle: subtitleDisplayTitle,
                    rowsBefore: rowsBefore,
                    rowsAfter: mergedResults.count,
                    returned: results.count,
                    totalCount: totalCount,
                    databaseSearchMilliseconds: databaseSearchMilliseconds,
                    groupCount: self.search.searchResultGroups.count,
                    renderedRowCount: self.search.renderedSearchResultCount,
                    status: "completed"
                )
            } catch is CancellationError {
                SearchPerformanceLogger.writeE2EFileLoadMore(
                    loadMoreRun,
                    subtitlePath: subtitlePath,
                    subtitleDisplayTitle: subtitleDisplayTitle,
                    rowsBefore: rowsBefore,
                    rowsAfter: nil,
                    returned: nil,
                    totalCount: totalCount,
                    status: "cancelled"
                )
                return
            } catch {
                guard !Task.isCancelled else {
                    SearchPerformanceLogger.writeE2EFileLoadMore(
                        loadMoreRun,
                        subtitlePath: subtitlePath,
                        subtitleDisplayTitle: subtitleDisplayTitle,
                        rowsBefore: rowsBefore,
                        rowsAfter: nil,
                        returned: nil,
                        totalCount: totalCount,
                        status: "cancelled"
                    )
                    return
                }

                self?.searchResultGroupTasks.removeValue(forKey: subtitlePath)
                self?.search.searchStatus = .failed(Self.errorMessage(for: error))
                SearchPerformanceLogger.writeE2EFileLoadMore(
                    loadMoreRun,
                    subtitlePath: subtitlePath,
                    subtitleDisplayTitle: subtitleDisplayTitle,
                    rowsBefore: rowsBefore,
                    rowsAfter: nil,
                    returned: nil,
                    totalCount: totalCount,
                    status: "failed",
                    error: Self.errorMessage(for: error)
                )
            }
        }
    }

    func loadedRowsForSearchResultGroup(_ subtitlePath: String) -> [SubtitleSearchResult] {
        let rows = search.expandedSearchResultGroupRowsByPath[subtitlePath]
            ?? search.searchResults.filter { $0.subtitlePath == subtitlePath }
        return rows.sorted(by: Self.searchResultSort)
    }

    func searchResultGroupHasLoadedRows(_ subtitlePath: String) -> Bool {
        if search.expandedSearchResultGroupRowsByPath[subtitlePath]?.isEmpty == false {
            return true
        }

        return search.searchResults.contains { $0.subtitlePath == subtitlePath }
    }

    func revealInitialGlobalSearchResultPage() {
        cancelSearchResultGroupTasks()
        search.expandedSearchResultGroupRowsByPath = [:]
        search.searchResults = Array(search.searchResults.prefix(Self.searchPageSize))
        loadedGlobalSearchResultCount = search.searchResults.count
        search.searchKnownResultCount = search.searchResultTotalCount
        search.searchKnownFileCount = search.searchFileSummaries.count
        search.hasMoreSearchResults = loadedGlobalSearchResultCount < search.searchResultTotalCount
        nextGlobalSearchCursor = search.hasMoreSearchResults
            ? SubtitleSearchCursor(offset: loadedGlobalSearchResultCount)
            : nil
        rebuildSearchResultGroups()
    }

    func appendGlobalSearchResults(_ results: [SubtitleSearchResult]) {
        let existingEntryIDs = Set(search.searchResults.map(\.entryID))
        search.searchResults.append(contentsOf: results.filter { !existingEntryIDs.contains($0.entryID) })
    }

    func resetSearchResultLoadingState() {
        cancelSearchResultGroupTasks()
        searchExactCompletionTask?.cancel()
        searchExactCompletionTask = nil
        searchNavigationTask?.cancel()
        search.searchResults = []
        search.searchResultTotalCount = 0
        search.searchFileSummaries = []
        search.searchCountState = .exact
        search.searchKnownResultCount = 0
        search.searchKnownFileCount = 0
        search.hasMoreSearchResults = false
        lastSearchCountProgressUpdate = 0
        search.searchResultPresentationState = .initial
        search.collapsedSearchResultGroupPaths = []
        search.expandedSearchResultGroupRowsByPath = [:]
        loadedGlobalSearchResultCount = 0
        nextGlobalSearchCursor = nil
        search.searchNavigationSnapshot = nil
        search.searchNavigationResultGroups = []
        rebuildSearchResultGroups()
    }

    func rebuildSearchResultGroups() {
        search.searchResultGroups = Self.makeSearchResultGroups(
            results: search.searchResults,
            fileSummaries: search.searchFileSummaries,
            expandedRowsByPath: search.expandedSearchResultGroupRowsByPath,
            collapsedGroupPaths: search.collapsedSearchResultGroupPaths,
            includesSummaryOnlyGroups: search.searchResultPresentationState == .collapsed
        )
        search.renderedSearchResultCount = search.searchResultGroups.reduce(0) { count, group in
            group.isCollapsed ? count : count + group.results.count
        }
        UIInvalidationProbe.count(
            "UI.SearchPresentation.rebuilt",
            details: "groups=\(search.searchResultGroups.count) rows=\(search.renderedSearchResultCount)"
        )
    }

    func cancelSearchResultGroupTasks() {
        searchResultGroupTasks.values.forEach { $0.cancel() }
        searchResultGroupTasks = [:]
    }
}
