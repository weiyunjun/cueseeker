# Playback Requirements

Status: Draft

## 1. Playback Goal

Playback exists to support subtitle search context.

The primary playback action is:

```text
Click subtitle search result
Open matching local video
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
- Pause playback.
- Seek manually.
- Handle missing files gracefully.

Out of scope for M1:

- Remote playback.
- Local HTTP proxy.
- Local cache.
- Advanced subtitle overlay.
- Real-time video effects.
- Advanced glass or blur effects.
- Media library management.

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

The final playback engine is not decided in this document.

The playback engine decision must be recorded in an ADR before production implementation.

The ADR must compare:

- AVFoundation.
- Embedded `libmpv`.
- Any other serious candidate.

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

## 7. Error States

Playback errors should be clear.

Examples:

- Matching video file not found.
- Video file cannot be opened.
- Timestamp seek failed.
- Playback engine initialization failed.

The app should avoid exposing raw engine logs directly in primary UI.

