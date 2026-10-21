# 版本

main

# 关联设计

- `docs/human/design/ui/UI Index.md`
- `docs/human/design/ui/UI Interaction Rules.md`
- `docs/human/design/ui/UI Components - Controls.md`
- `docs/human/design/ui/UI Components - Domain.md`
- `docs/human/design/ui/UI Layouts - Workbench.md`

# 需求描述

1. **非批量选择状态结果计数水平位置微调**：
   - Search 界面的 `xx results` 与 Excerpt 二级界面的 `xx excerpts` 在现有基础上向右移动 `8px`（距工具栏/表格左边缘 `22px`），使其首字符与下方表格表头首列的 `#` 左对齐。

2. **批量选择（Select）状态第一行布局调整**：
   - 进入 Select 状态时，第一行不再显示搜索框、筛选按钮（`Filter`）和排序按钮。
   - 第一行保持与表格等宽，从左到右依次显示：
     - **已选计数（`xx / yy rows selected`）**：样式（字号、字重、颜色）及左侧水平坐标与非 Select 状态下的 `xx results` / `xx excerpts` 完全一致（距左边缘 `22px`）。
     - **批量选择提示文字**：位于 `xx / yy rows selected` 右侧（间隔 `16px`），显示 `Batch selection active: click any row to select, Shift+click for range`，文字样式保持不变。
     - **退出选择按钮（`Exit Selection`）**：位于最右侧（与表格右边缘对齐），保留左侧退出图标，样式改为 Destructive（红色警告样式），功能保持不变（点击或按 `Esc` 退出批量选择）。

3. **批量选择（Select）状态第二行布局调整与移除底部浮层**：
   - 不再显示页面底部居中的批量操作浮层（`Selection Action Overlay`）。
   - 在工具栏第二行（原 `Exit Selection` 所在行）从左到右依次显示 `Export to Anki A`、`Copy Deep Links D`、`Copy Table T` 功能按钮，按钮样式与快捷键（`A` / `D` / `T`）功能保持不变。
   - 第二行左侧留出 `10px` 边距（加上按钮自身 `12px` 左侧透明内边距，文字起点距左边缘 `22px`），使第一个按钮的文字与上方的 `xx / yy rows selected`、非 Select 状态的 `xx results` / `xx excerpts` 以及表格首列的 `#` 左对齐。

# 验收标准

1. 非 Select 状态下，Search 界面的 `xx results` 与 Excerpt 二级界面的 `xx excerpts` 距左边缘 `22px`，首字符与下方表头 `#` 垂直左对齐。
2. 进入 Select 状态后，搜索框、筛选按钮、排序按钮以及页面底部的浮动功能卡片均不再显示，且进出 Select 状态时下方表格不发生纵向跳动。
3. Select 状态第一行左侧显示 `xx / yy rows selected`（样式与坐标同 `xx results`），右侧间隔 `16px` 显示批量选择提示文字，最右侧对齐表格右边缘显示带图标的 Destructive 样式 `Exit Selection` 按钮，点击或按 `Esc` 正常退出批量选择。
4. Select 状态第二行显示 `Export to Anki A`、`Copy Deep Links D`、`Copy Table T` 按钮，第一个按钮的文字与上方 `xx / yy rows selected` 左对齐，点击按钮或按快捷键 `A` / `D` / `T` 功能正常。