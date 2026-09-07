# Keeping the highlighted menu item visible moves from one menu to the surface they all share

Human-owned documents:

- `docs/human/requirements/20260907-Bug-Menu Keyboard Highlight Stays Visible.md`

## Why

The rule was already written: `2.4 Menus / Menu / Shared / States / Open` says that a highlighted item outside the visible range makes the menu scroll to it, and it says that under the generic Menu, not under one variant. Only the filter menu obeyed it.

The mechanism to obey it was already there too. `MenuHighlightModel` publishes `keyboardMoveCount`, bumped by keyboard moves and by nothing else, and its own comment says it exists so a scrolling menu can bring the new highlight into view. What was missing is where the reveal was written: inside `CueFacetFilterMenu`, one menu's view, rather than in the surface every menu is built on. So the behaviour existed exactly where somebody had typed it, and every other menu — the table row menu, the Shiori destination menu and its submenu, the card context menu, the selected-text menu — had nothing.

That stayed invisible while those menus were short enough never to scroll. The Shiori destination menu is the one that grew: with fourteen lists it outgrows the cap, and arrowing down walked the highlight off the bottom edge with the menu standing still.

The same class of gap covers opening. `Save to Shiori` opens on the list saved to most recently, which in a long list is somewhere in the middle — highlighted, and off screen. The requirement adds that case, and it lands in the same place as the keyboard one.

## What changed

`WorkbenchPopoverPanel` — the single surface behind all five menus — now takes the open menu's highlight model, wraps its scroll view in a `ScrollViewReader`, and reveals the highlighted item on appear and on every keyboard move. The reveal is `scrollTo` with no anchor and no animation: the least scrolling that makes the item whole, immediately. The wheel and the scrollbar bump neither signal, so they still move the content under a fixed highlight and the menu never snaps back.

For the reveal to find an item, each menu item now carries `.id` of its own position — the same integer the highlight model uses. The filter menu's local `ScrollViewReader` and its `onChange` are gone; it gets the behaviour from the surface like everyone else.

The player speed menu is not built on this surface. It is short, never scrolls, and is untouched.

Files:

- `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchControls/WorkbenchControls.swift`
- `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchSchemaSearch/CueFacetFilterPanel.swift`
- `apps/macos-native/Sources/CueSeekerApp/Shiori/ShioriDestinationMenu.swift`
- `apps/macos-native/Sources/CueSeekerApp/TableSandbox/SubtitleTableView.swift`
- `apps/macos-native/Sources/CueSeekerApp/TableSandbox/WorkbenchTestLibraryView.swift`
- `apps/macos-native/Sources/CueSeekerApp/Playback/SubtitleFocus/PlaybackSubtitleFocusReel.swift`
- `apps/macos-native/Tests/CueSeekerAppTests/MenuPanelHeightTests.swift`

## Verification

`swift build` clean.

`swift test`: 1142 tests. The failing set is the one already on record — native playback media and presentation, the Debug E2E scene and window tests, the library-removal and `CueGroupRefreshScopeIntegrationTests` order-dependent ones. `progressiveSearchProjectionRefreshesOnlyMountedTable`, which appears in that suite's failures, passes on its own, so it is order-dependent like its neighbours. `swift test --filter Menu`: 84 tests, all pass.

Debug E2E controller, `swift run CueSeeker --cueseeker-debug-e2e`, against the real library, main window 1445×821. Nothing was saved, moved, or removed: every menu was closed with Esc, never Enter, and the Shiori list still reported 397 results at the end.

Filter menu, Search page, thirty-odd options and a scrollbar:

1. Open: `<1s` highlighted at the top.
2. Twelve Down presses: the menu scrolled and `Traditional Chinese` sits complete against the bottom edge — the least scrolling that shows it.

`Save to Shiori`, Playback Overlay footer, fourteen lists and a scrollbar:

3. Open on `我喜欢的字幕`; twelve Down presses land on `8`, still inside the visible range, and the menu correctly does not move.
4. Two more: `New List` is revealed whole at the bottom and the first row is now clipped above.
5. Fourteen Up presses: back at the top with `我喜欢的字幕` whole.
6. Wheel over the open menu: the content scrolls, the highlight stays on `我喜欢的字幕` and slides out of view with it, and the menu does not pull itself back.

`Move to ...` submenu, Shiori list detail row menu, thirteen destinations and `New List`:

7. Right arrow opens it on `第二个列表` with a scrollbar and `New List` clipped.
8. Thirteen Down presses: `New List` revealed whole at the bottom, first row clipped above.

Acceptance item 7 — the table row menu and the card context menu made to scroll by a short window — is manual. The controller sets width only, as recorded for `20260906-UI-Menu Shrinks To Available Space Instead Of Being Clipped`. No E2E capability was added.

Unrelated observation for the owner, not touched by this change: the Recent page's Shiori cards and the Shiori page disagree by one cue on two lists (`我喜欢的字幕` 396 vs 397, `第二个列表` 88 vs 89). Both were read before any menu was opened in this session.
