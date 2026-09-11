import SwiftUI
import CueSeekerCore

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
    let query: String
    let cueIDs: [Int64]
    let resultRowCount: Int
    let folderPaths: [String]
    let filterSignature: String
    let languageFilter: SubtitleSearchLanguageFilter
    let watchStateFilter: SubtitleSearchWatchStateFilter
}

struct WorkbenchTestSearchView: View {
    /// The filter menu starts closed on every entry to the page.
    static let defaultFilterMenuOpen = false

    let isTableResponseActive: Bool
    @EnvironmentObject private var appState: AppCoordinator
    @EnvironmentObject private var search: SearchStore
    @EnvironmentObject private var settingsStore: SettingsStore
    // Observed so the copy below is re-read when the language changes.
    @EnvironmentObject private var localization: AppLocalizationStore
    @EnvironmentObject private var shioriStore: ShioriStore
    private let rowStore: TableSandboxRowModelStore
    @State private var appliedShowCueGroup: Bool?
    @State private var searchDraft: String
    @State private var tableScrollResetToken = 0
    @State private var tableScrollTargetRow: Int?
    @State private var didRestoreViewport = false
    @State private var hasPreparedViewportRestoration = false
    @State private var viewportAnchorToRestore: TableViewportAnchor?
    @State private var rowSelection = TableSandboxRowSelectionState()
    @State private var isSelectionMode = false
    @State private var hasDeferredRefreshWhileCovered = false
    @State private var isFilterMenuOpen: Bool
    @State private var searchFacetFilter = CueFacetFilter()
    @State private var selectionOverlayAnchor = MenuAnchorHandle()

    init(
        rowStore: TableSandboxRowModelStore,
        isTableResponseActive: Bool = true
    ) {
        self.rowStore = rowStore
        self.isTableResponseActive = isTableResponseActive
        _searchDraft = State(initialValue: "")
        _isFilterMenuOpen = State(initialValue: Self.defaultFilterMenuOpen)
    }

    var body: some View {
        let _ = UIInvalidationProbe.count(
            SubtitleTableProbeSurface.search.counterName("surface_body"),
            scope: appState.uiProbeScope
        )
        let textCopySource = tableTextCopySource
        SchemaWorkbenchSearchShell(
            searchDraft: searchInputBinding,
            columns: SchemaWorkbenchSearchDefaults.columns,
            isRedesign: true,
            tableSummary: tableSummary,
            searchResultCountText: exactSearchResultCountText,
            selectionActions: selectedSummaryActions,
            isSelectionMode: isSelectionMode,
            canEnterSelectionMode: canEnterSelectionMode,
            onToggleSelectionMode: toggleSelectionMode,
            filterMenu: CueFacetFilterMenuModel(
                distribution: facetDistribution,
                availableLanguages: availableFacetLanguages,
                isCalculating: search.isFacetSnapshotCalculating,
                filter: searchFacetFilterBinding
            ),
            isFilterMenuOpen: isFilterMenuOpen,
            onToggleFilterMenu: {
                isFilterMenuOpen.toggle()
            },
            onDismissFilterMenu: {
                isFilterMenuOpen = false
            },
            selectionOverlayAnchor: selectionOverlayAnchor
        ) { tableColumns in
            WorkbenchSearchTableRowsObserver(rowStore: rowStore) { snapshot in
                ZStack {
                    SubtitleTableView(
                        tableName: "test-search",
                        probeSurface: .search,
                        probeScope: appState.uiProbeScope,
                        rowCount: snapshot.totalRowCount,
                        rowProvider: { snapshot.row(at: $0) },
                        rowsVersion: snapshot.version,
                        rowsUpdate: snapshot.update,
                        displayTitleHeader: columnTitle("display", in: tableColumns, fallback: L("table.column.display_title")),
                        timeHeader: columnTitle("time", in: tableColumns, fallback: L("table.column.time_range")),
                        cuesHeader: columnTitle("cues", in: tableColumns, fallback: L("table.column.cues")),
                        languageHeader: columnTitle("language", in: tableColumns, fallback: L("table.column.language")),
                        columnOrder: tableColumns.map(\.id),
                        showsDisplayTitleColumn: containsColumn("display", in: tableColumns),
                        showsTimeColumn: containsColumn("time", in: tableColumns),
                        showsLanguageColumn: containsColumn("language", in: tableColumns),
                        showsCueGroup: appliedShowCueGroup
                            ?? (allowsTableResponse && settingsStore.showCueGroup),
                        scrollResetToken: tableScrollResetToken,
                        scrollTargetRow: tableScrollTargetRow,
                        onVisibleRowsChange: hydrateVisibleRows,
                        isSelectionMode: isSelectionMode,
                        isRowSelected: { rowSelection.isSelected($0, rowCount: snapshot.totalRowCount) },
                        selectionHeaderState: rowSelection.headerState(rowCount: snapshot.totalRowCount),
                        onToggleRowSelection: toggleRowSelection,
                        onShiftRowSelection: shiftSelectRow,
                        onToggleAllSelection: toggleAllRowSelection,
                        selectionOverlayAnchor: selectionOverlayAnchor,
                        allResultsTextCopyRowCount: textCopySource?.resultRowCount,
                        loadRowsForTextCopy: { range in
                            guard let textCopySource else { return nil }
                            return await loadRowsForTextCopy(range: range, source: textCopySource)
                        },
                        onPlay: play,
                        rowActionDestinations: rowActionDestinations,
                        onSaveShiori: saveShiori,
                        onCreateShioriList: createShioriList,
                        isRedesign: true
                    )

                    if showsSearchEmptyHint {
                        WorkbenchEmptyHint(message: L("table.search_empty_hint"))
                    }
                }
                .onChange(of: snapshot.version) { _ in
                    restoreSelectionIfPossible()
                    restoreViewportIfPossible()
                }
            }
        }
        .onAppear {
            search.setTableProjectionResponseActive(allowsTableResponse)
            let persistedFacetFilter = settingsStore.searchFacetFilter
            searchFacetFilter = persistedFacetFilter
            search.updateSearchFacetFilter(persistedFacetFilter)
            prepareViewportRestoration()
            searchDraft = search.tableSearchDraft.isEmpty
                ? search.searchQuery
                : search.tableSearchDraft
            if showsSearchEmptyHint {
                search.clearTableProjectionSource()
                clearTableRows(resetScroll: false)
            } else {
                updateRowsFromResidentSearch()
            }
            restoreSelectionIfPossible()
            restoreViewportIfPossible()
        }
        .onChange(of: search.searchQuery) { newValue in
            exitSelectionMode()
            searchDraft = newValue
            rowSelection.reset()
            persistSelection()
            search.tableViewportAnchor = nil
            viewportAnchorToRestore = nil
            didRestoreViewport = true
            if !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                search.activateResidentSearchTableProjection()
                tableScrollTargetRow = nil
            }
            if newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                search.clearTableProjectionSource()
                clearTableRows(resetScroll: true)
            }
        }
        .onChange(of: search.resultRevision) { _ in
            guard !showsSearchEmptyHint else { return }
            updateRowsFromResidentSearch()
        }
        .onChange(of: canEnterSelectionMode) { canEnter in
            if !canEnter {
                exitSelectionMode()
            }
        }
        .onChange(of: isTableResponseActive) { isActive in
            if !isActive {
                exitSelectionMode()
                // The menu belongs to this page: switching away closes it.
                isFilterMenuOpen = false
            }
            search.setTableProjectionResponseActive(isActive)
            if isActive {
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
            isFilterMenuOpen = false
            search.setTableProjectionResponseActive(false)
            persistSearchDraft()
            persistSelection()
            search.tableViewportAnchor = nil
        }
        .background(
            CueGroupPresentationGate(
                store: settingsStore.cueGroupPresentation,
                isActive: allowsTableResponse,
                appliedValue: $appliedShowCueGroup
            )
        )
    }

    private func containsColumn(_ id: String, in tableColumns: [WorkbenchTableColumn]) -> Bool {
        tableColumns.contains { $0.id == id }
    }

    private func columnTitle(_ id: String, in tableColumns: [WorkbenchTableColumn], fallback: String) -> String {
        tableColumns.first { $0.id == id }?.title ?? fallback
    }

    private var showsSearchEmptyHint: Bool {
        search.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && searchDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var searchFacetFilterBinding: Binding<CueFacetFilter> {
        Binding(
            get: { searchFacetFilter },
            set: { newValue in
                guard !isSelectionMode,
                      !search.isFacetSnapshotCalculating,
                      searchFacetFilter != newValue
                else {
                    return
                }
                searchFacetFilter = newValue
                settingsStore.searchFacetFilter = newValue
                applySearchFacetFilter(newValue)
            }
        )
    }

    private var facetDistribution: CueFacetDistribution? {
        search.displayedSearchFacetDistribution
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

    private var tableTextCopySource: WorkbenchSearchTableTextCopySource? {
        let query = search.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let cueIDs = search.filteredSearchResultCueIDs
        let resultRowCount = search.filteredSearchResultTotalCount ?? -1
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
        return WorkbenchSearchTableTextCopySource(
            query: query,
            cueIDs: cueIDs,
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

        let folders = source.folderPaths.map(URL.init(fileURLWithPath:))
        let page = await search.loadSearchRows(
            range: range,
            folders: folders,
            languageFilter: source.languageFilter,
            watchStateFilter: source.watchStateFilter,
            orderedCueIDs: source.cueIDs
        )

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
        guard search.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines) == source.query,
              search.activeFilterSetSignature == source.filterSignature,
              workbenchSearchHasCompleteTextCopyBoundary(
                  searchStatus: search.searchStatus,
                  countState: search.searchCountState,
                  cueIDs: search.filteredSearchResultCueIDs,
                  resultRowCount: search.filteredSearchResultTotalCount ?? -1
              ),
              search.filteredSearchResultTotalCount == source.resultRowCount,
              search.filteredSearchResultCueIDs == source.cueIDs
        else {
            return false
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
        guard let source = tableTextCopySource else {
            return nil
        }
        return schemaWorkbenchResultCountText(source.resultRowCount)
    }

    private var selectedSummaryActions: [SchemaWorkbenchSelectionAction]? {
        guard isSelectionMode else {
            return nil
        }
        return SchemaWorkbenchSelectionAction.exportActions(
            exportToAnki: exportSelectedRowsToAnki,
            copyDeepLinks: copySelectedRowsAsDeepLinks,
            copyTable: copySelectedRowsAsTable
        )
    }

    private func updateSearchDraft(_ newValue: String) {
        guard newValue != search.searchQuery else {
            return
        }
        search.tableSearchDraft = newValue
        tableScrollTargetRow = nil
        appState.updateSearchQuery(newValue)
    }

    private func updateRowsFromResidentSearch() {
        guard allowsTableResponse else {
            hasDeferredRefreshWhileCovered = true
            return
        }
        search.activateCurrentSearchTableProjection()
        rowSelection.clamp(rowCount: rowStore.snapshot.totalRowCount)
    }

    private var searchCueContentProvider: (Int64) -> CueContent? {
        let store = appState.cueContent
        return { cueID in store.content(for: cueID) }
    }

    private func clearTableRows(resetScroll: Bool) {
        guard allowsTableResponse else {
            hasDeferredRefreshWhileCovered = true
            return
        }
        let releasedRows = max(rowStore.snapshot.loadedReferenceCount, rowStore.snapshot.totalRowCount)
        rowSelection.reset()
        persistSelection()
        rowStore.updateResidentSearchResults(
            [],
            cueContentProvider: searchCueContentProvider,
            cueContentRevision: appState.cueContent.revision,
            tableName: "test-search",
            probeSurface: .search,
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

    /// Search has no current list, so every list is a destination.
    private var rowActionDestinations: [SubtitleTableRowActionDestination] {
        shioriStore.saveDestinations
    }

    private func saveShiori(_ row: SubtitleTableRow, toListID listID: Int64) {
        guard let cueID = row.primaryCueID else { return }
        appState.saveShiori(
            cueID: cueID,
            toListID: listID,
            listName: shioriStore.listName(id: listID),
            report: .toast
        )
    }

    private func createShioriList(
        _ row: SubtitleTableRow,
        for action: SubtitleTableRowAction
    ) {
        guard let cueID = row.primaryCueID else { return }
        appState.beginCreatingShioriList(
            pendingTransfer: ShioriListEditorPendingTransfer(
                action: action,
                target: .cue(cueID)
            )
        )
    }

    private func play(_ row: SubtitleTableRow) {
        guard let result = rowStore.snapshot.searchResult(entryID: row.id)
            ?? search.searchResults.first(where: { Int($0.entryID) == row.id })
        else {
            return
        }
        appState.openSearchResult(result, displayTitle: row.displayTitle)
    }

    private func hydrateVisibleRows(_ visibleRows: Range<Int>) {
        guard allowsTableResponse else { return }
        captureVisibleRows(visibleRows)
    }

    private func resumeDeferredTableResponse() {
        guard allowsTableResponse else { return }
        guard hasDeferredRefreshWhileCovered else { return }
        hasDeferredRefreshWhileCovered = false
        refreshTableForCurrentState()
    }

    private func refreshTableForCurrentState() {
        if showsSearchEmptyHint {
            clearTableRows(resetScroll: false)
        } else {
            updateRowsFromResidentSearch()
        }
    }

    private func applySearchFacetFilter(_ filter: CueFacetFilter) {
        UIInvalidationProbe.mark(
            "ACTION UI.SearchFacetFilter.changed",
            scope: appState.uiProbeScope
        )
        exitSelectionMode()
        rowSelection.reset()
        persistSelection()
        search.tableViewportAnchor = nil
        viewportAnchorToRestore = nil
        tableScrollTargetRow = nil
        didRestoreViewport = true
        tableScrollResetToken += 1
        search.updateSearchFacetFilter(filter)
    }

    private func exportSelectedRowsToAnki() {
        let selectedRows = rowSelection.selectedRows(rowCount: tableSummaryTotalRowCount)
        guard !selectedRows.isEmpty else {
            return
        }

        Task { @MainActor in
            let selection = await selectedSearchResults(for: selectedRows)
            appState.exportSearchResultsToAnki(selection)
        }
    }

    private func copySelectedRowsAsTable() {
        let rowCount = tableSummaryTotalRowCount
        let selection = rowSelection
        guard selection.selectedCount(rowCount: rowCount) > 0 else {
            return
        }

        let columns = SubtitleTableClipboard.columns(
            from: SchemaWorkbenchSearchDefaults.columns
        )
        let selectedRows = selection.selectedRows(rowCount: rowCount)
        guard !selectedRows.isEmpty else {
            return
        }

        var builder = SubtitleTableClipboard.TSVBuilder(columns: columns)
        builder.append(rows: selectedRows.compactMap { rowStore.snapshot.row(at: $0) })
        SubtitleTableClipboard.copy(representations: builder.representations)
    }

    private func copySelectedRowsAsDeepLinks() {
        let selectedRows = rowSelection.selectedRows(
            rowCount: tableSummaryTotalRowCount
        )
        guard !selectedRows.isEmpty else { return }
        let rows = selectedRows.compactMap { rowStore.snapshot.row(at: $0) }
        guard rows.count == selectedRows.count else { return }
        SubtitleTableClipboard.copyDeepLinks(rows: rows)
    }

    private func selectedSearchResults(
        for selectedRows: [Int]
    ) async -> [(result: SubtitleSearchResult, row: SubtitleTableRow)] {
        await hydrateRowsForExport(selectedRows)
        return selectedRows.compactMap { row in
            guard let tableRow = rowStore.snapshot.row(at: row),
                  let result = rowStore.snapshot.searchResult(entryID: tableRow.id)
                    ?? search.searchResults.first(where: { Int($0.entryID) == tableRow.id })
            else {
                return nil
            }
            return (result, tableRow)
        }
    }

    private func hydrateRowsForExport(_ selectedRows: [Int]) async {
        _ = selectedRows
    }

    private func toggleRowSelection(_ row: Int) {
        rowSelection.toggle(row: row, rowCount: rowStore.snapshot.totalRowCount)
        persistSelection()
    }

    private func shiftSelectRow(_ row: Int) {
        rowSelection.shiftClick(row: row, rowCount: rowStore.snapshot.totalRowCount)
        persistSelection()
    }

    private func toggleAllRowSelection() {
        rowSelection.toggleAll(rowCount: rowStore.snapshot.totalRowCount)
        persistSelection()
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
        isSelectionMode = true
    }

    private func exitSelectionMode() {
        guard isSelectionMode || rowSelection.selectedCount(rowCount: tableSummaryTotalRowCount) > 0 else {
            return
        }
        isSelectionMode = false
        rowSelection.reset()
        persistSelection()
    }

    private func restoreSelectionIfPossible() {
        let entryIDs = rowStore.snapshot.orderedEntryIDs
        guard entryIDs == search.tableSelectionEntryIDs else { return }
        rowSelection = search.tableSelectionState
        rowSelection.clamp(rowCount: rowStore.snapshot.totalRowCount)
    }

    private func persistSearchDraft() {
        search.tableSearchDraft = searchDraft
    }
}

private struct WorkbenchSearchTableRowsObserver<Content: View>: View {
    @ObservedObject var rowStore: TableSandboxRowModelStore
    @ViewBuilder let content: (TableSandboxRowsSnapshot) -> Content

    var body: some View {
        content(rowStore.snapshot)
    }
}
