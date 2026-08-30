# The submenu waited on a timer nobody asked for

Human-owned documents:

- `docs/human/requirements/20260830-Bug-Submenu Opens Without Delay.md`

## Why

Hovering `Move to…` or `Duplicate to…` in the Shiori row menu left the pointer
sitting on a highlighted item with nothing happening for a moment before the
destination list appeared. The wait was a fixed 300 millisecond timer the
submenu state started on hover and only honoured on hover: a click on the same
item, and the right arrow key, both opened it at once. So the same item answered
the pointer slowly and the keyboard immediately.

The timer's purpose was to keep the submenu shut while the pointer merely passes
over the trigger on its way to a lower item. The owner asked for the wait to go
so the immediacy can be judged first; the accidental-open case is the trade the
requirement's acceptance calls out, to be felt by hand rather than argued.

## What changed

The pointer reaching a trigger opens its submenu there and then. Moving between
the two triggers still closes the one the pointer left before opening the one it
reached, so the destination highlight starts at the first item again rather than
inheriting where the keyboard had left it — that ordering was previously spread
across the timer's cancellation and is now stated directly.

With no wait there is nothing to schedule and nothing to cancel, so the hover
task and the delay constant are gone. The separate grace period that keeps the
submenu open while the pointer crosses from the parent menu into it is unrelated
and untouched, as are the click and keyboard paths.

Files:

- `apps/macos-native/Sources/CueSeekerApp/TableSandbox/SubtitleTableView.swift`
  — `SubtitleTableRowActionSubmenuState` opens on hover without scheduling.
- `apps/macos-native/Tests/CueSeekerAppTests/SubtitleTableRowActionMenuTests.swift`
  — the delayed-entry case restated as an immediate one, plus the open order
  when the pointer moves from one trigger to the other.

## Verification

`swift build`: clean, no new warnings.

`swift test --filter SubtitleTable`: 173 tests pass, including the rewritten
`subtitleTableShioriSubmenuOpensOnHoverWithoutDelay`.

`swift test --filter "SubtitleTableRowActionMenu|MenuHighlightModel|MenuInputBarrier|PointerHoverGate"`:
41 tests pass, including
`subtitleTableShioriSubmenuStaysOpenAcrossDirectPointerTransfer`, which is what
removing the hover task would break first.

Acceptance point 5 — how immediate the opening feels — needs a real pointer over
a real menu. The Debug E2E controller posts synthetic mouse events, which do not
produce the tracking-area crossings SwiftUI hover is built on, so it cannot drive
this. That gap was reported before implementation and no test capability was
added for it. The owner checks it by hand.
