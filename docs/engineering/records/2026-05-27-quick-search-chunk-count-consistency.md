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
5. Moved selected chunk count state out of `PlaybackQuickSearchOverlay` and
   into `PlaybackStore`.
   Result: count loading and exact count values are now app state, not local
   view state.
6. Added request IDs for selected chunk counts and reject stale completions
   when the selected chunk or AI state changes.
   Result: old count results cannot overwrite the currently selected chunk.
7. Moved count execution into `AppCoordinator` using a background utility task.
   Result: the overlay no longer runs synchronous database work from SwiftUI
   view updates.
8. Updated the overlay to render only the store-provided count state.
   Result: chunks can render immediately while count completion updates the
   count badge later.
9. Added App store tests for chunk-count stale result rejection and reset.
   Result: the key front-end state lifecycle is covered.

## Verification

- Step 2: `git diff --check` passed.
- Step 2: `swift test` passed from `apps/macos-native` with 137 tests.
- Added regression coverage passed for CJK terms, CJK phrases, Latin prefix
  searches, whitespace-trimmed input, and scoped folders.
- Step 3: `git diff --check` passed.
- Step 3: `swift test` passed from `apps/macos-native` with 139 tests.
- Added state coverage passed for stale count rejection after chunk selection
  changes and count reset when AI state resets.
- Existing playback-history disk I/O log messages still appeared during the
  test run, but the full test suite passed.

## Outcome

- Step 3 is complete. The count source reuses Search exact totals, selected
  chunk count queries run in the background, and stale count completions are
  guarded before updating the UI.
