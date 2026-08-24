# Menu highlight and single selection

Human-owned documents:

- `docs/human/requirements/20260824-UI-Menu Highlight And Single Selection.md`

## Why

Eight surfaces expressed "the current item" in incompatible ways. Four menus had
no default highlight and no arrow-key navigation. Four list surfaces could light
two items at once, because Selected and Hover shared one background and were
independent. The shared menu row painted `isHighlighted || isHovered`, so the
parent's highlight and the row's own hover could both appear.

## What changed

### Step 1: shared infrastructure (no behaviour change)

`AppCursorVisibility` became the App's only owner of `NSCursor.hide()` and
`NSCursor.unhide()`. Those calls are counted, so once menus also need to hide
the cursor two independent hiders could leave it permanently invisible. The type
now keeps one hide outstanding while any owner asks for it. The playback
visibility model routes through it instead of calling `NSCursor` directly; its
own behaviour is unchanged, and Debug E2E `pointerVisible` keeps reporting the
real state.

`MenuHighlightModel` holds one highlight for one open menu surface. The owning
menu supplies the positions that can take the highlight, so dividers and
disabled items are absent and arrow keys skip them without the model knowing
what a divider is. The highlight stops at both ends rather than wrapping,
matching the Command Panel's existing arrow-key behaviour.

Hover is gated. A context menu opens under the pointer, and a keyboard move can
land away from a stationary pointer; in both cases the row beneath the cursor
would otherwise pull the highlight straight back. The model therefore remembers
where the pointer is but only adopts it after real pointer movement, which a
local `mouseMoved` monitor reports. The main window accepts mouse-moved events,
so that monitor sees motion over every surface that can host a menu. A keyboard
move closes the gate again and hides the cursor until the pointer moves.

Files: `Shared/AppCursorVisibility.swift` (new),
`Shared/MenuHighlightModel.swift` (new),
`Playback/PlaybackChromeVisibilityModel.swift`,
`Tests/CueSeekerAppTests/MenuHighlightModelTests.swift` (new).

### Step 2: the three menus built from the shared popover row

`WorkbenchPopoverRow` no longer paints a background for its own hover, only for
the highlight its owning menu gives it. That single line was the direct cause of
two rows lighting up at once. Hover is now reported upward instead, and the menu
decides whether it may move the highlight.

Three menus adopted the model: the Workbench table row context menu, the
Workbench cover context menu, and the selected-text menu shared by the Playback
Overlay and the Command Panel. Each opens the model with the positions its own
content allows, keeps its existing dismiss monitor, and gained arrow keys and
Enter through the monitor pattern already used for Escape.

The row menu's destination submenu is treated as its own surface with its own
highlight: while it is open it owns the arrow keys, its parent row stays
highlighted so the relationship stays visible, and the left arrow closes it and
returns the keys to the parent. Enter on a submenu parent opens the submenu
rather than acting, matching a click on the same row.

`SubtitleTableRowActionMenuModel` now answers which element positions can take
the highlight, so the view and the coordinator agree on which items are enabled
instead of computing it twice. `openHighlightedParent` became unreachable once
the right arrow read the shared highlight, so it and its assertion were removed.

Each menu surface owns its cursor-hiding claim by identity. A parent and its
submenu are separate owners, so closing a submenu no longer reveals the cursor
that the parent, still being navigated by keyboard, wants hidden.

Files: `Shared/WorkbenchControls/WorkbenchControls.swift`,
`TableSandbox/SubtitleTableView.swift`,
`TableSandbox/SubtitleTableRowActionMenu.swift`,
`TableSandbox/WorkbenchTestLibraryView.swift`,
`Playback/SubtitleFocus/PlaybackSubtitleFocusReel.swift`,
`Shared/AppCursorVisibility.swift`, `Shared/MenuHighlightModel.swift`.

## Verification

- `swift build` clean.
- `MenuHighlightModelTests`, 9 tests green: default highlight on the first
  selectable position, an already-selected default for the speed menu, arrow
  movement skipping unselectable positions and stopping at both ends, hover
  ignored until real motion, the remembered hover adopted as soon as motion
  arrives, a keyboard move closing the gate so a stationary pointer cannot pull
  the highlight back, hover on an unselectable position ignored, cursor hidden
  by keyboard movement and restored by motion, and the cursor staying hidden
  while any owner still asks for it.
- Regression: `DebugE2EControllerTests` 12 green, `PlaybackNormalShortcutTests`
  9 green including `playbackPointerStartsHiddenAndOnlyMovementRestoresIt`.

Step 2 additions:

- `MenuHighlightModelTests` grew to 10 tests, adding the parent/submenu cursor
  ownership case.
- `SubtitleTableRowActionMenuTests` covers selectable positions skipping
  dividers and disabled actions, `action(at:)` on a divider and out of range,
  and submenu parents being disabled without destinations.
- Filtered sweep over the table, workbench, library, playback-focus, menu and
  E2E suites: 476 tests, all green except two `DebugE2EControllerTests`
  scene-geometry cases. Those two were re-run with every step-2 file restored
  from Git and fail identically without this change: another suite in the mixed
  run leaves a window on screen that `DebugE2EScene.current` picks up. They pass
  when the suite runs alone or with the library suites.

Debug E2E run against the real App, on a Shiori list of 397 rows:

- `rightClick` on a row opened the context menu with Play highlighted and
  nothing else.
- Three `downarrow` presses moved the highlight to Copy Deep Link, skipping the
  divider, with exactly one row highlighted throughout.
- `pointerVisible` reported `true` before the first arrow key and `false` after
  it, which is the first time the Workbench hides the cursor on keyboard input.
- `rightarrow` on Move to… opened the destination submenu, `downarrow` moved the
  submenu's own highlight from the first to the second list, and the parent row
  stayed highlighted.

## Outcome

Steps 1 and 2 matched expectations.

One interpretation needs the owner's confirmation. The requirement says no two
highlights may exist at once. While a destination submenu is open, its parent
row stays highlighted and the submenu carries its own highlight, so two are
visible. The alternative, dropping the parent's highlight, loses which parent
the submenu belongs to. The submenu is treated as a separate surface with its
own single highlight; say so if the literal single-highlight reading was
intended instead.

Escape now closes the cover context menu, which previously had no keyboard
handling at all. This is consistent with the other menus but was not asked for.

The speed menu and the four list surfaces follow in separate steps.
