# Quick Search Chunk Count Consistency Implementation Record

## Requirement

- `docs/human/requirements/20260527-Feature-Quick Search Chunk Count Consistency.md`

## Scope

- Make Playback Quick Search chunk counts use the same exact count source as
  the Search results page.
- Preserve the existing UI design and AI chunking request flow.

## Steps

1. Mapped the existing Quick Search count chain across View, Store,
   Coordinator, and Core database code.
   Result: the root issue was split across two boundaries: the count source
   used a separate SQL path, and the front-end count lifecycle lived in the
   SwiftUI view instead of app state.
2. Replaced the standalone `cueGroupOccurrenceCount` SQL with
   `searchPage(..., mode: .exact).totalCount`.
   Result: chunk counts now share Search query planning, result validation,
   active video filtering, folder scoping, and exact total-count semantics.
3. Reworked front-end count state by moving selected chunk count state out of
   `PlaybackQuickSearchOverlay` and into `PlaybackStore`, with background
   execution owned by `AppCoordinator`.
   Result: chunks can render immediately while count completion updates the
   count badge later, and the overlay no longer runs database work from SwiftUI
   view updates.
4. Handled chunk switching consistency with selected chunk count request IDs
   and stale completion checks.
   Result: old count results cannot overwrite the currently selected chunk
   after the user switches chunks or the AI state resets.
5. Added automated verification coverage:
   - Core regression test comparing chunk count totals against
   `searchPage(...).totalCount` for CJK terms, CJK phrases, Latin prefix
   searches, whitespace-trimmed input, and scoped folders.
   - App store tests for stale count rejection after chunk selection changes
     and count reset when AI state resets.
   Result: automated checks cover the exact-count source and the key
   front-end state lifecycle.

## Verification

- Step 2: `git diff --check` passed.
- Step 2: `swift test` passed from `apps/macos-native` with 137 tests.
- Added regression coverage passed for CJK terms, CJK phrases, Latin prefix
  searches, whitespace-trimmed input, and scoped folders.
- Step 3: `git diff --check` passed.
- Step 3: `swift test` passed from `apps/macos-native` with 139 tests.
- Added state coverage passed for stale count rejection after chunk selection
  changes and count reset when AI state resets.
- Step 5: `rg` audit confirmed the old `occurrenceCountProvider`,
  `lastQueriedItem`, and synchronous App-layer count provider are no longer
  present.
- Step 5: `git diff --check` passed.
- Step 5: `swift test` passed from `apps/macos-native` with 139 tests.
- Existing playback-history disk I/O log messages still appeared during the
  test run, but the full test suite passed.

## Outcome

- Implementation work and automated verification are complete. Human
  acceptance testing is still pending.
