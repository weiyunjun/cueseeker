# Recent page card menu layer

Human-owned documents:

- `docs/human/requirements/20260825-UI-Menu Modality And Layer Input Ownership.md`

## Why

Right-clicking a video card on the Recent page opened the menu underneath the
Recent Shioris section below it: the list's cover art and text were painted over
the menu's items.

The accepted requirement puts a menu one step above the surface that opened it.
The surface here is the page, and the page holds two sections. The menu was not
above the page; it was above one section of it, so the section that comes after
it in the page's vertical order painted over it. Raising the menu inside its own
section cannot fix that, because depth only orders siblings that share a parent
— the whole section, menu included, sits below the section that follows it.

The same mistake also decided how the menu was placed. The menu measures how much
room is left before it chooses to open downward, upward, or slide along an edge,
and it takes that measurement from whatever it is attached to. Attached to the
card grid, it was measuring the grid instead of the page.

## What changed

The Recent page now hosts the menu at its own root, the way the Shiori overview
page already did. A grid asks the page for the menu host and only stands one up
itself when no page provides one, so every other screen that shows the same grids
— Library, the Command Panel's Recent Videos page, the Playback Overlay's episode
grid — keeps the behaviour it had.

Files:

- `apps/macos-native/Sources/CueSeekerApp/TableSandbox/WorkbenchTestLibraryView.swift`
  - `LibraryCardContextMenuHost` publishes its opener through the environment,
    next to the two values it already publishes.
  - `LibraryVideoCardGrid` uses that opener when a page supplies one.
  - `WorkbenchRecentView` wraps the page in the host.

No token, colour, size, menu content, or keyboard behaviour changed.

## Verification

`swift test`: 1061 tests, five failing. None of them come from this change.
`showCueGroupInvalidationIsScopedToMountedShiori` and
`shioriTableStartsAtTopAfterPanelRemount` fail identically on the baseline file
restored in place, so they were already failing. The three native playback
timeline tests pass in isolation on both trees and only fail inside the full
run, the same order-dependent flakes recorded on 2026-08-24.

Built and launched with `--cueseeker-debug-e2e`, then drove the Debug in-app
controller.

- Recent page, right-click on the first video card: the menu is fully visible
  over the Recent Shioris section; the list cover and description are behind it.
  The right-clicked card keeps its highlight.
- Wheel event while that menu is open: the capture is byte-identical to the one
  taken before the wheel event, so the whole-window scroll ban still holds.
- Escape closes the menu and the page is unchanged.
- Recent Videos page, right-click on a card: menu opens and covers the rows
  below it.
- Library page, right-click on a folder card: menu opens unchanged, on the path
  that still hosts its own menu.

## Outcome

Matches the requirement. The menu now covers the whole page it belongs to, and
its placement is measured against the page.

The remaining known gap in the same requirement is unrelated to this change:
`§3.3` — a higher surface must not close a menu already open below it — is still
not in effect on the same-window dialog path.
