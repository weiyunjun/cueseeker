import AppKit
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
            MenuGate.Kind.cardMenu,
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
            .cardMenu,
            .playerSpeedMenu,
        ] {
            #expect(kind.clearsTextSelection)
        }
    }

    @MainActor
    @Test
    func rightClickInsideOpenMenuIsConsumedWithoutDismissingOrForwarding() {
        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 600, height: 400),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        let layers = InterfaceLayerRegistry()
        let gate = layers.menuGate
        var dismissedCount = 0
        let menuRect = CGRect(x: 100, y: 100, width: 180, height: 140)
        var session: MenuGate.Session?
        session = gate.open(MenuGate.Client(
            owner: .workbenchPage,
            kind: .cardMenu,
            window: { window },
            isPointerOnMenu: { event in menuRect.contains(event.locationInWindow) },
            handleKey: { _, _ in false },
            dismiss: { _ in
                dismissedCount += 1
                session?.close()
            }
        ))

        let insideRightClick = NSEvent.mouseEvent(
            with: .rightMouseDown,
            location: CGPoint(x: 140, y: 150),
            modifierFlags: [],
            timestamp: 0,
            windowNumber: window.windowNumber,
            context: nil,
            eventNumber: 1,
            clickCount: 1,
            pressure: 1
        )!
        #expect(gate.route(insideRightClick) == nil)
        #expect(dismissedCount == 0)
        #expect(gate.bansScrolling)

        session?.close()
    }

    @MainActor
    @Test
    func rightClickOutsideOpenMenuDismissesItAndForwardsToOpenNewMenu() {
        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 600, height: 400),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        let layers = InterfaceLayerRegistry()
        let gate = layers.menuGate
        var firstMenuDismissedForwarding: [Bool] = []
        let firstMenuRect = CGRect(x: 40, y: 300, width: 160, height: 120)
        var firstSession: MenuGate.Session?
        firstSession = gate.open(MenuGate.Client(
            owner: .workbenchPage,
            kind: .cardMenu,
            window: { window },
            isPointerOnMenu: { event in firstMenuRect.contains(event.locationInWindow) },
            handleKey: { _, _ in false },
            dismiss: { forwarding in
                firstMenuDismissedForwarding.append(forwarding)
                firstSession?.close()
            }
        ))

        let cardRightClick = NSEvent.mouseEvent(
            with: .rightMouseDown,
            location: CGPoint(x: 320, y: 180),
            modifierFlags: [],
            timestamp: 0,
            windowNumber: window.windowNumber,
            context: nil,
            eventNumber: 2,
            clickCount: 1,
            pressure: 1
        )!
        let routed = gate.route(cardRightClick)
        #expect(routed === cardRightClick)
        #expect(firstMenuDismissedForwarding == [true])
        #expect(!gate.bansScrolling)

        let secondSession = gate.open(MenuGate.Client(
            owner: .workbenchPage,
            kind: .cardMenu,
            window: { window },
            isPointerOnMenu: { _ in false },
            handleKey: { _, _ in false },
            dismiss: { _ in }
        ))
        #expect(gate.bansScrolling)
        secondSession.close()
        #expect(!gate.bansScrolling)
    }
}
