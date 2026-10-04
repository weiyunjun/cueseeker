# Universal File Detail Dialog

Human-owned documents:

- `docs/human/requirements/20261005-UI-Universal File Detail Dialog.md`
- `docs/human/design/UI Design System.md`
- `docs/human/design/UI Application Rules.md`

## Why

1. **Information Accessibility**:
   - Provide a native, unified detail dialog for video and subtitle files from the Level 3 file cards in the File view.
   - Display essential metadata including resolution, frame rate, container and video codecs, bitrate, duration, audio tracks, associated subtitles, encoding, cue count, file size, format, path, and timestamps.

2. **Native macOS UI Alignment & Token Compliance**:
   - Adhere strictly to the Settings-style grouped card specification (`SettingsGroup`) with `--radius-settings-group` (10px) and `--color-settings-group-bg`.
   - Prevent window height overflow by binding the scrollable viewport to `workbenchDialogAvailableSize` so that the dialog stays comfortably centered within the macOS window and never clips off-screen.
   - Standardize typography using system fonts with `.monospacedDigit()` for numerical and timestamp values instead of monospace font families.
   - Maintain 24px visual equal insets on all four sides.

## What changed

1. **Tokens**:
   - In `WorkbenchControls.swift`, defined:
     - `redesignDetailFileIconContainerSize`: 40px
     - `redesignDetailFileIconGlyphSize`: 20px
     - `redesignDetailFileTitleLineHeight`: 20px
     - `redesignDetailLabelMinWidth`: 100px
     - `redesignDetailIndexLabelMinWidth`: 40px
2. **Icons**:
   - Added Phosphor `info` icon SVG asset (`apps/macos-native/Sources/CueSeekerApp/Resources/Icons/info.svg`).
   - Added `case info = "info"` to `AppIcon.swift`.
3. **Database & Data Layer**:
   - In `SubtitleTextDecoder.swift`, added `detectedEncodingName(in:)` for encoding inspection (supporting UTF-8, UTF-8 BOM, UTF-16, and legacy encodings).
   - In `LibraryDatabase+FileDetail.swift`, created `FileDetailVideoInfo` and `FileDetailSubtitleInfo` models and query helpers `fileDetailVideoInfo(for:)` and `fileDetailSubtitleInfo(for:)`.
4. **App Presentation & UI**:
   - In `LibraryStore.swift`, added `@Published var fileDetailSession: FileDetailDialogSession?`.
   - In `AppCoordinator+FileDetail.swift`, implemented `requestVideoDetail(for:)`, `requestSubtitleDetail(for:)`, and `closeFileDetailDialog()`.
   - In `WorkbenchFileView.swift`, added `Get Info` menu item with `.info` icon to Level 3 video and subtitle card action menus.
   - In `WorkbenchFileDetailDialog.swift`, created the dialog view using Settings-style grouped cards, bounded height, system typography, and 24px insets.
   - In `ContentView.swift`, integrated dialog presentation via `.workbenchDialog()` and registered `session.id` in `openDialogIDs`.
   - In `Localizable.strings` (`en`, `zh-Hans`, `zh-Hant`), added full localization keys for file detail.
5. **Tests**:
   - Created `FileDetailDatabaseTests.swift` testing database query resolution and subtitle text encoding detection.
   - Created `FileDetailDialogTests.swift` testing dialog session models, token metrics, and icon resolution.

## Verification

- Automated tests:
  - `swift test --filter FileDetail`: 5/5 tests passed.
  - `swift test --filter AppIconAssetTests`: 5/5 tests passed.
  - `swift test --filter FileCardMenuTests`: 5/5 tests passed.
