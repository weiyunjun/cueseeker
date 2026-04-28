# Functional Requirements

Status: Draft

## 1. Local Folder Management

The app must allow the user to add local subtitle folders.

Requirements:

- The user can choose a local folder through a native macOS folder picker.
- The app stores selected folder entries.
- The user can remove a selected folder.
- The app can refresh indexes for selected folders.
- The app should avoid duplicate folder entries when possible.

## 2. Subtitle Scanning

The app must scan selected local folders for `.srt` files.

Requirements:

- Recursive folder scanning.
- Ignore non-`.srt` files.
- Avoid following symlink loops.
- Report indexing progress.
- Skip files that cannot be read.
- Preserve enough error information for debugging.

## 3. Subtitle Parsing

The app must parse standard `.srt` subtitle files.

Requirements:

- Parse subtitle sequence number when present.
- Parse start and end timecodes.
- Convert start and end timecodes to milliseconds.
- Preserve subtitle text content.
- Support multi-line subtitle entries.
- Ignore malformed blocks without stopping the entire indexing run.

## 4. Video Matching

The app must match subtitle files to local video files in the same directory.

Initial matching rule:

- Match by basename.
- Support common video extensions.
- Support simple language suffix removal, such as matching `Movie.en.srt` to `Movie.mp4`.

Initial video extensions:

- `.mp4`
- `.mkv`
- `.webm`
- `.avi`
- `.mov`

## 5. Indexing

The app must write parsed subtitle entries to a local SQLite database with FTS5 search support.

Requirements:

- Store subtitle metadata.
- Store video path.
- Store subtitle path.
- Store start and end timestamps.
- Store searchable text content.
- Support incremental indexing based on file metadata.
- Remove stale entries when source subtitle files no longer exist.

## 6. Search

The app must search indexed subtitle content.

Requirements:

- Search should respond quickly for typical personal libraries.
- Empty queries should not return results.
- Search should support English text.
- Search should support CJK text at least at the level needed by the existing Flutter implementation.
- Results should be ordered predictably.
- Results should be limited to avoid rendering excessive rows.

## 7. Search Results

Search results must show enough information for the user to choose the correct match.

Current M1 result rows display:

- Subtitle text.
- Highlighted query matches.
- Subtitle file name.

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
- Render video inside the native app window.
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
- Provide playback speed control with preset choices from `0.5x` through `2.0x`.
- Provide keyboard shortcuts for subtitle visibility, fullscreen, play or pause, relative seek, volume, and speed adjustment.
- Limit keyboard speed adjustment to the same `0.5x` through `2.0x` range as the playback controls.
- Adjust volume keyboard shortcuts in `5%` steps.
- Provide transient visual feedback for shortcut and playback-control actions.

The playback engine is selected in `docs/decisions/ADR-0006-native-first-playback-backend.md`.

## 9. Settings

The app must provide a settings surface for local app configuration.

Early settings:

- Manage indexed folders.
- Trigger reindexing.
- View indexing status.

Future settings may include playback, database, logging, and privacy options.

## 10. Favorites

Favorites are not required for M1.

When implemented, the app should support:

- Favorite a subtitle line.
- Remove a favorite.
- View favorite subtitle lines.
- Jump from a favorite to video playback.
- Preserve favorite identity across reindexing when possible.
