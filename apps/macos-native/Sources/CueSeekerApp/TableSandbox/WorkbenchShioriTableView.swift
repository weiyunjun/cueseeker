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
    let reloadGeneration: Int
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
    @State private var lastVisibleRows: Range<Int>?
    @State private var reloadGeneration = 0
    @State private var continuousLoadGeneration = 0
    @State private var isLoadingContinuousRows = false
    @State private var initialRowsTask: Task<Void, Never>?
    @State private var continuousRowsTask: Task<Void, Never>?
    @State private var pendingRemoval: Shiori?
    @State private var pendingTagDeletion: PendingShioriTagDeletion?
    @State private var canExportSelectedRowsAsCollage = false
    @State private var hasDeferredReloadWhileCovered = false

    private static let continuousPageSize = 1_000

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
                    onVisibleRowsChange: hydrateVisibleRows,
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
            if !isActive {
                resetContinuousRowLoading()
            } else {
                resumeDeferredTableResponse()
            }
        }
        .onDisappear { resetContinuousRowLoading() }
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
            reloadGeneration: reloadGeneration,
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
            && reloadGeneration == source.reloadGeneration
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
        guard !shioriStore.tableHasLoadedInitialPage else {
            loadNextContinuousRowsIfNeeded(generation: continuousLoadGeneration)
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
        guard allowsTableResponse else {
            hasDeferredReloadWhileCovered = true
            resetContinuousRowLoading()
            return
        }
        reloadGeneration += 1
        let generation = reloadGeneration
        resetContinuousRowLoading()
        let continuousGeneration = continuousLoadGeneration
        lastVisibleRows = nil
        rowSelection.reset()
        resetSelectedCollageAvailability()
        shioriStore.clearTableRowsForReload()
        if resetScroll {
            tableScrollResetToken += 1
        }

        initialRowsTask = Task { @MainActor in
            guard allowsTableResponse, !Task.isCancelled else {
                return
            }
            guard let page = await loadRows(range: 0..<TableSandboxHydrationPaging.pageSize) else {
                guard generation == reloadGeneration else { return }
                initialRowsTask = nil
                if !Task.isCancelled {
                    shioriStore.markTableRowsLoaded(totalSavedRowCount: 0)
                }
                return
            }

            guard allowsTableResponse,
                  generation == reloadGeneration,
                  !Task.isCancelled
            else {
                return
            }
            applyHydrationPage(page)
            shioriStore.markTableRowsLoaded(totalSavedRowCount: page.totalSavedRowCount)
            initialRowsTask = nil
            loadNextContinuousRowsIfNeeded(generation: continuousGeneration)
        }
    }

    private func hydrateVisibleRows(_ visibleRows: Range<Int>) {
        guard allowsTableResponse else { return }
        lastVisibleRows = visibleRows
        guard visibleRows.upperBound >= rowStore.snapshot.totalRowCount - TableSandboxHydrationPaging.pageSize else {
            return
        }
        loadNextContinuousRowsIfNeeded(generation: continuousLoadGeneration)
    }

    private func loadRows(range: Range<Int>) async -> TableSandboxShioriHydrationPage? {
        UIInvalidationProbe.count(
            SubtitleTableProbeSurface.shiori.counterName("row_hydration_requested"),
            scope: appState.uiProbeScope
        )
        return await appState.loadTableSandboxShioriRows(
            range: range,
            searchText: shioriStore.tableSubmittedSearchText,
            filterSet: shioriStore.tableFilterRules.subtitleSearchFilterSet,
            resultShioriIDs: shioriStore.tableResultShioriIDs
        )
    }

    private func resetContinuousRowLoading() {
        continuousLoadGeneration += 1
        initialRowsTask?.cancel()
        initialRowsTask = nil
        continuousRowsTask?.cancel()
        continuousRowsTask = nil
        isLoadingContinuousRows = false
    }

    private func loadNextContinuousRowsIfNeeded(generation: Int) {
        guard generation == continuousLoadGeneration,
              allowsTableResponse,
              !isLoadingContinuousRows
        else {
            return
        }

        let loadedRowCount = rowStore.snapshot.totalRowCount
        guard loadedRowCount < shioriStore.tableResultRowCount else { return }

        isLoadingContinuousRows = true
        let upperBound = min(shioriStore.tableResultRowCount, loadedRowCount + Self.continuousPageSize)
        let range = loadedRowCount..<upperBound

        continuousRowsTask = Task { @MainActor in
            guard allowsTableResponse, !Task.isCancelled else {
                return
            }
            guard let page = await loadRows(range: range),
                  allowsTableResponse,
                  generation == continuousLoadGeneration,
                  !Task.isCancelled
            else {
                if generation == continuousLoadGeneration {
                    isLoadingContinuousRows = false
                    continuousRowsTask = nil
                }
                return
            }

            let appended = appendContinuousRows(page, expectedStartIndex: loadedRowCount)
            isLoadingContinuousRows = false
            continuousRowsTask = nil
            if appended {
                loadNextContinuousRowsIfNeeded(generation: generation)
            }
        }
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

    @discardableResult
    private func appendContinuousRows(
        _ page: TableSandboxShioriHydrationPage,
        expectedStartIndex: Int
    ) -> Bool {
        guard page.range.lowerBound == expectedStartIndex, !page.rows.isEmpty else {
            return false
        }
        applyHydrationPage(page)
        return rowStore.snapshot.totalRowCount > expectedStartIndex
    }

    private func applyHydrationPage(_ page: TableSandboxShioriHydrationPage) {
        shioriStore.tableTotalSavedRowCount = page.totalSavedRowCount
        shioriStore.installTableResultShioriIDs(page.resultShioriIDs)
        rowStore.hydrateShioriRows(
            page.rows,
            startIndex: page.range.lowerBound,
            totalRowCount: page.range.lowerBound + page.rows.count,
            tableName: "shiori",
            probeSurface: .shiori,
            probeScope: appState.uiProbeScope
        )
        rowSelection.clamp(rowCount: rowStore.snapshot.totalRowCount)
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
