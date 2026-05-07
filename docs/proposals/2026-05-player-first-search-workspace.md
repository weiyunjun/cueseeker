# Player-first Search Workspace

Status: Accepted

## Background

The current Search workspace places Search results on the left and playback on
the right. That layout keeps the search workflow visible, but it makes the
result-selection and review action feel spatially mismatched for a right-handed
mouse user: the user clicks in the left-side result list and then reviews video
context on the right.

The current collapse behavior also treats playback as the auxiliary surface.
That is backwards for subtitle context review. Search is functional navigation;
playback is the main review experience after a result is selected.

## Goals

- Make video playback the primary Search workspace experience.
- Place the embedded playback area on the left side of the Search workspace.
- Place Search controls and Search results in a right-side Search Panel.
- Allow the right-side Search Panel to collapse so playback can use more space.
- Preserve the leftmost app sidebar behavior for `Search` and `Settings`.
- Keep result-to-result review inside the Search workspace.
- Keep the first implementation focused on layout and interaction structure.

## Non-goals

- Redesign the leftmost app sidebar.
- Change `Search` or `Settings` navigation behavior.
- Change search ranking, query semantics, result grouping, or lazy loading.
- Change playback engine behavior.
- Add media-library browsing.
- Add database schema changes.
- Redesign Theater Mode fullscreen.

## User Flow

The accepted player-first Search flow is:

```text
Open Search from the leftmost sidebar
Use the right-side Search Panel to search subtitle text
Review grouped Search results in the right-side Search Panel
Click a result
The left-side Playback Area opens or updates
Video seeks to the result timestamp and plays
Optionally collapse the Search Panel to focus on playback
Reopen the Search Panel to continue result-to-result review
```

## UI/UX Impact

The app shell keeps the same high-level structure:

```text
Native titlebar
Leftmost sidebar navigation
Main Workspace
```

The leftmost sidebar remains outside the Search workspace swap. It continues to
provide the high-level `Search` and `Settings` navigation and keeps its existing
expand or collapse behavior.

When Search is active, the visible horizontal order should be:

```text
Leftmost sidebar navigation
Playback Area
Search Panel
```

Terminology:

- The embedded video surface in the Search workspace is named `Playback Area`.
- The right-side search controls and result list are named `Search Panel`.
- The fixed titlebar control that shows or hides the Search Panel is named
  `Search Panel Toggle`.

The `Playback Area` contains:

- Embedded video.
- Playback controls.
- A `Video Folder` button.
- A `Subtitle Folder` button.

The `Search Panel` contains:

- Search input.
- Indexing status when relevant.
- Result count.
- Collapse or expand-all result control.
- Grouped Search results.
- Empty, loading, and error states.

Selecting a search result should:

- Keep the user in the Search workspace.
- Open or update the left-side `Playback Area`.
- Start playback at the selected result's `start_ms`.
- Prefer seek over reload when the selected result belongs to the currently
  loaded video.
- Preserve the visible Search Panel when it is already expanded.

Collapsing the `Search Panel` should:

- Hide Search controls and Search results.
- Expand the available width for the `Playback Area`.
- Preserve the current query, result state, selected result, and playback
  context.
- Not pause playback.
- Not clear the current selected result.

Reopening the `Search Panel` should restore the current Search context when
practical and should not automatically change playback state.

Switching to another top-level section, such as Settings, should still pause
playback without stopping it.

Initial layout guidance:

- The leftmost sidebar width remains fixed according to the existing shell
  behavior.
- The `Playback Area` appears to the left of the `Search Panel`.
- The `Search Panel` appears on the right side of the Search workspace.
- The `Search Panel` width is user-resizable.
- The `Playback Area` width changes dynamically as the Search Panel width
  changes.
- The `Playback Area` should receive priority when the window cannot comfortably
  show both panes.
- The Search Panel must keep a usable minimum width when expanded.

Provisional sizing targets:

- Playback Area minimum width: `520pt`.
- Search Panel default width: `480pt`.
- Search Panel minimum width: `420pt`.
- Search Panel maximum width: available content width minus the Playback Area
  minimum width.

## Data Model Impact

No database schema change is required.

The workflow uses existing search result data:

- Subtitle content.
- `start_ms`.
- Video path.
- Subtitle path.

The app may keep transient or persisted UI state for:

- Whether the Search Panel is visible.
- The current Search Panel width.
- The currently selected search result.
- Current playback state.

## Technical Risk

Risks:

- The existing right-side Playback Inspector terminology and state names may
  need careful migration to avoid confusing product concepts with code history.
- The resizable two-pane Search workspace must preserve a usable Search Panel
  while giving playback enough room.
- The Search Panel collapse action must not accidentally reuse the old playback
  collapse behavior that paused video.
- Titlebar controls must keep the left sidebar toggle and the right Search Panel
  toggle distinct.
- Focus behavior must preserve native text editing while clearing Search focus
  for app-owned playback and navigation actions.

## Acceptance Criteria

- The leftmost app sidebar still owns `Search` and `Settings` navigation.
- The leftmost app sidebar expand or collapse behavior is unchanged by this
  Search workspace layout change.
- Inside the Search workspace, the Playback Area appears on the left.
- Inside the Search workspace, the Search Panel appears on the right.
- The Search Panel can be collapsed and reopened.
- Collapsing the Search Panel expands the available playback width.
- Collapsing the Search Panel does not pause playback.
- Collapsing the Search Panel does not clear the selected result.
- Reopening the Search Panel restores the current query and result context when
  practical.
- Clicking a Search result updates the left-side Playback Area without leaving
  Search.
- Switching from Search to Settings still pauses playback without stopping it.

## Decision

Accepted.

CueSeeker should move from a right-side playback inspector model to a
player-first Search workspace. Playback belongs on the left as the primary
review surface. Search belongs on the right as a functional, collapsible panel.
The existing leftmost app sidebar remains outside this layout swap and must keep
its current `Search` and `Settings` navigation role.

This proposal supersedes the layout and collapse portions of
`docs/proposals/2026-04-search-playback-inspector.md`. It does not supersede
the embedded playback, result-to-result review, pause-on-leaving-Search, or
Theater Mode fullscreen decisions.
