import AppKit
import Testing
@testable import CueSeekerApp

@Test
func tableScrollbarPrimitivePreservesDualAxisGeometry() throws {
    let presentation = TableScrollbarPresentation(
        vertical: TableScrollbarAxisPresentation(
            visibleFraction: 0.2,
            positionFraction: 0.5
        ),
        horizontal: TableScrollbarAxisPresentation(
            visibleFraction: 0.5,
            positionFraction: 0.25
        )
    )
    let geometry = TableScrollbarGeometry(presentation: presentation)
    let bounds = CGRect(x: 0, y: 0, width: 300, height: 200)
    let verticalTrack = try #require(geometry.trackRect(for: .vertical, in: bounds))
    let horizontalTrack = try #require(geometry.trackRect(for: .horizontal, in: bounds))
    let verticalThumb = try #require(geometry.thumbRect(for: .vertical, in: bounds))
    let horizontalThumb = try #require(geometry.thumbRect(for: .horizontal, in: bounds))

    #expect(verticalTrack == CGRect(x: 288, y: 4, width: 8, height: 180))
    #expect(horizontalTrack == CGRect(x: 4, y: 188, width: 280, height: 8))
    #expect(verticalThumb == CGRect(x: 288, y: 76, width: 8, height: 36))
    #expect(horizontalThumb == CGRect(x: 39, y: 188, width: 140, height: 8))
}

@Test
func tableScrollbarPrimitiveClampsFractionsAndKeepsMinimumThumb() throws {
    let presentation = TableScrollbarPresentation(
        vertical: TableScrollbarAxisPresentation(
            visibleFraction: -2,
            positionFraction: 4
        )
    )
    let geometry = TableScrollbarGeometry(presentation: presentation)
    let bounds = CGRect(x: 0, y: 0, width: 100, height: 200)
    let track = try #require(geometry.trackRect(for: .vertical, in: bounds))
    let thumb = try #require(geometry.thumbRect(for: .vertical, in: bounds))
    let interactive = try #require(
        geometry.interactiveThumbRect(for: .vertical, in: bounds)
    )

    #expect(thumb.height == TableScrollbarPrimitiveMetrics.minimumThumbLength)
    #expect(thumb.maxY == track.maxY)
    #expect(
        interactive.width
            == thumb.width + TableScrollbarPrimitiveMetrics.hitSlop * 2
    )
}

@Test
func tableScrollbarPrimitiveDragFractionRoundTrips() throws {
    let bounds = CGRect(x: 0, y: 0, width: 300, height: 200)
    let presentation = TableScrollbarPresentation(
        vertical: TableScrollbarAxisPresentation(
            visibleFraction: 0.25,
            positionFraction: 0.25
        )
    )
    let geometry = TableScrollbarGeometry(presentation: presentation)
    let thumb = try #require(geometry.thumbRect(for: .vertical, in: bounds))
    let resolved = geometry.positionFraction(
        for: .vertical,
        thumbPosition: thumb.minY,
        in: bounds
    )
    let moved = geometry.positionFraction(
        for: .vertical,
        dragStartThumbOrigin: thumb.minY,
        dragDelta: 40,
        in: bounds
    )

    #expect(abs(resolved - 0.25) < 0.0001)
    #expect(moved > resolved)
}

@MainActor
@Test
func tableScrollbarPrimitiveEmitsCompleteDragSequence() throws {
    _ = NSApplication.shared
    let window = NSWindow(
        contentRect: CGRect(x: 0, y: 0, width: 300, height: 200),
        styleMask: [.borderless],
        backing: .buffered,
        defer: false
    )
    let view = TableScrollbarOverlayView(
        frame: CGRect(x: 0, y: 0, width: 300, height: 200)
    )
    let presentation = TableScrollbarPresentation(
        vertical: TableScrollbarAxisPresentation(
            visibleFraction: 0.2,
            positionFraction: 0.25
        )
    )
    view.presentationProvider = { presentation }
    view.isPresented = true
    window.contentView = view
    var events: [TableScrollbarDragEvent] = []
    var dragStates: [Bool] = []
    view.onDrag = { events.append($0) }
    view.onDragStateChanged = { dragStates.append($0) }

    let geometry = TableScrollbarGeometry(presentation: presentation)
    let thumb = try #require(geometry.thumbRect(for: .vertical, in: view.bounds))
    let start = CGPoint(x: thumb.midX, y: thumb.midY)
    let end = CGPoint(x: start.x, y: start.y + 30)
    let startInWindow = view.convert(start, to: nil)
    let endInWindow = view.convert(end, to: nil)
    view.mouseDown(with: scrollbarMouseEvent(
        type: .leftMouseDown,
        location: startInWindow,
        window: window
    ))
    view.mouseDragged(with: scrollbarMouseEvent(
        type: .leftMouseDragged,
        location: endInWindow,
        window: window
    ))
    view.mouseUp(with: scrollbarMouseEvent(
        type: .leftMouseUp,
        location: endInWindow,
        window: window
    ))

    #expect(events.map(\.phase) == [.began, .changed, .ended])
    try #require(events.count == 3)
    #expect(events[1].positionFraction > events[0].positionFraction)
    #expect(events[2].positionFraction == events[1].positionFraction)
    #expect(dragStates == [true, false])
}

@MainActor
@Test
func tableScrollbarPrimitiveDoesNotDragAFullLengthPersistentThumb() throws {
    _ = NSApplication.shared
    let window = NSWindow(
        contentRect: CGRect(x: 0, y: 0, width: 300, height: 200),
        styleMask: [.borderless],
        backing: .buffered,
        defer: false
    )
    let view = TableScrollbarOverlayView(
        frame: CGRect(x: 0, y: 0, width: 300, height: 200)
    )
    let presentation = TableScrollbarPresentation(
        vertical: TableScrollbarAxisPresentation(
            visibleFraction: 1,
            positionFraction: 0.5
        )
    )
    view.presentationProvider = { presentation }
    view.isPresented = true
    window.contentView = view
    var events: [TableScrollbarDragEvent] = []
    var dragStates: [Bool] = []
    view.onDrag = { events.append($0) }
    view.onDragStateChanged = { dragStates.append($0) }

    let geometry = TableScrollbarGeometry(presentation: presentation)
    let thumb = try #require(geometry.thumbRect(for: .vertical, in: view.bounds))
    let pointInWindow = view.convert(
        CGPoint(x: thumb.midX, y: thumb.midY),
        to: nil
    )
    view.mouseDown(with: scrollbarMouseEvent(
        type: .leftMouseDown,
        location: pointInWindow,
        window: window
    ))
    view.mouseUp(with: scrollbarMouseEvent(
        type: .leftMouseUp,
        location: pointInWindow,
        window: window
    ))

    #expect(events.isEmpty)
    #expect(dragStates.isEmpty)
}

@MainActor
private func scrollbarMouseEvent(
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
