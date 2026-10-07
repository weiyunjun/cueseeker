import SwiftUI
import CueSeekerCore

private struct WorkbenchExcerptTableTextCopySource {
    let searchText: String
    let resultRowCount: Int
    let resultSnapshotID: UUID
    let resultExcerptIDs: [Int64]
    let dataRevision: Int
}

struct WorkbenchExcerptTableView: View {
    // Observed so the copy below is re-read when the language changes.
    @EnvironmentObject private var localization: AppLocalizationStore

    @EnvironmentObject private var excerptStore: ExcerptStore
    let isTableResponseActive: Bool

    init(isTableResponseActive: Bool = true) {
        self.isTableResponseActive = isTableResponseActive
    }

    var body: some View {
        WorkbenchExcerptTableContent(
            isTableResponseActive: isTableResponseActive,
            rowStore: excerptStore.tableRowStore
        )
    }
}

private struct WorkbenchExcerptTableContent: View {
    let isTableResponseActive: Bool
    @EnvironmentObject private var appState: AppCoordinator
    @EnvironmentObject private var excerptStore: ExcerptStore
    @EnvironmentObject private var settingsStore: SettingsStore
    @EnvironmentObject private var filterDialog: CueFacetFilterDialogCenter
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
    @State private var excerptFacetFilter = CueFacetFilter()
    @State private var selectionOverlayAnchor = MenuAnchorHandle()

    var body: some View {
        let _ = UIInvalidationProbe.count(
            SubtitleTableProbeSurface.excerpt.counterName("surface_body"),
            scope: appState.uiProbeScope
        )
        let textCopySource = tableTextCopySource
        SchemaWorkbenchSearchShell(
            searchDraft: searchInputBinding,
            columns: SchemaWorkbenchSearchDefaults.excerptColumns,
            isRedesign: true,
            summaryContent: coverSummary,
            hostsPageChromeInTable: true,
            tableSummary: tableSummary,
            searchResultCountText: exactSearchResultCountText,
            selectionActions: selectedSummaryActions,
            isSelectionMode: isSelectionMode,
            canEnterSelectionMode: canEnterSelectionMode,
            onToggleSelectionMode: toggleSelectionMode,
            isFilterDialogOpen: isFilterDialogOpen,
            onOpenFilterDialog: openFilterDialog,
            selectionOverlayAnchor: selectionOverlayAnchor
        ) { tableColumns in
            ZStack {
                SubtitleTableView(
                    tableName: "excerpt",
                    probeSurface: .excerpt,
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
                    onVisibleRowsChange: { visibleRows in
                        captureVisibleRows(visibleRows)
                        ExcerptOpenPerformanceTracker.recordVisibleRowsRendered(
                            listID: excerptStore.activeListID,
                            visibleRows: visibleRows
                        )
                    },
                    isSelectionMode: isSelectionMode,
                    isRowSelected: { rowSelection.isSelected($0, rowCount: rowStore.snapshot.totalRowCount) },
                    selectionHeaderState: rowSelection.headerState(
                        rowCount: rowStore.snapshot.totalRowCount,
                        unselectableRows: rowStore.snapshot.unavailableRows
                    ),
                    onToggleRowSelection: toggleRowSelection,
                    onShiftRowSelection: shiftSelectRow,
                    onToggleAllSelection: toggleAllRowSelection,
                    selectionOverlayAnchor: selectionOverlayAnchor,
                    allResultsTextCopyRowCount: textCopySource.resultRowCount,
                    loadRowsForTextCopy: { range in
                        await loadRowsForTextCopy(range: range, source: textCopySource)
                    },
                    onPlay: openExcerpt,
                    rowActionMenuStyle: .excerpt,
                    rowActionDestinations: rowActionDestinations,
                    onMoveExcerpt: moveExcerpt,
                    onDuplicateExcerpt: duplicateExcerpt,
                    onCreateExcerptList: createExcerptList,
                    onRemoveExcerpt: requestRemoveExcerpt,
                    isCueInLibrary: { appState.isCueInLibrary($0) },
                    onToast: { appState.toast.show($0) },
                    isRedesign: true,
                    pageChrome: excerptDetailPageChrome
                )

                if excerptStore.tableHasLoadedInitialPage && excerptStore.tableTotalSavedRowCount == 0 {
                    WorkbenchEmptyHint(message: L("excerpt.table.empty_hint"))
                }
            }
        }
        .onAppear {
            restoreExcerptFacetFilter()
            excerptStore.setTableProjectionResponseActive(allowsTableResponse)
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
        .onChange(of: excerptStore.tableDataRevision) { _ in
            exitSelectionMode()
            reloadRows(resetScroll: false)
        }
        .onChange(of: excerptStore.activeListID) { _ in
            excerptStore.tableViewportAnchor = nil
            viewportAnchorToRestore = nil
            tableScrollTargetRow = nil
            didRestoreViewport = true
            tableScrollResetToken += 1
            // Another list is another interface for the dialog: it closes.
            closeFilterDialog()
            restoreExcerptFacetFilter()
        }
        .onChange(of: canEnterSelectionMode) { canEnter in
            if !canEnter {
                exitSelectionMode()
            }
        }
        .onChange(of: isTableResponseActive) { isActive in
            if !isActive {
                exitSelectionMode()
                // The dialog belongs to this page: switching away closes it.
                closeFilterDialog()
            }
            excerptStore.setTableProjectionResponseActive(isActive)
            if isActive {
                resumeDeferredTableResponse()
            }
        }
        .onDisappear {
            exitSelectionMode()
            closeFilterDialog()
            excerptStore.setTableProjectionResponseActive(false)
            persistSelection()
            excerptStore.tableViewportAnchor = nil
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
        let totalRowCount = max(
            excerptStore.tableResultRowCount,
            rowStore.snapshot.totalRowCount
        )
        return SchemaWorkbenchTableSummary(
            totalRowCount: totalRowCount,
            selectableRowCount: TableSandboxRowSelectionState.selectableCount(
                rowCount: totalRowCount,
                unselectableRows: rowStore.snapshot.unavailableRows
            ),
            selectedRowCount: isSelectionMode
                ? rowSelection.selectedCount(rowCount: rowStore.snapshot.totalRowCount)
                : 0
        )
    }

    private var coverSummary: AnyView? {
        guard let summary = excerptStore.activeListSummary else { return nil }
        return AnyView(
            CoverSummaryCard(
                title: summary.list.name,
                supportingContent: .description(summary.list.description),
                actionKind: summary.resumeExcerpt == nil ? .play : .resume,
                isActionEnabled: excerptStore.activeListHasPlayableContent,
                action: {
                    appState.openExcerptListPlayback(summary)
                }
            ) {
                ExcerptListCoverView(
                    coverPath: summary.list.coverPath,
                    imageVerticalAlignment: .center
                )
            }
        )
    }

    private var excerptDetailPageChrome: SubtitleTablePageChrome? {
        guard let coverSummary else { return nil }
        let pinnedContent = AnyView(
            VStack(spacing: 0) {
                SchemaWorkbenchSearchToolbar(
                    placeholder: L("table.search_placeholder"),
                    searchDraft: searchInputBinding,
                    searchResultCountText: exactSearchResultCountText,
                    isSelectionMode: isSelectionMode,
                    isFilterDialogOpen: isFilterDialogOpen,
                    filterSelectionCount: excerptFacetFilter.selectedOptionCount(
                        emptyDistribution: appState.search.emptySearchFacetDistribution,
                        snapshot: excerptStore.residentFacetSnapshot
                    ),
                    canEnterSelectionMode: canEnterSelectionMode,
                    onFilter: openFilterDialog,
                    onToggleSelectionMode: toggleSelectionMode
                )
                .padding(.bottom, WorkbenchControlMetrics.redesignSpacing2)
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
                WorkbenchControlMetrics.redesignHeight * 2
                + WorkbenchControlMetrics.redesignSpacing2 * 2,
            leadingInset:
                WorkbenchControlMetrics.redesignWorkbenchPageHorizontalPadding,
            trailingInset:
                WorkbenchControlMetrics.redesignWorkbenchPageTrailingPadding,
            bottomInset: 0
        )
    }

    private var hasExactTableResult: Bool {
        let resultRowCount = max(
            excerptStore.tableResultRowCount,
            rowStore.snapshot.totalRowCount
        )
        return excerptStore.tableHasLoadedInitialPage
            && excerptStore.tableResultExcerptIDs?.count == resultRowCount
    }

    private var exactSearchResultCountText: String? {
        guard hasExactTableResult else { return nil }
        return schemaWorkbenchExcerptCountText(tableSummary.totalRowCount)
    }

    private var canEnterSelectionMode: Bool {
        return schemaWorkbenchCanEnterSelectionMode(
            hasExactResultSet: hasExactTableResult,
            selectableRowCount: tableSummary.selectableRowCount
        )
    }

    private var searchInputBinding: Binding<String> {
        Binding(
            get: { excerptStore.tableSearchDraft },
            set: { searchText in
                updateSearchDraft(searchText)
            }
        )
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

    private func containsColumn(_ id: String, in tableColumns: [WorkbenchTableColumn]) -> Bool {
        tableColumns.contains { $0.id == id }
    }

    private func columnTitle(_ id: String, in tableColumns: [WorkbenchTableColumn], fallback: String) -> String {
        tableColumns.first { $0.id == id }?.title ?? fallback
    }

    private var allowsTableResponse: Bool {
        isTableResponseActive
    }

    private var excerptFacetFilterBinding: Binding<CueFacetFilter> {
        Binding(
            get: { excerptFacetFilter },
            set: { newValue in
                guard !isSelectionMode,
                      excerptStore.residentFacetSnapshot != nil,
                      excerptFacetFilter != newValue,
                      let listID = excerptStore.activeListID
                else {
                    return
                }
                excerptFacetFilter = newValue
                settingsStore.setExcerptFacetFilter(
                    newValue,
                    forListID: listID
                )
                applyExcerptFacetFilter(newValue)
            }
        )
    }

    private var isFilterDialogOpen: Bool {
        filterDialog.session?.source == .excerpt
    }

    private var tableTextCopySource: WorkbenchExcerptTableTextCopySource {
        return WorkbenchExcerptTableTextCopySource(
            searchText: excerptStore.tableSearchDraft,
            resultRowCount: max(excerptStore.tableResultRowCount, rowStore.snapshot.totalRowCount),
            resultSnapshotID: excerptStore.tableResultSnapshotID,
            resultExcerptIDs: excerptStore.tableResultExcerptIDs ?? [],
            dataRevision: excerptStore.tableDataRevision
        )
    }

    private func loadRowsForTextCopy(
        range: Range<Int>,
        source: WorkbenchExcerptTableTextCopySource
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
        _ source: WorkbenchExcerptTableTextCopySource
    ) -> Bool {
        allowsTableResponse
            && excerptStore.tableDataRevision == source.dataRevision
            && excerptStore.tableSearchDraft == source.searchText
            && excerptStore.tableResultSnapshotID == source.resultSnapshotID
            && max(excerptStore.tableResultRowCount, rowStore.snapshot.totalRowCount)
                == source.resultRowCount
    }

    private func loadInitialRowsIfNeeded() {
        guard allowsTableResponse else {
            if !excerptStore.tableHasLoadedInitialPage {
                hasDeferredReloadWhileCovered = true
            }
            return
        }
        appState.loadExcerptTableRowsIfNeeded()
    }

    private func updateSearchDraft(_ searchText: String) {
        guard excerptStore.tableSearchDraft != searchText else { return }
        exitSelectionMode()
        rowSelection.reset()
        persistSelection()
        excerptStore.tableViewportAnchor = nil
        viewportAnchorToRestore = nil
        tableScrollTargetRow = nil
        didRestoreViewport = true
        tableScrollResetToken += 1
        appState.updateExcerptSearchQuery(searchText)
    }

    /// The dialog starts from the list's saved selection, and Show hands its
    /// selection back through the same path a changed selection always took.
    private func openFilterDialog() {
        restoreExcerptFacetFilter()
        let filter = excerptStore.activeListID.map {
            settingsStore.excerptFacetFilter(forListID: $0)
        } ?? CueFacetFilter()
        let binding = excerptFacetFilterBinding
        filterDialog.session = CueFacetFilterDialogSession(
            source: .excerpt,
            filter: filter,
            apply: { binding.wrappedValue = $0 }
        )
    }

    private func closeFilterDialog() {
        guard isFilterDialogOpen else { return }
        filterDialog.session = nil
    }

    private func restoreExcerptFacetFilter() {
        guard let listID = excerptStore.activeListID else {
            excerptFacetFilter = CueFacetFilter()
            return
        }
        let filter = settingsStore.excerptFacetFilter(forListID: listID)
        excerptFacetFilter = filter
        appState.updateExcerptFacetFilter(filter)
    }

    private func applyExcerptFacetFilter(_ filter: CueFacetFilter) {
        UIInvalidationProbe.mark(
            "ACTION UI.ExcerptFacetFilter.changed",
            scope: appState.uiProbeScope
        )
        exitSelectionMode()
        rowSelection.reset()
        persistSelection()
        excerptStore.tableViewportAnchor = nil
        viewportAnchorToRestore = nil
        tableScrollTargetRow = nil
        didRestoreViewport = true
        tableScrollResetToken += 1
        appState.updateExcerptFacetFilter(filter)
    }

    private func reloadRows(resetScroll: Bool) {
        guard allowsTableResponse else {
            hasDeferredReloadWhileCovered = true
            return
        }
        rowSelection.reset()
        persistSelection()
        if resetScroll {
            excerptStore.tableViewportAnchor = nil
            viewportAnchorToRestore = nil
            tableScrollTargetRow = nil
            didRestoreViewport = true
            tableScrollResetToken += 1
        }
        appState.reloadExcerptTableRows()
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

    private func openExcerpt(_ row: SubtitleTableRow) {
        guard let item = rowStore.snapshot.excerpt(entryID: row.id) else {
            return
        }
        guard item.isValid,
              let navigationScopeIDs = excerptStore.playbackTableResultExcerptIDs
        else {
            return
        }
        let playlistScope = PlaybackPlaylistExcerptScope.table(
            PlaybackPlaylistExcerptTableContext(
                runID: excerptStore.tableResultSnapshotID,
                searchText: excerptStore.tableSearchDraft,
                totalCount: navigationScopeIDs.count
            )
        )
        appState.openExcerpt(
            item,
            navigationScopeIDs: navigationScopeIDs,
            playlistScope: playlistScope,
            playlistSelectedOrdinal: navigationScopeIDs.firstIndex(
                of: Int64(row.id)
            ),
            displayTitle: row.displayTitle
        )
    }

    private func requestRemoveExcerpt(_ row: SubtitleTableRow) {
        guard let item = rowStore.snapshot.excerpt(entryID: row.id) else {
            return
        }
        appState.confirmation.session = WorkbenchConfirmationSession(
            title: L("excerpt.remove.title"),
            message: L("excerpt.remove.message"),
            destructiveTitle: L("common.remove"),
            cancelTitle: L("common.cancel"),
            onDestructive: {
                confirmRemoveExcerpt(item)
            },
            onCancel: {
                appState.confirmation.session = nil
            }
        )
    }

    private var rowActionDestinations: [SubtitleTableRowActionDestination] {
        excerptStore.listOverview.lists.compactMap { summary in
            guard summary.id != excerptStore.activeListID else {
                return nil
            }
            return SubtitleTableRowActionDestination(
                id: summary.id,
                title: summary.list.name
            )
        }
    }

    private func isExcerptValid(_ item: Excerpt, row: SubtitleTableRow) -> Bool {
        guard item.isValid, !row.cueState.isUnavailable else {
            return false
        }
        return appState.excerptIDsInLibrary(among: [item.id]).contains(item.id)
    }

    private func moveExcerpt(_ row: SubtitleTableRow, toListID listID: Int64) {
        guard let item = rowStore.snapshot.excerpt(entryID: row.id) else {
            return
        }
        guard isExcerptValid(item, row: row) else {
            appState.toast.show(TableToastRequest.cueNotInLibrary)
            return
        }
        appState.moveExcerpt(
            item,
            toListID: listID,
            listName: excerptStore.listName(id: listID)
        )
    }

    private func createExcerptList(
        _ row: SubtitleTableRow,
        for action: SubtitleTableRowAction
    ) {
        guard let item = rowStore.snapshot.excerpt(entryID: row.id) else {
            return
        }
        guard isExcerptValid(item, row: row) else {
            appState.toast.show(TableToastRequest.cueNotInLibrary)
            return
        }
        appState.beginCreatingExcerptList(
            pendingTransfer: ExcerptListEditorPendingTransfer(
                action: action,
                target: .excerpt(item)
            )
        )
    }

    private func duplicateExcerpt(_ row: SubtitleTableRow, toListID listID: Int64) {
        guard let item = rowStore.snapshot.excerpt(entryID: row.id) else {
            return
        }
        guard isExcerptValid(item, row: row) else {
            appState.toast.show(TableToastRequest.cueNotInLibrary)
            return
        }
        appState.duplicateExcerpt(
            item,
            toListID: listID,
            listName: excerptStore.listName(id: listID)
        )
    }

    private func confirmRemoveExcerpt(_ item: Excerpt) {
        appState.confirmation.session = nil
        guard appState.removeExcerpt(item, reloadPresentation: false) else {
            return
        }
    }

    private func exportSelectedRowsToAnki() {
        let selectedRows = rowSelection.selectedRows(rowCount: rowStore.snapshot.totalRowCount)
        guard !selectedRows.isEmpty else {
            return
        }

        Task { @MainActor in
            let selection = await selectedExcerpts(for: selectedRows)
            let excerptIDs = selection.map(\.excerpt.id)
            let validExcerptIDs = appState.excerptIDsInLibrary(among: excerptIDs)
            let validSelection = selection.filter { pair in
                pair.excerpt.isValid && !pair.row.cueState.isUnavailable && validExcerptIDs.contains(pair.excerpt.id)
            }
            guard !validSelection.isEmpty else {
                appState.toast.show(TableToastRequest.cueNotInLibrary(count: selectedRows.count))
                return
            }
            appState.exportExcerptsToAnki(validSelection)
        }
    }

    private func copySelectedRowsAsTable() {
        let rowCount = rowStore.snapshot.totalRowCount
        let selection = rowSelection
        guard selection.selectedCount(rowCount: rowCount) > 0 else {
            return
        }

        let columns = SubtitleTableClipboard.columns(
            from: SchemaWorkbenchSearchDefaults.excerptColumns
        )
        let selectedRows = selection.selectedRows(rowCount: rowCount)
        guard !selectedRows.isEmpty else {
            return
        }

        var builder = SubtitleTableClipboard.TSVBuilder(columns: columns)
        builder.append(rows: selectedRows.compactMap { rowStore.snapshot.row(at: $0) })
        SubtitleTableClipboard.copy(representations: builder.representations)
        appState.toast.show(TableToastRequest.copyTable)
    }

    private func copySelectedRowsAsDeepLinks() {
        let selectedRows = rowSelection.selectedRows(
            rowCount: rowStore.snapshot.totalRowCount
        )
        guard !selectedRows.isEmpty else { return }
        let rows = selectedRows.compactMap { rowStore.snapshot.row(at: $0) }
        guard rows.count == selectedRows.count else { return }

        let excerptIDs = rows.map { Int64($0.id) }
        let validExcerptIDs = appState.excerptIDsInLibrary(among: excerptIDs)
        let validRows = rows.filter { row in
            guard !row.cueState.isUnavailable,
                  let excerpt = rowStore.snapshot.excerpt(entryID: row.id),
                  excerpt.isValid,
                  validExcerptIDs.contains(Int64(row.id))
            else {
                return false
            }
            return true
        }

        guard !validRows.isEmpty else {
            appState.toast.show(TableToastRequest.cueNotInLibrary(count: selectedRows.count))
            return
        }

        SubtitleTableClipboard.copyDeepLinks(rows: validRows)
        appState.toast.show(TableToastRequest.copyDeepLinks)
    }

    private func selectedExcerpts(
        for selectedRows: [Int]
    ) async -> [(excerpt: Excerpt, row: SubtitleTableRow)] {
        await hydrateRowsForExport(selectedRows)
        return selectedRows.compactMap { row in
            guard let tableRow = rowStore.snapshot.row(at: row),
                  let excerpt = rowStore.snapshot.excerpt(entryID: tableRow.id)
            else {
                return nil
            }
            return (excerpt, tableRow)
        }
    }

    private func hydrateRowsForExport(_ selectedRows: [Int]) async {
        _ = selectedRows
    }

    private func toggleRowSelection(_ row: Int) {
        rowSelection.toggle(
            row: row,
            rowCount: rowStore.snapshot.totalRowCount,
            unselectableRows: rowStore.snapshot.unavailableRows
        )
        let count = rowSelection.selectedCount(rowCount: rowStore.snapshot.totalRowCount)
        if !isSelectionMode, count > 0 {
            isSelectionMode = true
        } else if isSelectionMode, count == 0 {
            isSelectionMode = false
        }
        persistSelection()
    }

    private func shiftSelectRow(_ row: Int) {
        rowSelection.shiftClick(
            row: row,
            rowCount: rowStore.snapshot.totalRowCount,
            unselectableRows: rowStore.snapshot.unavailableRows
        )
        let count = rowSelection.selectedCount(rowCount: rowStore.snapshot.totalRowCount)
        if !isSelectionMode, count > 0 {
            isSelectionMode = true
        } else if isSelectionMode, count == 0 {
            isSelectionMode = false
        }
        persistSelection()
    }

    private func toggleAllRowSelection() {
        rowSelection.toggleAll(
            rowCount: rowStore.snapshot.totalRowCount,
            unselectableRows: rowStore.snapshot.unavailableRows
        )
        let count = rowSelection.selectedCount(rowCount: rowStore.snapshot.totalRowCount)
        if !isSelectionMode, count > 0 {
            isSelectionMode = true
        } else if isSelectionMode, count == 0 {
            isSelectionMode = false
        }
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
        excerptStore.tableViewportAnchor = TableViewportAnchor(
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
        viewportAnchorToRestore = excerptStore.tableViewportAnchor
        didRestoreViewport = viewportAnchorToRestore == nil
    }

    private func persistSelection() {
        excerptStore.tableSelectionState = rowSelection
        excerptStore.tableSelectionEntryIDs = rowStore.snapshot.orderedEntryIDs
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
        guard entryIDs == excerptStore.tableSelectionEntryIDs else { return }
        rowSelection = excerptStore.tableSelectionState
        rowSelection.clamp(rowCount: rowStore.snapshot.totalRowCount)
    }
}
