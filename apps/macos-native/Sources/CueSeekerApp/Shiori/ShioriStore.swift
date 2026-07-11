import Foundation
import CueSeekerCore

@MainActor
final class ShioriStore: ObservableObject {
    private let uiProbeScope: String?
    @Published var collapsedShioriGroupPaths: Set<String> = []
    @Published var shioris: [Shiori] = []
    @Published var shioriFileGroups: [ShioriFileGroup] = []
    @Published var selectedShiori: Shiori?
    @Published var tableSearchDraft = ""
    @Published var tableSubmittedSearchText = ""
    @Published var tableVisibleColumnIDs = SchemaWorkbenchSearchDefaults.initialVisibleShioriColumnIDs
    @Published var tableActiveFilterSetID: String?
    @Published var tableFilterRules: [SchemaWorkbenchFilterRule] = []
    @Published var tableTotalSavedRowCount = 0
    @Published var tableHasLoadedInitialPage = false
    @Published var tableDataRevision = 0

    let tableRowStore = TableSandboxRowModelStore()

    init(uiProbeScope: String? = nil) {
        self.uiProbeScope = uiProbeScope
    }

    var hasShioriFileGroups: Bool {
        !shioriFileGroups.isEmpty
    }

    var shioriCount: Int {
        shioris.count
    }

    var shioriFileCount: Int {
        shioriFileGroups.count
    }

    func clearTableRowsForReload(tableName: String = "shiori") {
        tableHasLoadedInitialPage = false
        tableTotalSavedRowCount = 0
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

    func invalidateTableRows(tableName: String = "shiori") {
        clearTableRowsForReload(tableName: tableName)
        tableDataRevision += 1
    }
}
