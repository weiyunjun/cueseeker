# Filter Dialog Rounded Chips, Selection Counts And Group Actions

## Human-Owned Source

- `docs/human/requirements/20260917-UI-Filter Dialog Rounded Chips Selection Counts And Group Actions.md`
- `docs/human/design/UI Design System.md` (Filter Chip, Button, Information Badge / Task Count Badge, Search / Excerpt Toolbar Layout, Filter Dialog Layout; to be updated by the owner after acceptance)

## Implementation

- Options draw as a rounded rectangle with `--radius-control` instead of a capsule; the count placeholder is unchanged.
- The footer drops the calculating status. Reset leads, Cancel and Show trail. While the total is unknown Show reads `Calculating` with the Spinner in the button's icon slot and stays disabled; `WorkbenchPrimaryButton` gains `showsSpinner`, and `showTitle` now takes a known total only, so the `Show results` / `Show excerpts` strings without a number are removed from the three localizations.
- `CueFacetSection.selectedCount` counts the options shown as selected. The section header shows it with the existing Task Count Badge (surface `--color-bg-surface`, text in the header's secondary color, hidden at 0).
- The Filter trigger passes the table's applied selection count to the Icon Button's existing count. `CueFacetFilter.selectedOptionCount(emptyDistribution:snapshot:)` sums the groups' counts over the options the dialog lists for the same inputs, so the trigger always equals the sum of the headers for that selection. Search reads the library distribution and its complete snapshot; Excerpt reads the library distribution and the list's resident snapshot, as its dialog does.

### Group actions, added then removed

The first version (`3900285c`) also ended every section header with `Select All`, `Deselect All` and `Invert Selection` as 32-high Button / Neutral, built on a shared section helper and an optional `WorkbenchButton` height. After seeing them in-app the owner found them too heavy and dropped section 2.4 from the requirement (`b1c7af7b`). The buttons, their actions, the helper, the button height option, their strings and their two tests are removed; the sections builder is back to its earlier shape with `selectedCount` added.

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

- New test: the trigger count adds two durations, one language, one watch state and the two listed folders a selection keeps.
- `swift test` after the removal: 1238 tests, 30 issues in 16 tests, all in the environment-sensitive set of the earlier records (native playback, Debug E2E scene and width, the three Library folder removal tests, Excerpt remount and scoped invalidation, `playbackPlayerKeepsAutoPauseBoundaryAcrossUserSeeks`, `progressiveSearchProjectionRefreshesOnlyMountedTable`, `searchFacetSelectionDoesNotRefreshGlobalOrInactiveSurfaces`). Run alone, the three Library folder removal tests and the two search invalidation tests pass; `showCueGroupInvalidationIsScopedToMountedExcerpt` and `excerptTableStartsAtTopAfterPanelRemount` fail alone the same way on `b910e4a5` without this change.
- In-app, Debug E2E controller, 1445 × 821, Light, first version: the saved Search selection (Japanese, Finished, 13 folders) showed 15 on the trigger and 1, 1 and 13 in the headers, with the rounded options and Reset at the bottom left; the trigger kept 15 while the dialog's selection changed until Show, and Cancel discarded it. Opened right after pasting `の`, Show read `Calculating` beside a turning spinner and was disabled; once the search completed it read `Show 23336 results`. In the Excerpt list `我喜欢的字幕` (397 cues), four durations selected then Show put 4 on its trigger; Reset then Show removed it.
- In-app after the removal: the headers are back to the icon's height with only the name and number; selecting `<1s` showed 1 beside Duration while the trigger kept 15, and Cancel discarded it. The query was cleared, the Excerpt selection restored and the App left on Search both times.
- Not exercised in-app: Dark appearance, which takes only existing tokens, is left to the owner's acceptance.

## Outcome

Matched the requirement as revised: rounded options, `Calculating` inside a disabled Show while the total is unknown, Reset at the bottom left, and the selected numbers on the Filter trigger and every group header.
