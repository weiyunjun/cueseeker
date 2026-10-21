# 版本

main

# 关联设计

- `docs/human/design/ui/UI Components - Controls.md`
- `docs/human/design/ui/UI Components - Domain.md`
- `docs/human/design/ui/UI Layouts - Workbench.md`
- `docs/human/design/ui/UI Layouts - Playback.md`

# 需求描述

1. **标准带框按钮组与页面顶部操作栏（`C-03.1 Button`，高 `36px`）同行间距统一为 `--spacing-4`（`16px`）**：
   - **所有弹窗底部操作按钮组（Dialog Footer，`L-06.1` ~ `L-06.7` 及 `C-10.2 Confirmation Dialog`）**：底部右侧操作按钮之间的水平间距由 `--spacing-2`（`8px`）改为 `--spacing-4`（`16px`）。
   - **Library 二级界面与 Excerpt 二级界面封面区域右侧按钮组（`C-11.2 Cover Summary` Action Row，用于 `L-04.3`、`L-05.3`）**：`Play / Resume`、`View in File`、`More (...)` 按钮之间的水平间距由 `--spacing-2`（`8px`）改为 `--spacing-4`（`16px`）。
   - **各界面顶部操作栏与工具栏（`36px` 按钮同行区域）**：水平间距由 `--spacing-3`（`12px`）统一改为 `--spacing-4`（`16px`），包括：
     - `File` 界面顶部操作栏（`L-04.5 File Page Layout`）：`Add Folder` 按钮、`Index All` 按钮与状态指示器之间的水平间距；
     - `Search` 界面与 `Excerpt` 二级界面工具栏（`L-05.4 Search / Excerpt Toolbar Layout`）：第一行搜索框、`Filter` 按钮、`Sort` 按钮之间的水平间距，以及第二行批量选择模式下 `退出选择` 按钮与提示文案之间的水平间距；
     - `Command Panel` 搜索结果页顶栏（`L-09.2 Command Panel Secondary Layout`）：右侧 `Filter` 按钮与 `Sort` 按钮之间的水平间距；
     - `Library` 一级界面与 `Excerpt` 一级界面顶部操作栏（`L-04.1 Library Primary Layout`、`L-05.1 Excerpt Primary Layout`）：排序按钮（或 `New List` 按钮）与右侧统计文案之间的水平间距。

2. **底部带快捷键帽的动作按钮（`C-03.3 Shortcut Action Button`）统一规格**：
   - 将播放页与命令面板底栏（`L-08.3 Playback Footer Layout`）的快捷动作按钮水平间距规格，与表格底部批量操作浮层（`C-06.5 Selection Action Overlay`）完全统一：
     - 相邻快捷动作按钮之间的水平间距由 `--spacing-1`（`4px`）改为 `--spacing-2`（`8px`）；
     - 按钮内部左右内边距（Padding Inline）由 `--spacing-2`（`8px`）改为 `--spacing-3`（`12px`）；
     - 按钮内部文字与右侧快捷键帽（Keycap）之间的水平间距由 `--spacing-1`（`4px`）改为 `--spacing-2`（`8px`）（同一动作含多个快捷键帽时，按键帽彼此之间保持 `--spacing-1` `4px` 不变）。

3. **顶栏 `Task` 按钮内部图标与数字胶囊间距（`C-08.3 Task Count Badge`）**：
   - `Task` 按钮（`C-03.2 Icon Button`）内部左侧图标与右侧数字胶囊之间的水平间距，与 `Filter` 按钮统一为 `--spacing-2`（`8px`）。
   - 顶栏与底栏其余纯图标按钮（`C-03.2 Icon Button`）彼此之间的水平间距保持现有设计不变。

4. **弹窗内部双列与图文同行间距调整**：
   - **导出 Anki 弹窗（`L-06.5 Export to Anki Dialog Layout`）**：`Front` 与 `Back` 两列卡片的水平间距（Card Layout Column Gap）由 `--spacing-3`（`12px`）改为 `--spacing-5`（`20px`）。
   - **文件详情弹窗（`L-06.8 File Detail Dialog Layout`）**：顶部 `40×40px` 文件图标与右侧文件名之间的水平间距（File Header Spacing）由 `--inset-dialog`（`24px`）改为 `--spacing-4`（`16px`）。

# 验收标准

1. 所有带底部操作按钮的弹窗（含封面编辑、新建/编辑摘录列表、重命名、协议目录连接、导出 Anki、Filter 筛选面板、二次确认弹窗），底部右侧两个按钮之间的水平间距均为 `16px`。
2. `Library` 二级界面与 `Excerpt` 二级界面顶部封面卡片右侧的 `Play / Resume`、`View in File`、`More (...)` 按钮之间的水平间距均为 `16px`。
3. `File` 顶部操作栏、`Search` 与 `Excerpt` 二级界面工具栏（第一行搜索筛选栏与第二行批量选择栏）、`Command Panel` 搜索结果页顶栏右侧 `Filter / Sort` 按钮组、`Library` 与 `Excerpt` 一级界面顶部操作栏的同行元素间距均为 `16px`。
4. 播放页底栏与命令面板底栏的快捷动作按钮（如 `Subtitle`、`Command`、`Play/Pause` 等），相邻按钮间距为 `8px`、按钮左右内边距为 `12px`、文字与快捷键帽间距为 `8px`，与表格底部批量操作浮层视觉一致。
5. 顶栏 `Task` 按钮出现进行中任务数字胶囊时，图标与数字胶囊之间的水平间距为 `8px`，与 `Filter` 按钮内的图标和数字胶囊间距视觉一致。
6. `Export to Anki` 弹窗中 `Front` 与 `Back` 两列间距为 `20px`；`File Detail` 弹窗顶部文件图标与右侧文件名间距为 `16px`。