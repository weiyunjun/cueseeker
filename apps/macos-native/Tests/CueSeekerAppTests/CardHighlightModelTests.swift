import Testing
@testable import CueSeekerApp

/// Covers `docs/human/requirements/20261021-UI-Separate Hover And Select States
/// And Unify Pointer Rules.md` for cover card `Hover` and `Select` states.
@Suite(.serialized)
@MainActor
struct CardHighlightModelTests {
    private func workbench() -> CardHighlightModel {
        CardHighlightModel(keepsCurrentWhenPointerLeaves: false)
    }

    private func playback() -> CardHighlightModel {
        CardHighlightModel(keepsCurrentWhenPointerLeaves: true)
    }

    @Test
    func hoverUpdatesImmediatelyWhenCursorIsVisibleAndHidesWhenCursorIsHidden() {
        AppCursorVisibility.resetForTesting()
        defer { AppCursorVisibility.resetForTesting() }

        let model = workbench()
        model.noteHover(true, id: "a")
        #expect(model.hoveredID == "a")
        #expect(model.isHovered("a"))
        #expect(!model.isSelected("a"))

        // Hiding the cursor suppresses Hover while remembering the raw card
        // under the pointer.
        AppCursorVisibility.setHidden(true)
        let hiddenModel = playback()
        hiddenModel.setSelected("a")
        hiddenModel.noteHover(true, id: "b")
        #expect(hiddenModel.selectedID == "a")
        #expect(hiddenModel.hoveredID == nil)
        #expect(!hiddenModel.isHovered("b"))
    }

    @Test
    func selectVisualStyleTakesPriorityOverHoverWithoutStacking() {
        AppCursorVisibility.resetForTesting()
        let model = playback()
        model.setSelected("a")
        model.noteHover(true, id: "b")

        #expect(model.isSelected("a"))
        #expect(!model.isHovered("a"))
        #expect(model.isHovered("b"))
        #expect(!model.isSelected("b"))
        #expect(model.isHighlighted("a"))
        #expect(model.isHighlighted("b"))

        // When Hover and Select sit on the same card, only Select is shown.
        model.noteHover(false, id: "b")
        model.noteHover(true, id: "a")
        #expect(model.isSelected("a"))
        #expect(!model.isHovered("a"))
        #expect(model.isHighlighted("a"))
    }

    @Test
    func wheelScrollingLocksHoverUntilDebounceSettlesOrPointerMoves() {
        AppCursorVisibility.resetForTesting()
        let model = workbench()
        model.noteHover(true, id: "a")
        #expect(model.hoveredID == "a")

        // Scrolling slides another card under a stationary pointer; Hover stays
        // locked during the scroll.
        model.noteScrolled()
        model.noteHover(false, id: "a")
        model.noteHover(true, id: "b")
        #expect(model.hoveredID == "a")

        // Once the 300ms scroll debounce settles, Hover updates to the card
        // now under the pointer.
        model.noteScrollSettled()
        #expect(model.hoveredID == "b")

        // Physical pointer movement during scrolling also immediately updates.
        model.noteScrolled()
        model.noteHover(false, id: "b")
        model.noteHover(true, id: "c")
        #expect(model.hoveredID == "b")
        model.notePointerMoved()
        #expect(model.hoveredID == "c")
    }

    @Test
    func leavingCardClearsHoverWhilePreservingSelect() {
        AppCursorVisibility.resetForTesting()
        let workbenchModel = workbench()
        workbenchModel.noteHover(true, id: "a")
        workbenchModel.noteHover(false, id: "a")
        #expect(workbenchModel.hoveredID == nil)

        let playbackModel = playback()
        playbackModel.setSelected("a")
        playbackModel.noteHover(true, id: "b")
        playbackModel.noteHover(false, id: "b")
        #expect(playbackModel.hoveredID == nil)
        #expect(playbackModel.selectedID == "a")
    }

    @Test
    func rightClickPressUpdatesHoverOnlyAndNeverChangesSelect() {
        AppCursorVisibility.resetForTesting()
        let model = playback()
        model.setSelected("a")
        model.notePress(id: "b")
        #expect(model.selectedID == "a")
        #expect(model.hoveredID == "b")
    }

    @Test
    func unfreezingImmediatelyReevaluatesHoverFromCurrentPointerLocation() {
        AppCursorVisibility.resetForTesting()
        let model = workbench()
        model.notePress(id: "a")
        model.setFrozen(true)

        // While the menu is open, the pointer moves to card "b".
        model.noteHover(false, id: "a")
        model.noteHover(true, id: "b")
        #expect(model.hoveredID == "a")

        // Closing the menu unfreezes the layer and immediately updates Hover to
        // card "b" without waiting for another mouse move.
        model.setFrozen(false)
        #expect(model.hoveredID == "b")
    }

    @Test
    func unfreezingAfterPointerLeftAllCardsClearsHoverImmediately() {
        AppCursorVisibility.resetForTesting()
        let model = workbench()
        model.notePress(id: "a")
        model.setFrozen(true)
        model.noteHover(false, id: "a")
        #expect(model.hoveredID == "a")

        model.setFrozen(false)
        #expect(model.hoveredID == nil)
    }

    @Test
    func keyboardSelectionChangesDoNotAffectHover() {
        AppCursorVisibility.resetForTesting()
        let model = playback()
        model.setSelected("a")
        model.noteHover(true, id: "b")
        #expect(model.selectedID == "a")
        #expect(model.hoveredID == "b")

        model.setSelected("c")
        #expect(model.selectedID == "c")
        #expect(model.hoveredID == "b")
    }

    @Test
    func resetClearsSelectAndHoverForSubInterfaceSwitch() {
        AppCursorVisibility.resetForTesting()
        let model = playback()
        model.setSelected("a")
        model.noteHover(true, id: "b")

        model.reset()
        #expect(model.selectedID == nil)
        #expect(model.hoveredID == nil)
    }
}
