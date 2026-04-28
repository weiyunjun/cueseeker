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

### Prototype Status

An isolated native playback probe now exists under:

```text
apps/macos-native/Sources/NativePlaybackProbe/
```

The probe is intentionally separate from the production app playback path. It is
used to validate the proposed backend direction before the app's `libmpv`
integration is changed.

Validated so far:

- FFmpeg/libavformat can open the representative Matroska sample.
- FFmpeg/libavcodec can decode the H.264 video stream through VideoToolbox.
- The representative H.264 1080p60 sample produces hardware frames with
  `videotoolbox_vld`.
- The decoded VideoToolbox frame output can be displayed in a temporary AppKit
  window through `AVSampleBufferDisplayLayer`.
- The representative Opus audio stream can be decoded by FFmpeg into planar
  float PCM and scheduled through `AVAudioEngine`.
- Basic timestamp-driven video pacing works for the representative sample.
- A 300-video-packet run produced 300 hardware video frames, 0 software video
  frames, 0 late paced video frames, and no audio decode failures.
- The isolated probe can seek before playback with `--seek`, reset decoder and
  output state, discard pre-target frames, and resume VideoToolbox-backed video
  output plus native audio scheduling on a generated H.264/AAC sample.
- A display-mode seek smoke run against a generated 4-second H.264/AAC sample
  at 2.0 seconds produced 45 hardware video frames, 0 software video frames, 0
  late paced video frames, and no audio decode failures.
- The probe's frame limit now counts post-seek output video frames instead of
  raw video packets, with a bounded seek-preroll packet limit to avoid hiding
  long-GOP seek cost or running unbounded preroll decode.
- A display-mode seek run against the representative H.264/Opus Matroska sample
  at 60.0 seconds with 180 requested output video frames produced 477 hardware
  decoded frames, 0 software frames, 180 paced output frames, 0 late paced
  frames, and no audio decode failures.
- The display probe now starts `AVAudioPlayerNode` only after the first valid
  post-target audio buffer is scheduled, and video pacing uses the audio clock
  once that clock is initialized.
- A display-mode audio-clock seek run against the representative Matroska sample
  at 60.0 seconds with 180 requested output video frames produced 179
  audio-master paced video frames, 1 video-clock fallback frame, 0 late paced
  frames, and no audio decode failures.
- The display probe can run a repeated seek with `--seek-again`, flushing decoder
  and output state a second time and rebuilding the audio clock for the next
  playback segment.
- A repeated seek display run against the representative Matroska sample from
  60.0 seconds to 90.0 seconds with 60 output video frames per segment produced
  120 total output video frames, 532 hardware decoded frames, 0 software frames,
  118 audio-master paced video frames, 2 video-clock fallback frames, and no
  audio decode failures.
- The display probe can simulate pause and resume with `--pause-after-frames`
  and `--pause-duration`, pausing the audio player plus decode/display loop and
  shifting playback clocks before resuming.
- A seek plus pause display run against the representative Matroska sample at
  60.0 seconds, pausing for 1.0 seconds after 60 output frames, produced 120
  output video frames, 0 late paced frames, 119 audio-master paced video frames,
  1 video-clock fallback frame, and no audio decode failures.
- The display probe can now run for a requested wall-clock playback duration
  with `--run-duration` and print process memory samples with
  `--memory-sample-interval`.
- A duration-limited display run against the representative Matroska sample at
  60.0 seconds for 1.0 second produced 62 output video frames, 359 hardware
  decoded frames, 0 software frames, 61 audio-master paced video frames, 1
  video-clock fallback frame, 0 late paced frames, no audio decode failures, and
  a native probe physical-footprint range from 12.6 MB at start to 23.5 MB max.
- The probe now supports `--quiet` for iterative stability runs and handles
  Ctrl-C/SIGTERM by finishing the decode loop, printing the usual summary, and
  preserving a non-zero interrupted exit code in display mode.
- The probe now supports `--seek-list` and `--seek-list-loops` so repeated
  search-result selection can be stress-tested without manually restarting the
  probe.
- The probe now supports `--inspect` to quickly classify media files before
  playback testing by reporting container streams, FFmpeg decoder availability,
  VideoToolbox config availability, VideoToolbox device creation, audio decoder
  availability, and whether the file is a native-backend candidate.

Important prototype observations:

- Running the probe inside the Codex sandbox can prevent VideoToolbox hardware
  decode initialization. The same probe succeeds from a normal macOS Terminal.
- The FFmpeg Opus decoder may print a startup timestamp warning related to
  skipped samples. The representative sample still decodes and schedules audio
  successfully after the initial shortened frame.
- The current probe has a narrow audio-master pacing prototype. It is not yet a
  final production synchronization model and does not yet implement bounded
  packet, frame, or audio queues.
- The representative Matroska sample required about 297 decoded video frames of
  preroll before the first output frame at approximately 60.027 seconds.

Latest user-verified representative runs:

- A 600.015-second duration-limited display run from 60.0 seconds produced
  35,966 output video frames, 36,263 hardware decoded frames, 0 software frames,
  0 late video frames, 35,965 audio-master paced video frames, 1 video-clock
  fallback frame, 0 audio decode failures, and a physical-footprint profile of
  13.4 MB start, 33.2 MB max, and 32.9 MB end.
- An interrupted 184.482-second quiet display run from 60.0 seconds produced
  11,059 output video frames, 11,356 hardware decoded frames, 0 software frames,
  3 late video frames with 0.016 seconds max lateness, 0 audio decode failures,
  and a physical-footprint profile of 13.3 MB start, 27.2 MB max, and 26.8 MB
  end.
- A repeated search-result selection simulation using `--seek-list
  60.0,90.0,120.0,150.0 --seek-list-loops 15` with 300 output frames per
  segment completed 60 seek operations, produced 18,000 output video frames,
  29,340 hardware decoded frames, 0 software frames, 13 late video frames with
  0.106 seconds max lateness, 0 audio decode failures, and a physical-footprint
  profile of 12.4 MB start, 27.5 MB max, and 24.6 MB end.

Current interpretation:

- The native probe has shown a substantially lower physical-footprint profile
  than the observed `libmpv` app playback path for the representative H.264/Opus
  Matroska sample.
- The repeated seek-list result is good enough to continue toward broader
  candidate screening, but it still needs app-level verification before any
  production playback backend decision.
- The next useful probe step is multi-format screening with `--inspect`, followed
  by short 5-minute stability runs only for files reported as native candidates.

Current prototype command:

```bash
swift build --product NativePlaybackProbe
.build/debug/NativePlaybackProbe --inspect "/path/to/video.mkv"
.build/debug/NativePlaybackProbe --display "/path/to/video.mkv" 300
.build/debug/NativePlaybackProbe --display --seek 60.0 "/path/to/video.mkv" 300
.build/debug/NativePlaybackProbe --display --seek 60.0 --seek-again 90.0 "/path/to/video.mkv" 60
.build/debug/NativePlaybackProbe --display --seek 60.0 --pause-after-frames 60 --pause-duration 1.0 "/path/to/video.mkv" 120
.build/debug/NativePlaybackProbe --display --seek 60.0 --run-duration 600 --memory-sample-interval 10 "/path/to/video.mkv"
.build/debug/NativePlaybackProbe --display --quiet --seek 60.0 --run-duration 300 --memory-sample-interval 10 "/path/to/video.mkv"
.build/debug/NativePlaybackProbe --display --quiet --seek-list 60.0,90.0,120.0,150.0 --seek-list-loops 15 --memory-sample-interval 10 "/path/to/video.mkv" 300
```

The optional trailing number is the target number of output video frames after
each seek target, not a raw demux packet limit.
When `--run-duration` is provided without a trailing frame count, the probe uses
the requested playback duration as the primary stop condition.
Use `--quiet` for repeated 5-minute runs so memory samples and the final summary
remain readable.
Use `--seek-list` with a trailing frame count to simulate repeatedly selecting
different subtitle search results. For a 59.94 fps file, `300` output frames per
seek target is roughly five seconds per selected result.
Use `--inspect` first when screening HEVC, AV1, MOV, FLV, AVI, or other files.
Files that are not reported as native candidates should remain fallback-only
until a specific codec/container path is implemented and tested.

Expected representative output includes:

```text
Hardware frames: 300
Software frames: 0
Output video frames: 300
Paced video frames: 300
Audio clock initialized: yes
Audio-master paced video frames: 299
Audio decode failures: 0
Run duration reached: yes
Memory RSS MB: start=36.1, max=80.9, end=80.6, delta=44.5
Memory footprint MB: start=12.6, max=23.5, end=23.2, delta=10.6
```

When a run is stopped with Ctrl-C or SIGTERM, the summary includes
`Interrupted: yes`.

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
- Play and pause work.
- Audio stays acceptably synchronized for subtitle context review.
- Memory usage is substantially below the current mpv-based path.
- Unsupported files fall back to mpv without breaking the user workflow.
- The implementation does not introduce unbounded packet, frame, or audio queues.

Prototype acceptance progress:

- Done: FFmpeg demux for the representative Matroska file.
- Done: VideoToolbox hardware decode for the representative H.264 stream.
- Done: Temporary native display of decoded hardware frames.
- Done: FFmpeg Opus decode and native audio scheduling for the representative
  sample.
- Done: Timestamp-driven video pacing for the representative sample.
- Done: isolated probe seek to a requested playback timestamp before display.
- Done: narrow display-probe audio-master pacing prototype.
- Done: repeated display-probe seek between two requested playback timestamps.
- Done: display-probe pause and resume simulation.
- Done: duration-limited display-probe runs with process RSS and physical
  footprint sampling.
- Done: quiet iterative probe output and interrupt-safe final summaries.
- Done: repeated seek-list stress runs for search-result selection simulation.
- Done: inspect-only native candidate classification for multi-format screening.
- Not done: production app integration.
- Not done: mpv fallback routing from the app.
- Not done: memory target verification against the app-level playback workflow.

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
