# MKV Internal Subtitle Open Stall Step 2

Date: 2026-06-03

Human-owned document:

- `docs/human/requirements/20260603-Bug-Avoid Embedded MKV Attachment Playback Open Stall.md`

## Scope

- Added a minimal FFmpeg 8.1 patch that exposes
  `cueseeker_skip_internal_subtitles` on the Matroska demuxer.
- When that option is enabled, Matroska header parsing skips the Attachments
  payload and Matroska subtitle tracks are not exposed as AVStreams.
- Added `CUESEEKER_FFMPEG_ROOT` to the macOS Swift package manifest so local
  verification can point at a specific FFmpeg install.
- Made the local debug default prefer `/private/tmp/cueseeker-ffmpeg-8.1-patched`
  when that patched FFmpeg build exists, then fall back to Homebrew. This keeps
  plain local debug rebuilds on the patched demuxer during this bug verification
  step.
- Narrowed the libass link search path to `/opt/homebrew/opt/libass/lib` so
  the main app does not resolve FFmpeg libraries from Homebrew when a patched
  FFmpeg root is supplied.
- Updated macOS native playback, metadata duration inspection, keyframe preview,
  and the native playback probe to pass the demuxer option when opening media.

## Boundary

- This step does not introduce a formal CueSeeker-owned FFmpeg distribution or
  cross-platform packaging flow.
- Windows FFmpeg packaging remains outside this bug fix.
- The formal default toolchain/distribution path remains outside this bug fix;
  the local debug default only prefers the temporary patched FFmpeg build when
  it is present.

## Patch

- `third_party/ffmpeg/patches/ffmpeg-8.1-cueseeker-skip-internal-subtitles.patch`

## Verification

- Baseline data before implementation showed the reported Attack on Titan files
  spending their delay in `avformat_open_input`, not `avformat_find_stream_info`.
- A temporary patched FFmpeg build at `/private/tmp/cueseeker-ffmpeg-8.1-patched`
  reduced the affected MKV streams exposed to video + audio only.
- The FFmpeg patch file applied cleanly to a fresh FFmpeg 8.1 source tree with
  `patch --dry-run`.
- `CUESEEKER_FFMPEG_ROOT=/private/tmp/cueseeker-ffmpeg-8.1-patched swift build --package-path apps/macos-native`
  passed.
- `apps/macos-native/.build/arm64-apple-macosx/debug/NativePlaybackProbe --inspect`
  on the reported Attack on Titan sample showed only the H.264 video stream and
  AAC audio stream.
- `otool -L apps/macos-native/.build/arm64-apple-macosx/debug/CueSeeker`
  confirmed the main app links to the patched FFmpeg dylibs when
  `CUESEEKER_FFMPEG_ROOT` is supplied.
- After the manifest default was adjusted,
  `swift build --package-path apps/macos-native` passed without
  `CUESEEKER_FFMPEG_ROOT`.
- After that plain debug rebuild,
  `otool -L apps/macos-native/.build/arm64-apple-macosx/debug/CueSeeker`
  confirmed the main app links to `/private/tmp/cueseeker-ffmpeg-8.1-patched`
  FFmpeg dylibs.
- `CUESEEKER_FFMPEG_ROOT=/private/tmp/cueseeker-ffmpeg-8.1-patched swift test --package-path apps/macos-native`
  passed 7 XCTest tests and 180 Swift Testing tests. The run still printed
  existing non-fatal disk I/O and empty MKV probe diagnostics.
- `swift test --package-path apps/macos-native` passed 7 XCTest tests and 180
  Swift Testing tests without `CUESEEKER_FFMPEG_ROOT`. The run still printed
  existing non-fatal disk I/O and empty MKV probe diagnostics.
- Final automated comparison on the reported folder confirmed the fix:

  | Sample | Unpatched Homebrew total | Patched total | Streams after patch |
  | --- | ---: | ---: | --- |
  | EP01 | 1379.402ms | 68.375ms first run, 5.568ms warm | 1 video, 1 audio, 0 subtitle, 0 attachment |
  | EP21 | 5144.162ms | 57.197ms first run, 5.830ms warm | 1 video, 1 audio, 0 subtitle, 0 attachment |
  | EP25 | 7171.219ms | 59.273ms first run, 4.426ms warm | 1 video, 1 audio, 0 subtitle, 0 attachment |

- Human end-to-end acceptance: the owner reported no obvious issue after
  rebuilding and testing the patched debug app.
