import SwiftUI
import CueSeekerCore
import CueSeekerPlayback

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
    @State private var tableScrollTargetRow: Int?
    @State private var rowSelection = TableSandboxRowSelectionState()
    @State private var collageAvailabilityGeneration = 0
    @State private var canExportSelectedRowsAsCollage = false
    @State private var lastHandledCueContextRequestID: UUID?
    @State private var activeCueContextRequest: CueContextSearchRequest?
    @State private var cueContextLoadGeneration = 0
    @State private var suppressNextEmptySearchQueryReload = false
    @State private var suppressNextFilterRulesReload = false

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
            tableSummaryAction: selectedSummaryActions,
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
                    scrollTargetRow: tableScrollTargetRow,
                    onVisibleRowsChange: hydrateVisibleRows,
                    isRowSelected: { rowSelection.isSelected($0, rowCount: rowStore.snapshot.totalRowCount) },
                    selectionHeaderState: rowSelection.headerState(rowCount: rowStore.snapshot.totalRowCount),
                    onToggleRowSelection: toggleRowSelection,
                    onToggleAllSelection: toggleAllRowSelection,
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
            if let request = search.cueContextSearchRequest,
               applyCueContextSearchRequest(request) {
                CueContextPerformanceLogger.record(
                    event: "context_search_view_on_appear_applied",
                    contextID: request.id,
                    startedAt: request.requestedAt,
                    displayTitle: request.displayTitle,
                    subtitlePath: request.subtitlePath,
                    targetEntryID: request.targetEntryID,
                    status: "applied"
                )
                return
            }

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
            if suppressNextFilterRulesReload {
                suppressNextFilterRulesReload = false
                return
            }
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
            if !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                activeCueContextRequest = nil
                tableScrollTargetRow = nil
                cueContextLoadGeneration += 1
            }
            if newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if suppressNextEmptySearchQueryReload {
                    suppressNextEmptySearchQueryReload = false
                    return
                }
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
        .onChange(of: search.cueContextSearchRequest) { request in
            guard let request else {
                return
            }
            _ = applyCueContextSearchRequest(request)
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

    @discardableResult
    private func applyCueContextSearchRequest(_ request: CueContextSearchRequest) -> Bool {
        let applyStart = CueContextPerformanceLogger.now()
        guard lastHandledCueContextRequestID != request.id else {
            CueContextPerformanceLogger.record(
                event: "context_request_ignored_duplicate",
                contextID: request.id,
                startedAt: request.requestedAt,
                phaseStart: applyStart,
                displayTitle: request.displayTitle,
                subtitlePath: request.subtitlePath,
                targetEntryID: request.targetEntryID,
                status: "duplicate"
            )
            return false
        }

        let displayTitle = request.displayTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !displayTitle.isEmpty else {
            CueContextPerformanceLogger.record(
                event: "context_request_ignored_empty_title",
                contextID: request.id,
                startedAt: request.requestedAt,
                phaseStart: applyStart,
                subtitlePath: request.subtitlePath,
                targetEntryID: request.targetEntryID,
                status: "ignored"
            )
            return false
        }

        lastHandledCueContextRequestID = request.id
        activeCueContextRequest = request
        cueContextLoadGeneration += 1
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
        CueContextPerformanceLogger.record(
            event: "context_request_applied",
            contextID: request.id,
            startedAt: request.requestedAt,
            phaseStart: applyStart,
            displayTitle: displayTitle,
            subtitlePath: request.subtitlePath,
            targetEntryID: request.targetEntryID,
            generation: generation,
            status: "applied"
        )
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
        return isFilterOnlyMode ? rowStore.snapshot.totalRowCount : search.searchResultTotalCount
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
            }
        )
    }

    private func submitSearchDraft() {
        let trimmedDraft = searchDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedDraft.isEmpty else {
            activeCueContextRequest = nil
            tableScrollTargetRow = nil
            cueContextLoadGeneration += 1
            appState.submitSearch(searchDraft)
            return
        }

        activeCueContextRequest = nil
        tableScrollTargetRow = nil
        cueContextLoadGeneration += 1
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
        refreshSelectedCollageAvailability()
        hydrateInitialRowsIfNeeded()
    }

    private func clearTableRows(resetScroll: Bool) {
        visibleHydrator.reset()
        lastVisibleRows = nil
        rowSelection.reset()
        resetSelectedCollageAvailability()
        rowStore.updateSearchRows([], totalRowCount: 0, tableName: "test-search")
        if resetScroll {
            tableScrollTargetRow = nil
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

    private func showContext(_ row: SubtitleTableRow) {
        guard let result = rowStore.snapshot.searchResult(entryID: row.id)
            ?? search.searchResults.first(where: { Int($0.entryID) == row.id })
        else {
            return
        }

        appState.openSearchResultContext(result)
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
        if let activeCueContextRequest {
            CueContextPerformanceLogger.record(
                event: "context_visible_rows_changed",
                contextID: activeCueContextRequest.id,
                startedAt: activeCueContextRequest.requestedAt,
                displayTitle: activeCueContextRequest.displayTitle,
                subtitlePath: activeCueContextRequest.subtitlePath,
                targetEntryID: activeCueContextRequest.targetEntryID,
                range: visibleRows,
                tableRows: rowStore.snapshot.totalRowCount,
                status: "visibleRows"
            )
        }
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
        activeCueContextRequest = nil
        tableScrollTargetRow = nil
        visibleHydrator.reset()
        lastVisibleRows = nil
        if resetScroll {
            rowSelection.reset()
            resetSelectedCollageAvailability()
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

    private func loadCueContextRows(
        request: CueContextSearchRequest,
        filterSignature: String,
        generation: Int
    ) {
        Task { @MainActor in
            let loadStart = CueContextPerformanceLogger.now()
            CueContextPerformanceLogger.record(
                event: "context_initial_load_started",
                contextID: request.id,
                startedAt: request.requestedAt,
                displayTitle: request.displayTitle,
                subtitlePath: request.subtitlePath,
                targetEntryID: request.targetEntryID,
                range: 0..<TableSandboxHydrationPaging.pageSize,
                generation: generation,
                status: "loading"
            )
            guard let page = await appState.loadCueContextSearchPage(
                request: request,
                range: 0..<TableSandboxHydrationPaging.pageSize,
                anchorsInitialPage: true
            ) else {
                guard generation == cueContextLoadGeneration else { return }
                CueContextPerformanceLogger.record(
                    event: "context_initial_load_empty",
                    contextID: request.id,
                    startedAt: request.requestedAt,
                    phaseStart: loadStart,
                    displayTitle: request.displayTitle,
                    subtitlePath: request.subtitlePath,
                    targetEntryID: request.targetEntryID,
                    range: 0..<TableSandboxHydrationPaging.pageSize,
                    generation: generation,
                    status: "empty"
                )
                rowStore.updateSearchRows([], totalRowCount: 0, tableName: "test-search")
                return
            }
            CueContextPerformanceLogger.record(
                event: "context_initial_load_returned",
                contextID: request.id,
                startedAt: request.requestedAt,
                phaseStart: loadStart,
                displayTitle: request.displayTitle,
                subtitlePath: request.subtitlePath,
                targetEntryID: request.targetEntryID,
                range: page.range,
                returnedRows: page.results.count,
                totalRows: page.totalRowCount,
                generation: generation,
                status: "loaded"
            )

            guard generation == cueContextLoadGeneration,
                  search.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  search.activeFilterSetSignature == filterSignature
            else {
                CueContextPerformanceLogger.record(
                    event: "context_initial_load_discarded",
                    contextID: request.id,
                    startedAt: request.requestedAt,
                    displayTitle: request.displayTitle,
                    subtitlePath: request.subtitlePath,
                    targetEntryID: request.targetEntryID,
                    range: page.range,
                    returnedRows: page.results.count,
                    totalRows: page.totalRowCount,
                    generation: generation,
                    status: "discarded"
                )
                return
            }

            appState.applyTableSandboxAllCueSearchContext(page)
            let rowStoreStart = CueContextPerformanceLogger.now()
            rowStore.hydrateSearchRows(
                page.results,
                startIndex: page.range.lowerBound,
                totalRowCount: page.totalRowCount,
                tableName: "test-search"
            )
            tableScrollTargetRow = page.range.lowerBound
            tableScrollResetToken += 1
            CueContextPerformanceLogger.record(
                event: "context_initial_rows_committed",
                contextID: request.id,
                startedAt: request.requestedAt,
                phaseStart: rowStoreStart,
                displayTitle: request.displayTitle,
                subtitlePath: request.subtitlePath,
                targetEntryID: request.targetEntryID,
                range: page.range,
                returnedRows: page.results.count,
                totalRows: page.totalRowCount,
                tableRows: rowStore.snapshot.totalRowCount,
                generation: generation,
                status: "committed"
            )
            rowSelection.clamp(rowCount: rowStore.snapshot.totalRowCount)
            hydrateLastVisibleRowsIfNeeded()
            CueContextPerformanceLogger.record(
                event: "context_initial_hydration_requested",
                contextID: request.id,
                startedAt: request.requestedAt,
                displayTitle: request.displayTitle,
                subtitlePath: request.subtitlePath,
                targetEntryID: request.targetEntryID,
                range: lastVisibleRows,
                tableRows: rowStore.snapshot.totalRowCount,
                generation: generation,
                status: "scheduled"
            )
        }
    }

    private func loadRows(range: Range<Int>) async -> TableSandboxSearchHydrationPage? {
        if isFilterOnlyMode {
            if let activeCueContextRequest {
                return await appState.loadCueContextSearchPage(
                    request: activeCueContextRequest,
                    range: range
                )
            }
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

        activeCueContextRequest = nil
        tableScrollTargetRow = nil
        cueContextLoadGeneration += 1
        appliedFilterSignature = nextSignature
        visibleHydrator.reset()
        rowSelection.reset()
        resetSelectedCollageAvailability()
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
        collageAvailabilityGeneration += 1
        let generation = collageAvailabilityGeneration
        let selectedRows = rowSelection.selectedRows(rowCount: tableSummaryTotalRowCount)
        guard !selectedRows.isEmpty, selectedRows.count <= 50 else {
            canExportSelectedRowsAsCollage = false
            return
        }

        canExportSelectedRowsAsCollage = false
        Task { @MainActor in
            await hydrateRowsForExport(selectedRows)
            guard generation == collageAvailabilityGeneration else {
                return
            }
            let items = selectedSearchResultsFromSnapshot(for: selectedRows)
                .map { appState.subtitleScreenshotItem(for: $0) }
            canExportSelectedRowsAsCollage = SubtitleScreenshotExporter.canExportCollage(items)
        }
    }

    private func resetSelectedCollageAvailability() {
        collageAvailabilityGeneration += 1
        canExportSelectedRowsAsCollage = false
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
        refreshSelectedCollageAvailability()
    }

    private func toggleAllRowSelection() {
        rowSelection.toggleAll(rowCount: rowStore.snapshot.totalRowCount)
        refreshSelectedCollageAvailability()
    }
}
