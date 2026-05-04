# Playback Requirements

Status: Draft

## 1. Playback Goal

Playback exists to support subtitle search context.

The primary playback action is:

```text
Click subtitle search result
Open or update Playback Inspector
Open matching local or resolved remote video inside the app
Seek to subtitle start timestamp
Play or pause as needed
```

The app is not intended to become a full media library or general-purpose media player.

## 2. M1 Playback Scope

M1 requires only local playback.

Required:

- Open a local video file.
- Seek to a specific timestamp in milliseconds.
- Start playback near the subtitle start time.
- Render playback inside the app window.
- Pause playback.
- Toggle play/pause from the video surface.
- Seek when a different subtitle result in the same video is selected.
- Pause playback when the Playback Inspector is collapsed.
- Pause playback when the user leaves Search for another top-level section.
- Preserve the selected result when the Playback Inspector is collapsed.
- Do not automatically resume playback when the Playback Inspector is reopened.
- Handle missing files gracefully.

Out of scope for M1:

- Remote playback.
- Local HTTP proxy.
- Local cache.
- Advanced subtitle overlay.
- Real-time video effects.
- Advanced glass or blur effects.
- Expanded playback mode.
- Focus Mode.
- Media library management.
- External player windows as the primary playback experience.

## 3. Remote Playback Scope

Remote playback is accepted after the local native playback path. It must extend
the existing playback model rather than introduce a second production playback
engine.

Required:

- Use the project-owned native FFmpeg backend for remote media after provider
  resolution.
- Support read-only WebDAV as the first remote source type.
- Support AList as the first provider-specific resolver on top of WebDAV.
- Use WebDAV for AList directory listing and subtitle reads.
- Resolve AList playback URLs through AList API login and `/api/fs/get`.
- Pass resolved playback URLs and provider headers to the native backend only
  near media open time.
- Require seekable byte-range behavior for remote playback.
- Reuse indexed local ASS playback cache for remote ASS results. Normal playback
  must not re-download a remote ASS file that has already been indexed and
  cached.
- Cache AList tokens and signed playback URLs in memory so repeated clicks and
  unchanged links avoid avoidable login and `/api/fs/get` latency.
- Surface clear errors when a provider can list files but cannot provide a
  playable ranged media URL.
- Display remote search results with decoded subtitle or video filenames, not
  encoded transport URLs.
- Use short local cache filenames for downloaded remote subtitle files.

Out of scope:

- Whole remote video download into a local temporary file as a playback fallback.
- Treating AList `/api/auth/login` or `/api/fs/get` as generic WebDAV behavior.
- Storing provider-signed playback URLs as durable media identity.
- Storing passwords, tokens, Basic auth headers, signed URLs, or provider
  playback headers in SQLite.
- Playback-time remote ASS downloading as the normal path for an already indexed
  source.

Notes:

- AList WebDAV `/dav/...` media URLs are not assumed to be directly playable.
  Manual validation showed an AList BaiduNetdisk `/dav/...` media URL could
  list and return size metadata but fail ranged playback after provider
  redirect with `403 Forbidden`.
- The matching `/api/fs/get` `raw_url` for the same media returned valid ranged
  responses and could be opened and seeked by FFmpeg.
- Generic WebDAV sources may use direct WebDAV media URLs only when range
  requests and FFmpeg probing succeed against that server.
- Remote playback uses a local loopback stream proxy as the compatibility layer
  for provider headers, redirects, non-ASCII paths, and byte-range forwarding.
  It must stream requests through to the provider and must not download whole
  videos before playback.
- Locally mounted WebDAV/NAS paths may be preferred only when CueSeeker can
  match the remote source-relative path to a selected local root and confirm the
  file exists.
- Signed AList `raw_url` values are transient, but valid in-memory cached links
  should be reused until expiry, authentication or range failure, or a changed
  provider result.

## 4. Video Matching Dependency

Playback depends on subtitle-to-video matching.

The initial matching rule is same-directory basename matching.
This matching rule is not the long-term media identity model. Native playback
compatibility metadata must be determined from the matched media file itself, so
future fuzzy or manual subtitle matching can change the match without changing
how native compatibility is evaluated.

Example:

```text
Movie.srt -> Movie.mp4
Movie.en.srt -> Movie.mp4
Movie.scjp.ass -> Movie.mp4
```

## 5. Timestamp Behavior

The app should seek to `start_ms`.

Expected behavior:

- Seek should be close enough for subtitle context review.
- Exact frame-perfect seeking is not required for M1.
- If the playback engine needs warm-up or delayed seek, the UI should still behave predictably.
- Timeline seeking must not temporarily reset the displayed playback time to `0`.
- The UI may show the requested target timestamp immediately while the backend completes the seek, then accept later backend time updates as confirmation or correction.

## 6. Playback Engine Selection

The playback engine is selected in `docs/decisions/ADR-0007-native-only-playback-backend.md`,
which supersedes ADR-0006 and ADR-0003.

Current decision:

- Use the project-owned native backend as the only active production playback
  path.
- Do not link, initialize, or fall back to embedded `libmpv` in the active
  native macOS app.
- Surface native opening, demuxing, hardware decode, display, audio decode,
  audio output, seek, and playback-control failures directly.
- Remote media sources must not introduce a second production playback engine.
  Provider resolution may produce a URL and request headers before
  `avformat_open_input`, but demuxing, decode, output, seeking, and controls
  remain owned by the native backend.

Current implementation:

- The native backend uses FFmpeg demuxing, a user-selectable decode mode
  (`hardware`, `software`, or `auto`), `AVSampleBufferDisplayLayer` display,
  FFmpeg audio decode, `swresample` downmix or format conversion when needed,
  and `AVAudioEngine` output.
- `hardware` requires VideoToolbox video decode.
- `software` uses FFmpeg software video decode and currently converts decoded
  frames to BGRA with `libswscale` before display.
- Software playback may internally recycle the first software decode session
  after the first target frame is displayed when needed to reduce physical
  memory pressure. This recycle must not visibly interrupt playback, must not
  reset the displayed playback time to `0`, and must not noticeably increase the
  click-to-first-frame delay.
- `auto` should prefer VideoToolbox hardware decode and may fall back to
  software video decode when hardware setup is unavailable.
- Future Metal YUV work should first target software-decoded frame
  compatibility only. It must not change the VideoToolbox hardware decode
  display path unless a separate implementation decision explicitly expands
  that scope.
- The app uses a stable playback render container that hosts the native playback
  view in the Playback Inspector and Theater Mode fullscreen.
- Native compatibility metadata should be selected from video-file metadata
  before playback begins, not by doing expensive playback capability checks after
  a subtitle result is clicked.
- Scanning-time native compatibility inspection is video-first. Subtitle matching
  may evolve from exact basename matching to fuzzy or manual matching, but
  compatibility remains a property of the media file.
- Fast native compatibility inspection should inspect only stream presence and
  codec names, combined with the current machine's VideoToolbox hardware decode
  capability. It must not decode frames or start a player during folder scanning.
- The initial video codec candidates are H.264, HEVC, VP9, and AV1, but a codec
  should be marked as a native candidate only when the current machine reports
  hardware decode support for that codec.
- A media file with a currently supported video codec should be treated as a
  native playback candidate.
  If there is no video stream but there is a supported audio stream, the file may
  also become a native playback candidate as audio-only playback support evolves.
- If a native candidate fails during real playback, the app should surface the
  native failure and may persist the failure reason for that media file.
- Selecting a result in the same video should prefer seek behavior when
  practical.
- The previous `wid` style embedding and external player-window approach are not
  acceptable as the primary playback implementation.

Evaluation criteria:

- Codec compatibility.
- Seek accuracy.
- Subtitle support.
- Hardware acceleration.
- Fullscreen behavior.
- Native macOS integration.
- Visual effect compatibility.
- App signing and distribution impact.
- Maintenance cost.

## 7. Subtitle Rendering

The current native-first playback implementation supports app-owned subtitle
overlay rendering for the selected indexed SRT file.

Future versions may need:

- Highlight current subtitle.
- Support text selection or learning interactions.
- Source-faithful ASS rendering beyond the ASS Lite fallback.
- Optional danmaku playback as a separate overlay domain from subtitles.

Rules:

- Playback should load the source subtitle file associated with the selected
  search result.
- For SRT-only playback, the app may display current subtitle text from the
  indexed cue data.
- ASS Lite is an interim text overlay and fallback. The long-term ASS playback
  direction is the accepted source-faithful ASS rendering pipeline documented in
  `docs/proposals/2026-05-source-faithful-ass-rendering-pipeline.md` and
  ADR-0009.
- The current transition keeps renderer selection available in Settings. Native
  mode is the default direction for new ASS rendering work, and the final
  product direction is native-only ASS rendering.
- ASS playback rendering must use the source `.ass` file, or a cache generated
  from that exact source file identity, not the database search projection.
- All indexed ASS files should have an app-owned local playback cache. Small ASS
  files may keep a full-source cached payload; large ASS files should use
  indexed render segments.
- Search results should expose readable dialogue or lyric text. Playback
  rendering must preserve timed source ASS events, including `Effect=fx`,
  vector drawing, clipping, karaoke, blur, alpha, transforms, and short-duration
  effects.
- Search result selection, Playback Inspector visibility, video open, video
  seek, and playback controls must not wait for ASS parsing or rendering.
- ASS subtitle preparation should be asynchronous, cancellable, and cached by
  source file identity.
- ASS playback caches must be reconciled with selected folders, remote sources,
  source-relative paths, file metadata, and cache algorithm versions so removed
  or changed sources do not leave stale playback payloads.
- The renderer may fall back to ASS Lite when the source-faithful renderer is
  unavailable, but fallback must not block video playback.
- During source-faithful renderer development, complex ASS rendering failures
  should be surfaced explicitly instead of being silently hidden by ASS Lite or
  a legacy renderer path.
- Search result previews are database-owned cue group projections. Playback
  subtitle rendering is source-file-owned.
- Native playback does not need to decode embedded subtitle streams for M1.
- The subtitle visibility control should show or hide the app-owned overlay.
- For ASS rendering, the subtitle visibility control should show or hide the
  source ASS overlay without stopping video playback.
- Long-term danmaku support, if accepted later, should use a separate track and
  renderer from subtitle rendering. Subtitle tracks should preserve source
  subtitle semantics. Danmaku tracks should prioritize high-throughput moving
  text, density control, filtering, lane assignment, speed, opacity, outline,
  and independent visibility.
- ASS files may be classified as danmaku candidates through syntax and timeline
  heuristics such as high dialogue-event density, heavy overlap, short text
  events, scrolling `\move` patterns, top or bottom fixed comment positions,
  repeated lane-like vertical coordinates, and danmaku-oriented style or effect
  names. The product may use a binary subtitle-versus-danmaku classification in
  practice, but the classifier should remain diagnosable when a file is
  ambiguous.

Grouped search result behavior:

- Clicking a grouped subtitle result should select the row, open or seek the
  matched video file, and begin asynchronous source subtitle preparation for the
  matched source subtitle file.
- The playback target is the cue group start time even when the displayed search
  preview contains several ASS lines.
- If the source subtitle file changes, reindexing should rebuild the cue groups
  refresh the subtitle-to-video mapping, and rebuild the ASS playback cache
  before later search results are used for playback.

## 8. M2 Fullscreen Behavior

Playback fullscreen belongs to the playback interaction model.

Required behavior:

- Fullscreen should apply to the video playback experience, not to the entire app shell.
- Entering fullscreen should present the current video in an independent black theater-style window.
- The main app window should not enter the system Full Screen Space when the playback fullscreen button is used.
- The Theater Mode window must remain below system overlays such as the Cmd-Tab app switcher.
- The fullscreen window should reuse the same playback render container used by the Playback Inspector.
- Entering fullscreen should immediately hide the playback operation controls and mouse cursor.
- The fullscreen playback controls and mouse cursor should hide after 3 seconds without user activity.
- Mouse or click activity in fullscreen should reveal the controls and cursor and restart the inactivity timer.
- Keyboard shortcuts in fullscreen should run playback commands without revealing the playback operation controls.
- When the app resigns active during playback fullscreen, the fullscreen window should hide so other apps are visually reachable.
- When the app becomes active again after such a suspension, playback fullscreen should be restored without recreating the playback render context.
- Exiting fullscreen should return the video view to the Playback Inspector.
- Escape should exit playback fullscreen.
- Closing or hiding the Playback Inspector should leave playback fullscreen cleanly.
- Switching away from Search should pause playback and must not leave an orphan fullscreen window.

Implementation constraints:

- Do not create a second playback render view for fullscreen.
- Do not create a second backend render context for fullscreen.
- Do not let SwiftUI view lifetime decide when backend render state is destroyed.
- Playback fullscreen should use the singleton render container owned by the playback player.
- The fullscreen overlay should reuse the same playback controls and feedback model as the Playback Inspector.

## 9. M2 Playback Controls

Playback controls should be explicit and should avoid accidental video-surface commands.

Terminology:

- `Timeline Zone`: the progress bar and its enlarged seek hit area.
- `Transport Controls Zone`: the button row below the progress bar.
- `Playback Operation Zone`: the combined `Timeline Zone` and `Transport Controls Zone`.

Required behavior:

- Clicking the video surface may toggle play or pause.
- Clicking inside the `Playback Operation Zone` must not toggle play or pause unless the targeted control is the play or pause button.
- The playback speed selector should be an app-drawn menu that opens upward from the speed button.
- The playback speed menu should match the current playback control visual style.
- The playback speed menu should appear on hover over the speed control, and the speed control should not show a separate arrow icon.
- The playback speed menu should appear and disappear without its own animation.
- The playback speed button hover area and click area should be identical.
- The playback speed button hover and click area should have the same width as the playback speed menu.
- The playback speed menu should appear only when hovering the playback speed button area.
- The playback speed menu should remain visible while the pointer is inside the rectangle spanning the menu's top edge and the speed button's bottom edge, with the menu and button sharing left and right edges.
- The subtitle button should toggle subtitle visibility through the playback engine.
- Playback keyboard shortcuts should be available when a playback result is selected, the playback interface is visible, and the user is not typing into an editable text field.
- Read-only selectable metadata text must not disable playback keyboard shortcuts.
- `C` should show or hide subtitles.
- `F` should enter or exit playback fullscreen.
- `Space` should play or pause.
- `Left Arrow` should seek backward by 5 seconds.
- `Right Arrow` should seek forward by 5 seconds.
- `Up Arrow` should increase volume by 5 percentage points.
- `Down Arrow` should decrease volume by 5 percentage points.
- `Shift+,` should decrease playback speed by 0.25x.
- `Shift+.` should increase playback speed by 0.25x.
- Playback speed changes must stay within `0.5x` through `2.0x`.
- The visible playback speed menu should offer `0.5x`, `0.75x`, `1.0x`, `1.25x`, `1.5x`, `1.75x`, and `2.0x`.
- Timeline hover and drag states must not move the playback operation controls vertically.
- Playback commands should show transient feedback for subtitle visibility, play or pause, seek direction and amount, volume, and playback speed.

Current implementation notes:

- The speed preset menu remains `0.5x`, `0.75x`, `1.0x`, `1.25x`, `1.5x`, `1.75x`, and `2.0x`.
- Keyboard speed changes adjust the current speed by `0.25x` and are clamped to the same `0.5x` through `2.0x` range as the playback controls.
- Fullscreen chrome state suppresses the initial hover event emitted when the fullscreen window appears, then reveals controls and cursor only after real user activity.
- Fullscreen entry hides the playback operation controls and cursor immediately for both keyboard and button entry paths.
- Fullscreen playback shortcuts do not reveal the playback operation controls.
- The speed preset menu uses the same width as the speed button and has no separate show or hide animation.
- App deactivation hides the Theater Mode window and restores system presentation options; app reactivation restores Theater Mode without destroying the singleton render view.
- Read-only selectable metadata text does not count as editable text input for playback shortcut suppression.
- Relative seek feedback accumulates repeated left or right arrow presses within the feedback timeout.
- Subtitle visibility uses the playback engine subtitle state and shows feedback when toggled.

## 10. Error States

Playback errors should be clear.

Examples:

- Matching video file not found.
- Video file cannot be opened.
- Remote provider can list the file but cannot resolve a playable ranged media
  URL.
- Remote media URL requires credentials or headers that are unavailable.
- Timestamp seek failed.
- Playback engine initialization failed.

The app should avoid exposing raw engine logs directly in primary UI.
