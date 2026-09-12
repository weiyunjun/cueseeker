# Toast follows Playback Feedback and both wrap

Human-owned documents:

- `docs/human/requirements/20260912-UI-Toast Follows Playback Feedback And Both Wrap.md`
- `docs/human/design/Icon Registry.md` (the icon size the toast draws at)
- `docs/human/design/UI Design System.md` and `docs/human/design/UI Application Rules.md` (to be updated by the owner after acceptance)

## Why

The Workbench reported a result on a popover surface — a white or near-black card with a shadow, 14 px text, no icon — while the playback surfaces reported the same result on a dark blurred capsule with an icon. One event therefore looked like two, and the popover card was the weaker of the two. The owner chose the capsule for both and settled the two structural questions it raised: the capsule stays the same in Light and Dark because it sits over the content rather than in it, and the message wraps on both surfaces instead of being cut at a fixed width.

The toast's own rules were wrong in ways that showed. Its stay paused while the pointer rested on it, and the stack is anchored at the window's centre, which is exactly where a resting pointer tends to be: a toast that appeared under a still pointer never timed out. Its stay also paused when the app lost focus, which is not what a browser's `visibilitychange` means on macOS — the window is usually still on screen — so a toast froze in place while the owner worked in another app. A fifth result waited in a queue for five seconds instead of being shown, arriving long after the action that caused it. The same result reported twice stacked twice, because the scenario ID was recorded and never read. And the toast swallowed clicks that landed on it, contradicting the rule that it is only visual.

Classified as platform UI and UX. No product semantics move; nothing in `CueSeekerCore` changes.

## What changed

- The toast takes the Playback Feedback surface: `--color-player-menu-bg` with the blur, the 30 % hairline border, `--radius-playback-feedback`, and no shadow. It is the same in Light and Dark.
- Its message is 16 px in `--font-weight-control`, one step up from the body size and one step below the playback capsule's 18 px, and it carries a 23 px icon — one of the sizes `Icon Registry.md` documents. `ToastRequest` gained the icon and its weight, and every Shiori request is built by one helper so both surfaces name the same icon for the same event.
- The icon has its own column on both surfaces, aligned to the centre of the message's first line rather than to the centre of the block, so it does not drift into the gap between lines when a message wraps. The alignment is one shared custom `VerticalAlignment` plus one helper that reads the first line's height from the font.
- Both surfaces wrap. The width is the smallest of the content's width, the surface's own ceiling, and the window's width less the viewport margin on each side: `--width-toast-max` is 400 px, the new `--width-playback-feedback-max` is 520 px, and both use `--spacing-6`. The playback capsule no longer borrows `--width-player-topbar-title-max` and no longer truncates.
- `--height-playback-feedback` became a minimum height rather than a fixed one. A single line still measures exactly 52 px; only a wrapped message grows past it. The capsule's vertical padding is `--spacing-2`, small enough to stay inside that floor on one line and to give a wrapped message its own room.
- The newest toast's centre is the window's centre and older ones stack above it, so the place the eye returns to does not move with the count. The stack measures the newest toast and offsets itself by half that height.
- A toast's stay is a wall-clock deadline set when it appears. Nothing pauses it. One task sleeps until the earliest deadline instead of a timer polling ten times a second.
- Over the limit, the oldest toast leaves at once; there is no queue. A result whose scenario ID and message match a visible toast keeps that toast's identity, moves it to the newest place and starts its stay over.
- The toast takes no pointer input at all: the hover tracking is gone and the stack does not hit-test, so a click lands on the table underneath.
- Removed with the above: the visible/queued split, the remaining-duration table, the hover set, the app-active flag and its two notification observers, and the 0.1 s timer.

Files:

- `apps/macos-native/Sources/CueSeekerApp/Shared/Toast.swift`
- `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchControls/WorkbenchControls.swift`
- `apps/macos-native/Sources/CueSeekerApp/Playback/PlaybackFeedbackOverlay.swift`
- `apps/macos-native/Sources/CueSeekerApp/Playback/PlaybackTheme.swift`
- `apps/macos-native/Tests/CueSeekerAppTests/ToastTests.swift`

## Verification

`ToastTests` were rewritten around the new rules and drive the centre through injected dates: five results leave the last four visible with no queue; a repeated result keeps its identity, takes the newest place and expires from the later deadline while the other toast expires from the earlier one; a stay ends on the wall clock with nothing able to hold it. The registry test also pins the icon and its weight.

A first attempt at this change drew the toast icon at 24 px, which `Icon Registry.md` does not document, and the app trapped on the line width lookup the moment a toast was drawn — a Debug crash, and in Release a silent fall back to the master width. Nothing caught it: the size is a dictionary key, so the build is clean; no test drew an icon at that size; and the App pass never reached a toast. `feedbackIconsDrawAtTheirDocumentedSizes` now draws the Shiori icon at both surfaces' sizes and checks both are in the table. Setting the toast's size back to 24 fails that test and reproduces the original trap, so the guard is the real one. Toast suite: 6 tests, all passing.

`swift test`: 1207 tests, 16 failures. Fifteen are the names that fail on a clean `584404ea` tree — the native playback timeline, audio, presentation and auto-pause cases, the refresh-scope counts, the Debug E2E scene-geometry cases and the persistence migration case. The sixteenth is `libraryFolderRemovalAndIndexingRejectEachOther`, one of the two tests that flip between runs under the full suite in both directions and pass when run alone. No failure names the toast or the feedback capsule.

In the App: Debug E2E controller, main window 1445×821 at 2×, Light appearance. The app launches and runs with no trap. With the video paused so the picture is static, the volume feedback was captured and measured against the same frame without it. The capsule measures **114.5 × 52.0 points** and its centre lands on the stage centre (1445, 820.5 against 1445, 821). The single-line height is therefore unchanged by the move to a minimum height, and the anchor is unchanged.

Not verified here: the Workbench toast's appearance, the wrapped two-line case on either surface, the stacking order, and the narrow-window clamp. Every Workbench toast is reached through the Shiori destination submenu, and the Debug E2E controller does not open a submenu — the context menu opens on a right click and its items highlight under the arrow keys, but neither the right arrow nor a pointer move opens `Duplicate to …`. There is no other path to a Workbench toast: the selection overlay's actions are the export ones, and the recent-save list only marks a row inside that same menu. This gap is what let the 24 px size reach the owner's own run, and it is recorded here and in `docs/engineering/08_end_to_end_testing.md`'s terms; no E2E facility was added.

Outcome matched expectations as far as the controller could observe.
