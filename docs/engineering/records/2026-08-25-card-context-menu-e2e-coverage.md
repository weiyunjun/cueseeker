# Card context menu E2E coverage

Human-owned documents:

- `docs/human/requirements/20260825-Engineering-Card Context Menu E2E Coverage.md`
- `docs/human/requirements/20260825-UI-Menu Modality And Layer Input Ownership.md`

## Why

The card and cover right-click menus were the one menu family no automated run
could open. A card only listened for the right button while it reported SwiftUI
hover, so the automation had to make the card believe a pointer was resting on
it before it would answer at all. Every rule the menu family had to obey —
the scroll ban, the frozen surface below, the anchor staying lit — therefore
ended in "verify by hand", and the previous requirement wrote that exemption
into its acceptance.

The requirement removes the precondition: a card decides a right-click by where
the press landed, not by where the pointer has been.

## What changed

### The card answers for its own rectangle

The hover condition is gone from the trigger. The card's monitor was already
asking "is this press inside me"; that question is now the whole test, so a
right-click opens the menu whether or not a pointer visited the card first.

Dropping the condition widened who is listening: every visible card now has a
monitor installed instead of only the hovered one. Two consequences had to be
handled rather than inherited.

The first is layering. Hover used to imply "nothing is covering this page",
because a covered card stops taking hover. Without it, a card would have
answered a press made on top of an open dialog. The trigger now reads the same
covered-layer flag the cards already use to freeze their highlight, so a page
under a dialog stays silent — the rule the accepted menu requirement states for
every layer.

The second is clipping, and it is where the first attempt was wrong. The obvious
"is the press inside me" test — the view's own bounds — accepts presses made on
a card the page has scrolled out of sight, because the card's rectangle can still
extend under the toolbar. The fix reached for the view's visible rectangle
instead, on the assumption that AppKit clamps it to the view. It does not: for
these cards it reports the whole scroll viewport expressed in the card's own
coordinates, a rectangle far larger than the card. The first-created card
therefore accepted every right-click in the window, opened its own menu at the
press location — so the menu still looked right — and lit itself instead of the
card the reader had aimed at. Acting on that menu would have acted on the wrong
folder or video.

The test is now the intersection of the two: the part of the card that is both
inside the card and not clipped away. A visible card answers, a scrolled-away
card does not, and the card that answers is the card under the press.

Files: `TableSandbox/WorkbenchTestLibraryView.swift`,
`Shiori/ShioriListOverviewView.swift`.

## Verification

- `swift build`
- `swift test --filter CueSeekerAppTests --no-parallel` — 714 tests, the same
  four failures as before the change and for the same unrelated reasons
  (two localization assertions that expect English while the App runs in
  Chinese, one user-defaults migration assertion, two one-second waits in the
  refresh-scope integration suite).

Debug in-app E2E against the running App, main window `1445 × 821`, Library and
Shiori overviews and one Library folder detail. Captures were compared pixel by
pixel; the procedure is recorded as
`docs/engineering/08_end_to_end_testing.md` §13.

- **The menu opens with no pointer preparation.** A bare `rightClick` on a
  folder card, a video card and a Shiori list card opens each menu, and in all
  three the card under the press is the one that lights up. This is the step
  that was impossible before the change.
- **The anchor is the right card.** Right-clicking the first card lights the
  first card, and right-clicking the third row lights the third row. Before the
  intersection fix the lit card was neither, which is how the clipping defect
  was found.
- **Scroll ban.** With a card menu open, one wheel step over the grid leaves the
  content area unchanged apart from 153 anti-aliased pixels that follow the
  window's active state. The control — the same wheel step with no menu open —
  changes 1,276,949 pixels in that region.
- **The surface below is frozen.** With the menu open, moving the pointer onto
  another card leaves the whole content area **byte-identical**. A control move
  with no menu open moves the highlight to the card under the pointer, so the
  synthesized move does reach the cards.
- **Esc and outside press.** Esc closes the menu and restores the earlier
  capture byte for byte. A left press on another card closes the menu and is
  spent doing so: the page stays on the overview instead of opening that card.
- **Clipping.** With rows scrolled above the viewport, a right-click over the
  toolbar — inside the rectangle of a scrolled-away card — opens nothing, while
  a right-click just below the viewport edge opens the menu of the card that is
  actually visible there.

No E2E command, test fixture or capability was added; the run used the existing
`click`, `rightClick`, `mouseMove`, `scroll`, `keyPress` and `capture` commands.

The hit test itself is not unit tested. Its correctness depends on what AppKit
reports for a view inside a scroll view — the exact thing the first attempt got
wrong — so a synthetic test would encode the assumption rather than check it.
The in-app run above is the signal.

Outcome matched expectations after the clipping defect was corrected. The manual
acceptance that `20260825-UI-Menu Modality And Layer Input Ownership.md`
assigned to the SwiftUI cards is now automated, as its acceptance point 10 is
superseded by the current requirement.
