# Quick Search Chunk Actions Step 4 Underline Refinement Record

## Requirement

- `docs/human/requirements/20260528-Feature-Quick Search Chunk Actions.md`

## Scope

- Refine the sentence-side chunk mapping marker after visual review.
- Remove highlight effects that can affect nearby sentence text positioning.
- Use a plain underline as the only sentence-side selected marker.

## Steps

1. Removed the sentence-side mapped segment background, padding, and vertical
   offset.
   Result: the marker no longer behaves like an inline chip.
2. Removed the sentence-side mapped segment semibold weight and pure-white text
   override.
   Result: the mapped segment now uses the same font weight and color as the
   surrounding sentence text.
3. Added a plain underline to the mapped segment.
   Result: the selected chunk still maps to the source sentence location while
   minimizing layout impact.

## Verification

- `git diff --check` passed.
- `swift test` passed from `apps/macos-native` with 165 Swift Testing tests
  and 7 XCTest tests.
- The passing test run still emitted existing playback-history disk I/O log
  messages, but the full suite passed.

## Outcome

- The sentence-side mapping marker now uses only a plain underline.
