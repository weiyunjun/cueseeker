import Testing
@testable import CueSeekerApp

/// Covers `docs/human/requirements/20260826-UI-Card Highlight Single Authority
/// And Menu Input Rules.md` §8.1 for every surface that is not a card: while a
/// menu is open over its layer, or a higher layer covers it, the surface stops
/// answering the pointer.
struct PointerHoverGateTests {
    @Test
    func anActiveSurfaceIsToldWhatThePointerDid() {
        var gate = PointerHoverGate()

        #expect(gate.report(true, isFrozen: false) == true)
        #expect(gate.report(false, isFrozen: false) == false)
    }

    @Test
    func nothingIsSaidTwice() {
        var gate = PointerHoverGate()
        #expect(gate.report(true, isFrozen: false) == true)

        // A repeat of what the surface is already painting says nothing.
        #expect(gate.report(true, isFrozen: false) == nil)
        #expect(gate.freezeChanged(isFrozen: false) == nil)
    }

    @Test
    func aFrozenSurfaceIsToldNothingAndKeepsItsPicture() {
        var gate = PointerHoverGate()

        #expect(gate.report(true, isFrozen: true) == nil)
        #expect(gate.report(false, isFrozen: true) == nil)
    }

    @Test
    func whereThePointerEndedUpIsDeliveredWhenTheFreezeLifts() {
        var gate = PointerHoverGate()
        #expect(gate.report(true, isFrozen: false) == true)

        // A menu opens, and the pointer walks off the control while it is up.
        #expect(gate.freezeChanged(isFrozen: true) == nil)
        #expect(gate.report(false, isFrozen: true) == nil)

        // The menu closes: the control must not be left lit behind the pointer.
        #expect(gate.freezeChanged(isFrozen: false) == false)
    }

    @Test
    func aPointerThatCameBackToWhereItStartedChangesNothing() {
        var gate = PointerHoverGate()
        #expect(gate.report(true, isFrozen: false) == true)

        #expect(gate.freezeChanged(isFrozen: true) == nil)
        #expect(gate.report(false, isFrozen: true) == nil)
        #expect(gate.report(true, isFrozen: true) == nil)

        #expect(gate.freezeChanged(isFrozen: false) == nil)
    }
}
