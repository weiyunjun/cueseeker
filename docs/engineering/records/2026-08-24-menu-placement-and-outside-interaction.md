# Menu placement and outside interaction

Human-owned documents:

- `docs/human/requirements/20260824-UI-Menu Placement And Outside Interaction.md`

## Why

Five menus each carried their own placement arithmetic and the five disagreed.
The table's two menus opened downward and only slid along an edge, the cover
menu and the speed menu never changed side at all and slid until they covered
the thing they hung off, and only the table's menus moved when the content under
them scrolled. Nothing in `UI Design System.md` decided any of it, so each
surface had invented its own answer.

(This paragraph originally said the table's menus opened upward. That was wrong,
and Step 1a below is the correction and what it cost.)

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

## Step 1a: the table container measures downward

Step 1 shipped the table's two menus on the wrong side. The shared rule measures
downward from a top edge, which is what SwiftUI and every other menu host in the
App does, but the table's container view was the one surface still measuring
upward from a bottom edge. Feeding a bottom-up rectangle to a top-down rule
swapped the two sides: the menu opened above the row, and "no room below" became
"no room above". Travel was unaffected, because translating a frame does not
care which way its space is measured — which is why the menus tracked their rows
correctly while sitting on the wrong side.

The container now measures downward like the document, the header, the page
chrome viewport and the menu overlay inside it, so the whole table speaks one
direction. Two pieces of hand-written mirroring existed only to bridge the old
mismatch and are gone with it: the submenu now takes its parent item's offset
straight from the parent menu's top edge, and the test-only submenu hit check
converts its point out of the container before asking `hitTest`, which reads its
argument in the space outside the view.

No placement arithmetic changed. `MenuPlacement` was not touched.

Files: `TableSandbox/SubtitleTableView.swift`.

### Verification

- `swift build` clean.
- Table, menu and placement suites: 151 + 12 + 6 tests, all passing. Three tests
  moved with the container: the shared submenu geometry case, its integration
  counterpart, and the geometry test's name, which described the mirroring that
  no longer exists.
- Full suite before and after the change: 1048 tests, 29 pre-existing issues
  before and 27 after, all in the media-timing, library-removal, refresh-scope
  and debug-controller families that already fail on `main` in a full parallel
  run. No test failed that was not already failing.

Debug E2E against the running App, Shiori list of 397 rows:

- Right-click on the first row: the menu opens **below** the click, aligned to
  it. Screenshot `menu-row1`.
- Right-click on the second row, where the menu no longer fits in the room left
  below it: the menu opens above. Screenshot `menu-top-row`. That is the rule
  working, and it also shows the defect the next step has to fix — a menu placed
  above the click covers the frozen header, the search field and the cover,
  because placement still uses the whole page area as its container.
- One wheel step down with that menu open: the row and the menu moved up by the
  same amount and the menu stayed below the click. Screenshot
  `menu-after-scroll`.

## Outcome

Step 1 and Step 1a cover the requirement's §2, §3 and §4.1 to §4.3. §4.4, the
table's own clipping boundary, and §5 through §7 — the menu not blocking the
rest of the interface, the middle button, the wheel inside the menu, and the
height cap with its scrollbar — are the next steps and are not in this change.
