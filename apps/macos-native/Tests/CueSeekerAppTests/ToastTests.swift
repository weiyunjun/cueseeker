import Testing
@testable import CueSeekerApp

@MainActor
@Test
func toastCenterStacksFourAndPromotesFIFOWithoutReplacingVisibleItems() {
    let center = ToastCenter()
    for index in 1...5 {
        center.show(ToastRequest(message: "Toast \(index)"))
    }

    #expect(center.visibleItems.map(\.request.message) == [
        "Toast 1", "Toast 2", "Toast 3", "Toast 4"
    ])
    #expect(center.queuedCount == 1)

    let firstID = center.visibleItems[0].id
    center.setHovered(true, itemID: firstID)
    center.advance(by: 5.1)

    #expect(center.visibleItems.map(\.request.message) == ["Toast 1", "Toast 5"])
    #expect(center.queuedCount == 0)

    center.setHovered(false, itemID: firstID)
    center.advance(by: 5.1)
    #expect(center.visibleItems.isEmpty)
}

@MainActor
@Test
func toastCenterPausesAllDurationsWhileAppIsInactive() {
    let center = ToastCenter()
    center.show(ToastRequest(message: "Paused"))
    center.setAppActive(false)
    center.advance(by: 10)
    #expect(center.visibleItems.count == 1)

    center.setAppActive(true)
    center.advance(by: 5.1)
    #expect(center.visibleItems.isEmpty)
}

@Test
func shioriToastRequestsMatchTheUsageRegistry() {
    #expect(ShioriToastRequest.moveSucceeded(listName: "Study").message == "Moved to “Study”")
    #expect(ShioriToastRequest.duplicateSucceeded(listName: "Study").message == "Duplicated to “Study”")
    #expect(
        ShioriToastRequest.destinationUnavailable(listName: "Study").message
            == "“Study” is no longer available"
    )
    #expect(ShioriToastRequest.moveFailed.message == "Couldn’t move Shiori. Try again")
    #expect(ShioriToastRequest.duplicateFailed.message == "Couldn’t duplicate Shiori. Try again")
    #expect(ShioriToastRequest.saveSucceeded(listName: "Study").message == "Saved to “Study”")
    #expect(
        ShioriToastRequest.saveFailed(listName: "Study").message
            == "Couldn’t save to “Study”. Try again"
    )
    #expect(
        ShioriToastRequest.destinationAlreadyContainsCue(listName: "Study").message
            == "Shiori already exists in “Study”"
    )
    #expect(ShioriToastRequest.moveSucceeded(listName: "Study").duration == 5)
    #expect(ShioriToastRequest.moveSucceeded(listName: "Study").position == .appCenter)
    #expect(ShioriToastRequest.moveSucceeded(listName: "Study").animation == .default)
}
