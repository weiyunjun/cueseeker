# 20261024 Workbench Search Input and Command Panel Search Query Synchronization

## 1. Requirement Reference

- Requirement: `docs/human/requirements/20261024-Bug-Workbench Search Input And Command Panel Search Query Synchronization.md`
- Stabilized Design References:
  - `docs/human/design/playback/Command Panel.md`
  - `docs/human/design/workbench/Search and Filter.md`
  - `docs/human/design/ui/UI Layouts - Workbench.md`
  - `docs/human/design/ui/UI Layouts - Playback.md`

## 2. Implementation Summary

1. **Unify Workbench Search Input with `SearchStore.searchQuery` (`SearchStore.swift`, `WorkbenchSearchView.swift`)**:
   - Removed the redundant `tableSearchDraft` property from `SearchStore` and the local `@State private var searchDraft` from `WorkbenchSearchView`, binding the Workbench Search top input field directly to `search.searchQuery`.
   - Reset `tableViewportAnchor`, `tableSelectionState`, and `tableSelectionEntryIDs` in `SearchStore.updateQuery(_:)` whenever `searchQuery` changes so searches triggered while `WorkbenchSearchView` is unmounted (such as Command Panel searches started from Recent / Library / Excerpt playback) never leave stale table selection or scroll anchors behind.
2. **Regression Test Coverage (`PlaybackSearchOverlayTests.swift`)**:
   - Added `commandPanelSearchFromNonSearchPageKeepsWorkbenchSearchQueryAndTableStateSynchronized` to verify that searching a new keyword and updating Filter / Sort in Command Panel while the Workbench is on a non-Search route keeps `search.searchQuery`, filter/sort state, and the Search table projection synchronized upon returning to the Search page.

## 3. Verification

- Executed `swift test --package-path apps/macos-native --filter "PlaybackSearchOverlayTests|SearchStoreTests|TableSandboxRowModelStoreTests"`.
- All unit tests compiled cleanly and passed.
