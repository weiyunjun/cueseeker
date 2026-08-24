import CoreGraphics
import Testing
@testable import CueSeekerApp

private let container = CGRect(x: 0, y: 0, width: 400, height: 300)
private let menuSize = CGSize(width: 120, height: 100)

@Test
func menuOpensBelowItsAnchorAndAlignsToItsLeadingEdge() {
    let anchor = CGRect(x: 40, y: 50, width: 60, height: 20)

    let frame = MenuPlacement.openingFrame(
        anchor: anchor,
        menuSize: menuSize,
        in: container,
        gap: 8
    )

    #expect(frame.minY == anchor.maxY + 8)
    #expect(frame.minX == anchor.minX)
}

@Test
func menuOpensAboveWhenItWouldNotFitBelow() {
    let anchor = CGRect(x: 40, y: 240, width: 60, height: 20)

    let frame = MenuPlacement.openingFrame(
        anchor: anchor,
        menuSize: menuSize,
        in: container,
        gap: 8
    )

    #expect(frame.maxY == anchor.minY - 8)
}

@Test
func menuSlidesAlongTheEdgeWhenNeitherSideFits() {
    // Tall menu in a short container: neither below nor above has room.
    let anchor = CGRect(x: 40, y: 150, width: 60, height: 20)
    let tallMenu = CGSize(width: 120, height: 280)

    let frame = MenuPlacement.openingFrame(
        anchor: anchor,
        menuSize: tallMenu,
        in: container,
        gap: 8
    )

    // Slid up until its bottom rests on the container's bottom edge.
    #expect(frame.maxY == container.maxY)
    #expect(frame.minY >= container.minY)
}

@Test
func menuMovesInsideTheTrailingEdgeAndRespectsItsInset() {
    let anchor = CGRect(x: 360, y: 50, width: 30, height: 20)

    let frame = MenuPlacement.openingFrame(
        anchor: anchor,
        menuSize: menuSize,
        in: container,
        gap: 8,
        edgeInset: 12
    )

    #expect(frame.maxX == container.maxX - 12)
}

@Test
func menuTravelsWithItsAnchorWithoutChangingSide() {
    let anchor = CGRect(x: 40, y: 240, width: 60, height: 20)
    let opened = MenuPlacement.openingFrame(
        anchor: anchor,
        menuSize: menuSize,
        in: container,
        gap: 8
    )
    let offset = MenuPlacement.offset(from: anchor, to: opened)
    #expect(opened.maxY == anchor.minY - 8)

    // The anchor scrolls up to where the menu would have opened downward.
    let moved = anchor.offsetBy(dx: 0, dy: -200)
    let followed = MenuPlacement.followingFrame(
        anchor: moved,
        offset: offset,
        menuSize: menuSize
    )

    // Still above the anchor, and moved by exactly what the anchor moved.
    #expect(followed.maxY == moved.minY - 8)
    #expect(followed.minY == opened.minY - 200)
}

@Test
func aMenuThatFollowsItsAnchorOutOfViewIsNotPulledBack() {
    let anchor = CGRect(x: 40, y: 50, width: 60, height: 20)
    let opened = MenuPlacement.openingFrame(
        anchor: anchor,
        menuSize: menuSize,
        in: container,
        gap: 8
    )
    let offset = MenuPlacement.offset(from: anchor, to: opened)

    let scrolledAway = anchor.offsetBy(dx: 0, dy: -400)
    let followed = MenuPlacement.followingFrame(
        anchor: scrolledAway,
        offset: offset,
        menuSize: menuSize
    )

    #expect(followed.maxY < container.minY)
}
