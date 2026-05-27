# Quick Search Chunk Actions Step 4 Highlight Refinement Record

## Requirement

- `docs/human/requirements/20260528-Feature-Quick Search Chunk Actions.md`

## Scope

- Refine the sentence-side chunk mapping highlight after visual review.
- Preserve selected chunk visual tokens while avoiding reuse of the full chunk
  token layout inside sentence text.

## Steps

1. Replaced the sentence-side use of the full chunk label helper with a
   sentence-specific highlight label.
   Result: the mapped sentence text no longer inherits the chunk token's large
   horizontal and vertical padding.
2. Kept the selected chunk background color, text color, and semibold weight.
   Result: the mapping still follows the existing selected chunk visual
   language.
3. Added a small upward visual offset to the mapped sentence segment.
   Result: the selected source text reads as slightly raised without changing
   the surrounding sentence text style.

## Verification

- `git diff --check` passed.
- `swift test` passed from `apps/macos-native` with 165 Swift Testing tests
  and 7 XCTest tests.
- The passing test run still emitted existing playback-history disk I/O log
  messages, but the full suite passed.

## Outcome

- The sentence-side mapping highlight now reuses visual tokens instead of the
  full chunk token layout.
