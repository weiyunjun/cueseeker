# Product Brief

Status: Draft

## 1. Product Summary

CueSeeker is a personal macOS desktop app for searching subtitle text and jumping directly to the matching video timestamp.

The Chinese product name is `字幕求索`.

The product is built around one core workflow:

```text
Choose local subtitle folders
Index subtitle files
Search for a line
Click a result
Play the matching local video at the matching timestamp
```

## 2. Target User

The primary user is the project owner.

The app is optimized for personal macOS usage, not for public distribution, team collaboration, or cross-platform parity.

## 3. Core Value

The app should make it fast to find a sentence or phrase from a local subtitle library and immediately inspect the corresponding video context.

The key value is not subtitle file management. The key value is searchable subtitle-to-video navigation.

## 4. Product Direction

The native macOS rewrite should prioritize:

- A reliable local subtitle search workflow.
- Fast local indexing.
- Accurate subtitle timestamp parsing.
- Stable local video timestamp playback.
- Native macOS interaction quality.
- A maintainable local data model.

## 5. Early Product Constraints

The early native rewrite should be local-first.

Provisional platform constraint:

- Minimum supported macOS version: macOS 13.0 Ventura.

This minimum version may be raised before implementation if the chosen playback engine, sandbox strategy, or native UI APIs require it.

The following are intentionally not early priorities:

- Remote subtitle indexing.
- Remote video playback.
- Cloud sync.
- Mobile support.
- Public release polish.
- Vocabulary or Anki workflows.

## 6. Success Criteria

The first usable native version is successful when:

- The user can select a local subtitle folder.
- The app indexes supported external subtitle files from that folder.
- The app can search indexed subtitle text.
- Search results show enough context to identify the match.
- Clicking a result opens the matching local video.
- Playback starts near the subtitle start time.
- The app feels like a native macOS desktop tool.
