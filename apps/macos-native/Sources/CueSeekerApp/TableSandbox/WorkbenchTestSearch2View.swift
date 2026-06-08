import SwiftUI
import CueSeekerCore

struct WorkbenchTestSearch2View: View {
    @EnvironmentObject private var appState: AppCoordinator
    @EnvironmentObject private var search: SearchStore
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
            columns: SchemaWorkbenchSearchDefaults.columns,
            filterSets: SchemaWorkbenchSearchDefaults.filterSets,
            onSearchSubmit: {
                appState.submitTopbarSearch(searchDraft)
            }
        ) { _ in
            SubtitleTableView(
                tableName: "test-search-2",
                rowCount: rowStore.snapshot.totalRowCount,
                rowProvider: { rowStore.snapshot.row(at: $0) },
                rowsVersion: rowStore.snapshot.version,
                rowsUpdate: rowStore.snapshot.update,
                showsLanguageColumn: true,
                onVisibleRowsChange: hydrateVisibleRows,
                onPlay: play
            )
        }
        .onAppear {
            searchDraft = search.searchQuery
            updateRows(search.searchResults)
        }
        .onReceive(search.$searchResults) { updateRows($0) }
        .onChange(of: search.searchQuery) { newValue in
            searchDraft = newValue
            visibleHydrator.reset()
            lastVisibleRows = nil
        }
        .onChange(of: search.searchResultTotalCount) { _ in
            updateRows(search.searchResults)
            hydrateLastVisibleRowsIfNeeded()
        }
        .onChange(of: search.searchCountState) { _ in
            updateRows(search.searchResults)
            hydrateLastVisibleRowsIfNeeded()
        }
        .onDisappear { visibleHydrator.cancel() }
    }

    private func updateRows(_ results: [SubtitleSearchResult]) {
        rowStore.updateSearchRows(
            results,
            totalRowCount: search.searchResultTotalCount,
            tableName: "test-search-2"
        )
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
                await appState.loadTableSandboxSearchRows(range: range)
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
                await appState.loadTableSandboxSearchRows(range: range)
            },
            apply: applyHydrationPage
        )
    }

    private func hydrateLastVisibleRowsIfNeeded() {
        guard let lastVisibleRows else {
            return
        }
        hydrateVisibleRows(lastVisibleRows)
    }

    private func applyHydrationPage(_ page: TableSandboxSearchHydrationPage) {
        rowStore.hydrateSearchRows(
            page.results,
            startIndex: page.range.lowerBound,
            totalRowCount: max(search.searchResultTotalCount, rowStore.snapshot.totalRowCount),
            tableName: "test-search-2"
        )
    }
}
