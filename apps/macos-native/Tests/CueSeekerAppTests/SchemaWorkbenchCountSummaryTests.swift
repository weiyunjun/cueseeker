import CoreGraphics
import Testing
@testable import CueSeekerApp

@Test
func schemaWorkbenchCountSummaryFormatsDefaultRows() {
    let segments = SchemaWorkbenchCountSummaryText.segments(
        for: SchemaWorkbenchTableSummary(totalRowCount: 32, selectedRowCount: 0)
    )

    #expect(segments == [
        SchemaWorkbenchCountSummarySegment(text: "32", tone: .primary),
        SchemaWorkbenchCountSummarySegment(text: " rows", tone: .secondary),
    ])
}

@Test
func schemaWorkbenchCountSummaryFormatsSelectedRows() {
    let segments = SchemaWorkbenchCountSummaryText.segments(
        for: SchemaWorkbenchTableSummary(totalRowCount: 32, selectedRowCount: 3)
    )

    #expect(segments == [
        SchemaWorkbenchCountSummarySegment(text: "3", tone: .primary),
        SchemaWorkbenchCountSummarySegment(text: " / ", tone: .secondary),
        SchemaWorkbenchCountSummarySegment(text: "32", tone: .primary),
        SchemaWorkbenchCountSummarySegment(text: " rows selected", tone: .secondary),
    ])
}

@Test
func schemaWorkbenchCountSummaryFormatsOverflowCounts() {
    #expect(SchemaWorkbenchCountSummaryText.formattedCount(99_999) == "99999")
    #expect(SchemaWorkbenchCountSummaryText.formattedCount(100_000) == "99999+")

    let segments = SchemaWorkbenchCountSummaryText.segments(
        for: SchemaWorkbenchTableSummary(totalRowCount: 100_000, selectedRowCount: 100_000)
    )

    #expect(segments == [
        SchemaWorkbenchCountSummarySegment(text: "99999+", tone: .primary),
        SchemaWorkbenchCountSummarySegment(text: " / ", tone: .secondary),
        SchemaWorkbenchCountSummarySegment(text: "99999+", tone: .primary),
        SchemaWorkbenchCountSummarySegment(text: " rows selected", tone: .secondary),
    ])
}

@Test
func schemaWorkbenchCountSummaryClampsNegativeCounts() {
    let segments = SchemaWorkbenchCountSummaryText.segments(
        for: SchemaWorkbenchTableSummary(totalRowCount: -1, selectedRowCount: -1)
    )

    #expect(segments == [
        SchemaWorkbenchCountSummarySegment(text: "0", tone: .primary),
        SchemaWorkbenchCountSummarySegment(text: " rows", tone: .secondary),
    ])
}

@Test
func subtitleTableCheckboxLeadingInsetMatchesSummaryAlignment() {
    #expect(SubtitleTableMetrics.checkboxLeadingInset == CGFloat(17))
}

@Test
func schemaWorkbenchTablesUseDocumentedColumnWeightsAndMinimums() {
    #expect(SchemaWorkbenchSearchDefaults.columns.map(\.width) == [
        .fixed(50),
        .weighted(weight: 3, min: 180),
        .weighted(weight: 6, min: 240),
        .weighted(weight: 2, min: 140),
    ])
    #expect(SchemaWorkbenchSearchDefaults.shioriColumns.map(\.width) == [
        .fixed(50),
        .weighted(weight: 3, min: 180),
        .weighted(weight: 6, min: 240),
        .weighted(weight: 2, min: 140),
        .weighted(weight: 2, min: 140),
        .weighted(weight: 2, min: 120),
    ])
}
