# 版本

main

# 关联设计

- `docs/human/design/UI Design System.md`（Filter Chip、Button、Information Badge / Task Count Badge、Search / Excerpt Toolbar Layout、Filter Dialog Layout）

# 需求描述

## 1. 范围

Search 与 Excerpt 的 Filter Dialog，以及两处工具栏的 Filter Trigger。

## 2. 改动

### 2.1 Filter Chip

1. 圆角由胶囊形改为 `--radius-control`，其余外观不变。

### 2.2 Footer

1. 删除左侧的 Calculating Status。
2. Reset 移到 Footer 左侧；Cancel、Show 仍靠右。
3. 总数未知时（Search 搜索进行中、Excerpt 列表加载中），Show 的内容为 Spinner 与 `Calculating`，保持 Disabled；总数得出后显示 `Show N results` / `Show N excerpts`。

### 2.3 选中数量

1. Filter Trigger：图标右侧显示表格当前生效的筛选中选中的选项总数，外观同 Task Count Badge，为 0 时隐藏。
2. Section Header：名称右侧显示该组在对话框中当前选中的选项数，外观同 Task Count Badge，为 0 时隐藏。

### 2.4 分组操作

1. 每个 Section Header 行的右端新增三个按钮：`Select All`、`Deselect All`、`Invert Selection`（简体中文：全选、全不选、反选）。
2. 外观同 Button / Neutral，高度与 Filter Chip 相同；无 Disabled 状态。
3. 只作用于本组，只改变对话框中的选择，表格仍在 Show 后更新：
   - Select All：选中本组全部选项
   - Deselect All：取消本组全部选项
   - Invert Selection：本组每个选项的选中状态取反

## 3. 保持不变

1. Reset 的 Disabled 条件，以及 Cancel 与 Show 的行为不变。
2. 计数未知时 Filter Chip 内的占位块不变。

# 验收

1. Light 与 Dark 下，Filter Chip、Footer、Filter Trigger 与 Section Header 的数字、三个分组按钮的外观与本文一致。
2. 搜索进行中打开 Filter，Show 显示 Spinner 与 `Calculating` 且不可点击；搜索完成后恢复为带数量的 Show。
3. 三个分组按钮在各组的效果符合 2.4；点击 Show 后，表格与 Filter Trigger 的数字随之更新。
4. 本次改动不新增任何自动化端到端或单元用例的失败。