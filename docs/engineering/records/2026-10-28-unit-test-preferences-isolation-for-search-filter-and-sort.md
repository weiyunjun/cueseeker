# Implementation Record: Unit Test Preferences Isolation For Search Filter And Sort

- **Date**: 2026-10-28
- **Requirement**: `docs/human/requirements/20261028-Bug-Unit Test Preferences Isolation For Search Filter And Sort.md`
- **Design References**:
  - `docs/human/design/workbench/Search and Filter.md`
  - `docs/human/design/playback/Command Panel.md`

## Summary of Changes

1. **Isolated Unit Test UserDefaults & Temporary Databases**:
   - Updated unit tests that previously instantiated `AppCoordinator` without an isolated `UserDefaults` suite (`PlaybackSearchOverlayTests`, `PlaybackPlaylistSourceTests`, `PlaybackSubtitleFocusSessionStoreTests`, `PlaybackSubtitleFocusLayoutTests`, and `WorkbenchPageScrollbarTests`) to create a temporary `UserDefaults` suite (and temporary SQLite database URL where missing) and clean up the persistent domain and plist on teardown.
   - Prevented Command Panel search filter/sort tests (`playbackCommandPanelSearchPersistsWorkbenchFacetResultsAfterDismissal` and `commandPanelSearchFromNonSearchPageKeepsWorkbenchSearchQueryAndTableStateSynchronized`) from writing test filter/sort selections (such as `<1s` duration or `most_characters` sort order) into the user's shared application preferences domain (`com.cueseeker.shared`).
2. **Remote Folder Configuration Store & Subtitle Cache Test Isolation**:
   - Added unit-test process isolation in `ApplicationInfo` (`defaultSharedUserDefaults()` and `unitTestSubtitleCacheDirectoryURL` with automatic `atexit` cleanup) and wired `ApplicationPersistence.sharedUserDefaults()`, `WebDAVConfigurationStore`, `RemoteRootConfigStore` (`SMBConfigurationStore`, `FTPConfigurationStore`, `NFSConfigurationStore`), and `WebDAVSubtitleCache` to use isolated temporary storage whenever running in unit tests.
   - Added `setUserDefaultsForTesting(_:)` on remote configuration stores and updated `WebDAVSubtitleCache.setCacheDirectoryURLForTesting(_:)` to accept an optional `URL?`.
3. **Library Overview Sort Order & Remaining Test Plist Cleanup**:
   - Updated `LibraryStore` to read/write `library_overview_sort_order` through the injected `UserDefaults` passed from `AppCoordinator` rather than `UserDefaults.standard`.
   - Replaced remaining `UserDefaults(suiteName:)` and `.standard` usages in `WebDAVFolderDialogTests`, `SMBFolderDialogTests`, `FTPNFSFolderDialogTests`, `TooltipTests`, `AppLocalizationTests`, `WorkbenchPageScrollbarTests`, `PlaybackMoreMenuTests`, `PlaybackNormalShortcutTests`, `PlaybackSubtitleFocusSessionStoreTests`, and `WebDAVSupportTests` with `UserDefaults.temporary(suiteName:)` and `removePersistentDomainAndPlist(forName:)`.

## Verification

- Cleared the polluted `searchFacetExclusions` and reset `searchSortOrder` in `com.cueseeker.shared`, and removed leftover test `.plist` files from `~/Library/Preferences/`.
- Executed the affected unit test suites (`PlaybackSearchOverlayTests`, `PlaybackSubtitleFocusLayoutTests`, `WorkbenchPageScrollbarTests`, `WebDAVSupportTests`, `SMBSupportTests`, `FTPNFSSupportTests`, `WebDAVFolderDialogTests`, `SMBFolderDialogTests`, `FTPNFSFolderDialogTests`, `FileCardMenuTests`, `TooltipTests`, `AppLocalizationTests`, `PlaybackMoreMenuTests`, and `PlaybackNormalShortcutTests`), verified all tests pass, and confirmed `com.cueseeker.shared` and `~/Library/Preferences/` remain clean.
