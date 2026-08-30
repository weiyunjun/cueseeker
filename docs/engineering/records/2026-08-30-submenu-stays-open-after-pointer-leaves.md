# The submenu was never told the pointer had left

Human-owned documents:

- `docs/human/requirements/20260830-Bug-Submenu Stays Open After Pointer Leaves.md`

## What the measurement said

The submenu used to close when its own hover flag and the parent menu's both
went false. That decision was already proven correct by a unit test, so the
defect had to be in what reached it. Temporary probes on the gate's verdict and
on the state's own hearing, and one reproduction run by the owner in three
variants, settled it in a single session.

Across the whole session the gate saw 1058 pointer moves land outside the menu
and spent every one of them, as the barrier is meant to. It saw exactly eight
tracking-area crossings, and **every one of them happened with the pointer still
on the menu**. Not one crossing was ever produced by the pointer leaving. The
eight line up one for one with the only hover reports the submenu state ever
heard — entering the parent menu, crossing to the submenu, coming back — while
the run where the pointer left the trigger and stopped shows seven and a half
seconds in which the state heard nothing at all.

The reading follows: a crossing is not an event in its own right, it is worked
out while a move is being delivered. The barrier stops the moves that land
outside the menu, so AppKit never gets to notice the pointer has left the
menu's tracking area, and the crossing that would have said so is never born.
This is the 2026-08-27 defect's other half: that fix let crossings through, and
a crossing that is never generated cannot be let through.

The two hover reports that did arrive after each close were SwiftUI tearing the
submenu's view down, some twenty milliseconds late — a consequence of the close,
never a cause.

## What changed

The gate is the one place that still knows where the pointer is: it computes
that answer for its own verdict on every move, including the ones it spends. It
now hands it to the menu that owns it, and the submenu's closing is decided from
position rather than waited for as an event. The barrier is unchanged — nothing
underneath the menu sees any of this.

The owner chose the web convention over the macOS one, so the pointer leaving
closes the submenu, with a safe area for the crossing: the triangle from where
the pointer left the trigger to the submenu's near edge, plus the strip between
the two menus when they are parted (this table places them flush, so that strip
is usually empty). Inside it the menu's rows ignore the pointer entirely — they
neither take the highlight nor open the other submenu — which is what makes
cutting the corner over a lower item work. There is no speed or direction test:
inside the area is inside, as the requirement says.

Two things went away with it. The parent menu and the submenu no longer watch
their own hover — those flags could only ever be half told — and the grace
period that used to cover the seam between them is gone, because the safe area
covers that crossing by construction. What remains is one source for the
question and one rule.

Files:

- `apps/macos-native/Sources/CueSeekerApp/Shared/MenuGate.swift` — the client
  can be handed the pointer; another window's coordinates are not passed on.
- `apps/macos-native/Sources/CueSeekerApp/TableSandbox/SubtitleTableView.swift`
  — `SubtitleTableRowActionSubmenuSafeArea` is the geometry,
  `SubtitleTableRowActionSubmenuState.notePointer` the rule, and the menu rows
  ask before reacting.
- `apps/macos-native/Tests/CueSeekerAppTests/SubtitleTableRowActionMenuTests.swift`
  — crossing the corner, leaving in either direction, the parent menu's own
  rows still owning their case, and the geometry including a left-hand submenu
  and a parted pair.

The probes added for the measurement are removed in this same change.

## Verification

`swift build`: clean.

`swift test --filter SubtitleTable`: 176 tests pass.

`swift test --filter "SubtitleTableRowActionMenu|MenuInputBarrier|MenuHighlightModel|MenuGateKind|PointerHoverGate|InterfaceLayerFreeze"`:
51 tests pass.

Acceptance is the owner's by hand. The Debug E2E controller posts synthetic
mouse events, which produce neither the tracking-area crossings SwiftUI hover
needs nor a real pointer for the gate to report, so it can drive neither half of
this behaviour. That gap was reported before implementation and no test
capability was added for it.
