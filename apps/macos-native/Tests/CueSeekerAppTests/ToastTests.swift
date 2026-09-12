import Foundation
import Testing
@testable import CueSeekerApp

@MainActor
@Test
func toastCenterEvictsTheOldestInsteadOfQueueing() {
    let center = ToastCenter()
    let start = Date()
    for index in 1...5 {
        center.show(
            ToastRequest(scenarioID: "scenario.\(index)", message: "Toast \(index)"),
            now: start
        )
    }

    #expect(center.visibleItems.map(\.request.message) == [
        "Toast 2", "Toast 3", "Toast 4", "Toast 5"
    ])

    center.removeExpired(at: start.addingTimeInterval(5.1))
    #expect(center.visibleItems.isEmpty)
}

@MainActor
@Test
func toastCenterKeepsOneToastPerResultAndRestartsItsStay() {
    let center = ToastCenter()
    let start = Date()
    let repeated = ShioriToastRequest.saveSucceeded(listName: "Study")

    center.show(repeated, now: start)
    let firstID = center.visibleItems[0].id
    center.show(ToastRequest(scenarioID: "scenario.other", message: "Other"), now: start)
    center.show(repeated, now: start.addingTimeInterval(3))

    #expect(center.visibleItems.count == 2)
    #expect(center.visibleItems.last?.id == firstID)

    center.removeExpired(at: start.addingTimeInterval(5.1))
    #expect(center.visibleItems.map(\.request.message) == [repeated.message])
}

@MainActor
@Test
func toastDurationsRunOnTheWallClock() {
    let center = ToastCenter()
    let start = Date()
    center.show(ToastRequest(message: "Away"), now: start)

    center.removeExpired(at: start.addingTimeInterval(4.9))
    #expect(center.visibleItems.count == 1)

    center.removeExpired(at: start.addingTimeInterval(5))
    #expect(center.visibleItems.isEmpty)
}

/// Both surfaces draw their icon through the line width table, and a size the
/// Icon Registry does not document trips an assertion at the moment of drawing
/// rather than at build time. Nothing else in this suite draws.
@MainActor
@Test
func feedbackIconsDrawAtTheirDocumentedSizes() {
    for size in [
        WorkbenchControlMetrics.redesignToastIconSize,
        PlaybackChromeMetrics.feedbackIconSize,
    ] {
        #expect(AppIconLineWidth.bySize[size] != nil, "\(size)pt is not in the registry")
        #expect(AppIconStore.image(.bookmarkSimple, size: size, weight: .fill) != nil)
    }
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
    #expect(ShioriToastRequest.moveSucceeded(listName: "Study").icon == .bookmarkSimple)
    #expect(ShioriToastRequest.moveSucceeded(listName: "Study").iconWeight == .fill)
}
