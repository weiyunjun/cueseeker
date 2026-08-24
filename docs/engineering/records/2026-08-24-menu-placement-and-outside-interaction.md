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

## Step 2: the table body is the boundary (§4.4)

A menu carried up past the table body drew over the frozen header, the search
field and the cover. §4.4 makes the table body the boundary. The boundary that
cuts is also the boundary that measures: the table hands the shared rule its
body rectangle instead of the whole page, so a menu is placed inside the region
it is allowed to occupy, and cut off at that same region once its row carries it
out. Nothing is hidden and nothing closes.

This is not a promise that a menu stays whole. A body shorter than the menu
still cuts it, exactly as a row that scrolls out is cut. What the boundary
prevents is a menu that is born under the frozen chrome.

The rectangle is the existing `currentTableBodyVisibleRect`, which already
accounts for the pinned header taking up and giving back space; it is converted
into container coordinates for the menus. The menus now live in a clipping view
kept the size of that rectangle and stacked above the dismiss overlay, so a
press on a menu still reaches it. The clipping view's bounds are set to its
frame, which keeps one coordinate space either side of it — the menus are still
placed in container coordinates, and no offset arithmetic was added anywhere.

No placement arithmetic changed. `MenuPlacement` was not touched, and the other
four menus keep passing their own rectangles as before.

Files: `TableSandbox/SubtitleTableView.swift`.

### Verification

- `swift build` clean.
- Table suite 152 tests passing, including a new case: with a body shorter than
  the menu, the menu starts at the body's top edge instead of reaching the
  header above it, and it sits in the view that clips it. Three existing cases
  now grow the fixture's scroll view as well as its container, because the body
  — not the container — is what has to be tall enough for a menu to open below a
  click.
- Full suite: 1049 tests, 29 issues, the same count and the same families as the
  run before this change. The one new name,
  `subtitleTableViewUnifiedRowMenuAndClipboardKeepPrimaryAndGroupSemantics`,
  appears only in the parallel run and passes alone; it shares the system
  pasteboard with other cases.

Debug E2E against the running App, Shiori list of 397 rows:

- The right-click that used to flip up over the header now opens **below** the
  click: inside the body there is room below, and the body is what is measured.
  Screenshot `clip-row2`.
- Scrolling until that row leaves the body: the menu travels with it and is
  **cut off flat at the body's top edge** — the first three items are gone, the
  header and the pinned search field are untouched, and the menu is still open.
  Screenshot `clip-cut`.
- The destination submenu opens beside its parent item, inside the body, and is
  bounded by it too. Screenshot `clip-submenu`.

## Step 3: nothing is covered, and the closing press is spent (§5)

Four menus each answered "what happens outside me" differently. The table and
the cover menu each spread a full-surface layer to catch the press, which also
caught every hover and every scroll behind it. The speed menu and the
selected-text menu covered nothing but let the closing press fall through to
whatever was underneath, so one press both closed the menu and acted.

§5 settles it the same way for all of them. Nothing is covered: while a menu is
open, hover, scrolling and clicks all still reach the rest of the interface. The
press that closes a menu is the price of the menu being open — it is spent on
closing and never reaches what is under it. The middle button is not a
dismissal.

That leaves each menu with one mechanism instead of two: a local event monitor
that dismisses and then keeps the event. The table's blocking overlay view is
gone, and so is the cover menu's full-size tap layer. Two menus that only leaked
the press now keep it; the cover menu's monitor no longer matches the middle
button. Both playback menus needed the frame of the open menu to tell a press on
the menu from a press outside it — the speed menu now reports its frame the same
way its button already did.

A press in another window still closes the menu but is left to that window: it
was never this menu's to swallow.

Hover suppression went with the overlay. The table used to freeze every hover
while a menu was open; now it only ignores the pointer while the pointer is on
the menu, where it is not on a row at all, and clears the row hover on the way
in. The higher-priority overlay suppression from
`20260824-UI-Overlay Layer Priority And Input Ownership.md` is untouched.

Files: `TableSandbox/SubtitleTableView.swift`,
`TableSandbox/WorkbenchTestLibraryView.swift`,
`Playback/Chrome/PlaybackChromeView.swift`,
`Playback/SubtitleFocus/PlaybackSubtitleFocusReel.swift`.

### Verification

- `swift build` clean.
- Table suite 153 tests passing, including a new case: with a menu open, a row
  outside it still takes hover, and moving the pointer onto the menu clears that
  row's hover while the menu stays open.
- Full suite: 1050 tests, 25 issues, all in the families that already fail on a
  full parallel run and fewer than the 29 of the run before this change.

Debug E2E against the running App:

- With a row menu open, a click on a sidebar list closed the menu and **did not
  navigate**. Screenshot `outside-press-eaten`. Clicking the same item again
  navigated normally, so only the closing press is spent. Screenshot
  `second-press-navigates`.
- A click inside the menu still reaches it: the destination submenu opens.
  Screenshot `menu-click-still-works`.

Two of §5's acceptance points cannot be driven by the controller, and no
capability was added for them:

- **Row hover while a menu is open** is not reachable. The requirement's
  acceptance §11 assumes the table's row hover is covered by the existing
  automated end-to-end tests, but the table hovers from an `NSTrackingArea`,
  which follows the real cursor; the controller documents that it never moves
  the real pointer, and a synthesized `mouseMoved` does not reach that path. The
  behaviour is covered by the unit test above and needs manual acceptance in the
  App.
- **The middle button** has no controller command. Manual acceptance.

## Step 4: the menu owns the wheel over itself (§6)

A menu drew over the page but did not own the pointer's wheel: rolling over an
open menu scrolled whatever was behind it. §6 gives the wheel to the menu while
the pointer is on it, and only while it is on it.

Two mechanisms, because the menus are hosted two ways. The AppKit-hosted menus —
the table's menu and submenu, and the selected-text menu — now share one hosting
view that ends the wheel event at itself. This also answers §6.2 for free:
content inside a menu that can scroll sees the event first and scrolls with it;
when that content reaches its end AppKit passes the event up, where it stops
instead of travelling on to the page. The two SwiftUI menus have no view to
override, so their existing pointer monitors took the wheel as well: swallowed
while the pointer is on the menu, untouched everywhere else.

The table's own menu hosting view and the selected-text menu's plain hosting
view became one `MenuHostingView`, so the rule is written once. The cover menu's
monitor is no longer only about dismissal and is named for what it does.

Files: `Shared/MenuHostingView.swift` (new),
`TableSandbox/SubtitleTableView.swift`,
`TableSandbox/WorkbenchTestLibraryView.swift`,
`Playback/Chrome/PlaybackChromeView.swift`,
`Playback/SubtitleFocus/PlaybackSubtitleFocusReel.swift`.

### Verification

- `swift build` clean. Table suite 153 tests passing.

Debug E2E against the running App, Shiori list of 397 rows:

- One wheel step with the pointer **on** the open menu: nothing moved — not the
  page, not the cover, not the rows. Screenshot `wheel-on-menu`.
- The same wheel step with the pointer **outside** the menu: the page scrolled
  as usual and the menu travelled with its row. Screenshot `wheel-outside-menu`.

§6.2 — a menu that scrolls internally stopping at its end rather than handing
the rest to the page — has nothing to exercise it until §7 gives a menu a
scrollable region. It is covered by construction and needs verifying with §7.

## Step 5: the padding is the scrollbar's room (§7)

A menu that scrolls has to put its scrollbar somewhere. The two candidates were
both wrong: draw it over the items, and it crosses the highlight and the
dividers, which run edge to edge; widen the menu when it appears, and the menu
changes size for a reason the reader cannot see.

The answer is neither. **The menu's padding is now exactly what a scrollbar
occupies** — the thumb's 8pt plus the 4pt it keeps from the edge — so the
scrollbar is drawn in the padding ring, flush against the items and touching
nothing. No measuring is needed to decide whether a scrollbar will appear,
because the room is there either way, and the menu never changes width.

That made the padding a shared measurement rather than a per-menu number. It was
4pt in the shared popover panel and 6pt in the speed menu, which is why the two
looked subtly different; both now take the same token. The menus are wider by
twice the difference — 16pt for the four panel-based menus, 12pt for the speed
menu — and nothing inside them moved: item widths, text and icon positions,
highlight and divider widths, radii, colours and shadows are all unchanged.

The height cap is the second token. The panel now wraps its content in the
existing `WorkbenchScrollView` — already "system indicators hidden plus the
project's own overlay scrollbar", which is the scrollbar `UI Design System.md`
§2.7 describes — with the scroll view spanning the whole panel and the padding
inside it. Height stops at the cap; width still comes from the items.

Files: `Shared/MenuMetrics.swift` (new),
`Shared/WorkbenchControls/WorkbenchControls.swift`, `Playback/PlaybackTheme.swift`.

### Verification

- `swift build` clean. Table suite 154 tests passing, including a new case:
  thirty destinations make the submenu stop exactly at the cap, while the menu
  above it stays well under the cap and is not stretched to it. That case is
  also what proves the SwiftUI sizing works — a scroll view has no intrinsic
  size, and a wrong wrapping would have collapsed the width or stretched the
  height.
- Full suite: 1051 tests, 29 issues, the same families as before;
  `subtitleTableViewMapsTextColumnsWhenDisplayTitleIsHidden` appears only in the
  parallel run and passes alone.
- Debug E2E: the row menu's highlight and dividers now stop short of the menu
  edge on every side, and the items inside sit exactly where they did.
  Screenshot `padding12-row-menu`.

Two acceptance points could not be driven, and no capability was added:

- **A menu long enough to scroll** does not exist in this library: the
  destination submenu needs about twelve Shiori lists to pass 480pt and there
  are five. The cap itself is covered by the unit test; the scrollbar sitting in
  the padding ring, and §6.2's stop at the end of a scrollable menu, need either
  more lists or manual acceptance.
- **The speed menu** cannot be reached: the playback chrome appears on real
  cursor movement, which the controller does not produce. Its padding change is
  manual acceptance.

## Outcome

Steps 1 through 5 cover the requirement's §2 through §7 — every section. What
remains is the manual acceptance listed above plus the table row hover and the
middle button from Step 3, and then updating and committing
`docs/human/design/UI Design System.md`.
