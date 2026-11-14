import AppKit
import CoreGraphics
import Testing
@testable import CueSeekerApp

@MainActor
@Test
func subtitleTextLayoutUnderlineRectsUseFixedThicknessAndPixelAlignment() {
    let layout = SubtitleTextLayout()
    layout.update(
        attributedString: SubtitleTableText.body("sunny\nWrong World"),
        width: 240
    )

    let rects = layout.underlineRects(
        at: .zero,
        thickness: SubtitleTableMetrics.interactiveTextUnderlineThickness,
        offset: SubtitleTableMetrics.interactiveTextUnderlineOffset,
        backingScaleFactor: 2
    )

    #expect(rects.count == 2)
    #expect(rects.allSatisfy { abs($0.height - SubtitleTableMetrics.interactiveTextUnderlineThickness) < 0.001 })
    #expect(rects.allSatisfy { abs(($0.minY * 2).rounded() - ($0.minY * 2)) < 0.001 })
}

@MainActor
@Test
func subtitleTextLayoutHitTestingUsesActualLineFragments() {
    let layout = SubtitleTextLayout()
    layout.update(
        attributedString: SubtitleTableText.body("short\nmuch longer line"),
        width: 240
    )

    #expect(layout.containsText(at: CGPoint(x: 4, y: 8), origin: .zero) == true)
    #expect(layout.containsText(at: CGPoint(x: 220, y: 8), origin: .zero) == false)
    #expect(layout.containsText(at: CGPoint(x: 80, y: 24), origin: .zero) == true)
}

@MainActor
@Test
func subtitleTextLayoutUnionUsedRectCoversAllVisibleLines() throws {
    let layout = SubtitleTextLayout()
    layout.update(
        attributedString: SubtitleTableText.body("short\nmuch longer line"),
        width: 240
    )

    let rects = layout.usedRects(at: .zero)
    let unionRect = try #require(layout.unionUsedRect(at: .zero))

    #expect(rects.count == 2)
    #expect(abs(unionRect.minX - rects.map(\.minX).min()!) < 0.001)
    #expect(abs(unionRect.maxX - rects.map(\.maxX).max()!) < 0.001)
    #expect(abs(unionRect.minY - rects.map(\.minY).min()!) < 0.001)
    #expect(abs(unionRect.maxY - rects.map(\.maxY).max()!) < 0.001)
    #expect(unionRect.width > rects[0].width)
    #expect(unionRect.height > rects[0].height)
}

@MainActor
@Test
func subtitleCueFixedLineHeightCenteringPreservesUsedRectsAndPositionsUnderlines() throws {
    let text = "まだやってたのね その腕でライブなんて\n冗談じゃない"

    for style in [SubtitleTableCueStyle.primary, .extra] {
        let attributed = SubtitleTableCueTextMeasurer.attributedString(
            text,
            style: style,
            foregroundColor: .labelColor
        )
        #expect(attributed.attribute(.baselineOffset, at: 0, effectiveRange: nil) == nil)

        let layout = SubtitleTextLayout()
        layout.update(attributedString: attributed, width: 110)

        let usedRects = layout.usedRects(at: .zero)
        let fullRange = NSRange(location: 0, length: attributed.length)
        let selectionRects = layout.selectionRects(
            forUTF16Range: fullRange,
            at: .zero
        )
        let underlines = layout.underlineRects(
            at: .zero,
            thickness: SubtitleTableMetrics.interactiveTextUnderlineThickness,
            offset: SubtitleTableMetrics.interactiveTextUnderlineOffset,
            backingScaleFactor: 2
        )

        #expect(usedRects.count > 2)
        #expect(selectionRects.count == usedRects.count)
        #expect(underlines.count == usedRects.count)
        for ((usedRect, selectionRect), underline) in zip(zip(usedRects, selectionRects), underlines) {
            #expect(selectionRect.height == style.lineHeight)
            #expect(abs(underline.width - ceil(usedRect.width * 2) / 2) <= 0.5)
            #expect(underline.minY > usedRect.minY)
            #expect(underline.maxY <= usedRect.minY + style.lineHeight)
        }

        let hitPoint = try #require(usedRects.first.map {
            CGPoint(x: $0.midX, y: $0.midY)
        })
        #expect(layout.containsText(at: hitPoint, origin: .zero))
        #expect(layout.utf16Offset(at: hitPoint, origin: .zero) >= 0)
    }
}

@MainActor
@Test
func subtitleBodySameFontRoleKeepsBaselineAndSelectionConsistentAcrossGlyphShapes() throws {
    let samples = ["Ave Mujica - 01", "It's MyGO!!!!! - 07", "...", "08:33 - 10:38"]
    var expectedUnderlineMinY: CGFloat?
    var expectedSelectionRect: CGRect?

    for sample in samples {
        let attributed = SubtitleTableText.body(sample, role: .primaryContent)
        let layout = SubtitleTextLayout()
        layout.update(attributedString: attributed, width: 300)

        let underline = try #require(
            layout.underlineRects(
                at: .zero,
                thickness: SubtitleTableMetrics.interactiveTextUnderlineThickness,
                offset: SubtitleTableMetrics.interactiveTextUnderlineOffset,
                backingScaleFactor: 2
            ).first
        )
        let selection = try #require(
            layout.selectionRects(
                forUTF16Range: NSRange(location: 0, length: attributed.length),
                at: .zero
            ).first
        )

        if let expectedUnderlineMinY {
            #expect(underline.minY == expectedUnderlineMinY)
        } else {
            expectedUnderlineMinY = underline.minY
        }
        if let expectedSelectionRect {
            #expect(selection.minY == expectedSelectionRect.minY)
            #expect(selection.height == expectedSelectionRect.height)
        } else {
            expectedSelectionRect = selection
        }
    }
}

@MainActor
@Test
func subtitleHeaderColumnsShareIdenticalCenteredSelectionTopAndHeight() throws {
    let cellRect = CGRect(x: 0, y: 0, width: 200, height: 44)
    let titles = ["Cues", "Display Title", "Time Range", "Date Added"]
    let expectedMinY = cellRect.midY - SubtitleTableText.cellLineHeight / 2

    for title in titles {
        let attributed = SubtitleTableText.header(title)
        let layout = SubtitleTextLayout()
        layout.update(attributedString: attributed, width: cellRect.width)

        let centerYOffset = try #require(layout.firstLineCenterYOffset)
        let origin = CGPoint(x: 0, y: max(cellRect.minY, cellRect.midY - centerYOffset))
        let selection = try #require(
            layout.selectionRects(
                forUTF16Range: NSRange(location: 0, length: attributed.length),
                at: origin,
                targetLineHeight: SubtitleTableText.cellLineHeight
            ).first
        )

        #expect(abs(selection.minY - expectedMinY) < 0.001)
        #expect(selection.height == SubtitleTableText.cellLineHeight)
    }
}
