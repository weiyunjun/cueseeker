# Playback Requirements

Status: Draft

## 1. Playback Goal

Playback exists to support subtitle search context.

The primary playback action is:

```text
Click subtitle search result
Open or update the central Playback Area
Open matching local video inside the app
Seek to subtitle start timestamp
Play or pause as needed
```

The accepted Library playback action is:

```text
Click Library video row
Open or update the central Playback Area
Open selected local video inside the app
Start from Library resume history, or 0 when no Library history exists
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
- Continue playback when the Shared Content Panel is collapsed.
- Pause playback when the user leaves the CueSeeker workbench for another
  documented top-level section.
- Preserve the selected result when the Shared Content Panel is collapsed.
- Reopening the Shared Content Panel should not automatically change playback
  state.
- Handle missing files gracefully.

Accepted M2 Library playback behavior:

- Clicking a Library video row opens or updates playback from that video's
  persisted Library resume position, falling back to `0` when no history
  exists.
- If the selected Library video is already open, seeking to the resolved resume
  position is preferred over reopening when practical.
- Library playback history is persisted only for playback sessions opened
  through Library.
- Search-result playback must not read, write, or overwrite Library playback
  history. Search-result jumps remain exact subtitle-context jumps.

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

## 3. Video Matching Dependency

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

## 4. Timestamp Behavior

The app should seek to `start_ms`.

Expected behavior:

- Seek should be close enough for subtitle context review.
- Exact frame-perfect seeking is not required for M1.
- If the playback engine needs warm-up or delayed seek, the UI should still behave predictably.
- Timeline seeking must not temporarily reset the displayed playback time to `0`.
- The UI may show the requested target timestamp immediately while the backend completes the seek, then accept later backend time updates as confirmation or correction.
- Native video playback clock updates and SwiftUI playback-control updates are
  separate concerns. The native playback backend should continue playing and
  seeking at normal precision even if visible SwiftUI controls update the
  displayed time at a lower frequency to protect main-thread responsiveness.
- User-initiated seek operations must update the visible requested time
  immediately. Lower-frequency control updates must not make manual seeking
  feel delayed.

## 5. Playback Engine Selection

The playback engine is selected in `docs/decisions/ADR-0007-native-only-playback-backend.md`,
which supersedes ADR-0006 and ADR-0003.

Current decision:

- Use the project-owned native backend as the only active production playback
  path.
- Do not link, initialize, or fall back to embedded `libmpv` in the active
  native macOS app.
- Surface native opening, demuxing, hardware decode, display, audio decode,
  audio output, seek, and playback-control failures directly.

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
  view in the embedded Playback Area and playback fullscreen.
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

## 6. Subtitle Rendering

The current native-only playback implementation supports app-owned subtitle
overlay rendering for selected indexed subtitles, including `libass` rendering
for ASS files.

Future versions may need:

- Highlight current subtitle.
- Support text selection or learning interactions such as Shiori.
- Better `libass` font-resource handling for embedded attachments and adjacent
  font folders.
- Optional danmaku playback as a separate overlay domain from subtitles.

Rules:

- Playback should load the source subtitle file associated with the selected
  search result.
- For SRT-only playback, the app may display current subtitle text from the
  indexed cue data.
- ASS playback rendering uses the `libass`-backed source-faithful overlay as
  the only active renderer. The Settings surface must not expose an ASS renderer
  selector.
- ADR-0009 supersedes the previous native ASS renderer direction. Native ASS
  renderer code must not be on the active playback path.
- ASS playback rendering must use the source `.ass` file, or a cache generated
  from that exact source file identity, not the database search projection.
- Search results should expose readable dialogue or lyric text. Playback
  rendering must preserve timed source ASS events, including `Effect=fx`,
  vector drawing, clipping, karaoke, blur, alpha, transforms, and short-duration
  effects.
- Search result selection, Playback Area updates, Shared Content Panel
  visibility,
  video open, video seek, and playback controls must not wait for ASS parsing
  or rendering.
- ASS subtitle preparation should be asynchronous, cancellable, and cached by
  source file identity.
- ASS rendering failures should be surfaced explicitly. The app should not
  silently route failed ASS playback through ASS Lite or a native fallback
  renderer.
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
  and refresh the subtitle-to-video mapping before later search results are
  used for playback.

## 7. M2 Fullscreen Behavior

Playback fullscreen belongs to the playback interaction model.

Required behavior:

- Fullscreen should apply to the video playback experience, not to the entire app shell.
- Entering fullscreen should present the current video in a dedicated playback
  window that enters AppKit's native Full Screen Space.
- The main workbench window should not enter the system Full Screen Space when
  the playback fullscreen button is used.
- The fullscreen transition should follow standard macOS behavior for the Dock,
  menu bar, desktop, wallpaper, Spaces, Mission Control, app switching, and
  system overlays.
- The fullscreen window should reuse the same playback render container used by
  the embedded Playback Area.
- Entering and exiting fullscreen should use AppKit's native fullscreen
  lifecycle rather than a manually simulated borderless overlay transition.
- Entering fullscreen should immediately hide the playback operation controls and mouse cursor.
- The fullscreen playback controls and mouse cursor should hide after 3 seconds without user activity.
- Mouse or click activity in fullscreen should reveal the controls and cursor and restart the inactivity timer.
- Keyboard shortcuts in fullscreen should run playback commands without revealing the playback operation controls.
- App switching during playback fullscreen should rely on normal macOS Space
  behavior and must not leave a custom overlay window visually covering other
  apps.
- Exiting fullscreen should return the video view to the embedded Playback Area.
- Escape should exit playback fullscreen.
- Switching away from the CueSeeker workbench, closing the main window, or
  terminating the app should leave playback fullscreen cleanly.
- Switching away from the CueSeeker workbench should pause playback and must not
  leave an orphan fullscreen window.
- Fullscreen may later provide temporary access to documented workbench panel
  modes such as Library, Timeline, Search, Shiori, Queue, or Learning Session.
- Temporary fullscreen panels must preserve each mode's documented
  responsibilities and must not recreate the removed right-side panel model by
  default.
- Temporary fullscreen panels must not create a second playback render view or
  backend render context.

Implementation constraints:

- Do not create a second playback render view for fullscreen.
- Do not create a second backend render context for fullscreen.
- Do not let SwiftUI view lifetime decide when backend render state is destroyed.
- Playback fullscreen should use the singleton render container owned by the playback player.
- Playback fullscreen should move the singleton render container into a
  dedicated playback `NSWindow` and use AppKit `toggleFullScreen(_:)` on that
  playback window, not on the main CueSeeker workbench window.
- The dedicated playback fullscreen window should hide standard macOS traffic
  light buttons during fullscreen entry, active fullscreen, and fullscreen exit.
- Fullscreen enter and exit state should come from AppKit fullscreen lifecycle
  callbacks. If custom animation is later needed, it should use AppKit's custom
  fullscreen animation callbacks and the system-provided duration, not a fixed
  guessed delay.
- Do not manually simulate standard playback fullscreen with a borderless
  always-on-top overlay window.
- The embedded Playback Area's black video background should be owned by the
  native playback render container, not by a separate SwiftUI background behind
  the render view. The video frame, black background, and source-faithful ASS
  overlay should resize through the same native layout path.
- While the singleton render container is in the fullscreen playback window,
  the embedded Playback Area should not draw a fake black placeholder, subtitle
  overlay, feedback overlay, or playback controls. The embedded workbench should
  remain visually transparent or neutral until the render container returns.
- The fullscreen overlay should reuse the same playback controls and feedback
  model as the embedded Playback Area.
- Exiting fullscreen should not rebuild Library or Search result rows. Side
  panel presentation state belongs to the workbench, not to fullscreen playback
  lifecycle.

## 8. M2 Playback Controls

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
- `Q` should copy the current subtitle to the clipboard.
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
- Playback commands should show transient feedback for Shiori save or removal,
  subtitle copy, subtitle visibility, play or pause, seek direction and amount,
  volume, and playback speed.
- Continuous playback time updates used by visible SwiftUI controls should be
  rate-limited enough to avoid invalidating unrelated workbench UI. Native video
  playback and source-faithful subtitle rendering should keep their own timing
  requirements.

Current implementation notes:

- The speed preset menu remains `0.5x`, `0.75x`, `1.0x`, `1.25x`, `1.5x`, `1.75x`, and `2.0x`.
- Keyboard speed changes adjust the current speed by `0.25x` and are clamped to the same `0.5x` through `2.0x` range as the playback controls.
- Fullscreen chrome state suppresses the initial hover event emitted when the fullscreen window appears, then reveals controls and cursor only after real user activity.
- Fullscreen entry hides the playback operation controls and cursor immediately for both keyboard and button entry paths.
- Fullscreen playback shortcuts do not reveal the playback operation controls.
- The speed preset menu uses the same width as the speed button and has no separate show or hide animation.
- The playback fullscreen implementation uses AppKit fullscreen lifecycle
  instead of manual Theater Mode deactivation handling.
- Read-only selectable metadata text does not count as editable text input for playback shortcut suppression.
- Relative seek feedback accumulates repeated left or right arrow presses within the feedback timeout.
- Subtitle visibility uses the playback engine subtitle state and shows feedback when toggled.
- Current subtitle copy uses the indexed cue-group projection for clipboard text
  and preserves the same line ordering as Search result display.
- Shiori save should use the same indexed cue-group projection and current
  playback timestamp semantics as current-subtitle copy. Saving should show
  `Shiori Saved`; confirmed removal should show `Shiori Removed`.

## 9. Learning Session Playback

Learning Session playback is future work and is not required for M1 or the
current M2 playback interaction baseline.

Future Learning Session playback may support:

- Playing a selected subtitle cue with surrounding context.
- Playing a configured number of nearby subtitle cues before or after the
  target cue.
- Repeating an item multiple times.
- Randomizing queued items.
- Looping a queue or selected range.
- Playing only cue windows or broader surrounding video context.

Rules:

- Learning Session playback must build on the same playback command model used
  by normal playback controls and keyboard shortcuts.
- Learning Session playback must preserve clear escape paths back to ordinary
  playback.
- Learning Session configuration must be documented before implementation
  because it affects playback state, queue identity, keyboard behavior, and
  persistence.
- Learning Session behavior must not make ordinary Search result playback
  slower or less predictable.

## 10. Error States

Playback errors should be clear.

Examples:

- Matching video file not found.
- Video file cannot be opened.
- Timestamp seek failed.
- Playback engine initialization failed.

The app should avoid exposing raw engine logs directly in primary UI.
