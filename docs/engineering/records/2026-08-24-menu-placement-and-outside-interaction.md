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

## Step 5a: the cap is a cap, not a height (§7)

Step 5 declared §7 done and it was not. Every card right-click menu came out
exactly 480pt tall — the cap — whether it held two items or five, with a field of
empty space below the last one. Shiori's list page, the recent-video page and the
library page all showed it.

The cap had been written as a `maxHeight` frame. **`maxHeight` does not mean
"stop here", it means "you may grow this large"** — it is the same modifier
`maxWidth: .infinity` uses to fill a row. A menu offered more height than it
needs therefore grows straight to the cap. Wrapping the panel in a scroll view
had nothing to do with it: the panel stretches the same way with the scroll view
taken out and only the frame left.

Which menus were offered that height decided which ones broke. The table's row
menu, the Shiori submenu and the playback selected-text menu are each measured by
their AppKit host with no height offered at all, so the frame had nothing to grow
into and reported the items' own height; the speed menu never used this panel.
The three card menus live in an overlay spanning the whole page, and that overlay
offers the page's full height. One panel, two hosting styles, and only one of
them stretched.

Step 5's own test went through the AppKit host, which is why it passed while
three menus in the App were visibly wrong.

`MenuHeightCap` replaces the frame. It asks its content how tall it wants to be
and gives it that, or the cap, whichever is smaller. The scroll view inside is
handed a definite height either way: its own content's height, where there is
nothing to scroll, or the cap, where it scrolls. Nothing depends on what the menu
is offered, so both hosting styles now behave the same. Same padding token, same
cap token, same width, same placement, colours, radii and shadows.

Files: `Shared/MenuMetrics.swift`,
`Shared/WorkbenchControls/WorkbenchControls.swift`.

### Verification

- `swift build` clean.
- New `MenuPanelHeightTests`, 2 cases, hosting the panel the way a card menu is
  hosted — inside an overlay 900pt tall. Three 30pt items make a 114pt menu
  (items plus the padding ring), and thirty items stop at the cap. The first case
  measures 480pt on the old code, which is the regression itself. No new test
  capability was needed: `WorkbenchScrollViewTests` and
  `WorkbenchPageScrollbarTests` already host SwiftUI at a fixed size and read
  what came out.
- Menu suites: 51 tests passing, including
  `subtitleTableShioriSubmenuStopsAtTheMenuHeightCap`, which covers the same cap
  through the AppKit host.
- Full suite: 1053 tests, 25 issues, all in the media-timing and cue-group-scope
  families that were already failing. The two cue-group cases were run against
  unchanged sources and fail there identically.

Manual acceptance, for the reason §1.1 of
`docs/engineering/08_end_to_end_testing.md` records — these menus install their
right-click monitor only while the card reports SwiftUI hover, which a
synthesized move cannot produce: right-click a card on the Shiori list page, the
recent-video page and the library page; each menu should end just below its last
item, and the table row menu, the playback selected-text menu and the speed menu
should look exactly as they did.

## Step 1b: a card menu measures the room the reader can see (§3)

Step 1 gave the card menu the flip it never had, and it still opened downward
into places nobody can see. Right-click a cover near the bottom of the window and
the menu opens below the pointer and runs off the screen.

§3 says "below first, above when it will not fit below". **What the card menu was
measuring "below" against was its own grid** — forty covers, eight rows, twice the
height of the window. There is plenty of room below inside that rectangle; it is
simply not room anybody can see. The table's menus never had this problem because
§4.4 already binds them to the table body, which is a viewport. Nothing bound the
card menu to anything.

This is independent of Step 5a: at 480pt the same click opened downward too, just
further off-screen.

`LibraryCardContextMenuHost` is carried into five grids, all of them inside a
scrolling page: the library overview, the library folder detail, the recent-video
page, the Command Panel's recent videos and the playback library overlay. Only
Shiori's list page puts the host above the page's scroll view, where the host's
own rectangle already is the visible one — which is why Shiori was the one page
whose direction was right.

So the fix belongs in the host, not in five call sites. `WorkbenchScrollView` now
publishes its viewport: a named coordinate space so content can tell where it
sits relative to the window onto it, and the viewport's size through the
environment. The host asks for the visible part of itself and hands that to the
existing `MenuPlacement.openingFrame` instead of its whole rectangle. A host that
is not inside a scroll view gets nothing from the environment and keeps using its
own rectangle, so Shiori's path is untouched.

Following (§4) is unchanged: the side and the offset are still fixed at opening
time, and a menu whose card scrolls out of view still travels out with it.

Files: `Shared/WorkbenchScrollView.swift`,
`TableSandbox/WorkbenchTestLibraryView.swift`.

### Verification

- `swift build` clean.
- `WorkbenchScrollViewTests` gained four cases: three on the visible-rectangle
  arithmetic — scrolled to the middle, scrolled to the end, and a grid shorter
  than the viewport — and one that hosts a real scroll view and reads what it
  publishes. The last one scrolls the view 300pt and checks the sign the
  arithmetic depends on, which is the mistake Step 1a already cost once.
- Menu and placement suites unchanged and passing; `MenuPlacement` was not
  touched.
- Full suite before and after: 1053 tests with 29 issues before, 1057 with 27
  after. The failing sets differ in both directions between the two runs and all
  of them are the media-timing, library-removal, refresh-scope and
  persistence-migration families that already fail in a full parallel run; the
  two that appeared only in the run after the change pass alone. No test failed
  that was not already failing.

Manual acceptance, for the hover reason recorded in Step 5a: right-click a card
near the bottom of the window on the library overview, a folder's episode list,
the recent-video page and the Shiori list page — each menu should open upward and
stay fully visible — then scroll with a menu open and confirm it still travels
with its card and keeps its side.

(The mechanism this step introduced for reading the viewport was replaced in Step
1c, which also removes it. What survives from this step is the rule: a card menu
measures against what the reader can see.)

## Step 1c: one placement lifecycle, the table's (§3)

Step 1b gave the card menu the right boundary and the App got worse: a menu would
open above a cover and then, as the page scrolled, move to below it — and it
never slid off the screen the way §4.3 asks, it kept pulling itself back into
view.

Both are one cause. **The card menu had its own placement lifecycle.** It could
not measure itself when it opened, so it deferred the decision until the menu
reported its size through a side channel, and **until that record was written it
re-ran the opening rule on every layout pass**. Re-running is exactly what §3.3
forbids. It had been harmless only because the boundary used to be a fixed
rectangle, so every re-run gave the same answer; Step 1b made the boundary follow
the window, and the same re-run started answering differently as the page moved.
The second symptom is the same sentence read further: the opening rule ends by
sliding the menu inside its boundary, so every re-run pulled it back on screen.

The table never had either symptom because it does it in the other order: when a
menu opens it puts it in a hosting view, **measures it**, chooses the side once,
**stores the offset in that same call**, and from then on only translates.

The card host now follows that order. Because the size is known at the click,
three things the deferred version needed are gone: the size-reporting preference,
the guessed fallback size, and the handshake that wrote the decision one frame
later. The side and the offset live in the open menu's own state, and the body
has one job — translate.

The boundary is now asked for the same way the table asks: a view behind the page
reports its own unclipped rectangle, read at the moment of the click. That
replaces Step 1b's published viewport, which is removed with its tests, so there
is one way to answer "what can the reader see" instead of two — and no value that
has to be published ahead of the click and kept in step.

`MenuPlacement` was not touched; it was already the shared part. What was
duplicated was the lifecycle around it, and now it is not.

Files: `TableSandbox/WorkbenchTestLibraryView.swift`,
`Shared/WorkbenchScrollView.swift` (Step 1b's addition removed).

### Verification

- `swift build` clean.
- New `LibraryCardMenuPlacementTests`, 5 cases. They drive the menu through the
  very callback the cards are handed, so the hover gate that kept these menus out
  of automation is not in the way: opens above a card with no room below it on
  screen, keeps its side and offset while the page scrolls, keeps them when
  opened a second time, keeps them when opened on an already scrolled page, and
  travels out of the viewport with its card instead of being pulled back. The
  first and last both fail on Step 1b's code, which is the pair of symptoms
  reported. **Card menu placement is no longer manual-only acceptance.**
  Observing it needed one production change: the pointer monitor that already
  holds the menu's frame now exposes it, the way `WorkbenchScrollViewOverlayView`
  exposes its scroll view.
- Menu, placement and scroll-view suites: 62 tests passing.
- Full suite: 1058 tests, 39 issues, all in the media-timing, refresh-scope,
  localization-leak and persistence families that vary run to run; the four names
  that had not appeared in the previous run all pass alone. No test failed that
  was not already failing.

## Outcome

Steps 1 through 5a cover the requirement's §2 through §7 — every section. What
remains is the manual acceptance listed above plus the table row hover and the
middle button from Step 3, and then updating and committing
`docs/human/design/UI Design System.md`.
