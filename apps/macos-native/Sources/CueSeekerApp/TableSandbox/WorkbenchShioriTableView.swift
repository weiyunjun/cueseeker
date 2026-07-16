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
    @State private var rowSelection = TableSandboxRowSelectionState()
    @State private var pendingRemoval: Shiori?
    @State private var pendingTagDeletion: PendingShioriTagDeletion?
    @State private var canExportSelectedRowsAsCollage = false
    @State private var hasDeferredReloadWhileCovered = false

    var body: some View {
        let _ = UIInvalidationProbe.count(
            SubtitleTableProbeSurface.shiori.counterName("surface_body"),
            scope: appState.uiProbeScope
        )
        let textCopySource = tableTextCopySource
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
            tableSummaryAction: selectedSummaryActions,
            filterableColumnIDs: ["display", "cues"],
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
                    showsSpeakerColumn: false,
                    showsTagsColumn: isColumnVisible("tags", in: visibleColumns),
                    showsCueGroup: appliedShowCueGroup
                        ?? (allowsTableResponse && settingsStore.showCueGroup),
                    scrollResetToken: tableScrollResetToken,
                    suspendsMenuOutsideClickDismiss: pendingTagDeletion != nil,
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
        .task {
            loadInitialRowsIfNeeded()
        }
        .onChange(of: shioriStore.tableDataRevision) { _ in
            reloadRows(resetScroll: false)
        }
        .onChange(of: shioriStore.tableFilterRules) { _ in
            reloadRows(resetScroll: true)
        }
        .onChange(of: isTableResponseActive) { isActive in
            if isActive {
                resumeDeferredTableResponse()
            }
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
            selectedRowCount: rowSelection.selectedCount(rowCount: rowStore.snapshot.totalRowCount)
        )
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
        guard let page = await appState.loadTableSandboxShioriRows(
            range: range,
            searchText: source.searchText,
            filterSet: source.filterSet,
            resultShioriIDs: source.resultShioriIDs
        ),
            textCopySourceStillMatches(source),
            page.range == range,
            page.rows.count == range.count,
            page.totalRowCount == source.resultRowCount
        else {
            return nil
        }
        return page.rows.map { tableSandboxShioriRow(for: $0) }
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
        let trimmedDraft = shioriStore.tableSearchDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        shioriStore.tableSubmittedSearchText = trimmedDraft
        reloadRows(resetScroll: true)
    }

    private func reloadRows(resetScroll: Bool) {
        guard allowsTableResponse else {
            hasDeferredReloadWhileCovered = true
            return
        }
        rowSelection.reset()
        resetSelectedCollageAvailability()
        if resetScroll {
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
        guard let navigationScopeIDs = shioriStore.tableResultShioriIDs,
              navigationScopeIDs.count == shioriStore.tableResultRowCount
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
        refreshSelectedCollageAvailability()
    }

    private func toggleAllRowSelection() {
        rowSelection.toggleAll(rowCount: rowStore.snapshot.totalRowCount)
        refreshSelectedCollageAvailability()
    }
}

private struct PendingShioriTagDeletion {
    let tag: ShioriTag
    var onConfirm: () -> Void
    var onCancel: () -> Void
}
