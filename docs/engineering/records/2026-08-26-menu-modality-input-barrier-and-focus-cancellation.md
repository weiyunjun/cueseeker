# Menu modality input barrier and focus cancellation

Human-owned documents:

- `docs/human/requirements/20260826-UI-Menu Modality Input Barrier And Focus Cancellation.md`
- `docs/human/design/UI Application Rules.md`

## Why

An open menu was modal by agreement rather than by construction. The gate
intercepted the four event types it knew about and handed the rest back to the
App, so everything else — pointer motion, cursor shapes, hover, the keyboard —
depended on each surface remembering to ask whether a menu was open. Two
consequences were reported: typing kept reaching the search field under an open
menu, and the I-beam still appeared when the pointer crossed that field. Both
already contradicted the design; what was missing was a place where the answer
could be given once.

## What changed

**The gate is now a barrier.** Its monitor watches every pointer, button and
key event, and while a menu is open only four things travel on: what landed on
the menu, what belongs to another window, a drag that began on the menu, and a
shortcut. Everything else stops before it reaches any view, so a control added
to the App later cannot opt out of a message it never receives. The decisions
are three small pure rules in `MenuInputBarrier`, kept out of the event plumbing
so they can be pinned by tests; presses keep going through `MenuOutsidePress`
unchanged.

**Each menu now states only which menu it is.** The four switches every call
site used to pass — scroll ban, wheel ownership, and the two key sources — are a
table on `MenuGate.Kind`, which reads directly against the design's scroll table
and key rules. One behaviour changed with it: the selected-text menu in the
Command Panel now takes its keys from the playback key router like its Playback
Overlay twin, so arrows belong to the menu instead of moving the panel's
selection underneath it.

**The keyboard becomes nobody's while a menu is open.** Opening a menu cancels
the focus, and `CueSeekerMainWindow` refuses to hand it back until every open
menu is either closed or covered by a higher layer — cancelling alone is not
enough, because a field that focuses itself when it appears takes it straight
back. The focus does not return when the menu closes; the reader clicks the
field again. Unspent plain keys are consumed by the gate, which also keeps the
window from beeping now that nothing holds focus.

**The cursor becomes the App's.** Opening a menu switches the window's cursor
rects off and states the arrow once; closing switches them back on. No surface
under the menu can state a shape because no surface receives the events that
would make it.

**Selections do not outlive the menu that covered them.** Opening any menu but
the selected-text menu asks every surface holding selected text to drop it; the
selected-text menu keeps the selection it hangs off and clears it on the way out
as before.

**Two hover catch-ups were removed.** The table recalculated its hover from the
real pointer position when its menu closed and when a freeze lifted, which is
exactly the catch-up the requirement forbids. The highlight now stays where the
freeze left it until the pointer really moves, a right-click moves it, or a
left-click that is not spent closing a menu moves it. The cursor shape is still
answered on unfreeze; only the highlight waits.

One redundancy was left in place deliberately: the table's own pointer freeze
still asks whether its row menu is open. The barrier makes that check moot for
events, but the same flag guards paths the barrier does not reach — hover raised
by scrolling rather than by the pointer — and rewiring it inside a seven-thousand
line file was not worth the regression risk for this change. It freezes; it
never states a shape.

## Verification

Unit: the three barrier rules and the kind table, plus the existing menu, gate,
placement, highlight and playback-shortcut suites. The full run's failures are
the same environment-dependent families that fail on the unmodified baseline
(native playback media, scene and window geometry, refresh-scope counting,
localized feedback text), checked by running both trees.

In-app, driven through the debug E2E controller with screenshots:

- Typing `ab` into the Search field, then opening the filter menu: the focus
  ring and caret are gone, and two further keystrokes leave the text at `ab`.
- Pointer moved onto a table row, filter menu opened, pointer moved to another
  row: the first row keeps its highlight and nothing else lights.
- The click that closes the menu does not move the highlight; the next real
  pointer movement does.
- Table text selected, then the filter menu opened: the selection is gone.
- Row context menu: opens on the right-clicked row and moves the highlight
  there, Esc closes it and the highlight stays, and a right-click on another row
  relays the menu and the highlight in one press.
- Library card menu: same relay and the same highlight left behind after Esc.

Not covered automatically: the pointer's actual shape, which the controller
cannot report, and menu-row hover, which synthesized moves cannot drive. Both
are left to acceptance.

Files:

- `Sources/CueSeekerApp/Shared/MenuInputBarrier.swift` (new)
- `Sources/CueSeekerApp/Shared/CueSeekerMainWindow.swift` (new)
- `Sources/CueSeekerApp/Shared/MenuGate.swift`
- `Sources/CueSeekerApp/Shared/InterfaceLayerRegistry.swift`
- `Sources/CueSeekerApp/App/AppDelegate.swift`
- `Sources/CueSeekerApp/Shared/WorkbenchSchemaSearch/SchemaWorkbenchSearchShell.swift`
- `Sources/CueSeekerApp/Playback/Chrome/PlaybackChromeView.swift`
- `Sources/CueSeekerApp/Playback/SubtitleFocus/PlaybackSubtitleFocusReel.swift`
- `Sources/CueSeekerApp/TableSandbox/SubtitleTableView.swift`
- `Sources/CueSeekerApp/TableSandbox/WorkbenchTestLibraryView.swift`
- `Tests/CueSeekerAppTests/MenuInputBarrierTests.swift` (new)
- `Tests/CueSeekerAppTests/PlaybackNormalShortcutTests.swift`
- `Tests/CueSeekerAppTests/SubtitleTableVirtualRowTests.swift`
