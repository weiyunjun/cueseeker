# ADR-0003: Playback Engine

Status: Accepted

## Background

Playback is central to the SubFinderX workflow:

```text
Click subtitle search result
Open matching local video
Seek to subtitle start timestamp
Play or pause as needed
```

M1 requires local playback only. Remote playback, local HTTP proxying, media library management, advanced subtitle overlays, and real-time video effects are out of scope.

The product's initial video matching requirements include common local video containers such as `.mp4`, `.mkv`, `.webm`, `.avi`, and `.mov`.

## Decision

SubFinderX will use embedded `libmpv` as the target playback engine for the native macOS app.

Playback integration rules:

- Playback must open local files directly.
- Playback must seek to `start_ms` from a selected subtitle result.
- Playback must not depend on a local HTTP proxy for M1.
- Playback must not implement advanced subtitle overlay rendering for M1.
- Playback errors must be surfaced in a form the UI can present clearly.
- Exact frame-perfect seeking is not required for M1.
- AVFoundation may be used only for exploratory prototypes or fallback experiments unless a future ADR changes this decision.

The exact native view bridge and rendering backend may be decided during implementation, but changing away from `libmpv` requires a new or superseding ADR.

## Rationale

`libmpv` better matches the expected local media library than AVFoundation because it supports a wider range of common containers and codecs, including formats that are common in subtitle-based personal libraries.

The product needs reliable local file playback across common video formats more than it needs App Store-ready packaging in M1.

Because the early rewrite is a personal macOS app and public distribution is deferred, the additional packaging and signing complexity of `libmpv` is acceptable for the M1 direction.

## Evaluation

### Codec Compatibility

`libmpv` has stronger codec and container coverage for common local video files.

AVFoundation has excellent native integration but weaker coverage for containers such as `.mkv`, `.webm`, and `.avi`.

### Timestamp Seek Accuracy

Both AVFoundation and `libmpv` can seek to a timestamp suitable for subtitle context review.

M1 does not require frame-perfect seeking.

### Subtitle Support

M1 does not require custom subtitle overlay rendering.

`libmpv` provides a stronger foundation for future subtitle and media handling if needed.

### Hardware Acceleration

Both approaches may support hardware acceleration depending on format and environment.

`libmpv` requires implementation-time verification for the chosen rendering path.

### Fullscreen Behavior

Native fullscreen polish may be simpler with AVFoundation.

`libmpv` fullscreen and embedded-view behavior must be verified in the native app shell.

### Native macOS Integration

AVFoundation is more native by default.

`libmpv` requires a native bridge, but the app can still use SwiftUI and AppKit for the surrounding macOS experience.

### Visual Effect Compatibility

Advanced visual effects are out of scope for M1.

If future visual effects require a different rendering strategy, that work requires a proposal or ADR.

### Signing and Distribution Impact

AVFoundation has lower signing and distribution complexity.

`libmpv` introduces bundled native dependency handling and may affect signing, notarization, and release packaging.

This is acceptable because early distribution is personal local use.

### Maintenance Cost

`libmpv` adds dependency and integration maintenance.

The cost is justified by broader playback compatibility for local subtitle libraries.

## Alternatives Considered

### AVFoundation

AVFoundation provides strong native macOS integration, lower dependency risk, and simpler signing.

It was not selected as the target engine because its container and codec coverage does not match the product's expected local video file set.

### Embedded `libmpv`

Embedded `libmpv` provides broader local media compatibility and a stronger foundation for subtitle-adjacent playback behavior.

This option was selected.

### External Player Launch

Launching an external player would reduce embedded playback complexity.

It was not selected because the product requires an integrated search-to-playback workflow and predictable timestamp control.

## Consequences

- M1 playback implementation should integrate embedded `libmpv`.
- The app stack must allow AppKit or native view bridging for playback.
- Packaging and release rules must account for bundled native playback dependencies.
- Signing and notarization must be revisited before any distributable release.
- Playback tests must verify local file open, timestamp seek, play, pause, manual seek, and clear errors.
- If `libmpv` integration blocks M1, a follow-up ADR is required before switching to another engine.

