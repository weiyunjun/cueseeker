# Left Library Panel

Status: Accepted

## Background

CueSeeker has already accepted a player-first workspace with playback as the
center, Search on the right, and known-content navigation on the left. The next
left-side surface should be Library: a fast way to locate a known video and
start playback without using Search.

This Library is not the Settings `Library` category. Settings `Library` manages
indexed subtitle folders. The main-window Library browses playable indexed
videos.

## Goals

- Add a left-side Library panel for known video navigation.
- Keep Library visually aligned with the Search Panel's dense grouped-list
  structure while using the left-side gray background treatment.
- Use a fixed first-implementation width that is 100 pt wider than the current
  left-panel baseline. Resizing can be designed later.
- Show only one folder grouping level. Do not render nested folder trees.
- Sort folder groups with the same Finder-like natural ordering used by
  friendly Search result group titles.
- Allow each folder group to collapse or expand, with groups expanded by
  default.
- Provide a top-level `Collapse All` / `Expand All` control for all Library
  folder groups.
- Show playable video rows with friendly display names and file extensions.
- Show each video duration on the right side of its row.
- Start playback from `0` when a video row is clicked.

## Non-goals

- Implement playback history or resume position.
- Implement Library panel resizing.
- Implement nested folder browsing.
- Implement manual subtitle-track selection for videos with multiple subtitle
  files.
- Implement queue, Shiori, or contextual actions from Library rows.
- Change Search Panel layout or Search result behavior.
- Change the standalone Settings window.

## Layout

The first Library implementation should appear as a Left Content Panel between
the leftmost AppShell sidebar and the central Playback Area.

Conceptual order when Library is visible:

```text
Leftmost AppShell sidebar
Library Panel
Playback Area
Right Learning Panel / Search Panel
```

The leftmost AppShell sidebar keeps its existing app-navigation role. Library is
a content panel, not a new replacement for the AppShell sidebar.

The Library Panel should:

- Keep a gray background.
- Use compact list spacing comparable to Search results.
- Use a fixed width for this version.
- Start 100 pt wider than the current left-panel baseline.
- Avoid cards or nested card surfaces.

## Grouping And Sorting

Library content is flattened to one folder level.

Rules:

- Each folder group represents the immediate parent folder of one or more
  playable indexed videos.
- Folder groups are sorted by folder display name using Finder-like localized
  natural comparison. This behaves like alphabetic `a-z` ordering for ordinary
  text while sorting numeric filename runs naturally, such as `2` before `11`.
- Folder groups are expanded by default.
- Each folder group can be collapsed or expanded independently.
- The top action toggles all groups.
- Show `Collapse All` when at least one group is expanded.
- Show `Expand All` when all groups are collapsed.
- Collapsing a folder group hides only its video rows. It must not change
  Library identity, playback state, or indexed data.

## Video Rows

Video rows represent playable indexed videos.

Display name rules:

- A video row uses the immediate parent folder name plus the video's one-based
  Finder-like natural-sort rank among playable video siblings in that folder.
- The rank is zero-padded to at least two digits.
- The row appends the video's final file extension as plain text without the
  leading dot.
- The display format is:

```text
Parent Folder Name - NN  extension
```

Example:

```text
葬送的芙莉莲 - 01  mkv
```

The raw video path remains the stable identity and should remain available for
diagnostics and future Finder actions.

Video rows inside a folder group are sorted with the same Finder-like natural
comparison used to derive the rank.

Each row should display the indexed video duration on the right. If duration is
temporarily unavailable before reindexing or metadata extraction completes, the
UI may show a neutral placeholder, but the accepted steady state is to show the
duration after reindexing.

## Selection And Playback

Clicking a video row should:

- Keep the user in the main workspace.
- Open or update the central Playback Area.
- Start playback from `0` for this version.
- Prefer seek to `0` over reopening when the selected video is already loaded,
  if that is practical.
- Not require the user to keep attending to the Library after playback starts.

Future resume or history behavior must be documented before replacing the
start-from-zero rule.

## Data And Reindexing

Library depends on indexed playable video metadata. Reindexing should populate
or refresh the video rows and duration values.

The first implementation can rely on existing indexed video identity and video
metadata fields. If duration is missing for older indexed data, reindexing is
the expected refresh path.

## Acceptance Criteria

- Documentation states that Library is a left-side content panel, not the
  leftmost AppShell sidebar or Settings `Library`.
- Documentation states that the first Library width is fixed and 100 pt wider
  than the current left-panel baseline.
- Documentation states that Library uses one-level folder grouping.
- Documentation states that folders and videos use Finder-like natural sorting.
- Documentation states that folder groups are expanded by default and can be
  collapsed independently.
- Documentation states that a `Collapse All` / `Expand All` control applies to
  all Library folder groups.
- Documentation states the video display format
  `Parent Folder Name - NN  extension`.
- Documentation states that video duration appears on the row's right side.
- Documentation states that clicking a video opens playback from `0` in this
  version.

## Decision

Accepted.

CueSeeker should implement Library as the first concrete Left Content Panel for
known-video navigation. It should use a flat, collapsible folder-grouped list
with Finder-like natural sorting, friendly video display names, visible
durations, and direct start-from-zero playback.
