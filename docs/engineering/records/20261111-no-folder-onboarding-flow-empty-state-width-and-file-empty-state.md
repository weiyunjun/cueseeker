# 2026-11-11: No-Folder Onboarding Flow, Empty State Width, and File Empty State

## Requirement Source
- `docs/human/requirements/20261111-Feature-No Folder Onboarding Flow Empty State Width And File Empty State.md`
- `docs/human/design/workbench/Library and File.md`
- `docs/human/design/playback/Command Panel.md`
- `docs/human/design/ui/UI Tokens.md`
- `docs/human/design/ui/UI Components - Domain.md`
- `docs/human/design/ui/UI Layouts - Workbench.md`
- `docs/human/design/ui/UI Layouts - Playback.md`
- `docs/human/design/ui/Empty State Icon Registry.md`
- `docs/human/design/ui/Icon Registry.md`
- `docs/human/design/ui/Tooltip Usage Registry.md`

## Summary of Changes
1. **Empty State Width Unification, Title Removal, and `folder-hint` Duotone Icon (`WorkbenchControlMetrics`, `AppIcon`, `WorkbenchEmptyHint`, Container Views)**:
   - Removed `redesignEmptyStateTitleFontSize`, `redesignEmptyStateTitleToMessageGap`, and `redesignEmptyStateMessageMaxWidth` (`380px`).
   - Removed the bold title slot, `380px` message width cap, and internal horizontal padding from `WorkbenchEmptyHint`, aligning empty state container width with each Workbench page, dialog, or overlay content region while keeping vertical and horizontal centering.
   - Added `AppEmptyStateIcon.folderHint` (`68px`, reusing the `folder` geometry with `emptyIconFolderTab` back tab and `emptyIconCollageFront` front body).
2. **`File` Level 1 3-Step Onboarding Shell, New Empty State, and Lifecycle (`SettingsStore`, `WorkbenchLayoutState`, `AppCoordinator`, `WorkbenchFileView`, `Localizable.strings`)**:
   - Persisted `hasCompletedFileOnboarding` in `SettingsStore`; armed mandatory 3-step onboarding starting at Step 1 when launching with `0` indexed folders before `Done` has ever been clicked, and opened directly into the new `File` empty state once `Done` has been clicked (or when removing the last folder at runtime).
   - Preserved the active onboarding step (`1..3`) across tab/route switches within the current app launch, kept the tutorial open without auto-refreshing if background folder indexing finishes mid-tutorial, and transitioned directly to either the root folder list (if folders finished indexing) or the new `File` empty state upon clicking Step 3 `Done`.
   - Built the 3-step onboarding shell reusing standard `Workbench Titled Page Layout` margins (`top: 4px`, `bottom: 24px`, `leading: 32px`, `trailing: 48px`), with the blank content area filling the upper remaining space and the `36px` button bar pinned to the bottom-right (`16px` gap: Step 1 `Next`, Step 2 `Back` + `Next`, Step 3 `Back` + `Done`).
   - Replaced the `0`-folder `File` Level 1 toolbar + legacy empty state with centered `folder-hint`, localized description (`file.empty.message`), dual `Neutral` buttons (`info` + `View Tutorial` and `folder-plus` + `Add Folder`, disabling `Add Folder` with `tooltip.disabled.file.task_or_compaction_running` during library tasks or database compaction while keeping `View Tutorial` enabled), and a separate-line clickable status indicator slot (`12px` below the button row with symmetric vertical counterweight for zero-jump status transitions).
3. **No-Folder Strong Onboarding Across Other Surfaces & Frozen-Page Unfreeze Boundaries (`AppCoordinator`, `AppCoordinator+Indexing`, `AppCoordinator+Search`, `AppCoordinator+WorkbenchAccessibility`, `PlaybackStore`, Workbench & Command Panel Views)**:
   - Rendered `folder-hint` + `onboarding.no_folder.message` + `Go to File` (`folder` icon) on `0`-folder `Search`, `Library` Level 1, `Excerpt` Level 1 (only when global Excerpt List count is `0`, clearing residual `overviewSearchDraft` while preserving existing Excerpt Lists when non-empty), Workbench `Recent` (keeping topbar `Videos` / `Excerpt Lists` tabs), and Playback `Command Panel -> Recent Videos / Recent Excerpt Lists` when the active sub-tab has no items.
   - Routed `Go to File` to `File` Level 1 with full navigation history parity (stopping playback and dismissing `Command Panel` first when invoked from `Command Panel -> Recent`), and immediately transitioned non-tutorial `0`-folder onboarding surfaces to normal content once the first folder finishes indexing.
   - Preserved anti-interruption page freezing when removing the last folder at runtime, unfreezing into no-folder strong onboarding upon query/filter/sort/submit refresh actions in `Search`, section switches in `Recent`, or cross-route navigation, and registered full keyboard/controller accessibility traversal and activation for `.noFolderGoToFileButton`, `.commandPanelGoToFileButton`, `.fileOnboardingBackButton`, `.fileOnboardingPrimaryButton`, and `.fileViewTutorialButton`.

## Verification
- Ran `swift test --package-path apps/macos-native --filter "NoFolderOnboardingAndFileEmptyStateTests|workbenchEmptyHint|emptyStateLocalizationMatchesRequirements|deletingActiveLastExcerptListNavigatesBackToEmptyOnboardingAndClearsSearchDraft|WorkbenchAccessibilityStep1Tests|WorkbenchAccessibilityStep4Tests"` (24 tests, all passed).
- Ran `swift test --package-path apps/macos-native --no-parallel --filter "NoFolderOnboardingAndFileEmptyStateTests|WorkbenchEmptyHintTests|AppIconAssetTests|WorkbenchControlMetricsTests|WorkbenchLayoutStateTests|WorkbenchAccessibilityStep1Tests|WorkbenchAccessibilityStep2Tests|WorkbenchAccessibilityStep3Tests|WorkbenchAccessibilityStep4Tests|FileCardMenuTests|FileDetailDialogTests|FileRouteNavigationTests|LibraryRouteSnapshotReuseTests|ExcerptListEditorTests|ExcerptLifecycleAndInvalidItemsTests|ExcerptPresentationTests|PlaybackLibraryChangeTests|PlaybackEntryAndExcerptNavigationTests|PlaybackExcerptOverlayTests|PlaybackLibraryOverlayTests|PlaybackMultiModuleOverlayIntegrationTests|PlaybackSearchOverlayTests|PlaybackStoreTests|RecentPlaybackSessionRegressionTests|SearchInvalidItemsPruningTests|SearchStoreTests|AppStartupDatabaseTests|URLSchemeSearchRoutingTests|TooltipTests"` (236 tests, all passed).
