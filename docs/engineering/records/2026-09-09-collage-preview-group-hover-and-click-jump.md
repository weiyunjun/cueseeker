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

### Step 2 — the click reaches the reel

- The session store's keyboard navigation already carried an absolute target ordinal to the reel, which animates to it with the reel transition the wheel uses, loads the window around a far target, and commits the selection on arrival. Its body is now the shared `requestNavigation`, given a function from the current target to the next one: a key asks for the neighbour, a Collage strip asks for its first cue. The direction the request carries is derived from the two ordinals, which for a key is the key's own direction. A target equal to the current one asks for nothing, so a click on the strip already in focus leaves no pending request behind.
- `jumpToCollageCue(ordinal:)` is that entry, refused outside Collage editing, and otherwise under exactly the gate a key is under: no pending or running action, and no wheel motion in flight unless a request is already pending. It moves the focus only; the selection plan is untouched.
- The overlay hands the pane's click to that entry through the Collage editor.

Files:

- `apps/macos-native/Sources/CueSeekerPlayback/SubtitleScreenshotExporter.swift`
- `apps/macos-native/Sources/CueSeekerApp/Playback/SubtitleFocus/PlaybackSubtitleFocusSessionStore.swift`
- `apps/macos-native/Tests/CueSeekerAppTests/PlaybackSubtitleFocusSessionStoreTests.swift`
- `apps/macos-native/Sources/CueSeekerApp/Playback/SubtitleFocus/PlaybackCollagePreviewStore.swift`
- `apps/macos-native/Sources/CueSeekerApp/Playback/SubtitleFocus/PlaybackCollagePreview.swift`
- `apps/macos-native/Sources/CueSeekerApp/Playback/SubtitleFocus/PlaybackSubtitleFocusOverlay.swift`
- `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchControls/WorkbenchControls.swift`
- `apps/macos-native/Tests/CueSeekerPlaybackTests/SubtitleScreenshotExporterTests.swift`
- `apps/macos-native/Tests/CueSeekerAppTests/PlaybackCollagePreviewTests.swift`

## Verification

Step 1: `swift build` clean. The 12 Collage preview tests pass, three of them new — the store publishes a segment per drawn group with the stand-in naming the group drawn, the frame follows only real pointer movement and is cleared by a new image and held while frozen, and a click acts only on release inside the pressed strip. The composition test now also checks the group heights `[10, 5]`. One thing the tests taught: a view without a window converts "window" points from its top-level view's unflipped base coordinates, so the tests give pointer points as distances from the container's bottom.

Step 2: the 63 session, overlay, keyboard-action and Collage tests pass, one new — a strip click outside Collage editing is refused, inside it issues a request for the given ordinal with the direction derived from the current focus, leaves the plan alone, and asks for nothing once the focus is already there.

### Step 3 — end to end

Sample: `It's MyGO!!!!!` episode 05, Debug build, driven by the Debug E2E controller the way the two previous Collage records were: `swift run CueSeeker --cueseeker-debug-e2e` on a PTY, Library card at (837, 389), episode at (1294, 366), Enter, `P`. Scene 1445 × 821 at 2×. Checkbox column x = 768, rows at y = 158 / 239 / 479 / 560; the first click only activated the app, so `毫不团结` stayed unticked and the plan had three groups: `バラバラ` alone, the focused `目標が`, and the `13:20` pair. Preview coordinates were read off the captures and are not accepted procedure coordinates.

- `hover-first-strip`, `hover-second-strip`, `hover-third-strip`: `mouseMove` to (300, 300), (300, 500), (300, 540). The accent frame surrounds the whole first frame, then the `目標が` band, then both bands of the `13:20` group as one frame — one frame per group, at the strip's exact width and height, inside its edges.
- `after-click-first-strip`: `click` at (300, 300). The reel travels to `バラバラ` (13:15), now the bold focused cue; its checkbox is unchanged; the frame sits on the clicked strip.
- `after-return-no-frame`: pointer left on the third strip, then Return unticks the focused `バラバラ`. The preview republishes as `目標が` full frame plus the `13:20` band, and no frame is drawn under the still pointer.
- `move-onto-band`: one movement to (300, 500) puts the frame on the band. A first movement of one point had landed on the blank area under the now shorter image and drawn nothing, which is the blank-area rule, not a miss.
- `off-image-no-frame`: (300, 700), below the image: no frame.
- Covered by the Command Panel: not producible from the keyboard. While Collage is being edited the playback key handler answers every key but P, Esc, Return and the arrows itself, so `K` does not open the panel and Esc leaves Collage editing instead. The frozen path is the unit-tested `isInteractionEnabled` gate, read from the same interface-layer context the top bar and the cards use.
- Wheel scrolling of the preview was not exercised: at this window size the image fits the viewport. The frame is a subview of the scroll document, so it moves with the image by construction; the rule is a manual acceptance item.
- The pointer shape is not visible to the controller; the preview declares no shape of its own, so the arrow stays.

Full `swift test`, 1171 tests: 15 names failed, every one in a family earlier records already list as failing on this tree — native playback audio and seeking (`nativeAutoStopKeepsSessionAliveAndResumesFromBoundary`, `nativePlaybackNotifiesNaturalCompletionAfterAudioDrain`, `nativePlaybackRebuildsAudioOutputAndContinuesInCurrentSession`, `nativePlaybackUsesCommonTimelineWhenVideoTrackStartsAfterAudio`, `nativeRapidSeeksCommitOnlyLatestPresentationGeneration`, `nativeSeekAndOpenRetainPresentedImageUntilCurrentGenerationCommits`, `playbackPlayerKeepsAutoPauseBoundaryAcrossUserSeeks`), library folder removal (`libraryFolderRemovalAndIndexingRejectEachOther`, `libraryFolderRemovalPublishesProgressWithoutBlockingMainActor`), the Debug E2E window geometry (`sceneUsesVisibleWindowUnionAndTopLeftCoordinates`, `setWidthResizesMainWindowAndInvalidatesScene`), and the Search and Shiori refresh-scope integration tests (`progressiveSearchProjectionRefreshesOnlyMountedTable`, `searchFacetSelectionDoesNotRefreshGlobalOrInactiveSurfaces`, `shioriTableStartsAtTopAfterPanelRemount`, `showCueGroupInvalidationIsScopedToMountedShiori`). None touches the Collage editor, the subtitle focus session, or the preview.

## Design documents

Deferred to acceptance, as the requirement says: `--border-width-control: 1px` under 1.3 尺寸; `Border Width：--border-width-control` on the Search Field container; a Collage Group Frame entry and a Group Hovered state under Playback Collage Editor Layout; and the four Collage rules under Hover 与选中 in the application rules. Proposed text is provided on request; the AI does not edit `docs/human/`.
