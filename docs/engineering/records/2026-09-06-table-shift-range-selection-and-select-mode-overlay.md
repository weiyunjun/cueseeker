# Shift extends a row range, the overlay follows Select mode, and it stops leaking hover

Human-owned documents:

- `docs/human/requirements/20260906-UI-Table Shift Range Selection And Select Mode Overlay.md`

## Why

Three things the Select mode was missing.

Selecting a run of rows meant clicking each one. Every other list-shaped App on the platform extends a range with Shift, and the table had no equivalent.

The Selection Action Overlay only appeared once a row was already selected, so the actions available in Select mode were invisible at the moment the mode was entered, and the way out of the mode (Exit) was only reachable after picking something.

The Overlay floats over the table but the table kept reading pointer motion underneath it, so a row lit up behind the bar as the pointer travelled across it.

## What changed

**The selection state gained an anchor.** `TableSandboxRowSelectionState` now records `anchorRow`, the highest row the most recent selecting operation selected. Selecting one row sets it to that row; selecting a range sets it to the range's upper end; select-all sets it to the last row. Deselecting never moves it, which is what keeps the rules from needing a second concept — the anchor survives a Shift-click that only removes a row, so the next Shift-click still has somewhere to extend from. Clearing the selection clears it, and it rides along with `shiftRows` and `clamp` so a table that pages rows in at the top does not leave the anchor pointing at the wrong row; if the clamp does drop it, it falls back to the highest still-selected row, which preserves the "a selection always has an anchor" invariant the requirement relies on.

`shiftClick(row:rowCount:)` implements the three rules directly: nothing selected extends from the first row, an already-selected row is only removed, and an unselected row extends from the anchor. The storage is untouched — a range folds into the existing explicit set or comes out of the "all except" set, so select-all still costs no per-row memory.

**Shift reaches the state through the existing mouse path.** The document view's `mouseDown` already holds the event, so it passes `event.modifierFlags.contains(.shift)` into `handleMouseDown`, which routes Select-mode clicks to either the plain toggle or the new `shiftSelectRowFromMouse`. The Shift variant redraws the whole visible document rather than the clicked row, because a range changes rows the click never touched. The header, the keyboard `Space` toggle and normal mode are untouched, so Shift changes nothing there.

**The Overlay follows Select mode.** The shell's two render sites now test `isSelectionMode` instead of the selected count, and both callers' action builders drop the same count condition. The count text renders `0 selected` from the existing localised format; the three actions keep their normal appearance at zero rather than going Disabled — the requirement asks for that deliberately, since a later Toast is meant to explain what is missing rather than a dead-looking button.

**The table learns where the Overlay is.** `MenuAnchorHandle` already exists to carry one view's frame across hosting boundaries, and it gained a `windowFrame` accessor because the table works in AppKit window points. Each caller owns a handle, the shell mounts the existing `MenuAnchorProbe` behind the Overlay, and `handleMouseHover` returns early while the pointer is inside that frame. Freezing rather than clearing matches what `UI Application Rules.md` already says about a lower layer under a higher one: the picture stays where it was, and only a real move back onto the table changes it.

Files:

- `apps/macos-native/Sources/CueSeekerApp/TableSandbox/TableSandboxRowSelectionState.swift`
- `apps/macos-native/Sources/CueSeekerApp/TableSandbox/SubtitleTableView.swift`
- `apps/macos-native/Sources/CueSeekerApp/TableSandbox/WorkbenchTestSearchView.swift`
- `apps/macos-native/Sources/CueSeekerApp/TableSandbox/WorkbenchShioriTableView.swift`
- `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchSchemaSearch/SchemaWorkbenchSearchShell.swift`
- `apps/macos-native/Sources/CueSeekerApp/Shared/MenuAnchorProbe.swift`
- `apps/macos-native/Tests/CueSeekerAppTests/TableSandboxRowSelectionStateTests.swift`

## Verification

Unit tests cover the requirement's Shift scenarios exactly as written — the empty-table extend, the deselect-only case, the extend from the anchor, the chain that deselects the anchor and then extends back across it, select-all followed by a single removal on a 100,000-row table (still one tracked index), and the anchor following `shiftRows` and falling back after `clamp`. `swift test --filter TableSandboxRowSelectionStateTests`: 15 tests, all passing.

Debug E2E controller, main window 1445×821, Search, 549 results.

- Entering Select mode draws the Overlay immediately, reading `0 selected`, with Anki, Copy Deep Links and Copy Table at full strength alongside Exit.
- Pointer on row 3 lights row 3. Moving the pointer into the Overlay leaves row 3 lit and lights nothing under the bar. Moving back onto the table lights the row under the new position.
- Two plain clicks read `2 selected` and set the header Checkbox to its partial state; Exit clears the selection and restores the `#` column.

Full `swift test`: 1138 tests, 24 issues, in the families earlier records list as failing on the baseline tree — native playback timeline and audio, cue group refresh scope, ASS/matroska preparation. The two cue-group cases that fail every run (`showCueGroupInvalidationIsScopedToMountedShiori`, `shioriTableStartsAtTopAfterPanelRemount`) were re-run on the unmodified tree at `8dc707c` and fail there identically. `progressiveSearchProjectionRefreshesOnlyMountedTable` fails only under full-suite parallelism and passes when its suite runs alone.

## Known limits

Shift plus a click cannot be driven by the Debug E2E controller: its mouse commands reject a `modifiers` field and post their events with empty modifier flags, and only `keyPress` accepts modifiers. The Shift rules are therefore covered by unit tests over the selection state and remain a manual acceptance step in the App. Extending the controller's mouse commands would be new end-to-end capability and was not added.

The Shiori list detail was not exercised in this pass: the local library holds no Shiori lists, and creating one would write to the owner's data. Both tables go through the same shell, the same table view and the same wiring, and the Shiori caller received the identical changes, but its acceptance run is still outstanding.
