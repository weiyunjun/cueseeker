import CoreGraphics
import Testing
@testable import CueSeekerApp

@Test
func schemaWorkbenchFormatsSearchAndSelectionCounts() {
    #expect(schemaWorkbenchResultCountText(0) == "0 results")
    #expect(schemaWorkbenchResultCountText(1) == "1 result")
    #expect(schemaWorkbenchResultCountText(42) == "42 results")
    #expect(schemaWorkbenchResultCountText(-1) == "0 results")
    #expect(schemaWorkbenchSelectedCountText(0) == "0 rows selected")
    #expect(schemaWorkbenchSelectedCountText(1) == "1 row selected")
    #expect(schemaWorkbenchSelectedCountText(3) == "3 rows selected")
    #expect(schemaWorkbenchSelectedCountText(-1) == "0 rows selected")
}

@Test
func schemaWorkbenchSelectionModeRequiresExactResults() {
    #expect(!schemaWorkbenchCanEnterSelectionMode(hasExactResultSet: false))
    #expect(schemaWorkbenchCanEnterSelectionMode(hasExactResultSet: true))
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
    #expect(SchemaWorkbenchSearchDefaults.shioriColumns.map(\.id) == [
        "rowNumber", "cues", "display", "time", "dateAdded",
    ])
    #expect(SchemaWorkbenchSearchDefaults.shioriColumns.map(\.width) == [
        .fixed(50),
        .weighted(weight: 6, min: 240),
        .weighted(weight: 3, min: 180),
        .weighted(weight: 2, min: 140),
        .weighted(weight: 2, min: 120),
    ])
}
