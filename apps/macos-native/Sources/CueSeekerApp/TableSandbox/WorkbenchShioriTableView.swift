import SwiftUI
import CueSeekerCore

struct WorkbenchShioriTableView: View {
    @EnvironmentObject private var appState: AppCoordinator
    @EnvironmentObject private var shioriStore: ShioriStore
    @EnvironmentObject private var settingsStore: SettingsStore
    @StateObject private var rowStore = TableSandboxRowModelStore()
    @State private var searchDraft = ""
    @State private var visibleColumnIDs = SchemaWorkbenchSearchDefaults.initialVisibleShioriColumnIDs
    @State private var activeFilterSetID: String?
    @State private var filterRules: [SchemaWorkbenchFilterRule] = []
    @State private var tableScrollResetToken = 0
    @State private var rowSelection = TableSandboxRowSelectionState()
    @State private var currentShioris: [Shiori] = []
    @State private var pendingRemoval: Shiori?

    var body: some View {
        SchemaWorkbenchSearchShell(
            searchDraft: $searchDraft,
            visibleColumnIDs: $visibleColumnIDs,
            activeFilterSetID: $activeFilterSetID,
            filterRules: $filterRules,
            filterSets: $settingsStore.searchFilterSets,
            columns: SchemaWorkbenchSearchDefaults.shioriColumns,
            searchPlaceholder: "Search Shiori by title or cues...",
            isRedesign: true,
            tableSummary: tableSummary,
            tableSummaryLeadingInset: tableSummaryLeadingInset,
            tableSummaryAction: selectedAnkiAction,
            filterableColumnIDs: ["display", "cues", "language"],
            onSearchSubmit: {
                rebuildRows(resetScroll: true)
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
                    isRowSelected: { rowSelection.isSelected($0, rowCount: rowStore.snapshot.totalRowCount) },
                    selectionHeaderState: rowSelection.headerState(rowCount: rowStore.snapshot.totalRowCount),
                    onToggleRowSelection: toggleRowSelection,
                    onToggleAllSelection: toggleAllRowSelection,
                    onPlay: openShiori,
                    rowActionMenuStyle: .shiori,
                    onRemoveShiori: requestRemoveShiori,
                    isRedesign: true
                )

                if shioriStore.shioris.isEmpty {
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
            appState.hydrateShiorisAsync()
            rebuildRows(resetScroll: false)
        }
        .onChange(of: shioriStore.shioris) { _ in
            rebuildRows(resetScroll: false)
        }
        .onChange(of: searchDraft) { _ in
            rebuildRows(resetScroll: true)
        }
        .onChange(of: filterRules) { _ in
            rebuildRows(resetScroll: true)
        }
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

    private func rebuildRows(resetScroll: Bool) {
        let sources = shioriRowSources()
        currentShioris = sources.map(\.shiori)
        rowStore.updateShioriRows(sources, tableName: "shiori")
        rowSelection.clamp(rowCount: rowStore.snapshot.totalRowCount)
        if resetScroll {
            rowSelection.reset()
            tableScrollResetToken += 1
        }
    }

    private func shioriRowSources() -> [TableSandboxShioriRowSource] {
        let term = searchDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        let filterSet = filterRules.subtitleSearchFilterSet
        return shioriStore.shioris.compactMap { shiori in
            let displayTitle = SubtitleDisplayTitleResolver.displayTitle(forSubtitlePath: shiori.subtitlePath)
            let languages = appState.languages(for: shiori)
            let cues = tableSandboxDisplayText(content: shiori.content, cueLines: shiori.cueLines)
            guard matchesSearchTerm(term, displayTitle: displayTitle, cues: cues) else {
                return nil
            }
            guard matchesFilterSet(filterSet, displayTitle: displayTitle, cues: cues, languages: languages) else {
                return nil
            }
            return TableSandboxShioriRowSource(
                shiori: shiori,
                displayTitle: displayTitle,
                dateAddedText: WorkbenchShioriDateFormatter.displayText(for: shiori.createdAt),
                languages: languages
            )
        }
    }

    private func matchesSearchTerm(_ term: String, displayTitle: String, cues: String) -> Bool {
        guard !term.isEmpty else {
            return true
        }
        return displayTitle.range(of: term, options: [.caseInsensitive, .diacriticInsensitive]) != nil
            || cues.range(of: term, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }

    private func matchesFilterSet(
        _ filterSet: SubtitleSearchFilterSet,
        displayTitle: String,
        cues: String,
        languages: Set<SubtitleLanguageCode>
    ) -> Bool {
        let tags = SubtitleLanguageWorkbenchTags.tags(for: languages)
        let languageCandidates = Array(Set(languages.map(\.rawValue) + tags.map(\.label)))
        return filterSet.matches(
            display: displayTitle,
            cues: cues,
            languages: languageCandidates
        )
    }

    private func openShiori(_ row: SubtitleTableRow) {
        guard let item = currentShioris.first(where: { Int($0.id) == row.id }) else {
            return
        }
        appState.openShiori(item)
    }

    private func requestRemoveShiori(_ row: SubtitleTableRow) {
        pendingRemoval = currentShioris.first { Int($0.id) == row.id }
    }

    private func confirmRemoveShiori(_ item: Shiori) {
        pendingRemoval = nil
        appState.removeShiori(item)
        rowSelection.clamp(rowCount: rowStore.snapshot.totalRowCount)
    }

    private func exportSelectedRowsToAnki() {
        let selectedRows = rowSelection.selectedRows(rowCount: rowStore.snapshot.totalRowCount)
        let selectedShioris = selectedRows.compactMap { row in
            currentShioris.indices.contains(row) ? currentShioris[row] : nil
        }
        appState.exportShiorisToAnki(selectedShioris)
    }

    private func toggleRowSelection(_ row: Int) {
        rowSelection.toggle(row: row, rowCount: rowStore.snapshot.totalRowCount)
    }

    private func toggleAllRowSelection() {
        rowSelection.toggleAll(rowCount: rowStore.snapshot.totalRowCount)
    }
}

private enum WorkbenchShioriDateFormatter {
    static func displayText(for value: String) -> String {
        let isoFormatter = ISO8601DateFormatter()
        guard let date = isoFormatter.date(from: value) else {
            return value
        }

        let displayFormatter = DateFormatter()
        displayFormatter.locale = Locale(identifier: "en_US_POSIX")
        displayFormatter.dateFormat = "yy-MM-dd HH:mm"
        return displayFormatter.string(from: date)
    }
}
