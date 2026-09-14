import Combine
import Foundation
import CueSeekerCore

@MainActor
final class ExcerptStore: ObservableObject {
    private let uiProbeScope: String?
    private var cueContentChangesCancellable: AnyCancellable?
    private var isTableProjectionResponseActive = true
    private var pendingCueContentChange: CueContentStoreChange?
    @Published private(set) var listOverview = ExcerptListOverview(
        lists: [],
        uniqueCueCount: 0
    )
    @Published private(set) var recentListSummaries: [ExcerptListSummary] = []
    @Published private(set) var hasLoadedListOverview = false
    @Published private(set) var activeListID: Int64?
    /// The list the last successful `Save to Excerpt` went to, loaded from
    /// settings at launch. Only the destination menu's opening highlight reads
    /// it; a list that is gone by then is cleared rather than tracked here.
    @Published private(set) var recentSaveListID: Int64?
    @Published var listEditorSession: ExcerptListEditorSession?
    @Published var selectedExcerpt: Excerpt?
    @Published var tableSearchDraft = ""
    @Published var tableTotalSavedRowCount = 0
    @Published var tableResultRowCount = 0
    @Published var tableHasLoadedInitialPage = false
    @Published var tableDataRevision = 0
    @Published private(set) var residentFacetSnapshot: CueFacetSnapshot?
    private(set) var tableFacetFilter = CueFacetFilter()
    private(set) var tableResultSnapshotID = UUID()
    private(set) var tableResultExcerptIDs: [Int64]?
    private(set) var residentRelations: [ExcerptRelation] = []
    private(set) var residentExcerptsByID: [Int64: Excerpt] = [:]
    private(set) var residentDataRevision: Int?
    private(set) var residentListID: Int64?
    private(set) var tableRowsNeedReload = false
    var tableViewportAnchor: TableViewportAnchor?
    var tableSelectionState = TableSandboxRowSelectionState()
    var tableSelectionEntryIDs: [Int] = []

    var playbackTableResultExcerptIDs: [Int64]? {
        tableResultExcerptIDs?.filter { excerptID in
            if let resident = residentExcerptsByID[excerptID] {
                return resident.isValid
            }
            guard let entryID = Int(exactly: excerptID) else {
                return false
            }
            return tableRowStore.snapshot.excerpt(entryID: entryID)?.isValid == true
        }
    }

    var activeListSummary: ExcerptListSummary? {
        guard let activeListID,
              let overview = listOverview.lists.first(where: {
                  $0.id == activeListID
              })
        else {
            return nil
        }
        guard let recent = recentListSummaries.first(where: {
            $0.id == activeListID
        }) else {
            return overview
        }
        return ExcerptListSummary(
            list: overview.list,
            cueCount: overview.cueCount,
            resumeExcerpt: recent.resumeExcerpt,
            resumePosition: recent.resumePosition
        )
    }

    var activeListHasPlayableContent: Bool {
        guard let activeListID,
              residentListID == activeListID,
              residentDataRevision == tableDataRevision
        else {
            return activeListSummary?.resumeExcerpt?.isValid == true
        }
        return residentExcerptsByID.values.contains(where: \.isValid)
    }

    let tableRowStore = TableSandboxRowModelStore()

    init(
        cueContentStore: CueContentStore? = nil,
        uiProbeScope: String? = nil
    ) {
        self.uiProbeScope = uiProbeScope
        cueContentChangesCancellable = cueContentStore?.changes.sink {
            [weak self] change in
            self?.receiveCueContentChange(change)
        }
    }

    func setTableProjectionResponseActive(_ isActive: Bool) {
        guard isTableProjectionResponseActive != isActive else {
            return
        }
        isTableProjectionResponseActive = isActive
        guard isActive, let pendingCueContentChange else {
            return
        }
        self.pendingCueContentChange = nil
        refreshReferencedCueContent(pendingCueContentChange)
    }

    func installListOverview(_ overview: ExcerptListOverview) {
        guard listOverview != overview || !hasLoadedListOverview else {
            return
        }
        listOverview = overview
        if !hasLoadedListOverview {
            hasLoadedListOverview = true
        }
        // A deleted list's id is handed to the next list created, so the
        // remembered save target is dropped the moment its list leaves the
        // overview rather than when a menu next asks for it.
        if let recentSaveListID,
           !overview.lists.contains(where: { $0.id == recentSaveListID }) {
            self.recentSaveListID = nil
        }
    }

    func clearListOverviewForReload() {
        hasLoadedListOverview = false
    }

    func installRecentListSummaries(_ summaries: [ExcerptListSummary]) {
        guard recentListSummaries != summaries else {
            return
        }
        recentListSummaries = summaries
    }

    @discardableResult
    func upsertListSummary(_ list: ExcerptList) -> Bool {
        guard hasLoadedListOverview else {
            return false
        }
        var lists = listOverview.lists
        if let index = lists.firstIndex(where: { $0.id == list.id }) {
            let current = lists[index]
            let replacement = ExcerptListSummary(
                list: list,
                cueCount: current.cueCount
            )
            guard current != replacement else {
                return true
            }
            lists[index] = replacement
            if let recentIndex = recentListSummaries.firstIndex(
                where: { $0.id == list.id }
            ) {
                let recent = recentListSummaries[recentIndex]
                var updatedRecent = recentListSummaries
                updatedRecent[recentIndex] = ExcerptListSummary(
                    list: list,
                    cueCount: recent.cueCount,
                    resumeExcerpt: recent.resumeExcerpt,
                    resumePosition: recent.resumePosition
                )
                installRecentListSummaries(updatedRecent)
            }
        } else {
            lists.append(ExcerptListSummary(list: list, cueCount: 0))
            lists.sort {
                if $0.list.createdAt != $1.list.createdAt {
                    return $0.list.createdAt < $1.list.createdAt
                }
                return $0.id < $1.id
            }
        }
        installListOverview(ExcerptListOverview(
            lists: lists,
            uniqueCueCount: listOverview.uniqueCueCount
        ))
        return true
    }

    @discardableResult
    func removeListSummary(id: Int64, uniqueCueCount: Int) -> Bool {
        guard hasLoadedListOverview,
              listOverview.lists.contains(where: { $0.id == id })
        else {
            return false
        }
        installListOverview(ExcerptListOverview(
            lists: listOverview.lists.filter { $0.id != id },
            uniqueCueCount: uniqueCueCount
        ))
        installRecentListSummaries(
            recentListSummaries.filter { $0.id != id }
        )
        return true
    }

    @discardableResult
    func adjustListCueCounts(
        _ deltas: [Int64: Int],
        uniqueCueCount: Int? = nil
    ) -> Bool {
        guard hasLoadedListOverview,
              deltas.keys.allSatisfy({ listID in
                  listOverview.lists.contains(where: { $0.id == listID })
              })
        else {
            return false
        }
        let lists = listOverview.lists.map { summary in
            guard let delta = deltas[summary.id], delta != 0 else {
                return summary
            }
            return ExcerptListSummary(
                list: summary.list,
                cueCount: max(0, summary.cueCount + delta)
            )
        }
        installListOverview(ExcerptListOverview(
            lists: lists,
            uniqueCueCount: uniqueCueCount ?? listOverview.uniqueCueCount
        ))
        return true
    }

    func setRecentSaveListID(_ listID: Int64?) {
        guard recentSaveListID != listID else {
            return
        }
        recentSaveListID = listID
    }

    func setActiveListID(_ listID: Int64?) {
        guard activeListID != listID else {
            return
        }
        activeListID = listID
        invalidateTableRows()
    }

    private func receiveCueContentChange(_ change: CueContentStoreChange) {
        guard isTableProjectionResponseActive else {
            pendingCueContentChange = pendingCueContentChange?.merging(change)
                ?? change
            return
        }
        refreshReferencedCueContent(change)
    }

    private func refreshReferencedCueContent(_ change: CueContentStoreChange) {
        tableRowStore.refreshReferencedCueContent(
            change,
            tableName: "excerpt",
            probeSurface: .excerpt,
            probeScope: uiProbeScope
        )
    }

    func clearTableRowsForReload(tableName: String = "excerpt") {
        tableRowsNeedReload = false
        tableHasLoadedInitialPage = false
        tableTotalSavedRowCount = 0
        tableResultRowCount = 0
        tableResultSnapshotID = UUID()
        tableResultExcerptIDs = nil
        tableRowStore.updateExcerptRows(
            [],
            tableName: tableName,
            probeSurface: .excerpt,
            probeScope: uiProbeScope
        )
    }

    func markTableRowsLoaded(totalSavedRowCount: Int) {
        tableRowsNeedReload = false
        tableTotalSavedRowCount = totalSavedRowCount
        tableHasLoadedInitialPage = true
    }

    func installTableResultExcerptIDs(_ excerptIDs: [Int64]) {
        tableResultExcerptIDs = excerptIDs
        tableResultRowCount = excerptIDs.count
    }

    @discardableResult
    func updateTableSearchDraft(_ searchText: String) -> Bool {
        let normalizedSearchText = SearchInputNormalizer.singleLine(searchText)
        guard tableSearchDraft != normalizedSearchText else { return false }
        tableSearchDraft = normalizedSearchText
        return true
    }

    @discardableResult
    func updateTableFacetFilter(_ filter: CueFacetFilter) -> Bool {
        guard tableFacetFilter != filter else { return false }
        tableFacetFilter = filter
        return true
    }

    func beginTableResultProjection() {
        tableResultSnapshotID = UUID()
        tableResultExcerptIDs = nil
    }

    func installResidentSnapshot(
        _ snapshot: ExcerptResidentSnapshot,
        listID: Int64 = ExcerptListIdentity.defaultListID,
        dataRevision: Int
    ) {
        residentRelations = snapshot.relations
        residentExcerptsByID = Dictionary(
            uniqueKeysWithValues: snapshot.resolvedExcerpts.map { ($0.id, $0) }
        )
        residentFacetSnapshot = snapshot.facetSnapshot
        residentListID = listID
        residentDataRevision = dataRevision
    }

    func residentFacetProjection(
        using filter: CueFacetFilter
    ) -> (excerptIDs: [Int64], distribution: CueFacetDistribution) {
        guard let residentFacetSnapshot else { return ([], .zero) }
        var availableFilter = filter
        availableFilter.languages.formIntersection(
            residentFacetSnapshot.distribution.languageCounts.keys
        )
        let projection = residentFacetSnapshot.filteredCueIDs(
            using: availableFilter,
            limit: residentFacetSnapshot.cueIDs.count
        )
        let excerptIDByCueID = Dictionary(
            uniqueKeysWithValues: residentRelations.map { ($0.cueID, $0.id) }
        )
        return (
            projection.cueIDs.compactMap { excerptIDByCueID[$0] },
            projection.distribution
        )
    }

    func clearResidentSnapshot() {
        residentRelations = []
        residentExcerptsByID = [:]
        residentFacetSnapshot = nil
        residentListID = nil
        residentDataRevision = nil
    }

    func removeExcerptFromCurrentProjection(id: Int64) {
        guard residentDataRevision != nil,
              residentListID == activeListID,
              residentRelations.contains(where: { $0.id == id })
        else {
            return
        }
        let removedCueIDs = Set(
            residentRelations.lazy.filter { $0.id == id }.map(\.cueID)
        )
        residentRelations.removeAll { $0.id == id }
        residentExcerptsByID[id] = nil
        residentFacetSnapshot = residentFacetSnapshot?.removingCueIDs(
            removedCueIDs
        )
        tableTotalSavedRowCount = residentRelations.count
        if let tableResultExcerptIDs {
            let remainingIDs = tableResultExcerptIDs.filter { $0 != id }
            self.tableResultExcerptIDs = remainingIDs
            tableResultRowCount = remainingIDs.count
            tableResultSnapshotID = UUID()
            tableSelectionState.reset()
            tableSelectionEntryIDs = remainingIDs.map(Int.init)
        }
        tableRowStore.removeResidentExcerpt(
            id: id,
            tableName: "excerpt",
            probeSurface: .excerpt,
            probeScope: uiProbeScope
        )
    }

    func invalidateTableRows(tableName: String = "excerpt") {
        clearResidentSnapshot()
        clearTableRowsForReload(tableName: tableName)
        tableDataRevision += 1
    }

    func markTableRowsStale() {
        tableRowsNeedReload = true
        residentFacetSnapshot = nil
        tableDataRevision += 1
    }
}
