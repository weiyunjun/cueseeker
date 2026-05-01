# CueSeeker Native macOS

This directory contains the active native macOS rewrite.

Current stack decisions are defined in:

- `docs/decisions/ADR-0002-native-app-stack.md`
- `docs/decisions/ADR-0003-playback-engine.md`
- `docs/decisions/ADR-0004-sandbox-and-file-access.md`
- `docs/decisions/ADR-0006-native-first-playback-backend.md`
- `docs/decisions/ADR-0007-native-only-playback-backend.md`

## Build

The playback module uses FFmpeg libraries for the native backend.

```bash
brew install ffmpeg
```

```bash
swift build
```

## Test

```bash
swift test
```

## Run

```bash
swift run CueSeeker
```

The current target is a minimal native macOS M1 loop for local subtitle indexing,
search, and timestamp playback.
