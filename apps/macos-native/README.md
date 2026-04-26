# SubFinderX Native macOS

This directory contains the active native macOS rewrite.

Current stack decisions are defined in:

- `docs/decisions/ADR-0002-native-app-stack.md`
- `docs/decisions/ADR-0003-playback-engine.md`
- `docs/decisions/ADR-0004-sandbox-and-file-access.md`

## Build

The playback module links against Homebrew `libmpv`.

```bash
brew install mpv
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
swift run SubFinderX
```

The current target is a minimal native macOS M1 loop for local subtitle indexing,
search, and timestamp playback.
