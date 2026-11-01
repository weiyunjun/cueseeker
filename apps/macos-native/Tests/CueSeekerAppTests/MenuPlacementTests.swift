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
func aScrollingMenuSlidesAlongTheEdgeToKeepFullHeightWhenContainerCanHoldIt() {
    // Neither single side holds the menu whole, but the container is tall
    // enough to hold the entire menu without a scrollbar.
    let anchor = CGRect(x: 40, y: 150, width: 60, height: 20)
    let tallMenu = CGSize(width: 120, height: 280)

    let frame = MenuPlacement.openingFrame(
        anchor: anchor,
        menuSize: tallMenu,
        in: container,
        gap: 8,
        shrinksToFit: true
    )

    #expect(frame.height == tallMenu.height)
    #expect(frame.maxY == container.maxY)
    #expect(frame.minY == container.maxY - tallMenu.height)
    #expect(frame.minY < anchor.minY)
    #expect(frame.maxY > anchor.maxY)
}

@Test
func aScrollingMenuOnlyShrinksWhenTheWholeContainerIsShorterThanTheMenu() {
    let anchor = CGRect(x: 40, y: 150, width: 60, height: 20)
    let oversizedMenu = CGSize(width: 120, height: 360)

    let frame = MenuPlacement.openingFrame(
        anchor: anchor,
        menuSize: oversizedMenu,
        in: container,
        gap: 8,
        edgeInset: 10,
        shrinksToFit: true
    )

    #expect(frame.minY == container.minY + 10)
    #expect(frame.maxY == container.maxY - 10)
    #expect(frame.height == container.height - 20)
}

@Test
func aPointAnchorNearTheTrailingEdgeFlipsToTheLeftOfThePointer() {
    let pointerAnchor = CGRect(x: 360, y: 150, width: 0, height: 0)
    let tallMenu = CGSize(width: 120, height: 240)

    let frame = MenuPlacement.openingFrame(
        anchor: pointerAnchor,
        menuSize: tallMenu,
        in: container,
        gap: 8,
        shrinksToFit: true
    )

    #expect(frame.height == tallMenu.height)
    #expect(frame.maxX == pointerAnchor.minX)
    #expect(frame.maxY == container.maxY)
}

@Test
func aTrailingButtonAnchorStepsLeftWhenVerticalShiftWouldOverlapTheButton() {
    let buttonAnchor = CGRect(x: 356, y: 140, width: 32, height: 32)
    let tallMenu = CGSize(width: 120, height: 240)

    let frame = MenuPlacement.openingFrame(
        anchor: buttonAnchor,
        menuSize: tallMenu,
        in: container,
        gap: 4,
        edgeInset: 8,
        shrinksToFit: true
    )

    #expect(frame.height == tallMenu.height)
    #expect(frame.maxX == buttonAnchor.minX - 4)
    #expect(frame.maxY == container.maxY - 8)
}

@Test
func aScrollingMenuThatFitsWholeKeepsTheHeightItAskedFor() {
    let anchor = CGRect(x: 40, y: 50, width: 60, height: 20)

    let frame = MenuPlacement.openingFrame(
        anchor: anchor,
        menuSize: menuSize,
        in: container,
        gap: 8,
        shrinksToFit: true
    )

    #expect(frame.minY == anchor.maxY + 8)
    #expect(frame.height == menuSize.height)
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
