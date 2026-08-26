import Testing
@testable import CueSeekerApp

/// Covers `docs/human/requirements/20260826-UI-Menu Modality Input Barrier And
/// Focus Cancellation.md` §2: while a menu is open, what did not land on it
/// never reaches the interface underneath, and only the exceptions the design
/// names travel on.
struct MenuInputBarrierTests {
    @Test
    func pointerTrackingOutsideTheMenuStops() {
        #expect(MenuInputBarrier.passesPointerTracking(
            isFromAnotherWindow: false,
            isPointerOnMenu: false,
            isTrackingMenuDrag: false
        ) == false)
    }

    @Test
    func pointerTrackingOnTheMenuTravelsOn() {
        #expect(MenuInputBarrier.passesPointerTracking(
            isFromAnotherWindow: false,
            isPointerOnMenu: true,
            isTrackingMenuDrag: false
        ) == true)
    }

    @Test
    func aDragBegunOnTheMenuKeepsItsEventsOffTheMenu() {
        #expect(MenuInputBarrier.passesPointerTracking(
            isFromAnotherWindow: false,
            isPointerOnMenu: false,
            isTrackingMenuDrag: true
        ) == true)
    }

    @Test
    func anotherWindowIsNoneOfTheMenusBusiness() {
        #expect(MenuInputBarrier.passesPointerTracking(
            isFromAnotherWindow: true,
            isPointerOnMenu: false,
            isTrackingMenuDrag: false
        ) == true)
        #expect(MenuInputBarrier.passesNonDismissingButton(
            isFromAnotherWindow: true,
            isPointerOnMenu: false,
            isPointerOnAnchorControl: false,
            isTrackingMenuDrag: false
        ) == true)
        #expect(MenuInputBarrier.passesKey(
            isFromAnotherWindow: true,
            isShortcut: false
        ) == true)
    }

    @Test
    func aReleaseOutsideTheMenuIsSpentWithThePressItCompletes() {
        #expect(MenuInputBarrier.passesNonDismissingButton(
            isFromAnotherWindow: false,
            isPointerOnMenu: false,
            isPointerOnAnchorControl: false,
            isTrackingMenuDrag: false
        ) == false)
    }

    @Test
    func aReleaseOnTheControlThatTogglesTheMenuTravelsOn() {
        // The speed button toggles its own menu, so the press it began must be
        // allowed to finish on it.
        #expect(MenuInputBarrier.passesNonDismissingButton(
            isFromAnotherWindow: false,
            isPointerOnMenu: false,
            isPointerOnAnchorControl: true,
            isTrackingMenuDrag: false
        ) == true)
    }

    @Test
    func aPlainKeyStopsAtTheMenu() {
        // The search field underneath keeps its text: the keystroke never
        // arrives.
        #expect(MenuInputBarrier.passesKey(
            isFromAnotherWindow: false,
            isShortcut: false
        ) == false)
    }

    @Test
    func shortcutsAreUnaffectedByAnOpenMenu() {
        #expect(MenuInputBarrier.passesKey(
            isFromAnotherWindow: false,
            isShortcut: true
        ) == true)
    }
}

/// The per-menu behaviour the design's scroll table and key rules name, read
/// from the menu's kind instead of from four switches at each call site.
struct MenuGateKindTests {
    @Test
    func everyMenuButTheSpeedMenuBansWindowScrolling() {
        for kind in [
            MenuGate.Kind.tableRowMenu,
            .filterMenu,
            .cardMenu,
            .selectedTextMenu,
        ] {
            #expect(kind.bansScrolling)
        }
        #expect(MenuGate.Kind.playerSpeedMenu.bansScrolling == false)
    }

    @Test
    func theSpeedMenuTakesItsKeysFromThePlaybackRouterOnly() {
        #expect(MenuGate.Kind.playerSpeedMenu.receivesKeysFromMonitor == false)
        #expect(MenuGate.Kind.playerSpeedMenu.receivesKeysFromRouter)
    }

    @Test
    func onlyTheSelectedTextMenuKeepsTheSelectionItHangsOff() {
        #expect(MenuGate.Kind.selectedTextMenu.clearsTextSelection == false)
        for kind in [
            MenuGate.Kind.tableRowMenu,
            .filterMenu,
            .cardMenu,
            .playerSpeedMenu,
        ] {
            #expect(kind.clearsTextSelection)
        }
    }
}
