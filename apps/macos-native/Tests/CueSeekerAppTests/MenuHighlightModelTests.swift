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
    func hoverAndSelectAreUnifiedAndKeyboardNavigationSuppressesStationaryPointerHover() {
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

        // Keyboard Up/Down moves the unified highlight from 2 to 1 and suppresses
        // stationary pointer hover on 2.
        model.moveHighlight(by: -1)
        #expect(model.highlightedPosition == 1)
        #expect(model.isSuppressedByKeyboard)
        #expect(model.isSelected(1))
        #expect(!model.isSelected(2))
        #expect(!model.isHovered(2))

        // While suppressed, a stationary pointer hover event does not steal the highlight.
        model.noteHover(true, at: 2)
        #expect(model.highlightedPosition == 1)

        // Moving the mouse unsuppresses hover and updates the unified highlight to 2.
        model.notePointerMoved()
        #expect(!model.isSuppressedByKeyboard)
        #expect(model.highlightedPosition == 2)
    }

    @Test
    func accessibilityTabWrapsIncludesDisabledItemsAndKeepsFocusRingWhenMouseMovesUnifiedHighlight() {
        AppCursorVisibility.resetForTesting()
        let model = MenuHighlightModel()
        defer { model.close() }
        // Position 1 is a disabled item; position 2 is a divider (not in allPositions).
        model.open(selectablePositions: [0, 3], allPositions: [0, 1, 3])
        #expect(!model.isAccessibilityActive)

        // First Tab enters accessibility on item 0 (enabled) and syncs unified highlight.
        #expect(model.moveAccessibility(forward: true))
        #expect(model.accessibilityPosition == 0)
        #expect(model.highlightedPosition == 0)
        #expect(model.isAccessibilityFocused(0))
        #expect(model.isSelected(0))

        // Next Tab lands on item 1 (disabled): focus ring only, unified highlight cleared.
        #expect(model.moveAccessibility(forward: true))
        #expect(model.accessibilityPosition == 1)
        #expect(model.highlightedPosition == nil)
        #expect(model.activeTriggerPosition == nil)
        #expect(model.isAccessibilityFocused(1))
        #expect(!model.isSelected(1))

        // Next Tab skips divider 2 and lands on item 3 (enabled), syncing unified highlight.
        #expect(model.moveAccessibility(forward: true))
        #expect(model.accessibilityPosition == 3)
        #expect(model.highlightedPosition == 3)

        // Moving the mouse to item 0 without clicking moves the unified highlight to 0
        // while keeping the accessibility focus ring and trigger target on item 3.
        model.notePointerMoved()
        model.noteHover(true, at: 0)
        #expect(model.highlightedPosition == 0)
        #expect(model.accessibilityPosition == 3)
        #expect(model.activeTriggerPosition == 3)

        // Next Tab wraps around from accessibility item 3 to item 0 and suppresses pointer hover.
        #expect(model.moveAccessibility(forward: true))
        #expect(model.accessibilityPosition == 0)
        #expect(model.highlightedPosition == 0)
        #expect(model.isSuppressedByKeyboard)

        // Shift+Tab wraps backward to item 3.
        #expect(model.moveAccessibility(forward: false))
        #expect(model.accessibilityPosition == 3)
        #expect(model.highlightedPosition == 3)

        // Arrow Up while accessibility is active moves unified highlight to item 0 and
        // pulls the accessibility focus ring along with it.
        #expect(model.moveHighlight(by: -1))
        #expect(model.highlightedPosition == 0)
        #expect(model.accessibilityPosition == 0)

        // First Esc clears accessibility while keeping unified highlight on item 0.
        #expect(model.clearAccessibility())
        #expect(!model.isAccessibilityActive)
        #expect(model.highlightedPosition == 0)
        #expect(!model.clearAccessibility())
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
        #expect(presets == [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 3.0])
        #expect(PlaybackViewModel.maximumPlaybackSpeed == 3.0)
        #expect(PlaybackViewModel.speedPresetIndex(for: 1.0) == 2)
        #expect(PlaybackViewModel.speedPresetIndex(for: 1.75) == 5)
        #expect(PlaybackViewModel.speedPresetIndex(for: 3.0) == 7)
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
        #expect(model.hoveredPosition == 2)

        model.noteWindowDidResignFocus()
        #expect(model.hoveredPosition == nil)
    }
}
