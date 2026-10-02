# Intercept Invalid Items in Action Overlay and Row Menu

Human-owned documents:

- `docs/human/requirements/20261001-Feature-Intercept Invalid Items In Action Overlay And Menu.md`
- `docs/human/design/Toast Usage Registry.md`

## Why

1. When multiple items are selected in Search or Excerpt views, users can trigger batch actions (`Export to Anki`, `Copy Deep Links`, `Copy Table`) via the Selection Action Overlay. If some or all selected items have been removed from the library (invalid):
   - Previously, batch actions attempted to process invalid items, which either failed or caused unintended side-effects.
   - Per requirement, if all selected items are invalid, the action must be intercepted with a warning toast (`Cue Not in Library` for 1 item, `Cues Not in Library` for >1 items, 3.0s, `.warning`), and the table selection state (checkboxes) must remain unchanged.
   - If only a portion of the selected items are invalid, the action should execute normally on the valid items, presenting standard success feedback, while keeping the selection checkboxes unchanged.
2. In the Excerpt table row menu, clicking `Move to List` or `Duplicate to List` (including selecting a destination list or creating a new list) for an excerpt whose backing cue is no longer in the library must be intercepted with a warning toast (`Cue Not in Library`, 3.0s, `.warning`).

## What changed

- **Localization & Toast Requests**:
  - Added `toast.cues_not_in_library` string to `en.lproj` ("Cues Not in Library"), `zh-Hans.lproj` ("台词不在媒体库中"), and `zh-Hant.lproj` ("台詞不在資料庫中").
  - Added `TableToastRequest.cuesNotInLibrary` and helper `TableToastRequest.cueNotInLibrary(count:)` returning singular or plural toast based on count.
- **Search Selection Action Overlay**:
  - In `WorkbenchTestSearchView`:
    - Updated `exportSelectedRowsToAnki()`: filters selected rows by `appState.cueIDsInLibrary(among:)`. If all invalid, intercepts and displays `cueNotInLibrary(count:)` toast without opening export dialog. If partially valid, opens export dialog with only valid items. Selection checkboxes remain unchanged in both cases.
    - Updated `copySelectedRowsAsTable()`: filters selected rows by library presence. If all invalid, intercepts with `cueNotInLibrary(count:)` toast. If partially valid, copies valid rows to clipboard and displays standard `copyTable` toast.
    - Updated `copySelectedRowsAsDeepLinks()`: filters selected rows by library presence. If all invalid, intercepts with `cueNotInLibrary(count:)` toast. If partially valid, copies valid rows to clipboard and displays standard `copyDeepLinks` toast.
- **Excerpt Selection Action Overlay**:
  - In `WorkbenchExcerptTableView`:
    - Added `isExcerptValid(_:row:)` checking `item.isValid`, `!row.cueState.isUnavailable`, and `appState.excerptIDsInLibrary(among:)`.
    - Updated `exportSelectedRowsToAnki()`, `copySelectedRowsAsTable()`, and `copySelectedRowsAsDeepLinks()` to validate rows against library availability. If all invalid, displays `cueNotInLibrary(count:)` toast. If partially valid, filters to valid rows only and preserves selection checkboxes.
- **Excerpt Row Menu & Lifecycle Guards**:
  - In `SubtitleTableView`:
    - In `performActiveRowMenuDestinationAction` and `performActiveRowMenuCreateListAction`, guarded `.moveToList` and `.duplicateToList` actions against `isCueInLibrary(cueID)`. If invalid, displays `TableToastRequest.cueNotInLibrary` toast and cancels the transfer.
  - In `WorkbenchExcerptTableView`:
    - In `moveExcerpt`, `duplicateExcerpt`, and `createExcerptList`, verified item validity and library presence via `appState.excerptIDsInLibrary(among:)`. If invalid, displays `TableToastRequest.cueNotInLibrary` toast and cancels transfer.
  - In `AppCoordinator+Excerpt`:
    - Added defensive guards in `moveExcerpt`, `duplicateExcerpt`, and `beginCreatingExcerptList` to intercept invalid items and show `TableToastRequest.cueNotInLibrary`.

## Tests

- `ToastTests`:
  - Verified `TableToastRequest.cuesNotInLibrary` matches specification (icon: `.warning`, duration: 3.0s, localized text) and `TableToastRequest.cueNotInLibrary(count:)` returns singular for 1 and plural for >1.
- `SubtitleTableRowActionMenuTests`:
  - Added `subtitleTableRowActionMoveAndDuplicateInterceptInvalidItems()`: verifies row menu `.moveToList` and `.duplicateToList` are intercepted with `Cue Not in Library` toast when the item is not in the library.
- `ExcerptLifecycleAndInvalidItemsTests`:
  - Added `invalidExcerptMoveAndDuplicateAreIntercepted()`: verifies coordinator `moveExcerpt`, `duplicateExcerpt`, and `beginCreatingExcerptList` intercept invalid items when cues are removed from database.
- `SelectionActionOverlayInvalidItemsTests`:
  - Added unit test suite covering:
    - Search selection overlay: singular toast on single invalid row, plural toast on multiple invalid rows, valid-row filtering on partially invalid rows with selection preserved.
    - Excerpt selection overlay: singular toast on single invalid row, plural toast on multiple invalid rows, valid-row filtering on partially invalid rows with selection preserved.
