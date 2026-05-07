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
- Search should load results incrementally in pages of 100 so broad queries can
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

Search results should be grouped by subtitle file.

Each subtitle-file group should display:

- A friendly display title derived from the subtitle file's immediate parent
  folder name and its one-based natural-sort rank among same-extension sibling
  subtitle files when that title can be derived.
- The total matching cue-group count for that subtitle file as plain text
  appended after the display title, separated by two spaces, using `1 result` for a
  single match and `N results` otherwise.
- A collapsed or expanded state indicator.

Friendly subtitle-file group title rules:

- The display title format is `Parent Folder Name - NN`.
- `Parent Folder Name` is the immediate parent folder's last path component.
- `NN` is the subtitle file's one-based rank among visible regular sibling
  subtitle files with the same final subtitle extension.
- The sequence number is zero-padded to at least two digits, expanding to the
  sibling count's digit width when needed.
- Sibling ordering should use macOS Finder-like localized standard comparison,
  so numeric filename runs sort by numeric value, such as `aa2.ass` before
  `aa11.ass`.
- Rank derivation is scoped to the immediate parent directory and final subtitle
  extension. `.srt` and `.ass` files are ranked independently.
- If the friendly display title cannot be derived, the group should fall back
  to the source subtitle filename.
- Search grouping identity must remain based on subtitle path, not the friendly
  display title.

The visible group header should not render a separate per-file count badge or
additional count component. The per-file total should remain part of the header
text. The search layer should still retain per-file total counts for
lazy-loading rules, future sorting behavior, and internal consistency checks.

Subtitle-file groups should be expanded by default, but only the first 100
matching cue-group rows should be visible after the initial search. Scrolling to
the bottom of the visible rows should reveal the next 100 cue-group rows when
more results exist.

Collapsing a group should only affect row visibility and must not affect search
result counts, search scope, or playback identity. Expanding a collapsed
subtitle-file group is an explicit lazy-loading trigger: the group should show
at most the first 100 matching cue-group rows for that subtitle file, even when
those rows are outside the currently visible global result batch.

The Search view should provide a single control that collapses or expands all
subtitle-file groups for the current query. Collapsing all groups should hide
all subtitle rows while keeping headers visible. Expanding all groups is an
explicit lazy-loading trigger that reveals at most one global 100-result batch,
not 100 rows per subtitle file. This control must not change total result
counts or per-file match totals.

The collapse or expand-all control should use English labels, currently
`Collapse All Results` and `Expand All Results`, and its label should be based
on the last global collapse or expand action rather than on manual per-header
toggle state.

Search result rows display:

- Subtitle text.
- Highlighted query matches.
- The result start timestamp.

For grouped subtitle results:

- Display all cue lines in the matched cue group.
- Order cue lines by their derived display order so the result approximates the
  subtitle's on-video vertical arrangement.
- Do not hide or deduplicate cue lines at result-render time unless a later
  product rule explicitly defines that behavior.
- Do not impose a fixed product-level line count cap on displayed cue lines.

Clicking a result must open or update the central Playback Area and trigger
playback for the matching video at the subtitle start timestamp.

The Playback Area displays additional context:

- Embedded video playback.
- A `Video Folder` button that reveals the matched video file in Finder.
- A `Subtitle Folder` button that reveals the source subtitle file in Finder.

The Playback Area should not show separate read-only `Start Time`,
`Video Path`, or `Subtitle Path` metadata fields under the video. Source file
identity remains available through the Finder reveal buttons and internal search
result state.

The Search controls and Search results belong in a right-side Search Panel.
This Search Panel can collapse independently from playback. Collapsing it must
not pause playback, clear the selected result, or change search result identity.
The main window's top-level identity should be `CueSeeker`, not a `Search`
workspace label. Search is a right-side panel workflow, not a main-window
sidebar destination for the current single-workbench design.

## 8. Library And Timeline

Library and Timeline are not required for M1.

When implemented, Library should support:

- Browse playable videos from indexed folders.
- Use video identity as the primary row identity when a playable video can be
  resolved.
- Group videos by the immediate parent folder only. Library should be flat and
  should not render nested folder trees in the first implementation.
- Sort folder groups and video rows with the same Finder-like natural ordering
  used by friendly Search result group titles, so ordinary text sorts like
  `a-z` and numeric filename runs sort naturally.
- Use a flattened collapsible presentation that reuses the Search result
  grouping pattern where practical.
- Expand folder groups by default.
- Provide a `Collapse All` / `Expand All` control for all folder groups.
- Display friendly video names while preserving raw paths for identity,
  diagnostics, and Finder actions.
- Display video names as `Parent Folder Name - NN  extension`, where `NN` is
  the video's one-based natural-sort rank among playable sibling videos in the
  same folder, zero-padded to at least two digits, and `extension` is the final
  video file extension without the leading dot.
- Display each video's indexed duration on the right side of the row.
- Avoid showing duplicate top-level rows for multiple subtitle files that map
  to the same playable video unless a later product rule defines a manual
  subtitle-selection workflow.
- Let the left titlebar control collapse or expand the Library panel.
- Let the Library panel be resized horizontally. Its default width should equal
  its minimum width, and the first minimum width should be `310pt`, which is
  `50pt` narrower than the previous fixed `360pt` Library width.
- Persist the user's Library width when it differs from the default.
- Persist Library folder collapse or expand state across launches.
- Open or update playback from a persisted Library resume position when the
  user clicks a video through Library, falling back to `0` when no history
  exists.
- Record playback history only for videos opened through Library. Opening or
  seeking playback through Search results must not read, write, or overwrite
  Library resume history.

When implemented, Timeline should support:

- Show the current video's subtitle cues in timestamp order.
- Jump playback to a selected subtitle cue.
- Keep Timeline navigation tied to the currently loaded video.
- Preserve source subtitle identity when multiple subtitle tracks or files are
  available.

Library and Timeline belong to the future Left Content Panel because they help
the user locate known content and precise timestamps.

## 9. Queue And Learning Session

Queue and Learning Session are not required for M1.

When implemented, Queue should support:

- Add items from Search results.
- Add items from Library videos.
- Add items from Timeline subtitle cues.
- Add items from Favorites.
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

Queue and Learning Session belong to the future Right Learning Panel because
they are user-authored learning workflows rather than source media structure.

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
- Continue playback when the Search Panel is collapsed.
- Pause playback when the user switches from Search to another top-level section.
- Preserve the current selected result when the Search Panel is collapsed.
- Reopening the Search Panel should not automatically change playback state.
- Provide video-level fullscreen that does not put the app shell into macOS Full Screen.
- Provide a subtitle visibility toggle.
- Provide a copy-current-subtitle command from playback controls and keyboard.
- Provide playback speed control with preset choices from `0.5x` through `2.0x`.
- Provide keyboard shortcuts for copying the current subtitle, subtitle visibility, fullscreen, play or pause, relative seek, volume, and speed adjustment.
- Limit keyboard speed adjustment to the same `0.5x` through `2.0x` range as the playback controls.
- Adjust volume keyboard shortcuts in `5%` steps.
- Provide transient visual feedback for shortcut and playback-control actions.
- ASS playback rendering should preserve timed source ASS events, including
  visual effects and vector drawing events. Search results should still expose
  readable dialogue or lyric text rather than raw effect commands.

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
  main workspace away from the CueSeeker workbench, collapse either side panel,
  or clear the selected Search result.

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

## 12. Favorites

Favorites are not required for M1.

When implemented, the app should support:

- Favorite a subtitle line.
- Favorite a video or broader saved item only after that favorite type is
  documented.
- Remove a favorite.
- View favorite subtitle lines.
- Jump from a favorite to video playback.
- Preserve favorite identity across reindexing when possible.

Favoriting is an action that may appear in Search results, Timeline rows,
playback subtitle controls, contextual menus, and future hover controls.
Browsing and managing Favorites belongs primarily to the Left Content Panel
because Favorites are durable saved content. Favorites may also feed right-side
Queue or Learning Session workflows.
