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
        search.isPlaybackTemporaryFilterActive = true
    }

    func updatePlaybackSearchQuery(_ query: String) {
        UIInvalidationProbe.mark(
            "ACTION UI.PlaybackSearchQuery.changed",
            details: "length=\(query.count)"
        )
        search.searchQuery = query
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
        guard search.isPlaybackTemporaryFilterActive else {
            return
        }

        search.isPlaybackTemporaryFilterActive = false
        if committingEmptyFilter {
            let emptyFilterSet = SubtitleSearchFilterSet()
            search.activeFilterSet = emptyFilterSet
            search.resultFilterSet = emptyFilterSet
            return
        }

        guard search.resultFilterSetSignature != search.activeFilterSetSignature else {
            return
        }
        startSearch(
            query: search.searchQuery,
            cursor: .start,
            appending: false,
            debounce: false,
            filterSetOverride: search.activeFilterSet
        )
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
        guard let database = search.database else {
            return
        }

        do {
            guard let targetCueID = try database.firstCueID(
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
        search.cueContextSearchRequest = request
        workbenchLayout.selectPanelMode(.search)
    }

    func loadMoreSearchResultsIfNeeded(currentResult result: SubtitleSearchResult) {
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

    func loadTableSandboxSearchRows(range: Range<Int>) async -> TableSandboxSearchHydrationPage? {
        let trimmedQuery = search.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let folders = indexing.selectedFolders
        let languageFilter = settings.primarySearchLanguage.searchLanguageFilter
        let watchStateFilter = settings.searchScope.searchWatchStateFilter
        let filterSet = search.resultFilterSet
        let filterSignature = filterSet.cacheSignature

        guard !trimmedQuery.isEmpty,
              !folders.isEmpty,
              search.database != nil,
              let searchDatabaseURL = search.databaseURL
        else {
            return nil
        }

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
                let page = try await Self.runCancellableDetached(
                    priority: .userInitiated
                ) {
                    let pageDatabase = try SearchDatabase(
                        path: searchDatabaseURL,
                        access: .readOnly
                    )
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
                }

                guard !Task.isCancelled,
                      let page,
                      search.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines) == trimmedQuery,
                      indexing.selectedFolders.map(\.path) == folders.map(\.path),
                      settings.primarySearchLanguage.searchLanguageFilter == languageFilter,
                      settings.searchScope.searchWatchStateFilter == watchStateFilter,
                      search.resultFilterSetSignature == filterSignature,
                      search.searchResultCueIDs.count >= upperBound
                else {
                    return nil
                }

                cueContent.install(page.results.map(\.cueContent))
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
            search.loadedGlobalResultCount + Self.searchPageSize,
            Self.searchPageSize
        )
        guard upperBound <= fallbackUpperBound else {
            return nil
        }

        do {
            let page = try await Self.runCancellableDetached(
                priority: .userInitiated
            ) {
                let pageDatabase = try SearchDatabase(
                    path: searchDatabaseURL,
                    access: .readOnly
                )
                return try pageDatabase.searchVisiblePage(
                    trimmedQuery,
                    limit: upperBound - lowerBound,
                    cursor: SubtitleSearchCursor(offset: lowerBound),
                    under: folders,
                    languageFilter: languageFilter,
                    watchStateFilter: watchStateFilter,
                    filterSet: filterSet
                )
            }

            guard !Task.isCancelled,
                  search.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines) == trimmedQuery,
                  indexing.selectedFolders.map(\.path) == folders.map(\.path),
                  settings.primarySearchLanguage.searchLanguageFilter == languageFilter,
                  settings.searchScope.searchWatchStateFilter == watchStateFilter,
                  search.resultFilterSetSignature == filterSignature
            else {
                return nil
            }

            cueContent.install(page.results.map(\.cueContent))
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
              search.database != nil,
              let searchDatabaseURL = search.databaseURL
        else {
            return nil
        }
        let lowerBound = max(0, range.lowerBound)
        let upperBound = max(lowerBound, range.upperBound)
        guard lowerBound < upperBound else { return nil }

        do {
            let page = try await Self.runCancellableDetached(
                priority: .userInitiated
            ) {
                let pageDatabase = try SearchDatabase(
                    path: searchDatabaseURL,
                    access: .readOnly
                )
                return try pageDatabase.allCuesVisiblePage(
                    limit: upperBound - lowerBound,
                    cursor: SubtitleSearchCursor(offset: lowerBound),
                    under: folders,
                    filterSet: filterSet
                )
            }

            guard !Task.isCancelled,
                  indexing.selectedFolders.map(\.path) == folders.map(\.path),
                  search.activeFilterSetSignature == filterSignature
            else {
                return nil
            }

            cueContent.install(page.results.map(\.cueContent))
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
        guard search.database != nil,
              let pageDatabaseURL = search.databaseURL
        else {
            return nil
        }
        let lowerBound = max(0, range.lowerBound)
        let upperBound = max(lowerBound, range.upperBound)
        guard lowerBound < upperBound else { return nil }

        do {
            let subtitlePath = request.subtitlePath
            let targetCueID = request.targetCueID
            let loadedPage = try await Task.detached(priority: .userInitiated) {
                let pageDatabase = try SearchDatabase(
                    path: pageDatabaseURL,
                    access: .readOnly
                )
                return try pageDatabase.cueContextSearchPage(
                    subtitlePath: subtitlePath,
                    targetCueID: targetCueID,
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

            cueContent.install(page.results.map(\.cueContent))
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
        search.replaceLoadedSearchResults(
            page.results,
            orderedCueIDs: page.results.map(\.entryID)
        )
        search.searchResultTotalCount = page.totalRowCount
        search.searchCountState = .exact
        search.searchKnownResultCount = page.totalRowCount
        search.searchKnownFileCount = 0
        search.hasMoreSearchResults = page.range.upperBound < page.totalRowCount
        search.nextGlobalCursor = search.hasMoreSearchResults
            ? SubtitleSearchCursor(offset: page.range.upperBound)
            : nil
        refreshSearchPlaybackPlaylistSource(
            resultListGeneration: search.resultListGeneration
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
        filterSetOverride: SubtitleSearchFilterSet? = nil
    ) {
        if !appending {
            search.resultListGeneration &+= 1
        }
        let resultListGeneration = search.resultListGeneration
        if pendingURLSchemeDirectPlayIntent?.id != urlSchemeIntentID {
            pendingURLSchemeDirectPlayIntent = nil
        }
        search.searchTask?.cancel()
        if !appending {
            search.exactCompletionTask?.cancel()
            search.exactCompletionTask = nil
        }

        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let folders = indexing.selectedFolders
        let pageSize = Self.searchPageSize
        let offset = cursor.offset
        let languageFilter = settings.primarySearchLanguage.searchLanguageFilter
        let watchStateFilter = settings.searchScope.searchWatchStateFilter
        let filterSet = appending
            ? search.resultFilterSet
            : (filterSetOverride ?? search.activeFilterSet)
        let filterSignature = filterSet.cacheSignature
        if !appending {
            search.resultFilterSet = filterSet
        }
        if let activePerformanceRun = search.activePerformanceRun {
            SearchPerformanceLogger.mark(activePerformanceRun, "search_superseded_by_new_search")
            SearchPerformanceLogger.writeE2ESearchPage(
                activePerformanceRun,
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
        search.activePerformanceRun = searchPerformanceRun

        if !appending {
            let resetStart = SearchPerformanceLogger.now()
            resetSearchResultLoadingState()
            SearchPerformanceLogger.mark(
                searchPerformanceRun,
                "search_state_reset",
                phaseStart: resetStart,
                groupCount: search.searchFileSummaries.count,
                renderedRowCount: search.searchResults.count,
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
            resolveURLSchemeDirectPlayIntent(id: urlSchemeIntentID, firstPageResult: nil)
            return
        }

        guard !folders.isEmpty else {
            search.searchStatus = .completed
            if activePlaybackSource != .search || !isPlaybackPageVisible {
                search.selectedSearchResult = nil
            }
            SearchPerformanceLogger.mark(searchPerformanceRun, "search_skipped_no_folders", status: "completed")
            SearchPerformanceLogger.writeE2ESearchPage(
                searchPerformanceRun,
                event: "search_skipped_no_folders",
                page: nil,
                status: "completed"
            )
            clearSearchPerformanceRunIfActive(searchPerformanceRun)
            resolveURLSchemeDirectPlayIntent(id: urlSchemeIntentID, firstPageResult: nil)
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
            resolveURLSchemeDirectPlayIntent(id: urlSchemeIntentID, firstPageResult: nil)
            return
        }

        guard let database = search.database else {
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
            resolveURLSchemeDirectPlayIntent(id: urlSchemeIntentID, firstPageResult: nil)
            return
        }
        UIInvalidationProbe.count(
            "search.query_requested",
            scope: uiProbeScope,
            details: "offset=\(offset) appending=\(appending)"
        )
        search.searchTask = Task {
            do {
                if debounce {
                    let debounceStart = SearchPerformanceLogger.now()
                    try await Task.sleep(nanoseconds: Self.searchInputDebounceNanoseconds)
                    SearchPerformanceLogger.mark(
                        searchPerformanceRun,
                        "search_debounce_finished",
                        phaseStart: debounceStart
                    )
                }

                SearchPerformanceLogger.mark(searchPerformanceRun, "database_search_started")
                let diagnosticsSink = SearchPerformanceLogger.coreDiagnosticsSink(for: searchPerformanceRun)
                let pageLoad = try await Self.runCancellableDetached(priority: .userInitiated) {
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
                }
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

                guard resultListGeneration == search.resultListGeneration,
                      search.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines) == trimmedQuery,
                      indexing.selectedFolders.map(\.path) == folders.map(\.path),
                      settings.primarySearchLanguage.searchLanguageFilter == languageFilter,
                      settings.searchScope.searchWatchStateFilter == watchStateFilter,
                      search.resultFilterSetSignature == filterSignature
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
                    search.loadedGlobalResultCount = max(
                        search.loadedGlobalResultCount,
                        offset + page.results.count
                    )
                } else {
                    search.replaceLoadedSearchResults(page.results)
                    search.loadedGlobalResultCount = page.results.count
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
                search.nextGlobalCursor = page.nextCursor
                refreshSearchPlaybackPlaylistSource(
                    resultListGeneration: resultListGeneration
                )
                let stateAssignMilliseconds = SearchPerformanceLogger.elapsedMilliseconds(since: stateAssignStart)
                SearchPerformanceLogger.mark(
                    searchPerformanceRun,
                    "search_state_assigned",
                    phaseStart: stateAssignStart,
                    resultCount: search.searchResults.count,
                    totalCount: search.searchResultTotalCount,
                    fileSummaryCount: search.searchFileSummaries.count
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
                    groupCount: search.searchFileSummaries.count,
                    renderedRowCount: search.searchResults.count,
                    status: statusText
                )
                SearchPerformanceLogger.writeE2ESearchPage(
                    searchPerformanceRun,
                    event: eventName,
                    page: page,
                    databaseSearchMilliseconds: pageLoad.databaseSearchMilliseconds,
                    stateAssignMilliseconds: stateAssignMilliseconds,
                    statusCompletionMilliseconds: statusCompletionMilliseconds,
                    groupCount: search.searchFileSummaries.count,
                    renderedRowCount: search.searchResults.count,
                    status: statusText
                )
                let consumedURLSchemeIntent = resolveURLSchemeDirectPlayIntent(
                    id: urlSchemeIntentID,
                    firstPageResult: page.results.first
                )
                if !appending && !pageCompletesSearch {
                    startSearchExactCompletion(
                        query: trimmedQuery,
                        folders: folders,
                        languageFilter: languageFilter,
                        watchStateFilter: watchStateFilter,
                        filterSet: filterSet,
                        resultListGeneration: resultListGeneration,
                        run: searchPerformanceRun
                    )
                }
                if page.results.isEmpty {
                    SearchPerformanceLogger.mark(searchPerformanceRun, "search_no_result_rows_to_render")
                    clearSearchPerformanceRunIfActive(searchPerformanceRun)
                } else if consumedURLSchemeIntent {
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
                        groupCount: search.searchFileSummaries.count,
                        renderedRowCount: search.searchResults.count
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
                    groupCount: search.searchFileSummaries.count,
                    renderedRowCount: search.searchResults.count,
                    status: "failed",
                    error: message
                )
                clearSearchPerformanceRunIfActive(searchPerformanceRun)
                resolveURLSchemeDirectPlayIntent(id: urlSchemeIntentID, firstPageResult: nil)
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
        resultListGeneration: UInt64 = 0,
        run searchPerformanceRun: SearchPerformanceRun?
    ) {
        guard resultListGeneration == search.resultListGeneration,
              progress.countState == .exactProgress,
              search.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines) == trimmedQuery,
              indexing.selectedFolders.map(\.path) == folderPaths,
              settings.primarySearchLanguage.searchLanguageFilter == languageFilter,
              settings.searchScope.searchWatchStateFilter == watchStateFilter,
              search.resultFilterSetSignature == filterSignature,
              search.searchCountState != .exact,
              progress.knownResultCount >= search.searchKnownResultCount,
              progress.knownFileCount >= search.searchKnownFileCount
        else {
            return
        }

        let now = SearchPerformanceLogger.now()
        if search.lastCountProgressUpdate != 0,
           now - search.lastCountProgressUpdate < Self.searchCountProgressMinimumIntervalNanoseconds {
            return
        }
        search.lastCountProgressUpdate = now

        if !progress.results.isEmpty {
            search.replaceLoadedSearchResults(
                progress.results,
                orderedCueIDs: progress.cueIDs
            )
            search.loadedGlobalResultCount = progress.results.count
        }
        search.searchResultTotalCount = progress.knownResultCount
        search.searchFileSummaries = progress.fileSummaries
        search.searchCountState = progress.countState
        search.searchKnownResultCount = progress.knownResultCount
        search.searchKnownFileCount = progress.knownFileCount
        search.hasMoreSearchResults = search.loadedGlobalResultCount < search.searchResultTotalCount
        search.nextGlobalCursor = search.hasMoreSearchResults
            ? (search.nextGlobalCursor ?? SubtitleSearchCursor(offset: search.loadedGlobalResultCount))
            : nil
        refreshSearchPlaybackPlaylistSource(
            resultListGeneration: resultListGeneration
        )

        SearchPerformanceLogger.mark(
            searchPerformanceRun,
            "search_count_progress",
            resultCount: search.searchResults.count,
            totalCount: search.searchResultTotalCount,
            fileSummaryCount: search.searchFileSummaries.count,
            groupCount: search.searchFileSummaries.count,
            renderedRowCount: search.searchResults.count,
            status: "searching"
        )
        SearchPerformanceLogger.writeE2ECountProgress(
            searchPerformanceRun,
            progress: progress,
            resultCount: search.searchResults.count,
            groupCount: search.searchFileSummaries.count,
            renderedRowCount: search.searchResults.count
        )
    }

    func startSearchExactCompletion(
        query trimmedQuery: String,
        folders: [URL],
        languageFilter: SubtitleSearchLanguageFilter,
        watchStateFilter: SubtitleSearchWatchStateFilter,
        filterSet: SubtitleSearchFilterSet,
        resultListGeneration: UInt64,
        run searchPerformanceRun: SearchPerformanceRun?
    ) {
        search.exactCompletionTask?.cancel()

        guard let database = search.database else {
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
                    resultListGeneration: resultListGeneration,
                    run: searchPerformanceRun
                )
            }
        }
        search.exactCompletionTask = Task {
            do {
                SearchPerformanceLogger.mark(searchPerformanceRun, "database_exact_completion_started")
                let diagnosticsSink = SearchPerformanceLogger.coreDiagnosticsSink(for: searchPerformanceRun)
                let pageLoad = try await Self.runCancellableDetached(priority: .utility) {
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
                }
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

                guard resultListGeneration == search.resultListGeneration,
                      search.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines) == trimmedQuery,
                      indexing.selectedFolders.map(\.path) == folderPaths,
                      settings.primarySearchLanguage.searchLanguageFilter == languageFilter,
                      settings.searchScope.searchWatchStateFilter == watchStateFilter,
                      search.resultFilterSetSignature == filterSignature
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
                    search.replaceLoadedSearchResults(
                        page.renderableResults,
                        orderedCueIDs: page.cueIDs
                    )
                    search.loadedGlobalResultCount = page.renderableResults.count
                } else {
                    search.searchResultCueIDs = page.cueIDs
                }
                search.searchResultTotalCount = page.totalCount
                search.searchFileSummaries = page.fileSummaries
                search.searchCountState = page.countState
                search.searchKnownResultCount = page.knownResultCount
                search.searchKnownFileCount = page.knownFileCount
                search.hasMoreSearchResults = search.loadedGlobalResultCount < page.totalCount
                search.nextGlobalCursor = search.hasMoreSearchResults
                    ? (search.nextGlobalCursor ?? SubtitleSearchCursor(offset: search.loadedGlobalResultCount))
                    : nil
                refreshSearchPlaybackPlaylistSource(
                    resultListGeneration: resultListGeneration
                )
                let stateAssignMilliseconds = SearchPerformanceLogger.elapsedMilliseconds(since: stateAssignStart)

                let completionStart = SearchPerformanceLogger.now()
                search.searchStatus = .completed
                search.exactCompletionTask = nil
                let statusCompletionMilliseconds = SearchPerformanceLogger.elapsedMilliseconds(since: completionStart)
                SearchPerformanceLogger.mark(
                    searchPerformanceRun,
                    "search_status_completed",
                    phaseStart: completionStart,
                    resultCount: search.searchResults.count,
                    totalCount: search.searchResultTotalCount,
                    fileSummaryCount: search.searchFileSummaries.count,
                    groupCount: search.searchFileSummaries.count,
                    renderedRowCount: search.searchResults.count,
                    status: "completed"
                )
                SearchPerformanceLogger.writeE2ESearchPage(
                    searchPerformanceRun,
                    event: "search_status_completed",
                    page: page,
                    databaseSearchMilliseconds: pageLoad.databaseSearchMilliseconds,
                    stateAssignMilliseconds: stateAssignMilliseconds,
                    statusCompletionMilliseconds: statusCompletionMilliseconds,
                    groupCount: search.searchFileSummaries.count,
                    renderedRowCount: search.searchResults.count,
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

                guard resultListGeneration == search.resultListGeneration,
                      search.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines) == trimmedQuery,
                      indexing.selectedFolders.map(\.path) == folderPaths,
                      settings.primarySearchLanguage.searchLanguageFilter == languageFilter,
                      settings.searchScope.searchWatchStateFilter == watchStateFilter,
                      search.resultFilterSetSignature == filterSignature
                else {
                    SearchPerformanceLogger.mark(searchPerformanceRun, "search_exact_completion_error_stale")
                    return
                }

                let message = Self.errorMessage(for: error)
                search.searchStatus = .failed(message)
                search.exactCompletionTask = nil
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
                    groupCount: search.searchFileSummaries.count,
                    renderedRowCount: search.searchResults.count,
                    status: "failed",
                    error: message
                )
            }
        }
    }

    func clearSearchPerformanceRunIfActive(_ run: SearchPerformanceRun?) {
        guard let run, search.activePerformanceRun?.id == run.id else {
            return
        }

        search.activePerformanceRun = nil
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

    func refreshCurrentSearch(clearExistingResults: Bool = false) {
        guard !search.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        if clearExistingResults {
            let releasedRows = max(
                search.searchResults.count,
                search.searchResultCueIDs.count,
                search.searchResultTotalCount
            )
            search.searchResults = []
            search.searchResultCueIDs = []
            search.searchResultTotalCount = 0
            search.searchFileSummaries = []
            search.searchCountState = .exact
            search.searchKnownResultCount = 0
            search.searchKnownFileCount = 0
            search.hasMoreSearchResults = false
            search.loadedGlobalResultCount = 0
            search.lastCountProgressUpdate = 0
            search.nextGlobalCursor = nil
            AppMemoryPressureRelief.relieveAfterLargeResultRelease(estimatedReleasedRows: releasedRows)
        }

        updateSearchQuery(search.searchQuery)
    }

    func refreshSearchForLibraryWatchStateChange() {
        guard settings.searchScope != .all else {
            return
        }

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
        search.navigationTask?.cancel()

        let trimmedQuery = search.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !indexing.selectedFolders.isEmpty,
              search.database != nil
        else {
            search.searchNavigationSnapshot = nil
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

        let languageFilter = settings.primarySearchLanguage.searchLanguageFilter
        let filterSet = search.resultFilterSet
        let filterSignature = filterSet.cacheSignature
        search.navigationTask = Task { [weak self] in
            guard !Task.isCancelled, let self else {
                return
            }
            guard self.settings.primarySearchLanguage.searchLanguageFilter == languageFilter,
                  self.search.resultFilterSetSignature == filterSignature
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

        search.navigationTask = Task { [weak self] in
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

    func revealInitialGlobalSearchResultPage() {
        search.searchResults = Array(search.searchResults.prefix(Self.searchPageSize))
        search.loadedGlobalResultCount = search.searchResults.count
        search.searchKnownResultCount = search.searchResultTotalCount
        search.searchKnownFileCount = search.searchFileSummaries.count
        search.hasMoreSearchResults = search.loadedGlobalResultCount < search.searchResultTotalCount
        search.nextGlobalCursor = search.hasMoreSearchResults
            ? SubtitleSearchCursor(offset: search.loadedGlobalResultCount)
            : nil
    }

    func appendGlobalSearchResults(_ results: [SubtitleSearchResult]) {
        let existingEntryIDs = Set(search.searchResults.map(\.entryID))
        search.searchResults = search.searchResults
            + results.filter { !existingEntryIDs.contains($0.entryID) }
    }

    func resetSearchResultLoadingState() {
        search.exactCompletionTask?.cancel()
        search.exactCompletionTask = nil
        search.navigationTask?.cancel()
        let releasedRows = max(
            search.searchResults.count,
            search.searchResultCueIDs.count,
            search.searchResultTotalCount
        )
        search.searchResults = []
        search.searchResultCueIDs = []
        search.searchResultTotalCount = 0
        search.searchFileSummaries = []
        search.searchCountState = .exact
        search.searchKnownResultCount = 0
        search.searchKnownFileCount = 0
        search.hasMoreSearchResults = false
        search.lastCountProgressUpdate = 0
        search.loadedGlobalResultCount = 0
        search.nextGlobalCursor = nil
        search.searchNavigationSnapshot = nil
        AppMemoryPressureRelief.relieveAfterLargeResultRelease(estimatedReleasedRows: releasedRows)
    }
}
