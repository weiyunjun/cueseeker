# 版本
main

# 需求描述
1. 调整列宽相关内容，详见## 列宽参数，## 列宽计算规则。
2. 调整行高规则，详见## 行高规则。
3. UI改动见# UI文档改动。

## 列宽参数

| 列 | 权重 | 最小宽度 | 说明 |
|---|---:|---:|---|
| Checkbox | — | 固定 `50pt` | 不参与权重分配 |
| Display Title | `3` | `180pt` | 允许标题换行 |
| Cues | `6` | `240pt` | 从当前 `520pt` 大幅缩小；正常窗口仍因高权重获得最大宽度 |
| Tags | `2` | `140pt` | Tag 自动折行 |
| Time Range | `2` | `140pt` | 长时间格式允许换成两行 |
| Date Added | `2` | `120pt` | 当前格式约为 `26-07-12 00:00` |
| Speaker（若恢复） | `2` | `140pt` | Tag 型内容 |
| Language（若恢复） | `2` | `120pt` | Tag 型内容 |


## 列宽计算规则

不能简单使用“最小宽度 + 按权重分配额外空间”，否则最终宽度比例会失真。建议采用约束式重新分配：

1. `可分配宽度 = max(视口宽度 - 50, 所有可见数据列最小宽度之和)`。
2. 按权重计算候选宽度。
3. 候选宽度小于最小宽度的列冻结在最小宽度。
4. 用剩余宽度和剩余权重重新计算，直到所有列满足约束。
5. 如果视口小于最小宽度总和，表格扩展到最小总宽度并出现水平滚动。
6. 隐藏列完全退出计算。

## 行高规则

行高 = max(所有可见单元格换行后的内容高度, Checkbox 高度) + 上下内边距
最小行高 = 40pt

1. 缓存键包含全部可见列的真实宽度组合和可见列集合。
2. 窗口缩放后重新测量可见行及 overscan 行。
3. 离屏行继续惰性测量，避免一次测量几千行。
4. 保持当前滚动锚点，避免行高变化导致列表跳动。

# UI文档改动

### 1. Search / Shiori / Context Table Layout

修改前

```markdown
- Column Width：
  - Selection：`50pt`，固定
  - Display Title：`240pt`，固定
  - Cues：最小 `520pt`，填满剩余宽度
  - Tags：`180pt`，固定，仅 Shiori
  - Time Range：`190pt`，固定
  - Date Added：`160pt`，固定，仅 Shiori
```

修改后

```markdown
- Column Width：
  - Selection：`50pt`，固定，不参与权重分配
  - Display Title：权重 `3`，最小 `180pt`
  - Cues：权重 `6`，最小 `240pt`
  - Tags：权重 `2`，最小 `140pt`，仅 Shiori
  - Time Range：权重 `2`，最小 `140pt`
  - Date Added：权重 `2`，最小 `120pt`，仅 Shiori

- Column Width Resolution：
  1. 只有当前可见的数据列参与宽度计算；隐藏列完全退出计算。
  2. 可分配宽度为 Table Viewport Width 减去 Selection Column Width。
  3. 数据列首先按照各自权重计算候选宽度。
  4. 候选宽度小于最小宽度的列固定为最小宽度。
  5. 使用剩余宽度和剩余列权重重新计算，直到所有可见数据列均满足最小宽度。
  6. 当 Table Viewport Width 小于全部可见列的最小宽度总和，Table Content Width 使用最小宽度总和，并启用水平滚动。
  7. Header 和正文使用相同的最终列宽及水平滚动偏移。
```

### 2. Table Row 行高规则

修改前

```markdown
- 设本行显示的 Cue Item 数量为 `N`，每个 Cue Item 的自然高度为 `Hᵢ`：

  `Cue Block Height = ΣHᵢ + (N - 1) × --padding-table-row-y`

- 最终行高：

  `Row Height = max(--min-height-table-row, max(All Column Content Block Heights) + 2 × --padding-table-row-y)`

- 所有列的完整内容块在行内垂直居中。
- Metadata 不再对齐 Primary Cue 第一视觉行。
- Primary Cue 使用 `--font-size-table`、`--line-height-table-cue-primary`、`--color-text-secondary`。
- Extra Cues 使用 `--font-size-caption`、`--line-height-table-cue-secondary`、`--color-text-muted`。
- Primary Cue 和 Extra Cues 的文字字形分别在各自的 line-height 行框内垂直视觉居中。
- 所有 Cue 保留源换行和自动换行，不裁剪、不截断、不显示省略号。
```

修改后

```markdown
- Table Row 必须在当前可见列的最终列宽确定后计算内容布局和行高。
- Display Title、Cues、Time Range 和 Date Added 按各自最终列宽自动换行，并显示完整内容。
- Tags 按最终列宽使用水平换行布局，并形成完整内容块。
- 设本行显示的 Cue Item 数量为 `N`，每个 Cue Item 的自然高度为 `Hᵢ`：

  `Cue Block Height = ΣHᵢ + (N - 1) × --padding-table-row-y`

- 最终行高：

  `Row Height = max(--min-height-table-row, max(All Visible Column Content Block Heights) + 2 × --padding-table-row-y)`

- Table Viewport Width 或可见列发生变化时，按照新的最终列宽重新计算换行和行高。
- 行高更新时保留当前滚动锚点，不改变当前行或 Primary Cue 身份，不产生可见位置跳动。
- 所有列的完整内容块在行内垂直居中。
- Metadata 不再对齐 Primary Cue 第一视觉行。
- Primary Cue 使用 `--font-size-table`、`--line-height-table-cue-primary`、`--color-text-secondary`。
- Extra Cues 使用 `--font-size-caption`、`--line-height-table-cue-secondary`、`--color-text-muted`。
- Primary Cue 和 Extra Cues 的文字字形分别在各自的 line-height 行框内垂直视觉居中。
- 所有 Cue 保留源换行和自动换行，不裁剪、不截断、不显示省略号。
```
