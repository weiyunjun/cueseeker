# Table Sandbox Step 1 — Top-bar Test Entries and Empty Test Pages

Human requirement:

- `docs/human/requirements/20260605-Feature-UI Redesign.md`

## Scope

Phase A of the table-style UI sandbox: add isolated test entry points without
touching the production Library/Search/Shiori views.

- Added `WorkbenchTestPage` (library/search/shiori) and a non-persisted
  `activeTestPage` state with `toggleTestPage` / `clearTestPage` on
  `WorkbenchLayoutState`.
- Added three top-bar test icons to the right of the search field
  (`folder.circle` / `magnifyingglass.circle` / `bookmark.circle`), styled with
  the existing `TopbarModeButtonStyle`. Each toggles its test page.
- Switched the content area: when `activeTestPage` is set, the workspace shows
  `WorkbenchTestPageView` instead of `SearchView`.
- Returning to production: selecting a normal panel mode clears the test page
  (`activateWorkbenchPanelMode` now calls `clearTestPage` first), and focusing
  the production top-bar search also clears it.
- Added `WorkbenchTestPageView` (Phase A skeleton): a centered placeholder per
  page, using native semantic colors so it follows light/dark. Library stays
  blank by design; Search/Shiori will host the AppKit table in later phases.

This is platform UI/UX only: no product semantics, no playback-chain changes,
no AppKit table yet.

## Verification

- `swift build --target CueSeekerApp` succeeded (`Build complete`).
- Interactive check (manual, to run in-app): clicking each of the three test
  icons switches the content area to the corresponding empty test page; clicking
  the active icon again, selecting Library/Shiori, or focusing the search field
  returns to the production view.

## Outcome

Matched the Phase A expectation: isolated sandbox entries reachable only via the
new icons, production views untouched, build green.
