# Implementation Record: Recent Time Grouping And Never Played Section

- **Requirement**: `docs/human/requirements/20261016-UI-Recent Time Grouping And Never Played Section.md`
- **Date**: 2026-10-16

## Summary of Changes

1. **Calendar-Day Time Grouping Model (`RecentTimeSection`)**:
   - Added `RecentTimeSection` (`today`, `yesterday`, `last7Days`, `earlier`, `neverPlayed`) in `apps/macos-native/Sources/CueSeekerCore/LibraryDatabaseModels.swift` with `classify(timestamp:relativeTo:calendar:)` and `group(_:timestamp:relativeTo:calendar:)`.
   - Divided sections by local calendar midnight $T_0$ (`calendar.startOfDay(for: referenceDate)`):
     - `Today`: $t \ge T_0$
     - `Yesterday`: $T_0 - 1\text{d} \le t < T_0$
     - `Last 7 Days`: $T_0 - 6\text{d} \le t < T_0 - 1\text{d}$
     - `Earlier`: $t < T_0 - 6\text{d}$
     - `Never Played`: nil or empty timestamp

2. **Database & Store Support for `Never Played` Items**:
   - Updated `LibraryDatabase.recentLibraryWatching(under:limit:includesNeverPlayed:)` in `apps/macos-native/Sources/CueSeekerCore/LibraryDatabase+Presentation.swift` to append `EP01` (`episode_number = 1`, `updated_at = ''`) for folders that have no playback record in `library_playback_history` when `includesNeverPlayed == true`, ordered by `folder_title COLLATE NOCASE ASC, folder_path COLLATE NOCASE ASC`.
   - Updated `AppCoordinator.refreshTestRecentWatching()` in `apps/macos-native/Sources/CueSeekerApp/App/AppCoordinator+Library.swift` to query `recentLibraryWatching(..., includesNeverPlayed: true)` and filtered `recentWatchingItem(for:)` in `WorkbenchTestLibraryView.swift` on `!$0.updatedAt.isEmpty` so `Library Folder Detail` (`L-04.3`) continues to display `Play` rather than `Resume` for never-played folders.
   - Updated `ExcerptDatabase.recentExcerptListSummaries()` in `apps/macos-native/Sources/CueSeekerCore/ExcerptDatabase.swift` to include excerpt lists with `recent_played_at IS NULL` that contain valid playable excerpts after played lists, ordered by `created_at ASC, id ASC`, with `resumeExcerpt = nil` and `resumePosition = nil`.
   - Updated `AppCoordinator.openRecentExcerpt(_:)` and `recordRecentExcerptPlayback(for:)` in `apps/macos-native/Sources/CueSeekerApp/App/AppCoordinator+Excerpt.swift` so opening a never-played excerpt list starts from the first valid excerpt and immediately stamps `recentPlayedAt` for optimistic sorting.

3. **Section Title & Spacing Layout Across Workbench `Recent` and `Command Panel`**:
   - Added `recent.section.{today,yesterday,last_7_days,earlier,never_played}` strings across `en`, `zh-Hans`, and `zh-Hant` in `Localizable.strings`.
   - Added `RecentSectionTitleView` (`C-08.7 Section Title`: `--font-size-section-title: 18px`, `Semibold`, `--color-text-primary`, single-line, left-aligned via `--padding-library-media-card-hover: 12px`, non-clickable, no hover effect) and updated `RecentWatchingGrid` in `WorkbenchTestLibraryView.swift` and `ExcerptListCardGrid` (`groupsByRecentSection: true`) in `ExcerptListCardGrid.swift` / `PlaybackCommandPanel.swift` to group cards with `--spacing-3` (`12px`) between section title and card grid and `--spacing-3` (`12px`) between adjacent section containers.

## Verification

- Automated unit & integration tests (`swift test --package-path apps/macos-native`):
  - `LibraryDatabaseTests`: `recentLibraryWatchingAppendsNeverPlayedFoldersWithEP01SortedByFolderTitle`, `recentTimeSectionClassifiesAndGroupsByLocalCalendarDayBoundaries`
  - `ExcerptDatabaseTests`: `recentExcerptListSummariesIncludesNeverPlayedPlayableListsOrderedByCreatedAt`
  - `ExcerptPresentationTests` & `RecentPlaybackSessionRegressionTests`: all 15 tests passed.
