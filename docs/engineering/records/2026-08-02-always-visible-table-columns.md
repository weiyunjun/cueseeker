# Always-Visible Table Columns

## Requirement

- `docs/human/requirements/20260802-Feature-Always Show All Table Columns.md`
- `docs/human/design/UI.md`

## Classification

- Platform UI/UX: removes user-controlled column visibility from the native
  Search, Search-hosted Context, and Shiori table surfaces.
- Product semantics, persistence, platform integration, and playback
  execution: unchanged.

## Scope

- Removed the shared View button, column visibility popover, menu model, and
  popup positioning state.
- Passed each surface's complete declared column set directly into the shared
  table shell.
- Removed Search and Shiori column visibility state and its view-remount
  restoration path.
- Made Search and Shiori Copy Table actions use their complete declared data
  columns.
- Removed the disabled Hide Column item from column header menus while
  preserving sorting.
- Preserved the low-level table's configurable column inputs because fixed
  surface-specific layouts still depend on them.
- Removed tests that exercised the deleted visibility menu and retained the
  existing fixed column-order, width, copy, table lifecycle, and interaction
  coverage.

## Verification

- `swift build`: passed.
- Focused Schema Workbench, clipboard, Shiori lifecycle, and external text
  selection run: 19 tests passed.
- Source scan confirmed that the shared View button, visibility popover,
  visibility state, and Hide Column item have no remaining production
  references.
- `swift test`: ran 952 tests and reported 26 issues in unrelated concurrent
  Library removal, native playback timing, playback presentation, Subtitle
  Focus, UI probe, and existing row-menu placement tests.
- Focused reruns passed for Library folder removal (8 tests), native playback
  timeline (5 tests), native playback presentation transitions (2 tests), the
  UI probe failure, and both Subtitle Focus failures.
- The two row action menu placement tests still fail when run alone. The same
  unchanged failures are recorded in
  `docs/engineering/records/2026-07-31-playback-cue-text-selection-and-search-input-normalization.md`;
  temporarily restoring the removed disabled header-menu item did not change
  their result.
- `git diff --check`: passed.

## Outcome

Search, Search-hosted Context, and Shiori now expose one fixed column layout
with horizontal overflow instead of user-controlled column hiding. Copy Table
uses the same complete data-column definitions, and the removed feature leaves
no compatibility state or replacement abstraction.
