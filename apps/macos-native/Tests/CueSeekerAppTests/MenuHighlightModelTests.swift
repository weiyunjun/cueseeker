import Testing
@testable import CueSeekerApp

@Suite(.serialized)
@MainActor
struct MenuHighlightModelTests {
    @Test
    func openHighlightsFirstSelectablePositionByDefault() {
        let model = MenuHighlightModel()
        defer { model.close() }

        // Positions 1 and 4 stand for a divider and a disabled item.
        model.open(selectablePositions: [0, 2, 3, 5])

        #expect(model.highlightedPosition == 0)
        #expect(!model.adoptsHover)
    }

    @Test
    func openHonoursAnAlreadySelectedValue() {
        let model = MenuHighlightModel()
        defer { model.close() }

        model.open(selectablePositions: [0, 1, 2, 3], defaultPosition: 2)
        #expect(model.highlightedPosition == 2)

        // A default that cannot take the highlight falls back to the first.
        model.open(selectablePositions: [0, 2], defaultPosition: 1)
        #expect(model.highlightedPosition == 0)
    }

    @Test
    func arrowMovementSkipsUnselectablePositionsAndStopsAtBothEnds() {
        let model = MenuHighlightModel()
        defer { model.close() }
        model.open(selectablePositions: [0, 2, 3, 5])

        #expect(model.moveHighlight(by: 1))
        #expect(model.highlightedPosition == 2)
        model.moveHighlight(by: 1)
        #expect(model.highlightedPosition == 3)
        model.moveHighlight(by: 1)
        #expect(model.highlightedPosition == 5)

        // Stops at the last position instead of wrapping, and still reports the
        // key as consumed.
        #expect(model.moveHighlight(by: 1))
        #expect(model.highlightedPosition == 5)

        model.moveHighlight(by: -1)
        #expect(model.highlightedPosition == 3)
        model.moveHighlight(by: -1)
        model.moveHighlight(by: -1)
        #expect(model.highlightedPosition == 0)
        #expect(model.moveHighlight(by: -1))
        #expect(model.highlightedPosition == 0)
    }

    @Test
    func hoverDoesNotMoveTheHighlightUntilThePointerActuallyMoves() {
        let model = MenuHighlightModel()
        defer { model.close() }
        model.open(selectablePositions: [0, 1, 2])

        // The menu opened under the pointer: hover arrives without any motion.
        model.noteHover(true, at: 2)
        #expect(model.highlightedPosition == 0)

        // Real motion opens the gate and the remembered hover is adopted, even
        // though the pointer never crossed into another row.
        model.notePointerMoved()
        #expect(model.adoptsHover)
        #expect(model.highlightedPosition == 2)

        // With the gate open, crossing rows follows the pointer.
        model.noteHover(false, at: 2)
        model.noteHover(true, at: 1)
        #expect(model.highlightedPosition == 1)
    }

    @Test
    func keyboardMovementClosesTheHoverGateAgain() {
        let model = MenuHighlightModel()
        defer { model.close() }
        model.open(selectablePositions: [0, 1, 2])
        model.noteHover(true, at: 2)
        model.notePointerMoved()
        #expect(model.highlightedPosition == 2)

        // The keyboard takes over: the row still under the stationary pointer
        // must not pull the highlight back.
        model.moveHighlight(by: -1)
        #expect(model.highlightedPosition == 1)
        #expect(!model.adoptsHover)
        model.noteHover(true, at: 2)
        #expect(model.highlightedPosition == 1)
    }

    @Test
    func hoverOnAnUnselectablePositionIsIgnored() {
        let model = MenuHighlightModel()
        defer { model.close() }
        model.open(selectablePositions: [0, 2])
        model.notePointerMoved()

        model.noteHover(true, at: 1)
        #expect(model.highlightedPosition == 0)
        model.noteHover(true, at: 2)
        #expect(model.highlightedPosition == 2)
    }

    @Test
    func keyboardMovementHidesTheCursorAndPointerMotionRestoresIt() {
        AppCursorVisibility.resetForTesting()
        let model = MenuHighlightModel()
        defer {
            model.close()
            AppCursorVisibility.resetForTesting()
        }
        model.open(selectablePositions: [0, 1])
        #expect(!AppCursorVisibility.isCursorHidden)

        model.moveHighlight(by: 1)
        #expect(AppCursorVisibility.isCursorHidden)

        model.notePointerMoved()
        #expect(!AppCursorVisibility.isCursorHidden)
    }

    @Test
    func closingReleasesTheCursorAndClearsTheHighlight() {
        AppCursorVisibility.resetForTesting()
        let model = MenuHighlightModel()
        defer { AppCursorVisibility.resetForTesting() }
        model.open(selectablePositions: [0, 1])
        model.moveHighlight(by: 1)
        #expect(model.isOpen)
        #expect(AppCursorVisibility.isCursorHidden)

        model.close()

        #expect(!model.isOpen)
        #expect(model.highlightedPosition == nil)
        #expect(!AppCursorVisibility.isCursorHidden)
    }

    @Test
    func cursorStaysHiddenWhileAnyOwnerAsksForIt() {
        AppCursorVisibility.resetForTesting()
        defer { AppCursorVisibility.resetForTesting() }

        AppCursorVisibility.setHidden(true, owner: .player)
        AppCursorVisibility.setHidden(true, owner: .menu)
        #expect(AppCursorVisibility.isCursorHidden)

        // Releasing one owner must not reveal the cursor the other still hides.
        AppCursorVisibility.setHidden(false, owner: .menu)
        #expect(AppCursorVisibility.isCursorHidden)

        AppCursorVisibility.setHidden(false, owner: .player)
        #expect(!AppCursorVisibility.isCursorHidden)
    }
}
