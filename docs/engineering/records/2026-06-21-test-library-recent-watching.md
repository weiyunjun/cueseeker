# Test Library Recent Watching

Human requirement:

- `docs/human/requirements/20260621-Feature-Test Library.md`

## Scope

Implemented the first Test Library slice: design tokens/components needed for
Recent Watching and the functional Recent Watching section. Complete Library
folder cards, expansion state, episode lazy loading, and page scroll-state
persistence remain future work.

## Classification

- Product semantics: recent Library watching query, folder-level deduplication,
  five-item limit, and Library-only history source live in `CueSeekerCore` and
  App coordination.
- Platform UI/UX: Test Library Recent Watching cards, cover/progress display,
  hover/pressed/disabled states, status badge colors, and empty hint live in
  SwiftUI.
- Playback execution: card clicks reuse the existing Library playback path and
  resume-position loading.

## Changes

- Added shared redesign color tokens for Watch Status and Library Media.
- Added `RecentLibraryWatchingPresentation` and `recentLibraryWatching(under:)`
  to read persisted Library playback history joined with Library presentation
  rows and generated video covers.
- Kept only the newest video per folder and capped Recent Watching at five
  items.
- Added Recent Watching state to `LibraryStore` and asynchronous loading in
  `AppCoordinator`.
- Recorded a Library-opened video immediately in Library playback history so
  Recent Watching is persisted without waiting for periodic playback saves.
- Added Test Library Recent Watching UI with section title, adaptive grid,
  media card hover/pressed/disabled states, cover progress, time badge, watch
  status badge, and empty hint.
- Added a database test for latest-per-folder ordering and the five-item cap.

## Verification

- `swift test` succeeded after the initial implementation.
- `swift test` succeeded again after preserving existing playback-history
  duration when touching a Recent Watching record.

## Outcome

The implemented slice matches the current requirement: Recent Watching is
persisted through the existing Library playback-history boundary, excludes
Search/Shiori playback sources, deduplicates by folder, displays up to five
items, and opens the selected video through the existing resume-capable Library
playback path.
