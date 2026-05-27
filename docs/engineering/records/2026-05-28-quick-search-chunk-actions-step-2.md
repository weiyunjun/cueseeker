# Quick Search Chunk Actions Step 2 Implementation Record

## Requirement

- `docs/human/requirements/20260528-Feature-Quick Search Chunk Actions.md`

## Scope

- Update the Playback Quick Search current-sentence row layout.
- Keep the row in its existing position: directly below the search field when
  no AI chunks are present, and below the chunk results when chunks are present.
- Reuse the existing Quick Search command label visual style for the new
  `/chunk`, `/rechunk`, and `/copy` row presentation.
- Defer `/copy` execution behavior and richer action focus modeling to the
  next implementation step.

## Steps

1. Stopped rendering the selected chunk detail row when there are no chunks.
   Result: the current-sentence row is now the first panel row below the search
   field for cache-miss/no-chunk states.
2. Split the old single-line `sentence /chunks` row into a vertical layout.
   Result: the sentence displays on the first line, while command-style actions
   display below it.
3. Displayed `/chunk` when no chunks exist and `/rechunk` when chunks exist,
   with `/copy` shown after it.
   Result: the row communicates the intended command actions without mixing
   command text into the sentence text.
4. Extracted the Quick Search command label visual styling used by
   `/back`/`/forward`.
   Result: navigation commands and the current-sentence action row share the
   same local UI helper instead of duplicating styling.

## Verification

- `git diff --check` passed.
- `swift test` passed from `apps/macos-native` with 161 Swift Testing tests
  and 7 XCTest tests.
- The passing test run still emitted existing playback-history disk I/O log
  messages, but the full suite passed.

## Outcome

- Step 2 is implemented and verified.
