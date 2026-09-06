# The pointer shape stops at the edge of the main window

Human-owned documents:

- `docs/human/requirements/20260906-Bug-Pointer Shape Sticks On Other App Windows.md`

## Why

With the Settings window open, moving the pointer from a subtitle in the table into the Settings window left the hand cursor standing on a window that has no hand anywhere in it.

Two things kept it there, and either one alone reproduces the symptom.

The App holds one decided shape and puts it back at the end of every run loop pass, so that a scroll or a layout change under a still pointer cannot flicker it back to the arrow. The test for "is this pointer still mine" was the main window's own geometry: the pointer's location converted into the main window, checked against its content frame. The main window fills the screen and the Settings window sits inside that frame, so the test said yes for a pointer that was not on the main window at all — and the App overwrote the arrow the Settings window had just set, once per pass, forever.

Mouse-moved events reach the key window wherever the pointer is. While the main window is key and the Settings window is merely visible, the main window keeps receiving movements made over the Settings window, and hit testing them answers for whatever main-window surface lies underneath — the table. So the shape was not only preserved, it was re-decided as the hand from geometry the reader could not see.

Neither behaviour is written anywhere: the pointer rules describe surfaces inside the main window, and the Settings window is a separate window that the interface layer registry deliberately does not carry.

## What changed

**Ownership is asked of the window server, not of geometry.** `isPointerOverOwnWindow()` compares the topmost window number at the pointer's screen location with the main window's. That answers the actual question — which window is under the pointer — for the Settings window, for menus, and for other Apps alike, and it needs no knowledge of any particular window. Measured at 0.47 µs per call, so asking it on every movement and every run loop pass costs nothing worth avoiding.

**Nothing is decided or stated while another window has the pointer.** The one decision point gained that guard, which covers pointer movement and card hover reports together. `set` states a cursor only while the App owns the pointer, so a reset arriving from an interface switch cannot reach across into the Settings window's own I-beam either. While the pointer is away, the held shape goes back to the arrow, which is what makes the return start from a clean state rather than from whatever was last decided.

**Coming back is a movement when the pointer really went somewhere.** The location the pointer had outside is sampled every pass, and re-entry decides a shape only when the pointer arrives somewhere other than where it left. That distinction is what keeps a menu closing under a still pointer on the arrow, exactly as the menu rule requires, while a return from the Settings window — which cannot land on the point it left, since that point was on another window — decides normally. It also covers the case where the Settings window is key and the main window therefore receives no movements of its own.

Files:

- `apps/macos-native/Sources/CueSeekerApp/Shared/AppPointerShape.swift`

## Verification

`swift build` clean. `swift test --filter "PointerShapeModelTests|PointerHoverGateTests"`: 12 tests, all passing — the shape model itself is untouched, and the seven scenarios of `20260902-UI-Pointer Shape Follows Pointer Movement.md` still hold.

Full `swift test`: 1138 tests, 30 issues, in the families earlier records list as failing on the baseline tree — native playback timeline, presentation and audio, cue group refresh scope. The remaining failures (`sceneUsesVisibleWindowUnionAndTopLeftCoordinates`, `setWidthResizesMainWindowAndInvalidatesScene`, `sharedPersistenceMigrationCopiesLegacyValuesWithoutOverwritingSharedValues`, the two library folder removal cases, `playbackPlaylistCopyAndShioriTargetTheSettledPrimaryCue`) all pass when their suites run alone; they are the same full-suite parallelism interference the previous record describes. No baseline full-suite run was made for comparison on this pass.

## Known limits

The requirement's acceptance is a pointer shape on screen, and nothing automated can read one. The Debug E2E controller's `inspect` payload carries `pointerVisible` but no shape, and its mouse commands address the main window only, so a pointer cannot be driven onto the Settings window at all. Adding either would be new end-to-end capability and was not added. The shape itself therefore remains a manual acceptance step, as the requirement states.

Whether AppKit delivers mouse-moved events to a non-key window was not measured. The change does not depend on the answer: the return decides a shape from the run loop when no movement event arrives, and ignores the redundant decision when one does.
