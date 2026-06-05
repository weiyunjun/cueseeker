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
- Switched the content area inside `SearchView.mainContent`: when
  `activeTestPage` is set it shows `WorkbenchTestPageView`, otherwise the normal
  library/search/shiori panels. This keeps the playback overlay (a sibling layer
  in `SearchView`) in the tree so playback can still render over a test page.
- Returning to production: selecting a normal panel mode clears the test page
  (`activateWorkbenchPanelMode` now calls `clearTestPage` first), and focusing
  the production top-bar search also clears it.
- Added `WorkbenchTestPageView` (Phase A skeleton) using native semantic colors
  so it follows light/dark. Library is strictly blank per the requirement;
  Search/Shiori keep an interim placeholder until the AppKit table replaces them
  in later phases.

This is platform UI/UX only: no product semantics, no playback-chain changes,
no AppKit table yet.

## Verification

- `swift build --target CueSeekerApp` succeeded (`Build complete`).
- Interactive check (manual, to run in-app): clicking each of the three test
  icons switches the content area to the corresponding empty test page; clicking
  the active icon again, selecting Library/Shiori, or focusing the search field
  returns to the production view.

## Review Follow-up (Codex)

Addressed three review findings before sign-off:

- P1: test page was replacing the whole `SearchView` at the `ContentView` level,
  which would hide the playback overlay when a test table later triggers
  playback. Moved the test-page branch into `SearchView.mainContent` and
  reverted the `ContentView` replacement (removed the now-unused layout state
  there).
- P2: production mode buttons no longer show selected while a test page is
  active (`activeTestPage == nil && panelMode == mode`), removing the ambiguous
  dual highlight.
- P3: Test Library is now strictly blank (no placeholder), matching the
  requirement; Search/Shiori keep their interim placeholders.

## Outcome

Matched the Phase A expectation: isolated sandbox entries reachable only via the
new icons, production views untouched, playback overlay path preserved, build
green.
