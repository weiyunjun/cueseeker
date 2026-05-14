# Non-Goals

Status: Draft

## 1. Purpose

This document defines what the project should intentionally not do in the early native macOS rewrite.

Non-goals help prevent scope creep.

## 2. Platform Non-Goals

The early native rewrite will not target:

- iOS.
- iPadOS.
- Android.
- Windows.
- Linux.
- Web.

The project is macOS-first.

## 3. Distribution Non-Goals

The early native rewrite will not optimize for:

- Public App Store release.
- Broad public onboarding.
- Multi-user deployment.
- Enterprise distribution.
- Plugin marketplace support.

The project is a personal tool first.

## 4. Remote Feature Non-Goals

The early native rewrite will not implement:

- Remote subtitle indexing.
- Remote video playback.
- Online video crawling or downloading.
- WebDAV integration.
- AList integration.
- Cloud sync.
- Remote cache management.

These may be reconsidered only after the local-first workflow is stable.

## 5. Media Product Non-Goals

The app will not become a full media manager in the early rewrite.

Out of scope:

- Media library browsing.
- Poster or metadata scraping.
- Playlist management.
- Transcoding.
- File renaming.
- Download management.

## 6. Learning Feature Non-Goals

The early rewrite will not implement:

- Full Anki ownership or a complete spaced-repetition system.
- Vocabulary book workflows.
- Spaced repetition.
- Translation popovers.
- Word-level selection tools.
- AI-powered explanation, translation, transcription, or semantic search as core
  product behavior.

Shiori, export workflows, Anki integration, URL Scheme support, and raw
material export may be added around the core workflow. They should remain a
bridge from source material to user-chosen study methods rather than turning
CueSeeker into a complete learning platform.

## 7. Visual Effect Non-Goals

The early rewrite will not implement:

- Advanced glass effects.
- Real-time video image processing.
- Custom shader-based video effects.
- Complex animated visual treatments.

These should be reconsidered only after playback architecture is stable.
