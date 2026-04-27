# Changelog

All notable milestone-level project changes are recorded in this file.

This changelog does not replace Git history. Git records concrete file changes. This file records meaningful project progress and milestone outcomes.

## Unreleased

- Established project documentation governance.
- Clarified when `docs/changelog.md` must be updated across documentation, Git workflow, and release rules.
- Archived the legacy Flutter implementation under `archive/flutter/`.
- Began formal engineering documentation for the native macOS rewrite.
- Recorded the native macOS rewrite decision in ADR-0001.
- Recorded native app stack, playback engine, and sandbox/file-access decisions in ADR-0002 through ADR-0004.
- Started the native macOS app shell under `apps/macos-native/`.
- Added core SRT parsing, subtitle file scanning, and same-directory video matching.
- Added the initial SQLite + FTS5 database layer for subtitle entries and search paths.
- Added the core indexing pipeline from selected folders into the SQLite search database.
- Connected the native UI to subtitle indexing and FTS5 search.
- Added incremental reindexing behavior that skips unchanged subtitle files.
- Added embedded `libmpv` playback integration for local video files.
- Replaced external-window playback behavior with `libmpv` render API playback embedded in the app window.
- Connected search results to playback, including timestamp start behavior and same-video seek handling.
- Reworked the Search flow from split result/detail presentation to a search-results page and a dedicated playback page.
- Added basic playback-page interactions: auto-play on result selection, return-to-search stop behavior, and click-to-toggle play/pause on the video surface.
- Accepted the Playback Inspector workflow to replace default playback-page navigation for search result preview.
- Added a custom native app shell with Search and Settings navigation.
- Moved titlebar controls to AppKit so the sidebar toggle and centered section title align with the native macOS titlebar.
- Updated Search result presentation with a larger custom search field, subtitle-file-name context, and highlighted query matches.
- Refined custom titlebar layout by securely offsetting native traffic light controls, eliminating resize jitter while preserving native hover and click behaviors.
- UI polish remains in progress and is not yet considered final for M1.
