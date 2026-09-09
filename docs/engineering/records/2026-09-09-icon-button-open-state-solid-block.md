# Open stops being a second hover and becomes a solid block

Human-owned documents:

- `docs/human/requirements/20260909-UI-Icon Button Open State Solid Block.md`

## Why

An icon button that was lit and an icon button the pointer happened to rest on painted exactly the same background, so nothing on screen said which filter menu was up, whether selection mode was on, or whether the Settings window was open — the user had to move the pointer away to find out. Open needed to stop borrowing hover's paint.

It also had to stop being a per-surface value. The earlier attempt gave each surface its own deeper step, which on the player turned into a translucent white fill under a white glyph: the fill and the icon washed into each other and the button read as a smudge rather than a state. The fix is the one the Sidebar's selected item already uses — a solid block with the content in a single fully contrasting colour — in neutral rather than accent. Nothing about it depends on the surface, so nothing about it needs a surface parameter.

## What changed

One file. Open now paints the whole button box in `--color-text-muted` and the glyph in `--color-icon-on-dark`, both existing tokens, the same on every surface:

- The background branches on Open before hover, so an open button no longer reads its surface's hover step; hover keeps that step untouched.
- The glyph branches on Open before the caller's `iconColor` override. That override exists so the player's bars can draw a light icon on video; on a filled block it would put a near-white glyph on a mid-grey fill, which is the smudge described above. Open ignores it and takes white.
- No new parameter, no new token, and no call site changed — Open takes no surface-specific input at all, so the eight buttons named in the requirement are the same branch on all three surfaces.

Files:

- `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchControls/WorkbenchControls.swift`

## Verification

Debug E2E controller, main window 1445×821.

- Light: with the filter menu up, the filter button is a solid grey box with a white glyph, and the Select button beside it is bare with its usual dark glyph. The two states are told apart without moving the pointer.
- Dark: with the Settings window open, the gear is a solid grey box with a white glyph on the `#18181B` top bar, and the task button beside it is bare. Appearance was switched through the app's own Settings and set back to Light afterwards.
- In both, the fill is opaque and the glyph's strokes show that same fill between them — no translucency, no third colour.

`swift test`: 1163 tests. The failures are the set this suite already produces on this commit's parent — native playback timeline and audio, native presentation transitions, cue group refresh scope, library folder removal, and the Debug E2E window-geometry cases. None of them reads an icon button, and the change touches one view file.

## Known limits

Hover is not automatable, for the reason `docs/engineering/08_end_to_end_testing.md` §1.1 records: a synthesized `mouseMove` never reaches SwiftUI's `.onHover`. The requirement keeps hover unchanged, so nothing about it moved; confirming that by eye is a manual step.

The player top bar's pair was not captured. Another CueSeeker instance held the audio device, so entering a video failed with an `AVAudioEngine` error, and Player UI only reveals itself for three seconds on entry. The code path carries no surface-specific input for Open any more, so it is the same branch that was captured on the other two surfaces, but that is an argument from the code rather than a screenshot.

`UI Design System.md` still describes Icon Button's Open state as the same background as hover. Per the owner's instruction the design documents are updated after this round of UI tuning is accepted, so that gap is expected until then.
