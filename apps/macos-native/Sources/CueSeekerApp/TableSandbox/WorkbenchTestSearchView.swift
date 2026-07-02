import SwiftUI
import CueSeekerCore
import CueSeekerPlayback

struct WorkbenchTestSearchView: View {
    @EnvironmentObject private var appState: AppCoordinator
    @EnvironmentObject private var search: SearchStore
    @EnvironmentObject private var settingsStore: SettingsStore
    @StateObject private var rowStore = TableSandboxRowModelStore()
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
    @State private var continuousLoadGeneration = 0
    @State private var isLoadingContinuousRows = false
    @State private var cueContextLoadedSourceRange: Range<Int>?
    @State private var cueContextTotalRowCount = 0
    @State private var cueContextTargetSourceIndex: Int?
    @State private var isLoadingCueContextRows = false
    @State private var suppressNextEmptySearchQueryReload = false
    @State private var suppressNextFilterRulesReload = false

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
                    timeHeader: columnTitle("time", in: visibleColumns, fallback: "Time"),
                    cuesHeader: columnTitle("cues", in: visibleColumns, fallback: "Cues"),
                    speakerHeader: columnTitle("speaker", in: visibleColumns, fallback: "Speaker"),
                    languageHeader: columnTitle("language", in: visibleColumns, fallback: "Language"),
                    columnOrder: visibleColumns.map(\.id),
                    showsDisplayTitleColumn: isColumnVisible("display", in: visibleColumns),
                    showsTimeColumn: isColumnVisible("time", in: visibleColumns),
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
            resetContinuousRowLoading()
            rowSelection.reset()
            lastVisibleRows = nil
            if !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
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
                    clearTableRows(resetScroll: true)
                } else {
                    loadAllCueRows(resetScroll: true)
                }
            }
        }
        .onChange(of: search.searchResultTotalCount) { _ in
            guard !isFilterOnlyMode, !showsSearchEmptyHint else { return }
            updateRows(search.searchResults)
        }
        .onChange(of: search.searchCountState) { _ in
            guard !isFilterOnlyMode, !showsSearchEmptyHint else { return }
            updateRows(search.searchResults)
        }
        .onChange(of: search.searchResultCueGroupIDs) { _ in
            guard !isFilterOnlyMode, !showsSearchEmptyHint else { return }
            updateRows(search.searchResults)
        }
        .onChange(of: search.cueContextSearchRequest) { request in
            guard let request else {
                return
            }
            _ = applyCueContextSearchRequest(request)
        }
        .onDisappear {
            resetContinuousRowLoading()
        }
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
        guard lastHandledCueContextRequestID != request.id else {
            return false
        }

        let displayTitle = request.displayTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !displayTitle.isEmpty else {
            return false
        }

        lastHandledCueContextRequestID = request.id
        activeCueContextRequest = request
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

    private func submitSearchDraft() {
        let trimmedDraft = searchDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedDraft.isEmpty else {
            activeCueContextRequest = nil
            tableScrollTargetRow = nil
            cueContextLoadGeneration += 1
            resetCueContextWindow()
            appState.submitSearch(searchDraft)
            return
        }

        activeCueContextRequest = nil
        tableScrollTargetRow = nil
        cueContextLoadGeneration += 1
        resetCueContextWindow()
        let releasedRows = max(
            search.searchResults.count,
            search.searchResultCueGroupIDs.count,
            search.searchResultTotalCount,
            rowStore.snapshot.loadedReferenceCount,
            rowStore.snapshot.totalRowCount
        )
        search.searchQuery = ""
        search.searchResults = []
        search.searchResultCueGroupIDs = []
        search.searchResultTotalCount = 0
        search.searchNavigationSnapshot = nil
        search.hasMoreSearchResults = false
        if search.activeFilterSet.isEffectivelyEmpty {
            clearTableRows(resetScroll: true)
        } else {
            loadAllCueRows(resetScroll: true)
        }
        AppMemoryPressureRelief.relieveAfterLargeResultRelease(estimatedReleasedRows: releasedRows)
    }

    private func updateRows(_ results: [SubtitleSearchResult]) {
        rowStore.updateSearchRows(
            results,
            totalRowCount: results.count,
            tableName: "test-search"
        )
        rowSelection.clamp(rowCount: rowStore.snapshot.totalRowCount)
        refreshSelectedCollageAvailability()
    }

    private func clearTableRows(resetScroll: Bool) {
        let releasedRows = max(rowStore.snapshot.loadedReferenceCount, rowStore.snapshot.totalRowCount)
        resetContinuousRowLoading()
        resetCueContextWindow()
        lastVisibleRows = nil
        rowSelection.reset()
        resetSelectedCollageAvailability()
        rowStore.updateSearchRows([], totalRowCount: 0, tableName: "test-search")
        if resetScroll {
            tableScrollTargetRow = nil
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

    private func hydrateVisibleRows(_ visibleRows: Range<Int>) {
        lastVisibleRows = visibleRows
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
        loadNextContinuousRowsIfNeeded(generation: continuousLoadGeneration)
    }

    private func resetContinuousRowLoading() {
        continuousLoadGeneration += 1
        isLoadingContinuousRows = false
    }

    private func resetCueContextWindow() {
        cueContextLoadedSourceRange = nil
        cueContextTotalRowCount = 0
        cueContextTargetSourceIndex = nil
        isLoadingCueContextRows = false
    }

    private func loadNextContinuousRowsIfNeeded(generation: Int) {
        guard generation == continuousLoadGeneration,
              !isLoadingContinuousRows,
              isFilterOnlyMode,
              activeCueContextRequest == nil
        else {
            return
        }

        let loadedRowCount = rowStore.snapshot.totalRowCount
        let totalRowCount = search.searchResultTotalCount
        guard loadedRowCount < totalRowCount else { return }

        isLoadingContinuousRows = true
        let upperBound = min(totalRowCount, loadedRowCount + Self.continuousPageSize)
        let range = loadedRowCount..<upperBound

        Task { @MainActor in
            guard let page = await appState.loadTableSandboxAllCueRows(range: range),
                  generation == continuousLoadGeneration,
                  search.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  activeCueContextRequest == nil,
                  search.activeFilterSetSignature == appliedFilterSignature
            else {
                if generation == continuousLoadGeneration {
                    isLoadingContinuousRows = false
                }
                return
            }

            let appended = appendContinuousRows(page, expectedStartIndex: loadedRowCount)
            isLoadingContinuousRows = false
            if appended {
                loadNextContinuousRowsIfNeeded(generation: generation)
            }
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
        rowStore.hydrateSearchRows(
            page.results,
            startIndex: expectedStartIndex,
            totalRowCount: expectedStartIndex + page.results.count,
            tableName: "test-search"
        )
        rowSelection.clamp(rowCount: rowStore.snapshot.totalRowCount)
        return rowStore.snapshot.totalRowCount > expectedStartIndex
    }

    private func loadAllCueRows(resetScroll: Bool) {
        activeCueContextRequest = nil
        tableScrollTargetRow = nil
        resetCueContextWindow()
        resetContinuousRowLoading()
        let generation = continuousLoadGeneration
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
                totalRowCount: page.results.count,
                tableName: "test-search"
            )
            rowSelection.clamp(rowCount: rowStore.snapshot.totalRowCount)
            loadNextContinuousRowsIfNeeded(generation: generation)
        }
    }

    private func loadCueContextRows(
        request: CueContextSearchRequest,
        filterSignature: String,
        generation: Int
    ) {
        Task { @MainActor in
            guard let page = await appState.loadCueContextSearchPage(
                request: request,
                range: 0..<TableSandboxHydrationPaging.pageSize,
                anchorsInitialPage: true
            ) else {
                guard generation == cueContextLoadGeneration else { return }
                rowStore.updateSearchRows([], totalRowCount: 0, tableName: "test-search")
                return
            }

            guard generation == cueContextLoadGeneration,
                  search.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  search.activeFilterSetSignature == filterSignature
            else {
                return
            }

            appState.applyTableSandboxAllCueSearchContext(page)
            rowStore.updateSearchRows(
                page.results,
                totalRowCount: page.results.count,
                tableName: "test-search"
            )
            cueContextLoadedSourceRange = page.range
            cueContextTotalRowCount = page.totalRowCount
            let targetSourceIndex = resolvedCueContextTargetSourceIndex(
                in: page,
                targetEntryID: request.targetEntryID
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
            guard let page = await appState.loadCueContextSearchPage(
                request: request,
                range: range,
                anchorsInitialPage: false
            ),
                generation == cueContextLoadGeneration,
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
                let prependedCount = rowStore.prependSearchRows(
                    page.results,
                    tableName: "test-search"
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
                let appendedCount = rowStore.appendSearchRows(
                    page.results,
                    tableName: "test-search"
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
        resetContinuousRowLoading()
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
        SubtitleTableClipboard.copy(text: builder.text)
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
        _ = selectedRows
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

func resolvedCueContextTargetSourceIndex(
    in page: TableSandboxSearchHydrationPage,
    targetEntryID: Int64
) -> Int {
    page.results.first { $0.entryID == targetEntryID }?.searchRank ?? page.range.lowerBound
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
