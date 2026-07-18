# Video And Subtitle Matching Rules Implementation

## Requirement

- `docs/human/requirements/20260718-Feature-Video And Subtitle Matching Rules.md`

## Scope

- Implement the four ordered filename comparisons for matching one subtitle to
  a video in the same directory.
- Apply the required video-extension priority.
- Normalize filename comparisons canonically and compare video extensions
  case-insensitively.
- Keep database identity and missing-resource behavior out of this change.

## Steps

1. Changed `VideoMatcher` to enumerate only regular files in the subtitle's
   immediate directory.
2. Applied the four filename comparisons in requirement order before choosing
   a video by extension priority.
3. Added FLV support and changed the default priority to MKV, MP4, WebM, FLV,
   AVI, then MOV.
4. Added focused coverage for every filename comparison, comparison-order
   precedence, extension priority, uppercase extensions, FLV, and canonically
   equivalent Unicode filenames.

## Verification

- `swift test --filter VideoMatcher`: passed 11 tests.
- `swift test --filter SubtitleIndexer`: passed 16 tests.
- `swift test`: run twice. Both 746-test runs completed with unrelated
  intermittent failures outside `VideoMatcher` and `SubtitleIndexer`:
  `nativePlaybackUsesCommonTimelineWhenVideoTrackStartsAfterAudio` failed in
  both full runs, and `playbackRecentPointerDispatcherUsesSharedWorkbenchItem`
  timed out in the second run. Each failed test passed when rerun alone.
- `git diff --check`: passed.

## Outcome

The matcher now follows the accepted filename-comparison order and video-format
priority. Focused matcher and indexing coverage passed. No database schema or
resource-recovery behavior changed.
