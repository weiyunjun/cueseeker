# Workbench page titles move into a taller topbar with Back and Forward history

Human-owned documents:

- `docs/human/requirements/20260907-UI-Workbench Topbar Title And History Navigation.md`

## Why

The Workbench had a Back button that meant "up": enabled only on a second-level page, and taking the reader to that section's first level. Every page also spent its first 50px on a large title that repeated the Sidebar label beside it. The requirement replaces both with what a browser does: the title sits in a taller topbar, and Back and Forward walk a history of the pages shown since launch, whichever section they belong to.

Two other things had grown into the same area. Recent was three pages — an overview of two sections and a full page for each — reached through two extra Sidebar items, for what is one list with a choice of two contents. And playback carried a return target of its own, one that five different actions inside playback were allowed to overwrite, which is why searching from the Command Panel and closing the player put the reader on Search regardless of where they had started.

## What changed

### Recent is one page

The overview, its two section headers with counts and arrows, and the two Sidebar children are gone. Recent shows Recent Videos and Recent Shioris as Tabs at the top of the page — the same `WorkbenchTabs` the Library page uses, flush with the content's left edge — and starts on Recent Videos. Each Tab lists everything, as the old second-level pages did; the overview's five-Shiori cut is gone with it. The chosen Tab is route state and survives a visit to other pages; it is not persisted across launches. A Tab switch is an interface switch for the pointer rule, like Library's segments, and not a history step.

Files: `TableSandbox/WorkbenchTestLibraryView.swift`, `Workbench/ContentView.swift`, `App/WorkbenchLayoutState.swift`.

### History over pages

`WorkbenchRoute` names one page: Search, Recent, Library, a Library folder by path, File, Shiori, a Shiori list by id. `WorkbenchRouteState` keeps an array of them and an index; the launch page is the first entry. `navigate(to:)` drops whatever lay beyond the index and appends, `goBack` and `goForward` move the index, and all three set the panel mode and the second-level selections from the entry, so the views keep reading the same published properties they always did. Showing the page already shown is not a step, which is what the existing "same panel does not invalidate" test pins down.

The Library detail selection was a whole folder summary; it is now the folder path, and the view looks the summary up in the store when it draws. That is what lets a history entry outlive the folder, and it also means a re-index that changes a cover or a count shows without the reconcile step that used to re-select the presentation.

`AppCoordinator` fronts this with `navigateWorkbench(to:)`, `goBackInWorkbench()` and `goForwardInWorkbench()`. The one piece of page data a view does not load itself — the Shiori list a detail table shows — is activated there after every navigation, so Back into a list detail loads that list's rows exactly as opening it does. A Sidebar item now navigates to its section's first level, and does nothing on its own section at either level; Shiori used to jump to its overview from a detail, Library already stayed put. Deleting the list being looked at, or a folder vanishing under its detail, still returns to the overview, and that return is an ordinary step.

Files: `App/WorkbenchLayoutState.swift`, `App/AppCoordinator.swift`, `App/AppCoordinator+Shiori.swift`, `App/AppCoordinator+Search.swift`, `App/AppCoordinator+URLScheme.swift`, `TableSandbox/WorkbenchTestLibraryView.swift`, `Workbench/ContentView.swift`.

### Unknown page

A history entry keeps pointing at its list or folder after the thing is deleted. `isWorkbenchRouteUnknown` answers whether that has happened — only once the store that would know has loaded, so a page never flashes as unknown while its data is on the way. The Library and Shiori surfaces draw `WorkbenchUnknownPage` for such an entry, an Empty Hint with the new `page.unknown.message` string, and the topbar shows `page.unknown.title` in its place. The entry stays in the history so Forward still works past it.

Files: `App/AppCoordinator.swift`, `Search/SearchView.swift`, `TableSandbox/WorkbenchTestLibraryView.swift`, `Resources/*/Localizable.strings`.

### Playback leaves the Workbench alone

`PlaybackReturnContext` and the initialise / commit / restore trio around it are removed, together with the five call sites that overwrote the target — Command Panel search, Command Panel Recent video, Overlay Shiori playback, the playlist Shiori path and the deep link — and the line that switched the Workbench to Search whenever a search result started playing. Nothing inside playback touches the route any more, so closing the player shows the page it was opened from, second level and Recent Tab included, with the history untouched. The old tests of the return context are rewritten to assert exactly that.

Files: `App/AppTypes.swift`, `App/AppCoordinator.swift`, `App/AppCoordinator+Playback.swift`, `App/AppCoordinator+Library.swift`, `App/AppCoordinator+Shiori.swift`, `App/AppCoordinator+PlaybackCommandPanel.swift`, `App/AppCoordinator+PlaybackSubtitleFocus.swift`, `App/AppCoordinator+URLScheme.swift`.

### Topbar

`--height-workbench-topbar` (54px) is a new token; `--height-app-topbar` (45px) stays as the band the window controls are placed in, so the Settings window and the player are unchanged. The Workbench topbar, the page's top inset and the Sidebar toggle's vertical centre use the new one. The Sidebar's top inset now follows the window-controls band rather than the topbar, so its items did not move.

The topbar's function region holds Back, Forward and the page title, spaced by the gap the toggle already had. The title is `WorkbenchPageTitle` at 24px — `--font-size-page-title` changes from 28 — with the section's Sidebar label on first-level pages, nothing on a Library folder or Shiori list, and the unknown-page title when the entry's page is gone. `WorkbenchPageTitle` left every page: the Search shell's `pageTitle`, the shared overview layout's `title`, and the File and Recent pages' own titles are removed, so each page's content starts at its top padding.

Files: `Shared/WorkbenchControls/WorkbenchControls.swift`, `Workbench/AppTopbarLayout.swift`, `Workbench/ContentView.swift`, `Shared/WorkbenchSchemaSearch/SchemaWorkbenchSearchShell.swift`, `TableSandbox/WorkbenchTestSearchView.swift`, `Shared/LibraryOverviewComponents.swift`, `Shiori/ShioriListOverviewView.swift`, `Library/WorkbenchFileView.swift`, `TableSandbox/WorkbenchTestLibraryView.swift`.

### Tests

`WorkbenchLayoutStateTests` cover the history: steps, Back and Forward at both ends, Forward dropped by a new navigation, same-page navigation not counting, the Recent Tab kept across pages and reset on relaunch. `PlaybackReturnContextTests` now assert that playback from each page, and a Command Panel search during it, leave the route and the history as they were. `WorkbenchRouteUnknownTests` pin when an entry counts as unknown. `WorkbenchControlMetricsTests` carry the two topbar heights and the 24px title. The URL scheme, playback overlay, cue group and Shiori presentation tests moved from the removed setters and return context to `navigate(to:)`; where they asserted that playback forced the Workbench to Search, they now assert it stays where it was.

## Verification

- `swift build` — clean after each of the four commits.
- `swift test` — 1143 tests, 28 issues, all in the set already on record: the seven native playback media and presentation tests, the two Debug E2E scene and window tests, and four `CueGroupRefreshScopeIntegrationTests`. The four were checked rather than assumed: `shioriTableStartsAtTopAfterPanelRemount` and `showCueGroupInvalidationIsScopedToMountedShiori` fail the same way at `1d1282b6` with the navigation change stashed, and `progressiveSearchProjectionRefreshesOnlyMountedTable` and `searchFacetSelectionDoesNotRefreshGlobalOrInactiveSurfaces` pass on their own, so all four are order-dependent like their neighbours. `swift test --filter "WorkbenchLayoutState|PlaybackReturnContext|URLScheme|ShioriPresentation|PlaybackLibraryOverlay|AppLocalization|WorkbenchControlMetrics|WorkbenchPageScrollbar|historyEntriesReadAsUnknown"`: all pass.
- `plutil -lint` on the three `Localizable.strings` files, and the localization key-set test: the three new keys are present in all three languages.

Debug in-app E2E, `.build/debug/CueSeeker --cueseeker-debug-e2e` against the real library, main window `1445 × 821`, using the existing `click`, `mouseMove`, `keyPress` and `capture` commands. No E2E command or facility was added. One Shiori cue and one search result were played, which updates their recent-playback timestamps; nothing was saved, moved or removed.

- **Launch.** Topbar 54px with the window controls where they were, Toggle, a disabled Back, a disabled Forward and `Search` at 24px, the search toolbar directly under the bar. Sidebar has five items starting under the window-controls band, at the same place as before.
- **Recent.** Title `Recent`, Tabs `Recent Videos` / `Recent Shioris` left-aligned at the top of the page, Recent Videos selected, Back enabled. Switching to Recent Shioris shows every recent list.
- **Library.** Title `Library`, summary row and Video / Metadata under it; a folder card opens its detail with no topbar title and Forward disabled.
- **Back ×3** from the folder detail: Library, then Recent still on Recent Shioris, then Search with Back disabled and Forward enabled. **Forward ×3** returns to the folder detail with Forward disabled.
- **Sidebar on own section.** Library clicked on the folder detail: nothing changes. Shiori clicked on a list detail: nothing changes.
- **Forward cleared.** From the folder detail, Sidebar Shiori: the Shiori overview with Forward disabled.
- **Shiori detail.** A card opens its list; Back returns to the overview and Forward to the detail with the table populated.
- **Playback.** From the Shiori detail, a row's cue played; the return button brought back the Shiori detail with Back and Forward as before. Then a cue played again, `K` opened the Command Panel, `ok` returned 49 results, Enter played the first (`BanG Dream! - 01`), and the return button again showed the Shiori detail — not Search, which is the behaviour the requirement removes.
- **Collapsed Sidebar.** Toggle, Back, Forward, title in that order after the window controls.

Not covered by the controller: the unknown page needs a list deleted or a folder removed from the real library, which this run did not do — the resolution is pinned by `WorkbenchRouteUnknownTests`, and the two views draw the shared hint. Dark and the two Chinese languages are string and token data; the language popup is outside the captured scene, as recorded before.

Outcome matched expectations.
