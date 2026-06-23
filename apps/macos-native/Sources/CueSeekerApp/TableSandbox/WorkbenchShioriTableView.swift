import SwiftUI
import CueSeekerCore

struct WorkbenchShioriTableView: View {
    @EnvironmentObject private var shioriStore: ShioriStore

    var body: some View {
        WorkbenchShioriTableContent(rowStore: shioriStore.tableRowStore)
    }
}

private struct WorkbenchShioriTableContent: View {
    @EnvironmentObject private var appState: AppCoordinator
    @EnvironmentObject private var shioriStore: ShioriStore
    @EnvironmentObject private var settingsStore: SettingsStore
    @ObservedObject var rowStore: TableSandboxRowModelStore
    @StateObject private var visibleHydrator = TableSandboxVisibleShioriHydrator(
        debounceNanoseconds: 16_000_000,
        prefetchPageCount: 0,
        smallResultEagerLoadThreshold: 0
    )
    @State private var tableScrollResetToken = 0
    @State private var rowSelection = TableSandboxRowSelectionState()
    @State private var lastVisibleRows: Range<Int>?
    @State private var reloadGeneration = 0
    @State private var pendingRemoval: Shiori?

    var body: some View {
        SchemaWorkbenchSearchShell(
            searchDraft: $shioriStore.tableSearchDraft,
            visibleColumnIDs: $shioriStore.tableVisibleColumnIDs,
            activeFilterSetID: $shioriStore.tableActiveFilterSetID,
            filterRules: $shioriStore.tableFilterRules,
            filterSets: $settingsStore.searchFilterSets,
            columns: SchemaWorkbenchSearchDefaults.shioriColumns,
            searchPlaceholder: "Search Shiori by title or cues...",
            isRedesign: true,
            tableSummary: tableSummary,
            tableSummaryLeadingInset: tableSummaryLeadingInset,
            tableSummaryAction: selectedAnkiAction,
            filterableColumnIDs: ["display", "cues", "language"],
            onSearchSubmit: {
                submitSearchDraft()
            }
        ) { visibleColumns in
            ZStack {
                SubtitleTableView(
                    tableName: "shiori",
                    rowCount: rowStore.snapshot.totalRowCount,
                    rowProvider: { rowStore.snapshot.row(at: $0) },
                    rowsVersion: rowStore.snapshot.version,
                    rowsUpdate: rowStore.snapshot.update,
                    dateAddedHeader: columnTitle("dateAdded", in: visibleColumns, fallback: "Date Added"),
                    displayTitleHeader: columnTitle("display", in: visibleColumns, fallback: "Display Title"),
                    cuesHeader: columnTitle("cues", in: visibleColumns, fallback: "Cues"),
                    languageHeader: columnTitle("language", in: visibleColumns, fallback: "Language"),
                    showsDateAddedColumn: isColumnVisible("dateAdded", in: visibleColumns),
                    showsDisplayTitleColumn: isColumnVisible("display", in: visibleColumns),
                    showsLanguageColumn: isColumnVisible("language", in: visibleColumns),
                    showsSpeakerColumn: false,
                    scrollResetToken: tableScrollResetToken,
                    onVisibleRowsChange: hydrateVisibleRows,
                    isRowSelected: { rowSelection.isSelected($0, rowCount: rowStore.snapshot.totalRowCount) },
                    selectionHeaderState: rowSelection.headerState(rowCount: rowStore.snapshot.totalRowCount),
                    onToggleRowSelection: toggleRowSelection,
                    onToggleAllSelection: toggleAllRowSelection,
                    onPlay: openShiori,
                    rowActionMenuStyle: .shiori,
                    onRemoveShiori: requestRemoveShiori,
                    isRedesign: true
                )

                if shioriStore.tableHasLoadedInitialPage && shioriStore.tableTotalSavedRowCount == 0 {
                    WorkbenchEmptyHint(message: "Save cues from playback to collect Shiori.")
                }
            }
        }
        .overlay {
            if let pendingRemoval {
                WorkbenchConfirmationDialog(
                    systemImage: "bookmark.slash",
                    title: "Remove Shiori?",
                    message: "This cue will be removed from your Shiori. The original subtitle and video files will not be deleted.",
                    confirmTitle: "Remove",
                    cancelTitle: "Cancel",
                    onConfirm: {
                        confirmRemoveShiori(pendingRemoval)
                    },
                    onCancel: {
                        self.pendingRemoval = nil
                    }
                )
                .zIndex(20)
            }
        }
        .task {
            loadInitialRowsIfNeeded()
        }
        .onChange(of: shioriStore.tableDataRevision) { _ in
            reloadRows(resetScroll: false)
        }
        .onChange(of: shioriStore.tableFilterRules) { _ in
            reloadRows(resetScroll: true)
        }
        .onDisappear { visibleHydrator.cancel() }
    }

    private var tableSummary: SchemaWorkbenchTableSummary {
        SchemaWorkbenchTableSummary(
            totalRowCount: rowStore.snapshot.totalRowCount,
            selectedRowCount: rowSelection.selectedCount(rowCount: rowStore.snapshot.totalRowCount)
        )
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

    private func isColumnVisible(_ id: String, in visibleColumns: [WorkbenchTableColumn]) -> Bool {
        visibleColumns.contains { $0.id == id }
    }

    private func columnTitle(_ id: String, in visibleColumns: [WorkbenchTableColumn], fallback: String) -> String {
        visibleColumns.first { $0.id == id }?.title ?? fallback
    }

    private func loadInitialRowsIfNeeded() {
        guard !shioriStore.tableHasLoadedInitialPage else {
            hydrateLastVisibleRowsIfNeeded()
            return
        }
        reloadRows(resetScroll: false)
    }

    private func submitSearchDraft() {
        let trimmedDraft = shioriStore.tableSearchDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        shioriStore.tableSubmittedSearchText = trimmedDraft
        reloadRows(resetScroll: true)
    }

    private func reloadRows(resetScroll: Bool) {
        reloadGeneration += 1
        let generation = reloadGeneration
        visibleHydrator.reset()
        lastVisibleRows = nil
        rowSelection.reset()
        shioriStore.clearTableRowsForReload()
        if resetScroll {
            tableScrollResetToken += 1
        }

        Task { @MainActor in
            guard let page = await loadRows(range: 0..<TableSandboxHydrationPaging.pageSize) else {
                guard generation == reloadGeneration else { return }
                shioriStore.markTableRowsLoaded(totalSavedRowCount: 0)
                return
            }

            guard generation == reloadGeneration else {
                return
            }
            applyHydrationPage(page)
            shioriStore.markTableRowsLoaded(totalSavedRowCount: page.totalSavedRowCount)
            hydrateLastVisibleRowsIfNeeded()
        }
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

    private func loadRows(range: Range<Int>) async -> TableSandboxShioriHydrationPage? {
        await appState.loadTableSandboxShioriRows(
            range: range,
            searchText: shioriStore.tableSubmittedSearchText,
            filterSet: shioriStore.tableFilterRules.subtitleSearchFilterSet
        )
    }

    private func hydrateLastVisibleRowsIfNeeded() {
        guard let lastVisibleRows else {
            return
        }
        hydrateVisibleRows(lastVisibleRows)
    }

    private func applyHydrationPage(_ page: TableSandboxShioriHydrationPage) {
        shioriStore.tableTotalSavedRowCount = page.totalSavedRowCount
        rowStore.hydrateShioriRows(
            page.rows,
            startIndex: page.range.lowerBound,
            totalRowCount: page.totalRowCount,
            tableName: "shiori"
        )
        rowSelection.clamp(rowCount: rowStore.snapshot.totalRowCount)
    }

    private func openShiori(_ row: SubtitleTableRow) {
        guard let item = rowStore.snapshot.shiori(entryID: row.id) else {
            return
        }
        appState.openShiori(item)
    }

    private func requestRemoveShiori(_ row: SubtitleTableRow) {
        pendingRemoval = rowStore.snapshot.shiori(entryID: row.id)
    }

    private func confirmRemoveShiori(_ item: Shiori) {
        pendingRemoval = nil
        guard appState.removeShiori(item, reloadPresentation: false) else {
            return
        }
    }

    private func exportSelectedRowsToAnki() {
        let selectedRows = rowSelection.selectedRows(rowCount: rowStore.snapshot.totalRowCount)
        guard !selectedRows.isEmpty else {
            return
        }

        Task { @MainActor in
            let selectedShioris = await selectedShioris(for: selectedRows)
            appState.exportShiorisToAnki(selectedShioris)
        }
    }

    private func selectedShioris(for selectedRows: [Int]) async -> [Shiori] {
        await hydrateRowsForExport(selectedRows)
        return selectedRows.compactMap { row in
            guard let tableRow = rowStore.snapshot.row(at: row) else {
                return nil
            }
            return rowStore.snapshot.shiori(entryID: tableRow.id)
        }
    }

    private func hydrateRowsForExport(_ selectedRows: [Int]) async {
        let missingRows = selectedRows.filter { row in
            guard let tableRow = rowStore.snapshot.row(at: row) else {
                return true
            }
            return rowStore.snapshot.shiori(entryID: tableRow.id) == nil
        }
        guard !missingRows.isEmpty else {
            return
        }

        let pageSize = TableSandboxHydrationPaging.pageSize
        let rowCount = rowStore.snapshot.totalRowCount
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
