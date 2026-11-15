# 2026-11-15 Filter Dialog Primary Action Copy for Empty Search Query

- **Covering Requirement**: `docs/human/requirements/20261115-UI-Filter Dialog Apply Button Copy For Empty Search Query.md`
- **Branch / Baseline**: `main` (before change: `2b0ea71`, requirement commit: `baab146`)

## Summary of Changes

1. **Add trilingual empty-query filter application strings**
   - `apps/macos-native/Sources/CueSeekerApp/Resources/en.lproj/Localizable.strings`
   - `apps/macos-native/Sources/CueSeekerApp/Resources/zh-Hans.lproj/Localizable.strings`
   - `apps/macos-native/Sources/CueSeekerApp/Resources/zh-Hant.lproj/Localizable.strings`
   - Added `filter_dialog.apply_filters.one` and `filter_dialog.apply_filters.other` across all three localization bundles:
     - English: `Apply 1 filter` / `Apply %d filters` (`0` and `>= 2` format as `Apply 0 filters` / `Apply N filters`)
     - Simplified Chinese: `应用 1 个筛选条件` / `应用 %d 个筛选条件`
     - Traditional Chinese: `套用 1 個篩選條件` / `套用 %d 個篩選條件`
   - Formatted through `L(_:_:)` (`String(format:)` without grouping separators) so counts render as contiguous Arabic numerals without thousands commas.

2. **Empty-query primary button copy and interaction boundary in shared Filter dialog**
   - `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchSchemaSearch/CueFacetFilterPanel.swift`:
     - Added `CueFacetFilterDialogSession.Source.primaryActionTitle(totalCount:selectedFilterCount:isQueryEmpty:)`: returns `Apply 0 filters` / `Apply 1 filter` / `Apply N filters` (and localized equivalents) strictly when `source == .search` and `isQueryEmpty == true`; preserves existing `Calculating` / `Show 1 result` / `Show N results` / `Show 1 excerpt` / `Show N excerpts` behavior for non-empty `.search` queries and all `.excerpt` dialogs.
     - Added default parameter `isQueryEmpty: Bool = false` to `CueFacetFilterDialog`, computing the live total of selected filter chips across all five groups via `sections.reduce(0) { $0 + $1.selectedCount }` (matching toolbar badge `selectedOptionCount`), passing that count to `primaryActionTitle` in `footer`, and keeping the primary button enabled without a spinner when the search query is empty.
     - Passed `isQueryEmpty: searchState.isQueryEmpty` (`search.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty`) in `SearchFacetFilterDialog`, covering both Workbench Search and the Command Panel secondary search results Filter dialog; left `ExcerptFacetFilterDialog` on default `isQueryEmpty = false`.
     - Existing `.cueSeekerAppLanguageChanged` observation in `CueFacetFilterDialog` refreshes button copy immediately on live language switches while open; `Reset`, `Cancel`, and `.filterShow` accessibility activation paths remain unchanged.

3. **Scope check and pure-logic unit tests**
   - Kept edits surgical and in-place inside localization files and `CueFacetFilterPanel.swift`, without adding standalone frameworks, engines, managers, intermediate models, `docs/human/design/` edits, or production test backdoors.
   - `apps/macos-native/Tests/CueSeekerAppTests/SettingsStoreSearchTests.swift`: Added pure-logic tests `filterDialogPrimaryActionTitleCoversEmptySearchTrilingualCountsAndPreservesNonEmptyAndExcerpt` and `filterDialogEmptyAndWhitespaceSearchQueriesStayApplyReadyWithMatchingSelectedCount`, covering trilingual `0 / 1 / 2 / 1234` ungrouped numeral copy, empty vs. whitespace-only vs. non-empty queries, Excerpt regression safety, and five-section selected count parity with `selectedOptionCount` (including reset to zero) without synthetic windows or UI events.

## Compilation & Unit Test Verification

Executed after the final code and test edits:

1. **Build verification**:
   - `swift build --package-path apps/macos-native`: `Build complete! (0.34s)`, `0` errors.
2. **Targeted headless pure-logic tests (filtered, zero window popups)**:
   - `swift test --package-path apps/macos-native --filter "filterDialog|filterTrigger|searchFacetPersistence|settingsStore|WorkbenchAccessibilityStep2Tests|eachLanguageResolvesItsOwnLocalizationBundle|everyBundledLanguageDefinesTheSameKeys|singularCountKeysDoNotContainUnresolvedFormatPlaceholders"`
   - Result: `42` Swift Testing cases passed (`0` failed, covering the 2 new tests alongside existing search filter, settings persistence, localization key parity, and accessibility target logic tests).
3. **End-to-end acceptance**:
   - Live empty/whitespace query transitions, open-dialog language switching, toolbar badge synchronization, Command Panel secondary search page, and Excerpt detail Filter dialog behavior remain with the user for interactive acceptance.
