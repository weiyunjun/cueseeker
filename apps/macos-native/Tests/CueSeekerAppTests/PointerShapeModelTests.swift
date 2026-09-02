import Testing
@testable import CueSeekerApp

// The event sequences of `docs/human/requirements/20260902-UI-Pointer Shape
// Follows Pointer Movement.md`, 规则解释 4, driven through the decision alone.

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

// Scenario 1: the wheel under a hand, and a card that slid under a still
// pointer, change nothing.
@Test
func wheelAndSlidInHoverLeaveTheShapeAlone() {
    var model = PointerShapeModel()
    _ = model.pointerMoved(over: .grab, isMenuOpen: false)
    #expect(model.cardHover(true, id: "card", showsHand: true, followsPointer: false) == false)
    #expect(model.shape == .grab)
    #expect(model.cardHover(false, id: "card", showsHand: true, followsPointer: false) == false)
    #expect(model.shape == .grab)
}

// Scenarios 2 and 4: a menu opening puts the arrow back, movement under the
// menu decides nothing, and after it closes the arrow stays until a movement.
@Test
func menuResetsToArrowAndMovementUnderItDecidesNothing() {
    var model = PointerShapeModel()
    _ = model.pointerMoved(over: .iBeam, isMenuOpen: false)
    #expect(model.reset() == .arrow)
    #expect(model.pointerMoved(over: .grab, isMenuOpen: true) == nil)
    #expect(model.shape == .arrow)
    #expect(model.pointerMoved(over: .grab, isMenuOpen: false) == .grab)
}

// Scenario 3: a key or the wheel is not an input; the I-beam also survives a
// highlight moved by the keyboard.
@Test
func iBeamSurvivesKeyboardNavigation() {
    var model = PointerShapeModel()
    _ = model.pointerMoved(over: .iBeam, isMenuOpen: false)
    #expect(model.handTargetChanged() == nil)
    #expect(model.shape == .iBeam)
}

// Scenarios 5 and 6: an interface switch puts the arrow back even with a card
// under the pointer; the next movement gives the card its hand.
@Test
func interfaceSwitchResetsEvenOverACard() {
    var model = PointerShapeModel()
    _ = model.pointerMoved(over: .iBeam, isMenuOpen: false)
    _ = model.cardHover(true, id: "card", showsHand: true, followsPointer: false)
    #expect(model.reset() == .arrow)
    #expect(model.shape == .arrow)
    #expect(model.pointerMoved(over: .arrow, isMenuOpen: false) == .grab)
}

// Scenario 7: the keyboard moves the highlight off the card under the pointer
// and the hand goes with it; the next movement, still on the card, brings it
// back.
@Test
func handFollowsTheHighlightAwayAndComesBackWithMovement() {
    var model = PointerShapeModel()
    let entered = model.cardHover(true, id: "card", showsHand: true, followsPointer: true)
    #expect(entered)
    #expect(model.pointerMoved(over: .arrow, isMenuOpen: false) == .grab)
    #expect(model.handTargetChanged() == .arrow)
    #expect(model.shape == .arrow)
    #expect(model.pointerMoved(over: .arrow, isMenuOpen: false) == .grab)
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
