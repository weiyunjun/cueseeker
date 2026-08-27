import AppKit

/// What still reaches the interface while a menu is open.
///
/// The modality used to be a sum of promises: the gate forwarded the four event
/// types it knew about, and every surface underneath was expected to ask, on
/// its own, whether a menu was open before answering the pointer. A surface
/// that forgot — or one written later — answered anyway, which is how a search
/// field kept taking keystrokes and an I-beam kept appearing under an open
/// menu.
///
/// So the question is answered here instead, once, where events enter the App:
/// while a menu is open, everything that did not land on it is spent, and only
/// what the design names as an exception travels on. A control added later
/// cannot opt out of a message it never receives.
///
/// See `docs/human/requirements/20260826-UI-Menu Modality Input Barrier And
/// Focus Cancellation.md`.
enum MenuInputBarrier {
    /// Pointer motion and cursor updates. Only the menu sees them, so nothing
    /// underneath lights up and nothing states a cursor shape of its own — the
    /// arrow set when the menu opened stays.
    ///
    /// A drag that began on the menu keeps its events wherever the pointer
    /// travels, the way dragging a scrollbar thumb past its track does.
    ///
    /// A crossing into or out of a tracking area always travels on, because it
    /// is not input at all: it is how AppKit records which areas the pointer is
    /// inside, and that record is only ever written when the crossing is
    /// delivered. Spending one leaves the window believing the pointer is
    /// somewhere it is not, and AppKit then stops sending that area any motion
    /// — for good, because the correction it is waiting for is the very
    /// crossing it never saw. Leaving the App with a menu open and coming back
    /// with the pointer elsewhere produces exactly one such crossing, which is
    /// how the whole interface stopped answering the pointer and stayed that
    /// way after the menu had closed.
    ///
    /// Nothing underneath lights up from a crossing either: the freeze is what
    /// holds those surfaces still, and every one of them already asks it before
    /// acting.
    ///
    /// See `docs/human/requirements/20260827-Bug-Menu Hover Dies After
    /// Switching Apps.md`.
    static func passesPointerTracking(
        isTrackingAreaCrossing: Bool,
        isFromAnotherWindow: Bool,
        isPointerOnMenu: Bool,
        isTrackingMenuDrag: Bool
    ) -> Bool {
        isTrackingAreaCrossing || isFromAnotherWindow || isPointerOnMenu
            || isTrackingMenuDrag
    }

    /// The button events that must never close the menu: every release, and the
    /// middle press the design leaves alone. Outside the menu they are spent,
    /// so nothing underneath completes a click it never began.
    static func passesNonDismissingButton(
        isFromAnotherWindow: Bool,
        isPointerOnMenu: Bool,
        isPointerOnAnchorControl: Bool,
        isTrackingMenuDrag: Bool
    ) -> Bool {
        isFromAnotherWindow || isPointerOnMenu || isPointerOnAnchorControl
            || isTrackingMenuDrag
    }

    /// A key the open menus did not spend. Shortcuts are unaffected by an open
    /// menu, so they travel on; a plain key stops here rather than reaching
    /// whatever holds focus — and rather than drawing the beep an unhandled key
    /// would earn now that the menu cancelled the focus.
    static func passesKey(
        isFromAnotherWindow: Bool,
        isShortcut: Bool
    ) -> Bool {
        isFromAnotherWindow || isShortcut
    }
}
