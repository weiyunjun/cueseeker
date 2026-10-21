import Testing
@testable import CueSeekerApp

@Suite(.serialized)
@MainActor
struct MenuHighlightModelTests {
    @Test
    func openHighlightsFirstSelectablePositionByDefault() {
        AppCursorVisibility.resetForTesting()
        let model = MenuHighlightModel()
        defer { model.close() }

        // Positions 1 and 4 stand for a divider and a disabled item.
        model.open(selectablePositions: [0, 2, 3, 5])

        #expect(model.highlightedPosition == 0)
        #expect(model.selectedPosition == 0)
        #expect(model.hoveredPosition == nil)
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
    func hoverUpdatesIndependentlyOfSelectAndSelectTakesVisualPriority() {
        AppCursorVisibility.resetForTesting()
        let model = MenuHighlightModel()
        defer { model.close() }
        model.open(selectablePositions: [0, 1, 2])

        // The menu opens with item 0 Selected. Hovering item 2 sets Hover on 2
        // while keeping Select on 0.
        model.noteHover(true, at: 2)
        #expect(model.selectedPosition == 0)
        #expect(model.hoveredPosition == 2)
        #expect(model.isSelected(0))
        #expect(!model.isHovered(0))
        #expect(model.isHovered(2))
        #expect(!model.isSelected(2))

        // When Hover and Select coincide on item 0, only Select is shown.
        model.noteHover(false, at: 2)
        model.noteHover(true, at: 0)
        #expect(model.isSelected(0))
        #expect(!model.isHovered(0))
    }

    @Test
    func keyboardMovementMovesSelectWhilePreservingHover() {
        AppCursorVisibility.resetForTesting()
        let model = MenuHighlightModel()
        defer { model.close() }
        model.open(selectablePositions: [0, 1, 2])
        model.noteHover(true, at: 2)
        #expect(model.selectedPosition == 0)
        #expect(model.hoveredPosition == 2)

        model.moveHighlight(by: 1)
        #expect(model.selectedPosition == 1)
        #expect(model.hoveredPosition == 2)
        #expect(model.isSelected(1))
        #expect(model.isHovered(2))
    }

    @Test
    func wheelScrollingLocksHoverUntilDebounceSettlesOrPointerMoves() {
        AppCursorVisibility.resetForTesting()
        let model = MenuHighlightModel()
        defer { model.close() }
        model.open(selectablePositions: [0, 1, 2])
        model.noteHover(true, at: 1)
        #expect(model.hoveredPosition == 1)

        // The wheel slides rows under a stationary pointer; Hover stays locked
        // during scrolling.
        model.noteScrolled()
        model.noteHover(false, at: 1)
        model.noteHover(true, at: 2)
        #expect(model.hoveredPosition == 1)

        // Settling after the 300ms scroll debounce updates Hover to the row
        // now under the pointer.
        model.noteScrollSettled()
        #expect(model.hoveredPosition == 2)
    }

    @Test
    func onlyKeyboardMovesAnnounceThemselvesForScrollFollowing() {
        let model = MenuHighlightModel()
        defer { model.close() }
        model.open(selectablePositions: [0, 1])
        #expect(model.keyboardMoveCount == 0)

        model.moveHighlight(by: 1)
        #expect(model.keyboardMoveCount == 1)

        // Wheel and hover movement have nothing to reveal.
        model.noteScrolled()
        model.notePointerMoved()
        model.noteHover(true, at: 0)
        #expect(model.keyboardMoveCount == 1)
    }

    @Test
    func hoverOnAnUnselectablePositionIsIgnored() {
        AppCursorVisibility.resetForTesting()
        let model = MenuHighlightModel()
        defer { model.close() }
        model.open(selectablePositions: [0, 2])

        model.noteHover(true, at: 1)
        #expect(model.hoveredPosition == nil)
        model.noteHover(true, at: 2)
        #expect(model.hoveredPosition == 2)
    }

    @Test
    func keyboardMovementNeverHidesTheCursor() {
        AppCursorVisibility.resetForTesting()
        let model = MenuHighlightModel()
        defer {
            model.close()
            AppCursorVisibility.resetForTesting()
        }
        model.open(selectablePositions: [0, 1])
        #expect(!AppCursorVisibility.isCursorHidden)

        model.moveHighlight(by: 1)
        #expect(!AppCursorVisibility.isCursorHidden)

        model.notePointerMoved()
        #expect(!AppCursorVisibility.isCursorHidden)
    }

    @Test
    func closingClearsTheHighlight() {
        let model = MenuHighlightModel()
        model.open(selectablePositions: [0, 1])
        model.moveHighlight(by: 1)
        #expect(model.isOpen)

        model.close()

        #expect(!model.isOpen)
        #expect(model.highlightedPosition == nil)
    }

    @Test
    func speedMenuOpensOnTheSpeedInEffectAndTheHighlightMovesOffIt() {
        let presets = PlaybackViewModel.speedPresets
        #expect(PlaybackViewModel.speedPresetIndex(for: 1.0) == 2)
        #expect(PlaybackViewModel.speedPresetIndex(for: 1.75) == 5)
        #expect(PlaybackViewModel.speedPresetIndex(for: 1.3) == nil)

        let model = MenuHighlightModel()
        defer { model.close() }
        model.open(
            selectablePositions: Array(presets.indices),
            defaultPosition: PlaybackViewModel.speedPresetIndex(for: 1.5)
        )
        #expect(model.highlightedPosition == 4)

        // The check mark stays on 1.5x while the highlight moves away, so the
        // menu can show the value in effect and the current item separately.
        model.moveHighlight(by: 1)
        #expect(model.highlightedPosition == 5)
        #expect(PlaybackViewModel.speedPresetIndex(for: 1.5) == 4)

        // An unrecognised speed falls back to the first preset.
        model.open(
            selectablePositions: Array(presets.indices),
            defaultPosition: PlaybackViewModel.speedPresetIndex(for: 1.3)
        )
        #expect(model.highlightedPosition == 0)
    }

    @Test
    func aParentMenuAndItsSubmenuBothLeaveTheCursorAlone() {
        AppCursorVisibility.resetForTesting()
        let parent = MenuHighlightModel()
        let submenu = MenuHighlightModel()
        defer {
            parent.close()
            submenu.close()
            AppCursorVisibility.resetForTesting()
        }
        parent.open(selectablePositions: [0, 1])
        parent.moveHighlight(by: 1)
        submenu.open(selectablePositions: [0, 1])
        submenu.moveHighlight(by: 1)
        #expect(!AppCursorVisibility.isCursorHidden)

        submenu.close()
        #expect(!AppCursorVisibility.isCursorHidden)
    }
}
