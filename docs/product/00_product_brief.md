# Product Brief

Status: Draft

## 1. Product Summary

CueSeeker is a personal macOS desktop app for searching subtitle text and jumping directly to the matching video timestamp.

The Chinese product name is `字幕求索`.

CueSeeker is also a local subtitle corpus workbench for language learning and
media memory. It helps users turn loved source material into searchable,
reviewable, and exportable raw learning material.

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

The early app is optimized for personal macOS usage, not for broad public
distribution, team collaboration, or cross-platform parity.

The intended distributable audience is a small group of heavy users with
similar habits: Japanese and English learners, Chinese-speaking local media
users, fansub-aware users, fan creators, and users who want to turn familiar
anime, films, dramas, or YouTube videos into raw study material.

## 3. Core Value

The app should make it fast to find a sentence or phrase from a local subtitle library and immediately inspect the corresponding video context.

The key value is not subtitle file management. The key value is searchable subtitle-to-video navigation.

The broader product value is not automatic instruction. The product should help
users compare real contexts from material they already care about, then collect
that raw material for user-chosen study workflows such as Anki, Markdown notes,
or future learning-session features.

## 4. Product Direction

The native macOS rewrite should prioritize:

- A reliable local subtitle search workflow.
- Fast local indexing.
- Accurate subtitle timestamp parsing.
- Stable local video timestamp playback.
- Native macOS interaction quality.
- A maintainable local data model.
- Respect for user-owned local material, source subtitles, fansub culture, and
  fan-creation workflows.

## 5. Early Product Constraints

The early native rewrite should be local-first.

The app should not crawl online platforms or provide AI-powered explanation as
core product behavior. Users may prepare subtitles through external tools, but
CueSeeker's responsibility is to index, search, play, collect, and export the
local material they provide.

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
