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
- Search should load results incrementally in pages of 50 so broad queries can
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

- The subtitle file name.
- The total number of matching cue groups in that subtitle file for the current
  query, including matches that have not yet been loaded by lazy pagination.
- A collapsed or expanded state indicator.

Subtitle-file groups should be expanded by default. Collapsing a group should
only affect result visibility and must not affect search result counts, lazy
loading state, or playback identity.

Search result rows display:

- Subtitle text.
- Highlighted query matches.

For grouped subtitle results:

- Display all cue lines in the matched cue group.
- Order cue lines by their derived display order so the result approximates the
  subtitle's on-video vertical arrangement.
- Do not hide or deduplicate cue lines at result-render time unless a later
  product rule explicitly defines that behavior.
- Do not impose a fixed product-level line count cap on displayed cue lines.

Clicking a result must open or update the Playback Inspector and trigger playback for the matching video at the subtitle start timestamp.

The Playback Inspector displays additional context:

- Subtitle content.
- Start time.
- Video path.
- Subtitle path.

## 8. Local Playback

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
- Pause playback when the Playback Inspector is collapsed.
- Pause playback when the user switches from Search to another top-level section.
- Preserve the current selected result when the Playback Inspector is collapsed.
- Do not automatically resume playback when the Playback Inspector is reopened.
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

## 9. Settings

The app must provide a settings surface for local app configuration.

Early settings:

- Manage indexed folders.
- Add a local subtitle folder.
- Trigger reindexing for all selected folders from the Settings toolbar.
- Remove a selected folder through a confirmation dialog.
- View indexing status.
- Choose a persisted playback decode mode from `hardware`, `software`, and
  `auto`.

Future settings may include playback, database, logging, and privacy options.

## 10. Favorites

Favorites are not required for M1.

When implemented, the app should support:

- Favorite a subtitle line.
- Remove a favorite.
- View favorite subtitle lines.
- Jump from a favorite to video playback.
- Preserve favorite identity across reindexing when possible.
