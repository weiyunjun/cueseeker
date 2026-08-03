# Atomic Playback Resolution Switching

## Requirement

- `docs/human/requirements/20260803-Bug-Atomic Playback Resolution Switching.md`

## Scope

Keep each playback presentation generation internally consistent when Search
results switch between videos with different pixel sizes or aspect ratios.
This change does not add transitions or settings and does not alter subtitle
decoding, indexing, playback controls, or auto-pause semantics.

## Steps

1. Kept the previous complete native frame visible while a new presentation is
   pending and stopped applying the new session's dimensions when its render
   view is merely attached.
2. Captured the native video size only when the current generation presents its
   first frame, then committed the corresponding outer aspect ratio through the
   existing generation-gated presentation callback.
3. Added one batched subtitle-presentation update for source, video size,
   timestamp, and visibility. ASS and SRT overlays no longer expose intermediate
   property updates or rebuild the old source at the new size before replacing
   it.
4. Preserved the existing native generation rejection for superseded frames and
   added coverage for same-aspect size changes, different aspect ratios, hidden
   subtitles, and rapid superseding transitions.

## Verification

- The focused atomic presentation selection passed: 6 tests.
- The expanded native playback, presentation, subtitle, Screenshot, Seek, and
  auto-pause regression selection passed: 45 tests.
- `git diff --check` passed.

## Outcome

The first frame of a newly committed video now arrives with its matching video
size, outer layout aspect ratio, subtitle source, subtitle canvas, timestamp,
and visibility. Pending and superseded generations cannot publish a mixed old
and new presentation.

## Follow-ups

Final visual acceptance remains the project owner's playback check with the
identified 4K, 1080p, and nonstandard-resolution library items.
