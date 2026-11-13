# 版本

main

# 关联设计

- `docs/human/design/ui/UI Tokens.md`
- `docs/human/design/ui/UI Components - Controls.md`
- `docs/human/design/ui/UI Layouts - Workbench.md`

# 需求描述

1. **表格尺寸、间距与行高 Tokens 调整（`UI Tokens.md`）**：
   - `1.2 字体与文本 -> Typography`：新增表格普通文本单元格单行行高 `--line-height-table-cell: 20px`；
   - `1.3 尺寸 -> Height`：将 `--min-height-table-row` 由 `40px` 调整为 `48px`；
   - `1.4 间距 -> Spacing`：新增 `Cue Group` 条目间垂直间距 `--gap-table-cue-group: 4px`；
   - `1.4 间距 -> Padding`：将 `--padding-table-row-y` 由 `8px` 调整为 `12px`（`--padding-table-cell-hover-y` 保持 `8px` 不变）。

2. **表格目标字幕颜色、`Cue Group` 内部间距与行框居中规则（`C-06.3 Table Row`、`C-06.4 Table Cell`、`L-05.5 Search / Excerpt Table Layout`）**：
   - **目标字幕颜色**：`C-06.4 Table Cell / Interactive Text` 中目标字幕颜色由 `--color-text-primary` 调整为 `--color-text-secondary`（悬停下划线维持与该行文字同色，失效行主副字幕维持 `--color-text-muted` 不变），字号 `--font-size-table`（`14px`）、字重 `Medium`（`500`）与单行行高 `--line-height-table-cue-primary`（`24px`）保持不变；
   - **`Cue Group` 条目间距**：开启 `Show Cue Group` 时，`Cues` 列内目标字幕与附加字幕之间、以及多条附加字幕条目之间的垂直间距统一使用 `--gap-table-cue-group`（`4px`），不再复用 `--padding-table-row-y`；单条字幕自身源换行或自动折行之间不额外增加条目间距，继续按各自单行行框（`24px` / `20px`）连续排布且字形在单行行框内垂直视觉居中；
   - **普通文本数据列行高与居中**：`C-06.4 Table Cell / Text`（`Display Title`、`Time Range`、`Date Added`）统一使用单行行高 `--line-height-table-cell`（`20px`），每个视觉行占固定 `20px` 行框且字形在行框内垂直视觉居中，不附加尾部额外行距（多行内容块高度为 `视觉行数 × 20px`）；
   - **整行高度与列垂直对齐**：`Search` 与 `Excerpt` 表格行高统一按 `max(--min-height-table-row, 所有可见列最高内容块高度 + 2 × --padding-table-row-y)` 计算，各列内容块、首列序号/复选框及行尾 `dots-three` 按钮在整行高度内垂直居中（失效行左侧 `?` 状态图标维持与目标字幕首行垂直居中对齐）。

# 验收标准

1. **字重、颜色与纯单行表现**：`Search` 与 `Excerpt` 表格正常行的目标字幕保持 `Medium` 字重且颜色为 `--color-text-secondary`（悬停下划线同为 `--color-text-secondary`，失效行主副字幕维持 `--color-text-muted`）；关闭 `Show Cue Group` 且各列均为 1 行时，行高为 `48px`（上下内边距各 `12px`），目标字幕与右侧单行文本水平同轴居中。
2. **`Cue Group` 内紧外松与多行组合**：开启 `Show Cue Group`（以 1 行附加字幕为例）时，主副字幕条目间距为 `4px`、行上下内边距各 `12px`；1 行目标字幕时无论右侧列为 1 行还是 2 行，整行高度均为 `72px`；2 行目标字幕时整行高度为 `96px`，上下留白均衡对称。
3. **普通文本列折行对称与交互保持**：关闭 `Show Cue Group` 且右侧 `Date Added` 或 `Display Title` 折为 2 行、目标字幕为 1 行时，右侧 2 行文本块高度为 `40px`、整行高度为 `64px`，且右侧多行文本在行内上下留白严格对称（无偏上现象）；文字划选、悬停下划线、无障碍焦点框与切换 `Show Cue Group` / 缩放列宽时的滚动锚点恢复保持正常。