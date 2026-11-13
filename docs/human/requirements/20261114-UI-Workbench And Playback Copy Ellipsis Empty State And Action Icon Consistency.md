# 版本

main

# 关联设计

- `docs/human/design/ui/Icon Registry.md`
- `docs/human/design/ui/Tooltip Usage Registry.md`
- `docs/human/design/ui/UI Accessibility Rules.md`
- `docs/human/design/ui/UI Components - Controls.md`
- `docs/human/design/ui/UI Layouts - Workbench.md`
- `docs/human/design/ui/UI Layouts - Playback.md`

# 需求描述

1. **移除刻意添加的省略号并清理废弃词条**：
   - 将摘录表格行菜单（右键及 `...` 菜单）、批量选择工具栏按钮及对应 Tooltip 中的 `Move to ...`（`移动到…` / `移動至⋯`）与 `Duplicate to ...`（`复制到…` / `複製至⋯`）统一去掉省略号，改为 **`Move to`**（`移动到` / `移動至`）与 **`Duplicate to`**（`复制到` / `複製至`）；
   - 保留空间不足时的文本截断省略号，以及 macOS 顶部应用菜单栏常规写法 **`Settings...`**（`设置…` / `設定⋯`）；
   - 清理本地化词库中 6 条已废弃且当前界面不再使用的历史带省略号状态文案。

2. **规范各界面搜索框占位文案**：
   - **`Workbench Search` 与 `Command Panel` 首页搜索框**：统一调整为 **`Search cues`**（`搜索台词` / `搜尋台詞`）；侧边栏及 `Command Panel` 首页导航项文案保持 **`Search`**（`搜索` / `搜尋`）不变；
   - **`Workbench Excerpt` 详情页搜索框**：调整为 **`Search excerpts`**（`搜索摘录` / `搜尋摘錄`），不再与 `Search` 页面共用同一占位提示；
   - **`Workbench Library` 总览搜索框**：去掉省略号，调整为 **`Search folders`**（`搜索文件夹` / `搜尋資料夾`）；
   - **`Workbench Excerpt` 总览搜索框**：去掉省略号，调整为 **`Search excerpt lists`**（`搜索摘录集` / `搜尋摘錄集`）。

3. **统一与优化空白状态文案**：
   - **`Workbench Search` 未输入搜索词空状态**：调整为 **`Enter keywords to search cues.`**（`输入关键词以搜索台词。` / `輸入關鍵字以搜尋台詞。`）；
   - **`Recent` 视频空状态**（含工作台 `Recent -> Videos` 与 `Command Panel -> Recent Videos`）：调整为 **`No recent videos yet.`**（`没有最近视频。` / `尚無最近影片。`）；
   - **`Recent` 摘录集空状态**（含工作台 `Recent -> Excerpt Lists` 与 `Command Panel -> Recent Excerpt Lists`）：简体中文调整为 **`没有最近的摘录集。`**（英文 `No recent excerpt lists yet.` 与繁体中文 `尚無最近的摘錄集。` 保持不变）；
   - **`Task Panel` 英文空状态**：统一由单数改为复数，调整为 **`No tasks running or waiting.`**（进行中）、**`No completed tasks yet.`**（已完成）与 **`No incomplete tasks.`**（未完成），简繁中文保持不变；
   - `File` 二/三级目录空状态文案保持现状不变。

4. **统一封面及列表卡片菜单文案、图标与弹窗标题**：
   - **媒体封面卡片封面编辑入口**（覆盖 `Library` 一级文件夹卡片与二级剧集卡片及其 `Cover Summary` 的 `More` 菜单、`Recent` 视频卡片、`Playback Playlist` 视频卡片及 `Command Panel` 最近视频卡片的右键与 `...` 菜单）：菜单文案由 `Change Cover`（`更换封面` / `更換封面`）改为 **`Edit Cover`**（`编辑封面` / `編輯封面`），菜单图标由 `export` 统一改为 **`pencil-simple`**，与 `Edit Cover` 弹窗标题及选图动作图标保持一致；
   - **`Excerpt` 卡片及 `Cover Summary` `More` 菜单的 `Edit List`**：保持 `Edit List`（`编辑摘录集` / `編輯摘錄集`）文案不变，菜单图标由 `note-pencil` 统一改为 **`pencil-simple`**（不再保留仅用于此处的 `note-pencil` 图标）；
   - **`File` 文件夹卡片菜单**（覆盖一级根目录卡片与二级子文件夹卡片的右键及 `...` 菜单）：三项文件夹菜单文案统一去掉 `This` 与“此”，调整为 **`Rename Folder`**（`重命名文件夹` / `重新命名資料夾`）、**`Index Folder`**（`索引文件夹` / `索引資料夾`）与 **`Remove Folder`**（`移除文件夹` / `移除資料夾`），使重命名菜单项与 `Rename Folder` 弹窗标题一致。

5. **设计文档同步安排**：
   - 关联 UI 设计文档中对应文案、图标条目及已有文档差异记录，待本次改动验收完成后再统一提交更新。

# 验收标准

1. **省略号与搜索占位规范验收**：在 `EN`、简中、繁中三种语言下，摘录表格行菜单及批量工具栏/Tooltip 显示 `Move to` / `Duplicate to`（`移动到` / `复制到`、`移動至` / `複製至`），均不带省略号；`Search` 与 `Command Panel` 搜索框显示 `Search cues`（`搜索台词` / `搜尋台詞`），`Excerpt` 详情页显示 `Search excerpts`（`搜索摘录` / `搜尋摘錄`），`Library` 与 `Excerpt` 总览显示 `Search folders` 与 `Search excerpt lists` 且均不带省略号；顶部系统应用菜单栏仍保持 `Settings...`（`设置…` / `設定⋯`）。
2. **空白状态文案验收**：`Workbench Search` 未输入搜索词时显示 `Enter keywords to search cues.`（`输入关键词以搜索台词。` / `輸入關鍵字以搜尋台詞。`）；`Recent` 与 `Command Panel` 的视频空状态显示 `No recent videos yet.`（`没有最近视频。` / `尚無最近影片。`），摘录集空状态简体中文显示 `没有最近的摘录集。`；`Task Panel` 三个标签页英文空状态分别为 `No tasks running or waiting.`、`No completed tasks yet.`、`No incomplete tasks.`。
3. **动作文案与图标一致性验收**：所有媒体封面卡片右键与 `...` 菜单（含 `Library Folder Detail` 顶部 `More` 菜单）均显示 `Edit Cover`（`编辑封面` / `編輯封面`）与 `pencil-simple` 图标；`Excerpt` 卡片及详情 `More` 菜单中的 `Edit List` 使用 `pencil-simple` 图标；`File` 一/二级文件夹卡片菜单显示 `Rename Folder`、`Index Folder` 与 `Remove Folder`（`重命名文件夹` / `索引文件夹` / `移除文件夹`、`重新命名資料夾` / `索引資料夾` / `移除資料夾`）。