# A shape nobody owned, outliving the surface that set it

Human-owned documents:

- `docs/human/requirements/20260830-Bug-Pointer Shape Sticks Outside The Table.md`

## Why

Clicking a cue to play left the hand on screen through the whole video and
after it, over the Sidebar, however much the pointer moved. It went back to the
arrow at one boundary only: the workbench page's own content area — the cover
card, the search bar and the table, which are one scrolling surface, not three.

That boundary is the answer. The table had two ways of stating a pointer shape,
and they are not the same kind of thing. A cursor rect belongs to a view and to
an area of it, and AppKit undoes it the moment the pointer leaves — it cleans up
after itself. Setting the cursor directly belongs to nobody: there is no area to
leave, so nothing ever undoes it. It rides along under the pointer across the
whole App until something else states a shape, and outside that one scrolling
surface nothing in this App ever does. The playback page and the Sidebar have no
opinion about the pointer; they inherit whatever was left behind.

So the hand was not being kept by the video or the Sidebar. It was put there by
the table on the last mouse move before the click, and never taken back.

The direct set is also what the accepted pointer requirement asked to be gone.
It was added on 2026-07-04 to survive SwiftUI menu rows pushing and popping
cursors; 2026-08-26 removed every push and pop in the App, and this defence for
a cause that no longer exists stayed behind as the second path
`20260826-UI-Pointer Cursor Single Authority` §3 says not to keep.

## What changed

The table states no shape on pointer movement any more. The cursor rects it
already registers are the whole answer, so the hand exists exactly over playable
cue text and is undone by leaving it, wherever the pointer goes next.

One thing being covered is not, though: leaving. When the playback page or a
dialog comes up, the pointer has not moved — it is standing over a rect that is
about to stop existing, with nothing above to state a shape. So the table gives
the arrow back once, on its way out, which is the gesture the menu barrier
already makes for the same reason.

The two point predicates that only the removed path consulted went with it;
the tests that used them now ask the cursor rects, which is what the pointer
asks.

Files:

- `apps/macos-native/Sources/CueSeekerApp/TableSandbox/SubtitleTableView.swift`
  — the moved/entered/exited handlers no longer state a shape, `handBackCursor`
  runs on being covered and on the registry's freeze, and the superseded
  predicates are gone.
- `apps/macos-native/Tests/CueSeekerAppTests/SubtitleTableVirtualRowTests.swift`
  — the handover on both freezes, asserted through `NSCursor.current` after a
  hand is really current; the rect-based reading of the old point assertions.

## Verification

`swift build`: clean.

`swift test --filter "SubtitleTable|MenuHighlightModel|PointerHoverGate|InterfaceLayerFreeze|MenuInputBarrier"`:
213 tests pass, including the new
`subtitleTableHandsTheArrowBackWhenAHigherLayerCoversIt`.

The wheel symptom in §1 of the requirement is expected to go with the same
cause — the direct set is what polluted the shape AppKit falls back to when it
rebuilds its rects on a scroll — but that is a prediction, not a measurement.
The owner re-tests it; if it survives, it gets measured the way the submenu
defect was.

Pointer shapes are not readable from the Debug E2E controller, which reports
only whether the pointer is visible, so every acceptance point here is the
owner's by hand. That gap was reported before implementation and no test
capability was added for it.
