# Functional Requirements

Status: Draft

## 1. Media Source Management

The app must allow the user to add selected media sources for subtitle indexing.

Local folder requirements:

- The user can choose a local folder through a native macOS folder picker.
- The app stores selected folder entries.
- The user can remove a selected folder.
- Removing a folder must remove the app's derived index data for that folder,
  without deleting local subtitle or video files.
- The app can refresh indexes for all selected folders.
- The app should avoid duplicate folder entries when possible.

Remote source requirements:

- The first accepted remote source type is read-only WebDAV.
- The first provider-specific WebDAV resolver is AList.
- AList sources should use WebDAV for directory listing and subtitle reads, and
  AList API resolution for playable signed media URLs.
- Generic WebDAV sources may use direct WebDAV URLs for playback only when the
  source supports byte-range reads required for seekable media playback.
- Remote source credentials must not be stored in plain text.
- Removing a remote source must remove the app's derived index data for that
  source without modifying remote files.

## 2. Subtitle Scanning

The app must scan selected media sources for supported external subtitle files.

Requirements:

- Recursive folder scanning.
- Support `.srt` files.
- Support `.ass` files.
- Ignore unsupported subtitle and media-adjacent files.
- Avoid following symlink loops.
- Report indexing progress.
- Skip files that cannot be read.
- Preserve enough error information for debugging.
- Remote scanning must be read-only.
- Remote scanning may download subtitle files for parsing, but must not download
  matched video files during indexing.

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

The app must match subtitle files to video files in the same directory or remote
source-relative directory.

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
- Store enough source identity to distinguish local paths from remote source
  paths.
- Store start and end timestamps.
- Store searchable text content for each cue group.
- Store the ordered cue lines that belong to each cue group.
- Support incremental indexing based on file metadata.
- Remove stale entries when source subtitle files no longer exist.
- Remove derived index rows when a selected source is removed.
- Reconcile indexed content with the currently selected media sources when the app
  starts.
- If no sources are selected, previously derived index rows should be cleared or
  ignored so they cannot appear in search results.
- Remote sources should use stable source-relative identity for indexing and
  should not persist provider-issued temporary playback URLs as durable file
  identity.

## 6. Search

The app must search indexed subtitle content.

Requirements:

- Search should respond quickly for typical personal libraries.
- Empty queries should not return results.
- Search input should be draft-based: typing text alone must not execute a
  query, Return commits the draft query, and Escape restores the draft text to
  the committed query that owns the current result list.
- Search should support English text.
- Search should support CJK text at least at the level needed by the existing Flutter implementation.
- Results should be ordered predictably.
- Results should be limited to avoid rendering excessive rows.
- Search results must be scoped to the currently selected media sources.
- Stale index rows outside the currently selected sources must not appear in
  Search.
- Search should return cue groups, not individual ASS lines, so a bilingual or
  multi-layer ASS moment appears as one result.
- If a query matches any line in a cue group, the result should display the
  whole cue group.
- A cue group must not match only because query terms are split across different
  cue lines. At least one cue line must satisfy the query semantics.
- The current native search behavior should preserve the practical legacy Flutter semantics:
  single Latin-token searches use prefix matching, multi-token Latin searches use
  ordered whole-token filtering after FTS recall, CJK content is segmented for
  FTS phrase matching, and invalid FTS syntax returns no results instead of
  crashing the app.
- Search ranking, tokenization, query syntax, and CJK behavior remain expected
  iteration areas. Future search-quality changes should update this section and
  the database search tests before the implementation is treated as stable.

## 7. Search Results

Search results must show enough information for the user to choose the correct match.

Current M1 result rows display:

- Subtitle text.
- Highlighted query matches.
- Subtitle file name.

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
- Seek instead of reloading when the current video is already open. Same-media
  timeline jumps and same-video search-result jumps must not close and reopen the
  media URL.
- Keep seek controls responsive while the native backend performs seek work or
  waits for remote byte-range reads.
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
- ASS playback rendering should preserve timed source ASS events, including
  visual effects and vector drawing events. Search results should still expose
  readable dialogue or lyric text rather than raw effect commands.

The playback engine is selected in `docs/decisions/ADR-0007-native-only-playback-backend.md`.

## 9. Remote Playback

Remote playback is accepted for read-only WebDAV sources after the local native
playback loop.

Requirements:

- AList WebDAV sources must resolve playback through AList API rather than
  direct `/dav/...` media URLs when AList API resolution is available.
- AList playback resolution uses `/api/auth/login` and `/api/fs/get` to obtain a
  current signed `raw_url` and optional provider headers.
- Signed playback URLs must be resolved near playback time and must not be
  treated as durable database identity.
- The app must not download a whole remote video into a local temporary file as
  a playback fallback.
- Remote playback should use the same native playback backend and bounded
  packet read-ahead behavior as local and mounted-NAS playback.
- Remote playback errors should clearly distinguish source configuration,
  authentication, provider resolution, and media open failures when practical.
- Remote playback may use opportunistic warm sessions after result lists are
  materialized, such as search results and future favorites, to reduce cold-open
  latency for likely next selections.
- Warm-up must be bounded by distinct media files, not by result row count. A
  result list with many cue rows from the same video should warm the video once;
  a result list with many distinct videos must be limited by a small configurable
  cap.
- The initial warm-up policy should prepare only the first few prioritized
  distinct videos, run at most one remote warm-up at a time, cancel obsolete
  work when the result list changes, and use the first result for each video in
  the current ordering as that video's initial warm point.
- Warm-up must remain an acceleration path. It must not download whole remote
  videos, must not prevent normal click-to-playback if warm-up is incomplete,
  and must release inactive warm sessions after a short idle lifetime.
- The initial native implementation applies warm-up only to configured remote
  WebDAV providers, including AList, regardless of whether the host is a LAN IP
  or a public internet host. Local folders and mounted NAS paths are not remote
  warm-up candidates.
- The initial native implementation uses medium warm-up for search results:
  after a committed search completes, it warms at most three distinct remote
  videos in result order, opens each through the normal local stream proxy,
  mutes the background player, primes briefly at the first result timestamp for
  that video, then pauses the warm session for possible promotion.
- Warm-up should not load ASS rendering state in the background. Subtitle
  playback sources can be attached when a warm session is promoted to active
  playback.
- Remote playback may add a disk-backed byte-range cache below playback. The
  cache should preserve a single logical remote media URL for FFmpeg rather than
  switching between temporary clip files and remote streams.
- Remote byte-range cache entries must be bounded by keyframe-aware playback
  windows. For a search result window, the start boundary must use the nearest
  video keyframe at or before the target start time. The end boundary must use
  the nearest video keyframe at or after the target window end time. If precise
  keyframe metadata is unavailable, the cache may use a conservative fallback
  window until keyframe metadata is discovered.
- Remote byte-range cache should also store the stable remote ranges needed for
  container opening and seeking, such as header, stream metadata, and seek index
  ranges when the container requires them.
- Initial cache limits: at most 1,000 cached range-window entries, 16 GB total
  disk usage, and 64 MB per remote video. These are storage caps, not automatic
  per-search prefetch counts.
- A committed search should prefetch at most 20 remote cache windows in the
  initial testing policy. Future lazy loading and the centralized scheduler may
  refine which windows are eligible, but the search result count must not map
  directly to unbounded remote requests.
- Remote byte-range cache invalidation must use stable source identity plus
  source metadata such as size, modification time, ETag, content hash, provider
  id, and relative path when available.
- The cache must not persist provider tokens, signed raw URLs, Basic auth
  headers, provider playback headers, or whole remote video files.

## 10. Settings

The app must provide a settings surface for local app configuration.

Early settings:

- Manage indexed folders.
- Add a local subtitle folder.
- Trigger reindexing for all selected folders from the Settings toolbar.
- Remove a selected folder through a confirmation dialog.
- View indexing status.
- Choose a persisted playback decode mode from `hardware`, `software`, and
  `auto`.
- Manage remote WebDAV sources after the remote-source implementation begins.

Future settings may include playback, database, logging, and privacy options.

## 11. Favorites

Favorites are not required for M1.

When implemented, the app should support:

- Favorite a subtitle line.
- Remove a favorite.
- View favorite subtitle lines.
- Jump from a favorite to video playback.
- Preserve favorite identity across reindexing when possible.
