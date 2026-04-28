# ADR-0006: Native-First Playback Backend

Status: Accepted

## Background

ADR-0003 selected embedded `libmpv` as the app playback engine because it offered
the broadest local media compatibility during M1.

Post-M1 native playback probe work showed that a project-owned native backend can
handle representative local media with substantially lower physical footprint:

- H.264 1080p60 Matroska with Opus audio through FFmpeg demuxing,
  VideoToolbox hardware decode, `AVSampleBufferDisplayLayer`, FFmpeg Opus
  decode, and `AVAudioEngine`.
- HEVC 10-bit Matroska with HE-AAC 5.1 audio downmixed to stereo.
- VP9 WebM with Opus stereo audio.

The probe also validated timestamp seek, repeated seek-list simulation, pause and
resume simulation, duration-limited memory sampling, interrupt-safe summaries,
audio stream inspection, explicit audio stream selection, stereo downmix for
multi-channel audio, and batch candidate inspection.

## Decision

SubFinderX will move to native-first playback for supported local files.

The production app should try the native backend first and keep `libmpv` as a
fallback backend.

Current native backend responsibilities:

- Open local files directly through FFmpeg/libavformat.
- Decode supported video streams through VideoToolbox hardware decode.
- Display decoded hardware frames in the embedded playback surface.
- Decode audio through FFmpeg and schedule PCM audio through `AVAudioEngine`.
- Downmix multi-channel audio to stereo when needed for the native output path.
- Use audio-clock pacing when audio is available.
- Seek to the selected subtitle timestamp.

Fallback rules:

- Use `libmpv` when native opening, decoding, audio output, or seek setup fails.
- Use `libmpv` for user actions that are not yet implemented by the native
  backend, such as non-1.0 playback speed.
- Keep `libmpv` available until native backend compatibility, controls,
  fullscreen behavior, and packaging are proven across the app workflow.

## Rationale

SubFinderX is a subtitle-search workflow tool, not a general-purpose media
player. The default path should optimize the common local playback cases the app
actually uses: open a matched file, seek to a subtitle timestamp, play or pause,
and remain memory efficient during repeated result selection.

The native probe showed a materially lower memory profile than the `libmpv`
path for representative files. Keeping native playback isolated indefinitely
would avoid integration risk but would not validate the real app workflow, where
view movement, playback inspector behavior, shortcuts, fullscreen, and repeated
search-result selection matter.

The pragmatic choice is native-first integration with `libmpv` fallback, not
removing `libmpv`.

## Tradeoffs

- Native playback has narrower codec coverage than `libmpv`.
- The first production native backend does not implement full media-player
  parity.
- Subtitle rendering remains outside the first native backend integration.
- Some actions may switch to `libmpv` fallback until native equivalents exist.
- FFmpeg and native audio/video pipeline maintenance now becomes production app
  work, not only probe work.

These tradeoffs are acceptable because fallback remains available and the native
path can now be tested in the actual SubFinderX workflow.

## Alternatives Considered

### Keep `libmpv` Primary

This preserves broad compatibility but keeps the higher memory baseline observed
in local tests. It also prevents app-level validation of the native path.

### Remove `libmpv`

This would simplify backend selection but is premature. Unsupported codecs,
unusual containers, and unimplemented playback controls still need a fallback.

### Native-First With `libmpv` Fallback

This is selected. It optimizes common supported files while preserving a
compatibility path for failures and unsupported behavior.

## Status Notes

The first app integration is intentionally narrow:

- Native backend is primary for ordinary open, seek, play, pause, and volume.
- `libmpv` remains bundled and available as fallback, but the app should not
  initialize or retain an MPV player during successful native playback.
- Returning playback speed to `1.0x` should give the facade an opportunity to
  retry the native backend from the current playback position.
- Native timestamp seek should tolerate files that reject stream-specific seek
  by retrying with a global seek before falling back to `libmpv`.
- AV1 hardware decode should select a VideoToolbox-capable FFmpeg decoder when
  the default decoder is software-only, such as `libdav1d`.
- The next native display direction is a shared Metal YUV renderer that can
  render both VideoToolbox hardware frames and future software-decoded YUV
  frames.
- `libmpv` remains the final fallback while native software decode, Metal color
  handling, subtitle behavior, and broader format coverage are still being
  validated.
- Full app workflow testing is required before declaring the native backend
  complete.
- Packaging, signing, and notarization must account for FFmpeg libraries in
  addition to `libmpv` while fallback remains present.
- If a future decision removes `libmpv`, packaging still must bundle FFmpeg's
  required libraries and any non-system transitive codec dependencies used by
  the selected FFmpeg build. macOS system frameworks such as VideoToolbox,
  Metal, AVFoundation, CoreVideo, CoreMedia, and AVFAudio should remain system
  dependencies rather than bundled app payload.
