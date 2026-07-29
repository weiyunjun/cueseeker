# Playback Cue Typography Density Implementation Record

Status: Second visual iteration awaiting human review

Requirement:
`docs/human/requirements/20260729-Feature-Playback Cue Typography Density.md`

## Scope

Apply the first compact typography iteration to Playback Overlay Current,
subtitle Playlist, and Command Panel Search without changing their shared Reel,
measurement-cache, selection, scrolling, or Badge behavior.

## Implementation

- Changed Primary Cue typography to 24-point text with a 32-point nominal line
  height.
- Changed Cue Group typography to 20-point text with a 28-point nominal line
  height.
- Changed the internal visual-line gap to 3 points and Cue vertical padding to
  8 points.
- Derived the minimum single-line Current Cue height from line height and
  vertical padding instead of maintaining a second literal value.
- Updated focused layout and Cue Result tests for the proposed geometry.
- Kept Cue-to-Cue spacing, information Badge metrics, virtual layout,
  measurement-cache limits, and rendering paths unchanged.

## Verification

- `swift test --filter 'playbackCueResult|subtitleFocus'`: passed, 83 tests.
- The 50,000-Cue checks remained viewport-local, independent of total dataset
  size, and within the existing 64-entry measurement-cache limit. The local
  item-count assertion now derives its bound from the viewport, minimum Cue
  height, Cue gap, and fixed Overscan instead of the previous 40-point-font
  geometry.
- `swift test --no-parallel`: 897 of 898 tests passed. The unrelated
  `sharedPersistenceMigrationCopiesLegacyValuesWithoutOverwritingSharedValues`
  test observed shared `UserDefaults` state from an earlier test.
- The isolated persistence test passed with
  `swift test --filter sharedPersistenceMigrationCopiesLegacyValuesWithoutOverwritingSharedValues`.

## Outcome

The second iteration passed its focused verification and is ready for human
visual review. Final values and human-owned UI documentation remain
intentionally unsettled until the visual review is accepted.
