# A menu gives up height it cannot have instead of being cut off

Human-owned documents:

- `docs/human/requirements/20260906-UI-Menu Shrinks To Available Space Instead Of Being Clipped.md`

## Why

Opening a row menu near the bottom of a short window, or the Shiori submenu on a
window the size of a laptop screen, produced a menu with items missing off its
bottom edge. The submenu could show a scrollbar and still be cut, which is the
part that gives the cause away.

A menu carried two heights that never spoke to each other. One was the content
cap: the menu grew to its items' height and stopped at 480, and the scrollbar
appeared at that moment and no other. The other was the room the menu actually
had on the side it opened on, which decided nothing at all. Placement tried the
space below the anchor, then above it, and when neither could hold the menu
whole it left the menu at the height it had asked for and slid it inside the
boundary as far as it would go. Whatever hung over the edge was cut by the
clip view.

That clip was never meant for this. It belongs to the following rule — a menu
travelling with its row as the table scrolls must not draw over the frozen
header above the body — and it ended up standing in for "the menu did not fit
when it opened", which no rule asks for. Because the scroll threshold was a
constant rather than the room available, the scrollbar could not take the case
over: a menu 480 tall in a body 476 tall scrolls *and* gets cut.

## What changed

**The room on the chosen side is now one of the heights a menu is capped to.**
A menu's height is the smallest of its natural height, `--max-height-menu`, and
the space its side leaves it. Nothing new appears when a menu is held down to
that space: the scrollbar rule the menus already had takes over, which is why
the fix removes a case rather than adding a mechanism.

**Choosing the side needed one new rule.** "Below first, above when it will not
fit below" survives unchanged, because both branches still ask whether the menu
fits *whole*. What could not survive is the old third step: once a menu may
shrink, both sides always "fit", so there has to be something to break the tie.
The menu takes the side with more room, and scrolls the rest. Without that, a
menu opened near the bottom edge would stay below forever and shrink to a
sliver. A menu whose content does not scroll — the player speed menu, the
selected-text menus — keeps the old behaviour; `shrinksToFit` marks the
difference at each call site rather than changing them all.

**A shortened menu is measured twice.** The scrollbar's strip comes out of the
menu's width, so a menu that gains a scrollbar gets wider, and a wider menu's
trailing edge lands somewhere else. The first measurement answers "how tall does
this menu want to be"; only when the answer does not fit is the menu rebuilt
against the room it has and placed again. Menus that fit — nearly all of them —
still measure once.

**The submenu shrinks without flipping.** It has no notion of sides: it aligns
with its parent item and is clamped into the boundary. It now takes the
boundary's height when it cannot have its own, and scrolls the rest.

**The clip stays, for the job it was written for.** A menu that follows its row
up under the frozen header is still cut there. What no longer happens is a menu
being cut at the moment it opens.

Files:

- `apps/macos-native/Sources/CueSeekerApp/Shared/MenuPlacement.swift`
- `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchControls/WorkbenchControls.swift`
- `apps/macos-native/Sources/CueSeekerApp/TableSandbox/SubtitleTableView.swift`
- `apps/macos-native/Sources/CueSeekerApp/TableSandbox/WorkbenchTestLibraryView.swift`
- `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchSchemaSearch/SchemaWorkbenchSearchShell.swift`
- `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchSchemaSearch/CueFacetFilterPanel.swift`

## Verification

`swift build` clean.

`swift test --filter "MenuPlacement|menuSlides|menuOpens|aScrollingMenu|BoundedByTheTableBody|menuPanel"`
and `swift test --filter "subtitleTableShioriSubmenu"`: all passing. Three new
placement cases cover the roomier side above, the roomier side below, and a menu
that still fits whole; one new geometry case covers a submenu held to a boundary
shorter than itself.

`subtitleTableViewRightClickMenuIsBoundedByTheTableBody` was rewritten. It
asserted the old rule directly — the menu taller than the body, and clipped. It
now asserts the menu sits inside the body on both edges, with the clip view
still in place for the following case.

Full `swift test`: 1142 tests, 19 failing. A full run of the same suite on
`ace19ba` — the commit before this change, built in a throwaway clone — fails 20,
and the two sets differ in both directions: `playbackPlaylistCopyAndShiori...`,
`searchFacetSelection...` and `sharedPersistenceMigration...` fail only on the
baseline, and the two library folder removal cases fail only here, passing when
run alone. The stable remainder is the native playback timeline, presentation
and audio families, the cue group refresh scope cases, and the two
`DebugE2EControllerTests` window-geometry cases, all of which fail identically
on the baseline.

In the App, with the Debug E2E controller: a right-click on a row near the
bottom of the window opens the menu upward, complete, with nothing cut off.

## Known limits

The requirement's own acceptance says items 1, 2 and 5 are manual, because the
Debug E2E controller can set the main window's width and not its height. That is
exactly the state that shortens a menu, so the shrink itself could not be driven
from the controller and was not seen in the App on this pass — only in the
placement geometry, under test. Adding a height command would be new end-to-end
capability and was not added.

The submenu could not be opened from the controller either: synthesized pointer
movement lit the trigger but did not expand it, so the Shiori submenu was
verified only through its geometry.

Height is settled once, when the menu opens, as the requirement states. Resizing
the window while a menu is open therefore does not re-shorten it; a table row
menu that overflows in that moment is cut by the following clip, which the
requirement provides for.
