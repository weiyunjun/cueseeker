# Playback Current Collage Editor Step 3

Date: 2026-07-30

Requirement:

- `docs/human/requirements/20260730-Feature-Playback Current Collage Editor.md`

## Classification

- Collage selection limit and grouping state: product semantics already owned by `CueSeekerCore`.
- Editing Collage layout, native Reel drawing, pointer input, and keyboard routing: platform UI and UX.
- Playback media execution is unchanged.

## Implementation

- Reused the existing Current `PlaybackSubtitleFocusReelContainerView`, cue adapter, focus navigation, native virtual layout, and Table Scrollbar instead of adding a second list or scroll implementation.
- Moved that same Current Reel into the right half of the Editing Collage content region while preserving the session's Current selected ordinal across entry and exit.
- Added one centralized 24-point circular Checkbox metric and a leading accessory slot anchored to the Primary Cue; Display Title and Time Range remain rendered together by the existing information-badge layout.
- Matched Search Checkbox rendering by forcing the SF Symbol monochrome variant while retaining the shared dynamic Checked, Unchecked, and Disabled tokens in Light and Dark appearances.
- Initialized each Editing Collage session with the focused cue selected while keeping Checkbox selection styling independent from Reel focus; only the focused cue uses focused subtitle and Badge styling.
- Made the complete Cue Placement clickable, including the Checkbox, information badges, and Primary Cue, while preserving the independent focus state.
- Routed bare Enter to toggle the focused cue and bare Up / Down through the existing Current focus navigation. Checkbox drawing has no hover, pressed, or focus-ring state.
- Reused `SubtitleCollageSelectionPlan` as the only selection source of truth. At 50 selected cues, unchecked cues are disabled while checked cues remain available for deselection.

## Verification

- 130 focused Current Reel, virtual layout, virtual scrollbar, Playback Cue Result, Playlist Reel, session, and keyboard tests passed, including Light / Dark Checkbox colors, monochrome symbol rendering, complete-row pointer selection, unchanged focus, checked nonfocused cue styling, and the 50-cue disabled state.
- The complete 911-test Swift Testing run exposed 19 failures in 9 parallel media-timing, temporary-database, and refresh-scope tests. Every failed test passed when rerun independently without a code change; all 7 XCTest cases passed.
- `git diff --check` passed.
- `docs/human/design/UI.md` remains human-owned and was not modified or staged by the AI.

## Outcome

- Step 3 matches the requirement: Editing Collage uses the Current Reel on the right, retains its focus behavior and virtual scrollbar, adds Checkbox selection and Enter toggling, and enforces the existing 50-cue limit without an independent subtitle-list implementation.
