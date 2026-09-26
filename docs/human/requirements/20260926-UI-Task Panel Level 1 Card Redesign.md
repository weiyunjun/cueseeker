# 版本

main

# 关联设计

- `docs/human/design/UI Design System.md`
- `docs/human/design/UI Application Rules.md`
- `docs/human/design/Icon Registry.md`

# 需求描述

## 1. 结构与交互原则
1. 任务面板展示内容先精简，本次只做一级界面，卡片暂不提供展开或点击交互。
2. 移除卡片右上角的删除/取消按钮（取消与删除下沉到后续二级界面）。
3. 移除标题处的所有状态 Badge（不再显示 In Progress 与 Queued 徽标）。

## 2. 卡片容器与间距
1. 卡片外壳：
   - 宽度自适应（720px 弹窗内扣除左右各 24px 留白后为 672px）。
   - 内边距：四周等距 16px（`--spacing-4`）。
   - 圆角：8px（`--radius-control`）。
   - 边框：1px（`--border-width-control`，`--color-border-control`）。
   - 背景色：`--color-bg-dialog`。
2. 垂直间距：卡片列表间距为 12px（`--spacing-3`）。

## 3. 左侧图标与锚定法则
1. 尺寸与规格：图标统一使用 31×31px（`--size-task-card-icon`，对应名录 31px / 线宽 1.50px 规格），纯描边无边框底色，字色为 `--color-text-secondary`。
2. 锚定基准：以 Top 16px 为绝对锚点（顶部对齐），与右侧内容容器首行齐平，不随卡片动态内容垂直居中。
3. 图标映射：
   - 导出为 Anki：`anki-star`（实心）
   - 修改文件夹或文件名称：`pencil-simple`
   - Index：`arrow-clockwise`
   - Add Folder：`folder-plus`
   - Remove：`minus-circle`
4. 图标与右侧文本容器间距为 16px（`--spacing-4`）。

## 4. 排版与等高法则
1. 文本容器纵向排布，行间距为 4px（`--spacing-1`）。
2. Line 1（标题行）：
   - 整行文本统一样式：`--font-size-body`（14px），字重 500（Medium），字色 `--color-text-primary`，禁止对前缀与目标对象进行分色与拆分字重。
   - 单行截断：超出宽度时单行省略显示。
3. Line 2（副文本行）：
   - 文本样式：`--font-size-caption`（12px），字重 400（Regular），字色 `--color-text-muted`。
4. Line 3（动态行 / 16px 固定高度占位法则）：
   - 固定高度为 16px，使运行中与失败卡片保持相同总高度。
   - In Progress 状态下居中展示 4px 高度 Capsule 进度条（轨道 `--color-library-progress-track`，填充色 `--color-accent`）。
   - Incomplete 状态下居中展示单行报错信息（末尾截断），`--font-size-caption`（12px），字重 400（Regular），字色 `--color-danger-text`。

## 5. 标题与状态文本规则
1. 标题命名与本地化规则（前缀跟随系统语言本地化，均不包含路径；中文使用全角冒号无空格）：
   - 导出为 Anki：`Export to Anki: xx` / `导出到 Anki：xx` / `匯出至 Anki：xx`（xx 为 apkg 文件名）。
   - 修改文件夹名称：`Renaming Folder: xx` / `重命名文件夹：xx` / `重新命名資料夾：xx`（xx 为修改后的文件夹名）。
   - 修改文件名称：`Renaming Files: xx` / `重命名文件：xx` / `重新命名檔案：xx`（xx 为修改后的通用基准文件名）。
   - 索引与文件夹：`Index` / `索引`；`Add Folder: xx` / `添加文件夹：xx` / `加入資料夾：xx`；`Remove: xx` / `移除：xx` / `移除：xx`（xx 为文件夹名）。
2. Current 标签页规则：
   - 导出为 Anki：In Progress 为 `xx/yy cards exported` 并展示 Line 3 进度条；Queued 为 `Queued  xx cards`（间隔 2 个空格，无 Line 3）。
   - 修改文件夹或文件名称：In Progress 为进度阶段文字并展示 Line 3 进度条；Queued 为 `Queued`（无 Line 3）。
   - Index、Add Folder、Remove：In Progress 为进度阶段文字并展示 Line 3 进度条（Remove 无进度条）；Queued 为 `Queued`（无 Line 3）。
3. Completed 标签页规则（无 Line 3）：
   - 导出为 Anki：`xx cards  完成时间`（间隔 2 个空格）。
   - 修改文件夹名称：`完成时间`。
   - 修改文件名称：`xx files  完成时间`（间隔 2 个空格）。
   - Index、Add Folder、Remove：`完成时间`。
4. Incomplete 标签页规则：
   - Line 2 文字：格式与 Completed 标签页完全一致，时间替换为出错时间。
   - Line 3 报错：16px 高度容器内展示单行末尾截断的具体报错信息（`--color-danger-text`）。
5. 所有时间格式维持现有显示规则。

# 验收

1. 卡片外壳内边距、圆角、边框、图标尺寸（31px）及 Top 16px 锚定严格符合上述规范。
2. 标题行整行统一为 14px / 500 Medium / Primary 字色，前缀支持中英文本地化（中文全角冒号），行间距为 4px。
3. Line 3 的进度条与报错行（单行截断）均在 16px 高度内居中，运行中与失败卡片高度一致。
4. 三大标签页各类任务的副文本及时间格式符合既定规则。
5. 视觉由所有者通过设置延时环境变量（`CUESEEKER_DEBUG_TASK_DELAY_SECONDS=15`）进行人工验收。