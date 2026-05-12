# Topbar Search Single-Page Workflow

Status: Accepted

## Background

The current native macOS workbench uses a fixed Mode Rail and a resizable Shared
Content Panel for Library, Search, and Shiori. That structure improved
invalidation boundaries and kept playback central, but Search still feels like a
side-panel task instead of the primary discovery path.

The next Search UI direction moves keyword entry into the titlebar/topbar and
lets Search results and Search-launched playback occupy the main content area.
The first implementation is intentionally functional rather than visually
polished.

## Goals

- Make Search entry always available from the topbar.
- Submit Search only when the user presses Return in the topbar Search field.
- Show Search results in the main content area after a submitted query.
- Keep grouped Search result content consistent with the existing Search result
  presentation.
- Let Search-launched playback use a dedicated playback page with video above
  command buttons.
- Preserve the video's source aspect ratio and leave room below the video for
  command buttons.
- Add Search-result navigation from playback using the complete current Search
  result order.
- Add upward playback drawers for nearby Search results and current subtitle
  context.

## Non-goals

- Do not redesign Library, Shiori, or Settings in the first Search UI pass.
- Do not add new topbar navigation buttons in the first Search UI pass, other
  than the Search field.
- Do not restart Rust shared-core migration.
- Do not change subtitle indexing, Search matching semantics, or the playback
  backend.
- Do not prioritize visual polish in the first implementation.

## User Flow

The accepted first flow is:

```text
Type a query in the topbar Search field
Press Return
Main content shows Search results
Click a result
Main content switches to Search-launched playback
Use playback buttons to reveal files, navigate results, inspect nearby results,
or inspect the current subtitle file
```

The old side Search entry should no longer be the Search entry point once this
flow is implemented. Library, Shiori, and Settings may remain in their current
surfaces until they are migrated later.

## UI/UX Impact

The topbar contains a fixed-width Search field. Editing the field changes only
the draft query. Pressing Return submits the draft as the active Search query
and opens the Search results page.

Search results keep the existing grouped result content and the global
`Collapse All` control. The Search field is not repeated below the topbar.

Selecting a Search result opens a playback page. The playback page keeps the
video at the source aspect ratio using fit behavior. At the standard window
width, horizontal whitespace is acceptable because the video must not stretch
away from its source ratio and the bottom command row needs stable space.

The first playback-page command row contains:

- `Video Folder`.
- `Subtitle Folder`.
- `Previous Result`.
- `Next Result`.
- `Results`.
- `Subtitles`.

`Previous Result` and `Next Result` navigate by the complete active Search
result order, matching the Search results page. The navigation scope is not
limited to the current video path or subtitle path. The current playback time is
used only to identify the current Search-result anchor before moving backward or
forward in the complete ordered result list.

The `Results` button has a right chevron next to the text. Opening the drawer
animates the chevron upward and displays at least the previous, current, and
next Search results in current Search order. The current row uses the same
selected-row treatment as Search results. The drawer does not include
`Collapse All`.

The `Subtitles` button has the same chevron behavior. Opening the drawer shows
the current playback subtitle file in timestamp order. It does not apply keyword
highlighting because the drawer is not a query-match view. The current playback
subtitle row uses a selected state for context.

## Data Model Impact

No schema change is required.

The app needs a product-domain navigation helper for the current Search query
that can resolve:

- The complete result count.
- The current Search-result position.
- The previous and next Search results in complete Search result order.
- A small neighborhood around the current result for the playback `Results`
  drawer.

The helper should reuse the same Search sorting semantics as the Search results
page. It must not define a separate video-local or subtitle-local ordering.

## Technical Risk

The main risk is accidentally creating two Search order definitions: one for
the result list and another for playback navigation. The implementation should
share the ordering source or expose the navigation operation from the same
product-domain Search layer.

The topbar Search field also needs a Return-submit command path. The existing
single-line Search text view currently prevents newline insertion, so the new
implementation should expose an explicit submit callback instead of relying on
text-change debounce.

## Acceptance Criteria

- The topbar Search field submits only on Return.
- Submitted Search displays results in the main content area.
- The Search results page has no duplicate Search field below the topbar.
- Existing grouped Search result presentation is preserved for the first pass.
- Clicking a Search result opens Search-launched playback.
- Playback preserves source video aspect ratio and keeps command space below.
- `Previous Result` and `Next Result` use the complete active Search result
  order.
- `Results` shows at least previous, current, and next Search results and has no
  `Collapse All`.
- `Subtitles` shows the current subtitle file with selected current context and
  no keyword highlighting.
- Library, Shiori, and Settings remain available through their current surfaces
  until later migration work changes them.

## Decision

Accepted. Implement the Search UI transition first, then migrate other
workbench functions to topbar-driven control in later documented steps.
