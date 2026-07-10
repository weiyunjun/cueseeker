# Playback Subtitle Focus Virtual Reel

## Requirement

- `docs/human/requirements/20260710-Feature-Playback Subtitle Focus Virtual Reel Architecture.md`

## Scope

Replace the bounded window-loading implementation with a complete current-video
cue collection and an AppKit virtual reel. Search and Shiori aggregate reels
remain out of scope.

## Steps

1. Kept the initial 6 + 1 + 3 snapshot as the first presentation and added a
   separately cancellable background read for the complete current-video cue
   collection.
2. Added strict session, source, total-count, ordinal-continuity, and initial-cue
   validation before publishing the complete collection.
3. Reused the existing stable database ordering and cue-line hydration path;
   short subtitle files whose initial snapshot is already complete avoid a
   second read.
4. Cancelled and released the complete collection task on dismissal, source
   replacement, and action completion. Late results cannot publish after the
   session token becomes invalid.
5. Replaced the rendered SwiftUI cue stack with one AppKit scroll view and one
   custom document view. The document view computes the visible ordinal range
   directly from fixed 104-point slots, 136-point pitch, and four-cue overscan.
6. Added virtual leading and trailing space so every cue, including the first
   and last, aligns to the same fixed center anchor. Pointer hover and text-only
   activation are handled locally and invalidate only the affected rows.
7. Reused one TextKit layout stack for visible cue drawing instead of creating
   one layout graph per cue view.

## Verification

- `swift test --filter SubtitleFocus`
  - Passed 83 tests after the data-loading step.
  - The 2,500-cue complete-collection database test passed in 0.099 seconds.
  - Passed 86 tests after the virtual-reel step.
  - Verified that first and last cues resolve to the same anchor and that a
    50,000-cue document still computes at most 15 visible-plus-overscan cues.
- `git diff --check`
  - Passed.

## Outcome

The initial ten-cue presentation remains independent from the complete current-
video read. Complete results are retained only by the matching active session,
and the measured full read did not introduce an opening-path regression because
it starts only after the initial presentation publishes. Rendering cost is now
bounded by the viewport rather than the complete cue count, and the reel uses
one immutable compact cue collection without creating a view per cue.

## Follow-ups

- Replace the SwiftUI cue stack with the AppKit virtual reel.
- Remove the superseded bounded cache, sequential prefetch, and target-window
  loading paths after the virtual reel owns navigation.
