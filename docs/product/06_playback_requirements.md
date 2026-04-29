# Playback Requirements

Status: Draft

## 1. Playback Goal

Playback exists to support subtitle search context.

The primary playback action is:

```text
Click subtitle search result
Open or update Playback Inspector
Open matching local video inside the app
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

## 3. Video Matching Dependency

Playback depends on subtitle-to-video matching.

The initial matching rule is same-directory basename matching.
This matching rule is not the long-term media identity model. Playback backend
preference must be determined from the matched media file itself, so future fuzzy
or manual subtitle matching can change the match without changing how backend
preference is evaluated.

Example:

```text
Movie.srt -> Movie.mp4
Movie.en.srt -> Movie.mp4
```

## 4. Timestamp Behavior

The app should seek to `start_ms`.

Expected behavior:

- Seek should be close enough for subtitle context review.
- Exact frame-perfect seeking is not required for M1.
- If the playback engine needs warm-up or delayed seek, the UI should still behave predictably.
- Timeline seeking must not temporarily reset the displayed playback time to `0`.
- The UI may show the requested target timestamp immediately while the backend completes the seek, then accept later backend time updates as confirmation or correction.

## 5. Playback Engine Selection

The playback engine is selected in `docs/decisions/ADR-0006-native-first-playback-backend.md`,
which supersedes ADR-0003.

Current decision:

- Try the native backend first for supported local files.
- Keep embedded `libmpv` as a fallback backend for unsupported files, native
  backend failures, and playback actions not yet implemented by the native path.

Current implementation:

- The native backend uses FFmpeg demuxing, VideoToolbox hardware decode,
  `AVSampleBufferDisplayLayer` display, FFmpeg audio decode, `swresample`
  downmix or format conversion when needed, and `AVAudioEngine` output.
- The app uses a playback facade that owns both the native backend and `libmpv`
  fallback.
- Backend preference should be selected from video-file metadata before playback
  begins, not by doing expensive playback capability checks after a subtitle
  result is clicked.
- Scanning-time backend preselection is video-first. Subtitle matching may
  evolve from exact basename matching to fuzzy or manual matching, but backend
  preference remains a property of the media file.
- Fast backend preselection should inspect only stream presence and codec names,
  combined with the current machine's VideoToolbox hardware decode capability.
  It must not decode frames or start a player during folder scanning.
- The initial video codec candidates are H.264, HEVC, VP9, and AV1, but a codec
  should prefer the native backend only when the current machine reports
  hardware decode support for that codec.
- A media file with a currently supported video codec should prefer the native backend.
  If there is no video stream but there is a supported audio stream, the file may
  also prefer the native backend as audio-only playback support evolves.
- If the preselected native backend fails during real playback, the app should
  fall back to `libmpv` and persist the fallback result for that media file.
- The playback UI hosts a stable render container so the active backend view can
  be embedded in the Playback Inspector and moved into Theater Mode fullscreen.
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

M1 does not require custom subtitle overlay rendering.

Future versions may need:

- Display current subtitle text.
- Toggle subtitle visibility.
- Highlight current subtitle.
- Support text selection or learning interactions.

These features should be designed after the playback engine is selected.

## 7. M2 Fullscreen Behavior

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
- Playback fullscreen should use the singleton render container owned by the playback facade.
- The fullscreen overlay should reuse the same playback controls and feedback model as the Playback Inspector.

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

## 9. Error States

Playback errors should be clear.

Examples:

- Matching video file not found.
- Video file cannot be opened.
- Timestamp seek failed.
- Playback engine initialization failed.

The app should avoid exposing raw engine logs directly in primary UI.
