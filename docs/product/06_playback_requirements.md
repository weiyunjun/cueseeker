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

## 5. Playback Engine Selection

The playback engine is selected in `docs/decisions/ADR-0003-playback-engine.md`.

Current decision:

- Use embedded `libmpv` as the target playback engine for the native macOS app.
- AVFoundation may be used only for exploratory prototypes or fallback experiments unless a future ADR changes the decision.

Current M1 implementation:

- The native app uses Homebrew `libmpv` during local development.
- Playback is driven through the `libmpv` client API.
- Rendering uses the `libmpv` render API with `vo=libmpv`.
- The current render bridge is `MPVRenderView`, an `NSOpenGLView`-backed AppKit view embedded in SwiftUI.
- OpenGL deprecation warnings are expected for the current M1 bridge and are not build failures.
- The previous `wid` style embedding and external player-window approach are not acceptable as the primary M1 playback implementation.
- `loadfile` is used for new videos; selecting another result in the same video should prefer `seek`.

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
- The fullscreen window should reuse the same `MPVRenderView` and `libmpv` render context used by the Playback Inspector.
- Exiting fullscreen should return the video view to the Playback Inspector.
- Escape should exit playback fullscreen.
- Closing or hiding the Playback Inspector should leave playback fullscreen cleanly.
- Switching away from Search should pause playback and must not leave an orphan fullscreen window.

Implementation constraints:

- Do not create a second playback render view for fullscreen.
- Do not create a second `libmpv` render context for fullscreen.
- Do not let SwiftUI view lifetime decide when the `libmpv` render context is destroyed.

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
- The subtitle button should toggle subtitle visibility through the playback engine.
- Playback keyboard shortcuts should be available when a playback result is selected and the user is not typing into a text field.
- `C` should show or hide subtitles.
- `F` should enter or exit playback fullscreen.
- `Space` should play or pause.
- `Left Arrow` should seek backward by 5 seconds.
- `Right Arrow` should seek forward by 5 seconds.
- `Up Arrow` should increase volume by 10 percentage points.
- `Down Arrow` should decrease volume by 10 percentage points.
- `Shift+,` should decrease playback speed by 0.25x.
- `Shift+.` should increase playback speed by 0.25x.
- The visible playback speed menu should keep its existing preset choices.
- Playback commands should show transient feedback for subtitle visibility, play or pause, seek direction and amount, volume, and playback speed.

## 9. Error States

Playback errors should be clear.

Examples:

- Matching video file not found.
- Video file cannot be opened.
- Timestamp seek failed.
- Playback engine initialization failed.

The app should avoid exposing raw engine logs directly in primary UI.
