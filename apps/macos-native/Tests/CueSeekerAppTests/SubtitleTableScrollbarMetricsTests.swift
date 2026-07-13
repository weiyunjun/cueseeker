import AppKit
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
func subtitleTableScrollbarMetricsProvidesTransparentThumbHitSlop() {
    let metrics = SubtitleTableScrollbarMetrics(
        viewportSize: CGSize(width: 300, height: 200),
        contentSize: CGSize(width: 300, height: 1_000),
        contentOffset: .zero
    )
    let bounds = CGRect(x: 0, y: 0, width: 300, height: 200)
    let thumb = metrics.thumbRect(for: .vertical, in: bounds)
    let interactiveThumb = metrics.interactiveThumbRect(for: .vertical, in: bounds)

    #expect(thumb != nil)
    #expect(interactiveThumb != nil)
    guard let thumb, let interactiveThumb else { return }
    #expect(interactiveThumb.width == thumb.width + 2 * SubtitleTableMetrics.scrollbarHitSlop)
    #expect(interactiveThumb.contains(CGPoint(x: thumb.minX - SubtitleTableMetrics.scrollbarHitSlop / 2, y: thumb.midY)))
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

@Test
func subtitleTableScrollbarMetricsMapsThumbDragDeltaToScrollOffset() {
    let metrics = SubtitleTableScrollbarMetrics(
        viewportSize: CGSize(width: 300, height: 200),
        contentSize: CGSize(width: 300, height: 1_000),
        contentOffset: .zero
    )
    let bounds = CGRect(x: 0, y: 0, width: 300, height: 200)
    let thumb = metrics.thumbRect(for: .vertical, in: bounds)

    #expect(thumb != nil)
    guard let thumb else { return }
    let mappedOffset = metrics.scrollOffset(
        for: .vertical,
        dragStartThumbOrigin: thumb.minY,
        dragDelta: 40,
        in: bounds
    )
    #expect(mappedOffset > 0)
}

@MainActor
@Test
func subtitleTableScrollbarOverlayHitTestConvertsSuperviewCoordinates() {
    let parent = NSView(frame: CGRect(x: 0, y: 0, width: 320, height: 320))
    let scrollView = NSScrollView(frame: CGRect(x: 0, y: 44, width: 300, height: 200))
    let documentView = NSView(frame: CGRect(x: 0, y: 0, width: 300, height: 1_000))
    scrollView.documentView = documentView

    let overlay = SubtitleTableScrollbarOverlayView(frame: CGRect(x: 0, y: 44, width: 300, height: 200))
    overlay.scrollView = scrollView
    overlay.isRedesign = true

    parent.addSubview(scrollView)
    parent.addSubview(overlay)

    let metrics = SubtitleTableScrollbarMetrics(
        viewportSize: scrollView.contentView.bounds.size,
        contentSize: documentView.frame.size,
        contentOffset: scrollView.contentView.bounds.origin
    )
    let interactiveThumb = metrics.interactiveThumbRect(for: .vertical, in: overlay.bounds)

    #expect(interactiveThumb != nil)
    guard let interactiveThumb else { return }
    let parentPoint = overlay.convert(CGPoint(x: interactiveThumb.midX, y: interactiveThumb.midY), to: parent)
    #expect(parent.hitTest(parentPoint) === overlay)

    let transparentTrackPoint = overlay.convert(
        CGPoint(
            x: interactiveThumb.midX,
            y: min(overlay.bounds.maxY - 2, interactiveThumb.maxY + 40)
        ),
        to: parent
    )
    #expect(parent.hitTest(transparentTrackPoint) !== overlay)
}

@MainActor
@Test
func subtitleTableScrollbarOverlayPreservesDragAndWheelBehavior() throws {
    _ = NSApplication.shared
    let window = NSWindow(
        contentRect: CGRect(x: 0, y: 0, width: 300, height: 200),
        styleMask: [.borderless],
        backing: .buffered,
        defer: false
    )
    let parent = NSView(frame: CGRect(x: 0, y: 0, width: 300, height: 200))
    let scrollView = ScrollbarSpyScrollView(
        frame: CGRect(x: 0, y: 0, width: 300, height: 200)
    )
    let documentView = NSView(frame: CGRect(x: 0, y: 0, width: 300, height: 1_000))
    scrollView.documentView = documentView
    let overlay = SubtitleTableScrollbarOverlayView(
        frame: CGRect(x: 0, y: 0, width: 300, height: 200)
    )
    overlay.scrollView = scrollView
    overlay.isRedesign = true
    parent.addSubview(scrollView)
    parent.addSubview(overlay)
    window.contentView = parent

    var dragStates: [Bool] = []
    overlay.onDragStateChanged = { dragStates.append($0) }
    let metrics = SubtitleTableScrollbarMetrics(
        viewportSize: scrollView.contentView.bounds.size,
        contentSize: documentView.frame.size,
        contentOffset: .zero
    )
    let thumb = try #require(
        metrics.thumbRect(for: .vertical, in: overlay.bounds)
    )
    let start = CGPoint(x: thumb.midX, y: thumb.midY)
    let end = CGPoint(x: start.x, y: start.y + 40)
    let startInWindow = overlay.convert(start, to: nil)
    let endInWindow = overlay.convert(end, to: nil)

    overlay.mouseDown(with: subtitleTableScrollbarMouseEvent(
        type: .leftMouseDown,
        location: startInWindow,
        window: window
    ))
    overlay.mouseDragged(with: subtitleTableScrollbarMouseEvent(
        type: .leftMouseDragged,
        location: endInWindow,
        window: window
    ))
    let expectedDraggedOffset = metrics.scrollOffset(
        for: .vertical,
        dragStartThumbOrigin: thumb.minY,
        dragDelta: 40,
        in: overlay.bounds
    )
    #expect(
        abs(scrollView.contentView.bounds.origin.y - expectedDraggedOffset) < 0.001
    )
    let offsetBeforeMouseUp = scrollView.contentView.bounds.origin.y
    overlay.mouseUp(with: subtitleTableScrollbarMouseEvent(
        type: .leftMouseUp,
        location: endInWindow,
        window: window
    ))

    #expect(abs(scrollView.contentView.bounds.origin.y - offsetBeforeMouseUp) < 0.001)
    #expect(dragStates == [true, false])

    let wheelCGEvent = try #require(CGEvent(
        scrollWheelEvent2Source: nil,
        units: .pixel,
        wheelCount: 1,
        wheel1: 1,
        wheel2: 0,
        wheel3: 0
    ))
    let wheelEvent = try #require(NSEvent(cgEvent: wheelCGEvent))
    overlay.scrollWheel(with: wheelEvent)
    #expect(scrollView.receivedScrollWheelCount == 1)
}

@MainActor
@Test
func subtitleTableScrollbarOverlayPreservesHorizontalDragBehavior() throws {
    _ = NSApplication.shared
    let window = NSWindow(
        contentRect: CGRect(x: 0, y: 0, width: 300, height: 200),
        styleMask: [.borderless],
        backing: .buffered,
        defer: false
    )
    let parent = NSView(frame: CGRect(x: 0, y: 0, width: 300, height: 200))
    let scrollView = NSScrollView(frame: parent.bounds)
    let documentView = NSView(frame: CGRect(x: 0, y: 0, width: 900, height: 200))
    scrollView.documentView = documentView
    let overlay = SubtitleTableScrollbarOverlayView(frame: parent.bounds)
    overlay.scrollView = scrollView
    overlay.isRedesign = true
    parent.addSubview(scrollView)
    parent.addSubview(overlay)
    window.contentView = parent

    let metrics = SubtitleTableScrollbarMetrics(
        viewportSize: scrollView.contentView.bounds.size,
        contentSize: documentView.frame.size,
        contentOffset: .zero
    )
    let thumb = try #require(
        metrics.thumbRect(for: .horizontal, in: overlay.bounds)
    )
    let start = CGPoint(x: thumb.midX, y: thumb.midY)
    let end = CGPoint(x: start.x + 40, y: start.y)
    overlay.mouseDown(with: subtitleTableScrollbarMouseEvent(
        type: .leftMouseDown,
        location: overlay.convert(start, to: nil),
        window: window
    ))
    overlay.mouseDragged(with: subtitleTableScrollbarMouseEvent(
        type: .leftMouseDragged,
        location: overlay.convert(end, to: nil),
        window: window
    ))

    let expectedDraggedOffset = metrics.scrollOffset(
        for: .horizontal,
        dragStartThumbOrigin: thumb.minX,
        dragDelta: 40,
        in: overlay.bounds
    )
    #expect(
        abs(scrollView.contentView.bounds.origin.x - expectedDraggedOffset) < 0.001
    )
    overlay.mouseUp(with: subtitleTableScrollbarMouseEvent(
        type: .leftMouseUp,
        location: overlay.convert(end, to: nil),
        window: window
    ))
}

@MainActor
private func subtitleTableScrollbarMouseEvent(
    type: NSEvent.EventType,
    location: CGPoint,
    window: NSWindow
) -> NSEvent {
    NSEvent.mouseEvent(
        with: type,
        location: location,
        modifierFlags: [],
        timestamp: 0,
        windowNumber: window.windowNumber,
        context: nil,
        eventNumber: 0,
        clickCount: 1,
        pressure: 1
    )!
}

@MainActor
private final class ScrollbarSpyScrollView: NSScrollView {
    private(set) var receivedScrollWheelCount = 0

    override func scrollWheel(with event: NSEvent) {
        receivedScrollWheelCount += 1
    }
}
