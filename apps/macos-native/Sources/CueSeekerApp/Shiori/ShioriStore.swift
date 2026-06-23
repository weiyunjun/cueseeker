import Foundation
import CueSeekerCore

@MainActor
final class ShioriStore: ObservableObject {
    @Published var collapsedShioriGroupPaths: Set<String> = []
    @Published var shioris: [Shiori] = []
    @Published var shioriFileGroups: [ShioriFileGroup] = []
    @Published var selectedShiori: Shiori?
    @Published var tableSearchDraft = ""
    @Published var tableVisibleColumnIDs = SchemaWorkbenchSearchDefaults.initialVisibleShioriColumnIDs
    @Published var tableActiveFilterSetID: String?
    @Published var tableFilterRules: [SchemaWorkbenchFilterRule] = []
    @Published var tableTotalSavedRowCount = 0
    @Published var tableHasLoadedInitialPage = false

    let tableRowStore = TableSandboxRowModelStore()

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
        tableRowStore.updateShioriRows([], tableName: tableName)
    }

    func markTableRowsLoaded(totalSavedRowCount: Int) {
        tableTotalSavedRowCount = totalSavedRowCount
        tableHasLoadedInitialPage = true
    }

    func invalidateTableRows(tableName: String = "shiori") {
        clearTableRowsForReload(tableName: tableName)
    }
}
