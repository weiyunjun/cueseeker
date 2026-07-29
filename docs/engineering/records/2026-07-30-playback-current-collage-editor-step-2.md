# Playback Current Collage Editor Step 2

Date: 2026-07-30

Requirement:

- `docs/human/requirements/20260730-Feature-Playback Current Collage Editor.md`

## Classification

- Editing Collage mode state and keyboard routing: platform UI and UX.
- Playback media execution and product-domain Collage grouping semantics are unchanged.

## Implementation

- Added session-owned Editing Collage mode that can only start from Playback Current.
- Prevented direct and Tab-driven module changes while the mode is active.
- Routed bare `P` and `Esc` to exit the mode, consumed other bare Playback actions, and left arrow keys available to the reading-scroll UI introduced by the next step.
- Added the Current-only Collage / Exit top-bar action and replaced the centered Current / Playlist tabs with the edit icon and `Editing Collage` while active.
- Reused the existing Neutral Button component, Edit icon, and documented UI tokens; no independent visual constants were introduced.

## Verification

- 81 focused Playback Overlay, Subtitle Focus, and normal Playback tests passed, including Current-only entry, module isolation, P / Esc / Tab behavior, blocked Playback actions, and arrow-key passthrough.
- The complete 909-test Swift Testing run reported one unrelated shared-defaults persistence failure; the failing test passed when rerun independently without a code change. All 7 XCTest cases passed.
- The existing normal Playback `P` screenshot behavior remains outside Playback Current.
- `docs/human/design/UI.md` remains human-owned and was not modified by the AI.
