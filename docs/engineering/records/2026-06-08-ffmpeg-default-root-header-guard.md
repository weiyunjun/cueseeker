# FFmpeg Default Root Header Guard

Human requirement:

- `docs/human/requirements/20260603-Bug-Avoid Embedded MKV Attachment Playback Open Stall.md`

Related implementation record:

- `docs/engineering/records/2026-06-03-mkv-internal-subtitle-open-stall-step-2.md`

## Scope

This record covers a build fix for the macOS native package manifest's default
FFmpeg root selection.

The previous manifest selected `/private/tmp/cueseeker-ffmpeg-8.1-patched` when
`lib/libavformat.dylib` existed. That was not sufficient for compilation:
`swift run CueSeeker` can fail if the patched root has dylibs but is missing the
FFmpeg headers required by the C playback target.

## Changes

- Added `isUsableFFmpegRoot(_:)` to `apps/macos-native/Package.swift`.
- The default patched FFmpeg root is now selected only when the required
  FFmpeg headers and dylibs used by the package are present.
- If the patched root is incomplete, the manifest falls back to `/opt/homebrew`
  unless `CUESEEKER_FFMPEG_ROOT` explicitly overrides the root.

## Verification

- `swift build --target CueSeekerApp` succeeded without `CUESEEKER_FFMPEG_ROOT`.
- `swift build --product CueSeeker` succeeded without `CUESEEKER_FFMPEG_ROOT`.
- `swift run CueSeeker` succeeded through the build phase without
  `CUESEEKER_FFMPEG_ROOT`; the launched app process exited before cleanup was
  needed.

## Outcome

The default build path no longer chooses an incomplete patched FFmpeg root when
only dylibs are present. The compile phase used by `swift run CueSeeker` no
longer requires users to pass `CUESEEKER_FFMPEG_ROOT`.
