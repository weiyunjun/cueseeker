# The top bar becomes one row, and fullscreen keeps it

Human-owned documents:

- `docs/human/requirements/20260909-Bug-Topbar Layout In Narrow Window And Fullscreen.md`

## Why

Four defects, one shape: every top bar drew its left half, its centre and its right half as three overlays pinned to their own edges, so none of them knew how much room the others had taken.

- On the Workbench that meant the page title ran underneath the Task and Settings buttons as soon as the sidebar was expanded in a narrow window. The page beside it already had the answer — below `--min-width-workbench-page-content` a page stops shrinking and scrolls sideways — but the top bar was not part of that page, so it kept using the window's full width and pinning its buttons to the window's right edge.
- On the playback page the title had a fixed 520pt maximum and nothing else, so in a 480pt window it spread across the whole bar, over the window controls on one side and the App entries on the other.
- The playback page's bar was removed outright in fullscreen, so the way back, the title and the App entries all disappeared with it.
- The sidebar's auto-collapse test ran off the window root's width, and the playback page only omits the sidebar and top bar from the tree rather than replacing the root. Narrowing the window during playback therefore collapsed a sidebar nobody could see, and since a collapsed sidebar never re-expands on its own, the Workbench came back collapsed.

## What changed

**The Workbench top bar is one row with the page.** `AppTopbarLayout` merges the two content overlays into a single `HStack` — Back, Forward, the title, a spacer, then the trailing entries — laid out at `max(regionWidth, pageContentMinimumWidth)` inside a clipped container that starts where the sidebar segment ends. Because the title yields before the spacer does, it truncates instead of running under the buttons; because the row is offset by the page's own horizontal scroll, it travels with the page when the region is below the minimum, and the trailing buttons come back into view with the rest of the page. The window controls and the Sidebar Toggle stay outside the row and never move.

The offset reaches the bar through the mechanism that already exists rather than a new one. `WorkbenchScrollView`'s bridge already watches the scroll geometry to drive the Scrollbar overlays; it now also reports the horizontal offset to a `WorkbenchPageScrollOffset` picked up from the environment. The App shell puts that object in the environment around the pages only, so the five page-level horizontal scroll views report and the playback ones do not, with no change at any call site. It is a small object of its own, held on `WorkbenchLayoutState` but not published by it, so only the top bar re-reads on scroll.

**Titles take what the two sides leave.** `PlaybackChromeMetrics` gained the two numbers both playback bars need: where the return button starts, and how wide a centred title or Tabs may be — the bar minus twice the wider side, so it keeps the bar's centre line and reaches neither side. The player title still has its `--width-player-topbar-title-max` ceiling and now takes the smaller of the two, and it truncates in the middle, because the title reads `name - sequence` and the sequence must survive.

**Fullscreen keeps the bar.** The player top bar is no longer conditional on fullscreen; it follows the Player UI in both, exactly as the bottom control bar does. The return button reads a new `\.isAppFullscreen` environment value — set once by the App shell from the window's own fullscreen state — and drops the window controls' reserved band when the system titlebar owns them, which fixes the Playback Overlay's bar too: it was always shown in fullscreen and always left that gap.

**The sidebar test belongs to the Workbench.** The width test is skipped while the playback page is up and runs once on the way back, against the width in effect then.

Files:

- `apps/macos-native/Sources/CueSeekerApp/Workbench/AppTopbarLayout.swift`
- `apps/macos-native/Sources/CueSeekerApp/Workbench/ContentView.swift`
- `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchScrollView.swift`
- `apps/macos-native/Sources/CueSeekerApp/Shared/AppWindowControls.swift`
- `apps/macos-native/Sources/CueSeekerApp/App/WorkbenchLayoutState.swift`
- `apps/macos-native/Sources/CueSeekerApp/Playback/PlaybackTheme.swift`
- `apps/macos-native/Sources/CueSeekerApp/Playback/PlaybackVideoStage.swift`
- `apps/macos-native/Sources/CueSeekerApp/Playback/TopBar/LiquidGlassVideoTopBar.swift`
- `apps/macos-native/Sources/CueSeekerApp/Playback/TopBar/PlaybackReturnButton.swift`
- `apps/macos-native/Sources/CueSeekerApp/Playback/SubtitleFocus/PlaybackSubtitleFocusOverlay.swift`

## Verification

Debug E2E controller. No E2E capability was added; fullscreen turned out to be reachable through the existing `keyPress` command with `f`.

- Window 480, sidebar expanded: the title stands clear of the Task and Settings buttons, which have travelled off the right edge with the row. Dragging the page's horizontal Scrollbar brings them back into view while Back, Forward and the title leave to the left — bar and page move together.
- Collapsing the sidebar at 480 removes the horizontal scroll and puts the trailing buttons back against the window's right edge.
- Playback at 480 with a long folder name: `千与千寻千与…千与千寻 - 01`, centred, clear of the window controls and of the trailing buttons, sequence intact. Before the change the same title covered the whole bar.
- Playback Overlay at 480: return button, centred Tabs, and the Collage, Task and Settings buttons, none of them overlapping.
- Fullscreen, player page: the bar is there. It is hidden with the Player UI and returns with it; the return button sits at the bar's own padding with no empty window-controls band, the title is centred and middle-truncated, the App entries are at the right.
- Fullscreen, Playback Overlay: the return button is at the same leading padding.
- Sidebar expanded at 900 → open a video → 600 → 900 → return: still expanded. Same path leaving at 600: collapsed, as the rule asks.

`swift test`: 1171 tests. The failing set is the one this suite already produces on the parent commit — native playback timeline and audio, native presentation transitions, cue-group refresh scope, library folder removal, and the Debug E2E window-geometry cases — with two of them (`libraryFolderRemovalPublishesProgressWithoutBlockingMainActor`, `searchFacetSelectionDoesNotRefreshGlobalOrInactiveSurfaces`) passing here and failing on the parent, which marks them flaky rather than fixed. `CueGroupRefreshScopeIntegrationTests` was also run alone on the parent and on this change: identical two failures either way, so the added scroll reporting does not widen any invalidation scope.

## Known limits

A synthesized `mouseMove` does not wake the Player UI, so on the playback page the return button can only be reached through the Playback Overlay, which the `enter` key opens. That is a controller limitation, not a product one.

The design documents still describe the old behaviour: the App Topbar Layout has no minimum width or scrolling, the Player Topbar Layout has no fullscreen state, and Player Title still says tail truncation. Per the owner's instruction they are updated after this round of UI tuning is accepted; the requirement's UI 文档同步 section lists what to change.
