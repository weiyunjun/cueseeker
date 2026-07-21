import SwiftUI
import CueSeekerCore
import CueSeekerPlayback

func workbenchSearchHasCompleteTextCopyBoundary(
    countState: SubtitleSearchCountState,
    cueIDs: [Int64],
    resultRowCount: Int
) -> Bool {
    countState == .exact
        && resultRowCount >= 0
        && cueIDs.count == resultRowCount
}

private struct WorkbenchSearchTableTextCopySource {
    enum Mode {
        case search(query: String, cueIDs: [Int64])
        case allCues
        case context(CueContextSearchRequest)
    }

    let mode: Mode
    let resultRowCount: Int
    let folderPaths: [String]
    let filterSignature: String
    let languageFilter: SubtitleSearchLanguageFilter
    let watchStateFilter: SubtitleSearchWatchStateFilter
}

struct WorkbenchTestSearchView: View {
    let isTableResponseActive: Bool
    @EnvironmentObject private var appState: AppCoordinator
    @EnvironmentObject private var search: SearchStore
    @EnvironmentObject private var settingsStore: SettingsStore
    @ObservedObject private var rowStore: TableSandboxRowModelStore
    @State private var appliedShowCueGroup: Bool?
    @State private var searchDraft: String
    @State private var visibleColumnIDs: Set<String>
    @State private var activeFilterSetID: String?
    @State private var filterRules: [SchemaWorkbenchFilterRule]
    @State private var lastVisibleRows: Range<Int>?
    @State private var appliedFilterSignature = ""
    @State private var tableScrollResetToken = 0
    @State private var tableScrollTargetRow: Int?
    @State private var didRestoreViewport = false
    @State private var hasPreparedViewportRestoration = false
    @State private var viewportAnchorToRestore: TableViewportAnchor?
    @State private var rowSelection = TableSandboxRowSelectionState()
    @State private var canExportSelectedRowsAsCollage = false
    @State private var lastHandledCueContextRequestID: UUID?
    @State private var activeCueContextRequest: CueContextSearchRequest?
    @State private var cueContextLoadGeneration = 0
    @State private var cueContextLoadedSourceRange: Range<Int>?
    @State private var cueContextTotalRowCount = 0
    @State private var cueContextTargetSourceIndex: Int?
    @State private var isLoadingCueContextRows = false
    @State private var suppressNextEmptySearchQueryReload = false
    @State private var suppressNextFilterRulesReload = false
    @State private var hasDeferredRefreshWhileCovered = false

    private static let continuousPageSize = 1_000

    private enum CueContextLoadDirection {
        case previous
        case next
    }

    private enum CueContextScrollAnchor {
        case target
        case visibleTop
        case none
    }

    init(
        rowStore: TableSandboxRowModelStore,
        isTableResponseActive: Bool = true
    ) {
        _rowStore = ObservedObject(wrappedValue: rowStore)
        self.isTableResponseActive = isTableResponseActive
        _searchDraft = State(initialValue: "")
        _visibleColumnIDs = State(initialValue: SchemaWorkbenchSearchDefaults.initialVisibleColumnIDs)
        _activeFilterSetID = State(initialValue: SchemaWorkbenchSearchDefaults.defaultFilterSetID)
        _filterRules = State(initialValue: SchemaWorkbenchSearchDefaults.defaultFilterRules)
    }

    var body: some View {
        let _ = UIInvalidationProbe.count(
            tableProbeSurface.counterName("surface_body"),
            scope: appState.uiProbeScope
        )
        let textCopySource = tableTextCopySource
        SchemaWorkbenchSearchShell(
            searchDraft: searchInputBinding,
            visibleColumnIDs: $visibleColumnIDs,
            activeFilterSetID: $activeFilterSetID,
            filterRules: $filterRules,
            filterSets: $settingsStore.searchFilterSets,
            columns: SchemaWorkbenchSearchDefaults.columns,
            isRedesign: true,
            tableSummary: tableSummary,
            tableSummaryLeadingInset: tableSummaryLeadingInset,
            tableSummaryAction: selectedSummaryActions,
            filterableColumnIDs: ["display", "cues"]
        ) { visibleColumns in
            ZStack {
                SubtitleTableView(
                    tableName: "test-search",
                    probeSurface: tableProbeSurface,
                    probeScope: appState.uiProbeScope,
                    rowCount: rowStore.snapshot.totalRowCount,
                    rowProvider: { rowStore.snapshot.row(at: $0) },
                    rowsVersion: rowStore.snapshot.version,
                    rowsUpdate: rowStore.snapshot.update,
                    displayTitleHeader: columnTitle("display", in: visibleColumns, fallback: "Display Title"),
                    timeHeader: columnTitle("time", in: visibleColumns, fallback: "Time Range"),
                    cuesHeader: columnTitle("cues", in: visibleColumns, fallback: "Cues"),
                    speakerHeader: columnTitle("speaker", in: visibleColumns, fallback: "Speaker"),
                    languageHeader: columnTitle("language", in: visibleColumns, fallback: "Language"),
                    columnOrder: visibleColumns.map(\.id),
                    showsDisplayTitleColumn: isColumnVisible("display", in: visibleColumns),
                    showsTimeColumn: isColumnVisible("time", in: visibleColumns),
                    showsLanguageColumn: isColumnVisible("language", in: visibleColumns),
                    showsSpeakerColumn: isColumnVisible("speaker", in: visibleColumns),
                    showsCueGroup: appliedShowCueGroup
                        ?? (allowsTableResponse && settingsStore.showCueGroup),
                    scrollResetToken: tableScrollResetToken,
                    scrollTargetRow: tableScrollTargetRow,
                    onVisibleRowsChange: hydrateVisibleRows,
                    isRowSelected: { rowSelection.isSelected($0, rowCount: rowStore.snapshot.totalRowCount) },
                    selectionHeaderState: rowSelection.headerState(rowCount: rowStore.snapshot.totalRowCount),
                    onToggleRowSelection: toggleRowSelection,
                    onToggleAllSelection: toggleAllRowSelection,
                    allResultsTextCopyRowCount: textCopySource?.resultRowCount,
                    loadRowsForTextCopy: { range in
                        guard let textCopySource else { return nil }
                        return await loadRowsForTextCopy(range: range, source: textCopySource)
                    },
                    onPlay: play,
                    onShowContext: showContext,
                    isRedesign: true
                )

                if showsSearchEmptyHint {
                    WorkbenchEmptyHint(message: "Enter a search term or add filters to show cues.")
                }
            }
        }
        .onAppear {
            search.setTableProjectionResponseActive(allowsTableResponse)
            prepareViewportRestoration()
            restoreTableControls()
            if let request = search.cueContextSearchRequest,
               applyCueContextSearchRequest(request) {
                return
            }

            searchDraft = search.tableSearchDraft.isEmpty
                ? search.searchQuery
                : search.tableSearchDraft
            appliedFilterSignature = filterRules.subtitleSearchFilterSet.cacheSignature
            if showsSearchEmptyHint {
                search.clearTableProjectionSource()
                clearTableRows(resetScroll: false)
            } else if isFilterOnlyMode {
                loadAllCueRows(resetScroll: false)
            } else {
                updateRowsFromResidentSearch()
            }
            restoreSelectionIfPossible()
            restoreViewportIfPossible()
        }
        .onChange(of: filterRules) { newValue in
            search.tableFilterRules = newValue
            if suppressNextFilterRulesReload {
                suppressNextFilterRulesReload = false
                return
            }
            applyFilterRules(newValue)
        }
        .onChange(of: visibleColumnIDs) { newValue in
            search.tableVisibleColumnIDs = newValue
        }
        .onChange(of: activeFilterSetID) { newValue in
            search.tableActiveFilterSetID = newValue
        }
        .onChange(of: search.searchQuery) { newValue in
            searchDraft = newValue
            search.suspendFilterOnlyPageLoad()
            rowSelection.reset()
            persistSelection()
            search.tableViewportAnchor = nil
            viewportAnchorToRestore = nil
            didRestoreViewport = true
            lastVisibleRows = nil
            if !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                search.activateResidentSearchTableProjection()
                activeCueContextRequest = nil
                tableScrollTargetRow = nil
                cueContextLoadGeneration += 1
                resetCueContextWindow()
            }
            if newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if suppressNextEmptySearchQueryReload {
                    suppressNextEmptySearchQueryReload = false
                    return
                }
                if search.activeFilterSet.isEffectivelyEmpty {
                    search.clearTableProjectionSource()
                    clearTableRows(resetScroll: true)
                } else {
                    loadAllCueRows(resetScroll: true)
                }
            }
        }
        .onChange(of: search.searchResultTotalCount) { _ in
            guard !isFilterOnlyMode, !showsSearchEmptyHint else { return }
            updateRowsFromResidentSearch()
        }
        .onChange(of: search.searchCountState) { _ in
            guard !isFilterOnlyMode, !showsSearchEmptyHint else { return }
            updateRowsFromResidentSearch()
        }
        .onChange(of: search.searchResultCueIDs) { _ in
            guard !isFilterOnlyMode, !showsSearchEmptyHint else { return }
            updateRowsFromResidentSearch()
        }
        .onChange(of: search.indexedCueDataRevision) { _ in
            guard isFilterOnlyMode else { return }
            loadAllCueRows(resetScroll: false)
        }
        .onChange(of: rowStore.snapshot.version) { _ in
            restoreSelectionIfPossible()
            restoreViewportIfPossible()
        }
        .onChange(of: search.cueContextSearchRequest) { request in
            guard let request else {
                return
            }
            _ = applyCueContextSearchRequest(request)
        }
        .onChange(of: isTableResponseActive) { isActive in
            search.setTableProjectionResponseActive(isActive)
            if !isActive {
                resetCoveredTableLoading()
            } else {
                resumeDeferredTableResponse()
            }
        }
        .task(id: isTableResponseActive) {
            guard isTableResponseActive else { return }
            await Task.yield()
            resumeDeferredTableResponse()
        }
        .onDisappear {
            search.setTableProjectionResponseActive(false)
            persistTableControls()
            persistSelection()
        }
        .background(
            CueGroupPresentationGate(
                store: settingsStore.cueGroupPresentation,
                isActive: allowsTableResponse,
                appliedValue: $appliedShowCueGroup
            )
        )
    }

    private func isColumnVisible(_ id: String, in visibleColumns: [WorkbenchTableColumn]) -> Bool {
        visibleColumns.contains { $0.id == id }
    }

    private func columnTitle(_ id: String, in visibleColumns: [WorkbenchTableColumn], fallback: String) -> String {
        visibleColumns.first { $0.id == id }?.title ?? fallback
    }

    private var isFilterOnlyMode: Bool {
        search.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !search.activeFilterSet.isEffectivelyEmpty
    }

    private var showsSearchEmptyHint: Bool {
        search.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && searchDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && search.activeFilterSet.isEffectivelyEmpty
    }

    private var searchInputBinding: Binding<String> {
        Binding(
            get: { searchDraft },
            set: { newValue in
                searchDraft = newValue
                updateSearchDraft(newValue)
            }
        )
    }

    private var allowsTableResponse: Bool {
        isTableResponseActive
    }

    private var tableProbeSurface: SubtitleTableProbeSurface {
        activeCueContextRequest == nil ? .search : .context
    }

    private var tableTextCopySource: WorkbenchSearchTableTextCopySource? {
        let mode: WorkbenchSearchTableTextCopySource.Mode
        let resultRowCount: Int
        if let request = activeCueContextRequest {
            mode = .context(request)
            resultRowCount = cueContextTotalRowCount
        } else if isFilterOnlyMode {
            mode = .allCues
            resultRowCount = search.searchResultTotalCount
        } else {
            let query = search.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            let cueIDs = search.searchResultCueIDs
            resultRowCount = search.searchResultTotalCount
            guard !query.isEmpty,
                  workbenchSearchHasCompleteTextCopyBoundary(
                      countState: search.searchCountState,
                      cueIDs: cueIDs,
                      resultRowCount: resultRowCount
                  )
            else {
                return nil
            }
            mode = .search(query: query, cueIDs: cueIDs)
        }
        return WorkbenchSearchTableTextCopySource(
            mode: mode,
            resultRowCount: max(0, resultRowCount),
            folderPaths: appState.indexing.selectedFolders.map(\.path),
            filterSignature: search.activeFilterSetSignature,
            languageFilter: settingsStore.primarySearchLanguage.searchLanguageFilter,
            watchStateFilter: settingsStore.searchScope.searchWatchStateFilter
        )
    }

    private func loadRowsForTextCopy(
        range: Range<Int>,
        source: WorkbenchSearchTableTextCopySource
    ) async -> [SubtitleTableRow]? {
        guard range.lowerBound >= 0,
              range.upperBound <= source.resultRowCount,
              range.lowerBound < range.upperBound,
              textCopySourceStillMatches(source, range: range)
        else {
            return nil
        }

        let page: TableSandboxSearchHydrationPage?
        switch source.mode {
        case .search:
            page = await appState.loadTableSandboxSearchRows(range: range)
        case .allCues:
            page = await appState.loadTableSandboxAllCueRows(range: range)
        case .context(let request):
            page = await appState.loadCueContextSearchPage(
                request: request,
                range: range,
                anchorsInitialPage: false
            )
        }

        guard let page,
              textCopySourceStillMatches(source, range: range),
              page.range == range,
              page.results.count == range.count,
              page.totalRowCount == source.resultRowCount
        else {
            return nil
        }
        return page.results.map { tableSandboxSearchRow(for: $0) }
    }

    private func textCopySourceStillMatches(
        _ source: WorkbenchSearchTableTextCopySource,
        range: Range<Int>
    ) -> Bool {
        guard allowsTableResponse,
              appState.indexing.selectedFolders.map(\.path) == source.folderPaths
        else {
            return false
        }
        switch source.mode {
        case .search(let query, let cueIDs):
            guard activeCueContextRequest == nil,
                  search.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines) == query,
                  search.activeFilterSetSignature == source.filterSignature,
                  settingsStore.primarySearchLanguage.searchLanguageFilter == source.languageFilter,
                  settingsStore.searchScope.searchWatchStateFilter == source.watchStateFilter,
                  workbenchSearchHasCompleteTextCopyBoundary(
                      countState: search.searchCountState,
                      cueIDs: search.searchResultCueIDs,
                      resultRowCount: search.searchResultTotalCount
                  ),
                  search.searchResultTotalCount == source.resultRowCount,
                  search.searchResultCueIDs == cueIDs
            else {
                return false
            }
            return true
        case .allCues:
            return activeCueContextRequest == nil
                && search.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !search.activeFilterSet.isEffectivelyEmpty
                && search.activeFilterSetSignature == source.filterSignature
                && search.searchResultTotalCount == source.resultRowCount
        case .context(let request):
            return activeCueContextRequest?.id == request.id
                && search.cueContextSearchRequest?.id == request.id
                && cueContextTotalRowCount == source.resultRowCount
        }
    }

    @discardableResult
    private func applyCueContextSearchRequest(_ request: CueContextSearchRequest) -> Bool {
        guard allowsTableResponse else {
            hasDeferredRefreshWhileCovered = true
            return false
        }
        guard lastHandledCueContextRequestID != request.id else {
            return false
        }

        let displayTitle = request.displayTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !displayTitle.isEmpty else {
            return false
        }

        lastHandledCueContextRequestID = request.id
        activeCueContextRequest = request
        search.activateContextTableProjection(requestID: request.id)
        cueContextLoadGeneration += 1
        resetCueContextWindow()
        let generation = cueContextLoadGeneration
        let rules = [
            SchemaWorkbenchSearchDefaults.makeFilterRule(
                join: nil,
                fieldID: "display",
                operatorID: .contains,
                value: displayTitle
            )
        ]
        let filterSet = rules.subtitleSearchFilterSet
        let filterSignature = filterSet.cacheSignature

        if filterRules != rules {
            suppressNextFilterRulesReload = true
        }
        if !search.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            suppressNextEmptySearchQueryReload = true
        }

        searchDraft = ""
        activeFilterSetID = nil
        filterRules = rules
        search.searchQuery = ""
        search.searchNavigationSnapshot = nil
        appliedFilterSignature = filterSignature
        appState.updateSearchFilterSet(filterSet)
        tableScrollTargetRow = nil
        tableScrollResetToken += 1
        clearTableRows(resetScroll: false)
        loadCueContextRows(
            request: request,
            filterSignature: filterSignature,
            generation: generation
        )
        return true
    }

    private var tableSummary: SchemaWorkbenchTableSummary {
        let totalRowCount = tableSummaryTotalRowCount
        return SchemaWorkbenchTableSummary(
            totalRowCount: totalRowCount,
            selectedRowCount: rowSelection.selectedCount(rowCount: totalRowCount)
        )
    }

    private var tableSummaryTotalRowCount: Int {
        if showsSearchEmptyHint {
            return 0
        }
        return rowStore.snapshot.totalRowCount
    }

    private var tableSummaryLeadingInset: CGFloat {
        SubtitleTableMetrics.checkboxLeadingInset
    }

    private var selectedSummaryActions: AnyView? {
        guard tableSummary.selectedRowCount > 0 else {
            return nil
        }
        return AnyView(
            HStack(spacing: WorkbenchControlMetrics.redesignSpacing3) {
                WorkbenchButton(
                    title: "Anki",
                    systemImage: "square.and.arrow.up",
                    isRedesign: true,
                    action: exportSelectedRowsToAnki
                )
                WorkbenchButton(
                    title: "Screenshot",
                    systemImage: "photo",
                    isRedesign: true,
                    action: exportSelectedRowsAsScreenshots
                )
                WorkbenchButton(
                    title: "Collage",
                    systemImage: "rectangle.stack",
                    isRedesign: true,
                    action: exportSelectedRowsAsCollage
                )
                .disabled(!canExportSelectedRowsAsCollage)
                WorkbenchButton(
                    title: "Copy Table",
                    systemImage: "doc.on.doc",
                    isRedesign: true,
                    action: copySelectedRowsAsTable
                )
            }
        )
    }

    private var visibleColumnsForCopy: [WorkbenchTableColumn] {
        SchemaWorkbenchSearchDefaults.columns.filter {
            visibleColumnIDs.contains($0.id) ||
                SchemaWorkbenchColumnVisibilityMenu.isLocked($0.id)
        }
    }

    private func updateSearchDraft(_ newValue: String) {
        guard newValue != search.searchQuery else {
            return
        }
        search.tableSearchDraft = newValue
        search.cueContextSearchRequest = nil
        suppressNextEmptySearchQueryReload = false
        activeCueContextRequest = nil
        tableScrollTargetRow = nil
        cueContextLoadGeneration += 1
        resetCueContextWindow()
        appState.updateSearchQuery(newValue)
    }

    private func updateRows(_ results: [SubtitleSearchResult]) {
        guard allowsTableResponse else {
            hasDeferredRefreshWhileCovered = true
            return
        }
        rowStore.updateResidentSearchResults(
            results,
            cueContentProvider: searchCueContentProvider,
            cueContentRevision: appState.cueContent.revision,
            tableName: "test-search",
            probeSurface: tableProbeSurface,
            probeScope: appState.uiProbeScope
        )
        rowSelection.clamp(rowCount: rowStore.snapshot.totalRowCount)
        refreshSelectedCollageAvailability()
    }

    private func updateRowsFromResidentSearch() {
        guard allowsTableResponse else {
            hasDeferredRefreshWhileCovered = true
            return
        }
        search.activateResidentSearchTableProjection()
        rowSelection.clamp(rowCount: rowStore.snapshot.totalRowCount)
        refreshSelectedCollageAvailability()
    }

    private var searchCueContentProvider: (Int64) -> CueContent? {
        let store = appState.cueContent
        return { cueID in store.content(for: cueID) }
    }

    private func clearTableRows(resetScroll: Bool) {
        guard allowsTableResponse else {
            hasDeferredRefreshWhileCovered = true
            resetCoveredTableLoading()
            return
        }
        let releasedRows = max(rowStore.snapshot.loadedReferenceCount, rowStore.snapshot.totalRowCount)
        resetCueContextWindow()
        lastVisibleRows = nil
        rowSelection.reset()
        persistSelection()
        resetSelectedCollageAvailability()
        rowStore.updateResidentSearchResults(
            [],
            cueContentProvider: searchCueContentProvider,
            cueContentRevision: appState.cueContent.revision,
            tableName: "test-search",
            probeSurface: tableProbeSurface,
            probeScope: appState.uiProbeScope
        )
        if resetScroll {
            search.tableViewportAnchor = nil
            viewportAnchorToRestore = nil
            tableScrollTargetRow = nil
            didRestoreViewport = true
            tableScrollResetToken += 1
        }
        AppMemoryPressureRelief.relieveAfterLargeResultRelease(estimatedReleasedRows: releasedRows)
    }

    private func play(_ row: SubtitleTableRow) {
        guard let result = rowStore.snapshot.searchResult(entryID: row.id)
            ?? search.searchResults.first(where: { Int($0.entryID) == row.id })
        else {
            return
        }
        appState.openSearchResult(result, displayTitle: row.displayTitle)
    }

    private func showContext(_ row: SubtitleTableRow) {
        guard let result = rowStore.snapshot.searchResult(entryID: row.id)
            ?? search.searchResults.first(where: { Int($0.entryID) == row.id })
        else {
            return
        }

        appState.openSearchResultContext(result)
    }

    private func hydrateVisibleRows(_ visibleRows: Range<Int>) {
        guard allowsTableResponse else { return }
        lastVisibleRows = visibleRows
        captureVisibleRows(visibleRows)
        if activeCueContextRequest != nil {
            loadCueContextAdjacentRowsIfNeeded(generation: cueContextLoadGeneration)
            return
        }
        guard isFilterOnlyMode,
              activeCueContextRequest == nil,
              visibleRows.upperBound >= rowStore.snapshot.totalRowCount - TableSandboxHydrationPaging.pageSize
        else {
            return
        }
        loadAllCueRows(resetScroll: false)
    }

    private func resetCueContextWindow() {
        cueContextLoadedSourceRange = nil
        cueContextTotalRowCount = 0
        cueContextTargetSourceIndex = nil
        isLoadingCueContextRows = false
    }

    private func resetCoveredTableLoading() {
        search.suspendFilterOnlyPageLoad()
        cueContextLoadGeneration += 1
        isLoadingCueContextRows = false
    }

    private func resumeDeferredTableResponse() {
        guard allowsTableResponse else { return }
        let isStandardSearch = activeCueContextRequest == nil && !isFilterOnlyMode
        guard hasDeferredRefreshWhileCovered || isStandardSearch else { return }
        hasDeferredRefreshWhileCovered = false
        refreshTableForCurrentState()
    }

    private func refreshTableForCurrentState() {
        if let request = search.cueContextSearchRequest,
           applyCueContextSearchRequest(request) {
            return
        }

        if showsSearchEmptyHint {
            clearTableRows(resetScroll: false)
        } else if isFilterOnlyMode {
            loadAllCueRows(resetScroll: false)
        } else {
            updateRowsFromResidentSearch()
        }
    }

    @discardableResult
    private func appendContinuousRows(
        _ page: TableSandboxSearchHydrationPage,
        expectedStartIndex: Int
    ) -> Bool {
        guard page.range.lowerBound == expectedStartIndex, !page.results.isEmpty else {
            return false
        }
        rowStore.hydrateResidentSearchResults(
            page.results,
            startIndex: expectedStartIndex,
            cueContentProvider: searchCueContentProvider,
            cueContentRevision: appState.cueContent.revision,
            tableName: "test-search",
            probeSurface: tableProbeSurface,
            probeScope: appState.uiProbeScope
        )
        rowSelection.clamp(rowCount: rowStore.snapshot.totalRowCount)
        return rowStore.snapshot.totalRowCount > expectedStartIndex
    }

    private func loadAllCueRows(resetScroll: Bool) {
        guard allowsTableResponse,
              !appState.indexing.isLibraryFolderOperationActive
        else {
            hasDeferredRefreshWhileCovered = true
            resetCoveredTableLoading()
            return
        }
        let projectionKey = SearchFilterOnlyProjectionKey(
            filterSignature: search.activeFilterSetSignature,
            folderPaths: appState.indexing.selectedFolders.map(\.path),
            indexedCueDataRevision: search.indexedCueDataRevision
        )
        let sourceChanged = search.prepareFilterOnlyTableProjection(
            key: projectionKey
        )
        activeCueContextRequest = nil
        tableScrollTargetRow = nil
        resetCueContextWindow()
        lastVisibleRows = nil
        if resetScroll {
            rowSelection.reset()
            persistSelection()
            resetSelectedCollageAvailability()
            tableScrollResetToken += 1
        }
        if sourceChanged {
            rowStore.updateResidentSearchResults(
                [],
                cueContentProvider: searchCueContentProvider,
                cueContentRevision: appState.cueContent.revision,
                tableName: "test-search",
                probeSurface: tableProbeSurface,
                probeScope: appState.uiProbeScope
            )
        }
        guard let loadToken = search.beginFilterOnlyPageLoad(
            key: projectionKey,
            loadedRowCount: rowStore.snapshot.totalRowCount
        ) else {
            return
        }
        let pageSize = loadToken.startIndex == 0
            ? TableSandboxHydrationPaging.pageSize
            : Self.continuousPageSize
        let range = loadToken.startIndex..<(loadToken.startIndex + pageSize)

        Task { @MainActor in
            guard allowsTableResponse,
                  search.acceptsFilterOnlyPageLoad(loadToken),
                  search.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !search.activeFilterSet.isEffectivelyEmpty
            else {
                search.failFilterOnlyPageLoad(loadToken)
                return
            }
            UIInvalidationProbe.count(
                SubtitleTableProbeSurface.search.counterName("row_hydration_requested"),
                scope: appState.uiProbeScope
            )
            guard let page = await appState.loadTableSandboxAllCueRows(range: range),
                  search.acceptsFilterOnlyPageLoad(loadToken),
                  allowsTableResponse,
                  page.range.lowerBound == loadToken.startIndex,
                  search.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  activeCueContextRequest == nil,
                  search.activeFilterSetSignature == projectionKey.filterSignature
            else {
                search.failFilterOnlyPageLoad(loadToken)
                return
            }
            if loadToken.startIndex == 0 {
                appState.applyTableSandboxAllCueSearchContext(page)
                rowStore.updateResidentSearchResults(
                    page.results,
                    cueContentProvider: searchCueContentProvider,
                    cueContentRevision: appState.cueContent.revision,
                    tableName: "test-search",
                    probeSurface: tableProbeSurface,
                    probeScope: appState.uiProbeScope,
                    isHydration: true
                )
                rowSelection.clamp(rowCount: rowStore.snapshot.totalRowCount)
            } else {
                _ = appendContinuousRows(
                    page,
                    expectedStartIndex: loadToken.startIndex
                )
            }
            let loadedRowCount = rowStore.snapshot.totalRowCount
            let shouldContinue = search.completeFilterOnlyPageLoad(
                loadToken,
                totalRowCount: page.totalRowCount,
                loadedRowCount: loadedRowCount
            )
            if shouldContinue, loadedRowCount > loadToken.startIndex {
                loadAllCueRows(resetScroll: false)
            }
        }
    }

    private func loadCueContextRows(
        request: CueContextSearchRequest,
        filterSignature: String,
        generation: Int
    ) {
        guard allowsTableResponse else {
            hasDeferredRefreshWhileCovered = true
            return
        }
        Task { @MainActor in
            guard allowsTableResponse else { return }
            UIInvalidationProbe.count(
                SubtitleTableProbeSurface.context.counterName("row_hydration_requested"),
                scope: appState.uiProbeScope
            )
            guard let page = await appState.loadCueContextSearchPage(
                request: request,
                range: 0..<TableSandboxHydrationPaging.pageSize,
                anchorsInitialPage: true
            ) else {
                guard generation == cueContextLoadGeneration else { return }
                rowStore.updateResidentSearchResults(
                    [],
                    cueContentProvider: searchCueContentProvider,
                    cueContentRevision: appState.cueContent.revision,
                    tableName: "test-search",
                    probeSurface: .context,
                    probeScope: appState.uiProbeScope
                )
                return
            }

            guard generation == cueContextLoadGeneration,
                  allowsTableResponse,
                  search.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  search.activeFilterSetSignature == filterSignature
            else {
                return
            }

            appState.applyTableSandboxAllCueSearchContext(page)
            rowStore.updateResidentSearchResults(
                page.results,
                cueContentProvider: searchCueContentProvider,
                cueContentRevision: appState.cueContent.revision,
                tableName: "test-search",
                probeSurface: .context,
                probeScope: appState.uiProbeScope,
                isHydration: true
            )
            cueContextLoadedSourceRange = page.range
            cueContextTotalRowCount = page.totalRowCount
            let targetSourceIndex = resolvedCueContextTargetSourceIndex(
                in: page,
                targetCueID: request.targetCueID
            )
            cueContextTargetSourceIndex = targetSourceIndex
            tableScrollTargetRow = cueContextDisplayRow(
                forSourceIndex: targetSourceIndex,
                loadedSourceRange: page.range,
                loadedRowCount: rowStore.snapshot.totalRowCount
            )
            tableScrollResetToken += 1
            rowSelection.clamp(rowCount: rowStore.snapshot.totalRowCount)
            loadCueContextAdjacentRowsIfNeeded(
                generation: generation,
                preferredDirection: .previous
            )
        }
    }

    private func loadCueContextAdjacentRowsIfNeeded(
        generation: Int,
        preferredDirection: CueContextLoadDirection? = nil
    ) {
        guard generation == cueContextLoadGeneration,
              allowsTableResponse,
              activeCueContextRequest != nil,
              let sourceRange = cueContextLoadedSourceRange,
              cueContextTotalRowCount > 0,
              !isLoadingCueContextRows
        else {
            return
        }

        if preferredDirection == .previous, sourceRange.lowerBound > 0 {
            loadCueContextRows(
                direction: .previous,
                generation: generation,
                scrollAnchor: .target
            )
            return
        }

        let visibleRows = lastVisibleRows
        let isNearLoadedStart = (visibleRows?.lowerBound ?? 0) <= TableSandboxHydrationPaging.pageSize
        let isNearLoadedEnd = (visibleRows?.upperBound ?? rowStore.snapshot.totalRowCount)
            >= rowStore.snapshot.totalRowCount - TableSandboxHydrationPaging.pageSize

        if sourceRange.lowerBound > 0, isNearLoadedStart {
            loadCueContextRows(
                direction: .previous,
                generation: generation,
                scrollAnchor: .visibleTop
            )
            return
        }

        if sourceRange.upperBound < cueContextTotalRowCount, isNearLoadedEnd {
            loadCueContextRows(
                direction: .next,
                generation: generation,
                scrollAnchor: .none
            )
        }
    }

    private func loadCueContextRows(
        direction: CueContextLoadDirection,
        generation: Int,
        scrollAnchor: CueContextScrollAnchor
    ) {
        guard generation == cueContextLoadGeneration,
              allowsTableResponse,
              let request = activeCueContextRequest,
              let sourceRange = cueContextLoadedSourceRange,
              !isLoadingCueContextRows
        else {
            return
        }

        let range: Range<Int>
        switch direction {
        case .previous:
            let lowerBound = max(0, sourceRange.lowerBound - Self.continuousPageSize)
            range = lowerBound..<sourceRange.lowerBound
        case .next:
            let upperBound = min(cueContextTotalRowCount, sourceRange.upperBound + Self.continuousPageSize)
            range = sourceRange.upperBound..<upperBound
        }
        guard range.lowerBound < range.upperBound else { return }

        let filterSignature = search.activeFilterSetSignature
        let anchorSourceIndex = cueContextAnchorSourceIndex(
            scrollAnchor,
            loadedSourceRange: sourceRange
        )
        isLoadingCueContextRows = true

        Task { @MainActor in
            guard allowsTableResponse else {
                if generation == cueContextLoadGeneration {
                    isLoadingCueContextRows = false
                }
                return
            }
            UIInvalidationProbe.count(
                SubtitleTableProbeSurface.context.counterName("row_hydration_requested"),
                scope: appState.uiProbeScope
            )
            guard let page = await appState.loadCueContextSearchPage(
                request: request,
                range: range,
                anchorsInitialPage: false
            ),
                generation == cueContextLoadGeneration,
                allowsTableResponse,
                activeCueContextRequest?.id == request.id,
                search.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                search.activeFilterSetSignature == filterSignature
            else {
                if generation == cueContextLoadGeneration {
                    isLoadingCueContextRows = false
                }
                return
            }

            switch direction {
            case .previous:
                guard page.range.upperBound == sourceRange.lowerBound else {
                    isLoadingCueContextRows = false
                    return
                }
                let prependedCount = rowStore.prependResidentSearchResults(
                    page.results,
                    cueContentProvider: searchCueContentProvider,
                    cueContentRevision: appState.cueContent.revision,
                    tableName: "test-search",
                    probeSurface: .context,
                    probeScope: appState.uiProbeScope
                )
                if prependedCount > 0 {
                    let nextSourceRange = page.range.lowerBound..<sourceRange.upperBound
                    cueContextLoadedSourceRange = nextSourceRange
                    rowSelection.shiftRows(by: prependedCount)
                    rowSelection.clamp(rowCount: rowStore.snapshot.totalRowCount)
                    if let anchorSourceIndex {
                        tableScrollTargetRow = cueContextDisplayRow(
                            forSourceIndex: anchorSourceIndex,
                            loadedSourceRange: nextSourceRange,
                            loadedRowCount: rowStore.snapshot.totalRowCount
                        )
                        tableScrollResetToken += 1
                    }
                }
            case .next:
                guard page.range.lowerBound == sourceRange.upperBound else {
                    isLoadingCueContextRows = false
                    return
                }
                let appendedCount = rowStore.appendResidentSearchResults(
                    page.results,
                    cueContentProvider: searchCueContentProvider,
                    cueContentRevision: appState.cueContent.revision,
                    tableName: "test-search",
                    probeSurface: .context,
                    probeScope: appState.uiProbeScope
                )
                if appendedCount > 0 {
                    cueContextLoadedSourceRange = sourceRange.lowerBound..<page.range.upperBound
                    rowSelection.clamp(rowCount: rowStore.snapshot.totalRowCount)
                }
            }

            isLoadingCueContextRows = false
        }
    }

    private func cueContextAnchorSourceIndex(
        _ anchor: CueContextScrollAnchor,
        loadedSourceRange: Range<Int>
    ) -> Int? {
        switch anchor {
        case .target:
            return cueContextTargetSourceIndex
        case .visibleTop:
            return loadedSourceRange.lowerBound + max(0, lastVisibleRows?.lowerBound ?? 0)
        case .none:
            return nil
        }
    }

    private func applyFilterRules(_ rules: [SchemaWorkbenchFilterRule]) {
        let filterSet = rules.subtitleSearchFilterSet
        let nextSignature = filterSet.cacheSignature
        guard nextSignature != appliedFilterSignature else {
            return
        }

        activeCueContextRequest = nil
        tableScrollTargetRow = nil
        cueContextLoadGeneration += 1
        appliedFilterSignature = nextSignature
        search.suspendFilterOnlyPageLoad()
        rowSelection.reset()
        persistSelection()
        search.tableViewportAnchor = nil
        viewportAnchorToRestore = nil
        didRestoreViewport = true
        resetSelectedCollageAvailability()
        lastVisibleRows = nil
        tableScrollResetToken += 1
        appState.updateSearchFilterSet(filterSet)
        if search.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if filterSet.isEffectivelyEmpty {
                search.clearTableProjectionSource()
                clearTableRows(resetScroll: false)
            } else {
                loadAllCueRows(resetScroll: false)
            }
        }
    }

    private func exportSelectedRowsToAnki() {
        let selectedRows = rowSelection.selectedRows(rowCount: tableSummaryTotalRowCount)
        guard !selectedRows.isEmpty else {
            return
        }

        Task { @MainActor in
            let results = await selectedSearchResults(for: selectedRows)
            appState.exportSearchResultsToAnki(results)
        }
    }

    private func exportSelectedRowsAsScreenshots() {
        let selectedRows = rowSelection.selectedRows(rowCount: tableSummaryTotalRowCount)
        guard !selectedRows.isEmpty else {
            return
        }

        Task { @MainActor in
            let results = await selectedSearchResults(for: selectedRows)
            let items = results.map { appState.subtitleScreenshotItem(for: $0) }
            appState.exportSubtitleScreenshots(items)
        }
    }

    private func exportSelectedRowsAsCollage() {
        let selectedRows = rowSelection.selectedRows(rowCount: tableSummaryTotalRowCount)
        guard !selectedRows.isEmpty else {
            return
        }

        Task { @MainActor in
            let results = await selectedSearchResults(for: selectedRows)
            let items = results.map { appState.subtitleScreenshotItem(for: $0) }
            guard SubtitleScreenshotExporter.canExportCollage(items) else {
                refreshSelectedCollageAvailability()
                return
            }
            appState.exportSubtitleCollage(items)
        }
    }

    private func copySelectedRowsAsTable() {
        let rowCount = tableSummaryTotalRowCount
        let selection = rowSelection
        guard selection.selectedCount(rowCount: rowCount) > 0 else {
            return
        }

        let columns = SubtitleTableClipboard.columns(from: visibleColumnsForCopy)
        let selectedRows = selection.selectedRows(rowCount: rowCount)
        guard !selectedRows.isEmpty else {
            return
        }

        var builder = SubtitleTableClipboard.TSVBuilder(columns: columns)
        builder.append(rows: selectedRows.compactMap { rowStore.snapshot.row(at: $0) })
        SubtitleTableClipboard.copy(representations: builder.representations)
    }

    private func selectedSearchResults(for selectedRows: [Int]) async -> [SubtitleSearchResult] {
        await hydrateRowsForExport(selectedRows)
        return selectedRows.compactMap { row in
            guard let tableRow = rowStore.snapshot.row(at: row) else {
                return nil
            }
            return rowStore.snapshot.searchResult(entryID: tableRow.id)
                ?? search.searchResults.first { Int($0.entryID) == tableRow.id }
        }
    }

    private func selectedSearchResultsFromSnapshot(for selectedRows: [Int]) -> [SubtitleSearchResult] {
        selectedRows.compactMap { row in
            guard let tableRow = rowStore.snapshot.row(at: row) else {
                return nil
            }
            return rowStore.snapshot.searchResult(entryID: tableRow.id)
                ?? search.searchResults.first { Int($0.entryID) == tableRow.id }
        }
    }

    private func refreshSelectedCollageAvailability() {
        let selectedRows = rowSelection.selectedRows(rowCount: tableSummaryTotalRowCount)
        guard !selectedRows.isEmpty, selectedRows.count <= 50 else {
            setCanExportSelectedRowsAsCollage(false)
            return
        }

        let items = selectedSearchResultsFromSnapshot(for: selectedRows)
            .map { appState.subtitleScreenshotItem(for: $0) }
        setCanExportSelectedRowsAsCollage(SubtitleScreenshotExporter.canExportCollage(items))
    }

    private func resetSelectedCollageAvailability() {
        setCanExportSelectedRowsAsCollage(false)
    }

    private func setCanExportSelectedRowsAsCollage(_ canExport: Bool) {
        guard canExportSelectedRowsAsCollage != canExport else { return }
        canExportSelectedRowsAsCollage = canExport
    }

    private func hydrateRowsForExport(_ selectedRows: [Int]) async {
        _ = selectedRows
    }

    private func toggleRowSelection(_ row: Int) {
        rowSelection.toggle(row: row, rowCount: rowStore.snapshot.totalRowCount)
        persistSelection()
        refreshSelectedCollageAvailability()
    }

    private func toggleAllRowSelection() {
        rowSelection.toggleAll(rowCount: rowStore.snapshot.totalRowCount)
        persistSelection()
        refreshSelectedCollageAvailability()
    }

    private func captureVisibleRows(_ visibleRows: Range<Int>) {
        guard hasPreparedViewportRestoration, didRestoreViewport else { return }
        guard !visibleRows.isEmpty else { return }
        let anchorRow = min(
            visibleRows.upperBound - 1,
            visibleRows.lowerBound + SubtitleTableCueGeometry.measurementOverscan
        )
        guard let row = rowStore.snapshot.row(at: anchorRow) else { return }
        search.tableViewportAnchor = TableViewportAnchor(
            entryID: row.id,
            rowIndex: anchorRow
        )
        didRestoreViewport = true
    }

    private func restoreViewportIfPossible() {
        guard !didRestoreViewport,
              activeCueContextRequest == nil,
              rowStore.snapshot.totalRowCount > 0,
              let anchor = viewportAnchorToRestore
        else {
            return
        }
        guard let row = resolvedTableViewportRow(
            anchor: anchor,
            rowCount: rowStore.snapshot.totalRowCount,
            identityRow: rowStore.snapshot.rowIndex(entryID: anchor.entryID)
        ) else { return }
        viewportAnchorToRestore = nil
        didRestoreViewport = true
        tableScrollTargetRow = row
        tableScrollResetToken += 1
    }

    private func prepareViewportRestoration() {
        guard !hasPreparedViewportRestoration else { return }
        hasPreparedViewportRestoration = true
        viewportAnchorToRestore = search.tableViewportAnchor
        didRestoreViewport = viewportAnchorToRestore == nil
    }

    private func persistSelection() {
        search.tableSelectionState = rowSelection
        search.tableSelectionEntryIDs = rowStore.snapshot.orderedEntryIDs
    }

    private func restoreSelectionIfPossible() {
        let entryIDs = rowStore.snapshot.orderedEntryIDs
        guard entryIDs == search.tableSelectionEntryIDs else { return }
        rowSelection = search.tableSelectionState
        rowSelection.clamp(rowCount: rowStore.snapshot.totalRowCount)
    }

    private func restoreTableControls() {
        visibleColumnIDs = search.tableVisibleColumnIDs
        activeFilterSetID = search.tableActiveFilterSetID
        if filterRules != search.tableFilterRules {
            suppressNextFilterRulesReload = true
            filterRules = search.tableFilterRules
        }
    }

    private func persistTableControls() {
        search.tableSearchDraft = searchDraft
        search.tableVisibleColumnIDs = visibleColumnIDs
        search.tableActiveFilterSetID = activeFilterSetID
        search.tableFilterRules = filterRules
    }
}

func resolvedCueContextTargetSourceIndex(
    in page: TableSandboxSearchHydrationPage,
    targetCueID: Int64
) -> Int {
    page.results.first { $0.entryID == targetCueID }?.searchRank ?? page.range.lowerBound
}

func cueContextDisplayRow(
    forSourceIndex sourceIndex: Int,
    loadedSourceRange: Range<Int>,
    loadedRowCount: Int
) -> Int {
    guard loadedRowCount > 0 else { return 0 }
    return min(
        max(0, sourceIndex - loadedSourceRange.lowerBound),
        max(0, loadedRowCount - 1)
    )
}
