# WebDAV and AList Remote Media Source

Status: Accepted for first implementation

## Background

CueSeeker currently indexes and plays local path-based media. The next remote
media step is to support read-only WebDAV media sources, with AList as the first
validated provider.

The initial test environment is an AList instance exposing Baidu Netdisk content:

```text
Web UI root: http://192.168.1.173:5244/baidu
WebDAV root: http://192.168.1.173:5244/dav/baidu
```

Manual validation on 2026-05-04 showed:

- `PROPFIND /dav/baidu/` succeeds with `207 Multi-Status`.
- `HEAD /dav/baidu/...mkv` succeeds and reports the expected file size.
- Direct `GET /dav/baidu/...mkv` with `Range` returns an AList `302` redirect
  to a Baidu PCS URL, and following that redirect returns `403 Forbidden`.
- AList API login succeeds through `/api/auth/login`.
- AList `/api/fs/get` succeeds for the media path and returns a signed
  `raw_url` under `/p/baidu/...?...sign=...`.
- The signed `raw_url` supports `206 Partial Content` for both the first byte
  and the tail byte range.
- `ffprobe` can identify the signed `raw_url` as the expected Matroska file.
- `ffmpeg -ss 00:05:00 -i <raw_url> -t 1 -f null -` can seek and decode.

Therefore, AList WebDAV should be treated as two related capabilities:

- Generic WebDAV for listing files and reading subtitle content.
- AList-specific API resolution for playable signed media URLs.

## Goals

- Add read-only remote media-source support without changing CueSeeker into a
  cloud-drive client.
- Support WebDAV directory traversal, subtitle discovery, and subtitle download
  for indexing.
- Support AList as the first provider-specific resolver.
- Keep the same search-result workflow: search subtitle text, click a result,
  open the matched video at the cue timestamp.
- Preserve current playback jitter handling through native packet read-ahead and
  rebuffer behavior.
- Avoid copying or staging whole remote videos into a local temporary directory.
- Keep credentials out of SQLite, logs, URLs stored in the database, and Git.

## Non-goals

- Direct Baidu Netdisk API integration.
- A general AList replacement inside CueSeeker.
- WebDAV write support.
- Upload, delete, rename, move, copy, or sync.
- Whole-video offline cache.
- Background download management.
- Public cloud-drive account onboarding.
- Mobile support.

## Provider Model

Remote media sources should be modeled as selected sources, not as local folders.

Initial provider modes:

- `genericWebDAV`
- `alist`

Generic WebDAV behavior:

- Use WebDAV `PROPFIND` for directory traversal.
- Use WebDAV `GET` for subtitle files.
- Use direct HTTP/WebDAV media URLs for playback only when Range behavior is
  verified for the source.

AList behavior:

- Use WebDAV for directory traversal and subtitle file reads.
- Use AList `/api/auth/login` to obtain an API token.
- Use AList `/api/fs/get` to resolve a WebDAV media item to `raw_url` plus
  optional response headers.
- Use the resolved `raw_url` for playback.
- Do not persist `raw_url` because it is signed and may expire.

## User Flow

Initial user flow:

1. The user adds a remote source in Settings.
2. The user chooses provider mode `AList`.
3. The user enters:
   - Display name.
   - WebDAV root URL, such as `http://192.168.1.173:5244/dav/baidu`.
   - AList username.
   - AList password.
4. CueSeeker stores credentials in Keychain.
5. CueSeeker indexes the remote source.
6. Search results show remote subtitle and video identity.
7. Clicking a result resolves the current playable URL and opens it through the
   native FFmpeg playback backend.

## Indexing Design

Remote indexing should reuse the existing cue parsing and matching model where
possible.

Rules:

- WebDAV indexing is read-only.
- Remote scanning should recursively discover `.srt` and `.ass` files.
- Matching should initially use the same same-directory basename rules as local
  indexing.
- Subtitle files may be downloaded into memory for parsing.
- Large ASS render segments should still be generated during indexing and stored
  as derived SQLite cache rows.
- Video files must not be downloaded during indexing.
- Remote file identity should include source identity and path within the
  source, not only a raw URL string.
- Incremental indexing may use WebDAV metadata such as size, modified time,
  ETag, or provider-specific identifiers when available.

## Playback Design

The active native backend remains the playback engine.

AList playback should resolve immediately before opening media:

```text
stored remote media identity
-> AList /api/fs/get path
-> raw_url + headers
-> local loopback stream proxy
-> FFmpeg avformat_open_input on localhost URL
```

Rules:

- Direct `/dav/...` AList URLs should not be treated as the primary playback
  URL for AList sources.
- Resolved signed URLs must not be stored as durable database identity.
- A signed URL should be refreshed on each new media open.
- Same-video seek should avoid a full resolve when the currently open playback
  session remains valid.
- Local proxy URLs are transport handles only. Same-video playback identity must
  remain source ID plus source-relative path, not the proxy token URL.
- If a signed URL expires during playback, the app should surface a clear error
  first; automatic mid-stream refresh may be a later iteration.
- The app must not use a fallback that downloads the entire remote video to a
  local temporary file.
- Packet read-ahead remains compressed-packet read-ahead inside the native
  playback backend.

## Credential Handling

Rules:

- WebDAV and AList passwords must be stored in macOS Keychain.
- SQLite may store non-secret source configuration, such as provider type,
  display name, root URL, and Keychain account identifier.
- Passwords, tokens, Basic Authorization headers, AList API tokens, signed
  `raw_url` values, and provider request headers must not be logged.
- AList API tokens should be kept in memory and refreshed through login when
  needed.

## Data Model Impact

The local-only path model needs a remote source layer.

Expected additions:

- A selected media source entity with type, provider, display name, root URL,
  and credential reference.
- Remote file identity fields for source ID and source-relative path.
- A way to distinguish durable file identity from transient playback URLs.

The database may still store displayable subtitle and video paths for search
result context, but implementation should not rely on those strings as the only
remote identity.

## Display and Cache Hardening

The archived SubFinderX WebDAV implementation exposed several edge cases that
the native implementation must keep separate:

- Search result rows should display a human filename, not an encoded internal
  URL. Local results may use the local subtitle filename; remote results should
  prefer the source-relative subtitle path, take the last path component, and
  percent-decode it for display.
- Inspector metadata may show full local paths or remote source-relative paths,
  but must still percent-decode display strings. Encoded WebDAV URLs are internal
  identity/debug data, not the primary user-facing label.
- Remote subtitle cache filenames must be short and stable. Do not base64 the
  whole source-relative path into a single filesystem name, because long anime
  release paths can exceed the macOS filename length limit. Use a fixed-length
  hash of source ID plus source-relative path, preserving only the subtitle file
  extension.
- Cache file identity should not be confused with durable media identity. The
  durable identity remains source ID plus source-relative path.

## SubFinderX Compatibility Lessons

SubFinderX handled WebDAV playback with several fallbacks that are useful as
compatibility guidance:

- Preserve raw path characters when building WebDAV URLs for AList. Some
  high-level URI builders re-encode non-ASCII path components and can break
  AList path resolution.
- Resolve AList media through `/api/fs/get` shortly before playback and use the
  returned `raw_url` plus optional headers.
- Prefer a locally mounted file only when the same remote path can be proven to
  exist under a selected local root. This is an optimization, not a requirement.
- Remote playback uses a local loopback stream proxy so the playback backend
  opens a localhost URL while CueSeeker forwards provider URLs, credentials,
  and streaming headers. The proxy forwards `Range`, `HEAD`, `Content-Range`,
  `Accept-Ranges`, `ETag`, and similar streaming headers, but it must not become
  a whole-video download fallback.
- Remote subtitle files may be downloaded to a local subtitle cache before
  loading them into the subtitle renderer, but the cache filename must be short
  and independent of the full remote path length.

## Technical Risks

- WebDAV servers differ in path encoding, `PROPFIND` response shape, metadata,
  and Range behavior.
- AList `/api/fs/get` is not WebDAV; it is provider-specific behavior.
- AList signed URLs may expire.
- AList may return required request headers for some providers.
- Incorrect URL encoding can break paths containing spaces, brackets, `!`, `&`,
  Chinese characters, or Japanese characters.
- Passing Authorization headers across redirects can leak credentials to a
  third-party host.
- Remote playback failures may be caused by WebDAV, AList, the backing storage
  provider, local networking, FFmpeg HTTP behavior, or CueSeeker playback code.

## Testing Plan

Manual validation targets:

- `PROPFIND` root listing returns `207 Multi-Status`.
- Remote subtitle download succeeds.
- Remote subtitle parsing and video matching find expected results.
- AList `/api/auth/login` succeeds.
- AList `/api/fs/get` returns `code = 200` and a non-empty `raw_url`.
- `raw_url` returns `206 Partial Content` for the first byte and tail byte
  ranges.
- `ffprobe` can identify the resolved `raw_url`.
- `ffmpeg` can seek into the resolved `raw_url`.
- CueSeeker can search and play at least one Demon Slayer result.
- CueSeeker can index and play at least one It's MyGO result, including large
  ASS behavior.

Automated tests should cover:

- WebDAV path-to-source-relative-path normalization.
- Percent-decoded display names for remote source-relative paths.
- Short remote subtitle cache filenames for very long source-relative paths.
- AList WebDAV root to API path conversion, such as
  `/dav/baidu/...` -> `/baidu/...`.
- AList login response parsing.
- AList `/api/fs/get` response parsing.
- Credential redaction in debug descriptions and errors.

## Acceptance Criteria

First implementation is acceptable when:

- A read-only AList WebDAV source can be configured.
- Credentials are stored in Keychain.
- Remote subtitle files can be indexed without downloading remote videos.
- Search results from the remote source are scoped to the selected source.
- Clicking a remote result resolves a fresh AList signed playback URL.
- Native playback can open the resolved URL and seek to the selected timestamp.
- The implementation does not stage whole remote videos in a local temp
  directory.
- Direct `/dav/...` playback is not used for AList sources when AList API
  resolution is available.

## Decision

Accepted for the first remote media-source implementation:

- Implement WebDAV as a read-only remote source.
- Implement AList as the first provider-specific resolver on top of WebDAV.
- Use WebDAV for listing and subtitle reads.
- Use AList `/api/fs/get` for playable URLs.
- Use the native FFmpeg playback backend for the resolved playback URL.
- Do not implement whole-video local download fallback.
