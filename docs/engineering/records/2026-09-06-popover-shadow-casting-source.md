# The popover shadow is cast by the container shape, in two shrunk layers

Human-owned documents:

- `docs/human/requirements/20260906-UI-Popover Shadow Casting Source And Layered Recipe.md`

## Why

In Select mode every action button in the Selection Action Overlay carried a soft shadow of its own, and so did the count line above them. Read as design it looks like decoration nobody asked for; the design system's Button anatomy has no shadow entry at all, and the control itself draws only a fill, a border and a focus ring.

The shadow came from the overlay. A shadow attached to a composed surface is cast by every drawing primitive that surface contains, not by its silhouette: the panel's rounded rectangle cast one, each button's rounded rectangle cast another, and each run of text cast a third. This is the same failure the 2026-08-27 Task Panel record describes; the Task Panel and the Menu were moved onto their background shapes then, and the Selection Action Overlay, the Toast and the Playback Command Panel were not.

The panel's own shadow was wrong for a second, independent reason. It was one layer, offset down by 12 with a 24-point blur and nothing shrinking it, so it spread the same distance in every direction. Measured, that shape put a visible tint **33 points above the container's top edge** — where a surface lit from above should cast nothing at all — and still had not faded 40 points below it. What that reads as on screen is a grey haze around the panel rather than a panel sitting above the page.

## What changed

**Every surface that uses the popover shadow token now casts it from the shape that draws its background.** The silhouette is then a single opaque rounded rectangle, and nothing inside it casts anything. For the Selection Action Overlay and the Toast the background shape already existed; the shadow moved onto it. The Playback Command Panel had no shape to attach one to — its background was a plain colour applied before the clip — so it gained a real backing shape, placed after the clip so the clip cannot cut the shadow off.

**The token is now two layers, each shrunk before it is blurred.** A main layer lifts the surface and a contact layer bites its edge; both are pulled in from the container's outline, which is what keeps either of them from reaching past the top edge. SwiftUI has no spread parameter, so the modifier draws each layer as a copy of the container's shape inset by that layer's own shrink, casts the shadow from the copy, and lets the caller's opaque fill cover the copies. That is why the modifier now takes the corner radius: it has to rebuild the caller's shape to shrink it.

**The colour is one value for both themes.** A shadow darkens what is under it in proportion to that background's brightness, so the same value that moves a white page by about 25 levels moves a dark page by about 2 — next to a container border that stands about 33 levels off the same dark page. Dark therefore separates the popover from the page with its border, and the token records that if dark ever needs more lift, the popover background goes up a step rather than the shadow getting heavier.

Files:

- `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchRedesignTokens.swift`
- `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchSchemaSearch/SchemaWorkbenchSearchShell.swift`
- `apps/macos-native/Sources/CueSeekerApp/Shared/Toast.swift`
- `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchControls/WorkbenchControls.swift`
- `apps/macos-native/Sources/CueSeekerApp/Tasks/TaskPanel.swift`
- `apps/macos-native/Sources/CueSeekerApp/Playback/SubtitleFocus/PlaybackCommandPanel.swift`

## Verification

`swift build` clean.

**The blur radii were measured, not converted on faith.** The requirement records the recipe in the design system's CSS notation and says in so many words that the native blur parameter is not the same quantity and must be calibrated against what actually renders. A throwaway offscreen render of the same layer stack — the container's shape, the inset casters, an sRGB readback of the pixel column through the container's centre — gives:

| recipe | tint above the top edge | peak below the bottom edge | faded to nothing by |
| --- | --- | --- | --- |
| one layer, no shrink, radius 24 (what the token was) | reaches 33 pt up | 16/255 | not yet at 40 pt |
| two shrunk layers, CSS blur copied literally (15 / 6) | reaches 15 pt up | 27/255 | 36 pt |
| two shrunk layers, CSS blur halved (7.5 / 3) — shipped | reaches 1 pt up, at 1/255 | 29/255 | 24 pt |

So halving is the right conversion and copying the notation's numbers is not: literal numbers would still have bled fifteen points over the top edge. The shipped values leave one row of 1/255 immediately outside the border, which is below what a display resolves, and they make the contact edge stronger while pulling the whole spread in from beyond 40 points to 24. This is the objective half of acceptance item 2. The measurement script lives in the session scratchpad and is deliberately not committed: it measures a drawing primitive, not the App, and turning it into a fixture would be new test capability the requirement did not ask for.

Full `swift test`: 1138 tests, 15 failures, all in the families earlier records list as failing on the baseline tree — native playback timeline, presentation and audio, cue group refresh scope, window scene geometry, shared persistence migration, subtitle focus Shiori. No new family appears. The suite is not deterministic on this machine: runs of the same commit produced 15 to 18 failures with a set that varies inside those families, and a baseline run on the clean tree earlier in this change confirmed the same behaviour without any of it. Acceptance item 7 is therefore reported rather than claimed. `CueGroupRefreshScopeIntegrationTests` was checked in isolation on both trees during the first half of this change and fails the same two cases identically; the anchor its failing assertion names is the table's own scroll anchor, not the overlay's handle.

How the shadow reads on screen is acceptance item 6, which the requirement assigns to its owner. There is no documented end-to-end procedure for the Select mode overlay and none was written.

## Known limits

The shadow casters are opaque and are drawn behind the caller's own fill, so **every caller's fill must stay opaque**. All five callers use the popover background, which is opaque in both themes; a translucent popover would show black through the middle. The corner radius is passed to the modifier separately from the shape it belongs to, so a caller that changes one without the other would shrink the wrong outline — worth knowing, and cheap next to rebuilding the call sites around a shape-carrying modifier.

The inset casters keep the container's corner radius rather than reducing it by the shrink. At a radius of 8 and shrinks of 3 and 4 the difference is well inside the blur and does not survive to the rendered pixels.

Acceptance item 4 names three surfaces that its premise does not fit, and the requirement now excludes them explicitly. Tooltip is specified in the design system but has no implementation. Dialogs are presented as system sheets: the App draws no shadow of its own for them — an earlier alignment removed the legacy panel shadow — and the shadow visible on screen is the one the window server draws for the sheet, which no token of ours reaches. Playback Feedback uses the player overlay shadow and its icon carries a deliberate legibility shadow for white glyphs over video.
