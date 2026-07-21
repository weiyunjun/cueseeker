import Combine
import Foundation
import CueSeekerCore

@MainActor
final class ShioriStore: ObservableObject {
    private let uiProbeScope: String?
    private var cueContentChangesCancellable: AnyCancellable?
    private var isTableProjectionResponseActive = true
    private var pendingCueContentChange: CueContentStoreChange?
    @Published var selectedShiori: Shiori?
    @Published var tableSearchDraft = ""
    @Published var tableSubmittedSearchText = ""
    @Published var tableVisibleColumnIDs = SchemaWorkbenchSearchDefaults.initialVisibleShioriColumnIDs
    @Published var tableActiveFilterSetID: String?
    @Published var tableFilterRules: [SchemaWorkbenchFilterRule] = []
    @Published var tableTotalSavedRowCount = 0
    @Published var tableResultRowCount = 0
    @Published var tableHasLoadedInitialPage = false
    @Published var tableDataRevision = 0
    private(set) var tableResultSnapshotID = UUID()
    private(set) var tableResultShioriIDs: [Int64]?
    private(set) var residentRelations: [ShioriRelation] = []
    private(set) var residentTagsByShioriID: [Int64: [ShioriTag]] = [:]
    private(set) var residentDataRevision: Int?
    var tableViewportAnchor: TableViewportAnchor?
    var tableSelectionState = TableSandboxRowSelectionState()
    var tableSelectionEntryIDs: [Int] = []

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
        tableTotalSavedRowCount = totalSavedRowCount
        tableHasLoadedInitialPage = true
    }

    func installTableResultShioriIDs(_ shioriIDs: [Int64]) {
        tableResultShioriIDs = shioriIDs
        tableResultRowCount = shioriIDs.count
    }

    func installResidentSnapshot(
        _ snapshot: ShioriResidentSnapshot,
        dataRevision: Int
    ) {
        residentRelations = snapshot.relations
        residentTagsByShioriID = snapshot.tagsByShioriID
        residentDataRevision = dataRevision
    }

    func updateResidentTags(_ tags: [ShioriTag], forShioriID shioriID: Int64) {
        guard residentDataRevision != nil else { return }
        residentTagsByShioriID[shioriID] = tags
    }

    func removeResidentTag(tagID: Int64, fromShioriIDs shioriIDs: [Int64]) {
        guard residentDataRevision != nil else { return }
        for shioriID in shioriIDs {
            residentTagsByShioriID[shioriID]?.removeAll { $0.id == tagID }
        }
    }

    func clearResidentSnapshot() {
        residentRelations = []
        residentTagsByShioriID = [:]
        residentDataRevision = nil
    }

    func invalidateTableRows(tableName: String = "shiori") {
        clearResidentSnapshot()
        clearTableRowsForReload(tableName: tableName)
        tableDataRevision += 1
    }
}
