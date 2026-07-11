import AppKit
import Testing
@testable import CueSeekerApp

@Test
func subtitleTableRowHeightCacheReusesHeightForSameRowAndWidths() {
    var cache = SubtitleTableRowHeightCache()
    let row = SubtitleTableRow(id: 1, displayTitle: "Episode 01", cues: "line one\nline two")
    var computeCount = 0

    let first = cache.lookup(rowIndex: 0, row: row, effectiveCuesWidth: 640, showsCueGroup: false, styleRevision: 1) {
        computeCount += 1
        return testRowMeasurement(42)
    }
    let second = cache.lookup(rowIndex: 0, row: row, effectiveCuesWidth: 640, showsCueGroup: false, styleRevision: 1) {
        computeCount += 1
        return testRowMeasurement(99)
    }

    #expect(first.height == 42)
    #expect(!first.isCacheHit)
    #expect(second.height == 42)
    #expect(second.isCacheHit)
    #expect(computeCount == 1)
}

@Test
func subtitleTableRowHeightCacheMissesWhenWidthOrContentChanges() {
    var cache = SubtitleTableRowHeightCache()
    let row = SubtitleTableRow(id: 1, displayTitle: "Episode 01", cues: "line one")
    _ = cache.lookup(rowIndex: 0, row: row, effectiveCuesWidth: 640, showsCueGroup: false, styleRevision: 1) { testRowMeasurement(42) }

    var computeCount = 0
    let differentWidth = cache.lookup(rowIndex: 0, row: row, effectiveCuesWidth: 641, showsCueGroup: false, styleRevision: 1) {
        computeCount += 1
        return testRowMeasurement(50)
    }
    let changedContent = cache.lookup(
        rowIndex: 0,
        row: SubtitleTableRow(id: 1, displayTitle: "Episode 01", cues: "line one\nline two"),
        effectiveCuesWidth: 640,
        showsCueGroup: false,
        styleRevision: 1
    ) {
        computeCount += 1
        return testRowMeasurement(60)
    }

    #expect(!differentWidth.isCacheHit)
    #expect(differentWidth.height == 50)
    #expect(!changedContent.isCacheHit)
    #expect(changedContent.height == 60)
    #expect(computeCount == 2)
}

@Test
func subtitleTableRowHeightCachePrunesRowsNotInSnapshot() {
    var cache = SubtitleTableRowHeightCache()
    let kept = SubtitleTableRow(id: 1, displayTitle: "Episode 01", cues: "line one")
    let removed = SubtitleTableRow(id: 2, displayTitle: "Episode 02", cues: "line two")
    _ = cache.lookup(rowIndex: 0, row: kept, effectiveCuesWidth: 640, showsCueGroup: false, styleRevision: 1) { testRowMeasurement(42) }
    _ = cache.lookup(rowIndex: 1, row: removed, effectiveCuesWidth: 640, showsCueGroup: false, styleRevision: 1) { testRowMeasurement(50) }

    cache.prune(to: [kept])

    #expect(cache.count == 1)
    #expect(cache.lookup(rowIndex: 0, row: kept, effectiveCuesWidth: 640, showsCueGroup: false, styleRevision: 1) { testRowMeasurement(99) }.isCacheHit)
    #expect(!cache.lookup(rowIndex: 1, row: removed, effectiveCuesWidth: 640, showsCueGroup: false, styleRevision: 1) { testRowMeasurement(100) }.isCacheHit)
}

@Test
func subtitleTableRowHeightCacheStoresSparseRowIndexes() {
    var cache = SubtitleTableRowHeightCache()
    let row = SubtitleTableRow(id: 2_000_001, displayTitle: "Episode 2000001", cues: "line")
    var computeCount = 0

    let first = cache.lookup(rowIndex: 2_000_000, row: row, effectiveCuesWidth: 640, showsCueGroup: false, styleRevision: 1) {
        computeCount += 1
        return testRowMeasurement(42)
    }
    let second = cache.lookup(rowIndex: 2_000_000, row: row, effectiveCuesWidth: 640, showsCueGroup: false, styleRevision: 1) {
        computeCount += 1
        return testRowMeasurement(99)
    }

    #expect(cache.count == 1)
    #expect(first.height == 42)
    #expect(!first.isCacheHit)
    #expect(second.height == 42)
    #expect(second.isCacheHit)
    #expect(computeCount == 1)
}

@Test
func subtitleTableRowHeightCacheInvalidatesEveryCueLayoutKey() {
    let base = SubtitleTableRow(
        id: 7,
        primaryCueID: 70,
        displayTitle: "Episode 07",
        primaryCueText: "duplicate",
        cueGroupTexts: ["duplicate", "duplicate"],
        primaryGroupIndex: 0
    )
    let changedGroup = SubtitleTableRow(
        id: 7,
        primaryCueID: 70,
        displayTitle: "Episode 07",
        primaryCueText: "duplicate",
        cueGroupTexts: ["changed", "duplicate"],
        primaryGroupIndex: 1
    )
    let changedPrimaryIndex = SubtitleTableRow(
        id: 7,
        primaryCueID: 70,
        displayTitle: "Episode 07",
        primaryCueText: "duplicate",
        cueGroupTexts: ["duplicate", "duplicate"],
        primaryGroupIndex: 1
    )
    let changedPrimaryIdentity = SubtitleTableRow(
        id: 7,
        primaryCueID: 71,
        displayTitle: "Episode 07",
        primaryCueText: "duplicate",
        cueGroupTexts: ["duplicate", "duplicate"],
        primaryGroupIndex: 0
    )

    func misses(row: SubtitleTableRow, width: CGFloat = 640, show: Bool = false, revision: Int = 1) -> Bool {
        var cache = SubtitleTableRowHeightCache()
        _ = cache.lookup(
            rowIndex: 0,
            row: base,
            effectiveCuesWidth: 640,
            showsCueGroup: false,
            styleRevision: 1
        ) { testRowMeasurement(40) }
        return !cache.lookup(
            rowIndex: 0,
            row: row,
            effectiveCuesWidth: width,
            showsCueGroup: show,
            styleRevision: revision
        ) { testRowMeasurement(60) }.isCacheHit
    }

    #expect(misses(row: base, width: 641))
    #expect(misses(row: base, show: true))
    #expect(misses(row: base, revision: 2))
    #expect(misses(row: changedGroup))
    #expect(misses(row: changedPrimaryIndex))
    #expect(misses(row: changedPrimaryIdentity))
}

private func testRowMeasurement(_ height: CGFloat) -> SubtitleTableRowMeasurement {
    SubtitleTableRowMeasurement(height: height, primaryLineCount: 1, extraLineCount: 0)
}
