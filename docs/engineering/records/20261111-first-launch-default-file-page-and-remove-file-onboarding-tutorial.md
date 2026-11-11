# 2026-11-11: First-Launch Default File Page and Removal of File Onboarding Tutorial

## Requirement Source
- `docs/human/requirements/20261111-Feature-First Launch Default File Page And Remove File Onboarding Tutorial.md`
- `docs/human/design/workbench/Library and File.md`
- `docs/human/design/playback/Playback Edge Cases.md`
- `docs/human/design/ui/UI Components - Domain.md`
- `docs/human/design/ui/UI Layouts - Workbench.md`
- `docs/human/design/ui/UI Accessibility Rules.md`
- `docs/human/design/ui/Icon Registry.md`

## Summary of Changes
1. **First-Launch Initialization Defaulting to `File` Level 1 (`DatabaseBootstrap`, `WorkbenchLayoutState`, `AppCoordinator`)**:
   - Returned `DatabaseBootstrapResult(didCreateSchema:)` from `@discardableResult DatabaseBootstrap.prepare(at:)` when initializing a brand-new SQLite database (`PRAGMA user_version == 0`).
   - Removed the `"workbenchPanelMode": "search"` volatile default registration in `AppCoordinator` so missing local primary-page history is detected cleanly.
   - Updated `WorkbenchLayoutState` to open on `File` Level 1 (`.file`) and persist `"file"` when no saved primary-page history exists, and added `resetInitialRouteToFile()` invoked by `AppCoordinator` whenever `DatabaseBootstrap.prepare(at:)` creates a brand-new database schema on launch; subsequent launches continue restoring the last visited primary page.
2. **Removal of `File` 3-Step Onboarding Shell & Simplification of `File` Zero-Folder Empty State (`ApplicationPersistence`, `SettingsStore`, `WorkbenchLayoutState`, `AppCoordinator`, `AppCoordinator+Indexing`, `WorkbenchAccessibility`, `AppCoordinator+WorkbenchAccessibility`, `WorkbenchFileView`, `Localizable.strings`)**:
   - Removed the 3-step `File` onboarding shell (`Back`, `Next`, `Done`), `hasCompletedFileOnboarding` persistence (registering `"hasCompletedFileOnboarding"` for obsolete preference cleanup in `ApplicationPersistence`), cross-page step memory, mid-tutorial refresh suppression, `View Tutorial` button, associated accessibility targets (`.fileOnboardingBackButton`, `.fileOnboardingPrimaryButton`, `.fileViewTutorialButton`), and retired localization strings across `en`, `zh-Hans`, and `zh-Hant`.
   - Simplified the `File` Level 1 zero-folder empty state to display centered `folder-hint` (`68px`), localized description (`file.empty.message`), and a single centered `Add Folder` (`Neutral`) button (`folder-plus` icon, 5-protocol menu, disabled with existing tooltip during active library tasks or database compaction), keeping the separate-line clickable status indicator `12px` below with zero main-body jump and immediate transition to the root folder card list once the first folder finishes indexing.
   - Preserved no-folder `Go to File` onboarding across `Search`, `Library` Level 1, `Excerpt` Level 1 (when global Excerpt List count is `0`), Workbench `Recent`, and Playback `Command Panel -> Recent`, along with anti-interruption freeze/unfreeze behavior and global empty-state width/title rules.
3. **Unit & Integration Test Updates (`NoFolderOnboardingAndFileEmptyStateTests`, `WorkbenchLayoutStateTests`, `ApplicationPersistenceTests`, `WorkbenchAccessibilityStep1Tests`, `WorkbenchEmptyHintTests`, `SearchInvalidItemsPruningTests`, `URLSchemeSearchRoutingTests`)**:
   - Added startup routing tests covering brand-new `UserDefaults` + database launch on `File`, persistence of `"file"`, subsequent relaunch restoration of `Search` / `Excerpt`, and database recreation resetting stale `UserDefaults` back to `File`.
   - Updated zero-folder `File` empty state, accessibility traversal, localization, Search reappearance, and URL scheme direct-play tests to match the new `File` default and single-button empty state.

## Verification
- Ran `swift test --package-path apps/macos-native --no-parallel --filter "NoFolderOnboardingAndFileEmptyStateTests|ApplicationPersistenceTests|WorkbenchEmptyHintTests|AppIconAssetTests|WorkbenchControlMetricsTests|WorkbenchLayoutStateTests|WorkbenchAccessibilityStep1Tests|WorkbenchAccessibilityStep2Tests|WorkbenchAccessibilityStep3Tests|WorkbenchAccessibilityStep4Tests|FileCardMenuTests|FileDetailDialogTests|FileRouteNavigationTests|LibraryRouteSnapshotReuseTests|ExcerptListEditorTests|ExcerptLifecycleAndInvalidItemsTests|ExcerptPresentationTests|PlaybackLibraryChangeTests|PlaybackEntryAndExcerptNavigationTests|PlaybackExcerptOverlayTests|PlaybackLibraryOverlayTests|PlaybackMultiModuleOverlayIntegrationTests|PlaybackSearchOverlayTests|PlaybackStoreTests|RecentPlaybackSessionRegressionTests|SearchInvalidItemsPruningTests|SearchStoreTests|AppStartupDatabaseTests|URLSchemeSearchRoutingTests|TooltipTests"` (236 tests, all passed).
- Outcome matched all requirement and design specifications.
