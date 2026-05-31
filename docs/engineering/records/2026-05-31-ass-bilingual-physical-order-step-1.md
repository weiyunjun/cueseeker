# ASS Bilingual Physical Order Step 1

Requirement: `docs/human/requirements/20260531-Bug-ASS Bilingual Physical Order.md`

## Scope

- Added parser coverage for same-start/same-end bottom-aligned ASS lines where libass collision places the later colliding line above the earlier bottom line.
- The expected index-time data source is `SubtitleCueGroup.searchContent` and `SubtitleCueLine.displayOrder`.

## Verification

- `swift test --filter ordersSameTimestampBottomAlignedASSLinesByCollisionPositionAtIndexTime`
  failed as expected because current parsing produced `Japanese lower line`
  before `Chinese upper line`.
- `swift test --filter searchReadsASSIndexTimePhysicalOrderWithoutRuntimeReordering`
  failed as expected because database entries, FTS search content, and cue
  lines all read the same incorrect index-time order.
