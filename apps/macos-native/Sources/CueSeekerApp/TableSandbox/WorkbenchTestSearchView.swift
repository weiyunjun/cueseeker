import SwiftUI
import CueSeekerCore

struct WorkbenchTestSearchView: View {
    @EnvironmentObject private var appState: AppCoordinator
    @EnvironmentObject private var search: SearchStore
    @EnvironmentObject private var settingsStore: SettingsStore
    @StateObject private var rowStore = TableSandboxRowModelStore()
    @StateObject private var visibleHydrator = TableSandboxVisibleSearchHydrator(
        debounceNanoseconds: 16_000_000,
        prefetchPageCount: 0,
        smallResultEagerLoadThreshold: 0
    )
    @State private var searchDraft: String
    @State private var visibleColumnIDs: Set<String>
    @State private var activeFilterSetID: String?
    @State private var filterRules: [SchemaWorkbenchFilterRule]
    @State private var lastVisibleRows: Range<Int>?
    @State private var appliedFilterSignature = ""
    @State private var tableScrollResetToken = 0
    @State private var rowSelection = TableSandboxRowSelectionState()

    init() {
        _searchDraft = State(initialValue: "")
        _visibleColumnIDs = State(initialValue: SchemaWorkbenchSearchDefaults.initialVisibleColumnIDs)
        _activeFilterSetID = State(initialValue: SchemaWorkbenchSearchDefaults.defaultFilterSetID)
        _filterRules = State(initialValue: SchemaWorkbenchSearchDefaults.defaultFilterRules)
    }

    var body: some View {
        SchemaWorkbenchSearchShell(
            searchDraft: $searchDraft,
            visibleColumnIDs: $visibleColumnIDs,
            activeFilterSetID: $activeFilterSetID,
            filterRules: $filterRules,
            filterSets: $settingsStore.searchFilterSets,
            columns: SchemaWorkbenchSearchDefaults.columns,
            isRedesign: true,
            tableSummary: tableSummary,
            tableSummaryLeadingInset: tableSummaryLeadingInset,
            tableSummaryAction: selectedAnkiAction,
            filterableColumnIDs: ["display", "cues"],
            onSearchSubmit: {
                submitSearchDraft()
            }
        ) { visibleColumns in
            ZStack {
                SubtitleTableView(
                    tableName: "test-search",
                    rowCount: rowStore.snapshot.totalRowCount,
                    rowProvider: { rowStore.snapshot.row(at: $0) },
                    rowsVersion: rowStore.snapshot.version,
                    rowsUpdate: rowStore.snapshot.update,
                    displayTitleHeader: columnTitle("display", in: visibleColumns, fallback: "Display Title"),
                    startTimeHeader: columnTitle("startTime", in: visibleColumns, fallback: "Start Time"),
                    endTimeHeader: columnTitle("endTime", in: visibleColumns, fallback: "End Time"),
                    cuesHeader: columnTitle("cues", in: visibleColumns, fallback: "Cues"),
                    speakerHeader: columnTitle("speaker", in: visibleColumns, fallback: "Speaker"),
                    languageHeader: columnTitle("language", in: visibleColumns, fallback: "Language"),
                    showsDisplayTitleColumn: isColumnVisible("display", in: visibleColumns),
                    showsStartTimeColumn: isColumnVisible("startTime", in: visibleColumns),
                    showsEndTimeColumn: isColumnVisible("endTime", in: visibleColumns),
                    showsLanguageColumn: isColumnVisible("language", in: visibleColumns),
                    showsSpeakerColumn: isColumnVisible("speaker", in: visibleColumns),
                    scrollResetToken: tableScrollResetToken,
                    onVisibleRowsChange: hydrateVisibleRows,
                    isRowSelected: { rowSelection.isSelected($0, rowCount: rowStore.snapshot.totalRowCount) },
                    selectionHeaderState: rowSelection.headerState(rowCount: rowStore.snapshot.totalRowCount),
                    onToggleRowSelection: toggleRowSelection,
                    onToggleAllSelection: toggleAllRowSelection,
                    onPlay: play,
                    isRedesign: true
                )

                if showsSearchEmptyHint {
                    WorkbenchEmptyHint(message: "Enter a search term or add filters to show cues.")
                }
            }
        }
        .onAppear {
            searchDraft = search.searchQuery
            applyFilterRules(filterRules, force: true)
            if showsSearchEmptyHint {
                clearTableRows(resetScroll: false)
            } else if isFilterOnlyMode {
                loadAllCueRows(resetScroll: false)
            } else {
                updateRows(search.searchResults)
            }
        }
        .onChange(of: filterRules) { newValue in
            applyFilterRules(newValue)
        }
        .onReceive(search.$searchResults) {
            guard !isFilterOnlyMode, !showsSearchEmptyHint else { return }
            updateRows($0)
        }
        .onChange(of: search.searchQuery) { newValue in
            searchDraft = newValue
            visibleHydrator.reset()
            rowSelection.reset()
            lastVisibleRows = nil
            if newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if search.activeFilterSet.isEffectivelyEmpty {
                    clearTableRows(resetScroll: true)
                } else {
                    loadAllCueRows(resetScroll: true)
                }
            }
        }
        .onChange(of: search.searchResultTotalCount) { _ in
            guard !isFilterOnlyMode, !showsSearchEmptyHint else { return }
            updateRows(search.searchResults)
            hydrateLastVisibleRowsIfNeeded()
        }
        .onChange(of: search.searchCountState) { _ in
            guard !isFilterOnlyMode, !showsSearchEmptyHint else { return }
            updateRows(search.searchResults)
            hydrateLastVisibleRowsIfNeeded()
        }
        .onDisappear { visibleHydrator.cancel() }
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
        return isFilterOnlyMode ? rowStore.snapshot.totalRowCount : search.searchResultTotalCount
    }

    private var tableSummaryLeadingInset: CGFloat {
        SubtitleTableMetrics.checkboxLeadingInset
    }

    private var selectedAnkiAction: AnyView? {
        guard tableSummary.selectedRowCount > 0 else {
            return nil
        }
        return AnyView(
            WorkbenchButton(
                title: "Anki",
                systemImage: "square.and.arrow.up",
                isRedesign: true,
                action: exportSelectedRowsToAnki
            )
        )
    }

    private func submitSearchDraft() {
        let trimmedDraft = searchDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedDraft.isEmpty else {
            appState.submitSearch(searchDraft)
            return
        }

        search.searchQuery = ""
        search.searchResults = []
        search.searchResultTotalCount = 0
        search.searchNavigationSnapshot = nil
        search.hasMoreSearchResults = false
        if search.activeFilterSet.isEffectivelyEmpty {
            clearTableRows(resetScroll: true)
        } else {
            loadAllCueRows(resetScroll: true)
        }
    }

    private func updateRows(_ results: [SubtitleSearchResult]) {
        rowStore.updateSearchRows(
            results,
            totalRowCount: search.searchResultTotalCount,
            tableName: "test-search"
        )
        rowSelection.clamp(rowCount: rowStore.snapshot.totalRowCount)
        hydrateInitialRowsIfNeeded()
    }

    private func clearTableRows(resetScroll: Bool) {
        visibleHydrator.reset()
        lastVisibleRows = nil
        rowSelection.reset()
        rowStore.updateSearchRows([], totalRowCount: 0, tableName: "test-search")
        if resetScroll {
            tableScrollResetToken += 1
        }
    }

    private func play(_ row: SubtitleTableRow) {
        guard let result = rowStore.snapshot.searchResult(entryID: row.id)
            ?? search.searchResults.first(where: { Int($0.entryID) == row.id })
        else {
            return
        }
        appState.openSearchResult(result)
    }

    private func hydrateInitialRowsIfNeeded() {
        visibleHydrator.scheduleInitialCompletion(
            totalRowCount: rowStore.snapshot.totalRowCount,
            isRowLoaded: { rowStore.snapshot.row(at: $0) != nil },
            load: { range in
                await loadRows(range: range)
            },
            apply: applyHydrationPage
        )
    }

    private func hydrateVisibleRows(_ visibleRows: Range<Int>) {
        lastVisibleRows = visibleRows
        visibleHydrator.schedule(
            visibleRows: visibleRows,
            totalRowCount: rowStore.snapshot.totalRowCount,
            isRowLoaded: { rowStore.snapshot.row(at: $0) != nil },
            load: { range in
                await loadRows(range: range)
            },
            apply: applyHydrationPage
        )
    }

    private func loadAllCueRows(resetScroll: Bool) {
        visibleHydrator.reset()
        lastVisibleRows = nil
        if resetScroll {
            rowSelection.reset()
            tableScrollResetToken += 1
        }

        Task { @MainActor in
            guard search.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return
            }
            guard !search.activeFilterSet.isEffectivelyEmpty else {
                return
            }
            guard let page = await appState.loadTableSandboxAllCueRows(
                range: 0..<TableSandboxHydrationPaging.pageSize
            ) else {
                rowStore.updateSearchRows([], totalRowCount: 0, tableName: "test-search")
                return
            }
            appState.applyTableSandboxAllCueSearchContext(page)
            rowStore.updateSearchRows(
                page.results,
                totalRowCount: page.totalRowCount,
                tableName: "test-search"
            )
            rowSelection.clamp(rowCount: rowStore.snapshot.totalRowCount)
            hydrateLastVisibleRowsIfNeeded()
        }
    }

    private func loadRows(range: Range<Int>) async -> TableSandboxSearchHydrationPage? {
        if isFilterOnlyMode {
            return await appState.loadTableSandboxAllCueRows(range: range)
        }
        guard !showsSearchEmptyHint else { return nil }
        return await appState.loadTableSandboxSearchRows(range: range)
    }

    private func hydrateLastVisibleRowsIfNeeded() {
        guard let lastVisibleRows else {
            return
        }
        hydrateVisibleRows(lastVisibleRows)
    }

    private func applyHydrationPage(_ page: TableSandboxSearchHydrationPage) {
        if isFilterOnlyMode {
            appState.applyTableSandboxAllCueSearchContext(page)
        }
        rowStore.hydrateSearchRows(
            page.results,
            startIndex: page.range.lowerBound,
            totalRowCount: max(page.totalRowCount, rowStore.snapshot.totalRowCount),
            tableName: "test-search"
        )
        rowSelection.clamp(rowCount: rowStore.snapshot.totalRowCount)
    }

    private func applyFilterRules(_ rules: [SchemaWorkbenchFilterRule], force: Bool = false) {
        let filterSet = rules.subtitleSearchFilterSet
        let nextSignature = filterSet.cacheSignature
        guard force || nextSignature != appliedFilterSignature else {
            return
        }

        appliedFilterSignature = nextSignature
        visibleHydrator.reset()
        rowSelection.reset()
        lastVisibleRows = nil
        tableScrollResetToken += 1
        appState.updateSearchFilterSet(filterSet)
        if search.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if filterSet.isEffectivelyEmpty {
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

    private func hydrateRowsForExport(_ selectedRows: [Int]) async {
        let missingRows = selectedRows.filter { row in
            guard let tableRow = rowStore.snapshot.row(at: row) else {
                return true
            }
            return rowStore.snapshot.searchResult(entryID: tableRow.id) == nil
        }
        guard !missingRows.isEmpty else {
            return
        }

        let pageSize = TableSandboxHydrationPaging.pageSize
        let rowCount = tableSummaryTotalRowCount
        var requestedStarts: Set<Int> = []
        let ranges = missingRows
            .map { row -> Range<Int> in
                let start = max(0, (row / pageSize) * pageSize)
                let end = min(rowCount, start + pageSize)
                return start..<end
            }
            .filter { range in
                guard !requestedStarts.contains(range.lowerBound), !range.isEmpty else {
                    return false
                }
                requestedStarts.insert(range.lowerBound)
                return true
            }

        for range in ranges {
            guard let page = await loadRows(range: range) else {
                continue
            }
            applyHydrationPage(page)
        }
    }

    private func toggleRowSelection(_ row: Int) {
        rowSelection.toggle(row: row, rowCount: rowStore.snapshot.totalRowCount)
    }

    private func toggleAllRowSelection() {
        rowSelection.toggleAll(rowCount: rowStore.snapshot.totalRowCount)
    }
}
