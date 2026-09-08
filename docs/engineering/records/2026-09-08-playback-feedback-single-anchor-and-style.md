# Playback feedback collapses to one top-leading anchor and drops its hardcoded capsule

Human-owned documents:

- `docs/human/requirements/20260908-UI-Playback Feedback Single Anchor And Style.md`

## Why

Playback feedback had three anchors — the centre of the picture and the two vertical mid-edges — so the same class of message landed in three different places and the eye had to find it each time. The centre anchor sat over the part of the frame the viewer is actually watching, and the capsule itself was a 60-point full-radius pill with a 30-point icon and 20-point semibold text, which reads as a button rather than a transient message even though `UI Application Rules.md` says feedback takes no input. None of those numbers came from a token: the component's `Sizes` section in `UI Design System.md` is empty, so every value lived only in the view. The owner asked for the mainstream single-corner behaviour and for the style to be expressible in the design system.

## What changed

- `PlaybackFeedbackPosition` is gone, and with it the `position` argument on every `PlaybackFeedback`. All twenty-odd call sites construct the same shape now; direction is carried by the icon that was already there (`chevron.left` / `chevron.right`), not by where the capsule lands.
- `PlaybackFeedbackOverlay` places one capsule at the stage's top-leading corner: leading inset `--padding-player-chrome-x`, so its left edge is the vertical line the window controls and the bottom bar already start on, and top inset `--height-app-topbar` plus `--spacing-3`, so it clears the topbar band whether or not the topbar is drawn. The inset is a constant rather than a function of the chrome's visibility, so the capsule does not move when the Player UI hides, fullscreen toggles, or an overlay opens over it.
- The capsule is `--height-control` tall with `--radius-menu` corners, `--spacing-3` horizontal padding and `--spacing-2` between icon and label; the icon is `--size-player-circle-button-icon`, the label `--font-size-body` at `--font-weight-control`, both `--color-player-text-primary`. The icon's own drop shadow is gone — the container casts the only shadow, as `UI Design System.md` requires. The surface is unchanged in substance: `--color-player-menu-bg` under `.ultraThinMaterial`, a `WorkbenchControlMetrics.hairlineWidth` border and `PlaybackTheme.overlayShadow*`, which is the recipe the speed menu already uses.
- The label is monospaced-digit and capped at `--width-player-topbar-title-max` with tail truncation, so a long Shiori list name cannot run across the picture. The capsule takes its ideal width: without `fixedSize` the stage proposes the whole window, the label's ceiling becomes its width, and every capsule renders as wide as the longest one can be — that was caught in the first E2E pass and fixed before the geometry checks below.
- Motion is `ToastCenter.motion`, the existing Toast Motion constant, replacing a local `easeOut(0.14)`. Only the capsule's presence animates; its content swaps in place, so a held-down seek key redraws the counter without the capsule fading under it. The entering scale anchors on the top-leading corner so the left edge is fixed through the transition.
- The feedback expiry now clears both seek accumulators instead of choosing by position. In every reachable path this is the behaviour that was already there: a forward seek zeroes the rewind accumulator on the way in and vice versa, and every absolute seek — which is what result, bookmark and video navigation perform — zeroes both. The one sequence that differs is a rewind followed by a feedback that performs no seek at all, such as `No Result`, followed by another rewind: the counter used to resume from the earlier total across the unrelated message and now restarts. That is an artifact of keying the reset off the message's position rather than off the seek, and the requirement's "keep the accumulation as it is" is about the accumulation itself.
- `PlaybackNormalShortcutTests` loses three `position` expectations. The icon and text expectations in the same tests are untouched and still carry the value.

Files:

- `apps/macos-native/Sources/CueSeekerApp/Playback/PlaybackFeedbackOverlay.swift`
- `apps/macos-native/Sources/CueSeekerApp/Playback/PlaybackViewModel.swift`
- `apps/macos-native/Tests/CueSeekerAppTests/PlaybackNormalShortcutTests.swift`

## Verification

Debug in-app E2E controller, main window 1445×821, Light appearance, English, one video opened from the first Recent Videos card. Feedback was triggered by the documented playback keys — space, the arrows, `q`, `p`, `d`, and `c` inside Subtitle Focus — with a 0.3 s settle before each capture, since the capsule fades in over `--duration-toast-motion` and its own life is under a second. Capsule geometry was measured from the captures by scanning the band the requirement assigns it, rather than read by eye.

- Idle, with no feedback pending: no capsule in the band.
- `Pause`, `+ 5s`, `+ 20s`, `100%`, `Subtitles Off`, `Screenshot Copied`, `Next Library Video`, `Cue Text Copied`: every one at the same corner, none over the picture's centre or the subtitle band.
- Left edge measured 24.0–24.5 pt in every state, including `+ 5s` against `+ 20s`, so the accumulating counter grows to the right and the left edge does not move. Top edge 57 pt and height 40.0 pt on the two captures whose surroundings are light enough to measure the rounded corners cleanly (`Cue Text Copied` over Subtitle Focus, `Next Library Video` over a bright frame); on frames with dark content beside the capsule the scan cannot separate the two, and those were read visually instead.
- With Subtitle Focus open, `c` shows `Cue Text Copied` at the same anchor, above the overlay and below its top bar — the overlay's bar is the same 45-point band — so the copy feedback that the layer ordering exists for is both visible and non-overlapping.

`swift test --filter CueSeekerAppTests`: 793 tests, 8 issues, in three suites that have nothing to do with feedback. `DebugE2EControllerTests` and `LibraryFolderRemovalTests` pass in isolation, which is the load-dependent family the earlier records describe. `CueGroupRefreshScopeIntegrationTests` still fails `showCueGroupInvalidationIsScopedToMountedShiori` and `shioriTableStartsAtTopAfterPanelRemount` in isolation — the same two cases, on the same two expectations, that `2026-09-08-playback-topbars-share-one-layout.md` records as failing on that commit's parent. Every playback suite passes: `PlaybackNormalShortcutTests`, `PlaybackStoreTests`, `PlaybackShioriOverlayTests`, `PlaybackSubtitleFocusKeyboardActionTests`, and `WorkbenchControlMetricsTests`.

## Known limits

The first Recent Videos card was reached with a coordinate read off a capture. The card coordinates in `docs/engineering/08_end_to_end_testing.md` §13 and §16 predate the Workbench topbar and sidebar changes of the last few days and no longer point at the controls they name; the sidebar item centres are still derivable from the tokens and were derived, but the Recent grid's are not. The deviation is recorded here rather than made silently, and the gate the coordinates belong to was not run.

Dark appearance and the Simplified and Traditional Chinese strings were not captured — switching either means changing the owner's settings from inside the App. The label is a single line of localized text in a self-sizing capsule with a 520-point ceiling, so the risk is confined to a longer translation truncating earlier.

The `Save to Shiori` capsule at its truncation ceiling was not captured: it needs a list whose name is long enough to reach 520 points, and none in the owner's data is.

`UI Design System.md` still describes the component with the generic popover tokens, an empty `Sizes` section, and a three-valued `Position` on `Playback Feedback Overlay Layout`, and still places the layer below the Playback Overlay and the Command Panel where the App has always placed it above. Per the owner's instruction the design documents are updated after this round of UI tuning is accepted, so that gap is expected until then.
