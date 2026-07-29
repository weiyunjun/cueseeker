import Combine
import Foundation
import CueSeekerCore

@MainActor
final class ShioriStore: ObservableObject {
    private let uiProbeScope: String?
    private var cueContentChangesCancellable: AnyCancellable?
    private var isTableProjectionResponseActive = true
    private var pendingCueContentChange: CueContentStoreChange?
    @Published private(set) var listOverview = ShioriListOverview(
        lists: [],
        uniqueCueCount: 0
    )
    @Published private(set) var recentListSummaries: [ShioriListSummary] = []
    @Published private(set) var hasLoadedListOverview = false
    @Published private(set) var activeListID: Int64?
    @Published var listEditorSession: ShioriListEditorSession?
    @Published var selectedShiori: Shiori?
    @Published var tableSearchDraft = ""
    @Published var tableVisibleColumnIDs = SchemaWorkbenchSearchDefaults.initialVisibleShioriColumnIDs
    @Published var tableTotalSavedRowCount = 0
    @Published var tableResultRowCount = 0
    @Published var tableHasLoadedInitialPage = false
    @Published var tableDataRevision = 0
    @Published private(set) var residentFacetSnapshot: CueFacetSnapshot?
    @Published private(set) var tableFacetDistribution: CueFacetDistribution?
    private(set) var tableFacetFilter = CueFacetFilter()
    private(set) var tableResultSnapshotID = UUID()
    private(set) var tableResultShioriIDs: [Int64]?
    private(set) var residentRelations: [ShioriRelation] = []
    private(set) var residentShiorisByID: [Int64: Shiori] = [:]
    private(set) var residentDataRevision: Int?
    private(set) var residentListID: Int64?
    private(set) var tableRowsNeedReload = false
    var tableViewportAnchor: TableViewportAnchor?
    var tableSelectionState = TableSandboxRowSelectionState()
    var tableSelectionEntryIDs: [Int] = []

    var playbackTableResultShioriIDs: [Int64]? {
        tableResultShioriIDs?.filter { shioriID in
            if let resident = residentShiorisByID[shioriID] {
                return resident.isValid
            }
            guard let entryID = Int(exactly: shioriID) else {
                return false
            }
            return tableRowStore.snapshot.shiori(entryID: entryID)?.isValid == true
        }
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

    func installListOverview(_ overview: ShioriListOverview) {
        guard listOverview != overview || !hasLoadedListOverview else {
            return
        }
        listOverview = overview
        if !hasLoadedListOverview {
            hasLoadedListOverview = true
        }
    }

    func clearListOverviewForReload() {
        hasLoadedListOverview = false
    }

    func installRecentListSummaries(_ summaries: [ShioriListSummary]) {
        guard recentListSummaries != summaries else {
            return
        }
        recentListSummaries = summaries
    }

    @discardableResult
    func upsertListSummary(_ list: ShioriList) -> Bool {
        guard hasLoadedListOverview else {
            return false
        }
        var lists = listOverview.lists
        if let index = lists.firstIndex(where: { $0.id == list.id }) {
            let current = lists[index]
            let replacement = ShioriListSummary(
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
                updatedRecent[recentIndex] = ShioriListSummary(
                    list: list,
                    cueCount: recent.cueCount,
                    resumeShiori: recent.resumeShiori,
                    resumePosition: recent.resumePosition
                )
                installRecentListSummaries(updatedRecent)
            }
        } else {
            lists.append(ShioriListSummary(list: list, cueCount: 0))
            lists.sort {
                if $0.list.createdAt != $1.list.createdAt {
                    return $0.list.createdAt > $1.list.createdAt
                }
                return $0.id > $1.id
            }
        }
        installListOverview(ShioriListOverview(
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
        installListOverview(ShioriListOverview(
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
            return ShioriListSummary(
                list: summary.list,
                cueCount: max(0, summary.cueCount + delta)
            )
        }
        installListOverview(ShioriListOverview(
            lists: lists,
            uniqueCueCount: uniqueCueCount ?? listOverview.uniqueCueCount
        ))
        return true
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
            tableName: "shiori",
            probeSurface: .shiori,
            probeScope: uiProbeScope
        )
    }

    func clearTableRowsForReload(tableName: String = "shiori") {
        tableRowsNeedReload = false
        tableHasLoadedInitialPage = false
        tableTotalSavedRowCount = 0
        tableResultRowCount = 0
        tableResultSnapshotID = UUID()
        tableResultShioriIDs = nil
        tableRowStore.updateShioriRows(
            [],
            tableName: tableName,
            probeSurface: .shiori,
            probeScope: uiProbeScope
        )
    }

    func markTableRowsLoaded(totalSavedRowCount: Int) {
        tableRowsNeedReload = false
        tableTotalSavedRowCount = totalSavedRowCount
        tableHasLoadedInitialPage = true
    }

    func installTableResultShioriIDs(_ shioriIDs: [Int64]) {
        tableResultShioriIDs = shioriIDs
        tableResultRowCount = shioriIDs.count
    }

    func installTableFacetDistribution(_ distribution: CueFacetDistribution) {
        tableFacetDistribution = distribution
    }

    @discardableResult
    func updateTableSearchDraft(_ searchText: String) -> Bool {
        guard tableSearchDraft != searchText else { return false }
        tableSearchDraft = searchText
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
        tableResultShioriIDs = nil
    }

    func installResidentSnapshot(
        _ snapshot: ShioriResidentSnapshot,
        listID: Int64 = ShioriListIdentity.defaultListID,
        dataRevision: Int
    ) {
        residentRelations = snapshot.relations
        residentShiorisByID = Dictionary(
            uniqueKeysWithValues: snapshot.resolvedShioris.map { ($0.id, $0) }
        )
        residentFacetSnapshot = snapshot.facetSnapshot
        tableFacetDistribution = snapshot.facetSnapshot.distribution
        residentListID = listID
        residentDataRevision = dataRevision
    }

    func residentFacetProjection(
        using filter: CueFacetFilter
    ) -> (shioriIDs: [Int64], distribution: CueFacetDistribution) {
        guard let residentFacetSnapshot else { return ([], .zero) }
        var availableFilter = filter
        availableFilter.languages.formIntersection(
            residentFacetSnapshot.distribution.languageCounts.keys
        )
        let projection = residentFacetSnapshot.filteredCueIDs(
            using: availableFilter,
            limit: residentFacetSnapshot.cueIDs.count
        )
        let shioriIDByCueID = Dictionary(
            uniqueKeysWithValues: residentRelations.map { ($0.cueID, $0.id) }
        )
        return (
            projection.cueIDs.compactMap { shioriIDByCueID[$0] },
            projection.distribution
        )
    }

    func clearResidentSnapshot() {
        residentRelations = []
        residentShiorisByID = [:]
        residentFacetSnapshot = nil
        tableFacetDistribution = nil
        residentListID = nil
        residentDataRevision = nil
    }

    func removeShioriFromCurrentProjection(id: Int64) {
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
        residentShiorisByID[id] = nil
        residentFacetSnapshot = residentFacetSnapshot?.removingCueIDs(
            removedCueIDs
        )
        tableFacetDistribution = residentFacetProjection(
            using: tableFacetFilter
        ).distribution
        tableTotalSavedRowCount = residentRelations.count
        if let tableResultShioriIDs {
            let remainingIDs = tableResultShioriIDs.filter { $0 != id }
            self.tableResultShioriIDs = remainingIDs
            tableResultRowCount = remainingIDs.count
            tableResultSnapshotID = UUID()
            tableSelectionState.reset()
            tableSelectionEntryIDs = remainingIDs.map(Int.init)
        }
        tableRowStore.removeResidentShiori(
            id: id,
            tableName: "shiori",
            probeSurface: .shiori,
            probeScope: uiProbeScope
        )
    }

    func invalidateTableRows(tableName: String = "shiori") {
        clearResidentSnapshot()
        clearTableRowsForReload(tableName: tableName)
        tableDataRevision += 1
    }

    func markTableRowsStale() {
        tableRowsNeedReload = true
        residentFacetSnapshot = nil
        tableFacetDistribution = nil
        tableDataRevision += 1
    }
}
