# Library Finished Progress Regression

- Date: 2026-07-04
- Human requirement: `docs/human/requirements/20260704-Bug-Library Finished State Forces Progress To 100 Percent.md`

## Steps

- Committed the human-owned bug requirement before changing source code.
- Updated the Library cover progress presentation so progress fraction and time badge text are derived from the saved `positionMilliseconds` and duration, not from the finished watch state.
- Removed the `watchState` input from the cover progress view so the Finished badge cannot force the cover progress overlay to 100%.
- Added a regression test for a finished playback history whose saved position remains at 42.5 seconds of a 100 second video.

## Verification

- Ran `swift test` in `apps/macos-native`; all 373 tests passed.

## Outcome

- The Library card can show the Finished status while preserving the real saved playback progress in the progress bar and time badge.
