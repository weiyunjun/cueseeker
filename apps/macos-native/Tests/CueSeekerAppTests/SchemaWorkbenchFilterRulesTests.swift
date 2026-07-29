import Testing
@testable import CueSeekerApp

@Test
func schemaWorkbenchColumnVisibilityMenuLocksCuesAndSkipsCheckboxColumn() {
    let items = SchemaWorkbenchColumnVisibilityMenu.items(
        columns: SchemaWorkbenchSearchDefaults.columns,
        visibleColumnIDs: ["display", "time"]
    )

    #expect(items.map(\.id) == ["cues", "display", "time"])
    #expect(items.map(\.title) == ["Cues", "Display Title", "Time Range"])

    let cues = items.first { $0.id == "cues" }
    #expect(cues?.isSelected == true)
    #expect(cues?.isEnabled == false)

    let time = items.first { $0.id == "time" }
    #expect(time?.isSelected == true)
    #expect(time?.isEnabled == true)
}

@Test
func schemaWorkbenchColumnVisibilityMenuUsesShioriColumnOrder() {
    let items = SchemaWorkbenchColumnVisibilityMenu.items(
        columns: SchemaWorkbenchSearchDefaults.shioriColumns,
        visibleColumnIDs: SchemaWorkbenchSearchDefaults.initialVisibleShioriColumnIDs
    )

    #expect(items.map(\.id) == ["cues", "display", "time", "dateAdded"])
    #expect(items.map(\.title) == ["Cues", "Display Title", "Time Range", "Date Added"])
}
