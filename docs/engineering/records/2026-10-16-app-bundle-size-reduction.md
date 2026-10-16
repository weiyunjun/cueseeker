# Implementation Record: App Bundle Size Reduction

- **Date**: 2026-10-16
- **Requirement**: `docs/human/requirements/20261016-Engineering-App Bundle Size Reduction.md`

## Summary of Changes

1. **FFmpeg Encoder, Muxer, and Filter Cropping (`scripts/build_macos_media_runtime.sh`)**:
   - Kept all built-in FFmpeg demuxers, decoders, parsers, bitstream filters, and network protocols enabled by default so playback compatibility across local and WebDAV streams remains unchanged.
   - Added `--disable-encoders`, `--disable-muxers`, and `--disable-filters` with explicit allowlists covering only the components used by CueSeeker's cover extraction, subtitle screenshot, and Anki export workflows:
     - `--enable-encoder=libmp3lame,mjpeg,bmp,png,rawvideo,wrapped_avframe`
     - `--enable-muxer=mp3,image2,image2pipe,rawvideo,avif,mov,mp4,null`
     - `--enable-filter=scale,pad,crop,format,null,aformat,anull,aresample,pan,transpose,hflip,vflip`

2. **Pre-Codesign Local Symbol Stripping (`scripts/package_macos_app.sh`)**:
   - Added `strip -x` for `Contents/MacOS/CueSeeker`, `Contents/Helpers/ffmpeg`, and all `Contents/Frameworks/*.dylib` libraries after `rpath` cleanup and immediately before ordered `codesign` signing.

3. **Runtime Verification & Documentation (`scripts/verify_macos_media_runtime.sh`, `docs/engineering/09_macos_media_runtime_and_packaging.md`)**:
   - Extended `verify_macos_media_runtime.sh` to verify that required encoder, muxer, and filter `CONFIG_*` entries are present in `ffmpeg-config.mak`.
   - Updated `docs/engineering/09_macos_media_runtime_and_packaging.md` to document the encoder/muxer/filter allowlist and pre-signing `strip -x` step.

## Verification

- Rebuilt the controlled media runtime via `./scripts/build_macos_media_runtime.sh` and verified it with `./scripts/verify_macos_media_runtime.sh`.
- Packaged `CueSeeker.app` via `./scripts/package_macos_app.sh` and verified code signatures and bundle layout via `./scripts/verify_macos_app_bundle.sh`.
- Measured total packaged app bundle size reduction:
  - Total `CueSeeker.app` size reduced from `46.96 MB` (`47.0 MB` decimal) to **`30.73 MB` decimal (`29.30 MiB` / `29M`)**:
    - `Contents/MacOS/CueSeeker`: `19.11 MB` ➔ `8.78 MB`
    - `Contents/Frameworks/`: `25.20 MB` ➔ `19.27 MB` (`libavfilter.dylib` `3.75 MB` ➔ `0.27 MB`, `libavcodec.dylib` `12.88 MB` ➔ `11.50 MB`, `libavformat.dylib` `2.55 MB` ➔ `2.00 MB`)
- Verified bundled `Contents/Helpers/ffmpeg` directly across rawvideo cover scoring (`rawvideo + scale + pad`), full-resolution JPEG cover/Anki image extraction (`image2 + mjpeg`), subtitle screenshot frame extraction (`image2pipe + bmp`), and Anki MP3 audio export (`aresample + libmp3lame + mp3`).
- Ran automated playback and export tests (`LibraryCoverIndexerTests`, `SubtitleScreenshotExporterTests`, `AnkiPackageExporterTests`, `NativePlaybackMediaTimelineTests`).
