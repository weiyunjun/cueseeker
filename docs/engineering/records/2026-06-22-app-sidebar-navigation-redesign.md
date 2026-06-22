# App Sidebar Navigation Redesign

## Human-Owned Source

- `docs/human/requirements/20260622-Feature-App Sidebar Navigation Redesign.md`

## Scope

Implement the native macOS workbench sidebar navigation redesign covered by the
human-owned requirement.

## Classification

- Product semantics: the formal Search entry was removed; the existing Test
  Search surface is now the Search route.
- Platform UI/UX: top-level workbench routes moved from the title bar into a
  collapsible left sidebar with selected-state styling and title-only top bar.
- Platform integration: sidebar visibility and selected route are persisted in
  `UserDefaults`; Settings is opened from the sidebar bottom action.
- Playback execution: unchanged. Playback presentation hides the workbench
  sidebar and top bar instead of embedding them beside video playback.

## Changes

- Added sidebar layout tokens for background, selected background, width, item
  height, item radius, icon size, text size, and padding.
- Replaced top-bar mode buttons with an app sidebar containing Library, Shiori,
  Test Recent Watching, Test Library, Search, and Settings.
- Reused the existing title components in the title bar, including the Test
  Library folder-detail header and back button.
- Preserved fullscreen-aware sidebar toggle placement and animated sidebar
  expand/collapse behavior.
- Persisted selected sidebar route and sidebar expanded/collapsed state.
- Routed Search to the existing table-based Test Search view and removed the old
  formal Search card-result surface.
- Moved Test Recent Watching and Test Library titles out of page content and
  into the title bar.
- Added layout-state tests for default route, selected-route persistence, and
  sidebar visibility persistence.

## Verification

- `swift build` passed.
- `swift test` passed with 324 tests.
- `git diff --check` passed.
- Residual reference search for removed top-bar/test-search route symbols passed.

## Outcome

The workbench now uses the requested sidebar-first layout. Video playback hides
the non-player UI, and Search now enters through the table-based search surface.
