import Foundation
import CueSeekerCore

private struct SearchStorePageLoad: Sendable {
    let page: SubtitleSearchPage
    /// The rows the scan reported batch by batch before its page.
    var reportedResults: [SubtitleSearchResult] = []
    let databaseSearchMilliseconds: Double
}

/// The rows the scan reports while it runs, collected on its own thread. The
/// first page is taken from them as soon as it is complete; the rest reach the
/// table once, with the completed result.
private final class SearchReportedRows: @unchecked Sendable {
    var results: [SubtitleSearchResult] = []
}

@MainActor
extension SearchStore {
    static let searchPageSize = 100
    /// The most rows one read by cue ID asks for, as many as a scan batch.
    static let searchRowReadBatchSize = 5_000
    static let searchPrefetchThreshold = 10
    static let searchInputDebounceNanoseconds: UInt64 = 100_000_000

    func startSearch(
        query: String,
        cursor: SubtitleSearchCursor,
        appending: Bool,
        debounce: Bool,
        folders: [URL],
        languageFilter: SubtitleSearchLanguageFilter,
        watchStateFilter: SubtitleSearchWatchStateFilter,
        databaseIsCompacting: Bool,
        shouldClearSelectionWhenUnavailable: Bool,
        filterSetOverride: SubtitleSearchFilterSet? = nil,
        probeScope: String? = nil,
        isContextCurrent: @escaping @MainActor () -> Bool,
        onResultsChanged: @escaping @MainActor (UInt64) -> Void,
        onFirstPageResolved: @escaping @MainActor (SubtitleSearchResult?) -> Bool
    ) {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let pageSize = Self.searchPageSize
        let offset = cursor.offset
        let filterSet = appending
            ? resultFilterSet
            : (filterSetOverride ?? activeFilterSet)
        let filterSignature = filterSet.cacheSignature
        let scopeGeneration = folderScopeGeneration
        let generation = prepareSearch(
            appending: appending,
            filterSet: filterSet
        )
        let facetFilter = resultFacetFilter

        if let activePerformanceRun {
            SearchPerformanceLogger.mark(
                activePerformanceRun,
                "search_superseded_by_new_search"
            )
        }
        let run = SearchPerformanceLogger.startRun(
            query: trimmedQuery,
            queryLength: trimmedQuery.count,
            offset: offset,
            cursor: cursor,
            limit: pageSize,
            appending: appending,
            debounce: debounce,
            folderPaths: folders.map(\.path)
        )
        updateActivePerformanceRun(run)

        if !appending {
            let resetStart = SearchPerformanceLogger.now()
            resetResultLoadingState()
            SearchPerformanceLogger.mark(
                run,
                "search_state_reset",
                phaseStart: resetStart,
                groupCount: searchFileSummaries.count,
                renderedRowCount: searchResults.count,
                status: "reset"
            )
        }

        guard !trimmedQuery.isEmpty else {
            markSearchIdle()
            finishSkippedSearch(
                run: run,
                event: "search_skipped_empty_query",
                status: "idle",
                onFirstPageResolved: onFirstPageResolved
            )
            return
        }

        guard !folders.isEmpty else {
            markSearchCompleted()
            if shouldClearSelectionWhenUnavailable {
                selectResult(nil)
            }
            finishSkippedSearch(
                run: run,
                event: "search_skipped_no_folders",
                status: "completed",
                onFirstPageResolved: onFirstPageResolved
            )
            return
        }

        markSearchInProgress()
        SearchPerformanceLogger.mark(run, "search_status_searching", status: "searching")

        guard !databaseIsCompacting else {
            failBeforeSearch(
                L("status.compaction_running"),
                event: "search_failed_database_compacting",
                run: run,
                onFirstPageResolved: onFirstPageResolved
            )
            return
        }

        guard let database else {
            failBeforeSearch(
                L("status.database_not_initialized"),
                event: "search_failed_no_database",
                run: run,
                onFirstPageResolved: onFirstPageResolved
            )
            return
        }

        UIInvalidationProbe.count(
            "search.query_requested",
            scope: probeScope,
            details: "offset=\(offset) appending=\(appending)"
        )
        replaceSearchTask(Task { [weak self] in
            guard let self else { return }
            do {
                if debounce {
                    let debounceStart = SearchPerformanceLogger.now()
                    try await Task.sleep(
                        nanoseconds: Self.searchInputDebounceNanoseconds
                    )
                    SearchPerformanceLogger.mark(
                        run,
                        "search_debounce_finished",
                        phaseStart: debounceStart
                    )
                }

                SearchPerformanceLogger.mark(run, "database_search_started")
                let diagnostics = SearchPerformanceLogger.coreDiagnosticsSink(for: run)
                let (firstPages, firstPageContinuation) = AsyncStream.makeStream(
                    of: SearchStorePageLoad.self
                )
                // Not `async let`: in release builds Swift 6.1 frees an async let
                // with a result this large out of order, and the runtime aborts
                // the App as the search finishes.
                let scan = Task.detached(priority: .userInitiated) {
                    defer { firstPageContinuation.finish() }
                    let started = SearchPerformanceLogger.now()
                    guard !appending else {
                        let page = try database.searchVisiblePage(
                            trimmedQuery,
                            limit: pageSize,
                            cursor: cursor,
                            under: folders,
                            languageFilter: languageFilter,
                            watchStateFilter: watchStateFilter,
                            filterSet: filterSet,
                            facetFilter: facetFilter,
                            diagnostics: diagnostics
                        )
                        return SearchStorePageLoad(
                            page: page,
                            databaseSearchMilliseconds:
                                SearchPerformanceLogger.elapsedMilliseconds(since: started)
                        )
                    }
                    // One scan reads every match. Its first page reaches the table
                    // as soon as the scan has found it, and the rest once, with the
                    // completed result.
                    let reportedRows = SearchReportedRows()
                    let page = try database.searchPage(
                        trimmedQuery,
                        limit: pageSize,
                        cursor: .start,
                        under: folders,
                        languageFilter: languageFilter,
                        watchStateFilter: watchStateFilter,
                        filterSet: filterSet,
                        facetFilter: facetFilter,
                        diagnostics: diagnostics,
                        progress: { progress in
                            let hadFirstPage = reportedRows.results.count >= pageSize
                            reportedRows.results += progress.results
                            guard !hadFirstPage, reportedRows.results.count >= pageSize else {
                                return
                            }
                            firstPageContinuation.yield(SearchStorePageLoad(
                                page: SubtitleSearchPage(
                                    results: Array(reportedRows.results.prefix(pageSize)),
                                    totalCount: pageSize,
                                    fileSummaries: progress.fileSummaries,
                                    countSnapshot: .exactProgress(
                                        knownResultCount: pageSize,
                                        knownFileCount: progress.knownFileCount
                                    ),
                                    nextCursor: SubtitleSearchCursor(offset: pageSize),
                                    pageMode: .visibleWindow
                                ),
                                databaseSearchMilliseconds:
                                    SearchPerformanceLogger.elapsedMilliseconds(since: started)
                            ))
                        }
                    )
                    return SearchStorePageLoad(
                        page: page,
                        reportedResults: reportedRows.results,
                        databaseSearchMilliseconds:
                            SearchPerformanceLogger.elapsedMilliseconds(since: started)
                    )
                }

                @MainActor func isCurrent() -> Bool {
                    generation == self.resultListGeneration
                        && self.searchQuery.trimmingCharacters(
                            in: .whitespacesAndNewlines
                        ) == trimmedQuery
                        && self.resultFilterSetSignature == filterSignature
                        && isContextCurrent()
                }

                var publishedFirstPage = false
                var consumedFirstPage = false
                for await firstPage in firstPages where isCurrent() {
                    self.commitVisibleSearchPage(firstPage.page, appending: false, offset: 0)
                    onResultsChanged(generation)
                    publishedFirstPage = true
                    SearchPerformanceLogger.mark(
                        run,
                        "search_visible_page_loaded",
                        resultCount: self.loadedSearchResultCueIDs.count,
                        totalCount: self.searchResultTotalCount,
                        fileSummaryCount: self.searchFileSummaries.count,
                        groupCount: self.searchFileSummaries.count,
                        renderedRowCount: self.loadedSearchResultCueIDs.count,
                        status: "searching"
                    )
                    consumedFirstPage = onFirstPageResolved(firstPage.page.results.first)
                }
                let pageLoad = try await withTaskCancellationHandler {
                    try await scan.value
                } onCancel: {
                    scan.cancel()
                }
                let page = pageLoad.page

                guard !Task.isCancelled else {
                    self.logCancelledPage(
                        run: run,
                        event: "search_cancelled_after_database",
                        page: page,
                        databaseSearchMilliseconds: pageLoad.databaseSearchMilliseconds
                    )
                    return
                }
                guard isCurrent() else {
                    self.logCancelledPage(
                        run: run,
                        event: "search_stale_after_database",
                        page: page,
                        databaseSearchMilliseconds: pageLoad.databaseSearchMilliseconds
                    )
                    return
                }

                let stateAssignStart = SearchPerformanceLogger.now()
                if appending {
                    self.commitVisibleSearchPage(page, appending: true, offset: offset)
                } else {
                    self.commitExactSearchPage(
                        page,
                        reportedResults: pageLoad.reportedResults,
                        generation: generation
                    )
                }
                onResultsChanged(generation)
                let stateAssignMilliseconds =
                    SearchPerformanceLogger.elapsedMilliseconds(since: stateAssignStart)

                let completionStart = SearchPerformanceLogger.now()
                let statusCompletionMilliseconds =
                    SearchPerformanceLogger.elapsedMilliseconds(since: completionStart)
                let statusText = page.countState == .exact
                    ? "completed"
                    : "searching"
                let event = page.countState == .exact
                    ? "search_status_completed"
                    : "search_visible_page_loaded"
                SearchPerformanceLogger.mark(
                    run,
                    event,
                    phaseStart: completionStart,
                    resultCount: self.loadedSearchResultCueIDs.count,
                    totalCount: self.searchResultTotalCount,
                    fileSummaryCount: self.searchFileSummaries.count,
                    groupCount: self.searchFileSummaries.count,
                    renderedRowCount: self.loadedSearchResultCueIDs.count,
                    status: statusText
                )

                if !publishedFirstPage {
                    consumedFirstPage = onFirstPageResolved(page.results.first)
                }
                if page.results.isEmpty {
                    SearchPerformanceLogger.mark(
                        run,
                        "search_no_result_rows_to_render"
                    )
                    self.clearPerformanceRunIfActive(run)
                } else if consumedFirstPage {
                    self.clearPerformanceRunIfActive(run)
                }
            } catch is CancellationError {
                self.logCancelledPage(
                    run: run,
                    event: "search_cancelled",
                    page: nil,
                    databaseSearchMilliseconds: nil
                )
            } catch {
                guard !Task.isCancelled,
                      self.acceptsFolderScope(
                        folders,
                        generation: scopeGeneration
                      )
                else {
                    self.logCancelledPage(
                        run: run,
                        event: "search_cancelled_after_error",
                        page: nil,
                        databaseSearchMilliseconds: nil
                    )
                    return
                }
                if !appending {
                    self.resetResultLoadingState()
                }
                let message = String(describing: error)
                self.markSearchFailed(message, hasMore: false)
                SearchPerformanceLogger.mark(
                    run,
                    "search_failed",
                    status: "failed",
                    error: message
                )
                self.clearPerformanceRunIfActive(run)
                _ = onFirstPageResolved(nil)
            }
        })
    }

    /// Requirement 4.4: answers a changed selection from the completed result's
    /// snapshot and hands the table the whole result at once. The rows whose
    /// contents are not in memory, the matches outside the old selection, are
    /// read by cue ID first. Returns false when the search has not completed,
    /// in which case a search must run.
    func applyProjectedFacetFilter(
        _ filter: CueFacetFilter,
        folders: [URL],
        languageFilter: SubtitleSearchLanguageFilter,
        watchStateFilter: SubtitleSearchWatchStateFilter,
        onResultsChanged: @escaping @MainActor (UInt64) -> Void
    ) -> Bool {
        let normalizedFilter = normalizedFacetFilter(filter)
        guard (searchFacetFilter != normalizedFilter || resultFacetFilter != normalizedFilter),
              searchFacetSnapshot != nil
        else {
            return false
        }
        let trimmedQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let run = SearchPerformanceLogger.startRun(
            query: trimmedQuery,
            queryLength: trimmedQuery.count,
            offset: 0,
            cursor: .start,
            limit: Self.searchPageSize,
            appending: false,
            debounce: false,
            folderPaths: folders.map(\.path)
        )
        updateActivePerformanceRun(run)
        guard let projection = projectSearchFacetFilter(filter) else {
            return false
        }
        let generation = resultListGeneration
        SearchPerformanceLogger.mark(
            run,
            "search_facet_projection_applied",
            resultCount: 0,
            totalCount: projection.cueIDs.count,
            status: "completed"
        )
        let started = SearchPerformanceLogger.now()
        let missingCueIDs = projection.cueIDs.filter { cachedCueContent(for: $0) == nil }

        func commit() {
            guard commitProjectedSearchResult(
                cueIDs: projection.cueIDs,
                distribution: projection.distribution,
                generation: generation
            ) else {
                return
            }
            onResultsChanged(generation)
            SearchPerformanceLogger.mark(
                run,
                "search_facet_projection_rows_loaded",
                phaseStart: started,
                resultCount: loadedSearchResultCueIDs.count,
                totalCount: searchResultTotalCount,
                status: "completed"
            )
        }

        guard !missingCueIDs.isEmpty else {
            commit()
            return true
        }
        replaceSearchTask(Task { [weak self] in
            guard let self else { return }
            for lowerBound in stride(from: 0, to: missingCueIDs.count, by: Self.searchRowReadBatchSize) {
                let range = lowerBound..<min(lowerBound + Self.searchRowReadBatchSize, missingCueIDs.count)
                guard await self.loadSearchRows(
                    range: range,
                    folders: folders,
                    languageFilter: languageFilter,
                    watchStateFilter: watchStateFilter,
                    orderedCueIDs: missingCueIDs
                ) != nil,
                    !Task.isCancelled
                else {
                    return
                }
            }
            commit()
        })
        return true
    }

    private func finishSkippedSearch(
        run: SearchPerformanceRun?,
        event: String,
        status: String,
        onFirstPageResolved: @escaping @MainActor (SubtitleSearchResult?) -> Bool
    ) {
        SearchPerformanceLogger.mark(run, event, status: status)
        clearPerformanceRunIfActive(run)
        _ = onFirstPageResolved(nil)
    }

    private func failBeforeSearch(
        _ message: String,
        event: String,
        run: SearchPerformanceRun?,
        onFirstPageResolved: @escaping @MainActor (SubtitleSearchResult?) -> Bool
    ) {
        markSearchFailed(message)
        SearchPerformanceLogger.mark(
            run,
            event,
            status: "failed",
            error: message
        )
        clearPerformanceRunIfActive(run)
        _ = onFirstPageResolved(nil)
    }

    private func logCancelledPage(
        run: SearchPerformanceRun?,
        event: String,
        page: SubtitleSearchPage?,
        databaseSearchMilliseconds: Double?
    ) {
        SearchPerformanceLogger.mark(run, event)
    }

    private func clearPerformanceRunIfActive(_ run: SearchPerformanceRun?) {
        guard let run, activePerformanceRun?.id == run.id else { return }
        updateActivePerformanceRun(nil)
    }

    private func resetResultLoadingState() {
        cancelNavigationTask()
        let releasedRows = clearResults()
        AppMemoryPressureRelief.relieveAfterLargeResultRelease(
            estimatedReleasedRows: releasedRows
        )
    }

    func loadSearchRows(
        range: Range<Int>,
        folders: [URL],
        languageFilter: SubtitleSearchLanguageFilter,
        watchStateFilter: SubtitleSearchWatchStateFilter,
        orderedCueIDs: [Int64]? = nil
    ) async -> TableSandboxSearchHydrationPage? {
        let scopeGeneration = folderScopeGeneration
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let filterSet = resultFilterSet
        let filterSignature = filterSet.cacheSignature
        guard !query.isEmpty,
              !folders.isEmpty,
              acceptsFolderScope(folders, generation: scopeGeneration),
              database != nil,
              let databaseURL
        else {
            return nil
        }

        let facetFilter = resultFacetFilter
        let sourceCueIDs = orderedCueIDs ?? searchResultCueIDs
        let totalCount = orderedCueIDs?.count ?? searchResultTotalCount
        guard totalCount > 0 else { return nil }
        let lowerBound = min(max(0, range.lowerBound), totalCount)
        let upperBound = min(max(lowerBound, range.upperBound), totalCount)
        guard lowerBound < upperBound else { return nil }

        if sourceCueIDs.count >= upperBound {
            let requestedCueIDs = Array(sourceCueIDs[lowerBound..<upperBound])
            let fileSummaries = searchFileSummaries
            do {
                let page = try await Self.runCancellableDetached(
                    priority: .userInitiated
                ) {
                    let pageDatabase = try SearchDatabase(
                        path: databaseURL,
                        access: .readOnly
                    )
                    let window = SubtitleSearchResultIDIndexWindow(
                        cueIDs: requestedCueIDs,
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
                    return try pageDatabase.searchIndexedVisiblePage(from: window)
                }
                guard !Task.isCancelled,
                      let page,
                      acceptsFolderScope(
                        folders,
                        generation: scopeGeneration
                      ),
                      searchQuery.trimmingCharacters(
                        in: .whitespacesAndNewlines
                      ) == query,
                      resultFilterSetSignature == filterSignature,
                      (orderedCueIDs != nil || searchResultCueIDs.count >= upperBound)
                else {
                    return nil
                }
                cacheHydratedResults(page.results)
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
            loadedGlobalResultCount + Self.searchPageSize,
            Self.searchPageSize
        )
        guard upperBound <= fallbackUpperBound else { return nil }
        do {
            let page = try await Self.runCancellableDetached(
                priority: .userInitiated
            ) {
                let pageDatabase = try SearchDatabase(
                    path: databaseURL,
                    access: .readOnly
                )
                return try pageDatabase.searchVisiblePage(
                    query,
                    limit: upperBound - lowerBound,
                    cursor: SubtitleSearchCursor(offset: lowerBound),
                    under: folders,
                    languageFilter: languageFilter,
                    watchStateFilter: watchStateFilter,
                    filterSet: filterSet,
                    facetFilter: facetFilter
                )
            }
            guard !Task.isCancelled,
                  acceptsFolderScope(
                    folders,
                    generation: scopeGeneration
                  ),
                  searchQuery.trimmingCharacters(
                    in: .whitespacesAndNewlines
                  ) == query,
                  resultFilterSetSignature == filterSignature
            else {
                return nil
            }
            cacheHydratedResults(page.results)
            return TableSandboxSearchHydrationPage(
                range: lowerBound..<(lowerBound + page.results.count),
                results: page.results,
                totalRowCount: max(totalCount, page.totalCount)
            )
        } catch {
            return nil
        }
    }

    func loadAllCueRows(
        range: Range<Int>,
        folders: [URL]
    ) async -> TableSandboxSearchHydrationPage? {
        let scopeGeneration = folderScopeGeneration
        let filterSet = activeFilterSet
        let filterSignature = filterSet.cacheSignature
        guard !folders.isEmpty,
              acceptsFolderScope(folders, generation: scopeGeneration),
              database != nil,
              let databaseURL
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
                    path: databaseURL,
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
                  acceptsFolderScope(
                    folders,
                    generation: scopeGeneration
                  ),
                  activeFilterSetSignature == filterSignature
            else {
                return nil
            }
            cacheHydratedResults(page.results)
            return TableSandboxSearchHydrationPage(
                range: lowerBound..<(lowerBound + page.results.count),
                results: page.results,
                totalRowCount: page.totalCount
            )
        } catch {
            return nil
        }
    }

    func applyAllCueSearchPage(_ page: TableSandboxSearchHydrationPage) {
        let hasMore = page.range.upperBound < page.totalRowCount
        replaceResultState(
            results: page.results,
            orderedCueIDs: page.results.map(\.entryID),
            status: .completed,
            totalCount: page.totalRowCount,
            fileSummaries: searchFileSummaries,
            countState: .exact,
            knownResultCount: page.totalRowCount,
            knownFileCount: 0,
            hasMore: hasMore,
            loadedResultCount: page.results.count,
            nextCursor: hasMore
                ? SubtitleSearchCursor(offset: page.range.upperBound)
                : nil
        )
    }

    nonisolated private static func runCancellableDetached<T: Sendable>(
        priority: TaskPriority,
        operation: @Sendable @escaping () throws -> T
    ) async throws -> T {
        let task = Task.detached(priority: priority, operation: operation)
        return try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            task.cancel()
        }
    }
}
