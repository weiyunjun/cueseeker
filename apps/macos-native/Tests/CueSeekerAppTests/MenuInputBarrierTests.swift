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
            isTrackingAreaCrossing: false,
            isFromAnotherWindow: false,
            isPointerOnMenu: false,
            isTrackingMenuDrag: false
        ) == false)
    }

    @Test
    func pointerTrackingOnTheMenuTravelsOn() {
        #expect(MenuInputBarrier.passesPointerTracking(
            isTrackingAreaCrossing: false,
            isFromAnotherWindow: false,
            isPointerOnMenu: true,
            isTrackingMenuDrag: false
        ) == true)
    }

    @Test
    func aDragBegunOnTheMenuKeepsItsEventsOffTheMenu() {
        #expect(MenuInputBarrier.passesPointerTracking(
            isTrackingAreaCrossing: false,
            isFromAnotherWindow: false,
            isPointerOnMenu: false,
            isTrackingMenuDrag: true
        ) == true)
    }

    @Test
    func aTrackingAreaCrossingTravelsOnWhereverItLanded() {
        // It is AppKit's own record of where the pointer is, not input. A
        // window that never hears a crossing stops sending that area motion,
        // and the loss outlives the menu that spent it.
        #expect(MenuInputBarrier.passesPointerTracking(
            isTrackingAreaCrossing: true,
            isFromAnotherWindow: false,
            isPointerOnMenu: false,
            isTrackingMenuDrag: false
        ) == true)
    }

    @Test
    func anotherWindowIsNoneOfTheMenusBusiness() {
        #expect(MenuInputBarrier.passesPointerTracking(
            isTrackingAreaCrossing: false,
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

/// The per-menu behaviour the design's key rules name, read from the menu's
/// kind instead of from switches at each call site.
struct MenuGateKindTests {
    /// 菜单模态 6: any open menu bans scrolling for the whole window, the speed
    /// menu included.
    @MainActor
    @Test
    func everyOpenMenuBansWindowScrolling() {
        let layers = InterfaceLayerRegistry()
        let gate = layers.menuGate
        #expect(!gate.bansScrolling)
        let session = gate.open(MenuGate.Client(
            owner: .playbackPage,
            kind: .playerSpeedMenu,
            window: { nil },
            isPointerOnMenu: { _ in false },
            handleKey: { _, _ in false },
            dismiss: { _ in }
        ))
        #expect(gate.bansScrolling)
        session.close()
        #expect(!gate.bansScrolling)
    }

    @Test
    func thePlaybackRouterOffersKeysToEveryMenuButTheTableRowMenu() {
        #expect(MenuGate.Kind.tableRowMenu.receivesKeysFromRouter == false)
        for kind in [
            MenuGate.Kind.filterMenu,
            .cardMenu,
            .selectedTextMenu,
            .playerSpeedMenu,
            .excerptDestinationMenu,
        ] {
            #expect(kind.receivesKeysFromRouter)
        }
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
