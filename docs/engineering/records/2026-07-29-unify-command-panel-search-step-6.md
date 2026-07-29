# Unify Command Panel Search — Step 6

## Requirement

- `docs/human/requirements/20260729-Feature-Workbench Playback And Command Panel Shared UI.md`
- Step 6: reuse the accepted Playback Cue Playlist presentation and operation
  in Command Panel Search, remove the left cover, show the same information
  Badges and optional Cue Group content, retain the 50-result preview, and open
  the complete result Playlist.

## Classification

- Command Panel Search layout and interaction: native platform UI/UX.
- Preview and complete Playlist boundaries: existing playback intent and Search
  product semantics, unchanged except for the presentation projection.
- Native media execution: unchanged.

## Implementation

- Removed the Command Panel-only cover Context, video-presentation lookup, and
  result Row implementation.
- Mounted the existing Cue Result Adapter and native virtual Reel inside the
  Command Panel Search result region.
- Added a session-local resident preview Window containing at most the first 50
  Search results. The Window is the single selection owner and is released when
  Search results close or Command Panel dismisses.
- Reused Primary Cue, optional Cue Group, selected-only Badge, wheel, scrollbar,
  and viewport-virtualized drawing behavior from Cue Playlist.
- Preserved the complete Search result count for the `[x/y]` Badge even when the
  resident preview is limited to 50 results.
- Preserved existing Cue shortcuts and complete Playlist promotion when the
  selected preview result is opened.
- Human-owned documents, including `docs/human/design/UI.md`, were not modified.

## Verification

- `swift test --filter playbackCommandPanel`: all 7 focused tests passed.
- `swift test --filter playbackCueResult`: all 13 focused tests passed.
- `swift test --filter playbackPlaylist`: all 13 focused tests passed.
- `swift test --filter subtitleFocus`: all 69 focused tests passed.
- `swift test`: all 896 tests ran; the concurrent run reported 13 issues in
  eight existing timing/shared-resource tests. Each reported test passed when
  rerun individually, confirming no reproducible failure from this step.
- `swift build`: passed.
- `git diff --check`: passed before the final review.

## Outcome

- Command Panel Search now uses the accepted Cue Playlist presentation without
  changing its 50-result preview or complete-Playlist activation contract.
