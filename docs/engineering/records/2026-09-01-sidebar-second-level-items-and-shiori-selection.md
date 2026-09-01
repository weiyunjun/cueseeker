# Sidebar Second Level Items And Shiori Selection

Human-owned requirement:
`docs/human/requirements/20260901-UI-Sidebar Second Level Items And Shiori Selection.md`

Related design: `docs/human/design/UI Design System.md`
(Sidebar Item, App Sidebar Layout, Size).

## Why

The Sidebar's two collapsible groups earned their disclosure control only because
Shiori listed a variable number of lists under it. Once those list entries go
away, the Sidebar is a fixed six-item list and the chevron has nothing left to
hide, so the control, its state and its scrolling container all go with it. The
two remaining second-level items then need leading icons of their own to keep
reading as navigation rather than as stray labels.

## Implementation

The Sidebar is now a flat, fixed list: Search, Recent, Recent Videos, Recent
Shioris, Library, Shiori. The expansion state, the disclosure buttons and the two
parameters that carried them are gone from the navigation item, and the Shiori
list entries with their scroll container are gone from the Sidebar body.

Recent Videos takes `film` and Recent Shioris takes `bookmark`. The child item
grew a leading icon slot that mirrors the primary item's: same icon size, same
icon color rule, same icon-to-label gap. Indentation is unchanged in the sense
the requirement asks for — the child's existing leading inset already equalled the
primary item's label offset, so the icon now starts exactly where a primary
item's label starts and the child's label moves one step further right.

Shiori's selected test dropped its `selectedShioriListID == nil` clause, so the
primary item stays selected on a list's secondary page, the way Library already
behaves. Recent's rule is untouched.

Retired with their last users: `--size-app-sidebar-item-chevron`, and the
`sidebar.collapse` / `sidebar.expand` strings in all three localizations.

The Sidebar keeps its `loadShioriListOverviewIfNeeded` task even though it no
longer lists anything: it is still the earliest load of the overview, and the
Shiori table's move-to-list destinations read that overview without loading it
themselves. Only the now-unused `ShioriStore` observation was removed.

Files: `Workbench/ContentView.swift`,
`Shared/WorkbenchControls/WorkbenchControls.swift`,
`Resources/*/Localizable.strings`.

## Verification

- `swift build` — clean.
- `swift test` — 1125 tests, failing in the repository's existing
  environment- and timing-dependent set. Two suites in that set looked like they
  might have been disturbed by this change, so they were compared directly: with
  the change stashed and with it applied,
  `swift test --filter 'CueGroupRefreshScopeIntegrationTests|libraryFolderRemovalPublishesProgressWithoutBlockingMainActor|subtitleFocus'`
  runs 86 tests and fails the same two both times
  (`shioriTableStartsAtTopAfterPanelRemount`,
  `showCueGroupInvalidationIsScopedToMountedShiori`). The extra failures visible
  in the full run are ordering noise from running all 1125 together, not a
  regression from this change.

Debug in-app E2E against the running App, main window `1445 x 821`, scale 2, using
`click` and `capture`. No E2E command or test facility was added.

- **Sidebar contents.** Six items, no disclosure controls, both second-level items
  always present, nothing listed under Shiori, and no scrollbar in the navigation
  region.
- **Icons.** Recent Videos shows the film glyph, Recent Shioris the bookmark
  glyph.
- **Indentation, measured off the capture.** Primary icons start at 22pt and
  primary labels at 52pt; the child icon boxes start at 52pt and child labels at
  82pt. Icon-to-label gap is 12pt on both levels. The child icon's left edge and
  the primary label's left edge coincide, which is what the requirement asks for.
- **Shiori selection.** Opening a list's secondary page keeps the Sidebar's Shiori
  row filled with the accent color.
- **Recent selection.** Selecting Recent Videos fills only that row; Recent stays
  unfilled, unchanged from before.
- **Dark theme**, switched through Settings > Appearance and restored to Light
  afterwards: same six items, same icons, Shiori still selected on the secondary
  page.
