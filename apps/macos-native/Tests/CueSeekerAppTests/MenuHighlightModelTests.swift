import Testing
@testable import CueSeekerApp

@Suite(.serialized)
@MainActor
struct MenuHighlightModelTests {
    @Test
    func openStartsWithNoHighlightedItemByDefault() {
        AppCursorVisibility.resetForTesting()
        let model = MenuHighlightModel()
        defer { model.close() }

        // Positions 1 and 4 stand for a divider and a disabled item.
        model.open(selectablePositions: [0, 2, 3, 5], defaultPosition: 2)

        #expect(model.highlightedPosition == nil)
        #expect(model.selectedPosition == nil)
        #expect(model.hoveredPosition == nil)
    }

    @Test
    func firstUpSelectsLastAndFirstDownSelectsFirstWhenNothingIsHighlighted() {
        AppCursorVisibility.resetForTesting()
        let model = MenuHighlightModel()
        defer { model.close() }

        model.open(selectablePositions: [0, 2, 3, 5])
        #expect(model.highlightedPosition == nil)

        // Pressing Up when nothing is highlighted selects the bottommost item.
        #expect(model.moveHighlight(by: -1))
        #expect(model.highlightedPosition == 5)

        // Reopen with nothing highlighted; pressing Down selects the topmost item.
        model.open(selectablePositions: [0, 2, 3, 5])
        #expect(model.highlightedPosition == nil)
        #expect(model.moveHighlight(by: 1))
        #expect(model.highlightedPosition == 0)
    }

    @Test
    func arrowMovementSkipsUnselectablePositionsAndStopsAtBothEnds() {
        AppCursorVisibility.resetForTesting()
        let model = MenuHighlightModel()
        defer { model.close() }
        model.open(selectablePositions: [0, 2, 3, 5])

        #expect(model.moveHighlight(by: 1))
        #expect(model.highlightedPosition == 0)
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
    func hoverAndSelectAreUnifiedAndKeyboardMovementSuppressesHoverUntilPointerMoves() {
        AppCursorVisibility.resetForTesting()
        defer { AppCursorVisibility.resetForTesting() }
        let model = MenuHighlightModel()
        defer { model.close() }
        model.open(selectablePositions: [0, 1, 2])

        // Hovering item 2 sets the unified highlight on 2.
        model.noteHover(true, at: 2)
        #expect(model.highlightedPosition == 2)
        #expect(model.selectedPosition == 2)
        #expect(model.hoveredPosition == 2)
        #expect(model.isSelected(2))
        #expect(model.isHovered(2))

        // Moving with the keyboard moves the unified highlight from 2 to 1 and
        // immediately clears 2's highlight, suppressing pointer hover until the
        // mouse actually moves.
        model.moveHighlight(by: -1)
        #expect(model.highlightedPosition == 1)
        #expect(!model.isSelected(2))
        #expect(!model.isHovered(2))
        #expect(PointerHoverScrollState.shared.isHoverSuppressed)

        // Stationary hover reports while suppressed do not override the keyboard highlight.
        model.noteHover(false, at: 2)
        model.noteHover(true, at: 0)
        #expect(model.highlightedPosition == 1)

        // Wheel scroll debounce settling while suppressed by keyboard still keeps
        // the keyboard highlight until the pointer moves.
        PointerHoverScrollState.shared.noteScrolled()
        PointerHoverScrollState.shared.settleScroll()
        #expect(PointerHoverScrollState.shared.isHoverSuppressed)
        #expect(model.highlightedPosition == 1)

        // Once the pointer actually moves, hover resumes at the pointer's item.
        PointerHoverScrollState.shared.notePointerMoved()
        #expect(!PointerHoverScrollState.shared.isHoverSuppressed)
        #expect(model.highlightedPosition == 0)
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
        AppCursorVisibility.resetForTesting()
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
        AppCursorVisibility.resetForTesting()
        let model = MenuHighlightModel()
        model.open(selectablePositions: [0, 1])
        model.moveHighlight(by: 1)
        #expect(model.isOpen)

        model.close()

        #expect(!model.isOpen)
        #expect(model.highlightedPosition == nil)
    }

    @Test
    func speedMenuCheckmarkIndexIsIndependentOfPopupHighlight() {
        AppCursorVisibility.resetForTesting()
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
        #expect(model.highlightedPosition == nil)

        // Pressing Down highlights the first item (0), while the checkmark on
        // 1.5x (index 4) remains determined by speedPresetIndex.
        model.moveHighlight(by: 1)
        #expect(model.highlightedPosition == 0)
        #expect(PlaybackViewModel.speedPresetIndex(for: 1.5) == 4)
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

    @Test
    func windowResignFocusClearsPointerHoverHighlight() {
        AppCursorVisibility.resetForTesting()
        let model = MenuHighlightModel()
        defer { model.close() }
        model.open(selectablePositions: [0, 1, 2])
        model.noteHover(true, at: 2)
        #expect(model.highlightedPosition == 2)

        model.noteWindowDidResignFocus()
        #expect(model.highlightedPosition == nil)
    }
}
