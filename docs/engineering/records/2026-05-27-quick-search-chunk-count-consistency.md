# Quick Search Chunk Count Consistency Implementation Record

## Requirement

- `docs/human/requirements/20260527-Feature-Quick Search Chunk Count Consistency.md`

## Scope

- Make Playback Quick Search chunk counts use the same exact count source as
  the Search results page.
- Preserve the existing UI design and AI chunking request flow.

## Steps

1. Confirmed the committed human-owned requirement covers the change.
   Result: implementation is authorized under the traceability rules.
2. Replaced the standalone `cueGroupOccurrenceCount` SQL with
   `searchPage(..., mode: .exact).totalCount`.
   Result: chunk counts now share Search query planning, result validation,
   active video filtering, folder scoping, and exact total-count semantics.
3. Passed the current selected folder scope from the App layer into the Core
   count call.
   Result: Quick Search count requests use the same active library scope as
   Search.
4. Added a Core regression test comparing chunk count totals against
   `searchPage(...).totalCount` for CJK terms, CJK phrases, Latin prefix
   searches, whitespace-trimmed input, and scoped folders.
   Result: the Core count source is covered against the desired Search total
   semantics.

## Verification

- `git diff --check` passed.
- `swift test` passed from `apps/macos-native` with 137 tests.
- Added regression coverage passed for CJK terms, CJK phrases, Latin prefix
  searches, whitespace-trimmed input, and scoped folders.
- Existing playback-history disk I/O log messages still appeared during the
  test run, but the full test suite passed.

## Outcome

- Step 2 is complete. The count source now reuses Search exact totals, but the
  front-end count state and background execution flow still need the later
  implementation steps.
