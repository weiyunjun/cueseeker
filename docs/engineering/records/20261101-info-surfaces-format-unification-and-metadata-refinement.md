# Info Surfaces Format Unification and Metadata Refinement

- **Date**: 2026-11-01
- **Requirement**: `docs/human/requirements/20261101-UI-Info Surfaces Format Unification And Metadata Refinement.md`
- **Scope**: `File Info` (Video & Subtitle detail dialogs), `Folder Info`, `Task Panel` & `Task Info`, `File` status bar & Level 3 cards, `Excerpt` table, `Settings` (`Maintenance` & `Developer`), and `Player UI` (`More -> Audio Track` menu)

## Summary

1. **Global Number, Unit, Timestamp, and Separator Unification (`FileSizeFormatter`, `MediaDetailFormatter`, `FileStatusResolver`, `SubtitleTableRowModelStore`, `SettingsMaintenanceCategory`, `SettingsDeveloperCategory`, `TaskQueueStore`, `TaskPanel`)**:
   - Removed thousand separators across all count and parameter formatters (`MediaDetailFormatter`, `SettingsDeveloperCategory`, and `%lld` format strings in `Localizable.strings` for `library.folder_summary`).
   - Switched `FileSizeFormatter` to a `1000` decimal base with 2 decimal places (`KB`, `MB`, `GB`, `TB`, and `< 1000 B` as `N B`), and unified `Settings -> Maintenance` storage sizes and reclaimed space toast notifications onto `FileSizeFormatter.format(bytes:)`.
   - Standardized timestamps across `FileStatusResolver` (`Last Updated` in `File` status bar), `SubtitleTableRowModelStore` (`Date Added` column in `Excerpt` table), and `SettingsDeveloperCategory` (vocabulary `Updated` timestamp) to `yyyy-MM-dd HH:mm:ss`, matching `MediaDetailFormatter.dateText(_:)` in detail dialogs and `Task Panel` history cards.
   - Updated `MediaDetailFormatter.durationText(_:)` to omit the hours field when `< 1 hour` (`mm:ss`) and preserve `HH:mm:ss` when `>= 1 hour`.
   - Replaced the `" · "` separator in `TaskIndexProgress.label` with two spaces (`"  "`), and unified the never-indexed placeholder in `file.status.last_indexed_never` / `file.status.last_updated_never` to `"-"`.
   - Applied `RemoteAddressParser.decodedDisplayAddress(_:)` to `Path` rows in `WorkbenchFileDetailDialog` (`Video` & `Subtitle`) and all path/folder fields in `TaskDetailDialog` (`Location`, `Path`, `Original Path`, `New Path`, `Target Folders`).
2. **File Detail & Playback Audio Track Metadata Refinement (`LibraryDatabase+FileDetail`, `WorkbenchFileDetailDialog`, `PlaybackChromeMoreMenu`)**:
   - Moved `Bitrate` from the `Video` section to the bottom `File Details` section directly below `File Size`, and formatted values `>= 1000 kbps` as `Mbps` (up to 2 decimal places, trimming trailing zeros) and `< 1000 kbps` as integer `kbps`.
   - Updated `MediaDetailFormatter.frameRateText(_:)` to trim trailing fraction zeros up to 3 decimal places, and `sampleRateText(_:)` to format in `kHz` (up to 2 decimal places, trimming trailing zeros).
   - Simplified `MediaDetailFormatter.pixelFormatText(_:)` to map raw FFmpeg pixel formats to human-readable chroma subsampling/color descriptions (`YUV 4:2:0`, `YUV 4:2:2`, `YUV 4:4:4`, `RGB`, `Grayscale`).
   - Added `MediaDetailFormatter.audioCodecText(_:)` (mapping `flac` -> `FLAC`, `aac` -> `AAC`, `opus` -> `Opus`, `pcm*` -> `PCM`, `ac3` -> `AC-3`, `eac3` -> `E-AC-3`, `truehd` -> `TrueHD`, `dts*` -> `DTS`, `vorbis` -> `Vorbis`, `mp3` -> `MP3`, `alac` -> `ALAC`, etc.) and shared it between `WorkbenchFileDetailDialog` (`Audio #N`) and `PlaybackAudioTrackName` (`More -> Audio Track` menu).
   - Localized `MediaDetailFormatter.channelsText(_:locale:)` (`Mono (1.0)` / `单声道 (1.0)` / `單聲道 (1.0)`, `Stereo (2.0)` / `立体声 (2.0)` / `立體聲 (2.0)`, `Surround (5.1)` / `环绕声 (5.1)` / `環繞聲 (5.1)`, `Surround (7.1)` / `环绕声 (7.1)` / `環繞聲 (7.1)`).
   - Removed the `Created` row from the bottom `File Details` section of both Video and Subtitle detail dialogs, keeping only `Modified`.
3. **Folder Info `Folder Count` & Trilingual Copy Unification (`LibraryDatabase+FileDetail`, `AppCoordinator+FileDetail`, `Localizable.strings`)**:
   - Fixed `LibraryDatabase.fileDetailFolderInfo`: root folders (`isRootFolder == true`) exclude the root folder path itself when counting distinct child folders containing active paired media, and subfolders (`isRootFolder == false`) always report `folderCount = 0`.
   - Updated `en`, `zh-Hans`, and `zh-Hant` `Localizable.strings` for `file_detail.subtitles` (`Associated Subtitles` / `关联字幕` / `關聯字幕`), `file_detail.associated_video` (`Associated Video` / `关联视频` / `關聯影片`), `file_detail.raw_lines` (`Raw Cues` / `原始台词数` / `原始台詞數`), `file_detail.valid_lines` (`Valid Cues` / `有效台词数` / `有效台詞數`), `task_detail.indexed_subtitles` (`Subtitle Count` / `字幕数量` / `字幕數量`), and `task.title.rename_folder` / `task.title.rename_files` (`Rename Folder: ` / `Rename Files: `).
4. **Verification**:
   - Updated and verified `FileSizeFormatterTests`, `FileDetailDatabaseTests`, `FileDetailDialogTests`, `TaskQueueStoreTests`, `PlaybackMoreMenuTests`, `TableSandboxRowModelStoreTests`, and `FileRouteNavigationTests`.
