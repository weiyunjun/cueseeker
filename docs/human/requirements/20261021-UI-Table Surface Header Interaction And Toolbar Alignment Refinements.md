# 版本

main

# 关联设计

- `docs/human/design/ui/UI Design Rules.md`
- `docs/human/design/ui/UI Interaction Rules.md`
- `docs/human/design/ui/UI Tokens.md`
- `docs/human/design/ui/UI Components - Controls.md`
- `docs/human/design/ui/UI Components - Domain.md`
- `docs/human/design/ui/UI Layouts - Workbench.md`

# 需求描述

1. **移除深色模式下表格的额外灰色底色（`C-06.1 Table`）**：
   - Search 界面与 Excerpt 二级界面的表格（`C-06.1 Table`，含固定表头与表体）表面背景色由 `--color-table-bg` 改为复用页面背景 `--color-bg-surface`（Light `#FFFFFF`；Dark `#1C1C1F`），表头吸顶时保持不透明的 `--color-bg-surface` 以遮挡下方滚动内容。
   - 表格表头与表格行的悬停色、表格行选中色及行内状态图标（`C-08.5 Cue State Indicator`）悬停底色改为使用基于 `--color-bg-surface` 阶梯的专用 Token `--color-table-row-hover` 与 `--color-table-row-selected`（既有 `--color-table-bg`、`--color-row-hover`、`--color-row-selected` 继续供 `#2E2E34` 层级的卡片组件使用）。

2. **表头高度、垂直居中与工具栏间距调整（`C-06.2 Table Header Cell`、`L-05.4 Search / Excerpt Toolbar Layout`）**：
   - 表头高度 Token `--height-table-header` 由 `27px` 调整为 `36px`。
   - `C-06.2 Table Header Cell`（含普通列名与首列 `Selection` 变体的 `#` 及全选 `Checkbox`）垂直对齐方式由 `Vertical Top` 改为 `Vertical Center`，保持表头文字与底部分割线的距离不变。
   - `L-05.4 Search / Excerpt Toolbar Layout` 的 `Bottom Gap`（工具栏第二行至表头顶部的间距）由 `--spacing-4`（`16px`）调整为 `--spacing-2`（`8px`）。

3. **表头 Hover 与全选交互优化（`C-06.2 Table Header Cell`、`L-05.6 Search / Excerpt Table Layout`）**：
   - **整行 Hover 反馈**：鼠标悬停在表头任意位置时，整个表头行背景色切换为 `--color-table-row-hover`；当列表存在可选中的有效字幕行时，悬停表头任意位置均在首列 `Selection` 槽位显示全选 `Checkbox`（处于 `Select Mode` 时常驻显示全选 `Checkbox`）。
   - **全选点击触发范围**：未处于 `Select Mode` 时，与普通数据行（`C-06.3 Table Row`）保持一致，仅点击表头首列全选 `Checkbox` 区域触发全选并进入 `Select Mode`，表头文字区域仍支持划选文本；处于 `Select Mode` 时，点击表头整行任意位置均可切换全选状态。
   - **表头选中态无常驻底色**：无论表头处于 `None Selected`、`Partially Selected` 还是 `All Selected` 状态，非 Hover 时表头均保持默认背景色 `--color-bg-surface`，仅在鼠标 Hover 表头时显示 `--color-table-row-hover`。

4. **表格圆角外框与末行分割线收口（`C-06.1 Table`、`C-06.3 Table Row`、`L-05.6 Search / Excerpt Table Layout`）**：
   - 为 `C-06.1 Table`（包裹固定表头与数据行区域）增加圆角外框：圆角使用 `--radius-control`（`8px`），边框颜色使用 `--color-border-control`（Light `#E5E7EB`；Dark `#4A4A52`），边框宽度使用 `--border-width-control`（`1px`），表头与数据行的背景色均在圆角外框内裁剪。
   - 表头底部分割线与数据行间分割线保持使用 `--color-border-divider`（宽度 `--border-width-control`），**表格最后一行数据不再绘制底部分割线**；当数据行总高度未撑满表格可视区域时，圆角外框紧贴最后一行底部收口。

5. **工具栏计数文本左对齐微调（`L-05.4 Search / Excerpt Toolbar Layout`）**：
   - `L-05.4` 第二行在 `Default` 状态下的 `Result Count`（Search 界面的 `xx results` 与 Excerpt 二级界面的 `xx excerpts`）增加左侧内边距 `--padding-control-x`（`14px`），使其左边缘与上方 `C-01.3 Search Field` 内部左侧放大镜图标（左内边距同为 `--padding-control-x`）及下方表格首列 `Checkbox` 左边缘对齐；`Select Mode` 下的「退出选择」按钮保持与搜索框左外沿对齐。

6. **Token 调整与新增清单**：
   - **调整 Token**：
     - `--height-table-header`：`27px` $\rightarrow$ `36px`。
   - **新增 Token**：
     - `--color-table-row-hover`：Light `#F9FAFB`；Dark `#26262B`；
     - `--color-table-row-selected`：Light `#ECEEF2`；Dark `#313137`。

# 验收标准

1. Search 界面与 Excerpt 二级界面中，表格背景使用 `--color-bg-surface`（深色下无额外灰色底块），Hover（`--color-table-row-hover`）与选中行（`--color-table-row-selected`）对比度自然，且不影响 Settings、File、Task 卡片的既有深色背景与 Hover 表现。
2. 表头高度为 `--height-table-header`（`36px`），列名文字、`#` 与全选 `Checkbox` 均垂直居中，工具栏第二行与表头间距为 `--spacing-2`（`8px`）。
3. 鼠标悬停表头任意位置时，整行表头显示 `--color-table-row-hover` 背景色且首列显示全选 `Checkbox`；未进入批量选择时仅点击首列 `Checkbox` 触发全选，进入批量选择后点击表头整行均可切换全选；全选后移开鼠标，表头恢复 `--color-bg-surface` 背景色。
4. 表格具备 `--border-width-control`（`1px`）、`--color-border-control`、`--radius-control`（`8px`）圆角外框，最后一行无重复底部分割线，行数较少时外框紧贴末行底部收口，Excerpt 二级界面滚动与表头吸顶时外框与圆角裁剪表现正常。
5. `xx results` 与 `xx excerpts` 左侧缩进 `--padding-control-x`（`14px`），与搜索框内放大镜图标及表格首列 `Checkbox` 左边缘对齐。