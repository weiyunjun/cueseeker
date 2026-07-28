import SwiftUI
import CueSeekerCore
import CueSeekerPlayback

private struct WorkbenchShioriTableTextCopySource {
    let searchText: String
    let filterSet: SubtitleSearchFilterSet
    let filterSignature: String
    let resultRowCount: Int
    let resultSnapshotID: UUID
    let resultShioriIDs: [Int64]
    let dataRevision: Int
}

struct WorkbenchShioriTableView: View {
    static let defaultFacetPanelVisibility = false

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
    @State private var pendingRemoval: Shiori?
    @State private var pendingTagDeletion: PendingShioriTagDeletion?
    @State private var canExportSelectedRowsAsCollage = false
    @State private var hasDeferredReloadWhileCovered = false
    @State private var isFacetPanelVisible =
        WorkbenchShioriTableView.defaultFacetPanelVisibility
    @State private var shioriFacetFilter = CueFacetFilter()

    var body: some View {
        let _ = UIInvalidationProbe.count(
            SubtitleTableProbeSurface.shiori.counterName("surface_body"),
            scope: appState.uiProbeScope
        )
        let textCopySource = tableTextCopySource
        SchemaWorkbenchSearchShell(
            searchDraft: $shioriStore.tableSearchDraft,
            visibleColumnIDs: $shioriStore.tableVisibleColumnIDs,
            filterRules: $shioriStore.tableFilterRules,
            columns: SchemaWorkbenchSearchDefaults.shioriColumns,
            searchPlaceholder: "Search Shiori by title or cues...",
            isRedesign: true,
            tableSummary: tableSummary,
            selectionActions: selectedSummaryActions,
            isSelectionMode: isSelectionMode,
            canEnterSelectionMode: canEnterSelectionMode,
            onToggleSelectionMode: toggleSelectionMode,
            filterPanel: AnyView(
                CueFacetFilterPanel(
                    distribution:
                        shioriStore.residentFacetSnapshot?.distribution,
                    availableLanguages: availableFacetLanguages,
                    isCalculating: shioriStore.residentFacetSnapshot == nil,
                    isDisabled: isSelectionMode,
                    filter: shioriFacetFilterBinding
                )
            ),
            isFilterPanelVisible: isFacetPanelVisible,
            onToggleFilterPanel: {
                if !isFacetPanelVisible {
                    restoreShioriFacetFilter()
                }
                isFacetPanelVisible.toggle()
            },
            onSearchSubmit: {
                submitSearchDraft()
            }
        ) { visibleColumns in
            ZStack {
                SubtitleTableView(
                    tableName: "shiori",
                    probeSurface: .shiori,
                    probeScope: appState.uiProbeScope,
                    rowCount: rowStore.snapshot.totalRowCount,
                    rowProvider: { rowStore.snapshot.row(at: $0) },
                    rowsVersion: rowStore.snapshot.version,
                    rowsUpdate: rowStore.snapshot.update,
                    dateAddedHeader: columnTitle("dateAdded", in: visibleColumns, fallback: "Date Added"),
                    displayTitleHeader: columnTitle("display", in: visibleColumns, fallback: "Display Title"),
                    timeHeader: columnTitle("time", in: visibleColumns, fallback: "Time Range"),
                    cuesHeader: columnTitle("cues", in: visibleColumns, fallback: "Cues"),
                    languageHeader: columnTitle("language", in: visibleColumns, fallback: "Language"),
                    tagsHeader: columnTitle("tags", in: visibleColumns, fallback: "Tags"),
                    columnOrder: visibleColumns.map(\.id),
                    showsDateAddedColumn: isColumnVisible("dateAdded", in: visibleColumns),
                    showsDisplayTitleColumn: isColumnVisible("display", in: visibleColumns),
                    showsTimeColumn: isColumnVisible("time", in: visibleColumns),
                    showsLanguageColumn: isColumnVisible("language", in: visibleColumns),
                    showsTagsColumn: isColumnVisible("tags", in: visibleColumns),
                    showsCueGroup: appliedShowCueGroup
                        ?? (allowsTableResponse && settingsStore.showCueGroup),
                    scrollResetToken: tableScrollResetToken,
                    scrollTargetRow: tableScrollTargetRow,
                    suspendsMenuOutsideClickDismiss: pendingTagDeletion != nil,
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
                    onShowContext: showContext,
                    rowActionMenuStyle: .shiori,
                    rowActionDestinations: rowActionDestinations,
                    onMoveShiori: moveShiori,
                    onDuplicateShiori: duplicateShiori,
                    onRemoveShiori: requestRemoveShiori,
                    makeTagsPopover: { row, dismiss, requestLayout in
                        AnyView(
                            ShioriTagPopoverView(
                                row: row,
                                appState: appState,
                                rowStore: rowStore,
                                onDismiss: dismiss,
                                onRequestLayout: requestLayout,
                                onRequestDeleteConfirmation: { tag, onConfirm, onCancel in
                                    pendingTagDeletion = PendingShioriTagDeletion(
                                        tag: tag,
                                        onConfirm: onConfirm,
                                        onCancel: onCancel
                                    )
                                }
                            )
                            .id(row.id)
                        )
                    },
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
                    title: "Remove Shiori",
                    message: "This cue will be removed from your Shiori. The original subtitle and video files will not be deleted.",
                    destructiveTitle: "Remove",
                    cancelTitle: "Cancel",
                    onDestructive: {
                        confirmRemoveShiori(pendingRemoval)
                    },
                    onCancel: {
                        self.pendingRemoval = nil
                    }
                )
                .zIndex(20)
            }

            if let pendingTagDeletion {
                WorkbenchConfirmationDialog(
                    title: "Delete Tag",
                    message: "Are you sure you want to delete this tag? This will remove the tag from all cues. This action cannot be undone.",
                    destructiveTitle: "Delete",
                    cancelTitle: "Cancel",
                    onDestructive: {
                        let onConfirm = pendingTagDeletion.onConfirm
                        self.pendingTagDeletion = nil
                        onConfirm()
                    },
                    onCancel: {
                        let onCancel = pendingTagDeletion.onCancel
                        self.pendingTagDeletion = nil
                        onCancel()
                    }
                )
                .zIndex(30)
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
        .onChange(of: shioriStore.tableFilterRules) { _ in
            exitSelectionMode()
            reloadRows(resetScroll: true)
        }
        .onChange(of: shioriStore.activeListID) { _ in
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
            }
            shioriStore.setTableProjectionResponseActive(isActive)
            if isActive {
                resumeDeferredTableResponse()
            }
        }
        .onDisappear {
            exitSelectionMode()
            shioriStore.setTableProjectionResponseActive(false)
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

    private var canEnterSelectionMode: Bool {
        let resultRowCount = max(
            shioriStore.tableResultRowCount,
            rowStore.snapshot.totalRowCount
        )
        return schemaWorkbenchCanEnterSelectionMode(
            hasExactResultSet: shioriStore.tableHasLoadedInitialPage
                && shioriStore.tableResultShioriIDs?.count == resultRowCount
        )
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
        SchemaWorkbenchSearchDefaults.shioriColumns.filter {
            shioriStore.tableVisibleColumnIDs.contains($0.id) ||
                SchemaWorkbenchColumnVisibilityMenu.isLocked($0.id)
        }
    }

    private func isColumnVisible(_ id: String, in visibleColumns: [WorkbenchTableColumn]) -> Bool {
        visibleColumns.contains { $0.id == id }
    }

    private func columnTitle(_ id: String, in visibleColumns: [WorkbenchTableColumn], fallback: String) -> String {
        visibleColumns.first { $0.id == id }?.title ?? fallback
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
        let filterSet = shioriStore.tableFilterRules.subtitleSearchFilterSet
        return WorkbenchShioriTableTextCopySource(
            searchText: shioriStore.tableSubmittedSearchText,
            filterSet: filterSet,
            filterSignature: filterSet.cacheSignature,
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
            && shioriStore.tableSubmittedSearchText == source.searchText
            && shioriStore.tableFilterRules.subtitleSearchFilterSet.cacheSignature
                == source.filterSignature
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

    private func submitSearchDraft() {
        exitSelectionMode()
        let trimmedDraft = shioriStore.tableSearchDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        shioriStore.tableSubmittedSearchText = trimmedDraft
        reloadRows(resetScroll: true)
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
        resetSelectedCollageAvailability()
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
        resetSelectedCollageAvailability()
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
                searchText: shioriStore.tableSubmittedSearchText,
                filterSet: shioriStore.tableFilterRules.subtitleSearchFilterSet,
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

    private func showContext(_ row: SubtitleTableRow) {
        guard let item = rowStore.snapshot.shiori(entryID: row.id) else {
            return
        }
        appState.openShioriContext(item, displayTitle: row.displayTitle)
    }

    private func requestRemoveShiori(_ row: SubtitleTableRow) {
        pendingRemoval = rowStore.snapshot.shiori(entryID: row.id)
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

    private func duplicateShiori(_ row: SubtitleTableRow, toListID listID: Int64) {
        guard let item = rowStore.snapshot.shiori(entryID: row.id) else {
            return
        }
        appState.duplicateShiori(item, toListID: listID)
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

    private func exportSelectedRowsAsScreenshots() {
        let selectedRows = rowSelection.selectedRows(rowCount: rowStore.snapshot.totalRowCount)
        guard !selectedRows.isEmpty else {
            return
        }

        Task { @MainActor in
            let sources = await selectedShioriScreenshotSources(for: selectedRows)
            let items = sources.map {
                appState.subtitleScreenshotItem(for: $0.shiori, displayTitle: $0.displayTitle)
            }
            appState.exportSubtitleScreenshots(items)
        }
    }

    private func exportSelectedRowsAsCollage() {
        let selectedRows = rowSelection.selectedRows(rowCount: rowStore.snapshot.totalRowCount)
        guard !selectedRows.isEmpty else {
            return
        }

        Task { @MainActor in
            let sources = await selectedShioriScreenshotSources(for: selectedRows)
            let items = sources.map {
                appState.subtitleScreenshotItem(for: $0.shiori, displayTitle: $0.displayTitle)
            }
            guard SubtitleScreenshotExporter.canExportCollage(items) else {
                refreshSelectedCollageAvailability()
                return
            }
            appState.exportSubtitleCollage(items)
        }
    }

    private func copySelectedRowsAsTable() {
        let rowCount = rowStore.snapshot.totalRowCount
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

    private func selectedShioris(for selectedRows: [Int]) async -> [Shiori] {
        await hydrateRowsForExport(selectedRows)
        return selectedRows.compactMap { row in
            guard let tableRow = rowStore.snapshot.row(at: row) else {
                return nil
            }
            return rowStore.snapshot.shiori(entryID: tableRow.id)
        }
    }

    private func selectedShioriScreenshotSources(for selectedRows: [Int]) async -> [(shiori: Shiori, displayTitle: String)] {
        await hydrateRowsForExport(selectedRows)
        return selectedShioriScreenshotSourcesFromSnapshot(for: selectedRows)
    }

    private func selectedShioriScreenshotSourcesFromSnapshot(for selectedRows: [Int]) -> [(shiori: Shiori, displayTitle: String)] {
        selectedRows.compactMap { row in
            guard let tableRow = rowStore.snapshot.row(at: row),
                  let shiori = rowStore.snapshot.shiori(entryID: tableRow.id)
            else {
                return nil
            }
            return (shiori: shiori, displayTitle: tableRow.displayTitle)
        }
    }

    private func refreshSelectedCollageAvailability() {
        let selectedRows = rowSelection.selectedRows(rowCount: rowStore.snapshot.totalRowCount)
        guard !selectedRows.isEmpty, selectedRows.count <= 50 else {
            setCanExportSelectedRowsAsCollage(false)
            return
        }

        let items = selectedShioriScreenshotSourcesFromSnapshot(for: selectedRows)
            .map { appState.subtitleScreenshotItem(for: $0.shiori, displayTitle: $0.displayTitle) }
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
        resetSelectedCollageAvailability()
        isSelectionMode = true
    }

    private func exitSelectionMode() {
        guard isSelectionMode || rowSelection.selectedCount(rowCount: rowStore.snapshot.totalRowCount) > 0 else {
            return
        }
        isSelectionMode = false
        rowSelection.reset()
        persistSelection()
        resetSelectedCollageAvailability()
    }

    private func restoreSelectionIfPossible() {
        let entryIDs = rowStore.snapshot.orderedEntryIDs
        guard entryIDs == shioriStore.tableSelectionEntryIDs else { return }
        rowSelection = shioriStore.tableSelectionState
        rowSelection.clamp(rowCount: rowStore.snapshot.totalRowCount)
    }
}

private struct PendingShioriTagDeletion {
    let tag: ShioriTag
    var onConfirm: () -> Void
    var onCancel: () -> Void
}
