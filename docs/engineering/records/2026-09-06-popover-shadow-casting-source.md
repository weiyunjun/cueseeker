# The popover shadow is cast by the container shape

Human-owned documents:

- `docs/human/requirements/20260906-UI-Popover Shadow Casting Source And Layered Recipe.md`

## Why

In Select mode every action button in the Selection Action Overlay carried a soft shadow of its own, and so did the count line above them. Read as design it looks like decoration nobody asked for; the design system's Button anatomy has no shadow entry at all, and the control itself draws only a fill, a border and a focus ring.

The shadow came from the overlay. A shadow attached to a composed surface is cast by every drawing primitive that surface contains, not by its silhouette: the panel's rounded rectangle cast one, each button's rounded rectangle cast another, and each run of text cast a third. What reaches the screen is a stack of overlapping copies rather than one lift, which is also why the panel's own shadow read as a wide grey haze that reached above its top edge instead of sitting under it.

This is the same failure the 2026-08-27 Task Panel record describes, and the Task Panel and the Menu were moved onto their background shapes then. The Selection Action Overlay, the Toast and the Playback Command Panel were not.

## What changed

**Every surface that uses the popover shadow token now casts it from the shape that draws its background.** The silhouette is then a single opaque rounded rectangle, and nothing inside it casts anything.

For the Selection Action Overlay and the Toast the background shape already existed; the shadow moved onto it and the surface-level modifier went away. The Toast holds only one text run, so its symptom was a halo around the message rather than a row of button shadows, but the mechanism is identical.

The Playback Command Panel needed a little more. Its background was a plain colour applied before the clip, with the shadow applied after it, so there was no shape to attach a shadow to. It now has a real backing shape, placed after the clip so the clip cannot cut the shadow off, and it uses the shared shadow helper instead of restating the token's four fields by hand.

Files:

- `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchSchemaSearch/SchemaWorkbenchSearchShell.swift`
- `apps/macos-native/Sources/CueSeekerApp/Shared/Toast.swift`
- `apps/macos-native/Sources/CueSeekerApp/Playback/SubtitleFocus/PlaybackCommandPanel.swift`

## Verification

`swift build` clean.

A full `swift test` was run on this tree and, for comparison, on the clean tree at `a44c1807`. Both fail, and the failing set is not stable: three runs of the same 1138 tests produced 16, 17 and 18 failures, differing in the library folder removal, playlist copy, shared persistence migration and subtitle focus Shiori cases. The families are the ones earlier records list as failing on the baseline tree — native playback timeline, presentation and audio, cue group refresh scope, window scene geometry. No failure in any run touches popover shadow rendering, and no test present in a run with the change was absent from the baseline family set. Because the suite is not deterministic on this machine, the requirement's acceptance item 7 cannot be certified from a single pair of runs; it is reported rather than claimed.

`CueGroupRefreshScopeIntegrationTests` was singled out because one of its assertions is named for an anchor and the Selection Action Overlay registers an anchor handle. Run alone it fails the same two cases — `showCueGroupInvalidationIsScopedToMountedShiori` and `shioriTableStartsAtTopAfterPanelRemount` — on this tree and on the clean tree, byte for byte the same assertions. The anchor in question is the table's own scroll anchor, not the overlay's handle.

The shadow's appearance on screen was not verified here. Acceptance item 6 assigns it to the requirement owner, and there is no documented end-to-end procedure for the Select mode overlay; writing one would be new end-to-end capability and was not added.

## Known limits

Section 2 of the requirement — the layered recipe that replaces the single-layer popover shadow — is **not implemented**. Its Dark value is recorded as `<待定>` in the human-owned document, and a token cannot be half-defined. The token is unchanged, so acceptance item 2 (no visible grey above the overlay's top border) does not hold yet; only the casting source is fixed.

Acceptance item 4 names three surfaces that its premise does not fit. Tooltip is specified in the design system but has no implementation. Dialogs carry no shadow at all, following an earlier alignment that removed the legacy panel shadow. Playback Feedback uses the player overlay shadow, which section 4.4 of the same requirement puts out of scope, and its icon carries a deliberate legibility shadow for white glyphs over video. These were reported to the requirement owner rather than resolved here.
