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

Clicking a result must trigger playback for the matching video at the subtitle start timestamp.

The playback page displays additional context:

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
- Prefer seek over reload when the current video is already open.
- Stop playback when returning from the playback page.
- Allow returning from playback to search.

The playback engine is selected in `docs/decisions/ADR-0003-playback-engine.md`.

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
