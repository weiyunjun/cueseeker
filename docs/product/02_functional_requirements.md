# Functional Requirements

Status: Draft

## 1. Local Folder Management

The app must allow the user to add local subtitle folders.

Requirements:

- The user can choose a local folder through a native macOS folder picker.
- The app stores selected folder entries.
- The user can remove a selected folder.
- Removing a folder must remove the app's derived index data for that folder,
  without deleting local subtitle or video files.
- The app can refresh indexes for all selected folders.
- The app should avoid duplicate folder entries when possible.

## 2. Subtitle Scanning

The app must scan selected local folders for supported external subtitle files.

Requirements:

- Recursive folder scanning.
- Support `.srt` files.
- Support `.ass` files.
- Ignore unsupported subtitle and media-adjacent files.
- Avoid following symlink loops.
- Report indexing progress.
- Skip files that cannot be read.
- Preserve enough error information for debugging.

## 3. Subtitle Parsing

The app must parse supported external subtitle files into a normalized searchable
cue model.

Requirements:

- Parse start and end timecodes.
- Convert start and end timecodes to milliseconds.
- Preserve clean, searchable subtitle text content.
- Support multi-line subtitle text.
- Ignore malformed blocks or events without stopping the entire indexing run.
- Preserve enough source identity to map each searchable cue back to the source
  subtitle file and matched video file.

SRT parsing requirements:

- Parse subtitle sequence number when present.
- Treat each valid SRT block as one cue group with one cue line.

ASS parsing requirements:

- Parse `[Events]` `Dialogue` events according to the active `[Events]`
  `Format:` field mapping.
- Do not parse `Comment` events as searchable subtitles.
- Treat every `Dialogue` style as searchable unless a later product rule
  explicitly excludes it.
- Clean ASS text for search by removing override tags such as `{...}` and by
  normalizing ASS line breaks such as `\N`.
- Preserve each `Dialogue` event's start and end time after conversion to
  milliseconds.
- Group `Dialogue` events with the same subtitle file, exact start time, and
  exact end time into one cue group.
- Do not group near-equal ASS timestamps by tolerance in the first
  implementation.
- Keep all lines inside a cue group. Do not deduplicate same-looking text during
  indexing.
- Derive a stable display order for cue lines from ASS layout information when
  possible, including style alignment, margins, inline alignment overrides,
  explicit positions, and source event order.

## 4. Video Matching

The app must match subtitle files to local video files in the same directory.

Initial matching rule:

- Match by basename.
- Support common video extensions.
- Support simple language suffix removal, such as matching `Movie.en.srt` or
  `Movie.scjp.ass` to `Movie.mp4`.

Initial video extensions:

- `.mp4`
- `.mkv`
- `.webm`
- `.avi`
- `.mov`

## 5. Indexing

The app must write parsed subtitle cue groups and cue lines to a local SQLite
database with FTS5 search support.

Requirements:

- Store subtitle metadata.
- Store video path.
- Store subtitle path.
- Store start and end timestamps.
- Store searchable text content for each cue group.
- Store the ordered cue lines that belong to each cue group.
- Support incremental indexing based on file metadata.
- Remove stale entries when source subtitle files no longer exist.
- Remove derived index rows when a selected folder is removed.
- Reconcile indexed content with the currently selected folders when the app
  starts.
- If no folders are selected, previously derived index rows should be cleared or
  ignored so they cannot appear in search results.

## 6. Search

The app must search indexed subtitle content.

Requirements:

- Search should respond quickly for typical personal libraries.
- Empty queries should not return results.
- Search should support English text.
- Search should support CJK text at least at the level needed by the existing Flutter implementation.
- Results should be ordered predictably.
- Results should be limited to avoid rendering excessive rows.
- Search should load results incrementally in pages of 1000 so broad queries can
  continue revealing matches while avoiding an unbounded first render.
- The Search view should show the total matching cue-group count for the current
  query near the search field.
- Search results must be scoped to the currently selected subtitle folders.
- Stale index rows outside the currently selected folders must not appear in
  Search.
- Search should return cue groups, not individual ASS lines, so a bilingual or
  multi-layer ASS moment appears as one result.
- If a query matches any line in a cue group, the result should display the
  whole cue group.
- A cue group must not match only because query terms are split across different
  cue lines. At least one cue line must satisfy the query semantics.
- The current native search behavior should preserve the practical legacy Flutter semantics:
  single Latin-token searches use prefix matching, multi-token Latin searches use
  ordered whole-token filtering after FTS recall, Han and Japanese kana content
  is segmented for FTS phrase matching, and invalid FTS syntax returns no
  results instead of crashing the app.
- Search ranking, tokenization, query syntax, and CJK behavior remain expected
  iteration areas. Future search-quality changes should update this section and
  the database search tests before the implementation is treated as stable.

## 7. Search Results

Search results must show enough information for the user to choose the correct match.

Search results should be grouped by subtitle file. Each subtitle-file group
is a single flat container of matched cue-group rows; Search mode does not
aggregate groups by parent folder. The previous proposal to introduce a
parent-folder Show layer above subtitle files was rejected during
implementation review (see
`docs/proposals/2026-05-right-sidebar-show-episode-grouping.md`): the parent
folder is redundant header chrome in a search context, and aggregating a
season's worth of matches under one heading creates render and attention
problems that the existing flat layout already handles via the global
`Collapse All` control.

Each subtitle-file group should display:

- A friendly display title derived from the subtitle file's immediate parent
  folder name and its one-based natural-sort rank among same-extension sibling
  subtitle files when that title can be derived.
- The total matching cue-group count for that subtitle file as plain text
  appended after the display title, separated by two spaces, using
  `1 result` for a single match and `N results` otherwise.
- A collapsed or expanded state indicator on the left side of the group as a
  disclosure rail. The chevron rotates between `0°` (collapsed) and `90°`
  (expanded) over `160ms` with an ease curve when toggled. When the group is
  expanded, a vertical rail line extends below the chevron alongside the
  group's matched rows.

Friendly subtitle-file group title rules:

- The display title format is `Parent Folder Name - NN`.
- `Parent Folder Name` is the immediate parent folder's last path component.
- `NN` is the subtitle file's one-based rank among visible regular sibling
  subtitle files with the same final subtitle extension.
- The sequence number is zero-padded to at least two digits, expanding to the
  sibling count's digit width when needed.
- Sibling ordering should use macOS Finder-like localized standard
  comparison, so numeric filename runs sort by numeric value, such as
  `aa2.ass` before `aa11.ass`.
- Rank derivation is scoped to the immediate parent directory and final
  subtitle extension. `.srt` and `.ass` files are ranked independently.
- If the friendly display title cannot be derived, the group should fall back
  to the source subtitle filename.
- Search grouping identity must remain based on subtitle path, not the
  friendly display title.

The visible group header should not render a separate per-file count badge or
additional count component. The per-file total should remain part of the
header text. The search layer should still retain per-file total counts for
lazy-loading rules, future sorting behavior, and internal consistency checks.

Subtitle-file groups should be expanded by default, but only the first 100
matching cue-group rows should be visible after the initial search. Scrolling
to the bottom of the visible rows should reveal the next 100 cue-group rows
when more results exist.

Collapsing a group should only affect row visibility and must not affect
search result counts, search scope, or playback identity. Expanding a
collapsed subtitle-file group is an explicit lazy-loading trigger: the group
should show at most the first 100 matching cue-group rows for that subtitle
file, even when those rows are outside the currently visible global result
batch.

The Search view should provide a single control that collapses or expands
all subtitle-file groups for the current query. Collapsing all groups should
hide all subtitle rows while keeping headers visible. Expanding all groups
is an explicit lazy-loading trigger that reveals at most one global
100-result batch, not 100 rows per subtitle file. This control must not
change total result counts or per-file match totals.

The collapse or expand-all control should use English labels, currently
`Collapse All Results` and `Expand All Results`, and its label should be
based on the last global collapse or expand action rather than on manual
per-header toggle state.

Result row content:

- Subtitle text as the primary content.
- Inline highlighting of query matches.
- Result rows do not render a cue start timestamp. Within a subtitle-file group
  rows are already ordered by ascending cue start time, so spatial order
  conveys time order without a dedicated column.

Result row color behavior:

- Selected Result rows use the macOS system accent color
  (`NSColor.controlAccentColor`, surfaced through `Color.accentColor` in
  SwiftUI). When the user changes their system accent color, the selected
  background reflects that color. A future settings option may expose a
  custom accent override; the first implementation does not include that.
- Selected row text is white. Unselected row text uses a slightly muted
  primary label color so rows remain readable without competing with the
  selected row.
- Selected row keyword highlights use the on-selected highlight token (see
  §UI Design for token values).

For grouped subtitle results:

- Display all cue lines in the matched cue group.
- Order cue lines by their derived display order so the result approximates the
  subtitle's on-video vertical arrangement.
- Do not hide or deduplicate cue lines at result-render time unless a later
  product rule explicitly defines that behavior.
- Do not impose a fixed product-level line count cap on displayed cue lines.

Clicking a Result row must open or update the central Playback Area and trigger
playback for the matching video at the subtitle start timestamp.

The Playback Area displays additional context:

- Embedded video playback.
- A `Video Folder` button that reveals the matched video file in Finder.
- A `Subtitle Folder` button that reveals the source subtitle file in Finder.

The Playback Area should not show separate read-only `Start Time`,
`Video Path`, or `Subtitle Path` metadata fields under the video. Source file
identity remains available through the Finder reveal buttons and internal search
result state.

The Search controls and Search results belong in Search mode inside the shared
left-side content panel. The shared content panel can collapse independently
from playback. Collapsing it must not pause playback, clear the selected
result, or change search result identity.
The main window's top-level identity should be `CueSeeker`, not a `Search`
workspace label. Search is a workbench panel mode, not a main-window sidebar
destination for the current single-workbench design.

## 8. Library And Timeline

Library and Timeline are not required for M1.

When implemented, Library should support:

- Browse playable videos from indexed folders.
- Use video identity as the primary row identity when a playable video can be
  resolved.
- Hydrate the Library list from persisted indexed video metadata before the
  first visible main-window render after app launch. Restarting the app must
  not show an empty or loading Library panel when indexed Library rows already
  exist locally.
- Group videos by the immediate parent folder only. Library should be flat and
  should not render nested folder trees in the first implementation.
- Sort folder groups and the videos inside each folder with the same Finder-like
  natural ordering used by friendly Search result group titles, so ordinary
  text sorts like `a-z` and numeric filename runs sort naturally.
- Display each folder as a two-line row: the folder display name on the first
  line and an episode-count subtitle on the second line, with a single
  disclosure chevron on the left that rotates between `0°` (collapsed) and
  `90°` (expanded) over `160ms` with an ease curve when toggled. The same
  left-side chevron position and rotation animation are shared with Search and
  Shiori group disclosure rails.
- Read `N episodes` as the folder subtitle when no Library-launched playback is
  active for any video in this folder, and read `N episodes · Playing M` when
  Library-launched playback is active for a video in this folder, where `M` is
  that video's one-based natural-sort rank among playable sibling videos in the
  same folder.
- Library folder rows must not display a leading first-letter or first-character
  avatar block.
- Treat the entire folder row as a single click target that toggles folder
  expand or collapse. The chevron is a visual indicator, not the only hit
  region.
- Render an expanded folder as a numbered button grid where each button shows
  the video's one-based natural-sort rank among playable sibling videos in the
  same folder. Per-video file names, durations, and language tags are not shown
  in the grid.
- Use minimum-button-width auto-flow columns for the episode grid so the column
  count adapts to the user's current Shared Content Panel width.
- Indent the episode grid slightly relative to the folder row's left edge to
  express hierarchy. The indent should remain small.
- Use only three episode-button visual states: default, hover, and playing.
  The playing state highlights the currently playing video only when that
  playback was launched from Library.
- Avoid showing duplicate top-level rows for multiple subtitle files that map
  to the same playable video unless a later product rule defines a manual
  subtitle-selection workflow.
- Let the selected Library icon in the fixed Mode Rail collapse or expand the
  Shared Content Panel.
- Let the Shared Content Panel be resized horizontally. Its default width should
  equal its minimum width, and the first minimum width should be `420pt`,
  matching the previous Search Panel minimum width.
- Persist the user's Shared Content Panel width when it differs from the
  default.
- Keep Library folder collapse or expand state only for the current session.
  App startup and Library data refresh should show all folder groups collapsed.
- When a user expands a folder that contains the currently Library-launched
  playing video, automatically scroll that video's episode button into view as
  part of the expand transition. Auto-scroll must not fire on already-expanded
  folders or on data refresh.
- Open or update playback from a persisted Library resume position when the
  user clicks a video through Library, falling back to `0` when no history
  exists.
- Record playback history only for videos opened through Library. Opening or
  seeking playback through Search results must not read, write, or overwrite
  Library resume history.
- Drive the Library `Playing M` folder subtitle and the corresponding episode
  button highlight only from playback sessions launched through Library.
  Playback launched through Search results, Shiori, or any other surface must
  not toggle these Library indicators.

When implemented, Timeline should support:

- Show the current video's subtitle cues in timestamp order.
- Jump playback to a selected subtitle cue.
- Keep Timeline navigation tied to the currently loaded video.
- Preserve source subtitle identity when multiple subtitle tracks or files are
  available.

Library and Timeline belong to content-navigation modes because they help the
user locate known content and precise timestamps.

## 9. Queue And Learning Session

Queue and Learning Session are not required for M1.

When implemented, Queue should support:

- Add items from Search results.
- Add items from Library videos.
- Add items from Timeline subtitle cues.
- Add items from Shiori.
- Preserve enough identity to open the correct video and timestamp later.
- Display queued items in a reviewable order.
- Remove or reorder queued items when that workflow is accepted.

Search result rows may later expose hover actions or context menus, including
an `Add to Queue` action.

When implemented, Learning Session should support configurable playback over
selected or queued items.

Future Learning Session options may include:

- Context size around the selected timestamp.
- Number of nearby subtitle cues to include.
- Repeat count.
- Random order.
- Loop behavior.
- Whether to play only cue windows or broader surrounding context.

Detailed Learning Session behavior must be documented before implementation.

Queue and Learning Session placement must be documented before implementation.
They should not be assumed to require a separate right-side panel in the current
workbench model.

## 10. Local Playback

The app must support local video playback from a search result.

Requirements:

- Open the matched local video file.
- Seek to the subtitle start timestamp.
- For ASS search results, seek to the cue group start timestamp immediately and
  prepare source ASS rendering asynchronously.
- Render video inside the native app window.
- Render source ASS subtitles through the accepted source-faithful rendering
  pipeline, with ASS Lite available only as an interim fallback.
- Keep video playback responsive when ASS parsing or rendering is slow,
  unsupported, or fails.
- Allow play and pause.
- Toggle play/pause by clicking the video surface.
- Keep clicks in the playback operation controls from falling through to video-surface play or pause.
- Prefer seek over reload when the current video is already open.
- Continue playback when the Shared Content Panel is collapsed.
- Pause playback when the user switches from Search to another top-level section.
- Preserve the current selected result when the Shared Content Panel is
  collapsed.
- Reopening the Shared Content Panel should not automatically change playback
  state.
- Provide video-level fullscreen that does not put the app shell into macOS Full Screen.
- Provide a subtitle visibility toggle.
- Provide a copy-current-subtitle command from playback controls and keyboard.
- Provide playback speed control with preset choices from `0.5x` through `2.0x`.
- Provide keyboard shortcuts for copying the current subtitle, subtitle visibility, fullscreen, play or pause, relative seek, volume, and speed adjustment.
- Limit keyboard speed adjustment to the same `0.5x` through `2.0x` range as the playback controls.
- Adjust volume keyboard shortcuts in `5%` steps.
- Provide transient visual feedback for shortcut and playback-control actions.
- Persist continuous playback preferences across app restarts. This includes
  volume, last nonzero volume used for mute restore, subtitle visibility, and
  playback speed.
- ASS playback rendering should preserve timed source ASS events, including
  visual effects and vector drawing events. Search results should still expose
  readable dialogue or lyric text rather than raw effect commands.

Persistence rule:

- Non-one-shot user preferences that affect future playback or app behavior
  must be persisted by default. One-shot commands such as copying current
  subtitle text to the clipboard are not themselves persisted, while durable
  user-authored data created by a command, such as Shiori records, must remain
  persisted.
- Muting volume should preserve the previous nonzero volume so unmuting restores
  the user's last listening level rather than jumping to a generic default.

Current subtitle copy requirements:

- Copy the cue group whose time range contains the current playback timestamp.
- If multiple cue groups contain the current timestamp, choose the shortest
  duration.
- If multiple cue groups have the same duration but different time ranges,
  choose the cue group with the later end timestamp.
- If no cue group contains the current playback timestamp, search backward to
  the nearest previous cue range and apply the same selection rules there.
- Copy all lines in the selected cue group, separated by line breaks, using the
  same line order as Search result display.

The playback engine is selected in `docs/decisions/ADR-0007-native-only-playback-backend.md`.

## 11. Settings

The app must provide a Settings surface for local app configuration.

Settings entry requirements:

- Settings opens from `CueSeeker > Settings...` in the macOS app menu.
- Settings is an independent window, not a main-window sidebar section.
- Opening, focusing, or closing Settings must not pause playback, switch the
  main workspace away from the CueSeeker workbench, collapse the Shared Content
  Panel, or clear the selected Search result.

Current Settings categories:

- `Library`.
- `Decode`.

`Library` settings requirements:

- Manage indexed subtitle folders.
- Add a local subtitle folder.
- Trigger reindexing for selected folders through an `Index Now` action.
- Remove a selected folder through a confirmation dialog.
- View indexing status.

`Decode` settings requirements:

- Choose a persisted playback decode mode from `hardware`, `software`, and
  `auto`.

Future settings may include playback, database, logging, and privacy options.

## 12. Shiori

Shiori is CueSeeker's saved-subtitle workflow.

When implemented, the app should support:

- Save the current subtitle cue as a Shiori.
- Save a video or broader saved item only after that Shiori type is
  documented.
- Remove a Shiori record.
- View saved Shiori subtitle cues.
- Jump from a Shiori row to video playback.
- Preserve Shiori identity across reindexing when possible.

Initial Shiori save behavior:

- The initial visible save action belongs in playback controls.
- The playback Shiori button should appear immediately to the left of the
  pencil-tip copy-current-subtitle button.
- The `S` playback shortcut should trigger the same command as the playback
  Shiori button.
- Shiori shortcut handling must preserve native text input behavior and must not
  intercept editable text fields or modified shortcuts such as `Command-S`.
- The save command should resolve the current subtitle cue through the indexed
  database projection, using the current playback subtitle file and current
  playback timestamp. This should follow the same cue-selection semantics as
  current-subtitle copy: prefer the active cue at the playback time, then fall
  back to the previous cue when no active cue exists.
- If no subtitle cue can be resolved, the app should show a concise feedback
  overlay rather than creating an empty Shiori record.
- If the resolved cue is not already saved, the app should persist it and show a
  playback feedback overlay with the Shiori icon and `Shiori Saved`.
- If the resolved cue is already saved, the app should ask for confirmation
  before deletion. Suggested English copy is title `Remove Shiori?`, message
  `This subtitle is already saved. Remove it from Shiori?`, confirmation
  `Remove`, and cancellation `Cancel`.
- After confirmed deletion, the app should show a playback feedback overlay with
  the Shiori icon and `Shiori Removed`.

Initial Shiori panel behavior:

- Shiori is a Shared Content Panel mode selected from the fixed Mode Rail.
- The Shiori mode uses a saved-content icon and should be named `Shiori` in
  user-facing English text.
- Shiori rows should be grouped by subtitle file, following the Search
  result grouping pattern where practical.
- Shiori groups are expanded by default. The disclosure rail, hover
  background, and selected background follow the same rules as Search
  result rows.
- The Shiori panel summary should read `<count> shioris in <count> files`.
- The Shiori panel should expose a fixed `Collapse All` control. The
  control does not become `Expand All`; after a global collapse, users
  expand groups individually.
- Shiori rows display saved subtitle text only. Like Search result rows
  they do not render the cue start timestamp. Shiori rows do not carry a
  query, so keyword highlights do not apply.
- Clicking a Shiori row should open or update playback for the saved video
  at the saved subtitle start timestamp.

Shiori actions may later appear in Search results, Timeline rows, contextual
menus, and future hover controls after those entry points are documented. Shiori
may also feed Queue or Learning Session workflows after those workflows have
documented placement.
