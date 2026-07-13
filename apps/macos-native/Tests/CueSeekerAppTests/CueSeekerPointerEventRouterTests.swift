import AppKit
import Testing
@testable import CueSeekerApp

@MainActor
@Test
func cueSeekerPointerEventRouterBroadcastsAndReturnsLeftMouseDown() throws {
    let spy = CueSeekerLeftMouseDownNotificationSpy()
    NotificationCenter.default.addObserver(
        spy,
        selector: #selector(CueSeekerLeftMouseDownNotificationSpy.receive(_:)),
        name: .cueSeekerLeftMouseDown,
        object: nil
    )
    defer { NotificationCenter.default.removeObserver(spy) }
    let event = try #require(NSEvent.mouseEvent(
        with: .leftMouseDown,
        location: .zero,
        modifierFlags: [],
        timestamp: 0,
        windowNumber: 0,
        context: nil,
        eventNumber: 0,
        clickCount: 1,
        pressure: 1
    ))

    let routedEvent = CueSeekerPointerEventRouter.routeLeftMouseDown(event)

    #expect(routedEvent === event)
    #expect(spy.events.count == 1)
    #expect(spy.events.first === event)
}

@MainActor
private final class CueSeekerLeftMouseDownNotificationSpy: NSObject {
    private(set) var events: [NSEvent] = []

    @objc func receive(_ notification: Notification) {
        if let event = notification.object as? NSEvent {
            events.append(event)
        }
    }
}
