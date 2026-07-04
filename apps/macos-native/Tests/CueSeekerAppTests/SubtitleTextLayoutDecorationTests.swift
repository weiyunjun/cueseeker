import AppKit
import CoreGraphics
import Testing
@testable import CueSeekerApp

@MainActor
@Test
func subtitleTextLayoutUnderlineRectsUseFixedThicknessAndPixelAlignment() {
    let layout = SubtitleTextLayout()
    layout.update(
        attributedString: SubtitleTableText.body("sunny\nWrong World", isRedesign: true),
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
        attributedString: SubtitleTableText.body("short\nmuch longer line", isRedesign: true),
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
        attributedString: SubtitleTableText.body("short\nmuch longer line", isRedesign: true),
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
