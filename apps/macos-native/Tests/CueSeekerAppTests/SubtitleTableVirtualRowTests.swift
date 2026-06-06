import CoreGraphics
import Testing
@testable import CueSeekerApp

@MainActor
@Test
func subtitleTableViewUsesVirtualRowCountWithoutMaterializingModels() {
    let loadedRow = SubtitleTableRow(id: 1, name: "Episode 01", cues: "loaded cue")
    let coordinator = SubtitleTableView.Coordinator(
        tableName: "test-search",
        rowCount: 2_000_000,
        rowProvider: { index in
            index == 0 ? loadedRow : nil
        },
        rowsVersion: 1,
        onVisibleRowsChange: { _ in },
        onPlay: { _ in }
    )

    #expect(coordinator.numberOfRowsForTesting() == 2_000_000)
    #expect(coordinator.cellFullText(row: 0, column: 2) == "loaded cue")
    #expect(coordinator.cellFullText(row: 1_000_000, column: 0) == "1000001")
    #expect(coordinator.cellFullText(row: 1_000_000, column: 2) == "")
}

@Test
func subtitleVirtualRowHeightCacheKeepsFixedRowHeightForFastScrollMapping() {
    var cache = SubtitleVirtualRowHeightCache()

    let changed = cache.setHeight(CGFloat(120), for: 2_000_000, defaultHeight: CGFloat(56))
    #expect(!changed)
    #expect(cache.count == 0)
    #expect(cache.height(for: 2_000_000, defaultHeight: CGFloat(56)) == CGFloat(56))
    #expect(cache.height(for: 1_999_999, defaultHeight: CGFloat(56)) == CGFloat(56))
    #expect(cache.rowIndex(atY: CGFloat(112), rowCount: 2_000_000, defaultHeight: CGFloat(56)) == 2)
    #expect(cache.totalHeight(rowCount: 2_000_000, defaultHeight: CGFloat(56)) == CGFloat(112_000_000))
}
