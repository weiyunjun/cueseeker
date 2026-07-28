import SwiftUI
import CueSeekerCore
import CueSeekerPlayback

func workbenchSearchHasCompleteTextCopyBoundary(
    searchStatus: SearchStatus,
    countState: SubtitleSearchCountState,
    cueIDs: [Int64],
    resultRowCount: Int
) -> Bool {
    searchStatus == .completed
        && countState == .exact
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
    static let defaultFacetPanelVisibility = true

    let isTableResponseActive: Bool
    @EnvironmentObject private var appState: AppCoordinator
    @EnvironmentObject private var search: SearchStore
    @EnvironmentObject private var settingsStore: SettingsStore
    @ObservedObject private var rowStore: TableSandboxRowModelStore
    @State private var appliedShowCueGroup: Bool?
    @State private var searchDraft: String
    @State private var visibleColumnIDs: Set<String>
    @State private var filterRules: [SchemaWorkbenchFilterRule]
    @State private var lastVisibleRows: Range<Int>?
    @State private var appliedFilterSignature = ""
    @State private var tableScrollResetToken = 0
    @State private var tableScrollTargetRow: Int?
    @State private var didRestoreViewport = false
    @State private var hasPreparedViewportRestoration = false
    @State private var viewportAnchorToRestore: TableViewportAnchor?
    @State private var rowSelection = TableSandboxRowSelectionState()
    @State private var isSelectionMode = false
    @State private var canExportSelectedRowsAsCollage = false
    @State private var suppressNextEmptySearchQueryReload = false
    @State private var suppressNextFilterRulesReload = false
    @State private var hasDeferredRefreshWhileCovered = false
    @State private var isFacetPanelVisible: Bool

    private static let continuousPageSize = 1_000

    init(
        rowStore: TableSandboxRowModelStore,
        isTableResponseActive: Bool = true
    ) {
        _rowStore = ObservedObject(wrappedValue: rowStore)
        self.isTableResponseActive = isTableResponseActive
        _searchDraft = State(initialValue: "")
        _visibleColumnIDs = State(initialValue: SchemaWorkbenchSearchDefaults.initialVisibleColumnIDs)
        _filterRules = State(initialValue: SchemaWorkbenchSearchDefaults.defaultFilterRules)
        _isFacetPanelVisible = State(initialValue: Self.defaultFacetPanelVisibility)
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
            filterRules: $filterRules,
            columns: SchemaWorkbenchSearchDefaults.columns,
            isRedesign: true,
            tableSummary: tableSummary,
            searchResultCountText: exactSearchResultCountText,
            selectionActions: selectedSummaryActions,
            filterableColumnIDs: ["display", "cues"],
            isSelectionMode: isSelectionMode,
            canEnterSelectionMode: canEnterSelectionMode,
            onToggleSelectionMode: toggleSelectionMode,
            filterPanel: AnyView(
                CueFacetFilterPanel(
                    distribution: facetDistribution,
                    availableLanguages: availableFacetLanguages,
                    isCalculating: search.isFacetSnapshotCalculating,
                    filter: searchFacetFilterBinding
                )
            ),
            isFilterPanelVisible: isFacetPanelVisible,
            onToggleFilterPanel: {
                isFacetPanelVisible.toggle()
            }
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
                    languageHeader: columnTitle("language", in: visibleColumns, fallback: "Language"),
                    columnOrder: visibleColumns.map(\.id),
                    showsDisplayTitleColumn: isColumnVisible("display", in: visibleColumns),
                    showsTimeColumn: isColumnVisible("time", in: visibleColumns),
                    showsLanguageColumn: isColumnVisible("language", in: visibleColumns),
                    showsCueGroup: appliedShowCueGroup
                        ?? (allowsTableResponse && settingsStore.showCueGroup),
                    scrollResetToken: tableScrollResetToken,
                    scrollTargetRow: tableScrollTargetRow,
                    onVisibleRowsChange: hydrateVisibleRows,
                    isSelectionMode: isSelectionMode,
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
                    WorkbenchEmptyHint(message: "Enter a search term to show cues.")
                }
            }
        }
        .onAppear {
            search.setTableProjectionResponseActive(allowsTableResponse)
            search.updateSearchFacetFilter(settingsStore.searchFacetFilter)
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
            exitSelectionMode()
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
        .onChange(of: search.searchQuery) { newValue in
            exitSelectionMode()
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
                tableScrollTargetRow = nil
                search.cancelContextTableLoad()
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
        .onChange(of: search.resultRevision) { _ in
            guard !isFilterOnlyMode, !showsSearchEmptyHint else { return }
            updateRowsFromResidentSearch()
        }
        .onChange(of: search.indexedCueDataRevision) { _ in
            exitSelectionMode()
            guard isFilterOnlyMode else { return }
            loadAllCueRows(resetScroll: false)
        }
        .onChange(of: canEnterSelectionMode) { canEnter in
            if !canEnter {
                exitSelectionMode()
            }
        }
        .onChange(of: rowStore.snapshot.version) { _ in
            restoreSelectionIfPossible()
            restoreViewportIfPossible()
        }
        .onChange(of: search.tableLoadRevision) { _ in
            handleContextTablePresentation()
            appState.refreshSearchPlaybackPlaylistSource(
                resultListGeneration: search.resultListGeneration
            )
        }
        .onChange(of: search.cueContextSearchRequest) { request in
            exitSelectionMode()
            guard let request else {
                return
            }
            _ = applyCueContextSearchRequest(request)
        }
        .onChange(of: isTableResponseActive) { isActive in
            if !isActive {
                exitSelectionMode()
            }
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
            exitSelectionMode()
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
        search.cueContextSearchRequest == nil
            && search.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && searchDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && search.activeFilterSet.isEffectivelyEmpty
    }

    private var searchFacetFilterBinding: Binding<CueFacetFilter> {
        Binding(
            get: { settingsStore.searchFacetFilter },
            set: { newValue in
                settingsStore.searchFacetFilter = newValue
                applySearchFacetFilter(newValue)
            }
        )
    }

    private var facetDistribution: CueFacetDistribution? {
        search.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? search.emptySearchFacetDistribution
            : search.searchFacetSnapshot?.distribution
    }

    private var availableFacetLanguages: [SubtitleLanguageCode] {
        var available = Set(
            search.emptySearchFacetDistribution?.languageCounts.compactMap {
                $0.value > 0 ? $0.key : nil
            } ?? []
        )
        if let snapshot = search.searchFacetSnapshot {
            available.formUnion(snapshot.distribution.languageCounts.keys)
        }
        available.insert(.unknown)
        return SubtitleLanguageCode.allCases.filter(available.contains)
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
        search.cueContextSearchRequest == nil ? .search : .context
    }

    private var tableTextCopySource: WorkbenchSearchTableTextCopySource? {
        let mode: WorkbenchSearchTableTextCopySource.Mode
        let resultRowCount: Int
        if let request = search.cueContextSearchRequest {
            mode = .context(request)
            resultRowCount = search.contextTotalRowCount
        } else if isFilterOnlyMode {
            mode = .allCues
            resultRowCount = search.searchResultTotalCount
        } else {
            let query = search.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            let cueIDs = search.filteredSearchResultCueIDs
            resultRowCount = search.filteredSearchResultTotalCount ?? -1
            guard !query.isEmpty,
                  workbenchSearchHasCompleteTextCopyBoundary(
                      searchStatus: search.searchStatus,
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
            languageFilter: .all,
            watchStateFilter: .all
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
        let folders = source.folderPaths.map(URL.init(fileURLWithPath:))
        switch source.mode {
        case .search:
            page = await search.loadSearchRows(
                range: range,
                folders: folders,
                languageFilter: source.languageFilter,
                watchStateFilter: source.watchStateFilter,
                orderedCueIDs: {
                    guard case .search(_, let cueIDs) = source.mode else {
                        return nil
                    }
                    return cueIDs
                }()
            )
        case .allCues:
            page = await search.loadAllCueRows(range: range, folders: folders)
        case .context(let request):
            page = await search.loadContextRows(
                request: request,
                range: range,
                folders: folders,
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
            guard search.cueContextSearchRequest == nil,
                  search.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines) == query,
                  search.activeFilterSetSignature == source.filterSignature,
                  workbenchSearchHasCompleteTextCopyBoundary(
                      searchStatus: search.searchStatus,
                      countState: search.searchCountState,
                      cueIDs: search.filteredSearchResultCueIDs,
                      resultRowCount: search.filteredSearchResultTotalCount ?? -1
                  ),
                  search.filteredSearchResultTotalCount == source.resultRowCount,
                  search.filteredSearchResultCueIDs == cueIDs
            else {
                return false
            }
            return true
        case .allCues:
            return search.cueContextSearchRequest == nil
                && search.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !search.activeFilterSet.isEffectivelyEmpty
                && search.activeFilterSetSignature == source.filterSignature
                && search.searchResultTotalCount == source.resultRowCount
        case .context(let request):
            return search.cueContextSearchRequest?.id == request.id
                && search.cueContextSearchRequest?.id == request.id
                && search.contextTotalRowCount == source.resultRowCount
        }
    }

    @discardableResult
    private func applyCueContextSearchRequest(_ request: CueContextSearchRequest) -> Bool {
        guard allowsTableResponse else {
            hasDeferredRefreshWhileCovered = true
            return false
        }
        let displayTitle = request.displayTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !displayTitle.isEmpty else {
            return false
        }

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
        filterRules = rules
        search.updateQuery("")
        search.updateNavigationSnapshot(nil)
        appliedFilterSignature = filterSignature
        appState.updateSearchFilterSet(filterSet)
        let didBeginLoad = search.beginContextTableLoad(
            request: request,
            folders: appState.indexing.selectedFolders,
            initialPageSize: TableSandboxHydrationPaging.pageSize,
            continuationPageSize: Self.continuousPageSize
        )
        if didBeginLoad {
            tableScrollTargetRow = nil
            tableScrollResetToken += 1
            clearTableRows(resetScroll: false, cancelContextLoad: false)
        }
        return true
    }

    private var tableSummary: SchemaWorkbenchTableSummary {
        let totalRowCount = tableSummaryTotalRowCount
        return SchemaWorkbenchTableSummary(
            totalRowCount: totalRowCount,
            selectedRowCount: isSelectionMode
                ? rowSelection.selectedCount(rowCount: totalRowCount)
                : 0
        )
    }

    private var canEnterSelectionMode: Bool {
        schemaWorkbenchCanEnterSelectionMode(
            hasExactResultSet: tableTextCopySource != nil
        )
    }

    private var tableSummaryTotalRowCount: Int {
        if showsSearchEmptyHint {
            return 0
        }
        return rowStore.snapshot.totalRowCount
    }

    private var exactSearchResultCountText: String? {
        guard let source = tableTextCopySource,
              case .search = source.mode
        else {
            return nil
        }
        return schemaWorkbenchResultCountText(source.resultRowCount)
    }

    private var selectedSummaryActions: AnyView? {
        guard isSelectionMode, tableSummary.selectedRowCount > 0 else {
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
        search.updateContextRequest(nil)
        suppressNextEmptySearchQueryReload = false
        tableScrollTargetRow = nil
        search.cancelContextTableLoad()
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
        search.activateCurrentSearchTableProjection()
        rowSelection.clamp(rowCount: rowStore.snapshot.totalRowCount)
        refreshSelectedCollageAvailability()
    }

    private var searchCueContentProvider: (Int64) -> CueContent? {
        let store = appState.cueContent
        return { cueID in store.content(for: cueID) }
    }

    private func clearTableRows(
        resetScroll: Bool,
        cancelContextLoad: Bool = true
    ) {
        guard allowsTableResponse else {
            hasDeferredRefreshWhileCovered = true
            resetCoveredTableLoading()
            return
        }
        let releasedRows = max(rowStore.snapshot.loadedReferenceCount, rowStore.snapshot.totalRowCount)
        if cancelContextLoad {
            search.cancelContextTableLoad()
        }
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
        if search.cueContextSearchRequest != nil {
            search.loadAdjacentContextRows(
                visibleRows: visibleRows,
                folders: appState.indexing.selectedFolders,
                pageSize: Self.continuousPageSize
            )
            return
        }
        guard isFilterOnlyMode,
              search.cueContextSearchRequest == nil,
              visibleRows.upperBound >= rowStore.snapshot.totalRowCount - TableSandboxHydrationPaging.pageSize
        else {
            return
        }
        loadAllCueRows(resetScroll: false)
    }

    private func resetCoveredTableLoading() {
        search.suspendFilterOnlyPageLoad()
        search.cancelContextTableLoad()
    }

    private func resumeDeferredTableResponse() {
        guard allowsTableResponse else { return }
        let isStandardSearch = search.cueContextSearchRequest == nil
            && !isFilterOnlyMode
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

    private func loadAllCueRows(resetScroll: Bool) {
        guard allowsTableResponse,
              !appState.indexing.isLibraryFolderOperationActive
        else {
            hasDeferredRefreshWhileCovered = true
            resetCoveredTableLoading()
            return
        }
        tableScrollTargetRow = nil
        search.cancelContextTableLoad()
        lastVisibleRows = nil
        if resetScroll {
            rowSelection.reset()
            persistSelection()
            resetSelectedCollageAvailability()
            tableScrollResetToken += 1
        }
        search.loadFilterOnlyTableRows(
            folders: appState.indexing.selectedFolders,
            initialPageSize: TableSandboxHydrationPaging.pageSize,
            continuationPageSize: Self.continuousPageSize
        )
    }

    private func handleContextTablePresentation() {
        let prepended = search.contextPrependedRowCount
        if prepended > 0 {
            rowSelection.shiftRows(by: prepended)
        }
        rowSelection.clamp(rowCount: rowStore.snapshot.totalRowCount)
        if let sourceIndex = search.contextScrollTargetSourceIndex,
           let loadedRange = search.contextLoadedSourceRange {
            tableScrollTargetRow = cueContextDisplayRow(
                forSourceIndex: sourceIndex,
                loadedSourceRange: loadedRange,
                loadedRowCount: rowStore.snapshot.totalRowCount
            )
            tableScrollResetToken += 1
        }
        search.consumeContextTablePresentation()
        refreshSelectedCollageAvailability()
    }

    private func applyFilterRules(_ rules: [SchemaWorkbenchFilterRule]) {
        let filterSet = rules.subtitleSearchFilterSet
        let nextSignature = filterSet.cacheSignature
        guard nextSignature != appliedFilterSignature else {
            return
        }

        search.updateContextRequest(nil)
        tableScrollTargetRow = nil
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

    private func applySearchFacetFilter(_ filter: CueFacetFilter) {
        exitSelectionMode()
        rowSelection.reset()
        persistSelection()
        search.tableViewportAnchor = nil
        viewportAnchorToRestore = nil
        tableScrollTargetRow = nil
        didRestoreViewport = true
        lastVisibleRows = nil
        tableScrollResetToken += 1
        search.updateSearchFacetFilter(filter)
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
              search.cueContextSearchRequest == nil,
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

    private func toggleSelectionMode() {
        if isSelectionMode {
            exitSelectionMode()
            return
        }
        guard canEnterSelectionMode else { return }
        rowSelection.reset()
        persistSelection()
        resetSelectedCollageAvailability()
        isSelectionMode = true
    }

    private func exitSelectionMode() {
        guard isSelectionMode || rowSelection.selectedCount(rowCount: tableSummaryTotalRowCount) > 0 else {
            return
        }
        isSelectionMode = false
        rowSelection.reset()
        persistSelection()
        resetSelectedCollageAvailability()
    }

    private func restoreSelectionIfPossible() {
        let entryIDs = rowStore.snapshot.orderedEntryIDs
        guard entryIDs == search.tableSelectionEntryIDs else { return }
        rowSelection = search.tableSelectionState
        rowSelection.clamp(rowCount: rowStore.snapshot.totalRowCount)
    }

    private func restoreTableControls() {
        visibleColumnIDs = search.tableVisibleColumnIDs
        if filterRules != search.tableFilterRules {
            suppressNextFilterRulesReload = true
            filterRules = search.tableFilterRules
        }
    }

    private func persistTableControls() {
        search.tableSearchDraft = searchDraft
        search.tableVisibleColumnIDs = visibleColumnIDs
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
