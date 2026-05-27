# AI Chunk Position Dedupe Correction Implementation Record

## Requirement

- `docs/human/requirements/20260528-Feature-AI Chunk Multi Plan Merge.md`

## Scope

- Correct final AI Chunking de-duplication to operate on chunk position ranges
  instead of chunk text.
- Preserve repeated identical chunk text when it appears at different positions
  in the normalized sentence.
- Keep merge-base selection, split candidate selection, validation, prompt
  behavior, cache behavior, and UI behavior unchanged.

## Steps

1. Added a range key for final merged chunk de-duplication.
   Result: duplicate chunks are now identified by `[start, end)` offsets in the
   normalized sentence.
2. Updated final merged output de-duplication to iterate validated chunks
   instead of only item text.
   Result: the earliest chunk and translation for the same sentence position
   still wins, while repeated text at different positions remains visible.
3. Added regression coverage for repeated identical text at different sentence
   positions.
   Result: a repeated chunk such as two occurrences of `運` is preserved when
   the occurrences map to different ranges.

## Verification

- `swift test` passed from `apps/macos-native` with 161 Swift Testing tests
  and 7 XCTest tests.
- The test run still emitted existing playback-history disk I/O log messages,
  but the full suite passed.

## Outcome

- The position-based de-duplication correction is implemented and verified.
