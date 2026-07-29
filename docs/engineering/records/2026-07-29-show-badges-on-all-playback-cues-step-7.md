# Show Badges on All Playback Cues — Step 7

## Requirement

- `docs/human/requirements/20260729-Feature-Workbench Playback And Command Panel Shared UI.md`
- Step 7: keep each module's information Badges visible on every Cue, use
  Playback-specific neutral gray palettes with a stronger selected hierarchy,
  and keep Badge content and item height stable across selection changes.

## Classification

- Badge visibility, palette, and Reel geometry: native platform UI/UX.
- Cue identity, ordering, actions, and durable product data: unchanged.
- Native media execution: unchanged.

## Implementation

- Added Playback-specific unselected Badge colors with the accepted Unwatched
  color values without reusing Watch Status state or components.
- Made Current, Cue Playlist, and Command Panel Search draw their existing
  information Badges for every Cue. Selection now changes only the Badge
  palette.
- Included the fixed 23-point Badge row and 8-point Cue gap in every applicable
  item extent. Selected and unselected extents are identical, so selection
  cannot change Reel placement or invalidate text measurements.
- Preserved Current's dedicated primary-only native drawing path and the Cue
  Result path used by Playlist and Command Panel Search.
- Replaced the selected-only Badge plan cache with bounded 64-entry presentation
  caches so visible unselected Cues do not rebuild text widths on every frame.
- Human-owned `docs/human/design/UI.md` was not modified or staged.

## Verification

- `swift build`: passed.
- `swift test --filter playbackCueResult`: all 14 focused tests passed,
  including the resident 50,000-result rapid Scrollbar regression.
- `swift test --filter playbackCurrent`: all 3 focused tests passed.
- `swift test --filter playbackPlaylist`: all 13 focused tests passed.
- `swift test --filter playbackCommandPanel`: all 7 focused tests passed.
- `swift test --filter subtitleFocus`: all 69 focused tests passed.
- `swift test`: all 898 tests ran; the concurrent run reported 21 issues in 11
  existing timing/shared-resource tests. Every reported test passed when rerun
  individually.

## Outcome

- All three requested interfaces now keep information Badges visible without
  making selection part of item geometry or the measurement hot path.

## Follow-up: Replace Blue with Neutral Hierarchy

- Replaced the selected blue Badge background and text with a stronger neutral
  gray pair, and deepened the unselected neutral background and Light text for
  contrast against the Playback surface.
- Reused the existing four Playback-specific Badge color tokens. Badge
  components, geometry, selection, caching, and Watch Status tokens remain
  unchanged.
- Verified the exact Light and Dark token values with the focused Cue Result
  tests and reran the Playback Current, Playlist, Command Panel, and Subtitle
  Focus suites.
