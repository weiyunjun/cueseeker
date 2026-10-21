import Testing
@testable import CueSeekerApp

// Covers the unified pointer shape rules in
// `docs/human/requirements/20261021-UI-Separate Hover And Select States And Unify Pointer Rules.md`.

@Test
func pointerMovementDecidesTheShapeFromWhatIsUnderThePointer() {
    var model = PointerShapeModel()
    #expect(model.pointerMoved(over: .grab, isMenuOpen: false) == .grab)
    #expect(model.pointerMoved(over: .iBeam, isMenuOpen: false) == .iBeam)
    #expect(model.pointerMoved(over: .arrow, isMenuOpen: false) == .arrow)
    // Stated again even when unchanged, so a shape AppKit put back on its own
    // is corrected by the next movement.
    #expect(model.pointerMoved(over: .arrow, isMenuOpen: false) == .arrow)
}

@Test
func wheelScrollingLeavesTheShapeLockedUntilHoverSettles() {
    var model = PointerShapeModel()
    _ = model.pointerMoved(over: .grab, isMenuOpen: false)
    #expect(model.cardHover(true, id: "card", showsHand: true, followsPointer: false) == false)
    #expect(model.shape == .grab)
    #expect(model.cardHover(false, id: "card", showsHand: true, followsPointer: false) == false)
    #expect(model.shape == .grab)
}

@Test
func menuResetsToArrowAndMovementUnderItDecidesNothing() {
    var model = PointerShapeModel()
    _ = model.pointerMoved(over: .iBeam, isMenuOpen: false)
    #expect(model.reset() == .arrow)
    #expect(model.pointerMoved(over: .grab, isMenuOpen: true) == nil)
    #expect(model.shape == .arrow)
    #expect(model.pointerMoved(over: .grab, isMenuOpen: false) == .grab)
}

@Test
func pointerShapeFollowsCardHoverDirectlyWithoutResettingOnKeyboardSelectionChange() {
    var model = PointerShapeModel()
    let entered = model.cardHover(true, id: "card", showsHand: true, followsPointer: true)
    #expect(entered)
    #expect(model.pointerMoved(over: .arrow, isMenuOpen: false) == .grab)
    #expect(model.shape == .grab)

    let left = model.cardHover(false, id: "card", showsHand: true, followsPointer: true)
    #expect(left)
    #expect(model.pointerMoved(over: .arrow, isMenuOpen: false) == .arrow)
}

@Test
func cardWithoutHandAndCardLeftByThePointerAnswerTheSurface() {
    var model = PointerShapeModel()
    _ = model.cardHover(true, id: "disabled", showsHand: false, followsPointer: true)
    #expect(model.pointerMoved(over: .arrow, isMenuOpen: false) == .arrow)
    _ = model.cardHover(true, id: "card", showsHand: true, followsPointer: true)
    #expect(model.pointerMoved(over: .arrow, isMenuOpen: false) == .grab)
    let left = model.cardHover(false, id: "card", showsHand: true, followsPointer: true)
    #expect(left)
    #expect(model.pointerMoved(over: .arrow, isMenuOpen: false) == .arrow)
}
