# Implementation Record: Simplified and Traditional Chinese Translation Refinement and Unification

Date: 2026-10-24
Requirement: `docs/human/requirements/20261024-UI-Simplified And Traditional Chinese Translation Refinement And Unification.md`
Design References:
- `docs/human/design/ui/UI Index.md`
- `docs/human/design/ui/UI Design Rules.md`
- `docs/human/design/ui/UI Interaction Rules.md`
- `docs/human/design/ui/Toast Usage Registry.md`
- `docs/human/design/ui/Tooltip Usage Registry.md`
- `docs/human/design/ui/UI Layouts - Workbench.md`

## 1. Implementation Steps

1. Updated `apps/macos-native/Sources/CueSeekerApp/Resources/en.lproj/Localizable.strings`, `zh-Hans.lproj/Localizable.strings`, and `zh-Hant.lproj/Localizable.strings`:
   - Fixed the `table.column.cues` column header in Simplified and Traditional Chinese from `台词数` / `台詞數` to `台词` / `台詞`.
   - Fixed singular format placeholder bugs in `.one` localization keys (`library.folder_count.one`, `excerpt.list_count.one`, `excerpt.cue_count.one`) where `L(...)` is called without variadic arguments, and unified Excerpt overview summary terminology to `摘录集 / 摘錄集` and `台词 / 台詞`.
   - Unified cross-module terminology across Simplified and Traditional Chinese (`摘录集 / 摘錄集`, `不在媒体库中 / 不在媒體庫中`, `排队中 / 排隊中`, `进行中 / 進行中`, `音轨 / 音軌`, `默认音轨 / 預設音軌`, `已复制台词文本 / 已拷貝台詞文字`, `已复制 Deep Links / 已拷貝 Deep Links`, `时长 / 時長`, `文件名 / 檔案名稱`, `退出 / 退出全螢幕 / 退出長截圖`, `返回工作台`, `上一部影片 / 下一部影片`, `已经是第一条结果 / 已经是最后一条结果`, and `还没有最近观看的视频。 / 尚無最近觀看的影片。`).
   - Added dedicated `file_detail.associated_video` key (`Video` / `关联视频` / `關聯影片`) for the subtitle detail dialog's associated video group title, keeping `file_detail.video` (`Video` / `视频` / `影片`) for the video detail dialog's video specs group.
   - Added `playback.hud.seek_forward` (`+ %ds` / `+ %d秒` / `+ %d秒`) and `playback.hud.seek_backward` (`- %ds` / `- %d秒` / `- %d秒`) for localized seek HUD feedback.
   - Standardized punctuation and casing across all locales (`file.status.*` full-width colon `：` in Chinese, `⋯` in `playback.collage.editing` for `zh-Hant`, and `WebDAV` casing in `file.add_folder.webdav` and `webdav.dialog.title`).
2. Updated `apps/macos-native/Sources/CueSeekerApp/Playback/PlaybackViewModel.swift` to format seek HUD feedback via `L("playback.hud.seek_forward", ...)` and `L("playback.hud.seek_backward", ...)`.
3. Updated `apps/macos-native/Sources/CueSeekerApp/Library/WorkbenchFileDetailDialog.swift` to use `L("file_detail.associated_video")` in `subtitleContent(_:)`.
4. Updated unit tests in `apps/macos-native/Tests/CueSeekerAppTests/TaskCardMenuTests.swift` and added comprehensive localization verification tests in `apps/macos-native/Tests/CueSeekerAppTests/AppLocalizationTests.swift`.

## 2. Verification

- Executed `swift test --filter AppLocalizationTests`, `swift test --filter TaskCardMenuTests`, and `swift test --filter FileDetailDialogTests` in `apps/macos-native`.
- Verified all 6 tests in `AppLocalizationTests` (including key parity across `en`, `zh-Hans`, `zh-Hant`, absence of `%d` in `.one` keys, and exact values of all refined translations), 9 tests in `TaskCardMenuTests`, and 6 tests in `FileDetailDialogTests` passed with 0 failures.

## 3. Outcome

All localization errors, singular placeholder bugs, hardcoded seek HUD units, and terminology/punctuation inconsistencies specified in the requirement document are resolved and verified.
