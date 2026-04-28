# Native Playback Backend

Status: Draft

## Background

The current native macOS app uses embedded `libmpv` for local playback.
This direction was accepted in `docs/decisions/ADR-0003-playback-engine.md`
because `libmpv` provides broad local media compatibility and reliable
container support.

Recent playback memory checks show that the current `libmpv` direction has a
high memory baseline for ordinary local playback. A representative file is:

```text
Container: Matroska
Video: H.264 High, yuv420p, 1920x1080, 59.94 fps
Audio: Opus stereo
Bitrate: about 5175 kb/s
```

Observed local comparisons showed:

- Movist Pro playing the same file with a much lower memory footprint.
- VLC and Infuse using substantially less memory than mpv-based playback.
- IINA, which is mpv-based, showing memory usage in the same broad range as
  the current SubFinderX playback direction.
- Standalone mpv with hardware decoding enabled still retaining a high memory
  baseline compared with the lower-memory players.

These observations suggest that optimizing mpv options may reduce CPU usage and
some memory pressure, but it is unlikely to reach the desired memory profile.

The proposed direction is to evaluate a project-owned native playback backend:

```text
Local media file
FFmpeg/libavformat demux
Compressed video packets
VideoToolbox hardware decode when available
Low-copy display through a native macOS rendering path
Audio decode and playback through a bounded local pipeline
mpv fallback for unsupported or unstable cases
```

This proposal does not require transcoding. The goal is to keep the compressed
media stream intact, demux it, and feed supported video formats into macOS
native decoding and display components.

## Goals

- Reduce playback memory usage for common local files.
- Avoid using mpv as the default playback path for formats that can be handled
  efficiently through native macOS decoding.
- Use FFmpeg/libavformat for container demuxing instead of implementing custom
  MKV, WebM, or MP4 demuxers.
- Use VideoToolbox hardware decoding for supported codecs.
- Support H.264 and HEVC as first-class native-backend codecs.
- Support AV1 when the current Mac and macOS runtime report hardware decode
  support.
- Keep playback local-only.
- Preserve the current SubFinderX workflow:
  search result selection, local video open, timestamp seek, play, pause, and
  embedded playback.
- Keep mpv as a fallback backend for unsupported codecs, unsupported audio,
  unusual containers, or native-backend failure.
- Keep queues bounded so the native backend does not recreate mpv-like memory
  pressure.

## Non-goals

- Do not build a general-purpose media player.
- Do not transcode media files.
- Do not modify user media files.
- Do not require a local HTTP proxy.
- Do not implement advanced subtitle rendering in the first native-backend
  iteration.
- Do not attempt full codec parity with mpv in the first iteration.
- Do not remove mpv until the native backend has proven compatibility and
  fallback behavior.
- Do not commit to public distribution packaging before FFmpeg licensing,
  bundling, signing, and notarization implications are reviewed.

## User Flow

The user flow should remain unchanged:

```text
Open Search
Search subtitle text
Click a result
Playback Inspector opens or updates
Playback backend opens the matched local video
Playback seeks to the result start timestamp
User plays, pauses, seeks, or selects another result
```

The backend selection should be internal. The user should not need to choose a
playback engine for normal use.

Provisional backend selection:

```text
Try native backend for supported local files
If native backend cannot open, decode, seek, or play reliably
Fall back to mpv backend
Surface a clear playback error only if all available backends fail
```

## UI/UX Impact

The first native-backend evaluation should not change the main playback UI.

The existing Playback Inspector, playback fullscreen behavior, keyboard
shortcuts, and feedback overlays should continue to work through a backend
abstraction.

Potential UI additions after implementation proves useful:

- A diagnostic-only indicator for the active backend.
- A diagnostic-only indicator for hardware decode status.
- A settings or debug switch to force mpv fallback during troubleshooting.

These indicators should not be part of the primary user workflow unless later
product requirements justify them.

## Data Model Impact

No database schema change is required.

Search results already contain the required playback inputs:

- Matched local video path.
- Subtitle start timestamp in milliseconds.
- Subtitle end timestamp when available.

No media-derived playback cache should be stored in the database for the first
native-backend iteration.

## Technical Direction

The proposed native backend should be decomposed into small responsibilities:

```text
PlaybackBackend
MediaDemuxer
VideoDecodePipeline
VideoDisplaySurface
AudioDecodePipeline
PlaybackClock
SeekController
BackendFallbackController
```

### Demuxing

Use FFmpeg/libavformat to:

- Open local media files.
- Identify streams.
- Read compressed packets.
- Track packet timestamps, durations, keyframes, and time bases.
- Extract codec parameters and extradata.
- Use FFmpeg bitstream filters where needed.

The project should not implement a custom MKV or WebM demuxer unless FFmpeg
becomes unsuitable for licensing, packaging, or maintenance reasons.

### Video Decoding

Use VideoToolbox for supported hardware decode paths.

Initial codec support:

- H.264.
- HEVC.
- AV1 when `VTIsHardwareDecodeSupported` or equivalent runtime probing reports
  support on the current system.

The native backend must not assume AV1 hardware decode is universally available.
Apple hardware support varies by Mac generation. Unsupported AV1 files should
fall back to mpv or another fallback path unless a later decision adds software
AV1 decoding.

The implementation must handle container-specific codec metadata:

- H.264 SPS/PPS, AVCC, and Annex B differences.
- HEVC VPS/SPS/PPS and HVCC differences.
- AV1 sequence headers, OBU data, and AV1 codec configuration data.

### Display

The display path should avoid unnecessary frame copies.

Candidate approaches:

- `AVSampleBufferDisplayLayer` fed with correctly timed sample buffers.
- A Metal-backed view that renders VideoToolbox `CVPixelBuffer` output through
  CoreVideo/IOSurface-backed textures.

The first implementation should choose the simpler path that can prove low
memory usage and stable seek/playback behavior. If `AVSampleBufferDisplayLayer`
is not flexible enough for the app's fullscreen and overlay requirements, a
Metal display path should be evaluated.

### Audio

Audio is part of the core difficulty and should not be treated as an afterthought.

Possible initial direction:

- Use FFmpeg to decode unsupported or uncertain audio formats such as Opus into
  PCM.
- Feed PCM into `AVAudioEngine`, `AudioQueue`, or another native macOS audio
  output path.
- Keep audio buffering bounded.
- Use the audio clock as the primary playback clock when audio is present.

The first native-backend milestone may support a narrow audio matrix, but it
must fail over to mpv when audio cannot be decoded or synchronized reliably.

### Clock and Synchronization

The native backend must own an explicit playback clock.

Rules:

- Audio should be the master clock when audio is present and active.
- Video frames should be displayed according to packet or frame timestamps.
- Pausing must pause both the clock and output queues.
- Seeking must flush decoder state and output queues.
- Playback should drop or delay video frames when necessary to preserve sync.

### Seeking

Seeking should:

- Convert the requested `start_ms` to the demuxer's stream time base.
- Seek to a keyframe at or before the target timestamp.
- Flush audio and video decode state.
- Decode forward from the keyframe.
- Discard frames before the requested timestamp when necessary.
- Resume synchronized playback from the target region.

Exact frame-perfect seeking is not required for SubFinderX, but seeking must be
close enough for subtitle context review.

### Fallback

The fallback backend remains important.

Use mpv fallback when:

- The codec is unsupported by the native backend.
- VideoToolbox cannot create a decode session.
- Hardware decode is unavailable and software fallback is not implemented.
- Audio cannot be decoded or synchronized.
- Seek behavior fails validation.
- Playback enters an unrecoverable backend error state.

## Technical Risk

Key risks:

- Audio/video synchronization may be harder than demuxing or video decode.
- Seek behavior requires careful decoder flushing and queue reset behavior.
- Codec metadata conversion differs by codec and container.
- AV1 support depends on the user's Mac hardware and macOS runtime.
- Opus audio may require FFmpeg decode to PCM before native audio output.
- A naive display path could add frame copies and lose the memory advantage.
- FFmpeg packaging and licensing must be reviewed before formal release.
- A native backend can become a maintenance burden if it grows toward general
  media-player scope.

The project should mitigate these risks by keeping the first implementation
narrow and measurable.

## Acceptance Criteria

The proposal can be accepted when the team agrees on:

- Whether mpv should move from primary backend to fallback backend.
- Which codecs the first native backend must support.
- Whether AV1 is runtime-probed and optional rather than universally required.
- Which display path should be prototyped first.
- Which audio output path should be prototyped first.
- Which FFmpeg linking, licensing, and packaging strategy is acceptable for
  local development and future release.
- What memory target defines success for the representative H.264 1080p60 MKV.

The first implementation milestone should be considered successful only if:

- The representative H.264 1080p60 MKV plays through the native backend.
- Playback can seek to a subtitle result timestamp.
- Play and pause work.
- Audio stays acceptably synchronized for subtitle context review.
- Memory usage is substantially below the current mpv-based path.
- Unsupported files fall back to mpv without breaking the user workflow.
- The implementation does not introduce unbounded packet, frame, or audio queues.

## Decision

Pending.

This proposal records the candidate direction for discussion:

```text
Move from mpv-primary playback to a native macOS playback backend for supported
files, using FFmpeg demuxing plus VideoToolbox hardware decoding, while keeping
mpv as a fallback backend for compatibility.
```

If accepted, this proposal should be followed by either:

- A superseding ADR that updates `ADR-0003-playback-engine.md`.
- Product and engineering document updates that define the new playback backend
  strategy.
- A focused implementation plan for a narrow native-backend prototype.
