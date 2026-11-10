# 2026-11-11: Excerpt List Empty State, Last List Deletion, and Recent Retention

## Requirement Source
- `docs/human/requirements/20261111-Feature-Excerpt List Empty State Last List Deletion And Recent Retention.md`
- `docs/human/design/workbench/Excerpt and Export.md`
- `docs/human/design/playback/Playback Edge Cases.md`
- `docs/human/design/ui/UI Components - Domain.md`
- `docs/human/design/ui/Empty State Icon Registry.md`
- `docs/human/design/ui/Toast Usage Registry.md`

## Summary of Changes
1. **No Initial Default Excerpt List & Unrestricted Last-List Deletion (`DatabaseBootstrap`, `ExcerptDatabase`, `ExcerptListCardGrid`, `WorkbenchExcerptTableView`, `ExcerptStore`, `AppCoordinator`)**:
   - Stopped seeding `"Default"` on fresh database bootstrap (`previousVersion == 0`), keeping initial Excerpt List count at `0` while preserving existing lists on schema upgrades.
   - Removed the `listCount > 1` deletion guard from `ExcerptDatabase.deleteExcerptList`, `ExcerptListCardGrid`, and `WorkbenchExcerptTableView`, allowing `Delete List` in Excerpt Overview, Excerpt Detail `More`, Workbench `Recent -> Excerpt Lists`, and Playback `Command Panel -> Recent Excerpt Lists` even when only one list remains, and cleaning unreferenced tombstones on deletion.
   - Verified `Save to Excerpt` destination menus display only `New List` (without divider) when zero lists exist and automatically save target cue(s) into the newly created list.
2. **Recent Excerpt Lists Retention & Playback-Only Time Grouping (`ExcerptDatabase`, `IndexingDatabase+TombstoneReconciliation`, `ExcerptStore`, `PlaybackStore`)**:
   - Included all existing Excerpt Lists (empty, all-invalid, and valid) in `recentExcerptListSummaries()`, ordering played lists by `recent_played_at DESC, id DESC` and never-played lists by `created_at ASC, id ASC`.
   - Stopped clearing `recent_played_at` during tombstone reconciliation or excerpt deletion/moves so previously played lists retain their historical time section (`Today` / `Yesterday` / `Last 7 Days` / `Earlier`) regardless of current content validity, and synchronized in-memory `recentListSummaries` on list creation, edit, deletion, and actual playback.
3. **No Available Excerpts Presentation, Interception, and Copy (`AppCoordinator+Excerpt`, `AppCoordinator+PlaybackCommandPanel`, `AppCoordinator+PlaybackLibraryChange`, `PlaybackViewModel+Feedback`, `Toast`, `Localizable.strings`)**:
   - Kept reconciled Excerpt Detail `Cover Summary` hiding progress and showing a disabled `Play` button when valid excerpt count is `0`.
   - Intercepted `Play` / `Resume` clicks on unrefreshed frozen Excerpt Detail `Cover Summary`, Workbench `Recent -> Excerpt Lists`, and Playback `Command Panel -> Recent Excerpt Lists` when no valid excerpts exist in the database, keeping the current surface / Command Panel open without recording `recent_played_at`, and showing a 3-second bottom-right warning Toast (`No Available Excerpts` / `没有可用的摘录` / `沒有可用的摘錄`).
   - Updated 1-second top-left `Playback Feedback` (`warning` icon) when navigating an Excerpt playlist with 0 available items to use `playback.hud.no_available_excerpts` while preserving `No Available Results` for Search playlists.
4. **Excerpt Overview Empty-List Onboarding State (`AppIcon`, `WorkbenchEmptyHint`, `ExcerptListOverviewView`, `AppCoordinator+WorkbenchAccessibility`, `Localizable.strings`)**:
   - Added `AppEmptyStateIcon.excerptHint` (single-layer rounded swallowtail bookmark filled with `WorkbenchRedesignColors.emptyIconCollageBack` = macOS accent color at `0.52` alpha) and optional `Neutral` `WorkbenchButton` action support on `WorkbenchEmptyHint`.
   - Hid the Excerpt Overview action bar and cleared residual `overviewSearchDraft` when global Excerpt List count is `0`, centering the accent bookmark icon, localized hint (`excerpt.overview.empty_hint`), and `+ New List` button (`.excerptNewListButton`) while preserving Sidebar and Topbar.

## Verification
- Ran `swift test --package-path apps/macos-native --filter ExcerptDatabaseTests` (all passed).
- Ran `swift test --package-path apps/macos-native --filter "ToastTests|WorkbenchEmptyHintTests|ExcerptListEditorTests|ExcerptLifecycleAndInvalidItemsTests|ExcerptPresentationTests|PlaybackEntryAndExcerptNavigationTests|PlaybackExcerptOverlayTests|PlaybackLibraryChangeTests|PlaybackSubtitleFocusKeyboardActionTests"` (95 tests, all passed).
- Ran `swift test --package-path apps/macos-native --filter SearchInvalidItemsPruningTests` (all passed).
