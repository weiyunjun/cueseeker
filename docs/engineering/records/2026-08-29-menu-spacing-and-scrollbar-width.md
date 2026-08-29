# Menu spacing and scrollbar width

Human-owned documents:

- `docs/human/requirements/20260829-UI-Menu Spacing And Scrollbar Width.md`
- `docs/human/design/UI Design System.md`

## Why

A menu was being sized like a row of controls. `--height-action-menu-item` and
`--height-select-menu-item` both held 40px, the same number as the button, the
input field and the table row, while the label inside them is 14px on a 20px
line. That left about eleven points of air above and below every label — the
spacing of something you aim at, not of a list you read down.

The horizontal problem was that nothing owned the total. The menu container
took `--padding-menu`, the menu item took `--padding-menu-item`, and the two
simply added up: 12 and 16, so twenty-eight points passed before the first icon
appeared. Neither number is unreasonable on its own, which is why the sum went
unnoticed; the rule that was missing is that the distance from the menu's edge
to its content is a single figure to be chosen, not a by-product of two
independent ones.

The container's 12 was not arbitrary. It was the scrollbar's width plus the gap
that scrollbar keeps from the edge, so that a menu which scrolled could draw the
scrollbar inside the padding without disturbing anything: nothing moved when a
scrollbar appeared, and nothing needed measuring to find out whether it would.
That bought a stable width at the price of a padding that could never be
smaller than a scrollbar, and of items sitting flush against that scrollbar when
one was up — the gap the items kept from the menu's edge everywhere else
vanished on the side where a scrollbar existed.

Two smaller defects came out of the same place. The submenu indicator was drawn
into a 16pt icon slot, so a chevron a few points wide sat centred in it and the
trailing padding read from the slot's edge rather than the glyph's, which is
most of why "Move to ..." looked loose on the right. And the menu's corner was
16 with the highlight's corner at 8 inside 12 points of padding; concentric
corners want the inner radius to be the outer one less the padding, so the
highlight bulged into the menu's corners rather than following them.

## What changed

Menu items are now sized from their own text: 32 points is the 20px line box
with six points above and below it. The horizontal figures were chosen as a pair
— six points of menu padding and ten of item padding — so the menu's edge is
sixteen points from the leading icon rather than twenty-eight. The corners
follow the concentric rule as a derivation rather than a pair of literals:
`redesignMenuItemRadius` is `redesignMenuRadius - MenuMetrics.padding`, so a
later change to either input keeps the corners concentric on its own.

The scrollbar rule is inverted. `MenuMetrics.padding` no longer stands in for
the scrollbar's width, and a menu that scrolls widens instead: the items keep
the width they had, and the scrollbar plus a new `scrollbarOuterGap` are added
outside the padding they already sit inside. The gap between the last pixel of
an item and the scrollbar is therefore the same `--padding-menu` those items
keep from the menu's edge when nothing scrolls, which is what the requirement
asks for and what the old arrangement could not express.

Reserving that strip needs to know whether the menu overflows, which the old
design avoided on purpose. `MenuItemStack` does the measuring. It applies the
menu's padding and, when the items are taller than the cap, reports itself wider
by the strip while still placing the items at their natural width — the room
appears beside the items rather than being taken off the menu afterwards, which
is what keeps the scrollbar off them. It sits inside the scroll view rather than
around it because the scrollbar is drawn against the scroll view's own trailing
edge; an item's height does not depend on the space reserved beside it, so one
measurement settles and nothing oscillates.

The scrollbar's own inset stopped being a single global constant.
`TableScrollbarGeometry` takes an `inset`, defaulted to the shared value so
every table call site is unchanged, and `WorkbenchScrollView` accepts a
`scrollbarInset` that menus set to `MenuMetrics.scrollbarOuterGap`.

`WorkbenchMenuDivider` replaces the bare `Divider()` in the three menus that had
one, so the line reads as a break between groups instead of an underline
belonging to the row above it. Its ends sit where the items' content starts and
it keeps four points above and below itself. Writing the inset as a distance
from the menu's edge and then giving back the menu's padding is deliberate: the
divider is laid out inside the item stack, which that padding has already moved
in, so the token can state the figure the design system states rather than the
remainder left after the container.

The trailing icon lost its fixed 16pt width and the row's trailing padding drops
two points when that slot holds a glyph rather than text, which is the optical
compensation the requirement names. The row's content gap was a literal 12
against a design system that says `--spacing-2`; it now reads the token, which
also makes the row action menu and the filter menu agree.

The player's speed menu was taking `MenuMetrics.padding` and is outside this
requirement. Its width and height are fixed numbers measured against that
padding, so it now holds the former shared value directly.

## Verification

`swift build`: clean.

`swift test`: 1121 tests. The working tree was stashed and the same suite run on
the requirement commit to separate the pre-existing failures, which are the
usual playback-media, window-geometry and refresh-scope set with membership
varying run to run under parallelism. Two tests failed on the change and both
had pinned the old geometry:
`subtitleTableShioriSubmenuTouchesAndAlignsWithItsParentItem` asserted a 40pt
item and used a literal 200 as "far enough down the menu"; that offset is now
derived from the menu's own metrics so the test states its intent instead of a
density. `subtitleTableViewRightClickMenuIsBoundedByTheTableBody` needs a menu
taller than the table body, and a denser menu now fits inside the fixture's
200pt body, so the fixture's body is cut down until the relationship it tests
holds again. Three further tests appeared in the after-run and not the before-run
(`subtitleFocusDownThenShioriSavesTheFinalSettledCue`,
`subtitleFocusShioriKeySavesIdempotentlyAndKeepsPausedSession`,
`libraryFolderRemovalPublishesProgressWithoutBlockingMainActor`); all three pass
in isolation and belong to that same flake.

Real UI, Debug in-app E2E controller, a Shiori list, Light appearance.
Measurements are from the captured pixels at 2x, converted to points:

| Measured | Expected | Found |
| --- | --- | --- |
| Menu edge to item box | `--padding-menu` | 6.0 |
| Item box to leading icon box | `--padding-menu-item` | 10.0 |
| Menu edge to leading icon box | sum of the two | 16.0 |
| Menu edge to trailing chevron box | padding less the 2pt compensation | 14.0 |
| Menu item height | 32 | 32.0 |
| Menu corner radius | 12 | ~12 |
| Highlight corner radius | menu radius less padding | ~6 |

The row action menu measured 202pt wide around a 190pt item stack, which is the
item stack plus twice the padding and no strip. The filter menu, which scrolls,
measured 179pt around a 153pt item stack: 153 + 6 padding + 6 gap + 8 scrollbar
+ 6 outer gap. Its items end six points before the scrollbar's left edge, the
same six points the row action menu's items keep from its right border.

Dividers, measured on a second pass after the requirement's fourth section was
amended from border-to-border to inset:

| Menu | Divider ends | Against |
| --- | --- | --- |
| Row action | 16.0 from both menu edges | Item content start, which there is the leading icon's box |
| Shiori destination | 16.0 from both menu edges | Item content start, which there is the label — no leading icon |
| Filter (scrolling) | 16.0 from the left edge, 10.0 inside the item stack's trailing edge | Item content on both sides; 16.0 clear of the scrollbar |

Vertically the divider block measures 4.0 above the line and 4.0 below it: an
item ends, four points of white follow, the line, four more, then the next item.

The row action menu's dividers no longer cross x = the item stack's left edge,
which is how the inset was confirmed rather than inferred — a vertical scan
taken inside the menu but outside the item content found no divider pixel at
all.

Dark appearance was not captured. Switching it is a system setting on the
owner's machine, and this change moves no colour token and no theme-dependent
value — the geometry above comes from one code path shared by both appearances —
so there is nothing appearance-specific in it to check. The acceptance item
covering both themes is left for the owner.

## Outcome

Matches the requirement. Every figure in the requirement's acceptance list that
can be measured from a Light capture was measured and matched; the Dark pass is
outstanding and is noted above.
