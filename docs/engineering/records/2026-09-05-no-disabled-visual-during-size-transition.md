# The size-transition freeze stops being visible

Human-owned documents:

- `docs/human/requirements/20260905-UI-No Disabled Visual During Size Transition.md`

## Why

The Workbench freezes its chrome while a window or video size transition runs, so a click cannot land mid-animation. The freeze was written as a disabled state: the back button, the sidebar toggle and every sidebar item switched to `--color-text-disabled` and took a further `0.62` opacity on top. Double-clicking the title bar starts the same freeze — it has done so since `181b64a0` (2026-05-08), which introduced the freeze and wired the title-bar zoom into it without a requirement of its own — so a plain window zoom greyed out the whole sidebar for the length of the animation. Only the Settings item stayed normal, because it is the one item hard-coded as always enabled, which is what made the effect look arbitrary on screen.

Two separate faults, then: the freeze had no business changing anything on screen, and the `0.62` opacity exists in no design document at all.

## What changed

Input is untouched — the same controls are still disabled for the same durations, and the title-bar zoom still starts the freeze. Only the appearance stopped following it.

- `AppSidebarItemLabel`, `AppSidebarChildItem`, `AppSidebarItemButtonStyle`, `AppSidebarNavigationItem`: the colour and opacity of a sidebar item no longer read the enabled flag. Selected keeps `--color-app-sidebar-item-selected-content`; everything else keeps `--color-text-primary` / `--color-text-secondary`. The two `0.62` overlays are gone. The items still take `.disabled(!isEnabled)`.
- The sidebar toggle keeps `--color-text-secondary` through the freeze.
- The back button needed its two reasons separated: "there is nowhere to go back to" is a real Disabled state the Design System keeps (`App Topbar Layout` → Primary Page: Back Disabled), while the freeze is not. `WorkbenchIconButton` gained `isFrozen`, which disables its button from inside its own body, so the glyph colour still answers the caller's `isEnabled` and only the legitimate reason is visible. The call site now passes `.disabled(!routeState.canNavigateBack)` and `isFrozen: layoutState.isVideoSizeTransitionInProgress`.

Files:

- `apps/macos-native/Sources/CueSeekerApp/Workbench/ContentView.swift`
- `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchControls/WorkbenchControls.swift` — the `isFrozen` parameter; every other caller keeps its default and is unchanged.

## Verification

Debug E2E controller, main window 1445×821: the Workbench in its resting state is unchanged — Search selected with the accent pill and white content, the other items at full contrast, Settings unchanged, and the back button still showing its Back Disabled grey on a primary page. `--color-text-disabled` and `0.62` no longer appear anywhere in `ContentView.swift`.

The requirement's first two acceptance points ask what the three controls look like *during* the animation. The controller has no title-bar double-click command and no timed capture inside a ~0.25 s window, so that comparison cannot be automated with what the project has; the owner accepted it as a manual check rather than grow the test infrastructure for it.

Full `swift test`: 1132 tests, 29 issues, in the families the earlier records list as failing on the baseline tree — native playback timeline and audio, library folder removal, cue group refresh scope, the Debug E2E window-geometry cases. The same suite was run on the unmodified tree for comparison and failed in the same families; the four cases that failed only under the changed run pass alone (`swift test --filter "libraryFolderRemovalAndIndexingRejectEachOther|playbackPlaylistCopyAndShioriTargetTheSettledPrimaryCue|subtitleFocusDownThenShioriSavesTheFinalSettledCue|subtitleFocusShioriKeySavesIdempotentlyAndKeepsPausedSession"`: 4 tests pass), and one case that failed only on the baseline run passed under the changed one. No test references the freeze or the sidebar's colours.

## Known limits

The `Disabled` state that `UI Design System.md` still lists for `Sidebar Item` and `Sidebar Toggle` now has no trigger left in the App. The requirement defers that cleanup to the document pass after this round of UI tuning is accepted.
