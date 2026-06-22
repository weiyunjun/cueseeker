# Test Library Folder Flow

Human requirement:

- `docs/human/requirements/20260621-Feature-Test Library.md`

## Scope

Implemented the revised Test Library interaction model after the standalone Test
Recent Watching page was accepted for basic validation.

## Classification

- Product semantics: Complete Library now has separate folder summary and folder
  detail reads in `CueSeekerCore`.
- Platform UI/UX: Test Library now renders a folder-first Library page and a
  folder detail page with episode cards in SwiftUI.
- Platform integration: `AppCoordinator` loads lightweight folder summaries for
  the top-level page and loads a selected folder detail on demand.
- Playback execution: episode cards still reuse the existing Library playback
  path and saved resume position.
- Persistence semantics: Library playback history now stores "started" and
  "completed" milestones separately from the mutable resume position.
- Playback sync semantics: resume position is saved as continuous progress,
  while `started_at` and `completed_at` are written as one-way milestones.

## Changes

- Replaced the old Test Library combination page with a top-level `Library`
  folder card grid.
- Replaced expandable folder rows with a click-through folder detail view.
- Added a folder detail header with a chevron-left back button and folder title.
- Added folder summary and folder detail database queries so the top-level page
  no longer needs episode presentation rows.
- Kept folder cards separate from video cards: folder covers show only an
  episodes count badge, while episode cards retain progress and time badges.
- Removed Test Library scroll-position and expanded-folder persistence state.
- Added a separate Library playback navigation list for folder detail playback
  so formal Library presentation state is not polluted.
- Added a close-playback history revision so the folder detail view reloads its
  episode progress after returning from Library video playback.
- Added `started_at` and `completed_at` to `library_playback_history` in schema
  version 20. `position_ms` now remains only the resume point; watch status uses
  `completed_at` first, then `started_at`, then the legacy position heuristic.
- Backfilled the new watch-state columns during migration so existing finished
  and in-progress Library history keeps its presentation state.
- Updated Test Recent Watching and Test Library cards to render watch status
  from the persisted watch state instead of recalculating only from the current
  resume position.
- Split Library history writes so ordinary progress saves update `position_ms`
  without inferring `completed_at` from the current resume position.
- Added a playback-time milestone hook that writes `completed_at` as soon as a
  Library video reaches the completion threshold. Seeking back later only moves
  the resume position and does not roll the watch state back.

## Verification

- `swift build` passed.
- `swift test --filter completeLibraryFolderSummariesAndDetailSplitFolderAndEpisodeData` passed.
- `swift test --filter completeLibrary` passed.
- `swift test --filter closingLibraryPlaybackSavesHistoryAndMarksHistoryRevision` passed.
- `swift test --filter libraryPlaybackHistory` passed.
- `swift test --filter migrationBackfillsLibraryPlaybackHistoryWatchStateColumns` passed.
- `swift test --filter libraryPlaybackCompletionMilestoneSurvivesSeekingBackBeforeClose` passed.
- `swift test --quiet` passed: 321 Swift tests plus 7 XCTest cases.

## Outcome

Test Library can now be validated as the new folder-first flow while Test Recent
Watching remains a separate first-level test entry.
