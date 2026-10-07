# 版本

main

# 关联设计

- `docs/human/design/UI Design System.md`
- `docs/human/design/UI Application Rules.md`

# 需求描述

## 1. 统一状态与度量文本组件
1. **统一规范**：将 Search 计数（`xx results`）、Library 计数（`xx folders`）、File 状态（`Last Updated: xxx`）、Excerpt 计数（`xx lists  yy cues`）统一为同类组件规范。
2. **样式定义**：对齐 File 界面 `Last Updated`：
   - 容器高度：36px（`--height-control`）。
   - 文字排版：14px（`--font-size-body`），字重 500 Medium（`--font-weight-control`），颜色 `--color-text-secondary`。
   - 图标支持：支持可选 Leading 图标；File 界面展示 18px 图标，Search、Library、Excerpt 为纯文本无图标。

## 2. Library 与 Excerpt 界面微调
1. **Library 排序行左侧计数**：
   - Library 一级界面排序操作行左侧新增文件夹计数（英文 `1 folder` / `%d folders`，中文 `%d 个文件夹`）。
2. **Excerpt 概览文案格式**：
   - 英文全小写且中间双空格：`%d lists  %d cues`（单数 `1 list  1 cue`）。
   - 中文双空格：`%d 个列表  %d 条字幕`。
3. **Excerpt 新建按钮**：
   - Excerpt 一级界面「New List」按钮改为标准 Neutral 按钮（样式同「Index Now」）。
   - 图标使用 Phosphor 图标库的 `plus` 图标（18px）。

## 3. 表格工具栏间距与表头调整
1. **工具栏间距**：
   - Search 与 Excerpt List 表格工具栏中，搜索框与第二行操作行、第二行操作行与表头的间距均改为 16px（`--spacing-4`）。
2. **表头高度与对齐**：
   - 表头容器高度改为 27px（`--height-table-header`）。
   - 各文字列表头文本改为垂直上对齐，保持与底部分割线的视觉间距。
   - 序号列 `#` 及全选 Checkbox 改为水平居中、垂直上对齐。

# 验收标准

1. Search、Library、File、Excerpt 四处计数/状态文本的字号、字重、颜色统一为 14px Medium `--color-text-secondary`。
2. Library 排序行左侧正确显示文件夹计数；Excerpt 概览文本格式正确（全小写、双空格）。
3. Excerpt 一级界面「New List」呈现为带 `plus` 图标的 Neutral 按钮。
4. 表格工具栏搜索框至第二行、第二行至表头的上下间距均为 16px（`--spacing-4`）。
5. 表头高度为 27px，文字上对齐，首列 `#` 与全选 Checkbox 水平居中且上对齐。