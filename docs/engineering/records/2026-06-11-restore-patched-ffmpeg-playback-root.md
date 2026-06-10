# Restore Patched FFmpeg Playback Root

Human requirement:

- `docs/human/requirements/20260611-Bug-Restore Patched FFmpeg Playback Root.md`

## Scope

This record covers the June 11 regression fix for the macOS native FFmpeg root
selection. The June 8 build guard fixed compilation when the temporary patched
FFmpeg root had dylibs but no headers, but it also made the default build link
against Homebrew FFmpeg and therefore lost the patched Matroska demuxer option
used by playback.

## Changes

- Split default FFmpeg root selection into include and library roots.
- Preserved `CUESEEKER_FFMPEG_ROOT` as an explicit override for both include and
  library roots.
- Made the default include root fall back to Homebrew when the patched root has
  no headers.
- Made the default library root prefer the patched FFmpeg dylibs whenever they
  are present, so playback resolves the demuxer that supports
  `cueseeker_skip_internal_subtitles`.
- Updated the AI interaction rules so future fixes cannot reuse stale human
  requirements for new regression scopes and cannot treat compile success as
  enough when build fixes change runtime dependency selection.

## Verification

- `swift build --product CueSeeker`
- `swift build --product NativePlaybackProbe`
- `swift build --target CueSeekerApp`
- `otool -L apps/macos-native/.build/debug/CueSeeker` shows FFmpeg dylibs
  resolving from `/private/tmp/cueseeker-ffmpeg-8.1-patched/lib`.
- `otool -L apps/macos-native/.build/debug/NativePlaybackProbe` shows FFmpeg
  dylibs resolving from `/private/tmp/cueseeker-ffmpeg-8.1-patched/lib`.
- `apps/macos-native/.build/debug/NativePlaybackProbe --inspect` on the
  Shingeki no Kyojin sample reports the H.264 video stream and AAC audio stream
  as native candidates.

## Outcome

- The default build now keeps using Homebrew headers when the patched temporary
  root does not provide headers, while linking playback targets to the patched
  FFmpeg dylibs when they are present.
- `CUESEEKER_FFMPEG_ROOT` remains the explicit override for both include and
  library roots.
