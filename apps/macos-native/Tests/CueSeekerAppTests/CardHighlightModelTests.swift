import Testing
@testable import CueSeekerApp

/// Covers `docs/human/requirements/20260826-UI-Card Highlight Single Authority
/// And Menu Input Rules.md` §3 to §8. Whether the highlight is actually painted
/// on one card at a time is accepted by hand; what is checked here is that the
/// interface can only ever be told about one.
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
    func anInterfaceStartsWithNothingLitAndIgnoresHoverUntilThePointerMoves() {
        let model = workbench()

        // Entering an interface under a stationary pointer reports hover
        // straight away; nothing may light from it.
        model.noteHover(true, id: "a")
        #expect(model.currentID == nil)

        // Real movement opens the gate and adopts the card already under the
        // pointer, without waiting for it to cross into another card.
        model.notePointerMoved()
        #expect(model.currentID == "a")
    }

    @Test
    func aWheelIsNotMovementAndCannotMoveTheHighlight() {
        let model = workbench()
        model.notePointerMoved()
        model.noteHover(true, id: "a")
        #expect(model.currentID == "a")

        // Scrolling slides another card under a pointer that stayed put.
        model.noteScrolled()
        model.noteHover(false, id: "a")
        model.noteHover(true, id: "b")
        #expect(model.currentID == "a")

        // Moving for real hands the highlight to where the pointer now is.
        model.notePointerMoved()
        #expect(model.currentID == "b")
    }

    @Test
    func onlyOneCardIsEverCurrent() {
        let model = workbench()
        model.notePointerMoved()

        model.noteHover(true, id: "a")
        model.noteHover(false, id: "a")
        model.noteHover(true, id: "b")
        #expect(model.currentID == "b")
    }

    @Test
    func workbenchLetsThePointerLeaveButPlaybackKeepsOneCardLit() {
        let workbenchModel = workbench()
        workbenchModel.notePointerMoved()
        workbenchModel.noteHover(true, id: "a")
        workbenchModel.noteHover(false, id: "a")
        #expect(workbenchModel.currentID == nil)

        let playbackModel = playback()
        playbackModel.notePointerMoved()
        playbackModel.noteHover(true, id: "a")
        playbackModel.noteHover(false, id: "a")
        #expect(playbackModel.currentID == "a")
    }

    @Test
    func aPressLightsItsCardWithoutWaitingForMovement() {
        let model = workbench()

        model.notePress(id: "a")
        #expect(model.currentID == "a")
    }

    @Test
    func aPressStillLandsWhileTheInterfaceIsFrozen() {
        let model = workbench()
        model.notePress(id: "a")
        model.setFrozen(true)

        // Right-clicking a second card closes the first card's menu and opens
        // its own on the same press, so the highlight travels with it.
        model.notePress(id: "b")
        #expect(model.currentID == "b")
    }

    @Test
    func aFrozenInterfaceKeepsItsPictureAndDropsPointerReports() {
        let model = workbench()
        model.notePointerMoved()
        model.noteHover(true, id: "a")
        model.setFrozen(true)

        model.noteHover(false, id: "a")
        model.noteHover(true, id: "b")
        model.notePointerMoved()
        #expect(model.currentID == "a")

        // Unfreezing does not replay what the pointer did meanwhile: it has to
        // move again first.
        model.setFrozen(false)
        #expect(model.currentID == "a")
        model.noteHover(true, id: "b")
        #expect(model.currentID == "a")
        model.notePointerMoved()
        #expect(model.currentID == "b")
    }

    @Test
    func aSelectionMovedAwayFromThePointerIsNotPulledBack() {
        let model = playback()
        model.notePointerMoved()
        model.noteHover(true, id: "a")
        #expect(model.currentID == "a")

        // The keyboard moves the selection; the card still under the stationary
        // pointer must not take it back.
        model.setCurrent("c")
        model.noteHover(true, id: "a")
        #expect(model.currentID == "c")

        // Moving the pointer for real gives it back.
        model.notePointerMoved()
        #expect(model.currentID == "a")
    }

    @Test
    func anInterfaceThatNavigatesElsewhereReceivesTheAdoptedCard() {
        let model = playback()
        var adopted: [String?] = []
        model.adopt = { adopted.append($0) }

        model.notePointerMoved()
        model.noteHover(true, id: "a")

        // The model did not decide: it handed the target to the interface's own
        // selection, which reports back through `setCurrent`.
        #expect(adopted == ["a"])
        #expect(model.currentID == nil)
        model.setCurrent("a")
        #expect(model.currentID == "a")
    }

    @Test
    func switchingInterfaceStartsOverWithNothingLit() {
        let model = workbench()
        model.notePointerMoved()
        model.noteHover(true, id: "a")
        #expect(model.currentID == "a")

        model.reset()
        #expect(model.currentID == nil)

        // The pointer has to move again before anything lights, so entering an
        // interface under the pointer lights nothing.
        model.noteHover(true, id: "b")
        #expect(model.currentID == nil)
        model.notePointerMoved()
        #expect(model.currentID == "b")
    }
}
