# 版本

main

# 关联设计

- `docs/human/design/ui/UI Index.md`
- `docs/human/design/ui/UI Interaction Rules.md`
- `docs/human/design/ui/UI Components - Controls.md`
- `docs/human/design/ui/UI Components - Domain.md`
- `docs/human/design/ui/UI Layouts - Workbench.md`
- `docs/human/design/ui/Icon Registry.md`
- `docs/human/design/ui/Tooltip Usage Registry.md`

# 需求描述

1. **工具栏统一与下方表格左外框对齐**：
   - 去除工具栏额外的左侧缩进，非 Select 状态的 `xx results` / `xx excerpts`、Select 状态第一行的 `xx / yy rows selected` 以及第二行第一个按钮的左边框均直接与下方表格左外框对齐。

2. **批量选择（Select）状态第一行布局调整**：
   - 进入 Select 状态时，第一行不再显示搜索框、筛选按钮（`Filter`）和排序按钮。
   - 第一行保持与表格等宽，从左到右依次显示：
     - **已选计数（`xx / yy rows selected`）**：样式与左侧水平坐标同非 Select 状态的 `xx results` / `xx excerpts`，保持完整显示不截断。
     - **批量选择提示文字**：位于 `xx / yy rows selected` 右侧（间隔 `16px`），显示 `Batch selection active: click any row to select, Shift+click for range`；空间不足时优先缩减该提示文字并尾部省略（`...`），发生截断时悬停显示完整文字 Tooltip。
     - **退出选择按钮（`Exit Selection`）**：位于最右侧（与表格右边缘对齐），保留左侧 `sign-out` 图标，样式改为 Destructive（红色警告样式），悬停显示按钮文字与 `Esc` 快捷键 Tooltip，功能保持不变。

3. **批量选择（Select）状态第二行布局调整与移除底部浮层**：
   - 不再显示页面底部居中的批量操作浮层（`Selection Action Overlay`）。
   - 在工具栏第二行从左到右依次显示三个标准 Neutral 按钮（间距 `16px`，不显示行内按键帽）：`Export to Anki`（前置 `export` 图标）、`Copy Deep Links`（前置 `link-simple` 图标）、`Copy Table`（前置 `copy` 图标），悬停分别显示按钮文字与 `A` / `D` / `T` 快捷键 Tooltip，点击及快捷键功能保持不变。

# 验收标准

1. 非 Select 与 Select 状态下，工具栏两行内容均与下方表格左外框直接对齐，进出 Select 状态时下方表格不发生纵向跳动。
2. 进入 Select 状态后，搜索框、筛选按钮、排序按钮及页面底部浮动卡片均不再显示。
3. Select 状态第一行左侧完整显示 `xx / yy rows selected`，中间间隔 `16px` 显示提示文字（截断时悬停有完整文本 Tooltip），最右侧对齐表格右边缘显示带 `sign-out` 图标的 Destructive `Exit Selection` 按钮（悬停有 `Esc` 快捷键 Tooltip）。
4. Select 状态第二行显示带图标的标准 Neutral 按钮 `Export to Anki`、`Copy Deep Links`、`Copy Table`（间距 `16px`），悬停分别显示带 `A` / `D` / `T` 快捷键的 Tooltip，点击与快捷键功能正常。