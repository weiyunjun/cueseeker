import CoreGraphics
import Testing
@testable import CueSeekerApp

@Test
func subtitleTableScrollbarMetricsShowsOnlyScrollableAxes() {
    let fitted = SubtitleTableScrollbarMetrics(
        viewportSize: CGSize(width: 300, height: 200),
        contentSize: CGSize(width: 300, height: 200),
        contentOffset: .zero
    )
    #expect(fitted.isVisible(.vertical) == false)
    #expect(fitted.isVisible(.horizontal) == false)

    let verticalOnly = SubtitleTableScrollbarMetrics(
        viewportSize: CGSize(width: 300, height: 200),
        contentSize: CGSize(width: 300, height: 1_000),
        contentOffset: .zero
    )
    #expect(verticalOnly.isVisible(.vertical) == true)
    #expect(verticalOnly.isVisible(.horizontal) == false)

    let horizontalOnly = SubtitleTableScrollbarMetrics(
        viewportSize: CGSize(width: 300, height: 200),
        contentSize: CGSize(width: 900, height: 200),
        contentOffset: .zero
    )
    #expect(horizontalOnly.isVisible(.vertical) == false)
    #expect(horizontalOnly.isVisible(.horizontal) == true)
}

@Test
func subtitleTableScrollbarMetricsUsesEightPixelThumbThickness() {
    let metrics = SubtitleTableScrollbarMetrics(
        viewportSize: CGSize(width: 300, height: 200),
        contentSize: CGSize(width: 300, height: 1_000),
        contentOffset: .zero
    )
    let thumb = metrics.thumbRect(for: .vertical, in: CGRect(x: 0, y: 0, width: 300, height: 200))

    #expect(thumb?.width == SubtitleTableMetrics.scrollbarSize)
    #expect(thumb?.height ?? 0 >= SubtitleTableMetrics.scrollbarMinThumbLength)
    #expect(metrics.thumbRect(for: .horizontal, in: CGRect(x: 0, y: 0, width: 300, height: 200)) == nil)
}

@Test
func subtitleTableScrollbarMetricsMapsThumbPositionBackToScrollOffset() {
    let metrics = SubtitleTableScrollbarMetrics(
        viewportSize: CGSize(width: 300, height: 200),
        contentSize: CGSize(width: 300, height: 1_000),
        contentOffset: CGPoint(x: 0, y: 400)
    )
    let bounds = CGRect(x: 0, y: 0, width: 300, height: 200)
    let thumb = metrics.thumbRect(for: .vertical, in: bounds)

    #expect(thumb != nil)
    guard let thumb else { return }
    let mappedOffset = metrics.scrollOffset(for: .vertical, thumbPosition: thumb.minY, in: bounds)
    #expect(abs(mappedOffset - 400) < 0.001)
}
