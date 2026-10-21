# 2026-10-21 File And Task Card Accent Duotone Icons And Folder Minus Icon

## Requirement Reference
- `docs/human/requirements/20261021-UI-File And Task Card Accent Duotone Icons And Folder Minus Icon.md`

## Summary of Changes
1. **Borderless System Accent Duotone Card & Detail Icons (`32%` Scheme)**:
   - Added global opacity tokens (`redesignCardIconAccentBaseOpacity = 0.32`, `redesignCardIconAccentFolderTabOpacity = 0.52`, `redesignCardIconAccentAnkiLineOpacity = 0.59`, `redesignCardIconAccentForegroundOpacity = 1.0`) in `WorkbenchControlMetrics` and global color tokens (`cardIconAccentBase`, `cardIconAccentFolderTab`, `cardIconAccentAnkiLine`, `cardIconAccentForeground`) in `WorkbenchRedesignColors`, and removed the obsolete `20px` inner glyph size tokens (`redesignCardIconGlyphSize`, `redesignDetailFileIconGlyphSize`, `redesignSizeTaskCardIcon`).
   - Added `AppAccentDuotoneIconView` in `AppIcon.swift` to render all 12 borderless system-accent duotone large icons using the global color tokens across `32%` base background, `52%` folder top-left half-width tab, `59%` Anki flashcard lines, and `100%` solid foreground layers.
   - Updated `WorkbenchCardIcon` (`36×36px` by default) to render `AppAccentDuotoneIconView` without the previous grey rounded container box (`WorkbenchRedesignColors.bgHover`), covering `File` page folder/video/subtitle cards, remote folder browser dialog Step 2 directory list cards (`WebDAV` / `SMB` / `FTP` / `NFS`), and `Task` panel cards.
   - Updated `WorkbenchFileDetailDialog` (`File Info`) header row to render `WorkbenchCardIcon` at `40×40px` (`WorkbenchControlMetrics.redesignDetailFileIconContainerSize`).
2. **12 Large Icons & Linear Stroke Icon Adjustments**:
   - Added `folder-minus.svg` stroke master and `AppIcon.folderMinus`.
   - Updated `TaskRecord.icon` for `.removeFolder` to `.folderMinus` (while keeping `TaskPanel` `Remove Task` menu item as `.minusCircle`).
   - Updated `WorkbenchFileView` root folder card menu item `Remove This Folder` from `.minusCircle` to `.folderMinus`.
   - Updated `folder-webdav.svg` and `AppIcon.folderWebdav.folderProtocolBadge` from `"WebDav"` to `"DAV"` so both the `Add Folder -> WebDav Folder` linear menu icon and the WebDav folder card icon display `DAV`.

## Verification
- Verified unit tests in `AppIconAssetTests`, `FileRouteNavigationTests`, `FileCardMenuTests`, `TaskQueueStoreTests`, and `FileDetailDialogTests`.
