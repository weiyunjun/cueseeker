# Playback Subtitle Focus Quick Search Removal

## Human-Owned Source

- `docs/human/requirements/20260710-Feature-Playback Subtitle Focus Overlay.md`
- `docs/human/design/UI.md`

## Scope

Complete Playback Subtitle Focus by removing the previous Quick Search
presentation, interaction state, settings entry, and front-end navigation
commands while preserving the durable playback-navigation history backend.

## Classification

- Product semantics: retains existing persisted Library, Search, and Shiori
  navigation entries, pointer movement, and restore behavior without exposing
  them in the current playback UI.
- Platform UI/UX: removes the replaced Quick Search overlay, result rows, AI
  chunk rows, input bridge, settings page, and `/back` and `/forward` controls.
- Platform integration: removes Quick Search-specific search callbacks, async
  tasks, clipboard routing, cache adapters, and playback key routing.
- Playback execution: unchanged; Enter continues to open Subtitle Focus and
  the native render, seek, and close paths remain intact.

## Changes

- Removed the Quick Search overlay, its playback result row, search text bridge,
  search-context snapshot, visible-only host, and dedicated navigation-focus
  tests.
- Removed all Quick Search focus, draft, result, subtitle-line, AI chunk,
  selected-count, navigation-row, and captured-playback state from
  `PlaybackStore`, leaving timeline, chrome, playback, and Subtitle Focus state
  unchanged.
- Removed Quick Search open, submit, focus, result, Escape, clipboard, AI
  request/cache/count, Search-context restoration, and stop-cleanup adapters
  from the playback coordinator. The playback key path now contains only normal
  playback and Subtitle Focus behavior.
- Removed the Search completion callback that selected a Quick Search result and
  removed the obsolete coordinator task and snapshot slots.
- Removed the Experimental Features settings page because every control on that
  page configured the removed Playback Quick Search AI feature. Preserved
  `SettingsStore`, DeepSeek credentials, prompt configuration, AI client, cache
  schema, and stored user data without migration or deletion.
- Removed only the two playback theme aliases that became orphaned by this UI
  deletion. Existing feedback, Player Chrome, Subtitle Focus, and unrelated
  compatibility tokens remain unchanged.
- Moved the retained back/forward command type into the navigation-history
  backend under a neutral name and removed its overlay-closing side effect.
  History recording, branch truncation, same-kind replacement, pruning,
  availability, and Library/Search/Shiori restoration remain unchanged.
- Converted four history restoration tests from old Quick Search focus routing
  to direct backend commands and added forward restoration coverage for pointer
  movement, unchanged history, availability, and the end boundary.
- Increased the action-menu test wait ceiling from one to three seconds after a
  concurrent full-suite review exposed scheduler contention; the immediate
  no-early-menu assertions and documented 0.22-second behavior remain intact.

## Verification

- Source and test reference audit
  - `QuickSearch`, `quickSearch`, `Quick Search`, `/back`, and `/forward`
    returned no matches in active Swift source or tests.
- `swift build`
  - Passed.
- `swift test --filter PlaybackNavigation`
  - Passed 22 Swift Testing tests, including all retained history persistence,
    back restoration, new forward restoration, and availability behavior.
- `swift test --filter PlaybackStore`
  - Passed 2 retained Swift Testing tests for timeline invalidation isolation
    and independent AI usage accounting.
- `swift test --filter SubtitleFocus`
  - Passed 79 Swift Testing tests after the old UI removal.
- `swift test`
  - Passed 7 XCTest tests and 489 Swift Testing tests in a clean final run.
- Independent read-only UI, interaction, and backend reviews
  - Found no remaining priority-one or priority-two issue, old reference, or
    accidental deletion after the clean full-suite rerun.
- `git diff --check`
  - Passed.

## Outcome

Playback exposes only the accepted Subtitle Focus interaction on Enter. The
replaced Quick Search UI and its unreachable configuration surface no longer
ship, while durable playback-navigation data and restore behavior remain
isolated and testable in the backend. The completed feature matched the
human-owned requirements without modifying or deleting stored user data.
