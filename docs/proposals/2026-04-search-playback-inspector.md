# Search Playback Inspector Workflow

Status: Accepted

## Background

The current M1 native app flow opens a dedicated playback page when the user selects a subtitle search result.

That approach gives the video more room, but it makes the primary workflow slower. SubFinderX is primarily a subtitle search and context-review tool. The user often needs to click multiple search results quickly, compare context, and move between nearby matches.

The legacy Flutter implementation kept search results visible while showing playback in an embedded right-side area. That interaction better supported result-to-result review, but it could make the video feel too small.

## Goals

- Keep Search as the primary workspace.
- Replace default playback-page navigation with an embedded right-side `Playback Inspector`.
- Allow quick result-to-result playback without leaving the search results.
- Preserve the current selected result when the `Playback Inspector` is collapsed.
- Pause playback when the inspector is hidden or when the user leaves Search.
- Make the inspector width adjustable so video space can be increased without losing the search workflow.
- Keep the first implementation focused on M1 playback needs.

## Non-goals

- Full-screen playback.
- Expanded playback mode.
- Focus Mode.
- Advanced playback chrome.
- Advanced subtitle overlays.
- Media-library browsing.
- Database schema changes.

## User Flow

The accepted M1 search playback flow is:

```text
Open Search
Search subtitle text
Review results
Click a result
Playback Inspector expands
Video opens or seeks to the result timestamp
Video auto-plays
Click another result
Playback switches video or seeks within the current video
Collapse Playback Inspector when not needed
```

The user should not need to navigate away from Search for normal result preview.

## UI/UX Impact

The Search workspace should be organized as:

```text
Sidebar
Search Results Pane
Playback Inspector
```

Terminology:

- The right-side playback and result-detail panel is named `Playback Inspector`.
- The fixed titlebar control that shows or hides it is named `Playback Inspector Toggle`.

The `Playback Inspector` contains:

- Embedded video.
- Subtitle content.
- Start timestamp.
- Video path.
- Subtitle path.

The `Playback Inspector Toggle` belongs in the titlebar at a fixed right-side position. It should behave conceptually like the existing sidebar toggle, but it controls the right-side inspector.

Selecting a search result should:

- Expand the `Playback Inspector` by default.
- Keep the user in the Search workspace.
- Start playback at the selected result's `start_ms`.
- Prefer seek over reload when the selected result belongs to the currently loaded video.

Collapsing the `Playback Inspector` should:

- Hide the inspector.
- Pause playback.
- Keep the current selected result and playback context.
- Not clear the current selection.
- Not automatically resume playback when reopened.

Switching to another top-level section, such as Settings, should pause playback without stopping it.

Initial layout guidance:

- The sidebar width remains fixed according to the existing shell behavior.
- The `Playback Inspector` width is user-resizable.
- The Search Results Pane width changes dynamically as the inspector width changes.
- The Search Results Pane must have a minimum width so results remain usable.
- If the window is too narrow to show both panes well, the layout should prioritize a usable Search Results Pane.

Provisional sizing targets:

- Search Results Pane minimum width: `480pt`.
- Playback Inspector default width: `520pt`.
- Playback Inspector minimum width: `380pt`.
- Playback Inspector maximum width: available content width minus the Search Results Pane minimum width.

## Data Model Impact

No database schema change is required.

The workflow uses existing search result data:

- Subtitle content.
- `start_ms`.
- Video path.
- Subtitle path.

The app may keep transient UI state for:

- Whether the `Playback Inspector` is visible.
- The current inspector width.
- The currently selected search result.
- Current playback state.

Persisting the inspector width or visibility is optional for M1 and does not require a database change.

## Technical Risk

Risks:

- Resizable three-pane layout must preserve search usability at smaller window sizes.
- Titlebar integration must keep the `Playback Inspector Toggle` in a fixed right-side position without conflicting with existing AppKit titlebar controls.
- Hiding the inspector must pause `libmpv` playback without tearing down playback context.
- Switching away from Search must pause playback without losing the current selected result.
- Same-video result selection must seek reliably instead of unnecessarily reloading the video.

## Acceptance Criteria

- Clicking a search result opens or updates the `Playback Inspector` instead of navigating to a dedicated playback page.
- Clicking a search result expands the inspector if it is collapsed.
- The inspector shows embedded video, subtitle content, start timestamp, video path, and subtitle path.
- Selecting a result auto-plays at or near the result `start_ms`.
- Selecting another result in the same video seeks instead of reloading when practical.
- Selecting a result in a different video loads the new video and seeks to `start_ms`.
- The `Playback Inspector Toggle` is fixed in the right side of the titlebar.
- The inspector can be collapsed and expanded.
- Collapsing the inspector pauses playback and preserves the selected result.
- Reopening the inspector does not automatically resume playback.
- Switching to Settings or another top-level section pauses playback without stopping it.
- The inspector width can be adjusted while preserving a usable minimum Search Results Pane width.

## Decision

Accepted for the M1 interaction direction.

The default result-selection behavior should become an embedded `Playback Inspector` workflow. The dedicated playback page should no longer be the default M1 search result interaction.

Expanded playback, full-screen playback, and Focus Mode remain deferred until a later UX step.
