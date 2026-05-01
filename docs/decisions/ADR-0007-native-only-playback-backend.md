# ADR-0007: Native-Only Playback Backend

Status: Accepted

Supersedes ADR-0006.

## Background

ADR-0006 moved production playback from `libmpv` primary playback to a
native-first backend with `libmpv` fallback. That was useful for app integration,
but fallback can now hide native playback defects that need to be exposed and
fixed directly.

The archived Flutter implementation still contains the older MPV-backed
playback path. That archived implementation remains available for behavioral
comparison when native playback is less smooth, less compatible, or otherwise
regresses. The active native macOS app does not need to keep a second production
playback backend to preserve that reference value.

The current project priority is to improve the pure native playback path quickly,
especially hardware-decoded playback on the current target machine. M4 hardware
decode support is sufficient for the immediate AV1 validation work, and native
software decode can be addressed later after the hardware path is solid.

## Decision

CueSeeker will remove production `libmpv` compatibility and force playback
through the project-owned native backend.

The active app playback path is:

```text
Open local media through FFmpeg
Decode supported video through the selected native decode mode
Display through the native embedded playback surface
Decode audio through FFmpeg
Output audio through AVAudioEngine
Expose native playback failures directly
```

Rules:

- The active native macOS app must not link against, initialize, or fall back to
  `libmpv`.
- Native opening, demuxing, hardware decode, display, audio decode, audio
  output, seek, and playback-control failures must be surfaced as native
  playback errors.
- The native backend may expose hardware, software, and automatic video decode
  modes for compatibility and diagnostics while remaining a single native
  backend.
- Unsupported codecs, unsupported containers, missing hardware decode, audio
  output failures, and seek failures should be treated as compatibility defects
  or explicit unsupported-native cases, not as triggers for another backend.
- The archived Flutter implementation may be consulted for comparison, but
  active native app code must not import or depend on it.
- AV1 work should prioritize the hardware decode path on machines that support
  it, while software decode can be used for diagnostics and compatibility work.

## Rationale

The application needs a reliable native playback path, not a compatibility layer
that masks native defects. Removing fallback makes failures observable during
normal app use and shortens the debugging loop for smoothness, seek behavior,
audio/video pacing, fullscreen behavior, and codec handling.

Keeping MPV in production also adds build, packaging, signing, and maintenance
surface area. Removing it narrows the app to the stack that must actually be
improved for the native rewrite.

## Tradeoffs

- Some files that previously played through `libmpv` will now fail until native
  compatibility is implemented.
- M1-era compatibility breadth is intentionally reduced in favor of exposing and
  fixing native playback issues.
- Native playback error presentation becomes more important because unsupported
  files no longer have an automatic alternate path.
- FFmpeg and VideoToolbox integration remain production-critical dependencies.

These tradeoffs are acceptable because the archived Flutter/MPV code remains
available for comparison while the active app focuses on native playback quality.

## Alternatives Considered

### Keep Native-First With `libmpv` Fallback

This preserves broader compatibility, but it hides exactly the native playback
failures that now need to be exposed and fixed.

### Keep `libmpv` Behind a Debug Switch

This would preserve a convenient comparison path inside the active app, but it
keeps MPV-linked build and packaging complexity in the production target. The
archived Flutter implementation is a sufficient reference for now.

### Native-Only Playback

This is selected. It makes the native backend the only production route and
forces compatibility and smoothness issues to be handled in the native stack.

## Status Notes

- ADR-0006 remains historical context for why native playback entered the
  production app.
- Production playback should keep the stable render-container and Theater Mode
  lifecycle rules, but the contained backend view is now native-only.
- Media inspection and future database metadata should record native
  compatibility facts and failure reasons rather than backend preference.
- Packaging should account for FFmpeg and required non-system FFmpeg
  dependencies, but no longer needs to account for `libmpv`.
