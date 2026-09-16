# Filter Dialog Rounded Chips, Selection Counts And Group Actions

## Human-Owned Source

- `docs/human/requirements/20260917-UI-Filter Dialog Rounded Chips Selection Counts And Group Actions.md`
- `docs/human/design/UI Design System.md` (Filter Chip, Button, Information Badge / Task Count Badge, Search / Excerpt Toolbar Layout, Filter Dialog Layout; to be updated by the owner after acceptance)

## Implementation

- Options draw as a rounded rectangle with `--radius-control` instead of a capsule; the count placeholder is unchanged.
- The footer drops the calculating status. Reset leads, Cancel and Show trail. While the total is unknown Show reads `Calculating` with the Spinner in the button's icon slot and stays disabled; `WorkbenchPrimaryButton` gains `showsSpinner`, and `showTitle` now takes a known total only, so the `Show results` / `Show excerpts` strings without a number are removed from the three localizations.
- `CueFacetSection` builds every group through one helper from an option's selected test and toggle, so the Folder group keeps its own rules (`toggleFolder`), and adds `selectAll`, `deselectAll` and `invertSelection`: each toggles, in one change of the dialog's selection, the group's listed options that are unselected, selected, or all of them. `selectedCount` counts the options shown as selected.
- The section header shows that count with the existing Task Count Badge (surface `--color-bg-surface`, text in the header's secondary color, hidden at 0), then the three actions at the row's end as `WorkbenchButton` (Button / Neutral) with the new optional `height` set to `--height-filter-chip`, gap `--spacing-2`. They have no disabled state.
- The Filter trigger passes the table's applied selection count to the Icon Button's existing count. `CueFacetFilter.selectedOptionCount(emptyDistribution:snapshot:)` sums the groups' counts over the options the dialog lists for the same inputs, so the trigger always equals the sum of the headers for that selection. Search reads the library distribution and its complete snapshot; Excerpt reads the library distribution and the list's resident snapshot, as its dialog does.

Files:

- `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchSchemaSearch/CueFacetFilterPanel.swift`
- `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchSchemaSearch/SchemaWorkbenchSearchShell.swift`
- `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchControls/WorkbenchControls.swift`
- `apps/macos-native/Sources/CueSeekerApp/TableSandbox/WorkbenchTestSearchView.swift`
- `apps/macos-native/Sources/CueSeekerApp/TableSandbox/WorkbenchExcerptTableView.swift`
- `apps/macos-native/Sources/CueSeekerApp/Resources/*/Localizable.strings`
- `apps/macos-native/Tests/CueSeekerAppTests/SettingsStoreSearchTests.swift`
- `docs/changelog.md`

## Verification

- New tests: the Duration group's Invert Selection, Select All and Deselect All each make one change and leave Language untouched, with the header count following; the Folder group's actions keep the folder rules (inverting no selection selects every folder, inverting all leaves none, inverting one selects the other two, Select All leaves no folder out, Deselect All leaves no selection); the trigger count adds two durations, one language, one watch state and the two listed folders a selection keeps.
- `swift test`: 1240 tests, 30 issues in 15 tests, all in the environment-sensitive set of the earlier records (native playback, Debug E2E scene and width, Library folder removal, Excerpt remount and scoped invalidation, `playbackPlayerKeepsAutoPauseBoundaryAcrossUserSeeks`, `progressiveSearchProjectionRefreshesOnlyMountedTable`, `searchFacetSelectionDoesNotRefreshGlobalOrInactiveSurfaces`). Run alone, both Library folder removal tests and the two search invalidation tests pass; `showCueGroupInvalidationIsScopedToMountedExcerpt` and `excerptTableStartsAtTopAfterPanelRemount` fail alone the same way on `b910e4a5` without this change.
- In-app, Debug E2E controller, 1445 × 821, Light: the saved Search selection (Japanese, Finished, 13 folders) shows 15 on the trigger and 1, 1 and 13 in the headers, with the rounded options, the actions at each header's end and Reset at the bottom left. Invert Selection on Duration selected its four options and on Folder turned 13 into 28, the actions staying in place while the counts changed and the trigger keeping 15 until Show; Cancel discarded them. Opened right after pasting `の`, Show read `Calculating` beside a turning spinner and was disabled; once the search completed it read `Show 23336 results`. In the Excerpt list `我喜欢的字幕` (397 cues), Select All on Duration then Show put 4 on its trigger; Reset then Show removed it. The query was cleared, the Excerpt selection restored and the App left on Search.
- Not exercised in-app: Dark appearance, which takes only existing tokens, is left to the owner's acceptance.

## Outcome

Matched the requirement: rounded options, `Calculating` inside a disabled Show while the total is unknown, Reset at the bottom left, the selected numbers on the Filter trigger and every group header, and the three group actions changing only their group in the dialog.
