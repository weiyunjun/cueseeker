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

Search results should be grouped in three levels: Show → Episode → Hit. A
Show is the immediate parent folder of one or more matched subtitle files. An
Episode is a single subtitle file inside a Show, identified by its
contract-based alias rank. A Hit is one matched cue group inside an Episode.

Show group rules:

- Show identity is the parent folder path of its member subtitle files.
- The Show title is the last path component of that parent folder.
- The Show row renders the Show title on the first line and the total
  matching cue-group count across the Show on the second line as plain text,
  using `1 result` for a single match and `N results` otherwise.
- A single disclosure chevron on the right indicates collapsed or expanded
  state. The chevron rotates between `0°` (collapsed) and `90°` (expanded)
  over `160ms` with an ease curve when toggled.
- The full Show row is the click target that toggles expand or collapse. The
  Show row is never the selected row; selection lives on Hit rows only.
- Show grouping identity must remain based on parent folder path, not the
  Show title.
- Show ordering should be stable and based on the Show title using
  Finder-like localized standard comparison. The full parent folder path is
  the secondary stable ordering key when titles tie.

Episode header rules:

- An Episode header is the section heading for a single subtitle file inside
  an expanded Show. It is purely visual: it does not collapse, does not
  respond to hover, and does not draw a chevron.
- The header label on the left is `Episode NN`. `NN` is the subtitle file's
  one-based natural-sort rank among visible regular sibling subtitle files
  with the same final subtitle extension inside the parent folder. The rank
  is supplied by the existing contract-based alias rule
  (`SubtitleDisplayTitleResolver`).
- `NN` is zero-padded to at least two digits and expands to the sibling
  count's digit width when needed.
- Sibling ordering uses macOS Finder-like localized standard comparison, so
  numeric filename runs sort by numeric value, such as `aa2.ass` before
  `aa11.ass`. `.srt` and `.ass` files are ranked independently.
- The header right side renders the per-Episode result count as plain text,
  using `1 result` for a single match and `N results` otherwise.
- The Show name is not repeated in the Episode header.
- The Episode header does not depend on filename parsing and never falls
  back. Every member subtitle file always has a rank from the alias contract.
- Episode ordering inside a Show follows the same Finder-like rank ordering
  used to derive `NN`.

The visible Show row and Episode header should not render separate count
badges. Counts are plain text appended to the row text. The search layer
should still retain per-file totals for lazy-loading and internal consistency
checks.

Show groups should be expanded by default, but only the first 100 matching
cue-group rows should be visible after the initial search. Scrolling to the
bottom of the visible rows should reveal the next 100 cue-group rows when
more results exist.

Collapsing a Show should only affect row visibility and must not affect
search result counts, search scope, or playback identity. Expanding a
collapsed Show is an explicit lazy-loading trigger: the Show should show at
most the first 100 matching cue-group rows distributed across its Episodes,
even when those rows are outside the currently visible global result batch.

The Search view should provide a single control that collapses or expands
all Shows for the current query. Collapsing all Shows should hide all
subtitle rows while keeping Show rows visible. Expanding all Shows is an
explicit lazy-loading trigger that reveals at most one global 100-result
batch, not 100 rows per Show. This control must not change total result
counts or per-Show match totals.

The collapse or expand-all control should use English labels, currently
`Collapse All Results` and `Expand All Results`, and its label should be
based on the last global collapse or expand action rather than on manual
per-Show toggle state.

Hit row content:

- Subtitle text. Original-language and translation cue lines are rendered
  in the same row when both are present.
- Inline highlighting of query matches inside the original-language line.
- Hit rows do not render a cue start timestamp. Time order inside an
  Episode is conveyed by row order alone.

Hit row visual layering:

- Hit row hover and selected backgrounds left-align with the Episode header
  text. The row's own internal left padding then offsets the row text further
  to the right, so the cue text reads as visually nested under the Episode
  header even on a selected row.
- Selected rows use the macOS system accent color
  (`NSColor.controlAccentColor`, surfaced through `Color.accentColor` in
  SwiftUI). When the user changes their system accent color, the selected
  background reflects that color. A future settings option may expose a
  custom accent override; the first implementation does not include that.
- Selected row text is white. Hover row text uses the normal label color.
- Selected row keyword highlights use the on-selected highlight token (see
  §UI Design for token values).

For grouped subtitle results:

- Display all cue lines in the matched cue group.
- Order cue lines by their derived display order so the result approximates the
  subtitle's on-video vertical arrangement.
- Do not hide or deduplicate cue lines at result-render time unless a later
  product rule explicitly defines that behavior.
- Do not impose a fixed product-level line count cap on displayed cue lines.

Clicking a Hit row must open or update the central Playback Area and trigger
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
  disclosure chevron on the right that rotates between `0°` (collapsed) and
  `90°` (expanded) over `160ms` with an ease curve when toggled. The same
  chevron animation is shared with the right-sidebar Show row.
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
  count adapts to the user's current Library panel width.
- Indent the episode grid slightly relative to the folder row's left edge to
  express hierarchy. The indent should remain small.
- Use only three episode-button visual states: default, hover, and playing.
  The playing state highlights the currently playing video only when that
  playback was launched from Library.
- Avoid showing duplicate top-level rows for multiple subtitle files that map
  to the same playable video unless a later product rule defines a manual
  subtitle-selection workflow.
- Let the left titlebar control collapse or expand the Library panel.
- Let the Library panel be resized horizontally. Its default width should equal
  its minimum width, and the first minimum width should be `310pt`, which is
  `50pt` narrower than the previous fixed `360pt` Library width.
- Persist the user's Library width when it differs from the default.
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

Library and Timeline belong to the future Left Content Panel because they help
the user locate known content and precise timestamps.

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

- The current right-side saved-content placeholder becomes the Shiori mode.
- The Shiori mode uses a saved-content icon in the titlebar and should be named
  `Shiori` in user-facing English text.
- Shiori rows should be grouped by Show → Episode → Hit, mirroring the Search
  grouping pattern where practical.
- Shiori Show groups are expanded by default. The Show row, Episode header,
  hover background, and selected background follow the same rules as Search
  Hit rows. Episode headers in Shiori use `N shioris` or `1 shiori` for
  per-Episode counts.
- The Shiori panel summary should read `<count> shioris in <count> files`.
- The Shiori panel should expose a fixed `Collapse All` control. The control
  does not become `Expand All`; after a global collapse, users expand Show
  groups individually.
- Shiori Hit rows display saved subtitle text only. Like Search Hit rows
  they do not render the cue start timestamp. Shiori rows do not carry a
  query, so keyword highlights do not apply.
- Clicking a Shiori row should open or update playback for the saved video at
  the saved subtitle start timestamp.

Shiori actions may later appear in Search results, Timeline rows, contextual
menus, and future hover controls after those entry points are documented. Shiori
may also feed right-side Queue or Learning Session workflows.
