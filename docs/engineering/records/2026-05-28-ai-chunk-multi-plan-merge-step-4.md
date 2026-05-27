# AI Chunk Multi-Plan Merge Step 4 Implementation Record

## Requirement

- `docs/human/requirements/20260528-Feature-AI Chunk Multi Plan Merge.md`

## Scope

- Clear the Quick Search chunks-row selected visual state when focus leaves the
  chunks row.
- Default back to the first chunk when focus returns to the chunks row.
- Display chunks outside the merged plan on a separate wrapping line.

## Steps

1. Added display-group metadata to `AIChunkItem`.
   Result: chunks can be marked as part of the merged primary plan or as
   additional chunks from the original valid plans.
2. Marked de-duplicated chunks from the generated merged plan as primary and
   later-plan chunks as additional.
   Result: the UI can split the chunk display without re-running merge logic.
3. Rendered primary and additional chunks in separate Quick Search flow rows.
   Result: chunks outside the generated plan start on a new line and still wrap
   naturally when the row is narrow.
4. Scoped chunk pill selection and chunk detail display to active chunks-row
   focus.
   Result: leaving the chunks row removes the chunk selected visual state.
5. Defaulted chunk-row focus restoration to the first chunk.
   Result: returning to the chunks row selects the first chunk instead of the
   previously focused chunk.
6. Added tests for display-group decoding, merged-plan additional chunks, and
   chunk focus restoration.
   Result: the new grouping and focus behavior are covered by automated tests.

## Verification

- `git diff --check` passed.
- `swift test` passed from `apps/macos-native` with 167 Swift Testing tests
  and 7 XCTest tests.
- The passing test run still emitted existing playback-history disk I/O log
  messages, but the full suite passed.

## Outcome

- Step 4 is implemented and verified.
