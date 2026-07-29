import AppKit
import Testing
@testable import CueSeekerApp

@MainActor
@Test
func subtitleCueGeometryUsesDocumentedHardLineHeights() {
    let measurer = SubtitleTableCueTextMeasurer()

    for (text, expectedLines, expectedHeight) in [
        ("one", 1, CGFloat(40)),
        ("one\ntwo", 2, CGFloat(64)),
        ("one\ntwo\nthree", 3, CGFloat(88)),
    ] {
        let row = SubtitleTableRow(id: expectedLines, displayTitle: "", primaryCueText: text, cueGroupTexts: [text], primaryGroupIndex: 0)
        let measurement = measurer.rowMeasurement(row: row, effectiveCuesWidth: 2_000, showsCueGroup: false)
        #expect(measurement.primaryLineCount == expectedLines)
        #expect(measurement.extraLineCount == 0)
        #expect(measurement.height == expectedHeight)
    }
}

@MainActor
@Test
func subtitleCueGeometryAddsEveryExtraCueVisualLineBelowPrimary() {
    let measurer = SubtitleTableCueTextMeasurer()
    let onePrimaryOneExtra = SubtitleTableRow(
        id: 1,
        displayTitle: "",
        primaryCueText: "main",
        cueGroupTexts: ["extra", "main"],
        primaryGroupIndex: 1
    )
    let onePrimaryTwoExtras = SubtitleTableRow(
        id: 2,
        displayTitle: "",
        primaryCueText: "main",
        cueGroupTexts: ["extra one", "extra two", "main"],
        primaryGroupIndex: 2
    )
    let twoPrimaryOneExtra = SubtitleTableRow(
        id: 3,
        displayTitle: "",
        primaryCueText: "main one\nmain two",
        cueGroupTexts: ["extra", "main one\nmain two"],
        primaryGroupIndex: 1
    )

    let firstMeasurement = measurer.rowMeasurement(
        row: onePrimaryOneExtra,
        effectiveCuesWidth: 2_000,
        showsCueGroup: true
    )
    let secondMeasurement = measurer.rowMeasurement(
        row: onePrimaryTwoExtras,
        effectiveCuesWidth: 2_000,
        showsCueGroup: true
    )
    let thirdMeasurement = measurer.rowMeasurement(
        row: twoPrimaryOneExtra,
        effectiveCuesWidth: 2_000,
        showsCueGroup: true
    )

    #expect(firstMeasurement.height == 68)
    #expect(firstMeasurement.primaryFirstLineOffset == 8)
    #expect(firstMeasurement.extraCueOffsets == [40])
    #expect(secondMeasurement.height == 96)
    #expect(secondMeasurement.primaryFirstLineOffset == 8)
    #expect(secondMeasurement.extraCueOffsets == [40, 68])
    #expect(thirdMeasurement.height == 92)
    #expect(thirdMeasurement.primaryFirstLineOffset == 8)
    #expect(thirdMeasurement.extraCueOffsets == [64])
    #expect(measurer.rowMeasurement(row: onePrimaryTwoExtras, effectiveCuesWidth: 2_000, showsCueGroup: false).height == 40)
}

@MainActor
@Test
func subtitleCueGeometrySpacesCueItemsInsteadOfVisualLines() {
    let measurer = SubtitleTableCueTextMeasurer()
    let oneTwoLineExtra = SubtitleTableRow(
        id: 1,
        displayTitle: "",
        primaryCueText: "main",
        cueGroupTexts: ["extra one\nextra two", "main"],
        primaryGroupIndex: 1
    )
    let twoOneLineExtras = SubtitleTableRow(
        id: 2,
        displayTitle: "",
        primaryCueText: "main",
        cueGroupTexts: ["extra one", "extra two", "main"],
        primaryGroupIndex: 2
    )

    let oneItem = measurer.rowMeasurement(
        row: oneTwoLineExtra,
        effectiveCuesWidth: 2_000,
        showsCueGroup: true
    )
    let twoItems = measurer.rowMeasurement(
        row: twoOneLineExtras,
        effectiveCuesWidth: 2_000,
        showsCueGroup: true
    )

    #expect(oneItem.extraCueLineCounts == [2])
    #expect(oneItem.height == 88)
    #expect(twoItems.extraCueLineCounts == [1, 1])
    #expect(twoItems.height == 96)
}

@Test
func subtitleCueGeometryCentersCueBlockInsideTallestColumnRow() {
    let measurement = SubtitleTableRowMeasurement(
        height: SubtitleTableCueGeometry.rowHeight(
            primaryLineCount: 1,
            extraCueLineCounts: [],
            otherContentHeights: [50]
        ),
        primaryLineCount: 1,
        extraCueLineCounts: []
    )

    #expect(measurement.height == 66)
    #expect(measurement.cueBlockHeight == 24)
    #expect(measurement.cueBlockTopOffset == 21)
    #expect(measurement.primaryFirstLineOffset == 21)
}

@Test
func subtitleTableHoverVerticalPaddingMatchesRowPadding() {
    #expect(WorkbenchControlMetrics.redesignTableCellHoverPaddingY == SubtitleTableCueGeometry.rowPaddingY)
}

@MainActor
@Test
func subtitleCueVisualLineCountPreservesTerminalAndConsecutiveBreaks() {
    let measurer = SubtitleTableCueTextMeasurer()

    #expect(measurer.visualLineCount(text: "a\n", width: 2_000, style: .primary) == 2)
    #expect(measurer.visualLineCount(text: "a\n\nb", width: 2_000, style: .primary) == 3)
    #expect(measurer.visualLineCount(text: "a\r\nb", width: 2_000, style: .primary) == 2)
    #expect(measurer.visualLineCount(text: "", width: 2_000, style: .primary) == 1)
}

@MainActor
@Test
func subtitleCueVisualLineCountHasNoSoftWrapLimit() {
    let measurer = SubtitleTableCueTextMeasurer()
    let text = Array(repeating: "wrap", count: 40).joined(separator: " ")
    let lines = measurer.visualLineCount(text: text, width: 50, style: .primary)

    #expect(lines > 6)
    #expect(SubtitleTableCueGeometry.rowHeight(primaryLineCount: lines, extraCueLineCounts: []) == 16 + CGFloat(lines) * 24)
}

@MainActor
@Test
func subtitleCueTypographyUsesDocumentedPrimaryAndExtraStyles() {
    #expect(SubtitleTableCueStyle.primary.fontSize == 14)
    #expect(SubtitleTableCueStyle.primary.fontWeight == .medium)
    #expect(SubtitleTableCueStyle.primary.lineHeight == 24)
    #expect(SubtitleTableCueStyle.extra.fontSize == 12)
    #expect(SubtitleTableCueStyle.extra.fontWeight == .regular)
    #expect(SubtitleTableCueStyle.extra.lineHeight == 20)
}

@MainActor
@Test
func subtitleCueTypographyVisuallyCentersGlyphsInsideFixedLineHeights() throws {
    for style in [SubtitleTableCueStyle.primary, .extra] {
        let attributed = SubtitleTableCueTextMeasurer.attributedString(
            "まだやってたのね",
            style: style,
            foregroundColor: .labelColor
        )
        let textStorage = NSTextStorage(attributedString: attributed)
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(
            containerSize: CGSize(width: 2_000, height: CGFloat.greatestFiniteMagnitude)
        )
        textContainer.lineFragmentPadding = 0
        layoutManager.usesFontLeading = false
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
        layoutManager.ensureLayout(for: textContainer)

        let glyphRange = layoutManager.glyphRange(for: textContainer)
        #expect(glyphRange.length > 0)
        let glyphIndex = try #require(glyphRange.length > 0 ? glyphRange.location : nil)
        let lineRect = layoutManager.lineFragmentUsedRect(
            forGlyphAt: glyphIndex,
            effectiveRange: nil
        )
        let baseline = layoutManager.location(forGlyphAt: glyphIndex).y
        let visualTop = baseline - style.font.ascender
        let visualBottom = baseline - style.font.descender
        let topMargin = visualTop - lineRect.minY
        let bottomMargin = lineRect.maxY - visualBottom

        #expect(lineRect.height == style.lineHeight)
        #expect(abs(topMargin - bottomMargin) < 1)
        #expect(
            attributed.attribute(.baselineOffset, at: 0, effectiveRange: nil) as? CGFloat
                == style.baselineOffset
        )
    }
}

@Test
func subtitleVirtualRowHeightCacheMapsSparseTwoMillionRowGeometry() {
    var cache = SubtitleVirtualRowHeightCache()
    cache.configure(rowCount: 2_000_000, defaultHeight: 40)

    let changedFirst = cache.setHeight(60, for: 0)
    let changedMiddle = cache.setHeight(100, for: 1_000_000)
    let changedLast = cache.setHeight(80, for: 1_999_999)
    #expect(changedFirst)
    #expect(changedMiddle)
    #expect(changedLast)
    #expect(cache.count == 3)
    #expect(cache.height(for: 0) == 60)
    #expect(cache.height(for: 999_999) == 40)
    #expect(cache.yOffset(for: 1) == 60)
    #expect(cache.yOffset(for: 1_000_000) == 40_000_020)
    #expect(cache.yOffset(for: 1_000_001) == 40_000_120)
    #expect(cache.totalHeight == 80_000_120)
    #expect(cache.rowIndex(atY: 0) == 0)
    #expect(cache.rowIndex(atY: 59.9) == 0)
    #expect(cache.rowIndex(atY: 60) == 1)
    #expect(cache.rowIndex(atY: 40_000_020) == 1_000_000)
    #expect(cache.rowIndex(atY: cache.totalHeight) == 1_999_999)
}

@Test
func subtitleVirtualRowHeightCachePreservesSparseMeasurementsAcrossAppend() {
    var cache = SubtitleVirtualRowHeightCache()
    cache.configure(rowCount: 50_000, defaultHeight: 40)
    let changedFirst = cache.setHeight(88, for: 12_345)
    let changedLast = cache.setHeight(60, for: 49_999)
    #expect(changedFirst)
    #expect(changedLast)
    #expect(cache.totalHeight == 2_000_068)

    cache.configure(rowCount: 2_000_000, defaultHeight: 40)

    #expect(cache.count == 2)
    #expect(cache.height(for: 12_345) == 88)
    #expect(cache.height(for: 49_999) == 60)
    #expect(cache.yOffset(for: 50_000) == 2_000_068)
    #expect(cache.totalHeight == 80_000_068)
    #expect(cache.rowIndex(atY: cache.yOffset(for: 49_999)) == 49_999)
}

@Test
func subtitleVirtualRowHeightCacheMatchesNaivePrefixAndInverseGeometry() {
    let rowCount = 257
    var cache = SubtitleVirtualRowHeightCache()
    cache.configure(rowCount: rowCount, defaultHeight: 40)
    var naive = Array(repeating: CGFloat(40), count: rowCount)
    var state: UInt64 = 0xC0FFEE

    for _ in 0..<80 {
        state = state &* 6_364_136_223_846_793_005 &+ 1
        let row = Int(state % UInt64(rowCount))
        let height = CGFloat(40 + Int((state >> 16) % 8) * 20)
        _ = cache.setHeight(height, for: row)
        naive[row] = height
    }

    var prefix: CGFloat = 0
    for row in 0..<rowCount {
        #expect(cache.height(for: row) == naive[row])
        #expect(cache.yOffset(for: row) == prefix)
        #expect(cache.rowIndex(atY: prefix) == row)
        prefix += naive[row]
        #expect(cache.rowIndex(atY: prefix - 0.001) == row)
    }
    #expect(cache.totalHeight == prefix)
    #expect(cache.rowIndex(atY: prefix) == rowCount - 1)
}

@Test
func subtitleVirtualRowHeightCacheRemovesDefaultOverridesAndHandlesBounds() {
    var cache = SubtitleVirtualRowHeightCache()
    cache.configure(rowCount: 10, defaultHeight: 40)
    _ = cache.setHeight(80, for: 9)
    #expect(cache.count == 1)
    _ = cache.setHeight(40, for: 9)
    #expect(cache.count == 0)
    #expect(cache.totalHeight == 400)
    #expect(cache.rowIndex(atY: .infinity) == 9)
    #expect(cache.rowIndex(atY: -.infinity) == 0)
    #expect(cache.rowIndex(atY: .nan) == 0)

    _ = cache.setHeight(80, for: 8)
    cache.configure(rowCount: 5, defaultHeight: 40)
    #expect(cache.count == 0)
    #expect(cache.totalHeight == 200)
}
