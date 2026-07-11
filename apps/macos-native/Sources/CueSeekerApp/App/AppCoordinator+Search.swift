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

    func updateSearchFilterSet(_ filterSet: SubtitleSearchFilterSet) {
        let previousSignature = search.activeFilterSetSignature
        search.activeFilterSet = filterSet

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
        search.searchQuery = trimmedQuery
        search.searchNavigationSnapshot = nil
        startSearch(query: trimmedQuery, cursor: .start, appending: false, debounce: false)
    }

    func openSearchResultContext(_ result: SubtitleSearchResult) {
        openCueContextSearch(
            displayTitle: result.displayTitle,
            subtitlePath: result.subtitlePath,
            targetEntryID: result.cueGroupID
        )
    }

    func openShioriContext(_ item: Shiori, displayTitle: String) {
        let targetEntryID: Int64?
        if let database = subtitleDatabase {
            do {
                targetEntryID = try database.cueGroupID(
                    forSubtitlePath: item.subtitlePath,
                    startMilliseconds: item.startMilliseconds,
                    endMilliseconds: item.endMilliseconds
                ) ?? database.cueTextSelection(
                    forSubtitleFile: URL(fileURLWithPath: item.subtitlePath),
                    atMilliseconds: item.startMilliseconds
                )?.cueGroupID
            } catch {
                print("Failed to resolve Shiori context cue: \(error)")
                targetEntryID = nil
            }
        } else {
            targetEntryID = nil
        }

        guard let targetEntryID else {
            return
        }

        openCueContextSearch(
            displayTitle: displayTitle,
            subtitlePath: item.subtitlePath,
            targetEntryID: targetEntryID
        )
    }

    func openLibraryVideoContext(_ video: LibraryVideo, displayTitle: String) {
        guard let database = subtitleDatabase else {
            return
        }

        do {
            guard let targetEntryID = try database.firstCueGroupID(
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
                targetEntryID: targetEntryID
            )
        } catch {
            print("Failed to open Library video context: \(error)")
        }
    }

    func openCueContextSearch(
        displayTitle: String,
        subtitlePath: String,
        targetEntryID: Int64
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
            targetEntryID: targetEntryID
        )
        search.cueContextSearchRequest = request
        workbenchLayout.selectPanelMode(.search)
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
        let watchStateFilter = settings.searchScope.searchWatchStateFilter
        let filterSet = search.activeFilterSet
        let filterSignature = filterSet.cacheSignature

        guard !trimmedQuery.isEmpty,
              !folders.isEmpty,
              subtitleDatabase != nil
        else {
            return nil
        }
        let searchDatabaseURL = databaseURL

        let totalCount = search.searchResultTotalCount
        guard totalCount > 0 else { return nil }

        let lowerBound = min(max(0, range.lowerBound), totalCount)
        let upperBound = min(max(lowerBound, range.upperBound), totalCount)
        guard lowerBound < upperBound else { return nil }

        let resultCueIDs = search.searchResultCueIDs
        if resultCueIDs.count >= upperBound {
            let cueIDs = Array(resultCueIDs[lowerBound..<upperBound])
            let fileSummaries = search.searchFileSummaries
            do {
                let page = try await Task.detached(priority: .userInitiated) {
                    let pageDatabase = try SubtitleDatabase(path: searchDatabaseURL)
                    let indexWindow = SubtitleSearchResultIDIndexWindow(
                        cueIDs: cueIDs,
                        offset: lowerBound,
                        totalCount: totalCount,
                        fileSummaries: fileSummaries,
                        countSnapshot: .exact(
                            totalCount: totalCount,
                            fileSummaryCount: fileSummaries.count
                        ),
                        appliedCursor: SubtitleSearchCursor(offset: lowerBound),
                        nextCursor: upperBound < totalCount
                            ? SubtitleSearchCursor(offset: upperBound)
                            : nil
                    )
                    return try pageDatabase.searchIndexedVisiblePage(from: indexWindow)
                }.value

                guard !Task.isCancelled,
                      let page,
                      search.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines) == trimmedQuery,
                      indexing.selectedFolders.map(\.path) == folders.map(\.path),
                      settings.primarySearchLanguage.searchLanguageFilter == languageFilter,
                      settings.searchScope.searchWatchStateFilter == watchStateFilter,
                      search.activeFilterSetSignature == filterSignature,
                      search.searchResultCueIDs.count >= upperBound
                else {
                    return nil
                }

                return TableSandboxSearchHydrationPage(
                    range: lowerBound..<(lowerBound + page.results.count),
                    results: page.results,
                    totalRowCount: totalCount
                )
            } catch {
                return nil
            }
        }

        let fallbackUpperBound = max(
            loadedGlobalSearchResultCount + Self.searchPageSize,
            Self.searchPageSize
        )
        guard upperBound <= fallbackUpperBound else {
            return nil
        }

        do {
            let page = try await Task.detached(priority: .userInitiated) {
                let pageDatabase = try SubtitleDatabase(path: searchDatabaseURL)
                return try pageDatabase.searchVisiblePage(
                    trimmedQuery,
                    limit: upperBound - lowerBound,
                    cursor: SubtitleSearchCursor(offset: lowerBound),
                    under: folders,
                    languageFilter: languageFilter,
                    watchStateFilter: watchStateFilter,
                    filterSet: filterSet
                )
            }.value

            guard !Task.isCancelled,
                  search.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines) == trimmedQuery,
                  indexing.selectedFolders.map(\.path) == folders.map(\.path),
                  settings.primarySearchLanguage.searchLanguageFilter == languageFilter,
                  settings.searchScope.searchWatchStateFilter == watchStateFilter,
                  search.activeFilterSetSignature == filterSignature
            else {
                return nil
            }

            return TableSandboxSearchHydrationPage(
                range: lowerBound..<(lowerBound + page.results.count),
                results: page.results,
                totalRowCount: max(totalCount, page.totalCount)
            )
        } catch {
            return nil
        }
    }

    func loadTableSandboxAllCueRows(range: Range<Int>) async -> TableSandboxSearchHydrationPage? {
        let folders = indexing.selectedFolders
        let filterSet = search.activeFilterSet
        let filterSignature = filterSet.cacheSignature
        guard !folders.isEmpty,
              subtitleDatabase != nil
        else {
            return nil
        }
        let searchDatabaseURL = databaseURL
        let lowerBound = max(0, range.lowerBound)
        let upperBound = max(lowerBound, range.upperBound)
        guard lowerBound < upperBound else { return nil }

        do {
            let page = try await Task.detached(priority: .userInitiated) {
                let pageDatabase = try SubtitleDatabase(path: searchDatabaseURL)
                return try pageDatabase.allCueGroupsVisiblePage(
                    limit: upperBound - lowerBound,
                    cursor: SubtitleSearchCursor(offset: lowerBound),
                    under: folders,
                    filterSet: filterSet
                )
            }.value

            guard !Task.isCancelled,
                  indexing.selectedFolders.map(\.path) == folders.map(\.path),
                  search.activeFilterSetSignature == filterSignature
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

    func loadCueContextSearchPage(
        request: CueContextSearchRequest,
        range: Range<Int>,
        anchorWindowSize: Int = TableSandboxHydrationPaging.pageSize,
        anchorsInitialPage: Bool = false
    ) async -> TableSandboxSearchHydrationPage? {
        let folders = indexing.selectedFolders
        guard subtitleDatabase != nil else {
            return nil
        }
        let pageDatabaseURL = databaseURL
        let lowerBound = max(0, range.lowerBound)
        let upperBound = max(lowerBound, range.upperBound)
        guard lowerBound < upperBound else { return nil }

        do {
            let subtitlePath = request.subtitlePath
            let targetEntryID = request.targetEntryID
            let loadedPage = try await Task.detached(priority: .userInitiated) {
                let pageDatabase = try SubtitleDatabase(path: pageDatabaseURL)
                return try pageDatabase.cueContextSearchPage(
                    subtitlePath: subtitlePath,
                    targetCueGroupID: targetEntryID,
                    limit: upperBound - lowerBound,
                    cursor: SubtitleSearchCursor(offset: lowerBound),
                    anchorWindowSize: anchorWindowSize,
                    anchorsInitialPage: anchorsInitialPage,
                    under: folders
                )
            }.value
            guard let page = loadedPage else {
                return nil
            }

            guard !Task.isCancelled,
                  indexing.selectedFolders.map(\.path) == folders.map(\.path),
                  search.cueContextSearchRequest?.id == request.id
            else {
                return nil
            }

            return TableSandboxSearchHydrationPage(
                range: page.appliedCursor.offset..<(page.appliedCursor.offset + page.results.count),
                results: page.results,
                totalRowCount: page.totalCount
            )
        } catch {
            print("Failed to load Cue Context Search page: \(error)")
            return nil
        }
    }

    func applyTableSandboxAllCueSearchContext(_ page: TableSandboxSearchHydrationPage) {
        search.searchStatus = .completed
        search.searchResults = page.results
        search.searchResultCueIDs = page.results.map(\.entryID)
        search.searchResultTotalCount = page.totalRowCount
        search.searchCountState = .exact
        search.searchKnownResultCount = page.totalRowCount
        search.searchKnownFileCount = 0
        search.hasMoreSearchResults = page.range.upperBound < page.totalRowCount
        nextGlobalSearchCursor = search.hasMoreSearchResults
            ? SubtitleSearchCursor(offset: page.range.upperBound)
            : nil
    }

    var searchNavigationTotalCount: Int {
        max(
            search.searchNavigationSnapshot?.totalCount ?? 0,
            search.searchResultTotalCount,
            search.searchResults.count
        )
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
        let watchStateFilter = settings.searchScope.searchWatchStateFilter
        let filterSet = search.activeFilterSet
        let filterSignature = filterSet.cacheSignature
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
                        watchStateFilter: watchStateFilter,
                        filterSet: filterSet,
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

                guard search.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines) == trimmedQuery,
                      indexing.selectedFolders.map(\.path) == folders.map(\.path),
                      settings.primarySearchLanguage.searchLanguageFilter == languageFilter,
                      settings.searchScope.searchWatchStateFilter == watchStateFilter,
                      search.activeFilterSetSignature == filterSignature
                else {
                    SearchPerformanceLogger.mark(searchPerformanceRun, "search_stale_after_database")
                    SearchPerformanceLogger.writeE2ESearchPage(
                        searchPerformanceRun,
                        event: "search_stale_after_database",
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
                    search.searchResultCueIDs = []
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
                        watchStateFilter: watchStateFilter,
                        filterSet: filterSet,
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

    func applySearchCountProgress(
        _ progress: SubtitleSearchProgressSnapshot,
        query trimmedQuery: String,
        folderPaths: [String],
        languageFilter: SubtitleSearchLanguageFilter,
        watchStateFilter: SubtitleSearchWatchStateFilter,
        filterSignature: String,
        run searchPerformanceRun: SearchPerformanceRun?
    ) {
        guard progress.countState == .exactProgress,
              search.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines) == trimmedQuery,
              indexing.selectedFolders.map(\.path) == folderPaths,
              settings.primarySearchLanguage.searchLanguageFilter == languageFilter,
              settings.searchScope.searchWatchStateFilter == watchStateFilter,
              search.activeFilterSetSignature == filterSignature,
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

        if !progress.results.isEmpty {
            search.searchResults = progress.results
            search.searchResultCueIDs = progress.cueIDs
            loadedGlobalSearchResultCount = progress.results.count
        }
        search.searchResultTotalCount = progress.knownResultCount
        search.searchFileSummaries = progress.fileSummaries
        search.searchCountState = progress.countState
        search.searchKnownResultCount = progress.knownResultCount
        search.searchKnownFileCount = progress.knownFileCount
        search.hasMoreSearchResults = loadedGlobalSearchResultCount < search.searchResultTotalCount
        nextGlobalSearchCursor = search.hasMoreSearchResults
            ? (nextGlobalSearchCursor ?? SubtitleSearchCursor(offset: loadedGlobalSearchResultCount))
            : nil
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
        watchStateFilter: SubtitleSearchWatchStateFilter,
        filterSet: SubtitleSearchFilterSet,
        run searchPerformanceRun: SearchPerformanceRun?
    ) {
        searchExactCompletionTask?.cancel()

        guard let database = subtitleDatabase else {
            return
        }

        let completionResultLimit = 0
        let folderPaths = folders.map(\.path)
        let filterSignature = filterSet.cacheSignature
        let progressSink: SubtitleSearchProgressSink = { [weak self] snapshot in
            Task { @MainActor [weak self] in
                self?.applySearchCountProgress(
                    snapshot,
                    query: trimmedQuery,
                    folderPaths: folderPaths,
                    languageFilter: languageFilter,
                    watchStateFilter: watchStateFilter,
                    filterSignature: filterSignature,
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
                        limit: completionResultLimit,
                        cursor: .start,
                        under: folders,
                        languageFilter: languageFilter,
                        watchStateFilter: watchStateFilter,
                        filterSet: filterSet,
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
                      settings.primarySearchLanguage.searchLanguageFilter == languageFilter,
                      settings.searchScope.searchWatchStateFilter == watchStateFilter,
                      search.activeFilterSetSignature == filterSignature
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
                if !page.renderableResults.isEmpty {
                    search.searchResults = page.renderableResults
                    loadedGlobalSearchResultCount = page.renderableResults.count
                }
                search.searchResultCueIDs = page.cueIDs
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
                      settings.primarySearchLanguage.searchLanguageFilter == languageFilter,
                      settings.searchScope.searchWatchStateFilter == watchStateFilter,
                      search.activeFilterSetSignature == filterSignature
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
            let releasedRows = max(
                search.searchResults.count,
                search.searchResultCueIDs.count,
                search.searchResultTotalCount,
                search.renderedSearchResultCount
            )
            search.searchResults = []
            search.searchResultCueIDs = []
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
            AppMemoryPressureRelief.relieveAfterLargeResultRelease(estimatedReleasedRows: releasedRows)
        }

        updateSearchQuery(search.searchQuery)
    }

    func loadSearchNavigationSnapshot(opening direction: SearchResultNavigationDirection?) {
        searchNavigationTask?.cancel()

        let trimmedQuery = search.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !indexing.selectedFolders.isEmpty,
              let database = subtitleDatabase
        else {
            search.searchNavigationSnapshot = nil
            if let direction {
                playback.playbackViewModel?.showSearchNavigationFeedback(direction: direction, hasResult: false)
            }
            return
        }

        let folders = indexing.selectedFolders
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

        let languageFilter = settings.primarySearchLanguage.searchLanguageFilter
        let filterSet = search.activeFilterSet
        let filterSignature = filterSet.cacheSignature
        searchNavigationTask = Task { [weak self] in
            do {
                let snapshot = try await Task.detached(priority: .userInitiated) {
                    try database.searchNavigationSnapshotFromResultIDIndex(
                        trimmedQuery,
                        under: folders,
                        languageFilter: languageFilter,
                        filterSet: filterSet,
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

                guard self.settings.primarySearchLanguage.searchLanguageFilter == languageFilter,
                      self.search.activeFilterSetSignature == filterSignature
                else {
                    return
                }

                let resolvedSnapshot = snapshot ?? self.loadedSearchNavigationSnapshot(
                    anchor: anchor,
                    radius: panelRadius
                )
                guard let resolvedSnapshot else {
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
            } catch {
                guard !Task.isCancelled else {
                    return
                }

                print("Failed to load Search navigation snapshot: \(error)")
                self?.search.searchNavigationSnapshot = nil
            }
        }
    }

    private func loadAllCueSearchNavigationSnapshot(
        opening direction: SearchResultNavigationDirection?,
        anchor: SearchNavigationAnchor,
        radius: Int
    ) {
        let totalCount = searchNavigationTotalCount
        guard totalCount > 0 else {
            search.searchNavigationSnapshot = nil
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

        searchNavigationTask = Task { [weak self] in
            guard let self,
                  let page = await self.loadTableSandboxAllCueRows(range: requestedRange)
            else {
                return
            }

            guard !Task.isCancelled else {
                return
            }

            self.applyTableSandboxAllCueSearchContext(page)
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
        }
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
        search.searchNavigationSnapshot = snapshot
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

        search.searchNavigationSnapshot = nil
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
        let watchStateFilter = settings.searchScope.searchWatchStateFilter
        let filterSet = search.activeFilterSet
        let filterSignature = filterSet.cacheSignature
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
                        languageFilter: languageFilter,
                        watchStateFilter: watchStateFilter,
                        filterSet: filterSet
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
                      self.settings.searchScope.searchWatchStateFilter == watchStateFilter,
                      self.search.activeFilterSetSignature == filterSignature,
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
        let releasedRows = max(
            search.searchResults.count,
            search.searchResultCueIDs.count,
            search.searchResultTotalCount,
            search.renderedSearchResultCount
        )
        search.searchResults = []
        search.searchResultCueIDs = []
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
        rebuildSearchResultGroups()
        AppMemoryPressureRelief.relieveAfterLargeResultRelease(estimatedReleasedRows: releasedRows)
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
