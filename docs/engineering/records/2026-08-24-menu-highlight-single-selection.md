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

## Outcome

Step 1 matched expectations. No user-visible behaviour changed yet: nothing
consumes `MenuHighlightModel` so far. The four menus and the four list surfaces
follow in separate steps.
