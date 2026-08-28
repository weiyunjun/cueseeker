import SwiftUI
import CueSeekerCore

private struct WorkbenchShioriTableTextCopySource {
    let searchText: String
    let resultRowCount: Int
    let resultSnapshotID: UUID
    let resultShioriIDs: [Int64]
    let dataRevision: Int
}

struct WorkbenchShioriTableView: View {
    /// The filter menu starts closed on every entry to the page.
    static let defaultFilterMenuOpen = false
    // Observed so the copy below is re-read when the language changes.
    @EnvironmentObject private var localization: AppLocalizationStore

    @EnvironmentObject private var shioriStore: ShioriStore
    let isTableResponseActive: Bool

    init(isTableResponseActive: Bool = true) {
        self.isTableResponseActive = isTableResponseActive
    }

    var body: some View {
        WorkbenchShioriTableContent(
            isTableResponseActive: isTableResponseActive,
            rowStore: shioriStore.tableRowStore
        )
    }
}

private struct WorkbenchShioriTableContent: View {
    let isTableResponseActive: Bool
    @EnvironmentObject private var appState: AppCoordinator
    @EnvironmentObject private var shioriStore: ShioriStore
    @EnvironmentObject private var settingsStore: SettingsStore
    @ObservedObject var rowStore: TableSandboxRowModelStore
    @State private var appliedShowCueGroup: Bool?
    @State private var tableScrollResetToken = 0
    @State private var tableScrollTargetRow: Int?
    @State private var didRestoreViewport = false
    @State private var hasPreparedViewportRestoration = false
    @State private var viewportAnchorToRestore: TableViewportAnchor?
    @State private var rowSelection = TableSandboxRowSelectionState()
    @State private var isSelectionMode = false
    @State private var hasDeferredReloadWhileCovered = false
    @State private var isFilterMenuOpen =
        WorkbenchShioriTableView.defaultFilterMenuOpen
    @State private var shioriFacetFilter = CueFacetFilter()
    /// The filter button lives in the table's pinned chrome, a separate
    /// hosting hierarchy; this handle is how the shell's menu host finds it.
    @State private var filterMenuAnchor = MenuAnchorHandle()

    var body: some View {
        let _ = UIInvalidationProbe.count(
            SubtitleTableProbeSurface.shiori.counterName("surface_body"),
            scope: appState.uiProbeScope
        )
        let textCopySource = tableTextCopySource
        SchemaWorkbenchSearchShell(
            searchDraft: searchInputBinding,
            columns: SchemaWorkbenchSearchDefaults.shioriColumns,
            isRedesign: true,
            summaryContent: coverSummary,
            hostsPageChromeInTable: true,
            tableSummary: tableSummary,
            searchResultCountText: exactSearchResultCountText,
            selectionActions: selectedSummaryActions,
            isSelectionMode: isSelectionMode,
            canEnterSelectionMode: canEnterSelectionMode,
            onToggleSelectionMode: toggleSelectionMode,
            filterMenu: CueFacetFilterMenuModel(
                distribution:
                    shioriStore.tableFacetDistribution
                        ?? shioriStore.residentFacetSnapshot?.distribution,
                availableLanguages: availableFacetLanguages,
                isCalculating: shioriStore.residentFacetSnapshot == nil,
                filter: shioriFacetFilterBinding
            ),
            isFilterMenuOpen: isFilterMenuOpen,
            onToggleFilterMenu: toggleFilterMenu,
            onDismissFilterMenu: {
                isFilterMenuOpen = false
            },
            externalFilterMenuAnchor: filterMenuAnchor
        ) { tableColumns in
            ZStack {
                SubtitleTableView(
                    tableName: "shiori",
                    probeSurface: .shiori,
                    probeScope: appState.uiProbeScope,
                    rowCount: rowStore.snapshot.totalRowCount,
                    rowProvider: { rowStore.snapshot.row(at: $0) },
                    rowsVersion: rowStore.snapshot.version,
                    rowsUpdate: rowStore.snapshot.update,
                    dateAddedHeader: columnTitle("dateAdded", in: tableColumns, fallback: L("table.column.date_added")),
                    displayTitleHeader: columnTitle("display", in: tableColumns, fallback: L("table.column.display_title")),
                    timeHeader: columnTitle("time", in: tableColumns, fallback: L("table.column.time_range")),
                    cuesHeader: columnTitle("cues", in: tableColumns, fallback: L("table.column.cues")),
                    languageHeader: columnTitle("language", in: tableColumns, fallback: L("table.column.language")),
                    columnOrder: tableColumns.map(\.id),
                    showsDateAddedColumn: containsColumn("dateAdded", in: tableColumns),
                    showsDisplayTitleColumn: containsColumn("display", in: tableColumns),
                    showsTimeColumn: containsColumn("time", in: tableColumns),
                    showsLanguageColumn: containsColumn("language", in: tableColumns),
                    showsCueGroup: appliedShowCueGroup
                        ?? (allowsTableResponse && settingsStore.showCueGroup),
                    scrollResetToken: tableScrollResetToken,
                    scrollTargetRow: tableScrollTargetRow,
                    onVisibleRowsChange: captureVisibleRows,
                    isSelectionMode: isSelectionMode,
                    isRowSelected: { rowSelection.isSelected($0, rowCount: rowStore.snapshot.totalRowCount) },
                    selectionHeaderState: rowSelection.headerState(rowCount: rowStore.snapshot.totalRowCount),
                    onToggleRowSelection: toggleRowSelection,
                    onToggleAllSelection: toggleAllRowSelection,
                    allResultsTextCopyRowCount: textCopySource.resultRowCount,
                    loadRowsForTextCopy: { range in
                        await loadRowsForTextCopy(range: range, source: textCopySource)
                    },
                    onPlay: openShiori,
                    rowActionMenuStyle: .shiori,
                    rowActionDestinations: rowActionDestinations,
                    onMoveShiori: moveShiori,
                    onDuplicateShiori: duplicateShiori,
                    onCreateShioriList: createShioriList,
                    onRemoveShiori: requestRemoveShiori,
                    isRedesign: true,
                    pageChrome: shioriDetailPageChrome
                )

                if shioriStore.tableHasLoadedInitialPage && shioriStore.tableTotalSavedRowCount == 0 {
                    WorkbenchEmptyHint(message: L("shiori.table.empty_hint"))
                }
            }
        }
        .onAppear {
            restoreShioriFacetFilter()
            shioriStore.setTableProjectionResponseActive(allowsTableResponse)
            prepareViewportRestoration()
            restoreSelectionIfPossible()
            restoreViewportIfPossible()
        }
        .task {
            loadInitialRowsIfNeeded()
        }
        .onChange(of: rowStore.snapshot.version) { _ in
            restoreSelectionIfPossible()
            restoreViewportIfPossible()
        }
        .onChange(of: shioriStore.tableDataRevision) { _ in
            exitSelectionMode()
            reloadRows(resetScroll: false)
        }
        .onChange(of: shioriStore.activeListID) { _ in
            shioriStore.tableViewportAnchor = nil
            viewportAnchorToRestore = nil
            tableScrollTargetRow = nil
            didRestoreViewport = true
            tableScrollResetToken += 1
            // Another list is another interface for the menu: it closes.
            isFilterMenuOpen = false
            restoreShioriFacetFilter()
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
            shioriStore.setTableProjectionResponseActive(isActive)
            if isActive {
                resumeDeferredTableResponse()
            }
        }
        .onDisappear {
            exitSelectionMode()
            isFilterMenuOpen = false
            shioriStore.setTableProjectionResponseActive(false)
            persistSelection()
            shioriStore.tableViewportAnchor = nil
        }
        .background(
            CueGroupPresentationGate(
                store: settingsStore.cueGroupPresentation,
                isActive: allowsTableResponse,
                appliedValue: $appliedShowCueGroup
            )
        )
    }

    private var tableSummary: SchemaWorkbenchTableSummary {
        SchemaWorkbenchTableSummary(
            totalRowCount: max(
                shioriStore.tableResultRowCount,
                rowStore.snapshot.totalRowCount
            ),
            selectedRowCount: isSelectionMode
                ? rowSelection.selectedCount(rowCount: rowStore.snapshot.totalRowCount)
                : 0
        )
    }

    private var coverSummary: AnyView? {
        guard let summary = shioriStore.activeListSummary else { return nil }
        return AnyView(
            CoverSummaryCard(
                title: summary.list.name,
                supportingContent: .description(summary.list.description),
                actionKind: summary.resumeShiori == nil ? .play : .resume,
                isActionEnabled: shioriStore.activeListHasPlayableContent,
                action: {
                    appState.openShioriListPlayback(summary)
                }
            ) {
                ShioriListCoverView(
                    coverPath: summary.list.coverPath,
                    imageVerticalAlignment: .center
                )
            }
        )
    }

    private var shioriDetailPageChrome: SubtitleTablePageChrome? {
        guard let coverSummary else { return nil }
        let pinnedContent = AnyView(
            VStack(spacing: 0) {
                SchemaWorkbenchSearchToolbar(
                    placeholder: L("table.search_placeholder"),
                    searchDraft: searchInputBinding,
                    searchResultCountText: exactSearchResultCountText,
                    isSelectionMode: isSelectionMode,
                    isFilterMenuOpen: isFilterMenuOpen,
                    canEnterSelectionMode: canEnterSelectionMode,
                    filterMenuAnchor: filterMenuAnchor,
                    onFilter: toggleFilterMenu,
                    onToggleSelectionMode: toggleSelectionMode
                )
                .padding(.bottom, WorkbenchControlMetrics.redesignSpacing3)
            }
            .background(WorkbenchRedesignColors.bgSurface)
        )

        return SubtitleTablePageChrome(
            scrollableHeader: AnyView(
                coverSummary
                    .padding(
                        .top,
                        WorkbenchControlMetrics.redesignCoverSummaryDetailTopPadding
                    )
                    .padding(
                        .bottom,
                        WorkbenchControlMetrics.redesignCoverSummaryToolbarGap
                    )
            ),
            pinnedHeader: pinnedContent,
            scrollableHeaderHeight: { contentWidth in
                WorkbenchControlMetrics.redesignCoverSummaryDetailTopPadding
                    + CoverSummaryCardLayout.height(forCardWidth: contentWidth)
                    + WorkbenchControlMetrics.redesignCoverSummaryToolbarGap
            },
            pinnedHeaderHeight:
                WorkbenchControlMetrics.redesignHeight
                + WorkbenchControlMetrics.redesignSpacing3,
            leadingInset:
                WorkbenchControlMetrics.redesignWorkbenchPageHorizontalPadding,
            trailingInset:
                WorkbenchControlMetrics.redesignWorkbenchPageTrailingPadding,
            bottomInset: SchemaWorkbenchStyle.pageBottomPadding
        )
    }

    private var hasExactTableResult: Bool {
        let resultRowCount = max(
            shioriStore.tableResultRowCount,
            rowStore.snapshot.totalRowCount
        )
        return shioriStore.tableHasLoadedInitialPage
            && shioriStore.tableResultShioriIDs?.count == resultRowCount
    }

    private var exactSearchResultCountText: String? {
        guard hasExactTableResult else { return nil }
        return schemaWorkbenchResultCountText(tableSummary.totalRowCount)
    }

    private var canEnterSelectionMode: Bool {
        return schemaWorkbenchCanEnterSelectionMode(
            hasExactResultSet: hasExactTableResult
        )
    }

    private var searchInputBinding: Binding<String> {
        Binding(
            get: { shioriStore.tableSearchDraft },
            set: { searchText in
                updateSearchDraft(searchText)
            }
        )
    }

    private var selectedSummaryActions: AnyView? {
        guard isSelectionMode, tableSummary.selectedRowCount > 0 else {
            return nil
        }
        return AnyView(
            HStack(spacing: WorkbenchControlMetrics.redesignSpacing3) {
                WorkbenchButton(
                    title: L("table.toolbar.anki"),
                    systemImage: "square.and.arrow.up",
                    isRedesign: true,
                    action: exportSelectedRowsToAnki
                )
                WorkbenchButton(
                    title: L("table.toolbar.copy_deep_links"),
                    systemImage: "doc.on.doc",
                    isRedesign: true,
                    action: copySelectedRowsAsDeepLinks
                )
                WorkbenchButton(
                    title: L("table.toolbar.copy_table"),
                    systemImage: "doc.on.doc",
                    isRedesign: true,
                    action: copySelectedRowsAsTable
                )
            }
        )
    }

    private func containsColumn(_ id: String, in tableColumns: [WorkbenchTableColumn]) -> Bool {
        tableColumns.contains { $0.id == id }
    }

    private func columnTitle(_ id: String, in tableColumns: [WorkbenchTableColumn], fallback: String) -> String {
        tableColumns.first { $0.id == id }?.title ?? fallback
    }

    private var allowsTableResponse: Bool {
        isTableResponseActive
    }

    private var shioriFacetFilterBinding: Binding<CueFacetFilter> {
        Binding(
            get: { shioriFacetFilter },
            set: { newValue in
                guard !isSelectionMode,
                      shioriStore.residentFacetSnapshot != nil,
                      shioriFacetFilter != newValue,
                      let listID = shioriStore.activeListID
                else {
                    return
                }
                shioriFacetFilter = newValue
                settingsStore.setShioriFacetFilter(
                    newValue,
                    forListID: listID
                )
                applyShioriFacetFilter(newValue)
            }
        )
    }

    private var availableFacetLanguages: [SubtitleLanguageCode] {
        var available = Set<SubtitleLanguageCode>()
        if let snapshot = shioriStore.residentFacetSnapshot {
            available.formUnion(snapshot.distribution.languageCounts.keys)
        }
        return SubtitleLanguageCode.allCases.filter(available.contains)
    }

    private var tableTextCopySource: WorkbenchShioriTableTextCopySource {
        return WorkbenchShioriTableTextCopySource(
            searchText: shioriStore.tableSearchDraft,
            resultRowCount: max(shioriStore.tableResultRowCount, rowStore.snapshot.totalRowCount),
            resultSnapshotID: shioriStore.tableResultSnapshotID,
            resultShioriIDs: shioriStore.tableResultShioriIDs ?? [],
            dataRevision: shioriStore.tableDataRevision
        )
    }

    private func loadRowsForTextCopy(
        range: Range<Int>,
        source: WorkbenchShioriTableTextCopySource
    ) async -> [SubtitleTableRow]? {
        guard range.lowerBound >= 0,
              range.upperBound <= source.resultRowCount,
              range.lowerBound < range.upperBound,
              textCopySourceStillMatches(source)
        else {
            return nil
        }
        let rows = range.compactMap { rowStore.snapshot.row(at: $0) }
        guard textCopySourceStillMatches(source), rows.count == range.count else {
            return nil
        }
        return rows
    }

    private func textCopySourceStillMatches(
        _ source: WorkbenchShioriTableTextCopySource
    ) -> Bool {
        allowsTableResponse
            && shioriStore.tableDataRevision == source.dataRevision
            && shioriStore.tableSearchDraft == source.searchText
            && shioriStore.tableResultSnapshotID == source.resultSnapshotID
            && max(shioriStore.tableResultRowCount, rowStore.snapshot.totalRowCount)
                == source.resultRowCount
    }

    private func loadInitialRowsIfNeeded() {
        guard allowsTableResponse else {
            if !shioriStore.tableHasLoadedInitialPage {
                hasDeferredReloadWhileCovered = true
            }
            return
        }
        appState.loadShioriTableRowsIfNeeded()
    }

    private func updateSearchDraft(_ searchText: String) {
        guard shioriStore.tableSearchDraft != searchText else { return }
        exitSelectionMode()
        rowSelection.reset()
        persistSelection()
        shioriStore.tableViewportAnchor = nil
        viewportAnchorToRestore = nil
        tableScrollTargetRow = nil
        didRestoreViewport = true
        tableScrollResetToken += 1
        appState.updateShioriSearchQuery(searchText)
    }

    private func toggleFilterMenu() {
        if !isFilterMenuOpen {
            restoreShioriFacetFilter()
        }
        isFilterMenuOpen.toggle()
    }

    private func restoreShioriFacetFilter() {
        guard let listID = shioriStore.activeListID else {
            shioriFacetFilter = CueFacetFilter()
            return
        }
        let filter = settingsStore.shioriFacetFilter(forListID: listID)
        shioriFacetFilter = filter
        appState.updateShioriFacetFilter(filter)
    }

    private func applyShioriFacetFilter(_ filter: CueFacetFilter) {
        UIInvalidationProbe.mark(
            "ACTION UI.ShioriFacetFilter.changed",
            scope: appState.uiProbeScope
        )
        exitSelectionMode()
        rowSelection.reset()
        persistSelection()
        shioriStore.tableViewportAnchor = nil
        viewportAnchorToRestore = nil
        tableScrollTargetRow = nil
        didRestoreViewport = true
        tableScrollResetToken += 1
        appState.updateShioriFacetFilter(filter)
    }

    private func reloadRows(resetScroll: Bool) {
        guard allowsTableResponse else {
            hasDeferredReloadWhileCovered = true
            return
        }
        rowSelection.reset()
        persistSelection()
        if resetScroll {
            shioriStore.tableViewportAnchor = nil
            viewportAnchorToRestore = nil
            tableScrollTargetRow = nil
            didRestoreViewport = true
            tableScrollResetToken += 1
        }
        appState.reloadShioriTableRows()
    }

    private func resumeDeferredTableResponse() {
        guard allowsTableResponse else { return }
        if hasDeferredReloadWhileCovered {
            hasDeferredReloadWhileCovered = false
            reloadRows(resetScroll: false)
        } else {
            loadInitialRowsIfNeeded()
        }
    }

    private func openShiori(_ row: SubtitleTableRow) {
        guard let item = rowStore.snapshot.shiori(entryID: row.id) else {
            return
        }
        guard item.isValid,
              let navigationScopeIDs = shioriStore.playbackTableResultShioriIDs
        else {
            return
        }
        let playlistScope = PlaybackPlaylistShioriScope.table(
            PlaybackPlaylistShioriTableContext(
                runID: shioriStore.tableResultSnapshotID,
                searchText: shioriStore.tableSearchDraft,
                totalCount: navigationScopeIDs.count
            )
        )
        appState.openShiori(
            item,
            navigationScopeIDs: navigationScopeIDs,
            playlistScope: playlistScope,
            playlistSelectedOrdinal: navigationScopeIDs.firstIndex(
                of: Int64(row.id)
            ),
            displayTitle: row.displayTitle
        )
    }

    private func requestRemoveShiori(_ row: SubtitleTableRow) {
        guard let item = rowStore.snapshot.shiori(entryID: row.id) else {
            return
        }
        appState.confirmation.session = WorkbenchConfirmationSession(
            title: L("shiori.remove.title"),
            message: L("shiori.remove.message"),
            destructiveTitle: L("common.remove"),
            cancelTitle: L("common.cancel"),
            onDestructive: {
                confirmRemoveShiori(item)
            },
            onCancel: {
                appState.confirmation.session = nil
            }
        )
    }

    private var rowActionDestinations: [SubtitleTableRowActionDestination] {
        shioriStore.listOverview.lists.compactMap { summary in
            guard summary.id != shioriStore.activeListID else {
                return nil
            }
            return SubtitleTableRowActionDestination(
                id: summary.id,
                title: summary.list.name
            )
        }
    }

    private func moveShiori(_ row: SubtitleTableRow, toListID listID: Int64) {
        guard let item = rowStore.snapshot.shiori(entryID: row.id) else {
            return
        }
        appState.moveShiori(item, toListID: listID)
    }

    private func createShioriList(
        _ row: SubtitleTableRow,
        for action: SubtitleTableRowAction
    ) {
        guard let item = rowStore.snapshot.shiori(entryID: row.id) else {
            return
        }
        appState.beginCreatingShioriList(
            pendingTransfer: ShioriListEditorPendingTransfer(
                action: action,
                shiori: item
            )
        )
    }

    private func duplicateShiori(_ row: SubtitleTableRow, toListID listID: Int64) {
        guard let item = rowStore.snapshot.shiori(entryID: row.id) else {
            return
        }
        appState.duplicateShiori(item, toListID: listID)
    }

    private func confirmRemoveShiori(_ item: Shiori) {
        appState.confirmation.session = nil
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

    private func copySelectedRowsAsTable() {
        let rowCount = rowStore.snapshot.totalRowCount
        let selection = rowSelection
        guard selection.selectedCount(rowCount: rowCount) > 0 else {
            return
        }

        let columns = SubtitleTableClipboard.columns(
            from: SchemaWorkbenchSearchDefaults.shioriColumns
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
            rowCount: rowStore.snapshot.totalRowCount
        )
        guard !selectedRows.isEmpty else { return }
        let rows = selectedRows.compactMap { rowStore.snapshot.row(at: $0) }
        guard rows.count == selectedRows.count else { return }
        SubtitleTableClipboard.copyDeepLinks(rows: rows)
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
        _ = selectedRows
    }

    private func toggleRowSelection(_ row: Int) {
        rowSelection.toggle(row: row, rowCount: rowStore.snapshot.totalRowCount)
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
        shioriStore.tableViewportAnchor = TableViewportAnchor(
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
        viewportAnchorToRestore = shioriStore.tableViewportAnchor
        didRestoreViewport = viewportAnchorToRestore == nil
    }

    private func persistSelection() {
        shioriStore.tableSelectionState = rowSelection
        shioriStore.tableSelectionEntryIDs = rowStore.snapshot.orderedEntryIDs
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
        guard isSelectionMode || rowSelection.selectedCount(rowCount: rowStore.snapshot.totalRowCount) > 0 else {
            return
        }
        isSelectionMode = false
        rowSelection.reset()
        persistSelection()
    }

    private func restoreSelectionIfPossible() {
        let entryIDs = rowStore.snapshot.orderedEntryIDs
        guard entryIDs == shioriStore.tableSelectionEntryIDs else { return }
        rowSelection = shioriStore.tableSelectionState
        rowSelection.clamp(rowCount: rowStore.snapshot.totalRowCount)
    }
}
