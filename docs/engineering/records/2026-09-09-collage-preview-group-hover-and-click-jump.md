# The Collage preview frames the hovered group, and a click sends the reel to its first cue

Human-owned documents:

- `docs/human/requirements/20260909-UI-Collage Preview Group Hover And Click Jump.md`

## Why

The Collage preview showed one composed image and nothing connected it back to the cue reel: to find the cues behind a strip, the reader had to scroll the reel by hand. The requirement adds the one pointer interaction that closes that gap — an accent frame on the group under the pointer, and a click that sends the reel to that group's first cue — under the hover rules the rest of the App already follows: only a real pointer movement decides the frame, the wheel never moves it, and a new picture clears it until the pointer moves again.

## What changed

### Step 1 — strips published with the image, and the hover frame

- Composing a collage now returns the image together with each group's height in it. The first group is its whole frame, every later group is its subtitle bands stacked, so the heights fall out of the composition itself and no second geometry source exists. The export path and the Collage export test read `.image` from that result.
- The preview store publishes, with every image, one segment per strip in display order: the strip's height and the reel ordinal of the first cue of the group actually drawn there. For a stand-in — a changed group whose old image is kept in place until the new render lands — that is the old group, because that is the picture on screen. Image and segments are set in one call, so a click always reads the segments of the picture it was made on.
- The preview's AppKit container installs a local monitor for pointer movement and reads the event's own location, the way the Workbench table does, so a synthesized move from the Debug E2E controller drives it as well as a real one. A movement puts the frame on the strip under the pointer, or takes it away when the pointer is on the blank area, off the image, or outside the viewport. A new image clears the frame and the pressed strip; nothing else changes them. While the pane is frozen — covered by the Command Panel, or under a menu on the overlay — movements and clicks are ignored, which the pane reads from its interface layer context now that it is put on the overlay's layer like the top bar.
- The frame is a view inside the scroll document, so it scrolls with the strip. It strokes the search field's focus border colour (`--color-border-focus`, the system accent) at the new `--border-width-control` width, inset by half the width so the image edges do not clip it; no radius.
- A press remembers the strip under the pointer; the release acts only inside that same strip, moves the frame there, and hands the strip's first-cue ordinal to the pane's callback. The document view answers hit tests for itself so the image view, a control, cannot keep the click.
- `WorkbenchControlMetrics.redesignControlBorderWidth` (`--border-width-control: 1px`) is the code-side token; the search field's stroke reads it instead of its literal.

Files:

- `apps/macos-native/Sources/CueSeekerPlayback/SubtitleScreenshotExporter.swift`
- `apps/macos-native/Sources/CueSeekerApp/Playback/SubtitleFocus/PlaybackCollagePreviewStore.swift`
- `apps/macos-native/Sources/CueSeekerApp/Playback/SubtitleFocus/PlaybackCollagePreview.swift`
- `apps/macos-native/Sources/CueSeekerApp/Playback/SubtitleFocus/PlaybackSubtitleFocusOverlay.swift`
- `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchControls/WorkbenchControls.swift`
- `apps/macos-native/Tests/CueSeekerPlaybackTests/SubtitleScreenshotExporterTests.swift`
- `apps/macos-native/Tests/CueSeekerAppTests/PlaybackCollagePreviewTests.swift`

## Verification

Step 1: `swift build` clean. The 12 Collage preview tests pass, three of them new — the store publishes a segment per drawn group with the stand-in naming the group drawn, the frame follows only real pointer movement and is cleared by a new image and held while frozen, and a click acts only on release inside the pressed strip. The composition test now also checks the group heights `[10, 5]`. One thing the tests taught: a view without a window converts "window" points from its top-level view's unflipped base coordinates, so the tests give pointer points as distances from the container's bottom.
