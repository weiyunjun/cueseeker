import CoreGraphics
import Testing
@testable import CueSeekerApp

@Test
func schemaWorkbenchFormatsSearchAndSelectionCounts() {
    #expect(schemaWorkbenchResultCountText(0) == "0 results")
    #expect(schemaWorkbenchResultCountText(1) == "1 result")
    #expect(schemaWorkbenchResultCountText(42) == "42 results")
    #expect(schemaWorkbenchResultCountText(-1) == "0 results")
    #expect(schemaWorkbenchExcerptCountText(0) == "0 excerpts")
    #expect(schemaWorkbenchExcerptCountText(1) == "1 excerpt")
    #expect(schemaWorkbenchExcerptCountText(42) == "42 excerpts")
    #expect(schemaWorkbenchExcerptCountText(-1) == "0 excerpts")
    #expect(
        schemaWorkbenchSelectedCountText(selectedRowCount: 0, selectableRowCount: 4)
            == "0 / 4 rows selected"
    )
    #expect(
        schemaWorkbenchSelectedCountText(selectedRowCount: 3, selectableRowCount: 4)
            == "3 / 4 rows selected"
    )
    #expect(
        schemaWorkbenchSelectedCountText(selectedRowCount: -1, selectableRowCount: -1)
            == "0 / 0 rows selected"
    )
}

@Test
func schemaWorkbenchSelectionModeRequiresExactResultsWithASelectableRow() {
    #expect(!schemaWorkbenchCanEnterSelectionMode(
        hasExactResultSet: false,
        selectableRowCount: 3
    ))
    #expect(!schemaWorkbenchCanEnterSelectionMode(
        hasExactResultSet: true,
        selectableRowCount: 0
    ))
    #expect(schemaWorkbenchCanEnterSelectionMode(
        hasExactResultSet: true,
        selectableRowCount: 1
    ))
}

@Test
func schemaWorkbenchTablesUseDocumentedColumnWeightsAndMinimums() {
    #expect(SchemaWorkbenchSearchDefaults.columns.map(\.id) == [
        "rowNumber", "cues", "display", "time",
    ])
    #expect(SchemaWorkbenchSearchDefaults.columns.map(\.width) == [
        .fixed(50),
        .weighted(weight: 6, min: 240),
        .weighted(weight: 3, min: 180),
        .weighted(weight: 2, min: 140),
    ])
    #expect(SchemaWorkbenchSearchDefaults.excerptColumns.map(\.id) == [
        "rowNumber", "cues", "display", "time", "dateAdded",
    ])
    #expect(SchemaWorkbenchSearchDefaults.excerptColumns.map(\.width) == [
        .fixed(50),
        .weighted(weight: 6, min: 240),
        .weighted(weight: 3, min: 180),
        .weighted(weight: 2, min: 140),
        .weighted(weight: 2, min: 120),
    ])
}

@Test
func schemaWorkbenchSelectionActionExportActionsExcludeExitButton() {
    let actions = SchemaWorkbenchSelectionAction.exportActions(
        exportToAnki: {},
        copyDeepLinks: {},
        copyTable: {}
    )
    #expect(actions.count == 3)
    #expect(actions.map(\.id) == ["anki", "copy-deep-links", "copy-table"])
    #expect(actions.map(\.icon) == [.export, .linkSimple, .copy])
    #expect(!actions.contains(where: { $0.id == "exit" }))
}

