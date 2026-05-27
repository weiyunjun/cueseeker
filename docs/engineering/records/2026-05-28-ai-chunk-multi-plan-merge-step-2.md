# AI Chunk Multi-Plan Merge Step 2 Implementation Record

## Requirement

- `docs/human/requirements/20260528-Feature-AI Chunk Multi Plan Merge.md`

## Scope

- Switch AI Chunking response parsing from the legacy root `items` format to
  the new root `plans` format.
- Validate each returned plan by mapping chunks from left to right onto the
  normalized sentence.
- Keep valid-plan range metadata for the later multi-plan merge step.
- Keep multi-plan merge and final cross-plan de-duplication for the next
  implementation step.

## Steps

1. Added validated plan/chunk models with normalized-sentence character
   offsets.
   Result: later merge code can compare chunk ranges without reparsing raw
   strings.
2. Replaced root `items` decoding with root `plans` decoding.
   Result: the client now accepts the new response contract and rejects the old
   response shape.
3. Added strict per-plan coverage validation.
   Result: chunks must cover non-space sentence text from left to right, may
   skip sentence spaces as hard boundaries, must not contain spaces themselves,
   and must not include external text or omit sentence text.
4. Filtered invalid plans while preserving valid plan order.
   Result: one bad plan no longer discards other valid plans, but an all-invalid
   response surfaces an AI Chunking error.
5. Added tests for the `plans` schema, legacy schema rejection, hard-space
   boundaries, incomplete coverage, invalid plan counts, and invalid-plan
   filtering.
   Result: the response parsing and validation layer is covered before merge
   behavior is introduced.

## Verification

- `swift test` passed from `apps/macos-native` with 156 Swift Testing tests
  and 7 XCTest tests.
- The test run still emitted existing playback-history disk I/O log messages,
  but the full suite passed.

## Outcome

- Step 2 is implemented and verified.
