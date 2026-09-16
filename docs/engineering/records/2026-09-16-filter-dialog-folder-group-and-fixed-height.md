# Filter Dialog Folder Group And Fixed Height

## Human-Owned Source

- `docs/human/requirements/20260916-Feature-Filter Dialog Folder Group And Fixed Height.md`
- `docs/human/design/UI Design System.md` (Filter Dialog Layout, Filter Chip, Dialog, Library Folder Card Layout; to be updated by the owner after acceptance, section 9 of the requirement)

## Baseline

The search scan has not changed since `2026-09-15-search-single-full-scan-step-1.md` (the commits between touched the icon button, the dialog layer and the Anki export), so its numbers are the baseline: app level, Debug E2E controller, live library (77,145 matches for `の`, 41 folders), window 1445 × 821, no selection, hot runs after an `abc` search: first page 143 to 155 ms, completion 2685 / 2119 ms and 2701 / 2118 ms (e2e / db), a main-thread stall of 381 to 441 ms at completion for the 77,145-row installation.

A baseline taken at `7ef0c44a` at the start of this work (hot 5002 / 3996 ms) and every timing taken before 00:25 on 2026-09-17 were polluted: a throwaway width-measuring `swift` script of this session looped without end, and `pkill` on the driver left its `swift-frontend -interpret` child running for 86 minutes at 98% CPU and 43 GB, filling swap. Those timings are discarded; the process was ended and the timings below were taken afterwards.

## Implementation

- Folder is a fifth facet. `CueFacetFilter.excludedFolders` remembers the listed folders that are not selected and is nil while the group has no selection, so a folder indexed later is selected with the rest and stays unselected when nothing is; `toggleFolder(_:listed:)` starts a selection by leaving every other listed folder out and ends it when the last folder is deselected; `normalizingFolders(listed:)` turns a selection that leaves out every listed folder into none (requirement 3.3). `CueFacetSnapshot` carries each match's folder and `CueFacetDistribution` its counts; `filteredCueIDs` counts the Folder group ignoring its own selection and applies it to the other four.
- The search scan takes each match's folder from the search order rows it already reads per file (one string shared by every match of the file, not a column read per row, which cost about 3% on the bench). With a Folder selection `searchFileRanks` also returns the files of the selected folders, `orderedFTSHitRowIDs` puts their hits before the rest with each run in display order, and `facetSnapshot()` merges the two runs back into display order by file rank before the snapshot is built, so a changed selection after completion projects in display order as before. Results only come from the selected folders, so the first-page and completion pushes are unchanged.
- `CueFacetCountCache` counts the folder facet from the search order rows for the empty-query distribution, which lists the folders for the dialog; it skips the group during migrations from schemas whose order rows have no folder yet. Schema 50 rebuilds the counts once so a library indexed before it lists its folders at first launch.
- The Excerpt resident snapshot derives each cue's folder from its subtitle path the same way the order rows do.
- Settings persist the group as a `folder` exclusion list, absent while the group has no selection. `SearchStore` normalizes the filter when it is set, projected and when the empty-query distribution reloads after indexing; the Excerpt projection funnel normalizes with the same listed folders, and the dialog's Reset reads the normalized filter.
- The dialog gains the Folder section last, listing every folder the library counts, in the Library Video tab's order (name, then path, without regard to case), with the folder name as the chip's title. Search and Excerpt list the same languages and folders from the library's empty-query distribution, so Excerpt no longer lists only its own languages nor narrows a selection to them. Chips take at most `--max-width-filter-chip` (332) with the name truncated by an ellipsis, and the dialog keeps `--height-filter-dialog` (600), or the window's room when less, as a VStack whose scroll view fills the middle so the footer keeps the bottom.

Files:

- `apps/macos-native/Sources/CueSeekerCore/CueFacetFilter.swift`
- `apps/macos-native/Sources/CueSeekerCore/CueFacetCountCache.swift`
- `apps/macos-native/Sources/CueSeekerCore/DatabaseBootstrap.swift`
- `apps/macos-native/Sources/CueSeekerCore/SearchDatabase.swift`
- `apps/macos-native/Sources/CueSeekerCore/ExcerptDatabase.swift`
- `apps/macos-native/Sources/CueSeekerApp/Search/SearchStore.swift`
- `apps/macos-native/Sources/CueSeekerApp/Excerpt/ExcerptStore.swift`
- `apps/macos-native/Sources/CueSeekerApp/App/AppCoordinator+Excerpt.swift`
- `apps/macos-native/Sources/CueSeekerApp/Settings/SettingsStore.swift`
- `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchSchemaSearch/CueFacetFilterPanel.swift`
- `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchControls/WorkbenchControls.swift`
- `apps/macos-native/Sources/CueSeekerApp/Resources/*/Localizable.strings`
- Tests: `CueFacetFilterTests`, `SearchDatabaseTests`, `ExcerptDatabaseTests`, `DatabaseBootstrapTests`, `SettingsStoreSearchTests`, and the folder argument at every test that builds a snapshot or distribution
- `docs/changelog.md`

## Verification

- New tests: the Folder selection remembers the folders left out, a later folder joins it, every listed folder selected is still a selection, deselecting the last leaves none, and a selection that leaves out every listed folder normalizes to none; the snapshot counts folders ignoring their own selection; a scan with only the last folder in display order selected returns that folder's rows in order while its snapshot equals the unfiltered scan's, and the empty-query counts list both folders; the Excerpt snapshot carries the folder; settings restore a folder selection and keep no selection apart from every folder selected; the dialog lists folders last in library order with their counts and toggles them; schema 49 to 50 rebuilds the folder counts.
- `swift test`: 1237 tests, 28 issues in 16 tests, all in the environment-sensitive set of the earlier records: native playback (6), Debug E2E scene and width (2), Library folder removal (3), Excerpt remount and scoped invalidation (2), `playbackPlayerKeepsAutoPauseBoundaryAcrossUserSeeks`, `progressiveSearchProjectionRefreshesOnlyMountedTable` and `sharedPersistenceMigrationCopiesLegacyValuesWithoutOverwritingSharedValues`. Run alone, the last two, `libraryFolderRemovalAndIndexingRejectEachOther` and `searchFacetSelectionDoesNotRefreshGlobalOrInactiveSurfaces` pass.
- Bench, DB level, on the polluted machine but paired back to back on a read-only `.backup` copy of the live library (`SearchBench`, `の`, limit 100, five hot runs, min / median): code at `7ef0c44a` 4127 / 4234 ms, the change 4184 / 4240 ms. Reading the folder as a column per matched row had cost about 3% (4070 / 4140 ms against 3947 / 4003 ms); one string per file removed it.
- App level, committed build, machine recovered, same procedure as the baseline, `logs/search-e2e/search-e2e-2026-09-17.jsonl` from 00:28:

| Run | First page e2e / db | Complete e2e / db | Main-thread stall at completion |
| --- | --- | --- | --- |
| No filter, first run of the launch | 173 / 54 ms | 2672 / 2098 ms | 357 ms |
| No filter, hot | 165 / 50 ms | 2725 / 2121 ms | 458 ms |
| No filter, hot repeat | 154 / 45 ms | 2722 / 2119 ms | 467 ms |
| Folder `赛马娘 第1季` (1,147 results), hot | 154 / 45 ms | 2084 / 1921 ms | none logged |
| Folder, hot repeat | 160 / 49 ms | 2091 / 1925 ms | none logged |

  Unfiltered, the change matches the baseline to the millisecond of database time (2119 to 2121 ms against 2118 to 2119 ms). With the folder selected the first page arrives as early as without a filter although the folder is late in display order, and completion is faster because 1,147 rows are installed instead of 77,145.
- Dialog, in-app: 720 × 600 centred, header and footer fixed, the groups scrolling with the scrollbar in the inset; the Folder group last with the folder icon, 41 chips wrapping three to four to a line at these name lengths, in the Video tab's order with their counts; selecting `赛马娘 第1季` turned the chip green, the other four groups' counts to the folder's 1,147 rows while the Folder counts stayed, Show read `Show 1147 results` and the table kept its 77,145 rows until Show; Show after the completed search projected 1,147 rows in 59 ms without a search; reopening showed the applied counts; Reset then Show projected 77,145 rows back in 366 ms. The saved Search selection was left empty.
- Not exercised in-app: no folder name in the live library reaches the 332 cap, so the ellipsis rests on SwiftUI's single-line truncation; the Excerpt dialog and the new-folder rule after indexing (requirement 3, acceptance 5) are left to the owner's acceptance as agreed.

## Outcome

Matched the requirement: the Folder group lists the library's folders last in the Video tab's order for Search and Excerpt, remembers the folders left out so a later folder joins a selection, the Excerpt dialog lists the library's languages, chips are capped at 332 and the dialog at 600, the scan reads the selected folders first without changing the pushes or the projection, and the unfiltered scan completes in the same time as before. Schema 50 counts the folders of an existing library.
