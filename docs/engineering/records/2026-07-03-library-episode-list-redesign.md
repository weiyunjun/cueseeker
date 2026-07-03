# Library Episode List Redesign

## Human-Owned Source

- `docs/human/requirements/20260703-Feature-Library Episode List Redesign.md`
- `docs/human/design/UI.md`

## Scope

Implement the accepted Library second-level episode list redesign in the native
macOS workbench. The change covers the adaptive episode card layout, watch
progress display rules, indexed media metadata needed by the list rows, and the
AI-maintained schema documentation that reflects the new database fields.

## Classification

- Product semantics: Library episode rows expose indexed file size, resolution,
  frame rate, and video codec metadata that already belongs to the media index.
- Platform UI/UX: the Library folder-detail episode grid becomes an adaptive
  horizontal list-card layout with the accepted cover, spacing, typography, and
  primary Play affordance.
- Platform integration: the native metadata inspector reads video stream
  dimensions, frame rate, codec, and duration through the existing FFmpeg-backed
  playback integration.
- Playback execution: unchanged; playback launch behavior and player execution
  stay on the existing path.

## Changes

- Replaced the fixed-width Library episode tile grid with an adaptive 380px
  minimum list-card grid that naturally collapses between two columns and one
  column based on the available content width.
- Updated episode cards to use the accepted 204px by 115px cover, three-line
  detail stack, watch-status badge, metadata row, and text-only primary Play
  label.
- Removed episode-card hover background and pressed scale from the redesigned
  list card while preserving the existing pointer affordance and disabled state.
- Applied the global accepted watch-progress rule: unwatched covers hide the
  progress bar, watching covers show progress only after playback has advanced,
  and finished covers show a complete progress bar.
- Added Library list layout and primary button tokens for the new dimensions,
  spacing, typography, and light/dark Play button colors.
- Added schema version 23 fields for `video_width`, `video_height`, and
  `frame_rate` on `video_files`, with migrations for existing databases.
- Extended the native FFmpeg metadata inspector and playback metadata indexer
  so Library rows can display indexed video size, resolution, frame rate, and
  codec without opening media from the SwiftUI view.
- Updated AI-maintained database and product data-model docs to describe schema
  version 23.

## Verification

- `git diff --check` passed.
- `swift build` passed from `apps/macos-native`.
- `swift test --filter completeLibraryFolderSummariesAndDetailSplitFolderAndEpisodeData`
  passed from `apps/macos-native`.
- `swift test` passed from `apps/macos-native`. XCTest reported 7 passing CASS
  rendering tests, and Swift Testing reported 369 passing tests.

## Outcome

Library folder-detail episodes now render as the accepted responsive list-card
interface. The metadata row is backed by indexed database fields, and the
progress-bar behavior is consistent across Library cover surfaces.

