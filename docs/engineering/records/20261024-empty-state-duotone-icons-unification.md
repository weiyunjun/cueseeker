# 2026-10-24 Empty State Duotone Icons Unification Across Workbench, Dialogs, and Playback

## Covering Human Documentation

- Requirement: `docs/human/requirements/20261024-UI-Empty State Duotone Icons Unification Across Workbench Dialogs And Playback.md`
- Design authorities:
  - `docs/human/design/ui/UI Foundations.md` (`F-01.2 Color Tokens`, `F-02.1 Font Scale & Weights`, `F-03.1 Spacing Scale`, `F-05.1 Icon System`)
  - `docs/human/design/ui/UI Components - Workbench.md` (`C-09.2 Empty State`)
  - `docs/human/design/ui/UI Components - Domain.md` (`C-15.4 Task Panel`, `C-15.8 WebDav / SMB / FTP / NFS Folder Dialog`)
  - `docs/human/design/ui/UI Layouts - Workbench.md` (`L-05.3 Search Page`, `L-06.2 Recent Page`, `L-07.2 Library Page`, `L-08.1 File Page`, `L-09.2 Excerpt Detail Page`)
  - `docs/human/design/ui/UI Layouts - Playback.md` (`L-08 Playback Overlay`, `L-09 Command Panel`)

## Implementation Steps

1. Added empty-state duotone opacity and geometry tokens to `WorkbenchControlMetrics.swift` (`redesignEmptyStateIconSize = 68`, `redesignEmptyStateIconToTextGap = 14`, `redesignEmptyStateTitleToMessageGap = 4`, `redesignEmptyStateTitleFontSize = 15`, `redesignEmptyStateMessageMaxWidth = 380`, and the five duotone layer opacities `0.30`, `0.58`, `0.22`, `0.24`, `0.44`) and exposed dynamic theme-aware color tokens in `WorkbenchRedesignTokens.swift`.
2. Implemented `AppEmptyStateIcon` (10 cases: `.searchHint`, `.searchNoResults`, `.video`, `.excerpt`, `.folder`, `.folderQuestion`, `.videoQuestion`, `.excerptQuestion`, `.subtitleQuestion`, `.taskTray`) and `AppEmptyStateIconView` in `AppIcon.swift` using `256×256` vector shapes and `.blendMode(.destinationOut)` inside `.compositingGroup()` for genuine background knockouts across light and dark appearances.
3. Unified `WorkbenchEmptyHint` in `WorkbenchEmptyHint.swift` to render a top centered `68×68px` `AppEmptyStateIconView`, a `14px` vertical gap, an optional `15px Semibold` `title` (`4px` gap to message), and a centered `14px Regular` `message` (`maxWidth: 380`), while preserving `.allowsHitTesting(false)`.
4. Updated all 22 empty states and boundary invalidation states across `WorkbenchSearchView`, `WorkbenchRecentView`, `WorkbenchLibraryView`, `LibraryMediaCards`, `WorkbenchFileView`, `WorkbenchExcerptTableView`, `WorkbenchWorkspaceView`, `TaskPanel`, `RemoteFolderDialogSharedViews`, `PlaybackSubtitleFocusOverlay`, `PlaybackLibraryOverlay`, and `PlaybackCommandPanel` to use `WorkbenchEmptyHint` centered horizontally and vertically in each container's remaining available space, and removed the obsolete `EmptyStateView.swift`, `LibraryEmptyHint`, and `PlaybackEmptyHint`.
5. Updated and expanded `WorkbenchEmptyHintTests.swift` to verify hit-testing passthrough, design metrics, and all 10 `AppEmptyStateIcon` renderings.

## Verification

- Ran `swift test --package-path apps/macos-native --filter "WorkbenchEmptyHint|AppIconAsset"`.
- Ran `swift test --package-path apps/macos-native --filter "PlaybackLibraryChangeTests|PlaybackSearchOverlayTests|TaskPanelTests"`.

## Outcome

- Result matched expectations: all 22 empty states and invalidation states across Workbench pages, Dialogs, Playback Overlay, and Command Panel now share the unified `WorkbenchEmptyHint` component and system-accent duotone icon set without private empty-state implementations.
