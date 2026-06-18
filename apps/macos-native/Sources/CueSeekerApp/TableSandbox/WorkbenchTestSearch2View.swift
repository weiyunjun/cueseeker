import SwiftUI
import CueSeekerCore

struct WorkbenchTestSearch2View: View {
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
            onSearchSubmit: {
                submitSearchDraft()
            }
        ) { _ in
            SubtitleTableView(
                tableName: "test-search-2",
                rowCount: rowStore.snapshot.totalRowCount,
                rowProvider: { rowStore.snapshot.row(at: $0) },
                rowsVersion: rowStore.snapshot.version,
                rowsUpdate: rowStore.snapshot.update,
                displayTitleHeader: "Display Title",
                showsLanguageColumn: true,
                showsSpeakerColumn: true,
                scrollResetToken: tableScrollResetToken,
                onVisibleRowsChange: hydrateVisibleRows,
                isRowSelected: { rowSelection.isSelected($0, rowCount: rowStore.snapshot.totalRowCount) },
                selectionHeaderState: rowSelection.headerState(rowCount: rowStore.snapshot.totalRowCount),
                onToggleRowSelection: toggleRowSelection,
                onToggleAllSelection: toggleAllRowSelection,
                onPlay: play,
                isRedesign: true
            )
        }
        .onAppear {
            searchDraft = search.searchQuery
            applyFilterRules(filterRules, force: true)
            if isAllCuesMode {
                loadAllCueRows(resetScroll: false)
            } else {
                updateRows(search.searchResults)
            }
        }
        .onChange(of: filterRules) { newValue in
            applyFilterRules(newValue)
        }
        .onReceive(search.$searchResults) {
            guard !isAllCuesMode else { return }
            updateRows($0)
        }
        .onChange(of: search.searchQuery) { newValue in
            searchDraft = newValue
            visibleHydrator.reset()
            rowSelection.reset()
            lastVisibleRows = nil
            if newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                loadAllCueRows(resetScroll: true)
            }
        }
        .onChange(of: search.searchResultTotalCount) { _ in
            guard !isAllCuesMode else { return }
            updateRows(search.searchResults)
            hydrateLastVisibleRowsIfNeeded()
        }
        .onChange(of: search.searchCountState) { _ in
            guard !isAllCuesMode else { return }
            updateRows(search.searchResults)
            hydrateLastVisibleRowsIfNeeded()
        }
        .onDisappear { visibleHydrator.cancel() }
    }

    private var isAllCuesMode: Bool {
        search.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var tableSummary: SchemaWorkbenchTableSummary {
        let totalRowCount = tableSummaryTotalRowCount
        return SchemaWorkbenchTableSummary(
            totalRowCount: totalRowCount,
            selectedRowCount: rowSelection.selectedCount(rowCount: totalRowCount)
        )
    }

    private var tableSummaryTotalRowCount: Int {
        isAllCuesMode ? rowStore.snapshot.totalRowCount : search.searchResultTotalCount
    }

    private var tableSummaryLeadingInset: CGFloat {
        SubtitleTableMetrics.checkboxLeadingInset
    }

    private func submitSearchDraft() {
        let trimmedDraft = searchDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedDraft.isEmpty else {
            appState.submitTopbarSearch(searchDraft)
            return
        }

        search.searchQuery = ""
        search.searchResults = []
        search.searchResultTotalCount = 0
        search.searchNavigationSnapshot = nil
        search.hasMoreSearchResults = false
        loadAllCueRows(resetScroll: true)
    }

    private func updateRows(_ results: [SubtitleSearchResult]) {
        rowStore.updateSearchRows(
            results,
            totalRowCount: search.searchResultTotalCount,
            tableName: "test-search-2"
        )
        rowSelection.clamp(rowCount: rowStore.snapshot.totalRowCount)
        hydrateInitialRowsIfNeeded()
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
            guard let page = await appState.loadTableSandboxAllCueRows(range: 0..<240) else {
                rowStore.updateSearchRows([], totalRowCount: 0, tableName: "test-search-2")
                return
            }
            appState.applyTableSandboxAllCueSearchContext(page)
            rowStore.updateSearchRows(
                page.results,
                totalRowCount: page.totalRowCount,
                tableName: "test-search-2"
            )
            rowSelection.clamp(rowCount: rowStore.snapshot.totalRowCount)
            hydrateLastVisibleRowsIfNeeded()
        }
    }

    private func loadRows(range: Range<Int>) async -> TableSandboxSearchHydrationPage? {
        if isAllCuesMode {
            return await appState.loadTableSandboxAllCueRows(range: range)
        }
        return await appState.loadTableSandboxSearchRows(range: range)
    }

    private func hydrateLastVisibleRowsIfNeeded() {
        guard let lastVisibleRows else {
            return
        }
        hydrateVisibleRows(lastVisibleRows)
    }

    private func applyHydrationPage(_ page: TableSandboxSearchHydrationPage) {
        if isAllCuesMode {
            appState.applyTableSandboxAllCueSearchContext(page)
        }
        rowStore.hydrateSearchRows(
            page.results,
            startIndex: page.range.lowerBound,
            totalRowCount: max(page.totalRowCount, rowStore.snapshot.totalRowCount),
            tableName: "test-search-2"
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
        if isAllCuesMode {
            loadAllCueRows(resetScroll: false)
        }
    }

    private func toggleRowSelection(_ row: Int) {
        rowSelection.toggle(row: row, rowCount: rowStore.snapshot.totalRowCount)
    }

    private func toggleAllRowSelection() {
        rowSelection.toggleAll(rowCount: rowStore.snapshot.totalRowCount)
    }
}
