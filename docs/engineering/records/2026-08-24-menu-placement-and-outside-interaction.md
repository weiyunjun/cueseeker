# Menu placement and outside interaction

Human-owned documents:

- `docs/human/requirements/20260824-UI-Menu Placement And Outside Interaction.md`

## Why

Five menus each carried their own placement arithmetic and the five disagreed.
The table's two menus opened upward first, the cover menu and the speed menu
never changed side at all and only slid along an edge until they covered the
thing they hung off, and only the table's menus moved when the content under
them scrolled. Nothing in `UI Design System.md` decided any of it, so each
surface had invented its own answer.

## What changed

### Step 1: one placement rule

`MenuPlacement` holds the whole rule as three pure functions: where a menu opens,
the offset to remember, and where it sits after its anchor moved. Below the
anchor first, above it when the menu will not fit below, slid inside the edge
when neither side fits.

The side is chosen once, when the menu opens. What the caller keeps afterwards is
an offset, not a recipe, so an anchor that scrolls carries its menu along without
the menu ever flipping to the other side halfway through a scroll. That is the
requirement's rule and it is also the cheaper one: following is addition.

Gaps and edge insets stay with the callers. Each menu passes the spacing it
already used, so no spacing token was added, changed or shared.

Per surface:

- The table's two menus now open downward. A right-click anchor is stored in
  document coordinates instead of container coordinates, so the menu tracks the
  row the pointer landed on rather than a fixed point on screen. Both replaced
  functions are gone; `repositionOpenMenu` translates instead of re-deciding.
- The cover context menu gained the flip it never had. It also travels now: the
  card that owns the open menu reports its new frame through one environment
  callback, which is the only channel that reaches the host from inside the grid.
- The speed menu goes through the same rule. Its button sits on the bottom
  chrome, so no room is found below and the menu opens upward exactly as before.
  It is given the chrome's own horizontal padding as its edge inset, without
  which the shared rule pushed it flat against the window edge.
- The selected-text menu opens below the pointer instead of beside it.

Files: `Shared/MenuPlacement.swift` (new),
`TableSandbox/SubtitleTableView.swift`,
`TableSandbox/WorkbenchTestLibraryView.swift`,
`Playback/Chrome/PlaybackChromeView.swift`,
`Playback/SubtitleFocus/PlaybackSubtitleFocusReel.swift`.

## Verification

- `swift build` clean.
- `MenuPlacementTests`, 6 tests: opens below and aligns to the anchor's leading
  edge, flips above when it will not fit below, rests on the container's edge
  when neither side fits, moves inside a trailing edge inset, travels with a
  moving anchor without changing side, and follows an anchor right out of view
  rather than being pulled back.
- Three existing tests were updated because they pinned the old direction, not
  because they broke: the two table right-click cases now expect the menu below
  the click and are given a container tall enough to have room there, and the
  selected-text case expects the gap the shared rule applies.
- Table, menu, workbench and playback-focus suites: 585 tests, failures only in
  the localization-leak and media-timing families that vary between runs. The
  two that named menus, `subtitleTableShioriSubmenuStaysOpenAcrossDirectPointerTransfer`
  and `subtitleTableViewResponderSelectAllCopiesVisibleColumnsWithoutCheckboxes`,
  both pass when run alone.

Debug E2E against the running App, on a Shiori list of 397 rows:

- Right-click on the first row opened the menu **below** the click. Right-click
  on a lower row, where the menu no longer fits below, opened it above.
- Scrolling the page with that menu open moved the menu by exactly what the row
  moved and left it on the same side. Before this change the right-click menu
  stayed where it was while the row slid away underneath.
- The speed menu opens upward and now sits inside the chrome's right margin. The
  first attempt, before the edge inset, put it flat against the window edge; the
  screenshot is what caught it.

The cover context menu could not be driven from the controller, for the reason
`docs/engineering/08_end_to_end_testing.md` §1.1 already records: its right-click
monitor is installed only while the card reports SwiftUI hover, which a
synthesized move cannot produce. Its placement and its travel are a manual
acceptance step.

## Outcome

Step 1 covers the requirement's §2, §3 and §4. Sections 5 through 7 — the menu
not blocking the rest of the interface, the middle button, the wheel inside the
menu, and the height cap with its scrollbar — are the second step and are not in
this change.
