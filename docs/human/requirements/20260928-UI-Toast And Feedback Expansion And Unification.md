# 版本

main

# 关联设计

- `docs/human/design/UI Design System.md`（Toast、Playback Feedback、Toast Layout、Feedback）
- `docs/human/design/Toast Usage Registry.md`
- `docs/human/design/Icon Registry.md`

# 需求描述

## 1. 目标

全面补全 Workbench 表格的轻提示（Toast），统一 Workbench Toast 与 Playback Feedback 的停留持续时间、文案标点、图标语义及边界拦截处理，使两者的提示规范化、参数化并在设计文档中闭环。

## 2. 持续时间（Stay Duration）分档规则

所有 Toast 与 Feedback 的显示停留时间（不含 160ms 进出场动效）实行显式参数化，按场景分为三档：

1. **轻提示档（1.5 秒）**：
   - 适用于所有成功的瞬态操作反馈（Workbench 表格行与多选复制、摘录保存/移动/复制成功、Playback Overlay 复制与截图等）。
2. **报错与警示拦截档（3 秒）**：
   - 适用于所有失败、冲突已存在、目标失效、不可用或操作被拦截的场景，保证充足的阅读时间。
3. **播放器常规 HUD 档（1 秒）**：
   - 适用于视频播放过程中的高频控制（播放/暂停、快进快退松手后、音量、倍速、字幕开关、全屏、播放列表切换与边界提示）。

## 3. 文案与标点规范

1. **末尾不加句号**：所有 Toast 与 Feedback 文案（含英文与中文本地化）一律不得包含末尾句号。历史文档及代码中的 `Couldn’t save to “{List Name}”.` 等全部去除末尾句号。
2. **补全主语**：库内容被移除后的拦截文案统一补全主语，由 `Not in Library` 改为 `Cue Not in Library`。
3. **播放列表无可用项文案统一**：播放列表中所有项目失效不可用时，不再区分来源是 Search 还是 Excerpt，统一使用 `No Available Results`（取消 `No Available Excerpts`）。

## 4. 图标语义规范

1. **报错与警示统一**：所有失败、失效、已存在、不可用及拦截提示，统一使用 `warning` 图标（包括 Excerpt 失败分支、`Cue Not in Library`、`No Subtitle`、`Copy Failed`、`Collage Not Ready` 等）。
2. **成功与功能性操作**：使用对应的业务图标（复制类使用 `copy`，截图使用 `camera`，摘录成功使用 `bookmarkSimple` 实心等）。

## 5. Workbench 交互补全

1. **表格行菜单（Row Action Menu）4 个 Copy 按钮**：
   - `Copy Cue Text`：图标 `copy`，文案 `Cue Text Copied`，持续时间 1.5 秒。
   - `Copy Deep Link`：图标 `copy`，文案 `Deep Link Copied`，持续时间 1.5 秒。
   - `Copy Cue Group Text`：图标 `copy`，文案 `Cue Group Text Copied`，持续时间 1.5 秒。
   - `Copy Time Range`：图标 `copy`，文案 `Time Range Copied`，持续时间 1.5 秒。
2. **表格多选状态栏（Selection Action Overlay）2 个 Copy 按钮**：
   - `Copy Deep Links`（快捷键 D）：图标 `copy`，文案 `Deep Links Copied`，持续时间 1.5 秒。
   - `Copy Table`（快捷键 T）：图标 `copy`，文案 `Table Copied`，持续时间 1.5 秒。
3. **Workbench 库移除边界拦截**：
   - 当某行所属文件夹已从库中移除，用户在表格行菜单点击 `Copy Deep Link` 或 `Save to Excerpt` 时，予以拦截并弹出 Toast：图标 `warning`，文案 `Cue Not in Library`，持续时间 3 秒。

## 6. 完整场景与注册表映射

| 分类 | Scenario ID / Action | 文案 | 图标 | 持续时间 |
| :--- | :--- | :--- | :--- | :--- |
| **轻提示** | `table.row.copy_cue_text` | `Cue Text Copied` | `copy` | 1.5s |
| **轻提示** | `table.row.copy_deep_link` | `Deep Link Copied` | `copy` | 1.5s |
| **轻提示** | `table.row.copy_cue_group_text` | `Cue Group Text Copied` | `copy` | 1.5s |
| **轻提示** | `table.row.copy_time_range` | `Time Range Copied` | `copy` | 1.5s |
| **轻提示** | `table.selection.copy_deep_links` | `Deep Links Copied` | `copy` | 1.5s |
| **轻提示** | `table.selection.copy_table` | `Table Copied` | `copy` | 1.5s |
| **轻提示** | `playback.feedback.selected_text_copied` | `Selected Text Copied` | `copy` | 1.5s |
| **轻提示** | `playback.feedback.screenshot_copied` | `Screenshot Copied` | `camera` | 1.5s |
| **轻提示** | `excerpt.save.succeeded` | `Saved to “{List Name}”` | `bookmarkSimple` (fill) | 1.5s |
| **轻提示** | `excerpt.move.succeeded` | `Moved to “{List Name}”` | `bookmarkSimple` (fill) | 1.5s |
| **轻提示** | `excerpt.duplicate.succeeded` | `Duplicated to “{List Name}”` | `bookmarkSimple` (fill) | 1.5s |
| **轻提示** | `playback.feedback.excerpt_removed` *(备查)* | `Excerpt Removed` | `bookmarkSimple` | 1.5s |
| **报错/警示** | `excerpt.destination.unavailable` | `“{List Name}” is no longer available` | `warning` | 3s |
| **报错/警示** | `excerpt.destination.cue.already_exists` | `This excerpt already exists in “{List Name}”` | `warning` | 3s |
| **报错/警示** | `excerpt.save.failed` | `Couldn’t save to “{List Name}”` | `warning` | 3s |
| **报错/警示** | `excerpt.move.failed` | `Couldn’t move the excerpt` | `warning` | 3s |
| **报错/警示** | `excerpt.duplicate.failed` | `Couldn’t duplicate the excerpt` | `warning` | 3s |
| **报错/警示** | `cue_not_in_library` *(Workbench与Playback)* | `Cue Not in Library` | `warning` | 3s |
| **报错/警示** | `playback.feedback.no_subtitle` | `No Subtitle` | `warning` | 3s |
| **报错/警示** | `playback.feedback.copy_failed` | `Copy Failed` | `warning` | 3s |
| **报错/警示** | `playback.feedback.collage_not_ready` | `Collage Not Ready` | `warning` | 3s |
| **常规 HUD** | `playback.hud.play_pause` | `Play` / `Pause` | `play` / `pause` (fill) | 1s |
| **常规 HUD** | `playback.hud.auto_pause` | `Auto Pause` | `pause` (fill) | 1s |
| **常规 HUD** | `playback.hud.seek` | `+ {N}s` / `- {N}s` | `caretRight` / `caretLeft` | 1s (松手后) |
| **常规 HUD** | `playback.hud.repeat` | `Repeat` | `repeat` | 1s |
| **常规 HUD** | `playback.hud.volume` | `{volume}%` / `Muted` | `speaker*` | 1s |
| **常规 HUD** | `playback.hud.speed` | `{speed}x` | `speedometer` | 1s |
| **常规 HUD** | `playback.hud.subtitles` | `Subtitles On` / `Subtitles Off` | `subtitles` | 1s |
| **常规 HUD** | `playback.hud.fullscreen` | `Enter Fullscreen` / `Exit Fullscreen` | 无 | 1s |
| **常规 HUD** | `playback.hud.navigation` | `Previous/Next Result` 等 | `caret*` | 1s |
| **常规 HUD** | `playback.hud.navigation_edge` | `Already at First/Last...` | `caret*` | 1s |
| **常规 HUD** | `playback.hud.no_available_results` | `No Available Results` | `warning` / `caret*` | 1s |
| **常规 HUD** | `playback.hud.no_available_videos` | `No Available Videos` | `warning` / `caret*` | 1s |

## 7. 本地化（i18n）增改对照

| 键名 | 英文 (en) | 简体中文 (zh-Hans) | 繁体中文 (zh-Hant) |
| :--- | :--- | :--- | :--- |
| `toast.table.cue_text_copied` | `Cue Text Copied` | `已复制台词` | `已拷貝台詞` |
| `toast.table.deep_link_copied` | `Deep Link Copied` | `已复制 Deep Link` | `已拷貝 Deep Link` |
| `toast.table.cue_group_text_copied` | `Cue Group Text Copied` | `已复制台词组文本` | `已拷貝台詞組文字` |
| `toast.table.time_range_copied` | `Time Range Copied` | `已复制时间范围` | `已拷貝時間範圍` |
| `toast.table.deep_links_copied` | `Deep Links Copied` | `已复制 Deep Link` | `已拷貝 Deep Link` |
| `toast.table.table_copied` | `Table Copied` | `已复制表格` | `已拷貝表格` |
| `toast.cue_not_in_library` / `playback.hud.not_in_library` | `Cue Not in Library` | `台词不在媒体库中` | `台詞不在資料庫中` |
| `toast.excerpt.move_failed` | `Couldn’t move the excerpt` | `移动摘录出错` | `移動摘錄時發生錯誤` |
| `toast.excerpt.save_failed` | `Couldn’t save to “%@”` | `保存到“%@”出错` | `儲存至「%@」時發生錯誤` |
| `toast.excerpt.duplicate_failed` | `Couldn’t duplicate the excerpt` | `复制摘录出错` | `複製摘錄時發生錯誤` |

## 8. 设计文档同步

验收通过后，同步更新：
1. `docs/human/design/Toast Usage Registry.md`：
   - 补入表格复制场景及 `Cue Not in Library`。
   - 所有条目显式标注 `持续时间`（1.5 秒 或 3 秒）。
   - 报错类条目的图标由 `bookmarkSimple` 改为 `warning`。
   - 移除所有文案末尾句号。
2. `docs/human/design/UI Design System.md`：
   - Toast 与 Playback Feedback 的 Presentation Inputs 章节明确持续时间参数及默认分档规则。

# 验收

1. **Workbench 表格行复制**：
   - 依次点击表格行菜单的 4 个 Copy 按钮，屏幕正中弹出对应的深色胶囊 Toast，带 `copy` 图标，文案无句号，停留 1.5 秒后自动淡出消失。
2. **Workbench 表格多选复制**：
   - 进入多选模式，分别点击顶栏 `Copy Deep Links`（或按 D）与 `Copy Table`（或按 T），屏幕正中弹出对应 Toast，停留 1.5 秒后消失。
3. **移除文件夹边界拦截**：
   - 移除文件夹后，在表格行菜单点击 `Copy Deep Link` 或 `Save to Excerpt`，弹出 `warning` 图标的 `Cue Not in Library`，停留 3 秒后消失。
   - 播放已移除项时，在 Overlay 中尝试保存或复制，弹出 `warning` 图标的 `Cue Not in Library`，停留 3 秒后消失。
4. **报错与异常 Toast**：
   - 触发 Excerpt 失败、失效或已存在时，Toast 均带有 `warning` 图标，文案无末尾句号，停留 3 秒后消失。
5. **Playback HUD 与 Overlay 持续时间**：
   - 播放器常规 HUD（播放/暂停、音量、倍速、快进快退松手后）显示 1 秒。
   - Overlay 复制类反馈显示 1.5 秒；Overlay 报错（如 `No Subtitle`）显示 3 秒。
6. **国际化与测试**：
   - 英文、简体中文、繁体中文文案均无末尾句号，无截断无换行溢出。
   - 现有自动化单元测试与集成测试全部通过，无构建与静态检查警告。