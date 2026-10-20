# Tooltip 调用场景注册表 (Tooltip Usage Registry)

## 规范总则

1. **悬停触发延迟（Hover Delay）**：
   - 默认统一为 **1秒（`1s`）**，即指针移入目标热区并保持在目标内满 1 秒后展示 Tooltip。
   - 已展示的 Tooltip 处于显示期间，或因指针移出隐藏后的 **`0.3s`（`--delay-tooltip-skip-window`）** 内移入其他目标热区时，跳过等待立即展示；因点击、滚轮、按键、打开菜单或对话框被动隐藏时重置该时间窗。
   - 各场景均显式标注 `触发延迟`，后续可按具体交互高频度单独微调。
2. **标点规范**：所有 Tooltip 文案（含英、简、繁）末尾**一律不加句号**。
3. **快捷键动态跟随规则**：
   - 绑定了快捷键的纯图标按钮，在可用（Enabled）状态下，Tooltip 同时展示**功能名称**与**当前快捷键**。
   - 本文档各词条中标注的快捷键（如 `Space`、`A`、`D`、`Q`、`R`、`P`、`F` 等）均为**默认键位说明**。
   - 实际运行时，凡属于 `Settings / Shortcuts` 可配置的快捷键，**必须动态读取当前生效键位（Effective Key）**：
     - 用户改键后，Tooltip 同步展示修改后的键位；
     - 用户清空该快捷键（Empty）或该键位处于冲突失效状态（Conflict）时，**不显示快捷键部分，仅显示功能文案**；
     - 不可修改的固定快捷键（如打开设置的 `⌘,`、关闭/退出的 `Esc`）恒定显示。
4. **禁用态（Disabled）展示规则与排除范围**：
   - 当按钮处于 `Disabled` 状态时，悬停达到触发延迟后展示对应的**禁用原因 Tooltip**。
   - 若按钮本身在正常态下有功能 Tooltip（如 `Back`、`Previous`、`Restore Default Shortcut`），进入 `Disabled` 态后统一切换为展示**禁用原因文案**（不再附带快捷键）。
   - **所有菜单触发按钮（`More` 按钮）及菜单项（Menu Items，含正常态与禁用态）均不展示 Tooltip**。
5. **截断文本（Truncated Text）触发规则**：
   - 仅当文本因容器宽度限制**实际发生省略（`...`）**时，悬停才触发 Tooltip 展示完整文本；文本完整可见时不触发。

---

## 一、顶栏与导航纯图标控件（Topbar & Navigation Icon Tooltips）

### 1. 侧边栏展开 / 收起（Sidebar Toggle）
- 英文（展开态下悬停）：Hide Sidebar
- 英文（收起态下悬停）：Show Sidebar
- 简体中文（展开态下悬停）：隐藏边栏
- 简体中文（收起态下悬停）：显示边栏
- 繁体中文（展开态下悬停）：隱藏側邊欄
- 繁体中文（收起态下悬停）：顯示側邊欄
- 快捷键：无
- 触发延迟：1秒
- Scenario ID：topbar.sidebar.toggle
- 所在位置：App Topbar

### 2. 顶栏后退（Back Action）
- 英文（可用）：Back
- 简体中文（可用）：后退
- 繁体中文（可用）：後退
- 英文（Disabled - 已在历史起点）：No previous page
- 简体中文（Disabled - 已在历史起点）：没有可后退的页面
- 繁体中文（Disabled - 已在历史起点）：沒有可後退的頁面
- 快捷键：无
- 触发延迟：1秒
- Scenario ID：topbar.navigation.back
- 所在位置：App Topbar

### 3. 顶栏前进（Forward Action）
- 英文（可用）：Forward
- 简体中文（可用）：前进
- 繁体中文（可用）：前進
- 英文（Disabled - 已在历史终点）：No next page
- 简体中文（Disabled - 已在历史终点）：没有可前进的页面
- 繁体中文（Disabled - 已在历史终点）：沒有可前進的頁面
- 快捷键：无
- 触发延迟：1秒
- Scenario ID：topbar.navigation.forward
- 所在位置：App Topbar

### 4. 任务面板入口（Task Entry）
- 英文：Tasks
- 简体中文：任务
- 繁体中文：任務
- 快捷键：无
- 触发延迟：1秒
- Scenario ID：topbar.entry.tasks
- 所在位置：App Topbar / Player Topbar / Playback Overlay Topbar

### 5. 设置入口（Settings Entry）
- 英文：Settings
- 简体中文：设置
- 繁体中文：設定
- 快捷键：`⌘,`（系统固定快捷键）
- 触发延迟：1秒
- Scenario ID：topbar.entry.settings
- 所在位置：App Topbar / Player Topbar / Playback Overlay Topbar

### 6. 播放页返回工作台（Player Return Action）
- 英文：Return to Workbench
- 简体中文：返回到工作台
- 繁体中文：返回到工作台
- 快捷键：无
- 触发延迟：1秒
- Scenario ID：player.topbar.return
- 所在位置：Player Topbar

### 7. 播放覆盖层返回工作台（Playback Overlay Return Action）
- 英文：Return to Workbench
- 简体中文：返回到工作台
- 繁体中文：返回到工作台
- 快捷键：无
- 触发延迟：1秒
- Scenario ID：playback_overlay.topbar.return
- 所在位置：Playback Overlay Topbar

### 8. 长截图编辑模式开关（Collage Action）
- 英文（未开启时）：Edit Collage
- 英文（编辑中 Open 态）：Exit Collage
- 简体中文（未开启时）：编辑长截图
- 简体中文（编辑中 Open 态）：退出长截图
- 繁体中文（未开启时）：編輯長截圖
- 繁体中文（编辑中 Open 态）：結束長截圖
- 快捷键：默认 `P`（动态跟随 `Settings / Shortcuts -> Edit Collage`）
- 触发延迟：1秒
- Scenario ID：playback_overlay.topbar.collage
- 所在位置：Playback Overlay Topbar（仅 Current 模块可见）

### 9. 命令面板二级页返回上一级（Command Panel Back Action）
- 英文：Back
- 简体中文：返回上一级
- 繁体中文：返回上一級
- 快捷键：`Esc`（固定键位）
- 触发延迟：1秒
- Scenario ID：command_panel.header.back
- 所在位置：Command Panel Secondary Header（Subtitles / Audio Track / Speed）

---

## 二、播放器底栏控制区（Player Bottom Control Bar Tooltips）

> **说明**：以下词条标注的快捷键均为默认键位，实际展示时动态跟随 `Settings / Shortcuts` 中的用户配置；若快捷键被清空或冲突失效，则仅显示功能名称。

### 10. 播放 / 暂停（Play / Pause）
- 英文（暂停中）：Play
- 英文（播放中）：Pause
- 简体中文（暂停中）：播放
- 简体中文（播放中）：暂停
- 繁体中文（暂停中）：播放
- 繁体中文（播放中）：暫停
- 快捷键：默认 `Space`（动态跟随 `Settings / Shortcuts -> Play / Pause`）
- 触发延迟：1秒
- Scenario ID：player.control.play_pause
- 所在位置：Player Bottom Control Bar

### 11. 上一条台词 / 上一个视频（Previous）
- **台词播放列表（Search / Excerpt 进入）**：
  - 英文（可用）：Previous Cue
  - 简体中文（可用）：上一条台词
  - 繁体中文（可用）：上一條台詞
  - 英文（Disabled - 已在首项或无可用项）：Already at first cue
  - 简体中文（Disabled - 已在首项或无可用项）：已经是第一条台词
  - 繁体中文（Disabled - 已在首项或无可用项）：已經是第一條台詞
- **视频播放列表（Library 进入）**：
  - 英文（可用）：Previous Video
  - 简体中文（可用）：上一个视频
  - 繁体中文（可用）：上一個影片
  - 英文（Disabled - 已在首项或无可用项）：Already at first video
  - 简体中文（Disabled - 已在首项或无可用项）：已经是第一个视频
  - 繁体中文（Disabled - 已在首项或无可用项）：已經是第一個影片
- 快捷键（可用）：默认 `A`（动态跟随 `Settings / Shortcuts -> Previous`）
- 触发延迟：1秒
- Scenario ID：player.control.previous
- 所在位置：Player Bottom Control Bar

### 12. 下一条台词 / 下一个视频（Next）
- **台词播放列表（Search / Excerpt 进入）**：
  - 英文（可用）：Next Cue
  - 简体中文（可用）：下一条台词
  - 繁体中文（可用）：下一條台詞
  - 英文（Disabled - 已在末项或无可用项）：Already at last cue
  - 简体中文（Disabled - 已在末项或无可用项）：已经是最后一条台词
  - 繁体中文（Disabled - 已在末项或无可用项）：已經是最後一條台詞
- **视频播放列表（Library 进入）**：
  - 英文（可用）：Next Video
  - 简体中文（可用）：下一个视频
  - 繁体中文（可用）：下一個影片
  - 英文（Disabled - 已在末项或无可用项）：Already at last video
  - 简体中文（Disabled - 已在末项或无可用项）：已经是最后一个视频
  - 繁体中文（Disabled - 已在末项或无可用项）：已經是最後一個影片
- 快捷键（可用）：默认 `D`（动态跟随 `Settings / Shortcuts -> Next`）
- 触发延迟：1秒
- Scenario ID：player.control.next
- 所在位置：Player Bottom Control Bar

### 13. 静音 / 取消静音（Volume Button）
- 英文（有声态）：Mute
- 英文（静音态）：Unmute
- 简体中文（有声态）：静音
- 简体中文（静音态）：取消静音
- 繁体中文（有声态）：靜音
- 繁体中文（静音态）：取消靜音
- 快捷键：无
- 触发延迟：1秒
- Scenario ID：player.control.mute
- 所在位置：Player Bottom Control Bar

### 14. 重播当前台词（Replay Current Cue）
- 英文（可用）：Replay Current Cue
- 简体中文（可用）：重播当前台词
- 繁体中文（可用）：重播目前台詞
- 快捷键（可用）：默认 `R`（动态跟随 `Settings / Shortcuts -> Replay Current Cue`）
- 英文（Disabled - 当前无激活台词）：No active cue to replay
- 简体中文（Disabled - 当前无激活台词）：当前没有可重播的台词
- 繁体中文（Disabled - 当前无激活台词）：目前沒有可重播的台詞
- 触发延迟：1秒
- Scenario ID：player.control.repeat
- 所在位置：Player Bottom Control Bar
- 交互说明：触发该操作时**不弹出 Toast / HUD 提示**

### 15. 复制当前截图（Copy Current Screenshot）
- 英文：Copy Current Screenshot
- 简体中文：复制当前截图
- 繁体中文：拷貝目前截圖
- 快捷键：默认 `P`（动态跟随 `Settings / Shortcuts -> Copy Screenshot`）
- 触发延迟：1秒
- Scenario ID：player.control.copy_screenshot
- 所在位置：Player Bottom Control Bar

### 16. 字幕开关（Toggle Subtitles）
- 英文（字幕关闭时）：Show Subtitles
- 英文（字幕开启时）：Hide Subtitles
- 简体中文（字幕关闭时）：开启字幕
- 简体中文（字幕开启时）：关闭字幕
- 繁体中文（字幕关闭时）：開啟字幕
- 繁体中文（字幕开启时）：關閉字幕
- 快捷键：默认 `Q`（动态跟随 `Settings / Shortcuts -> Toggle Subtitles`）
- 触发延迟：1秒
- Scenario ID：player.control.subtitles
- 所在位置：Player Bottom Control Bar

### 17. 播放倍速（Playback Speed）
- 英文：Playback Speed
- 简体中文：播放速度
- 繁体中文：播放速度
- 快捷键：无
- 触发延迟：1秒
- Scenario ID：player.control.speed
- 所在位置：Player Bottom Control Bar

### 18. 全屏切换（Fullscreen Toggle）
- 英文（未全屏时）：Enter Fullscreen
- 英文（已全屏时）：Exit Fullscreen
- 简体中文（未全屏时）：进入全屏
- 简体中文（已全屏时）：退出全屏
- 繁体中文（未全屏时）：進入全螢幕
- 繁体中文（已全屏时）：結束全螢幕
- 快捷键：默认 `F`（动态跟随 `Settings / Shortcuts -> Toggle Fullscreen`）
- 英文（Disabled）：Fullscreen is currently unavailable
- 简体中文（Disabled）：当前无法切换全屏
- 繁体中文（Disabled）：目前無法切換全螢幕
- 触发延迟：1秒
- Scenario ID：player.control.fullscreen
- 所在位置：Player Bottom Control Bar

---

## 三、通用输入、对话框与设置纯图标按钮（Inputs, Dialogs & Settings Icon Tooltips）

### 19. 对话框关闭按钮（Dialog Close Button）
- 英文：Close
- 简体中文：关闭
- 繁体中文：關閉
- 快捷键：`Esc`（固定键位）
- 触发延迟：1秒
- Scenario ID：dialog.header.close
- 所在位置：Edit Cover / Excerpt List Editor / Rename / WebDAV Folder / SMB Folder / FTP Folder / NFS Folder / Export to Anki / Filter / File Info / Confirmation / Task Panel 右上角 `X` 按钮

### 20. 搜索框清空按钮（Search Field Clear Button）
- 英文：Clear Input
- 简体中文：清除已输入内容
- 繁体中文：清除已輸入內容
- 快捷键：无
- 触发延迟：1秒
- Scenario ID：input.search.clear
- 所在位置：Search / Excerpt Toolbar 搜索框、Command Panel 搜索框

### 21. 快捷键录入清空按钮（Shortcut Field Inline Clear）
- 英文：Clear Shortcut
- 简体中文：清除快捷键
- 繁体中文：清除快速鍵
- 快捷键：无
- 触发延迟：1秒
- Scenario ID：input.shortcut.clear
- 所在位置：Settings -> Shortcuts（Recording 状态下右侧 `✕` 按钮）

### 22. 恢复默认快捷键（Settings Shortcuts Restore Default）
- 英文（可用）：Restore Default Shortcut
- 简体中文（可用）：恢复默认快捷键
- 繁体中文（可用）：恢復預設快速鍵
- 快捷键：无
- 触发延迟：1秒
- Scenario ID：settings.shortcuts.restore_default
- 所在位置：Settings -> Shortcuts 每行最右侧

### 23. 选择导出文件夹（Export to Anki Location Folder Button）
- 英文：Choose Export Folder
- 简体中文：选择导出文件夹
- 繁体中文：選擇匯出資料夾
- 快捷键：无
- 触发延迟：1秒
- Scenario ID：anki_export.location.choose_folder
- 所在位置：Export to Anki Dialog -> Location 行右侧 `folder` 图标按钮

### 24. 添加 Anki 卡片数据对象（Export to Anki Add Card Item Button）
- 英文（可用）：Add Item
- 简体中文（可用）：添加项目
- 繁体中文（可用）：加入項目
- 英文（Disabled - 已添加全部 7 个项目）：All items added
- 简体中文（Disabled - 已添加全部 7 个项目）：已添加全部项目
- 繁体中文（Disabled - 已添加全部 7 个项目）：已加入全部項目
- 快捷键：无
- 触发延迟：1秒
- Scenario ID：anki_export.card.add_item
- 所在位置：Export to Anki Dialog -> `Front` / `Back` 标题右侧 `+` 图标按钮

### 25. 移除 Anki 卡片数据对象（Export to Anki Remove Card Item Button）
- 英文：Remove Item
- 简体中文：移除项目
- 繁体中文：移除項目
- 快捷键：无
- 触发延迟：1秒
- Scenario ID：anki_export.card.remove_item
- 所在位置：Export to Anki Dialog -> `Front` / `Back` 卡片内数据对象右侧 `✕` 图标按钮

---

## 四、状态与异常指示器（Status Indicator Tooltips）

### 24. 摘录台词内容已变更（Cue State: Content Changed）
- 英文：This cue changed after reindexing
- 简体中文：该台词在重新索引后发生了变化
- 繁体中文：此台詞在重新索引後已變更
- 触发延迟：1秒
- Scenario ID：table.cue_state.content_changed
- 所在位置：Excerpt 二级页表格行状态图标（`clock-counter-clockwise`）

### 25. 摘录台词不可用（Cue State: Unavailable）
- 原因分支 1（媒体库不可用）：
  - 英文：The library source is currently unavailable
  - 简体中文：媒体库来源当前不可用
  - 繁体中文：媒體庫來源目前無法使用
- 原因分支 2（视频文件缺失）：
  - 英文：The video file is missing. The subtitle file is still available
  - 简体中文：视频文件缺失，字幕文件仍然可用
  - 繁体中文：影片檔案遺失，字幕檔案仍可使用
- 原因分支 3（字幕文件缺失）：
  - 英文：The subtitle file is missing or could not be reconnected
  - 简体中文：字幕文件缺失或无法重新连接
  - 繁体中文：字幕檔案遺失或無法重新連接
- 原因分支 4（字幕内找不到该台词）：
  - 英文：This cue could not be found in the current subtitle file
  - 简体中文：在当前字幕文件中找不到该台词
  - 繁体中文：在目前的字幕檔案中找不到此台詞
- 触发延迟：1秒
- Scenario ID：table.cue_state.unavailable
- 所在位置：Excerpt 二级页表格行状态图标（`question`）

---

## 五、禁用态控件原因说明（Disabled Controls Tooltips）

> **说明**：本章节控件在可用（Enabled）状态下已有明确文字标签，无需展示常规 Tooltip；**仅当其处于 `Disabled` 状态时**，悬停 1 秒展示以下原因说明。

### 26. Cover Summary 播放 / 继续播放按钮禁用（Cover Summary Play / Resume Disabled）
- 英文：No playable content available
- 简体中文：没有可播放的内容
- 繁体中文：沒有可播放的內容
- 触发延迟：1秒
- Scenario ID：disabled.cover_summary.no_playable_content
- 所在位置：Library 二级页、Excerpt 二级页顶部 Cover Summary 的 `Play` / `Resume` 按钮

### 27. File 页面“添加文件夹”按钮禁用（Add Folder Disabled）
- 英文：Unavailable while a task or database compaction is running
- 简体中文：任务或数据库压缩进行期间不可用
- 繁体中文：任務或資料庫壓縮進行期間無法使用
- 触发延迟：1秒
- Scenario ID：disabled.file.add_folder
- 所在位置：File 页面右上角 `Add Folder` 按钮

### 28. File 页面“索引全部”按钮禁用（Index All Disabled）
- 原因分支 A（尚未添加任何文件夹）：
  - 英文：Add a folder before indexing
  - 简体中文：请先添加文件夹后再索引
  - 繁体中文：請先加入資料夾後再索引
- 原因分支 B（存在进行中的任务或数据库压缩中）：
  - 英文：Unavailable while a task or database compaction is running
  - 简体中文：任务或数据库压缩进行期间不可用
  - 繁体中文：任務或資料庫壓縮進行期間無法使用
- 触发延迟：1秒
- Scenario ID：disabled.file.index_now
- 所在位置：File 页面左上角 `Index All` 按钮

### 29. 筛选对话框“重置”按钮禁用（Filter Reset Disabled）
- 英文：No active filters to reset
- 简体中文：当前没有可重置的筛选条件
- 繁体中文：目前沒有可重設的篩選條件
- 触发延迟：1秒
- Scenario ID：disabled.filter.reset
- 所在位置：Filter Dialog 左下角 `Reset` 按钮

### 30. 设置 -> 播放“自动切换到下一条台词”开关禁用（Auto Switch Disabled）
- 英文：Enable “Auto Pause After a Cue Finishes” first
- 简体中文：请先开启“台词结束后自动暂停”
- 繁体中文：請先開啟「台詞結束後自動暫停」
- 触发延迟：1秒
- Scenario ID：disabled.settings.play.auto_switch
- 所在位置：Settings -> Play -> `Auto Switch to Next Cues in Playlist` 开关

### 31. 设置 -> 字幕“恢复默认”按钮禁用（Subtitle Restore Defaults Disabled）
- 英文：All subtitle settings are already at default values
- 简体中文：当前全部字幕设置均为默认值
- 繁体中文：目前全部字幕設定皆為預設值
- 触发延迟：1秒
- Scenario ID：disabled.settings.subtitle.restore_defaults
- 所在位置：Settings -> Subtitle 底部 `Restore Defaults` 按钮

### 32. 设置 -> 维护“刷新”与“压缩数据库”按钮禁用（Maintenance Actions Disabled）
- 英文：Unavailable while folder removal or database compaction is running
- 简体中文：移除文件夹或压缩数据库期间不可用
- 繁体中文：移除資料夾或壓縮資料庫期間無法使用
- 触发延迟：1秒
- Scenario ID：disabled.settings.maintenance.actions
- 所在位置：Settings -> Maintenance -> `Refresh` 与 `Compact Database` 按钮

### 33. 编辑封面弹窗“保存”按钮禁用（Edit Cover Save Disabled）
- 英文：Choose an image first
- 简体中文：请先选择一张图片
- 繁体中文：請先選擇一張圖片
- 触发延迟：1秒
- Scenario ID：disabled.edit_cover.save
- 所在位置：Edit Cover Dialog 右下角 `Save` 按钮

---

## 六、截断文本补全（Truncated Text Tooltips）

> **说明**：以下组件仅在文本因宽度限制发生截断省略（`...`）时，悬停 1 秒后展示完整原文本；未发生截断时不触发。

### 34. 工作台顶栏页面标题（Workbench Page Title）
- 显示内容：完整的当前页面或层级标题文本
- 触发条件：单行文本超出顶栏可用宽度发生尾部省略（`...`）时
- 触发延迟：1秒
- Scenario ID：truncated.topbar.page_title
- 所在位置：App Topbar 标题区

### 35. 播放页顶栏视频标题（Player Title）
- 显示内容：完整的视频显示标题（`Display Title`）
- 触发条件：标题超出顶栏中心区最大宽度发生单行中间省略（`...`）时
- 触发延迟：1秒
- Scenario ID：truncated.player.title
- 所在位置：Player Topbar 中心标题区

### 36. 筛选对话框筛选项胶囊文本（Filter Chip Label）
- 显示内容：完整的筛选项名称文本
- 触发条件：胶囊文本达到 `332px` 最大宽度上限发生单行尾部省略（`...`）时
- 触发延迟：1秒
- Scenario ID：truncated.filter.chip_label
- 所在位置：Filter Dialog 筛选项胶囊按钮