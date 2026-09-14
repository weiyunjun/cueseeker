# Filter Menu becomes Filter Dialog

Human-owned documents:

- `docs/human/requirements/20260915-UI-Filter Menu Becomes Filter Dialog.md`
- `docs/human/design/UI Design System.md` (Dialog, Filter Menu, Filter Option Menu Item, Checkbox / Filter Checkbox, Menu Title, Menu Section Header, Progress Indicator, Search / Excerpt Toolbar Layout; to be updated by the owner after acceptance)
- `docs/human/design/UI Application Rules.md` (界面层级, 焦点; to be updated by the owner after acceptance)

## Why

File filters are coming and the menu has no room for them, so the filter becomes a dialog. Checking an option no longer applies it: the dialog keeps its own selection and its counts, and the table changes only when Show hands over a selection that differs from the table's.

Classified as platform UI and UX. The count rules in `CueSeekerCore` are unchanged; which counts the dialog can show for a selection it has not applied is presentation state.

## What changed

- The filter button opens the Filter dialog in the window's dialog layer instead of the menu. The dialog is x-large, titled `Filter`, with the Dialog close button; Esc and × are Cancel, Enter is Show. The button keeps its Open state while the dialog is open, and the dialog closes when its page stops responding (page switch, another Excerpt list, disappear).
- The four cards are sections with their existing icons; each option is a capsule button (title and count) laid out by the existing wrapping layout, so the options wrap to the dialog's width. Capsules take no focus. Selected: macOS accent for title, count and border, background the Library media card hover colour. Unselected hover follows Button / Neutral.
- Checking changes the dialog's selection only. Show applies it through the page's existing selection path when it differs from the table's; otherwise it only closes. Every opening starts from the table's selection.
- Counts for the dialog's selection (requirement 6):
  - Search, the selection the search runs with: the search's own counts, calculating and pending cards as before; the total once the result is exact.
  - Search, any other selection: answered from the complete rows once every count is complete, otherwise unknown. The dialog never starts a search; Show does, as a changed selection always did.
  - Excerpt: the list is in memory, so every selection is answered at once. The table's row projection (facet selection plus search text) moved into one coordinator function that the table and the dialog both call.
- An unknown count shows a still grey capsule. While any count is unknown the footer shows the Spinner and `Calculating` on the left. Show stays available; without a total its title is `Show results` / `Show excerpts`.
- The Spinner is a new component (requirement section 9) instead of the system spinner: a still ring with a quarter arc turning once per `--duration-spinner-motion`, drawn from the animation timeline so it needs no state. Only the Filter dialog uses it; the system spinners elsewhere are unchanged.
- Reset, a Button / Neutral left of Cancel, clears the dialog's selection; the table waits for Show as for any other change. It is disabled while the dialog's selection is empty. Reset keeps `--spacing-3` to Cancel, Cancel keeps `--spacing-2` to Show.
- The filter menu is gone: its surface, measuring, keyboard highlight and the Menu Gate's `filterMenu` kind. The Excerpt store's table facet distribution, read only by that menu, is removed.
- The dialog view kept the file name `CueFacetFilterPanel.swift`; a rename would remove the old path, which is left to the owner.

Values introduced, pending the design document: `--height-filter-chip` 32px, `--width-filter-chip-count-placeholder` 24px, `--height-filter-chip-count-placeholder` 12px, `--color-filter-chip-selected-content` macOS accent colour, `--color-filter-chip-selected-bg` same as `--color-library-media-card-hover-bg`; capsule radius; from the requirement, `--size-spinner` 16px, `--width-spinner-stroke` 2px, `--color-spinner-track` Light `#E5E7EB` / Dark `#3F3F46`, `--color-spinner-indicator` Light `#717171` / Dark `#878787`. Everything else references existing tokens: section gap `--spacing-4`, header to options and option gaps `--spacing-2`, section header as the former Menu Section Header, count `--font-size-caption` / `--color-text-secondary`, placeholder `--color-border-control`, Spinner motion `--duration-spinner-motion` / `--easing-spinner-motion`.

Files:

- `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchSchemaSearch/CueFacetFilterPanel.swift`
- `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchSchemaSearch/SchemaWorkbenchSearchShell.swift`
- `apps/macos-native/Sources/CueSeekerApp/TableSandbox/WorkbenchTestSearchView.swift`
- `apps/macos-native/Sources/CueSeekerApp/TableSandbox/WorkbenchExcerptTableView.swift`
- `apps/macos-native/Sources/CueSeekerApp/Workbench/ContentView.swift`
- `apps/macos-native/Sources/CueSeekerApp/App/AppCoordinator.swift`
- `apps/macos-native/Sources/CueSeekerApp/App/AppCoordinator+Excerpt.swift`
- `apps/macos-native/Sources/CueSeekerApp/App/AppDelegate.swift`
- `apps/macos-native/Sources/CueSeekerApp/Excerpt/ExcerptStore.swift`
- `apps/macos-native/Sources/CueSeekerApp/Shared/MenuGate.swift`
- `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchRedesignTokens.swift`
- `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchControls/WorkbenchControls.swift`
- `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchControls/WorkbenchSpinner.swift`
- `apps/macos-native/Sources/CueSeekerApp/Resources/{en,zh-Hans,zh-Hant}.lproj/Localizable.strings`
- `apps/macos-native/Tests/CueSeekerAppTests/SettingsStoreSearchTests.swift`
- `apps/macos-native/Tests/CueSeekerAppTests/SearchStoreTests.swift`
- `apps/macos-native/Tests/CueSeekerAppTests/MenuInputBarrierTests.swift`
- `apps/macos-native/Tests/CueSeekerAppTests/WorkbenchPageScrollbarTests.swift`
- `apps/macos-native/Tests/CueSeekerAppTests/PlaybackExcerptOverlayTests.swift`
- `apps/macos-native/Tests/CueSeekerAppTests/CueGroupRefreshScopeIntegrationTests.swift`

## Verification

- New tests: the four sections, their option counts and a toggle that reads the current selection; only the unchecked options of a pending card are unknown; the Search counts rule (own selection, waiting, answered from complete rows, empty query); Show hands over only a changed selection. The Excerpt facet test reads the counts through the shared projection.
- `swift test --filter 'SettingsStoreSearch|MenuInputBarrier|WorkbenchPageScrollbar|SearchStoreTests|ExcerptStore|filterDialog'`: 61 tests pass.
- Full `swift test`: 1232 tests, 28 issues in 14 tests, all in the environment-sensitive set the 2026-09-15 Step 9 record lists: native playback (5), Debug E2E scene and width (2), Library folder removal (2; the suite passes alone), Excerpt scroll anchor (2) and the refresh-scope counters (`searchFacetSelectionDoesNotRefreshGlobalOrInactiveSurfaces`, `progressiveSearchProjectionRefreshesOnlyMountedTable`, which pass alone; the suite alone fails only the two Excerpt scroll anchor tests). `playbackControllerRepeatsSquareBackspaceInCommandPanelRoot` failed once under load in an earlier full run and passes alone. The first full run exposed a crash in the Cue Group refresh-scope host, which builds `ContentView` without the new environment object; the host now provides it.
- App, Debug E2E controller, live library, 1445 × 821, Search with the saved selection `3–4.999s`:
  - `の` pasted and the dialog opened at once: every count a grey capsule, spinner and `Calculating`, `Show results`. Four seconds later the total was exact (`Show 28724 results`) and only Duration's unchecked options were still grey; three seconds after that every count was known and the status was gone.
  - Checking `31+`: counts changed at once and Show read `Show 1214 results` while the table kept 28724. Cancel closed it with the table unchanged; reopening showed `31+` unchecked.
  - Checking `31+` and Show: the table became 1214 results. Reopen and Esc: closed, still 1214. Reopen, uncheck `31+`, Enter: the table returned to 28724, the saved selection restored.
  - Excerpt list `列表 6`: `Show 11 excerpts`; checking Watching gave `Show 2 excerpts` with the table at 11; × closed it unchanged.
- Reset and the Spinner (after the requirement added them):
  - `swift test --filter 'SettingsStoreSearch|Locali|filterDialog|WorkbenchPageScrollbar'`: 26 tests pass.
  - Full `swift test`: 1232 tests, 31 issues in 16 tests, exactly the environment-sensitive set of the 2026-09-15 Step 9 record (native playback, Debug E2E scene and width, Library folder removal, Excerpt scroll anchor, refresh-scope counters, the shared persistence migration).
  - App, sidebar collapsed, saved selection empty: `の` pasted and the dialog opened at once showed the ring Spinner turning beside `Calculating`, with Reset disabled, `--spacing-3` to Cancel and `--spacing-2` between Cancel and Show. With the counts complete (77145 results) Reset stayed disabled; checking `31+` enabled it and Show read `Show 2766 results` while the table kept 77145. Reset unchecked everything, Show returned to `Show 77145 results` and Reset was disabled again; × closed the dialog with the table unchanged.
- Hover on the capsules is not verifiable through the controller (SwiftUI hover follows the real pointer) and is left to manual acceptance.

## Outcome

Implemented and verified as above. The owner accepted it and recorded it in both design documents (`f0ea6e13`); the placeholder's token names in the code comments were then aligned with the two tokens the design document records.
