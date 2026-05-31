# ASS Bilingual Physical Order Step 2

Requirement: `docs/human/requirements/20260531-Bug-ASS Bilingual Physical Order.md`

## Scope

- Changed only the ASS index-time parser path.
- Added collision-lite placement inside exact `start/end` cue groups before
  `SubtitleCueGroup.searchContent` and `SubtitleCueLine.displayOrder` are
  created.
- Left search queries, sidebar reads, database read paths, and playback
  rendering unchanged.

## Notes

- Placement is grouped by ASS layer, follows source event order within a layer,
  and shifts colliding bottom-aligned lines upward or top/middle-aligned lines
  downward before sorting by the resulting physical rectangle.
- Explicitly positioned events and ASS effects that disable normal collision
  handling are kept out of collision shifting and sorted by their projected
  physical position.

## Verification

- `swift test --filter ordersSameTimestampBottomAlignedASSLinesByCollisionPositionAtIndexTime`
  passed.
- `swift test --filter searchReadsASSIndexTimePhysicalOrderWithoutRuntimeReordering`
  passed.
