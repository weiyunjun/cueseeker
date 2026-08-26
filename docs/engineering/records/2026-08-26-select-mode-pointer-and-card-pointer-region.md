# Select Mode arrow, and one shape for the whole card

Human-owned documents:

- `docs/human/requirements/20260826-Bug-Select Mode Pointer And Card Pointer Region.md`

## Why

Two leftovers from before the pointer rules were written down.

The subtitle table showed the hand over the whole row in Select Mode. That was
deliberate when Select Mode was added: a press anywhere on the row ticks its
checkbox, so the whole row was treated as a click target and given the hand.
The accepted rule is narrower — the hand marks playable cue text, and Select
Mode plays nothing.

This is not the cause of the earlier filter-menu report, where the hand appeared
over menu rows. That one was the table's cursor rects staying in force under a
higher surface, and it is closed by the menu barrier. Select Mode needs no menu
and no covering layer to show the hand; the table states it itself.

The cards showed the hand over less than they light up for. A card is a button,
and its style adds the interaction padding around the label — that padding is
what Hover covers, because Hover is asked of the button. The hand was asked of
the label inside the padding, so the ring between the content and the card edge
lit the card and kept the arrow.

## What changed

Select Mode contributes no hand rects at all; the mode joins the existing guard
instead of branching inside the function. The row's hover, its checkbox and its
press are untouched.

On the two cards that are buttons the hand moved from the label into the button
style, stated on the same padded shape that already answers Hover and the press.
It is still inside the button, which is what the earlier finding required — a
hand asked for around a button is overwritten by the button itself. The video
card is not a button; its hand moved up beside its content shape so all three
cards read the same way.

A `ButtonStyle` is not a view and cannot watch the environment, so the card
passes the freeze answer it already reads into the style.

Files:

- `apps/macos-native/Sources/CueSeekerApp/TableSandbox/SubtitleTableView.swift`
  - `interactiveCellCursorRects` refuses Select Mode; its `documentWidth`
    argument went with the removed branch.
- `apps/macos-native/Sources/CueSeekerApp/Shared/LibraryOverviewComponents.swift`
  - `LibraryOverviewCardButtonStyle` states the hand after its content shape.
- `apps/macos-native/Sources/CueSeekerApp/Shiori/ShioriListOverviewView.swift`,
  `apps/macos-native/Sources/CueSeekerApp/TableSandbox/WorkbenchTestLibraryView.swift`
  - The three cards stop stating it themselves; the two buttons pass the freeze
    answer to the style.

No token, colour, size, layout, hover, press or menu behaviour changed.

## Verification

`swift build`: clean. `swift test`: 1098 tests, the same failures as the
baseline tree with this change stashed — native playback timeline, refresh
scope, window geometry, and the playback tests that differ run to run on both
trees.

`subtitleTableViewDropsPointingHandInSelectionMode` pins the table half: in
Select Mode there are no hand rects at all and no point on the row reports one,
and leaving the mode brings the cue text's hand back.

The card half stays the owner's manual check, as acceptance item 5 already
says. It cannot be automated with what the project has: the Debug E2E
controller's `mouseMove` never reaches SwiftUI's pointer machinery, captures
never contain the cursor, and the padding ring is exactly the area that needs a
real pointer to be in it. No test capability was added for this.

## Follow-up: the card's area is its rectangle, corners included

The first attempt aligned the hand with the press, and the owner rejected it:
the area to match is the one that decides Hover, and that one is the card's
plain rectangle. Hover is asked of the whole frame; the press and the hand were
asked of the rounded shape the background is drawn with. At a 20pt radius each
corner is a visible sliver that lit the card up, took no click, and kept the
arrow.

The rounded shape was never a hit area — it is what the hover background is
drawn with, and using it to answer input made the card's edge disagree with
itself. The three cards now answer over their rectangle, so a corner lights up,
shows the hand and opens the card. The background stays rounded; nothing about
the card's appearance changed. Right-click already used the rectangle and is
unaffected.

Owner decision, recorded because it reads as the opposite of an obvious
alternative: shrinking Hover to the rounded shape was offered and refused. A
card's interactive area is a rectangle.

Files:

- `apps/macos-native/Sources/CueSeekerApp/Shared/LibraryOverviewComponents.swift`,
  `apps/macos-native/Sources/CueSeekerApp/TableSandbox/WorkbenchTestLibraryView.swift`
  - The interaction shape is `Rectangle()`; the hand keeps sitting on it.

### Verification

`swift build`: clean. `swift test`: 1098 tests, no new failures against the
baseline — the three library-folder-removal names that surfaced in this run pass
in isolation and are the same suite-parallelism flake the earlier record noted.

Corner behaviour stays the owner's manual check for the same reason as before:
the E2E controller cannot put a real pointer in the corner, and captures never
contain the cursor.
